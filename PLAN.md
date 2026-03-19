# StimTracker — App Planning Document

> **Status:** Active development — UI polish complete, pending device testing
> **Last updated:** March 2026
> **Note:** This is a working document — not the knowledge base. It contains research notes,
> decisions in progress, and future plans. Nothing here should be treated as tested or authoritative.

---

## 1. Concept Summary

A Garmin Watch App (with Glance) for tracking caffeine (and eventually other active ingredient)
consumption throughout the day. Core value propositions:
- Know how much caffeine is currently in your system (half-life decay model)
- Know when your caffeine will be below your sleep threshold
- See a warning before drinking something that would push you over a threshold
- Log and review consumption history

---

## 2. App Type Decision

**Watch App** (768KB RAM) with Glance view.
- Widget (64KB) ruled out immediately — insufficient memory for this data model.
- Watch App gives us 768KB RAM and proven glance support (see skin_temp_widget_development_lessons.md §21).
- Application.Storage: ~128KB total, 32KB per key. More than sufficient for Phase 1 scope.

---

## 3. Phasing Plan

### Phase 1 — Caffeine-only, full feature set
- Drink profile database (caffeine content only, 7 personal products + a few generics)
- Log a drink (tap to add, timestamped)
- Daily total vs. configurable limit
- Half-life decay model → "currently in system" estimate
- Sleep threshold → "Below Sleep Threshold at X:XX" projection
- Pre-drink preview (how long will this keep me awake?)
- "Oops" feature — log a side-effect event, sets a personal threshold warning
- History view (rolling window, TBD days)
- Glance: key caffeine metric at a glance
- First-run setup wizard (at minimum: body weight for personalised limit)

### Phase 2 — Multi-ingredient expansion
- Add tracked ingredients: L-Theanine, Taurine, B-vitamins, Tyrosine, etc.
- Expand drink profiles with full ingredient data
- Per-ingredient limits, half-lives, sleep thresholds
- "Oops" feature per-ingredient
- Note: L-Theanine (~1hr half-life) and Taurine (~1hr) clear fast — half-life calc is less
  compelling for these; daily total tracking is the main value.

### Phase 3 — Android companion app
- Long-term data export (beyond on-device rolling window)
- Richer history/trend views
- Sync drink/ingredient database

---

## 4. Product Database — Personal Products

*Labels photographed and analysed March 2026.*

### 4a. Caffeine content (Phase 1 focus)

| Product | Serving | Caffeine | Status |
|---------|---------|----------|--------|
| Reign Red Dragon (can) | 16 fl oz | 300mg | confirmed from label |
| G Fuel Blue Ice (powder) | 1 scoop (7g) | 150mg | confirmed from label |
| Great Value Energy Cherry Slush (can) | 16 fl oz | 200mg | confirmed from label |
| Nutricost Caffeine + L-Theanine (capsule) | 1 capsule | 200mg | confirmed from label |
| Nutricost Energy Complex (capsule) | 1 serving | 100mg | confirmed (front label) |
| Nutricost Clean Energy Powder | 1 scoop | 100mg | confirmed |
| Nutricost Intra-Workout Complex | 1 scoop | 100mg | confirmed |
| Neuro Alert Brain Energy & Stamina (capsule) | 1 capsule | — | DEFERRED: uses 200mg Paraxanthine, not caffeine — Phase 2 ingredient |

### 4b. Full ingredient list (Phase 2 reference)

**Reign Red Dragon (16 fl oz can)**
- Caffeine: 300mg
- BCAAs: 1000mg (L-Leucine, L-Isoleucine, L-Valine) — EXCLUDE from tracking per user
- CoQ10: 50mcg
- Niacin (B3): 21.6mg NE
- Vitamin B6: 2mg
- Vitamin B12: 2.4mcg
- Sodium: 200mg (electrolyte — EXCLUDE)
- Potassium: 70mg (electrolyte — EXCLUDE)

**G Fuel Blue Ice (per scoop)**
- Caffeine: 150mg
- Vitamin C: 250mg — EXCLUDE per user
- Vitamin E: 15 IU — EXCLUDE per user
- Niacin (B3): 45mg
- Vitamin B6: 0.4mg
- Vitamin B12: 0.6mcg
- Energy Complex (proprietary, amounts unknown): Taurine, L-Citrulline Malate,
  Glucuronolactone, N-Acetyl-L-Carnitine HCl
- Focus Complex (proprietary, amounts unknown): L-Tyrosine, N-Acetyl-L-Tyrosine,
  Adenosine-5-Triphosphate Disodium (ATP)

**Great Value Energy Cherry Slush (16 fl oz can)**
- Caffeine: 200mg
- Niacin (B3): TBD
- Vitamin B6: TBD
- Vitamin B12: TBD
- Sodium: (electrolyte — EXCLUDE)

**Nutricost Caffeine + L-Theanine (per capsule)**
- Caffeine: 200mg
- L-Theanine: 200mg

**Neuro Alert Brain Energy & Stamina**
- Active stimulant: 200mg Paraxanthine (NOT caffeine — a primary caffeine metabolite)
- Paraxanthine has similar CNS stimulant effects to caffeine but distinct pharmacokinetics
- DEFERRED to Phase 2: needs its own ingredient profile, not a caffeine alias
- Open question: track separately, or model as caffeine-equivalent with a conversion factor?

**Nutricost Energy Complex**
- Caffeine: 100mg per serving (from all sources, per front label)
- Full breakdown: TODO (Phase 2)

**Nutricost Clean Energy Powder**
- Caffeine: 100mg per scoop
- Full breakdown: TODO (Phase 2)

**Nutricost Intra-Workout Complex**
- Caffeine: 100mg per scoop (confirmed)
- Otherwise primarily BCAAs, Hydration Complex, electrolytes — exclude rest per user preference

### 4c. Ingredients to track in Phase 2 (user-confirmed exclusions in parentheses)

**TRACK:**
- Caffeine ✓ (Phase 1)
- L-Theanine
- Taurine
- Niacin / Vitamin B3
- Vitamin B6
- Vitamin B12
- L-Tyrosine / N-Acetyl-L-Tyrosine
- N-Acetyl-L-Carnitine
- L-Citrulline Malate (borderline — user to decide)
- CoQ10 (borderline — minimal half-life relevance)
- Glucuronolactone (borderline)

