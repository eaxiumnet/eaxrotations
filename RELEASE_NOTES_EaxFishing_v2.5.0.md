# EAXFishing v2.5.0 Release Notes

**Release Date**: 2026-07-05
**Previous Version**: v2.4.3
**Total Features**: 23
**Modules**: 25 Lua files
**Menu Options**: 88 (7 collapsible sections)
**HUD Rows**: 33
**Tests**: 10 suites / 170+ assertions
**Lines of Code**: 7,000+

---

## What's New in v2.5.0

### Auto-Loot Corpses

A brand-new background feature that automatically loots nearby corpses while you fish — no manual clicking required.

**How it works:**
- While fishing is active, the addon scans for lootable corpses within 30 yards
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
- **Never blocks fishing**: Looting happens between casts, never interrupting your fishing loop

**How to enable:**
1. Open the fishing menu (Control Panel)
2. Expand the **"Automation"** section
3. Check **"Auto-Loot Corpses"**
4. Adjust timing, range, and safety settings to your preference

**Menu options (10 new):**
- Auto-Loot Corpses [OFF]
- Loot Only When Safe (OOC Only / Always)
- Wait After Combat (0–5s)
- Loot Delay: Minimum (0–300ms)
- Loot Delay: Maximum (100–500ms)
- Loot Speed Limit (1–10 per 10s)
- Skip Player Corpses [ON]
- Pause If Bags Nearly Full [ON]
- Minimum Free Bag Slots (0–20)
- Scan Range (10–50 yards)

**HUD:**
- **Looted** row shows total corpses looted this session

---

## Feature Matrix (23 Total)

| # | Feature | Since | Module |
|---|---------|-------|--------|
| 1 | Auto-cast & auto-catch | v1.0 | fishing/engine |
| 2 | Auto-equip fishing pole | v1.0 | fishing/gear |
| 3 | Auto-lure | v1.0 | fishing/lures |
| 4 | Cast jitter | v2.1 | core/behavior |
| 5 | Pool tracking | v1.0 | navigation/client |
| 6 | Smart pool ranking | v2.3 | fishing/pool_ranker |
| 7 | Pool depletion detection | v2.4 | fishing/engine |
| 8 | Quest fish targeting | v2.4 | fishing/quest_tracker |
| 9 | Auto-open containers | v2.4 | fishing/containers |
| 10 | Auto-cook raw fish | v2.3 | fishing/cook |
| 11 | Mr. Pinchy handler | v2.4 | fishing/mr_pinchy |
| 12 | Auto-sell junk | v2.4 | inventory/auto_sell |
| 13 | Auto-delete worthless | v2.4 | inventory/auto_delete |
| 14 | Auto-hearth | v2.4 | navigation/hearth |
| 15 | Whisper alert | v2.4 | core/responder |
| 16 | Disconnect alert | v2.4 | core/relog |
| 17 | Sound alerts | v2.4.1 | core/sound_manager |
| 18 | Auto-water walking | v2.4.2 | fishing/water_walking |
| 19 | Advanced stealth | v2.4.3 | core/stealth |
| 20 | Human behaviors | v2.4.3 | core/human_behaviors |
| 21 | Prettier HUD | v2.4.3 | ui/render |
| 22 | Rich control panel | v2.4.3 | ui/control_panel |
| 23 | **Auto-loot corpses** | **v2.5.0** | **inventory/auto_loot** |

---

## Test Results

```
========================================
Total:  10
Passed: 10
Failed: 0
========================================
```

Suites: state_machine, config_safe_menu, pool_ranker, cook, containers, mr_pinchy, quest_tracker, sound_manager, water_walking, auto_loot

---

## Upgrade Notes

- No breaking changes. All settings persist.
- Auto-loot is **disabled by default** — opt-in only.
- Compatible with all existing features.
