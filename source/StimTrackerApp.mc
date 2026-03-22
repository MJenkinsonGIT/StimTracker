// StimTrackerApp.mc
// App entry point and glance view.
// Glance annotation pattern per skin_temp_widget_development_lessons.md §21:
//   - Annotate getGlanceView() function only
//   - Annotate GlanceView class
//   - NEVER annotate the AppBase class itself

import Toybox.Application;
import Toybox.Background;
import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

(:background)
class StimTrackerApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        // Guard expensive work — onStart() is called every 30s in glance mode
        // on non-live-update devices. Only run full init in the real app.
        var s = System.getDeviceSettings();
        if ((s has :isGlanceModeEnabled) && s.isGlanceModeEnabled) {
            return;
        }
        // Pre-load settings (initialises defaults on first run)
        StimTrackerStorage.loadSettings();
        // Push fresh complication data immediately when the app opens
        _pushComplication();
        // Ensure a background temporal event is scheduled for periodic updates
        _scheduleBackground();
    }

    // Wire up the background service delegate so the system can launch it
    // periodically to push complication updates without the app being open.
    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new StimTrackerServiceDelegate()];
    }

    // Push current caffeine-in-system to the complication from the foreground.
    // Called on app open so Face It has a fresh value immediately.
    private function _pushComplication() as Void {
        var settings  = StimTrackerStorage.loadSettings();
        var currentMg = StimTrackerStorage.calcCurrentMg(settings);
        try {
            Complications.updateComplication(0, {
                :value => currentMg.toNumber(),
                :unit  => "mg"
            } as Complications.Data);
        } catch (e) {
            // Complication not subscribed — ignore.
        }
    }

    // Register a temporal background event to fire 5 minutes from the last
    // event (or immediately if none has run yet). The service delegate will
    // reschedule itself on each firing.
    private function _scheduleBackground() as Void {
        var fiveMin  = new Time.Duration(5 * 60);
        var lastTime = Background.getLastTemporalEventTime();
        var nextTime;
        if (lastTime != null) {
            nextTime = lastTime.add(fiveMin);
        } else {
            nextTime = Time.now();
        }
        try {
            Background.registerForTemporalEvent(nextTime);
        } catch (e instanceof Background.InvalidBackgroundTimeException) {
            // Ran too recently — schedule 5 min from now.
            try {
                Background.registerForTemporalEvent(Time.now().add(fiveMin));
            } catch (e2) { }
        }
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var settings = StimTrackerStorage.loadSettings();
        var view     = new MainView(settings);
        var delegate = new MainDelegate(view, settings);
        return [view, delegate];
    }

    (:glance)
    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new StimGlanceView()];
    }
}

// ── Glance View ─────────────────────────────────────────────────────────────