**EXCLUDE:**
- Electrolytes (sodium, potassium, magnesium, etc.)
- Vitamin C
- Vitamin E
- BCAAs (L-Leucine, L-Isoleucine, L-Valine)
- Hydration complex ingredients
- Creatine / workout recovery compounds

---

## 5. Scientific Reference Data

### Caffeine (Phase 1)

| Parameter | Value | Source |
|-----------|-------|--------|
| Half-life | 3–7 hrs (mean ~5 hrs) | NCBI / FDA |
| Daily limit (general) | 400mg | FDA / EFSA |
| Daily limit (weight-based) | 5.7 mg/kg body weight | EFSA |
| Peak plasma | 15–45 min after ingestion | Multiple sources |
| Sleep disruption threshold | ~100mg remaining is commonly cited; conservative: 50mg | Sleep Foundation |
| Default sleep threshold (app) | TBD — user-configurable, suggest 100mg as default |

**Factors affecting half-life (for user personalisation):**
- Smoking: speeds metabolism → ~3–4 hrs
- Oral contraceptives: ~doubles half-life
- Pregnancy: up to 15 hrs
- Liver function issues: dramatically longer
- Genetics (CYP1A2): "fast" vs "slow" metabolisers

### L-Theanine (Phase 2)
- Half-life: ~1 hour (65 min plasma; ~1.2 hr capsule form)
- Daily limit: No established upper limit; typical dose 100–200mg
- Note: Clears fast — daily total tracking more useful than decay model

### Taurine (Phase 2)
- Half-life: ~1 hour (0.7–1.4 hrs, clinical studies)
- Endogenous compound — hard to set a meaningful "limit"
- Note: Same situation as L-Theanine for tracking purposes

---

## 6. "Oops" Feature — Side Effect Baseline

*User-reported side effects (rare, but enough to warrant a warning system):*
- Elevated heart rate (resting HR elevated to ~80s bpm while seated at desk)
- Palpitations (can feel heartbeat in chest)

These are classic caffeine over-stimulation symptoms, consistent with adenosine receptor
saturation + sympathetic nervous system activation.

**Implication for defaults:**
- "Oops" threshold for caffeine should be set to whatever level was in system at the time
  the user logs the event (calculated from their consumption history + timestamps + half-life)
- App should prompt user to log an "Oops" event when they experience these symptoms
- That snapshot becomes a personal warning threshold
- Default before any "Oops" event: visual warning at 80% of daily limit
- After an "Oops" event: warn if projected system load will exceed the recorded threshold

---

## 7. Open Questions / Decisions Pending

- [x] History: 30 days on-device rolling window
- [x] Caffeine limit: weight-based (5.7mg/kg), pulled from UserProfile.getProfile().weight (grams)
- [x] Log timing: default to now, with optional backdating
- [x] Glance: both today total/limit AND current in-system estimate
- [x] Bedtime: pre-populate from UserProfile.getProfile().sleepTime, user-overridable
- [x] UserProfile permission required in manifest
- [x] App name: StimTracker (inclusive of future multi-ingredient scope)
- [x] Caffeine confirmed for all current products (see §4a)
- [ ] Paraxanthine (Neuro Alert) — defer to Phase 2; research whether to model as caffeine-equivalent or separate ingredient

---

## 8. Navigation / Screen Map (FINAL — Phase 1)

### Screen Inventory

**Glance** — two lines: today total/limit + current in-system mg. Tap → Main.

**Main Screen** — status hub
- Large: current caffeine in system (mg, decaying)
- Smaller: today total / limit
- Smaller: "Below Sleep Threshold: HH:MMpm" or "Below Sleep Threshold: Now"
- Coloured arc/bar: today total vs limit (green → amber → red)
- Small Oops button (corner, distinct colour)

**Log Stimulant Screen** — scrollable profile list
- Each row: stimulant name + caffeine mg
- Last row: [+ Add New Stimulant]
- Tap any profile → Preview/Confirm Screen
- Long-press any profile → Edit / Delete options

**Add Stimulant Screen** — name + caffeine mg entry, Save → back to list

**Edit Stimulant Screen** — same layout as Add, pre-populated. Save / Cancel.

**Preview / Confirm Screen** — shown after tapping a profile
- Drink name + mg being added
- New "in system" estimate after this dose
- New daily total
- Updated "Below Sleep Threshold" time
- Warning banner if Oops threshold or daily limit would be exceeded
- [Log It] button → logs with current timestamp → back to Main
- [Adjust Time] → Backdate Screen (then returns here with recalculated preview)
- Swipe DOWN → cancel, back to Log Stimulant

**Backdate Screen** — "How long ago?"
- Options: Just now / 15 min / 30 min / 1 hr / 2 hrs / Custom
- Tap → return to Preview with adjusted timestamp

**History Screen** — 30-day list, most recent first
- One row per day: date, total mg, dose count
- Tap a day → Day Detail Screen
- Swipe DOWN → Main

**Day Detail Screen** — read-only dose log for selected day
- Each entry: stimulant name, time logged, mg
- Swipe DOWN → History

**Oops Screen** — triggered from Oops button on Main
- Shows current in-system estimate (snapshot)
- "Set this as your warning threshold?"
- Confirm → saves threshold → Main
- Cancel → Main

**Settings Screen** — scrollable
- Daily limit (auto from weight, overridable)
- Half-life (default 5.0 hrs)
- Sleep threshold mg (default 100mg)
- Bedtime (pre-populated from Garmin profile, adjustable)
- Oops threshold (current value or "Not set")
- Reset today's log (destructive, requires confirmation)

### Navigation Map

