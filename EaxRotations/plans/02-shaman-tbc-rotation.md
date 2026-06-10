# Plan: TBC Anniversary 2.5.5 Shaman Rotation (Elemental)

**Destination**: `Rotations/Shaman/` (new top-level folder)
**Files**: 2 only — `header.lua`, `main.lua`. No subfiles, no NS context, no shared modules.
**Spec scope**: **Elemental** (1 of 3 shaman specs; resto/enhancement as future plans).
**TBC Anniversary note**: Runs on the Wrath 3.3.5 client. Wrath-era spells available to shaman (e.g. **Elemental Mastery** cooldown-reduction Wrath behavior) are valid.

---

## Constraints (read these first)

These come from the local apidocs, the IZI SDK docs, and the existing `EaxRotations` patterns. They are **non-negotiable** for performance and correctness.

| Rule | Source | Why |
|------|--------|-----|
| Cache at module load, not inside `on_update` | `apidocs/pages/dev/api/core.md`, EaxRotations NS pattern | Gameimpact — every `require`/`core.time` lookup inside the tick costs |
| Use **squared distance** for range checks | EaxRotations pattern + IZI SDK `distance()` already cached | `math.sqrt` is banned in hot paths |
| Static table reuse for enemy/friend lists | EaxRotations pattern | Avoid GC in 20Hz tick |
| `cast_safe` for production, `cast` for debug | `apidocs/pages/dev/libraries/izi/izi-spells.md` | `cast_safe` includes GCD/cast-state/facing/range checks before sending |
| Throttle expensive calls (spellbook scan, target re-acquire) | EaxRotations pattern | 2s scan throttle already used in TBC warlock example |
| Do NOT use `math.sqrt`, `ffi.C`, `io.popen`, `os.execute`, `debug.*` | EaxRotations banned-APIs | Engine safety + performance |
| `on_update` is the only place for rotation logic | `apidocs/pages/dev/api/core.md` (callback table) | `on_render` is for graphics only |
| Auto-detect highest spell rank from spellbook | `apidocs/pages/dev/examples/tbc-warlock-affliction.md` `scan()` | TBC has 5-11 ranks per spell |
| No external platform APIs — only `core.*`, `izi.*`, `common/*` | EaxRotations boundary rule | Engine isolation |

---

## Phase 0 — Documentation Discovery (DONE in this plan)

### 0.1 Sources consulted

| File / URL | What was extracted |
|------------|-------------------|
| `apidocs/pages/dev/libraries/izi/izi-spells.md` | `izi.spell(id)`, `:cast_safe(target,label)`, `:cast(target,label)`, `:is_learned()`, `:cooldown_up()`, `:is_castable()`, multi-id constructor `[id1,id2,...]` |
| `apidocs/pages/dev/libraries/izi/units.md` | `izi.me()`, `me:is_alive()`, `me:can_attack(target)`, `me:mana_pct()`, `me:health_pct()`, `me:get_target()`, `me:buff_up(id)`, `me:buff_down(id)`, `me:distance()`, `target:is_valid()`, `target:is_valid_enemy()`, `target:debuff_up({ids})`, `target:debuff_down({ids})`, `target:health_pct()`, `izi.enemies(radius)` |
| `apidocs/pages/dev/libraries/izi/izi-spells-sequences.md` | (To be read in Phase 1 if any spell sequence is needed) |
| `apidocs/pages/dev/examples/tbc-warlock-affliction.md` | **TEMPLATE** — single file, callback table, action list waterfall, `scan()` rank resolver, `try_cast` wrapper, `core.register_on_update_callback`, menu via `core.menu.*`, control panel via `core.register_on_render_control_panel_callback` |
| `apidocs/pages/dev/api/core.md` | `core.register_on_update_callback(fn)`, `core.menu.tree_node/checkbox/keybind/header`, `core.time()`, `core.object_manager.get_local_player()` |
| `OldProjects/archive_original_specs/EAXShamanElemental/header.lua` | **header pattern** — class ID 7 = Shaman, load-guard returns table with `load=false` on mismatch |
| `OldProjects/archive_original_specs/EAXShamanElemental/main.lua` | **inspiration only** — totem list, mana gates, Lightning Bolt downrank trick. We do NOT copy the 30-library require chain. |
| `EaxRotations/classes/shaman/elemental_sylvanas.lua` | Spell IDs and rank tables to seed `DEFS`: LightningBolt ranks, ChainLightning, FlameShock, EarthShock, FrostShock, LightningShield, WaterShield, totems (Totem of Wrath, Wrath of Air, Mana Spring, Magma), Elemental Mastery, Bloodlust/Heroism |
| `wowhead_data/corpus/tbc/spells_shaman.md` | Confirmed highest-rank IDs and base ranks for the 131 TBC shaman spells available locally |

