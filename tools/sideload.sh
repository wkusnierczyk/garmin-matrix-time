#!/bin/sh
# Copy a built .prg onto a USB-connected Garmin watch. Driven by "make sideload".
#
# The transport is MTP, not mass storage. macOS does not mount MTP devices as
# volumes, and the epix Pro (Gen 2) does not present itself as anything macOS will
# mount: with the watch attached, /Volumes stays empty and mtp-detect reports
# "Garmin EPIX Pro ... Device recognized as MTP". So the transfer goes through
# libmtp rather than cp.
#
# Two subcommands, because the target has to know which device to build for
# before it builds:
#
#   detect          print the Connect IQ device id of the attached watch
#   install <prg>   replace <prg> in GARMIN/Apps, then verify what landed
#
# libmtp's exit statuses carry almost nothing here, so every check below reads
# the output instead: mtp-sendfile exits 0 whether it transferred the file or
# skipped it entirely, mtp-delfile exits 1 for a file that was simply not there,
# and mtp-detect exits 0 with no device attached. Measured with libmtp 1.1.23.

set -eu

# Where Connect IQ apps live on the watch. Over MTP the folder is spelled "Apps",
# not the "APPS" of the mass-storage layout.
APPS=/GARMIN/Apps

# The SDK's per-device definitions, used to turn the watch's part number into a
# Connect IQ device id. Same default as the Makefile's CIQ_HOME, which passes its
# own value in.
CIQ_HOME=${CIQ_HOME:-$HOME/Library/Application Support/Garmin/ConnectIQ}

die() {
  for line in "$@"; do printf '%s\n' "$line"; done >&2
  exit 1
}

require_libmtp() {
  command -v mtp-files >/dev/null 2>&1 || die \
    "libmtp not found: mtp-files is not on PATH." \
    "The watch is an MTP device and macOS does not mount it as a volume, so the" \
    "transfer needs a CLI MTP client:" \
    "  brew install libmtp"
}

# Every libmtp tool prefixes its real output with one of these per folder on the
# device -- around 150 lines on a watch -- which buries everything worth reading.
quiet() {
  grep -v 'MTP extended association type' || true
}

# One listing of every file on the watch, reused by both subcommands and left in
# LISTING rather than written to stdout: the check below has to be able to end the
# run, and inside a command substitution "exit" would only end the subshell, which
# left the caller to carry on and report a second, wrong reason for the failure.
#
# mtp-files exits 0 with or without a device, so the listing itself is the signal:
# a watch that answers always has files on it.
LISTING=

load_listing() {
  LISTING=$(mtp-files 2>&1 | quiet)
  case $LISTING in
    *"File ID:"*) ;;
    *) die "No watch found: libmtp lists no files on a device." \
           "Connect the watch by USB and try again." ;;
  esac
}

