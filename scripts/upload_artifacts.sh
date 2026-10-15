#!/usr/bin/env bash
# Uploads the newest build artifact for one device to S3.
# Usage: upload_artifacts.sh <out/target/product/<codename> dir> <codename>
# Requires: S3_BUCKET env var, aws-cli configured (credentials injected by
# the Jenkins withCredentials block, or an instance IAM role).
set -euo pipefail

OUT_DIR="$1"
CODENAME="$2"

ZIP_PATH="$(ls -t "${OUT_DIR}"/frosty_${CODENAME}_ananas*.zip 2>/dev/null | head -n1 || true)"

if [ -z "$ZIP_PATH" ]; then
    echo "No build artifact found for ${CODENAME} in ${OUT_DIR}" >&2
    exit 1
fi

if [[ $FROSTY_BUILDTYPE == "UNOFFICIAL" ]]; then
    DEST="${S3_BUCKET:?S3_BUCKET not set}/testing/${CODENAME}/"

    echo "Uploading ${ZIP_PATH} to ${DEST}"
    aws s3 cp "$ZIP_PATH" "$DEST"

    if [ -f "${ZIP_PATH}.sha256sum" ]; then
        aws s3 cp "${ZIP_PATH}.sha256sum" "$DEST"
    fi
else
    UPLOAD_OTA=true
fi

if [[ -f "${ZIP_PATH}.json" && $UPLOAD_OTA == true ]]; then
    DEST_PATH="$(jq -r '.[0].files.[0].filepath' "$ZIP_PATH.json" | cut -d\/ -f-3)"
    DEST="${S3_BUCKET:?S3_BUCKET not set}/${DEST_PATH}/"

    EXTRA_NAMES="$(jq -r '.[0].files[] | .filename' "$ZIP_PATH.json")"
    while IFS= read -r name; do
        [[ -n $name ]] || continue
        echo "Uploading ${name} to ${DEST}"
        aws s3 cp "${OUT_DIR}/${name}" "$DEST"
    done <<<"$EXTRA_NAMES"

    echo "Uploading ${ZIP_PATH}.json to ${S3_BUCKET}/json/ananas/${CODENAME}.json"
    aws s3 cp "$ZIP_PATH.json" "${S3_BUCKET}/json/ananas/${CODENAME}.json"
fi

echo "Done: ${CODENAME}"
