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
  - manifest.xml's iq:application/@version, the single source of truth the
    CHANGELOG names as such;
  - CHANGELOG.md, which must already carry a section for that version.

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
  tools/release-notes.py v0.3.0        check, and print the notes
  tools/release-notes.py v0.3.0 -o F   ... and write them to F instead

Needs nothing but Python. It reads only what is committed, so it runs on a bare
runner, before the container the bundle is built in is even pulled.
"""
import argparse
import re
import sys

MANIFEST = 'manifest.xml'
CHANGELOG = 'CHANGELOG.md'

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


def manifest_version():
    match = APP_VERSION.search(read(MANIFEST))
    if not match:
        fail(f'no iq:application version found in {MANIFEST}')
    return match.group(1)


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
        description='Check a release tag against manifest.xml and CHANGELOG.md, '
                    'and print that release\'s notes.')
    parser.add_argument('tag', help='the tag being released, e.g. v0.3.0')
    parser.add_argument('-o', '--output', metavar='FILE',
                        help='write the notes to FILE rather than to stdout')
    arguments = parser.parse_args()

    tag = arguments.tag
    if not tag.startswith('v'):
        fail(f'tag {tag!r} does not start with "v"')
    version = tag[1:]

    declared = manifest_version()
    if version != declared:
        fail(f'tag {tag} does not match the version in {MANIFEST} ({declared}); '
             f'tag v{declared}, or change the manifest first')

    notes = '\n'.join(changelog_section(version)).strip() + '\n'
    if arguments.output:
        with open(arguments.output, 'w', encoding='utf-8') as handle:
            handle.write(notes)
        print(f'{tag}: version {version} agrees with {MANIFEST}; '
              f'notes written to {arguments.output}', file=sys.stderr)
    else:
        sys.stdout.write(notes)


if __name__ == '__main__':
    main()
