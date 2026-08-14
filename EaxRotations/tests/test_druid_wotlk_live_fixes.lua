-- test_druid_wotlk_live_fixes.lua — Druid WotLK W3.3 live-fix regression tests.
-- WHAT:  pins the 2026-08-13 Wave 3.3 fixes: bear/cat/balance/resto/leveling
--        resource reads now use REAL engine surface (context fields /
--        me:get_power / NS.mana_pct — the mock-only me:get_rage() /
--        me:get_energy() / me:get_combo_points() / me:get_mana_percentage()
--        members are NOT defined on the mock, so any regression fails loudly),
--        balance Starfall ST + Eclipse switching, bear Mangle refresh gate +
--        FrenziedRegeneration, cat SavageRoar 5-CP + FB dump + TigersFury /
--        Berserk / ShredOmen, resto injured-ally WildGrowth + Lifebloom
--        mana/stacks + friendly targeting + Nourish/Innervate, leveling
--        InsectSwarm/FaerieFire refresh gates + Rip 5-CP.
-- WHEN:  standalone: lua EaxRotations/tests/test_druid_wotlk_live_fixes.lua
--        (registered by the W3.5 integration wave, not by run_rotation_tests).
-- WHY:   each fix must fail loudly if a future edit regresses it.
-- SAFETY: Pure unit tests with mocked _G.EaxRotations; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

-- Deterministic module stubs (mirrors test_druid_vanilla_live_fixes).
package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }

-- Real spec_kit + strategy_dsl (both nil-tolerant under a mock NS) so the
-- compiled DSL strategies behave exactly like in production.
package.loaded["shared/spec_kit_sylvanas"] = nil
package.loaded["shared/strategy_dsl_sylvanas"] = nil

-- Mock surface: ONLY real engine members. Deliberately NO
-- get_rage/get_energy/get_combo_points/get_mana_percentage on units — the
-- W3.1 audit proved those are mock-only, and any regression back to them
-- fails here with a nil-read instead of silently passing.
local function make_action(ids, label)
    local id = type(ids) == "table" and ids[1] or ids
    return {
        id = id,
        name = label or tostring(id),
        cast_safe = function(self, target) return true end,
        cooldown_remaining = function(self) return 0 end,
        can_cast = function(self, target) return true end,
        is_learned = function(self) return true end,
    }
end

local me_unit = {
    get_health_percentage = function(self) return 80 end,
    get_power = function(self, p) return 100 end,
}
local target_unit = {
    get_health_percentage = function(self) return 80 end,
    get_creature_type = function(self) return 7 end,
}
local friend_unit = { get_health_percentage = function(self) return 60 end }

local casts = {}
_G.EaxRotations = {
    DruidSpells = {
        MangleBear = make_action(33987, "MangleBear"),
        Lacerate = make_action(33745, "Lacerate"),
        SwipeBear = make_action(26997, "SwipeBear"),
        Maul = make_action(26996, "Maul"),
        FaerieFireFeral = make_action(27011, "FeralFaerieFire"),
        FrenziedRegeneration = make_action(26999, "FrenziedRegeneration"),
        FaerieFireFeralCat = make_action(27011, "FaerieFireFeral"),
        Ravage = make_action(27005, "Ravage"),
        MangleCat = make_action(33983, "MangleCat"),
        Rake = make_action(27003, "Rake"),
        Rip = make_action(27008, "Rip"),
        SavageRoar = make_action(52610, "SavageRoar"),
        FerociousBite = make_action(24248, "FerociousBite"),
        Shred = make_action(27002, "Shred"),
        TigersFury = make_action(5217, "TigersFury"),
        Berserk = make_action(50334, "Berserk"),
        MoonkinForm = make_action(24858, "MoonkinForm"),
        InsectSwarm = make_action(27013, "InsectSwarm"),
        Moonfire = make_action(26988, "Moonfire"),
        Starfall = make_action(48505, "Starfall"),
        Wrath = make_action(26985, "Wrath"),
        Starfire = make_action(26986, "Starfire"),
        Rejuvenation = make_action(774, "Rejuvenation"),
        WildGrowth = make_action(48438, "WildGrowth"),
        Regrowth = make_action(8936, "Regrowth"),
        Swiftmend = make_action(18562, "Swiftmend"),
        Lifebloom = make_action(33763, "Lifebloom"),
        Nourish = make_action(50464, "Nourish"),
        Innervate = make_action(29166, "Innervate"),
    },
    GetPlayer = function() return me_unit end,
    me = me_unit,
    POWER_MANA = 0,
    POWER_RAGE = 1,
    POWER_ENERGY = 3,
    POWER_COMBO = 4,
    spell_action = make_action,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    try_cast = function(spell, unit, reason, opts) casts[#casts + 1] = reason; return true end,
    buff_up = function(unit, ids) return false end,
    buff_remains = function(unit, ids) return 0 end,
    buff_stacks = function(unit, ids) return 0 end,
    debuff_up = function(unit, ids) return false end,
    debuff_remains = function(unit, ids) return 0 end,
    cooldown_remains = function() return 0 end,
    mana_pct = function(unit) return 42 end,
    is_behind_target = function(target) return true end,
    should_use_long_cd = function(ctx, cd) return true end,
    gate_overheal = function() return false end,
    has_form = function(name) return false end,
    is_item_ready = function() return false end,
    use_item_by_id = function() return true end,
    time_now = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    rotation_registry = { register = function() end },
}

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name, 2)
end

