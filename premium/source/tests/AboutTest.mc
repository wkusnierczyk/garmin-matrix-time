using Toybox.Test;
using Toybox.WatchUi;

import Toybox.Lang;


// The About entry (#181). Premium only, like the settings menu it is in.
(:test)
class AboutTest {

    // make writes the stamp before every Premium build, this suite's included, so the build
    // under test carries a real version and date, not the Unknown fallbacks. A failure here
    // means the stamp no longer reaches the build: premium.jungle lost premium/resources-stamp,
    // or the Makefile stopped writing it.
    (:test)
    static function theBuildIsStampedWithItsVersionAndDate(logger as Test.Logger) as Boolean {
        Test.assertMessage(isVersion(About.version()), "\"" + About.version() + "\" is MAJOR.MINOR.PATCH");
        Test.assertMessage(isDate(About.buildDate()), "\"" + About.buildDate() + "\" is YYYY-MM-DD");
        return true;
    }


    // The last item of the settings menu, with the version under it.
    (:test)
    static function theSettingsMenuEndsWithAboutAndTheVersion(logger as Test.Logger) as Boolean {
        var menu = new SettingsMenuView();
        var index = menu.findItemById(About.ID);
        Test.assertMessage(menu.getItem(index + 1) == null, "About is the last item");
        var item = menu.getItem(index) as WatchUi.MenuItem;
        Test.assertEqual(item.getLabel(), "About");
        Test.assertEqual(item.getSubLabel() as String, "Version " + About.version());
        return true;
    }


    (:test)
    static function aboutShowsTheVersionTheBuildDateAndTheContact(logger as Test.Logger) as Boolean {
        var about = new AboutMenuView();
        assertItem(about, :version, "Version", About.version());
        assertItem(about, :built, "Built", About.buildDate());
        assertItem(about, :contact, "Contact", "wacus@pm.me");
        Test.assertMessage(about.getItem(3) == null, "About has three items");
        return true;
    }


    static function assertItem(menu as WatchUi.Menu2, id as Symbol, label as String, value as String) as Void {
        var item = menu.getItem(menu.findItemById(id));
        Test.assert(item != null);
        Test.assertEqual((item as WatchUi.MenuItem).getLabel(), label);
        Test.assertEqual((item as WatchUi.MenuItem).getSubLabel() as String, value);
    }


    // Three runs of digits separated by dots, as tools/release-notes.py requires of a manifest.
    static function isVersion(text as String) as Boolean {
        var parts = 1;
        var run = 0;
        var chars = text.toCharArray();
        for (var i = 0; i < chars.size(); ++i) {
            if (chars[i] == '.') {
                if (run == 0) {
                    return false;
                }
                parts += 1;
                run = 0;
            } else if (isDigit(chars[i])) {
                run += 1;
            } else {
                return false;
            }
        }
        return parts == 3 && run > 0;
    }


    static function isDate(text as String) as Boolean {
        var chars = text.toCharArray();
        if (chars.size() != 10) {
            return false;
        }
        for (var i = 0; i < chars.size(); ++i) {
            var dash = i == 4 || i == 7;
            if (dash != (chars[i] == '-') || !dash && !isDigit(chars[i])) {
                return false;
            }
        }
        return true;
    }


    static function isDigit(char as Char) as Boolean {
        var code = char.toNumber();
        return code >= '0'.toNumber() && code <= '9'.toNumber();
    }

}
