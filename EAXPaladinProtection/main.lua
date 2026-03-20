-- EAX PaladinProtection | main.lua
-- Core rotation wiring for Protection Paladin survival and threat management.

local menu = require("menu")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")

---@type interrupt_manager
local interrupt_manager = require("common/eax_shared/interrupt_manager")
---@type ooc_manager
local ooc_manager = require("common/eax_shared/ooc_manager")
---@type vendor_automation
local vendor_automation = require("common/eax_shared/vendor_automation")
---@type consumables_manager
local consumables_manager = require("common/eax_shared/consumables_manager")
---@type mount_manager
local mount_manager = require("common/eax_shared/mount_manager")
---@type leveling_manager
local leveling_manager = require("leveling_manager")
---@type creature_utils
local creature_utils = require("creature_utils")

---@type encounter_manager
local encounter_manager = require("common/eax_shared/encounter_manager")
-- Module-level encounter policy cache (updated each tick)
local enc = nil


---@type esp_renderer
local esp_renderer = require("esp_renderer")
esp_renderer.init("pprot", "Paladin Prot")


-- Phase 04 visual telemetry wiring
local dps_meter = require("common/eax_shared/dps_meter")
local cooldown_tracker = require("common/eax_shared/cooldown_tracker")
local visual_state = require("common/eax_shared/visual_state")
local reactive_runtime = require("eax_shared/reactive_runtime")

local _visual_ttd_tracker = nil
local _visual_ttd_ok, _visual_ttd_mod = pcall(require, "ttd_tracker")
if _visual_ttd_ok and _visual_ttd_mod then
    _visual_ttd_tracker = _visual_ttd_mod
end

local _visual_runtime = {
    in_combat = false,
    last_me_hp_pct = nil,
    last_target_hp_pct = nil,
    reactive_state = {},
}

local reactive_adapter = {}

local _visual_on_cast = esp_renderer.on_cast
function esp_renderer.on_cast(spell_id, name, col, target_name)
    if spell_id and core and core.time and core.spell_book and core.spell_book.get_spell_cooldown then
        local now_s = core.time()
        local cd_s = tonumber(core.spell_book.get_spell_cooldown(spell_id)) or 0
        cooldown_tracker.set_next_spell(spell_id, now_s, cd_s)
    end
    return _visual_on_cast(spell_id, name, col, target_name)
end

local function visual_get_ttd_seconds(target)
    if not _visual_ttd_tracker or not _visual_ttd_tracker.get then return "--" end
    local ok, value = pcall(function() return _visual_ttd_tracker.get(target) end)
    if not ok then return "--" end
    local ttd_value = tonumber(value)
    if not ttd_value then return "--" end
    return ttd_value
end

