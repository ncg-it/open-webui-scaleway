#!/usr/bin/env bash
# Cost guard: sums up the Scaleway costs of the current month (excl. VAT)
# and powers off the instance once COST_LIMIT_EUR is reached.
#
# ACTION=check (default): check costs; if over the limit, stop the instance and exit with an error
# ACTION=start:           power the instance back on (after raising the limit or in a new month)
#
# Requires: SCW_SECRET_KEY (with BillingReadOnly + InstancesFullAccess), SCW_DEFAULT_ORGANIZATION_ID,
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
  if [ "$state" = "running" ]; then echo "Instance is already running."; exit 0; fi
  server_action poweron
  echo "Starting instance (previous state: $state)." | tee -a "$SUMMARY"
  exit 0
fi

# --- Fetch the costs of the current month (all pages) ---
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

# Amount = units + nanos/1e9. Discounts (e.g. free tokens) are deliberately NOT subtracted -> conservative.
COST=$(jq '[.[] | ((.value.units // "0" | tonumber) + ((.value.nanos // 0) / 1e9))] | add // 0 | (. * 100 | round) / 100' <<<"$ALL")
PCT=$(jq -n --argjson c "$COST" --argjson l "$COST_LIMIT_EUR" '($c / $l * 100) | floor')

{
  echo "### Scaleway costs $PERIOD"
  echo ""
  echo "**$COST € of $COST_LIMIT_EUR € limit ($PCT %)**, excl. VAT."
  echo ""
  echo "| Product | € |"
  echo "|---|---:|"
  jq -r 'group_by(.product_name) | map({p: .[0].product_name, v: (map((.value.units // "0" | tonumber) + ((.value.nanos // 0) / 1e9)) | add)})
         | sort_by(-.v) | .[] | "| \(.p) | \((.v * 100 | round) / 100) |"' <<<"$ALL"
} >> "$SUMMARY"

echo "Costs $PERIOD: $COST € / limit $COST_LIMIT_EUR € ($PCT %)"

if [ "$PCT" -ge 100 ]; then
  state=$(server_state)
  if [ "$state" = "running" ] || [ "$state" = "starting" ]; then
    server_action poweroff
    msg="Limit reached: stopping instance $SERVER_ID (was: $state)."
  else
    msg="Limit reached: instance is already '$state'."
  fi
  echo "::error::$msg"
  echo "" >> "$SUMMARY"; echo "> ⛔ $msg To restart: run the 'Cost guard' workflow manually with action=start." >> "$SUMMARY"
  exit 1
elif [ "$PCT" -ge "$WARN_PERCENT" ]; then
  echo "::warning::Costs at $PCT % of the limit ($COST € of $COST_LIMIT_EUR €)."
fi
