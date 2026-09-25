using Toybox.Application;
using Toybox.Graphics;
using Toybox.Math;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;

import Toybox.Lang;


const
    // Letters only. MatrixCodeNFI maps letters to katakana-style glyphs but renders
    // digits as recognisable digits, so a charset with 0-9 in it scatters numerals
    // through the rain that compete with the clock for attention (#54). The time is
    // the only number on screen.
    CHARSET = "abcdefghijklmnopqrstuvwxyz",
    CHARSET_SIZE = CHARSET.length(),
    MATRIX_COLOR = 0x00FF2B,
    TIME_COLOR = Graphics.COLOR_GREEN;

const
    JUSTIFY = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

const
    // The always-on scene: TIME_COLOR at two thirds of its brightness, stepped round
    // the four corners of a small square so that no pixel stays lit for more than
    // one minute at a time. The offset is a fraction of the screen width so that it
    // scales with the glyphs, which are themselves scaled per resolution.
    //
    // The jitter has to clear the stroke width, not merely be non-zero: a pixel down
    // the centre of a stroke that is still inside the stroke at all four positions
    // never goes dark, and three minutes of that trips the protector. Measured over
    // "12:34" at the TimeLarge font on the thirteen resolutions configured at the time,
    // a divisor of 20 or more leaves such pixels; 19 and below leaves none. The five
    // that remain after #19 are a subset of those thirteen, so the result still holds.
    // 16 is the largest round value below that, and halves as the font doubled -- at
    // the previous 32 the doubled glyphs would have had up to 31 permanently lit
    // pixels (#69). The two jitter constants are read by RainMath.jitter; the colour is
    // used below.
    LOW_POWER_TIME_COLOR = 0x00AA00,
    LOW_POWER_POSITIONS = 4,
    LOW_POWER_JITTER_DIVISOR = 16;


class DigitalRain {

    private var
        _timeColor as Graphics.ColorType = TIME_COLOR,
        _matrixColor as Number = MATRIX_COLOR,
        _shades as Array<Graphics.ColorType> = [];

    // Loaded in initialize rather than declared const. A const initialised from
    // loadResource is not a compile-time constant at all -- the compiler lowers it to a
    // lazily-initialised global -- so both bitmaps were pinned in memory from module
    // initialisation, before App.onStart had run, for the whole life of the app (#24).
    //
    // TimeLarge is twice the reference size of Time. The always-on scene is what the
    // watch shows nearly all of the time, and at the rain glyph size the time was
    // unreadable (#69). The two sizes are independent: time-rain alignment was abandoned
    // in #50, so Time is no longer tied to the Matrix glyph size and is free to be larger.
    private var
        _timeFont as Graphics.FontType,
        _timeLargeFont as Graphics.FontType,
        _matrixFont as Graphics.FontType;

    private var
        _width as Number,
        _height as Number,
        _centerX as Number,
        _centerY as Number;

    // The grid. None of these can be built in the constructor -- every one of them
    // depends on the font metrics, and those need a Dc, which only arrives with the
    // first onUpdate. `_initialize` fills them all in one pass and `_initialized`
    // records that it has run; `draw` consults that flag before reading any of them,
    // so by the time anything here is dereferenced it has a value.
    //
    // They are therefore declared as what they hold rather than as `... or Null`, and
    // start as an empty grid: zero rows, zero columns, no glyphs. The compiler requires
    // a definite value, and an empty grid is the honest one -- it says there is nothing
    // to draw yet, which is exactly the state before the first Dc arrives.
    //
    // The nullable declarations they replace promised a contract the code never
    // honoured: not one of the reads was guarded, and a guard would have been
    // unreachable (#25).
    private var
        _glyphs as Array<String> = [],
        _trails as Array<Array<String>> = [],
        _heads as Array<Number> = [],
        _rowFirst as Array<Number> = [],
        _rowLast as Array<Number> = [],
        _rowCount as Number = 0,
        _columnCount as Number = 0,
        _centerRow as Number = 0,
        _centerColumn as Number = 0,
        _originX as Number = 0,
        _originY as Number = 0,
        _rowHeight as Number = 0,
        _columnWidth as Number = 0,
        _columnX as Array<Number> = [],
        _rowY as Array<Number> = [],
        _initialized as Boolean = false;

