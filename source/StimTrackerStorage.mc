// StimTrackerStorage.mc
// Handles all Application.Storage reads and writes.
// No permission required for Application.Storage.
//
// Storage keys:
//   "settings"      -> Dictionary with user preferences
//   "profiles"      -> Array of stimulant profile Dictionaries
//   "log_YYYYMMDD"  -> Array of dose event Dictionaries for that day
//   "log_days"      -> Array of date strings (for enumeration and pruning)
//   "pending_dose"  -> Dictionary for a dose in progress (Record pressed, Finish not yet)

import Toybox.Application;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.UserProfile;

class StimTrackerStorage {

    // ── Constants ──────────────────────────────────────────────────────────

    static const MAX_HISTORY_DAYS = 30;

    // Recording-mode sleep cache (in-memory, 60-second TTL)
    // Avoids re-running the full bisection every frame during active recording.
    static var _recSleepCacheSec = 0;
    static var _recSleepCacheVal = 0;

    // Default stimulant profiles (Phase 1 — caffeine only)
    // Each profile: { "id" => Number, "name" => String, "caffeineMg" => Number }
    static const DEFAULT_PROFILES = [
        { "id" => 1, "name" => "Reign Red Dragon",          "caffeineMg" => 300, "type" => "drink" },
        { "id" => 2, "name" => "G Fuel Blue Ice",           "caffeineMg" => 150, "type" => "drink" },
        { "id" => 3, "name" => "GV Energy Cherry Slush",    "caffeineMg" => 120, "type" => "drink" },
        { "id" => 4, "name" => "Nutricost Caff+Theanine",   "caffeineMg" => 200, "type" => "pill"  },
        { "id" => 5, "name" => "Nutricost Energy Complex",  "caffeineMg" => 100, "type" => "pill"  },
        { "id" => 6, "name" => "Nutricost Clean Energy",    "caffeineMg" => 100, "type" => "drink" },
        { "id" => 7, "name" => "Nutricost Intra-Workout",   "caffeineMg" => 100, "type" => "drink" },
        { "id" => 8, "name" => "GV Peach Mango GT",         "caffeineMg" => 55,  "type" => "drink" },
        { "id" => 9, "name" => "CL Peach Mango GT",         "caffeineMg" => 15,  "type" => "drink" }
    ] as Array<Dictionary>;

    // ── Settings ───────────────────────────────────────────────────────────

    // Returns the settings dictionary, initialising defaults on first run.
    // Settings keys:
    //   "limitMg"           -> Number  (daily caffeine limit in mg)
    //   "halfLifeHrs"       -> Float   (caffeine half-life in hours, default 5.0)
    //   "sleepThresholdMg"  -> Number  (mg in system = "safe to sleep", default 100)
    //   "bedtimeMinutes"    -> Number  (minutes since midnight for bedtime)
    //   "oopsThresholdMg"   -> Number or Null (mg in system at time of Oops event)
    //   "nextProfileId"     -> Number  (auto-increment ID for new profiles)
    //   "absorptionModel"   -> Number  (0=Instant, 1=Standard, 2=Precision)
    //   "standardFoodState" -> Number  (0=Fasted, 1=Typical, 2=WithFood)
    static function loadSettings() as Dictionary {
        var stored = Application.Storage.getValue("settings");
        if (stored != null) {
            var s = stored as Dictionary;
            // Migrate: add keys introduced after initial release
            var changed = false;
            if (!s.hasKey("drinkTimeEstimateMin")) {
                s["drinkTimeEstimateMin"] = 30;
                changed = true;
            }
            if (changed) { saveSettings(s); }
            return s;
        }
        // First run — build defaults
        var defaults = buildDefaultSettings();
        Application.Storage.setValue("settings", defaults);
        return defaults;
    }

    static function saveSettings(settings as Dictionary) as Void {
        Application.Storage.setValue("settings", settings);
        refreshSleepCache();
    }

    static function buildDefaultSettings() as Dictionary {
        var limitMg = 400;  // fallback if UserProfile unavailable

        // Try to read weight from Garmin profile for personalised limit
        // UserProfile.getProfile() returns Profile; weight field is in grams
        var profile = UserProfile.getProfile();
        if (profile != null) {
            var weightG = profile.weight;
            if (weightG != null && weightG > 0) {
                var weightKg = weightG / 1000.0f;
                // EFSA: 5.7 mg/kg/day, rounded to nearest 10mg
                var calculated = (weightKg * 5.7f + 5.0f).toNumber() / 10 * 10;
                if (calculated > 0) {
                    limitMg = calculated;
                }
            }
        }

        // Try to pre-populate bedtime from Garmin sleep schedule
        var bedtimeMinutes = 22 * 60;  // fallback: 10:00 PM
        if (profile != null) {
            var sleepTime = profile.sleepTime;
            if (sleepTime != null) {
                // sleepTime is a Duration since local midnight
                bedtimeMinutes = (sleepTime.value() / 60).toNumber();
            }
        }

        return {
            "limitMg"           => limitMg,
            "halfLifeHrs"       => 5.0f,
            "sleepThresholdMg"  => 100,
            "bedtimeMinutes"    => bedtimeMinutes,
            "oopsThresholdMg"   => null,
            "nextProfileId"     => 10,  // first user-created profile gets ID 10
            "absorptionModel"      => 0,   // 0=Instant, 1=Standard, 2=Precision
            "standardFoodState"   => 1,   // 0=Fasted, 1=Typical, 2=WithFood (Standard sub-setting)
            "drinkTimeEstimateMin" => 30  // Assumed drink window when finish time is unknown
        } as Dictionary;
    }

    // ── Stimulant Profiles ─────────────────────────────────────────────────

    static function loadProfiles() as Array<Dictionary> {
        var stored = Application.Storage.getValue("profiles");
        if (stored != null) {
            return stored as Array<Dictionary>;
        }
        // First run — write defaults
        Application.Storage.setValue("profiles", DEFAULT_PROFILES);
        return DEFAULT_PROFILES;
    }

