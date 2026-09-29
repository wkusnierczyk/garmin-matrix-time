using Toybox.Application;
using Toybox.Application.Properties;
using Toybox.Graphics;
using Toybox.Test;

import Toybox.Lang;


// The time style setting (#72). Premium only, like the hollow fonts and the property.
(:test)
class TimeStyleTest {

    // Sets both settings the style depends on, applies them the way Connect IQ does, and
    // returns what the face now draws the time with: [font height, background]. Puts back
    // what was stored, for the reason TimeSizeTest.selectedWith gives.
    private static function drawnWith(size as Number, style as Number) as Array<Number> {
        var app = Application.getApp() as App;
        var view = (app.getInitialView() as Array)[0] as View;
        var savedSize = Properties.getValue(TimeSize.PROPERTY);
        var savedStyle = Properties.getValue(TimeStyle.PROPERTY);

        Properties.setValue(TimeSize.PROPERTY, size);
        Properties.setValue(TimeStyle.PROPERTY, style);
        app.onSettingsChanged();
        var rain = view.digitalRain();
        var drawn = [Graphics.getFontHeight(rain.timeFont()), rain.timeBackground() as Number] as Array<Number>;

        Properties.setValue(TimeSize.PROPERTY, savedSize as Number);
        Properties.setValue(TimeStyle.PROPERTY, savedStyle as Number);
        app.onSettingsChanged();
        return drawn;
    }


    // Joins Lite's property table, as TimeSizeTest checks for timeSize (#91).
    (:test)
    static function thePropertyIsDeclared(logger as Test.Logger) as Boolean {
        var style = PropertyUtils.getPropertyElseDefault(TimeStyle.PROPERTY, "not declared");
        Test.assertMessage(style instanceof Lang.Number, "timeStyle is declared, but got: " + style);
        return true;
    }


    (:test)
    static function anythingButHollowIsFilled(logger as Test.Logger) as Boolean {
        Test.assertEqualMessage(TimeStyle.styleOf(TimeStyle.HOLLOW), TimeStyle.HOLLOW, "1 is hollow");
        Test.assertEqualMessage(TimeStyle.styleOf(TimeStyle.FILLED), TimeStyle.FILLED, "0 is filled");
        Test.assertEqualMessage(TimeStyle.styleOf(2), TimeStyle.FILLED, "2 falls back to filled");
        Test.assertEqualMessage(TimeStyle.styleOf(-1), TimeStyle.FILLED, "-1 falls back to filled");
        Test.assertEqualMessage(TimeStyle.styleOf(null), TimeStyle.FILLED, "null falls back to filled");
        Test.assertEqualMessage(TimeStyle.styleOf("1"), TimeStyle.FILLED, "a String falls back to filled");
        Test.assertEqualMessage(TimeStyle.styleOf(true), TimeStyle.FILLED, "a Boolean falls back to filled");
        return true;
    }


    // S and M have no hollow font; L and XL do.
    (:test)
    static function onlyLargeAndExtraLargeHaveAHollowFont(logger as Test.Logger) as Boolean {
        Test.assertMessage(TimeStyle.loadHollow(TimeSize.SMALL) == null, "S has no hollow font");
        Test.assertMessage(TimeStyle.loadHollow(TimeSize.MEDIUM) == null, "M has no hollow font");
        Test.assertMessage(TimeStyle.loadHollow(TimeSize.LARGE) != null, "L has a hollow font");
        Test.assertMessage(TimeStyle.loadHollow(TimeSize.EXTRA_LARGE) != null, "XL has a hollow font");
        return true;
    }


    // A hollow font is its filled twin with the interior taken out, so swapping one for the
    // other must not move the time: the same height, on every resolution the suite runs on.
    (:test)
    static function aHollowFontHasItsFilledTwinsMetrics(logger as Test.Logger) as Boolean {
        var large = Application.loadResource(Rez.Fonts.TimeLarge) as Graphics.FontType;
        for (var size = TimeSize.LARGE; size <= TimeSize.EXTRA_LARGE; ++size) {
            var filled = Graphics.getFontHeight(TimeSize.load(size, large));
            var hollow = Graphics.getFontHeight(TimeStyle.loadHollow(size) as Graphics.FontType);
            logger.debug("size " + size + ": filled " + filled + " px, hollow " + hollow + " px");
            Test.assertEqualMessage(hollow, filled, "size " + size + ": hollow is as tall as filled");
        }
        return true;
    }


    // The whole path a change takes, App.onSettingsChanged to DigitalRain.reloadTimeFont,
    // and what it decides: hollow L and XL drop the box, everything else keeps it.
    (:test)
    static function hollowDropsTheBoxAtLargeAndExtraLargeOnly(logger as Test.Logger) as Boolean {
        var none = Graphics.COLOR_TRANSPARENT;
        var box = Graphics.COLOR_BLACK;
        Test.assertEqualMessage(drawnWith(TimeSize.EXTRA_LARGE, TimeStyle.HOLLOW)[1], none, "hollow XL: no box");
        Test.assertEqualMessage(drawnWith(TimeSize.LARGE, TimeStyle.HOLLOW)[1], none, "hollow L: no box");
        Test.assertEqualMessage(drawnWith(TimeSize.MEDIUM, TimeStyle.HOLLOW)[1], box, "hollow M: filled, on the box");
        Test.assertEqualMessage(drawnWith(TimeSize.SMALL, TimeStyle.HOLLOW)[1], box, "hollow S: filled, on the box");
        Test.assertEqualMessage(drawnWith(TimeSize.EXTRA_LARGE, TimeStyle.FILLED)[1], box, "filled XL: on the box");
        return true;
    }


    // The style changes the font, never the size.
    (:test)
    static function hollowKeepsTheSelectedSize(logger as Test.Logger) as Boolean {
        for (var size = TimeSize.SMALL; size <= TimeSize.EXTRA_LARGE; ++size) {
            var filled = drawnWith(size, TimeStyle.FILLED)[0];
            var hollow = drawnWith(size, TimeStyle.HOLLOW)[0];
            Test.assertEqualMessage(hollow, filled, "size " + size + ": the same height either style");
        }
        return true;
    }

}
