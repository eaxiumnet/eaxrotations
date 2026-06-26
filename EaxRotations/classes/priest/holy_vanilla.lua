-- holy_vanilla.lua — Priest Holy healing rotation for Vanilla/Classic Era.
-- WHAT:  healing rotation (Renew, Flash Heal, Greater Heal, Prayer of Healing).
-- WHEN:  combat or pre-hot, when NS.is_vanilla() is true.
-- WHY:   expansion-aware loader selects _vanilla suffix for Classic Era.
-- SAFETY: nil-guards on NS, SPELLS, and player class check; early return if not priest.

local _G = _G
local NS = _G.EaxRotations
if not NS then return nil end

local load_player = NS.GetPlayer and NS.GetPlayer()

local _ok_enums, enums = pcall(require, "common/enums")
if not _ok_enums or type(enums) ~= "table" or type(enums.class_id) ~= "table" then enums = { class_id = NS.CLASS_ID } end
if not load_player then return end
local ok_cls, cls_id = pcall(function() return load_player:get_class() end)
if not ok_cls or cls_id ~= enums.class_id.PRIEST then return end

local SPELLS = NS.PriestSpells

local function load_healing_helpers()
    if NS.PriestHealing then return NS.PriestHealing end
    local ok, module = pcall(require, "classes/priest/healing_sylvanas")
    if ok then
        return module or NS.PriestHealing or {}
    end
    if NS.log_warning then
        NS.log_warning("Failed to load Priest healing helpers: " .. tostring(module))
    end
    return NS.PriestHealing or {}
end

local Healing = load_healing_helpers()

local format = string.format
-- ipairs unused in holy (no ipairs iteration needed)
local tostring = tostring
local EMPTY_SETTINGS = {}

-- ============================================================================
-- IMPORT SHARED RANK TABLES + UTILITIES (from class_sylvanas.lua)
-- class_sylvanas.lua loads at order=61, holy at order=66 ? safe to import.
-- ============================================================================
local FLASH_HEAL_RANKS = NS.PriestFLASH_HEAL_RANKS
local GREATER_HEAL_RANKS = NS.PriestGREATER_HEAL_RANKS
local PRAYER_OF_HEALING_RANKS = NS.PriestPRAYER_OF_HEALING_RANKS
local BINDING_HEAL_RANKS = NS.PriestBINDING_HEAL_RANKS
local cast_best_heal_rank = NS.cast_best_heal_rank or function() return false end

local INNER_FOCUS_BUFF = 14751
-- Surge of Light (33151) and Holy Concentration (34753/34859) are TBC-only talents.
local SHADOW_WORD_PAIN_DEBUFF = { 10894, 10893, 10892, 2767, 992, 970, 594, 589 }
local HOLY_FIRE_DOT_DEBUFF = { 15261, 15267, 15266, 15265, 15264, 15263, 15262, 14914 }

-- parity feature constants
-- ============================================================================
-- Fade buff IDs (all ranks)
local FADE_BUFF = { 10942, 10941, 9592, 9579, 9578, 586 }

-- Healthstone item IDs (TBC, best to worst)
local HEALTHSTONE_IDS = (TBC and TBC.ITEMS and TBC.ITEMS.healthstones) or { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }

-- Karazhan encounter map ID
local KARAZHAN_MAP_ID = 532

-- Pushback detection for Greater Heal (parity v0.5.0 style)
-- Tracks recent damage taken to gate long-cast heals during pushback
--- Checks if the player is taking damage or in pushback using available API.
--- Uses fallback detection when standard enemy scanner isn't exposed.
---@param context table The combat context.
---@return boolean has_pushback True if pushback is likely active.
local function _check_pushback(context)
    if not (context and context.me) then return false end
    local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(8) or {}
    for _, enemy in ipairs(enemies) do
        if enemy then
            local ok, is_casting = pcall(function() return enemy:is_casting() end)
            if ok and is_casting then return true end
            local ok2, can_atk = pcall(function()
                if context.me.can_attack then return enemy:can_attack(context.me) end
                return false
            end)
            if ok2 and can_atk then return true end
        end
    end
    return false
end

