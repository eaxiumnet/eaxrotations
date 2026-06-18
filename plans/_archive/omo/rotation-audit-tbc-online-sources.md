# rotation-audit-tbc-online-sources - Work Plan

## TL;DR (For humans)

**What you'll get:** 5 spec rotation fixes across Destruction Warlock, Fury Warrior, Combat Rogue, Arms Warrior, and Balance Druid — each aligned with TBC Classic community-standard rotation priorities verified against 10 online sources. 24 other specs confirmed correct with zero changes needed.

**Why this approach:** Every change is a minimal strategy reorder or one-strategy addition in the existing `strategies[]` table — never removes spells, never changes spell IDs, never modifies shared modules. One commit per spec for bisect-ability. Existing test suite (111 tests, 95 rotation suites) catches regressions immediately.

**What it will NOT do:** Touch 24 verified-correct specs (including all healers, tanks, and 2 false-positive DPS specs). Change spell IDs, debuff tables, or buff IDs. Modify shared modules or middleware. Add new config settings. Rewrite entire strategies tables.

**Effort:** Short (~20 min)
**Risk:** Low — all changes are strategy-table tweaks, test suite covers every spec
**Decisions I made for you:**
- **Metis review found 2 false-start additions**: Arcane Mage Cold Snap (ColdSnapIVReset strategy at arcane_sylvanas.lua:L521 already implements double-IV exactly) and BM Hunter Steady Shot (SteadyShot strategy at beast_mastery_sylvanas.lua:L749 already implements Auto→Steady weave). Both removed from plan. These were my errors — the code was already correct.
- **Metis corrected Fury swap logic**: Move Rampage AFTER Bloodthirst (not swap with Execute). New order: Execute → Bloodthirst → Rampage → Whirlwind.
- **3 initial DPS gaps resolved to false positives**: Ret Paladin seal twist correctly defers CS only within the 0.45s pre-swing window. Fire Mage Scorch→Fireball order is correct. Shadow Priest Shadowfiend already fires before Vampiric Touch (L649 vs L650).
- **No healer/tank changes**: All 12 healer/tank specs verified correct against community sources.
- **Fix via strategy moves/adds only**: No removal of any spell logic.
- **Primary source per spec**: wowtbc.gg + Icy Veins, cross-ref Warcraft Tavern + sim data.
- **Test after every fix**: `luac -p` + `run_rotation_tests.lua` + `run_leveling_tests.lua` after each commit.

Your next move: approve the plan, then `$start-work` to begin execution. Full execution detail follows below.

---

> TL;DR (machine): Short, Low risk, 5 spec files — strategy reorder + missing strategy additions, test after each, 1 commit/spec

