-- test_leveling_compliance.lua -- Phase 2 compliance: leveling file standardization audit.
-- WHAT:  verifies that all 9 class leveling files meet the canonical contract:
--          (a) Module loads without errors
--          (b) Registers "leveling" playstyle with rotation_registry
--          (c) Exposes build_state / get_state
--          (d) Return shape includes strategies (array or .strategies field)
--          (e) Registration is guarded (won't crash if registry missing)
-- WHEN:  run as standalone test or via run_leveling_tests.lua.
-- WHY:   locks the leveling standardization contract; prevents drift.
-- SAFETY: pure mock-based static analysis; no engine API calls.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_not_nil(v, label) if v == nil then error(label or "assert_not_nil failed", 2) end end

local passed = 0
local failed = 0
local issues = {}

local function add_issue(class, rule, detail)
    issues[#issues + 1] = string.format("%s :: %s :: %s", class, rule, detail)
end

-- ============================================================================
-- Build mock environment
-- ============================================================================

local function build_mock_env(class_name, spell_keys)
    local NS = {}
    local core = {}

    core.time = function() return 100 end
    core.game_time = function() return 100000 end
    core.spell_book = {
        get_spell_cooldown = function() return 0 end,
        get_global_cooldown = function() return 0 end,
        is_spell_learned = function() return true end,
    }
    core.input = { cast_target_spell = function() return true end }

    NS.log = function() end
    NS.log_warning = function() end
    NS.spell_ready = function(spell) return spell ~= nil end
    NS.spell_exists = function() return true end
    NS.try_cast = function(spell) return spell ~= nil end
    NS.get_local_player = function()
        return {
            is_valid = function() return true end,
            has_buff = function() return false end,
            get_power = function() return 100 end,
            get_health = function() return 8000 end,
            get_max_health = function() return 10000 end,
            get_mana = function() return 5000 end,
            get_max_mana = function() return 10000 end,
            is_in_combat = function() return false end,
            get_target = function()
                return {
                    is_valid = function() return true end,
                    get_health = function() return 8000 end,
                    get_max_health = function() return 10000 end,
                    is_casting = function() return false end,
                    is_alive = function() return true end,
                    get_guid = function() return "mock-target" end,
                }
            end,
        }
    end
    NS.get_target = function()
        return {
            is_valid = function() return true end,
            get_health = function() return 8000 end,
            get_max_health = function() return 10000 end,
            is_casting = function() return false end,
            is_alive = function() return true end,
            get_guid = function() return "mock-target" end,
        }
    end
    NS.get_distance = function() return 10 end
    NS.debuff_remains = function() return 0 end
    NS.buff_remains = function() return 0 end
    NS.debuff_stacks = function() return 0 end
    NS.buff_up = function() return false end
    NS.combo_points = 0
    NS.energy = 100

    -- rotation_registry mock
    NS.rotation_registry = {
        _registrations = {},
        register = function(self, key, strategies, opts)
            self._registrations[key] = { strategies = strategies, opts = opts }
        end,
        set_class_config = function(self, config) end,
    }

    -- Build minimal spell table
    local spell_table = {}
    if spell_keys then
        for i, key in ipairs(spell_keys) do
            spell_table[key] = { 1000 + i }
        end
    end
    NS[class_name .. "Spells"] = spell_table

    _G.core = core
    _G.EaxRotations = NS

    return NS
end

-- ============================================================================
-- Test each class
-- ============================================================================

local classes = {
    { name = "Druid",   path = "EaxRotations/classes/druid/leveling_sylvanas.lua",   spells = {"MarkOfTheWild","Thorns","Moonfire","Wrath"} },
    { name = "Hunter",  path = "EaxRotations/classes/hunter/leveling_sylvanas.lua",  spells = {"AspectOfTheHawk","SerpentSting","ArcaneShot"} },
    { name = "Mage",    path = "EaxRotations/classes/mage/leveling_sylvanas.lua",    spells = {"Frostbolt","FireBlast","ArcaneMissiles"} },
    { name = "Paladin", path = "EaxRotations/classes/paladin/leveling_sylvanas.lua", spells = {"HolyLight","Judgement","SealOfRighteousness"} },
    { name = "Priest",  path = "EaxRotations/classes/priest/leveling_sylvanas.lua",  spells = {"ShadowWordPain","MindBlast","Renew"} },
    { name = "Rogue",   path = "EaxRotations/classes/rogue/leveling_sylvanas.lua",   spells = {"SinisterStrike","Eviscerate","SliceAndDice"} },
    { name = "Shaman",  path = "EaxRotations/classes/shaman/leveling_sylvanas.lua",  spells = {"LightningBolt","EarthShock","HealingWave"} },
    { name = "Warlock", path = "EaxRotations/classes/warlock/leveling_sylvanas.lua", spells = {"ShadowBolt","Corruption","Immolate"} },
    { name = "Warrior", path = "EaxRotations/classes/warrior/leveling_sylvanas.lua", spells = {"HeroicStrike","Rend","Charge"} },
}

for _, class in ipairs(classes) do
    -- Fresh environment per class
    local NS = build_mock_env(class.name, class.spells)

    local ok, module = pcall(dofile, class.path)
    if not ok then
        add_issue(class.name, "load", "Module failed to load: " .. tostring(module))
        failed = failed + 1
    elseif module == nil then
        add_issue(class.name, "load", "Module returned nil")
        failed = failed + 1
    else
        -- (a) Check registration
        local reg = NS.rotation_registry._registrations["leveling"]
        if not reg then
            add_issue(class.name, "registration", "Did not register 'leveling' playstyle")
            failed = failed + 1
        else
            -- (b) Check build_state accessibility
            local build_state_fn = nil
            if type(module) == "table" and type(module.build_state) == "function" then
                build_state_fn = module.build_state
            elseif reg.opts and type(reg.opts.get_state) == "function" then
                build_state_fn = reg.opts.get_state
            end
            if not build_state_fn then
                add_issue(class.name, "build_state", "No build_state or get_state function found")
                failed = failed + 1
            end

            -- (c) Check strategies accessibility (either on module or in registry)
            local strategies = nil
            if type(module) == "table" then
                if type(module.strategies) == "table" then
                    strategies = module.strategies
                elseif #module > 0 then
                    strategies = module
                end
            end
            if not strategies and reg.strategies then
                strategies = reg.strategies
            end
            if not strategies then
                add_issue(class.name, "strategies", "No strategies array, .strategies field, or registered strategies found")
                failed = failed + 1
            end
        end

        -- (d) Guarded registration test: reload with nil registry
        local NS2 = {
            log = function() end,
            spell_ready = function() return true end,
            spell_exists = function() return true end,
            try_cast = function() return true end,
            get_local_player = NS.get_local_player,
            get_target = NS.get_target,
            get_distance = function() return 10 end,
            debuff_remains = function() return 0 end,
            buff_remains = function() return 0 end,
            buff_up = function() return false end,
            -- NO rotation_registry — module must not crash
        }
        NS2[class.name .. "Spells"] = NS[class.name .. "Spells"]
        _G.EaxRotations = NS2

        local ok2, module2 = pcall(dofile, class.path)
        if not ok2 then
            add_issue(class.name, "guard", "Module crashed when rotation_registry is missing: " .. tostring(module2))
            failed = failed + 1
        else
            passed = passed + 1
        end
    end
end

-- ============================================================================
-- Summary
-- ============================================================================

if #issues > 0 then
    print("FAIL test_leveling_compliance")
    for _, issue in ipairs(issues) do
        print("  - " .. issue)
    end
    print(string.format("\nResults: %d passed, %d failed", passed, failed))
    error("test_leveling_compliance failed", 0)
else
    print(string.format("PASS test_leveling_compliance (%d classes, all conform)", passed))
end
