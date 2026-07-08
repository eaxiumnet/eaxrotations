-- test_shaman_resto_vanilla_friendly_target.lua -- Restoration Shaman Vanilla-era compatibility friendly target targeting tests.
-- WHAT:  Restoration Shaman Vanilla-era compatibility friendly target targeting tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Verifies Vanilla/Classic-era rotation compatibility and spell availability.
-- SAFETY: Tests only Vanilla spell IDs and mechanics.

-- test_shaman_resto_vanilla_friendly_target.lua — B6 FriendlyTarget for vanilla resto shaman.
package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

local _ft_unit = { _friendly = true, is_player = function() return true end }
local _ft_hp = 75
local _ft_hostile = false
local _ft_present = true
local _last_cast = nil

_G.core = { time = function() return 0 end, log = function() end, get_game_version = function() return "Vanilla" end }
_G.EaxRotations = {
    ShamanSpells = { HealingWave = 25316, LesserHealingWave = 25420, ChainHeal = 25423, NaturesSwiftness = 16188, Purge = 8012, TremorTotem = 8143, GroundingTotem = 8177, ManaTideTotem = 16190 },
    CLASS_ID = { SHAMAN = 7 },
    PLAYER_UNIT = { _mock = true },
    GetPlayer = function() return { get_class = function() return 7 end } end,
    GetTarget = function() return _ft_present and _ft_unit or nil end,
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
    log = function() end,
    rotation_registry = { register = function() end },
}

package.loaded["shared/potion_helper_sylvanas"] = { try_use_potion = function() return false end, MANA_POTION_IDS = {}, HEALTH_POTION_IDS = {} }
package.loaded["classes/shaman/healing_sylvanas"] = { select_heal = function() return nil end, scan_healing_targets = function() return {}, 0 end }

local result = dofile("EaxRotations/classes/shaman/restoration_vanilla.lua")
local strategies = result.strategies or result
local function find(name) for i = 1, #strategies do if strategies[i].name == name then return strategies[i] end end error("not found: "..name) end
local ft = find("FriendlyTarget")
assert_true(ft, "FriendlyTarget strategy should exist")

local function ctx(o) local c = { in_combat = true, is_moving = false, mana_pct = 100, hp = 100, settings = {}, me = { _mock = true }, is_pvp = false, target = nil } if o then for k,v in pairs(o) do c[k]=v end end return c end
local function st(o) local s = { lowest = nil, tank = nil, mana_pct = 100, healing_wave_ready = true, lesser_healing_wave_ready = true, chain_heal_ready = false } if o then for k,v in pairs(o) do s[k]=v end end return s end
local function reset() _ft_present = true; _ft_hostile = false; _ft_hp = 75; _last_cast = nil end

print("--- Shaman Resto Vanilla FriendlyTarget (B6) ---")

reset()
assert_true(ft.matches(ctx(), st({ lowest = { effective_hp = 80, unit = {} } })), "C1: should match")
_last_cast = nil
assert_true(ft.execute(ctx(), st()), "C1: execute returns true")
assert_eq(_last_cast.target, _ft_unit, "C1: targets friendly unit")
print("  [ PASS ] C1: matches + casts HealingWave on friendly target")

reset()
assert_false(ft.matches(ctx(), st({ lowest = { effective_hp = 40, unit = {} } })), "C2: lowest 40% (<=50) -> emergency override")
print("  [ PASS ] C2: emergency override")

reset()
assert_false(ft.matches(ctx({ settings = { restoration_use_friendly_target = false } }), st()), "C3: opt-out respected")
print("  [ PASS ] C3: opt-out setting respected")

reset()
assert_false(ft.matches(ctx({ is_moving = true }), st()), "C4: moving -> no match")
print("  [ PASS ] C4: moving-gated")

reset(); _ft_hostile = true
assert_false(ft.matches(ctx(), st()), "C5: hostile target does not match")
_ft_hostile = false
print("  [ PASS ] C5: hostile target does not match")

local ft_idx, uc_idx, hw_idx
for i = 1, #strategies do
    if strategies[i].name == "FriendlyTarget" then ft_idx = i end
    if strategies[i].name == "UnavailableClassicShamanBurst" then uc_idx = i end
    if strategies[i].name == "HealingWay" then hw_idx = i end
end
assert_true(ft_idx and uc_idx and hw_idx, "C6: expected strategies present")
assert_true(uc_idx < ft_idx, "C6: FriendlyTarget after UnavailableClassicShamanBurst")
assert_true(ft_idx < hw_idx, "C6: FriendlyTarget before HealingWay")
print("  [ PASS ] C6: strategy ordering")

print("PASS test_shaman_resto_vanilla_friendly_target")
