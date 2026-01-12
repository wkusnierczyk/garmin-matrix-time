using Toybox.Application.Properties;
using Toybox.WatchUi;

import Toybox.Lang;


class Menu extends WatchUi.Menu2 {

    function initialize() {

        Menu2.initialize({:title => CUSTOMIZE_MENU_TITLE});

        // var standardTimeEnabled = PropertyUtils.getPropertyElseDefault(STANDARD_TIME_PROPERTY, STANDARD_TIME_MODE_DEFAULT);
        // addItem(new WatchUi.ToggleMenuItem(
        //     STANDARD_TIME_LABEL, 
        //     null, 
        //     STANDARD_TIME_PROPERTY, 
        //     standardTimeEnabled, 
        //     null
        // ));

        // var multiOptionSelection = PropertyUtils.getPropertyElseDefault(MULTI_OPTION_PROPERTY, MULTI_OPTION_DEFAULT);
        // var multiOptoinName = MULTI_OPTION_NAMES[multiOptionSelection];
        // addItem(new WatchUi.MenuItem(
        //     MULTI_OPTION_LABEL, 
        //     multiOptoinName, 
        //     MULTI_OPTION_PROPERTY, 
        //     null
        // ));

    }

}
