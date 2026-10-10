using Toybox.Graphics;
using Toybox.Math;
using Toybox.System;
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


    // The last item of the settings menu, saying that it leads to more rather than holding a value.
    (:test)
    static function theSettingsMenuEndsWithAboutAndBuildInformation(logger as Test.Logger) as Boolean {
        var menu = new SettingsMenuView();
        var index = menu.findItemById(About.ID);
        Test.assertMessage(menu.getItem(index + 1) == null, "About is the last item");
        var item = menu.getItem(index) as WatchUi.MenuItem;
        Test.assertEqual(item.getLabel(), "About");
        Test.assertEqual(item.getSubLabel() as String, "Build information");
        return true;
    }


    // Selecting About opens its page rather than falling through to the settings' path, which
    // would write an undeclared "about" property. The presets keep their pages, and a setting
    // opens none.
    (:test)
    static function selectingAboutOpensItsPage(logger as Test.Logger) as Boolean {
        Test.assertMessage(viewFor(About.ID) instanceof AboutView, "About opens AboutView");
        Test.assertMessage(delegateFor(About.ID) instanceof AboutDelegate, "with AboutDelegate");
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


    // The page draws each label over its value, centred, from the top down.
    (:test)
    static function thePageShowsTheVersionTheBuildAndTheContact(logger as Test.Logger) as Boolean {
        var settings = System.getDeviceSettings();
        var page = new PageRecorder();
        About.drawPage(page as Graphics.Dc, settings.screenWidth, settings.screenHeight);
        var expected = ["Version", About.version(), "Build", About.commit(), "Contact", "wacus@pm.me"];
        Test.assertEqual(page.texts.size(), expected.size());
        for (var i = 0; i < expected.size(); ++i) {
            Test.assertEqual(page.texts[i], expected[i]);
            Test.assertEqual(page.xs[i], settings.screenWidth / 2);
            Test.assertEqual(page.justifies[i], Graphics.TEXT_JUSTIFY_CENTER);
            Test.assertEqual(page.fonts[i], i % 2 == 0 ? About.LABEL_FONT : About.VALUE_FONT);
            Test.assertMessage(i == 0 || page.ys[i] > page.ys[i - 1], expected[i] + " is below the line before it");
        }
        return true;
    }


    // Every line is on the glass: within the screen, and on a round one, as wide as its text at
    // most where the circle crosses the line's top and bottom. A commit with -dirty after it is
    // the widest value the page can show.
    (:test)
    static function thePageStaysOnTheGlass(logger as Test.Logger) as Boolean {
        var settings = System.getDeviceSettings();
        var width = settings.screenWidth;
        var height = settings.screenHeight;
        var page = new PageRecorder();
        About.drawPage(page as Graphics.Dc, width, height);
        var widest = page.getTextWidthInPixels("0000000-dirty", About.VALUE_FONT);
        for (var i = 0; i < page.texts.size(); ++i) {
            var font = page.fonts[i] as Graphics.FontType;
            var top = page.ys[i];
            var bottom = top + page.getFontHeight(font);
            Test.assertMessage(top >= 0 && bottom <= height, page.texts[i] + " is within the screen");
            var half = (i % 2 == 1 ? widest : page.getTextWidthInPixels(page.texts[i], font)) / 2.0;
            if (settings.screenShape == System.SCREEN_SHAPE_ROUND) {
                Test.assertMessage(half <= chord(top, width) && half <= chord(bottom, width),
                    page.texts[i] + " fits inside the circle");
            } else {
                Test.assertMessage(half <= width / 2, page.texts[i] + " fits across the screen");
            }
        }
        return true;
    }


    // Half the width of a circle of the given diameter at height y.
    static function chord(y as Number, diameter as Number) as Float {
        var r = diameter / 2.0;
        var dy = y - r;
        return dy * dy >= r * r ? 0.0 : Math.sqrt(r * r - dy * dy).toFloat();
    }


    (:test)
    static function selectOnThePageDoesNothing(logger as Test.Logger) as Boolean {
        Test.assertMessage(new AboutDelegate().onSelect(), "select is handled, and so goes nowhere");
        return true;
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


// Stands in for the screen's Dc and records every drawText, in order. Font metrics come from a
// real Dc, so the layout is checked against the fonts the watch has.
(:test)
class PageRecorder {

    private var _dc as Graphics.Dc;

    var texts as Array<String> = [];
    var xs as Array<Number> = [];
    var ys as Array<Number> = [];
    var fonts as Array<Graphics.FontType> = [];
    var justifies as Array<Number> = [];

    function initialize() {
        var bitmap = Graphics.createBufferedBitmap({:width => 8, :height => 8}).get() as Graphics.BufferedBitmap;
        _dc = bitmap.getDc();
    }

    function setColor(foreground as Graphics.ColorType, background as Graphics.ColorType) as Void {
    }

    function drawText(x as Numeric, y as Numeric, font as Graphics.FontType, text as String, justify as Number) as Void {
        texts.add(text);
        xs.add(x as Number);
        ys.add(y as Number);
        fonts.add(font);
        justifies.add(justify);
    }

    function getFontHeight(font as Graphics.FontType) as Number {
        return _dc.getFontHeight(font);
    }

    function getTextWidthInPixels(text as String, font as Graphics.FontType) as Number {
        return _dc.getTextWidthInPixels(text, font);
    }

}
