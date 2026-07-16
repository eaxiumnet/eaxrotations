-- healing_sylvanas.lua — Paladin Healing rotation for TBC Anniversary (2.5.5).
-- WHAT:  full healing priority list (triage, emergency, dispel, OOC buffs) + heal_helper re-export.
-- WHEN:  combat or pre-combat with friendly targets; also required by holy_sylvanas for helpers.
-- WHY:  scorecard "healing" spec must be a real rotation (triage + emergency + dispel + overheal gate).
-- SAFETY: Pattern 14 via safe_state; HealerDeficit overheal gate; nil-guarded state; no on_update allocs.

local NS = _G.EaxRotations
if not NS then return nil end

-- ---------------------------------------------------------------------------
-- Helpers (backward-compatible re-export of heal_helper_sylvanas)
-- ---------------------------------------------------------------------------
local Healing = NS.PaladinHealing
if type(Healing) ~= "table" then
    local ok, h = pcall(require, "classes/paladin/heal_helper_sylvanas")
    if ok and type(h) == "table" then
        Healing = h
    end
    Healing = Healing or NS.PaladinHealing
end
Healing = Healing or {}
NS.PaladinHealing = NS.PaladinHealing or Healing

local spec_kit = require("shared/spec_kit_sylvanas")
local potion_helper = require("shared/potion_helper_sylvanas")
local SPELLS = NS.PaladinSpells or {}
local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    FlashOfLight      = define("FlashOfLight",      { 27137, 19943, 19942, 19941, 19940, 19939, 19750 }, "FlashOfLight"),
    HolyLight         = define("HolyLight",         { 27136, 25292, 10329, 10328, 10324, 1042, 647, 639, 635 }, "HolyLight"),
    HolyShock         = define("HolyShock",         { 33072, 27174, 20930, 20929, 20473 }, "HolyShock"),
    Cleanse           = define("Cleanse",           { 4987 }, "Cleanse"),
    Purify            = define("Purify",            { 1152 }, "Purify"),
    DivineShield      = define("DivineShield",      { 1020, 642 }, "DivineShield"),
    LayOnHands        = define("LayOnHands",        { 27154, 10310, 2800, 633 }, "LayOnHands"),
    BlessingOfWisdom  = define("BlessingOfWisdom",  { 27142, 25290, 19854, 19853, 19852, 19850, 19742 }, "BlessingOfWisdom"),
    ConcentrationAura = define("ConcentrationAura", { 19746 }, "ConcentrationAura"),
    SealOfWisdom      = define("SealOfWisdom",      { 27166, 20357, 20356, 20166 }, "SealOfWisdom"),
}

local BUFF_BLESSING_WISDOM = { 27143, 27142, 25918, 25894, 25290, 19854, 19853, 19852, 19850, 19742 }
local BUFF_CONCENTRATION_AURA = { 19746 }
local BUFF_SEAL_WISDOM = { 27166, 20357, 20356, 20166 }
local BUFF_DIVINE_SHIELD = { 642, 1020 }
local DEBUFF_FORBEARANCE = { 25771 }
local HEALTHSTONE_IDS = { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }

local EMERGENCY_HP = 30
local LOH_HP = 15
local DIVINE_SHIELD_HP = 20
local HOLY_SHOCK_HP = 40
local FOL_HP = 92

local HEAL_SCHEMA = {
    hp_pct = 100,
    mana_pct = 100,
    lowest_hp = 100,
    emergency_count = 0,
}

local heal_state = {
    lowest = nil,
    tank = nil,
    cleanse_target = nil,
    mana_pct = 100,
    hp_pct = 100,
    loh_ready = false,
    ds_ready = false,
    cleanse_ready = false,
    holy_shock_ready = false,
    holy_light_ready = false,
    fol_ready = false,
    bow_ready = false,
    aura_ready = false,
    seal_ready = false,
    has_blessing_wisdom = false,
    has_concentration_aura = false,
    has_seal_wisdom = false,
    has_forbearance = false,
    has_divine_shield = false,
    healthstone_id = nil,
    in_combat = false,
    is_group = false,
    is_raid = false,
    is_solo = false,
    is_pvp = false,
    is_leveling = false,
}

local function entry_hp(entry)
    if entry and type(entry.effective_hp) == "number" then return entry.effective_hp end
    if entry and type(entry.hp) == "number" then return entry.hp end
    return 100
end

local function first_ready_item(ids)
    if not NS.is_item_ready then return nil end
    for i = 1, #ids do
        if NS.is_item_ready(ids[i]) then return ids[i] end
    end
    return nil
end

local function gate_overheal(spell_key, unit, cast_time, settings, spell_id)
    if NS.HealerDeficit and NS.HealerDeficit.gate_spell_overheal then
        return NS.HealerDeficit.gate_spell_overheal(spell_key, unit, cast_time, settings, spell_id)
    end
    if Healing.gate_overheal then
        return Healing.gate_overheal(spell_key, unit, cast_time, settings, spell_id)
    end
    return NS.gate_overheal and NS.gate_overheal(spell_key, unit, cast_time, settings, spell_id) or false
end

