#!/usr/bin/env python3
"""Regenerate every image in resources/graphics/ from the current build.

The seven files here were made by hand: run the simulator, capture screenshots,
resize and composite them, upload the result. #80 is what that cost -- #54 dropped
`0-9` from the rain charset and all seven went on showing numerals for months,
because a capture is derived from the app but is not generated output, so nothing
reports it stale.

Capturing and composing are not this project's work to do. `garmin-graphics-generator
shots` runs the Connect IQ simulator in a container under Xvfb -- no GUI, no macOS
permission to grant, nothing to click -- and returns each frame twice: the device
framebuffer at native resolution, and the same frame set into the SDK's own watch
render with the surround already transparent. `hero` composes those into the store
image. Both are shared with the sibling faces (#78 is the standing argument against
keeping a local copy of anything generic).

What is here is what is specific to this face: which files, under which names, at
which sizes, captured on which product.

  MatrixTimeCapture.png         one raw framebuffer, nothing composited over it
  MatrixTime1.png .. 3.png      watch renders at 200px, for the store gallery
  MatrixTime4.png               the same, for the README features table
  MatrixTimeHero.png            those four scattered across 1440x720, the store hero
  MatrixTimeHero-small.png      the same composition at 900x450, the README banner

The gallery images and the hero are flattened onto white, which is what the files
they replace look like and what the store gallery expects. `--background none`
keeps them transparent instead.

Usage:
  tools/make-graphics.py                   regenerate everything
  tools/make-graphics.py --background none keep the transparency instead of white
  tools/make-graphics.py --timezone ...    choose the clock the captured face shows

Needs Docker running, and garmin-graphics-generator 0.5.0 or newer.
"""
import argparse
import os
import sys
import tempfile
from importlib.metadata import PackageNotFoundError, version
from itertools import takewhile

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GRAPHICS = os.path.join(PROJECT, "resources", "graphics")

# The product every capture is taken on. The Makefile's DEVICE default and the one
# CI compiles and tests, so the images show what is actually verified. Its screen is
# 416x416; the file this replaces was 454x454, which was another product entirely.
DEFAULT_DEVICE = "epix2pro47mm"

# Four frames, and not a setting. The gallery is four files, because the store
# listing names them MatrixTime1 to MatrixTime4, and the hero is those same four.
# More is not better in the hero either: the composition places watches without
# overlapping them beyond MAX_OVERLAP, so every extra one makes them all smaller to
# fit. A --count that captured more than this used would either change the hero
# behind the option's back or quietly throw the extra frames away, and neither is
# worth a knob. The rain is seeded from the clock and from uptime, so frames spaced
# a few seconds apart differ by more than one step of the animation.
SHOT_COUNT = 4

CAPTURE_NAME = "MatrixTimeCapture.png"
GALLERY_NAME = "MatrixTime{index}.png"
HERO_NAME = "MatrixTimeHero.png"
HERO_SMALL_NAME = "MatrixTimeHero-small.png"

GALLERY_WIDTH = 200
HERO_SIZE = (1440, 720)
HERO_SMALL_SIZE = (900, 450)

# Passed to the hero composition. The images this replaces are scattered at varying
# size and angle rather than laid out in a row, and these reproduce that.
SIZE_VARIATION = 5
ORIENTATION_VARIATION = 20
MAX_OVERLAP = 20

# The first release carrying the shots command, and the hero that does not drop
# inputs. Both are needed here: without the first there is nothing to capture with,
# and without the second the hero silently arrives with fewer watches than it was
# given, which looks like a bad capture rather than a stale tool.
GENERATOR = "garmin_graphics_generator"
REQUIRED_VERSION = "0.5.0"
RELEASE_URL = (
    "https://github.com/wkusnierczyk/garmin-graphics-generator/releases/tag/v0.5.0"
)

INSTALL_HINT = f"""garmin-graphics-generator {REQUIRED_VERSION} or newer is needed, and {{problem}}.

    pip install 'garmin-graphics-generator @ git+https://github.com/wkusnierczyk/garmin-graphics-generator@v{REQUIRED_VERSION}'

It carries the simulator capture and the hero composition, which are shared with the
other watch faces rather than kept here. Release notes: {RELEASE_URL}"""


def as_numbers(version):
    """A version as a tuple of integers, for comparing one release against another."""
    numbers = []
    for part in version.split("."):
        digits = "".join(takewhile(str.isdigit, part))
        if not digits:
            break
        numbers.append(int(digits))
    return tuple(numbers)


