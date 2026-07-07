-- unit tests for demonology_sylvanas custom matches functions.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Mock NS namespace
local action_calls = {}
_G.EaxRotations = {
    WarlockSpells = {},
    action_matches = function(ctx, act)
        action_calls[#action_calls + 1] = { fn = "action_matches", ctx = ctx, act = act }
        return true
    end,
    is_spell_learned = function(spell_id)
        return true
    end,
    log = function() end,
    rotation_registry = {
        register = function() end,
    },
}

local strategies = dofile("EaxRotations/classes/warlock/demonology_sylvanas.lua").strategies
assert_true(strategies, "strategies table should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then
            return strategies[i]
        end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- Death Coil: only when player HP <= 40
-- ============================================================================

local death_coil = find_strategy("DeathCoil")

-- High HP -> should NOT match
action_calls = {}
local ctx_dc_high = {
    target = {},
    me = {
        get_health_percentage = function() return 60 end,
    },
}
assert_false(death_coil.matches(ctx_dc_high), "DeathCoil should not match when HP > 40")
assert_eq(#action_calls, 0, "action_matches should not be called when HP > 40")

-- Low HP -> should match
action_calls = {}
local ctx_dc_low = {
    target = {},
    me = {
        get_health_percentage = function() return 30 end,
    },
}
assert_true(death_coil.matches(ctx_dc_low), "DeathCoil should match when HP <= 40")

-- No me -> should return false
assert_false(death_coil.matches({ target = {} }), "DeathCoil should not match when me is nil")

-- No target -> should return false
assert_false(death_coil.matches({ me = { get_health_percentage = function() return 30 end } }), "DeathCoil should not match when target is nil")

-- ============================================================================
-- Summon Felguard: only OOC with no pet
-- ============================================================================

local summon_felguard = find_strategy("SummonFelguard")

-- In combat -> should NOT match
action_calls = {}
local ctx_pet_combat = {
    in_combat = true,
    me = {},
}
assert_false(summon_felguard.matches(ctx_pet_combat), "SummonFelguard should not match when in combat")
assert_eq(#action_calls, 0, "action_matches should not be called when in combat")

-- OOC but has pet -> should NOT match
action_calls = {}
local ctx_pet_has = {
    in_combat = false,
    me = {
        has_pet = function() return true end,
    },
}
assert_false(summon_felguard.matches(ctx_pet_has), "SummonFelguard should not match when pet exists")
assert_eq(#action_calls, 0, "action_matches should not be called when pet exists")

-- OOC, no pet -> should match
local ctx_pet_none = {
    in_combat = false,
    me = {
        has_pet = function() return false end,
    },
}
assert_true(summon_felguard.matches(ctx_pet_none), "SummonFelguard should match when OOC and no pet")
-- Note: needs_felguard does not delegate to NS.action_matches (self-contained gate)

-- ============================================================================
-- Health Funnel: only when pet HP < 30
-- ============================================================================

local health_funnel = find_strategy("HealthFunnel")

-- Pet HP high -> should NOT match
action_calls = {}
local ctx_hf_high = {
    me = {
        get_pet = function()
            return {
                is_valid = function() return true end,
                get_health_percentage = function() return 50 end,
            }
        end,
    },
}
assert_false(health_funnel.matches(ctx_hf_high), "HealthFunnel should not match when pet HP >= 30")
assert_eq(#action_calls, 0, "action_matches should not be called when pet HP >= 30")

-- Pet HP low -> should match
local ctx_hf_low = {
    me = {
        get_pet = function()
            return {
                is_valid = function() return true end,
                get_health_percentage = function() return 20 end,
            }
        end,
    },
}
assert_true(health_funnel.matches(ctx_hf_low), "HealthFunnel should match when pet HP < 30")
-- Note: pet_needs_healing does not delegate to NS.action_matches (self-contained gate)

-- No pet -> should NOT match
action_calls = {}
local ctx_hf_none = {
    me = {
        get_pet = function() return nil end,
    },
}
assert_false(health_funnel.matches(ctx_hf_none), "HealthFunnel should not match when no pet")

-- ============================================================================
-- Drain Soul: TBC shard-capture only -- channel as the mob dies (ttd <= window),
-- NOT a sub-25% DPS execute (that is a Wrath mechanic).
-- ============================================================================

local drain_soul = find_strategy("DrainSoul")

-- No ttd known -> should NOT match (can't reliably capture a shard)
assert_false(drain_soul.matches({
    target = {},
}, {
    drain_soul_ready = true,
    target_hp_pct = 20,
}), "DrainSoul should not match when ttd is unknown (even at low HP)")

-- ttd known but mob not dying soon -> should NOT match
assert_false(drain_soul.matches({
    target = {},
    ttd_known = true,
    ttd = 10,
}, {
    drain_soul_ready = true,
    target_hp_pct = 20,
}), "DrainSoul should not match when ttd > capture window")

-- ttd known and mob about to die -> should match (shard capture)
assert_true(drain_soul.matches({
    target = {},
    ttd_known = true,
    ttd = 4,
}, {
    drain_soul_ready = true,
    target_hp_pct = 20,
}), "DrainSoul should match when ttd <= capture window (shard capture)")

-- ttd in window but not ready -> should NOT match
assert_false(drain_soul.matches({
    target = {},
    ttd_known = true,
    ttd = 4,
}, {
    drain_soul_ready = false,
    target_hp_pct = 20,
}), "DrainSoul should not match when not ready")

-- No target -> should NOT match
assert_false(drain_soul.matches({
    ttd_known = true,
    ttd = 4,
}, {
    drain_soul_ready = true,
}), "DrainSoul should not match without target")

print("PASS test_demonology_custom_matches")
