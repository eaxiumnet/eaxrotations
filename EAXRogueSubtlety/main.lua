-- EAX Rogue Subtlety | main.lua

local menu = require("menu")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")

---@type interrupt_manager
local interrupt_manager = require("interrupt_manager")
---@type ooc_manager
local ooc_manager = require("ooc_manager")
---@type leveling_manager
local leveling_manager = require("leveling_manager")
---@type encounter_manager
local encounter_manager = require("encounter_manager")


---@type esp_renderer
local esp_renderer = require("esp_renderer")
esp_renderer.init("subtlety")
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

local runtime = {
    premeditation_id = nil,
    cheap_shot_id = nil,
    ambush_id = nil,
    backstab_id = nil,
    hemorrhage_id = nil,
    slice_and_dice_id = nil,
    rupture_id = nil,
    eviscerate_id = nil,
    shadowstep_id = nil,
    preparation_id = nil,
    vanish_id = nil,
    combo_points = 0,
    combo_target = nil,
    prev_toggle_state = false,
    last_cast_time = 0,
    cached_mode = "solo",
    set_multiplier = 1.0,
}

local GCD_CAST_INTERVAL = 1.0  -- TBC GCD

local function resolve_spells()
    runtime.premeditation_id = utils.resolve_spell_id(spells.PREMEDITATION)
    runtime.cheap_shot_id = utils.resolve_spell_id(spells.CHEAP_SHOT)
    runtime.ambush_id = utils.resolve_spell_id(spells.AMBUSH)
    runtime.backstab_id = utils.resolve_spell_id(spells.BACKSTAB)
    runtime.hemorrhage_id = utils.resolve_spell_id(spells.HEMORRHAGE)
    runtime.slice_and_dice_id = utils.resolve_spell_id(spells.SLICE_AND_DICE)
    runtime.rupture_id = utils.resolve_spell_id(spells.RUPTURE)
    runtime.eviscerate_id = utils.resolve_spell_id(spells.EVISCERATE)
    runtime.shadowstep_id = utils.resolve_spell_id(spells.SHADOWSTEP)
    runtime.preparation_id = utils.resolve_spell_id(spells.PREPARATION)
    runtime.vanish_id = utils.resolve_spell_id(spells.VANISH)
end

local function log_resolved_spells()
    core.log(
        "[EAX Rogue Subtlety] Resolved: Premed=" .. tostring(runtime.premeditation_id)
            .. " Ambush=" .. tostring(runtime.ambush_id)
            .. " Backstab=" .. tostring(runtime.backstab_id)
            .. " Hemo=" .. tostring(runtime.hemorrhage_id)
    )
end

resolve_spells()
log_resolved_spells()

local function note_cast()
    runtime.last_cast_time = core.time()
end

local function is_gcd_ready()
    if (core.time() - runtime.last_cast_time) < GCD_CAST_INTERVAL then
        return false
    end

    return core.spell_book.get_global_cooldown() <= 0
end

local function current_mode()
    return utils.get_selected_mode(menu)
end

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        menu.enabled:set(not menu.enabled:get_state())
    end
    runtime.prev_toggle_state = current
end

local function track_target(target)
    if not target or not target:is_valid() then
        runtime.combo_points = 0
        runtime.combo_target = nil
        return
    end

    if runtime.combo_target and runtime.combo_target ~= target then
        runtime.combo_points = 0
    end

    runtime.combo_target = target
end

local function is_stealthed(me)
    return utils.has_buff(me, spells.BUFF_STEALTH)
end

local function should_use_cheap_shot()
    local mode = current_mode()
    return mode == "dungeon" or mode == "raid"
end

local function try_premeditation(me, target)
    if not menu.use_premeditation:get_state() then
        return false
    end
    if not runtime.premeditation_id or not is_stealthed(me) or not utils.can_attack(me, target) then
        return false
    end
    if runtime.combo_points > 0 then
        return false
    end
    if not utils.can_cast_self(runtime.premeditation_id, me) then
        return false
    end

    if utils.cast_self(runtime.premeditation_id, me, "Premeditation") then
        utils.log_debug(menu, "Premeditation")
        note_cast()
        runtime.combo_points = math.min(runtime.combo_points + 2, 5)
        runtime.combo_target = target
        return true
    end

    return false
end

local function try_cheap_shot(me, target)
    if not menu.use_cheap_shot:get_state() or not should_use_cheap_shot() then
        return false
    end
    if not runtime.cheap_shot_id or not is_stealthed(me) or not utils.can_attack(me, target) then
        return false
    end
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_CHEAP_SHOT) > 0 then
        return false
    end
    if not utils.can_cast_target(runtime.cheap_shot_id, me, target) then
        return false
    end

    if utils.cast_target(runtime.cheap_shot_id, target, "Cheap Shot") then
        utils.log_debug(menu, "Cheap Shot")
        note_cast()
        return true
    end

    return false
end

