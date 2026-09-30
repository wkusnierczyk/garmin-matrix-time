using Toybox.Application.Properties;
using Toybox.Graphics;

import Toybox.Lang;


// The date under the woken time (#163), the first of the data fields #33 asks for: shown
// or not. Off is the default, so the face looks as it did until the date is turned on.
//
// It is ISO 8601, 2026-09-05, zero-padded, and so as fixed in width as the time: ten
// cells of the monospace time font at every date. Formats with month or weekday names were
// tried and dropped. In a monospace face the letters are spaced as widely as the digits,
// and they would have added some thirty glyphs to the font.
//
// It is drawn at XXS, the smallest time size, whatever the time size, in XXS's own font. Its
// entry in premium/resources/fonts/charsets.json adds "-" to the time's glyphs for it.
//
// The date sits under the time's box and follows the time alignment (#154), so the two
// read as one block; see xOf. It is drawn on a black box, like a filled time (#50), since
// text this small is not legible over the rain. The always-on screen draws no date, so
// the burn-in measurements on #145, #153 and #161 stand as they were.
module DateField {

    const
        PROPERTY = "date",
        OFF = 0,
        ON = 1;

    // The stored switch, clamped by showOf.
    function shown() as Boolean {
        return showOf(PropertyUtils.getPropertyElseDefault(PROPERTY, OFF)) == ON;
    }

    // Anything but 1 is off, the default: a missing property, a value of the wrong type,
    // one out of range.
    function showOf(value as Properties.ValueType or Null) as Number {
        return value instanceof Number && value == ON ? ON : OFF;
    }

    // The date as drawn. month is 1 to 12, as Gregorian.info gives it in its short format.
    function textOf(year as Number, month as Number, day as Number) as String {
        return year + "-" + month.format("%02d") + "-" + day.format("%02d");
    }

    // The y of the date's centre: its box directly under the time's, which is centred on
    // the screen. Both halves rounded up, as TimeAlign.inset rounds them, so that the two
    // boxes never overlap by the odd row either way.
    function yOf(height as Number, timeFontHeight as Number, dateFontHeight as Number) as Number {
        return height / 2 + (timeFontHeight + 1) / 2 + (dateFontHeight + 1) / 2;
    }

    // The x of the date, anchored as TimeAlign.justifyOf anchors the time. Flush with the
    // time where the glass allows it. The date is lower than the time, where a round
    // screen's chord is shorter, so it may have to sit further in to keep every corner of
    // its box on the glass: at the margin TimeAlign works out for a box reaching as far
    // from the centre as the date's lower edge does, and whichever of the two is further
    // in wins.
    function xOf(align as Number, timeX as Number, width as Number, height as Number, y as Number,
            dateFontHeight as Number) as Number {
        if (align == TimeAlign.CENTER) {
            return width / 2;
        }
        var reach = y - height / 2 + (dateFontHeight + 1) / 2;
        var own = TimeAlign.xAt(align, width, height, reach, dateFontHeight);
        if (align == TimeAlign.LEFT) {
            return own > timeX ? own : timeX;
        }
        return own < timeX ? own : timeX;
    }

    function load() as Graphics.FontType {
        return TimeSize.load(TimeSize.EXTRA_EXTRA_SMALL);
    }

}
