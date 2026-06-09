-- ============================================================================
-- pcall-based nil-guard regression tests for remaining class middlewares
-- Classes: mage, warlock, hunter, priest, rogue, shaman
-- Each test verifies that setting a key NS.* function to nil doesn't crash
-- the middleware strategy matches function.
--
-- Pattern: save original NS.<func>, set to nil, pcall the strategy matches,
-- restore, assert that pcall returned ok=true (no crash).
-- ============================================================================

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- ============================================================================
-- Shared NS mock factory
-- ============================================================================
local function make_mock_ns()
    return {
        MageSpells = {
            IceBlock = 27619,
            ManaShield = 1463,
            MoltenArmor = 30482,
            MageArmor = 6117,
            ArcaneIntellect = 27126,
            Spellsteal = { id = { 30449 } },
            RemoveCurse = 475,
        },
        WarlockSpells = {
            Soulshatter = 32835,
            HowlofTerror = 17928,
            ShadowWard = { id = { 28610 } },
            DeathCoil = { id = { 27223 } },
        },
        HunterSpells = {
            FeignDeath = 19615,
            ViperSting = 27018,
            FreezingTrap = 14309,
            MendPet = 27046,
            RevivePet = 982,
            CallPet = 883,
            HuntersMark = 14325,
        },
        PriestSpells = {
            MassDispel = 32375,
            DispelMagic = 988,
            ManaBurn = 30459,
            PsychicScream = 10890,
            Fade = 586,
        },
        RogueSpells = {
            Shiv = 5938,
            Kick = 1766,
            Vanish = 26889,
            CloakOfShadows = 31224,
            Evasion = 26669,
            Feint = 1966,
        },
        ShamanSpells = {
            EarthShock = 8042,
        },
        PLAYER_UNIT = {},
        register_class_middleware = function() end,
        spell_ready = function() return true end,
        is_spell_learned = function() return true end,
        has_player_buff = function() return false end,
        has_buff = function() return false end,
        debuff_up = function() return false end,
        buff_up = function() return false end,
        buff_remains = function() return 0 end,
        debuff_remains = function() return 0 end,
        has_debuff = function() return false end,
        try_cast = function() return true end,
        try_cast_position = function() return true end,
        spell_action = function(ids) return ids end,
        time_now = function() return 0 end,
        GetPlayer = function() return {} end,
        GetPet = function() return nil end,
        GetFocus = function() return nil end,
        get_pet = function() return nil end,
        has_pet = function() return false end,
        get_pet_hp = function() return 100 end,
        has_item = function() return false end,
        use_item = function() return false end,
        is_item_ready = function() return false end,
        use_item_by_id = function() return false end,
        should_kite = function() return false end,
        same_unit = function(a, b) return a == b end,
        GetEnemiesInRange = function() return {} end,
        GetEnemiesCount = function() return 0 end,
        GetPartyMembers = function() return {} end,
        safe_field = function(obj, field)
            if obj and obj[field] then return obj[field] end
            return nil
        end,
        get_setting = function() return nil end,
        is_breakable_cc_active = function() return false, nil end,
        is_casting_preemptive_cc = function() return false, nil end,
        find_best_dispel_target = function() return nil, 0, nil end,
        is_healer_class = function() return false end,
        unit_mana_pct = function() return 0 end,
        OffensiveDispelDB = {
            PRIORITY_LOW = 1, PRIORITY_MEDIUM = 2, PRIORITY_HIGH = 3, PRIORITY_CRITICAL = 4,
            find_best_dispel_target = function() return nil, 0, nil end,
            should_mass_dispel = function() return false, nil end,
            is_healer_class = function() return false end,
            is_breakable_cc_active = function() return false, nil end,
            is_casting_preemptive_cc = function() return false, nil end,
            is_any_nearby_enemy_under_cc = function() return false, nil end,
        },
        log = function() end,
        broken_api_throttled = function() return false end,
        rotation_registry = { register = function() end },
        spell_id = function() return 0 end,
        get_aoe_cast_position = function() return nil end,
    }
end