local function try_ambush(me, target)
    if not menu.use_ambush:get_state() then
        return false
    end
    if not runtime.ambush_id or not is_stealthed(me) or not utils.can_attack(me, target) then
        return false
    end
    if not utils.can_cast_target(runtime.ambush_id, me, target) then
        return false
    end

    if utils.cast_target(runtime.ambush_id, target, "Ambush") then
        utils.log_debug(menu, "Ambush")
        note_cast()
        return true
    end

    return false
end

local function try_shadowstep(me, target)
    if not menu.use_shadowstep:get_state() then
        return false
    end
    if not runtime.shadowstep_id or not utils.can_attack(me, target) then
        return false
    end
    if current_mode() == "solo" then
        return false
    end
    if utils.can_cast_target(runtime.backstab_id, me, target) then
        return false
    end
    if not utils.can_cast_target(runtime.shadowstep_id, me, target) then
        return false
    end

    if utils.cast_target_fast(runtime.shadowstep_id, target, "Shadowstep") then
        utils.log_debug(menu, "Shadowstep")
        note_cast()
        return true
    end

    return false
end

local function try_preparation(me)
    if not menu.use_preparation:get_state() then
        return false
    end
    if not runtime.preparation_id or current_mode() ~= "raid" then
        return false
    end
    if not me:is_in_combat() or runtime.combo_points < 4 then
        return false
    end
    if not utils.can_cast_self(runtime.preparation_id, me) then
        return false
    end

    if utils.cast_self_fast(runtime.preparation_id, me, "Preparation") then
        utils.log_debug(menu, "Preparation")
        note_cast()
        return true
    end

    return false
end

local function try_slice_and_dice(me)
    if not menu.use_slice_and_dice:get_state() then
        return false
    end
    if not runtime.slice_and_dice_id or runtime.combo_points <= 0 then
        return false
    end

    local remaining_ms = utils.get_buff_remaining_ms(me, spells.BUFF_SLICE_AND_DICE)
    if remaining_ms > (menu.snd_refresh_seconds:get() * 1000) then
        return false
    end
    if not utils.can_cast_self(runtime.slice_and_dice_id, me) then
        return false
    end

    if utils.cast_self(runtime.slice_and_dice_id, me, "Slice and Dice") then
        utils.log_debug(menu, "Slice and Dice")
        note_cast()
        return true
    end

    return false
end

local function try_rupture(me, target)
    if not menu.use_rupture:get_state() then
        return false
    end
    if not runtime.rupture_id or not utils.can_attack(me, target) then
        return false
    end
    if runtime.combo_points < menu.finisher_combo_points:get() then
        return false
    end
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_RUPTURE) > 3000 then return false end
    -- TTD gate: don't Rupture if fight ending before it expires (v1.3)
    if ttd_tracker.get(target) < 12 then return false end
    if not utils.can_cast_target(runtime.rupture_id, me, target) then
        return false
    end

    if utils.cast_target(runtime.rupture_id, target, "Rupture") then
        utils.log_debug(menu, "Rupture")
        note_cast()
        return true
    end

    return false
end

local function try_eviscerate(me, target)
    if not menu.use_eviscerate:get_state() then
        return false
    end
    if not runtime.eviscerate_id or not utils.can_attack(me, target) then
        return false
    end
    if runtime.combo_points < menu.finisher_combo_points:get() then
        return false
    end
    if utils.get_buff_remaining_ms(me, spells.BUFF_SLICE_AND_DICE) < 2000 then
        return false
    end
    if not utils.can_cast_target(runtime.eviscerate_id, me, target) then
        return false
    end

    if utils.cast_target(runtime.eviscerate_id, target, "Eviscerate") then
        utils.log_debug(menu, "Eviscerate")
        note_cast()
        return true
    end

    return false
end

local function try_backstab(me, target)
    if not menu.use_backstab:get_state() then
        return false
    end
    if not runtime.backstab_id or not utils.can_attack(me, target) then
        return false
    end
    if runtime.combo_points >= 5 then
        return false
    end
    if not utils.can_cast_target(runtime.backstab_id, me, target) then
        return false
    end

    if utils.cast_target(runtime.backstab_id, target, "Backstab") then
        utils.log_debug(menu, "Backstab")
        note_cast()
                esp_renderer.on_cast(runtime.backstab_id, "Backstab", color.purple(220))
        return true
    end

    return false
end

local function try_hemorrhage(me, target)
    if not menu.use_hemorrhage:get_state() then
        return false
    end
    if not runtime.hemorrhage_id or not utils.can_attack(me, target) then
        return false
    end
    if runtime.combo_points >= 5 then
        return false
    end
    if not utils.can_cast_target(runtime.hemorrhage_id, me, target) then
        return false
    end

    if utils.cast_target(runtime.hemorrhage_id, target, "Hemorrhage") then
        utils.log_debug(menu, "Hemorrhage")
        note_cast()
                esp_renderer.on_cast(runtime.hemorrhage_id, "Hemorrhage", color.red(220))
        return true
    end

    return false
