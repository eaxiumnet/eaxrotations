-- EAX Paladin Retribution | main.lua
-- Rotation logic for Seal twists, Crusader Strike, and Judgement.

local menu = require("menu")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")
local color     = require("color")

---@type interrupt_manager
local interrupt_manager = require("common/eax_shared/interrupt_manager")
---@type ooc_manager
local ooc_manager = require("common/eax_shared/ooc_manager")
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
esp_renderer.init("pret", "Paladin Ret")
---@type ttd_tracker
local ttd_tracker = require("ttd_tracker")
---@type racial_manager
local racial_manager = require("common/eax_shared/racial_manager")
---@type defensive_manager
local defensive_manager = require("common/eax_shared/defensive_manager")

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local runtime = {
    divine_shield_id = nil,
    redemption_id = nil,
    crusader_strike_id = nil,
    divine_storm_id = nil,
    avenging_wrath_id = nil,
    seal_command_id = nil,
    consecration_id = nil,
    divine_favor_id = nil,
    exorcism_id = nil,
    seal_righteousness_id = nil,
    seal_blood_id = nil,
    judgement_ids = {
        wisdom = nil,
        crusader = nil,
    },
    last_cast_time = 0,
    cached_mode = "solo",
    last_twist_at = 0,
    twist_state = "idle",
    ooc_blessing_of_might_id = nil,
    ooc_blessing_of_wisdom_id = nil,
    hand_of_freedom_id = nil,
    hammer_of_the_righteous_id = nil,
    templars_verdict_id = nil,
    inquisition_id = nil,
    judgement_id = nil,
    holy_power = 0,
}

local GCD_CAST_INTERVAL = 1.5  -- TBC GCD
local MODE_REFRESH_INTERVAL = 3.0
local RET_AOE_RADIUS = 8

local RET_EXTRA_SPELLS = {
    HAMMER_OF_THE_RIGHTEOUS = { 53595 },
    TEMPLARS_VERDICT = { 85256 },
    INQUISITION = { 84963 },
    JUDGEMENT = { 20271 },
}

local function clamp_holy_power(value)
    if value < 0 then
        return 0
    end
    if value > 3 then
        return 3
    end
    return value
end

local function spend_holy_power(amount)
    runtime.holy_power = clamp_holy_power(runtime.holy_power - (amount or 0))
end

local function gain_holy_power(amount)
    runtime.holy_power = clamp_holy_power(runtime.holy_power + (amount or 0))
end

local function count_nearby_enemies(me)
    local ok_count, count = pcall(function()
        return utils.count_enemies_within_radius(me, RET_AOE_RADIUS)
    end)
    if ok_count and type(count) == "number" then
        return count
    end
    local ok_enemy_count, alt_count = pcall(function()
        return utils.enemy_count_in_radius(me, RET_AOE_RADIUS)
    end)
    if ok_enemy_count and type(alt_count) == "number" then
        return alt_count
    end
    return 1
end

local function should_refresh_inquisition(me)
    if not runtime.inquisition_id then
        return false
    end
    if utils.has_buff(me, { 84963 }) then
        return false
    end
    return runtime.holy_power >= 1
end

