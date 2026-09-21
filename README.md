# Garmin Matrix Time

[![build](https://github.com/wkusnierczyk/garmin-matrix-time/actions/workflows/build.yml/badge.svg)](https://github.com/wkusnierczyk/garmin-matrix-time/actions/workflows/build.yml)

A minimalist, elegant, nerdy, typography-focused Garmin Connect IQ watch face that displays the current time with the Digital Rain design in the background.

![Matrix Time](resources/graphics/MatrixTimeHero-small.png)

Available from [Garmin Connect IQ Developer portal](https://apps.garmin.com/apps/71aed235-c2f2-4b33-b29f-836e83497853) or through the Connect IQ mobile app.

> **Note**  
> Matrix Time is part of a [collection of unconventional Garmin watch faces](https://github.com/wkusnierczyk/garmin-watch-faces). It has been developed for fun, as a proof of concept, and as a learning experience.
> It is shared _as is_ as an open source project, with no commitment to long term maintenance and further feature development.
>
> Please use [issues](https://github.com/wkusnierczyk/garmin-matrix-time/issues) to provide bug reports or feature requests.  
> Please use [discussions](https://github.com/wkusnierczyk/garmin-matrix-time/discussions) for any other comments.
>
> All feedback is wholeheartedly welcome.

## Contents

* [Matrix time](#matrix-time)
* [Features](#features)
* [Fonts](#fonts)
* [Launcher icon](#launcher-icon)
* [Build, test, deploy](#build-test-deploy)
* [Upstream bug reports](#upstream-bug-reports)

## Matrix time

Matrix Time displays the current time as digits with [Digital Rain](https://en.wikipedia.org/wiki/Digital_rain) in the background.

**Stepped, not smooth**  
Every frame advances each column of rain by exactly one row, and a watch face is given at most one frame a second: `onUpdate` is called about once a second while the watch is awake, and only once a minute once it has dropped into low power. The rain therefore steps rather than flows. It also steps only while the watch is awake, because the always-on screen leaves the rain out altogether; see **Always-on display** below. The callback that would add frames in low power, `onPartialUpdate`, is a memory-in-pixel mechanism and is deliberately not implemented here: on an AMOLED product it is the burn-in protector, not the frame rate, that decides what the always-on screen may draw.

**Letters only**  
The rain is drawn from the letters `a`-`z` alone. Matrix Code NFI maps letters to katakana-style glyphs but draws digits as recognisable digits, so a charset including `0`-`9` scattered numerals through the rain that competed with the clock for attention. The time is the only number on the screen.

**A different start each time**  
The initial pattern of glyphs and the starting position of each falling column are random, and seeded from both the current time and how long the watch has been switched on, so the rain begins differently on every launch. Two watches side by side do not fall into step, even if they are started at the same moment — they will have been awake for different lengths of time.

**Rain grid**  
The rain glyphs sit on a fixed grid rather than being set as text. Matrix Code NFI is a proportional typeface — its letters vary by around half again in width — so the grid cell is as wide as the widest glyph in the charset, which keeps neighbouring glyphs from touching whatever falls where. That makes the rain slightly sparser than a grid sized to an average letter, and it is the reason the column count is what it is at each resolution.

**Round screens**  
The rain is laid out on a rectangular grid, so on a round watch the corners of that grid fall off the glass and are never drawn. A cell is kept when the cell itself overlaps the visible disc, not merely when its centre does, so the rain reaches the rim at every round resolution instead of stopping a cell short of it.

**Always-on display**  
Every supported device has an AMOLED screen, and Garmin's burn-in protector blanks the display in always-on mode if more than 10% of the pixels are lit, or if any pixel stays lit for longer than three minutes. A full-screen digital rain fails both tests, so the rain is not drawn while the watch is in low-power mode: the always-on screen shows the time alone, drawn at twice the size used on the woken screen, dimmed to two thirds of its normal brightness and shifted to a different corner of a small square every minute. The shift is wide enough to carry each stroke clear of where it stood a minute earlier, so no pixel stays lit long enough to trip the protector. Raising the wrist wakes the watch face and brings the rain back.

## Features

The Matrix Time watch face supports the following features:

|Screenshot|Description|
|-|:-|
|![](resources/graphics/MatrixTime4.png)|**Digital rain**<br/> An implementation of the digital rain design is used as a bacground for the current time.

In the initial version, there are no customisation settings. The watch face does ship a `resources/properties/properties.xml`, but the single property it declares is a schema marker with no entry in any settings screen, so nothing shows up in Connect IQ or on the watch. It is there because a build with no declared property has no property table at all, and reading a property from a table that does not exist takes the app down with an error no `catch` clause sees (#91, #93). It costs 96 bytes in the `.prg`.

## Fonts

The Matrix Time watch face uses custom fonts:

* [Norfok Matrix Code NFI](https://www.norfok.com) for the digital raing glyphs.
* [SUSEMono Regular](https://fonts.google.com/specimen/SUSE+Mono) for the current time, at two sizes: the smaller one on the woken screen, and one twice as large on the always-on screen, where the time is all that is drawn and legibility matters most.

> The development of Garmin watch faces motivated the implementation of two useful tools:
> * A TTF to FNT+PNG converter ([`ttf2bmp`](https://github.com/wkusnierczyk/ttf2bmp)).  
> Garmin watches use non-scalable fixed-size bitmap fonts, and cannot handle variable size True Type fonts directly.
> * An font scaler automation tool ([`garmin-font-scaler`](https://github.com/wkusnierczyk/garmin-font-scaler)).  
> Garmin watches come in a variety of shapes and resolutions, and bitmap fonts need to be scaled for each device proportionally to its resolution.

The font development proceeded as follows:

* The fonts were downloaded from [Google Fonts](https://fonts.google.com/) as True Type  (`.ttf`) fonts.
* The fonts were converted to bitmaps as `.fnt` and `.png` pairs using the open source command-line [`ttf2bmp`](https://github.com/wkusnierczyk/ttf2bmp) converter.
* The font sizes were established on a Garmin epix™ Pro (Gen 2) 47mm watch, 416x416 pixel screen resolution.
This is the reference resolution declared in `resources/fonts/resolutions.json`, and the device the watch face is
verified on; sizes for all other resolutions are derived from it proportionally by the font scaler.
* The fonts were then scaled proportionally to match other screen sizes available on Garmin watches using the [`garmin-font-scaler`](https://github.com/wkusnierczyk/garmin-font-scaler) tool.


The table below lists all font sizes provided for the supported screen resolutions.

| Resolution |   Shape   |  Element   |       Font       | Size |
| ---------: | :-------- | :--------- | :--------------- | ---: |
|  320 x 360 | rectangle | Matrix     | MatrixCodeNFI    |   21 |
|  320 x 360 | rectangle | Time       | SUSEMono regular |   21 |
|  320 x 360 | rectangle | Time large | SUSEMono regular |   42 |
|  360 x 360 | round     | Matrix     | MatrixCodeNFI    |   23 |
|  360 x 360 | round     | Time       | SUSEMono regular |   23 |
|  360 x 360 | round     | Time large | SUSEMono regular |   47 |
|  390 x 390 | round     | Matrix     | MatrixCodeNFI    |   25 |
|  390 x 390 | round     | Time       | SUSEMono regular |   25 |
|  390 x 390 | round     | Time large | SUSEMono regular |   51 |
|  416 x 416 | round     | Matrix     | MatrixCodeNFI    |   27 |
|  416 x 416 | round     | Time       | SUSEMono regular |   27 |
|  416 x 416 | round     | Time large | SUSEMono regular |   54 |
|  454 x 454 | round     | Matrix     | MatrixCodeNFI    |   29 |
|  454 x 454 | round     | Time       | SUSEMono regular |   29 |
|  454 x 454 | round     | Time large | SUSEMono regular |   59 |
|  466 x 466 | round     | Matrix     | MatrixCodeNFI    |   30 |
|  466 x 466 | round     | Time       | SUSEMono regular |   30 |
|  466 x 466 | round     | Time large | SUSEMono regular |   60 |
|  448 x 486 | rectangle | Matrix     | MatrixCodeNFI    |   29 |
|  448 x 486 | rectangle | Time       | SUSEMono regular |   29 |
|  448 x 486 | rectangle | Time large | SUSEMono regular |   58 |

## Launcher icon

The launcher icon is the digital rain held still: glyphs from the same typeface, in the same green
and from the same letters-only charset, that the watch face draws with.

Garmin sets the launcher icon size per device. The 51 supported products ask for eight different
sizes, from 38 x 38 on the Instinct Crossover AMOLED to 70 x 70 on the Venu 3. The size does not
follow the screen, and so cannot be served by the `deviceFamily` qualifier the fonts use: the
`round-390x390` family alone spans 38 x 38, 54 x 54, 56 x 56, 60 x 60 and 70 x 70. Every device is
therefore mapped to its own icon individually, by a per-product `resourcePath` entry in
`monkey.jungle`.

Each size is drawn at its own resolution rather than scaled down from a single master. Digital rain
is thin strokes at a high spatial frequency, which is what naive downscaling destroys first: a
100 x 100 still resampled to 38 x 38 stops being characters and becomes noise. The glyph cell is a
constant 10 pixels at every size, so a larger icon shows more rain rather than the same rain drawn
larger -- the grid runs from 4 x 3 glyphs at 38 x 38 to 7 x 6 at 70 x 70.

Each supported product is mapped to the icon its device asks for:

| Product                 |    Icon |
| :---------------------- | ------: |
| approachs7047mm         | 70 x 70 |
| d2airx10                | 70 x 70 |
| venu2                   | 70 x 70 |
| venu2plus               | 70 x 70 |
| venu3                   | 70 x 70 |
| venu3s                  | 70 x 70 |
| d2mach2                 | 65 x 65 |
| d2mach2pro              | 65 x 65 |
| fenix847mm              | 65 x 65 |
| fenix8pro47mm           | 65 x 65 |
| fenix947mm              | 65 x 65 |
| fenix9pro47mm           | 65 x 65 |
| fenix9pro51mm           | 65 x 65 |
| fr57047mm               | 65 x 65 |
| fr965                   | 65 x 65 |
| fr970                   | 65 x 65 |
| venu445mm               | 65 x 65 |
| venux1                  | 65 x 65 |
| venu2s                  | 61 x 61 |
| approachs7042mm         | 60 x 60 |
| d2mach1                 | 60 x 60 |
| descentg2               | 60 x 60 |
| descentmk343mm          | 60 x 60 |
| descentmk351mm          | 60 x 60 |
| epix2                   | 60 x 60 |
| epix2pro42mm            | 60 x 60 |
| epix2pro47mm            | 60 x 60 |
| epix2pro51mm            | 60 x 60 |
| fenix843mm              | 60 x 60 |
| fenix943mm              | 60 x 60 |
| fenix9pro43mm           | 60 x 60 |
| fenixe                  | 60 x 60 |
| fr265                   | 60 x 60 |
| fr265s                  | 60 x 60 |
| instinct3amoled45mm     | 60 x 60 |
| instinct3amoled50mm     | 60 x 60 |
| marq2                   | 60 x 60 |
| marq2aviator            | 60 x 60 |
| approachs50             | 56 x 56 |
| vivoactive5             | 56 x 56 |
| fr165                   | 54 x 54 |
| fr165m                  | 54 x 54 |
| fr170                   | 54 x 54 |
| fr170m                  | 54 x 54 |
| fr57042mm               | 54 x 54 |
| fr70                    | 54 x 54 |
| venu441mm               | 54 x 54 |
| vivoactive6             | 54 x 54 |
| venusq2                 | 40 x 40 |
| venusq2m                | 40 x 40 |
| instinctcrossoveramoled | 38 x 38 |

The icons, the mapping block in `monkey.jungle` and the table above are **generated output** of
`tools/make-launcher-icons.py`, which reads the sizes from the SDK's own device definitions.
Regenerate them with `make icons`, which needs Python 3 with [Pillow](https://python-pillow.org)
installed; do not hand-edit them. `make check-icons` needs nothing but Python 3, and verifies that
every supported product has a mapping, that every icon is the size its directory promises, that
the table above agrees with the mapping, and -- when the SDK is installed -- that every mapping
matches the size the SDK declares for that device.

`resources/drawables/launcher_icon.png` is a 70 x 70 copy of the icon, the largest size any supported
device asks for. It is a fallback only: it applies to a product added to `manifest.xml` before
`make icons` has been rerun.

## Build, test, deploy

To modify and build the sources, you need to have installed:

* [Visual Studio Code](https://code.visualstudio.com/) with [Monkey C extension](https://developer.garmin.com/connect-iq/reference-guides/visual-studio-code-extension/).
* [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/).

The [Monkey C Visual Studio Code Extension](https://developer.garmin.com/connect-iq/reference-guides/visual-studio-code-extension/)
reference guide covers the extension in full; what follows is the part of it this project actually uses.

### A developer key

Every build is signed, so nothing compiles until a developer key exists. Generate one from the command
palette with `Monkey C: Generate a Developer Key`, or by hand:

```bash
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key -nocrypt
```

`monkeyc` wants the DER file, `developer_key`. Point the extension at it with the `monkeyC.developerKeyPath`
setting, and the `Makefile` at it with `DEV_KEY`, which defaults to `../garmin-keys/developer_key`, that is,
outside the working tree. Keep it there: the key is the identity every app you publish is signed with, and
losing it or leaking it cannot be undone by a new one. `.gitignore` guards `developer_key*` as a second line
of defence, not as a licence to keep the key in the repository.

### From Visual Studio Code

`Cmd+Shift+P` on macOS, `Ctrl+Shift+P` on Windows and Linux, opens the command palette. The commands
that matter here:

| Command | What it does |
| :------ | :----------- |
| `Monkey C: Build Current Project` | compiles for one device and writes the `.prg` into `bin/` |
| `Monkey C: Build for Device` | the same build, written to a folder you choose, for sideloading |
| `Monkey C: Run Tests` | runs the unit test suite in the simulator, reporting into the Test Explorer |
| `Monkey C: Export Project` | builds the signed `.iq` bundle to upload to the store |
| `Monkey C: Edit Products` | edits the supported device list in `manifest.xml` |
| `Monkey C: Verify Installation` | checks that a current SDK is selected, that its version is supported, and that device definitions have been downloaded |

`F5` runs the watch face in the simulator under the debugger, `Ctrl+F5` without it. Both read a `monkeyc`
launch configuration from `.vscode/launch.json`; the extension offers to write one the first time.

Each build asks which device to build for, choosing from the products listed in `manifest.xml`, with the
device you built last offered at the top. A launch configuration whose `device` is `${command:GetTargetDevice}`
asks that same question on every run; replacing it with a product id, `"device": "epix2pro47mm"`, pins it.
`.vscode/` is not committed, so the launch configuration and the key path are per clone, not per project.

Every one of these has a `Makefile` equivalent, `Monkey C: Export Project` included: `make export`
builds the same store bundle, and is described below.

### From the command line

The included `Makefile` covers everything except the export.

```bash
# build binaries from sources
make build

# start the simulator if it is not already running
make sim

# run the unit tests
make test

# run the simulation
make run

# build the signed .iq store bundle, for every supported device
make export

# build for the connected watch and install the binary on it
make sideload

# ... and wait up to five minutes for a watch to be plugged in first
make sideload WAIT=300

# regenerate the launcher icons and their jungle mapping
make icons

# check that the font and launcher icon configurations are consistent
make check-fonts
make check-icons

# clean up the project directory
make clean
```

Every target that compiles builds for `DEVICE`, which defaults to `epix2pro47mm`, the reference device;
override it with `make build DEVICE=venu3` for any other product listed in `manifest.xml`. `make build`
needs no arguments at all.

`make export` is the exception, and the only compiling target that ignores `DEVICE`: it packages
every product `manifest.xml` names into one signed `.iq` under `export/`, which is the file the
Connect IQ store takes. It also strips debug information, which `make build` deliberately keeps so
that the simulator and the profiler have something to say. `monkeyc` counts part numbers rather than
products as it works, so it reports more devices than the manifest lists -- several products ship
under more than one part, and `venu2` under four. The whole set builds in well under a minute, and
this is the only build that exercises the packaging step, so it is worth running before a release
even when nothing about the devices has changed. Uploading the bundle is still manual, through the
store's web form.

`make check-fonts` and `make check-icons` are consistency checks rather than builds, and need no SDK.
`check-fonts` verifies that `fonts.xml`, `resolutions.json` and `charsets.json` agree with one another
and with the bitmaps on disk, that the rain charset is the same string in `source/Matrix.mc`,
`resources/fonts/charsets.json` and `tools/make-launcher-icons.py`, that the base fonts are byte-identical
to the generated reference-resolution ones, and that the size tables in this file and in `fonts.md` are
what the scaler produced. `check-icons` does the same for the launcher icons and their per-product mapping
in `monkey.jungle`; see [Launcher icon](#launcher-icon).

`make run` and `make test` start the simulator themselves when it is not already up, wait for it to
accept connections, and then load the binary into it. Neither hangs waiting for the simulator: both
give up with a message after 60 seconds. The simulator port is assumed to be 1234; override it with
`make run SIM_PORT=<port>` if yours differs.

`make run` does not return once the binary is loaded. `monkeydo` stays attached for the life of the
app session to relay the app's console output to your terminal, so the command sits in the
foreground while the watch face runs; press Ctrl-C when you are done. `make test` also uses
`monkeydo`, but captures its output and does return.

### Unit tests

`make test` compiles a unit-test binary, loads it into the simulator and reports the result. The suite
lives in `source/tests/` and runs on Garmin's Run No Evil framework, which only exists inside the
simulator -- there is no way to run these on a watch, or without the SDK.

The tests cover the arithmetic behind the scene rather than the pixels: the trail's colour ramp, the
grid's size and origin, the round-display cull, the always-on jitter and the clock string all live in
`source/utils/RainMath.mc` as pure functions, and `RainMathTest` checks them against expected values
and against the properties they are supposed to hold. `DigitalRainTest` covers what cannot be reduced
to numbers -- the head and shade indices inside the drawing loop -- by drawing enough frames into a
scratch bitmap for every index the ring can produce.

`PropertyUtilsTest` covers `source/utils/PropertyUtils.mc`, whose one function nothing calls yet. What
it really checks is the resource: `resources/properties/properties.xml` declares one property, and that
declaration is what lets `Properties.getValue` fall back to the default on an unknown key instead of
taking the app down with an error no `catch` clause sees (#91, #93). Remove the resource, or empty it
out, and both tests report an error rather than a failure.

Run No Evil strips every `(:test)` function from ordinary builds, so none of this reaches a watch. The
three test classes carry the annotation themselves, which drops their bodies too and leaves 240 bytes
of class shell in the `.prg` -- 0.22% of it, and nothing at all in the memory budget, since none of the
three is ever instantiated.

Note that `monkeydo` exits non-zero whether the suite passes or fails, so `make test` reads the summary
line rather than the exit status. A run that cannot reach the simulator prints no summary and is
reported as a failure, which is the intended behaviour.

### Sideloading to the watch

`make sideload` builds the binary and copies it into `GARMIN/Apps` on a watch connected by USB, which
is the whole of what installing a development build takes: the watch face appears in the watch face
list on the device, with no store submission and no phone involved.

The transfer goes over MTP rather than mass storage. macOS does not mount MTP devices as volumes --
that is what OpenMTP exists to work around -- and the reference device presents nothing macOS will
mount: with the watch attached, nothing appears under `/Volumes`. The target therefore needs a
command-line MTP client, which is the one dependency it adds:

```bash
brew install libmtp
```

The device is read off the watch rather than assumed. `tools/sideload.sh` pulls `GarminDevice.xml` off
the watch, takes the part number out of it, matches that against the SDK's own device definitions, and
builds for whatever comes back. `make sideload` therefore needs no `DEVICE`, and a `DEVICE` passed
anyway is checked against the watch and refused when the two disagree: a `.prg` built for another
product installs without complaint and fails only once the watch tries to run it, which is a slow way
to find out.

What landed is verified rather than assumed. The size is read back off the watch and compared with the
local file, and a short copy is deleted instead of being left to fail on the wrist. None of this can
lean on exit statuses -- `mtp-sendfile` exits 0 whether it transferred the file or skipped it
entirely -- so the script reads the tools' output instead, and the comments in it say where each of
those quirks was measured.

`make sideload` expects the watch to be plugged in already and stops on the first look if it is not,
which is what you want when it is sitting on the desk on its cable. When you would rather start the
command and then go and find the watch, ask it to wait:

```bash
make sideload WAIT=1        # look for a watch for up to five minutes
make sideload WAIT=300      # the same thing, said in seconds
make sideload WAIT=60       # give up after a minute
```

`WAIT=1` means "yes, wait" rather than "wait one second", since a one-second wait is no different
from not waiting at all. The wait is always bounded -- there is no spelling of it that polls for
ever -- and each look, plus the time spent so far, is reported, so a run left in a terminal says what
it is doing. Once a watch answers, the run carries straight on into the detection and the transfer.

The looking is deliberately unhurried, once a minute, because each probe opens a USB session; override
that with `make sideload WAIT=300 EVERY=10` if you want it checked more often. The probe itself
is `mtp-detect`, which answers in about 0.2 s, rather than the four-second file listing the detection
proper uses.

For the manual route, or for sideloading from another platform, see
[developer.garmin.com/connect-iq/connect-iq-basics/your-first-app](https://developer.garmin.com/connect-iq/connect-iq-basics/your-first-app/).

### Continuous integration

Every push to `main` and every pull request runs
[`.github/workflows/build.yml`](.github/workflows/build.yml), which does two things:

| Job | What it proves |
| :-- | :------------- |
| `consistency checks` | `make check-fonts` and `make check-icons` pass. Pure Python, no SDK, seconds. |
| `build` | the face compiles, for one product per `deviceFamily`. |

Building one product per family rather than all fifty-one is the cheapest set that still compiles
every resolution and shape the face ships: resource qualifiers resolve per family, so within a family
the compiler sees the same sources, the same bitmaps and the same layout. The set is derived at run
time by `tools/ci-devices.py`, from `manifest.xml` and the SDK's device definitions, so a newly
supported product is covered the moment it is added and there is no list in the workflow to forget.
A product the manifest names but the SDK has no definition for fails the job rather than being
skipped -- that is the state in which the store bundle fails to build, and CI is the right place to
hear about it first.

The build job runs in [`ghcr.io/matco/connectiq-tester`](https://github.com/matco/connectiq-tester),
which carries the SDK, the device definitions and the simulator. The container is not a convenience:
the SDK itself is a public download, but the device definitions `monkeyc` needs are fetched by the
SDK manager from Garmin behind an account sign-in, one product at a time, and are not in the SDK
archive. There is no headless fetch, so they have to arrive in the image. The image is pinned by
digest rather than by tag -- a tag is mutable, and a retag upstream would swap both the build
environment and the code CI runs with no diff here to show it -- so an SDK bump is a deliberate,
visible change with a green run behind it. The `Makefile`, by contrast, deliberately follows whatever
SDK the SDK manager has selected.

No developer key is involved. CI generates a throwaway one per run and discards it: a signed build
proves nothing an unsigned-in-practice one does not, and the real key -- the identity every published
app is signed with -- does not belong in a public repository's secrets. That changes if and when
release automation is added, which is the point at which a real key first earns its place.

Both jobs check out with Git LFS fetched. Several binaries here are LFS objects -- the launcher icon
fallback and both source typefaces among them -- and a checkout without it leaves a pointer file where
the `.png` should be: `check-icons` then fails on the fallback's dimensions, and `monkeyc` compiles the
pointer as a drawable without a word. The first run of this workflow found exactly that.

Unit tests do not run in CI yet. They need the simulator, which the image can run under `xvfb`; that
is the next stage rather than a limitation of the approach.

## Upstream bug reports

Two defects found while building this face turned out to be in the tools rather than in it, and were
reported where they belong. Both are worth knowing about if you are working on a Connect IQ project of
your own, because in each case the symptom points somewhere other than the cause.

### Connect IQ: `Properties.getValue` takes the app down when no property is declared

[forums.garmin.com bug report](https://forums.garmin.com/developer/connect-iq/i/bug-reports/properties-getvalue-crashes-the-app-uncatchably-instead-of-throwing-invalidkeyexception-when-no-property-is-declared)
· [#91](https://github.com/wkusnierczyk/garmin-matrix-time/issues/91),
[#93](https://github.com/wkusnierczyk/garmin-matrix-time/issues/93)

`Properties.getValue` is documented to raise `InvalidKeyException` for a key that is not declared. With
no property table compiled into the app at all, it does something else: it fails a level below the
language, with a system error that no `catch` clause sees, and the app goes down with it. A
`try`/`catch` written against the documented behaviour is therefore not the guard it looks like, and
neither is a `has` check.

An empty `<properties>` element is not a fix. It is valid by Garmin's own `resources.xsd` and it
crashes identically. What works is declaring at least one property, which is why
`resources/properties/properties.xml` exists here and why `PropertyUtilsTest` guards it.

Measured on SDK 9.2.0, `epix2pro47mm`.

### libmtp: one Garmin USB id listed twice, under a misspelled name

[libmtp#434](https://github.com/libmtp/libmtp/issues/434) ·
[libmtp#435](https://github.com/libmtp/libmtp/pull/435)

Found while building `make sideload`. `libmtp`'s device table carried two entries for Garmin product
id `0x4f43` -- the only duplicated Garmin id in it -- so only the first was ever reached, and its name
is a typo: `Euduro 2` for `Enduro 2`. The second entry named it `Fenix 7`, which is a different watch
again.

`0x4f43` is in fact the fenix 7X family: the fenix 7X, tactix 7, quatix 7X Solar and Enduro 2 share
one hardware id, which Garmin's own SDK confirms by mapping them all to the device definition
`fenix7x`. The patch collapses the two entries into one that names the family.

This is why `tools/sideload.sh` identifies a watch by the part number in `GarminDevice.xml` rather than
by the name `libmtp` reports. The part number comes from the device; the name comes from a table that
can be wrong.
