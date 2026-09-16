using Toybox.Application.Properties;
using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Time;

import Toybox.Lang;


class View extends WatchUi.WatchFace {

    private var _digitalRain = new DigitalRain();

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {

        // clear() blanks the screen with the background colour through a dedicated
        // path. A full-screen fillRectangle measured 12.6 ms per frame -- 21.8% of
        // the whole frame -- for the same result.
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        _digitalRain
            .forTime(Time.now())
            .draw(dc);

    }

}