### 0.2 Allowed APIs (exact names — copy these literally, do not invent)

```lua
-- Lifecycle
core.register_on_update_callback(fn)        -- rotation runs here
core.register_on_render_callback(fn)        -- HUD only, no game logic
core.register_on_render_menu_callback(fn)   -- menu UI
core.register_on_render_control_panel_callback(fn)
core.time()                                -- seconds, monotonic
core.object_manager.get_local_player()

-- Menu widgets
local m = core.menu
m.tree_node() / m.checkbox(def, id) / m.keybind(key, shift, id) / m.header() / m.slider_int(min,max,def,id)

-- IZI SDK (require "common/izi_sdk")
izi.spell(id_or_id_array)         -- returns izi_spell
izi.me()                          -- returns local player unit (with extensions)
izi.enemies(radius)               -- game_object[] (static table reused, do not modify)
izi.friends(radius)               -- game_object[]
izi.printf(fmt, ...)              -- engine log
izi.color.yellow(a)               -- color helper

-- Unit methods (patches onto game_object — call directly on `me` and `target`)
me:is_alive()
me:mana_pct()
me:health_pct()
me:get_target()                   -- current target (may be nil)
me:can_attack(target)
me:buff_up(id_or_ids)
me:buff_down(id_or_ids)
me:distance()                     -- already squared? Verify in Phase 1; if not, use squared comparison
target:is_valid()
target:is_valid_enemy()
target:health_pct()
target:debuff_up(id_or_ids)
target:debuff_down(id_or_ids)
target:is_casting()               -- for interrupt check (Wind Shear / Earth Shock)

-- Spell methods
spell:is_learned()
spell:cooldown_up()
spell:is_castable()
spell:cast_safe(target, label)    -- production
spell:cast(target, label)         -- debug only
spell.ids                         -- array of candidate IDs (from izi.spell([...]))

-- Spellbook scan
core.spell_book.get_spells()      -- returns table of {id=true} (verify key/value structure in Phase 1)
```

### 0.3 Anti-patterns (DO NOT do)

- ❌ Invent APIs not in the list above (e.g. `core.spell_book.get_spell(id)` is NOT in apidocs — use `izi.spell(id)`)
- ❌ `math.sqrt` for range checks — `5yd = 25`, `10yd = 100`, `30yd = 900`, `40yd = 1600`
- ❌ `require` inside `on_update`
- ❌ `me:distance()` then `math.sqrt` — if `distance()` returns squared, use it as-is; if it returns linear, square your own threshold once at module load
- ❌ Allocating tables in the tick — use module-level static tables
- ❌ Calling `core.object_manager.get_local_player()` every tick — cache at module load and refresh only on death
- ❌ Cloning the 30-library EaxRotations `require` chain — use IZI SDK + `common/izi_sdk` only
- ❌ Reading `wowhead_data/spells/tbc/{id}.json` from the rotation (cold path on every check) — seed `DEFS` with IDs from `corpus/tbc/spells_shaman.md` and resolve highest rank via `scan()`

### 0.4 Confidence

