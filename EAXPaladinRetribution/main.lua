-- EAX Paladin Retribution | main.lua
-- Retribution DPS rotation ported with seal twisting

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")
local dashboard = require("libraries/dashboard")
local dashboard_config = require("libraries/dashboard_config")

---@type buff_manager
local buff_manager = require("common/modules/buff_manager")
---@type racial_manager
local racial_manager = require("libraries/racial_manager")
---@type defensive_manager
local defensive_manager = require("libraries/defensive_manager")
---@type consumables_manager
local consumables_manager = require("libraries/consumables_manager")
---@type interrupt_manager
local interrupt_manager = require("libraries/interrupt_manager")
---@type burst_manager
local burst_manager = require("libraries/burst_manager")
---@type trinket_manager
local trinket_manager = require("libraries/trinket_manager")
local middleware_manager = require("libraries/middleware_manager")
local ooc_manager = require("../libraries/ooc_manager")

-- Flux Feature Integration
local combat_forecast = require("libraries/combat_forecast")
local force_commands = require("libraries/force_commands")
local swing_manager = require("libraries/swing_manager")

-- Hot-path local caching
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown
local _get_spell_cd = core.spell_book.get_spell_cooldown

local runtime = {
    crusader_strike_id = nil,
    judgement_id = nil,
    hammer_of_wrath_id = nil,
    exorcism_id = nil,
    consecration_id = nil,
    avenging_wrath_id = nil,
    divine_favor_id = nil,
    divine_shield_id = nil,
    lay_on_hands_id = nil,
    seal_of_command_id = nil,
    seal_of_blood_id = nil,
    seal_of_martyr_id = nil,
    seal_of_vengeance_id = nil,
    seal_of_corruption_id = nil,
    seal_of_righteousness_id = nil,
    seal_of_crusader_id = nil,
    seal_of_wisdom_id = nil,
    hand_of_freedom_id = nil,
    cleanse_id = nil,
    hammer_of_justice_id = nil,
    sanctity_aura_id = nil,
    devotion_aura_id = nil,
    blessing_of_might_id = nil,
    blessing_of_kings_id = nil,
    last_cast_time = 0,
    last_aura_cast_at = 0,
    last_ooc_buff_at = 0,
    last_twist_at = 0,
    twist_state = "idle",
    twist_seal_id = nil,
    twist_seal_name = nil,
    vengeance_stacks = 0,
    last_vengeance_check = 0,
    is_horde = false,
    combat_start_time = nil,
}

local AURA_RETRY_WINDOW = 12.0
local BUFF_RETRY_WINDOW = 6.0
local SEAL_TWIST_INPUT_DELAY_MS = 100
local SEAL_TWIST_CONFIRM_TIMEOUT_S = 0.75

