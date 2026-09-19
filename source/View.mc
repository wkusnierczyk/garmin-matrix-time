using Toybox.Application.Properties;
using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Time;

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
    // 5.0.0 it is available on every product in the manifest -- but it reports nothing
    // the callbacks do not, so it was investigated and left alone (#68). Its one extra
    // state, DISPLAY_MODE_OFF, is unreachable from here: onUpdate is not called while
    // the display is off, and the simulator cannot produce the state either -- its
    // Display Mode menu offers High Power and Always-On and nothing else. The callbacks
    // also set the state synchronously, where getDisplayMode() is a poll whose timing
    // against the sleep transition is unverified, and reading it a beat early would draw
    // the full rain in always-on mode -- exactly what the burn-in protector shuts the
    // screen off for.
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
        if (_lowPower) {
            rain.drawLowPower(dc);
        } else {
            rain.draw(dc);
        }

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
