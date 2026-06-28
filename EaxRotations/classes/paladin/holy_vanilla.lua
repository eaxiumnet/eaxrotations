-- holy_vanilla.lua — Paladin Holy healing for Vanilla/Classic Anniversary (1.15.x).
-- WHAT:  tank/raid healing (Flash of Light, Holy Light, Divine Favor).
-- WHEN:  combat or pre-combat, when NS.is_vanilla() is true.
-- WHY:   expansion-aware loader selects _vanilla suffix for Classic Era.
-- SAFETY: nil-guards on NS, SPELLS, and state fields per Pattern 14.


local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.PaladinSpells or {}
local potion_helper = require("shared/potion_helper_sylvanas")
local Healing = NS.PaladinHealing or require("classes/paladin/healing_sylvanas")
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { ITEMS = { potions = {} } } end
local TBC_POTIONS = (TBC.ITEMS and TBC.ITEMS.potions) or {}

local format = string.format
local EMPTY_OPTS = {}
local SELF_OPTS = { skip_range = true }
local EXPECTED_10S = { expected_cooldown = 10 }
local EXPECTED_300S = { expected_cooldown = 300, skip_range = true }
local EXPECTED_LOH = { expected_cooldown = 3600, skip_range = true }
local EXPECTED_CONSECRATION_SELF = { skip_range = true, expected_cooldown = 8 }

local _last_aura_cast = -100
local AURA_SWITCH_COOLDOWN = 3.0

local function spell_action(ids, label)
    if NS.spell_action then return NS.spell_action(ids, label) end
    return type(ids) == "table" and ids[1] or ids
end

-- Classic Vanilla Holy spells not exposed by the base Paladin class map.
local BlessingOfLight = SPELLS.BlessingOfLight or spell_action({ 19979, 19978, 19977 }, "BlessingOfLight")
local GreaterBlessingOfLight = SPELLS.GreaterBlessingOfLight or spell_action({ 25890 }, "GreaterBlessingOfLight")
local BlessingOfFreedom = SPELLS.BlessingOfFreedom or spell_action({ 1044 }, "BlessingOfFreedom")
local BlessingOfProtection = SPELLS.BlessingOfProtection or spell_action({ 10278, 5599, 1022 }, "BlessingOfProtection")
local BlessingOfSacrifice = SPELLS.BlessingOfSacrifice or spell_action({ 20729, 6940 }, "BlessingOfSacrifice")
local FireResistanceAura = SPELLS.FireResistanceAura or spell_action({ 19900, 19899, 19891 }, "FireResistanceAura")
local FrostResistanceAura = SPELLS.FrostResistanceAura or spell_action({ 19898, 19897, 19888 }, "FrostResistanceAura")
local ShadowResistanceAura = SPELLS.ShadowResistanceAura or spell_action({ 19896, 19895, 19876 }, "ShadowResistanceAura")
local SealOfLight = SPELLS.SealOfLight or spell_action({ 20349, 20348, 20347, 20165 }, "SealOfLight")
local Purify = SPELLS.Purify or spell_action({ 1152 }, "Purify") -- DB2: learned at level 8

local HolyLightRank11 = spell_action({ 25292 }, "HolyLightRank9")
local HolyLightRank9 = spell_action({ 25292 }, "HolyLightRank9")
local HolyLightRank7 = spell_action({ 10328 }, "HolyLightRank7")
local HolyLightRank4 = spell_action({ 1042 }, "HolyLightRank4")
local FlashOfLightRank6 = spell_action({ 19943 }, "FlashOfLightRank6")

local BUFF_DIVINE_FAVOR = { 20216 }
local BUFF_FORBEARANCE = { 25771 }
local BUFF_SEAL_WISDOM = { 20357, 20356, 20166 }
local BUFF_SEAL_LIGHT = { 20349, 20348, 20347, 20165 }
local BUFF_SEAL_RIGHTEOUSNESS = { 20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084, 20154 }
local BUFF_BLESSING_LIGHT = { 19979, 19978, 19977, 25890 }
local BUFF_BLESSING_WISDOM = { 25918, 25894, 25290, 19854, 19853, 19852, 19850, 19742 }
local BUFF_BLESSING_KINGS = { 25898, 20217 }
local BUFF_BLESSING_FREEDOM = { 1044 }
local BUFF_BLESSING_PROTECTION = { 10278, 5599, 1022 }
local BUFF_BLESSING_SACRIFICE = { 20729, 6940 }
local BUFF_DIVINE_SHIELD = { 642, 1020 }
local BUFF_LIGHTS_GRACE = { }
local BUFF_CONCENTRATION_AURA = { 19746 }
local BUFF_DEVOTION_AURA = { 10293, 10292, 1032, 643, 10291, 10290, 465 }
local BUFF_FIRE_RESIST_AURA = { 19900, 19899, 19891 }
local BUFF_FROST_RESIST_AURA = { 19898, 19897, 19888 }
local BUFF_SHADOW_RESIST_AURA = { 19896, 19895, 19876 }
local DEBUFF_JUDGEMENT_LIGHT = { 20343, 20342, 20341, 20185 }
local DEBUFF_JUDGEMENT_WISDOM = { 20355, 20354, 20186 }

