-- EAX Paladin Holy  main.lua
-- Holy healing rotation ported from 

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")
local dashboard = require("libraries/dashboard")
local dashboard_config = require("libraries/dashboard_config")

---@type buff_manager
local buff_manager = require("common/modules/buff_manager")
---@type health_prediction
local health_prediction = require("common/modules/health_prediction")
---@type heal_context
local heal_context = require("libraries/heal_context")
---@type heal_utils
local heal_utils = require("libraries/heal_utils")

---@type racial_manager
local racial_manager = require("libraries/racial_manager")
---@type defensive_manager
local defensive_manager = require("libraries/defensive_manager")
---@type consumables_manager
local consumables_manager = require("libraries/consumables_manager")
---@type trinket_manager
local trinket_manager = require("libraries/trinket_manager")


local middleware_manager = require("libraries/middleware_manager")
local ooc_manager = require("libraries/ooc_manager")

-- Hot-path local caching
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown

local runtime = {
    flash_of_light_id = nil,
    holy_light_id = nil,
    holy_shock_id = nil,
    lay_on_hands_id = nil,
    divine_favor_id = nil,
    divine_illumination_id = nil,
    avenging_wrath_id = nil,
    divine_shield_id = nil,
    divine_protection_id = nil,
    seal_of_wisdom_id = nil,
    seal_of_light_id = nil,
    seal_of_righteousness_id = nil,
    seal_of_crusader_id = nil,
    judgement_id = nil,
    cleanse_id = nil,
    purify_id = nil,
    blessing_of_wisdom_id = nil,
    blessing_of_might_id = nil,
    blessing_of_kings_id = nil,
    devotion_aura_id = nil,
    concentration_aura_id = nil,
    redemption_id = nil,
    righteous_fury_id = nil,
    last_cast_time = 0,
    last_heal_target = nil,
    last_aura_cast_at = 0,
}

local AURA_RETRY_WINDOW = 12.0
local BUFF_RETRY_WINDOW = 6.0
local HEAL_SCAN_INTERVAL = 0.5

local function resolve_spells()
    runtime.flash_of_light_id = utils.resolve_spell_id(spells.FLASH_OF_LIGHT)
    runtime.holy_light_id = utils.resolve_spell_id(spells.HOLY_LIGHT)
    runtime.holy_shock_id = utils.resolve_spell_id(spells.HOLY_SHOCK)
    runtime.lay_on_hands_id = utils.resolve_spell_id(spells.LAY_ON_HANDS)
    runtime.divine_favor_id = utils.resolve_spell_id(spells.DIVINE_FAVOR)
    runtime.divine_illumination_id = utils.resolve_spell_id(spells.DIVINE_ILLUMINATION)
    runtime.avenging_wrath_id = utils.resolve_spell_id(spells.AVENGING_WRATH)
    runtime.divine_shield_id = utils.resolve_spell_id(spells.DIVINE_SHIELD)
    runtime.divine_protection_id = utils.resolve_spell_id(spells.DIVINE_PROTECTION)
    runtime.seal_of_wisdom_id = utils.resolve_spell_id(spells.SEAL_OF_WISDOM)
    runtime.seal_of_light_id = utils.resolve_spell_id(spells.SEAL_OF_LIGHT)
    runtime.seal_of_righteousness_id = utils.resolve_spell_id(spells.SEAL_OF_RIGHTEOUSNESS)
    runtime.seal_of_crusader_id = utils.resolve_spell_id(spells.SEAL_OF_THE_CRUSADER)
    runtime.judgement_id = utils.resolve_spell_id(spells.JUDGEMENT)
    runtime.cleanse_id = utils.resolve_spell_id(spells.CLEANSE)
    runtime.purify_id = utils.resolve_spell_id(spells.PURIFY)
    runtime.blessing_of_wisdom_id = utils.resolve_spell_id(spells.BLESSING_OF_WISDOM)
    runtime.blessing_of_might_id = utils.resolve_spell_id(spells.BLESSING_OF_MIGHT)
    runtime.blessing_of_kings_id = utils.resolve_spell_id(spells.BLESSING_OF_KINGS)
    runtime.devotion_aura_id = utils.resolve_spell_id(spells.DEVOTION_AURA)
    runtime.concentration_aura_id = utils.resolve_spell_id(spells.CONCENTRATION_AURA)
    runtime.redemption_id = utils.resolve_spell_id(spells.REDEMPTION)
    runtime.righteous_fury_id = utils.resolve_spell_id(spells.RIGHTEOUS_FURY)
