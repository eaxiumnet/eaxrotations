-- EAX Priest Discipline | main.lua
-- Priority rotation that keeps shields, Renew, Power Infusion, and Pain Suppression ready.

local menu = require("menu")
local key_helper = require("common/utility/key_helper")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")
local color     = require("color")

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


---@type esp_renderer
local esp_renderer = require("esp_renderer")
esp_renderer.init("disc", "Priest Disc")


-- Phase 04 visual telemetry wiring
local dps_meter = require("common/eax_shared/dps_meter")
local cooldown_tracker = require("common/eax_shared/cooldown_tracker")
local visual_state = require("common/eax_shared/visual_state")

local _visual_ttd_tracker = nil
local _visual_ttd_ok, _visual_ttd_mod = pcall(require, "ttd_tracker")
if _visual_ttd_ok and _visual_ttd_mod then
    _visual_ttd_tracker = _visual_ttd_mod
end

local _visual_runtime = {
    in_combat = false,
    last_me_hp_pct = nil,
    last_target_hp_pct = nil,
}

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
---@type ttd_tracker
local ttd_tracker = require("ttd_tracker")
---@type racial_manager
local racial_manager = require("common/eax_shared/racial_manager")
---@type defensive_manager
local defensive_manager = require("common/eax_shared/defensive_manager")

---@type mana_conservator
local mana_conservator = require("mana_conservator")
---@type mana_manager
local mana_manager = require("eax_shared/mana_manager")
---@type threat_manager
local threat_manager = require("eax_shared/threat_manager")

-- Guard to init threat_manager only once at startup
local threat_initialized = false

local runtime = {
    resurrection_id = nil,
    penance_id = nil,
    pw_shield_id = nil,
    flash_heal_id = nil,
    mode_cache = "solo",
    last_mode_check = 0,
    last_mode_log = nil,
    set_multiplier = 1.0,
    last_set_check = 0,
}

local resolved = {
    shield = utils.resolve_spell_id(spells.POWER_WORD_SHIELD),
    renew = utils.resolve_spell_id(spells.RENEW),
    power_infusion = utils.resolve_spell_id(spells.POWER_INFUSION),
    pain_suppression = utils.resolve_spell_id(spells.PAIN_SUPPRESSION),
    prayer_of_mending = utils.resolve_spell_id(spells.PRAYER_OF_MENDING),
}
runtime.pw_shield_id = resolved.shield

local function log_mode(mode)
    if menu.debug:get_state() and runtime.last_mode_log ~= mode then
        utils.log_debug(menu, "Mode=" .. mode)
        runtime.last_mode_log = mode
    end
end

local SET_UPDATE_INTERVAL_MS = 5000
local PRIEST_SET_NAMES = { "Vestments", "Absolution", "AbsolutionRegalia" }

local function update_set_bonus(me)
    local now = core.game_time()
    if not runtime.last_set_check or (now - runtime.last_set_check) >= SET_UPDATE_INTERVAL_MS then
        runtime.last_set_check = now
        local best_multiplier = 1.0
        for _, set_name in ipairs(PRIEST_SET_NAMES) do
            local mult = utils.get_set_multiplier(me, set_name)
            if mult > best_multiplier then
                best_multiplier = mult
            end
        end
        runtime.set_multiplier = best_multiplier
    end
end


local function try_inner_fire_disc(me)
    if not runtime.inner_fire_id then return false end
    if utils.has_buff(me, spells.BUFF_INNER_FIRE) then return false end
    if not utils.can_cast_self(runtime.inner_fire_id, me) then return false end
    if utils.cast_self(runtime.inner_fire_id, me) then return true end
    return false
end

local function try_power_infusion(me)
    if not resolved.power_infusion or not menu.power_infusion_enabled:get_state() then
        return false
    end

    if utils.has_buff(me, spells.POWER_INFUSION) then
        return false
    end

    local threshold = menu.power_infusion_threshold:get() / 100
    local candidate = utils.find_low_health_ally(me, threshold, true)

    if candidate then
        return utils.cast_self(resolved.power_infusion, me)
    end

    return false
end

local function try_pain_suppression(me, mode)
    if not resolved.pain_suppression then
        return false
    end

    if mode == "solo" then
        return false
    end

    local threshold = menu.pain_suppression_threshold:get() / 100
    local candidate = utils.find_low_health_ally(me, threshold, false)

    if candidate and not utils.has_buff(candidate, spells.PAIN_SUPPRESSION) then
        return utils.cast_target(resolved.pain_suppression, candidate, nil)
    end

    return false
end

