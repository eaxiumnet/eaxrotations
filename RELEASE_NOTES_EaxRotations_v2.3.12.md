# EaxRotations v2.3.12 — Auto-Loot + Shadow Priest Multi-DoT Fix

**Release Date**: 2026-07-05
**Previous Version**: v2.3.11
**Total Specs**: 29 TBC Classic specializations
**Total Tests**: 219 rotation suites + 13 leveling suites (all passing)

---

## What's New

### Auto-Loot Corpses (All 9 Classes)

A brand-new background feature that automatically loots nearby corpses while your rotation runs — no manual clicking required. Available in the settings menu for **all 9 classes** (Druid, Hunter, Mage, Paladin, Priest, Rogue, Shaman, Warlock, Warrior).

**How it works:**
- While your rotation is active, the addon scans for lootable corpses within 30 yards
- When a corpse is found, it waits a brief random moment (50–200ms) before looting — just like a real player would
- After looting, it waits a moment before closing the loot window
- Only loots one corpse per check to avoid looking robotic

**Safety features:**
- **Combat aware**: Only loots when you're out of combat by default (optional "Always" mode available)
- **Post-combat grace**: Waits 2 seconds after combat ends before looting (configurable 0–5s)
- **Burst protection**: Maximum 5 corpses per 10-second window — prevents suspicious rapid-fire looting
- **Bag full protection**: Pauses automatically when you have fewer than 2 free bag slots
- **Player corpse skip**: Won't loot player corpses in battlegrounds / arenas (optional, on by default)
- **Retry guard**: Won't spam-click the same corpse — waits 500ms between attempts
- **Never blocks rotation**: Looting happens between your abilities, never interrupting casts or GCD

**How to enable:**
1. Open your rotation settings menu ("/eax" or the settings panel)
2. Look for the new **"Auto-Loot"** tab at the top
3. Check **"Auto-Loot Corpses"**
4. Adjust timing, range, and safety settings to your preference

**Self-explanatory labels:** Every setting label is written so you understand it at a glance. Hover for detailed tooltips that explain *what* the setting does, *why* it matters, and *what the default means*.

**Default settings:**
- Auto-Loot: **Off** (opt-in feature)
- Combat Mode: **Out of Combat Only**
- Post-Combat Grace: **2 seconds**
- Loot Delay: **50–200ms**
- Max Loots per 10s: **5**
- Skip Player Corpses: **On**
- Stop When Bags Full: **On**
- Min Free Slots: **2**
- Loot Range: **30 yards**

**Stats tracking:**
- Total corpses looted this session
- Last looted target name
- Bag-full pause indicator

---

## Bug Fixes

### Shadow Priest — Multi-DoT Now Spreads to Real Targets

**Problem:** In AoE / cleave situations, Shadow Word: Pain and Vampiric Touch were being recast on your current target instead of spreading to nearby enemies that didn't have the debuff. This meant your DoTs weren't actually covering multiple targets.

**Fix:** The rotation now scans nearby enemies and picks one that is missing the DoT — preferring a different target than your current one. Each spread cast is tracked per-target so the same enemy isn't double-queued.

**What to expect:** In dungeon/raid packs, your DoTs will now genuinely spread across multiple enemies instead of being wasted on the target that already has them.

---

## What to Expect

- **Auto-Loot** is completely optional and disabled by default. Turn it on if you want it.
- All existing settings carry over automatically — no reset needed.
- The feature adds zero CPU overhead when disabled.
- When enabled, it runs quietly in the background without any visual clutter.
- Compatible with all 29 specs — Warrior, Paladin, Hunter, Rogue, Priest, Shaman, Mage, Warlock, Druid.
- Drop-in replacement: delete your old `EaxRotations` folder and replace with this one.

---

## Compatibility

- **Client**: TBC Classic Anniversary (2.5.5.x)
- **Platform**: Project Sylvanas
- **Lua**: 5.1 (no external dependencies)
- **Existing specs**: No changes to rotation logic — pure addition

---

## Upgrade Notes

1. Delete your old `EaxRotations` folder
2. Copy the new `EaxRotations` folder into `scripts/`
3. Your settings are preserved automatically
4. No `/reload` or relog required

---

## Full Change List

| Category | Change |
|----------|--------|
| **Feature** | Auto-Loot Corpses (all classes, background service) |
| **Feature** | Auto-Loot settings tab with 10 configurable options (all 9 classes) |
| **Feature** | Combat-aware looting with post-combat grace period |
| **Feature** | Burst protection (max loots per 10s window) |
| **Feature** | Bag-full auto-pause with configurable threshold |
| **Feature** | Player corpse skip for PvP environments |
| **Feature** | Session stats: corpses looted, last target |
| **Bugfix** | Shadow Priest Multi-DoT now spreads to missing targets |
| **Bugfix** | DoT spread lockout prevents double-casting on same target |
| **Test** | 219 rotation suites: all passing |
| **Test** | 13 leveling suites: all passing |
| **Polish** | Self-explanatory labels + detailed tooltips on all 10 auto-loot settings |
| **Test** | Auto-loot module: 8 unit tests passing |
