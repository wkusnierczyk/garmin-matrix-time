#!/usr/bin/env python3
"""Regenerate an edition's generated store images from the current build.

Lite's, in resources/graphics/, used to be made by hand: run the simulator, capture
screenshots, resize and composite them, upload the result. #80 is what that cost --
#54 dropped `0-9` from the rain charset and all seven of them went on showing numerals
for months, because a capture is derived from the app but is not generated output, so
nothing reports it stale.

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
  MatrixTimeHero-draft.png      those five scattered across 1440x720
  MatrixTimeHero-draft-small.png  the same composition at 900x450

The hero this writes is a draft, and not what the store serves (#130). The published
pair, MatrixTimeHero.png and MatrixTimeHero-small.png, is composed by hand with an
image model from these same captures: watches larger, overlapping, seen from several
viewpoints under one light, which a 2D composition of face-on renders cannot be. This
target does not write those two files, so a capture run cannot overwrite them. The
draft is what a composed candidate is compared against, and the fallback when there is
no composed hero.

Recomposing the published hero is therefore a manual step, and it is owed whenever
what the face draws changes -- the same debt as every image here, but one no target
can pay.

MatrixTime5.png is a second capture run rather than a fifth frame of the first. The
simulator will not enter always-on headlessly -- Display Mode is a GUI menu and is not
one of the keys it persists -- so that frame comes from a build in which onUpdate takes
the low-power branch unconditionally, selected by layering graphics.jungle over
monkey.jungle. Only the trigger is forced; see source/View.mc.

Premium has a store listing of its own, and so a set of its own (#188), written to
premium/graphics/ beside its store cover and never over Lite's:

  MatrixTimePremium1.png .. 3.png  the three built-in presets, Green, Red and Blue
  MatrixTimePremium4.png           white-to-green rain under a hollow white time
  MatrixTimePremium5.png           the always-on scene
  MatrixTimePremiumHero-draft.png  those five scattered across 1440x720
  MatrixTimePremium-default.png    the defaults, for the README's Features table
  MatrixTimePremium-<setting>.png  the defaults with that one setting changed, the same

Each Premium image is a look rather than a moment, so each is a build of its own,
compiled with its settings as the property defaults, in a copy of the tree. All
thirteen are captured in one container, the always-on ones through graphics.jungle as
Lite's is.
The presets are not restated here: each preset build asks the face to load that
slot, as the phone would, and the face loads what Presets.builtIn holds.

Both editions also keep the full-size watch renders, unflattened, in
.dev/scratchpad/hero/<edition>/captures/. Those are what `make hero` sends to the image
model the published hero is composed by; the 200px gallery images are too small to
read the glyphs from.

The gallery images and the hero are flattened onto white, which is what the files
they replace look like and what the store gallery expects. `--background none`
keeps them transparent instead.

Usage:
  tools/make-graphics.py                   regenerate the eight Lite images it owns
  tools/make-graphics.py --edition premium regenerate the fourteen Premium ones
  tools/make-graphics.py --background none keep the transparency instead of white
  tools/make-graphics.py --timezone ...    choose the clock the captured face shows

Needs Docker running, and garmin-graphics-generator 0.5.1 or newer for Lite, 0.6.0 or
newer for Premium.
"""
import argparse
import os
import shutil
import sys
import tempfile
from importlib.metadata import PackageNotFoundError, version
from itertools import takewhile
from typing import Dict, NamedTuple

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GRAPHICS = os.path.join(PROJECT, "resources", "graphics")

# Where the full-size watch renders are kept for `make hero`, per edition. Gitignored,
# like make preview's output: they are inputs to a manual step, not artwork.
HERO_CAPTURES = os.path.join(
    PROJECT, ".dev", "scratchpad", "hero", "{edition}", "captures"
)

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
# simulator for it. The woken frames rely on that same reset: the real build draws the
# rain only when System.getDisplayMode() reports high power (#191, #212). graphics.jungle is one line layered over monkey.jungle; monkeyc -f
# takes the list and lets the later file override the earlier one. One frame is enough
# -- the scene is the time alone, shifted a step every minute, so a second frame taken
# seconds later would be the same picture.
#
# The edition jungle comes last in both lists, never before graphics.jungle (#135).
# graphics.jungle replaces base.excludeAnnotations, so layered after lite.jungle it
# would drop Lite's (:premium) exclusion and could capture Premium code as Lite. Named
# for the woken run too: monkey.jungle names no manifest, so the shared tool's
# default of monkey.jungle alone no longer builds.
WOKEN_JUNGLE = "monkey.jungle;lite.jungle"
ALWAYS_ON_JUNGLE = "monkey.jungle;graphics.jungle;lite.jungle"
ALWAYS_ON_COUNT = 1

