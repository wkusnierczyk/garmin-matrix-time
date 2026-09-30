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
    // The always-on scene: TIME_COLOR at two thirds of its brightness -- Premium's time
    // colour setting at the always-on brightness setting's share of it, of which two
    // thirds is Dim (#143, #161) -- stepped round the four corners of a small square so
    // that no pixel stays lit for more than one minute at a time. The offset is a
    // fraction of the screen width so that it scales with the glyphs, which are
    // themselves scaled per resolution.
    //
    // The jitter has to clear the stroke width, not merely be non-zero: a pixel down
    // the centre of a stroke that is still inside the stroke at all four positions
    // never goes dark, and three minutes of that trips the protector. Measured over
    // "12:34" at the TimeLarge font on the thirteen resolutions configured at the time,
    // a divisor of 20 or more leaves such pixels; 19 and below leaves none. The five
    // that remain after #19 are a subset of those thirteen, so the result still holds.
    // 16 is the largest round value below that, and halves as the font doubled -- at
    // the previous 32 the doubled glyphs would have had up to 31 permanently lit
    // pixels (#69). Re-measured for Premium's heavier ExtraBold TimeLarge (#144) on the
    // seven families shipped then: the threshold is the same for both weights, 20 or
    // below leaving no such pixel and 21 the first to leave one, so 16 still clears.
    //
    // Premium's always-on font was then the hollow ExtraBold XL (#145), 68 at the reference
    // and called M since the sizes were renamed (#166), which cleared at 16 with no margin:
    // measured the same way over a whole day, 12- and 24-hour, on the seven families, every
    // divisor from 8 to 16 left no such pixel and 17 left 21 to 58. A hollow stroke is no help
    // here -- what stays lit are pixels where one digit's outline lands on another's once
    // shifted, not the middle of a stroke.
    //
    // It was then the hollow XXL (#153), 82, called L since #166, and that fails at 16: 21 to 34
    // pixels stay lit for three minutes, and at 15, 23 to 110. The count is not monotonic in
    // the divisor, so every candidate was measured: 13 is the first to leave no such pixel on
    // any family, and 12 cleared with one step of margin. So Premium has its own divisor, and
    // Lite, which is frozen, keeps 16 -- the pair of annotated constants below, which leaves
    // Lite's release PRG byte for byte as it was.
    //
    // It is now the filled XL (#164), 96, because the thin hollow outline all but vanished on
    // the panel the watch dims in always-on. Filled, it fails at 12: 4 to 44 pixels stay lit
    // for three minutes, on six of the seven families, and at 13, 234 to 537. 11 is the first
    // to leave no such pixel, and 10 clears with one step of margin, so Premium's divisor is
    // 10, which shifts the time 41 px at 416x416. 9 and 8 clear as well, but at 8 the ink of
    // "7:22" leaves the glass on every round family. At 10 the ink stays at least 10 px inside
    // the circle, or the rectangle, at all four corners, for every time of the day. The same
    // run puts the most of the screen the time lights at 5.97% (360x360), against 10% allowed;
    // Lite's filled Regular TimeLarge is at 1.40% there. A larger always-on font, or another
    // divisor, has to be measured again.
    //
    // LOW_POWER_POSITIONS and the edition's LOW_POWER_JITTER_DIVISOR, below, are read by
    // RainMath.jitter; the colour is used below.
    LOW_POWER_TIME_COLOR = 0x00AA00,
    LOW_POWER_POSITIONS = 4;

(:lite)
const LOW_POWER_JITTER_DIVISOR = 16;

