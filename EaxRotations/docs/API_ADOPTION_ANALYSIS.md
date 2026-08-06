# EaxRotations API Adoption & Performance Analysis

Generated: 2026-06-13
Source: https://docs.project-sylvanas.net/dev/ (46 pages scraped)

---

## 1. Current API Usage (Already Adopted)

EaxRotations already uses ~15 native Project Sylvanas APIs. This is excellent:

| API | Module | Usage | Status |
|-----|--------|-------|--------|
| `buff_manager` | `common/modules/buff_manager` | Cached aura queries | Primary path |
| `spell_queue` | `common/modules/spell_queue` | Shared plugin queue | Primary path |
| `spell_helper` | `common/utility/spell_helper` | Native spell readiness | Primary path |
| `cooldown_tracker` | `common/utility/cooldown_tracker` | Enemy CD observation | Primary path |
| `auto_attack_helper` | `common/utility/auto_attack_helper` | Swing timer | Primary path |
| `pvp_helper` | `common/utility/pvp_helper` | DR/trinket/burst | Primary path |
| `cc_data_helper` | `common/utility/cc_data_helper` | NPC CC immunity | Primary path |
| `unit_helper` | `common/utility/unit_helper` | Boss/dummy/health pred | Primary path |
| `spell_sequence` | `common/utility/spell_sequence_helper` | Multi-step sequences | Primary path |
| `target_selector` | `common/modules/target_selector` | Pre-filtered enemies | Primary path |
| `health_prediction` | `common/modules/health_prediction` | Tank/PvP detection | Primary path |
| `inventory_helper` | `common/utility/inventory_helper` | Consumable tracking | Primary path |
| `combat_forecast` | `common/modules/combat_forecast` | Incoming damage | Primary path |
| `spell_prediction` | `common/modules/spell_prediction` | AoE position opt | Partial use |

---

## 2. Performance Bottlenecks (Critical)

### 2.1 `pcall` Overhead in Hot Paths (HIGHEST IMPACT)

Every frame, the rotation does **100-200+ `pcall` calls** through `safe()` and `safe_field()` wrappers:

```lua
-- In core_sylvanas.lua, lines ~412-432:
local function safe(fn, ...)
 if type(fn) ~= "function" then return nil end
 local ok, a, b, c = pcall(fn, ...) -- <-- pcall overhead
 if ok then return a, b, c end
 return nil
end

local function safe_field(obj, key)
 if not obj then return nil end
 local ok, value = pcall(function() return obj[key] end) -- <-- pcall overhead
 return ok and value or nil
end
```

**Impact:** `pcall` creates a new Lua call frame and error handler. In a 20-strategy rotation with 5 buff checks each, that's 100 pcalls/frame × 60fps = 6,000 pcalls/second. Each pcall costs ~50-100ns in C but the Lua frame overhead is ~0.5-1μs, totaling 3-6ms/sec of pure overhead.

**Affected functions (hot path):**
- `NS.buff_up()` → `pcall` on buff_manager + fallback pcalls
- `NS.debuff_up()` → same pattern
- `NS.unit_health_pct()` → `safe_field` + `safe`
- `NS.mana_pct()` → `safe_field` + `safe`
- `NS.gcd_remains()` → `safe_field` + `safe`
- `NS.unit_alive()` → `pcall` wrapper around inner function
- `NS.power_current()` → `safe_field` + `safe`
- `NS.GetPlayer()` → `pcall` every tick
- `NS.spell_ready()` → `pcall` on spell_helper
- `NS.is_spell_in_range()` → `pcall` on spell_helper
- `NS.cooldown_remains()` → `pcall` on spell_helper

**Fix:** Add direct-call fast paths for known-safe objects. The player object is validated once per tick; subsequent method calls don't need pcall.

### 2.2 Settings Cache (HIGH IMPACT)

```lua
-- In core_sylvanas.lua, lines ~1156-1183:
function NS.get_setting(key, default)
 if _settings_manager then
 local v = _settings_manager:get(key)
 if v ~= nil then return v end
 end
 local now = _settings_cache_time()
 if now - _settings_cache_last_update > _SETTINGS_CACHE_TTL then -- 200ms
 _settings_cache = {}
 for k, v in pairs(NS.settings) do _settings_cache[k] = v end
 _settings_cache_last_update = now
 end
 local value = _settings_cache[key]
 if value == nil then return default end
 return value
end
```

**Problem:** `_settings_manager` is declared at line 107 but **never initialized** (no `pcall(require, "common/modules/settings_manager")`). The manual cache rebuilds every 200ms, copying the entire settings table. This is O(n) where n = number of settings.

**Fix:** Load `settings_manager` at module init. It provides engine-level caching with O(1) lookups.

### 2.3 Combat State Detection (MEDIUM IMPACT)

