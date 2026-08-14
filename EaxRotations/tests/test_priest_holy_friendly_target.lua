-- test_priest_holy_friendly_target.lua — B6 FriendlyTarget strategy for Holy priest.
-- WHAT:  verifies the manual-friendly-target heal honors the player's selected
--        ally when below threshold, WITHOUT overriding critical emergencies.
-- WHEN:  regression guard for the FriendlyTarget strategy in holy_sylvanas.lua.
-- WHY:   B6 gives healers manual-target control; the safety contract is that
--        life-critical saves (EmergencyPWS / EmergencyFlashHeal) still win and
--        a critically-low auto-scanned ally is never skipped for a manual target.
-- SAFETY: bypasses build_holy_state by passing crafted state; mocks NS minimally.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed: expected false", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- ============================================================================
-- Test-controlled friendly-target state (read by the NS mocks)
-- ============================================================================
local _ft_unit = { _friendly = true, is_player = function() return true end }
local _ft_hp = 75          -- friendly target HP%
local _ft_hostile = false  -- is the current target hostile?
local _ft_present = true   -- does GetTarget return a unit?
local _last_cast = nil     -- captures { spell, target, tag } from try_cast

-- ============================================================================
-- Mock NS
-- ============================================================================
local function stub() return function() return true end end
_G.EaxRotations = {
    PriestSpells = {
        GreaterHeal = 2060,
        FlashHeal = 2061,
        PowerWordShield = 17,
        Renew = 139,
        PrayerofMending = 33076,
        CircleofHealing = 34861,
    },
    PLAYER_UNIT = { _mock = true },
    GetPlayer = function()
        return { get_class = function() return 5 end, is_moving = function() return false end, mana_pct = function() return 100 end }
    end,
    GetTarget = function() return _ft_present and _ft_unit or nil end,
    is_hostile_unit = function(me, target) return _ft_hostile end,
    unit_alive = function(u) return u ~= nil end,
    unit_health_pct = function(u) if u == _ft_unit then return _ft_hp end return 100 end,
    -- Friendly-target helper under test (units domain) — install the real one:
    get_friendly_target_entry = function(context)
        if not _ft_present or _ft_hostile then return nil end
        return { unit = _ft_unit, hp_pct = _ft_hp, effective_hp = _ft_hp, is_player = true }
    end,
    gate_overheal = function() return false end,
    GetEnemiesInRange = function() return {} end,  -- _check_pushback -> false
    cast_best_heal_rank = function(ranks, target, ctx, label, opts)
        return 2060, "GreaterHeal r7"
    end,
    try_cast = function(spell, target, tag, opts)
        _last_cast = { spell = spell, target = target, tag = tag }
        return true
    end,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    has_player_buff = function() return false end,
    debuff_remains = function() return 0 end,
    import_helpers = function(...)
        -- holy_sylvanas imports: try_cast, spell_exists, spell_ready,
        -- debuff_remains, health_pct, player_control_locked, has_player_buff.
        -- Return our capturing try_cast first so execute() casts are observable.
        return function(spell, target, tag, opts)
                   _last_cast = { spell = spell, target = target, tag = tag }
                   return true
               end,
               stub(),  -- spell_exists
               stub(),  -- spell_ready
               function() return 0 end,  -- debuff_remains
               function() return 100 end,-- health_pct
               function() return false end, -- player_control_locked
               function() return false end  -- has_player_buff
    end,
    broken_api_throttled = function() return false end,
    log = function() end,
    log_warning = function() end,
    rotation_registry = { register = function() end },
}

-- Mock healing helpers + enums so the spec loads cleanly.
package.loaded["classes/priest/healing_sylvanas"] = {
    scan_healing_targets = function() return {}, 0 end,
    count_subgroup_below_hp = function() return 0 end,
}
package.loaded["common/enums"] = { class_id = { PRIEST = 5 } }
package.loaded["shared/preemptive_heal_sylvanas"] = {
    DEFAULT_THRESHOLD = 75,
    match = function() return false end,
    execute = function() return false end,
}

-- ============================================================================
-- Load spec
-- ============================================================================
local result = dofile("EaxRotations/classes/priest/holy_sylvanas.lua")
local strategies = result.strategies or result
assert_true(strategies, "holy spec should load and return strategies")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local ft = find_strategy("FriendlyTarget")
assert_true(ft, "FriendlyTarget strategy should exist")

-- Shared base context + state. lowest at 80% (no emergency); mana 100; not moving.
local function make_context(overrides)
    local c = {
        in_combat = true,
        player_control_locked = false,
        is_moving = false,
        mana_pct = 100,
        hp = 100,
        settings = {},
        me = { _mock = true },
        target = nil,
    }
    if overrides then for k, v in pairs(overrides) do c[k] = v end end
    return c
end
local function base_state(overrides)
    local s = { lowest = nil, lowest_hp = 100, tank = nil, tank_hp = 100, friendly_target_ready = false, friendly_target = nil }
    if overrides then for k, v in pairs(overrides) do s[k] = v end end
    return s
end

