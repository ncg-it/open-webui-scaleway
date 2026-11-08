#!/usr/bin/env bash
# Kosten-Stopp: summiert die Scaleway-Kosten des laufenden Monats (netto, ohne MwSt.)
# und schaltet die Instance aus, sobald COST_LIMIT_EUR erreicht ist.
#
# ACTION=check (Standard): Kosten prüfen, bei Überschreitung Instance stoppen und mit Fehler enden
# ACTION=start:            Instance wieder einschalten (nach Erhöhung des Limits oder im neuen Monat)
#
# Benötigt: SCW_SECRET_KEY (mit BillingReadOnly + InstancesFullAccess), SCW_DEFAULT_ORGANIZATION_ID,
#           SERVER_ID, COST_LIMIT_EUR; optional ZONE, WARN_PERCENT. Tools: curl, jq
set -euo pipefail

: "${SCW_SECRET_KEY:?}" "${SCW_DEFAULT_ORGANIZATION_ID:?}" "${SERVER_ID:?}" "${COST_LIMIT_EUR:?}"
ZONE="${ZONE:-nl-ams-1}"
WARN_PERCENT="${WARN_PERCENT:-80}"
ACTION="${ACTION:-check}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/stdout}"
API=https://api.scaleway.com
AUTH=(-H "X-Auth-Token: $SCW_SECRET_KEY" -H "Content-Type: application/json")
SERVER_URL="$API/instance/v1/zones/$ZONE/servers/$SERVER_ID"

server_state() { curl -fsS "${AUTH[@]}" "$SERVER_URL" | jq -r '.server.state'; }
server_action() { curl -fsS "${AUTH[@]}" -X POST "$SERVER_URL/action" -d "{\"action\":\"$1\"}" >/dev/null; }

if [ "$ACTION" = "start" ]; then
  state=$(server_state)
  if [ "$state" = "running" ]; then echo "Instance läuft bereits."; exit 0; fi
  server_action poweron
  echo "Instance wird gestartet (vorher: $state)." | tee -a "$SUMMARY"
  exit 0
fi

# --- Kosten des laufenden Monats abrufen (alle Seiten) ---
PERIOD=$(date -u +%Y-%m)
ALL='[]'; page=1
while :; do
  resp=$(curl -fsS "${AUTH[@]}" \
    "$API/billing/v2beta1/consumptions?organization_id=$SCW_DEFAULT_ORGANIZATION_ID&billing_period=$PERIOD&page=$page&page_size=100")
  ALL=$(jq -c --argjson acc "$ALL" '$acc + .consumptions' <<<"$resp")
  total=$(jq -r '.total_count' <<<"$resp")
  [ "$(jq length <<<"$ALL")" -ge "$total" ] || [ "$(jq '.consumptions | length' <<<"$resp")" -eq 0 ] && break
  page=$((page + 1))
done

# Betrag = units + nanos/1e9. Rabatte (z. B. Gratis-Tokens) werden bewusst NICHT abgezogen -> konservativ.
COST=$(jq '[.[] | ((.value.units // "0" | tonumber) + ((.value.nanos // 0) / 1e9))] | add // 0 | (. * 100 | round) / 100' <<<"$ALL")
PCT=$(jq -n --argjson c "$COST" --argjson l "$COST_LIMIT_EUR" '($c / $l * 100) | floor')

{
  echo "### Scaleway-Kosten $PERIOD"
  echo ""
  echo "**$COST € von $COST_LIMIT_EUR € Limit ($PCT %)**, netto ohne MwSt."
  echo ""
  echo "| Produkt | € |"
  echo "|---|---:|"
  jq -r 'group_by(.product_name) | map({p: .[0].product_name, v: (map((.value.units // "0" | tonumber) + ((.value.nanos // 0) / 1e9)) | add)})
         | sort_by(-.v) | .[] | "| \(.p) | \((.v * 100 | round) / 100) |"' <<<"$ALL"
} >> "$SUMMARY"

echo "Kosten $PERIOD: $COST € / Limit $COST_LIMIT_EUR € ($PCT %)"

if [ "$PCT" -ge 100 ]; then
  state=$(server_state)
  if [ "$state" = "running" ] || [ "$state" = "starting" ]; then
    server_action poweroff
    msg="Limit erreicht: Instance $SERVER_ID wird gestoppt (war: $state)."
  else
    msg="Limit erreicht: Instance ist bereits '$state'."
  fi
  echo "::error::$msg"
  echo "" >> "$SUMMARY"; echo "> ⛔ $msg Wieder starten: Workflow 'Kosten-Stopp' manuell mit action=start ausführen." >> "$SUMMARY"
  exit 1
elif [ "$PCT" -ge "$WARN_PERCENT" ]; then
  echo "::warning::Kosten bei $PCT % des Limits ($COST € von $COST_LIMIT_EUR €)."
fi
