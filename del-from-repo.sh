#!/bin/bash
### Remove packages from the irao-arch repo
###
### Usage: del-from-repo.sh <package> [package ...]
###
### Examples:
###   del-from-repo.sh some-pkg
###   del-from-repo.sh pkg1 pkg2 pkg3
set -uo pipefail
trap 's=$?; echo "$0: Error on line $LINENO: $BASH_COMMAND"; exit $s' ERR

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <package> [package ...]"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [[ ! -f $ENV_FILE ]]; then
    echo "Error: $ENV_FILE not found"
    exit 1
fi

source "$ENV_FILE"
"$SCRIPT_DIR/setup-remote.sh"

REMOTE_NAME="irao-arch"
REPO_NAME="irao-arch"
LOCAL_PATH="$SCRIPT_DIR/local-repo"
REMOTE_PATH="$REMOTE_NAME:$BUCKET_NAME/x86_64"
AUR_CONF="$SCRIPT_DIR/aur-packages.conf"

mkdir -p "$LOCAL_PATH"

echo "==> Syncing remote DB to local..."
rclone copy "$REMOTE_PATH/" "$LOCAL_PATH/" \
    --include "$REPO_NAME.db.tar.xz" \
    --include "$REPO_NAME.files.tar.xz" \
    --no-check-dest

ln -sf "$REPO_NAME.db.tar.xz" "$LOCAL_PATH/$REPO_NAME.db"
ln -sf "$REPO_NAME.files.tar.xz" "$LOCAL_PATH/$REPO_NAME.files"

echo "==> Removing packages from DB..."
repo-remove "$LOCAL_PATH/$REPO_NAME.db.tar.xz" "$@"

echo "==> Syncing updated DB to remote..."
rclone copy -L "$LOCAL_PATH/" "$REMOTE_PATH/" \
    --include "$REPO_NAME.db" \
    --include "$REPO_NAME.db.tar.xz" \
    --include "$REPO_NAME.files" \
    --include "$REPO_NAME.files.tar.xz"

for package in "$@"; do
    echo "==> Deleting $package files from remote..."
    rclone delete "$REMOTE_PATH/" \
        --include "$package-*.pkg.tar.xz" \
        --include "$package-*.pkg.tar.zst"
done

echo "==> Refreshing pacman DB..."
sudo pacsync "$REPO_NAME"

for package in "$@"; do
    if [[ -f $AUR_CONF ]] && grep -qx "$package" "$AUR_CONF"; then
        sed -i "/^${package}$/d" "$AUR_CONF"
        echo "  -> Removed $package from $AUR_CONF"
    fi
done

echo "Done."
