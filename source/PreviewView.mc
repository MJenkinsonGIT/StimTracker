// PreviewView.mc
// Preview/Confirm screen — shown after tapping a stimulant profile.
// Hold Back → Profile edit screen (suppressed for Misc profile id=0).

import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Math;

class PreviewView extends WatchUi.View {

    private const CX = 227;
    private const CY = 227;

    var _profile   as Dictionary;
    var _settings  as Dictionary;
    var _startSec  as Number;  // 0 = not set (use current time at log)
    var _finishSec as Number;  // 0 = not set (instant dose)

    function initialize(profile as Dictionary, settings as Dictionary) {
        View.initialize();
        _profile   = profile;
        _settings  = settings;
        _startSec  = 0;
        _finishSec = 0;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var name      = _profile["name"] as String;
        var caffMg    = _profile["caffeineMg"] as Number;
        var limitMg   = _settings["limitMg"] as Number;
        var oopsMg    = _settings["oopsThresholdMg"];
        var todayMg   = StimTrackerStorage.calcTodayTotalMg();

        var futureTotal     = todayMg + caffMg;
        var futureInSystem  = StimTrackerStorage.previewCurrentMgAfterDose(caffMg, _settings);
        var futureSleepMins = StimTrackerStorage.previewMinutesAfterDose(caffMg, _settings);
        var futureSleepStr  = StimTrackerStorage.formatSleepTime(futureSleepMins);

        var exceedsLimit = futureTotal > limitMg;
        var exceedsOops  = false;
        if (oopsMg != null) {
            exceedsOops = futureInSystem > (oopsMg as Float);
        }

        // ── Header: caffeine first (grey), then name (white) ─────────────
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 42, Graphics.FONT_XTINY,
            "+ " + caffMg.toString() + "mg caffeine",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var nameWrapped = _drawWrappedName(dc, name, 81);

        // ── Warning banner (shifts down 5px if name is two lines) ────────
        var warningY = nameWrapped ? 123 : 118;
        if (exceedsOops) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(CX, warningY, Graphics.FONT_XTINY,
                "! Past your Oops threshold",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (exceedsLimit) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(CX, warningY, Graphics.FONT_XTINY,
                "! Over daily limit",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // ── Preview numbers ───────────────────────────────────────────────
        var sleepLabel = futureSleepMins < 0
            ? "Below Sleep Threshold: Now"
            : "Below Sleep Threshold: " + futureSleepStr;
        var yBase = 153;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, yBase, Graphics.FONT_XTINY, "After this:",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, yBase + 30, Graphics.FONT_XTINY,
            futureTotal.toString() + " / " + limitMg.toString() + "mg today",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, yBase + 60, Graphics.FONT_XTINY,
            "~" + futureInSystem.toNumber().toString() + "mg in system",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, yBase + 90, Graphics.FONT_XTINY, sleepLabel,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Time window indicator ─────────────────────────────────────────
        if (_startSec > 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            if (_finishSec > _startSec) {
                dc.drawText(CX, yBase + 122, Graphics.FONT_XTINY,
                    _fmtTimeSec(_startSec) + " - " + _fmtTimeSec(_finishSec),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            } else {
                dc.drawText(CX, yBase + 122, Graphics.FONT_XTINY,
                    "At: " + _fmtTimeSec(_startSec),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        // ── Log It button ─────────────────────────────────────────────────
        dc.setColor(0x007700, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(107, 292, 240, 53, 10);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 318, Graphics.FONT_XTINY, "Log It",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Hold Back = Profile bar (only shown for real profiles) ────────
        var profileId = _profile["id"] as Number;
        if (profileId != 0) {
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, 355, dc.getWidth(), 27);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(CX, 368, Graphics.FONT_XTINY, "Hold Back=Profile",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // ── Adjust Time button ────────────────────────────────────────────
        dc.setColor(0x880000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(107, 387, 240, 53, 10);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 413, Graphics.FONT_XTINY, "Adjust Time",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function _fillCircularBar(dc as Graphics.Dc, y as Number, barH as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var rSq = 210 * 210;
        for (var row = y; row < y + barH; row++) {
            var dy  = row - CY;
            var rem = rSq - dy * dy;
            if (rem <= 0) { continue; }
            var hw = Math.sqrt(rem.toFloat()).toNumber();
            dc.fillRectangle(CX - hw, row, hw * 2, 1);
        }
    }

    function isLogItTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 107 && tapX <= 347 && tapY >= 292 && tapY <= 345;
    }

    function isAdjustTimeTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 107 && tapX <= 347 && tapY >= 387 && tapY <= 440;
    }

    // Set the consumption window. Called by AdjustTimeDelegate on back.
    function setTimings(startSec as Number, finishSec as Number) as Void {
        _startSec  = startSec;
        _finishSec = finishSec;
        WatchUi.requestUpdate();
    }

    // Format a Unix timestamp as "H:MMam/pm" in local time
    private function _fmtTimeSec(tsSec as Number) as String {
        var moment = new Time.Moment(tsSec);
        var info   = Gregorian.info(moment, Time.FORMAT_SHORT);
        var h    = info.hour;
        var min  = info.min;
        var ampm = h >= 12 ? "pm" : "am";
        var h12  = h % 12;
        if (h12 == 0) { h12 = 12; }
        var mStr = min < 10 ? "0" + min.toString() : min.toString();
        return h12.toString() + ":" + mStr + ampm;
    }

    // Word-wrap name: if > 22 chars, split at last space at/before char 22.
    // Lines spaced 27px apart for readability.
    // Returns true if wrapping occurred (caller uses this to shift the warning).
    private function _drawWrappedName(dc as Graphics.Dc, name as String, y as Number) as Boolean {
        if (name.length() <= 22) {
            dc.drawText(CX, y, Graphics.FONT_XTINY, name,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return false;
        } else {
            var splitPos = 22;
            while (splitPos > 0 && !(name.substring(splitPos, splitPos + 1).equals(" "))) {
                splitPos--;
            }
            var line1;
            var line2;
            if (splitPos == 0) {
                line1 = name.substring(0, 22);
                line2 = name.substring(22, name.length());
            } else {
                line1 = name.substring(0, splitPos);
                line2 = name.substring(splitPos + 1, name.length());
            }
            dc.drawText(CX, y - 11, Graphics.FONT_XTINY, line1,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(CX, y + 16, Graphics.FONT_XTINY, line2,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return true;
        }
    }

    function refreshProfile(profile as Dictionary) as Void {
        _profile = profile;
        WatchUi.requestUpdate();
    }
}

// ── Preview Delegate ─────────────────────────────────────────────────────────

class PreviewDelegate extends WatchUi.BehaviorDelegate {

    private var _view     as PreviewView;
    private var _profile  as Dictionary;
    private var _listView as LogStimulantView;

    function initialize(view as PreviewView, profile as Dictionary,
                        settings as Dictionary, listView as LogStimulantView) {
        BehaviorDelegate.initialize();
        _view     = view;
        _profile  = profile;
        _listView = listView;
    }

    // Short back press → return to log list
    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onPreviousPage() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    // Hold back → Profile edit screen (real profiles only, not Misc id=0)
    function onMenu() as Boolean {
        if ((_profile["id"] as Number) == 0) { return false; }
        // Find current array index so ProfileEditView knows the sort order
        var profiles   = _listView.getProfiles();
        var profileIdx = 0;
        var targetId   = _profile["id"] as Number;
        for (var i = 0; i < profiles.size(); i++) {
            if ((profiles[i] as Dictionary)["id"] as Number == targetId) {
                profileIdx = i;
                break;
            }
        }
        var profView = new ProfileEditView(_profile, _view._settings,
            profileIdx + 1, profiles.size());
        WatchUi.pushView(
            profView,
            new ProfileEditDelegate(profView, _profile, _view._settings, _view, _listView, true),
            WatchUi.SLIDE_LEFT
        );
        return true;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var tapX   = coords[0];
        var tapY   = coords[1];

        if (_view.isLogItTap(tapX, tapY)) {
            _commitDose();
            return true;
        }

        if (_view.isAdjustTimeTap(tapX, tapY)) {
            var atView = new AdjustTimeView();
            WatchUi.pushView(
                atView,
                new AdjustTimeDelegate(atView, _view, _profile),
                WatchUi.SLIDE_LEFT
            );
            return true;
        }
        return false;
    }

    private function _commitDose() as Void {
        var caffMg    = _profile["caffeineMg"] as Number;
        var name      = _profile["name"] as String;
        var profileId = _profile["id"] as Number;

        var startSec;
        var finishSec;
        if (_view._startSec > 0) {
            startSec  = _view._startSec;
            finishSec = (_view._finishSec > _view._startSec) ? _view._finishSec : startSec;
        } else {
            startSec  = Time.now().value().toNumber();
            finishSec = startSec;
        }

        StimTrackerStorage.logDoseWithWindow(profileId, name, caffMg, startSec, finishSec);

        WatchUi.popView(WatchUi.SLIDE_DOWN);  // pop Preview
        WatchUi.popView(WatchUi.SLIDE_DOWN);  // pop LogStimulant (normal) or MiscCaffeine
        if (profileId == 0) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);  // also pop LogStimulant for Misc
        }
    }
}

// ── Profile Edit View ─────────────────────────────────────────────────────────

class ProfileEditView extends WatchUi.View {

    private const CX = 227;

    var _profile           as Dictionary;
    var _name              as String;
    var _caffMg            as Number;
    var _sortOrder         as Number;
    var _originalSortOrder as Number;
    var _totalProfiles     as Number;
    var _sortOrderSelected as Boolean;

    function initialize(profile as Dictionary, settings as Dictionary,
                        sortOrder as Number, totalProfiles as Number) {
        View.initialize();
        _profile           = profile;
        _name              = profile["name"] as String;
        _caffMg            = profile["caffeineMg"] as Number;
        _sortOrder         = sortOrder;
        _originalSortOrder = sortOrder;
        _totalProfiles     = totalProfiles;
        _sortOrderSelected = false;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // ── Title ─────────────────────────────────────────────────────────
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 30, Graphics.FONT_XTINY, "Edit Profile",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Name field ────────────────────────────────────────────────────
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 60, Graphics.FONT_XTINY, "Name:",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 88, Graphics.FONT_XTINY, _name,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Sort Order widget ─────────────────────────────────────────────
        var arrowColor = _sortOrderSelected
            ? Graphics.COLOR_GREEN
            : Graphics.COLOR_DK_GRAY;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 125, Graphics.FONT_XTINY, "Sort Order:",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (_sortOrderSelected) {
            dc.setColor(0x003300, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(CX - 26, 150, 52, 46, 6);
        }
        ArrowUtils.drawUpArrow(dc, CX, 143, ArrowUtils.HINT_ARROW_SIZE, arrowColor);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 175, Graphics.FONT_NUMBER_MILD, _sortOrder.toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        ArrowUtils.drawDownArrow(dc, CX, 202, ArrowUtils.HINT_ARROW_SIZE, arrowColor);

        // ── Caffeine mg field ─────────────────────────────────────────────
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 225, Graphics.FONT_XTINY, "Caffeine (mg):",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 219, Graphics.FONT_NUMBER_MEDIUM, _caffMg.toString(),
            Graphics.TEXT_JUSTIFY_CENTER);

        // +/- buttons
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(110, 220, Graphics.FONT_NUMBER_MEDIUM, "-",
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(344, 220, Graphics.FONT_NUMBER_MEDIUM, "+",
            Graphics.TEXT_JUSTIFY_CENTER);

        // ── Save button ───────────────────────────────────────────────────
        dc.setColor(0x007700, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(107, 308, 240, 50, 10);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 333, Graphics.FONT_XTINY, "Save",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Delete button ─────────────────────────────────────────────────
        dc.setColor(0x880000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(107, 368, 240, 50, 10);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 393, Graphics.FONT_XTINY, "Delete Profile",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function isNameTap(tapX as Number, tapY as Number) as Boolean {
        return tapY >= 68 && tapY <= 120;
    }

    function isSortOrderTap(tapX as Number, tapY as Number) as Boolean {
        return tapY >= 120 && tapY <= 200;
    }

    function isMinusTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 20 && tapX <= 145 && tapY >= 225 && tapY <= 305;
    }

    function isPlusTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 309 && tapX <= 434 && tapY >= 225 && tapY <= 305;
    }

    function isNumberTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 145 && tapX <= 309 && tapY >= 225 && tapY <= 305;
    }

    function isSaveTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 107 && tapX <= 347 && tapY >= 308 && tapY <= 358;
    }

    function isDeleteTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 107 && tapX <= 347 && tapY >= 368 && tapY <= 418;
    }

    function selectSortOrder() as Void {
        _sortOrderSelected = true;
        WatchUi.requestUpdate();
    }

    function incrementSortOrder() as Void {
        if (_sortOrder < _totalProfiles) { _sortOrder++; }
        WatchUi.requestUpdate();
    }

    function decrementSortOrder() as Void {
        if (_sortOrder > 1) { _sortOrder--; }
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
}

// ── Profile Edit Delegate ─────────────────────────────────────────────────────
// _fromPreview = true  → called from PreviewDelegate.onMenu (hold-back)
//                        save refreshes preview; delete pops 3 → back to Main
// _fromPreview = false → called from list long-press
//                        save refreshes list only; delete pops 2 → back to Main

class ProfileEditDelegate extends WatchUi.BehaviorDelegate {

    private var _view        as ProfileEditView;
    private var _profile     as Dictionary;
    private var _previewView as PreviewView or Null;
    private var _listView    as LogStimulantView;
    private var _fromPreview as Boolean;

    function initialize(view as ProfileEditView, profile as Dictionary,
                        settings as Dictionary, previewView as PreviewView or Null,
                        listView as LogStimulantView, fromPreview as Boolean) {
        BehaviorDelegate.initialize();
        _view        = view;
        _profile     = profile;
        _previewView = previewView;
        _listView    = listView;
        _fromPreview = fromPreview;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    // Swipe UP → increment sort order when field is selected
    function onNextPage() as Boolean {
        if (_view._sortOrderSelected) { _view.incrementSortOrder(); }
        return true;  // always consume
    }

    // Swipe DOWN → decrement sort order when field is selected; back button = cancel
    function onPreviousPage() as Boolean {
        if (_view._sortOrderSelected) { _view.decrementSortOrder(); }
        return true;  // always consume
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var tapX   = coords[0];
        var tapY   = coords[1];

        if (_view.isSortOrderTap(tapX, tapY)) {
            _view.selectSortOrder();
            return true;
        }

        if (_view.isNameTap(tapX, tapY)) {
            WatchUi.pushView(
                new WatchUi.TextPicker(_view._name),
                new ProfileNamePickerDelegate(_view),
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
                new ProfileCaffTextPickerDelegate(_view),
                WatchUi.SLIDE_UP
            );
            return true;
        }

        if (_view.isSaveTap(tapX, tapY)) {
            _save();
            return true;
        }

        if (_view.isDeleteTap(tapX, tapY)) {
            var confirm = new WatchUi.Confirmation(
                "Delete " + (_profile["name"] as String) + "?");
            WatchUi.pushView(confirm,
                new ProfileDeleteDelegate(_profile["id"] as Number, _listView, _fromPreview),
                WatchUi.SLIDE_UP);
            return true;
        }

        return false;
    }

    private function _save() as Void {
        var id     = _profile["id"] as Number;
        var oldIdx = _view._originalSortOrder - 1;
        var newIdx = _view._sortOrder - 1;

        // Apply sort order change first (array-position reorder)
        if (oldIdx != newIdx) {
            StimTrackerStorage.reorderProfile(oldIdx, newIdx);
        }
        // Update name / caffeine (finds by ID, safe after reorder)
        var updated = StimTrackerStorage.updateProfile(id, _view._name, _view._caffMg);
        _listView.refreshProfiles(updated);

        // Refresh preview behind us if we came from there
        if (_previewView != null) {
            _profile["name"]       = _view._name;
            _profile["caffeineMg"] = _view._caffMg;
            (_previewView as PreviewView).refreshProfile(_profile);
        }

        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

// ── Profile Name Picker Delegate ──────────────────────────────────────────────

class ProfileCaffTextPickerDelegate extends WatchUi.TextPickerDelegate {

    private var _editView as ProfileEditView;

    function initialize(editView as ProfileEditView) {
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

class ProfileNamePickerDelegate extends WatchUi.TextPickerDelegate {

    private var _editView as ProfileEditView;

    function initialize(editView as ProfileEditView) {
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

// ── Profile Delete Delegate ───────────────────────────────────────────────────
// _fromPreview = true  → stack is Main/LogStimulant/Preview/ProfileEdit → pop 3
// _fromPreview = false → stack is Main/LogStimulant/ProfileEdit          → pop 2

class ProfileDeleteDelegate extends WatchUi.ConfirmationDelegate {

    private var _profileId   as Number;
    private var _listView    as LogStimulantView;
    private var _fromPreview as Boolean;

    function initialize(profileId as Number, listView as LogStimulantView, fromPreview as Boolean) {
        ConfirmationDelegate.initialize();
        _profileId   = profileId;
        _listView    = listView;
        _fromPreview = fromPreview;
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            var updated = StimTrackerStorage.deleteProfile(_profileId);
            _listView.refreshProfiles(updated);
            WatchUi.popView(WatchUi.SLIDE_DOWN);  // pop ProfileEdit
            WatchUi.popView(WatchUi.SLIDE_DOWN);  // pop Preview (fromPreview) or LogStimulant
            if (_fromPreview) {
                WatchUi.popView(WatchUi.SLIDE_DOWN);  // also pop LogStimulant
            }
        } else {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
        return true;
    }
}

// ── Adjust Time View ──────────────────────────────────────────────────────────
// Two HH:MM pickers side by side (Start and Finish).
// Tap a column to select it. Swipe up/down increments/decrements the selection.
// Start Recording button starts live recording (saves pending dose, pops to main screen).
// Back applies the chosen times to the PreviewView.

class AdjustTimeView extends WatchUi.View {

    private const CX = 227;

    // Column x-centres for the four digit fields
    private const X_SH = 40;   // Start Hours
    private const X_SM = 112;  // Start Minutes
    private const X_SC = 76;   // Start colon x-centre
    private const X_FH = 336;  // Finish Hours
    private const X_FM = 408;  // Finish Minutes
    private const X_FC = 372;  // Finish colon x-centre

    // Row y-centres
    private const Y_UP     = 162;
    private const Y_NUM    = 207;
    private const Y_DOWN   = 252;
    private const Y_LABEL  = 280;
    private const Y_RECORD = 361;

    var _startH  as Number;
    var _startM  as Number;
    var _finishH as Number;
    var _finishM as Number;
    var _sel     as Number;  // 0=StartH 1=StartM 2=FinishH 3=FinishM

    function initialize() {
        View.initialize();
        var clock = System.getClockTime();
        _startH  = clock.hour;
        _startM  = clock.min;
        _finishH = clock.hour;
        _finishM = clock.min;
        _sel = 0;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // ── Header ───────────────────────────────────────────────────────
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 75, Graphics.FONT_XTINY, "Set Start & Finish times,",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 100, Graphics.FONT_XTINY, "or tap to begin Recording",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Selected field highlight ──────────────────────────────────────
        var selXArr = [X_SH, X_SM, X_FH, X_FM] as Array<Number>;
        var selX    = selXArr[_sel] as Number;
        dc.setColor(0x003300, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(selX - 28, Y_NUM - 26, 56, 52, 8);

        // ── Up arrows ────────────────────────────────────────────────────
        ArrowUtils.drawUpArrow(dc, X_SH, Y_UP, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);
        ArrowUtils.drawUpArrow(dc, X_SM, Y_UP, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);
        ArrowUtils.drawUpArrow(dc, X_FH, Y_UP, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);
        ArrowUtils.drawUpArrow(dc, X_FM, Y_UP, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);

        // ── Time digits ──────────────────────────────────────────────────
        _drawNum(dc, X_SH, _startH,  _sel == 0);
        _drawNum(dc, X_SM, _startM,  _sel == 1);
        _drawNum(dc, X_FH, _finishH, _sel == 2);
        _drawNum(dc, X_FM, _finishM, _sel == 3);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(X_SC, Y_NUM, Graphics.FONT_NUMBER_MILD, ":",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(X_FC, Y_NUM, Graphics.FONT_NUMBER_MILD, ":",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Down arrows ───────────────────────────────────────────────────
        ArrowUtils.drawDownArrow(dc, X_SH, Y_DOWN, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);
        ArrowUtils.drawDownArrow(dc, X_SM, Y_DOWN, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);
        ArrowUtils.drawDownArrow(dc, X_FH, Y_DOWN, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);
        ArrowUtils.drawDownArrow(dc, X_FM, Y_DOWN, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);

        // ── Section labels ────────────────────────────────────────────────
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(X_SC, Y_LABEL, Graphics.FONT_XTINY, "Start",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(X_FC, Y_LABEL, Graphics.FONT_XTINY, "Finish",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Save button (middle gap between the two time pickers) ─────────
        dc.setColor(0x007700, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(157, 235, 140, 66, 8);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 268, Graphics.FONT_XTINY, "Save",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── "or" separator ────────────────────────────────────────────────
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, Y_RECORD - 39, Graphics.FONT_XTINY, "or",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Start Recording button ────────────────────────────────────────
        dc.setColor(0x880000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(70, Y_RECORD - 10, 314, 72, 10);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, Y_RECORD + 26, Graphics.FONT_XTINY, "Start Recording",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function _drawNum(dc as Graphics.Dc, x as Number, val as Number, selected as Boolean) as Void {
        var color = selected ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var str = val < 10 ? "0" + val.toString() : val.toString();
        dc.drawText(x, Y_NUM, Graphics.FONT_NUMBER_MILD, str,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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

    // Tap within the picker rows selects a field
    function selectFromTap(tapX as Number, tapY as Number) as Void {
        if (tapY < Y_NUM - 26 || tapY > Y_NUM + 26) { return; }
        if (tapX < 224) {
            _sel = tapX < X_SC ? 0 : 1;
        } else {
            _sel = tapX < X_FC ? 2 : 3;
        }
        WatchUi.requestUpdate();
    }

    function isSaveTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 157 && tapX <= 297 && tapY >= 235 && tapY <= 301;
    }

    function isRecordTap(tapY as Number) as Boolean {
        return tapY >= Y_RECORD - 10 && tapY <= Y_RECORD + 62;
    }

    // Convert Start HH:MM to a Unix timestamp for today
    function getStartSec() as Number {
        return _todayAtHHMM(_startH, _startM);
    }

    // Convert Finish HH:MM to a Unix timestamp.
    // If finish < start (midnight wrap), add 86400.
    function getFinishSec() as Number {
        var s = _todayAtHHMM(_startH,  _startM);
        var f = _todayAtHHMM(_finishH, _finishM);
        if (f < s) { f += 86400; }
        return f;
    }

    // Compute Unix timestamp for H:M today in local time.
    // Uses clock delta to avoid Gregorian.moment() UTC/local ambiguity.
    private function _todayAtHHMM(h as Number, m as Number) as Number {
        var clock   = System.getClockTime();
        var nowSec  = Time.now().value().toNumber();
        var diffSec = (h - clock.hour) * 3600 + (m - clock.min) * 60 - clock.sec;
        return nowSec + diffSec;
    }
}

// ── Adjust Time Delegate ──────────────────────────────────────────────────────

class AdjustTimeDelegate extends WatchUi.BehaviorDelegate {

    private var _view        as AdjustTimeView;
    private var _previewView as PreviewView;
    private var _profile     as Dictionary;

    function initialize(view as AdjustTimeView, previewView as PreviewView,
                        profile as Dictionary) {
        BehaviorDelegate.initialize();
        _view        = view;
        _previewView = previewView;
        _profile     = profile;
    }

    // Swipe UP → increment selected field
    function onNextPage() as Boolean {
        _view.increment();
        return true;
    }

    // Swipe DOWN → decrement selected field
    function onPreviousPage() as Boolean {
        _view.decrement();
        return true;
    }

    // Back → apply times to PreviewView and return
    function onBack() as Boolean {
        _previewView.setTimings(_view.getStartSec(), _view.getFinishSec());
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var tapX   = coords[0];
        var tapY   = coords[1];

        if (_view.isSaveTap(tapX, tapY)) {
            _previewView.setTimings(_view.getStartSec(), _view.getFinishSec());
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return true;
        }

        if (_view.isRecordTap(tapY)) {
            // Save pending dose with start = now, then pop to main screen
            var profileId = _profile["id"]        as Number;
            var name      = _profile["name"]       as String;
            var caffMg    = _profile["caffeineMg"] as Number;
            var nowSec    = Time.now().value().toNumber();
            StimTrackerStorage.savePendingDose(profileId, name, caffMg, nowSec);
            // Pop AdjustTime → Preview → LogStimulant → back at Main
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return true;
        }

        _view.selectFromTap(tapX, tapY);
        return true;
    }
}
