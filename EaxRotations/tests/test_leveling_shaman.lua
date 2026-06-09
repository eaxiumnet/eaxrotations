-- Unit tests for Shaman leveling rotation
-- Tests build_state, all 14 match functions, strategy ordering,
-- helper functions, and edge case handling

local EAXROTATIONS_DIR = "C:/newbot/scripts/EaxRotations"
if not package.path:find(EAXROTATIONS_DIR, 1, true) then
    package.path = package.path .. ";" .. EAXROTATIONS_DIR .. "/?.lua"
end

local passed = 0
local failed = 0
local assertions = 0

local function assert_true(v, label)
    assertions = assertions + 1
    if not v then error(label or "assert_true failed", 2) end
end

local function assert_false(v, label)
    assertions = assertions + 1
    if v then error(label or "assert_false failed: expected false", 2) end
end

local function assert_eq(a, b, label)
    assertions = assertions + 1
    if a ~= b then
        error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2)
    end
end

local function assert_nil(v, label)
    assertions = assertions + 1
    if v ~= nil then error(label or "assert_nil failed: expected nil got " .. tostring(v), 2) end
end

local function assert_not_nil(v, label)
    assertions = assertions + 1
    if v == nil then error(label or "assert_not_nil failed: expected non-nil", 2) end
end

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

-- ============================================================================
-- Mock environment builder
-- ============================================================================

local MOCK_SHAMAN_SPELLS = {
    LightningBolt = { 25449 },
    EarthShock = { 25454 },
    FlameShock = { 25457 },
    FrostShock = { 25464 },
    ChainLightning = { 25442 },
    LightningShield = { 25472 },
    WaterShield = { 33736 },
    HealingWave = { 25396 },
    LesserHealingWave = { 25420 },
    GhostWolf = { 2645 },
    Purge = { 370 },
    EarthbindTotem = { 2484 },
    StoneclawTotem = { 2487 },
    FireNovaTotem = { 25459 },
    SearingTotem = { 25295 },
    StrengthOfEarthTotem = { 25587 },
    GraceOfAirTotem = { 25360 },
    ManaSpringTotem = { 25570 },
    HealingStreamTotem = { 25567 },
    GroundingTotem = { 8177 },
    WindfuryTotem = { 8516 },
    TremorTotem = { 8143 },
    WindfuryWeapon = { 25485 },
    RockbiterWeapon = { 25487 },
    FlametongueWeapon = { 25489 },
    FrostbrandWeapon = { 25493 },
    Shoot = { 5019 },
}

--- Create a fresh mock environment. Returns (NS, core, mock_player, mock_target).
local function build_mock_env()
    local NS = {}
    local core = {}

    core.time = function() return 100 end
    core.game_time = function() return 100000 end

    core.spell_book = {
        get_spell_cooldown = function() return 0 end,
        get_global_cooldown = function() return 0 end,
        is_spell_learned = function() return true end,
        get_totem_info = function() return nil end,
    }

    core.input = {
        cast_target_spell = function(spell_id, target)
            return spell_id ~= nil and target ~= nil
        end,
    }

    local mock_state = {
        health = 8000,
        max_health = 10000,
        mana = 5000,
        max_mana = 10000,
        buffs = {},
        debuffs = {},
        is_casting = false,
        target_guid = "mock-target",
    }

    local mock_target = {
        is_valid = function() return true end,
        get_health = function() return 8000 end,
        get_max_health = function() return 10000 end,
        is_casting = function() return mock_state.is_casting end,
        is_alive = function() return true end,
        get_guid = function() return mock_state.target_guid end,
        get_distance = function(other) return 5 end,
        get_health_percentage = function() return 80 end,
    }

    local mock_player = {
        is_valid = function() return true end,
        get_health = function() return mock_state.health end,
        get_max_health = function() return mock_state.max_health end,
        get_mana = function() return mock_state.mana end,
        get_max_mana = function() return mock_state.max_mana end,
        has_buff = function(id)
            if not id then return false end
            local remains = mock_state.buffs[id]
            return remains ~= nil and remains > 0
        end,
        has_debuff = function(id) return false end,
        get_class = function() return 7 end,
        is_in_combat = function() return false end,
        get_target = function() return mock_target end,
        get_position = function() return { x = 0, y = 0, z = 0 } end,
        get_item_at_inventory_slot = function() return nil end,
        get_totem_info = function() return nil end,
    }

    NS.log = function() end
    NS.log_warning = function() end
    NS.spell_ready = function(spell_action, target, opts)
        if not spell_action then return false end
        return true
    end
    NS.spell_exists = function(spell_id) return true end
    NS.try_cast = function(spell_action, target, label, opts)
        if not spell_action then return false end
        return true
    end
    NS.get_local_player = function() return mock_player end
    NS.GetPlayer = function() return mock_player end
    NS.get_target = function() return mock_target end
    NS.get_distance = function(target)
        if not target then return nil end
        return 10
    end
    NS.debuff_remains = function(target, spell)
        if not target or not spell then return 0 end
        return 0
    end
    NS.buff_remains = function(unit, buff_ids) return 0 end
    NS.buff_up = function(unit, buff_ids)
        if not unit or not buff_ids then return false end
        return false
    end
    NS.game_time_ms = function() return 100000 end

    -- rotation_registry mock
    NS.rotation_registry = {
        _registrations = {},
        register = function(self, key, strategies, opts)
            self._registrations[key] = { strategies = strategies, opts = opts }
        end,
        set_class_config = function(self, config) end,
    }

    NS.ShamanSpells = {}
    for k, v in pairs(MOCK_SHAMAN_SPELLS) do
        NS.ShamanSpells[k] = v
    end

    _G.core = core
    _G.EaxRotations = NS

    return NS, core, mock_player, mock_target, mock_state
end

