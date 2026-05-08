#!/bin/bash
set -uo pipefail
trap 's=$?; echo "$0: Error on line $LINENO: $BASH_COMMAND"; exit $s' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [[ ! -f $ENV_FILE ]]; then
    echo "Error: $ENV_FILE not found"
    exit 1
fi

source "$ENV_FILE"
for var in S3_ENDPOINT ACCESS_KEY_ID ACCESS_KEY_SECRET; do
    if [[ -z ${!var:-} ]]; then
        echo "Error: $var is not set in $ENV_FILE"
        exit 1
    fi
done

REMOTE_NAME="irao-arch"

if rclone listremotes 2>/dev/null | grep -q "^$REMOTE_NAME:"; then
    if [[ ${1:-} == "--recreate" ]]; then
        echo "Deleting existing remote '$REMOTE_NAME'..."
        rclone config delete "$REMOTE_NAME"
    else
        echo "Remote '$REMOTE_NAME' already exists, skipping."
        exit 0
    fi
fi

echo "Creating rclone remote '$REMOTE_NAME'..."
rclone config create "$REMOTE_NAME" s3 \
    provider=Other \
    env_auth=false \
    access_key_id="$ACCESS_KEY_ID" \
    secret_access_key="$ACCESS_KEY_SECRET" \
    endpoint="$S3_ENDPOINT" \
    force_path_style=true

echo "Remote '$REMOTE_NAME' created successfully."
