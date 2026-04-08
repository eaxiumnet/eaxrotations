-- EAX Port) | main.lua
-- Holy healing rotation with Circle of Healing raid healing, Prayer of Mending bouncing.
-- Source: /rotation/source/aio/priest/holy.lua

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")
local ooc_manager = require("libraries/ooc_manager")

local middleware_manager = require("libraries/middleware_manager")
local dashboard = require("libraries/dashboard")
local dashboard_config = require("libraries/dashboard_config")
local mana_manager = require("libraries/mana_manager")
local trinket_manager = require("libraries/trinket_manager")

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
    _initialized = false,
}

-- ============================================================================

-- ============================================================================

local function init_()
    if runtime._initialized then return end
    
    -- Setup middleware (healthstones, potions, racials)
    middleware_manager.setup(menu, spells)
    
    -- Initialize dashboard
    dashboard.init(dashboard_config)
    local dashboard_enabled = true
    if menu.dashboard_enabled and menu.dashboard_enabled.get_state then
        dashboard_enabled = menu.dashboard_enabled:get_state()
    end
    dashboard.set_enabled(dashboard_enabled)
    dashboard.set_position(
        (menu.dashboard_x and menu.dashboard_x:get()) or 20,
        (menu.dashboard_y and menu.dashboard_y:get()) or 200
    )
    dashboard.set_scale((menu.dashboard_scale and menu.dashboard_scale:get()) or 1.0)
    dashboard.register_render_callback()
    
    runtime._initialized = true
    print("[EAX Holy] integration initialized")
end