- **High**: API signatures (verified in apidocs), callback pattern (verified in tbc-warlock-affliction example), header pattern (verified in old archive), spell ID base ranks (verified in wowhead corpus).
- **Medium**: Whether `me:distance()` returns linear or squared. **Resolution**: read `.api/common/izi_sdk.lua` in Phase 1 step 1.3 before writing any range check. Default to squared until proven otherwise.
- **Medium**: Exact key structure of `core.spell_book.get_spells()` return value. **Resolution**: read the api source in Phase 1 step 1.3 — the tbc-warlock example handles both `type(k)=="number"` and `type(v)=="number"`, so follow that pattern.

---

## Phase 1 — Scaffold `Rotations/Shaman/` (header + main skeleton)

### 1.1 Create folder + `header.lua`

**Path**: `Rotations/Shaman/header.lua`

**Copy from**: `OldProjects/archive_original_specs/EAXShamanElemental/header.lua`

**Adapt**: change the plugin name to "Shaman Elemental" and keep the class ID 7 (Shaman) guard exactly. The old header is 27 lines and is already the right shape — do not add complexity.

**Verification**:
```bash
luac -p Rotations/Shaman/header.lua
```

**Anti-pattern guard**: Do NOT add class/spec detection beyond what the old header does. The spec gating (Elemental vs Enhancement vs Restoration) happens inside `main.lua` via a spell-learned check at the top of `on_update`, not in the header.

### 1.2 Create `main.lua` skeleton

**Path**: `Rotations/Shaman/main.lua`

**Copy the structure from**: `apidocs/pages/dev/examples/tbc-warlock-affliction.md` lines 67-71 (the TBC warlock main.lua). The structure is:

```
1. requires (izi_sdk, key_helper, control_panel_helper)
2. PREFIX for menu IDs + uid() helper
3. use_safe_cast toggle + try_cast wrapper
4. menu table + on() + render menu callback + render control panel callback
5. DEFS table (base-rank spell IDs)
6. spells / spell_ids / all_ranks / SPELLS tables
7. resolved / name_cache / last_scan + spell_name() + scan()
8. helpers (debuff_missing, etc.)
9. spellCallbacks = {} — one named function per spell
10. actionList.core = function() — priority waterfall
11. on_update callback
12. on_render callback (HUD)
```

**Verification**: file parses, no references to nonexistent globals.

```bash
luac -p Rotations/Shaman/main.lua
```

### 1.3 Read the actual izi_sdk.lua source before writing the rotation

**File**: `.api/common/izi_sdk.lua` (cache, but actually read enough to confirm):
- Whether `me:distance()` returns yards (linear) or yards² (squared)
- The exact return shape of `core.spell_book.get_spells()` (the tbc-warlock example handles both keys-and-values; verify)
- The `:debuff_up()` / `:buff_up()` argument shape (single id vs array — the apidocs units.md shows `unit:buff_up(SHADOW_TRANCE)` (single) and `unit:debuff_up(table)` (array))

**Verification**: write a 5-line comment block at the top of `main.lua` documenting what each verified call returns, e.g.:
```lua
-- distance(): returns squared yards (verified .api/common/izi_sdk.lua:XXX)
-- spell_book.get_spells(): returns { [id]=true, ... } (verified ...)
```

This is the "stay very very true to the documentation" guard the user asked for.

---

## Phase 2 — Spell definitions, scan(), and menu

### 2.1 Seed `DEFS` with TBC elemental shaman spells

**Source of truth**: `wowhead_data/corpus/tbc/spells_shaman.md` (read in Phase 0; spell IDs are confirmed in that file).

**Minimum DEFS for Elemental** (base rank 1 IDs — `scan()` will upgrade to max rank in the spellbook):

