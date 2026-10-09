#!/usr/bin/env python3
"""Lite's launcher icons and store cover: the face's own digital rain.

As a module, this is the renderer garmin-graphics-generator draws Lite's icons with.
`make icons` runs it as

  garmin-graphics-generator icons -R tools/launcher_icon.py \\
      --readme-anchor 'Each supported product is mapped to the icon its device asks for'

which writes resources-icon-<size>/, the fallback in resources/drawables/, the mapping
block in monkey.jungle and the size table in README.md (#78). The launcher icon size
is a per-device property, not a per-family one, which is why the mapping is per
product (#42). Premium's renderer, premium/tools/launcher_icon.py, draws its rain
through this module and adds its star.

As a script, it does what that command does not -- the store cover, and its checks:

  tools/launcher_icon.py cover
  tools/launcher_icon.py check

Every icon is RENDERED at its target size rather than scaled down from one master.
The artwork is digital rain -- fine glyphs, thin strokes, high spatial frequency --
which is the worst case for naive downscaling: at 38x38 a resampled 100x100 still
stops being characters and becomes noise. Rendering natively keeps the glyph cell
at a constant ~10px on every device, so a bigger icon shows more rain rather than
the same rain drawn larger, and no glyph is ever resampled.

The store cover is the same artwork once more, square and much larger, with the column
count fixed instead of the cell size (#219). Premium's cover is this one with its star.

Rendering needs Pillow; `check` needs nothing but Python.
"""
import os
import random
import sys

# The face's own rain colour and charset, so the icon is the watch face rather than
# a picture of something like it. Keep in step with MATRIX_COLOR and CHARSET in
# source/Matrix.mc.
MATRIX_COLOR = (0x00, 0xFF, 0x2B)
CHARSET = 'abcdefghijklmnopqrstuvwxyz'
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

# The store cover is the 70 x 70 icon's composition -- the same 7 columns of rain and
# the same glyphs -- drawn at the cover's size rather than scaled up from 70 (#189,
# #219). 500 x 500 is the size the store's dashboard asks for, and the store allows
# 300 KB. premium/tools/launcher_icon.py draws Premium's from this one, with its star.
COVER = 'resources/graphics/MatrixTimeCover.png'
COVER_SIZE = 500
COVER_COLUMNS = 7
COVER_LIMIT = 300 * 1000


# ------------------------------------------------------------------------ rendering

def columns_for(size):
    """How many columns an icon `size` pixels wide gets: one per PIXELS_PER_CELL."""
    return max(3, int(size / PIXELS_PER_CELL + 0.5))


def render(size, columns=None):
    """The rain, `size` pixels square, in `columns` columns: by default as many as fit
    at PIXELS_PER_CELL. The cover fixes the count instead, and so draws larger glyphs."""
    from PIL import Image, ImageDraw, ImageFont

    columns = columns or columns_for(size)
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


def png_size(path):
    """(width, height) out of the PNG header, so `check` needs no image library."""
    with open(path, 'rb') as f:
        head = f.read(24)
    if head[:8] != b'\x89PNG\r\n\x1a\n' or head[12:16] != b'IHDR':
        return None
    return int.from_bytes(head[16:20], 'big'), int.from_bytes(head[20:24], 'big')


def cover_absence(path):
    """Why a cover has no PNG size, for a check's message: missing, or not a PNG -- an
    LFS pointer, say."""
    return " (missing)" if not os.path.exists(path) else " (not a PNG)"


def cover(size=COVER_SIZE):
    """The store cover: the 70 x 70 icon's rain, drawn at `size`."""
    return render(size, COVER_COLUMNS)


def write_cover(path=COVER):
    os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
    cover().save(path, optimize=True)
    print(f"  {COVER_SIZE}x{COVER_SIZE}  {path}  ({os.path.getsize(path)} bytes, store cover)")


# --------------------------------------------------------------------------- actions

def check():
    """The checks garmin-graphics-generator icons --check does not make: the store
    cover's size and weight. No SDK."""
    fail = []

    def ok(cond, msg):
        print(f"  {'OK  ' if cond else 'FAIL'}  {msg}")
        if not cond:
            fail.append(msg)

    got = png_size(COVER) if os.path.exists(COVER) else None
    ok(got == (COVER_SIZE, COVER_SIZE),
       f"{COVER} is {COVER_SIZE}x{COVER_SIZE}"
       + (f" (it is {got[0]}x{got[1]})" if got and got != (COVER_SIZE, COVER_SIZE) else
          "" if got else cover_absence(COVER)))
    weight = os.path.getsize(COVER) if got else None
    ok(weight is not None and weight < COVER_LIMIT,
       f"{COVER} is under {COVER_LIMIT // 1000} KB"
       + (f" ({weight} bytes)" if weight is not None else ""))

    print(f"\n{'ALL CONSISTENT' if not fail else f'{len(fail)} PROBLEM(S)'}\n")
    return 1 if fail else 0


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['cover']:
        write_cover()
    elif args == ['check']:
        sys.exit(check())
    else:
        sys.exit(__doc__)