```
GLANCE
  └─ tap ──────────────────────────────────────────► Main

Main
  ├─ swipe UP  ────────────────────────────────────► Log Stimulant
  ├─ swipe DOWN ───────────────────────────────────► History
  ├─ menu button ──────────────────────────────────► Settings
  └─ tap Oops ─────────────────────────────────────► Oops Screen
       └─ confirm/cancel ───────────────────────────► Main

Log Stimulant
  ├─ tap profile ──────────────────────────────────► Preview/Confirm
  │    ├─ tap [Log It] ────────────────────────────► Main
  │    ├─ tap [Adjust Time] ──────────────────────► Backdate
  │    │    └─ tap option ──────────────────────────► Preview/Confirm
  │    └─ swipe DOWN ──────────────────────────────► Log Stimulant
  ├─ long-press profile ───────────────────────────► Edit / Delete menu
  │    ├─ Edit ────────────────────────────────────► Edit Stimulant Screen
  │    │    └─ Save/Cancel ──────────────────────────► Log Stimulant
  │    └─ Delete (confirm) ───────────────────────► Log Stimulant
  └─ tap [+ Add New Stimulant] ────────────────────► Add Stimulant Screen
       └─ Save/Cancel ──────────────────────────────► Log Stimulant

History
  ├─ tap day ──────────────────────────────────────► Day Detail
  │    └─ swipe DOWN ──────────────────────────────► History
  └─ swipe DOWN ───────────────────────────────────► Main

Settings
  └─ swipe DOWN ───────────────────────────────────► Main
```

---

## 9. Data Model (Draft — Phase 1)

```
Storage keys:
  "settings"  → { limitMg, halfLifeHrs, sleepThresholdMg, bedtimeHour, bedtimeMinute,
                   bodyWeightKg, oopsThresholdMg }
  "profiles"  → Array of { id, name, caffeineMg }
  "log_YYYYMMDD" → Array of { profileId, timestampMs, caffeineMg } (one key per day)
  "log_days"  → Array of date strings stored (for enumeration / pruning)
```

Memory budget estimate (conservative):
- Settings: ~200 bytes
- 10 profiles: ~500 bytes
- 90 days × 5 events/day × 50 bytes = ~22.5KB
- Total: well within 128KB Storage limit

---

## 10. Build Notes (Pre-development)

- App type: `watch-app` (not widget, not data field)
- Glance: implement `getGlanceView()` + `(:glance)` annotations per skin_temp_widget_development_lessons.md §21
- No special permissions required for Application.Storage (confirmed in KB)
- Time handling: use `System.getClockTime()` for local time (NOT `Gregorian.moment()` which is UTC)
- Half-life formula: `remaining = dose × 0.5^(elapsedHours / halfLifeHours)`
- For multiple doses: sum of all active doses' remaining amounts

---

## 11. UI Polish Session — March 2026 (Simulator-confirmed, device testing pending)

All screens converted to `FONT_XTINY` and consistent layout conventions. Simulator builds and
navigates correctly. Pending real-device test before closing.

### Screens completed

**Preview screen** (`PreviewView.mc`)
- Caffeine line (grey) drawn first at y=42; name (white) below via `_drawWrappedName()`
- Name word-wrap: if >22 chars, split at last space at/before char 22; both lines centred 22px apart
- Warning banner at y=106
- “After this:” section base at y=141 with 30px inter-line spacing
- “Sleep safe: X” replaced with “Below Sleep Threshold: X”; “Just now” replaced with “Now”
- Log It: green `fillRoundedRectangle`, y=268, h=38
- Adjust Time: red `fillRoundedRectangle`, y=312, h=38
- Hold Back=Profile bar: circle-clipped dark grey at y=355, h=27
- `onMenu()` in `PreviewDelegate` fires on long-press back → pushes `ProfileEditView`

**Profile Edit screen** (`ProfileEditView` in `PreviewView.mc`)
- Title: green “Edit Profile”, `FONT_XTINY`
- Name tap → TextPicker; caffeine +/− with `FONT_NUMBER_MEDIUM` value
- Save (green): updates storage + refreshes `PreviewView` and `LogStimulantView` list
- Delete (dark red): confirmation dialog, pops back 3 levels to log list
- Cancel bar: full-width `#333333` at y=380 with down arrow and “Cancel” text

**Settings screen** (`SettingsView.mc`)
- All text `FONT_XTINY`; title green at y=28
- ROW_H=58, LIST_TOP=55, ROWS_VIS=6 — all 6 settings fit without scrolling
- Labels centred (CX), label at y+13, value at y+38 within each row
- Swipe UP/DOWN scrolls list only; back button is the sole exit
- Polygon scroll arrows via `ArrowUtils`
- `SettingsDelegate` receives view as constructor argument (delegate/view disconnect fixed)

**Value editor** (`ValueEditView` in `SettingsView.mc`)
- Title `FONT_XTINY` green; number `FONT_NUMBER_HOT`; +/− `FONT_NUMBER_MEDIUM`
- Save button `FONT_XTINY`, y=283; cancel bar matches Profile Edit screen
- `ValueEditDelegate` receives view as constructor argument

**Main screen footer bars** (`MainView.mc`)
- Two circle-clipped dark grey bars using `_fillCircularBar()` with arc radius 210
- Bar 1 (Settings hint): y=355, h=27, text centred at y=368
- Bar 2 (Log/History): y=384, h=27, text centred at y=397
- 2px gap between bars

**History / DayDetail / LogStimulant / EditStimulant** — completed in prior session;
  see session summary at top of this file / transcript.

### Navigation finalised

- All secondary screens: back button exits, swipes scroll within screen
- `onMenu()` = hold back button (Garmin standard for secondary long-press action)
- Settings: back exits, swipes scroll
- Preview: back exits, hold-back → Profile Edit
- Profile Edit: back cancels, Save commits

### Log entry data model note

Deleting a stimulant profile does **not** affect history. Each `logDose()` call stores a
self-contained snapshot of `{ name, caffeineMg, timestampSec }`. The `profileId` field is
stored but never used to look anything up at display time.

---

## 13. Pharmacokinetic Model — How We Calculate Caffeine In System

### The Core Equation

We use a **first-order single-compartment exponential decay** model. For a single dose of
caffeine taken at a known time, the amount remaining in the body at any later time `t` is:

```
C(t) = D × 0.5 ^ (t / t½)
```

Where:
- `C(t)` = caffeine remaining in system at time `t` (mg)
- `D`    = original dose size (mg)
- `t`    = time elapsed since dose was taken (hours)
- `t½`  = the half-life (hours, default 5.0 in StimTracker)
- `0.5` = the decay base, because after exactly one half-life exactly half remains

For **multiple doses** (the realistic case), we use the **superposition principle** — the body
processes each dose independently, so we just sum them:

```
C(t) = Σ [ Dᵢ × 0.5 ^ ((t - tᵢ) / t½) ]
```

