# Implementation Plan: Warlock Demonic Sacrifice, Backdraft, and Pet Loop Fixes

**Created:** 2026-06-21
**Scope:** High-priority Warlock rotation bugs (Pet summon loop, Demonic Sacrifice dispatch, Backdraft proc tracking)
**API Surface:** `NS.*` (delegating to Sylvanas `core.*`) + `pet_handler` (from `common/utility/pet_handler`)
**Docs References:** `apidocs/pages/dev/api/buffs.md`, `apidocs/pages/dev/api/object-manager.md`, `apidocs/pages/dev/api/spellbook.md`, `apidocs/pages/dev/modules/`
**Active Plan Index:** this plan rows into `plans/_active.md` upon start; archived to `plans/_archive/<slug>.md` on completion.

---

## ⚠️ Phase 0 — Corrections to the bug report (READ FIRST)

DBC verification ([`wowheadScrape/dbc_extract/lua/spell_db.lua:191277`](wowheadScrape/dbc_extract/lua/spell_db.lua) and [`EaxRotations/shared/wowhead_data_bridge_sylvanas.lua:8928`](EaxRotations/shared/wowhead_data_bridge_sylvanas.lua)) supersedes parts of the original bug report:

| User-supplied ID | User claim | DBC truth | Plan impact |
|------------------|------------|-----------|-------------|
| `18787` | "Demonic Sacrifice: Imp" | `Heaven's Blessing` (paladin trinket, level 60, school holy) — **not DS** | **DO NOT USE.** Not a castable DS spell. |
| `18788` | "Demonic Sacrifice: Voidwalker" | `Demonic Sacrifice` ✓ — the **ONE** castable DS spell | **Correct, retain.** Bridges all 5 pets. |
| `18789` | "Demonic Sacrifice: Succubus" | `Burning Wish` — passive aura (Imp-sacrifice fire damage buff), applied by engine after 18788 cast | **NOT a castable spell** — only an aura ID for tracking purposes. |
| `18790` | "Demonic Sacrifice: Felhunter" | `Fel Stamina` — passive aura (Voidwalker-sacrifice HP regen), applied by engine after 18788 cast | **NOT a castable spell** — only an aura ID for tracking purposes. |
| `30147` | "Demonic Sacrifice: Felguard" | `Tamed Pet Passive (DND)` — unrelated (pet scaling passive) | **DO NOT USE.** Not an Imp/Felguard buff. |

**SotC semantics (per DBC description of 18788):** Sacrificing is a single spell that **consumes the current summoned demon and grants a corresponding passive aura** based on which pet was active at cast time:

| Active pet at cast | Granted aura via DS | School | Type |
|--------------------|----------------------|--------|------|
| Imp | `18789` *Burning Wish* (+% fire damage) | fire | damage |
| Voidwalker | `18790` *Fel Stamina* (+HP regen) | shadow | sustain |
| Succubus / Incubus | `18791` (shadow damage bonus aura) | shadow | damage |
| Felhunter | `18792` (mana regen aura) | shadow | sustain |
| Felguard | `35701` (shadow dmg + mana regen aura) | shadow | hybrid |

**Conclusion:** The middleware line 335 (`{ id = { 18788 }, name = "DemonicSacrifice" }`) is **already casting the correct single DS spell**. Per-type spell IDs `18789/18790/18791/18792/35701` are CASTABLE-blocked passive auras that must be discovered via `NS.buff_up` / `NS.buff_remains`, not registered as `NS.try_cast` targets.

**Backdraft** (TBC Destruction talent, next-2-Soul-Fire/Shadow-Bolt instant cast proc after Conflagrate):
- Not yet verified in DBC inside this session.
- Phase 1 Task 3 resolves ID — likely `47271` or `35346`. Do not hardcode until Phase 1 verifies.

**Summon spell IDs (all already registered in `class_sylvanas.lua` lines 239-252, DBC confirmed by bridge):**
- `688` Summon Imp, `697` Summon Voidwalker, `712` Summon Succubus, `691` Summon Felhunter, `30146` Summon Felguard, `18708` Fel Domination.

---

## Overview

Three tightly-coupled bugs make the Warlock rotation "fight itself":