local function get_tank_unit(me)
    local units = utils.get_party_units(me)
    for _, unit in ipairs(units) do
        if unit and unit:is_valid() and not unit:is_dead() then
            local class = unit:get_class()
            if class == 1 or class == 2 or class == 6 then -- Warrior, Paladin, Druid
                return unit
            end
        end
    end
    return nil
end

local function try_shield(me)
    if not resolved.shield then
        return false
    end
    -- Check cooldown
    local cd = core.spell_book.get_spell_cooldown(resolved.shield)
    if cd > 0 then
        return false
    end

    local enc = encounter_manager.get_policy(me)
    local threshold = menu.shield_threshold:get() / 100
    local candidate = nil
    
    -- If tank damage heavy, prioritize tank
    if enc.tank_damage_heavy then
        candidate = get_tank_unit(me)
        if candidate and (utils.has_buff(candidate, spells.POWER_WORD_SHIELD) or utils.has_debuff(candidate, spells.BUFF_WEAKENED_SOUL) or utils.get_health_pct(candidate) > threshold) then
            candidate = nil
        end
    end
    
    -- Fallback to low health ally
    if not candidate then
        candidate = utils.find_low_health_ally(me, threshold, true)
    end

    if candidate and not utils.has_buff(candidate, spells.POWER_WORD_SHIELD) and not utils.has_debuff(candidate, spells.BUFF_WEAKENED_SOUL) then
        return utils.cast_target(resolved.shield, candidate, nil)
    end

    return false
end

local function try_renew(me)
    if not resolved.renew then
        return false
    end

    local threshold = menu.renew_threshold:get() / 100
    local window_ms = menu.renew_refresh_seconds:get() * 1000
    local units = utils.get_party_units(me)
    local candidate = nil
    local lowest_pct = threshold

    for i = 1, #units do
        local unit = units[i]
        if unit then
            local pct = utils.get_health_pct(unit)
            if pct <= threshold and pct <= lowest_pct then
                local remaining = utils.get_buff_remaining_ms(unit, spells.RENEW)
                if remaining <= window_ms then
                    candidate = unit
                    lowest_pct = pct
                end
            end
        end
    end

    if candidate == nil then
        candidate = utils.find_low_health_ally(me, threshold, true)
    end

    if candidate and not utils.has_buff(candidate, spells.RENEW) then
        return utils.cast_target(resolved.renew, candidate, nil)
    end

    return false
end

local function try_prayer_of_mending(me)
    if not resolved.prayer_of_mending or not menu.prayer_of_mending:get_state() then
        return false
    end

    local threshold = menu.prayer_of_mending_threshold:get() / 100
    local candidate = utils.find_low_health_ally(me, threshold, true)

    if candidate and not utils.has_buff(candidate, spells.PRAYER_OF_MENDING) then
        return utils.cast_target(resolved.prayer_of_mending, candidate, nil)
    end

    return false
end


-- --- Power Word: Shield maintenance (v1.4) -------------------------------

local function try_pw_shield(me, target)
    if not runtime.pw_shield_id then return false end
    if not menu.use_pw_shield or not menu.use_pw_shield:get_state() then return false end
    -- Don't apply if Weakened Soul debuff is active
    if utils.has_debuff(target, spells.BUFF_WEAKENED_SOUL) then return false end
    if utils.has_buff(target, spells.BUFF_POWER_WORD_SHIELD) then return false end
    local hp = utils.get_health_pct(target)
    if hp > 0.80 then return false end  -- only shield when taking damage
    esp_renderer.on_cast(nil, "PW:Shield", color.white(220))
    return utils.cast_target(runtime.pw_shield_id, target, "PW:Shield")
end

-- --- Penance - Disc spec burst heal (v1.4) -------------------------------

local function try_penance(me, target)
    if not runtime.penance_id then return false end
    if not menu.use_penance or not menu.use_penance:get_state() then return false end
    if not target or not target:is_valid() then return false end
    local hp = utils.get_health_pct(target)
    if hp > 0.70 then return false end
    if not utils.can_cast_target(runtime.penance_id, me, target) then return false end
    esp_renderer.on_cast(nil, "Penance", color.gold(220))
    return utils.cast_target(runtime.penance_id, target, "Penance")
end



