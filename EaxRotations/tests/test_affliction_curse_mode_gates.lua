-- test_affliction_curse_mode_gates.lua -- Affliction curse-mode gate tests.
-- WHAT:  regression tests for warlock_curse_mode dropdown in affliction spec.
-- WHEN:  during rotation test suite execution.
-- WHY:   ensures curse mode/assigned curse respect APL-aligned selection.
-- SAFETY: uses synthetic context; no live game data required.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_false
local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
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
    log = function() end,
    time_now = function() return 1000 end,
    cooldown_remains = function(spell, cd) return 0 end,
    rotation_registry = { register = function() end },
}

local orig_pcall = _G.pcall
_G.pcall = function(fn, path, ...)
    if type(path) == "string" then
        if path:find("tbc_data_sylvanas") then return true, { ITEMS = { potions = {} } } end
        if path:find("izi_sdk") then return false, nil end
    end
    return orig_pcall(fn, path, ...)
end

local orig_require = _G.require
_G.require = function(path)
    if type(path) == "string" then
        if path:find("tbc_data_sylvanas") then return { ITEMS = { potions = {} } } end
        if path:find("offensive_dispel") then return {} end
        if path:find("izi_sdk") then return nil end
    end
    return orig_require(path)
end

local result = dofile("EaxRotations/classes/warlock/affliction_sylvanas.lua")
assert_true(result, "affliction module should load")
local strategies = result.strategies
assert_true(strategies, "strategies table should load from result")

_G.require = orig_require
_G.pcall = orig_pcall

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function make_context(mode, group, playstyle, enemy_count, assigned)
    return {
        target = {},
        has_valid_enemy_target = true,
        is_group = group,
        active_playstyle = playstyle,
        enemy_count = enemy_count or 1,
        ttd_known = true,
        ttd = 120,
        settings = { warlock_curse_mode = mode, warlock_assigned_curse = assigned or "none", dot_ttd_threshold = 50 },
    }
end

local function make_state(opts)
    opts = opts or {}
    return {
        agony_remains = opts.agony_remains or 0,
        coe_remains = opts.coe_remains or 0,
        doom_remains = opts.doom_remains or 0,
        recklessness_remains = opts.recklessness_remains or 0,
        weakness_remains = opts.weakness_remains or 0,
        enemy_count = opts.enemy_count or 1,
    }
end

local coa = find_strategy("CurseOfAgony")
local coe = find_strategy("CurseOfElements")
local cod = find_strategy("CurseOfDoom")
local cor = find_strategy("CurseOfRecklessness")
local cow = find_strategy("CurseOfWeakness")

-- Auto mode in group/affliction should prefer Elements (CoE)
spell_ready_calls = {}
assert_false(coa.matches(make_context("auto", true, "affliction", 1), make_state()),
    "CoA should NOT match in auto/group/affliction when select_curse returns elements")
assert_true(coe.matches(make_context("auto", true, "affliction", 1), make_state()),
    "CoE should match in auto/group/affliction when select_curse returns elements")
assert_false(cod.matches(make_context("auto", true, "affliction", 1), make_state()),
    "CoD should NOT match in auto/group/affliction when select_curse returns elements")

-- Explicit elements mode
spell_ready_calls = {}
assert_false(coa.matches(make_context("elements", true, "affliction", 1), make_state()),
    "CoA should NOT match in elements mode")
assert_true(coe.matches(make_context("elements", true, "affliction", 1), make_state()),
    "CoE should match in elements mode")

-- Explicit agony mode
spell_ready_calls = {}
assert_true(coa.matches(make_context("agony", true, "affliction", 1), make_state()),
    "CoA should match in agony mode")
assert_false(coe.matches(make_context("agony", true, "affliction", 1), make_state()),
    "CoE should NOT match in agony mode")

-- Assigned curse overrides auto logic
spell_ready_calls = {}
assert_true(cod.matches(make_context("auto", true, "affliction", 1, "doom"), make_state()),
    "CoD should match when assigned curse is doom")
assert_false(coa.matches(make_context("auto", true, "affliction", 1, "doom"), make_state()),
    "CoA should NOT match when assigned curse is doom")

-- Recklessness and Weakness modes
spell_ready_calls = {}
assert_true(cor.matches(make_context("recklessness", true, "affliction", 1), make_state()),
    "CoR should match in recklessness mode")
assert_true(cow.matches(make_context("weakness", true, "affliction", 1), make_state()),
    "CoW should match in weakness mode")

print("PASS test_affliction_curse_mode_gates")