local function visual_build_tracked_auras(me, target)
    local tracked_auras = {}
    if me and me:is_in_combat() then
        tracked_auras[#tracked_auras + 1] = { label = "Combat", active = true }
    end
    if target and target:is_valid() and not target:is_dead() then
        if target:is_casting_spell() then
            tracked_auras[#tracked_auras + 1] = { label = "Cast", active = true }
        end
        if target:is_channelling_spell() then
            tracked_auras[#tracked_auras + 1] = { label = "Channel", active = true }
        end
    end
    return tracked_auras
end

local function visual_update_snapshot(me, target)
    if not me then return end
    local in_combat = me:is_in_combat()
    if in_combat and not _visual_runtime.in_combat then
        dps_meter.on_combat_start()
        _visual_runtime.in_combat = true
        _visual_runtime.last_me_hp_pct = nil
        _visual_runtime.last_target_hp_pct = nil
    elseif (not in_combat) and _visual_runtime.in_combat then
        dps_meter.on_combat_end()
        _visual_runtime.in_combat = false
        _visual_runtime.last_me_hp_pct = nil
        _visual_runtime.last_target_hp_pct = nil
    end

    local me_hp_pct = tonumber(me:get_health_percentage())
    if in_combat and _visual_runtime.last_me_hp_pct and me_hp_pct and me_hp_pct > _visual_runtime.last_me_hp_pct then
        dps_meter.on_heal(me_hp_pct - _visual_runtime.last_me_hp_pct)
    end
    _visual_runtime.last_me_hp_pct = me_hp_pct

    local target_hp_pct = nil
    if target and target:is_valid() and not target:is_dead() then
        target_hp_pct = tonumber(target:get_health_percentage())
    end
    if in_combat and _visual_runtime.last_target_hp_pct and target_hp_pct and target_hp_pct < _visual_runtime.last_target_hp_pct then
        dps_meter.on_damage(_visual_runtime.last_target_hp_pct - target_hp_pct)
    end
    _visual_runtime.last_target_hp_pct = target_hp_pct

    reactive_runtime.update_tick(me, target, {
        adapter = reactive_adapter,
        encounter_manager = encounter_manager,
        state = _visual_runtime.reactive_state,
        spec = "EAXPaladinProtection",
    })

    local snapshot = visual_state.build_snapshot({
        now_s = core.time(),
        ttd_seconds = visual_get_ttd_seconds(target),
        tracked_auras = visual_build_tracked_auras(me, target),
    })

    if esp_renderer.update_visual_snapshot then
        esp_renderer.update_visual_snapshot(snapshot)
    elseif esp_renderer.set_visual_snapshot then
        esp_renderer.set_visual_snapshot(snapshot)
    end
end

core.register_on_update_callback(function()
    if not menu or not menu.enabled or not menu.enabled:get_state() then return end
    local me = core.object_manager.get_local_player()
    if not me or me:is_dead() then return end
    local target = me:get_target()
    visual_update_snapshot(me, target)
end)
---@type racial_manager
local racial_manager = require("common/eax_shared/racial_manager")
---@type defensive_manager
local defensive_manager = require("common/eax_shared/defensive_manager")

---@type ttd_tracker
local ttd_tracker = require("ttd_tracker")

---@type color
local color = require("color")

local MODE_AUTO = "auto"
local MODE_SOLO = "solo"
local MODE_DUNGEON = "dungeon"
local MODE_RAID = "raid"
local MODE_DETECT_INTERVAL = 1.5
local UPDATE_INTERVAL = 0.12
local NOTIFICATION_LABEL = "EAX Paladin Protection"

local runtime = {
    divine_shield_id = nil,
    redemption_id = nil,
    hammer_of_justice_id = nil,
    righteous_fury_id = nil,
    holy_shield_id = nil,
    consecration_id = nil,
    avengers_shield_id = nil,
    judgement_id = nil,
    cached_mode = MODE_SOLO,
    mode_checked_at = 0,
    last_update_at = 0,
    prev_toggle_state = false,
    ooc_blessing_of_might_id = nil,
    ooc_blessing_of_sanctuary_id = nil,
    hand_of_freedom_id = nil,
    holy_wrath_id = nil,
    shield_of_the_righteous_id = nil,
    hammer_of_the_righteous_id = nil,
    crusader_strike_id = nil,
    lay_on_hands_id = nil,
    holy_power = 0,
}

local PROT_EXTRA_SPELLS = {
    SHIELD_OF_THE_RIGHTEOUS = { 53600 },
}

local GRAND_CRUSADER_BUFFS = { 85416, 90174 }

local function clamp_holy_power(value)
    if value < 0 then
        return 0
    end
    if value > 3 then
        return 3
    end
    return value
end

local function gain_holy_power(amount)
    runtime.holy_power = clamp_holy_power(runtime.holy_power + (amount or 0))
end

local function spend_holy_power(amount)
    runtime.holy_power = clamp_holy_power(runtime.holy_power - (amount or 0))
end

local function has_grand_crusader_proc(me)
    return utils.has_buff(me, GRAND_CRUSADER_BUFFS)
end

local function resolve_spells()
    runtime.righteous_fury_id = utils.resolve_spell_id(spells.RIGHTEOUS_FURY)
    runtime.holy_shield_id = utils.resolve_spell_id(spells.HOLY_SHIELD)
    runtime.holy_wrath_id = utils.resolve_spell_id(spells.HOLY_WRATH)
    runtime.consecration_id = utils.resolve_spell_id(spells.CONSECRATION)
    runtime.avengers_shield_id = utils.resolve_spell_id(spells.AVENGERS_SHIELD)
    runtime.shield_of_the_righteous_id = utils.resolve_spell_id(spells.SHIELD_OF_THE_RIGHTEOUS or PROT_EXTRA_SPELLS.SHIELD_OF_THE_RIGHTEOUS)
    runtime.hammer_of_the_righteous_id = utils.resolve_spell_id(spells.HAMMER_OF_THE_RIGHTEOUS)
    runtime.crusader_strike_id = utils.resolve_spell_id(spells.CRUSADER_STRIKE)
    runtime.judgement_id = utils.resolve_spell_id(spells.JUDGEMENT)
    runtime.hammer_of_justice_id = utils.resolve_spell_id(spells.HAMMER_OF_JUSTICE)
    runtime.lay_on_hands_id = utils.resolve_spell_id(spells.LAY_ON_HANDS)
    runtime.redemption_id  = utils.resolve_spell_id(spells.REDEMPTION)
    runtime.hand_of_freedom_id = utils.resolve_spell_id(spells.HAND_OF_FREEDOM)
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

local function try_hand_of_freedom(me)
    if not menu.use_hand_of_freedom:get_state() then return false end
    if not runtime.hand_of_freedom_id then return false end
    if not utils.can_cast_self(runtime.hand_of_freedom_id, me) then return false end

    local include_slows = menu.hof_include_slows:get_state()
    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local unit = objects[i]
        if unit and unit:is_valid() and unit:is_unit() and not unit:is_dead()
            and (me:is_party_member_of(unit) or utils.same_unit(me, unit)) then
            local is_root = unit:is_rooted(500)
            local is_slow = include_slows and unit:is_slowed(0.30, 500)
            if is_root or is_slow then
                if not utils.has_buff(unit, spells.BUFF_HAND_OF_FREEDOM) then
                    if utils.cast_unit(runtime.hand_of_freedom_id, me, unit) then
                        utils.log_debug(menu, "Hand of Freedom -> " .. (unit.get_name and unit:get_name() or "ally"))
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function try_consecration(me, enemy_count)
    if enc and not enc.aoe_safe then return false end
    if not menu.use_consecration:get_state() or not runtime.consecration_id then
        return false
    end

    if enemy_count < menu.consecration_enemy_count:get() then
        return false
    end

    if utils.can_cast_self(runtime.consecration_id, me) and utils.cast_self(runtime.consecration_id, me) then
        utils.log_debug(menu, "Cast Consecration")
        notify_cast("paladin:consecration", "Consecration", color.red(220))
                esp_renderer.on_cast(nil, "Consecration", color.yellow(220))
        return true
    end

    return false
end

local function try_avengers_shield(me, target, mode)
    if not menu.use_avengers_shield:get_state() or not runtime.avengers_shield_id then
        return false
    end

    if runtime.holy_power < 3 and not has_grand_crusader_proc(me) then
        return false
    end

    if not target then
        return false
    end

    if utils.can_cast_hostile(runtime.avengers_shield_id, me, target) then
        if utils.cast_target(runtime.avengers_shield_id, target) then
            if runtime.holy_power >= 3 then
                spend_holy_power(3)
            end
            utils.log_debug(menu, "Cast Avenger's Shield")
            notify_cast("paladin:avengers_shield", "Avenger's Shield", color.green(220))
                    esp_renderer.on_cast(nil, "Avenger's Shield", color.gold(220))
        return true
        end
    end

    return false
end

local function try_judgement(me, target)
    if not menu.use_judgement:get_state() or not runtime.judgement_id or not target then
        return false
    end

    if not utils.can_cast_hostile(runtime.judgement_id, me, target) then
        return false
    end

    if utils.cast_target(runtime.judgement_id, target) then
        gain_holy_power(1)
        utils.log_debug(menu, "Cast Judgement")
        notify_cast("paladin:judgement", "Judgement", color.gold(220))
        return true
    end

    return false
end

local function try_holy_wrath(me)
    if not runtime.holy_wrath_id then
        return false
    end
    if enc and not enc.aoe_safe then
        return false
    end
    if utils.get_mana_pct(me) < 0.20 then
        return false
    end
    if not utils.can_cast_self(runtime.holy_wrath_id, me) then
        return false
    end
    if utils.cast_self(runtime.holy_wrath_id, me) then
        utils.log_debug(menu, "Holy Wrath")
        return true
    end
    return false
end

local function try_hammer_of_the_righteous(me, target, enemy_count)
    if enemy_count < 3 then
        return false
    end
    if not runtime.hammer_of_the_righteous_id then
        return false
    end
    if not target or not target:is_valid() or target:is_dead() then
        return false
    end
    if not utils.can_cast_hostile(runtime.hammer_of_the_righteous_id, me, target) then
        return false
    end
    if utils.cast_target(runtime.hammer_of_the_righteous_id, target) then
        gain_holy_power(1)
        return true
    end
    return false
end

local function try_crusader_strike(me, target)
    if not runtime.crusader_strike_id then
        return false
    end
    if not target or not target:is_valid() or target:is_dead() or not utils.is_melee_target(me, target) then
        return false
    end
    if not utils.can_cast_hostile(runtime.crusader_strike_id, me, target) then
        return false
    end
    if utils.cast_target(runtime.crusader_strike_id, target) then
        gain_holy_power(1)
        return true
    end
    return false
end

local function try_shield_of_the_righteous(me, target)
    if runtime.holy_power < 3 then
        return false
    end
    if not runtime.shield_of_the_righteous_id then
        return false
    end
    if not target or not target:is_valid() or target:is_dead() then
        return false
    end
    if not utils.can_cast_hostile(runtime.shield_of_the_righteous_id, me, target) then
        return false
    end
    if utils.cast_target(runtime.shield_of_the_righteous_id, target) then
        spend_holy_power(3)
        return true
    end
    return false
end

local function try_lay_on_hands_emergency(me)
    if not menu.use_lay_on_hands:get_state() or not runtime.lay_on_hands_id then
        return false
    end
    local hp_threshold = menu.use_lay_on_hands_hp_pct:get() / 100
    if (me:get_health_percentage() / 100) > hp_threshold then
        return false
    end
    if not utils.can_cast_self(runtime.lay_on_hands_id, me) then
        return false
    end
    if utils.cast_self(runtime.lay_on_hands_id, me) then
        utils.log_debug(menu, "Lay on Hands")
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


-- --- Hammer of Justice - interrupt/stun (v1.4) ---------------------------

local function try_hammer_of_justice(me, target)
    if not runtime.hammer_of_justice_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not interrupt_manager.should_interrupt(target) then return false end
    if not utils.can_cast_hostile(runtime.hammer_of_justice_id, me, target) then return false end
    if utils.cast_target_fast(runtime.hammer_of_justice_id, target) then
        utils.log_debug(menu, "Hammer of Justice (interrupt)")
        return true
    end
    return false
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
        ooc_manager.on_update(me, menu, utils, {
        group_buffs = {
            { spell_id = runtime.ooc_blessing_of_might_id,
               buff_ids = spells.BUFF_BLESSING_OF_MIGHT,
               name = "Blessing of Might",
               toggle = menu.ooc_group_buff },
            { spell_id = runtime.ooc_blessing_of_sanctuary_id,
               buff_ids = spells.BUFF_BLESSING_OF_SANCTUARY,
               name = "Blessing of Sanctuary",
               toggle = menu.ooc_group_buff },
        },
    })
    if (menu.auto_mount and menu.auto_mount:get_state()) or (menu.auto_dismount and menu.auto_dismount:get_state()) then
        mount_manager.update_mount_state(me, menu, utils)
    end

    if menu.auto_ooc_food_drink and menu.auto_ooc_food_drink:get_state() then
        consumables_manager.try_use_ooc_food_drink(me, menu, utils)
    end

    if menu.auto_repair and menu.auto_repair:get_state() then
        vendor_automation.try_auto_repair(me, menu, utils)
    end

    if menu.auto_sell_greys and menu.auto_sell_greys:get_state() then
        vendor_automation.try_auto_sell_greys(me, menu, utils)
    end

    if me:is_in_combat() then
        if menu.auto_combat_potions and menu.auto_combat_potions:get_state() then
            consumables_manager.try_use_combat_consumable(me, menu, utils)
        end
        if menu.auto_flask and menu.auto_flask:get_state() then
            consumables_manager.try_maintain_flask(me, menu, utils)
        end
    end

    if eax_utils.is_eating_or_drinking(me) then return end

    refresh_mode_cache(now)
    local mode = get_effective_mode()
    
    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    local target = focus_target or utils.find_best_target(me)
    
    if not target or not me:can_attack(target) then
        return
    end

    -- Interrupt
    if interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "paladin", utils) then
            return
        end
    end


    -- Mana conservation (leveling 1-70)
    if leveling_manager.is_conserving_mana(me, menu) then
        leveling_manager.ensure_melee(me, target)
    end
    -- Encounter policy (boss-specific rotation adjustments)
    enc = encounter_manager.get_policy(me)

    -- Racial CDs
    racial_manager.try_offensive(me)
    racial_manager.try_utility(me, target)
    racial_manager.try_defensive(me)

    -- Defensive abilities
    if try_divine_shield_emergency(me) then return true end
    if try_lay_on_hands_emergency(me) then return true end
    if defensive_manager.try_defensive(me, "paladin", utils) then
        return
    end

    ttd_tracker.update(target)

    -- Self-emergency healing
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_hammer_of_justice(me, target) then return true end
    if ensure_holy_shield(me, target) then return true end
    end

    if try_hand_of_freedom(me) then return end
    utils.ensure_melee_attack(me, target)

    if ensure_righteous_fury(me) then
        return
    end

    if ensure_holy_shield(me, target) then
        return
    end

    if try_holy_wrath(me) then
        return
    end

    if try_avengers_shield(me, target, mode) then
        return
    end

    if try_shield_of_the_righteous(me, target) then
        return
    end

    local enemy_count = utils.count_enemies_within_radius(me, menu.consecration_radius:get())
    if try_hammer_of_the_righteous(me, target, enemy_count) then
        return
    end
    if try_crusader_strike(me, target) then
        return
    end

    if try_consecration(me, enemy_count) then
        return
    end

    try_judgement(me, target)
end

local function on_control_panel()
    menu.enabled:render("Enabled", "Master toggle for the paladin helper")
    menu.mode:render("Mode", { "Auto", "Solo", "Dungeon", "Raid" })
end

resolve_spells()

reactive_adapter = {
    spec = "EAXPaladinProtection",
    actions = {
        life_save_self = {
            handler = function(_, action_deps)
                return defensive_manager.try_defensive(action_deps.me, "paladin", utils)
            end,
        },
        life_save_ally = { noop = "unsupported" },
        interrupt_control = {
            handler = function(_, action_deps)
                local interrupt_target = action_deps.target or action_deps.current_target
                if not interrupt_target or not interrupt_target:is_valid() then
                    return false
                end

                if not interrupt_manager.should_interrupt(interrupt_target) then
                    return false
                end

                return interrupt_manager.try_interrupt(action_deps.me, interrupt_target, "paladin", utils)
            end,
        },
        anti_overheal = { noop = "unsupported" },
        anti_aggro = { noop = "unsupported" },
        throughput_resume = { noop = "unsupported" },
    },
}

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
local _space_win = core.menu.window("eaxpaladinprotection_space_win")
_space_win:set_initial_size(_vec2.new(460, 580))
_space_win:set_next_window_min_size(_vec2.new(320, 300))
_space_win:set_next_window_padding(_vec2.new(10, 8))
menu.set_window(_space_win)
-- -----------------------------------------------------------------------------
core.register_on_render_menu_callback(menu.render)
core.register_on_render_control_panel_callback(on_control_panel)


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
        local label = "EAX Paladin Prot] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxpaladinprotection_enabled_cp")
        if menu.enabled:get_state() then
        if menu.use_cooldowns then
            local cur_ppr_cds = menu.use_cooldowns:get_state()
            local nxt_ppr_cds = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX PPr] Cooldowns", cur_ppr_cds, 0, false, "eax_ppr_cds_cp")
            if nxt_ppr_cds ~= cur_ppr_cds then menu.use_cooldowns:set(nxt_ppr_cds) end
        end
        if menu.use_racial then
            local cur_ppr_racial = menu.use_racial:get_state()
            local nxt_ppr_racial = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX PPr] Use Racial", cur_ppr_racial, 0, false, "eax_ppr_racial_cp")
            if nxt_ppr_racial ~= cur_ppr_racial then menu.use_racial:set(nxt_ppr_racial) end
        end
        end
        return elements
    end)
end

-- -- EAX Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Paladin"
    local _eax_spec  = "Protection"
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


