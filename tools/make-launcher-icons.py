#!/usr/bin/env python3
"""Generate one launcher icon per required size, and the jungle mapping that serves it.

The launcher icon size is a per-device property, published by the SDK in
  ~/Library/Application Support/Garmin/ConnectIQ/Devices/<product>/compiler.json
as `launcherIcon`. Across the products in manifest.xml it takes eight distinct
values, and it is NOT a function of `deviceFamily` -- round-390x390 alone spans
38x38 to 70x70 -- so the usual `resources-<family>/` qualifier cannot express it
(#42). What can is a per-product `resourcePath` entry in the jungle, which is what
this tool writes, between the markers in monkey.jungle.

Every icon is RENDERED at its target size rather than scaled down from one master.
The artwork is digital rain -- fine glyphs, thin strokes, high spatial frequency --
which is the worst case for naive downscaling: at 38x38 a resampled 100x100 still
stops being characters and becomes noise. Rendering natively keeps the glyph cell
at a constant ~10px on every device, so a bigger icon shows more rain rather than
the same rain drawn larger, and no glyph is ever resampled.

Usage:
  tools/make-launcher-icons.py           regenerate icons and the jungle mapping
  tools/make-launcher-icons.py --table   print the README size table
  tools/make-launcher-icons.py --check   verify what is committed is consistent

Generating needs Pillow; --check and --table need nothing but Python, and no SDK
either -- the committed jungle mapping is itself the device->size table, and is
cross-checked against the SDK only when it is present.
"""
import json
import os
import random
import re
import sys

MANIFEST = 'manifest.xml'
JUNGLE = 'monkey.jungle'
README = 'README.md'
README_HEADING = 'Each supported product is mapped to the icon its device asks for'
BASE_ICON = 'resources/drawables/launcher_icon.png'
ICON_DIR = 'resources-icon-{}'
ICON_DIR_RE = re.compile(r'^resources-icon-(\d+)$')
DEVICES = os.path.expanduser(
    '~/Library/Application Support/Garmin/ConnectIQ/Devices')

BEGIN = '# BEGIN generated launcher icon mapping -- tools/make-launcher-icons.py'
END = '# END generated launcher icon mapping'

# The face's own rain colour and charset, so the icon is the watch face rather than
# a picture of something like it. Keep in step with MATRIX_COLOR and CHARSET in
# source/Matrix.mc.
MATRIX_COLOR = (0x00, 0xFF, 0x2B)
CHARSET = 'abcdefghijklmnopqrstuvwxyz0123456789'
FONT = 'resources/fonts/MatrixCodeNFI.ttf'

# One glyph cell per ~10 icon pixels. This is the whole design rule: it fixes the
# glyph size, and the icon's size decides how many glyphs fit.
PIXELS_PER_CELL = 10
# Cell height is the glyph plus a gap, as the rain has on screen.
CELL_LEADING = 1.25
# Trails fade towards the top, but only to this fraction of full brightness. The
# on-screen ramp fades all the way to black over half a screen; an icon is three to
# six rows tall, so the same ramp would leave its top half nearly unlit.
TRAIL_FLOOR = 0.30
# A column's leading glyph sits on the bottom row or the one above it. Enough to
# keep the leading edge ragged, and narrowed to nothing on the three-row icons,
# where staggering even one row empties a third of the artwork.
HEAD_STAGGER = 2
# Fixed, so regenerating without changing the rules reproduces the same artwork.
SEED = 20260917


# resources/drawables/launcher_icon.png is rendered once more at the largest required
# size. That copy is what a product gets if it is added to manifest.xml without
# rerunning this tool: the default resource path still resolves, and the scaling is
# 70->N rather than the 100->N this replaced.
#
# Derived, never a constant. An SDK update that raises some device above the current
# largest would otherwise leave the fallback behind, quietly contradicting what the
# README says it is. `generate` derives it from the SDK, `check` from the committed
# mapping -- which is the same number, and keeps the check SDK-free.
def fallback_size(sizes):
    """The largest size any supported product asks for."""
    return max(sizes.values())


def products():
    return re.findall(r'<iq:product id="([^"]+)"', open(MANIFEST).read())


