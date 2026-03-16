-- main.lua
-- EAX Hunter Survival | Full TBC Auto Rotation
-- Priority: Serpent Sting > Explosive Shot > Raptor Strike > Melee

local menu = require("menu")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local runtime = {
    auto_shot_id = nil,
    arcane_shot_id = nil,
    steady_shot_id = nil,
    multi_shot_id = nil,
    serpent_sting_id = nil,
    explosive_shot_id = nil,
    hunters_mark_id = nil,
    aspect_hawk_id = nil,
    aspect_monkey_id = nil,
    raptor_strike_id = nil,
    wing_clip_id = nil,
    mend_pet_id = nil,
    counter_shot_id = nil,
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
    runtime.arcane_shot_id = utils.resolve_spell_id(spells.ARCANE_SHOT)
    runtime.steady_shot_id = utils.resolve_spell_id(spells.STEADY_SHOT)
    runtime.multi_shot_id = utils.resolve_spell_id(spells.MULTI_SHOT)
    runtime.serpent_sting_id = utils.resolve_spell_id(spells.SERPENT_STING)
    runtime.explosive_shot_id = utils.resolve_spell_id(spells.EXPLOSIVE_SHOT)
    runtime.hunters_mark_id = utils.resolve_spell_id(spells.HUNTERS_MARK)
    runtime.aspect_hawk_id = utils.resolve_spell_id(spells.ASPECT_OF_THE_HAWK)
    runtime.aspect_monkey_id = utils.resolve_spell_id(spells.ASPECT_OF_THE_MONKEY)
    runtime.raptor_strike_id = utils.resolve_spell_id(spells.RAPTOR_STRIKE)
    runtime.wing_clip_id = utils.resolve_spell_id(spells.WING_CLIP)
    runtime.mend_pet_id = utils.resolve_spell_id(spells.MEND_PET)
    runtime.counter_shot_id = utils.resolve_spell_id(spells.COUNTER_SHOT)
end

local function log_resolved_spells()
    core.log("[EAX Hunter Survival] Resolved: SerpentSting=" .. tostring(runtime.serpent_sting_id)
        .. " ExplosiveShot=" .. tostring(runtime.explosive_shot_id)
        .. " RaptorStrike=" .. tostring(runtime.raptor_strike_id)
        .. " WingClip=" .. tostring(runtime.wing_clip_id))
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

local function try_explosive_shot(target)
    if not menu.use_explosive_shot:get_state() then return false end
    if not runtime.explosive_shot_id then return false end
    local dist = get_distance(target)
    if dist > 20 then return false end
    if not can_cast(runtime.explosive_shot_id, target) then return false end
    if cast_spell(runtime.explosive_shot_id, target) then
        utils.log_debug(menu, "Explosive Shot cast")
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

local function try_wing_clip(target)
    if not menu.use_wing_clip:get_state() then return false end
    if not runtime.wing_clip_id then return false end
    local dist = get_distance(target)
    if dist > 5 then return false end
    if not can_cast(runtime.wing_clip_id, target) then return false end
    if cast_spell(runtime.wing_clip_id, target) then
        utils.log_debug(menu, "Wing Clip cast")
        return true
    end
    return false
end

local function try_mend_pet(me)
    if not menu.use_mend_pet:get_state() then return false end
    if not runtime.mend_pet_id then return false end
    local pet = core.pet.get_pet()
    if not pet or pet:is_dead() then return false end
    local pet_hp = pet:get_health_percentage()
    if pet_hp > menu.mend_pet_hp_pct:get() then return false end
    if me:is_moving() then return false end
    if not utils.can_cast_self(runtime.mend_pet_id, me) then return false end
    if utils.cast_self(runtime.mend_pet_id, me) then
        utils.log_debug(menu, "Mend Pet")
        return true
    end
    return false
end

local function do_rotation(me, target)
    if is_busy() then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    
    -- Interrupt
    if target:is_casting_spell() and target:is_active_spell_interruptable() then
        if runtime.counter_shot_id and can_cast(runtime.counter_shot_id, target) then
            if cast_spell(runtime.counter_shot_id, target) then
                utils.log_debug(menu, "Counter Shot interrupt")
                return true
            end
        end
    end
    
    local dist = get_distance(target)
    
    if dist <= 40 then
        face_target(target)
    end
    
    if try_aspect() then return true end
    
    if menu.use_hunters_mark:get_state() then
        if try_hunters_mark(target) then return true end
    end
    
    if dist <= 20 then
        if try_explosive_shot(target) then return true end
    end
    
    if try_serpent_sting(target) then return true end
    
    if dist <= 5 then
        if try_raptor_strike(target) then return true end
        if try_wing_clip(target) then return true end
        start_auto_attack()
    else
        if try_multi_shot(target) then return true end
        if try_arcane_shot(target) then return true end
        if try_steady_shot(target) then return true end
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
        try_mend_pet(me)
    end
    
    if not target or not target:is_valid() or target:is_dead() then
        return
    end
    
    do_rotation(me, target)
end

local function on_control_panel()
    local elements = {}
    local toggle_key_code = menu.toggle_key:get_key_code()
    local display_name = "[EAX Hunter Survival] Enable"
    if toggle_key_code ~= 7 then
        display_name = "[EAX Hunter Survival] Enable (" .. key_helper:get_key_name(toggle_key_code) .. ")"
    end
    control_panel_utility:insert_toggle_(elements, display_name, menu.toggle_key)
    return elements
end

core.register_on_update_callback(on_update)
core.register_on_render_menu_callback(menu.render)
core.register_on_render_control_panel_callback(on_control_panel)

return {}
