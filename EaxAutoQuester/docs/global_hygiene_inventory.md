# Global-hygiene inventory (EaxAutoQuester production code)

The defect class the navigation A/B proved real: a name that is read or written as a global
because nobody declared it. This file is the per-site inventory the sweep produced, with a
verdict for each site and the reasoning for the sites deliberately left alone.

## Method

`luac -p -l -l` (the pinned Lua 5.1 compiler) over **all 49 production files** — the plugin
root, `quest_state/*`, `shared/*`, and the seven generated `npc_spawns/chunk_*.lua` data files.
`GETGLOBAL` and `SETGLOBAL` instructions carry `[line]` in that listing, and every function's
`locals` table names its locals, so each site gets a file, a line, and its op.

One trap, recorded because it produced a wrong first answer: **luac prints a function's
instructions before that function's `locals` block.** Pairing each instruction run with the
*preceding* table attributes every nested function's globals to its parent, which silently
hides the read-before-declaration class (the first pass reported "none flagged" for exactly
that reason). Each run must be paired with the locals table that *follows* it.

Totals: **1451 global sites, 15 distinct names** — all of them base library or documented API.
No plugin-internal name is read or written as a global anywhere in production code.

## Fixed — accidental (this sweep)

### A. Bare global function definitions (16 definitions, 3 files)

Each was `SETGLOBAL` at its definition and `GETGLOBAL` when the module's export table was
built. No other file references any of these names (checked repo-wide, including string
literals), and the module's own export table reaches them as fields of a local `M`, so all 16
became `local function`:

| File | Definitions |
|---|---|
| `questie_reader_sylvanas.lua` | `M_get_quest_npc_ids:81`, `M_get_quest_npc_positions:93`, `M_get_quest_objectives:146`, `M_get_quest_locations:174`, `M_find_nearest_quest_unit:202`, `M_is_loaded:242` |
| `zygor_reader_sylvanas.lua` | `M_get_current_step_info:90`, `M_get_current_waypoint_world:104`, `M_get_step_waypoints_world:125`, `M_get_current_waypoint_raw:155`, `M_get_current_objectives:175`, `M_get_sticky_goals:201`, `M_has_current_step:228`, `M_is_loaded:239`, `M_get_next_waypoint_world:247` |
| `goal_resolver_sylvanas.lua` | `M_resolve_goal:201` |

`M_is_loaded` existed in **two** files, so as globals they clobbered each other: whichever
module loaded last owned the name for both. That is the collision argument for this whole
class — the same name in two sibling plugins would equally clobber.

### B. Global reads that were nil at runtime (the real bugs)

| Site | Read | Verdict |
|---|---|---|
| `quest_state/coordinator.lua:381` | `next_state` | **Fixed.** `local next_state` is declared at `:485`, so this read was a global nil and `nil ~= "IDLE"` was always true: the combat override fired unconditionally, and a stray `_G.next_state = "IDLE"` from anything else would have silently *disabled* it. Now compares `shared._state`, which is the state that actually exists at that point (dispatch runs after this branch returns). |
| `quest_state/do_action_state.lua:818` | `nearby_count` | **Fixed.** The local was declared at `:778` *inside* the `if enemy_pos` block, so the attack log one scope out read a name that was never declared or assigned anywhere — it always printed `nearby=nil`. The declaration is now hoisted above that block so the log reports the count the block measures. Log-only: no decision depended on it. |
| `quest_interaction_sylvanas.lua:246` | `_get_item_info` | **Fixed — load-bearing.** Declared nowhere; the call sat in a `pcall`, so every equipped item compared as **quality 0** in `auto_equip_best_reward`, making any reward of quality ≥ 1 look like an upgrade. Now uses the documented `core.quests.get_item_info(item_id_or_link)` (`.api/core.lua:4563`), the same cached function this file already uses for reward links. Pinned by `tests/test_auto_equip.lua` S10, which fails against the undeclared read. |

### C. Global round-trip (leak, not a nil read)

| Site | Name | Verdict |
|---|---|---|
| `quest_state/idle_state.lua:418`, `:420` (flight step) and `:444`, `:446` (hearth-set step) | `wp` | **Fixed.** `SETGLOBAL` immediately followed by `GETGLOBAL`, because the `local wp` that belongs to this function is declared at `:480` — far below both blocks. The value only ever travelled into `shared._nav_destination`, so both blocks now assign the flight master / innkeeper there directly. The leak created a plugin-wide `wp` global on those two paths. |

## Left as globals deliberately

| Sites | Name | Why it stays |
|---|---|---|
| 557 `pcall`, 170 `tostring`, 106 `_G`, 85 `math`, 84 `type`, 74 `require`, 44 `ipairs`, 13 `table`, 12 `string`, 9 `pairs`, 9 `rawget`, 9 `tonumber`, 2 `next`, 1 `unpack` | base library | The runtime's own environment; the plugin is a guest in it. `next` and `unpack` are 5.1 base functions (the compat gate documents the one live `unpack`). |
| 268 reads across 35 files | `core` | The documented API table (`.api/core.lua`), provided by the host. |
| 106 reads | `_G` | Every one is `_G.EaxAutoQuester` / `_G.EaxRotations` / `_G.SentinelNavClient` — field access on the documented plugin namespace, not a bare global read. The **only** global key the plugin creates is `EaxAutoQuester` itself, which check B of `tests/test_global_hygiene.lua` pins. |
| — | `menu` | Allowlisted in the static check because the host documents a `menu` global, but no production site reads it bare today (it is absent from this inventory's name list). |

## Text-check false positives, recorded so the next reader trusts the check

The static half of `tests/test_global_hygiene.lua` scans source text, so it sees shapes the
bytecode knows are locals. Each of these was investigated against the compiler and the check
was taught to excuse it:

| Shape | Example | Bytecode truth |
|---|---|---|
| forward-declared local defined with `function NAME(` | `json_loader.lua:193 parse_value` (`local parse_value` at `:67`) | `GETUPVAL`, not a global |
| reassigned function parameters | `npc_manager:284 range`, `:285 exclude_dead`, `questie_reader:203 range`, `service_gossip:80/114 wanted_services`, `idle_state:600 opos`, `do_action_state:183 named_found`, `quest_blacklist:56 _core_cpu_time`, `vendor_manager:102 count`, `:150 bought`, `:186/196/210 actions_taken`, `waypoint_fixer:16 _coords`, `zygor_reader:26 _waypoint_fixer`, `:213 count` | parameters are locals; no `SETGLOBAL` exists for any of them |
| a keyword consumed by the multi-assign pattern | `navigation_sylvanas.lua:619 end, { return_to_start = false })` matched as `end, … =` | `end` is a keyword |

## What this inventory cannot prove

- The static check cannot see a global write to a name that **also** has a legitimate local
  elsewhere in the file — the `wp` shape in section C. Only bytecode shows which of the two a
  given statement touches, which is why the table above is the record for it and why the
  runtime half of the suite (not the text half) is the general guard.
- The runtime tripwires cover the paths the suite drives (module load, and a coordinator
  combat tick). A global written only on a path no scenario exercises is invisible to them —
  for the record, the bytecode sweep is what makes that claim exhaustive today.
- The compiler used is the desktop 5.1 build pinned by the battery, not the in-game LuaJIT;
  `GETGLOBAL`/`SETGLOBAL` semantics are identical for this purpose, but that is an argument,
  not a measurement.
