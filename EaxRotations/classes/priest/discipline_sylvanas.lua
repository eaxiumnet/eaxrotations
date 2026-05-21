-- Priest Discipline group-healing priority list.
-- ============================================================================
-- What: TBC Priest Discipline healing and support rotation
-- When: Per tick
-- Why: Priority triage, shield management, and idle damage are centralized for consistency
-- Safety: Context.settings defaults, pcall on optional item/spell checks, shared healing helper guards
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.PriestSpells or {}
local Healing = NS.PriestHealing or require("classes/priest/healing_sylvanas")
local EMPTY_SETTINGS = {}

-- ============================================================================
-- Buff & Debuff ID tables
-- ============================================================================
local SHADOW_WORD_PAIN_DEBUFF = { 25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589 }
local WEAKENED_SOUL_DEBUFF = { 6788 }

local DIVINE_SPIRIT_BUFF = { 25312, 27841, 14819, 14818, 14752 }
-- Mana conservation floors (Research.md Angle 4 Part B)
local CONSUME_MANA_FLOOR = 15  -- Below this: shield only, no heals
-- Rank 7 (max): mana > 30%, Rank 5 (conserve): mana 15-30%, Rank 4: mana < 15%
local GREATER_HEAL_MAX      = 25314  -- Rank 7
local GREATER_HEAL_CONSERVE = 25312  -- Rank 5
local GREATER_HEAL_EFFICIENT = 25210 -- Rank 4

-- Pushback detection for Greater Heal
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
            -- Try: is this enemy attacking?
            local ok, is_casting = pcall(function() return enemy:is_casting() end)
            if ok and is_casting then return true end

            -- Fallback: can_attack check
            local ok2, can_attack = pcall(function()
                if context.me.can_attack then return enemy:can_attack(context.me) end
                return false
            end)
            if ok2 and can_attack then return true end
        end
    end
    return false
end
local INNER_FIRE_BUFF = { 25431, 10952, 10951, 1006, 602, 7128, 588 }
local FEAR_WARD_BUFF = { 6346 }
local POWER_WORD_FORTITUDE_BUFF = { 25389, 10938, 10937, 2791, 1245, 1244, 1243 }
local PRAYER_OF_FORTITUDE_BUFF = { 25392, 21564, 21562 }
local RENEW_BUFF = { 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }
local INNER_FOCUS_BUFF = { 14751 }
-- FrostByte feature constants
local FADE_BUFF = { 25429, 10942, 10941, 9592, 9579, 9578, 586 }
local HEALTHSTONE_IDS = (TBC and TBC.ITEMS and TBC.ITEMS.healthstones) or { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }

-- ============================================================================
-- State builder
-- ============================================================================
local disc_state = {
    lowest = nil,
    tank = nil,
    group_damaged_count = 0,
    has_inner_fire = false,
    has_fear_ward = false,
    has_power_word_fortitude = false,
    pws_ready = false,
    pom_ready = false,
    flash_heal_ready = false,
    greater_heal_ready = false,
    renew_ready = false,
    binding_heal_ready = false,
    circle_of_healing_ready = false,
    prayer_of_healing_ready = false,
    prayer_of_mending_ready = false,
    shadow_word_pain_ready = false,
    smite_ready = false,
    holy_fire_ready = false,
    psychic_scream_ready = false,
    dispel_magic_ready = false,
    shackle_undead_ready = false,
    mana_pct = 100,
    hp_pct = 100,
    in_combat = false,
    target_creature_type = nil,
    target_casting = false,
    -- CD state
    pain_suppression_ready = false,
    power_infusion_ready = false,
    inner_focus_ready = false,
    has_inner_focus = false,
    -- FrostByte feature state
    healthstone_ready = false,
    healthstone_id = nil,
    has_fade_buff = false,
    fade_ready = false,
}

