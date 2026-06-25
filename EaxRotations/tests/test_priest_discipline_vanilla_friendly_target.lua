-- test_priest_discipline_vanilla_friendly_target.lua — B6 FriendlyTarget for vanilla discipline priest.
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
    PriestSpells = { FlashHeal = 25315, GreaterHeal = 25314, PowerWordShield = 25218, Renew = 25222, PrayerOfHealing = 25331, InnerFire = 588, FearWard = 6346, PowerWordFortitude = 25389, DivineSpirit = 25312, PsychicScream = 8122, ShackleUndead = 10955, DispelMagic = 988, PowerInfusion = 10060, InnerFocus = 14751, Smite = 25363, ShadowWordPain = 25368, HolyFire = 25384 },
    CLASS_ID = { PRIEST = 5 },
    PLAYER_UNIT = { _mock = true },
    GetPlayer = function() return { get_class = function() return 5 end } end,
    GetTarget = function() return _ft_present and _ft_unit or nil end,
    GetEnemiesInRange = function() return { { is_casting = function() return true end, can_attack = function() return true end } } end,
    is_hostile_unit = function() return _ft_hostile end,
    unit_alive = function(u) return u ~= nil end,
    unit_health_pct = function(u) if u == _ft_unit then return _ft_hp end return 100 end,
    get_friendly_target_entry = function()
        if not _ft_present or _ft_hostile then return nil end
        return { unit = _ft_unit, hp_pct = _ft_hp, effective_hp = _ft_hp, is_player = true }
    end,
    spell_ready = function() return true end,
    has_player_buff = function() return false end,
    debuff_remains = function() return 0 end,
    gate_overheal = function() return false end,
    try_cast = function(spell, target, reason) _last_cast = { spell = spell, target = target, reason = reason }; return true end,
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
package.loaded["classes/priest/healing_sylvanas"] = { select_heal = function() return nil end, scan_healing_targets = function() return {}, 0 end }

local _registered_strategies
_G.EaxRotations.rotation_registry = { register = function(_, name, strats) _registered_strategies = strats end }

local result = dofile("EaxRotations/classes/priest/discipline_vanilla.lua")
local strategies = _registered_strategies
local function find(name) for i = 1, #strategies do if strategies[i].name == name then return strategies[i] end end error("not found: "..name) end
local ft = find("FriendlyTarget")
assert_true(ft, "FriendlyTarget strategy should exist")

local function ctx(o) local c = { in_combat = true, player_control_locked = false, is_moving = false, mana_pct = 100, hp = 100, settings = {}, me = { _mock = true }, is_pvp = false, target = nil } if o then for k,v in pairs(o) do c[k]=v end end return c end
local function st(o) local s = { lowest = nil, tank = nil, mana_pct = 100, greater_heal_ready = true, flash_heal_ready = true } if o then for k,v in pairs(o) do s[k]=v end end return s end
local function reset() _ft_present = true; _ft_hostile = false; _ft_hp = 75; _last_cast = nil end

print("--- Priest Discipline Vanilla FriendlyTarget (B6) ---")

reset()
assert_true(ft.matches(ctx(), st({ lowest = { effective_hp = 80, unit = {} } })), "C1: should match")
_last_cast = nil
assert_true(ft.execute(ctx(), st()), "C1: execute returns true")
assert_eq(_last_cast.target, _ft_unit, "C1: targets friendly unit")
print("  [ PASS ] C1: matches + casts GreaterHeal on friendly target")

reset()
assert_false(ft.matches(ctx(), st({ lowest = { effective_hp = 40, unit = {} } })), "C2: lowest 40% (<=55) -> emergency override")
print("  [ PASS ] C2: emergency override (discipline_flash_hp gate)")

reset()
assert_false(ft.matches(ctx({ settings = { disc_use_friendly_target = false } }), st()), "C3: opt-out respected")
print("  [ PASS ] C3: opt-out setting respected")

reset()
assert_false(ft.matches(ctx({ is_moving = true }), st()), "C4: moving -> no match")
print("  [ PASS ] C4: moving-gated")

reset(); _ft_hostile = true
assert_false(ft.matches(ctx(), st()), "C5: hostile target does not match")
_ft_hostile = false
print("  [ PASS ] C5: hostile target does not match")

local ft_idx, ef_idx, gh_idx
for i = 1, #strategies do
    if strategies[i].name == "FriendlyTarget" then ft_idx = i end
    if strategies[i].name == "EmergencyFlashHeal" then ef_idx = i end
    if strategies[i].name == "GreaterHeal" then gh_idx = i end
end
assert_true(ft_idx and ef_idx and gh_idx, "C6: expected strategies present")
assert_true(ef_idx < ft_idx, "C6: FriendlyTarget after EmergencyFlashHeal")
assert_true(ft_idx < gh_idx, "C6: FriendlyTarget before GreaterHeal")
print("  [ PASS ] C6: strategy ordering")

print("PASS test_priest_discipline_vanilla_friendly_target")
