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

The rain is Lite's, drawn by Lite's own renderer in tools/make-launcher-icons.py and
not copied: a change to Lite's artwork reaches Premium at the next `make icons`, and
the two editions can only differ by the mark. The mark is a five-point gold star in
the top-right corner, on a black disc so it reads against the rain. It was chosen
over a crown, a gold corner and a gold rim by rendering all four at every launcher
size: at 38 x 38 the star keeps the clearest outline and hides the least rain, and a
corner would vanish if a launcher crops icons to a circle.

Generating needs Pillow; `check` needs nothing but Python.
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

# The store cover is the 70 x 70 icon's composition -- the same 7 columns of rain
# and the same glyphs -- drawn at the cover's size rather than scaled up from 70.
# Square, and well within the store's 300 KB.
COVER_SIZE = 512
COVER_COLUMNS = 7
COVER_LIMIT = 300 * 1000

ICON_DIRECTORY = re.compile(r'^resources-icon-(\d+)$')


def _lite():
    """Lite's icon module. Its font path is relative to the repository, so it is pinned
    to an absolute one: the renderer then works from any directory."""
    spec = importlib.util.spec_from_file_location(
        'lite_launcher_icons', os.path.join(ROOT, 'tools', 'make-launcher-icons.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.FONT = os.path.join(ROOT, module.FONT)
    return module


LITE = _lite()


def _star(size):
    from PIL import Image, ImageDraw

    edge = size * SUPERSAMPLE
    layer = Image.new('RGBA', (edge, edge), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    r = edge * STAR_RADIUS
    cx, cy = edge - r - edge * STAR_INSET, r + edge * STAR_INSET
    d = r * DISC
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


def cover(size=COVER_SIZE):
    """The store cover: the 70 x 70 icon's rain at `size`, with the star."""
    # Lite's renderer fixes the glyph cell at PIXELS_PER_CELL and lets the size decide
    # how many columns fit. For the cover the column count is what is fixed, so the
    # cell is widened for this one call and put back.
    cell = LITE.PIXELS_PER_CELL
    LITE.PIXELS_PER_CELL = size / COVER_COLUMNS
    try:
        rain = LITE.render(size)
    finally:
        LITE.PIXELS_PER_CELL = cell
    return _marked(rain)


def write_cover(path):
    os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
    cover().save(path, optimize=True)
    print(f"  {COVER_SIZE}x{COVER_SIZE}  {path}  ({os.path.getsize(path)} bytes)")


def check(fallback, cover_path):
    """The checks garmin-graphics-generator icons --check does not make: Premium's
    fallback icon, and the store cover. Pure Python, and no SDK."""
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

    got = LITE.png_size(cover_path) if os.path.exists(cover_path) else None
    ok(got is not None and got[0] == got[1],
       f"{cover_path} is a square PNG" + (f" ({got[0]}x{got[1]})" if got else " (missing)"))
    weight = os.path.getsize(cover_path) if got else None
    ok(weight is not None and weight < COVER_LIMIT,
       f"{cover_path} is under {COVER_LIMIT // 1000} KB"
       + (f" ({weight} bytes)" if weight is not None else ""))

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
