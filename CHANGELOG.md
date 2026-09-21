# Changelog

Everything in Matrix Time that a user could notice, newest first. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); the project follows
[semantic versioning](https://semver.org/spec/v2.0.0.html), with the version in `manifest.xml` as the
single source of truth -- it is the number the Connect IQ store shows.

Issue numbers in parentheses point at
[the tracker](https://github.com/wkusnierczyk/garmin-matrix-time/issues), where the reasoning behind
each change is recorded in full.

## 0.2.0 -- 2026-09-21

Everything since the first release. The always-on screen was rewritten, the digits left the rain,
the rain loop was rebuilt around the profiler, and the supported device list grew by half.

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
