-- test_bare_ns_value_reads_regression.lua — pins the two genuine fixes from
-- the 2026-08-11 bare-value-read sweep (NS-member audit rule extension).
-- The class: `NS.<member>` used as a bare VALUE read (not a call, so the
-- audit's call scanner structurally could not see it) of members that are
-- NEVER defined. The sweep found two live breaks:
--   (1) cat_sylvanas:127 `pcall(NS.get_item_count, id)` — NS.get_item_count
--       is undefined (core/items.lua owns the item API, no count query), so
--       the reference was nil and `pcall(nil, id)` ERRORED the moment a
--       ready healthstone was found. Fixed to guard the reference and fail
--       open on count (is_item_ready already proved the item usable).
--   (2) protection_sylvanas:414 `NS.get_party_members or NS.party_members`
--       — both undefined, so party_scan was nil live and the Intervene
--       ally scan never ran. Fixed to read the engine's authoritative
--       context.party_members (main_sylvanas.lua:932).
-- WHAT:  (A) cat healthstone: no reader -> first ready id (no crash, fail
--        open); reader returning 0 -> none; reader returning 7 -> first id.
--        (B) prot Intervene: context.party_members populated -> the lowest-
--        hp in-range ally becomes prot_state.tank; absent -> nil.
-- WHEN:  rotation suite execution (run_rotation_tests.lua).
-- WHY:   a future edit reverting either site to a bare NS read re-crashes
--        cat healthstone eating and re-deads the prot Intervene scan — the
--        audit rule now catches the class, these tests pin the two fixes.
-- SAFETY: mock NS before dofile (runner snapshots/restores _G per suite).

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;.api/?.lua;.api/?/?.lua;" .. package.path

local function assert_eq(a, b, label)
    if a ~= b then error("FAIL: " .. (label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
end
local function assert_true(v, label)
    if not v then error("FAIL: " .. (label or "assert_true"), 2) end
end

local function install_mock(module_name, factory)
    local orig_preload = package.preload[module_name]
    local orig_loaded = package.loaded[module_name]
    package.preload[module_name] = factory
    package.loaded[module_name] = nil
    return function()
        package.preload[module_name] = orig_preload
        package.loaded[module_name] = orig_loaded
    end
end

local function mock_spec_kit()
    return install_mock("shared/spec_kit_sylvanas", function()
        local M = {}
        M.merge_state = function(build_state, context) return build_state(context) end
        M.define_action_for_class = function(_)
            return function(_, ids, name) return { ids = ids, name = name } end
        end
        M.setting = function(ctx, key, default)
            local s = (ctx and ctx.settings) or {}
            return s[key] or default
        end
        M.setting_number = M.setting
        M.setting_bool = function(ctx, key, default)
            local s = (ctx and ctx.settings) or {}
            local v = s[key]
            if v == nil then return default end
            return v
        end
        M.safe_state = function(raw, schema)
            local proxy = {}
            setmetatable(proxy, {
                __index = function(t, k)
                    if raw[k] ~= nil then return raw[k] end
                    if schema and schema[k] ~= nil then return schema[k] end
                    return nil
                end,
            })
            for k, v in pairs(raw) do proxy[k] = v end
            return proxy
        end
        return M
    end)
end

-- ============================================================================
-- (A) cat_sylvanas healthstone path (crash fix)
-- ============================================================================
local restore_spec = mock_spec_kit()
local restore_leveling = install_mock("shared/leveling_helpers_sylvanas", function()
    return { is_low_level = function() return false end }
end)
local restore_energy = install_mock("shared/energy_tick_tracker_sylvanas", function()
    return {
        new_state = function() return {} end,
        estimate_next_tick = function() return 2.0 end,
        predicted_energy = function(_, energy) return math.min(100, (energy or 0) + 20) end,
    }
end)
local restore_potion = install_mock("shared/potion_helper_sylvanas", function()
    return { HEALTH_POTION_IDS = {}, MANA_POTION_IDS = {}, try_use_potion = function() return false end }
end)
local restore_engineering = install_mock("shared/engineering_helper_sylvanas", function() return nil end)
local restore_combat_mode = install_mock("shared/combat_mode_sylvanas", function() return nil end)
local restore_snapshot = install_mock("shared/snapshot_sylvanas", function()
    return { should_upgrade = function() return false end }
end)

local mock_item_ready, mock_item_count
_G.EaxRotations = _G.EaxRotations or {}
local NS = _G.EaxRotations
NS.log = function() end
NS.log_warning = function() end
NS.GetPlayer = function() return { get_health = function() return 100 end } end
NS.PLAYER_UNIT = "player"
NS.time_now = function() return 1000 end
NS.spell_ready = function() return true end
NS.try_cast = function() return false end
NS.debuff_remains = function() return 0 end
NS.get_debuff_stacks = function() return 0 end
NS.buff_up = function() return false end
NS.buff_remains = function() return 0 end
NS.has_form = function() return false end
NS.get_combo_points = function() return 0 end
NS.power_current = function() return 100 end
NS.power_pct = function() return 100 end
NS.health_pct = function() return 100 end
NS.energy = function() return 100 end
NS.spell_exists = function() return true end
NS.is_behind_target = function() return false end
NS.rotation_registry = { register = function() end }
NS.aoe_target_meets = function(threshold, radius, target, context, state) return threshold <= (state and state.enemy_count or 1) end
NS.DruidSpells = {}
NS.spell_action = function(ids, name) return { ids = ids, name = name } end
NS.is_item_ready = function(id) return mock_item_ready(id) end
NS.get_item_count = nil -- the never-defined member: absent unless the scenario sets it

local HEALTHSTONE_FIRST = 22105
local cat = dofile("EaxRotations/classes/druid/cat_sylvanas.lua")
assert_true(cat and cat.build_state, "cat module should load with build_state")

local function cat_ctx()
    return { me = { get_health = function() return 100 end }, target = {},
        energy = 100, combo_points = 0, mana_pct = 100, enemy_count = 1,
        in_combat = true, settings = {} }
end

-- Scenario 1: reader ABSENT -> fail open (the old code ERRORS: pcall(nil, id)).
mock_item_ready = function(id) return id == HEALTHSTONE_FIRST end
mock_item_count = nil
NS.get_item_count = nil
local st1 = cat.build_state(cat_ctx())
assert_eq(st1.healthstone_ready, HEALTHSTONE_FIRST,
    "healthstone ready with get_item_count ABSENT (fail-open, no pcall(nil) crash)")

-- Scenario 2: reader PRESENT, count 0 -> silent (no ready healthstone).
NS.get_item_count = function(id) return 0 end
local st2 = cat.build_state(cat_ctx())
assert_eq(st2.healthstone_ready, 0, "healthstone NOT ready when count reader says 0")

-- Scenario 3: reader PRESENT, count > 0 -> first ready id.
NS.get_item_count = function(id) return 7 end
local st3 = cat.build_state(cat_ctx())
assert_eq(st3.healthstone_ready, HEALTHSTONE_FIRST, "healthstone ready when count reader says 7")

restore_spec(); restore_leveling(); restore_energy(); restore_potion()
restore_engineering(); restore_combat_mode(); restore_snapshot()

-- ============================================================================
-- (B) protection_sylvanas Intervene ally scan (party_members fix)
-- ============================================================================
local restore_spec2 = mock_spec_kit()
local restore_potion2 = install_mock("shared/potion_helper_sylvanas", function()
    return { HEALTH_POTION_IDS = {}, MANA_POTION_IDS = {}, try_use_potion = function() return false end }
end)
-- strategy_dsl loads REAL (it only requires the mocked spec_kit); prot
-- needs its compile_strategy at module load.
local restore_offensive = install_mock("shared/offensive_dispel_sylvanas", function()
    return { find_best_dispel_target = function() return nil end }
end)

local me2 = { get_position = function(self) return { x = 0, y = 0, z = 0 } end }
local ally_low = { get_position = function(self) return { x = 10, y = 0, z = 0 } end }
local ally_high = { get_position = function(self) return { x = 5, y = 0, z = 0 } end }
ally_low._hp, ally_high._hp = 30, 80

NS.WarriorSpells = {}
NS.get_debuff_stacks = function() return 0 end
NS.debuff_remains = function() return 0 end
NS.is_interruptible = function() return false end
NS.buff_up = function() return false end
NS.spell_ready = function() return true end
NS.unit_health_pct = function(u) return u and u._hp or 100 end
NS.not_same_unit = function(a, b) return a ~= b end
NS.unit_mana_pct = function() return 100 end
NS.is_valid_target = function(u) return u ~= nil end
NS.GetPlayer = function() return me2 end

local prot = dofile("EaxRotations/classes/warrior/protection_sylvanas.lua")
assert_true(prot and prot.build_state, "protection module should load with build_state")

-- Scenario 1: party_members populated -> lowest-hp in-range ally becomes tank.
local ctx_group = { me = me2, target = {}, is_group = true, has_valid_enemy_target = true,
    in_combat = true, stance = 2, rage = 40, party_members = { ally_low, ally_high }, settings = {} }
local p1 = prot.build_state(ctx_group)
assert_true(p1.tank ~= nil, "Intervene scan populates tank from context.party_members")
assert_true(p1.tank.unit == ally_low, "lowest-hp in-range ally is chosen")
assert_true(p1.lowest_allied ~= nil, "lowest_allied mirrors the scan result")

-- Scenario 2: no party_members -> tank nil (the OLD code was always nil live).
local ctx_solo = { me = me2, target = {}, is_group = true, has_valid_enemy_target = true,
    in_combat = true, stance = 2, rage = 40, settings = {} }
local p2 = prot.build_state(ctx_solo)
assert_eq(p2.tank, nil, "no party_members -> tank nil (safe, no scan)")

restore_spec2(); restore_potion2(); restore_offensive()

print("PASS test_bare_ns_value_reads_regression (cat healthstone fail-open/0/7, prot Intervene party_members scan)")
