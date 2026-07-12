-- test_destruction_curse_mode_gates.lua -- Destruction curse-mode gate tests.
-- WHAT:  regression tests for warlock_curse_mode dropdown in destruction spec.
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

local action_calls = {}
_G.EaxRotations = {
    WarlockSpells = {},
    spell_action = function(spell_ids, name) return { spell = spell_ids, name = name } end,
    is_spell_learned = function(id) return true end,
    spell_ready = function(spell, target, opts) return true end,
    should_use_long_cd = function(context, cd) return true end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local orig_require = _G.require
_G.require = function(path)
    if type(path) == "string" and path:find("spec_kit_sylvanas") then
        return {
            define_action_for_class = function(_)
                return function(_, ids, name) return { ids = ids, name = name } end
            end,
            setting = function(ctx, key, default)
                local s = (ctx and ctx.settings) or {}
                return s[key] or default
            end,
            setting_number = function(ctx, key, default)
                local s = (ctx and ctx.settings) or {}
                return s[key] or default
            end,
            setting_bool = function(ctx, key, default)
                local s = (ctx and ctx.settings) or {}
                local v = s[key]
                if v == nil then return default end
                return v
            end,
            safe_state = function(raw, schema) return raw end,
        }
    end
    return orig_require(path)
end

local result = dofile("EaxRotations/classes/warlock/destruction_sylvanas.lua")
assert_true(result, "destruction module should load")
local strategies = result.strategies
assert_true(strategies, "strategies table should load")

_G.require = orig_require

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function make_context(mode, group, assigned, physical_dps_count)
    return {
        target = {},
        is_group = group,
        party_size = group and 2 or 1,
        physical_dps_count = physical_dps_count or 0,
        ttd_known = true,
        ttd = 120,
        settings = { warlock_curse_mode = mode, warlock_assigned_curse = assigned or "none", warlock_curse_reck_threshold = 2 },
    }
end

local function make_state(opts)
    opts = opts or {}
    return {
        coa_remains = opts.coa_remains or 0,
        coe_remains = opts.coe_remains or 0,
        cod_remains = opts.cod_remains or 0,
        recklessness_remains = opts.recklessness_remains or 0,
        weakness_remains = opts.weakness_remains or 0,
    }
end

local coa = find_strategy("CurseOfAgony")
local coe = find_strategy("CurseOfElements")
local cod = find_strategy("CurseOfDoom")
local cor = find_strategy("CurseOfRecklessness")
local cow = find_strategy("CurseOfWeakness")

-- Auto mode in group should prefer Doom (personal DPS default)
assert_false(coa.matches(make_context("auto", true), make_state()),
    "CoA should NOT match in auto/group when select_curse returns doom")
assert_false(coe.matches(make_context("auto", true), make_state()),
    "CoE should NOT match in auto/group when select_curse returns doom")
assert_true(cod.matches(make_context("auto", true), make_state()),
    "CoD should match in auto/group when select_curse returns doom")

assert_false(coe.matches(make_context("auto", true, nil, 0, 5), make_state()),
    "CoE should NOT auto-match in group just because caster_count is high")

-- Explicit elements mode
assert_false(coa.matches(make_context("elements", true), make_state()),
    "CoA should NOT match in elements mode")
assert_true(coe.matches(make_context("elements", true), make_state()),
    "CoE should match in elements mode")

-- Explicit agony mode
assert_true(coa.matches(make_context("agony", true), make_state()),
    "CoA should match in agony mode")
assert_false(coe.matches(make_context("agony", true), make_state()),
    "CoE should NOT match in agony mode")

-- Assigned curse overrides auto logic
assert_true(coe.matches(make_context("auto", true, "elements"), make_state()),
    "CoE should match when assigned curse is elements")
assert_false(cod.matches(make_context("auto", true, "elements"), make_state()),
    "CoD should NOT match when assigned curse is elements")

-- Recklessness and Weakness modes
assert_true(cor.matches(make_context("recklessness", true), make_state()),
    "CoR should match in recklessness mode")
assert_true(cow.matches(make_context("weakness", true), make_state()),
    "CoW should match in weakness mode")

-- Assigned curse overrides group-only gate in solo
assert_true(coe.matches(make_context("auto", false, "elements"), make_state()),
    "CoE should match in solo when assigned curse is elements")
assert_true(cor.matches(make_context("auto", false, "recklessness"), make_state()),
    "CoR should match in solo when assigned curse is recklessness")
assert_true(cow.matches(make_context("auto", false, "weakness"), make_state()),
    "CoW should match in solo when assigned curse is weakness")

assert_true(cor.matches(make_context("auto", true, nil, 2), make_state()),
    "CoR should match in auto when physical_dps_count >= warlock_curse_reck_threshold")

print("PASS test_destruction_curse_mode_gates")