```lua
-- In main_sylvanas.lua, lines ~415-429:
local is_in_combat = NS.safe_field and NS.safe_field(me, "is_in_combat") or nil
local raw_in_combat = is_in_combat and fast(is_in_combat, me) or nil
local combat_state_known = type(raw_in_combat) == "boolean"
local in_combat
if combat_state_known then
 in_combat = raw_in_combat
 _combat_state_last_known = NS.time_now()
else
 if was_in_combat and NS.time_now() - _combat_state_last_known > 1.0 then
 was_in_combat = false
 end
 in_combat = was_in_combat
end
```

**Problem:** Manual combat detection with decay logic. The engine provides `core.register_on_combat_start_callback` and `core.register_on_combat_end_callback` (documented in `dev_api_core.md`).

**Fix:** Use native callbacks. Eliminates per-frame combat state uncertainty and the 1s decay window.

### 2.4 Spell Cache Key Generation (MEDIUM IMPACT)

```lua
-- In core_sylvanas.lua, lines ~1989-2001:
local function spell_cache_key(spell, ids)
 local key = table.concat(ids, ":")
 local meta = type(spell) == "table" and spell._meta or nil
 if meta and type(meta.levels) == "table" then
 key = key .. "|levels=" .. table.concat(meta.levels, ":")
 end
 return key
end
```

**Problem:** `table.concat` allocates a new string every time. This is called for every spell lookup in `NS.get_spell_id()`.

**Fix:** Use numeric hash or pre-computed keys. For small ID arrays, a direct concatenation is faster than table.concat.

### 2.5 Enemy Counting (MEDIUM IMPACT)

```lua
-- In main_sylvanas.lua, lines ~317-328:
local function throttled_enemies()
 local now = NS.game_time_ms and NS.game_time_ms() or 0
 if now - _cached_enemies_time > 100 then
 if target_selector and type(target_selector.get_targets) == "function" then
 _cached_enemies = target_selector:get_targets(40)
 else
 _cached_enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(40) or nil
 end
 _cached_enemies_time = now
 end
 return _cached_enemies
end
```

**Problem:** 100ms throttle adds latency. `target_selector` already has engine-level caching. The double-throttle (engine + manual) adds 100ms of stale data.

**Fix:** Use `core.object_manager.get_enemy_list()` directly (documented in `dev_api_object-manager.md`). The engine list is already updated every frame.

### 2.6 Incoming Heal Prediction (MEDIUM IMPACT)

```lua
-- In shared/incoming_heal_predictor_sylvanas.lua:
local HEAL_SIZE_FALLBACK = {
 ["greater heal"] = 3500,
 ["flash heal"] = 1500,
 ...
}
```

**Problem:** Manual heuristic-based prediction. The engine provides `get_incoming_heals()` on game_objects (documented in `dev_api_game-object.md`).

**Fix:** Use native `get_incoming_heals()` as primary path, keep heuristics as fallback.

---

## 3. APIs Not Yet Used (Opportunity)

### 3.1 `settings_manager` (HIGH PRIORITY)
- **Location:** `common/modules/settings_manager`
- **Docs:** `apidocs/pages/dev/modules/settings-manager.md`
- **Benefit:** Engine-level caching, O(1) lookups, no manual 200ms rebuild
- **Effort:** Low—add `pcall(require, ...)` at module init
- **Status (2026-07-10):** Now loaded in core_sylvanas.lua (right after cooldown_tracker) and passed to core/settings install. Primary path in NS.get_setting / set_setting is active. Manual cache is now only fallback. (Also cleaned dead legacy _settings_cache code + small fast-path: cached safe/safe_field in units.GetPet.)

### 3.2 `core.register_on_combat_start_callback` / `core.register_on_combat_end_callback` (HIGH PRIORITY)
- **Location:** `core` API
- **Docs:** `dev_api_core.md` (lines ~25-55)
- **Benefit:** Eliminates manual combat state detection and decay logic
- **Effort:** Low—replace manual state tracking with callbacks
- **Status (2026-07-10):** Wired in main_sylvanas.lua build_context load: engine callbacks now drive _combat_start_time / was_in_combat for more accurate live combat_time and state (with poll fallback). See also enriched context fields.

### 3.3 `core.object_manager.get_enemy_list` / `get_ally_list` (MEDIUM PRIORITY)
- **Location:** `core.object_manager`
- **Docs:** `dev_api_object-manager.md`
- **Benefit:** Direct access to engine enemy/ally lists without target_selector wrapper
- **Effort:** Low—replace `throttled_enemies()` with direct call
- **Status (2026-07-10):** unit_helper (which uses optimized lists) now loaded in main_sylvanas and used as fallback/preferred path in throttled_enemies() via get_enemy_list_around when target_selector unavailable. Promotes the recommended API. Also cleaned dead legacy _settings_cache code in core_sylvanas (now fully delegated). Small perf wins: cached safe/safe_field in units.GetPet/GetPlayer; consolidated hot APIs to _api table (fixed upvalue limit, hoisted all for lookup reduction in build_context and paths); deduped in core; added boss/party frame counts to context (from subagent + plan for deeper api-driven context).

