-- EAX Paladin Protection  main.lua
-- Protection tank rotation ported from 

local _G = _G
local NS = _G.EAX
if not NS then
    NS = {}
    _G.EAX = NS
end

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")
local eax_utils = require("libraries/eax_utils")
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
---@type ooc_manager
local ooc_manager = require("libraries/ooc_manager")


local middleware_manager = require("libraries/middleware_manager")

-- NEW: Trinket manager for defensive trinket mode
local trinket_manager = require("libraries/trinket_manager")

-- NEW: Advanced tanking libraries from Flux port
---@type context_builder
local context_builder = require("libraries/context_builder")
---@type threat_tab_manager
local threat_tab_manager = require("libraries/threat_tab_manager")
---@type smart_defensive
local smart_defensive = require("libraries/smart_defensive")

-- Hot-path local caching
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown

local runtime = {
    holy_shield_id = nil,
    avengers_shield_id = nil,
    righteous_defense_id = nil,
    righteous_fury_id = nil,
    consecration_id = nil,
    judgement_id = nil,
    seal_of_righteousness_id = nil,
    seal_of_vengeance_id = nil,
    seal_of_wisdom_id = nil,
    seal_of_command_id = nil,
    hammer_of_wrath_id = nil,
    exorcism_id = nil,
    holy_wrath_id = nil,
    avenging_wrath_id = nil,
    divine_shield_id = nil,
    lay_on_hands_id = nil,
    cleanse_id = nil,
    hammer_of_justice_id = nil,
    devotion_aura_id = nil,
    blessing_of_kings_id = nil,
    blessing_of_sanctuary_id = nil,
    redemption_id = nil,
    last_cast_time = 0,
    last_aura_cast_at = 0,
    last_ooc_buff_at = 0,
    combat_start_time = 0,
    last_tab_target_at = 0,
    tab_target_cooldown = 0.5,
}

local AURA_RETRY_WINDOW = 12.0
local BUFF_RETRY_WINDOW = 6.0

local function resolve_spells()
    runtime.holy_shield_id = utils.resolve_spell_id(spells.HOLY_SHIELD)
    runtime.avengers_shield_id = utils.resolve_spell_id(spells.AVENGERS_SHIELD)
    runtime.righteous_defense_id = utils.resolve_spell_id(spells.RIGHTEOUS_DEFENSE)
    runtime.righteous_fury_id = utils.resolve_spell_id(spells.RIGHTEOUS_FURY)
    runtime.consecration_id = utils.resolve_spell_id(spells.CONSECRATION)
    runtime.judgement_id = utils.resolve_spell_id(spells.JUDGEMENT)
    runtime.seal_of_righteousness_id = utils.resolve_spell_id(spells.SEAL_OF_RIGHTEOUSNESS)
    runtime.seal_of_vengeance_id = utils.resolve_spell_id(spells.SEAL_OF_VENGEANCE)
    runtime.seal_of_wisdom_id = utils.resolve_spell_id(spells.SEAL_OF_WISDOM)
    runtime.seal_of_command_id = utils.resolve_spell_id(spells.SEAL_OF_COMMAND)
    runtime.hammer_of_wrath_id = utils.resolve_spell_id(spells.HAMMER_OF_WRATH)
    runtime.exorcism_id = utils.resolve_spell_id(spells.EXORCISM)
    runtime.holy_wrath_id = utils.resolve_spell_id(spells.HOLY_WRATH)
    runtime.avenging_wrath_id = utils.resolve_spell_id(spells.AVENGING_WRATH)
    runtime.divine_shield_id = utils.resolve_spell_id(spells.DIVINE_SHIELD)
    runtime.lay_on_hands_id = utils.resolve_spell_id(spells.LAY_ON_HANDS)
    runtime.cleanse_id = utils.resolve_spell_id(spells.CLEANSE)
    runtime.hammer_of_justice_id = utils.resolve_spell_id(spells.HAMMER_OF_JUSTICE)
    runtime.devotion_aura_id = utils.resolve_spell_id(spells.DEVOTION_AURA)
    runtime.blessing_of_kings_id = utils.resolve_spell_id(spells.BLESSING_OF_KINGS)
    runtime.blessing_of_sanctuary_id = utils.resolve_spell_id(spells.BLESSING_OF_SANCTUARY)
    runtime.blessing_of_might_id = utils.resolve_spell_id(spells.BLESSING_OF_MIGHT)
    runtime.blessing_of_wisdom_id = utils.resolve_spell_id(spells.BLESSING_OF_WISDOM)
    runtime.redemption_id = utils.resolve_spell_id(spells.REDEMPTION)
