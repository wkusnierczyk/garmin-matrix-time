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
    CHARSET = "abcdefghijklmnopqrstuvwxyz0123456789".toCharArray() as Array<Char>,
    CHARSET_SIZE = CHARSET.size(),
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


class DigitalRain {

    private var 
        _timeColor = TIME_COLOR,
        _timeFont = TIME_FONT,
        _matrixFont = MATRIX_FONT,
        _matrixColor = MATRIX_COLOR,
        _shades as Array<Graphics.ColorType> or Null;

    private var
        _width as Number,
        _height as Number,
        _centerX as Number,
        _centerY as Number;

    private var
        _trails as Array<Array<Char>> or Null,
        _heads as Array<Number> or Null,
        _rowFirst as Array<Number> or Null,
        _rowLast as Array<Number> or Null,
        _rowCount as Number or Null,
        _columnCount as Number or Null,
        _rowHeight as Number or Null,
        _columnWidth as Number or Null,
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
        _drawTime();

        return self;

    }


    private function _initialize() {

        _rowHeight = _dc.getFontHeight(_matrixFont);
        _columnWidth =  _dc.getTextWidthInPixels("0", _matrixFont);
        _rowCount = _height / _rowHeight + 1;
        _columnCount = _width / _columnWidth + 1;

        _trails = new [_columnCount] as Array<Array<Char>>;
        _heads = new [_columnCount];

        for (var i = 0; i < _columnCount; ++i) {
            _trails[i] = new [_rowCount] as Array<Char>;
            for (var j = 0; j < _rowCount; ++j) {
                var index = Math.rand() % CHARSET_SIZE;
                _trails[i][j] = CHARSET[index];
            }
            _heads[i] = Math.rand() % _rowCount;
        }

        _generateShades();
        _generateSpans();

        _initialized = true;

    }


    private function _generateSpans() {

        // On a round display the grid's corners fall outside the glass. Precompute,
        // per column, the first and last row whose cell centre is actually on the
        // display, so _drawTrails can skip the rest instead of drawing off-screen.
        _rowFirst = new [_columnCount];
        _rowLast = new [_columnCount];

        var round = System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND;
        var radius = (_width < _height ? _width : _height) / 2.0;

        for (var i = 0; i < _columnCount; ++i) {
            if (!round) {
                _rowFirst[i] = 0;
                _rowLast[i] = _rowCount - 1;
                continue;
            }
            var dx = i * _columnWidth - _centerX;
            var span = radius * radius - dx * dx;
            if (span < 0) {
                // whole column is off the glass
                _rowFirst[i] = 0;
                _rowLast[i] = -1;
                continue;
            }
            var dy = Math.sqrt(span);
            var first = Math.ceil((_centerY - dy) / _rowHeight).toNumber();
            var last = Math.floor((_centerY + dy) / _rowHeight).toNumber();
            _rowFirst[i] = first < 0 ? 0 : first;
            _rowLast[i] = last > _rowCount - 1 ? _rowCount - 1 : last;
        }

    }


    private function _drawTrails() {

        for (var i = 0; i < _columnCount; ++i) {
            var trail = _trails[i];
            var head = _heads[i];
            for (var j = _rowFirst[i]; j <= _rowLast[i]; ++j) {
                var shade = _shades[(_rowCount + head - j) % _rowCount];
                if (shade == 0) {
                    // The ramp fades to black over half a screen, so the far half of
                    // every trail is 0x000000. Drawing that on a black background
                    // paints nothing -- skip it rather than pay for setColor+drawText.
                    continue;
                }
                var character = trail[j];
                _dc.setColor(shade, Graphics.COLOR_TRANSPARENT);
                _dc.drawText(i * _columnWidth, j * _rowHeight, _matrixFont, character.toString(), JUSTIFY);
            }
            _heads[i] = (_heads[i] + 1) % _rowCount;

            // Change one random character in the trail to a new random character
            trail[Math.rand() % _rowCount] = CHARSET[Math.rand() % CHARSET_SIZE];
        }

    }


    private function _drawTime() {

        var info = Gregorian.info(_time, Time.FORMAT_SHORT);
        var hour = info.hour;
        if (!System.getDeviceSettings().is24Hour) {
            // FORMAT_SHORT always yields 0-23; map to a 12-hour clock where 0 and 12 read as 12
            hour = ((hour + 11) % 12) + 1;
        }
        var time = Lang.format("$1$:$2$", [hour.format("%2d"), info.min.format("%02d")]);
        // _dc.setColor(_timeColor, Graphics.COLOR_TRANSPARENT);
        _dc.setColor(_timeColor, Graphics.COLOR_BLACK);
        _dc.drawText(_centerX, _centerY, _timeFont, time, JUSTIFY);

    }


    private function _generateShades() {

        var steps = _rowCount / 2;
        var red = (_matrixColor >> RED_SHIFT) & MASK,
            green = (_matrixColor >> GREEN_SHIFT) & MASK,
            blue = (_matrixColor >> BLUE_SHIFT) & MASK;
        
        _shades = new [_rowCount] as Array<Graphics.ColorType>;
        for (var i = 0; i < _rowCount; ++i) {
            _shades[i] = ((red * (steps - i) / steps) << RED_SHIFT) |
                        ((green * (steps - i) / steps) << GREEN_SHIFT) | 
                        ((blue * (steps - i) / steps) << BLUE_SHIFT);
            if (_shades[i] < 0) {
                _shades[i] = 0;
            }
        }        

    }

}
