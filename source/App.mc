using Toybox.Application;
using Toybox.WatchUi;


class App extends Application.AppBase {

    // Premium keeps the view, so that a settings change can reach it (#32). Lite has
    // no settings and holds nothing.
    (:premium)
    private var _view as View?;

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
        return [ new SettingsMenuView(), new SettingsMenuDelegate() ];
    }

    (:premium)
    function onSettingsChanged() as Void {
        var view = _view;
        if (view != null) {
            view.applySettings();
        }
        WatchUi.requestUpdate();
    }

}