    static function saveProfiles(profiles as Array<Dictionary>) as Void {
        Application.Storage.setValue("profiles", profiles);
    }

    // Add a new profile. Returns the updated profiles array.
    static function addProfile(name as String, caffeineMg as Number,
                                 doseType as String, settings as Dictionary) as Array<Dictionary> {
        var profiles = loadProfiles();
        var nextId = settings["nextProfileId"] as Number;
        profiles.add({ "id" => nextId, "name" => name, "caffeineMg" => caffeineMg, "type" => doseType });
        saveProfiles(profiles);
        settings["nextProfileId"] = nextId + 1;
        saveSettings(settings);
        return profiles;
    }

    // Update an existing profile by id. Returns updated profiles array.
    static function updateProfile(id as Number, name as String, caffeineMg as Number,
                                    doseType as String) as Array<Dictionary> {
        var profiles = loadProfiles();
        for (var i = 0; i < profiles.size(); i++) {
            var p = profiles[i] as Dictionary;
            if ((p["id"] as Number) == id) {
                p["name"]       = name;
                p["caffeineMg"] = caffeineMg;
                p["type"]       = doseType;
                profiles[i]     = p;
                break;
            }
        }
        saveProfiles(profiles);
        return profiles;
    }

    // Move a profile from one array position to another.
    // fromIdx and toIdx are 0-based. The item ends up at toIdx in the
    // resulting array; all items in between shift by one to fill the gap.
    static function reorderProfile(fromIdx as Number, toIdx as Number) as Array<Dictionary> {
        var profiles = loadProfiles();
        if (fromIdx == toIdx || fromIdx < 0 || fromIdx >= profiles.size() ||
            toIdx < 0 || toIdx >= profiles.size()) {
            return profiles;
        }
        var item = profiles[fromIdx] as Dictionary;
        // Build array without the item at fromIdx
        var without = [] as Array<Dictionary>;
        for (var i = 0; i < profiles.size(); i++) {
            if (i != fromIdx) { without.add(profiles[i] as Dictionary); }
        }
        // Insert item at toIdx position in the new array
        var result = [] as Array<Dictionary>;
        for (var i = 0; i < without.size(); i++) {
            if (i == toIdx) { result.add(item); }
            result.add(without[i] as Dictionary);
        }
        if (toIdx >= without.size()) { result.add(item); }
        saveProfiles(result);
        return result;
    }

    // Delete a profile by id. Returns updated profiles array.
    static function deleteProfile(id as Number) as Array<Dictionary> {
        var profiles = loadProfiles();
        var updated = [] as Array<Dictionary>;
        for (var i = 0; i < profiles.size(); i++) {
            var p = profiles[i] as Dictionary;
            if ((p["id"] as Number) != id) {
                updated.add(p);
            }
        }
        saveProfiles(updated);
        return updated;
    }

    // ── Dose Log ───────────────────────────────────────────────────────────

    // Returns today's date string "YYYYMMDD" using local clock time
    static function todayKey() as String {
        var info  = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        // Build YYYYMMDD string — pad month/day with leading zero
        var y = info.year.toString();
        var m = info.month < 10 ? "0" + info.month.toString() : info.month.toString();
        var d = info.day   < 10 ? "0" + info.day.toString()   : info.day.toString();
        return y + m + d;
    }

    // Returns the storage key for a given date string
    static function logKey(dateStr as String) as String {
        return "log_" + dateStr;
    }

    // Load all dose events for a given date string.
    // Each event: { "profileId" => Number, "name" => String,
    //               "caffeineMg" => Number, "timestampSec" => Number,
    //               "type" => String, "foodState" => Number }
    static function loadDayLog(dateStr as String) as Array<Dictionary> {
        var stored = Application.Storage.getValue(logKey(dateStr));
        if (stored != null) {
            return stored as Array<Dictionary>;
        }
        return [] as Array<Dictionary>;
    }

    // Append an instant dose (backward-compatible wrapper).
    // Uses "drink" type and Typical food state as migration defaults.
    static function logDose(profileId as Number, name as String, caffeineMg as Number, timestampSec as Number) as Void {
        logDoseWithWindow(profileId, name, caffeineMg, timestampSec, timestampSec, "drink", 1);
    }

    // Append a dose with a consumption window to the appropriate day's log.
    // startSec and finishSec are seconds since epoch. When equal the dose is
    // treated as instant by calcCurrentMg. The event is stored under the day
    // of startSec so yesterday-evening starts are found by the yesterday loop.
    static function logDoseWithWindow(profileId as Number, name as String,
                                      caffeineMg as Number,
                                      startSec as Number, finishSec as Number,
                                      doseType as String, foodState as Number) as Void {
        // Derive date string from startSec
        var startMoment = new Time.Moment(startSec);
        var si = Gregorian.info(startMoment, Time.FORMAT_SHORT);
        var sy = si.year.toString();
        var sm = si.month < 10 ? "0" + si.month.toString() : si.month.toString();
        var sd = si.day   < 10 ? "0" + si.day.toString()   : si.day.toString();
        var dateStr = sy + sm + sd;

        var events = loadDayLog(dateStr);
        events.add({
            "profileId"    => profileId,
            "name"         => name,
            "caffeineMg"   => caffeineMg,
            "startSec"     => startSec,
            "finishSec"    => finishSec,
            "timestampSec" => startSec,   // kept for backward compat / history display
            "type"         => doseType,
            "foodState"    => foodState
        });
        Application.Storage.setValue(logKey(dateStr), events);
        _touchDayIndex(dateStr);
        pruneOldDays();
        refreshSleepCache();
    }

    // Load the list of days that have log entries
    static function loadDayIndex() as Array<String> {
        var stored = Application.Storage.getValue("log_days");
        if (stored != null) {
            return stored as Array<String>;
        }
        return [] as Array<String>;
    }

