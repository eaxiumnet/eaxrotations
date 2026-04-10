-- EAX Druid Balance | Project Sylvanas
-- Priority: Faerie Fire -> DoTs -> Nukes -> AoE

-- Load header first to check if we should load at all
local header = require("header")
if not header.load then
    return
end

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")
local middleware_manager = require("libraries/middleware_manager")
local dashboard = require("libraries/dashboard")
local ooc_manager = require("libraries/ooc_manager")
local mana_manager = require("libraries/mana_manager")
local burst_manager = require("libraries/burst_manager")
local trinket_manager = require("libraries/trinket_manager")
local form_consumables = require("libraries/form_consumables")

-- Flux libraries integration
local energy_tick = require("libraries/energy_tick")
local combat_forecast = require("libraries/combat_forecast")
local force_commands = require("libraries/force_commands")
local swing_manager = require("libraries/swing_manager")

-- Hot-path local caching
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown

-- Runtime state
local rt = {
    last_spell_refresh = 0,
    cached_mode = "solo",
    prev_toggle_state = false,
    _saved_form = nil,
    -- Spell IDs
    starfire_id = nil,
    wrath_id = nil,
    moonfire_id = nil,
    insect_swarm_id = nil,
    faerie_fire_id = nil,
    hurricane_id = nil,
    force_of_nature_id = nil,
    innervate_id = nil,
    barkskin_id = nil,
    moonkin_form_id = nil,
    -- PvP Spell IDs
    entangling_roots_id = nil,
    hibernate_id = nil,
    cyclone_id = nil,
    -- Cast tracking
    last_moonfire_cast = 0,
    last_insect_swarm_cast = 0,
    last_faerie_fire_cast = 0,
    -- PvP state
    pvp_context = nil,
    last_pvp_check = 0,
}

local SPELL_REFRESH = 1.0
local MODE_REFRESH = 4.5
local DOT_REFRESH_THRESHOLD = 3.0

-- Initialize Flux libraries
force_commands:init()

-- Form spells for consumable usage
local FORM_SPELLS = {
    CAT = 768,
    BEAR = 5487,
    MOONKIN = 24858,
    TREE = 33891,
}

-- Helpers
local function get_me() return _get_local_player() end

local function resolve()
    local now = _core_time()
    if (now - rt.last_spell_refresh) < SPELL_REFRESH then return end
    rt.last_spell_refresh = now
    rt.starfire_id = utils.resolve_spell_id(spells.STARFIRE)
    rt.wrath_id = utils.resolve_spell_id(spells.WRATH)
    rt.moonfire_id = utils.resolve_spell_id(spells.MOONFIRE)
    rt.insect_swarm_id = utils.resolve_spell_id(spells.INSECT_SWARM)
    rt.faerie_fire_id = utils.resolve_spell_id(spells.FAERIE_FIRE)
    rt.hurricane_id = utils.resolve_spell_id(spells.HURRICANE)
    rt.force_of_nature_id = utils.resolve_spell_id(spells.FORCE_OF_NATURE)
    rt.innervate_id = utils.resolve_spell_id(spells.INNERVATE)
    rt.barkskin_id = utils.resolve_spell_id(spells.BARKSKIN)
    rt.moonkin_form_id = utils.resolve_spell_id(spells.MOONKIN_FORM)
    -- PvP spells
    rt.entangling_roots_id = utils.resolve_spell_id(spells.ENTANGLING_ROOTS)
    rt.hibernate_id = utils.resolve_spell_id(spells.HIBERNATE)
    rt.cyclone_id = utils.resolve_spell_id(spells.CYCLONE)
    -- OOC buffs
    rt.mark_of_the_wild_id = utils.resolve_spell_id(spells.MARK_OF_THE_WILD)
    rt.thorns_id = utils.resolve_spell_id(spells.THORNS)
end

local function is_moving()
    local me = get_me()
    local ok_moving, is_moving = pcall(function() return me:is_moving() end)
    return ok_moving and is_moving
end

local function mana_pct(me)
    return utils.mana_pct(me)
end

local function has_debuff(target, tbl)
    return utils.has_debuff(target, tbl)
end

