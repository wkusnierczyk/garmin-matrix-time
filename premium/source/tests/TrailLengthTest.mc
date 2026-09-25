using Toybox.Application;
using Toybox.Application.Properties;
using Toybox.Graphics;
using Toybox.Test;
using Toybox.Time;

import Toybox.Lang;


// The trail length setting (#53). Premium only, like the property it reads.
(:test)
class TrailLengthTest {

    // Sets trailLength for the length of one check and puts back what was there, for the
    // reason TimeSizeTest.selectedWith gives.
    private static function selectedWith(value as Number) as Number {
        var saved = Properties.getValue(TrailLength.PROPERTY);
        Properties.setValue(TrailLength.PROPERTY, value);
        var selected = TrailLength.selected();
        Properties.setValue(TrailLength.PROPERTY, saved as Number);
        return selected;
    }

    // The lit bands of a ramp: the ones _drawTrails draws.
    private static function lit(shades as Array<Graphics.ColorType>) as Number {
        var count = 0;
        for (var i = 0; i < shades.size(); ++i) {
            if (shades[i] != 0) {
                ++count;
            }
        }
        return count;
    }


    // Resolving to a Number rather than to the String default is the proof the property is
    // declared, and in the same merged table as TimeSize's (#91).
    (:test)
    static function thePropertyIsDeclared(logger as Test.Logger) as Boolean {
        var length = PropertyUtils.getPropertyElseDefault(TrailLength.PROPERTY, "not declared");
        Test.assertMessage(length instanceof Lang.Number, "trailLength is declared, but got: " + length);
        return true;
    }


    (:test)
    static function eachOfTheOfferedLengthsIsKept(logger as Test.Logger) as Boolean {
        var offered = [25, 50, 75];
        for (var i = 0; i < offered.size(); ++i) {
            var percent = offered[i] as Number;
            Test.assertEqualMessage(selectedWith(percent), percent, percent + "% is selected as stored");
        }
        return true;
    }


    // A value no listEntry offers but that is still a percentage is kept: that is what lets
    // the list grow without a change here.
    (:test)
    static function anyPercentageStrictlyInsideTheScreenIsKept(logger as Test.Logger) as Boolean {
        Test.assertEqualMessage(TrailLength.percentOf(1), 1, "1% is kept");
        Test.assertEqualMessage(TrailLength.percentOf(99), 99, "99% is kept");
        return true;
    }


    (:test)
    static function anOutOfRangeLengthFallsBackToHalf(logger as Test.Logger) as Boolean {
        Test.assertEqualMessage(selectedWith(0), TrailLength.DEFAULT, "0 falls back to 50");
        Test.assertEqualMessage(selectedWith(100), TrailLength.DEFAULT, "100 falls back to 50");
        Test.assertEqualMessage(selectedWith(-25), TrailLength.DEFAULT, "-25 falls back to 50");
        return true;
    }


    (:test)
    static function aValueOfTheWrongTypeFallsBackToHalf(logger as Test.Logger) as Boolean {
        Test.assertEqualMessage(TrailLength.percentOf(null), TrailLength.DEFAULT, "null falls back to 50");
        Test.assertEqualMessage(TrailLength.percentOf("25"), TrailLength.DEFAULT, "a String falls back to 50");
        Test.assertEqualMessage(TrailLength.percentOf(25.0f), TrailLength.DEFAULT, "a Float falls back to 50");
        Test.assertEqualMessage(TrailLength.percentOf(true), TrailLength.DEFAULT, "a Boolean falls back to 50");
        return true;
    }


    // 50% has to be Lite's rowCount / 2 exactly, on every ring a supported screen gives --
    // 17 rows on the round products, 19 on 320x360 -- and on odd and even rings besides.
    (:test)
    static function halfIsLitesHalfScreen(logger as Test.Logger) as Boolean {
        for (var rowCount = 2; rowCount <= 40; ++rowCount) {
            Test.assertEqualMessage(TrailLength.steps(50, rowCount), rowCount / 2, "50% of " + rowCount + " rows");
        }
        return true;
    }


    (:test)
    static function theOfferedLengthsOnASeventeenRowRing(logger as Test.Logger) as Boolean {
        Test.assertEqualMessage(TrailLength.steps(25, 17), 4, "25% of 17 rows");
        Test.assertEqualMessage(TrailLength.steps(50, 17), 8, "50% of 17 rows");
        Test.assertEqualMessage(TrailLength.steps(75, 17), 12, "75% of 17 rows");
        return true;
    }


    // At least one lit row, and never the whole ring: a trail with no black band would have
    // _drawTrails skip nothing.
    (:test)
    static function theStepsStayInsideTheRing(logger as Test.Logger) as Boolean {
        Test.assertEqualMessage(TrailLength.steps(1, 17), 1, "1% of 17 rows is still one row");
        Test.assertEqualMessage(TrailLength.steps(99, 17), 16, "99% of 17 rows leaves one black band");
        Test.assertEqualMessage(TrailLength.steps(99, 200), 198, "99% of 200 rows");
        return true;
    }


    // The whole path a change in Connect IQ takes, on a rain that is already falling:
    // App.onSettingsChanged, View.applySettings, DigitalRain.applyTrailLength. Without it a
    // change would do nothing until the face restarted, and every other test here would
    // still pass.
    (:test)
    static function aSettingsChangeReachesTheRampDrawn(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as App;
        var view = (app.getInitialView() as Array)[0] as View;
        var rain = view.digitalRain();
        var saved = Properties.getValue(TrailLength.PROPERTY);

        var bitmap = Graphics.createBufferedBitmap({ :width => 64, :height => 64 }).get();
        Test.assertMessage(bitmap != null, "the simulator would not allocate a scratch bitmap");
        rain.forTime(Time.now()).draw((bitmap as Graphics.BufferedBitmap).getDc());

        // Restored in finally, so a throw part way round cannot leave a length behind in
        // the simulator's settings file.
        var counts = [0, 0, 0];
        var offered = [25, 50, 75];
        try {
            for (var i = 0; i < offered.size(); ++i) {
                Properties.setValue(TrailLength.PROPERTY, offered[i] as Number);
                app.onSettingsChanged();
                counts[i] = lit(rain.shades());
            }
        } finally {
            Properties.setValue(TrailLength.PROPERTY, saved as Number);
            app.onSettingsChanged();
        }

        logger.debug("lit bands at 25/50/75%: " + counts);
        var rows = rain.shades().size();
        for (var i = 0; i < offered.size(); ++i) {
            Test.assertEqualMessage(counts[i], TrailLength.steps(offered[i] as Number, rows), offered[i] + "% lights its steps");
        }
        Test.assertMessage(counts[0] < counts[1] && counts[1] < counts[2], "a longer setting lights more bands");
        return true;
    }

}
