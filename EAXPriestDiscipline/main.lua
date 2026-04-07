require("libraries/path_bootstrap")
-- EAX Port) | main.lua
-- Discipline healing rotation with PW:S spam, Penance burst, Weakened Soul management.
-- Source: /rotation/source/aio/priest/discipline.lua

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")

-- Access the namespace for toggle_menu export
local _G = _G
local NS = _G.EAX

local buff_manager = require("common/modules/buff_manager")
local spell_queue = require("common/modules/spell_queue")

-- Hot-path local caching
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown
local _get_spell_cd = core.spell_book.get_spell_cooldown

-- Runtime state
local runtime = {
    last_cast_time = 0,
    shadowfiend_last = 0,
    mode_cache = "solo",
    last_mode_check = 0,
    last_mode_log = nil,
}

-- Resolved spell IDs
local resolved = {
    flash_heal = utils.resolve_spell_id(spells.FLASH_HEAL),
    greater_heal = utils.resolve_spell_id(spells.GREATER_HEAL),
    renew = utils.resolve_spell_id(spells.RENEW),
    power_word_shield = utils.resolve_spell_id(spells.POWER_WORD_SHIELD),
    prayer_of_healing = utils.resolve_spell_id(spells.PRAYER_OF_HEALING),
    prayer_of_mending = utils.resolve_spell_id(spells.PRAYER_OF_MENDING),
    binding_heal = utils.resolve_spell_id(spells.BINDING_HEAL),
    inner_focus = utils.resolve_spell_id(spells.INNER_FOCUS),
    power_infusion = utils.resolve_spell_id(spells.POWER_INFUSION),
    pain_suppression = utils.resolve_spell_id(spells.PAIN_SUPPRESSION),
    inner_fire = utils.resolve_spell_id(spells.INNER_FIRE),
    fortitude = utils.resolve_spell_id(spells.POWER_WORD_FORTITUDE),
    divine_spirit = utils.resolve_spell_id(spells.DIVINE_SPIRIT),
    shadow_protection = utils.resolve_spell_id(spells.SHADOW_PROTECTION),
    fear_ward = utils.resolve_spell_id(spells.FEAR_WARD),
    fade = utils.resolve_spell_id(spells.FADE),
    shadowfiend = utils.resolve_spell_id(spells.SHADOWFIEND),
    dispel_magic = utils.resolve_spell_id(spells.DISPEL_MAGIC),
    cure_disease = utils.resolve_spell_id(spells.CURE_DISEASE),
    desperate_prayer = utils.resolve_spell_id(spells.DESPERATE_PRAYER),
    berserking = utils.resolve_spell_id(spells.BERSERKING),
}

-- Helper functions
local function note_cast()
    runtime.last_cast_time = _core_time()
end

local function log_mode(mode)
    if menu and menu.debug and menu.debug:get_state() and runtime.last_mode_log ~= mode then
        utils.log_debug(menu, "Mode=" .. mode)
        runtime.last_mode_log = mode
    end
end

-- Check if Pain Suppression is available
local function is_pain_suppression_ready()
    if not resolved.pain_suppression then return false end
    return _get_spell_cd(resolved.pain_suppression) == 0
end

-- Check if Power Infusion is available
local function is_power_infusion_ready()
    if not resolved.power_infusion then return false end
    return _get_spell_cd(resolved.power_infusion) == 0
end

-- Check if Inner Focus is available
local function is_inner_focus_ready()
    if not resolved.inner_focus then return false end
    return _get_spell_cd(resolved.inner_focus) == 0
end

-- Try Pain Suppression on critically low tank
local function try_pain_suppression(me)
    if not resolved.pain_suppression then return false end
    if not (menu.disc_use_pain_suppression and menu.disc_use_pain_suppression:get_state()) then return false end
    if not is_pain_suppression_ready() then return false end
    if not me:is_in_combat() then return false end
    
    local tank = utils.get_tank_unit(me)
    if not tank or not tank:is_valid() or tank:is_dead() then return false end
    
    local threshold = (menu.disc_pain_suppression_hp and menu.disc_pain_suppression_hp:get() or 20) / 100
    local hp = utils.get_health_pct(tank)
    if hp > threshold then return false end
    
    if utils.cast_target(resolved.pain_suppression, me, tank) then
        note_cast()
        utils.log_debug(menu, "Pain Suppression on tank (" .. math.floor(hp * 100) .. "%)")
        return true
    end
    return false
end