local function build_state(context)
    context.settings = context.settings or EMPTY_SETTINGS
    local me = context.me or NS.GetPlayer()
    if not me then return disc_state end
    -- Mounted bail: healer should not queue buffs/heals while mounted
    if me.is_mounted and me:is_mounted() then
        return disc_state
    end
    local target = context.target
    local entries, count = Healing.scan_healing_targets()

    disc_state.lowest = NS.healing_get_lowest_hp(entries, count, 92)
    disc_state.tank = NS.healing_get_tank(entries, count) or disc_state.lowest
    disc_state.group_damaged_count = NS.healing_count_below_hp(entries, count, context.settings.discipline_aoe_hp or 85)
    -- Subgroup count for Prayer of Healing: in raids, only count your own party
    disc_state.subgroup_damaged_count = (Healing.count_subgroup_below_hp and Healing.count_subgroup_below_hp(context.settings.discipline_aoe_hp or 85)) or disc_state.group_damaged_count
    disc_state.has_inner_fire = me and NS.buff_up(me, INNER_FIRE_BUFF) or false
    disc_state.has_fear_ward = me and NS.buff_up(me, FEAR_WARD_BUFF) or false
    disc_state.has_power_word_fortitude = me and NS.buff_up(me, POWER_WORD_FORTITUDE_BUFF) or false
    disc_state.divine_spirit_ready = me and NS.spell_ready(SPELLS.DivineSpirit, me, { skip_range = true }) or false
    disc_state.prayer_of_fortitude_ready = me and NS.spell_ready(SPELLS.PrayerOfFortitude, me, { skip_range = true }) or false
    disc_state.pws_ready = me and NS.spell_ready(SPELLS.PowerWordShield, me, { skip_range = true }) or false
    disc_state.pom_ready = me and NS.spell_ready(SPELLS.PrayerofMending, me, { skip_range = true }) or false
    disc_state.flash_heal_ready = me and NS.spell_ready(SPELLS.FlashHeal, me, { skip_range = true }) or false
    disc_state.greater_heal_ready = me and NS.spell_ready(SPELLS.GreaterHeal, me, { skip_range = true }) or false
    disc_state.renew_ready = me and NS.spell_ready(SPELLS.Renew, me, { skip_range = true }) or false
    disc_state.binding_heal_ready = me and NS.spell_ready(SPELLS.BindingHeal, me, { skip_range = true }) or false
    disc_state.circle_of_healing_ready = me and NS.spell_ready(SPELLS.CircleofHealing, me, { skip_range = true }) or false
    disc_state.prayer_of_healing_ready = me and NS.spell_ready(SPELLS.PrayerOfHealing, me, { skip_range = true }) or false
    disc_state.prayer_of_mending_ready = me and NS.spell_ready(SPELLS.PrayerofMending, me, { skip_range = true }) or false
    disc_state.shadow_word_pain_ready = me and NS.spell_ready(SPELLS.ShadowWordPain, me, { expected_cooldown = 1.5 }) or false
    disc_state.smite_ready = me and NS.spell_ready(SPELLS.Smite, me, { expected_cooldown = 2.5 }) or false
    disc_state.holy_fire_ready = me and NS.spell_ready(SPELLS.HolyFire, me, { expected_cooldown = 10 }) or false
    disc_state.psychic_scream_ready = me and NS.spell_ready(SPELLS.PsychicScream, me, { expected_cooldown = 30 }) or false
    disc_state.dispel_magic_ready = me and NS.spell_ready(SPELLS.DispelMagic, me, { skip_range = true }) or false
    disc_state.shackle_undead_ready = me and NS.spell_ready(SPELLS.ShackleUndead, me, { expected_cooldown = 1.5 }) or false
    disc_state.mana_pct = context.mana_pct or (me and NS.unit_mana_pct and NS.unit_mana_pct(me)) or 100
    disc_state.hp_pct = context.hp or (me and NS.unit_health_pct(me)) or 100
    disc_state.in_combat = context.in_combat or false
    disc_state.target_creature_type = target and NS.unit_creature_type and NS.unit_creature_type(target) or nil
    disc_state.target_casting = target and target.is_casting and target:is_casting() or false

    -- Cooldown readiness
    disc_state.pain_suppression_ready = me and NS.spell_ready(33206, me, { skip_range = true }) or false
    disc_state.power_infusion_ready = me and NS.spell_ready(10060, me, { skip_range = true }) or false
    disc_state.inner_focus_ready = me and NS.spell_ready(SPELLS.InnerFocus or 14751, me, { skip_range = true }) or false
    disc_state.has_inner_focus = me and NS.buff_up(me, INNER_FOCUS_BUFF) or false

    -- FrostByte: Healthstone scanning
    disc_state.healthstone_id = nil
    disc_state.healthstone_ready = false
    if NS.is_item_ready then
        for _, id in ipairs(HEALTHSTONE_IDS) do
            local ok, ready = pcall(NS.is_item_ready, id)
            if ok and ready then
                disc_state.healthstone_id = id
                disc_state.healthstone_ready = true
                break
            end
        end
    end

    -- FrostByte: Fade state
    disc_state.has_fade_buff = me and NS.buff_up(me, FADE_BUFF) or false
    disc_state.fade_ready = me and NS.spell_ready(SPELLS.Fade, me, { skip_range = true }) or false

    return disc_state