-- [PRE-ALLOC] Heal rank option tables ? created once at load time, not per-frame in execute().
-- Avoids Lua 5.1 GC pressure from repeated inline table creation in combat path.
local HOLY_OPTS_EMERGENCY_FH = { prioritize_speed = true, cast_time = 1.5, overheal_threshold = 1.4 }
local HOLY_OPTS_BH = { bh_coefficient = true, cast_time = 2.0, overheal_threshold = 1.3 }
local HOLY_OPTS_CLEARCAST_GH = { prioritize_efficiency = true, gh_coefficient = true, cast_time = 2.5, overheal_threshold = 1.3 }
local HOLY_OPTS_GH = { gh_coefficient = true, cast_time = 2.5, overheal_threshold = 1.3 }
local HOLY_OPTS_FH = { cast_time = 1.5, overheal_threshold = 1.3 }
local HOLY_OPTS_POH = { poh_coefficient = true, cast_time = 3.0, overheal_threshold = 1.3 }

local holy_state = {
    lowest = nil,
    lowest_hp = 100,
    tank = nil,
    tank_hp = 100,
    group_damaged_count = 0,
    surge_of_light = false,
    clearcasting = false,
    pom_ready = false,
    coh_ready = false,
    has_inner_focus = false,
    swp_remaining = 0,
    holy_fire_remaining = 0,
    -- parity feature state
    healthstone_ready = false,
    healthstone_id = nil,
    has_fade_buff = false,
    fade_ready = false,
    encounter_id = 0,
    lightwell_ready = false,
    dispel_magic_ready = false,
    cure_disease_ready = false,
    abolish_disease_ready = false,
}
-- Shared helpers from core_sylvanas.lua
local try_cast, spell_exists, spell_ready, debuff_remains, health_pct, player_control_locked, has_player_buff = NS.import_helpers(
    "try_cast", "spell_exists", "spell_ready", "debuff_remains", "health_pct",
    "player_control_locked", "has_player_buff"
)
local function build_holy_state(context)
    context.settings = context.settings or EMPTY_SETTINGS
    local aoe_hp = context.settings.holy_aoe_hp or 80
    local lowest_entry = nil
    local tank_entry = nil
    local lowest_hp = 100
    local tank_hp = 100
    local damaged_count = 0

    local player = NS.GetPlayer()
    if not player then return holy_state end
    -- Mounted bail: healer should not queue buffs/heals while mounted
    if player.is_mounted and player:is_mounted() then
        return holy_state
    end
    context.player_control_locked = player_control_locked()
    context.is_moving = context.is_moving or (player.is_moving and player:is_moving()) or false
    context.hp = health_pct(NS.PLAYER_UNIT)
    context.mana_pct = context.player_mana_pct or (player.mana_pct and player:mana_pct()) or 100

    if Healing.scan_healing_targets then
        local entries, count = Healing.scan_healing_targets()
        if entries and count and count > 0 then
            lowest_entry = entries[1]
            lowest_hp = (lowest_entry and lowest_entry.effective_hp) or 100

            for i = 1, count do
                local entry = entries[i]
                if entry and entry.effective_hp and entry.effective_hp < aoe_hp then
                    damaged_count = damaged_count + 1
                end
                if entry and entry.is_tank and (not tank_entry or (entry.effective_hp or 100) < tank_hp) then
                    tank_entry = entry
                    tank_hp = entry.effective_hp or 100
                end
            end
        end
    end

    holy_state.lowest = lowest_entry
    holy_state.lowest_hp = lowest_hp
    holy_state.tank = tank_entry
    holy_state.tank_hp = tank_hp
    holy_state.group_damaged_count = damaged_count
    -- Subgroup count for Prayer of Healing: in raids, only count your own party
    if Healing.count_subgroup_below_hp then
        holy_state.subgroup_damaged_count = Healing.count_subgroup_below_hp(aoe_hp)
    else
        holy_state.subgroup_damaged_count = damaged_count
    end
    holy_state.surge_of_light = false  -- TBC-only talent
    holy_state.clearcasting = false    -- TBC-only talent
    -- parity: Healthstone scanning
    holy_state.healthstone_id = nil
    holy_state.healthstone_ready = false
    if NS.is_item_ready then
        for _, id in ipairs(HEALTHSTONE_IDS) do
            local ok, ready = pcall(NS.is_item_ready, id)
            if ok and ready then
                holy_state.healthstone_id = id
                holy_state.healthstone_ready = true
                break
            end
        end
    end

    -- parity: Fade state
    holy_state.has_fade_buff = has_player_buff(FADE_BUFF)
    holy_state.fade_ready = spell_exists(SPELLS.Fade) and spell_ready(SPELLS.Fade)

    -- parity: Encounter ID for Karazhan reactions
    holy_state.encounter_id = (NS.core and NS.core.get_map_id and NS.core.get_map_id())
        or (core and core.get_map_id and core.get_map_id())
        or 0

    holy_state.pom_ready = false  -- Prayer of Mending is TBC-only
    holy_state.coh_ready = false  -- Circle of Healing is TBC-only
    holy_state.has_inner_focus = has_player_buff(INNER_FOCUS_BUFF)
    -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
    local skip_aura = NS.broken_api_throttled and NS.broken_api_throttled(14752, 3.0) or false
    if not skip_aura then
        holy_state.swp_remaining = context.target and debuff_remains(context.target, SHADOW_WORD_PAIN_DEBUFF) or 0
        holy_state.holy_fire_remaining = context.target and debuff_remains(context.target, HOLY_FIRE_DOT_DEBUFF) or 0
    end
    holy_state.lightwell_ready = spell_exists(SPELLS.Lightwell) and spell_ready(SPELLS.Lightwell, NS.PLAYER_UNIT)
    holy_state.dispel_magic_ready = spell_exists(SPELLS.DispelMagic) and spell_ready(SPELLS.DispelMagic, (lowest_entry and lowest_entry.unit) or NS.PLAYER_UNIT)
    holy_state.cure_disease_ready = spell_exists(SPELLS.CureDisease) and spell_ready(SPELLS.CureDisease, (lowest_entry and lowest_entry.unit) or NS.PLAYER_UNIT)
    holy_state.abolish_disease_ready = spell_exists(SPELLS.AbolishDisease) and spell_ready(SPELLS.AbolishDisease, (lowest_entry and lowest_entry.unit) or NS.PLAYER_UNIT)

    return holy_state