```lua
local DEFS = {
    -- Damage
    LIGHTNING_BOLT    = 403,    -- ranks 1-11, max 25449
    CHAIN_LIGHTNING   = 421,    -- max 25442
    FLAME_SHOCK       = 805,    -- max 25457
    EARTH_SHOCK       = 804,    -- max 25454
    FROST_SHOCK       = 8056,   -- max 25464
    LAVA_BURST        = 51505,  -- THE TBC BREAKTHROUGH SPELL, level 70
    -- Buffs / Shields
    LIGHTNING_SHIELD  = 324,    -- max 25472
    WATER_SHIELD      = 52127,  -- 70-era Wrath spell, TBC Anniversary valid
    -- Cooldowns
    ELEMENTAL_MASTERY = 16166,  -- next 2 spells with <10s cast time become instant
    BLOODLUST         = 2825,   -- 40-man only in TBC; check `core.instance.is_40man()` if available, else skip
    HEROISM           = 32182,  -- Alliance version of Bloodlust
    -- Totems
    TOTEM_OF_WRATH    = 30706,
    WRATH_OF_AIR      = 3738,
    MANA_SPRING       = 25570,  -- aura
    MAGMA_TOTEM       = 8190,   -- max 25552
    -- Utility
    HEX               = 51514,  -- TBC 70
    PURGE             = 370,
    -- Downrank (mana conservation)
    LIGHTNING_BOLT_LOWER = 25448,  -- rank 10, used when mana < 30%
}
```

**Verification**:
```bash
# Every ID must exist in wowhead_data/spells/tbc/
for id in 403 421 805 804 8056 51505 324 52127 16166 2825 32182 30706 3738 25570 8190 51514 370 25448; do
  test -f "wowhead_data/spells/tbc/${id}.json" || echo "MISSING: $id"
done
```

### 2.2 Menu tree (per-spell checkboxes + master toggle)

**Copy from**: tbc-warlock-affliction example, `menu = { ... }` table and `core.register_on_render_menu_callback`.

**Menu structure** (keep it flat, no sub-trees beyond Spells group):

```
[TBC Shaman Elemental]
  Enabled                          (checkbox, default true)
  Rotation Toggle                  (keybind)
  [Spells]
    Lightning Bolt                 (checkbox)
    Chain Lightning (AoE)          (checkbox)
    Flame Shock                    (checkbox)
    Earth Shock (interrupt)        (checkbox)
    Lava Burst                     (checkbox)
    Lightning Shield               (checkbox)
    Water Shield                   (checkbox, mutually exclusive w/ Lightning Shield)
    Elemental Mastery              (checkbox)
    Bloodlust / Heroism            (checkbox)
    Totem of Wrath                 (checkbox)
    Wrath of Air                   (checkbox)
    Mana Spring Totem              (checkbox)
    Magma Totem (AoE)              (checkbox)
  [Mana]
    Mana Low %                     (slider_int, default 30)
    Mana Emergency %               (slider_int, default 15)
  [Debug]
    Enable core.log output         (checkbox, default true; reads from `_debug_log`)
    Bench report interval (ms)     (slider_int, 1000-30000, default 5000)
```

**PREFIX convention**: `"eaxsham_tbc"` — unique per plugin so it doesn't collide with EaxRotations.

**Verification**:
```bash
luac -p Rotations/Shaman/main.lua
# All menu IDs unique:
grep -oE 'uid\("[^"]+"\)' Rotations/Shaman/main.lua | sort | uniq -d
# Must be empty.
```

### 2.3 `scan()` spellbook rank resolver

**Copy from**: tbc-warlock-affliction example, `scan()` function. 2-second throttle (`last_scan`).

The function:
1. Throttles to 2s
2. Resolves spell names for each `DEFS` key
3. Scans `core.spell_book.get_spells()` for all known IDs
4. For each `DEFS` key, finds all ranks (matching by spell name) and picks highest ID
5. Updates `spell_ids[k]`, `spells[k] = izi.spell(id)`, `all_ranks[k] = ranks[k]`
6. Refreshes the `SPELLS` table so callbacks use the current rank

**Anti-pattern guard**: do NOT modify the table returned by `core.spell_book.get_spells()`. Build a fresh `ids` set as the example does.

### 2.4 `core.log` debug + in-tick bench

