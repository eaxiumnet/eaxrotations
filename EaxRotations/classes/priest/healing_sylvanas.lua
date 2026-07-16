-- healing_sylvanas.lua — Priest Healing Utilities for Holy and Discipline.
-- WHAT:  shared party/raid scanning, PW:S absorb tracking, and heal target selection.
-- WHEN:  loaded by holy_sylvanas.lua and discipline_sylvanas.lua during addon load.
-- WHY:   centralizes healing logic so both specs share the same triage and absorb math.
-- SAFETY: NS guard at load; buff_points nil-guarded (Pattern 11); no per-frame allocations.

-- ============================================================================
-- Priest Healing Utilities (EaxRotations)
-- Shared healing target scanning for Holy and Discipline playstyles
-- ============================================================================
local _G = _G
local NS = _G.EaxRotations
if not NS then
    if type(core) == "table" and type(core.log_error) == "function" then
        core.log_error("[EaxRotations ERROR] Core module not loaded!")
    else
        print("[EaxRotations ERROR] Core module not loaded!")
    end
    return
end

local _ok_enums, enums = pcall(require, "common/enums")
if not _ok_enums or type(enums) ~= "table" or type(enums.class_id) ~= "table" then enums = { class_id = NS.CLASS_ID } end
local load_player = NS.GetPlayer and NS.GetPlayer()
local ok_cls, cls_id = pcall(function() return load_player and load_player:get_class() end)
if not ok_cls or cls_id ~= enums.class_id.PRIEST then return end

local math_floor = math.floor
local ipairs = ipairs

local PARTY_UNITS = { "player", "party1", "party2", "party3", "party4" }
local RAID_UNITS = {}
for i = 1, 40 do RAID_UNITS[i] = "raid" .. i end

local healing_targets = {}
local healing_targets_count = 0
local scan_frame = 0

NS.PriestHealing = {}

local WEAKENED_SOUL_DEBUFF_IDS = { 6788 }
local RENEW_BUFF_IDS = { 139, 6074, 6075, 6076, 6077, 6078, 10927, 10928, 10929, 25315, 25221, 25222 }
local POWER_WORD_SHIELD_BUFF_IDS = { 25218, 25217, 10901, 10900, 10899, 10898, 6066, 6065, 3747, 600, 592, 17 }
-- Shared helpers from core_sylvanas.lua
local buff_up, debuff_up, predict_effective_deficit, buff_remains = NS.import_helpers("buff_up", "debuff_up", "predict_effective_deficit", "buff_remains")

local function has_weakened_soul(unit)
    if not unit then return true end
    for _, debuff_id in ipairs(WEAKENED_SOUL_DEBUFF_IDS) do
        if debuff_up(unit, debuff_id) then return true end
    end
    return false
end

local function has_renew(unit)
    if not unit then return false end
    for _, buff_id in ipairs(RENEW_BUFF_IDS) do
        if buff_up(unit, buff_id) then return true end
    end
    return false
end

--- Returns remaining seconds on Renew, or 0 if not present.
--- Used to avoid early refresh (wasted ticks) per Research divergence table.
local function renew_remains(unit)
    if not unit then return 0 end
    if type(buff_remains) ~= "function" then
        -- Fallback: if buff_remains isn't available, use has_renew as binary
        return has_renew(unit) and 999 or 0
    end
    local longest = 0
    for _, buff_id in ipairs(RENEW_BUFF_IDS) do
        local r = buff_remains(unit, buff_id)
        if r and r > longest then longest = r end
    end
    return longest
end

local function has_pws(unit)
    if not unit then return false end
    for _, buff_id in ipairs(POWER_WORD_SHIELD_BUFF_IDS) do
        if buff_up(unit, buff_id) then return true end
    end
    return false
end

