-- EAX Druid Feral | Project Sylvanas
-- Priority: Prowl -> Ravage -> DoTs -> Finishers -> Builders

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")
local energy_tick = require("libraries/energy_tick")
local powershift = require("libraries/powershift")
local combat_forecast = require("libraries/combat_forecast")
local force_commands = require("libraries/force_commands")
local middleware_manager = require("libraries/middleware_manager")
local dashboard = require("libraries/dashboard")
local dashboard_config = require("libraries/dashboard_config")
local ooc_manager = require("libraries/ooc_manager")
local form_consumables = require("libraries/form_consumables")
local burst_manager = require("libraries/burst_manager")
local trinket_manager = require("libraries/trinket_manager")

-- Hot-path local caching
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player

-- Runtime state
local rt = {
    last_spell_refresh = 0,
    cached_mode = "solo",
    prev_toggle_state = false,
    combat_start_time = nil,
    -- Spell IDs
    shred_id = nil,
    rake_id = nil,
    rip_id = nil,
    ferocious_bite_id = nil,
    mangle_cat_id = nil,
    tigers_fury_id = nil,
    prowl_id = nil,
    ravage_id = nil,
    cat_form_id = nil,
    faerie_fire_id = nil,
    -- PvP Spell IDs
    entangling_roots_id = nil,
    hibernate_id = nil,
    -- State
    last_powershift_time = 0,
    pvp_context = nil,
    saved_form = nil,  -- For form_consumables restoration
    spell_costs = {
        shred = 42,
        mangle = 40,
        rake = 35,
        rip = 30,
        ferocious_bite = 35,
        ravage = 60,
        tigers_fury = 30,
    },
}

local SPELL_REFRESH = 1.0
local MODE_REFRESH = 4.5
local ENERGY_TICK = 2.0
local SHIFT_COOLDOWN = 1.0

-- Helpers
local function get_me() return _get_local_player() end

local function resolve()
    local now = _core_time()
    if (now - rt.last_spell_refresh) < SPELL_REFRESH then return end
    rt.last_spell_refresh = now

    local function get_spell_cost(spell_id, fallback)
        if not spell_id then return fallback end
        if core.spell_book and core.spell_book.get_spell_power_cost then
            local cost = core.spell_book.get_spell_power_cost(spell_id)
            if cost and cost > 0 then return cost end
        end
        return fallback
    end

    rt.shred_id = utils.resolve_spell_id(spells.SHRED)
    rt.rake_id = utils.resolve_spell_id(spells.RAKE)
    rt.rip_id = utils.resolve_spell_id(spells.RIP)
    rt.ferocious_bite_id = utils.resolve_spell_id(spells.FEROCIOUS_BITE)
    rt.mangle_cat_id = utils.resolve_spell_id(spells.MANGLE_CAT)
    rt.tigers_fury_id = utils.resolve_spell_id(spells.TIGERS_FURY)
    rt.prowl_id = utils.resolve_spell_id(spells.PROWL)
    rt.ravage_id = utils.resolve_spell_id(spells.RAVAGE)
    rt.cat_form_id = utils.resolve_spell_id(spells.CAT_FORM)
    rt.faerie_fire_id = utils.resolve_spell_id(spells.FAERIE_FIRE_FERAL) or utils.resolve_spell_id(spells.FAERIE_FIRE)
    
    -- PvP spells
    rt.entangling_roots_id = utils.resolve_spell_id(spells.ENTANGLING_ROOTS)
    rt.hibernate_id = utils.resolve_spell_id(spells.HIBERNATE)

    rt.spell_costs.shred = get_spell_cost(rt.shred_id, 42)
    rt.spell_costs.mangle = get_spell_cost(rt.mangle_cat_id, 40)
    rt.spell_costs.rake = get_spell_cost(rt.rake_id, 35)
    rt.spell_costs.rip = get_spell_cost(rt.rip_id, 30)
    rt.spell_costs.ferocious_bite = get_spell_cost(rt.ferocious_bite_id, 35)
    rt.spell_costs.ravage = get_spell_cost(rt.ravage_id, 60)
    rt.spell_costs.tigers_fury = get_spell_cost(rt.tigers_fury_id, 30)

    -- OOC buffs
    rt.thorns_id = utils.resolve_spell_id(spells.THORNS)
end

local function energy(me)
    return utils.get_energy(me)
end

local function combo_points(me)
    return utils.get_combo_points(me)
