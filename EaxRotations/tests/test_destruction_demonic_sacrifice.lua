-- test_destruction_demonic_sacrifice.lua -- Destruction Demonic Sacrifice sacrifice logic tests.
-- WHAT:  Destruction Demonic Sacrifice sacrifice logic tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- unit tests for destruction_sylvanas Demonic Sacrifice summon loop fix.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Mock NS namespace with Demonic Sacrifice aura tracking
local _ds_aura_active = false
local captured_get_state
_G.EaxRotations = {
    WarlockSpells = {
        ShadowBolt = 27209,
        Immolate = 27215,
        Corruption = 27216,
        CurseOfAgony = 27218,
        CurseOfDoom = 27218,
        Conflagrate = 30912,
        SoulFire = 30545,
        Shadowburn = 30546,
        Incinerate = 32231,
        SearingPain = 30459,
        SeedOfCorruption = 27243,
        RainOfFire = 5740,
        Hellfire = 1949,
        DrainLife = 27220,
        LifeTap = 27222,
        DarkPact = 27265,
        Fear = 6215,
        DeathCoil = 6789,
        CreateHealthstone = 6201,
        FelArmor = 28189,
        DemonArmor = 11735,
        ShadowWard = 28610,
        SummonImp = 688,
        SummonVoidwalker = 697,
        SummonSuccubus = 712,
        SummonFelhunter = 691,
        SummonFelguard = 30146,
        FelDomination = 18708,
        Soulshatter = 29858,
    },
    PLAYER_UNIT = {},
    spell_ready = function(spell, target, opts) return true end,
    is_spell_learned = function(id) return true end,
    has_player_buff = function(buff_list)
        if _ds_aura_active then return true end
        return false
    end,
    get_spell_cooldown = function(spell) return 0 end,
    should_use_long_cd = function() return false end,
    broken_api_throttled = function(spell, seconds) return false end,
    should_refresh_dot = function(remains, pandemic, ttd, duration) return remains <= pandemic end,
    is_execute_phase = function(target_hp, threshold) return true end,
    has_item = function(id) return true end,
    unit_alive = function(unit) return true end,
    unit_health_pct = function(unit) return 100 end,
    GetPet = function() return nil end,
    get_spell_id = function(spell) return type(spell) == "number" and spell or 0 end,
    try_cast = function(spell, target, label, opts) return true end,
    try_cast_position = function(spell, pos, target, label, opts) return true end,
    log = function() end,
    spell_action = function(def, label)
        if type(def) == "table" then return def[1] or 1 end
        return def
    end,
    rotation_registry = {
        register = function(self, spec, strats, opts)
            captured_get_state = opts and opts.get_state
        end
    },
    buff_up = function(unit, ids)
        if _ds_aura_active then
            for _, id in ipairs(ids) do
                if id == 18789 or id == 18790 or id == 18791 or id == 18792 or id == 35701 then
                    return true
                end
            end
        end
        return false
    end,
    debuff_remains = function(unit, ids) return 0 end,
    GetPlayer = function() return {} end,
    GetEnemiesInRange = function() return {} end,
}

