#!/usr/bin/env python3
"""Verify the font configuration chain is internally consistent.

Source of truth is resources/fonts/resolutions.json (reference resolution and
target list) plus resources/fonts/fonts.xml (reference size, encoded in each
.fnt filename). Everything else -- the generated resource directories, fonts.md,
and the README size table and prose -- is derived, and must agree.

resources/fonts/charsets.json is a source of truth of its own: it decides which
glyphs each generated font contains. The code that draws with those fonts carries
its own copy of the charset, so the copies are compared here too.

The README is descriptive, not prescriptive: this script derives expected values
from the config and asserts the derived artifacts conform, never the reverse.
"""
import hashlib
import json
import os
import re
import sys

FONT_RE = re.compile(r'<font\s+id="(\w+)"\s+filename="([^"]+)"')
REQUIRED_FONT_IDS = {'Matrix', 'Time', 'TimeLarge'}
fail = []


def ok(cond, msg):
    print(f"  {'OK  ' if cond else 'FAIL'}  {msg}")
    if not cond:
        fail.append(msg)


def sha(path):
    return hashlib.sha256(open(path, 'rb').read()).hexdigest()


# ---------------------------------------------------------------- sources of truth
res = json.load(open('resources/fonts/resolutions.json'))
ref = res['reference']
rw, rh = ref['resolution']
targets = [(t['resolution'][0], t['resolution'][1], t['shape']) for t in res['targets']]

print("\nSOURCE OF TRUTH")
print(f"  resolutions.json  reference = {rw}x{rh} {ref['shape']}, {len(targets)} targets")

fonts = dict(FONT_RE.findall(open('resources/fonts/fonts.xml').read()))
refsize = {}
for fid, fn in fonts.items():
    m = re.match(r'(.+)-(\d+)\.fnt$', fn)
    if not m:
        ok(False, f"fonts.xml {fid}: filename {fn!r} is not <name>-<size>.fnt")
        continue
    refsize[fid] = (m.group(1), int(m.group(2)))
    print(f"  fonts.xml         {fid:8} -> {fn}  (reference size {m.group(2)})")


def k(w, h):
    return min(w / rw, h / rh)


def expected(fid, w, h):
    stem, sz = refsize[fid]
    return stem, round(sz * k(w, h))


print("\nCHAIN CHECKS")

# both fonts must exist -- otherwise the shared-size invariant below is vacuous
ok(REQUIRED_FONT_IDS <= set(refsize),
   f"fonts.xml declares every required font {sorted(REQUIRED_FONT_IDS)} "
   f"(found {sorted(refsize) or 'none'})")

# the reference must itself be a generated target, or the base identity check is moot
ok((rw, rh, ref['shape']) in targets,
   f"reference {rw}x{rh} {ref['shape']} is present in the target list")

for fid, (stem, sz) in sorted(refsize.items()):
    for ext in ('fnt', 'png'):
        ok(os.path.exists(f'resources/fonts/{stem}-{sz}.{ext}'),
           f"base bitmap present: {stem}-{sz}.{ext}")

# Time and TimeLarge are the same typeface at two sizes, and the always-on scene is
# sized against the woken one: TimeLarge is Time doubled (#69). Matrix is independent
# of both -- the time was once locked to the rain glyph size, and that was abandoned
# in #50. The scaler derives every target from these two reference sizes, so getting
# the ratio wrong here would propagate silently to all thirteen resolutions.
if {'Time', 'TimeLarge'} <= set(refsize):
    (tstem, tsize), (lstem, lsize) = refsize['Time'], refsize['TimeLarge']
    ok(tstem == lstem,
       f"Time and TimeLarge are the same typeface ({tstem} vs {lstem})")
    ok(lsize == 2 * tsize,
       f"TimeLarge reference size {lsize} is twice Time's {tsize}")

