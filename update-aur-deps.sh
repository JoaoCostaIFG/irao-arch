#!/bin/bash
set -uo pipefail
trap 's=$?; echo "$0: Error on line $LINENO: $BASH_COMMAND"; exit $s' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="$SCRIPT_DIR/packages"
AUR_CONF="$SCRIPT_DIR/aur-packages.conf"

read_aur_packages() {
  [[ -f "$AUR_CONF" ]] || return 0
  grep -v '^\s*#' "$AUR_CONF" | grep -v '^\s*$' | sed 's/\s*#.*//' || true
}

is_official_pkg() {
  local repo
  repo=$(pacman -Si "$1" 2>/dev/null | awk '/^Repository/ {print $3}')
  [[ "$repo" == "core" || "$repo" == "extra" || "$repo" == "multilib" ]]
}

get_custom_pkgs() {
  local pkg_dir
  for pkg_dir in "$PACKAGES_DIR"/*/; do
    [[ -d "$pkg_dir" ]] || continue
    echo "$(basename "$pkg_dir")"
    bash -c "source '$pkg_dir/PKGBUILD' 2>/dev/null; echo \"\$pkgname\"; if [[ \${#provides[@]} -gt 0 ]]; then printf '%s\n' \"\${provides[@]}\"; fi"
  done | sort -u
}

auto_detect_aur_deps() {
  echo "==> Scanning packages/*/PKGBUILD for AUR dependencies..."
  local deps=()
  local dep custom_pkgs tracked new_aur_pkgs=()

  for pkgbuild in "$PACKAGES_DIR"/*/PKGBUILD; do
    [[ -f "$pkgbuild" ]] || continue
    mapfile -t pkg_deps < <(
      awk "/^depends=\(/,/\)/{print}" "$pkgbuild" \
        | grep -v "^depends=(" | grep -v "^)" \
        | sed "s/'//g;s/[[:space:]]//g" \
        | grep -v '^\s*$'
    )
    deps+=("${pkg_deps[@]}")
  done

  local -A custom_set=()
  local -A tracked_set=()
  local -A seen=()

  while IFS= read -r custom_pkgs; do
    [[ -n "$custom_pkgs" ]] && custom_set["$custom_pkgs"]=1
  done < <(get_custom_pkgs)

  while IFS= read -r tracked; do
    [[ -n "$tracked" ]] && tracked_set["$tracked"]=1
  done < <(read_aur_packages)

  for dep in "${deps[@]}"; do
    [[ -z "$dep" ]] && continue
    [[ -n "${seen[$dep]:-}" ]] && continue
    seen[$dep]=1

    [[ -n "${custom_set[$dep]:-}" ]] && continue
    [[ -n "${tracked_set[$dep]:-}" ]] && continue

    if ! is_official_pkg "$dep"; then
      new_aur_pkgs+=("$dep")
    fi
  done

  if [[ ${#new_aur_pkgs[@]} -gt 0 ]]; then
    echo "  -> New AUR dependencies detected: ${new_aur_pkgs[*]}"
    for pkg in "${new_aur_pkgs[@]}"; do
      echo "$pkg" >> "$AUR_CONF"
      echo "  -> Added $pkg to $AUR_CONF"
    done
    sort -o "$AUR_CONF" "$AUR_CONF"
    echo "  -> Sorted $AUR_CONF"
  else
    echo "  -> No new AUR dependencies found."
  fi
}

auto_detect_aur_deps