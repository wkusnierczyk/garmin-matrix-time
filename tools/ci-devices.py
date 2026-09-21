#!/usr/bin/env python3
"""Print the CI build set: one product per deviceFamily, as "<family> <product>".

Compiling every product in manifest.xml would be fifty-odd builds of, mostly, the
same inputs. Resource qualifiers resolve per deviceFamily, so within a family the
compiler sees the same sources, the same bitmaps and the same layout; one product
per family is the smallest set that still compiles every resolution and shape the
face ships. That is the drift which has actually broken this project (#21, #22,
#36, #37), and it is what the Stage-1 build job in #41 is for.

Families come from the SDK's own device definitions rather than from the
resources-<shape>-<WxH>/ directory names, so a product added to the manifest is
covered the moment it is added and there is no second list here to forget. A
product the manifest names but the SDK has no definition for is an error rather
than a skip: that is exactly the state in which `monkeyc -e` fails at release
time (#37), and CI is the right place to hear about it first.

The representative is the alphabetically first product in its family. Which one
it is does not matter -- that is the point of grouping by family -- so the rule
is the one that needs no judgement and does not shift under a diff.

Usage:
  tools/ci-devices.py            print "<family> <product>", one per line

Needs nothing but Python, and the device definitions the SDK manager downloads.
"""
import json
import os
import re
import sys

MANIFEST = 'manifest.xml'

# The SDK manager keeps device definitions outside the SDK itself, in a per-user
# directory whose path differs by platform. The container CI builds in (see
# .github/workflows/build.yml) is Linux; a developer running this by hand is on
# macOS. Probe both rather than make the caller say which.
DEVICE_DIRS = [
    '~/Library/Application Support/Garmin/ConnectIQ/Devices',
    '~/.Garmin/ConnectIQ/Devices',
]


def devices_dir():
    for d in DEVICE_DIRS:
        p = os.path.expanduser(d)
        if os.path.isdir(p):
            return p
    sys.exit('no device definitions found; looked in:\n  '
             + '\n  '.join(os.path.expanduser(d) for d in DEVICE_DIRS))


def products():
    return re.findall(r'<iq:product id="([^"]+)"', open(MANIFEST).read())


def family(root, product):
    """The product's deviceFamily, e.g. round-416x416."""
    f = os.path.join(root, product, 'compiler.json')
    if not os.path.exists(f):
        return None
    return json.load(open(f))['deviceFamily']


def main():
    root = devices_dir()
    ids = products()
    missing = [p for p in ids if family(root, p) is None]
    if missing:
        sys.exit(f'{MANIFEST} names products with no device definition under\n'
                 f'  {root}\n'
                 f'  {", ".join(missing)}\n'
                 'Download them in the SDK manager; monkeyc cannot build without them.')

    families = {}
    for p in sorted(ids):
        families.setdefault(family(root, p), p)
    for f in sorted(families):
        print(f, families[f])
    return 0


if __name__ == '__main__':
    sys.exit(main())
