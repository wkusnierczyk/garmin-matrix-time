using Toybox.Application.Properties;

import Toybox.Lang;


// The always-on brightness setting: how bright the always-on time is drawn, as a share of
// the time colour (#161). Bright is the default.
//
// Lite draws its always-on time at two thirds of its woken green, and Premium did the same
// for every time colour (#143). On the watch that was hard to read, since the system dims
// the always-on screen further on top of it, so Premium offers the full colour and a step
// between the two as well. Dim is the old two thirds, and what Lite still draws.
//
// The burn-in protector counts lit pixels, not their brightness, so every level leaves the
// always-on figures measured on #145 and #153 as they were. A brighter time costs some
// battery in always-on, and nothing else.
module AlwaysOnBrightness {

    const
        PROPERTY = "alwaysOnBrightness",
        BRIGHT = 0,
        DIMMED = 1,
        DIM = 2;

    // Each level's share of the time colour, in sixths, indexed by level: all of it, five
    // sixths and two thirds. Sixths so that Dim is Lite's two thirds exactly.
    const SIXTHS = [6, 5, 4] as Array<Number>;

    // The stored level, clamped by levelOf.
    function selected() as Number {
        return levelOf(PropertyUtils.getPropertyElseDefault(PROPERTY, BRIGHT));
    }

    // Anything that is not one of the three -- a missing property, a value of the wrong
    // type, one out of range -- is bright, the default.
    function levelOf(value as Properties.ValueType or Null) as Number {
        if (value instanceof Number && value >= BRIGHT && value <= DIM) {
            return value;
        }
        return BRIGHT;
    }

    function sixthsOf(level as Number) as Number {
        return SIXTHS[level];
    }

}
