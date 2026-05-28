-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_arms_hamstring_tactician.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- unit tests for arms_sylvanas Hamstring Tactician weave gating.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local pass_count = 0
local test_count = 0

local function assert_true(v, label)
    test_count = test_count + 1
    if not v then error("FAIL: " .. (label or "assert_true"), 2) end
    pass_count = pass_count + 1
end

local function assert_false(v, label)
    test_count = test_count + 1
    if v then error("FAIL: " .. (label or "assert_false"), 2) end
    pass_count = pass_count + 1
end

local function assert_eq(a, b, label)
    test_count = test_count + 1
    if a ~= b then error("FAIL: " .. (label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
    pass_count = pass_count + 1
end

-- MortalStrike spell ID used in cooldown_remains mock
local MORTAL_STRIKE_SPELL_ID = 12294

-- Mock NS namespace
local action_calls = {}
local spell_ready_calls = {}
_G.EaxRotations = {
    WarriorSpells = {
        Hamstring = { 25212, 7373, 7372, 1715 },
        MortalStrike = MORTAL_STRIKE_SPELL_ID,
        BattleShout = 6673,
        Execute = 5308,
        Overpower = 7384,
        HeroicStrike = 78,
    },
    WarriorConstants = {
        STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
    },
    action_matches = function(ctx, act)
        action_calls[#action_calls + 1] = { fn = "action_matches", ctx = ctx, act = act }
        return true
    end,
    action_execute = function() return true end,
    spell_ready = function(spell, target, opts)
        spell_ready_calls[#spell_ready_calls + 1] = { spell = spell, target = target, opts = opts }
        return true
    end,
    buff_up = function(me, buff_list) return false end,
    debuff_remains = function(unit, ids) return 0 end,
    -- Return 3.0s for MortalStrike (still on CD), 0 for everything else
    cooldown_remains = function(spell_value, fallback)
        if spell_value == MORTAL_STRIKE_SPELL_ID then
            return 3.0  -- MS has 3s remaining on cooldown
        end
        if type(spell_value) == "number" then return 0 end
        return (fallback or 1) > 0 and fallback or 0
    end,
    log = function() end,
    get_tactical_mastery_cap = function() return 25 end,
    is_execute_phase = function(hp, threshold) return hp and hp <= (threshold or 20) end,
    rotation_registry = { register = function() end },
    PLAYER_UNIT = {},
    GetPlayer = function() return {} end,
}

local strategies = dofile("EaxRotations/classes/warrior/arms_sylvanas.lua")
assert_true(strategies, "strategies table should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- Hamstring Tactician Weave Tests
-- ============================================================================

local hamstring = find_strategy("Hamstring")

-- Base context for non-PvP, in-combat warrior in Battle Stance
local function base_context(overrides)
    local ctx = {
        settings = {
            hamstring_tactician_weave = true,
            hamstring_weave_rage = 55,
            hamstring_fleeing_mobs = false,
        },
        rage = 80,
        hp = 100,
        in_combat = true,
        stance = 1,
        target_hp = 100,
        is_pvp = false,
        target = { is_valid = function() return true end },
    }
    if overrides then
        for k, v in pairs(overrides) do
            if k == "settings" then
                for sk, sv in pairs(v) do ctx.settings[sk] = sv end
            else
                ctx[k] = v
            end
        end
    end
    return ctx
end

-- Case 1: Tactician disabled -> should NOT match
action_calls = {}
assert_false(
    hamstring.matches(base_context({ settings = { hamstring_tactician_weave = false, hamstring_fleeing_mobs = false } })),
    "Hamstring should not match when tactician weave disabled and flee disabled, non-PvP"
)
assert_eq(#action_calls, 0, "action_matches should not be called when all hamstring cases are gated")

-- Case 2: Tactician enabled, rage below threshold -> should NOT match
action_calls = {}
assert_false(
    hamstring.matches(base_context({ rage = 30 })),
    "Hamstring should not match when rage (30) below weave threshold (55)"
)
assert_eq(#action_calls, 0, "action_matches should not be called when rage is insufficient")

-- Case 3: Tactician enabled, rage at threshold -> should match (ms_cd = 3.0 > 1.5)
action_calls = {}
spell_ready_calls = {}
assert_true(
    hamstring.matches(base_context({ rage = 55 })),
    "Hamstring should match when rage equals threshold (55), MS on CD"
)
assert_true(#spell_ready_calls > 0, "spell_ready should be called when all tactician conditions met (build_state + match)")

-- Case 4: Tactician enabled, rage above threshold, MS ready (CD <= 1.5) -> should NOT match
-- Temporarily override cooldown_remains to return 0 for MS (CD ready)
local orig_cooldown = _G.EaxRotations.cooldown_remains
_G.EaxRotations.cooldown_remains = function(spell_value, fallback)
    if spell_value == MORTAL_STRIKE_SPELL_ID then return 0.5 end  -- MS almost ready (< 1.5)
    return orig_cooldown(spell_value, fallback)
end
-- Re-load to pick up the new mock
-- Note: we can't easily re-load, so instead we test via the match function
-- which builds state fresh each call (good). The mock change takes effect.
action_calls = {}
assert_false(
    hamstring.matches(base_context({ rage = 80 })),
    "Hamstring should not match when MS CD (0.5s) < 1.5s — MS about to come up"
)
assert_eq(#action_calls, 0, "action_matches should not be called when MS CD is too short")

-- Restore original
_G.EaxRotations.cooldown_remains = orig_cooldown

-- Case 5: Tactician enabled, rage above threshold, MS on CD, execute phase active -> should NOT match
action_calls = {}
assert_false(
    hamstring.matches(base_context({ target_hp = 15 })),
    "Hamstring tactician should not match during execute phase (target_hp=15)"
)

-- Case 6: PvP mode with Hamstring debuff low -> should match (PvP snare path, not tactician)
action_calls = {}
spell_ready_calls = {}
local pvp_debuff_context = base_context({
    is_pvp = true,
    settings = { hamstring_fleeing_mobs = false }, -- tactician defaults are on
    -- We need hamstring_remains <= 3. The debuff_remains mock returns 0 for all,
    -- so arms_state.hamstring_remains will be 0, which is <= 3, so PvP path should trigger
})
assert_true(
    hamstring.matches(pvp_debuff_context),
    "Hamstring should match in PvP when debuff is low/expired (PvP snare path)"
)
assert_true(#spell_ready_calls > 0, "spell_ready should be called for PvP snare path (build_state + match)")

-- Case 7: Tactician enabled with custom rage threshold from settings
action_calls = {}
spell_ready_calls = {}
assert_true(
    hamstring.matches(base_context({
        rage = 70,
        settings = { hamstring_tactician_weave = true, hamstring_weave_rage = 65, hamstring_fleeing_mobs = false },
    })),
    "Hamstring should match with custom weave_rage=65 when rage=70, MS on CD"
)
assert_true(#spell_ready_calls > 0, "spell_ready should be called with custom rage threshold (build_state + match)")

-- Case 8: Tactician enabled with low custom rage threshold
action_calls = {}
assert_false(
    hamstring.matches(base_context({
        rage = 40,
        settings = { hamstring_tactician_weave = true, hamstring_weave_rage = 55, hamstring_fleeing_mobs = false },
    })),
    "Hamstring should not match when rage (40) < custom threshold (55)"
)
assert_eq(#action_calls, 0, "action_matches should not be called when rage below custom threshold")

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("PASS test_arms_hamstring_tactician (%d/%d assertions passed)", pass_count, test_count))
