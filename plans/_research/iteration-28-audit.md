# Per-Spec Audit Notes — Iteration 28
## Session: 2026-06-22

---

## discipline_sylvanas.lua (PR3)
**Commit**: `f7dddd3d` — fix(discipline): enable Prayer of Mending pre-pull
**Quality bar**: §4.3 Healer
**Sources**: wowsims/tbc priest module, AGENTS.md Pattern 13 (Smart Innervate)
**Audit findings**:
- Pre-pull Prayer of Mending wired via `disc_prepull_pom` setting
- Nil-guarded: `(state.pom_ready and state.prepull_pom_enabled)`
- Test: `test_discipline_feature_gaps.lua` covers pre-pull scenarios
**DoD status**: Pre-pull PoM [x]

---

## elemental_sylvanas.lua (SH3)
**Commit**: `0b74bec8` — fix(elemental): detect Clearcast, prioritize Chain Lightning
**Quality bar**: §4.2 DPS
**Sources**: wowsims/tbc shaman module, lexxer.org spell 12536
**Audit findings**:
- Clearcast buff ID 12536 verified in DBC
- Chain Lightning prioritized when Clearcast active to consume proc
- Nil-guarded: `(state.clearcast and state.clearcast > 0)`
- Test: `test_elemental_clearcast_priority.lua`
**DoD status**: Clearcast consumption [x]

---

## assassination_sylvanas.lua (RO2 + RO4)
**Commits**: `87dfc8a3` (SnD priority), `7cb81e4c` (dagger check)
**Quality bar**: §4.2 DPS
**Sources**: wowsims/tbc rogue module, SimulationCraft APL
**Audit findings**:
- SliceAndDice moved before Envenom in priority list (matches wowsims)
- Mutilate eligibility gated on `has_daggers()` with 506-item whitelist
- Sinister Strike fallback when no daggers equipped
- Nil-guarded all state reads
- Tests: `test_rogue_snd_maintenance.lua`, `test_assassination_mutilate_dagger_check.lua`
**DoD status**: SnD maintenance [x], Mutilate dagger check [x]

---

## combat_sylvanas.lua (RO3)
**Commit**: `332a0d89` — fix(rogue): update combat energy pooling to wowsims canPoolEnergy
**Quality bar**: §4.2 DPS
**Sources**: wowsims/tbc rogue module, energy tick mechanics (2.0s ticks)
**Audit findings**:
- Energy pooling logic synced with wowsims `canPoolEnergy` threshold
- Builders deferred when within 0.6s of energy tick cap
- Nil-guarded: `(state.energy or 0)`, `(state.next_tick_in or 999)`
- Test: `test_combat_energy_pooling.lua`
**DoD status**: Energy pooling [x]

---

## hunter specs (HU1-HU5)
**Commits**: `4f4b9e49` (pet manager), `1483f59b` (Steady Shot), `88852dd5` (Trueshot Aura), `85e0bddb` (dead zone test)
**Quality bar**: §4.2 DPS
**Sources**: wowsims/tbc hunter module, wowtbc.gg hunter guide
**Audit findings**:
- Pet manager wired into dispatcher with class-key gate
- Steady Shot weaving enabled at high haste (1:1 rotation)
- Trueshot Aura (19506) added to marksmanship rotation
- Dead zone test registered and passing
- Nil-guarded all state reads
- Tests: `test_hunter_pet_manager_wiring.lua`, `test_hunter_steady_shot_weave.lua`, `test_mm_trueshot_aura.lua`, `test_hunter_dead_zone.lua`
**DoD status**: Pet management [x], Steady Shot weave [x], Trueshot Aura [x], Dead zone [x]

---

## warrior_protection_sylvanas.lua (TK2)
**Commit**: `0c8e9809` — fix(warrior-protection): wire Shield Wall / Last Stand to settings
**Quality bar**: §4.4 Tank
**Sources**: wowsims/tbc warrior module, tank mitigation priorities
**Audit findings**:
- Shield Wall and Last Stand now respect `defensive_hp_threshold` setting
- Disable toggles wired correctly
- Nil-guarded: `(state.hp or 100)`, `(state.shield_wall_ready or false)`
- Test: `test_warrior_defensive_threshold_wiring.lua`
**DoD status**: Defensive cooldowns wired [x]

---

## paladin_protection_sylvanas.lua (TK3 + TK4)
**Commits**: `31284ccd` (Consecration downrank), `254b4c86` (Avenger's Shield opener)
**Quality bar**: §4.4 Tank
**Sources**: wowsims/tbc paladin module, protection paladin threat guide
**Audit findings**:
- Consecration downranking at <35% mana (ranks 6→3, IDs verified: 27173, 20924, 20923, 20922)
- Avenger's Shield pre-pull opener wired via `prot_avenger_opener` setting
- OOC-only gate preserved for opener
- Nil-guarded: `(state.mana_pct or 100)`, `(state.in_combat or false)`
- Tests: `test_paladin_consecration_downrank.lua`, `test_paladin_avenger_shield_opener.lua`
**DoD status**: Consecration downrank [x], Avenger's Shield opener [x]

---

## Universal compliance
**All audited specs pass**:
- Pattern-14 nil-guards: verified via `test_state_field_nil_guards_2026_06.lua`
- Pattern-15 headers: added to all 21 missing files
- No raw menu.get() outside functions: verified via `test_rotation_strategy_compliance.lua`
- No math.sqrt(): verified via `test_quality_bar_compliance.lua`
- No forbidden cast paths: verified via `test_rotation_strategy_compliance.lua`

---

## Oracle verification
- Round-1: completed (iterations 1-10)
- Round-2: completed (iterations 11-14)
- Round-3: VERIFIED-APPROVED (iterations 15-28, commits f7dddd3d..254b4c86)

---

## Gate status
- `run_rotation_tests.lua`: 146/146 PASS
- `run_leveling_tests.lua`: 11/11 PASS
- `run_sylvanas_audit_tests.lua`: 61/61 PASS (0 invalid spell IDs)
- `luac -p`: clean on all modified files
