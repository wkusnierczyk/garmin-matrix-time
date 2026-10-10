using Toybox.Application;
using Toybox.Graphics;
using Toybox.WatchUi;

import Toybox.Lang;


// What the About entry at the end of the Customize menu shows (#181): the version installed
// on the watch, the build -- the commit it was made from -- and the developer's address. The Connect
// IQ app shows the store's latest version and its date, which is not the copy on the watch.
//
// An app cannot read its own version: SDK 9.2.0 has no call for it, and the manifest's version
// attribute never reaches the .prg. So make writes the manifest's version and the commit into a
// string resource before every Premium build, premium/resources-stamp/, which replaces the
// fallbacks in premium/resources-base; see STAMP in the Makefile. A build that does not go
// through make shows the stamp the last make build left, or Unknown on a clean tree.
module About {

    const ID = "about";

    // MAJOR.MINOR.PATCH, manifest-premium.xml's.
    function version() as String {
        return Application.loadResource(Rez.Strings.AppVersion) as String;
    }

    // The first seven hex digits of the commit, with -dirty after them for a build of
    // uncommitted work.
    function commit() as String {
        return Application.loadResource(Rez.Strings.AppCommit) as String;
    }

    function contact() as String {
        return Application.loadResource(Rez.Strings.AboutContactAddress) as String;
    }

    // The page, as label and value in turn: Version, Build and Contact.
    function page() as Array<String> {
        return [
            Application.loadResource(Rez.Strings.AboutVersion) as String, version(),
            Application.loadResource(Rez.Strings.AboutBuild) as String, commit(),
            Application.loadResource(Rez.Strings.AboutContact) as String, contact()
        ];
    }

    const
        LABEL_FONT = Graphics.FONT_XTINY,
        VALUE_FONT = Graphics.FONT_SMALL;

    // Draws page() as one block centred on a width x height screen: each label in grey over its
    // value in white, and half a label's height between one pair and the next. Apart from the
    // view so that a test can draw it into a recorder.
    function drawPage(dc as Graphics.Dc, width as Number, height as Number) as Void {
        var lines = page();
        var labelHeight = dc.getFontHeight(LABEL_FONT);
        var valueHeight = dc.getFontHeight(VALUE_FONT);
        var pairs = lines.size() / 2;
        var gap = labelHeight / 2;
        var y = (height - pairs * (labelHeight + valueHeight) - (pairs - 1) * gap) / 2;
        for (var i = 0; i < pairs; ++i) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, y, LABEL_FONT, lines[2 * i], Graphics.TEXT_JUSTIFY_CENTER);
            y += labelHeight;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, y, VALUE_FONT, lines[2 * i + 1], Graphics.TEXT_JUSTIFY_CENTER);
            y += valueHeight + gap;
        }
    }

}


// The About entry's page (#181): a page of text rather than a menu, so that nothing on it looks
// selectable. Select does nothing, and back returns to the settings menu.
class AboutView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        About.drawPage(dc, dc.getWidth(), dc.getHeight());
    }

}


class AboutDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

}
