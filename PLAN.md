# StimTracker — App Planning Document

> **Status:** Active development
> **Last updated:** March 2026
> **Note:** This is a working document — not the knowledge base. It contains research notes,
> decisions in progress, and future plans. Nothing here should be treated as tested or authoritative.
>
> **Implementation status summary (March 2026):**
> - §15 Absorption model: IMPLEMENTED and device-confirmed working.
> - §16 Dose parameters / gear icon pattern: IMPLEMENTED and device-confirmed.
> - §17 Testing checklist: COMPLETE — absorption model device-verified.
> - §19 Peak finder + sleep cache + preview overhaul: IMPLEMENTED and device-confirmed.
>   drinkTimeEstimateMin setting live. Preview shows Peak: Xmg at H:MMpm.
>   Main screen sleep threshold is stable and fast (cached).
> - §20 Background service / complication: SHELVED pending custom watch face.
>   Background fires correctly. updateComplication succeeds. Face It does not subscribe
>   to updates — complication only refreshes when app is opened. Plan: build a minimal
>   StimTracker watch face with subscribeToUpdates() as a future project.

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
| Great Value Energy Cherry Slush (can) | 16 fl oz | 120mg | confirmed from label |
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
- Caffeine: 120mg
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
- Gear icon (top-right) → Settings

**Log Stimulant Screen** — scrollable profile list
- Each row: stimulant name + caffeine mg
- Last row: [+ Add New Stimulant]
- Tap any profile → Preview/Confirm Screen
- Long-press any profile → Edit / Delete options

**Add Stimulant Screen** — name + caffeine mg entry, Save → back to list

**Edit Stimulant Screen** — same layout as Add, pre-populated. Save / Cancel. Gear → Profile Params.

**Preview / Confirm Screen** — shown after tapping a profile
- Drink name + mg being added
- New "in system" estimate after this dose
- New daily total
- Updated "Below Sleep Threshold" time
- Warning banner if Oops threshold or daily limit would be exceeded
- [Log It] button → logs with current timestamp → back to Main
- [Dose Options] → Dose Options Screen (timing + food state; returns here with recalculated preview)
- Swipe DOWN → cancel, back to Log Stimulant

**Dose Options Screen** (formerly "Adjust Time")
- Start/Finish time pickers
- Food state selector (Precision mode only)
- Save / Start Recording

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
- Absorption Model (Instant / Standard / Precision)
- Standard Food State (sub-setting, Standard mode only)
- Reset today's log (destructive, requires confirmation)

### Navigation Map

```
GLANCE
  └─ tap ──────────────────────────────────────────► Main

Main
  ├─ swipe UP  ────────────────────────────────────► Log Stimulant
  ├─ swipe DOWN ───────────────────────────────────► History
  ├─ tap gear icon / top button (KEY_ENTER) ───────► Settings
  └─ tap Oops ─────────────────────────────────────► Oops Screen
       └─ confirm/cancel ───────────────────────────► Main

Log Stimulant
  ├─ tap profile ──────────────────────────────────► Preview/Confirm
  │    ├─ tap [Log It] ────────────────────────────► Main
  │    ├─ tap [Dose Options] ──────────────────► Dose Options Screen
  │    │    └─ back/save ───────────────────────────► Preview/Confirm
  │    └─ swipe DOWN ──────────────────────────────► Log Stimulant
  ├─ long-press profile ───────────────────────────► Edit / Delete menu
  │    ├─ Edit ────────────────────────────────────► Edit Stimulant Screen
  │    │    ├─ Save/Cancel ───────────────────────────► Log Stimulant
  │    │    └─ gear / KEY_ENTER ───────────────────► Profile Params Screen
  │    └─ Delete (confirm) ───────────────────────► Log Stimulant
  └─ tap [+ Add New Stimulant] ────────────────────► Add Stimulant Screen
       └─ Save/Cancel ──────────────────────────────► Log Stimulant

History
  ├─ tap day ──────────────────────────────────────► Day Detail
  │    ├─ swipe DOWN ──────────────────────────────► History
  │    └─ gear / KEY_ENTER ────────────────────────► Dose Params Screen
  └─ swipe DOWN ───────────────────────────────────► Main

Settings
  └─ swipe DOWN ───────────────────────────────────► Main
```

---

## 9. Data Model (as implemented — Phase 1 + absorption model)