--- Returns the remaining absorb amount on a Power Word: Shield buff.
--- Uses buff.points[1] which contains the absorb remaining value.
--- Returns 0 if no PW:S buff is present.
---@param unit game_object The unit to check.
---@return number absorb_remaining The absorb remaining on the shield, or 0.
local function pws_absorb_remaining(unit)
    if not unit then return 0 end
    if type(NS.buff_points) ~= "function" then
        -- Fallback: buff_points not yet available (core loaded after this module)
        return has_pws(unit) and 1 or 0
    end
    local points = NS.buff_points(unit, POWER_WORD_SHIELD_BUFF_IDS)
    if not points then return 0 end
    return points[1] or 0
end

NS.PriestHealing.pws_absorb_remaining = pws_absorb_remaining

NS.PriestHealing.has_weakened_soul = has_weakened_soul
NS.PriestHealing.has_renew = has_renew
NS.PriestHealing.renew_remains = renew_remains
NS.PriestHealing.has_pws = has_pws

NS.PriestHealing.predict_effective_deficit = predict_effective_deficit

function NS.PriestHealing.gate_overheal(spell_key, unit, cast_time, settings, spell_id)
    if NS.HealerDeficit and NS.HealerDeficit.gate_spell_overheal then
        return NS.HealerDeficit.gate_spell_overheal(spell_key, unit, cast_time, settings, spell_id)
    end
    return NS.gate_overheal and NS.gate_overheal(spell_key, unit, cast_time, settings, spell_id) or false
end

-- Magic debuff detection for Dispel Magic gate (used by Holy + Disc)
-- Uses NS.has_dispel_type_debuff when available; falls back to manual scan.
local DANGEROUS_MAGIC_DEBUFF_IDS = {
    12826 -- Polymorph
    , 61305 -- Polymorph (Black Cat)
    , 61721 -- Polymorph (Rabbit)
    , 61780 -- Polymorph (Turkey)
    , 26373 -- Hibernate
    , 19386 -- Wyvern Sting
    , 14326 -- Sleep
    , 5782 -- Fear
    , 6213 -- Fear
    , 17962 -- Death Coil
    , 15122 -- Repentance
    , 605 -- Mind Control
    , 20537 -- Arcane Torrent (silence)
    , 15487 -- Silence
    , 18469 -- Counterspell (silence)
    -- Expanded from WoWHead TBC dungeon/raid research for dangerous magic that kills or slows clears (MC, horror, AoE fear, silences, dots)
    , 32830 -- Possess (Auchenai Crypts MC - not easily dispelled)
    , 34984 -- Psychic Horror (Underbog/Slave Pens - bypasses Tremor, dispellable with Dispel Magic/Purge/Devour)
    , 38660 -- Fear (Steamvault Coilfang Siren AoE)
    , 46561 -- Fear (Sunwell Dusk Priest - uninterruptible)
    , 17172 -- Devouring Plague
    , 10890, 10888, 8124, 8122 -- Psychic Scream
    , 18425 -- Improved Counterspell silence
    -- More from research: Inhibit Magic (Auchenai), Arcane Resonance (Botanica magic amp), Fungal Decay poison etc.
    , 3436, 3439 -- Wandering Plague cast + disease aura
    , 31719 -- Suspension (Underbog Black Stalker Levitate debuff, dispellable)
    , 39193 -- Shadow Power (Mechanar Gatekeeper enemy buff, purge/dispel asap per guides)
    , 39029 -- Virulent Poison (SSC/Underbog poison, dispellable)
    , 39032 -- Initial Infection (SSC Colossus jumping disease, abolish disease)
    , 41303 -- Soul Drain (BT Reliquary magic DoT/mana drain, dispel priority)
    , 46280 -- Polymorph (SWP trash, dispel)
    , 46279 -- Flame Buffet (SWP magic fire amp, dispel)
    -- Lung Burst (Steamvault Thespia, dispellable debuff doing damage/stun)
    -- From research: more in Steamvault, Mechanar, Botanica, SSC, BT, SWP for dispel priority to speed clears and prevent deaths.
    -- Hound debuffs: 46296 Necrotic Poison, 46293 Corrosive Poison, 46297 Piercing Shadow, etc. (decursable/cleansable/dispellable)
}