Where `tᵢ` is when dose `i` was taken, and `t - tᵢ` is the elapsed time for that specific dose.
This is exactly what `calcCurrentMg()` does: it loops over every logged dose from today and
yesterday, computes the decayed remainder for each, and sums them.

### The Math In Plain English

Exponential decay means the drug doesn't disappear at a fixed rate of mg/hour — it disappears
at a fixed **fraction** per hour. If your half-life is 5 hours, you lose half every 5 hours.
This gives the characteristic curve where the drop is steep at first and then flattens:

```
Start:   200mg
5 hrs:   100mg  (half remains)
10 hrs:   50mg  (half of that)
15 hrs:   25mg
20 hrs:  12.5mg
```

Mathematically, `0.5^(t/t½)` is equivalent to `e^(-λt)` where `λ = ln(2) / t½ ≈ 0.1386 / t½`.
Both forms compute identical results — our code uses the `0.5^` form because it's more
intuitive when reasoning about half-lives.

The code also has a practical cutoff: doses older than 7 half-lives are ignored entirely (their
contribution would be `0.5^7 ≈ 0.78%` of original — below 1%, negligible). At a 5-hour half-life
that means doses older than 35 hours drop out of the calculation automatically.

### What We're Simplifying (and Why It's Still Good)

**Absorption delay** — In reality caffeine is not instantly in your bloodstream. After oral
ingestion, 99% is absorbed within 45 minutes, with peak plasma concentration occurring between
15 and 120 minutes after consumption depending on whether you had food, individual gastric
emptying speed, and other factors. Our model assumes **instant absorption** — the full dose is
in your system from the moment you log it. The practical consequence is that our estimate runs
*slightly high* in the first 30–60 minutes after a dose, then becomes accurate as absorption
actually catches up to the instantaneous assumption.

The academic app Caffeine Zone (Ritter & Yeh, Penn State, 2011) modelled both absorption and
elimination as separate exponentials (absorption half-life ~7 minutes), which is more correct
but significantly more complex. For a personal tracking tool where you typically log a drink
as you start consuming it, the instant-absorption assumption is a reasonable simplification —
you're asking "what have I put in the pipeline?" not "what's in my plasma right now?"

**The half-life is an average** — Published studies show a population range of 1.5 to 9.5 hours
with a mean around 4–5 hours. The two biggest individual factors:
- **Smoking** shortens half-life by 30–50% (smokers clear caffeine roughly twice as fast)
- **Oral contraceptives** roughly double the half-life (~10 hours)
- Pregnancy can push it to 11–18 hours in the third trimester
- Genetic variation in the CYP1A2 liver enzyme: ~40% of people are "fast" metabolisers (~3 hrs),
  ~45% "normal" (~5 hrs), ~15% "slow" (6–10+ hrs)

Our 5.0-hour default is the textbook mean for a healthy non-smoking adult not on oral
contraceptives. The Settings screen lets the user override this — which is the correct design
choice: the model is structurally sound, it just needs the right parameter for the individual.

**Paraxanthine is not modelled** — About 84% of caffeine is metabolised into paraxanthine, which
is itself an adenosine antagonist with similar stimulant effects and a longer half-life (~3.5–5 hrs
for paraxanthine to clear after caffeine peaks). 8–10 hours after a dose, paraxanthine levels
actually exceed caffeine levels. Our model only tracks caffeine, not its primary metabolite.
This means we *underestimate* total stimulant load at the 8–15 hour mark. This is a known
pharmacological simplification that virtually all consumer caffeine trackers make.

### Is This The Right Model? What Others Do

Academic consensus is clear: caffeine elimination follows **first-order kinetics** and is
"adequately described by a one-compartment open model" (Bonati et al., 1982 — this finding has
been replicated many times over the past 40 years). This is not disputed.

The arguments in the literature and among app developers are about *parameters* and *extensions*:

**Absorption modelling** — Higher-fidelity apps (Caffeine Zone, some clinical tools) use a
two-phase model with separate absorption and elimination exponentials. The improvement in
accuracy is real but small for practical purposes, and it adds the complication that you need
to know *when you finished* the drink rather than just logging a timestamp.

**Tolerance/adenosine upregulation** — Daily caffeine users upregulate adenosine receptors,
meaning the same plasma concentration produces less subjective effect over time. No consumer
caffeine app attempts to model this because it requires longitudinal dose history and the
pharmacodynamics are poorly characterised for individuals. StimTracker's goal is tracking load
(the objective pharmacokinetic question) rather than predicting subjective alertness (the
pharmacokinetic + pharmacodynamic question), so we're correctly out of scope here.

**Dose-nonlinearity at very high doses** — At extreme overdose levels (the literature documents
a case of ~5.9g in one sitting with an observed half-life of 27 hours rather than the normal
2–12 hours), caffeine kinetics become nonlinear. At normal recreational doses (100–600mg range)
the one-compartment linear model fits experimental data well. This is not a practical concern
for StimTracker.

**Cutoff threshold for sleep impact** — The sleep threshold is the most debated parameter.
Some sources cite 50mg as the level below which sleep architecture is measurably unaffected;
others cite 100mg; some consumer apps use 0mg ("fully eliminated"). We default to 100mg,
which is a mid-range conservative choice. The Caffeine Zone app also used an anecdotally-derived
threshold and made it user-adjustable, which is the right approach. Our Settings screen does
the same.

### Summary: Our Model's Fitness For Purpose

| Aspect | Our approach | Accuracy |
|--------|-------------|----------|
| Elimination kinetics | First-order single-compartment | Scientifically correct |
| Multi-dose superposition | Sum of independent decays | Correct |
| Absorption | Instant (no delay modelled) | Slight overestimate in first hour |
| Half-life default | 5.0 hrs | Good population average |
| Half-life personalisation | User-configurable | Correct approach |
| Paraxanthine metabolite | Not modelled | Known underestimate at 8–15h mark |
| Tolerance | Not modelled | Out of scope for load tracking |

For a personal awareness tool the model is well-suited. The main real-world error source is
the individual's actual half-life diverging from the default — a 3-hour fast metaboliser will
see our estimates read consistently high throughout the day, and vice versa. The "Oops"
threshold feature partially compensates for this: by logging a side-effect event, the user
calibrates the threshold to their actual response, regardless of what the underlying kinetics are.

