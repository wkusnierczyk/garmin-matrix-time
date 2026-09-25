using Toybox.Application.Properties;

import Toybox.Lang;


// The trail length setting: how far down the screen the rain fades to black (#53).
//
// The property holds the length itself, as a percentage of the screen height, rather than
// an index into a list: a longer or shorter option is then one more listEntry in
// settings.xml and nothing here. Lite fades over half the screen, so 50 is the default and
// Premium looks like Lite until the setting is changed.
//
// It is also the face's largest battery control. _drawTrails skips every black band, so
// the bands it draws a frame are exactly the steps this returns: 25% roughly halves the
// draw calls of 50%, and 75% adds roughly half again.
module TrailLength {

    const
        PROPERTY = "trailLength",
        DEFAULT = 50;

    // The stored percentage, clamped by percentOf.
    function selected() as Number {
        return percentOf(PropertyUtils.getPropertyElseDefault(PROPERTY, DEFAULT));
    }

    // Anything that is not a percentage strictly between 0 and 100 -- a missing property,
    // a value of the wrong type, one out of range -- is 50, Lite's length. 100 is out on
    // purpose: at the full ring no band is ever black, so _drawTrails skips nothing and the
    // face is back to its cost before #8.
    function percentOf(value as Properties.ValueType or Null) as Number {
        if (value instanceof Number && value > 0 && value < 100) {
            return value;
        }
        return DEFAULT;
    }

    // The ramp's steps for a ring of rowCount rows: the percentage of it, truncating, so
    // 50 is exactly Lite's rowCount / 2. Kept inside [1, rowCount - 1], for a short ring
    // where a small percentage would round to no trail at all, or a large one to all of it.
    function steps(percent as Number, rowCount as Number) as Number {
        var steps = rowCount * percent / 100;
        if (steps > rowCount - 1) {
            steps = rowCount - 1;
        }
        if (steps < 1) {
            steps = 1;
        }
        return steps;
    }

}