1. **Pet summon loop** — Destruction has 5 summon actions sharing one OOC predicate; Imp action is registered first so any spec that has the Destruction file loaded re-summons the wrong demon.
2. **Missing Demonic Sacrifice: Imp** — No spec has an OOC "sacrifice for Burning Wish fire damage buff" strategy. Only an emergency HP<20% defensive exists.
3. **Backdraft proc never tracked** — `state.has_backdraft` is declared but never assigned, so Conflagrate's instant-followup never fires (Soul Fire should drop from 4.0s→0 cast time for the next 2 spells if Backdraft is active).

Two secondary bugs (leveling summon gate, pet_manager mislabel) are bundled into Phase 4 / Phase 6 as cleanup.

---

## Files To Touch

| File | Phase | Concern |
|------|-------|---------|
| `EaxRotations/classes/warlock/destruction_sylvanas.lua` | 2, 3, 4 | Fix summon loop, add `Sac:Imp`, add Backdraft tracking |
| `EaxRotations/classes/warlock/demonology_sylvanas.lua` | 4 | Felguard-first (already correct), add OOC Imp fallback for low-level play |
| `EaxRotations/classes/warlock/affliction_sylvanas.lua` | 4 | Add OOC Felhunter summon (existing summon-related code is only state in build_state, no ACTIONS) |
| `EaxRotations/classes/warlock/leveling_sylvanas.lua` | 4 | Fix `summon_pet_matches` in_combat gate → OOC allowed like other specs |
| `EaxRotations/classes/warlock/middleware_sylvanas.lua` | 3 | Refactor `Warlock_DemonicSacrifice`: dispatch to spec-preferred pet via context.playstyle; spec-specific pet preference |
| `EaxRotations/classes/warlock/class_sylvanas.lua` | 1, 2 | Register `DemonicSacrifice` spell action + Backdraft buff table |
| `EaxRotations/classes/warlock/schema_sylvanas.lua` | 2 | Add per-spec `pet_preference` dropdown setting (imp/voidwalker/succubus/felhunter/felguard) |
| `EaxRotations/classes/warlock/destruction_vanilla.lua` | 2 | Mirror `has_backdraft` declaration/assignment (parity) |
| `EaxRotations/shared/pet_manager_sylvanas.lua` | 6 | Fix header comment ("Hunter" → "Hunter + Warlock"); add `M.get_current_pet_type()` helper |
| `EaxRotations/tests/test_destruction_custom_matches.lua` | 5 | Add `find_strategy("DemonicSacrifice")` + `find_strategy("BackdraftSoulBolt")` + Imp-First-Summon sequencing |
| `EaxRotations/tests/test_warlock_imp_machine_gun_2026_06.lua` | 5 | Convert from RED→GREEN — already exists, verifies new strategy presence |

---

## API Integration

| Function | Path | Purpose |
|----------|------|---------|
| `NS.spell_action(ids, name)` | `api/utility/spell_action` | Build spell object table for DS, Backdraft, Soulshatter |
| `NS.rotation_registry:register(spec, strats, opts)` | `api/common/rotation_registry` | Register spec strategies (already wired) |
| `NS.buff_up(unit, ids)` | `api/common/buff_up` | Check Backdraft active | `apidocs/pages/dev/api/buffs.md` |
| `NS.buff_remains(unit, ids)` | `api/common/buff_remains` | Time-left for Backdraft/Sac aura |
| `NS.has_pet()` / `NS.GetPet()` | `api/core / NS wrappers` | Pet presence check |
| `NS.unit_alive(unit)` | `api/core` (via NS helper) | Pet liveness check |
| `NS.spell_ready(spell, target, opts)` | `api/common/spell_ready` | Spell readiness (cooldown + reagent + range) |
| `NS.try_cast(spell, target, label, opts)` | `api/common/try_cast` | Cast spell (with skip_range opt for self-cast) |
| `NS.try_cast_position(...)` | `api/common/try_cast_position` | AoE / position-based cast |
| `pet_handler.pet_state.AGGRESSIVE / DEFENSIVE / PASSIVE` | `api/common/utility/pet_handler` | Pet stance control |
| `NS.time_now()` | `api/core` | Local anti-spam timer (Soulshatter, DS already have it) |
| `NS.has_player_buff(ids)` | `api/common/has_player_buff` | Check player-side auras (Soulstone, Fel Armor, Backdraft) |

