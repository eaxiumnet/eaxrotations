-- test_protection_bok_party.lua -- Protection Paladin Blessing of Kings Party OOC.
-- WHAT:  verifies BlessingOfKingsParty strategy gating.
-- WHEN:  regression guard after protection_sylvanas.lua BoK party addition.
-- WHY:   BoK party must only fire OOC, only on missing buff, only when enabled.
-- SAFETY: mocks NS minimally; bypasses build_state with crafted state tables.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local _captured_strategies
local _buff_up_results = {}
_G.EaxRotations = {
    PaladinSpells = {
        RighteousFury = 25780, SealRighteousness = {27155}, SealCommand = {27170},
        HolyShield = {27179}, Consecration = {27173}, AvengerShield = {32699},
        Judgement = {20271}, DivineShield = {642}, DivineProtection = {498},
        LayOnHands = 27154, HammerOfWrath = {27180}, AvengingWrath = 31884,
        Exorcism = {871}, HolyWrath = {27139}, HammerOfJustice = {10308},
        Cleanse = {4987}, SealOfWisdom = 27166, RighteousDefense = 31789,
        BlessingOfProtection = 10278, BlessingOfSanctuary = 27169,
        BlessingOfKings = {20217},
        DevotionAura = {27149}, FlashOfLight = {27137}, HolyLight = {27136},
        HolyShock = {33072}, HolyWrathSpell = {27139},
    },
    PLAYER_UNIT = {},
    buff_up = function(unit, ids)
        if _buff_up_results[unit] then return _buff_up_results[unit] end
        return false
    end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    buff_remains = function() return 0 end,
    buff_points = function() return nil end,
    spell_ready = function() return true end,
    time_now = function() return 1000 end,
    game_time_ms = function() return 1000000 end,
    log = function() end,
    GetPlayer = function() return {} end,
    GetPartyMembers = function() return {} end,
    mana_pct = function() return 100 end,
    unit_health_pct = function() return 100 end,
    unit_mana_pct = function() return 100 end,
    not_same_unit = function(a, b) return a ~= b end,
    broken_api_throttled = function() return false end,
    rotation_registry = { register = function(self, spec, strategies, opts)
        _captured_strategies = strategies
    end },
    setting = function(ctx, key, fallback)
        if ctx and ctx.settings and ctx.settings[key] ~= nil then return ctx.settings[key] end
        return fallback
    end,
}

package.loaded["shared/potion_helper_sylvanas"] = { try_use_potion = function() return false end, MANA_POTION_IDS = {} }

local function find_strategy(name)
    for i = 1, #_captured_strategies do
        if _captured_strategies[i].name == name then return _captured_strategies[i] end
    end
    return nil
end

local function build_state_proxy(overrides)
    local s = {
        has_righteous_fury = true, has_holy_shield = true, holy_shield_charges = 5,
        has_seal = true, has_seal_command = false, has_devotion_aura = true,
        has_divine_shield = false, has_forbearance = false,
        consecration_remains = 0, has_blessing_sanctuary = true,
        now_ms = 1000000, consecration_ready = true, holy_shield_ready = true,
        avenger_ready = true, exorcism_ready = true, judgement_ready = true,
        divine_shield_ready = true, divine_protection_ready = true,
        lay_on_hands_ready = true, hammer_of_justice_ready = true,
        hammer_of_wrath_ready = true, avenging_wrath_ready = true,
        flash_of_light_ready = true, holy_light_ready = true,
        holy_shock_ready = true, holy_wrath_ready = true, cleanse_ready = true,
        needs_cleanse = false, seal_of_wisdom_ready = true,
        righteous_defense_ready = true, mana_pct = 100, hp_pct = 100,
        target_hp_pct = 100, enemy_count = 1, target_creature_type = nil,
        target_casting = false, ally_threatened = nil, low_hp_ally = nil,
        cc_nearby = false, has_seal_wisdom = false, target_has_wisdom = false,
        judgement_wisdom_mode = false, last_judgement_mode = nil,
        is_group = false,
    }
    if overrides then for k, v in pairs(overrides) do s[k] = v end end
    return s
end

dofile("EaxRotations/classes/paladin/protection_sylvanas.lua")

local bok = find_strategy("BlessingOfKingsParty")
assert_true(bok, "BlessingOfKingsParty strategy should exist")

-- C1: OOC, group, ally missing buff, setting enabled -> match
local ally_missing = { name = "ally1" }
_buff_up_results = { [ally_missing] = false }
local ctx1 = {
    in_combat = false,
    is_group = true,
    party_members = { ally_missing },
    me = {},
    settings = {},
}
assert_true(bok.matches(ctx1, build_state_proxy({ is_group = true })), "C1: OOC + group + ally missing buff -> match")
print("  [ PASS ] C1: OOC with missing buff ally matches")

-- C2: In combat -> no match
local ctx2 = {
    in_combat = true,
    is_group = true,
    party_members = { ally_missing },
    me = {},
    settings = {},
}
assert_false(bok.matches(ctx2, build_state_proxy({ is_group = true })), "C2: in combat -> no match")
print("  [ PASS ] C2: in combat does not match")

-- C3: Ally already has buff -> no match
local ally_has_buff = { name = "ally2" }
_buff_up_results = { [ally_has_buff] = true }
local ctx3 = {
    in_combat = false,
    is_group = true,
    party_members = { ally_has_buff },
    me = {},
    settings = {},
}
_buff_up_results[ctx3.me] = true
assert_false(bok.matches(ctx3, build_state_proxy({ is_group = true })), "C3: ally has buff -> no match")
print("  [ PASS ] C3: ally with buff does not match")

-- C4: Setting disabled -> no match
local ctx4 = {
    in_combat = false,
    is_group = true,
    party_members = { ally_missing },
    me = {},
    settings = { prot_bok_party = false },
}
assert_false(bok.matches(ctx4, build_state_proxy({ is_group = true })), "C4: setting disabled -> no match")
print("  [ PASS ] C4: setting disabled does not match")

-- C5: Not in group -> no match
local ctx5 = {
    in_combat = false,
    is_group = false,
    party_members = { ally_missing },
    me = {},
    settings = {},
}
assert_false(bok.matches(ctx5, build_state_proxy({ is_group = false })), "C5: not in group -> no match")
print("  [ PASS ] C5: not in group does not match")

print("PASS test_protection_bok_party")
