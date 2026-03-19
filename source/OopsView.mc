// OopsView.mc
// Records a snapshot of current caffeine-in-system as the personal warning threshold.

import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

class OopsView extends WatchUi.View {

    private const CX = 227;
    var _settings    as Dictionary;
    var _snapshotMg  as Float;

    function initialize(settings as Dictionary) {
        View.initialize();
        _settings   = settings;
        _snapshotMg = StimTrackerStorage.calcCurrentMg(settings);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();

        // Header
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 28, Graphics.FONT_XTINY, "Oops!",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Subtitle (word-wrapped)
        dc.drawText(CX, 52, Graphics.FONT_XTINY, "I took too much",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(CX, 79, Graphics.FONT_XTINY, "and feel bad",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Label
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 116, Graphics.FONT_XTINY, "Caffeine in system now:",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Snapshot value — FONT_NUMBER_MILD for legibility
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 170, Graphics.FONT_NUMBER_MILD,
            _snapshotMg.toNumber().toString() + "mg",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Existing threshold if set
        var existingMg = _settings["oopsThresholdMg"];
        if (existingMg != null) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(CX, 228, Graphics.FONT_XTINY,
                "Current Threshold: " + (existingMg as Float).toNumber().toString() + "mg",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Prompt
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 264, Graphics.FONT_XTINY, "Set this as your",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(CX, 291, Graphics.FONT_XTINY, "warning threshold?",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Set Threshold button
        dc.setColor(0x880000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(107, 315, 240, 55, 10);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 342, Graphics.FONT_XTINY, "Set Threshold",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Cancel bar (standard pattern)
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 380, w, 23);
        ArrowUtils.drawDownArrow(dc, CX - 30, 391, ArrowUtils.HINT_ARROW_SIZE,
            Graphics.COLOR_LT_GRAY);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX - 14, 391, Graphics.FONT_XTINY, "Cancel",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function isConfirmTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 107 && tapX <= 347 && tapY >= 315 && tapY <= 370;
    }
}

class OopsDelegate extends WatchUi.BehaviorDelegate {

    private var _view     as OopsView;
    private var _settings as Dictionary;

    function initialize(view as OopsView, settings as Dictionary) {
        BehaviorDelegate.initialize();
        _view     = view;
        _settings = settings;
    }

    function onPreviousPage() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        if (_view.isConfirmTap(coords[0], coords[1])) {
            _settings["oopsThresholdMg"] = _view._snapshotMg;
            StimTrackerStorage.saveSettings(_settings);
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return true;
        }
        return false;
    }
}