```
Storage keys:
  "settings"    → { limitMg, halfLifeHrs, sleepThresholdMg, bedtimeHour, bedtimeMinute,
                     bodyWeightKg, oopsThresholdMg,
                     absorptionModel,      // 0=Instant, 1=Standard, 2=Precision (default 0)
                     standardFoodState }   // 0=Fasted, 1=Typical, 2=WithFood (default 1)

  "profiles"    → Array of { id, name, caffeineMg,
                              type }       // "drink" | "pill" (default "drink" if absent)

  "log_YYYYMMDD" → Array of {
                     name,          // snapshot of profile name at log time
                     caffeineMg,    // snapshot of caffeine amount
                     profileId,     // stored but unused at display time
                     startSec,      // Unix epoch seconds (was timestampSec for instant doses)
                     finishSec,     // = startSec for instant doses; > startSec for window doses
                     type,          // "drink" | "pill" (default "drink" if absent — migration)
                     foodState }    // 0=Fasted, 1=Typical, 2=WithFood (default 1 if absent)

  "log_days"    → Array of date strings stored (for enumeration / pruning)
```

**Migration notes (old log entries):**
- `timestampSec` absent but `startSec` present → use `startSec` / `finishSec` (new format)
- `timestampSec` present, `startSec` absent → treat as instant dose: `startSec = finishSec = timestampSec`
- `type` absent → treat as `"drink"`
- `foodState` absent → treat as `1` (Typical)

Memory budget estimate (conservative):
- Settings: ~300 bytes (extended fields)
- 10 profiles: ~600 bytes (with type field)
- 90 days × 5 events/day × 80 bytes = ~36KB
- Total: well within 128KB Storage limit

---

## 10. Source File Map (as built)

```
source/
  StimTrackerApp.mc       — App + GlanceView (inline PK decay loop mirrors StimTrackerStorage)
  StimTrackerStorage.mc   — All storage I/O + PK engine (calcCurrentMg, calcAbsorbedMg, getKa)
  MainView.mc             — MainView + MainDelegate (gear icon, KEY_ENTER, Oops button)
  LogStimulantView.mc     — LogStimulantView + LogStimulantDelegate (scrollable profile list)
  EditStimulantView.mc    — EditStimulantView + Delegate (Add/Edit profile; gear → ProfileParamsView)
  PreviewView.mc          — PreviewView + Delegate (dose preview + food state button in Precision)
                            ProfileEditView + Delegate (name/caffeine/type edit, accessed via long-press)
  HistoryView.mc          — HistoryView + Delegate; DayDetailView + Delegate
  SettingsView.mc         — SettingsView + Delegate (scrollable settings including absorptionModel)
                            ValueEditView + Delegate (generic numeric editor)
                            BedtimeEditView + Delegate (HH:MM swipe picker)
  ParamsViews.mc          — DoseParamsView/Delegate, ProfileParamsView/Delegate,
                            MiscParamsView/Delegate, and shared Dose Form / Food State sub-screens
  OopsView.mc             — OopsView + Delegate
  ArrowUtils.mc           — Polygon-drawn arrow utilities (up/down arrows, hint arrows)

resources/
  drawables/
    drawables.xml         — Registers all bitmap assets
    gear_icon.png         — 56×56 gear icon (generated at 448px, downsampled with LANCZOS)
    launcher_icon.png     — App launcher icon
    oops_heart.png        — Heart icon for Oops button
    complication_icon.svg — Complication icon
    Cover Image.png       — Store cover image
  strings/
    strings.xml           — String resources
  complications/
    (complication layout files)
```

**Removed vs. original plan:** `IconUtils.mc` was planned but not created — the gear icon is a
PNG asset instead of a drawn module.

---

## 11. UI Polish Session — March 2026 (DEVICE-CONFIRMED)

All screens converted to `FONT_XTINY` and consistent layout conventions. Device-confirmed
working. Main footer bars updated: "Hold Back=Settings" bar removed; gear icon + KEY_ENTER
replaces it (see §16).

### Screens completed

**Preview screen** (`PreviewView.mc`)
- Caffeine line (grey) drawn first at y=42; name (white) below via `_drawWrappedName()`
- Name word-wrap: if >22 chars, split at last space at/before char 22; both lines centred 22px apart
- Warning banner at y=106
- "After this:" section base at y=141 with 30px inter-line spacing
- "Sleep safe: X" replaced with "Below Sleep Threshold: X"; "Just now" replaced with "Now"
- Log It: green `fillRoundedRectangle`, y=268, h=38
- Dose Options: red `fillRoundedRectangle`, y=312, h=38 (button label renamed from "Adjust Time")
- Hold Back=Profile bar: circle-clipped dark grey at y=355, h=27
- `onMenu()` in `PreviewDelegate` fires on long-press back → pushes `ProfileEditView`

