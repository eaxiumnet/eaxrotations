-- main.lua
-- EAX Hunter Survival | Full TBC Auto Rotation
-- Priority: Serpent Sting > Explosive Shot > Raptor Strike > Melee

local menu = require("menu")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")
local color     = require("color")

---@type interrupt_manager
local interrupt_manager = require("interrupt_manager")
---@type ooc_manager
local ooc_manager = require("ooc_manager")
---@type leveling_manager
local leveling_manager = require("leveling_manager")
---@type creature_utils
local creature_utils = require("creature_utils")

---@type encounter_manager
local encounter_manager = require("encounter_manager")


---@type esp_renderer
local esp_renderer = require("esp_renderer")
esp_renderer.init("sv", "Hunter SV")
---@type ttd_tracker
local ttd_tracker = require("ttd_tracker")
---@type racial_manager
local racial_manager = require("racial_manager")
---@type defensive_manager
local defensive_manager = require("defensive_manager")

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

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
    set_multiplier = 1.0,
}

local GCD_INTERVAL = 1.5  -- actual TBC GCD duration
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
    

if control_panel_utility then
    core.register_on_render_control_panel_callback(function()
        local elements = {}
        local function add_cb(label, item, uid)
            if not item then return end
            local cur = item:get_state()
            local nxt = control_panel_utility:insert_key_checkbox_(elements, label, cur, 0, false, uid)
            if nxt ~= cur then item:set(nxt) end
        end
        local toggle_key = menu.toggle_key:get_key_code()
        local label = "EAX Hunter SV] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxhuntersurvival_enabled_cp")
        if menu.enabled:get_state() then
        if menu.use_cooldowns then
            local cur_hsv_cds = menu.use_cooldowns:get_state()
            local nxt_hsv_cds = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX HSV] Cooldowns", cur_hsv_cds, 0, false, "eax_hsv_cds_cp")
            if nxt_hsv_cds ~= cur_hsv_cds then menu.use_cooldowns:set(nxt_hsv_cds) end
        end
        if menu.focus_priority then
            local cur_hsv_focus = menu.focus_priority:get_state()
            local nxt_hsv_focus = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX HSV] Focus Priority", cur_hsv_focus, 0, false, "eax_hsv_focus_cp")
            if nxt_hsv_focus ~= cur_hsv_focus then menu.focus_priority:set(nxt_hsv_focus) end
        end
        if menu.use_racial then
            local cur_hsv_racial = menu.use_racial:get_state()
            local nxt_hsv_racial = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX HSV] Use Racial", cur_hsv_racial, 0, false, "eax_hsv_racial_cp")
            if nxt_hsv_racial ~= cur_hsv_racial then menu.use_racial:set(nxt_hsv_racial) end
        end
        end
        return elements
    end)
end

-- -- EAX Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Hunter"
    local _eax_spec  = "Survival"
    -- Register this spec for its class (last-loaded wins for tracking)
    if not _G.__EAX_LOADED[_eax_class] then
        _G.__EAX_LOADED[_eax_class] = {}
    end
    _G.__EAX_LOADED[_eax_class][_eax_spec] = function()
        return menu and menu.enabled and menu.enabled:get_state()
    end
    -- Runtime conflict check: fires on render, only warns when 2+ specs enabled
    local _conflict_last_warn = 0
    local _orig_render = on_render
    on_render = function()
        if _orig_render then _orig_render() end
        local specs = _G.__EAX_LOADED[_eax_class]
        if not specs then return end
        local enabled_specs = {}
        for spec_name, is_enabled_fn in pairs(specs) do
            if is_enabled_fn and is_enabled_fn() then
                table.insert(enabled_specs, spec_name)
            end
        end
        if #enabled_specs < 2 then return end
        local now = core.time()
        if (now - _conflict_last_warn) < 10 then return end
        _conflict_last_warn = now
        local names = table.concat(enabled_specs, " + ")
        core.log("[EAX WARNING] Multiple " .. _eax_class .. " specs enabled: "
            .. names .. ". Disable all but one.")
        core.graphics.add_notification(
            "eax_conflict_" .. _eax_class,
            "[EAX] Conflict!",
            "Multiple " .. _eax_class .. " specs enabled: " .. names .. " - Disable all but one in the bot menu.",
            8.0,
            require("common/color").new(255, 80, 80, 255)
        )
    end
end

core.log("[EAX Hunter Survival] Resolved: SerpentSting=" .. tostring(runtime.serpent_sting_id)
        .. " ExplosiveShot=" .. tostring(runtime.explosive_shot_id)
        .. " RaptorStrike=" .. tostring(runtime.raptor_strike_id)
        .. " WingClip=" .. tostring(runtime.wing_clip_id))
end

resolve_spells()
log_resolved_spells()

