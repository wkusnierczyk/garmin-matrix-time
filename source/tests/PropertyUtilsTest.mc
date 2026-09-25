using Toybox.Application.Properties;
using Toybox.Test;

import Toybox.Lang;


// The helper is scaffolding for the settings work, kept rather than deleted (#16). Lite
// never calls it; Premium's TimeSize is its first caller (#32). It is covered here all the
// same, because its documented contract is exactly what #91
// found it could not honour: with no property table compiled in, Properties.getValue does
// not raise the InvalidKeyException the try/catch is written for -- it fails a level lower
// down, with a system error no catch clause sees, and the app goes down with it.
//
// That is why these tests are worth the 80 bytes of class shell they add to every build. They
// do not really test PropertyUtils.mc, whose body has not changed: they test that the resource
// resources/properties/properties.xml is there and declares a property. Delete it, or empty
// it out, and both tests below report ERROR rather than FAIL, because what they run into is
// not an assertion but the uncatchable failure itself (measured: 21 passed, 0 failed,
// 2 errors) -- #93.
(:test)
class PropertyUtilsTest {

    // The schema marker declared in resources/properties/properties.xml, which exists only
    // so that a property table exists at all.
    static const MARKER = "settingsSchema";


    (:test)
    static function anUnknownPropertyFallsBackToTheDefault(logger as Test.Logger) as Boolean {
        Test.assertEqualMessage(
            PropertyUtils.getPropertyElseDefault("noSuchProperty", 42), 42,
            "an unknown key gives back the default");
        return true;
    }


    (:test)
    static function aDeclaredPropertyComesBackRatherThanTheDefault(logger as Test.Logger) as Boolean {
        // The marker's own value is not asserted: the simulator keeps the property table in
        // GARMIN/APPS/SETTINGS/<APPNAME>.SET across rebuilds and restarts, so a value written
        // there would outlive the declaration in the resource. What is asserted is that the
        // key resolves to the declared number rather than to the String handed in as the
        // default, which is what proves the table is there at all.
        var value = PropertyUtils.getPropertyElseDefault(MARKER, "the default, so the key did not resolve");
        Test.assertMessage(
            value instanceof Lang.Number,
            "the schema marker '" + MARKER + "' is declared and readable, but got: " + value);
        logger.debug("the property table is present: " + MARKER + " = " + value);
        return true;
    }

}