-- Try Power Infusion (off-GCD, self or ally)
local function try_power_infusion(me)
    if not resolved.power_infusion then return false end
    if not (menu.disc_use_power_infusion and menu.disc_use_power_infusion:get_state()) then return false end
    if not is_power_infusion_ready() then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_POWER_INFUSION) then return false end
    
    -- Cast on self for now (could be extended to target healers/DPS)
    if utils.cast_self(resolved.power_infusion, me) then
        note_cast()
        utils.log_debug(menu, "Power Infusion (self)")
        return true
    end
    return false
end

-- Try Inner Focus (off-GCD, before Greater Heal)
local function try_inner_focus(me)
    if not resolved.inner_focus then return false end
    if not (menu.disc_use_inner_focus and menu.disc_use_inner_focus:get_state()) then return false end
    if not is_inner_focus_ready() then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_INNER_FOCUS) then return false end
    
    -- Only use if we have a low HP target that needs Greater Heal
    local threshold = (menu.disc_flash_heal_hp and menu.disc_flash_heal_hp:get() or 50) / 100
    local lowest, lowest_hp = utils.find_lowest_effective_ally(me, threshold, false)
    if not lowest or lowest_hp >= threshold then return false end
    
    if utils.cast_self(resolved.inner_focus, me) then
        note_cast()
        utils.log_debug(menu, "Inner Focus (for Greater Heal)")
        return true
    end
    return false
end

-- Try Emergency Flash Heal on critically low target
local function try_emergency_flash_heal(me)
    if not resolved.flash_heal then return false end
    if not me:is_in_combat() then return false end
    
    local threshold = (menu.disc_emergency_hp and menu.disc_emergency_hp:get() or 25) / 100
    local lowest, lowest_hp = utils.find_lowest_effective_ally(me, threshold, false)
    if not lowest or lowest_hp >= threshold then return false end
    
    if lowest == me then
        if utils.cast_self(resolved.flash_heal, me) then
            note_cast()
            utils.log_debug(menu, "Emergency Flash Heal (self)")
            return true
        end
    else
        if utils.cast_target(resolved.flash_heal, me, lowest) then
            note_cast()
            utils.log_debug(menu, "Emergency Flash Heal (" .. math.floor(lowest_hp * 100) .. "%)")
            return true
        end
    end
    return false
end

-- Try Binding Heal (self + target both damaged)
local function try_binding_heal(me)
    if not resolved.binding_heal then return false end
    if not me:is_in_combat() then return false end
    
    local self_hp = utils.get_health_pct(me)
    if self_hp > 0.80 then return false end
    
    local threshold = (menu.disc_flash_heal_hp and menu.disc_flash_heal_hp:get() or 50) / 100
    local lowest, lowest_hp = utils.find_lowest_effective_ally(me, threshold, true) -- skip self
    if not lowest or lowest_hp >= threshold then return false end
    
    if utils.cast_target(resolved.binding_heal, me, lowest) then
        note_cast()
        utils.log_debug(menu, "Binding Heal (self: " .. math.floor(self_hp * 100) .. "%, target: " .. math.floor(lowest_hp * 100) .. "%)")
        return true
    end
    return false
end

-- Try Power Word: Shield on tank (pre-pull capable)
local function try_shield_tank(me)
    if not resolved.power_word_shield then return false end
    if not (menu.disc_use_shield and menu.disc_use_shield:get_state()) then return false end
    
    local tank = utils.get_tank_unit(me)
    if not tank or not tank:is_valid() or tank:is_dead() then return false end
    
    -- Check Weakened Soul
    if utils.has_debuff(tank, spells.DEBUFF_WEAKENED_SOUL) then return false end
    
    local threshold = (menu.disc_shield_hp and menu.disc_shield_hp:get() or 90) / 100
    local hp = utils.get_health_pct(tank)
    
    -- In combat: only shield if below threshold
    if me:is_in_combat() and hp > threshold then return false end
    
    -- Out of combat: only if prepull setting enabled
    if not me:is_in_combat() and not (menu.disc_prepull_shield and menu.disc_prepull_shield:get_state()) then return false end
    
    -- Don't shield if already has PW:S
    if utils.has_buff(tank, spells.BUFF_POWER_WORD_SHIELD) then return false end
    
    if utils.cast_target(resolved.power_word_shield, me, tank) then
        note_cast()
        utils.log_debug(menu, "PW:Shield on tank (" .. math.floor(hp * 100) .. "%)")
        return true
    end
    return false
end

