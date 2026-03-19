# StimTracker

A Garmin Venu 3 watch app for tracking caffeine intake throughout the day. StimTracker uses a pharmacokinetic decay model to estimate how much caffeine is currently active in your system, when that level will drop below your sleep threshold, and whether your next drink would push you into warning territory — all from your wrist.

> **⚠️ Work in Progress:** StimTracker is actively developed and many features are planned. See [Future Plans](#future-plans) at the bottom of this document.

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

Most caffeine tracking apps count milligrams consumed. StimTracker goes further: it tracks how much caffeine is **currently active in your body** at any given moment, using the same exponential decay model that pharmacologists use to describe how caffeine clears from the body over time.

At a glance from your watch you can see:

- **How much caffeine is in your system right now** (continuously updated, accounting for decay since each dose)
- **Your total intake today** versus your personalised daily limit
- **When your caffeine will drop below your sleep threshold** — projected forward from your current load, with your bedtime used as a reference point for warnings
- **A pre-drink preview** before logging anything — showing you exactly what your numbers would look like after a given drink, including a warning if you'd exceed your daily limit or a previously recorded "Oops" threshold
- **A full 30-day consumption history**, browsable by day with individual dose details

---

## How the Caffeine Model Works

### The Core Equation

StimTracker uses a **first-order single-compartment exponential decay** model. This is the standard model used in published pharmacokinetic research for caffeine. For a single dose taken at a known time, the amount remaining in the body at any later time is:

```
C(t) = D × 0.5 ^ (t / t½)
```

Where:
- `C(t)` = caffeine remaining at time `t` (mg)
- `D`    = original dose (mg)
- `t`    = hours elapsed since the dose was taken
- `t½`  = your configured half-life (hours; default **5.0 hrs**)

### Multiple Doses

The body processes each dose independently. For multiple doses, the total caffeine in your system at any moment is the **sum of each dose's individual decay**:

```
Total = Σ [ Dᵢ × 0.5 ^ ((t - tᵢ) / t½) ]
```

This is computed fresh each time the main screen updates, looping over all logged doses from today and yesterday.

### What "In System" Means in Practice

Exponential decay means caffeine doesn't disappear at a fixed mg-per-hour rate — it disappears at a fixed *fraction* per unit time. With a 5-hour half-life:

```
Start:   200 mg
5 hrs:   100 mg  (half remains)
10 hrs:   50 mg
15 hrs:   25 mg
20 hrs:  12.5 mg
```

The curve is steep at first and flattens over time. This is why coffee at 2pm can still affect your sleep at midnight.

### Sleep Threshold Calculation

The app projects forward in time from your current caffeine load, finding the earliest future moment when the decayed total drops below your configured **sleep threshold** (default: 100 mg). The main screen displays this as **"Below Sleep Threshold: HH:MM"**, or **"Below Sleep Threshold: Now"** if you're already below it. Your **bedtime** setting is used as a reference point — screens will warn you if the threshold won't be reached before bedtime.

### Daily Limit

Your daily limit defaults to a weight-based calculation using the EFSA guideline of **5.7 mg per kg of body weight**, pulled automatically from your Garmin profile. You can override this in Settings.

### Accuracy and Limitations

The model is scientifically grounded but involves several simplifications you should be aware of:

**Absorption delay is not modelled.** In reality, caffeine takes 15–45 minutes to reach peak plasma concentration after ingestion (longer with food). StimTracker assumes the full dose is active immediately when logged. This means the "in system" estimate runs slightly high in the first 30–60 minutes after each dose, then becomes accurate as real absorption catches up. Modelling onset separately for drinks vs. capsules/pills is a planned future addition — see [Future Plans](#future-plans).

**The half-life is a population average.** Published research shows a range of roughly 1.5 to 9.5 hours across individuals. The biggest factors are:
- Smoking: roughly halves half-life (~3–4 hrs for regular smokers)
- Oral contraceptives: roughly doubles half-life (~10 hrs)
- Pregnancy: can extend to 11–18 hrs in the third trimester
- Genetics (CYP1A2 enzyme): about 40% of people are fast metabolisers (~3 hrs), 45% normal (~5 hrs), 15% slow (6–10+ hrs)

If StimTracker consistently over- or under-estimates when you feel the effects of caffeine, try adjusting the half-life in Settings to better match your personal metabolism.

**Paraxanthine is not modelled.** About 84% of caffeine is metabolised into paraxanthine, which is itself an adenosine antagonist with similar stimulant effects and its own half-life. At the 8–15 hour mark after a dose, paraxanthine levels actually exceed caffeine levels. StimTracker only tracks caffeine — meaning total stimulant load is **underestimated** in the hours-later window. This is a simplification that virtually all consumer caffeine trackers make. Paraxanthine tracking is a planned future addition — see [Future Plans](#future-plans).

**Doses older than 35 hours** (7 × default half-life) are automatically dropped from the calculation — their contribution is below 1% of the original dose and is negligible.

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
- **Large centre number:** Caffeine currently in your system (mg, continuously decaying)
- **"Today: X / Y mg":** Your total logged today vs. your daily limit
- **"Below Sleep Threshold: HH:MM"** or **"Below Sleep Threshold: Now":** Projected time when your caffeine load will drop below your configured sleep threshold. Displays yellow when a future time, green when already below.
- **Coloured arc bar:** Visual fill of today's total vs. limit (green → orange → red as you approach and exceed the limit)

**Navigation from Main:**
| Action | Result |
|--------|--------|
| Swipe UP | Log Stimulant screen |
| Swipe DOWN | History screen |
| Menu button (hold back) | Settings |

---

### Log Stimulant Screen
A scrollable list of your saved drink/product profiles, plus two special rows at the top:

- **Misc** (teal) — Quick-log any caffeine amount without saving a profile
- **Quick log, no profile** — Description row for Misc

Below that, your saved profiles are listed in your configured sort order, each showing:
- **Name** (coloured white, orange, or red — see warning colours below)
- **Caffeine amount** (mg) — centred
- **Sort order number** — shown on the far left of the mg line, so you know which number to use in the sort order field if you want to reposition an entry
- **Scroll arrows** appear when there are more rows than visible

**Warning colours on profile names:**
- **White** — no threshold would be exceeded
- **Orange** — this drink would push your *today total* over your daily limit
- **Red** — this drink would push your *in-system estimate* over your Oops threshold (your personal "too much" level, if set)

**Navigation from Log Stimulant:**
| Action | Result |
|--------|--------|
| Tap a profile | Preview / Confirm screen for that profile |
| Tap Misc | Misc Quick Log screen |
| Long-press a profile | Edit Profile screen for that profile |
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
  - New in-system estimate (mg)
  - New today total (mg)
  - Updated **"Below Sleep Threshold"** time
- **"Log It"** button (green) — logs the drink with the current timestamp and returns to Main
- **"Adjust Time"** button (red) — opens the Adjust Time screen to backdate or forward-date the log entry before committing

**Navigation from Preview:**
| Action | Result |
|--------|--------|
| Tap "Log It" | Logs drink, returns to Main |
| Tap "Adjust Time" | Adjust Time screen |
| Long-press back | Edit Profile screen for this profile |
| Back button | Return to Log Stimulant (nothing logged) |

---

### Adjust Time Screen
Lets you set a custom start time (and optionally a custom finish time) for a log entry. Useful for backdating a drink you forgot to log, or logging something you've already partially consumed.

The screen shows two time columns — **Start** and **Finish** — each with Hour and Minute sub-columns. Tap a column to select it; swipe UP/DOWN to change the selected value.

When you're done, tap **"Preview"** to return to the Preview screen with the adjusted timestamp applied to the dose calculation.

---

### Misc Quick Log Screen
For one-off caffeine amounts that don't correspond to a saved profile — a random coffee shop coffee, a medication, etc.

- Use **−** / **+** to set the caffeine amount in 10 mg steps, or tap the number to type it directly
- Tap **"Preview"** to go to the Preview / Confirm screen with this amount
- Back or swipe down to cancel (nothing is logged or saved)

> **💡 Typing tip:** Anywhere in StimTracker where tapping a name or number opens the on-watch keyboard, Garmin Connect will also push a text entry prompt to your phone if it is on and connected. Typing on your phone's full keyboard is often much faster than using the watch's character picker — especially for profile names.

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

Long-press any dose entry to edit it (name, time, caffeine amount) or delete it.

**Navigation:**
| Action | Result |
|--------|--------|
| Long-press a dose | Dose Edit screen |
| Swipe UP / DOWN | Scroll if more than a few entries |
| Back button | Return to History |

---

### Dose Edit Screen
Edit an individual historical dose entry. You can change:
- **Name** — tap to open a menu. Scroll through the configured Stimulants to select one, 	select Custom to access the keyboard picker
- **Time** — tap to seelcts and then swipe and and down to adjust the logged timestamp
- **Caffeine amount** — use −/+ or tap the number to type

Tap **Save** to commit changes. Tap **Delete** to remove the dose entirely (with confirmation).

---

### Edit Profile Screen (Add New)
Reached by tapping "+ Add New Stimulant" from the Log Stimulant screen. Enter:
- **Name** — tap to open keyboard picker
- **Caffeine (mg)** — use −/+ or tap the number to type directly

Tap **Save** to add the profile to your list.

---

### Edit Profile Screen (Edit Existing)
Reached by long-pressing a profile on the Log Stimulant screen, or by long-pressing the back button from the Preview screen.

Shows all editable fields for the selected profile:
- **Name** — tap to rename via keyboard picker
- **Sort Order** — tap to activate (arrows turn green), then swipe UP/DOWN to move the profile up or down in the list. The sort order determines the display order on the Log Stimulant screen
- **Caffeine (mg)** — use −/+ or tap the number to type directly

Tap **Save** to commit all changes (name, sort order, and caffeine). Tap **Delete Profile** to permanently remove the profile (with confirmation — does not affect history).

> Note: Deleting a profile does **not** alter your history. Each logged dose stores its own snapshot of the name and caffeine amount at the time of logging, so historical records remain accurate even if you later rename or delete a profile.

---

### Settings Screen
A scrollable list of all configurable values. Tap any row to edit.

| Setting | What it does |
|---------|-------------|
| **Daily Limit (mg)** | Your maximum daily caffeine target. Defaults to 5.7 mg/kg of your Garmin profile body weight. Affects the coloured arc and warning colours. |
| **Half-Life (hrs)** | How fast your body processes caffeine. Default: 5.0 hrs. Adjust lower if you feel effects fade faster than the app predicts; adjust higher if you're sensitive or effects linger. |
| **Sleep Threshold (mg)** | The in-system caffeine level at or below which you expect to be able to sleep. Default: 100 mg. Used to calculate the "Below Sleep Threshold" projected time. |
| **Bedtime** | Your target bedtime (HH:MM). Used together with the sleep threshold to display a warning if your caffeine won't clear in time. |
| **Oops Threshold (mg)** | Your personal "too much" level — the in-system amount at which you've previously experienced unwanted effects. If set, profile rows turn red when the projected post-dose in-system level would exceed this. Set via the Oops button on Main, or manually adjusted here. |

---

### Oops Screen
Accessible via the Oops button [Red heart with a white !] on the Main screen. Use this when you notice you've consumed too much — racing heart, jitters, trouble settling, etc.

The screen shows your current in-system caffeine estimate as a snapshot. Confirm to save this value as your personal **Oops Threshold** — future drinks that would push you past this level will be flagged red in the Log Stimulant list and with a warning banner in the Preview screen.

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

**Debug `.prg` + `.prg.debug.xml`** — these two files must be kept together. The `.prg` is the app binary; the `.prg.debug.xml` is the symbol map that translates raw crash addresses into source file names and line numbers. If the app crashes, the watch writes a log to `GARMIN\APPS\LOGS\CIQ_LOG.YAML` — cross-referencing that log against the `.prg.debug.xml` tells you exactly which line of code caused the crash.

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

**Not medical advice.** StimTracker is a personal tracking tool, not a medical device. The caffeine estimates it produces are based on published population-average pharmacokinetic data and are not personalised clinical measurements. Individual responses to caffeine vary widely based on genetics, health status, medications, pregnancy, and other factors. Do not use this app to make medical decisions. If you have any concerns about your caffeine intake or its effects on your health — including heart rate changes, sleep disruption, anxiety, or any other symptom — consult a qualified medical professional.

**Estimates, not measurements.** The app does not measure caffeine in your body. It calculates an *estimate* based on what you've logged, when you logged it, and a configurable half-life value. If you forget to log a drink, log it with the wrong time, or have a half-life that differs significantly from the default, the estimates will be off accordingly.

**Caffeine content accuracy.** The caffeine amounts in your profiles are only as accurate as the values you enter. Caffeine content can vary between batches, preparation methods, and serving sizes. The app uses whatever values you configure.

**The sleep threshold is a guideline.** The "Below Sleep Threshold" time is a projection based on when your modelled caffeine load drops below a configurable threshold. Being above the threshold does not mean sleep is impossible, and being below it does not guarantee good sleep. Sleep is affected by many factors beyond caffeine.

---

## Future Plans

StimTracker is a Phase 1 release focused entirely on caffeine. There is a lot planned. Here is a sample of what's being considered for future versions:

**Graphs and trends** — Visualising your caffeine load curve over the course of a day, or your daily totals over weeks, to help you understand your patterns at a glance.

**Tracking additional ingredients** — L-Theanine, Taurine, Niacin (B3), Vitamin B6, B12, L-Tyrosine, and other active compounds found in energy drinks and supplements. The pharmacokinetics are documented; it's a matter of expanding the data model and UI.

**Pill vs. drink onset modelling** — Currently the model assumes instant absorption. A future refinement would let you flag whether something is a capsule or a liquid, applying a more realistic absorption curve (peak at ~30–45 min for a pill vs. ~15–20 min for a drink). This would reduce the early-dose overestimate in the in-system number.

**Sleep threshold calibration** — A method for recording how much caffeine was estimated to be in your system when you actually fell asleep, building up a personal dataset to help you find your real sleep threshold rather than guessing.

**Heart rate monitoring** — Looking at resting heart rate changes after consumption to spot patterns, identify early signs of over-consumption, or correlate heart rate elevation with in-system caffeine estimates.

**"Wean off" mode** — A guided reduction plan that helps you step down your daily caffeine intake gradually over a configurable number of days or weeks, to minimise withdrawal symptoms while working toward a lower baseline.

**Paraxanthine tracking** — Modelling the primary caffeine metabolite (which accounts for the 8–15 hour stimulant tail that pure caffeine tracking misses).

**A companion Android app** — For richer history views, long-term trend analysis beyond the 30-day on-device window, data export, and a more convenient interface for managing profiles and settings.

**And more.** This is an evolving personal project. Features get added based on what proves useful in real-world daily use.

---

## Licence

MIT — see [LICENSE] for full terms. Note that all Monkey C code in this project was written by Claude (Anthropic). The licence reflects this authorship.