local function debuff_rem(target, tbl)
    if not target or not target:is_valid() then return 0 end
    local d = target:get_debuff_data(tbl)
    if d and d.is_active and (d.remaining or 0) > 0 then return d.remaining end
    local ok_a, d = pcall(function() return target:get_aura_data(tbl) end)
    if not ok_a then d = nil end
    if d and d.is_active and (d.remaining or 0) > 0 then return d.remaining end
    return 0
end

local function detect_mode()
    local n = 0
    local ok_objects, all_objects = pcall(function() return core.object_manager.get_all_objects() end)
    if not ok_objects then all_objects = {} end
    for _, o in ipairs(all_objects) do
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
local function try_faerie_fire(me, t)
    if not (menu.use_faerie_fire and menu.use_faerie_fire:get_state()) or false then return false end
    if not rt.faerie_fire_id then return false end
    if has_debuff(t, spells.DEBUFF_FAERIE_FIRE) then return false end
    if not utils.can_cast_hostile(rt.faerie_fire_id, me, t) then return false end
    if utils.cast_target(rt.faerie_fire_id, me, t) then
        utils.log_debug(menu, "Faerie Fire")
        return true
    end
    return false
end

local function try_moonfire(me, t)
    if not (menu.use_moonfire and menu.use_moonfire:get_state()) or false then return false end
    if not rt.moonfire_id then return false end
    local rem = debuff_rem(t, spells.DEBUFF_MOONFIRE)
    if rem > DOT_REFRESH_THRESHOLD then return false end
    
    -- TTD gating for DoTs
    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
    if min_ttd > 0 and t then
        ---@type combat_forecast
        local forecast = require("libraries/combat_forecast")
        if not forecast:is_valid_forecast_logic(min_ttd, t, false) then
            return false
        end
    end
    
    if not utils.can_cast_hostile(rt.moonfire_id, me, t) then return false end
    if utils.cast_target(rt.moonfire_id, me, t) then
        rt.last_moonfire_cast = _core_time()
        utils.log_debug(menu, "Moonfire")
        return true
    end
    return false
end

local function try_insect_swarm(me, t)
    if not (menu.use_insect_swarm and menu.use_insect_swarm:get_state()) or false then return false end
    if not rt.insect_swarm_id then return false end
    local rem = debuff_rem(t, spells.DEBUFF_INSECT_SWARM)
    if rem > DOT_REFRESH_THRESHOLD then return false end
    
    -- TTD gating for DoTs
    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
    if min_ttd > 0 and t then
        ---@type combat_forecast
        local forecast = require("libraries/combat_forecast")
        if not forecast:is_valid_forecast_logic(min_ttd, t, false) then
            return false
        end
    end
    
    if not utils.can_cast_hostile(rt.insect_swarm_id, me, t) then return false end
    if utils.cast_target(rt.insect_swarm_id, me, t) then
        rt.last_insect_swarm_cast = _core_time()
        utils.log_debug(menu, "Insect Swarm")
        return true
    end
    return false
end

local function try_starfire(me, t)
    if not (menu.use_starfire and menu.use_starfire:get_state()) or false then return false end
    if not rt.starfire_id then return false end
    if is_moving() then return false end
    if not utils.can_cast_hostile(rt.starfire_id, me, t) then return false end
    if utils.cast_target(rt.starfire_id, me, t) then
        utils.log_debug(menu, "Starfire")
        return true
    end
    return false
end

local function try_wrath(me, t)
    if not (menu.use_wrath and menu.use_wrath:get_state()) or false then return false end
    if not rt.wrath_id then return false end
    if not utils.can_cast_hostile(rt.wrath_id, me, t) then return false end
    if utils.cast_target(rt.wrath_id, me, t) then
        utils.log_debug(menu, "Wrath")
        return true
    end
    return false
end

-- Clearcasting exploitation functions
local function try_starfire_clearcasting(me, t)
    -- ONLY cast if Clearcasting is active - highest priority free spell
    if not utils.has_clearcasting_buff(me) then return false end
    if not (menu.use_starfire and menu.use_starfire:get_state()) or false then return false end
    if not rt.starfire_id then return false end
    if is_moving() then return false end
    if not utils.can_cast_hostile(rt.starfire_id, me, t) then return false end
    if utils.cast_target(rt.starfire_id, me, t) then
        utils.log_debug(menu, "Starfire (Clearcasting - FREE!)")
        return true
    end
    return false