    // Set by forTime, which View calls before every draw and drawLowPower. Same
    // contract as the grid above: assigned before it is read, so not nullable.
    private var _time as Time.Moment = new Time.Moment(0);


    function initialize() {

        // Math.rand() runs from a fixed default seed, so without this every launch
        // produced the same starting grid and the same per-column head offsets -- two
        // watches side by side fell in step, and so did the same watch across restarts.
        //
        // The clock alone is not enough to fix that. Moment.value() is a count of
        // seconds, so two watches started in the same second would seed identically and
        // fall in step anyway -- rarer than before, but the same failure. getTimer() is
        // milliseconds since the device powered on, which is both finer grained and
        // genuinely per device: two watches agree on the wall clock but not on how long
        // they have been awake. XOR rather than addition so the mix cannot overflow the
        // 32-bit Number and land on a negative seed (#27).
        Math.srand(Time.now().value() ^ System.getTimer());

        _matrixFont = Application.loadResource(Rez.Fonts.Matrix) as Graphics.FontType;
        _timeFont = Application.loadResource(Rez.Fonts.Time) as Graphics.FontType;
        _timeLargeFont = Application.loadResource(Rez.Fonts.TimeLarge) as Graphics.FontType;

        var settings = System.getDeviceSettings();
        _width = settings.screenWidth;
        _height = settings.screenHeight;
        _centerX = _width / 2;
        _centerY = _height / 2;

    }


    // Premium's time size setting (#32). initialize has loaded Time, Lite's size, and this
    // swaps in the selected one: at start-up and whenever the settings change. Only the
    // time font moves -- the grid is derived from the Matrix font alone (#50), so nothing
    // needs re-initialising.
    //
    // The outgoing font is dropped before the new one is loaded, by pointing the field at
    // a system font for the moment in between, so the two bitmaps are never held at once.
    (:premium)
    function reloadTimeFont() as Void {
        _timeFont = Graphics.FONT_XTINY;
        _timeFont = TimeSize.load(TimeSize.selected(), _timeLargeFont);
    }

    // For TimeSizeTest only, which checks that a settings change reaches the font drawn.
    // (:debug), not (:test): the runner calls every (:test) member as a test. Release
    // builds strip (:debug), so this is not in the shipped .prg.
    (:debug :premium)
    function timeFont() as Graphics.FontType {
        return _timeFont;
    }


    // The one caller, View.onUpdate, always has a Moment in hand, so the parameter is
    // not nullable and there is no "now" default to fall back to. Deciding what time it
    // is belongs to the caller that is already asking the clock, not to a defaulting
    // branch here that nothing ever took (#30).
    //
    // The fluent return stays: View reads better for it, and it costs nothing.
    function forTime(time as Time.Moment) as DigitalRain {
        _time = time;
        return self;
    }


    function draw(dc as Graphics.Dc) as DigitalRain {

        if (!_initialized) {
            _initialize(dc);
        }

        _drawTrails(dc);
        _drawTime(dc, _centerX, _centerY, _timeFont, _timeColor, Graphics.COLOR_BLACK);

        return self;

    }


    // The always-on scene for an AMOLED product. The system blanks the screen in
    // low-power mode if more than 10% of the pixels are lit, or if any pixel stays
    // lit for three minutes, and a full-screen rain fails both tests. So the rain is
    // dropped entirely: only the time is drawn, dimmed, and shifted to a different
    // corner of a small square every minute.
    //
    // No black box is painted behind the time here, unlike the high-power scene: a
    // lit rectangle is exactly what the burn-in protector counts, and with no rain
    // behind it there is nothing for it to mask anyway.
    function drawLowPower(dc as Graphics.Dc) as DigitalRain {

        var offset = RainMath.jitter(_time.value(), _width);

        _drawTime(dc, _centerX + offset[0], _centerY + offset[1], _timeLargeFont, LOW_POWER_TIME_COLOR, Graphics.COLOR_TRANSPARENT);

        return self;

    }