local result = dofile("EaxRotations/classes/warlock/destruction_sylvanas.lua")
assert_true(result, "destruction module should load")
local strategies = result.strategies or result
assert_true(strategies, "strategies table should load")
assert_true(#strategies > 0, "should have at least one strategy")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then
            return strategies[i]
        end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- DemonicSacrifice_Imp strategy should exist
-- ============================================================================

local ds = find_strategy("DemonicSacrifice")
assert_true(ds.matches, "DemonicSacrifice should have a matches function")
assert_true(ds.execute, "DemonicSacrifice should have an execute function")

-- ============================================================================
-- Summon loop fix: do NOT re-summon when DS aura is active
-- ============================================================================

local summon_imp = find_strategy("SummonImp")
assert_true(summon_imp.matches, "SummonImp should have a matches function")

-- Mock context with no pet, no enemy, OOC
-- Note: destro_pet_preference = "imp" selects Imp (fire build)
local mock_context_no_pet = {
    in_combat = false,
    has_valid_enemy_target = false,
    me = {},
    target = nil,
    settings = { destro_pet_preference = "imp" },
}

-- Without DS aura: should want to summon
local mock_state_no_ds = { has_demonic_sacrifice = false }
local should_summon = summon_imp.matches(mock_context_no_pet, mock_state_no_ds)
assert_true(should_summon, "SummonImp should fire when no pet, no DS aura, OOC")

-- Mock context with Succubus preference (shadow build)
local mock_context_sacc = {
    in_combat = false,
    has_valid_enemy_target = false,
    me = {},
    target = nil,
    settings = { destro_pet_preference = "succubus" },
}
local should_not_summon_imp = summon_imp.matches(mock_context_sacc, mock_state_no_ds)
assert_false(should_not_summon_imp, "SummonImp should NOT fire when preference is Succubus (shadow build)")

local summon_succubus = find_strategy("SummonSuccubus")
local should_summon_succubus = summon_succubus.matches(mock_context_sacc, mock_state_no_ds)
assert_true(should_summon_succubus, "SummonSuccubus should fire when preference is Succubus (shadow build)")

-- With DS aura active: should NOT re-summon (this is the bug fix)
_ds_aura_active = true
local mock_state_with_ds = { has_demonic_sacrifice = true }
local should_not_summon = summon_imp.matches(mock_context_no_pet, mock_state_with_ds)
assert_false(should_not_summon, "SummonImp should NOT fire when DS aura is active (bug fix)")
_ds_aura_active = false

-- ============================================================================
-- DemonicSacrifice should fire when pet exists and no DS aura
-- ============================================================================

_G.EaxRotations.GetPet = function() return { is_valid = function() return true end } end
_G.EaxRotations.unit_alive = function() return true end

local ds_context = {
    in_combat = false,
    has_valid_enemy_target = false,
    me = {},
    target = nil,
}
local ds_state = { has_demonic_sacrifice = false }
local ds_should_fire = ds.matches(ds_context, ds_state)
assert_true(ds_should_fire, "DemonicSacrifice should fire when pet alive, no DS aura, OOC")

-- With DS aura already active: should NOT fire again
_ds_aura_active = true
ds_state = { has_demonic_sacrifice = true }
local ds_should_not_fire = ds.matches(ds_context, ds_state)
assert_false(ds_should_not_fire, "DemonicSacrifice should NOT fire when DS aura already active")
_ds_aura_active = false

-- ============================================================================
-- DemonicSacrifice should NOT fire when no pet exists
-- ============================================================================

_G.EaxRotations.GetPet = function() return nil end
local ds_no_pet = ds.matches(ds_context, { has_demonic_sacrifice = false })
assert_false(ds_no_pet, "DemonicSacrifice should NOT fire when no pet exists")

-- ============================================================================
-- build_state integration: has_demonic_sacrifice reflects aura via buff_up
-- ============================================================================

-- Load module fresh to capture get_state via registry mock
local result2 = dofile("EaxRotations/classes/warlock/destruction_sylvanas.lua")
local build_state = captured_get_state
assert_true(build_state ~= nil, "build_state should be captured from registry")
if build_state then
    _ds_aura_active = true
    local ctx = { target = nil, hp = 100, mana_pct = 100, spell_damage = 500 }
    local st = build_state(ctx)
    assert_true(st.has_demonic_sacrifice, "build_state should set has_demonic_sacrifice=true when DS aura active")
    _ds_aura_active = false
    local st2 = build_state(ctx)
    assert_false(st2.has_demonic_sacrifice, "build_state should set has_demonic_sacrifice=false when no DS aura")
end

print("[PASS] test_destruction_demonic_sacrifice")
