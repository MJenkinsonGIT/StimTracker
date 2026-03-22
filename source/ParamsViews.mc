// ParamsViews.mc
// Per-dose and per-profile parameter screens, reached via the gear icon.
//
// Screen hierarchy:
//   DoseEditView      → gear → DoseParamsView    (Dose Form + Food State — tap to cycle)
//   EditStimulantView → gear → ProfileParamsView (Dose Form — tap to cycle)
//   MiscCaffeineView  → gear → MiscParamsView    (Dose Form + Food State — tap to cycle)
//
// All rows cycle their value in-place on tap; no sub-screens.

import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

// ── Dose Params View (reached from DoseEditView gear icon) ────────────────────
// Shows: Dose Form row + Food State row.
// Rows are greyed + non-tappable when mode is insufficient.
//
// Public members _type and _foodState are read by DoseEditDelegate at Save time.

class DoseParamsView extends WatchUi.View {

    private const CX       = 227;
    private const ROW_H    = 58;
    private const LIST_TOP = 65;

    var _type      as String;  // public: "drink" | "pill"
    var _foodState as Number;  // public: 0=Fasted, 1=Typical, 2=WithFood
    private var _settings as Dictionary;

    function initialize(doseType as String, foodState as Number,
                        settings as Dictionary) {
        View.initialize();
        _type      = doseType;
        _foodState = foodState;
        _settings  = settings;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 35, Graphics.FONT_XTINY, "Parameters",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var model = _settings.hasKey("absorptionModel")
            ? _settings["absorptionModel"] as Number : 0;

        var typeStr = _type.equals("drink") ? "Drink" : "Pill";
        var fsStr   = _foodState == 0 ? "Fasted"
                    : _foodState == 2 ? "With Food"
                    : "Typical";

        _drawRow(dc, 0, "Dose Form",  typeStr, model != 0);
        _drawRow(dc, 1, "Food State", fsStr,   model == 2);
    }

