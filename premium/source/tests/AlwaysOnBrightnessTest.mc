using Toybox.Application;
using Toybox.Application.Properties;
using Toybox.Test;

import Toybox.Lang;


// The always-on brightness setting (#161). Premium only, like the property it reads.
(:test)
class AlwaysOnBrightnessTest {

    // Joins Lite's property table, as TimeSizeTest checks for timeSize (#91).
    (:test)
    static function thePropertyIsDeclared(logger as Test.Logger) as Boolean {
        var level = PropertyUtils.getPropertyElseDefault(AlwaysOnBrightness.PROPERTY, "not declared");
        Test.assertMessage(level instanceof Lang.Number, "alwaysOnBrightness is declared, but got: " + level);
        return true;
    }


    (:test)
    static function anythingButALevelIsBright(logger as Test.Logger) as Boolean {
        Test.assertEqualMessage(AlwaysOnBrightness.levelOf(null), AlwaysOnBrightness.BRIGHT, "null");
        Test.assertEqualMessage(AlwaysOnBrightness.levelOf(-1), AlwaysOnBrightness.BRIGHT, "-1");
        Test.assertEqualMessage(AlwaysOnBrightness.levelOf(AlwaysOnBrightness.DIM + 1), AlwaysOnBrightness.BRIGHT, "one past the end");
        Test.assertEqualMessage(AlwaysOnBrightness.levelOf("1"), AlwaysOnBrightness.BRIGHT, "a String");
        Test.assertEqualMessage(AlwaysOnBrightness.levelOf(1.0f), AlwaysOnBrightness.BRIGHT, "a Float");
        Test.assertEqualMessage(AlwaysOnBrightness.levelOf(AlwaysOnBrightness.DIMMED), AlwaysOnBrightness.DIMMED, "dimmed is kept");
        Test.assertEqualMessage(AlwaysOnBrightness.levelOf(AlwaysOnBrightness.DIM), AlwaysOnBrightness.DIM, "dim is kept");
        return true;
    }


    // Brighter to dimmer in the order the menu lists them, and Dim is Lite's two thirds.
    (:test)
    static function eachLevelIsDimmerThanTheOneBefore(logger as Test.Logger) as Boolean {
        Test.assertEqual(AlwaysOnBrightness.SIXTHS.size(), AlwaysOnBrightness.DIM + 1);
        Test.assertEqual(AlwaysOnBrightness.sixthsOf(AlwaysOnBrightness.BRIGHT), 6);
        Test.assert(AlwaysOnBrightness.sixthsOf(AlwaysOnBrightness.DIMMED) < 6);
        Test.assert(AlwaysOnBrightness.sixthsOf(AlwaysOnBrightness.DIM) < AlwaysOnBrightness.sixthsOf(AlwaysOnBrightness.DIMMED));
        Test.assertEqual(AlwaysOnBrightness.sixthsOf(AlwaysOnBrightness.DIM) * 3, 6 * 2);
        return true;
    }


    // The whole path a change takes, App.onSettingsChanged to DigitalRain.applyColors, for
    // every level, with the default green: the woken time is untouched, and the always-on
    // one is the level's share of it.
    (:test)
    static function aSettingsChangeReachesTheAlwaysOnTime(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as App;
        var view = (app.getInitialView() as Array)[0] as View;
        var savedLevel = Properties.getValue(AlwaysOnBrightness.PROPERTY);
        var savedColor = Properties.getValue(TimeColor.PROPERTY);
        var expected = [0x00FF00, 0x00D400, LOW_POWER_TIME_COLOR];
        try {
            Properties.setValue(TimeColor.PROPERTY, TimeColor.GREEN);
            for (var level = AlwaysOnBrightness.BRIGHT; level <= AlwaysOnBrightness.DIM; ++level) {
                Properties.setValue(AlwaysOnBrightness.PROPERTY, level);
                app.onSettingsChanged();
                var drawn = view.digitalRain().timeColors();
                Test.assertEqualMessage(drawn[0], TIME_COLOR, "level " + level + " woken");
                Test.assertEqualMessage(drawn[1], expected[level], "level " + level + " always-on");
            }
        } finally {
            Properties.setValue(AlwaysOnBrightness.PROPERTY, savedLevel as Number);
            Properties.setValue(TimeColor.PROPERTY, savedColor as Number);
            app.onSettingsChanged();
        }
        return true;
    }

}
