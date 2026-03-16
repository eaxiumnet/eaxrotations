-- EAX PaladinProtection | main.lua
-- Core rotation wiring for Protection Paladin survival and threat management.

local menu = require("menu")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")
---@type color
local color = require("common/color")

local MODE_AUTO = "auto"
local MODE_SOLO = "solo"
local MODE_DUNGEON = "dungeon"
local MODE_RAID = "raid"
local MODE_DETECT_INTERVAL = 1.5
local UPDATE_INTERVAL = 0.12
local NOTIFICATION_LABEL = "EAX Paladin Protection"

local runtime = {
    righteous_fury_id = nil,
    holy_shield_id = nil,
    consecration_id = nil,
    avengers_shield_id = nil,
    judgement_id = nil,
    cached_mode = MODE_SOLO,
    mode_checked_at = 0,
    last_update_at = 0,
    prev_toggle_state = false,
}

local function resolve_spells()
    runtime.righteous_fury_id = utils.resolve_spell_id(spells.RIGHTEOUS_FURY)
    runtime.holy_shield_id = utils.resolve_spell_id(spells.HOLY_SHIELD)
    runtime.consecration_id = utils.resolve_spell_id(spells.CONSECRATION)
    runtime.avengers_shield_id = utils.resolve_spell_id(spells.AVENGERS_SHIELD)
    runtime.judgement_id = utils.resolve_spell_id(spells.JUDGEMENT)
end

local function detect_mode()
    local party_count = utils.get_visible_party_size()
    if party_count == 0 then
        return MODE_SOLO
    elseif party_count <= 4 then
        return MODE_DUNGEON
    end
    return MODE_RAID
end

local function refresh_mode_cache(now)
    if (now - runtime.mode_checked_at) < MODE_DETECT_INTERVAL then
        return
    end
    runtime.cached_mode = detect_mode()
    runtime.mode_checked_at = now
end

local function get_effective_mode()
    local selection = menu.mode:get()
    if selection == 2 then
        return MODE_SOLO
    elseif selection == 3 then
        return MODE_DUNGEON
    elseif selection == 4 then
        return MODE_RAID
    end
    return runtime.cached_mode or MODE_SOLO
end

local function notify_cast(unique_id, message, notification_color)
    if not menu.show_notifications:get_state() then
        return
    end

    if core.graphics.is_notification_active(unique_id) then
        return
    end

    core.graphics.add_notification(
        unique_id,
        NOTIFICATION_LABEL,
        message,
        0.8,
        notification_color or color.gold(220)
    )
end

local function ensure_righteous_fury(me)
    if not menu.use_righteous_fury:get_state() or not runtime.righteous_fury_id then
        return false
    end

    if utils.has_buff(me, spells.BUFF_RIGHTEOUS_FURY) then
        return false
    end

    if utils.can_cast_self(runtime.righteous_fury_id, me) and utils.cast_self(runtime.righteous_fury_id, me) then
        utils.log_debug(menu, "Cast Righteous Fury")
        notify_cast("paladin:rf", "Righteous Fury", color.gold(220))
        return true
    end

    return false
end

local function ensure_holy_shield(me, target)
    if not menu.use_holy_shield:get_state() or not runtime.holy_shield_id then
        return false
    end

    if not utils.is_melee_target(me, target) then
        return false
    end

    if utils.has_buff(me, spells.BUFF_HOLY_SHIELD) then
        return false
    end

    if utils.can_cast_self(runtime.holy_shield_id, me) and utils.cast_self(runtime.holy_shield_id, me) then
        utils.log_debug(menu, "Cast Holy Shield")
        notify_cast("paladin:holy_shield", "Holy Shield", color.blue(220))
        return true
    end

    return false
end

local function try_consecration(me, enemy_count)
    if not menu.use_consecration:get_state() or not runtime.consecration_id then
        return false
    end

    if enemy_count < menu.consecration_enemy_count:get() then
        return false
    end

    if utils.can_cast_self(runtime.consecration_id, me) and utils.cast_self(runtime.consecration_id, me) then
        utils.log_debug(menu, "Cast Consecration")
        notify_cast("paladin:consecration", "Consecration", color.red(220))
        return true
    end

    return false
end

local function try_avengers_shield(me, target, mode)
    if not menu.use_avengers_shield:get_state() or not runtime.avengers_shield_id then
        return false
    end

    if mode == MODE_RAID then
        return false
    end

    if not target or utils.is_melee_target(me, target) then
        return false
    end

    if utils.can_cast_target(runtime.avengers_shield_id, me, target) then
        if utils.cast_target(runtime.avengers_shield_id, me, target) then
            utils.log_debug(menu, "Cast Avenger's Shield")
            notify_cast("paladin:avengers_shield", "Avenger's Shield", color.green(220))
            return true
        end
    end

    return false
end

local function try_judgement(me, target)
    if not menu.use_judgement:get_state() or not runtime.judgement_id or not target then
        return false
    end

    if not utils.can_cast_target(runtime.judgement_id, me, target) then
        return false
    end

    if utils.cast_target(runtime.judgement_id, me, target) then
        utils.log_debug(menu, "Cast Judgement")
        notify_cast("paladin:judgement", "Judgement", color.gold(220))
        return true
    end

    return false
end

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        local was_enabled = menu.enabled:get_state()
        menu.enabled:set(not was_enabled)
        utils.log_debug(menu, "Toggled -> " .. tostring(not was_enabled))
    end
    runtime.prev_toggle_state = current
end

local function on_update()
    if not menu.enabled:get_state() then
        handle_toggle()
        return
    end

    local now = core.time()
    if (now - runtime.last_update_at) < UPDATE_INTERVAL then
        handle_toggle()
        return
    end

    runtime.last_update_at = now
    handle_toggle()
    if not menu.enabled:get_state() then
        return
    end

    local me = core.object_manager.get_local_player()
    if not me or not me:is_valid() or me:is_dead() then
        return
    end

    refresh_mode_cache(now)
    local mode = get_effective_mode()
    
    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    local target = focus_target or utils.find_best_target(me)
    
    if not target or not me:can_attack(target) then
        return
    end

    -- Self-emergency healing
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_holy_shield(me, target) then return true end
    end

    utils.ensure_melee_attack(me, target)

    if ensure_righteous_fury(me) then
        return
    end

    if ensure_holy_shield(me, target) then
        return
    end

    local enemy_count = utils.count_enemies_within_radius(me, menu.consecration_radius:get())
    if try_consecration(me, enemy_count) then
        return
    end

    if try_avengers_shield(me, target, mode) then
        return
    end

    try_judgement(me, target)
end

local function on_control_panel()
    menu.enabled:render("Enabled", "Master toggle for the paladin helper")
    menu.mode:render("Mode", { "Auto", "Solo", "Dungeon", "Raid" })
end

resolve_spells()
core.register_on_update_callback(on_update)
core.register_on_render_menu_callback(menu.render)
core.register_on_render_control_panel_callback(on_control_panel)
