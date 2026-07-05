-- =============================================================================
-- test_autoloot_sylvanas.lua — Auto-loot module tests for EaxRotations.
-- WHAT:  Validates module load, settings keys, defaults, and on_tick safety.
-- SAFETY: pure unit tests; no game client dependency.
-- =============================================================================

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

-- Mock NS global
_G.NS = {
    time_now = function() return 100.0 end,
    log = function(msg) end,
    get_setting = function(key, fallback)
        local defaults = {
            eax_autoloot_enabled = false,
            eax_autoloot_combat_mode = 1,
            eax_autoloot_grace = 2,
            eax_autoloot_delay_min = 50,
            eax_autoloot_delay_max = 200,
            eax_autoloot_max_burst = 5,
            eax_autoloot_skip_players = true,
            eax_autoloot_stop_full = true,
            eax_autoloot_min_free = 2,
            eax_autoloot_range = 30,
        }
        return defaults[key] ~= nil and defaults[key] or fallback
    end,
}

-- Mock core
_G.core = nil

-- ── Test 1: Module loads ────────────────────────────────────────────────────
print("TEST 1: auto_loot module loads")
local ok, AutoLoot = pcall(require, "shared/auto_loot_sylvanas")
assert(ok, "Module failed to load: " .. tostring(AutoLoot))
assert(type(AutoLoot) == "table", "Module should return a table")
print("  PASS")

-- ── Test 2: API surface ─────────────────────────────────────────────────────
print("TEST 2: API surface")
assert(type(AutoLoot.on_tick) == "function", "on_tick missing")
assert(type(AutoLoot.find_corpses) == "function", "find_corpses missing")
assert(type(AutoLoot.loot_corpse) == "function", "loot_corpse missing")
assert(type(AutoLoot.reset) == "function", "reset missing")
print("  PASS")

-- ── Test 3: Settings keys ───────────────────────────────────────────────────
print("TEST 3: settings keys")
local S = AutoLoot.SETTINGS
assert(S.enabled == "eax_autoloot_enabled", "enabled key mismatch")
assert(S.combat_mode == "eax_autoloot_combat_mode", "combat_mode key mismatch")
assert(S.delay_min == "eax_autoloot_delay_min", "delay_min key mismatch")
assert(S.delay_max == "eax_autoloot_delay_max", "delay_max key mismatch")
assert(S.max_per_10s == "eax_autoloot_max_burst", "max_per_10s key mismatch")
assert(S.skip_players == "eax_autoloot_skip_players", "skip_players key mismatch")
assert(S.stop_bags_full == "eax_autoloot_stop_full", "stop_bags_full key mismatch")
assert(S.min_free == "eax_autoloot_min_free", "min_free key mismatch")
assert(S.range == "eax_autoloot_range", "range key mismatch")
print("  PASS")

-- ── Test 4: Defaults ────────────────────────────────────────────────────────
print("TEST 4: defaults")
local D = AutoLoot.DEFAULTS
assert(D.enabled == false, "default enabled should be false")
assert(D.combat_mode == 1, "default combat_mode should be 1 (OOC)")
assert(D.grace_period == 2, "default grace 2s")
assert(D.delay_min_ms == 50, "default min delay 50ms")
assert(D.delay_max_ms == 200, "default max delay 200ms")
assert(D.max_per_10s == 5, "default max per 10s 5")
assert(D.skip_players == true, "default skip_players true")
assert(D.stop_bags_full == true, "default stop_bags_full true")
assert(D.min_free_slots == 2, "default min_free_slots 2")
assert(D.range == 30, "default range 30")
print("  PASS")

-- ── Test 5: on_tick with disabled setting ───────────────────────────────────
print("TEST 5: on_tick when disabled does nothing")
AutoLoot.reset()
local ctx = { state = {}, in_combat = false, is_casting = false, is_channeling = false, on_gcd = false }
AutoLoot.on_tick(ctx) -- should not error when disabled
print("  PASS")

-- ── Test 6: Stats tracking ──────────────────────────────────────────────────
print("TEST 6: stats tracking")
AutoLoot.reset()
assert(AutoLoot.stats.corpses_looted == 0, "corpses_looted should be 0 after reset")
assert(AutoLoot.stats.paused_bags_full == false, "paused_bags_full should be false")
print("  PASS")

-- ── Test 7: Schema module loads ─────────────────────────────────────────────
print("TEST 7: schema module loads")
local ok2, Schema = pcall(require, "shared/schema_autoloot_sylvanas")
assert(ok2, "Schema module failed to load: " .. tostring(Schema))
assert(type(Schema.settings) == "function", "settings() missing")
assert(type(Schema.build_tab) == "function", "build_tab() missing")
local settings = Schema.settings()
assert(#settings == 10, "should have 10 settings, got " .. #settings)
print("  PASS")

-- ── Test 8: Schema build_tab structure ──────────────────────────────────────
print("TEST 8: schema build_tab structure")
local tab = Schema.build_tab()
assert(tab.name == "Auto-Loot", "tab name mismatch")
assert(type(tab.sections) == "table", "sections should be a table")
assert(#tab.sections == 1, "should have 1 section")
assert(tab.sections[1].header == "Auto-Loot", "section header mismatch")
assert(#tab.sections[1].settings == 10, "should have 10 settings in section")
print("  PASS")

print("\n========================================")
print("AutoLoot (EaxRotations) Tests: 8/8 PASSED")
print("========================================")