---

## 12. Knowledge Base Additions

### Already Added to KB

> All entries below have been promoted to `stimtracker_development_lessons.md`.
> They are retained here for reference only.

### PK-1 — Delegate/view disconnect pattern (CRITICAL)

**Problem:** When `pushView(new MyView(), new MyDelegate(), ...)` is called with the delegate
creating its own private view internally, `onUpdate()` fires on the pushed view but all delegate
methods that call view functions operate on the delegate’s private copy. Visual updates never
appear; swipe-triggered scrolls and data changes silently affect an invisible ghost object.

**Fix:** Always create the view first, pass it to both `pushView()` and the delegate constructor.

```monkeyc
// CORRECT
var myView = new MyView(data);
WatchUi.pushView(myView, new MyDelegate(myView, data), WatchUi.SLIDE_UP);

// BROKEN — delegate’s internal new MyView() is a ghost
WatchUi.pushView(new MyView(data), new MyDelegate(data), WatchUi.SLIDE_UP);
```

Affected in StimTracker: HistoryDelegate, LogStimulantDelegate, EditStimulantDelegate,
PreviewDelegate, SettingsDelegate, ValueEditDelegate, BackdateDelegate, ProfileEditDelegate.
All fixed by passing the view as the first constructor argument.

### PK-2 — Local variable type annotations cause build error

`var line1 as String;` inside a function body is rejected by the Venu 3 compiler:
> ERROR: Invalid explicit typing of a local variable. Local variable types are inferred.

Monkey C infers local variable types — only member variables (class-level) can have explicit
`as Type` annotations. Remove the annotation from local declarations:

```monkeyc
// BROKEN
var line1 as String;
var line2 as String;

// CORRECT
var line1;
var line2;
```

This is already documented in the KB under `monkey_c_lessons.md` — confirm same entry applies
and cross-reference if needed.

### PK-3 — `onMenu()` fires on long-press of the back button

`BehaviorDelegate.onMenu()` is triggered by a long-press of the physical back/menu button on
Venu 3 (and other Garmin devices). This can be used as a “hold back = secondary action”
pattern with a labelled hint bar at the bottom of the screen. The short back press still fires
`onBack()` / `onPreviousPage()` as normal. Both can coexist in the same delegate.

```monkeyc
function onBack() as Boolean {
    WatchUi.popView(WatchUi.SLIDE_RIGHT); // short press
    return true;
}
function onMenu() as Boolean {
    WatchUi.pushView(new SecondaryView(), ...); // long press
    return true;
}
```

**Needs device confirmation** — simulator may not distinguish short vs long press reliably.

### PK-4 — Circle-clipped horizontal bar technique

To draw a dark background bar that respects the circular screen boundary (radius 210 for Venu 3
arc, not the full screen radius 227), fill it row by row using the arc equation:

```monkeyc
private function _fillCircularBar(dc as Graphics.Dc, y as Number, barH as Number,
                                   color as Number) as Void {
    dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    var rSq = 210 * 210;  // arc radius, NOT CY*CY
    for (var row = y; row < y + barH; row++) {
        var dy  = row - CY;  // CY = 227
        var rem = rSq - dy * dy;
        if (rem <= 0) { continue; }
        var hw = Math.sqrt(rem.toFloat()).toNumber();
        dc.fillRectangle(CX - hw, row, hw * 2, 1);
    }
}
```

Using 227 (screen radius) instead of 210 (arc radius) draws the bar slightly wider than the
visual arc, causing it to clip against the bezel unexpectedly at the bottom of the screen.

### PK-5 — Confirmed layout constants for secondary screens (FONT_XTINY)

After iterative pixel adjustment in the simulator, these values produce clean results on
Venu 3 (454×454) with `FONT_XTINY`:

| Element | Value | Notes |
|---------|-------|-------|
| Screen safe zone | y=42 to y=412 | Inside arc boundary |
| Secondary screen title | y=28–30 | Green, centred |
| Row height (settings list) | 58px | 6 rows fit y=55 to y=403 |
| Label-to-value gap (list) | +13px / +38px | From row top |
| Inter-line spacing (data lines) | 30px | Preview screen “After this” section |
| Green action button | h=38–42px, radius=10 | `fillRoundedRectangle` |
| Cancel/hint bar | y=380, h=23 | Full-width `fillRectangle` |
| Footer circle-clipped bar | h=27 | Both main screen bars |
| Gap between stacked footer bars | 2px | |

**Note:** These are simulator-confirmed. Record device-confirmed values separately after testing.

### PK-6 — Word-wrap helper for long names (no SDK wrapping support)

Monkey C `drawText()` does not wrap text automatically. To word-wrap at a character boundary
without splitting words:

```monkeyc
private function _drawWrappedName(dc as Graphics.Dc, name as String, y as Number) as Void {
    if (name.length() <= 22) {
        dc.drawText(CX, y, Graphics.FONT_XTINY, name,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    } else {
        var splitPos = 22;
        // Walk back to last space at or before position 22
        while (splitPos > 0 && !(name.substring(splitPos, splitPos + 1).equals(" "))) {
            splitPos--;
        }
        var line1;
        var line2;
        if (splitPos == 0) {
            // No space found — hard break at char 22
            line1 = name.substring(0, 22);
            line2 = name.substring(22, name.length());
        } else {
            line1 = name.substring(0, splitPos);
            line2 = name.substring(splitPos + 1, name.length());
        }
        dc.drawText(CX, y - 11, Graphics.FONT_XTINY, line1,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(CX, y + 11, Graphics.FONT_XTINY, line2,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
```

The 22-char threshold and 11px line offset are tuned for `FONT_XTINY` on Venu 3.
Adjust for other fonts/screens.

### PK-7 — `StimTrackerStorage.deleteProfile()` does not affect log history

Each `logDose()` call stores a self-contained snapshot `{ name, caffeineMg, timestampSec,
profileId }` in the day log. The profile list is never consulted at history display time.
Deleting a profile therefore has no effect on past log entries — they display correctly forever
using the `name` and `caffeineMg` that were snapshotted at log time.

`profileId` is stored but currently unused at read-time; it exists for potential future
correlation (e.g. rename propagation, ingredient expansion).