local function resolve_spells()
    runtime.hammer_of_wrath_id = utils.resolve_spell_id(spells.HAMMER_OF_WRATH)
    runtime.divine_plea_id     = utils.resolve_spell_id(spells.DIVINE_PLEA)
    runtime.lay_on_hands_id    = utils.resolve_spell_id(spells.LAY_ON_HANDS)
    runtime.crusader_strike_id = utils.resolve_spell_id(spells.CRUSADER_STRIKE)
    runtime.divine_storm_id      = utils.resolve_spell_id(spells.DIVINE_STORM)
    runtime.hammer_of_the_righteous_id = utils.resolve_spell_id(spells.HAMMER_OF_THE_RIGHTEOUS or RET_EXTRA_SPELLS.HAMMER_OF_THE_RIGHTEOUS)
    runtime.templars_verdict_id = utils.resolve_spell_id(spells.TEMPLARS_VERDICT or RET_EXTRA_SPELLS.TEMPLARS_VERDICT)
    runtime.inquisition_id = utils.resolve_spell_id(spells.INQUISITION or RET_EXTRA_SPELLS.INQUISITION)
    runtime.judgement_id = utils.resolve_spell_id(spells.JUDGEMENT or RET_EXTRA_SPELLS.JUDGEMENT)
    runtime.avenging_wrath_id    = utils.resolve_spell_id(spells.AVENGING_WRATH)
    runtime.seal_command_id = utils.resolve_spell_id(spells.SEAL_OF_COMMAND)
    runtime.seal_righteousness_id = utils.resolve_spell_id(spells.SEAL_OF_RIGHTEOUSNESS)
    runtime.seal_blood_id = utils.resolve_spell_id(spells.SEAL_OF_BLOOD)
    runtime.consecration_id = utils.resolve_spell_id(spells.CONSECRATION)
    runtime.divine_favor_id  = utils.resolve_spell_id(spells.DIVINE_FAVOR)
    runtime.exorcism_id      = utils.resolve_spell_id(spells.EXORCISM)
    runtime.redemption_id  = utils.resolve_spell_id(spells.REDEMPTION)
    runtime.hand_of_freedom_id = utils.resolve_spell_id(spells.HAND_OF_FREEDOM)
    runtime.judgement_ids.wisdom = utils.resolve_spell_id(spells.JUDGEMENT_OF_WISDOM)
    runtime.judgement_ids.crusader = utils.resolve_spell_id(spells.JUDGEMENT_OF_THE_CRUSADER)
    runtime.divine_shield_id = utils.resolve_spell_id(spells.DIVINE_SHIELD)
end

local function log_resolved_spells()
    core.log("[EAX Paladin Retribution] Resolved spells: CS=" .. tostring(runtime.crusader_strike_id))
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

local function refresh_mode_cache()
    runtime.cached_mode = detect_mode()
end

local function get_effective_mode()
    local idx = menu.mode:get()
    if idx == 1 then
        return runtime.cached_mode
    end
    if idx == 2 then
        return "solo"
    end
    if idx == 3 then
        return "dungeon"
    end
    return "raid"
end

local function is_gcd_ready()
    if (core.time() - runtime.last_cast_time) < GCD_CAST_INTERVAL then
        return false
    end
    return core.spell_book.get_global_cooldown() <= 0
end

local function note_cast()
    runtime.last_cast_time = core.time()
end

local function twists_allowed_in_mode(mode)
    if mode == "solo" then
        return true
    elseif mode == "dungeon" then
        return menu.allow_twist_dungeon:get_state()
    elseif mode == "raid" then
        return menu.allow_twist_raid:get_state()
    end
    return true
end

local function get_current_seal(me)
    if utils.has_buff(me, spells.BUFF_SEAL_OF_BLOOD) then
        return "blood"
    end
    if utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND) then
        return "command"
    end
    if utils.has_buff(me, spells.BUFF_SEAL_OF_RIGHTEOUSNESS) then
        return "righteous"
    end
    return "none"
end

local function should_start_seal_twist(me, target)
    if runtime.twist_state ~= "idle" then
        return false
    end
    if not menu.use_seal_twist:get_state() then
        return false
    end
    local effective_mode = get_effective_mode()
    if not twists_allowed_in_mode(effective_mode) then
        return false
    end
    if not target or not target:is_valid() or target:is_dead() then
        return false
    end
    if not utils.is_melee_target(me, target) then
        return false
    end
    if not runtime.seal_command_id or not runtime.seal_blood_id or not runtime.seal_righteousness_id then
        return false
    end
    if not utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND) then
        return false
    end
    if not is_gcd_ready() then
        return false
    end
    local next_swing_ms = utils.get_next_swing_ms(me)
    if next_swing_ms < menu.seal_twist_window:get() then
        return false
    end
    local required_cooldown = menu.seal_twist_cooldown:get() / 1000
    if (core.time() - runtime.last_twist_at) < required_cooldown then
        return false
    end
    return true
end

local function begin_seal_twist(me, target)
    if not should_start_seal_twist(me, target) then
        return false
    end
    if utils.cast_self(runtime.seal_blood_id, me) then
        runtime.twist_state = "blood"
        runtime.last_twist_at = core.time()
        utils.log_debug(menu, "Seal twist -> Blood")
        note_cast()
        return true
    end
    return false
