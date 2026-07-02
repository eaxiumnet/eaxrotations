# Implementation Plan: CLEU Extension + LG Chain + BoK + DoT Windows

**Created:** 2026-07-02
**Goal:** Ship 5 parallel improvements in one batch. All gated by luac -p + 215 rotation + 13 leveling tests.

---

## Task A: Holy Paladin — Light's Grace Chaining

**File:** `EaxRotations/classes/paladin/holy_sylvanas.lua`
**What:** When `lights_grace_remains < 2.5s` and tank is taking damage, queue another Holy Light (even downranked) to keep the 0.5s haste buff rolling.
**Why:** TBC holy paladin throughput depends on chaining Light's Grace. Letting it drop wastes 0.5s on every subsequent HL.

**Implementation:**
- In `build_state()`, read `lights_grace_remains` (already tracked)
- New strategy: `LightGraceChain`, priority between `DivineFavorCombo` and `HolyLightRanked`
- Match: `state.lights_grace_remains < 2.5 and state.lights_grace_remains > 0 and state.tank_incoming_dps > 0`
- Execute: `NS.try_cast(state.selected_hl_rank or SPELLS.HolyLight, tank, "[HOLY] Light's Grace chain")`
- Add setting: `holy_lg_chain_enabled` (default true)

**Test:** `test_holy_lg_chaining.lua` — validate match fires at 2.4s, doesn't fire at 3.0s, doesn't fire when LG absent.

---

## Task B: Enhancement Shaman — CLEU Swing Diagnostics

**File:** `EaxRotations/classes/shaman/enhancement_sylvanas.lua`
**What:** Consume `NS.SwingDiagnostics` for CLEU-backed swing timing to improve Stormstrike / totem twist / shock alignment.
**Why:** Enhancement weaving (Stormstrike → shocks → totem refresh) benefits from exact swing knowledge same as retribution.

**Implementation:**
- Register weapon buff / Stormstrike IDs with `NS.SwingDiagnostics.register_seals()` at load
- In `build_state()`, prefer `NS.SwingDiagnostics.get_swing_remains()` for `swing_remains`
- In Stormstrike execute, `mark_twist_attempt()` if SS is treated as a "twist" equivalent
- Add diagnostics toggle: `enh_cleu_diagnostics` (default false)

**Test:** `test_enhancement_cleu_wiring.lua` — validate CLEU data is consumed when active, native fallback when inactive.

---

## Task C: Warrior (Arms/Fury/Kebab) — CLEU Swing Diagnostics

**Files:** `EaxRotations/classes/warrior/arms_sylvanas.lua`, `fury_sylvanas.lua`, `kebab_sylvanas.lua`
**What:** Consume `NS.SwingDiagnostics` for HS trick timing / Slam weave windows.
**Why:** HS trick (DW offhand normalization) and Slam weave both depend on precise swing timing. CLEU removes drift.

**Implementation (per spec):**
- Register relevant abilities with `register_seals()` (e.g., Slam, Heroic Strike)
- In `build_state()`, prefer `NS.SwingDiagnostics.get_swing_remains()` over `NS.get_time_until_swing()`
- Kebab already reads `mh_remain` / `oh_remain` — swap to CLEU-backed when available
- Add diagnostics toggle per spec: `<spec>_cleu_diagnostics`

**Test:** `test_warrior_cleu_wiring.lua` — validates swing data wiring across all 3 warrior specs.

---

## Task D: Protection Paladin — Blessing of Kings Party Buff OOC

**File:** `EaxRotations/classes/paladin/protection_sylvanas.lua`
**What:** Low-priority OOC strategy that casts BoK on party members missing the buff.
**Why:** Party buff maintenance is a standard tank responsibility. EAX prot already has BoS self-cast; adding BoK party is minimal incremental value.

**Implementation:**
- New strategy: `BlessingOfKingsParty`, priority ~50 (low, after all combat/defensive)
- Match: `not context.in_combat and state.is_group and NS.spell_ready(SPELLS.BlessingOfKings)`
- Find ally without `BLESSING_KINGS_BUFF` using `find_ally()` pattern
- Setting: `prot_bok_party` (default true)

**Test:** `test_protection_bok_party.lua` — validate BoK only fires OOC, only on unbuffed ally, respects setting.

---

## Task E: Shadow Priest — Configurable DoT Refresh Windows

**File:** `EaxRotations/classes/priest/shadow_sylvanas.lua`
**What:** Expose hardcoded `VT_CLIP_THRESHOLD = 1.5` via `context.settings`.
**Why:** Users on different latencies / playstyles want control over how aggressively DoTs are refreshed.

**Implementation:**
- Replace `VT_CLIP_THRESHOLD` with `get_setting(context, "shadow_vt_refresh_window", 1.5)`
- Add `SW:P` equivalent: `get_setting(context, "shadow_swp_refresh_window", 1.5)`
- Schema wiring: add two slider settings in `classes/priest/schema_sylvanas.lua` (1.0–3.0s range)
- No rotation logic change — just parameterization

**Test:** Update `test_shadow_dot_refresh.lua` or create `test_shadow_refresh_windows.lua` — validate custom values are respected.

---

## Validation Gates (All Tasks)

| Gate | Command | Pass Criteria |
|------|---------|---------------|
| Syntax | `luac -p` on every modified file | 0 errors |
| Rotation tests | `lua EaxRotations/tests/run_rotation_tests.lua` | 215/215 pass |
| Leveling tests | `lua EaxRotations/tests/run_leveling_tests.lua` | 13/13 pass |
| New tests | All new test files pass standalone | ok |

## Delegation

- **Agent Alpha (melee-specialist):** Tasks B + C (Enhancement + Warrior CLEU wiring)
- **Agent Beta (healer-specialist):** Tasks A + D (Holy LG chaining + Prot BoK)
- **Agent Gamma (caster-specialist):** Task E (Shadow DoT windows)
