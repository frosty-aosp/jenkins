#!/usr/bin/env bash
# Uploads the newest build artifact for one device to S3.
# Usage: upload_artifacts.sh <out/target/product/<codename> dir> <codename>
# Requires: S3_BUCKET env var, aws-cli configured (credentials injected by
# the Jenkins withCredentials block, or an instance IAM role).
set -euo pipefail

OUT_DIR="$1"
CODENAME="$2"
DATE_TAG="$(date +%Y%m%d)"

ZIP_PATH="$(ls -t "${OUT_DIR}"/frosty_${CODENAME}_ananas*.zip 2>/dev/null | head -n1 || true)"

if [ -z "$ZIP_PATH" ]; then
    echo "No build artifact found for ${CODENAME} in ${OUT_DIR}" >&2
    exit 1
fi

if [ $FROSTY_BUILDTYPE == "UNOFFICIAL"]; then
    DEST="${S3_BUCKET:?S3_BUCKET not set}/testing/${CODENAME}/"
else
    DEST="${S3_BUCKET:?S3_BUCKET not set}/${CODENAME}/"
    UPLOAD_OTA=true
fi

echo "Uploading ${ZIP_PATH} to ${DEST}"
aws s3 cp "$ZIP_PATH" "$DEST"

if [ -f "${ZIP_PATH}.sha256sum" ]; then
    aws s3 cp "${ZIP_PATH}.sha256sum" "$DEST"
fi

if [[ -f "${ZIP_PATH}.json" && $UPLOAD_OTA == true ]]; then
    aws s3 cp "${ZIP_PATH}.json" "${S3_BUCKET}/json/ananas/${CODENAME}.json"
fi

echo "Done: ${CODENAME} (${DATE_TAG})"
