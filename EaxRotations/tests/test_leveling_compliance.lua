-- test_leveling_compliance.lua -- Phase 2 compliance: leveling file standardization audit.
-- WHAT:  verifies that all 28 leveling files (TBC + Vanilla + WotLK) meet the contract:
--          (a) Module loads without errors
--          (b) Registers "leveling" playstyle with rotation_registry
--          (c) Exposes build_state / get_state
--          (d) Return shape includes strategies (array or .strategies field)
--          (e) Registration is guarded (won't crash if registry missing)
-- WHEN:  run as standalone test or via run_leveling_tests.lua.
-- WHY:   locks the leveling standardization contract; prevents drift (Scenario 5).
-- SAFETY: pure mock-based static analysis; no engine API calls.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local passed = 0
local failed = 0
local issues = {}

local function add_issue(label, rule, detail)
    issues[#issues + 1] = string.format("%s :: %s :: %s", label, rule, detail)
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
    NS.GetPlayer = NS.get_local_player
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
    NS.debuff_up = function() return false end
    NS.has_form = function() return true end
    NS.is_behind_target = function() return true end
    NS.is_stealthed = function() return false end
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

    -- Build minimal spell table (metatable fallback for unknown keys)
    local spell_table = setmetatable({}, {
        __index = function(_, spell_field) return spell_field end,
    })
    if spell_keys then
        for i, key in ipairs(spell_keys) do
            spell_table[key] = { 1000 + i }
        end
    end
    NS[class_name .. "Spells"] = spell_table

    -- Provide empty spell tables for all classes so cross-requires don't crash
    local all_classes = {
        "Warrior", "Paladin", "Hunter", "Rogue", "Priest",
        "Mage", "Warlock", "Druid", "Shaman", "DeathKnight",
    }
    for _, c in ipairs(all_classes) do
        if not NS[c .. "Spells"] then
            NS[c .. "Spells"] = setmetatable({}, {
                __index = function(_, spell_field) return spell_field end,
            })
        end
    end

    _G.core = core
    _G.EaxRotations = NS

    return NS
end

-- ============================================================================
-- All 28 leveling files (9 TBC + 9 Vanilla + 10 WotLK)
-- ============================================================================

local DEFAULT_SPELLS = {
    Druid = { "MarkOfTheWild", "Thorns", "Moonfire", "Wrath" },
    Hunter = { "AspectOfTheHawk", "SerpentSting", "ArcaneShot" },
    Mage = { "Frostbolt", "FireBlast", "ArcaneMissiles" },
    Paladin = { "HolyLight", "Judgement", "SealOfRighteousness" },
    Priest = { "ShadowWordPain", "MindBlast", "Renew" },
    Rogue = { "SinisterStrike", "Eviscerate", "SliceAndDice" },
    Shaman = { "LightningBolt", "EarthShock", "HealingWave" },
    Warlock = { "ShadowBolt", "Corruption", "Immolate" },
    Warrior = { "HeroicStrike", "Rend", "Charge" },
    DeathKnight = { "IcyTouch", "PlagueStrike", "BloodStrike", "DeathCoil" },
}

local files = {
    -- TBC (leveling_sylvanas)
    { label = "Druid/tbc",     class = "Druid",   path = "EaxRotations/classes/druid/leveling_sylvanas.lua" },
    { label = "Hunter/tbc",    class = "Hunter",  path = "EaxRotations/classes/hunter/leveling_sylvanas.lua" },
    { label = "Mage/tbc",      class = "Mage",    path = "EaxRotations/classes/mage/leveling_sylvanas.lua" },
    { label = "Paladin/tbc",   class = "Paladin", path = "EaxRotations/classes/paladin/leveling_sylvanas.lua" },
    { label = "Priest/tbc",    class = "Priest",  path = "EaxRotations/classes/priest/leveling_sylvanas.lua" },
    { label = "Rogue/tbc",     class = "Rogue",   path = "EaxRotations/classes/rogue/leveling_sylvanas.lua" },
    { label = "Shaman/tbc",    class = "Shaman",  path = "EaxRotations/classes/shaman/leveling_sylvanas.lua" },
    { label = "Warlock/tbc",   class = "Warlock", path = "EaxRotations/classes/warlock/leveling_sylvanas.lua" },
    { label = "Warrior/tbc",   class = "Warrior", path = "EaxRotations/classes/warrior/leveling_sylvanas.lua" },
    -- Vanilla
    { label = "Druid/vanilla",   class = "Druid",   path = "EaxRotations/classes/druid/leveling_vanilla.lua" },
    { label = "Hunter/vanilla",  class = "Hunter",  path = "EaxRotations/classes/hunter/leveling_vanilla.lua" },
    { label = "Mage/vanilla",    class = "Mage",    path = "EaxRotations/classes/mage/leveling_vanilla.lua" },
    { label = "Paladin/vanilla", class = "Paladin", path = "EaxRotations/classes/paladin/leveling_vanilla.lua" },
    { label = "Priest/vanilla",  class = "Priest",  path = "EaxRotations/classes/priest/leveling_vanilla.lua" },
    { label = "Rogue/vanilla",   class = "Rogue",   path = "EaxRotations/classes/rogue/leveling_vanilla.lua" },
    { label = "Shaman/vanilla",  class = "Shaman",  path = "EaxRotations/classes/shaman/leveling_vanilla.lua" },
    { label = "Warlock/vanilla", class = "Warlock", path = "EaxRotations/classes/warlock/leveling_vanilla.lua" },
    { label = "Warrior/vanilla", class = "Warrior", path = "EaxRotations/classes/warrior/leveling_vanilla.lua" },
    -- WotLK
    { label = "Druid/wotlk",        class = "Druid",       path = "EaxRotations/classes/druid/leveling_wotlk.lua" },
    { label = "Hunter/wotlk",       class = "Hunter",      path = "EaxRotations/classes/hunter/leveling_wotlk.lua" },
    { label = "Mage/wotlk",         class = "Mage",        path = "EaxRotations/classes/mage/leveling_wotlk.lua" },
    { label = "Paladin/wotlk",      class = "Paladin",     path = "EaxRotations/classes/paladin/leveling_wotlk.lua" },
    { label = "Priest/wotlk",       class = "Priest",      path = "EaxRotations/classes/priest/leveling_wotlk.lua" },
    { label = "Rogue/wotlk",        class = "Rogue",       path = "EaxRotations/classes/rogue/leveling_wotlk.lua" },
    { label = "Shaman/wotlk",       class = "Shaman",      path = "EaxRotations/classes/shaman/leveling_wotlk.lua" },
    { label = "Warlock/wotlk",      class = "Warlock",     path = "EaxRotations/classes/warlock/leveling_wotlk.lua" },
    { label = "Warrior/wotlk",      class = "Warrior",     path = "EaxRotations/classes/warrior/leveling_wotlk.lua" },
    { label = "DeathKnight/wotlk",  class = "DeathKnight", path = "EaxRotations/classes/deathknight/leveling_wotlk.lua" },
}

for _, entry in ipairs(files) do
    local NS = build_mock_env(entry.class, DEFAULT_SPELLS[entry.class])

    local ok, module = pcall(dofile, entry.path)
    if not ok then
        add_issue(entry.label, "load", "Module failed to load: " .. tostring(module))
        failed = failed + 1
    elseif module == nil then
        add_issue(entry.label, "load", "Module returned nil")
        failed = failed + 1
    else
        -- (a) Check registration
        local reg = NS.rotation_registry._registrations["leveling"]
        if not reg then
            add_issue(entry.label, "registration", "Did not register 'leveling' playstyle")
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
                add_issue(entry.label, "build_state", "No build_state or get_state function found")
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
                add_issue(entry.label, "strategies", "No strategies array, .strategies field, or registered strategies found")
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
            GetPlayer = NS.get_local_player,
            get_target = NS.get_target,
            get_distance = function() return 10 end,
            debuff_remains = function() return 0 end,
            buff_remains = function() return 0 end,
            buff_up = function() return false end,
            debuff_up = function() return false end,
            has_form = function() return true end,
            -- NO rotation_registry — module must not crash
        }
        NS2[entry.class .. "Spells"] = NS[entry.class .. "Spells"]
        _G.EaxRotations = NS2

        local ok2, module2 = pcall(dofile, entry.path)
        if not ok2 then
            add_issue(entry.label, "guard", "Module crashed when rotation_registry is missing: " .. tostring(module2))
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
    print(string.format("\nResults: %d passed, %d failed (of %d files)", passed, failed, #files))
    error("test_leveling_compliance failed", 0)
else
    print(string.format("PASS test_leveling_compliance (%d files, all conform)", passed))
end
