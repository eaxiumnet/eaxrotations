-- test_paladin_tbc_seals.lua — Retribution seal-twist suppress behavior + seal ID contract.
-- WHAT:  verifies the twist-suppress gate (suppress off-GCD abilities near MH swing when
--        seal-twisting is enabled) and the TBC Anniversary seal/judgement spell IDs.
-- WHEN:  regression guard for retribution_sylvanas.lua twist logic (backed by native
--        auto_attack_helper via NS.get_time_until_swing → state.swing_remains).
-- WHY:   the twist match-gate was implemented but had zero test coverage (this file was a
--        6-line stub). Seals of Blood (31892) / Martyr (348700) are TBC Anniversary 2.5.5
--        backports — assert they are referenced, never stripped as "WotLK".
-- SAFETY: bypasses build_state by passing crafted state tables; mocks NS minimally.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed: expected false", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- ============================================================================
-- Mock NS — minimal surface to load retribution_sylvanas.lua and exercise matches.
-- ============================================================================
local _captured_strategies
_G.EaxRotations = {
    PaladinSpells = {
        CrusaderStrike = 35395,
        Judgement = 20271,
        SealCommand = 27170,
        SealBlood = 31892,
        SealOfTheMartyr = 348700,
        SealRighteousness = 27155,
        SealCrusader = 27158,
        SealOfWisdom = 27166,
        Consecration = 27173,
        Exorcism = 27138,
        HolyWrath = 27139,
        HammerOfWrath = 27180,
        AvengingWrath = 31884,
        DivineStorm = 53723,
    },
    PLAYER_UNIT = { _mock = true },
    -- setting(context, key, default) — return the default for every key.
    setting = function(context, key, default) return default end,
    get_any_setting = function(context, k1, k2, fallback) return fallback end,
    spell_action = nil,  -- force inline action() fallback
    spell_ready = function(spell, target, opts) return true end,
    try_cast = function(spell, target, tag, opts) return true end,
    has_player_buff = function(ids) return false end,
    has_player_debuff = function(ids) return false end,
    has_target_debuff = function(unit, ids) return false end,
    buff_up = function(unit, ids) return false end,
    is_item_ready = function(id) return false end,
    is_casting = function(unit) return false end,
    is_interruptible = function(unit) return true end,
    unit_faction = function(unit) return "Horde" end,
    GetPlayer = function() return { _mock = true } end,
    get_time_until_swing = function() return 99 end,
    broken_api_throttled = function() return false end,
    log = function() end,
    time_now = function() return 1000 end,
    unit_alive = function(u) return true end,
    is_valid_target = function(u) return true end,
    unit_health_pct = function(u) return 100 end,
    unit_mana_pct = function(u) return 100 end,
    rotation_registry = {
        register = function(self, spec, strategies, opts)
            _captured_strategies = strategies
        end,
    },
}

-- Mock tbc_data_sylvanas so the pcall(require) at module top resolves cleanly.
package.loaded["shared/tbc_data_sylvanas"] = { ITEMS = { healthstones = {}, potions = {} } }

-- ============================================================================
-- Load spec
-- ============================================================================
local result = dofile("EaxRotations/classes/paladin/retribution_sylvanas.lua").strategies
assert_true(result ~= nil, "retribution module should load and return non-nil")
assert_true(_captured_strategies ~= nil, "strategies table should be captured via register")

local function find_strategy(name)
    for i = 1, #_captured_strategies do
        local s = _captured_strategies[i]
        if s.name == name then return s end
    end
    return nil
end

local crusader = find_strategy("CrusaderStrike")
assert_true(crusader, "CrusaderStrike strategy should exist")
local consecration = find_strategy("Consecration")
assert_true(consecration, "Consecration strategy should exist")
local exorcism = find_strategy("Exorcism")
assert_true(exorcism, "Exorcism strategy should exist")

-- ============================================================================
-- Mock context + state factory. Bypasses build_state entirely.
-- prep_start = (twist_window or 0.45) + 0.75 = 1.20s with twist_window=0.45.
-- ============================================================================
local TWIST_WINDOW = 0.45
local PREP_START = TWIST_WINDOW + 0.75  -- 1.20s

local function make_context()
    return {
        me = { get_distance = function(self, unit) return 5 end },
        target = { get_creature_type = function() return 3 end, is_player = function() return false end },  -- 3 = undead
        settings = {},
        in_combat = true,
        enemy_count = 3,
    }
end

local function make_context_with_optional_spells()
    local context = make_context()
    context.settings = { use_consecration = true, use_exorcism = true }
    return context
end

-- A "not suppressed" base state: twist OFF, in melee, mana fine, enough enemies.
local function base_state(overrides)
    local s = {
        can_twist = false,
        has_command = true,
        has_command_rank1 = false,
        has_blood = false,
        has_martyr = false,
        has_damage_seal = true,
        swing_remains = 5.0,        -- far from swing → not in twist window
        twist_window = TWIST_WINDOW,
        in_melee = true,
        mana_pct = 100,
        mana_emergency = false,
        enemy_count = 3,
    }
    if overrides then for k, v in pairs(overrides) do s[k] = v end end
    return s
