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
: "${SDK_BIN:?SDK_BIN is not set; run this through \"make export VERSION=beta\"}"
: "${DEV_KEY:?DEV_KEY is not set; run this through \"make export VERSION=beta\"}"
: "${EDITION:?EDITION is not set}"
: "${MANIFEST:?MANIFEST is not set}"
: "${APP:?APP is not set}"
: "${BETA_ID:?BETA_ID is not set}"

key="$(cd "$(dirname "$DEV_KEY")" && pwd)/$(basename "$DEV_KEY")"
test -f "$key" || { echo "Developer key not found: $DEV_KEY" >&2; exit 1; }

# The id is the one attribute that differs, so it is found by the element, not by its value:
# a public id that changes needs nothing here.
application_id() {  # <manifest>
    sed -nE 's/.*<iq:application[^>]* id="([^"]*)".*/\1/p' "$1"
}
public_id="$(application_id "$MANIFEST")"
test -n "$public_id" || { echo "No <iq:application id=...> in $MANIFEST" >&2; exit 1; }
test "$public_id" != "$BETA_ID" || { echo "BETA_ID is $MANIFEST's own id" >&2; exit 1; }

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
test "$(application_id "$copy/$MANIFEST")" = "$BETA_ID" ||
    { echo "Could not put the beta id into the copy of $MANIFEST" >&2; exit 1; }
diff "$MANIFEST" "$copy/$MANIFEST" | grep -c '^[<>]' | grep -qx 2 ||
    { echo "The copy of $MANIFEST differs by more than its id" >&2; exit 1; }

echo "Exporting $APP as its beta, $BETA_ID, from a copy of the tree..."
make -C "$copy" --no-print-directory export EDITION="$EDITION" VERSION=public \
     SDK_BIN="$SDK_BIN" DEV_KEY="$key"

mkdir -p "$(dirname "$output")"
cp "$copy/export/$APP.iq" "$output"

# The bundle, not the copy, is what gets uploaded: check the id inside it. An .iq is a 7-zip
# archive, which libarchive's tar reads (macOS's tar is bsdtar; on Linux, install bsdtar).
# Its manifest is monkeyc's own rewrite, with the id lower case and without the hyphens.
untar=tar
command -v bsdtar > /dev/null && untar=bsdtar
bundled="$("$untar" -xOf "$output" manifest.xml 2> /dev/null |
    sed -nE 's/.*<iq:application[^>]* id="([^"]*)".*/\1/p')" ||
    true
want="$(printf '%s' "$BETA_ID" | tr -d '-' | tr '[:upper:]' '[:lower:]')"
test -n "$bundled" ||
    { rm -f "$output"; echo "Could not read manifest.xml from $output: needs a tar that reads 7-zip (bsdtar)" >&2; exit 1; }
test "$bundled" = "$want" ||
    { rm -f "$output"; echo "The bundle carries id $bundled, not the beta's $want" >&2; exit 1; }
echo "Beta export complete: $output, application id $BETA_ID"
