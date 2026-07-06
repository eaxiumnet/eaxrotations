# Warlock Deep-Dive Audit & Fix — 2026-07-06

## Goal
Full audit of all 11 active Warlock Lua files (5,786 lines). Fix every crash, wrong-spell, and settings-mismatch bug. Ensure top parsing for solo/pet/dungeon/raid/PvP.

## Critical Bugs Found (verified)

### C1 — CRASH: `SUCC_LASH` undefined
- **File:** `classes/warlock/demonology_sylvanas.lua:114`
- **Impact:** When a non-Imp pet (Succubus/VW/Felguard) is out and `get_pet_spells()` succeeds, `ipairs(SUCC_LASH)` crashes — "attempt to index nil value (global 'SUCC_LASH')".
- **Fix:** Define `SUCC_LASH` constant (Lash of Pain ranks: 7814,7815,7816,7817,7818,7819,11770,11771,27268).

### C2 — CRASH: `core` global not NS-guarded
- **File:** `classes/warlock/demonology_sylvanas.lua:101`
- **Impact:** `core.spell_book` references the raw global; crashes if `core` is nil. Pattern 2 / middleware uses `NS.core`.
- **Fix:** Use `_G.core` nil-guarded via pcall or `NS.core`.

### C3 — WRONG SPELL: Shadowburn ID 17924 is Soul Fire
- **File:** `classes/warlock/affliction_sylvanas.lua` LOCAL_SPELLS
- **Impact:** `Shadowburn = { 30546, 27263, 18871, 17924, 17877 }` — 17924 is Soul Fire rank 1, not Shadowburn. Could cast the wrong spell.
- **Fix:** Use `{ 30546, 27263, 18871, 18870, 18869, 18868, 18867, 17877 }` (matches SPELLS table).

### C4 — CRASH: unguarded `NS.has_player_buff(NIGHTFALL_BUFF)`
- **File:** `classes/warlock/affliction_sylvanas.lua:234` + `affliction_vanilla.lua`
- **Impact:** If `NS.has_player_buff` is nil (broken API), build_state crashes every tick.
- **Fix:** `NS.has_player_buff and NS.has_player_buff(NIGHTFALL_BUFF) or false`.

### C5 — DEAD STRATEGY: duplicate `CurseOfAgony` in destruction_sylvanas ACTIONS
- **File:** `classes/warlock/destruction_sylvanas.lua:122,125`
- **Impact:** Two identical entries; second never fires. Wastes a dispatch iteration + confusing.
- **Fix:** Remove the duplicate.

### C6 — SETTINGS MISMATCH: healthstone UI setting doesn't work
- **Files:** affliction_sylvanas, destruction_sylvanas, demonology files
- **Schema key:** `healthstone_hp` (default 0)
- **Code reads:** `auto_healthstone` (undefined→always true) + `healthstone_hp_threshold` (undefined→fallback 30)
- **Impact:** User's Healthstone HP slider has NO effect; fires at hardcoded 30%.
- **Fix:** Read `settings.healthstone_hp` (the schema key); gate on `> 0` instead of `auto_healthstone`.

### C7 — MISSING SPELL: Curse of Shadow (raid debuff for Shadow damage)
- **Spell IDs:** 17862 (r1,44), 17937 (r2,56), 27229 (r3,67)
- **Impact:** Affliction/Demonology deal Shadow damage. Curse of Elements only covers Fire/Frost/Arcane. Curse of Shadow covers Shadow/Arcane. Missing = lost raid DPS.
- **Fix:** Add to SPELLS table + CurseOfShadow strategy in affliction/demonology.

### C8 — WRONG ORDER: Amplify Curse fires AFTER curses
- **File:** `classes/warlock/affliction_sylvanas.lua:737`
- **Impact:** Amplify Curse must be cast BEFORE the curse to benefit it. Currently after all curse strategies → never empowers the current cast.
- **Fix:** Move AmplifyCurse strategy before CurseOfDoom/CurseOfAgony.

## High-Priority Issues (functional)

### H1 — Destruction never Demonic Sacrifices (playbook W1)
- All 5 summon actions share one matcher that always picks Imp (first in list). No sac flow.
### H2 — Fragile `table.insert(strategies, N, ...)` hardcoded positions
- destruction_sylvanas: positions 7, 23, 25. Breaks silently if ACTIONS changes.
### H3 — Affliction Shadowburn at 5% (should be 20% via setting)
### H4 — Soulshatter at 90% threat (raids want 80-85%)
### H5 — Curse of Recklessness/Weakness in schema dropdown but never selected by select_curse
### H6 — No UA multi-DoT spread (only Corruption/Siphon/CoA have spread)

## Validation Gate
- `luac -p` on every changed file
- `lua EaxRotations/tests/run_rotation_tests.lua` (220 suites)
- `lua EaxRotations/tests/run_leveling_tests.lua` (13 suites)

## Status: IN PROGRESS
