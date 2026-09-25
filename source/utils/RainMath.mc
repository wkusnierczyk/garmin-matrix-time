using Toybox.Graphics;
using Toybox.Math;

import Toybox.Lang;


// The colour ramp is packed 0xRRGGBB, one byte a channel.
const
    RED_SHIFT = 16,
    GREEN_SHIFT = 8,
    BLUE_SHIFT = 0,
    MASK = 0xFF;


// The arithmetic behind the scene, with none of the drawing.
//
// Everything here was a private method of DigitalRain, where nothing could reach it:
// Monkey C's `private` is class scope, and a unit test is a global function or a static
// method of another class, so both are outside it. Moving the class's own test hooks
// inside DigitalRain is not an option either -- a static method that reads a private
// instance field of its own class crashes the 9.2.0 compiler outright ("A critical error
// has occurred"), for a read the compiler accepts everywhere else (#23).
//
// So the arithmetic comes out and the drawing stays behind. What is here is what can be
// checked by comparing numbers: the colour ramp, the grid's size and origin, the
// round-display cull, the always-on jitter, the clock string. Each is pure -- same
// arguments, same answer, no Dc, no device settings, no clock -- and each is called at
// most once a frame, so the call costs nothing that matters.
//
// The one piece of arithmetic deliberately left in DigitalRain is the head/shade index
// wrap in _drawTrails. That one runs some 340 times a frame, and #60 went to the trouble
// of lifting every field read out of that loop; adding a function call back into it to
// make it reachable would undo the work. It is covered end to end instead, by
// DigitalRainTest driving draw() over enough frames for every head to wrap.
module RainMath {

    // The trail's colour ramp: index 0 is the head, at full brightness, and each step
    // back along the trail is one step dimmer until the ramp reaches black `steps` rows
    // later. `_drawTrails` skips the black tail rather than drawing it (#8), so `steps` is
    // both the trail length and the number of bands drawn a frame.
    //
    // Lite passes `rowCount / 2`, half a screen. Premium's trail length setting passes a
    // chosen fraction of the screen instead (#53); the caller decides, not the ramp.
    //
    // The clamp is on `scale`, before it reaches a channel, so with `scale` in
    // [0, steps] and each channel in [0, 255] every term is in range by construction.
    //
    // What it replaces -- `if (shade < 0) { shade = 0; }` on the packed colour -- gave
    // the same ramp for every colour, but only via a 32-bit sign-propagation argument:
    // past `steps` all three channels scale by the same negative factor, and a channel
    // in [-255, 0] still sets the sign bit after a shift of 16 or less, so the OR is
    // negative whenever any channel is. Correct, and far too subtle to leave a colour
    // change resting on (#9).
    //
    // The ramp needs at least one step to divide by. Lite's `rowCount / 2` is at least 8
    // on every supported screen -- the smallest ring is 17 rows -- so the guard cannot
    // bite there. It guards the arithmetic rather than a known input: a future device
    // with a row height past half the screen would make `steps` 0 and divide by it three
    // times a row (#28).
    function shades(rowCount as Number, steps as Number, color as Number) as Array<Graphics.ColorType> {

        if (steps < 1) {
            steps = 1;
        }

        var red = (color >> RED_SHIFT) & MASK,
            green = (color >> GREEN_SHIFT) & MASK,
            blue = (color >> BLUE_SHIFT) & MASK;

        var ramp = new [rowCount] as Array<Graphics.ColorType>;
        for (var i = 0; i < rowCount; ++i) {
            var scale = steps - i;
            if (scale < 0) {
                scale = 0;
            }
            ramp[i] = ((red * scale / steps) << RED_SHIFT) |
                      ((green * scale / steps) << GREEN_SHIFT) |
                      ((blue * scale / steps) << BLUE_SHIFT);
        }
        return ramp;

    }


    // How many cells the grid steps from the centre to the edge along one axis, given the
    // distance from the centre to that edge and the cell pitch.
    //
    // The grid is built outward from the screen centre rather than from the top-left
    // corner: one cell sits exactly at the centre and the rest step out symmetrically in
    // both directions. A corner-anchored grid centred its first row and column on y = 0 /
    // x = 0 -- half of every one of those glyphs off the screen -- while leaving the far
    // edge ragged by whatever the cell size did not divide (#10).
    //
    // The half-cell term picks the smallest number of steps whose outermost cell still
    // reaches the edge, so the grid covers the screen without any cell landing entirely
    // outside it.
    function centerSteps(half as Number, pitch as Number) as Number {
        return Math.ceil((half - pitch / 2.0) / pitch).toNumber();
    }