**Source of truth** (verified in Phase 0):
- `core.log(msg)` — documented in `apidocs/pages/dev/api/assets-helper.md:163`, `auction_house.md:57,362,367,376,381`, `modules/buff-manager.md:80`. Accepts a string. Engine-side logger.
- `izi.now()` — seconds (float). `apidocs/pages/dev/libraries/izi.md:165-170`.
- `izi.now_ms()` — milliseconds (int). `apidocs/pages/dev/libraries/izi.md:191`.
- `izi.printf(fmt, ...)` — `printf`-style. `apidocs/pages/dev/libraries/izi/units.md` (used in all examples).

**Two distinct log layers** (kept separate so the user can mute one without losing the other):

#### Layer A — Rotation-level `core.log` (for debugging the rotation, not the framework)

One line per cast attempt, throttled to 1 per 250ms to avoid log spam. Use `core.log` (engine logger), **not** `izi.printf` (which prefixes with the plugin name and is louder).

```lua
local _debug_log = true                   -- master toggle (hardcoded; not menu-exposed)
local _last_log_ms = 0
local _LOG_THROTTLE_MS = 250

local function dlog(msg)
    if not _debug_log then return end
    local now = izi.now_ms()
    if now - _last_log_ms < _LOG_THROTTLE_MS then return end
    _last_log_ms = now
    core.log("[ShamanElemental] " .. tostring(msg))
end
```

**Call sites** — exactly these, no more:
- Top of `on_update` (after the early-returns): `dlog(string.format("tick: mana=%.0f%% tgt=%s hp=%.0f%%", ...))` — once per tick that survives the early-returns.
- Inside `try_cast`, on success: `dlog("CAST " .. label .. " -> " .. (target and target:get_name() or "nil"))`
- Inside `try_cast`, on `is_learned` failure (first time per scan): `dlog("skip " .. label .. " not learned")`
- Inside `scan()`: `dlog("rank resolved: " .. k .. " = " .. id)` when an ID changes (so a fresh log every time a higher rank is learned, not on every scan)

**Anti-pattern guards**:
- ❌ Do NOT log inside the action list waterfall between callbacks — only at cast and at the tick boundary
- ❌ Do NOT concat the full `debuff_up/debuff_down` table — log only the booleans
- ❌ Do NOT log when `_debug_log` is false (gating above is mandatory to keep zero cost when off)
- ❌ Do NOT log in `on_render` (graphics tick, runs every frame)

#### Layer B — In-tick bench (mean / max ms over a 5-second window)

Wrap the entire body of `on_update` after the early-returns, but before the action list. Use `izi.now_ms()` for both endpoints. Aggregate in a static table — **no allocation in the hot path**.

```lua
-- Module-level bench state (initialized once)
local _bench = {
    samples_n = 0,
    samples_ms_total = 0,
    samples_ms_max = 0,
    samples_ring = {},    -- circular buffer of last N samples
    samples_ring_idx = 0,
    last_report_ms = 0,
}
local _BENCH_RING_SIZE = 100            -- ~5s at 20Hz
local _BENCH_REPORT_MS = 5000           -- log mean/max every 5s

local function bench_reset_window()
    _bench.samples_n = 0
    _bench.samples_ms_total = 0
    _bench.samples_ms_max = 0
    for i = 1, _BENCH_RING_SIZE do _bench.samples_ring[i] = 0 end
    _bench.samples_ring_idx = 0
end
bench_reset_window()

local function bench_record(dt_ms)
    _bench.samples_n = _bench.samples_n + 1
    _bench.samples_ms_total = _bench.samples_ms_total + dt_ms
    if dt_ms > _bench.samples_ms_max then _bench.samples_ms_max = dt_ms end
    _bench.samples_ring_idx = (_bench.samples_ring_idx % _BENCH_RING_SIZE) + 1
    _bench.samples_ring[_bench.samples_ring_idx] = dt_ms
end

local function bench_maybe_report()
    local now = izi.now_ms()
    if now - _bench.last_report_ms < _BENCH_REPORT_MS then return end
    if _bench.samples_n == 0 then return end
    local mean = _bench.samples_ms_total / _bench.samples_n
    -- p95 from ring buffer (approximate, no sort)
    local sorted_n = 0
    local sorted_sum = 0
    for i = 1, _BENCH_RING_SIZE do
        local v = _bench.samples_ring[i]
        if v > 0 then sorted_n = sorted_n + 1; sorted_sum = sorted_sum + v end
    end
    local ring_mean = sorted_n > 0 and (sorted_sum / sorted_n) or 0
    dlog(string.format(
        "BENCH 5s: n=%d mean=%.2fms max=%.2fms ring_mean=%.2fms",
        _bench.samples_n, mean, _bench.samples_ms_max, ring_mean))
    _bench.last_report_ms = now
    bench_reset_window()
end
```