(:premium)
const LOW_POWER_JITTER_DIVISOR = 10;


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
    //
    // _timeLargeFont is the always-on font. In Premium that is the filled XL rather than
    // TimeLarge (#164); reloadTimeFont swaps it in, and says why it is not loaded here.
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
    //
    // The time style setting (#72) picks between a size's filled font and its hollow one;
    // XXS and XS have no hollow font and stay filled. Neither is drawn on a box (#174): the
    // rain falls through a hollow time's digits, and around a filled time's.
    //
    // The first call also swaps the always-on font: Premium draws the always-on time in the
    // filled XL (#164). initialize is shared with Lite, which is frozen and still compiles
    // byte for byte as it did, so it loads TimeLarge in Premium too; this drops that before
    // loading the filled XL, at the cost of one wasted load at start-up and nothing held. The
    // filled XL woken time is then that same font, not a second copy of it.
    (:premium)
    function reloadTimeFont() as Void {
        var alwaysOn = TimeStyle.alwaysOnFont();
        if (!_lowPowerFontLoaded) {
            _timeLargeFont = Graphics.FONT_XTINY;
            _timeLargeFont = Application.loadResource(alwaysOn) as Graphics.FontType;
            _lowPowerFontLoaded = true;
        }
        _timeFont = Graphics.FONT_XTINY;
        var size = TimeSize.selected();
        var hollow = TimeStyle.hollowFont(size, TimeStyle.selected());
        if (hollow != null) {
            _timeFont = Application.loadResource(hollow) as Graphics.FontType;
        } else if (size == TimeSize.EXTRA_EXTRA_SMALL && _dateFont != null) {
            // The date's font is XXS (#163): share it rather than hold XXS twice.
            _timeFont = _dateFont as Graphics.FontType;
        } else if (TimeSize.fontOf(size) == alwaysOn) {
            _timeFont = _timeLargeFont;
        } else {
            _timeFont = TimeSize.load(size);
        }
    }

    // Whether _timeLargeFont holds Premium's always-on font yet, rather than the TimeLarge
    // initialize loaded. Only reloadTimeFont reads it, and App.getInitialView calls that,
    // through applySettings, before the first frame, so drawLowPower never sees TimeLarge
    // on the watch. A DigitalRain built directly, as DigitalRainTest builds one, still does.
    (:premium)
    private var _lowPowerFontLoaded as Boolean = false;

    // Premium's trail length setting (#53), as a percentage of the screen height. Held
    // here rather than applied at once, because the ramp is built from _rowCount and that
    // is not known until the first Dc: applySettings runs before it at start-up, and
    // _initialize then builds the ramp from whatever this holds. 50 is Lite's half screen.
    (:premium)
    private var _trailPercent as Number = TrailLength.DEFAULT;

    // Called at start-up and whenever the settings change. Only the ramp moves -- the grid,
    // the glyphs and the heads are untouched -- so a change takes effect on the next frame
    // without restarting the rain.
    (:premium)
    function applyTrailLength() as Void {
        _trailPercent = TrailLength.selected();
        if (_initialized) {
            _generateShades();
        }
    }

    // Premium's time and rain colour settings (#143). _timeColor and _matrixColor were
    // kept as fields for this (#16); Premium writes them here, and adds the two colours
    // Lite has as constants: the always-on time, which follows the time colour at the
    // always-on brightness setting's share of it (#161), and the colour the rain's trail
    // cools towards, which is the rain colour itself unless a gradient is chosen. Their
    // defaults are Lite's.
    (:premium)
    private var
        _lowPowerTimeColor as Number = LOW_POWER_TIME_COLOR,
        _matrixTailColor as Number = MATRIX_COLOR;

    // Called at start-up and whenever the settings change, like applyTrailLength and for
    // the same reason: the ramp needs _rowCount, so before the first Dc the colours are
    // only held, and _initialize builds the ramp from them.
    (:premium)
    function applyColors() as Void {
        _timeColor = TimeColor.colorOf(TimeColor.selected());
        _lowPowerTimeColor = TimeColor.lowPowerOf(_timeColor, AlwaysOnBrightness.selected());
        var rain = RainColor.selected();
        _matrixColor = RainColor.headOf(rain);
        _matrixTailColor = RainColor.tailOf(rain);
        if (_initialized) {
            _generateShades();
        }
    }

    // Premium's time alignment setting (#154): where the woken time is drawn, and what its
    // text is anchored to there.
    //
    // _timeX is not the centre until applyTimeAlign has run: the centre is known only in
    // initialize, which Lite shares and which therefore cannot set it. App.getInitialView
    // runs applySettings before the first frame, as it does for _lowPowerFontLoaded, so on
    // the watch draw never sees the 0.
    (:premium)
    private var
        _timeX as Number = 0,
        _timeJustify as Number = JUSTIFY;

    // Called at start-up and whenever the settings change, after reloadTimeFont: the margin
    // at the left and right comes from the height of the font being drawn, so a change of
    // time size moves it too. Graphics.getFontHeight needs no Dc, so unlike the ramp this
    // can be settled before the first frame.
    (:premium)
    function applyTimeAlign() as Void {
        var align = TimeAlign.selected();
        _timeX = TimeAlign.xOf(align, _width, _height, Graphics.getFontHeight(_timeFont));
        _timeJustify = TimeAlign.justifyOf(align);
    }

    // Premium's date (#163): the font it is drawn in, or null while the date is off, so that
    // a face with no date holds no date font; and where applyDate put it.
    (:premium)
    private var
        _dateFont as Graphics.FontType or Null = null,
        _dateX as Number = 0,
        _dateY as Number = 0;

    // Called at start-up and whenever the settings change, after applyTimeAlign: the date
    // sits under the time's box, so its height moves it down, and follows the time's x.
    (:premium)
    function applyDate() as Void {
        if (!DateField.shown()) {
            _dateFont = null;
            return;
        }
        // At time size XXS the time's own font is the date's; reloadTimeFont reuses the date's
        // XXS for the time when it has one. At any other size the date keeps the XXS it holds --
        // reloadTimeFont loads a new time font rather than changing the one the date shares --
        // or loads one.
        if (TimeSize.selected() == TimeSize.EXTRA_EXTRA_SMALL) {
            _dateFont = _timeFont;
        } else if (_dateFont == null) {
            _dateFont = DateField.load();
        }
        var dateHeight = Graphics.getFontHeight(_dateFont as Graphics.FontType);
        _dateY = DateField.yOf(_height, Graphics.getFontHeight(_timeFont), dateHeight);
        _dateX = DateField.xOf(TimeAlign.selected(), _timeX, _width, _height, _dateY, dateHeight);
    }

    // For DateFieldTest only; (:debug) for the reason timeFont gives.
    (:debug :premium)
    function dateFont() as Graphics.FontType or Null {
        return _dateFont;
    }

    // For TimeAlignTest only; (:debug) for the reason timeFont gives.
    (:debug :premium)
    function timePlacement() as Array<Number> {
        return [_timeX, _timeJustify];
    }

    // For TimeColorTest only; (:debug) for the reason timeFont gives.
    (:debug :premium)
    function timeColors() as Array<Number> {
        return [_timeColor, _lowPowerTimeColor];
    }

    // For TrailLengthTest and RainColorTest only; (:debug) for the reason timeFont gives.
    (:debug :premium)
    function shades() as Array<Graphics.ColorType> {
        return _shades;
    }

    // For TimeSizeTest, TimeStyleTest and LowPowerFontTest only, which check that a settings
    // change reaches the font drawn.
    // (:debug), not (:test): the runner calls every (:test) member as a test. Release
    // builds strip (:debug), so this is not in the shipped .prg.
    (:debug :premium)
    function timeFont() as Graphics.FontType {
        return _timeFont;
    }

    // For LowPowerFontTest only; (:debug) for the reason timeFont gives.
    (:debug :premium)
    function lowPowerFont() as Graphics.FontType {
        return _timeLargeFont;
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


    // Lite always draws the time on its black box. Two definitions rather than a shared
    // one reading a field, so that Lite, which is frozen, compiles exactly as before.
    (:lite)
    function draw(dc as Graphics.Dc) as DigitalRain {

        if (!_initialized) {
            _initialize(dc);
        }

        _drawTrails(dc);
        _drawTime(dc, _centerX, _centerY, _timeFont, _timeColor, Graphics.COLOR_BLACK);

        return self;

    }

    // Premium draws it with no box, whatever the time style (#174), so the rain falls around
    // a filled time and through a hollow one (#72); where the time alignment put it (#154);
    // and the date under it when the date is on (#163), anchored the same way and always on
    // a black box.
    (:premium)
    function draw(dc as Graphics.Dc) as DigitalRain {

        if (!_initialized) {
            _initialize(dc);
        }

        _drawTrails(dc);
        _drawTime(dc, _timeX, _centerY, _timeFont, _timeColor, _timeJustify);
        if (_dateFont != null) {
            _drawDate(dc, _dateFont);
        }

        return self;

    }


    // The always-on scene for an AMOLED product. The system blanks the screen in
    // low-power mode if more than 10% of the pixels are lit, or if any pixel stays
    // lit for three minutes, and a full-screen rain fails both tests. So the rain is
    // dropped entirely: only the time is drawn, dimmed in Lite, and shifted to a
    // different corner of a small square every minute.
    //
    // No black box is painted behind the time here, unlike the high-power scene: a
    // lit rectangle is exactly what the burn-in protector counts, and with no rain
    // behind it there is nothing for it to mask anyway.
    //
    // Lite draws it in LOW_POWER_TIME_COLOR, always. Two definitions for the reason draw
    // gives.
    (:lite)
    function drawLowPower(dc as Graphics.Dc) as DigitalRain {

        var offset = RainMath.jitter(_time.value(), _width);

        _drawTime(dc, _centerX + offset[0], _centerY + offset[1], _timeLargeFont, LOW_POWER_TIME_COLOR, Graphics.COLOR_TRANSPARENT);

        return self;

    }

    // Premium draws it in the time colour setting's own always-on colour (#143), at the
    // always-on brightness setting's share of it (#161), and in the filled ExtraBold XL
    // whatever the time size and style (#164), which reloadTimeFont has put in _timeLargeFont.
    // It is larger and heavier than Lite's filled TimeLarge and lights more of the screen, and
    // it is shifted further, by Premium's own divisor; see LOW_POWER_JITTER_DIVISOR.
    //
    // Always centred, whatever the time alignment (#154), so that the burn-in measurement
    // stands: the jitter square was measured about the centre.
    (:premium)
    function drawLowPower(dc as Graphics.Dc) as DigitalRain {

        var offset = RainMath.jitter(_time.value(), _width);

        _drawTime(dc, _centerX + offset[0], _centerY + offset[1], _timeLargeFont, _lowPowerTimeColor, JUSTIFY);

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
    // `setColor` runs once per lit band -- 8 on `epix2pro47mm` at Lite's half screen -- where
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
                // The ramp fades to black part way round the ring -- half of it in Lite,
                // the trail length setting in Premium (#53) -- so the rest of every trail
                // is 0x000000. Drawing that on a black background paints nothing -- skip
                // the whole band rather than pay for setColor + drawText.
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


    // Lite always centres the time. Two definitions for the reason draw gives.
    (:lite)
    private function _drawTime(dc as Graphics.Dc, x as Number, y as Number, font as Graphics.FontType, color as Graphics.ColorType, background as Graphics.ColorType) as Void {

        var info = Gregorian.info(_time, Time.FORMAT_SHORT);
        var time = RainMath.timeText(info.hour, info.min, System.getDeviceSettings().is24Hour);
        dc.setColor(color, background);
        dc.drawText(x, y, font, time, JUSTIFY);

    }

    // Premium anchors it where the time alignment says (#154); the always-on screen passes
    // JUSTIFY. It never draws a box, on either screen (#174).
    (:premium)
    private function _drawTime(dc as Graphics.Dc, x as Number, y as Number, font as Graphics.FontType, color as Graphics.ColorType, justify as Number) as Void {

        var info = Gregorian.info(_time, Time.FORMAT_SHORT);
        var time = RainMath.timeText(info.hour, info.min, System.getDeviceSettings().is24Hour);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, time, justify);

    }


    (:premium)
    private function _drawDate(dc as Graphics.Dc, font as Graphics.FontType) as Void {

        var info = Gregorian.info(_time, Time.FORMAT_SHORT);
        var date = DateField.textOf(info.year, info.month as Number, info.day);
        dc.setColor(_timeColor, Graphics.COLOR_BLACK);
        dc.drawText(_dateX, _dateY, font, date, _timeJustify);

    }


    // Lite fades over half the screen, always.
    (:lite)
    private function _generateShades() as Void {
        _shades = RainMath.shades(_rowCount, _rowCount / 2, _matrixColor);
    }

    // Premium fades over the length the setting chose (#53), from the rain colour's head
    // to its tail (#143).
    (:premium)
    private function _generateShades() as Void {
        _shades = RainMath.gradient(_rowCount, TrailLength.steps(_trailPercent, _rowCount), _matrixColor, _matrixTailColor);
    }

}