    // The cell centres along one axis: `count` of them, `pitch` apart, starting at
    // `origin`. A cell's pixel position never changes -- its x depends only on the column
    // and its y only on the row -- so precomputing both replaces the two multiplications
    // `_drawTrails` did per drawn cell, some 320 a frame, with two array reads (#60).
    function axis(origin as Number, pitch as Number, count as Number) as Array<Number> {

        var coordinates = new [count] as Array<Number>;
        for (var i = 0; i < count; ++i) {
            coordinates[i] = origin + i * pitch;
        }
        return coordinates;

    }


    // How many rows above and below the centre row this column reaches before it leaves a
    // round display, or -1 for a column that is off the glass entirely. `columnOffset` is
    // the column's distance from the centre column, in columns.
    //
    // The test is cell rectangle against circle, not cell centre against circle. A
    // centre-in-circle test drops every cell whose centre has crossed the rim even when
    // most of its glyph is still on the glass, which left a thin uncovered band right
    // round the edge where the rain stopped short -- 1.9% to 3.4% of the visible disc,
    // depending on the resolution (#63). Shrinking the centre distance by half a cell on
    // each axis before the comparison keeps every cell whose rectangle touches the circle.
    // It is the conservative direction for a culling test: it can keep a cell whose ink
    // misses the glass, but never drops one whose ink would have hit it.
    //
    // Coverage does not depend on the resolution. The cells are laid out as a gapless
    // tiling that overhangs the screen on all four sides, so every point of the glass
    // falls inside some cell, and keeping every cell that meets the disc therefore covers
    // the disc entirely by construction. Sampling agreed: measured across every round
    // resolution configured at the time -- the four the manifest ships, 360x360, 390x390,
    // 416x416 and 454x454, plus the four stale entries #19 has since removed -- the
    // uncovered band came out at 0.00% everywhere, for 10-15% more cells.
    function rowReach(
        columnOffset as Number,
        columnWidth as Number,
        rowHeight as Number,
        radius as Float,
        centerRow as Number
    ) as Number {

        // Horizontal distance from the centre to the cell's nearer vertical edge, zero
        // for the columns the vertical centre line passes through.
        var dx = (columnOffset * columnWidth).abs() - columnWidth / 2.0;
        if (dx < 0.0) {
            dx = 0.0;
        }

        var span = radius * radius - dx * dx;
        if (span < 0) {
            return -1;
        }

        // The grid is symmetric about the centre row, so the span is too: it reaches the
        // same number of rows above and below it. The half row added back is the vertical
        // half of the same rectangle test -- a row is in reach when its nearer horizontal
        // edge is inside the circle, not when its centre is.
        var reach = Math.floor((Math.sqrt(span) + rowHeight / 2.0) / rowHeight).toNumber();
        return (reach > centerRow) ? centerRow : reach;

    }


    // The always-on scene's offset from the screen centre, as [dx, dy]: one of the four
    // corners of a small square, stepped once a minute so that no pixel stays lit for
    // more than a minute at a time. `seconds` is the Moment's own value; the minute
    // number is taken straight off it, because the jitter needs nothing else from the
    // calendar and Gregorian.info is comparatively expensive.
    //
    // See LOW_POWER_JITTER_DIVISOR in Matrix.mc for why the square is the size it is.
    function jitter(seconds as Number, width as Number) as Array<Number> {

        var step = (seconds / 60) % LOW_POWER_POSITIONS;
        var offset = width / LOW_POWER_JITTER_DIVISOR;

        return [
            (step == 0 || step == 3) ? -offset : offset,
            (step < 2) ? -offset : offset
        ];

    }


    // The clock string. `hour` is 0-23 as Gregorian.FORMAT_SHORT reports it; on a 12-hour
    // watch it is mapped to a 12-hour clock where 0 and 12 both read as 12.
    //
    // The hour is padded with %2d on purpose -- do not "fix" it to %d. SUSEMono-Regular is
    // monospace, every glyph including the space and the colon sharing one advance, so the
    // padding space occupies exactly one digit cell. That keeps the string a constant five
    // cells wide for every hour, and a centre-justified time therefore never shifts as the
    // hour crosses 9 -> 10 or between 12- and 24-hour mode. %d would make it jump. See #7,
    // filed as a bug and closed as intentional.
    function timeText(hour as Number, minute as Number, is24Hour as Boolean) as String {

        var shown = hour;
        if (!is24Hour) {
            shown = ((hour + 11) % 12) + 1;
        }
        return Lang.format("$1$:$2$", [shown.format("%2d"), minute.format("%02d")]);

    }

}
