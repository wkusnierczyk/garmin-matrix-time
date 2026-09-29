using Toybox.Application.Properties;
using Toybox.Graphics;

import Toybox.Lang;


// The time colour setting: the colour of the time, woken and always-on (#143).
//
// The property holds an index into COLORS, not the colour itself, so the menu on the watch
// can step through the list in its own order (SettingsMenu.next wants ascending values)
// rather than in the order of the RGB numbers. Green, Lite's TIME_COLOR, is the default,
// so Premium's time looks like Lite's until the setting is changed.
//
// Any pair of time and rain colours can be chosen, including a hollow time in the rain's
// own colour. That pair is hard to read, and the README says so; it is not blocked.
module TimeColor {

    const
        PROPERTY = "timeColor",
        GREEN = 0;

    // Green, White, Cyan, Amber, Orange, Red; settings.xml's listEntry values index this.
    // Every one is fully saturated or white, so it still reads at the two thirds the
    // always-on screen draws it at.
    const COLORS = [TIME_COLOR, 0xFFFFFF, 0x00FFFF, 0xFFBF00, 0xFF8000, 0xFF0000] as Array<Number>;

    // The stored index, clamped by indexOf.
    function selected() as Number {
        return indexOf(PropertyUtils.getPropertyElseDefault(PROPERTY, GREEN));
    }

    // Anything that is not an index into COLORS -- a missing property, a value of the wrong
    // type, one out of range -- is green, Lite's colour.
    function indexOf(value as Properties.ValueType or Null) as Number {
        if (value instanceof Number && value >= 0 && value < COLORS.size()) {
            return value;
        }
        return GREEN;
    }

    function colorOf(index as Number) as Number {
        return COLORS[index];
    }

    // The always-on colour: `color` at two thirds of its brightness, channel by channel,
    // which is how LOW_POWER_TIME_COLOR was derived from TIME_COLOR. Green gives it back
    // exactly. The burn-in protector counts lit pixels, not their brightness, so a
    // brighter hue leaves the always-on budget measured in the README unchanged.
    function lowPowerOf(color as Number) as Number {
        return ((((color >> RED_SHIFT) & MASK) * 2 / 3) << RED_SHIFT) |
               ((((color >> GREEN_SHIFT) & MASK) * 2 / 3) << GREEN_SHIFT) |
               ((((color >> BLUE_SHIFT) & MASK) * 2 / 3) << BLUE_SHIFT);
    }

}
