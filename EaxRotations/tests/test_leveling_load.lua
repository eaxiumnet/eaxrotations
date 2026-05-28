-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_leveling_load.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- Leveling rotation validation test.
-- Loads ALL 9 class leveling rotations with a mock environment and verifies:
--   1. Module loads without errors
--   2. Module returns valid interface (strategies or on_update)
--   3. Rotation evaluates without crashing in various contexts
--   4. Context guard properly gates activation
--   5. Strategy evaluation doesn't crash even with missing spells

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed: expected false", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
local function assert_nil(v, label) if v ~= nil then error(label or "assert_nil failed: expected nil got " .. tostring(v), 2) end end
local function assert_not_nil(v, label) if v == nil then error(label or "assert_not_nil failed: expected non-nil", 2) end end

-- Add EaxRotations dir to Lua module search path so require("shared/...") works
-- The modules do: require("shared/leveling_sylvanas") which expects the file at EaxRotations/shared/...
local EAXROTATIONS_DIR = "C:/newbot/scripts/EaxRotations"
if not package.path:find(EAXROTATIONS_DIR, 1, true) then
    package.path = package.path .. ";" .. EAXROTATIONS_DIR .. "/?.lua"
end

local passed = 0
local failed = 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL: " .. name .. " -- " .. tostring(err))
    end
end

-- ============================================================================
-- Build a unified mock environment
-- ============================================================================

