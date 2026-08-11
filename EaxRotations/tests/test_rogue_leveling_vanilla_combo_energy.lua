-- test_rogue_leveling_vanilla_combo_energy.lua — pins the 2026-08-11 fix of
-- the last degraded chain from the undefined-NS-member sweep: rogue
-- leveling_vanilla read `NS.combo_points or 0` / `NS.energy or 100` — bare
-- member reads (never a call, so the NS-member audit structurally cannot see
-- them) of members that are NEVER assigned. Live, combo was always 0 (every
-- finisher gate dead: SliceAndDice >= 1, Rupture/ExposeArmor/KidneyShot >= 3,
-- Eviscerate >= 5) and energy always 100 (Thistle Tea's <= 40 gate never
-- fired). Fixed by reading the real surface the engine writes — context
-- .combo_points (main_sylvanas.lua:858 via combo_points_reader) and context
-- .energy (main_sylvanas.lua:811) — plus the me:combo_points_current() and
-- me:get_power(4/3) unit fallbacks, mirroring rogue/leveling_sylvanas.lua:253.
-- WHAT:  (1) build_state reads context.combo_points / context.energy when the
--        engine provides them; (2) falls back to me:get_power(4/3) when the
--        context fields are absent; (3) a real strategy fires on the wired
--        value and stays silent at 0 — Rupture at combo 4 vs 0, Thistle Tea
--        at energy 30 vs 100.
-- WHEN:  rotation suite execution (run_rotation_tests.lua).
-- WHY:   a future edit that reverts these lines to bare NS reads re-deads the
--        vanilla rogue finishers without any audit noticing (non-call reads).
-- SAFETY: full mock _G.EaxRotations before require (runner snapshots/restores
--         _G per suite); no game data, no fs writes.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label)
    if not v then error("FAIL: " .. (label or "assert_true"), 2) end
end

local function assert_eq(a, b, label)
    if a ~= b then
        error("FAIL: " .. (label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2)
    end
end

-- ============================================================================
-- Mock NS surface the file touches at load + during build_state/matches.
-- ============================================================================
_G.core = {
    time = function() return 0 end,
    get_game_version = function() return "1.15.5" end,
    log = function() end,
    object_manager = { get_local_player = function() return nil end },
    spell_book = {
        is_spell_learned = function() return true end,
        get_global_cooldown = function() return 1.5 end,
        get_spell_cooldown = function() return 0 end,
    },
    input = { cast_target_spell = function() return false end },
}

local mock_me
_G.EaxRotations = {
    RogueSpells = {
        SinisterStrike = { 1752 }, Eviscerate = { 2098 }, SliceAndDice = { 5171 },
        Rupture = { 1943 }, Garrote = { 863 }, Ambush = { 867 }, Kick = { 1766 },
        Gouge = { 1776 }, Evasion = { 5277 }, Sprint = { 2983 }, BladeFlurry = { 13877 },
        AdrenalineRush = { 13750 }, ColdBlood = { 14177 }, Vanish = { 1856 },
        Stealth = { 1784 }, KidneyShot = { 408 }, ExposeArmor = { 8647 },
        ThistleTea = { 9512 }, Sap = { 6770 }, Blind = { 2094 },
    },
    spell_exists = function() return true end,
    spell_ready = function() return true end,
    try_cast = function() return false end,
    buff_up = function() return false end,
    debuff_remains = function() return 0 end,
    get_setting = function() return nil end,
    GetPlayer = function() return mock_me end,
    get_local_player = function() return mock_me end,
}
package.loaded["classes/rogue/leveling_vanilla"] = nil
local rogue_leveling = require("classes/rogue/leveling_vanilla")

local function rupture_matches(ctx, state)
    for _, s in ipairs(rogue_leveling.strategies) do
        if s.name == "Rupture" then return s.matches(ctx, state) == true end
    end
    error("Rupture strategy not found", 2)
end

local function thistle_tea_matches(ctx, state)
    for _, s in ipairs(rogue_leveling.strategies) do
        if s.name == "ThistleTea" then return s.matches(ctx, state) == true end
    end
    error("ThistleTea strategy not found", 2)
end

-- ============================================================================
-- (1) Engine-wired path: context.combo_points / context.energy are real.
-- ============================================================================
local ctx_wired = { in_combat = true, combo_points = 4, energy = 60, target = {} }
local st = rogue_leveling.build_state(ctx_wired)
assert_eq(st.combo_points, 4, "context.combo_points flows into state.combo_points")
assert_eq(st.energy, 60, "context.energy flows into state.energy")
assert_true(rupture_matches(ctx_wired, st), "Rupture FIRES at wired combo 4 (>= 3, < 5)")

-- ============================================================================
-- (2) Unit fallback: context fields absent -> me:get_power(4/3) wins.
-- ============================================================================
mock_me = {
    get_power = function(self, power_type)
        if power_type == 4 then return 3 end -- combo
        if power_type == 3 then return 45 end -- energy
        return 0
    end,
}
local ctx_unit = { in_combat = true, target = {} }
local st2 = rogue_leveling.build_state(ctx_unit)
assert_eq(st2.combo_points, 3, "me:get_power(4) supplies combo when context is absent")
assert_eq(st2.energy, 45, "me:get_power(3) supplies energy when context is absent")

-- ============================================================================
-- (3) Silent at zero: the SAME strategies must not fire with empty pools.
-- ============================================================================
mock_me = { get_power = function(self, power_type) return 0 end }
local ctx_zero = { in_combat = true, combo_points = 0, energy = 100, target = {} }
local st0 = rogue_leveling.build_state(ctx_zero)
assert_eq(st0.combo_points, 0, "zero combo stays zero")
assert_eq(st0.energy, 100, "full energy stays 100")
assert_eq(rupture_matches(ctx_zero, st0), false, "Rupture SILENT at combo 0")
assert_eq(thistle_tea_matches(ctx_zero, st0), false, "ThistleTea SILENT at energy 100 (> 40)")

-- ThistleTea fires only when the pool is genuinely low (energy <= 40).
mock_me = { get_power = function(self, power_type) return 0 end }
local ctx_low = { in_combat = true, combo_points = 0, energy = 30, target = {} }
local stl = rogue_leveling.build_state(ctx_low)
assert_eq(stl.energy, 30, "low energy flows through")
assert_true(thistle_tea_matches(ctx_low, stl), "ThistleTea FIRES at energy 30 (<= 40)")

print("PASS test_rogue_leveling_vanilla_combo_energy (context + unit fallback chains, Rupture fired/silent, ThistleTea fired/silent)")
