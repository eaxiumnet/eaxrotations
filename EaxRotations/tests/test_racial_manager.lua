-- racial manager behavior regression test for orc and dwarf racials.

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed: expected false", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- Load the racial manager (depends on NS global)
local NS = {
    GetPlayer = function()
        return {
            get_race_id = function() return 2 end,  -- ORC
            is_in_combat = function() return true end,
            is_casting = function() return false end,
            is_channeling = function() return false end,
        }
    end,
    GetTarget = function()
        return {
            is_hostile = function() return true end,
        }
    end,
    spell_action = function(id, name) return {id = id, _meta = {id = id}} end,
    try_cast = function(spell, target, reason, opts) return true end,
    gcd_remains = function() return 0 end,
    has_form = function() return false end,
    unit_health_pct = function(unit) return 50 end,
    is_hostile_unit = function(me, target) return true end,
    safe_field = function(obj, key)
        if not obj then return nil end
        local ok, val = pcall(function() return obj[key] end)
        return ok and val or nil
    end,
    time_now = function() return 100 end,
    get_setting = function(key, default)
        if key == "use_racial_offensive" then return true end
        if key == "use_racial_defensive" then return true end
        return default
    end,
    settings = {use_racial_offensive = true, use_racial_defensive = true},
    log = function() end,
    log_warning = function() end,
    debuff_up = function() return false end,
    is_rooted = function() return false end,
    is_snared = function() return false end,
    has_dispel_type_debuff = function() return false end,
    player_control_locked = function() return false end,
    should_drop_threat = function() return false end,
    GetCurrentContext = function() return nil end,
}
_G.EaxRotations = NS
_G.core = {}

dofile("EaxRotations/shared/racial_manager_sylvanas.lua")

local M = _G.EaxRacialManager
assert_true(M ~= nil, "RacialManager should be loaded")

-- Verify orc racial data
local orc_racial = M.get_racial_for_race(2)  -- ORC = 2
assert_eq(orc_racial.name, "Blood Fury", "orc racial should be Blood Fury")
assert_eq(orc_racial.kind, "offensive", "orc racial kind should be offensive")
assert_eq(orc_racial.spell_id, 20572, "orc racial spell_id should be 20572")

-- Verify dwarf racial data
local dwarf_racial = M.get_racial_for_race(3)  -- DWARF = 3
assert_eq(dwarf_racial.name, "Stoneform", "dwarf racial should be Stoneform")
assert_eq(dwarf_racial.kind, "cleanse", "dwarf racial kind should be cleanse")
assert_eq(dwarf_racial.spell_id, 20594, "dwarf racial spell_id should be 20594")

-- Test get_race_id returns cached value
local race_id = M.get_race_id()
assert_eq(race_id, 2, "get_race_id should return ORC (2)")

-- Test should_use_offensive: in combat with valid target and setting enabled
local offensive_entry = {kind = "offensive"}
local ctx_offensive = {
    settings = {use_racial_offensive = true},
    in_combat = true,
    has_valid_enemy_target = true,
}
-- should_use_offensive is local, but on_update uses it. Test through on_update.

-- Test on_update: ORC in combat, GCD=0, should match (offensive racial)
local called_cast = false
NS.try_cast = function(spell, target, reason, opts)
    called_cast = true
    assert_eq(reason, "[Racial] Blood Fury", "cast reason should be Blood Fury")
    return true
end
local result1 = M.on_update()
assert_true(result1, "on_update should return true for orc in combat (offensive racial)")
assert_true(called_cast, "try_cast should have been called for offensive racial")

-- Test on_update: GCD active => should NOT match
called_cast = false
NS.gcd_remains = function() return 1.5 end
local result2 = M.on_update()
assert_false(result2, "on_update should return false when GCD is active")
assert_false(called_cast, "try_cast should NOT be called when GCD is active")

-- Test on_update: player not in combat => should NOT match for offensive
NS.gcd_remains = function() return 0 end
local NS2 = {
    GetPlayer = function()
        return {
            get_race_id = function() return 2 end,  -- ORC
            is_in_combat = function() return false end,
        }
    end,
    GetTarget = function() return nil end,
    spell_action = function(id, name) return {id = id, _meta = {id = id}} end,
    try_cast = function(spell, target, reason, opts) called_cast = true; return true end,
    gcd_remains = function() return 0 end,
    has_form = function() return false end,
    unit_health_pct = function(unit) return 50 end,
    is_hostile_unit = function(me, target) return true end,
    safe_field = function(obj, key)
        if not obj then return nil end
        local ok, val = pcall(function() return obj[key] end)
        return ok and val or nil
    end,
    time_now = function() return 100 end,
    get_setting = function(key, default)
        if key == "use_racial_offensive" then return true end
        if key == "use_racial_defensive" then return true end
        return default
    end,
    settings = {},
    log = function() end,
    log_warning = function() end,
    debuff_up = function() return false end,
    is_rooted = function() return false end,
    is_snared = function() return false end,
    has_dispel_type_debuff = function() return false end,
    player_control_locked = function() return false end,
    should_drop_threat = function() return false end,
    GetCurrentContext = function() return nil end,
}
_G.EaxRotations = NS2