## Scope
### Must have
- **Destruction Warlock**: Add Curse of Elements strategy entry (before CurseOfDoom in ACTIONS table, group-content-gated)
- **Fury Warrior**: Move Rampage strategy entry to after Bloodthirst in STRATEGY_SPECS (keep Execute as #1, new order: Execute → BT → Rampage → WW)
- **Combat Rogue**: Register existing cheap_shot_matches and garrote_matches in the strategies table (match functions already exist at combat_sylvanas.lua:L405-L421, just need table registration)
- **Arms Warrior**: Add Mortal Strike healing-debuff maintenance check to mortal_strike_matches (use existing ms_remains field already computed in build_state:L278)
- **Balance Druid**: Add TTD gate (min 15s) to Force of Nature cooldown use

### Must NOT have (guardrails, anti-slop, scope boundaries)
- ❌ Modify 24 verified-correct spec files: Fire, Frost, Arcane (ColdSnapIVReset already correct), Retribution, Shadow, Affliction, Demonology, Elemental, Enhancement, Restoration (all healer/tank specs), Beast Mastery (SteadyShot already correct), Marksmanship, Survival, Assassination, Subtlety, Protection Warrior, Protection Paladin, Holy Paladin, Discipline, Holy Priest, Smite, Feral Cat, Feral Bear, Restoration Druid, Caster Druid
- ❌ Remove or change ANY spell ID, debuff table, buff ID, or constant
- ❌ Modify shared modules (interrupts, consumables, buff_db, etc.)
- ❌ Add new config/menu settings or schema entries
- ❌ Touch middleware_sylvanas.lua files
- ❌ Touch leveling_sylvanas.lua files
- ❌ Rewrite entire strategies[] table — only move/add individual entries
- ❌ Change spell_id_resolver or DBC-extracted IDs

### Resolved False Positives (close inspection disproved initial gaps)
| Spec | Original Concern | Why Correct | Evidence |
|------|-----------------|-------------|----------|
| **Retribution Paladin** | "CS must be #1 priority, twist strategies at 760/750 fire before CS at 700" | Twist match functions gate on `swing_remains ≤ twist_window` (0.45s). CS runs in all other cases. Twist only defers CS within the 0.45s pre-swing window — optimal behavior | retribution_sylvanas.lua:L410,L453 |
| **Fire Mage** | "Scorch should be before Fireball" | Already correct: Scorch at L299, Fireball at L308 in strategies[] | fire_sylvanas.lua:L296-L310 |
| **Shadow Priest** | "Shadowfiend should cast before DoTs" | Already correct: Shadowfiend at L649, VT at L650 in strategies[] | shadow_sylvanas.lua:L649-L650 |
| **Arcane Mage** | "Missing Cold Snap for double IV" | Already implemented: ColdSnapIVReset at L521 fires when IV active + AP expired | arcane_sylvanas.lua:L521-L534 |
| **Beast Mastery Hunter** | "Missing Steady Shot filler" | Already implemented: SteadyShot at L749 with full Auto→Steady weave | beast_mastery_sylvanas.lua:L749-L758 |

## Verification strategy
> Zero human intervention - all verification is agent-executed.
- Test decision: **tests-after** — existing test suite covers all 29 specs. Run full suite after each commit. Add strategy-name assertions for new strategies.
- Framework: Lua test runner (`EaxRotations/tests/run_rotation_tests.lua`, 95 suites) + `run_leveling_tests.lua` (11 suites) + `luac -p` syntax check
- Evidence: `.omo/evidence/task-<N>-rotation-audit-tbc-online-sources.txt`

## Execution strategy
### Parallel execution waves
> Target 5-8 todos per wave. Fewer than 3 (except the final) means you under-split.

**Wave 1**: Independent DPS fixes (parallel — no cross-spec dependencies):
- Todo 1: Destruction Warlock (add CoE strategy)
- Todo 2: Fury Warrior (move Rampage after BT)
- Todo 3: Arms Warrior (add MS debuff refresh)

**Wave 2**: Independent fixes (parallel):
- Todo 4: Combat Rogue (register existing stealth matchers)
- Todo 5: Balance Druid (add FoN TTD gate)

**Wave 3**: Global verification (sequential)
- Verify all modified specs pass test suites
- luac -p on all 5 modified files
- Verify 24 unchanged specs still pass

### Dependency matrix
| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| 1. DestroWarlock | none | none | 2, 3 |
| 2. FuryWarrior | none | none | 1, 3 |
| 3. ArmsWarrior | none | none | 1, 2 |
| 4. CombatRogue | none | none | 5 |
| 5. BalanceDruid | none | none | 4 |

## Todos
<!-- APPEND TASK BATCHES BELOW THIS LINE WITH edit/apply_patch - never rewrite the headers above. -->
- [ ] 1. Destruction Warlock: Add Curse of Elements strategy to ACTIONS table
  What to do / Must NOT do: In destruction_sylvanas.lua, add a new spell definition near L19: `local CurseElements = NS.spell_action({ 27228, 11722, 11721, 1490 }, "CurseOfElements")` and debuff table near L9: `local CURSE_OF_ELEMENTS_DEBUFF = { 27228, 11722, 11721, 1490 }`. Insert a new ACTIONS entry AFTER the comment line at L95 and BEFORE the CurseOfDoom entry at L96: `{ name = "CurseOfElements", spell = CurseElements, debuff = CURSE_OF_ELEMENTS_DEBUFF, refresh = 3, group_only = true },`. If `group_only` field is not supported by the ACTIONS matching engine, add a match-function gate checking `context.is_group` instead. Verify spell IDs 27228/11722/11721/1490 exist in DBC. Do NOT change any existing ACTIONS entries or their order. Do NOT change CurseOfDoom or any DoT strategy.
  Parallelization: Wave 1 | Blocked by: none | Blocks: none
  References: destruction_sylvanas.lua:L85-L124 (ACTIONS table), L9 (debuff tables), L19-L36 (spell definitions), L94-L97 (insertion point)
  Acceptance criteria (agent-executable): `lua EaxRotations/tests/run_rotation_tests.lua` passes all 95 suites. `luac -p EaxRotations/classes/warlock/destruction_sylvanas.lua` exits 0. Spell ID 27228 returns valid spell from DBC.
  QA scenarios: happy — CoE applies before DoTs in group combat. failure — CoE skips when not in a group. Evidence: `.omo/evidence/task-1-destro-coe.txt`
  Commit: Y | fix(destruction): add Curse of Elements strategy for group content

- [ ] 2. Fury Warrior: Move Rampage to after Bloodthirst in STRATEGY_SPECS
  What to do / Must NOT do: In fury_sylvanas.lua STRATEGY_SPECS table (L720-L783), move the `{ "Rampage", rampage_matches, ... }` entry (currently at L771, position just before Execute) to AFTER the `{ "Bloodthirst", bt_matches, ... }` entry (L773) but BEFORE `{ "Whirlwind", whirlwind_matches, ... }` (L774). New order around L770-L775: `SweepingStrikes(L769) → Execute(L772) → Bloodthirst(L773) → Rampage(moved) → Whirlwind(L774)`. Execute stays at #1 (sub-20% finisher). BT priority > Rampage maintenance. Do NOT move Execute. Do NOT change any match functions (rampage_matches, bt_matches). Do NOT change spell IDs or action definitions.
  Parallelization: Wave 1 | Blocked by: none | Blocks: none
  References: fury_sylvanas.lua:L770-L774 (STRATEGY_SPECS entries), L439-L457 (rampage_matches), L497-L503 (bt_matches)
  Acceptance criteria (agent-executable): `lua EaxRotations/tests/run_rotation_tests.lua` passes. `luac -p EaxRotations/classes/warrior/fury_sylvanas.lua` exits 0. Strategy ordering: Execute before Bloodthirst before Rampage before Whirlwind.
  QA scenarios: happy — BT fires before Rampage when both off-cooldown and rage ≥ 30. failure — Rampage only fires when stacks < 5, BT on cooldown, and rage ≥ 30. Execute always fires first below 20% target HP. Evidence: `.omo/evidence/task-2-fury-bt-first.txt`
  Commit: Y | fix(fury): move Rampage after Bloodthirst per TBC community standards

- [ ] 3. Arms Warrior: Add Mortal Strike debuff maintenance to match function
  What to do / Must NOT do: In arms_sylvanas.lua mortal_strike_matches function, add a debuff-remains check BEFORE the existing rage-cap gating. The ms_remains field already exists in build_state (L278) but is never read by mortal_strike_matches. Add: if `state.ms_remains < 3` and `state.ms_cd` (from L286) `== 0`, refresh Mortal Strike immediately (debuff maintenance supersedes rage management). Do NOT change Slam timing, Execute priority, or any other strategy. Do NOT add new state fields — ms_remains already computed.
  Parallelization: Wave 1 | Blocked by: none | Blocks: none
  References: arms_sylvanas.lua:L59 (MORTAL_STRIKE_DEBUFF table), L278 (ms_remains in build_state), L286 (ms_cd), L366-L370 (mortal_strike_matches)
  Acceptance criteria (agent-executable): `lua EaxRotations/tests/run_rotation_tests.lua` passes. `luac -p EaxRotations/classes/warrior/arms_sylvanas.lua` exits 0.
  QA scenarios: happy — MS fires when healing-debuff <3s remaining regardless of rage level. failure — MS follows normal cooldown+rage priority when debuff has >3s remaining. Evidence: `.omo/evidence/task-3-arms-ms-refresh.txt`
  Commit: Y | fix(arms): add Mortal Strike debuff maintenance refresh to match function

- [ ] 4. Combat Rogue: Register existing stealth opener match functions in strategies table
  What to do / Must NOT do: In combat_sylvanas.lua strategies table (L448-L484), register the already-defined match functions cheap_shot_matches (L405-L411) and garrote_matches (L413-L421) as new strategy entries. Insert AFTER the existing Stealth strategy (L467) and BEFORE SliceAndDice (L468). Both need execute functions calling `NS.try_cast()` with the spell ID: Cheap Shot → 1833, Garrote → 703. Use existing `SPELLS.CheapShot` and `SPELLS.Garrote` if available, or direct ID. Do NOT create new match functions — they already exist. Do NOT change SliceAndDice, Rupture, or Eviscerate priorities. This was an intentional omission in the original code (PvP-focused), but TBC Combat Rogues should use stealth openers in PvE per Wowhead + Rogue Discord.
  Parallelization: Wave 2 | Blocked by: none | Blocks: none
  References: combat_sylvanas.lua:L405-L411 (cheap_shot_matches), L413-L421 (garrote_matches), L448-L484 (strategies table), L467-L468 (insertion point between Stealth and SliceAndDice)
  Acceptance criteria (agent-executable): `lua EaxRotations/tests/run_rotation_tests.lua` passes. `luac -p EaxRotations/classes/rogue/combat_sylvanas.lua` exits 0.
  QA scenarios: happy — Cheap Shot fires from stealth on melee target (if learned). Garrote fires from stealth when target is casting. failure — both skip when not stealthed or target not in melee range. Evidence: `.omo/evidence/task-4-combat-stealth.txt`
  Commit: Y | fix(combat): register stealth opener strategies (Cheap Shot, Garrote) for PvE

- [ ] 5. Balance Druid: Add TTD gate to Force of Nature cooldown use
  What to do / Must NOT do: In balance_sylvanas.lua, modify the _ACT_FON action definition (L32) to add TTD-awareness: don't spend the 3-minute Force of Nature cooldown if the target will die within 15 seconds. Add `min_ttd = 15` to the action definition. In the FoN match function (L140-L148 area), add a TTD check before the spell_ready call: if `context.ttd_known and context.ttd < 15` then return false. Use existing NS.match_helpers.ttd_gate pattern (see affliction_sylvanas.lua for reference). Do NOT change any other rotation priority. Do NOT change Hurricane, Moonfire, or Starfire strategies.
  Parallelization: Wave 2 | Blocked by: none | Blocks: none
  References: balance_sylvanas.lua:L32 (_ACT_FON definition), L140-L148 (FoN match function), affliction_sylvanas.lua match_helpers.ttd_gate usage
  Acceptance criteria (agent-executable): `lua EaxRotations/tests/run_rotation_tests.lua` passes. `luac -p EaxRotations/classes/druid/balance_sylvanas.lua` exits 0.
  QA scenarios: happy — FoN fires on cooldown when TTD > 15s. failure — FoN skips when TTD known < 15s. Evidence: `.omo/evidence/task-5-balance-fon.txt`
  Commit: Y | fix(balance): add TTD gate to Force of Nature cooldown use

## Final verification wave
> Runs in parallel after ALL todos. ALL must APPROVE. Surface results and wait for the user's explicit okay before declaring complete.
- [ ] F1. Plan compliance audit — verify all 5 todos completed, 0 changes to 24 verified specs, all entry-point constraints held
- [ ] F2. Code quality review — luac -p on all 5 modified files exits 0, lsp_diagnostics shows 0 errors on changed files
- [ ] F3. Real manual QA — `lua EaxRotations/tests/run_rotation_tests.lua` all 95 suites PASS, `lua EaxRotations/tests/run_leveling_tests.lua` all 11 suites PASS
- [ ] F4. Scope fidelity — `git diff --stat` shows exactly 5 spec files changed, 0 shared/middleware/schema files touched

## Commit strategy
One commit per spec, ordered by impact:
1. `fix(destruction): add Curse of Elements strategy for group content`
2. `fix(fury): move Rampage after Bloodthirst per TBC community standards`
3. `fix(arms): add Mortal Strike debuff maintenance refresh check`
4. `fix(combat): register stealth opener strategies for PvE`
5. `fix(balance): add TTD gate to Force of Nature cooldown use`

Each commit verified with `luac -p` + full test suite before push.

## Success criteria
- All 5 spec files modified with minimal strategy-order changes or additions
- Zero changes to 24 verified-correct spec files
- `lua EaxRotations/tests/run_rotation_tests.lua` — all 95 suites PASS
- `lua EaxRotations/tests/run_leveling_tests.lua` — all 11 suites PASS
- `luac -p` exits 0 on all 5 modified files
- lsp_diagnostics shows 0 errors on changed files
- Rotation priorities in modified specs match canonical sources (wowtbc.gg, Icy Veins)
