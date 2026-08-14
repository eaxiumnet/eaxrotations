-- test_combat_wotlk_dsl_priority.lua  WotLK Combat DSL priority order validation.
-- WHAT:  Asserts the declarative DSL strategies appear in the correct priority order
--        and that key match/no-match gates behave correctly under mocked combat state.
-- WHEN:  Runs as part of the WotLK rotation test suite.
-- WHY:   Regression guard for the WotLK DSL adoption  ensures declarative conditions
--        produce the same behavior as the original imperative match functions.
-- SAFETY: Uses synthetic context/state; no live game data required.

-- Validates the 6 strategies in the DSL_DEFS table (incl. baseline Kick).

local mock_ns = {
    GetPlayer = function() return nil end,
    me = nil,
    rotation_registry = {
        register = function(self, name, strategies, opts) end,
    },
    log = function(msg) end,
    buff_up = function() return false end,
    buff_remains = function() return 0 end,
    spell_ready = function(id) return true end,
    should_use_long_cd = function() return true end,
    RogueSpells = {
        SliceAndDice = 5171,
        SinisterStrike = 1752,
        Eviscerate = 2098,
        BladeFlurry = 13877,
        KillingSpree = 51690,
    },
    spec_kit = nil,
}
_G.EaxRotations = mock_ns

local _mock_spec_kit = {
    merge_state = dofile("EaxRotations/tests/spec_kit_merge_state.lua").merge_state,
    define_action_for_class = function(spells)
        return function(name, ids, label)
            local id = type(ids) == "table" and ids[1] or ids
            return { cast_safe = function(self, target) return true end, spell_id = id, cooldown_remaining = function() return 0 end }
        end
    end,
    -- Plain define_action (fire_wotlk precedent): the wotlk spec files resolve
    -- actions through this instead of define_action_for_class so the file-local
    -- WotLK rank lists are not shadowed by the TBC-era class spell tables.
    define_action = function(spell_field, ids, label)
        local id = type(ids) == "table" and ids[1] or ids
        return { cast_safe = function(self, target) return true end, spell_id = id, cooldown_remaining = function() return 0 end }
    end,
    safe_state = function(tbl)
        local mt = {
            __index = function(_, key)
                local defaults = { hp=100, energy=0, combo_points=0, target_hp=100, enemy_count=0, snd_remains=0, snd_active=false, blade_flurry_ready=false, killing_spree_ready=false, in_combat=false }
                return defaults[key] or 0
            end
        }
        return setmetatable({}, mt)
    end,
    setting = function(ctx, key, fallback) return fallback end,
}
_G.EaxRotations.spec_kit = _mock_spec_kit

package.preload["shared/spec_kit_sylvanas"] = function() return _mock_spec_kit end
-- combat_wotlk requires the combo-point reader at load (real CD/energy reads
-- via NS); the real module is dependency-free, so load the genuine file.
package.preload["shared/combo_points_reader_sylvanas"] = function()
    return dofile("EaxRotations/shared/combo_points_reader_sylvanas.lua")
end
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
                            if cond.op == "<=" and (val or 0) > (cond.value or 0) then return false end
                            if cond.op == ">=" and (val or 0) < (cond.value or 0) then return false end
                            if cond.op == ">" and (val or 0) <= (cond.value or 0) then return false end
                            if cond.op == "truthy" and not val then return false end
                            if cond.op == "falsy" and val ~= false and val ~= nil and val ~= 0 then return false end
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

local ok, mod = pcall(require, "EaxRotations.classes.rogue.combat_wotlk")
if not ok or not mod then
    error("Failed to load combat_wotlk module: " .. tostring(ok))
end

local strategies = mod.strategies
local build_state = mod.build_state

local tests = {}
local passed = 0
local failed = 0