-- ============================================================================
-- MAGE MIDDLEWARE
-- ============================================================================
local function test_mage()
    _G.EaxRotations = make_mock_ns()

    -- Preload shared modules needed by mage middleware
    package.preload["shared/consumable_manager_sylvanas"] = function()
        return { on_update = function() return false end }
    end
    package.preload["shared/interrupt_manager_sylvanas"] = function()
        return {
            register_interrupt_spell = function()
                return { name = "Counterspell", matches = function() return false end, execute = function() return false end }
            end,
        }
    end
    package.preload["shared/offensive_dispel_sylvanas"] = function()
        return _G.EaxRotations.OffensiveDispelDB
    end

    local strategies = dofile("EaxRotations/classes/mage/middleware_sylvanas.lua")
    assert_true(strategies, "mage strategies should load")

    local function find_strategy(name)
        for i = 1, #strategies do
            if strategies[i].name == name then return strategies[i] end
        end
        error("mage strategy not found: " .. name)
    end

    local test_count = 0
    local function test_pcall_nil(strategy, ctx, ns_key, label)
        test_count = test_count + 1
        local orig = _G.EaxRotations[ns_key]
        _G.EaxRotations[ns_key] = nil
        local ok, err = pcall(strategy.matches, ctx)
        _G.EaxRotations[ns_key] = orig
        assert_true(ok, label .. ": pcall should not error. Error: " .. tostring(err))
    end

    -- MageCCBreak tests
    local cc_break = find_strategy("MageCCBreak")
    local ctx_in_combat = { in_combat = true, me = {}, settings = {} }
    test_pcall_nil(cc_break, ctx_in_combat, "GetEnemiesInRange", "MageCCBreak: GetEnemiesInRange nil")
    test_pcall_nil(cc_break, ctx_in_combat, "is_spell_learned", "MageCCBreak: is_spell_learned nil")
    test_pcall_nil(cc_break, ctx_in_combat, "spell_ready", "MageCCBreak: spell_ready nil")
    test_pcall_nil(cc_break, ctx_in_combat, "same_unit", "MageCCBreak: same_unit nil")

    -- Spellsteal tests
    local spellsteal = find_strategy("Spellsteal")
    test_pcall_nil(spellsteal, { in_combat = true, settings = {}, mana_pct = 100 }, "is_spell_learned", "Spellsteal: is_spell_learned nil")
    test_pcall_nil(spellsteal, { in_combat = true, settings = {}, mana_pct = 100 }, "spell_ready", "Spellsteal: spell_ready nil")

    -- Defensive tests
    local defensive = find_strategy("Defensive")
    test_pcall_nil(defensive, { in_combat = true, hp = 10, mana_pct = 100, settings = { use_defensives = true } }, "spell_ready", "Defensive: spell_ready nil")
    test_pcall_nil(defensive, { in_combat = true, hp = 10, mana_pct = 100, settings = { use_defensives = true } }, "has_player_buff", "Defensive: has_player_buff nil")

    -- SelfBuff tests
    local self_buff = find_strategy("SelfBuff")
    test_pcall_nil(self_buff, { settings = { use_self_buffs = true } }, "has_player_buff", "SelfBuff: has_player_buff nil")
    test_pcall_nil(self_buff, { settings = { use_self_buffs = true } }, "spell_ready", "SelfBuff: spell_ready nil")

    -- PvPIceBlock tests
    local pvp_ice = find_strategy("PvPIceBlock")
    test_pcall_nil(pvp_ice, { hp = 10, settings = { use_pvp_defensives = true } }, "should_kite", "PvPIceBlock: should_kite nil")

    -- IceBarrier tests
    local ice_barrier = find_strategy("IceBarrier")
    test_pcall_nil(ice_barrier, { in_combat = true, me = {}, settings = { use_ice_barrier = true } }, "buff_up", "IceBarrier: buff_up nil")
    test_pcall_nil(ice_barrier, { in_combat = true, me = {}, settings = { use_ice_barrier = true } }, "spell_ready", "IceBarrier: spell_ready nil")

    -- Evocation tests
    local evocation = find_strategy("Evocation")
    test_pcall_nil(evocation, { in_combat = true, mana_pct = 10, settings = { use_evocation = true } }, "spell_ready", "Evocation: spell_ready nil")

    -- ManaGem tests
    local mana_gem = find_strategy("ManaGem")
    test_pcall_nil(mana_gem, { in_combat = true, mana_pct = 50, settings = { use_mana_gem = true } }, "is_item_ready", "ManaGem: is_item_ready nil")

    -- RemoveCurse tests
    local remove_curse = find_strategy("RemoveCurse")
    test_pcall_nil(remove_curse, { in_combat = true, me = {}, settings = { auto_remove_curse = true } }, "debuff_up", "RemoveCurse: debuff_up nil")

    return test_count