end

local function has_debuff(target, tbl)
    return utils.has_debuff(target, tbl)
end

local function debuff_rem(target, tbl)
    if not target or not target:is_valid() then return 0 end
    local d = target:get_debuff_data(tbl)
    if d and d.is_active and (d.remaining or 0) > 0 then return d.remaining end
    d = target:get_aura_data(tbl)
    if d and d.is_active and (d.remaining or 0) > 0 then return d.remaining end
    return 0
end

local function is_stealthed(me)
    return utils.has_buff(me, spells.BUFF_PROWL)
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
    local ok, s = pcall(function() return menu.mode:get() end)
    if not ok then s = 1 end
    if s == 2 then return "solo" elseif s == 3 then return "dungeon" elseif s == 4 then return "raid" end
    return rt.cached_mode
end

-- Rotation functions
local function try_cat_form(me)
    if not rt.cat_form_id then return false end
    if utils.has_buff(me, spells.BUFF_CAT_FORM) then return false end
    if not utils.can_cast_self(rt.cat_form_id, me) then return false end
    if utils.cast_self(rt.cat_form_id, me) then
        utils.log_debug(menu, "Cat Form")
        energy_tick.on_shift()  -- Reset energy tick tracking after shift
        return true
    end
    return false
end

local function try_prowl(me)
    if not (menu.use_prowl and menu.use_prowl:get_state()) then return false end
    if not rt.prowl_id then return false end
    if me:is_in_combat() then return false end
    if is_stealthed(me) then return false end
    if not utils.can_cast_self(rt.prowl_id, me) then return false end
    if utils.cast_self(rt.prowl_id, me) then
        utils.log_debug(menu, "Prowl")
        return true
    end
    return false
end

local function try_ravage(me, t)
    if not rt.ravage_id then return false end
    if not is_stealthed(me) then return false end
    if energy(me) < 60 then return false end
    if not utils.can_cast_hostile(rt.ravage_id, me, t) then return false end
    if utils.cast_target(rt.ravage_id, me, t) then
        utils.log_debug(menu, "Ravage")
        return true
    end
    return false
end

local function try_rake(me, t)
    if not (menu.use_rake and menu.use_rake:get_state()) then return false end
    if not rt.rake_id then return false end
    if has_debuff(t, spells.DEBUFF_RAKE) then return false end
    if energy(me) < 35 then return false end
    if not utils.can_cast_hostile(rt.rake_id, me, t) then return false end
    if utils.cast_target(rt.rake_id, me, t) then
        utils.log_debug(menu, "Rake")
        return true
    end
    return false
end

local function try_rip(me, t)
    if not (menu.use_rip and menu.use_rip:get_state()) then return false end
    if not rt.rip_id then return false end
    if combo_points(me) < 5 then return false end
    if has_debuff(t, spells.DEBUFF_RIP) then return false end
    if energy(me) < 30 then return false end
    if not utils.can_cast_hostile(rt.rip_id, me, t) then return false end
    if utils.cast_target(rt.rip_id, me, t) then
        utils.log_debug(menu, "Rip")
        return true
    end
    return false
end

local function try_ferocious_bite(me, t)
    if not (menu.use_ferocious_bite and menu.use_ferocious_bite:get_state()) then return false end
    if not rt.ferocious_bite_id then return false end
    if combo_points(me) < 4 then return false end
    if energy(me) < 35 then return false end
    if not utils.can_cast_hostile(rt.ferocious_bite_id, me, t) then return false end
    if utils.cast_target(rt.ferocious_bite_id, me, t) then
        utils.log_debug(menu, "Ferocious Bite")
        return true
    end
    return false
end

local function try_mangle(me, t)
    if not (menu.use_mangle_cat and menu.use_mangle_cat:get_state()) then return false end
    if not rt.mangle_cat_id then return false end
    if has_debuff(t, spells.DEBUFF_MANGLE) then return false end
    if energy(me) < 40 then return false end
    if not utils.can_cast_hostile(rt.mangle_cat_id, me, t) then return false end
    if utils.cast_target(rt.mangle_cat_id, me, t) then
        utils.log_debug(menu, "Mangle")
        return true
    end
    return false
end

