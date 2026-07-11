-- test_destruction_curse_mode_gates.lua -- Destruction curse-mode gate tests.
-- WHAT:  regression tests for warlock_curse_mode dropdown in destruction spec.
-- WHEN:  during rotation test suite execution.
-- WHY:   ensures Curse of Elements/Agony/Doom respect the curse mode setting.
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

local function make_context(mode, group)
    return {
        target = {},
        is_group = group,
        party_size = group and 2 or 1,
        ttd_known = true,
        ttd = 120,
        settings = { warlock_curse_mode = mode },
    }
end

local function make_state(opts)
    opts = opts or {}
    return {
        coa_remains = opts.coa_remains or 0,
        coe_remains = opts.coe_remains or 0,
        cod_remains = opts.cod_remains or 0,
    }
end

local coa = find_strategy("CurseOfAgony")
local coe = find_strategy("CurseOfElements")
local cod = find_strategy("CurseOfDoom")

-- Auto mode in group should prefer Agony
assert_true(coa.matches(make_context("auto", true), make_state()),
    "CoA should match in auto/group")
assert_false(coe.matches(make_context("auto", true), make_state()),
    "CoE should NOT match in auto/group when select_curse returns agony")

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

-- Doom mode gates
assert_false(cod.matches(make_context("agony", true), make_state()),
    "CoD should NOT match in agony mode")
assert_true(cod.matches(make_context("doom", true), make_state()),
    "CoD should match in doom mode")
assert_false(cod.matches(make_context("auto", true), make_state()),
    "CoD should NOT match in auto mode when select_curse returns agony")

print("PASS test_destruction_curse_mode_gates")
