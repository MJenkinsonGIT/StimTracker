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

    // Default stimulant profiles (Phase 1 — caffeine only)
    // Each profile: { "id" => Number, "name" => String, "caffeineMg" => Number }
    static const DEFAULT_PROFILES = [
        { "id" => 1, "name" => "Reign Red Dragon",          "caffeineMg" => 300 },
        { "id" => 2, "name" => "G Fuel Blue Ice",           "caffeineMg" => 150 },
        { "id" => 3, "name" => "GV Energy Cherry Slush",    "caffeineMg" => 120 },
        { "id" => 4, "name" => "Nutricost Caff+Theanine",   "caffeineMg" => 200 },
        { "id" => 5, "name" => "Nutricost Energy Complex",  "caffeineMg" => 100 },
        { "id" => 6, "name" => "Nutricost Clean Energy",    "caffeineMg" => 100 },
        { "id" => 7, "name" => "Nutricost Intra-Workout",   "caffeineMg" => 100 }
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
            return stored as Dictionary;
        }
        // First run — build defaults
        var defaults = buildDefaultSettings();
        Application.Storage.setValue("settings", defaults);
        return defaults;
    }

    static function saveSettings(settings as Dictionary) as Void {
        Application.Storage.setValue("settings", settings);
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
            "nextProfileId"     => 8,   // first user-created profile gets ID 8
            "absorptionModel"   => 0,   // 0=Instant, 1=Standard, 2=Precision
            "standardFoodState" => 1    // 0=Fasted, 1=Typical, 2=WithFood (Standard sub-setting)
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

    // Calculate total caffeine currently in system.
    //
    // Dispatches on absorptionModel:
    //   0 = Instant: original window-integral decay model
    //   1 = Standard: one-compartment PK with global food state
    //   2 = Precision: one-compartment PK with per-dose food state
    //
    // Returns mg as a Float.
    static function calcCurrentMg(settings as Dictionary) as Float {
        var halfLifeHrs       = settings["halfLifeHrs"] as Float;
        var absorptionModel   = settings.hasKey("absorptionModel")   ? settings["absorptionModel"]   as Number : 0;
        var standardFoodState = settings.hasKey("standardFoodState") ? settings["standardFoodState"] as Number : 1;
        var nowSec            = Time.now().value().toNumber();
        var ln2               = Math.log(2.0, Math.E).toFloat();
        var ke                = ln2 / halfLifeHrs;  // elimination rate constant (h⁻¹)
        var total             = 0.0f;

        var dateStrings = [] as Array<String>;
        dateStrings.add(todayKey());
        dateStrings.add(_yesterdayKey());

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

                var elapsedStartSec = nowSec - startSec;
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
                        if (nowSec < finishSec) {
                            remaining = coeff * (1.0f - Math.pow(0.5, elapsedStartHrs / halfLifeHrs).toFloat());
                        } else {
                            var elapsedFinishHrs = (nowSec - finishSec).toFloat() / 3600.0f;
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

    // Calculate today's total consumed (raw mg, no decay)
    static function calcTodayTotalMg() as Number {
        var events = loadDayLog(todayKey());
        var total  = 0;
        for (var i = 0; i < events.size(); i++) {
            total += (events[i] as Dictionary)["caffeineMg"] as Number;
        }
        return total;
    }

    // Project the time (minutes from now) until current-in-system drops
    // below the sleep threshold.
    // Returns minutes as a Number, or -1 if already below threshold.
    static function minutesUntilSleepSafe(settings as Dictionary) as Number {
        var thresholdMg = (settings["sleepThresholdMg"] as Number).toFloat();
        var currentMg   = calcCurrentMg(settings);
        if (currentMg <= thresholdMg) {
            return -1;  // already safe
        }
        var halfLifeHrs = settings["halfLifeHrs"] as Float;
        // Solve: threshold = current * 0.5^(t/halfLife)
        // t = halfLife * log2(current / threshold)
        // log2(x) = ln(x) / ln(2)
        var ratio      = currentMg / thresholdMg;
        var hoursNeeded = halfLifeHrs * (Math.log(ratio, Math.E) / Math.log(2.0, Math.E)).toFloat();
        return (hoursNeeded * 60.0f).toNumber();
    }

    // Preview: what would currentMg be immediately after adding a new dose?
    static function previewCurrentMgAfterDose(caffeineMg as Number, settings as Dictionary) as Float {
        return calcCurrentMg(settings) + caffeineMg.toFloat();
    }

    // Preview: what would sleep-safe minutes be after adding a dose?
    static function previewMinutesAfterDose(caffeineMg as Number, settings as Dictionary) as Number {
        var thresholdMg  = (settings["sleepThresholdMg"] as Number).toFloat();
        var futureCurrentMg = calcCurrentMg(settings) + caffeineMg.toFloat();
        if (futureCurrentMg <= thresholdMg) {
            return -1;
        }
        var halfLifeHrs = settings["halfLifeHrs"] as Float;
        var ratio       = futureCurrentMg / thresholdMg;
        var hoursNeeded = halfLifeHrs * (Math.log(ratio, Math.E) / Math.log(2.0, Math.E)).toFloat();
        return (hoursNeeded * 60.0f).toNumber();
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