end

local function holy_idle_damage_enabled(context)
    local settings = context and context.settings or EMPTY_SETTINGS
    if settings.holy_dps_when_idle == true then return true end
    return context and (context.is_solo == true or context.is_leveling == true)
end

-- ============================================================================
-- parity Feature: StopCast
-- Mid-cast cancellation: if a higher-priority target emerges during a long cast,
-- interrupt the current cast to switch to the higher-priority target.
-- ============================================================================
local function stop_cast_matches(context, state)
    if not context.in_combat then return false end
    if context.player_control_locked then return false end
    -- Only fire if player is currently casting
    if not context.me then return false end
    local ok, is_casting = pcall(function() return context.me:is_casting() end)
    if not ok or not is_casting then return false end
    -- Someone is critically low and we're casting something else ? interrupt
    if not state.lowest then return false end
    if state.lowest_hp < 30 then
        return true
    end
    -- If tank dropped below safe zone during cast, stop and heal them
    if state.tank and state.tank_hp < 50 then
        return true
    end
    return false
end

-- ============================================================================
-- parity Feature: PreHeal
-- Pre-cast Greater Heal when tank is about to take predictable damage.
-- Timed to land just after the damage hits.
-- ============================================================================
local function pre_heal_matches(context, state)
    if not context.in_combat then return false end
    if context.player_control_locked or context.is_moving then return false end
    if not state.tank then return false end
    -- Tank HP should be in the "pre-heal" range: healthy enough to survive
    -- the cast, but damage is incoming
    if state.tank_hp < 60 or state.tank_hp > 95 then return false end
    -- Check for incoming damage: enemy casting
    if not _check_pushback(context) then return false end
    -- Don't pre-heal if already casting
    if context.me then
        local ok, casting = pcall(function() return context.me:is_casting() end)
        if ok and casting then return false end
    end
    return spell_exists(SPELLS.GreaterHeal) and spell_ready(SPELLS.GreaterHeal, state.tank.unit)
end