--- Check if a unit has a dangerous magic debuff worth dispelling.
-- @param unit game_object|nil
-- @return boolean
local function has_dangerous_dispel(unit)
    if not unit then return false end
    -- Fast path: use shared type-based debuff checker
    if NS.has_dispel_type_debuff then
        local ok, result = pcall(NS.has_dispel_type_debuff, unit, "Magic")
        if ok and result == true then return true end
    end
    -- Fallback: scan known dangerous magic debuff IDs
    if NS.debuff_up then
        for i = 1, #DANGEROUS_MAGIC_DEBUFF_IDS do
            local ok, up = pcall(NS.debuff_up, unit, DANGEROUS_MAGIC_DEBUFF_IDS[i])
            if ok and up then return true end
        end
    end
    return false
end

--- Check if a unit has a disease debuff worth dispelling.
-- @param unit game_object|nil
-- @return boolean
local function has_disease(unit)
    if not unit then return false end
    -- Fast path: use shared type-based debuff checker
    if NS.has_dispel_type_debuff then
        local ok, result = pcall(NS.has_dispel_type_debuff, unit, "Disease")
        if ok and result == true then return true end
    end
    -- Fallback: use has_debuff with known disease IDs
    local DISEASE_DEBUFF_IDS = {
        3427 -- Infected Wound
        , 16428 -- Mangle (TBC disease flag)
        , 19615 -- Fling
        , 3436, 3439 -- Wandering Plague (disease)
        , 17172 -- Devouring Plague
        , 39032 -- Initial Infection (SSC, jumping, high priority abolish)
        , 46481 -- Disease Buffet (SWP, increases nature damage)
    }
    if NS.debuff_up then
        for i = 1, #DISEASE_DEBUFF_IDS do
            local ok, up = pcall(NS.debuff_up, unit, DISEASE_DEBUFF_IDS[i])
            if ok and up then return true end
        end
    end
    return false
end

NS.PriestHealing.has_dangerous_dispel = has_dangerous_dispel
NS.PriestHealing.has_disease = has_disease

--- Check if a unit has a poison debuff worth dispelling (for druid/shaman/pal optimization in dungeons).
local function has_poison(unit)
    if not unit then return false end
    if NS.has_dispel_type_debuff then
        local ok, result = pcall(NS.has_dispel_type_debuff, unit, "Poison")
        if ok and result == true then return true end
    end
    local POISON_DEBUFF_IDS = {
        3427, -- Infected Wound
        19615, -- Fling (poison?)
        39029, -- Virulent Poison (SSC/Underbog, dispellable poison dot)
        46296, -- Necrotic Poison (SWP hound)
        46293, -- Corrosive Poison (SWP hound)
        -- From research: Fungal Decay, Impending Coma in Botanica/Underbog, poison from Greyheart Tidecaller etc.
    }
    if NS.debuff_up then
        for i = 1, #POISON_DEBUFF_IDS do
            local ok, up = pcall(NS.debuff_up, unit, POISON_DEBUFF_IDS[i])
            if ok and up then return true end
        end
    end
    return false
end

--- Check if a unit has a curse debuff worth dispelling (mage/druid/shaman).
local function has_curse(unit)
    if not unit then return false end
    if NS.has_dispel_type_debuff then
        local ok, result = pcall(NS.has_dispel_type_debuff, unit, "Curse")
        if ok and result == true then return true end
    end
    local CURSE_DEBUFF_IDS = {
        31615, -- Hunter's Mark (but curse in some)
        -- Common TBC curses in dungeons: reduce healing, stats (from guides)
    }
    if NS.debuff_up then
        for i = 1, #CURSE_DEBUFF_IDS do
            local ok, up = pcall(NS.debuff_up, unit, CURSE_DEBUFF_IDS[i])
            if ok and up then return true end
        end
    end
    return false
end

