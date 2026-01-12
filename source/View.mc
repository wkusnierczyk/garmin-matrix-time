using Toybox.Application.Properties;
using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Time;
using Toybox.Time.Gregorian;

import Toybox.Lang;


class View extends WatchUi.WatchFace {

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc) {
        setLayout(Rez.Layouts.WatchFace(dc));
    }

    function onUpdate(dc) {

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.fillRectangle(0, 0, dc.getWidth(), dc.getHeight());

        // var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        // var hour = info.hour;
        // var minutes = info.min;
        // var seconds = info.sec;
        // var dayOfWeek = info.day_of_week;
        // var day = info.day;
        // var month = info.month;
        // var year = info.year;

        // var clockTime = System.getClockTime();
        // var hour = clockTime.hour;
        // var minutes = clockTime.min;
        // var seconds = clockTime.sec;

    }

}