cmd_detect() {
  require_libmtp

  # GarminDevice.xml carries the part number, which is the only identifier on the
  # watch that maps cleanly onto a Connect IQ device id. Its object id is not
  # fixed, so it is looked up by name.
  #
  # The names libmtp itself reports are not usable for this. On a fenix 7X Solar
  # it announces "Garmin Euduro 2" from its own device table -- a typo, and the
  # wrong product besides -- while the part number in this file, 006-B3907-00,
  # resolves to fenix7x correctly.
  load_listing
  id=$(printf '%s\n' "$LISTING" | awk '
    /^File ID:/                                    { found = $3 }
    $1 == "Filename:" && $2 == "GarminDevice.xml"  { print found; exit }')
  [ -n "$id" ] || die \
    "GARMIN/GarminDevice.xml is not on the watch, so the device cannot be identified." \
    "Build for it explicitly instead:  make sideload DEVICE=<device>"

  tmp=$(mktemp -t sideload) || die "Could not create a temporary file."
  trap 'rm -f "$tmp"' EXIT
  mtp-getfile "$id" "$tmp" >/dev/null 2>&1 || true
  [ -s "$tmp" ] || die "Could not read GarminDevice.xml off the watch."

  # There is exactly one <Model> element, so the anchor is unambiguous. The plain
  # <PartNumber> is not: the file carries some 140 more of them, belonging to maps
  # and other installed content.
  part=$(sed -n 's|.*<Model><PartNumber>\([^<]*\)</PartNumber>.*|\1|p' "$tmp")
  [ -n "$part" ] || die "GarminDevice.xml has no <Model><PartNumber>."

  # Part numbers are unique across the SDK's device definitions -- 151 of them
  # across the 89 devices installed when this was written, no collisions -- so a
  # plain match over compiler.json names the device without parsing the JSON.
  matches=$(grep -l -F "$part" "$CIQ_HOME"/Devices/*/compiler.json 2>/dev/null || true)
  count=$(printf '%s' "$matches" | grep -c . || true)
  case $count in
    1) ;;
    0) die "The watch reports part number $part, which matches no device definition in" \
           "  $CIQ_HOME/Devices" \
           "Download that device in the SDK manager, or name it yourself:" \
           "  make sideload DEVICE=<device>" ;;
    *) die "Part number $part matches more than one device definition:" "$matches" ;;
  esac

  basename "$(dirname "$matches")"
}

cmd_install() {
  prg=$1
  [ -f "$prg" ] || die "No such file: $prg"
  require_libmtp

  base=$(basename "$prg")
  size=$(wc -c < "$prg" | tr -d ' ')

  # Sending does not overwrite: the watch adds a second object under the same
  # name and leaves the first in place, one more on every transfer, so the old
  # copies go first. They are deleted by object id rather than by path, because
  # deleting by path resolves the name to whichever handle the device lists
  # first, and that one can be stale -- "Found a bad handle" -- while the file
  # itself stays put. Deleting the oldest id removes the file and every alias of
  # it at once, so the rest of the loop then fails harmlessly; failures are
  # ignored for the same reason a first install has nothing to delete.
  #
  # Scoping by name alone is enough: the destination folder is fixed below, and
  # what landed is checked by object id afterwards.
  load_listing
  printf '%s\n' "$LISTING" | awk -v want="$base" '
    /^File ID:/                          { found = $3 }
    $1 == "Filename:" && $2 == want      { print found }' |
  while read -r old; do
    mtp-delfile -n "$old" >/dev/null 2>&1 || true
  done

  # mtp-sendfile resolves its destination as an object that already exists, so a
  # full destination path is refused -- "Parent folder could not be found" -- for
  # a file that is not on the watch yet. Naming the folder works instead, and the
  # name on the watch is then the local basename. That refusal exits 0 like every
  # other outcome, so the new object id is what says the transfer happened, and
  # its absence is what says the folder was wrong.
  out=$(mtp-sendfile "$prg" "$APPS" 2>&1 | quiet)
  newid=$(printf '%s\n' "$out" | sed -n 's/^New file ID: \([0-9][0-9]*\)$/\1/p')
  if [ -z "$newid" ]; then
    printf '%s\n' "$out" >&2
    die "Transfer failed: $base is not on the watch."
  fi

  # Verify rather than trust: read the size back off the watch and compare. A
  # short file means the transfer stopped partway, and a half-written .prg fails
  # on the watch rather than at install time, so it is removed instead of left.
  load_listing
  landed=$(printf '%s\n' "$LISTING" | awk -v want="$newid" '
    /^File ID:/                                     { found = $3 }
    found == want && $1 == "File" && $2 == "size"   { print $3; exit }')
  if [ "$landed" != "$size" ]; then
    mtp-delfile -n "$newid" >/dev/null 2>&1 || true
    die "Transfer of $base was incomplete: $size bytes sent, ${landed:-nothing} on the watch." \
        "The partial copy has been removed. Reconnect the watch and try again."
  fi

  echo "Installed $base ($size bytes) to $APPS."
}

case ${1:-} in
  detect)  cmd_detect ;;
  install) [ $# -eq 2 ] || die "usage: $0 install <prg>"; cmd_install "$2" ;;
  *)       die "usage: $0 detect | install <prg>" ;;
esac
