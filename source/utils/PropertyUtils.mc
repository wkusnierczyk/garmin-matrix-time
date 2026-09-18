using Toybox.Application.Properties;

import Toybox.Lang;


module PropertyUtils {

    // Typed with Properties.ValueType, which is what Properties.getValue returns and
    // therefore the widest thing this can honestly hand back -- it is wider than
    // Application.PropertyValueType, which does not admit Array<Properties.ValueType>.
    // Scaffolding for the settings work in #32 and #33, kept rather than deleted (#16).
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
