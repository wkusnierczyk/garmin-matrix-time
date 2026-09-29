using Toybox.Application;
using Toybox.Application.Properties;
using Toybox.Graphics;

import Toybox.Lang;


// The time size setting: which font the woken screen draws the time in (#32).
//
// S, M, L, XL and XXL are 27, 40, 54, 68 and 82 at the 416x416 reference, a step of
// about 14; garmin-font-scaler derives every other resolution from those. S and L are
// Lite's Time and TimeLarge ids at Lite's sizes; M, XL and XXL are Premium's own (#153).
// All five are Premium fonts, generated from premium/resources/fonts in SUSE Mono
// ExtraBold (#144), Time and TimeLarge overriding Lite's Regular ones. The always-on
// scene is not affected: it draws the hollow XXL at every size and style (#145, #153).
//
// The time font is independent of the rain (#50), so a change of size reloads one
// font and nothing else -- the grid is derived from the Matrix font alone.
module TimeSize {

    const
        PROPERTY = "timeSize",
        SMALL = 0,
        MEDIUM = 1,
        LARGE = 2,
        EXTRA_LARGE = 3,
        EXTRA_EXTRA_LARGE = 4;

    // The stored index, clamped by sizeOf.
    function selected() as Number {
        return sizeOf(PropertyUtils.getPropertyElseDefault(PROPERTY, EXTRA_LARGE));
    }

    // Anything that is not one of the five -- a missing property, a value of the wrong
    // type, one out of range -- is XL, the default in properties.xml (#155), so a watch
    // with no stored value and one with a corrupt value look the same. Separate from
    // selected so that every such value can be tested directly, without first getting it
    // into the property table.
    function sizeOf(value as Properties.ValueType or Null) as Number {
        if (value instanceof Number && value >= SMALL && value <= EXTRA_EXTRA_LARGE) {
            return value;
        }
        return EXTRA_LARGE;
    }

    // Loads the selected font, and only that one.
    function load(size as Number) as Graphics.FontType {
        switch (size) {
            case MEDIUM:
                return Application.loadResource(Rez.Fonts.TimeMedium) as Graphics.FontType;
            case LARGE:
                return Application.loadResource(Rez.Fonts.TimeLarge) as Graphics.FontType;
            case EXTRA_LARGE:
                return Application.loadResource(Rez.Fonts.TimeExtraLarge) as Graphics.FontType;
            case EXTRA_EXTRA_LARGE:
                return Application.loadResource(Rez.Fonts.TimeExtraExtraLarge) as Graphics.FontType;
            default:
                return Application.loadResource(Rez.Fonts.Time) as Graphics.FontType;
        }
    }

}
