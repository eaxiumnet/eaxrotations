# Runtime sandbox audit — host functions vs. what the runtime documents

**Question.** The plugin runs in the game's Lua sandbox, not a desktop interpreter. Does any
production code depend on a host function the runtime may not expose?

**Method.** Two independent passes, not a grep:

1. **Bytecode-exact inventory** — `luac -l -p` over every production file, collecting every
   `GETGLOBAL` / `SETGLOBAL`. This cannot miss a host table reference and cannot invent one from
   a comment or string (unlike a text scan).
2. **Per-site adjudication** against the runtime's own sources, in this order:
   `.api/core.lua` (the API stubs the client actually implements) and `scraped_docs_md/dev/`
   (the published docs). A call is only left unguarded when one of those shows it as available.

Scope: `EaxAutoQuester/**/*.lua` excluding `tests/`, `docs/` and the generated `npc_spawns/` data.

## Verdicts

| Site | Call | Verdict | Evidence |
|---|---|---|---|
| `quest_blacklist_sylvanas.lua:40` (before) | `os.clock() * 100` | **Not documented → GUARDED** | `.api/core.lua:655-664` — `core.get_local_time()` exists because "*in sandboxed Lua `os.date()` / `os.time()` are unavailable*". No `os.*` call appears anywhere in the published addon docs. The `os` table therefore cannot be assumed, and the fallback also had a unit bug (`core.time()` is seconds; `* 100` made it centiseconds, shrinking the 60 s window to 0.6 s). **Removed**; replaced by `core.cpu_time()/1e9` (same unit) and, when no clock API exists at all, a monotonic tick counter. |
| `quest_blacklist_sylvanas.lua` (clock, preferred path) | `core.time()` | Documented | `scraped_docs_md/dev/api/core.md:713-736`, `.api/core.lua:229-231` ("seconds since the injection time"). Unchanged — production behaviour is identical. Same call already used at `mount_manager_sylvanas.lua:100` and `progress_tracker_sylvanas.lua:86`. |
| `quest_blacklist_sylvanas.lua` (new fallback) | `core.cpu_time()` | Documented | `scraped_docs_md/dev/api/core.md:805-811`, `.api/core.lua:247-249` (nanoseconds). |
| `quest_state/coordinator.lua:227-232`, `quest_state/idle_state.lua:12` + 70 refs | `require("…")` | Documented | The platform's own examples load modules this way: `scraped_docs_md/dev/api/assets-helper.md:112,233,241`. |
| `json_loader.lua` (via `core.read_data_file`) | file read | Documented | `scraped_docs_md/dev/api/file-io.md:64,99,486` — sandboxed reads, paths restricted to the game/`scripts_data` sandbox. No host `io.*` is used by production code. |
| 102 refs | `_G` | Documented | `scraped_docs_md/dev/api/sentinel-navigation.md:64,87,103` (`_G.SentinelNavClient`), `scraped_docs_md/dev/examples/nav-follower.md:169` (`_G.NavLib`). |
| 547 `pcall`, 170 `tostring`, 64 `type`, 44 `ipairs`, 9 `pairs`, 9 `rawget`, 8 `tonumber`, 1 `next`, 1 `unpack` | base library | Documented (5.1 base) | Docs examples use the same base surface, e.g. `core.md:382` (`string.format`), `plugin-helper.md:971` (`table.insert`), `file-io.md:507` (`ipairs`). No guard added. |
| 86 `math.*`, 16 `string.*`, 13 `table.*` | base library | Documented | Same as above; only base members are used (`math.floor/min/max/abs/rad/cos/sin/log/random`, `string.format/char/find/lower`, `table.concat/insert`). |
| — | `io.*`, `debug.*`, `lfs`, `coroutine.*`, `dofile`, `loadfile`, `loadstring`, `load(str)`, `collectgarbage`, `string.dump`, `os.*` | **Zero references** | Bytecode-exact: these names never appear as a global in production code. |

Net result: **one guarded site**, everything else confirmed available and left alone — no defensive
layers were added for documented functions.

## Not a sandbox issue, recorded because the inventory surfaced it — now CLOSED

The same bytecode pass showed plugin-internal state living in the **global** namespace:
`_stuck_level`, `_stuck_attempts`, `_stuck_recovery_timer` (`navigation_sylvanas.lua`) and
`wp` / `next_state` / `nearby_count`, plus global function definitions such as
`M_resolve_goal` (`goal_resolver_sylvanas.lua:201`) and `M_is_loaded`
(`questie_reader_sylvanas.lua:242`, `zygor_reader_sylvanas.lua:239`).

The follow-up landed: **all of these are locals now**, and the correction to this note is that
they did *not* "resolve fine today" — `_stuck_attempts` crashed the fallback stuck ladder with
`attempt to perform arithmetic on global '_stuck_attempts'`, and `next_state` / `nearby_count`
were nil reads (`next_state` made the coordinator's combat override unconditional; `nearby_count`
printed nil). `navigation_sylvanas.lua` also gained a fourth undeclared read that this note never
saw, `_get_item_info` in `quest_interaction_sylvanas.lua:246`, which silently forced every
equipped item to compare as quality 0 during auto-equip.

The full per-site inventory, the verdict for each site, the names deliberately left as globals
and the text-check false positives are in `docs/global_hygiene_inventory.md`. The regression
guard is `tests/test_global_hygiene.lua` (static bare-global checks plus runtime `_G`
read/write tripwires and the coordinator's poisoned-global pin).

## Tests

`tests/test_quest_blacklist.lua` S6-S9 exercise the guarded paths by re-requiring the module with
a stubbed `_G.core`: `core.time()` in seconds (S6, including the 70 s-apart case that a call
counter would get wrong), `core.cpu_time()` nanoseconds scaled to seconds (S7), no clock API →
tick counter (S8), and `core` absent entirely → no error (S9). S1-S5 pin the unchanged
documented-API behaviour.