end

local function discipline_idle_damage_enabled(context)
    local settings = context and context.settings or EMPTY_SETTINGS
    if settings.discipline_dps_when_idle == true then return true end
    return context and (context.is_solo == true or context.is_leveling == true)
end

local function group_stable_for_idle_damage(context, s)
    local settings = context and context.settings or EMPTY_SETTINGS
    if s.lowest and (s.lowest.effective_hp or 100) < (settings.discipline_idle_hp or 92) then return false end
    return true
end

-- ============================================================================
-- Action definitions
-- ============================================================================
local EMERGENCY_PWS_ACTION = { name = "EmergencyPowerWordShield", spell = SPELLS.PowerWordShield, target = "self", requires_target = false }
local POM_TANK_ACTION = { name = "PrayerOfMendingTank", spell = SPELLS.PrayerofMending, target = "self", cooldown = 10, requires_target = false }
local FLASH_HEAL_ACTION = { name = "EmergencyFlashHeal", spell = SPELLS.FlashHeal, target = "self", requires_target = false }
local GREATER_HEAL_ACTION = { name = "GreaterHeal", spell = SPELLS.GreaterHeal, target = "self", requires_target = false }
local RENEW_TANK_ACTION = { name = "RenewTank", spell = SPELLS.Renew, target = "self", kind = "buff", buff = RENEW_BUFF, requires_target = false }
local RENEW_LOWEST_ACTION = { name = "RenewLowest", spell = SPELLS.Renew, target = "self", kind = "buff", buff = RENEW_BUFF, requires_target = false }
local BINDING_HEAL_ACTION = { name = "BindingHeal", spell = SPELLS.BindingHeal, target = "self", requires_target = false }
local CIRCLE_OF_HEALING_ACTION = { name = "CircleOfHealing", spell = SPELLS.CircleofHealing, target = "self", requires_target = false }
local PRAYER_OF_HEALING_ACTION = { name = "PrayerOfHealing", spell = SPELLS.PrayerOfHealing, target = "self", requires_target = false }
local INNER_FIRE_ACTION = { name = "InnerFire", spell = SPELLS.InnerFire, target = "self", kind = "buff", buff = INNER_FIRE_BUFF, requires_target = false }
local FEAR_WARD_ACTION = { name = "FearWard", spell = SPELLS.FearWard, target = "self", kind = "buff", buff = FEAR_WARD_BUFF, requires_target = false }
local PWF_ACTION = { name = "PowerWordFortitude", spell = SPELLS.PowerWordFortitude, target = "self", kind = "buff", buff = POWER_WORD_FORTITUDE_BUFF, requires_target = false }
local IDLE_SWP_ACTION = { name = "IdleShadowWordPain", spell = SPELLS.ShadowWordPain, cooldown = 1.5 }
local IDLE_SMITE_ACTION = { name = "IdleSmite", spell = SPELLS.Smite, cooldown = 2.5 }
local HOLY_FIRE_ACTION = { name = "HolyFire", spell = SPELLS.HolyFire, cooldown = 10 }
local PSYCHIC_SCREAM_ACTION = { name = "PsychicScream", spell = SPELLS.PsychicScream, cooldown = 30 }
local SHACKLE_UNDEAD_ACTION = { name = "ShackleUndead", spell = SPELLS.ShackleUndead, cooldown = 1.5 }
local DISPEL_MAGIC_ACTION = { name = "DispelMagic", spell = SPELLS.DispelMagic, target = "self", requires_target = false }
local PAIN_SUPPRESSION_ACTION = { name = "PainSuppression", spell = 33206, target = "self", cooldown = 180, requires_target = false }
local POWER_INFUSION_ACTION = { name = "PowerInfusion", spell = 10060, target = "self", cooldown = 180, requires_target = false }
local INNER_FOCUS_ACTION = { name = "InnerFocus", spell = SPELLS.InnerFocus or 14751, target = "self", kind = "buff", buff = INNER_FOCUS_BUFF, cooldown = 180, requires_target = false }