CAPTURE_NAME = "MatrixTimeCapture.png"
GALLERY_NAME = "MatrixTime{index}.png"

# Deliberately not MatrixTimeHero.png. That name belongs to the composed hero the
# store serves, which is not generated output and which this target must not touch
# (#130). Renaming these back would silently overwrite it on the next capture run.
HERO_NAME = "MatrixTimeHero-draft.png"
HERO_SMALL_NAME = "MatrixTimeHero-draft-small.png"

GALLERY_WIDTH = 200
HERO_SIZE = (1440, 720)
HERO_SMALL_SIZE = (900, 450)

# Passed to the hero composition. The images this replaces are scattered at varying
# size and angle rather than laid out in a row, and these reproduce that.
SIZE_VARIATION = 5
ORIENTATION_VARIATION = 20
MAX_OVERLAP = 20

# Premium's set (#188), beside its store cover. No capture and no draft banner: Lite's
# raw capture is a reference nothing in the listing uses, and the README banner is cut
# from the published hero by make hero, not from the draft.
PREMIUM_GRAPHICS = os.path.join(PROJECT, "premium", "graphics")
PREMIUM_GALLERY_NAME = "MatrixTimePremium{index}.png"
PREMIUM_HERO_NAME = "MatrixTimePremiumHero-draft.png"

# The jungles and the resource path of a Premium build. The edition jungle comes last,
# as in every build. The resource directories are the ones whose properties files the
# looks below rewrite: a property file off the build's path would be rewritten and
# ignored, and every image would show the defaults.
PREMIUM_WOKEN_JUNGLE = "monkey.jungle;premium.jungle"
PREMIUM_ALWAYS_ON_JUNGLE = "monkey.jungle;graphics.jungle;premium.jungle"
PREMIUM_RESOURCES = ("resources", "premium/resources-base")


class Look(NamedTuple):
    """One Premium gallery image: what it shows, its scene, and its settings."""

    name: str
    jungle: str
    settings: Dict[str, str]


# The five Premium gallery images, in the order the listing names them, each as the
# property defaults its build is compiled with; every property not named keeps its own.
#
# The presets are not restated. presetLoad is the phone's "load preset" request, and a
# build whose default holds a slot makes the face load that slot as it starts, through
# Presets.applyRequests, before the view first reads its settings. With the simulator's
# storage wiped between builds, a slot holds its built-in look, so these three show
# what Presets.builtIn says, whatever it comes to say.
#
# The fourth is no preset, so its values are stated: rainColor 7, white to green;
# timeStyle 1, hollow; timeSize 5, Extra large; and timeColor 1, white. The size and
# the colour are for the gallery tile: at the default Medium and green, the outline
# was lost among the green trails at 200px, and white at Extra large was the one of
# five variants that read at once. The always-on scene is at the defaults, which is
# how a new install draws it: the time in green, at full brightness.
PREMIUM_LOOKS = (
    Look("preset 1", PREMIUM_WOKEN_JUNGLE, {"presetLoad": "1"}),
    Look("preset 2", PREMIUM_WOKEN_JUNGLE, {"presetLoad": "2"}),
    Look("preset 3", PREMIUM_WOKEN_JUNGLE, {"presetLoad": "3"}),
    Look(
        "white-to-green rain, hollow time",
        PREMIUM_WOKEN_JUNGLE,
        {"rainColor": "7", "timeStyle": "1", "timeSize": "5", "timeColor": "1"},
    ),
    Look("always-on", PREMIUM_ALWAYS_ON_JUNGLE, {}),
)


