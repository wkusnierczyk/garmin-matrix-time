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


    // The choice the draw follows, for every size and style: hollow S, M, L, XL and XXL are
    // drawn in their hollow fonts, and everything else is drawn filled, which is null here.
    (:test)
    static function hollowIsSmallAndAboveOnly(logger as Test.Logger) as Boolean {
        var filled = TimeStyle.FILLED;
        var hollow = TimeStyle.HOLLOW;
        Test.assertMessage(TimeStyle.hollowFont(TimeSize.SMALL, hollow) == Rez.Fonts.TimeLargeHollow,
            "hollow S is drawn in TimeLargeHollow");
        Test.assertMessage(TimeStyle.hollowFont(TimeSize.MEDIUM, hollow) == Rez.Fonts.TimeExtraLargeHollow,
            "hollow M is drawn in TimeExtraLargeHollow");
        Test.assertMessage(TimeStyle.hollowFont(TimeSize.LARGE, hollow) == Rez.Fonts.TimeExtraExtraLargeHollow,
            "hollow L is drawn in TimeExtraExtraLargeHollow");
        Test.assertMessage(TimeStyle.hollowFont(TimeSize.EXTRA_LARGE, hollow) == Rez.Fonts.TimeHugeHollow,
            "hollow XL is drawn in TimeHugeHollow");
        Test.assertMessage(TimeStyle.hollowFont(TimeSize.EXTRA_EXTRA_LARGE, hollow) == Rez.Fonts.TimeExtraHugeHollow,
            "hollow XXL is drawn in TimeExtraHugeHollow");
        Test.assertMessage(TimeStyle.hollowFont(TimeSize.EXTRA_EXTRA_SMALL, hollow) == null, "hollow XXS is drawn filled");
        Test.assertMessage(TimeStyle.hollowFont(TimeSize.EXTRA_SMALL, hollow) == null, "hollow XS is drawn filled");
        for (var size = TimeSize.EXTRA_EXTRA_SMALL; size <= TimeSize.EXTRA_EXTRA_LARGE; ++size) {
            Test.assertMessage(TimeStyle.hollowFont(size, filled) == null, "filled size " + size + " is drawn filled");
        }
        return true;
    }


    // A hollow font is its filled twin with the interior taken out, so swapping one for the
    // other must not move the time: the same height and the same width of the drawn time,
    // which is what centres it. tools/check-font-config.py compares every glyph's metrics
    // in every family; this checks the fonts as the device loads them.
    (:test)
    static function aHollowFontHasItsFilledTwinsMetrics(logger as Test.Logger) as Boolean {
        var dc = (Graphics.createBufferedBitmap({:width => 1, :height => 1}).get() as Graphics.BufferedBitmap).getDc();
        for (var size = TimeSize.SMALL; size <= TimeSize.EXTRA_EXTRA_LARGE; ++size) {
            var filled = TimeSize.load(size);
            var hollow = Application.loadResource(
                TimeStyle.hollowFont(size, TimeStyle.HOLLOW) as ResourceId) as Graphics.FontType;
            var text = "12:34";
            logger.debug("size " + size + ": filled " + Graphics.getFontHeight(filled) + " x "
                + dc.getTextWidthInPixels(text, filled) + " px, hollow " + Graphics.getFontHeight(hollow)
                + " x " + dc.getTextWidthInPixels(text, hollow) + " px");
            Test.assertEqualMessage(Graphics.getFontHeight(hollow), Graphics.getFontHeight(filled),
                "size " + size + ": hollow is as tall as filled");
            Test.assertEqualMessage(dc.getTextWidthInPixels(text, hollow), dc.getTextWidthInPixels(text, filled),
                "size " + size + ": hollow is as wide as filled");
        }
        return true;
    }


    // The whole path a change takes, App.onSettingsChanged to DigitalRain.reloadTimeFont,
    // and what it decides: hollow S and above drop the box, everything else keeps it.
    (:test)
    static function hollowDropsTheBoxAtSmallAndAboveOnly(logger as Test.Logger) as Boolean {
        var none = Graphics.COLOR_TRANSPARENT;
        var box = Graphics.COLOR_BLACK;
        Test.assertEqualMessage(drawnWith(TimeSize.EXTRA_EXTRA_LARGE, TimeStyle.HOLLOW)[1], none, "hollow XXL: no box");
        Test.assertEqualMessage(drawnWith(TimeSize.EXTRA_LARGE, TimeStyle.HOLLOW)[1], none, "hollow XL: no box");
        Test.assertEqualMessage(drawnWith(TimeSize.LARGE, TimeStyle.HOLLOW)[1], none, "hollow L: no box");
        Test.assertEqualMessage(drawnWith(TimeSize.MEDIUM, TimeStyle.HOLLOW)[1], none, "hollow M: no box");
        Test.assertEqualMessage(drawnWith(TimeSize.SMALL, TimeStyle.HOLLOW)[1], none, "hollow S: no box");
        Test.assertEqualMessage(drawnWith(TimeSize.EXTRA_SMALL, TimeStyle.HOLLOW)[1], box, "hollow XS: filled, on the box");
        Test.assertEqualMessage(drawnWith(TimeSize.EXTRA_EXTRA_SMALL, TimeStyle.HOLLOW)[1], box, "hollow XXS: filled, on the box");
        Test.assertEqualMessage(drawnWith(TimeSize.MEDIUM, TimeStyle.FILLED)[1], box, "filled M: on the box");
        Test.assertEqualMessage(drawnWith(TimeSize.EXTRA_EXTRA_LARGE, TimeStyle.FILLED)[1], box, "filled XXL: on the box");
        return true;
    }


    // The style changes the font, never the size.
    (:test)
    static function hollowKeepsTheSelectedSize(logger as Test.Logger) as Boolean {
        for (var size = TimeSize.EXTRA_EXTRA_SMALL; size <= TimeSize.EXTRA_EXTRA_LARGE; ++size) {
            var filled = drawnWith(size, TimeStyle.FILLED)[0];
            var hollow = drawnWith(size, TimeStyle.HOLLOW)[0];
            Test.assertEqualMessage(hollow, filled, "size " + size + ": the same height either style");
        }
        return true;
    }

}