end

local function note_cast()
    runtime.last_cast_time = _core_time()
end

-- Seal management
local function get_active_seal(me)
    if utils.has_buff(me, spells.BUFF_SEAL_OF_WISDOM) then return "wisdom" end
    if utils.has_buff(me, spells.BUFF_SEAL_OF_LIGHT) then return "light" end
    if utils.has_buff(me, spells.BUFF_SEAL_OF_RIGHTEOUSNESS) then return "righteousness" end
    return "none"
end

local function ensure_seal(me)
    local seal_choice = (menu.seal_choice and menu.seal_choice:get()) or 1
    if seal_choice == 3 then return false end -- None selected
    
    local current_seal = get_active_seal(me)
    local desired_seal = (seal_choice == 1) and "wisdom" or "light"
    
    if current_seal == desired_seal then return false end
    
    local seal_id = nil
    if desired_seal == "wisdom" then seal_id = runtime.seal_of_wisdom_id
    elseif desired_seal == "light" then seal_id = runtime.seal_of_light_id
    end
    
    if seal_id and utils.can_cast_self(seal_id, me) then
        if utils.cast_self(seal_id, me) then
            note_cast()
            if menu.debug and menu.debug:get_state() then
                utils.log_debug(menu, "Seal: " .. desired_seal)
            end
            return true
        end
    end
    return false
end

-- Aura management
local function ensure_aura(me)
    if (_core_time() - runtime.last_aura_cast_at) < AURA_RETRY_WINDOW then return false end
    
    if utils.has_buff(me, spells.BUFF_DEVOTION_AURA) or 
       utils.has_buff(me, spells.BUFF_CONCENTRATION_AURA) or
       utils.has_buff(me, spells.BUFF_RETRIBUTION_AURA) then
        return false
    end
    
    -- Holy uses Concentration Aura, fallback to Devotion
    local aura_id = runtime.concentration_aura_id or runtime.devotion_aura_id
    if aura_id and utils.can_cast_self(aura_id, me) then
        if utils.cast_self(aura_id, me) then
            runtime.last_aura_cast_at = _core_time()
            note_cast()
            return true
        end
    end
    return false
end

-- Healing functions
local function cast_flash_of_light(me, target)
    if not runtime.flash_of_light_id then return false end
    if not utils.can_cast_target(runtime.flash_of_light_id, me, target) then return false end
    if utils.cast_target(runtime.flash_of_light_id, me, target) then
        note_cast()
        runtime.last_heal_target = target
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Flash of Light -> " .. (target.get_name and target:get_name() or "target"))
        end
        return true
    end
    return false
end

local function cast_holy_light(me, target)
    if not runtime.holy_light_id then return false end
    if not utils.can_cast_target(runtime.holy_light_id, me, target) then return false end
    if utils.cast_target(runtime.holy_light_id, me, target) then
        note_cast()
        runtime.last_heal_target = target
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Holy Light -> " .. (target.get_name and target:get_name() or "target"))
        end
        return true
    end
    return false
end

local function cast_holy_shock(me, target)
    if not runtime.holy_shock_id then return false end
    if not (menu.use_holy_shock and menu.use_holy_shock:get_state()) then return false end
    if not utils.can_cast_target(runtime.holy_shock_id, me, target) then return false end
    if utils.cast_target(runtime.holy_shock_id, me, target) then
        note_cast()
        runtime.last_heal_target = target
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Holy Shock -> " .. (target.get_name and target:get_name() or "target"))
        end
        return true
    end
    return false
