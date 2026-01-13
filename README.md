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
* [Build, test, deploy](#build-test-deploy)

## Matrix time

Matrix Time displays the current time as digits with [Digital Rain](https://en.wikipedia.org/wiki/Digital_rain) in the background.

**Note**  
Due to power constraints on watch faces, the digital rain does not appear to fall smoothly, as watch faces are refreshed once per second.

## Features

The Matrix Time watch face supports the following features:

|Screenshot|Description|
|-|:-|
|![](resources/graphics/MatrixTime4.png)|**Digital rain**<br/> An implementation of the digital rain design is used as a bacground for the current time.

In the initial version, there are no customisation settings.

## Fonts

The Matrix Time watch face uses custom fonts:

* [Norfok Matrix Code NFI](https://www.norfok.com) for the digital raing glyphs.
* [SUSEMono Regular](https://fonts.google.com/specimen/SUSE+Mono) for the current time.

> The development of Garmin watch faces motivated the implementation of two useful tools:
> * A TTF to FNT+PNG converter ([`ttf2bmp`](https://github.com/wkusnierczyk/ttf2bmp)).  
> Garmin watches use non-scalable fixed-size bitmap fonts, and cannot handle variable size True Type fonts directly.
> * An font scaler automation tool ([`garmin-font-scaler`](https://github.com/wkusnierczyk/garmin-font-scaler)).  
> Garmin watches come in a variety of shapes and resolutions, and bitmap fonts need to be scaled for each device proportionally to its resolution.

The font development proceeded as follows:

* The fonts were downloaded from [Google Fonts](https://fonts.google.com/) as True Type  (`.ttf`) fonts.
* The fonts were converted to bitmaps as `.fnt` and `.png` pairs using the open source command-line [`ttf2bmp`](https://github.com/wkusnierczyk/ttf2bmp) converter.
* The font sizes were established to match the Garmin Fenix 7X Solar watch 280x280 pixel screen resolution.
* The fonts were then scaled proportionally to match other screen sizes available on Garmin watches using the [`garmin-font-scaler`](https://github.com/wkusnierczyk/garmin-font-scaler) tool.


The table below lists all font sizes provided for the supported screen resolutions.

| Resolution |    Shape     | Element |       Font       | Size |
| ---------: | :----------- | :------ | :--------------- | ---: |
|  148 x 205 | rectangle    | Matrix  | MatrixCodeNFI    |   10 |
|  148 x 205 | rectangle    | Time    | SUSEMono regular |   10 |
|  176 x 176 | semi-octagon | Matrix  | MatrixCodeNFI    |   12 |
|  176 x 176 | semi-octagon | Time    | SUSEMono regular |   12 |
|  215 x 180 | semi-round   | Matrix  | MatrixCodeNFI    |   12 |
|  215 x 180 | semi-round   | Time    | SUSEMono regular |   12 |
|  218 x 218 | round        | Matrix  | MatrixCodeNFI    |   14 |
|  218 x 218 | round        | Time    | SUSEMono regular |   14 |
|  240 x 240 | round        | Matrix  | MatrixCodeNFI    |   16 |
|  240 x 240 | rectangle    | Matrix  | MatrixCodeNFI    |   16 |
|  240 x 240 | round        | Time    | SUSEMono regular |   16 |
|  240 x 240 | rectangle    | Time    | SUSEMono regular |   16 |
|  260 x 260 | round        | Matrix  | MatrixCodeNFI    |   17 |
|  260 x 260 | round        | Time    | SUSEMono regular |   17 |
|  280 x 280 | round        | Matrix  | MatrixCodeNFI    |   19 |
|  280 x 280 | round        | Time    | SUSEMono regular |   19 |
|  320 x 360 | rectangle    | Matrix  | MatrixCodeNFI    |   21 |
|  320 x 360 | rectangle    | Time    | SUSEMono regular |   21 |
|  360 x 360 | round        | Matrix  | MatrixCodeNFI    |   24 |
|  360 x 360 | round        | Time    | SUSEMono regular |   24 |
|  390 x 390 | round        | Matrix  | MatrixCodeNFI    |   26 |
|  390 x 390 | round        | Time    | SUSEMono regular |   26 |
|  416 x 416 | round        | Matrix  | MatrixCodeNFI    |   27 |
|  416 x 416 | round        | Time    | SUSEMono regular |   27 |
|  454 x 454 | round        | Matrix  | MatrixCodeNFI    |   30 |
|  454 x 454 | round        | Time    | SUSEMono regular |   30 |

## Build, test, deploy

To modify and build the sources, you need to have installed:

* [Visual Studio Code](https://code.visualstudio.com/) with [Monkey C extension](https://developer.garmin.com/connect-iq/reference-guides/visual-studio-code-extension/).
* [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/).

Consult [Monkey C Visual Studio Code Extension](https://developer.garmin.com/connect-iq/reference-guides/visual-studio-code-extension/) for how to execute commands such as `build` and `test` to the Monkey C runtime.

You can use the included `Makefile` to conveniently trigger some of the actions from the command line.

```bash
# build binaries from sources
make build

# run unit tests -- note: requires the simulator to be running
make test

# run the simulation
make run

# clean up the project directory
make clean
```

To sideload your application to your Garmin watch, see [developer.garmin.com/connect-iq/connect-iq-basics/your-first-app](https://developer.garmin.com/connect-iq/connect-iq-basics/your-first-app/).
