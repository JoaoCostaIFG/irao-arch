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
        if [[ -n $deps ]]; then
            sudo pacman -D --asdeps $deps
        fi
    else
        echo "==> Skipping $pkg_name (not installed)"
    fi
done
