-- test_group_aware_utility_gates.lua — Regression tests for class group-aware utility toggles.
-- WHAT:  verifies that disabling <class>_group_aware_utility blocks group-only utility spells.
-- WHEN:  during rotation test suite execution.
-- WHY:   locks in the behavior of the newly exposed player toggles.
-- SAFETY: synthetic contexts; no live game data required.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

-- Lua 5.2+ compatibility: unpack moved to table.unpack
local unpack = table.unpack or unpack

local assert_true, assert_false

local function setup_asserts()
    assert_true = function(v, label)
        if not v then error(label or "assert_true failed", 2) end
    end
    assert_false = function(v, label)
        if v then error(label or "assert_false failed", 2) end
    end
end
setup_asserts()

-- -----------------------------------------------------------------------------
-- Minimal EaxRotations namespace mock.
-- Spec files load a handful of shared modules and define actions; we provide the
-- generic API surface they touch during the strategy matches we exercise.
-- -----------------------------------------------------------------------------
local ns = {
    -- Class spell tables must exist so spec_kit definitions don't crash.
    WarlockSpells = {},
    HunterSpells  = {},
    MageSpells    = {},
    RogueSpells   = {},
    PaladinSpells = {},
    DruidSpells   = {},
    PriestSpells  = {},
    ShamanSpells  = {},

    PLAYER_UNIT = {},

    spell_action = function(rank_ids, label)
        if type(rank_ids) == "table" then return (rank_ids[1] or label) end
        return rank_ids or label
    end,
    spell_ready   = function() return true end,
    try_cast      = function() return true end,
    is_spell_learned = function() return true end,
    get_spell_cooldown = function() return 0 end,
    has_player_buff = function() return false end,
    buff_remains  = function() return 0 end,
    debuff_remains = function() return 0 end,
    buff_up       = function() return false end,
    debuff_up     = function() return false end,
    has_debuff    = function() return false end,
    action_matches = function() return true end,
    aoe_self_meets = function() return true end,
    aoe_count_meets = function() return true end,
    broken_api_throttled = nil,  -- not loaded; nil is fine for the specs that guard it
    -- import_helpers is used by several specs (e.g., shaman healing) to pull helpers from core.
    import_helpers = function(...)
        local n = select("#", ...)
        local out = {}
        for i = 1, n do out[i] = function() return 0 end end
        return unpack(out)
    end,
    game_time_ms  = function() return 0 end,
    log           = function() end,
    -- Each call returns a new time so specs that cache state (e.g., druid balance
    -- innervate scan) actually re-run on successive build_state calls.
    time_now      = (function() local t = 1000 return function() t = t + 10; return t end end)(),
    rotation_registry = { register = function() end },
    -- Class-aware loading support for priest/shaman specs
    CLASS_ID = { PRIEST = 5, SHAMAN = 7, DRUID = 11 },
    current_class = nil,
    same_unit = function(a, b) return a == b end,
    is_tank_unit = function() return true end,
    GetPartyMembers = function() return {} end,
}
_G.EaxRotations = ns

ns.GetPlayer = function() return { get_class = function() return ns.current_class end } end