local function resolve_spells()
    runtime.crusader_strike_id = utils.resolve_spell_id(spells.CRUSADER_STRIKE)
    runtime.judgement_id = utils.resolve_spell_id(spells.JUDGEMENT)
    runtime.hammer_of_wrath_id = utils.resolve_spell_id(spells.HAMMER_OF_WRATH)
    runtime.exorcism_id = utils.resolve_spell_id(spells.EXORCISM)
    runtime.consecration_id = utils.resolve_spell_id(spells.CONSECRATION)
    runtime.avenging_wrath_id = utils.resolve_spell_id(spells.AVENGING_WRATH)
    runtime.divine_favor_id = utils.resolve_spell_id(spells.DIVINE_FAVOR)
    runtime.divine_shield_id = utils.resolve_spell_id(spells.DIVINE_SHIELD)
    runtime.lay_on_hands_id = utils.resolve_spell_id(spells.LAY_ON_HANDS)
    runtime.seal_of_command_id = utils.resolve_spell_id(spells.SEAL_OF_COMMAND)
    runtime.seal_of_blood_id = utils.resolve_spell_id(spells.SEAL_OF_BLOOD)
    runtime.seal_of_martyr_id = utils.resolve_spell_id(spells.SEAL_OF_MARTYR)
    runtime.seal_of_vengeance_id = utils.resolve_spell_id(spells.SEAL_OF_VENGEANCE)
    runtime.seal_of_corruption_id = utils.resolve_spell_id(spells.SEAL_OF_CORRUPTION)
    runtime.seal_of_righteousness_id = utils.resolve_spell_id(spells.SEAL_OF_RIGHTEOUSNESS)
    runtime.seal_of_crusader_id = utils.resolve_spell_id(spells.SEAL_OF_THE_CRUSADER)
    runtime.seal_of_wisdom_id = utils.resolve_spell_id(spells.SEAL_OF_WISDOM)
    runtime.hand_of_freedom_id = utils.resolve_spell_id(spells.HAND_OF_FREEDOM)
    runtime.cleanse_id = utils.resolve_spell_id(spells.CLEANSE)
    runtime.hammer_of_justice_id = utils.resolve_spell_id(spells.HAMMER_OF_JUSTICE)
    runtime.sanctity_aura_id = utils.resolve_spell_id(spells.SANCTITY_AURA)
    runtime.devotion_aura_id = utils.resolve_spell_id(spells.DEVOTION_AURA)
    runtime.blessing_of_might_id = utils.resolve_spell_id(spells.BLESSING_OF_MIGHT)
    runtime.blessing_of_kings_id = utils.resolve_spell_id(spells.BLESSING_OF_KINGS)
    runtime.blessing_of_wisdom_id = utils.resolve_spell_id(spells.BLESSING_OF_WISDOM)
    runtime.righteous_fury_id = utils.resolve_spell_id(spells.RIGHTEOUS_FURY)
end

resolve_spells()

-- Initialize Flux force_commands
force_commands:init()

-- Spell casting helpers
local function try_cast_self(spell_id, me, label)
    if not spell_id or not me then return false end
    if not utils.can_cast_self(spell_id, me) then return false end
    if utils.cast_self(spell_id, me) then
        utils.log_debug(menu, label or "Self cast")
        return true
    end
    return false
end

local function try_cast_target(spell_id, me, target, label)
    if not spell_id or not me or not target then return false end
    if not utils.can_cast_hostile(spell_id, me, target) then return false end
    if utils.cast_target(spell_id, me, target) then
        utils.log_debug(menu, label or "Target cast")
        return true
    end
    return false
end

-- Aura management
local function ensure_aura(me)
    if not (menu.use_aura and menu.use_aura:get_state()) then return false end
    if not me or me:is_dead() then return false end
    if not runtime.sanctity_aura_id then return false end
    
    local now = _core_time()
    if (now - runtime.last_aura_cast_at) < AURA_RETRY_WINDOW then return false end
    
    if not utils.has_buff(me, spells.BUFF_SANCTITY_AURA) then
        if try_cast_self(runtime.sanctity_aura_id, me, "Sanctity Aura") then
            runtime.last_aura_cast_at = now
            return true
        end
    end
    return false
end

-- Seal management
local function ensure_baseline_seal(me)
    if not me or me:is_dead() then return false end
    
    local now = _core_time()
    if (now - runtime.last_twist_at) < ((menu.seal_twist_cooldown and menu.seal_twist_cooldown:get()) or 3) then return false end
    
    local has_seal = utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND) or
                     utils.has_buff(me, spells.BUFF_SEAL_OF_VENGEANCE) or
                     utils.has_buff(me, spells.BUFF_SEAL_OF_RIGHTEOUSNESS) or
                     utils.has_buff(me, spells.BUFF_SEAL_OF_BLOOD) or
                     utils.has_buff(me, spells.BUFF_SEAL_OF_MARTYR)
    
    if has_seal then return false end
    
    local seal_id = nil
    local seal_name = nil
    
    if runtime.seal_of_command_id and (menu.use_seal_of_command and menu.use_seal_of_command:get_state()) then
        seal_id = runtime.seal_of_command_id
        seal_name = "Seal of Command"
    elseif runtime.seal_of_vengeance_id and (menu.use_seal_of_vengeance and menu.use_seal_of_vengeance:get_state()) then
        seal_id = runtime.seal_of_vengeance_id
        seal_name = "Seal of Vengeance"
    elseif runtime.seal_of_righteousness_id and (menu.use_seal_of_righteousness and menu.use_seal_of_righteousness:get_state()) then
        seal_id = runtime.seal_of_righteousness_id
        seal_name = "Seal of Righteousness"
    end
    
    if seal_id and try_cast_self(seal_id, me, seal_name) then
        return true
    end
    return false