# The README's Features table illustrates every Premium setting with one image (#190):
# the face at its defaults with that one setting changed, so the image shows what the
# setting does and nothing else. The first is the defaults themselves, beside Lite's
# rain. Two settings borrow a gallery image instead: the time style, since a hollow
# time in the rain's own green is hard to read, which is MatrixTimePremium4.png's
# reason for a white one; and the presets, whose looks are the first three.
PREMIUM_FEATURE_NAME = "MatrixTimePremium-{feature}.png"
PREMIUM_FEATURES = (
    ("default", Look("defaults", PREMIUM_WOKEN_JUNGLE, {})),
    (
        "timeSize",
        Look("time size Extra extra large", PREMIUM_WOKEN_JUNGLE, {"timeSize": "6"}),
    ),
    (
        "trailLength",
        Look("trail length 25%", PREMIUM_WOKEN_JUNGLE, {"trailLength": "25"}),
    ),
    (
        "timeAlign",
        Look("time alignment Right", PREMIUM_WOKEN_JUNGLE, {"timeAlign": "2"}),
    ),
    ("timeColor", Look("time colour Amber", PREMIUM_WOKEN_JUNGLE, {"timeColor": "3"})),
    ("rainColor", Look("rain colour Orange", PREMIUM_WOKEN_JUNGLE, {"rainColor": "4"})),
    (
        "alwaysOnBrightness",
        Look(
            "always-on brightness Dim",
            PREMIUM_ALWAYS_ON_JUNGLE,
            {"alwaysOnBrightness": "2"},
        ),
    ),
    ("date", Look("date On", PREMIUM_WOKEN_JUNGLE, {"date": "1"})),
)


# 0.5.0 brought the shots command; 0.5.1 is what this needs, for two things the fifth
# image depends on. Its hero retries the whole arrangement instead of abandoning an
# image it could not place, which is what makes a five-watch composition reliable
# rather than lucky -- at four, the same request landed two watches on one run and four
# on the next. And its shots accepts a list of jungle files, which is how the always-on
# capture selects the forced build: 0.5.0 checked the whole string as one filename and
# rejected "monkey.jungle;graphics.jungle" before starting the container.
#
# Premium needs 0.6.0, which captures several builds in one container, each with its
# own property defaults laid over a copy of the tree.
#
# The hint installs INSTALL_VERSION rather than the minimum: make icons and make hero
# need 0.7.0, and the README installs that release, with the Pillow the icons were
# drawn with, for every target alike.
GENERATOR = "garmin_graphics_generator"
REQUIRED_VERSIONS = {"lite": "0.5.1", "premium": "0.6.0"}
INSTALL_VERSION = "0.7.0"
RELEASE_URL = (
    "https://github.com/wkusnierczyk/garmin-graphics-generator/releases/tag/v{version}"
)

INSTALL_HINT = """garmin-graphics-generator {version} or newer is needed, and {problem}.

    python3 -m pip install 'garmin-graphics-generator @ git+https://github.com/wkusnierczyk/garmin-graphics-generator@v{install}' 'Pillow==12.1.0'

It carries the simulator capture and the hero composition, which are shared with the
other watch faces rather than kept here. Release notes: {url}"""


def as_numbers(version):
    """A version as a tuple of integers, for comparing one release against another."""
    numbers = []
    for part in version.split("."):
        digits = "".join(takewhile(str.isdigit, part))
        if not digits:
            break
        numbers.append(int(digits))
    return tuple(numbers)


def load_generator(edition):
    """Checks the shared generator is new enough for the edition's images."""
    required = REQUIRED_VERSIONS[edition]

    def fail(problem):
        sys.exit(
            INSTALL_HINT.format(
                version=required,
                problem=problem,
                install=INSTALL_VERSION,
                url=RELEASE_URL.format(version=INSTALL_VERSION),
            )
        )

    try:
        installed = version(GENERATOR)
    except PackageNotFoundError:
        fail("it is not installed")

    if as_numbers(installed) < as_numbers(required):
        fail(f"{installed} is installed")

    try:
        from garmin_graphics_generator.core import (  # noqa: F401
            WatchHeroGenerator,
        )
        from garmin_graphics_generator.capture import CaptureError
        from garmin_graphics_generator.shots import ShotsError, take_shots
    except ImportError as error:
        fail(f"importing it failed: {error}")
    # Both, because cutting the frames raises CaptureError, which is no ShotsError; a
    # failed cut is reported like a failed capture rather than as a traceback.
    return WatchHeroGenerator, take_shots, (ShotsError, CaptureError)