end

local function cast_lay_on_hands(me, target)
    if not runtime.lay_on_hands_id then return false end
    if not (menu.use_lay_on_hands and menu.use_lay_on_hands:get_state()) then return false end
    -- Check Forbearance
    if utils.has_debuff(me, spells.DEBUFF_FORBEARANCE) then return false end
    if not utils.can_cast_target(runtime.lay_on_hands_id, me, target) then return false end
    if utils.cast_target(runtime.lay_on_hands_id, me, target) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Lay on Hands -> " .. (target.get_name and target:get_name() or "target"))
        end
        return true
    end
    return false
end

-- Cooldowns
local function try_divine_favor(me)
    if not runtime.divine_favor_id then return false end
    if not (menu.use_divine_favor and menu.use_divine_favor:get_state()) then return false end
    if not me:is_in_combat() then return false end
    if not utils.can_cast_self(runtime.divine_favor_id, me) then return false end
    -- Only use if someone needs healing
    local ctx = heal_context.get_context(me)
    local lowest = ctx.lowest_ally
    if not lowest then return false end
    local hp_pct = utils.get_effective_hp_pct(lowest)
    if hp_pct > 0.8 then return false end
    
    if utils.cast_self_fast(runtime.divine_favor_id, me) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Divine Favor")
        end
        return true
    end
    return false
end

local function try_divine_illumination(me)
    if not runtime.divine_illumination_id then return false end
    if not (menu.use_divine_illumination and menu.use_divine_illumination:get_state()) then return false end
    if not me:is_in_combat() then return false end
    local mana_pct = utils.get_mana_pct(me)
    local threshold = ((menu.divine_illumination_pct and menu.divine_illumination_pct:get()) or 60) / 100
    if mana_pct > threshold then return false end
    if not utils.can_cast_self(runtime.divine_illumination_id, me) then return false end
    if utils.cast_self_fast(runtime.divine_illumination_id, me) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Divine Illumination")
        end
        return true
    end
    return false
end

local function try_avenging_wrath(me)
    if not runtime.avenging_wrath_id then return false end
    if not (menu.use_avenging_wrath and menu.use_avenging_wrath:get_state()) then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_AVENGING_WRATH) then return false end
    if utils.has_debuff(me, spells.DEBUFF_FORBEARANCE) then return false end
    if not utils.can_cast_self(runtime.avenging_wrath_id, me) then return false end
    -- Only use during heavy healing
    local count = utils.count_below_hp(me, 70)
    if count < 2 then return false end
    
    if utils.cast_self_fast(runtime.avenging_wrath_id, me) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Avenging Wrath")
        end
        return true
    end
    return false
end

-- Defensive
local function try_divine_shield(me)
    if not runtime.divine_shield_id then return false end
    if not (menu.use_divine_shield and menu.use_divine_shield:get_state()) then return false end
    if utils.has_debuff(me, spells.DEBUFF_FORBEARANCE) then return false end
    local hp_pct = utils.get_health_pct(me)
    local threshold = ((menu.divine_shield_hp_pct and menu.divine_shield_hp_pct:get()) or 20) / 100
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

local function try_divine_protection(me)
    if not runtime.divine_protection_id then return false end
    if not (menu.use_divine_protection and menu.use_divine_protection:get_state()) then return false end
    if utils.has_debuff(me, spells.DEBUFF_FORBEARANCE) then return false end
    local hp_pct = utils.get_health_pct(me)
    local threshold = ((menu.divine_protection_hp_pct and menu.divine_protection_hp_pct:get()) or 30) / 100
    if hp_pct > threshold then return false end
    if not utils.can_cast_self(runtime.divine_protection_id, me) then return false end
    if utils.cast_self(runtime.divine_protection_id, me) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Divine Protection")
        end
        return true
    end
    return false