end

local function try_wrath_clearcasting(me, t)
    -- Fallback Clearcasting spell when Starfire can't be cast (moving, out of range)
    if not utils.has_clearcasting_buff(me) then return false end
    if not rt.wrath_id then return false end
    if not utils.can_cast_hostile(rt.wrath_id, me, t) then return false end
    if utils.cast_target(rt.wrath_id, me, t) then
        utils.log_debug(menu, "Wrath (Clearcasting - FREE!)")
        return true
    end
    return false
end

local function try_hurricane(me, t)
    if not (menu.use_hurricane and menu.use_hurricane:get_state()) or false then return false end
    if not rt.hurricane_id then return false end
    if is_moving() then return false end
    local min_targets = (menu.hurricane_min_targets and menu.hurricane_min_targets:get()) or 3
    local count = 1
    local tp = t:get_position()
    if tp then
        local ok_objects, all_objects = pcall(function() return core.object_manager.get_all_objects() end)
    if not ok_objects then all_objects = {} end
    for _, o in ipairs(all_objects) do
            if o and o:is_valid() and o:is_unit() and not o:is_dead() and me:can_attack(o) and o ~= t then
                local op = o:get_position()
                if op then
                    local dx, dy, dz = op.x - tp.x, op.y - tp.y, op.z - tp.z
                    if (dx * dx + dy * dy + dz * dz) <= 100 then
                        count = count + 1
                    end
                end
            end
        end
    end
    if count < min_targets then return false end
    if not utils.can_cast_hostile(rt.hurricane_id, me, t) then return false end
    if utils.cast_target(rt.hurricane_id, me, t) then
        utils.log_debug(menu, "Hurricane (" .. count .. " targets)")
        return true
    end
    return false
end

local function try_force_of_nature(me, t)
    if not (menu.use_force_of_nature and menu.use_force_of_nature:get_state()) or false then return false end
    if not rt.force_of_nature_id then return false end
    
    -- TTD gating for treants
    local min_ttd = (menu.force_of_nature_min_ttd and menu.force_of_nature_min_ttd:get()) or 10
    if min_ttd > 0 and t then
        ---@type combat_forecast
        local forecast = require("libraries/combat_forecast")
        if not forecast:is_valid_forecast_logic(min_ttd, t, false) then
            return false
        end
    end
    
    if not utils.can_cast_hostile(rt.force_of_nature_id, me, t) then return false end
    if utils.cast_target(rt.force_of_nature_id, me, t) then
        utils.log_debug(menu, "Force of Nature")
        return true
    end
    return false
end

local function try_innervate(me)
    if not (menu.use_innervate and menu.use_innervate:get_state()) or false then return false end
    if not rt.innervate_id then return false end
    local threshold = (menu.innervate_mana_pct and menu.innervate_mana_pct:get()) or 20 / 100
    if mana_pct(me) > threshold then return false end
    if not utils.can_cast_self(rt.innervate_id, me) then return false end
    if utils.cast_self(rt.innervate_id, me) then
        utils.log_debug(menu, "Innervate")
        return true
    end
    return false
end

local function try_barkskin(me)
    if not (menu.use_barkskin and menu.use_barkskin:get_state()) or false then return false end
    if not rt.barkskin_id then return false end
    local threshold = (menu.barkskin_hp_pct and menu.barkskin_hp_pct:get()) or 30 / 100
    if utils.get_health_pct(me) > threshold then return false end
    if not utils.can_cast_self(rt.barkskin_id, me) then return false end
    if utils.cast_self(rt.barkskin_id, me) then
        utils.log_debug(menu, "Barkskin")
        return true
    end
    return false
end

local function try_moonkin_form(me)
    if not rt.moonkin_form_id then return false end
    if utils.has_buff(me, spells.BUFF_MOONKIN_FORM) then return false end
    if not utils.can_cast_self(rt.moonkin_form_id, me) then return false end
    if utils.cast_self(rt.moonkin_form_id, me) then
        utils.log_debug(menu, "Moonkin Form")
        return true
    end
    return false
