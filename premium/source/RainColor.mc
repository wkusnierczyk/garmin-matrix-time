using Toybox.Application.Properties;

import Toybox.Lang;


// The rain colour setting: the colour of the rain, and whether its hue moves along the
// trail as well as dimming (#143).
//
// Each entry is a pair, the colour of the head and the colour the trail cools towards. A
// plain colour is the same colour twice; a gradient, such as white to green, is two. So
// the hue transition is part of the palette rather than a setting of its own, and
// RainMath.gradient builds both kinds of ramp alike.
//
// The property holds an index into the palette, for the reason TimeColor gives. Green,
// Lite's MATRIX_COLOR on its own, is the default, so Premium's rain looks like Lite's
// until the setting is changed.
//
// Every entry has to stay a readable ramp at the shortest trail length, where the ramp
// has the fewest rows to fade over: RainColorTest checks that each of its lit rows is a
// distinct colour. A dark colour would reach black in fewer visibly different steps, which
// is why the blue is a light one.
module RainColor {

    const
        PROPERTY = "rainColor",
        GREEN = 0;

    // Green, Cyan, Blue, Amber, Red, White, White to green, Green to teal; settings.xml's
    // listEntry values index these two, which run index for index.
    const
        HEADS = [MATRIX_COLOR, 0x00FFFF, 0x3399FF, 0xFFBF00, 0xFF0000, 0xFFFFFF, 0xFFFFFF, MATRIX_COLOR] as Array<Number>,
        TAILS = [MATRIX_COLOR, 0x00FFFF, 0x3399FF, 0xFFBF00, 0xFF0000, 0xFFFFFF, MATRIX_COLOR, 0x00FFFF] as Array<Number>;

    // The stored index, clamped by indexOf.
    function selected() as Number {
        return indexOf(PropertyUtils.getPropertyElseDefault(PROPERTY, GREEN));
    }

    // Anything that is not an index into the palette -- a missing property, a value of the
    // wrong type, one out of range -- is green, Lite's colour.
    function indexOf(value as Properties.ValueType or Null) as Number {
        if (value instanceof Number && value >= 0 && value < HEADS.size()) {
            return value;
        }
        return GREEN;
    }

    function headOf(index as Number) as Number {
        return HEADS[index];
    }

    function tailOf(index as Number) as Number {
        return TAILS[index];
    }

}
