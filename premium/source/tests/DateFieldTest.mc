using Toybox.Application;
using Toybox.Application.Properties;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Test;
using Toybox.Time;

import Toybox.Lang;


// The date under the woken time (#163). Premium only, like the property.
(:test)
class DateFieldTest {

    // Applies the date switch, alignment and size the way Connect IQ does, draws one frame of
    // the woken or the always-on scene into a RecordingDc, and returns it with the date and
    // time fonts that frame was drawn with, read before the settings are put back. Puts back
    // what was stored, for the reason TimeSizeTest.selectedWith gives.
    private static function drawnWith(date as Number, align as Number, size as Number, lowPower as Boolean)
            as [RecordingDc, Graphics.FontType or Null, Graphics.FontType] {
        var app = Application.getApp() as App;
        var view = (app.getInitialView() as Array)[0] as View;
        var saved = [
            Properties.getValue(DateField.PROPERTY),
            Properties.getValue(TimeAlign.PROPERTY),
            Properties.getValue(TimeSize.PROPERTY)
        ];

        Properties.setValue(DateField.PROPERTY, date);
        Properties.setValue(TimeAlign.PROPERTY, align);
        Properties.setValue(TimeSize.PROPERTY, size);
        app.onSettingsChanged();
        var rain = view.digitalRain().forTime(new Time.Moment(0));
        var dc = new RecordingDc();
        if (lowPower) {
            rain.drawLowPower(dc as Graphics.Dc);
        } else {
            rain.draw(dc as Graphics.Dc);
        }
        var fonts = [rain.dateFont(), rain.timeFont()];

        Properties.setValue(DateField.PROPERTY, saved[0] as Number);
        Properties.setValue(TimeAlign.PROPERTY, saved[1] as Number);
        Properties.setValue(TimeSize.PROPERTY, saved[2] as Number);
        app.onSettingsChanged();
        return [dc, fonts[0], fonts[1] as Graphics.FontType];
    }

    // Applies the date switch, alignment and size the way Connect IQ does, draws one woken
    // frame, and returns [the time's x, the date's x], the date's -1 while it is off. The
    // time's is read from timePlacement, since with the date on the last drawText is the
    // date's; TimeAlignTest checks that the time is drawn at it.
    private static function placedWith(date as Number, align as Number, size as Number) as Array<Number> {
        var app = Application.getApp() as App;
        var view = (app.getInitialView() as Array)[0] as View;
        var saved = [
            Properties.getValue(DateField.PROPERTY),
            Properties.getValue(TimeAlign.PROPERTY),
            Properties.getValue(TimeSize.PROPERTY)
        ];

        Properties.setValue(DateField.PROPERTY, date);
        Properties.setValue(TimeAlign.PROPERTY, align);
        Properties.setValue(TimeSize.PROPERTY, size);
        app.onSettingsChanged();
        var rain = view.digitalRain().forTime(new Time.Moment(0));
        var dc = new RecordingDc();
        rain.draw(dc as Graphics.Dc);
        var placed = [rain.timePlacement()[0], date == DateField.ON ? dc.x : -1] as Array<Number>;

        Properties.setValue(DateField.PROPERTY, saved[0] as Number);
        Properties.setValue(TimeAlign.PROPERTY, saved[1] as Number);
        Properties.setValue(TimeSize.PROPERTY, saved[2] as Number);
        app.onSettingsChanged();
        return placed;
    }

