-- test_affliction_wotlk_dsl_priority.lua — WotLK Affliction DSL priority order validation.
-- WHAT:  Asserts the declarative DSL strategies appear in the correct priority order
--        and that key match/no-match gates behave correctly under mocked combat state.
-- WHEN:  Runs as part of the WotLK rotation test suite.
-- WHY:   Regression guard for the WotLK DSL adoption — ensures declarative conditions
--        produce the same behavior as the original imperative match functions.
-- SAFETY: Uses synthetic context/state; no live game data required.

-- Validates the 6 declarative strategies in the DSL_DEFS table.

local mock_ns = {
    GetPlayer = function() return nil end,
    me = nil,
    rotation_registry = {
        register = function(self, name, strategies, opts) end,
    },
    log = function(msg) end,
    debuff_remains = function() return 0 end,
    spell_ready = function(id) return true end,
    WarlockSpells = {
        UnstableAffliction = 30108,
        Haunt = 48181,
        Corruption = 172,
        CurseOfAgony = 980,
        DrainSoul = 1120,
        ShadowBolt = 686,
    },
    spec_kit = nil,
}
_G.EaxRotations = mock_ns

local _mock_spec_kit = {
    define_action_for_class = function(spells)
        return function(name, ids, label)
            local id = type(ids) == "table" and ids[1] or ids
            return { cast_safe = function(self, target) return true end, spell_id = id }
        end
    end,
    safe_state = function(tbl)
        local mt = {
            __index = function(_, key)
                local defaults = { hp=100, mana_pct=100, target_hp=100, enemy_count=0, unstable_remains=0, haunt_remains=0, corruption_remains=0, agony_remains=0 }
                return defaults[key] or 0
            end
        }
        return setmetatable({}, mt)
    end,
    setting = function(ctx, key, fallback) return fallback end,
}
_G.EaxRotations.spec_kit = _mock_spec_kit

package.preload["shared/spec_kit_sylvanas"] = function() return _mock_spec_kit end
package.preload["shared/strategy_dsl_sylvanas"] = function()
    local dsl = {
        compile_strategy = function(defn, opts)
            local conditions = defn.conditions or {}
            return {
                name = defn.name,
                matches = function(context, state)
                    for _, cond in ipairs(conditions) do
                        if cond.type == "state" then
                            local val = state[cond.field]
                            if cond.op == "<" and (val or 0) >= (cond.value or 0) then return false end
                            if cond.op == ">=" and (val or 0) < (cond.value or 0) then return false end
                        elseif cond.type == "custom" and cond.fn then
                            if not cond.fn(context, state) then return false end
                        end
                    end
                    return true
                end,
                execute = function(ctx)
                    local spell = defn.action and defn.action.spell
                    if spell and spell.cast_safe then return spell:cast_safe() end
                    return false
                end,
            }
        end,
    }
    return dsl
end

local ok, mod = pcall(require, "EaxRotations.classes.warlock.affliction_wotlk")
if not ok or not mod then
    error("Failed to load affliction_wotlk module: " .. tostring(ok))
end

local strategies = mod.strategies
local build_state = mod.build_state

local tests = {}
local passed = 0
local failed = 0

function tests.priority_order()
    local expected = { "Haunt", "UnstableAffliction", "Corruption", "CurseOfAgony", "DrainSoul", "ShadowBolt" }
    for i, name in ipairs(expected) do
        local s = strategies[i]
        if not s then return false, "missing strategy at position " .. i .. " (expected " .. name .. ")" end
        if s.name ~= name then return false, "position " .. i .. ": expected " .. name .. " but got " .. (s.name or "nil") end
    end
    return true
end

local function make_state(overrides)
    local ctx = { in_combat = true, target = {}, enemy_count = 1 }
    local raw = {
        hp = 100, mana_pct = 100, target_hp = 100, enemy_count = 1, in_combat = true,
        unstable_remains = 0, haunt_remains = 0, corruption_remains = 0, agony_remains = 0,
    }
    for k, v in pairs(overrides or {}) do raw[k] = v end
    return ctx, raw
end

local function test_match(name, state_overrides, expected)
    return function()
        local ctx, raw = make_state(state_overrides)
        for _, s in ipairs(strategies) do
            if s.name == name then
                if not s.matches then return false, "strategy " .. name .. " has no matches function" end
                local result = s.matches(ctx, raw)
                if result ~= expected then
                    return false, name .. ": expected " .. tostring(expected) .. " but got " .. tostring(result)
                end
                return true
            end
        end
        return false, "strategy " .. name .. " not found"
    end
end

-- Haunt: matches when haunt_remains < 3
tests.test_Haunt_matches_when_expiring = test_match("Haunt", { haunt_remains = 2 }, true)
tests.test_Haunt_does_not_match_when_fresh = test_match("Haunt", { haunt_remains = 10 }, false)

-- UnstableAffliction: matches when unstable_remains < 3
tests.test_UA_matches_when_expiring = test_match("UnstableAffliction", { unstable_remains = 2 }, true)
tests.test_UA_does_not_match_when_fresh = test_match("UnstableAffliction", { unstable_remains = 10 }, false)

-- Corruption: matches when corruption_remains < 3
tests.test_Corruption_matches_when_expiring = test_match("Corruption", { corruption_remains = 2 }, true)
tests.test_Corruption_does_not_match_when_fresh = test_match("Corruption", { corruption_remains = 10 }, false)

-- CurseOfAgony: matches when agony_remains < 3
tests.test_CoA_matches_when_expiring = test_match("CurseOfAgony", { agony_remains = 2 }, true)
tests.test_CoA_does_not_match_when_fresh = test_match("CurseOfAgony", { agony_remains = 10 }, false)

-- DrainSoul: matches when target_hp < 25
tests.test_DrainSoul_matches_when_execute = test_match("DrainSoul", { target_hp = 20 }, true)
tests.test_DrainSoul_does_not_match_when_high = test_match("DrainSoul", { target_hp = 50 }, false)

-- ShadowBolt: matches when mana_pct >= 20
tests.test_ShadowBolt_matches_when_mana_ok = test_match("ShadowBolt", { mana_pct = 50 }, true)
tests.test_ShadowBolt_does_not_match_when_low = test_match("ShadowBolt", { mana_pct = 10 }, false)

for name, fn in pairs(tests) do
    local ok, err = pcall(fn)
    if ok and err == true then
        passed = passed + 1
        io.write(".")
    else
        failed = failed + 1
        io.write("F")
        local msg = type(err) == "string" and err or (type(err) == "table" and (err[2] or "unknown") or "unknown")
        io.write(" [" .. name .. ": " .. tostring(msg) .. "]")
    end
end

io.write("\n")
io.write(string.format("Results: %d/%d passed, %d failed\n", passed, passed + failed, failed))

if failed > 0 then
    os.exit(1)
end
