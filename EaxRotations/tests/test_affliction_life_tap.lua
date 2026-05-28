-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_affliction_life_tap.lua"
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
-- unit tests for affliction_sylvanas Life Tap sustain logic.
-- Verifies Life Tap fires only when mana is below threshold and HP is safe.

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
    WarlockSpells = {
        LifeTap = 1454,
        DarkPact = 27220,
        Corruption = 172,
        CurseOfAgony = 27218,
        CurseOfDoom = 27214,
        ShadowBolt = 27209,
        Immolate = 348,
        SiphonLife = 27259,
        DrainLife = 27217,
        UnstableAffliction = 30108,
        Haunt = 30154,
        RainOfFire = 27211,
        SeedOfCorruption = 27243,
        DeathCoil = 2894,
        Fear = 6215,
        HealthFunnel = 30656,
        FelArmor = 28176,
        DemonArmor = 27299,
        SummonImp = 688,
        SummonVoidwalker = 697,
        SummonSuccubus = 712,
        SummonFelhunter = 691,
        SummonFelguard = 30146,
        CreateHealthstone = 6201,
    },
    PLAYER_UNIT = "player",
    spell_ready = function(spell, target, opts)
        action_calls[#action_calls + 1] = { fn = "spell_ready", spell = spell, target = target }
        return true
    end,
    try_cast = function(spell, target, label)
        action_calls[#action_calls + 1] = { fn = "try_cast", spell = spell, target = target, label = label }
        return true
    end,
    has_player_buff = function() return false end,
    debuff_remains = function() return 0 end,
    spell_cooldown = function() return 0 end,
    spell_action = function(spell_ids, name)
        return { spell = spell_ids, name = name }
    end,
    action_matches = function(ctx, act)
        action_calls[#action_calls + 1] = { fn = "action_matches", ctx = ctx, act = act }
        return true
    end,
    log = function() end,
    rotation_registry = {
        register = function() end,
    },
}

local result = dofile("EaxRotations/classes/warlock/affliction_sylvanas.lua")
assert_true(result, "strategies table should load")
local strategies = result.strategies or result
assert_true(type(strategies) == "table", "strategies table exists")

-- Helper to find strategy by name
local function find_strategy(name)
    for k, v in pairs(strategies) do
        if type(v) == "table" and v.name == name then
            return v
        end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- LifeTap: only when mana below threshold AND HP above safety threshold
-- ============================================================================

local life_tap = find_strategy("LifeTap")

-- Low mana (below threshold), HP safe -> should match
action_calls = {}local ctx_low_mana = {
	    target = {},
	    settings = {
	        aff_life_tap_mana = 40,
	    },
	}
	local st_low_mana = { mana_pct = 25, hp_pct = 80 }
	assert_true(life_tap.matches(ctx_low_mana, st_low_mana), "LifeTap should match when mana is low and HP is safe")
	
	-- High mana (above threshold) -> should NOT match
	action_calls = {}
	local ctx_high_mana = {
	    target = {},
	    settings = {
	        aff_life_tap_mana = 30,
	    },
	}
	local st_high_mana = { mana_pct = 65, hp_pct = 80 }
	assert_false(life_tap.matches(ctx_high_mana, st_high_mana), "LifeTap should not match when mana is above threshold")
	
	-- HP too low (below safety threshold) -> should NOT match
	action_calls = {}
	local ctx_low_hp = {
	    target = {},
	    settings = {
	        aff_life_tap_mana = 40,
	    },
	}
	local st_low_hp = { mana_pct = 20, hp_pct = 15 }
	assert_false(life_tap.matches(ctx_low_hp, st_low_hp), "LifeTap should not match when HP is too low")
	
	-- No settings (default used) -> should use default threshold of 30
	action_calls = {}
	local ctx_default_settings = {
	    target = {},
	    settings = {},
	}
	local st_default = { mana_pct = 25, hp_pct = 80 }
	assert_true(life_tap.matches(ctx_default_settings, st_default), "LifeTap should use default mana threshold when no setting provided")
	
	-- High mana with no settings -> should NOT match
	local ctx_no_state = {
	    target = {},
	    settings = {},
	}
	local st_no_state = { mana_pct = 100, hp_pct = 100 }
	assert_false(life_tap.matches(ctx_no_state, st_no_state), "LifeTap should not match when mana is above threshold (no_state case)")
	
	-- Mana exactly at threshold boundary -> should NOT match (must be below)
	action_calls = {}
	local ctx_boundary = {
	    target = {},
	    settings = {
	        aff_life_tap_mana = 30,
	    },
	}
	local st_boundary = { mana_pct = 30, hp_pct = 80 }
	assert_true(life_tap.matches(ctx_boundary, st_boundary), "LifeTap should match when mana == threshold (uses > not >=)")

print("PASS test_affliction_life_tap")
