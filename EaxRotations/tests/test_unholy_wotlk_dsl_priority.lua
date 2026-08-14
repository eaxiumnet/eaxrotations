-- test_unholy_wotlk_dsl_priority.lua  WotLK Unholy DSL priority order validation.
-- WHAT:  Asserts the declarative DSL strategies appear in the correct priority order
--        and that key match/no-match gates behave correctly under mocked combat state.
-- WHEN:  Runs as part of the WotLK rotation test suite.
-- WHY:   Regression guard for the WotLK DSL adoption  ensures declarative conditions
--        produce the same behavior as the original imperative match functions.
-- SAFETY: Uses synthetic context/state; no live game data required.

-- Validates the 13 declarative strategies in the DSL_DEFS table.

-- Bootstrap: minimal mock environment so the spec module loads without crashing.
-- We do NOT load mock_sylvanas.lua because the WotLK spec files reference
-- api/ modules (NS.GetPlayer, NS.spell_ready, NS.buff_up, etc.) that require
-- the full Sylvanas runtime. Instead we set up a minimal _G.EaxRotations with
-- the stubs needed by build_state() and the DSL substitution loop at load time.
local mock_ns = {
    GetPlayer = function() return nil end,
    me = nil,
    rotation_registry = {
        register = function(self, name, strategies, opts) end,
    },
    log = function(msg) end,
    is_wotlk = function() return true end,
    buff_up = function() return false end,
    debuff_remains = function() return 0 end,
    has_pet = function() return false end,
    spell_ready = function(id) return true end,
    aoe_target_meets = function() return false end,
    should_use_long_cd = function() return true end,
    AOE_RADIUS = { TARGET_10 = 10, GROUND_10 = 10 },
    DeathKnightSpells = {
        IcyTouch          = 45477,
        PlagueStrike      = 49917,
        ScourgeStrike     = 55090,
        BloodStrike       = 45902,
        DeathCoil         = 47541,
        Pestilence        = 50842,
        DeathAndDecay     = 43265,
        SummonGargoyle    = 49206,
        HornOfWinter      = 57330,
        EmpowerRuneWeapon = 47568,
        BoneShield        = 49222,
        RaiseDead         = 46584,
        BloodPresence     = 48266,
        FrostPresence     = 48263,
        UnholyPresence    = 48265,
    },
    DeathKnightConstants = {
        FROST_FEVER_DEBUFF  = { 55095 },
        BLOOD_PLAGUE_DEBUFF = { 55078 },
        HORN_OF_WINTER_BUFF = { 57330, 57623 },
    },
    spec_kit = nil,
}
_G.EaxRotations = mock_ns

