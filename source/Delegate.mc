using Toybox.Application.Properties;
using Toybox.WatchUi;

import Toybox.Lang;


class Delegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {

        var id = item.getId();
        
        // if (id.equals(STANDARD_TIME_PROPERTY) && item instanceof WatchUi.ToggleMenuItem) {
        //     Properties.setValue(STANDARD_TIME_PROPERTY, item.isEnabled());
        // }

        // if (id.equals(MULTI_OPTION_PROPERTY) && item instanceof WatchUi.MenuItem) {
        //     var currentOption = PropertyUtils.getPropertyElseDefault(MULTI_OPTION_PROPERTY, MULTI_OPTION_DEFAULT);
        //     var newOption = (currentOption % MULTI_OPTION_NAMES.size()) + 1;
        //     Properties.setValue(MULTI_OPTION_PROPERTY, newOption);
        //     item.setSubLabel(MULTI_OPTION_NAMES[newOption -1]);
        // }

    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

}
