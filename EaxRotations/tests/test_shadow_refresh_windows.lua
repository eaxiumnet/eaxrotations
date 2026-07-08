-- Test: Shadow Priest configurable DoT refresh windows.
-- WHAT:  Verify VT and SW:P match functions respect custom refresh thresholds.
-- WHEN:  loaded as part of run_rotation_tests.lua.
-- WHY:   shadow_sylvanas.lua parameterizes clip thresholds via context.settings.
-- SAFETY: mock environment; no live API calls.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_false
local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

_G.EaxRotations = {
    PriestSpells = {
        ShadowWordPain = 25368, VampiricTouch = 34917, MindBlast = 8092,
        ShadowWordDeath = 32379, Shadowform = 15473, InnerFire = 588,
        InnerFocus = 14751, MindFlay = 15407, PsychicScream = 8122,
        DispelMagic = 528, ShackleUndead = 9484, DevouringPlague = 2944,
        FlashHeal = 2061, PowerWordShield = 17, PowerWordFortitude = 1243,
        VampiricEmbrace = 15286, Shadowfiend = 34433, Berserking = 26297,
        BloodFury = 33697, ArcaneTorrent = 28730, Starshards = 10797,
        HolyNova = 15237,
    },
    action_matches = function() return true end,
    action_execute = function() return true end,
    spell_ready = function(spell, target, opts) return true end,
    spell_exists = function(spell) return true end,
    debuff_remains = function(target, ids) return 0 end,
    debuff_up = function() return false end,
    buff_up = function() return false end,
    log = function() end,
    time_now = function() return 100 end,
    cooldown_remains = function() return 0 end,
    rotation_registry = { register = function() end },
    GetPlayer = function() return {} end,
    GetTarget = function() return nil end,
    GetEnemiesInRange = function() return {} end,
    unit_mana_pct = function() return 80 end,
    unit_health_pct = function() return 100 end,
    get_debuff_stacks = function() return 5 end,
    is_threat_safe = function() return true end,
}

package.loaded["shared/mf_tick_compute_sylvanas"] = {
    compute_channel_state = function() return false, 0 end,
    should_clip_mf = function() return false end,
}
package.loaded["shared/offensive_dispel_sylvanas"] = {}
package.loaded["shared/dot_ttd_gating_sylvanas"] = {
    should_skip_dot = function() return false end,
    should_skip_dot_from_context = function() return false end,
    DOT_DURATIONS = { vampiric_touch = 15, shadow_word_pain = 18 },
}

local result = dofile("EaxRotations/classes/priest/shadow_sylvanas.lua")
local strategies = result.strategies or result
assert_true(strategies, "strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    return nil
end

local vt = find_strategy("VampiricTouch")
local swp = find_strategy("ShadowWordPain")
assert_true(vt ~= nil, "VampiricTouch strategy should exist")
assert_true(swp ~= nil, "ShadowWordPain strategy should exist")


-- ============================================================================
-- VT refresh window tests
-- ============================================================================

-- Base state that passes all other gates for VT
local base_vt_state = {
    vampiric_touch_known = true,
    mana_emergency = false,
    vt_remaining = 2.0,
    spell_damage = 100,
    snapshot_vt_dmg = 100,
    has_bloodlust = false,
    mf_channeling = false,
}

local base_vt_context = {
    in_combat = true,
    has_valid_enemy_target = true,
    is_moving = false,
    is_casting = false,
    is_channeling = false,
    ttd_known = false,
    ttd = 0,
    settings = {},
}

-- Default threshold = 1.5: vt_remaining=2.0 > 1.5 -> should NOT match
assert_false(vt.matches(base_vt_context, base_vt_state), "VT default threshold: 2.0 > 1.5 -> no match")

-- Custom threshold = 2.5: vt_remaining=2.0 <= 2.5 -> should match (other gates pass)
local ctx_custom_vt = {}
for k, v in pairs(base_vt_context) do ctx_custom_vt[k] = v end
ctx_custom_vt.settings = { shadow_vt_refresh_window = 2.5 }
assert_true(vt.matches(ctx_custom_vt, base_vt_state), "VT custom threshold 2.5: 2.0 <= 2.5 -> match")

-- ============================================================================
-- SW:P refresh window tests
-- ============================================================================

-- Base state that passes all other gates for SW:P
local base_swp_state = {
    swp_known = true,
    mana_emergency = false,
    swp_remaining = 2.0,
    spell_damage = 100,
    snapshot_swp_dmg = 100,
    has_bloodlust = false,
    weaving_stacks = 5,
    mf_channeling = false,
}

local base_swp_context = {
    in_combat = true,
    has_valid_enemy_target = true,
    ttd_known = false,
    ttd = 0,
    settings = {},
}

-- Default threshold = 1.5: swp_remaining=2.0 > 1.5 -> should NOT match
assert_false(swp.matches(base_swp_context, base_swp_state), "SW:P default threshold: 2.0 > 1.5 -> no match")

-- Custom threshold = 2.5: swp_remaining=2.0 <= 2.5 -> should match (other gates pass)
local ctx_custom_swp = {}
for k, v in pairs(base_swp_context) do ctx_custom_swp[k] = v end
ctx_custom_swp.settings = { shadow_swp_refresh_window = 2.5 }
assert_true(swp.matches(ctx_custom_swp, base_swp_state), "SW:P custom threshold 2.5: 2.0 <= 2.5 -> match")

-- ============================================================================
-- Fallback to 1.5 when no setting provided (via NS.get_setting)
-- ============================================================================

_G.EaxRotations.get_setting = function(key, default)
    return default
end

-- Re-load to pick up NS.get_setting
package.loaded["EaxRotations/classes/priest/shadow_sylvanas.lua"] = nil
result = dofile("EaxRotations/classes/priest/shadow_sylvanas.lua")
strategies = result.strategies or result
vt = find_strategy("VampiricTouch")
swp = find_strategy("ShadowWordPain")

assert_false(vt.matches(base_vt_context, base_vt_state), "VT fallback via NS.get_setting: 2.0 > 1.5 -> no match")
assert_false(swp.matches(base_swp_context, base_swp_state), "SW:P fallback via NS.get_setting: 2.0 > 1.5 -> no match")

print("PASS test_shadow_refresh_windows")