-- ============================================================================
-- Match functions
-- ============================================================================
local function emergency_pws_matches(context, s)
    if not s.lowest then return false end
    if (s.lowest.effective_hp or 100) > (context.settings.discipline_pws_hp or 35) then return false end
    if s.lowest.has_weakened_soul then return false end
    if not s.pws_ready then return false end
    -- Respect existing absorb: don't overwrite a healthy PW:S shield.
    -- PW:S max absorb is ~1265 base (up to ~2000 with gear); 200 means ≤16% remaining.
    if Healing.pws_absorb_remaining then
        local absorb = Healing.pws_absorb_remaining(s.lowest.unit)
        if absorb > 200 then return false end
    end
    return NS.action_matches(context, EMERGENCY_PWS_ACTION)
end

local function pom_tank_matches(context, s)
    if not context.in_combat then return false end
    local target = s.tank or s.lowest
    if not target then return false end
    if not s.pom_ready then return false end
    return NS.action_matches(context, POM_TANK_ACTION)
end

local function flash_heal_matches(context, s)
    if context.is_moving then return false end
    if not s.lowest then return false end
    if (s.lowest.effective_hp or 100) > (context.settings.discipline_flash_hp or 55) then return false end
    if (s.mana_pct or 100) < CONSUME_MANA_FLOOR then return false end
    if not s.flash_heal_ready then return false end
    return NS.action_matches(context, FLASH_HEAL_ACTION)
end

local function greater_heal_matches(context, s)
    if not context.in_combat then return false end
    if context.is_moving then return false end
    if not s.lowest then return false end
    -- Mana conserve: at <30%, skip GH in favor of Flash Heal (Research.md Angle 4 Part B)
    if (s.mana_pct or 100) < 30 then return false end
    -- Pushback gate: skip GH when taking damage (cast time gets pushed back, inefficient)
    -- Falls back to faster heals (Flash Heal) during pushback windows
    if _check_pushback(context) then return false end
    local hp = s.lowest.effective_hp or 100
    if hp > (context.settings.discipline_greater_heal_hp or 82) then return false end
    if hp <= (context.settings.discipline_flash_hp or 55) then return false end
    if not s.greater_heal_ready then return false end
    return NS.action_matches(context, GREATER_HEAL_ACTION)
end

local function renew_tank_matches(context, s)
    if not s.tank then return false end
    if s.tank.has_renew then return false end
    if (s.tank.effective_hp or 100) > (context.settings.discipline_renew_hp or 90) then return false end
    if not s.renew_ready then return false end
    return NS.action_matches(context, RENEW_TANK_ACTION)
end

local function renew_lowest_matches(context, s)
    if not s.lowest then return false end
    if s.lowest.has_renew then return false end
    if (s.lowest.effective_hp or 100) > (context.settings.discipline_renew_hp or 90) then return false end
    if not s.renew_ready then return false end
    return NS.action_matches(context, RENEW_LOWEST_ACTION)