-- Ensure spec_kit loads for real; if any other shared module fails to load,
-- return a placeholder table so the spec file can still define its strategies.
-- Modules listed here are runtime-only shared helpers that are safe to stub
-- in a unit-test context.
local orig_require = _G.require
local stub_whitelist = {
    ["shared/stealth_helper_sylvanas"] = true,
    ["shared/offensive_dispel_sylvanas"] = true,
    ["shared/pet_manager_sylvanas"] = true,
    ["shared/aoe_hit_volume_sylvanas"] = true,
    ["shared/dot_ttd_gating_sylvanas"] = true,
    ["shared/buff_manager_helper_sylvanas"] = true,
    ["shared/profiler_helper_sylvanas"] = true,
    ["shared/ts_helper_sylvanas"] = true,
    ["shared/cooldown_planner_sylvanas"] = true,
    ["shared/potion_helper_sylvanas"] = true,
    ["shared/leveling_helpers_sylvanas"] = true,
    ["shared/hit_cap_tracker_sylvanas"] = true,
    ["shared/health_pred_helper_sylvanas"] = true,
    ["shared/fsr_manager_sylvanas"] = true,
    ["shared/preemptive_heal_sylvanas"] = true,
    ["shared/tbc_data_sylvanas"] = true,
    ["common/izi_sdk"] = true,
    ["common/modules/buff_manager"] = true,
    ["common/enums"] = true,
    ["classes/paladin/healing_sylvanas"] = true,
    ["classes/priest/healing_sylvanas"] = true,
    ["shared/strategy_dsl_sylvanas"] = true,
}
local function safe_require(name)
    if name == "shared/spec_kit_sylvanas" then
        return orig_require(name)
    end
    local ok, mod = pcall(orig_require, name)
    if ok and mod ~= nil then return mod end
    if not stub_whitelist[name] then
        error("required module failed to load and is not in test whitelist: " .. tostring(name), 2)
    end
    return {}
end
_G.require = safe_require

-- Pre-load a minimal common/enums so specs that require it get our class IDs.
package.loaded["common/enums"] = { class_id = ns.CLASS_ID }

local function load_spec(path, class_id)
    ns.current_class = class_id
    local ok, mod = pcall(dofile, "EaxRotations/classes/" .. path)
    if not ok then
        error("failed to load " .. path .. ": " .. tostring(mod), 2)
    end
    assert_true(mod and mod.strategies, path .. " should export strategies")
    return mod
end

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

-- Default group context with the requested toggle value.
local function ctx_group(toggle_key, toggle_val, extra)
    local c = {
        is_group = true,
        settings = { [toggle_key] = toggle_val },
    }
    if extra then
        for k, v in pairs(extra) do c[k] = v end
    end
    return c
end

local function run_tests()

-- ============================================================================
-- Warlock Affliction
-- ============================================================================
local affliction = load_spec("warlock/affliction_sylvanas.lua").strategies
local function warlock_ctx(toggle_val, extra)
    return ctx_group("warlock_group_aware_utility", toggle_val, extra)
end

local cc_fear = find_strategy(affliction, "CC_Fear")
local cc_howl = find_strategy(affliction, "CC_HowlOfTerror")
local cc_tongues = find_strategy(affliction, "PvP_CurseTongues")
local shadow_ward = find_strategy(affliction, "ShadowWard")

-- Toggle off -> blocked in group
assert_false(cc_fear.matches(warlock_ctx(false, { target = {} }), {}), "CC_Fear should be blocked with toggle off")
assert_false(cc_howl.matches(warlock_ctx(false, { melee_on_you = true }), {}), "CC_HowlOfTerror should be blocked with toggle off")
assert_false(cc_tongues.matches(warlock_ctx(false, { target = {}, enemy_caster = true }), {}), "PvP_CurseTongues should be blocked with toggle off")
assert_false(shadow_ward.matches(warlock_ctx(false, { enemy_shadow_caster = true }), {}), "ShadowWard should be blocked with toggle off")

-- Toggle on -> allowed in group
assert_true(cc_fear.matches(warlock_ctx(true, { target = {} }), {}), "CC_Fear should match with toggle on")
assert_true(cc_howl.matches(warlock_ctx(true, { melee_on_you = true }), {}), "CC_HowlOfTerror should match with toggle on")
assert_true(cc_tongues.matches(warlock_ctx(true, { target = {}, enemy_caster = true }), {}), "PvP_CurseTongues should match with toggle on")
assert_true(shadow_ward.matches(warlock_ctx(true, { in_combat = true, hp = 50, enemy_shadow_caster = true }), { shadow_ward_ready = true }), "ShadowWard should match with toggle on")

-- PvP bypasses the toggle entirely
assert_true(cc_fear.matches(warlock_ctx(false, { is_pvp = true, target = {} }), {}), "CC_Fear should match in PvP even with toggle off")