NS.PriestHealing.has_poison = has_poison
NS.PriestHealing.has_curse = has_curse

local is_in_raid = NS.is_in_raid or function() return false end
local is_in_party = NS.is_in_party or function() return false end

local build_healing_entries = NS.build_healing_entries or function() return false end
local healing_get_tank = NS.healing_get_tank or function() return nil end
local healing_get_lowest_hp = NS.healing_get_lowest_hp or function() return nil end
local healing_count_below_hp = NS.healing_count_below_hp or function() return 0 end

local function scan_healing_targets()
    local current_frame = math_floor(NS.game_time_ms() / (1000 / 60))

    if current_frame > 0 and current_frame == scan_frame then
        return healing_targets, healing_targets_count
    end
    scan_frame = current_frame

    healing_targets_count = build_healing_entries(healing_targets, function(entry, unit)
        entry.has_renew = has_renew(unit)
        entry.renew_remains = renew_remains(unit)
        entry.has_pws = has_pws(unit)
        entry.has_weakened_soul = has_weakened_soul(unit)
    end)

    return healing_targets, healing_targets_count
end

NS.PriestHealing.scan_healing_targets = scan_healing_targets

local function get_tank_target()
    scan_healing_targets()
    return healing_get_tank(healing_targets, healing_targets_count)
end

NS.PriestHealing.get_tank_target = get_tank_target

local function get_lowest_hp_target(threshold)
    threshold = threshold or 100
    scan_healing_targets()
    return healing_get_lowest_hp(healing_targets, healing_targets_count, threshold)
end

NS.PriestHealing.get_lowest_hp_target = get_lowest_hp_target

local function count_below_hp(threshold)
    threshold = threshold or 100
    scan_healing_targets()
    return healing_count_below_hp(healing_targets, healing_targets_count, threshold)
end

NS.PriestHealing.count_below_hp = count_below_hp
NS.PriestHealing.is_in_raid = is_in_raid
NS.PriestHealing.is_in_party = is_in_party
NS.PriestHealing.PARTY_UNITS = PARTY_UNITS
NS.PriestHealing.RAID_UNITS = RAID_UNITS

--- Counts injured units in the player's subgroup only.
--- Uses the new core.party / get_party_frames backed NS.GetPartyMembers() for
--- accurate, current subgroup (the player's exact party in raids).
--- This is more reliable than is_party_member pcalls and leverages the frames API.
---@param threshold number HP threshold (0-100) to count as injured.
---@return integer count Number of injured subgroup members.
local function count_subgroup_below_hp(threshold)
    -- Prefer the accurate party list from new party frames feature
    local party = NS.GetPartyMembers and NS.GetPartyMembers() or nil
    if not party or #party == 0 then
        -- Fallback to full entries scan
        local entries, count = scan_healing_targets()
        if count == 0 or not entries then return 0 end
        local injured = 0
        for i = 1, count do
            local entry = entries[i]
            if entry and entry.effective_hp and entry.effective_hp < threshold then
                injured = injured + 1
            end
        end
        return injured
    end
    local injured = 0
    for i = 1, #party do
        local u = party[i]
        if u then
            local hp = NS.unit_health_pct and NS.unit_health_pct(u) or 100
            if hp < threshold then
                injured = injured + 1
            end
        end
    end
    return injured
end

NS.PriestHealing.count_subgroup_below_hp = count_subgroup_below_hp

-- ============================================================================
-- FULL HEALING ROTATION (scorecard "healing" spec — triage + emergency + dispel)
-- ============================================================================
local spec_kit = require("shared/spec_kit_sylvanas")
local potion_helper = require("shared/potion_helper_sylvanas")
local SPELLS = NS.PriestSpells or {}
local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    PowerWordShield   = define("PowerWordShield",   { 25218, 25217, 10901, 10900, 10899, 10898, 6066, 6065, 3747, 600, 592, 17 }, "PowerWordShield"),
    FlashHeal         = define("FlashHeal",         { 25235, 25233, 10917, 10916, 10915, 9474, 9473, 9472, 2061 }, "FlashHeal"),
    GreaterHeal       = define("GreaterHeal",       { 25213, 25210, 10965, 10964, 10963, 2060 }, "GreaterHeal"),
    Renew             = define("Renew",             { 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }, "Renew"),
    DispelMagic       = define("DispelMagic",       { 988, 527 }, "DispelMagic"),
    CureDisease       = define("CureDisease",       { 528 }, "CureDisease"),
    AbolishDisease    = define("AbolishDisease",    { 552 }, "AbolishDisease"),
    Fade              = define("Fade",              { 586 }, "Fade"),
    DesperatePrayer   = define("DesperatePrayer",   { 25437, 19243, 19242, 19241, 19240, 19238, 19236, 13908 }, "DesperatePrayer"),
    InnerFire         = define("InnerFire",         { 25431, 10952, 10951, 1006, 602, 7128, 588 }, "InnerFire"),
    PowerWordFortitude = define("PowerWordFortitude", { 25389, 10938, 10937, 2791, 1245, 1244, 1243 }, "PowerWordFortitude"),
}