end

-- ============================================================================
-- WARLOCK MIDDLEWARE
-- ============================================================================
local function test_warlock()
    _G.EaxRotations = make_mock_ns()

    package.preload["shared/consumable_manager_sylvanas"] = function()
        return { on_update = function() return false end }
    end
    package.preload["shared/interrupt_manager_sylvanas"] = function()
        return {
            register_interrupt_spell = function()
                return { name = "Pummel", matches = function() return false end, execute = function() return false end }
            end,
        }
    end
    package.preload["shared/offensive_dispel_sylvanas"] = function()
        return _G.EaxRotations.OffensiveDispelDB
    end
    package.preload["shared/tbc_data_sylvanas"] = function()
        return { ITEMS = { healthstones = {}, potions = {} } }
    end

    local strategies = dofile("EaxRotations/classes/warlock/middleware_sylvanas.lua")
    assert_true(strategies, "warlock strategies should load")

    local function find_strategy(name)
        for i = 1, #strategies do
            if strategies[i].name == name then return strategies[i] end
        end
        error("warlock strategy not found: " .. name)
    end

    local test_count = 0
    local function test_pcall_nil(strategy, ctx, ns_key, label)
        test_count = test_count + 1
        local orig = _G.EaxRotations[ns_key]
        _G.EaxRotations[ns_key] = nil
        local ok, err = pcall(strategy.matches, ctx)
        _G.EaxRotations[ns_key] = orig
        assert_true(ok, label .. ": pcall should not error. Error: " .. tostring(err))
    end

    -- WarlockCCBreak tests
    local cc_break = find_strategy("WarlockCCBreak")
    local ctx_in_combat = { in_combat = true, me = {}, target = {}, settings = {} }
    test_pcall_nil(cc_break, ctx_in_combat, "GetEnemiesInRange", "WarlockCCBreak: GetEnemiesInRange nil")
    test_pcall_nil(cc_break, ctx_in_combat, "is_spell_learned", "WarlockCCBreak: is_spell_learned nil")
    test_pcall_nil(cc_break, ctx_in_combat, "spell_ready", "WarlockCCBreak: spell_ready nil")
    test_pcall_nil(cc_break, ctx_in_combat, "same_unit", "WarlockCCBreak: same_unit nil")

    -- DevourMagic tests
    local devour = find_strategy("DevourMagic")
    test_pcall_nil(devour, { in_combat = true, settings = {}, mana_pct = 100 }, "is_spell_learned", "DevourMagic: is_spell_learned nil")
    test_pcall_nil(devour, { in_combat = true, settings = {}, mana_pct = 100 }, "spell_ready", "DevourMagic: spell_ready nil")

    -- PvPHowlofTerror tests
    local howl = find_strategy("PvPHowlofTerror")
    test_pcall_nil(howl, { settings = { use_pvp_defensives = true } }, "should_kite", "PvPHowlofTerror: should_kite nil")
    test_pcall_nil(howl, { settings = { use_pvp_defensives = true } }, "GetEnemiesCount", "PvPHowlofTerror: GetEnemiesCount nil")

    -- ThreatDrop tests
    local threat = find_strategy("ThreatDrop")
    test_pcall_nil(threat, { in_combat = true, threat_pct = 95, settings = { use_threat_drop = true } }, "time_now", "ThreatDrop: time_now nil")
    test_pcall_nil(threat, { in_combat = true, threat_pct = 95, settings = { use_threat_drop = true } }, "spell_ready", "ThreatDrop: spell_ready nil")

    -- Warlock_ShadowWard tests
    local shadow_ward = find_strategy("Warlock_ShadowWard")
    test_pcall_nil(shadow_ward, { in_combat = true, me = {}, target = {}, settings = { use_shadow_ward = true } }, "has_player_buff", "Warlock_ShadowWard: has_player_buff nil")
    test_pcall_nil(shadow_ward, { in_combat = true, me = {}, target = {}, settings = { use_shadow_ward = true } }, "spell_ready", "Warlock_ShadowWard: spell_ready nil")

    -- Warlock_FelDomination tests
    local fel_dom = find_strategy("Warlock_FelDomination")
    test_pcall_nil(fel_dom, { in_combat = true, me = {}, hp = 20, settings = { use_fel_domination = true } }, "has_pet", "Warlock_FelDomination: has_pet nil")
    test_pcall_nil(fel_dom, { in_combat = true, me = {}, hp = 20, settings = { use_fel_domination = true } }, "spell_ready", "Warlock_FelDomination: spell_ready nil")

    -- Warlock_HealthFunnel tests
    local hf = find_strategy("Warlock_HealthFunnel")
    test_pcall_nil(hf, { in_combat = true, me = {}, hp = 80, settings = { use_health_funnel = true } }, "has_pet", "Warlock_HealthFunnel: has_pet nil")
    test_pcall_nil(hf, { in_combat = true, me = {}, hp = 80, settings = { use_health_funnel = true } }, "get_pet_hp", "Warlock_HealthFunnel: get_pet_hp nil")
    test_pcall_nil(hf, { in_combat = true, me = {}, hp = 80, settings = { use_health_funnel = true } }, "spell_ready", "Warlock_HealthFunnel: spell_ready nil")

    -- Warlock_CreateHealthstone tests
    local create_hs = find_strategy("Warlock_CreateHealthstone")
    test_pcall_nil(create_hs, { me = {}, settings = { auto_create_healthstone = true } }, "time_now", "Warlock_CreateHealthstone: time_now nil")
    test_pcall_nil(create_hs, { me = {}, settings = { auto_create_healthstone = true } }, "has_item", "Warlock_CreateHealthstone: has_item nil")
    test_pcall_nil(create_hs, { me = {}, settings = { auto_create_healthstone = true } }, "spell_ready", "Warlock_CreateHealthstone: spell_ready nil")

    -- Warlock_CreateSoulstone tests
    local create_ss = find_strategy("Warlock_CreateSoulstone")
    test_pcall_nil(create_ss, { me = {}, settings = { auto_create_soulstone = true } }, "has_item", "Warlock_CreateSoulstone: has_item nil")
    test_pcall_nil(create_ss, { me = {}, settings = { auto_create_soulstone = true } }, "has_player_buff", "Warlock_CreateSoulstone: has_player_buff nil")
    test_pcall_nil(create_ss, { me = {}, settings = { auto_create_soulstone = true } }, "spell_ready", "Warlock_CreateSoulstone: spell_ready nil")

    -- Warlock_DeathCoil tests
    local dc = find_strategy("Warlock_DeathCoil")
    test_pcall_nil(dc, { in_combat = true, hp = 30, settings = { death_coil_hp = 50 } }, "spell_ready", "Warlock_DeathCoil: spell_ready nil")

    -- Warlock_Healthstone tests (execute function)
    local whs = find_strategy("Warlock_Healthstone")
    test_pcall_nil(whs, { in_combat = true, hp = 20, me = {}, settings = { healthstone_hp = 30 } }, "use_item", "Warlock_Healthstone execute: use_item nil")

    return test_count