local function try_shred(me, t)
    if not (menu.use_shred and menu.use_shred:get_state()) then return false end
    if not rt.shred_id then return false end

    local cp = combo_points(me)
    local e = energy(me)

    -- At 5 CP: only shred if energy above FB cap (energy dump for next Rip)
    if cp >= 5 then
        local ok_fb_max, fb_max_energy = pcall(function() return menu.fb_max_energy:get() end)
        fb_max_energy = (ok_fb_max and fb_max_energy) or 39
        if e <= fb_max_energy then return false end
        -- Energy is above FB cap, continue to shred for energy dump
    else
        -- CP < 5: Check tick optimization (prefer Mangle in dead-zone)
        if menu.cat_tick_optimization and menu.cat_tick_optimization:get_state() then
            if energy_tick.should_prefer_mangle(e, rt.spell_costs.mangle, rt.spell_costs.shred) then
                if utils.throttle("tick_opt_debug", 2.0) then
                    utils.log_debug(menu, string.format("Tick opt: preferring Mangle over Shred (energy=%d, tick in %.2fs)",
                        e, energy_tick.time_until_next_tick()))
                end
                return false
            end
        end
    end

    if e < 42 then return false end
    if not utils.can_cast_hostile(rt.shred_id, me, t) then return false end
    if utils.cast_target(rt.shred_id, me, t) then
        utils.log_debug(menu, "Shred")
        return true
    end
    return false
end

local function try_tigers_fury(me, target)
    if not (menu.use_tigers_fury and menu.use_tigers_fury:get_state()) then return false end
    if not rt.tigers_fury_id then return false end
    if utils.has_buff(me, spells.BUFF_TIGERS_FURY) then return false end
    if energy(me) > 40 then return false end
    
    -- TTD gating for burst CDs
    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
    if min_ttd > 0 and target then
        ---@type combat_forecast
        local forecast = require("libraries/combat_forecast")
        if not forecast:is_valid_forecast_logic(min_ttd, target, false) then
            return false
        end
    end
    
    if not utils.can_cast_self(rt.tigers_fury_id, me) then return false end
    if utils.cast_self(rt.tigers_fury_id, me) then
        utils.log_debug(menu, "Tiger's Fury")
        return true
    end
    return false
end

local function try_powershift(me)
    -- Use powershift library for decision and execution
    if not rt.cat_form_id then return false end
    
    local current_energy = energy(me)
    
    -- Check if we should powershift using the library
    if powershift:should_powershift(me, current_energy, energy_tick, menu) then
        if powershift:execute(me, me:get_target(), energy_tick, rt.cat_form_id) then
            rt.last_powershift_time = _core_time()
            if utils.throttle("powershift_debug", 2.0) then
                local debug_info = powershift:get_debug_info(me, current_energy, energy_tick)
                utils.log_debug(menu, string.format("Powershift: %d -> %d energy (Wolfshead: %s)",
                    debug_info.current_energy, debug_info.energy_after_shift, tostring(debug_info.has_wolfshead)))
            end
            return true
        end
    end
    return false
end

local function try_faerie_fire(me, t)
    if not (menu.use_faerie_fire and menu.use_faerie_fire:get_state()) then return false end
    if not rt.faerie_fire_id then return false end
    if is_stealthed(me) then return false end  -- Don't break stealth
    if has_debuff(t, spells.DEBUFF_FAERIE_FIRE) then return false end
    if not utils.can_cast_hostile(rt.faerie_fire_id, me, t) then return false end
    if utils.cast_target(rt.faerie_fire_id, me, t) then
        utils.log_debug(menu, "Faerie Fire")
        return true
    end
    return false
end

-- PvP rotation functions
local function try_pvp_entangling_roots(me, t)
    if not utils.is_pvp_setting_enabled(menu, "pvp_entangling_roots") then return false end
    if not rt.entangling_roots_id then return false end
    if not rt.pvp_context or not rt.pvp_context.is_pvp then return false end
    
    -- Only root melee targets that are attacking us
    local distance = utils.get_distance_to_target(me, t)
    if distance > 10 then return false end  -- Only close targets
    
    -- Check if target already has root
    if utils.has_debuff(t, {339, 1062, 5195, 5196, 9852, 9853}) then return false end
    
    -- Don't root if we're in cat form and can fight
    if utils.has_buff(me, spells.BUFF_CAT_FORM) then
        local energy_val = energy(me)
        if energy_val > 40 then return false end  -- Save roots for when we're low on energy
    end
    
    if not utils.can_cast_hostile(rt.entangling_roots_id, me, t) then return false end
    if utils.cast_target(rt.entangling_roots_id, me, t) then
        utils.log_debug(menu, "PvP: Entangling Roots")
        return true
    end
    return false