    private function _initialize(dc as Graphics.Dc) as Void {

        // _generateGlyphs runs first: the pitch is measured from the interned charset,
        // so the glyphs have to exist before the grid can be sized.
        _generateGlyphs();

        _rowHeight = dc.getFontHeight(_matrixFont);
        _columnWidth = _widestGlyph(dc);

        // Built outward from the screen centre, one glyph sitting exactly at the centre
        // and the cells stepping out symmetrically in both directions -- see
        // RainMath.centerSteps for why (#10).
        _centerColumn = RainMath.centerSteps(_centerX, _columnWidth);
        _centerRow = RainMath.centerSteps(_centerY, _rowHeight);
        _columnCount = 2 * _centerColumn + 1;
        _rowCount = 2 * _centerRow + 1;
        _originX = _centerX - _centerColumn * _columnWidth;
        _originY = _centerY - _centerRow * _rowHeight;

        _trails = new [_columnCount] as Array<Array<String>>;
        _heads = new [_columnCount] as Array<Number>;

        for (var i = 0; i < _columnCount; ++i) {
            _trails[i] = new [_rowCount] as Array<String>;
            for (var j = 0; j < _rowCount; ++j) {
                var index = Math.rand() % CHARSET_SIZE;
                _trails[i][j] = _glyphs[index];
            }
            _heads[i] = Math.rand() % _rowCount;
        }

        _generateShades();
        _generateSpans();
        _generateCoordinates();

        _initialized = true;

    }


    private function _generateGlyphs() as Void {

        // Dc.drawText takes a String and the trails used to hold Char, so every drawn
        // cell paid for a Char.toString() -- 160 short-lived Strings a frame, one per
        // glyph, at one frame a second (#57). Interning the charset once removes that
        // conversion from the loop: _trails holds references into this fixed pool of
        // CHARSET_SIZE strings, so drawing a frame allocates nothing.
        var characters = CHARSET.toCharArray();
        _glyphs = new [CHARSET_SIZE] as Array<String>;
        for (var i = 0; i < CHARSET_SIZE; ++i) {
            _glyphs[i] = characters[i].toString();
        }

    }


    // The grid pitch. MatrixCodeNFI is proportional -- its 26 advances span 11 to 16
    // pixels at the 416x416 reference resolution -- so no single character's width is the
    // right pitch for a fixed grid. The cell has to be as wide as the widest glyph, or
    // the wide ones overrun it; and since every glyph in the font inks its full advance,
    // that overrun would be visible, not notional.
    //
    // What this replaces measured "0", a character the font has not contained since the
    // charset lost its digits (#79). Connect IQ answers a missing glyph with a fixed
    // fallback width -- 13 pixels at 416x416, the same value it returns for any other
    // absent character -- so the pitch was a constant unrelated to the typeface, and
    // 3 pixels narrower than the widest glyph, which therefore overhung its cell by
    // 1.5 pixels on each side (#84).
    private function _widestGlyph(dc as Graphics.Dc) as Number {

        var width = 0;
        for (var i = 0; i < CHARSET_SIZE; ++i) {
            var advance = dc.getTextWidthInPixels(_glyphs[i], _matrixFont);
            if (advance > width) {
                width = advance;
            }
        }
        return width;

    }


    private function _generateSpans() as Void {

        // On a round display the grid's corners fall outside the glass. Precompute,
        // per column, the first and last row whose cell overlaps the display, so
        // _drawTrails can skip the rest instead of drawing off-screen. RainMath.rowReach
        // does the overlap test and explains why it is a rectangle test, not a centre
        // test (#63, #83).
        _rowFirst = new [_columnCount] as Array<Number>;
        _rowLast = new [_columnCount] as Array<Number>;

        var round = System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND;
        var radius = (_width < _height ? _width : _height) / 2.0;

        for (var i = 0; i < _columnCount; ++i) {
            if (!round) {
                _rowFirst[i] = 0;
                _rowLast[i] = _rowCount - 1;
                continue;
            }
            var reach = RainMath.rowReach(i - _centerColumn, _columnWidth, _rowHeight, radius, _centerRow);
            if (reach < 0) {
                // whole column is off the glass
                _rowFirst[i] = 0;
                _rowLast[i] = -1;
                continue;
            }
            _rowFirst[i] = _centerRow - reach;
            _rowLast[i] = _centerRow + reach;
        }

    }


