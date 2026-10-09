using Toybox.Application;

import Toybox.Lang;


// What the About entry at the end of the Customize menu shows (#181): the version installed
// on the watch, the day that build was made, and the developer's address. The Connect IQ app
// shows the store's latest version and its date, which is not the copy on the watch.
//
// An app cannot read its own version: SDK 9.2.0 has no call for it, and the manifest's version
// attribute never reaches the .prg. So make writes the manifest's version and the build's date
// into a string resource before every Premium build, premium/resources-stamp/, which replaces
// the fallbacks in premium/resources-base; see STAMP in the Makefile. A build that does not go
// through make shows the stamp the last make build left, or Unknown on a clean tree.
module About {

    const ID = "about";

    // MAJOR.MINOR.PATCH, manifest-premium.xml's.
    function version() as String {
        return Application.loadResource(Rez.Strings.AppVersion) as String;
    }

    // YYYY-MM-DD, in UTC.
    function buildDate() as String {
        return Application.loadResource(Rez.Strings.BuildDate) as String;
    }

    function contact() as String {
        return Application.loadResource(Rez.Strings.AboutContactAddress) as String;
    }

    // The settings menu's sub-label for the entry: Version 1.0.1.
    function summary() as String {
        return Lang.format(Application.loadResource(Rez.Strings.AboutSubLabel) as String, [version()]);
    }

}