### PK-8 — Settings delegate: swipes scroll, back button exits (not swipe)

For a scrollable settings/list screen where you want swipes to scroll rather than navigate:
- `onNextPage()` (swipe UP) → `view.scrollDown()`
- `onPreviousPage()` (swipe DOWN) → `view.scrollUp()`
- `onBack()` → `WatchUi.popView()` (the **only** exit)

Do **not** call `popView()` inside `onPreviousPage()` even when `scrollPos == 0`; that creates
an accidental navigation trigger when the user swipes down on the first item.

### PK-10 — Glance decay loop must read yesterday's log

The glance view has its own inline PK decay calculation (it cannot call `StimTrackerStorage`
methods directly due to the `(:glance)` annotation context). If that loop only reads
`"log_" + todayKey`, residual caffeine from doses taken the previous day will be silently
ignored. This causes the glance to show a lower "Now:" figure than the main app, with the
discrepancy largest first thing in the morning and narrowing to zero as yesterday's doses
fully decay (~35 hours after last yesterday dose at default 5h half-life).

Fix: compute both `_glanceTodayKey()` and `_glanceYesterdayKey()`, loop over both log keys,
add yesterday's doses to `currentMg` (decay sum) but **not** to `totalMg` (today's count).
Confirmed working on device — glance and main screen now match.

### PK-11 — Delegate hitbox bug: never store a live-mutating list in the delegate

When a delegate is constructed with a copy of a list that the view may later mutate via
`refreshProfiles()` / `refreshData()`, the delegate's copy falls out of sync. Symptoms:
- Tapping scrolled-down rows does nothing (delegate computes wrong `totalRows`)
- Long-press targets wrong profile (index lookup uses stale array)
- Rows beyond the initial visible count are unreachable

Fix: remove the list member from the delegate entirely. Add a `getProfiles()` (or equivalent)
accessor to the view and call `_view.getProfiles()` inside `onTap` / `onHold` to get the
live array at event time. The view is the single source of truth.

Also move the bounds check (`rowIdx >= totalRows`) into `rowForTapY()` on the view, so that
it is always evaluated against the live list size.

### PK-12 — Ghost-view bug: delegate must receive the displayed view, never construct its own

If a delegate constructs its own view instance internally (e.g. `_view = new HistoryView(days)`
inside `initialize()`), then `pushView` is called with a *different* view object. The displayed
view and the delegate's `_view` are two separate instances. Scroll state (`_scrollPos`) and
any other mutable state live in the delegate's phantom view, not the one on screen.

Result: `scrollDown()` / `scrollUp()` calls do nothing visible; `rowForTapY()` always
evaluates against `_scrollPos = 0`; tapping any row below the initial viewport is silently
ignored or resolves to the wrong row.

Fix: always create the view first, pass it to both `pushView` and the delegate constructor.
```monkeyc
var histView = new HistoryView(days);
WatchUi.pushView(histView, new HistoryDelegate(histView), WatchUi.SLIDE_DOWN);
```
This pattern must be used for every view/delegate pair in the app. Never let a delegate
create its own view.

### PK-13 — "Hold to edit" hint label pattern

For scrollable list screens where long-press reveals an edit action, add a dim grey hint
label between the screen title and the first list row. This communicates the gesture without
taking up a full row.

```monkeyc
// In onUpdate(), after drawing the title:
dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
dc.drawText(CX, 65, Graphics.FONT_XTINY, "Hold to edit",
    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
```

The hint sits at y=65 (LogStimulantView) or y=74 (DayDetailView). If the hint is added to an
existing screen, shift `LIST_TOP` down by ~15px to keep the first row from overlapping it.
DayDetailView: LIST_TOP moved 80 → 95 when hint was added.

---

### PK-14 — HH:MM swipe picker (BedtimeEditView template)

For editing a time stored as total minutes (e.g. bedtime), use a two-column swipe picker
rather than a raw integer editor. Swipe UP/DOWN increments/decrements the selected column;
tapping the left half selects hour, right half selects minute.

**View skeleton:**
```monkeyc
class BedtimeEditView extends WatchUi.View {
    private const CX = 227;
    private var _hourVal   as Number;  // 0–23
    private var _minVal    as Number;  // 0–59
    private var _selCol    as Number;  // 0 = hour, 1 = min

    function initialize(bedtimeMinutes as Number) {
        View.initialize();
        _hourVal = bedtimeMinutes / 60;
        _minVal  = bedtimeMinutes % 60;
        _selCol  = 0;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Title
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 30, Graphics.FONT_XTINY, "Bedtime",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Hour column (highlight if selected)
        var hourColor = (_selCol == 0) ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY;
        dc.setColor(hourColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(160, 200, Graphics.FONT_NUMBER_MEDIUM,
            _hourVal.format("%02d"),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Colon separator
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 200, Graphics.FONT_NUMBER_MEDIUM, ":",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Minute column
        var minColor = (_selCol == 1) ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY;
        dc.setColor(minColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(294, 200, Graphics.FONT_NUMBER_MEDIUM,
            _minVal.format("%02d"),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Up/down hint arrows
        ArrowUtils.drawUpArrow(dc, CX, 120, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_DK_GRAY);
        ArrowUtils.drawDownArrow(dc, CX, 280, ArrowUtils.HINT_ARROW_SIZE, Graphics.COLOR_DK_GRAY);

        // Save button
        dc.setColor(0x007700, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(107, 305, 240, 42, 10);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, 326, Graphics.FONT_XTINY, "Save",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Cancel bar
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 380, dc.getWidth(), 23);
        ArrowUtils.drawDownArrow(dc, CX - 49, 392, ArrowUtils.HINT_ARROW_SIZE,
            Graphics.COLOR_LT_GRAY);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX - 35, 392, Graphics.FONT_XTINY, "Cancel",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function getMinutes() as Number { return _hourVal * 60 + _minVal; }

    function increment() as Void {
        if (_selCol == 0) { _hourVal = (_hourVal + 1)  % 24; }
        else              { _minVal  = (_minVal  + 1)  % 60; }
        WatchUi.requestUpdate();
    }

    function decrement() as Void {
        if (_selCol == 0) { _hourVal = (_hourVal + 23) % 24; }
        else              { _minVal  = (_minVal  + 59) % 60; }
        WatchUi.requestUpdate();
    }

    function selectCol(tapX as Number) as Void {
        _selCol = (tapX < CX) ? 0 : 1;
        WatchUi.requestUpdate();
    }

    function isSaveTap(tapX as Number, tapY as Number) as Boolean {
        return tapX >= 107 && tapX <= 347 && tapY >= 305 && tapY <= 347;
    }
}
```