**Patterns applied (AGENTS.md):**
- **Pattern 10** (Spec file structure): extend `build_state` → `match` → `strategy`; state table indexed by string keys.
- **Pattern 14** (State field nil-guards): every new state field gets a safe default — e.g. `has_backdraft = false`, `has_sac_aura = false`.
- **Pattern 5** (Spell casting via izi.spell()): use `NS.try_cast(spell, target, label, opts)`; never `core.input.cast_target_spell` directly.
- **Pattern 7** (Spell resolution caching): `NS.is_spell_learned(id)` is preferred over hot-path calls.

---

## Task List

### Phase 1: Spell ID Verification (READ-ONLY RESEARCH)

> Goal: confirm ALL fixture IDs against the DBC + bridge, fix the bug-report errors in any code or test references before writing anything.

- [ ] **Task 1.1: Verify Backdraft proc ID against DBC**
  - **Files:** `wowheadScrape/dbc_extract/lua/spell_db.lua` (or `wowsims.db` via `node -e "const db=require('better-sqlite3')('wowheadScrape/dbc_extract/wowsims.db'); console.log(JSON.stringify(db.prepare(\"SELECT id, name, description FROM spell WHERE name LIKE 'Backdraft%' OR name LIKE 'Backdraft'\").all()))"`)
  - **Acceptance:** minimum one match with description like "Your next 2 Shadow Bolt or Soul Fire spells are instant cast". Candidate IDs to validate: `47271`, `35346`, `61082`. If no ID matches, escalate in plan (this is the user's prompt area of concern).
  - **Verify:** node script returns a single row with the proc description.

- [ ] **Task 1.2: Verify DS buff auras (18789 / 18790 / 18791 / 18792 / 35701) school & type**
  - **Files:** `EaxRotations/shared/wowhead_data_bridge_sylvanas.lua:8927-8930` (42713..) — confirm which ones are present in TBC DBC. Likely only Imp + Voidwalker exist in TBC base; Succubus/Felhunter may be WotLK additions.
  - **Acceptance:** document the table `DEMONIC_SACRIFICE_AURAS = { Imp=18789, Voidwalker=18790, Succubus=<found or nil>, Felhunter=<found or nil>, Felguard=35701 }`. Missing IDs are flagged for the implementer: `nil` is acceptable (we just won't track that aura), but documented.
  - **Verify:** the table in this plan is filled in by the researcher; any nil entries are intentional.

- [ ] **Task 1.3: Confirm summon spell IDs already in `class_sylvanas.lua:239-252`**
  - **Files:** `EaxRotations/shared/wowhead_data_bridge_sylvanas.lua`
  - **Acceptance:** bridge lookup for each of `688, 697, 712, 691, 30146, 18708` returns the canonical pet spell name. Any ID mismatch is escalated (none expected).
  - **Verify:** shell `grep -E '^\[688\]|^\[697\]|^\[712\]|^\[691\]|^\[30146\]|^\[18708\]' wowhead_data_bridge_sylvanas.lua` shows expected names.

- [ ] **Task 1.4: Add new spell action table entries to plan (no code yet)**
  - Output: confirmed ID list appended to this plan under "Confirmed IDs" section, which the implementer copies verbatim. Looking up example: `DemonicSacrifice = { ids = {18788}, name = "DemonicSacrifice", cast_time=0, cooldown=0 }` and `BACKDRAFT_BUFF_IDS = { <verified> }`.

---

### Phase 2: Fix Destruction Spec (Demonic Sacrifice: Imp + Backdraft + Summon Loop)

- [ ] **Task 2.1: Declare new constants at file top (after line 36, before line 38)**
  - **File:** `EaxRotations/classes/warlock/destruction_sylvanas.lua`
  - **Line numbers:** insert near existing `BACKLASH_BUFF` table (line 13).
  - **Pattern:** Spell ID constant tables at module top, alphabetically grouped.
  - **API Used:** constants only.
  - **Acceptance:**
    - `BACKDRAFT_BUFF = { <Phase 1 verified ID(s)> }` declared.
    - `DEMONIC_SACRIFICE = { id = { 18788 }, name = "DemonicSacrifice" }` declared (single spell — see Phase 0).
    - `DEMONIC_SACRIFICE_AURA = { 18789, 18790, 18791, 18792, 35701 }` declared (all DS-grant auras).
  - **Verify:** `luac -p EaxRotations/classes/warlock/destruction_sylvanas.lua`

- [ ] **Task 2.2: Assign `state.has_backdraft` in `build_state`**
  - **File:** `EaxRotations/classes/warlock/destruction_sylvanas.lua`, line 58.
  - **Problem:** currently `state.has_backdraft = false` literal; never updated.
  - **Fix:** replace with `state.has_backdraft = me and NS.has_player_buff and NS.has_player_buff(BACKDRAFT_BUFF) or false` (or `NS.buff_up(me, BACKDRAFT_BUFF)` — match existing local style: file uses `NS.buff_up` on line 57 for `has_backlash`).
  - **Pattern 14 (state field nil-guards):** provides safe default `false` for nil `me`.
  - **Acceptance:** `state.has_backdraft` reflects actual Backdraft buff state in tests.
  - **Verify:** unit test asserts state assignment works when player buff registry reports active.

- [ ] **Task 2.3: Add `SacAuraFireSpam` strategy (or rename BacklashShadowBolt if appropriate)**
  - **File:** `EaxRotations/classes/warlock/destruction_sylvanas.lua`, after line 99 (`BacklashShadowBolt`).
  - **Strategy:** When `state.has_backdraft` is true and Soul Fire / Shadow Bolt are off GCD, cast the instant-cast variant.
  - **Acceptance:** new strategy `BackdraftSoulBolt` registered, fires only when `state.has_backdraft = true`, preempts regular filler rotation.
  - **Verify:** `find_strategy("BackdraftSoulBolt")` non-nil in `test_destruction_custom_matches.lua` after Phase 5.

- [ ] **Task 2.4: FIX the summon predicate — split summon strategies per spec-preferred pet**
  - **File:** `EaxRotations/classes/warlock/destruction_sylvanas.lua`, lines 115-120.
  - **Problem:** all 5 pet summon actions share one `summon_pet_matches` predicate registered via the `elseif action.name == "SummonImp" or ...` branch (line 343) — Destruction defaults to Imp.
  - **Fix strategy options (ranked):**
    1. **Preferred:** Destruction spec uses ONE summon strategy — `SummonPet` action resolving to spec-preferred pet via context.settings.destruction_preferred_pet or hardcoded per-spec.
    2. **Acceptable:** keep 5 separate strategies matched by `is_spell_learned` to gate each.
    3. **Avoid:** blindly registering all 5 — re-summons loop after DS.
  - **Acceptance:** when player has no pet AND has Demonic Sacrifice aura active (imp-sac firebuff `18789` is present), In-combat re-summon logic must be locked. Add gate: `if NS.has_player_buff(DEMONIC_SACRIFICE_AURA)` then return false.
  - **Verify:** test verifying "SummonPet does NOT fire when DS aura on player".

- [ ] **Task 2.5: Add a no-arg `SummonPet` strategy that picks the spec-preferred pet in middleware**
  - **File:** `EaxRotations/classes/warlock/destruction_sylvanas.lua`
  - **Position:** Add new strategy "SummonPet" (not "SummonImp") with `requires_target = false`, `ooc = true`, match predicate that checks `NS.has_pet() == false` and check optional setting.
  - **execute:** delegate to a helper that picks `SummonImp | SummonVoidwalker | SummonSuccubus | SummonFelhunter | SummonFelguard` based on context.settings.destruction_preferred_pet or fallback Imp.
  - **API Used:** `NS.has_pet`, `NS.try_cast`, `NS.is_spell_learned`.
  - **Acceptance:** strategy registered, summon predicate uses `not NS.has_pet()` not `pet == nil`, with `(or false)` nil-guard per Pattern 14.
  - **Verify:** lua load succeeds, `find_strategy("SummonPet")` non-nil.

- [ ] **Task 2.6: Mirror change in `destruction_vanilla.lua` line 80**
  - **File:** `EaxRotations/classes/warlock/destruction_vanilla.lua`, around line 80.
  - **Note:** vanilla is not in the rotation test fixtures (`run_rotation_tests.lua` runs `*_sylvanas.lua` only per its conventions). But the parity rule in AGENTS.md requires consistency.
  - **Verify:** `luac -p` passes; manual code review.

### Phase 3: Fix Middleware (Per-Pet Demonic Sacrifice Dispatch)

- [ ] **Task 3.1: Refactor `Warlock_DemonicSacrifice` strategy into `Warlock_DemonicSacrifice_<Spec>_<Pet>` family**
  - **File:** `EaxRotations/classes/warlock/middleware_sylvanas.lua`, lines 323-342.
  - **Current state:** hardcoded to `18788` with HP<20% gate.
  - **New design:** the emergency defensive is correct (player HP<threshold, sacrifice for instant buff). But per-spec preferred-pet dispatch is needed:
    - Destruction → Sacrifices Imp for Burning Wish (fire damage +%). Trigger not HP-based — trigger when entering combat AND Demonology actively summoned.
    - Demonology → Sacrifices any non-Felguard pet when Felguard is the spec target. May also be HP-emergency.
    - Affliction → Sacrifices Imp for Burning Wish (alternate) or Voidwalker for HP sustain.
    - Leveling → HP-gated fallback at 20%.
  - **Implementation:**
    - Gate the existing `Warlock_DemonicSacrifice` on `not context.has_demonic_sacrifice_buff` and `not NS.spell_action.is_prepared(DEMONIC_SACRIFICE_AURA_IMP)`.
    - Add 4 named strategies: `DemonicSacrifice_Imp`, `DemonicSacrifice_Voidwalker`, `DemonicSacrifice_Succubus`, `DemonicSacrifice_Felhunter` registered in the spec files (Phase 2 / 4) to take priority.
  - **Acceptance:** each spec file owns its preferred-pet sacrifice; middleware retains emergency fallback.
  - **Verify:** unit tests verify spec-specific strategies dispatched (per-spec test fixture).

- [ ] **Task 3.2: Add per-spec pet-preference setting in `schema_sylvanas.lua`**
  - **File:** `EaxRotations/classes/warlock/schema_sylvanas.lua`
  - **Insert:** Add a `{ key = "destruction_preferred_pet", type = "dropdown", ..., options = {imp/void/succ/felhunt/felguard} }` under Destruction tab; similar for demonology / affliction.
  - **Note:** adds new menu items — per AGENTS.md "Ask before adding new menu items" — **escalate to user before implementing**.
  - **If approved:** settings key `spec._preferred_pet` consumed in spec files via `context.settings.<key>` (Pattern 8).

---

### Phase 4: Fix Other Specs & Leveling

- [ ] **Task 4.1: Add OOC `SummonFelhunter` strategy to `affliction_sylvanas.lua`**
  - **File:** `EaxRotations/classes/warlock/affliction_sylvanas.lua`, insert before line 921 (strategy block end).
  - **Predicate:** `not in_combat AND not has_pet AND Felhunter learned`.
  - **Pattern 14:** nil-guard `state.pet_alive` with `or false`.
  - **API:** `NS.has_pet`, `NS.try_cast(SPELLS.SummonFelhunter, NS.PLAYER_UNIT, ...)`
  - **Acceptance:** strategy registered, does NOT fire in combat.
  - **Verify:** unit test confirms strategy exists.

- [ ] **Task 4.2: Add OOC `SummonImp` fallback to `demonology_sylvanas.lua`**
  - **Current:** `SummonFelguard` is summoned OOC when out of combat (line 380). Add OOC `SummonImp` fallback if Felguard not learned.
  - **File:** `EaxRotations/classes/warlock/demonology_sylvanas.lua`
  - **Insert:** new strategy before Felguard strategy that tries SummonImp if both Felguard and Felhunter not learned.
  - **Acceptance:** Augment the existing `needs_felguard` predicate or add new `SummonFallbackPet`.
  - **Verify:** unit test verifies new strategy.

- [ ] **Task 4.3: Add a Sac: Succubus option to Demonology as alternate**
  - **Optional per design discussion.** Adds `DemonicSacrifice_Succubus` strategy in demonology spec, fired when player has Succubus summoned AND in combat.
  - **Decision defer:** include or omit; safe default = omit (don't break current Demonology behaviour).

- [ ] **Task 4.4: Fix `leveling_sylvanas.lua` summon `in_combat` gate**
  - **File:** `EaxRotations/classes/warlock/leveling_sylvanas.lua`, line 176: `if not state.in_combat then return false end`.
  - **Bug:** summoning is currently combat-only, but pet could die before a fight starts.
  - **Fix:** Change to OOC-friendly: `if state.in_combat then return false end` (note `not` is currently in place — line is saying "fail IF NOT in combat", which means it requires in_combat → so it's COMBAT-only. Change the condition.)
  - **Re-read line:** `if not state.in_combat then return false end` means "if NOT in_combat, return false" — meaning summoning requires `state.in_combat == true`, i.e. combat-only.
  - **Fix:** Either (a) allow OOC, OR (b) allow OOC only if the pet was recently dead (use `context.pet_was_dead` flag, OR time-based "pet disappeared within last X seconds"). Safe choice: add OOC summon alongside combat summon — OOC case re-summons if pet missing. Conditions:
    ```lua
    if context.pet and context.pet:is_valid() then return false end  -- already has live pet
    if not state.target then return false end                        -- safety: only engage in combat zones
    if state.in_combat then return true end                          -- combat resummon
    -- OOC: only if we have a soul shard (cost)
    if NS.has_item and NS.has_item(6265) then return true end
    return false
    ```
  - **Acceptance:** SummonPet matches OOC if pet missing and a soul shard is held.
  - **Verify:** new unit test `test_leveling_warlock.lua` extended to cover OOC case.

- [ ] **Task 4.5: Audit `affliction_sylvanas.lua` `state.pet_alive` & `state.pet_health` tracking precision**
  - **Pattern 14:** in `build_state` lines 173-181 — verify the `or false / or 100` defaults are correct under nil pet.
  - **Note:** no functional change needed unless a state field elsewhere omits the nil-guard.

---

### Phase 5: Tests (RED → GREEN)

> Test files use the IZI/ns-mock fixture pattern established in `test_destruction_custom_matches.lua`. Inspect test_warlock_imp_machine_gun_2026_06.lua for RED-test template.

- [ ] **Task 5.1: RED test fixture — "sacrifice should fire for Destruction with Imp summoned in combat"**
  - **File:** new `EaxRotations/tests/test_destruction_demonic_sacrifice.lua`
  - **Mock setup:** `NS.WarlockSpells.DemonicSacrifice = 18788`; `NS.has_pet()` returns true; `NS.has_player_buff({18789})` returns false (pre-sacrifice state); build_state returns meaningful state.
  - **Expected:** `find_strategy("DemonicSacrifice_Imp")` returns a strategy whose `matches()` evaluates to `true` under those conditions.
  - **Initial state:** RED — strategy does not exist yet.
  - **Verify:** `lua EaxRotations/tests/test_destruction_demonic_sacrifice.lua` exits non-zero on initial run.

- [ ] **Task 5.2: RED test — "summon predicate skipped when DS aura active"**
  - **File:** new `EaxRotations/tests/test_destruction_summon_loop.lua`
  - **Mock setup:** `NS.has_pet() = false` AND `NS.has_player_buff(DEMONIC_SACRIFICE_AURA) = true`.
  - **Expected:** `find_strategy("SummonPet").matches()` returns **false**.
  - **Initial state:** RED — strategy still fires unconditionally.
  - **Verify:** test fails on initial run, passes after Phase 2.4 fix.

- [ ] **Task 5.3: RED test — "Backdraft proc tracked in destruction state"**
  - **File:** extend `test_destruction_custom_matches.lua`
  - **Mock setup:** `NS.has_player_buff(BACKDRAFT_BUFF) = true`.
  - **Expected:** `build_state(context)` returns table with `state.has_backdraft == true`.
  - **Initial state:** RED — currently returns false (literal assignment).
  - **Verify:** test fails on initial run, passes after Phase 2.2 fix.

- [ ] **Task 5.4: GREEN test — "Imp-favored summon sequencing"**
  - **File:** new `EaxRotations/tests/test_destruction_imp_first.lua`
  - **Mock setup:** `NS.is_spell_learned(688) = true`; `NS.has_pet() = false`; `NS.has_player_buff(DS_AURA) = false`.
  - **Expected:** execute runs in order — Destruction summons Imp (or whatever spec preference) when no pet exists.
  - **Verify:** test passes after Phase 2.4 / 2.5.

- [ ] **Task 5.5: GREEN test — "Affliction has SummonFelhunter OOC strategy"**
  - **File:** extend `test_warlock_imp_machine_gun_2026_06.lua` or new test file.
  - **Pattern:** mirror what existing RED/green test fixture does.

- [ ] **Task 5.6: GREEN test — "Leveling summon OOC works with soul shard"**
  - **File:** extend `EaxRotations/tests/test_leveling_warlock.lua`.

- [ ] **Task 5.7: GREEN test — "DemonicSacrifice middleware dispatched per-spec when imp sac active on destruction"**
  - **File:** new `EaxRotations/tests/test_warlock_demonic_sacrifice_dispatch.lua`
  - **Mock setup:** middleware loads; for context with `playstyle = "destruction"` AND `NS.has_player_buff(18789) = false` AND pet exists; expect match.

---

### Phase 6: Polish & Documentation

- [ ] **Task 6.1: Update header comment of `EaxRotations/shared/pet_manager_sylvanas.lua`**
  - **File:** line 2: change `Shared Helper: Pet Manager (Hunter)` → `Shared Helper: Pet Manager (Hunter + Warlock)`.
  - **Acceptance:** header reflects both consumers.

- [ ] **Task 6.2: Add `M.get_current_pet_type()` helper to `pet_manager_sylvanas.lua`**
  - **Why:** allows specs to detect "is_imp" / "is_voidwalker" / "is_felguard" without exposing `IZI` everywhere.
  - **API:** reads from `pet_handler` or `core.object_manager.get_local_pet():get_creature_family()`.
  - **Acceptance:** function returns string `imp / voidwalker / succubus / felhunter / felguard / unknown`.
  - **Verify:** unit test (extending `test_pet_happiness.lua` if it exists).

- [ ] **Task 6.3: AGENTS.md note for Pattern update**
  - **File:** `AGENTS.md`
  - **Action:** if a new state idiom emerges (e.g., "Backdraft proc-state read"), add it under Pattern 14 defaults.
  - **Optional** — defer unless code stabilizes.

- [ ] **Task 6.4: Update `plans/_active.md` to mark this plan complete**
  - **File:** `plans/_active.md`
  - **Action:** once all 6 phases pass, move `plans/warlock-imp-sac-backdraft-fix.md` to `plans/_archive/` and remove the row.

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Backdraft ID unverified — plan progresses without ground truth | Strategy fires incorrectly or never | Phase 1 Task 1.1 is gated; do not proceed to Phase 2.2 until ID confirmed. |
| User-supplied IDs (18787 / 18789 / 18790 / 30147) mistakenly entered as DS spell IDs | Wrong spell cast, no effect, log spam | Phase 0 calls out the error; Phase 5 tests assert DS spell ID = 18788 only. |
| `NS.has_pet()` returns nil after `MaxGilroy` engine state change | Re-summon loop returns | Pattern 14 nil-guard `(or false)`. |
| Adding new menu items (`destruction_preferred_pet`) | Per AGENTS.md "Ask First" | Phase 3.2 is gated on user confirmation. |
| `SummonPet` strategy collides with existing SummonX actions | Both fire, double summon | Plan: delete / disable the redundant SummonImp / SummonVoidwalker / SummonSuccubus / SummonFelhunter / SummonFelguard actions in Destruction spec (Task 2.5); keep spec-level SummonPet. |
| `NS.has_player_buff` not present in some test fixtures | State stays false | Provide mock fallback in test file (Pattern of `test_destruction_custom_matches.lua`). |
| Backdraft test-fixture writes to global state across tests | Cross-test contamination | Use `setup_each` style reset in test file (or `dofile` reload, already pattern that reset NS handlers). |

---

## Phase Acceptance Wicket

After all phases complete:

1. `luac -p` must pass on every modified `.lua` file (mandatory per AGENTS.md).
2. `lua EaxRotations/tests/run_rotation_tests.lua` — **all 127 rotation suites pass** (29 specs × multiple themes).
3. `lua EaxRotations/tests/run_leveling_tests.lua` — **all 11 leveling suites pass**.
4. `lsp_diagnostics` clean on all modified files (`errors == 0`).
5. No `fi` debug print leftovers, no `_DEBUG = true` left in production code.

---

## Confirmed IDs — Phase 1 Verified (2026-06-23)

| Effect | IDs | DBC Status |
|--------|-----|-----------|
| `Summon Imp` | `688` | ✅ In class_sylvanas.lua:239, bridge confirmed |
| `Summon Voidwalker` | `697` | ✅ In class_sylvanas.lua:240, bridge confirmed |
| `Summon Succubus` | `712` | ✅ In class_sylvanas.lua:241, bridge confirmed |
| `Summon Felhunter` | `691` | ✅ In class_sylvanas.lua:242, bridge confirmed |
| `Summon Felguard` | `30146` | ✅ In class_sylvanas.lua:243, bridge confirmed |
| `Fel Domination` | `18708` | ✅ In class_sylvanas.lua, bridge confirmed |
| **Demonic Sacrifice (castable)** | `18788` | ✅ Single castable spell |
| DS — Imp aura (Burning Wish) | `18789` | ✅ DBC, School=4(fire), DurationIndex=30 |
| DS — Voidwalker aura (Fel Stamina) | `18790` | ✅ DBC, School=32(shadow), DurationIndex=30 |
| DS — Succubus aura (Touch of Shadow) | `18791` | ✅ DBC, School=32(shadow), DurationIndex=30 |
| DS — Felhunter aura (Fel Energy) | `18792` | ✅ Present in bridge at line 8932 |
| DS — Felguard aura (Touch of Shadow) | `35701` | ✅ Present in bridge at line 20172 |
| Backdraft proc | **N/A** | ❌ **Backdraft is a Wrath talent — NOT in TBC DBC at all.** No candidates found for 47271, 35346, or 61082. Already documented in destruction_sylvanas.lua line 68-70. **Do NOT implement Backdraft strategies for TBC.** |

### Phase 1 → Phase 2 Impact

| Plan task | Status | Action |
|-----------|--------|--------|
| 2.1 (constants) | ✅ Already declared | `DEMONIC_SACRIFICE_AURA_ALL` at line 24, all 5 actions at lines 27-45 |
| 2.2 (state.has_backdraft) | ✅ Already there | Hardcoded `false` at line 70 — correct for TBC |
| 2.3 (BackdraftSoulBolt) | 🛑 **Skip — not in TBC** | No Backdraft talent exists |
| 2.4 (fix summon predicate) | ✅ DS gate present | `summon_pet_matches` line 302 already blocks on DS aura |
| 2.5 (SummonPet strategy) | ⚠️ 5 separate summons still | All 5 share same predicate (line 387-388). Functional but inelegant |
| 2.6 (destruction_vanilla.lua) | ✅ `has_backdraft` already at line 80 | No change needed |

**Revised scope**: The remaining gaps are:
- **Summon loop**: 5 separate SummonX actions all use same predicate — no actual loop bug (only the first match wins), but consolidate if desired
- **Phase 3** (middleware per-pet DS dispatch): verify middleware already handles correctly
- **Phase 4** (affliction/demo/leveling): verify OOC summon existence
- **Phase 5** (tests): add test coverage for DS and summon behavior

---

## Notes on Plan Format

- This plan lives at `plans/warlock-imp-sac-backdraft-fix.md`.
- Add a row to `plans/_active.md` upon start; remove + move to `_archive/` on completion.
- Per AGENTS.md Agent Contract §5: if a task loops more than 2 attempts, STOP and write a debugging note in `plans/` describing the failure instead of retrying.
- Per Agent Contract §3: one concern per commit. Suggested commit boundaries:
  - Commit 1: Phase 2 (Destruction fixes)
  - Commit 2: Phase 3 (Middleware refactor)
  - Commit 3: Phase 4 (Other specs + leveling)
  - Commit 4: Phase 5 (Test fixtures — RED→GREEN)
  - Commit 5: Phase 6 (Polish)
