// StimTrackerBackground.mc
// Background service delegate for periodic complication updates.
//
// Fires every 5 minutes (the SDK minimum) via a temporal background event.
// Computes current caffeine in system and pushes it to the complication so
// Face It and other watch faces see fresh data without the main app being open.
//
// The PK calculation here is intentionally inlined rather than calling
// StimTrackerStorage — background code runs in a separate annotated context
// and cannot reference un-annotated foreground classes. This logic must be
// kept in sync with StimTrackerStorage.calcCurrentMg() by hand.
//
// Background memory limit: ~32 KB — keep this file lean.

import Toybox.Application;
import Toybox.Background;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

(:background)
class StimTrackerServiceDelegate extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    // Called by the system when the temporal background event fires.
    // No rescheduling needed — registered as a Duration so the OS repeats automatically.
    function onTemporalEvent() as Void {
        _pushComplication();
        Background.exit(null);
    }

    // ── Complication push ───────────────────────────────────────────────────

    private function _pushComplication() as Void {
        var nowSec      = Time.now().value().toNumber();
        var currentMg   = _calcMgAt(nowSec);
        var mg60        = _calcMgAt(nowSec + 60);
        var mg900       = _calcMgAt(nowSec + 900);
        var trendLevel  = 0;
        if (mg60 > currentMg + 0.01f) {
            trendLevel = (mg900 > currentMg) ? 2 : 1;
        } else if (mg60 < currentMg - 0.01f) {
            trendLevel = ((currentMg - mg900) > 3.0f) ? -2 : -1;
        }
        var trendPrefix = trendLevel ==  2 ? "^^" : trendLevel ==  1 ? "^" :
                          trendLevel == -2 ? "vv" : trendLevel == -1 ? "v" : "";
        try {
            Complications.updateComplication(0, {
                :value => trendPrefix + currentMg.toNumber().toString() + "mg"
            } as Complications.Data);
        } catch (e) {
            // Complication not subscribed or unavailable — ignore silently.
        }
    }

    // ── Inline PK calculation ───────────────────────────────────────────────
    //
    // Mirrors StimTrackerStorage.calcCurrentMg() exactly, including all three
    // absorption modes and the corrected window formula (R/(ka-ke), not
    // R*ka/(ke*(ka-ke))). Update both locations if the formula changes.

    private function _calcMgAt(asOfSec as Number) as Float {
        var stored = Application.Storage.getValue("settings");
        if (stored == null) { return 0.0f; }
        var s = stored as Dictionary;

        var halfLifeHrs       = s["halfLifeHrs"] as Float;
        var absorptionModel   = s.hasKey("absorptionModel")   ? s["absorptionModel"]   as Number : 0;
        var standardFoodState = s.hasKey("standardFoodState") ? s["standardFoodState"] as Number : 1;
        var ln2               = Math.log(2.0, Math.E).toFloat();
        var ke                = ln2 / halfLifeHrs;
        var total             = 0.0f;

        var dayKeys = [_todayKey(), _yesterdayKey()];
        for (var d = 0; d < 2; d++) {
            var events = Application.Storage.getValue("log_" + (dayKeys[d] as String)) as Array?;
            if (events == null) { continue; }
            for (var i = 0; i < (events as Array).size(); i++) {
                var evt    = (events as Array)[i] as Dictionary;
                var caffMg = (evt["caffeineMg"] as Number).toFloat();

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

                var elapsedStartHrs = (asOfSec - startSec).toFloat() / 3600.0f;
                if (elapsedStartHrs < 0.0f || elapsedStartHrs >= halfLifeHrs * 7.0f) { continue; }

                var remaining;
                if (absorptionModel == 0) {
                    // ── Instant model ──────────────────────────────────────
                    if (finishSec <= startSec) {
                        remaining = caffMg * Math.pow(0.5, elapsedStartHrs / halfLifeHrs).toFloat();
                    } else {
                        var durHrs = (finishSec - startSec).toFloat() / 3600.0f;
                        var coeff  = caffMg / durHrs * (halfLifeHrs / ln2);
                        if (asOfSec < finishSec) {
                            remaining = coeff * (1.0f - Math.pow(0.5, elapsedStartHrs / halfLifeHrs).toFloat());
                        } else {
                            var elapsedFinishHrs = (asOfSec - finishSec).toFloat() / 3600.0f;
                            remaining = coeff * (Math.pow(0.5, elapsedFinishHrs / halfLifeHrs).toFloat()
                                               - Math.pow(0.5, elapsedStartHrs / halfLifeHrs).toFloat());
                        }
                        if (remaining < 0.0f) { remaining = 0.0f; }
                    }
                } else {
                    // ── PK absorption model (Standard or Precision) ────────
                    var dType = evt.hasKey("type") ? evt["type"] as String : "drink";
                    var fs    = (absorptionModel == 2 && evt.hasKey("foodState"))
                                ? evt["foodState"] as Number : standardFoodState;

                    var ka;
                    if (dType.equals("drink")) {
                        ka = (fs == 0) ? 3.5f : ((fs == 2) ? 2.0f : 2.75f);
                    } else {
                        ka = (fs == 0) ? 1.75f : ((fs == 2) ? 1.0f : 1.375f);
                    }

                    var diff = ka - ke;
                    if (diff < 0.0f) { diff = -diff; }
                    if (diff < 0.001f) {
                        // ka ≈ ke guard: fall back to simple decay
                        remaining = caffMg * Math.pow(0.5, elapsedStartHrs * ke / ln2).toFloat();
                    } else {
                        var windowHrs = (finishSec - startSec).toFloat() / 3600.0f;
                        if (windowHrs < 0.0f || dType.equals("pill")) { windowHrs = 0.0f; }

                        if (windowHrs <= 0.0f) {
                            // Bolus path
                            var ke_d = Math.pow(0.5, elapsedStartHrs * ke / ln2).toFloat();
                            var ka_d = Math.pow(0.5, elapsedStartHrs * ka / ln2).toFloat();
                            remaining = caffMg * (ka / (ka - ke)) * (ke_d - ka_d);
                            if (remaining < 0.0f) { remaining = 0.0f; }
                        } else {
                            // Piecewise zero-order input model
                            var R = caffMg / windowHrs;
                            var T = windowHrs;
                            if (elapsedStartHrs <= T) {
                                // During drinking phase
                                var ke_d = Math.pow(0.5, elapsedStartHrs * ke / ln2).toFloat();
                                var ka_d = Math.pow(0.5, elapsedStartHrs * ka / ln2).toFloat();
                                remaining = (R / ke) * (1.0f - ke_d)
                                          - R / (ka - ke) * (ke_d - ka_d);
                                if (remaining < 0.0f) { remaining = 0.0f; }
                            } else {
                                // After drinking — propagate state at T
                                var ke_T    = Math.pow(0.5, T * ke / ln2).toFloat();
                                var ka_T    = Math.pow(0.5, T * ka / ln2).toFloat();
                                var A_gut_T = (R / ka) * (1.0f - ka_T);
                                var A_bdy_T = (R / ke) * (1.0f - ke_T)
                                            - R / (ka - ke) * (ke_T - ka_T);
                                if (A_bdy_T < 0.0f) { A_bdy_T = 0.0f; }
                                var dt    = elapsedStartHrs - T;
                                var ke_dt = Math.pow(0.5, dt * ke / ln2).toFloat();
                                var ka_dt = Math.pow(0.5, dt * ka / ln2).toFloat();
                                remaining = A_bdy_T * ke_dt
                                          + A_gut_T * (ka / (ka - ke)) * (ke_dt - ka_dt);
                                if (remaining < 0.0f) { remaining = 0.0f; }
                            }
                        }
                    }
                }
                total += remaining;
            }
        }
        return total;
    }

    // ── Date key helpers (duplicated from StimTrackerStorage for background context) ──

    private function _todayKey() as String {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var y = info.year.toString();
        var m = info.month < 10 ? "0" + info.month.toString() : info.month.toString();
        var d = info.day   < 10 ? "0" + info.day.toString()   : info.day.toString();
        return y + m + d;
    }

    private function _yesterdayKey() as String {
        var yesterday = Time.now().subtract(new Time.Duration(86400));
        var info = Gregorian.info(yesterday, Time.FORMAT_SHORT);
        var y = info.year.toString();
        var m = info.month < 10 ? "0" + info.month.toString() : info.month.toString();
        var d = info.day   < 10 ? "0" + info.day.toString()   : info.day.toString();
        return y + m + d;
    }
}