local MAGIC_DAMAGE_DEBUFFS = { 10894 }  -- Vanilla SW:P rank 8
local FIRE_DAMAGE_DEBUFFS = { 22959, 10161, 16536 }
local FROST_DAMAGE_DEBUFFS = { 12494, 116, 7321 }
local SHADOW_DAMAGE_DEBUFFS = { }
local ROOT_SNARE_DEBUFFS = { 122, 339, 512, 865, 1022, 116, 1715, 2974, 3409, 3600, 12494 }
local PHYSICAL_FOCUS_DEBUFFS = { 26017, 12809, 25274, 25273 }
local DARK_RUNE_IDS = { 20520, 12662 }

local DEFAULT_SCAN_HP = 96
local EMERGENCY_HP = 25
local LOW_MANA_PCT = 35
local POTION_MANA_PCT = 22
local HEAVY_DAMAGE_COUNT = 3
local HEAVY_TANK_HP = 55
local BLESSING_REFRESH_SEC = 120
local BLESSING_MIN_MANA = 30
local BOSS_HP_FLOOR = 20
local TANK_HEAL_TARGET_HP = 92
local LIGHT_HEAL_DEFICIT = 900
local MEDIUM_HEAL_DEFICIT = 1900
local LARGE_HEAL_DEFICIT = 3200

local state = {
    entries = nil,
    count = 0,
    lowest = nil,
    tank = nil,
    cleanse_target = nil,
    purify_target = nil,
    mana_target = nil,
    freedom_target = nil,
    protection_target = nil,
    sacrifice_target = nil,
    pvp_stun_target = nil,
    aura_spell = nil,
    aura_label = nil,
    blessing_target = nil,
    blessing_spell = nil,
    blessing_label = nil,
    heal_target = nil,
    heal_spell = nil,
    heal_label = nil,
    heal_priority = 0,
    holy_light_spell = nil,
    holy_light_label = nil,
    emergency_count = 0,
    heavy_healing = false,
    use_group_blessings = false,
    in_pvp = false,
    mana_pct = 100,
    hp_pct = 100,
    target_hp_pct = 100,
    moving = false,
    has_divine_favor = false,
    has_forbearance = false,
    has_seal_wisdom = false,
    has_seal_righteousness = false,
    has_concentration_aura = false,
    has_devotion_aura = false,
    has_fire_aura = false,
    has_frost_aura = false,
    has_shadow_aura = false,
    has_lights_grace = false,
    target_has_jol = false,
    target_has_jow = false,
}

local function hp_of(entry, fallback)
    if entry and type(entry.effective_hp) == "number" then return entry.effective_hp end
    if entry and type(entry.hp) == "number" then return entry.hp end
    return fallback or 100
end

local function deficit_of(entry)
    if not entry then return 0 end
    if type(entry.deficit) == "number" then return entry.deficit end
    if type(entry.max_hp) == "number" and type(entry.current_hp) == "number" then
        return entry.max_hp - entry.current_hp
    end
    return 0
end

local function unit_has_buff(unit, ids)
    return unit and NS.buff_up and NS.buff_up(unit, ids) or false
end

local function unit_debuff_remains(unit, ids)
    if not unit or not NS.debuff_remains then return 0 end
    return NS.debuff_remains(unit, ids) or 0
end

local function has_debuff(unit, ids)
    return unit and unit_debuff_remains(unit, ids) > 0 or false
end

local function has_any_debuff(unit, lists)
    if not unit then return false end
    for i = 1, #lists do
        if has_debuff(unit, lists[i]) then return true end
    end
    return false
end

local function can_help(entry)
    if not entry or not entry.unit then return false end
    if entry.is_dead == true or entry.dead == true then return false end
    return true
end

local function can_cast_on(spell, entry)
    return can_help(entry) and NS.spell_ready(spell, entry.unit, EMPTY_OPTS)
end

local function cast_on(spell, entry, reason, opts)
    if not can_help(entry) then return false end
    return NS.try_cast(spell, entry.unit, reason, opts)
end

local function is_self(entry)
    if not entry or not entry.unit then return false end
    return NS.same_unit and NS.same_unit(entry.unit, NS.PLAYER_UNIT) or entry.unit == NS.PLAYER_UNIT
end

local function entry_needs_freedom(entry)
    if not can_help(entry) then return false end
    if unit_has_buff(entry.unit, BUFF_BLESSING_FREEDOM) then return false end
    if has_any_debuff(entry.unit, ROOT_SNARE_DEBUFFS) then return true end
    return entry.is_rooted == true or entry.is_snared == true
end

