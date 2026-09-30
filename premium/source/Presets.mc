using Toybox.Application;
using Toybox.Application.Properties;
using Toybox.Application.Storage;

import Toybox.Lang;


// Presets: five slots, each a saved look that can be loaded back in one step (#172).
//
// A preset is the look only -- time size, trail length, time style, time alignment, time
// colour and rain colour. Always-on brightness and the date are about readability and
// information, not the look, so a load leaves them as they are.
//
// The snapshot is kept in Storage, which the phone never writes, so a save made on the
// watch cannot be overwritten by the phone's copy of the settings. It is a dictionary from
// property to value: a setting added after a preset was saved is missing from it, and a
// load leaves that setting as it is. Only the slot names are properties, presetName1 to
// presetName5, so that the phone can rename them.
//
// The phone's settings screen is built from settings.xml, so its lists cannot show a name
// given on the watch; they say Slot 1 to Slot 5. Loading and saving from the phone are two
// list settings, presetLoad and presetSave, whose first entry, NONE, does nothing. The face
// acts on any other value in onSettingsChanged, through applyRequests, and sets the list
// back to NONE, so the same slot can be picked again.
module Presets {

    const
        SLOTS = 5,
        NONE = 0,
        LOAD_PROPERTY = "presetLoad",
        SAVE_PROPERTY = "presetSave",
        NAME_PROPERTY = "presetName",
        STORAGE_KEY = "preset";

    // The settings a preset covers, in the menu's order.
    function properties() as Array<String> {
        return [TimeSize.PROPERTY, TrailLength.PROPERTY, TimeStyle.PROPERTY, TimeAlign.PROPERTY, TimeColor.PROPERTY,
            RainColor.PROPERTY];
    }

    // Saves the look in effect into slot, 1 to SLOTS. The values are the ones the face
    // draws, clamped, so a load never writes back a value the face would ignore.
    function save(slot as Number) as Void {
        var snapshot = {} as Dictionary<String, Number>;
        var properties = properties();
        for (var i = 0; i < properties.size(); ++i) {
            snapshot[properties[i]] = SettingsMenu.selected(properties[i]);
        }
        Storage.setValue(STORAGE_KEY + slot, snapshot as Storage.ValueType);
    }

    // Sets every setting slot holds. False, and nothing changed, if slot has never been
    // saved.
    function load(slot as Number) as Boolean {
        var snapshot = Storage.getValue(STORAGE_KEY + slot);
        if (!(snapshot instanceof Dictionary)) {
            return false;
        }
        var properties = properties();
        for (var i = 0; i < properties.size(); ++i) {
            var value = snapshot[properties[i]];
            if (value instanceof Number) {
                Properties.setValue(properties[i], value);
            }
        }
        return true;
    }

    function isSaved(slot as Number) as Boolean {
        return Storage.getValue(STORAGE_KEY + slot) instanceof Dictionary;
    }

    // The slot's name as the phone set it; Preset 1 to Preset 5 by default, and whenever the
    // name is cleared.
    function nameOf(slot as Number) as String {
        var name = PropertyUtils.getPropertyElseDefault(NAME_PROPERTY + slot, "");
        if (name instanceof String && name.length() > 0) {
            return name;
        }
        return (Application.loadResource(Rez.Strings.PresetDefaultName) as String) + " " + slot;
    }

    // Acts on a load or save picked on the phone, and sets the list back to NONE. Called
    // from onSettingsChanged and at start, for a request that arrived while the face was
    // not running. A save goes first, so that picking both saves the look the phone sent
    // with the request and then replaces it.
    function applyRequests() as Void {
        var slot = requestOf(PropertyUtils.getPropertyElseDefault(SAVE_PROPERTY, NONE));
        if (slot != NONE) {
            save(slot);
            Properties.setValue(SAVE_PROPERTY, NONE);
        }
        slot = requestOf(PropertyUtils.getPropertyElseDefault(LOAD_PROPERTY, NONE));
        if (slot != NONE) {
            load(slot);
            Properties.setValue(LOAD_PROPERTY, NONE);
        }
    }

    // A slot, 1 to SLOTS, or NONE for anything else.
    function requestOf(value as Properties.ValueType or Null) as Number {
        return value instanceof Number && value >= 1 && value <= SLOTS ? value : NONE;
    }

}
