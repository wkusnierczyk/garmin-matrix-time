using Toybox.Application;
using Toybox.Application.Properties;
using Toybox.Graphics;

import Toybox.Lang;


// The time size setting: which font the woken screen draws the time in (#32).
//
// XXS, XS, S, M, L, XL and XXL are 27, 40, 54, 68, 82, 96 and 110 at the 416x416 reference,
// a step of 14; garmin-font-scaler derives every other resolution from those. The ladder ran
// S to XXL over the first five until XL and XXL were added above it (#166), and the five
// kept their fonts, indices and font ids and took the names two steps down. So the ids no
// longer match the names:
//
//     XXS  Time                  (Lite's Time)
//     XS   TimeMedium
//     S    TimeLarge             (Lite's TimeLarge)
//     M    TimeExtraLarge
//     L    TimeExtraExtraLarge
//     XL   TimeHuge
//     XXL  TimeExtraHuge
//
// Time and TimeLarge cannot be renamed, since they redefine Lite's ids (#144). All seven are
// Premium fonts, generated from premium/resources/fonts in SUSE Mono ExtraBold (#144). The
// always-on scene is not affected: it draws the hollow L at every size and style (#145,
// #153).
//
// The time font is independent of the rain (#50), so a change of size reloads one
// font and nothing else -- the grid is derived from the Matrix font alone.
module TimeSize {

    const
        PROPERTY = "timeSize",
        EXTRA_EXTRA_SMALL = 0,
        EXTRA_SMALL = 1,
        SMALL = 2,
        MEDIUM = 3,
        LARGE = 4,
        EXTRA_LARGE = 5,
        EXTRA_EXTRA_LARGE = 6;

    // The stored index, clamped by sizeOf.
    function selected() as Number {
        return sizeOf(PropertyUtils.getPropertyElseDefault(PROPERTY, MEDIUM));
    }

    // Anything that is not one of the seven -- a missing property, a value of the wrong
    // type, one out of range -- is M, the default in properties.xml (#155), so a watch
    // with no stored value and one with a corrupt value look the same. Separate from
    // selected so that every such value can be tested directly, without first getting it
    // into the property table.
    function sizeOf(value as Properties.ValueType or Null) as Number {
        if (value instanceof Number && value >= EXTRA_EXTRA_SMALL && value <= EXTRA_EXTRA_LARGE) {
            return value;
        }
        return MEDIUM;
    }

    // Loads the selected font, and only that one.
    function load(size as Number) as Graphics.FontType {
        switch (size) {
            case EXTRA_SMALL:
                return Application.loadResource(Rez.Fonts.TimeMedium) as Graphics.FontType;
            case SMALL:
                return Application.loadResource(Rez.Fonts.TimeLarge) as Graphics.FontType;
            case MEDIUM:
                return Application.loadResource(Rez.Fonts.TimeExtraLarge) as Graphics.FontType;
            case LARGE:
                return Application.loadResource(Rez.Fonts.TimeExtraExtraLarge) as Graphics.FontType;
            case EXTRA_LARGE:
                return Application.loadResource(Rez.Fonts.TimeHuge) as Graphics.FontType;
            case EXTRA_EXTRA_LARGE:
                return Application.loadResource(Rez.Fonts.TimeExtraHuge) as Graphics.FontType;
            default:
                return Application.loadResource(Rez.Fonts.Time) as Graphics.FontType;
        }
    }

}
