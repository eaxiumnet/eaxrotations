-- Readability notes:
--   What: trinket manager strategy matching regression test.
--   When: run with lua from the repository root.
--   Why: confirms offensive/defensive trinket matching, cooldown gating, and HP thresholds.
--   Safety: no game input APIs are called; all dependencies are mocked.

-- Decision notes:
--   Tests use local stubs instead of a live Sylvanas client so API-bound behavior remains reproducible.
--   Each case protects one previous failure mode or role rule; keep assertions narrow and descriptive.
--   No test should call real input/cast APIs because regression runs must be safe outside the game.

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed: expected false", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- Shared mock player with configurable trinkets
local function make_player(trinket1_id, trinket1_cd_start, trinket1_cd_dur, in_combat)
    return {
        get_equipped_item_id = function(self, slot)
            if slot == 13 then return trinket1_id or nil end
            if slot == 14 then return nil end
            return nil
        end,
        get_item_at_inventory_slot = function(self, slot)
            if slot == 13 then return trinket1_id or nil end
            if slot == 14 then return nil end
            return nil
        end,
        get_item_cooldown = function(self, item_id)
            if item_id == trinket1_id then
                return trinket1_cd_start or 0, trinket1_cd_dur or 0
            end
            return 0, 0
        end,
        is_in_combat = function() return in_combat or false end,
        is_casting = function() return false end,
        is_channeling = function() return false end,
    }
end

-- Build NS with a given player factory
local function build_ns(player_factory)
    local use_item_called = false
    local NS = {
        EQUIPMENT_SLOTS = {TRINKET1 = 13, TRINKET2 = 14},
        time_now = function() return 100 end,
        game_time_ms = function() return 100000 end,
        GetPlayer = player_factory,
        -- trinket_manager calls NS.get_equipped_item_id directly
        get_equipped_item_id = function(slot)
            local me = player_factory()
            if me and me.get_equipped_item_id then
                return me:get_equipped_item_id(slot)
            end
            return nil
        end,
        GetTarget = function()
            return {is_hostile = function() return true end}
        end,
        try_cast = function(spell, target, reason, opts) return true end,
        gcd_remains = function() return 0 end,
        unit_health_pct = function(unit) return 50 end,
        is_hostile_unit = function(me, target) return true end,
        safe_field = function(obj, key)
            if not obj then return nil end
            local ok, val = pcall(function() return obj[key] end)
            return ok and val or nil
        end,
        get_setting = function(key, default)
            if key == "use_trinket_1" then return true end
            if key == "use_trinket_2" then return true end
            if key == "use_trinket_offensive" then return true end
            if key == "use_trinket_defensive" then return true end
            if key == "trinket_defensive_hp" then return 40 end
            if key == "use_cooldowns" then return true end
            return default
        end,
        settings = {},
        log = function() end,
        log_warning = function() end,
        GetCurrentContext = function() return nil end,
        spell_book = {
            is_item_ready = function(item_id) return true end,
            get_spell_cooldown_information = function(item_id) return nil end,
        },
    }
    _G.EaxRotations = NS
    _G.core = {
        spell_book = {
            is_item_ready = function(item_id) return true end,
            get_spell_cooldown_information = function(item_id) return nil end,
        },
        input = {
            use_item = function(slot)
                use_item_called = true
                return true
            end,
        },
    }
    return NS, function() return use_item_called end
end

-- Load the trinket manager
dofile("EaxRotations/shared/trinket_manager_sylvanas.lua")
local M = _G.EaxTrinketManager
assert_true(M ~= nil, "TrinketManager should be loaded")

-- Verify trinket database
local entry = M.get_trinket_entry(29383)
assert_eq(entry.name, "Bloodlust Brooch", "Bloodlust Brooch should be in trinket DB")
assert_eq(entry.kind, "offensive", "Bloodlust Brooch kind should be offensive")

