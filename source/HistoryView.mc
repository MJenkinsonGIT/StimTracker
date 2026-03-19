// HistoryView.mc
// 30-day scrollable history list, per-day detail view, and dose editor.

import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.System;

// ── History List ─────────────────────────────────────────────────────────────

class HistoryView extends WatchUi.View {

    private const CX       = 227;
    private const ROW_H    = 77;
    private const LIST_TOP = 58;
    private const ROWS_VIS = 5;

    var _days      as Array<String>;
    var _scrollPos as Number;

    function initialize(days as Array<String>) {
        View.initialize();
        _days      = _sortDesc(days);
        _scrollPos = 0;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 30, Graphics.FONT_XTINY,
            "30 Day History",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (_days.size() == 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(CX, 200, Graphics.FONT_SMALL, "No data yet",
                Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        for (var i = 0; i < ROWS_VIS; i++) {
            var dayIdx = _scrollPos + i;
            if (dayIdx >= _days.size()) { break; }

            var dateStr = _days[dayIdx] as String;
            var events  = StimTrackerStorage.loadDayLog(dateStr);
            var total   = 0;
            for (var e = 0; e < events.size(); e++) {
                total += (events[e] as Dictionary)["caffeineMg"] as Number;
            }
            var doseWord = events.size() == 1 ? " dose" : " doses";
            var label    = _formatDate(dateStr) + " | "
                         + total.toString() + "mg "
                         + events.size().toString() + doseWord;

            var y = LIST_TOP + i * ROW_H;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(CX, y + ROW_H / 2, Graphics.FONT_XTINY,
                label,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(40, y + ROW_H - 1, 414, y + ROW_H - 1);
        }

        if (_scrollPos > 0) {
            ArrowUtils.drawUpArrow(dc, CX, 46, ArrowUtils.HINT_ARROW_SIZE,
                Graphics.COLOR_LT_GRAY);
        }
        var bottomY = LIST_TOP + ROWS_VIS * ROW_H + 10;
        if (_scrollPos + ROWS_VIS < _days.size() && bottomY < 420) {
            ArrowUtils.drawDownArrow(dc, CX, bottomY, ArrowUtils.HINT_ARROW_SIZE,
                Graphics.COLOR_LT_GRAY);
        }
    }

    function rowForTapY(tapY as Number) as Number {
        if (tapY < LIST_TOP) { return -1; }
        var idx = _scrollPos + ((tapY - LIST_TOP) / ROW_H);
        if (idx >= _days.size()) { return -1; }
        return idx;
    }

    function dateForRow(rowIdx as Number) as String {
        return _days[rowIdx] as String;
    }

    function scrollDown() as Void {
        if (_scrollPos + ROWS_VIS < _days.size()) {
            _scrollPos++;
            WatchUi.requestUpdate();
        }
    }

    function scrollUp() as Void {
        if (_scrollPos > 0) {
            _scrollPos--;
            WatchUi.requestUpdate();
        }
    }

    private function _formatDate(dateStr as String) as String {
        var y2 = dateStr.substring(2, 4);
        var m  = dateStr.substring(4, 6).toNumber();
        var d  = dateStr.substring(6, 8).toNumber();
        return m.toString() + "/" + d.toString() + "/" + y2;
    }

    private function _sortDesc(days as Array<String>) as Array<String> {
        var arr = days.slice(0, null);
        for (var i = 0; i < arr.size() - 1; i++) {
            for (var j = 0; j < arr.size() - 1 - i; j++) {
                if ((arr[j] as String).compareTo(arr[j + 1] as String) < 0) {
                    var tmp    = arr[j];
                    arr[j]     = arr[j + 1];
                    arr[j + 1] = tmp;
                }
            }
        }
        return arr;
    }
}

class HistoryDelegate extends WatchUi.BehaviorDelegate {

    private var _view as HistoryView;

    function initialize(view as HistoryView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onNextPage() as Boolean {
        _view.scrollDown();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.scrollUp();
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var tapY   = coords[1];
        var rowIdx = _view.rowForTapY(tapY);
        if (rowIdx < 0) { return false; }
        var dateStr    = _view.dateForRow(rowIdx);
        var detailView = new DayDetailView(dateStr);
        WatchUi.pushView(
            detailView,
            new DayDetailDelegate(detailView),
            WatchUi.SLIDE_LEFT
        );
        return true;
    }
}

// ── Day Detail ────────────────────────────────────────────────────────────────

class DayDetailView extends WatchUi.View {

    private const CX       = 227;
    private const ROW_H    = 66;
    private const LIST_TOP = 95;
    private const ROWS_VIS = 5;

    var _dateStr   as String;
    var _events    as Array<Dictionary>;
    var _scrollPos as Number;

    function initialize(dateStr as String) {
        View.initialize();
        _dateStr   = dateStr;
        _events    = StimTrackerStorage.loadDayLog(dateStr);
        _scrollPos = 0;
    }

    function scrollDown() as Void {
        if (_scrollPos + ROWS_VIS < _events.size()) {
            _scrollPos++;
            WatchUi.requestUpdate();
        }
    }

    function scrollUp() as Void {
        if (_scrollPos > 0) {
            _scrollPos--;
            WatchUi.requestUpdate();
        }
    }

    function rowForTapY(tapY as Number) as Number {
        if (tapY < LIST_TOP) { return -1; }
        var idx = _scrollPos + ((tapY - LIST_TOP) / ROW_H);
        if (idx >= _events.size()) { return -1; }
        return idx;
    }

    function refreshEvents() as Void {
        _events = StimTrackerStorage.loadDayLog(_dateStr);
        var maxScroll = _events.size() - ROWS_VIS;
        if (maxScroll < 0) { maxScroll = 0; }
        if (_scrollPos > maxScroll) { _scrollPos = maxScroll; }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var total = 0;
        for (var i = 0; i < _events.size(); i++) {
            total += (_events[i] as Dictionary)["caffeineMg"] as Number;
        }

        var y2 = _dateStr.substring(2, 4);
        var m  = _dateStr.substring(4, 6).toNumber();
        var d  = _dateStr.substring(6, 8).toNumber();
        var dateLabel = m.toString() + "/" + d.toString() + "/" + y2;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 47, Graphics.FONT_XTINY,
            dateLabel + " | " + total.toString() + "mg",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 74, Graphics.FONT_XTINY, "Hold to edit",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (_events.size() == 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(CX, 200, Graphics.FONT_SMALL, "No doses",
                Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        for (var i = 0; i < ROWS_VIS; i++) {
            var idx = _scrollPos + i;
            if (idx >= _events.size()) { break; }
            var evt    = _events[idx] as Dictionary;
            var name   = evt["name"] as String;
            var caffMg = evt["caffeineMg"] as Number;
            var timeStr = "--:--";
            if (evt.hasKey("startSec")) {
                var startSec  = evt["startSec"]  as Number;
                var finishSec = evt["finishSec"] as Number;
                if (finishSec > startSec) {
                    timeStr = _formatTime(startSec) + "-" + _formatTime(finishSec);
                } else {
                    timeStr = _formatTime(startSec);
                }
            } else if (evt.hasKey("timestampSec")) {
                timeStr = _formatTime(evt["timestampSec"] as Number);
            }
            var y = LIST_TOP + i * ROW_H;

            // Row 1: time (left-aligned) + mg (right-aligned)
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(50, y + 15, Graphics.FONT_XTINY, timeStr,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(404, y + 15, Graphics.FONT_XTINY,
                caffMg.toString() + "mg",
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

            // Row 2: stimulant name — center-aligned to avoid edge clipping
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(CX, y + 42, Graphics.FONT_XTINY, name,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(40, y + ROW_H - 7, 414, y + ROW_H - 7);
        }

        if (_scrollPos > 0) {
            ArrowUtils.drawUpArrow(dc, CX, 68, ArrowUtils.HINT_ARROW_SIZE,
                Graphics.COLOR_LT_GRAY);
        }
        var bottomArrowY = LIST_TOP + ROWS_VIS * ROW_H + 10;
        if (_scrollPos + ROWS_VIS < _events.size() && bottomArrowY < 420) {
            ArrowUtils.drawDownArrow(dc, CX, bottomArrowY, ArrowUtils.HINT_ARROW_SIZE,
                Graphics.COLOR_LT_GRAY);
        }
    }

    private function _formatTime(timestampSec as Number) as String {
        var moment = new Time.Moment(timestampSec);
        var info   = Gregorian.info(moment, Time.FORMAT_SHORT);
        var h    = info.hour;
        var min  = info.min;
        var ampm = h >= 12 ? "pm" : "am";
        var h12  = h % 12;
        if (h12 == 0) { h12 = 12; }
        var mStr = min < 10 ? "0" + min.toString() : min.toString();
        return h12.toString() + ":" + mStr + ampm;
    }
}

class DayDetailDelegate extends WatchUi.BehaviorDelegate {

    private var _view as DayDetailView;

    function initialize(view as DayDetailView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onNextPage() as Boolean {
        _view.scrollDown();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.scrollUp();
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    // Long-press → open dose editor
    function onHold(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var tapY   = coords[1];
        var idx    = _view.rowForTapY(tapY);
        if (idx < 0) { return false; }

        var events   = StimTrackerStorage.loadDayLog(_view._dateStr);
        if (idx >= events.size()) { return false; }
        var evt2     = events[idx] as Dictionary;

        var profiles = StimTrackerStorage.loadProfiles();
        var editView = new DoseEditView(evt2, idx, _view._dateStr);
        WatchUi.pushView(
            editView,
            new DoseEditDelegate(editView, idx, _view._dateStr, _view, profiles),
            WatchUi.SLIDE_LEFT
        );
        return true;
    }
}

// ── Dose Edit View ─────────────────────────────────────────────────────────────
// Edit name, caffeine, start/finish times for a logged dose.
// Swipe UP/DOWN adjusts the selected time column (same pattern as AdjustTimeView).
// Tap the name area to open a profile picker.
// Save / grey-bar Cancel / Delete (below grey bar).

class DoseEditView extends WatchUi.View {

    private const CX = 227;

    // Time picker column x-centres — Start shifted 5px left, Finish shifted 5px right
    private const X_SH = 55;
    private const X_SM = 127;
    private const X_SC = 91;
    private const X_FH = 321;
    private const X_FM = 393;
    private const X_FC = 357;

    // Time picker y-rows — shifted up 30px vs original
    private const Y_UP    = 112;
    private const Y_NUM   = 148;
    private const Y_DOWN  = 178;
    private const Y_LABEL = 196;

    var _name     as String;
    var _caffMg   as Number;
    var _startH   as Number;
    var _startM   as Number;
    var _finishH  as Number;
    var _finishM  as Number;
    var _sel      as Number;   // 0=SH 1=SM 2=FH 3=FM

    // Originals for delta-based timestamp reconstruction
    var _origStartSec  as Number;
    var _origFinishSec as Number;
    var _origStartH    as Number;
    var _origStartM    as Number;
    var _origFinishH   as Number;
    var _origFinishM   as Number;

    function initialize(evt as Dictionary, idx as Number, dateStr as String) {
        View.initialize();
        _name   = evt["name"] as String;
        _caffMg = evt["caffeineMg"] as Number;
        _sel    = 0;

        // Resolve start/finish seconds from event
        if (evt.hasKey("startSec")) {
            _origStartSec  = evt["startSec"]  as Number;
            _origFinishSec = evt["finishSec"] as Number;
        } else {
            _origStartSec  = evt["timestampSec"] as Number;
            _origFinishSec = _origStartSec;
        }

        // Extract H:M from the stored timestamps
        var si = Gregorian.info(new Time.Moment(_origStartSec), Time.FORMAT_SHORT);
        _origStartH = si.hour;
        _origStartM = si.min;
        _startH     = _origStartH;
        _startM     = _origStartM;

        var fi = Gregorian.info(new Time.Moment(_origFinishSec), Time.FORMAT_SHORT);
        _origFinishH = fi.hour;
        _origFinishM = fi.min;
        _finishH     = _origFinishH;
        _finishM     = _origFinishM;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // ── Title ─────────────────────────────────────────────────────────
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 33, Graphics.FONT_XTINY, "Edit Dose",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Name (tap to open profile picker) ─────────────────────────────
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        _drawName(dc);

        // ── Selected time field highlight ──────────────────────────────────
        var selXArr = [X_SH, X_SM, X_FH, X_FM] as Array<Number>;
        var selX    = selXArr[_sel] as Number;
        dc.setColor(0x003300, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(selX - 28, Y_NUM - 24, 56, 48, 8);

        // ── Up arrows ─────────────────────────────────────────────────────
        ArrowUtils.drawUpArrow(dc, X_SH, Y_UP, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);
        ArrowUtils.drawUpArrow(dc, X_SM, Y_UP, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);
        ArrowUtils.drawUpArrow(dc, X_FH, Y_UP, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);
        ArrowUtils.drawUpArrow(dc, X_FM, Y_UP, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);

        // ── Time digits ────────────────────────────────────────────────────
        _drawNum(dc, X_SH, _startH,  _sel == 0);
        _drawNum(dc, X_SM, _startM,  _sel == 1);
        _drawNum(dc, X_FH, _finishH, _sel == 2);
        _drawNum(dc, X_FM, _finishM, _sel == 3);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(X_SC, Y_NUM, Graphics.FONT_NUMBER_MILD, ":",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(X_FC, Y_NUM, Graphics.FONT_NUMBER_MILD, ":",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Down arrows ────────────────────────────────────────────────────
        ArrowUtils.drawDownArrow(dc, X_SH, Y_DOWN, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);
        ArrowUtils.drawDownArrow(dc, X_SM, Y_DOWN, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);
        ArrowUtils.drawDownArrow(dc, X_FH, Y_DOWN, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);
        ArrowUtils.drawDownArrow(dc, X_FM, Y_DOWN, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);

        // ── Start / Finish labels ──────────────────────────────────────────
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(X_SC, Y_LABEL, Graphics.FONT_XTINY, "Start",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(X_FC, Y_LABEL, Graphics.FONT_XTINY, "Finish",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Save button ────────────────────────────────────────────────────
        // Caffeine label + readout
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 211, Graphics.FONT_XTINY, "Caffeine (mg)",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 258, Graphics.FONT_NUMBER_MILD, _caffMg.toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(132, 203, Graphics.FONT_NUMBER_MEDIUM, "-",
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(322, 203, Graphics.FONT_NUMBER_MEDIUM, "+",
            Graphics.TEXT_JUSTIFY_CENTER);

        // Save — moved up 35px, 25px taller (288–353), text centred at 320
        dc.setColor(0x007700, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(107, 288, 240, 65, 10);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 320, Graphics.FONT_XTINY, "Save",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Delete Dose — moved up 15px, 25px taller (358–423), text centred at 390
        dc.setColor(0x880000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(107, 358, 240, 65, 10);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 390, Graphics.FONT_XTINY, "Delete Dose",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Delete button (below cancel bar) ──────────────────────────────
    }

    private function _drawNum(dc as Graphics.Dc, x as Number, val as Number, selected as Boolean) as Void {
        var color = selected ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var str = val < 10 ? "0" + val.toString() : val.toString();
        dc.drawText(x, Y_NUM, Graphics.FONT_NUMBER_MILD, str,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Draw name at top, wrapping to a second line if > 20 chars.
    // Single-line: centred at y=60, underline at 73.
    // Two-line: line1 at 52, line2 at 72, underline at 85.
    private function _drawName(dc as Graphics.Dc) as Void {
        if (_name.length() <= 20) {
            dc.drawText(CX, 60, Graphics.FONT_XTINY, _name,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            var splitPos = 20;
            while (splitPos > 0 && !(_name.substring(splitPos, splitPos + 1).equals(" "))) {
                splitPos--;
            }
            var line1 = splitPos == 0
                ? _name.substring(0, 20)
                : _name.substring(0, splitPos);
            var line2 = splitPos == 0
                ? _name.substring(20, _name.length())
                : _name.substring(splitPos + 1, _name.length());
            dc.drawText(CX, 59, Graphics.FONT_XTINY, line1,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(CX, 87, Graphics.FONT_XTINY, line2,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // ── Interaction helpers ────────────────────────────────────────────────

    function isNameTap(tapY as Number) as Boolean {
        return tapY >= 44 && tapY <= 97;  // covers single-line (60) and two-line (59+87)
    }

    function isMinusTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 20 && tapX <= 165 && tapY >= 230 && tapY <= 288;
    }

    function isPlusTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 289 && tapX <= 434 && tapY >= 230 && tapY <= 288;
    }

    function isNumberTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 165 && tapX <= 289 && tapY >= 230 && tapY <= 288;
    }

    function isSaveTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 107 && tapX <= 347 && tapY >= 288 && tapY <= 353;
    }

    function isDeleteTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 107 && tapX <= 347 && tapY >= 358 && tapY <= 423;
    }

    // Select a time column based on tap position within the digit row
    function selectFromTap(tapX as Number, tapY as Number) as Void {
        if (tapY < Y_NUM - 26 || tapY > Y_NUM + 26) { return; }
        if (tapX < 224) {
            _sel = tapX < X_SC ? 0 : 1;
        } else {
            _sel = tapX < X_FC ? 2 : 3;
        }
        WatchUi.requestUpdate();
    }

    function increment() as Void {
        if (_sel == 0) { _startH  = (_startH  + 1) % 24; }
        if (_sel == 1) { _startM  = (_startM  + 1) % 60; }
        if (_sel == 2) { _finishH = (_finishH + 1) % 24; }
        if (_sel == 3) { _finishM = (_finishM + 1) % 60; }
        WatchUi.requestUpdate();
    }

    function decrement() as Void {
        if (_sel == 0) { _startH  = (_startH  + 23) % 24; }
        if (_sel == 1) { _startM  = (_startM  + 59) % 60; }
        if (_sel == 2) { _finishH = (_finishH + 23) % 24; }
        if (_sel == 3) { _finishM = (_finishM + 59) % 60; }
        WatchUi.requestUpdate();
    }

    function decrementMg() as Void {
        if (_caffMg > 10) { _caffMg -= 10; }
        WatchUi.requestUpdate();
    }

    function incrementMg() as Void {
        if (_caffMg < 1000) { _caffMg += 10; }
        WatchUi.requestUpdate();
    }

    function setName(name as String) as Void {
        _name = name;
        WatchUi.requestUpdate();
    }

    function setNameAndMg(name as String, caffMg as Number) as Void {
        _name   = name;
        _caffMg = caffMg;
        WatchUi.requestUpdate();
    }

    // Compute new start timestamp via delta from original
    function getStartSec() as Number {
        return _origStartSec
            + (_startH - _origStartH) * 3600
            + (_startM - _origStartM) * 60;
    }

    // Compute new finish timestamp via delta from original
    function getFinishSec() as Number {
        return _origFinishSec
            + (_finishH - _origFinishH) * 3600
            + (_finishM - _origFinishM) * 60;
    }
}

// ── Dose Edit Delegate ─────────────────────────────────────────────────────────

class DoseEditDelegate extends WatchUi.BehaviorDelegate {

    private var _view       as DoseEditView;
    private var _idx        as Number;
    private var _dateStr    as String;
    private var _detailView as DayDetailView;
    private var _profiles   as Array<Dictionary>;

    function initialize(view as DoseEditView, idx as Number, dateStr as String,
                        detailView as DayDetailView, profiles as Array<Dictionary>) {
        BehaviorDelegate.initialize();
        _view       = view;
        _idx        = idx;
        _dateStr    = dateStr;
        _detailView = detailView;
        _profiles   = profiles;
    }

    // Swipe UP → increment selected time column
    function onNextPage() as Boolean {
        _view.increment();
        return true;
    }

    // Swipe DOWN → decrement selected time column
    function onPreviousPage() as Boolean {
        _view.decrement();
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var tapX   = coords[0];
        var tapY   = coords[1];

        if (_view.isNameTap(tapY)) {
            var pickerView = new DoseNamePickerView(_profiles);
            WatchUi.pushView(
                pickerView,
                new DoseNamePickerDelegate(pickerView, _view, _profiles),
                WatchUi.SLIDE_LEFT
            );
            return true;
        }

        if (_view.isMinusTap(tapX, tapY)) {
            _view.decrementMg();
            return true;
        }

        if (_view.isPlusTap(tapX, tapY)) {
            _view.incrementMg();
            return true;
        }

        if (_view.isNumberTap(tapX, tapY)) {
            WatchUi.pushView(
                new WatchUi.TextPicker(_view._caffMg.toString()),
                new DoseCaffTextPickerDelegate(_view),
                WatchUi.SLIDE_UP
            );
            return true;
        }

        if (_view.isSaveTap(tapX, tapY)) {
            _save();
            return true;
        }

        if (_view.isDeleteTap(tapX, tapY)) {
            var confirm = new WatchUi.Confirmation("Delete this dose?");
            WatchUi.pushView(confirm,
                new DoseDeleteDelegate(_idx, _dateStr, _detailView),
                WatchUi.SLIDE_UP);
            return true;
        }

        // Tap on time digit area → select column
        _view.selectFromTap(tapX, tapY);
        return true;
    }

    private function _save() as Void {
        StimTrackerStorage.updateDose(
            _dateStr, _idx,
            _view._name, _view._caffMg,
            _view.getStartSec(), _view.getFinishSec()
        );
        _detailView.refreshEvents();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

// ── Dose Delete Confirmation Delegate ────────────────────────────────────────

class DoseCaffTextPickerDelegate extends WatchUi.TextPickerDelegate {

    private var _editView as DoseEditView;

    function initialize(editView as DoseEditView) {
        TextPickerDelegate.initialize();
        _editView = editView;
    }

    function onTextEntered(text as String, changed as Boolean) as Boolean {
        var num = text.toNumber();
        if (num != null) {
            if (num < 10)   { num = 10; }
            if (num > 1000) { num = 1000; }
            _editView._caffMg = num;
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onCancel() as Boolean {
        return true;
    }
}

class DoseDeleteDelegate extends WatchUi.ConfirmationDelegate {

    private var _idx        as Number;
    private var _dateStr    as String;
    private var _detailView as DayDetailView;

    function initialize(idx as Number, dateStr as String, detailView as DayDetailView) {
        ConfirmationDelegate.initialize();
        _idx        = idx;
        _dateStr    = dateStr;
        _detailView = detailView;
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            StimTrackerStorage.deleteDose(_dateStr, _idx);
            _detailView.refreshEvents();
            WatchUi.popView(WatchUi.SLIDE_DOWN);   // pop confirmation
            WatchUi.popView(WatchUi.SLIDE_RIGHT);  // pop DoseEditView
        } else {
            WatchUi.popView(WatchUi.SLIDE_DOWN);   // pop confirmation only
        }
        return true;
    }
}

// ── Dose Name Picker View ─────────────────────────────────────────────────────
// Scrollable list of stimulant profiles for renaming a dose.
// Row 0: "Custom" (type any name, caffeine unchanged).
// Rows 1..n: profiles (sets both name and caffeineMg).

class DoseNamePickerView extends WatchUi.View {

    private const CX       = 227;
    private const ROW_H    = 70;
    private const LIST_TOP = 80;
    private const ROWS_VIS = 4;

    var _profiles  as Array<Dictionary>;
    var _scrollPos as Number;

    function initialize(profiles as Array<Dictionary>) {
        View.initialize();
        _profiles  = profiles;
        _scrollPos = 0;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 30, Graphics.FONT_XTINY, "Pick Profile",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var totalRows = 1 + _profiles.size();

        for (var i = 0; i < ROWS_VIS; i++) {
            var rowIdx = _scrollPos + i;
            if (rowIdx >= totalRows) { break; }

            var y = LIST_TOP + i * ROW_H;

            if (rowIdx == 0) {
                // Custom row — opens keyboard
                dc.setColor(0x00AAAA, Graphics.COLOR_TRANSPARENT);
                dc.drawText(CX, y + 20, Graphics.FONT_XTINY, "Custom",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(CX, y + 50, Graphics.FONT_XTINY, "Type a name",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            } else {
                var p      = _profiles[rowIdx - 1] as Dictionary;
                var name   = p["name"] as String;
                var caffMg = p["caffeineMg"] as Number;
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(CX, y + 20, Graphics.FONT_XTINY, name,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(CX, y + 50, Graphics.FONT_XTINY, caffMg.toString() + "mg",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }

            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(40, y + ROW_H - 2, 414, y + ROW_H - 2);
        }

        if (_scrollPos > 0) {
            ArrowUtils.drawUpArrow(dc, CX, 68, ArrowUtils.HINT_ARROW_SIZE,
                Graphics.COLOR_LT_GRAY);
        }
        var bottomY = LIST_TOP + ROWS_VIS * ROW_H + 10;
        if (_scrollPos + ROWS_VIS < totalRows) {
            ArrowUtils.drawDownArrow(dc, CX, bottomY, ArrowUtils.HINT_ARROW_SIZE,
                Graphics.COLOR_LT_GRAY);
        }
    }

    function rowForTapY(tapY as Number) as Number {
        if (tapY < LIST_TOP) { return -1; }
        var rowIdx    = _scrollPos + ((tapY - LIST_TOP) / ROW_H);
        var totalRows = 1 + _profiles.size();
        if (rowIdx >= totalRows) { return -1; }
        return rowIdx;
    }

    function scrollDown() as Void {
        var totalRows = 1 + _profiles.size();
        if (_scrollPos + ROWS_VIS < totalRows) {
            _scrollPos++;
            WatchUi.requestUpdate();
        }
    }

    function scrollUp() as Void {
        if (_scrollPos > 0) {
            _scrollPos--;
            WatchUi.requestUpdate();
        }
    }
}

// ── Dose Name Picker Delegate ─────────────────────────────────────────────────

class DoseNamePickerDelegate extends WatchUi.BehaviorDelegate {

    private var _pickerView as DoseNamePickerView;
    private var _editView   as DoseEditView;
    private var _profiles   as Array<Dictionary>;

    function initialize(pickerView as DoseNamePickerView, editView as DoseEditView,
                        profiles as Array<Dictionary>) {
        BehaviorDelegate.initialize();
        _pickerView = pickerView;
        _editView   = editView;
        _profiles   = profiles;
    }

    function onNextPage() as Boolean {
        _pickerView.scrollDown();
        return true;
    }

    function onPreviousPage() as Boolean {
        _pickerView.scrollUp();
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var tapY   = coords[1];
        var rowIdx = _pickerView.rowForTapY(tapY);
        if (rowIdx < 0) { return false; }

        if (rowIdx == 0) {
            // Custom — open keyboard; caffeine stays unchanged
            WatchUi.pushView(
                new WatchUi.TextPicker(_editView._name),
                new DoseCustomNameDelegate(_editView),
                WatchUi.SLIDE_UP
            );
        } else {
            // Profile selected — set name and caffeine, pop back to edit screen
            var p = _profiles[rowIdx - 1] as Dictionary;
            _editView.setNameAndMg(p["name"] as String, p["caffeineMg"] as Number);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
        return true;
    }
}

// ── Dose Custom Name Delegate ─────────────────────────────────────────────────

class DoseCustomNameDelegate extends WatchUi.TextPickerDelegate {

    private var _editView as DoseEditView;

    function initialize(editView as DoseEditView) {
        TextPickerDelegate.initialize();
        _editView = editView;
    }

    function onTextEntered(text as String, changed as Boolean) as Boolean {
        if (text.length() > 0) {
            _editView.setName(text);
        }
        // Pop TextPicker, then pop DoseNamePickerView → back at DoseEditView
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onCancel() as Boolean {
        return true;
    }
}
