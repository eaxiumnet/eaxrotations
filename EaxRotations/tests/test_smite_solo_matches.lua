-- regression checks for Smite Priest solo/leveling/PvP support rows.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

package.loaded["common/enums"] = { class_id = { PRIEST = 5 } }

local ready_calls = 0
_G.EaxRotations = {
    CLASS_ID = { PRIEST = 5 },
    PLAYER_UNIT = {},
    PriestSpells = {
        InnerFire = 588,
        PowerWordShield = 17,
        Renew = 139,
        PsychicScream = 8122,
        Shadowfiend = 34433,
        Smite = 585,
        HolyFire = 14914,
        MindBlast = 8092,
        ShadowWordPain = 589,
    },
    GetPlayer = function()
        return {
            get_class = function() return 5 end,
            get_race_id = function() return 1 end,
            is_moving = function() return false end,
            mana_pct = function() return 100 end,
        }
    end,
    import_helpers = function()
        return function() return true end, function() return true end, function()
            ready_calls = ready_calls + 1
            return true
        end, function() return 0 end, function() return false end, function() return 100 end, function() return false end
    end,
    debuff_up = function() return false end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local strategies = dofile("EaxRotations/classes/priest/smite_sylvanas.lua").strategies
assert_true(strategies, "smite strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local pws = find_strategy("SoloPowerWordShield")
assert_true(pws.matches({ is_solo = true, player_control_locked = false, settings = {} }, {
    has_weakened_soul = false,
    hp_pct = 40,
    power_word_shield_ready = true,
}), "solo PW:S should match at low HP")
assert_false(pws.matches({ is_solo = true, player_control_locked = false, settings = {} }, {
    has_weakened_soul = true,
    hp_pct = 40,
    power_word_shield_ready = true,
}), "solo PW:S should respect Weakened Soul")

local renew = find_strategy("SoloRenew")
assert_true(renew.matches({ is_leveling = true, player_control_locked = false, settings = {} }, {
    has_renew = false,
    hp_pct = 60,
    renew_ready = true,
}), "leveling Renew should match at moderate HP")

local scream = find_strategy("SoloPsychicScream")
assert_true(scream.matches({ in_combat = true, is_pvp = true, player_control_locked = false, settings = {} }, {
    hp_pct = 50,
    enemy_count = 1,
    psychic_scream_ready = true,
}), "PvP Psychic Scream should match at low HP")

local fiend = find_strategy("ShadowfiendMana")
assert_true(fiend.matches({
    in_combat = true,
    has_valid_enemy_target = true,
    target = {},
    target_phys_immune = false,
    settings = {},
}, {
    mana_pct = 20,
    shadowfiend_ready = true,
}), "Shadowfiend should match at low mana")

assert_true(ready_calls >= 0, "stub sanity")
print("PASS test_smite_solo_matches")
