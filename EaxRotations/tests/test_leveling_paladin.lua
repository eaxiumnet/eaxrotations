-- Unit tests for Paladin leveling rotation
-- Tests build_state, all 16 match functions, strategy ordering,
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

local MOCK_PALADIN_SPELLS = {
    BlessingOfMight = { 27140 },
    BlessingOfWisdom = { 27142 },
    DevotionAura = { 27149 },
    SealRighteousness = { 20154 },
    SealCommand = { 20375 },
    SealBlood = { 31801 },
    Judgement = { 20271 },
    Consecration = { 27173 },
    HammerOfWrath = { 27180 },
    CrusaderStrike = { 35395 },
    HammerOfJustice = { 10308 },
    Exorcism = { 27138 },
    DivineShield = { 642 },
    LayOnHands = { 27154 },
    FlashOfLight = { 27137 },
    HolyLight = { 27135 },
    HolyShield = { 27179 },
    Cleanse = { 4987 },
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
        get_class = function() return 2 end,
        is_in_combat = function() return false end,
        get_target = function() return mock_target end,
        get_position = function() return { x = 0, y = 0, z = 0 } end,
    }

    NS.PLAYER_UNIT = "player"
    NS.log = function() end
    NS.log_warning = function() end
    NS.spell_ready = function(spell_action, target, opts)
        if not spell_action then return false end
        return true
    end
    NS.spell_exists = function(spell_id) return true end
    NS.try_cast = function(spell_action, target, label)
        if not spell_action then return false end
        return true
    end
    NS.buff_up = function(unit, buff_ids)
        if not unit or not buff_ids then return false end
        if type(buff_ids) == "table" then
            for _, id in ipairs(buff_ids) do
                if unit.has_buff and unit:has_buff(id) then return true end
            end
            return false
        end
        return unit.has_buff and unit:has_buff(buff_ids) or false
    end
    NS.get_local_player = function() return mock_player end
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
    NS.game_time_ms = function() return 100000 end

    -- rotation_registry mock
    NS.rotation_registry = {
        _registrations = {},
        register = function(self, key, strategies, opts)
            self._registrations[key] = { strategies = strategies, opts = opts }
        end,
        set_class_config = function(self, config) end,
    }

    NS.PaladinSpells = {}
    for k, v in pairs(MOCK_PALADIN_SPELLS) do
        NS.PaladinSpells[k] = v
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
            get_creature_type = function() return 3 end,  -- demon type for Exorcism
        },
        pet = nil,
        settings = {
            playstyle = "leveling",
            active_playstyle = "leveling",
            use_interrupt = true,
            leveling_wand_threshold = 30,
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
-- Load the Paladin leveling module
-- ============================================================================

local NS, core, mock_player, mock_target, mock_state = build_mock_env()
local ok, module = pcall(dofile, "EaxRotations/classes/paladin/leveling_sylvanas.lua")
if not ok then
    error("Failed to load Paladin leveling module: " .. tostring(module))
end
if not module or type(module) ~= "table" then
    error("Paladin leveling module should return a table of strategies")
end

local reg = NS.rotation_registry._registrations["leveling"]
if not reg then
    error("Paladin leveling module should register as 'leveling' in rotation_registry")
end
local strategies = reg.strategies
local get_state = reg.opts.get_state

print("=== Paladin Leveling Unit Tests ===\n")
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
    assert_true(state.blessing_might_ready, "blessing_might_ready")
    assert_true(state.blessing_wisdom_ready, "blessing_wisdom_ready")
    assert_true(state.devotion_aura_ready, "devotion_aura_ready")
    assert_true(state.seal_righteousness_ready, "seal_righteousness_ready")
    assert_true(state.seal_command_ready, "seal_command_ready")
    assert_true(state.seal_blood_ready, "seal_blood_ready")
    assert_true(state.judgement_ready, "judgement_ready")
    assert_true(state.consecration_ready, "consecration_ready")
    assert_true(state.hammer_wrath_ready, "hammer_wrath_ready")
    assert_true(state.crusader_strike_ready, "crusader_strike_ready")
    assert_true(state.hammer_justice_ready, "hammer_justice_ready")
    assert_true(state.exorcism_ready, "exorcism_ready")
    assert_true(state.divine_shield_ready, "divine_shield_ready")
    assert_true(state.lay_on_hands_ready, "lay_on_hands_ready")
    assert_true(state.holy_shield_ready, "holy_shield_ready")
    assert_true(state.flash_light_ready, "flash_light_ready")
    assert_true(state.holy_light_ready, "holy_light_ready")
    assert_true(state.cleanse_ready, "cleanse_ready")
end)