def flatten(image, background):
    """Puts an image on a solid background, or leaves its transparency alone."""
    if background == "none":
        return image
    from PIL import Image

    flattened = Image.new("RGBA", image.size, background)
    flattened.alpha_composite(image.convert("RGBA"))
    return flattened.convert("RGB")


def write_gallery(shots, background, quiet, directory=GRAPHICS, name=GALLERY_NAME):
    """Writes the five 200px renders, in the order the store listing names them."""
    for index, shot in enumerate(shots, start=1):
        write_render(
            shot, os.path.join(directory, name.format(index=index)), background, quiet
        )


def write_render(shot, path, background, quiet):
    """Writes one watch render at the gallery's 200px width."""
    from PIL import Image

    with Image.open(shot.watch_path) as watch:
        height = round(GALLERY_WIDTH * watch.height / watch.width)
        resized = watch.convert("RGBA").resize((GALLERY_WIDTH, height), Image.LANCZOS)
    flatten(resized, background).save(path)
    report(path, quiet)


def keep_hero_captures(shots, edition, quiet):
    """
    Copies the full-size watch renders to where make hero reads them.

    As they came from the capture, transparent around the watch and at the render's
    own size, in gallery order. Earlier ones are removed first, so a capture of
    fewer images cannot leave a stale one behind to be sent to the model.
    """
    directory = HERO_CAPTURES.format(edition=edition)
    if os.path.isdir(directory):
        shutil.rmtree(directory)
    os.makedirs(directory)
    if not quiet:
        print("Keeping the full-size captures for make hero:")
    for index, shot in enumerate(shots, start=1):
        path = os.path.join(directory, f"watch-{index}.png")
        shutil.copyfile(shot.watch_path, path)
        report(path, quiet)


def write_capture(shots, quiet):
    """Writes the raw device framebuffer, with nothing composited over it."""
    from PIL import Image

    path = os.path.join(GRAPHICS, CAPTURE_NAME)
    with Image.open(shots[0].screen_path) as screen:
        screen.save(path)
    report(path, quiet)


