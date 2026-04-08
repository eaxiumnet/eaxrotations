-- EAX Druid Bear | Project Sylvanas
-- Priority: Mangle -> Lacerate -> Swipe -> Maul

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")
local ooc_manager = require("libraries/ooc_manager")
local form_consumables = require("libraries/form_consumables")
local dashboard = require("libraries/dashboard")
local dashboard_config = require("libraries/dashboard_config")

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

-- Runtime state
local rt = {
    last_spell_refresh = 0,
    cached_mode = "solo",
    prev_toggle_state = false,
    saved_form = nil,  -- For form_consumables restoration
    -- Spell IDs
    maul_id = nil,
    swipe_id = nil,
    lacerate_id = nil,
    mangle_bear_id = nil,
    demo_roar_id = nil,
    frenzied_regen_id = nil,
    growl_id = nil,
    challenging_roar_id = nil,
    bash_id = nil,
    enrage_id = nil,
    barkskin_id = nil,
    bear_form_id = nil,
    dire_bear_form_id = nil,
    mark_of_the_wild_id = nil,
    feral_charge_id = nil,
    faerie_fire_feral_id = nil,
    -- State
    lacerate_stacks = 0,
}

local SPELL_REFRESH = 1.0
local MODE_REFRESH = 4.5

-- Helpers
local function get_me() return _get_local_player() end

local function resolve()
    local now = _core_time()
    if (now - rt.last_spell_refresh) < SPELL_REFRESH then return end
    rt.last_spell_refresh = now
    rt.maul_id = utils.resolve_spell_id(spells.MAUL)
    rt.swipe_id = utils.resolve_spell_id(spells.SWIPE)
    rt.lacerate_id = utils.resolve_spell_id(spells.LACERATE)
    rt.mangle_bear_id = utils.resolve_spell_id(spells.MANGLE_BEAR)
    rt.demo_roar_id = utils.resolve_spell_id(spells.DEMORALIZING_ROAR)
    rt.frenzied_regen_id = utils.resolve_spell_id(spells.FRENZIED_REGENERATION)
    rt.growl_id = utils.resolve_spell_id(spells.GROWL)
    rt.challenging_roar_id = utils.resolve_spell_id(spells.CHALLENGING_ROAR)
    rt.bash_id = utils.resolve_spell_id(spells.BASH)
    rt.enrage_id = utils.resolve_spell_id(spells.ENRAGE)
    rt.barkskin_id = utils.resolve_spell_id(spells.BARKSKIN)
    rt.bear_form_id = utils.resolve_spell_id(spells.BEAR_FORM)
    rt.dire_bear_form_id = utils.resolve_spell_id(spells.DIRE_BEAR_FORM)
    rt.mark_of_the_wild_id = utils.resolve_spell_id(spells.MARK_OF_THE_WILD)
    rt.thorns_id = utils.resolve_spell_id(spells.THORNS)
    rt.feral_charge_id = utils.resolve_spell_id(spells.FERAL_CHARGE)
    rt.faerie_fire_feral_id = utils.resolve_spell_id(spells.FAERIE_FIRE_FERAL)
end

local function rage(me)
    return utils.get_rage(me)
end

local function has_debuff(target, tbl)
    return utils.has_debuff(target, tbl)
end

local function debuff_stacks(target, spell_id)
    if not target or not target:is_valid() then return 0 end
    local d = target:get_debuff_data({ spell_id })
    if d and d.is_active then return d.stacks or 0 end
    return 0
end

local function detect_mode()
    local n = 0
    for _, o in ipairs(core.object_manager.get_all_objects()) do
        if o and o:is_valid() and o:is_unit() and not o:is_dead() and o:is_party_member() then
            n = n + 1
        end
    end
    if n == 0 then return "solo" elseif n <= 4 then return "dungeon" end
    return "raid"
end

local function active_mode()
    local s = (menu.mode and menu.mode:get()) or 1
    if s == 2 then return "solo" elseif s == 3 then return "dungeon" elseif s == 4 then return "raid" end
    return rt.cached_mode
end

-- Rotation functions
local function try_bear_form(me)
    if not rt.bear_form_id then return false end
    if utils.has_buff(me, spells.BUFF_BEAR_FORM) then return false end
    if not utils.can_cast_self(rt.bear_form_id, me) then return false end
    if utils.cast_self(rt.bear_form_id, me) then
        utils.log_debug(menu, "Bear Form")
        return true
    end
    return false
end