end

local function try_pvp_hibernate(me, t)
    if not utils.is_pvp_setting_enabled(menu, "pvp_hibernate") then return false end
    if not rt.hibernate_id then return false end
    if not rt.pvp_context or not rt.pvp_context.is_pvp then return false end
    
    -- Hibernate only works on beasts and dragonkin
    -- Check target class for Druid/Shaman (can shift to beast forms)
    local target_class = nil
    if t.get_class then
        local ok, class = pcall(function() return t:get_class() end)
        if ok then target_class = class end
    end
    
    -- Only hibernate druids (can be in cat/bear form) and shamans (ghost wolf)
    if target_class ~= "DRUID" and target_class ~= "SHAMAN" then return false end
    
    -- Check if target already has hibernate
    if utils.has_debuff(t, {2637, 18657, 18658}) then return false end
    
    if not utils.can_cast_hostile(rt.hibernate_id, me, t) then return false end
    if utils.cast_target(rt.hibernate_id, me, t) then
        utils.log_debug(menu, "PvP: Hibernate")
        return true
    end
    return false
end

-- Main rotation
local function do_rotation(me, t)
    if utils.throttle("energy_tick_debug", 3.0) and menu.debug and menu.debug:get_state() then
        local tick_info = energy_tick.get_debug_info()
        core.log(string.format(
            "|cFF00FF00[Tick Debug]|r confident=%s time_until=%.2fs delay=%s wolfshead=%s",
            tostring(tick_info.confident),
            tick_info.time_until_next,
            tostring(tick_info.should_delay),
            tostring(tick_info.wolfshead)
        ))
    end

    -- Debug: Log entry and state
    if utils.throttle("feral_debug", 2.0) then
        local e = energy(me)
        local cp = combo_points(me)
        local rip_ok = utils.can_cast_hostile(rt.rip_id, me, t)
        local rake_ok = utils.can_cast_hostile(rt.rake_id, me, t)
        core.log(string.format("|cFF00FF00[EAX Feral]|r Energy=%d CP=%d RipOK=%s RakeOK=%s", e, cp, tostring(rip_ok), tostring(rake_ok)))
    end

    -- Ensure in cat form
    if not utils.has_buff(me, spells.BUFF_CAT_FORM) then
        if try_cat_form(me) then return end
    end

    -- Stealth opener
    if not me:is_in_combat() then
        if try_prowl(me) then return end
    end
    if is_stealthed(me) then
        if try_ravage(me, t) then return end
    end

    -- Cooldowns
    if try_tigers_fury(me, t) then return end

    -- Powershift if low energy
    if try_powershift(me) then return end

    -- Rotation priority
    if try_faerie_fire(me, t) then return end
    if try_rip(me, t) then return end
    if try_ferocious_bite(me, t) then return end
    if try_rake(me, t) then return end
    if try_mangle(me, t) then return end
    if try_shred(me, t) then return end
end

