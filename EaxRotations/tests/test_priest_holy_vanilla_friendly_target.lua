-- test_priest_holy_vanilla_friendly_target.lua -- Holy Priest Vanilla-era compatibility friendly target targeting tests.
-- WHAT:  Holy Priest Vanilla-era compatibility friendly target targeting tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Verifies Vanilla/Classic-era rotation compatibility and spell availability.
-- SAFETY: Tests only Vanilla spell IDs and mechanics.

-- B6 FriendlyTarget for vanilla priest holy.
package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

local _ft_unit = { _friendly = true, is_player = function() return true end }
local _ft_hp = 75
local _ft_hostile = false
local _ft_present = true
local _last_cast = nil

_G.core = { time = function() return 0 end, log = function() end }
_G.EaxRotations = {
    PriestSpells = { GreaterHeal = 25314, FlashHeal = 25315, PowerWordShield = 25218, Renew = 25222, BindingHeal = 32546, PrayerOfHealing = 25331, CircleOfHealing = 34861, Lightwell = 724, InnerFocus = 14751 },
    CLASS_ID = { PRIEST = 5 },
    PLAYER_UNIT = { _mock = true },
    GetPlayer = function() return nil end,
    GetTarget = function() return _ft_present and _ft_unit or nil end,
    GetPlayer = function() return { get_class = function() return 5 end } end,
    GetEnemiesInRange = function() return { { is_casting = function() return true end, can_attack = function() return true end } } end,
    is_hostile_unit = function() return _ft_hostile end,
    unit_alive = function(u) return u ~= nil end,
    unit_health_pct = function(u) if u == _ft_unit then return _ft_hp end return 100 end,
    get_friendly_target_entry = function()
        if not _ft_present or _ft_hostile then return nil end
        return { unit = _ft_unit, hp_pct = _ft_hp, effective_hp = _ft_hp, is_player = true }
    end,
    import_helpers = function()
        local function tc(...) _last_cast = { args = {...} }; return true end
        local function se(...) return true end
        return tc, se, se, function() return 0 end, function() return 100 end, function() return false end, function() return false end
    end,
    spell_action = function(ids, name) return { spell = ids, name = name } end,
    spell_ready = function() return true end,
    cast_best_heal_rank = function(ranks, target, ctx, label, opts)
        return { spell = { 25314 }, name = "GreaterHeal" }, "GreaterHeal"
    end,
    healing_get_tank = function() return nil end,
    healing_get_lowest_hp = function() return nil end,
    healing_all_above_hp = function() return false end,
    healing_get_cleanse_target = function() return nil end,
    healing_count_below_hp = function() return 0 end,
    has_dispel_type_debuff = function() return false end,
    has_healing_reduction_debuff = function() return false end,
    is_in_raid = function() return false end,
    is_in_party = function() return false end,
    log = function() end,
    rotation_registry = { register = function() end },
}
package.loaded["common/modules/buff_manager"] = { get_all_buffs = function() return {} end }
package.loaded["classes/priest/healing_sylvanas"] = { select_heal = function() return nil end, scan_healing_targets = function() return {}, 0 end }

local result = dofile("EaxRotations/classes/priest/holy_vanilla.lua")
local strategies = result.strategies or result
local function find(name) for i = 1, #strategies do if strategies[i].name == name then return strategies[i] end end error("not found: "..name) end
local ft = find("FriendlyTarget")
assert_true(ft, "FriendlyTarget strategy should exist")

local function ctx(o) local c = { in_combat = true, player_control_locked = false, is_moving = false, mana_pct = 100, hp = 100, settings = {}, me = { _mock = true }, is_pvp = false, target = nil } if o then for k,v in pairs(o) do c[k]=v end end return c end
local function st(o) local s = { lowest = nil, lowest_hp = 100, tank = nil, mana_pct = 100 } if o then for k,v in pairs(o) do s[k]=v end end return s end
local function reset() _ft_present = true; _ft_hostile = false; _ft_hp = 75; _last_cast = nil end

print("--- Priest Holy Vanilla FriendlyTarget (B6) ---")

-- C1: friendly 75%, no emergency -> matches; execute casts GreaterHeal on friendly
reset()
assert_true(ft.matches(ctx(), st({ lowest = { effective_hp = 80, unit = {} } })), "C1: should match")
_last_cast = nil
assert_true(ft.execute(ctx(), st()), "C1: execute returns true")
assert_true(_last_cast ~= nil and _last_cast.args ~= nil, "C1: cast triggered")
assert_eq(_last_cast.args[2], _ft_unit, "C1: targets friendly unit")
print("  [ PASS ] C1: matches + casts GreaterHeal on friendly target")

-- C2: lowest in emergency (25% <= 30) -> no match
reset()
assert_false(ft.matches(ctx(), st({ lowest = { effective_hp = 25, unit = {} } })), "C2: lowest 25% (<=30) -> emergency override")
print("  [ PASS ] C2: emergency override (holy_emergency_hp gate)")

-- C3: opt-out holy_use_friendly_target = false -> no match
reset()
assert_false(ft.matches(ctx({ settings = { holy_use_friendly_target = false } }), st()), "C3: opt-out respected")
print("  [ PASS ] C3: opt-out setting respected")

-- C4: moving -> no match
reset()
assert_false(ft.matches(ctx({ is_moving = true }), st()), "C4: moving -> no match")
print("  [ PASS ] C4: moving-gated")

-- C5: hostile target -> no match
reset(); _ft_hostile = true
assert_false(ft.matches(ctx(), st()), "C5: hostile target does not match")
_ft_hostile = false
print("  [ PASS ] C5: hostile target does not match")

-- C6: strategy ordering — after EmergencyFlashHeal, before UnavailableClassicPriestHealA
local ft_idx, ef_idx, uc_idx
for i = 1, #strategies do
    if strategies[i].name == "FriendlyTarget" then ft_idx = i end
    if strategies[i].name == "EmergencyFlashHeal" then ef_idx = i end
    if strategies[i].name == "UnavailableClassicPriestHealA" then uc_idx = i end
end
assert_true(ft_idx and ef_idx and uc_idx, "C6: expected strategies present")
assert_true(ef_idx < ft_idx, "C6: FriendlyTarget after EmergencyFlashHeal")
assert_true(ft_idx < uc_idx, "C6: FriendlyTarget before UnavailableClassicPriestHealA")
print("  [ PASS ] C6: strategy ordering (after emergency, before routine placeholder)")

print("PASS test_priest_holy_vanilla_friendly_target")
