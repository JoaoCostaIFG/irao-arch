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
PACKAGES_DIR="$SCRIPT_DIR/packages"

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

# --- Build local meta-packages from packages/ ---
LOCAL_PKGS=()
AUR_ARGS=()
BUILD_ALL_LOCAL=false

for arg in "$@"; do
  if [[ "$arg" == "-u" ]]; then
    BUILD_ALL_LOCAL=true
    AUR_ARGS+=("$arg")
  elif [[ -d "$PACKAGES_DIR/$arg" ]]; then
    LOCAL_PKGS+=("$arg")
  else
    AUR_ARGS+=("$arg")
  fi
done

# If no args passed, build all local packages and sync all tracked AUR packages
if [[ $# -eq 0 ]]; then
  BUILD_ALL_LOCAL=true
fi

if $BUILD_ALL_LOCAL && [[ -d "$PACKAGES_DIR" ]]; then
  for dir in "$PACKAGES_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    LOCAL_PKGS+=("$(basename "$dir")")
  done
fi

if [[ ${#LOCAL_PKGS[@]} -gt 0 ]]; then
  echo "==> Building local packages: ${LOCAL_PKGS[*]}"
  for pkg in "${LOCAL_PKGS[@]}"; do
    pkg_dir="$PACKAGES_DIR/$pkg"
    echo "  -> Building $pkg..."
    (cd "$pkg_dir" && makepkg -cdf --noconfirm)
    cp "$pkg_dir"/*.pkg.tar.* "$LOCAL_PATH/"
    repo-add "$LOCAL_PATH/$REPO_NAME.db.tar.xz" "$pkg_dir"/*.pkg.tar.*
    rm -f "$pkg_dir"/*.pkg.tar.*
  done
fi

# --- Build/sync AUR packages ---
if [[ ${#AUR_ARGS[@]} -gt 0 ]] || [[ $# -eq 0 ]]; then
  echo "==> Running aursync..."
  aur sync --noview --repo "$REPO_NAME" --root "$LOCAL_PATH" "${AUR_ARGS[@]}"
fi

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