### 3.4 `core.buffs.get_buffs` / `get_debuffs` (MEDIUM PRIORITY)
- **Location:** `core.buffs`
- **Docs:** `dev_api_buffs.md`
- **Benefit:** Bulk aura queries instead of per-ID buff_manager calls
- **Effort:** Medium—refactor `NS.buff_up`/`debuff_up` to use bulk API

### 3.5 `core.spell_book.get_specialization_id` (LOW PRIORITY)
- **Location:** `core.spell_book`
- **Docs:** `dev_api_spellbook.md`
- **Benefit:** Native spec detection for class middleware
- **Effort:** Low—add to class detection logic

### 3.6 `core.input.get_key_state` (LOW PRIORITY)
- **Location:** `core.input`
- **Docs:** `dev_api_input.md`
- **Benefit:** Manual key detection for toggles (instead of menu-only)
- **Effort:** Low—add keybind detection utility

### 3.7 `core.graphics` (LOW PRIORITY)
- **Location:** `core.graphics`
- **Docs:** `dev_api_graphics.md`
- **Benefit:** Native rendering instead of `sdf_render_sylvanas.lua` custom overlay
- **Effort:** High—replace entire rendering subsystem

### 3.8 `izi.units` (LOW PRIORITY)
- **Location:** `IZI SDK`
- **Docs:** `dev_libraries_izi_units.md`
- **Benefit:** Advanced unit filtering (smart enemies, friends, party)
- **Effort:** Medium—replace manual filtering with IZI queries

### 3.9 `izi.callbacks` (LOW PRIORITY)
- **Location:** `IZI SDK`
- **Docs:** `dev_libraries_izi_callbacks.md`
- **Benefit:** Event-driven callbacks for buffs, combat, spells, keyboard
- **Effort:** Medium—replace manual callback registration with IZI wrappers

### 3.10 `core.quests` (VERY LOW PRIORITY)
- **Location:** `core.quests`
- **Docs:** `dev_api_quests.md`
- **Benefit:** Quest-aware rotation logic (e.g., don't pull during escort)
- **Effort:** Medium—add quest state checks to rotation gates

---

## 4. Recommended Implementation Order

### Phase 1: Fast Wins (0.5-1 day)
1. **Load settings_manager** → replace manual cache
2. **Use native combat callbacks** → replace manual state detection
3. **Use get_enemy_list directly** → replace throttled_enemies()
4. **Optimize safe_field/safe** → add fast paths for known-valid objects

### Phase 2: Hot Path Optimization (1-2 days)
5. **Cache buff_manager lookups** → avoid pcall on every buff check
6. **Cache spell_helper lookups** → avoid pcall on every spell_ready
7. **Optimize spell cache keys** → reduce string allocation
8. **Use native get_incoming_heals** → replace heuristic predictor

### Phase 3: API Expansion (2-3 days)
9. **Use core.buffs.get_buffs for bulk queries**
10. **Add get_specialization_id for spec detection**
11. **Add get_key_state for manual toggles**
12. **Evaluate izi.units for advanced filtering**

---

## 5. Expected Performance Impact

| Optimization | pcall/frame | ms/tick (before) | ms/tick (after) | Improvement |
|-------------|-------------|------------------|-----------------|-------------|
| safe_field/safe fast path | -50 to -100 | ~0.5-1.0 | ~0.3-0.5 | 40-50% |
| settings_manager | -1 | ~0.05 | ~0.01 | 80% |
| combat callbacks | -2 | ~0.02 | ~0.005 | 75% |
| enemy_list direct | -1 | ~0.05 | ~0.02 | 60% |
| spell_helper cache | -20 to -40 | ~0.3-0.5 | ~0.15-0.25 | 50% |
| buff_manager cache | -30 to -60 | ~0.4-0.8 | ~0.2-0.4 | 50% |
| **TOTAL** | **-104 to -204** | **~1.3-2.4** | **~0.7-1.2** | **~50%** |

---

## 6. Files to Modify

| File | Changes | Priority |
|------|---------|----------|
| `core_sylvanas.lua` | Load settings_manager, optimize safe_field/safe, cache spell_helper, optimize buff checks | High |
| `main_sylvanas.lua` | Use combat callbacks, use get_enemy_list directly | High |
| `shared/incoming_heal_predictor_sylvanas.lua` | Use native get_incoming_heals | Medium |
| `shared/combat_forecast_gate_sylvanas.lua` | Use unit_helper.is_boss | Low |
| `shared/tick_profiler_sylvanas.lua` | Add metrics for pcall count | Low |

---

## 7. Verification Plan

1. **Syntax:** `luac -p` on all modified files
2. **Tests:** Run `lua EaxRotations/tests/run_rotation_tests.lua` (95 suites)
3. **Tests:** Run `lua EaxRotations/tests/run_leveling_tests.lua` (11 suites)
4. **Benchmark:** Compare tick profiler metrics before/after
5. **Regression:** Ensure no change in rotation behavior (same spells cast in same order)
