#!/usr/bin/env python3
"""Premium's launcher icons and store cover: Lite's icon with a gold star (#189).

As a module, this is the renderer garmin-graphics-generator draws Premium's icons with.
`make icons` runs it as

  garmin-graphics-generator icons -R premium/tools/launcher_icon.py \\
      --manifest manifest-premium.xml --jungle premium.jungle --icon-root premium \\
      --fallback-icon premium/resources-base/drawables/launcher_icon.png

which writes premium/resources-icon-<size>/ and the mapping block in premium.jungle.
As a script, it does what that command does not -- the store cover, and its checks:

  premium/tools/launcher_icon.py cover <cover.png>
  premium/tools/launcher_icon.py check <fallback.png> <cover.png>

The rain is Lite's, drawn by Lite's own renderer in tools/launcher_icon.py and not
copied: a change to Lite's artwork reaches Premium at the next `make icons`, and
the two editions can only differ by the mark. The mark is a five-point gold star in
the top-right corner, on a black disc so it reads against the rain. It was chosen
over a crown, a gold corner and a gold rim by rendering all four at every launcher
size: at 38 x 38 the star keeps the clearest outline and hides the least rain, and a
corner would vanish if a launcher crops icons to a circle.

Generating and checking both need Pillow: `check` compares every Premium icon with
Lite's, pixel by pixel, outside the star, and Premium's store cover with Lite's outside
the star and the cells it clears. The cover check also reads Lite's rain font, to lay
out those cells.
"""
import importlib.util
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))

# The star, as fractions of the icon's edge, so it is the same shape at every size.
GOLD = (0xFF, 0xC4, 0x2E)
STAR_RADIUS = 0.19
# From the top and right edges to the star's bounding circle.
STAR_INSET = 0.04
# The inner vertices, as a fraction of the outer radius.
STAR_INNER = 0.45
# The black disc behind the star, as a multiple of its radius.
DISC = 1.12
# The mark alone is drawn at this multiple and resampled down, so its edges are
# antialiased. The rain is not: it is Lite's, drawn natively at the target size.
SUPERSAMPLE = 8

# The store cover is Lite's cover with the star (#219): its size, column count and the
# store's limit are Lite's, in tools/launcher_icon.py.

# How far from the disc's edge, measured from pixel centres, Premium may differ from
# Lite: the antialiased rim of the resampled disc reaches about 2.6 px.
RIM = 3

ICON_DIRECTORY = re.compile(r'^resources-icon-(\d+)$')