-- Try Prayer of Mending (instant, on CD)
local function try_prayer_of_mending(me)
    if not resolved.prayer_of_mending then return false end
    if not (menu.disc_use_prayer_of_mending and menu.disc_use_prayer_of_mending:get_state()) then return false end
    if _get_spell_cd(resolved.prayer_of_mending) > 0 then return false end
    
    local tank = utils.get_tank_unit(me)
    local target = tank
    
    if not target or not target:is_valid() or target:is_dead() then
        local threshold = (menu.disc_shield_hp and menu.disc_shield_hp:get() or 90) / 100
        target = utils.find_lowest_effective_ally(me, threshold, false)
    end
    
    if not target or not target:is_valid() or target:is_dead() then return false end
    if utils.has_buff(target, spells.BUFF_PRAYER_OF_MENDING) then return false end
    
    if utils.cast_target(resolved.prayer_of_mending, me, target) then
        note_cast()
        utils.log_debug(menu, "Prayer of Mending")
        return true
    end
    return false
end

-- Try PW:S on non-tank (if not tank-only mode)
local function try_shield_others(me)
    if not resolved.power_word_shield then return false end
    if not (menu.disc_use_shield and menu.disc_use_shield:get_state()) then return false end
    if not me:is_in_combat() then return false end
    if menu.disc_shield_tank_only and menu.disc_shield_tank_only:get_state() then return false end
    
    local threshold = (menu.disc_shield_hp and menu.disc_shield_hp:get() or 90) / 100
    local lowest, lowest_hp = utils.find_lowest_effective_ally(me, threshold, false)
    if not lowest or lowest_hp >= threshold then return false end
    
    -- Skip if this is the tank
    if utils.is_tank_unit(lowest) then return false end
    
    -- Check Weakened Soul
    if utils.has_debuff(lowest, spells.DEBUFF_WEAKENED_SOUL) then return false end
    
    -- Don't shield if already has PW:S
    if utils.has_buff(lowest, spells.BUFF_POWER_WORD_SHIELD) then return false end
    
    if utils.cast_target(resolved.power_word_shield, me, lowest) then
        note_cast()
        utils.log_debug(menu, "PW:Shield on " .. (lowest == me and "self" or "ally") .. " (" .. math.floor(lowest_hp * 100) .. "%)")
        return true
    end
    return false
end

-- Try Renew on tank (pre-pull capable)
local function try_renew_tank(me)
    if not resolved.renew then return false end
    if not (menu.disc_use_renew and menu.disc_use_renew:get_state()) then return false end
    
    local tank = utils.get_tank_unit(me)
    if not tank or not tank:is_valid() or tank:is_dead() then return false end
    
    local threshold = (menu.disc_renew_hp and menu.disc_renew_hp:get() or 85) / 100
    local hp = utils.get_health_pct(tank)
    
    -- In combat: only renew if below threshold
    if me:is_in_combat() and hp > threshold then return false end
    
    -- Out of combat: only if prepull setting enabled
    if not me:is_in_combat() and not (menu.disc_prepull_renew and menu.disc_prepull_renew:get_state()) then return false end
    
    -- Don't renew if already has Renew
    if utils.has_buff(tank, spells.BUFF_RENEW) then return false end
    
    if utils.cast_target(resolved.renew, me, tank) then
        note_cast()
        utils.log_debug(menu, "Renew on tank (" .. math.floor(hp * 100) .. "%)")
        return true
    end
    return false
end

-- Try Greater Heal (sustained healing)
local function try_greater_heal(me)
    if not resolved.greater_heal then return false end
    if not me:is_in_combat() then return false end
    
    local flash_threshold = (menu.disc_flash_heal_hp and menu.disc_flash_heal_hp:get() or 50) / 100
    local renew_threshold = (menu.disc_renew_hp and menu.disc_renew_hp:get() or 85) / 100
    
    local lowest, lowest_hp = utils.find_lowest_effective_ally(me, renew_threshold, false)
    if not lowest then return false end
    
    -- Only GH if between flash and renew thresholds
    if lowest_hp >= renew_threshold or lowest_hp < flash_threshold then return false end
    
    if lowest == me then
        if utils.cast_self(resolved.greater_heal, me) then
            note_cast()
            utils.log_debug(menu, "Greater Heal (self)")
            return true
        end
    else
        if utils.cast_target(resolved.greater_heal, me, lowest) then
            note_cast()
            utils.log_debug(menu, "Greater Heal (" .. math.floor(lowest_hp * 100) .. "%)")
            return true
        end
    end
    return false
end