**Delegate skeleton:**
```monkeyc
class BedtimeEditDelegate extends WatchUi.BehaviorDelegate {
    private var _view     as BedtimeEditView;
    private var _settView as SettingsView;

    function initialize(view as BedtimeEditView, settView as SettingsView) {
        BehaviorDelegate.initialize();
        _view     = view;
        _settView = settView;
    }

    // Swipe UP = increment selected column
    function onNextPage() as Boolean {
        _view.increment();
        return true;
    }

    // Swipe DOWN = decrement selected column
    function onPreviousPage() as Boolean {
        _view.decrement();
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var tapX   = coords[0];
        var tapY   = coords[1];

        if (_view.isSaveTap(tapX, tapY)) {
            _settView._settings["bedtimeMinutes"] = _view.getMinutes();
            StimTrackerStorage.saveSettings(_settView._settings);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return true;
        }

        // Tap digit area = select column
        if (tapY >= 160 && tapY <= 260) {
            _view.selectCol(tapX);
            return true;
        }
        return false;
    }
}
```

**Key points:**
- Store bedtime as total minutes (0–1439) in settings: `bedtimeMinutes = hour*60 + min`
- `onNextPage()` / `onPreviousPage()` map to swipe UP / swipe DOWN (Venu 3 convention)
- Digit columns wrap around: hour 23→0, minute 59→0 (use modulo with offset for decrement)
- Do NOT assign `_settView` as a member of the delegate if it causes a compiler warning about
  unused variables — read the settings dict reference from the passed-in view's public field instead

---

### PK-15 — Number input widget template (±arrows + centre tap → TextPicker)

The standard pattern for editing a numeric value on a secondary screen. The number is centred;
`[-]` and `[+]` buttons flank it; tapping the number itself opens `WatchUi.TextPicker`
pre-populated with the current value so the user can type directly.

**View hit-test functions:**
```monkeyc
// All three zones share the same Y band, flush against the Save button top.
// Tune topY to be ~80–85px above saveTopY (screen-specific — see PK-16).

function isMinusTap(tapX as Number, tapY as Number) as Boolean {
    return tapX >= 20 && tapX <= 145 && tapY >= TOP_Y && tapY <= SAVE_TOP;
}

function isPlusTap(tapX as Number, tapY as Number) as Boolean {
    return tapX >= 309 && tapX <= 434 && tapY >= TOP_Y && tapY <= SAVE_TOP;
}

function isNumberTap(tapX as Number, tapY as Number) as Boolean {
    return tapX >= 145 && tapX <= 309 && tapY >= TOP_Y && tapY <= SAVE_TOP;
}
```

**Delegate onTap handling:**
```monkeyc
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
        new CaffTextPickerDelegate(_view),
        WatchUi.SLIDE_UP
    );
    return true;
}
```

**TextPicker delegate:**
```monkeyc
class CaffTextPickerDelegate extends WatchUi.TextPickerDelegate {

    private var _editView as MyEditView;  // replace with actual view type

    function initialize(editView as MyEditView) {
        TextPickerDelegate.initialize();
        _editView = editView;
    }

    function onTextEntered(text as String, changed as Boolean) as Boolean {
        var num = text.toNumber();
        if (num != null) {
            if (num < 10)   { num = 10; }    // clamp to min
            if (num > 1000) { num = 1000; }  // clamp to max
            _editView._caffMg = num;
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onCancel() as Boolean {
        return true;
    }
}
```

**Increment/decrement functions on the view:**
```monkeyc
function decrementMg() as Void {
    if (_caffMg > 10) { _caffMg -= 10; }  // step = 10, min = 10
    WatchUi.requestUpdate();
}

function incrementMg() as Void {
    if (_caffMg < 1000) { _caffMg += 10; }  // step = 10, max = 1000
    WatchUi.requestUpdate();
}
```

**Drawing the number and flanking buttons:**
```monkeyc
// Number (large, centred)
dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
dc.drawText(CX, NUMBER_Y, Graphics.FONT_NUMBER_MEDIUM, _caffMg.toString(),
    Graphics.TEXT_JUSTIFY_CENTER);

// Flanking [-] and [+] (same Y as number, to the sides)
dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
dc.drawText(110, NUMBER_Y, Graphics.FONT_NUMBER_MEDIUM, "-", Graphics.TEXT_JUSTIFY_CENTER);
dc.drawText(344, NUMBER_Y, Graphics.FONT_NUMBER_MEDIUM, "+", Graphics.TEXT_JUSTIFY_CENTER);
```

*One `CaffTextPickerDelegate` class is needed per view type (they differ only in the
view type annotation). Consider a common naming convention: `[ScreenName]CaffTextPickerDelegate`.)*

---

### PK-16 — Hitbox alignment for numeric input widgets

The hit zones for `[-]`, number, and `[+]` must be calibrated per screen because the number
glyph height and its Y position differ. The governing rules arrived at through device testing:

**Bottom:** Align with the top Y of the Save button immediately below — zero gap, no overlap.
**Top:** 80–85px above the bottom (roughly covers the glyph plus comfortable tap margin).
**Horizontal:** Three equal thirds of screen width (CX=227, total width ~454):
- `[-]`: x 20–145 (left zone, minus glyph drawn at x≈110)
- Number: x 145–309 (centre zone)
- `[+]`: x 309–434 (right zone, plus glyph drawn at x≈344)

Note: for DoseEditView the `[-]` and `[+]` x-bounds are slightly different (20–165 and 289–434)
because the glyph positions are slightly different on that screen.

**Per-screen values confirmed:**

| Screen | topY | bottomY | Save top | Notes |
|--------|------|---------|----------|-------|
| ValueEditView (Settings) | 220 | 305 | 305 | |
| ProfileEditView | 198 | 283 | 283 | |
| EditStimulantView (Add Stim) | 200 | 280 | 305 | Bottom deliberately 25px above Save |
| MiscCaffeineView | 165 | 245 | 288 | Bottom 43px above Preview button |
| DoseEditView (History) | 255 | 323 | 323 | Different x-bounds — see above |

