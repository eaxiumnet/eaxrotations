# Position / visible-objects contract audit (2026-08-08)

**Scope:** every consumer of `get_position()` / `get_visible_objects()` in the
codebase (EaxRotations + EaxESP + crash/EAXFishing + test/ mirrors), checking
for the multi-value-capture truncation family that deaded prot `Intervene`
(see `docs/never_strategy_triage_dps_2026-08-07.md` and
`tests/test_intervene_lane_regression.lua`).

**Contract (verified 2026-08-08):** `game_object:get_position()` returns
**ONE** vec3 table `{x, y, z}` — `.api/game_object.lua:163`
(`---@field get_position fun(self: game_object): vec3`), corroborated by
shared/auto_loot (`p.x, p.y, p.z`), shared/targeting (`pos.x, pos.y, pos.z`),
EaxESP (`base.x or base[1]`), and the battery mocks (`.api`-conformant
`{x,y,z,[1],[2]}` tables). `core.object_manager.get_visible_objects()` returns
ONE `game_objects_table` (`.api/core.lua:1747`).

**Truncation family:** `local dx, dy = unit:get_position()` or the and-form
`local dx, dy = unit.get_position and unit:get_position()` — both dead lanes
because `get_position()` yields a single table, so `dx` = the table and
`dy` = nil; any downstream arithmetic on `dx`/`dy` as numbers is garbage.

## Verdict

**No new truncation-family bugs found.** The only instance was the prot party
scan + `Intervene` matcher, **already fixed** (protection:429-449, 774-788).
Every other consumer captures the single table and reads `.x`/`.y`/`.z`
fields, or passes the table through to table-form helpers. No code changes
required by this audit.

## get_position() consumers — read form

| File:line | Read form | Verdict |
|---|---|---|
| `classes/warrior/protection_sylvanas.lua:429-449` | `me:get_position()` → `pos.x/y/z` (existence-guarded) | ✅ fixed (was and-form multi-capture) |
| `classes/warrior/protection_sylvanas.lua:774-788` | `me:get_position()` / `ally:get_position()` → table fields | ✅ fixed (was and-form multi-capture) |
| `classes/shaman/enhancement_sylvanas.lua:1229,1267` | `me:get_position()` / `obj:get_position()` → `.x/.y` | ✅ table form |
| `classes/shaman/enhancement_vanilla.lua:882,920` | same as sylvanas enh | ✅ table form |
| `classes/warlock/destruction_sylvanas.lua:665-666` | `pos = get_position and target:get_position() or nil` → `try_cast_position` | ✅ single-table pass-through |
| `classes/warlock/destruction_vanilla.lua:413-414` | same as destro sylvanas | ✅ single-table pass-through |
| `classes/priest/middleware_sylvanas.lua:195` | `pos = enemy and enemy.get_position and enemy:get_position() or nil` → `try_cast_position` | ✅ single-table pass-through |
| `core_sylvanas.lua:667, 2448-2450, 2472-2473, 2491-2493, 2539, 2577, 2611, 4563-4565, 4784-4786, 5911-5913` | `pos`/`position` single captures → `spell_prediction`, `get_most_hits_position`, `unit_get_enemies_around` | ✅ all table form |
| `main_sylvanas.lua:535` | `pos = me and safe_field(me,"get_position") and me:get_position() or nil` → `get_enemy_list_around` | ✅ single-table pass-through |
| `shared/auto_loot_sylvanas.lua:173,571` | `p = obj:get_position()` → `p.x, p.y, p.z` | ✅ table form |
| `shared/pet_manager_sylvanas.lua:547` | `pcall(target:get_position)` → `try_cast_position` | ✅ table form |
| `shared/targeting_sylvanas.lua:272-273,290` | `pos = center:get_position()` → `pos.x/y/z` | ✅ table form |
| `shared/aoe_hit_volume_sylvanas.lua:62-63` | `pcall(unit.get_position)` → `p.x/p.y` type-checked | ✅ table form |
| `EaxESP/reader.lua:38-55` | `pcall` then **defensive dual-form**: table/userdata OR scalar x,y,z | ✅ handles both contracts |
| `EaxESP/main.lua:237` | `pcall(me:get_position)` → `.x/.y/.z` | ✅ table form |
| `EaxESP/terrain.lua:224-226` | `pcall(me.get_position)` → `is_finite(p.x/y/z)` | ✅ table form |
| `EaxESP/attachment_safe.lua:110-113` | `pcall(unit:get_position)` → `base.x or base[1]` | ✅ table form |
| `crash/EAXFishing/core/api_surface.lua:149-152` | `pcall` → checks `result.x`/`result.z` | ✅ table form |
| `crash/EAXFishing/ui/render.lua:80-105` | `pcall(me.get_position)` → `.x/.y/.z` | ✅ table form |
| `crash/EAXFishing/inventory/auto_loot.lua:78-84` | `p = obj:get_position()` → `p.x/y/z` | ✅ table form |
| `test/EaxProfessions/combat_helper.lua:119` | `me_pos = me.get_position and me:get_position()` → `squared_distance` (reads `.x/.y/.z`) | ✅ single-table capture |
| `test/EaxProfessions/professions/skin.lua:193-201` | `pcall(obj.get_position)` → `.x/.y/.z` | ✅ table form |