**`on_update` integration** — exactly 3 lines added:

```lua
core.register_on_update_callback(function()
    scan()
    if not menu:on() then return end
    local me = izi.me()
    if not me or not me:is_alive() then return end
    if (me:mana_pct() or 0) < MANA_EMERGENCY then return end
    local target = me:get_target()
    if not target or not target:is_valid() then return end
    if not target:is_valid_enemy() then return end
    if not me:can_attack(target) then return end

    -- BENCH START
    local _bench_t0 = izi.now_ms()
    dlog(string.format("tick: mana=%.0f%% tgt=%s hp=%.0f%%",
        me:mana_pct() or 0,
        target:get_name() or "?",
        target:health_pct() or 0))

    -- ... existing actionList.burst / aoe / buffs / reactive / filler calls ...

    -- BENCH END
    bench_record(izi.now_ms() - _bench_t0)
    bench_maybe_report()
end)
```

**Performance guard (CRITICAL — do not regress)**:
- `izi.now_ms()` is the only timing call (documented; cheap)
- Ring buffer is a fixed-size table; no allocation
- Report happens at most every 5s, regardless of tick rate
- When `_debug_log = false`, the `dlog()` early-returns in O(1) with one comparison + one integer sub
- `bench_record` does 4 integer ops + 1 table write per tick — negligible

**Verification**:
```bash
# Bench/Log functions defined exactly once each (no dupes)
grep -cE '^local function (dlog|bench_record|bench_maybe_report|bench_reset_window)' Rotations/Shaman/main.lua
# Expected: 4
# No string.format in on_update outside the tick dlog + bench report
grep -nE 'string\.format' Rotations/Shaman/main.lua
# Should be: exactly 2 (tick dlog + bench report)
```

---

## Phase 3 — Rotation callbacks + action list

### 3.1 Callback pattern (copy structure from tbc-warlock example)

Each callback is `function() return try_cast(SPELLS.X, target, "X") end` returning `true` on cast, `false` otherwise. Names in the table become the SpellDebugger labels (optional, but free if FBR is present).

### 3.2 Elemental priority list (inspired by EaxRotations + tbc-warlock template)

The priority below is the **waterfall** checked each tick; first `true` wins, rest skipped.

```
[REACTIVE]  Flame Shock on a high-HP target
            → if no Flame Shock on target, cast it (it's a one-time DoT setup, highest prio on pull)

[REACTIVE]  Elemental Mastery
            → cast on pull / on burst windows (mana > 30%, target > 50% HP, not in AoE)
            → then next 2 lightning bolts are instant (handled by IZI cast_safe)

[AOE 3+]    Chain Lightning
            → #izi.enemies(10) >= 3, mana > 30%, not in emergency

[BUFF]      Lightning Shield
            → me:buff_down(LIGHTNING_SHIELD_IDS), me:mana_pct() > 50
            → skip if Water Shield active (mutually exclusive element shields)

[BUFF]      Water Shield
            → me:mana_pct() < 50, me:buff_down(WATER_SHIELD_IDS)
            → skip if Lightning Shield active

[BUFF]      Totem of Wrath (10 min duration, refresh <2 min remaining)
            → if spell not present in last-cast-time, place

[BUFF]      Wrath of Air Totem
[BUFF]      Mana Spring Totem

[AOE]       Magma Totem
            → #izi.enemies(10) >= 3, refresh every 20s (or check for totem present)

[COOLDOWN]  Bloodlust / Heroism
            → only in instances (check `core.instance` or skip if no API), party check, cast on self

[EXECUTE]   Earth Shock
            → target:health_pct() < 30%, no shock debuff on target
            → also serves as interrupt if target:is_casting()

[INTERRUPT] Earth Shock (interrupt path)
            → target:is_casting() and not target:is_silenced() (or :is_cc() per IZI)

[FILLER]    Lightning Bolt
            → default cast; cast lower rank (25448) if me:mana_pct() < MANA_LOW
            → if me:mana_pct() < MANA_EMERGENCY (default 15), stop all casting (early return)
            → if me:mana_pct() < 10, drink (placeholder, OOC manager is out of scope)
```