def write_hero(
    generator_class,
    shots,
    background,
    quiet,
    directory=GRAPHICS,
    name=HERO_NAME,
    small_name=HERO_SMALL_NAME,
):
    """
    Writes the draft hero, and its banner as the same composition scaled, unless
    `small_name` is None.

    Scaled rather than composed a second time: the placement is random, so a second
    run would put the watches somewhere else, and the banner is meant to be the
    hero, smaller.
    """
    from PIL import Image

    generator = (
        generator_class()
        .set_input_paths([shot.watch_path for shot in shots])
        .set_output_directory(directory)
        .set_hero_filename(name)
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

    hero_path = os.path.join(directory, name)
    with Image.open(hero_path) as hero:
        composed = hero.convert("RGBA")
        flatten(composed, background).save(hero_path)
    report(hero_path, quiet)
    if small_name is None:
        return

    small_path = os.path.join(directory, small_name)
    flatten(composed.resize(HERO_SMALL_SIZE, Image.LANCZOS), background).save(
        small_path
    )
    report(small_path, quiet)


def report(path, quiet):
    """Says what was written, as a path relative to the project."""
    if not quiet:
        print(f"  {os.path.relpath(path, PROJECT)}")


def capture(take_shots, shots_error, arguments, work, scene, count, jungle):
    """
    One capture run, in its own directories so neither run clears the other's.

    `jungle` is a jungle list, passed through to the shared tool, which hands it to
    `monkeyc -f` whole.
    """
    if not arguments.silent:
        frames = "frame" if count == 1 else "frames"
        print(f"Capturing {count} {scene} {frames} of {arguments.device}...")

    try:
        return take_shots(
            project=PROJECT,
            product=arguments.device,
            output_directory=os.path.join(work, f"shots-{scene}"),
            work_directory=os.path.join(work, f"work-{scene}"),
            count=count,
            platform=arguments.platform,
            timezone=arguments.timezone,
            jungle=jungle,
        )
    except shots_error as error:
        sys.exit(f"{scene} capture failed: {error}")


def capture_looks(looks, shots_error, arguments, work):
    """
    One capture run of Premium's looks, a build each, in one container.

    Each build's settings are laid over a copy of the tree by the shared tool, so the
    project is never written to. Returns one frame per look, in the order given.
    """
    from garmin_graphics_generator import variants
    from garmin_graphics_generator.shots import Build, take_builds

    try:
        resources = variants.read_resources(PROJECT, PREMIUM_RESOURCES)
    except variants.VariantsError as error:
        sys.exit(f"cannot read Premium's settings: {error}")

    # Checked against settings.xml before anything is built: a value no setting lists
    # would compile, be clamped to the default by the face, and be captured as the
    # wrong look without a word.
    for look in looks:
        for key, value in look.settings.items():
            setting = resources.settings.get(key)
            if setting is None:
                sys.exit(f"{look.name}: Premium has no setting {key}")
            if value not in (listed for listed, _ in setting.values):
                sys.exit(f"{look.name}: {key} lists no value {value}")

    # Every overlay carries every properties file any look touches, so laying them
    # over one copy in turn puts back what the previous build changed.
    try:
        overlays = variants.overlay_files(
            PROJECT, resources, [look.settings for look in looks]
        )
    except variants.VariantsError as error:
        sys.exit(f"cannot set Premium's looks: {error}")
    builds = [
        Build(f"{index:02d}", look.jungle, files or None)
        for index, (look, files) in enumerate(zip(looks, overlays), start=1)
    ]

    if not arguments.silent:
        print(f"Capturing {len(builds)} Premium looks of {arguments.device}:")
        for look in looks:
            print(f"  {look.name}")

    try:
        captured = take_builds(
            project=PROJECT,
            product=arguments.device,
            output_directory=os.path.join(work, "shots"),
            work_directory=os.path.join(work, "work"),
            builds=builds,
            count=1,
            platform=arguments.platform,
            timezone=arguments.timezone,
        )
    except shots_error as error:
        sys.exit(f"Premium capture failed: {error}")
    return [frames[0] for frames in captured]


def make_lite(arguments, work):
    """Captures Lite and writes resources/graphics, but for the published hero and banner."""
    generator_class, take_shots, shots_error = load_generator("lite")

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
        jungle=WOKEN_JUNGLE,
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
    keep_hero_captures(shots, "lite", arguments.silent)


def make_premium(arguments, work):
    """Captures Premium and writes premium/graphics, but for the published hero and cover."""
    generator_class, _, shots_error = load_generator("premium")
    # The gallery and the README's feature images in one run, in one container.
    features = [look for _, look in PREMIUM_FEATURES]
    frames = capture_looks(list(PREMIUM_LOOKS) + features, shots_error, arguments, work)
    shots = frames[: len(PREMIUM_LOOKS)]

    if not arguments.silent:
        print("Writing premium/graphics:")
    write_gallery(
        shots,
        arguments.background,
        arguments.silent,
        directory=PREMIUM_GRAPHICS,
        name=PREMIUM_GALLERY_NAME,
    )
    write_hero(
        generator_class,
        shots,
        arguments.background,
        arguments.silent,
        directory=PREMIUM_GRAPHICS,
        name=PREMIUM_HERO_NAME,
        small_name=None,
    )
    for (feature, _), frame in zip(PREMIUM_FEATURES, frames[len(PREMIUM_LOOKS) :]):
        write_render(
            frame,
            os.path.join(
                PREMIUM_GRAPHICS, PREMIUM_FEATURE_NAME.format(feature=feature)
            ),
            arguments.background,
            arguments.silent,
        )
    keep_hero_captures(shots, "premium", arguments.silent)


def main():
    parser = argparse.ArgumentParser(
        description="Regenerate an edition's generated store images from the "
        "simulator: Lite's in resources/graphics, Premium's in premium/graphics. The "
        "composed heroes, their banners and Premium's cover are left alone."
    )
    parser.add_argument(
        "-e",
        "--edition",
        choices=("lite", "premium"),
        default="lite",
        help="Which edition's images to capture (default: lite)",
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

    make = make_premium if arguments.edition == "premium" else make_lite
    with tempfile.TemporaryDirectory(prefix="matrix-graphics-") as work:
        make(arguments, work)

    return 0


if __name__ == "__main__":
    sys.exit(main())