-- --- try_cast_spell - generic target-cast helper for focus/self priority --
local function try_cast_spell(me, target, spell_id)
    if not spell_id then return false end
    if not target or not target:is_valid() then return false end
    if target == me then
        if utils.can_cast_self(spell_id, me) then
            return utils.cast_self(spell_id, me)
        end
    else
        if utils.can_cast_target(spell_id, me, target) then
            return utils.cast_target(spell_id, target, nil)
        end
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
    if not me or not me:is_valid() or me:is_dead() then
        return
    end
    if not threat_initialized then threat_manager.init(me); threat_initialized = true end
        ooc_manager.on_update(me, menu, utils, {
        group_buffs = {
            { spell_id = resolved.ooc_power_word_fortitude_id,
               buff_ids = spells.BUFF_POWER_WORD_FORT,
               name = "Power Word: Fortitude",
               toggle = menu.ooc_group_buff },
            { spell_id = resolved.ooc_divine_spirit_id,
               buff_ids = spells.BUFF_DIVINE_SPIRIT,
               name = "Divine Spirit",
               toggle = menu.ooc_group_buff },
            { spell_id = resolved.ooc_shadow_protection_id,
               buff_ids = spells.BUFF_SHADOW_PROTECTION,
               name = "Shadow Protection",
               toggle = menu.ooc_group_buff },
        },
    })
    if not me:is_in_combat() then
        return
    end
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

    update_set_bonus(me)

    -- Overheal Protection - cancel slow heals if target is healthy
    if eax_utils.should_stopcasting(me, menu) then
        if SpellStopCasting then SpellStopCasting() end
    end

    -- Interrupt (PVP)
    local target = utils.find_best_target(me)
    if target and target:is_valid() and me:can_attack(target) and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "priest", utils) then
            return
        end
    end


    -- Wanding / mana conservation (leveling 1-70)
    if leveling_manager.try_wand(me, target, menu) then return true end
    if not leveling_manager.has_enough_mana(me, menu) then
        leveling_manager.ensure_melee(me, target)
        return false
    end
    -- Encounter policy (boss-specific rotation adjustments)
    local enc = encounter_manager.get_policy(me)
    -- Mana potion check (proactive mana management)
    if mana_manager.should_use_mana_potion(me, 30) then
        if mana_manager.use_mana_potion() then
            return
        end
    end

    -- Racial CDs
    racial_manager.try_offensive(me)
    racial_manager.try_utility(me, target)
    racial_manager.try_defensive(me)

    -- Defensive abilities
    if defensive_manager.try_defensive(me, "priest", utils) then
        return
    end

    -- Threat fade protection — don't pull aggro from tank
    local current_target = me:get_target()
    local ok, should_fade = pcall(function() return threat_manager.should_fade(me, current_target) end)
    if ok and should_fade then
        pcall(function() threat_manager.try_fade(me) end)
        return
    end

    ttd_tracker.update(target)

    -- Focus Target Priority - heal focus target first
    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target then
        local focus_hp = focus_target:get_health_percentage()
        if focus_hp < menu.shield_threshold:get() then
            if try_cast_spell(me, focus_target, resolved.shield) then
                return
            end
        end
    end

    -- Combat-aware self HP threshold
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_cast_spell(me, me, resolved.shield) then
            return
        end
    end

    local mode = utils.get_effective_mode(menu, runtime)
    log_mode(mode)

    try_power_infusion(me)
    try_pain_suppression(me, mode)
    try_shield(me)
    try_renew(me)
    try_prayer_of_mending(me)
end)


-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxpriestdiscipline_space_win")
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
        local label = "EAX Priest Disc] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxpriestdiscipline_enabled_cp")
        if menu.enabled:get_state() then
        if menu.use_cooldowns then
            local cur_pdi_cds = menu.use_cooldowns:get_state()
            local nxt_pdi_cds = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX PDi] Cooldowns", cur_pdi_cds, 0, false, "eax_pdi_cds_cp")
            if nxt_pdi_cds ~= cur_pdi_cds then menu.use_cooldowns:set(nxt_pdi_cds) end
        end
        if menu.focus_priority then
            local cur_pdi_focus = menu.focus_priority:get_state()
            local nxt_pdi_focus = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX PDi] Focus Priority", cur_pdi_focus, 0, false, "eax_pdi_focus_cp")
            if nxt_pdi_focus ~= cur_pdi_focus then menu.focus_priority:set(nxt_pdi_focus) end
        end
        if menu.use_racial then
            local cur_pdi_racial = menu.use_racial:get_state()
            local nxt_pdi_racial = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX PDi] Use Racial", cur_pdi_racial, 0, false, "eax_pdi_racial_cp")
            if nxt_pdi_racial ~= cur_pdi_racial then menu.use_racial:set(nxt_pdi_racial) end
        end
        end
        return elements
    end)
end

-- -- EAX Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Priest"
    local _eax_spec  = "Discipline"
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