local function update_set_bonus()
    local me = core.object_manager.get_local_player()
    if not me then return end
    
    local cryptstalker_mult = utils.get_set_multiplier(me, "Cryptstalker")
    local cryptstalker_battlegear_mult = utils.get_set_multiplier(me, "CryptstalkerBattlegear")
    local cryptstalker_vindication_mult = utils.get_set_multiplier(me, "CryptstalkerVindication")
    
    runtime.set_multiplier = cryptstalker_mult
    if cryptstalker_battlegear_mult > runtime.set_multiplier then
        runtime.set_multiplier = cryptstalker_battlegear_mult
    end
    if cryptstalker_vindication_mult > runtime.set_multiplier then
        runtime.set_multiplier = cryptstalker_vindication_mult
    end
    
    if runtime.set_multiplier > 1.0 then
        utils.log_debug(menu, "Set bonus: " .. tostring(runtime.set_multiplier))
    end
end

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
    local buff = buff_manager:get_buff_data(me, {spell_id})
    return buff and buff.is_active
end

local function has_debuff(spell_id, target)
    if not spell_id or not target then return false end
    local debuff = buff_manager:get_debuff_data(target, {spell_id})
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


-- --- Auto Shot clip buffer (v1.3) ----------------------------------------
-- Prevents instant casts from clipping the auto shot timing.
-- auto_shot_eta_ms: time until next auto shot fires
-- Returns true if it is safe to cast an instant right now.

local AUTO_SHOT_CLIP_BUFFER_MS = 200   -- 200ms safety margin

local function get_auto_shot_eta_ms(me)
    -- Use the auto-attack helper if available
    if me and me.get_auto_attack_timer_ms then
        local ok, val = pcall(function() return me:get_auto_attack_timer_ms() end)
        if ok and type(val) == "number" then return val end
    end
    -- Fallback: assume safe
    return 9999
end

local function allow_instant(me)
    local eta = get_auto_shot_eta_ms(me)
    return eta > AUTO_SHOT_CLIP_BUFFER_MS
end

local function allow_cast(me, cast_ms)
    if me and me.is_moving and me:is_moving() then return false end
    local eta = get_auto_shot_eta_ms(me)
    return eta > (cast_ms + AUTO_SHOT_CLIP_BUFFER_MS)
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
                esp_renderer.on_cast(nil, "Explosive Shot", color.red(220))
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
                esp_renderer.on_cast(nil, "Steady Shot", color.green(220))
        return true
    end
    return false
end

local function try_multi_shot(target)
    if enc and not enc.aoe_safe then return false end
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


-- --- Kiting / Threat Management (v1.2) -----------------------------------

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



-- --- Scorpid / Viper Sting situational use (v1.4) ------------------------

local function try_scorpid_sting(target)
    if not runtime.scorpid_sting_id then return false end
    if not menu.use_scorpid_sting or not menu.use_scorpid_sting:get_state() then return false end
    if utils.has_debuff(target, spells.DEBUFF_SCORPID_STING) then return false end
    -- Only use in dungeon/raid (debuffs matter there)
    local mode = get_active_mode()
    if mode == "solo" then return false end
    if not allow_instant(core.object_manager.get_local_player()) then return false end
    if not can_cast(runtime.scorpid_sting_id, target) then return false end
    if cast_spell(runtime.scorpid_sting_id, target) then
        utils.log_debug(menu, "Scorpid Sting")
        return true
    end
    return false
end

local function try_viper_sting(target)
    if not runtime.viper_sting_id then return false end
    if not menu.use_viper_sting or not menu.use_viper_sting:get_state() then return false end
    if utils.has_debuff(target, spells.DEBUFF_VIPER_STING) then return false end
    -- Only use on mana-using targets (casters)
    if not allow_instant(core.object_manager.get_local_player()) then return false end
    if not can_cast(runtime.viper_sting_id, target) then return false end
    if cast_spell(runtime.viper_sting_id, target) then
        utils.log_debug(menu, "Viper Sting")
        return true
    end
    return false
end

-- --- Rapid Fire (v1.4) ----------------------------------------------------

local function try_rapid_fire(me)
    if enc and enc.hold_cooldowns then return false end
    if not runtime.rapid_fire_id then return false end
    if not menu.use_rapid_fire or not menu.use_rapid_fire:get_state() then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_RAPID_FIRE) then return false end
    if not can_cast(runtime.rapid_fire_id, "player") then return false end
    if cast_spell(runtime.rapid_fire_id, "player") then
        utils.log_debug(menu, "Rapid Fire")
        return true
    end
    return false
end

-- --- Intimidation (BM only) (v1.4) ----------------------------------------

