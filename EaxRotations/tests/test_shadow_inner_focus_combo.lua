-- Test: Shadow Priest Inner Focus + Mind Blast combo.

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
    DOT_DURATIONS = {},
}

local strategies = dofile("EaxRotations/classes/priest/shadow_sylvanas.lua")
assert_true(strategies, "strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    return nil
end

local if_combo = find_strategy("InnerFocusMindBlast")
assert_true(if_combo ~= nil, "InnerFocusMindBlast strategy should exist")

-- Combo enabled, MB ready, in combat, not mana_low -> match
assert_true(if_combo.matches({ in_combat = true, settings = { shadow_if_mb_combo = true } },
    { mb_ready = true, has_inner_focus = false, mana_low = false, mf_channeling = false }), "combo + MB ready -> match")

-- Combo enabled, MB on short CD (<=5s) -> match (hold for MB)
assert_true(if_combo.matches({ in_combat = true, settings = { shadow_if_mb_combo = true } },
    { mb_ready = false, mb_cd_remains = 3, has_inner_focus = false, mana_low = false, mf_channeling = false }), "combo + MB soon -> match")

-- Combo enabled, MB on long CD (>5s), combo enabled -> should NOT match (don't hold forever)
assert_false(if_combo.matches({ in_combat = true, settings = { shadow_if_mb_combo = true } },
    { mb_ready = false, mb_cd_remains = 8, has_inner_focus = false, mana_low = false, mf_channeling = false }), "combo + MB long CD -> no match")

-- Combo disabled -> use non-combo logic (requires mb_ready)
assert_true(if_combo.matches({ in_combat = true, settings = { shadow_if_mb_combo = false } },
    { mb_ready = true, has_inner_focus = false, mana_low = false, mf_channeling = false }), "combo off + MB ready -> match")

-- Already has inner focus -> no match
assert_false(if_combo.matches({ in_combat = true, settings = { shadow_if_mb_combo = true } },
    { mb_ready = true, has_inner_focus = true, mana_low = false, mf_channeling = false }), "already has IF -> no match")

-- OOC -> no match
assert_false(if_combo.matches({ in_combat = false, settings = { shadow_if_mb_combo = true } },
    { mb_ready = true, has_inner_focus = false, mana_low = false, mf_channeling = false }), "OOC -> no match")

-- Mana low -> no match
assert_false(if_combo.matches({ in_combat = true, settings = { shadow_if_mb_combo = true } },
    { mb_ready = true, has_inner_focus = false, mana_low = true, mf_channeling = false }), "mana_low -> no match")

print("PASS test_shadow_inner_focus_combo")
