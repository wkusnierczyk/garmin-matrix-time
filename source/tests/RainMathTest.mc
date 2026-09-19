using Toybox.Test;

import Toybox.Lang;


// The pure arithmetic behind the scene. Every function under test takes numbers and
// returns numbers, so these run without a Dc, without device settings and without a
// clock -- see the module header in RainMath.mc for why the arithmetic lives there.
//
// Connect IQ strips every (:test) function from debug and release builds, so none of this
// reaches a watch: `make build` and `make test` compile the same sources and only the
// latter keeps the tests. The annotation is on the class as well as on each method --
// without it the class shell, its fixtures and the un-annotated helper below would all
// ship, which measured 1,136 bytes against the 160 the bare shells cost.
(:test)
class RainMathTest {

    // The four round radii the manifest ships -- 360x360, 390x390, 416x416, 454x454 --
    // and the one rectangle, 320x360, whose shorter side is its width.
    static const RADII = [180.0, 195.0, 208.0, 227.0, 160.0];
    static const WIDTHS = [360, 390, 416, 454, 320];

    // The three channels of a packed 0xRRGGBB colour.
    static const SHIFTS = [RED_SHIFT, GREEN_SHIFT, BLUE_SHIFT];


    //
    // The trail's colour ramp.
    //

    (:test)
    static function theHeadOfTheRampIsTheUndimmedColour(logger as Test.Logger) as Boolean {
        var ramp = RainMath.shades(17, MATRIX_COLOR);
        Test.assertEqualMessage(ramp[0], MATRIX_COLOR, "the head of the trail is drawn at full brightness");
        return true;
    }


    (:test)
    static function theRampIsTheExpectedSequence(logger as Test.Logger) as Boolean {
        // rowCount 5 gives steps 2: full colour, half of it, then black for the rest of
        // the ring. 255 / 2 is 127 and 43 / 2 is 21, both truncating.
        var ramp = RainMath.shades(5, 0x00FF2B);
        var expected = [0x00FF2B, 0x007F15, 0x000000, 0x000000, 0x000000];
        for (var i = 0; i < expected.size(); ++i) {
            Test.assertEqualMessage(ramp[i], expected[i], "ramp[" + i + "] of a 5-row ring");
        }
        return true;
    }


    (:test)
    static function everyChannelFadesOnItsOwn(logger as Test.Logger) as Boolean {
        // #9: the clamp is on `scale`, before it reaches a channel. The packed-colour
        // clamp it replaced happened to give the same answer, but only by a 32-bit
        // sign-propagation argument that no colour change should have to rest on. A
        // colour with all three channels lit is what tells the two apart by inspection.
        var ramp = RainMath.shades(5, 0xFF8040);
        Test.assertEqualMessage(ramp[0], 0xFF8040, "the head keeps all three channels");
        Test.assertEqualMessage(ramp[1], 0x7F4020, "each channel halves independently");
        Test.assertEqualMessage(ramp[2], 0x000000, "the ramp reaches black at `steps`");
        return true;
    }


    (:test)
    static function theRampFadesAndThenStaysBlack(logger as Test.Logger) as Boolean {
        // #8: the ramp fades to black over half a ring, and _drawTrails skips the black
        // tail rather than drawing it. Checked per channel, because the packed values
        // are only monotonic if each channel is.
        var rowCounts = [17, 21, 27, 31];
        for (var n = 0; n < rowCounts.size(); ++n) {
            var rowCount = rowCounts[n] as Number;
            var steps = rowCount / 2;
            var ramp = RainMath.shades(rowCount, MATRIX_COLOR);
            Test.assertEqualMessage(ramp.size(), rowCount, "one shade per row of a " + rowCount + "-row ring");
            for (var i = 1; i < rowCount; ++i) {
                for (var c = 0; c < SHIFTS.size(); ++c) {
                    var shift = SHIFTS[c] as Number;
                    var here = (ramp[i] >> shift) & MASK;
                    var before = (ramp[i - 1] >> shift) & MASK;
                    Test.assertMessage(here <= before, "channel at shift " + shift + " never brightens: ramp[" + i + "]");
                }
            }
            for (var i = steps; i < rowCount; ++i) {
                Test.assertEqualMessage(ramp[i], 0x000000, "ramp[" + i + "] is black from `steps` on");
            }
        }
        return true;
    }


    (:test)
    static function noShadeIsEverNegative(logger as Test.Logger) as Boolean {
        // #9 again, from the other side: a negative packed colour is what the old clamp
        // was detecting, and nothing downstream would survive one.
        var ramp = RainMath.shades(27, MATRIX_COLOR);
        for (var i = 0; i < ramp.size(); ++i) {
            Test.assertMessage(ramp[i] >= 0, "ramp[" + i + "] is a colour, not a negative");
        }
        return true;
    }