-- Try Flash Heal (moderate urgency)
local function try_flash_heal(me)
    if not resolved.flash_heal then return false end
    if not me:is_in_combat() then return false end
    
    local threshold = (menu.disc_flash_heal_hp and menu.disc_flash_heal_hp:get() or 50) / 100
    local lowest, lowest_hp = utils.find_lowest_effective_ally(me, threshold, false)
    if not lowest or lowest_hp >= threshold then return false end
    
    -- Skip if below emergency threshold (emergency handler takes priority)
    local emergency_threshold = (menu.disc_emergency_hp and menu.disc_emergency_hp:get() or 25) / 100
    if lowest_hp < emergency_threshold then return false end
    
    if lowest == me then
        if utils.cast_self(resolved.flash_heal, me) then
            note_cast()
            utils.log_debug(menu, "Flash Heal (self)")
            return true
        end
    else
        if utils.cast_target(resolved.flash_heal, me, lowest) then
            note_cast()
            utils.log_debug(menu, "Flash Heal (" .. math.floor(lowest_hp * 100) .. "%)")
            return true
        end
    end
    return false
end

-- Try Renew on injured (HoT spread)
local function try_renew_spread(me)
    if not resolved.renew then return false end
    if not (menu.disc_use_renew and menu.disc_use_renew:get_state()) then return false end
    if not me:is_in_combat() then return false end
    
    local threshold = (menu.disc_renew_hp and menu.disc_renew_hp:get() or 85) / 100
    local lowest, lowest_hp = utils.find_lowest_effective_ally(me, threshold, false)
    if not lowest or lowest_hp >= threshold then return false end
    
    -- Don't renew if already has Renew
    if utils.has_buff(lowest, spells.BUFF_RENEW) then return false end
    
    if utils.cast_target(resolved.renew, me, lowest) then
        note_cast()
        utils.log_debug(menu, "Renew spread (" .. math.floor(lowest_hp * 100) .. "%)")
        return true
    end
    return false
end

-- Try Prayer of Healing (group damage)
local function try_prayer_of_healing(me)
    if not resolved.prayer_of_healing then return false end
    if not (menu.disc_use_prayer_of_healing and menu.disc_use_prayer_of_healing:get_state()) then return false end
    if not me:is_in_combat() then return false end
    
    local min_count = (menu.disc_aoe_count and menu.disc_aoe_count:get() or 3)
    local damaged_count = utils.count_below_hp(me, 0.90)
    
    if damaged_count < min_count then return false end
    
    if utils.cast_self(resolved.prayer_of_healing, me) then
        note_cast()
        utils.log_debug(menu, "Prayer of Healing (" .. damaged_count .. " hurt)")
        return true
    end
    return false
end

-- Try Racial (Berserking/Arcane Torrent)
local function try_racial(me)
    if not me:is_in_combat() then return false end
    if not (menu.use_racial and menu.use_racial:get_state()) then return false end
    
    if resolved.berserking and _get_spell_cd(resolved.berserking) == 0 then
        if utils.cast_self(resolved.berserking, me) then
            note_cast()
            utils.log_debug(menu, "Berserking")
            return true
        end
    end
    
    return false
end

-- Try Fade (threat reduction)
local function try_fade(me)
    if not resolved.fade then return false end
    if not (menu.use_fade and menu.use_fade:get_state()) then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_FADE) then return false end
    
    local hp = utils.get_health_pct(me)
    if hp > 0.50 then return false end
    
    if utils.cast_self(resolved.fade, me) then
        note_cast()
        utils.log_debug(menu, "Fade")
        return true
    end
    return false
end

-- Try Shadowfiend (mana recovery)
local function try_shadowfiend(me)
    if not resolved.shadowfiend then return false end
    if not (menu.use_shadowfiend and menu.use_shadowfiend:get_state()) then return false end
    if not me:is_in_combat() then return false end
    
    local threshold = (menu.shadowfiend_pct and menu.shadowfiend_pct:get() or 50) / 100
    local mana_pct = utils.get_mana_pct(me)
    if mana_pct > threshold then return false end
    
    local now = _core_time()
    if runtime.shadowfiend_last and (now - runtime.shadowfiend_last) < 300 then return false end
    
    local target = me:get_target()
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    
    if utils.cast_target(resolved.shadowfiend, me, target) then
        runtime.shadowfiend_last = now
        note_cast()
        utils.log_debug(menu, "Shadowfiend (mana: " .. math.floor(mana_pct * 100) .. "%)")
        return true
    end
    return false
end