local function entry_needs_protection(entry, context)
    if not can_help(entry) then return false end
    if unit_has_buff(entry.unit, BUFF_BLESSING_PROTECTION) then return false end
    if hp_of(entry) > 38 then return false end
    if context and context.in_combat == false then return false end
    if has_any_debuff(entry.unit, PHYSICAL_FOCUS_DEBUFFS) then return true end
    return entry.threat_status and entry.threat_status >= 2 or false
end

local function entry_needs_cleanse(entry)
    if not can_help(entry) then return false end
    return entry.needs_cleanse or entry.has_poison or entry.has_disease or entry.has_magic
end

local function entry_is_mana_user(entry)
    if not can_help(entry) then return false end
    if entry.power_type == NS.POWER_MANA then return true end
    if type(entry.mana_pct) == "number" then return true end
    return entry.is_caster == true or entry.role == "healer" or entry.role == "caster"
end

local function should_use_greater_blessing(s)
    return (s.count or 0) >= 5 or s.use_group_blessings
end

local function blessing_remains(entry, ids)
    if not can_help(entry) then return 0 end
    if NS.buff_remains then return NS.buff_remains(entry.unit, ids) or 0 end
    return unit_has_buff(entry.unit, ids) and BLESSING_REFRESH_SEC or 0
end

local function blessing_missing_or_expiring(entry, ids, threshold)
    local remains = blessing_remains(entry, ids)
    return remains <= (threshold or BLESSING_REFRESH_SEC)
end

local function choose_holy_light_rank(context, entry)
    local mode = (context.settings["holy_light_rank"] or NS.get_setting("holy_light_rank", "max") or "max")
    local hp = hp_of(entry)
    local deficit = deficit_of(entry)
    if mode == "rank4" then return HolyLightRank4, "Holy Light R4" end
    if mode == "rank7" then return HolyLightRank7, "Holy Light R7" end
    if mode == "rank9" then return HolyLightRank9, "Holy Light R9" end
    if hp <= EMERGENCY_HP or deficit >= LARGE_HEAL_DEFICIT then return HolyLightRank11, "Holy Light R9" end
    if hp <= 45 or deficit >= MEDIUM_HEAL_DEFICIT then return HolyLightRank9, "Holy Light R9" end
    if hp <= 65 or deficit >= LIGHT_HEAL_DEFICIT then return HolyLightRank7, "Holy Light R7" end
    return HolyLightRank4, "Holy Light R4"
end

local function choose_smart_heal(context, s, entry)
    if not can_help(entry) then return nil end
    local hp = hp_of(entry)
    local deficit = deficit_of(entry)
    local flash_hp = (context.settings["holy_flash_light_hp"] or NS.get_setting("holy_flash_light_hp", 85) or 85)
    local shock_hp = (context.settings["holy_shock_hp"] or NS.get_setting("holy_shock_hp", 40) or 40)
    if (context and context.is_moving or s.moving) and hp <= flash_hp and NS.spell_ready(SPELLS.HolyShock, entry.unit, EMPTY_OPTS) then
        s.heal_spell = SPELLS.HolyShock
        s.heal_label = "Holy Shock moving"
        return SPELLS.HolyShock
    end
    if hp <= shock_hp and NS.spell_ready(SPELLS.HolyShock, entry.unit, EMPTY_OPTS) then
        s.heal_spell = SPELLS.HolyShock
        s.heal_label = "Holy Shock emergency"
        return SPELLS.HolyShock
    end
    -- Light's Grace reduces Holy Light cast time to 2.0s, making it more efficient
    local hl_hp_threshold = s.has_lights_grace and 80 or 70
    if (hp <= hl_hp_threshold or deficit >= LIGHT_HEAL_DEFICIT) and (s.mana_pct or 100) >= LOW_MANA_PCT then
        s.holy_light_spell, s.holy_light_label = choose_holy_light_rank(context, entry)
        s.heal_spell = s.holy_light_spell
        s.heal_label = s.holy_light_label
        return s.heal_spell
    end
    if hp <= flash_hp then
        -- Flash of Light downranking: use rank 6 [25297] for mana conservation < 15%
        if (s.mana_pct or 100) < 15 and NS.spell_ready(FlashOfLightRank6, entry.unit, EMPTY_OPTS) then
            s.heal_spell = FlashOfLightRank6
            s.heal_label = "Flash of Light R6 conserve"
        else
            s.heal_spell = SPELLS.FlashOfLight
            s.heal_label = "Flash of Light"
        end
        return s.heal_spell
    end
    return nil
end

