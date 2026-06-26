-- test_discipline_friendly_target.lua — Step 0 FriendlyTarget for Discipline priest.
-- WHAT:  verifies the manual-friendly-target heal is TOP priority (index 1),
--        works in and out of combat, and is gated only by threshold + readiness.
-- WHEN:  regression guard for the FriendlyTarget strategy in discipline_sylvanas.lua.
-- WHY:   Step 0 gives healers immediate manual-target control; no emergency
--        override because life-critical saves (PW:S / FlashHeal) follow after.
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

local function stub() return function() return true end end
_G.EaxRotations = {
    PriestSpells = { GreaterHeal = 2060, FlashHeal = 2061, PowerWordShield = 17, Renew = 139, PrayerofMending = 33076, CircleofHealing = 34861, BindingHeal = 32595 },
    PLAYER_UNIT = { _mock = true },
    GetPlayer = function() return { get_class = function() return 5 end, is_moving = function() return false end, mana_pct = function() return 100 end } end,
    GetTarget = function() return _ft_present and _ft_unit or nil end,
    is_hostile_unit = function() return _ft_hostile end,
    unit_alive = function(u) return u ~= nil end,
    unit_health_pct = function(u) if u == _ft_unit then return _ft_hp end return 100 end,
    get_friendly_target_entry = function()
        if not _ft_present or _ft_hostile then return nil end
        return { unit = _ft_unit, hp_pct = _ft_hp, effective_hp = _ft_hp, is_player = true }
    end,
    gate_overheal = function() return false end,
    GetEnemiesInRange = function() return {} end,
    try_cast = function(spell, target, tag, opts) _last_cast = { spell = spell, target = target, tag = tag }; return true end,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    has_player_buff = function() return false end,
    debuff_remains = function() return 0 end,
    broken_api_throttled = function() return false end,
    log = function() end, log_warning = function() end,
    rotation_registry = { register = function() end },
}

package.loaded["classes/priest/healing_sylvanas"] = { scan_healing_targets = function() return {}, 0 end, count_subgroup_below_hp = function() return 0 end }
package.loaded["common/enums"] = { class_id = { PRIEST = 5 } }
package.loaded["shared/preemptive_heal_sylvanas"] = { DEFAULT_THRESHOLD = 75, match = function() return false end, execute = function() return false end }

local strategies = dofile("EaxRotations/classes/priest/discipline_sylvanas.lua")
local function find(name) for i = 1, #strategies do if strategies[i].name == name then return strategies[i] end end error("not found: "..name) end
local ft = find("FriendlyTarget")
assert_true(ft, "FriendlyTarget strategy should exist")

local function ctx(o) local c = { in_combat = true, is_moving = false, mana_pct = 100, hp = 100, settings = {}, me = { _mock = true }, target = nil } if o then for k,v in pairs(o) do c[k]=v end end return c end
local function st(o) local s = { lowest = nil, lowest_hp = 100, tank = nil, tank_hp = 100, greater_heal_ready = true, mana_pct = 100, friendly_target_ready = false, friendly_target = nil } if o then for k,v in pairs(o) do s[k]=v end end return s end
local function reset() _ft_present = true; _ft_hostile = false; _ft_hp = 75; _last_cast = nil end

print("--- Discipline priest FriendlyTarget (Step 0) ---")

-- C1: friendly 75%, no emergency -> matches; execute casts GreaterHeal (rank by mana)
reset()
assert_true(ft.matches(ctx(), st({ friendly_target_ready = true, friendly_target = { unit = _ft_unit, hp_pct = 75 } })), "C1: should match")
_last_cast = nil
assert_true(ft.execute(ctx({ mana_pct = 100 }), st({ mana_pct = 100, friendly_target_ready = true, friendly_target = { unit = _ft_unit, hp_pct = 75 } })), "C1: execute returns true")
assert_eq(_last_cast.target, _ft_unit, "C1: targets friendly unit")
assert_true(_last_cast.spell ~= nil, "C1: a GreaterHeal-rank spell id is cast")
print("  [ PASS ] C1: matches + casts GreaterHeal rank on friendly target")

-- C2: greater_heal_ready false -> no match (readiness gate)
reset()
assert_false(ft.matches(ctx(), st({ greater_heal_ready = false, friendly_target_ready = true, friendly_target = { unit = _ft_unit, hp_pct = 75 } })), "C2: GH not ready -> no match")
print("  [ PASS ] C2: greater_heal_ready gate respected")

-- C3: low mana (<=15) -> execute picks GREATER_HEAL_EFFICIENT (still casts; rank differs)
reset()
ft.execute(ctx({ mana_pct = 10 }), st({ mana_pct = 10, friendly_target_ready = true, friendly_target = { unit = _ft_unit, hp_pct = 75 } }))
assert_eq(_last_cast.target, _ft_unit, "C3: low-mana execute still targets friendly unit")
print("  [ PASS ] C3: low-mana rank selection still targets friendly unit")

-- C4: hostile target -> friendly_target_ready = false -> no match
reset(); _ft_hostile = true
assert_false(ft.matches(ctx(), st()), "C4: hostile target -> no match")
print("  [ PASS ] C4: hostile target does not match")

-- C5: out of combat -> SHOULD match (Step 0 is unconditional)
reset(); _ft_hp = 75
assert_true(ft.matches(ctx({ in_combat = false }), st({ friendly_target_ready = true, friendly_target = { unit = _ft_unit, hp_pct = 75 } })), "C5: OOC -> should match")
print("  [ PASS ] C5: works out of combat")

-- C6: strategy ordering — FriendlyTarget is FIRST (index 1)
local ft_idx, pws_idx
for i = 1, #strategies do
    if strategies[i].name == "FriendlyTarget" then ft_idx = i end
    if strategies[i].name == "PowerWordShieldTank" then pws_idx = i end
end
assert_true(ft_idx and pws_idx, "C6: expected strategies present")
assert_true(ft_idx == 1, "C6: FriendlyTarget must be FIRST strategy")
assert_true(ft_idx < pws_idx, "C6: FriendlyTarget before PowerWordShieldTank")
print("  [ PASS ] C6: strategy ordering (first, before all other heals)")

print("PASS test_discipline_friendly_target")