**Do not** extend hitbox tops up to the label area above the number ("Caffeine (mg):", etc.) —
that creates a zone that is 150–200px tall which far exceeds the visible glyph, confuses users,
and risks accidental increments when attempting to tap other elements.

---

### PK-17 — ValueEditView title word-wrap

Settings titles for the `ValueEditView` editor (e.g. "Sleep Threshold", "Half-Life (hrs)")
may exceed 16 characters. Monkey C does not wrap `drawText()` automatically. Split the title
at the space nearest to the midpoint and draw two lines:

```monkeyc
private function _drawTitle(dc as Graphics.Dc) as Void {
    if (_title.length() <= 16) {
        dc.drawText(CX, 46, Graphics.FONT_XTINY, _title,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    } else {
        // Split at space nearest midpoint
        var mid  = _title.length() / 2;
        var best = -1;
        var dist = 999;
        for (var i = 0; i < _title.length(); i++) {
            if (_title.substring(i, i + 1).equals(" ")) {
                var d = (i - mid).abs();
                if (d < dist) { dist = d; best = i; }
            }
        }
        if (best < 0) {
            // No space — hard break at midpoint
            dc.drawText(CX, 30, Graphics.FONT_XTINY,
                _title.substring(0, mid), Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(CX, 63, Graphics.FONT_XTINY,
                _title.substring(mid, _title.length()), Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(CX, 30, Graphics.FONT_XTINY,
                _title.substring(0, best), Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(CX, 63, Graphics.FONT_XTINY,
                _title.substring(best + 1, _title.length()), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
```

Line 1 at y=30, line 2 at y=63 — these were tuned in the simulator. Single-line titles draw
at y=46 (midpoint between the two).

---

### PK-18 — Compiler warning patterns to avoid

Warnings that surfaced during StimTracker development (all treated as errors in CI):

**Unused local variable:**
```monkeyc
// BAD — triggers "unused variable" warning
var w = dc.getWidth();

// FIX — remove the assignment if the variable is never read
```

**Unused member variable (delegate/view disconnect):**
If a member variable is assigned in `initialize()` but never read in any method, the analyser
will warn. Common cause: refactoring a delegate to call `_view._field` instead of caching
`_field` locally, but forgetting to remove the now-dead member declaration.
```monkeyc
// BAD
class MyDelegate {
    private var _settings as Dictionary;  // was used; now _view._settings is called instead
    function initialize(view as MyView, settings as Dictionary) {
        _settings = settings;  // dead assignment → warning
    }
}

// FIX — remove the unused member; pass it only to the view or read it via _view
```

**Unreachable branch due to Boolean member initialised to false:**
The static analyser performs interprocedural analysis from `initialize()`. If a Boolean member
is initialised to `false` and only set to `true` via a code path the analyser considers
unreachable, the `if (_flag) { ... }` branch will be flagged as unreachable dead code.
Prefer opaque API values (e.g. `info.timerState`) over Boolean flags where possible.
Already documented in the general KB — cross-reference: `monkey_c_lessons.md`.

---

### PK-9 — Profile/delete flow: correct pop count after nested confirmation

When a confirmation dialog is presented from within a deeply-pushed screen and the user
confirms a destructive action that should return several levels, pop the dialog first
(implicit in `onResponse` return) then explicitly pop the remaining levels:

```monkeyc
// In ProfileDeleteDelegate.onResponse (after CONFIRM_YES):
// Stack at this point: Main → LogStimulant → Preview → ProfileEdit → Confirmation
WatchUi.popView(WatchUi.SLIDE_DOWN); // dismiss Confirmation
WatchUi.popView(WatchUi.SLIDE_DOWN); // dismiss ProfileEdit
WatchUi.popView(WatchUi.SLIDE_DOWN); // dismiss Preview
// Now back at LogStimulant with refreshed profile list
```

The list refresh must happen **before** the pops via the `_listView` reference passed through
the delegate chain, so the refreshed list is ready to display when the stack unwinds.

---

### Pending KB Additions

> **DO NOT add these to the KB yet.** Pending real-device test to confirm no regressions.

#### Sort Order Feature — device test required

- Sort order stored as **array position** (not a dedicated field) — reordering = remove-and-insert on the profiles array via `StimTrackerStorage.reorderProfile(fromIdx, toIdx)`.
- `ProfileEditView` accepts `sortOrder as Number` and `totalProfiles as Number` in constructor; exposes a tap-to-activate swipe widget for the sort order value.
- Sort order widget: tap anywhere in y=120–200 sets `_sortOrderSelected=true`; arrows turn green; a dark highlight box appears behind the number. Swipe UP/DOWN increments/decrements (clamped 1–totalProfiles). Both swipe handlers return `true` (consume event). Back button is the only cancel.
- `_save()` calls `reorderProfile()` first (if sort order changed), then `updateProfile()` — safe because `updateProfile` finds the profile by ID, not index.
- Callers (PreviewDelegate.onMenu, LogStimulantDelegate.onHold) search the profiles array for the matching profile ID to determine current index, then pass `idx+1` and `profiles.size()` to the constructor.
- Sort order highlight box: `fillRoundedRectangle(CX-26, 150, 52, 46, 6)` — height 46px (extended from 30px during simulator tuning).

#### FONT_NUMBER_MEDIUM/MILD Visual Offset — additional screens to verify

We confirmed `FONT_NUMBER_MEDIUM` without VCENTER places y at the bounding-box top, with the visual glyph appearing ~25px lower (y=219 → visual top y≈244, visual bottom y≈303). Manual pixel compensation has been applied throughout the app. The following screens use large number fonts without VCENTER and *may* have similar offsets — no changes made, pending visual check:

| Screen | Font | Notes |
|--------|------|-------|
| ValueEditView (Settings) | FONT_NUMBER_HOT | Different size — offset may differ |
| AdjustTimeView (time columns) | FONT_NUMBER_MILD | Multiple columns |
| MainView (large caffeine display) | FONT_NUMBER_HOT | Already visually verified? |

If any of these look misaligned on device, the fix pattern is the same: move the number y upward to compensate (do not change hitboxes).