-- ============================================================================
-- Warlock Demonology
-- ============================================================================
local demonology = load_spec("warlock/demonology_sylvanas.lua").strategies
local demo_state = {
    fear_ready = true,
    pet_type_succubus = true,
    pet_alive = true,
    seduction_ready = true,
}
local demo_fear = find_strategy(demonology, "Fear")
local demo_seduction = find_strategy(demonology, "Seduction")

assert_false(demo_fear.matches(warlock_ctx(false, { in_combat = true, target = {} }), demo_state), "Demonology Fear should be blocked with toggle off")
assert_true(demo_fear.matches(warlock_ctx(true, { in_combat = true, target = {} }), demo_state), "Demonology Fear should match with toggle on")

assert_false(demo_seduction.matches(warlock_ctx(false, { in_combat = true, target = {} }), demo_state), "Seduction should be blocked with toggle off")
assert_true(demo_seduction.matches(warlock_ctx(true, { in_combat = true, target = {} }), demo_state), "Seduction should match with toggle on")

-- ============================================================================
-- Hunter Survival
-- ============================================================================
local survival = load_spec("hunter/survival_sylvanas.lua").strategies
local wyvern = find_strategy(survival, "WyvernSting")
local hunter_state = { wyvern_sting_ready = true, has_serpent_sting = false, has_scorpid_sting = false }
local function hunter_ctx(toggle_val, extra)
    return ctx_group("hunter_group_aware_utility", toggle_val, extra)
end

assert_false(wyvern.matches(hunter_ctx(false, { target = {} }), hunter_state), "WyvernSting should be blocked with toggle off")
assert_true(wyvern.matches(hunter_ctx(true, { target = {} }), hunter_state), "WyvernSting should match with toggle on")
assert_true(wyvern.matches(hunter_ctx(false, { is_pvp = true, target = {} }), hunter_state), "WyvernSting should match in PvP with toggle off")

-- ============================================================================
-- Mage Arcane / Frost / Fire (Polymorph)
-- ============================================================================
local function mage_ctx(toggle_val, extra)
    return ctx_group("mage_group_aware_utility", toggle_val, extra)
end
local mage_state = { polymorph_ready = true, is_moving = false }

local arcane = load_spec("mage/arcane_sylvanas.lua").strategies
local arc_poly = find_strategy(arcane, "Polymorph")
local arc_nova = find_strategy(arcane, "FrostNova")

assert_false(arc_poly.matches(mage_ctx(false, { cc_target = {} }), mage_state), "Arcane Polymorph should be blocked with toggle off")
assert_true(arc_poly.matches(mage_ctx(true, { cc_target = {} }), mage_state), "Arcane Polymorph should match with toggle on")
assert_true(arc_poly.matches(mage_ctx(false, { is_pvp = true, cc_target = {} }), mage_state), "Arcane Polymorph should match in PvP with toggle off")

local me_close = { get_distance = function() return 5 end }
assert_false(arc_nova.matches(mage_ctx(false, { target = {}, me = me_close }), {}), "Arcane FrostNova should be blocked with toggle off in group")
assert_true(arc_nova.matches(mage_ctx(true, { target = {}, me = me_close }), {}), "Arcane FrostNova should match with toggle on in group")

local frost = load_spec("mage/frost_sylvanas.lua").strategies
local frost_poly = find_strategy(frost, "Polymorph")
assert_false(frost_poly.matches(mage_ctx(false, { target = {}, cc_target = {} }), mage_state), "Frost Polymorph should be blocked with toggle off")
assert_true(frost_poly.matches(mage_ctx(true, { target = {}, cc_target = {} }), mage_state), "Frost Polymorph should match with toggle on")

local fire = load_spec("mage/fire_sylvanas.lua").strategies
local fire_poly = find_strategy(fire, "Polymorph")
assert_false(fire_poly.matches(mage_ctx(false, { cc_target = {} }), mage_state), "Fire Polymorph should be blocked with toggle off")
assert_true(fire_poly.matches(mage_ctx(true, { cc_target = {} }), mage_state), "Fire Polymorph should match with toggle on")