-- ============================================================================
-- 1. bear_wotlk: rage from context.rage (mock-only me:get_rage removed)
-- ============================================================================
local bear = dofile("EaxRotations/classes/druid/bear_wotlk.lua")
local bear_state = bear.build_state({ in_combat = true, target = target_unit, rage = 55 })
assert_true(bear_state.rage == 55, "bear build_state must read context.rage (got " .. tostring(bear_state.rage) .. ")")
local bear_norage = bear.build_state({ in_combat = true, target = target_unit })
assert_true(bear_norage.rage == 100, "bear rage fallback must be me:get_power(POWER_RAGE) (got " .. tostring(bear_norage.rage) .. ")")
assert_true(bear_norage.rage ~= nil, "bear rage must never be nil")
print("PASS: bear rage via context.rage / me:get_power (mock-only get_rage gone)")

-- ============================================================================
-- 2. bear_wotlk: Mangle refresh gate + FrenziedRegeneration panic lane
-- ============================================================================
local mangle_lane = find_strategy(bear.strategies, "MangleBear")
local mangle_ctx = { in_combat = true, target = target_unit, settings = {}, rage = 50 }
local m_state = bear.build_state(mangle_ctx)
m_state.mangle_remains = 1
assert_true(mangle_lane.matches(mangle_ctx, m_state), "MangleBear must fire when the Mangle debuff is expiring")
m_state.mangle_remains = 20
assert_false(mangle_lane.matches(mangle_ctx, m_state), "MangleBear must NOT fire when the Mangle debuff is fresh (refresh gate)")
local fr_lane = find_strategy(bear.strategies, "FrenziedRegeneration")
local fr_ctx = { in_combat = true, target = target_unit, settings = {}, rage = 30, hp = 35 }
local fr_state = bear.build_state(fr_ctx)
assert_true(fr_lane.matches(fr_ctx, fr_state), "FrenziedRegeneration must fire at hp <= 40 with rage >= 10")
local fr_healthy_ctx = { in_combat = true, target = target_unit, settings = {}, rage = 30, hp = 90 }
local fr_healthy = bear.build_state(fr_healthy_ctx)
assert_false(fr_lane.matches(fr_healthy_ctx, fr_healthy), "FrenziedRegeneration must not fire at full hp")
print("PASS: bear Mangle debuff refresh gate + FrenziedRegeneration lane")

-- ============================================================================
-- 3. cat_wotlk: energy/combo from context (mock-only reads removed)
-- ============================================================================
local cat = dofile("EaxRotations/classes/druid/cat_wotlk.lua")
local cat_state = cat.build_state({ in_combat = true, target = target_unit, energy = 45, combo_points = 3 })
assert_true(cat_state.energy == 45, "cat build_state must read context.energy (got " .. tostring(cat_state.energy) .. ")")
assert_true(cat_state.combo_points == 3, "cat build_state must read context.combo_points (got " .. tostring(cat_state.combo_points) .. ")")
print("PASS: cat energy/combo via context fields (mock-only get_energy/get_combo_points gone)")

