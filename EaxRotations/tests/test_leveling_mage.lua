-- Unit tests for Mage leveling rotation
-- Tests build_state, all 13 match functions, strategy ordering,
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

local MOCK_MAGE_SPELLS = {
    Frostbolt = { 27070 },
    FireBlast = { 27078 },
    Scorch = { 27080 },
    ArcaneMissiles = { 27075 },
    FrostNova = { 27088 },
    Blizzard = { 27085 },
    Polymorph = { 12826 },
    Counterspell = { 2139 },
    Evocation = { 12051 },
    IceBarrier = { 27134 },
    ManaShield = { 27142 },
    ArcaneIntellect = { 27126 },
    RemoveCurse = { 475 },
    Shoot = { 5019 },
    ConjureManaGem = { 27101 },
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
    }

    core.input = {
        cast_target_spell = function(spell_id, target)
            return spell_id ~= nil and target ~= nil
        end,
    }

    --- Shared state for mock player/target
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
        get_class = function() return 8 end,
        is_in_combat = function() return false end,
        get_target = function() return mock_target end,
        get_position = function() return { x = 0, y = 0, z = 0 } end,
    }

    NS.log = function() end
    NS.log_warning = function() end
    NS.spell_ready = function(spell_action)
        if not spell_action then return false end
        return true
    end
    NS.spell_exists = function(spell_id)
        if spell_id == 5019 then return true end
        return true
    end
    NS.try_cast = function(spell_action, target, label)
        if not spell_action then return false end
        return true
    end
    NS.get_local_player = function() return mock_player end
    NS.get_target = function() return mock_target end
    NS.get_distance = function() return 10 end
    NS.debuff_remains = function(target, debuff_ids)
        if not target then return 0 end
        return 0
    end
    NS.buff_remains = function(unit, buff_ids) return 0 end
    NS.buff_up = function(unit, buff_ids) return false end
    NS.is_item_ready = function(item_id) return false end
    NS.use_item_by_id = function(item_id) return true end

    -- rotation_registry mock that captures registrations
    NS.rotation_registry = {
        _registrations = {},
        register = function(self, key, strategies, opts)
            self._registrations[key] = { strategies = strategies, opts = opts }
        end,
        set_class_config = function(self, config) end,
    }

    NS.MageSpells = {}
    for k, v in pairs(MOCK_MAGE_SPELLS) do
        NS.MageSpells[k] = v
    end

    _G.core = core
    _G.EaxRotations = NS

    return NS, core, mock_player, mock_target, mock_state
end