end

local function note_cast()
    runtime.last_cast_time = _core_time()
end

-- Seal management
local function get_active_seal(me)
    if utils.has_buff(me, spells.BUFF_SEAL_OF_RIGHTEOUSNESS) then return "righteousness" end
    if utils.has_buff(me, spells.BUFF_SEAL_OF_VENGEANCE) then return "vengeance" end
    if utils.has_buff(me, spells.BUFF_SEAL_OF_WISDOM) then return "wisdom" end
    if utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND) then return "command" end
    return "none"
end

local function ensure_seal(me)
    local seal_choice = (menu.seal_choice and menu.seal_choice:get()) or 1
    local current_seal = get_active_seal(me)
    
    -- Check for low mana seal switch
    if menu.use_seal_of_wisdom_low_mana and menu.use_seal_of_wisdom_low_mana:get_state() then
        local mana_pct = utils.get_mana_pct(me)
        local threshold = ((menu.seal_of_wisdom_mana_pct and menu.seal_of_wisdom_mana_pct:get()) or 20) / 100
        if mana_pct <= threshold then
            if current_seal ~= "wisdom" and runtime.seal_of_wisdom_id then
                if utils.can_cast_self(runtime.seal_of_wisdom_id, me) and utils.cast_self(runtime.seal_of_wisdom_id, me) then
                    note_cast()
                    if menu.debug and menu.debug:get_state() then
                        utils.log_debug(menu, "Seal: Wisdom (low mana)")
                    end
                    return true
                end
            end
        end
    end
    
    -- Normal seal selection
    local desired_seal = "righteousness"
    local seal_id = runtime.seal_of_righteousness_id
    if seal_choice == 2 and runtime.seal_of_vengeance_id then
        desired_seal = "vengeance"
        seal_id = runtime.seal_of_vengeance_id
    elseif seal_choice == 3 and runtime.seal_of_wisdom_id then
        desired_seal = "wisdom"
        seal_id = runtime.seal_of_wisdom_id
    end
    
    if current_seal == desired_seal then return false end
    
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
    if utils.has_buff(me, spells.BUFF_DEVOTION_AURA) or utils.has_buff(me, spells.BUFF_RETRIBUTION_AURA) then
        return false
    end
    
    local aura_id = runtime.devotion_aura_id
    if aura_id and utils.can_cast_self(aura_id, me) then
        if utils.cast_self(aura_id, me) then
            runtime.last_aura_cast_at = _core_time()
            note_cast()
            if menu.debug and menu.debug:get_state() then
                utils.log_debug(menu, "Devotion Aura")
            end
            return true
        end
    end
    return false
end

-- Righteous Fury check
local function ensure_righteous_fury(me)
    if utils.has_buff(me, spells.BUFF_RIGHTEOUS_FURY) then return false end
    if not runtime.righteous_fury_id then return false end
    if utils.can_cast_self(runtime.righteous_fury_id, me) and utils.cast_self(runtime.righteous_fury_id, me) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Righteous Fury")
        end
        return true
    end
    return false
end

-- Holy Shield (critical for tanking)
local function try_holy_shield(me)
    if not (menu.use_holy_shield and menu.use_holy_shield:get_state()) then return false end
    if not runtime.holy_shield_id then return false end
    if utils.has_buff(me, spells.BUFF_HOLY_SHIELD) then
        -- Check remaining duration
        local remaining = utils.get_buff_remaining_ms(me, spells.BUFF_HOLY_SHIELD)
        if remaining > 2000 then return false end -- Still has >2s left
    end
    if not utils.can_cast_self(runtime.holy_shield_id, me) then return false end
    if utils.cast_self(runtime.holy_shield_id, me) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Holy Shield")
        end
        return true
    end
    return false
end

-- Avenger's Shield (pull only)
local function try_avengers_shield(me, target)
    if not (menu.use_avengers_shield and menu.use_avengers_shield:get_state()) then return false end
    if not runtime.avengers_shield_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    -- Only use in first 3 seconds of combat
    local combat_time = _core_time() - runtime.combat_start_time
    if combat_time > 3 then return false end
    if not utils.can_cast_target(runtime.avengers_shield_id, me, target) then return false end
    if utils.cast_target(runtime.avengers_shield_id, me, target) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Avenger's Shield")
        end
        return true
    end
    return false
