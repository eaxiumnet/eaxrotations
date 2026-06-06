-- unit tests for affliction_sylvanas custom matches functions.
-- Complements test_affliction_life_tap.lua which already covers Life Tap.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Mock NS namespace
local spell_ready_calls = {}
_G.EaxRotations = {
    WarlockSpells = {
        DeathCoil = { ids = { 27223 }, name = "DeathCoil" },
        Soulshatter = { ids = { 29858 }, name = "Soulshatter" },
        ShadowBolt = { ids = { 27209 }, name = "ShadowBolt" },
        Corruption = { ids = { 27216 }, name = "Corruption" },
        UnstableAffliction = { ids = { 30405 }, name = "UnstableAffliction" },
        SiphonLife = { ids = { 30911 }, name = "SiphonLife" },
        CurseOfDoom = { ids = { 30910 }, name = "CurseOfDoom" },
        CurseOfAgony = { ids = { 27218 }, name = "CurseOfAgony" },
        Immolate = { ids = { 27215 }, name = "Immolate" },
        SeedOfCorruption = { ids = { 27285 }, name = "SeedOfCorruption" },
        LifeTap = { ids = { 27222 }, name = "LifeTap" },
    },
    spell_action = function(tbl) return tbl end,
    has_player_buff = function(buff_list) return false end,
    buff_remains = function(me, ids) return 0 end,
    debuff_remains = function(target, ids) return 0 end,
    get_debuff_stacks = function(target, ids) return 0 end,
    spell_ready = function(spell, target, opts)
        spell_ready_calls[#spell_ready_calls + 1] = { spell = spell, target = target, opts = opts }
        return true
    end,
    is_spell_learned = function(id) return true end,
    is_api_health_broken = function() return false end,
    is_item_ready = function(id) return false end,
    has_item = function(id) return false end,
    get_spell_damage = function() return 0 end,
    log = function() end,
    time_now = function() return 1000 end,
    cooldown_remains = function(spell, cd) return 0 end,
    rotation_registry = { register = function() end },
}

-- Override require for tbc_data/offensive_dispel to return empty stubs
local orig_pcall = _G.pcall
_G.pcall = function(fn, path, ...)
    if type(path) == "string" then
        if path:find("tbc_data_sylvanas") then return true, { ITEMS = { potions = {} } } end
        if path:find("reagent_guard") then return true, nil end
        if path:find("izi_sdk") then return false, nil end
    end
    return orig_pcall(fn, path, ...)
end

-- Override require too
local orig_require = _G.require
_G.require = function(path)
    if type(path) == "string" then
        if path:find("tbc_data_sylvanas") then return { ITEMS = { potions = {} } } end
        if path:find("offensive_dispel") then return {} end
        if path:find("reagent_guard") then return nil end
        if path:find("izi_sdk") then return nil end
    end
    return orig_require(path)
end

local result = dofile("EaxRotations/classes/warlock/affliction_sylvanas.lua")
assert_true(result, "affliction module should load")
local strategies = result.strategies
assert_true(strategies, "strategies table should load from result")

-- Restore require
_G.require = orig_require
_G.pcall = orig_pcall

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then
            return strategies[i]
        end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- DeathCoilSurvival: only when HP <= 30% and valid enemy target
-- ============================================================================

local death_coil = find_strategy("DeathCoilSurvival")

-- High HP -> should NOT match
spell_ready_calls = {}
assert_false(death_coil.matches({
    has_valid_enemy_target = true,
}, {
    hp_pct = 60,
}), "DeathCoil should not match when HP > 30%")

-- Low HP -> should match
spell_ready_calls = {}
assert_true(death_coil.matches({
    has_valid_enemy_target = true,
}, {
    hp_pct = 25,
}), "DeathCoil should match when HP <= 30%")

-- No valid enemy target -> should NOT match even with low HP
spell_ready_calls = {}
assert_false(death_coil.matches({
    has_valid_enemy_target = false,
}, {
    hp_pct = 20,
}), "DeathCoil should not match without valid enemy target")

-- ============================================================================
-- Healthstone: only when HP <= 40% and healthstone ready
-- ============================================================================

local healthstone = find_strategy("Healthstone")

-- High HP -> should NOT match
assert_false(healthstone.matches({
    hp = 70,
    me = { get_health_percentage = function() return 70 end },
}, {
    healthstone_ready = true, healthstone_id = 22105,
}), "Healthstone should not match when HP > 40%")

-- HP <= 40, healthstone ready -> should match
assert_true(healthstone.matches({
    hp = 30,
    me = { get_health_percentage = function() return 30 end },
}, {
    healthstone_ready = true, healthstone_id = 22105,
}), "Healthstone should match when HP <= 40% and ready")

-- HP low but healthstone not ready -> should NOT match
assert_false(healthstone.matches({
    hp = 25,
}, {
    healthstone_ready = false,
}), "Healthstone should not match when not ready")

-- ============================================================================
-- Nightfall: only when Nightfall proc is active and valid target
-- ============================================================================

local nightfall = find_strategy("NightfallProc")

-- No proc -> should NOT match
spell_ready_calls = {}
assert_false(nightfall.matches({
    has_valid_enemy_target = true,
}, {
    nightfall_active = false,
}), "Nightfall should not match without proc")

-- Proc active, valid target -> should match
spell_ready_calls = {}
assert_true(nightfall.matches({
    has_valid_enemy_target = true,
}, {
    nightfall_active = true,
}), "Nightfall should match with proc and valid target")

-- Proc active but no target -> should NOT match
spell_ready_calls = {}
assert_false(nightfall.matches({
    has_valid_enemy_target = false,
}, {
    nightfall_active = true,
}), "Nightfall should not match without valid target despite proc")

-- ============================================================================
-- CurseOfDoom: only on long-lived targets (TTD >= 62)
-- ============================================================================

local curse_of_doom = find_strategy("CurseOfDoom")

-- Target known to die soon -> should NOT match
spell_ready_calls = {}
assert_false(curse_of_doom.matches({
    target = {}, has_valid_enemy_target = true,
    ttd_known = true, ttd = 30,
}, {
    doom_remains = 0,
}), "CurseOfDoom should not match when TTD < 62s")

-- Target lives long enough -> should match
spell_ready_calls = {}
assert_true(curse_of_doom.matches({
    target = {}, has_valid_enemy_target = true,
    ttd_known = true, ttd = 90,
}, {
    doom_remains = 0,
}), "CurseOfDoom should match when TTD >= 62s")

-- Doom already applied with time remaining -> should NOT match
spell_ready_calls = {}
assert_false(curse_of_doom.matches({
    target = {}, has_valid_enemy_target = true,
    ttd_known = true, ttd = 90,
}, {
    doom_remains = 30,
}), "CurseOfDoom should not match when already applied")

-- No target -> should NOT match
assert_false(curse_of_doom.matches({
    target = nil,
    has_valid_enemy_target = false,
}, {
    doom_remains = 0,
}), "CurseOfDoom should not match without target")

-- ============================================================================
-- CurseOfAgony: short TTD gate, CoE conflict in groups
-- ============================================================================

local curse_of_agony = find_strategy("CurseOfAgony")

-- Target dies too soon -> should NOT match
spell_ready_calls = {}
assert_false(curse_of_agony.matches({
    has_valid_enemy_target = true,
    target = {}, is_group = false,
    ttd_known = true, ttd = 5,
}, {
    agony_remains = 0, coe_remains = 0,
}), "CurseOfAgony should not match when TTD < 8s")

-- Group with CoE active -> should NOT match (one curse per target)
spell_ready_calls = {}
assert_false(curse_of_agony.matches({
    has_valid_enemy_target = true,
    target = {}, is_group = true,
    ttd_known = true, ttd = 30,
}, {
    agony_remains = 0, coe_remains = 30,
}), "CurseOfAgony should not match when CoE is active in group")

-- Solo, long TTD, no CoE -> should match
spell_ready_calls = {}
assert_true(curse_of_agony.matches({
    has_valid_enemy_target = true,
    target = {}, is_group = false,
    ttd_known = true, ttd = 30,
}, {
    agony_remains = 0, coe_remains = 0, enemy_count = 1,
}), "CurseOfAgony should match solo with long TTD")

-- ============================================================================
-- SeedsOfCorruption: only when enemy count >= threshold
-- ============================================================================

local seed = find_strategy("SeedOfCorruption")

-- Too few enemies -> should NOT match
spell_ready_calls = {}
assert_false(seed.matches({
    has_valid_enemy_target = true,
    settings = { aff_seed_targets = 3 },
}, {
    enemy_count = 2,
}), "SeedOfCorruption should not match with <3 enemies")

-- Enough enemies -> should match
spell_ready_calls = {}
assert_true(seed.matches({
    has_valid_enemy_target = true,
    settings = { aff_seed_targets = 3 },
}, {
    enemy_count = 4,
}), "SeedOfCorruption should match with >=3 enemies")

-- ============================================================================
-- DrainSoul execute: only when target <= 25% HP, not channeling
-- ============================================================================

local drain_soul = find_strategy("DrainSoulExecute")

-- High HP -> should NOT match
spell_ready_calls = {}
assert_false(drain_soul.matches({
    has_valid_enemy_target = true,
    is_channeling = false,
}, {
    target_hp = 50,
}), "DrainSoul should not match when target HP > 25%")

-- Low HP execute range -> should match
spell_ready_calls = {}
assert_true(drain_soul.matches({
    has_valid_enemy_target = true,
    is_channeling = false,
}, {
    target_hp = 20,
}), "DrainSoul should match when target HP <= 25%")

-- Low HP but channeling -> should NOT match
spell_ready_calls = {}
assert_false(drain_soul.matches({
    has_valid_enemy_target = true,
    is_channeling = true,
}, {
    target_hp = 15,
}), "DrainSoul should not match when already channeling")

print("PASS test_affliction_custom_matches")
