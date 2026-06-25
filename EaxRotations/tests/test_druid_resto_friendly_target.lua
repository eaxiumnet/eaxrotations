-- test_druid_resto_friendly_target.lua — B6 FriendlyTarget for Resto druid.
-- Focused on druid-specific bits: Regrowth + predictive_overheal gate, the
-- resto_emergency_hp override, and resto_ settings. Shared helper semantics
-- covered by test_priest_holy_friendly_target.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

local _ft_unit = { _friendly = true, is_player = function() return true end }
local _ft_hp = 75
local _ft_hostile = false
local _ft_present = true
local _last_cast = nil

_G.core = { time = function() return 0 end, log = function() end, get_game_version = function() return "Tbc" end }
_G.EaxRotations = {
    DruidSpells = { Regrowth = 8936, HealingTouch = 8936, Swiftmend = 18562, Lifebloom = 33763, Rejuvenation = 774, Barkskin = 22812, NaturesSwiftness = 17116 },
    PLAYER_UNIT = { _mock = true },
    GetPlayer = function() return nil end,
    GetTarget = function() return _ft_present and _ft_unit or nil end,
    is_hostile_unit = function() return _ft_hostile end,
    unit_alive = function(u) return u ~= nil end,
    unit_health_pct = function(u) if u == _ft_unit then return _ft_hp end return 100 end,
    get_friendly_target_entry = function()
        if not _ft_present or _ft_hostile then return nil end
        return { unit = _ft_unit, hp_pct = _ft_hp, effective_hp = _ft_hp, is_player = true }
    end,
    spell_action = function(ids, name) return { spell = ids, name = name } end,
    spell_ready = function() return true end,
    has_player_buff = function() return false end,
    debuff_remains = function() return 0 end,
    gate_overheal = function() return false end,
    try_cast = function(spell, target, reason, opts) _last_cast = { spell = spell, target = target, reason = reason }; return true end,
    healing_get_tank = function() return nil end,
    healing_get_lowest_hp = function() return nil end,
    safe_field = function() return nil end,
    same_unit = function(a, b) return a == b end,
    is_in_party = function() return false end,
    is_in_raid = function() return false end,
    log = function() end,
    rotation_registry = { register = function() end },
}
package.loaded["classes/druid/healing_sylvanas"] = { scan_healing_targets = function() return {}, 0 end }

local result = dofile("EaxRotations/classes/druid/resto_sylvanas.lua")
local strategies = result.strategies or result
local function find(name) for i = 1, #strategies do if strategies[i].name == name then return strategies[i] end end error("not found: "..name) end
local ft = find("FriendlyTarget")
assert_true(ft, "FriendlyTarget strategy should exist")

local function ctx(o) local c = { in_combat = true, is_moving = false, mana_pct = 100, hp = 100, settings = {}, me = { _mock = true }, is_pvp = false } if o then for k,v in pairs(o) do c[k]=v end end return c end
local function st(o) local s = { lowest = nil, tank = nil, mana_pct = 100, mana_conserve = false, regrowth_target = nil, ht_target = nil } if o then for k,v in pairs(o) do s[k]=v end end return s end
local function reset() _ft_present = true; _ft_hostile = false; _ft_hp = 75; _last_cast = nil end

print("--- Resto druid FriendlyTarget (B6) ---")

-- C1: friendly 75%, no emergency -> matches; execute casts Regrowth on friendly unit
reset()
assert_true(ft.matches(ctx(), st({ lowest = { effective_hp = 80, unit = {} } })), "C1: should match")
_last_cast = nil
assert_true(ft.execute(ctx(), st()), "C1: execute returns true")
assert_eq(_last_cast.target, _ft_unit, "C1: targets friendly unit")
assert_true(_last_cast.spell ~= nil, "C1: a Regrowth spell is cast")
print("  [ PASS ] C1: matches + casts Regrowth on friendly target")

-- C2: lowest in emergency (30% <= 35) -> emergency override -> no match
reset()
assert_false(ft.matches(ctx(), st({ lowest = { effective_hp = 30, unit = {} } })), "C2: lowest 30% (<=35) -> emergency override")
print("  [ PASS ] C2: emergency override (resto_emergency_hp gate)")

-- C3: moving -> no match (Regrowth is a cast)
reset()
assert_false(ft.matches(ctx({ is_moving = true }), st()), "C3: moving -> no match")
print("  [ PASS ] C3: moving-gated")

-- C4: opt-out resto_use_friendly_target = false -> no match
reset()
assert_false(ft.matches(ctx({ settings = { resto_use_friendly_target = false } }), st()), "C4: opt-out respected")
print("  [ PASS ] C4: opt-out setting respected")

-- C5: hostile target -> no match
reset(); _ft_hostile = true
assert_false(ft.matches(ctx(), st()), "C5: hostile target -> no match")
print("  [ PASS ] C5: hostile target does not match")

-- C6: strategy ordering — after HealingTouchMaxEmergency, before RegrowthSpotHeal
local ft_idx, ht_idx, rg_idx
for i = 1, #strategies do
    if strategies[i].name == "FriendlyTarget" then ft_idx = i end
    if strategies[i].name == "HealingTouchMaxEmergency" then ht_idx = i end
    if strategies[i].name == "RegrowthSpotHeal" then rg_idx = i end
end
assert_true(ft_idx and ht_idx and rg_idx, "C6: expected strategies present")
assert_true(ht_idx < ft_idx, "C6: FriendlyTarget after HealingTouchMaxEmergency")
assert_true(ft_idx < rg_idx, "C6: FriendlyTarget before RegrowthSpotHeal")
print("  [ PASS ] C6: strategy ordering (after emergency, before routine spot heals)")

print("PASS test_druid_resto_friendly_target")