end

local function binding_heal_matches(context, s)
    if context.is_moving then return false end
    if not s.lowest then return false end
    if (s.lowest.effective_hp or 100) > 50 then return false end
    if (s.hp_pct or 100) > 70 then return false end
    if not s.binding_heal_ready then return false end
    return NS.action_matches(context, BINDING_HEAL_ACTION)
end

local function circle_of_healing_matches(context, s)
    if context.is_moving then return false end
    if s.group_damaged_count < 3 then return false end
    if not s.circle_of_healing_ready then return false end
    return NS.action_matches(context, CIRCLE_OF_HEALING_ACTION)
end

local function prayer_of_healing_matches(context, s)
    if context.is_moving then return false end
    -- Use subgroup count for PoH (only counts your party in raids)
    local poh_count = s.subgroup_damaged_count or s.group_damaged_count
    if poh_count < 4 then return false end
    if not s.prayer_of_healing_ready then return false end
    return NS.action_matches(context, PRAYER_OF_HEALING_ACTION)
end

local function inner_fire_matches(context, s)
    if s.has_inner_fire then return false end
    return NS.action_matches(context, INNER_FIRE_ACTION)
end

local function fear_ward_matches(context, s)
    if s.has_fear_ward then return false end
    return NS.action_matches(context, FEAR_WARD_ACTION)
end

local function pwf_matches(context, s)
    if s.has_power_word_fortitude then return false end
    return NS.action_matches(context, PWF_ACTION)
end

local function idle_swp_matches(context, s)
    if not context.in_combat then return false end
    if not context.has_valid_enemy_target then return false end
    if not discipline_idle_damage_enabled(context) then return false end
    if (s.mana_pct or context.mana_pct or 100) < ((context.settings or EMPTY_SETTINGS).discipline_dps_mana_floor or 35) then return false end
    if not group_stable_for_idle_damage(context, s) then return false end
    if NS.debuff_remains(context.target, SHADOW_WORD_PAIN_DEBUFF) > 0 then return false end
    if not s.shadow_word_pain_ready then return false end
    return NS.action_matches(context, IDLE_SWP_ACTION)
end

local function idle_smite_matches(context, s)
    if context.is_moving then return false end
    if not context.in_combat then return false end
    if not context.has_valid_enemy_target then return false end
    if not discipline_idle_damage_enabled(context) then return false end
    if (s.mana_pct or context.mana_pct or 100) < ((context.settings or EMPTY_SETTINGS).discipline_dps_mana_floor or 35) then return false end
    if not group_stable_for_idle_damage(context, s) then return false end
    if not s.smite_ready then return false end
    return NS.action_matches(context, IDLE_SMITE_ACTION)
end

local function holy_fire_matches(context, s)
    if context.is_moving then return false end
    if not context.in_combat then return false end
    if not context.has_valid_enemy_target then return false end
    if not discipline_idle_damage_enabled(context) then return false end
    if (s.mana_pct or context.mana_pct or 100) < ((context.settings or EMPTY_SETTINGS).discipline_dps_mana_floor or 45) then return false end
    if not group_stable_for_idle_damage(context, s) then return false end
    if not s.holy_fire_ready then return false end
    return NS.action_matches(context, HOLY_FIRE_ACTION)
end

local function psychic_scream_matches(context, s)
    if not context.in_combat then return false end
    if s.enemy_count < 3 then return false end
    if not s.psychic_scream_ready then return false end
    return NS.action_matches(context, PSYCHIC_SCREAM_ACTION)
end

local function shackle_undead_matches(context, s)
    if not context.has_valid_enemy_target then return false end
    if s.target_creature_type ~= 6 then return false end
    if not s.shackle_undead_ready then return false end
    return NS.action_matches(context, SHACKLE_UNDEAD_ACTION)
end

