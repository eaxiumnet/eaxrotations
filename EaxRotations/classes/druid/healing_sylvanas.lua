-- healing_sylvanas.lua -- Shared druid healing helpers for TBC Anniversary (2.5.5).
-- WHAT:  healing target scanner + spell recommender for resto/off-heal playstyles.
-- WHEN:  loaded by resto_sylvanas.lua and resto_vanilla.lua via require() or NS.DruidHealing.
-- WHY:   centralizes HoT scanning for TBC resto (Lifebloom 3x, Rejuv, Regrowth per Icy Veins/Wowhead) so resto specs don't re-implement. 
-- SAFETY: all spell accesses via spec_kit.define_action_for_class; nil-guarded entry fields; no on_update() allocs.
-- NOTE:   this is a helper module, NOT a rotation spec — no strategies/build_state/registration.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")

local M = {}
local healing_targets = {}
local healing_targets_count = 0
local scan_frame = 0
local LIFEBLOOM_MAX_STACKS = 3
local LIFEBLOOM_REFRESH_REMAINS = 1.6

local SPELLS = NS.DruidSpells or {}

-- Centralized spell resolver via spec_kit (rank IDs from class_sylvanas.lua).
local define = spec_kit.define_action_for_class(SPELLS)
local ACTION = {
    HealingTouch  = define("HealingTouch",  { 26979, 26978, 25297, 9889, 9888, 9758, 8903, 6778, 5189, 5188, 5187, 5186, 5185 }, "HealingTouch"),
    Lifebloom     = define("Lifebloom",     { 33763 }, "Lifebloom"),
    Regrowth      = define("Regrowth",      { 26980, 9858, 9857, 9856, 9750, 8941, 8940, 8939, 8938, 8936 }, "Regrowth"),
    Rejuvenation  = define("Rejuvenation",  { 26982, 26981, 25299, 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774 }, "Rejuvenation"),
}

local function has(unit, spell)
    return unit and spell and NS.buff_up(unit, spell.id or spell)
end

local function stacks(unit, spell)
    return unit and spell and NS.buff_stacks and NS.buff_stacks(unit, spell.id or spell) or 0
end

local function remains(unit, spell)
    return unit and spell and NS.buff_remains and NS.buff_remains(unit, spell.id or spell) or 0
end

function M.scan_healing_targets()
    local current_frame = math.floor(NS.game_time_ms() / (1000 / 60))
    if current_frame > 0 and current_frame == scan_frame then
        return healing_targets, healing_targets_count
    end
    scan_frame = current_frame
    healing_targets_count = NS.build_healing_entries(healing_targets, function(entry, unit)
        entry.has_lifebloom = has(unit, ACTION.Lifebloom)
        entry.lifebloom_stacks = stacks(unit, ACTION.Lifebloom)
        entry.lifebloom_remains = remains(unit, ACTION.Lifebloom)
        entry.has_rejuvenation = has(unit, ACTION.Rejuvenation)
        entry.has_regrowth = has(unit, ACTION.Regrowth)
    end)
    return healing_targets, healing_targets_count
end

function M.tank_target()
    M.scan_healing_targets()
    return NS.healing_get_tank and NS.healing_get_tank(healing_targets, healing_targets_count) or nil
end

function M.best_target(context)
    M.scan_healing_targets()
    return NS.healing_get_lowest_hp and NS.healing_get_lowest_hp(healing_targets, healing_targets_count, 92) or nil
end

-- Advanced: use new party frames powered helpers when available in context
function M.best_party_target(context)
    if context and context.heal_targets and #context.heal_targets > 0 then
        -- Use platform heal targets (advanced menu-driven from target_selector)
        return {unit = context.heal_targets[1]}
    end
    if NS.get_best_heal_target then
        local best = NS.get_best_heal_target(40)
        if best then return {unit = best} end
    end
    if context and context.party_injured_count and context.party_injured_count > 0 then
        -- Prefer party-aware lowest if group injured
        local low = NS.GetPartyLowestHP and NS.GetPartyLowestHP()
        if low then return {unit = low} end
    end
    return M.best_target(context)
end

function M.recommend(context)
    -- Leverage advanced party data from core.party frames for smarter targeting
    local entry = M.best_party_target(context) or M.best_target(context)
    local tank = M.tank_target()
    if not entry and tank then entry = tank end
    if not entry or not entry.unit then return nil end
    local target = entry.unit

    local hp = entry.hp or NS.unit_health_pct(target)
    local effective = entry.effective_hp or hp

    if effective <= 35 or (entry.time_to_die and entry.time_to_die < 4) or (entry.death_risk and entry.death_risk > 100) or entry.will_die_soon or (context and (context.party_imminent_deaths or 0) > 0 and effective < 45) then
        return { spell = ACTION.HealingTouch, target = target, reason = "no one dies: emergency or imminent death save" }
    end
    if effective <= 55 and not entry.has_regrowth then
        return { spell = ACTION.Regrowth, target = target, reason = "stabilize with direct heal plus HoT" }
    end
    -- Advanced party-aware: use context.party_tanks from core.party frames for priority
    local tanks = (context and context.party_tanks) or {}
    local primary_tank = tank and tank.unit
    if #tanks > 0 then primary_tank = tanks[1] end
    if primary_tank and (context.in_combat or (tank and tank.effective_hp or 100) <= 95) then
        local lb_stacks = (tank and tank.lifebloom_stacks) or 0
        local lb_remains = (tank and tank.lifebloom_remains) or 0
        if lb_stacks < LIFEBLOOM_MAX_STACKS or lb_remains <= LIFEBLOOM_REFRESH_REMAINS then
            return { spell = ACTION.Lifebloom, target = primary_tank, reason = "maintain priority tank Lifebloom roll (party frames)" }
        end
    end
    if hp <= 85 and not entry.has_lifebloom then
        return { spell = ACTION.Lifebloom, target = target, reason = "tank/party rolling HoT" }
    end
    if hp <= 90 and not entry.has_rejuvenation then
        return { spell = ACTION.Rejuvenation, target = target, reason = "efficient maintenance HoT" }
    end
    return nil
end

function M.try_heal(context)
    -- Mounted bail: healer should not queue heals while mounted
    local me = context and context.me or NS.GetPlayer()
    if me and me.is_mounted and me:is_mounted() then return false end
    local rec = M.recommend(context)
    if not rec then return false end
    return NS.try_cast(rec.spell, rec.target, "[DRUID HEAL] " .. rec.reason)
end

function M.gate_overheal(spell_key, unit, cast_time, settings, spell_id)
    if NS.HealerDeficit and NS.HealerDeficit.gate_spell_overheal then
        return NS.HealerDeficit.gate_spell_overheal(spell_key, unit, cast_time, settings, spell_id)
    end
    return NS.gate_overheal and NS.gate_overheal(spell_key, unit, cast_time, settings, spell_id) or false
end

NS.DruidHealing = M
return M
