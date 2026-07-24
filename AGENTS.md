# EAX TBC Classic Rotations — Agent Context

> ## ⚠️ THIS IS THE SINGLE SOURCE OF TRUTH
> This file (`AGENTS.md` at the repo root) is the **only** agent-instruction file for
> the EAX codebase. Any `CLAUDE.md`, `.cursorrules`, or per-tool prompt that says
> otherwise is stale — read **this file first**, always. Do not rely on memorized
> spec/test counts or data paths; the numbers below are authoritative as of the
> "Last Updated" line. Reference-system clones (`tbc-main/`, `_external_tbc_explore/`,
> `tbc_roblox/`, `ClassResearchTBC/`, `EaxESP/`) are **external** and out of scope.

**Repo**: https://github.com/eaxiumnet/eaxrotations
**Local Path**: `C:\newbot\scripts`
**Last Updated**: 2026-07-22
**Specs**: 29 TBC Classic class specializations (all 29 completed)
**Tests**: 382 rotation suites registered in `run_rotation_tests.lua` + 23 leveling suites in `run_leveling_tests.lua` (405 total)

---

## Agent Contract (mandatory for all AI tools)

1. **Read this file first.** Ignore `CLAUDE.md`/`EaxRotations/CLAUDE.md` content beyond their pointer line.
2. **Plans live in one place:** `plans/`. Check `plans/_active.md` before starting any work. Create exactly one plan per effort. Completed/abandoned plans move to `plans/_archive/`.
3. **One concern per commit.** Never bundle unrelated changes.
4. **Before marking any task complete:** run `luac -p` on changed files AND `lua EaxRotations/tests/run_rotation_tests.lua`. Both must pass.
5. **If a task loops more than 2 attempts, STOP.** Write a debugging note in `plans/` describing the failure instead of retrying. Looping is the failure mode this contract exists to prevent.
6. **Never edit reference-system clones** (`tbc-main/`, `_external_tbc_explore/`, etc.) — they are external inspiration, not our code.

## Agent Operating Charter (META v2.0)

The full "Principal Architect Charter" (Bias, META-0, R1–R11, Zero-Pause Execution Layer)
is preserved at `EaxRotations/CLAUDE.md.charter.md`. It is invoked when a task prompt
contains a "Zero-Pause" trigger phrase. For day-to-day work the summary above
(Bias toward decisive, test-covered, reversible action; R5 execution-as-ground-truth;
R6 tests-encode-contracts) is the operating mode.

---

## Project Identity

**What**: 29 WoW TBC Classic rotation plugins for Project Sylvanas targeting **TBC Classic Anniversary (2.5.x)** which runs on its **own client (2.5.5.x)**. Flat `_sylvanas.lua` files under `EaxRotations/classes/<class>/`. Shared logic in `EaxRotations/shared/`.

**Critical: TBC Classic Anniversary is NOT 2.4.3**. It runs on its own **2.5.5.x client** (not Wrath 3.3.5). However, some Wrath-era spells were **backported** into the 2.5.5 client (e.g., Ice Lance 30455, Seal of Blood 31892, Seal of the Martyr 348700) — these ARE valid. Always verify spell existence against the **DBC** (`wowheadScrape/dbc_extract/wowsims.db`) and cross-check with **lexxer.org/api/v1/spells/{id}?game=tbc** before classifying anything as "WotLK-only". The DBC is the **authoritative source of truth**. The `wowhead_data/spells/tbc/` JSON cache is supplementary detail data.

**Hard Constraints**:
- TBC-era content + **TBC Anniversary 2.5.5 spells** — do NOT remove spells just because they seem "WotLK". Verify against DBC + lexxer.org first.
- All menu references must be nil-guarded to prevent crashes
- `luac -p` must pass on every modified file
- All 29 specs must pass `lua EaxRotations/tests/run_rotation_tests.lua` and `lua EaxRotations/tests/run_leveling_tests.lua`
- Only Project Sylvanas API (`api/`, `apidocs/`) — no external platforms

---

## Key Directories

