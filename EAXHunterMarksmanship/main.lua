-- main.lua
-- EAX Hunter Marksmanship | Full TBC Auto Rotation
-- Priority: Aimed Shot > Multi-Shot > Steady Shot > Arcane Shot

local menu = require("menu")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")

---@type interrupt_manager
local interrupt_manager = require("common/eax_shared/interrupt_manager")
---@type ttd_tracker
local ttd_tracker = require("common/eax_shared/ttd_tracker")
---@type racial_manager
local racial_manager = require("common/eax_shared/racial_manager")
---@type defensive_manager
local defensive_manager = require("common/eax_shared/defensive_manager")

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local runtime = {
    auto_shot_id = nil,
    aimed_shot_id = nil,
    arcane_shot_id = nil,
    steady_shot_id = nil,
    multi_shot_id = nil,
    kill_command_id = nil,
    hunters_mark_id = nil,
    serpent_sting_id = nil,
    aspect_hawk_id = nil,
    aspect_monkey_id = nil,
    raptor_strike_id = nil,
    last_cast_time = 0,
    cached_mode = "solo",
    prev_toggle_state = false,
    last_spell_refresh = 0,
}

local GCD_INTERVAL = 0.05
local MODE_REFRESH_INTERVAL = 4.5
local SPELL_REFRESH_INTERVAL = 1.0

local function resolve_spells()
    local now = core.time()
    if (now - runtime.last_spell_refresh) < SPELL_REFRESH_INTERVAL then
        return
    end
    runtime.last_spell_refresh = now

    runtime.auto_shot_id = utils.resolve_spell_id(spells.AUTO_SHOT)
    runtime.aimed_shot_id = utils.resolve_spell_id(spells.AIMED_SHOT)
    runtime.arcane_shot_id = utils.resolve_spell_id(spells.ARCANE_SHOT)
    runtime.steady_shot_id = utils.resolve_spell_id(spells.STEADY_SHOT)
    runtime.multi_shot_id = utils.resolve_spell_id(spells.MULTI_SHOT)
    runtime.kill_command_id = utils.resolve_spell_id(spells.KILL_COMMAND)
    runtime.hunters_mark_id = utils.resolve_spell_id(spells.HUNTERS_MARK)
    runtime.serpent_sting_id = utils.resolve_spell_id(spells.SERPENT_STING)
    runtime.aspect_hawk_id = utils.resolve_spell_id(spells.ASPECT_OF_THE_HAWK)
    runtime.aspect_monkey_id = utils.resolve_spell_id(spells.ASPECT_OF_THE_MONKEY)
    runtime.raptor_strike_id = utils.resolve_spell_id(spells.RAPTOR_STRIKE)
end

local function log_resolved_spells()
    core.log("[EAX Hunter Marksmanship] Resolved: AimedShot=" .. tostring(runtime.aimed_shot_id)
        .. " MultiShot=" .. tostring(runtime.multi_shot_id)
        .. " SteadyShot=" .. tostring(runtime.steady_shot_id)
        .. " ArcaneShot=" .. tostring(runtime.arcane_shot_id)
        .. " HuntersMark=" .. tostring(runtime.hunters_mark_id))
end

resolve_spells()
log_resolved_spells()

local function detect_mode()
    local objects = core.object_manager.get_visible_objects()
    local party_count = 0
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() 
           and obj:is_party_member() then
            party_count = party_count + 1
        end
    end
    if party_count == 0 then
        return "solo"
    elseif party_count <= 4 then
        return "dungeon"
    end
    return "raid"
end

local function get_active_mode()
    local selection = menu.mode:get()
    if selection == 1 then
        return detect_mode()
    elseif selection == 2 then
        return "solo"
    elseif selection == 3 then
        return "dungeon"
    elseif selection == 4 then
        return "raid"
    end
    return detect_mode()
end

local function has_buff(spell_id)
    if not spell_id then return false end
    local me = core.object_manager.get_local_player()
    if not me then return false end
    local buff = me:get_buff_data(spell_id)
    return buff and buff.is_active
end

local function has_debuff(spell_id, target)
    if not spell_id or not target then return false end
    local debuff = target:get_debuff_data(spell_id)
    return debuff and debuff.is_active
end

local function can_cast(spell_id, target)
    if not spell_id or not target then return false end
    local me = core.object_manager.get_local_player()
    if not me then return false end
    return me:can_cast_spell(spell_id, false, target:get_position())
end