    // Ensure a date string exists in the day index
    static function _touchDayIndex(dateStr as String) as Void {
        var days = loadDayIndex();
        // Check if already present
        for (var i = 0; i < days.size(); i++) {
            if ((days[i] as String).equals(dateStr)) {
                return;
            }
        }
        days.add(dateStr);
        Application.Storage.setValue("log_days", days);
    }

    // Remove log entries older than MAX_HISTORY_DAYS
    static function pruneOldDays() as Void {
        var days = loadDayIndex();
        if (days.size() <= MAX_HISTORY_DAYS) {
            return;
        }
        // Sort ascending so oldest is first — simple bubble sort (small array)
        for (var i = 0; i < days.size() - 1; i++) {
            for (var j = 0; j < days.size() - 1 - i; j++) {
                if ((days[j] as String).compareTo(days[j + 1] as String) > 0) {
                    var tmp  = days[j];
                    days[j]  = days[j + 1];
                    days[j + 1] = tmp;
                }
            }
        }
        // Delete excess old days
        while (days.size() > MAX_HISTORY_DAYS) {
            var oldest = days[0] as String;
            Application.Storage.deleteValue(logKey(oldest));
            days.remove(days[0]);
        }
        Application.Storage.setValue("log_days", days);
    }

    // Update a single dose entry by index in a day's log.
    static function updateDose(dateStr as String, idx as Number,
                                name as String, caffeineMg as Number,
                                startSec as Number, finishSec as Number,
                                doseType as String, foodState as Number) as Void {
        var events = loadDayLog(dateStr);
        if (idx < 0 || idx >= events.size()) { return; }
        var evt = events[idx] as Dictionary;
        evt["name"]         = name;
        evt["caffeineMg"]   = caffeineMg;
        evt["startSec"]     = startSec;
        evt["finishSec"]    = finishSec;
        evt["timestampSec"] = startSec;  // keep in sync for backward compat
        evt["type"]         = doseType;
        evt["foodState"]    = foodState;
        events[idx] = evt;
        Application.Storage.setValue(logKey(dateStr), events);
        refreshSleepCache();
    }

    // Delete a single dose entry by index from a day's log.
    // If the day becomes empty, removes it from the day index.
    static function deleteDose(dateStr as String, idx as Number) as Void {
        var events = loadDayLog(dateStr);
        if (idx < 0 || idx >= events.size()) { return; }
        events.remove(events[idx]);
        if (events.size() == 0) {
            Application.Storage.deleteValue(logKey(dateStr));
            // Remove from day index
            var days    = loadDayIndex();
            var updated = [] as Array<String>;
            for (var i = 0; i < days.size(); i++) {
                if (!(days[i] as String).equals(dateStr)) {
                    updated.add(days[i] as String);
                }
            }
            Application.Storage.setValue("log_days", updated);
        } else {
            Application.Storage.setValue(logKey(dateStr), events);
        }
        refreshSleepCache();
    }

    // ── Pending Dose (Record / Finish live-recording flow) ────────────────

    // Save a dose that has started but not yet finished.
    static function savePendingDose(profileId as Number, name as String,
                                    caffeineMg as Number, startSec as Number,
                                    doseType as String, foodState as Number) as Void {
        Application.Storage.setValue("pending_dose", {
            "profileId"  => profileId,
            "name"       => name,
            "caffeineMg" => caffeineMg,
            "startSec"   => startSec,
            "type"       => doseType,
            "foodState"  => foodState
        } as Dictionary);
    }

    // Returns the pending dose dict, or null if none is in progress.
    static function loadPendingDose() as Dictionary? {
        var stored = Application.Storage.getValue("pending_dose");
        if (stored != null) {
            return stored as Dictionary;
        }
        return null;
    }

    // Complete the pending dose with a finish time, log it, then clear.
    static function finishPendingDose(finishSec as Number) as Void {
        var stored = Application.Storage.getValue("pending_dose");
        if (stored == null) { return; }
        var p = stored as Dictionary;
        var pType      = p.hasKey("type")      ? p["type"]      as String : "drink";
        var pFoodState = p.hasKey("foodState") ? p["foodState"] as Number : 1;
        logDoseWithWindow(
            p["profileId"]  as Number,
            p["name"]       as String,
            p["caffeineMg"] as Number,
            p["startSec"]   as Number,
            finishSec,
            pType, pFoodState
        );
        clearPendingDose();
        refreshSleepCache();  // pending dose is now cleared — cache can be computed correctly
    }

    // Discard any pending dose (e.g. user cancelled).
    static function clearPendingDose() as Void {
        Application.Storage.deleteValue("pending_dose");
    }

    // Delete all log entries for today (for Settings "Reset today" option)
    static function resetToday() as Void {
        var dateStr = todayKey();
        Application.Storage.deleteValue(logKey(dateStr));
        // Remove from index too
        var days    = loadDayIndex();
        var updated = [] as Array<String>;
        for (var i = 0; i < days.size(); i++) {
            if (!(days[i] as String).equals(dateStr)) {
                updated.add(days[i] as String);
            }
        }
        Application.Storage.setValue("log_days", updated);
        refreshSleepCache();
    }

    // ── Pharmacokinetics ───────────────────────────────────────────────────

    // Returns absorption rate constant ka (h⁻¹) for a given dose type and food state.
    // type:      "drink" | "pill"
    // foodState: 0=Fasted, 1=Typical (default), 2=WithFood
    // Migration: absent foodState field should be treated as 1 (Typical) by callers.
    static function getKa(type as String, foodState as Number) as Float {
        if (type.equals("drink")) {
            if (foodState == 0) { return 3.5f;   }  // fasted
            if (foodState == 2) { return 2.0f;   }  // with food
            return 2.75f;                            // typical (default)
        }
        // pill
        if (foodState == 0) { return 1.75f;  }
        if (foodState == 2) { return 1.0f;   }
        return 1.375f;                               // typical (default)
    }