```
EaxRotations/
├── main_sylvanas.lua          # Main rotation engine, dispatcher
├── core_sylvanas.lua          # NS helpers (buff_points, spell_ready, etc.)
├── classes/<class>/<spec>_sylvanas.lua  # 29 spec files (flat, one per spec)
├── shared/                    # ~50 shared modules (interrupts, consumables, etc.)
├── tests/                     # ~394 test files (373 rotation + 21 leveling suites)
└── tools/                     # Build/validation scripts

api/                           # Sylvanas API definitions (runtime, .gitignored)
├── core.lua                   # Core callbacks, time, logging
├── game_object.lua            # Unit/entity access
└── common/                    # buff_db, enums, izi_sdk, modules/, utility/

NOTE: `api/` and `apidocs/` are .gitignored (local-only). A leftover `.api/`
mirror also exists with identical content — use `api/` (no dot); they are the
same. If one appears missing in your checkout, the other is equivalent.

apidocs/                       # Offline API documentation
├── corpus.jsonl               # LLM retrieval corpus (2877 chunks)
└── pages/dev/api/             # core.md, game-object.md, spellbook.md, buffs.md

wowhead_data/                  # AUTHORITATIVE data sources (verified against WoW 2.5.5.68101 client)
├── lua/                       # NEW: cMaNGOS-extracted Lua tables (items, NPCs, quests, objects)
│   ├── item_db.lua            # 29,881 items with drops, vendors, stats, quests (48 MB)
│   ├── npc_db.lua             # 18,799 NPCs with drops, vendors, quests (35 MB)
│   ├── quest_db.lua           # 6,599 quests with NPC relations (6 MB)
│   └── gameobject_db.lua      # 14,198 objects with loot (2 MB)
├── spells/tbc/*.json          # 1,992 TBC spell files (kept for pipeline; source of truth now DBC)
├── spells/vanilla/*.json      # 639 Classic spells
├── items/tbc/*.json           # 3,410 TBC items (stats, sockets, sets)
├── extracted/                 # cMaNGOS JSON extractions (creature_template, quest_template, etc.)
├── corpus/tbc/                # LLM-ready: per-class .md files + spells.jsonl + items.jsonl
└── corpus/vanilla/            # LLM-ready: per-class .md files + spells.jsonl

wowheadScrape/                 # Scraper + DBC extraction tools
├── scrape_tcs.js              # Playwright scraper of wowhead.com/tbc/spell={id}
├── classify.js                # Classifies scraped spells (player/NPC/item)
├── audit_spells.py            # Audits scrape output against EaxRotations Lua
├── dbc_extract/               # NEW: WoW client DBC extraction output
│   ├── wowsims.db             # 36 MB SQLite DB (28,650 spells, 38,303 effects, 30,057 items)
│   └── lua/                   # NEW: Verified Lua tables from DBC
│       ├── spell_db.lua       # 28,650 spells (19 MB)
│       ├── spell_effect_db.lua # 38,303 effects (50 MB)
│       ├── item_effect_db.lua  # 17,729 item effects (5 MB)
│       ├── item_set_db.lua     # 388 item sets
│       └── item_set_spell_db.lua # 883 set spells
└── tbc_spells_CLASSIFIED.json # 1,788 classified spells

build_tools/                   # Pipeline scripts (primary path: wowheadScrape/DBC)
├── json_to_lua_data.py        # PRIMARY: wowhead_data + DBC → EaxRotations/shared/wowhead_data_bridge_sylvanas.lua
│                              #   NOW consumes wowsims.db as authoritative spell source
│                              #   Merges DBC names/schools with wowhead_data detail fields
├── classified_to_wowhead.py # scrape → wowhead_data/spells/tbc/{id}.json + spell_index/list_tbc.json
├── build_spell_resolver.py    # LEGACY (lexxer.org): generates spell_id_table_sylvanas.lua
├── fetch_all_lexxer_data.py   # LEGACY (lexxer.org): downloads index files for vanilla data + items
└── validate_vanilla_ids.py    # Cross-references _vanilla.lua rotation files against wowhead_data spell lists

# Refresh pipeline (end-to-end):
#   1. DBC extraction (from WoW client):
#      cd tbc-new/tools/DB2ToSqlite && dotnet run -- -o wowheadScrape/dbc_extract/wowsims.db
#   2. Convert DBC to Lua:
#      python wowheadScrape/convert_db_to_lua_v4.py
#   3. Build bridge (merges wowhead_data + DBC):
#      python build_tools/json_to_lua_data.py
#   4. Bridge now embeds 28,650 verified spells; 4 shared modules consume it via require()
```

---

## API Quick Reference

Full docs in `apidocs/`. Key entry points:

