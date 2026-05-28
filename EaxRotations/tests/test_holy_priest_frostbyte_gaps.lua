-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_holy_priest_frostbyte_gaps.lua"
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
-- Feature audit for holy_sylvanas: documents FrostByte gaps vs present strategies.
-- Verifies all 22 strategies (16 existing + 6 FrostByte)

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;../?.lua;../EaxRotations/?.lua;../EaxRotations/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Mock unit object
local mock_unit = {
    get_class = function() return 5 end,  -- Priest class ID
    is_mounted = function() return false end,
    is_moving = function() return false end,
    mana_pct = function() return 100 end,
    can_attack = function() return true end,
    is_casting = function() return false end,
    is_channeling = function() return false end,
    is_alive = function() return true end,
    is_valid = function() return true end,
    is_in_combat = function() return false end,
    get_health_percentage = function() return 100 end,
    get_health = function() return 10000 end,
    get_max_health = function() return 10000 end,
}

-- Mock party/raid frames for healing target scanning
local mock_party = {
    { unit = mock_unit, effective_hp = 85, is_tank = true, has_renew = false, has_weakened_soul = false, is_player = false },
    { unit = mock_unit, effective_hp = 95, is_tank = false, has_renew = false, has_weakened_soul = false, is_player = false },
}

-- Mock NS namespace
_G.EaxRotations = {
    PriestSpells = { Fade = true, GreaterHeal = true },  -- Mock spell references
    PriestFLASH_HEAL_RANKS = {},
    PriestGREATER_HEAL_RANKS = {},
    PriestPRAYER_OF_HEALING_RANKS = {},
    PriestBINDING_HEAL_RANKS = {},

    PriestHealing = {
        scan_healing_targets = function()
            return mock_party, 2
        end,
        count_subgroup_below_hp = function(_)
            return 1
        end,
    },

    cast_best_heal_rank = function(_, target, _ctx, label, _opts)
        return { id = 1, name = label }, label
    end,

    is_item_ready = function() return false end,
    use_item_by_id = function() return true end,
    stop_casting = function() return true end,
    cancel_current_cast = function() return true end,

    GetPlayer = function() return mock_unit end,
    GetEnemiesInRange = function() return {} end,
    PLAYER_UNIT = "player",

    import_helpers = function(...)
        local helpers = {}
        local args = {...}
        for i = 1, #args do
            helpers[args[i]] = function(...)
                -- try_cast, spell_exists, etc return appropriate mock values
                return true
            end
        end
        -- Override specific helpers with realistic behavior
        -- health_pct returns player's HP
        helpers.health_pct = function() return 100 end
        -- spell_exists returns true for key spells
        helpers.spell_exists = function(spell)
            if type(spell) == "table" and spell.id then return true end
            if type(spell) == "number" then return true end
            return true
        end
        -- spell_ready returns true
        helpers.spell_ready = function() return true end
        -- debuff_remains returns 0 (no debuffs active)
        helpers.debuff_remains = function() return 0 end
        -- player_control_locked returns false
        helpers.player_control_locked = function() return false end
        -- has_player_buff returns false
        helpers.has_player_buff = function() return false end
        return helpers.try_cast, helpers.spell_exists, helpers.spell_ready,
               helpers.debuff_remains, helpers.health_pct,
               helpers.player_control_locked, helpers.has_player_buff
    end,

    log = function() end,
    log_warning = function() end,

    get_map_id = function() return 0 end,

    rotation_registry = {
        register = function(name, strategies, opts)
            -- Capture the strategies for audit
            _G.EaxRotations._last_registered_strategies = strategies
        end,
    },

    _last_registered_strategies = nil,

    -- Mock class constants needed by shared modules
    CLASS_ID = {
        PRIEST = 5,
    },
}

-- Load holy_sylvanas.lua (should register strategies via rotation_registry)
local strategies = dofile("EaxRotations/classes/priest/holy_sylvanas.lua")
if not strategies or #strategies == 0 then
    strategies = _G.EaxRotations._last_registered_strategies or {}