(:glance)
class StimGlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // ── Textured gradient background (copied from SkinTempGlanceView) ──────────
        var fillPeak = 29;
        var fillEnd  = (w * 68) / 100;
        var stripW   = 8;
        var stripIdx = 0;
        var x = 0;
        while (x < fillEnd) {
            var dist      = fillEnd - x;
            var stripBase = (fillPeak * dist) / fillEnd;
            if (stripBase <= 0) { x = x + stripW; stripIdx++; continue; }
            var baseCol = (stripBase << 16) | (stripBase << 8) | stripBase;
            dc.setColor(baseCol, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, 0, stripW, h);
            x = x + stripW;
            stripIdx++;
        }

        // ── Border lines ─────────────────────────────────────────────────
        var borderEnd    = (w * 72) / 100;
        var borderStripW = 2;
        x = 0;
        while (x < borderEnd) {
            var bdist = borderEnd - x;
            var tlR = (106 * bdist) / borderEnd;
            var tlG = (105 * bdist) / borderEnd;
            var tlB = (106 * bdist) / borderEnd;
            var tdR = (49  * bdist) / borderEnd;
            var tdG = (48  * bdist) / borderEnd;
            var tdB = (49  * bdist) / borderEnd;
            var blR = (98  * bdist) / borderEnd;
            var blG = (105 * bdist) / borderEnd;
            var blB = (106 * bdist) / borderEnd;
            if (tlR <= 0 && tlG <= 0 && tlB <= 0) { break; }
            var colTL = (tlR << 16) | (tlG << 8) | tlB;
            var colTD = (tdR << 16) | (tdG << 8) | tdB;
            var colBL = (blR << 16) | (blG << 8) | blB;
            dc.setColor(colTL, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, 4, borderStripW, 1);
            dc.fillRectangle(x, 5, borderStripW, 1);
            dc.setColor(colTD, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, 6, borderStripW, 1);
            dc.setColor(colTD, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, h - 8, borderStripW, 1);
            dc.setColor(colBL, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, h - 7, borderStripW, 1);
            dc.fillRectangle(x, h - 6, borderStripW, 1);
            x = x + borderStripW;
        }

        // ── Black masks ─────────────────────────────────────────────────
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0,   w, 4);
        dc.fillRectangle(0, 159, w, 5);

        // ── Data ───────────────────────────────────────────────────────
        var settings = Application.Storage.getValue("settings") as Dictionary?;
        if (settings == null) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(8, h / 2, Graphics.FONT_TINY, "Open app first",
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var limitMg          = settings["limitMg"] as Number;
        var halfLife         = settings["halfLifeHrs"] as Float;
        var absorptionModel  = settings.hasKey("absorptionModel")   ? settings["absorptionModel"]   as Number : 0;
        var stdFoodState     = settings.hasKey("standardFoodState") ? settings["standardFoodState"] as Number : 1;
        var glanceKe         = Math.log(2.0, Math.E).toFloat() / halfLife;

        var todayKey     = _glanceTodayKey();
        var yesterdayKey = _glanceYesterdayKey();
        var totalMg   = 0;
        var currentMg = 0.0f;
        var nowSec    = Time.now().value().toNumber();

        // Read today + yesterday so carry-over doses are included in decay
        var ln2     = Math.log(2.0, Math.E).toFloat();
        var dayKeys = [todayKey, yesterdayKey];
        for (var d = 0; d < 2; d++) {
            var events = Application.Storage.getValue("log_" + dayKeys[d]) as Array?;
            if (events == null) { continue; }
            for (var i = 0; i < (events as Array).size(); i++) {
                var evt    = (events as Array)[i] as Dictionary;
                var caffMg = evt["caffeineMg"] as Number;
                if (d == 0) { totalMg += caffMg; }

                var startSec;
                var finishSec;
                if (evt.hasKey("startSec")) {
                    startSec  = evt["startSec"]  as Number;
                    finishSec = evt["finishSec"] as Number;
                } else if (evt.hasKey("timestampSec")) {
                    startSec  = evt["timestampSec"] as Number;
                    finishSec = startSec;
                } else {
                    continue;
                }

                var elapsedStartHrs = (nowSec - startSec).toFloat() / 3600.0f;
                if (elapsedStartHrs < 0.0f || elapsedStartHrs >= halfLife * 7.0f) { continue; }

                var remaining;
                if (absorptionModel == 0) {
                    // Instant model (original logic)
                    if (finishSec <= startSec) {
                        remaining = caffMg.toFloat() * Math.pow(0.5, elapsedStartHrs / halfLife).toFloat();
                    } else {
                        var durHrs = (finishSec - startSec).toFloat() / 3600.0f;
                        var coeff  = caffMg.toFloat() / durHrs * (halfLife / ln2);
                        if (nowSec < finishSec) {
                            remaining = coeff * (1.0f - Math.pow(0.5, elapsedStartHrs / halfLife).toFloat());
                        } else {
                            var elapsedFinishHrs = (nowSec - finishSec).toFloat() / 3600.0f;
                            remaining = coeff * (Math.pow(0.5, elapsedFinishHrs / halfLife).toFloat()
                                               - Math.pow(0.5, elapsedStartHrs / halfLife).toFloat());
                        }
                        if (remaining < 0.0f) { remaining = 0.0f; }
                    }
                } else {
                    // Full one-compartment PK model (matches calcAbsorbedMg)
                    var dType = evt.hasKey("type")      ? evt["type"]      as String : "drink";
                    var fs    = (absorptionModel == 2 && evt.hasKey("foodState"))
                                ? evt["foodState"] as Number : stdFoodState;
                    var ka;
                    if (dType.equals("drink")) {
                        ka = (fs == 0) ? 3.5f : ((fs == 2) ? 2.0f : 2.75f);
                    } else {
                        ka = (fs == 0) ? 1.75f : ((fs == 2) ? 1.0f : 1.375f);
                    }
                    var diff = ka - glanceKe;
                    if (diff < 0.0f) { diff = -diff; }
                    if (diff < 0.001f) {
                        remaining = caffMg.toFloat() * Math.pow(0.5, elapsedStartHrs * glanceKe / ln2).toFloat();
                    } else {
                        var windowHrs = (finishSec - startSec).toFloat() / 3600.0f;
                        if (windowHrs < 0.0f || dType.equals("pill")) { windowHrs = 0.0f; }
                        if (windowHrs <= 0.0f) {
                            // Bolus path
                            var ke_d = Math.pow(0.5, elapsedStartHrs * glanceKe / ln2).toFloat();
                            var ka_d = Math.pow(0.5, elapsedStartHrs * ka       / ln2).toFloat();
                            remaining = caffMg.toFloat() * (ka / (ka - glanceKe)) * (ke_d - ka_d);
                            if (remaining < 0.0f) { remaining = 0.0f; }
                        } else {
                            // Window path — piecewise zero-order input
                            var R = caffMg.toFloat() / windowHrs;
                            var T = windowHrs;
                            if (elapsedStartHrs <= T) {
                                var ke_d = Math.pow(0.5, elapsedStartHrs * glanceKe / ln2).toFloat();
                                var ka_d = Math.pow(0.5, elapsedStartHrs * ka       / ln2).toFloat();
                                remaining = (R / glanceKe) * (1.0f - ke_d)
                                          - R / (ka - glanceKe) * (ke_d - ka_d);
                                if (remaining < 0.0f) { remaining = 0.0f; }
                            } else {
                                var ke_T    = Math.pow(0.5, T * glanceKe / ln2).toFloat();
                                var ka_T    = Math.pow(0.5, T * ka       / ln2).toFloat();
                                var A_gut_T = (R / ka) * (1.0f - ka_T);
                                var A_bdy_T = (R / glanceKe) * (1.0f - ke_T)
                                            - R / (ka - glanceKe) * (ke_T - ka_T);
                                if (A_bdy_T < 0.0f) { A_bdy_T = 0.0f; }
                                var dt    = elapsedStartHrs - T;
                                var ke_dt = Math.pow(0.5, dt * glanceKe / ln2).toFloat();
                                var ka_dt = Math.pow(0.5, dt * ka       / ln2).toFloat();
                                remaining = A_bdy_T * ke_dt + A_gut_T * (ka / (ka - glanceKe)) * (ke_dt - ka_dt);
                                if (remaining < 0.0f) { remaining = 0.0f; }
                            }
                        }
                    }
                }
                currentMg += remaining;
            }
        }

        var pct   = limitMg > 0 ? (totalMg * 100 / limitMg) : 0;
        var textX = 8;

        // Line 1: percentage, colour-coded
        var pctColor = Graphics.COLOR_GREEN;
        if (pct >= 80) { pctColor = Graphics.COLOR_RED; }
        else if (pct >= 50) { pctColor = Graphics.COLOR_ORANGE; }
        dc.setColor(pctColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(textX, h / 5, Graphics.FONT_TINY,
            pct.toString() + "%",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Line 2: total / limit
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(textX, h / 2, Graphics.FONT_SMALL,
            totalMg.toString() + "/" + limitMg.toString() + "mg",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Line 3: current in system
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(textX, h * 4 / 5, Graphics.FONT_TINY,
            "Now: " + currentMg.toNumber().toString() + "mg",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Minimal inline date keys — avoids pulling in StimTrackerStorage
    private function _glanceTodayKey() as String {
        var info = Toybox.Time.Gregorian.info(Toybox.Time.now(), Toybox.Time.FORMAT_SHORT);
        var y = info.year.toString();
        var m = info.month < 10 ? "0" + info.month.toString() : info.month.toString();
        var d = info.day   < 10 ? "0" + info.day.toString()   : info.day.toString();
        return y + m + d;
    }

    private function _glanceYesterdayKey() as String {
        var yesterday = Toybox.Time.now().subtract(new Toybox.Time.Duration(86400));
        var info = Toybox.Time.Gregorian.info(yesterday, Toybox.Time.FORMAT_SHORT);
        var y = info.year.toString();
        var m = info.month < 10 ? "0" + info.month.toString() : info.month.toString();
        var d = info.day   < 10 ? "0" + info.day.toString()   : info.day.toString();
        return y + m + d;
    }
}

// ── App factory ─────────────────────────────────────────────────────────────

function getApp() as StimTrackerApp {
    return Application.getApp() as StimTrackerApp;
}