-- Update loop
local function on_update()
    resolve()
    local me = get_me()

    -- Update energy tick tracker
    local current_energy = energy(me)
    local in_cat_form = utils.has_buff(me, spells.BUFF_CAT_FORM)
    energy_tick.update(current_energy, in_cat_form)

    -- Sample TTD for combat forecast (~1 second throttle)
    if utils.throttle("combat_forecast_sample", 1.0) then
        local t = me:get_target()
        if t and t:is_valid() then
            combat_forecast:sample(t)
        end
    end

    if utils.throttle("feral_mode", MODE_REFRESH) then
        rt.cached_mode = detect_mode()
    end

    -- Debug: Check if menu exists and is enabled
    if not menu then
        if utils.throttle("feral_no_menu", 5.0) then
            core.log("|cFFFF0000[EAX Feral]|r menu is nil!")
        end
        return
    end

    -- Debug: Check unified state directly
    local is_enabled = (menu.enabled and menu.enabled:get_state()) or false

    if not is_enabled then
        dashboard.set_enabled(false)  -- Disable dashboard when rotation is off
        return
    end

    -- Enable dashboard when rotation is active (respect menu setting)
    local show_dashboard = (menu.show_dashboard and menu.show_dashboard.get and menu.show_dashboard:get()) or false
    dashboard.set_enabled(show_dashboard)

    -- OOC Manager: Handle out-of-combat buffs
    -- Order matters: Buffs first (in human form), then shift to Cat Form
    if not me:is_in_combat() then
        ooc_manager.on_update(me, menu, utils, {
            group_buffs = {
                {
                    spell_id = utils.resolve_spell_id(spells.MARK_OF_THE_WILD),
                    buff_ids = spells.BUFF_MARK_OF_THE_WILD,
                    name = "Mark of the Wild",
                    toggle = menu.use_mark_of_the_wild
                },
                {
                    spell_id = rt.thorns_id,
                    buff_ids = spells.BUFF_THORNS,
                    name = "Thorns",
                    toggle = menu.use_thorns
                },
                {
                    spell_id = rt.cat_form_id,
                    buff_ids = spells.BUFF_CAT_FORM,
                    name = "Cat Form",
                    toggle = menu.use_cat_form
                },
            }
        })
        return  -- Exit after OOC buffs to prevent combat rotation from overwriting
    end

    -- Initialize middleware on first run
    if not rt.middleware_initialized then
        middleware_manager.initialize(menu)
        rt.middleware_initialized = true
    end

    -- Build context and execute middleware
    local context = middleware_manager.build_context(me, menu)
    if middleware_manager.execute(icon, context) then
        return
    end

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
        if (menu.debug and menu.debug:get_state()) then
            print(string.format("[CC] Rotation paused: %s", cc_reason or "CC"))
        end
        return  -- Stop rotation while CC'd
    end

    -- Sync dashboard settings (safe pcall for uninitialized menu items)
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

    if not me or me:is_dead() then return end

    -- Track combat start time for burst manager
    if me:is_in_combat() then
        if not rt.combat_start_time then
            rt.combat_start_time = now
        end
    else
        rt.combat_start_time = nil
    end

    local t = me:get_target()
    if not t or not t:is_valid() or t:is_dead() then return end
    if not me:can_attack(t) then return end

    -- Form-aware consumables
    local use_form_consumables = (menu.use_form_consumables and menu.use_form_consumables.get and menu.use_form_consumables:get()) or false
    if use_form_consumables then
        local form_spells = {
            CAT = rt.cat_form_id,
            BEAR = rt.bear_form_id,
            DIRE_BEAR = rt.dire_bear_form_id,
        }
        local used, saved_form, reason = form_consumables.check_and_use(me, menu, form_spells, rt.saved_form)
        if used then
            rt.saved_form = saved_form
            if reason then utils.log_debug(menu, "Form consumable: " .. reason) end
        elseif saved_form == nil and rt.saved_form then
            -- Form was restored, clear saved_form
            rt.saved_form = nil
        end
    end

    -- PvP context detection
    local now = _core_time()
    if not rt.last_pvp_check or (now - rt.last_pvp_check) > 1.0 then
        rt.pvp_context = utils.detect_pvp_context(me, t)
        rt.last_pvp_check = now
    end

    -- PvP rotation
    if utils.is_pvp_active(menu, rt.pvp_context) then
        if try_pvp_entangling_roots(me, t) then return end
        if try_pvp_hibernate(me, t) then return end
    end

    -- Burst & Trinket Automation with Flux V2 API
    local combat_time = now - (rt.combat_start_time or now)
    local is_burst_window = burst_manager.should_auto_burst(me, t, combat_time, menu)
    if is_burst_window then
        -- Tiger's Fury is our main burst CD - already called in do_rotation
        -- but we can force it here if in burst window
        if try_tigers_fury(me, t) then return end
    end
    
    -- V2 Trinket check with TTD gating and force command integration
    local is_burst = burst_manager and burst_manager.is_burst_active and burst_manager:is_burst_active()
    trinket_manager:check_trinkets_v2(me, t, is_burst, force_commands, combat_forecast, menu, {
        offensive_ttd = (menu.trinket_ttd and menu.trinket_ttd:get()) or 10,
        defensive_hp = (menu.defensive_trinket_hp and menu.defensive_trinket_hp:get()) or 35,
    })

    do_rotation(me, t)
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

-- Initialize force commands
force_commands:init()

-- Export toggle settings for external access
local NS = _G.EAXDruidFeral_ and _G.EAXDruidFeral_.NS or {}
_G.EAXDruidFeral_ = _G.EAXDruidFeral_ or {}
_G.EAXDruidFeral_.NS = NS
NS.toggle_menu = menu.toggle_menu

return {}