-- ============================================================================
-- parity Feature: Fade
-- Auto-use Fade when player has aggro and Fade is ready.
-- ============================================================================
local function fade_matches(context, state)
    if not context.in_combat then return false end
    if context.player_control_locked then return false end
    if state.has_fade_buff then return false end
    if not state.fade_ready then return false end
    -- Check if enemies are targeting the player
    local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(20) or {}
    for _, enemy in ipairs(enemies) do
        if enemy and enemy.is_valid and enemy:is_valid() and enemy.is_alive and enemy:is_alive() then
            local ok, target = pcall(function() return enemy:get_target() end)
            if ok and target and context.me and NS.same_unit(target, context.me) then
                return true
            end
        end
    end
    return false
end

-- ============================================================================
-- parity Feature: Healthstone
-- Auto-use healthstone below HP threshold, off-GCD.
-- ============================================================================
local function healthstone_matches_parity(context, state)
    if not state.healthstone_ready then return false end
    local hs_hp = (context.settings and context.settings.holy_healthstone_hp) or 35
    if context.hp > hs_hp then return false end
    return true
end

-- ============================================================================
-- parity Feature: MountedProtection
-- Safety net: prevent actions while mounted.
-- build_holy_state returns early when mounted, but this strategy acts as
-- an additional guard at the strategy evaluation level.
-- ============================================================================
local function mounted_protection_matches(context, state)
    if not context.me then return false end
    -- build_holy_state already returns early when mounted (state is empty),
    -- so other strategies won't fire. This is a named safety net.
    if context.me.is_mounted and context.me:is_mounted() then
        return true
    end
    return false
end

-- ============================================================================
-- parity Feature: EncounterReactions
-- React to specific Karazhan encounter mechanics:
-- Netherspite: avoid long casts during Nether Breath
-- Maiden: cleanse/heal through Repentance
-- Moroes: heal Garrote targets quickly
-- ============================================================================
local function encounter_reactions_matches(context, state)
    if not context.in_combat then return false end
    if state.encounter_id ~= KARAZHAN_MAP_ID then return false end
    -- Netherspite: player control locked (Nether Breath fear) ? dispel/prepare
    if context.player_control_locked then
        return state.tank_hp < 80
    end
    -- Maiden / Moroes: tank taking heavy damage
    if state.tank and state.tank_hp < 45 then
        return true
    end
    return false
end