local function dispel_magic_matches(context, s)
    if not s.dispel_magic_ready then return false end
    return NS.action_matches(context, DISPEL_MAGIC_ACTION)
end

-- ============================================================================
-- Pain Suppression: emergency external CD for tank lethal spikes
-- ============================================================================
local function pain_suppression_matches(context, s)
    if not context.in_combat then return false end
    if not s.tank then return false end
    local tank_hp = s.tank.effective_hp or 100
    if tank_hp > (context.settings.discipline_pain_suppression_hp or 25) then return false end
    if not s.pain_suppression_ready then return false end
    return NS.action_matches(context, PAIN_SUPPRESSION_ACTION)
end

-- ============================================================================
-- Power Infusion: grant +20% haste to caster DPS or self
-- ============================================================================
local function power_infusion_matches(context, s)
    if not context.in_combat then return false end
    if not s.power_infusion_ready then return false end
    local settings = context.settings or EMPTY_SETTINGS
    if settings.discipline_use_power_infusion == false then return false end
    -- Gate: only use on boss fights or when all DPS are healthy
    if s.lowest and (s.lowest.effective_hp or 100) < (settings.discipline_pi_safety_hp or 80) then return false end
    return NS.action_matches(context, POWER_INFUSION_ACTION)
end

-- ============================================================================
-- Inner Focus: free +25% crit on next spell — pair with Greater Heal or PoH
-- ============================================================================
local function inner_focus_matches(context, s)
    if not context.in_combat then return false end
    if s.has_inner_focus then return false end
    if not s.inner_focus_ready then return false end
    local settings = context.settings or EMPTY_SETTINGS
    if settings.discipline_use_inner_focus == false then return false end
    -- Use when tank needs a big heal or raid needs PoH
    local tank_hp = s.tank and (s.tank.effective_hp or 100) or 100
    if tank_hp > (settings.discipline_if_hp or 65) and s.group_damaged_count < 4 then return false end
    return NS.action_matches(context, INNER_FOCUS_ACTION)
end

-- ============================================================================
-- FrostByte Feature: StopCast
-- Mid-cast cancellation: if a higher-priority target emerges during a long cast,
-- interrupt the current cast to switch to the higher-priority target.
-- ============================================================================
local function stop_cast_matches(context, s)
    if not context.in_combat then return false end
    if context.player_control_locked then return false end
    if not context.me then return false end
    local ok, is_casting = pcall(function() return context.me:is_casting() end)
    if not ok or not is_casting then return false end
    if not s.lowest then return false end
    if (s.lowest.effective_hp or 100) < 30 then return true end
    if s.tank and (s.tank.effective_hp or 100) < 50 then return true end
    return false
end

-- ============================================================================
-- FrostByte Feature: PreHeal
-- Pre-cast Greater Heal when tank is about to take predictable damage.
-- ============================================================================
local function pre_heal_matches(context, s)
    if not context.in_combat then return false end
    if context.is_moving then return false end
    if not s.tank then return false end
    local tank_hp = s.tank.effective_hp or 100
    if tank_hp < 60 or tank_hp > 95 then return false end
    if not _check_pushback(context) then return false end
    if context.me then
        local ok, casting = pcall(function() return context.me:is_casting() end)
        if ok and casting then return false end
    end
    return s.greater_heal_ready
end

-- ============================================================================
-- FrostByte Feature: Fade
-- Auto-use Fade when player has aggro.
-- ============================================================================
local function fade_matches(context, s)
    if not context.in_combat then return false end
    if s.has_fade_buff then return false end
    if not s.fade_ready then return false end
    local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(20) or {}
    for _, enemy in ipairs(enemies) do
        if enemy and pcall(function() return enemy:is_valid() end) and pcall(function() return enemy:is_alive() end) then
            local ok, etarget = pcall(function() return enemy:get_target() end)
            if ok and etarget and context.me and etarget == context.me then
                return true
            end
        end
    end
    return false
end

