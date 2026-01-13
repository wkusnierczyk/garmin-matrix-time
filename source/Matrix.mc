using Toybox.Application;
using Toybox.Graphics;
using Toybox.Math;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi;

import Toybox.Lang; 


const 
    FONT = Application.loadResource(Rez.Fonts.Matrix) as Graphics.FontType,
    CHARSET = "abcdefghijklmnopqrstuvwxyz0123456789".toCharArray() as Array<Char>,
    CHARSET_SIZE = CHARSET.size(),
    COLOR = 0x00FF2B;

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
        _font = FONT,
        _color = COLOR,
        _shades as Array<Graphics.ColorType> or Null;

    private var
        _width as Number,
        _height as Number;

    private var
        _trails as Array<Array<Char>> or Null,
        _heads as Array<Number> or Null,
        _rowCount as Number or Null,
        _columnCount as Number or Null,
        _rowHeight as Number or Null,
        _columnWidth as Number or Null,
        _initialized as Boolean = false;

    private var _dc as Graphics.Dc or Null;


    function initialize() {
        var settings = System.getDeviceSettings();
        _width = settings.screenWidth;
        _height = settings.screenHeight;
    }


    function draw(dc as Graphics.Dc) as DigitalRain {

        _dc = dc;
        if (!_initialized) {
            _initialize();
        }

        _drawTrails();

        return self;
    }

    private function _initialize() as DigitalRain {

        _rowHeight = _dc.getFontHeight(_font);
        _columnWidth =  _dc.getTextWidthInPixels("0", _font);
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

        _initialized = true;

        return self;

    }


    private function _drawTrails() as DigitalRain {

        for (var i = 0; i < _columnCount; ++i) {
            var trail = _trails[i];
            var head = _heads[i];
            for (var j = 0; j < _rowCount; ++j) {
                var character = trail[j];
                var shade = _shades[(_rowCount + head - j) % _rowCount];
                _dc.setColor(shade, Graphics.COLOR_TRANSPARENT);
                _dc.drawText(i * _columnWidth, j * _rowHeight, _font, character.toString(), JUSTIFY);
            }
        }

        return _updateTrails();

    }

    private function _updateTrails() as DigitalRain {

        for (var i = 0; i < _columnCount; ++i) {
            _heads[i] = (_heads[i] + 1) % _rowCount;
            if (_heads[i] == 0) {
                // TODO regenerate trail, but careful about the still falling tail, it should not suddenl;y change
            }
        }

        return self;
    }


    private function _drawTime() as DigitalRain {
        // TODO
        return self;
    }


    private function _generateShades() {
        var steps = _rowCount / 2;
        var shades = new [_rowCount] as Array<Graphics.ColorType>;
        var red = (_color >> RED_SHIFT) & MASK,
            green = (_color >> GREEN_SHIFT) & MASK,
            blue = (_color >> BLUE_SHIFT) & MASK;
        for (var i = 0; i < _rowCount; ++i) {
            shades[i] = ((red * (steps - i) / steps) << RED_SHIFT) |
                        ((green * (steps - i) / steps) << GREEN_SHIFT) | 
                        ((blue * (steps - i) / steps) << BLUE_SHIFT);
            if (shades[i] < 0) {
                shades[i] = 0;
            }
        }        
        _shades = shades;
    }

}
