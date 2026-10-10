using Toybox.Test;
using Toybox.WatchUi;

import Toybox.Lang;


// The About entry (#181). Premium only, like the settings menu it is in.
(:test)
class AboutTest {

    // make writes the stamp before every Premium build, this suite's included, so the build
    // under test carries a real version and commit, not the Unknown fallbacks. A failure here
    // means the stamp no longer reaches the build: premium.jungle lost premium/resources-stamp,
    // or, on a tree with no stamp left from an earlier build, make test stopped writing it.
    // That export writes it is build.yml's to check.
    (:test)
    static function theBuildIsStampedWithItsVersionAndCommit(logger as Test.Logger) as Boolean {
        Test.assertMessage(isVersion(About.version()), "\"" + About.version() + "\" is MAJOR.MINOR.PATCH");
        Test.assertMessage(isCommit(About.commit()), "\"" + About.commit() + "\" is seven hex digits, -dirty or not");
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


    // Selecting About opens its page rather than falling through to the settings' path, which
    // would write an undeclared "about" property. The presets keep their pages, and a setting
    // opens none.
    (:test)
    static function selectingAboutOpensItsPage(logger as Test.Logger) as Boolean {
        Test.assertMessage(viewFor(About.ID) instanceof AboutMenuView, "About opens AboutMenuView");
        Test.assertMessage(delegateFor(About.ID) instanceof AboutMenuDelegate, "with AboutMenuDelegate");
        Test.assertMessage(viewFor(Presets.LOAD_PROPERTY) instanceof PresetsMenuView, "Load preset opens the slots");
        Test.assertMessage(viewFor(Presets.SAVE_PROPERTY) instanceof PresetsMenuView, "Save opens the slots");
        var properties = SettingsMenu.properties();
        for (var i = 0; i < properties.size(); ++i) {
            Test.assertMessage(SettingsMenu.pageFor(properties[i]) == null, properties[i] + " opens no page");
        }
        return true;
    }


    static function viewFor(id as String) as WatchUi.Views or Null {
        var page = SettingsMenu.pageFor(id);
        return page == null ? null : page[0];
    }


    static function delegateFor(id as String) as WatchUi.InputDelegates or Null {
        var page = SettingsMenu.pageFor(id);
        return page == null ? null : page[1];
    }


    (:test)
    static function aboutShowsTheVersionTheCommitAndTheContact(logger as Test.Logger) as Boolean {
        var about = new AboutMenuView();
        assertItem(about, :version, "Version", About.version());
        assertItem(about, :commit, "Commit", About.commit());
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


    // Seven lower-case hex digits, as the Makefile cuts them, then nothing or -dirty.
    static function isCommit(text as String) as Boolean {
        var chars = text.toCharArray();
        if (chars.size() != 7 && !(chars.size() == 13 && "-dirty".equals(text.substring(7, 13)))) {
            return false;
        }
        for (var i = 0; i < 7; ++i) {
            if (!isDigit(chars[i]) && "abcdef".find(chars[i].toString()) == null) {
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
