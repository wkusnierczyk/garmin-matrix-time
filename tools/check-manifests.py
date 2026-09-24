#!/usr/bin/env python3
"""Verify the two edition manifests agree on everything they are meant to share.

manifest.xml is Lite's and manifest-premium.xml is Premium's (#135). Each jungle
names one, because monkeyc will not set project.manifest twice in one build, so the
product list -- and the permissions, languages, API level, entry point and launcher
icon with it -- exists twice. This is the check that the copies have not drifted:
a product added to one and not the other would ship one edition to a watch the
other does not support, and nothing else would notice.

Three things may differ, and one must:

  - the application id MUST differ. It is what makes Premium a separate app in the
    store and on the watch rather than an update of Lite;
  - the version may differ. Each edition is released on its own terms;
  - nothing else. The name is @Strings.AppName in both, and Premium's own name comes
    from premium/resources-base/strings/strings.xml, not from the manifest.

manifest.xml is the one to edit first; copy the change across. Pure Python, no SDK.
"""
import difflib
import re
import sys
import uuid

LITE = 'manifest.xml'
PREMIUM = 'manifest-premium.xml'

# The attributes of <iq:application> that are allowed to differ, replaced by a
# placeholder before the two files are compared as text.
PER_EDITION = ('id', 'version')

APPLICATION_RE = re.compile(r'<iq:application\b[^>]*>')

fail = []


def ok(cond, msg):
    print(f"  {'OK  ' if cond else 'FAIL'}  {msg}")
    if not cond:
        fail.append(msg)


def application(text, path):
    tags = APPLICATION_RE.findall(text)
    if len(tags) != 1:
        sys.exit(f"{path}: expected one <iq:application> element, found {len(tags)}")
    return tags[0]


def attribute(tag, name):
    m = re.search(rf'\s{name}="([^"]*)"', tag)
    return m.group(1) if m else None


def shared(text, tag):
    """The manifest with the per-edition attributes blanked out."""
    blanked = tag
    for name in PER_EDITION:
        blanked = re.sub(rf'(\s{name}=")[^"]*(")', rf'\g<1><per-edition>\g<2>', blanked)
    return text.replace(tag, blanked)


def valid_uuid(value):
    try:
        uuid.UUID(value)
        return True
    except (TypeError, ValueError):
        return False


texts = {path: open(path, encoding='utf-8').read() for path in (LITE, PREMIUM)}
tags = {path: application(text, path) for path, text in texts.items()}
ids = {path: attribute(tag, 'id') for path, tag in tags.items()}

print("\nEDITION MANIFESTS")
for path in (LITE, PREMIUM):
    ok(valid_uuid(ids[path]), f"{path} application id {ids[path]} is a UUID")
ok(ids[LITE] != ids[PREMIUM],
   "the editions have different application ids, so Premium is a separate app")

lite, premium = (shared(texts[p], tags[p]) for p in (LITE, PREMIUM))
same = lite == premium
ok(same, f"{PREMIUM} matches {LITE} in everything but {' and '.join(PER_EDITION)}")
if not same:
    sys.stdout.writelines(difflib.unified_diff(
        lite.splitlines(keepends=True), premium.splitlines(keepends=True),
        fromfile=LITE, tofile=PREMIUM))

print(f"\n{'ALL CONSISTENT' if not fail else f'{len(fail)} PROBLEM(S)'}\n")
sys.exit(1 if fail else 0)
