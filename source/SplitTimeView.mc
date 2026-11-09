import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Esfera "Split Time" con dos estilos:
//  A - Vertical: horas arriba y minutos abajo, separados por una linea de
//      color, con la fecha en el cuadrante derecho.
//  B - Horizontal: "9 05" en una linea, minutos en el color destacado y la
//      fecha debajo.
// La fecha usa los glifos pixelados de Pixel Time ("MO 12").
// Pensada para tactix 8 Solar / fenix 8 Solar 51 mm (MIP, 280x280).
class SplitTimeView extends WatchUi.WatchFace {

    // ---- Ajustes ---------------------------------------------------------
    // Color destacado: linea del estilo A y minutos del estilo B.
    const ACCENT_COLOR = 0xFF2D6F;
    // Pixeles libres entre la caja de las cifras y el borde circular. El hueco
    // visible es algo mayor (unos 10 px), porque la caja incluye el espaciado
    // lateral de la fuente.
    const EDGE_MARGIN = 6;
    // Fuentes vectoriales del sistema, por orden de preferencia.
    const FONT_FACES = ["BionicSemiBold", "RobotoCondensedBold"];
    // Altura de las cifras respecto al tamano em de la fuente (medido en el
    // simulador con BionicSemiBold).
    const CAP_RATIO = 0.495;
    // Estilo A: ancho y grosor de la linea respecto a la pantalla, y hueco
    // entre la linea y las cifras respecto a la altura de las cifras.
    const LINE_W_RATIO = 0.32;
    const LINE_T_RATIO = 0.015;
    const GAP_RATIO_A = 0.42;
    // Estilo B: hueco entre horas y minutos, y entre la hora y la fecha,
    // respecto a la altura de las cifras.
    const SPACE_RATIO_B = 0.3;
    const DATE_GAP_B = 0.4;
    // Bloque de la fecha pixelada en pixeles y margen con el borde derecho
    // (estilo A).
    const DATE_BLOCK = 3;
    const DATE_MARGIN = 12;
    // ----------------------------------------------------------------------

    const GLYPH_H = 5;