def sdk_sizes(ids):
    """product -> launcher icon edge, from the SDK. None when the SDK is absent."""
    if not os.path.isdir(DEVICES):
        return None
    out = {}
    for d in ids:
        f = os.path.join(DEVICES, d, 'compiler.json')
        if not os.path.exists(f):
            return None
        icon = json.load(open(f))['launcherIcon']
        if icon['width'] != icon['height']:
            sys.exit(f"{d}: launcher icon {icon['width']}x{icon['height']} is not square; "
                     "this tool renders square icons only")
        out[d] = icon['width']
    return out


# ------------------------------------------------------------------------ rendering

def render(size):
    from PIL import Image, ImageDraw, ImageFont

    columns = max(3, int(size / PIXELS_PER_CELL + 0.5))
    cell_w = size / columns

    # Fit the widest glyph in the charset, not a representative one: the typeface is
    # not monospace, and fitting 'm' alone lets wider glyphs bleed into the next cell.
    font = box = None
    for points in range(int(cell_w * 2) + 6, 3, -1):
        font = ImageFont.truetype(FONT, points)
        boxes = [font.getbbox(c) for c in CHARSET]
        w = max(b[2] - b[0] for b in boxes)
        h = max(b[3] - b[1] for b in boxes)
        if w <= cell_w and h <= cell_w:
            box = (w, h)
            break
    if box is None:
        sys.exit(f"no point size renders {FONT} into a {cell_w:.1f}px cell")

    cell_h = box[1] * CELL_LEADING
    # The bottom row may run off the edge, as the rain does on screen -- but only
    # while most of it is still on the icon. A sliver of glyph tops reads as dirt
    # rather than as rain, and at 38x38 that sliver is a sixth of the artwork.
    rows = int(size // cell_h)
    if size - rows * cell_h >= box[1] / 2:
        rows += 1

    image = Image.new('RGB', (size, size), (0, 0, 0))
    draw = ImageDraw.Draw(image)
    rnd = random.Random(SEED)

    for column in range(columns):
        head = rows - 1 - rnd.randrange(min(HEAD_STAGGER, max(1, rows - 3)))
        for step in range(head + 1):
            row = head - step
            fade = 1.0 - step / max(1, rows - 1)
            level = TRAIL_FLOOR + (1.0 - TRAIL_FLOOR) * max(0.0, fade)
            colour = tuple(int(channel * level) for channel in MATRIX_COLOR)
            glyph = CHARSET[rnd.randrange(len(CHARSET))]
            b = font.getbbox(glyph)
            x = column * cell_w + (cell_w - (b[2] - b[0])) / 2 - b[0]
            draw.text((x, row * cell_h - b[1]), glyph, font=font, fill=colour)

    return image


DRAWABLES = ('<drawables xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
             'xsi:noNamespaceSchemaLocation='
             '"https://developer.garmin.com/downloads/connect-iq/resources.xsd">\n'
             '    <bitmap id="LauncherIcon" filename="launcher_icon.png" dithering="none" />\n'
             '</drawables>\n')


def png_size(path):
    """(width, height) out of the PNG header, so --check needs no image library."""
    with open(path, 'rb') as f:
        head = f.read(24)
    if head[:8] != b'\x89PNG\r\n\x1a\n' or head[12:16] != b'IHDR':
        return None
    return int.from_bytes(head[16:20], 'big'), int.from_bytes(head[20:24], 'big')


def write_icon(path, size):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    render(size).save(path)


# -------------------------------------------------------------------- jungle mapping

def mapping_block(sizes):
    lines = [BEGIN,
             '# Launcher icon size is per device, not per device family (#42).',
             '# Regenerate with: make icons']
    for product in sorted(sizes):
        lines.append(f'{product}.resourcePath = $({product}.resourcePath);'
                     + ICON_DIR.format(sizes[product]))
    lines.append(END)
    return '\n'.join(lines) + '\n'


def splice(text, block):
    if BEGIN in text:
        head = text.split(BEGIN)[0]
        tail = text.split(END, 1)[1].lstrip('\n')
        return head + block + (('\n' + tail) if tail else '')
    return text.rstrip('\n') + '\n\n' + block


def jungle_mapping():
    """product -> size, read back out of the committed jungle."""
    text = open(JUNGLE).read()
    if BEGIN not in text:
        return {}
    block = text.split(BEGIN, 1)[1].split(END, 1)[0]
    return {m.group(1): int(m.group(2)) for m in
            re.finditer(r'^(\S+)\.resourcePath\s*=.*;resources-icon-(\d+)\s*$', block, re.M)}


# ----------------------------------------------------------------- the README table

TABLE_RE = re.compile(r'^\|\s*(\S+)\s*\|\s*(\d+) x (\d+)\s*\|$', re.M)


def table(mapping):
    """The README's icon table, derived from the mapping. Never hand-edit the copy there.

    Sorted by size rather than by product, because the point the table has to make is
    that the eight sizes cut across every other way of grouping the devices.
    """
    rows = [(p, f'{mapping[p]} x {mapping[p]}')
            for p in sorted(mapping, key=lambda p: (-mapping[p], p))]
    left = max([len('Product')] + [len(r[0]) for r in rows])
    right = max([len('Icon')] + [len(r[1]) for r in rows])
    out = [f'| {"Product":<{left}} | {"Icon":>{right}} |',
           f'| :{"-" * (left - 1)} | {"-" * (right - 1)}: |']
    out += [f'| {a:<{left}} | {b:>{right}} |' for a, b in rows]
    return '\n'.join(out) + '\n'


def write_readme_table(sizes):
    """
    Replaces the table under README_HEADING with one derived from `sizes`.

    Part of generation, not a separate step: the README calls the table generated
    output and tells contributors not to hand-edit it, so leaving it to a second
    command would mean every device list change lands with a stale table and a
    failing `make check-icons`.
    """
    text = open(README).read()
    if README_HEADING not in text:
        sys.exit(f"{README} has no table to update: the sentence "
                 f"{README_HEADING!r} is not in it.")
    head, tail = text.split(README_HEADING, 1)

    lines = tail.split('\n')
    # The table is the first run of "|" lines after the heading sentence, and it
    # belongs to this section: stop at the next markdown heading rather than walking
    # into whatever table comes later in the document.
    start = end = None
    for i, line in enumerate(lines):
        if line.startswith('#'):
            break
        if line.startswith('|'):
            start = i
            end = next((j for j in range(i, len(lines)) if not lines[j].startswith('|')),
                       len(lines))
            break
    rows = table(sizes).rstrip('\n').split('\n')
    if start is None:
        # No table yet: put one after the blank line that follows the sentence.
        start = end = next((i for i, line in enumerate(lines) if not line.strip()), 0) + 1
        rows = rows + ['']

    open(README, 'w').write(head + README_HEADING + '\n'.join(lines[:start] + rows + lines[end:]))
    print(f"  {len(sizes)} products tabulated in {README}")


def readme_table():
    """product -> size, as the README states it. None when the table is not there at all."""
    text = open(README).read()
    if README_HEADING not in text:
        return None
    body = text.split(README_HEADING, 1)[1]
    return {m.group(1): int(m.group(2)) for m in TABLE_RE.finditer(body)
            if m.group(2) == m.group(3)}


# --------------------------------------------------------------------------- actions

def generate():
    ids = products()
    sizes = sdk_sizes(ids)
    if sizes is None:
        sys.exit(f"launcher icon sizes come from the SDK's device definitions under\n"
                 f"  {DEVICES}\n"
                 "Install the SDK and the device definitions, then rerun.")

    for size in sorted(set(sizes.values()), reverse=True):
        directory = os.path.join(ICON_DIR.format(size), 'drawables')
        write_icon(os.path.join(directory, 'launcher_icon.png'), size)
        open(os.path.join(directory, 'drawables.xml'), 'w').write(DRAWABLES)
        count = sum(1 for v in sizes.values() if v == size)
        print(f"  {size}x{size}  {directory}/launcher_icon.png"
              f"  ({count} device{'' if count == 1 else 's'})")

    fallback = fallback_size(sizes)
    write_icon(BASE_ICON, fallback)
    print(f"  {fallback}x{fallback}  {BASE_ICON}  (fallback)")

    # Read before opening for write: `open(JUNGLE, 'w')` truncates, and as the
    # receiver of .write() it is evaluated before the argument that reads the file.
    text = open(JUNGLE).read()
    open(JUNGLE, 'w').write(splice(text, mapping_block(sizes)))
    print(f"  {len(sizes)} products mapped in {JUNGLE}")

    write_readme_table(sizes)

    for directory in sorted(unmapped(set(sizes.values()))):
        print(f"  NOTE  {directory}/ is no longer required by any product -- remove it")


def unmapped(sizes):
    """Icon directories on disk that no product asks for."""
    found = ((d, ICON_DIR_RE.match(d)) for d in os.listdir('.'))
    return [d for d, m in found if m and int(m.group(1)) not in sizes]


def check():
    fail = []

    def ok(cond, msg):
        print(f"  {'OK  ' if cond else 'FAIL'}  {msg}")
        if not cond:
            fail.append(msg)

    ids = products()
    mapped = jungle_mapping()

    print("\nMAPPING")
    missing = sorted(set(ids) - set(mapped))
    extra = sorted(set(mapped) - set(ids))
    ok(not missing, "every manifest product has an icon resourcePath"
       + (f" (missing {missing})" if missing else f" ({len(ids)} products)"))
    ok(not extra, "no resourcePath entry for a product outside the manifest"
       + (f" (extra {extra})" if extra else ""))

    print("\nICONS")
    for size in sorted(set(mapped.values()), reverse=True):
        png = os.path.join(ICON_DIR.format(size), 'drawables', 'launcher_icon.png')
        xml = os.path.join(ICON_DIR.format(size), 'drawables', 'drawables.xml')
        if not os.path.exists(png):
            ok(False, f"{png} missing"); continue
        got = png_size(png)
        ok(got == (size, size),
           f"{png} is {got and 'x'.join(map(str, got))}, directory promises {size}x{size}")
        # Compared whole, not searched for "LauncherIcon": the file is generated, and
        # a declaration naming the wrong filename contains that substring too and
        # would pass, only to fail at compile time.
        ok(os.path.exists(xml) and open(xml).read() == DRAWABLES,
           f"{xml} declares LauncherIcon -> launcher_icon.png")

    fallback = fallback_size(mapped) if mapped else None
    ok(fallback is not None
       and os.path.exists(BASE_ICON) and png_size(BASE_ICON) == (fallback, fallback),
       f"{BASE_ICON} is the {fallback}x{fallback} fallback, the largest size mapped")

    orphans = sorted(unmapped(set(mapped.values())))
    ok(not orphans, "no icon directory left unmapped"
       + (f" ({orphans})" if orphans else ""))

    print("\nREADME")
    stated = readme_table()
    if stated is None:
        ok(False, f"{README} has no icon table under {README_HEADING!r}")
    else:
        wrong = sorted(set(stated.items()) ^ set(mapped.items()))
        ok(not wrong, "README icon table gives every product the size the jungle maps it to"
           + (f" (disagrees on {sorted({p for p, _ in wrong})[:3]})" if wrong else
              f" ({len(stated)} products)"))

    print("\nAGAINST THE SDK")
    sizes = sdk_sizes(ids)
    if sizes is None:
        print("  SKIP  device definitions not installed; mapping not cross-checked")
    else:
        wrong = sorted((d, mapped[d], sizes[d]) for d in sizes
                       if d in mapped and mapped[d] != sizes[d])
        ok(not wrong, "every mapping matches the device's launcherIcon"
           + (f" (wrong {wrong[:3]})" if wrong else f" ({len(sizes)} devices)"))

    print(f"\n{'ALL CONSISTENT' if not fail else f'{len(fail)} PROBLEM(S)'}\n")
    return 1 if fail else 0


if __name__ == '__main__':
    if '--check' in sys.argv[1:]:
        sys.exit(check())
    if '--table' in sys.argv[1:]:
        sys.stdout.write(table(jungle_mapping()))
        sys.exit(0)
    generate()