local function build_state(context)
    context = context or {}
    local me = context.me or (NS.GetPlayer and NS.GetPlayer()) or NS.PLAYER_UNIT
    local settings = context.settings or {}

    heal_state.in_combat = context.in_combat == true
    heal_state.is_group = context.is_group == true
    heal_state.is_raid = context.is_raid == true
    heal_state.is_solo = context.is_solo == true
    heal_state.is_pvp = context.is_pvp == true or context.is_arena == true or context.is_battleground == true
    heal_state.is_leveling = context.is_leveling == true
    heal_state.mana_pct = context.mana_pct or (me and NS.mana_pct and NS.mana_pct(me)) or 100
    heal_state.hp_pct = context.hp or context.hp_pct or (me and NS.unit_health_pct and NS.unit_health_pct(me)) or 100

    if type(Healing.scan_healing_targets) == "function" then
        Healing.scan_healing_targets()
    end
    heal_state.lowest = (Healing.get_lowest_hp_target and Healing.get_lowest_hp_target(FOL_HP)) or nil
    heal_state.tank = (Healing.get_tank_target and Healing.get_tank_target()) or nil
    heal_state.cleanse_target = (Healing.get_cleanse_target and Healing.get_cleanse_target()) or nil

    if context.friendly_target and context.friendly_target_hp then
        local ft_hp = context.friendly_target_hp or 100
        if ft_hp < entry_hp(heal_state.lowest) then
            heal_state.lowest = {
                unit = context.friendly_target,
                effective_hp = ft_hp,
                hp = ft_hp,
                deficit = context.friendly_target_deficit or 0,
            }
        end
    end

    heal_state.loh_ready = NS.spell_ready and NS.spell_ready(ACTION.LayOnHands, me, { skip_range = true, expected_cooldown = 3600 }) or false
    heal_state.ds_ready = NS.spell_ready and NS.spell_ready(ACTION.DivineShield, me, { skip_range = true, expected_cooldown = 300 }) or false
    heal_state.cleanse_ready = NS.spell_ready and NS.spell_ready(ACTION.Cleanse, me, { skip_range = true }) or false
    heal_state.holy_shock_ready = heal_state.lowest and NS.spell_ready and NS.spell_ready(ACTION.HolyShock, heal_state.lowest.unit) or false
    heal_state.holy_light_ready = heal_state.lowest and NS.spell_ready and NS.spell_ready(ACTION.HolyLight, heal_state.lowest.unit) or false
    heal_state.fol_ready = heal_state.lowest and NS.spell_ready and NS.spell_ready(ACTION.FlashOfLight, heal_state.lowest.unit) or false
    heal_state.bow_ready = NS.spell_ready and NS.spell_ready(ACTION.BlessingOfWisdom, me, { skip_range = true }) or false
    heal_state.aura_ready = NS.spell_ready and NS.spell_ready(ACTION.ConcentrationAura, me, { skip_range = true }) or false
    heal_state.seal_ready = NS.spell_ready and NS.spell_ready(ACTION.SealOfWisdom, me, { skip_range = true }) or false

    heal_state.has_blessing_wisdom = me and NS.buff_up and NS.buff_up(me, BUFF_BLESSING_WISDOM) or false
    heal_state.has_concentration_aura = me and NS.buff_up and NS.buff_up(me, BUFF_CONCENTRATION_AURA) or false
    heal_state.has_seal_wisdom = me and NS.buff_up and NS.buff_up(me, BUFF_SEAL_WISDOM) or false
    heal_state.has_divine_shield = me and NS.buff_up and NS.buff_up(me, BUFF_DIVINE_SHIELD) or false
    heal_state.has_forbearance = me and NS.debuff_up and NS.debuff_up(me, DEBUFF_FORBEARANCE) or false
    heal_state.healthstone_id = first_ready_item(HEALTHSTONE_IDS)
    heal_state.lowest_hp = entry_hp(heal_state.lowest)

    return spec_kit.safe_state(heal_state, HEAL_SCHEMA)
end

local function cast_on_entry(spell, entry, reason, opts)
    if not entry or not entry.unit then return false end
    return NS.try_cast and NS.try_cast(spell, entry.unit, reason, opts) or false
end

local function lay_on_hands_matches(context, state)
    if not state.loh_ready then return false end
    local target = state.lowest
    if not target or not target.unit then return false end
    if (entry_hp(target) or 100) > LOH_HP then return false end
    if state.has_forbearance then return false end
    return true
end

local function divine_shield_matches(context, state)
    if not state.ds_ready then return false end
    if state.has_divine_shield or state.has_forbearance then return false end
    if (state.hp_pct or 100) > DIVINE_SHIELD_HP then return false end
    return true
end

local function cleanse_matches(context, state)
    if not state.cleanse_ready then return false end
    if not state.cleanse_target or not state.cleanse_target.unit then return false end
    return true
end

local function holy_shock_emergency_matches(context, state)
    if not state.holy_shock_ready then return false end
    local target = state.lowest
    if not target or not target.unit then return false end
    local hp = entry_hp(target)
    if hp > HOLY_SHOCK_HP and not context.is_moving then return false end
    if hp > FOL_HP then return false end
    return true