end

-- ============================================================================
-- HUNTER MIDDLEWARE
-- ============================================================================
local function test_hunter()
    _G.EaxRotations = make_mock_ns()

    package.preload["shared/consumable_manager_sylvanas"] = function()
        return { on_update = function() return false end }
    end
    package.preload["shared/interrupt_manager_sylvanas"] = function()
        return {
            register_interrupt_spell = function()
                return { name = "SilencingShot", matches = function() return false end, execute = function() return false end }
            end,
        }
    end
    package.preload["shared/aspect_manager_sylvanas"] = function()
        return {
            viper_middleware_strategy = function() return { name = "ViperAspect", matches = function() return false end, execute = function() return false end } end,
            hawk_middleware_strategy = function() return { name = "HawkAspect", matches = function() return false end, execute = function() return false end } end,
        }
    end

    local strategies = dofile("EaxRotations/classes/hunter/middleware_sylvanas.lua")
    assert_true(strategies, "hunter strategies should load")

    local function find_strategy(name)
        for i = 1, #strategies do
            if strategies[i].name == name then return strategies[i] end
        end
        error("hunter strategy not found: " .. name)
    end

    local test_count = 0
    local function test_pcall_nil(strategy, ctx, ns_key, label)
        test_count = test_count + 1
        local orig = _G.EaxRotations[ns_key]
        _G.EaxRotations[ns_key] = nil
        local ok, err = pcall(strategy.matches, ctx)
        _G.EaxRotations[ns_key] = orig
        assert_true(ok, label .. ": pcall should not error. Error: " .. tostring(err))
    end

    -- ThreatDrop tests
    local threat = find_strategy("ThreatDrop")
    test_pcall_nil(threat, { in_combat = true, threat_level = 3, settings = { use_threat_drop = true } }, "spell_ready", "ThreatDrop: spell_ready nil")

    -- ViperSting tests
    local viper = find_strategy("ViperSting")
    test_pcall_nil(viper, { in_combat = true, has_valid_enemy_target = true, target = { get_power_type = function() return 0 end, get_class = function() return "MAGE" end }, settings = {} }, "debuff_up", "ViperSting: debuff_up nil")
    test_pcall_nil(viper, { in_combat = true, has_valid_enemy_target = true, target = { get_power_type = function() return 0 end, get_class = function() return "MAGE" end }, settings = {} }, "spell_ready", "ViperSting: spell_ready nil")

    -- FreezingTrap tests
    local trap = find_strategy("FreezingTrap")
    test_pcall_nil(trap, { in_combat = true, has_valid_enemy_target = true, enemy_count = 3, target = {}, settings = {} }, "debuff_up", "FreezingTrap: debuff_up nil")
    test_pcall_nil(trap, { in_combat = true, has_valid_enemy_target = true, enemy_count = 3, target = {}, settings = {} }, "spell_ready", "FreezingTrap: spell_ready nil")

    -- Misdirection tests
    local md = find_strategy("Misdirection")
    test_pcall_nil(md, { in_combat = true, has_valid_enemy_target = true, combat_time = 2, me = {}, settings = {} }, "is_spell_learned", "Misdirection: is_spell_learned nil")
    test_pcall_nil(md, { in_combat = true, has_valid_enemy_target = true, combat_time = 2, me = {}, settings = {} }, "spell_ready", "Misdirection: spell_ready nil")
    test_pcall_nil(md, { in_combat = true, has_valid_enemy_target = true, combat_time = 2, me = {}, settings = {} }, "has_buff", "Misdirection: has_buff nil")

    -- MendPet tests
    local mend = find_strategy("MendPet")
    test_pcall_nil(mend, { in_combat = true, me = {}, settings = { auto_mend_pet = true } }, "get_pet_hp", "MendPet: get_pet_hp nil")
    test_pcall_nil(mend, { in_combat = true, me = {}, settings = { auto_mend_pet = true } }, "get_pet", "MendPet: get_pet nil")
    test_pcall_nil(mend, { in_combat = true, me = {}, settings = { auto_mend_pet = true } }, "buff_up", "MendPet: buff_up nil")
    test_pcall_nil(mend, { in_combat = true, me = {}, settings = { auto_mend_pet = true } }, "spell_ready", "MendPet: spell_ready nil")

    -- RevivePet tests
    local revive = find_strategy("RevivePet")
    test_pcall_nil(revive, { me = {}, settings = { auto_revive_pet = true } }, "has_pet", "RevivePet: has_pet nil")
    test_pcall_nil(revive, { me = {}, settings = { auto_revive_pet = true } }, "spell_ready", "RevivePet: spell_ready nil")

    -- CallPet tests
    local call = find_strategy("CallPet")
    test_pcall_nil(call, { me = {}, settings = { auto_call_pet = true } }, "has_pet", "CallPet: has_pet nil")
    test_pcall_nil(call, { me = {}, settings = { auto_call_pet = true } }, "spell_ready", "CallPet: spell_ready nil")

    -- HuntersMark tests
    local hm = find_strategy("HuntersMark")
    test_pcall_nil(hm, { in_combat = true, has_valid_enemy_target = true, target = {}, settings = {} }, "debuff_up", "HuntersMark: debuff_up nil")
    test_pcall_nil(hm, { in_combat = true, has_valid_enemy_target = true, target = {}, settings = {} }, "debuff_remains", "HuntersMark: debuff_remains nil")
    test_pcall_nil(hm, { in_combat = true, has_valid_enemy_target = true, target = {}, settings = {} }, "spell_ready", "HuntersMark: spell_ready nil")

    return test_count