end

local function continue_seal_twist(me)
    if runtime.twist_state == "idle" then
        return false
    end
    if not is_gcd_ready() then
        return false
    end

    if runtime.twist_state == "blood" then
        if utils.cast_self(runtime.seal_righteousness_id, me) then
            runtime.twist_state = "righteous"
            utils.log_debug(menu, "Seal twist -> Righteousness")
            note_cast()
            return true
        end
        return false
    end

    if runtime.twist_state == "righteous" then
        if utils.cast_self(runtime.seal_command_id, me) then
            runtime.twist_state = "command"
            utils.log_debug(menu, "Seal twist -> Command")
            note_cast()
            return true
        end
        return false
    end

    if runtime.twist_state == "command" then
        if utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND) then
            runtime.twist_state = "idle"
            runtime.last_twist_at = core.time()
        end
    end

    return false
end

local function ensure_command_active(me)
    if runtime.twist_state ~= "idle" then
        return false
    end
    if utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND) then
        return false
    end
    if not is_gcd_ready() then
        return false
    end
    if utils.cast_self(runtime.seal_command_id, me) then
        note_cast()
        utils.log_debug(menu, "Seal: Command baseline")
        return true
    end
    return false
end

local function selected_judgement_key()
    if menu.judgement_choice:get() == 2 then
        return "crusader"
    end
    return "wisdom"
end


-- --- Consecration (v1.6) ------------------------------------------------------
-- AoE threat + DPS; also used in single-target as filler when everything else is on CD

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

local function try_consecration(me, target)
    if enc and not enc.aoe_safe then return false end
    if not menu.use_consecration or not menu.use_consecration:get_state() then return false end
    if not runtime.consecration_id then return false end
    if not utils.is_melee_target(me, target) then return false end
    if not utils.can_cast_self(runtime.consecration_id, me) then return false end
    if utils.cast_self(runtime.consecration_id, me) then
        utils.log_debug(menu, "Consecration")
        return true
    end
    return false
end

-- --- Divine Favor (v1.6) - Holy Shock guaranteed crit -------------------------

local function try_divine_favor(me)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_divine_favor or not menu.use_divine_favor:get_state() then return false end
    if not runtime.divine_favor_id then return false end
    if not me:is_in_combat() then return false end
    if not utils.can_cast_self(runtime.divine_favor_id, me) then return false end
    if utils.cast_self_fast(runtime.divine_favor_id, me) then
        utils.log_debug(menu, "Divine Favor")
        return true
    end
    return false
end

-- --- Exorcism (v1.6) - Undead / Demon only ------------------------------------

local function try_exorcism(me, target)
    if not menu.use_exorcism or not menu.use_exorcism:get_state() then return false end
    if not runtime.exorcism_id then return false end
    -- TBC: Exorcism only works on undead and demons
    local target_type = target.get_creature_type and target:get_creature_type() or 0
    local UNDEAD, DEMON = 5, 2  -- creature type IDs
    if target_type ~= UNDEAD and target_type ~= DEMON then return false end
    if not utils.can_cast_hostile(runtime.exorcism_id, me, target) then return false end
    if utils.cast_target(runtime.exorcism_id, target, "Exorcism") then
        utils.log_debug(menu, "Exorcism (undead/demon)")
        return true
    end
    return false
end


local function maybe_cast_judgement(me, target)
    if not menu.use_judgement:get_state() then
        return false
    end
    if not target or not target:is_valid() or target:is_dead() or not utils.is_melee_target(me, target) then
        return false
    end
    if not is_gcd_ready() then
        return false
    end

    local mode_key = selected_judgement_key()
    local spell_id = runtime.judgement_id or runtime.judgement_ids[mode_key]
    if not spell_id then
        return false
    end
    if utils.cast_target(spell_id, target) then
        gain_holy_power(1)
        note_cast()
        utils.log_debug(menu, "Judgement -> " .. (mode_key == "crusader" and "Crusader" or "Wisdom"))
                esp_renderer.on_cast(runtime.spell_id, "Judgement", color.yellow(220))
        return true
    end
    return false
end

