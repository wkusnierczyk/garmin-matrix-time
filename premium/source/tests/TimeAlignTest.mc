using Toybox.Application;
using Toybox.Application.Properties;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Test;
using Toybox.Time;

import Toybox.Lang;


// Stands in for the screen's Dc and records the last drawText, which is the time in both
// scenes: draw paints the rain first and the time over it, and drawLowPower draws nothing
// else. Everything else goes to a real Dc, which answers the font metrics the grid is built
// from; that one is small, so the rain is clipped, for the reason DigitalRainTest gives.
(:test)
class RecordingDc {

    private var _dc as Graphics.Dc;

    var x as Number = -1;
    var justify as Number = -1;

    function initialize() {
        var bitmap = Graphics.createBufferedBitmap({:width => 64, :height => 64}).get() as Graphics.BufferedBitmap;
        _dc = bitmap.getDc();
    }

    function setColor(foreground as Graphics.ColorType, background as Graphics.ColorType) as Void {
        _dc.setColor(foreground, background);
    }

    function drawText(x as Numeric, y as Numeric, font as Graphics.FontType, text as String, justify as Number) as Void {
        self.x = x as Number;
        self.justify = justify;
        _dc.drawText(x, y, font, text, justify);
    }

    function getFontHeight(font as Graphics.FontType) as Number {
        return _dc.getFontHeight(font);
    }

    function getTextWidthInPixels(text as String, font as Graphics.FontType) as Number {
        return _dc.getTextWidthInPixels(text, font);
    }

}


// The time alignment setting (#154). Premium only, like the property.
(:test)
class TimeAlignTest {

    // Applies an alignment, size and style the way Connect IQ does, draws one frame of the
    // woken or the always-on scene, and returns what the time was drawn with: [x, justify,
    // the woken font's height]. Puts back what was stored, for the reason
    // TimeSizeTest.selectedWith gives.
    private static function drawnWith(align as Number, size as Number, style as Number, lowPower as Boolean)
            as Array<Number> {
        var app = Application.getApp() as App;
        var view = (app.getInitialView() as Array)[0] as View;
        var saved = [
            Properties.getValue(TimeAlign.PROPERTY),
            Properties.getValue(TimeSize.PROPERTY),
            Properties.getValue(TimeStyle.PROPERTY)
        ];

        Properties.setValue(TimeAlign.PROPERTY, align);
        Properties.setValue(TimeSize.PROPERTY, size);
        Properties.setValue(TimeStyle.PROPERTY, style);
        app.onSettingsChanged();
        var rain = view.digitalRain().forTime(new Time.Moment(0));
        var dc = new RecordingDc();
        if (lowPower) {
            rain.drawLowPower(dc as Graphics.Dc);
        } else {
            rain.draw(dc as Graphics.Dc);
        }
        var drawn = [dc.x, dc.justify, Graphics.getFontHeight(rain.timeFont())] as Array<Number>;

        Properties.setValue(TimeAlign.PROPERTY, saved[0] as Number);
        Properties.setValue(TimeSize.PROPERTY, saved[1] as Number);
        Properties.setValue(TimeStyle.PROPERTY, saved[2] as Number);
        app.onSettingsChanged();
        return drawn;
    }

    // Whether a point is on this screen's glass: inside the circle on a round screen, and
    // inside the circle the margin is taken from on a rectangular one, which is stricter.
    private static function onTheGlass(x as Number, y as Number) as Boolean {
        var settings = System.getDeviceSettings();
        var width = settings.screenWidth;
        var height = settings.screenHeight;
        var radius = (width < height ? width : height) / 2;
        var dx = x - width / 2;
        var dy = y - height / 2;
        return dx * dx + dy * dy <= radius * radius;
    }


    // Joins Lite's property table, as TimeSizeTest checks for timeSize (#91).
    (:test)
    static function thePropertyIsDeclared(logger as Test.Logger) as Boolean {
        var align = PropertyUtils.getPropertyElseDefault(TimeAlign.PROPERTY, "not declared");
        Test.assertMessage(align instanceof Lang.Number, "timeAlign is declared, but got: " + align);
        return true;
    }


