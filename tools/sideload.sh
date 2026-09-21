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

# Exit 1 for "this went wrong", exit 2 for "no watch answered". The caller needs
# to tell those apart: an explicit DEVICE is a usable answer to a watch that
# cannot be identified, and no answer at all to a watch that is not there.
die() {
  for line in "$@"; do printf '%s\n' "$line"; done >&2
  exit 1
}

die_no_watch() {
  for line in "$@"; do printf '%s\n' "$line"; done >&2
  exit 2
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
    *) die_no_watch "No watch found: libmtp lists no files on a device." \
                    "Connect the watch by USB and try again." ;;
  esac
}

# Resolve a folder path to its object id. mtp-folders prints "<id>\t<indent><name>",
# two spaces per level of nesting, so the path is rebuilt from the indent depth
# rather than assumed. Needed because mtp-files reports a Parent ID but no folder
# names, and scoping a delete to a folder is the whole point of having it.
folder_id() {
  mtp-folders 2>&1 | quiet | awk -F'\t' -v want="$1" '
    NF < 2 { next }
    {
      name = $2
      depth = match(name, /[^ ]/) - 1
      sub(/^ +/, "", name)
      path[depth] = name
      full = ""
      for (d = 0; d <= depth; d += 2) full = full "/" path[d]
      if (full == want) { print $1; exit }
    }'
}

# Object ids of the files named $2 directly inside folder id $1, newest last.
# Filename is read off the rest of the line rather than as a field, so a name
# containing spaces still matches; it precedes Parent ID in each record, so the
# decision waits for the parent.
ids_in_folder() {
  printf '%s\n' "$LISTING" | awk -v parent="$1" -v want="$2" '
    /^File ID:/ { id = $3; fname = "" }
    $1 == "Filename:" { fname = $0; sub(/^[ \t]*Filename:[ \t]*/, "", fname) }
    $1 == "Parent" && $2 == "ID:" && fname == want && $3 == parent { print id }'
}

cmd_detect() {
  require_libmtp

  # GarminDevice.xml carries the part number, which is the only identifier on the
  # watch that maps cleanly onto a Connect IQ device id. Its object id is not
  # fixed, so it is looked up by name.
  #
  # The names libmtp itself reports are not usable for this. They come from its own
  # USB device table, which names a hardware family rather than a Connect IQ
  # product, and nothing maps one to the other: a fenix 7X Solar is announced as
  # "Garmin Euduro 2" -- Enduro 2 is a genuine sibling of that family, sharing both
  # the USB product id and the fenix7x device definition, but the spelling is
  # libmtp's own typo. The part number in this file, 006-B3907-00, resolves to
  # fenix7x with no guessing at all.
  load_listing
  id=$(printf '%s\n' "$LISTING" | awk '
    /^File ID:/                                    { found = $3 }
    $1 == "Filename:" && $2 == "GarminDevice.xml"  { print found; exit }')
  [ -n "$id" ] || die \
    "GARMIN/GarminDevice.xml is not on the watch, so the device cannot be identified." \
    "Name the device yourself and the detection is skipped:" \
    "  make sideload DEVICE=<device>"

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
           "Download that device in the SDK manager. Or name it yourself, which" \
           "skips the detection entirely:" \
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

  # The listing is loaded before anything else so that an absent watch is reported
  # as an absent watch, rather than as the missing Apps folder it would otherwise
  # look like a moment later.
  load_listing

  # Everything below is scoped to this one folder. Resolving it first also turns a
  # watch with no Apps folder into a refusal here, before anything is deleted or
  # sent, rather than into the silent skip mtp-sendfile would answer with.
  apps=$(folder_id "$APPS")
  [ -n "$apps" ] || die \
    "$APPS does not exist on the watch, so there is nowhere to install to." \
    "Connect a watch that runs Connect IQ apps."

  # Sending does not overwrite: the watch adds a second object under the same name
  # and leaves the first in place, one more on every transfer, so the old copies go
  # first. They are matched on folder as well as name -- deleting every object that
  # merely shares the basename would reach unrelated files elsewhere on the watch,
  # and a wrongly named build would then destroy one of them.
  #
  # They are deleted by object id rather than by path, because deleting by path
  # resolves the name to whichever handle the device lists first, and that one can
  # be stale -- "Found a bad handle" -- while the file itself stays put. Deleting
  # the oldest id removes the file and every alias of it at once, which is why the
  # rest of the loop is expected to fail and its failures are ignored. What is not
  # ignored is the result: the folder is re-read afterwards, and anything still
  # standing stops the run rather than being papered over with a duplicate.
  old=$(ids_in_folder "$apps" "$base")
  if [ -n "$old" ]; then
    printf '%s\n' "$old" | while read -r id; do
      mtp-delfile -n "$id" >/dev/null 2>&1 || true
    done
    load_listing
    still=$(ids_in_folder "$apps" "$base")
    [ -z "$still" ] || die \
      "Could not remove the copy of $base already on the watch." \
      "Sending now would leave two files of that name. Disconnect the watch," \
      "reconnect it and try again."
  fi

  # mtp-sendfile resolves its destination as an object that already exists, so a
  # full destination path is refused -- "Parent folder could not be found" -- for
  # a file that is not on the watch yet. Naming the folder works instead, and the
  # name on the watch is then the local basename. That refusal exits 0 like every
  # other outcome, so the new object id is what says the transfer happened.
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
