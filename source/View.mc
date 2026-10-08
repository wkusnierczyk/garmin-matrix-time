using Toybox.Application.Properties;
using Toybox.Graphics;
using Toybox.System;
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
    // Which scene to draw comes from two signals, and the always-on one is drawn
    // unless both say the watch is awake (#191): this flag, which the sleep callbacks
    // set, and System.getDisplayMode(), which inLowPower reads in every frame the flag
    // says awake. With the display off, nothing is drawn at all; see below (#212).
    //
    // The flag alone was the design until #191: #68 kept it over the poll, whose timing
    // against the sleep transition was unverified. Measured on an epix Pro (Gen 2), it
    // is the flag that lags. onEnterSleep arrives after the display mode has already
    // switched to always-on, and in 18 hours onUpdate was called in always-on 375
    // times while the flag still said awake -- whether because the callback was late
    // or because the face had been started while the watch was already asleep, when
    // the flag starts out awake and no onEnterSleep may follow. Each such frame drew
    // the full rain, the burn-in protector shut the always-on screen off, and it
    // stayed off until the face restarted. The display mode catches those frames.
    //
    // The flag stays as the second signal in case the display mode is ever the one
    // that lags. It costs little: in every logged wake, one to three frames came in
    // high power before onExitSleep cleared the flag, and those still draw the
    // always-on scene, as every wake did before.
    //
    // DISPLAY_MODE_OFF is a third state, in which onUpdate draws nothing at all (#212).
    // This comment used to say onUpdate is not called while the display is off. It is.
    // In sleep mode, once the sleep-mode display timeout has passed, the watch reports
    // DISPLAY_MODE_OFF and goes on calling onUpdate, and what the face draws is shown:
    // the face drew its always-on time there all night, where Garmin's own faces leave
    // the screen dark. Measured on an epix Pro (Gen 2), 2026-10-08. The AMOLED example
    // in the SDK FAQ draws nothing in that mode as well. Low power, the always-on
    // screen proper, still gets the small scene.
    private var _lowPower as Boolean = false;

    // There is deliberately no onPartialUpdate. Per-second partial updates are a MIP
    // mechanism; on an AMOLED product the burn-in protector governs the always-on
    // scene instead.
    //
    // Nor does the always-on scene count on onUpdate's rate. It is documented as once
    // a minute while asleep, but on an epix Pro (Gen 2) it averaged about 16 calls a
    // minute, often in runs of one a second (#191). The scene takes its position from
    // the clock, not from the call count, so it still moves once a minute.

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {

        // clear() blanks the screen with the background colour through a dedicated
        // path. A full-screen fillRectangle measured 12.6 ms per frame -- 21.8% of
        // the whole frame -- for the same result.
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // The display is off, as in sleep mode: leave the screen black (#212).
        if (System.getDisplayMode() == System.DISPLAY_MODE_OFF) {
            return;
        }

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
    // The real test, and onUpdate's display-off test, call System.getDisplayMode() with
    // no has-guard. That is safe only because the function is API 5.0.0 and #13 raised
    // minApiLevel to 5.0.0 in both manifests. Lowering minApiLevel needs a "System has
    // :getDisplayMode" guard in both places first: the compiler checks calls against
    // the device API files, not against minApiLevel, so an older firmware would install
    // the face and fail at runtime.
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
        return _lowPower || System.getDisplayMode() != System.DISPLAY_MODE_HIGH_POWER;
    }

    (:forceLowPower)
    private function inLowPower() as Boolean {
        return true;
    }

    // Premium's settings, applied at start-up and on every change (#32, #53, #143, #154,
    // #163). applyTimeAlign follows reloadTimeFont, since the margin depends on the font, and
    // applyDate follows both, since the date sits under the time and follows its x.
    (:premium)
    function applySettings() as Void {
        _digitalRain.reloadTimeFont();
        _digitalRain.applyTimeAlign();
        _digitalRain.applyDate();
        _digitalRain.applyTrailLength();
        _digitalRain.applyColors();
    }

    // For TimeSizeTest, TrailLengthTest, TimeStyleTest, TimeColorTest, RainColorTest,
    // TimeAlignTest, DateFieldTest and LowPowerFontTest only; (:debug) for the reason DigitalRain.timeFont gives.
    (:debug :premium)
    function digitalRain() as DigitalRain {
        return _digitalRain;
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