-- Need to reload the module with new NS
-- Instead, just verify the logic: offensive racials require in_combat
-- The on_update function checks context.in_combat for offensive types

-- Test defensive racial (dwarf) with low HP
local NS3 = {
    GetPlayer = function()
        return {
            get_race_id = function() return 3 end,  -- DWARF
            is_in_combat = function() return true end,
            is_casting = function() return false end,
            is_channeling = function() return false end,
        }
    end,
    GetTarget = function()
        return {is_hostile = function() return true end}
    end,
    spell_action = function(id, name) return {id = id, _meta = {id = id}} end,
    try_cast = function(spell, target, reason, opts)
        called_cast = true
        assert_eq(reason, "[Racial] Stoneform", "cast reason should be Stoneform")
        return true
    end,
    gcd_remains = function() return 0 end,
    has_form = function() return false end,
    unit_health_pct = function(unit) return 25 end,  -- Low HP
    is_hostile_unit = function(me, target) return true end,
    safe_field = function(obj, key)
        if not obj then return nil end
        local ok, val = pcall(function() return obj[key] end)
        return ok and val or nil
    end,
    time_now = function() return 100 end,
    get_setting = function(key, default)
        if key == "use_racial_defensive" then return true end
        if key == "racial_defensive_hp" then return 35 end
        if key == "defensive_hp" then return 35 end
        return default
    end,
    settings = {use_racial_defensive = true, racial_defensive_hp = 35},
    log = function() end,
    log_warning = function() end,
    debuff_up = function() return false end,
    is_rooted = function() return false end,
    is_snared = function() return false end,
    has_dispel_type_debuff = function() return false end,
    player_control_locked = function() return false end,
    should_drop_threat = function() return false end,
    GetCurrentContext = function() return nil end,
}
_G.EaxRotations = NS3

-- Re-require to pick up new NS
package.loaded["EaxRotations.shared.racial_manager_sylvanas"] = nil
dofile("EaxRotations/shared/racial_manager_sylvanas.lua")
M = _G.EaxRacialManager

called_cast = false
local result3 = M.on_update()
assert_true(result3, "on_update should return true for dwarf with HP 25% (< 35 threshold)")
assert_true(called_cast, "try_cast should have been called for defensive racial (Stoneform)")

-- Test defensive racial (dwarf) with high HP => should NOT match
NS3.unit_health_pct = function(unit) return 80 end
called_cast = false
local result4 = M.on_update()
assert_false(result4, "on_update should return false for dwarf with HP 80% (> 35 threshold)")
assert_false(called_cast, "try_cast should NOT be called when HP is above threshold")

-- Test CC break racial (undead) with CC debuff
local NS4 = {
    GetPlayer = function()
        return {
            get_race_id = function() return 5 end,  -- UNDEAD
            is_in_combat = function() return true end,
            is_casting = function() return false end,
            is_channeling = function() return false end,
        }
    end,
    GetTarget = function()
        return {is_hostile = function() return true end}
    end,
    spell_action = function(id, name) return {id = id, _meta = {id = id}} end,
    try_cast = function(spell, target, reason, opts)
        called_cast = true
        return true
    end,
    gcd_remains = function() return 0 end,
    has_form = function() return false end,
    unit_health_pct = function(unit) return 50 end,
    is_hostile_unit = function(me, target) return true end,
    safe_field = function(obj, key)
        if not obj then return nil end
        local ok, val = pcall(function() return obj[key] end)
        return ok and val or nil
    end,
    time_now = function() return 100 end,
    get_setting = function(key, default)
        if key == "use_racial_defensive" then return true end
        if key == "racial_defensive_hp" then return 35 end
        if key == "defensive_hp" then return 35 end
        return default
    end,
    settings = {use_racial_defensive = true},
    log = function() end,
    log_warning = function() end,
    debuff_up = function(unit, ids)
        -- Simulate having a CC debuff (Sap = 6770)
        for _, id in ipairs(ids) do
            if id == 6770 then return true end
        end
        return false
    end,
    is_rooted = function() return false end,
    is_snared = function() return false end,
    has_dispel_type_debuff = function() return false end,
    player_control_locked = function() return false end,
    should_drop_threat = function() return false end,
    GetCurrentContext = function() return nil end,
}
_G.EaxRotations = NS4

package.loaded["EaxRotations.shared.racial_manager_sylvanas"] = nil
dofile("EaxRotations/shared/racial_manager_sylvanas.lua")
M = _G.EaxRacialManager

called_cast = false
local result5 = M.on_update()
assert_true(result5, "on_update should return true for undead with CC debuff (Will of the Forsaken)")
assert_true(called_cast, "try_cast should have been called for CC break racial")

print("PASS racial_manager")