local function build_mock_env()
    -- Fresh NS and core per call
    local NS = {}
    local core = {}

    -- core.time
    core.time = function() return 100 end
    core.game_time = function() return 100000 end

    -- core.spell_book
    core.spell_book = {
        get_spell_cooldown = function() return 0 end,
        get_global_cooldown = function() return 0 end,
        is_spell_learned = function() return true end,
    }

    -- core.input
    core.input = {
        cast_target_spell = function() return true end,
    }

    -- NS helpers
    NS.log = function() end
    NS.log_warning = function() end
    NS.spell_ready = function(spell_action)
        if not spell_action then return false end
        -- Simulate whether spell is learned: by default all spells are ready
        return true
    end
    NS.spell_exists = function(spell_id)
        -- Wand (5019) always exists
        if spell_id == 5019 then return true end
        return true
    end
    NS.try_cast = function(spell_action, target, label)
        if not spell_action then return false end
        return true
    end
    NS.get_local_player = function()
        local player = {
            is_valid = function() return true end,
            get_health = function() return 8000 end,
            get_max_health = function() return 10000 end,
            get_mana = function() return 5000 end,
            get_max_mana = function() return 10000 end,
            has_buff = function(id) return false end,
            has_debuff = function(id) return false end,
            get_class = function() return 5 end,
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
            get_position = function() return { x = 0, y = 0, z = 0 } end,
        }
        return player
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
    NS.debuff_remains = function(target, debuff_ids) return 0 end
    NS.buff_remains = function(unit, buff_ids) return 0 end

    -- rotation_registry mock
    NS.rotation_registry = {
        _registrations = {},
        register = function(self, key, strategies, opts)
            self._registrations[key] = { strategies = strategies, opts = opts }
        end,
        set_class_config = function(self, config) end,
    }

    -- Class-specific spell tables with minimal stubs that match spell_ready checks
    -- Each spell is an array of spell IDs (newest first), matching NS.spell_action pattern
    NS.MageSpells = {
        ArcaneIntellect = { 1459 },
        MoltenArmor = { 30482 },
        FrostArmor = { 168 },
        IceArmor = { 7301 },
        MageArmor = { 6117 },
        IceBarrier = { 11426 },
        ManaShield = { 1463 },
        Frostbolt = { 27072 },
        FireBlast = { 27078 },
        Scorch = { 27072 },
        ArcaneMissiles = { 27075 },
        Polymorph = { 12826 },
        Counterspell = { 2139 },
        FrostNova = { 122 },
        Blizzard = { 27085 },
        Evocation = { 12051 },
        ConjureManaGem = { 10054 },
        ConjureWater = { 27090 },
        Shoot = { 5019 },
    }

    NS.WarlockSpells = {
        FelArmor = { 28176 },
        DemonArmor = { 706 },
        CreateHealthstone = { 6201 },
        SpellLock = { 19647 },
        HealthFunnel = { 755 },
        Fear = { 6215 },
        DeathCoil = { 27223 },
        LifeTap = { 27222 },
        Corruption = { 27216 },
        Immolate = { 27215 },
        CurseOfAgony = { 27218 },
        DrainSoul = { 27217 },
        ShadowBolt = { 27209 },
        Shoot = { 5019 },
    }

    NS.DruidSpells = {
        MarkOfTheWild = { 26991 },
        Thorns = { 26992 },
        Moonfire = { 26988 },
        Wrath = { 26984 },
        Starfire = { 26986 },
        InsectSwarm = { 26989 },
        Hurricane = { 27012 },
        Rejuvenation = { 26981 },
        HealingTouch = { 26979 },
        Barkskin = { 22812 },
        EntanglingRoots = { 26990 },
        NaturesGrasp = { 26993 },
        FaerieFire = { 26993 },
    }

    NS.HunterSpells = {
        AspectOfTheHawk = { 27044 },
        AspectOfTheViper = { 34074 },
        AspectOfTheMonkey = { 13159 },
        SerpentSting = { 27019 },
        ArcaneShot = { 27025 },
        HuntersMark = { 27016 },
        MendPet = { 136 },
        ConcussiveShot = { 27634 },
        MultiShot = { 27021 },
        Shoot = { 5019 },
    }

    NS.PaladinSpells = {
        BlessingOfMight = { 27141 },
        BlessingOfWisdom = { 27143 },
        SealOfCommand = { 27160 },
        SealOfRighteousness = { 27155 },
        Judgement = { 20271 },
        HolyLight = { 27136 },
        HammerOfJustice = { 10308 },
        Exorcism = { 27138 },
        Consecration = { 27173 },
    }

    NS.PriestSpells = {
        PowerWordFortitude = { 25312 },
        InnerFire = { 25382 },
        PowerWordShield = { 25218 },
        ShadowWordPain = { 27607 },
        Renew = { 25222 },
        Heal = { 25213 },
        FlashHeal = { 25235 },
        HolyFire = { 25233 },
        MindBlast = { 25375 },
        ShadowWordDeath = { 32379 },
        Fade = { 586 },
        PsychicScream = { 10890 },
        Smite = { 25364 },
        Shoot = { 5019 },
    }

    NS.RogueSpells = {
        Stealth = { 1784 },
        SinisterStrike = { 26861 },
        Eviscerate = { 26866 },
        SliceAndDice = { 26867 },
        Rupture = { 26868 },
        ExposeArmor = { 26869 },
        Kick = { 11286 },
        ColdBlood = { 14177 },
        AdrenalineRush = { 13750 },
        BladeFlurry = { 13877 },
        Vanish = { 26870 },
        Evasion = { 26669 },
        Sprint = { 2983 },
    }

    NS.ShamanSpells = {
        LightningBolt = { 27070 },
        EarthShock = { 26988 },
        FlameShock = { 26989 },
        FrostShock = { 26990 },
        ChainLightning = { 27072 },
        LightningShield = { 26364 },
        WaterShield = { 33736 },
        HealingWave = { 27063 },
        LesserHealingWave = { 27065 },
        GhostWolf = { 2645 },
        Purge = { 370 },
        EarthbindTotem = { 3600 },
        StoneclawTotem = { 2630 },
        FireNovaTotem = { 2870 },
        SearingTotem = { 2637 },
        StrengthOfEarthTotem = { 8075 },
        GraceOfAirTotem = { 25908 },
        ManaSpringTotem = { 25507 },
        GroundingTotem = { 8177 },
        WindfuryTotem = { 25524 },
        TremorTotem = { 8143 },
        Shoot = { 5019 },
    }

    NS.WarriorSpells = {
        Charge = { 100 },
        BattleShout = { 25289 },
        CommandingShout = { 469 },
        Rend = { 25202 },
        MortalStrike = { 25248 },
        Bloodthirst = { 23881 },
        VictoryRush = { 25286 },
        Execute = { 25208 },
        Whirlwind = { 25231 },
        ThunderClap = { 25252 },
        Hamstring = { 25212 },
        Overpower = { 25234 },
        HeroicStrike = { 25284 },
        DemoralizingShout = { 25203 },
        ShieldBlock = { 2565 },
    }

    _G.core = core
    _G.EaxRotations = NS

    return NS, core
end

-- ============================================================================
-- Helper: build a mock context
-- ============================================================================

local function make_context(overrides)
    local ctx = {
        is_solo = true,
        is_leveling = false,
        in_combat = true,
        mana_pct = 80,
        hp = 100,
        enemies_count = 1,
        target = {
            is_valid = function() return true end,
            get_health = function() return 8000 end,
            get_max_health = function() return 10000 end,
            is_casting = function() return false end,
            is_alive = function() return true end,
            get_guid = function() return "mock-target" end,
        },
        pet = { guid = "mock-pet" },
        is_moving = false,
        settings = {
            playstyle = "leveling",
            active_playstyle = "leveling",
            use_interrupt = true,
            leveling_wand_threshold = 30,
            leveling_heal_hp = 40,
        },
    }
    if overrides then
        for k, v in pairs(overrides) do
            ctx[k] = v
        end
    end
    return ctx
end

-- ============================================================================
-- Pattern 1 Tests: NS.rotation_registry pattern (Mage, Warlock, Hunter, Paladin, Priest)
-- ============================================================================

