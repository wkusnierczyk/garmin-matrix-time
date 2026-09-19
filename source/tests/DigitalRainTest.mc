using Toybox.Graphics;
using Toybox.Test;
using Toybox.Time;

import Toybox.Lang;


// What RainMath cannot reach: the drawing itself.
//
// The head and shade indices in _drawTrails are the one piece of arithmetic left inside
// DigitalRain -- that loop body runs some 340 times a frame and #60 went to the trouble
// of lifting every field read out of it, so a function call back in to make it reachable
// would undo the work. It is covered here instead, end to end: drawing enough frames for
// every column's head to wrap past the end of the ring and come round again exercises
// both the wrap and the row-span cull with every index the ring can produce. An index
// that ran off either end would throw, and a throw is a failed test.
(:test)
class DigitalRainTest {

    // Enough frames to wrap the ring several times over. Measured in the simulator, the
    // ring is 17 rows on every round product -- 390x390, 416x416 and 454x454 all come out
    // at 17, because the font is scaled per resolution and the row height scales with it
    // -- and 19 on the 320x360 rectangle. 96 frames is five times round the longest of
    // them, so every head visits every row.
    static const FRAMES = 96;

    // The scratch bitmap only has to answer font-metric questions and accept drawText.
    // It is deliberately far smaller than the screen: DigitalRain sizes its grid from
    // System.getDeviceSettings(), not from the Dc, so most of the grid lands outside this
    // buffer and is clipped. That is the point -- what is under test is the index
    // arithmetic, not the pixels.
    static const SCRATCH = 64;


    (:test)
    static function drawSurvivesEveryHeadWrappingRightRound(logger as Test.Logger) as Boolean {

        var rain = new DigitalRain();
        var dc = _scratchDc();
        var time = Time.now();

        for (var frame = 0; frame < FRAMES; ++frame) {
            rain.forTime(time).draw(dc);
        }

        logger.debug("drew " + FRAMES + " frames without an index running off the ring");
        return true;

    }


    (:test)
    static function drawLowPowerSurvivesTheWholeJitterCycle(logger as Test.Logger) as Boolean {

        // The always-on scene draws no rain, so it needs no grid: everything it touches
        // -- the screen centre, the width, the large font -- is set in the constructor.
        var rain = new DigitalRain();
        var dc = _scratchDc();

        for (var minute = 0; minute < 2 * LOW_POWER_POSITIONS; ++minute) {
            rain.forTime(new Time.Moment(minute * 60)).drawLowPower(dc);
        }

        return true;

    }


    (:test)
    static function theSceneCanChangeBetweenPowerStatesOnTheSameGrid(logger as Test.Logger) as Boolean {

        // View switches between the two scenes on the sleep callbacks without rebuilding
        // anything, so they have to share one initialised grid.
        var rain = new DigitalRain();
        var dc = _scratchDc();
        var time = Time.now();

        for (var round = 0; round < 8; ++round) {
            rain.forTime(time).draw(dc);
            rain.forTime(time).drawLowPower(dc);
        }

        return true;

    }


    (:test)
    static function forTimeHandsBackTheSameRain(logger as Test.Logger) as Boolean {
        var rain = new DigitalRain();
        Test.assertMessage(rain.forTime(Time.now()) == rain, "forTime is fluent, not a copy");
        return true;
    }


    static function _scratchDc() as Graphics.Dc {
        var reference = Graphics.createBufferedBitmap({ :width => SCRATCH, :height => SCRATCH });
        var bitmap = reference.get();
        Test.assertMessage(bitmap != null, "the simulator would not allocate a scratch bitmap");
        return (bitmap as Graphics.BufferedBitmap).getDc();
    }

}