local function cast_spell(spell_id, target_or_pos)
    if not spell_id then return false end
    local me = core.object_manager.get_local_player()
    if not me then return false end
    local target = me:get_target()
    if target_or_pos then
        if type(target_or_pos) == "userdata" then
            return me:cast_spell(spell_id, target_or_pos)
        elseif target_or_pos == "target" and target then
            return me:cast_spell(spell_id, target)
        elseif target_or_pos == "player" then
            return me:cast_spell(spell_id, me)
        end
    end
    return me:cast_spell(spell_id)
end

local function get_distance(target)
    if not target then return 999 end
    local me = core.object_manager.get_local_player()
    if not me then return 999 end
    local my_pos = me:get_position()
    local target_pos = target:get_position()
    if not my_pos or not target_pos then return 999 end
    local dx = my_pos.x - target_pos.x
    local dy = my_pos.y - target_pos.y
    local dz = my_pos.z - target_pos.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function face_target(target)
    if not target then return end
    local me = core.object_manager.get_local_player()
    if not me then return end
    me:face_target(target)
end

local function is_busy()
    local me = core.object_manager.get_local_player()
    if not me then return true end
    return me:is_channeling() or me:is_casting()
end

local function start_auto_attack()
    local me = core.object_manager.get_local_player()
    if not me then return end
    local target = me:get_target()
    if not target or not target:is_valid() then return end
    local dist = get_distance(target)
    if dist <= 5 then
        me:start_auto_attack(target)
    end
end

local function try_hunters_mark(target)
    if not menu.use_hunters_mark:get_state() then return false end
    if not runtime.hunters_mark_id then return false end
    if not can_cast(runtime.hunters_mark_id, target) then return false end
    if has_debuff(runtime.hunters_mark_id, target) then return false end
    if cast_spell(runtime.hunters_mark_id, target) then
        utils.log_debug(menu, "Hunters Mark cast")
        return true
    end
    return false
end

local function try_serpent_sting(target)
    if not menu.use_serpent_sting:get_state() then return false end
    if not runtime.serpent_sting_id then return false end
    if not can_cast(runtime.serpent_sting_id, target) then return false end
    if has_debuff(runtime.serpent_sting_id, target) then return false end
    if cast_spell(runtime.serpent_sting_id, target) then
        utils.log_debug(menu, "Serpent Sting cast")
        return true
    end
    return false
end

local function try_arcane_shot(target)
    if not menu.use_arcane_shot:get_state() then return false end
    if not runtime.arcane_shot_id then return false end
    local dist = get_distance(target)
    if dist > 30 then return false end
    if not can_cast(runtime.arcane_shot_id, target) then return false end
    if cast_spell(runtime.arcane_shot_id, target) then
        utils.log_debug(menu, "Arcane Shot cast")
        return true
    end
    return false
end

local function try_aimed_shot(target)
    if not menu.use_aimed_shot:get_state() then return false end
    if not runtime.aimed_shot_id then return false end
    local dist = get_distance(target)
    if dist > 40 then return false end
    if is_busy() then return false end
    if not can_cast(runtime.aimed_shot_id, target) then return false end
    if cast_spell(runtime.aimed_shot_id, target) then
        utils.log_debug(menu, "Aimed Shot cast")
        return true
    end
    return false
end

local function try_steady_shot(target)
    if not menu.use_steady_shot:get_state() then return false end
    if not runtime.steady_shot_id then return false end
    local dist = get_distance(target)
    if dist > 40 then return false end
    if not can_cast(runtime.steady_shot_id, target) then return false end
    if cast_spell(runtime.steady_shot_id, target) then
        utils.log_debug(menu, "Steady Shot cast")
        return true
    end
    return false
end

local function try_multi_shot(target)
    if not menu.use_multi_shot:get_state() then return false end
    if not runtime.multi_shot_id then return false end
    local mode = get_active_mode()
    if mode == "solo" then return false end
    local dist = get_distance(target)
    if dist > 30 then return false end
    if not can_cast(runtime.multi_shot_id, target) then return false end
    if cast_spell(runtime.multi_shot_id, target) then
        utils.log_debug(menu, "Multi-Shot cast")
        return true
    end
    return false
end

local function try_aspect()
    local me = core.object_manager.get_local_player()
    if not me then return false end
    
    local desired_aspect = runtime.aspect_hawk_id
    
    if not desired_aspect then return false end
    if has_buff(desired_aspect) then return false end
    if is_busy() then return false end
    
    if cast_spell(desired_aspect, "player") then
        utils.log_debug(menu, "Aspect cast")
        return true
    end
    return false
end