-- Test 1: Offensive trinket matches during burst (in combat, valid target, trinket ready)
do
    local NS, get_called = build_ns(function() return make_player(29383, 0, 0, true) end)
    package.loaded["EaxRotations.shared.trinket_manager_sylvanas"] = nil
    dofile("EaxRotations/shared/trinket_manager_sylvanas.lua")
    local M2 = _G.EaxTrinketManager

    local ctx = {
        me = make_player(29383, 0, 0, true),
        target = {is_hostile = function() return true end},
        settings = NS.settings,
        in_combat = true,
        has_valid_enemy_target = true,
        should_burst = true,
    }
    local result = M2.on_update(ctx)
    assert_true(result, "on_update should return true when offensive trinket matches during burst")
    assert_true(get_called(), "use_item should have been called for offensive trinket")
end

-- Test 2: Defensive trinket matches when HP < 40%
do
    local NS, get_called = build_ns(function() return make_player(28528, 0, 0, true) end)
    package.loaded["EaxRotations.shared.trinket_manager_sylvanas"] = nil
    dofile("EaxRotations/shared/trinket_manager_sylvanas.lua")
    local M2 = _G.EaxTrinketManager

    local ctx = {
        me = make_player(28528, 0, 0, true),
        settings = NS.settings,
        hp = 35,
        in_combat = true,
    }
    local result = M2.on_update(ctx)
    assert_true(result, "on_update should return true when defensive trinket matches at HP 35% (< 40%)")
    assert_true(get_called(), "use_item should have been called for defensive trinket")
end

-- Test 3: Does NOT match when trinket is on cooldown
do
    local NS, get_called = build_ns(function() return make_player(29383, 60, 120, true) end)
    package.loaded["EaxRotations.shared.trinket_manager_sylvanas"] = nil
    dofile("EaxRotations/shared/trinket_manager_sylvanas.lua")
    local M2 = _G.EaxTrinketManager

    local ctx = {
        me = make_player(29383, 60, 120, true),
        target = {is_hostile = function() return true end},
        settings = NS.settings,
        in_combat = true,
        has_valid_enemy_target = true,
        should_burst = true,
    }
    local result = M2.on_update(ctx)
    assert_false(result, "on_update should return false when trinket is on cooldown")
    assert_false(get_called(), "use_item should NOT be called when trinket is on cooldown")
end

-- Test 4: Does NOT match when HP >= defensive threshold
do
    local NS, get_called = build_ns(function() return make_player(28528, 0, 0, true) end)
    package.loaded["EaxRotations.shared.trinket_manager_sylvanas"] = nil
    dofile("EaxRotations/shared/trinket_manager_sylvanas.lua")
    local M2 = _G.EaxTrinketManager

    local ctx = {
        me = make_player(28528, 0, 0, true),
        settings = NS.settings,
        hp = 80,
        in_combat = true,
    }
    local result = M2.on_update(ctx)
    assert_false(result, "on_update should return false when HP 80% >= 40% defensive threshold")
    assert_false(get_called(), "use_item should NOT be called when HP is above defensive threshold")
end

-- Test 5: Does NOT match when not in combat (offensive trinket)
do
    local NS, get_called = build_ns(function() return make_player(29383, 0, 0, false) end)
    package.loaded["EaxRotations.shared.trinket_manager_sylvanas"] = nil
    dofile("EaxRotations/shared/trinket_manager_sylvanas.lua")
    local M2 = _G.EaxTrinketManager

    local ctx = {
        me = make_player(29383, 0, 0, false),
        target = {is_hostile = function() return true end},
        settings = NS.settings,
        in_combat = false,
        has_valid_enemy_target = true,
        should_burst = true,
    }
    local result = M2.on_update(ctx)
    assert_false(result, "on_update should return false when not in combat (offensive trinket)")
    assert_false(get_called(), "use_item should NOT be called when not in combat")
end

print("PASS trinket_manager")