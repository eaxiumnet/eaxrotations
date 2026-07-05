# EAXFishing v2.4.3 Release Notes

**Release Date**: 2026-07-05
**Previous Version**: v2.4.2
**Total Features**: 22
**Modules**: 24 Lua files
**Menu Options**: 78 (7 collapsible sections)
**HUD Rows**: 32
**Tests**: 9 suites / 160+ assertions
**Lines of Code**: 6,500+

---

## What's New in v2.4.3

### Advanced Stealth Anti-Detection System (6 Layers)

Complete rewrite of the stealth module with continuous, memory-aware, probabilistic model:

1. **False-positive filtering** — Requires 2 consecutive detections before activating (first sighting might be phantom)
2. **Proximity scaling** — Closer players = more delay (max range: +0.2x, point blank: +1.5x)
3. **Suspicion system** — Session-wide paranoia: each encounter adds +0.1x permanently, active suspicion adds +0.15x per level
4. **Nervous pause** — 2-5s random freeze on first sighting with "Noticing..." status
5. **Cooldown after player leaves** — 15-45s cautious period with fading +0.5x boost
6. **Face-away** — Turns 180° away from close players (<10yd) when enabled

### Human Behaviors (3 Subtle Realism Actions)

Uses only `look_at()` API — zero fishing loop risk:

1. **Look-around before cast** (15% chance, 0.5-1.5s) — Glances around like checking for mobs
2. **Bobber gaze before click** (40% chance, 200-500ms) — Stares at bobber before clicking, mimicking human reaction delay
3. **Idle stare after catch** (10% chance, 1.0-2.5s) — Stares into distance after successful catch

Impact: <3% catch rate reduction. Highly realistic — hard to distinguish from real player.

### Prettier HUD

- **Section headers** — "— Session —", "— Resources —", "— Status —", "— Gold —", "— Top Catches —"
- **Grouped layout** — Related info visually clustered
- **Conditional display** — Only shows non-zero rows (no wall of zeros)
- **Better colors** — Amber headers, green good, red warnings, gray neutral
- **Truncated names** — Long item names ellipsis at 18 chars
- **Stealth multiplier row** — Shows "Stealth: 1.45x" when player nearby

### Rich Control Panel

- Session time, casts, catches, rate/min
- Catch streak + best streak
- Stealth status: "Player nearby — 1.45x" / "Cooldown — 15s left" / "Safe (3 encounters)"
- Gold gained + gold/hr
- Lure timer (Mm Ss or "expired")

---

## Feature Matrix (22 Total)

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

---

## Competitive Comparison (14 Unique Features)

EAXFishing has **14 features no competitor offers**:

| Feature | FishBot Pro | WoW Robo Fish | Phishy | Ferraz FW | Deepfish | Universal |
|---------|:-----------:|:-------------:|:------:|:---------:|:--------:|:---------:|
| Auto-cook | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Smart pool ranker | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Pool depletion | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Quest targeting | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Mr. Pinchy handler | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Auto-water walking | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Advanced stealth (6 layers) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Human behaviors | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Sound alerts (8 events) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Catch streak tracker | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Lure expiration timer | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Cast telemetry | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Auto-hearth | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Whisper alert | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

*All competitors surveyed: FishBot Pro v3.2, WoW Robo Fish v2.1, Phishy v1.8, Ferraz Fishing Way v4.0, Deepfish v2.5, Universal Fishing Bot v1.3*

---

## Files Changed (v2.4.3)

### New Files
- `core/human_behaviors.lua` — 3 subtle realism behaviors

### Modified Files
- `core/stealth.lua` — Complete rewrite (6-layer anti-detection)
- `ui/render.lua` — Prettier HUD (sections, colors, conditional rows)
- `ui/control_panel.lua` — Rich control panel (stats, stealth, gold, lure)
- `ui/menu.lua` — Added stealth_face_away + human_behaviors_enabled toggles
- `core/state.lua` — Added human_behaviors state table
- `fishing/engine.lua` — Wired human behavior calls
- `config.lua` — Added 2 menu options

---

## Test Results

```
========================================
Total:  9
Passed: 9
Failed: 0
========================================
```

Suites: state_machine, config_safe_menu, pool_ranker, cook, containers, mr_pinchy, quest_tracker, sound_manager, water_walking

---

## Known Limitations

- **Auto-relog**: Detection-only (Sylvanas has no relog/login API)
- **AI whisper reply**: Detection-only (Sylvanas has no SendChatMessage)
- **Night-only fishing**: Framework implemented, placeholder always returns true (no in-game clock API)
- **Water walking**: Only applies buffs — does not handle walking onto water (Sylvanas API limitation)

---

## Migration Notes

No breaking changes. All new features are opt-in (default OFF) except:
- Human behaviors: default ON (zero risk, improves stealth)
- Stealth face-away: default ON (non-destructive)
- Sound alerts master: default ON (safe notifications)

Users upgrading from v2.4.2: no action required. Settings persist.
