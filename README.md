# StimTracker

A Garmin Venu 3 watch app for tracking caffeine intake throughout the day. StimTracker uses a pharmacokinetic model to estimate how much caffeine is currently active in your system, when that level will drop below your sleep threshold, and whether your next drink would push you into warning territory — all from your wrist.

> **⚠️ Work in Progress:** StimTracker is actively developed and further features are planned. See [Future Plans](#future-plans) at the bottom of this document.

> **⚠️ Not Medical Advice:** This app is not intended to diagnose, treat, cure, or prevent any medical condition. The calculations are estimates based on population averages and published pharmacokinetic data — they are not personalised clinical assessments. If you have concerns about your caffeine consumption or its effects on your health, consult a qualified medical professional.

---

## About This Project

This app was built through **vibecoding** — a development approach where the human provides direction, intent, and testing, and an AI (in this case, Claude by Anthropic) writes all of the code. I have no formal programming background; this is an experiment in what's possible when curiosity and AI assistance meet.

Every line of Monkey C in this project was written by Claude. My role was to describe what I wanted, test each iteration on a real Garmin Venu 3, report back what worked and what didn't, and keep pushing until the result was something I was happy with.

As part of this process, I've been building a knowledge base — a growing collection of Markdown documents that capture the real-world lessons Claude and I have uncovered together: non-obvious API behaviours, compiler quirks, layout constraints specific to the Venu 3's circular display, and fixes for bugs that aren't covered anywhere in the official SDK documentation. These files are fed back into Claude at the start of each new session so the knowledge carries forward rather than being rediscovered from scratch every time.

The knowledge base is open source. If you're building Connect IQ apps for the Venu 3 and want to skip some of the trial and error, you're welcome to use it:

**[Venu 3 Claude Coding Knowledge Base](https://github.com/MJenkinsonGIT/Venu3ClaudeCodingKnowledge)**

---

## What StimTracker Does

Most caffeine tracking apps count milligrams consumed. StimTracker goes further: it tracks how much caffeine is **currently active in your body** at any given moment, using the same pharmacokinetic models that researchers use to describe how caffeine is absorbed and cleared from the body over time.

At a glance from your watch you can see:

- **How much caffeine is in your system right now** (continuously updated, accounting for absorption and decay since each dose)
- **Your total intake today** versus your personalised daily limit
- **When your caffeine will drop below your sleep threshold** — projected forward from your current load, with your bedtime used as a reference point for warnings
- **A pre-drink preview** before logging anything — showing you exactly what your numbers would look like after a given drink, including a warning if you'd exceed your daily limit or a previously recorded "Oops" threshold
- **A full 30-day consumption history**, browsable by day with individual dose details

---

## How the Caffeine Model Works

StimTracker offers three calculation modes, selectable in Settings. The default is **Instant**; **Standard** and **Precision** add a full two-phase absorption model.

---

### Instant Mode (default)

The simplest model. Each logged dose is assumed to be fully absorbed the moment it is logged. The amount remaining in the body at any later time follows first-order exponential decay:

```
C(t) = D × 0.5 ^ (t / t½)
```

Where:
- `C(t)` = caffeine remaining at time `t` (mg)
- `D`    = original dose (mg)
- `t`    = hours elapsed since the dose was logged
- `t½`  = your configured half-life (hours; default **5.0 hrs**)

For multiple doses, the total is the **sum of each dose's individual decay** — the body processes each one independently:

```
Total(t) = Σ [ Dᵢ × 0.5 ^ ((t − tᵢ) / t½) ]
```

**For drinks logged with a Start and Finish time** (recorded using the "Start Recording" flow), Instant mode uses an exact integral formula that distributes absorption evenly across the drinking window:

*While still drinking* (current time `t` is between Start and Finish):
```
Remaining = (D / T) × (t½ / ln2) × [1 − 0.5 ^ (t_elapsed / t½)]
```

*After drinking ends* (current time is after Finish):
```
Remaining = (D / T) × (t½ / ln2) × [0.5 ^ (t_from_finish / t½) − 0.5 ^ (t_from_start / t½)]
```

Where `T` = drinking duration in hours, and `t½ / ln2` is the characteristic time constant. This ensures the calculation is correct whether you check the app mid-drink or hours later.

**Doses older than 7 × half-life** (35 hours at the default setting) are automatically excluded from the calculation — their contribution is below 1% of the original dose.

---

### Standard and Precision Modes

#### The Case for a Two-Phase Model

In Instant mode, caffeine is assumed to reach full concentration the moment you log it. In reality, caffeine is absorbed through the gastrointestinal tract after ingestion. Gastric emptying — the rate at which the stomach passes its contents to the intestine — is the main bottleneck. Even on an empty stomach, peak plasma concentration typically takes 20–45 minutes for a drink and 45–90 minutes for a capsule.

Every published pharmacokinetic study on caffeine models this as a **one-compartment open model with first-order absorption and first-order elimination** (Bonati et al. 1982, replicated many times). The amount in the body at time `t` after a bolus dose follows:

```
A(t) = D × (ka / (ka − ke)) × (e^(−ke×t) − e^(−ka×t))
```

Where:
- `D`  = dose (mg)
- `ka` = absorption rate constant (h⁻¹) — how fast caffeine enters the bloodstream
- `ke` = elimination rate constant (h⁻¹) = ln(2) / t½ — how fast it clears
- `t`  = hours since the dose

This curve rises from zero to a peak at time `Tmax = ln(ka / ke) / (ka − ke)`, then falls exponentially. Instant mode only captures the falling part; Standard and Precision capture both.

> **Note on volume of distribution:** The standard pharmacokinetic equation includes a volume of distribution term (`Vd`) that converts amount to plasma concentration in mg/L. StimTracker tracks mg-in-system rather than plasma concentration, so `Vd` cancels out and does not appear in the calculation.

#### Absorption Rate Constants

The value of `ka` depends on the form of the dose (liquid or pill) and whether it was taken on an empty stomach. StimTracker uses three food states:

| Food State | What it represents |
|---|---|
| **Fasted** | First thing in the morning before eating; stomach fully empty |
| **Typical** *(default)* | 1–3 hours after a meal; the most common real-world scenario |
| **With Food** | Consumed alongside or immediately after food |

The intermediate "Typical" state is the default because most real-world caffeine consumption (a mid-morning energy drink, an afternoon coffee) happens in the 1–3 hour post-meal window — neither fully fasted nor actively digesting. Using fasted-state literature values as a default would systematically overestimate the early-phase caffeine curve for most users.

The food effect works mechanically, not chemically: food slows gastric emptying, delaying when caffeine reaches the intestinal absorptive surface. This is the primary reason fed-state absorption is slower — not stomach pH or chemical interaction with food.

The `ka` values used in the app:

| | Drink (liquid) | Pill / capsule |
|---|---|---|
| **Fasted** | 3.5 h⁻¹ | 1.75 h⁻¹ |
| **Typical** | 2.75 h⁻¹ | 1.375 h⁻¹ |
| **With Food** | 2.0 h⁻¹ | 1.0 h⁻¹ |

These are derived from the pharmacokinetic literature (Kamimori et al. 2002; Alsabri et al. 2018; Fuseau et al.). The Typical values are the average of Fasted and With Food, representing the intermediate gastric state. Drink rates reflect the lumped apparent `ka` that includes gastric emptying; capsule rates are approximately half of drink rates, consistent with the additional dissolution step.

> **On the food effect magnitude:** The Fuseau study found a ~3.5× slowdown in the extreme case of a high-fibre liquid test meal. More typical mixed meals produce a milder effect (~1.5–2×). The 1.375× reduction from Fasted to With Food used here is a conservative middle-ground estimate.

#### Corresponding Tmax Values

| | Drink (liquid) | Pill / capsule |
|---|---|---|
| **Fasted** | ~20 min | ~45 min |
| **Typical** | ~30 min | ~65 min |
| **With Food** | ~45 min | ~90 min |

#### Drinking Window Model (Standard / Precision)

When a dose is logged with a Start and Finish time using the recording flow, Standard and Precision modes use a piecewise **zero-order input** model rather than the bolus formula. Caffeine enters the gut at a constant rate `R = D / T` (mg/h) during the drinking window `T`, while absorption and elimination proceed simultaneously throughout.

*During the drinking window* (`0 ≤ t ≤ T`):
```
A(t) = (R / ke) × (1 − e^(−ke×t))
     − R / (ka − ke) × (e^(−ke×t) − e^(−ka×t))
```

*After the drinking window ends* (`t > T`):

The state at `t = T` is calculated first:
```
A_gut(T) = (R / ka) × (1 − e^(−ka×T))
A_body(T) = [formula above evaluated at t = T]
```

Then standard two-phase decay from those initial conditions:
```
A(t) = A_body(T) × e^(−ke×(t−T))
     + A_gut(T) × (ka / (ka − ke)) × (e^(−ke×(t−T)} − e^(−ka×(t−T)))
```

Pills always use the bolus formula regardless of any recorded window — the dissolution time is already incorporated into the lower `ka` value.

> **Why drinking speed usually doesn't matter:** White et al. (2016) found no statistically significant difference in Tmax, AUC, or absorption time between drinking 160 mg of caffeine in 2 minutes versus 20 minutes in fasted subjects. The mechanistic reason is that gastric emptying (30–60 min fasted) dominates the timeline — the stomach acts as a mixing buffer that erases the drinking-rate difference when the window is shorter than gastric emptying time. The window model becomes meaningful for longer sipping sessions (60–90 min+) where caffeine is continuously entering the stomach at a rate comparable to how fast it is being emptied.

#### Guard Against Numerical Instability

When `ka` and `ke` are very close in value (difference < 0.001 h⁻¹), the `(ka − ke)` denominator approaches zero. In this edge case the app falls back to simple exponential decay:
```
A(t) = D × 0.5 ^ (t × ke / ln2)
```

This situation does not arise at any of the configured `ka` values or at any realistic half-life setting.

#### Standard vs. Precision Mode

| | Standard | Precision |
|---|---|---|
| **Dose Form** (Drink/Pill) | Per profile — set via the gear icon on profile edit screens | Per profile — same |
| **Food State** | One global setting (applies to every dose) | Per dose — set at log time |

**Standard mode** is suitable for users whose consumption habits are consistent — for example, always drinking caffeine with breakfast, or always on an empty stomach. Set the global Absorption Profile once in Settings and forget it.

**Precision mode** adds a Food State selector to the Dose Options screen every time you log. The selector resets to "Typical" after each dose, so you only need to change it when your circumstances differ from the norm.

---

### Sleep Threshold Calculation

The app calculates the earliest future moment when your total caffeine load will drop below your configured **sleep threshold** (default: 100 mg). It accounts for doses that are still being absorbed — not just those already decaying — by first finding the combined curve's peak.

**Step 1 — Find the peak** using a bisection algorithm. The combined curve of all logged doses (including any active recording, using your Drink Time Estimate as the projected finish) is searched for its maximum. The peak is located to sub-second precision in ~48 function evaluations, regardless of how many doses are logged.

**Step 2 — Solve for sleep-safe time** from the peak:
```
t_safe = peak_time + t½ × log₂(peak_mg / threshold_mg)
```

This is always correct, whether the curve is currently rising or falling. Before this approach, the old formula (`t½ × log₂(current_mg / threshold_mg)`) could be off by up to 3 hours for a dose still mid-absorption — because it anchored the calculation to the instantaneous level rather than the eventual peak.

The result is displayed as **"Below Sleep Threshold: H:MMam/pm"** or **"Below Sleep Threshold: Now"** if already below. During an active recording the calculation uses your **Drink Time Estimate** as the projected finish time; if the recording runs over that estimate, the current time is used instead, causing the projected sleep time to slowly increase until you tap Finish.

---

### Daily Limit

Your daily limit defaults to a weight-based calculation using the EFSA guideline of **5.7 mg per kg of body weight**, pulled automatically from your Garmin profile. You can override this in Settings.

---

### Accuracy and Limitations

**The half-life is a population average.** Published research shows a range of roughly 1.5 to 9.5 hours across individuals. The biggest factors:
- Smoking: roughly halves half-life (~3–4 hrs for regular smokers)
- Oral contraceptives: roughly doubles half-life (~10 hrs)
- Pregnancy: can extend to 11–18 hrs in the third trimester
- Genetics (CYP1A2 enzyme): ~40% of people are fast metabolisers (~3 hrs), ~45% normal (~5 hrs), ~15% slow (6–10+ hrs)

If StimTracker consistently over- or under-estimates when you feel the effects of caffeine, try adjusting the half-life in Settings.

**Paraxanthine is not modelled.** About 84% of caffeine is metabolised into paraxanthine, which is itself an adenosine antagonist with similar stimulant effects and its own half-life (~3.5–5 hrs). At the 8–15 hour mark after a large dose, paraxanthine levels actually exceed caffeine levels. StimTracker only tracks caffeine — meaning total stimulant load is **underestimated** in the hours-later window. This is a known simplification that virtually all consumer caffeine trackers make.

**The absorption model uses population-average ka values.** Individual gastric emptying rates vary. The food state toggle captures the single most significant known variable (fasted vs. fed), but other factors (meal composition, individual motility, hydration) are not modelled.

**The preview peak is calculated assuming an instant bolus.** The Preview screen computes the projected combined peak by treating the new dose as consumed all at once right now — the "worst case" peak level, as if you chugged it immediately without adjusting timing. If you use Dose Options to spread the dose over a longer window, the actual peak will be lower and later. This is by design: the preview is intentionally conservative, and the README note under Dose Options explains how recording affects the result.

**The Oops warning on the list screen is approximate.** The red highlight on the Log Stimulant list uses your current in-system level rather than the projected peak to determine whether a dose would exceed your Oops threshold. Running the full absorption-curve peak calculation for every visible profile on every screen draw exceeds the Garmin watch's CPU time limit and causes crashes. The Preview screen always runs the precise calculation — tap any profile to get the accurate answer before logging.

---

## Screens and Navigation

### Glance View
The watch face carousel shows a two-line glance:
- **Line 1:** Current caffeine in system (mg) — labelled "Now:"
- **Line 2:** Today's total vs. your daily limit — labelled "Today:"

Tap the glance to open the full StimTracker app.

---

### Main Screen
The primary view. Shows:
- **Large centre number:** Caffeine currently in your system (mg, continuously updating)
- **Trend arrows** (↑↑ / ↑ / ↓ / ↓↓) next to the large number — shows whether your caffeine is rising, near its peak, or falling steeply
- **"Today: X / Y mg":** Your total logged today vs. your daily limit
- **"Below Sleep Threshold: H:MMam/pm"** or **"Below Sleep Threshold: Now":** Projected time when your caffeine load will drop below your configured sleep threshold. Displays yellow when a future time, green when already below. Shown at all times — even during an active recording (using Drink Time Estimate as the projected finish)
- **During a recording:** The name of the drink being recorded is shown in orange above the sleep threshold line
- **Coloured arc bar:** Visual fill of today's total vs. limit (green → orange → red as you approach and exceed the limit)
- **Gear icon** (top-right): opens Settings

**Navigation from Main:**
| Action | Result |
|--------|--------|
| Swipe UP | Log Stimulant screen |
| Swipe DOWN | History screen |
| Tap gear icon | Settings |
| Top button | Settings |
| Tap Oops button | Oops screen |

---

### Log Stimulant Screen
A scrollable list of your saved drink/product profiles, plus two special rows at the top:

- **Misc** (teal) — Quick-log any caffeine amount without saving a profile
- **Quick log, no profile** — Description row for Misc

Below that, your saved profiles are listed in your configured sort order, each showing:
- **Name** (coloured white, orange, or red — see warning colours below)
- **Caffeine amount** (mg)
- **Sort order number** — shown on the far left of the mg line

**Warning colours on profile names:**
- **White** — no threshold would be exceeded
- **Orange** — this drink would push your today total over your daily limit
- **Red** — this drink would push your current in-system level over your Oops threshold (if set)

> **Note on the red warning:** The red indicator on the list screen uses a simplified check — it compares each profile's caffeine amount against the gap between your current in-system level and your Oops threshold. This is intentionally conservative: it does not account for your absorption curve, so it may flag drinks red that would not actually breach the threshold once absorption is factored in. **Tap the profile to see the Preview screen, which runs the full calculation** and gives you the precise projected peak, sleep threshold time, and an accurate warning. The simplified check exists because the full peak-finding calculation is too computationally expensive to run for every profile on every screen draw on the watch's hardware. A future Android companion app will handle this calculation on the phone and transmit the result to the watch, enabling precise per-profile warnings on the list screen.

**Navigation from Log Stimulant:**
| Action | Result |
|--------|--------|
| Tap a profile | Preview / Confirm screen |
| Tap Misc | Misc Quick Log screen |
| Long-press a profile | Edit Profile screen |
| Tap "+ Add New Stimulant" | Add Stimulant screen |
| Swipe UP / DOWN | Scroll the list |
| Back button | Return to Main |

---

### Preview / Confirm Screen
Shown before logging any drink — gives you a full impact forecast before committing.

Displays:
- **Drink name and caffeine amount** (top)
- **Warning banner** (if this drink would exceed your daily limit or Oops threshold)
- **After this drink:**
  - **New today total (mg)** vs. your daily limit
  - **Peak: Xmg at H:MMpm** — the projected maximum combined caffeine level in your system and when it occurs. Calculated using the absorption model active in Settings, treating the new dose as an instant bolus (conservative "chug it now" estimate — see [Accuracy and Limitations](#accuracy-and-limitations))
  - **Below Sleep Threshold: H:MMpm** — when your load will drop below your sleep threshold, computed from the projected peak
- **"Log It"** button (green) — logs the drink with the current timestamp and returns to Main
- **"Dose Options"** button (red) — opens the Dose Options screen to adjust time, food state, or start a recording session before committing

**Navigation from Preview:**
| Action | Result |
|--------|--------|
| Tap "Log It" | Logs drink, returns to Main |
| Tap "Dose Options" | Dose Options screen |
| Long-press back | Edit Profile screen for this profile |
| Back button | Return to Log Stimulant (nothing logged) |

---

### Dose Options Screen
Accessed from the Preview screen. Lets you customise the timing and (in Precision mode) the food state before logging.

**Time fields:**
- **Start** and **Finish** columns, each with Hour and Minute sub-columns
- Tap a column to select it; swipe UP/DOWN to change the value

**Food State row** *(Precision mode only):*
- Cycles through **Fasted → Typical → With Food** on each tap
- Resets to Typical each time the screen is opened (per-dose setting, not persistent)
- Selecting a non-Typical food state will change the shape of the absorption curve in the calculation

**Bottom buttons:**
- **Save** — returns to Preview with the adjusted timestamp (and food state in Precision mode)
- **or**
- **Start Recording** — saves the start time and a pending dose entry; the app returns to Main while the dose is "in progress." A recording indicator is shown. Tap **Finish Recording** when you finish the drink; the finish time is captured and the full window dose is logged

---

### Misc Quick Log Screen
For one-off caffeine amounts that don't correspond to a saved profile.

- Use **−** / **+** to set the caffeine amount in 10 mg steps, or tap the number to type it directly
- **Gear icon** (top-right) / top button — opens the Misc Parameters screen to set Dose Form and Food State (Standard/Precision modes)
- Tap **"Preview"** to go to the Preview / Confirm screen
- Back or swipe down to cancel

> **💡 Typing tip:** Anywhere in StimTracker where tapping a name or number opens the on-watch keyboard, Garmin Connect will also push a text entry prompt to your phone if it is on and connected. Typing on your phone's full keyboard is often much faster.

---

### History Screen
A scrollable list of the past 30 days with log entries, most recent first. Each row shows:
- **Date**
- **Total caffeine logged that day (mg)**
- **Number of doses that day**

Tap any day to open the Day Detail screen.

**Navigation:**
| Action | Result |
|--------|--------|
| Tap a day row | Day Detail screen |
| Swipe UP / DOWN | Scroll the list |
| Back button | Return to Main |

---

### Day Detail Screen
A list of all individual dose entries for a selected day, showing:
- **Stimulant name**
- **Time logged**
- **Caffeine amount (mg)**

Long-press any dose entry to edit it or delete it.

**Navigation:**
| Action | Result |
|--------|--------|
| Long-press a dose | Dose Edit screen |
| Swipe UP / DOWN | Scroll if needed |
| Back button | Return to History |

---

### Dose Edit Screen
Edit an individual historical dose entry. You can change:
- **Name** — tap to open a picker; scroll through saved stimulants or select Custom for keyboard entry
- **Time** — tap to select, then swipe to adjust the logged timestamp
- **Caffeine amount** — use −/+ or tap the number to type
- **Gear icon / top button** — opens Dose Parameters (Dose Form and Food State; availability depends on absorption mode)

Tap **Save** to commit changes. Tap **Delete** to remove the dose entirely (with confirmation).

---

### Dose Parameters Screen
Accessed via the gear icon or top button from any dose editing screen (Dose Edit, Profile Edit, Add Stimulant, Misc Quick Log).

Shows two rows:
- **Dose Form** — `Drink` or `Pill`. Active (and tappable) in Standard and Precision modes; greyed out in Instant mode
- **Food State** — `Fasted`, `Typical`, or `With Food`. Active only in Precision mode; greyed out in Standard and Instant modes

Tap any active row to cycle its value in place. Changes take effect when you Save on the parent screen.

> The greyed-out rows are intentionally visible rather than hidden — they let you see what would be unlocked if you changed your absorption mode in Settings.

---

### Edit Profile Screen (Add New)
Reached by tapping "+ Add New Stimulant" from the Log Stimulant screen. Enter:
- **Name** — tap to open keyboard picker
- **Caffeine (mg)** — use −/+ or tap the number to type directly
- **Gear icon / top button** — opens Profile Parameters to set the Dose Form for this profile

Tap **Save** to add the profile to your list.

---

### Edit Profile Screen (Edit Existing)
Reached by long-pressing a profile on the Log Stimulant screen, or by long-pressing the back button from the Preview screen.

- **Name** — tap to rename
- **Sort Order** — tap to activate (arrows turn green), then swipe UP/DOWN to reposition in the list
- **Caffeine (mg)** — use −/+ or tap to type
- **Gear icon / top button** — opens Profile Parameters to set the Dose Form

Tap **Save** to commit all changes. Tap **Delete Profile** to permanently remove the profile (with confirmation — does not affect history).

> Note: Deleting a profile does **not** alter your history. Each logged dose stores its own snapshot of the name and caffeine amount at the time of logging.

---

### Settings Screen
A scrollable list of all configurable values. Tap any row to edit.

| Setting | What it does |
|---------|-------------|
| **Daily Caffeine Limit** | Your maximum daily caffeine target. Defaults to 5.7 mg/kg of your Garmin profile body weight (EFSA guideline). Affects the coloured arc and warning colours. |
| **Caffeine Half-Life** | How fast your body processes caffeine. Default: 5.0 hrs. Adjust lower if effects fade faster than the app predicts; adjust higher if effects linger. |
| **Sleep Threshold** | The in-system caffeine level at or below which you expect to sleep. Default: 100 mg. Used to calculate the "Below Sleep Threshold" time. |
| **Bedtime** | Your target bedtime (H:MMam/pm). Pre-populated from your Garmin sleep schedule if available. |
| **Oops Threshold** | Your personal "too much" level. If set, profile rows turn red when the projected post-dose in-system level would exceed this. Set via the Oops button, or adjusted manually here. |
| **Absorption Model** | `Instant` (default) / `Standard` / `Precision` — controls which pharmacokinetic model is used. See [How the Caffeine Model Works](#how-the-caffeine-model-works). |
| **Absorption Profile** | *(Standard mode only)* Global food state: `Fasted` / `Typical` / `With Food`. Sets the `ka` value applied to every dose in Standard mode. Does not appear in Instant or Precision modes. |
| **Drink Time Estimate** | *(Standard and Precision modes only)* How long you typically take to finish a drink, in minutes (default: 30). Used as the projected finish time when a recording is active, so the sleep threshold and peak calculations remain meaningful before you tap Finish. Set to 0 to treat all drinks as instant. |
| **Reset Today's Log** | Clears all log entries for today (with confirmation). Does not affect history for other days. |

---

### Oops Screen
Accessible via the Oops button (red heart with white exclamation mark) on the Main screen. Use this when you notice you've consumed too much — racing heart, jitters, trouble settling, etc.

The screen shows your current in-system caffeine estimate as a snapshot. Confirm to save this value as your personal **Oops Threshold** — future drinks that would push you past this level will be flagged red in the Log Stimulant list and with a warning banner in the Preview screen.

---

## Watch Face Complication

StimTracker publishes a **Connect IQ complication** — a data slot that compatible watch faces can display directly on the watch face without the app being open. When it works, the complication shows your current caffeine in system (with trend arrows) updating automatically in the background every 5 minutes.

### How it works

The app runs a background service that fires every 5 minutes, recalculates your current caffeine level using the same pharmacokinetic model as the main screen, and pushes the result to the complication system. Any watch face that subscribes to complication updates will receive the new value and redraw accordingly.

To use it:
1. Install StimTracker
2. Open the app once — this seeds the background update chain
3. In your watch face's complication settings, find StimTracker in the list of available complications and assign it to a slot

### Current limitation

We've run into a compatibility issue that we haven't been able to fully resolve yet. The background service fires correctly and the complication push succeeds without error — but on the watch face we've tested, the complication slot doesn't visually update between app opens. The value shown is always from the last time StimTracker was opened, not the most recent background update.

It's not yet clear whether this is a limitation of the specific watch face we tested, a subtlety in how our complication is published, or something else entirely. We need to test against a watch face that we know implements the complication subscription API correctly before we can say for certain what's happening. That testing is on our to-do list — it will likely involve building a dedicated StimTracker watch face.

In the meantime, the complication does display the correct value when you open StimTracker (the foreground push always works), so if you're comfortable opening the app before checking the complication, it will be accurate at that moment.

---

## Installation

### Which file should I download?

Each release includes three files. All three contain the same app — the difference is how they were compiled:

| File | Size | Best for |
|------|------|----------|
| `StimTracker-release.prg` | Smallest | Most users — just install and run |
| `StimTracker-debug.prg` | ~4× larger | Troubleshooting crashes — includes debug symbols |
| `StimTracker.iq` | Small (7-zip archive) | Developers / advanced users |

**Release `.prg`** is a fully optimised build with debug symbols and logging stripped out. This is what you want if you just want to use the app.

**Debug `.prg` + `.prg.debug.xml`** — these two files must be kept together. If the app crashes, the watch writes a log to `GARMIN\APPS\LOGS\CIQ_LOG.YAML` — cross-referencing that log against the `.prg.debug.xml` tells you exactly which line of code caused the crash.

**`.iq` file** is a 7-zip archive containing the release `.prg` plus metadata. You can extract the `.prg` from it by renaming it to `.7z` and extracting.

---

**Option A — direct `.prg` download (simplest)**
1. Download `StimTracker-release.prg` from the [Releases](#) section
2. Connect your Venu 3 via USB
3. Copy the `.prg` to `GARMIN\APPS\` on the watch
4. Press the **Back button** on the watch — it will show "Verifying Apps"
5. Unplug once the watch finishes
6. Find StimTracker in your **Apps** list on the watch

> **To uninstall:** Use Garmin Express. Sideloaded apps cannot be removed directly from the watch or the Garmin Connect phone app.

---

## Device Compatibility

Built and tested on: **Garmin Venu 3**
SDK Version: **8.4.1 / API Level 5.2**

Compatibility with other devices has not been tested.

---

## Disclaimers

**Not medical advice.** StimTracker is a personal tracking tool, not a medical device. The caffeine estimates it produces are based on published population-average pharmacokinetic data and are not personalised clinical measurements. Individual responses to caffeine vary widely based on genetics, health status, medications, pregnancy, and other factors. Do not use this app to make medical decisions. If you have any concerns about your caffeine intake or its effects on your health, consult a qualified medical professional.

**Estimates, not measurements.** The app does not measure caffeine in your body. It calculates an *estimate* based on what you've logged, when you logged it, and your configured settings. If you forget to log a drink, log it with the wrong time, or have a metabolism that differs significantly from the defaults, the estimates will be off accordingly.

**Caffeine content accuracy.** The caffeine amounts in your profiles are only as accurate as the values you enter. Caffeine content can vary between batches, preparation methods, and serving sizes.

**The sleep threshold is a guideline.** The "Below Sleep Threshold" time is a projection based on when your modelled caffeine load drops below a configurable threshold. Being above the threshold does not mean sleep is impossible, and being below it does not guarantee good sleep. Sleep is affected by many factors beyond caffeine.

---

## Future Plans

**Graphs and trends** — Visualising your caffeine load curve over the course of a day, or your daily totals over weeks.

**Tracking additional ingredients** — L-Theanine, Taurine, Niacin (B3), Vitamin B6, B12, L-Tyrosine, and other active compounds found in energy drinks and supplements.

**Sleep threshold calibration** — A method for recording how much caffeine was estimated to be in your system when you actually fell asleep, to help you find your real sleep threshold rather than guessing.

**Heart rate monitoring** — Looking at resting heart rate changes after consumption to spot patterns or correlate heart rate elevation with in-system caffeine estimates.

**"Wean off" mode** — A guided reduction plan that helps you step down your daily caffeine intake gradually.

**Paraxanthine tracking** — Modelling the primary caffeine metabolite, which accounts for the 8–15 hour stimulant tail that pure caffeine tracking misses.

**A companion Android app** — For richer history views, long-term trend analysis beyond the 30-day on-device window, data export, and a more convenient interface for managing profiles and settings. The companion app will also take over computationally expensive calculations that exceed the watch CPU's limits — most notably, computing precise per-profile Oops threshold warnings for the Log Stimulant list. The phone will run the full absorption-curve peak calculation for each profile, then transmit the results to the watch as a simple lookup table, enabling accurate warnings without any heavy math on the watch side.

---

## Licence

MIT — see [LICENSE] for full terms. Note that all Monkey C code in this project was written by Claude (Anthropic). The licence reflects this authorship.
