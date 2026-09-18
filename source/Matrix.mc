using Toybox.Application;
using Toybox.Graphics;
using Toybox.Math;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi;

import Toybox.Lang; 


const 
    MATRIX_FONT = Application.loadResource(Rez.Fonts.Matrix) as Graphics.FontType,
    TIME_FONT = Application.loadResource(Rez.Fonts.Time) as Graphics.FontType,
    // Twice the reference size of Time. The always-on scene is what the watch shows
    // nearly all of the time, and at the rain glyph size the time was unreadable (#69).
    // The two sizes are independent: time-rain alignment was abandoned in #50, so Time
    // is no longer tied to the Matrix glyph size and this one is free to be larger.
    TIME_LARGE_FONT = Application.loadResource(Rez.Fonts.TimeLarge) as Graphics.FontType,
    // Letters only. MatrixCodeNFI maps letters to katakana-style glyphs but renders
    // digits as recognisable digits, so a charset with 0-9 in it scatters numerals
    // through the rain that compete with the clock for attention (#54). The time is
    // the only number on screen.
    CHARSET = "abcdefghijklmnopqrstuvwxyz",
    CHARSET_SIZE = CHARSET.length(),
    MATRIX_COLOR = 0x00FF2B,
    TIME_COLOR = Graphics.COLOR_GREEN;

const 
    SCREEN_WIDTH = System.getDeviceSettings().screenWidth,
    SCREEN_HEIGHT = System.getDeviceSettings().screenHeight;

const
    JUSTIFY = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

const
    RED_SHIFT = 16,
    GREEN_SHIFT = 8,
    BLUE_SHIFT = 0,
    MASK = 0xFF;

const
    // The always-on scene: TIME_COLOR at two thirds of its brightness, stepped round
    // the four corners of a small square so that no pixel stays lit for more than
    // one minute at a time. The offset is a fraction of the screen width so that it
    // scales with the glyphs, which are themselves scaled per resolution.
    //
    // The jitter has to clear the stroke width, not merely be non-zero: a pixel down
    // the centre of a stroke that is still inside the stroke at all four positions
    // never goes dark, and three minutes of that trips the protector. Measured over
    // "12:34" at TIME_LARGE_FONT on all thirteen supported resolutions, a divisor of
    // 20 or more leaves such pixels; 19 and below leaves none. 16 is the largest
    // round value below that, and halves as the font doubled -- at the previous 32 the
    // doubled glyphs would have had up to 31 permanently lit pixels (#69).
    LOW_POWER_TIME_COLOR = 0x00AA00,
    LOW_POWER_POSITIONS = 4,
    LOW_POWER_JITTER_DIVISOR = 16;


class DigitalRain {

    private var 
        _timeColor = TIME_COLOR,
        _timeFont = TIME_FONT,
        _timeLargeFont = TIME_LARGE_FONT,
        _matrixFont = MATRIX_FONT,
        _matrixColor = MATRIX_COLOR,
        _shades as Array<Graphics.ColorType> or Null;

    private var
        _width as Number,
        _height as Number,
        _centerX as Number,
        _centerY as Number;

    private var
        _glyphs as Array<String> or Null,
        _trails as Array<Array<String>> or Null,
        _heads as Array<Number> or Null,
        _rowFirst as Array<Number> or Null,
        _rowLast as Array<Number> or Null,
        _rowCount as Number or Null,
        _columnCount as Number or Null,
        _centerRow as Number or Null,
        _centerColumn as Number or Null,
        _originX as Number or Null,
        _originY as Number or Null,
        _rowHeight as Number or Null,
        _columnWidth as Number or Null,
        _columnX as Array<Number> or Null,
        _rowY as Array<Number> or Null,
        _initialized as Boolean = false;

    private var _dc as Graphics.Dc or Null;

    private var _time as Time.Moment or Null;


    function initialize() {
        var settings = System.getDeviceSettings();
        _width = settings.screenWidth;
        _height = settings.screenHeight;
        _centerX = _width / 2;
        _centerY = _height / 2;
    }


    function forTime(time as Time.Moment or Null) as DigitalRain {
        _time = (time == null) ? Time.now() : time;
        return self;
    }