local function choose_blessing(context, s)
    s.blessing_target = nil
    s.blessing_spell = nil
    s.blessing_label = nil
    if (context.settings["holy_refresh_enabled"] or NS.get_setting("holy_refresh_enabled", true) or true) == false then return end
    if (s.mana_pct or 100) < (context.settings["holy_refresh_mana"] or NS.get_setting("holy_refresh_mana", BLESSING_MIN_MANA) or BLESSING_MIN_MANA) then return end
    local threshold = (context.settings["holy_refresh_threshold"] or NS.get_setting("holy_refresh_threshold", BLESSING_REFRESH_SEC) or BLESSING_REFRESH_SEC)
    local use_greater = should_use_greater_blessing(s)

    if (context.settings["holy_blessing_light"] or NS.get_setting("holy_blessing_light", true) or true) ~= false and can_help(s.tank) and blessing_missing_or_expiring(s.tank, BUFF_BLESSING_LIGHT, threshold) then
        s.blessing_target = s.tank
        s.blessing_spell = use_greater and GreaterBlessingOfLight or BlessingOfLight
        s.blessing_label = use_greater and "Greater Blessing of Light" or "Blessing of Light"
        return
    end
    if (context.settings["holy_blessing_wisdom"] or NS.get_setting("holy_blessing_wisdom", true) or true) ~= false then
        for i = 1, s.count do
            local entry = s.entries[i]
            if entry_is_mana_user(entry) and blessing_missing_or_expiring(entry, BUFF_BLESSING_WISDOM, threshold) then
                s.blessing_target = entry
                s.blessing_spell = use_greater and SPELLS.GreaterBlessingOfWisdom or SPELLS.BlessingOfWisdom
                s.blessing_label = use_greater and "Greater Blessing of Wisdom" or "Blessing of Wisdom"
                return
            end
        end
    end
    for i = 1, s.count do
        local entry = s.entries[i]
        if can_help(entry) and blessing_missing_or_expiring(entry, BUFF_BLESSING_KINGS, threshold) then
            s.blessing_target = entry
            s.blessing_spell = use_greater and SPELLS.GreaterBlessingOfKings or SPELLS.BlessingOfKings
            s.blessing_label = use_greater and "Greater Blessing of Kings" or "Blessing of Kings"
            return
        end
    end
end

local function choose_aura(context, s)
    s.aura_spell = nil
    s.aura_label = nil
    if has_any_debuff(NS.PLAYER_UNIT, SHADOW_DAMAGE_DEBUFFS) and not s.has_shadow_aura then
        s.aura_spell = ShadowResistanceAura
        s.aura_label = "Shadow Resistance Aura"
        return
    end
    if has_any_debuff(NS.PLAYER_UNIT, FIRE_DAMAGE_DEBUFFS) and not s.has_fire_aura then
        s.aura_spell = FireResistanceAura
        s.aura_label = "Fire Resistance Aura"
        return
    end
    if has_any_debuff(NS.PLAYER_UNIT, FROST_DAMAGE_DEBUFFS) and not s.has_frost_aura then
        s.aura_spell = FrostResistanceAura
        s.aura_label = "Frost Resistance Aura"
        return
    end
    if s.heavy_healing and not s.has_concentration_aura then
        s.aura_spell = SPELLS.ConcentrationAura
        s.aura_label = "Concentration Aura"
        return
    end
    if not s.has_devotion_aura and not s.has_concentration_aura then
        s.aura_spell = SPELLS.DevotionAura
        s.aura_label = "Devotion Aura"
    end
end

local function item_ready(item_id)
    if NS.is_item_ready then return NS.is_item_ready(item_id) end
    return true
end

local function try_use_item(item_ids, reason)
    if not NS.use_item_by_id then return false end
    for i = 1, #item_ids do
        local item_id = item_ids[i]
        if item_ready(item_id) and NS.use_item_by_id(item_id) then
            return true
        end
    end
    return false
end