    (:test)
    static function aOneRowRingStillHasAStepToDivideBy(logger as Test.Logger) as Boolean {
        // #28: `steps` is rowCount / 2, which is 0 for a one-row ring. No supported screen
        // produces one -- the smallest ring is 17 rows -- so this guards the arithmetic
        // rather than a known input.
        var ramp = RainMath.shades(1, MATRIX_COLOR);
        Test.assertEqualMessage(ramp.size(), 1, "a one-row ring has one shade");
        Test.assertEqualMessage(ramp[0], MATRIX_COLOR, "and that shade is the head, not a division by zero");
        return true;
    }


    //
    // The grid.
    //

    (:test)
    static function theGridReachesTheEdgeAndNoFurther(logger as Test.Logger) as Boolean {
        // #10: the outermost cell has to cover the screen edge, and it has to be the
        // smallest number of steps that does -- one more would put a whole cell outside
        // the screen.
        var halves = [160, 180, 195, 208, 227];
        for (var h = 0; h < halves.size(); ++h) {
            var half = halves[h] as Number;
            for (var pitch = 8; pitch <= 60; ++pitch) {
                var steps = RainMath.centerSteps(half, pitch);
                var outerEdge = steps * pitch + pitch / 2.0;
                var innerEdge = (steps - 1) * pitch + pitch / 2.0;
                Test.assertMessage(outerEdge >= half,
                    "half " + half + " pitch " + pitch + ": the outermost cell reaches the edge");
                Test.assertMessage(innerEdge < half,
                    "half " + half + " pitch " + pitch + ": and one step fewer would not");
            }
        }
        return true;
    }


    (:test)
    static function theAxisStepsByThePitchFromTheOrigin(logger as Test.Logger) as Boolean {
        var coordinates = RainMath.axis(7, 16, 4);
        var expected = [7, 23, 39, 55];
        Test.assertEqualMessage(coordinates.size(), expected.size(), "one coordinate per cell");
        for (var i = 0; i < expected.size(); ++i) {
            Test.assertEqualMessage(coordinates[i], expected[i], "coordinate " + i);
        }
        Test.assertEqualMessage(RainMath.axis(0, 16, 0).size(), 0, "an empty grid has no coordinates");
        return true;
    }


    //
    // The round-display cull.
    //

    (:test)
    static function everyCellThatTouchesTheGlassIsKept(logger as Test.Logger) as Boolean {
        // #63, #83. `rowReach` is a closed form; `_touchesDisc` below is the definition it
        // is derived from -- the honest rectangle-against-circle test. Checking one against
        // the other across whole grids is what catches a cull that has quietly become a
        // centre-in-circle test again, which is what left a bare band round the rim.
        for (var r = 0; r < RADII.size(); ++r) {
            var radius = RADII[r] as Float;
            var half = radius.toNumber();
            for (var pitch = 10; pitch <= 34; pitch += 4) {
                var columnWidth = pitch;
                var rowHeight = pitch + 6;
                var centerColumn = RainMath.centerSteps(half, columnWidth);
                var centerRow = RainMath.centerSteps(half, rowHeight);
                for (var c = -centerColumn; c <= centerColumn; ++c) {
                    var reach = RainMath.rowReach(c, columnWidth, rowHeight, radius, centerRow);
                    for (var row = 0; row <= centerRow; ++row) {
                        var touches = _touchesDisc(c, row, columnWidth, rowHeight, radius);
                        // The message is built only when the assertion is about to fail.
                        // This loop runs some thirty thousand times, and concatenating a
                        // string on every pass costs far more than the arithmetic it is
                        // checking.
                        if (touches != (row <= reach)) {
                            Test.assertMessage(false,
                                "radius " + radius + " pitch " + pitch + " column " + c + " row " + row +
                                (touches ? ": a cell on the glass was culled" : ": a cell off the glass was kept"));
                        }
                    }
                }
            }
        }
        return true;
    }


    (:test)
    static function aColumnPastTheRimIsDroppedWhole(logger as Test.Logger) as Boolean {
        Test.assertEqualMessage(RainMath.rowReach(100, 16, 27, 208.0, 7), -1,
            "a column a hundred cells out is off the glass entirely");
        return true;
    }


    (:test)
    static function theReachNeverRunsPastTheGrid(logger as Test.Logger) as Boolean {
        // The centre column of a 416x416 screen reaches eight rows of 27 pixels, but a
        // grid with only three rows either side of centre has nowhere to put them.
        Test.assertEqualMessage(RainMath.rowReach(0, 16, 27, 208.0, 3), 3,
            "the reach is clamped to the rows the grid actually has");
        return true;
    }


    //
    // The always-on jitter.
    //

    (:test)
    static function theTimeStepsRoundFourDistinctCorners(logger as Test.Logger) as Boolean {
        // #69: the burn-in protector blanks an AMOLED screen if any pixel stays lit for
        // three minutes, so the four positions have to be four, and distinct.
        var width = 416;
        var offset = width / LOW_POWER_JITTER_DIVISOR;
        var expected = [[-offset, -offset], [offset, -offset], [offset, offset], [-offset, offset]];
        for (var minute = 0; minute < LOW_POWER_POSITIONS; ++minute) {
            var corner = RainMath.jitter(minute * 60, width);
            var want = expected[minute] as Array<Number>;
            Test.assertEqualMessage(corner[0], want[0], "minute " + minute + " dx");
            Test.assertEqualMessage(corner[1], want[1], "minute " + minute + " dy");
        }
        return true;
    }