local function maybe_cast_crusader_strike(me, target)
    if not menu.use_crusader_strike:get_state() then
        return false
    end
    if not target or not target:is_valid() or target:is_dead() or not utils.is_melee_target(me, target) then
        return false
    end
    if not is_gcd_ready() then
        return false
    end
    if not runtime.crusader_strike_id then
        return false
    end
    if utils.cast_target(runtime.crusader_strike_id, target) then
        gain_holy_power(1)
        note_cast()
        utils.log_debug(menu, "Crusader Strike")
                esp_renderer.on_cast(runtime.crusader_strike_id, "Crusader Strike", color.gold(220))
        return true
    end
    return false
end

local function maybe_cast_hammer_of_the_righteous(me, target, enemy_count)
    if enemy_count < 3 then
        return false
    end
    if not runtime.hammer_of_the_righteous_id then
        return false
    end
    if not target or not target:is_valid() or target:is_dead() or not utils.is_melee_target(me, target) then
        return false
    end
    if not is_gcd_ready() then
        return false
    end
    if not utils.can_cast_hostile(runtime.hammer_of_the_righteous_id, me, target) then
        return false
    end
    if utils.cast_target(runtime.hammer_of_the_righteous_id, target) then
        gain_holy_power(1)
        note_cast()
        utils.log_debug(menu, "Hammer of the Righteous")
        return true
    end
    return false
end

local function maybe_cast_inquisition(me)
    if not should_refresh_inquisition(me) then
        return false
    end
    if not is_gcd_ready() then
        return false
    end
    if not utils.can_cast_self(runtime.inquisition_id, me) then
        return false
    end
    if utils.cast_self(runtime.inquisition_id, me) then
        spend_holy_power(1)
        note_cast()
        utils.log_debug(menu, "Inquisition")
        return true
    end
    return false
end

local function maybe_cast_templars_verdict(me, target)
    if runtime.holy_power < 3 then
        return false
    end
    if not runtime.templars_verdict_id then
        return false
    end
    if not target or not target:is_valid() or target:is_dead() or not utils.is_melee_target(me, target) then
        return false
    end
    if not is_gcd_ready() then
        return false
    end
    if not utils.can_cast_hostile(runtime.templars_verdict_id, me, target) then
        return false
    end
    if utils.cast_target(runtime.templars_verdict_id, target) then
        spend_holy_power(3)
        note_cast()
        utils.log_debug(menu, "Templar's Verdict")
        return true
    end
    return false
end

resolve_spells()
log_resolved_spells()


-- --- Offensive CDs (v1.1) -------------------------------------------------

local function try_avenging_wrath(me)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_avenging_wrath or not menu.use_avenging_wrath:get_state() then return false end
    if not runtime.avenging_wrath_id then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_AVENGING_WRATH) then return false end
    if not utils.can_cast_self(runtime.avenging_wrath_id, me) then return false end
    if utils.cast_self_fast(runtime.avenging_wrath_id, me) then
        utils.log_debug(menu, "Avenging Wrath")
        return true
    end
    return false
end