end

-- Seal twisting logic
local function begin_seal_twist(me, target)
    if not (menu.use_seal_twist and menu.use_seal_twist:get_state()) then return false end
    if not me or me:is_dead() then return false end
    if not target or not target:is_valid() then return false end
    
    local now = _core_time()
    if (now - runtime.last_twist_at) < ((menu.seal_twist_cooldown and menu.seal_twist_cooldown:get()) or 3) then return false end
    
    -- Check if we have a seal active that can be twisted
    local has_command = utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND)
    local has_vengeance = utils.has_buff(me, spells.BUFF_SEAL_OF_VENGEANCE)
    local has_blood = utils.has_buff(me, spells.BUFF_SEAL_OF_BLOOD)
    local has_martyr = utils.has_buff(me, spells.BUFF_SEAL_OF_MARTYR)
    
    if not (has_command or has_vengeance or has_blood or has_martyr) then return false end
    
    -- Start twist by casting the alternate seal
    local twist_seal_id = nil
    local twist_seal_name = nil
    
    if has_command and runtime.seal_of_vengeance_id then
        twist_seal_id = runtime.seal_of_vengeance_id
        twist_seal_name = "Seal of Vengeance (twist)"
    elseif has_vengeance and runtime.seal_of_command_id then
        twist_seal_id = runtime.seal_of_command_id
        twist_seal_name = "Seal of Command (twist)"
    elseif has_blood and runtime.seal_of_command_id then
        twist_seal_id = runtime.seal_of_command_id
        twist_seal_name = "Seal of Command (twist)"
    elseif has_martyr and runtime.seal_of_command_id then
        twist_seal_id = runtime.seal_of_command_id
        twist_seal_name = "Seal of Command (twist)"
    end
    
    if twist_seal_id and try_cast_self(twist_seal_id, me, twist_seal_name) then
        runtime.twist_state = "twisting"
        runtime.twist_seal_id = twist_seal_id
        runtime.twist_seal_name = twist_seal_name
        runtime.last_twist_at = now
        return true
    end
    return false
end

local function continue_seal_twist(me, target)
    if runtime.twist_state ~= "twisting" then return false end
    if not runtime.twist_seal_id then return false end
    
    -- Check if we should judge to complete the twist
    if target and target:is_valid() and me:can_attack(target) then
        if runtime.judgement_id and utils.can_cast_hostile(runtime.judgement_id, me, target) then
            if try_cast_target(runtime.judgement_id, me, target, "Judgement (twist)") then
                runtime.twist_state = "idle"
                runtime.twist_seal_id = nil
                runtime.twist_seal_name = nil
                return true
            end
        end
    end
    return false
end

-- Core rotation abilities
local function try_crusader_strike(me, target)
    if not (menu.use_crusader_strike and menu.use_crusader_strike:get_state()) then return false end
    if not runtime.crusader_strike_id then return false end
    if not target or not target:is_valid() then return false end
    if not me:can_attack(target) then return false end
    
    return try_cast_target(runtime.crusader_strike_id, me, target, "Crusader Strike")
end

local function try_judgement(me, target)
    if not (menu.use_judgement and menu.use_judgement:get_state()) then return false end
    if not runtime.judgement_id then return false end
    if not target or not target:is_valid() then return false end
    if not me:can_attack(target) then return false end
    
    return try_cast_target(runtime.judgement_id, me, target, "Judgement")
end

local function try_hammer_of_wrath(me, target)
    if not (menu.use_hammer_of_wrath and menu.use_hammer_of_wrath:get_state()) then return false end
    if not runtime.hammer_of_wrath_id then return false end
    if not target or not target:is_valid() then return false end
    if not me:can_attack(target) then return false end
    
    local hp_pct = target:get_health_percentage()
    if hp_pct > 20 then return false end
    
    return try_cast_target(runtime.hammer_of_wrath_id, me, target, "Hammer of Wrath")
