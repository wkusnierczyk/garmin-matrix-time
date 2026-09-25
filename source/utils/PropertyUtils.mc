using Toybox.Application.Properties;

import Toybox.Lang;


module PropertyUtils {

    // Typed with Properties.ValueType, which is what Properties.getValue returns and
    // therefore the widest thing this can honestly hand back -- it is wider than
    // Application.PropertyValueType, which does not admit Array<Properties.ValueType>.
    // Kept rather than deleted (#16); Premium's TimeSize is its first caller (#32).
    function getPropertyElseDefault(
        propertyName as String,
        defaultValue as Properties.ValueType
    ) as Properties.ValueType {
        try {
            var value = Properties.getValue(propertyName);
            return (value != null) ? value : defaultValue;
        } catch (_) {
            return defaultValue;
        }
    }

}
