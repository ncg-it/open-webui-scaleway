#!/usr/bin/env bash
# Scaleway Cockpit helper.
# ACTION=list: show the data sources per region (nl-ams, fr-par).
# ACTION=sync: sync the data sources of all regions into Grafana, then list them.
#   Needed because the Generative APIs report metrics in fr-par while the server runs in nl-ams.
# Requires: SCW_SECRET_KEY (with ObservabilityFullAccess or ObservabilityReadOnly for list),
#           SCW_DEFAULT_PROJECT_ID. Tools: curl, jq
set -euo pipefail

: "${SCW_SECRET_KEY:?}" "${SCW_DEFAULT_PROJECT_ID:?}"
ACTION="${ACTION:-list}"
REGIONS="${REGIONS:-nl-ams fr-par}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/stdout}"
API=https://api.scaleway.com/cockpit/v1
AUTH=(-H "X-Auth-Token: $SCW_SECRET_KEY" -H "Content-Type: application/json")

call() {
  # Prints the body; fails with a readable message on HTTP errors (e.g. 403 = missing permission)
  local out code
  out=$(curl -sS -w '\n%{http_code}' "${AUTH[@]}" "$@")
  code=${out##*$'\n'}; out=${out%$'\n'*}
  if [ "$code" -ge 300 ]; then
    echo "::error::HTTP $code for ${*: -1}: $(jq -r '.message // .' <<<"$out" 2>/dev/null || echo "$out")" >&2
    [ "$code" = 403 ] && echo "::error::The API key lacks Cockpit permissions. Add the permission set 'ObservabilityFullAccess' to the policy of the open-webui-terraform IAM application." >&2
    return 1
  fi
  printf '%s' "$out"
}

list() {
  {
    echo "### Cockpit data sources"
    echo ""
    echo "| Region | Name | Type | Origin |"
    echo "|---|---|---|---|"
    for r in $REGIONS; do
      call "$API/regions/$r/data-sources?project_id=$SCW_DEFAULT_PROJECT_ID&page_size=100" \
        | jq -r --arg r "$r" '.data_sources[] | "| \($r) | \(.name) | \(.type) | \(.origin) |"'
    done
  } | tee -a "$SUMMARY"
}

if [ "$ACTION" = "sync" ]; then
  call -X POST "$API/grafana/sync-data-sources" -d "{\"project_id\":\"$SCW_DEFAULT_PROJECT_ID\"}" >/dev/null
  echo "Grafana data sources synced for project $SCW_DEFAULT_PROJECT_ID." | tee -a "$SUMMARY"
fi
list