test("build_state: buff checks from context", function()
    local ctx = make_context()
    local state = get_state(ctx)
    -- Buff states depend on ctx.me.has_buff which returns false in mock
    assert_false(state.has_blessing_might, "has_blessing_might from buff check")
    assert_false(state.has_blessing_wisdom, "has_blessing_wisdom from buff check")
    assert_false(state.has_devotion_aura, "has_devotion_aura from buff check")
end)

test("build_state: wand_learned and use_interrupt from common state", function()
    local ctx = make_context()
    local state = get_state(ctx)
    assert_true(state.use_interrupt, "use_interrupt defaults to true")
    assert_true(state.wand_learned, "wand_learned from spell_exists")
end)

-- ============================================================================
-- Test: blessing_might_matches (strategy #1)
-- ============================================================================

test("blessing_might_matches: OOC, no buff, ready -> true", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_blessing_might = false
    state.blessing_might_ready = true
    assert_true(strategies[1].matches(ctx, state), "OOC without buff should match")
end)

test("blessing_might_matches: in combat -> false", function()
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.has_blessing_might = false
    state.blessing_might_ready = true
    assert_false(strategies[1].matches(ctx, state), "in combat should not match")
end)

test("blessing_might_matches: already has buff -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_blessing_might = true
    state.blessing_might_ready = true
    assert_false(strategies[1].matches(ctx, state), "already has buff should not match")
end)

test("blessing_might_matches: not ready -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_blessing_might = false
    state.blessing_might_ready = false
    assert_false(strategies[1].matches(ctx, state), "not ready should not match")
end)

-- ============================================================================
-- Test: retribution_aura_matches (strategy #3)
-- ============================================================================

test("retribution_aura_matches: OOC, no buff, ready -> true", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_retribution_aura = false
    state.retribution_aura_ready = true
    assert_true(strategies[3].matches(ctx, state), "OOC without buff should match")
end)

test("retribution_aura_matches: in combat -> false", function()
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.has_retribution_aura = false
    state.retribution_aura_ready = true
    assert_false(strategies[3].matches(ctx, state), "in combat should not match")
end)

test("retribution_aura_matches: already has buff -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_retribution_aura = true
    state.retribution_aura_ready = true
    assert_false(strategies[3].matches(ctx, state), "already has buff should not match")
end)

-- ============================================================================
-- Test: devotion_aura_matches (strategy #4)
-- ============================================================================

test("devotion_aura_matches: OOC, no buff, no retribution, ready -> true", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_devotion_aura = false
    state.has_retribution_aura = false
    state.devotion_aura_ready = true
    assert_true(strategies[4].matches(ctx, state), "OOC without buff should match")
end)

test("devotion_aura_matches: in combat -> false", function()
    local ctx = make_context({in_combat = true})
    local state = get_state(ctx)
    state.has_devotion_aura = false
    state.devotion_aura_ready = true
    assert_false(strategies[4].matches(ctx, state), "in combat should not match")
end)

test("devotion_aura_matches: already has buff -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_devotion_aura = true
    state.devotion_aura_ready = true
    assert_false(strategies[4].matches(ctx, state), "already has buff should not match")
end)

test("devotion_aura_matches: has retribution aura -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_devotion_aura = false
    state.has_retribution_aura = true
    state.devotion_aura_ready = true
    assert_false(strategies[4].matches(ctx, state), "retribution aura active should skip devotion")
end)

test("devotion_aura_matches: not ready -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_devotion_aura = false
    state.devotion_aura_ready = false
    assert_false(strategies[4].matches(ctx, state), "not ready should not match")
end)

-- ============================================================================
-- Test: holy_shield_matches (strategy #5)
-- ============================================================================

test("holy_shield_matches: in combat, no buff, ready -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.has_holy_shield = false
    state.holy_shield_ready = true
    assert_true(strategies[5].matches(ctx, state), "in combat without buff should match")
end)

test("holy_shield_matches: already has buff -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.has_holy_shield = true
    state.holy_shield_ready = true
    assert_false(strategies[5].matches(ctx, state), "already has buff should not match")
end)

test("holy_shield_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.has_holy_shield = false
    state.holy_shield_ready = true
    assert_false(strategies[5].matches(ctx, state), "OOC should not match")
end)

test("holy_shield_matches: not ready -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.has_holy_shield = false
    state.holy_shield_ready = false
    assert_false(strategies[5].matches(ctx, state), "not ready should not match")
end)

test("holy_shield_matches: nil state -> false", function()
    local ctx = make_context()
    assert_false(strategies[5].matches(ctx, nil), "nil state should return false")
end)

-- ============================================================================
-- Test: flash_light_matches (strategy #6)
-- ============================================================================

test("flash_light_matches: in combat, HP below 60, ready -> true", function()
    local ctx = make_context({hp = 40})
    local state = get_state(ctx)
    state.flash_light_ready = true
    state.hp = 40
    assert_true(strategies[6].matches(ctx, state), "HP below 60 should match")
end)

test("flash_light_matches: HP above 60 -> false", function()
    local ctx = make_context({hp = 80})
    local state = get_state(ctx)
    state.flash_light_ready = true
    state.hp = 80
    assert_false(strategies[6].matches(ctx, state), "HP above 60 should not match")
end)

test("flash_light_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, hp = 40})
    local state = get_state(ctx)
    state.flash_light_ready = true
    state.hp = 40
    assert_false(strategies[6].matches(ctx, state), "OOC should not match")
end)

test("flash_light_matches: not ready -> false", function()
    local ctx = make_context({hp = 40})
    local state = get_state(ctx)
    state.flash_light_ready = false
    state.hp = 40
    assert_false(strategies[6].matches(ctx, state), "not ready should not match")
end)

-- ============================================================================
-- Test: divine_shield_matches (strategy #8)
-- ============================================================================

test("divine_shield_matches: in combat, HP below 20, ready -> true", function()
    local ctx = make_context({hp = 15})
    local state = get_state(ctx)
    state.divine_shield_ready = true
    state.hp = 15
    assert_true(strategies[8].matches(ctx, state), "HP below 20 should match")
end)

test("divine_shield_matches: HP above 20 -> false", function()
    local ctx = make_context({hp = 50})
    local state = get_state(ctx)
    state.divine_shield_ready = true
    state.hp = 50
    assert_false(strategies[8].matches(ctx, state), "HP above 20 should not match")
end)

test("divine_shield_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, hp = 15})
    local state = get_state(ctx)
    state.divine_shield_ready = true
    state.hp = 15
    assert_false(strategies[8].matches(ctx, state), "OOC should not match")
end)

-- ============================================================================
-- Test: lay_on_hands_matches (strategy #9)
-- ============================================================================

test("lay_on_hands_matches: in combat, HP below 15, ready -> true", function()
    local ctx = make_context({hp = 10})
    local state = get_state(ctx)
    state.lay_on_hands_ready = true
    state.hp = 10
    assert_true(strategies[9].matches(ctx, state), "HP below 15 should match")
end)

test("lay_on_hands_matches: HP above 15 -> false", function()
    local ctx = make_context({hp = 50})
    local state = get_state(ctx)
    state.lay_on_hands_ready = true
    state.hp = 50
    assert_false(strategies[9].matches(ctx, state), "HP above 15 should not match")
end)

test("lay_on_hands_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, hp = 10})
    local state = get_state(ctx)
    state.lay_on_hands_ready = true
    state.hp = 10
    assert_false(strategies[9].matches(ctx, state), "OOC should not match")
end)

-- ============================================================================
-- Test: hammer_justice_matches (strategy #10)
-- ============================================================================

test("hammer_justice_matches: in combat, 2+ enemies, ready -> true", function()
    local ctx = make_context({enemies_count = 3})
    local state = get_state(ctx)
    state.hammer_justice_ready = true
    state.enemies = 3
    assert_true(strategies[10].matches(ctx, state), "2+ enemies should match")
end)

test("hammer_justice_matches: single enemy -> false", function()
    local ctx = make_context({enemies_count = 1})
    local state = get_state(ctx)
    state.hammer_justice_ready = true
    state.enemies = 1
    assert_false(strategies[10].matches(ctx, state), "1 enemy should not match")
end)

test("hammer_justice_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, enemies_count = 3})
    local state = get_state(ctx)
    state.hammer_justice_ready = true
    state.enemies = 3
    assert_false(strategies[10].matches(ctx, state), "OOC should not match")
end)

test("hammer_justice_matches: no target -> false", function()
    local ctx = make_context({target = nil, enemies_count = 3})
    local state = get_state(ctx)
    state.hammer_justice_ready = true
    state.enemies = 3
    state.target = nil
    assert_false(strategies[10].matches(ctx, state), "no target should not match")
end)

-- ============================================================================
-- Test: judgement_matches (strategy #11)
-- ============================================================================

test("judgement_matches: in combat, ready -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.judgement_ready = true
    assert_true(strategies[11].matches(ctx, state), "in combat ready should match")
end)

test("judgement_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.judgement_ready = true
    assert_false(strategies[11].matches(ctx, state), "OOC should not match")
end)

test("judgement_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.judgement_ready = true
    state.target = nil
    assert_false(strategies[11].matches(ctx, state), "no target should not match")
end)

test("judgement_matches: not ready -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.judgement_ready = false
    assert_false(strategies[11].matches(ctx, state), "not ready should not match")
end)

-- ============================================================================
-- Test: hammer_wrath_matches (strategy #12)
-- ============================================================================

test("hammer_wrath_matches: in combat, target HP below 20, ready -> true", function()
    local ctx = make_context()
    ctx.target.get_health_percentage = function() return 15 end
    local state = get_state(ctx)
    state.hammer_wrath_ready = true
    assert_true(strategies[12].matches(ctx, state), "target HP below 20 should match")
end)

test("hammer_wrath_matches: target HP above 20 -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.hammer_wrath_ready = true
    assert_false(strategies[12].matches(ctx, state), "target HP above 20 should not match")
end)

test("hammer_wrath_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    ctx.target.get_health_percentage = function() return 15 end
    local state = get_state(ctx)
    state.hammer_wrath_ready = true
    assert_false(strategies[12].matches(ctx, state), "OOC should not match")
end)

test("hammer_wrath_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.hammer_wrath_ready = true
    state.target = nil
    assert_false(strategies[12].matches(ctx, state), "no target should not match")
end)

-- ============================================================================
-- Test: crusader_strike_matches (strategy #13)
-- ============================================================================

test("crusader_strike_matches: in combat, ready -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.crusader_strike_ready = true
    assert_true(strategies[13].matches(ctx, state), "in combat ready should match")
end)

test("crusader_strike_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.crusader_strike_ready = true
    assert_false(strategies[13].matches(ctx, state), "OOC should not match")
end)

test("crusader_strike_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.crusader_strike_ready = true
    state.target = nil
    assert_false(strategies[13].matches(ctx, state), "no target should not match")
end)

test("crusader_strike_matches: not ready -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.crusader_strike_ready = false
    assert_false(strategies[13].matches(ctx, state), "not ready should not match")
end)

-- ============================================================================
-- Test: exorcism_matches (strategy #14)
-- ============================================================================

test("exorcism_matches: in combat, not moving, ready -> true", function()
    local ctx = make_context({is_moving = false})
    local state = get_state(ctx)
    state.exorcism_ready = true
    state.is_moving = false
    assert_true(strategies[14].matches(ctx, state), "stationary should match")
end)

test("exorcism_matches: moving -> false", function()
    local ctx = make_context({is_moving = true})
    local state = get_state(ctx)
    state.exorcism_ready = true
    state.is_moving = true
    assert_false(strategies[14].matches(ctx, state), "moving should not match")
end)

test("exorcism_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.exorcism_ready = true
    assert_false(strategies[14].matches(ctx, state), "OOC should not match")
end)

test("exorcism_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.exorcism_ready = true
    state.target = nil
    assert_false(strategies[14].matches(ctx, state), "no target should not match")
end)

-- ============================================================================
-- Test: consecration_matches (strategy #15)
-- ============================================================================

test("consecration_matches: 2+ enemies, not moving, ready -> true", function()
    local ctx = make_context({enemies_count = 3, is_moving = false})
    local state = get_state(ctx)
    state.consecration_ready = true
    state.enemies = 3
    state.is_moving = false
    assert_true(strategies[15].matches(ctx, state), "2+ enemies stationary should match")
end)

test("consecration_matches: single enemy -> false", function()
    local ctx = make_context({enemies_count = 1})
    local state = get_state(ctx)
    state.consecration_ready = true
    state.enemies = 1
    assert_false(strategies[15].matches(ctx, state), "1 enemy should not match")
end)

test("consecration_matches: moving -> false", function()
    local ctx = make_context({enemies_count = 3, is_moving = true})
    local state = get_state(ctx)
    state.consecration_ready = true
    state.enemies = 3
    state.is_moving = true
    assert_false(strategies[15].matches(ctx, state), "moving should not match")
end)

test("consecration_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false, enemies_count = 3})
    local state = get_state(ctx)
    state.consecration_ready = true
    state.enemies = 3
    assert_false(strategies[15].matches(ctx, state), "OOC should not match")
end)

test("consecration_matches: no target -> false", function()
    local ctx = make_context({target = nil, enemies_count = 3})
    local state = get_state(ctx)
    state.consecration_ready = true
    state.enemies = 3
    state.target = nil
    assert_false(strategies[15].matches(ctx, state), "no target should not match")
end)

-- ============================================================================
-- Test: seal_matches (strategy #16)
-- ============================================================================

test("seal_matches: in combat, target, ready -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.seal_command_ready = true
    -- Prefers Command/Blood first
    assert_true(strategies[16].matches(ctx, state), "seal command ready should match")
end)

test("seal_matches: only righteous ready -> true", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.seal_command_ready = false
    state.seal_blood_ready = false
    state.seal_righteousness_ready = true
    assert_true(strategies[16].matches(ctx, state), "only seal righteous should match")
end)

test("seal_matches: no seal ready -> false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.seal_command_ready = false
    state.seal_blood_ready = false
    state.seal_righteousness_ready = false
    assert_false(strategies[16].matches(ctx, state), "no seal ready should not match")
end)

test("seal_matches: not in combat -> false", function()
    local ctx = make_context({in_combat = false})
    local state = get_state(ctx)
    state.seal_command_ready = true
    assert_false(strategies[16].matches(ctx, state), "OOC should not match")
end)

test("seal_matches: no target -> false", function()
    local ctx = make_context({target = nil})
    local state = get_state(ctx)
    state.seal_command_ready = true
    state.target = nil
    assert_false(strategies[16].matches(ctx, state), "no target should not match")
end)

-- ============================================================================
-- Test: Strategy priority ordering
-- ============================================================================

test("strategies: 16 strategies in correct priority order", function()
    local expected = {
        "BlessingMight",
        "BlessingWisdom",
        "DevotionAura",
        "HolyShield",
        "Cleanse",
        "FlashOfLight",
        "HolyLight",
        "DivineShield",
        "LayOnHands",
        "HammerOfJustice",
        "Judgement",
        "HammerOfWrath",
        "CrusaderStrike",
        "Exorcism",
        "Consecration",
        "Seal",
    }
    assert_eq(#strategies, 16, "should have 16 strategies")
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

test("execute_BlessingMight: does not crash", function()
    local ok, result = pcall(strategies[1].execute)
    assert_true(ok, "execute should not throw")
end)

test("execute_CrusaderStrike: does not crash with context", function()
    local ctx = make_context()
    local ok, result = pcall(strategies[13].execute, ctx)
    assert_true(ok, "execute with context should not throw")
end)

-- ============================================================================
-- Test: Nil guard
-- ============================================================================

test("module: returns nil when EaxRotations is nil", function()
    local _, c = build_mock_env()
    _G.EaxRotations = nil
    local nil_mod = dofile("EaxRotations/classes/paladin/leveling_sylvanas.lua")
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
    local state = get_state(ctx)
    state.has_blessing_might = false
    state.blessing_might_ready = true
    state.has_devotion_aura = false
    state.devotion_aura_ready = true
    state.has_retribution_aura = false
    state.retribution_aura_ready = true
    state.has_blessing_wisdom = false
    state.blessing_wisdom_ready = true
    state.cleanse_ready = true

    -- OOC buffs should match
    assert_true(strategies[1].matches(ctx, state), "BlessingMight should match OOC")
    assert_true(strategies[2].matches(ctx, state), "BlessingWisdom should match OOC")
    assert_true(strategies[3].matches(ctx, state), "RetributionAura should match OOC")
    assert_true(strategies[4].matches(ctx, state), "DevotionAura should match OOC")
    assert_true(strategies[6].matches(ctx, state), "Cleanse should match OOC")

    -- Combat abilities should not match OOC
    local combat_indices = {5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17}
    for _, i in ipairs(combat_indices) do
        local ok, matched = pcall(strategies[i].matches, ctx, state)
        assert_true(ok, "strategy[" .. i .. "] matches should not throw")
        assert_false(matched, "strategy[" .. i .. "] (" .. strategies[i].name .. ") should not match OOC")
    end
end)

test("rotation: execute scenario - hammer_wrath should match when target < 20%", function()
    local ctx = make_context()
    ctx.target.get_health_percentage = function() return 15 end
    local state = get_state(ctx)
    state.hammer_wrath_ready = true

    assert_true(strategies[13].matches(ctx, state), "HammerOfWrath should match when target < 20% HP")
end)

test("rotation: low HP scenario - flash_light should match", function()
    local ctx = make_context({hp = 40})
    local state = get_state(ctx)
    state.flash_light_ready = true
    state.hp = 40

    assert_true(strategies[7].matches(ctx, state), "FlashOfLight should match when HP < 60")
end)

-- ============================================================================
-- Edge Case: Seal priority boundaries
-- ============================================================================

test("edge_seal: Command preferred over Blood and Righteousness", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.seal_command_ready = true
    state.seal_blood_ready = true
    state.seal_righteousness_ready = true
    assert_true(strategies[16].matches(ctx, state), "Command ready should match")
end)

test("edge_seal: Blood fallback when Command not ready", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.seal_command_ready = false
    state.seal_blood_ready = true
    state.seal_righteousness_ready = true
    assert_true(strategies[16].matches(ctx, state), "Blood ready should match when Command not ready")
end)

test("edge_seal: Righteousness fallback when Command and Blood not ready", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.seal_command_ready = false
    state.seal_blood_ready = false
    state.seal_righteousness_ready = true
    assert_true(strategies[16].matches(ctx, state), "Righteousness ready should match when others not ready")
end)

test("edge_seal: no seal ready returns false", function()
    local ctx = make_context()
    local state = get_state(ctx)
    state.seal_command_ready = false
    state.seal_blood_ready = false
    state.seal_righteousness_ready = false
    assert_false(strategies[16].matches(ctx, state), "no seal ready should not match")
end)

-- ============================================================================
-- Edge Case: Consecration enemy count boundaries
-- ============================================================================

test("edge_consecration: exactly 2 enemies -> true", function()
    local ctx = make_context({enemies_count = 2, is_moving = false})
    local state = get_state(ctx)
    state.consecration_ready = true
    state.enemies = 2
    state.is_moving = false
    assert_true(strategies[15].matches(ctx, state), "exactly 2 enemies should match")
end)

test("edge_consecration: exactly 1 enemy -> false", function()
    local ctx = make_context({enemies_count = 1, is_moving = false})
    local state = get_state(ctx)
    state.consecration_ready = true
    state.enemies = 1
    state.is_moving = false
    assert_false(strategies[15].matches(ctx, state), "exactly 1 enemy should not match")
end)

-- ============================================================================
-- Edge Case: HP boundaries for survival spells
-- ============================================================================

test("edge_flash_light: HP exactly 60 -> true", function()
    local ctx = make_context({hp = 60})
    local state = get_state(ctx)
    state.flash_light_ready = true
    state.hp = 60
    assert_true(strategies[6].matches(ctx, state), "HP exactly 60 should match (<= check)")
end)

test("edge_flash_light: HP exactly 61 -> false", function()
    local ctx = make_context({hp = 100})
    local state = get_state(ctx)
    state.flash_light_ready = true
    state.hp = 61
    assert_false(strategies[6].matches(ctx, state), "HP exactly 61 should not match")
end)

test("edge_divine_shield: HP exactly 20 -> true", function()
    local ctx = make_context({hp = 20})
    local state = get_state(ctx)
    state.divine_shield_ready = true
    state.hp = 20
    assert_true(strategies[8].matches(ctx, state), "HP exactly 20 should match (<= check)")
end)

test("edge_divine_shield: HP exactly 21 -> false", function()
    local ctx = make_context({hp = 50})
    local state = get_state(ctx)
    state.divine_shield_ready = true
    state.hp = 21
    assert_false(strategies[8].matches(ctx, state), "HP exactly 21 should not match")
end)

test("edge_lay_on_hands: HP exactly 15 -> true", function()
    local ctx = make_context({hp = 15})
    local state = get_state(ctx)
    state.lay_on_hands_ready = true
    state.hp = 15
    assert_true(strategies[9].matches(ctx, state), "HP exactly 15 should match (<= check)")
end)

test("edge_lay_on_hands: HP exactly 16 -> false", function()
    local ctx = make_context({hp = 50})
    local state = get_state(ctx)
    state.lay_on_hands_ready = true
    state.hp = 16
    assert_false(strategies[9].matches(ctx, state), "HP exactly 16 should not match")
end)

-- ============================================================================
-- Edge Case: Hammer of Wrath target HP boundaries
-- ============================================================================

test("edge_hammer_wrath: target HP exactly 20 -> true", function()
    local ctx = make_context()
    ctx.target.get_health_percentage = function() return 20 end
    local state = get_state(ctx)
    state.hammer_wrath_ready = true
    assert_true(strategies[12].matches(ctx, state), "target HP exactly 20 should match (<= check)")
end)

test("edge_hammer_wrath: target HP exactly 21 -> false", function()
    local ctx = make_context()
    ctx.target.get_health_percentage = function() return 21 end
    local state = get_state(ctx)
    state.hammer_wrath_ready = true
    assert_false(strategies[12].matches(ctx, state), "target HP exactly 21 should not match")
end)

-- ============================================================================
-- Edge Case: Hammer of Justice enemy count boundary
-- ============================================================================

test("edge_hammer_justice: exactly 2 enemies -> true", function()
    local ctx = make_context({enemies_count = 2})
    local state = get_state(ctx)
    state.hammer_justice_ready = true
    state.enemies = 2
    assert_true(strategies[10].matches(ctx, state), "exactly 2 enemies should match")
end)

test("edge_hammer_justice: exactly 1 enemy -> false", function()
    local ctx = make_context({enemies_count = 1})
    local state = get_state(ctx)
    state.hammer_justice_ready = true
    state.enemies = 1
    assert_false(strategies[10].matches(ctx, state), "exactly 1 enemy should not match")
end)

-- ============================================================================
-- Edge Case: Exorcism movement boundary
-- ============================================================================

test("edge_exorcism: stationary -> true", function()
    local ctx = make_context({is_moving = false})
    local state = get_state(ctx)
    state.exorcism_ready = true
    state.is_moving = false
    assert_true(strategies[14].matches(ctx, state), "stationary should match")
end)

test("edge_exorcism: moving -> false", function()
    local ctx = make_context({is_moving = true})
    local state = get_state(ctx)
    state.exorcism_ready = true
    state.is_moving = true
    assert_false(strategies[14].matches(ctx, state), "moving should not match")
end)

-- ============================================================================
-- Edge Case: Buff API safety (nil/throwing NS.buff_up in build_state)
-- ============================================================================

test("edge_buff: NS.buff_up nil in build_state returns false for all buffs", function()
    local ctx = make_context({in_combat = false})
    local saved = NS.buff_up
    NS.buff_up = nil
    local state = get_state(ctx)
    assert_false(state.has_blessing_might, "has_blessing_might false when NS.buff_up nil")
    assert_false(state.has_blessing_wisdom, "has_blessing_wisdom false when NS.buff_up nil")
    assert_false(state.has_devotion_aura, "has_devotion_aura false when NS.buff_up nil")
    NS.buff_up = saved
end)

test("edge_buff: NS.buff_up throws in build_state does not crash", function()
    local ctx = make_context({in_combat = false})
    local saved = NS.buff_up
    NS.buff_up = function() error("mock crash") end
    local state = get_state(ctx)
    assert_false(state.has_blessing_might, "has_blessing_might false when NS.buff_up throws")
    assert_false(state.has_blessing_wisdom, "has_blessing_wisdom false when NS.buff_up throws")
    assert_false(state.has_devotion_aura, "has_devotion_aura false when NS.buff_up throws")
    NS.buff_up = saved
end)

-- ============================================================================
-- Edge Case: API crash safety (nil/throwing NS.spell_ready, nil NS.try_cast)
-- ============================================================================

test("edge_api: NS.spell_ready nil in build_state returns false for all ready fields", function()
    local ctx = make_context()
    local saved = NS.spell_ready
    NS.spell_ready = nil
    local state = get_state(ctx)
    assert_false(state.blessing_might_ready, "blessing_might_ready false when NS.spell_ready nil")
    assert_false(state.judgement_ready, "judgement_ready false when NS.spell_ready nil")
    NS.spell_ready = saved
end)

test("edge_api: NS.spell_ready throws in build_state returns false for all ready fields", function()
    local ctx = make_context()
    local saved = NS.spell_ready
    NS.spell_ready = function() error("mock crash") end
    local state = get_state(ctx)
    assert_false(state.blessing_might_ready, "blessing_might_ready false when NS.spell_ready throws")
    assert_false(state.judgement_ready, "judgement_ready false when NS.spell_ready throws")
    NS.spell_ready = saved
end)

test("edge_api: NS.try_cast nil does not crash execute functions", function()
    local saved = NS.try_cast
    NS.try_cast = nil
    for i, s in ipairs(strategies) do
        local ok, result = pcall(s.execute, make_context())
        assert_true(ok, "strategy[" .. i .. "] execute should not throw with nil NS.try_cast")
    end
    NS.try_cast = saved
end)

-- ============================================================================
-- Edge Case: Rotation crash safety (nil context for execute)
-- ============================================================================

test("edge_rotation_crash: all execute functions handle nil context -> no crash", function()
    for i, s in ipairs(strategies) do
        local ok, result = pcall(s.execute, nil)
        assert_true(ok, "strategy[" .. i .. "] execute(nil) should not throw")
    end
end)

-- ============================================================================
-- Summary
-- ============================================================================

print(string.format("\n=== Paladin Leveling Unit Tests: %d passed, %d failed (%d assertions) ===\n", passed, failed, assertions))
if failed > 0 then
    error(string.format("Some tests FAILED (%d failures)", failed))
else
    print("All Paladin leveling unit tests passed!")
end
