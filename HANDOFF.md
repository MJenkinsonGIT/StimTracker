# StimTracker — Performance Review Handoff

**Purpose:** This document is for an Opus session doing a focused performance review of the pharmacokinetic calculation code. It describes the full calculation stack, what fires when, the caching strategy, known performance concerns, and the specific areas to review.

The README (appended at the end) describes what the app does from a user perspective and contains detailed documentation of the pharmacokinetic model, absorption constants, and sleep threshold calculation approach.

---

## Architecture Overview

StimTracker is a Garmin Connect IQ **watch-app** (768KB RAM) targeting the Venu 3 (454×454 AMOLED). All business logic lives in `StimTrackerStorage.mc` as static functions. UI is split across multiple view/delegate files. There is no background thread in the foreground app — all computation happens synchronously on the main UI thread during `onUpdate()` calls.

**Relevant source files for this review:**
- `source/StimTrackerStorage.mc` — all PK calculations, caching, storage I/O
- `source/MainView.mc` — main screen; calls `calcCurrentMg`, `calcTrendLevel`, `minutesUntilSleepSafe` on every `onUpdate()`
- `source/PreviewView.mc` — preview screen; calls `previewPeakInfo` on every `onUpdate()`
- `source/StimTrackerBackground.mc` — background service (separate context); calls its own inlined `_calcMgAt` — not part of this review

---

## The Calculation Stack

### 1. `calcMgAt(settings, asOfSec)` — Core PK Engine

The foundation of everything. Iterates over **all days in the day index** (up to 30 days), loads each day's log from Storage, and sums the PK contribution of every dose.

**Performance characteristics:**
- Calls `Application.Storage.getValue()` for **every day in the index** — potentially 30 Storage reads per call
- Each dose requires 2–6 calls to `Math.pow()` depending on absorption model and whether it's in the drinking window or after
- Doses older than `halfLifeHrs * 7.0` hours are skipped (early-exit check)
- In practice, only today's and yesterday's doses contribute meaningfully — but the loop still iterates all 30 days and calls Storage for each

**Called by:** `calcCurrentMg`, `calcTrendLevel` (×3), `_mgForBisect` (×many during bisection)

---

### 2. `calcTrendLevel(settings)` — Trend Arrows

Called once per `onUpdate()` on the main screen.

```
calcTrendLevel()
  ├── calcMgAt(now)        [full Storage scan]
  ├── calcMgAt(now + 60s)  [full Storage scan]
  └── calcMgAt(now + 900s) [full Storage scan]
```

**3 full Storage scans per main screen refresh.**

---

### 3. Sleep Threshold — Cached Path

The sleep threshold display (`minutesUntilSleepSafe`) goes through a **cache** stored in `Application.Storage` under `"sleep_safe_cache"`.

**Cache is populated by `refreshSleepCache()`**, which is called after every mutation:
- `saveSettings()`
- `logDoseWithWindow()`
- `updateDose()`
- `deleteDose()`
- `resetToday()`

**On main screen `onUpdate()`**, `minutesUntilSleepSafe` calls `calcSleepSafeSec` which reads the cache — **1 Storage read**, no computation.

**Exception:** During an active recording (`pending_dose` exists), the cache is bypassed and `_computeSleepSafeSec` runs live on every `onUpdate()` call (because the projected finish time drifts with the clock).

**`_computeSleepSafeSec` cost:**
```
_computeSleepSafeSec()
  └── calcPeakInfo()
        └── _findPeak()
              ├── Early-exit check: 2× _mgForBisect → 2× calcMgAt
              ├── Exponential search: ~4–8× _mgForBisect → 4–8× calcMgAt (each)
              └── Bisection (20 iters): 2× _mgForBisect per iteration → 40× calcMgAt
              Total: ~50–100 calcMgAt calls
```

Each `calcMgAt` does up to 30 Storage reads. This is the expensive operation that caused the 2+ second main screen load before caching was introduced.

---

### 4. Preview Screen — `previewPeakInfo` on Every `onUpdate()`

**This is the primary concern for this review.**

`PreviewView.onUpdate()` calls `StimTrackerStorage.previewPeakInfo(caffMg, doseType, previewFs, _settings)` on **every frame render**.

```
PreviewView.onUpdate()
  └── previewPeakInfo(caffMg, doseType, previewFs, settings)
        └── _findPeak(settings, nowSec, hasExtra=true, ...)
              ├── No early-exit (hasExtra=true always skips it)
              ├── Exponential search: ~4–8 iterations, each 2× _mgForBisect
              └── Bisection: 20 iterations, each 2× _mgForBisect
              Total: ~50–100 calcMgAt calls per onUpdate()
```