    // One-compartment oral absorption model.
    // Returns estimated mg in system at tHours after dose start.
    //
    // doseMg      : dose size (mg)
    // ka          : absorption rate constant (h⁻¹), from getKa()
    // ke          : elimination rate constant (h⁻¹) = ln2 / halfLifeHrs
    // tHours      : elapsed time since dose start (hours)
    // windowHours : drinking duration (hours); 0 = bolus (instant ingestion)
    //
    // Pills always use the bolus path (windowHours is ignored for pills;
    // callers should pass 0 for pill doses).
    static function calcAbsorbedMg(doseMg as Float, ka as Float, ke as Float,
                                    tHours as Float, windowHours as Float) as Float {
        if (tHours <= 0.0f) { return 0.0f; }
        var ln2 = Math.log(2.0, Math.E).toFloat();

        // Guard: ka ≈ ke would cause divide-by-zero — fall back to simple decay
        var diff = ka - ke;
        if (diff < 0.0f) { diff = -diff; }
        if (diff < 0.001f) {
            return doseMg * Math.pow(0.5, tHours * ke / ln2).toFloat();
        }

        if (windowHours <= 0.0f) {
            // Bolus path: C(t) = D * ka/(ka-ke) * (e^(-ke*t) - e^(-ka*t))
            // Using 0.5-base: e^(-x*t) = 0.5^(x*t/ln2)
            var ke_d = Math.pow(0.5, tHours * ke / ln2).toFloat();
            var ka_d = Math.pow(0.5, tHours * ka / ln2).toFloat();
            var result = doseMg * (ka / (ka - ke)) * (ke_d - ka_d);
            if (result < 0.0f) { result = 0.0f; }
            return result;
        }

        // Piecewise zero-order input model (drink with window):
        // Zero-order input at rate R = D/T during [0, T]; first-order
        // absorption + elimination throughout; standard decay after T.
        var R = doseMg / windowHours;  // mg/h input rate
        var T = windowHours;

        if (tHours <= T) {
            // During drinking phase
            var ke_d = Math.pow(0.5, tHours * ke / ln2).toFloat();
            var ka_d = Math.pow(0.5, tHours * ka / ln2).toFloat();
            var result = (R / ke) * (1.0f - ke_d)
                       - R / (ka - ke) * (ke_d - ka_d);
            if (result < 0.0f) { result = 0.0f; }
            return result;
        }

        // After drinking: initial conditions at t = T, then standard decay
        var ke_T    = Math.pow(0.5, T * ke / ln2).toFloat();
        var ka_T    = Math.pow(0.5, T * ka / ln2).toFloat();
        var A_gut_T = (R / ka) * (1.0f - ka_T);
        var A_bdy_T = (R / ke) * (1.0f - ke_T)
                    - R / (ka - ke) * (ke_T - ka_T);
        if (A_bdy_T < 0.0f) { A_bdy_T = 0.0f; }

        var dt    = tHours - T;
        var ke_dt = Math.pow(0.5, dt * ke / ln2).toFloat();
        var ka_dt = Math.pow(0.5, dt * ka / ln2).toFloat();
        var result = A_bdy_T * ke_dt + A_gut_T * (ka / (ka - ke)) * (ke_dt - ka_dt);
        if (result < 0.0f) { result = 0.0f; }
        return result;
    }

    // Thin wrapper — computes mg at the current moment.
    static function calcCurrentMg(settings as Dictionary) as Float {
        return calcMgAt(settings, Time.now().value().toNumber());
    }

    // Returns the trend level for the caffeine curve:
    //   2  = rising now, will still be rising in 15 min  (↑↑)
    //   1  = rising now, will have peaked within 15 min  (↑)
    //   0  = flat / negligible                           (no arrow)
    //  -1  = falling, but rate < 3mg/15min — shallow tail (↓)
    //  -2  = falling, rate ≥ 3mg/15min — steep descent   (↓↓)
    //
    // Direction uses a 60-second look-ahead with a 0.01mg deadband to avoid
    // a false flat reading right at the absorption peak. The 15-minute
    // comparison uses calcMgAt(t+900) for the double-arrow thresholds.
    // Pre-loads events once for all 3 evaluations (was 3 separate Storage scans).
    static function calcTrendLevel(settings as Dictionary) as Number {
        var halfLifeHrs       = settings["halfLifeHrs"] as Float;
        var absorptionModel   = settings.hasKey("absorptionModel")   ? settings["absorptionModel"]   as Number : 0;
        var standardFoodState = settings.hasKey("standardFoodState") ? settings["standardFoodState"] as Number : 1;
        var ln2               = Math.log(2.0, Math.E).toFloat();
        var ke                = ln2 / halfLifeHrs;
        var events            = _loadAllEvents();
        var nowSec            = Time.now().value().toNumber();
        var nowMg  = _calcMgAtFromEvents(events, nowSec,       halfLifeHrs, absorptionModel, standardFoodState, ke, ln2);
        var mg60   = _calcMgAtFromEvents(events, nowSec + 60,  halfLifeHrs, absorptionModel, standardFoodState, ke, ln2);
        var mg900  = _calcMgAtFromEvents(events, nowSec + 900, halfLifeHrs, absorptionModel, standardFoodState, ke, ln2);
        if (mg60 > nowMg + 0.01f) {
            return (mg900 > nowMg) ? 2 : 1;
        }
        if (mg60 < nowMg - 0.01f) {
            return ((nowMg - mg900) > 3.0f) ? -2 : -1;
        }
        return 0;
    }

