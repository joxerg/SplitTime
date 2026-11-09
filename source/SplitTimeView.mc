import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Esfera "Split Time" con dos estilos:
//  A - Vertical: horas arriba y minutos abajo, separados por una linea, con
//      la fecha en el cuadrante derecho.
//  B - Horizontal: "9:05" en una linea, con la fecha debajo.
// Todo en blanco sobre negro o negro sobre blanco. La fuente de la hora se
// elige en los ajustes, con opcion de negrita. La fecha ("MO 12") y el
// calendario usan Roboto Condensed.
// Pensada para tactix 8 Solar / fenix 8 Solar 51 mm (MIP, 280x280).
class SplitTimeView extends WatchUi.WatchFace {

    // ---- Ajustes ---------------------------------------------------------
    // Pixeles libres entre la caja de las cifras y el borde circular. El hueco
    // visible es algo mayor (unos 10 px), porque la caja incluye el espaciado
    // lateral de la fuente.
    const EDGE_MARGIN = 6;
    // Estilo A: ancho y grosor de la linea respecto a la pantalla, y hueco
    // entre la linea y las cifras respecto a la altura de las cifras.
    const LINE_W_RATIO = 0.32;
    const LINE_T_RATIO = 0.015;
    const GAP_RATIO_A = 0.42;
    // Estilo B: hueco entre la hora y la fecha, respecto a la altura de las
    // cifras.
    const DATE_GAP_B = 0.4;
    // Negrita simulada (fuentes sin version negrita): grosor extra del trazo
    // respecto al tamano de la fuente.
    const BOLD_RATIO = 0.035;
    // Fecha: fuente, tamano (px) por estilo y margen con el borde derecho
    // (estilo A).
    const TEXT_FACES = ["RobotoCondensedBold"];
    const DATE_SIZE_A = 26;
    const DATE_SIZE_B = 30;
    const DATE_MARGIN = 12;
    // Calendario: tamano (px) de la cabecera, iniciales y numeros.
    const CAL_TITLE_SIZE = 28;
    const CAL_WEEK_SIZE = 19;
    const CAL_DAY_SIZE = 25;
    // Gris de la marca del dia de hoy: oscuro con fondo negro y claro con
    // fondo blanco, para que el numero se siga leyendo encima.
    const TODAY_DARK = Graphics.COLOR_DK_GRAY;
    const TODAY_LIGHT = Graphics.COLOR_LT_GRAY;
    // ----------------------------------------------------------------------

    // Fuentes de la hora (mismo orden que FONT_* en SplitTimeApp.mc): cara
    // normal, cara negrita (null = negrita simulada), y donde empiezan y
    // cuanto miden las cifras respecto al tamano em. Medido en el simulador
    // a 100 px.
    const FONT_REGULAR = ["BionicSemiBold", "RobotoCondensedRegular", "KosugiRegular",
                          "NanumGothicExtraBold", "NotoSansSCMedium"];
    const FONT_BOLD = [null, "RobotoCondensedBold", null, null, null];
    const FONT_TOP = [0.23, 0.18, 0.10, 0.16, 0.27];
    const FONT_CAP = [0.50, 0.62, 0.76, 0.71, 0.52];

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