    function draw(dc as Graphics.Dc) as DigitalRain {

        _dc = dc;
        if (!_initialized) {
            _initialize();
        }

        _drawTrails();
        _drawTime(_centerX, _centerY, _timeFont, _timeColor, Graphics.COLOR_BLACK);

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

        _dc = dc;

        // The minute number, taken straight off the Moment: the jitter needs nothing
        // else from the calendar, and Gregorian.info is comparatively expensive.
        var step = (_time.value() / 60) % LOW_POWER_POSITIONS;
        var jitter = _width / LOW_POWER_JITTER_DIVISOR;
        var dx = (step == 0 || step == 3) ? -jitter : jitter;
        var dy = (step < 2) ? -jitter : jitter;

        _drawTime(_centerX + dx, _centerY + dy, _timeLargeFont, LOW_POWER_TIME_COLOR, Graphics.COLOR_TRANSPARENT);

        return self;

    }


    private function _initialize() {

        // _generateGlyphs runs first: the pitch is measured from the interned charset,
        // so the glyphs have to exist before the grid can be sized.
        _generateGlyphs();

        _rowHeight = _dc.getFontHeight(_matrixFont);
        _columnWidth = _widestGlyph();

        // The grid is built outward from the screen centre rather than from the top-left
        // corner: one glyph sits exactly at the centre and the cells step out symmetrically
        // in both directions. A corner-anchored grid centred its first row and column on
        // y = 0 / x = 0 -- half of every one of those glyphs off the screen -- while leaving
        // the far edge ragged by whatever the cell size did not divide (#10).
        //
        // The half-cell term picks the smallest number of steps whose outermost glyph still
        // reaches the edge, so the grid covers the screen without any cell landing entirely
        // outside it.
        _centerColumn = Math.ceil((_centerX - _columnWidth / 2.0) / _columnWidth).toNumber();
        _centerRow = Math.ceil((_centerY - _rowHeight / 2.0) / _rowHeight).toNumber();
        _columnCount = 2 * _centerColumn + 1;
        _rowCount = 2 * _centerRow + 1;
        _originX = _centerX - _centerColumn * _columnWidth;
        _originY = _centerY - _centerRow * _rowHeight;

        _trails = new [_columnCount] as Array<Array<String>>;
        _heads = new [_columnCount];

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


    private function _generateGlyphs() {

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
    private function _widestGlyph() as Number {

        var width = 0;
        for (var i = 0; i < CHARSET_SIZE; ++i) {
            var advance = _dc.getTextWidthInPixels(_glyphs[i], _matrixFont);
            if (advance > width) {
                width = advance;
            }
        }
        return width;

    }


    private function _generateSpans() {

        // On a round display the grid's corners fall outside the glass. Precompute,
        // per column, the first and last row whose cell overlaps the display, so
        // _drawTrails can skip the rest instead of drawing off-screen.
        //
        // The test is cell rectangle against circle, not cell centre against circle. A
        // centre-in-circle test drops every cell whose centre has crossed the rim even
        // when most of its glyph is still on the glass, which left a thin uncovered band
        // right round the edge where the rain stopped short -- 1.9% to 3.4% of the
        // visible disc, depending on the resolution (#63). Shrinking the centre distance
        // by half a cell on each axis before the comparison keeps every cell whose
        // rectangle touches the circle. It is the conservative direction for a culling
        // test: it can keep a cell whose ink misses the glass, but never drops one whose
        // ink would have hit it.
        //
        // Coverage does not depend on the resolution. _initialize lays the cells out as a
        // gapless tiling that overhangs the screen on all four sides, so every point of
        // the glass falls inside some cell, and keeping every cell that meets the disc
        // therefore covers the disc entirely by construction. Sampling agrees: the
        // uncovered band goes to 0.00% at each of the four round resolutions the manifest
        // actually ships -- 360x360, 390x390, 416x416, 454x454 -- for 10-15% more cells.
        // The four further round entries in resolutions.json are stale scaler config for
        // devices the manifest does not list (#19), and model to 0.00% as well.
        _rowFirst = new [_columnCount];
        _rowLast = new [_columnCount];

        var round = System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND;
        var radius = (_width < _height ? _width : _height) / 2.0;
        var halfColumn = _columnWidth / 2.0;
        var halfRow = _rowHeight / 2.0;

        for (var i = 0; i < _columnCount; ++i) {
            if (!round) {
                _rowFirst[i] = 0;
                _rowLast[i] = _rowCount - 1;
                continue;
            }
            // Horizontal distance from the centre to the cell's nearer vertical edge,
            // zero for the columns the vertical centre line passes through.
            var dx = ((i - _centerColumn) * _columnWidth).abs() - halfColumn;
            if (dx < 0.0) {
                dx = 0.0;
            }
            var span = radius * radius - dx * dx;
            if (span < 0) {
                // whole column is off the glass
                _rowFirst[i] = 0;
                _rowLast[i] = -1;
                continue;
            }
            // The grid is symmetric about the centre row, so the span is too: it reaches
            // the same number of rows above and below it. The half row added back is the
            // vertical half of the same rectangle test -- a row is in reach when its
            // nearer horizontal edge is inside the circle, not when its centre is.
            var reach = Math.floor((Math.sqrt(span) + halfRow) / _rowHeight).toNumber();
            if (reach > _centerRow) {
                reach = _centerRow;
            }
            _rowFirst[i] = _centerRow - reach;
            _rowLast[i] = _centerRow + reach;
        }

    }


    private function _generateCoordinates() {

        // A cell's pixel position never changes: its x depends only on the column and
        // its y only on the row. Precomputing both replaces the two multiplications
        // _drawTrails did per drawn cell -- some 320 a frame -- with two array reads
        // (#60).
        _columnX = new [_columnCount];
        for (var i = 0; i < _columnCount; ++i) {
            _columnX[i] = _originX + i * _columnWidth;
        }

        _rowY = new [_rowCount];
        for (var j = 0; j < _rowCount; ++j) {
            _rowY[j] = _originY + j * _rowHeight;
        }

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
    private function _drawTrails() {

        var dc = _dc,
            font = _matrixFont,
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


    private function _drawTime(x as Number, y as Number, font as Graphics.FontType, color as Graphics.ColorType, background as Graphics.ColorType) {

        var info = Gregorian.info(_time, Time.FORMAT_SHORT);
        var hour = info.hour;
        if (!System.getDeviceSettings().is24Hour) {
            // FORMAT_SHORT always yields 0-23; map to a 12-hour clock where 0 and 12 read as 12
            hour = ((hour + 11) % 12) + 1;
        }
        var time = Lang.format("$1$:$2$", [hour.format("%2d"), info.min.format("%02d")]);
        // _dc.setColor(_timeColor, Graphics.COLOR_TRANSPARENT);
        _dc.setColor(color, background);
        _dc.drawText(x, y, font, time, JUSTIFY);

    }


    private function _generateShades() {

        var steps = _rowCount / 2;
        var red = (_matrixColor >> RED_SHIFT) & MASK,
            green = (_matrixColor >> GREEN_SHIFT) & MASK,
            blue = (_matrixColor >> BLUE_SHIFT) & MASK;

        // The ramp fades linearly to black over `steps` rows and is black for the rest of
        // the ring, which `_drawTrails` skips (#8). The clamp is on `scale`, before it
        // reaches a channel, so with `scale` in [0, steps] and each channel in [0, 255]
        // every term is in range by construction.
        //
        // What it replaces -- `if (_shades[i] < 0) { _shades[i] = 0; }` on the packed
        // colour -- gave the same ramp for every `MATRIX_COLOR`, but only via a 32-bit
        // sign-propagation argument: past `steps` all three channels scale by the same
        // negative factor, and a channel in [-255, 0] still sets the sign bit after a
        // shift of 16 or less, so the OR is negative whenever any channel is. Correct,
        // and far too subtle to leave a colour change resting on (#9).
        _shades = new [_rowCount] as Array<Graphics.ColorType>;
        for (var i = 0; i < _rowCount; ++i) {
            var scale = steps - i;
            if (scale < 0) {
                scale = 0;
            }
            _shades[i] = ((red * scale / steps) << RED_SHIFT) |
                        ((green * scale / steps) << GREEN_SHIFT) |
                        ((blue * scale / steps) << BLUE_SHIFT);
        }

    }

}
