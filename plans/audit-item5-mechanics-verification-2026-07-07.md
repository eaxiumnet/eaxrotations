# Plan: Audit Item #5 — Per-spec mechanics verification

**Date:** 2026-07-07
**Status:** COMPLETE — all flagged mechanics verified as correctly implemented (false positives)
**Scope:** Verify the "handful of per-spec mechanics" flagged in the "What's Missing" audit.

## Findings — all PASS (audit flags were false positives)

### 1. Warrior Arms — Sweeping Strikes AoE cleave hook  ✅ IMPLEMENTED
- `arms_sylvanas.lua:544-553` — full `sweeping_strikes_matches()`:
  - `enemy_count >= SWEEPING_STRIKES_COUNT` (configurable, default 2)
  - `aoe_cc_nearby` guard (won't break CC), TTD gate (>5s), rage gate (>=30), BATTLE stance, 30s cooldown
  - Registered in strategies table at line 865.
- `should_reserve_for_sweeping` rage-reservation logic gates Hamstring/Slam so SS rage isn't spent first.
- The audit's "no AoE cleave hook" claim was **wrong** — the hook is fully present.

### 2. Warrior Arms — Bladestorm/Heroic Throw  ✅ CORRECTLY ABSENT (WotLK-only)
- DBC verification (`wowheadScrape/dbc_extract/lua/spell_db.lua`):
  - Bladestorm talent = spell **46924** — NOT in TBC DBC (only Wrath/Cata/MoP external data).
  - Heroic Throw = spell **57755** — NOT in TBC DBC (only Wrath/Cata/MoP external data).
  - The two "Bladestorm" entries that DO exist in TBC DBC (9632, 35131) are **item procs** (weapon-enchant AoE + haste rating buff), NOT the warrior talent.
- Correctly omitted per AGENTS.md "TBC-era content" hard constraint.

### 3. Hunter MM — Silencing Shot + Scatter Shot  ✅ WIRED INTO INTERRUPT LAYER
- `class_sylvanas.lua:260-282` declares both spell objects.
- `middleware_sylvanas.lua:12-13` calls `interrupt_manager.register_interrupt_spell("hunter", "SilencingShot"/"ScatterShot", SPELLS)`.
- `interrupt_manager_sylvanas.lua:26-29,50,61` has FALLBACK_IDS + school-lock (34490=physical, 3s lock).
- `marksmanship_sylvanas.lua:203` tracks `silencing_shot_ready` in state.
- Fully wired into the interrupt manager arbitration layer.

### 4. Priest Shadow — Shadowfiend + Silence  ✅ BOTH FIRING
- `shadow_sylvanas.lua:672-691` `shadowfiend_matches()`: gates on `shadowfiend_known`, VT remaining, TTD >= 60s (wowsims-aligned). Registered at line 1077.
- `shadow_sylvanas.lua:957-960` `silence_matches()`: gates on `silence_ready` (tracked line 434). Spell ID 15487 (SILENCE_INTERRUPT_SPELL).
- Both confirmed present and gated with TBC-era logic.

### 5. Warlock — Spell Lock pet interrupt  ✅ WIRED
- `class_sylvanas.lua:219` declares `SpellLock = NS.spell_action({ 24259, 19647 }, "SpellLock")`.
- `middleware_sylvanas.lua:77` calls `interrupt_manager.register_interrupt_spell("warlock", "SpellLock", SPELLS)`.
- `interrupt_manager_sylvanas.lua:29,49,60` has FALLBACK_ID (19647), school=shadow, lock=3s.
- Leveling specs (`leveling_sylvanas.lua:165`, `leveling_vanilla.lua:126`) have `spell_lock_matches()` + registered strategies.
- Fully wired.

## Conclusion

All flagged mechanics in audit item #5 are **false positives**. No code changes needed. The audit's "Medium/Low confidence" ratings were appropriate — these were verification items, not real gaps. Documented here for traceability.

## Validation
- No production code changed (verification-only task).
- `run_rotation_tests.lua`: 242/242 pass (incl. 8 new gate-sweep suites from item #3).
- `run_leveling_tests.lua`: 13/13 pass.

# Plan: Audit Item #5 — Per-spec mechanics verification

**Date:** 2026-07-07
**Status:** COMPLETE — all flagged mechanics verified as correctly implemented (false positives)
**Scope:** Verify the "handful of per-spec mechanics" flagged in the "What's Missing" audit.

## Findings — all PASS (audit flags were false positives)

### 1. Warrior Arms — Sweeping Strikes AoE cleave hook  ✅ IMPLEMENTED
- `arms_sylvanas.lua:544-553` — full `sweeping_strikes_matches()`:
  - `enemy_count >= SWEEPING_STRIKES_COUNT` (configurable, default 2)
  - `aoe_cc_nearby` guard (won't break CC), TTD gate (>5s), rage gate (>=30), BATTLE stance, 30s cooldown
  - Registered in strategies table at line 865.
- `should_reserve_for_sweeping` rage-reservation logic gates Hamstring/Slam so SS rage isn't spent first.
- The audit's "no AoE cleave hook" claim was **wrong** — the hook is fully present.

### 2. Warrior Arms — Bladestorm/Heroic Throw  ✅ CORRECTLY ABSENT (WotLK-only)
- DBC verification (`wowheadScrape/dbc_extract/lua/spell_db.lua`):
  - Bladestorm talent = spell **46924** — NOT in TBC DBC (only Wrath/Cata/MoP external data).
  - Heroic Throw = spell **57755** — NOT in TBC DBC (only Wrath/Cata/MoP external data).
  - The two "Bladestorm" entries that DO exist in TBC DBC (9632, 35131) are **item procs** (weapon-enchant AoE + haste rating buff), NOT the warrior talent.
- Correctly omitted per AGENTS.md "TBC-era content" hard constraint.

### 3. Hunter MM — Silencing Shot + Scatter Shot  ✅ WIRED INTO INTERRUPT LAYER
- `class_sylvanas.lua:260-282` declares both spell objects.
- `middleware_sylvanas.lua:12-13` calls `interrupt_manager.register_interrupt_spell("hunter", "SilencingShot"/"ScatterShot", SPELLS)`.
- `interrupt_manager_sylvanas.lua:26-29,50,61` has FALLBACK_IDS + school-lock (34490=physical, 3s lock).
- `marksmanship_sylvanas.lua:203` tracks `silencing_shot_ready` in state.
- Fully wired into the interrupt manager arbitration layer.

### 4. Priest Shadow — Shadowfiend + Silence  ✅ BOTH FIRING
- `shadow_sylvanas.lua:672-691` `shadowfiend_matches()`: gates on `shadowfiend_known`, VT remaining, TTD >= 60s (wowsims-aligned). Registered at line 1077.
- `shadow_sylvanas.lua:957-960` `silence_matches()`: gates on `silence_ready` (tracked line 434). Spell ID 15487 (SILENCE_INTERRUPT_SPELL).
- Both confirmed present and gated with TBC-era logic.

### 5. Warlock — Spell Lock pet interrupt  ✅ WIRED
- `class_sylvanas.lua:219` declares `SpellLock = NS.spell_action({ 24259, 19647 }, "SpellLock")`.
- `middleware_sylvanas.lua:77` calls `interrupt_manager.register_interrupt_spell("warlock", "SpellLock", SPELLS)`.
- `interrupt_manager_sylvanas.lua:29,49,60` has FALLBACK_ID (19647), school=shadow, lock=3s.
- Leveling specs (`leveling_sylvanas.lua:165`, `leveling_vanilla.lua:126`) have `spell_lock_matches()` + registered strategies.
- Fully wired.

## Conclusion

All flagged mechanics in audit item #5 are **false positives**. No code changes needed. The audit's "Medium/Low confidence" ratings were appropriate — these were verification items, not real gaps. Documented here for traceability.

## Validation
- No production code changed (verification-only task).
- `run_rotation_tests.lua`: 242/242 pass (incl. 8 new gate-sweep suites from item #3).
- `run_leveling_tests.lua`: 13/13 pass.
