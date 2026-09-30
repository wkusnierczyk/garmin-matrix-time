using Toybox.Application.Properties;
using Toybox.Application.Storage;
using Toybox.Test;

import Toybox.Lang;


// Presets (#172). Each test puts back the settings and slots it touches, since the simulator
// keeps both across runs.
(:test)
class PresetsTest {

    // A preset brings back every setting of the look it was saved with.
    (:test)
    static function aLoadRestoresTheSavedLook(logger as Test.Logger) as Boolean {
        var saved = snapshot();
        Properties.setValue(TimeSize.PROPERTY, TimeSize.LARGE);
        Properties.setValue(TrailLength.PROPERTY, 75);
        Properties.setValue(TimeStyle.PROPERTY, TimeStyle.HOLLOW);
        Properties.setValue(TimeAlign.PROPERTY, TimeAlign.LEFT);
        Properties.setValue(TimeColor.PROPERTY, 1);
        Properties.setValue(RainColor.PROPERTY, 6);
        Presets.save(1);
        Properties.setValue(TimeSize.PROPERTY, TimeSize.SMALL);
        Properties.setValue(TrailLength.PROPERTY, 25);
        Properties.setValue(TimeStyle.PROPERTY, TimeStyle.FILLED);
        Properties.setValue(TimeAlign.PROPERTY, TimeAlign.RIGHT);
        Properties.setValue(TimeColor.PROPERTY, 5);
        Properties.setValue(RainColor.PROPERTY, 2);
        var loaded = Presets.load(1);
        var look = [TimeSize.selected(), TrailLength.selected(), TimeStyle.selected(), TimeAlign.selected(),
            TimeColor.selected(), RainColor.selected()];
        restore(saved);
        Test.assert(loaded);
        Test.assertEqual(look[0], TimeSize.LARGE);
        Test.assertEqual(look[1], 75);
        Test.assertEqual(look[2], TimeStyle.HOLLOW);
        Test.assertEqual(look[3], TimeAlign.LEFT);
        Test.assertEqual(look[4], 1);
        Test.assertEqual(look[5], 6);
        return true;
    }


    // Always-on brightness and the date are not part of the look, and a load leaves them.
    (:test)
    static function aLoadLeavesAlwaysOnBrightnessAndTheDate(logger as Test.Logger) as Boolean {
        var saved = snapshot();
        Properties.setValue(AlwaysOnBrightness.PROPERTY, AlwaysOnBrightness.BRIGHT);
        Properties.setValue(DateField.PROPERTY, DateField.OFF);
        Presets.save(1);
        Properties.setValue(AlwaysOnBrightness.PROPERTY, AlwaysOnBrightness.DIM);
        Properties.setValue(DateField.PROPERTY, DateField.ON);
        Presets.load(1);
        var level = AlwaysOnBrightness.selected();
        var shown = DateField.shown();
        restore(saved);
        Test.assertEqual(level, AlwaysOnBrightness.DIM);
        Test.assert(shown);
        return true;
    }


    // An empty slot loads nothing, and a setting missing from a snapshot -- one added after
    // the preset was saved -- is left as it is.
    (:test)
    static function anEmptySlotOrAMissingSettingChangesNothing(logger as Test.Logger) as Boolean {
        var saved = snapshot();
        Storage.deleteValue(Presets.STORAGE_KEY + 1);
        Properties.setValue(TimeSize.PROPERTY, TimeSize.SMALL);
        var loadedEmpty = Presets.load(1);
        var savedEmpty = Presets.isSaved(1);
        var sizeAfterEmpty = TimeSize.selected();
        var partial = {TimeColor.PROPERTY => 3} as Dictionary<String, Number>;
        Storage.setValue(Presets.STORAGE_KEY + 1, partial as Storage.ValueType);
        Presets.load(1);
        var sizeAfterPartial = TimeSize.selected();
        var colorAfterPartial = TimeColor.selected();
        restore(saved);
        Test.assert(!loadedEmpty);
        Test.assert(!savedEmpty);
        Test.assertEqual(sizeAfterEmpty, TimeSize.SMALL);
        Test.assertEqual(sizeAfterPartial, TimeSize.SMALL);
        Test.assertEqual(colorAfterPartial, 3);
        return true;
    }


