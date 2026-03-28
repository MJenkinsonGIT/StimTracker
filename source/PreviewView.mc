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
    var _foodState as Number;  // per-dose food state for Precision mode (default Typical=1)
    var _peakInfo  as Array or Null;  // cached [peakMg, peakSec] — recomputed on input change

    function initialize(profile as Dictionary, settings as Dictionary) {
        View.initialize();
        _profile   = profile;
        _settings  = settings;
        _startSec  = 0;
        _finishSec = 0;
        _peakInfo  = null;  // will be computed on first onUpdate
        // Default food state for Precision mode: global standardFoodState, else Typical
        var model = settings.hasKey("absorptionModel") ? settings["absorptionModel"] as Number : 0;
        _foodState = (model == 2 && settings.hasKey("standardFoodState"))
            ? settings["standardFoodState"] as Number : 1;
    }

    // Recomputes the cached peak info from current profile, settings, and food state.
    // Called once on first draw, then only when setTimings/setFoodState/refreshProfile fires.
    function _recomputePeakInfo() as Void {
        var caffMg   = _profile["caffeineMg"] as Number;
        var doseType = (_profile as Dictionary).hasKey("type")
            ? (_profile as Dictionary)["type"] as String : "drink";
        var absModel = _settings.hasKey("absorptionModel") ? _settings["absorptionModel"] as Number : 0;
        var previewFs;
        if (absModel == 1) {
            previewFs = _settings.hasKey("standardFoodState") ? _settings["standardFoodState"] as Number : 1;
        } else {
            previewFs = _foodState;
        }
        _peakInfo = StimTrackerStorage.previewPeakInfo(caffMg, doseType, previewFs, _settings);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var name      = _profile["name"] as String;
        var caffMg    = _profile["caffeineMg"] as Number;
        var limitMg   = _settings["limitMg"] as Number;
        var oopsMg    = _settings["oopsThresholdMg"];
        var todayMg   = StimTrackerStorage.calcTodayTotalMg();

        var futureTotal = todayMg + caffMg;

        // Peak info: cached, recomputed only when inputs change.
        if (_peakInfo == null) { _recomputePeakInfo(); }
        var peakMg    = (_peakInfo as Array)[0] as Float;
        var peakSec   = (_peakInfo as Array)[1] as Number;
        var threshMg  = (_settings["sleepThresholdMg"] as Number).toFloat();
        var halfLife  = _settings["halfLifeHrs"] as Float;
        var ln2       = Math.log(2.0, Math.E).toFloat();
        var futureSleepStr;
        if (peakMg <= threshMg) {
            futureSleepStr = "Now";
        } else {
            var hoursFromPeak  = halfLife * (Math.log(peakMg / threshMg, Math.E) / ln2).toFloat();
            var futureSleepSec = peakSec + (hoursFromPeak * 3600.0f).toNumber();
            futureSleepStr = StimTrackerStorage.formatSleepSec(futureSleepSec);
        }

        var exceedsLimit = futureTotal > limitMg;
        var exceedsOops  = false;
        if (oopsMg != null) {
            exceedsOops = peakMg > (oopsMg as Float);
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
        var sleepLabel = peakMg <= threshMg
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
            "Peak: " + peakMg.toNumber().toString() + "mg at " + StimTrackerStorage.formatSleepSec(peakSec),
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

        // ── Dose Options button ───────────────────────────────────────────
        dc.setColor(0x880000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(107, 387, 240, 53, 10);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 413, Graphics.FONT_XTINY, "Dose Options",
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
        _peakInfo  = null;  // invalidate — onUpdate() will recompute (not a tap handler)
        WatchUi.requestUpdate();
    }

    // Update per-dose food state (called by AdjustTimeDelegate).
    function setFoodState(fs as Number) as Void {
        _foodState = fs;
        _peakInfo  = null;  // invalidate — onUpdate() will recompute (not a tap handler)
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
        _profile  = profile;
        _peakInfo = null;  // invalidate — will recompute on next draw
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
            var atView = new AdjustTimeView(_view._settings);
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

        // Get dose type from profile (migration default: "drink")
        var doseType = (_profile as Dictionary).hasKey("type")
            ? (_profile as Dictionary)["type"] as String : "drink";
        var settings  = _view._settings;
        var absModel  = settings.hasKey("absorptionModel")
            ? settings["absorptionModel"] as Number : 0;
        var foodState;
        if (absModel == 1) {
            // Standard: global food state
            foodState = settings.hasKey("standardFoodState")
                ? settings["standardFoodState"] as Number : 1;
        } else if (absModel == 2) {
            // Precision: per-dose food state set via Dose Options
            foodState = _view._foodState;
        } else {
            foodState = 1;
        }
        StimTrackerStorage.logDoseWithWindow(profileId, name, caffMg, startSec, finishSec,
            doseType, foodState);

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
    var _gearBmp           as WatchUi.BitmapResource;

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
        _gearBmp           = WatchUi.loadResource(Rez.Drawables.GearIcon) as WatchUi.BitmapResource;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 30, Graphics.FONT_XTINY, "Edit Profile",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 60, Graphics.FONT_XTINY, "Name:",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 88, Graphics.FONT_XTINY, _name,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Gear icon (Parameters) -- right bezel, between name and sort order
        dc.drawBitmap(395 - _gearBmp.getWidth() / 2, 108 - _gearBmp.getHeight() / 2, _gearBmp);

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

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 225, Graphics.FONT_XTINY, "Caffeine (mg):",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 219, Graphics.FONT_NUMBER_MEDIUM, _caffMg.toString(),
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(110, 220, Graphics.FONT_NUMBER_MEDIUM, "-",
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(344, 220, Graphics.FONT_NUMBER_MEDIUM, "+",
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x007700, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(107, 308, 240, 50, 10);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 333, Graphics.FONT_XTINY, "Save",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(0x880000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(107, 368, 240, 50, 10);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 393, Graphics.FONT_XTINY, "Delete Profile",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function isNameTap(tapX as Number, tapY as Number) as Boolean {
        return tapY >= 68 && tapY <= 120;
    }

    // Gear tap -- centred on (395, 108), r=14 → 40px touch target
    function isGearTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 355 && tapX <= 435 && tapY >= 88 && tapY <= 128;
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

class ProfileEditDelegate extends WatchUi.BehaviorDelegate {

    private var _view        as ProfileEditView;
    private var _profile     as Dictionary;
    private var _previewView as PreviewView or Null;
    private var _listView    as LogStimulantView;
    private var _fromPreview as Boolean;
    private var _paramsView  as ProfileParamsView;
    private var _settings    as Dictionary;

    function initialize(view as ProfileEditView, profile as Dictionary,
                        settings as Dictionary, previewView as PreviewView or Null,
                        listView as LogStimulantView, fromPreview as Boolean) {
        BehaviorDelegate.initialize();
        _view        = view;
        _profile     = profile;
        _settings    = settings;
        _previewView = previewView;
        _listView    = listView;
        _fromPreview = fromPreview;
        var profileType = (profile as Dictionary).hasKey("type")
            ? (profile as Dictionary)["type"] as String : "drink";
        _paramsView = new ProfileParamsView(profileType, settings);
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    // Top button (KEY_ENTER) opens the same params screen as the gear icon.
    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        if (evt.getKey() == WatchUi.KEY_ENTER) {
            WatchUi.pushView(_paramsView,
                new ProfileParamsDelegate(_paramsView, _settings),
                WatchUi.SLIDE_LEFT);
            return true;
        }
        return false;
    }

    function onNextPage() as Boolean {
        if (_view._sortOrderSelected) { _view.incrementSortOrder(); }
        return true;
    }

    function onPreviousPage() as Boolean {
        if (_view._sortOrderSelected) { _view.decrementSortOrder(); }
        return true;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var tapX   = coords[0];
        var tapY   = coords[1];

        // Gear checked before name: both share the y=88-120 zone.
        if (_view.isGearTap(tapX, tapY)) {
            WatchUi.pushView(_paramsView,
                new ProfileParamsDelegate(_paramsView, _settings),
                WatchUi.SLIDE_LEFT);
            return true;
        }

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

        if (oldIdx != newIdx) {
            StimTrackerStorage.reorderProfile(oldIdx, newIdx);
        }
        var updated = StimTrackerStorage.updateProfile(id, _view._name, _view._caffMg,
            _paramsView._type);
        _listView.refreshProfiles(updated);

        if (_previewView != null) {
            _profile["name"]       = _view._name;
            _profile["caffeineMg"] = _view._caffMg;
            (_previewView as PreviewView).refreshProfile(_profile);
        }

        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

// ── Profile Picker Delegates ──────────────────────────────────────────────────

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
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            if (_fromPreview) {
                WatchUi.popView(WatchUi.SLIDE_DOWN);
            }
        } else {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
        return true;
    }
}

// ── Adjust Time View ──────────────────────────────────────────────────────────

class AdjustTimeView extends WatchUi.View {

    private const CX = 227;

    private const X_SH = 40;
    private const X_SM = 112;
    private const X_SC = 76;
    private const X_FH = 336;
    private const X_FM = 408;
    private const X_FC = 372;

    private const Y_UP     = 162;
    private const Y_NUM    = 207;
    private const Y_DOWN   = 252;
    private const Y_LABEL  = 280;
    private const Y_RECORD = 361;

    var _startH    as Number;
    var _startM    as Number;
    var _finishH   as Number;
    var _finishM   as Number;
    var _sel       as Number;
    var _foodState as Number;
    var _settings  as Dictionary;

    function initialize(settings as Dictionary) {
        View.initialize();
        var clock  = System.getClockTime();
        _startH    = clock.hour;
        _startM    = clock.min;
        _finishH   = clock.hour;
        _finishM   = clock.min;
        _sel       = 0;
        _settings  = settings;
        var model  = settings.hasKey("absorptionModel") ? settings["absorptionModel"] as Number : 0;
        _foodState = (model == 2 && settings.hasKey("standardFoodState"))
            ? settings["standardFoodState"] as Number : 1;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 75, Graphics.FONT_XTINY, "Set Start & Finish times,",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 100, Graphics.FONT_XTINY, "or tap to begin Recording",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var selXArr = [X_SH, X_SM, X_FH, X_FM] as Array<Number>;
        var selX    = selXArr[_sel] as Number;
        dc.setColor(0x003300, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(selX - 28, Y_NUM - 26, 56, 52, 8);

        ArrowUtils.drawUpArrow(dc, X_SH, Y_UP, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);
        ArrowUtils.drawUpArrow(dc, X_SM, Y_UP, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);
        ArrowUtils.drawUpArrow(dc, X_FH, Y_UP, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);
        ArrowUtils.drawUpArrow(dc, X_FM, Y_UP, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);

        _drawNum(dc, X_SH, _startH,  _sel == 0);
        _drawNum(dc, X_SM, _startM,  _sel == 1);
        _drawNum(dc, X_FH, _finishH, _sel == 2);
        _drawNum(dc, X_FM, _finishM, _sel == 3);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(X_SC, Y_NUM, Graphics.FONT_NUMBER_MILD, ":",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(X_FC, Y_NUM, Graphics.FONT_NUMBER_MILD, ":",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        ArrowUtils.drawDownArrow(dc, X_SH, Y_DOWN, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);
        ArrowUtils.drawDownArrow(dc, X_SM, Y_DOWN, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);
        ArrowUtils.drawDownArrow(dc, X_FH, Y_DOWN, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);
        ArrowUtils.drawDownArrow(dc, X_FM, Y_DOWN, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_LT_GRAY);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(X_SC, Y_LABEL, Graphics.FONT_XTINY, "Start",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(X_FC, Y_LABEL, Graphics.FONT_XTINY, "Finish",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Food state cycling button (Precision mode only) -- above Save, y=155-189.
        var doseModel = _settings.hasKey("absorptionModel")
            ? _settings["absorptionModel"] as Number : 0;
        if (doseModel == 2) {
            var fsStr = _foodState == 0 ? "Fasted"
                      : _foodState == 2 ? "With Food"
                      : "Typical";
            dc.setColor(0x004477, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(157, 140, 140, 64, 8);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(CX, 172, Graphics.FONT_XTINY, fsStr,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Save button -- original position
        dc.setColor(0x007700, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(157, 235, 140, 66, 8);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 268, Graphics.FONT_XTINY, "Save",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // "or" separator -- always shown between Save and Start Recording
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, Y_RECORD - 39, Graphics.FONT_XTINY, "or",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

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

    function fieldForTap(tapX as Number, tapY as Number) as Number {
        if (tapY < Y_NUM - 26 || tapY > Y_NUM + 26) { return -1; }
        if (tapX < 224) {
            return tapX < X_SC ? 0 : 1;
        } else {
            return tapX < X_FC ? 2 : 3;
        }
    }

    function selectFromTap(tapX as Number, tapY as Number) as Void {
        var col = fieldForTap(tapX, tapY);
        if (col >= 0) { _sel = col; WatchUi.requestUpdate(); }
    }

    function getFieldVal(col as Number) as Number {
        if (col == 0) { return _startH; }
        if (col == 1) { return _startM; }
        if (col == 2) { return _finishH; }
        return _finishM;
    }

    function setFieldVal(col as Number, val as Number) as Void {
        if (col == 0)      { _startH  = val; }
        else if (col == 1) { _startM  = val; }
        else if (col == 2) { _finishH = val; }
        else               { _finishM = val; }
        WatchUi.requestUpdate();
    }

    // Save tap -- original fixed hitbox.
    function isSaveTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 157 && tapX <= 297 && tapY >= 235 && tapY <= 301;
    }

    // Food state cycling button tap (Precision mode only) -- matches button at y=155-189.
    function isFoodStateCycleTap(tapX as Number, tapY as Number) as Boolean {
        var model = _settings.hasKey("absorptionModel")
            ? _settings["absorptionModel"] as Number : 0;
        if (model != 2) { return false; }
        return tapX >= 157 && tapX <= 297 && tapY >= 140 && tapY <= 204;
    }

    function isRecordTap(tapY as Number) as Boolean {
        return tapY >= Y_RECORD - 10 && tapY <= Y_RECORD + 62;
    }

    function getStartSec() as Number {
        return _todayAtHHMM(_startH, _startM);
    }

    function getFinishSec() as Number {
        var s = _todayAtHHMM(_startH,  _startM);
        var f = _todayAtHHMM(_finishH, _finishM);
        if (f < s) { f += 86400; }
        return f;
    }

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

    function onNextPage() as Boolean {
        _view.increment();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.decrement();
        return true;
    }

    function onBack() as Boolean {
        _previewView.setTimings(_view.getStartSec(), _view.getFinishSec());
        _previewView.setFoodState(_view._foodState);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onHold(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var col    = _view.fieldForTap(coords[0], coords[1]);
        if (col < 0) { return false; }
        var isHour = (col == 0 || col == 2);
        WatchUi.pushView(
            new WatchUi.TextPicker(_view.getFieldVal(col).toString()),
            new AdjustTimeFieldPickerDelegate(_view, col, isHour),
            WatchUi.SLIDE_UP
        );
        return true;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var tapX   = coords[0];
        var tapY   = coords[1];

        if (_view.isFoodStateCycleTap(tapX, tapY)) {
            _view._foodState = (_view._foodState + 1) % 3;
            WatchUi.requestUpdate();
            return true;
        }

        if (_view.isSaveTap(tapX, tapY)) {
            _previewView.setTimings(_view.getStartSec(), _view.getFinishSec());
            _previewView.setFoodState(_view._foodState);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return true;
        }

        if (_view.isRecordTap(tapY)) {
            var profileId = _profile["id"]        as Number;
            var name      = _profile["name"]       as String;
            var caffMg    = _profile["caffeineMg"] as Number;
            var startSec  = _view.getStartSec();
            var pType = (_profile as Dictionary).hasKey("type")
                ? (_profile as Dictionary)["type"] as String : "drink";
            StimTrackerStorage.savePendingDose(profileId, name, caffMg, startSec, pType, _view._foodState);
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return true;
        }

        _view.selectFromTap(tapX, tapY);
        return true;
    }
}

// ── Adjust Time Field Text Picker Delegate ────────────────────────────────────

class AdjustTimeFieldPickerDelegate extends WatchUi.TextPickerDelegate {

    private var _view   as AdjustTimeView;
    private var _col    as Number;
    private var _isHour as Boolean;

    function initialize(view as AdjustTimeView, col as Number, isHour as Boolean) {
        TextPickerDelegate.initialize();
        _view   = view;
        _col    = col;
        _isHour = isHour;
    }

    function onTextEntered(text as String, changed as Boolean) as Boolean {
        var num = text.toNumber();
        if (num != null) {
            var max = _isHour ? 23 : 59;
            if (num < 0)   { num = 0; }
            if (num > max) { num = max; }
            _view.setFieldVal(_col, num);
        }
        return true;
    }

    function onCancel() as Boolean {
        return true;
    }
}