local function try_frenzied_regeneration(me, ctx)
    if not (menu.use_frenzied_regen and menu.use_frenzied_regen.get and menu.use_frenzied_regen:get()) then return false end
    if not rt.frenzied_regen_id then return false end
    
    -- Use smart_defensive for predictive mitigation
    local settings = {
        frenzied_regen_hp = ((menu.frenzied_regen_hp and menu.frenzied_regen_hp:get_value()) or 30),
    }
    local should_use, reason = smart_defensive.should_use(me, "frenzied_regen", ctx or {}, settings)
    
    if not should_use then return false end
    if rage(me) < 10 then return false end
    if not utils.can_cast_self(rt.frenzied_regen_id, me) then return false end
    if utils.cast_self(rt.frenzied_regen_id, me) then
        utils.log_debug(menu, "Frenzied Regeneration (" .. (reason or "hp_threshold") .. ")")
        return true
    end
    return false
end

local function try_barkskin(me, ctx)
    local use_barkskin = (menu.use_barkskin and menu.use_barkskin.is_checked and menu.use_barkskin:is_checked()) or false
    if not use_barkskin then return false end
    if not rt.barkskin_id then return false end
    
    -- Use smart_defensive for predictive mitigation
    local settings = {
        barkskin_hp = ((menu.barkskin_hp and menu.barkskin_hp:get_value()) or 40),
    }
    local should_use, reason = smart_defensive.should_use(me, "barkskin", ctx or {}, settings)
    
    if not should_use then return false end
    if not utils.can_cast_self(rt.barkskin_id, me) then return false end
    if utils.cast_self(rt.barkskin_id, me) then
        utils.log_debug(menu, "Barkskin (" .. (reason or "hp_threshold") .. ")")
        return true
    end
    return false
end

local function try_growl(me, t)
    if not (menu.use_growl and menu.use_growl.get and menu.use_growl:get()) then return false end
    if not rt.growl_id then return false end
    if not utils.can_cast_hostile(rt.growl_id, me, t) then return false end
    if utils.cast_target(rt.growl_id, me, t) then
        utils.log_debug(menu, "Growl")
        return true
    end
    return false
end

local function try_challenging_roar(me)
    if not (menu.use_challenging_roar and menu.use_challenging_roar.get and menu.use_challenging_roar:get()) then return false end
    if not rt.challenging_roar_id then return false end
    if not utils.can_cast_self(rt.challenging_roar_id, me) then return false end
    if utils.cast_self(rt.challenging_roar_id, me) then
        utils.log_debug(menu, "Challenging Roar")
        return true
    end
    return false
end

-- NEW: Bash interrupt function
local function try_bash(me, t)
    -- Check if Bash is enabled in menu
    local use_bash = (menu.use_bash and menu.use_bash.get and menu.use_bash:get()) or false
    if not use_bash then return false end
    
    -- Check if Bash spell is resolved
    if not rt.bash_id then return false end
    
    -- Check if target is casting and interruptible
    if not utils.is_target_casting(t) then return false end
    if not utils.is_casting_interruptible(t) then return false end
    
    -- Check rage requirement (Bash costs 10 rage)
    if rage(me) < 10 then return false end
    
    -- Check if we can cast on target
    if not utils.can_cast_hostile(rt.bash_id, me, t) then return false end
    
    -- Cast Bash
    if utils.cast_target(rt.bash_id, me, t) then
        utils.log_debug(menu, "Bash (Interrupt)")
        return true
    end
    return false
end

local function try_mangle(me, t)
    if not (menu.use_mangle and menu.use_mangle.get and menu.use_mangle:get()) then return false end
    if not rt.mangle_bear_id then return false end
    if rage(me) < 20 then return false end
    if not utils.can_cast_hostile(rt.mangle_bear_id, me, t) then return false end
    if utils.cast_target(rt.mangle_bear_id, me, t) then
        utils.log_debug(menu, "Mangle")
        return true
    end
    return false
end

local function try_faerie_fire_feral(me, t)
    if not (menu.use_faerie_fire and menu.use_faerie_fire.get and menu.use_faerie_fire:get()) then return false end
    if not rt.faerie_fire_feral_id then return false end
    -- Check if target already has Faerie Fire (normal or feral)
    if has_debuff(t, spells.DEBUFF_FAERIE_FIRE) then return false end
    if has_debuff(t, spells.DEBUFF_FAERIE_FIRE_FERAL) then return false end
    if rage(me) < 15 then return false end
    if not utils.can_cast_hostile(rt.faerie_fire_feral_id, me, t) then return false end
    if utils.cast_target(rt.faerie_fire_feral_id, me, t) then
        utils.log_debug(menu, "Faerie Fire (Feral)")
        return true
    end
    return false
