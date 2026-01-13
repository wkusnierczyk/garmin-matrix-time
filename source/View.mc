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

    function onUpdate(dc) {

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.fillRectangle(0, 0, dc.getWidth(), dc.getHeight());

        var time = Time.now();

        _digitalRain
            .forTime(time)
            .draw(dc);


    }

}