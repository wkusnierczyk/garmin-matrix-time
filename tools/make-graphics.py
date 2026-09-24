#!/usr/bin/env python3
"""Regenerate every image in resources/graphics/ from the current build.

The files here were made by hand: run the simulator, capture screenshots, resize and
composite them, upload the result. #80 is what that cost -- #54 dropped `0-9` from the
rain charset and all seven of them went on showing numerals for months,
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
  MatrixTime5.png               the always-on scene, for both (#128)
  MatrixTimeHero.png            those five scattered across 1440x720, the store hero
  MatrixTimeHero-small.png      the same composition at 900x450, the README banner

MatrixTime5.png is a second capture run rather than a fifth frame of the first. The
simulator will not enter always-on headlessly -- Display Mode is a GUI menu and is not
one of the keys it persists -- so that frame comes from a build in which onUpdate takes
the low-power branch unconditionally, selected by layering graphics.jungle over
monkey.jungle. Only the trigger is forced; see source/View.mc.

The gallery images and the hero are flattened onto white, which is what the files
they replace look like and what the store gallery expects. `--background none`
keeps them transparent instead.

Usage:
  tools/make-graphics.py                   regenerate everything
  tools/make-graphics.py --background none keep the transparency instead of white
  tools/make-graphics.py --timezone ...    choose the clock the captured face shows

Needs Docker running, and garmin-graphics-generator 0.5.1 or newer.
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

# Four woken frames, and not a setting. The gallery is five files, because the store
# listing names them MatrixTime1 to MatrixTime5, and the hero is those same five.
# More is not better in the hero either: the composition places watches without
# overlapping them beyond MAX_OVERLAP, so every extra one makes them all smaller to
# fit. A --count that captured more than this used would either change the hero
# behind the option's back or quietly throw the extra frames away, and neither is
# worth a knob. The rain is seeded from the clock and from uptime, so frames spaced
# a few seconds apart differ by more than one step of the animation.
SHOT_COUNT = 4

# The fifth image is the always-on scene, and it needs its own capture run: the
# simulator resets Display Mode to High Power on every launch and persists no key for
# it, so always-on is reached by compiling the forcing in rather than by asking the
# simulator for it. graphics.jungle is one line layered over monkey.jungle; monkeyc -f
# takes the list and lets the later file override the earlier one. One frame is enough
# -- the scene is the time alone, shifted a step every minute, so a second frame taken
# seconds later would be the same picture.
ALWAYS_ON_JUNGLE = "monkey.jungle;graphics.jungle"
ALWAYS_ON_COUNT = 1

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

# 0.5.0 brought the shots command; 0.5.1 is what this needs, for two things the fifth
# image depends on. Its hero retries the whole arrangement instead of abandoning an
# image it could not place, which is what makes a five-watch composition reliable
# rather than lucky -- at four, the same request landed two watches on one run and four
# on the next. And its shots accepts a list of jungle files, which is how the always-on
# capture selects the forced build: 0.5.0 checked the whole string as one filename and
# rejected "monkey.jungle;graphics.jungle" before starting the container.
GENERATOR = "garmin_graphics_generator"
REQUIRED_VERSION = "0.5.1"
RELEASE_URL = (
    "https://github.com/wkusnierczyk/garmin-graphics-generator/releases/tag/v0.5.1"
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
    """Writes the five 200px renders, in the order the store listing names them."""
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
    # copy per input under the input's own name, and the gallery images are five
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


def capture(take_shots, shots_error, arguments, work, scene, count, jungle):
    """
    One capture run, in its own directories so neither run clears the other's.

    `jungle` is None for the ordinary build and a jungle list for the forced one; it
    is passed through to the shared tool, which hands it to `monkeyc -f` whole.
    """
    if not arguments.silent:
        frames = "frame" if count == 1 else "frames"
        print(f"Capturing {count} {scene} {frames} of {arguments.device}...")

    settings = {} if jungle is None else {"jungle": jungle}
    try:
        return take_shots(
            project=PROJECT,
            product=arguments.device,
            output_directory=os.path.join(work, f"shots-{scene}"),
            work_directory=os.path.join(work, f"work-{scene}"),
            count=count,
            platform=arguments.platform,
            timezone=arguments.timezone,
            **settings,
        )
    except shots_error as error:
        sys.exit(f"{scene} capture failed: {error}")


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

    with tempfile.TemporaryDirectory(prefix="matrix-graphics-") as work:
        # Two runs, because they are two builds. Each one compiles the face, starts a
        # container and lets the simulator settle, so this is roughly twice the wait
        # the woken frames alone took.
        woken = capture(
            take_shots,
            shots_error,
            arguments,
            work,
            "woken",
            SHOT_COUNT,
            jungle=None,
        )
        always_on = capture(
            take_shots,
            shots_error,
            arguments,
            work,
            "always-on",
            ALWAYS_ON_COUNT,
            jungle=ALWAYS_ON_JUNGLE,
        )
        shots = woken + always_on

        if not arguments.silent:
            print("Writing resources/graphics:")
        write_capture(woken, arguments.silent)
        write_gallery(shots, arguments.background, arguments.silent)
        write_hero(generator_class, shots, arguments.background, arguments.silent)

    return 0


if __name__ == "__main__":
    sys.exit(main())