-- ============================================================================
-- 4. cat_wotlk: SavageRoar 5-CP spend + FerociousBite 5-CP dump
-- ============================================================================
local sr_lane = find_strategy(cat.strategies, "SavageRoar")
local cat_ctx = { in_combat = true, target = target_unit, settings = {} }
local sr_state = cat.build_state(cat_ctx)
sr_state.savage_roar_remains = 1
sr_state.combo_points = 5
assert_true(sr_lane.matches(cat_ctx, sr_state), "SavageRoar must fire at 5 CP when the buff would drop")
sr_state.combo_points = 1
assert_false(sr_lane.matches(cat_ctx, sr_state), "SavageRoar must NOT fire at 1 CP (was 8s-SR spam)")
local fb_lane = find_strategy(cat.strategies, "FerociousBite")
local fb_state = cat.build_state(cat_ctx)
fb_state.combo_points = 5
fb_state.target_hp = 50
fb_state.rip_remains = 5
fb_state.savage_roar_remains = 5
assert_true(fb_lane.matches(cat_ctx, fb_state), "FerociousBite must dump 5 CP above execute when Rip+SR healthy")
fb_state.rip_remains = 1
assert_false(fb_lane.matches(cat_ctx, fb_state), "FerociousBite must NOT dump when Rip needs the CP")
print("PASS: cat SavageRoar 5-CP gate + FerociousBite healthy-window dump")

-- ============================================================================
-- 5. cat_wotlk: TigersFury / Berserk / ShredOmen lanes fire (real spell_ready)
-- ============================================================================
local tf_lane = find_strategy(cat.strategies, "TigersFury")
local tf_state = cat.build_state(cat_ctx)
tf_state.energy = 30
tf_state.combo_points = 0
assert_true(tf_lane.matches(cat_ctx, tf_state), "TigersFury must fire at low energy off CD")
tf_state.energy = 80
assert_false(tf_lane.matches(cat_ctx, tf_state), "TigersFury must not fire near the energy cap")
local berserk_lane = find_strategy(cat.strategies, "Berserk")
local b_state = cat.build_state(cat_ctx)
b_state.combo_points = 2
assert_true(berserk_lane.matches(cat_ctx, b_state), "Berserk must fire in combat below 5 CP")
local omen_lane = find_strategy(cat.strategies, "ShredOmen")
local o_state = cat.build_state(cat_ctx)
o_state.clearcasting = true
o_state.is_behind = true
o_state.combo_points = 2
o_state.energy = 30
assert_true(omen_lane.matches(cat_ctx, o_state), "ShredOmen must fire on Omen of Clarity behind")
print("PASS: cat TigersFury/Berserk/ShredOmen lanes (real spell_ready gates)")

-- ============================================================================
-- 6. balance_wotlk: mana from context + Starfall ST + Eclipse switching
-- ============================================================================
local balance = dofile("EaxRotations/classes/druid/balance_wotlk.lua")
local bal_state = balance.build_state({ in_combat = true, target = target_unit, mana_pct = 60 })
assert_true(bal_state.mana_pct == 60, "balance build_state must read context.mana_pct (got " .. tostring(bal_state.mana_pct) .. ")")
local starfall_lane = find_strategy(balance.strategies, "Starfall")
local bal_ctx = { in_combat = true, target = target_unit, settings = {} }
local sf_state = balance.build_state(bal_ctx)
sf_state.enemy_count = 1
assert_true(starfall_lane.matches(bal_ctx, sf_state), "Starfall must fire on a SINGLE target (enemy_count gate removed)")
local wrath_lane = find_strategy(balance.strategies, "Wrath")
local starfire_lane = find_strategy(balance.strategies, "Starfire")
local e_state = balance.build_state(bal_ctx)
e_state.eclipse_solar = true
e_state.mana_pct = 80
assert_true(wrath_lane.matches(bal_ctx, e_state), "Wrath must fire during solar eclipse")
assert_false(starfire_lane.matches(bal_ctx, e_state), "Starfire must NOT fire during solar eclipse")
e_state.eclipse_solar = false
assert_true(starfire_lane.matches(bal_ctx, e_state), "Starfire must fire outside solar eclipse")
print("PASS: balance mana via context + Starfall ST + Eclipse spell-switching")

-- ============================================================================
-- 7. resto_wotlk: mana via context, WildGrowth injured-ally gate, Lifebloom
--    mana/stacks, friendly (lowest) targeting, Nourish + Innervate
-- ============================================================================
local resto = dofile("EaxRotations/classes/druid/resto_wotlk.lua")
local resto_ctx = { in_combat = true, target = target_unit, settings = {}, mana_pct = 70,
                    lowest = { unit = friend_unit, hp = 55 }, party_injured_count = 3 }
