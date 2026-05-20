# Mage Frost Implementation Checklist

**Job:** 010_Mage_Frost.md  
**Status:** completed  
**Created:** 2026-05-19  
**Last Updated:** 2026-05-19

---

## Research.md Requirements vs Implementation

### Single-Target Priority

| Requirement | Research.md | Status | Evidence |
|---|---|---|---|
| Icy Veins with trinkets/burn windows | Line 12 | **PRESENT** | `icy_veins_matches` at priority 6 |
| Water Elemental when talented/up | Line 14 | **PRESENT** | `water_elemental_matches` at priority 7 |
| Frostbolt as filler | Line 15 | **PRESENT** | `frostbolt_matches` at priority 30 (bottom of damage) |
| Cold Snap resets | Line 16 | **PRESENT** | `cold_snap_wrapper` at priority 5 |
| Mana Gem / Evocation | Line 17 | **PRESENT** | `evocation_matches`, `mana_gem_matches_fn` |

### Multi-Target / AoE

| Requirement | Research.md | Status | Evidence |
|---|---|---|---|
| Blizzard for ranged stacked AoE | Line 20 | **PRESENT** | `blizzard_matches` at priority 20, enemy_count >= 3 |
| Cone of Cold / Frost Nova | Line 21 | **PRESENT** | `cone_of_cold_wrapper`, `frost_nova_wrapper` |
| Arcane Explosion for close stacked | Line 21 | **PRESENT** | Added `arcane_explosion_matches` at priority 19 |
| Maintain control, don't break CC | Line 22 | **PRESENT** | `cc_safe` checked via `action_matches` gates |

### PvP / Utility

| Requirement | Research.md | Status | Evidence |
|---|---|---|---|
| Frost Nova, Cone of Cold | Line 26 | **PRESENT** | Position 18, 17 respectively |
| Ice Barrier, Ice Block | Line 26 | **PRESENT** | `ice_barrier_matches`, `ice_block_wrapper` |
| Counterspell | Line 26 | **PRESENT** | `counterspell_matches` |
| Polymorph | Line 26 | **PRESENT** | `polymorph_matches` |
| Shatter combos (Frostbite) | Line 27 | **PRESENT** | `frostbite_fb_matches` at priority 8 |
| Remove Curse | Line 111 | **PRESENT** | Middleware handles `auto_remove_curse` |

### State Tracking

| State Input | Research.md | Status | Evidence |
|---|---|---|---|
| `frostbite_active` | Line 168 | **PRESENT** | Tracked via `NS.debuff_up(target, FROSTBITE_DEBUFF)` |
| `winter_chill_stacks` | Line 228 | **PRESENT** | Tracked via `NS.debuff_stacks`; refresh at <3s |
| `ice_barrier_remains` | Line 167 | **PRESENT** | Tracked via `NS.buff_remains`; refresh at <5s |
| `mana_pct` | Line 170 | **PRESENT** | Tracked in state; Evocation at <30% |

### Forbidden Mechanics Check

| Forbidden | Status | Evidence |
|---|---|---|
| Brain Freeze [44549] | **ABSENT** | Not referenced in code |
| Deep Freeze | **ABSENT** | Not referenced |
| Frostfire Bolt | **ABSENT** | Not referenced |
| Fingers of Frost | **ABSENT** | Not referenced |

---

## Patches Applied

| Patch | File | Details |
|---|---|---|
| Added `ArcaneExplosion` spell definition | `class_sylvanas.lua` | IDs: 27082, 27080, 10202, 10201, 8439, 8438, 8437, 1449 (from Job 009, shared) |
| Added `arcane_explosion_matches` strategy | `frost_sylvanas.lua` | Instant AoE for 3+ enemies; inserted before Blizzard per Research AoE priority |

---

## Validation

- `luac -p frost_sylvanas.lua` - **PASS**
- `luac -p class_sylvanas.lua` - **PASS** (no new changes this job; ArcaneExplosion added in Job 009)
- `luac -p schema_sylvanas.lua` - **PASS** (no changes)

---

## Decision: COMPLETED

All vetted Research.md requirements are present or intentionally configurable. [VERIFY] items remain as configurable settings per AGENT_RUNNER.md rules.

### Remaining Risk

None identified.

---

## [VERIFY] Rows

| Research Row | Status | Decision |
|---|---|---|
| Water Elemental placement at max range | Keep configurable | Requires game client positioning API; not hard-coded |
| Cold Snap offensive reset timing | Keep configurable | User discretion via cooldown settings |
| Ice Barrier pre-expiry absorb tracking | Present | `ice_barrier_remains < 5s` gate handles this |
| Blink PvP defensive | Not in rotation | Mobility spell; handled by player or PvP middleware |