    private function _generateCoordinates() as Void {

        _columnX = RainMath.axis(_originX, _columnWidth, _columnCount);
        _rowY = RainMath.axis(_originY, _rowHeight, _rowCount);

    }


    // The body of this loop runs some 340 times a frame, and its own arithmetic --
    // everything outside the Dc calls it makes -- was 16.5% of the frame (#60). Three
    // things follow from that count, and none of them change what is drawn:
    //
    //  - every field and constant the loop touches is read once into a local. A field
    //    access in Monkey C is a symbol lookup, not a struct offset, so a field read in
    //    the inner body is paid for per cell;
    //  - the traversal is by shade band rather than by column, so `setColor` is called
    //    once per distinct shade instead of once per glyph (see below);
    //  - the cell coordinates come from the tables `_generateCoordinates` built.
    //
    // The grid is walked outside-in by distance from the head rather than column by
    // column. A cell's shade is fixed by that distance alone, so one band is one colour:
    // `setColor` runs `_rowCount / 2` times a frame -- 8 on `epix2pro47mm` -- where
    // column-major order called it once per drawn glyph, 160 times, 152 of them setting
    // a colour that was already current (#58). The `drawText` calls are the same calls
    // in a different order, and since glyphs do not overlap the frame is identical --
    // which holds because the pitch is the widest advance in the charset, not in spite
    // of the font being proportional (#84).
    private function _drawTrails(dc as Graphics.Dc) as Void {

        var font = _matrixFont,
            transparent = Graphics.COLOR_TRANSPARENT,
            justify = JUSTIFY,
            shades = _shades,
            glyphs = _glyphs,
            trails = _trails,
            heads = _heads,
            rowFirst = _rowFirst,
            rowLast = _rowLast,
            columnX = _columnX,
            rowY = _rowY,
            rowCount = _rowCount,
            columnCount = _columnCount;

        for (var d = 0; d < rowCount; ++d) {

            var shade = shades[d];
            if (shade == 0) {
                // The ramp fades to black over half a screen, so the far half of every
                // trail is 0x000000. Drawing that on a black background paints nothing --
                // skip the whole band rather than pay for setColor + drawText.
                continue;
            }
            dc.setColor(shade, transparent);

            for (var i = 0; i < columnCount; ++i) {

                // The band index is the distance back from this column's head, so the
                // row it names is head - d, wrapped. Both are in [0, rowCount), so the
                // difference falls short by at most one ring and a single conditional
                // add does what a modulo would.
                var j = heads[i] - d;
                if (j < 0) {
                    j += rowCount;
                }

                // Off the glass on a round display. Column-major order had this as a
                // loop bound; brightness-major order visits one row per column per band,
                // so it becomes a range test paid per cell instead.
                if (j < rowFirst[i] || j > rowLast[i]) {
                    continue;
                }

                dc.drawText(columnX[i], rowY[j], font, trails[i][j], justify);

            }

        }

        // The heads advance and the trails mutate once the whole frame is drawn. Both
        // were per column inside the drawing loop, which no longer has one; moving them
        // out changes nothing, since neither touched the column being drawn.
        for (var i = 0; i < columnCount; ++i) {

            // head + 1 mod rowCount, without the modulo: head is already in range, so
            // the sum can only overshoot by one.
            var next = heads[i] + 1;
            heads[i] = (next == rowCount) ? 0 : next;

            // Change one random character in the trail to a new random character
            trails[i][Math.rand() % rowCount] = glyphs[Math.rand() % CHARSET_SIZE];

        }

    }


    private function _drawTime(dc as Graphics.Dc, x as Number, y as Number, font as Graphics.FontType, color as Graphics.ColorType, background as Graphics.ColorType) as Void {

        var info = Gregorian.info(_time, Time.FORMAT_SHORT);
        var time = RainMath.timeText(info.hour, info.min, System.getDeviceSettings().is24Hour);
        dc.setColor(color, background);
        dc.drawText(x, y, font, time, JUSTIFY);

    }


    private function _generateShades() as Void {
        _shades = RainMath.shades(_rowCount, _matrixColor);
    }

}