    (:test)
    static function theCornerHoldsForAWholeMinuteAndThenMoves(logger as Test.Logger) as Boolean {
        var width = 416;
        var start = RainMath.jitter(0, width);
        var sameMinute = RainMath.jitter(59, width);
        var nextMinute = RainMath.jitter(60, width);
        var fourLater = RainMath.jitter(4 * 60, width);
        Test.assertEqualMessage(sameMinute[0], start[0], "the corner holds for the whole minute");
        Test.assertEqualMessage(sameMinute[1], start[1], "the corner holds for the whole minute");
        Test.assertMessage(nextMinute[0] != start[0] || nextMinute[1] != start[1],
            "the next minute is a different corner");
        Test.assertEqualMessage(fourLater[0], start[0], "the cycle repeats every four minutes");
        Test.assertEqualMessage(fourLater[1], start[1], "the cycle repeats every four minutes");
        return true;
    }


    (:test)
    static function theSquareIsNonZeroOnEveryShippedWidth(logger as Test.Logger) as Boolean {
        // A zero offset is the failure mode that matters: the time would sit in one place
        // and the protector would shut the screen off.
        for (var w = 0; w < WIDTHS.size(); ++w) {
            var width = WIDTHS[w] as Number;
            var corner = RainMath.jitter(0, width);
            Test.assertEqualMessage(corner[0], -(width / LOW_POWER_JITTER_DIVISOR), "dx on a " + width + " px screen");
            Test.assertMessage(corner[0] != 0, "the square has a width on a " + width + " px screen");
            Test.assertMessage(corner[1] != 0, "the square has a height on a " + width + " px screen");
        }
        return true;
    }


    //
    // The clock string.
    //

    (:test)
    static function aTwentyFourHourClockShowsTheHourAsGiven(logger as Test.Logger) as Boolean {
        Test.assertEqualMessage(RainMath.timeText(0, 0, true), " 0:00", "midnight");
        Test.assertEqualMessage(RainMath.timeText(9, 5, true), " 9:05", "a single-digit hour and minute");
        Test.assertEqualMessage(RainMath.timeText(13, 45, true), "13:45", "an afternoon hour");
        Test.assertEqualMessage(RainMath.timeText(23, 59, true), "23:59", "the last minute of the day");
        return true;
    }


    (:test)
    static function aTwelveHourClockReadsMidnightAndNoonAsTwelve(logger as Test.Logger) as Boolean {
        Test.assertEqualMessage(RainMath.timeText(0, 0, false), "12:00", "midnight is 12, not 0");
        Test.assertEqualMessage(RainMath.timeText(12, 0, false), "12:00", "noon is 12, not 0");
        Test.assertEqualMessage(RainMath.timeText(1, 30, false), " 1:30", "the small hours are themselves");
        Test.assertEqualMessage(RainMath.timeText(11, 30, false), "11:30", "and so is eleven");
        Test.assertEqualMessage(RainMath.timeText(13, 0, false), " 1:00", "13 reads as 1");
        Test.assertEqualMessage(RainMath.timeText(23, 0, false), "11:00", "23 reads as 11");
        return true;
    }


    (:test)
    static function theClockIsAlwaysFiveCellsWide(logger as Test.Logger) as Boolean {
        // #7. The hour is padded with %2d on purpose: SUSEMono-Regular is monospace, so
        // the padding space is one digit cell wide and the centre-justified time never
        // shifts as the hour crosses 9 -> 10 or between the two clock modes. %d would
        // make it jump, which is why this is a test and not a comment.
        for (var hour = 0; hour < 24; ++hour) {
            Test.assertEqualMessage(RainMath.timeText(hour, 0, true).length(), 5,
                "24-hour clock at " + hour + ":00");
            Test.assertEqualMessage(RainMath.timeText(hour, 0, false).length(), 5,
                "12-hour clock at " + hour + ":00");
        }
        return true;
    }


    // Does the cell at (columnOffset, rowOffset) overlap the disc? The nearest point of
    // the cell's rectangle to the screen centre, against the radius -- the definition
    // RainMath.rowReach is the closed form of.
    static function _touchesDisc(
        columnOffset as Number,
        rowOffset as Number,
        columnWidth as Number,
        rowHeight as Number,
        radius as Float
    ) as Boolean {

        var dx = (columnOffset * columnWidth).abs() - columnWidth / 2.0;
        if (dx < 0.0) {
            dx = 0.0;
        }
        var dy = (rowOffset * rowHeight).abs() - rowHeight / 2.0;
        if (dy < 0.0) {
            dy = 0.0;
        }
        return dx * dx + dy * dy <= radius * radius;

    }

}