| Namespace | Purpose | Key Functions |
|-----------|---------|---------------|
| `core.object_manager.*` | Objects | `get_local_player()`, `get_all_objects()`, `get_enemies()` |
| `core.spell_book.*` | Spells | `is_spell_learned()`, `get_spell_cooldown()`, `has_spell()`, `get_spells()` |
| `core.input.*` | Actions | `cast_target_spell()`, `cast_position_spell()`, `use_item()`, `jump()`, `look_at()` |
| `core.menu.*` | UI Widgets | `checkbox()`, `slider_int()`, `slider_float()`, `keybind()`, `tree_node()`, `combobox()` |
| `core.graphics.*` | Rendering | `circle_3d()`, `line_3d()`, `text_2d()`, `text_3d()`, `rect_2d()` |

**Raw game_object methods**: `get_position()`, `get_name()`, `is_valid()`, `is_dead()`, `is_ghost()`, `is_in_combat()`, `is_casting()`, `is_channelling()`, `get_health()`, `get_max_health()`, `get_mana()`, `get_max_mana()`, `has_buff(id)`, `has_debuff(id)`
**IZI SDK unit extensions**: `get_health_percentage()`, `get_mana_percentage()`, `distance()`, `buff_up(id)`, `debuff_up(id)`, `buff_remains(id)`, `debuff_remains(id)`
**Unit helper** (`require("common/utility/unit_helper")`): `get_health_percentage(unit)`, `get_enemy_list_around(point, range, ...)`

**IZI SDK** (`require("common/izi_sdk")`): `izi.spell(id)`, `izi.item(id)`, `izi.pick_enemy(fn)`, `izi.enemies()`, `izi.on_combat_start(fn)`, `izi.on_spell_success(fn)`

**WoW Spell/Item Data** (local, refreshed 2026-06-15 from WoW client 2.5.5.68101):
- **Spell data**: `wowheadScrape/dbc_extract/lua/spell_db.lua` (28,650 spells, verified from client)
- **Spell effects**: `wowheadScrape/dbc_extract/lua/spell_effect_db.lua` (38,303 effects)
- **Item data**: `wowhead_data/lua/item_db.lua` (29,881 items from cMaNGOS)
- **NPC data**: `wowhead_data/lua/npc_db.lua` (18,799 NPCs from cMaNGOS)
- **Quest data**: `wowhead_data/lua/quest_db.lua` (6,599 quests from cMaNGOS)
- **Legacy Wowhead scrape**: `wowhead_data/spells/tbc/{id}.json` (kept for detail fields not in DBC)
- Alternative live API (lexxer.org): `GET https://lexxer.org/api/v1/spells/{id}?game=tbc`

### When in doubt, read the right doc (`apidocs/pages/dev/`)

**Models: open these files directly when the task touches the topic.** Do not guess API behavior from memory — these MD files are the source of truth and are small enough to read fully.

| If the task involves… | Read this file first |
|----------------------|----------------------|
| Casting spells, GCD, spell IDs, ranks, forms | `apidocs/pages/dev/api/spellbook.md` + `api/spell-helper.md` |
| Reading/iterating units, enemies, party, target | `apidocs/pages/dev/api/object-manager.md` + `api/game-object.md` |
| Input — casting on target, moving, clicking | `apidocs/pages/dev/api/input.md` |
| Buffs/debuffs — stacks, remains, points, auras | `apidocs/pages/dev/api/buffs.md` |
| Cooldowns — tracking, remaining, charges | `apidocs/pages/dev/api/cooldown-tracker.md` |
| Menus — checkboxes, sliders, keybinds | `apidocs/pages/dev/api/ui.md` |
| Drawing — circles, lines, text on screen | `apidocs/pages/dev/api/graphics.md` |
| IZI SDK (`izi.spell()`, `izi.enemies()`, `izi.pick_enemy()`) | `apidocs/pages/dev/libraries/izi/` (all files) |
| Modules — buff_manager, spell_queue, target_selector | `apidocs/pages/dev/modules/` + `libraries/modules/` |
| Enums (class_id, power_type, spec_enum, buff_type) | `apidocs/pages/dev/api/enums.md` |
| Geometry, vectors, distance | `apidocs/pages/dev/api/geometry.md`, `vector-2.md`, `vector-3.md` |
| Quests (for EaxAutoQuester) | `apidocs/pages/dev/api/quests.md` |
| Movement / navigation | `apidocs/pages/dev/api/movement-handler.md`, `simple-movement.md` |
| Pets | `apidocs/pages/dev/api/pet-handler.md` |