local function try_divine_storm(me, target)
    if enc and not enc.aoe_safe then return false end
    if not menu.use_divine_storm or not menu.use_divine_storm:get_state() then return false end
    if not runtime.divine_storm_id then return false end
    if not utils.can_cast_hostile(runtime.divine_storm_id, me, target) then return false end
    if utils.cast_target(runtime.divine_storm_id, target, "Divine Storm") then
        if runtime.holy_power >= 3 then
            spend_holy_power(3)
        else
            gain_holy_power(1)
        end
        utils.log_debug(menu, "Divine Storm")
                esp_renderer.on_cast(runtime.divine_storm_id, "Divine Storm", color.gold(220))
        return true
    end
    return false
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
core.register_on_update_callback(function()
    if not menu.enabled:get_state() then
        return
    end

    local me = core.object_manager.get_local_player()
    if not me or me:is_dead() then
        return
    end
        ooc_manager.on_update(me, menu, utils, {
        group_buffs = {
            { spell_id = runtime.ooc_blessing_of_might_id,
               buff_ids = spells.BUFF_BLESSING_OF_MIGHT,
               name = "Blessing of Might",
               toggle = menu.ooc_group_buff },
            { spell_id = runtime.ooc_blessing_of_wisdom_id,
               buff_ids = spells.BUFF_BLESSING_OF_WISDOM,
               name = "Blessing of Wisdom",
               toggle = menu.ooc_group_buff },
        },
    })
    if eax_utils.is_eating_or_drinking(me) then return end

    if utils.throttle("eaxpr:mode", MODE_REFRESH_INTERVAL) then
        refresh_mode_cache()
    end

    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and not me:can_attack(focus_target) then focus_target = nil end
    local target = focus_target or utils.find_best_target(me)
    local enemy_count = count_nearby_enemies(me)
    
    -- Self-emergency
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_holy_light then try_holy_light(me, me) end
    end
    
    utils.ensure_melee_auto_attack(me, target)


    -- Mana conservation (leveling 1-70)
    if leveling_manager.is_conserving_mana(me, menu) then
        leveling_manager.ensure_melee(me, target)
    end
    -- Encounter policy (boss-specific rotation adjustments)
    enc = encounter_manager.get_policy(me)

    -- Interrupt
    if target and target:is_valid() and me:can_attack(target) and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "paladin", utils) then
            return
        end
    end

    -- Racial CDs
    racial_manager.try_offensive(me)
    racial_manager.try_utility(me, target)
    racial_manager.try_defensive(me)

    -- Defensive abilities
    ttd_tracker.update(target)

    if try_divine_shield_emergency(me) then return true end
    if defensive_manager.try_defensive(me, "paladin", utils) then
        return
    end

    if try_hand_of_freedom(me) then return end
    if continue_seal_twist(me) then
        return
    end

    -- Offensive CDs
    try_avenging_wrath(me)
    if try_divine_favor(me) then return end
    if enemy_count >= 3 and runtime.holy_power >= 3 and try_divine_storm(me, target) then return end
    if maybe_cast_templars_verdict(me, target) then return end
    if maybe_cast_inquisition(me) then return end
    if try_exorcism(me, target) then return end

    if maybe_cast_hammer_of_the_righteous(me, target, enemy_count) then return end

    if maybe_cast_judgement(me, target) then
        return
    end

    if maybe_cast_crusader_strike(me, target) then return end
    if enemy_count >= 3 and try_divine_storm(me, target) then return end
    if try_consecration(me, target) then return end

    if begin_seal_twist(me, target) then
        return
    end

    ensure_command_active(me)
end)


-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxpaladinretribution_space_win")
_space_win:set_initial_size(_vec2.new(460, 580))
_space_win:set_next_window_min_size(_vec2.new(320, 300))
_space_win:set_next_window_padding(_vec2.new(10, 8))
menu.set_window(_space_win)
-- -----------------------------------------------------------------------------
core.register_on_render_menu_callback(function()
    menu.render()
end)

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
        local label = "EAX Paladin Ret] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxpaladinretribution_enabled_cp")
        if menu.enabled:get_state() then
        if menu.use_cooldowns then
            local cur_prt_cds = menu.use_cooldowns:get_state()
            local nxt_prt_cds = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX PRt] Cooldowns", cur_prt_cds, 0, false, "eax_prt_cds_cp")
            if nxt_prt_cds ~= cur_prt_cds then menu.use_cooldowns:set(nxt_prt_cds) end
        end
        if menu.focus_priority then
            local cur_prt_focus = menu.focus_priority:get_state()
            local nxt_prt_focus = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX PRt] Focus Priority", cur_prt_focus, 0, false, "eax_prt_focus_cp")
            if nxt_prt_focus ~= cur_prt_focus then menu.focus_priority:set(nxt_prt_focus) end
        end
        if menu.use_racial then
            local cur_prt_racial = menu.use_racial:get_state()
            local nxt_prt_racial = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX PRt] Use Racial", cur_prt_racial, 0, false, "eax_prt_racial_cp")
            if nxt_prt_racial ~= cur_prt_racial then menu.use_racial:set(nxt_prt_racial) end
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
    local _eax_spec  = "Retribution"
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

local _pi = pcall(require, "plugin_info") and require("plugin_info") or nil
core.log("[EAX Paladin Retribution] Loaded " .. (_pi and _pi.plugin_version or "?"))
