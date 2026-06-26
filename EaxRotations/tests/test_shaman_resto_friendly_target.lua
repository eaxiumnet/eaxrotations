-- test_shaman_resto_friendly_target.lua — Step 0 FriendlyTarget for Resto shaman.
-- WHAT:  verifies the manual-friendly-target heal is TOP priority (index 1),
--        works in and out of combat, and is gated only by threshold + readiness.
-- WHEN:  regression guard for the FriendlyTarget strategy in restoration_sylvanas.lua.
-- WHY:   Step 0 gives healers immediate manual-target control; no emergency
--        override because life-critical saves (NaturesSwiftness / ManaTide) follow after.
-- SAFETY: bypasses build_state by passing crafted state; mocks NS minimally.

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
    ShamanSpells = { HealingWave = 25416, LesserHealingWave = 25418, ChainHeal = 25423, EarthShield = 32593, Bloodlust = 2825, NaturesSwiftness = 17116 },
    CLASS_ID = { SHAMAN = 7 },
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
    healing_all_above_hp = function() return false end,
    healing_get_cleanse_target = function() return nil end,
    healing_count_below_hp = function() return 0 end,
    has_dispel_type_debuff = function() return false end,
    has_healing_reduction_debuff = function() return false end,
    is_in_raid = function() return false end,
    is_in_party = function() return false end,
    game_time_ms = function() return 0 end,
    log = function() end,
    rotation_registry = { register = function() end },
}
package.loaded["classes/shaman/healing_sylvanas"] = { select_heal = function() return nil end, scan_healing_targets = function() return {}, 0 end }

local result = dofile("EaxRotations/classes/shaman/restoration_sylvanas.lua")
local strategies = result.strategies or result
local function find(name) for i = 1, #strategies do if strategies[i].name == name then return strategies[i] end end error("not found: "..name) end
local ft = find("FriendlyTarget")
assert_true(ft, "FriendlyTarget strategy should exist")

local function ctx(o) local c = { in_combat = true, is_moving = false, mana_pct = 100, hp = 100, settings = {}, me = { _mock = true }, is_pvp = false, target = nil } if o then for k,v in pairs(o) do c[k]=v end end return c end
local function st(o) local s = { lowest = nil, tank = nil, mana_pct = 100, healing_wave_ready = true, lesser_healing_wave_ready = true, chain_heal_ready = false, healing_way_stacks = 0, friendly_target_ready = false, friendly_target = nil } if o then for k,v in pairs(o) do s[k]=v end end return s end
local function reset() _ft_present = true; _ft_hostile = false; _ft_hp = 75; _last_cast = nil end

print("--- Resto shaman FriendlyTarget (Step 0) ---")

-- C1: friendly 75%, no emergency -> matches; execute casts HealingWave on friendly unit
reset()
assert_true(ft.matches(ctx(), st({ friendly_target_ready = true, friendly_target = { unit = _ft_unit, hp_pct = 75 } })), "C1: should match")
_last_cast = nil
assert_true(ft.execute(ctx(), st({ friendly_target_ready = true, friendly_target = { unit = _ft_unit, hp_pct = 75 } })), "C1: execute returns true")
assert_eq(_last_cast.target, _ft_unit, "C1: targets friendly unit")
assert_true(_last_cast.spell ~= nil, "C1: a HealingWave spell is cast")
print("  [ PASS ] C1: matches + casts HealingWave on friendly target")

-- C2: healing_wave_ready false -> no match
reset()
assert_false(ft.matches(ctx(), st({ healing_wave_ready = false, friendly_target_ready = true, friendly_target = { unit = _ft_unit, hp_pct = 75 } })), "C2: HW not ready -> no match")
print("  [ PASS ] C2: healing_wave_ready gate respected")

-- C3: moving -> no match (HealingWave is a cast)
reset()
assert_false(ft.matches(ctx({ is_moving = true }), st({ friendly_target_ready = true, friendly_target = { unit = _ft_unit, hp_pct = 75 } })), "C3: moving -> no match")
print("  [ PASS ] C3: moving-gated")

-- C4: hostile target -> no match
reset(); _ft_hostile = true
assert_false(ft.matches(ctx(), st()), "C4: hostile target -> no match")
print("  [ PASS ] C4: hostile target does not match")

-- C5: out of combat -> SHOULD match (Step 0 is unconditional)
reset()
assert_true(ft.matches(ctx({ in_combat = false }), st({ friendly_target_ready = true, friendly_target = { unit = _ft_unit, hp_pct = 75 } })), "C5: OOC -> should match")
print("  [ PASS ] C5: works out of combat")

-- C6: strategy ordering — FriendlyTarget is FIRST (index 1)
local ft_idx, es_idx, ns_idx
for i = 1, #strategies do
    if strategies[i].name == "FriendlyTarget" then ft_idx = i end
    if strategies[i].name == "EarthShieldTank" then es_idx = i end
    if strategies[i].name == "NaturesSwiftness" then ns_idx = i end
end
assert_true(ft_idx and es_idx and ns_idx, "C6: expected strategies present")
assert_true(ft_idx == 1, "C6: FriendlyTarget must be FIRST strategy")
assert_true(ft_idx < es_idx, "C6: FriendlyTarget before EarthShieldTank")
assert_true(ft_idx < ns_idx, "C6: FriendlyTarget before NaturesSwiftness")
print("  [ PASS ] C6: strategy ordering (first, before all other heals)")

print("PASS test_shaman_resto_friendly_target")