    // Combined trend + current mg calculation. Loads events once from Storage
    // and evaluates all 3 trend points plus the current level.
    // Returns [trendLevel as Number, currentMg as Float].
    // Used by MainView to avoid separate calcCurrentMg + calcTrendLevel calls.
    static function calcTrendAndCurrent(settings as Dictionary) as Array {
        var halfLifeHrs       = settings["halfLifeHrs"] as Float;
        var absorptionModel   = settings.hasKey("absorptionModel")   ? settings["absorptionModel"]   as Number : 0;
        var standardFoodState = settings.hasKey("standardFoodState") ? settings["standardFoodState"] as Number : 1;
        var ln2               = Math.log(2.0, Math.E).toFloat();
        var ke                = ln2 / halfLifeHrs;
        var events            = _loadAllEvents();
        var nowSec            = Time.now().value().toNumber();
        var nowMg  = _calcMgAtFromEvents(events, nowSec,       halfLifeHrs, absorptionModel, standardFoodState, ke, ln2);
        var mg60   = _calcMgAtFromEvents(events, nowSec + 60,  halfLifeHrs, absorptionModel, standardFoodState, ke, ln2);
        var mg900  = _calcMgAtFromEvents(events, nowSec + 900, halfLifeHrs, absorptionModel, standardFoodState, ke, ln2);
        var trend;
        if (mg60 > nowMg + 0.01f) {
            trend = (mg900 > nowMg) ? 2 : 1;
        } else if (mg60 < nowMg - 0.01f) {
            trend = ((nowMg - mg900) > 3.0f) ? -2 : -1;
        } else {
            trend = 0;
        }
        return [trend, nowMg] as Array;
    }