def _lite():
    """Lite's icon module. Its font path is relative to the repository, so it is pinned
    to an absolute one: the renderer then works from any directory."""
    spec = importlib.util.spec_from_file_location(
        'lite_launcher_icons', os.path.join(ROOT, 'tools', 'launcher_icon.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.FONT = os.path.join(ROOT, module.FONT)
    return module


LITE = _lite()


def _disc(size):
    """The centre and radius of the black disc behind the star, in pixels at `size`."""
    r = size * STAR_RADIUS
    return size - r - size * STAR_INSET, r + size * STAR_INSET, r * DISC


def _star(size):
    from PIL import Image, ImageDraw

    edge = size * SUPERSAMPLE
    layer = Image.new('RGBA', (edge, edge), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    r = edge * STAR_RADIUS
    cx, cy, d = _disc(edge)
    draw.ellipse((cx - d, cy - d, cx + d, cy + d), fill=(0, 0, 0, 255))
    points = []
    for i in range(10):
        radius = r if i % 2 == 0 else r * STAR_INNER
        angle = -math.pi / 2 + i * math.pi / 5
        points.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    draw.polygon(points, fill=GOLD + (255,))
    return layer.resize((size, size), Image.LANCZOS)


def _marked(rain):
    icon = rain.convert('RGBA')
    icon.alpha_composite(_star(rain.width))
    return icon.convert('RGB')


def render(size):
    """One launcher icon, `size` pixels square: Lite's, with the star."""
    return _marked(LITE.render(size))


def _cells(size, columns=None):
    """The glyph cells LITE.render lays out at `size` in `columns` columns, as
    (x0, y0, x1, y1) boxes.

    This mirrors the sizing at the top of LITE.render: the column count, the widest
    glyph fitted to a cell, the leading and the row count. `cover` checks that every
    lit pixel falls inside one of these, so the two cannot drift apart unnoticed.
    """
    from PIL import ImageFont

    columns = columns or LITE.columns_for(size)
    cell_w = size / columns
    for points in range(int(cell_w * 2) + 6, 3, -1):
        font = ImageFont.truetype(LITE.FONT, points)
        boxes = [font.getbbox(c) for c in LITE.CHARSET]
        h = max(b[3] - b[1] for b in boxes)
        if max(b[2] - b[0] for b in boxes) <= cell_w and h <= cell_w:
            break
    cell_h = h * LITE.CELL_LEADING
    rows = int(size // cell_h)
    if size - rows * cell_h >= h / 2:
        rows += 1
    return [(c * cell_w, r * cell_h, (c + 1) * cell_w, r * cell_h + h)
            for c in range(columns) for r in range(rows)]


def _cleared(cells, size):
    """The pixel boxes the cover blanks, (x0, y0, x1, y1) inclusive: one per cell that
    reaches under the star's disc, a pixel wider all round, and truncated to whole
    pixels as Pillow truncates a rectangle's coordinates. `cover` paints exactly these
    and `_cover_drift` skips exactly these, so the two cannot disagree by a pixel."""
    cx, cy, d = _disc(size)
    return [(int(x0 - 1), int(y0 - 1), int(x1 + 1), int(y1 + 1)) for x0, y0, x1, y1 in cells
            if math.hypot(min(max(cx, x0), x1) - cx, min(max(cy, y0), y1) - cy) < d]


def cover(size=None):
    """The store cover: Lite's cover, with the star (#219).

    A glyph whose cell reaches under the disc is left out whole. At icon sizes the
    disc trims such a glyph by a pixel or two; at the cover's size it would cut it
    into fragments that read as dirt around the star."""
    from PIL import Image, ImageChops, ImageDraw

    size = size or LITE.COVER_SIZE
    rain = LITE.cover(size)
    cells = _cells(size, LITE.COVER_COLUMNS)

    inside = Image.new('L', rain.size, 0)
    for x0, y0, x1, y1 in cells:
        ImageDraw.Draw(inside).rectangle((x0 - 1, y0 - 1, x1 + 1, y1 + 1), fill=255)
    stray = ImageChops.multiply(rain.convert('L'), ImageChops.invert(inside)).getbbox()
    if stray:
        sys.exit(f"cover: Lite's renderer drew outside the cells _cells() expects, at {stray}; "
                 "bring _cells() back in step with tools/launcher_icon.py")

    draw = ImageDraw.Draw(rain)
    for box in _cleared(cells, size):
        draw.rectangle(box, fill=(0, 0, 0))
    return _marked(rain)


def write_cover(path):
    os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
    cover().save(path, optimize=True)
    size = LITE.COVER_SIZE
    print(f"  {size}x{size}  {path}  ({os.path.getsize(path)} bytes)")


def _cover_drift(cover_path):
    """Pixels where Premium's cover differs from Lite's, away from the star and from the
    cells it leaves out. -1 if either is missing or unreadable, not square, or the two
    differ in size: the size checks report which, and a malformed file must fail the
    check rather than end it in a traceback."""
    from PIL import Image

    lite_path = os.path.join(ROOT, LITE.COVER)
    try:
        lite = Image.open(lite_path).convert('RGB')
        premium = Image.open(cover_path).convert('RGB')
    except OSError:
        # Missing files raise FileNotFoundError; unreadable ones UnidentifiedImageError.
        # Both are OSErrors.
        return -1
    if lite.size != premium.size or lite.width != lite.height:
        return -1
    size = lite.width
    cx, cy, d = _disc(size)
    cleared = _cleared(_cells(size, LITE.COVER_COLUMNS), size)
    a, b = lite.load(), premium.load()
    return sum(1 for y in range(size) for x in range(size)
               if a[x, y] != b[x, y]
               and math.hypot(x + .5 - cx, y + .5 - cy) > d + RIM
               and not any(x0 <= x <= x1 and y0 <= y <= y1 for x0, y0, x1, y1 in cleared))


def _drift(size):
    """Pixels where Premium's icon at `size` differs from Lite's, away from the star."""
    from PIL import Image

    lite = Image.open(os.path.join(ROOT, f'resources-icon-{size}', 'drawables',
                                   'launcher_icon.png')).convert('RGB')
    premium = Image.open(os.path.join(ROOT, 'premium', f'resources-icon-{size}', 'drawables',
                                      'launcher_icon.png')).convert('RGB')
    if lite.size != premium.size:
        return -1
    cx, cy, d = _disc(size)
    a, b = lite.load(), premium.load()
    return sum(1 for y in range(size) for x in range(size)
               if a[x, y] != b[x, y] and math.hypot(x + .5 - cx, y + .5 - cy) > d + RIM)


def check(fallback, cover_path):
    """The checks garmin-graphics-generator icons --check does not make: that Premium's
    icons are still Lite's but for the star, Premium's fallback, and the store cover.
    No SDK."""
    fail = []

    def ok(cond, msg):
        print(f"  {'OK  ' if cond else 'FAIL'}  {msg}")
        if not cond:
            fail.append(msg)

    # The largest size mapped is the largest icon directory: the shared check has
    # already failed if the two disagree.
    root = os.path.join(ROOT, 'premium')
    sizes = [int(m.group(1)) for m in map(ICON_DIRECTORY.match, os.listdir(root)) if m]
    largest = max(sizes) if sizes else None
    ok(largest is not None and os.path.exists(fallback)
       and LITE.png_size(fallback) == (largest, largest),
       f"{fallback} is the {largest}x{largest} fallback, the largest size mapped")

    # Without it the fallback is never compiled, and Premium falls back to Lite's.
    declaration = os.path.join(os.path.dirname(fallback), 'drawables.xml')
    shared = os.path.join(ROOT, 'resources', 'drawables', 'drawables.xml')
    ok(os.path.exists(declaration) and open(declaration).read() == open(shared).read(),
       f"{declaration} declares LauncherIcon, as {os.path.relpath(shared, ROOT)} does")

    # Regenerating Lite's icons alone would leave Premium on the old artwork.
    for size in sorted(sizes, reverse=True):
        drift = _drift(size)
        ok(drift == 0, f"premium/resources-icon-{size} is Lite's icon but for the star"
           + ("" if drift == 0 else f" ({'sizes differ' if drift < 0 else f'{drift} pixels differ'};"
              " regenerate both with make icons)"))

    size, limit = LITE.COVER_SIZE, LITE.COVER_LIMIT
    got = LITE.png_size(cover_path) if os.path.exists(cover_path) else None
    ok(got == (size, size),
       f"{cover_path} is {size}x{size}" + (f" (it is {got[0]}x{got[1]})" if got and got != (size, size)
                                          else "" if got else LITE.cover_absence(cover_path)))
    weight = os.path.getsize(cover_path) if got else None
    ok(weight is not None and weight < limit,
       f"{cover_path} is under {limit // 1000} KB"
       + (f" ({weight} bytes)" if weight is not None else ""))

    # Regenerating Lite's cover alone would leave Premium's on the old artwork (#219).
    drift = _cover_drift(cover_path)
    ok(drift == 0, f"{cover_path} is {LITE.COVER} but for the star"
       + ("" if drift == 0 else f" ({'missing, unreadable or of different sizes' if drift < 0 else f'{drift} pixels differ'};"
          " regenerate both with make icons)"))

    print(f"\n{'ALL CONSISTENT' if not fail else f'{len(fail)} PROBLEM(S)'}\n")
    return 1 if fail else 0


if __name__ == '__main__':
    args = sys.argv[1:]
    if args[:1] == ['cover'] and len(args) == 2:
        write_cover(args[1])
    elif args[:1] == ['check'] and len(args) == 3:
        sys.exit(check(args[1], args[2]))
    else:
        sys.exit(__doc__)