end

local function try_lacerate(me, t)
    if not (menu.use_lacerate and menu.use_lacerate.get and menu.use_lacerate:get()) then return false end
    if not rt.lacerate_id then return false end
    local stacks = debuff_stacks(t, rt.lacerate_id)
    if stacks >= 5 then return false end
    if rage(me) < 15 then return false end
    if not utils.can_cast_hostile(rt.lacerate_id, me, t) then return false end
    if utils.cast_target(rt.lacerate_id, me, t) then
        utils.log_debug(menu, "Lacerate (" .. (stacks + 1) .. "/5)")
        return true
    end
    return false
end

local function try_swipe(me, t)
    if not (menu.use_swipe and menu.use_swipe.get and menu.use_swipe:get()) then return false end
    if not rt.swipe_id then return false end
    local min_targets = (menu.swipe_min_targets and menu.swipe_min_targets:get()) or 2
    local count = 1
    local tp = t:get_position()
    if tp then
        for _, o in ipairs(core.object_manager.get_all_objects()) do
            if o and o:is_valid() and o:is_unit() and not o:is_dead() and me:can_attack(o) and o ~= t then
                local op = o:get_position()
                if op then
                    local dx, dy, dz = op.x - tp.x, op.y - tp.y, op.z - tp.z
                    if (dx * dx + dy * dy + dz * dz) <= 64 then
                        count = count + 1
                    end
                end
            end
        end
    end
    if count < min_targets then return false end
    if rage(me) < 20 then return false end
    if not utils.can_cast_hostile(rt.swipe_id, me, t) then return false end
    if utils.cast_target(rt.swipe_id, me, t) then
        utils.log_debug(menu, "Swipe (" .. count .. " targets)")
        return true
    end
    return false
end

local function try_demo_roar(me, t)
    if not (menu.use_demo_roar and menu.use_demo_roar.get and menu.use_demo_roar:get()) then return false end
    if not rt.demo_roar_id then return false end
    if has_debuff(t, spells.DEBUFF_DEMORALIZING_ROAR) then return false end
    if rage(me) < 10 then return false end
    if not utils.can_cast_hostile(rt.demo_roar_id, me, t) then return false end
    if utils.cast_target(rt.demo_roar_id, me, t) then
        utils.log_debug(menu, "Demoralizing Roar")
        return true
    end
    return false
end

local function try_maul(me, t)
    if not (menu.use_maul and menu.use_maul.get and menu.use_maul:get()) then return false end
    if not rt.maul_id then return false end
    if rage(me) < 15 then return false end
    if not utils.can_cast_hostile(rt.maul_id, me, t) then return false end
    if utils.cast_target(rt.maul_id, me, t) then
        utils.log_debug(menu, "Maul")
        return true
    end
    return false
end

local function try_enrage(me)
    if not (menu.use_enrage and menu.use_enrage.get and menu.use_enrage:get()) then return false end
    if not rt.enrage_id then return false end
    if rage(me) > 30 then return false end
    if not utils.can_cast_self(rt.enrage_id, me) then return false end
    if utils.cast_self(rt.enrage_id, me) then
        utils.log_debug(menu, "Enrage")
        return true
    end
    return false
end

local function try_feral_charge(me, t)
    if not (menu.use_feral_charge and menu.use_feral_charge.get and menu.use_feral_charge:get()) then return false end
    if not rt.feral_charge_id then return false end
    if rage(me) < 5 then return false end
    local dist_sq = utils.dist_squared(me, t)
    if not dist_sq or dist_sq <= 64 then return false end  -- 8 yards squared = 64
    if not utils.can_cast_hostile(rt.feral_charge_id, me, t) then return false end
    if utils.cast_target(rt.feral_charge_id, me, t) then
        utils.log_debug(menu, "Feral Charge")
        return true
    end
    return false
end

-- Main rotation
local function do_rotation(me, t, ctx)
    -- Ensure in bear form
    if not utils.has_buff(me, spells.BUFF_BEAR_FORM) then
        if try_bear_form(me) then return end
    end

    -- Defensive (with smart_defensive prediction)
    if try_frenzied_regeneration(me, ctx) then return end
    if try_barkskin(me, ctx) then return end

    -- Taunts
    if try_growl(me, t) then return end

    -- Interrupts (high priority)
    if try_bash(me, t) then return end

    -- Cooldowns
    if try_enrage(me) then return end

    -- Gap closer (before Mangle)
    if try_feral_charge(me, t) then return end

    -- Rotation priority
    if try_mangle(me, t) then return end
    if try_faerie_fire_feral(me, t) then return end
    if try_demo_roar(me, t) then return end
    if try_lacerate(me, t) then return end
    if try_swipe(me, t) then return end
    if try_maul(me, t) then return end