    (:test)
    static function anythingButTheThreeIsCentred(logger as Test.Logger) as Boolean {
        Test.assertEqualMessage(TimeAlign.alignOf(TimeAlign.LEFT), TimeAlign.LEFT, "0 is left");
        Test.assertEqualMessage(TimeAlign.alignOf(TimeAlign.CENTER), TimeAlign.CENTER, "1 is centre");
        Test.assertEqualMessage(TimeAlign.alignOf(TimeAlign.RIGHT), TimeAlign.RIGHT, "2 is right");
        Test.assertEqualMessage(TimeAlign.alignOf(3), TimeAlign.CENTER, "3 falls back to centre");
        Test.assertEqualMessage(TimeAlign.alignOf(-1), TimeAlign.CENTER, "-1 falls back to centre");
        Test.assertEqualMessage(TimeAlign.alignOf(null), TimeAlign.CENTER, "null falls back to centre");
        Test.assertEqualMessage(TimeAlign.alignOf("0"), TimeAlign.CENTER, "a String falls back to centre");
        Test.assertEqualMessage(TimeAlign.alignOf(0.0f), TimeAlign.CENTER, "a Float falls back to centre");
        return true;
    }


    // The chord, worked by hand: XL at 416x416 is 86 pixels tall, so its corners are 43 above
    // and below the centre, where the circle of radius 208 is 2 * 203.5 wide. Rounded up, the
    // inset is 5, and the gap a quarter of 86, 21, puts the box 26 in. A box as tall as the
    // screen has nowhere to go but the middle.
    (:test)
    static function theMarginIsWhereTheCircleCrossesTheBox(logger as Test.Logger) as Boolean {
        Test.assertEqual(TimeAlign.inset(208, 86), 5);
        Test.assertEqual(TimeAlign.inset(208, 85), 5);
        Test.assertEqual(TimeAlign.inset(208, 0), 0);
        Test.assertEqual(TimeAlign.inset(208, 416), 208);
        Test.assertEqual(TimeAlign.xOf(TimeAlign.CENTER, 416, 416, 86), 208);
        Test.assertEqual(TimeAlign.xOf(TimeAlign.LEFT, 416, 416, 86), 26);
        Test.assertEqual(TimeAlign.xOf(TimeAlign.RIGHT, 416, 416, 86), 390);
        // A rectangle takes the circle across its narrower side, centred on the screen.
        Test.assertEqual(TimeAlign.xOf(TimeAlign.LEFT, 448, 486, 86), TimeAlign.inset(224, 86) + 21);
        Test.assertEqual(TimeAlign.xOf(TimeAlign.RIGHT, 448, 486, 86), 448 - TimeAlign.inset(224, 86) - 21);
        return true;
    }