local strategies = {
    {
        name = "EmergencyPWS",
        matches = function(context, state)
            if context.player_control_locked then return false end
            if context.settings.holy_use_pws == false then return false end
            -- Tank-only gate: when disc_shield_tank_only is set, only shield the tank
            if context.settings.disc_shield_tank_only then
                if not state.tank then return false end
                if state.tank.effective_hp > (context.settings.holy_pws_hp or 30) then return false end
                if state.tank.has_weakened_soul then return false end
                return spell_exists(SPELLS.PowerWordShield) and spell_ready(SPELLS.PowerWordShield, state.tank.unit)
            end
            if not state.lowest then return false end
            if state.lowest.effective_hp > (context.settings.holy_pws_hp or 30) then return false end
            if state.lowest.has_weakened_soul then return false end
            return spell_exists(SPELLS.PowerWordShield) and spell_ready(SPELLS.PowerWordShield, state.lowest.unit)
        end,
        execute = function(context, state)
            if context.settings.disc_shield_tank_only and state.tank then
                return try_cast(SPELLS.PowerWordShield, state.tank.unit, format("[HOLY] Emergency PW:S Tank %.0f%%", state.tank.effective_hp or 0))
            end
            return try_cast(SPELLS.PowerWordShield, state.lowest.unit, format("[HOLY] Emergency PW:S %.0f%%", state.lowest.effective_hp or 0))
        end,
    },
    {
        name = "EmergencyFlashHeal",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked or context.is_moving then return false end
            if not state.lowest then return false end
            return state.lowest_hp < (context.settings.holy_emergency_hp or 30)
        end,
        execute = function(context, state)
            local target = state.lowest.unit
            local chosen_spell, spell_label = cast_best_heal_rank(FLASH_HEAL_RANKS, target, context, "Emergency FH", HOLY_OPTS_EMERGENCY_FH)
            if not chosen_spell then return false end
            return try_cast(chosen_spell, target, format("[HOLY] %s %.0f%%", spell_label, state.lowest.effective_hp or 0))
        end,
    },
    {
        name = "FriendlyTarget",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked or context.is_moving then return false end
            if not _check_pushback(context) then return false end
            if context.settings.holy_use_friendly_target == false then return false end
            local threshold = (context.settings and context.settings.holy_friendly_target_threshold) or 90
            local ft = NS.get_friendly_target_entry(context)
            if not ft or not ft.unit then return false end
            if (ft.hp_pct or 100) >= threshold then return false end
            if not state.lowest or (state.lowest.effective_hp or 100) <= (context.settings.holy_emergency_hp or 30) then return false end
            return true
        end,
        execute = function(context, state)
            local ft = NS.get_friendly_target_entry(context)
            if not ft then return false end
            local target = ft.unit
            local chosen_spell, spell_label = cast_best_heal_rank(GREATER_HEAL_RANKS, target, context, "Friendly GH", HOLY_OPTS_GH)
            if not chosen_spell then return false end
            return try_cast(chosen_spell, target, format("[HOLY] %s ft=%.0f%%", spell_label, ft.effective_hp or 0))
        end,
    },

    {
        name = "UnavailableClassicPriestHealA",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked or context.is_moving then return false end
            if context.settings.holy_use_binding_heal == false then return false end
            if context.hp > (context.settings.holy_binding_self_hp or 80) then return false end
            if not state.lowest or state.lowest.is_player then return false end
            return spell_exists(SPELLS.UnavailableClassicPriestHealA) and spell_ready(SPELLS.UnavailableClassicPriestHealA, state.lowest.unit)
        end,
        execute = function(context, state)
            local chosen_spell, spell_label = cast_best_heal_rank(BINDING_HEAL_RANKS, state.lowest.unit, context, "BH", HOLY_OPTS_BH)
            if not chosen_spell then return false end
            return try_cast(chosen_spell, state.lowest.unit, format("[HOLY] %s target=%.0f%% self=%.0f%%", spell_label, state.lowest.effective_hp or 0, context and context.hp or 0))
        end,
    },
    {
        name = "PrayerOfHealing",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked or context.is_moving then return false end
            if context.settings.holy_use_poh == false then return false end
            -- Use subgroup count for PoH (only counts your party in raids)
            local poh_count = state.subgroup_damaged_count or state.group_damaged_count
            if poh_count < (context.settings.holy_aoe_count or 3) then return false end
            -- Predictive overheal gate
            if NS.HealerDeficit and NS.HealerDeficit.gate_spell_overheal then
                local target = state.lowest and state.lowest.unit or NS.PLAYER_UNIT
                if NS.HealerDeficit.gate_spell_overheal("PrayerOfHealing", target, 3.0, context.settings) then return false end
            end
            return true
        end,
        execute = function(context, state)
            local chosen_spell, spell_label = cast_best_heal_rank(PRAYER_OF_HEALING_RANKS, NS.PLAYER_UNIT, context, "PoH", HOLY_OPTS_POH)
            if not chosen_spell then return false end
            return try_cast(chosen_spell, NS.PLAYER_UNIT, format("[HOLY] %s count=%d", spell_label, state.group_damaged_count or 0))
        end,
    },
    {
        name = "InnerFocus",
        is_gcd_gated = false,
        is_burst = true,
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked then return false end
            if context.settings.holy_use_inner_focus == false then return false end
            if state.has_inner_focus then return false end
            if not spell_exists(SPELLS.InnerFocus) or not spell_ready(SPELLS.InnerFocus, NS.PLAYER_UNIT) then return false end
            if not state.lowest then return false end
            return state.lowest_hp < (context.settings.holy_renew_hp or 90)
        end,
        execute = function()
            return try_cast(SPELLS.InnerFocus, NS.PLAYER_UNIT, "[HOLY] Inner Focus")
        end,
    },
    {
        name = "Lightwell",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked then return false end
            if context.settings.holy_use_lightwell == false then return false end
            if not state.lightwell_ready then return false end
            -- Only place Lightwell when raid HP is under sustained pressure (3+ injured)
            return state.group_damaged_count >= (context.settings.holy_aoe_count or 3)
        end,
        execute = function()
            return try_cast(SPELLS.Lightwell, NS.PLAYER_UNIT, "[HOLY] Lightwell (raid sustain)")
        end,
    },
    {
        name = "GreaterHeal",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked or context.is_moving then return false end
            if not state.lowest then return false end
            -- Pushback gate: skip GH when taking damage, fallback to FH
            if _check_pushback(context) then return false end
            -- Mana conservation: drop GH below 30% mana, use FH+Renew only
            if context.mana_pct < (context.settings.holy_gh_mana_floor or 30) then return false end
            local flash_hp = context.settings.holy_flash_heal_hp or 50
            local renew_hp = context.settings.holy_renew_hp or 90
            if not (state.lowest_hp < renew_hp and state.lowest_hp >= flash_hp) then return false end
            -- Predictive overheal gate
            if NS.HealerDeficit and NS.HealerDeficit.gate_spell_overheal then
                if NS.HealerDeficit.gate_spell_overheal("GreaterHeal", state.lowest.unit, 2.5, context.settings) then return false end
            end
            return true
        end,
        execute = function(context, state)
            local target = state.lowest.unit
            local chosen_spell, spell_label = cast_best_heal_rank(GREATER_HEAL_RANKS, target, context, "GH", HOLY_OPTS_GH)
            if not chosen_spell then return false end
            return try_cast(chosen_spell, target, format("[HOLY] %s %.0f%%", spell_label, state.lowest.effective_hp or 0))
        end,
    },
    {
        name = "FlashHeal",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked or context.is_moving then return false end
            if not state.lowest then return false end
            -- Mana conservation: drop direct heals below 15% mana, Renew only
            if context.mana_pct < (context.settings.holy_fh_mana_floor or 15) then return false end
            if not (state.lowest_hp < (context.settings.holy_flash_heal_hp or 50)) then return false end
            -- Predictive overheal gate
            if NS.HealerDeficit and NS.HealerDeficit.gate_spell_overheal then
                if NS.HealerDeficit.gate_spell_overheal("FlashHeal", state.lowest.unit, 1.5, context.settings) then return false end
            end
            return true
        end,
        execute = function(context, state)
            local target = state.lowest.unit
            local chosen_spell, spell_label = cast_best_heal_rank(FLASH_HEAL_RANKS, target, context, "FH", HOLY_OPTS_FH)
            if not chosen_spell then return false end
            return try_cast(chosen_spell, target, format("[HOLY] %s %.0f%%", spell_label, state.lowest.effective_hp or 0))
        end,
    },
    {
        name = "DesperatePrayer",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked then return false end
            if context.settings.holy_use_desperate_prayer == false then return false end
            if context.hp > (context.settings.holy_desp_prayer_hp or 30) then return false end
            if not spell_exists(SPELLS.DesperatePrayer) or not spell_ready(SPELLS.DesperatePrayer, NS.PLAYER_UNIT) then return false end
            return true
        end,
        execute = function()
            return try_cast(SPELLS.DesperatePrayer, NS.PLAYER_UNIT, "[HOLY] Desperate Prayer")
        end,
    },
    {
        name = "DispelMagic",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked then return false end
            if context.settings.use_party_dispel == false then return false end
            if not state.dispel_magic_ready then return false end
            if context.mana_pct < (context.settings.party_dispel_mana_floor or 30) then return false end
            -- Dispel dangerous magic debuffs on tank first, then lowest ally
            if not state.tank and not state.lowest then return false end
            local target = (state.tank and state.tank.unit) or (state.lowest and state.lowest.unit)
            -- Gate: only dispel if the target has a harmful magic effect (Healing module tracks this)
            if Healing.has_dangerous_dispel then
                return Healing.has_dangerous_dispel(target)
            end
            return true
        end,
        execute = function(_, state)
            local target = (state.tank and state.tank.unit) or (state.lowest and state.lowest.unit)
            return try_cast(SPELLS.DispelMagic, target, "[HOLY] Dispel Magic")
        end,
    },
    {
        name = "CureDisease",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked then return false end
            if not state.cure_disease_ready then return false end
            if context.mana_pct < (context.settings.party_dispel_mana_floor or 30) then return false end
            if not state.lowest then return false end
            -- Gate: only cure if the target actually has a disease
            if Healing.has_disease then
                return Healing.has_disease((state.tank and state.tank.unit) or state.lowest.unit)
            end
            return true
        end,
        execute = function(_, state)
            local target = (state.tank and state.tank.unit) or (state.lowest and state.lowest.unit)
            return try_cast(SPELLS.CureDisease, target, "[HOLY] Cure Disease")
        end,
    },
    {
        name = "AbolishDisease",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked then return false end
            if not state.abolish_disease_ready then return false end
            if context.mana_pct < (context.settings.party_dispel_mana_floor or 30) then return false end
            -- Abolish Disease is pre-emptive: use on tank pre-combat or during disease-heavy encounters
            return state.tank ~= nil and not state.cure_disease_ready
        end,
        execute = function(_, state)
            return try_cast(SPELLS.AbolishDisease, state.tank.unit, "[HOLY] Abolish Disease (preventive)")
        end,
    },
    {
        name = "RenewTank",
        matches = function(context, state)
            if context.player_control_locked then return false end
            if not state.tank then return false end
            if not spell_exists(SPELLS.Renew) or not spell_ready(SPELLS.Renew, state.tank.unit) then return false end
            if not context.in_combat and context.settings.holy_prepull_renew == false then return false end

            -- Refresh timing gate: only refresh if < 3s remaining (avoid wasted ticks)
            -- Use explicit nil-check to avoid Lua 0-falsy edge case with renew_remains
            local tank_renew = state.tank.renew_remains
            if tank_renew == nil then
                tank_renew = (state.tank.has_renew and 999 or 0)
            end
            if tank_renew > 3 then return false end

            local threshold = context.settings.holy_renew_hp or 90
            if state.tank.effective_hp > threshold and context.in_combat then
                return false
            end

            return true
        end,
        execute = function(_, state)
            return try_cast(SPELLS.Renew, state.tank.unit, format("[HOLY] Renew Tank %.0f%%", state.tank.effective_hp or 0))
        end,
    },
    {
        name = "RenewSpread",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked then return false end
            if not state.lowest then return false end
            if not spell_exists(SPELLS.Renew) or not spell_ready(SPELLS.Renew, state.lowest.unit) then return false end

            -- Refresh timing gate: only refresh if < 3s remaining (avoid wasted ticks)
            -- Use explicit nil-check to avoid Lua 0-falsy edge case with renew_remains
            local lowest_renew = state.lowest.renew_remains
            if lowest_renew == nil then
                lowest_renew = (state.lowest.has_renew and 999 or 0)
            end
            if lowest_renew > 3 then return false end

            return state.lowest_hp < (context.settings.holy_renew_hp or 90)
        end,
        execute = function(_, state)
            return try_cast(SPELLS.Renew, state.lowest.unit, format("[HOLY] Renew %.0f%%", state.lowest.effective_hp or 0))
        end,
    },
    {
        name = "IdleSWP",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked then return false end
            if not holy_idle_damage_enabled(context) then return false end
            if not context.has_valid_enemy_target then return false end
            if state.lowest_hp < (context.settings.holy_renew_hp or 90) then return false end
            if context.mana_pct < (context.settings.holy_dps_mana_floor or (context.is_solo and 35 or 70)) then return false end
            if state.swp_remaining > 0 then return false end
            return spell_exists(SPELLS.ShadowWordPain) and spell_ready(SPELLS.ShadowWordPain, context.target)
        end,
        execute = function(context)
            return try_cast(SPELLS.ShadowWordPain, context.target, "[HOLY] Idle SW:P")
        end,
    },
    {
        name = "IdleHolyFire",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked or context.is_moving then return false end
            if not holy_idle_damage_enabled(context) then return false end
            if not context.has_valid_enemy_target then return false end
            if state.lowest_hp < (context.settings.holy_renew_hp or 90) then return false end
            if context.mana_pct < (context.settings.holy_dps_mana_floor or (context.is_solo and 45 or 70)) then return false end
            if state.holy_fire_remaining > 0 then return false end
            return spell_exists(SPELLS.HolyFire) and spell_ready(SPELLS.HolyFire, context.target)
        end,
        execute = function(context)
            return try_cast(SPELLS.HolyFire, context.target, "[HOLY] Idle Holy Fire")
        end,
    },
    {
        name = "IdleSmite",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked or context.is_moving then return false end
            if not holy_idle_damage_enabled(context) then return false end
            if not context.has_valid_enemy_target then return false end
            if state.lowest_hp < (context.settings.holy_renew_hp or 90) then return false end
            if context.mana_pct < (context.settings.holy_dps_mana_floor or (context.is_solo and 35 or 70)) then return false end
            return spell_exists(SPELLS.Smite) and spell_ready(SPELLS.Smite, context.target)
        end,
        execute = function(context)
            return try_cast(SPELLS.Smite, context.target, "[HOLY] Idle Smite")
        end,
    },
    -- Mana < 5%: wand/auto-attack only ? all spells forbidden (Research resource floor)
    {
        name = "ManaBelow5Wand",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.player_control_locked then return false end
            if context.mana_pct >= 5 then return false end
            -- Still allow Desperate Prayer if we're about to die
            if context.hp < 15 and state.lowest and state.lowest.is_player then return false end
            return context.has_valid_enemy_target
        end,
        execute = function()
            -- Wand if auto-shoot is not active; otherwise do nothing (auto-attack handles itself)
            if NS.start_auto_attack then
                return NS.start_auto_attack()
            end
            return false
        end,
    },
    -- parity Feature: StopCast
    {
        name = "StopCast",
        matches = stop_cast_matches,
        execute = function()
            if NS.stop_casting then
                return NS.stop_casting()
            end
            -- Fallback: cancel current form/cast via spell book
            if NS.cancel_current_cast then
                return NS.cancel_current_cast()
            end
            return false
        end,
    },
    -- parity Feature: PreHeal
    {
        name = "PreHeal",
        matches = pre_heal_matches,
        execute = function(context, state)
            local target = (state.tank and state.tank.unit) or (state.lowest and state.lowest.unit) or NS.PLAYER_UNIT
            local chosen_spell, spell_label = cast_best_heal_rank(GREATER_HEAL_RANKS, target, context, "PreHeal GH", HOLY_OPTS_GH)
            if not chosen_spell then return false end
            return try_cast(chosen_spell, target, format("[HOLY] %s (PreHeal) %.0f%%", spell_label, state.tank_hp or 0))
        end,
    },
    -- parity Feature: Fade
    {
        name = "Fade",
        matches = fade_matches,
        execute = function(_, state)
            return try_cast(SPELLS.Fade, nil, "[HOLY] Fade (aggro drop)", { skip_range = true })
        end,
    },
    -- parity Feature: Healthstone
    {
        name = "Healthstone",
        matches = healthstone_matches_parity,
        execute = function(_, state)
            if state.healthstone_id and state.healthstone_ready then
                if NS.use_item_by_id then
                    return NS.use_item_by_id(state.healthstone_id)
                end
                return try_cast(state.healthstone_id, nil, "[HOLY] Healthstone", { skip_range = true })
            end
            return false
        end,
    },
    -- parity Feature: MountedProtection
    {
        name = "MountedProtection",
        matches = mounted_protection_matches,
        execute = function()
            return true  -- No-op: mount check is handled in build_holy_state
        end,
    },
    -- parity Feature: EncounterReactions
    {
        name = "EncounterReactions",
        matches = encounter_reactions_matches,
        execute = function(context, state)
            local target = (state.tank and state.tank.unit) or (state.lowest and state.lowest.unit) or NS.PLAYER_UNIT
            local chosen_spell, spell_label = cast_best_heal_rank(FLASH_HEAL_RANKS, target, context, "Encounter FH", HOLY_OPTS_FH)
            if not chosen_spell then return false end
            return try_cast(chosen_spell, target, format("[HOLY] %s (Encounter) %.0f%%", spell_label, (state.tank_hp or state.lowest_hp or 0)))
        end,
    },
}

NS.rotation_registry:register("holy", strategies, {
    get_state = build_holy_state,
    format_context_log = function(_, state)
        return format(
            "lowest=%.0f tank=%.0f damaged=%d sol=%s clear=%s",
            state.lowest_hp or 100,
            state.tank_hp or 100,
            state.group_damaged_count or 0,
            tostring(state.surge_of_light),
            tostring(state.clearcasting)
        )
    end,
})

NS.log("Holy priest rotation registered")
return strategies
