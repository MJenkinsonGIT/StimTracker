// EditStimulantView.mc
// Add New and Edit Stimulant screens.
// If profile is null → Add New mode. Otherwise → Edit mode.

import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

class EditStimulantView extends WatchUi.View {

    private const CX = 227;

    var _profile  as Dictionary or Null;
    var _settings as Dictionary;
    var _name     as String;
    var _caffMg   as Number;

    function initialize(profile as Dictionary or Null, settings as Dictionary) {
        View.initialize();
        _profile  = profile;
        _settings = settings;
        _name     = profile != null ? profile["name"] as String : "";
        _caffMg   = profile != null ? profile["caffeineMg"] as Number : 100;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // ── Title ────────────────────────────────────────────────────────
        var title = _profile == null ? "Add Stimulant" : "Edit Stimulant";
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 30, Graphics.FONT_XTINY, title,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Name field ───────────────────────────────────────────────────
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 80, Graphics.FONT_XTINY, "Name:",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        var displayName = _name.length() > 0 ? _name : "(tap to set)";
        dc.setColor(_name.length() > 0 ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY,
            Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 108, Graphics.FONT_XTINY, displayName,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Caffeine mg field ─────────────────────────────────────────────
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 158, Graphics.FONT_XTINY, "Caffeine (mg):",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 188, Graphics.FONT_NUMBER_MEDIUM, _caffMg.toString(),
            Graphics.TEXT_JUSTIFY_CENTER);

        // +/- buttons
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(110, 180, Graphics.FONT_NUMBER_MEDIUM, "-",
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(344, 180, Graphics.FONT_NUMBER_MEDIUM, "+",
            Graphics.TEXT_JUSTIFY_CENTER);

        // ── Save button ───────────────────────────────────────────────────
        var canSave = _name.length() > 0 && _caffMg > 0;
        dc.setColor(canSave ? 0x007700 : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(107, 305, 240, 44, 10);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 327, Graphics.FONT_XTINY, "Save",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Cancel bar — full width, y=384, h=20, matching main screen ─────
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 380, dc.getWidth(), 23);
        // Arrow + "Cancel" centred together at CX
        ArrowUtils.drawDownArrow(dc, CX - 49, 392, ArrowUtils.HINT_ARROW_SIZE,
            Graphics.COLOR_LT_GRAY);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX - 35, 392, Graphics.FONT_XTINY, "Cancel",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Fill a horizontal bar clipped to the progress arc circle (radius 210).
    private function _fillCircularBar(dc as Graphics.Dc, y as Number, barH as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var rSq = 210 * 210;
        for (var row = y; row < y + barH; row++) {
            var dy  = row - 227;
            var rem = rSq - dy * dy;
            if (rem <= 0) { continue; }
            var hw = Math.sqrt(rem.toFloat()).toNumber();
            dc.fillRectangle(227 - hw, row, hw * 2, 1);
        }
    }

    function isNameTap(tapX as Number, tapY as Number) as Boolean {
        return tapY >= 68 && tapY <= 130;
    }

    function isMinusTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 20 && tapX <= 145 && tapY >= 200 && tapY <= 280;
    }

    function isPlusTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 309 && tapX <= 434 && tapY >= 200 && tapY <= 280;
    }

    function isNumberTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 145 && tapX <= 309 && tapY >= 200 && tapY <= 280;
    }

    function isSaveTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 107 && tapX <= 347 && tapY >= 305 && tapY <= 349;
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
}

// ── Edit Delegate ─────────────────────────────────────────────────────────────

class EditStimulantDelegate extends WatchUi.BehaviorDelegate {

    private var _view     as EditStimulantView;
    private var _profile  as Dictionary or Null;
    private var _settings as Dictionary;
    private var _listView as LogStimulantView;

    function initialize(view as EditStimulantView, profile as Dictionary or Null,
                        settings as Dictionary, listView as LogStimulantView) {
        BehaviorDelegate.initialize();
        _view     = view;
        _profile  = profile;
        _settings = settings;
        _listView = listView;
    }

    // Back button or swipe down = cancel
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

        if (_view.isNameTap(tapX, tapY)) {
            WatchUi.pushView(
                new WatchUi.TextPicker(_view._name),
                new NamePickerDelegate(_view),
                WatchUi.SLIDE_UP
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
                new EditCaffTextPickerDelegate(_view),
                WatchUi.SLIDE_UP
            );
            return true;
        }

        if (_view.isSaveTap(tapX, tapY)) {
            if (_view._name.length() > 0 && _view._caffMg > 0) {
                _save();
            }
            return true;
        }
        return false;
    }

    private function _save() as Void {
        var updated;
        if (_profile == null) {
            updated = StimTrackerStorage.addProfile(_view._name, _view._caffMg, _settings);
        } else {
            updated = StimTrackerStorage.updateProfile(
                _profile["id"] as Number, _view._name, _view._caffMg);
        }
        _listView.refreshProfiles(updated);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

// ── Name Picker Delegate ──────────────────────────────────────────────────────

class EditCaffTextPickerDelegate extends WatchUi.TextPickerDelegate {

    private var _editView as EditStimulantView;

    function initialize(editView as EditStimulantView) {
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

class NamePickerDelegate extends WatchUi.TextPickerDelegate {

    private var _editView as EditStimulantView;

    function initialize(editView as EditStimulantView) {
        TextPickerDelegate.initialize();
        _editView = editView;
    }

    function onTextEntered(text as String, changed as Boolean) as Boolean {
        if (text.length() > 0) {
            _editView.setName(text);
        }
        return true;
    }

    function onCancel() as Boolean {
        return true;
    }
}
