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
    static function eachOfTheSevenSizesIsKept(logger as Test.Logger) as Boolean {
        for (var size = TimeSize.EXTRA_EXTRA_SMALL; size <= TimeSize.EXTRA_EXTRA_LARGE; ++size) {
            Test.assertEqualMessage(selectedWith(size), size, "size " + size + " is selected as stored");
        }
        return true;
    }


    // A value no listEntry offers can still arrive -- from a settings file written by some
    // other version, or by hand. It falls back to M, the default, rather than to nothing
    // (#155).
    (:test)
    static function anOutOfRangeSizeFallsBackToMedium(logger as Test.Logger) as Boolean {
        Test.assertEqualMessage(selectedWith(-1), TimeSize.MEDIUM, "-1 falls back to M");
        Test.assertEqualMessage(selectedWith(7), TimeSize.MEDIUM, "7 falls back to M");
        return true;
    }


    // XL and XXL were appended as 5 and 6 (#166), so that a value stored before they existed
    // still draws the font it did, under its new name: 0, once S, is XXS, in Time, and 4,
    // once XXL, is L, in TimeExtraExtraLarge. The default, 3, once XL, is M. Heights stand
    // for the fonts, as in theSevenSizesGrow, and no two sizes share one.
    (:test)
    static function aStoredSizeKeepsItsFont(logger as Test.Logger) as Boolean {
        var fonts = [
            Rez.Fonts.Time,
            Rez.Fonts.TimeMedium,
            Rez.Fonts.TimeLarge,
            Rez.Fonts.TimeExtraLarge,
            Rez.Fonts.TimeExtraExtraLarge,
            Rez.Fonts.TimeHuge,
            Rez.Fonts.TimeExtraHuge
        ] as Array<ResourceId>;
        for (var value = 0; value < fonts.size(); ++value) {
            var expected = Application.loadResource(fonts[value]) as Graphics.FontType;
            Test.assertEqualMessage(Graphics.getFontHeight(TimeSize.load(TimeSize.sizeOf(value))),
                Graphics.getFontHeight(expected), "stored " + value + " draws its font");
        }
        return true;
    }


    (:test)
    static function aValueOfTheWrongTypeFallsBackToMedium(logger as Test.Logger) as Boolean {
        Test.assertEqualMessage(TimeSize.sizeOf(null), TimeSize.MEDIUM, "null falls back to M");
        Test.assertEqualMessage(TimeSize.sizeOf("2"), TimeSize.MEDIUM, "a String falls back to M");
        Test.assertEqualMessage(TimeSize.sizeOf(2.0f), TimeSize.MEDIUM, "a Float falls back to M");
        Test.assertEqualMessage(TimeSize.sizeOf(true), TimeSize.MEDIUM, "a Boolean falls back to M");
        Test.assertEqualMessage(TimeSize.sizeOf(2), TimeSize.SMALL, "the Number 2 is S");
        return true;
    }


    // The whole path a change in Connect IQ takes: App.onSettingsChanged, View.applySettings,
    // DigitalRain.reloadTimeFont. Without it a size change would do nothing until the face
    // restarted, and every other test here would still pass.
    (:test)
    static function aSettingsChangeReachesTheFontDrawn(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as App;
        var view = (app.getInitialView() as Array)[0] as View;
        var saved = Properties.getValue(TimeSize.PROPERTY);

        Properties.setValue(TimeSize.PROPERTY, TimeSize.EXTRA_EXTRA_SMALL);
        app.onSettingsChanged();
        var smallest = Graphics.getFontHeight(view.digitalRain().timeFont());

        Properties.setValue(TimeSize.PROPERTY, TimeSize.EXTRA_EXTRA_LARGE);
        app.onSettingsChanged();
        var largest = Graphics.getFontHeight(view.digitalRain().timeFont());

        Properties.setValue(TimeSize.PROPERTY, saved as Number);
        logger.debug("XXS " + smallest + " px, XXL " + largest + " px");
        Test.assertMessage(largest > smallest, "changing the setting to XXL makes the drawn time taller");
        return true;
    }


    // The ladder is 27, 40, 54, 68, 82, 96, 110 at the reference; on every family the scaler has to
    // keep it a ladder. Heights rather than point sizes, because heights are what can be
    // read back from a loaded font.
    (:test)
    static function theSevenSizesGrow(logger as Test.Logger) as Boolean {
        var previous = 0;
        for (var size = TimeSize.EXTRA_EXTRA_SMALL; size <= TimeSize.EXTRA_EXTRA_LARGE; ++size) {
            var height = Graphics.getFontHeight(TimeSize.load(size));
            logger.debug("size " + size + ": " + height + " px");
            Test.assertMessage(height > previous, "size " + size + " is taller than the one below it");
            previous = height;
        }
        return true;
    }

}