end

-- PvP rotation functions
local function try_pvp_entangling_roots(me, t)
    if not rt.pvp_context or not rt.pvp_context.target_is_player then return false end
    if not (menu.pvp_entangling_roots and menu.pvp_entangling_roots:get()) then return false end
    if not rt.entangling_roots_id then return false end
    -- Check if target doesn't have roots already
    if utils.has_debuff(t, spells.DEBUFF_ENTANGLING_ROOTS) then return false end
    if not utils.can_cast_hostile(rt.entangling_roots_id, me, t) then return false end
    if utils.cast_target(rt.entangling_roots_id, me, t) then
        utils.log_debug(menu, "PvP: Entangling Roots")
        return true
    end
    return false
end

local function try_pvp_hibernate(me, t)
    if not rt.pvp_context or not rt.pvp_context.target_is_player then return false end
    if not (menu.pvp_hibernate and menu.pvp_hibernate:get()) then return false end
    if not rt.hibernate_id then return false end
    -- Check if target is beast or dragonkin
    local creature_type = nil
    if t.get_creature_type then
        local ok, ct = pcall(function() return t:get_creature_type() end)
        if ok then creature_type = ct end
    end
    if creature_type ~= "Beast" and creature_type ~= "Dragonkin" then return false end
    -- Check if target doesn't have hibernate already
    if utils.has_debuff(t, spells.DEBUFF_HIBERNATE) then return false end
    if not utils.can_cast_hostile(rt.hibernate_id, me, t) then return false end
    if utils.cast_target(rt.hibernate_id, me, t) then
        utils.log_debug(menu, "PvP: Hibernate")
        return true
    end
    return false
end

local function try_pvp_cyclone(me, t)
    if not rt.pvp_context or not rt.pvp_context.target_is_player then return false end
    if not (menu.pvp_cyclone and menu.pvp_cyclone:get()) then return false end
    if not rt.cyclone_id then return false end
    -- Check if target doesn't have cyclone already
    if utils.has_debuff(t, spells.DEBUFF_CYCLONE) then return false end
    if not utils.can_cast_hostile(rt.cyclone_id, me, t) then return false end
    if utils.cast_target(rt.cyclone_id, me, t) then
        utils.log_debug(menu, "PvP: Cyclone")
        return true
    end
    return false
end

-- Main rotation
local function do_rotation(me, t)
    -- Mana recovery check
    if (menu.use_mana_manager and menu.use_mana_manager:get()) then
        local used_mana, mana_type = mana_manager.check_and_recover(me, menu, mana_manager.CLASS_RECOVERY.DRUID)
        if used_mana then return end
    end

    -- Defensive
    if try_barkskin(me) then return end

    -- Cooldowns
    if try_innervate(me) then return end
    if try_force_of_nature(me, t) then return end

    -- Form check
    if not utils.has_buff(me, spells.BUFF_MOONKIN_FORM) then
        if try_moonkin_form(me) then return end
    end

    -- Clearcasting exploitation - HIGHEST PRIORITY (free spells before DoTs)
    if try_starfire_clearcasting(me, t) then return end
    if try_wrath_clearcasting(me, t) then return end

    -- Rotation priority
    if try_faerie_fire(me, t) then return end
    if try_moonfire(me, t) then return end
    if try_insect_swarm(me, t) then return end
    if try_hurricane(me, t) then return end

    -- Mana tier check with Nature's Grace Wrath priority
    local mp = mana_pct(me)
    local tier2 = ((menu.bal_tier2_mana and menu.bal_tier2_mana:get()) or 30) / 100
    local ng_wrath_enabled = (menu.bal_ng_wrath and menu.bal_ng_wrath.get and menu.bal_ng_wrath:get()) or false
    local has_ng = utils.has_natures_grace_buff(me)

    if ng_wrath_enabled and has_ng then
        -- Prioritize Wrath when Nature's Grace is active
        if try_wrath(me, t) then return end
        if try_starfire(me, t) then return end
    elseif mp < tier2 then
        -- Low mana: use efficient Wrath
        if try_wrath(me, t) then return end
    else
        -- Normal rotation: Starfire priority
        if try_starfire(me, t) then return end
        if try_wrath(me, t) then return end
    end