end

-- Consecration (AoE threat)
local function try_consecration(me)
    if not (menu.use_consecration and menu.use_consecration:get_state()) then return false end
    if not runtime.consecration_id then return false end
    -- Mana check - only use if >30% mana
    if utils.get_mana_pct(me) < 0.30 then return false end
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

-- Judgement
local function try_judgement(me, target)
    if not (menu.use_judgement and menu.use_judgement:get_state()) then return false end
    if not runtime.judgement_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    if not utils.is_melee_target(me, target) then return false end
    if not utils.can_cast_target(runtime.judgement_id, me, target) then return false end
    -- Need a seal active
    if get_active_seal(me) == "none" then return false end
    if utils.cast_target(runtime.judgement_id, me, target) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Judgement")
        end
        return true
    end
    return false
end

-- Exorcism (Undead/Demon only)
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

-- Hammer of Wrath (execute)
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

-- Holy Wrath (Undead/Demon AoE)
local function try_holy_wrath(me)
    if not runtime.holy_wrath_id then return false end
    local enemy_count = utils.count_enemies_within_radius(me, 8)
    if enemy_count < 3 then return false end
    -- Check if any are undead/demon
    local has_valid_target = false
    local objects = core.object_manager.get_visible_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and me:can_attack(obj) and utils.is_undead_or_demon(obj) then
            has_valid_target = true
            break
        end
    end
    if not has_valid_target then return false end
    if utils.get_mana_pct(me) < 0.40 then return false end
    if not utils.can_cast_self(runtime.holy_wrath_id, me) then return false end
    if utils.cast_self(runtime.holy_wrath_id, me) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Holy Wrath")
        end
        return true
    end
    return false
end

-- Righteous Defense (taunt)
local function try_righteous_defense(me, target)
    if menu.no_taunt and menu.no_taunt:get_state() then return false end
    if not (menu.use_righteous_defense and menu.use_righteous_defense:get_state()) then return false end
    if not runtime.righteous_defense_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    -- Only taunt if we don't have aggro
    if utils.has_target_aggro(target, me) then return false end
    -- Check if target is attacking a party member
    local target_target = target:get_target()
    if not target_target then return false end
    if utils.same_unit(target_target, me) then return false end
    -- Don't taunt players
    if target:is_player() then return false end
    -- Only taunt elites/bosses
    local ok, classification = pcall(function() return target:get_classification() end)
    if ok and classification then
        if classification < 2 then return false end -- 0=normal, 1=elite, 2=rareelite, 3=worldboss
    end
    if not utils.can_cast_target(runtime.righteous_defense_id, me, target) then return false end
    if utils.cast_target(runtime.righteous_defense_id, me, target) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Righteous Defense")
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

local function try_divine_shield(me, ctx)
    if not (menu.use_divine_shield and menu.use_divine_shield:get_state()) then return false end
    if not runtime.divine_shield_id then return false end
    
    -- Use smart_defensive for predictive mitigation
    local settings = {
        divine_shield_hp = ((menu.divine_shield_hp_pct and menu.divine_shield_hp_pct:get()) or 15),
    }
    local should_use, reason = smart_defensive.should_use(me, "divine_shield", ctx or {}, settings)
    
    if not should_use then return false end
    if not utils.can_cast_self(runtime.divine_shield_id, me) then return false end
    if utils.cast_self(runtime.divine_shield_id, me) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Divine Shield (" .. (reason or "emergency") .. ")")
        end
        return true
    end
    return false
end

local function try_lay_on_hands(me, ctx)
    if not (menu.use_lay_on_hands and menu.use_lay_on_hands:get_state()) then return false end
    if not runtime.lay_on_hands_id then return false end
    
    -- Use smart_defensive for predictive mitigation
    local settings = {
        lay_on_hands_hp = ((menu.lay_on_hands_hp_pct and menu.lay_on_hands_hp_pct:get()) or 15),
    }
    local should_use, reason = smart_defensive.should_use(me, "lay_on_hands", ctx or {}, settings)
    
    if not should_use then return false end
    if not utils.can_cast_self(runtime.lay_on_hands_id, me) then return false end
    if utils.cast_self(runtime.lay_on_hands_id, me) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Lay on Hands (" .. (reason or "emergency") .. ")")
        end
        return true
    end
    return false
end

-- Cleanse
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