end

-- ============================================================================
-- PRIEST MIDDLEWARE
-- ============================================================================
local function test_priest()
    _G.EaxRotations = make_mock_ns()

    package.preload["shared/consumable_manager_sylvanas"] = function()
        return { on_update = function() return false end }
    end
    package.preload["shared/interrupt_manager_sylvanas"] = function()
        return {
            register_interrupt_spell = function()
                return { name = "Silence", matches = function() return false end, execute = function() return false end }
            end,
        }
    end
    package.preload["shared/offensive_dispel_sylvanas"] = function()
        return _G.EaxRotations.OffensiveDispelDB
    end

    local strategies = dofile("EaxRotations/classes/priest/middleware_sylvanas.lua")
    assert_true(strategies, "priest strategies should load")

    local function find_strategy(name)
        for i = 1, #strategies do
            if strategies[i].name == name then return strategies[i] end
        end
        error("priest strategy not found: " .. name)
    end

    local test_count = 0
    local function test_pcall_nil(strategy, ctx, ns_key, label)
        test_count = test_count + 1
        local orig = _G.EaxRotations[ns_key]
        _G.EaxRotations[ns_key] = nil
        local ok, err = pcall(strategy.matches, ctx)
        _G.EaxRotations[ns_key] = orig
        assert_true(ok, label .. ": pcall should not error. Error: " .. tostring(err))
    end

    local base_ctx = { in_combat = true, mana_pct = 100, me = {}, settings = {} }

    -- MassDispel tests
    local mass = find_strategy("MassDispel")
    test_pcall_nil(mass, base_ctx, "is_spell_learned", "MassDispel: is_spell_learned nil")
    test_pcall_nil(mass, base_ctx, "spell_ready", "MassDispel: spell_ready nil")
    test_pcall_nil(mass, base_ctx, "GetEnemiesInRange", "MassDispel: GetEnemiesInRange nil")

    -- OffensiveDispel tests
    local od = find_strategy("OffensiveDispel")
    test_pcall_nil(od, base_ctx, "is_spell_learned", "OffensiveDispel: is_spell_learned nil")
    test_pcall_nil(od, base_ctx, "spell_ready", "OffensiveDispel: spell_ready nil")

    -- ManaBurn tests
    local mb = find_strategy("ManaBurn")
    test_pcall_nil(mb, base_ctx, "is_spell_learned", "ManaBurn: is_spell_learned nil")
    test_pcall_nil(mb, base_ctx, "spell_ready", "ManaBurn: spell_ready nil")
    test_pcall_nil(mb, base_ctx, "unit_mana_pct", "ManaBurn: unit_mana_pct nil")

    -- PvPPsychicScream tests
    local scream = find_strategy("PvPPsychicScream")
    test_pcall_nil(scream, { settings = { use_pvp_defensives = true } }, "should_kite", "PvPPsychicScream: should_kite nil")
    test_pcall_nil(scream, { settings = { use_pvp_defensives = true } }, "GetEnemiesCount", "PvPPsychicScream: GetEnemiesCount nil")

    -- ThreatDrop tests
    local threat = find_strategy("ThreatDrop")
    test_pcall_nil(threat, { in_combat = true, me = {}, settings = { use_threat_drop = true } }, "spell_ready", "ThreatDrop: spell_ready nil")
    test_pcall_nil(threat, { in_combat = true, me = {}, settings = { use_threat_drop = true } }, "has_buff", "ThreatDrop: has_buff nil")

    -- PartyDispelMagic tests
    local pdm = find_strategy("PartyDispelMagic")
    test_pcall_nil(pdm, base_ctx, "has_debuff", "PartyDispelMagic: has_debuff nil")
    test_pcall_nil(pdm, base_ctx, "spell_ready", "PartyDispelMagic: spell_ready nil")
    test_pcall_nil(pdm, base_ctx, "GetPartyMembers", "PartyDispelMagic: GetPartyMembers nil")

    -- AbolishDisease tests
    local ad = find_strategy("AbolishDisease")
    test_pcall_nil(ad, base_ctx, "has_debuff", "AbolishDisease: has_debuff nil")
    test_pcall_nil(ad, base_ctx, "spell_ready", "AbolishDisease: spell_ready nil")

    -- PartyAbolishDisease tests
    local pad = find_strategy("PartyAbolishDisease")
    test_pcall_nil(pad, base_ctx, "has_debuff", "PartyAbolishDisease: has_debuff nil")
    test_pcall_nil(pad, base_ctx, "spell_ready", "PartyAbolishDisease: spell_ready nil")

    -- Shadowfiend tests
    local sf = find_strategy("Shadowfiend")
    test_pcall_nil(sf, base_ctx, "is_spell_learned", "Shadowfiend: is_spell_learned nil")
    test_pcall_nil(sf, base_ctx, "spell_ready", "Shadowfiend: spell_ready nil")

    -- EnhancedFade tests
    local ef = find_strategy("EnhancedFade")
    test_pcall_nil(ef, base_ctx, "is_spell_learned", "EnhancedFade: is_spell_learned nil")
    test_pcall_nil(ef, base_ctx, "spell_ready", "EnhancedFade: spell_ready nil")
    test_pcall_nil(ef, base_ctx, "has_buff", "EnhancedFade: has_buff nil")

    return test_count
