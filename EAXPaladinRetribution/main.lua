require("libraries/path_bootstrap")
-- EAX Paladin Retribution  main.lua
-- Retribution DPS rotation ported from  with seal twisting

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")

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
    runtime.seal_of_martyr_id = utils.resolve_spell_id(spells.SEAL_OF_THE_MARTYR)
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
    
    -- Detect faction
    runtime.is_horde = utils.is_horde()
end

local function note_cast()
    runtime.last_cast_time = _core_time()
end

-- Seal management
local function get_active_seal(me)
    if utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND) then return "command" end
    if runtime.is_horde then
        if utils.has_buff(me, spells.BUFF_SEAL_OF_BLOOD) then return "blood" end
        if utils.has_buff(me, spells.BUFF_SEAL_OF_CORRUPTION) then return "corruption" end
    else
        if utils.has_buff(me, spells.BUFF_SEAL_OF_THE_MARTYR) then return "martyr" end
        if utils.has_buff(me, spells.BUFF_SEAL_OF_VENGEANCE) then return "vengeance" end
    end
    if utils.has_buff(me, spells.BUFF_SEAL_OF_RIGHTEOUSNESS) then return "righteousness" end
    if utils.has_buff(me, spells.BUFF_SEAL_OF_THE_CRUSADER) then return "crusader" end
    if utils.has_buff(me, spells.BUFF_SEAL_OF_WISDOM) then return "wisdom" end
    if utils.has_buff(me, spells.BUFF_SEAL_OF_LIGHT) then return "light" end
    return "none"
end

-- Get preferred DPS seal based on faction and availability
local function get_preferred_seal()
    if runtime.is_horde then
        if runtime.seal_of_blood_id and utils.is_known_spell(runtime.seal_of_blood_id) then
            return runtime.seal_of_blood_id, "Blood", "blood"
        end
        if runtime.seal_of_corruption_id and utils.is_known_spell(runtime.seal_of_corruption_id) then
            return runtime.seal_of_corruption_id, "Corruption", "corruption"
        end
    else
        if runtime.seal_of_martyr_id and utils.is_known_spell(runtime.seal_of_martyr_id) then
            return runtime.seal_of_martyr_id, "Martyr", "martyr"
        end
        if runtime.seal_of_vengeance_id and utils.is_known_spell(runtime.seal_of_vengeance_id) then
            return runtime.seal_of_vengeance_id, "Vengeance", "vengeance"
        end
    end
    if runtime.seal_of_command_id and utils.is_known_spell(runtime.seal_of_command_id) then
        return runtime.seal_of_command_id, "Command", "command"
    end
    if runtime.seal_of_righteousness_id and utils.is_known_spell(runtime.seal_of_righteousness_id) then
        return runtime.seal_of_righteousness_id, "Righteousness", "righteousness"
    end
    return nil, nil, nil
end

-- Get twist seal (Command for twist setup)
local function get_twist_seal()
    if runtime.seal_of_command_id and utils.is_known_spell(runtime.seal_of_command_id) then
        return runtime.seal_of_command_id, "Command", "command"
    end
    return nil, nil, nil
end

-- Check if twisting is allowed in current mode
local function twists_allowed_in_mode()
    local mode_idx = (menu.mode and menu.mode:get()) or 1
    if mode_idx == 1 then  -- Auto - detect
        local me = _get_local_player()
        local party_count = 0
        for i = 1, 4 do
            local unit = core.object_manager.get_object_by_name("party" .. i)
            if unit and unit:is_valid() then party_count = party_count + 1 end
        end
        if party_count == 0 then return true end  -- Solo
        if party_count <= 4 then  -- Dungeon
            return menu.allow_twist_dungeon and menu.allow_twist_dungeon:get_state()
        end
        return menu.allow_twist_raid and menu.allow_twist_raid:get_state()  -- Raid
    elseif mode_idx == 2 then  -- Solo
        return true
    elseif mode_idx == 3 then  -- Dungeon
        return menu.allow_twist_dungeon and menu.allow_twist_dungeon:get_state()
    else  -- Raid
        return menu.allow_twist_raid and menu.allow_twist_raid:get_state()
    end
end

-- Aura management
local function ensure_aura(me)
    if (_core_time() - runtime.last_aura_cast_at) < AURA_RETRY_WINDOW then return false end
    if utils.has_buff(me, spells.BUFF_SANCTITY_AURA) or 
       utils.has_buff(me, spells.BUFF_DEVOTION_AURA) or
       utils.has_buff(me, spells.BUFF_RETRIBUTION_AURA) or
       utils.has_buff(me, spells.BUFF_CRUSADER_AURA) then
        return false
    end
    
    local aura_id = nil
    if menu.use_sanctity_aura and menu.use_sanctity_aura:get_state() then
        aura_id = runtime.sanctity_aura_id
    end
    if not aura_id then aura_id = runtime.devotion_aura_id end
    
    if aura_id and utils.can_cast_self(aura_id, me) then
        if utils.cast_self(aura_id, me) then
            runtime.last_aura_cast_at = _core_time()
            note_cast()
            if menu.debug and menu.debug:get_state() then
                utils.log_debug(menu, "Aura")
            end
            return true
        end
    end
    return false
