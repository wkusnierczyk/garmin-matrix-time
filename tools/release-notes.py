#!/usr/bin/env python3
"""Check a release tag against the repository, and print that release's notes.

A tag push is the whole trigger for the release workflow (see
.github/workflows/release.yml), and a tag is just a name someone typed. Nothing
about `git tag v0.3.0` consults manifest.xml, so a mistyped or stale tag would
otherwise publish a bundle whose version is not the one on the release page --
and the version in the bundle is the number the Connect IQ store shows, which
cannot be uploaded twice. That is the shape of mistake 0.2.0 was lost to, so it
is worth failing a minute into a release rather than after it.

Three things have to agree before anything is built:

  - the tag, which must be "v" followed by the version and nothing else;
  - the editions' manifests -- manifest.xml for Lite, manifest-premium.xml for
    Premium -- each carrying the version that edition is published as;
  - CHANGELOG.md, which must already carry a section for that version.

A tag is a code release of the repository, one for both editions; a manifest's
version is what that edition is published as (#186). An edition moves to the
tag's version only when the release changes it, so at least one manifest must
equal the tag, and none may be ahead of it -- a manifest ahead of the tag is a
bump made for a later release, or a typo. The editions whose manifest equals
the tag are the ones the tag releases, and the only ones the workflow exports;
an edition left behind keeps the version it is already published as.

The last is not pedantry. A release whose notes are written afterwards is how
0.2.1 came to exist: the store took 0.2.0 from the first of two upload steps and
left the 0.1.0 notes standing, and the number could not be used again. Requiring
the section to exist before the tag is pushed puts the notes ahead of the
irreversible step rather than behind it.

On success the section's body -- the heading itself stripped, since the release
page supplies its own title -- goes to stdout, which is what becomes the draft
release's notes. On any disagreement the reason goes to stderr and the exit
status is 1.

Usage:
  tools/release-notes.py v0.3.0              check, and print the notes
  tools/release-notes.py v0.3.0 -o F         ... and write them to F instead
  tools/release-notes.py v0.3.0 -e F         ... and write the released editions
                                             to F, as a JSON list

Needs nothing but Python. It reads only what is committed, so it runs on a bare
runner, before the container the bundle is built in is even pulled.
"""
import argparse
import json
import re
import sys

# Edition to manifest, in the order the editions are reported. The same pairing
# as EDITION and MANIFEST in the Makefile.
MANIFESTS = {'lite': 'manifest.xml', 'premium': 'manifest-premium.xml'}
CHANGELOG = 'CHANGELOG.md'

# A version is three dot-separated numbers, compared as numbers: 0.10.0 is ahead
# of 0.9.0. No leading zeros, as semver requires, so that two spellings of one
# version cannot exist. Anything else is refused rather than compared as text.
VERSION = re.compile(r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$')

# The application version, not the manifest format version on the line above it
# nor the XML declaration's above that -- all three are spelled version="...".
# Anchored on iq:application so it can only match the one that ships.
APP_VERSION = re.compile(r'<iq:application\b[^>]*\bversion="([^"]+)"')

# "## 0.2.1 -- 2026-09-21". The date is spelled out as YYYY-MM-DD rather than
# matched as "some token", because a section still being written is the state
# this check exists to catch and "## 0.3.0 -- TBD" is exactly what that looks
# like. Anything looser lets the placeholder through and the gate passes on a
# heading that was put there to say it is not ready. The shape is checked, not
# the calendar: a typo'd but well-formed date is a different mistake, and one no
# amount of parsing here would catch.
SECTION = re.compile(r'^##\s+(\S+)\s+--\s+(\d{4}-\d{2}-\d{2})\s*$')


def fail(message):
    print(f'{sys.argv[0]}: {message}', file=sys.stderr)
    raise SystemExit(1)


def read(path):
    try:
        with open(path, encoding='utf-8') as handle:
            return handle.read()
    except OSError as error:
        fail(f'cannot read {path}: {error}')


def manifest_version(manifest):
    match = APP_VERSION.search(read(manifest))
    if not match:
        fail(f'no iq:application version found in {manifest}')
    return match.group(1)


def parse(version, where):
    match = VERSION.match(version)
    if not match:
        fail(f'{where} version {version!r} is not MAJOR.MINOR.PATCH')
    return tuple(int(part) for part in match.groups())


def released_editions(version):
    """Return the editions `version` releases, refusing a manifest ahead of it."""
    tagged = parse(version, 'tag')
    released = []
    for edition, manifest in MANIFESTS.items():
        declared = manifest_version(manifest)
        if parse(declared, manifest) > tagged:
            fail(f'{manifest} ({declared}) is ahead of the tag ({version}); tag '
                 f'v{declared}, or change the manifest first')
        if declared == version:
            released.append(edition)
    if not released:
        found = ', '.join(f'{m} {manifest_version(m)}' for m in MANIFESTS.values())
        fail(f'no edition is at {version} ({found}); set the version of each edition '
             f'this release changes, then tag')
    return released


def changelog_section(version):
    """Return the body of the CHANGELOG section for `version`, heading stripped."""
    lines = read(CHANGELOG).splitlines()
    start = None
    for index, line in enumerate(lines):
        match = SECTION.match(line)
        if not match:
            continue
        if start is not None:
            # The next dated section closes the one being collected.
            return lines[start:index]
        if match.group(1) == version:
            start = index + 1
    if start is None:
        fail(f'{CHANGELOG} has no section for {version} dated YYYY-MM-DD; write '
             f'the release notes, and date the heading, before tagging')
    return lines[start:]


def main():
    parser = argparse.ArgumentParser(
        description='Check a release tag against the manifests and CHANGELOG.md, '
                    'and print that release\'s notes.')
    parser.add_argument('tag', help='the tag being released, e.g. v0.3.0')
    parser.add_argument('-o', '--output', metavar='FILE',
                        help='write the notes to FILE rather than to stdout')
    parser.add_argument('-e', '--editions', metavar='FILE',
                        help='write the editions the tag releases to FILE, as a JSON list')
    arguments = parser.parse_args()

    tag = arguments.tag
    if not tag.startswith('v'):
        fail(f'tag {tag!r} does not start with "v"')
    version = tag[1:]

    editions = released_editions(version)

    notes = '\n'.join(changelog_section(version)).strip() + '\n'
    if arguments.editions:
        with open(arguments.editions, 'w', encoding='utf-8') as handle:
            json.dump(editions, handle)
    if arguments.output:
        with open(arguments.output, 'w', encoding='utf-8') as handle:
            handle.write(notes)
        print(f'{tag}: releases {", ".join(editions)}; '
              f'notes written to {arguments.output}', file=sys.stderr)
    else:
        sys.stdout.write(notes)


if __name__ == '__main__':
    main()