end

-- ============================================================================
-- ROGUE MIDDLEWARE
-- ============================================================================
local function test_rogue()
    _G.EaxRotations = make_mock_ns()

    package.preload["shared/consumable_manager_sylvanas"] = function()
        return { on_update = function() return false end }
    end
    package.preload["shared/interrupt_manager_sylvanas"] = function()
        return {
            register_interrupt_spell = function()
                return { name = "Kick", matches = function() return false end, execute = function() return false end }
            end,
        }
    end
    package.preload["shared/offensive_dispel_sylvanas"] = function()
        return _G.EaxRotations.OffensiveDispelDB
    end

    local strategies = dofile("EaxRotations/classes/rogue/middleware_sylvanas.lua")
    assert_true(strategies, "rogue strategies should load")

    local function find_strategy(name)
        for i = 1, #strategies do
            if strategies[i].name == name then return strategies[i] end
        end
        error("rogue strategy not found: " .. name)
    end

    local test_count = 0
    local function test_pcall_nil(strategy, ctx, ns_key, label)
        test_count = test_count + 1
        local orig = _G.EaxRotations[ns_key]
        _G.EaxRotations[ns_key] = nil
        local ok, err = pcall(strategy.matches, ctx)
        _G.EaxRotations[ns_key] = orig
        assert_true(ok, label .. ": pcall should not error. Error: " .. tostring(err))
    end

    local pvp_ctx = { in_combat = true, is_pvp = true, has_valid_enemy_target = true, target = { is_player = function() return true end }, in_melee_range = true, me = {}, settings = {} }

    -- RogueShivPurge tests
    local shiv = find_strategy("RogueShivPurge")
    test_pcall_nil(shiv, pvp_ctx, "is_spell_learned", "RogueShivPurge: is_spell_learned nil")

    -- RogueCCBreak tests
    local cc = find_strategy("RogueCCBreak")
    test_pcall_nil(cc, { in_combat = true, me = {}, settings = {} }, "GetEnemiesInRange", "RogueCCBreak: GetEnemiesInRange nil")
    test_pcall_nil(cc, { in_combat = true, me = {}, settings = {} }, "spell_ready", "RogueCCBreak: spell_ready nil")
    test_pcall_nil(cc, { in_combat = true, me = {}, settings = {} }, "same_unit", "RogueCCBreak: same_unit nil")

    -- CloakOfShadows tests
    local cloak = find_strategy("CloakOfShadows")
    test_pcall_nil(cloak, { in_combat = true, player_hp = 30, target = { get_class = function() return "MAGE" end }, settings = {} }, "has_debuff", "CloakOfShadows: has_debuff nil")
    test_pcall_nil(cloak, { in_combat = true, player_hp = 30, target = { get_class = function() return "MAGE" end }, settings = {} }, "spell_ready", "CloakOfShadows: spell_ready nil")
    test_pcall_nil(cloak, { in_combat = true, player_hp = 30, target = { get_class = function() return "MAGE" end }, settings = {} }, "has_buff", "CloakOfShadows: has_buff nil")

    -- Evasion tests
    local evasion = find_strategy("Evasion")
    test_pcall_nil(evasion, { in_combat = true, player_hp = 20, target = { get_class = function() return "WARRIOR" end }, settings = {} }, "is_spell_learned", "Evasion: is_spell_learned nil")
    test_pcall_nil(evasion, { in_combat = true, player_hp = 20, target = { get_class = function() return "WARRIOR" end }, settings = {} }, "spell_ready", "Evasion: spell_ready nil")
    test_pcall_nil(evasion, { in_combat = true, player_hp = 20, target = { get_class = function() return "WARRIOR" end }, settings = {} }, "has_buff", "Evasion: has_buff nil")

    -- VanishDefensive tests
    local vanish = find_strategy("VanishDefensive")
    test_pcall_nil(vanish, { in_combat = true, player_hp = 10, settings = {} }, "is_spell_learned", "VanishDefensive: is_spell_learned nil")
    test_pcall_nil(vanish, { in_combat = true, player_hp = 10, settings = {} }, "spell_ready", "VanishDefensive: spell_ready nil")

    -- ThistleTea tests
    local tea = find_strategy("ThistleTea")
    test_pcall_nil(tea, { in_combat = true, energy = 20, should_burst = true, me = {}, settings = {} }, "has_item", "ThistleTea: has_item nil")
    test_pcall_nil(tea, { in_combat = true, energy = 20, should_burst = true, me = {}, settings = {} }, "use_item", "ThistleTea: use_item nil")

    -- PvPCCGate tests
    local pvg = find_strategy("PvPCCGate")
    test_pcall_nil(pvg, { in_combat = true, settings = {} }, "is_spell_learned", "PvPCCGate: is_spell_learned nil")

    return test_count