end


-- ─── Feint — threat drop (v1.3) ──────────────────────────────────────────

local function try_feint(me)
    if not menu.use_feint or not menu.use_feint:get_state() then return false end
    if not runtime.feint_id then return false end
    local mode = utils.get_selected_mode and utils.get_selected_mode(menu) or "solo"
    if mode == "solo" then return false end
    if not utils.can_cast_target(runtime.feint_id, me, me:get_target()) then return false end
    if utils.cast_target(runtime.feint_id, me:get_target(), "Feint") then
        utils.log_debug(menu, "Feint")
        return true
    end
    return false
end


local function do_rotation(me, target)
    if not is_gcd_ready() then
        return false
    end
    if not utils.can_attack(me, target) then
        return false
    end

    -- Interrupt
    -- Interrupt
    if target and interrupt_manager
    -- Encounter policy (boss-specific rotation adjustments)
    local enc = encounter_manager.get_policy(me)
.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "rogue", utils) then
            return true
        end
    end

    -- Racial CDs
    racial_manager.try_offensive(me)
    racial_manager.try_utility(me, target)

    -- Defensive abilities
    ttd_tracker.update(target)

    if defensive_manager.try_defensive(me, "rogue", utils) then
        return true
    end

    track_target(target)

    if is_stealthed(me) then
        if try_premeditation(me, target) then
            return true
        end
        if try_cheap_shot(me, target) then
            return true
        end
        if try_ambush(me, target) then
            return true
        end
    end

    if try_shadowstep(me, target) then
        return true
    end
    if try_slice_and_dice(me) then return true end
    if try_feint(me) then return true end
    if try_preparation(me) then
        return true
    end
    if try_rupture(me, target) then
        return true
    end
    if try_eviscerate(me, target) then
        return true
    end
    if try_backstab(me, target) then
        return true
    end
    if try_hemorrhage(me, target) then
        return true
    end

    -- Auto-attack fallback for leveling 1-70
    -- (ensure_melee_auto_attack is called in the core combat lanes above)

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
    if utils.throttle("mode_refresh", 2.0) then
        runtime.cached_mode = current_mode()
    end

    if utils.throttle("set_bonus_check", 5.0) then
        local me = core.object_manager.get_local_player()
        if me then
            update_set_bonus(me)
        end
    end

    handle_toggle()
    if not menu.enabled:get_state() then
        return
    end

    local me = core.object_manager.get_local_player()
    if not me or me:is_dead() then
        return
    end
    if eax_utils.is_eating_or_drinking(me) then return end

    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    local target = focus_target or me:get_target()

    do_rotation(me, target)
end)

local function update_set_bonus(me)
    local max_mult = 1.0
    local sets = { "Deathmantle", "DeathmantleBattlegear", "Terror" }
    for _, set_name in ipairs(sets) do
        local mult = utils.get_set_multiplier(me, set_name)
        if mult > max_mult then
            max_mult = mult
        end
    end
    runtime.set_multiplier = max_mult
end


-- ── Space theme: create menu window and inject into menu ─────────────────────
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxroguesubtlety_space_win")
_space_win:set_initial_size(_vec2.new(460, 580))
_space_win:set_next_window_min_size(_vec2.new(320, 300))
_space_win:set_next_window_padding(_vec2.new(10, 8))
menu.set_window(_space_win)
-- ─────────────────────────────────────────────────────────────────────────────
core.register_on_render_menu_callback(function()
    menu.render()
end)

core.register_on_render_control_panel_callback(function()
    local elements = {}
    local key_name = key_helper:get_key_name(menu.toggle_key:get_key_code())
    control_panel_utility:insert_toggle_(elements, "[EAX Rogue Subtlety] Enable (" .. key_name .. ")", menu.toggle_key)
    return elements
end)

core.register_on_spell_cast_callback(function(data)
    if not data or not data.spell_id then
        return
    end

    if data.spell_id == runtime.premeditation_id then
        runtime.combo_points = math.min(runtime.combo_points + 2, 5)
    elseif data.spell_id == runtime.cheap_shot_id then
        runtime.combo_points = math.min(runtime.combo_points + 2, 5)
        runtime.combo_target = data.target or runtime.combo_target
    elseif data.spell_id == runtime.ambush_id
        or data.spell_id == runtime.backstab_id
        or data.spell_id == runtime.hemorrhage_id then
        runtime.combo_points = math.min(runtime.combo_points + 1, 5)
        runtime.combo_target = data.target or runtime.combo_target
    elseif data.spell_id == runtime.slice_and_dice_id
        or data.spell_id == runtime.rupture_id
        or data.spell_id == runtime.eviscerate_id then
        runtime.combo_points = 0
        runtime.combo_target = data.target or runtime.combo_target
    end
end)



-- ── EAX Conflict Detection ─────────────────────────────────────────────────
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Rogue"
    local _eax_spec  = "Subtlety"
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

core.log("[EAX Rogue Subtlety] Loaded v1.0.0")