end

-- Cleanse
local function try_cleanse(me)
    if not (menu.use_cleanse and menu.use_cleanse:get_state()) then return false end
    local cleanse_id = runtime.cleanse_id or runtime.purify_id
    if not cleanse_id then return false end
    
    -- Check self first
    if utils.needs_cleanse(me) and utils.can_cast_self(cleanse_id, me) then
        if utils.cast_self(cleanse_id, me) then
            note_cast()
            if menu.debug and menu.debug:get_state() then
                utils.log_debug(menu, "Cleanse (self)")
            end
            return true
        end
    end
    
    -- Check party if enabled
    if not (menu.use_cleanse_party and menu.use_cleanse_party:get_state()) then return false end
    local party = utils.get_party_units(me)
    for _, unit in ipairs(party) do
        if unit and unit:is_valid() and not unit:is_dead() and utils.needs_cleanse(unit) then
            if utils.can_cast_target(cleanse_id, me, unit) then
                if utils.cast_target(cleanse_id, me, unit) then
                    note_cast()
                    if menu.debug and menu.debug:get_state() then
                        utils.log_debug(menu, "Cleanse -> " .. (unit.get_name and unit:get_name() or "party"))
                    end
                    return true
                end
            end
        end
    end
    return false
end

-- Judgement (for mana return via Seal of Wisdom)
local function try_judgement(me, target)
    if not (menu.use_judgement and menu.use_judgement:get_state()) then return false end
    if not runtime.judgement_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    if not utils.is_known_spell(runtime.judgement_id) then return false end
    if core.spell_book.get_spell_cooldown(runtime.judgement_id) > 0 then return false end
    
    -- Only judge if we have a seal active
    local current_seal = get_active_seal(me)
    if current_seal == "none" then return false end
    
    -- Check if debuff already present
    local judge_choice = (menu.maintain_judgement and menu.maintain_judgement:get()) or 1
    local debuff_ids = nil
    if judge_choice == 1 then debuff_ids = spells.DEBUFF_JUDGEMENT_OF_LIGHT
    elseif judge_choice == 2 then debuff_ids = spells.DEBUFF_JUDGEMENT_OF_WISDOM
    else return false end
    
    if debuff_ids and utils.get_debuff_remaining_ms(target, debuff_ids) > 3000 then return false end
    
    -- Need to be in melee range
    local my_pos = me:get_position()
    local target_pos = target:get_position()
    if not my_pos or not target_pos then return false end
    local reach = (me:get_combat_reach() or 0) + (target:get_combat_reach() or 0) + 1.0
    local sq_dist = my_pos:squared_dist_to_ignore_z(target_pos)
    if sq_dist > (reach * reach) then return false end
    
    if utils.cast_target(runtime.judgement_id, me, target) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Judgement")
        end
        return true
    end
    return false
end

-- Main healing logic
local function do_healing(me)
    -- Use shared heal_context for party/raid scanning
    local ctx = heal_context.get_context(me)
    
    if not ctx or not ctx.lowest_ally then return false end
    
    local target = ctx.lowest_ally
    local hp_pct = utils.get_effective_hp_pct(target)
    
    -- Emergency: Lay on Hands
    if hp_pct < ((menu.lay_on_hands_hp_pct and menu.lay_on_hands_hp_pct:get()) or 15) / 100 then
        if cast_lay_on_hands(me, target) then return true end
    end
    
    -- Holy Shock for instant heal
    local holy_shock_threshold = ((menu.holy_shock_hp_pct and menu.holy_shock_hp_pct:get()) or 50) / 100
    if hp_pct < holy_shock_threshold then
        if cast_holy_shock(me, target) then return true end
    end
    
    -- Holy Light (primary heal)
    local holy_light_threshold = ((menu.holy_light_hp_pct and menu.holy_light_hp_pct:get()) or 90) / 100
    if hp_pct < holy_light_threshold then
        if cast_holy_light(me, target) then return true end
    end
    
    -- Flash of Light (filler)
    local flash_threshold = ((menu.flash_of_light_hp_pct and menu.flash_of_light_hp_pct:get()) or 95) / 100
    if hp_pct < flash_threshold then
        if cast_flash_of_light(me, target) then return true end
    end
    
    return false