The preview screen is not continuously refreshing (it's a static screen with no timer), so `onUpdate()` only fires when the user taps a button or the system requests a redraw. However, it fires at least once when the screen opens, and once per any tap event (button highlights etc.).

**The preview screen also recomputes the sleep-safe time inline** (not via cache), duplicating the `hoursFromPeak` calculation:

```monkeyc
// In PreviewView.onUpdate():
var hoursFromPeak  = halfLife * (Math.log(peakMg / threshMg, Math.E) / ln2).toFloat();
var futureSleepSec = peakSec + (hoursFromPeak * 3600.0f).toNumber();
```

This is fine — it's O(1) math, not expensive. The `previewPeakInfo` call is where the cost is.

---

### 5. `_findPeak` — Bisection Algorithm Detail

```
_findPeak(settings, nowSec, hasExtra, eStart, eFinish, eCaffMg, eModel, eDoseType, eFoodState)
```

**When `hasExtra=false` (main screen sleep cache):**
1. Check if curve is already falling (2× `_mgForBisect`)
2. If falling: return `[mgNow, nowSec]` immediately — **cheap path**
3. If rising: exponential search (typically 3–6 iterations × 2 calls = 6–12 `_mgForBisect`)
4. Bisection: 20 iterations × 2 calls = 40 `_mgForBisect`
5. Total: ~50–55 `calcMgAt` calls

**When `hasExtra=true` (preview screen, pending recording):**
1. Skip early-exit entirely (the new PK dose contributes 0mg at t=0, so early-exit would wrongly return the pre-dose peak)
2. Exponential search: same as above
3. Bisection: same as above
4. Total: ~50 `calcMgAt` calls, always — no cheap path

**`_mgForBisect` structure:**
```
_mgForBisect(settings, asOfSec, hasExtra, ...)
  ├── calcMgAt(settings, asOfSec)   [up to 30 Storage reads + Math.pow per dose]
  └── _extraDoseMgAt(...)           [O(1) — no Storage, single dose math]
```

So the Storage cost is entirely in `calcMgAt`, not `_extraDoseMgAt`.

---

## Known Performance Issues / Areas to Review

### Issue 1: `calcMgAt` reads Storage on every call

Every call to `calcMgAt` calls `loadDayIndex()` (1 Storage read) then `loadDayLog()` for each day in the index (up to 30 Storage reads). In practice most days contribute 0mg (doses have fully decayed), but the Storage reads still happen.

**Potential fix:** Pass a pre-loaded event list into `calcMgAt` instead of reading from Storage inside. The bisection calls `calcMgAt` ~50–100 times for a single peak-find — loading Storage once before the bisection starts and passing it in would replace ~1500–3000 Storage reads with 30.

### Issue 2: `calcTrendLevel` calls `calcMgAt` 3 times on every main screen `onUpdate()`

These three calls each do the full Storage scan. The trend level doesn't change between frames (it changes when a dose is logged or settings change). It could be cached similarly to the sleep threshold.

**Potential fix:** Cache the trend level in `Application.Storage` alongside the sleep cache, refreshed by the same mutation points (`refreshSleepCache` → `refreshDisplayCache`).

### Issue 3: Preview screen has no result caching

`previewPeakInfo` is called fresh on every `onUpdate()`. The inputs (`caffMg`, `doseType`, `previewFs`, `settings`) don't change between frames unless the user actively changes something. The result could be computed once when the screen opens and stored in a member variable, then only recomputed when `setTimings()` or `setFoodState()` is called.

**Potential fix:** Store `_peakInfo` as a member of `PreviewView`, compute it in `initialize()` and in `setTimings()`/`setFoodState()`, and use the cached value in `onUpdate()`.

### Issue 4: `_fillCircularBar` in `MainView` is a pixel-by-pixel loop

```monkeyc
for (var row = y; row < y + barH; row++) {
    // sqrt per row, fillRectangle per row
}
```

For `barH=27` this is 27 iterations with a `Math.sqrt` and `dc.fillRectangle` each. Small but worth noting. The arc itself uses `dc.drawArc` (hardware-accelerated SDK call) which is fine.

### Issue 5: `_drawOopsButton` loads a bitmap resource on every `onUpdate()`

```monkeyc
var heart = WatchUi.loadResource(Rez.Drawables.OopsHeart) as WatchUi.BitmapResource;
```

This is called every frame. The gear icon bitmap is correctly cached as a member variable (`_gearBmp`) in `initialize()`. The heart bitmap should be treated the same way.

### Issue 6: `calcMgAt` loads settings from inside the bisection

`_computeSleepSafeSec(settings)` receives `settings` as a parameter but `calcMgAt` (called inside `_mgForBisect`) also receives settings. This is fine — no redundant settings loads. But `_mgForBisect` calls `calcMgAt(settings, asOfSec)` which calls `loadDayIndex()` internally. The day index is loaded fresh on every `calcMgAt` call even though it doesn't change during a bisection run.

---

## Call Count Summary (Worst Case, Active Recording on Main Screen)

| Operation | Calls per `onUpdate()` | Storage reads per `onUpdate()` |
|---|---|---|
| `calcCurrentMg` | 1 | up to 30 |
| `calcTrendLevel` | 3× `calcMgAt` | up to 90 |
| `minutesUntilSleepSafe` (recording active, no cache) | ~50–100× `calcMgAt` | up to 3,000 |
| `loadPendingDose` | 1 | 1 |
| **Total (recording active)** | | **up to ~3,120** |

**With no active recording (cache hit):**

| Operation | Calls per `onUpdate()` | Storage reads |
|---|---|---|
| `calcCurrentMg` | 1 | up to 30 |
| `calcTrendLevel` | 3× `calcMgAt` | up to 90 |
| `minutesUntilSleepSafe` (cache hit) | 0 | 1 |
| `loadPendingDose` | 1 | 1 |
| **Total (no recording)** | | **up to ~122** |

The cache is doing most of the work. The remaining cost of ~122 Storage reads per frame for trend + current is the primary non-recording overhead.

---

## Monkey C Constraints Relevant to Optimisation

- **No multithreading.** All computation is synchronous on the UI thread.
- **`Application.Storage.getValue()` is the main I/O operation** — cost is not documented but empirically noticeable at scale (30 reads per `calcMgAt` call is the observed bottleneck).
- **`Math.pow()` is available** but each call is a floating-point operation with meaningful cost on a watch CPU. The PK formulas use 2–6 `Math.pow` calls per dose per `calcMgAt` call.
- **No closures or lambdas.** Can't pass a loaded data set into a function via closure — must pass as explicit parameters.
- **Static functions only in classes** (no instance methods on `StimTrackerStorage`). Data passing must be via parameters.
- **`private static` silently returns null/0** — confirmed device bug. All helper functions used across contexts must omit `private`.
- **Integer overflow at Unix timestamps** (~1.74B in 2026): `(a + b) / 2` overflows 32-bit signed int. Always use `a + (b - a) / 2` for midpoints with timestamp values.

---

## Suggested Optimisation Priority

1. **High impact, low risk:** Cache `previewPeakInfo` result in `PreviewView` as a member variable. Recompute only in `initialize()`, `setTimings()`, `setFoodState()`. Eliminates repeated full bisection on non-changing preview screen.

2. **High impact, medium complexity:** Pre-load the day's events once before bisection and pass them into `calcMgAt` instead of re-reading Storage 50–100 times. Requires adding an optional pre-loaded events parameter to `calcMgAt` or creating a new internal variant.

3. **Medium impact, low risk:** Cache trend level alongside sleep cache. Refresh at same mutation points. Eliminates 3× `calcMgAt` per main screen frame.

4. **Low impact, low risk:** Cache `OopsHeart` bitmap in `MainView.initialize()` as a member variable (same pattern as `_gearBmp`).

5. **Low impact, medium complexity:** Optimise `_fillCircularBar` — precompute halfwidths or use a different drawing primitive.

---

## What Is Working Well (Do Not Change)

- **Sleep cache strategy:** Caching `_computeSleepSafeSec` result in Storage and only recomputing on mutation eliminated the 2+ second main screen freeze. This pattern is correct and should be preserved.
- **7-half-life cutoff:** The early-exit `if (elapsedStartHrs > halfLifeHrs * 7.0f)` in `calcMgAt` correctly skips negligible doses (< 1% remaining). This is a correct and important optimisation.
- **Bisection safe midpoint:** `loSec + (hiSec - loSec) / 2` instead of `(loSec + hiSec) / 2` prevents integer overflow with Unix timestamps. Must be preserved.
- **`hasExtra` early-exit skip:** The check `if (!hasExtra)` before the early-exit in `_findPeak` is correct and critical — without it, new PK-mode doses (which contribute 0mg at t=0) would incorrectly trigger the early exit.
- **`_extraDoseMgAt` is O(1):** The extra dose calculation does no Storage I/O and is fast. The Storage cost in bisection is entirely in `calcMgAt(base)`, not in the extra dose math.

---

*Append: Full README follows on next page*

---

# README

