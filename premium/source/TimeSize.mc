using Toybox.Application;
using Toybox.Application.Properties;
using Toybox.Graphics;

import Toybox.Lang;


// The time size setting: which font the woken screen draws the time in (#32).
//
// S, M, L, XL are 27, 40, 54 and 68 at the 416x416 reference; garmin-font-scaler
// derives every other resolution from those. S and L are Lite's Time and TimeLarge, so
// only M and XL are Premium fonts, generated from premium/resources/fonts. The
// always-on scene is not affected: it stays at TimeLarge, the size its burn-in jitter
// and lit-pixel budget were measured at (#69).
//
// The time font is independent of the rain (#50), so a change of size reloads one
// font and nothing else -- the grid is derived from the Matrix font alone.
module TimeSize {

    const
        PROPERTY = "timeSize",
        SMALL = 0,
        MEDIUM = 1,
        LARGE = 2,
        EXTRA_LARGE = 3;

    // The stored index, clamped by sizeOf.
    function selected() as Number {
        return sizeOf(PropertyUtils.getPropertyElseDefault(PROPERTY, SMALL));
    }

    // Anything that is not one of the four -- a missing property, a value of the wrong
    // type, one out of range -- is S, Lite's size. Separate from selected so that every
    // such value can be tested directly, without first getting it into the property table.
    function sizeOf(value as Properties.ValueType or Null) as Number {
        if (value instanceof Number && value >= SMALL && value <= EXTRA_LARGE) {
            return value;
        }
        return SMALL;
    }

    // Loads the selected font, and only that one. L is handed the always-on font the
    // caller already holds rather than loading TimeLarge a second time.
    function load(size as Number, large as Graphics.FontType) as Graphics.FontType {
        switch (size) {
            case MEDIUM:
                return Application.loadResource(Rez.Fonts.TimeMedium) as Graphics.FontType;
            case LARGE:
                return large;
            case EXTRA_LARGE:
                return Application.loadResource(Rez.Fonts.TimeExtraLarge) as Graphics.FontType;
            default:
                return Application.loadResource(Rez.Fonts.Time) as Graphics.FontType;
        }
    }

}