### 3.3 Action list (waterfall)

```lua
local actionList = {}
actionList.burst = function()
    if spellCallbacks.elementalMastery() then return true end
end
actionList.aoe = function()
    if spellCallbacks.chainLightning() then return true end
end
actionList.buffs = function()
    if spellCallbacks.lightningShield() then return true end
    if spellCallbacks.waterShield()     then return true end
    if spellCallbacks.totemOfWrath()    then return true end
    if spellCallbacks.wrathOfAir()      then return true end
    if spellCallbacks.manaSpring()      then return true end
    if spellCallbacks.magmaTotem()      then return true end
    if spellCallbacks.bloodlust()       then return true end
end
actionList.reactive = function()
    if spellCallbacks.flameShock() then return true end
    if spellCallbacks.earthShock()  then return true end  -- execute OR interrupt
end
actionList.filler = function()
    if spellCallbacks.lightningBolt() then return true end
end
```

### 3.4 `on_update` body

Copy the structure from tbc-warlock example's `core.register_on_update_callback` block:

```lua
core.register_on_update_callback(function()
    scan()  -- rank resolver, 2s throttled
    if not menu:on() then return end
    local me = izi.me()
    if not me or not me:is_alive() then return end
    if (me:mana_pct() or 0) < MANA_EMERGENCY then return end  -- early-return emergency gate
    local target = me:get_target()
    if not target or not target:is_valid() then return end
    if not target:is_valid_enemy() then return end
    if not me:can_attack(target) then return end

    -- Reactive: Elemental Mastery on burst
    if actionList.burst() then return end
    -- AoE first
    if #izi.enemies(10) >= 3 then
        if actionList.aoe() then return end
    end
    -- Buffs
    if actionList.buffs() then return end
    -- Reactive procs / execute / interrupt
    if actionList.reactive() then return end
    -- Filler
    actionList.filler()
end)
```

**Verification** (perf guard from AGENTS.md):
- No `require` inside the callback
- No `math.sqrt`
- No table allocation in the hot path (all tables are module-level)
- `izi.enemies(10)` returns a shared table — read-only access, do not mutate

### 3.5 HUD

Minimal: a single line at top-left saying `[Shaman Elemental] ENABLED` or `DISABLED` plus a small line showing current mana % and active totem if `on_render` is wired. **Do not** put rotation logic in `on_render`.

**HUD also shows the last bench summary line** (mean / max ms) so the user can see perf in-game without opening the log file. Updated only when `bench_maybe_report` fires, so it never causes per-frame churn.

---

## Phase 4 — Verification (mandatory, do not skip)

### 4.1 Syntax

```bash
luac -p Rotations/Shaman/header.lua
luac -p Rotations/Shaman/main.lua
```

Both must exit 0.

### 4.2 Anti-pattern grep

