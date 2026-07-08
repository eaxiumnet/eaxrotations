# Plan: Audit Item #2 (movement_assist wiring) + #4a (boss immunity DB expansion + dead-code fix)

**Date:** 2026-07-07
**Status:** COMPLETE
**Scope:** Audit item #2 (wire movement_assist into try_cast) + item #4a (expand boss immunity DB + wire into evaluate_cast).

## Item #2 — movement_assist wiring

### Root cause (verified against source)
`movement_assist_sylvanas.lua` is loaded in `main.lua:1071` for the render callback, but:
1. **Never registered on `NS.MovementAssist`** — the module returns `M` but never does `NS.MovementAssist = M`.
2. So `core_sylvanas.lua:5775` (`local ma = NS.MovementAssist and NS.MovementAssist()`) always evaluates to nil → dead code.
3. Even if registered, `NS.MovementAssist()` treats the module as a *function* — but it's a *table* (wrong call style).
4. The assist call only exists in the `skip_gcd` branch of `action_execute`, NOT in `NS.try_cast` (the universal cast path used by ALL 29 specs via their execute functions).

### Fix
1. `movement_assist_sylvanas.lua`: register `NS.MovementAssist = M` at end (before `return M`).
2. `core_sylvanas.lua` `NS.try_cast`: after `evaluate_cast` passes (cast is committed), call `NS.MovementAssist.face_for_spell(id, target)` so cast-time spells auto-face/pause. Guarded: only fires when movement_handler available + cast_time > 0.1s (instants are skipped by the module itself).

## Item #4a — boss immunity DB expansion + wiring

### Root cause (verified against source)
1. `get_target_school_immunities()` in `main_sylvanas.lua:270` is **dead code** — defined but NEVER called. `evaluate_cast` has immunity checks for player buffs (Divine Shield/Ice Block/BOP/Cloak/WotF/BerserkerRage) but **no boss school-immunity check at all**.
2. Al'ar (19514) comment says "removed: not actually fire immune" but DBC `creature_template.json` proves **SchoolImmuneMask=4 (fire)** — it IS fire-immune. The comment was wrong.

### DBC-verified data (SchoolImmuneMask from creature_template.json)
| NPC ID | Boss | Mask | Schools | Status |
|--------|------|------|---------|--------|
| 15691 | The Curator (Kara) | 64 | arcane | ✅ existing entry correct |
| 19514 | Al'ar (TK) | 4 | fire | 🔴 BUG: comment wrong, IS fire-immune |
| 21216 | Hydross (SSC) | 0 | (phase mechanic) | keep nature (phase judgment) |
| 19516 | Void Reaver (TK) | 0 | (spell reflect) | keep arcane (mechanic judgment) |
| 17767 | Rage Winterchill (Hyjal) | 0 | (undead type) | keep frost (type judgment) |

All other TBC raid bosses (Gruul, Magtheridon, Vashj, Kael, Naj'entus, Supremus, Teron, Shahraz, Illidan, Brutallus, M'uru, Kil'jaeden, etc.) have **Mask=0** — no static school immunity. The 5 entries above are the complete set of relevant TBC boss school immunities.

### Fix
1. Move `BOSS_SCHOOL_IMMUNITIES` from `main_sylvanas.lua` to `core_sylvanas.lua` (where `evaluate_cast` lives) as `NS.BOSS_SCHOOL_IMMUNITIES`.
2. Add Al'ar (19514) fire entry (fix the wrong comment).
3. Wire `NS.is_boss_school_immune(target, school)` into `evaluate_cast` section 5 (target immunity gating).
4. Keep `get_target_school_immunities` in main_sylvanas.lua delegating to NS (backward-compat) OR remove it as dead code.

## Validation gate
- `luac -p` on all changed files.
- `run_rotation_tests.lua` (242/242) + `run_leveling_tests.lua` (13/13).
- New test: `test_boss_school_immunity.lua` + `test_movement_assist_wiring.lua`.

**Date:** 2026-07-07
**Status:** IN PROGRESS
**Scope:** Two audit items in one commit-cluster (related: both fix "defined but never wired" subsystems).

## Item #2 — movement_assist_sylvanas.lua wiring

### Problem (3 bugs)
1. `movement_assist_sylvanas.lua` never sets `NS.MovementAssist` — the module is returned but
   not registered on the namespace. `core_sylvanas.lua:5775` reads `NS.MovementAssist` → always nil.
2. The call site at `core_sylvanas.lua:5775` calls `NS.MovementAssist()` (treating a *table* as a
   *function*), and uses colon-call `ma:face_for_spell(id, target)` which shifts args (ma becomes self).
3. The call site is ONLY in the `skip_gcd` branch of `action_execute`. The primary cast path used by
   ALL specs is `NS.try_cast` (core_sylvanas.lua:2182), which has NO movement assist at all.

### Fix
1. In `movement_assist_sylvanas.lua`: register `NS.MovementAssist = M` before `return M`.
2. In `core_sylvanas.lua` `NS.try_cast` (~line 2220, after LOS check, before spell_queue dispatch):
   add a movement_assist call for cast-time spells (using `M.get_cast_time(id)` to skip instants).
3. Fix the `skip_gcd` call site (core_sylvanas:5775) to use the registered table correctly.

## Item #4a — Boss School Immunity DB

### Problem (2 bugs)
1. `get_target_school_immunities` (main_sylvanas.lua:270) is **dead code** — defined but never
   called by `evaluate_cast` or anywhere else. The entire boss-immunity subsystem is non-functional.
2. Al'ar (19514) has a comment "removed: not actually fire immune in TBC" but DBC data proves
   SchoolImmuneMask=4 (fire) — it IS fire-immune. The comment was wrong.

### DBC verification (creature_template.json SchoolImmuneMask)
| NPC ID | Boss | Mask | Decoded | Existing entry | Action |
|--------|------|------|---------|----------------|--------|
| 15691 | The Curator (Kara) | 64 | arcane | `{arcane=true}` | ✅ Keep (confirmed) |
| 21216 | Hydross (SSC) | 0 (DmgSchool=4) | — | `{nature=true}` | Keep (phase-conditional; judgment) |
| 19516 | Void Reaver (TK) | 0 | — | `{arcane=true}` | Keep (spell-reflect; judgment) |
| 17767 | Rage Winterchill (Hyjal) | 0 | — | `{frost=true}` | Keep (undead-type; judgment) |
| 19514 | Al'ar (TK) | **4** | **fire** | *"removed: not fire immune"* | 🔴 ADD `{fire=true}` |

Note: Most TBC raid bosses have SchoolImmuneMask=0 in the DB because their immunities are
*phase-conditional* (Hydross switches nature/frost, Void Reaver reflects) rather than static flags.
The 4 hardcoded entries represent sound mechanic judgments, not raw DB extracts. Only Al'ar is a
confirmed-data correction.

### Fix
1. Add Al'ar (19514) `{ fire = true }` and fix the misleading comment.
2. Wire `get_target_school_immunities` into `NS.evaluate_cast` (school-immunity gate, step 5e).
3. Expose `NS.get_target_school_immunities` on the namespace so evaluate_cast can call it.
4. Add a unit test for both the Al'ar fire-immunity gate and the movement_assist registration.

## Validation
- `luac -p` on all modified files.
- `run_rotation_tests.lua` (242/242) + `run_leveling_tests.lua` (13/13).
- New test: `test_boss_school_immunity.lua` (direct test of the gate).
- New test: extend `test_movement_assist.lua` or new `test_movement_assist_wiring.lua`.