# every target: declared filename, declared id set, and both files on disk
bad = 0
for w, h, shape in targets:
    d = f"resources-{shape}-{w}x{h}"
    xml = f'{d}/fonts/fonts.xml'
    if not os.path.exists(xml):
        ok(False, f"{d}/fonts/fonts.xml missing for target in resolutions.json"); bad += 1
        continue
    got = dict(FONT_RE.findall(open(xml).read()))
    if set(got) != set(refsize):
        ok(False, f"{d}: declares fonts {sorted(got)}, base declares {sorted(refsize)}"); bad += 1
    for fid, fn in sorted(got.items()):                  # validate EVERY declared entry
        if fid not in refsize:
            continue                                     # already reported by the set check
        stem, sz = expected(fid, w, h)
        if fn != f"{stem}-{sz}.fnt":
            ok(False, f"{d} {fid}: declares {fn}, expected {stem}-{sz}.fnt"); bad += 1
        elif not all(os.path.exists(f'{d}/fonts/{stem}-{sz}.{e}') for e in ('fnt', 'png')):
            ok(False, f"{d} {fid}: {fn} declared but .fnt/.png missing"); bad += 1
if not bad:
    ok(True, f"all {len(targets)} targets: declared size == round(ref x k), ids match, files present")

# orphans: bitmaps on disk that no fonts.xml declares
orphans = []
for root, _, files in os.walk('.'):
    parts = root.split(os.sep)
    if '.git' in parts or os.path.basename(root) != 'fonts':
        continue
    xml = os.path.join(root, 'fonts.xml')
    if not os.path.exists(xml):
        continue
    keep = set(dict(FONT_RE.findall(open(xml).read())).values())
    keep |= {f[:-4] + '.png' for f in keep}
    orphans += [os.path.join(root, f) for f in files
                if f.endswith(('.fnt', '.png')) and f not in keep]
ok(not orphans,
   f"no orphaned bitmaps ({len(orphans)} found: {', '.join(orphans[:3])}…)" if orphans
   else "no orphaned bitmaps left by the scaler")

# base assets must BE the reference-resolution assets, not merely same-named.
# ttf2bmp defaults to -hinting full while garmin-font-scaler passes -hinting none,
# so a hand-run of the tool silently produces a different bitmap at the same size.
refdir = f"resources-{ref['shape']}-{rw}x{rh}/fonts"
for fid, (stem, sz) in sorted(refsize.items()):
    for ext in ('fnt', 'png'):
        b, r = f'resources/fonts/{stem}-{sz}.{ext}', f'{refdir}/{stem}-{sz}.{ext}'
        if not (os.path.exists(b) and os.path.exists(r)):
            ok(False, f"cannot compare {stem}-{sz}.{ext}: missing base or reference copy")
        else:
            ok(sha(b) == sha(r),
               f"base {stem}-{sz}.{ext} is byte-identical to {refdir}/ "
               "(same bitmap, not just the same point size)")

# ---------------------------------------------------------------------- charsets
# A generated font contains exactly the glyphs its charsets.json entry names, so a
# character the code draws but the charset omits comes out as a blank or garbage cell
# -- silent at build time and visible only on-device. The Matrix charset is mirrored
# in three hand-maintained places and nothing compared them until #54, which is
# precisely a charset change.
MC_CHARSET_RE = re.compile(r'\bCHARSET\s*=\s*"([^"]*)"')
PY_CHARSET_RE = re.compile(r"^CHARSET\s*=\s*'([^']*)'", re.M)
MIRRORS = {'source/Matrix.mc': MC_CHARSET_RE,
           'tools/make-launcher-icons.py': PY_CHARSET_RE}

print("\nCHARSETS")
charsets = {c['fontId']: c['fontCharset']
            for c in json.load(open('resources/fonts/charsets.json'))}
ok(set(charsets) == set(refsize),
   f"charsets.json covers exactly the fonts fonts.xml declares "
   f"(charsets {sorted(charsets)}, fonts {sorted(refsize)})")

for path, pattern in MIRRORS.items():
    m = pattern.search(open(path).read())
    if not m:
        ok(False, f"{path}: no CHARSET literal found to compare")
    else:
        ok(m.group(1) == charsets.get('Matrix'),
           f"{path} CHARSET matches the charsets.json Matrix entry"
           + (f" ({m.group(1)!r} vs {charsets.get('Matrix')!r})"
              if m.group(1) != charsets.get('Matrix') else ""))