```bash
# No math.sqrt in main.lua
grep -n 'math\.sqrt' Rotations/Shaman/main.lua && echo "FAIL: math.sqrt found" || echo "OK"
# No require inside functions (only at top of file)
grep -nE '^[[:space:]]+require\(' Rotations/Shaman/main.lua && echo "FAIL: require inside function" || echo "OK"
# No ffi/os.execute/io.popen
grep -nE 'ffi\.C|os\.execute|io\.popen|debug\.' Rotations/Shaman/main.lua && echo "FAIL: banned API" || echo "OK"
# No menu.uid collision
grep -oE 'uid\("[^"]+"\)' Rotations/Shaman/main.lua | sort | uniq -d
# No TODOs left
grep -nE 'TODO|FIXME|XXX' Rotations/Shaman/main.lua
# Bench/log helpers defined exactly once each
grep -cE '^local function (dlog|bench_record|bench_maybe_report|bench_reset_window)' Rotations/Shaman/main.lua
# Expected: 4
# string.format used only in dlog() and bench_maybe_report()
grep -nE 'string\.format' Rotations/Shaman/main.lua | wc -l
# Expected: exactly 2
# No core.log in on_render (graphics tick)
grep -nE 'core\.log' Rotations/Shaman/main.lua | grep -v ':render'  # eyeball the result
```

### 4.3 Structural checklist

- [ ] `Rotations/Shaman/header.lua` — returns `plugin` table with `load=false` when class ≠ 7
- [ ] `Rotations/Shaman/main.lua` — single file, no `require` outside the top
- [ ] `DEFS` contains all 18 spell entries listed in 2.1
- [ ] `scan()` updates `spell_ids[k]` and `SPELLS.X` to highest known rank
- [ ] Every callback returns `true` on successful cast, `false` otherwise
- [ ] `on_update` early-returns on: menu off, dead, no target, enemy invalid, can't attack, mana emergency
- [ ] Action list waterfall order matches Phase 3.2
- [ ] No `math.sqrt`, no `require` in callbacks, no banned APIs
- [ ] SpellDebugger integration is **optional** — wrap in `if FBR and FBR.SpellDebugger then ... end` (one-liner, copy from tbc-warlock example)
- [ ] `dlog()` wraps `core.log` with a 250ms throttle, gated by `_debug_log` flag, called only at tick boundary + cast attempt + rank-resolve
- [ ] `_bench` static state records `izi.now_ms()` delta per tick, reports mean/max every 5s via `dlog` and updates HUD
- [ ] Ring buffer of 100 samples, no allocation per tick

### 4.4 Documentation-truth spot check

```bash
# Every API used must appear in apidocs
for api in core.register_on_update_callback core.menu.checkbox core.menu.keybind core.menu.tree_node \
           izi.spell izi.me izi.enemies izi.printf \
           :cast_safe :cast :cooldown_up :is_learned :is_castable \
           :is_alive :mana_pct :health_pct :get_target :can_attack \
           :buff_up :buff_down :debuff_up :debuff_down \
           :is_valid :is_valid_enemy :distance; do
  echo "=== $api ==="
  grep -rln "$api" apidocs/pages/ | head -3
done
```

Any API not found in the output above is **invented** and must be removed.

### 4.5 Final deliverable

```
Rotations/
└── Shaman/
    ├── header.lua   (load guard, class ID 7)
    └── main.lua     (single-file IZI SDK callback rotation, ~250-350 lines)
```

No other files. No `shared/`, no `core/`, no `tests/` (rotation has its own validation in 4.1-4.4).

---

## Out of scope (deliberately, per user)

- ❌ Resto and Enhancement specs (separate plans; same template applies)
- ❌ Spellbook audit / cross-class contamination (the `DEFS` is seeded from `wowhead_data/corpus/tbc/spells_shaman.md`, already validated)
- ❌ OOC manager, interrupt manager, consumable manager, leveling manager — these are EaxRotations libs the user wants to avoid
- ❌ A test harness (the verification checklist above is the contract)
- ❌ Cross-referencing competitor bots (apex, lazy rotation) — not asked

---

## Phase execution order (for `/claude-mem:do` or manual)

1. **Phase 1**: Create folder + header.lua + main.lua skeleton (2 files, no logic)
2. **Phase 2**: Seed DEFS, build menu, copy scan()
3. **Phase 3**: Write callbacks + action list + on_update
4. **Phase 4**: Run all verification; fix any grep fails; commit
