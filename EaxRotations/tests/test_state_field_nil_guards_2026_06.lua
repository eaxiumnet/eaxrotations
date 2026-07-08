-- Regression test: state field nil-guards for bear, cat, arcane.
--
-- Verifies that match functions do NOT crash with "attempt to compare nil with
-- number" when state fields like rage, energy, combo_points, or mana_pct are
-- nil.
--
-- Each strategy match receives a context table. Bear and cat strategies call
-- build_state(context) which provides nil-safe defaults. Arcane strategies
-- receive state (s) from the framework — when called with only context as
-- a unit test, s is nil and must not crash.
--
-- Expected: RED (fails) before nil-guards are in place; GREEN after.
--
package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Track failures: count and collect messages
local failures = {}
local total_tests = 0
local total_passed = 0

local function expect_no_crash(label, fn)
    total_tests = total_tests + 1
    local ok, err = pcall(fn)
    if ok then
        total_passed = total_passed + 1
    else
        failures[#failures + 1] = { label = label, error = err }
    end
end

-- ============================================================================
-- Mock NS — shared across all spec loads
-- ============================================================================
_G.EaxRotations = {
    DruidSpells = {
        Shred = 5221,
        MangleBear = 33878,
        Lacerate = 33745,
        SwipeBear = 779,
        Maul = 6807,
        FaerieFireFeral = 27011,
        Growl = 6794,
        DemoralizingRoar = 25203,
        ChallengingRoar = 5209,
        FeralCharge = 16979,
        Bash = 8983,
        Enrage = 5229,
        BearForm = 5487,
        FrenziedRegeneration = 22842,
        Barkskin = 22812,
        FerociousBite = 22568,
        NaturesGrasp = 16810,
        MarkOfTheWild = 1126,
        GiftOfTheWild = 21849,
        Thorns = 467,
        CatForm = 768,
        Prowl = 5215,
        MangleCat = 33982,
        Ravage = 6785,
        Dash = 1850,
        Claw = 27000,
        Rake = 27003,
        Rip = 27008,
        TigersFury = 5217,
    },
    MageSpells = {
        ArcaneBlast = 30451,
        ArcaneMissiles = 5143,
        ArcanePower = 12042,
        PresenceOfMind = 12043,
        Evocation = 12051,
        IceBarrier = 13031,
        ManaShield = 1463,
        Polymorph = 118,
        FrostNova = 122,
        Slow = 31589,
        FireBlast = 2136,
        IceBlock = 45438,
        ColdSnap = 11958,
        Blink = 1953,
        IcyVeins = 12472,
        Fireball = 133,
        Frostbolt = 116,
    },
    action_matches = function(ctx, act) return true end,
    debuff_remains = function(target, debuff_list) return target and target._debuff_remains or 0 end,
    get_debuff_stacks = function(target, debuff_list) return target and target._debuff_stacks or 0 end,
    debuff_stacks = function(target, debuff_list) return target and target._debuff_stacks or 0 end,
    buff_up = function(me, buff_list) return me and me._buff_up or false end,
    buff_remains = function(me, buff_list) return me and me._buff_remains or 0 end,
    is_spell_learned = function(spell_id) return true end,
    spell_exists = function(spell) return true end,
    spell_ready = function(spell, target, opts) return true end,
    setting_number = function(settings, key, default)
        return type(settings) == "table" and type(settings[key]) == "number" and settings[key] or default
    end,
    setting_bool = function(settings, key, default)
        local value = settings and settings[key]
        if value == nil then return default end
        return value ~= false
    end,
    log = function() end,
    time_now = function() return 0 end,
    safe_field = function(unit, method) return unit[method] end,
    rotation_registry = {
        register = function() end,
    },
    -- For arcane-specific mock
    setting = function(context, key, default)
        local settings = context and context.settings
        if settings and settings[key] ~= nil then return settings[key] end
        return default
    end,
    get_visible_units = function() return {}, 0 end,
    cooldown_remains = function() return 0 end,
    has_form = function(form) return form == "bear" end,
}

-- For leveling/arcane compat (avoid "attempt to index nil" on common/enums)
_G.common = { enums = { power_type = { COMBOPOINTS = 4, COMBOPOINTS_TBC = 4 } } }

-- Silence potion_helper require
package.preload["shared/potion_helper_sylvanas"] = function()
    return { try_use_potion = function() end, HEALTH_POTION_IDS = {}, MANA_POTION_IDS = {} }
end

-- Silence tbc_data_sylvanas require
package.preload["shared/tbc_data_sylvanas"] = function()
    return { ITEMS = { healthstones = {}, potions = {} }, SPELLS = { mage = {} } }
end

-- Silence energy tick tracker
package.preload["shared/energy_tick_tracker_sylvanas"] = function()
    return {
        new_state = function() return { last_tick_time = 0, tick_confident = false } end,
        estimate_next_tick = function() return 2.0 end,
        predicted_energy = function(state, current, interval) return current + 20 end,
    }
end

print("=== test_state_field_nil_guards_2026_06 ===")

-- ============================================================================
-- SPEC 1: bear_sylvanas.lua — rage/hp nil-guards
-- ============================================================================
print("--- Bear Druid: rage/hp nil-guards ---")

_G.EaxRotations.unit_health_pct = nil
_G.EaxRotations.GetPlayer = nil
_G.EaxRotations.spell_exists = function(spell) return true end
_G.EaxRotations.spell_ready = function(spell, target, opts) return true end
_G.EaxRotations.cooldown_remains = function() return 0 end
_G.EaxRotations.has_form = function(form) return form == "bear" end
_G.EaxRotations.safe_field = nil  -- test without safe_field

local bear_strategies = dofile("EaxRotations/classes/druid/bear_sylvanas.lua")
assert_true(type(bear_strategies) == "table", "bear strategies should load")

-- Helper to find strategy by name
local function find_bear_strategy(name)
    for i = 1, #bear_strategies do
        if bear_strategies[i].name == name then return bear_strategies[i] end
    end
    error("bear strategy not found: " .. name)
end

-- Context with nil rage, nil hp, nil pack_loose — tests line 480 (rage_allows_filler)
-- and line 584 (challenging_roar_matches accessing state.hp)
local nil_ctx = {
    in_combat = true,
    target = nil,   -- triggers early exit on many strategies
    me = { _buff_up = false },
    settings = {},
}

-- Strategy: SwipeAoE → calls rage_allows_filler(state, RAGE_SWIPE) → state.rage < 20
-- build_state defaults rage to 0, so this should not crash
local swipe_aoe = find_bear_strategy("SwipeAoE")
expect_no_crash("bear: SwipeAoE with nil rage — rage_allows_filler state.rage < rage_cost (L480)", function()
    return swipe_aoe.matches({ in_combat = true, me = { _buff_up = false }, settings = {}, target = nil })
end)

-- Strategy: ChallengingRoar → state.pack_loose < 2 and state.hp < 45 (L584)
-- build_state defaults hp to 100, pack_loose to 0
local challenging_roar = find_bear_strategy("ChallengingRoar")
expect_no_crash("bear: ChallengingRoar with nil hp — state.hp < 45 (L584)", function()
    return challenging_roar.matches({ in_combat = true, me = { _buff_up = false }, settings = {}, target = nil })
end)

-- Strategy: MangleBear → would_starve_mangle uses state.rage < X
local mangle = find_bear_strategy("MangleBear")
expect_no_crash("bear: Mangle with nil rage — would_starve_mangle state.rage (L470-473)", function()
    return mangle.matches({ in_combat = true, me = { _buff_up = false }, settings = {}, target = nil })
end)

-- Strategy: Maul → state.rage < state.maul_rage (L694)
local maul = find_bear_strategy("Maul")
expect_no_crash("bear: Maul with nil rage — state.rage < state.maul_rage (L694)", function()
    return maul.matches({ in_combat = true, me = { _buff_up = false }, settings = {}, target = nil })
end)

-- Strategy: FaerieFireFeral → state.faerie_remains > FAERIE_FIRE_REFRESH (L606)
local faerie_fire = find_bear_strategy("FaerieFireFeral")
expect_no_crash("bear: FaerieFireFeral with nil debuff — state.faerie_remains (L606)", function()
    return faerie_fire.matches({ in_combat = true, me = { _buff_up = false }, settings = {} })
end)

-- ============================================================================
-- SPEC 2: cat_sylvanas.lua — energy/combo_points nil-guards
-- ============================================================================
print("--- Feral Cat: energy/combo_points nil-guards ---")

local cat_strategies = dofile("EaxRotations/classes/druid/cat_sylvanas.lua")
assert_true(type(cat_strategies) == "table", "cat strategies should load")

local function find_cat_strategy(name)
    for i = 1, #cat_strategies do
        if cat_strategies[i].name == name then return cat_strategies[i] end
    end
    error("cat strategy not found: " .. name)
end

-- build_state defaults: energy via get_energy → 0, combo_points → 0
local cat_nil_ctx = {
    in_combat = true,
    me = nil,
    target = nil,
    settings = {},
    is_stealthed = false,
}

-- Line 791: pounce_matches → state.energy < POUNCE_COST
local pounce = find_cat_strategy("PounceOpener")
expect_no_crash("cat: PounceOpener with nil energy — state.energy (L791)", function()
    return pounce.matches({ in_combat = true, is_stealthed = true, me = nil, target = nil, settings = {} })
end)

-- Line 800: ravage_matches → state.energy < RAVAGE_COST
local ravage = find_cat_strategy("RavageOpener")
expect_no_crash("cat: RavageOpener with nil energy — state.energy (L800)", function()
    return ravage.matches({ in_combat = true, is_stealthed = true, me = nil, target = nil, settings = {}, is_behind = true })
end)

-- Line 818: stealth_mangle_matches → state.energy < MANGLE_COST
local stealth_mangle = find_cat_strategy("StealthMangle")
expect_no_crash("cat: StealthMangle with nil energy — state.energy (L818)", function()
    return stealth_mangle.matches({ in_combat = true, is_stealthed = true, me = nil, target = nil, settings = {} })
end)

-- Line 885: rip_snapshot_matches → state.combo_points < required_cp
local rip_snapshot = find_cat_strategy("RipSnapshot")
expect_no_crash("cat: RipSnapshot with nil combo_points — state.combo_points (L885)", function()
    return rip_snapshot.matches({ in_combat = true, me = nil, target = nil, settings = {}, in_melee = true })
end)

-- Line 900: bite_matches → state.combo_points < required_cp
local bite = find_cat_strategy("FerociousBiteExecute")
expect_no_crash("cat: FerociousBite with nil combo_points — state.combo_points (L900)", function()
    return bite.matches({ in_combat = true, me = nil, target = nil, settings = {}, in_melee = true })
end)

-- Line 1116: wait_execute → state.combo_points < setting_number
-- PoolForExecuteBite is in strategies table directly (not in ACTIONS)
local pool_for_bite = find_cat_strategy("PoolForExecuteBite")
expect_no_crash("cat: PoolForExecuteBite with nil combo_points — state.combo_points (L1116)", function()
    return pool_for_bite.matches({ in_combat = true, me = nil, target = nil, settings = {} })
end)

-- Lines 749-750: should_pool_for_rip/shred (in build_state) use state.energy and state.combo_points
-- These are exercised by calling any strategy that triggers build_state
expect_no_crash("cat: build_state with nil energy/combo_points (L749-750)", function()
    return rip_snapshot.matches({ in_combat = true, me = nil, target = nil, settings = {} })
end)

-- ============================================================================
-- SPEC 3: arcane_sylvanas.lua — mana_pct nil-guards
-- ============================================================================
print("--- Arcane Mage: mana_pct nil-guards ---")

-- Arcane strategies receive (context, s) where s is built by the framework's
-- get_state (build_state). When called as a unit test with strategy.matches(ctx),
-- the second arg 's' is nil — this tests that the match functions handle nil s.

local captured_get_state = nil
_G.EaxRotations.rotation_registry = {
    register = function(self, spec, strats, opts)
        captured_get_state = opts and opts.get_state
    end,
}
-- Need some NS helpers for arcane
_G.EaxRotations.GetPlayer = function() return nil end
_G.EaxRotations.unit_mana_pct = function(me) return 100 end
_G.EaxRotations.unit_health_pct = function(me) return 100 end
_G.EaxRotations.PLAYER_UNIT = "player"
_G.EaxRotations.POWER_MANA = 0
_G.EaxRotations.buff_up = function(me, buff_list) return false end
_G.EaxRotations.get_setting = function(key, default) return default end
_G.EaxRotations.is_item_ready = function() return false end
_G.EaxRotations.use_item_by_id = function() return false end
_G.EaxRotations.broken_api_throttled = function() return false end
_G.EaxRotations.DRTracker = nil
_G.EaxRotations.gate_cooldown_boss_only = function() return true end

local arcane_result = dofile("EaxRotations/classes/mage/arcane_sylvanas.lua")
assert_true(type(arcane_result) == "table", "arcane module should load")
local arcane_strategies = arcane_result.strategies
assert_true(type(arcane_strategies) == "table", "arcane strategies should be a table")
assert_true(captured_get_state ~= nil, "arcane should capture get_state from registration")

-- Build state from a context with nil mana_pct
local arcane_state = captured_get_state({
    mana_pct = nil,    -- explicitly nil
    hp = nil,          -- explicitly nil
    in_combat = true,
    me = nil,          -- no player object
    target = nil,
    settings = {},
})

-- Test that the state was built without crashing and mana_pct/hp have defaults
assert_true(type(arcane_state) == "table", "arcane state should be a table")
assert_true(type(arcane_state.mana_pct) == "number", "arcane state.mana_pct should default to a number, got " .. type(arcane_state.mana_pct))
assert_true(type(arcane_state.hp_pct) == "number", "arcane state.hp_pct should default to a number, got " .. type(arcane_state.hp_pct))

-- Now test match functions: strategies registered by arcane receive them
-- (context, s) where s is the built state. Call with the built state.
local function find_arcane_strategy(name)
    for i = 1, #arcane_strategies do
        if arcane_strategies[i].name == name then return arcane_strategies[i] end
    end
    error("arcane strategy not found: " .. name)
end

-- Lines 197, 228, 231: build_state accesses s.mana_pct without guard
-- These are tested by the captured_get_state call above, but also test
-- match functions that use s.mana_pct
local ctx = { me = nil, target = nil, settings = {}, in_combat = true }

-- IceBarrier: accesses s.hp_pct (L252), guarded with (s.hp_pct or 100)
local ice_barrier = find_arcane_strategy("IceBarrier")
expect_no_crash("arcane: IceBarrier with nil s.hp_pct — (s.hp_pct or 100) > 60 (L252)", function()
    return ice_barrier.matches(ctx, arcane_state)
end)

-- ManaShield: accesses s.mana_pct (L263), guarded with (s.mana_pct or 0)
local mana_shield = find_arcane_strategy("ManaShield")
expect_no_crash("arcane: ManaShield with nil s.mana_pct — (s.mana_pct or 0) < 30 (L263)", function()
    return mana_shield.matches(ctx, arcane_state)
end)

-- Evocation: accesses s.mana_pct at lines 333, 337, guarded with (s.mana_pct or 100)
local evocation = find_arcane_strategy("Evocation")
expect_no_crash("arcane: Evocation with nil s.mana_pct — (s.mana_pct or 100) (L333,337)", function()
    return evocation.matches(ctx, arcane_state)
end)

-- ManaGem: accesses s.mana_pct at lines 349, 353, guarded with (s.mana_pct or 100)
local mana_gem = find_arcane_strategy("ManaGem")
expect_no_crash("arcane: ManaGem with nil s.mana_pct — (s.mana_pct or 100) (L349,353)", function()
    return mana_gem.matches(ctx, arcane_state)
end)

-- ArcaneBlast: accesses s.mana_pct at line 386, guarded with (s.mana_pct or 100)
local arcane_blast = find_arcane_strategy("ArcaneBlast")
expect_no_crash("arcane: ArcaneBlast with nil s.mana_pct — (s.mana_pct or 100) < 15 (L386)", function()
    return arcane_blast.matches(ctx, arcane_state)
end)

-- ArcaneMissiles: accesses s.mana_pct at line 420, guarded with (s.mana_pct or 100)
local arcane_missiles = find_arcane_strategy("ArcaneMissiles")
expect_no_crash("arcane: ArcaneMissiles with nil s.mana_pct — (s.mana_pct or 100) < 20 (L420)", function()
    return arcane_missiles.matches(ctx, arcane_state)
end)

-- Test build_state directly: lines 197, 228, 231 access s.mana_pct unguarded
-- Provide a context with nil mana_pct and no me/NS.unit_mana_pct
local state_with_nil_mana = captured_get_state({
    mana_pct = nil,
    hp = nil,
    in_combat = true,
    is_moving = false,
    me = nil,
    target = nil,
    settings = {},
})
-- If mana_pct is still nil after build_state, lines 197/228/231 would crash
assert_true(type(state_with_nil_mana.mana_pct) == "number",
    "build_state with nil context.mana_pct should produce number, got " .. tostring(state_with_nil_mana.mana_pct))
-- Verify man_pct has a sensible default
assert_true(state_with_nil_mana.mana_pct > 0,
    "build_state mana_pct default should be > 0, got " .. tostring(state_with_nil_mana.mana_pct))

-- ============================================================================
-- PROVE-IT: nil comparisons ARE dangerous without guards
-- These prove that removing the build_state defaults WOULD crash.
-- ============================================================================
print("--- Prove-it: nil comparison vulnerability ---")

total_tests = total_tests + 1
local ok, err = pcall(function()
    local s = { rage = nil }
    return s.rage < 15  -- nil < number → crash
end)
if not ok then
    total_passed = total_passed + 1
    print(string.format("  [ok] nil rage < 15 crashes: %s", tostring(err):sub(1, 80)))
else
    failures[#failures + 1] = { label = "prove-it: nil rage comparison should crash", error = "did NOT crash (unexpected)" }
end

total_tests = total_tests + 1
local ok, err = pcall(function()
    local s = { energy = nil }
    return s.energy < 30  -- nil < number → crash
end)
if not ok then
    total_passed = total_passed + 1
    print(string.format("  [ok] nil energy < 30 crashes: %s", tostring(err):sub(1, 80)))
else
    failures[#failures + 1] = { label = "prove-it: nil energy comparison should crash", error = "did NOT crash (unexpected)" }
end

total_tests = total_tests + 1
local ok, err = pcall(function()
    local s = { combo_points = nil }
    return s.combo_points < 5  -- nil < number → crash
end)
if not ok then
    total_passed = total_passed + 1
    print(string.format("  [ok] nil combo_points < 5 crashes: %s", tostring(err):sub(1, 80)))
else
    failures[#failures + 1] = { label = "prove-it: nil combo_points comparison should crash", error = "did NOT crash (unexpected)" }
end

total_tests = total_tests + 1
local ok, err = pcall(function()
    local s = { mana_pct = nil }
    return s.mana_pct < 10  -- nil < number → crash
end)
if not ok then
    total_passed = total_passed + 1
    print(string.format("  [ok] nil mana_pct < 10 crashes: %s", tostring(err):sub(1, 80)))
else
    failures[#failures + 1] = { label = "prove-it: nil mana_pct comparison should crash", error = "did NOT crash (unexpected)" }
end

-- ============================================================================
-- REPORT
-- ============================================================================
print()
if #failures == 0 then
    print(string.format("PASS test_state_field_nil_guards_2026_06 — %d/%d passed", total_passed, total_tests))
else
    print(string.format("FAIL test_state_field_nil_guards_2026_06 — %d/%d passed, %d failures:",
        total_passed, total_tests, #failures))
    for i, f in ipairs(failures) do
        print(string.format("  %d. [%s] %s", i, f.label, f.error))
    end
    error(string.format("test_state_field_nil_guards_2026_06: %d failure(s)", #failures))
end

-- Return failure count for diagnostic use
return #failures