-- Resolved spell IDs
local resolved = {
    flash_heal = utils.resolve_spell_id(spells.FLASH_HEAL),
    greater_heal = utils.resolve_spell_id(spells.GREATER_HEAL),
    renew = utils.resolve_spell_id(spells.RENEW),
    power_word_shield = utils.resolve_spell_id(spells.POWER_WORD_SHIELD),
    prayer_of_healing = utils.resolve_spell_id(spells.PRAYER_OF_HEALING),
    prayer_of_mending = utils.resolve_spell_id(spells.PRAYER_OF_MENDING),
    circle_of_healing = utils.resolve_spell_id(spells.CIRCLE_OF_HEALING),
    binding_heal = utils.resolve_spell_id(spells.BINDING_HEAL),
    inner_focus = utils.resolve_spell_id(spells.INNER_FOCUS),
    inner_fire = utils.resolve_spell_id(spells.INNER_FIRE),
    fortitude = utils.resolve_spell_id(spells.POWER_WORD_FORTITUDE),
    divine_spirit = utils.resolve_spell_id(spells.DIVINE_SPIRIT),
    shadow_protection = utils.resolve_spell_id(spells.SHADOW_PROTECTION),
    fear_ward = utils.resolve_spell_id(spells.FEAR_WARD),
    fade = utils.resolve_spell_id(spells.FADE),
    shadowfiend = utils.resolve_spell_id(spells.SHADOWFIEND),
    dispel_magic = utils.resolve_spell_id(spells.DISPEL_MAGIC),
    cure_disease = utils.resolve_spell_id(spells.CURE_DISEASE),
    smite = utils.resolve_spell_id(spells.SMITE),
    holy_fire = utils.resolve_spell_id(spells.HOLY_FIRE),
    shadow_word_pain = utils.resolve_spell_id(spells.DEBUFF_SHADOW_WORD_PAIN),
    desperate_prayer = utils.resolve_spell_id(spells.DESPERATE_PRAYER),
    berserking = utils.resolve_spell_id(spells.BERSERKING),
    resurrection = utils.resolve_spell_id(spells.RESURRECTION),
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

-- Check if Inner Focus is available
local function is_inner_focus_ready()
    if not resolved.inner_focus then return false end
    return _get_spell_cd(resolved.inner_focus) == 0
end

-- Check if Circle of Healing is available
local function is_coh_ready()
    if not resolved.circle_of_healing then return false end
    return _get_spell_cd(resolved.circle_of_healing) == 0
end

-- Check if Prayer of Mending is available
local function is_pom_ready()
    if not resolved.prayer_of_mending then return false end
    return _get_spell_cd(resolved.prayer_of_mending) == 0
end

-- Try Emergency PW:S (instant shield on critically low target)
local function try_emergency_pws(me)
    if not resolved.power_word_shield then return false end
    if not ((menu.use_power_word_shield and menu.use_power_word_shield:get_state()) or 
            (menu.holy_use_pws and menu.holy_use_pws:get_state())) then return false end
    
    local threshold = ((menu.power_word_shield_hp_pct and menu.power_word_shield_hp_pct:get()) or 
                      (menu.holy_pws_hp and menu.holy_pws_hp:get()) or 30) / 100
    local lowest, lowest_hp = utils.find_lowest_effective_ally(me, threshold, false)
    if not lowest or lowest_hp >= threshold then return false end
    
    -- Check Weakened Soul
    if utils.has_debuff(lowest, spells.DEBUFF_WEAKENED_SOUL) then return false end
    
    -- Don't shield if already has PW:S
    if utils.has_buff(lowest, spells.BUFF_POWER_WORD_SHIELD) then return false end
    
    if utils.cast_target(resolved.power_word_shield, me, lowest) then
        note_cast()
        utils.log_debug(menu, "Emergency PW:S on " .. (lowest == me and "self" or "ally") .. " (" .. math.floor(lowest_hp * 100) .. "%)")
        return true
    end
    return false
end

-- Try Emergency Flash Heal
local function try_emergency_flash_heal(me)
    if not resolved.flash_heal then return false end
    if not me:is_in_combat() then return false end
    
    local threshold = (menu.holy_emergency_hp and menu.holy_emergency_hp:get() or 30) / 100
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

-- Try Prayer of Mending (instant, on CD, tank priority - PRE-PULL capable)
local function try_prayer_of_mending(me)
    if not resolved.prayer_of_mending then return false end
    if not ((menu.use_prayer_of_mending and menu.use_prayer_of_mending:get_state()) or
            (menu.holy_use_pom and menu.holy_use_pom:get_state())) then return false end
    if not is_pom_ready() then return false end
    
    -- Pre-pull: gate OOC usage on setting
    if not me:is_in_combat() and not ((menu.prepull_pom and menu.prepull_pom:get_state()) or
                                       (menu.holy_prepull_pom and menu.holy_prepull_pom:get_state())) then
        return false
    end
    
    local tank = utils.get_tank_unit(me)
    local target = tank
    
    if not target or not target:is_valid() or target:is_dead() then
        local threshold = (menu.holy_renew_hp and menu.holy_renew_hp:get() or 90) / 100
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

-- Try Circle of Healing (instant AoE, group damage)
local function try_circle_of_healing(me)
    if not resolved.circle_of_healing then return false end
    if not ((menu.use_circle_of_healing and menu.use_circle_of_healing:get_state()) or
            (menu.holy_use_coh and menu.holy_use_coh:get_state())) then return false end
    if not is_coh_ready() then return false end
    if not me:is_in_combat() then return false end
    
    local threshold = ((menu.circle_of_healing_threshold and menu.circle_of_healing_threshold:get()) or
                      (menu.holy_aoe_hp and menu.holy_aoe_hp:get()) or 80) / 100
    local min_count = ((menu.circle_of_healing_count and menu.circle_of_healing_count:get()) or
                       (menu.holy_aoe_count and menu.holy_aoe_count:get()) or 3)
    
    local damaged_count = utils.count_below_hp(me, threshold)
    if damaged_count < min_count then return false end
    
    -- Find best target (lowest HP in group)
    local lowest, lowest_hp = utils.find_lowest_effective_ally(me, threshold, false)
    if not lowest then return false end
    
    if utils.cast_target(resolved.circle_of_healing, me, lowest) then
        note_cast()
        utils.log_debug(menu, "Circle of Healing (" .. damaged_count .. " hurt)")
        return true
    end
    return false
end

-- Try Binding Heal (self + target both damaged)
local function try_binding_heal(me)
    if not resolved.binding_heal then return false end
    if not ((menu.use_binding_heal and menu.use_binding_heal:get_state()) or
            (menu.holy_use_binding_heal and menu.holy_use_binding_heal:get_state())) then return false end
    if not me:is_in_combat() then return false end
    
    local self_threshold = ((menu.binding_heal_self_threshold and menu.binding_heal_self_threshold:get()) or
                            (menu.holy_binding_self_hp and menu.holy_binding_self_hp:get()) or 80) / 100
    local self_hp = utils.get_health_pct(me)
    if self_hp > self_threshold then return false end
    
    local target_threshold = ((menu.binding_heal_target_threshold and menu.binding_heal_target_threshold:get()) or
                              (menu.holy_flash_heal_hp and menu.holy_flash_heal_hp:get()) or 50) / 100
    local lowest, lowest_hp = utils.find_lowest_effective_ally(me, target_threshold, true) -- skip self
    if not lowest or lowest_hp >= target_threshold then return false end
    
    if utils.cast_target(resolved.binding_heal, me, lowest) then
        note_cast()
        utils.log_debug(menu, "Binding Heal (self: " .. math.floor(self_hp * 100) .. "%, target: " .. math.floor(lowest_hp * 100) .. "%)")
        return true
    end
    return false
end

-- Try Clearcasting Greater Heal (free heal from Holy Concentration)
local function try_clearcasting_greater_heal(me)
    if not resolved.greater_heal then return false end
    if not me:is_in_combat() then return false end
    
    -- Check for Clearcasting buff
    if not utils.has_buff(me, spells.BUFF_CLEARCASTING) then return false end
    
    local lowest, lowest_hp = utils.find_lowest_effective_ally(me, 0.95, false)
    if not lowest or lowest_hp >= 0.95 then return false end
    
    if lowest == me then
        if utils.cast_self(resolved.greater_heal, me) then
            note_cast()
            utils.log_debug(menu, "Clearcasting Greater Heal (self)")
            return true
        end
    else
        if utils.cast_target(resolved.greater_heal, me, lowest) then
            note_cast()
            utils.log_debug(menu, "Clearcasting Greater Heal (" .. math.floor(lowest_hp * 100) .. "%)")
            return true
        end
    end
    return false
end

-- Try Renew on tank (maintain HoT - PRE-PULL capable)
local function try_renew_tank(me)
    if not resolved.renew then return false end
    
    local tank = utils.get_tank_unit(me)
    if not tank or not tank:is_valid() or tank:is_dead() then return false end
    
    local threshold = (menu.holy_renew_hp and menu.holy_renew_hp:get() or 90) / 100
    local hp = utils.get_health_pct(tank)
    
    -- In combat: only renew if below threshold
    if me:is_in_combat() and hp > threshold then return false end
    
    -- Out of combat: only if prepull setting enabled
    if not me:is_in_combat() and not (menu.holy_prepull_renew and menu.holy_prepull_renew:get_state()) then
        return false
    end
    
    -- Don't renew if already has Renew
    if utils.has_buff(tank, spells.BUFF_RENEW) then return false end
    
    if utils.cast_target(resolved.renew, me, tank) then
        note_cast()
        utils.log_debug(menu, "Renew on tank (" .. math.floor(hp * 100) .. "%)")
        return true
    end
    return false
end

-- Try Renew on injured (HoT spread)
local function try_renew_spread(me)
    if not resolved.renew then return false end
    if not me:is_in_combat() then return false end
    
    local threshold = (menu.holy_renew_hp and menu.holy_renew_hp:get() or 90) / 100
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

-- Try Inner Focus (off-GCD, fire before Greater Heal)
local function try_inner_focus(me)
    if not resolved.inner_focus then return false end
    if not (menu.holy_use_inner_focus and menu.holy_use_inner_focus:get_state()) then return false end
    if not is_inner_focus_ready() then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_INNER_FOCUS) then return false end
    
    -- Only use if we have a target that needs healing
    local threshold = (menu.holy_renew_hp and menu.holy_renew_hp:get() or 90) / 100
    local lowest, lowest_hp = utils.find_lowest_effective_ally(me, threshold, false)
    if not lowest or lowest_hp >= threshold then return false end
    
    if utils.cast_self(resolved.inner_focus, me) then
        note_cast()
        utils.log_debug(menu, "Inner Focus (for Greater Heal)")
        return true
    end
    return false