end

-- Update loop
local function on_update()
    resolve()
    local me = get_me()
    if not me or not me:is_valid() then return end

    -- Flux library updates
    local ok_power, power_val = pcall(function() return me:get_power(3) end)
    energy_tick:update(ok_power and power_val or 0)
    swing_manager:update_swing(me)
    
    if utils.throttle("balancemode", MODE_REFRESH) then
        rt.cached_mode = detect_mode()
    end
    if not (menu.enabled and menu.enabled:get_state()) then return end

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

    local ok_dead, is_dead = pcall(function() return me:is_dead() end)
    if not me or (ok_dead and is_dead) then return end

    -- Form-aware consumable usage (before rotation)
    local use_hs = (menu.use_healthstone and menu.use_healthstone:get()) or false
    local use_hp = (menu.use_healing_potion and menu.use_healing_potion:get()) or false
    if use_hs or use_hp then
        local used, form_to_save, reason = form_consumables.check_and_use(me, menu, FORM_SPELLS, rt._saved_form)
        if used then
            rt._saved_form = form_to_save
            return
        elseif form_to_save then
            rt._saved_form = form_to_save
            return
        end
    end

    -- OOC rotation
    if not me:is_in_combat() then
        ooc_manager.on_update(me, menu, utils, {
            group_buffs = {
                {
                    spell_id = rt.mark_of_the_wild_id,
                    buff_ids = spells.BUFF_MARK_OF_THE_WILD,
                    name = "Mark of the Wild",
                    toggle = menu.use_mark_of_the_wild
                },
                {
                    spell_id = rt.moonkin_form_id,
                    buff_ids = spells.BUFF_MOONKIN_FORM,
                    name = "Moonkin Form",
                    toggle = menu.use_moonkin_form
                },
                {
                    spell_id = rt.thorns_id,
                    buff_ids = spells.BUFF_THORNS,
                    name = "Thorns",
                    toggle = menu.use_thorns
                },
            }
        })
        return
    end

    local ok_t, t = pcall(function() return me:get_target() end)
    if not ok_t then t = nil end
    if not t or not t:is_valid() or t:is_dead() then return end
    local ok_attack, can_attack = pcall(function() return me:can_attack(t) end)
    if not (ok_attack and can_attack) then return end

    -- Flux combat forecast sampling
    if combat_forecast and t and t:is_valid() then
        combat_forecast:sample(t)
    end

    -- Energy tick delay check before expensive abilities
    if (menu.use_energy_tick and menu.use_energy_tick:get()) then
        if energy_tick:should_delay_action() then return end
    end

    -- Swing delay check
    if (menu.use_swing_delay and menu.use_swing_delay:get()) then
        if swing_manager:is_swing_landing_soon(0.15) then return end
    end

    -- PvP context detection
    local now = _core_time()
    if not rt.last_pvp_check or (now - rt.last_pvp_check) > 1.0 then
        rt.pvp_context = utils.detect_pvp_context(me, t)
        rt.last_pvp_check = now
    end

    -- Burst & Trinket Automation
    local ctx = middleware_manager.build_context(me, menu)
    local combat_time = _core_time() - (ctx.combat_start_time or _core_time())
    local is_burst_window = burst_manager.should_auto_burst(me, t, combat_time, menu)
    if is_burst_window then
        -- Balance burst: Force of Nature (treants)
        if try_force_of_nature(me, t) then return end
    end
    trinket_manager.check_trinkets_v2(me, t, is_burst_window, force_commands, combat_forecast, menu)

    -- PvP rotation
    if utils.is_pvp_active(menu, rt.pvp_context) then
        if try_pvp_entangling_roots(me, t) then return end
        if try_pvp_hibernate(me, t) then return end
        if try_pvp_cyclone(me, t) then return end
    end

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

-- Export toggle settings for external access (only if header loaded successfully)
if header.load then
    local NS = _G.EAXDruidBalance and _G.EAXDruidBalance.NS or {}
    _G.EAXDruidBalance = _G.EAXDruidBalance or {}
    _G.EAXDruidBalance.NS = NS
    NS.toggle_menu = menu.toggle_menu
end

return {}






