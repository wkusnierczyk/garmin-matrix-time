using Toybox.Application;
using Toybox.Application.Properties;
using Toybox.Application.Storage;

import Toybox.Lang;


// Presets: five slots, each a saved look that can be loaded back in one step (#172).
//
// Slots 1 to 3 ship with a look of their own, Green, Red and Blue (#183), which stands in
// for a snapshot until the slot is first saved over. Slots 4 and 5 ship empty. The names
// are the defaults of presetName1 to presetName3 in properties.xml.
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
    // saved and has no built-in look.
    function load(slot as Number) as Boolean {
        var snapshot = snapshotOf(slot);
        if (snapshot == null) {
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

    // Whether slot holds a look, saved or built in.
    function hasLook(slot as Number) as Boolean {
        return snapshotOf(slot) != null;
    }

    // The look slot holds: the one saved into it, else its built-in look, else null.
    function snapshotOf(slot as Number) as Dictionary or Null {
        var snapshot = Storage.getValue(STORAGE_KEY + slot);
        if (snapshot instanceof Dictionary) {
            return snapshot as Dictionary;
        }
        return builtIn(slot);
    }

    // The looks slots 1 to 3 ship with (#183), or null for a slot that ships empty. The
    // colours are indices into TimeColor.COLORS and RainColor's HEADS and TAILS.
    function builtIn(slot as Number) as Dictionary<String, Number> or Null {
        switch (slot) {
            case 1:
                // Green: white time, green rain.
                return look(TimeSize.MEDIUM, 25, TimeStyle.FILLED, TimeAlign.RIGHT, 1, 0);
            case 2:
                // Red: orange time, red rain.
                return look(TimeSize.LARGE, 25, TimeStyle.FILLED, TimeAlign.LEFT, 4, 5);
            case 3:
                // Blue: cyan time, blue rain.
                return look(TimeSize.EXTRA_EXTRA_LARGE, 75, TimeStyle.HOLLOW, TimeAlign.CENTER, 2, 2);
        }
        return null;
    }

    function look(size as Number, trail as Number, style as Number, align as Number, timeColor as Number,
            rainColor as Number) as Dictionary<String, Number> {
        return {
            TimeSize.PROPERTY => size,
            TrailLength.PROPERTY => trail,
            TimeStyle.PROPERTY => style,
            TimeAlign.PROPERTY => align,
            TimeColor.PROPERTY => timeColor,
            RainColor.PROPERTY => rainColor
        } as Dictionary<String, Number>;
    }

    // The slot's name as the phone set it; Green, Red, Blue, Preset 4 and Preset 5 by
    // default, and Preset N whenever the name is cleared.
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