**For exhaustive / fuzzy lookups** there is also a pre-chunked RAG corpus at
`apidocs/corpus.jsonl` (2,882 chunks, ~2.5MB) — one JSON object per line. Use it
when you need to grep across all docs at once (e.g. "which API touches
'immunity'?"). For a single known topic, prefer the MD file above — it's faster
and more readable than the JSONL.

---

## Critical Coding Patterns

### Pattern 1: Menu Nil Guards
```lua
-- WRONG: menu.mode:get() -- crashes if nil
-- RIGHT: (menu.mode and menu.mode:get()) or 1
-- Current: via context.settings or NS.get_setting(key, fallback)
```

### Pattern 2: API Caching at Load
```lua
-- Cache at module load (NOT in on_update):
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
-- NS wrappers: NS.me, NS.gcd, NS.GetPlayer()
```

### Pattern 3: Squared Distance
```lua
-- WRONG: math.sqrt(dx*dx + dy*dy) < 10
-- RIGHT: dx*dx + dy*dy < 100  (10 yards squared)
-- Common: 5yd=25, 8yd=64, 10yd=100, 15yd=225, 20yd=400
```

### Pattern 4: Static Table Reuse
```lua
local _t = { n = 0 }  -- Static, reuse every frame
function on_update()
    _t.n = 0
    for i, v in ipairs(source) do _t.n = _t.n + 1; _t[_t.n] = v end
end
```

### Pattern 5: Spell Casting
```lua
local izi = require("common/izi_sdk")
local spell = izi.spell(spell_id)
if spell:cast_safe(target) then return true end
if spell:cooldown_up() and spell:can_cast(target) then spell:queue(target); return true end
```

### Pattern 6: Combat Context (Throttled)
```lua
-- Cache with 2s throttle — never build every frame
local ctx = utils.get_cached_combat_context(me)  -- 2s TTL
```

### Pattern 7: Spell Resolution Caching
```lua
-- Cache is_spell_learned() results per-spec in spell_resolver.lua
```

### Pattern 8: Menu Structure (via Middleware)
```lua
-- Spec files access settings through context, not direct menu widget access:
local function setting(context, key, fallback)
    local s = context.settings
    if s and s[key] ~= nil then return s[key] end
    if NS.get_setting then return NS.get_setting(key, fallback) end
    return fallback
end
-- Menu IDs: "eax<class><spec>_<feature>_<subfeature>"
```

### Pattern 9: File Requires
```lua
local NS = _G.EaxRotations; if not NS then return nil end  -- All spec files start here
local SPELLS = NS.WarriorSpells or {}                       -- Class-specific spell tables
local _ok, Mod = pcall(require, "shared/optional_module")   -- Optional shared modules
local buff_manager = require("common/modules/buff_manager")  -- API modules (absolute)
```

### Pattern 10: Spec File Structure
```
1. NS namespace access + spell/constant tables
2. Optional shared modules (pcall)
3. Action definitions, buff/debuff ID tables, constants
4. State table
5. Helper functions (setting, buff_up, etc.)
6. build_state(context) — populate state from context + NS
7. Match functions (one per strategy)
8. Strategy table (ordered priority list)
9. NS.rotation_registry:register(spec, strategies, { get_state = build_state })
```

### Pattern 11: Aura Points — buff_points / debuff_points

Read variable values from aura data (absorb remaining, Holy Shield charges, etc.).

```lua
-- API (core_sylvanas.lua):
function NS.buff_points(unit, ids)   -- returns number[]|nil (points array)
function NS.debuff_points(unit, ids) -- returns number[]|nil

-- Example — Holy Shield charges (protection_sylvanas.lua):
local pts = NS.buff_points(me, HOLY_SHIELD_BUFF)
prot_state.holy_shield_charges = (pts and pts[1]) or 0
-- Skip refresh if charges > 2
```

- `points[1]` is typically the primary value
- Always nil-guard: `(pts and pts[1]) or 0`
- Distinct from `get_buff_stacks()` — stacks are counts, points are arbitrary values

### Pattern 12: PW:S Absorb Tracking (healing + discipline)

```lua
-- healing_sylvanas.lua helper:
function pws_absorb_remaining(unit)
    local points = NS.buff_points(unit, POWER_WORD_SHIELD_BUFF_IDS)
    if not points then return 0 end
    return points[1] or 0
end

-- discipline_sylvanas.lua consumer:
local absorb = Healing.pws_absorb_remaining(s.lowest.unit)
if absorb > 200 then return false end  -- ~16% of fresh ~1265 absorb, safe to refresh
```

### Pattern 13: Smart Innervate Targeting (balance + resto)

Prefer low-mana healer-class party members over self. Falls back to self.

```lua
local HEALER_CLASS_IDS = { [2]=true, [5]=true, [7]=true, [11]=true }  -- Pally, Priest, Shaman, Druid

-- Party scan in build_state() — gated behind context.in_combat and context.is_group
-- First low-mana healer wins (break after find)
-- Split strategies: InnervateHealer (non-self) + InnervateSelf (fallback)
```

### Pattern 14: State Field Nil-Guards (match functions)

**Critical**: Bare `state.field < X` with nil evaluates to `false`, silently skipping strategies.

```lua
-- WRONG: if state.rage < 25 then return false end  -- nil → false, skips Execute
-- RIGHT: if (state.rage or 0) < 25 then return false end  -- nil → 0, correctly blocks
```

| Field | Safe Default | Rationale |
|-------|-------------|-----------|
| `hp` / `hp_pct` / `mana_pct` | `100` | Assume full → skip defensives |
| `rage` / `energy` / `focus` / `combo_points` | `0` | Assume empty → skip spenders |
| `enemy_count` / `enemies` | `0` | Assume none → skip AoE |
| `target_hp` / `target_hp_pct` | `100` | Assume full → skip execute-range |

**Scope**: 24 files (14 spec + 9 leveling + 1 shadow), ~170 locations guarded. All 373 rotation + 21 leveling suites pass.

### Pattern 15: File Readability Header

Every `.lua` file in `EaxRotations/` starts with a 1–5 line header documenting **What / When / Why / Safety / Decision**. A reader (human or agent) should understand the file's purpose and its key safety invariants from the header alone, without reading the whole file.

```lua
-- cat_sylvanas.lua — Druid Feral Cat rotation for TBC Anniversary (2.5.5).
-- WHAT:  priority-list strategies (Rip, FB, Mangle, SR cycle, bite-window gating).
-- WHEN:  combat, cat form, with valid enemy target.
-- WHY:   mirrors SimulationCraft APL with snapshot-aware refresh.
-- SAFETY: every state.rage/state.combo_points read is nil-guarded; no on_update() allocs.
```

This is mandatory for new files and strongly encouraged when substantially editing an existing file.

### Pattern 16: spec_kit (canonical spec-file boilerplate + nil-guard elimination)

`spec_kit` is **live** in `EaxRotations/shared/spec_kit_sylvanas.lua` (no longer a sandbox proof-of-concept). It provides:

- `spec_kit.define_action_for_class(SPELLS)` — replaces the copy-pasted `spell()` helper in every spec.
- `spec_kit.safe_state(raw, schema)` — a proxy table where numeric reads fall back to documented Pattern 14 defaults, making the nil-guard bug **structurally impossible**.
- `spec_kit.setting(context, key, default)` — centralized Pattern 8 menu-settings helper.

**Reference implementation:** `classes/warrior/arms_sylvanas.lua` (first spec converted — uses `define_action_for_class` + guarded registration).

**Canonical spec-file skeleton** (target for all 29 specs — see README "How to Read a Spec"):

```lua
-- <spec>_sylvanas.lua — <Class> <Spec> rotation for TBC Anniversary (2.5.5).
-- WHAT:  one-line summary of the rotation's priority logic.
-- WHEN:  combat conditions (target type, form, range).
-- WHY:   mirrors SimulationCraft / wowsims APL with TBC-era mechanics.
-- SAFETY: state.* reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

-- 1. spec_kit + shared modules
local spec_kit = require("shared/spec_kit_sylvanas")
local potion_helper = require("shared/potion_helper_sylvanas")
local SPELLS = NS.<Class>Spells or {}

-- 2. Action table via spec_kit (replaces per-spec spell() helper)
local define = spec_kit.define_action_for_class(SPELLS)
local ACTION = { SpellName = define("SpellName", { rank_ids }, "Label") }

-- 3. Buff/debuff ID tables + constants
local SOME_BUFF = { spell_ids }

-- 4. State table (raw; safe_state proxy applied in build_state)
local spec_state = { }
local _last_build_state_time = -1

-- 5. build_state(context) — populate state, return safe_state proxy
local function build_state(context)
    local state = spec_kit.safe_state(spec_state)
    -- populate fields from context + NS
    return state
end

-- 6. Match functions (one per strategy)
local function some_spell_matches(context, state) return true end

-- 7. Strategy table (ordered priority list)
local strategies = {
    { name = "SpellName", matches = some_spell_matches, execute = function(ctx) end },
}

-- 8. Register (guarded — nil-safe in unit tests)
if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("<spec>", strategies, { get_state = build_state })
end
if NS.log then NS.log("<Class> <spec> rotation registered") end

-- 9. Return (canonical shape — dispatcher + tests both get what they need)
return { strategies = strategies, build_state = build_state }
```

**Migration rules:**
- Convert a spec **only when already editing it** — never big-bang (per `plans/refactor-developer-experience-2026-06.md`).
- One spec per commit. Gate each with `luac -p` + full 365+21 suite.
- **R5: if a task loops more than 2 attempts, STOP.** Write a debugging note in `plans/`.
- Migration state is tracked in `EaxRotations/README.md` ("How to Read a Spec") and enforced by `tests/test_spec_layout_compliance.lua`.

---

## Menu Item Reference

| Type | Constructor | Example |
|------|-------------|---------|
| Checkbox | `core.menu.checkbox(true, id)` | `menu.use_bt` |
| Slider | `core.menu.slider_int(min, max, default, id)` | `menu.hp_threshold` |
| Slider (float) | `core.menu.slider_float(min, max, default, id)` | `menu.max_distance` |
| Combobox | `core.menu.combobox(1, id)` | `menu.mode` (1=Auto, 2=PVE, 3=PVP) |
| Keybind | `core.menu.keybind(key, shift, id)` | `menu.toggle` |

---

## Testing Rules

- Run `luac -p` on every modified file before commit
- Run `lua EaxRotations/tests/run_rotation_tests.lua` — all 382 rotation suites must pass
- Run `lua EaxRotations/tests/run_leveling_tests.lua` — all 23 leveling suites must pass
- `lsp_diagnostics` must show 0 errors on changed files

---

## Boundaries

### Always
- Cache hot-path APIs at module load
- Throttle expensive calls (combat_context → 2s, detect_mode → 5s)
- Limit target scan to 50 objects with early exit
- Nil-guard ALL menu references and numeric state field comparisons
- Use squared distance, static table reuse

### Ask First
- Add new shared modules to `EaxRotations/shared/`
- Modify `core_sylvanas.lua` NS helper patterns
- Add new menu items (handled by middleware)
- Use APIs outside `api/` or `apidocs/`

### Never
- `ffi.C`, `io.popen`, `os.execute`, `debug.*` — banned APIs
- **Edit any file in `api/` or `.api/`** — these are .gitignored runtime API stubs from Project Sylvanas; strictly read-only. If docs are stale, note it in plans/ instead.
- Use `math.sqrt()` for distance comparisons
- Call expensive APIs in `on_update()` without caching
- Create garbage in tight loops (use static tables)
- Access `menu.x:get()` without nil guard
- Remove spells from class_sylvanas.lua because they seem "WotLK" — TBC Anniversary runs on its **own 2.5.5.x client**, not Wrath 3.3.5. Some Wrath-era spells were **backported** to 2.5.5 (Ice Lance 30455, Seal of Blood 31892, etc.) and ARE valid. Always verify against the DBC (`wowheadScrape/dbc_extract/wowsims.db`) and lexxer.org API before removing. Run `lua EaxRotations/tests/run_sylvanas_audit_tests.lua` to verify spell IDs exist in the client.

---

## Session Start Protocol

1. Work from `C:\newbot\scripts`
2. `git status --short --branch && git log --oneline -5`
3. Read claude-mem memory for project context (`memory/project/tbc-classic-wrath-spells.md`)
4. Read target spec file + related `shared/` modules
5. Run `luac -p` on any file before editing
6. Validate: `lua EaxRotations/tests/run_rotation_tests.lua` and `lua EaxRotations/tests/run_leveling_tests.lua`

---

*This file is agent-curated. Update when patterns change or APIs are adopted.*