**Profile Edit screen** (`ProfileEditView` in `PreviewView.mc`)
- Title: green "Edit Profile", `FONT_XTINY`
- Name tap → TextPicker; caffeine +/− with `FONT_NUMBER_MEDIUM` value
- Save (green): updates storage + refreshes `PreviewView` and `LogStimulantView` list
- Delete (dark red): confirmation dialog, pops back 3 levels to log list
- Cancel bar: full-width `#333333` at y=380 with down arrow and "Cancel" text

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
- ~~Two~~ One circle-clipped dark grey bar using `_fillCircularBar()` with arc radius 210
- ~~Bar 1 (Settings hint): y=355, h=27, text centred at y=368~~ — **REMOVED**: replaced by gear icon + KEY_ENTER (see §16)
- Bar 2 (Log/History): y=384, h=27, text centred at y=397 — **remains**
- Gear icon drawn at approximately x=395, y=100 (top-right, inside circular boundary — see §16 for safe-zone details)

**History / DayDetail / LogStimulant / EditStimulant** — completed in prior session;
  see session summary at top of this file / transcript.

### Navigation finalised

- All secondary screens: back button exits, swipes scroll within screen
- `onMenu()` = long-press of the back/ESC button (NOT the top button — see §16 and PK-3)
- **Top button (physical "MENU" label) = KEY_ENTER** — used to open params/settings screens across all views
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

**Absorption delay** — ~~In reality caffeine is not instantly in your bloodstream.~~ The original instant-absorption assumption has been superseded by the absorption model in §15. With `absorptionModel=0` (Instant, the default), the original behaviour is preserved for backwards compatibility. With Standard or Precision mode enabled, the app uses a one-compartment first-order absorption + elimination model — see §15 for full details.

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
| Absorption | Instant (mode 0) or one-compartment PK (modes 1–2) | Mode 0: slight overestimate in first hour; modes 1–2: accurate curve |
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
methods that call view functions operate on the delegate's private copy. Visual updates never
appear; swipe-triggered scrolls and data changes silently affect an invisible ghost object.

**Fix:** Always create the view first, pass it to both `pushView()` and the delegate constructor.

