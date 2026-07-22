-- test_discipline_wotlk_dsl_priority.lua — WotLK Discipline DSL priority order validation.
-- WHAT:  Asserts the declarative DSL strategies appear in the correct priority order
--        and that key match/no-match gates behave correctly under mocked combat state.
-- WHEN:  Runs as part of the WotLK rotation test suite.
-- WHY:   Regression guard for the WotLK DSL adoption — ensures declarative conditions
--        produce the same behavior as the original imperative match functions.
-- SAFETY: Uses synthetic context/state; no live game data required.

-- Validates the 4 declarative strategies in the DSL_DEFS table.

local mock_ns = {
    GetPlayer = function() return nil end,
    me = nil,
    rotation_registry = {
        register = function(self, name, strategies, opts) end,
    },
    log = function(msg) end,
    buff_up = function() return false end,
    buff_remains = function() return 0 end,
    debuff_up = function() return false end,
    spell_ready = function(id) return true end,
    PriestSpells = {
        PowerWordShield = 17,
        Penance = 47540,
        PrayerofMending = 33076,
        Renew = 139,
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
                local defaults = { hp=100, mana_pct=100, target_hp=100, enemy_count=0, weakened_soul_up=false, renew_remains=0 }
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
                            if cond.op == "falsy" and val ~= false and val ~= nil and val ~= 0 then return false end
                            if cond.op == "truthy" and not val then return false end
                            if cond.op == "<" and (val or 0) >= (cond.value or 0) then return false end
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

local ok, mod = pcall(require, "EaxRotations.classes.priest.discipline_wotlk")
if not ok or not mod then
    error("Failed to load discipline_wotlk module: " .. tostring(ok))
end

local strategies = mod.strategies
local build_state = mod.build_state

local tests = {}
local passed = 0
local failed = 0

function tests.priority_order()
    local expected = { "PowerWordShield", "Penance", "PrayerOfMending", "Renew" }
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
        weakened_soul_up = false, renew_remains = 0,
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

-- PowerWordShield: matches when weakened_soul_up is falsy
tests.test_PWS_matches_when_no_weakened = test_match("PowerWordShield", { weakened_soul_up = false }, true)
tests.test_PWS_does_not_match_when_weakened = test_match("PowerWordShield", { weakened_soul_up = true }, false)

-- Penance: unconditional (always matches)
tests.test_Penance_always_matches = test_match("Penance", {}, true)

-- PrayerOfMending: unconditional (always matches)
tests.test_PrayerOfMending_always_matches = test_match("PrayerOfMending", {}, true)

-- Renew: matches when renew_remains < 3
tests.test_Renew_matches_when_expiring = test_match("Renew", { renew_remains = 2 }, true)
tests.test_Renew_does_not_match_when_fresh = test_match("Renew", { renew_remains = 10 }, false)

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