end

-- Seal twist logic
local function can_consider_seal_twist(me, target)
    if not (menu.use_seal_twist and menu.use_seal_twist:get_state()) then return nil, nil end
    if not twists_allowed_in_mode() then return nil, nil end
    if not target or not target:is_valid() or target:is_dead() then return nil, nil end
    if not utils.is_melee_target(me, target) then return nil, nil end
    
    local twist_seal_id, twist_seal_name = get_twist_seal()
    local baseline_seal_id, baseline_seal_name, baseline_key = get_preferred_seal()
    
    if not baseline_seal_id or not twist_seal_id then return nil, nil end
    if baseline_key == "command" then return nil, nil end  -- Already using Command
    
    -- Check mana
    if utils.get_mana_pct(me) < 0.20 then return nil, nil end
    
    -- Check cooldown
    local twist_cooldown = ((menu.seal_twist_cooldown and menu.seal_twist_cooldown:get()) or 3)
    if (_core_time() - runtime.last_twist_at) < twist_cooldown then return nil, nil end
    
    -- Don't twist away from high SoV stacks
    if baseline_key == "vengeance" or baseline_key == "corruption" then
        local stacks = runtime.vengeance_stacks
        if stacks >= 3 then
            local ttd_ok, ttd = pcall(function() 
                local ttd_mod = require("libraries/ttd_tracker")
                return ttd_mod and ttd_mod.get and ttd_mod.get(target) or 999
            end)
            if ttd_ok and ttd and ttd >= 15 then return nil, nil end
        end
    end
    
    return twist_seal_id, twist_seal_name
end

local function should_start_seal_twist(me, target)
    if runtime.twist_state ~= "idle" then return false end
    
    local twist_seal_id, twist_seal_name = can_consider_seal_twist(me, target)
    if not twist_seal_id then return false end
    
    local twist_window = ((menu.seal_twist_window and menu.seal_twist_window:get()) or 400)
    if not utils.is_next_swing_within_ms(me, twist_window, SEAL_TWIST_INPUT_DELAY_MS) then return false end
    
    -- Don't start if Crusader Strike is about to come off CD
    if runtime.crusader_strike_id then
        local cs_cd = _get_spell_cd(runtime.crusader_strike_id) or 0
        if cs_cd > 0 and cs_cd < 1.5 then return false end
    end
    
    runtime.twist_seal_id = twist_seal_id
    runtime.twist_seal_name = twist_seal_name
    return true
end

local function begin_seal_twist(me, target)
    if not should_start_seal_twist(me, target) then return false end
    if utils.cast_self_fast(runtime.twist_seal_id, me) then
        runtime.twist_state = "twist_pending"
        runtime.last_twist_at = _core_time()
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Seal twist -> " .. tostring(runtime.twist_seal_name))
        end
        return true
    end
    return false
end

local function has_active_twist_seal(me)
    if runtime.twist_seal_name == "Command" then
        return utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND)
    end
    return false
end

local function has_baseline_seal(me)
    local _, _, baseline_key = get_preferred_seal()
    local current = get_active_seal(me)
    return current == baseline_key
end

local function continue_seal_twist(me, target)
    if runtime.twist_state == "idle" then return false end
    
    if not me or not me:is_valid() or not me:is_in_combat() then
        runtime.twist_state = "idle"
        return false
    end
    
    if not target or not target:is_valid() or target:is_dead() or not utils.is_melee_target(me, target) then
        runtime.twist_state = "idle"
        return false
    end
    
    if runtime.twist_state == "twist_pending" then
        if has_active_twist_seal(me) then
            runtime.twist_state = "twist_active"
        elseif (_core_time() - runtime.last_twist_at) > SEAL_TWIST_CONFIRM_TIMEOUT_S then
            runtime.twist_state = "idle"
        end
        return false
    end
    
    if runtime.twist_state == "twist_active" then
        local baseline_seal_id, baseline_seal_name = get_preferred_seal()
        if baseline_seal_id and utils.cast_self_fast(baseline_seal_id, me) then
            runtime.twist_state = "baseline_pending"
            note_cast()
            if menu.debug and menu.debug:get_state() then
                utils.log_debug(menu, "Seal twist -> " .. tostring(baseline_seal_name))
            end
            return true
        end
        return false
    end
    
    if runtime.twist_state == "baseline_pending" then
        if has_baseline_seal(me) then
            runtime.twist_state = "idle"
        elseif (_core_time() - runtime.last_twist_at) > SEAL_TWIST_CONFIRM_TIMEOUT_S then
            runtime.twist_state = "idle"
        end
    end
    
    return false
