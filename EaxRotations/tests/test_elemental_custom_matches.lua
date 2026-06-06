-- unit tests for elemental_sylvanas custom matches functions.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Mock NS namespace
local spell_ready_calls = {}
_G.EaxRotations = {
    ShamanSpells = {
        LightningShield = 25472,
        WaterShield = 32594,
        GhostWolf = 2645,
        TremorTotem = 8143,
        EarthbindTotem = 2484,
        ManaTideTotem = 16190,
        ElementalMastery = 16166,
        NaturesSwiftness = 16188,
        Bloodlust = 2825,
        ChainLightning = 25442,
        LightningBolt = 25449,
        FlameShock = 25457,
        ChainHeal = 25423,
        EarthShock = 25454,
        FrostShock = 25464,
        FireNovaTotem = 25547,
        MagmaTotem = 25552,
        TotemicCall = 16191,
        FlametongueWeapon = 25489,
        WindfuryWeapon = 25505,
        RockbiterWeapon = 25485,
        HealingWave = 25396,
        TotemOfWrath = 30706,
        WrathOfAirTotem = 3738,
        ManaSpringTotem = 25570,
    },
    has_player_buff = function(buff_list) return false end,
    buff_remains = function(me, ids) return 0 end,
    debuff_remains = function(target, ids) return 0 end,
    spell_ready = function(spell, target, opts)
        spell_ready_calls[#spell_ready_calls + 1] = { spell = spell, target = target, opts = opts }
        return true
    end,
    is_spell_learned = function(id) return true end,
    broken_api_throttled = function(spell, seconds) return false end,
    game_time_ms = function() return 100000 end,
    log = function() end,
    should_refresh_dot = function(remains, window, ttd, dur) return true end,
    rotation_registry = { register = function() end },
}

local strategies = dofile("EaxRotations/classes/shaman/elemental_sylvanas.lua")
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
-- ManaEmergencyWand: gates ALL strategies when mana in emergency state
-- ============================================================================

local emergency = find_strategy("ManaEmergencyWand")

-- Emergency mana, in combat -> should match
assert_true(emergency.matches({ in_combat = true, mana_pct = 3 }, {
    mana_emergency = true,
}), "ManaEmergencyWand should match in combat with emergency mana")

-- Not in combat, emergency mana -> should NOT match
assert_false(emergency.matches({ in_combat = false, mana_pct = 3 }, {
    mana_emergency = true,
}), "ManaEmergencyWand should not match when OOC")

-- In combat, mana NOT emergency -> should NOT match
assert_false(emergency.matches({ in_combat = true, mana_pct = 50 }, {
    mana_emergency = false,
}), "ManaEmergencyWand should not match when mana is not emergency")

-- ============================================================================
-- LightningShield: not already up, not emergency mana
-- ============================================================================

local lightning_shield = find_strategy("LightningShield")

-- Already up -> should NOT match
spell_ready_calls = {}
assert_false(lightning_shield.matches({
    settings = { elemental_lightning_shield = true },
}, {
    lightning_shield_up = true, mana_emergency = false,
    now_ms = 200000,
}), "LightningShield should not match when already up")

-- Emergency mana -> should NOT match
spell_ready_calls = {}
assert_false(lightning_shield.matches({
    settings = { elemental_lightning_shield = true },
}, {
    lightning_shield_up = false, mana_emergency = true,
    now_ms = 200000,
}), "LightningShield should not match in emergency mana")

-- Setting disabled -> should NOT match
spell_ready_calls = {}
assert_false(lightning_shield.matches({
    settings = { elemental_lightning_shield = false },
}, {
    lightning_shield_up = false, mana_emergency = false,
    now_ms = 200000,
}), "LightningShield should not match when setting is false")

-- Not up, normal mana, setting enabled -> should match
spell_ready_calls = {}
assert_true(lightning_shield.matches({
    settings = { elemental_lightning_shield = true },
}, {
    lightning_shield_up = false, mana_emergency = false,
    now_ms = 200000,
}), "LightningShield should match when not up and mana is fine")

-- ============================================================================
-- ChainLightning: 3+ targets, not moving, not conserve/emergency mana
-- ============================================================================

local chain_lightning = find_strategy("ChainLightning")

-- Moving -> should NOT match
spell_ready_calls = {}
assert_false(chain_lightning.matches({
    is_moving = true, target_count = 5,
    settings = { elemental_cl_min_targets = 3 },
}, {
    mana_emergency = false, mana_conserve = false, target_count = 5,
}), "ChainLightning should not match when moving")

-- Emergency mana -> should NOT match
spell_ready_calls = {}
assert_false(chain_lightning.matches({
    is_moving = false, target_count = 5,
    settings = { elemental_cl_min_targets = 3 },
}, {
    mana_emergency = true, mana_conserve = false, target_count = 5,
}), "ChainLightning should not match in emergency mana")

-- Conserve mana -> should NOT match
spell_ready_calls = {}
assert_false(chain_lightning.matches({
    is_moving = false, target_count = 5,
    settings = { elemental_cl_min_targets = 3 },
}, {
    mana_emergency = false, mana_conserve = true, target_count = 5,
}), "ChainLightning should not match in conserve mana")

-- <3 targets -> should NOT match
spell_ready_calls = {}
assert_false(chain_lightning.matches({
    is_moving = false, target_count = 2,
    settings = { elemental_cl_min_targets = 3 },
}, {
    mana_emergency = false, mana_conserve = false, target_count = 2,
}), "ChainLightning should not match with <3 targets")

-- 3+ targets, not moving, normal mana -> should match
spell_ready_calls = {}
assert_true(chain_lightning.matches({
    is_moving = false, target_count = 4,
    settings = { elemental_cl_min_targets = 3 },
}, {
    mana_emergency = false, mana_conserve = false, target_count = 4,
}), "ChainLightning should match with 3+ targets and normal mana")

-- CC-safe false -> should NOT match
spell_ready_calls = {}
assert_false(chain_lightning.matches({
    is_moving = false, target_count = 4, cc_safe = false,
    settings = { elemental_cl_min_targets = 3 },
}, {
    mana_emergency = false, mana_conserve = false, target_count = 4,
}), "ChainLightning should not match when cc-safe is false")

-- ============================================================================
-- LightningBolt: not moving, not emergency mana, threat below 90%
-- ============================================================================

local lightning_bolt = find_strategy("LightningBolt")

-- Moving -> should NOT match
spell_ready_calls = {}
assert_false(lightning_bolt.matches({
    is_moving = true, threat_pct = 50,
}, {
    mana_emergency = false, mana_low = false,
}), "LightningBolt should not match when moving")

-- Emergency mana -> should NOT match
spell_ready_calls = {}
assert_false(lightning_bolt.matches({
    is_moving = false, threat_pct = 50,
}, {
    mana_emergency = true, mana_low = false,
}), "LightningBolt should not match in emergency mana")

-- Threat > 90% -> should NOT match
spell_ready_calls = {}
assert_false(lightning_bolt.matches({
    is_moving = false, threat_pct = 95,
}, {
    mana_emergency = false, mana_low = false,
}), "LightningBolt should not match when threat > 90%")

-- Normal conditions -> should match
spell_ready_calls = {}
assert_true(lightning_bolt.matches({
    is_moving = false, threat_pct = 50,
}, {
    mana_emergency = false, mana_low = false,
}), "LightningBolt should match under normal conditions")

-- ============================================================================
-- FlameShock: refresh within 1s, SP above minimum
-- ============================================================================

local flame_shock = find_strategy("FlameShock")

-- No target -> should NOT match
spell_ready_calls = {}
assert_false(flame_shock.matches({
    target = nil, settings = { elemental_flame_shock_min_sp = 400 },
}, {
    flame_remains = 0.5, spell_damage = 500,
}), "FlameShock should not match without target")

-- Remains > 1s -> should NOT match (don't clip early)
spell_ready_calls = {}
assert_false(flame_shock.matches({
    target = {}, settings = { elemental_flame_shock_min_sp = 400 },
}, {
    flame_remains = 5, spell_damage = 500,
}), "FlameShock should not match when >1s remains")

-- SP below minimum -> should NOT match
spell_ready_calls = {}
assert_false(flame_shock.matches({
    target = {}, settings = { elemental_flame_shock_min_sp = 400 },
}, {
    flame_remains = 0.5, spell_damage = 200,
}), "FlameShock should not match when spell damage < minimum")

-- SP above minimum, within refresh window -> should match
_G.EaxRotations.should_refresh_dot = function(remains, window, ttd, dur) return true end
spell_ready_calls = {}
assert_true(flame_shock.matches({
    target = {}, settings = { elemental_flame_shock_min_sp = 400 },
}, {
    flame_remains = 0.5, spell_damage = 500,
}), "FlameShock should match within refresh window with sufficient SP")

-- ============================================================================
-- EarthShock moving filler: only when moving and interrupt reserve OFF
-- ============================================================================

local earth_shock_moving = find_strategy("EarthShockMoving")

-- Not moving -> should NOT match
spell_ready_calls = {}
assert_false(earth_shock_moving.matches({
    is_moving = false, settings = { elemental_interrupt_reserve = false },
}, {}), "EarthShock moving filler should not match when stationary")

-- Moving with interrupt reserve ON -> should NOT match
spell_ready_calls = {}
assert_false(earth_shock_moving.matches({
    is_moving = true, settings = { elemental_interrupt_reserve = true },
}, {}), "EarthShock moving filler should not match with interrupt reserve on")

-- Moving with interrupt reserve OFF -> should match
spell_ready_calls = {}
assert_true(earth_shock_moving.matches({
    is_moving = true, settings = { elemental_interrupt_reserve = false },
}, {}), "EarthShock moving filler should match when moving with reserve off")

print("PASS test_elemental_custom_matches")