-- Hammer of Justice (interrupt)
local function try_hammer_of_justice(me, target)
    if not (menu.use_hammer_of_justice and menu.use_hammer_of_justice:get_state()) then return false end
    if not runtime.hammer_of_justice_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    -- Check if target is casting
    local ok, is_casting = pcall(function() return target:is_casting_spell() end)
    if not ok or not is_casting then return false end
    if not utils.can_cast_target(runtime.hammer_of_justice_id, me, target) then return false end
    if utils.cast_target(runtime.hammer_of_justice_id, me, target) then
        note_cast()
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Hammer of Justice (interrupt)")
        end
        return true
    end
    return false
end

-- OOC buffs (delegated to ooc_manager)
local function try_ooc_buffs(me)
    if me:is_in_combat() then return false end
    
    local resolved = {
        redemption = runtime.redemption_id,
        blessing_of_kings = runtime.blessing_of_kings_id,
        blessing_of_sanctuary = runtime.blessing_of_sanctuary_id,
        blessing_of_might = runtime.blessing_of_might_id,
        blessing_of_wisdom = runtime.blessing_of_wisdom_id,
        righteous_fury = runtime.righteous_fury_id,
        devotion_aura = runtime.devotion_aura_id,
    }
    
    return ooc_manager.on_update(me, menu, utils, {
        rez_spell_id = resolved.redemption,
        group_buffs = {
            {
                spell_id = resolved.blessing_of_might,
                buff_ids = spells.BUFF_BLESSING_OF_MIGHT,
                name = "Blessing of Might",
                toggle = menu.use_blessing_of_might
            },
            {
                spell_id = resolved.blessing_of_wisdom,
                buff_ids = spells.BUFF_BLESSING_OF_WISDOM,
                name = "Blessing of Wisdom",
                toggle = menu.use_blessing_of_wisdom
            },
            {
                spell_id = resolved.blessing_of_kings,
                buff_ids = spells.BUFF_BLESSING_OF_KINGS,
                name = "Blessing of Kings",
                toggle = menu.use_blessing_of_kings
            },
            {
                spell_id = resolved.blessing_of_sanctuary,
                buff_ids = spells.BUFF_BLESSING_OF_SANCTUARY,
                name = "Blessing of Sanctuary",
                toggle = menu.use_blessing_of_sanctuary
            },
            {
                spell_id = resolved.righteous_fury,
                buff_ids = spells.BUFF_RIGHTEOUS_FURY,
                name = "Righteous Fury",
                toggle = menu.use_righteous_fury
            },
            {
                spell_id = resolved.devotion_aura,
                buff_ids = spells.BUFF_DEVOTION_AURA,
                name = "Devotion Aura",
                toggle = menu.use_devotion_aura
            },
        }
    })
end

-- Auto tab targeting for threat management
local function try_auto_tab(me)
    if not (menu.use_auto_tab and menu.use_auto_tab:get_state()) then return false end
    if (_core_time() - runtime.last_tab_target_at) < runtime.tab_target_cooldown then return false end
    
    local current_target = me:get_target()
    if not current_target or not current_target:is_valid() then return false end
    
    -- If we have aggro on current target, check for others
    if utils.has_target_aggro(current_target, me) then
        -- Look for mobs attacking party members
        local party = utils.get_party_units(me)
        local objects = core.object_manager.get_visible_objects()
        local max_mobs = (menu.tab_max_mobs and menu.tab_max_mobs:get()) or 4
        local managed_mobs = 0
        
        for i = 1, #objects do
            local obj = objects[i]
            if obj and obj:is_valid() and me:can_attack(obj) and obj:is_in_combat() then
                if utils.has_target_aggro(obj, me) then
                    managed_mobs = managed_mobs + 1
                end
            end
        end
        
        if managed_mobs >= max_mobs then return false end
        
        -- Find a mob attacking a party member that we don't have aggro on
        for i = 1, #objects do
            local obj = objects[i]
            if obj and obj:is_valid() and me:can_attack(obj) and obj:is_in_combat() and not utils.has_target_aggro(obj, me) then
                local obj_target = obj:get_target()
                if obj_target then
                    for _, party_member in ipairs(party) do
                        if utils.same_unit(obj_target, party_member) then
                            -- Found one - would tab target here
                            runtime.last_tab_target_at = _core_time()
                            return false -- Return false to not consume GCD, just tracking
                        end
                    end
                end
            end
        end
    end
    return false
end

-- Toggle handling removed - unified menu handles toggling

