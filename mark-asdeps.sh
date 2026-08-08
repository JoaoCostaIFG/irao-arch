#!/bin/bash
### Mark dependencies of installed meta-packages as dependency-installed
### so they show up as orphans if the meta-package is later removed
###
### Usage: mark-asdeps.sh
###
### Examples:
###   mark-asdeps.sh
set -uo pipefail
trap 's=$?; echo "$0: Error on line $LINENO: $BASH_COMMAND"; exit $s' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="$SCRIPT_DIR/packages"

for pkgbuild in "$PACKAGES_DIR"/*/PKGBUILD; do
    pkg_name=$(basename "$(dirname "$pkgbuild")")
    if pacman -Qi "$pkg_name" &>/dev/null; then
        echo "==> Marking dependencies of $pkg_name as deps..."
        deps=$(awk '/^depends=\(/,/\)/' "$pkgbuild" | grep "'" | sed "s/.*'\(.*\)'.*/\1/")
        installed_deps=()
        for dep in $deps; do
            if real=$(pacman -Qq "$dep" 2>/dev/null); then
                installed_deps+=("$real")
            else
                echo "  -> $dep not installed, skipping"
            fi
        done
        if [[ ${#installed_deps[@]} -gt 0 ]]; then
            sudo pacman -D --asdeps "${installed_deps[@]}"
        fi
    else
        echo "==> Skipping $pkg_name (not installed)"
    fi
done