    // As TimeAlignTest.onTheGlass.
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
        var date = PropertyUtils.getPropertyElseDefault(DateField.PROPERTY, "not declared");
        Test.assertMessage(date instanceof Lang.Number, "date is declared, but got: " + date);
        return true;
    }


    (:test)
    static function anythingButOneIsOff(logger as Test.Logger) as Boolean {
        Test.assertEqualMessage(DateField.showOf(DateField.OFF), DateField.OFF, "0 is off");
        Test.assertEqualMessage(DateField.showOf(DateField.ON), DateField.ON, "1 is on");
        Test.assertEqualMessage(DateField.showOf(2), DateField.OFF, "2 falls back to off");
        Test.assertEqualMessage(DateField.showOf(-1), DateField.OFF, "-1 falls back to off");
        Test.assertEqualMessage(DateField.showOf(null), DateField.OFF, "null falls back to off");
        Test.assertEqualMessage(DateField.showOf("1"), DateField.OFF, "a String falls back to off");
        Test.assertEqualMessage(DateField.showOf(true), DateField.OFF, "a Boolean falls back to off");
        return true;
    }


    (:test)
    static function theDateIsIsoAndZeroPadded(logger as Test.Logger) as Boolean {
        Test.assertEqual(DateField.textOf(2026, 9, 5), "2026-09-05");
        Test.assertEqual(DateField.textOf(2026, 12, 31), "2026-12-31");
        Test.assertEqual(DateField.textOf(2027, 1, 1), "2027-01-01");
        return true;
    }


    // Worked by hand at 416x416, radius 208, with XXS's 35-pixel line under a time of the
    // given height. Under an XXS time (35 px, at x 9 when left-aligned) the date's box is
    // centred at 244 and reaches 54 below the centre, where the inset is 8 and the gap a
    // quarter of 35 more, 16: the glass is narrower there, so the date sits further in than
    // the time. Under an L time (104 px, at x 33) it reaches 88 below, needs only 28, and
    // sits flush with the time. Under an XXL time (139 px, at x 47), the largest (#166), it
    // is centred at 296 and reaches 106 below, needs 38, and is flush too, its bottom at 314.
    (:test)
    static function theDateIsFlushWithTheTimeWhereTheGlassAllows(logger as Test.Logger) as Boolean {
        Test.assertEqual(TimeAlign.insetAt(208, 54), 8);
        Test.assertEqual(TimeAlign.insetAt(208, 88), 20);
        Test.assertEqual(TimeAlign.insetAt(208, 106), 30);
        Test.assertEqual(TimeAlign.insetAt(208, 208), 208);
        Test.assertEqual(DateField.yOf(416, 35, 35), 244);
        Test.assertEqual(DateField.yOf(416, 104, 35), 278);
        Test.assertEqual(DateField.yOf(416, 139, 35), 296);
        Test.assertEqual(TimeAlign.xOf(TimeAlign.LEFT, 416, 416, 139), 47);

        Test.assertEqual(DateField.xOf(TimeAlign.LEFT, 9, 416, 416, 244, 35), 16);
        Test.assertEqual(DateField.xOf(TimeAlign.RIGHT, 407, 416, 416, 244, 35), 400);
        Test.assertEqual(DateField.xOf(TimeAlign.LEFT, 33, 416, 416, 278, 35), 33);
        Test.assertEqual(DateField.xOf(TimeAlign.RIGHT, 383, 416, 416, 278, 35), 383);
        Test.assertEqual(DateField.xOf(TimeAlign.CENTER, 208, 416, 416, 278, 35), 208);
        Test.assertEqual(DateField.xOf(TimeAlign.LEFT, 47, 416, 416, 296, 35), 47);
        Test.assertEqual(DateField.xOf(TimeAlign.RIGHT, 369, 416, 416, 296, 35), 369);

        // And the time goes where the date goes (#202): under XXS both sit at 16 rather than
        // the time's own 9, and from L up both stay at the time's margin.
        Test.assertEqual(TimeAlign.sharedXOf(TimeAlign.LEFT, 416, 416, 35, 35), 16);
        Test.assertEqual(TimeAlign.sharedXOf(TimeAlign.RIGHT, 416, 416, 35, 35), 400);
        Test.assertEqual(TimeAlign.sharedXOf(TimeAlign.CENTER, 416, 416, 35, 35), 208);
        Test.assertEqual(TimeAlign.sharedXOf(TimeAlign.LEFT, 416, 416, 104, 35), 33);
        Test.assertEqual(TimeAlign.sharedXOf(TimeAlign.RIGHT, 416, 416, 139, 35), 369);
        return true;
    }


    // The date's box, for every time size and alignment on this product: all four corners
    // on the glass, its top no higher than the time's box's bottom, and its bottom on the
    // screen. The date is drawn in XXS whatever the time size, and ISO is the same ten cells
    // at every date. CI runs this on one product; the other families are run by hand.
    (:test)
    static function theDateStaysOnTheGlassUnderTheTime(logger as Test.Logger) as Boolean {
        var settings = System.getDeviceSettings();
        var width = settings.screenWidth;
        var height = settings.screenHeight;
        var dc = new RecordingDc();
        var date = DateField.load();
        var dateHeight = Graphics.getFontHeight(date);
        var boxWidth = dc.getTextWidthInPixels("2026-09-29", date);
        for (var size = TimeSize.EXTRA_EXTRA_SMALL; size <= TimeSize.EXTRA_EXTRA_LARGE; ++size) {
            var timeHeight = Graphics.getFontHeight(TimeSize.load(size));
            var y = DateField.yOf(height, timeHeight, dateHeight);
            // Assumes drawText puts a vertically centred box's top half its height above y,
            // rounded down, and so the time's bottom half its height below the centre, rounded
            // up. That is yOf's own arithmetic, so this guards yOf, not the platform; placed
            // the other way round, an odd height still leaves the date under the time.
            var top = y - dateHeight / 2;
            var bottom = top + dateHeight;
            Test.assertMessage(top >= height / 2 + (timeHeight + 1) / 2, "size " + size + ": the date is under the time");
            Test.assertMessage(bottom <= height, "size " + size + ": the date is on the screen");
            for (var align = TimeAlign.LEFT; align <= TimeAlign.RIGHT; ++align) {
                var timeX = TimeAlign.xOf(align, width, height, timeHeight);
                var x = DateField.xOf(align, timeX, width, height, y, dateHeight);
                var left = align == TimeAlign.LEFT ? x : align == TimeAlign.RIGHT ? x - boxWidth : x - boxWidth / 2;
                var right = left + boxWidth;
                logger.debug(width + "x" + height + " size " + size + " align " + align + ": date at "
                    + left + ".." + right + ", " + top + ".." + bottom + "; time x " + timeX);
                Test.assertMessage(onTheGlass(left, top) && onTheGlass(left, bottom)
                    && onTheGlass(right, top) && onTheGlass(right, bottom),
                    "size " + size + ", align " + align + ": the date's box is on the glass");
                if (align == TimeAlign.LEFT) {
                    Test.assertMessage(x >= timeX, "size " + size + ": the date is not left of the time");
                } else if (align == TimeAlign.RIGHT) {
                    Test.assertMessage(x <= timeX, "size " + size + ": the date is not right of the time");
                }
            }
        }
        return true;
    }


    // The whole path a change takes, App.onSettingsChanged to the drawText: on, the date is
    // the last thing drawn, in XXS, anchored as the time is and where DateField puts it. At
    // XXS, where the date shares the time's font, and at M, where it does not.
    (:test)
    static function theDateIsDrawnUnderTheTimeWhenOn(logger as Test.Logger) as Boolean {
        var width = System.getDeviceSettings().screenWidth;
        var height = System.getDeviceSettings().screenHeight;
        var dateHeight = Graphics.getFontHeight(DateField.load());
        var sizes = [TimeSize.EXTRA_EXTRA_SMALL, TimeSize.MEDIUM];
        for (var i = 0; i < 6; ++i) {
            var align = i % 3;
            var size = sizes[i / 3];
            var drawn = drawnWith(DateField.ON, align, size, false);
            var dc = drawn[0];
            var timeHeight = Graphics.getFontHeight(TimeSize.load(size));
            var y = DateField.yOf(height, timeHeight, dateHeight);
            var x = TimeAlign.sharedXOf(align, width, height, timeHeight, dateHeight);
            Test.assertEqualMessage(dc.text.length(), 10, "align " + align + ": an ISO date is drawn, got " + dc.text);
            Test.assertMessage(dc.text.find("-") == 4, "align " + align + ": an ISO date is drawn, got " + dc.text);
            Test.assertEqualMessage(dc.x, x, "align " + align + ": the date's x");
            Test.assertEqualMessage(dc.y, y, "align " + align + ": the date's y");
            Test.assertEqualMessage(dc.justify, TimeAlign.justifyOf(align), "align " + align + ": anchored as the time");
            Test.assertMessage(dc.font != null && Graphics.getFontHeight(dc.font as Graphics.FontType) == dateHeight,
                "size " + size + ", align " + align + ": the date is drawn in XXS");
        }
        return true;
    }


    // The time and the date share one edge at the left and the right (#202), at every time
    // size: the date's x is the time's, and the time's is the same with the date on and off,
    // so turning the date on never moves the time.
    (:test)
    static function theTimeAndTheDateShareTheirEdge(logger as Test.Logger) as Boolean {
        var aligns = [TimeAlign.LEFT, TimeAlign.RIGHT];
        for (var size = TimeSize.EXTRA_EXTRA_SMALL; size <= TimeSize.EXTRA_EXTRA_LARGE; ++size) {
            for (var i = 0; i < aligns.size(); ++i) {
                var align = aligns[i] as Number;
                var on = placedWith(DateField.ON, align, size);
                var off = placedWith(DateField.OFF, align, size);
                var where = "size " + size + ", align " + align;
                Test.assertEqualMessage(on[1], on[0], where + ": the date's x is the time's");
                Test.assertEqualMessage(off[0], on[0], where + ": the time does not move when the date is turned on");
            }
        }
        return true;
    }


    // Off, and on the always-on screen whatever the switch, the time is the last thing drawn.
    (:test)
    static function noDateIsDrawnWhenOffOrAlwaysOn(logger as Test.Logger) as Boolean {
        var off = drawnWith(DateField.OFF, TimeAlign.CENTER, TimeSize.MEDIUM, false)[0];
        // A colon, not a length: the unpadded time is four characters or five (#196).
        Test.assertMessage(off.text.find(":") != null, "off: the time is drawn last, got " + off.text);
        var alwaysOn = drawnWith(DateField.ON, TimeAlign.CENTER, TimeSize.MEDIUM, true)[0];
        Test.assertMessage(alwaysOn.text.find(":") != null, "always-on: the time is drawn last, got " + alwaysOn.text);
        Test.assertEqualMessage(alwaysOn.x, System.getDeviceSettings().screenWidth / 2
            + RainMath.jitter(0, System.getDeviceSettings().screenWidth)[0], "always-on: the time is centred");
        return true;
    }


    // The date font is held only while the date is on, and at time size XXS it is the time's
    // own font rather than a second copy of it.
    (:test)
    static function theDateFontIsHeldOnlyWhenNeeded(logger as Test.Logger) as Boolean {
        var off = drawnWith(DateField.OFF, TimeAlign.CENTER, TimeSize.EXTRA_EXTRA_SMALL, false);
        Test.assertMessage(off[1] == null, "off: no date font is held");
        var smallest = drawnWith(DateField.ON, TimeAlign.CENTER, TimeSize.EXTRA_EXTRA_SMALL, false);
        Test.assertMessage(smallest[1] == smallest[2], "XXS: the date shares the time's font");
        var medium = drawnWith(DateField.ON, TimeAlign.CENTER, TimeSize.MEDIUM, false);
        Test.assertMessage(medium[1] != null && medium[1] != medium[2], "M: the date has XXS's font, not the time's");
        Test.assertEqualMessage(Graphics.getFontHeight(medium[1] as Graphics.FontType),
            Graphics.getFontHeight(DateField.load()), "M: the date is drawn at XXS");
        return true;
    }

}
