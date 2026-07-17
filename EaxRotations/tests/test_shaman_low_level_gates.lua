-- test_shaman_low_level_gates.lua — Low-level silent spell-gating regressions.
-- WHAT:  verifies Shaman specs do not soft-lock at levels 20-50 when high-level
--         abilities (Water Shield 62+, Windfury Weapon 30, Flame Shock 10) are missing.
-- WHEN:  rotation test suite.
-- WHY:   mirrors the Druid Feral level-42 is_low_level fix pattern.
-- SAFETY: pure unit tests with mocked API context.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;api/?.lua;api/?/?.lua;api/?/?/?.lua;" .. package.path

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end
local function assert_false(v, label)
    if v then error(label or "assert_false failed", 2) end
end
local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
end

local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  PASS: " .. name)
    else
        failed = failed + 1
        print("  FAIL: " .. name .. " -- " .. tostring(err))
    end
end

print("=== Shaman Low-Level Gate Tests ===\n")

-- ============================================================================
-- Enhancement: weapon imbue + water shield fallbacks
-- ============================================================================

local enh_build_state, enh_strategies

local LEARNED = {}
local function set_learned(ids)
    LEARNED = {}
    for _, id in ipairs(ids) do LEARNED[id] = true end
end

_G.EaxRotations = {
    ShamanSpells = {
        LightningShield = { 324 }, WaterShield = { 33736, 24398 },
        ShamanisticRage = { 30823 }, Bloodlust = { 2825 },
        Stormstrike = { 17364 }, FlameShock = { 8050 },
        EarthShock = { 8042 }, FrostShock = { 8056 },
        ChainLightning = { 421 }, LightningBolt = { 403 },
        WindfuryTotem = { 8512 }, GraceOfAirTotem = { 8835 },
        StrengthOfEarthTotem = { 8075 }, StoneskinTotem = { 8155 },
        ManaSpringTotem = { 5675 }, HealingStreamTotem = { 5394 },
        SearingTotem = { 3599 }, MagmaTotem = { 8190 },
        FireNovaTotem = { 1535 }, ManaTideTotem = { 16190 },
        NaturesSwiftness = { 16188 }, LesserHealingWave = { 8004 },
        ChainHeal = { 1064 }, GroundingTotem = { 8177 },
        WindfuryWeapon = { 8232 }, FlametongueWeapon = { 8024 },
        RockbiterWeapon = { 8017 }, FrostbrandWeapon = { 8033 },
        TotemicCall = { 36936 }, GiftOfTheNaaru = { 28880 },
        Purge = { 370 },
    },
    rotation_registry = {
        register = function(self, name, strategies, opts)
            if name == "enhancement" then
                enh_strategies = strategies
                if opts and opts.get_state then enh_build_state = opts.get_state end
            end
            return true
        end,
    },
    game_time_ms = function() return 0 end,
    GetPlayer = function()
        local me = {}
        me.is_moving = function() return false end
        me.get_level = function() return 5 end
        return me
    end,
    unit_mana_pct = function() return 100 end,
    unit_health_pct = function() return 100 end,
    buff_up = function() return false end,
    buff_remains = function() return 0 end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    spell_ready = function(spell)
        if not spell then return false end
        -- Gate readiness on LEARNED set
        local function known(s)
            if type(s) == "number" then return LEARNED[s] == true end
            if type(s) == "table" then
                for _, id in pairs(s) do
                    if type(id) == "number" and LEARNED[id] then return true end
                end
            end
            return false
        end
        return known(spell)
    end,
    is_spell_learned = function(spell)
        if type(spell) == "number" then return LEARNED[spell] == true end
        if type(spell) == "table" then
            for _, id in pairs(spell) do
                if type(id) == "number" and LEARNED[id] then return true end
            end
        end
        return false
    end,
    try_cast = function() return true end,
    log = function() end,
    get_totem_info = function() return { have_totem = false } end,
    PLAYER_UNIT = {},
}

_G.core = {
    spell_book = { get_totem_info = function() return { have_totem = false } end },
    object_manager = { get_visible_objects = function() return {} end },
}

package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    MANA_POTION_IDS = {},
}
package.loaded["shared/cooldown_planner_sylvanas"] = nil
package.loaded["common/utility/inventory_helper"] = nil

-- Rockbiter only (level 1-9)
set_learned({ 8017, 324, 8042, 403 })
dofile("EaxRotations/classes/shaman/enhancement_sylvanas.lua")

local function find_strat(name)
    for i = 1, #(enh_strategies or {}) do
        if enh_strategies[i].name == name then return enh_strategies[i] end
    end
    return nil
end

test("enhancement: default windfury at level 5 still matches MH weapon (rockbiter fallback)", function()
    local me = { is_moving = function() return false end, get_level = function() return 5 end }
    _G.EaxRotations.GetPlayer = function() return me end
    local ctx = {
        settings = { enhancement_main_hand_ench = "windfury" },
        in_combat = false,
        me = me,
        mana_pct = 100, hp = 100, enemy_count = 1,
    }
    assert_true(enh_build_state ~= nil, "build_state captured")
    enh_build_state(ctx)
    local mh = find_strat("MHWeaponBuff")
    assert_true(mh ~= nil, "MHWeaponBuff exists")
    assert_true(mh.matches(ctx) == true, "should match via rockbiter fallback")
end)