## get_visible_objects() consumers — read form

| File:line | Read form | Verdict |
|---|---|---|
| `core_sylvanas.lua:4662` (`NS.get_visible_units`) | `safe(...) or EMPTY` → iterates `#objects` | ✅ single table |
| `classes/shaman/enhancement_sylvanas.lua:1252` | `pcall(_get_visible_objects)` → `#objects` loop | ✅ single table |
| `classes/shaman/enhancement_vanilla.lua:905` | same as sylvanas enh | ✅ single table |
| `classes/warrior/protection_sylvanas.lua:196` | `pcall(_get_visible_objects)` → `#visible_objects` | ✅ single table |
| `shared/incoming_heal_predictor_sylvanas.lua:409` | `pcall(...)` → `ipairs(visible)` | ✅ single table |
| `shared/pet_heal_sylvanas.lua:132` | `pcall(om.get_visible_objects, om)` → `ipairs` | ✅ single table |
| `shared/targeting_sylvanas.lua:189` | `pcall(...)` → `#list` + `list[i]` | ✅ single table |
| `EaxESP/reader.lua:658` | `pcall(om.get_visible_objects)` → `add_from(vis)` | ✅ single table |
| `crash/EAXFishing/core/api_surface.lua:107-110` | `pcall(...)` → `type(result)=="table"` | ✅ single table |

Note: `NS.get_visible_units()` is a **wrapper** that returns `(visible, visible.n)`
— two values by design (core:4656, 4680); all 5 callers
(`core_sylvanas.lua:752, 4575, 4794, 4876, 4956, 4986` + `bear_vanilla.lua:268`)
correctly do `local units, count = NS.get_visible_units()`. No truncation.

## Also checked

- `obj:position()` fallback (`shared/auto_loot_sylvanas.lua:175`,
  `crash/EAXFishing/inventory/auto_loot.lua:79`, `EaxESP/reader.lua:50-51`):
  read as table (`p.x/p.y/p.z`); reader is defensive dual-form. ✅
- Distance helpers (`core_sylvanas.lua:4686` `distance`, `bear_vanilla.lua:188`
  `unit_distance`) use `distance_to()`/`distance()` methods, not
  get_position — outside this contract. ✅
- Battery + regression mocks return vec3 tables with `[1]/[2]` aliases
  (behavioral_audit:96-102, 1928; test_intervene_lane_regression:121-124;
  test_totemic_call_lane_regression:82-99). ✅

**Validation:** no code changed; battery still 100 never-firing / 31 specs /
0 load failures, `luac -p` clean on behavioral_audit.