    // Fuente de la hora por estilo, con la distancia de la caja a la parte
    // alta de las cifras (top), la altura de las cifras (cap) y el grosor de
    // la negrita simulada (bold, 0 si no hace falta).
    private var _fontA as Graphics.FontType = Graphics.FONT_NUMBER_THAI_HOT;
    private var _topA as Number = 0;
    private var _capA as Number = 0;
    private var _boldA as Number = 0;
    private var _fontB as Graphics.FontType = Graphics.FONT_NUMBER_HOT;
    private var _topB as Number = 0;
    private var _capB as Number = 0;
    private var _boldB as Number = 0;
    // Resultado de la ultima llamada a fitFont.
    private var _fitTop as Number = 0;
    private var _fitCap as Number = 0;
    private var _fitBold as Number = 0;
    // Fuente y negrita con las que se calcularon las fuentes de la hora.
    private var _fontKey as Number = -1;
    // Fuentes de texto (fecha y calendario).
    private var _dateA as Graphics.FontType = Graphics.FONT_SMALL;
    private var _dateB as Graphics.FontType = Graphics.FONT_MEDIUM;
    private var _calTitle as Graphics.FontType = Graphics.FONT_SMALL;
    private var _calWeek as Graphics.FontType = Graphics.FONT_XTINY;
    private var _calDay as Graphics.FontType = Graphics.FONT_TINY;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        layoutTime(dc);
        _dateA = textFont(DATE_SIZE_A, Graphics.FONT_SMALL);
        _dateB = textFont(DATE_SIZE_B, Graphics.FONT_MEDIUM);
        _calTitle = textFont(CAL_TITLE_SIZE, Graphics.FONT_SMALL);
        _calWeek = textFont(CAL_WEEK_SIZE, Graphics.FONT_XTINY);
        _calDay = textFont(CAL_DAY_SIZE, Graphics.FONT_TINY);
    }

    // Fuentes de la hora con el mayor tamano que deja EDGE_MARGIN pixeles
    // libres hasta el borde circular. Se calcula para el caso mas ancho
    // ("88" / "88:88"), asi el tamano no cambia con la hora. Se repite cuando
    // cambian la fuente o la negrita en los ajustes.
    private function layoutTime(dc as Dc) as Void {
        var font = getTimeFont();
        var bold = isBold();
        _fontKey = font * 2 + (bold ? 1 : 0);
        var r = (dc.getWidth() < dc.getHeight() ? dc.getWidth() : dc.getHeight()) / 2.0 - EDGE_MARGIN;
        _fontA = fitFont(dc, r, font, bold, false);
        _topA = _fitTop;
        _capA = _fitCap;
        _boldA = _fitBold;
        _fontB = fitFont(dc, r, font, bold, true);
        _topB = _fitTop;
        _capB = _fitCap;
        _boldB = _fitBold;
    }

    // Roboto Condensed vectorial al tamano pedido, o la fuente del sistema
    // indicada si no hay fuentes vectoriales.
    private function textFont(size as Number, fallback as Graphics.FontType) as Graphics.FontType {
        if (Graphics has :getVectorFont) {
            var f = Graphics.getVectorFont({:face => TEXT_FACES, :size => size});
            if (f != null) {
                return f;
            }
        }
        return fallback;
    }

    // Busqueda binaria del mayor tamano que cabe en el circulo de radio r.
    // Sin fuentes vectoriales se usa la fuente numerica mayor del sistema.
    private function fitFont(dc as Dc, r as Float, font as Number, bold as Boolean,
                             horizontal as Boolean) as Graphics.FontType {
        var face = FONT_REGULAR[font];
        var fake = false;
        if (bold) {
            if (FONT_BOLD[font] != null) {
                face = FONT_BOLD[font];
            } else {
                fake = true;
            }
        }
        var best = null;
        var bestSize = 0;
        if (Graphics has :getVectorFont) {
            var lo = 20;
            var hi = 400;
            while (lo <= hi) {
                var size = (lo + hi) / 2;
                var f = Graphics.getVectorFont({:face => [face, "RobotoCondensedBold"], :size => size});
                if (f == null) {
                    break;
                }
                var k = fake ? boldPx(size) : 0;
                var cap = (size * FONT_CAP[font]).toNumber() + k;
                var tw = timeWidth(dc, horizontal ? "88:88" : "88", f, k).toFloat();
                var hx = tw / 2.0;
                // B: bloque centrado. A: esquina exterior de horas o minutos.
                var hy = horizontal ? cap / 2.0 : (gapA(cap) + cap).toFloat();
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
            _fitCap = (Graphics.getFontAscent(sys) * 0.95).toNumber();
            _fitTop = Graphics.getFontAscent(sys) - _fitCap;
            _fitBold = 0;
            return sys;
        }
        _fitBold = fake ? boldPx(bestSize) : 0;
        _fitCap = (bestSize * FONT_CAP[font]).toNumber() + _fitBold;
        _fitTop = (bestSize * FONT_TOP[font]).toNumber();
        return best;
    }

    private function boldPx(size as Number) as Number {
        var k = (size * BOLD_RATIO + 0.5).toNumber();
        return k < 1 ? 1 : k;
    }

    // Hueco entre la linea y las cifras (estilo A).
    private function gapA(cap as Number) as Number {
        return (cap * GAP_RATIO_A).toNumber();
    }

    // Trozos que se dibujan por separado: "23:59" -> ["23", ":", "59"]. Con
    // negrita simulada, cada trozo ocupa "bold" pixeles mas, asi los dos
    // puntos no se pegan a las cifras.
    private function timeParts(text as String) as Array<String> {
        var i = text.find(":");
        if (i == null) {
            return [text];
        }
        return [text.substring(0, i) as String, ":", text.substring(i + 1, text.length()) as String];
    }

    // Ancho de un texto de la hora.
    private function timeWidth(dc as Dc, text as String, font as Graphics.FontType, bold as Number) as Number {
        if (bold == 0) {
            return dc.getTextWidthInPixels(text, font);
        }
        var parts = timeParts(text);
        var total = 0;
        for (var p = 0; p < parts.size(); p++) {
            total += dc.getTextWidthInPixels(parts[p], font) + bold;
        }
        return total;
    }

    // Desplazamientos de la negrita simulada, en fracciones del grosor: el
    // borde de un cuadrado (esquinas y puntos medios). Con 8 copias el trazo
    // engorda sin huecos visibles y el dibujo sigue siendo ligero.
    const BOLD_DX = [0, 1, 2, 2, 2, 1, 0, 0];
    const BOLD_DY = [0, 0, 0, 1, 2, 2, 2, 1];

    // Dibuja la hora centrada en x, con la parte alta de las cifras en "top".
    private function drawTime(dc as Dc, x as Number, top as Number, font as Graphics.FontType,
                              fontTop as Number, bold as Number, text as String) as Void {
        var y = top - fontTop;
        if (bold == 0) {
            dc.drawText(x, y, font, text, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        var parts = timeParts(text);
        var px = x - timeWidth(dc, text, font, bold) / 2;
        var l = Graphics.TEXT_JUSTIFY_LEFT;
        for (var p = 0; p < parts.size(); p++) {
            for (var i = 0; i < 8; i++) {
                dc.drawText(px + BOLD_DX[i] * bold / 2, y + BOLD_DY[i] * bold / 2, font, parts[p], l);
            }
            px += dc.getTextWidthInPixels(parts[p], font) + bold;
        }
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

        if (getTimeFont() * 2 + (isBold() ? 1 : 0) != _fontKey) {
            layoutTime(dc);
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
            // Hora sin cero delante, como en "9:05".
            drawHorizontal(dc, w, h, hour.toString() + ":" + mText, date);
        } else {
            var hText = settings.is24Hour ? hour.format("%02d") : hour.toString();
            drawVertical(dc, w, h, hText, mText, date);
        }
    }

    // Estilo A: horas arriba, minutos abajo, linea en el centro y fecha en el
    // cuadrante derecho.
    private function drawVertical(dc as Dc, w as Number, h as Number, hText as String,
                                  mText as String, date as String) as Void {
        var cx = w / 2;
        var cy = h / 2;
        var gap = gapA(_capA);
        // Horas: la base de las cifras queda "gap" por encima de la linea.
        drawTime(dc, cx, cy - gap - _capA, _fontA, _topA, _boldA, hText);
        // Minutos: la parte alta de las cifras queda "gap" por debajo.
        drawTime(dc, cx, cy + gap, _fontA, _topA, _boldA, mText);

        // ---- Linea central ----
        var lineW = (w * LINE_W_RATIO).toNumber();
        var lineT = (h * LINE_T_RATIO + 0.5).toNumber();
        if (lineT < 2) {
            lineT = 2;
        }
        var lineX = cx - lineW / 2;
        dc.fillRectangle(lineX, cy - lineT / 2, lineW, lineT);

        // ---- Fecha centrada entre el final de la linea y el borde ----
        var left = lineX + lineW;
        var right = w - DATE_MARGIN;
        dc.drawText((left + right) / 2, cy, _dateA, date,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Estilo B: "9:05" en una linea, con la fecha debajo.
    private function drawHorizontal(dc as Dc, w as Number, h as Number, time as String,
                                    date as String) as Void {
        var cx = w / 2;
        var cy = h / 2;
        // Cifras centradas verticalmente en la pantalla.
        drawTime(dc, cx, cy - _capB / 2, _fontB, _topB, _boldB, time);

        // Fecha debajo: la parte alta de las mayusculas a DATE_GAP_B de la hora.
        var dy = cy + _capB / 2 + (_capB * DATE_GAP_B).toNumber();
        dc.drawText(cx, dy - capOffset(_dateB, DATE_SIZE_B), _dateB, date, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Distancia entre la parte alta de la caja de texto y la de las
    // mayusculas (Roboto: mayusculas de ~0.71 em).
    private function capOffset(font as Graphics.FontType, size as Number) as Number {
        return Graphics.getFontAscent(font) - (size * 0.71).toNumber();
    }

    // Dia de la semana (0 = domingo ... 6 = sabado), algoritmo de Sakamoto.
    private function dayOfWeek(y as Number, m as Number, d as Number) as Number {
        var t = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4];
        if (m < 3) {
            y -= 1;
        }
        return (y + y / 4 - y / 100 + y / 400 + t[m - 1] + d) % 7;
    }

    // Mes completo (semana de lunes a domingo) con el dia de hoy marcado en
    // gris.
    private function drawCalendar(dc as Dc, w as Number, h as Number) as Void {
        var pitch = 29;              // ancho de columna
        var cellW = 24;              // ancho de la celda de cada numero
        var gridW = 6 * pitch + cellW;
        var rowH = 24;               // alto de cada semana
        var titleCap = (CAL_TITLE_SIZE * 0.71).toNumber();
        var weekCap = (CAL_WEEK_SIZE * 0.71).toNumber();
        var dayCap = (CAL_DAY_SIZE * 0.71).toNumber();
        var vc = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

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
        var totalH = titleCap + 14 + weekCap + 10 + 6 * rowH;
        var y = (h - totalH) / 2;
        var left = (w - gridW) / 2;

        // Cabecera: "<  NOV 2026  >". Las flechas marcan las zonas de pulsacion.
        var ty = y + titleCap / 2;
        dc.drawText(w / 2, ty, _calTitle, MONTH_LABELS[month - 1] + " " + year.toString(), vc);
        dc.drawText(left + cellW / 2, ty, _calTitle, "<", vc);
        dc.drawText(left + gridW - cellW / 2, ty, _calTitle, ">", vc);
        y += titleCap + 14;

        for (var c = 0; c < 7; c++) {
            dc.drawText(left + c * pitch + cellW / 2, y + weekCap / 2, _calWeek, WEEK_LABELS[c], vc);
        }
        y += weekCap + 10;

        for (var d = 1; d <= days; d++) {
            var idx = firstCol + d - 1;
            var cx = left + (idx % 7) * pitch;
            var cy = y + (idx / 7) * rowH;
            if (d == day) {
                // Marca gris detras de todo el numero, bajo el texto.
                dc.setColor(isDarkMode() ? TODAY_DARK : TODAY_LIGHT, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(cx - 2, cy - 4, cellW + 4, dayCap + 8, 3);
                dc.setColor(isDarkMode() ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(cx + cellW / 2, cy + dayCap / 2, _calDay, d.toString(), vc);
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