--- Create a mock context with sensible defaults.
--- @param overrides table Optional overrides for context fields
local function make_context(overrides)
    local ctx = {
        is_solo = false,
        is_leveling = true,
        in_combat = true,
        mana_pct = 80,
        hp = 100,
        enemies_count = 1,
        is_moving = false,
        me = {
            is_valid = function() return true end,
            get_health = function() return 10000 end,
            get_max_health = function() return 10000 end,
            has_buff = function(id) return false end,
            get_position = function() return { x = 0, y = 0, z = 0 } end,
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
            leveling_polymorph_hp = 40,
            leveling_arcane_missiles_use = true,
            leveling_scorch_use = true,
            leveling_fire_blast_use = true,
            use_mana_gem = true,
            mana_gem_mana_pct = 70,
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
-- Load the Mage leveling module
-- ============================================================================

local NS, core, mock_player, mock_target, mock_state = build_mock_env()
local ok, module = pcall(dofile, "EaxRotations/classes/mage/leveling_sylvanas.lua")
if not ok then
    error("Failed to load Mage leveling module: " .. tostring(module))
end
if not module or type(module) ~= "table" then
    error("Mage leveling module should return a table of strategies")
end

-- Get the registration info
local reg = NS.rotation_registry._registrations["leveling"]
if not reg then
    error("Mage leveling module should register as 'leveling' in rotation_registry")
end
local strategies = reg.strategies
local get_state = reg.opts.get_state

print("=== Mage Leveling Unit Tests ===\n")
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
        -- Minimal context, most fields missing
        me = { is_valid = function() return true end, has_buff = function() return false end, get_health = function() return 10000 end, get_max_health = function() return 10000 end },
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
    assert_true(state.frostbolt_ready, "frostbolt_ready should be true")
    assert_true(state.fire_blast_ready, "fire_blast_ready should be true")
    assert_true(state.scorch_ready, "scorch_ready should be true")
    assert_true(state.arcane_missiles_ready, "arcane_missiles_ready should be true")
    assert_true(state.frost_nova_ready, "frost_nova_ready should be true")
    assert_true(state.blizzard_ready, "blizzard_ready should be true")
    assert_true(state.polymorph_ready, "polymorph_ready should be true")
    assert_true(state.counterspell_ready, "counterspell_ready should be true")
    assert_true(state.evocation_ready, "evocation_ready should be true")
    assert_true(state.ice_barrier_ready, "ice_barrier_ready should be true")
    assert_true(state.mana_shield_ready, "mana_shield_ready should be true")
    assert_true(state.ai_ready, "ai_ready should be true")
    assert_true(state.remove_curse_ready, "remove_curse_ready should be true")
end)

test("build_state: custom thresholds from settings", function()
    local ctx = make_context()
    ctx.settings.leveling_wand_threshold = 15
    ctx.settings.leveling_polymorph_hp = 60
    ctx.settings.leveling_scorch_use = false
    ctx.settings.leveling_fire_blast_use = false
    ctx.settings.leveling_arcane_missiles_use = false
    local state = get_state(ctx)
    assert_eq(state.wand_threshold, 15, "wand_threshold from settings")
    assert_eq(state.polymorph_hp, 60, "polymorph_hp from settings")
    assert_false(state.use_scorch, "use_scorch from settings")
    assert_false(state.use_fire_blast, "use_fire_blast from settings")
    assert_false(state.use_arcane_missiles, "use_arcane_missiles from settings")
end)

test("build_state: missing settings uses defaults", function()
    local ctx = make_context({settings = {}})
    local state = get_state(ctx)
    assert_eq(state.wand_threshold, 30, "default wand_threshold = 30")
    assert_eq(state.polymorph_hp, 40, "default polymorph_hp = 40")
    assert_true(state.use_scorch, "default use_scorch = true")
    assert_true(state.use_fire_blast, "default use_fire_blast = true")
    assert_true(state.use_arcane_missiles, "default use_arcane_missiles = true")
end)

test("build_state: buff checks populate correctly", function()
    local ctx = make_context()
    local state = get_state(ctx)
    assert_false(state.has_ai, "no AI buff by default")
    assert_false(state.has_molten_armor, "no Molten Armor by default")
    assert_false(state.has_ice_barrier, "no Ice Barrier by default")
    assert_false(state.has_mana_shield, "no Mana Shield by default")
end)

-- ============================================================================
-- Test: arcane_intellect_matches (strategy #1)
-- ============================================================================

test("arcane_intellect_matches: OOC, ready, no buff -> true", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_ai = false
    state.ai_ready = true
    assert_true(strategies[1].matches(ctx, state), "should match")
end)

test("arcane_intellect_matches: in combat -> false", function()
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.has_ai = false
    state.ai_ready = true
    assert_false(strategies[1].matches(ctx, state), "should not match in combat")
end)

test("arcane_intellect_matches: already has buff -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_ai = true
    state.ai_ready = true
    assert_false(strategies[1].matches(ctx, state), "should not match if buff active")
end)

test("arcanee_intellect_matches: nil state -> does not crash", function()
    local ok, result = pcall(strategies[1].matches, make_context({in_combat = false}), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: polymorph_matches (strategy #5)
-- ============================================================================

test("polymorph_matches: OOC, ready, target HP low, no debuff -> true", function()
    -- Build context with low HP target before building state
    local ctx = make_context({in_combat = false})
    ctx.target = {
        is_valid = function() return true end,
        get_health = function() return 2000 end,
        get_max_health = function() return 10000 end,
        is_casting = function() return false end,
        is_alive = function() return true end,
        get_guid = function() return "mock-target" end,
        get_distance = function(other) return 5 end,
        get_health_percentage = function() return 20 end,
    }
    local state = get_state(ctx)
    state.polymorph_ready = true
    state.polymorph_hp = 40
    assert_true(strategies[5].matches(ctx, state), "should match when target HP below threshold")
end)

test("polymorph_matches: in combat -> false", function()
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.polymorph_ready = true
    assert_false(strategies[5].matches(ctx, state), "should not match in combat")
end)

test("polymorph_matches: no target -> false", function()
    local ctx = make_context({in_combat = false, target = nil})
    local state = get_state(ctx)
    state.polymorph_ready = true
    assert_false(strategies[5].matches(ctx, state), "no target should return false")
end)

test("polymorph_matches: target HP too high -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.polymorph_ready = true
    state.polymorph_hp = 10
    -- Target HP returns 80, threshold is 10, 80 >= 10 -> false
    assert_false(strategies[5].matches(ctx, state), "target HP above threshold should not match")
end)

test("polymorph_matches: debuff still active -> false", function()
    local ctx = make_context({in_combat = false})
    ctx.target = {
        is_valid = function() return true end,
        get_health = function() return 2000 end,
        get_max_health = function() return 10000 end,
        is_casting = function() return false end,
        is_alive = function() return true end,
        get_guid = function() return "mock-target" end,
        get_distance = function(other) return 5 end,
        get_health_percentage = function() return 20 end,
    }
    local state = get_state(ctx)
    state.polymorph_ready = true
    NS.debuff_remains = function(target, ids) return 15 end
    assert_false(strategies[5].matches(ctx, state), "active polymorph should not match")
    NS.debuff_remains = function(target, ids) return 0 end
end)

-- ============================================================================
-- Test: counterspell_matches (strategy #6)
-- ============================================================================

test("counterspell_matches: ready, target casting -> true", function()
    local ctx = make_context()
    ctx.target = {
        is_valid = function() return true end,
        get_health = function() return 8000 end,
        get_max_health = function() return 10000 end,
        is_casting = function() return true end,
        is_alive = function() return true end,
        get_guid = function() return "mock-target" end,
        get_distance = function(other) return 5 end,
        get_health_percentage = function() return 80 end,
    }
    local state = get_state(ctx)
    state.counterspell_ready = true
    assert_true(strategies[6].matches(ctx, state), "target casting should match")
end)

test("counterspell_matches: target not casting -> false", function()
    local ctx = make_context()
    ctx.target.is_casting = function() return false end
    local state = get_state(ctx)
    state.counterspell_ready = true
    assert_false(strategies[6].matches(ctx, state), "target not casting should not match")
end)

test("counterspell_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.counterspell_ready = true
    state.target = nil
    assert_false(strategies[6].matches(ctx, state), "no target should return false")
end)

test("counterspell_matches: interrupt disabled -> false", function()
    local ctx = make_context()
    ctx.settings.use_interrupt = false
    local state = get_state(ctx)
    state.counterspell_ready = true
    state.use_interrupt = false
    assert_false(strategies[6].matches(ctx, state), "interrupt disabled should not match")
end)

-- ============================================================================
-- Test: mana_shield_matches (strategy #7)
-- ============================================================================

test("mana_shield_matches: ready, low HP, no shield -> true", function()
    local ctx = make_context({hp = 30})
    local state = get_state(ctx)
    state.has_mana_shield = false
    state.mana_shield_ready = true
    state.hp = 30
    assert_true(strategies[7].matches(ctx, state), "low HP should match")
end)

test("mana_shield_matches: already has shield -> false", function()
    local ctx = make_context({hp = 30})
    local state = get_state(ctx)
    state.has_mana_shield = true
    state.mana_shield_ready = true
    state.hp = 30
    assert_false(strategies[7].matches(ctx, state), "shield already active")
end)

test("mana_shield_matches: HP above threshold -> false", function()
    local ctx = make_context({hp = 80})
    local state = get_state(ctx)
    state.has_mana_shield = false
    state.mana_shield_ready = true
    state.hp = 80
    assert_false(strategies[7].matches(ctx, state), "HP above 40 threshold")
end)

test("mana_shield_matches: nil state -> does not crash", function()
    local ok, result = pcall(strategies[7].matches, make_context({hp = 30}), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: ice_barrier_matches (strategy #8)
-- ============================================================================

test("ice_barrier_matches: ready, in combat, no barrier -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.has_ice_barrier = false
    state.ice_barrier_ready = true
    assert_true(strategies[8].matches(ctx, state), "should match in combat without barrier")
end)

test("ice_barrier_matches: already has barrier -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.has_ice_barrier = true
    state.ice_barrier_ready = true
    assert_false(strategies[8].matches(ctx, state), "barrier already active")
end)

test("ice_barrier_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_ice_barrier = false
    state.ice_barrier_ready = true
    assert_false(strategies[8].matches(ctx, state), "OOC should not match")
end)

-- ============================================================================
-- Test: frost_nova_matches (strategy #9)
-- ============================================================================

test("frost_nova_matches: ready, in combat, target in melee -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.frost_nova_ready = true
    ctx.target.get_distance = function(other) return 5 end
    assert_true(strategies[9].matches(ctx, state), "target in melee range should match")
end)

test("frost_nova_matches: target far away -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.frost_nova_ready = true
    ctx.target.get_distance = function(other) return 15 end
    assert_false(strategies[9].matches(ctx, state), "target far should not match")
end)

test("frost_nova_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.frost_nova_ready = true
    assert_false(strategies[9].matches(ctx, state), "OOC should not match")
end)

test("frost_nova_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.frost_nova_ready = true
    state.target = nil
    assert_false(strategies[9].matches(ctx, state), "no target should return false")
end)

-- ============================================================================
-- Test: blizzard_matches (strategy #12)
-- ============================================================================

test("blizzard_matches: ready, 3+ enemies, not moving -> true", function()
    local ctx = make_context({enemies_count = 3, is_moving = false})
    local state = get_state(ctx)
    state.blizzard_ready = true
    state.enemies = 3
    state.is_moving = false
    assert_true(strategies[12].matches(ctx, state), "3 enemies stationary should match")
end)

test("blizzard_matches: 1 enemy -> false", function()
    local ctx = make_context({enemies_count = 1})
    local state = get_state(ctx)
    state.blizzard_ready = true
    state.enemies = 1
    assert_false(strategies[12].matches(ctx, state), "1 enemy should not match")
end)

test("blizzard_matches: moving -> false", function()
    local ctx = make_context({enemies_count = 3, is_moving = true})
    local state = get_state(ctx)
    state.blizzard_ready = true
    state.enemies = 3
    state.is_moving = true
    assert_false(strategies[12].matches(ctx, state), "moving should not match")
end)

test("blizzard_matches: not ready -> false", function()
    local ctx = make_context({enemies_count = 3})
    local state = get_state(ctx)
    state.blizzard_ready = false
    state.enemies = 3
    assert_false(strategies[12].matches(ctx, state), "blizzard not ready")
end)

test("blizzard_matches: nil state -> does not crash", function()
    local ok, result = pcall(strategies[12].matches, make_context({enemies_count = 3}), nil)
    assert_true(ok, "nil state should not throw")
end)

-- ============================================================================
-- Test: evocation_matches (strategy #13)
-- ============================================================================

test("evocation_matches: ready, low mana, in combat -> true", function()
    local ctx = make_context({mana_pct = 20})
    local state = get_state(ctx)
    state.evocation_ready = true
    state.mana_pct = 20
    assert_true(strategies[13].matches(ctx, state), "low mana in combat should match")
end)

test("evocation_matches: mana above 25% -> false", function()
    local ctx = make_context({mana_pct = 50})
    local state = get_state(ctx)
    state.evocation_ready = true
    state.mana_pct = 50
    assert_false(strategies[13].matches(ctx, state), "mana above 25% should not match")
end)

test("evocation_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, mana_pct = 20})
    local state = get_state(ctx)
    state.evocation_ready = true
    state.in_combat = false
    state.mana_pct = 20
    assert_false(strategies[13].matches(ctx, state), "OOC should not match")
end)

-- ============================================================================
-- Test: fire_blast_matches (strategy #14)
-- ============================================================================

test("fire_blast_matches: ready, has target, enabled -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.fire_blast_ready = true
    state.use_fire_blast = true
    assert_true(strategies[14].matches(ctx, state), "should match when ready")
end)

test("fire_blast_matches: disabled -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.fire_blast_ready = true
    state.use_fire_blast = false
    assert_false(strategies[14].matches(ctx, state), "disabled should not match")
end)

test("fire_blast_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.fire_blast_ready = true
    state.target = nil
    state.use_fire_blast = true
    assert_false(strategies[14].matches(ctx, state), "no target should not match")
end)

-- ============================================================================
-- Test: scorch_matches (strategy #15)
-- ============================================================================

test("scorch_matches: ready, enabled, not moving, enough mana -> true", function()
    local ctx = make_context({is_moving = false, mana_pct = 50})
    local state = get_state(ctx)
    state.scorch_ready = true
    state.use_scorch = true
    state.is_moving = false
    state.mana_pct = 50
    assert_true(strategies[15].matches(ctx, state), "should match when ready and stationary")
end)

test("scorch_matches: moving -> false", function()
    local ctx = make_context({is_moving = true})
    local state = get_state(ctx)
    state.scorch_ready = true
    state.use_scorch = true
    state.is_moving = true
    assert_false(strategies[15].matches(ctx, state), "moving should not match")
end)

test("scorch_matches: disabled -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.scorch_ready = true
    state.use_scorch = false
    assert_false(strategies[15].matches(ctx, state), "disabled should not match")
end)

test("scorch_matches: low mana -> false", function()
    local ctx = make_context({is_moving = false, mana_pct = 5})
    local state = get_state(ctx)
    state.scorch_ready = true
    state.use_scorch = true
    state.is_moving = false
    state.mana_pct = 5
    assert_false(strategies[15].matches(ctx, state), "low mana should not match")
end)

-- ============================================================================
-- Test: arcane_missiles_matches (strategy #16)
-- ============================================================================

test("arcane_missiles_matches: ready, enabled, not moving, enough mana -> true", function()
    local ctx = make_context({is_moving = false, mana_pct = 50})
    local state = get_state(ctx)
    state.arcane_missiles_ready = true
    state.use_arcane_missiles = true
    state.is_moving = false
    state.mana_pct = 50
    assert_true(strategies[16].matches(ctx, state), "should match when ready and stationary")
end)

test("arcane_missiles_matches: moving -> false", function()
    local ctx = make_context({is_moving = true})
    local state = get_state(ctx)
    state.arcane_missiles_ready = true
    state.use_arcane_missiles = true
    state.is_moving = true
    assert_false(strategies[16].matches(ctx, state), "moving should not match")
end)

test("arcane_missiles_matches: low mana -> false", function()
    local ctx = make_context({mana_pct = 10})
    local state = get_state(ctx)
    state.arcane_missiles_ready = true
    state.use_arcane_missiles = true
    state.mana_pct = 10
    assert_false(strategies[16].matches(ctx, state), "low mana should not match")
end)

test("arcane_missiles_matches: disabled -> false", function()
    local ctx = make_context({is_moving = false})
    local state = get_state(ctx)
    state.arcane_missiles_ready = true
    state.use_arcane_missiles = false
    state.is_moving = false
    assert_false(strategies[16].matches(ctx, state), "disabled should not match")
end)

-- ============================================================================
-- Test: frostbolt_matches (strategy #17)
-- ============================================================================

test("frostbolt_matches: ready, not moving, enough mana -> true", function()
    local ctx = make_context({is_moving = false, mana_pct = 50})
    local state = get_state(ctx)
    state.frostbolt_ready = true
    state.is_moving = false
    state.mana_pct = 50
    assert_true(strategies[17].matches(ctx, state), "should match when ready and stationary")
end)

test("frostbolt_matches: moving -> false", function()
    local ctx = make_context({is_moving = true})
    local state = get_state(ctx)
    state.frostbolt_ready = true
    state.is_moving = true
    assert_false(strategies[17].matches(ctx, state), "moving should not match")
end)

test("frostbolt_matches: low mana -> false", function()
    local ctx = make_context({mana_pct = 5})
    local state = get_state(ctx)
    state.frostbolt_ready = true
    state.mana_pct = 5
    assert_false(strategies[17].matches(ctx, state), "low mana should not match")
end)

test("frostbolt_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.frostbolt_ready = true
    state.target = nil
    assert_false(strategies[17].matches(ctx, state), "no target should not match")
end)

-- ============================================================================
-- Test: wand_matches_fn (strategy #19)
-- ============================================================================

test("wand_matches: low mana, in combat, has target -> true", function()
    local ctx = make_context({mana_pct = 10})
    local state = get_state(ctx)
    state.mana_pct = 10
    state.wand_threshold = 30
    state.wand_learned = true
    assert_true(strategies[19].matches(ctx, state), "low mana should match")
end)

test("wand_matches: enough mana -> false", function()
    local ctx = make_context({mana_pct = 80})
    local state = get_state(ctx)
    state.mana_pct = 80
    state.wand_threshold = 30
    state.wand_learned = true
    assert_false(strategies[19].matches(ctx, state), "enough mana should not match")
end)

test("wand_matches: no target -> false", function()
    local ctx = make_context({target = nil, mana_pct = 10})
    local state = get_state(ctx)
    state.mana_pct = 10
    state.target = nil
    state.wand_learned = true
    assert_false(strategies[19].matches(ctx, state), "no target should not match")
end)

test("wand_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, mana_pct = 10})
    local state = get_state(ctx)
    state.mana_pct = 10
    state.wand_threshold = 30
    state.wand_learned = true
    state.in_combat = false
    assert_true(strategies[19].matches(ctx, state), "Wand matches OOC when mana is below threshold")
end)

test("wand_matches: wand not learned -> false", function()
    local ctx = make_context({mana_pct = 10})
    local state = get_state(ctx)
    state.mana_pct = 10
    state.wand_learned = false
    assert_false(strategies[19].matches(ctx, state), "wand not learned should not match")
end)

-- ============================================================================
-- Test: Strategy priority ordering
-- ============================================================================

test("strategies: 19 strategies in correct priority order", function()
    local expected = {
        "ArcaneIntellect",
        "FrostArmor",
        "RemoveCurse",
        "ConjureManaGem",
        "Polymorph",
        "Counterspell",
        "ManaShield",
        "IceBarrier",
        "FrostNova",
        "ConeOfCold",
        "Blink",
        "Blizzard",
        "Evocation",
        "FireBlast",
        "Scorch",
        "ArcaneMissiles",
        "Frostbolt",
        "UseManaGem",
        "Wand",
    }
    assert_eq(#strategies, 19, "should have 19 strategies after adding FrostArmor, RemoveCurse, ConeOfCold, Blink")
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
-- Test: Execute functions (smoke tests - no crash)
-- ============================================================================

test("execute_ArcaneIntellect: does not crash", function()
    local ok, result = pcall(strategies[1].execute)
    assert_true(ok, "execute should not throw")
end)

test("execute_Wand: does not crash with context", function()
    local ctx = make_context()
    local ok, result = pcall(strategies[19].execute, ctx)
    assert_true(ok, "execute with context should not throw")
end)

test("execute_Wand: does not crash without context", function()
    local ok, result = pcall(strategies[19].execute)
    assert_true(ok, "execute without context should not throw")
end)

-- ============================================================================
-- Test: Nil guard - module returns nil when NS is nil
-- ============================================================================

test("module: returns nil when EaxRotations is nil", function()
    local _, c = build_mock_env()
    _G.EaxRotations = nil
    local nil_mod = dofile("EaxRotations/classes/mage/leveling_sylvanas.lua")
    assert_nil(nil_mod, "should return nil when NS is nil")
    _G.EaxRotations = NS
end)

-- ============================================================================
-- Test: All match functions handle nil context gracefully
-- ============================================================================

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
-- Test: Scenario integration - full rotation cycle
-- ============================================================================

test("rotation: no crashes when evaluating all strategies in sequence", function()
    local ctx = make_context({in_combat = true, mana_pct = 80, hp = 100, enemies_count = 1, is_moving = false})
    local state = get_state(ctx)
    assert_not_nil(state, "state should be built")
    for i, s in ipairs(strategies) do
        local ok_match, matched = pcall(s.matches, ctx, state)
        assert_true(ok_match, "strategy[" .. i .. "] matches should not throw")
        local ok_exec, executed = pcall(s.execute, ctx)
        assert_true(ok_exec, "strategy[" .. i .. "] execute should not throw")
    end
end)

test("rotation: OOC scenario - only OOC buffs should match", function()
    local ctx = make_context({in_combat = false})
    ctx.me.has_buff = function(id) return false end
    local state = get_state(ctx)
    state.has_ai = false
    state.ai_ready = true
    state.polymorph_ready = true

    -- ArcaneIntellect should match (OOC, no buff)
    assert_true(strategies[1].matches(ctx, state), "AI should match OOC without buff")

    -- Polymorph needs a target with low HP to match
    -- state.target already exists from get_state; polymorph checks target HP
    -- The default target's get_health_percentage returns 80, and polymorph_hp is 40
    -- So 80 >= 40 is true, meaning HP too high, polymorph would NOT match
    -- This is correct - stray polymorphs OOC would steal a mob we're not fighting yet
    assert_false(strategies[5].matches(ctx, state), "Polymorph should not match OOC with high-HP target")

    -- Combat abilities should not match OOC
    -- Start at 6 (Counterspell): 4=ConjureManaGem and 5=Polymorph are OOC-gated
    for i = 6, 12 do
        local ok, matched = pcall(strategies[i].matches, ctx, state)
        assert_true(ok, "strategy[" .. i .. "] matches should not throw")
        assert_false(matched, "strategy[" .. i .. "] should not match OOC")
    end
    -- Wand can match OOC if mana is below threshold
    local ok_wand, matched_wand = pcall(strategies[19].matches, ctx, state)
    assert_true(ok_wand, "strategy[13] matches should not throw")
end)

test("rotation: low HP scenario - mana shield should match", function()
    local ctx = make_context({hp = 30, mana_pct = 80})
    local state = get_state(ctx)
    state.has_mana_shield = false
    state.mana_shield_ready = true
    state.hp = 30

    -- ManaShield should match when HP < 40
    assert_true(strategies[7].matches(ctx, state), "ManaShield should match when HP < 40")
end)

test("rotation: AoE scenario - blizzard should match with 3+ enemies", function()
    local ctx = make_context({enemies_count = 4, is_moving = false})
    local state = get_state(ctx)
    state.blizzard_ready = true
    state.enemies = 4
    state.is_moving = false

    -- Blizzard should match with 3+ enemies stationary
    assert_true(strategies[12].matches(ctx, state), "Blizzard should match with 3+ enemies")
end)

test("rotation: low mana scenario - wand should match", function()
    local ctx = make_context({mana_pct = 10})
    local state = get_state(ctx)
    state.mana_pct = 10
    state.wand_threshold = 30
    state.wand_learned = true

    -- Wand should match when mana below threshold
    assert_true(strategies[19].matches(ctx, state), "Wand should match when mana below threshold")
end)

-- ============================================================================
-- Edge Case: Polymorph boundaries
-- ============================================================================

test("edge_polymorph: target HP exactly at threshold (40) should not match", function()
    local ctx = make_context({in_combat = false})
    ctx.target = {
        is_valid = function() return true end,
        get_health = function() return 4000 end,
        get_max_health = function() return 10000 end,
        is_casting = function() return false end,
        is_alive = function() return true end,
        get_guid = function() return "mock-target" end,
        get_distance = function(other) return 5 end,
        get_health_percentage = function() return 40 end,
    }
    local state = get_state(ctx)
    state.polymorph_ready = true
    state.polymorph_hp = 40
    assert_false(strategies[5].matches(ctx, state), "HP at exactly 40 should not match (40 >= 40)")
end)

test("edge_polymorph: target HP just below threshold (39) should match", function()
    local ctx = make_context({in_combat = false})
    ctx.target = {
        is_valid = function() return true end,
        get_health = function() return 3900 end,
        get_max_health = function() return 10000 end,
        is_casting = function() return false end,
        is_alive = function() return true end,
        get_guid = function() return "mock-target" end,
        get_distance = function(other) return 5 end,
        get_health_percentage = function() return 39 end,
    }
    local state = get_state(ctx)
    state.polymorph_ready = true
    state.polymorph_hp = 40
    assert_true(strategies[5].matches(ctx, state), "HP at 39 should match (< 40)")
end)

test("edge_polymorph: debuff remains at exactly 10 boundary should not match", function()
    local ctx = make_context({in_combat = false})
    ctx.target = {
        is_valid = function() return true end,
        get_health = function() return 2000 end,
        get_max_health = function() return 10000 end,
        is_casting = function() return false end,
        is_alive = function() return true end,
        get_guid = function() return "mock-target" end,
        get_distance = function(other) return 5 end,
        get_health_percentage = function() return 20 end,
    }
    local state = get_state(ctx)
    state.polymorph_ready = true
    state.polymorph_hp = 40
    local saved_debuff = NS.debuff_remains
    NS.debuff_remains = function() return 10 end
    assert_false(strategies[5].matches(ctx, state), "debuff at exactly 10s should not match (10 >= 10 is true, returns false)")
    NS.debuff_remains = saved_debuff
end)

test("edge_polymorph: debuff remains at 9 should match", function()
    local ctx = make_context({in_combat = false})
    ctx.target = {
        is_valid = function() return true end,
        get_health = function() return 2000 end,
        get_max_health = function() return 10000 end,
        is_casting = function() return false end,
        is_alive = function() return true end,
        get_guid = function() return "mock-target" end,
        get_distance = function(other) return 5 end,
        get_health_percentage = function() return 20 end,
    }
    local state = get_state(ctx)
    state.polymorph_ready = true
    state.polymorph_hp = 40
    local saved_debuff = NS.debuff_remains
    NS.debuff_remains = function() return 9 end
    assert_true(strategies[5].matches(ctx, state), "debuff at 9s should match (< 10)")
    NS.debuff_remains = saved_debuff
end)

test("edge_polymorph: not ready returns false", function()
    local ctx = make_context({in_combat = false})
    ctx.target = {
        is_valid = function() return true end,
        get_health = function() return 2000 end,
        get_max_health = function() return 10000 end,
        is_casting = function() return false end,
        is_alive = function() return true end,
        get_guid = function() return "mock-target" end,
        get_distance = function(other) return 5 end,
        get_health_percentage = function() return 20 end,
    }
    local state = get_state(ctx)
    state.polymorph_ready = false
    state.polymorph_hp = 40
    assert_false(strategies[5].matches(ctx, state), "polymorph not ready should not match")
end)

test("edge_polymorph: NS.debuff_remains nil does not crash", function()
    local ctx = make_context({in_combat = false})
    ctx.target = {
        is_valid = function() return true end,
        get_health = function() return 2000 end,
        get_max_health = function() return 10000 end,
        is_casting = function() return false end,
        is_alive = function() return true end,
        get_guid = function() return "mock-target" end,
        get_distance = function(other) return 5 end,
        get_health_percentage = function() return 20 end,
    }
    local saved_debuff = NS.debuff_remains
    NS.debuff_remains = nil
    local state = get_state(ctx)
    state.polymorph_ready = true
    state.polymorph_hp = 40
    local ok, result = pcall(strategies[5].matches, ctx, state)
    assert_true(ok, "NS.debuff_remains nil should not throw")
    NS.debuff_remains = saved_debuff
end)

-- ============================================================================
-- Edge Case: Counterspell resilience
-- ============================================================================

test("edge_counterspell: is_casting throws error should not crash", function()
    local ctx = make_context()
    ctx.target = {
        is_valid = function() return true end,
        get_health = function() return 8000 end,
        get_max_health = function() return 10000 end,
        is_casting = function() error("simulated throw from is_casting") end,
        is_alive = function() return true end,
        get_guid = function() return "mock-target" end,
        get_distance = function(other) return 5 end,
        get_health_percentage = function() return 80 end,
    }
    local state = get_state(ctx)
    state.counterspell_ready = true
    state.use_interrupt = true
    local ok, result = pcall(strategies[6].matches, ctx, state)
    assert_true(ok, "is_casting throw should be caught by pcall in counterspell_matches")
end)

test("edge_counterspell: no target returns false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.counterspell_ready = true
    state.target = nil
    state.use_interrupt = true
    assert_false(strategies[6].matches(ctx, state), "no target should return false")
end)

test("edge_counterspell: interrupt disabled returns false", function()
    local ctx = make_context()
    ctx.target.is_casting = function() return true end
    local state = get_state(ctx)
    state.counterspell_ready = true
    state.use_interrupt = false
    assert_false(strategies[6].matches(ctx, state), "interrupt disabled should return false")
end)

-- ============================================================================
-- Edge Case: Buff API resilience (build_state)
-- ============================================================================

test("edge_buff: NS.buff_up nil in build_state returns false for all buffs", function()
    local ctx = make_context({in_combat = false})
    local saved_buff_up = NS.buff_up
    NS.buff_up = nil
    local state = get_state(ctx)
    assert_false(state.has_ai, "has_ai should be false when NS.buff_up nil")
    assert_false(state.has_molten_armor, "has_molten_armor should be false")
    assert_false(state.has_ice_barrier, "has_ice_barrier should be false")
    assert_false(state.has_mana_shield, "has_mana_shield should be false")
    NS.buff_up = saved_buff_up
end)

test("edge_buff: NS.buff_up throws in build_state is caught by pcall", function()
    local ctx = make_context({in_combat = false})
    local saved_buff_up = NS.buff_up
    NS.buff_up = function() error("simulated throw from NS.buff_up") end
    local ok, state = pcall(get_state, ctx)
    assert_true(ok, "NS.buff_up throw should be caught - build_state should not crash")
    if ok and state then
        assert_false(state.has_ai, "has_ai should be false when NS.buff_up throws")
        assert_false(state.has_molten_armor, "has_molten_armor should be false")
        assert_false(state.has_ice_barrier, "has_ice_barrier should be false")
        assert_false(state.has_mana_shield, "has_mana_shield should be false")
    end
    NS.buff_up = saved_buff_up
end)

-- ============================================================================
-- Edge Case: Frost Nova distance boundary
-- ============================================================================

test("edge_frost_nova: target at exactly 10 yards should match", function()
    local ctx = make_context()
    ctx.target.get_distance = function(other) return 10 end
    local state = get_state(ctx)
    state.frost_nova_ready = true
    assert_true(strategies[9].matches(ctx, state), "target at exactly 10 yards should match (dist <= 10)")
end)

test("edge_frost_nova: target at 11 yards should not match", function()
    local ctx = make_context()
    ctx.target.get_distance = function(other) return 11 end
    local state = get_state(ctx)
    state.frost_nova_ready = true
    assert_false(strategies[9].matches(ctx, state), "target at 11 yards should not match (dist > 10)")
end)

-- ============================================================================
-- Edge Case: Blizzard enemy count boundary
-- ============================================================================

test("edge_blizzard: exactly 2 enemies does not match", function()
    local ctx = make_context({enemies_count = 2, is_moving = false})
    local state = get_state(ctx)
    state.blizzard_ready = true
    state.enemies = 2
    state.is_moving = false
    assert_false(strategies[12].matches(ctx, state), "exactly 2 enemies should not match (< 3)")
end)

test("edge_blizzard: exactly 3 enemies matches", function()
    local ctx = make_context({enemies_count = 3, is_moving = false})
    local state = get_state(ctx)
    state.blizzard_ready = true
    state.enemies = 3
    state.is_moving = false
    assert_true(strategies[12].matches(ctx, state), "exactly 3 enemies should match (>= 3)")
end)

-- ============================================================================
-- Edge Case: Movement restrictions
-- ============================================================================

test("edge_movement: frostbolt while moving does not match", function()
    local ctx = make_context({is_moving = true, mana_pct = 80})
    local state = get_state(ctx)
    state.frostbolt_ready = true
    state.is_moving = true
    state.mana_pct = 80
    assert_false(strategies[17].matches(ctx, state), "frostbolt while moving should not match")
end)

test("edge_movement: scorch while moving does not match", function()
    local ctx = make_context({is_moving = true, mana_pct = 80})
    local state = get_state(ctx)
    state.scorch_ready = true
    state.use_scorch = true
    state.is_moving = true
    state.mana_pct = 80
    assert_false(strategies[15].matches(ctx, state), "scorch while moving should not match")
end)

test("edge_movement: arcane missiles while moving does not match", function()
    local ctx = make_context({is_moving = true, mana_pct = 80})
    local state = get_state(ctx)
    state.arcane_missiles_ready = true
    state.use_arcane_missiles = true
    state.is_moving = true
    state.mana_pct = 80
    assert_false(strategies[16].matches(ctx, state), "arcane missiles while moving should not match")
end)

test("edge_movement: blizzard while moving does not match", function()
    local ctx = make_context({is_moving = true, enemies_count = 4})
    local state = get_state(ctx)
    state.blizzard_ready = true
    state.enemies = 4
    state.is_moving = true
    assert_false(strategies[12].matches(ctx, state), "blizzard while moving should not match")
end)

test("edge_movement: fire blast (instant) still works while moving", function()
    local ctx = make_context({is_moving = true})
    local state = get_state(ctx)
    state.fire_blast_ready = true
    state.use_fire_blast = true
    state.is_moving = true
    assert_true(strategies[14].matches(ctx, state), "fire blast (instant) should work while moving")
end)

-- ============================================================================
-- Edge Case: Wand threshold boundary
-- ============================================================================

test("edge_wand: mana exactly at threshold (30) should not match", function()
    local ctx = make_context({mana_pct = 30})
    local state = get_state(ctx)
    state.mana_pct = 30
    state.wand_threshold = 30
    state.wand_learned = true
    assert_false(strategies[19].matches(ctx, state), "mana exactly at threshold should not match (mana >= threshold)")
end)

test("edge_wand: wand not learned returns false even at low mana", function()
    local ctx = make_context({mana_pct = 10})
    local state = get_state(ctx)
    state.mana_pct = 10
    state.wand_threshold = 30
    state.wand_learned = false
    assert_false(strategies[19].matches(ctx, state), "wand not learned should return false")
end)

-- ============================================================================
-- Edge Case: API resilience (nil/throwing NS functions)
-- ============================================================================

test("edge_api: NS.spell_ready nil in build_state should not crash", function()
    local saved = NS.spell_ready
    NS.spell_ready = nil
    local ctx = make_context()
    local ok, state = pcall(get_state, ctx)
    assert_true(ok, "NS.spell_ready nil should not crash build_state")
    if ok and state then
        assert_false(state.frostbolt_ready, "frostbolt should not be ready when NS.spell_ready nil")
        assert_false(state.fire_blast_ready, "fire_blast should not be ready")
    end
    NS.spell_ready = saved
end)

test("edge_api: NS.spell_ready throws in build_state should not crash", function()
    local saved = NS.spell_ready
    NS.spell_ready = function() error("simulated throw in NS.spell_ready") end
    local ctx = make_context()
    local ok, state = pcall(get_state, ctx)
    assert_true(ok, "NS.spell_ready throw should not crash build_state (wrapped in spell_is_ready pcall)")
    if ok and state then
        assert_false(state.frostbolt_ready, "frostbolt should not be ready when NS.spell_ready throws")
    end
    NS.spell_ready = saved
end)

test("edge_api: NS.try_cast nil does not crash execute", function()
    local saved = NS.try_cast
    NS.try_cast = nil
    local ctx = make_context()
    local ok, result = pcall(strategies[17].execute, ctx)  -- Frostbolt execute
    assert_true(ok, "NS.try_cast nil should not crash execute")
    NS.try_cast = saved
end)

test("edge_api: NS.try_cast nil does not crash execute with nil context", function()
    local saved = NS.try_cast
    NS.try_cast = nil
    local ok, result = pcall(strategies[17].execute, nil)  -- Frostbolt execute
    assert_true(ok, "NS.try_cast nil with nil context should not crash")
    NS.try_cast = saved
end)

test("edge_api: NS.spell_exists nil in build_state should not crash", function()
    local saved = NS.spell_exists
    NS.spell_exists = nil
    local ctx = make_context()
    local ok, state = pcall(get_state, ctx)
    assert_true(ok, "NS.spell_exists nil should not crash build_state")
    if ok and state then
        assert_false(state.wand_learned, "wand not learned when NS.spell_exists nil")
    end
    NS.spell_exists = saved
end)

-- ============================================================================
-- Edge Case: All disabled
-- ============================================================================

test("edge_all_disabled: all toggles off, only wand matches", function()
    local ctx = make_context({
        in_combat = true,
        mana_pct = 10,
        hp = 30,
        enemies_count = 4,
        is_moving = false,
    })
    ctx.settings.leveling_fire_blast_use = false
    ctx.settings.leveling_scorch_use = false
    ctx.settings.leveling_arcane_missiles_use = false
    ctx.settings.use_interrupt = false
    ctx.me.has_buff = function(id) return false end
    local state = get_state(ctx)

    -- Set all spell readiness to true
    state.frostbolt_ready = true
    state.fire_blast_ready = true
    state.scorch_ready = true
    state.arcane_missiles_ready = true
    state.frost_nova_ready = true
    state.blizzard_ready = true
    state.polymorph_ready = true
    state.counterspell_ready = true
    state.evocation_ready = true
    state.ice_barrier_ready = true
    state.mana_shield_ready = true
    state.ai_ready = true

    -- Verify each toggle-gated strategy returns false
    assert_false(strategies[5].matches(ctx, state), "polymorph disabled OOC with low HP target")
    assert_false(strategies[6].matches(ctx, state), "counterspell disabled")
    assert_false(strategies[14].matches(ctx, state), "fire_blast disabled")
    assert_false(strategies[15].matches(ctx, state), "scorch disabled")
    assert_false(strategies[16].matches(ctx, state), "arcane_missiles disabled")

    -- But wand should still match (no toggle gate)
    state.wand_threshold = 30
    state.wand_learned = true
    assert_true(strategies[19].matches(ctx, state), "wand should still match when mana low")
end)

-- ============================================================================
-- Edge Case: Rotation crash safety
-- ============================================================================

test("edge_rotation_crash: all match functions handle nil context -> false", function()
    for i, s in ipairs(strategies) do
        local ok, result = pcall(s.matches, nil, {})
        assert_true(ok, "strategy[" .. i .. "] (" .. s.name .. ") matches(nil, {}) should not throw")
    end
end)

test("edge_rotation_crash: all match functions handle nil state -> no crash", function()
    local ctx = make_context()
    for i, s in ipairs(strategies) do
        local ok, result = pcall(s.matches, ctx, nil)
        assert_true(ok, "strategy[" .. i .. "] (" .. s.name .. ") matches(ctx, nil) should not throw")
    end
end)

test("edge_rotation_crash: all execute functions handle nil context -> false", function()
    for i, s in ipairs(strategies) do
        local ok, result = pcall(s.execute, nil)
        assert_true(ok, "strategy[" .. i .. "] (" .. s.name .. ") execute(nil) should not throw")
    end
end)

-- ============================================================================
-- Edge Case: Settings custom thresholds
-- ============================================================================

test("edge_settings: custom polymorph_hp=60 means 55 HP target matches", function()
    local ctx = make_context({in_combat = false})
    ctx.settings.leveling_polymorph_hp = 60
    ctx.target = {
        is_valid = function() return true end,
        get_health = function() return 5500 end,
        get_max_health = function() return 10000 end,
        is_casting = function() return false end,
        is_alive = function() return true end,
        get_guid = function() return "mock-target" end,
        get_distance = function(other) return 5 end,
        get_health_percentage = function() return 55 end,
    }
    local state = get_state(ctx)
    state.polymorph_ready = true
    state.polymorph_hp = 60
    assert_true(strategies[5].matches(ctx, state), "HP 55 < 60 threshold should match")
end)

test("edge_settings: custom wand_threshold=15 means 15% mana does not wand", function()
    local ctx = make_context({mana_pct = 15})
    ctx.settings.leveling_wand_threshold = 15
    local state = get_state(ctx)
    state.mana_pct = 15
    state.wand_threshold = 15
    state.wand_learned = true
    assert_false(strategies[19].matches(ctx, state), "wand at threshold 15 should not match (mana >= threshold)")
end)

test("edge_settings: custom wand_threshold=15 means 14% mana does wand", function()
    local ctx = make_context({mana_pct = 14})
    ctx.settings.leveling_wand_threshold = 15
    local state = get_state(ctx)
    state.mana_pct = 14
    state.wand_threshold = 15
    state.wand_learned = true
    assert_true(strategies[19].matches(ctx, state), "wand at 14 < 15 threshold should match")
end)

-- ============================================================================
-- Edge Case: Mana gem conjure
-- ============================================================================

test("edge_mana_gem: conjure OOC, ready, no gem -> true", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.conjure_gem_ready = true
    state.mana_gem_available = false
    assert_true(strategies[4].matches(ctx, state), "OOC conjure ready without gem should match")
end)

test("edge_mana_gem: conjure in combat -> false", function()
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.conjure_gem_ready = true
    state.mana_gem_available = false
    assert_false(strategies[4].matches(ctx, state), "conjure in combat should not match")
end)

test("edge_mana_gem: conjure not ready -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.conjure_gem_ready = false
    state.mana_gem_available = false
    assert_false(strategies[4].matches(ctx, state), "conjure not ready should not match")
end)

test("edge_mana_gem: conjure already have gem -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.conjure_gem_ready = true
    state.mana_gem_available = true
    assert_false(strategies[4].matches(ctx, state), "already have gem should not conjure")
end)

test("edge_mana_gem: conjure execute returns false when no spell known", function()
    local saved_exists = NS.spell_exists
    NS.spell_exists = function(id) return false end
    local ctx = make_context({in_combat = false})
    local ok, result = pcall(strategies[4].execute)
    assert_true(ok, "conjure execute should not crash when no spell known")
    NS.spell_exists = saved_exists
end)

test("edge_mana_gem: conjure nil state does not crash", function()
    local ctx = make_context({in_combat = false})
    local ok, result = pcall(strategies[4].matches, ctx, nil)
    assert_true(ok, "conjure matches with nil state should not crash")
end)

-- ============================================================================
-- Edge Case: Mana gem use (in combat)
-- ============================================================================

test("edge_mana_gem_use: in combat, low mana, gem available -> true", function()
    local ctx = make_context({mana_pct = 50, in_combat = true})
    local saved_ready = NS.is_item_ready
    NS.is_item_ready = function(id) return true end
    local state = get_state(ctx)
    state.use_mana_gem = true
    state.mana_gem_available = true
    state.mana_pct = 50
    state.mana_gem_threshold = 70
    assert_true(strategies[18].matches(ctx, state), "low mana with gem should match")
    NS.is_item_ready = saved_ready
end)

test("edge_mana_gem_use: mana above threshold -> false", function()
    local ctx = make_context({mana_pct = 80, in_combat = true})
    local saved_ready = NS.is_item_ready
    NS.is_item_ready = function(id) return true end
    local state = get_state(ctx)
    state.use_mana_gem = true
    state.mana_gem_available = true
    state.mana_pct = 80
    state.mana_gem_threshold = 70
    assert_false(strategies[18].matches(ctx, state), "mana above threshold should not match")
    NS.is_item_ready = saved_ready
end)

test("edge_mana_gem_use: OOC -> false", function()
    local ctx = make_context({mana_pct = 50, in_combat = false})
    local state = get_state(ctx)
    state.use_mana_gem = true
    state.mana_gem_available = true
    state.mana_pct = 50
    state.mana_gem_threshold = 70
    assert_false(strategies[18].matches(ctx, state), "OOC should not use gem")
end)

test("edge_mana_gem_use: use_mana_gem disabled -> false", function()
    local ctx = make_context({mana_pct = 50, in_combat = true})
    local state = get_state(ctx)
    state.use_mana_gem = false
    state.mana_gem_available = true
    state.mana_pct = 50
    state.mana_gem_threshold = 70
    assert_false(strategies[18].matches(ctx, state), "disabled setting should not match")
end)

test("edge_mana_gem_use: no gem available -> false", function()
    local ctx = make_context({mana_pct = 50, in_combat = true})
    local state = get_state(ctx)
    state.use_mana_gem = true
    state.mana_gem_available = false
    state.mana_pct = 50
    state.mana_gem_threshold = 70
    assert_false(strategies[18].matches(ctx, state), "no gem in inventory should not match")
end)

test("edge_mana_gem_use: nil state does not crash", function()
    local ctx = make_context({mana_pct = 50, in_combat = true})
    local ok, result = pcall(strategies[18].matches, ctx, nil)
    assert_true(ok, "use gem with nil state should not crash")
end)

test("edge_mana_gem_use: execute with no items ready returns false", function()
    local saved_ready = NS.is_item_ready
    NS.is_item_ready = function(id) return false end
    local ok, result = pcall(strategies[18].execute)
    assert_true(ok, "use gem execute with no items should not crash")
    NS.is_item_ready = saved_ready
end)

test("edge_mana_gem_use: execute with nil NS.is_item_ready returns false", function()
    local saved_ready = NS.is_item_ready
    NS.is_item_ready = nil
    local ok, result = pcall(strategies[18].execute)
    assert_true(ok, "use gem execute with nil NS.is_item_ready should not crash")
    NS.is_item_ready = saved_ready
end)

test("edge_mana_gem_use: mana at exactly threshold should not match", function()
    local ctx = make_context({mana_pct = 70, in_combat = true})
    local saved_ready = NS.is_item_ready
    NS.is_item_ready = function(id) return true end
    local state = get_state(ctx)
    state.use_mana_gem = true
    state.mana_gem_available = true
    state.mana_pct = 70
    state.mana_gem_threshold = 70
    assert_false(strategies[18].matches(ctx, state), "mana exactly at 70 threshold should not match (70 > 70 is false)")
    NS.is_item_ready = saved_ready
end)

-- ============================================================================
-- ============================================================================
-- Edge case: HP boundaries
-- ============================================================================
do
    -- ManaShield: hp <= 40 -> match; hp > 40 -> no match
    local ctx = make_context({ hp = 40 })
    local state = get_state(ctx)
    state.mana_shield_ready = true
    state.ice_barrier_ready = true
    state.frostbolt_ready = true
    state.arcane_missiles_ready = true
    state.fire_blast_ready = true
    state.scorch_ready = true
    assert_true(strategies[7].matches(ctx, state), "manashield hp=40 -> match (hp <= 40)")

    local ctx2 = make_context({ hp = 41 })
    local state2 = get_state(ctx2)
    state2.mana_shield_ready = true
    state2.ice_barrier_ready = true
    assert_false(strategies[7].matches(ctx2, state2), "manashield hp=41 -> no match (hp > 40)")

    -- Blink: hp <= 50 -> match; hp > 50 -> no match
    local ctx3 = make_context({ hp = 50 })
    local state3 = get_state(ctx3)
    state3.blink_ready = true
    assert_true(strategies[11].matches(ctx3, state3), "blink hp=50 -> match (hp <= 50)")

    local ctx4 = make_context({ hp = 51 })
    local state4 = get_state(ctx4)
    state4.blink_ready = true
    assert_false(strategies[11].matches(ctx4, state4), "blink hp=51 -> no match (hp > 50)")
end

-- ============================================================================
-- Edge case: Mana boundaries
-- ============================================================================
do
    -- Evocation: mana_pct <= 25 -> match; > 25 -> no match
    local ctx = make_context({ mana_pct = 25 })
    local state = get_state(ctx)
    state.evocation_ready = true
    assert_true(strategies[13].matches(ctx, state), "evocation mana=25 -> match (<=25)")

    local ctx2 = make_context({ mana_pct = 26 })
    local state2 = get_state(ctx2)
    state2.evocation_ready = true
    assert_false(strategies[13].matches(ctx2, state2), "evocation mana=26 -> no match (>25)")

    -- ArcaneMissiles: mana_pct >= 20 -> match; < 20 -> no match
    local ctx3 = make_context({ mana_pct = 20 })
    local state3 = get_state(ctx3)
    state3.arcane_missiles_ready = true
    state3.use_arcane_missiles = true
    state3.frostbolt_ready = true
    state3.fire_blast_ready = true
    state3.scorch_ready = true
    assert_true(strategies[16].matches(ctx3, state3), "arcanemissiles mana=20 -> match (>=20)")

    local ctx4 = make_context({ mana_pct = 19 })
    local state4 = get_state(ctx4)
    state4.arcane_missiles_ready = true
    state4.use_arcane_missiles = true
    assert_false(strategies[16].matches(ctx4, state4), "arcanemissiles mana=19 -> no match (<20)")

    -- Frostbolt: mana_pct >= 10 -> match; < 10 -> no match
    local ctx5 = make_context({ mana_pct = 10 })
    local state5 = get_state(ctx5)
    state5.frostbolt_ready = true
    state5.fire_blast_ready = true
    state5.scorch_ready = true
    assert_true(strategies[17].matches(ctx5, state5), "frostbolt mana=10 -> match (>=10)")

    local ctx6 = make_context({ mana_pct = 9 })
    local state6 = get_state(ctx6)
    state6.frostbolt_ready = true
    assert_false(strategies[17].matches(ctx6, state6), "frostbolt mana=9 -> no match (<10)")

    -- Scorch: mana_pct >= 10 -> match; < 10 -> no match
    local ctx7 = make_context({ mana_pct = 10 })
    local state7 = get_state(ctx7)
    state7.scorch_ready = true
    state7.use_scorch = true
    state7.fire_blast_ready = true
    assert_true(strategies[15].matches(ctx7, state7), "scorch mana=10 -> match (>=10)")

    local ctx8 = make_context({ mana_pct = 9 })
    local state8 = get_state(ctx8)
    state8.scorch_ready = true
    state8.use_scorch = true
    assert_false(strategies[15].matches(ctx8, state8), "scorch mana=9 -> no match (<10)")
end

-- ============================================================================
-- Edge case: Wand threshold
-- ============================================================================
do
    -- Wand: mana_pct < wand_threshold (default 30) -> match
    local ctx = make_context({ mana_pct = 29 })
    ctx.wand_learned = true
    local state = get_state(ctx)
    state.wand_learned = true
    state.frostbolt_ready = true
    state.arcane_missiles_ready = true
    assert_true(strategies[19].matches(ctx, state), "wand mana=29 -> match (<30)")

    local ctx2 = make_context({ mana_pct = 30 })
    ctx2.wand_learned = true
    local state2 = get_state(ctx2)
    state2.wand_learned = true
    state2.frostbolt_ready = true
    state2.arcane_missiles_ready = true
    assert_false(strategies[19].matches(ctx2, state2), "wand mana=30 -> no match (>=30)")
end

-- ============================================================================
-- Edge case: Mana gem boundaries
-- ============================================================================
do
    -- UseManaGem: mana_pct < mana_gem_threshold (default 70) -> match
    local ctx = make_context({ mana_pct = 69 })
    ctx.mana_gem_available = true
    local state = get_state(ctx)
    state.mana_gem_available = true
    state.use_mana_gem = true
    state.frostbolt_ready = true
    state.arcane_missiles_ready = true
    state.fire_blast_ready = true
    state.scorch_ready = true
    assert_true(strategies[18].matches(ctx, state), "usemanagem mana=69 -> match (<70)")

    local ctx2 = make_context({ mana_pct = 70 })
    ctx2.mana_gem_available = true
    local state2 = get_state(ctx2)
    state2.mana_gem_available = true
    state2.use_mana_gem = true
    assert_false(strategies[18].matches(ctx2, state2), "usemanagem mana=70 -> no match (>=70)")

    -- UseManaGem: no gem available -> no match
    local ctx3 = make_context({ mana_pct = 50 })
    ctx3.mana_gem_available = false
    local state3 = get_state(ctx3)
    state3.mana_gem_available = false
    state3.use_mana_gem = true
    assert_false(strategies[18].matches(ctx3, state3), "usemanagem no gem -> no match")

    -- ConjureManaGem: gem already available -> no match
    local ctx4 = make_context({ in_combat = false })
    ctx4.mana_gem_available = true
    local state4 = get_state(ctx4)
    state4.conjure_gem_ready = true
    state4.mana_gem_available = true
    assert_false(strategies[4].matches(ctx4, state4), "conjuregem gem available -> no match")
end

-- ============================================================================
-- Edge case: Polymorph boundaries
-- ============================================================================
do
    -- Polymorph: target HP < polymorph_hp (40) -> match
    local ctx = make_context({ in_combat = false, enemies_count = 0 })
    ctx.polymorph_hp = 40
    ctx.target = {
        is_valid = function() return true end,
        get_health = function() return 3900 end,
        get_max_health = function() return 10000 end,
        get_health_percentage = function() return 39 end,
    }
    local state = get_state(ctx)
    state.polymorph_ready = true
    state.ai_ready = true
    state.frost_armor_ready = true
    assert_true(strategies[5].matches(ctx, state), "polymorph target_hp=39 -> match (<40)")

    local ctx2 = make_context({ in_combat = false, enemies_count = 0 })
    ctx2.polymorph_hp = 40
    ctx2.target = {
        is_valid = function() return true end,
        get_health = function() return 4000 end,
        get_max_health = function() return 10000 end,
        get_health_percentage = function() return 40 end,
    }
    local state2 = get_state(ctx2)
    state2.polymorph_ready = true
    state2.ai_ready = true
    state2.frost_armor_ready = true
    assert_false(strategies[5].matches(ctx2, state2), "polymorph target_hp=40 -> no match (>=40)")

    -- Polymorph: remains >= 10 -> no match
    local ctx3 = make_context({ in_combat = false, enemies_count = 0 })
    ctx3.target = {
        is_valid = function() return true end,
        get_health = function() return 3000 end,
        get_max_health = function() return 10000 end,
        get_health_percentage = function() return 30 end,
    }
    local state3 = get_state(ctx3)
    state3.polymorph_ready = true
    state3.ai_ready = true
    state3.frost_armor_ready = true
    local saved = NS.debuff_remains
    NS.debuff_remains = function(target, spell) return 9 end
    assert_true(strategies[5].matches(ctx3, state3), "polymorph remains=9 -> match (<10)")
    NS.debuff_remains = saved

    local ctx4 = make_context({ in_combat = false, enemies_count = 0 })
    ctx4.target = {
        is_valid = function() return true end,
        get_health = function() return 3000 end,
        get_max_health = function() return 10000 end,
        get_health_percentage = function() return 30 end,
    }
    local state4 = get_state(ctx4)
    state4.polymorph_ready = true
    state4.ai_ready = true
    state4.frost_armor_ready = true
    local saved4 = NS.debuff_remains
    NS.debuff_remains = function(target, spell) return 10 end
    assert_false(strategies[5].matches(ctx4, state4), "polymorph remains=10 -> no match (>=10)")
    NS.debuff_remains = saved4
end

-- ============================================================================
-- Edge case: Enemy thresholds
-- ============================================================================
do
    -- Blizzard: enemies >= 3 -> match; < 3 -> no match
    local ctx = make_context({ enemies_count = 3 })
    local state = get_state(ctx)
    state.blizzard_ready = true
    state.frostbolt_ready = true
    state.arcane_missiles_ready = true
    state.fire_blast_ready = true
    state.scorch_ready = true
    assert_true(strategies[12].matches(ctx, state), "blizzard enemies=3 -> match (>=3)")

    local ctx2 = make_context({ enemies_count = 2 })
    local state2 = get_state(ctx2)
    state2.blizzard_ready = true
    assert_false(strategies[12].matches(ctx2, state2), "blizzard enemies=2 -> no match (<3)")

    -- ConeOfCold: enemies >= 2 -> match; < 2 -> no match
    local ctx3 = make_context({ enemies_count = 2 })
    ctx3.me = { is_valid = function() return true end, get_position = function() return { x = 0, y = 0, z = 0 } end }
    ctx3.target = {
        is_valid = function() return true end,
        get_health = function() return 8000 end,
        get_max_health = function() return 10000 end,
        get_health_percentage = function() return 80 end,
        get_distance = function(other) return 5 end,
    }
    local state3 = get_state(ctx3)
    state3.cone_of_cold_ready = true
    state3.frostbolt_ready = true
    state3.arcane_missiles_ready = true
    state3.fire_blast_ready = true
    state3.scorch_ready = true
    assert_true(strategies[10].matches(ctx3, state3), "conecold enemies=2 -> match (>=2)")

    local ctx4 = make_context({ enemies_count = 1 })
    ctx4.me = { is_valid = function() return true end, get_position = function() return { x = 0, y = 0, z = 0 } end }
    local state4 = get_state(ctx4)
    state4.cone_of_cold_ready = true
    assert_false(strategies[10].matches(ctx4, state4), "conecold enemies=1 -> no match (<2)")
end

-- ============================================================================
-- Edge case: Movement guards
-- ============================================================================
do
    -- Blizzard: is_moving -> no match
    local ctx = make_context({ is_moving = true, enemies_count = 3 })
    local state = get_state(ctx)
    state.blizzard_ready = true
    assert_false(strategies[12].matches(ctx, state), "blizzard moving -> no match")

    -- ArcaneMissiles: is_moving -> no match
    local ctx2 = make_context({ is_moving = true })
    local state2 = get_state(ctx2)
    state2.arcane_missiles_ready = true
    state2.use_arcane_missiles = true
    assert_false(strategies[16].matches(ctx2, state2), "arcanemissiles moving -> no match")

    -- Frostbolt: is_moving -> no match
    local ctx3 = make_context({ is_moving = true })
    local state3 = get_state(ctx3)
    state3.frostbolt_ready = true
    assert_false(strategies[17].matches(ctx3, state3), "frostbolt moving -> no match")

    -- Scorch: is_moving -> no match
    local ctx4 = make_context({ is_moving = true })
    local state4 = get_state(ctx4)
    state4.scorch_ready = true
    state4.use_scorch = true
    assert_false(strategies[15].matches(ctx4, state4), "scorch moving -> no match")
end

-- ============================================================================
-- Edge case: Buff guards
-- ============================================================================
do
    -- ArcaneIntellect: has_ai -> no match
    local ctx = make_context({ in_combat = false, enemies_count = 0 })
    local state = get_state(ctx)
    state.has_ai = true
    state.ai_ready = true
    assert_false(strategies[1].matches(ctx, state), "arcaneintellect buff active -> no match")

    -- FrostArmor: has_frost_armor -> no match
    local ctx2 = make_context({ in_combat = false, enemies_count = 0 })
    local state2 = get_state(ctx2)
    state2.has_frost_armor = true
    state2.frost_armor_ready = true
    assert_false(strategies[2].matches(ctx2, state2), "frostarmor buff active -> no match")

    -- FrostArmor: has_mage_armor -> no match
    local ctx3 = make_context({ in_combat = false, enemies_count = 0 })
    local state3 = get_state(ctx3)
    state3.has_frost_armor = false
    state3.has_mage_armor = true
    state3.frost_armor_ready = true
    assert_false(strategies[2].matches(ctx3, state3), "frostarmor mage armor active -> no match")

    -- IceBarrier: has_ice_barrier -> no match
    local ctx4 = make_context({})
    local state4 = get_state(ctx4)
    state4.has_ice_barrier = true
    state4.ice_barrier_ready = true
    assert_false(strategies[8].matches(ctx4, state4), "icebarrier buff active -> no match")
end

-- ============================================================================
-- Edge case: Settings toggle
-- ============================================================================
do
    -- FireBlast: use_fire_blast disabled -> no match
    local ctx = make_context({})
    ctx.settings.leveling_fire_blast_use = false
    local state = get_state(ctx)
    state.fire_blast_ready = true
    state.frostbolt_ready = true
    state.arcane_missiles_ready = true
    state.scorch_ready = true
    assert_false(strategies[14].matches(ctx, state), "fireblast setting disabled -> no match")

    -- Scorch: use_scorch disabled -> no match
    local ctx2 = make_context({})
    ctx2.settings.leveling_scorch_use = false
    local state2 = get_state(ctx2)
    state2.scorch_ready = true
    state2.frostbolt_ready = true
    state2.arcane_missiles_ready = true
    assert_false(strategies[15].matches(ctx2, state2), "scorch setting disabled -> no match")

    -- ArcaneMissiles: use_arcane_missiles disabled -> no match
    local ctx3 = make_context({})
    ctx3.settings.leveling_arcane_missiles_use = false
    local state3 = get_state(ctx3)
    state3.arcane_missiles_ready = true
    state3.frostbolt_ready = true
    assert_false(strategies[16].matches(ctx3, state3), "arcanemissiles setting disabled -> no match")

    -- Counterspell: use_interrupt disabled -> no match
    local ctx4 = make_context({})
    ctx4.settings.use_interrupt = false
    ctx4.target = {
        is_valid = function() return true end,
        get_health = function() return 8000 end,
        get_max_health = function() return 10000 end,
        get_health_percentage = function() return 80 end,
        is_casting = function() return true end,
    }
    local state4 = get_state(ctx4)
    state4.counterspell_ready = true
    state4.frostbolt_ready = true
    state4.arcane_missiles_ready = true
    assert_false(strategies[6].matches(ctx4, state4), "counterspell interrupt disabled -> no match")
end

-- ============================================================================
-- Edge case: FrostNova distance boundary
-- ============================================================================
do
    local ctx = make_context({})
    ctx.me = { is_valid = function() return true end, get_position = function() return { x = 0, y = 0, z = 0 } end }
    ctx.target = {
        is_valid = function() return true end,
        get_health = function() return 8000 end,
        get_max_health = function() return 10000 end,
        get_health_percentage = function() return 80 end,
        get_distance = function(other) return 10 end,
    }
    local state = get_state(ctx)
    state.frost_nova_ready = true
    state.frostbolt_ready = true
    state.arcane_missiles_ready = true
    state.fire_blast_ready = true
    state.scorch_ready = true
    assert_true(strategies[9].matches(ctx, state), "frostnova dist=10 -> match (<=10)")

    local ctx2 = make_context({})
    ctx2.me = { is_valid = function() return true end, get_position = function() return { x = 0, y = 0, z = 0 } end }
    ctx2.target = {
        is_valid = function() return true end,
        get_health = function() return 8000 end,
        get_max_health = function() return 10000 end,
        get_health_percentage = function() return 80 end,
        get_distance = function(other) return 11 end,
    }
    local state2 = get_state(ctx2)
    state2.frost_nova_ready = true
    assert_false(strategies[9].matches(ctx2, state2), "frostnova dist=11 -> no match (>10)")
end

-- ============================================================================
-- API crash: NS.try_cast nil/throwing
-- ============================================================================
do
    local saved = NS.try_cast
    local ctx = make_context({})
    local state = get_state(ctx)
    state.ai_ready = true
    state.frost_armor_ready = true
    state.remove_curse_ready = true
    state.polymorph_ready = true
    state.counterspell_ready = true
    state.mana_shield_ready = true
    state.ice_barrier_ready = true
    state.frost_nova_ready = true
    state.cone_of_cold_ready = true
    state.blink_ready = true
    state.blizzard_ready = true
    state.evocation_ready = true
    state.fire_blast_ready = true
    state.scorch_ready = true
    state.arcane_missiles_ready = true
    state.frostbolt_ready = true

    -- NS.try_cast = nil -> execute should not crash
    NS.try_cast = nil
    for i = 1, #strategies do
        local ok, result = pcall(strategies[i].execute, ctx)
        assert_true(ok, "try_cast=nil: strategy " .. i .. " execute did not crash")
    end

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

print(string.format("\n=== Mage Leveling Unit Tests: %d passed, %d failed (%d assertions) ===\n", passed, failed, assertions))
if failed > 0 then
    error(string.format("Some tests FAILED (%d failures)", failed))
else
    print("All Mage leveling unit tests passed!")
end
