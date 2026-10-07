#!/usr/bin/env python3
"""Verify the font configuration chain is internally consistent.

Source of truth is resources/fonts/resolutions.json (reference resolution and
target list) plus resources/fonts/fonts.xml (reference size, encoded in each
.fnt filename). Everything else -- the generated resource directories, fonts.md,
and the README size table and prose -- is derived, and must agree.

resources/fonts/charsets.json is a source of truth of its own: it decides which
glyphs each generated font contains. The code that draws with those fonts carries
its own copy of the charset, so the copies are compared here too.

Premium's fonts have a configuration of their own, in premium/resources/fonts, and are
checked the same way against premium/resources-<family>/ and premium/fonts.md (#32).

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

# Connect IQ selects a qualified resource directory by matching its name against the
# device's `deviceFamily`, whose shape component has no hyphen and no capital. The
# scaler concatenates the `shape` string from resolutions.json straight into the
# directory name, so a shape spelled any other way produces a directory the compiler
# can never select -- and it fails silently: no error, no warning, the device just
# falls back to the unscaled default font set (#39).
#
# `garmin-font-scaler`'s own README documents `"shape": "semi-round"` in its example,
# so this is easy to get wrong by following the upstream docs. Hard-coded rather than
# read from the SDK device definitions because this script must run on a bare clone
# with no SDK installed.
CIQ_SHAPES = {'round', 'semiround', 'rectangle', 'semioctagon'}

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


def expected(fid, w, h, sizes=None):
    stem, sz = (sizes or refsize)[fid]
    return stem, round(sz * k(w, h))


# A hollow font's outline width, as garmin-font-scaler 0.3.0 derives it for a target
# (#72): scaled by the same k as the size, rounded to two decimals, passed as written at
# the reference, and never below ttf2bmp's minimum of 0.125.
MIN_STROKE = 0.125


def expected_stroke(ref_stroke, w, h):
    factor = k(w, h)
    stroke = ref_stroke * factor
    if stroke < MIN_STROKE:
        return MIN_STROKE
    if factor == 1:
        return ref_stroke
    return max(MIN_STROKE, round(stroke, 2))


def stroke_text(stroke):
    """How the scaler and ttf2bmp write a width: the shortest decimal, 1.0 as "1"."""
    text = repr(float(stroke))
    return text[:-2] if text.endswith('.0') else text


def fnt_name(stem, size, stroke=None):
    """The file the scaler points a font id at; hollow ones carry the stroke, "." as "p"."""
    suffix = '' if stroke is None else '-stroke' + stroke_text(stroke).replace('.', 'p')
    return f"{stem}-{size}{suffix}.fnt"


print("\nCHAIN CHECKS")

# both fonts must exist -- otherwise the shared-size invariant below is vacuous
ok(REQUIRED_FONT_IDS <= set(refsize),
   f"fonts.xml declares every required font {sorted(REQUIRED_FONT_IDS)} "
   f"(found {sorted(refsize) or 'none'})")

# the reference must itself be a generated target, or the base identity check is moot
ok((rw, rh, ref['shape']) in targets,
   f"reference {rw}x{rh} {ref['shape']} is present in the target list")

# every shape must be spelled the way Connect IQ spells it, or the directory the
# scaler generates for it is invisible to the compiler (#39)
for shape in sorted({ref['shape']} | {s for _, _, s in targets}):
    ok(shape in CIQ_SHAPES,
       f"shape {shape!r} must be a Connect IQ deviceFamily qualifier "
       f"(one of {sorted(CIQ_SHAPES)})")

for fid, (stem, sz) in sorted(refsize.items()):
    for ext in ('fnt', 'png'):
        ok(os.path.exists(f'resources/fonts/{stem}-{sz}.{ext}'),
           f"base bitmap present: {stem}-{sz}.{ext}")

# Time and TimeLarge are the same typeface at two sizes, and the always-on scene is
# sized against the woken one: TimeLarge is Time doubled (#69). Matrix is independent
# of both -- the time was once locked to the rain glyph size, and that was abandoned
# in #50. The scaler derives every target from these two reference sizes, so getting
# the ratio wrong here would propagate silently to every configured resolution.
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
# The Font column may read "SUSEMono regular, hollow", and a table with a hollow font in
# it has a sixth column, the stroke, blank for a filled font (#72).
ROW_RE = re.compile(
    r'^\|\s*(\d+)\s*x\s*(\d+)\s*\|\s*([\w-]+)\s*\|\s*([\w ]+?)\s*\|\s*([\w ,-]+?)\s*\|\s*(\d+)\s*\|'
    r'(?:\s*([\d.]*)\s*\|)?$')


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
            out.append((int(m.group(1)), int(m.group(2)), m.group(3), m.group(4), int(m.group(6)),
                        m.group(7) or None, m.group(5)))
        elif out and not line.strip().startswith('|'):
            break
    return out


def check_table(rows, label, sizes=None, strokes=None):
    """A table is correct only if it matches values derived from the config."""
    sizes = sizes or refsize
    strokes = strokes or {}
    if not rows:
        ok(False, f"{label}: no size rows parsed"); return
    want = {(w, h, shape, humanize(fid)): expected(fid, w, h, sizes)[1]
            for (w, h, shape) in targets for fid in sizes}
    got = {(w, h, shape, fid): size for (w, h, shape, fid, size, _, _) in rows}
    missing = sorted(set(want) - set(got))
    extra = sorted(set(got) - set(want))
    wrong = sorted(kk for kk in set(want) & set(got) if want[kk] != got[kk])
    ok(not missing, f"{label}: no target/font rows missing"
       + (f" (missing {missing[:3]})" if missing else ""))
    ok(not extra, f"{label}: no rows for unknown targets"
       + (f" (extra {extra[:3]})" if extra else ""))
    ok(not wrong, f"{label}: every size equals round(ref x k)"
       + (f" (wrong {[(kk, got[kk], want[kk]) for kk in wrong[:3]]})" if wrong else ""))
    if strokes:
        want_stroke = {(w, h, shape, humanize(fid)):
                       stroke_text(expected_stroke(strokes[fid], w, h)) if fid in strokes else None
                       for (w, h, shape) in targets for fid in sizes}
        got_stroke = {(w, h, shape, fid): st for (w, h, shape, fid, _, st, _) in rows}
        bad = sorted(kk for kk in set(want_stroke) & set(got_stroke)
                     if want_stroke[kk] != got_stroke[kk])
        ok(not bad, f"{label}: every stroke equals the reference stroke x k, and filled fonts have none"
           + (f" (wrong {[(kk, got_stroke[kk], want_stroke[kk]) for kk in bad[:3]]})" if bad else ""))
        hollow_ids = {humanize(fid) for fid in strokes}
        mislabelled = sorted({fid for (_, _, _, fid, _, _, font) in rows
                              if font.endswith(', hollow') != (fid in hollow_ids)})
        ok(not mislabelled, f"{label}: exactly the hollow fonts are labelled hollow"
           + (f" (wrong {mislabelled})" if mislabelled else ""))


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

# ----------------------------------------------------------------------- Premium
# Premium's fonts have a configuration of their own, in premium/resources/fonts, which
# garmin-font-scaler reads with --project-dir premium and turns into
# premium/resources-<family>/fonts (#135, #32). It is on no resource path -- its
# fonts.xml repeats the jsonData ids Lite's declares -- so nothing but this script
# ever compares it with Lite's, and every way it can drift is silent: a resolutions.json
# that differs scales Premium's fonts for screens it does not ship on, and a family
# premium.jungle does not name compiles without the Premium fonts until it fails on an
# undefined symbol, or, where a monkeyc resource path is mistyped, not at all.
print("\nPREMIUM")
PDIR = 'premium/resources/fonts'
PREMIUM_FONT_IDS = {'Time', 'TimeMedium', 'TimeLarge', 'TimeExtraLarge', 'TimeExtraExtraLarge', 'TimeHuge',
                    'TimeExtraHuge', 'TimeLargeHollow', 'TimeExtraLargeHollow', 'TimeExtraExtraLargeHollow',
                    'TimeHugeHollow', 'TimeExtraHugeHollow'}
# The Lite ids Premium redefines, to draw them in its own weight (#144). premium.jungle
# appends premium/resources-<family> after resources-<family>, and a later resource
# directory redefines an id rather than colliding with it: Premium compiles its own
# bitmaps under these ids and none of Lite's. Any other repeated id is a mistake.
PREMIUM_OVERRIDES = {'Time', 'TimeLarge'}
# Each hollow font is its filled twin drawn as an outline (#72): the same face at the same
# size, so the same metrics, and swapping one for the other never moves the time.
HOLLOW_TWINS = {'TimeLargeHollow': 'TimeLarge', 'TimeExtraLargeHollow': 'TimeExtraLarge',
                'TimeExtraExtraLargeHollow': 'TimeExtraExtraLarge', 'TimeHugeHollow': 'TimeHuge',
                'TimeExtraHugeHollow': 'TimeExtraHuge'}
STROKE_RE = re.compile(r'<font\s+id="(\w+)"[^>]*\sstroke="([^"]+)"')
# Premium's XXS, Time, also draws the ISO date under the woken time at every time size (#163),
# so it holds the date's one glyph that is not the time's. The date has no font of its own:
# the scaler names a bitmap by face and size, so one at XXS's size would overwrite XXS's.
DATE_FONT_ID = 'Time'
DATE_EXTRA = '-'

ok(open(f'{PDIR}/resolutions.json').read() == open('resources/fonts/resolutions.json').read(),
   f"{PDIR}/resolutions.json is identical to Lite's")

pfonts = dict(FONT_RE.findall(open(f'{PDIR}/fonts.xml').read()))
psize = {}
for fid, fn in pfonts.items():
    m = re.match(r'(.+)-(\d+)\.fnt$', fn)
    if not m:
        ok(False, f"premium fonts.xml {fid}: filename {fn!r} is not <name>-<size>.fnt")
        continue
    psize[fid] = (m.group(1), int(m.group(2)))
    print(f"  fonts.xml         {fid:25} -> {fn}  (reference size {m.group(2)})")

ok(set(psize) == PREMIUM_FONT_IDS,
   f"premium fonts.xml declares exactly {sorted(PREMIUM_FONT_IDS)} (found {sorted(psize)})")

pstroke = {fid: float(s) for fid, s in STROKE_RE.findall(open(f'{PDIR}/fonts.xml').read())}
ok(set(pstroke) == set(HOLLOW_TWINS),
   f"premium fonts.xml gives a stroke to exactly the hollow fonts {sorted(HOLLOW_TWINS)} "
   f"(found {sorted(pstroke)})")
twins_all = {**refsize, **psize}
for hollow, filled in sorted(HOLLOW_TWINS.items()):
    ok(hollow in psize and filled in twins_all and psize[hollow] == twins_all[filled],
       f"{hollow} is {filled}'s face and size, {twins_all.get(filled)}")
ok(set(psize) & set(refsize) == PREMIUM_OVERRIDES,
   f"Premium repeats exactly the Lite font ids it overrides, {sorted(PREMIUM_OVERRIDES)} "
   f"(found {sorted(set(psize) & set(refsize))})")
# An override changes the weight, never the size: Time and TimeLarge, Premium's XXS and S, stay
# Lite's sizes. TimeLarge is Lite's always-on font, whose burn-in jitter and lit-pixel budget
# were measured at that size (#69); Premium's always-on font is TimeHuge instead, measured
# on its own (#164).
for fid in sorted(PREMIUM_OVERRIDES & set(psize) & set(refsize)):
    ok(psize[fid][1] == refsize[fid][1],
       f"Premium {fid} keeps Lite's reference size ({psize[fid][1]} vs {refsize[fid][1]})")

# Premium's typeface is its own file, an instance of a weight Lite does not ship, and the
# licence travels with it; OFL-SUSEMono.txt is a symlink to Lite's copy.
ttfs = {stem for stem, _ in psize.values()}
for stem in sorted(ttfs):
    ok(os.path.exists(f'{PDIR}/{stem}.ttf'), f"{PDIR}/{stem}.ttf resolves")
ok(os.path.exists(f'{PDIR}/OFL-SUSEMono.txt'), f"{PDIR}/OFL-SUSEMono.txt resolves")

# The time size ladder, XXS XS S M L XL XXL, is Time, TimeMedium, TimeLarge, TimeExtraLarge,
# TimeExtraExtraLarge, TimeHuge, TimeExtraHuge (#166; the ids predate the names, and override
# Lite's where they repeat them, so they stay): one typeface, strictly growing at the
# reference. The scaler rounds per target, so the order is checked at every target too -- two
# adjacent sizes rounding to the same point size would make one step of the setting do nothing.
LADDER = ['Time', 'TimeMedium', 'TimeLarge', 'TimeExtraLarge', 'TimeExtraExtraLarge', 'TimeHuge', 'TimeExtraHuge']
allsize = {**refsize, **psize}
if set(LADDER) <= set(allsize):
    ok(len({allsize[f][0] for f in LADDER}) == 1,
       f"the time size ladder {LADDER} is one typeface")
    ref_ladder = [allsize[f][1] for f in LADDER]
    ok(all(a < b for a, b in zip(ref_ladder, ref_ladder[1:])),
       f"the time size ladder grows at the reference {ref_ladder}")
    flat = [(w, h, shape, [expected(f, w, h, allsize)[1] for f in LADDER])
            for w, h, shape in targets]
    flat = [t for t in flat if not all(a < b for a, b in zip(t[3], t[3][1:]))]
    ok(not flat, f"the time size ladder grows at every target"
       + (f" (not at {flat[:3]})" if flat else ""))

pcharsets = {c['fontId']: c['fontCharset'] for c in json.load(open(f'{PDIR}/charsets.json'))}
ok(set(pcharsets) == set(psize),
   f"premium charsets.json covers exactly the fonts premium fonts.xml declares "
   f"(charsets {sorted(pcharsets)}, fonts {sorted(psize)})")
ok(all(c == charsets.get('Time') + (DATE_EXTRA if f == DATE_FONT_ID else '') for f, c in pcharsets.items()),
   "every Premium time font has Lite's Time charset, so each size can draw the same string, "
   f"and {DATE_FONT_ID} adds {DATE_EXTRA!r} for the date and nothing else")

pjungle = open('premium.jungle').read()
bad = 0
for w, h, shape in targets:
    fam = f"{shape}-{w}x{h}"
    d = f"premium/resources-{fam}"
    line = f"{fam}.resourcePath = $({fam}.resourcePath);{d}"
    if line not in pjungle:
        ok(False, f"premium.jungle appends {d} to {fam}"); bad += 1
    xml = f'{d}/fonts/fonts.xml'
    if not os.path.exists(xml):
        ok(False, f"{xml} missing for target in resolutions.json"); bad += 1
        continue
    got = dict(FONT_RE.findall(open(xml).read()))
    if set(got) != set(psize):
        ok(False, f"{d}: declares fonts {sorted(got)}, premium config declares {sorted(psize)}"); bad += 1
    if 'stroke=' in open(xml).read():
        ok(False, f"{xml}: carries a stroke attribute, which Connect IQ does not know"); bad += 1
    for fid, fn in sorted(got.items()):
        if fid not in psize:
            continue
        stem, sz = expected(fid, w, h, psize)
        stroke = expected_stroke(pstroke[fid], w, h) if fid in pstroke else None
        want = fnt_name(stem, sz, stroke)
        if fn != want:
            ok(False, f"{d} {fid}: declares {fn}, expected {want}"); bad += 1
        elif not all(os.path.exists(f'{d}/fonts/{want[:-4]}.{e}') for e in ('fnt', 'png')):
            ok(False, f"{d} {fid}: {fn} declared but .fnt/.png missing"); bad += 1
if not bad:
    ok(True, f"all {len(targets)} Premium targets: named in premium.jungle, "
             "declared size == round(ref x k), stroke == ref x k, ids match, files present")


# A hollow font must draw the time exactly where its filled twin does: the same line
# height and base, and every glyph the same size, offsets and advance. Where a glyph sits
# in the atlas image -- x, y, the atlas size -- does not affect drawing and is not compared. Compared on the generated files, in every family,
# since that is what the device loads -- the configuration alone cannot see a ttf2bmp
# that pads outlined glyphs differently (#72).
def fnt_metrics(path):
    common, chars = None, {}
    for line in open(path):
        fields = dict(re.findall(r'(\w+)=("[^"]*"|\S+)', line))
        if line.startswith('common '):
            common = {kk: fields.get(kk) for kk in ('lineHeight', 'base')}
        elif line.startswith('char '):
            chars[fields['id']] = {kk: fields.get(kk)
                                   for kk in ('width', 'height', 'xoffset', 'yoffset', 'xadvance')}
    return common, chars


def family_font(fid, fam):
    """The generated .fnt a font id resolves to in a family: Lite's tree or Premium's."""
    for d in (f'premium/resources-{fam}/fonts', f'resources-{fam}/fonts'):
        xml = f'{d}/fonts.xml'
        if os.path.exists(xml):
            fn = dict(FONT_RE.findall(open(xml).read())).get(fid)
            if fn:
                return f'{d}/{fn}'
    return None


twin_bad = []
for w, h, shape in targets:
    fam = f"{shape}-{w}x{h}"
    for hollow, filled in sorted(HOLLOW_TWINS.items()):
        a, b = family_font(hollow, fam), family_font(filled, fam)
        if not (a and b and os.path.exists(a) and os.path.exists(b)):
            twin_bad.append((fam, hollow, 'missing')); continue
        ma, mb = fnt_metrics(a), fnt_metrics(b)
        # Both must hold exactly the glyphs of the hollow font's charset: two files empty,
        # or truncated to the same few glyphs, would otherwise compare equal.
        glyphs = {str(ord(c)) for c in pcharsets.get(hollow, '')}
        if not ma[0] or set(ma[1]) != glyphs or set(mb[1]) != glyphs or ma != mb:
            twin_bad.append((fam, hollow, os.path.basename(a), os.path.basename(b)))
ok(not twin_bad, f"every hollow font has its filled twin's metrics in all {len(targets)} families"
   + (f" (not {twin_bad[:3]})" if twin_bad else ""))

# Lite pads the hour with %2d so that its time is always five cells wide and a
# centre-justified time never shifts (#7). Premium does not pad (#196), but its time still
# relies on equal cells: it is to change width only when the hour gains or loses a digit,
# not with every minute, and the date under it is ten cells wide at every date. Both hold
# only while every glyph of a time font -- digits, space and colon -- has one advance,
# which a typeface or weight change could quietly break (#144). Checked on the generated
# files, Lite's and Premium's, in every family.
# Each font must hold exactly the Time charset -- a monospace font that lost its space or
# colon would otherwise pass -- and every one expected must be found and read, so that a
# missing file cannot make the check pass by examining nothing.
time_glyphs = {str(ord(c)) for c in charsets.get('Time', '')}
time_ids = {'lite': sorted(f for f in refsize if f.startswith('Time')),
            'premium': sorted(f for f in psize if f.startswith('Time'))}
proportional, examined = [], 0
for w, h, shape in targets:
    fam = f"{shape}-{w}x{h}"
    for edition, d in (('lite', f'resources-{fam}/fonts'), ('premium', f'premium/resources-{fam}/fonts')):
        xml = f'{d}/fonts.xml'
        declared = dict(FONT_RE.findall(open(xml).read())) if os.path.exists(xml) else {}
        for fid in time_ids[edition]:
            fn = declared.get(fid)
            if not fn or not os.path.exists(f'{d}/{fn}'):
                proportional.append((d, fid, 'missing')); continue
            glyphs = fnt_metrics(f'{d}/{fn}')[1]
            advances = {g['xadvance'] for g in glyphs.values()}
            want = time_glyphs | ({str(ord(c)) for c in DATE_EXTRA}
                                  if edition == 'premium' and fid == DATE_FONT_ID else set())
            if set(glyphs) != want or len(advances) != 1:
                proportional.append((d, fid, sorted(advances), sorted(want ^ set(glyphs))))
            examined += 1
want_examined = len(targets) * (len(time_ids['lite']) + len(time_ids['premium']))
ok(not proportional and examined == want_examined and time_glyphs,
   f"every time font, Lite and Premium, holds exactly the Time charset (digits, space, colon), "
   f"and Premium's {DATE_FONT_ID} the date's {DATE_EXTRA!r} too, with one advance, in all {len(targets)} families ({examined} of {want_examined} fonts)"
   + (f" (not {proportional[:3]})" if proportional else ""))

# Premium's time alignment (#154) keeps the box drawText fills on the glass, and relies on
# no pixel of a digit falling outside that box: every glyph of a Premium time font has to
# be a cell at offset 0, as wide as its advance and as tall as the line. ttf2bmp writes
# them that way; a generator that trimmed glyphs to their ink, or let one overhang, would
# put pixels where TimeAlign's margin does not look. Checked in every family, with every
# font expected found and read, as above.
overhang, examined = [], 0
for w, h, shape in targets:
    fam = f"{shape}-{w}x{h}"
    d = f'premium/resources-{fam}/fonts'
    xml = f'{d}/fonts.xml'
    declared = dict(FONT_RE.findall(open(xml).read())) if os.path.exists(xml) else {}
    for fid in time_ids['premium']:
        fn = declared.get(fid)
        if not fn or not os.path.exists(f'{d}/{fn}'):
            overhang.append((d, fid, 'missing')); continue
        common, glyphs = fnt_metrics(f'{d}/{fn}')
        for cid, g in glyphs.items():
            if (g['xoffset'], g['yoffset']) != ('0', '0') or g['width'] != g['xadvance'] \
                    or g['height'] != common['lineHeight']:
                overhang.append((d, fid, chr(int(cid)), g))
        examined += 1
want_examined = len(targets) * len(time_ids['premium'])
ok(not overhang and examined == want_examined,
   f"every Premium time glyph is its whole cell, advance wide and line high, so no digit "
   f"leaves the aligned box, in all {len(targets)} families ({examined} of {want_examined} fonts)"
   + (f" (not {overhang[:3]})" if overhang else ""))

# Premium's size table is generated like Lite's -- garmin-font-scaler --project-dir
# premium --table fonts.md writes premium/fonts.md -- and the README copies it.
pfonts_md = open('premium/fonts.md').read()
check_table(table_rows(pfonts_md, '# Font sizes by resolution'), 'premium/fonts.md table', psize, pstroke)
check_table(table_rows(rd, 'The Premium time sizes'), 'README Premium table', psize, pstroke)
pm_lines = [l for l in pfonts_md.split('# Font sizes by resolution', 1)[1].splitlines()
            if l.startswith('|')]
m = re.search(r'The Premium time sizes.*?(\| Resolution \|.*?)(?=\n\n)', rd, re.S)
ok(m is not None and [l for l in m.group(1).splitlines() if l.startswith('|')] == pm_lines,
   "README Premium size table is byte-identical to generated premium/fonts.md")

print(f"\n{'ALL CONSISTENT' if not fail else f'{len(fail)} PROBLEM(S)'}\n")
sys.exit(1 if fail else 0)
