#!/bin/bash
### Sort depends arrays in PKGBUILDs alphabetically
###
### Usage: sort-depends.sh
###
### Examples:
###   sort-depends.sh
set -euo pipefail

sort_depends_in_file() {
    local file="$1"
    local tmpfile
    tmpfile="$(mktemp)"

    awk '
    /^[[:space:]]*(depends|makedepends|checkdepends|optdepends)=\(/ {
        in_depends = 1; depth = 0; count = 0; print; next
    }
    in_depends {
        for (i = 1; i <= length($0); i++) {
            c = substr($0, i, 1)
            if (c == "(") depth++
            else if (c == ")") depth--
        }
        if (depth < 0) {
            if (count > 0) {
                cmd = "LC_ALL=C sort"
                for (i = 1; i <= count; i++) print lines[i] | cmd
                close(cmd)
            }
            in_depends = 0; count = 0; print; next
        }
        lines[++count] = $0
        next
    }
    { print }
    ' "$file" > "$tmpfile"

    if ! cmp -s "$file" "$tmpfile"; then
        mv "$tmpfile" "$file"
        echo "Sorted depends in ${file#./}"
        return 0
    else
        rm "$tmpfile"
        return 1
    fi
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

changed=0
for pkgbuild in packages/*/PKGBUILD; do
    if [ -f "$pkgbuild" ]; then
        sort_depends_in_file "$pkgbuild" && changed=1
    fi
done

if [ "$changed" -eq 0 ]; then
    echo "All PKGBUILD depends arrays are already sorted."
fi
