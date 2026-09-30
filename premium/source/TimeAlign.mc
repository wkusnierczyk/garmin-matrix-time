using Toybox.Application.Properties;
using Toybox.Graphics;
using Toybox.Math;

import Toybox.Lang;


// The time alignment setting: the woken time at the left, centre or right of the screen
// (#154). Centre is the default, and is where Lite draws it.
//
// The time stays the fixed 5-cell box it is at the centre, `%2d`'s padding cell included
// (#7), so nothing moves when the hour goes from 9 to 10 or between 12- and 24-hour mode.
// Before 10:00 in 12-hour mode a left-aligned time therefore starts one blank cell in from
// its margin, and that is accepted.
//
// The margin is not fixed. It starts where the screen's circle crosses the top and bottom
// edges of the box drawText fills, which is the font height tall and centred on the
// screen: there those two corners touch the circle and the rest of the box is inside it.
// Every time font's glyph cell is that whole box -- tools/check-font-config.py holds the
// fonts to it -- so no digit can reach past the glass, and the black box behind a filled
// time (#50) stays on it too.
//
// That alone puts the digits against the bezel, 1 pixel in at S and 5 at XL on 416x416,
// so the box moves a further GAP in: a quarter of the font height, which in SUSE Mono is
// about half a digit cell (41 of 86 pixels at XL), and so the same proportion at every
// size. A quarter of the height rather than half the measured advance because the height
// needs no Dc, and the margin can then be settled before the first frame. The margin
// therefore grows with the time size, and is worked out from whichever font is loaded,
// so a new size needs nothing here.
//
// A rectangular screen has no edge to clip against, but takes the margin of the circle
// that fits it, so that the time sits the same way on every shape.
//
// The always-on screen ignores the setting and stays centred, with its jitter, so the
// burn-in measurements on #145 and #153 stand as they were.
module TimeAlign {

    const
        PROPERTY = "timeAlign",
        GAP_DIVISOR = 4,
        LEFT = 0,
        CENTER = 1,
        RIGHT = 2;

    // The stored alignment, clamped by alignOf.
    function selected() as Number {
        return alignOf(PropertyUtils.getPropertyElseDefault(PROPERTY, CENTER));
    }

    // Anything that is not one of the three -- a missing property, a value of the wrong
    // type, one out of range -- is centred, Lite's alignment.
    function alignOf(value as Properties.ValueType or Null) as Number {
        if (value instanceof Number && value >= LEFT && value <= RIGHT) {
            return value;
        }
        return CENTER;
    }

    // How far in from the screen's edge a box of this height has to sit, left or right, for
    // its corners to be on the circle of this radius. Rounded up, so that the box is never
    // a fraction of a pixel outside it, and taking the half height rounded up too, since
    // centring an odd height puts the extra row on one side or the other.
    //
    // The time's case of insetAt. xOf passes the same half height to xAt directly; this is
    // kept for TimeAlignTest's hand-worked values, and for DateField's comment on rounding.
    function inset(radius as Number, boxHeight as Number) as Number {
        return insetAt(radius, (boxHeight + 1) / 2);
    }

    // The same for a box whose farthest corner is reach pixels above or below the centre:
    // the date's (#163), which sits under the time rather than across the middle.
    function insetAt(radius as Number, reach as Number) as Number {
        if (reach >= radius) {
            return radius;
        }
        return radius - Math.sqrt(radius * radius - reach * reach).toNumber();
    }

    // The x the time is drawn at, for a screen of this size and a font of this height. At
    // the centre it is the centre; left and right are the box's outer edge, which justifyOf
    // anchors the text to, inset past the circle and a gap further.
    function xOf(align as Number, width as Number, height as Number, fontHeight as Number) as Number {
        return xAt(align, width, height, (fontHeight + 1) / 2, fontHeight);
    }

    // xOf for a box of this font's height whose farthest corner is reach pixels from the
    // centre, as insetAt takes it.
    function xAt(align as Number, width as Number, height as Number, reach as Number, fontHeight as Number) as Number {
        var center = width / 2;
        if (align == CENTER) {
            return center;
        }
        var radius = (width < height ? width : height) / 2;
        var margin = insetAt(radius, reach) + fontHeight / GAP_DIVISOR;
        return align == LEFT ? center - radius + margin : center + radius - margin;
    }

    // Always vertically centred, like Lite's JUSTIFY; only the horizontal anchor moves.
    function justifyOf(align as Number) as Number {
        switch (align) {
            case LEFT:
                return Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
            case RIGHT:
                return Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER;
            default:
                return Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        }
    }

}