end

-- Try Greater Heal (sustained healing)
local function try_greater_heal(me)
    if not resolved.greater_heal then return false end
    if not me:is_in_combat() then return false end
    
    local flash_threshold = (menu.holy_flash_heal_hp and menu.holy_flash_heal_hp:get() or 50) / 100
    local renew_threshold = (menu.holy_renew_hp and menu.holy_renew_hp:get() or 90) / 100
    
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

-- Try Flash Heal (urgent healing)
local function try_flash_heal(me)
    if not resolved.flash_heal then return false end
    if not me:is_in_combat() then return false end
    
    local threshold = (menu.holy_flash_heal_hp and menu.holy_flash_heal_hp:get() or 50) / 100
    local lowest, lowest_hp = utils.find_lowest_effective_ally(me, threshold, false)
    if not lowest or lowest_hp >= threshold then return false end
    
    -- Skip if below emergency threshold
    local emergency_threshold = (menu.holy_emergency_hp and menu.holy_emergency_hp:get() or 30) / 100
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

-- Try Prayer of Healing (channeled AoE heal)
local function try_prayer_of_healing(me)
    if not resolved.prayer_of_healing then return false end
    if not ((menu.use_prayer_of_healing and menu.use_prayer_of_healing:get_state()) or
            (menu.holy_use_poh and menu.holy_use_poh:get_state())) then return false end
    if not me:is_in_combat() then return false end
    
    local min_count = ((menu.prayer_of_healing_count and menu.prayer_of_healing_count:get()) or
                       (menu.holy_aoe_count and menu.holy_aoe_count:get()) or 3)
    local damaged_count = utils.count_below_hp(me, 0.80)
    
    if damaged_count < min_count then return false end
    
    if utils.cast_self(resolved.prayer_of_healing, me) then
        note_cast()
        utils.log_debug(menu, "Prayer of Healing (" .. damaged_count .. " hurt)")
        return true
    end
    return false
