#!/usr/bin/env bash
# Convert many images with the Unraster Batches API and download one zip.
#
# Usage:
#   UNRASTER_API_KEY=... batch.sh <svg|pptx> <out.zip> <image> [<image> ...]
#
# Flow (see https://unraster.ai/docs/api#batches):
#   1. POST /v1/batches                 declare files, reserve credits (Idempotency-Key)
#   2. PUT  /v1/batches/{id}/files/{idx} upload each file
#   3. POST /v1/batches/{id}/start      begin conversion
#   4. GET  /v1/batches/{id}            poll until finished_at is set
#   5. GET  /v1/batches/{id}/archive    download every delivered file as one zip
#
# Batches need a plan with batch access ($49.9/month and up; other plans get
# 403 plan_required). Each file can be up to 20 MiB. Credits are reserved for every file when
# the batch is created and only delivered files are charged.
set -euo pipefail

API="${UNRASTER_API:-https://unraster.ai}"
POLL_SECONDS="${UNRASTER_POLL_SECONDS:-5}"
MAX_WAIT_SECONDS="${UNRASTER_MAX_WAIT_SECONDS:-1800}"

die() { echo "error: $*" >&2; exit 1; }

[ "$#" -ge 3 ] || die "usage: batch.sh <svg|pptx> <out.zip> <image> [<image> ...]"
[ -n "${UNRASTER_API_KEY:-}" ] || die "set UNRASTER_API_KEY (create one at https://unraster.ai/developers/api-keys)"
command -v curl >/dev/null || die "curl is required"
command -v jq >/dev/null || die "jq is required"

OUTPUT="$1"; OUT_ZIP="$2"; shift 2
case "$OUTPUT" in svg|pptx) ;; *) die "output must be svg or pptx" ;; esac

mime_for() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    *.png) echo "image/png" ;;
    *.jpg|*.jpeg) echo "image/jpeg" ;;
    *.webp) echo "image/webp" ;;
    *) return 1 ;;
  esac
}

FILES=("$@")
DECLARED='[]'
for f in "${FILES[@]}"; do
  [ -f "$f" ] || die "not a file: $f"
  type="$(mime_for "$f")" || die "only PNG, JPEG or WebP are supported: $f"
  size="$(wc -c < "$f" | tr -d ' ')"
  [ "$size" -le 20971520 ] || die "file is larger than 20 MiB, the per-file batch limit: $f"
  DECLARED="$(jq -c --arg name "$(basename "$f")" --argjson size "$size" --arg type "$type" \
    '. + [{name:$name,size:$size,type:$type}]' <<<"$DECLARED")"
done
BODY="$(jq -cn --arg output "$OUTPUT" --argjson files "$DECLARED" '{output:$output,files:$files}')"

auth=(-H "Authorization: Bearer $UNRASTER_API_KEY")

# Keep the same key for retries of this exact request. Pass UNRASTER_IDEMPOTENCY_KEY
# to resume after a lost response; otherwise a new one is generated.
KEY="${UNRASTER_IDEMPOTENCY_KEY:-$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)}"
echo "Idempotency-Key: $KEY (export UNRASTER_IDEMPOTENCY_KEY=$KEY to retry this exact request)" >&2

echo "Creating batch for ${#FILES[@]} file(s), output=$OUTPUT ..." >&2
CREATED="$(curl -sS --fail-with-body "$API/v1/batches" "${auth[@]}" \
  -H "Idempotency-Key: $KEY" -H "Content-Type: application/json" -d "$BODY")" \
  || die "could not create batch: ${CREATED:-see response above}"
BATCH="$(jq -r '.id' <<<"$CREATED")"
RESERVED="$(jq -r '.reserved_credits' <<<"$CREATED")"
echo "Batch $BATCH created; $RESERVED credit(s) reserved (only delivered files are charged)." >&2

i=0
for f in "${FILES[@]}"; do
  type="$(mime_for "$f")"
  echo "Uploading [$i] $f" >&2
  curl -sS --fail-with-body -X PUT "$API/v1/batches/$BATCH/files/$i" "${auth[@]}" \
    -F "file=@$f;type=$type" >/dev/null \
    || die "upload failed for $f"
  i=$((i + 1))
done

echo "Starting batch ..." >&2
curl -sS --fail-with-body -X POST "$API/v1/batches/$BATCH/start" "${auth[@]}" >/dev/null \
  || die "could not start batch"

waited=0
while :; do
  VIEW="$(curl -sS --fail-with-body "$API/v1/batches/$BATCH" "${auth[@]}")" || die "could not read batch"
  FINISHED="$(jq -r '.finished_at // empty' <<<"$VIEW")"
  if [ -n "$FINISHED" ]; then break; fi
  [ "$waited" -lt "$MAX_WAIT_SECONDS" ] || die "still running after ${MAX_WAIT_SECONDS}s; check batch $BATCH later"
  sleep "$POLL_SECONDS"
  waited=$((waited + POLL_SECONDS))
done

STATE="$(jq -r '.state' <<<"$VIEW")"
CHARGED="$(jq -r '.charged_credits' <<<"$VIEW")"
echo "Batch finished: state=$STATE, credits charged=$CHARGED." >&2
jq -r '.items[] | select(.state != "done") | "  not delivered: [\(.idx)] \(.file_name) (\(.state), \(.error_code // "no error code"))"' <<<"$VIEW" >&2 || true

if [ "$(jq -r '.counts.done' <<<"$VIEW")" = "0" ]; then
  die "no file was delivered, so there is no archive (nothing was charged)"
fi

code="$(curl -sS -o "$OUT_ZIP" -w '%{http_code}' "$API/v1/batches/$BATCH/archive" "${auth[@]}")" \
  || die "could not download the archive"
case "$code" in
  200) ;;
  410) rm -f -- "$OUT_ZIP"; die "batch $BATCH is past its 7-day retention period, so the archive is gone" ;;
  404) rm -f -- "$OUT_ZIP"; die "batch $BATCH has no delivered files to download" ;;
  *) rm -f -- "$OUT_ZIP"; die "could not download the archive (HTTP $code)" ;;
esac
echo "Saved $OUT_ZIP. Files are kept for 7 days; do not share the batch publicly." >&2
