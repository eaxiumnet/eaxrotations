-- EAX Rogue Subtlety | main.lua

local menu = require("menu")
local enums = (function()
    local ok, e = pcall(require, "common/enums")
    return ok and e or nil
end)()
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
---@type encounter_manager
local encounter_manager = require("common/eax_shared/encounter_manager")


---@type esp_renderer
local esp_renderer = require("esp_renderer")
esp_renderer.init("sub", "Rogue Sub")


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

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local runtime = {
    cloak_id = nil,
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
local SUB_FINISHER_COMBO_POINTS = 5
local SND_REFRESH_CRITICAL_MS = 2000
local SND_CLIP_GUARD_MS = 10000

local function is_behind_target(me, target)
    return encounter_manager.is_target_behind(me, target)
end

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
    runtime.cloak_id = utils.resolve_spell_id({ 31224 })
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

-- Read combo points using native game_object API on ME (the player).
-- Key fix: get_power() must be called on the PLAYER, not on cp_obj (the target mob).
-- Calling it on cp_obj always returned 0 because mobs have no combo points.
local function get_current_combo_points(me, target)
    -- Method 1: native game_object API, TBC-specific power type
    local ok1, v1 = pcall(function() return me:get_power(enums.power_type.COMBOPOINTS_TBC) end)
    if ok1 and type(v1) == "number" and v1 > 0 then return v1 end

    -- Method 2: native game_object API, retail enum fallback (COMBOPOINTS = 4)
    local ok2, v2 = pcall(function() return me:get_power(enums.power_type.COMBOPOINTS) end)
    if ok2 and type(v2) == "number" and v2 > 0 then return v2 end

    return nil  -- all failed, keep cast-callback count
end


local function track_target(me, target)
    -- Read combo points directly from the API every tick via izi_sdk.
    local cp = get_current_combo_points(me, target)
    if cp == nil then return end  -- API bug, keep existing count

    -- Confirm CPs are on the current target, not a previous one
    local cp_target_ok, cp_target = pcall(function() return me:get_combo_points_target() end)
    if cp_target_ok and cp_target and cp_target:is_valid() then
        if target and not utils.same_unit(cp_target, target) then
            cp = 0
        end
    end

    runtime.combo_points = cp or 0
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
        -- combo_points will be updated from API on next tick
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
    if not utils.can_cast_hostile(runtime.cheap_shot_id, me, target) then
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
    if not utils.can_cast_hostile(runtime.ambush_id, me, target) then
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
    if is_behind_target(me, target) then
        return false
    end
    if not utils.can_cast_hostile(runtime.shadowstep_id, me, target) then
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
    if not runtime.preparation_id then
        return false
    end
    if not me:is_in_combat() then
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

    local policy = encounter_manager.get_policy(me)
    local enemy_count = encounter_manager.enemy_count_in_range(me, 8)
    local min_combo_points = (enemy_count >= 2 or (policy and policy.burn_phase)) and 3 or 4
    if runtime.combo_points < min_combo_points or runtime.combo_points > SUB_FINISHER_COMBO_POINTS then
        return false
    end

    local remaining_ms = utils.get_buff_remaining_ms(me, spells.BUFF_SLICE_AND_DICE)
    if remaining_ms > SND_CLIP_GUARD_MS then
        return false
    end
    if remaining_ms > SND_REFRESH_CRITICAL_MS and remaining_ms > 0 then
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
    if not utils.can_cast_hostile(runtime.rupture_id, me, target) then
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
    if not utils.can_cast_hostile(runtime.eviscerate_id, me, target) then
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
    if runtime.combo_points >= SUB_FINISHER_COMBO_POINTS then
        return false
    end
    if not is_behind_target(me, target) then
        return false
    end
    if not utils.can_cast_hostile(runtime.backstab_id, me, target) then
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
    if runtime.combo_points >= SUB_FINISHER_COMBO_POINTS then
        return false
    end
    if is_behind_target(me, target) then
        return false
    end
    if not utils.can_cast_hostile(runtime.hemorrhage_id, me, target) then
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


-- --- Feint - threat drop (v1.3) ------------------------------------------

local function try_feint(me)
    if not menu.use_feint or not menu.use_feint:get_state() then return false end
    if not runtime.feint_id then return false end
    local mode = utils.get_selected_mode and utils.get_selected_mode(menu) or "solo"
    if mode == "solo" then return false end
    if not utils.can_cast_hostile(runtime.feint_id, me, me:get_target()) then return false end
    if utils.cast_target(runtime.feint_id, me:get_target(), "Feint") then
        utils.log_debug(menu, "Feint")
        return true
    end
    return false
end


local function try_cloak_of_shadows(me)
    if not menu.use_cloak or not menu.use_cloak:get_state() then return false end
    if not runtime.cloak_id then return false end
    local hp = me:get_health_percentage() / 100
    local threshold = menu.use_cloak_hp_pct and (menu.use_cloak_hp_pct:get() / 100) or 0.60
    if hp > threshold then return false end
    if not utils.can_cast_self(runtime.cloak_id, me) then return false end
    if utils.cast_self(runtime.cloak_id, me) then
        utils.log_debug(menu, "Cloak of Shadows")
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
    local enc = encounter_manager.get_policy(me)
    if target and interrupt_manager.should_interrupt(target) and not enc.hold_cooldowns then
        if interrupt_manager.try_interrupt(me, target, "rogue", utils) then
            return true
        end
    end

    -- Racial CDs
    racial_manager.try_offensive(me)
    racial_manager.try_utility(me, target)
    racial_manager.try_defensive(me)

    -- Defensive abilities
    ttd_tracker.update(target)

    if try_cloak_of_shadows(me) then return true end
    if defensive_manager.try_defensive(me, "rogue", utils) then
        return true
    end

    track_target(me, target)

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
        ooc_manager.on_update(me, menu, utils)
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

    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    -- Validate focus target is hostile; if not, fall through to smart selector
    if focus_target and not me:can_attack(focus_target) then focus_target = nil end
    -- Smart target selection: prioritize units actively fighting us/party
    local target = focus_target or utils.find_best_target(me)

    do_rotation(me, target)
end)



