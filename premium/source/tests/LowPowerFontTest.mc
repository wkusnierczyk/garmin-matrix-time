using Toybox.Application;
using Toybox.Application.Properties;
using Toybox.Graphics;
using Toybox.Test;
using Toybox.Time;

import Toybox.Lang;


// Premium's always-on font: the filled ExtraBold XL (#164; the hollow L before it, #153, and
// the hollow M before that, #145), whatever the woken time's size and style. Premium only,
// like the font.
(:test)
class LowPowerFontTest {

    // Applies a size and style the way Connect IQ does and returns the view's rain, with the
    // stored values put back afterwards, for the reason TimeSizeTest.selectedWith gives. The
    // rain is read before they are put back, so the caller sees the fonts of the combination.
    private static function withSettings(size as Number, style as Number) as Array<Graphics.FontType> {
        var app = Application.getApp() as App;
        var view = (app.getInitialView() as Array)[0] as View;
        var savedSize = Properties.getValue(TimeSize.PROPERTY);
        var savedStyle = Properties.getValue(TimeStyle.PROPERTY);

        Properties.setValue(TimeSize.PROPERTY, size);
        Properties.setValue(TimeStyle.PROPERTY, style);
        app.onSettingsChanged();
        var rain = view.digitalRain();
        var fonts = [rain.lowPowerFont(), rain.timeFont()] as Array<Graphics.FontType>;

        Properties.setValue(TimeSize.PROPERTY, savedSize as Number);
        Properties.setValue(TimeStyle.PROPERTY, savedStyle as Number);
        app.onSettingsChanged();
        return fonts;
    }


    // Every combination of the two settings, all fourteen, leaves the always-on font at XL's
    // height. A hollow font has its filled twin's metrics, so the height says XL and not
    // which of the two; the next test says which.
    (:test)
    static function theAlwaysOnFontIsExtraLargeWhateverTheSettings(logger as Test.Logger) as Boolean {
        var extraLarge = Graphics.getFontHeight(TimeSize.load(TimeSize.EXTRA_LARGE));
        for (var size = TimeSize.EXTRA_EXTRA_SMALL; size <= TimeSize.EXTRA_EXTRA_LARGE; ++size) {
            for (var style = TimeStyle.FILLED; style <= TimeStyle.HOLLOW; ++style) {
                var height = Graphics.getFontHeight(withSettings(size, style)[0]);
                Test.assertEqualMessage(height, extraLarge,
                    "size " + size + ", style " + style + ": the always-on time is XL");
            }
        }
        return true;
    }


    // The id DigitalRain loads the always-on font from. Filled and hollow XL share every
    // metric, so no loaded font can show which of the two it is; the id can. The hollow
    // outline is what #164 replaced: on the panel the watch dims in always-on it all but
    // disappeared.
    (:test)
    static function theAlwaysOnFontIsTheFilledOne(logger as Test.Logger) as Boolean {
        Test.assertMessage(TimeStyle.alwaysOnFont() == Rez.Fonts.TimeHuge,
            "the always-on font is TimeHuge");
        return true;
    }


    // The filled XL woken time is the always-on font itself, the one object, not a second
    // copy of the bitmap.
    (:test)
    static function theFilledExtraLargeTimeSharesTheAlwaysOnFont(logger as Test.Logger) as Boolean {
        var fonts = withSettings(TimeSize.EXTRA_LARGE, TimeStyle.FILLED);
        Test.assertMessage(fonts[1] == fonts[0], "filled XL is drawn in the always-on font");
        return true;
    }


    // Any other combination loads its own font, so the always-on font is not what the
    // woken time is drawn in -- in particular not hollow XL, whose height it shares.
    (:test)
    static function everyOtherTimeHasItsOwnFont(logger as Test.Logger) as Boolean {
        for (var size = TimeSize.EXTRA_EXTRA_SMALL; size <= TimeSize.EXTRA_EXTRA_LARGE; ++size) {
            for (var style = TimeStyle.FILLED; style <= TimeStyle.HOLLOW; ++style) {
                if (size == TimeSize.EXTRA_LARGE && style == TimeStyle.FILLED) {
                    continue;
                }
                var fonts = withSettings(size, style);
                Test.assertMessage(fonts[1] != fonts[0],
                    "size " + size + ", style " + style + ": the woken time has its own font");
            }
        }
        return true;
    }


    // DigitalRainTest drives the always-on scene round the jitter cycle on a rain built
    // directly, which draws Lite's font. This drives it with the font Premium draws, the one
    // the settings have swapped in, at every corner of the square.
    (:test)
    static function theAlwaysOnFontSurvivesTheWholeJitterCycle(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as App;
        var rain = ((app.getInitialView() as Array)[0] as View).digitalRain();
        var dc = (Graphics.createBufferedBitmap({:width => 64, :height => 64}).get() as Graphics.BufferedBitmap).getDc();
        for (var minute = 0; minute < 2 * LOW_POWER_POSITIONS; ++minute) {
            rain.forTime(new Time.Moment(minute * 60)).drawLowPower(dc);
        }
        return true;
    }

}