```monkeyc
// CORRECT
var myView = new MyView(data);
WatchUi.pushView(myView, new MyDelegate(myView, data), WatchUi.SLIDE_UP);

// BROKEN — delegate's internal new MyView() is a ghost
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

### PK-3 — `onMenu()` fires on long-press of the ESC (back) button; top button is KEY_ENTER

`BehaviorDelegate.onMenu()` is triggered by a long-press of the physical back/ESC button on
the Venu 3. The physical top button (labelled "MENU" on the hardware) fires `KEY_ENTER`, not
`KEY_MENU`. The correct handler for the top button is `onKey()` checking `WatchUi.KEY_ENTER`.

Full Venu 3 button mapping:
- Top button (labelled "MENU"): fires `KEY_ENTER` → handle with `onKey()` + `KEY_ENTER`
- Bottom short press: fires `KEY_ESC` → handled by `onBack()`
- Bottom long press: fires `KEY_MENU` → handled by `onMenu()`

**Simulator trap:** The simulator `M` keyboard shortcut fires `KEY_MENU` (long-press back). The
graphical top button in the simulator fires `KEY_ENTER`. Code checking `KEY_MENU` in `onKey()`
will appear to work when pressing `M` on keyboard, but silently fail on device and on the
graphical top button. Device-confirmed: only `KEY_ENTER` works on the physical top button.

The short and long press on the back button can coexist in the same delegate:

```monkeyc
function onBack() as Boolean {
    WatchUi.popView(WatchUi.SLIDE_RIGHT); // short press
    return true;
}
function onMenu() as Boolean {
    WatchUi.pushView(new SecondaryView(), ...); // long press back
    return true;
}
function onKey(evt as WatchUi.KeyEvent) as Boolean {
    if (evt.getKey() == WatchUi.KEY_ENTER) {
        // top button
        return true;
    }
    return false;
}
```

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
Venu 3 (454×454) with `FONT_XTINY`. Simulator-confirmed; device layout broadly consistent.

| Element | Value | Notes |
|---------|-------|-------|
| Screen safe zone | y=42 to y=412 | Inside arc boundary |
| Secondary screen title | y=28–30 | Green, centred |
| Row height (settings list) | 58px | 6 rows fit y=55 to y=403 |
| Label-to-value gap (list) | +13px / +38px | From row top |
| Inter-line spacing (data lines) | 30px | Preview screen "After this" section |
| Green action button | h=38–42px, radius=10 | `fillRoundedRectangle` |
| Cancel/hint bar | y=380, h=23 | Full-width `fillRectangle` |
| Footer circle-clipped bar | h=27 | Main screen Log/History bar |

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

**Key points:**
- Store bedtime as total minutes (0–1439) in settings: `bedtimeMinutes = hour*60 + min`
- `onNextPage()` / `onPreviousPage()` map to swipe UP / swipe DOWN (Venu 3 convention)
- Digit columns wrap around: hour 23→0, minute 59→0 (use modulo with offset for decrement)

---

### PK-15 — Number input widget template (±arrows + centre tap → TextPicker)

The standard pattern for editing a numeric value on a secondary screen. The number is centred;
`[-]` and `[+]` buttons flank it; tapping the number itself opens `WatchUi.TextPicker`
pre-populated with the current value so the user can type directly.

One `CaffTextPickerDelegate` subclass is needed per view type. Naming convention:
`[ScreenName]CaffTextPickerDelegate`.

---

### PK-16 — Hitbox alignment for numeric input widgets

The hit zones for `[-]`, number, and `[+]` must be calibrated per screen.

**Bottom:** Align with the top Y of the Save button immediately below — zero gap, no overlap.
**Top:** 80–85px above the bottom (roughly covers the glyph plus comfortable tap margin).
**Horizontal:**
- `[-]`: x 20–145 (left zone)
- Number: x 145–309 (centre zone)
- `[+]`: x 309–434 (right zone)

Note: for DoseEditView the `[-]` and `[+]` x-bounds are slightly different (20–165 and 289–434).

**Per-screen values (simulator-confirmed):**

| Screen | topY | bottomY | Save top | Notes |
|--------|------|---------|----------|-------|
| ValueEditView (Settings) | 220 | 305 | 305 | |
| ProfileEditView | 225 | 305 | 308 | KB §16 confirmed |
| EditStimulantView | 200 | 280 | 305 | Bottom 25px above Save |
| MiscCaffeineView | 165 | 245 | 288 | Bottom 43px above Preview button |
| DoseEditView (History) | 230 | 288 | 288 | Different x-bounds — see above |

---

### PK-17 — ValueEditView title word-wrap

Settings titles for the `ValueEditView` editor may exceed 16 characters. Split the title at
the space nearest to the midpoint and draw two lines. Line 1 at y=30, line 2 at y=63.
Single-line titles draw at y=46 (midpoint between the two).

---

## 18. Compiler Warning Patterns to Avoid

**Unused local variable:**
```monkeyc
// BAD — triggers warning if never read
var w = dc.getWidth();
// FIX — remove the assignment
```

**Unused member variable after refactoring:**
If a member is assigned in `initialize()` but never read (e.g. after switching to `_view._field`), the analyser warns. Remove the dead member declaration.

**Unreachable branch due to Boolean member:**
The static analyser traces from `initialize()`. If a Boolean member is initialised to `false` and only set to `true` via a path the analyser considers unreachable, the `if (_flag)` branch is flagged as dead code. Prefer opaque API values (`info.timerState`) over Boolean flags where possible. See `monkeyc_analyzer_unreachable_statement_guide.md` for full detail.

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

#### Sort Order Feature — promoted to KB §stimtracker_development_lessons.md §20

- Sort order stored as **array position** (not a dedicated field) — reordering = remove-and-insert on the profiles array via `StimTrackerStorage.reorderProfile(fromIdx, toIdx)`.
- `ProfileEditView` accepts `sortOrder as Number` and `totalProfiles as Number` in constructor; exposes a tap-to-activate swipe widget for the sort order value.
- Sort order widget: tap anywhere in y=120–200 sets `_sortOrderSelected=true`; arrows turn green; a dark highlight box appears behind the number. Swipe UP/DOWN increments/decrements (clamped 1–totalProfiles). Both swipe handlers return `true` (consume event). Back button is the only cancel.
- `_save()` calls `reorderProfile()` first (if sort order changed), then `updateProfile()` — safe because `updateProfile` finds the profile by ID, not index.
- Callers (PreviewDelegate.onMenu, LogStimulantDelegate.onHold) search the profiles array for the matching profile ID to determine current index, then pass `idx+1` and `profiles.size()` to the constructor.
- Sort order highlight box: `fillRoundedRectangle(CX-26, 150, 52, 46, 6)` — height 46px (extended from 30px during simulator tuning).

---

#### FONT_NUMBER_MEDIUM/MILD Visual Offset — promoted to KB §stimtracker_development_lessons.md §19

Device-confirmed: all screens using large number fonts without VCENTER (ProfileEditView, ValueEditView, AdjustTimeView, MainView) have correct glyph/hitbox alignment. The manual pixel compensation applied throughout the app was correct. See §19 for the full documented pattern and confirmed screen list.

---

## 14. Absorption Modelling — Research Notes

> **Status:** Research complete. Implementation complete — see §15 for implemented design and §13 for updated model description.

### 14a. What Other Apps Do

**The short answer: none of them model food state at all.**

- **Caffeine Zone 2 (Penn State, the academic gold standard)** — their own website explicitly states it "Does not take account of the many factors that influence half-life and thresholds, including, **individual differences, food intake**, age, nicotine use, and certain medications." Despite being built by pharmacokinetics researchers with ONR funding, they made a deliberate simplification decision. The app does let you enter consumption time (which shapes the curve), but treats all doses as occurring under the same absorption conditions.
- **Caffeine Clock** — models absorption rate and lets you enter how long you took to drink something. No food state parameter.
- **HiCoffee** — has "metabolism inputs" (focused on half-life/metabolizer type). No food state toggle.
- **RECaf, WaterMinder, generic trackers** — none implement food state. All use a fixed absorption curve per dose type.
- **Caffeine Tracker (rogan.software)** — explicitly lists factors its algorithm accounts for (pregnancy, other modifiers) but not food intake.

A Slashdot commenter reviewing Caffeine Zone 2 at launch observed directly: *"Just by drinking a coffee with an empty stomach, or after a big meal, changes completely the caffeine effects. It is better to rely on one's own feelings."* — this was identified as a known gap even in 2012 and has remained unaddressed by every app since.

**Implication for StimTracker:** The empty stomach toggle would be a genuine differentiator. No existing app, including the research-backed Penn State one, models this. Our plan to implement it is on firmer ground than any competitor's, and we would be the first caffeine tracker to explicitly model fasted vs. fed absorption.

---

### 14b. What the Research Shows

#### The Standard Two-Phase Model (Absorption + Elimination)

The current model treats caffeine as instantly in-system from the moment it is logged. The pharmacokinetic literature is consistent that this is a simplification. The standard model for oral caffeine (and drugs in general) is a **one-compartment model with first-order absorption and first-order elimination**, often called the "one-compartment open model with first-order input".

For a single bolus dose (instant ingestion), the plasma concentration at time `t` is:

```
C(t) = (F × D × ka) / (Vd × (ka - ke)) × (e^(-ke×t) - e^(-ka×t))
```

Where:
- `F`  = bioavailability (1.0 for caffeine — virtually complete oral absorption)
- `D`  = dose (mg)
- `ka` = absorption rate constant (h⁻¹)
- `ke` = elimination rate constant (h⁻¹) = ln(2) / half-life
- `Vd` = volume of distribution (L)
- `t`  = time elapsed since dose (hours)

Since we track caffeine in mg-in-system (not plasma concentration), and Vd cancels when we normalise, the ratio form is what matters for our purposes. We do not measure plasma concentration — we track an estimated "amount in system" which is proportional to it.

The key insight: this equation rises from zero, peaks at Tmax, then falls exponentially. The current model only has the falling exponential — it misses the rising phase.

#### Absorption Rate Constants — What the Data Say

**For liquid caffeine (energy drinks, coffee, dissolved powder):**
- Multiple sources agree: 99% absorbed within 45 minutes (Bonati et al. 1982; Liguori et al. 1997; NCBI Bookshelf NBK223808)
- Tmax typically 15–60 minutes for liquids, occasionally up to 90 minutes (Alsabri et al. 2018; MDPI Beverages 2019)
- White et al. (2016, PMC4898153): drink speed (2 min vs 20 min) did not meaningfully change pharmacokinetics
- Practical `ka` for liquids: **~3–4 h⁻¹** is the commonly cited range in controlled studies (corresponds to Tmax ~20–45 min)

**For capsules/tablets (anhydrous caffeine):**
- Tmax: 45–120 minutes (Kamimori et al. 2002; NCBI NBK223808; Alsabri 2018)
- Kamimori et al. (2002): capsule `ka` ranges **1.29–2.36 h⁻¹** (vs gum 3.21–3.96 h⁻¹)
- Practical `ka` for capsules: **~1.5–2.0 h⁻¹** is well-supported (corresponds to Tmax ~45–90 min)

#### Empty Stomach (Fasted State) Toggle

Three natural states based on gastric emptying physiology:

| Time since eating | Gastric state | App state |
|---|---|---|
| 0–1 hour | Actively digesting, stomach full | Taken with food |
| 1–3 hours | Partially emptied, returning to baseline | Default (neither toggle) |
| 3+ hours / before first meal | Essentially fasted motility | Empty stomach toggle |

The default intermediate state represents typical real-world caffeine consumption (1–3 hours after eating).

### 14c. Proposed Parameter Values for Implementation

| Parameter | Drink (liquid) | Capsule/Pill | Source |
|-----------|---------------|--------------|--------|
| `ka` (empty stomach toggle ON) | 3.5 h⁻¹ | 1.75 h⁻¹ | Kamimori 2002; Alsabri 2018 (fasted-state literature values) |
| `ka` (default — neither toggle) | 2.75 h⁻¹ | 1.375 h⁻¹ | Average of fasted and fed; represents typical 1–3h post-meal consumption |
| `ka` (taken with food toggle ON) | 2.0 h⁻¹ | 1.0 h⁻¹ | Fasted values ÷ 1.75× (Fuseau synthesis) |
| Tmax (fasted, drink) | ~20 min | ~45 min | Derived from ka |
| Tmax (default, drink) | ~30 min | ~65 min | Derived from ka |
| Tmax (with food, drink) | ~45 min | ~90 min | Derived from ka |
| Bioavailability (F) | ~1.0 | ~1.0 | NCBI NBK223808 |

**What we do NOT need:** Volume of distribution (Vd). Since we track mg-in-system (not plasma concentration), the Vd cancels in the normalised calculation.

---

## 15. Absorption Model Setting — IMPLEMENTED

> **Status:** IMPLEMENTED. Storage engine, glance mirror, settings UI, params screens, and per-dose food state selector all complete. Pending device verification of PK behaviour (see §17).
>
> **Implementation notes vs. original plan:**
> - `emptyStomach`/`withFood` dual booleans replaced with `foodState` integer enum (0/1/2) per Grok review — cleaner, no implicit "both false = Typical" rule
> - `calcAbsorbedMg()` and `getKa()` live in `StimTrackerStorage.mc`
> - Glance (StimTrackerApp.mc) mirrors the full dispatch logic inline per PK-10 pattern
> - Settings screen extended with Absorption Model row + Standard Food State sub-setting
> - All params screens live in `ParamsViews.mc` (DoseParamsView, ProfileParamsView, MiscParamsView)

### 15a. Overview

The absorption model is exposed as a user-facing setting with three modes. The setting lives in Settings alongside half-life, daily limit, etc.

| Mode | Label | What it does |
|------|-------|-------------|
| 0 | **Instant** | Current behaviour: full dose in-system at log time. No absorption curve. |
| 1 | **Standard** | One-compartment PK model with drink/pill distinction. Fixed ka at intermediate state (no per-dose food state choice). Optional global food state sub-setting. |
| 2 | **Precision** | Full model: drink/pill distinction + per-dose three-state food selector (Fasted / Typical / With Food). |

**Why "Standard" uses intermediate ka:** The intermediate (neither-fasted nor with-food) ka best represents the typical real-world case — most caffeine is consumed 1–3 hours after eating. Using fasted-state literature values as the Standard default would systematically overestimate early-phase caffeine for the majority of users.

---

### 15b. Instant Mode

Behaviour identical to current `calcCurrentMg()`. No changes to logging flow, storage, or UI. Acts as a compatibility/simplicity option.

---

### 15c. Standard Mode

**Calculation:** Uses the one-compartment oral absorption formula with:
- `ka` determined by drink/pill type
- Food state fixed globally (not per-dose) — defaults to Typical (intermediate)

**Sub-setting (appears in Settings only when Standard is active):**
`Standard Absorption Profile` — three options:
- Fasted (I usually have caffeine before eating)
- **Typical** (default — I usually have caffeine 1–3h after eating)
- With Food (I usually have caffeine with a meal)

**UI changes for Standard mode:**
- Dose Form parameter (Drink/Pill) accessible via gear icon on: ProfileEditView, EditStimulantView, MiscCaffeineView
- No food state selector during logging
- Button label: **"Dose Options"** (renamed from "Adjust Time" across all modes)

---

### 15d. Precision Mode

**Calculation:** Uses the one-compartment oral absorption formula with:
- `ka` determined by drink/pill type AND per-dose food state flag
- Food state chosen per dose at log time

**Per-dose food state selector:**
Three tappable labels: `[ Fasted ]  [ Typical ]  [ With Food ]`
- "Typical" is pre-selected by default each time the screen is opened
- Selection is per-dose; resets to Typical after each log

---

### 15e. "Dose Options" Screen (renamed from "Adjust Time")

Renamed across all modes. Precision mode adds a food state selector row between the time section and the Save/Record buttons.

---

### 15f. MiscCaffeineView Changes

- "How much caffeine?" label moved from y=90 to y=~115 (all modes)
- Drink/Pill toggle replaced by gear icon pattern (see §16i)

---

### 15g. ProfileEditView / EditStimulantView Changes

- Drink/Pill toggle replaced by gear icon pattern (see §16g)
- `profile["type"]` persisted in storage; migration default is `"drink"`

---

### 15h. DoseEditView (History) Changes

**Standard mode:** Dose Form editable. Food State not shown.
**Precision mode:** Dose Form + Food State selector both editable.
**Instant mode:** Neither shown.

Migration: `type` absent → `"drink"`; `foodState` absent → `1` (Typical).

---

### 15i. Storage Schema Changes

See §9 (Data Model) for the complete implemented schema.

**Why enum over booleans:** A single `foodState` integer is cleaner than two booleans (`emptyStomach`, `withFood`) whose combined meaning required an implicit rule (both false = Typical). The enum maps directly to the three-option UI selector. Suggested by Grok review.

---

### 15j. calcCurrentMg Dispatch

```
function calcCurrentMg(settings):
    model = settings["absorptionModel"]  // 0, 1, or 2
    ...
    for each dose in activeDoses:
        elapsed = (nowSec - dose["startSec"]) / 3600.0
        window  = (dose["finishSec"] - dose["startSec"]) / 3600.0

        if model == 0:  // Instant
            remaining += dose["caffeineMg"] * 0.5 ^ (elapsed / halfLifeHrs)

        else if model == 1:  // Standard
            foodState = settings["standardFoodState"]  // global
            ka = getKa(dose["type"], foodState)
            remaining += calcAbsorbedMg(dose["caffeineMg"], ka, ke, elapsed, window)

        else:  // Precision
            ka = getKa(dose["type"], dose["foodState"] != null ? dose["foodState"] : 1)
            remaining += calcAbsorbedMg(dose["caffeineMg"], ka, ke, elapsed, window)