end

local function holy_light_emergency_matches(context, state)
    if context.is_moving then return false end
    if not state.holy_light_ready then return false end
    local target = state.lowest
    if not target or not target.unit then return false end
    if (entry_hp(target) or 100) > EMERGENCY_HP then return false end
    if gate_overheal("HolyLight", target.unit, 2.5, context.settings) then return false end
    return true
end

local function flash_of_light_matches(context, state)
    if context.is_moving then return false end
    if not state.fol_ready then return false end
    local target = state.lowest
    if not target or not target.unit then return false end
    if (entry_hp(target) or 100) >= FOL_HP then return false end
    if (state.mana_pct or 100) < 5 then return false end
    if gate_overheal("FlashOfLight", target.unit, 1.5, context.settings) then return false end
    return true
end

local function mana_potion_matches(context, state)
    if not context.in_combat then return false end
    if (state.mana_pct or 100) > 22 then return false end
    if not potion_helper or not potion_helper.try_use_potion then return false end
    return true
end

local function healthstone_matches(context, state)
    if not context.in_combat then return false end
    if (state.hp_pct or 100) > 35 then return false end
    if not state.healthstone_id then return false end
    return true
end

local function blessing_of_wisdom_matches(context, state)
    if context.in_combat then return false end
    if state.has_blessing_wisdom then return false end
    if not state.bow_ready then return false end
    return true
end

local function concentration_aura_matches(context, state)
    if context.in_combat and not context.is_pvp then return false end
    if state.has_concentration_aura then return false end
    if not state.aura_ready then return false end
    return true
end

local function seal_of_wisdom_matches(context, state)
    if state.has_seal_wisdom then return false end
    if not state.seal_ready then return false end
    if (state.mana_pct or 100) > 90 and not context.in_combat then return false end
    return true
end

local strategies = {
    {
        name = "LayOnHands",
        matches = lay_on_hands_matches,
        execute = function(context, state)
            return cast_on_entry(ACTION.LayOnHands, state.lowest, "[HEAL] Lay on Hands", { expected_cooldown = 3600, skip_range = true })
        end,
    },
    {
        name = "DivineShield",
        matches = divine_shield_matches,
        execute = function(context, state)
            local me = context.me or NS.PLAYER_UNIT
            return NS.try_cast(ACTION.DivineShield, me, "[HEAL] Divine Shield", { expected_cooldown = 300, skip_range = true })
        end,
    },
    {
        name = "Cleanse",
        matches = cleanse_matches,
        execute = function(context, state)
            return cast_on_entry(ACTION.Cleanse, state.cleanse_target, "[HEAL] Cleanse")
        end,
    },
    {
        name = "HolyShockEmergency",
        matches = holy_shock_emergency_matches,
        execute = function(context, state)
            return cast_on_entry(ACTION.HolyShock, state.lowest, "[HEAL] Holy Shock", { expected_cooldown = 15 })
        end,
    },
    {
        name = "HolyLightEmergency",
        matches = holy_light_emergency_matches,
        execute = function(context, state)
            return cast_on_entry(ACTION.HolyLight, state.lowest, "[HEAL] Holy Light emergency")
        end,
    },
    {
        name = "FlashOfLight",
        matches = flash_of_light_matches,
        execute = function(context, state)
            return cast_on_entry(ACTION.FlashOfLight, state.lowest, "[HEAL] Flash of Light")
        end,
    },
    {
        name = "ManaPotion",
        matches = mana_potion_matches,
        execute = function(context, state)
            local ids = potion_helper.MANA_POTION_IDS or {}
            return potion_helper.try_use_potion(context, ids) == true
        end,
    },
    {
        name = "Healthstone",
        matches = healthstone_matches,
        execute = function(context, state)
            if state.healthstone_id and NS.use_item_by_id then
                return NS.use_item_by_id(state.healthstone_id) == true
            end
            return false
        end,
    },
    {
        name = "BlessingOfWisdom",
        matches = blessing_of_wisdom_matches,
        execute = function(context, state)
            local me = context.me or NS.PLAYER_UNIT
            return NS.try_cast(ACTION.BlessingOfWisdom, me, "[HEAL] Blessing of Wisdom", { skip_range = true })
        end,
    },
    {
        name = "ConcentrationAura",
        matches = concentration_aura_matches,
        execute = function(context, state)
            local me = context.me or NS.PLAYER_UNIT
            return NS.try_cast(ACTION.ConcentrationAura, me, "[HEAL] Concentration Aura", { skip_range = true })
        end,
    },
    {
        name = "SealOfWisdom",
        matches = seal_of_wisdom_matches,
        execute = function(context, state)
            local me = context.me or NS.PLAYER_UNIT
            return NS.try_cast(ACTION.SealOfWisdom, me, "[HEAL] Seal of Wisdom", { skip_range = true })
        end,
    },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("healing", strategies, { get_state = build_state })
end
if NS.log then NS.log("Paladin healing rotation registered") end

Healing.strategies = strategies
Healing.build_state = build_state

return Healing
