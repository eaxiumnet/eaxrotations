-- test_paladin_holy_friendly_target.lua — B6 FriendlyTarget for Holy paladin.
-- Focused on paladin-specific bits: choose_holy_light_rank rank selection,
-- the hp<=55 emergency-override gate, and holy_ settings. Shared
-- NS.get_friendly_target_entry semantics covered by test_priest_holy_friendly_target.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

local _ft_unit = { _friendly = true, is_player = function() return true end }
local _ft_hp = 75
local _ft_hostile = false
local _ft_present = true
local _last_cast = nil

_G.EaxRotations = {
    PaladinSpells = { DivineFavor = 20216, HolyShock = 20473, FlashOfLight = 19750, HolyLight = 635 },
    PLAYER_UNIT = { _mock = true },
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
    gate_overheal = function() return false end,
    try_cast = function(spell, target, reason, opts) _last_cast = { spell = spell, target = target, reason = reason }; return true end,
    healing_get_lowest_hp = function() return nil end,
    healing_get_tank = function() return nil end,
    log = function() end,
    rotation_registry = { register = function() end },
}
package.loaded["classes/paladin/healing_sylvanas"] = { scan_healing_targets = function() return {}, 0 end, select_heal = function() return { spell = 19750, label = "FlashOfLight" } end }

local strategies = dofile("EaxRotations/classes/paladin/holy_sylvanas.lua")
local function find(name) for i = 1, #strategies do if strategies[i].name == name then return strategies[i] end end error("not found: "..name) end
local ft = find("FriendlyTarget")
assert_true(ft, "FriendlyTarget strategy should exist")

local function ctx(o) local c = { in_combat = true, is_moving = false, mana_pct = 100, hp = 100, settings = {}, me = { _mock = true } } if o then for k,v in pairs(o) do c[k]=v end end return c end
local function st(o) local s = { lowest = nil, tank = nil, mana_pct = 100, moving = false, has_divine_favor = false } if o then for k,v in pairs(o) do s[k]=v end end return s end
local function reset() _ft_present = true; _ft_hostile = false; _ft_hp = 75; _last_cast = nil end

print("--- Holy paladin FriendlyTarget (B6) ---")

-- C1: friendly 75%, no emergency -> matches; execute casts a HolyLight rank on friendly unit
reset()
assert_true(ft.matches(ctx(), st({ lowest = { effective_hp = 80, unit = {} } })), "C1: should match")
_last_cast = nil
assert_true(ft.execute(ctx(), st()), "C1: execute returns true")
assert_eq(_last_cast.target, _ft_unit, "C1: targets friendly unit")
assert_true(_last_cast.spell ~= nil, "C1: a HolyLight-rank spell id is cast")
print("  [ PASS ] C1: matches + casts HolyLight rank on friendly target")

-- C2: lowest in emergency (50% <= 55) -> emergency override -> no match
reset()
assert_false(ft.matches(ctx(), st({ lowest = { effective_hp = 50, unit = {} } })), "C2: lowest 50% (<=55) -> emergency override, no match")
print("  [ PASS ] C2: emergency override (hp<=55 gate)")

-- C3: friendly above threshold (95%) -> no match
reset(); _ft_hp = 95
assert_false(ft.matches(ctx(), st({ lowest = { effective_hp = 96, unit = {} } })), "C3: friendly 95% (>=90) -> no match")
print("  [ PASS ] C3: above-threshold friendly target does not match")

-- C4: opt-out holy_use_friendly_target = false -> no match
reset()
assert_false(ft.matches(ctx({ settings = { holy_use_friendly_target = false } }), st()), "C4: opt-out respected")
print("  [ PASS ] C4: opt-out setting respected")

-- C5: hostile target -> no match
reset(); _ft_hostile = true
assert_false(ft.matches(ctx(), st()), "C5: hostile target -> no match")
print("  [ PASS ] C5: hostile target does not match")

-- C6: out of combat -> no match
reset()
assert_false(ft.matches(ctx({ in_combat = false }), st()), "C6: OOC -> no match")
print("  [ PASS ] C6: combat-gated")

-- C7: strategy ordering — after DivineFavorHolyLightFollowup, before BlessingOfSacrificeTank
local ft_idx, df_idx, bos_idx
for i = 1, #strategies do
    if strategies[i].name == "FriendlyTarget" then ft_idx = i end
    if strategies[i].name == "DivineFavorHolyLightFollowup" then df_idx = i end
    if strategies[i].name == "BlessingOfSacrificeTank" then bos_idx = i end
end
assert_true(ft_idx and df_idx and bos_idx, "C7: expected strategies present")
assert_true(df_idx < ft_idx, "C7: FriendlyTarget after DivineFavorHolyLightFollowup")
assert_true(ft_idx < bos_idx, "C7: FriendlyTarget before BlessingOfSacrificeTank")
print("  [ PASS ] C7: strategy ordering (after emergency direct heals)")

print("PASS test_paladin_holy_friendly_target")
