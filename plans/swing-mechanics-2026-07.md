# Swing Mechanics — Parry-Haste + Enemy Swing + Overpower Proc — 2026-07-06

**Goal:** Port the three highest-value swing-timer mechanics from SuperSwingTimer (SST)
into EAX's Sylvanas-runtime `swing_diagnostics` module, so melee specs (tanks + DPS) get
parry-haste compression, enemy-swing tracking, and Overpower dodge-proc gating.

**Baseline:** 219 rotation + 13 leveling = 232 suites PASS (the 220th, test_combat_custom_matches,
is a pre-existing rogue failure, unrelated).

## Why extend swing_diagnostics in place (not a new file)
- `NS.register_on_game_event` is a **singleton dispatcher** (core_sylvanas.lua:1309) — one core
  callback fans out to many Lua handlers per event. A second file would register a 2nd CLEU
  handler (allowed, but wasteful: double-parses every CLEU event). Extending the existing
  `on_cleu` keeps all CLEU logic cohesive + zero extra parse cost.
- SST is a WoW addon (Blizzard APIs: UnitAttackSpeed/GetSpellCooldown/C_Spell.IsAutoRepeat/frames).
  EAX runs in the Sylvanas runtime. We port the **algorithms + mechanic constants**, not code.

## SST-confirmed constants
- Parry-haste: reduce remaining swing by `0.40 * weapon_speed`, floor `0.20 * weapon_speed`
  (SST_State.lua:1122-1124 `ApplyParryHaste`).
- Overpower proc window: `5.0s` after the player's attack is dodged (SST_State.lua:1256
  `warriorOverpowerProcUntil = eventTime + WARRIOR_OVERPOWER_PROC_WINDOW`).

## CLEU arg layout (authoritative — apidocs/pages/dev/api/events.md + hunter_adaptive:758)
Fixed prefix [1..11]: timestamp, sub_event, hide_caster, source_guid(4), source_name,
source_flags, source_raid_flags, dest_guid(8), dest_name, dest_flags, dest_raid_flags.
- `SWING_MISSED` suffix: [12]=missType (string: PARRY/DODGE/BLOCK…), [13]=isOffHand.
- `SPELL_MISSED` suffix: [12]=spell_id, [13]=spell_name, [14]=spell_school, [15]=missType, [16]=isOffHand.
- Existing `is_player_source` reads args[4] (source_guid) ✓; `dest_guid` = args[8] ✓ (matches doc).

## Changes
### 1. `shared/swing_diagnostics_sylvanas.lua` (extend on_cleu + new API)
- Add constants `PARRY_REDUCTION=0.40`, `PARRY_FLOOR=0.20`, `OVERPOWER_PROC_WINDOW=5.0`.
- Add state: `_last_parry_time`, `_parry_swing_end`, `_overpower_proc_until`,
  `_last_enemy_swing_time`, `_last_enemy_swing_interval`.
- Add `is_player_dest(args)` (args[8]==player_guid).
- Add `apply_parry_haste(now)`, `record_enemy_swing(now)`, `record_overpower_proc(now)`.
- Restructure `on_cleu`: handle player-as-DEFENDER (parry + enemy swing) BEFORE the
  player-as-source gate; detect DODGE in player-source SWING_MISSED + new SPELL_MISSED branch.
- Make `get_swing_remains()` parry-aware (use `_parry_swing_end` when set).
- New API: `is_overpower_proc_active()`, `get_overpower_proc_remains()`, `get_last_parry_time()`,
  `get_enemy_swing_remains()`, `get_enemy_swing_interval()`.
- Extend `reset()` to clear new state.

### 2. `classes/warrior/arms_sylvanas.lua` (wire Overpower proc gate)
- `overpower_matches`: when SwingDiagnostics is active, require `is_overpower_proc_active()`
  (else fall back to spell_ready-only = legacy behavior). Stops burning rotation ticks on
  non-castable Overpower attempts (Overpower is only usable for 5s after a dodge).

### 3. `tests/test_swing_mechanics.lua` (new — synthetic CLEU injection)
- Mock NS.register_on_game_event to capture the CLEU callback; inject synthetic args.
- Assert: parry compresses get_swing_remains (40% reduction, 20% floor); dodge sets
  is_overpower_proc_active for 5s; enemy swing (player-as-defender) tracked; SPELL_MISSED
  dodge also procs Overpower; reset clears state.

## Validation
`luac -p` on changed files + `lua run_rotation_tests.lua` (220) + `lua run_leveling_tests.lua` (13).
All warrior tests must stay green.

---

## STATUS (2026-07-06) — COMPLETE & VALIDATED

- `luac -p` clean on all 4 changed files.
- **234/234 tests pass** (221 rotation + 13 leveling, 0 failures). New `test_swing_mechanics`
  registered in `run_rotation_tests.lua` (9 sub-assertions: parry compression 40%, 20% floor,
  parry-clears-on-new-swing, Overpower 5s window, SPELL_MISSED dodge proc, enemy swing timer,
  reset clears all).
- Spell audit unaffected (0 invalid).

### Delivered
- `shared/swing_diagnostics_sylvanas.lua`: parry-haste + enemy-swing + Overpower-proc wired
  into the existing CLEU handler (player-as-defender branch + dodge detection in player-as-source
  SWING_MISSED + new SPELL_MISSED branch). `get_swing_remains()` is now parry-aware → arms/fury/
  enh/kebab auto-benefit. New API: `is_overpower_proc_active()`, `get_overpower_proc_remains()`,
  `get_last_parry_time()`, `get_enemy_swing_remains()`, `get_enemy_swing_interval()`.
- `classes/warrior/arms_sylvanas.lua`: `overpower_matches` now gates on the dodge proc when
  CLEU is active (stops burning ticks on non-castable Overpower; falls back to spell_ready
  alone when CLEU absent).
- `tests/test_swing_mechanics.lua`: synthetic CLEU injection test (9 cases).

## Follow-up (documented, not in this commit)
- Wire prot tank to consume enemy-swing timer (Shield Block coverage, Revenge window) — separate spec change.
- Fix pre-existing `is_offhand` reads in on_cleu (args[12] for SWING_MISSED is missType, not isOffHand;
  currently a harmless no-op always-false). Out of scope here.

## Follow-up (documented, not in this commit)
- Wire prot tank to consume enemy-swing timer (Shield Block coverage, Revenge window) — separate spec change.
- Fix pre-existing `is_offhand` reads in on_cleu (args[12] for SWING_MISSED is missType, not isOffHand;
  currently a harmless no-op always-false). Out of scope here.