end

resolve_spells()

-- Main update loop
core.register_on_update_callback(function()
    if not (menu.enabled and menu.enabled:get_state()) then return end
    
    -- Initialize middleware on first run
    if not middleware_manager.is_initialized() then
        middleware_manager.initialize(menu)
    end
    
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
        use_divine_illumination = (menu.use_divine_illumination and menu.use_divine_illumination:get_state()) or false,
        use_berserking = (menu.use_berserking and menu.use_berserking:get_state()) or false,
        use_stoneform = (menu.use_stoneform and menu.use_stoneform:get_state()) or false,
    })
    
    -- Execute middleware (healthstones, potions, defensives)
    local mw_result, mw_msg = middleware_manager.execute(nil, ctx)
    if mw_result then
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, mw_msg or "Middleware executed")
        end
        -- Don't return here - let healing continue after middleware
    end
    
    -- CC Detection: Stop rotation if crowd controlled
    local cc_detector = require("libraries/cc_detector")
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
    
    -- OOC: drink, buff, and rez
    if not me:is_in_combat() then
        if menu.ooc_drink and menu.ooc_drink:get_state() then
            consumables_manager.try_use_ooc_food_drink(me, menu, utils)
        end
        
        -- OOC Manager for buffs and rez
        ooc_manager.on_update(me, menu, utils, {
            rez_spell_id = runtime.redemption_id,
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
            }
        })
    end
    
    -- Don't cast while eating/drinking
    local eax_utils = require("libraries/eax_utils")
    if eax_utils.is_eating_or_drinking(me) then return end
    
    -- Maintain aura
    if ensure_aura(me) then return end
    
    -- Defensive CDs (self)
    if try_divine_shield(me) then return end
    if try_divine_protection(me) then return end
    
    -- Mana CDs
    if try_divine_illumination(me) then return end
    
    -- Only continue if in combat or party members are in combat
    local in_combat = me:is_in_combat()
    if not in_combat then
        local party = utils.get_party_units(me)
        for _, unit in ipairs(party) do
            if unit and unit:is_valid() and unit:is_in_combat() then
                in_combat = true
                break
            end
        end
    end
    
    if not in_combat then return end
    
    -- Combat potions
    if menu.auto_mana_potion and menu.auto_mana_potion:get_state() then
        consumables_manager.try_use_combat_consumable(me, menu, utils)
    end
    
    -- Racial
    racial_manager.try_defensive(me)
    
    -- Trinkets (offensive during burst, defensive when low HP)
    trinket_manager.check_trinkets(me, false, menu)
    
    -- Avenging Wrath during heavy damage
    if try_avenging_wrath(me) then return end
    
    -- Divine Favor before big heal
    if try_divine_favor(me) then return end
    
    -- Cleanse
    if try_cleanse(me) then return end
    
    -- Maintain seal for mana return
    if ensure_seal(me) then return end
    
    -- Try to judge for mana (if in melee)
    local target = me:get_target()
    if target and target:is_valid() and not target:is_dead() and me:can_attack(target) then
        try_judgement(me, target)
    end
    
    -- Main healing
    do_healing(me)
end)

-- Menu rendering
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxpaladinholyspace_win")
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
local NS = _G.EAXPaladinHoly and _G.EAXPaladinHoly.NS or {}
_G.EAXPaladinHoly = _G.EAXPaladinHoly or {}
_G.EAXPaladinHoly.NS = NS
NS.toggle_menu = menu.toggle_menu