    // Core PK calculation engine — computes total mg in system as of asOfSec.
    //
    // Dispatches on absorptionModel:
    //   0 = Instant: original window-integral decay model
    //   1 = Standard: one-compartment PK with global food state
    //   2 = Precision: one-compartment PK with per-dose food state
    static function calcMgAt(settings as Dictionary, asOfSec as Number) as Float {
        var halfLifeHrs       = settings["halfLifeHrs"] as Float;
        var absorptionModel   = settings.hasKey("absorptionModel")   ? settings["absorptionModel"]   as Number : 0;
        var standardFoodState = settings.hasKey("standardFoodState") ? settings["standardFoodState"] as Number : 1;
        var ln2               = Math.log(2.0, Math.E).toFloat();
        var ke                = ln2 / halfLifeHrs;  // elimination rate constant (h⁻¹)
        var total             = 0.0f;

        // Use the full day index so doses from 2+ days ago that are still
        // within the 7-half-life window are included in the calculation.
        var dateStrings = loadDayIndex();

        for (var d = 0; d < dateStrings.size(); d++) {
            var events = loadDayLog(dateStrings[d] as String);
            for (var i = 0; i < events.size(); i++) {
                var evt = events[i] as Dictionary;

                var startSec;
                var finishSec;
                if (evt.hasKey("startSec")) {
                    startSec  = evt["startSec"]  as Number;
                    finishSec = evt["finishSec"] as Number;
                } else if (evt.hasKey("timestampSec")) {
                    startSec  = evt["timestampSec"] as Number;
                    finishSec = startSec;
                } else {
                    continue;  // skip malformed entries
                }

                var caffMg = (evt["caffeineMg"] as Number).toFloat();

                var elapsedStartSec = asOfSec - startSec;
                if (elapsedStartSec < 0) { elapsedStartSec = 0; }
                var elapsedStartHrs = elapsedStartSec.toFloat() / 3600.0f;

                // Skip negligible contributions (> 7 half-lives since start)
                if (elapsedStartHrs > halfLifeHrs * 7.0f) { continue; }

                var remaining;
                if (absorptionModel == 0) {
                    if (finishSec <= startSec) {
                        // Instant model: instant dose
                        remaining = caffMg * Math.pow(0.5, elapsedStartHrs / halfLifeHrs).toFloat();
                    } else {
                        // Instant model: window dose (integral formula)
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
                    // PK absorption model (Standard or Precision)
                    var evtDict  = evt as Dictionary;
                    var doseType = evtDict.hasKey("type")      ? evtDict["type"]      as String : "drink";
                    var fs;
                    if (absorptionModel == 2) {
                        fs = evtDict.hasKey("foodState") ? evtDict["foodState"] as Number : 1;
                    } else {
                        fs = standardFoodState;
                    }
                    var ka = getKa(doseType, fs);
                    var windowHrs = (finishSec - startSec).toFloat() / 3600.0f;
                    if (windowHrs < 0.0f || doseType.equals("pill")) { windowHrs = 0.0f; }
                    remaining = calcAbsorbedMg(caffMg, ka, ke, elapsedStartHrs, windowHrs);
                }
                total += remaining;
            }
        }
        return total;
    }

    // ── Pre-loaded event helpers (avoid repeated Storage reads) ──────────

    // Loads all dose events from all days in the day index into a flat array.
    // One-time Storage cost (~31 reads), then the returned array can be passed
    // to _calcMgAtFromEvents for as many evaluations as needed with zero I/O.
    static function _loadAllEvents() as Array {
        var dateStrings = loadDayIndex();
        var allEvents = [] as Array;
        for (var d = 0; d < dateStrings.size(); d++) {
            var dayLog = loadDayLog(dateStrings[d] as String);
            for (var i = 0; i < dayLog.size(); i++) {
                allEvents.add(dayLog[i]);
            }
        }
        return allEvents;
    }

    // Same computation as calcMgAt but operates on a pre-loaded events array
    // instead of reading from Application.Storage on every call.
    // Parameters ke and ln2 are pre-computed by the caller to avoid redundant
    // Math.log calls across dozens of evaluations.
    static function _calcMgAtFromEvents(events as Array, asOfSec as Number,
                                        halfLifeHrs as Float, absorptionModel as Number,
                                        standardFoodState as Number,
                                        ke as Float, ln2 as Float) as Float {
        var total = 0.0f;
        for (var i = 0; i < events.size(); i++) {
            var evt = events[i] as Dictionary;

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

            var caffMg = (evt["caffeineMg"] as Number).toFloat();
            var elapsedStartSec = asOfSec - startSec;
            if (elapsedStartSec < 0) { elapsedStartSec = 0; }
            var elapsedStartHrs = elapsedStartSec.toFloat() / 3600.0f;

            if (elapsedStartHrs > halfLifeHrs * 7.0f) { continue; }

            var remaining;
            if (absorptionModel == 0) {
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
                var doseType = evt.hasKey("type") ? evt["type"] as String : "drink";
                var fs;
                if (absorptionModel == 2) {
                    fs = evt.hasKey("foodState") ? evt["foodState"] as Number : 1;
                } else {
                    fs = standardFoodState;
                }
                var ka = getKa(doseType, fs);
                var windowHrs = (finishSec - startSec).toFloat() / 3600.0f;
                if (windowHrs < 0.0f || doseType.equals("pill")) { windowHrs = 0.0f; }
                remaining = calcAbsorbedMg(caffMg, ka, ke, elapsedStartHrs, windowHrs);
            }
            total += remaining;
        }
        return total;
    }

    // Calculate today's total consumed (raw mg, no decay)
    static function calcTodayTotalMg() as Number {
        var events = loadDayLog(todayKey());
        var total  = 0;
        for (var i = 0; i < events.size(); i++) {
            total += (events[i] as Dictionary)["caffeineMg"] as Number;
        }
        return total;
    }

    // Returns minutes from now until the system will fall below sleepThresholdMg.
    // Accounts for doses still absorbing by finding the combined peak first.
    // Includes pending recording using drinkTimeEstimateMin as projected finish.
    // Returns -1 if already below threshold.
    static function minutesUntilSleepSafe(settings as Dictionary) as Number {
        var nowSec   = Time.now().value().toNumber();
        var sleepSec = calcSleepSafeSec(settings);
        if (sleepSec < 0) { return -1; }
        return (sleepSec - nowSec) / 60;
    }

    // Invalidates the sleep-safe cache without running any computation.
    // Called from mutation points (log, delete, settings save, finish recording)
    // so the cache is marked stale immediately. The actual bisection computation
    // runs lazily on the next onUpdate() call via the cache-miss path in
    // calcSleepSafeSec — safely away from tap handlers where the watchdog fires.
    static function refreshSleepCache() as Void {
        // Reset the in-memory recording-mode TTL so it recomputes next frame.
        _recSleepCacheSec = 0;
        // Delete the persistent cache key. calcSleepSafeSec will recompute
        // and re-store it on the next call (from onUpdate, not a tap handler).
        Application.Storage.deleteValue("sleep_safe_cache");
    }

    // Returns absolute Unix timestamp when system will drop below sleepThresholdMg.
    // Reads from the cache written by refreshSleepCache() for speed.
    // Falls back to a live computation if the cache is missing (first run),
    // or recomputes live if a recording is active (time-dependent estimate).
    static function calcSleepSafeSec(settings as Dictionary) as Number {
        if (loadPendingDose() != null) {
            // Active recording: recompute at most once per 60 seconds.
            // Display resolution is 1 minute, so sub-minute staleness is invisible.
            var nowSec = Time.now().value().toNumber();
            if (_recSleepCacheSec > 0 && (nowSec - _recSleepCacheSec) < 60) {
                return _recSleepCacheVal;
            }
            var result = _computeSleepSafeSec(settings);
            _recSleepCacheSec = nowSec;
            _recSleepCacheVal = result;
            return result;
        }
        var cached = Application.Storage.getValue("sleep_safe_cache");
        if (cached != null) { return cached as Number; }
        // Cache miss (first run or cleared) — compute and store.
        var result = _computeSleepSafeSec(settings);
        Application.Storage.setValue("sleep_safe_cache", result);
        return result;
    }

    // Core computation: runs the bisection peak-finder and solves for sleep time.
    // Only called by calcSleepSafeSec and refreshSleepCache — never directly
    // from onUpdate, so the bisection only runs when data actually changes.
    static function _computeSleepSafeSec(settings as Dictionary) as Number {
        var peakInfo    = calcPeakInfo(settings);
        var peakMg      = peakInfo[0] as Float;
        var peakSec     = peakInfo[1] as Number;
        var thresholdMg = (settings["sleepThresholdMg"] as Number).toFloat();
        if (peakMg <= thresholdMg) { return -1; }
        var halfLifeHrs  = settings["halfLifeHrs"] as Float;
        var ln2          = Math.log(2.0, Math.E).toFloat();
        var hoursFromPeak = halfLifeHrs * (Math.log(peakMg / thresholdMg, Math.E) / ln2).toFloat();
        return peakSec + (hoursFromPeak * 3600.0f).toNumber();
    }

    // Formats an absolute Unix timestamp as a local clock time string "H:MMam/pm".
    // Uses System.getClockTime() for the local time base to avoid UTC issues
    // with Gregorian.info (which uses UTC per KB timezone bug).
    static function formatSleepSec(sleepSec as Number) as String {
        var nowSec    = Time.now().value().toNumber();
        var minsFromNow = (sleepSec - nowSec) / 60;
        return formatSleepTime(minsFromNow);
    }

    // Returns [peakMg as Float, peakSec as Number] — the highest combined caffeine
    // level and the time it occurs, including any pending recording projected
    // to finish at startSec + drinkTimeEstimateMin (or nowSec if overdue).
    static function calcPeakInfo(settings as Dictionary) as Array {
        var nowSec  = Time.now().value().toNumber();
        var pending = loadPendingDose();
        if (pending == null) {
            return _findPeak(settings, nowSec, false, 0, 0, 0.0f, 0, "drink", 1);
        }
        var drinkEst = settings.hasKey("drinkTimeEstimateMin")
            ? settings["drinkTimeEstimateMin"] as Number : 30;
        var pStart  = pending["startSec"] as Number;
        var pFinish = pStart + drinkEst * 60;
        if (pFinish < nowSec) { pFinish = nowSec; }  // overdue: use current time
        var pCaffMg = (pending["caffeineMg"] as Number).toFloat();
        var pType   = pending.hasKey("type")      ? pending["type"]      as String : "drink";
        var pFs     = pending.hasKey("foodState") ? pending["foodState"] as Number : 1;
        var pModel  = settings.hasKey("absorptionModel") ? settings["absorptionModel"] as Number : 0;
        return _findPeak(settings, nowSec, true, pStart, pFinish, pCaffMg, pModel, pType, pFs);
    }

    // Returns [peakMg as Float, peakSec as Number] after adding a hypothetical
    // new instant dose (start=finish=now) on top of all logged doses.
    // Used by the Preview screen to show peak level and when it will occur.
    static function previewPeakInfo(caffMg as Number, doseType as String,
                                     foodState as Number, settings as Dictionary) as Array {
        var nowSec   = Time.now().value().toNumber();
        var absModel = settings.hasKey("absorptionModel") ? settings["absorptionModel"] as Number : 0;
        return _findPeak(settings, nowSec, true, nowSec, nowSec, caffMg.toFloat(),
                         absModel, doseType, foodState);
    }

    // Bisection peak-finder — public entry point. Loads events then delegates.
    static function _findPeak(settings as Dictionary, nowSec as Number,
                                       hasExtra as Boolean, eStart as Number, eFinish as Number,
                                       eCaffMg as Float, eModel as Number,
                                       eDoseType as String, eFoodState as Number) as Array {
        var events = _loadAllEvents();
        return _findPeakFromEvents(events, settings, nowSec, hasExtra,
                                   eStart, eFinish, eCaffMg, eModel, eDoseType, eFoodState);
    }

    // Inner peak-finder. Accepts pre-loaded events so callers that need to run
    // many peak evaluations (e.g. dose-threshold bisection) can load Storage once.
    // Algorithm: exponential-search for upper bound where curve is falling,
    // then bisect between lo (rising) and hi (falling) for 20 iterations.
    // Precision: ~0.17s over a 180000s window.
    static function _findPeakFromEvents(events as Array, settings as Dictionary, nowSec as Number,
                                        hasExtra as Boolean, eStart as Number, eFinish as Number,
                                        eCaffMg as Float, eModel as Number,
                                        eDoseType as String, eFoodState as Number) as Array {
        var halfLifeHrs       = settings["halfLifeHrs"] as Float;
        var absorptionModel   = settings.hasKey("absorptionModel")   ? settings["absorptionModel"]   as Number : 0;
        var standardFoodState = settings.hasKey("standardFoodState") ? settings["standardFoodState"] as Number : 1;
        var ln2 = Math.log(2.0, Math.E).toFloat();
        var ke  = ln2 / halfLifeHrs;

        // Pre-compute ka for extra dose (only used in PK mode)
        var eKa = 0.0f;
        if (hasExtra && eModel != 0) {
            if (eDoseType.equals("drink")) {
                eKa = (eFoodState == 0) ? 3.5f : ((eFoodState == 2) ? 2.0f : 2.75f);
            } else {
                eKa = (eFoodState == 0) ? 1.75f : ((eFoodState == 2) ? 1.0f : 1.375f);
            }
        }

        // Early-exit: if no extra dose and the curve is already falling, peak is now.
        // Skipped when hasExtra because at t=0 a new PK-mode dose contributes 0mg
        // (elapsedHrs=0 → ke_d=ka_d=1 → contribution=0), so the existing-dose
        // falloff would incorrectly trigger the early exit before the new dose peaks.
        if (!hasExtra) {
            var mgNow = _mgForBisect(events, nowSec,      halfLifeHrs, absorptionModel, standardFoodState, ke, ln2, false, 0, 0, 0.0f, 0, eKa);
            var mg60  = _mgForBisect(events, nowSec + 60, halfLifeHrs, absorptionModel, standardFoodState, ke, ln2, false, 0, 0, 0.0f, 0, eKa);
            if (mg60 <= mgNow) {
                return [mgNow, nowSec] as Array;  // peak is at or before now
            }
        }

        // Exponential search for upper bound where curve is falling
        var hiSec  = nowSec + 3600;
        var maxSec = nowSec + (halfLifeHrs * 10.0f * 3600.0f).toNumber();
        while (hiSec < maxSec) {
            var mgHi   = _mgForBisect(events, hiSec,      halfLifeHrs, absorptionModel, standardFoodState, ke, ln2, hasExtra, eStart, eFinish, eCaffMg, eModel, eKa);
            var mgHi60 = _mgForBisect(events, hiSec + 60, halfLifeHrs, absorptionModel, standardFoodState, ke, ln2, hasExtra, eStart, eFinish, eCaffMg, eModel, eKa);
            if (mgHi60 < mgHi) { break; }
            hiSec += 3600;
        }

        // Bisect: loSec is always rising, hiSec is always falling
        var loSec = nowSec;
        for (var i = 0; i < 10; i++) {
            var midSec  = loSec + (hiSec - loSec) / 2;  // safe midpoint
            var mgMid   = _mgForBisect(events, midSec,      halfLifeHrs, absorptionModel, standardFoodState, ke, ln2, hasExtra, eStart, eFinish, eCaffMg, eModel, eKa);
            var mgMid60 = _mgForBisect(events, midSec + 60, halfLifeHrs, absorptionModel, standardFoodState, ke, ln2, hasExtra, eStart, eFinish, eCaffMg, eModel, eKa);
            if (mgMid60 > mgMid) { loSec = midSec; } else { hiSec = midSec; }
        }

        var peakSec = loSec + (hiSec - loSec) / 2;  // safe midpoint avoids integer overflow
        var peakMg  = _mgForBisect(events, peakSec, halfLifeHrs, absorptionModel, standardFoodState, ke, ln2, hasExtra, eStart, eFinish, eCaffMg, eModel, eKa);
        return [peakMg, peakSec] as Array;
    }

    // Returns the oops dose threshold for the Log Stimulant list.
    // Conservative approximation: any profile whose caffMg would push the
    // current in-system level over the oops threshold is flagged red.
    // Uses current mg (not peak) — intentionally conservative, and fast.
    // The Preview screen provides the accurate peak-based answer when tapped.
    // Returns 9999.0f if no oops threshold is set (nothing flagged red).
    static function calcOopsCurrentThreshold(settings as Dictionary) as Float {
        var oopsMg = settings["oopsThresholdMg"];
        if (oopsMg == null) { return 9999.0f; }
        var currentMg = calcCurrentMg(settings);
        return (oopsMg as Float) - currentMg;
    }

    // Combined mg at asOfSec: all logged doses (from pre-loaded events)
    // + optional extra dose. Zero Storage I/O per call.
    static function _mgForBisect(events as Array, asOfSec as Number,
                                          halfLifeHrs as Float, absorptionModel as Number,
                                          standardFoodState as Number,
                                          ke as Float, ln2 as Float,
                                          hasExtra as Boolean, eStart as Number, eFinish as Number,
                                          eCaffMg as Float, eModel as Number, eKa as Float) as Float {
        var base = _calcMgAtFromEvents(events, asOfSec, halfLifeHrs, absorptionModel, standardFoodState, ke, ln2);
        if (!hasExtra || eCaffMg <= 0.0f) { return base; }
        return base + _extraDoseMgAt(asOfSec, eStart, eFinish, eCaffMg, eModel, eKa, ke, ln2, halfLifeHrs);
    }

    // PK contribution of a single extra dose (not yet in storage) at asOfSec.
    static function _extraDoseMgAt(asOfSec as Number, startSec as Number, finishSec as Number,
                                            caffMg as Float, absorptionModel as Number,
                                            ka as Float, ke as Float, ln2 as Float,
                                            halfLifeHrs as Float) as Float {
        var elapsedHrs = (asOfSec - startSec).toFloat() / 3600.0f;
        if (elapsedHrs < 0.0f || elapsedHrs >= halfLifeHrs * 7.0f) { return 0.0f; }
        if (absorptionModel == 0) {
            // Instant window model
            if (finishSec <= startSec) {
                return caffMg * Math.pow(0.5, elapsedHrs / halfLifeHrs).toFloat();
            }
            var durHrs = (finishSec - startSec).toFloat() / 3600.0f;
            var coeff  = caffMg / durHrs * (halfLifeHrs / ln2);
            if (asOfSec < finishSec) {
                return coeff * (1.0f - Math.pow(0.5, elapsedHrs / halfLifeHrs).toFloat());
            }
            var finEl = (asOfSec - finishSec).toFloat() / 3600.0f;
            var res = coeff * (Math.pow(0.5, finEl / halfLifeHrs).toFloat()
                             - Math.pow(0.5, elapsedHrs / halfLifeHrs).toFloat());
            return res > 0.0f ? res : 0.0f;
        } else {
            // PK absorption model
            var diff = ka - ke;
            if (diff < 0.0f) { diff = -diff; }
            if (diff < 0.001f) {
                return caffMg * Math.pow(0.5, elapsedHrs * ke / ln2).toFloat();
            }
            var windowHrs = (finishSec - startSec).toFloat() / 3600.0f;
            if (windowHrs < 0.0f) { windowHrs = 0.0f; }
            if (windowHrs <= 0.0f) {
                var ke_d = Math.pow(0.5, elapsedHrs * ke / ln2).toFloat();
                var ka_d = Math.pow(0.5, elapsedHrs * ka / ln2).toFloat();
                var res  = caffMg * (ka / (ka - ke)) * (ke_d - ka_d);
                return res > 0.0f ? res : 0.0f;
            }
            var T = windowHrs;
            var R = caffMg / T;
            if (elapsedHrs <= T) {
                var ke_d = Math.pow(0.5, elapsedHrs * ke / ln2).toFloat();
                var ka_d = Math.pow(0.5, elapsedHrs * ka / ln2).toFloat();
                var res  = (R / ke) * (1.0f - ke_d) - R / (ka - ke) * (ke_d - ka_d);
                return res > 0.0f ? res : 0.0f;
            } else {
                var ke_T    = Math.pow(0.5, T * ke / ln2).toFloat();
                var ka_T    = Math.pow(0.5, T * ka / ln2).toFloat();
                var A_gut_T = (R / ka) * (1.0f - ka_T);
                var A_bdy_T = (R / ke) * (1.0f - ke_T) - R / (ka - ke) * (ke_T - ka_T);
                if (A_bdy_T < 0.0f) { A_bdy_T = 0.0f; }
                var dt    = elapsedHrs - T;
                var ke_dt = Math.pow(0.5, dt * ke / ln2).toFloat();
                var ka_dt = Math.pow(0.5, dt * ka / ln2).toFloat();
                var res   = A_bdy_T * ke_dt + A_gut_T * (ka / (ka - ke)) * (ke_dt - ka_dt);
                return res > 0.0f ? res : 0.0f;
            }
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────────

    static function _yesterdayKey() as String {
        var yesterdayMoment = Time.now().subtract(new Time.Duration(86400));
        var info = Gregorian.info(yesterdayMoment, Time.FORMAT_SHORT);
        var y = info.year.toString();
        var m = info.month < 10 ? "0" + info.month.toString() : info.month.toString();
        var d = info.day   < 10 ? "0" + info.day.toString()   : info.day.toString();
        return y + m + d;
    }

    // Format minutes-from-now as a clock time string "H:MMam/pm"
    static function formatSleepTime(minutesFromNow as Number) as String {
        if (minutesFromNow < 0) {
            return "Now";
        }
        var clock      = System.getClockTime();
        var totalMins  = clock.hour * 60 + clock.min + minutesFromNow;
        totalMins      = totalMins % (24 * 60);  // wrap at midnight
        var h          = totalMins / 60;
        var m          = totalMins % 60;
        var ampm       = h >= 12 ? "pm" : "am";
        var h12        = h % 12;
        if (h12 == 0) { h12 = 12; }
        var mStr = m < 10 ? "0" + m.toString() : m.toString();
        return h12.toString() + ":" + mStr + ampm;
    }
}
