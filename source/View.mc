using Toybox.Application.Properties;
using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Time;

import Toybox.Lang;


class View extends WatchUi.WatchFace {

    private var _digitalRain = new DigitalRain();

    // Every supported product is AMOLED, and on AMOLED the system shuts the screen
    // off in always-on mode if more than 10% of the pixels are lit or any pixel
    // stays lit for three minutes. A full-screen digital rain trips both, so the
    // low-power scene has to be a different, much smaller one -- see
    // DigitalRain.drawLowPower.
    //
    // The state is tracked from the sleep callbacks rather than read per frame:
    // System.getDisplayMode() is the alternative, and it needs API 5.0.0, which the
    // manifest does not yet declare (#13).
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
