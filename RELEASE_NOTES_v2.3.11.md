# EaxRotations v2.3.11 — Release Notes

**Release Date:** 2026-07-04

---

## 🐛 Bug Fix: Druid Cat — Travel Form Spam

**What was happening:**
When playing Feral Cat, the rotation would rapidly flip between **Cat Form** and **Travel Form** every 2 seconds while out of combat with a distant target selected. This caused:
- Constant GCD locks and mana drain
- Unable to maintain Dash / prowl openers
- Visual stutter and gameplay disruption

**Why it happened:**
The form-switch cooldown was only **2 seconds** — too short to prevent oscillation. Once Cat Form cast, Travel Form would fire 2 seconds later (target ≥25 yards, out of combat). Then Cat Form would fire again 2 seconds after that. Repeat forever.

**What changed:**
- **Form-switch cooldown increased** from 2s → **5s** — prevents the rapid flip-flop loop
- **Travel Form is now opt-in** (`cat_auto_travel_form` setting, default **OFF**) — no surprise form changes
- **Travel Form only fires when actually moving** — stationary players stay in Cat Form
- **Cat Form respects existing Travel Form** — when running toward a distant target while in Travel Form, the rotation stays in Travel Form instead of forcing Cat Form
- **Direct stance checks added** — catches form state even when buff API is lagging

**How to enable Travel Form auto-cast (if you want it):**
Open the EaxRotations menu → Class Settings → Cat → check **"Auto Travel Form"**

---

## 🐛 Bug Fix: Shadow Priest — Mind Flay Opener (v2.3.9 follow-up)

Restored the `engaged_with_player` safety gate for Mind Flay on fresh targets. Prevents Mind Flay from firing before Shadow Word: Pain and Mind Blast on targets that haven't yet targeted the player.

---

## ✅ Quality & Reliability

- **219 rotation test suites** — all passing
- **13 leveling rotation suites** — all passing
- All changes are backward compatible. No settings reset required.

---

## 📦 Installation

1. Download `EaxRotations-v2.3.11.zip`
2. Extract to your Project Sylvanas `Scripts/` folder
3. Reload UI or restart the game

---

*Questions? Report issues at: https://github.com/eaxiumnet/eaxrotations/issues*
