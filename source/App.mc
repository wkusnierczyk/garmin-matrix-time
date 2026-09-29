using Toybox.Application;
using Toybox.WatchUi;

import Toybox.Lang;


class App extends Application.AppBase {

    // Premium keeps the view, so that a settings change can reach it (#32). Lite has
    // no settings and holds nothing.
    (:premium)
    private var _view as View?;

    // The settings menu while it is open, so a change from the phone can reach it too
    // (#148). Weak, so that once the menu is popped it is freed and this goes dead rather
    // than keeping it alive.
    (:premium)
    private var _settingsMenu as WeakReference?;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    (:lite)
    function getInitialView() {
        return [ new View() ];
    }

    (:premium)
    function getInitialView() {
        var view = new View();
        view.applySettings();
        _view = view;
        return [ view ];
    }

    // The watch's Customize menu (#148). settings.xml gives the phone app its screen; the
    // watch has only this.
    (:premium)
    function getSettingsView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] or Null {
        var menu = new SettingsMenuView();
        _settingsMenu = menu.weak();
        return [ menu, new SettingsMenuDelegate() ];
    }

    (:premium)
    function onSettingsChanged() as Void {
        var view = _view;
        if (view != null) {
            view.applySettings();
        }
        var menu = _settingsMenu;
        if (menu != null && menu.stillAlive()) {
            (menu.get() as SettingsMenuView).refresh();
        }
        WatchUi.requestUpdate();
    }

}