local function try_intimidation(me, target)
    if not runtime.intimidation_id then return false end
    if not menu.use_intimidation or not menu.use_intimidation:get_state() then return false end
    if not pet_is_alive() then return false end
    if not allow_instant(me) then return false end
    if not can_cast(runtime.intimidation_id, target) then return false end
    if cast_spell(runtime.intimidation_id, target) then
        utils.log_debug(menu, "Intimidation")
        return true
    end
    return false
end

-- --- Aspect of the Viper - mana recovery (v1.4) ---------------------------

local function try_aspect_of_viper(me)
    -- Switch to Viper when OOM, back to Hawk when full
    if not runtime.viper_aspect_id then return false end
    if not menu.use_aspect_viper or not menu.use_aspect_viper:get_state() then return false end
    local mana_pct = utils.get_mana_pct(me)
    local has_viper = utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_VIPER)
    if has_viper and mana_pct >= 0.90 then
        -- Switch back to Hawk when mana recovered
        if runtime.aspect_hawk_id and can_cast(runtime.aspect_hawk_id, "player") then
            cast_spell(runtime.aspect_hawk_id, "player")
        end
        return false
    end
    if not has_viper and mana_pct < 0.20 then
        if can_cast(runtime.viper_aspect_id, "player") then
            cast_spell(runtime.viper_aspect_id, "player")
            utils.log_debug(menu, "Aspect of the Viper (low mana)")
            return true
        end
    end
    return false
end



local function try_execute_opener(me, target)
    if me:is_in_combat() then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    if pet_is_alive() then do_pet_attack(target) end
    if try_hunters_mark(target) then return true end
    if not me:is_auto_attacking and not me:is_auto_attacking() then
        if core.input and core.input.start_attack then
            core.input.start_attack(target)
        end
    end
    return false
end


local function do_rotation(me, target)
    if is_busy() then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end

    -- Pre-combat opener
    try_execute_opener(me, target)
    if try_feign_death(me) then return true end
    if try_disengage(me, target) then return true end
    try_aspect_of_viper(me)
    try_rapid_fire(me)
    
    -- Interrupt
    if target:is_casting_spell() and target:is_active_spell_interruptable() then
        if runtime.counter_shot_id and can_cast(runtime.counter_shot_id, target) then
            if cast_spell(runtime.counter_shot_id, target) then
                utils.log_debug(menu, "Counter Shot interrupt")
                return true
            end
        end
    end

    -- Defensive abilities
    -- Interrupt
    if interrupt_manager.should_interrupt(target) then
        interrupt_manager.try_interrupt(me, target, "hunter", utils)
    end

    ttd_tracker.update(target)

    if defensive_manager.try_defensive(me, "hunter", utils) then
        return true
    end


    -- Mana conservation (leveling 1-70)
    if leveling_manager.is_conserving_mana(me, menu) then
        leveling_manager.ensure_melee(me, target)
    end
    -- Encounter policy (boss-specific rotation adjustments)
    local enc = encounter_manager.get_policy(me)

    -- Racial CDs
    racial_manager.try_offensive(me)
    racial_manager.try_utility(me, target)
    
    local dist = get_distance(target)
    
    if dist <= 40 then
        face_target(target)
    end
    
    if try_aspect() then return true end
    
    if menu.use_hunters_mark:get_state() then
        if try_hunters_mark(target) then return true end
    if try_scorpid_sting(target) then return true end
    if try_viper_sting(target) then return true end
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
    
    -- Ranged auto-attack fallback for leveling 1-70 (Hunter)
    if me:is_in_combat() and target and target:is_valid() and not target:is_dead()
       and me:can_attack(target) and not me:is_moving() then
        leveling_manager.ensure_ranged(me, target)
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
    
    if utils.throttle("set_bonus", 5.0) then
        update_set_bonus()
    end
    
    handle_toggle()
    
    if not menu.enabled:get_state() then
        return
    end
    
    local me = core.object_manager.get_local_player()
    if not me or me:is_dead() then
        return
    end
        ooc_manager.on_update(me, menu, utils)
    if eax_utils.is_eating_or_drinking(me) then return end
    
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


local function on_render()
    esp_renderer.on_render(menu)
end

-- ESP only renders when this spec is enabled
core.register_on_render_callback(function()
    if not menu or not menu.enabled or not menu.enabled:get_state() then return end
    on_render()
end)
-- __EAX_ESP_GUARD
core.register_on_update_callback(on_update)

-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxhuntersurvival_space_win")
_space_win:set_initial_size(_vec2.new(460, 580))
_space_win:set_next_window_min_size(_vec2.new(320, 300))
_space_win:set_next_window_padding(_vec2.new(10, 8))
menu.set_window(_space_win)
-- -----------------------------------------------------------------------------
core.register_on_render_menu_callback(menu.render)
core.register_on_render_control_panel_callback(on_control_panel)

return {}