-- ============================================================================
-- FrostByte Feature: Healthstone
-- Auto-use healthstone below HP threshold, off-GCD.
-- ============================================================================
local function healthstone_matches(context, s)
    if not s.healthstone_ready then return false end
    local hs_hp = (context.settings and context.settings.discipline_healthstone_hp) or 35
    if (s.hp_pct or 100) > hs_hp then return false end
    return true
end

-- ============================================================================
-- Divine Spirit: maintain buff on self (and group when Prayer of Spirit talented)
-- ============================================================================
local DIVINE_SPIRIT_ACTION = { name = "DivineSpirit", spell = SPELLS.DivineSpirit, target = "self", kind = "buff", buff = DIVINE_SPIRIT_BUFF, requires_target = false }

local function divine_spirit_matches(context, s)
    if not s.divine_spirit_ready then return false end
    return NS.action_matches(context, DIVINE_SPIRIT_ACTION)
end

-- ============================================================================
-- Prayer of Fortitude: maintain raid buff
-- ============================================================================
local POF_ACTION = { name = "PrayerOfFortitude", spell = SPELLS.PrayerOfFortitude, target = "self", kind = "buff", buff = PRAYER_OF_FORTITUDE_BUFF, requires_target = false }

local function pof_matches(context, s)
    if not s.prayer_of_fortitude_ready then return false end
    return NS.action_matches(context, POF_ACTION)
end