    // The box drawText fills, for every time font on this product, left and right: all four
    // corners on the glass, and at least a quarter of a cell clear of where they would
    // touch it. GAP_DIVISOR aims at half a cell; this catches the gap being lost, not its
    // exact size, which depends on the font's proportions. Every glyph cell is that whole box (tools/check-font-config.py),
    // so no pixel of a digit is off it either. CI runs this on one product; the other
    // families are run by hand, and the PR for #154 records them.
    (:test)
    static function everyTimeFontStaysOnTheGlass(logger as Test.Logger) as Boolean {
        var settings = System.getDeviceSettings();
        var width = settings.screenWidth;
        var height = settings.screenHeight;
        var radius = (width < height ? width : height) / 2;
        var dc = new RecordingDc();
        for (var size = TimeSize.SMALL; size <= TimeSize.EXTRA_EXTRA_LARGE; ++size) {
            for (var style = TimeStyle.FILLED; style <= TimeStyle.HOLLOW; ++style) {
                var id = TimeStyle.hollowFont(size, style);
                var font = id == null ? TimeSize.load(size) : Application.loadResource(id) as Graphics.FontType;
                var fontHeight = Graphics.getFontHeight(font);
                var boxWidth = dc.getTextWidthInPixels("12:34", font);
                var top = height / 2 - (fontHeight + 1) / 2;
                var bottom = height / 2 + (fontHeight + 1) / 2;
                var left = TimeAlign.xOf(TimeAlign.LEFT, width, height, fontHeight);
                var right = TimeAlign.xOf(TimeAlign.RIGHT, width, height, fontHeight);
                logger.debug(width + "x" + height + " size " + size + " style " + style + ": "
                    + boxWidth + " x " + fontHeight + " px, margin " + left);
                var boxes = [[left, left + boxWidth], [right - boxWidth, right]] as Array<Array<Number>>;
                for (var i = 0; i < boxes.size(); ++i) {
                    var box = boxes[i];
                    var where = "size " + size + ", style " + style + (i == 0 ? ", left" : ", right");
                    Test.assertMessage(onTheGlass(box[0], top) && onTheGlass(box[0], bottom)
                        && onTheGlass(box[1], top) && onTheGlass(box[1], bottom), where + ": the box is on the glass");
                    var outside = i == 0 ? box[0] - (width / 2 - radius) : (width / 2 + radius) - box[1];
                    var gap = outside - TimeAlign.inset(radius, fontHeight);
                    Test.assertMessage(4 * gap >= boxWidth / 5, where + ": " + gap + " px clear of the circle");
                }
            }
        }
        return true;
    }


    // The whole path a change takes, App.onSettingsChanged to the drawText the time is drawn
    // with: the anchor follows the setting, and the margin follows the time size.
    (:test)
    static function theWokenTimeIsDrawnWhereTheSettingSays(logger as Test.Logger) as Boolean {
        var width = System.getDeviceSettings().screenWidth;
        var height = System.getDeviceSettings().screenHeight;
        var filled = TimeStyle.FILLED;
        for (var size = TimeSize.SMALL; size <= TimeSize.EXTRA_EXTRA_LARGE; ++size) {
            var left = drawnWith(TimeAlign.LEFT, size, filled, false);
            var center = drawnWith(TimeAlign.CENTER, size, filled, false);
            var right = drawnWith(TimeAlign.RIGHT, size, filled, false);
            Test.assertEqualMessage(left[0], TimeAlign.xOf(TimeAlign.LEFT, width, height, left[2]), "size " + size + ": left x");
            Test.assertEqualMessage(center[0], width / 2, "size " + size + ": centre x");
            Test.assertEqualMessage(right[0], TimeAlign.xOf(TimeAlign.RIGHT, width, height, right[2]), "size " + size + ": right x");
            Test.assertEqualMessage(left[1], Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER, "size " + size + ": left anchor");
            Test.assertEqualMessage(center[1], JUSTIFY, "size " + size + ": centre anchor");
            Test.assertEqualMessage(right[1], Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER, "size " + size + ": right anchor");
        }
        var small = drawnWith(TimeAlign.LEFT, TimeSize.SMALL, filled, false)[0];
        var extraLarge = drawnWith(TimeAlign.LEFT, TimeSize.EXTRA_LARGE, filled, false)[0];
        Test.assertMessage(extraLarge > small, "a taller time sits further in: S at " + small + ", XL at " + extraLarge);
        return true;
    }


    // The always-on time ignores the setting: centred at every alignment, shifted by the
    // jitter alone, so the burn-in measurement stands (#145, #153).
    (:test)
    static function theAlwaysOnTimeStaysCentred(logger as Test.Logger) as Boolean {
        var width = System.getDeviceSettings().screenWidth;
        var expected = width / 2 + RainMath.jitter(0, width)[0];
        for (var align = TimeAlign.LEFT; align <= TimeAlign.RIGHT; ++align) {
            var drawn = drawnWith(align, TimeSize.EXTRA_LARGE, TimeStyle.FILLED, true);
            Test.assertEqualMessage(drawn[0], expected, "alignment " + align + ": the always-on time is at the centre");
            Test.assertEqualMessage(drawn[1], JUSTIFY, "alignment " + align + ": the always-on time is centred");
        }
        return true;
    }

}