end

-- Update loop
local function on_update()
    resolve()
    local me = get_me()
    if utils.throttle("bearmode", MODE_REFRESH) then
        rt.cached_mode = detect_mode()
    end
    if not menu or not (menu.enabled and menu.enabled:get_state()) then
        dashboard.set_enabled(false)  -- Disable dashboard when rotation is off
        return
    end

    -- Enable dashboard when rotation is active (respect menu setting)
    local show_dashboard = (menu.show_dashboard and menu.show_dashboard.get and menu.show_dashboard:get()) or false
    dashboard.set_enabled(show_dashboard)
    
    -- Sync dashboard settings (safe pcall for uninitialized menu items)
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
    
    if not me or me:is_dead() then return end

    -- CC Detection: Stop rotation if crowd controlled
    local cc_detector = require("libraries/cc_detector")
    local should_stop, cc_reason = cc_detector.should_stop_rotation(me)

    -- Druid special: Try shapeshift for roots before stopping
    if should_stop and cc_reason == "ROOTS" then
        if utils.try_shapeshift_root_break(me, menu) then
            return  -- Successfully broke root
        end
    end

    if should_stop then
        return  -- Stop rotation while CC'd
    end

    -- OOC handling
    if not me:is_in_combat() then
        ooc_manager.on_update(me, menu, utils, {
            group_buffs = {
                {
                    spell_id = rt.mark_of_the_wild_id,
                    buff_ids = spells.BUFF_MARK_OF_THE_WILD,
                    name = "Mark of the Wild",
                    toggle = menu.use_motw
                },
                {
                    spell_id = rt.bear_form_id,
                    buff_ids = spells.BUFF_BEAR_FORM,
                    name = "Bear Form",
                    toggle = menu.use_bear_form
                },
                {
                    spell_id = rt.thorns_id,
                    buff_ids = spells.BUFF_THORNS,
                    name = "Thorns",
                    toggle = menu.use_thorns
                },
            }
        })
        return  -- Fix: Exit after OOC buffs to prevent combat rotation from overwriting
    end

    local t = me:get_target()
    if not t or not t:is_valid() or t:is_dead() then return end
    if not me:can_attack(t) then return end
    
    -- NEW: Build rotation context once per frame
    local ctx = context_builder.build(me, t, menu)
    
    -- NEW: Update manual target detection for threat_tab_manager
    threat_tab_manager.update_manual_target(t)
    
    -- NEW: Threat-aware tab targeting
    local should_tab, tab_reason, new_target = threat_tab_manager.should_tab(me, t, menu)
    if should_tab and new_target then
        if threat_tab_manager.execute_tab(me) then
            utils.log_debug(menu, "Tab target: " .. tab_reason)
            -- Update target to new one
            t = new_target
            ctx = context_builder.build(me, t, menu)
        end
    end

    -- Form-aware consumables
    local use_form_consumables = (menu.use_form_consumables and menu.use_form_consumables.get and menu.use_form_consumables:get()) or false
    if use_form_consumables then
        local form_spells = {
            BEAR = rt.bear_form_id,
            DIRE_BEAR = rt.dire_bear_form_id,
        }
        local used, saved_form, reason = form_consumables.check_and_use(me, menu, form_spells, rt.saved_form)
        if used then
            rt.saved_form = saved_form
            if reason then utils.log_debug(menu, "Form consumable: " .. reason) end
        elseif saved_form == nil and rt.saved_form then
            rt.saved_form = nil
        end
    end

    -- NEW: Pass context to rotation
    do_rotation(me, t, ctx)

    -- Defensive trinket check (tank mode - not burst)
    trinket_manager.check_trinkets(me, false, menu)
end

core.register_on_update_callback(on_update)

-- Register menu render callback
core.register_on_render_menu_callback(function()
    menu.render()
end)

-- Initialize dashboard
local config = require("libraries/dashboard_config")
dashboard.init(config)
dashboard.register_render_callback()

-- Export toggle settings for external access
local NS = _G.EAXDruidBear and _G.EAXDruidBear.NS or {}
_G.EAXDruidBear = _G.EAXDruidBear or {}
_G.EAXDruidBear.NS = NS
NS.toggle_menu = menu.toggle_menu

return {}