-- ============================================================================
-- Rogue Combat / Assassination
-- ============================================================================
local function rogue_ctx(toggle_val, extra)
    return ctx_group("rogue_group_aware_utility", toggle_val, extra)
end
local rogue_state = { in_combat = true, hp_pct = 30 }

local combat = load_spec("rogue/combat_sylvanas.lua").strategies
local combat_blind = find_strategy(combat, "Blind")
assert_false(combat_blind.matches(rogue_ctx(false, { target = {} }), rogue_state), "Combat Blind should be blocked with toggle off")
assert_true(combat_blind.matches(rogue_ctx(true, { target = {} }), rogue_state), "Combat Blind should match with toggle on")

local assassination = load_spec("rogue/assassination_sylvanas.lua").strategies
local assass_blind = find_strategy(assassination, "BlindCC")
assert_false(assass_blind.matches(rogue_ctx(false, { target = {} }), {}), "Assassination BlindCC should be blocked with toggle off")
assert_true(assass_blind.matches(rogue_ctx(true, { target = {} }), {}), "Assassination BlindCC should match with toggle on")

-- ============================================================================
-- Paladin Holy (CleanseParty)
-- ============================================================================
local holy = load_spec("paladin/holy_sylvanas.lua").strategies
local cleanse = find_strategy(holy, "CleanseParty")
local paladin_state = { cleanse_target = { unit = {} } }
local function paladin_ctx(toggle_val, extra)
    return ctx_group("paladin_group_aware_utility", toggle_val, extra)
end

assert_false(cleanse.matches(paladin_ctx(false, { control_risk = false }), paladin_state), "CleanseParty should be blocked with toggle off in group (no control risk)")
assert_true(cleanse.matches(paladin_ctx(true, { control_risk = false }), paladin_state), "CleanseParty should match with toggle on in group")
-- control_risk is an always-valid bypass
assert_true(cleanse.matches(paladin_ctx(false, { control_risk = true }), paladin_state), "CleanseParty should match with control_risk even when toggle off")

-- ============================================================================
-- Druid Balance (Innervate target scan)
-- ============================================================================
local balance_mod = load_spec("druid/balance_sylvanas.lua")
local function druid_ctx(toggle_val, extra)
    return ctx_group("druid_group_aware_utility", toggle_val, extra)
end

local healer_unit = {}
local me_unit = {}
ns.GetPartyMembers = function() return { healer_unit } end
ns.same_unit = function(a, b) return a == b end
ns.safe_field = function(u, field)
    if field == "get_class" then
        return function() return 5 end  -- priest healer
    end
    return nil
end
ns.mana_pct = function(u) return 20 end  -- low mana -> eligible for Innervate
ns.GetPlayer = function() return me_unit end
ns.spell_ready = function() return true end

local balance_ctx_on = druid_ctx(true, { in_combat = true, me = me_unit, mana_pct = 100 })
local state_on = balance_mod.build_state(balance_ctx_on)
assert_true(state_on.innervate_target == healer_unit, "Balance Innervate should scan party healer when druid_group_aware_utility is enabled")

local balance_ctx_off = druid_ctx(false, { in_combat = true, me = me_unit, mana_pct = 100 })
local state_off = balance_mod.build_state(balance_ctx_off)
assert_true(state_off.innervate_target == nil, "Balance Innervate should NOT scan party healer when druid_group_aware_utility is disabled")

-- Restore class-aware player provider for specs that check class on load.
ns.GetPlayer = function() return { get_class = function() return ns.current_class end } end

-- ============================================================================
-- Druid Restoration (Rebirth / dispels)
-- ============================================================================
local resto = load_spec("druid/resto_sylvanas.lua").strategies
local rebirth = find_strategy(resto, "RebirthBattleRez")
local resto_state = { rebirth_ready = true }
local function resto_ctx(toggle_val, extra)
    return ctx_group("druid_resto_group_aware_utility", toggle_val, extra)
end

