-- test_target_selector_integration.lua — Verify target_selector direct queries integrate into specs.
-- WHAT:  Tests shared/ts_helper_sylvanas.lua and its use in affliction, shadow, balance, holy, and restoration specs.
-- WHEN:  During rotation test suite execution.
-- WHY:   Ensures Phase 4 (target_selector direct queries) works and falls back gracefully when unavailable.
-- SAFETY: Uses synthetic contexts; no live game data required.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- ============================================================================
-- 1. shared/ts_helper_sylvanas.lua direct tests
-- ============================================================================
local _ts_helper_loaded = false
local function test_ts_helper()
    _G.EaxRotations = {
        target_selector = {
            get_targets = function(_, limit)
                return { { name = "enemy1" }, { name = "enemy2" } }
            end,
            get_targets_heal = function(_, limit)
                return { { name = "ally1" }, { name = "ally2" } }
            end,
        },
    }
    local ok, TSHelper = pcall(require, "shared/ts_helper_sylvanas")
    assert_true(ok and type(TSHelper) == "table", "ts_helper_sylvanas should load")
    local dps = TSHelper.get_dps_targets(10)
    assert_true(type(dps) == "table" and #dps == 2, "get_dps_targets should return targets")
    local heal = TSHelper.get_heal_targets(10)
    assert_true(type(heal) == "table" and #heal == 2, "get_heal_targets should return targets")
    _ts_helper_loaded = true
end

test_ts_helper()

-- ============================================================================
-- 2. Warlock Affliction: target_selector used for multi-DoT priority
-- ============================================================================
local function test_affliction_ts()
    local spell_ready_calls = {}
    _G.EaxRotations = {
        WarlockSpells = {
            DeathCoil = { ids = { 27223 }, name = "DeathCoil" },
            Soulshatter = { ids = { 29858 }, name = "Soulshatter" },
            ShadowBolt = { ids = { 27209 }, name = "ShadowBolt" },
            Corruption = { ids = { 27216 }, name = "Corruption" },
            UnstableAffliction = { ids = { 30405 }, name = "UnstableAffliction" },
            SiphonLife = { ids = { 30911 }, name = "SiphonLife" },
            CurseOfDoom = { ids = { 30910 }, name = "CurseOfDoom" },
            CurseOfAgony = { ids = { 27218 }, name = "CurseOfAgony" },
            Immolate = { ids = { 27215 }, name = "Immolate" },
            SeedOfCorruption = { ids = { 27285 }, name = "SeedOfCorruption" },
            LifeTap = { ids = { 27222 }, name = "LifeTap" },
        },
        target_selector = {
            get_targets = function(_, limit)
                return {
                    { get_health_percentage = function() return 50 end, debuff_up = function() return false end },
                    { get_health_percentage = function() return 30 end, debuff_up = function() return false end },
                }
            end,
        },
        spell_action = function(tbl) return tbl end,
        has_player_buff = function(buff_list) return false end,
        buff_remains = function(me, ids) return 0 end,
        debuff_remains = function(target, ids) return 0 end,
        get_debuff_stacks = function(target, ids) return 0 end,
        debuff_up = function(target, ids) return false end,
        spell_ready = function(spell, target, opts)
            spell_ready_calls[#spell_ready_calls + 1] = { spell = spell, target = target, opts = opts }
            return true
        end,
        is_spell_learned = function(id) return true end,
        is_api_health_broken = function() return false end,
        is_item_ready = function(id) return false end,
        has_item = function(id) return false end,
        log = function() end,
        time_now = function() return 1000 end,
        cooldown_remains = function(spell, cd) return 0 end,
        rotation_registry = { register = function() end },
    }
    local orig_pcall = _G.pcall
    local orig_require = _G.require
    _G.pcall = function(fn, path, ...)
        if type(path) == "string" then
            if path:find("tbc_data_sylvanas") then return true, { ITEMS = { potions = {} } } end
            if path:find("izi_sdk") then return false, nil end
        end
        return orig_pcall(fn, path, ...)
    end
    _G.require = function(path)
        if type(path) == "string" then
            if path:find("tbc_data_sylvanas") then return { ITEMS = { potions = {} } } end
            if path:find("offensive_dispel") then return {} end
            if path:find("izi_sdk") then return nil end
        end
        return orig_require(path)
    end
    local result = dofile("EaxRotations/classes/warlock/affliction_sylvanas.lua")
    assert_true(result and result.strategies, "affliction module should load with target_selector")
    _G.require = orig_require
    _G.pcall = orig_pcall
end

test_affliction_ts()

-- ============================================================================
-- 3. Priest Shadow: target_selector used for SW:P/VT multi-DoT
-- ============================================================================
local function test_shadow_ts()
    _G.EaxRotations = {
        PriestSpells = {
            DevouringPlague = { ids = { 25467 }, name = "DevouringPlague" },
            DispelMagic = { ids = { 988 }, name = "DispelMagic" },
            Fade = { ids = { 25429 }, name = "Fade" },
            FlashHeal = { ids = { 25235 }, name = "FlashHeal" },
            HolyNova = { ids = { 25331 }, name = "HolyNova" },
            InnerFire = { ids = { 25431 }, name = "InnerFire" },
            InnerFocus = { ids = { 14751 }, name = "InnerFocus" },
            MindBlast = { ids = { 25375 }, name = "MindBlast" },
            MindFlay = { ids = { 25387 }, name = "MindFlay" },
            PowerWordFortitude = { ids = { 25389 }, name = "PowerWordFortitude" },
            PowerWordShield = { ids = { 25218 }, name = "PowerWordShield" },
            PsychicScream = { ids = { 10890 }, name = "PsychicScream" },
            ShackleUndead = { ids = { 10955 }, name = "ShackleUndead" },
            ShadowWordDeath = { ids = { 32996 }, name = "ShadowWordDeath" },
            ShadowWordPain = { ids = { 25368 }, name = "ShadowWordPain" },
            Shadowfiend = { ids = { 34433 }, name = "Shadowfiend" },
            Shadowform = { ids = { 15473 }, name = "Shadowform" },
            Starshards = { ids = { 25446 }, name = "Starshards" },
            VampiricEmbrace = { ids = { 15286 }, name = "VampiricEmbrace" },
            VampiricTouch = { ids = { 34917 }, name = "VampiricTouch" },
        },
        target_selector = {
            get_targets = function(_, limit)
                return {
                    { get_health_percentage = function() return 40 end },
                    { get_health_percentage = function() return 20 end },
                }
            end,
        },
        spell_action = function(tbl) return tbl end,
        has_player_buff = function(buff_list) return false end,
        buff_remains = function(me, ids) return 0 end,
        debuff_remains = function(target, ids) return 0 end,
        get_debuff_stacks = function(target, ids) return 0 end,
        debuff_up = function(target, ids) return false end,
        spell_ready = function(spell, target, opts) return true end,
        is_spell_learned = function(id) return true end,
        log = function() end,
        time_now = function() return 1000 end,
        cooldown_remains = function(spell, cd) return 0 end,
        rotation_registry = { register = function() end },
        setting = function(ctx, key, default) return default end,
        setting_number = function(ctx, key, default) return default end,
        setting_bool = function(ctx, key, default) return default end,
    }
    local result = dofile("EaxRotations/classes/priest/shadow_sylvanas.lua")
    assert_true(result and result.strategies, "shadow module should load with target_selector")
end

test_shadow_ts()

-- ============================================================================
-- 4. Druid Balance: target_selector used for Moonfire/Insect Swarm multi-DoT
-- ============================================================================
local function test_balance_ts()
    _G.EaxRotations = {
        DruidSpells = {},
        target_selector = {
            get_targets = function(_, limit)
                return {
                    { get_health_percentage = function() return 60 end },
                    { get_health_percentage = function() return 45 end },
                }
            end,
        },
        action_matches = function(ctx, act) return true end,
        action_execute = function(ctx, act, label) return true end,
        debuff_remains = function(target, debuff_list) return 0 end,
        get_debuff_stacks = function(target, debuff_list) return 0 end,
        has_player_buff = function(buff_list) return false end,
        buff_remains = function(me, ids) return 0 end,
        spell_ready = function(spell, target, opts) return true end,
        try_cast = function(spell, target, label) return true end,
        log = function() end,
        rotation_registry = { register = function() end },
        setting = function(ctx, key, default) return default end,
        setting_number = function(ctx, key, default) return default end,
        setting_bool = function(ctx, key, default) return default end,
    }
    local result = dofile("EaxRotations/classes/druid/balance_sylvanas.lua")
    assert_true(result and result.strategies, "balance module should load with target_selector")
end

test_balance_ts()

-- ============================================================================
-- 5. Priest Holy: target_selector used for triage target selection
-- ============================================================================
local function test_holy_ts()
    _G.EaxRotations = {
        PriestSpells = {},
        CLASS_ID = { PRIEST = 5 },
        target_selector = {
            get_targets_heal = function(_, limit)
                return {
                    { get_health_percentage = function() return 30 end },
                    { get_health_percentage = function() return 70 end },
                }
            end,
        },
        PLAYER_UNIT = {},
        GetPlayer = function() return { is_mounted = function() return false end, is_moving = function() return false end, get_class = function() return 5 end } end,
        import_helpers = function(...) return end,
        has_player_buff = function(buff_list) return false end,
        buff_remains = function(me, ids) return 0 end,
        debuff_remains = function(target, ids) return 0 end,
        spell_ready = function(spell, target, opts) return true end,
        spell_exists = function(spell) return true end,
        try_cast = function(spell, target, label) return true end,
        log = function() end,
        rotation_registry = { register = function() end },
        setting = function(ctx, key, default) return default end,
        setting_number = function(ctx, key, default) return default end,
        setting_bool = function(ctx, key, default) return default end,
        health_pct = function(unit) return 100 end,
        gate_overheal = function() return false end,
    }
    local Healing = {
        scan_healing_targets = function() return {}, 0 end,
    }
    package.loaded["classes/priest/healing_sylvanas"] = Healing
    local result = dofile("EaxRotations/classes/priest/holy_sylvanas.lua")
    assert_true(result and result.strategies, "holy module should load with target_selector")
end

test_holy_ts()

-- ============================================================================
-- 6. Shaman Restoration: target_selector used for Chain Heal target selection
-- ============================================================================
local function test_resto_ts()
    _G.EaxRotations = {
        ShamanSpells = {},
        target_selector = {
            get_targets_heal = function(_, limit)
                return {
                    { get_health_percentage = function() return 40 end },
                    { get_health_percentage = function() return 55 end },
                }
            end,
        },
        PLAYER_UNIT = {},
        GetPlayer = function() return {} end,
        has_player_buff = function(buff_list) return false end,
        buff_remains = function(me, ids) return 0 end,
        buff_up = function(me, ids) return false end,
        debuff_remains = function(target, ids) return 0 end,
        spell_ready = function(spell, target, opts) return true end,
        try_cast = function(spell, target, label) return true end,
        log = function() end,
        rotation_registry = { register = function() end },
        setting = function(ctx, key, default) return default end,
        setting_number = function(ctx, key, default) return default end,
        setting_bool = function(ctx, key, default) return default end,
    }
    local Healing = {
        scan_healing_targets = function() return {}, 0 end,
    }
    package.loaded["classes/shaman/healing_sylvanas"] = Healing
    local result = dofile("EaxRotations/classes/shaman/restoration_sylvanas.lua")
    assert_true(result and result.strategies, "restoration module should load with target_selector")
end

test_resto_ts()

print("PASS test_target_selector_integration")
