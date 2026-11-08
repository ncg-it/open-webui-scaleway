#!/usr/bin/env bash
# Creates a snapshot of the data volume and deletes all but the latest $KEEP.
# Requires: SCW_SECRET_KEY, SCW_DEFAULT_PROJECT_ID, DATA_VOLUME_ID; optional ZONE, KEEP. Tools: curl, jq
set -euo pipefail

: "${SCW_SECRET_KEY:?}" "${SCW_DEFAULT_PROJECT_ID:?}" "${DATA_VOLUME_ID:?}"
ZONE="${ZONE:-nl-ams-1}"
KEEP="${KEEP:-7}"
API="https://api.scaleway.com/block/v1alpha1/zones/$ZONE"
AUTH=(-H "X-Auth-Token: $SCW_SECRET_KEY" -H "Content-Type: application/json")

NAME="open-webui-data-$(date -u +%Y%m%d-%H%M)"
echo "Creating snapshot $NAME"
curl -fsS "${AUTH[@]}" -X POST "$API/snapshots" \
  -d "$(jq -n --arg v "$DATA_VOLUME_ID" --arg n "$NAME" --arg p "$SCW_DEFAULT_PROJECT_ID" \
        '{volume_id:$v, name:$n, project_id:$p, tags:["open-webui-backup"]}')" | jq -r '.id'

echo "Cleaning up (keeping $KEEP)"
curl -fsS "${AUTH[@]}" "$API/snapshots?volume_id=$DATA_VOLUME_ID&page_size=100" \
  | jq -r '.snapshots | map(select(.tags | index("open-webui-backup"))) | sort_by(.created_at) | reverse | .['"$KEEP"':][] | .id' \
  | while read -r id; do
      echo "Deleting $id"
      curl -fsS "${AUTH[@]}" -X DELETE "$API/snapshots/$id" >/dev/null
    done