function tests.priority_order()
    -- wowsims combat APL order (ui/rogue/apls/combat.apl.json): SnD > Eviscerate > BladeFlurry > KillingSpree > SinisterStrike.
    -- Kick is a baseline interrupt NOT in the fixture — first, outside the pinned order.
    local expected = { "Kick", "SliceAndDice", "Eviscerate", "BladeFlurry", "KillingSpree", "SinisterStrike" }
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
        hp = 100, energy = 100, combo_points = 5, target_hp = 100, enemy_count = 1, in_combat = true,
        snd_remains = 0, snd_active = true, blade_flurry_ready = true, killing_spree_ready = true,
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

tests.test_SliceAndDice_matches_when_expiring = test_match("SliceAndDice", { snd_remains = 1, combo_points = 2 }, true)
tests.test_SliceAndDice_does_not_refresh_early = test_match("SliceAndDice", { snd_remains = 2, combo_points = 2 }, false)
tests.test_SliceAndDice_does_not_refresh_after_boundary = test_match("SliceAndDice", { snd_remains = 1.01, combo_points = 2 }, false)
tests.test_SliceAndDice_does_not_match_when_fresh = test_match("SliceAndDice", { snd_remains = 10, combo_points = 2 }, false)
tests.test_SliceAndDice_does_not_match_no_cp = test_match("SliceAndDice", { snd_remains = 1, combo_points = 0 }, false)

-- BladeFlurry: matches when in_combat AND ready AND SnD up AND enemy_count >= 2 AND long_cd ok
tests.test_BladeFlurry_matches = test_match("BladeFlurry", { in_combat = true, blade_flurry_ready = true, snd_active = true, enemy_count = 2 }, true)
tests.test_BladeFlurry_no_combat = test_match("BladeFlurry", { in_combat = false, blade_flurry_ready = true, snd_active = true, enemy_count = 2 }, false)
tests.test_BladeFlurry_not_ready = test_match("BladeFlurry", { in_combat = true, blade_flurry_ready = false, snd_active = true, enemy_count = 2 }, false)
tests.test_BladeFlurry_single_target = test_match("BladeFlurry", { in_combat = true, blade_flurry_ready = true, snd_active = true, enemy_count = 1 }, false)
tests.test_BladeFlurry_no_snd = test_match("BladeFlurry", { in_combat = true, blade_flurry_ready = true, snd_active = false, enemy_count = 2 }, false)

-- KillingSpree: matches when in_combat AND ready AND energy <= 50 AND long_cd ok
tests.test_KillingSpree_matches = test_match("KillingSpree", { in_combat = true, killing_spree_ready = true, energy = 40 }, true)
tests.test_KillingSpree_no_combat = test_match("KillingSpree", { in_combat = false, killing_spree_ready = true, energy = 40 }, false)
tests.test_KillingSpree_not_ready = test_match("KillingSpree", { in_combat = true, killing_spree_ready = false, energy = 40 }, false)
tests.test_KillingSpree_high_energy = test_match("KillingSpree", { in_combat = true, killing_spree_ready = true, energy = 60 }, false)

-- Eviscerate: matches when combo_points >= 4
tests.test_Eviscerate_matches_when_enough_cp = test_match("Eviscerate", { combo_points = 4 }, true)
tests.test_Eviscerate_does_not_match_low_cp = test_match("Eviscerate", { combo_points = 2 }, false)

-- SinisterStrike: matches when energy >= 45
tests.test_SinisterStrike_matches_when_enough_energy = test_match("SinisterStrike", { energy = 45 }, true)
tests.test_SinisterStrike_does_not_match_low_energy = test_match("SinisterStrike", { energy = 30 }, false)

-- Kick (baseline interrupt): matches when in_combat AND target is casting
tests.test_Kick_matches_when_casting = test_match("Kick", { in_combat = true, target_is_casting = true }, true)
tests.test_Kick_no_cast = test_match("Kick", { in_combat = true, target_is_casting = false }, false)
tests.test_Kick_no_combat = test_match("Kick", { in_combat = false, target_is_casting = true }, false)

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
