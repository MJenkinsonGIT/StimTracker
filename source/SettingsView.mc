// SettingsView.mc
// Scrollable settings screen. Each item is tappable to edit.

import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.Time.Gregorian;

class SettingsView extends WatchUi.View {

    private const CX       = 227;
    private const ROW_H    = 58;
    private const LIST_TOP = 55;
    private const ROWS_VIS = 6;

    var _settings  as Dictionary;
    var _scrollPos as Number;

    static const ITEM_LIMIT       = 0;
    static const ITEM_HALF_LIFE   = 1;
    static const ITEM_SLEEP_MG    = 2;
    static const ITEM_BEDTIME     = 3;
    static const ITEM_OOPS        = 4;
    static const ITEM_RESET_TODAY = 5;

    function initialize(settings as Dictionary) {
        View.initialize();
        _settings  = settings;
        _scrollPos = 0;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 28, Graphics.FONT_XTINY, "Settings",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var items = _buildItems();

        for (var i = 0; i < ROWS_VIS; i++) {
            var idx = _scrollPos + i;
            if (idx >= items.size()) { break; }
            var item = items[idx] as Array;
            var y    = LIST_TOP + i * ROW_H;

            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(CX, y + 13, Graphics.FONT_XTINY, item[0] as String,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(CX, y + 38, Graphics.FONT_XTINY, item[1] as String,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(40, y + ROW_H - 1, 414, y + ROW_H - 1);
        }

        if (_scrollPos > 0) {
            ArrowUtils.drawUpArrow(dc, CX, 43, ArrowUtils.HINT_ARROW_SIZE,
                Graphics.COLOR_LT_GRAY);
        }
        if (_scrollPos + ROWS_VIS < items.size()) {
            ArrowUtils.drawDownArrow(dc, CX, LIST_TOP + ROWS_VIS * ROW_H + 12,
                ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);
        }
    }

    private function _buildItems() as Array<Array> {
        var limitMg     = _settings["limitMg"] as Number;
        var halfLife    = _settings["halfLifeHrs"] as Float;
        var sleepMg     = _settings["sleepThresholdMg"] as Number;
        var bedtimeMins = _settings["bedtimeMinutes"] as Number;
        var oopsMg      = _settings["oopsThresholdMg"];

        var bedH    = bedtimeMins / 60;
        var bedM    = bedtimeMins % 60;
        var bedAmpm = bedH >= 12 ? "pm" : "am";
        var bedH12  = bedH % 12;
        if (bedH12 == 0) { bedH12 = 12; }
        var bedMStr    = bedM < 10 ? "0" + bedM.toString() : bedM.toString();
        var bedtimeStr = bedH12.toString() + ":" + bedMStr + bedAmpm;

        var oopsStr = oopsMg != null
            ? (oopsMg as Float).toNumber().toString() + "mg"
            : "Not set";

        return [
            ["Daily Caffeine Limit",  limitMg.toString() + "mg"],
            ["Caffeine Half-Life",    halfLife.format("%.1f") + " hrs"],
            ["Sleep Threshold",       sleepMg.toString() + "mg in system"],
            ["Bedtime",               bedtimeStr],
            ["Oops Threshold",        oopsStr],
            ["Reset Today's Log",     "Tap to clear"]
        ] as Array<Array>;
    }

    function rowForTapY(tapY as Number) as Number {
        if (tapY < LIST_TOP) { return -1; }
        var idx = _scrollPos + ((tapY - LIST_TOP) / ROW_H);
        var items = _buildItems();
        if (idx >= items.size()) { return -1; }
        return idx;
    }

    function scrollDown() as Void {
        if (_scrollPos + ROWS_VIS < _buildItems().size()) {
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

// ── Settings Delegate ─────────────────────────────────────────────────────────

class SettingsDelegate extends WatchUi.BehaviorDelegate {

    private var _view     as SettingsView;
    private var _settings as Dictionary;
    private var _mainView as MainView;

    function initialize(view as SettingsView, settings as Dictionary, mainView as MainView) {
        BehaviorDelegate.initialize();
        _view     = view;
        _settings = settings;
        _mainView = mainView;
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
        _mainView.refreshSettings(_settings);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var tapY   = coords[1];
        var rowIdx = _view.rowForTapY(tapY);
        if (rowIdx < 0) { return false; }

        if (rowIdx == SettingsView.ITEM_LIMIT) {
            // Step 10mg (was 50)
            _pushNumberEditor("Daily Limit (mg)", _settings["limitMg"] as Number,
                100, 2000, 10, method(:onLimitPicked));
        } else if (rowIdx == SettingsView.ITEM_HALF_LIFE) {
            var tenths = ((_settings["halfLifeHrs"] as Float) * 10.0f).toNumber();
            _pushNumberEditor("Half-Life (x0.1 hrs)", tenths, 10, 120, 1,
                method(:onHalfLifePicked));
        } else if (rowIdx == SettingsView.ITEM_SLEEP_MG) {
            _pushNumberEditor("Sleep Threshold (mg)", _settings["sleepThresholdMg"] as Number,
                0, 400, 10, method(:onSleepMgPicked));
        } else if (rowIdx == SettingsView.ITEM_BEDTIME) {
            // HH:MM picker instead of raw minutes
            var mins     = _settings["bedtimeMinutes"] as Number;
            var bedView  = new BedtimeEditView(mins);
            WatchUi.pushView(
                bedView,
                new BedtimeEditDelegate(bedView, _settings, _view),
                WatchUi.SLIDE_LEFT
            );
        } else if (rowIdx == SettingsView.ITEM_OOPS) {
            // Adjust threshold like Sleep Threshold (was a clear-confirmation)
            var oopsMg = _settings["oopsThresholdMg"];
            var initial = oopsMg != null ? (oopsMg as Float).toNumber() : 100;
            _pushNumberEditor("Oops Threshold (mg)", initial,
                0, 500, 10, method(:onOopsPicked));
        } else if (rowIdx == SettingsView.ITEM_RESET_TODAY) {
            var confirm = new WatchUi.Confirmation("Clear today's log?");
            WatchUi.pushView(confirm, new ResetTodayDelegate(), WatchUi.SLIDE_UP);
        }
        return true;
    }

    function onLimitPicked(value as Number) as Void {
        _settings["limitMg"] = value;
        StimTrackerStorage.saveSettings(_settings);
        WatchUi.requestUpdate();
    }

    function onHalfLifePicked(value as Number) as Void {
        _settings["halfLifeHrs"] = value.toFloat() / 10.0f;
        StimTrackerStorage.saveSettings(_settings);
        WatchUi.requestUpdate();
    }

    function onSleepMgPicked(value as Number) as Void {
        _settings["sleepThresholdMg"] = value;
        StimTrackerStorage.saveSettings(_settings);
        WatchUi.requestUpdate();
    }

    function onOopsPicked(value as Number) as Void {
        _settings["oopsThresholdMg"] = value.toFloat();
        StimTrackerStorage.saveSettings(_settings);
        WatchUi.requestUpdate();
    }

    private function _pushNumberEditor(title as String, initial as Number,
            minVal as Number, maxVal as Number, step as Number,
            callback as Method) as Void {
        var editView = new ValueEditView(title, initial, minVal, maxVal, step);
        WatchUi.pushView(
            editView,
            new ValueEditDelegate(editView, minVal, maxVal, step, callback),
            WatchUi.SLIDE_LEFT
        );
    }
}

// ── Value Edit View ───────────────────────────────────────────────────────────

class ValueEditView extends WatchUi.View {

    private const CX = 227;

    var _title   as String;
    var _value   as Number;
    var _min     as Number;
    var _max     as Number;
    var _step    as Number;

    function initialize(title as String, initial as Number,
            minVal as Number, maxVal as Number, step as Number) {
        View.initialize();
        _title = title;
        _value = initial;
        _min   = minVal;
        _max   = maxVal;
        _step  = step;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Title — word-wrapped to avoid bezel clipping
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        _drawTitle(dc);

        // Current value — large number
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 175, Graphics.FONT_NUMBER_HOT,
            _value.toString(), Graphics.TEXT_JUSTIFY_CENTER);

        // Minus / Plus buttons
        dc.setColor(_value > _min ? Graphics.COLOR_BLUE : Graphics.COLOR_DK_GRAY,
            Graphics.COLOR_TRANSPARENT);
        dc.drawText(80, 195, Graphics.FONT_NUMBER_MEDIUM, "-",
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(_value < _max ? Graphics.COLOR_BLUE : Graphics.COLOR_DK_GRAY,
            Graphics.COLOR_TRANSPARENT);
        dc.drawText(374, 195, Graphics.FONT_NUMBER_MEDIUM, "+",
            Graphics.TEXT_JUSTIFY_CENTER);

        // Save button
        dc.setColor(0x007700, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(107, 305, 240, 42, 10);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 326, Graphics.FONT_XTINY, "Save",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Cancel bar
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 380, dc.getWidth(), 23);
        ArrowUtils.drawDownArrow(dc, CX - 49, 391, ArrowUtils.HINT_ARROW_SIZE,
            Graphics.COLOR_LT_GRAY);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX - 35, 391, Graphics.FONT_XTINY, "Cancel",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Word-wrap title onto two lines if > 16 chars, splitting at the space
    // nearest the midpoint — keeps both lines balanced and within the bezel.
    private function _drawTitle(dc as Graphics.Dc) as Void {
        if (_title.length() <= 16) {
            dc.drawText(CX, 42, Graphics.FONT_XTINY, _title,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            var mid     = _title.length() / 2;
            var bestPos = -1;
            var bestDist = _title.length();
            for (var i = 0; i < _title.length(); i++) {
                if (_title.substring(i, i + 1).equals(" ")) {
                    var dist = i >= mid ? i - mid : mid - i;
                    if (dist < bestDist) {
                        bestDist = dist;
                        bestPos  = i;
                    }
                }
            }
            if (bestPos < 0) {
                // No space found — truncate
                dc.drawText(CX, 42, Graphics.FONT_XTINY, _title,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            } else {
                var line1 = _title.substring(0, bestPos);
                var line2 = _title.substring(bestPos + 1, _title.length());
                dc.drawText(CX, 30, Graphics.FONT_XTINY, line1,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                dc.drawText(CX, 63, Graphics.FONT_XTINY, line2,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }
    }

    function decrement() as Void {
        if (_value - _step >= _min) { _value -= _step; }
        WatchUi.requestUpdate();
    }

    function increment() as Void {
        if (_value + _step <= _max) { _value += _step; }
        WatchUi.requestUpdate();
    }

    function isMinusTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 20 && tapX <= 145 && tapY >= 220 && tapY <= 305;
    }

    function isPlusTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 309 && tapX <= 434 && tapY >= 220 && tapY <= 305;
    }

    // Tap on the number itself (centre strip between minus and plus)
    function isNumberTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 145 && tapX <= 309 && tapY >= 220 && tapY <= 305;
    }

    function isSaveTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 107 && tapX <= 347 && tapY >= 305 && tapY <= 347;
    }
}

class ValueEditDelegate extends WatchUi.BehaviorDelegate {

    private var _view     as ValueEditView;
    private var _callback as Method;

    function initialize(view as ValueEditView, minVal as Number, maxVal as Number,
            step as Number, callback as Method) {
        BehaviorDelegate.initialize();
        _view     = view;
        _callback = callback;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onPreviousPage() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var tapX   = coords[0];
        var tapY   = coords[1];

        if (_view.isMinusTap(tapX, tapY)) {
            _view.decrement();
            return true;
        }
        if (_view.isPlusTap(tapX, tapY)) {
            _view.increment();
            return true;
        }
        if (_view.isNumberTap(tapX, tapY)) {
            WatchUi.pushView(
                new WatchUi.TextPicker(_view._value.toString()),
                new ValueTextPickerDelegate(_view),
                WatchUi.SLIDE_UP
            );
            return true;
        }
        if (_view.isSaveTap(tapX, tapY)) {
            _callback.invoke(_view._value);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return true;
        }
        return false;
    }
}

// ── Value Text Picker Delegate ────────────────────────────────────────────────
// Opened when the user taps directly on the number in ValueEditView.
// Parses the entered string as an integer and clamps it to the view's range.

class ValueTextPickerDelegate extends WatchUi.TextPickerDelegate {

    private var _editView as ValueEditView;

    function initialize(editView as ValueEditView) {
        TextPickerDelegate.initialize();
        _editView = editView;
    }

    function onTextEntered(text as String, changed as Boolean) as Boolean {
        var num = text.toNumber();
        if (num != null) {
            if (num < _editView._min) { num = _editView._min; }
            if (num > _editView._max) { num = _editView._max; }
            _editView._value = num;
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onCancel() as Boolean {
        return true;
    }
}

// ── Bedtime Edit View ─────────────────────────────────────────────────────────
// HH:MM picker for the bedtime setting.
// Swipe UP = increment selected column, swipe DOWN = decrement.
// Tap left half = select hours, tap right half = select minutes.

class BedtimeEditView extends WatchUi.View {

    private const CX     = 227;
    private const X_H    = 160;   // hours column centre
    private const X_C    = 227;   // colon
    private const X_M    = 294;   // minutes column centre
    private const Y_UP   = 100;
    private const Y_NUM  = 175;
    private const Y_DOWN = 252;
    private const Y_LBL  = 282;

    var _hours as Number;
    var _mins  as Number;
    var _sel   as Number;  // 0 = hours, 1 = minutes

    function initialize(totalMins as Number) {
        View.initialize();
        _hours = totalMins / 60;
        _mins  = totalMins % 60;
        _sel   = 0;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Title
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 33, Graphics.FONT_XTINY, "Bedtime",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Selection highlight
        var selX = _sel == 0 ? X_H : X_M;
        dc.setColor(0x003300, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(selX - 46, Y_NUM - 42, 92, 84, 10);

        // Up arrows
        ArrowUtils.drawUpArrow(dc, X_H, Y_UP, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);
        ArrowUtils.drawUpArrow(dc, X_M, Y_UP, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);

        // Digits
        _drawCol(dc, X_H, _hours, _sel == 0);
        _drawCol(dc, X_M, _mins,  _sel == 1);

        // Colon
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(X_C, Y_NUM, Graphics.FONT_NUMBER_HOT, ":",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Down arrows
        ArrowUtils.drawDownArrow(dc, X_H, Y_DOWN, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);
        ArrowUtils.drawDownArrow(dc, X_M, Y_DOWN, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);

        // Column labels
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(X_H, Y_LBL, Graphics.FONT_XTINY, "Hour",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(X_M, Y_LBL, Graphics.FONT_XTINY, "Min",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Save button
        dc.setColor(0x007700, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(107, 305, 240, 42, 10);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 326, Graphics.FONT_XTINY, "Save",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Cancel bar
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 380, dc.getWidth(), 23);
        ArrowUtils.drawDownArrow(dc, CX - 49, 391, ArrowUtils.HINT_ARROW_SIZE,
            Graphics.COLOR_LT_GRAY);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX - 35, 391, Graphics.FONT_XTINY, "Cancel",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function _drawCol(dc as Graphics.Dc, x as Number, val as Number, sel as Boolean) as Void {
        dc.setColor(sel ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY,
            Graphics.COLOR_TRANSPARENT);
        var str = val < 10 ? "0" + val.toString() : val.toString();
        dc.drawText(x, Y_NUM, Graphics.FONT_NUMBER_HOT, str,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function increment() as Void {
        if (_sel == 0) { _hours = (_hours + 1) % 24; }
        else           { _mins  = (_mins  + 1) % 60; }
        WatchUi.requestUpdate();
    }

    function decrement() as Void {
        if (_sel == 0) { _hours = (_hours + 23) % 24; }
        else           { _mins  = (_mins  + 59) % 60; }
        WatchUi.requestUpdate();
    }

    function selectFromTap(tapX as Number) as Void {
        _sel = tapX < CX ? 0 : 1;
        WatchUi.requestUpdate();
    }

    function isSaveTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 107 && tapX <= 347 && tapY >= 305 && tapY <= 347;
    }

    function getTotalMins() as Number {
        return _hours * 60 + _mins;
    }
}

class BedtimeEditDelegate extends WatchUi.BehaviorDelegate {

    private var _view     as BedtimeEditView;
    private var _settings as Dictionary;

    function initialize(view as BedtimeEditView, settings as Dictionary,
                        settView as SettingsView) {
        BehaviorDelegate.initialize();
        _view     = view;
        _settings = settings;
    }

    // Swipe UP = increment selected column
    function onNextPage() as Boolean {
        _view.increment();
        return true;
    }

    // Swipe DOWN = decrement selected column
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

        if (_view.isSaveTap(tapX, tapY)) {
            _settings["bedtimeMinutes"] = _view.getTotalMins();
            StimTrackerStorage.saveSettings(_settings);
            WatchUi.requestUpdate();
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return true;
        }

        // Tap on digit area = column select
        if (tapY >= 133 && tapY <= 315) {
            _view.selectFromTap(tapX);
        }
        return true;
    }
}

// ── Reset Today Delegate ──────────────────────────────────────────────────────

class ResetTodayDelegate extends WatchUi.ConfirmationDelegate {

    function initialize() {
        ConfirmationDelegate.initialize();
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            StimTrackerStorage.resetToday();
            WatchUi.requestUpdate();
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