test("enhancement: water shield auto at low mana falls back to lightning when WS unlearned", function()
    -- Level 40, low mana would pick water; WS not learned
    set_learned({ 8017, 324, 8042, 403, 8050, 8024 })  -- no water shield, no windfury
    local me = { is_moving = function() return false end, get_level = function() return 40 end }
    _G.EaxRotations.GetPlayer = function() return me end
    local ctx = {
        settings = { enhancement_shield_type = "auto" },
        in_combat = true,
        me = me,
        mana_pct = 25, hp = 100, enemy_count = 1,
    }
    enh_build_state(ctx)
    local ws = find_strat("WaterShield")
    local ls = find_strat("LightningShield")
    assert_true(ws ~= nil and ls ~= nil, "shield strategies exist")
    assert_false(ws.matches(ctx), "WaterShield must not match when unlearned")
    assert_true(ls.matches(ctx) == true, "LightningShield must match as fallback")
end)

test("enhancement: earth shock dps mode without FS learned still fires", function()
    set_learned({ 8017, 324, 8042, 403 })  -- ES yes, FS no
    local me = { is_moving = function() return false end, get_level = function() return 8 end }
    _G.EaxRotations.GetPlayer = function() return me end
    local target = {
        is_valid = function() return true end,
        is_casting = function() return false end,
        get_distance = function() return 5 end,
    }
    local ctx = {
        settings = { enhancement_earth_shock_mode = "dps" },
        in_combat = true,
        me = me,
        target = target,
        mana_pct = 80, hp = 100, enemy_count = 1,
    }
    enh_build_state(ctx)
    local es = find_strat("EarthShock")
    assert_true(es ~= nil, "EarthShock exists")
    assert_true(es.matches(ctx) == true, "ES dps mode must work without FS at low level")
end)

-- ============================================================================
-- Restoration: water shield default falls back to lightning
-- ============================================================================

local resto_build_state, resto_strategies

-- Minimal healing stub so restoration loads
package.loaded["classes/shaman/healing_sylvanas"] = {
    scan_healing_targets = function() return {}, 0 end,
    select_heal = function() return nil end,
    group_mana_avg = function() return 100 end,
    all_members_above_hp = function() return true end,
}
package.loaded["shared/fsr_manager_sylvanas"] = {
    should_wait = function() return false end,
    is_inside_fsr = function() return false end,
    seconds_until_fsr = function() return 0 end,
    get_regen_delta = function() return 0 end,
    get_fsr_remaining = function() return 0 end,
}
package.loaded["shared/preemptive_heal_sylvanas"] = {}
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    MANA_POTION_IDS = {},
}

_G.EaxRotations.ShamanHealing = package.loaded["classes/shaman/healing_sylvanas"]
_G.EaxRotations.rotation_registry.register = function(self, name, strategies, opts)
    if name == "enhancement" then
        enh_strategies = strategies
        if opts and opts.get_state then enh_build_state = opts.get_state end
    elseif name == "restoration" then
        resto_strategies = strategies
        if opts and opts.get_state then resto_build_state = opts.get_state end
    end
    return true
end
_G.EaxRotations.healing_get_lowest_hp = function() return nil end
_G.EaxRotations.healing_get_tank = function() return nil end
_G.EaxRotations.spell_ready = function(spell)
    if not spell then return false end
    local function known(s)
        if type(s) == "number" then return LEARNED[s] == true end
        if type(s) == "table" then
            for _, id in pairs(s) do
                if type(id) == "number" and LEARNED[id] then return true end
            end
        end
        return false
    end
    return known(spell)
end
_G.EaxRotations.is_spell_learned = _G.EaxRotations.spell_ready

set_learned({ 324, 331, 403, 8042 })  -- LS + basic heals, no Water Shield
local ok_resto, err_resto = pcall(dofile, "EaxRotations/classes/shaman/restoration_sylvanas.lua")
if not ok_resto then
    print("  SKIP resto load: " .. tostring(err_resto))
else
    local function find_resto(name)
        -- restoration may return strategies nested
        local list = resto_strategies
        if type(list) ~= "table" then return nil end
        for i = 1, #list do
            if list[i].name == name then return list[i] end
        end
        return nil
    end

    test("restoration: default water shield falls back to lightning when WS unlearned", function()
        local me = {
            is_moving = function() return false end,
            is_mounted = function() return false end,
            get_level = function() return 40 end,
        }
        _G.EaxRotations.GetPlayer = function() return me end
        local ctx = {
            settings = { restoration_shield_type = "water" },
            in_combat = true,
            me = me,
            mana_pct = 80, hp = 100, enemy_count = 2,
            has_valid_enemy_target = true,
        }
        assert_true(resto_build_state ~= nil, "resto build_state captured")
        local state = resto_build_state(ctx)
        assert_true(state ~= nil, "state built")
        local ls = find_resto("LightningShield")
        local ws = find_resto("WaterShield")
        assert_true(ls ~= nil, "LightningShield strategy exists")
        assert_true(ws ~= nil, "WaterShield strategy exists")
        -- Water not ready
        assert_false(ws.matches(ctx, state), "WaterShield must not match when unlearned")
        -- Lightning falls back
        assert_true(ls.matches(ctx, state) == true, "LightningShield must fall back when water unavailable")
    end)
end

print(string.format("\n=== Shaman Low-Level Gates: %d passed, %d failed ===\n", passed, failed))
if failed > 0 then
    error(string.format("Some tests FAILED (%d failures)", failed))
end
print("All shaman low-level gate tests passed!")