local function build_state(context)
    -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
    local skip_aura = NS.broken_api_throttled and NS.broken_api_throttled(20216, 3.0) or false
    local entries, count = Healing.scan_healing_targets()
    state.entries = entries
    state.count = count or 0
    state.lowest = NS.healing_get_lowest_hp(entries, count, DEFAULT_SCAN_HP)
    state.tank = NS.healing_get_tank(entries, count)
    state.cleanse_target = nil
    state.purify_target = nil
    state.mana_target = nil
    state.freedom_target = nil
    state.protection_target = nil
    state.sacrifice_target = nil
    state.pvp_stun_target = nil
    state.heal_target = nil
    state.heal_spell = nil
    state.heal_label = nil
    state.heal_priority = 0
    state.holy_light_spell = nil
    state.holy_light_label = nil
    state.emergency_count = 0
    state.mana_pct = context and context.mana_pct or NS.mana_pct and NS.mana_pct(NS.GetPlayer()) or 100
    state.hp_pct = context and context.hp or NS.unit_health_pct and NS.unit_health_pct(NS.GetPlayer()) or 100
    state.target_hp_pct = context and context.target_hp or NS.unit_health_pct and NS.unit_health_pct(context and context.target) or 100
    state.moving = context and context.is_moving or false
    state.in_pvp = NS.is_pvp_zone and NS.is_pvp_zone() or context and context.is_pvp or false
    state.use_group_blessings = state.count >= 5
    if not skip_aura then
        state.has_divine_favor = NS.has_player_buff(BUFF_DIVINE_FAVOR)
        state.has_forbearance = NS.has_player_debuff and NS.has_player_debuff(BUFF_FORBEARANCE) or NS.has_player_buff(BUFF_FORBEARANCE)
        state.has_seal_wisdom = NS.has_player_buff(BUFF_SEAL_WISDOM)
        state.has_seal_light = NS.has_player_buff(BUFF_SEAL_LIGHT)
        state.has_seal_righteousness = NS.has_player_buff(BUFF_SEAL_RIGHTEOUSNESS)
        state.has_concentration_aura = NS.has_player_buff(BUFF_CONCENTRATION_AURA)
        state.has_devotion_aura = NS.has_player_buff(BUFF_DEVOTION_AURA)
        state.has_fire_aura = NS.has_player_buff(BUFF_FIRE_RESIST_AURA)
        state.has_frost_aura = NS.has_player_buff(BUFF_FROST_RESIST_AURA)
        state.has_shadow_aura = NS.has_player_buff(BUFF_SHADOW_RESIST_AURA)
        state.has_lights_grace = NS.has_player_buff(BUFF_LIGHTS_GRACE)
        state.target_has_jol = context and context.target and has_debuff(context.target, DEBUFF_JUDGEMENT_LIGHT) or false
        state.target_has_jow = context and context.target and has_debuff(context.target, DEBUFF_JUDGEMENT_WISDOM) or false
    end

    for i = 1, state.count do
        local entry = entries[i]
        if can_help(entry) then
            local hp = hp_of(entry)
            if hp < 40 then state.emergency_count = state.emergency_count + 1 end
            if not state.cleanse_target and entry_needs_cleanse(entry) then state.cleanse_target = entry end
            if not state.purify_target and is_self(entry) and (entry.has_poison or entry.has_disease) then state.purify_target = entry end
            if not state.freedom_target and entry_needs_freedom(entry) then state.freedom_target = entry end
            if not state.protection_target and entry_needs_protection(entry, context) then state.protection_target = entry end
            if not state.mana_target and entry_is_mana_user(entry) then state.mana_target = entry end
        end
    end

    if can_help(state.tank) and hp_of(state.tank) <= HEAVY_TANK_HP then state.sacrifice_target = state.tank end
    state.heavy_healing = state.emergency_count >= HEAVY_DAMAGE_COUNT or hp_of(state.tank) <= HEAVY_TANK_HP
    choose_blessing(context, state)
    choose_aura(context, state)
    state.heal_target = state.lowest or state.tank
    if can_help(state.heal_target) then choose_smart_heal(context, state, state.heal_target) end
    return state
end

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

local function solo_damage_enabled(context, s)
    if not has_valid_enemy(context) then return false end
    local settings = context and context.settings or {}
    if not (context.is_solo == true or context.is_leveling == true or settings.holy_dps_when_idle == true) then return false end
    local safe_hp = settings.holy_idle_hp or 88
    if s and can_help(s.lowest) and hp_of(s.lowest) < safe_hp then return false end
    if s and (s.mana_pct or 100) < (settings.holy_dps_mana_floor or 35) then return false end
    return true
end

local function cast_judgement(context, label)
    return NS.try_cast(SPELLS.Judgement, context.target, label, EXPECTED_10S)
end