-- Initialize
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
        use_avenging_wrath = (menu.use_avenging_wrath and menu.use_avenging_wrath:get_state()) or false,
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
    local cc_detector = require("libraries/cc_detector")
    local should_stop, cc_reason = cc_detector.should_stop_rotation(me)

    -- Paladin special: Try Divine Shield for any CC before stopping
    if should_stop then
        if defensive_manager.try_divine_shield_cc_break(me, menu) then
            return  -- Successfully broke CC
        end
    end

    if should_stop then
        if (menu.debug and menu.debug:get_state()) then
            print(string.format("[CC] Rotation paused: %s", cc_reason or "CC"))
        end
        return  -- Stop rotation while CC'd
    end
    
    -- Track combat start
    if me:is_in_combat() and runtime.combat_start_time == 0 then
        runtime.combat_start_time = _core_time()
    elseif not me:is_in_combat() then
        runtime.combat_start_time = 0
    end
    
    -- OOC buffs
    if try_ooc_buffs(me) then return end
    
    -- Maintain Righteous Fury (critical for tanking)
    if ensure_righteous_fury(me) then return end
    
    -- Maintain aura
    if ensure_aura(me) then return end
    
    -- Don't cast while eating/drinking
    if eax_utils.is_eating_or_drinking(me) then return end
    
    local target = me:get_target()
    
    -- NEW: Build rotation context once per frame
    local tank_ctx = context_builder.build(me, target, menu)
    
    -- NEW: Update manual target detection for threat_tab_manager
    threat_tab_manager.update_manual_target(target)
    
    -- NEW: Threat-aware tab targeting (replaces basic try_auto_tab)
    local should_tab, tab_reason, new_target = threat_tab_manager.should_tab(me, target, menu)
    if should_tab and new_target then
        if threat_tab_manager.execute_tab(me) then
            if menu.debug and menu.debug:get_state() then
                utils.log_debug(menu, "Tab target: " .. tab_reason)
            end
            -- Update target to new one
            target = new_target
            tank_ctx = context_builder.build(me, target, menu)
        end
    end
    
    -- Defensive CDs (with smart_defensive prediction)
    if try_divine_shield(me, tank_ctx) then return end
    if try_lay_on_hands(me, tank_ctx) then return end
    
    -- Only continue if in combat
    if not me:is_in_combat() then return end
    
    -- Consumables
    if menu.auto_combat_potions and menu.auto_combat_potions:get_state() then
        consumables_manager.try_use_combat_consumable(me, menu, utils)
    end
    
    -- Racial
    racial_manager.try_defensive(me)
    
    -- Avenging Wrath
    if try_avenging_wrath(me) then return end
    
    -- Cleanse
    if try_cleanse(me) then return end
    
    -- Interrupt
    if target and target:is_valid() then
        if try_hammer_of_justice(me, target) then return end
    end
    
    -- Avenger's Shield (pull only, first 3s)
    if try_avengers_shield(me, target) then return end
    
    -- Holy Shield (critical - prioritize if enabled)
    local prioritize_hs = menu.prioritize_holy_shield and menu.prioritize_holy_shield:get_state()
    if prioritize_hs and try_holy_shield(me) then return end
    
    -- Maintain seal
    if ensure_seal(me) then return end
    
    -- Consecration (AoE threat)
    if try_consecration(me) then return end
    
    -- Judgement
    if target and target:is_valid() then
        if try_judgement(me, target) then return end
    end
    
    -- Righteous Defense (taunt)
    if target and target:is_valid() then
        if try_righteous_defense(me, target) then return end
    end
    
    -- Holy Shield (fallback if not prioritized)
    if not prioritize_hs and try_holy_shield(me) then return end
    
    -- Fillers
    if target and target:is_valid() then
        if try_hammer_of_wrath(me, target) then return end
        if try_exorcism(me, target) then return end
    end
    
    -- Holy Wrath (AoE undead/demon)
    if (menu.use_holy_wrath and menu.use_holy_wrath:get_state()) then
        if try_holy_wrath(me) then return end
    end

    -- Defensive trinket check (tank mode - not burst)
    trinket_manager.check_trinkets(me, false, menu)
end)

-- Initialize dashboard
dashboard.init(dashboard_config)
dashboard.register_render_callback()

-- Export toggle settings for external access
local NS = _G.EAXPaladinProtection and _G.EAXPaladinProtection.NS or {}
_G.EAXPaladinProtection = _G.EAXPaladinProtection or {}
_G.EAXPaladinProtection.NS = NS
NS.toggle_menu = menu.toggle_menu