end

local function try_exorcism(me, target)
    if not (menu.use_exorcism and menu.use_exorcism:get_state()) then return false end
    if not runtime.exorcism_id then return false end
    if not target or not target:is_valid() then return false end
    if not me:can_attack(target) then return false end
    
    -- Only cast on undead/demon targets
    local creature_type = nil
    if target.get_creature_type then
        creature_type = target:get_creature_type()
    end
    if creature_type ~= "Undead" and creature_type ~= "Demon" then return false end
    
    return try_cast_target(runtime.exorcism_id, me, target, "Exorcism")
end

local function try_consecration(me, target)
    if not (menu.use_consecration and menu.use_consecration:get_state()) then return false end
    if not runtime.consecration_id then return false end
    if not me:is_in_combat() then return false end
    
    return try_cast_self(runtime.consecration_id, me, "Consecration")
end

-- Cooldowns
local function try_avenging_wrath(me, target)
    if not (menu.use_avenging_wrath and menu.use_avenging_wrath:get_state()) then return false end
    if not runtime.avenging_wrath_id then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_AVENGING_WRATH) then return false end
    
    return try_cast_self(runtime.avenging_wrath_id, me, "Avenging Wrath")
end

local function try_divine_favor(me, target)
    if not (menu.use_divine_favor and menu.use_divine_favor:get_state()) then return false end
    if not runtime.divine_favor_id then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_DIVINE_FAVOR) then return false end
    
    return try_cast_self(runtime.divine_favor_id, me, "Divine Favor")
end

local function try_divine_shield(me)
    if not (menu.use_divine_shield and menu.use_divine_shield:get_state()) then return false end
    if not runtime.divine_shield_id then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_DIVINE_SHIELD) then return false end
    
    local hp_pct = me:get_health_percentage()
    local threshold = (menu.divine_shield_hp_pct and menu.divine_shield_hp_pct:get()) or 20
    if hp_pct > threshold then return false end
    
    return try_cast_self(runtime.divine_shield_id, me, "Divine Shield")
end

-- Utility
local function try_hand_of_freedom(me)
    if not (menu.use_hand_of_freedom and menu.use_hand_of_freedom:get_state()) then return false end
    if not runtime.hand_of_freedom_id then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_HAND_OF_FREEDOM) then return false end
    
    -- Check for root/snare effects
    local has_cc = utils.has_debuff(me, spells.DEBUFF_FROST_NOVA) or
                   utils.has_debuff(me, spells.DEBUFF_ENTANGLING_ROOTS) or
                   utils.has_debuff(me, spells.DEBUFF_HAMSTRING) or
                   utils.has_debuff(me, spells.DEBUFF_SLOW)
    
    if not has_cc then return false end
    
    return try_cast_self(runtime.hand_of_freedom_id, me, "Hand of Freedom")
end

local function try_cleanse(me)
    if not (menu.use_cleansing and menu.use_cleansing:get_state()) then return false end
    if not runtime.cleanse_id then return false end
    if not me:is_in_combat() then return false end
    
    -- Check for dispellable debuffs on self
    local has_poison = utils.has_debuff(me, spells.DEBUFF_POISON)
    local has_disease = utils.has_debuff(me, spells.DEBUFF_DISEASE)
    local has_magic = utils.has_debuff(me, spells.DEBUFF_MAGIC)
    
    if not (has_poison or has_disease or has_magic) then return false end
    
    return try_cast_self(runtime.cleanse_id, me, "Cleanse")
end

