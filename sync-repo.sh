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

mkdir -p "$LOCAL_PATH"

echo "==> Syncing remote DB to local..."
rclone copy "$REMOTE_PATH/" "$LOCAL_PATH/" \
  --include "$REPO_NAME.db.tar.xz" \
  --include "$REPO_NAME.files.tar.xz" \
  --no-check-dest

ln -sf "$REPO_NAME.db.tar.xz" "$LOCAL_PATH/$REPO_NAME.db"
ln -sf "$REPO_NAME.files.tar.xz" "$LOCAL_PATH/$REPO_NAME.files"

echo "==> Cleaning local package cache..."
rm -f "$LOCAL_PATH/"*.pkg.tar.xz "$LOCAL_PATH/"*.pkg.tar.zst

echo "==> Running aursync..."
aur sync --noview --repo "$REPO_NAME" --root "$LOCAL_PATH" "$@"

echo "==> Syncing local changes to remote..."
rclone copy -L "$LOCAL_PATH/" "$REMOTE_PATH/" \
  --include "*.pkg.tar.xz" \
  --include "*.pkg.tar.zst" \
  --include "$REPO_NAME.db" \
  --include "$REPO_NAME.db.tar.xz" \
  --include "$REPO_NAME.files" \
  --include "$REPO_NAME.files.tar.xz"

echo "==> Refreshing pacman DB..."
sudo pacsync "$REPO_NAME"

echo "Done."
