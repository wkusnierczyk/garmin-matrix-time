using Toybox.Application.Properties;
using Toybox.Graphics;
using Toybox.Time;
using Toybox.WatchUi;

import Toybox.Lang;


class View extends WatchUi.WatchFace {

    private var _digitalRain as DigitalRain = new DigitalRain();

    // Every supported product is AMOLED, and on AMOLED the system shuts the screen
    // off in always-on mode if more than 10% of the pixels are lit or any pixel
    // stays lit for three minutes. A full-screen digital rain trips both, so the
    // low-power scene has to be a different, much smaller one -- see
    // DigitalRain.drawLowPower.
    //
    // The state is tracked from the sleep callbacks rather than read per frame.
    // System.getDisplayMode() is the alternative, and since #13 raised minApiLevel to
    // 5.0.0 it is available on every product in the manifest. It was investigated and
    // left alone (#68).
    //
    // It does report one state the callbacks cannot distinguish: DISPLAY_MODE_OFF, the
    // screen off, as against DISPLAY_MODE_LOW_POWER for always-on. Both arrive here as
    // _lowPower == true. That distinction is unreachable from onUpdate, though, because
    // onUpdate is not called at all while the display is off -- a branch on
    // DISPLAY_MODE_OFF would never be taken, and the simulator cannot produce the state
    // to show otherwise: its Display Mode menu offers High Power and Always-On and
    // nothing else.
    //
    // What that leaves is a poll in place of a flag the callbacks set synchronously,
    // with the poll's timing against the sleep transition unverified. Read a beat early
    // it draws the full rain in always-on mode, which is exactly what the burn-in
    // protector shuts the screen off for.
    private var _lowPower as Boolean = false;

    // There is deliberately no onPartialUpdate. Per-second partial updates are a MIP
    // mechanism; on an AMOLED product the burn-in protector governs the always-on
    // scene instead, and onUpdate is called once a minute while asleep.

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {

        // clear() blanks the screen with the background colour through a dedicated
        // path. A full-screen fillRectangle measured 12.6 ms per frame -- 21.8% of
        // the whole frame -- for the same result.
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var rain = _digitalRain.forTime(Time.now());
        if (inLowPower()) {
            rain.drawLowPower(dc);
        } else {
            rain.draw(dc);
        }

    }

    // The low-power test, as a function rather than the field itself, so that a
    // capture build can answer it differently (#128).
    //
    // resources/graphics/MatrixTime5.png is the always-on scene, and the simulator
    // will not enter always-on headlessly: Display Mode is a GUI menu and is not one
    // of the keys the simulator persists, so it resets to High Power on every launch.
    // make graphics therefore takes that one frame from a build in which this
    // function returns true unconditionally. Only the trigger is forced --
    // drawLowPower reads _time and _width and nothing the system sets in always-on,
    // so the captured pixels are the pixels of a genuine always-on frame.
    //
    // Exactly one of these two definitions is compiled. monkey.jungle excludes
    // forceLowPower, so every ordinary build -- make build, run, test, sideload,
    // export, and CI -- compiles the first and the second is not in the .prg at all,
    // not merely unreached. graphics.jungle, layered over monkey.jungle for the
    // capture and used by nothing else, excludes realLowPower instead.
    //
    // Deleting the exclusion does not ship the forcing: both definitions then compile
    // and the build fails with "Redefinition of 'inLowPower' in '$.View'". That is why
    // the gate is a pair of definitions rather than a flag -- there is nothing to
    // remember to check.
    (:realLowPower)
    private function inLowPower() as Boolean {
        return _lowPower;
    }

    (:forceLowPower)
    private function inLowPower() as Boolean {
        return true;
    }

    // Premium's settings, applied at start-up and on every change (#32).
    (:premium)
    function applySettings() as Void {
        _digitalRain.reloadTimeFont();
    }

    function onEnterSleep() as Void {
        _lowPower = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _lowPower = false;
        WatchUi.requestUpdate();
    }

}