-- Try Desperate Prayer (emergency self-heal)
local function try_desperate_prayer(me)
    if not resolved.desperate_prayer then return false end
    if not me:is_in_combat() then return false end
    
    local hp = utils.get_health_pct(me)
    if hp > 0.30 then return false end
    
    if utils.cast_self(resolved.desperate_prayer, me) then
        note_cast()
        utils.log_debug(menu, "Desperate Prayer (" .. math.floor(hp * 100) .. "%)")
        return true
    end
    return false
end

-- Try Inner Fire (self-buff)
local function try_inner_fire(me)
    if not resolved.inner_fire then return false end
    if not (menu.use_inner_fire and menu.use_inner_fire:get_state()) then return false end
    if me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_INNER_FIRE) then return false end
    
    if utils.cast_self(resolved.inner_fire, me) then
        note_cast()
        utils.log_debug(menu, "Inner Fire")
        return true
    end
    return false
end

-- Try Fear Ward (pre-pull buff)
local function try_fear_ward(me)
    if not resolved.fear_ward then return false end
    if not (menu.use_fear_ward and menu.use_fear_ward:get_state()) then return false end
    if me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_FEAR_WARD) then return false end
    
    if utils.cast_self(resolved.fear_ward, me) then
        note_cast()
        utils.log_debug(menu, "Fear Ward (self)")
        return true
    end
    return false
end

-- Try Fortitude buff
local function try_fortitude(me)
    if not resolved.fortitude then return false end
    if not (menu.use_fortitude and menu.use_fortitude:get_state()) then return false end
    if me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_POWER_WORD_FORT) then return false end
    
    if utils.cast_self(resolved.fortitude, me) then
        note_cast()
        utils.log_debug(menu, "Power Word: Fortitude")
        return true
    end
    return false
end

-- Try Divine Spirit buff
local function try_divine_spirit(me)
    if not resolved.divine_spirit then return false end
    if not (menu.use_divine_spirit and menu.use_divine_spirit:get_state()) then return false end
    if me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_DIVINE_SPIRIT) then return false end
    
    if utils.cast_self(resolved.divine_spirit, me) then
        note_cast()
        utils.log_debug(menu, "Divine Spirit")
        return true
    end
    return false
end

-- Main rotation logic
local function on_update()
    if not menu.is_enabled() then return end
    
    local me = _get_local_player()
    if not me or not me:is_valid() or me:is_dead() then return end
    
    local mode = utils.get_effective_mode(menu, runtime)
    log_mode(mode)
    
    -- OOC buffs
    if not me:is_in_combat() then
        if try_inner_fire(me) then return end
        if try_fear_ward(me) then return end
        if try_fortitude(me) then return end
        if try_divine_spirit(me) then return end
    end
    
    -- Pre-pull shields/renews
    if not me:is_in_combat() then
        if try_shield_tank(me) then return end
        if try_renew_tank(me) then return end
        if try_prayer_of_mending(me) then return end
    end
    
    if not me:is_in_combat() then return end
    
    -- Emergency: Desperate Prayer
    if try_desperate_prayer(me) then return end
    
    -- Off-GCD abilities
    if try_power_infusion(me) then return end
    if try_inner_focus(me) then return end
    
    -- Cooldowns
    if try_pain_suppression(me) then return end
    if try_racial(me) then return end
    
    -- Threat management
    if try_fade(me) then return end
    
    -- Mana recovery
    if try_shadowfiend(me) then return end
    
    -- Emergency healing
    if try_emergency_flash_heal(me) then return end
    
    -- Binding Heal (self + target)
    if try_binding_heal(me) then return end
    
    -- Tank maintenance (PW:S priority for Discipline)
    if try_shield_tank(me) then return end
    
    -- Prayer of Mending (instant)
    if try_prayer_of_mending(me) then return end
    
    -- PW:S on others
    if try_shield_others(me) then return end
    
    -- Renew on tank
    if try_renew_tank(me) then return end
    
    -- AoE healing
    if try_prayer_of_healing(me) then return end
    
    -- Direct heals
    if try_greater_heal(me) then return end
    if try_flash_heal(me) then return end
    
    -- HoT spread
    if try_renew_spread(me) then return end
end

-- Register update callback
core.register_on_update_callback(on_update)

-- Export toggle settings for external access
local NS = _G.EAXPriestDiscipline and _G.EAXPriestDiscipline.NS or {}
_G.EAXPriestDiscipline = _G.EAXPriestDiscipline or {}
_G.EAXPriestDiscipline.NS = NS
NS.toggle_menu = menu.toggle_menu


