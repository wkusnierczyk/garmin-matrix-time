using Toybox.Application.Properties;

import Toybox.Lang;


module PropertyUtils {

    function getPropertyElseDefault(propertyName as String, defaultValue) {
        try {
            var value = Properties.getValue(propertyName);
            return (value != null) ? value : defaultValue;
        } catch (_) {
            return defaultValue;
        }
    }

}
