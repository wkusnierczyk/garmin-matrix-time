using Toybox.Application;
using Toybox.Application.Properties;
using Toybox.Test;

import Toybox.Lang;


// The time colour setting (#143). Premium only, like the property it reads.
(:test)
class TimeColorTest {

    // Joins Lite's property table, as TimeSizeTest checks for timeSize (#91).
    (:test)
    static function thePropertyIsDeclared(logger as Test.Logger) as Boolean {
        var color = PropertyUtils.getPropertyElseDefault(TimeColor.PROPERTY, "not declared");
        Test.assertMessage(color instanceof Lang.Number, "timeColor is declared, but got: " + color);
        return true;
    }


    (:test)
    static function greenIsLitesColourAwakeAndAlwaysOn(logger as Test.Logger) as Boolean {
        Test.assertEqual(TimeColor.colorOf(TimeColor.GREEN), TIME_COLOR);
        Test.assertEqual(TimeColor.lowPowerOf(TIME_COLOR), LOW_POWER_TIME_COLOR);
        return true;
    }


    (:test)
    static function anythingButAnIndexIsGreen(logger as Test.Logger) as Boolean {
        Test.assertEqualMessage(TimeColor.indexOf(null), TimeColor.GREEN, "null");
        Test.assertEqualMessage(TimeColor.indexOf(-1), TimeColor.GREEN, "-1");
        Test.assertEqualMessage(TimeColor.indexOf(TimeColor.COLORS.size()), TimeColor.GREEN, "one past the end");
        Test.assertEqualMessage(TimeColor.indexOf("1"), TimeColor.GREEN, "a String");
        Test.assertEqualMessage(TimeColor.indexOf(1.0f), TimeColor.GREEN, "a Float");
        Test.assertEqualMessage(TimeColor.indexOf(TimeColor.COLORS.size() - 1), TimeColor.COLORS.size() - 1, "the last index is kept");
        return true;
    }


    // Channel by channel, truncating: 0xFF is 0xAA and 0x80 is 0x55.
    (:test)
    static function alwaysOnIsTwoThirdsOfEachChannel(logger as Test.Logger) as Boolean {
        Test.assertEqual(TimeColor.lowPowerOf(0xFFFFFF), 0xAAAAAA);
        Test.assertEqual(TimeColor.lowPowerOf(0xFF8000), 0xAA5500);
        Test.assertEqual(TimeColor.lowPowerOf(0x000000), 0x000000);
        return true;
    }


    // The whole path a change takes, App.onSettingsChanged to DigitalRain.applyColors, for
    // every colour offered, woken and always-on.
    (:test)
    static function aSettingsChangeReachesTheTimeDrawn(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as App;
        var view = (app.getInitialView() as Array)[0] as View;
        var saved = Properties.getValue(TimeColor.PROPERTY);
        try {
            for (var i = 0; i < TimeColor.COLORS.size(); ++i) {
                Properties.setValue(TimeColor.PROPERTY, i);
                app.onSettingsChanged();
                var drawn = view.digitalRain().timeColors();
                Test.assertEqualMessage(drawn[0], TimeColor.COLORS[i], "colour " + i + " woken");
                Test.assertEqualMessage(drawn[1], TimeColor.lowPowerOf(TimeColor.COLORS[i]), "colour " + i + " always-on");
            }
        } finally {
            Properties.setValue(TimeColor.PROPERTY, saved as Number);
            app.onSettingsChanged();
        }
        return true;
    }

}