-- ============================================================================
-- Strategies
-- ============================================================================
local strategies = {
    { name = "EmergencyPowerWordShield", matches = emergency_pws_matches, execute = function(context, s) return NS.try_cast(SPELLS.PowerWordShield, s.lowest.unit, string.format("[DISCIPLINE] PW:S %.0f%%", s.lowest.effective_hp or 0)) end },
    { name = "PrayerOfMendingTank", matches = pom_tank_matches, execute = function(context, s) return NS.try_cast(SPELLS.PrayerofMending, (s.tank and s.tank.unit) or (s.lowest and s.lowest.unit), "[DISCIPLINE] Prayer of Mending") end },
    { name = "EmergencyFlashHeal", matches = flash_heal_matches, execute = function(context, s) return NS.try_cast(SPELLS.FlashHeal, s.lowest.unit, string.format("[DISCIPLINE] Flash Heal %.0f%%", s.lowest.effective_hp or 0)) end },
    { name = "GreaterHeal", matches = greater_heal_matches, execute = function(context, s)
        local mana_pct = s.mana_pct or context.mana_pct or 100
        local spell_id
        if mana_pct > 30 then
            spell_id = GREATER_HEAL_MAX
        elseif mana_pct > 15 then
            spell_id = GREATER_HEAL_CONSERVE
        else
            spell_id = GREATER_HEAL_EFFICIENT
        end
        return NS.try_cast(spell_id, s.lowest.unit, string.format("[DISCIPLINE] Greater Heal %.0f%% (rank %s)", s.lowest.effective_hp or 0, mana_pct > 30 and "7" or (mana_pct > 15 and "5" or "4")))
    end },
    { name = "BindingHeal", matches = binding_heal_matches, execute = function(context, s) return NS.try_cast(SPELLS.BindingHeal, s.lowest.unit, "[DISCIPLINE] Binding Heal") end },
    { name = "CircleOfHealing", matches = circle_of_healing_matches, execute = function(context) return NS.action_execute(context, CIRCLE_OF_HEALING_ACTION, "[DISCIPLINE]") end },
    { name = "PrayerOfHealing", matches = prayer_of_healing_matches, execute = function(context) return NS.action_execute(context, PRAYER_OF_HEALING_ACTION, "[DISCIPLINE]") end },
    { name = "RenewTank", matches = renew_tank_matches, execute = function(context, s) return NS.try_cast(SPELLS.Renew, s.tank.unit, string.format("[DISCIPLINE] Renew tank %.0f%%", s.tank.effective_hp or 0)) end },
    { name = "RenewLowest", matches = renew_lowest_matches, execute = function(context, s) return NS.try_cast(SPELLS.Renew, s.lowest.unit, string.format("[DISCIPLINE] Renew %.0f%%", s.lowest.effective_hp or 0)) end },
    { name = "InnerFire", matches = inner_fire_matches, execute = function(context) return NS.action_execute(context, INNER_FIRE_ACTION, "[DISCIPLINE]") end },
    { name = "FearWard", matches = fear_ward_matches, execute = function(context) return NS.action_execute(context, FEAR_WARD_ACTION, "[DISCIPLINE]") end },
    { name = "PowerWordFortitude", matches = pwf_matches, execute = function(context) return NS.action_execute(context, PWF_ACTION, "[DISCIPLINE]") end },
    { name = "DivineSpirit", matches = divine_spirit_matches, execute = function(context) return NS.action_execute(context, DIVINE_SPIRIT_ACTION, "[DISCIPLINE]") end },
    { name = "PrayerOfFortitude", matches = pof_matches, execute = function(context) return NS.action_execute(context, POF_ACTION, "[DISCIPLINE]") end },
    { name = "IdleShadowWordPain", matches = idle_swp_matches, execute = function(context) return NS.action_execute(context, IDLE_SWP_ACTION, "[DISCIPLINE]") end },
    { name = "IdleSmite", matches = idle_smite_matches, execute = function(context) return NS.action_execute(context, IDLE_SMITE_ACTION, "[DISCIPLINE]") end },
    { name = "HolyFire", matches = holy_fire_matches, execute = function(context) return NS.action_execute(context, HOLY_FIRE_ACTION, "[DISCIPLINE]") end },
    { name = "PsychicScream", matches = psychic_scream_matches, execute = function(context) return NS.action_execute(context, PSYCHIC_SCREAM_ACTION, "[DISCIPLINE]") end },
    { name = "ShackleUndead", matches = shackle_undead_matches, execute = function(context) return NS.action_execute(context, SHACKLE_UNDEAD_ACTION, "[DISCIPLINE]") end },
    { name = "DispelMagic", matches = dispel_magic_matches, execute = function(context) return NS.action_execute(context, DISPEL_MAGIC_ACTION, "[DISCIPLINE]") end },
    -- Cooldown Features
    { name = "PainSuppression", matches = pain_suppression_matches, execute = function(_, s) return NS.try_cast(33206, s.tank.unit, string.format("[DISCIPLINE] Pain Suppression on tank %.0f%%", s.tank.effective_hp or 0)) end },
    { name = "PowerInfusion", matches = power_infusion_matches, execute = function() return NS.try_cast(10060, nil, "[DISCIPLINE] Power Infusion", { skip_range = true }) end },
    { name = "InnerFocus", matches = inner_focus_matches, execute = function() return NS.try_cast(SPELLS.InnerFocus or 14751, nil, "[DISCIPLINE] Inner Focus", { skip_range = true }) end },
    -- FrostByte Features
    { name = "StopCast", matches = stop_cast_matches, execute = function() if NS.stop_casting then return NS.stop_casting() end; if NS.cancel_current_cast then return NS.cancel_current_cast() end; return false end },
    { name = "PreHeal", matches = pre_heal_matches, execute = function(context, s) return NS.try_cast(SPELLS.GreaterHeal, (s.tank and s.tank.unit) or (s.lowest and s.lowest.unit), string.format("[DISCIPLINE] PreHeal GH %.0f%%", (s.tank and s.tank.effective_hp) or (s.lowest and s.lowest.effective_hp) or 0)) end },
    { name = "Fade", matches = fade_matches, execute = function() return NS.try_cast(SPELLS.Fade, nil, "[DISCIPLINE] Fade (aggro drop)", { skip_range = true }) end },
    { name = "Healthstone", matches = healthstone_matches, execute = function(_, s) if s.healthstone_id and s.healthstone_ready and NS.use_item_by_id then return NS.use_item_by_id(s.healthstone_id) end; return false end },
}

NS.rotation_registry:register("discipline", strategies, { get_state = build_state })
NS.log("Priest discipline rotation registered (Tier A)")
return strategies
