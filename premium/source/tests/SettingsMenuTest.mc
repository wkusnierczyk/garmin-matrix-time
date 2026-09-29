using Toybox.Application.Properties;
using Toybox.Test;
using Toybox.WatchUi;

import Toybox.Lang;


// The on-watch settings menu (#148). Premium only, like the settings it shows.
(:test)
class SettingsMenuTest {

    // The menu offers every entry of each colour palette, no more and no fewer (#143): the
    // values are indices, so one missing here would be a colour the phone offers and the
    // watch skips.
    (:test)
    static function theMenuOffersEveryPaletteEntry(logger as Test.Logger) as Boolean {
        Test.assertEqual(SettingsMenu.valuesOf(TimeColor.PROPERTY).size(), TimeColor.COLORS.size());
        Test.assertEqual(SettingsMenu.valuesOf(RainColor.PROPERTY).size(), RainColor.HEADS.size());
        return true;
    }


    // Every setting in the menu offers a label for each of its values, and every offered
    // value is one its module keeps as it is rather than clamping to the default -- so the
    // menu can never write a value the face would then ignore.
    (:test)
    static function everyOfferedValueHasALabelAndIsKept(logger as Test.Logger) as Boolean {
        var properties = SettingsMenu.properties();
        for (var i = 0; i < properties.size(); ++i) {
            var property = properties[i];
            var values = SettingsMenu.valuesOf(property);
            Test.assertEqualMessage(SettingsMenu.labelsOf(property).size(), values.size(),
                property + " has one label per value");
            for (var j = 0; j < values.size(); ++j) {
                var value = values[j];
                var kept = property.equals(TimeSize.PROPERTY) ? TimeSize.sizeOf(value)
                    : property.equals(TrailLength.PROPERTY) ? TrailLength.percentOf(value)
                    : property.equals(TimeColor.PROPERTY) ? TimeColor.indexOf(value)
                    : property.equals(RainColor.PROPERTY) ? RainColor.indexOf(value)
                    : property.equals(TimeAlign.PROPERTY) ? TimeAlign.alignOf(value)
                    : TimeStyle.styleOf(value);
                Test.assertEqualMessage(kept, value, property + " keeps the offered " + value);
            }
        }
        return true;
    }


    // Against the strings themselves, so a labelsOf out of step with valuesOf fails here
    // rather than passing the size check above.
    (:test)
    static function eachValueIsShownWithItsOwnLabel(logger as Test.Logger) as Boolean {
        Test.assertEqual(SettingsMenu.labelOf(TimeSize.PROPERTY, TimeSize.SMALL), "Small");
        Test.assertEqual(SettingsMenu.labelOf(TimeSize.PROPERTY, TimeSize.EXTRA_LARGE), "Extra large");
        Test.assertEqual(SettingsMenu.labelOf(TrailLength.PROPERTY, 25), "25% of the screen");
        Test.assertEqual(SettingsMenu.labelOf(TrailLength.PROPERTY, 75), "75% of the screen");
        Test.assertEqual(SettingsMenu.labelOf(TimeStyle.PROPERTY, TimeStyle.FILLED), "Filled");
        Test.assertEqual(SettingsMenu.labelOf(TimeStyle.PROPERTY, TimeStyle.HOLLOW), "Hollow (Large and Extra large)");
        Test.assertEqual(SettingsMenu.labelOf(TimeAlign.PROPERTY, TimeAlign.LEFT), "Left");
        Test.assertEqual(SettingsMenu.labelOf(TimeAlign.PROPERTY, TimeAlign.CENTER), "Centre");
        Test.assertEqual(SettingsMenu.labelOf(TimeAlign.PROPERTY, TimeAlign.RIGHT), "Right");
        Test.assertEqual(SettingsMenu.labelOf(TimeColor.PROPERTY, TimeColor.GREEN), "Green");
        Test.assertEqual(SettingsMenu.labelOf(TimeColor.PROPERTY, 4), "Orange");
        Test.assertEqual(SettingsMenu.labelOf(RainColor.PROPERTY, RainColor.GREEN), "Green");
        Test.assertEqual(SettingsMenu.labelOf(RainColor.PROPERTY, 6), "White to green");
        return true;
    }


    (:test)
    static function selectingStepsToTheNextValueAndWraps(logger as Test.Logger) as Boolean {
        var sizes = SettingsMenu.valuesOf(TimeSize.PROPERTY);
        Test.assertEqual(SettingsMenu.next(sizes, TimeSize.SMALL), TimeSize.MEDIUM);
        Test.assertEqual(SettingsMenu.next(sizes, TimeSize.LARGE), TimeSize.EXTRA_LARGE);
        Test.assertEqual(SettingsMenu.next(sizes, TimeSize.EXTRA_LARGE), TimeSize.SMALL);

        var styles = SettingsMenu.valuesOf(TimeStyle.PROPERTY);
        Test.assertEqual(SettingsMenu.next(styles, TimeStyle.FILLED), TimeStyle.HOLLOW);
        Test.assertEqual(SettingsMenu.next(styles, TimeStyle.HOLLOW), TimeStyle.FILLED);

        var aligns = SettingsMenu.valuesOf(TimeAlign.PROPERTY);
        Test.assertEqual(SettingsMenu.next(aligns, TimeAlign.LEFT), TimeAlign.CENTER);
        Test.assertEqual(SettingsMenu.next(aligns, TimeAlign.CENTER), TimeAlign.RIGHT);
        Test.assertEqual(SettingsMenu.next(aligns, TimeAlign.RIGHT), TimeAlign.LEFT);
        return true;
    }


    // A change from the phone while the menu is open reaches the menu too: refresh shows
    // the stored value, not the one the menu was built with.
    (:test)
    static function refreshShowsAValueChangedBehindTheMenu(logger as Test.Logger) as Boolean {
        var saved = Properties.getValue(TimeSize.PROPERTY);
        Properties.setValue(TimeSize.PROPERTY, TimeSize.SMALL);
        var menu = new SettingsMenuView();
        Properties.setValue(TimeSize.PROPERTY, TimeSize.EXTRA_LARGE);
        menu.refresh();
        var item = menu.getItem(menu.findItemById(TimeSize.PROPERTY));
        Properties.setValue(TimeSize.PROPERTY, saved as Number);
        Test.assert(item != null);
        Test.assertEqual((item as WatchUi.MenuItem).getSubLabel() as String, "Extra large");
        return true;
    }


    // A trail length the list does not offer is kept by TrailLength (#53); the menu steps
    // from it to the next offered length, not back to the first.
    (:test)
    static function anUnofferedTrailLengthStepsToTheNextOfferedOne(logger as Test.Logger) as Boolean {
        var lengths = SettingsMenu.valuesOf(TrailLength.PROPERTY);
        Test.assertEqual(SettingsMenu.next(lengths, 40), 50);
        Test.assertEqual(SettingsMenu.next(lengths, 90), 25);
        Test.assertEqualMessage(SettingsMenu.labelOf(TrailLength.PROPERTY, 40), "40%",
            "an unoffered length is shown by its number");
        return true;
    }

}