end

-- Core abilities
local function try_crusader_strike(me, target)
    if not (menu.use_crusader_strike and menu.use_crusader_strike:get_state()) then return false end
    if not runtime.crusader_strike_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not utils.is_melee_target(me, target) then return false end
    if not utils.can_cast_target(runtime.crusader_strike_id, me, target) then return false end
    
    -- Don't CS if in twist window
    local twist_window = ((menu.seal_twist_window and menu.seal_twist_window:get()) or 400)
    if utils.is_next_swing_within_ms(me, twist_window + 1500, 0) then return false end
    
    if utils.cast_target(runtime.crusader_strike_id, me, target) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Crusader Strike")
        end
        return true
    end
    return false
end

local function try_judgement(me, target)
    if not (menu.use_judgement and menu.use_judgement:get_state()) then return false end
    if not runtime.judgement_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    if not utils.is_melee_target(me, target) then return false end
    if not utils.can_cast_target(runtime.judgement_id, me, target) then return false end
    
    -- Need a seal active
    if get_active_seal(me) == "none" then return false end
    
    -- Check if debuff already present
    local judge_choice = (menu.judgement_choice and menu.judgement_choice:get()) or 1
    local debuff_ids = nil
    if judge_choice == 1 then debuff_ids = spells.DEBUFF_JUDGEMENT_OF_WISDOM
    elseif judge_choice == 2 then debuff_ids = spells.DEBUFF_JUDGEMENT_OF_THE_CRUSADER
    else debuff_ids = spells.DEBUFF_JUDGEMENT_OF_LIGHT end
    
    if debuff_ids and utils.get_debuff_remaining_ms(target, debuff_ids) > 4000 then return false end
    
    if utils.cast_target(runtime.judgement_id, me, target) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Judgement")
        end
        return true
    end
    return false
end

local function try_hammer_of_wrath(me, target)
    if not (menu.use_hammer_of_wrath and menu.use_hammer_of_wrath:get_state()) then return false end
    if not runtime.hammer_of_wrath_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if utils.get_health_pct(target) > 0.20 then return false end
    if not utils.can_cast_target(runtime.hammer_of_wrath_id, me, target) then return false end
    
    if utils.cast_target(runtime.hammer_of_wrath_id, me, target) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Hammer of Wrath")
        end
        return true
    end
    return false
end

local function try_exorcism(me, target)
    if not (menu.use_exorcism and menu.use_exorcism:get_state()) then return false end
    if not runtime.exorcism_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not utils.is_undead_or_demon(target) then return false end
    if utils.get_mana_pct(me) < 0.40 then return false end
    if not utils.can_cast_target(runtime.exorcism_id, me, target) then return false end
    
    if utils.cast_target(runtime.exorcism_id, me, target) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Exorcism")
        end
        return true
    end
    return false
end

local function try_consecration(me, target)
    if not (menu.use_consecration and menu.use_consecration:get_state()) then return false end
    if not runtime.consecration_id then return false end
    if utils.get_mana_pct(me) < 0.60 then return false end
    
    local threshold = (menu.consecration_aoe_threshold and menu.consecration_aoe_threshold:get()) or 3
    if threshold > 0 then
        local enemy_count = utils.count_enemies_within_radius(me, 8)
        if enemy_count < threshold then return false end
    end
    
    if not utils.can_cast_self(runtime.consecration_id, me) then return false end
    if utils.cast_self(runtime.consecration_id, me) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Consecration")
        end
        return true
    end
    return false
end

-- Cooldowns
local function try_avenging_wrath(me)
    if not (menu.use_avenging_wrath and menu.use_avenging_wrath:get_state()) then return false end
    if not runtime.avenging_wrath_id then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_AVENGING_WRATH) then return false end
    if utils.has_debuff(me, spells.DEBUFF_FORBEARANCE) then return false end
    if not utils.can_cast_self(runtime.avenging_wrath_id, me) then return false end
    if utils.cast_self_fast(runtime.avenging_wrath_id, me) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Avenging Wrath")
        end
        return true
    end
    return false
end

local function try_divine_favor(me)
    if not (menu.use_divine_favor and menu.use_divine_favor:get_state()) then return false end
    if not runtime.divine_favor_id then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_DIVINE_FAVOR) then return false end
    if not utils.can_cast_self(runtime.divine_favor_id, me) then return false end
    if utils.cast_self_fast(runtime.divine_favor_id, me) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Divine Favor")
        end
        return true
    end
    return false
