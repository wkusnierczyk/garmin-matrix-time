# Garmin Matrix Time

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

## Matrix time

Matrix Time displays the current time as digits with [Digital Rain](https://en.wikipedia.org/wiki/Digital_rain) in the background.

**Note**  
Due to power constraints on watch faces, the digital rain does not appear to fall smoothly, as watch faces are refreshed once per second.

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

In the initial version, there are no customisation settings.

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

| Resolution |    Shape     |  Element   |       Font       | Size |
| ---------: | :----------- | :--------- | :--------------- | ---: |
|  148 x 205 | rectangle    | Matrix     | MatrixCodeNFI    |   10 |
|  148 x 205 | rectangle    | Time       | SUSEMono regular |   10 |
|  148 x 205 | rectangle    | Time large | SUSEMono regular |   19 |
|  176 x 176 | semi-octagon | Matrix     | MatrixCodeNFI    |   11 |
|  176 x 176 | semi-octagon | Time       | SUSEMono regular |   11 |
|  176 x 176 | semi-octagon | Time large | SUSEMono regular |   23 |
|  215 x 180 | semi-round   | Matrix     | MatrixCodeNFI    |   12 |
|  215 x 180 | semi-round   | Time       | SUSEMono regular |   12 |
|  215 x 180 | semi-round   | Time large | SUSEMono regular |   23 |
|  218 x 218 | round        | Matrix     | MatrixCodeNFI    |   14 |
|  218 x 218 | round        | Time       | SUSEMono regular |   14 |
|  218 x 218 | round        | Time large | SUSEMono regular |   28 |
|  240 x 240 | round        | Matrix     | MatrixCodeNFI    |   16 |
|  240 x 240 | rectangle    | Matrix     | MatrixCodeNFI    |   16 |
|  240 x 240 | round        | Time       | SUSEMono regular |   16 |
|  240 x 240 | rectangle    | Time       | SUSEMono regular |   16 |
|  240 x 240 | round        | Time large | SUSEMono regular |   31 |
|  240 x 240 | rectangle    | Time large | SUSEMono regular |   31 |
|  260 x 260 | round        | Matrix     | MatrixCodeNFI    |   17 |
|  260 x 260 | round        | Time       | SUSEMono regular |   17 |
|  260 x 260 | round        | Time large | SUSEMono regular |   34 |
|  280 x 280 | round        | Matrix     | MatrixCodeNFI    |   18 |
|  280 x 280 | round        | Time       | SUSEMono regular |   18 |
|  280 x 280 | round        | Time large | SUSEMono regular |   36 |
|  320 x 360 | rectangle    | Matrix     | MatrixCodeNFI    |   21 |
|  320 x 360 | rectangle    | Time       | SUSEMono regular |   21 |
|  320 x 360 | rectangle    | Time large | SUSEMono regular |   42 |
|  360 x 360 | round        | Matrix     | MatrixCodeNFI    |   23 |
|  360 x 360 | round        | Time       | SUSEMono regular |   23 |
|  360 x 360 | round        | Time large | SUSEMono regular |   47 |
|  390 x 390 | round        | Matrix     | MatrixCodeNFI    |   25 |
|  390 x 390 | round        | Time       | SUSEMono regular |   25 |
|  390 x 390 | round        | Time large | SUSEMono regular |   51 |
|  416 x 416 | round        | Matrix     | MatrixCodeNFI    |   27 |
|  416 x 416 | round        | Time       | SUSEMono regular |   27 |
|  416 x 416 | round        | Time large | SUSEMono regular |   54 |
|  454 x 454 | round        | Matrix     | MatrixCodeNFI    |   29 |
|  454 x 454 | round        | Time       | SUSEMono regular |   29 |
|  454 x 454 | round        | Time large | SUSEMono regular |   59 |

## Launcher icon

The launcher icon is the digital rain held still: glyphs from the same typeface, in the same green
and from the same letters-only charset, that the watch face draws with.

Garmin sets the launcher icon size per device. The 34 supported products ask for eight different
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
| venu2                   | 70 x 70 |
| venu2plus               | 70 x 70 |
| venu3                   | 70 x 70 |
| venu3s                  | 70 x 70 |
| fenix847mm              | 65 x 65 |
| fenix8pro47mm           | 65 x 65 |
| fr57047mm               | 65 x 65 |
| fr965                   | 65 x 65 |
| fr970                   | 65 x 65 |
| venu445mm               | 65 x 65 |
| venu2s                  | 61 x 61 |
| descentmk343mm          | 60 x 60 |
| descentmk351mm          | 60 x 60 |
| epix2                   | 60 x 60 |
| epix2pro42mm            | 60 x 60 |
| epix2pro47mm            | 60 x 60 |
| epix2pro51mm            | 60 x 60 |
| fenix843mm              | 60 x 60 |
| fenixe                  | 60 x 60 |
| fr265                   | 60 x 60 |
| fr265s                  | 60 x 60 |
| instinct3amoled45mm     | 60 x 60 |
| instinct3amoled50mm     | 60 x 60 |
| marq2                   | 60 x 60 |
| marq2aviator            | 60 x 60 |
| vivoactive5             | 56 x 56 |
| fr165                   | 54 x 54 |
| fr165m                  | 54 x 54 |
| fr57042mm               | 54 x 54 |
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

Consult [Monkey C Visual Studio Code Extension](https://developer.garmin.com/connect-iq/reference-guides/visual-studio-code-extension/) for how to execute commands such as `build` and `test` to the Monkey C runtime.

You can use the included `Makefile` to conveniently trigger some of the actions from the command line.

```bash
# build binaries from sources
make build

# start the simulator if it is not already running
make sim

# run unit tests -- no tests are defined yet, so this currently fails
make test

# run the simulation
make run

# regenerate the launcher icons and their jungle mapping
make icons

# check that the font and launcher icon configurations are consistent
make check-fonts
make check-icons

# clean up the project directory
make clean
```

`make run` and `make test` start the simulator themselves when it is not already up, wait for it to
accept connections, and then load the binary into it. Neither hangs waiting for the simulator: both
give up with a message after 60 seconds. The simulator port is assumed to be 1234; override it with
`make run SIM_PORT=<port>` if yours differs.

`make run` does not return once the binary is loaded. `monkeydo` stays attached for the life of the
app session to relay the app's console output to your terminal, so the command sits in the
foreground while the watch face runs; press Ctrl-C when you are done. `make test` also uses
`monkeydo`, but captures its output and does return.

`make test` compiles and loads a unit-test binary, but the sources define no `(:test)` functions yet,
so the run reports a failure rather than `PASSED`. The target is kept ready for the test suite; until
that exists, treat a failing `make test` as expected.

To sideload your application to your Garmin watch, see [developer.garmin.com/connect-iq/connect-iq-basics/your-first-app](https://developer.garmin.com/connect-iq/connect-iq-basics/your-first-app/).