end
assert_true(strategies, "strategies table should load")
assert_true(#strategies > 0, "strategies table should have entries, got " .. tostring(#strategies))

-- Collect strategy names for audit
local strategy_names = {}
for i = 1, #strategies do
    strategy_names[strategies[i].name] = true
end

-- ============================================================================
-- Feature Audit: Check which FrostByte features exist vs missing
-- ============================================================================

-- Core healing strategies that ARE present
assert_true(strategy_names["EmergencyPWS"], "EmergencyPWS should be present")
assert_true(strategy_names["EmergencyFlashHeal"], "EmergencyFlashHeal should be present")
assert_true(strategy_names["PrayerOfMending"], "PrayerOfMending should be present")
assert_true(strategy_names["CircleOfHealing"], "CircleOfHealing should be present")
assert_true(strategy_names["BindingHeal"], "BindingHeal should be present")
assert_true(strategy_names["PrayerOfHealing"], "PrayerOfHealing should be present")
assert_true(strategy_names["ClearcastingGreaterHeal"], "ClearcastingGreaterHeal should be present")
assert_true(strategy_names["InnerFocus"], "InnerFocus should be present")
assert_true(strategy_names["GreaterHeal"], "GreaterHeal should be present")
assert_true(strategy_names["FlashHeal"], "FlashHeal should be present")
assert_true(strategy_names["RenewTank"], "RenewTank should be present")
assert_true(strategy_names["RenewSpread"], "RenewSpread should be present")
assert_true(strategy_names["SurgeOfLightSmite"], "SurgeOfLightSmite should be present")
assert_true(strategy_names["IdleSWP"], "IdleSWP should be present")
assert_true(strategy_names["IdleHolyFire"], "IdleHolyFire should be present")
assert_true(strategy_names["IdleSmite"], "IdleSmite should be present")

-- FrostByte gap strategy assertions (6 newly implemented)
assert_true(strategy_names["StopCast"], "StopCast should be present")
assert_true(strategy_names["PreHeal"], "PreHeal should be present")
assert_true(strategy_names["Fade"], "Fade should be present")
assert_true(strategy_names["Healthstone"], "Healthstone should be present")
assert_true(strategy_names["MountedProtection"], "MountedProtection should be present")
assert_true(strategy_names["EncounterReactions"], "EncounterReactions should be present")

-- FrostByte features that should be present
-- These are known gaps from FROSTBYTE_GAP_ANALYSIS.md
local frostbyte_gaps = {
    "StopCast",            -- Stop-cast engine (mid-cast cancellation at HP checkpoints)
    "PreHeal",             -- Pre-heal system (queues GH/FH based on damage patterns)
    "Fade",                -- Fade auto-use (aggro drop with backup healer check)
    "Healthstone",         -- Healthstone auto-use (off-GCD, HP threshold)
    "MountedProtection",   -- Mounted protection (skip buffs/heals while mounted)
    "EncounterReactions",  -- Encounter reactions (Netherspite, Maiden, Moroes)
}

local present_gaps = 0
local missing_gaps = {}
for _, gap_name in ipairs(frostbyte_gaps) do
    if strategy_names[gap_name] then
        present_gaps = present_gaps + 1
    else
        missing_gaps[#missing_gaps + 1] = gap_name
    end
end

 local expected_count = 29
assert_eq(#strategies, expected_count, "expected " .. expected_count .. " strategies, got " .. #strategies)

print("PASS test_holy_priest_frostbyte_gaps (gap audit: " .. #strategies .. " strategies present, " .. present_gaps .. "/6 FrostByte gaps closed)")

-- Print gap status
if #missing_gaps > 0 then
    print("  Missing FrostByte features (" .. #missing_gaps .. "):")
    for _, name in ipairs(missing_gaps) do
        print("    - " .. name)
    end
else
    print("  All 6 FrostByte gaps closed!")
end

-- Print strategy inventory for reference
local sorted_names = {}
for name, _ in pairs(strategy_names) do
    sorted_names[#sorted_names + 1] = name
end
table.sort(sorted_names)
print("  Strategies present: " .. table.concat(sorted_names, ", "))
