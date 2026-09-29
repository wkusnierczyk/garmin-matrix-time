using Toybox.Application;
using Toybox.Application.Properties;
using Toybox.WatchUi;

import Toybox.Lang;


// The Premium settings on the watch, in the face's Customize menu (#148).
//
// settings.xml drives the phone app only; the watch shows whatever getSettingsView
// returns, and without this it showed nothing. Each setting is one item with its value as
// the sub-label, and selecting it steps to the next value, as in the sibling faces. The
// phone and the watch read and write the same properties, so the two stay in step.
//
// The values and labels below are settings.xml's listEntry lists, in the same order. Keep
// them together: a value added there and not here can be picked on the phone and is then
// shown here by its number, but never offered.
module SettingsMenu {

    // The settings, in the order the menu lists them and settings.xml declares them.
    function properties() as Array<String> {
        return [TimeSize.PROPERTY, TrailLength.PROPERTY, TimeStyle.PROPERTY];
    }

    function titleOf(property as String) as ResourceId {
        if (property.equals(TimeSize.PROPERTY)) {
            return Rez.Strings.TimeSizeTitle;
        }
        if (property.equals(TrailLength.PROPERTY)) {
            return Rez.Strings.TrailLengthTitle;
        }
        return Rez.Strings.TimeStyleTitle;
    }

    // The values offered, ascending, as next requires.
    function valuesOf(property as String) as Array<Number> {
        if (property.equals(TimeSize.PROPERTY)) {
            return [TimeSize.SMALL, TimeSize.MEDIUM, TimeSize.LARGE, TimeSize.EXTRA_LARGE];
        }
        if (property.equals(TrailLength.PROPERTY)) {
            return [25, 50, 75];
        }
        return [TimeStyle.FILLED, TimeStyle.HOLLOW];
    }

    // The labels of valuesOf, index for index.
    function labelsOf(property as String) as Array<ResourceId> {
        if (property.equals(TimeSize.PROPERTY)) {
            return [
                Rez.Strings.TimeSizeSmall,
                Rez.Strings.TimeSizeMedium,
                Rez.Strings.TimeSizeLarge,
                Rez.Strings.TimeSizeExtraLarge
            ];
        }
        if (property.equals(TrailLength.PROPERTY)) {
            return [Rez.Strings.TrailLength25, Rez.Strings.TrailLength50, Rez.Strings.TrailLength75];
        }
        return [Rez.Strings.TimeStyleFilled, Rez.Strings.TimeStyleHollow];
    }

    // The value in effect, clamped exactly as the face clamps it when it draws, so the
    // menu never shows a value the face is not using.
    function selected(property as String) as Number {
        if (property.equals(TimeSize.PROPERTY)) {
            return TimeSize.selected();
        }
        if (property.equals(TrailLength.PROPERTY)) {
            return TrailLength.selected();
        }
        return TimeStyle.selected();
    }

    // The first offered value above current, wrapping to the first. Not "the one after
    // current's index": a trail length the list does not offer is still kept (#53), and
    // this steps from it to the next offered length rather than jumping back to the start.
    function next(values as Array<Number>, current as Number) as Number {
        for (var i = 0; i < values.size(); ++i) {
            if (values[i] > current) {
                return values[i];
            }
        }
        return values[0];
    }

    function labelOf(property as String, value as Number) as String {
        var values = valuesOf(property);
        for (var i = 0; i < values.size(); ++i) {
            if (values[i] == value) {
                return Application.loadResource(labelsOf(property)[i]) as String;
            }
        }
        // Only a trail length can get here, a percentage settings.xml does not offer.
        return value + "%";
    }

}


class SettingsMenuView extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({:title => Application.loadResource(Rez.Strings.AppName) as String});
        var properties = SettingsMenu.properties();
        for (var i = 0; i < properties.size(); ++i) {
            var property = properties[i];
            addItem(new WatchUi.MenuItem(
                Application.loadResource(SettingsMenu.titleOf(property)) as String,
                SettingsMenu.labelOf(property, SettingsMenu.selected(property)),
                property,
                null
            ));
        }
    }

}


class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var property = item.getId() as String;
        var value = SettingsMenu.next(SettingsMenu.valuesOf(property), SettingsMenu.selected(property));
        Properties.setValue(property, value);
        item.setSubLabel(SettingsMenu.labelOf(property, value));
        // onSettingsChanged is for changes from the phone; one made here has to be
        // passed on to the face by hand.
        (Application.getApp() as App).onSettingsChanged();
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

}