    // A slot picked on the phone is saved or loaded, and the list goes back to None.
    (:test)
    static function aPhoneRequestIsActedOnAndCleared(logger as Test.Logger) as Boolean {
        var saved = snapshot();
        Properties.setValue(TimeColor.PROPERTY, 2);
        Properties.setValue(Presets.SAVE_PROPERTY, 1);
        Presets.applyRequests();
        var saveAfter = Properties.getValue(Presets.SAVE_PROPERTY);
        Properties.setValue(TimeColor.PROPERTY, 4);
        Properties.setValue(Presets.LOAD_PROPERTY, 1);
        Presets.applyRequests();
        var loadAfter = Properties.getValue(Presets.LOAD_PROPERTY);
        var color = TimeColor.selected();
        restore(saved);
        Test.assertEqual(saveAfter, Presets.NONE);
        Test.assertEqual(loadAfter, Presets.NONE);
        Test.assertEqual(color, 2);
        return true;
    }


    // Save and load picked together: the save runs first, so the slot gets the look the
    // phone sent, and the load then brings it straight back.
    (:test)
    static function aSaveRunsBeforeALoad(logger as Test.Logger) as Boolean {
        var saved = snapshot();
        Properties.setValue(TimeColor.PROPERTY, 1);
        Presets.save(1);
        Properties.setValue(TimeColor.PROPERTY, 3);
        Properties.setValue(Presets.SAVE_PROPERTY, 1);
        Properties.setValue(Presets.LOAD_PROPERTY, 1);
        Presets.applyRequests();
        var color = TimeColor.selected();
        restore(saved);
        Test.assertEqual(color, 3);
        return true;
    }


    // Anything but a slot number is no request.
    (:test)
    static function onlyASlotNumberIsARequest(logger as Test.Logger) as Boolean {
        Test.assertEqual(Presets.requestOf(null), Presets.NONE);
        Test.assertEqual(Presets.requestOf(0), Presets.NONE);
        Test.assertEqual(Presets.requestOf(Presets.SLOTS + 1), Presets.NONE);
        Test.assertEqual(Presets.requestOf("1"), Presets.NONE);
        Test.assertEqual(Presets.requestOf(1), 1);
        Test.assertEqual(Presets.requestOf(Presets.SLOTS), Presets.SLOTS);
        return true;
    }


    // A slot is Preset N until the phone names it, and again if the name is cleared.
    (:test)
    static function aSlotWithoutANameIsPresetN(logger as Test.Logger) as Boolean {
        var key = Presets.NAME_PROPERTY + 2;
        var name = Properties.getValue(key);
        Properties.setValue(key, "Night");
        var named = Presets.nameOf(2);
        Properties.setValue(key, "");
        var cleared = Presets.nameOf(2);
        Properties.setValue(key, name as String);
        Test.assertEqual(named, "Night");
        Test.assertEqual(cleared, "Preset 2");
        return true;
    }


    // The settings a preset touches, and slot 1, as they were before a test.
    static function snapshot() as Dictionary {
        var keys = [TimeSize.PROPERTY, TrailLength.PROPERTY, TimeStyle.PROPERTY, TimeAlign.PROPERTY, TimeColor.PROPERTY,
            RainColor.PROPERTY, AlwaysOnBrightness.PROPERTY, DateField.PROPERTY, Presets.LOAD_PROPERTY,
            Presets.SAVE_PROPERTY];
        var saved = {} as Dictionary;
        for (var i = 0; i < keys.size(); ++i) {
            saved[keys[i]] = Properties.getValue(keys[i]);
        }
        saved[:slot] = Storage.getValue(Presets.STORAGE_KEY + 1);
        return saved;
    }

    static function restore(saved as Dictionary) as Void {
        var keys = saved.keys();
        for (var i = 0; i < keys.size(); ++i) {
            if (keys[i] instanceof String) {
                Properties.setValue(keys[i] as String, saved[keys[i]] as Properties.ValueType);
            }
        }
        var slot = saved[:slot];
        if (slot == null) {
            Storage.deleteValue(Presets.STORAGE_KEY + 1);
        } else {
            Storage.setValue(Presets.STORAGE_KEY + 1, slot as Storage.ValueType);
        }
    }

}
