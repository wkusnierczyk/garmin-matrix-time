#!/usr/bin/env bash
# The Lite invariant (#135): Premium-only files must not change the Lite build.
#
#   tools/check-lite-invariant.sh <product>...
#
# SDK_BIN and DEV_KEY come from the environment; "make check-lite" passes both, and
# DEVICES as the product list.
#
# For each product, Lite is built twice as a release build: once from this tree, and
# once from a copy of it with every Premium-only file deleted. The two PRGs must be
# identical. What that catches is a Premium file reaching Lite's build -- premium/
# on Lite's sourcePath or resourcePath, a Premium resource overriding a Lite one, a
# jungle change that leaks -- which nothing else would report, because Lite still
# compiles and still runs.
#
# Release builds, because only they are comparable: a debug build embeds the
# absolute build path and line numbers, so the copy would differ from the tree
# whatever it contained (#35, finding 4). The signature is deterministic for a given
# key, so both builds are signed with the same one.
#
# What this does NOT catch is a (:premium) declaration in a shared file leaking into
# Lite: the copy has the same shared file and the same lite.jungle, so both builds
# would leak alike. That is lite.jungle's exclusion, and the (:test :premium) test in
# source/tests/EditionTest.mc is what fails if it is dropped.
set -eu

# Every file that exists for Premium alone. Delete any of these and Lite must build
# exactly as before. A new Premium-only file outside premium/ belongs on this list.
PREMIUM_ONLY=(premium premium.jungle manifest-premium.xml)

cd "$(dirname "$0")/.."

if [ $# -eq 0 ]; then
    echo "usage: $0 <product>..." >&2
    exit 2
fi
: "${SDK_BIN:?SDK_BIN is not set; run this through \"make check-lite\"}"
: "${DEV_KEY:?DEV_KEY is not set; run this through \"make check-lite\"}"

# Absolute, because the second build runs from the copy, where a relative key path
# would point somewhere else.
key="$(cd "$(dirname "$DEV_KEY")" && pwd)/$(basename "$DEV_KEY")"
test -f "$key" || { echo "Developer key not found: $DEV_KEY" >&2; exit 1; }

work=$(mktemp -d "${TMPDIR:-/tmp}/lite-invariant.XXXXXX")
trap 'rm -rf "$work"' EXIT

# The copy is what git would commit from here -- tracked files and new ones, as they
# are on disk, minus whatever .gitignore excludes -- not the whole directory, so
# build output, a developer key and .git itself stay behind. A tracked file deleted
# from disk is skipped rather than handed to tar, which would fail on it.
#
# safe.directory because in a CI container job the checkout belongs to another user,
# and git refuses to read a repository it does not own without being told to.
copy="$work/tree"
mkdir "$copy"
git -c safe.directory="$PWD" ls-files -z --cached --others --exclude-standard |
    while IFS= read -r -d '' f; do
        if [ -e "$f" ] || [ -L "$f" ]; then printf '%s\0' "$f"; fi
    done |
    tar --null -T - -cf - | tar -xf - -C "$copy"

for f in "${PREMIUM_ONLY[@]}"; do
    rm -rf "${copy:?}/$f"
done

build() {  # <directory> <product> <output>
    make -C "$1" --no-print-directory build EDITION=lite RELEASE=1 DEVICE="$2" \
         SDK_BIN="$SDK_BIN" DEV_KEY="$key" OUTPUT="$3" > "$3.log" 2>&1 || {
        cat "$3.log"
        echo "FAIL  $2: the Lite build failed in $1" >&2
        exit 1
    }
}

echo "Building Lite with and without the Premium files (${PREMIUM_ONLY[*]})..."
status=0
for product in "$@"; do
    build . "$product" "$work/$product-with.prg"
    build "$copy" "$product" "$work/$product-without.prg"
    with=$(shasum -a 256 "$work/$product-with.prg" 2>/dev/null || sha256sum "$work/$product-with.prg")
    with=${with%% *}
    if cmp -s "$work/$product-with.prg" "$work/$product-without.prg"; then
        printf "  OK    %-24s %s\n" "$product" "${with:0:12}"
    else
        printf "  FAIL  %-24s %s\n" "$product" "the Premium files change the Lite release build"
        status=1
    fi
done

if [ $status -ne 0 ]; then
    echo
    echo "A Premium-only change reached Lite. Lite is frozen; see \"Editions\" in README.md."
fi
exit $status