end

local function try_divine_shield(me)
    if not (menu.use_divine_shield and menu.use_divine_shield:get_state()) then return false end
    if not runtime.divine_shield_id then return false end
    if utils.has_debuff(me, spells.DEBUFF_FORBEARANCE) then return false end
    local hp_pct = utils.get_health_pct(me)
    local threshold = ((menu.divine_shield_hp and menu.divine_shield_hp:get()) or 20) / 100
    if hp_pct > threshold then return false end
    if not utils.can_cast_self(runtime.divine_shield_id, me) then return false end
    if utils.cast_self(runtime.divine_shield_id, me) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Divine Shield (emergency)")
        end
        return true
    end
    return false
end

-- Utility
local function try_hand_of_freedom(me)
    if not (menu.use_hand_of_freedom and menu.use_hand_of_freedom:get_state()) then return false end
    if not runtime.hand_of_freedom_id then return false end
    if not utils.can_cast_self(runtime.hand_of_freedom_id, me) then return false end
    
    -- Check self
    local ok_rooted, is_rooted = pcall(function() return me:is_rooted(500) end)
    local ok_slowed, is_slowed = pcall(function() return me:is_slowed(0.30, 500) end)
    
    if (ok_rooted and is_rooted) or (ok_slowed and is_slowed and menu.hof_include_slows and menu.hof_include_slows:get_state()) then
        if not utils.has_buff(me, spells.BUFF_HAND_OF_FREEDOM) then
            if utils.cast_self(runtime.hand_of_freedom_id, me) then
                note_cast()
                if menu.debug and menu.debug:get_state() then
                    utils.log_debug(menu, "Hand of Freedom (self)")
                end
                return true
            end
        end
    end
    return false
end

local function try_cleanse(me)
    if not (menu.use_cleanse and menu.use_cleanse:get_state()) then return false end
    local cleanse_id = runtime.cleanse_id
    if not cleanse_id then return false end
    if not utils.needs_cleanse(me) then return false end
    if not utils.can_cast_self(cleanse_id, me) then return false end
    if utils.cast_self(cleanse_id, me) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Cleanse")
        end
        return true
    end
    return false
end

-- OOC buffs
local function try_ooc_buffs(me)
    if me:is_in_combat() then return false end
    if (_core_time() - runtime.last_ooc_buff_at) < BUFF_RETRY_WINDOW then return false end
    if not (menu.ooc_buff and menu.ooc_buff:get_state()) then return false end
    
    -- Check for blessing
    local has_blessing = utils.has_buff(me, spells.BUFF_BLESSING_OF_MIGHT) or
                         utils.has_buff(me, spells.BUFF_BLESSING_OF_KINGS)
    if not has_blessing then
        local buff_id = nil
        if menu.use_blessing_of_might and menu.use_blessing_of_might:get_state() then
            buff_id = runtime.blessing_of_might_id
        elseif menu.use_blessing_of_kings and menu.use_blessing_of_kings:get_state() then
            buff_id = runtime.blessing_of_kings_id
        end
        if buff_id and utils.can_cast_self(buff_id, me) then
            if utils.cast_self(buff_id, me) then
                runtime.last_ooc_buff_at = _core_time()
                note_cast()
                return true
            end
        end
    end
    return false
end

-- Ensure baseline seal
local function ensure_baseline_seal(me)
    if runtime.twist_state ~= "idle" then return false end
    local seal_id, seal_name, seal_key = get_preferred_seal()
    if not seal_id then return false end
    
    local current = get_active_seal(me)
    if current == seal_key then return false end
    
    if utils.can_cast_self(seal_id, me) and utils.cast_self(seal_id, me) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Seal: " .. seal_name)
        end
        return true
    end
    return false
end

resolve_spells()

-- Main update loop
core.register_on_update_callback(function()
    if not menu.is_enabled() then return end
    
    local me = _get_local_player()
    if not me or me:is_dead() then return end
    
    -- OOC
    if not me:is_in_combat() then
        if menu.auto_ooc_food_drink and menu.auto_ooc_food_drink:get_state() then
            consumables_manager.try_use_ooc_food_drink(me, menu, utils)
        end
        if try_ooc_buffs(me) then return end
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
    if not me:is_in_combat() then return end
    
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
    
    -- Cooldowns
    if try_avenging_wrath(me) then return end
    if try_divine_favor(me) then return end
    
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
end)

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

-- Export toggle settings for external access
local NS = _G.EAXPaladinRetribution and _G.EAXPaladinRetribution.NS or {}
_G.EAXPaladinRetribution = _G.EAXPaladinRetribution or {}
_G.EAXPaladinRetribution.NS = NS
NS.toggle_menu = menu.toggle_menu