local function test_pattern1(name, module_path, expected_spell_count)
    local NS, core = build_mock_env()

    local ok, module = pcall(dofile, module_path)
    assert_true(ok, name .. ": dofile should not throw")
    assert_not_nil(module, name .. ": module should not be nil (NS must exist)")

    -- Pattern 1: module returns strategies table (array)
    assert_true(type(module) == "table", name .. ": should return a table")
    assert_true(#module > 0, name .. ": should have at least one strategy")

    -- Check that it registered with rotation_registry
    local reg = NS.rotation_registry._registrations["leveling"]
    assert_not_nil(reg, name .. ": should register as 'leveling' in rotation_registry")
    assert_not_nil(reg.opts, name .. ": should have opts")
    assert_not_nil(reg.opts.get_state, name .. ": should have get_state in opts")

    -- Check each strategy has required fields
    for i, strategy in ipairs(module) do
        assert_true(type(strategy.name) == "string", name .. ": strategy[" .. i .. "] should have name")
        assert_true(type(strategy.matches) == "function", name .. ": strategy[" .. i .. "] matches should be function")
        assert_true(type(strategy.execute) == "function", name .. ": strategy[" .. i .. "] execute should be function")
    end

    -- Test build_state doesn't crash
    local context = make_context()
    local state = reg.opts.get_state(context)
    assert_true(type(state) == "table", name .. ": build_state should return a table")
    assert_eq(state.in_combat, true, name .. ": state.in_combat should be set")

    -- Test environment without NS (module should return nil)
    local NS_new, core_new = build_mock_env()
    _G.EaxRotations = nil
    local nil_mod = dofile(module_path)
    assert_nil(nil_mod, name .. ": should return nil when EaxRotations is nil")
    _G.EaxRotations = NS

    print("  PASS: " .. name .. " (" .. #module .. " strategies)")
end

-- ============================================================================
-- Pattern 2 Tests: xxx_leveling.on_update pattern (Rogue, Shaman, Warrior, Druid)
-- ============================================================================

local function test_pattern2(name, module_path)
    local NS, core = build_mock_env()

    local ok, module = pcall(dofile, module_path)
    assert_true(ok, name .. ": dofile should not throw")
    assert_not_nil(module, name .. ": module should not be nil (NS must exist)")

    -- Pattern 2: module returns a table with on_update function
    assert_true(type(module) == "table", name .. ": should return a table")
    assert_not_nil(module.on_update, name .. ": should have on_update function")
    assert_true(type(module.on_update) == "function", name .. ": on_update should be a function")
    assert_not_nil(module.build_state, name .. ": should have build_state function")
    assert_true(type(module.build_state) == "function", name .. ": build_state should be a function")

    -- Test 1: nil context returns false
    assert_false(module.on_update(nil), name .. ": nil context should return false")

    -- Test 2: non-leveling context returns false
    local non_leveling = make_context({ is_solo = false, is_leveling = false, settings = { playstyle = "balance" } })
    assert_false(module.on_update(non_leveling), name .. ": non-leveling context should return false")

    -- Test 3: solo context activates rotation
    local solo_context = make_context({ is_solo = true })
    -- Might or might not find a strategy to execute (depends on mock state),
    -- but should not crash
    local result = module.on_update(solo_context)
    -- Accept either true (strategy fired) or false (no strategy matched)
    assert_true(type(result) == "boolean", name .. ": on_update should return boolean")

    -- Test 4: leveling playstyle context activates rotation
    local leveling_ctx = make_context({ is_solo = false, settings = { playstyle = "leveling" } })
    local result2 = module.on_update(leveling_ctx)
    assert_true(type(result2) == "boolean", name .. ": on_update with leveling playstyle should return boolean")

    -- Test 5: build_state doesn't crash with minimal context
    local minimal_ctx = make_context({ target = nil, settings = {} })
    local state = module.build_state(minimal_ctx)
    assert_true(type(state) == "table", name .. ": build_state should return a table with minimal context")

    -- Test 6: build_state with nil context returns nil
    assert_nil(module.build_state(nil), name .. ": build_state with nil should return nil")

    -- Test 7: rotation doesn't crash with no spells available
    -- Temporarily make NS.spell_ready return false
    local orig_spell_ready = NS.spell_ready
    NS.spell_ready = function() return false end
    local no_spells_ctx = make_context()
    local result3 = module.on_update(no_spells_ctx)
    assert_false(result3, name .. ": on_update with no spells should return false (no matches)")
    NS.spell_ready = orig_spell_ready

    -- Test 8: rotation handles settings mismatch gracefully
    local bad_settings_ctx = make_context({ settings = { nonsense_key = "abc" } })
    local result4 = module.on_update(bad_settings_ctx)
    assert_true(type(result4) == "boolean", name .. ": on_update with bad settings should not crash")

    -- Test 9: rotation is called repeatedly without issue
    for i = 1, 5 do
        local r = module.on_update(make_context())
        assert_true(type(r) == "boolean", name .. ": repeated call #" .. i .. " should return boolean")
    end

    -- Test 10: environment without NS (module should return nil)
    local NS2, core2 = build_mock_env()
    _G.EaxRotations = nil
    local nil_mod = dofile(module_path)
    assert_nil(nil_mod, name .. ": should return nil when EaxRotations is nil")
    _G.EaxRotations = NS

    print("  PASS: " .. name)
end

-- ============================================================================
-- Run all tests
-- ============================================================================

print("=== Leveling Rotation Validation ===\n")

-- Pattern 1 (rotation_registry)
test("Mage", function() test_pattern1("Mage", "EaxRotations/classes/mage/leveling_sylvanas.lua") end)
test("Warlock", function() test_pattern1("Warlock", "EaxRotations/classes/warlock/leveling_sylvanas.lua") end)
test("Hunter", function() test_pattern1("Hunter", "EaxRotations/classes/hunter/leveling_sylvanas.lua") end)
test("Paladin", function() test_pattern1("Paladin", "EaxRotations/classes/paladin/leveling_sylvanas.lua") end)
test("Priest", function() test_pattern1("Priest", "EaxRotations/classes/priest/leveling_sylvanas.lua") end)

-- Pattern 2 (on_update)
test("Rogue", function() test_pattern2("Rogue", "EaxRotations/classes/rogue/leveling_sylvanas.lua") end)
test("Shaman", function() test_pattern2("Shaman", "EaxRotations/classes/shaman/leveling_sylvanas.lua") end)
test("Warrior", function() test_pattern2("Warrior", "EaxRotations/classes/warrior/leveling_sylvanas.lua") end)
test("Druid", function() test_pattern2("Druid", "EaxRotations/classes/druid/leveling_sylvanas.lua") end)

-- ============================================================================
-- Shared module smoke test
-- ============================================================================

test("SharedModule", function()
    local NS, core = build_mock_env()
    local leveling = dofile("EaxRotations/shared/leveling_sylvanas.lua")
    assert_not_nil(leveling, "Shared module should load")

    -- Verify all 8 exported functions
    assert_true(type(leveling.create_context_guard) == "function", "create_context_guard")
    assert_true(type(leveling.execute_wand) == "function", "execute_wand")
    assert_true(type(leveling.create_wand_matches) == "function", "create_wand_matches")
    assert_true(type(leveling.build_common_state) == "function", "build_common_state")
    assert_true(type(leveling.create_interrupt_matches) == "function", "create_interrupt_matches")
    assert_true(type(leveling.create_ooc_buff_matches) == "function", "create_ooc_buff_matches")
    assert_true(type(leveling.dot_needs_refresh) == "function", "dot_needs_refresh")
    assert_true(type(leveling.create_aoe_matches) == "function", "create_aoe_matches")

    -- Smoke test context guard
    local guard = leveling.create_context_guard()
    assert_false(guard(nil), "context guard: nil context")
    assert_true(guard({ is_solo = true }), "context guard: solo")
    assert_true(guard({ settings = { playstyle = "leveling" } }), "context guard: playstyle")

    -- Smoke test create_wand_matches
    local wand_matches = leveling.create_wand_matches("test_key", 30)
    assert_true(type(wand_matches) == "function", "wand_matches function")

    -- Smoke test build_common_state
    local state = leveling.build_common_state(make_context(), {})
    assert_eq(state.in_combat, true, "common state: in_combat")

    -- Smoke test create_interrupt_matches
    local interrupt = leveling.create_interrupt_matches("kick_ready")
    assert_true(type(interrupt) == "function", "interrupt_matches function")

    -- Smoke test create_ooc_buff_matches
    local ooc = leveling.create_ooc_buff_matches("has_buff", "buff_ready")
    assert_true(type(ooc) == "function", "ooc_buff_matches function")

    -- Smoke test dot_needs_refresh
    local target_mock = { magic_remains = 0 }
    local needs = leveling.dot_needs_refresh(target_mock, { 100 })
    assert_true(needs, "dot_needs_refresh: expired dot needs refresh")

    -- Smoke test create_aoe_matches
    local aoe = leveling.create_aoe_matches(3)
    assert_true(type(aoe) == "function", "aoe_matches function")

    print("  PASS: SharedModule (8 functions verified)")
end)

-- ============================================================================
-- Summary
-- ============================================================================

print(string.format("\n=== Results: %d passed, %d failed ===", passed, failed))
if failed > 0 then
    error(string.format("Some tests FAILED (%d failures)", failed))
else
    print("All leveling rotations validated successfully!")
end