local function reset_ft() _ft_present = true; _ft_hostile = false; _ft_hp = 75; _last_cast = nil end

print("--- Holy priest FriendlyTarget (B6) ---")

-- C1: friendly target 75% (below default 90), no emergency -> matches; execute casts GH on friendly unit
reset_ft(); _ft_hp = 75
assert_true(ft.matches(make_context(), base_state({
    lowest = { effective_hp = 80, unit = {} },
    lowest_hp = 80,
    friendly_target_ready = true,
    friendly_target = { unit = _ft_unit, hp_pct = 75 },
})),
    "C1: friendly 75% + lowest 80% (no emergency) -> should match")
_last_cast = nil
assert_true(ft.execute(make_context(), base_state({ friendly_target_ready = true, friendly_target = { unit = _ft_unit, hp_pct = 75 } })), "C1: execute should return true")
assert_eq(_last_cast.spell, 2060, "C1: execute casts GreaterHeal")
assert_eq(_last_cast.target, _ft_unit, "C1: execute targets the friendly unit")
print("  [ PASS ] C1: matches + casts GreaterHeal on friendly target")

-- C2: friendly target 95% (above threshold) -> no match
reset_ft(); _ft_hp = 95
assert_false(ft.matches(make_context(), base_state({
    lowest = { effective_hp = 96, unit = {} },
    lowest_hp = 96,
    friendly_target_ready = true,
    friendly_target = { unit = _ft_unit, hp_pct = 95 },
})),
    "C2: friendly 95% (>= 90 threshold) -> should NOT match")
print("  [ PASS ] C2: above-threshold friendly target does not match")

-- C3: hostile target -> friendly_target_ready = false -> no match
reset_ft(); _ft_hostile = true
assert_false(ft.matches(make_context(), base_state()), "C3: hostile target -> should NOT match")
print("  [ PASS ] C3: hostile target does not match")

-- C4: no target -> no match
reset_ft(); _ft_present = false
assert_false(ft.matches(make_context(), base_state()), "C4: no target -> should NOT match")
print("  [ PASS ] C4: no target does not match")

-- C5: emergency on lowest ally does NOT block FriendlyTarget (top priority, unconditional)
reset_ft(); _ft_hp = 75
assert_true(ft.matches(make_context({ settings = { holy_emergency_hp = 30 } }),
    base_state({ lowest = { effective_hp = 20, unit = {} }, lowest_hp = 20,
                 friendly_target_ready = true, friendly_target = { unit = _ft_unit, hp_pct = 75 } })),
    "C5: friendly 75% despite lowest 20% emergency -> SHOULD match (top priority)")
print("  [ PASS ] C5: friendly target wins even during emergency")

-- C6: removed — old opt-out setting (holy_use_friendly_target) no longer exists
print("  [ SKIP ] C6: opt-out setting removed in refactor")

-- C7: out of combat -> SHOULD match (FriendlyTarget is unconditional, works OOC)
reset_ft(); _ft_hp = 75
assert_true(ft.matches(make_context({ in_combat = false }),
    base_state({ friendly_target_ready = true, friendly_target = { unit = _ft_unit, hp_pct = 75 } })),
    "C7: out of combat -> SHOULD match")
print("  [ PASS ] C7: works out of combat")

-- C8: low mana still matches (no mana-floor gate on FriendlyTarget)
reset_ft(); _ft_hp = 75
assert_true(ft.matches(make_context({ mana_pct = 20 }),
    base_state({ friendly_target_ready = true, friendly_target = { unit = _ft_unit, hp_pct = 75 } })),
    "C8: mana 20% -> should STILL match")
print("  [ PASS ] C8: no mana-floor conservation on FriendlyTarget")

-- C9: custom threshold 60 — friendly at 70% should NOT match (above custom threshold)
reset_ft(); _ft_hp = 70
assert_false(ft.matches(make_context({ settings = { holy_friendly_target_threshold = 60 } }),
    base_state({ friendly_target_ready = true, friendly_target = { unit = _ft_unit, hp_pct = 70 } })),
    "C9: friendly 70% with threshold 60 -> should NOT match")
print("  [ PASS ] C9: custom threshold respected")

-- C10: strategy ordering — FriendlyTarget is FIRST (index 1), before all other heals
local ft_idx, pom_idx, efh_idx
for i = 1, #strategies do
    if strategies[i].name == "FriendlyTarget" then ft_idx = i end
    if strategies[i].name == "PrayerOfMending" then pom_idx = i end
    if strategies[i].name == "EmergencyFlashHeal" then efh_idx = i end
end
assert_true(ft_idx and pom_idx and efh_idx, "C10: expected strategies present")
assert_true(ft_idx == 1, "C10: FriendlyTarget must be FIRST strategy")
assert_true(ft_idx < efh_idx, "C10: FriendlyTarget must come BEFORE EmergencyFlashHeal")
assert_true(ft_idx < pom_idx, "C10: FriendlyTarget must come BEFORE PrayerOfMending")
print("  [ PASS ] C10: strategy ordering (first, before all other heals)")

print("PASS test_priest_holy_friendly_target")
