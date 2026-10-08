# Changelog

Everything in Matrix Time that a user could notice, newest first. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); the project follows
[semantic versioning](https://semver.org/spec/v2.0.0.html). A section is a code release, tagged `vX.Y.Z`
and shared by both editions. Each edition's version is the one in its own manifest, `manifest.xml`
for Lite and `manifest-premium.xml` for Premium. The owner decides which editions get a new version in
a release -- both, one or neither -- and only those move to the release's version, so the versions can
differ (#186). From 1.0.2 on, every release carries both editions' bundles, each at its own version
(#223).

Issue numbers in parentheses point at
[the tracker](https://github.com/wkusnierczyk/garmin-matrix-time/issues), where the reasoning behind
each change is recorded in full.

## 1.0.2 -- 2026-10-08

Tooling and store images only: neither watch face changes, and both editions stay at 1.0.1. This
release carries both editions' 1.0.1 bundles, under their new names.

### Internal

No user-visible effect on either watch face:

* `make export` names the store bundle by edition and version, `MatrixTime-1.0.1.iq` and
  `MatrixTimePremium-1.0.1.iq`, without the tag's `v`, and the release assets keep those names. A
  failed export no longer leaves an old bundle at the path that gets uploaded. (#216, #217)
* The `.prg` files inside a bundle keep their plain names, `MatrixTime.prg` or
  `MatrixTimePremium.prg`, as in every public bundle the store has taken, whatever the bundle's own
  name. (#221, #222)
* Every release carries a bundle for both editions, each at the version in its own manifest. The
  notes end with a list saying which bundles carry a new version and which carry theirs over. A
  release may give new versions to both editions, one, or neither; this one gives neither.
  (#223, #224)
* Lite gets a store cover, the same artwork as Premium's without the star, and both covers are
  500 x 500. (#219, #220)
* The README links a report to Garmin: the Connect IQ store takes the app version from a free text
  field, not from the bundle, and publishes it before the release notes are in. (#226, #227)

## 1.0.1 -- 2026-10-08

A fix for both editions: the screen now stays dark in sleep mode, as it does with Garmin's own
watch faces.

### Fixed

* **The screen stays dark in sleep mode.** During the watch's sleep schedule, once the sleep-mode
  timeout had passed, the face showed its always-on time all night, where Garmin's own watch faces
  leave the screen dark. The watch switches the display off at that point but still asks the face to
  draw, and the face drew its always-on screen. It now draws nothing while the display is off, so the
  face follows the sleep-mode display settings as the built-in faces do. Waking the watch brings it
  back, and outside the sleep schedule the always-on screen is unchanged. Both editions. (#212)

## 1.0.0 -- 2026-10-07

The first release of Matrix Time Premium, the paid edition: everything below marked Premium. It is a
separate app, for the same watches, and installs alongside Lite rather than over it. Lite, the free
edition, gets the fix under Fixed and is otherwise unchanged; it goes from 0.2.1 to 1.0.0 because
the two editions share their release numbers.

### Added

* **Premium: a choice of time size.** Premium's settings, in Connect IQ and on the watch, offer
  seven sizes for the time on the woken screen, from Extra extra small to Extra extra large. Extra
  extra small is Lite's size; Medium, two and a half times it, is the default, and Extra extra large,
  four times it, spans about 80% of the screen and still fits a round screen with the time at the
  left or right. The rain is unaffected. (#32, #155, #153, #166)
* **Premium: a choice of trail length.** The rain can fade to black over 25%, 50% or 75% of the
  screen. 50% is Lite's length and the default. A shorter trail also draws less each frame, so it
  saves battery; a longer one fades more smoothly. (#53)
* **Premium: a hollow time, and no box.** A time style setting draws the time as an outline instead
  of solid digits, so the rain falls through the digits. It applies to the Small time size and every
  size above it; Extra extra small and Extra small stay solid. Filled is the default. In either style
  the time is drawn without the black box Lite draws it on, so the rain falls right up to the digits
  rather than leaving out the whole time field. (#72, #174)
* **Premium: a bolder time.** Premium draws the time in SUSE Mono ExtraBold, the same typeface as
  Lite at a heavier weight, at every size, filled and hollow, woken and always-on. The digits read
  more strongly against the rain, and the outline of the hollow time has room to show it through. The
  always-on screen stays well inside the burn-in limits on every supported watch. (#144)
* **Premium: the settings on the watch.** The face's Customize menu lists all the settings with
  their current values, and selecting one steps to the next value, so a face sideloaded without the
  Connect IQ app can be set up too. (#148)
* **Premium: a choice of time and rain colours.** The time can be green, white, cyan, amber, orange
  or red, and the always-on time follows it. The rain can be green, cyan, blue, amber, orange,
  red or white, or change hue as it fades: white to green (a white-hot head cooling to green) or
  green to teal. Green, Lite's look, is the default for both. (#143, #171)
* **Premium: a choice of time alignment.** The time can sit at the left, centre or right of the woken
  screen. Centre, Lite's look, is the default. The margin follows the screen's curve and the time
  size, so no digit is cut off by a round screen's edge. Premium does not pad the hour with a blank
  as Lite does, so at a single-digit hour the time is `7:25`, not ` 7:25`. A left-aligned time
  therefore starts at its margin at every hour, and the time changes width by one character
  whenever the hour gains or loses a digit. At the left or right the time shares its margin with
  the date, whether or not the date is shown, so turning the date on never moves it. The always-on
  time stays centred, and is unpadded too. (#154, #196, #202)
* **Premium: a larger always-on time.** The always-on screen draws the time filled at the Extra
  large size, whatever the settings for the woken screen. It is bigger and bolder than Lite's, and
  moves further each minute than Lite's does, which keeps it well inside the burn-in limits on every
  supported watch. (#145, #153, #164)
* **Premium: a choice of always-on brightness.** The time on the always-on screen can be Bright,
  the full time colour, Dimmed, five sixths of it, or Dim, the two thirds Lite draws. Bright is the
  default, since the dimmer always-on time was hard to read. The burn-in figures hold at every level.
  (#161)
* **Premium: the date.** A date setting shows today's date under the time on the woken screen, as
  2026-09-29, at the Extra extra small time size and in the time colour. It follows the time
  alignment and lines up with the time at every hour and every time size, and the two stay clear of
  a round screen's edge. Off, Lite's look, is the default. It is drawn on a black box, since text
  that small does not read over the rain. The always-on screen shows the time alone. (#163, #174,
  #196, #202)
* **Premium: presets.** Five slots, each a saved look that can be loaded back in one step: time size,
  trail length, time style, time alignment, time colour and rain colour. Load and save are at the top
  of the watch's Customize menu and in the Connect IQ app, where the slots can also be renamed.
  Loading a preset leaves always-on brightness and the date as they are. Slots 1 to 3 come filled
  with three looks, Green, Red and Blue, which can be loaded straight away, renamed, or saved over.
  (#172, #183)
* **Premium: its own launcher icon.** Premium's icon is Lite's with a gold star in the corner, so the
  two editions can be told apart in a launcher list, at every size a supported watch asks for. The store
  listing gets a square cover image built from the same artwork. (#189)
* **Premium: its own store images.** The Premium store listing has a gallery of its own: the three
  built-in presets, a white-to-green rain under a hollow time, and the always-on screen, with a hero
  composed from the five. (#188)

### Fixed

* **The always-on time no longer disappears.** On some watches it went dark after a while and stayed
  dark, across later sleeps, until the face was restarted, for example by opening the activity list
  and backing out. The watch can start an always-on frame before telling the face it is asleep, and
  the face then drew its full rain in always-on, which the burn-in protector shuts the screen off for.
  The face now also asks the watch which mode the screen is in, and draws the always-on time whenever
  either says asleep. Both editions. (#191)

## 0.2.1 -- 2026-09-21

Everything since the first release. The always-on screen was rewritten, the digits left the rain,
the rain loop was rebuilt around the profiler, and the supported device list grew by half.

There is no properly published 0.2.0. Uploading to the store takes two steps -- the file and its
version, then the description and the release notes -- and the first step alone was enough to move
the listing to 0.2.0, with the release notes left reading "Initial release." from 0.1.0. The number
cannot be uploaded a second time, so this release goes out as 0.2.1, carrying the notes 0.2.0 never
received. The two are the same face.

### Added

* **An always-on screen that is actually readable.** Matrix Time now draws a different scene in
  low-power mode: the time alone, at twice the size it has on the woken screen, a little dimmer, and
  moved to a different corner of a small square every minute. Raising the wrist brings the rain back. Before
  this, the same full-screen rain was drawn awake or asleep, which Garmin's burn-in protector
  responds to by blanking the display -- it blanks when more than 10% of the pixels are lit, or when
  any pixel stays lit for longer than three minutes, and a full-screen rain fails both tests. The
  minute-by-minute shift is what keeps any one pixel from staying lit. (#12, #67, #69, #71)

* **Seventeen more watches**, taking the supported list from 34 products to 51. fēnix 9 (43mm,
  47mm / 51mm), fēnix 9 Pro (43mm, 47mm, 51mm), Venu X1, Descent G2, D2 Air X10, D2 Mach 1, D2 Mach 2,
  D2 Mach 2 Pro, Approach S50, Approach S70 (42mm, 47mm), Forerunner 70, Forerunner 170 and
  Forerunner 170 Music. Two of those brought screen sizes the face had never been drawn for --
  466x466 on the fēnix 9 Pro 51mm and 448x486 on the Venu X1 -- so both have fonts scaled for them
  rather than borrowed from a neighbour. (#100)

### Changed

* **The rain is letters only.** Matrix Code NFI draws letters as katakana-style glyphs but digits as
  recognisable digits, so with `0`-`9` in the set roughly 28% of the rain was numerals competing with
  the clock for attention. The time is now the only number on the screen. (#54, #79)

* **12-hour watches show 12-hour time.** The face read the hour as 0-23 and never consulted the
  device's own setting, so a watch set to 12-hour time displayed `13:45` where it should have shown
  `1:45`. No AM/PM marker is added: the time font has no letters in it. (#51)

* **The rain reaches the rim on round watches.** Cells were kept or dropped by asking whether the
  centre of the cell fell inside the glass, which discarded cells that would still have painted
  visible pixels and left a bare ring round the edge -- between 1.9% and 3.4% of the visible disc,
  depending on the watch. The test is now whether the cell overlaps the glass at all, and the ring is
  gone at every round resolution. (#83)

* **The grid is centred on the screen.** It used to be anchored at the top-left corner, which put
  half of the first column and half of the first row off the screen and left whatever did not divide
  evenly as a ragged margin on the opposite edge. One glyph now lands exactly at the centre and the
  overhang is equal on both sides. (#62)

* **Glyphs no longer touch.** The spacing of the grid was measured from the width of `0`, a character
  the rain font stopped containing when the digits were dropped; Connect IQ answers a request for a
  missing glyph with a fixed 13 pixels, so the spacing had quietly become a constant with nothing to
  do with the typeface, and the widest letters overhung their cell and inked into their neighbours.
  It is now measured from the widest glyph actually in the set. The rain is slightly sparser as a
  result, and the number of columns changed on most screens. (#85)

* **A launcher icon drawn at the size each watch asks for.** One 100x100 image was being scaled to
  whatever the watch wanted -- eight different sizes across the supported list, as small as 38x38 --
  with a compiler warning on every build. Each size is now rendered at its own resolution. (#42, #77)

* **The store listing's compatibility claim is honest.** The manifest declared a minimum Connect IQ
  version of 1.2.0 while the lowest version any supported watch actually runs is 5.0.0. (#13, #70)

### Performance

None of this changes what is on the screen. It changes what the watch spends its battery on, and it
came out of profiling rather than guesswork; the figures are per frame on an epix Pro (Gen 2) 47mm.

* Clearing the screen through `Dc.clear()` rather than painting a full-screen rectangle: 12.6 ms down
  to 9.5 ms, and the whole frame from 57.9 ms to 53.1 ms. (#61)
* Not drawing the tail of each trail after the colour ramp has faded it to black -- it was painting
  black on black: 53% fewer glyph draws per frame. (#52)
* Not drawing the corners of the grid that fall off a round screen, which is 31 of the watches
  supported at the time: about 28% of each frame. (#55)
* Setting the drawing colour once per shade rather than once per glyph: 8 calls a frame where there
  were 160. (#82)
* Taking the arithmetic out of the inner loop -- one modulo per column instead of one per cell,
  precomputed coordinates, and every field read once: about 340 modulo operations and 320
  multiplications a frame. (#60, #75)
* Holding the rain glyphs as strings from the start, so the rain stopped creating some 160
  short-lived strings a frame for the garbage collector to clean up afterwards. Drawing the clock
  still builds a string of its own each frame, so a frame is not allocation-free; the rain is simply
  no longer the bulk of it. (#57, #81)

### Fixed

* The trail's colour ramp clamped the finished colour rather than the factor that produced it, which
  happened to give the right answer for every colour but rested on 32-bit sign propagation to do it.
  The ramp itself is unchanged. (#76)
* The face now ships a property table with one declared property in it. Nothing in this edition reads
  a property, but a build with no table at all takes the app down on the first read with an error no
  error handler can catch, and the settings work in the Pro edition would have walked straight into
  it. The property is a placeholder with no settings screen, so nothing appears in Connect IQ or on
  the watch. (#91, #93, #95)

### Internal

No user-visible effect: a unit-test suite (#92), a font and launcher-icon consistency check run on
every change (#47, #54), a `make sideload` target that installs to a connected watch (#96, #101), a
`make export` target that builds the store bundle (#112), GitHub Actions building one product per
device family on every push (#41, #102), the SDK path resolved from the SDK manager instead of pinned
(#49), and a round of code cleanups (#86, #89, #90, #98).

## 0.1.0 -- 2026-01-13

First release: the digital rain, the time drawn over it, 34 AMOLED watches, no settings.