local INNER_FIRE_BUFF = { 25431, 10952, 10951, 1006, 602, 7128, 588 }
local FORTITUDE_BUFF = { 25392, 25389, 10938, 10937, 2791, 1245, 1244, 1243, 21564, 21562 }
local HEALTHSTONE_IDS = { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }

local EMERGENCY_HP = 30
local PWS_HP = 50
local FLASH_HP = 70
local GREATER_HP = 55
local RENEW_HP = 90
local FADE_HP = 60

local HEAL_SCHEMA = { hp_pct = 100, mana_pct = 100, lowest_hp = 100 }

local heal_state = {
    lowest = nil,
    tank = nil,
    mana_pct = 100,
    hp_pct = 100,
    lowest_hp = 100,
    pws_ready = false,
    flash_ready = false,
    greater_ready = false,
    renew_ready = false,
    dispel_ready = false,
    cure_disease_ready = false,
    fade_ready = false,
    desperate_ready = false,
    inner_fire_ready = false,
    fort_ready = false,
    has_inner_fire = false,
    has_fortitude = false,
    has_weakened_soul = false,
    has_renew = false,
    has_dangerous_dispel = false,
    has_disease = false,
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
    return NS.PriestHealing.gate_overheal and NS.PriestHealing.gate_overheal(spell_key, unit, cast_time, settings, spell_id) or false
end

local function build_state(context)
    context = context or {}
    local me = context.me or (NS.GetPlayer and NS.GetPlayer()) or NS.PLAYER_UNIT

    heal_state.in_combat = context.in_combat == true
    heal_state.is_group = context.is_group == true
    heal_state.is_raid = context.is_raid == true
    heal_state.is_solo = context.is_solo == true
    heal_state.is_pvp = context.is_pvp == true or context.is_arena == true or context.is_battleground == true
    heal_state.is_leveling = context.is_leveling == true
    heal_state.mana_pct = context.mana_pct or (me and NS.mana_pct and NS.mana_pct(me)) or 100
    heal_state.hp_pct = context.hp or context.hp_pct or (me and NS.unit_health_pct and NS.unit_health_pct(me)) or 100

    scan_healing_targets()
    heal_state.lowest = get_lowest_hp_target(RENEW_HP)
    heal_state.tank = get_tank_target()

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

    local target = heal_state.lowest and heal_state.lowest.unit
    heal_state.pws_ready = target and NS.spell_ready and NS.spell_ready(ACTION.PowerWordShield, target) or false
    heal_state.flash_ready = target and NS.spell_ready and NS.spell_ready(ACTION.FlashHeal, target) or false
    heal_state.greater_ready = target and NS.spell_ready and NS.spell_ready(ACTION.GreaterHeal, target) or false
    heal_state.renew_ready = target and NS.spell_ready and NS.spell_ready(ACTION.Renew, target) or false
    heal_state.dispel_ready = NS.spell_ready and NS.spell_ready(ACTION.DispelMagic, me, { skip_range = true }) or false
    heal_state.cure_disease_ready = NS.spell_ready and NS.spell_ready(ACTION.CureDisease, me, { skip_range = true }) or false
    heal_state.fade_ready = NS.spell_ready and NS.spell_ready(ACTION.Fade, me, { skip_range = true }) or false
    heal_state.desperate_ready = NS.spell_ready and NS.spell_ready(ACTION.DesperatePrayer, me, { skip_range = true }) or false
    heal_state.inner_fire_ready = NS.spell_ready and NS.spell_ready(ACTION.InnerFire, me, { skip_range = true }) or false
    heal_state.fort_ready = NS.spell_ready and NS.spell_ready(ACTION.PowerWordFortitude, me, { skip_range = true }) or false

    heal_state.has_inner_fire = me and NS.buff_up and NS.buff_up(me, INNER_FIRE_BUFF) or false
    heal_state.has_fortitude = me and NS.buff_up and NS.buff_up(me, FORTITUDE_BUFF) or false
    heal_state.has_weakened_soul = target and has_weakened_soul(target) or false
    heal_state.has_renew = target and has_renew(target) or false
    heal_state.has_dangerous_dispel = target and has_dangerous_dispel(target) or false
    heal_state.has_disease = target and has_disease(target) or false
    heal_state.healthstone_id = first_ready_item(HEALTHSTONE_IDS)
    heal_state.lowest_hp = entry_hp(heal_state.lowest)

    return spec_kit.safe_state(heal_state, HEAL_SCHEMA)
end

local function cast_on(spell, unit, reason, opts)
    if not unit then return false end
    return NS.try_cast and NS.try_cast(spell, unit, reason, opts) or false
end

local function emergency_pws_matches(context, state)
    if not state.pws_ready then return false end
    local target = state.lowest
    if not target or not target.unit then return false end
    if (entry_hp(target) or 100) > PWS_HP then return false end
    if state.has_weakened_soul then return false end
    return true
end

local function emergency_flash_matches(context, state)
    if context.is_moving then return false end
    if not state.flash_ready then return false end
    local target = state.lowest
    if not target or not target.unit then return false end
    if (entry_hp(target) or 100) > EMERGENCY_HP then return false end
    if gate_overheal("FlashHeal", target.unit, 1.5, context.settings) then return false end
    return true
end

local function greater_heal_matches(context, state)
    if context.is_moving then return false end
    if not state.greater_ready then return false end
    local target = state.lowest
    if not target or not target.unit then return false end
    local hp = entry_hp(target)
    if hp > GREATER_HP or hp <= EMERGENCY_HP then return false end
    if gate_overheal("GreaterHeal", target.unit, 2.5, context.settings) then return false end
    return true
end

local function flash_heal_matches(context, state)
    if context.is_moving then return false end
    if not state.flash_ready then return false end
    local target = state.lowest
    if not target or not target.unit then return false end
    if (entry_hp(target) or 100) >= FLASH_HP then return false end
    if (state.mana_pct or 100) < 5 then return false end
    if gate_overheal("FlashHeal", target.unit, 1.5, context.settings) then return false end
    return true
end

local function renew_matches(context, state)
    if not state.renew_ready then return false end
    local target = state.lowest
    if not target or not target.unit then return false end
    if (entry_hp(target) or 100) >= RENEW_HP then return false end
    if state.has_renew then return false end
    return true
end

local function dispel_magic_matches(context, state)
    if not state.dispel_ready then return false end
    if not state.has_dangerous_dispel then return false end
    local target = state.lowest
    if not target or not target.unit then return false end
    return true
end

local function cure_disease_matches(context, state)
    if not state.cure_disease_ready then return false end
    if not state.has_disease then return false end
    local target = state.lowest
    if not target or not target.unit then return false end
    return true
end

local function fade_matches(context, state)
    if not context.in_combat then return false end
    if not state.fade_ready then return false end
    if (state.hp_pct or 100) > FADE_HP then return false end
    if not (context.is_group or context.is_raid) then return false end
    return true
end

local function desperate_prayer_matches(context, state)
    if not state.desperate_ready then return false end
    if (state.hp_pct or 100) > EMERGENCY_HP then return false end
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

local function inner_fire_matches(context, state)
    if context.in_combat then return false end
    if state.has_inner_fire then return false end
    if not state.inner_fire_ready then return false end
    return true
end

local function fortitude_matches(context, state)
    if context.in_combat then return false end
    if state.has_fortitude then return false end
    if not state.fort_ready then return false end
    return true
end

local strategies = {
    { name = "DesperatePrayer", matches = desperate_prayer_matches,
      execute = function(context, state)
          local me = context.me or NS.PLAYER_UNIT
          return cast_on(ACTION.DesperatePrayer, me, "[HEAL] Desperate Prayer", { skip_range = true })
      end },
    { name = "EmergencyPWS", matches = emergency_pws_matches,
      execute = function(context, state)
          return cast_on(ACTION.PowerWordShield, state.lowest.unit, "[HEAL] Emergency PW:S")
      end },
    { name = "EmergencyFlashHeal", matches = emergency_flash_matches,
      execute = function(context, state)
          return cast_on(ACTION.FlashHeal, state.lowest.unit, "[HEAL] Emergency Flash Heal")
      end },
    { name = "Fade", matches = fade_matches,
      execute = function(context, state)
          local me = context.me or NS.PLAYER_UNIT
          return cast_on(ACTION.Fade, me, "[HEAL] Fade", { skip_range = true })
      end },
    { name = "DispelMagic", matches = dispel_magic_matches,
      execute = function(context, state)
          return cast_on(ACTION.DispelMagic, state.lowest.unit, "[HEAL] Dispel Magic")
      end },
    { name = "CureDisease", matches = cure_disease_matches,
      execute = function(context, state)
          return cast_on(ACTION.CureDisease, state.lowest.unit, "[HEAL] Cure Disease")
      end },
    { name = "GreaterHeal", matches = greater_heal_matches,
      execute = function(context, state)
          return cast_on(ACTION.GreaterHeal, state.lowest.unit, "[HEAL] Greater Heal")
      end },
    { name = "FlashHeal", matches = flash_heal_matches,
      execute = function(context, state)
          return cast_on(ACTION.FlashHeal, state.lowest.unit, "[HEAL] Flash Heal")
      end },
    { name = "Renew", matches = renew_matches,
      execute = function(context, state)
          return cast_on(ACTION.Renew, state.lowest.unit, "[HEAL] Renew")
      end },
    { name = "ManaPotion", matches = mana_potion_matches,
      execute = function(context, state)
          return potion_helper.try_use_potion(context, potion_helper.MANA_POTION_IDS or {}) == true
      end },
    { name = "Healthstone", matches = healthstone_matches,
      execute = function(context, state)
          if state.healthstone_id and NS.use_item_by_id then
              return NS.use_item_by_id(state.healthstone_id) == true
          end
          return false
      end },
    { name = "InnerFire", matches = inner_fire_matches,
      execute = function(context, state)
          local me = context.me or NS.PLAYER_UNIT
          return cast_on(ACTION.InnerFire, me, "[HEAL] Inner Fire", { skip_range = true })
      end },
    { name = "PowerWordFortitude", matches = fortitude_matches,
      execute = function(context, state)
          local me = context.me or NS.PLAYER_UNIT
          return cast_on(ACTION.PowerWordFortitude, me, "[HEAL] Power Word: Fortitude", { skip_range = true })
      end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("healing", strategies, { get_state = build_state })
end
if NS.log then NS.log("Priest healing rotation registered") end

NS.PriestHealing.strategies = strategies
NS.PriestHealing.build_state = build_state

-- Healing utilities + rotation loaded
return NS.PriestHealing