-- Mock shared modules before loading spec file
local _mock_spec_kit = {
    merge_state = dofile("EaxRotations/tests/spec_kit_merge_state.lua").merge_state,
    define_action_for_class = function(spells)
        return function(name, ids, label)
            local id = type(ids) == "table" and ids[1] or ids
            return { cast_safe = function(self, target) return true end, spell_id = id }
        end
    end,
    safe_state = function(tbl)
        local mt = {
            __index = function(_, key)
                local defaults = { hp=100, mana_pct=100, target_hp=100, enemy_count=0, runic_power=0, horn_of_winter_up=false, bone_shield_up=false, pet_present=false, is_boss=false }
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
    -- Minimal DSL that compiles strategies with match function + execute from DSL_DEFS
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
                            if cond.op == ">=" and (val or 0) < (cond.value or 0) then return false end
                            if cond.op == ">" and (val or 0) <= (cond.value or 0) then return false end
                            if cond.op == "<" and (val or 0) >= (cond.value or 0) then return false end
                            if cond.op == "<=" and (val or 0) > (cond.value or 0) then return false end
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
package.preload["shared/rune_manager_sylvanas"] = function()
    return { get_runic_power = function() return 0 end, get_rune_state = function() return { ready = { blood=0, frost=0, unholy=0, death=0 } } end }
end
package.preload["shared/presence_manager_sylvanas"] = function()
    return {
        get_optimal_presence = function() return nil end,
        should_switch_presence = function() return false end,
    }
end
package.preload["shared/interrupt_manager_sylvanas"] = function()
    return {
        register_interrupt_spell = function(class, name, spells)
            return { name = "MindFreeze", matches = function() return false end, execute = function() return false end }
        end,
    }
end
package.preload["shared/aoe_hit_volume_sylvanas"] = function()
    return { install = function(ns) end }
end

-- Load the spec module
local ok, mod = pcall(require, "EaxRotations.classes.deathknight.unholy_wotlk")
if not ok or not mod then
    error("Failed to load unholy_wotlk module: " .. tostring(ok))
end

local strategies = mod.strategies
local build_state = mod.build_state

-- Test framework
local tests = {}
local passed = 0
local failed = 0

function tests.priority_order()
    -- Verify strategy order: interrupt -> HornOfWinter -> BoneShield -> Presence -> RaiseDead -> SummonGargoyle -> EmpowerRuneWeapon -> IcyTouch -> PlagueStrike -> Pestilence -> DeathCoil -> DeathAndDecay -> ScourgeStrike -> BloodStrike -> DeathCoilDump -> GhoulGnaw -> GhoulLeap
    -- (GhoulGnaw/GhoulLeap appended 2026-08-13 after DeathCoilDump — pin-safe:
    -- unholy is pinned only for PlagueStrike < ScourgeStrike < BloodStrike(occ2)
    -- < DeathCoilDump; the pet lanes sit below the resolved strategies.)
    local expected = { "MindFreeze", "HornOfWinter", "BoneShield", "Presence", "RaiseDead", "SummonGargoyle", "EmpowerRuneWeapon", "IcyTouch", "PlagueStrike", "Pestilence", "DeathCoil", "DeathAndDecay", "ScourgeStrike", "BloodStrike", "DeathCoilDump", "GhoulGnaw", "GhoulLeap" }
    for i, name in ipairs(expected) do
        local s = strategies[i]
        if not s then return false, "missing strategy at position " .. i .. " (expected " .. name .. ")" end
        if s.name ~= name then return false, "position " .. i .. ": expected " .. name .. " but got " .. (s.name or "nil") end
    end
    return true
end

-- Helper: create a context + state with overrides
local function make_state(overrides)
    local ctx = { in_combat = true, target = {}, enemy_count = 1 }
    local raw = {
        hp = 100, target_hp = 100, enemy_count = 1, in_combat = true,
        frost_fever_remains = 0, blood_plague_remains = 0,
        horn_of_winter_up = false, bone_shield_up = false,
        runic_power = 0, pet_present = false, is_boss = false,
        rune_ready = { blood = 0, frost = 0, unholy = 0, death = 0 },
    }
    for k, v in pairs(overrides or {}) do raw[k] = v end
    return ctx, raw
end

-- Match tests for each strategy (except interrupt and Presence which remain manual)
local function test_match(name, context, state_overrides, expected)
    return function()
        local ctx, raw = make_state(state_overrides)
        local state = raw -- use raw state for test determinism
        for _, s in ipairs(strategies) do
            if s.name == name then
                if not s.matches then return false, "strategy " .. name .. " has no matches function" end
                local result = s.matches(ctx, state)
                if result ~= expected then
                    return false, name .. ": expected " .. tostring(expected) .. " but got " .. tostring(result)
                end
                return true
            end
        end
        return false, "strategy " .. name .. " not found"
    end
end

-- HornOfWinter: matches when horn_of_winter_up is falsy
tests.test_HornOfWinter_matches_when_down = test_match("HornOfWinter", nil, { horn_of_winter_up = false }, true)
tests.test_HornOfWinter_does_not_match_when_up = test_match("HornOfWinter", nil, { horn_of_winter_up = true }, false)

-- BoneShield: matches when bone_shield_up is falsy
tests.test_BoneShield_matches_when_down = test_match("BoneShield", nil, { bone_shield_up = false }, true)
tests.test_BoneShield_does_not_match_when_up = test_match("BoneShield", nil, { bone_shield_up = true }, false)

-- RaiseDead: matches when pet_present is falsy
tests.test_RaiseDead_matches_when_no_pet = test_match("RaiseDead", nil, { pet_present = false }, true)
tests.test_RaiseDead_does_not_match_when_pet = test_match("RaiseDead", nil, { pet_present = true }, false)

-- SummonGargoyle: matches when is_boss truthy AND runic_power >= 60
tests.test_SummonGargoyle_matches_when_boss_and_rp = test_match("SummonGargoyle", nil, { is_boss = true, runic_power = 60 }, true)
tests.test_SummonGargoyle_does_not_match_when_not_boss = test_match("SummonGargoyle", nil, { is_boss = false, runic_power = 80 }, false)
tests.test_SummonGargoyle_does_not_match_when_low_rp = test_match("SummonGargoyle", nil, { is_boss = true, runic_power = 40 }, false)

-- EmpowerRuneWeapon: matches when all runes are spent (total == 0)
tests.test_EmpowerRuneWeapon_matches_when_no_runes = test_match("EmpowerRuneWeapon", nil, { rune_ready = { blood = 0, frost = 0, unholy = 0, death = 0 } }, true)
tests.test_EmpowerRuneWeapon_does_not_match_with_runes = test_match("EmpowerRuneWeapon", nil, { rune_ready = { blood = 1, frost = 1, unholy = 1, death = 0 } }, false)

-- IcyTouch: matches when frost_fever_remains < 3
tests.test_IcyTouch_matches_when_ff_expiring = test_match("IcyTouch", nil, { frost_fever_remains = 2 }, true)
tests.test_IcyTouch_does_not_match_when_ff_fresh = test_match("IcyTouch", nil, { frost_fever_remains = 5 }, false)

-- PlagueStrike: matches when blood_plague_remains < 3
tests.test_PlagueStrike_matches_when_bp_expiring = test_match("PlagueStrike", nil, { blood_plague_remains = 2 }, true)
tests.test_PlagueStrike_does_not_match_when_bp_fresh = test_match("PlagueStrike", nil, { blood_plague_remains = 5 }, false)

-- DeathCoil: matches when runic_power >= 100 (overcap)
tests.test_DeathCoil_matches_when_overcap = test_match("DeathCoil", nil, { runic_power = 100 }, true)
tests.test_DeathCoil_does_not_match_when_below = test_match("DeathCoil", nil, { runic_power = 60 }, false)

-- ScourgeStrike: matches when both diseases are up (> 0 remains)
tests.test_ScourgeStrike_matches_when_diseases_up = test_match("ScourgeStrike", nil, { frost_fever_remains = 5, blood_plague_remains = 5 }, true)
tests.test_ScourgeStrike_does_not_match_when_ff_missing = test_match("ScourgeStrike", nil, { frost_fever_remains = 0, blood_plague_remains = 5 }, false)

-- BloodStrike: unconditional (always matches)
tests.test_BloodStrike_always_matches = test_match("BloodStrike", nil, {}, true)

-- DeathCoilDump: matches when runic_power >= 40
tests.test_DeathCoilDump_matches_when_enough_rp = test_match("DeathCoilDump", nil, { runic_power = 40 }, true)
tests.test_DeathCoilDump_does_not_match_when_low_rp = test_match("DeathCoilDump", nil, { runic_power = 20 }, false)

-- Run all tests
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