--- Create a mock context with sensible defaults.
local function make_context(overrides)
    local ctx = {
        is_solo = false,
        is_leveling = true,
        in_combat = true,
        mana_pct = 80,
        hp = 100,
        enemies_count = 1,
        is_moving = false,
        has_valid_enemy_target = false,
        me = {
            is_valid = function() return true end,
            get_health = function() return 10000 end,
            get_max_health = function() return 10000 end,
            has_buff = function(id) return false end,
            get_position = function() return { x = 0, y = 0, z = 0 } end,
            get_class = function() return 8 end,
            get_aura = function(id) return nil end,
            buff_up = function(id) return false end,
        },
        target = {
            is_valid = function() return true end,
            get_health = function() return 8000 end,
            get_max_health = function() return 10000 end,
            is_casting = function() return false end,
            is_alive = function() return true end,
            get_guid = function() return "mock-target" end,
            get_distance = function(other) return 5 end,
            get_health_percentage = function() return 80 end,
        },
        pet = { guid = "mock-pet" },
        settings = {
            playstyle = "leveling",
            active_playstyle = "leveling",
            use_interrupt = true,
            leveling_wand_threshold = 30,
            leveling_heal_hp = 50,
            leveling_use_shocks = true,
            leveling_default_shock = "flame",
            leveling_use_weapon_imbue = true,
            leveling_weapon_imbue = "windfury",
            leveling_use_totems = true,
            leveling_use_searing_totem = true,
            leveling_use_strength_totem = true,
            leveling_use_water_totem = true,
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
-- Load the Shaman leveling module
-- ============================================================================

local NS, core, mock_player, mock_target, mock_state = build_mock_env()
local ok, module = pcall(dofile, "EaxRotations/classes/shaman/leveling_sylvanas.lua")
if not ok then
    error("Failed to load Shaman leveling module: " .. tostring(module))
end
if not module or type(module) ~= "table" then
    error("Shaman leveling module should return a table of strategies")
end

local reg = NS.rotation_registry._registrations["leveling"]
if not reg then
    error("Shaman leveling module should register as 'leveling' in rotation_registry")
end
local strategies = reg.strategies
local get_state = reg.opts.get_state

print("=== Shaman Leveling Unit Tests ===\n")
print("Loaded " .. tostring(#strategies) .. " strategies\n")

-- ============================================================================
-- Test: build_state
-- ============================================================================

test("build_state: nil context returns nil", function()
    assert_nil(get_state(nil), "nil context should return nil")
end)

test("build_state: minimal context returns full state table", function()
    local ctx = make_context()
    local state = get_state(ctx)
    assert_not_nil(state, "should return a table")
    assert_eq(state.in_combat, true, "in_combat from context")
    assert_eq(state.mana_pct, 80, "mana_pct from context")
    assert_eq(state.hp, 100, "hp from context")
    assert_eq(state.enemies, 1, "enemies from context")
    assert_false(state.is_moving, "is_moving from context")
    assert_not_nil(state.target, "target from context")
end)

test("build_state: missing context fields use defaults", function()
    local ctx = {
        is_solo = false,
        is_leveling = true,
        me = { is_valid = function() return true end, has_buff = function(id) return false end, get_health = function() return 10000 end, get_max_health = function() return 10000 end },
        target = { is_valid = function() return true end, get_health = function() return 8000 end, get_max_health = function() return 10000 end, is_casting = function() return false end, is_alive = function() return true end, get_guid = function() return "mock-target" end, get_distance = function() return 5 end, get_health_percentage = function() return 80 end },
        settings = {},
    }
    local state = get_state(ctx)
    assert_not_nil(state, "should return a table")
    assert_eq(state.hp, 100, "default hp = 100")
    assert_eq(state.mana_pct, 100, "default mana_pct = 100")
    assert_eq(state.enemies, 0, "default enemies = 0")
    assert_false(state.is_moving, "default is_moving = false")
    assert_false(state.in_combat, "default in_combat = false")
end)

test("build_state: spell readiness fields populated", function()
    local ctx = make_context()
    local state = get_state(ctx)
    assert_true(state.lightning_bolt_ready, "lightning_bolt_ready")
    assert_true(state.earth_shock_ready, "earth_shock_ready")
    assert_true(state.flame_shock_ready, "flame_shock_ready")
    assert_true(state.frost_shock_ready, "frost_shock_ready")
    assert_true(state.chain_lightning_ready, "chain_lightning_ready")
    assert_true(state.lightning_shield_ready, "lightning_shield_ready")
    assert_true(state.water_shield_ready, "water_shield_ready")
    assert_true(state.healing_wave_ready, "healing_wave_ready")
    assert_true(state.ghost_wolf_ready, "ghost_wolf_ready")
    assert_true(state.earthbind_totem_ready, "earthbind_totem_ready")
    assert_true(state.searing_totem_ready, "searing_totem_ready")
    assert_true(state.strength_of_earth_ready, "strength_of_earth_ready")
    assert_true(state.mana_spring_ready, "mana_spring_ready")
    assert_true(state.grounding_totem_ready, "grounding_totem_ready")
end)

test("build_state: custom settings from context", function()
    local ctx = make_context()
    ctx.settings.leveling_wand_threshold = 15
    ctx.settings.leveling_heal_hp = 30
    ctx.settings.leveling_use_shocks = false
    ctx.settings.leveling_default_shock = "earth"
    ctx.settings.leveling_use_weapon_imbue = false
    ctx.settings.leveling_use_totems = false
    local state = get_state(ctx)
    assert_eq(state.wand_threshold, 15, "wand_threshold from settings")
    assert_eq(state.heal_hp, 30, "heal_hp from settings")
    assert_false(state.use_shocks, "use_shocks from settings")
    assert_eq(state.default_shock, "earth", "default_shock from settings")
    assert_false(state.use_weapon_imbue, "use_weapon_imbue from settings")
    assert_false(state.use_totems, "use_totems from settings")
end)

test("build_state: missing settings uses defaults", function()
    local ctx = make_context({settings = {}})
    local state = get_state(ctx)
    assert_eq(state.wand_threshold, 30, "default wand_threshold = 30")
    assert_eq(state.heal_hp, 50, "default heal_hp = 50")
    assert_true(state.use_shocks, "default use_shocks = true")
    assert_eq(state.default_shock, "flame", "default default_shock = flame")
    assert_true(state.use_weapon_imbue, "default use_weapon_imbue = true")
    assert_true(state.use_totems, "default use_totems = true")
end)

-- ============================================================================
-- Test: weapon_imbue_matches (strategy #1)
-- ============================================================================

test("weapon_imbue_matches: OOC, enabled, no imbue, ready -> true", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.use_weapon_imbue = true
    state.weapon_imbue = { 25485 }
    state.has_mainhand_imbue = false
    state.weapon_imbue_api_known = true
    assert_true(strategies[1].matches(ctx, state), "OOC without imbue should match")
end)

test("weapon_imbue_matches: in combat -> false", function()
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.use_weapon_imbue = true
    state.has_mainhand_imbue = false
    assert_false(strategies[1].matches(ctx, state), "in combat should not match")
end)

test("weapon_imbue_matches: disabled -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.use_weapon_imbue = false
    state.has_mainhand_imbue = false
    assert_false(strategies[1].matches(ctx, state), "disabled should not match")
end)

test("weapon_imbue_matches: already has imbue -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.use_weapon_imbue = true
    state.has_mainhand_imbue = true
    assert_false(strategies[1].matches(ctx, state), "already imbued should not match")
end)

-- ============================================================================
-- Test: lightning_shield_matches (strategy #2)
-- ============================================================================

test("lightning_shield_matches: OOC, ready, no shield -> true", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_lightning_shield = false
    state.lightning_shield_ready = true
    assert_true(strategies[2].matches(ctx, state), "OOC without shield should match")
end)

test("lightning_shield_matches: in combat -> false", function()
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.has_lightning_shield = false
    state.lightning_shield_ready = true
    assert_false(strategies[2].matches(ctx, state), "in combat should not match")
end)

test("lightning_shield_matches: already has shield -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_lightning_shield = true
    state.lightning_shield_ready = true
    assert_false(strategies[2].matches(ctx, state), "already shielded should not match")
end)

-- ============================================================================
-- Test: earth_shock_interrupt_matches (strategy #4)
-- ============================================================================

test("earth_shock_interrupt: ready, target casting -> true", function()
    local ctx = make_context()
    ctx.target.is_casting = function() return true end
    local state = get_state(ctx)
    state.earth_shock_ready = true
    assert_true(strategies[4].matches(ctx, state), "target casting should match")
end)

test("earth_shock_interrupt: target not casting -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.earth_shock_ready = true
    assert_false(strategies[4].matches(ctx, state), "target not casting should not match")
end)

test("earth_shock_interrupt: interrupt disabled -> false", function()
    local ctx = make_context()
    ctx.settings.use_interrupt = false
    local state = get_state(ctx)
    state.earth_shock_ready = true
    state.use_interrupt = false
    assert_false(strategies[4].matches(ctx, state), "interrupt disabled should not match")
end)

test("earth_shock_interrupt: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.in_combat = false
    state.earth_shock_ready = true
    assert_false(strategies[4].matches(ctx, state), "OOC should not match")
end)

-- ============================================================================
-- Test: healing_wave_matches (strategy #6)
-- ============================================================================

test("healing_wave_matches: ready, HP below threshold -> true", function()
    local ctx = make_context({hp = 30})
    local state = get_state(ctx)
    state.healing_wave_ready = true
    state.hp = 30
    state.heal_hp = 50
    assert_true(strategies[6].matches(ctx, state), "HP below 50 should match")
end)

test("healing_wave_matches: HP above threshold -> false", function()
    local ctx = make_context({hp = 80})
    local state = get_state(ctx)
    state.healing_wave_ready = true
    state.hp = 80
    state.heal_hp = 50
    assert_false(strategies[6].matches(ctx, state), "HP above 50 should not match")
end)

test("healing_wave_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, hp = 30})
    local state = get_state(ctx)
    state.healing_wave_ready = true
    state.in_combat = false
    state.hp = 30
    assert_false(strategies[6].matches(ctx, state), "OOC should not match")
end)

-- ============================================================================
-- Test: searing_totem_matches (strategy #8)
-- ============================================================================

test("searing_totem_matches: in combat, ready, enabled, no existing totem -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.searing_totem_ready = true
    state.use_totems = true
    state.use_searing_totem = true
    state.mana_pct = 80
    assert_true(strategies[8].matches(ctx, state), "should match in combat")
end)

test("searing_totem_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.searing_totem_ready = true
    state.use_totems = true
    state.use_searing_totem = true
    state.in_combat = false
    assert_false(strategies[8].matches(ctx, state), "OOC should not match")
end)

test("searing_totem_matches: totems disabled -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.searing_totem_ready = true
    state.use_totems = false
    assert_false(strategies[8].matches(ctx, state), "totems disabled should not match")
end)

-- ============================================================================
-- Test: strength_totem_matches (strategy #9)
-- ============================================================================

test("strength_totem_matches: in combat, ready, enabled -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.strength_of_earth_ready = true
    state.use_totems = true
    state.use_strength_totem = true
    state.mana_pct = 80
    assert_true(strategies[9].matches(ctx, state), "should match in combat")
end)

test("strength_totem_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.strength_of_earth_ready = true
    state.use_totems = true
    state.use_strength_totem = true
    state.in_combat = false
    assert_false(strategies[9].matches(ctx, state), "OOC should not match")
end)

-- ============================================================================
-- Test: water_totem_matches (strategy #10)
-- ============================================================================

test("water_totem_matches: ready, mana below threshold -> true", function()
    local ctx = make_context({mana_pct = 60})
    local state = get_state(ctx)
    state.mana_spring_ready = true
    state.healing_stream_ready = true
    state.use_totems = true
    state.use_water_totem = true
    state.mana_pct = 60
    state.hp = 100
    assert_true(strategies[10].matches(ctx, state), "should match when mana < 85")
end)

test("water_totem_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, mana_pct = 60})
    local state = get_state(ctx)
    state.mana_spring_ready = true
    state.use_totems = true
    state.use_water_totem = true
    state.in_combat = false
    state.mana_pct = 60
    assert_false(strategies[10].matches(ctx, state), "OOC should not match")
end)

test("water_totem_matches: totems disabled -> false", function()
    local ctx = make_context({mana_pct = 60})
    local state = get_state(ctx)
    state.mana_spring_ready = true
    state.use_totems = false
    state.mana_pct = 60
    assert_false(strategies[10].matches(ctx, state), "totems disabled should not match")
end)

-- ============================================================================
-- Test: chain_lightning_matches (strategy #14)
-- ============================================================================

test("chain_lightning_matches: ready, 2+ enemies -> true", function()
    local ctx = make_context({enemies_count = 3})
    local state = get_state(ctx)
    state.chain_lightning_ready = true
    state.enemies = 3
    assert_true(strategies[14].matches(ctx, state), "3 enemies should match")
end)

test("chain_lightning_matches: single enemy -> false", function()
    local ctx = make_context({enemies_count = 1})
    local state = get_state(ctx)
    state.chain_lightning_ready = true
    state.enemies = 1
    assert_false(strategies[14].matches(ctx, state), "1 enemy should not match")
end)

-- ============================================================================
-- Test: flame_shock_matches (strategy #15)
-- ============================================================================

test("flame_shock_matches: ready, default shock = flame, DoT expired -> true", function()
    local ctx = make_context()
    NS.debuff_remains = function(target, spell) return 0 end
    local state = get_state(ctx)
    state.flame_shock_ready = true
    state.use_shocks = true
    state.default_shock = "flame"
    assert_true(strategies[15].matches(ctx, state), "should match when using flame shock")
end)

test("flame_shock_matches: default shock is earth -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.flame_shock_ready = true
    state.use_shocks = true
    state.default_shock = "earth"
    assert_false(strategies[15].matches(ctx, state), "should not match with earth as default")
end)

test("flame_shock_matches: DoT still active -> false", function()
    local ctx = make_context()
    NS.debuff_remains = function(target, spell) return 10 end
    local state = get_state(ctx)
    state.flame_shock_ready = true
    state.use_shocks = true
    state.default_shock = "flame"
    assert_false(strategies[15].matches(ctx, state), "active DoT should not match")
    NS.debuff_remains = function(target, spell) return 0 end
end)

test("flame_shock_matches: shocks disabled -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.flame_shock_ready = true
    state.use_shocks = false
    state.default_shock = "flame"
    assert_false(strategies[15].matches(ctx, state), "shocks disabled should not match")
end)

-- ============================================================================
-- Test: earth_shock_dps_matches (strategy #16)
-- ============================================================================

test("earth_shock_dps_matches: ready, default shock = earth -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.earth_shock_ready = true
    state.use_shocks = true
    state.default_shock = "earth"
    assert_true(strategies[16].matches(ctx, state), "should match with earth as default")
end)

test("earth_shock_dps_matches: default shock is flame -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.earth_shock_ready = true
    state.use_shocks = true
    state.default_shock = "flame"
    assert_false(strategies[16].matches(ctx, state), "should not match with flame as default")
end)

-- ============================================================================
-- Test: frost_shock_matches (strategy #18)
-- ============================================================================

test("frost_shock_matches: ready, default shock = frost -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.frost_shock_ready = true
    state.use_shocks = true
    state.default_shock = "frost"
    assert_true(strategies[18].matches(ctx, state), "should match with frost as default")
end)

test("frost_shock_matches: default shock is flame -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.frost_shock_ready = true
    state.use_shocks = true
    state.default_shock = "flame"
    assert_false(strategies[18].matches(ctx, state), "should not match with flame as default")
end)

-- ============================================================================
-- Test: earthbind_totem_matches (strategy #19)
-- ============================================================================

test("earthbind_totem_matches: 3+ enemies, low HP -> true", function()
    local ctx = make_context({hp = 40, enemies_count = 4})
    local state = get_state(ctx)
    state.earthbind_totem_ready = true
    state.hp = 40
    state.enemies = 4
    assert_true(strategies[19].matches(ctx, state), "overwhelmed should match")
end)

test("earthbind_totem_matches: high HP -> false", function()
    local ctx = make_context({hp = 80, enemies_count = 4})
    local state = get_state(ctx)
    state.earthbind_totem_ready = true
    state.hp = 80
    state.enemies = 4
    assert_false(strategies[19].matches(ctx, state), "high HP should not match")
end)

test("earthbind_totem_matches: 1 enemy -> false", function()
    local ctx = make_context({hp = 40, enemies_count = 1})
    local state = get_state(ctx)
    state.earthbind_totem_ready = true
    state.hp = 40
    state.enemies = 1
    assert_false(strategies[19].matches(ctx, state), "single enemy should not match")
end)

-- ============================================================================
-- Test: lightning_bolt_matches (strategy #21)
-- ============================================================================

test("lightning_bolt_matches: ready, not moving -> true", function()
    local ctx = make_context({is_moving = false})
    local state = get_state(ctx)
    state.lightning_bolt_ready = true
    state.is_moving = false
    assert_true(strategies[21].matches(ctx, state), "stationary should match")
end)

test("lightning_bolt_matches: moving -> false", function()
    local ctx = make_context({is_moving = true})
    local state = get_state(ctx)
    state.lightning_bolt_ready = true
    state.is_moving = true
    assert_false(strategies[21].matches(ctx, state), "moving should not match")
end)

test("lightning_bolt_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.lightning_bolt_ready = true
    state.target = nil
    assert_false(strategies[21].matches(ctx, state), "no target should not match")
end)

-- ============================================================================
-- Test: ghost_wolf_matches (strategy #22)
-- ============================================================================

test("ghost_wolf_matches: OOC, ready, target far -> true", function()
    local ctx = make_context({in_combat = false})
    NS.get_distance = function(target) return 25 end
    local state = get_state(ctx)
    state.ghost_wolf_ready = true
    state.in_combat = false
    assert_true(strategies[22].matches(ctx, state), "OOC with distant target should match")
end)

test("ghost_wolf_matches: in combat -> false", function()
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.ghost_wolf_ready = true
    state.in_combat = true
    assert_false(strategies[22].matches(ctx, state), "in combat should not match")
end)

test("ghost_wolf_matches: target too close -> false", function()
    local ctx = make_context({in_combat = false})
    NS.get_distance = function(target) return 10 end
    local state = get_state(ctx)
    state.ghost_wolf_ready = true
    state.in_combat = false
    assert_false(strategies[22].matches(ctx, state), "target close should not match")
end)

test("ghost_wolf_matches: no target -> false", function()
    local ctx = make_context({in_combat = false, target = nil})
    local state = get_state(ctx)
    state.ghost_wolf_ready = true
    state.in_combat = false
    assert_false(strategies[22].matches(ctx, state), "no target should not match")
end)

-- ============================================================================
-- Test: wand_matches (strategy #23, via create_wand_matches)
-- ============================================================================

test("wand_matches: low mana -> true", function()
    local ctx = make_context({mana_pct = 10})
    local state = get_state(ctx)
    state.mana_pct = 10
    state.wand_threshold = 30
    state.wand_learned = true
    assert_true(strategies[23].matches(ctx, state), "low mana should match")
end)

test("wand_matches: enough mana -> false", function()
    local ctx = make_context({mana_pct = 80})
    local state = get_state(ctx)
    state.mana_pct = 80
    state.wand_threshold = 30
    state.wand_learned = true
    assert_false(strategies[23].matches(ctx, state), "enough mana should not match")
end)

test("wand_matches: wand not learned -> false", function()
    local ctx = make_context({mana_pct = 10})
    local state = get_state(ctx)
    state.mana_pct = 10
    state.wand_learned = false
    assert_false(strategies[23].matches(ctx, state), "wand not learned should not match")
end)

-- ============================================================================
-- Test: Strategy priority ordering
-- ============================================================================

test("strategies: 23 strategies in correct priority order", function()
    local expected = {
        "WeaponImbue",
        "LightningShield",
        "WaterShield",
        "EarthShockInterrupt",
        "ShamanisticRage",
        "HealingWave",
        "LesserHealingWave",
        "SearingTotem",
        "StrengthOfEarthTotem",
        "WaterTotem",
        "GroundingTotem",
        "TremorTotem",
        "Stormstrike",
        "ChainLightning",
        "FlameShock",
        "EarthShock",
        "Purge",
        "FrostShock",
        "EarthbindTotem",
        "StoneclawTotem",
        "LightningBolt",
        "GhostWolf",
        "Wand",
    }
    assert_eq(#strategies, 23, "should have 23 strategies after adding WaterShield, ShamanisticRage, LesserHealingWave, GroundingTotem, TremorTotem, Purge, StoneclawTotem, Stormstrike")
    for i, name in ipairs(expected) do
        assert_eq(strategies[i].name, name, "strategy[" .. i .. "] should be " .. name)
    end
end)

test("strategies: every strategy has name, matches, execute", function()
    for i, s in ipairs(strategies) do
        assert_true(type(s.name) == "string", "strategy[" .. i .. "] should have string name")
        assert_true(type(s.matches) == "function", "strategy[" .. i .. "] matches should be function")
        assert_true(type(s.execute) == "function", "strategy[" .. i .. "] execute should be function")
    end
end)

-- ============================================================================
-- Test: Execute functions (smoke tests)
-- ============================================================================

test("execute_WeaponImbue: does not crash with context", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    local ok, result = pcall(strategies[1].execute, ctx, state)
    assert_true(ok, "execute should not throw")
end)

test("execute_LightningBolt: does not crash with context", function()
    local ctx = make_context()
    local ok, result = pcall(strategies[21].execute, ctx)
    assert_true(ok, "execute with context should not throw")
end)

-- ============================================================================
-- Test: Nil guard
-- ============================================================================

test("module: returns nil when EaxRotations is nil", function()
    local _, c = build_mock_env()
    _G.EaxRotations = nil
    local nil_mod = dofile("EaxRotations/classes/shaman/leveling_sylvanas.lua")
    assert_nil(nil_mod, "should return nil when NS is nil")
    _G.EaxRotations = NS
end)

test("match_functions: all handle nil context -> false", function()
    for i, s in ipairs(strategies) do
        local ok, result = pcall(s.matches, nil, {})
        assert_true(ok, "strategy[" .. i .. "] (" .. s.name .. ") matches(nil, {}) should not throw")
    end
end)

test("match_functions: all handle nil state -> no crash", function()
    local ctx = make_context()
    for i, s in ipairs(strategies) do
        local ok, result = pcall(s.matches, ctx, nil)
        assert_true(ok, "strategy[" .. i .. "] (" .. s.name .. ") matches(ctx, nil) should not throw")
    end
end)

-- ============================================================================
-- Test: Scenario integration
-- ============================================================================

test("rotation: OOC scenario - only OOC buffs should match", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.use_weapon_imbue = true
    state.weapon_imbue = { 25485 }
    state.has_mainhand_imbue = false
    state.weapon_imbue_api_known = true
    state.has_lightning_shield = false
    state.lightning_shield_ready = true
    state.ghost_wolf_ready = true

    -- WeaponImbue should match
    assert_true(strategies[1].matches(ctx, state), "WeaponImbue should match OOC")
    -- LightningShield should match
    assert_true(strategies[2].matches(ctx, state), "LightningShield should match OOC")

    -- Combat abilities should not match OOC
    -- GhostWolf checks NS.get_distance which returns 10, so target too close
    -- All other strategies require in_combat
    for i = 3, 14 do
        local ok, matched = pcall(strategies[i].matches, ctx, state)
        assert_true(ok, "strategy[" .. i .. "] matches should not throw")
    end
end)

test("rotation: no crashes when evaluating all strategies in sequence", function()
    local ctx = make_context({in_combat = true, mana_pct = 80, hp = 100, enemies_count = 1, is_moving = false})
    local state = get_state(ctx)
    assert_not_nil(state, "state should be built")
    for i, s in ipairs(strategies) do
        local ok_match, matched = pcall(s.matches, ctx, state)
        assert_true(ok_match, "strategy[" .. i .. "] matches should not throw")
        local ok_exec, executed = pcall(s.execute, ctx, state)
        assert_true(ok_exec, "strategy[" .. i .. "] execute should not throw")
    end
end)

test("rotation: low HP scenario - healing should match", function()
    local ctx = make_context({hp = 30})
    local state = get_state(ctx)
    state.healing_wave_ready = true
    state.hp = 30
    state.heal_hp = 50

    -- HealingWave should match when HP < 50
    assert_true(strategies[6].matches(ctx, state), "HealingWave should match when HP < 50")
end)

test("rotation: AoE scenario - chain lightning should match with 3+ enemies", function()
    local ctx = make_context({enemies_count = 3})
    local state = get_state(ctx)
    state.chain_lightning_ready = true
    state.enemies = 3

    -- Chain Lightning should match with 2+ enemies
    assert_true(strategies[14].matches(ctx, state), "Chain Lightning should match with 3 enemies")
end)

-- ============================================================================
-- ============================================================================
-- Edge Case Tests: Healing Wave HP boundary
-- ============================================================================

do -- edge_healing_wave
    test("edge_healing_wave: HP exactly 50 (threshold) -> match", function()
        local ctx = make_context({hp = 50})
        local state = get_state(ctx)
        state.healing_wave_ready = true
        state.hp = 50
        state.heal_hp = 50
        assert_true(strategies[6].matches(ctx, state), "HP 50 should match (<= threshold)")
    end)

    test("edge_healing_wave: HP exactly 51 (above threshold) -> no match", function()
        local ctx = make_context({hp = 51})
        local state = get_state(ctx)
        state.healing_wave_ready = true
        state.hp = 51
        state.heal_hp = 50
        assert_false(strategies[6].matches(ctx, state), "HP 51 should not match (> threshold)")
    end)
end

-- ============================================================================
-- Edge Case Tests: Chain Lightning enemy count boundary
-- ============================================================================

do -- edge_chain_lightning
    test("edge_chain_lightning: enemies exactly 2 -> match", function()
        local ctx = make_context({enemies_count = 2})
        local state = get_state(ctx)
        state.chain_lightning_ready = true
        state.enemies = 2
        assert_true(strategies[14].matches(ctx, state), "2 enemies should match (>= 2)")
    end)

    test("edge_chain_lightning: enemies exactly 1 -> no match", function()
        local ctx = make_context({enemies_count = 1})
        local state = get_state(ctx)
        state.chain_lightning_ready = true
        state.enemies = 1
        assert_false(strategies[14].matches(ctx, state), "1 enemy should not match (< 2)")
    end)
end

-- ============================================================================
-- Edge Case Tests: Flame Shock DoT refresh boundary
-- ============================================================================

do -- edge_flame_shock
    test("edge_flame_shock: debuff remains exactly 0 -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.flame_shock_ready = true
        state.use_shocks = true
        state.default_shock = "flame"
        local saved = NS.debuff_remains
        NS.debuff_remains = function() return 0 end
        assert_true(strategies[15].matches(ctx, state), "remains 0 should match (<= 4)")
        NS.debuff_remains = saved
    end)

    test("edge_flame_shock: debuff remains exactly 5 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.flame_shock_ready = true
        state.use_shocks = true
        state.default_shock = "flame"
        local saved = NS.debuff_remains
        NS.debuff_remains = function() return 5 end
        assert_false(strategies[15].matches(ctx, state), "remains 5 should not match (> 4)")
        NS.debuff_remains = saved
    end)

    test("edge_flame_shock: default shock not flame -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.flame_shock_ready = true
        state.use_shocks = true
        state.default_shock = "earth"
        assert_false(strategies[15].matches(ctx, state), "earth default should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Earth Shock DPS default shock boundary
-- ============================================================================

do -- edge_earth_shock
    test("edge_earth_shock: default shock earth -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.earth_shock_ready = true
        state.use_shocks = true
        state.default_shock = "earth"
        assert_true(strategies[16].matches(ctx, state), "earth default should match")
    end)

    test("edge_earth_shock: default shock not earth -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.earth_shock_ready = true
        state.use_shocks = true
        state.default_shock = "flame"
        assert_false(strategies[16].matches(ctx, state), "flame default should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Frost Shock default shock boundary
-- ============================================================================

do -- edge_frost_shock
    test("edge_frost_shock: default shock frost -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.frost_shock_ready = true
        state.use_shocks = true
        state.default_shock = "frost"
        assert_true(strategies[18].matches(ctx, state), "frost default should match")
    end)

    test("edge_frost_shock: default shock not frost -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.frost_shock_ready = true
        state.use_shocks = true
        state.default_shock = "flame"
        assert_false(strategies[18].matches(ctx, state), "flame default should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Earthbind Totem boundaries
-- ============================================================================

do -- edge_earthbind
    test("edge_earthbind: enemies exactly 3 -> match", function()
        local ctx = make_context({hp = 40, enemies_count = 3})
        local state = get_state(ctx)
        state.earthbind_totem_ready = true
        state.hp = 40
        state.enemies = 3
        assert_true(strategies[19].matches(ctx, state), "3 enemies should match (>= 3)")
    end)

    test("edge_earthbind: enemies exactly 2 -> no match", function()
        local ctx = make_context({hp = 40, enemies_count = 2})
        local state = get_state(ctx)
        state.earthbind_totem_ready = true
        state.hp = 40
        state.enemies = 2
        assert_false(strategies[19].matches(ctx, state), "2 enemies should not match (< 3)")
    end)

    test("edge_earthbind: HP exactly 50 -> match", function()
        local ctx = make_context({hp = 50, enemies_count = 3})
        local state = get_state(ctx)
        state.earthbind_totem_ready = true
        state.hp = 50
        state.enemies = 3
        assert_true(strategies[19].matches(ctx, state), "HP 50 should match (<= 50)")
    end)

    test("edge_earthbind: HP exactly 51 -> no match", function()
        local ctx = make_context({hp = 51, enemies_count = 3})
        local state = get_state(ctx)
        state.earthbind_totem_ready = true
        state.hp = 51
        state.enemies = 3
        assert_false(strategies[19].matches(ctx, state), "HP 51 should not match (> 50)")
    end)
end

-- ============================================================================
-- Edge Case Tests: Water Totem mana/HP boundary
-- ============================================================================

do -- edge_water_totem
    test("edge_water_totem: mana exactly 85 -> match (mana_spring)", function()
        local ctx = make_context({mana_pct = 85, hp = 100})
        local state = get_state(ctx)
        state.mana_spring_ready = true
        state.healing_stream_ready = true
        state.use_totems = true
        state.use_water_totem = true
        state.mana_pct = 85
        state.hp = 100
        state.now_ms = 500000
        assert_true(strategies[10].matches(ctx, state), "mana 85 should match (<= 85)")
    end)

    test("edge_water_totem: mana exactly 86 -> no match", function()
        local ctx = make_context({mana_pct = 86, hp = 100})
        local state = get_state(ctx)
        state.mana_spring_ready = true
        state.healing_stream_ready = true
        state.use_totems = true
        state.use_water_totem = true
        state.mana_pct = 86
        state.hp = 100
        assert_false(strategies[10].matches(ctx, state), "mana 86 should not match (> 85)")
    end)

    test("edge_water_totem: HP exactly 85 -> match (healing_stream)", function()
        local ctx = make_context({mana_pct = 100, hp = 85})
        local state = get_state(ctx)
        state.mana_spring_ready = true
        state.healing_stream_ready = true
        state.use_totems = true
        state.use_water_totem = true
        state.mana_pct = 100
        state.hp = 85
        state.now_ms = 500000
        assert_true(strategies[10].matches(ctx, state), "HP 85 should match (<= 85)")
    end)

    test("edge_water_totem: HP exactly 86 -> no match", function()
        local ctx = make_context({mana_pct = 100, hp = 86})
        local state = get_state(ctx)
        state.mana_spring_ready = true
        state.healing_stream_ready = true
        state.use_totems = true
        state.use_water_totem = true
        state.mana_pct = 100
        state.hp = 86
        assert_false(strategies[10].matches(ctx, state), "HP 86 should not match (> 85)")
    end)
end

-- ============================================================================
-- Edge Case Tests: Ghost Wolf distance boundary
-- ============================================================================

do -- edge_ghost_wolf
    test("edge_ghost_wolf: distance exactly 19 -> no match", function()
        local ctx = make_context({in_combat = false})
        local saved = NS.get_distance
        NS.get_distance = function() return 19 end
        local state = get_state(ctx)
        state.ghost_wolf_ready = true
        state.in_combat = false
        assert_false(strategies[22].matches(ctx, state), "distance 19 should not match (< 20)")
        NS.get_distance = saved
    end)

    test("edge_ghost_wolf: distance exactly 20 -> match", function()
        local ctx = make_context({in_combat = false})
        local saved = NS.get_distance
        NS.get_distance = function() return 20 end
        local state = get_state(ctx)
        state.ghost_wolf_ready = true
        state.in_combat = false
        assert_true(strategies[22].matches(ctx, state), "distance 20 should match (>= 20)")
        NS.get_distance = saved
    end)
end

-- ============================================================================
-- Edge Case Tests: Wand mana boundary
-- ============================================================================

do -- edge_wand
    test("edge_wand: mana exactly 29 (below threshold) -> match", function()
        local ctx = make_context({mana_pct = 29})
        local state = get_state(ctx)
        state.wand_threshold = 30
        state.mana_pct = 29
        state.wand_learned = true
        assert_true(strategies[23].matches(ctx, state), "mana 29 should match (< threshold)")
    end)

    test("edge_wand: mana exactly 30 (at threshold) -> no match", function()
        local ctx = make_context({mana_pct = 30})
        local state = get_state(ctx)
        state.wand_threshold = 30
        state.mana_pct = 30
        state.wand_learned = true
        assert_false(strategies[23].matches(ctx, state), "mana 30 should not match (>= threshold)")
    end)
end

-- ============================================================================
-- Edge Case Tests: Weapon Imbue & Lightning Shield (OOC buffs)
-- ============================================================================

do -- edge_weapon_imbue
    test("edge_weapon_imbue: OOC, no imbue, ready -> match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.use_weapon_imbue = true
        state.weapon_imbue = { 25485 }
        state.has_mainhand_imbue = false
        state.weapon_imbue_api_known = true
        assert_true(strategies[1].matches(ctx, state), "unbuffed OOC should match")
    end)

    test("edge_weapon_imbue: already imbued -> no match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.use_weapon_imbue = true
        state.has_mainhand_imbue = true
        assert_false(strategies[1].matches(ctx, state), "already imbued should not match")
    end)
end

do -- edge_lightning_shield
    test("edge_lightning_shield: OOC, no shield, ready -> match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.has_lightning_shield = false
        state.lightning_shield_ready = true
        state.now_ms = 500000
        assert_true(strategies[2].matches(ctx, state), "unshielded OOC should match")
    end)

    test("edge_lightning_shield: already shielded -> no match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.has_lightning_shield = true
        state.lightning_shield_ready = true
        assert_false(strategies[2].matches(ctx, state), "already shielded should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Searing/Strength/Water totem disabled boundaries
-- ============================================================================

do -- edge_totem_disabled
    test("edge_searing_totem: totems disabled -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.searing_totem_ready = true
        state.use_totems = false
        assert_false(strategies[8].matches(ctx, state), "totems disabled should not match")
    end)

    test("edge_searing_totem: searing disabled -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.searing_totem_ready = true
        state.use_totems = true
        state.use_searing_totem = false
        assert_false(strategies[8].matches(ctx, state), "searing disabled should not match")
    end)

    test("edge_strength_totem: strength disabled -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.strength_of_earth_ready = true
        state.use_totems = true
        state.use_strength_totem = false
        assert_false(strategies[9].matches(ctx, state), "strength disabled should not match")
    end)

    test("edge_water_totem: water disabled -> no match", function()
        local ctx = make_context({mana_pct = 60})
        local state = get_state(ctx)
        state.mana_spring_ready = true
        state.use_totems = true
        state.use_water_totem = false
        state.mana_pct = 60
        assert_false(strategies[10].matches(ctx, state), "water disabled should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Lightning Bolt movement boundary
-- ============================================================================

do -- edge_lightning_bolt
    test("edge_lightning_bolt: not moving -> match", function()
        local ctx = make_context({is_moving = false})
        local state = get_state(ctx)
        state.lightning_bolt_ready = true
        state.is_moving = false
        assert_true(strategies[21].matches(ctx, state), "stationary should match")
    end)

    test("edge_lightning_bolt: moving -> no match", function()
        local ctx = make_context({is_moving = true})
        local state = get_state(ctx)
        state.lightning_bolt_ready = true
        state.is_moving = true
        assert_false(strategies[21].matches(ctx, state), "moving should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Interrupt boundary
-- ============================================================================

do -- edge_interrupt
    test("edge_earth_shock_interrupt: target casting -> match", function()
        local ctx = make_context()
        ctx.target.is_casting = function() return true end
        local state = get_state(ctx)
        state.earth_shock_ready = true
        state.use_interrupt = true
        assert_true(strategies[4].matches(ctx, state), "target casting should match")
    end)

    test("edge_earth_shock_interrupt: target not casting -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.earth_shock_ready = true
        state.use_interrupt = true
        assert_false(strategies[4].matches(ctx, state), "target not casting should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Build state API safety (nil/throwing NS functions)
-- ============================================================================

do -- edge_buff
    test("edge_buff: NS.buff_up nil in build_state -> no crash", function()
        local saved = NS.buff_up
        NS.buff_up = nil
        local ctx = make_context()
        local state = get_state(ctx)
        NS.buff_up = saved
        assert_not_nil(state, "state should not be nil")
        assert_false(state.has_lightning_shield, "has_lightning_shield should be false")
    end)

    test("edge_buff: NS.buff_up throws in build_state -> no crash", function()
        local saved = NS.buff_up
        NS.buff_up = function() error("crash") end
        local ctx = make_context()
        local ok, state = pcall(get_state, ctx)
        NS.buff_up = saved
        assert_true(ok, "NS.buff_up throw should be caught - build_state should not crash")
        if ok and state then
            assert_false(state.has_lightning_shield, "has_lightning_shield should be false")
        end
    end)
end

-- ============================================================================
-- Edge Case Tests: API crash safety (spell_ready, try_cast)
-- ============================================================================

do -- edge_api
    test("edge_api: NS.spell_ready nil -> no crash, ready flags false", function()
        local saved = NS.spell_ready
        NS.spell_ready = nil
        local ctx = make_context()
        local ok, state = pcall(get_state, ctx)
        NS.spell_ready = saved
        assert_true(ok, "NS.spell_ready nil should not crash build_state")
        if ok and state then
            assert_false(state.lightning_bolt_ready, "lightning_bolt_ready should be false")
            assert_false(state.earth_shock_ready, "earth_shock_ready should be false")
        end
    end)

    test("edge_api: NS.spell_ready throws -> no crash, ready flags false", function()
        local saved = NS.spell_ready
        NS.spell_ready = function() error("crash") end
        local ctx = make_context()
        local ok, state = pcall(get_state, ctx)
        NS.spell_ready = saved
        assert_true(ok, "NS.spell_ready throw should not crash build_state")
        if ok and state then
            assert_false(state.lightning_bolt_ready, "lightning_bolt_ready should be false")
            assert_false(state.earth_shock_ready, "earth_shock_ready should be false")
        end
    end)

    test("edge_api: NS.try_cast nil does not crash execute functions", function()
        local saved = NS.try_cast
        NS.try_cast = nil
        local ctx = make_context()
        for i = 1, 15 do
            local ok, result = pcall(strategies[i].execute, ctx)
            assert_true(ok, string.format("strategies[%d].execute should not crash with NS.try_cast nil", i))
        end
        NS.try_cast = saved
    end)
end

-- ============================================================================
-- Edge Case Tests: Rotation crash safety
-- ============================================================================

do -- edge_rotation_crash
    test("edge_rotation_crash: all execute functions handle nil context", function()
        for i = 1, 15 do
            local ok, result = pcall(strategies[i].execute)
            assert_true(ok, string.format("strategies[%d].execute should not crash with nil context", i))
        end
    end)

    test("edge_rotation_crash: all match functions handle nil context", function()
        for i = 1, 15 do
            local ok, result = pcall(strategies[i].matches, nil, {})
            assert_true(ok, string.format("strategies[%d].matches should not crash with nil context", i))
        end
    end)

    test("edge_rotation_crash: all match functions handle nil state", function()
        local ctx = make_context()
        for i = 1, 15 do
            local ok, result = pcall(strategies[i].matches, ctx, nil)
            assert_true(ok, string.format("strategies[%d].matches should not crash with nil state", i))
        end
    end)
end
-- ============================================================================
-- Edge case: HP boundaries
-- ============================================================================
do
    -- HealingWave: hp <= heal_hp (50) -> match; > -> no match
    local ctx = make_context({hp = 50})
    local state = get_state(ctx)
    state.healing_wave_ready = true
    state.hp = 50
    state.heal_hp = 50
    assert_true(strategies[6].matches(ctx, state), "healingwave hp=50 -> match (<=50)")

    local ctx2 = make_context({hp = 51})
    local state2 = get_state(ctx2)
    state2.healing_wave_ready = true
    state2.hp = 51
    state2.heal_hp = 50
    assert_false(strategies[6].matches(ctx2, state2), "healingwave hp=51 -> no match (>50)")

    -- LesserHealingWave: hp <= 40 -> match; > 40 -> no match
    local ctx3 = make_context({hp = 40})
    local state3 = get_state(ctx3)
    state3.lesser_healing_wave_ready = true
    state3.hp = 40
    assert_true(strategies[7].matches(ctx3, state3), "lesserhealingwave hp=40 -> match (<=40)")

    local ctx4 = make_context({hp = 41})
    local state4 = get_state(ctx4)
    state4.lesser_healing_wave_ready = true
    state4.hp = 41
    assert_false(strategies[7].matches(ctx4, state4), "lesserhealingwave hp=41 -> no match (>40)")
end

-- ============================================================================
-- Edge case: Mana boundaries
-- ============================================================================
do
    -- ShamanisticRage: mana <= rage_mana (30) -> match; > -> no match
    local ctx = make_context({mana_pct = 30})
    local state = get_state(ctx)
    state.shamanistic_rage_ready = true
    state.shamanistic_rage_mana = 30
    state.mana_pct = 30
    assert_true(strategies[5].matches(ctx, state), "shamanisticrage mana=30 -> match (<=30)")

    local ctx2 = make_context({mana_pct = 31})
    local state2 = get_state(ctx2)
    state2.shamanistic_rage_ready = true
    state2.shamanistic_rage_mana = 30
    state2.mana_pct = 31
    assert_false(strategies[5].matches(ctx2, state2), "shamanisticrage mana=31 -> no match (>30)")

    -- Stormstrike: mana >= 10 -> match; < 10 -> no match
    local ctx3 = make_context({mana_pct = 10})
    ctx3.in_melee_range = true
    ctx3.settings.leveling_use_stormstrike = true
    local state3 = get_state(ctx3)
    state3.stormstrike_ready = true
    state3.use_stormstrike = true
    state3.in_melee_range = true
    state3.mana_pct = 10
    assert_true(strategies[13].matches(ctx3, state3), "stormstrike mana=10 -> match (>=10)")

    local ctx4 = make_context({mana_pct = 9})
    ctx4.in_melee_range = true
    ctx4.settings.leveling_use_stormstrike = true
    local state4 = get_state(ctx4)
    state4.stormstrike_ready = true
    state4.use_stormstrike = true
    state4.in_melee_range = true
    state4.mana_pct = 9
    assert_false(strategies[13].matches(ctx4, state4), "stormstrike mana=9 -> no match (<10)")
end

-- ============================================================================
-- Edge case: Enemy thresholds
-- ============================================================================
do
    -- ChainLightning: enemies >= 2 -> match; < 2 -> no match
    local ctx = make_context({enemies_count = 2})
    local state = get_state(ctx)
    state.chain_lightning_ready = true
    state.enemies = 2
    assert_true(strategies[14].matches(ctx, state), "chainlightning enemies=2 -> match (>=2)")

    local ctx2 = make_context({enemies_count = 1})
    local state2 = get_state(ctx2)
    state2.chain_lightning_ready = true
    state2.enemies = 1
    assert_false(strategies[14].matches(ctx2, state2), "chainlightning enemies=1 -> no match (<2)")

    -- EarthbindTotem: enemies >= 3, hp <= 50 -> match
    local ctx3 = make_context({enemies_count = 3, hp = 50})
    local state3 = get_state(ctx3)
    state3.earthbind_totem_ready = true
    state3.enemies = 3
    state3.hp = 50
    assert_true(strategies[19].matches(ctx3, state3), "earthbind enemies=3 hp=50 -> match")

    local ctx4 = make_context({enemies_count = 2, hp = 50})
    local state4 = get_state(ctx4)
    state4.earthbind_totem_ready = true
    state4.enemies = 2
    state4.hp = 50
    assert_false(strategies[19].matches(ctx4, state4), "earthbind enemies=2 -> no match (<3)")
end

-- ============================================================================
-- Edge case: Shock default_shock setting
-- ============================================================================
do
    -- FlameShock: default_shock = flame -> match; earth/frost -> no match
    local ctx = make_context({})
    ctx.settings.leveling_default_shock = "flame"
    local state = get_state(ctx)
    state.flame_shock_ready = true
    state.use_shocks = true
    state.default_shock = "flame"
    local saved = NS.debuff_remains
    NS.debuff_remains = function() return 0 end
    assert_true(strategies[15].matches(ctx, state), "flameshock default=flame -> match")
    NS.debuff_remains = saved

    local ctx2 = make_context({})
    ctx2.settings.leveling_default_shock = "earth"
    local state2 = get_state(ctx2)
    state2.flame_shock_ready = true
    state2.use_shocks = true
    state2.default_shock = "earth"
    assert_false(strategies[15].matches(ctx2, state2), "flameshock default=earth -> no match")

    -- EarthShock: default_shock = earth -> match; frost/flame -> no match
    local ctx3 = make_context({})
    ctx3.settings.leveling_default_shock = "earth"
    local state3 = get_state(ctx3)
    state3.earth_shock_ready = true
    state3.use_shocks = true
    state3.default_shock = "earth"
    assert_true(strategies[16].matches(ctx3, state3), "earthshock default=earth -> match")

    local ctx4 = make_context({})
    ctx4.settings.leveling_default_shock = "frost"
    local state4 = get_state(ctx4)
    state4.earth_shock_ready = true
    state4.use_shocks = true
    state4.default_shock = "frost"
    assert_false(strategies[16].matches(ctx4, state4), "earthshock default=frost -> no match")
end

-- ============================================================================
-- Edge case: Settings toggle
-- ============================================================================
do
    -- use_shocks disabled -> no shock matches
    local ctx = make_context({})
    ctx.settings.leveling_use_shocks = false
    local state = get_state(ctx)
    state.flame_shock_ready = true
    state.use_shocks = false
    assert_false(strategies[15].matches(ctx, state), "flameshock shocks disabled -> no match")

    -- use_stormstrike disabled -> no match
    local ctx3 = make_context({})
    ctx3.settings.leveling_use_stormstrike = false
    local state3 = get_state(ctx3)
    state3.stormstrike_ready = true
    state3.use_stormstrike = false
    state3.in_melee_range = true
    state3.mana_pct = 50
    assert_false(strategies[13].matches(ctx3, state3), "stormstrike setting disabled -> no match")
end

-- ============================================================================
-- Edge case: Movement guard
-- ============================================================================
do
    local ctx = make_context({is_moving = true})
    local state = get_state(ctx)
    state.lightning_bolt_ready = true
    state.is_moving = true
    assert_false(strategies[21].matches(ctx, state), "lightningbolt moving -> no match")
end

-- ============================================================================
-- Edge case: GhostWolf distance boundary
-- ============================================================================
do
    local saved_dist = NS.get_distance
    local ctx = make_context({in_combat = false})
    ctx.target = { is_valid = function() return true end }
    local state = get_state(ctx)
    state.ghost_wolf_ready = true

    NS.get_distance = function() return 20 end
    assert_true(strategies[22].matches(ctx, state), "ghostwolf dist=20 -> match (>=20)")
    NS.get_distance = saved_dist

    local ctx2 = make_context({in_combat = false})
    ctx2.target = { is_valid = function() return true end }
    local state2 = get_state(ctx2)
    state2.ghost_wolf_ready = true
    local saved_dist2 = NS.get_distance
    NS.get_distance = function() return 19 end
    assert_false(strategies[22].matches(ctx2, state2), "ghostwolf dist=19 -> no match (<20)")
    NS.get_distance = saved_dist2
end

-- ============================================================================
-- Edge case: OOC guards
-- ============================================================================
do
    -- HealingWave: OOC -> no match
    local ctx = make_context({in_combat = false, hp = 30})
    local state = get_state(ctx)
    state.healing_wave_ready = true
    state.hp = 30
    state.heal_hp = 50
    assert_false(strategies[6].matches(ctx, state), "healingwave OOC -> no match")

    -- LesserHealingWave: OOC -> no match
    local ctx2 = make_context({in_combat = false, hp = 30})
    local state2 = get_state(ctx2)
    state2.lesser_healing_wave_ready = true
    state2.hp = 30
    assert_false(strategies[7].matches(ctx2, state2), "lesserhealingwave OOC -> no match")

    -- ChainLightning: OOC -> no match
    local ctx3 = make_context({in_combat = false, enemies_count = 3})
    local state3 = get_state(ctx3)
    state3.chain_lightning_ready = true
    state3.enemies = 3
    assert_false(strategies[14].matches(ctx3, state3), "chainlightning OOC -> no match")

    -- LightningBolt: OOC -> no match
    local ctx4 = make_context({in_combat = false, is_moving = false})
    local state4 = get_state(ctx4)
    state4.lightning_bolt_ready = true
    state4.is_moving = false
    assert_false(strategies[21].matches(ctx4, state4), "lightningbolt OOC -> no match")
end

-- ============================================================================
-- API crash: NS.try_cast throwing
-- ============================================================================
do
    local saved = NS.try_cast
    local ctx = make_context({})

    -- NS.try_cast throws -> execute should not crash
    NS.try_cast = function() error("simulated throw") end
    for i = 1, #strategies do
        local ok, result = pcall(strategies[i].execute, ctx)
        assert_true(ok, "try_cast=throw: strategy " .. i .. " execute did not crash")
    end

    NS.try_cast = saved
end

-- ============================================================================
-- Rotation crash: nil context for all execute functions
-- ============================================================================
do
    for i = 1, #strategies do
        local ok, result = pcall(strategies[i].execute, nil)
        assert_true(ok, "execute nil ctx: strategy " .. i .. " did not crash")
    end
end

-- ============================================================================
-- Rotation crash: no-arg execute for all functions
-- ============================================================================
do
    for i = 1, #strategies do
        local ok, result = pcall(strategies[i].execute)
        assert_true(ok, "execute no-arg: strategy " .. i .. " did not crash")
    end
end

-- Summary
-- ============================================================================

print(string.format("\n=== Shaman Leveling Unit Tests: %d passed, %d failed (%d assertions) ===\n", passed, failed, assertions))
if failed > 0 then
    error(string.format("Some tests FAILED (%d failures)", failed))
else
    print("All Shaman leveling unit tests passed!")
end