    // Etiquetas por dia de la semana (Gregorian: 1 = domingo ... 7 = sabado).
    const DAY_LABELS = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];
    const MONTH_LABELS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                          "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
    const WEEK_LABELS = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"];
    const MONTH_DAYS = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

    // Calendario del mes: se muestra al mantener pulsada la pantalla y se
    // oculta al volver a pulsar o cuando el reloj vuelve al reposo.
    var showCalendar as Boolean = false;
    // Meses de desplazamiento respecto al actual (-1 anterior, +1 siguiente).
    var monthOffset as Number = 0;

    // Glifos pixelados de Pixel Time: [ancho, fila0..fila4, (columna, fila*2)...].
    // Cada fila es una mascara de bits, el bit mas alto es la columna izquierda.
    private var _fontPixel as Dictionary<String, Array<Number>>;
    // Digitos pequenos 3x5 para los dias del calendario.
    private var _fontSmall as Dictionary<String, Array<Number>>;

    private var _fontA as Graphics.FontType = Graphics.FONT_NUMBER_THAI_HOT;
    private var _capA as Number = 0;
    private var _fontB as Graphics.FontType = Graphics.FONT_NUMBER_HOT;
    private var _capB as Number = 0;
    // Altura de las cifras de la ultima fuente calculada por fitFont.
    private var _capFit as Number = 0;

    function initialize() {
        WatchFace.initialize();
        _fontPixel = {
            "0" => [4, 0x6, 0x9, 0x9, 0x9, 0x6],
            "1" => [4, 0x2, 0x2, 0x2, 0x2, 0x2, 1, 3],
            "2" => [4, 0x6, 0x9, 0x2, 0x4, 0xF],
            "3" => [4, 0xE, 0x1, 0x6, 0x1, 0xE],
            "4" => [4, 0x9, 0x9, 0xF, 0x1, 0x1],
            "5" => [4, 0xF, 0x8, 0xE, 0x1, 0xE],
            "6" => [4, 0x6, 0x8, 0xE, 0x9, 0x6],
            "7" => [4, 0xF, 0x1, 0x2, 0x4, 0x4],
            "8" => [4, 0x6, 0x9, 0x6, 0x9, 0x6],
            "9" => [4, 0x6, 0x9, 0x7, 0x1, 0x6],
            " " => [1, 0x0, 0x0, 0x0, 0x0, 0x0],
            "M" => [5, 0x11, 0x1B, 0x15, 0x11, 0x11],
            "W" => [5, 0x11, 0x11, 0x15, 0x1B, 0x11],
            "O" => [4, 0x6, 0x9, 0x9, 0x9, 0x6],
            "T" => [3, 0x7, 0x2, 0x2, 0x2, 0x2],
            "U" => [4, 0x9, 0x9, 0x9, 0x9, 0x6],
            "E" => [4, 0xF, 0x8, 0xE, 0x8, 0xF],
            "H" => [4, 0x9, 0x9, 0xF, 0x9, 0x9],
            "F" => [4, 0xF, 0x8, 0xE, 0x8, 0x8],
            "R" => [4, 0xE, 0x9, 0xE, 0xA, 0x9],
            "S" => [4, 0x7, 0x8, 0x6, 0x1, 0xE],
            "A" => [4, 0x6, 0x9, 0xF, 0x9, 0x9],
            "N" => [4, 0x9, 0xD, 0xB, 0x9, 0x9],
            "B" => [4, 0xE, 0x9, 0xE, 0x9, 0xE],
            "P" => [4, 0xE, 0x9, 0xE, 0x8, 0x8],
            "L" => [4, 0x8, 0x8, 0x8, 0x8, 0xF],
            "G" => [4, 0x7, 0x8, 0xB, 0x9, 0x7],
            "C" => [4, 0x7, 0x8, 0x8, 0x8, 0x7],
            "D" => [4, 0xE, 0x9, 0x9, 0x9, 0xE],
            "J" => [4, 0x1, 0x1, 0x1, 0x9, 0x6],
            "Y" => [5, 0x11, 0x0A, 0x04, 0x04, 0x04],
            "V" => [5, 0x11, 0x11, 0x11, 0x0A, 0x04],
            "<" => [3, 0x1, 0x2, 0x4, 0x2, 0x1],
            ">" => [3, 0x4, 0x2, 0x1, 0x2, 0x4]
        } as Dictionary<String, Array<Number>>;

        _fontSmall = {
            "0" => [3, 0x7, 0x5, 0x5, 0x5, 0x7],
            "1" => [3, 0x2, 0x6, 0x2, 0x2, 0x7],
            "2" => [3, 0x7, 0x1, 0x7, 0x4, 0x7],
            "3" => [3, 0x7, 0x1, 0x3, 0x1, 0x7],
            "4" => [3, 0x5, 0x5, 0x7, 0x1, 0x1],
            "5" => [3, 0x7, 0x4, 0x7, 0x1, 0x7],
            "6" => [3, 0x7, 0x4, 0x7, 0x5, 0x7],
            "7" => [3, 0x7, 0x1, 0x2, 0x2, 0x2],
            "8" => [3, 0x7, 0x5, 0x7, 0x5, 0x7],
            "9" => [3, 0x7, 0x5, 0x7, 0x1, 0x7]
        } as Dictionary<String, Array<Number>>;
    }

    // Fuente vectorial del sistema (Bionic, la de los numeros de Garmin) con
    // el mayor tamano que deja EDGE_MARGIN pixeles libres hasta el borde
    // circular. Se calcula para el caso mas ancho ("88"), asi el tamano no
    // cambia con la hora.
    function onLayout(dc as Dc) as Void {
        var r = (dc.getWidth() < dc.getHeight() ? dc.getWidth() : dc.getHeight()) / 2.0 - EDGE_MARGIN;
        _fontA = fitFont(dc, r, false);
        _capA = _capFit;
        _fontB = fitFont(dc, r, true);
        _capB = _capFit;
    }

    // Busqueda binaria del mayor tamano que cabe en el circulo de radio r.
    // Sin fuentes vectoriales se usa la fuente numerica mayor del sistema.
    private function fitFont(dc as Dc, r as Float, horizontal as Boolean) as Graphics.FontType {
        var best = null;
        var bestSize = 0;
        if (Graphics has :getVectorFont) {
            var lo = 20;
            var hi = 400;
            while (lo <= hi) {
                var size = (lo + hi) / 2;
                var f = Graphics.getVectorFont({:face => FONT_FACES, :size => size});
                if (f == null) {
                    break;
                }
                var cap = (size * CAP_RATIO).toNumber();
                var tw = dc.getTextWidthInPixels("88", f).toFloat();
                var hx;
                var hy;
                if (horizontal) {
                    // Bloque "88 88" centrado: esquinas a (ancho/2, cifra/2).
                    hx = (2 * tw + spaceB(cap)) / 2.0;
                    hy = cap / 2.0;
                } else {
                    // Esquina exterior de las horas (o de los minutos).
                    hx = tw / 2.0;
                    hy = (gapA(cap) + cap).toFloat();
                }
                if (hx * hx + hy * hy <= r * r) {
                    best = f;
                    bestSize = size;
                    lo = size + 1;
                } else {
                    hi = size - 1;
                }
            }
        }
        if (best == null) {
            var sys = horizontal ? Graphics.FONT_NUMBER_HOT : Graphics.FONT_NUMBER_THAI_HOT;
            _capFit = (Graphics.getFontAscent(sys) * 0.95).toNumber();
            return sys;
        }
        _capFit = (bestSize * CAP_RATIO).toNumber();
        return best;
    }

    // Hueco entre la linea y las cifras (estilo A).
    private function gapA(cap as Number) as Number {
        return (cap * GAP_RATIO_A).toNumber();
    }

    // Hueco entre horas y minutos (estilo B).
    private function spaceB(cap as Number) as Number {
        return (cap * SPACE_RATIO_B).toNumber();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var dark = isDarkMode();
        var bg = dark ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
        var fg = dark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        dc.setColor(bg, bg);
        dc.clear();
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);

        if (showCalendar) {
            drawCalendar(dc, w, h);
            return;
        }

        var settings = System.getDeviceSettings();
        var clock = System.getClockTime();
        var hour = clock.hour;
        if (!settings.is24Hour) {
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }
        var mText = clock.min.format("%02d");

        // Fecha "MO 12"
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var date = DAY_LABELS[(info.day_of_week as Number) - 1] + " " + info.day.toString();

        if (getStyle() == STYLE_HORIZONTAL) {
            // Hora sin cero delante, como en "9 05".
            drawHorizontal(dc, w, h, hour.toString(), mText, date, fg);
        } else {
            var hText = settings.is24Hour ? hour.format("%02d") : hour.toString();
            drawVertical(dc, w, h, hText, mText, date, fg);
        }
    }

    // Estilo A: horas arriba, minutos abajo, linea en el centro y fecha en el
    // cuadrante derecho.
    private function drawVertical(dc as Dc, w as Number, h as Number, hText as String,
                                  mText as String, date as String, fg as Number) as Void {
        var cx = w / 2;
        var cy = h / 2;
        var gap = gapA(_capA);
        // drawText coloca el texto por la parte superior de la caja; la base
        // de las cifras queda a "ascent" de ahi.
        var ascent = Graphics.getFontAscent(_fontA);
        // Horas: la base de las cifras queda "gap" por encima de la linea.
        dc.drawText(cx, cy - gap - ascent, _fontA, hText, Graphics.TEXT_JUSTIFY_CENTER);
        // Minutos: la parte alta de las cifras queda "gap" por debajo.
        dc.drawText(cx, cy + gap + _capA - ascent, _fontA, mText, Graphics.TEXT_JUSTIFY_CENTER);

        // ---- Linea central ----
        var lineW = (w * LINE_W_RATIO).toNumber();
        var lineT = (h * LINE_T_RATIO + 0.5).toNumber();
        if (lineT < 2) {
            lineT = 2;
        }
        var lineX = cx - lineW / 2;
        dc.setColor(ACCENT_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lineX, cy - lineT / 2, lineW, lineT);

        // ---- Fecha centrada entre el final de la linea y el borde ----
        var dw = measure(_fontPixel, date, 1) * DATE_BLOCK;
        var left = lineX + lineW;
        var right = w - DATE_MARGIN;
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        drawText(dc, _fontPixel, date, left + (right - left - dw) / 2,
                 cy - GLYPH_H * DATE_BLOCK / 2, DATE_BLOCK, 1);
    }

    // Estilo B: "9 05" en una linea, horas en el color del texto y minutos en
    // el color destacado; la fecha pixelada debajo.
    private function drawHorizontal(dc as Dc, w as Number, h as Number, hText as String,
                                    mText as String, date as String, fg as Number) as Void {
        var cx = w / 2;
        var cy = h / 2;
        var space = spaceB(_capB);
        var hw = dc.getTextWidthInPixels(hText, _fontB);
        var mw = dc.getTextWidthInPixels(mText, _fontB);
        var x = cx - (hw + space + mw) / 2;
        // Cifras centradas verticalmente en la pantalla.
        var y = cy + _capB / 2 - Graphics.getFontAscent(_fontB);
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, _fontB, hText, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(ACCENT_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + hw + space, y, _fontB, mText, Graphics.TEXT_JUSTIFY_LEFT);

        var dw = measure(_fontPixel, date, 1) * DATE_BLOCK;
        var dy = cy + _capB / 2 + (_capB * DATE_GAP_B).toNumber();
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        drawText(dc, _fontPixel, date, cx - dw / 2, dy, DATE_BLOCK, 1);
    }

    // Dia de la semana (0 = domingo ... 6 = sabado), algoritmo de Sakamoto.
    private function dayOfWeek(y as Number, m as Number, d as Number) as Number {
        var t = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4];
        if (m < 3) {
            y -= 1;
        }
        return (y + y / 4 - y / 100 + y / 400 + t[m - 1] + d) % 7;
    }

    // Mes completo (semana de lunes a domingo) con el dia de hoy subrayado
    // en el color de la linea.
    private function drawCalendar(dc as Dc, w as Number, h as Number) as Void {
        var p = (w >= 240) ? 3 : 2;  // bloque de los numeros
        var wp = p - 1;              // bloque de las iniciales de la semana
        var cellW = 7 * p;           // dos digitos de 3 + 1 de hueco
        var pitch = cellW + 3 * p;   // ancho de columna con separacion
        var gridW = 7 * pitch - 3 * p;
        var rowH = 8 * p;            // 5 de digito + hueco + subrayado + hueco

        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var total = (info.year as Number) * 12 + (info.month as Number) - 1 + monthOffset;
        var year = total / 12;
        var month = total % 12 + 1;
        var day = (monthOffset == 0) ? info.day as Number : 0;

        var days = MONTH_DAYS[month - 1];
        if (month == 2 && ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0)) {
            days = 29;
        }
        var firstCol = (dayOfWeek(year, month, 1) + 6) % 7;

        // Altura calculada siempre para 6 semanas, para que la cabecera no salte.
        var totalH = 5 * p + 3 * p + 5 * wp + 3 * p + 6 * rowH - 3 * p;
        var y = (h - totalH) / 2;
        var left = (w - gridW) / 2;

        var title = MONTH_LABELS[month - 1] + " " + year.toString();
        drawText(dc, _fontPixel, title, (w - measure(_fontPixel, title, 1) * p) / 2, y, p, 1);
        drawText(dc, _fontPixel, "<", left, y, p, 1);
        drawText(dc, _fontPixel, ">", left + gridW - 3 * p, y, p, 1);
        y += 8 * p;

        for (var c = 0; c < 7; c++) {
            var lw = measure(_fontPixel, WEEK_LABELS[c], 1) * wp;
            drawText(dc, _fontPixel, WEEK_LABELS[c], left + c * pitch + (cellW - lw) / 2, y, wp, 1);
        }
        y += 5 * wp + 3 * p;

        for (var d = 1; d <= days; d++) {
            var idx = firstCol + d - 1;
            var cx = left + (idx % 7) * pitch;
            var cy = y + (idx / 7) * rowH;
            var s = d.toString();
            var tw = measure(_fontSmall, s, 1) * p;
            drawText(dc, _fontSmall, s, cx + (cellW - tw) / 2, cy, p, 1);
            if (d == day) {
                var fg = isDarkMode() ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
                dc.setColor(ACCENT_COLOR, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(cx, cy + 6 * p, cellW, p);
                dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
            }
        }
    }

    // Ancho en bloques de un texto.
    private function measure(font as Dictionary<String, Array<Number>>, text as String, spacing as Number) as Number {
        var chars = text.toCharArray();
        var total = 0;
        for (var i = 0; i < chars.size(); i++) {
            var g = font[chars[i].toString()];
            if (g != null) {
                total += g[0];
                if (i > 0) {
                    total += spacing;
                }
            }
        }
        return total;
    }

    private function drawText(dc as Dc, font as Dictionary<String, Array<Number>>, text as String,
                              x as Number, y as Number, block as Number, spacing as Number) as Void {
        var chars = text.toCharArray();
        for (var i = 0; i < chars.size(); i++) {
            var g = font[chars[i].toString()];
            if (g != null) {
                drawGlyph(dc, g, x, y, block);
                x += (g[0] + spacing) * block;
            }
        }
    }

    private function drawGlyph(dc as Dc, g as Array<Number>, x as Number, y as Number, block as Number) as Void {
        var gw = g[0];
        for (var r = 0; r < GLYPH_H; r++) {
            var bits = g[r + 1];
            var col = 0;
            while (col < gw) {
                if ((bits & (1 << (gw - 1 - col))) != 0) {
                    var start = col;
                    while (col < gw && (bits & (1 << (gw - 1 - col))) != 0) {
                        col++;
                    }
                    dc.fillRectangle(x + start * block, y + r * block, (col - start) * block, block);
                } else {
                    col++;
                }
            }
        }
        for (var i = GLYPH_H + 1; i + 1 < g.size(); i += 2) {
            dc.fillRectangle(x + g[i] * block, y + (g[i + 1] * block) / 2, block, block);
        }
    }

    // En MIP la esfera se refresca una vez por minuto; no hace falta nada mas.
    function onEnterSleep() as Void {
        if (showCalendar) {
            showCalendar = false;
            monthOffset = 0;
            WatchUi.requestUpdate();
        }
    }

    function onExitSleep() as Void {
    }
}