end

-- Try Racial (Berserking)
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

-- Try Trinkets (mana/spellpower/defensive)
local function try_trinkets(me)
    if not me:is_in_combat() then return false end
    
    local trinket1_mode = (menu.trinket1_mode and menu.trinket1_mode:get()) or 1
    local trinket2_mode = (menu.trinket2_mode and menu.trinket2_mode:get()) or 1
    
    -- Skip if both trinkets are off
    if trinket1_mode == 1 and trinket2_mode == 1 then return false end
    
    local used = false
    local self_hp = utils.get_health_pct(me)
    
    -- Check for urgent healing needed (don't use offensive trinkets if critical)
    local emergency_threshold = (menu.holy_emergency_hp and menu.holy_emergency_hp:get() or 30) / 100
    local has_emergency = false
    local lowest_hp = utils.find_lowest_effective_ally(me, emergency_threshold, false)
    if lowest_hp and lowest_hp < emergency_threshold then
        has_emergency = true
    end
    
    -- Trinket slot 13 (trinket 1)
    if trinket1_mode == 2 then  -- Offensive
        -- Only use offensive if no emergency and we have a valid target
        if not has_emergency then
            local target = me:get_target()
            if target and target:is_valid() and not target:is_dead() and me:can_attack(target) then
                if trinket_manager.use_trinket_if_ready(13) then
                    utils.log_debug(menu, "Trinket 1 (Offensive)")
                    used = true
                end
            end
        end
    elseif trinket1_mode == 3 then  -- Defensive
        -- Use defensive trinket when HP is low
        if self_hp < 0.50 then
            if trinket_manager.use_trinket_if_ready(13) then
                utils.log_debug(menu, "Trinket 1 (Defensive)")
                used = true
            end
        end
    end
    
    -- Trinket slot 14 (trinket 2)
    if trinket2_mode == 2 then  -- Offensive
        if not has_emergency then
            local target = me:get_target()
            if target and target:is_valid() and not target:is_dead() and me:can_attack(target) then
                if trinket_manager.use_trinket_if_ready(14) then
                    utils.log_debug(menu, "Trinket 2 (Offensive)")
                    used = true
                end
            end
        end
    elseif trinket2_mode == 3 then  -- Defensive
        if self_hp < 0.50 then
            if trinket_manager.use_trinket_if_ready(14) then
                utils.log_debug(menu, "Trinket 2 (Defensive)")
                used = true
            end
        end
    end
    
    return used
end

-- Try Surge of Light Smite (free instant Smite proc)
local function try_surge_of_light_smite(me)
    if not resolved.smite then return false end
    if not me:is_in_combat() then return false end
    
    -- Check for Surge of Light buff
    if not utils.has_buff(me, spells.BUFF_SURGE_OF_LIGHT) then return false end
    
    -- Need valid enemy target
    local target = me:get_target()
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    
    -- Only cast if no urgent healing needed
    local threshold = (menu.holy_flash_heal_hp and menu.holy_flash_heal_hp:get() or 50) / 100
    local lowest_hp = utils.get_health_pct(me)
    if lowest_hp < threshold then return false end
    
    if utils.cast_target(resolved.smite, me, target) then
        note_cast()
        utils.log_debug(menu, "Surge of Light Smite")
        return true
    end
    return false
end

-- Try Idle DPS (when everyone healthy)
local function try_idle_dps(me)
    if not me:is_in_combat() then return false end
    if not (menu.holy_dps_when_idle and menu.holy_dps_when_idle:get_state()) then return false end
    
    -- Check mana floor
    local mana_floor = (menu.holy_dps_mana_floor and menu.holy_dps_mana_floor:get() or 70) / 100
    local mana_pct = utils.get_mana_pct(me)
    if mana_pct < mana_floor then return false end
    
    -- Check if everyone is healthy
    local threshold = (menu.holy_renew_hp and menu.holy_renew_hp:get() or 90) / 100
    local lowest, lowest_hp = utils.find_lowest_effective_ally(me, threshold, false)
    if lowest and lowest_hp < threshold then return false end
    
    -- Need valid enemy target
    local target = me:get_target()
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    
    -- Try Holy Fire first (if not on target)
    if resolved.holy_fire and not utils.has_debuff(target, spells.DEBUFF_HOLY_FIRE) then
        if utils.cast_target(resolved.holy_fire, me, target) then
            note_cast()
            utils.log_debug(menu, "Idle Holy Fire")
            return true
        end
    end
    
    -- Try SW:P (if not on target)
    if resolved.shadow_word_pain and not utils.has_debuff(target, spells.DEBUFF_SHADOW_WORD_PAIN) then
        if utils.cast_target(resolved.shadow_word_pain, me, target) then
            note_cast()
            utils.log_debug(menu, "Idle SW:P")
            return true
        end
    end
    
    -- Fallback to Smite
    if resolved.smite then
        if utils.cast_target(resolved.smite, me, target) then
            note_cast()
            utils.log_debug(menu, "Idle Smite")
            return true
        end
    end
    
    return false
end

-- Try Holy Nova (AoE heal when enemies close)
local function try_holy_nova(me)
    if not resolved.holy_nova then return false end
    if not ((menu.use_holy_nova and menu.use_holy_nova:get_state()) or
            (menu.holy_use_nova and menu.holy_use_nova:get_state())) then return false end
    if not me:is_in_combat() then return false end
    
    -- Check if enemies are in close range (10 yards for Holy Nova)
    local target = me:get_target()
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    
    -- Check distance (squared distance for performance)
    local dist_sq = utils.dist_squared(me, target)
    if dist_sq > 100 then return false end -- 10 yards squared
    
    -- Check if we need healing (self or nearby allies)
    local self_hp = utils.get_health_pct(me)
    local threshold = ((menu.holy_aoe_hp and menu.holy_aoe_hp:get()) or 80) / 100
    
    -- Only use if self is injured or there are injured allies
    if self_hp > threshold then
        local injured_count = utils.count_below_hp(me, threshold)
        if injured_count < 2 then return false end
    end
    
    if utils.cast_self(resolved.holy_nova, me) then
        note_cast()
        utils.log_debug(menu, "Holy Nova (enemies close)")
        return true
    end
    return false
end

-- Try Dispel Magic (remove harmful magic debuffs)
local function try_dispel_magic(me)
    if not resolved.dispel_magic then return false end
    if not ((menu.use_dispel_magic and menu.use_dispel_magic:get_state()) or
            (menu.use_dispels and menu.use_dispels:get_state())) then return false end
    if not me:is_in_combat() then return false end
    
    -- Use heal_context to get injured allies with debuffs
    local heal_context = require("libraries/heal_context")
    local ctx = heal_context.get_context(me)
    
    -- Check self first
    local self_has_magic_debuff = false
    local ok, has_debuff = pcall(function()
        return me:has_debuff_type("Magic")
    end)
    if ok and has_debuff then
        self_has_magic_debuff = true
    end
    
    if self_has_magic_debuff then
        if utils.cast_self(resolved.dispel_magic, me) then
            note_cast()
            utils.log_debug(menu, "Dispel Magic (self)")
            return true
        end
    end
    
    -- Check injured allies
    if ctx and ctx.injured and ctx.injured.n > 0 then
        for i = 1, ctx.injured.n do
            local ally = ctx.injured[i]
            if ally and ally:is_valid() and not ally:is_dead() then
                local ally_ok, ally_has_magic = pcall(function()
                    return ally:has_debuff_type("Magic")
                end)
                if ally_ok and ally_has_magic then
                    if utils.cast_target(resolved.dispel_magic, me, ally) then
                        note_cast()
                        utils.log_debug(menu, "Dispel Magic (ally)")
                        return true
                    end
                end
            end
        end
    end
    
    return false
end

-- Try Cure Disease / Abolish Disease
local function try_cure_disease(me)
    if not me:is_in_combat() then return false end
    
    local use_dispels = (menu.use_dispels and menu.use_dispels:get_state()) or
                        (menu.use_cure_disease and menu.use_cure_disease:get_state())
    if not use_dispels then return false end
    
    -- Prefer Abolish Disease if available (it's a HoT that prevents disease)
    local abolish_first = resolved.abolish_disease and 
                          ((menu.use_abolish_disease and menu.use_abolish_disease:get_state()) or true)
    
    local spell_to_use = nil
    if abolish_first and resolved.abolish_disease then
        spell_to_use = resolved.abolish_disease
    elseif resolved.cure_disease then
        spell_to_use = resolved.cure_disease
    end
    
    if not spell_to_use then return false end
    
    -- Use heal_context to get injured allies
    local heal_context = require("libraries/heal_context")
    local ctx = heal_context.get_context(me)
    
    -- Check self first
    local self_has_disease = false
    local ok, has_debuff = pcall(function()
        return me:has_debuff_type("Disease")
    end)
    if ok and has_debuff then
        self_has_disease = true
    end
    
    if self_has_disease then
        if utils.cast_self(spell_to_use, me) then
            note_cast()
            utils.log_debug(menu, "Cure Disease (self)")
            return true
        end
    end
    
    -- Check injured allies
    if ctx and ctx.injured and ctx.injured.n > 0 then
        for i = 1, ctx.injured.n do
            local ally = ctx.injured[i]
            if ally and ally:is_valid() and not ally:is_dead() then
                local ally_ok, ally_has_disease = pcall(function()
                    return ally:has_debuff_type("Disease")
                end)
                if ally_ok and ally_has_disease then
                    if utils.cast_target(spell_to_use, me, ally) then
                        note_cast()
                        utils.log_debug(menu, "Cure Disease (ally)")
                        return true
                    end
                end
            end
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
    if not (menu.enabled and menu.enabled:get_state()) then return end
    
    local me = _get_local_player()
    if not me or not me:is_valid() or me:is_dead() then return end
    
    -- Crowd Control check - return early if stunned/silenced/feared etc.
    if utils.is_cced and utils.is_cced(me) then return end
    
    
    if not runtime._initialized then
        init_()
    end
    
    local mode = utils.get_effective_mode(menu, runtime)
    log_mode(mode)
    
    -- Mana recovery check (healers need reliable mana)
    if (menu.use_mana_manager and menu.use_mana_manager:get()) then
        local used_mana, mana_type = mana_manager.check_and_recover(me, menu, mana_manager.CLASS_RECOVERY.PRIEST)
        if used_mana then
            -- Mana recovery triggered
        end
    end
    
    -- Execute middleware (healthstones, potions, racials)
    local target = me:get_target()
    local mw_result, mw_msg = middleware_manager.execute_middleware(nil, me, target)
    if mw_result then
        note_cast()
        utils.log_debug(menu, mw_msg or "Middleware executed")
        return
    end
    
    -- CC Detection: Stop rotation if crowd controlled
    local cc_detector = require("libraries/cc_detector")
    local should_stop, cc_reason = cc_detector.should_stop_rotation(me)

    if should_stop then
        if (menu.debug and menu.debug:get_state()) then
            print(string.format("[CC] Rotation paused: %s", cc_reason or "CC"))
        end
        return  -- Stop rotation while CC'd
    end
    
    -- OOC buffs and resurrection via ooc_manager
    if not me:is_in_combat() then
        ooc_manager.on_update(me, menu, utils, {
            rez_spell_id = resolved.resurrection,
            group_buffs = {
                {
                    spell_id = resolved.inner_fire,
                    buff_ids = spells.BUFF_INNER_FIRE,
                    name = "Inner Fire",
                    toggle = menu.use_inner_fire
                },
                {
                    spell_id = resolved.fortitude,
                    buff_ids = spells.BUFF_POWER_WORD_FORTITUDE,
                    name = "Fortitude",
                    toggle = menu.use_power_word_fortitude
                },
                {
                    spell_id = resolved.divine_spirit,
                    buff_ids = spells.BUFF_DIVINE_SPIRIT,
                    name = "Divine Spirit",
                    toggle = menu.use_divine_spirit
                },
                {
                    spell_id = resolved.shadow_protection,
                    buff_ids = spells.BUFF_SHADOW_PROTECTION,
                    name = "Shadow Protection",
                    toggle = menu.use_shadow_protection
                },
                {
                    spell_id = resolved.fear_ward,
                    buff_ids = spells.BUFF_FEAR_WARD,
                    name = "Fear Ward",
                    toggle = menu.use_fear_ward
                },
            }
        })
    end
    
    -- Pre-pull PoM and Renew
    if not me:is_in_combat() then
        if try_prayer_of_mending(me) then return end
        if try_renew_tank(me) then return end
    end
    
    if not me:is_in_combat() then return end
    
    -- Emergency: Desperate Prayer
    if try_desperate_prayer(me) then return end
    
    -- Off-GCD: Inner Focus
    if try_inner_focus(me) then return end
    
    -- Cooldowns
    if try_racial(me) then return end
    
    -- Trinkets (mana/spellpower/defensive)
    try_trinkets(me)
    
    -- Threat management
    if try_fade(me) then return end
    
    -- Mana recovery
    if try_shadowfiend(me) then return end
    
    -- Emergency healing
    if try_emergency_pws(me) then return end
    if try_emergency_flash_heal(me) then return end
    
    -- Dispels (high priority)
    if try_dispel_magic(me) then return end
    if try_cure_disease(me) then return end
    
    -- Clearcasting proc
    if try_clearcasting_greater_heal(me) then return end
    
    -- Prayer of Mending (instant)
    if try_prayer_of_mending(me) then return end
    
    -- Circle of Healing (instant AoE - Holy specialty)
    if try_circle_of_healing(me) then return end
    
    -- Holy Nova (when enemies close)
    if try_holy_nova(me) then return end
    
    -- Binding Heal
    if try_binding_heal(me) then return end
    
    -- Tank maintenance
    if try_renew_tank(me) then return end
    
    -- AoE healing
    if try_prayer_of_healing(me) then return end
    
    -- Direct heals
    if try_greater_heal(me) then return end
    if try_flash_heal(me) then return end
    
    -- HoT spread
    if try_renew_spread(me) then return end
    
    -- Surge of Light proc
    if try_surge_of_light_smite(me) then return end
    
    -- Idle DPS (when everyone healthy)
    if try_idle_dps(me) then return end
end

-- Register update callback
core.register_on_update_callback(on_update)

-- Menu rendering is now handled internally by simple_ui in libraries/menu.lua
-- No need to set up window or register render callbacks manually
-- Menu toggle key is configured as NUMPAD MULTIPLY (keycode 106) in menu.lua

-- Control panel
local control_panel_utility = require("common/utility/control_panel_helper")
local key_helper = require("common/utility/key_helper")

local function on_control_panel()
    local elements = {}
    local function add_toggle(label, item, uid)
        if not item then return end
        local current = item:get_state()
        local next_state = control_panel_utility:insert_key_checkbox_(elements, label, current, 0, false, uid)
        if next_state ~= current then
            item:set(next_state)
        end
    end

    local toggle_key_code = 106
        if menu.toggle_key and menu.toggle_key.get_key_code then
            toggle_key_code = menu.toggle_key:get_key_code()
        end
    local display_name = "[EAX] Enabled"
    if toggle_key_code ~= 7 then
        display_name = "[EAX] Enabled (" .. key_helper:get_key_name(toggle_key_code) .. ")"
    end

    add_toggle(display_name, menu.enabled, "eax_priestholyenabled_cp")

    if menu and menu.enabled and menu.enabled:get_state() then
        add_toggle("[EAX Holy] CoH", (menu.use_circle_of_healing or menu.holy_use_coh), "eax_holy_coh_cp")
        add_toggle("[EAX Holy] PoM", (menu.use_prayer_of_mending or menu.holy_use_pom), "eax_holy_pom_cp")
        add_toggle("[EAX Holy] PoH", (menu.use_prayer_of_healing or menu.holy_use_poh), "eax_holy_poh_cp")
    end

    return elements
end

core.register_on_render_control_panel_callback(on_control_panel)

-- Export toggle settings for external access
local NS = _G.EAXPriestHoly and _G.EAXPriestHoly.NS or {}
_G.EAXPriestHoly = _G.EAXPriestHoly or {}
_G.EAXPriestHoly.NS = NS
NS.toggle_menu = menu.toggle_menu