end

print("--- Ret seal-twist: suppress off-GCD abilities near MH swing ---")

-- C1: twist ON, Command up (no Blood), swing IMMINENT → CrusaderStrike SUPPRESSED
assert_false(crusader.matches(make_context(), base_state({ can_twist = true, swing_remains = 0.3 })),
    "C1: twist on + Command + swing 0.3s (<=1.20) → CrusaderStrike suppressed")
print("  [ PASS ] C1: CrusaderStrike suppressed near swing when twisting")

-- C2: twist ON, swing FAR → CrusaderStrike NOT suppressed (falls through to spell_ready=true)
assert_true(crusader.matches(make_context(), base_state({ can_twist = true, swing_remains = 5.0 })),
    "C2: twist on + swing 5.0s (>1.20) → CrusaderStrike not suppressed")
print("  [ PASS ] C2: CrusaderStrike allowed when swing is far")

-- C3: twist OFF → suppression inactive even with imminent swing
assert_true(crusader.matches(make_context(), base_state({ can_twist = false, swing_remains = 0.3 })),
    "C3: twist off + swing 0.3s → suppression inactive, CrusaderStrike allowed")
print("  [ PASS ] C3: suppression inactive when seal_twisting disabled")

-- C4: twist ON but Blood already up → NOT suppressed (twist gate requires Command-without-Blood)
assert_true(crusader.matches(make_context(), base_state({ can_twist = true, swing_remains = 0.3, has_command = false, has_blood = true })),
    "C4: twist on + Blood up → not suppressed (gate is Command-without-Blood only)")
print("  [ PASS ] C4: Blood-up bypasses Command-twist suppression")

-- C5: boundary — swing_remains exactly == prep_start → suppressed (<= comparison)
assert_false(crusader.matches(make_context(), base_state({ can_twist = true, swing_remains = PREP_START })),
    "C5: swing_remains == prep_start (1.20) → suppressed (<=)")
print("  [ PASS ] C5: boundary prep_start is suppressed")

-- C6: Consecration honours the same twist-suppress gate
assert_false(consecration.matches(make_context_with_optional_spells(), base_state({ can_twist = true, swing_remains = 0.3 })),
    "C6: Consecration suppressed near swing when twisting")
assert_true(consecration.matches(make_context_with_optional_spells(), base_state({ can_twist = true, swing_remains = 5.0 })),
    "C6b: Consecration allowed when swing far")
print("  [ PASS ] C6: Consecration honours twist-suppress gate")

-- C7: Exorcism honours the same twist-suppress gate (undead target → spell_ready path)
assert_false(exorcism.matches(make_context_with_optional_spells(), base_state({ can_twist = true, swing_remains = 0.3 })),
    "C7: Exorcism suppressed near swing when twisting")
assert_true(exorcism.matches(make_context_with_optional_spells(), base_state({ can_twist = true, swing_remains = 5.0 })),
    "C7b: Exorcism allowed when swing far")
print("  [ PASS ] C7: Exorcism honours twist-suppress gate")

print("--- Ret TBC Anniversary seal/judgement spell IDs ---")

-- C8: Seal of Blood (31892) and Seal of the Martyr (348700) are TBC Anniversary 2.5.5
-- backports — they MUST be present (AGENTS.md: do not strip as "WotLK"). Verify the seal
-- buff ID tables in the module reference them by reading the loaded module's constants.
-- We re-dofile to grab the file source and assert the IDs appear (guard against regression).
local src = io.open("EaxRotations/classes/paladin/retribution_sylvanas.lua", "r"):read("*a")
assert_true(src:find("31892", 1, true) ~= nil, "C8: Seal of Blood 31892 must be referenced")
assert_true(src:find("348700", 1, true) ~= nil, "C8: Seal of the Martyr 348700 must be referenced")
assert_true(src:find("27170", 1, true) ~= nil, "C8: Seal of Command 27170 must be referenced")
print("  [ PASS ] C8: SoB 31892 / SoM 348700 / SoC 27170 all referenced (TBC Anniversary backports preserved)")

-- C9: SealBlood_Primary and SealMartyr_Primary strategies exist (damage-seal swap paths)
assert_true(find_strategy("Ret_SealBlood_Primary") ~= nil, "C9: Ret_SealBlood_Primary strategy should exist")
assert_true(find_strategy("Ret_SealMartyr_Primary") ~= nil, "C9: Ret_SealMartyr_Primary strategy should exist")
assert_true(find_strategy("Ret_SealCommand_Primary") ~= nil, "C9: Ret_SealCommand_Primary strategy should exist")
print("  [ PASS ] C9: Blood/Martyr/Command primary seal strategies registered")

print("PASS test_paladin_tbc_seals")
