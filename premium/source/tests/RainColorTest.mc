using Toybox.Application;
using Toybox.Application.Properties;
using Toybox.Graphics;
using Toybox.Test;
using Toybox.Time;

import Toybox.Lang;


// The rain colour setting, and the two-colour ramp it builds (#143). Premium only, like
// the property it reads and RainMath.gradient.
(:test)
class RainColorTest {

    // The ring sizes the supported screens give: 17 rows on the round products, 19 on
    // 320x360 (see TrailLengthTest.halfIsLitesHalfScreen).
    static const ROW_COUNTS = [17, 19];


    // Joins Lite's property table, as TimeSizeTest checks for timeSize (#91).
    (:test)
    static function thePropertyIsDeclared(logger as Test.Logger) as Boolean {
        var color = PropertyUtils.getPropertyElseDefault(RainColor.PROPERTY, "not declared");
        Test.assertMessage(color instanceof Lang.Number, "rainColor is declared, but got: " + color);
        return true;
    }


    (:test)
    static function greenIsLitesPlainColour(logger as Test.Logger) as Boolean {
        Test.assertEqual(RainColor.headOf(RainColor.GREEN), MATRIX_COLOR);
        Test.assertEqual(RainColor.tailOf(RainColor.GREEN), MATRIX_COLOR);
        return true;
    }


    (:test)
    static function anythingButAnIndexIsGreen(logger as Test.Logger) as Boolean {
        var size = RainColor.HEADS.size();
        Test.assertEqual(RainColor.TAILS.size(), size);
        Test.assertEqualMessage(RainColor.indexOf(null), RainColor.GREEN, "null");
        Test.assertEqualMessage(RainColor.indexOf(-1), RainColor.GREEN, "-1");
        Test.assertEqualMessage(RainColor.indexOf(size), RainColor.GREEN, "one past the end");
        Test.assertEqualMessage(RainColor.indexOf("1"), RainColor.GREEN, "a String");
        Test.assertEqualMessage(RainColor.indexOf(size - 1), size - 1, "the last index is kept");
        return true;
    }


    // A plain colour is the one-colour ramp exactly, so Premium's default rain is Lite's to
    // the bit, at every trail length and for every plain entry in the palette.
    (:test)
    static function aPlainColourIsLitesRamp(logger as Test.Logger) as Boolean {
        var percents = [25, 50, 75];
        for (var c = 0; c < RainColor.HEADS.size(); ++c) {
            var head = RainColor.HEADS[c];
            if (head != RainColor.TAILS[c]) {
                continue;
            }
            for (var n = 0; n < ROW_COUNTS.size(); ++n) {
                var rows = ROW_COUNTS[n] as Number;
                for (var p = 0; p < percents.size(); ++p) {
                    var steps = TrailLength.steps(percents[p] as Number, rows);
                    var gradient = RainMath.gradient(rows, steps, head, head);
                    var shades = RainMath.shades(rows, steps, head);
                    for (var i = 0; i < rows; ++i) {
                        Test.assertEqualMessage(gradient[i], shades[i], "colour " + c + ", " + rows + " rows, " + percents[p] + "%, row " + i);
                    }
                }
            }
        }
        return true;
    }


    // The head is the head colour undimmed, the ramp is black from `steps` on, and a gradient
    // has left its head colour by the last lit row.
    (:test)
    static function aGradientRunsFromItsHeadColourToBlack(logger as Test.Logger) as Boolean {
        var ramp = RainMath.gradient(17, 8, 0xFFFFFF, MATRIX_COLOR);
        Test.assertEqualMessage(ramp[0], 0xFFFFFF, "the head is white");
        Test.assertMessage(((ramp[7] >> RED_SHIFT) & MASK) < ((ramp[7] >> GREEN_SHIFT) & MASK),
            "the last lit row has cooled to green, not a grey");
        for (var i = 8; i < 17; ++i) {
            Test.assertEqualMessage(ramp[i], 0x000000, "row " + i + " is black");
        }
        return true;
    }


    // The readable-ramp check the issue asks for: at the shortest trail length, where a
    // ramp has the fewest rows to fade over, every lit row of every palette entry is a
    // different colour and none is black.
    (:test)
    static function everyEntryIsAReadableRampAtTheShortestTrail(logger as Test.Logger) as Boolean {
        for (var c = 0; c < RainColor.HEADS.size(); ++c) {
            for (var n = 0; n < ROW_COUNTS.size(); ++n) {
                var rows = ROW_COUNTS[n] as Number;
                var steps = TrailLength.steps(25, rows);
                var ramp = RainMath.gradient(rows, steps, RainColor.HEADS[c], RainColor.TAILS[c]);
                for (var i = 0; i < steps; ++i) {
                    Test.assertMessage(ramp[i] != 0, "colour " + c + ", " + rows + " rows: row " + i + " is lit");
                    if (i > 0) {
                        Test.assertMessage(ramp[i] != ramp[i - 1], "colour " + c + ", " + rows + " rows: row " + i + " differs from the row before");
                    }
                }
            }
        }
        return true;
    }


    // The whole path a change takes, App.onSettingsChanged to DigitalRain.applyColors, on a
    // rain that is already falling, for every entry offered.
    (:test)
    static function aSettingsChangeReachesTheRampDrawn(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as App;
        var view = (app.getInitialView() as Array)[0] as View;
        var rain = view.digitalRain();
        var saved = Properties.getValue(RainColor.PROPERTY);

        var bitmap = Graphics.createBufferedBitmap({ :width => 64, :height => 64 }).get();
        Test.assertMessage(bitmap != null, "the simulator would not allocate a scratch bitmap");
        rain.forTime(Time.now()).draw((bitmap as Graphics.BufferedBitmap).getDc());

        try {
            for (var c = 0; c < RainColor.HEADS.size(); ++c) {
                Properties.setValue(RainColor.PROPERTY, c);
                app.onSettingsChanged();
                var shades = rain.shades();
                var expected = RainMath.gradient(shades.size(), TrailLength.steps(TrailLength.selected(), shades.size()),
                    RainColor.HEADS[c], RainColor.TAILS[c]);
                for (var i = 0; i < shades.size(); ++i) {
                    Test.assertEqualMessage(shades[i], expected[i], "colour " + c + ", row " + i);
                }
            }
        } finally {
            Properties.setValue(RainColor.PROPERTY, saved as Number);
            app.onSettingsChanged();
        }
        return true;
    }

}