# Time and TimeLarge are the same string drawn at two sizes: a glyph missing from one
# would blank a cell on exactly one of the woken and always-on scenes.
ok(charsets.get('Time') == charsets.get('TimeLarge'),
   "Time and TimeLarge charsets agree"
   + (f" ({charsets.get('Time')!r} vs {charsets.get('TimeLarge')!r})"
      if charsets.get('Time') != charsets.get('TimeLarge') else ""))

# ------------------------------------------------------------------- derived docs
ROW_RE = re.compile(
    r'^\|\s*(\d+)\s*x\s*(\d+)\s*\|\s*([\w-]+)\s*\|\s*([\w ]+?)\s*\|\s*[\w -]+?\s*\|\s*(\d+)\s*\|$')


def humanize(fid):
    """The scaler's Element column: id minus a trailing "font", camelCase split, capitalized.

    "TimeLarge" is written "Time large" in the generated tables, so the derived
    expectation has to be spelled the same way before it can be compared.
    """
    text = re.sub(r'font$', '', fid, flags=re.IGNORECASE)
    return re.sub(r'([a-z])([A-Z])', r'\1 \2', text).strip().capitalize()


def table_rows(text, heading):
    body = text.split(heading, 1)[1]
    out = []
    for line in body.splitlines():
        m = ROW_RE.match(line.strip())
        if m:
            out.append((int(m.group(1)), int(m.group(2)), m.group(3), m.group(4), int(m.group(5))))
        elif out and not line.strip().startswith('|'):
            break
    return out


def check_table(rows, label):
    """A table is correct only if it matches values derived from the config."""
    if not rows:
        ok(False, f"{label}: no size rows parsed"); return
    want = {(w, h, shape, humanize(fid)): expected(fid, w, h)[1]
            for (w, h, shape) in targets for fid in refsize}
    got = {(w, h, shape, fid): size for (w, h, shape, fid, size) in rows}
    missing = sorted(set(want) - set(got))
    extra = sorted(set(got) - set(want))
    wrong = sorted(kk for kk in set(want) & set(got) if want[kk] != got[kk])
    ok(not missing, f"{label}: no target/font rows missing"
       + (f" (missing {missing[:3]})" if missing else ""))
    ok(not extra, f"{label}: no rows for unknown targets"
       + (f" (extra {extra[:3]})" if extra else ""))
    ok(not wrong, f"{label}: every size equals round(ref x k)"
       + (f" (wrong {[(kk, got[kk], want[kk]) for kk in wrong[:3]]})" if wrong else ""))


fonts_md = open('fonts.md').read()
rd = open('README.md').read()
check_table(table_rows(fonts_md, '# Font sizes by resolution'), 'fonts.md table')
check_table(table_rows(rd, 'The table below lists all font sizes'), 'README table')

# and the two derived documents must agree with each other
fm_lines = [l for l in fonts_md.split('# Font sizes by resolution', 1)[1].splitlines()
            if l.startswith('|')]
m = re.search(r'\| Resolution \|.*?(?=\n\n)', rd, re.S)
ok(m is not None and [l for l in m.group(0).splitlines() if l.startswith('|')] == fm_lines,
   "README size table is byte-identical to generated fonts.md")

# the prose must state the reference -- anchored to the sentence, not a document-wide
# substring, which the size table would otherwise satisfy by coincidence
# paragraph-scoped, not line-scoped: the sentence may wrap across source lines
paragraphs = [' '.join(b.split()) for b in re.split(r'\n\s*\n', rd)]
prose = [b for b in paragraphs if 'reference resolution' in b.lower()]
ok(bool(prose) and any(re.search(rf'\b{rw}\s*x\s*{rh}\b', b) for b in prose),
   f"README prose names the reference resolution {rw}x{rh} where it discusses the reference")
ok(bool(prose) and any('resolutions.json' in b for b in prose),
   "README prose cites resolutions.json as the source of truth")

print(f"\n{'ALL CONSISTENT' if not fail else f'{len(fail)} PROBLEM(S)'}\n")
sys.exit(1 if fail else 0)