-- Main update callback
local function on_update()
    if not (menu.enabled and menu.enabled:get_state()) then return end
    
    local me = _get_local_player()
    if not me or me:is_dead() then return end
    
    -- Sync dashboard settings
    local ok_show, show_dashboard = pcall(function() return menu.show_dashboard:get_state() end)
    if ok_show then
        dashboard.set_enabled(show_dashboard)
    end
    
    local ok_opacity, opacity = pcall(function() return menu.dashboard_opacity:get() end)
    if ok_opacity then
        dashboard.set_opacity(opacity)
    end
    
    local ok_scale, scale = pcall(function() return menu.dashboard_scale:get() end)
    if ok_scale then
        dashboard.set_scale(scale)
    end
    
    local ok_x, pos_x = pcall(function() return menu.dashboard_x:get() end)
    local ok_y, pos_y = pcall(function() return menu.dashboard_y:get() end)
    if ok_x and ok_y then
        dashboard.set_position(pos_x, pos_y)
    end
    
    -- Build middleware context
    local target = me:get_target()
    local ctx = middleware_manager.build_context(me, target, {
        use_healthstone = (menu.use_healthstone and menu.use_healthstone:get_state()) or false,
        use_healing_potion = (menu.use_health_potion and menu.use_health_potion:get_state()) or false,
        use_mana_potion = (menu.use_mana_potion and menu.use_mana_potion:get_state()) or false,
        use_divine_protection = (menu.use_divine_protection and menu.use_divine_protection:get_state()) or false,
        use_divine_shield = (menu.use_divine_shield and menu.use_divine_shield:get_state()) or false,
        use_lay_on_hands = (menu.use_lay_on_hands and menu.use_lay_on_hands:get_state()) or false,
        use_avenging_wrath = (menu.use_avenging_wrath and menu.use_avenging_wrath:get_state()) or false,
        use_divine_favor = (menu.use_divine_favor and menu.use_divine_favor:get_state()) or false,
        use_berserking = (menu.use_berserking and menu.use_berserking:get_state()) or false,
        use_stoneform = (menu.use_stoneform and menu.use_stoneform:get_state()) or false,
    })
    
    -- Execute middleware (healthstones, potions, defensives)
    local mw_result, mw_msg = middleware_manager.execute(nil, ctx)
    if mw_result then
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, mw_msg or "Middleware executed")
        end
    end
    
    -- CC Detection: Stop rotation if crowd controlled
    local cc_detector = require("../libraries/cc_detector")
    local should_stop, cc_reason = cc_detector.should_stop_rotation(me)

    -- Paladin special: Try Divine Shield for any CC before stopping
    if should_stop then
        if utils.try_divine_shield_cc_break(me, menu) then
            return  -- Successfully broke CC
        end
    end

    if should_stop then
        if (menu.debug and menu.debug:get_state()) then
            print(string.format("[CC] Rotation paused: %s", cc_reason or "CC"))
        end
        return  -- Stop rotation while CC'd
    end
    
    -- OOC
    if not me:is_in_combat() then
        ooc_manager.on_update(me, menu, utils, {
            group_buffs = {
                {
                    spell_id = runtime.blessing_of_might_id,
                    buff_ids = spells.BUFF_BLESSING_OF_MIGHT,
                    name = "Blessing of Might",
                    toggle = menu.use_blessing_of_might
                },
                {
                    spell_id = runtime.blessing_of_wisdom_id,
                    buff_ids = spells.BUFF_BLESSING_OF_WISDOM,
                    name = "Blessing of Wisdom",
                    toggle = menu.use_blessing_of_wisdom
                },
                {
                    spell_id = runtime.blessing_of_kings_id,
                    buff_ids = spells.BUFF_BLESSING_OF_KINGS,
                    name = "Blessing of Kings",
                    toggle = menu.use_blessing_of_kings
                },
                {
                    spell_id = runtime.righteous_fury_id,
                    buff_ids = spells.BUFF_RIGHTEOUS_FURY,
                    name = "Righteous Fury",
                    toggle = menu.use_righteous_fury
                },
                {
                    spell_id = runtime.devotion_aura_id,
                    buff_ids = spells.BUFF_DEVOTION_AURA,
                    name = "Devotion Aura",
                    toggle = menu.use_devotion_aura
                },
                {
                    spell_id = runtime.sanctity_aura_id,
                    buff_ids = spells.BUFF_SANCTITY_AURA,
                    name = "Sanctity Aura",
                    toggle = menu.use_sanctity_aura
                },
            }
        })
    end
    
    -- Don't cast while eating/drinking
    local eax_utils = require("libraries/eax_utils")
    if eax_utils.is_eating_or_drinking(me) then return end
    
    -- Maintain aura
    if ensure_aura(me) then return end
    
    local target = me:get_target()
    
    -- Defensive CDs
    if try_divine_shield(me) then return end
    
    -- Only continue if in combat
    if not me:is_in_combat() then
        runtime.combat_start_time = nil
        return
    end

    -- Track combat start time for burst detection
    if not runtime.combat_start_time then
        runtime.combat_start_time = _core_time()
    end
    
    -- Flux: Update swing manager
    swing_manager:update_swing(me)
    
    -- Flux: Sample combat forecast
    if combat_forecast and target and target:is_valid() then
        combat_forecast:sample(target)
    end
    
    -- Flux: Check swing delay (don't clip auto attacks)
    if swing_manager:is_swing_landing_soon(0.15) then return end
    
    -- Ensure auto attack
    if target and target:is_valid() then
        utils.ensure_melee_auto_attack(me, target)
    end
    
    -- Update Vengeance stacks
    if target and target:is_valid() then
        local stacks = utils.get_debuff_stacks(target, spells.DEBUFF_HOLY_VENGEANCE)
        if not stacks then stacks = utils.get_debuff_stacks(target, spells.DEBUFF_BLOOD_CORRUPTION) end
        runtime.vengeance_stacks = stacks or 0
    end
    
    -- Consumables
    if menu.auto_combat_potions and menu.auto_combat_potions:get_state() then
        consumables_manager.try_use_combat_consumable(me, menu, utils)
    end
    
    -- Racial
    racial_manager.try_defensive(me)

    -- Burst detection and trinkets
    local combat_time = 0
    local start_time = runtime.combat_start_time
    if start_time then
        combat_time = _core_time() - start_time
    end
    local should_burst, burst_reason = burst_manager.should_auto_burst(me, target, combat_time, menu)
    local is_burst_window = should_burst or false

    -- Flux: Trinkets V2
    trinket_manager.check_trinkets_v2(me, target, is_burst_window, force_commands, combat_forecast, menu)

    -- Cooldowns (use burst detection for Avenging Wrath)
    if is_burst_window then
        if try_avenging_wrath(me, target) then return end
    end
    if try_divine_favor(me, target) then return end
    
    -- Utility
    if try_hand_of_freedom(me) then return end
    if try_cleanse(me) then return end
    
    -- Interrupt
    if target and target:is_valid() and me:can_attack(target) then
        if menu.use_interrupt and menu.use_interrupt:get_state() and interrupt_manager.should_interrupt(target) then
            if interrupt_manager.try_interrupt(me, target, "paladin", utils) then return end
        end
    end
    
    -- Seal twist (continue if in progress)
    if continue_seal_twist(me, target) then return end
    
    -- Maintain baseline seal
    if ensure_baseline_seal(me) then return end
    
    -- Core rotation
    if target and target:is_valid() and me:can_attack(target) then
        if try_hammer_of_wrath(me, target) then return end
        if try_exorcism(me, target) then return end
        if try_crusader_strike(me, target) then return end
        if try_judgement(me, target) then return end
    end
    
    -- AoE
    if try_consecration(me, target) then return end
    
    -- Start seal twist if conditions met
    if begin_seal_twist(me, target) then return end
end

-- Menu rendering
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxpaladinretributionspace_win")
_space_win:set_initial_size(_vec2.new(460, 580))
_space_win:set_next_window_min_size(_vec2.new(320, 300))
_space_win:set_next_window_padding(_vec2.new(10, 8))
menu.set_window(_space_win)

core.register_on_render_callback(function()
    menu.render()
end)

core.register_on_render_menu_callback(function()
    menu.render()
end)

-- Initialize dashboard
dashboard.init(dashboard_config)
dashboard.register_render_callback()

-- Export toggle settings for external access
local NS = _G.EAXPaladinRetribution and _G.EAXPaladinRetribution.NS or {}
_G.EAXPaladinRetribution = _G.EAXPaladinRetribution or {}
_G.EAXPaladinRetribution.NS = NS
NS.toggle_menu = menu.toggle_menu
