#!/usr/bin/env bash
# make export VERSION=beta (#201): the edition's store bundle under the application id of its
# store beta, a separate Connect IQ app, with the public id left where it is.
#
# A beta is the public export of a copy of the tree whose manifest carries the beta id. The
# copy is the point: monkeyc takes the manifest from the edition jungle's project.manifest,
# will not let a later jungle set it again ("Attempting to reset project property
# 'manifest'"), and refuses -m alongside -f. Editing the tracked manifest in place and
# restoring it afterwards would leave the beta id in it after an interrupted run, where the
# next public export or a commit would pick it up -- and an upload publishes at once (#121).
# So the tree is copied as "make check-lite" copies it, the copy's manifest is rewritten, and
# the ordinary "make export" runs in the copy: same sources, same jungles, same flags.
#
# Usage, through the Makefile:
#   SDK_BIN=... DEV_KEY=... EDITION=premium MANIFEST=manifest-premium.xml APP=MatrixTimePremium \
#   BETA_ID=<uuid> tools/export-beta.sh export/MatrixTimePremium-beta.iq
set -eu
cd "$(dirname "$0")/.."

if [ $# -ne 1 ]; then
    echo "usage: $0 <output .iq>" >&2
    exit 2
fi
output="$1"
# The previous beta bundle goes first, before anything can fail: a run that stops part way
# must not leave it at the path that gets uploaded, where it would pass for this run's (#121).
rm -f "$output"
: "${SDK_BIN:?SDK_BIN is not set; run this through \"make export VERSION=beta\"}"
: "${DEV_KEY:?DEV_KEY is not set; run this through \"make export VERSION=beta\"}"
: "${EDITION:?EDITION is not set}"
: "${MANIFEST:?MANIFEST is not set}"
: "${APP:?APP is not set}"
: "${BETA_ID:?BETA_ID is not set}"

key="$(cd "$(dirname "$DEV_KEY")" && pwd)/$(basename "$DEV_KEY")"
test -f "$key" || { echo "Developer key not found: $DEV_KEY" >&2; exit 1; }
# Absolute too: the export below runs in the copy, where a relative SDK_BIN, which the
# outer make accepted, would lead nowhere.
sdk="$(cd "$SDK_BIN" 2> /dev/null && pwd)" || { echo "Connect IQ SDK not found at $SDK_BIN" >&2; exit 1; }

# The id is the one attribute that differs, so it is found by the element, not by its value:
# a public id that changes needs nothing here.
application_id() {  # <manifest> on stdin
    sed -nE 's/.*<iq:application[^>]* id="([^"]*)".*/\1/p'
}
# Ids compared as monkeyc writes them into a bundle: lower case, without the hyphens.
normal() {
    printf '%s' "$1" | tr -d '-' | tr '[:upper:]' '[:lower:]'
}
public_id="$(application_id < "$MANIFEST")"
test -n "$public_id" || { echo "No <iq:application id=...> in $MANIFEST" >&2; exit 1; }
test "$(normal "$public_id")" != "$(normal "$BETA_ID")" ||
    { echo "$MANIFEST already carries the beta id; put the public one back" >&2; exit 1; }

# The bundle is checked by reading its manifest back out, and an .iq is a 7-zip archive, which
# libarchive's tar reads: macOS's tar is bsdtar; on Linux, install bsdtar (Debian and Ubuntu:
# libarchive-tools). GNU tar cannot. Found before the build rather than after it.
untar=tar
command -v bsdtar > /dev/null && untar=bsdtar
"$untar" --version 2> /dev/null | grep -q libarchive ||
    { echo "Needs a tar that reads 7-zip (bsdtar, from libarchive) to check the bundle" >&2; exit 1; }

work=$(mktemp -d "${TMPDIR:-/tmp}/export-beta.XXXXXX")
trap 'rm -rf "$work"' EXIT
copy="$work/tree"
mkdir "$copy"

# What git would commit, as check-lite-invariant.sh copies it: tracked and untracked files
# alike, ignored ones left out, a file staged for deletion skipped.
git -c safe.directory="$PWD" ls-files -z --cached --others --exclude-standard |
    while IFS= read -r -d '' f; do
        if [ -e "$f" ] || [ -L "$f" ]; then printf '%s\0' "$f"; fi
    done |
    tar --null -T - -cf - | tar -xf - -C "$copy"

sed -E "s/(<iq:application[^>]* id=\")$public_id\"/\1$BETA_ID\"/" "$MANIFEST" > "$copy/$MANIFEST"
test "$(application_id < "$copy/$MANIFEST")" = "$BETA_ID" ||
    { echo "Could not put the beta id into the copy of $MANIFEST" >&2; exit 1; }
diff "$MANIFEST" "$copy/$MANIFEST" | grep -c '^[<>]' | grep -qx 2 ||
    { echo "The copy of $MANIFEST differs by more than its id" >&2; exit 1; }

# The ordinary public export, in the copy. MAKEFLAGS is cleared so that nothing from the outer
# command line but what is passed here reaches it: an EXPORT_DIR given there would otherwise
# send the inner bundle out of the copy under the public name. EXPORT names the beta, so that
# what the inner make prints does too. BETA_ID is emptied because the copy's manifest carries
# the beta id on purpose, which the public export otherwise refuses.
inner="export/$APP-beta.iq"
echo "Exporting $APP as its beta, $BETA_ID, from a copy of the tree..."
MAKEFLAGS= MFLAGS= make -C "$copy" --no-print-directory export EDITION="$EDITION" VERSION=public \
     BETA_ID= EXPORT="$inner" SDK_BIN="$sdk" DEV_KEY="$key"

# The bundle, not the copy's manifest, is what gets uploaded: check the id inside it, and only
# then give it its name under export/. Its manifest is monkeyc's own rewrite.
bundled="$("$untar" -xOf "$copy/$inner" manifest.xml 2> /dev/null | application_id)" || true
test -n "$bundled" || { echo "Could not read manifest.xml from the bundle" >&2; exit 1; }
test "$(normal "$bundled")" = "$(normal "$BETA_ID")" ||
    { echo "The bundle carries id $bundled, not the beta's $BETA_ID" >&2; exit 1; }

mkdir -p "$(dirname "$output")"
cp "$copy/$inner" "$output"
echo "Beta export complete: $output, application id $BETA_ID"
