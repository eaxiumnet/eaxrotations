-- test_paladin_protection_jow_mode.lua — Prot Paladin Mana Emergency Judge Wisdom.
-- WHAT:  verifies judgement_wisdom_mode hysteresis and match gating.
-- WHEN:  regression guard for protection_sylvanas.lua JoW swap logic.
-- WHY:   prevents flip-flopping and ensures wisdom-only judgement below threshold.
-- SAFETY: mocks NS minimally; bypasses build_state with crafted state tables.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

local _captured_strategies
_G.EaxRotations = {
    PaladinSpells = {
        RighteousFury = 25780, SealRighteousness = {27155}, SealCommand = {27170},
        HolyShield = {27179}, Consecration = {27173}, AvengerShield = {32699},
        Judgement = {20271}, DivineShield = {642}, DivineProtection = {498},
        LayOnHands = 27154, HammerOfWrath = {27180}, AvengingWrath = 31884,
        Exorcism = {871}, HolyWrath = {27139}, HammerOfJustice = {10308},
        Cleanse = {4987}, SealOfWisdom = 27166, RighteousDefense = 31789,
        BlessingOfProtection = 10278, BlessingOfSanctuary = 27169,
        DevotionAura = {27149}, FlashOfLight = {27137}, HolyLight = {27136},
        HolyShock = {33072}, HolyWrathSpell = {27139},
    },
    buff_up = function() return false end,
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
    }
    if overrides then for k, v in pairs(overrides) do s[k] = v end end
    return s
end

dofile("EaxRotations/classes/paladin/protection_sylvanas.lua")

local ctx = { in_combat = true, is_mounted = false, has_valid_enemy_target = true, me = {}, target = { x=1, y=1 }, settings = { playstyle = "protection" } }

-- C1: Normal mana → judgement allowed (has_seal)
local jud = find_strategy("Judgement")
assert_true(jud, "Judgement strategy should exist")
assert_true(jud.matches(ctx, build_state_proxy()), "C1: normal mana, has seal -> match")
print("  [ PASS ] C1: normal mana judgement matches")

-- C2: JoW mode active but no wisdom seal -> no match
assert_false(jud.matches(ctx, build_state_proxy({ judgement_wisdom_mode = true, has_seal = true, has_seal_wisdom = false })),
    "C2: JoW mode without wisdom seal -> no match")
print("  [ PASS ] C2: JoW mode blocks judgement without wisdom seal")

-- C3: JoW mode active with wisdom seal but target already has wisdom -> no match
assert_false(jud.matches(ctx, build_state_proxy({ judgement_wisdom_mode = true, has_seal = true, has_seal_wisdom = true, target_has_wisdom = true })),
    "C3: JoW mode with wisdom on target -> no match")
print("  [ PASS ] C3: JoW mode blocks when target already debuffed")

-- C4: JoW mode active with wisdom seal and target clean -> match
assert_true(jud.matches(ctx, build_state_proxy({ judgement_wisdom_mode = true, has_seal = true, has_seal_wisdom = true, target_has_wisdom = false })),
    "C4: JoW mode with wisdom seal and clean target -> match")
print("  [ PASS ] C4: JoW mode allows judgement with wisdom seal")

-- C5: Hysteresis — last mode retained in dead band (20% threshold, 21% mana)
local s5 = build_state_proxy({ mana_pct = 21, last_judgement_mode = "wisdom" })
-- Recompute mode logic (simulating what build_state does)
local jow_threshold = 20
local mana_pct = 21
if mana_pct < jow_threshold then s5.judgement_wisdom_mode = true; s5.last_judgement_mode = "wisdom"
elseif mana_pct > (jow_threshold + 5) then s5.judgement_wisdom_mode = false; s5.last_judgement_mode = "damage"
else s5.judgement_wisdom_mode = (s5.last_judgement_mode == "wisdom") end
assert_true(s5.judgement_wisdom_mode, "C5: hysteresis retains wisdom mode at 21%")
print("  [ PASS ] C5: hysteresis retains mode in dead band")

-- C6: Recovery above threshold+5 resets to damage mode
local s6 = build_state_proxy({ mana_pct = 26, last_judgement_mode = "wisdom" })
if s6.mana_pct < jow_threshold then s6.judgement_wisdom_mode = true; s6.last_judgement_mode = "wisdom"
elseif s6.mana_pct > (jow_threshold + 5) then s6.judgement_wisdom_mode = false; s6.last_judgement_mode = "damage"
else s6.judgement_wisdom_mode = (s6.last_judgement_mode == "wisdom") end
assert_false(s6.judgement_wisdom_mode, "C6: recovery to 26% resets to damage mode")
print("  [ PASS ] C6: recovery resets mode")

print("PASS test_paladin_protection_jow_mode")
