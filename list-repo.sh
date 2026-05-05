#!/bin/bash
set -uo pipefail
trap 's=$?; echo "$0: Error on line $LINENO: $BASH_COMMAND"; exit $s' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: $ENV_FILE not found"
  exit 1
fi
source "$ENV_FILE"

"$SCRIPT_DIR/setup-remote.sh"

REMOTE_NAME="irao-arch"
REPO_NAME="irao-arch"
LOCAL_PATH="$SCRIPT_DIR/local-repo"
REMOTE_PATH="$REMOTE_NAME:$BUCKET_NAME/x86_64"
DB_FILE="$LOCAL_PATH/$REPO_NAME.db.tar.xz"

mkdir -p "$LOCAL_PATH"

echo "==> Syncing remote DB to local..."
rclone copy "$REMOTE_PATH/" "$LOCAL_PATH/" \
  --include "$REPO_NAME.db.tar.xz" \
  --include "$REPO_NAME.files.tar.xz" \
  --no-check-dest

echo "==> Packages in $REPO_NAME:"
tar -tf "$DB_FILE" 2>/dev/null | awk -F/ '{print $1}' | sort -u | while read -r pkg; do
  echo "  $pkg"
done