def load_generator():
    """Imports the shared generator, or explains what is wrong with what is there."""
    try:
        installed = version(GENERATOR)
    except PackageNotFoundError:
        sys.exit(INSTALL_HINT.format(problem="it is not installed"))

    if as_numbers(installed) < as_numbers(REQUIRED_VERSION):
        sys.exit(INSTALL_HINT.format(problem=f"{installed} is installed"))

    try:
        from garmin_graphics_generator.core import (  # noqa: F401
            WatchHeroGenerator,
        )
        from garmin_graphics_generator.shots import ShotsError, take_shots
    except ImportError as error:
        sys.exit(INSTALL_HINT.format(problem=f"importing it failed: {error}"))
    return WatchHeroGenerator, take_shots, ShotsError


def flatten(image, background):
    """Puts an image on a solid background, or leaves its transparency alone."""
    if background == "none":
        return image
    from PIL import Image

    flattened = Image.new("RGBA", image.size, background)
    flattened.alpha_composite(image.convert("RGBA"))
    return flattened.convert("RGB")


def write_gallery(shots, background, quiet):
    """Writes the four 200px renders: three for the store gallery, one for the README."""
    from PIL import Image

    for index, shot in enumerate(shots, start=1):
        with Image.open(shot.watch_path) as watch:
            height = round(GALLERY_WIDTH * watch.height / watch.width)
            resized = watch.convert("RGBA").resize(
                (GALLERY_WIDTH, height), Image.LANCZOS
            )
        path = os.path.join(GRAPHICS, GALLERY_NAME.format(index=index))
        flatten(resized, background).save(path)
        report(path, quiet)


def write_capture(shots, quiet):
    """Writes the raw device framebuffer, with nothing composited over it."""
    from PIL import Image

    path = os.path.join(GRAPHICS, CAPTURE_NAME)
    with Image.open(shots[0].screen_path) as screen:
        screen.save(path)
    report(path, quiet)


def write_hero(generator_class, shots, background, quiet):
    """
    Writes the store hero, and the README banner as the same composition scaled.

    Scaled rather than composed a second time: the placement is random, so a second
    run would put the watches somewhere else, and the banner is meant to be the
    hero, smaller.
    """
    from PIL import Image

    generator = (
        generator_class()
        .set_input_paths([shot.watch_path for shot in shots])
        .set_output_directory(GRAPHICS)
        .set_hero_filename(HERO_NAME)
        .set_hero_size(*HERO_SIZE)
        .set_variations(SIZE_VARIATION, ORIENTATION_VARIATION)
        .set_max_overlap(MAX_OVERLAP)
        .prepare_output_directory()
        .process_input_images()
        .generate_hero_composition()
    )
    # generate_resized_files is deliberately not called: it would write one resized
    # copy per input under the input's own name, and the gallery images are four
    # chosen frames under this project's names.
    del generator

    hero_path = os.path.join(GRAPHICS, HERO_NAME)
    with Image.open(hero_path) as hero:
        composed = hero.convert("RGBA")
        flatten(composed, background).save(hero_path)
        small = composed.resize(HERO_SMALL_SIZE, Image.LANCZOS)
    report(hero_path, quiet)

    small_path = os.path.join(GRAPHICS, HERO_SMALL_NAME)
    flatten(small, background).save(small_path)
    report(small_path, quiet)


def report(path, quiet):
    """Says what was written, as a path relative to the project."""
    if not quiet:
        print(f"  {os.path.relpath(path, PROJECT)}")


def main():
    parser = argparse.ArgumentParser(
        description="Regenerate resources/graphics from the simulator."
    )
    parser.add_argument(
        "-d",
        "--device",
        default=DEFAULT_DEVICE,
        help=f"Product to capture on (default: {DEFAULT_DEVICE})",
    )
    parser.add_argument(
        "--background",
        default="white",
        help="Background for the gallery and hero images, or 'none' to keep them "
        "transparent (default: white)",
    )
    parser.add_argument(
        "--platform",
        help="Container platform; linux/amd64 is needed on an arm64 machine",
    )
    parser.add_argument(
        "--timezone",
        help="TZ for the container, which is the time the captured face shows",
    )
    parser.add_argument(
        "-q", "--silent", action="store_true", help="Print nothing but errors"
    )
    arguments = parser.parse_args()

    generator_class, take_shots, shots_error = load_generator()

    if not arguments.silent:
        print(f"Capturing {SHOT_COUNT} frames of {arguments.device}...")

    with tempfile.TemporaryDirectory(prefix="matrix-graphics-") as work:
        try:
            shots = take_shots(
                project=PROJECT,
                product=arguments.device,
                output_directory=os.path.join(work, "shots"),
                work_directory=work,
                count=SHOT_COUNT,
                platform=arguments.platform,
                timezone=arguments.timezone,
            )
        except shots_error as error:
            sys.exit(f"capture failed: {error}")

        if not arguments.silent:
            print("Writing resources/graphics:")
        write_capture(shots, arguments.silent)
        write_gallery(shots, arguments.background, arguments.silent)
        write_hero(generator_class, shots, arguments.background, arguments.silent)

    return 0


if __name__ == "__main__":
    sys.exit(main())
