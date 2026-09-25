using Toybox.Application;
using Toybox.Application.Properties;
using Toybox.Graphics;
using Toybox.Test;

import Toybox.Lang;


// The time size setting (#32). Premium only, like the fonts and the property it reads.
(:test)
class TimeSizeTest {

    // Sets timeSize for the length of one check and puts back what was there. The simulator
    // keeps the property table in GARMIN/APPS/SETTINGS/<APPNAME>.SET across runs, so a value
    // left behind would leak into the next run of the suite, and into the face itself.
    private static function selectedWith(value as Number) as Number {
        var saved = Properties.getValue(TimeSize.PROPERTY);
        Properties.setValue(TimeSize.PROPERTY, value);
        var selected = TimeSize.selected();
        Properties.setValue(TimeSize.PROPERTY, saved as Number);
        return selected;
    }


    // premium/resources-base/properties/properties.xml has to join Lite's property table,
    // not replace it: without the settingsSchema marker the table could still be empty in
    // some future Lite, and an empty one takes the app down (#91). Both keys resolving to
    // Numbers, rather than to the String defaults, is the proof the two files merged.
    (:test)
    static function thePremiumPropertyJoinsLitesTable(logger as Test.Logger) as Boolean {
        var size = PropertyUtils.getPropertyElseDefault(TimeSize.PROPERTY, "not declared");
        var marker = PropertyUtils.getPropertyElseDefault("settingsSchema", "not declared");
        Test.assertMessage(size instanceof Lang.Number, "timeSize is declared, but got: " + size);
        Test.assertMessage(marker instanceof Lang.Number, "settingsSchema survives, but got: " + marker);
        return true;
    }


    (:test)
    static function eachOfTheFourSizesIsKept(logger as Test.Logger) as Boolean {
        for (var size = TimeSize.SMALL; size <= TimeSize.EXTRA_LARGE; ++size) {
            Test.assertEqualMessage(selectedWith(size), size, "size " + size + " is selected as stored");
        }
        return true;
    }


    // A value no listEntry offers can still arrive -- from a settings file written by some
    // other version, or by hand. It falls back to S, Lite's size, rather than to nothing.
    (:test)
    static function anOutOfRangeSizeFallsBackToSmall(logger as Test.Logger) as Boolean {
        Test.assertEqualMessage(selectedWith(-1), TimeSize.SMALL, "-1 falls back to S");
        Test.assertEqualMessage(selectedWith(4), TimeSize.SMALL, "4 falls back to S");
        return true;
    }


    // L is the always-on font the caller already holds, not a second copy of it.
    (:test)
    static function largeReusesTheFontItIsHanded(logger as Test.Logger) as Boolean {
        var large = Application.loadResource(Rez.Fonts.TimeLarge) as Graphics.FontType;
        Test.assertMessage(TimeSize.load(TimeSize.LARGE, large) == large, "L is the font handed in");
        return true;
    }


    // The ladder is 27, 40, 54, 68 at the reference; on every family the scaler has to
    // keep it a ladder. Heights rather than point sizes, because heights are what can be
    // read back from a loaded font.
    (:test)
    static function theFourSizesGrow(logger as Test.Logger) as Boolean {
        var large = Application.loadResource(Rez.Fonts.TimeLarge) as Graphics.FontType;
        var previous = 0;
        for (var size = TimeSize.SMALL; size <= TimeSize.EXTRA_LARGE; ++size) {
            var height = Graphics.getFontHeight(TimeSize.load(size, large));
            logger.debug("size " + size + ": " + height + " px");
            Test.assertMessage(height > previous, "size " + size + " is taller than the one below it");
            previous = height;
        }
        return true;
    }

}