local function try_raptor_strike(target)
    if not menu.use_raptor_strike:get_state() then return false end
    if not runtime.raptor_strike_id then return false end
    local dist = get_distance(target)
    if dist > 5 then return false end
    if not can_cast(runtime.raptor_strike_id, target) then return false end
    if cast_spell(runtime.raptor_strike_id, target) then
        utils.log_debug(menu, "Raptor Strike cast")
        return true
    end
    return false
end


-- ─── Kiting / Threat Management (v1.2) ───────────────────────────────────

local function try_disengage(me, target)
    if not runtime.disengage_id then return false end
    local dist = get_distance(target)
    if dist > 8 then return false end
    if not can_cast(runtime.disengage_id, "player") then return false end
    if cast_spell(runtime.disengage_id, "player") then
        utils.log_debug(menu, "Disengage")
        return true
    end
    return false
end

local function try_feign_death(me)
    if not runtime.feign_death_id then return false end
    local hp = me:get_health_percentage() / 100
    if hp > 0.30 then return false end
    if not can_cast(runtime.feign_death_id, "player") then return false end
    if cast_spell(runtime.feign_death_id, "player") then
        utils.log_debug(menu, "Feign Death")
        return true
    end
    return false
end


local function do_rotation(me, target)
    if is_busy() then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end

    if try_feign_death(me) then return true end
    if try_disengage(me, target) then return true end
    
    -- Interrupt
    -- Interrupt
    if target and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "hunter", utils) then
            return true
        end
    end

    -- Racial CDs
    racial_manager.try_offensive(me)
    racial_manager.try_utility(me, target)

    -- Defensive abilities
    ttd_tracker.update(target)

    if defensive_manager.try_defensive(me, "hunter", utils) then
        return true
    end
    
    local dist = get_distance(target)
    
    if dist <= 40 then
        face_target(target)
    end
    
    if try_aspect() then return true end
    
    if menu.use_hunters_mark:get_state() then
        if try_hunters_mark(target) then return true end
    end
    
    if dist <= 40 then
        if try_aimed_shot(target) then return true end
    end
    
    if try_multi_shot(target) then return true end
    
    if try_serpent_sting(target) then return true end
    
    if try_steady_shot(target) then return true end
    
    if dist <= 30 then
        if try_arcane_shot(target) then return true end
    end
    
    if dist <= 5 then
        if try_raptor_strike(target) then return true end
        start_auto_attack()
    end
    
    return false
end

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current then
        if not runtime.prev_toggle_state then
            local enabled = menu.enabled:get_state()
            menu.enabled:set(not enabled)
            utils.log_debug(menu, "Toggled -> " .. tostring(not enabled))
        end
        runtime.prev_toggle_state = true
    else
        runtime.prev_toggle_state = false
    end
end

local function on_update()
    resolve_spells()
    
    if utils.throttle("mode_refresh", MODE_REFRESH_INTERVAL) then
        runtime.cached_mode = detect_mode()
    end
    
    handle_toggle()
    
    if not menu.enabled:get_state() then
        return
    end
    
    local me = core.object_manager.get_local_player()
    if not me or me:is_dead() then
        return
    end
    
    local target = me:get_target()
    
    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and focus_target:is_valid() then
        target = focus_target
    end
    
    -- Self-emergency
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_mend_pet then try_mend_pet(me) end
    end
    
    if not target or not target:is_valid() or target:is_dead() then
        return
    end
    
    do_rotation(me, target)
end

local function on_control_panel()
    local elements = {}
    local toggle_key_code = menu.toggle_key:get_key_code()
    local display_name = "[EAX Hunter Marksmanship] Enable"
    if toggle_key_code ~= 7 then
        display_name = "[EAX Hunter Marksmanship] Enable (" .. key_helper:get_key_name(toggle_key_code) .. ")"
    end
    control_panel_utility:insert_toggle_(elements, display_name, menu.toggle_key)

    local dev_id = "eax_hunter_ms_"
    local function add_checkbox(name, menu_item)
        if not menu_item then return end
        local current = menu_item:get_state()
        local new_state = control_panel_utility:insert_key_checkbox_(
            elements, name, current, 0, false, dev_id .. name
        )
        if new_state ~= current then
            menu_item:set(new_state)
        end
    end

    add_checkbox("Enabled", menu.enabled)
    add_checkbox("Use Aimed Shot", menu.use_aimed_shot)
    add_checkbox("Use Multi-Shot", menu.use_multi_shot)
    add_checkbox("Steady Shot Weave", menu.use_steady_weave)

    return elements
end

core.register_on_update_callback(on_update)
core.register_on_render_menu_callback(menu.render)
core.register_on_render_control_panel_callback(on_control_panel)

return {}