end

-- ============================================================================
-- SHAMAN MIDDLEWARE
-- ============================================================================
local function test_shaman()
    _G.EaxRotations = make_mock_ns()

    package.preload["shared/consumable_manager_sylvanas"] = function()
        return { on_update = function() return false end }
    end
    package.preload["shared/interrupt_manager_sylvanas"] = function()
        return {
            register_interrupt_spell = function()
                return { name = "EarthShock", matches = function() return false end, execute = function() return false end }
            end,
        }
    end
    package.preload["shared/auto_tremor_sylvanas"] = function()
        return {
            is_fear_boss = function() return false end,
            try_drop_tremor = function() return false end,
        }
    end
    package.preload["shared/purge_manager_sylvanas"] = function()
        return {
            has_purgeable_buff = function() return false end,
            try_purge = function() return false end,
        }
    end
    package.preload["shared/offensive_dispel_sylvanas"] = function()
        return _G.EaxRotations.OffensiveDispelDB
    end

    local strategies = dofile("EaxRotations/classes/shaman/middleware_sylvanas.lua")
    assert_true(strategies, "shaman strategies should load")

    local function find_strategy(name)
        for i = 1, #strategies do
            if strategies[i].name == name then return strategies[i] end
        end
        error("shaman strategy not found: " .. name)
    end

    local test_count = 0
    local function test_pcall_nil(strategy, ctx, ns_key, label)
        test_count = test_count + 1
        local orig = _G.EaxRotations[ns_key]
        _G.EaxRotations[ns_key] = nil
        local ok, err = pcall(strategy.matches, ctx)
        _G.EaxRotations[ns_key] = orig
        assert_true(ok, label .. ": pcall should not error. Error: " .. tostring(err))
    end

    local base_ctx = { in_combat = true, mana_pct = 100, me = {}, settings = {}, target = {} }

    -- Purge tests
    local purge = find_strategy("Purge")
    test_pcall_nil(purge, base_ctx, "find_best_dispel_target", "Purge: find_best_dispel_target nil")

    -- CurePoison tests
    local cp = find_strategy("CurePoison")
    test_pcall_nil(cp, base_ctx, "has_debuff", "CurePoison: has_debuff nil")
    test_pcall_nil(cp, base_ctx, "is_spell_learned", "CurePoison: is_spell_learned nil")
    test_pcall_nil(cp, base_ctx, "spell_ready", "CurePoison: spell_ready nil")

    -- CureDisease tests
    local cd = find_strategy("CureDisease")
    test_pcall_nil(cd, base_ctx, "has_debuff", "CureDisease: has_debuff nil")
    test_pcall_nil(cd, base_ctx, "is_spell_learned", "CureDisease: is_spell_learned nil")
    test_pcall_nil(cd, base_ctx, "spell_ready", "CureDisease: spell_ready nil")

    return test_count
end

-- ============================================================================
-- RUN ALL TESTS
-- ============================================================================
local total = 0
total = total + test_mage()
total = total + test_warlock()
total = total + test_hunter()
total = total + test_priest()
total = total + test_rogue()
total = total + test_shaman()

print(string.format("PASS test_other_classes_middleware_nil_guard (%d tests)", total))
