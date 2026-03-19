// MainView.mc
// The status hub — shows current caffeine in system, today's total,
// and sleep-safe time. Refreshes every time it is shown.

import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;

class MainView extends WatchUi.View {

    // Layout constants (454x454 display, safe zone y=42 to y=412)
    private const CX = 227;
    private const CY = 227;

    // Shared settings reference (updated by delegate when settings change)
    var _settings as Dictionary;

    function initialize(settings as Dictionary) {
        View.initialize();
        _settings = settings;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var limitMg   = _settings["limitMg"] as Number;
        var totalMg   = StimTrackerStorage.calcTodayTotalMg();
        var currentMg = StimTrackerStorage.calcCurrentMg(_settings);
        var minsLeft  = StimTrackerStorage.minutesUntilSleepSafe(_settings);

        // ── Large centre: current mg in system ───────────────────────────
        var currentRounded = currentMg.toNumber();
        var currentColor   = _currentColor(currentMg, limitMg);
        dc.setColor(currentColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, CY - 129, Graphics.FONT_NUMBER_HOT,
            currentRounded.toString(),
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, CY - 9, Graphics.FONT_XTINY,
            "mg in system",
            Graphics.TEXT_JUSTIFY_CENTER);

        // ── Today total / limit ──────────────────────────────────────────
        var totalColor = totalMg >= limitMg ? Graphics.COLOR_RED : Graphics.COLOR_WHITE;
        dc.setColor(totalColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 80, Graphics.FONT_SMALL,
            totalMg.toString() + " / " + limitMg.toString() + " mg",
            Graphics.TEXT_JUSTIFY_CENTER);

        // ── Sleep-safe time or Recording indicator ──────────────────────────
        var pending = StimTrackerStorage.loadPendingDose();
        if (pending != null) {
            var recName = pending["name"] as String;
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(CX, 252, Graphics.FONT_XTINY, "Recording:",
                Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            _drawRecordingName(dc, recName, 285);
        } else {
            var sleepColor = minsLeft < 0 ? Graphics.COLOR_GREEN : Graphics.COLOR_YELLOW;
            var sleepLabel = "Below Sleep Threshold:";
            var sleepStr   = minsLeft < 0 ? "Now" : StimTrackerStorage.formatSleepTime(minsLeft);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(CX, 265, Graphics.FONT_XTINY,
                sleepLabel,
                Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(sleepColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(CX, 300, Graphics.FONT_SMALL,
                sleepStr,
                Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ── Oops button (top-right) ────────────────────────────────────────
        _drawOopsButton(dc);

        // ── Footer bar 1: Settings (circle-clipped, wider at this y) ─────────────
        _fillCircularBar(dc, 355, 27, 0x333333);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 368, Graphics.FONT_XTINY, "Hold Back=Settings",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Footer bar 2: Log / History  —or—  Finish when recording ───────
        if (pending != null) {
            _fillCircularBar(dc, 384, 50, 0x550000);
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(CX, 397, Graphics.FONT_XTINY, "End Recording",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            _fillCircularBar(dc, 384, 27, 0x333333);
            ArrowUtils.drawUpDownPair(dc, CX, 397, "Log", "History",
                Graphics.FONT_XTINY, Graphics.COLOR_LT_GRAY);
        }

        // ── Arc drawn last so it renders on top of the footer bars ───────
        _drawArc(dc, totalMg, limitMg);
    }

    // Returns the tap region for the Finish Recording button — [x1, y1, x2, y2]
    function finishButtonRegion() as Array<Number> {
        return [60, 364, 394, 434] as Array<Number>;
    }

    // Draw a coloured progress arc representing today's total vs limit.
    // Arc is drawn as a series of filled rectangles (avoid fillPolygon in loops).
    private function _drawArc(dc as Graphics.Dc, totalMg as Number, limitMg as Number) as Void {
        var fillRatio = totalMg.toFloat() / limitMg.toFloat();
        if (fillRatio > 1.0f) { fillRatio = 1.0f; }

        // Choose arc colour
        var arcColor = Graphics.COLOR_GREEN;
        if (fillRatio >= 1.0f) {
            arcColor = Graphics.COLOR_RED;
        } else if (fillRatio >= 0.8f) {
            arcColor = Graphics.COLOR_ORANGE;
        } else if (fillRatio >= 0.5f) {
            arcColor = Graphics.COLOR_YELLOW;
        }

        // Draw arc using dc.drawArc (SDK built-in — no polygon loops needed)
        // Arc goes from top (270°) clockwise. SDK drawArc goes counter-clockwise
        // from startAngle to endAngle, so we invert.
        var arcDegrees = (fillRatio * 360.0f).toNumber();
        var radius     = 210;
        var thickness  = 8;

        // Draw grey background ring
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(CX, CY, radius, Graphics.ARC_CLOCKWISE, 270, 270 - 359);

        if (arcDegrees > 0) {
            dc.setColor(arcColor, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(thickness);
            dc.drawArc(CX, CY, radius, Graphics.ARC_CLOCKWISE, 270, 270 - arcDegrees);
            dc.setPenWidth(1);
        }
    }

    private function _drawOopsButton(dc as Graphics.Dc) as Void {
        // Heart bitmap (40x40, transparent background), centred at (CX, 40)
        var heart = WatchUi.loadResource(Rez.Drawables.OopsHeart) as WatchUi.BitmapResource;
        dc.drawBitmap(CX - 26, 26, heart);
        // White "!" centred on the heart
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX - 2, 30, Graphics.FONT_TINY, "!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Fill a horizontal bar clipped to the progress arc circle (radius 210).
    // Draws 1px-tall strips row by row, each clipped to the arc boundary.
    private function _fillCircularBar(dc as Graphics.Dc, y as Number, barH as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var rSq = 210 * 210;  // arc radius² = 44100
        for (var row = y; row < y + barH; row++) {
            var dy  = row - CY;
            var rem = rSq - dy * dy;
            if (rem <= 0) { continue; }
            var hw = Math.sqrt(rem.toFloat()).toNumber();
            dc.fillRectangle(CX - hw, row, hw * 2, 1);
        }
    }

    // Draw the recording stim name at FONT_XTINY, wrapping if it would exceed
    // the safe inner width at that y-coordinate (circle radius 210, centre 227).
    // Splits at the last space before char 20; draws two lines 22px apart.
    private function _drawRecordingName(dc as Graphics.Dc, name as String, y as Number) as Void {
        if (name.length() <= 20) {
            dc.drawText(CX, y + 14, Graphics.FONT_XTINY, name,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            var splitPos = 20;
            while (splitPos > 0 && !(name.substring(splitPos, splitPos + 1).equals(" "))) {
                splitPos--;
            }
            var line1;
            var line2;
            if (splitPos == 0) {
                line1 = name.substring(0, 20);
                line2 = name.substring(20, name.length());
            } else {
                line1 = name.substring(0, splitPos);
                line2 = name.substring(splitPos + 1, name.length());
            }
            dc.drawText(CX, y + 18, Graphics.FONT_XTINY, line1,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(CX, y + 45, Graphics.FONT_XTINY, line2,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function _currentColor(currentMg as Float, limitMg as Number) as Number {
        var ratio = currentMg / limitMg.toFloat();
        if (ratio >= 1.0f) { return Graphics.COLOR_RED; }
        if (ratio >= 0.8f) { return Graphics.COLOR_ORANGE; }
        if (ratio >= 0.5f) { return Graphics.COLOR_YELLOW; }
        return Graphics.COLOR_GREEN;
    }

    // Called by delegate when settings may have changed
    function refreshSettings(settings as Dictionary) as Void {
        _settings = settings;
    }

    // Returns the tap region for the Oops button — [x1, y1, x2, y2]
    function oopsButtonRegion() as Array<Number> {
        return [206, 20, 248, 70] as Array<Number>;
    }

    // Expose pending dose state so delegate can react without re-loading storage
    function hasPendingDose() as Boolean {
        return StimTrackerStorage.loadPendingDose() != null;
    }
}

// ── Main Screen Delegate ─────────────────────────────────────────────────────

class MainDelegate extends WatchUi.BehaviorDelegate {

    private var _view   as MainView;
    private var _settings as Dictionary;

    function initialize(view as MainView, settings as Dictionary) {
        BehaviorDelegate.initialize();
        _view     = view;
        _settings = settings;
    }

    // Swipe UP → Log Stimulant screen
    function onNextPage() as Boolean {
        var profiles = StimTrackerStorage.loadProfiles();
        var logView  = new LogStimulantView(profiles, _settings);
        WatchUi.pushView(
            logView,
            new LogStimulantDelegate(logView, profiles, _settings),
            WatchUi.SLIDE_UP
        );
        return true;
    }

    // Swipe DOWN → History screen
    function onPreviousPage() as Boolean {
        var days     = StimTrackerStorage.loadDayIndex();
        var histView = new HistoryView(days);
        WatchUi.pushView(
            histView,
            new HistoryDelegate(histView),
            WatchUi.SLIDE_DOWN
        );
        return true;
    }

    // Menu button → Settings
    function onMenu() as Boolean {
        var settingsView = new SettingsView(_settings);
        WatchUi.pushView(
            settingsView,
            new SettingsDelegate(settingsView, _settings, _view),
            WatchUi.SLIDE_LEFT
        );
        return true;
    }

    // Tap: check Oops button or Finish Recording button
    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var tapX   = coords[0];
        var tapY   = coords[1];

        // Oops button (top-centre heart)
        var oopsRegion = _view.oopsButtonRegion();
        if (tapX >= oopsRegion[0] && tapX <= oopsRegion[2] &&
            tapY >= oopsRegion[1] && tapY <= oopsRegion[3]) {
            var oopsView = new OopsView(_settings);
            WatchUi.pushView(
                oopsView,
                new OopsDelegate(oopsView, _settings),
                WatchUi.SLIDE_UP
            );
            return true;
        }

        // Finish Recording button (bottom bar, only active while recording)
        if (_view.hasPendingDose()) {
            var finishRegion = _view.finishButtonRegion();
            if (tapX >= finishRegion[0] && tapX <= finishRegion[2] &&
                tapY >= finishRegion[1] && tapY <= finishRegion[3]) {
                StimTrackerStorage.finishPendingDose(Time.now().value().toNumber());
                WatchUi.requestUpdate();
                return true;
            }
        }

        return false;
    }
}