-- RebirthBattleRez is a DSL strategy; the custom condition gates on group_aware.
assert_false(rebirth.matches(resto_ctx(false, { in_combat = true }), resto_state), "Resto Rebirth should be blocked with toggle off in group")
assert_true(rebirth.matches(resto_ctx(true, { in_combat = true }), resto_state), "Resto Rebirth should match with toggle on in group")

-- ============================================================================
-- Priest Discipline (Symbol of Hope / Mass Dispel)
-- ============================================================================
local function priest_ctx(toggle_val, extra)
    return ctx_group("priest_group_aware_utility", toggle_val, extra)
end

local discipline = load_spec("priest/discipline_sylvanas.lua", ns.CLASS_ID.PRIEST).strategies
local symbol_of_hope = find_strategy(discipline, "SymbolOfHope")
local mass_dispel = find_strategy(discipline, "MassDispel")

-- Symbol of Hope: when enabled, requires group/raid; when disabled, allowed regardless of group status
assert_true(symbol_of_hope.matches(priest_ctx(false, { in_combat = false, is_group = false }), { symbol_of_hope_ready = true }), "Priest SymbolOfHope should match with toggle off even when solo")
assert_false(symbol_of_hope.matches(priest_ctx(true, { in_combat = false, is_group = false }), { symbol_of_hope_ready = true }), "Priest SymbolOfHope should be blocked with toggle on when solo")
assert_true(symbol_of_hope.matches(priest_ctx(true, { in_combat = false }), { symbol_of_hope_ready = true }), "Priest SymbolOfHope should match with toggle on in group")

-- Mass Dispel: when enabled, requires group/raid; when disabled, allowed regardless of group status
assert_true(mass_dispel.matches(priest_ctx(false, { in_combat = true, is_group = false, mana_pct = 60 }), { mass_dispel_ready = true }), "Priest MassDispel should match with toggle off when solo")
assert_false(mass_dispel.matches(priest_ctx(true, { in_combat = true, is_group = false, mana_pct = 60 }), { mass_dispel_ready = true }), "Priest MassDispel should be blocked with toggle on when solo")
assert_true(mass_dispel.matches(priest_ctx(true, { in_combat = true, mana_pct = 60 }), { mass_dispel_ready = true }), "Priest MassDispel should match with toggle on in group")

-- ============================================================================
-- Shaman Restoration (Chain Heal / Mana Tide Totem)
-- ============================================================================
local function shaman_ctx(toggle_val, extra)
    return ctx_group("shaman_group_aware_utility", toggle_val, extra)
end

local shaman = load_spec("shaman/healing_sylvanas.lua", ns.CLASS_ID.SHAMAN)
local chain_heal = find_strategy(shaman.strategies, "ChainHeal")
local mana_tide = find_strategy(shaman.strategies, "ManaTideTotem")

-- Chain Heal: when disabled, always requires 2+ injured (raid doesn't bypass); when enabled, 1 injured in raid is allowed
local ch_state = { lowest = { unit = {}, effective_hp = 50 }, injured_count = 1, ch_ready = true }
assert_false(chain_heal.matches(shaman_ctx(false, { is_raid = true }), ch_state), "Shaman ChainHeal should be blocked with toggle off when only 1 injured and not in raid")
assert_true(chain_heal.matches(shaman_ctx(true, { is_raid = true }), ch_state), "Shaman ChainHeal should match with toggle on in raid with 1 injured")

-- Mana Tide Totem: when enabled, requires group/raid; when disabled, ignores group status
local mt_state = { mana_tide_ready = true, mana_pct = 20 }
assert_false(mana_tide.matches(shaman_ctx(true, { is_group = false, in_combat = true }), mt_state), "Shaman ManaTideTotem should be blocked with toggle on when solo")
assert_true(mana_tide.matches(shaman_ctx(false, { is_group = false, in_combat = true }), mt_state), "Shaman ManaTideTotem should match with toggle off when solo")

end

local ok, err = pcall(run_tests)
_G.require = orig_require
ns.current_class = nil
if not ok then
    error(err, 0)
end

print("PASS test_group_aware_utility_gates")