    private function _drawRow(dc as Graphics.Dc, idx as Number,
                               label as String, value as String,
                               active as Boolean) as Void {
        var y = LIST_TOP + idx * ROW_H;
        dc.setColor(active ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_DK_GRAY,
            Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, y + 13, Graphics.FONT_XTINY, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(active ? Graphics.COLOR_WHITE : Graphics.COLOR_DK_GRAY,
            Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, y + 38, Graphics.FONT_XTINY, value,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(40, y + ROW_H - 1, 414, y + ROW_H - 1);
    }

    function rowForTapY(tapY as Number) as Number {
        if (tapY < LIST_TOP) { return -1; }
        var row = (tapY - LIST_TOP) / ROW_H;
        if (row >= 2) { return -1; }
        return row;
    }
}

class DoseParamsDelegate extends WatchUi.BehaviorDelegate {

    private var _view     as DoseParamsView;
    private var _settings as Dictionary;

    function initialize(view as DoseParamsView, settings as Dictionary) {
        BehaviorDelegate.initialize();
        _view     = view;
        _settings = settings;
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
        var tapY  = evt.getCoordinates()[1];
        var row   = _view.rowForTapY(tapY);
        if (row < 0) { return false; }
        var model = _settings.hasKey("absorptionModel")
            ? _settings["absorptionModel"] as Number : 0;
        if (row == 0 && model != 0) {
            _view._type = _view._type.equals("drink") ? "pill" : "drink";
            WatchUi.requestUpdate();
        } else if (row == 1 && model == 2) {
            _view._foodState = (_view._foodState + 1) % 3;
            WatchUi.requestUpdate();
        }
        return true;
    }
}

// ── Profile Params View (reached from EditStimulantView / ProfileEditView gear) ──
// Shows: Dose Form row only (Food State is not a per-profile setting).

class ProfileParamsView extends WatchUi.View {

    private const CX       = 227;
    private const ROW_H    = 58;
    private const LIST_TOP = 65;

    var _type     as String;   // public: "drink" | "pill"
    private var _settings as Dictionary;

    function initialize(profileType as String, settings as Dictionary) {
        View.initialize();
        _type     = profileType;
        _settings = settings;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 35, Graphics.FONT_XTINY, "Parameters",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var active  = _settings.hasKey("absorptionModel")
            ? (_settings["absorptionModel"] as Number) != 0 : false;
        var typeStr = _type.equals("drink") ? "Drink" : "Pill";
        var y       = LIST_TOP;

        dc.setColor(active ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_DK_GRAY,
            Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, y + 13, Graphics.FONT_XTINY, "Dose Form",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(active ? Graphics.COLOR_WHITE : Graphics.COLOR_DK_GRAY,
            Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, y + 38, Graphics.FONT_XTINY, typeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(40, y + ROW_H - 1, 414, y + ROW_H - 1);
    }

    function isDoseFormTap(tapY as Number) as Boolean {
        return tapY >= LIST_TOP && tapY < LIST_TOP + ROW_H;
    }
}

class ProfileParamsDelegate extends WatchUi.BehaviorDelegate {

    private var _view     as ProfileParamsView;
    private var _settings as Dictionary;

    function initialize(view as ProfileParamsView, settings as Dictionary) {
        BehaviorDelegate.initialize();
        _view     = view;
        _settings = settings;
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
        var tapY  = evt.getCoordinates()[1];
        var model = _settings.hasKey("absorptionModel")
            ? _settings["absorptionModel"] as Number : 0;
        if (_view.isDoseFormTap(tapY) && model != 0) {
            _view._type = _view._type.equals("drink") ? "pill" : "drink";
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }
}

// ── Misc Params View (reached from MiscCaffeineView gear icon) ────────────────
// Structurally identical to DoseParamsView; separate class for clarity.

class MiscParamsView extends WatchUi.View {

    private const CX       = 227;
    private const ROW_H    = 58;
    private const LIST_TOP = 65;

    var _type      as String;  // public
    var _foodState as Number;  // public
    private var _settings as Dictionary;

    function initialize(miscType as String, foodState as Number,
                        settings as Dictionary) {
        View.initialize();
        _type      = miscType;
        _foodState = foodState;
        _settings  = settings;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 35, Graphics.FONT_XTINY, "Parameters",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var model = _settings.hasKey("absorptionModel")
            ? _settings["absorptionModel"] as Number : 0;

        var typeStr = _type.equals("drink") ? "Drink" : "Pill";
        var fsStr   = _foodState == 0 ? "Fasted"
                    : _foodState == 2 ? "With Food"
                    : "Typical";

        _drawRow(dc, 0, "Dose Form",  typeStr, model != 0);
        _drawRow(dc, 1, "Food State", fsStr,   model == 2);
    }

    private function _drawRow(dc as Graphics.Dc, idx as Number,
                               label as String, value as String,
                               active as Boolean) as Void {
        var y = LIST_TOP + idx * ROW_H;
        dc.setColor(active ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_DK_GRAY,
            Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, y + 13, Graphics.FONT_XTINY, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(active ? Graphics.COLOR_WHITE : Graphics.COLOR_DK_GRAY,
            Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, y + 38, Graphics.FONT_XTINY, value,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(40, y + ROW_H - 1, 414, y + ROW_H - 1);
    }

    function rowForTapY(tapY as Number) as Number {
        if (tapY < LIST_TOP) { return -1; }
        var row = (tapY - LIST_TOP) / ROW_H;
        if (row >= 2) { return -1; }
        return row;
    }
}

class MiscParamsDelegate extends WatchUi.BehaviorDelegate {

    private var _view     as MiscParamsView;
    private var _settings as Dictionary;

    function initialize(view as MiscParamsView, settings as Dictionary) {
        BehaviorDelegate.initialize();
        _view     = view;
        _settings = settings;
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
        var tapY  = evt.getCoordinates()[1];
        var row   = _view.rowForTapY(tapY);
        if (row < 0) { return false; }
        var model = _settings.hasKey("absorptionModel")
            ? _settings["absorptionModel"] as Number : 0;
        if (row == 0 && model != 0) {
            _view._type = _view._type.equals("drink") ? "pill" : "drink";
            WatchUi.requestUpdate();
        } else if (row == 1 && model == 2) {
            _view._foodState = (_view._foodState + 1) % 3;
            WatchUi.requestUpdate();
        }
        return true;
    }
}
