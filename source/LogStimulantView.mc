// LogStimulantView.mc
// Scrollable list of stimulant profiles.
// Row 0 is always the special "Misc" quick-log entry (never stored as a profile).
// Rows 1..n are user profiles. Last row is "+ Add New Stimulant".
//
// Tap profile row   → PreviewView
// Tap Misc row      → MiscCaffeineView (enter mg on the fly, no profile saved)
// Long-press row    → ProfileEditView (edit name/mg/delete) — real profiles only
// Tap Add New       → EditStimulantView (add-new mode)

import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

class LogStimulantView extends WatchUi.View {

    private const ROW_H      = 75;
    private const LIST_TOP   = 97;
    private const LIST_BOT   = 397;
    private const ROWS_VIS   = 4;
    private const CX         = 227;

    var _profiles    as Array<Dictionary>;
    var _settings    as Dictionary;
    var _scrollPos   as Number;

    function initialize(profiles as Array<Dictionary>, settings as Dictionary) {
        View.initialize();
        _profiles  = profiles;
        _settings  = settings;
        _scrollPos = 0;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 30, Graphics.FONT_XTINY, "Log Stimulant",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 65, Graphics.FONT_XTINY, "Hold to edit",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Total rows: 1 Misc + profiles + 1 Add New
        var totalRows = 1 + _profiles.size() + 1;

        for (var i = 0; i < ROWS_VIS; i++) {
            var rowIdx = _scrollPos + i;
            if (rowIdx >= totalRows) { break; }

            var y = LIST_TOP + i * ROW_H;

            if (rowIdx == 0) {
                // ── Misc row ─────────────────────────────────────────────
                dc.setColor(0x00AAAA, Graphics.COLOR_TRANSPARENT);
                dc.drawText(CX, y + 20, Graphics.FONT_XTINY, "Misc",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(CX, y + 55, Graphics.FONT_XTINY, "Quick log, no profile",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

            } else if (rowIdx <= _profiles.size()) {
                // ── Profile row ───────────────────────────────────────────
                var p         = _profiles[rowIdx - 1] as Dictionary;
                var name      = p["name"] as String;
                var caffMg    = p["caffeineMg"] as Number;
                var oopsMg    = _settings["oopsThresholdMg"];
                var limitMg   = _settings["limitMg"] as Number;
                var todayMg   = StimTrackerStorage.calcTodayTotalMg();

                var wouldExceedLimit = (todayMg + caffMg) > limitMg;
                var wouldExceedOops  = false;
                if (oopsMg != null) {
                    var futureInSystem = StimTrackerStorage.previewCurrentMgAfterDose(caffMg, _settings);
                    wouldExceedOops = futureInSystem > (oopsMg as Float);
                }

                var rowColor = Graphics.COLOR_WHITE;
                if (wouldExceedOops)       { rowColor = Graphics.COLOR_RED; }
                else if (wouldExceedLimit) { rowColor = Graphics.COLOR_ORANGE; }

                dc.setColor(rowColor, Graphics.COLOR_TRANSPARENT);
                dc.drawText(CX, y + 20, Graphics.FONT_XTINY, name,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(CX, y + 55, Graphics.FONT_XTINY,
                    caffMg.toString() + "mg",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                dc.drawText(50, y + 55, Graphics.FONT_XTINY,
                    rowIdx.toString(),
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

            } else {
                // ── Add New row ───────────────────────────────────────────
                dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(CX, y + ROW_H / 2, Graphics.FONT_XTINY,
                    "+ Add New Stimulant",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }

            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(40, y + ROW_H - 2, 414, y + ROW_H - 2);
        }

        // Scroll arrows
        if (_scrollPos > 0) {
            ArrowUtils.drawUpArrow(dc, CX, 79, ArrowUtils.HINT_ARROW_SIZE,
                Graphics.COLOR_LT_GRAY);
        }
        if (_scrollPos + ROWS_VIS < totalRows) {
            ArrowUtils.drawDownArrow(dc, CX, LIST_BOT + 12, ArrowUtils.HINT_ARROW_SIZE,
                Graphics.COLOR_LT_GRAY);
        }
    }

    // Map tap Y to row index.
    // 0 = Misc, 1..n = profiles, n+1 = Add New, -1 = outside list.
    function rowForTapY(tapY as Number) as Number {
        if (tapY < LIST_TOP || tapY >= LIST_BOT) { return -1; }
        var relY      = tapY - LIST_TOP;
        var rowIdx    = _scrollPos + (relY / ROW_H);
        var totalRows = 1 + _profiles.size() + 1;
        if (rowIdx >= totalRows) { return -1; }
        return rowIdx;
    }

    function getProfiles() as Array<Dictionary> {
        return _profiles;
    }

    function scrollDown() as Void {
        var totalRows = 1 + _profiles.size() + 1;
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

    function refreshProfiles(profiles as Array<Dictionary>) as Void {
        _profiles = profiles;
        var maxScroll = 1 + _profiles.size() + 1 - ROWS_VIS;
        if (maxScroll < 0) { maxScroll = 0; }
        if (_scrollPos > maxScroll) { _scrollPos = maxScroll; }
        WatchUi.requestUpdate();
    }
}

// ── Log Stimulant Delegate ───────────────────────────────────────────────────

class LogStimulantDelegate extends WatchUi.BehaviorDelegate {

    private var _view     as LogStimulantView;
    private var _settings as Dictionary;

    function initialize(view as LogStimulantView, profiles as Array<Dictionary>, settings as Dictionary) {
        BehaviorDelegate.initialize();
        _view     = view;
        _settings = settings;
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
        var coords   = evt.getCoordinates();
        var tapY     = coords[1];
        var rowIdx   = _view.rowForTapY(tapY);
        if (rowIdx < 0) { return false; }

        var profiles = _view.getProfiles();

        if (rowIdx == 0) {
            // Misc quick-log
            var miscView = new MiscCaffeineView();
            WatchUi.pushView(
                miscView,
                new MiscCaffeineDelegate(miscView, _settings, _view),
                WatchUi.SLIDE_LEFT
            );
        } else if (rowIdx <= profiles.size()) {
            // Real profile tap → Preview
            var profile  = profiles[rowIdx - 1] as Dictionary;
            var prevView = new PreviewView(profile, _settings);
            WatchUi.pushView(
                prevView,
                new PreviewDelegate(prevView, profile, _settings, _view),
                WatchUi.SLIDE_UP
            );
        } else {
            // Add New
            var editView = new EditStimulantView(null, _settings);
            WatchUi.pushView(
                editView,
                new EditStimulantDelegate(editView, null, _settings, _view),
                WatchUi.SLIDE_LEFT
            );
        }
        return true;
    }

    // Long-press → go directly to unified ProfileEditView (real profiles only)
    function onHold(evt as WatchUi.ClickEvent) as Boolean {
        var coords   = evt.getCoordinates();
        var tapY     = coords[1];
        var rowIdx   = _view.rowForTapY(tapY);
        var profiles = _view.getProfiles();

        // Only respond to long-press on real profile rows (not Misc, not Add New)
        if (rowIdx <= 0 || rowIdx > profiles.size()) { return false; }

        var profile  = profiles[rowIdx - 1] as Dictionary;
        // rowIdx 1..n → array index (rowIdx-1), sort order = rowIdx
        var profView = new ProfileEditView(profile, _settings, rowIdx, profiles.size());
        WatchUi.pushView(
            profView,
            new ProfileEditDelegate(profView, profile, _settings, null, _view, false),
            WatchUi.SLIDE_LEFT
        );
        return true;
    }
}

// ── Misc Caffeine Text Picker Delegate ──────────────────────────────────────────

class MiscCaffTextPickerDelegate extends WatchUi.TextPickerDelegate {

    private var _miscView as MiscCaffeineView;

    function initialize(miscView as MiscCaffeineView) {
        TextPickerDelegate.initialize();
        _miscView = miscView;
    }

    function onTextEntered(text as String, changed as Boolean) as Boolean {
        var num = text.toNumber();
        if (num != null) {
            if (num < 10)   { num = 10; }
            if (num > 1000) { num = 1000; }
            _miscView._caffMg = num;
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onCancel() as Boolean {
        return true;
    }
}

// ── Delete Confirmation Delegate ─────────────────────────────────────────────
// Used by EditStimulantDelegate for "Add New" delete path (unused currently,
// but kept for safety). Profile-edit deletes use ProfileDeleteDelegate.

class DeleteConfirmDelegate extends WatchUi.ConfirmationDelegate {

    private var _profileId as Number;
    private var _listView  as LogStimulantView;

    function initialize(profileId as Number, listView as LogStimulantView) {
        ConfirmationDelegate.initialize();
        _profileId = profileId;
        _listView  = listView;
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            var updated = StimTrackerStorage.deleteProfile(_profileId);
            _listView.refreshProfiles(updated);
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}

// ── Misc Caffeine View ────────────────────────────────────────────────────────
// Quick-log screen for one-off caffeine amounts.
// User sets mg with +/-, taps Preview to go straight to the confirm screen.
// Nothing is saved to profiles.

class MiscCaffeineView extends WatchUi.View {

    private const CX = 227;

    var _caffMg as Number;

    function initialize() {
        View.initialize();
        _caffMg = 100;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // ── Title ─────────────────────────────────────────────────────────
        dc.setColor(0x00AAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 35, Graphics.FONT_XTINY, "Misc Quick Log",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Label ─────────────────────────────────────────────────────────
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 90, Graphics.FONT_XTINY, "How much caffeine?",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── mg value ──────────────────────────────────────────────────────
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 150, Graphics.FONT_NUMBER_MEDIUM, _caffMg.toString(),
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 255, Graphics.FONT_XTINY, "mg",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── +/- buttons ───────────────────────────────────────────────────
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(90, 142, Graphics.FONT_NUMBER_MEDIUM, "-",
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(364, 142, Graphics.FONT_NUMBER_MEDIUM, "+",
            Graphics.TEXT_JUSTIFY_CENTER);

        // ── Preview button ────────────────────────────────────────────────
        dc.setColor(0x007700, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(107, 288, 240, 50, 10);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 313, Graphics.FONT_XTINY, "Preview",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Cancel bar ────────────────────────────────────────────────────
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 380, dc.getWidth(), 23);
        ArrowUtils.drawDownArrow(dc, CX - 49, 391, ArrowUtils.HINT_ARROW_SIZE,
            Graphics.COLOR_LT_GRAY);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX - 35, 391, Graphics.FONT_XTINY, "Cancel",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function isMinusTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 20 && tapX <= 145 && tapY >= 165 && tapY <= 245;
    }

    function isPlusTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 309 && tapX <= 434 && tapY >= 165 && tapY <= 245;
    }

    function isNumberTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 145 && tapX <= 309 && tapY >= 165 && tapY <= 245;
    }

    function isPreviewTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 107 && tapX <= 347 && tapY >= 288 && tapY <= 338;
    }

    function decrementMg() as Void {
        if (_caffMg > 10) { _caffMg -= 10; }
        WatchUi.requestUpdate();
    }

    function incrementMg() as Void {
        if (_caffMg < 1000) { _caffMg += 10; }
        WatchUi.requestUpdate();
    }
}

// ── Misc Caffeine Delegate ────────────────────────────────────────────────────

class MiscCaffeineDelegate extends WatchUi.BehaviorDelegate {

    private var _view     as MiscCaffeineView;
    private var _settings as Dictionary;
    private var _listView as LogStimulantView;

    function initialize(view as MiscCaffeineView, settings as Dictionary,
                        listView as LogStimulantView) {
        BehaviorDelegate.initialize();
        _view     = view;
        _settings = settings;
        _listView = listView;
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
                new MiscCaffTextPickerDelegate(_view),
                WatchUi.SLIDE_UP
            );
            return true;
        }

        if (_view.isPreviewTap(tapX, tapY)) {
            // Build a temporary Misc profile dict (id=0, never stored in profiles)
            var miscProfile = {
                "id"         => 0,
                "name"       => "Misc",
                "caffeineMg" => _view._caffMg
            } as Dictionary;
            var prevView = new PreviewView(miscProfile, _settings);
            WatchUi.pushView(
                prevView,
                new PreviewDelegate(prevView, miscProfile, _settings, _listView),
                WatchUi.SLIDE_UP
            );
            return true;
        }

        return false;
    }
}