```

The glance view's inline decay loop mirrors the same dispatch logic.

---

### 15k. README Update — DONE

README.md updated to describe the absorption model modes and food state options. The "safe to sleep" wording was also corrected to "Below Sleep Threshold" throughout.

---

## 16. Dose Parameters UI Pattern — IMPLEMENTED

> **Status:** IMPLEMENTED. Gear icon + params screens deployed across all four target views.
> Device-confirmed: gear visible and correctly sized, top button (KEY_ENTER) working, hitbox
> ordering correct (gear checked before name in onTap chain).
>
> **Implementation vs. plan divergences:**
> - **Gear icon is a PNG bitmap asset** (`resources/drawables/gear_icon.png`), not a drawn
>   `IconUtils.drawGear()` function. Generated at 448px, downsampled with LANCZOS to 56px.
>   `IconUtils.mc` module was planned but is not used — PNG approach is cleaner.
> - **Top button constant is `KEY_ENTER`**, not `KEY_MENU`. Physical "MENU" label on the
>   hardware is misleading. See PK-3 for full mapping.
> - **Gear safe zone:** At x=395, minimum safe y≈74 (circular bezel constraint). Initial
>   placement at y=40 was fully clipped; moved to ~y=100–108 across screens.
> - **All params screens in `ParamsViews.mc`**: DoseParamsView/Delegate, ProfileParamsView/
>   Delegate, MiscParamsView/Delegate all in one file.
> - **Hitbox ordering**: Gear hitbox must be evaluated *before* wide name/label hitboxes in
>   `onTap()` — the name hitbox extends to the bezel edge and swallows gear taps otherwise.

### 16a. Overview and Rationale

The **gear icon → parameters list** pattern is adopted uniformly across:

- **DoseEditView** (editing historical doses)
- **ProfileEditView** (editing saved stimulant profiles)
- **EditStimulantView** (adding new stimulant profiles)
- **MiscCaffeineView** (quick-log screen)

This avoids cluttering primary screens with conditional rows that appear/disappear based on settings, and provides a natural home for future additions without restructuring existing layouts.

---

### 16b. The Gear Icon — IMPLEMENTED AS PNG

The gear icon is a **PNG bitmap asset**, not a drawn `IconUtils` function. The `IconUtils.mc`
module approach was planned but the PNG gives better results (smooth edges via LANCZOS
downsampling) with less code. `gear_icon.png` is in `resources/drawables/`.

**Loading pattern in each view's `initialize()`:**
```monkeyc
_gearBmp = WatchUi.loadResource(Rez.Drawables.GearIcon) as Graphics.BitmapResource;
```

**Drawing centred on a coordinate in `onUpdate()`:**
```monkeyc
dc.drawBitmap(cx - (_gearBmp.getWidth() / 2), cy - (_gearBmp.getHeight() / 2), _gearBmp);
```

**Safe-zone check for circular display** — at x=395 (168px from centre), minimum safe y≈74.
Actual placement is ~y=100–108 across the four views. See PENDING_KB.md §1b for the formula.

The gear hitbox is a `gearButtonRegion()` accessor on the view, returning `[x1, y1, x2, y2]`.
It must be checked **first** in the `onTap()` handler before any wider hitbox.

---

### 16c. Dose Form Parameter

**Parameter label:** **"Dose Form"** | **Options:** `Drink` | `Pill`

**Which modes show this:** Standard and Precision (not Instant). Greyed out and non-interactive in Instant mode.

**Storage:** `dose["type"]` in log entries; `profile["type"]` in profile storage. Migration: absent = `"drink"`.

---

### 16d. Food State Parameter

**Parameter label:** **"Food State"** | **Options:** `Fasted` | `Typical` | `With Food`

**Which modes show this:** Precision only. Greyed out in Instant and Standard modes.

**Storage:** `dose["foodState"]` as Number (0=Fasted, 1=Typical, 2=WithFood). Migration: absent = 1 (Typical).

---

### 16e. Greyed Out vs Hidden

Parameters that depend on a mode not currently active are greyed out and non-interactive (not hidden). This makes mode-dependent settings discoverable. The gear icon itself is always visible in all modes.

---

### 16f. DoseEditView Changes — IMPLEMENTED

Gear icon placed in the gap between name area and time picker. Tapping pushes `DoseParamsView`
(in `ParamsViews.mc`). Top button (KEY_ENTER) also opens the same screen.

---

### 16g. ProfileEditView and EditStimulantView Changes — IMPLEMENTED

Gear icon placed on right side of bezel on both screens. Tapping pushes `ProfileParamsView`
(in `ParamsViews.mc`). Top button (KEY_ENTER) also opens the same screen on both views.
Profile's `type` field persisted in storage; migration default is `"drink"`.

---

### 16i. MiscCaffeineView Changes — IMPLEMENTED

Gear icon placed at approximately x=395, y=35 (top-right, same row as title). Tapping pushes
`MiscParamsView` (in `ParamsViews.mc`). Top button (KEY_ENTER) also opens the same screen.
"How much caffeine?" label moved down from y=90 to y=~115.

Per-log state (type, foodState) defaults to `"drink"` / `1` (Typical) each time
MiscCaffeineView opens. Set via MiscParamsView and passed to PreviewView at log time.

---

### 16j. Shared Sub-Screen Designs — IMPLEMENTED

Dose Form and Food State sub-screens implemented as described. Selection is immediate (no
separate Save); sub-screen pops back to the params list on tap. All sub-screens in
`ParamsViews.mc`.

---

### 16k. Future-Proofing Notes

- The params list screens are intentionally styled like SettingsView (scrollable list, label + current value per row). Once there are 4+ rows they become scrollable without any structural change.
- As Phase 2 ingredients (L-Theanine, Taurine, etc.) are added to profiles, their per-ingredient parameters (limits, half-lives) will appear in ProfileParamsView / EditStimulantView's params list.

---

## 17. Device Testing Checklist — Absorption Model

> **Status:** READY TO RUN. Implementation complete. Run these tests with the absorption model active (set absorptionModel ≠ 0 in Settings).

### 17a. Functional correctness

| Test | Expected result | Notes |
|------|----------------|-------|
| Morning fasted log (absorptionModel=1 or 2, foodState=0) | "In system" rises gradually over ~20 min rather than instant spike | Confirms ka=3.5 h⁻¹ path |
| Same dose, foodState=2 (With Food) | Rise is noticeably slower, peak later and lower | Confirms ka=2.0 h⁻¹ path |
| Pill dose (absorptionModel=1, type="pill") | Rise slower than drink; peak ~45–65 min | Confirms ka=1.375 h⁻¹ typical path |
| Long sipping session via Start Recording → End after 90 min | Peak noticeably lower and later than bolus equivalent | Confirms piecewise window model |
| Instant mode still works | Numbers identical to pre-update behaviour | Regression check |

### 17b. Glance / Main screen parity

| Test | Expected result |
|------|----------------|
| Open glance immediately after logging | Glance and main screen show same (low) in-system value — both reflect absorption curve, not instant load |
| Check glance first thing in morning | Yesterday's doses correctly contribute to current mg (PK-10 fix still intact) |

### 17c. Migration

| Test | Expected result |
|------|----------------|
| Install over existing install with logged doses | App launches without crash; old log entries load with `foodState` defaulting to 1 (Typical) |
| Numbers after 2+ hours | Nearly identical to pre-update (absorption curve has resolved; only differs in first ~1h window) |
| Old entries in DoseEditView | Dose Form and Food State show "Drink" and "Typical" respectively (migration defaults) |

### 17d. Battery / performance

| Test | Expected result |
|------|----------------|
| Run 24h with absorptionModel=2 and ~10 doses logged | Battery drain indistinguishable from Instant mode — floating-point PK math on glance update should be negligible |

### 17e. Preview UX (follow-on — do not block absorption model release)

> The instant-model preview showed a single "~Xmg in system" figure which was the current load plus the new dose. Under the absorption model this number is nearly zero at log time (nothing absorbed yet), then rises. This creates a confusing preview. The fix — showing peak time/dosage as an interim measure before a full graph is implemented — is a follow-on task and should not block the absorption model release.

Tracked separately. Do not implement during the absorption model feature.