local r_state = resto.build_state(resto_ctx)
assert_true(r_state.mana_pct == 70, "resto build_state must read context.mana_pct (got " .. tostring(r_state.mana_pct) .. ")")
assert_true(r_state.lowest_hp_pct == 55, "resto must track the lowest ally hp (got " .. tostring(r_state.lowest_hp_pct) .. ")")
assert_true(r_state.party_injured_count == 3, "resto must track the engine party_injured_count")
local wg_lane = find_strategy(resto.strategies, "WildGrowth")
assert_true(wg_lane.matches(resto_ctx, r_state), "WildGrowth must fire with 3 injured allies")
local wg_single = resto.build_state({ in_combat = true, target = target_unit, settings = {}, mana_pct = 70, party_injured_count = 1 })
assert_false(wg_lane.matches(resto_ctx, wg_single), "WildGrowth must NOT fire with a single injured ally (was enemy_count gate)")
local lb_lane = find_strategy(resto.strategies, "Lifebloom")
local lb_state = resto.build_state({ in_combat = true, target = target_unit, settings = {}, mana_pct = 60, lowest = { unit = friend_unit, hp = 55 } })
lb_state.lifebloom_remains = 2
lb_state.lifebloom_stacks = 0
assert_true(lb_lane.matches(resto_ctx, lb_state), "Lifebloom must roll up stacks when expiring")
lb_state.lifebloom_stacks = 3
assert_false(lb_lane.matches(resto_ctx, lb_state), "Lifebloom must NOT clip at 3 stacks with 2s remaining (3-stack awareness)")
local lb_lowmana = resto.build_state({ in_combat = true, target = target_unit, settings = {}, mana_pct = 20, lowest = { unit = friend_unit, hp = 55 } })
lb_lowmana.lifebloom_remains = 2
assert_false(lb_lane.matches(resto_ctx, lb_lowmana), "Lifebloom must not cast below the mana floor")
local nourish_lane = find_strategy(resto.strategies, "Nourish")
assert_true(nourish_lane.matches(resto_ctx, r_state), "Nourish must fire on a hurt lowest ally")
local innervate_lane = find_strategy(resto.strategies, "Innervate")
local inv_state = resto.build_state({ in_combat = true, target = target_unit, settings = {}, mana_pct = 25 })
assert_true(innervate_lane.matches(resto_ctx, inv_state), "Innervate must fire at low mana")
print("PASS: resto mana via context + WildGrowth injured gate + Lifebloom mana/stacks + Nourish/Innervate")

-- ============================================================================
-- 8. leveling_wotlk: mana via context, InsectSwarm/FaerieFire refresh gates,
--    Rip 5-CP spend
-- ============================================================================
local leveling = dofile("EaxRotations/classes/druid/leveling_wotlk.lua")
local lvl_state = leveling.build_state({ in_combat = true, target = target_unit, mana_pct = 50, form = "caster" })
assert_true(lvl_state.mana_pct == 50, "leveling build_state must read context.mana_pct (got " .. tostring(lvl_state.mana_pct) .. ")")
local is_lane = find_strategy(leveling.strategies, "InsectSwarm")
local lvl_ctx = { in_combat = true, target = target_unit, settings = {}, form = "caster", mana_pct = 50 }
local is_state = leveling.build_state(lvl_ctx)
is_state.insect_swarm_remains = 1
assert_true(is_lane.matches(lvl_ctx, is_state), "InsectSwarm must fire when the debuff expires")
is_state.insect_swarm_remains = 20
assert_false(is_lane.matches(lvl_ctx, is_state), "InsectSwarm must NOT re-cast every GCD (refresh gate)")
local ff_lane = find_strategy(leveling.strategies, "FaerieFire")
local ff_state = leveling.build_state(lvl_ctx)
ff_state.faerie_fire_remains = 1
assert_true(ff_lane.matches(lvl_ctx, ff_state), "FaerieFire must fire when the debuff expires")
ff_state.faerie_fire_remains = 20
assert_false(ff_lane.matches(lvl_ctx, ff_state), "FaerieFire must NOT re-cast every GCD (refresh gate)")
local rip_lane = find_strategy(leveling.strategies, "Rip")
local rip_state = leveling.build_state({ in_combat = true, target = target_unit, settings = {}, form = "cat", combo_points = 4 })
rip_state.rip_remains = 0
assert_false(rip_lane.matches(lvl_ctx, rip_state), "Rip must NOT fire at 4 CP (5-CP spend)")
rip_state.combo_points = 5
assert_true(rip_lane.matches(lvl_ctx, rip_state), "Rip must fire at 5 CP")
print("PASS: leveling mana via context + IS/FF refresh gates + Rip 5-CP spend")

print("PASS test_druid_wotlk_live_fixes")