local strategies = {
    {
        name = "LayOnHandsLastResort",
        matches = function(context, s)
            if not can_help(s.lowest) then return false end
            if hp_of(s.lowest) > 12 then return false end
            return NS.spell_ready(SPELLS.LayOnHands, s.lowest.unit, EXPECTED_LOH)
        end,
        execute = function(_, s)
            return cast_on(SPELLS.LayOnHands, s.lowest, format("[HOLY] Lay on Hands last resort %.0f%%", hp_of(s.lowest)), EXPECTED_LOH)
        end,
    },
    {
        name = "DivineShieldSelfPreservation",
        matches = function(context, s)
            if (s.hp_pct or 100) > 18 or s.has_forbearance then return false end
            return NS.spell_ready(SPELLS.DivineShield, NS.PLAYER_UNIT, EXPECTED_300S)
        end,
        execute = function()
            return NS.try_cast(SPELLS.DivineShield, NS.PLAYER_UNIT, "[HOLY] Divine Shield self-preservation", EXPECTED_300S)
        end,
    },
    {
        name = "BlessingOfProtectionFocusedAlly",
        matches = function(_, s)
            return can_cast_on(BlessingOfProtection, s.protection_target)
        end,
        execute = function(_, s)
            return cast_on(BlessingOfProtection, s.protection_target, "[HOLY] Blessing of Protection focused ally")
        end,
    },
    {
        name = "CleanseTankPriority",
        matches = function(context, s)
            if (context.settings["holy_auto_cleanse"] or NS.get_setting("holy_auto_cleanse", true) or true) == false then return false end
            if not entry_needs_cleanse(s.tank) then return false end
            return can_cast_on(SPELLS.Cleanse, s.tank)
        end,
        execute = function(_, s)
            return cast_on(SPELLS.Cleanse, s.tank, "[HOLY] Cleanse tank")
        end,
    },
    {
        name = "PurifySelf",
        matches = function(context, s)
            if (context.settings["holy_auto_cleanse"] or NS.get_setting("holy_auto_cleanse", true) or true) == false then return false end
            return can_cast_on(Purify, s.purify_target)
        end,
        execute = function(_, s)
            return cast_on(Purify, s.purify_target, "[HOLY] Purify self")
        end,
    },
    {
        name = "CleanseParty",
        matches = function(context, s)
            if (context.settings["holy_auto_cleanse"] or NS.get_setting("holy_auto_cleanse", true) or true) == false then return false end
            return can_cast_on(SPELLS.Cleanse, s.cleanse_target)
        end,
        execute = function(_, s)
            return cast_on(SPELLS.Cleanse, s.cleanse_target, "[HOLY] Cleanse ally")
        end,
    },
    {
        name = "BlessingOfFreedomSnare",
        matches = function(_, s)
            return can_cast_on(BlessingOfFreedom, s.freedom_target)
        end,
        execute = function(_, s)
            return cast_on(BlessingOfFreedom, s.freedom_target, "[HOLY] Blessing of Freedom snare/root")
        end,
    },
    {
        name = "DivineFavor",
        matches = function(context, s)
            local target = s.lowest or s.tank
            if not can_help(target) or s.has_divine_favor then return false end
            if hp_of(target) > (context.settings["holy_divine_favor_hp"] or NS.get_setting("holy_divine_favor_hp", 45) or 45) then return false end
            return NS.spell_ready(SPELLS.DivineFavor, NS.PLAYER_UNIT, SELF_OPTS)
        end,
        execute = function()
            return NS.try_cast(SPELLS.DivineFavor, NS.PLAYER_UNIT, "[HOLY] Divine Favor before critical Holy Light", SELF_OPTS)
        end,
    },
    {
        name = "HolyShock",
        matches = function(context, s)
            if not can_help(s.lowest) then return false end
            local moving = s.moving or context and context.is_moving
            if hp_of(s.lowest) > (context.settings["holy_shock_hp"] or NS.get_setting("holy_shock_hp", 40) or 40) and not moving then return false end
            return NS.spell_ready(SPELLS.HolyShock, s.lowest.unit, EMPTY_OPTS)
        end,
        execute = function(_, s)
            return cast_on(SPELLS.HolyShock, s.lowest, format("[HOLY] Holy Shock %.0f%%", hp_of(s.lowest)))
        end,
    },
    {
        name = "HolyLightEmergency",
        matches = function(context, s)
            if not can_help(s.lowest) or hp_of(s.lowest) > 55 then return false end
            s.holy_light_spell, s.holy_light_label = choose_holy_light_rank(context, s.lowest)
            return NS.spell_ready(s.holy_light_spell, s.lowest.unit, EMPTY_OPTS)
        end,
        execute = function(_, s)
            return cast_on(s.holy_light_spell, s.lowest, format("[HOLY] %s emergency %.0f%%", s.holy_light_label, hp_of(s.lowest)))
        end,
    },
    {
        name = "DivineFavorHolyLightFollowup",
        matches = function(context, s)
            if not s.has_divine_favor or not can_help(s.lowest) then return false end
            s.holy_light_spell, s.holy_light_label = choose_holy_light_rank(context, s.lowest)
            return NS.spell_ready(s.holy_light_spell, s.lowest.unit, EMPTY_OPTS)
        end,
        execute = function(_, s)
            return cast_on(s.holy_light_spell, s.lowest, format("[HOLY] %s guaranteed crit %.0f%%", s.holy_light_label, hp_of(s.lowest)))
        end,
    },
    {
        name = "FriendlyTarget",
        matches = function(context, s)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            if context.settings.holy_use_friendly_target == false then return false end
            local threshold = (context.settings and context.settings.holy_friendly_target_threshold) or 90
            local ft = NS.get_friendly_target_entry(context)
            if not ft or not ft.unit then return false end
            if (ft.hp_pct or 100) >= threshold then return false end
            if not can_help(s.lowest) or hp_of(s.lowest) <= EMERGENCY_HP then return false end
            s.holy_light_spell, s.holy_light_label = choose_holy_light_rank(context, ft)
            return can_cast_on(s.holy_light_spell, ft)
        end,
        execute = function(context, s)
            local ft = NS.get_friendly_target_entry(context)
            if not ft then return false end
            return cast_on(s.holy_light_spell, ft, format("[HOLY] %s ft %.0f%%", s.holy_light_label, hp_of(ft)))
        end,
    },
    {
        name = "BlessingOfSacrificeTank",
        matches = function(_, s)
            if not can_help(s.sacrifice_target) then return false end
            if unit_has_buff(s.sacrifice_target.unit, BUFF_BLESSING_SACRIFICE) then return false end
            return NS.spell_ready(BlessingOfSacrifice, s.sacrifice_target.unit, EMPTY_OPTS)
        end,
        execute = function(_, s)
            return cast_on(BlessingOfSacrifice, s.sacrifice_target, "[HOLY] Blessing of Sacrifice on tank")
        end,
    },
    {
        name = "ManaPotion",
        matches = function(_, s)
            return (s.mana_pct or 100) <= POTION_MANA_PCT
        end,
        execute = function(context)
            return potion_helper.try_use_potion(context, potion_helper.MANA_POTION_IDS)
        end,
    },
    {
        name = "DarkRune",
        matches = function(_, s)
            return (s.mana_pct or 100) <= 18 and (s.hp_pct or 100) > 45
        end,
        execute = function()
            return try_use_item(DARK_RUNE_IDS, "[HOLY] Dark Rune")
        end,
    },
    {
        name = "AuraManagement",
        matches = function(_, s)
            local now = NS.time_now and NS.time_now() or 0
            if now - _last_aura_cast < AURA_SWITCH_COOLDOWN then return false end
            return s.aura_spell and NS.spell_ready(s.aura_spell, NS.PLAYER_UNIT, SELF_OPTS)
        end,
        execute = function(_, s)
            local ok = NS.try_cast(s.aura_spell, NS.PLAYER_UNIT, "[HOLY] " .. s.aura_label, SELF_OPTS)
            if ok then _last_aura_cast = NS.time_now and NS.time_now() or 0 end
            return ok
        end,
    },
    {
        name = "BlessingRefresh",
        matches = function(_, s)
            return s.blessing_spell and can_cast_on(s.blessing_spell, s.blessing_target)
        end,
        execute = function(_, s)
            return cast_on(s.blessing_spell, s.blessing_target, "[HOLY] " .. s.blessing_label)
        end,
    },
    {
        name = "BlessingOfLightTank",
        matches = function(context, s)
            if (context.settings["holy_blessing_light"] or NS.get_setting("holy_blessing_light", true) or true) == false then return false end
            if not can_help(s.tank) or not blessing_missing_or_expiring(s.tank, BUFF_BLESSING_LIGHT, BLESSING_REFRESH_SEC) then return false end
            return NS.spell_ready(BlessingOfLight, s.tank.unit, EMPTY_OPTS)
        end,
        execute = function(_, s)
            return cast_on(BlessingOfLight, s.tank, "[HOLY] Blessing of Light tank")
        end,
    },
    {
        name = "TankPreHeal",
        matches = function(context, s)
            if not can_help(s.tank) or hp_of(s.tank) > TANK_HEAL_TARGET_HP then return false end
            s.heal_target = s.tank
            return choose_smart_heal(context, s, s.tank) and NS.spell_ready(s.heal_spell, s.tank.unit, EMPTY_OPTS)
        end,
        execute = function(_, s)
            return cast_on(s.heal_spell, s.tank, format("[HOLY] %s tank %.0f%%", s.heal_label, hp_of(s.tank)))
        end,
    },
    {
        name = "SmartHeal",
        matches = function(context, s)
            local target = s.heal_target or s.lowest or s.tank
            if not can_help(target) then return false end
            s.heal_target = target
            return choose_smart_heal(context, s, target) and NS.spell_ready(s.heal_spell, target.unit, EMPTY_OPTS)
        end,
        execute = function(_, s)
            return cast_on(s.heal_spell, s.heal_target, format("[HOLY] %s %.0f%%", s.heal_label, hp_of(s.heal_target)))
        end,
    },
    {
        name = "FlashOfLightEfficientTopoff",
        matches = function(context, s)
            if not can_help(s.lowest) then return false end
            if hp_of(s.lowest) > (context.settings["holy_flash_light_hp"] or NS.get_setting("holy_flash_light_hp", 85) or 85) then return false end
            return NS.spell_ready(SPELLS.FlashOfLight, s.lowest.unit, EMPTY_OPTS)
        end,
        execute = function(_, s)
            return cast_on(SPELLS.FlashOfLight, s.lowest, format("[HOLY] Flash of Light efficient %.0f%%", hp_of(s.lowest)))
        end,
    },
    {
        name = "SealOfWisdomLowMana",
        matches = function(_, s)
            if (s.mana_pct or 100) > LOW_MANA_PCT or s.has_seal_wisdom then return false end
            return NS.spell_ready(SPELLS.SealOfWisdom, NS.PLAYER_UNIT, SELF_OPTS)
        end,
        execute = function(_, s)
            return NS.try_cast(SPELLS.SealOfWisdom, NS.PLAYER_UNIT, format("[HOLY] Seal of Wisdom mana %.0f%%", s.mana_pct), SELF_OPTS)
        end,
    },
    {
        name = "JudgementOfWisdomBoss",
        matches = function(context, s)
            if not has_valid_enemy(context) or s.target_has_jow then return false end
            if (s.mana_pct or 100) > LOW_MANA_PCT and (s.target_hp_pct or 100) < BOSS_HP_FLOOR then return false end
            return s.has_seal_wisdom and NS.spell_ready(SPELLS.Judgement, context.target, EXPECTED_10S)
        end,
        execute = function(context)
            return cast_judgement(context, "[HOLY] Judgement of Wisdom")
        end,
    },
    {
        name = "SealOfLightBoss",
        matches = function(context, s)
            if not has_valid_enemy(context) or s.target_has_jol or s.has_seal_light then return false end
            if (s.mana_pct or 100) < LOW_MANA_PCT then return false end
            if (s.target_hp_pct or 100) < BOSS_HP_FLOOR then return false end
            return NS.spell_ready(SealOfLight, NS.PLAYER_UNIT, SELF_OPTS)
        end,
        execute = function()
            return NS.try_cast(SealOfLight, NS.PLAYER_UNIT, "[HOLY] Seal of Light support", SELF_OPTS)
        end,
    },
    {
        name = "JudgementOfLightBoss",
        matches = function(context, s)
            if not has_valid_enemy(context) or s.target_has_jol or (s.mana_pct or 100) < LOW_MANA_PCT then return false end
            if (s.target_hp_pct or 100) < BOSS_HP_FLOOR then return false end
            return s.has_seal_light and NS.spell_ready(SPELLS.Judgement, context.target, EXPECTED_10S)
        end,
        execute = function(context)
            return cast_judgement(context, "[HOLY] Judgement of Light support")
        end,
    },
    {
        name = "HammerOfJusticeDiver",
        matches = function(context, s)
            if not s.in_pvp and (s.hp_pct or 100) > 55 then return false end
            if not has_valid_enemy(context) then return false end
            if NS.unit_distance and NS.unit_distance(context.target, context.me) > 10 then return false end
            return NS.spell_ready(SPELLS.HammerOfJustice, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.HammerOfJustice, context.target, "[HOLY] Hammer of Justice on diver")
        end,
    },
    {
        name = "SealOfRighteousnessSolo",
        matches = function(context, s)
            if not solo_damage_enabled(context, s) or s.has_seal_righteousness then return false end
            return NS.spell_ready(SPELLS.SealRighteousness, NS.PLAYER_UNIT, SELF_OPTS)
        end,
        execute = function()
            return NS.try_cast(SPELLS.SealRighteousness, NS.PLAYER_UNIT, "[HOLY] Solo Seal of Righteousness", SELF_OPTS)
        end,
    },
    {
        name = "HammerOfWrathSolo",
        matches = function(context, s)
            if not solo_damage_enabled(context, s) or (s.target_hp_pct or 100) > 20 then return false end
            return NS.spell_ready(SPELLS.HammerOfWrath, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.HammerOfWrath, context.target, "[HOLY] Solo Hammer of Wrath")
        end,
    },
    {
        name = "HolyShockSoloDamage",
        matches = function(context, s)
            if not solo_damage_enabled(context, s) then return false end
            if (s.mana_pct or 100) < 45 and context.is_leveling then return false end
            return NS.spell_ready(SPELLS.HolyShock, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.HolyShock, context.target, "[HOLY] Solo Holy Shock")
        end,
    },
    {
        name = "JudgementSoloRighteousness",
        matches = function(context, s)
            if not solo_damage_enabled(context, s) or not s.has_seal_righteousness then return false end
            return NS.spell_ready(SPELLS.Judgement, context.target, EXPECTED_10S)
        end,
        execute = function(context)
            return cast_judgement(context, "[HOLY] Solo Judgement")
        end,
    },
    {
        name = "ConsecrationSoloAoE",
        matches = function(context, s)
            if context.is_moving then return false end
            if not solo_damage_enabled(context, s) then return false end
            if (context.enemy_count or context.enemies_count or 1) < 2 then return false end
            return NS.spell_ready(SPELLS.Consecration, NS.PLAYER_UNIT, EXPECTED_CONSECRATION_SELF)
        end,
        execute = function()
            return NS.try_cast(SPELLS.Consecration, NS.PLAYER_UNIT, "[HOLY] Solo Consecration", EXPECTED_CONSECRATION_SELF)
        end,
    },
    {
        name = "SealOfRighteousnessIdle",
        matches = function(context, s)
            if not has_valid_enemy(context) or s.has_seal_righteousness or (s.mana_pct or 100) < 45 then return false end
            return NS.spell_ready(SPELLS.SealRighteousness, NS.PLAYER_UNIT, SELF_OPTS)
        end,
        execute = function()
            return NS.try_cast(SPELLS.SealRighteousness, NS.PLAYER_UNIT, "[HOLY] Seal of Righteousness idle", SELF_OPTS)
        end,
    },
}

NS.rotation_registry:register("holy", strategies, { get_state = build_state })
NS.log("Paladin holy rotation registered (deep Classic Vanilla healing/buff utility)")
return strategies