-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxroguesubtlety_space_win")
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
        local label = "EAX Rogue Sub] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxroguesubtlety_enabled_cp")
        if menu.enabled:get_state() then
        if menu.use_cooldowns then
            local cur_rsu_cds = menu.use_cooldowns:get_state()
            local nxt_rsu_cds = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX RSu] Cooldowns", cur_rsu_cds, 0, false, "eax_rsu_cds_cp")
            if nxt_rsu_cds ~= cur_rsu_cds then menu.use_cooldowns:set(nxt_rsu_cds) end
        end
        if menu.focus_priority then
            local cur_rsu_focus = menu.focus_priority:get_state()
            local nxt_rsu_focus = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX RSu] Focus Priority", cur_rsu_focus, 0, false, "eax_rsu_focus_cp")
            if nxt_rsu_focus ~= cur_rsu_focus then menu.focus_priority:set(nxt_rsu_focus) end
        end
        if menu.use_racial then
            local cur_rsu_racial = menu.use_racial:get_state()
            local nxt_rsu_racial = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX RSu] Use Racial", cur_rsu_racial, 0, false, "eax_rsu_racial_cp")
            if nxt_rsu_racial ~= cur_rsu_racial then menu.use_racial:set(nxt_rsu_racial) end
        end
        end
        return elements
    end)
end


-- -- EAX Conflict Detection -------------------------------------------------
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

local _pi = pcall(require, "plugin_info") and require("plugin_info") or nil
core.log("[EAX Rogue Subtlety] Loaded " .. (_pi and _pi.plugin_version or "?"))
