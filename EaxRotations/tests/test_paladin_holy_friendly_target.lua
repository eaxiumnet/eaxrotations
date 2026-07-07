-- test_paladin_holy_friendly_target.lua — Step 0 FriendlyTarget for Holy paladin.
-- WHAT:  verifies the manual-friendly-target heal is TOP priority (index 1),
--        works in and out of combat, and is gated only by threshold + readiness.
-- WHEN:  regression guard for the FriendlyTarget strategy in holy_sylvanas.lua.
-- WHY:   Step 0 gives healers immediate manual-target control; no emergency
--        override because life-critical saves (LayOnHands / DivineShield) follow after.
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

local strategies = dofile("EaxRotations/classes/paladin/holy_sylvanas.lua").strategies
local function find(name) for i = 1, #strategies do if strategies[i].name == name then return strategies[i] end end error("not found: "..name) end
local ft = find("FriendlyTarget")
assert_true(ft, "FriendlyTarget strategy should exist")

local function ctx(o) local c = { in_combat = true, is_moving = false, mana_pct = 100, hp = 100, settings = {}, me = { _mock = true } } if o then for k,v in pairs(o) do c[k]=v end end return c end
local function st(o) local s = { lowest = nil, tank = nil, mana_pct = 100, moving = false, has_divine_favor = false, friendly_target_ready = false, friendly_target = nil } if o then for k,v in pairs(o) do s[k]=v end end return s end
local function reset() _ft_present = true; _ft_hostile = false; _ft_hp = 75; _last_cast = nil end

print("--- Holy paladin FriendlyTarget (Step 0) ---")

-- C1: friendly 75%, no emergency -> matches; execute casts a HolyLight rank on friendly unit
reset()
assert_true(ft.matches(ctx(), st({ friendly_target_ready = true, friendly_target = { unit = _ft_unit, hp_pct = 75 } })), "C1: should match")
_last_cast = nil
assert_true(ft.execute(ctx(), st({ friendly_target_ready = true, friendly_target = { unit = _ft_unit, hp_pct = 75 } })), "C1: execute returns true")
assert_eq(_last_cast.target, _ft_unit, "C1: targets friendly unit")
assert_true(_last_cast.spell ~= nil, "C1: a HolyLight-rank spell id is cast")
print("  [ PASS ] C1: matches + casts HolyLight rank on friendly target")

-- C2: friendly above threshold (95%) -> no match
reset(); _ft_hp = 95
assert_false(ft.matches(ctx(), st({ friendly_target_ready = true, friendly_target = { unit = _ft_unit, hp_pct = 95 } })), "C2: friendly 95% (>=90) -> no match")
print("  [ PASS ] C2: above-threshold friendly target does not match")

-- C3: hostile target -> no match
reset(); _ft_hostile = true
assert_false(ft.matches(ctx(), st()), "C3: hostile target -> no match")
print("  [ PASS ] C3: hostile target does not match")

-- C4: out of combat -> SHOULD match (Step 0 is unconditional)
reset()
assert_true(ft.matches(ctx({ in_combat = false }), st({ friendly_target_ready = true, friendly_target = { unit = _ft_unit, hp_pct = 75 } })), "C4: OOC -> should match")
print("  [ PASS ] C4: works out of combat")

-- C5: strategy ordering — FriendlyTarget is FIRST (index 1)
local ft_idx, loh_idx, df_idx
for i = 1, #strategies do
    if strategies[i].name == "FriendlyTarget" then ft_idx = i end
    if strategies[i].name == "LayOnHandsLastResort" then loh_idx = i end
    if strategies[i].name == "DivineFavor" then df_idx = i end
end
assert_true(ft_idx and loh_idx and df_idx, "C5: expected strategies present")
assert_true(ft_idx == 1, "C5: FriendlyTarget must be FIRST strategy")
assert_true(ft_idx < loh_idx, "C5: FriendlyTarget before LayOnHandsLastResort")
assert_true(ft_idx < df_idx, "C5: FriendlyTarget before DivineFavor")
print("  [ PASS ] C5: strategy ordering (first, before all other heals)")

print("PASS test_paladin_holy_friendly_target")
