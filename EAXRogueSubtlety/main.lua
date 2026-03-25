-- EAX Rogue Subtlety | main.lua

local menu = require("menu")
local enums = (function()
    local ok, e = pcall(require, "common/enums")
    return ok and e or nil
end)()
local spells = require("spells")
local utils = require("utils")
local rotation_context = require("rotation_context")
local resource_gate = require("resource_gate")

if not utils.same_unit then
    function utils.same_unit(a, b)
        return a ~= nil and a == b
    end
end
local eax_utils = require("eax_utils")
local color     = require("color")

---@type interrupt_manager
local interrupt_manager = require("interrupt_manager")
---@type ooc_manager
local ooc_manager = require("ooc_manager")
local poison_manager = require("poison_manager")
---@type vendor_automation
local vendor_automation = require("vendor_automation")
---@type consumables_manager
local consumables_manager = require("consumables_manager")
---@type mount_manager
local mount_manager = require("mount_manager")
---@type leveling_manager
local leveling_manager = require("leveling_manager")
---@type encounter_manager
local encounter_manager = require("encounter_manager")


---@type esp_renderer
local esp_renderer = require("esp_renderer")
esp_renderer.init("sub", "Rogue Sub")
-- Smart Cast Manager - addresses spam/sluggishness
local smart_cast_manager = require("smart_cast_manager")

-- Phase 04 visual telemetry wiring
local dps_meter = require("dps_meter")
local cooldown_tracker = require("cooldown_tracker")
local visual_state = require("visual_state")
local reactive_runtime = require("reactive_runtime")
local dps_risk = require("dps_risk")
local dps_runtime = require("dps_runtime")

-- Hot-path local caching (performance critical)
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown
local _get_spell_cd = core.spell_book.get_spell_cooldown

smart_cast_manager.init({
    core_time = _core_time,
    get_gcd = _get_gcd,
    get_spell_cd = _get_spell_cd,
})

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
local POISON_OPTION_KEYS = { "disabled", "instant", "deadly", "wound", "crippling", "mind_numbing" }
local POISON_ITEM_TABLES = {
    instant = spells.POISON_ITEMS_INSTANT,
    deadly = spells.POISON_ITEMS_DEADLY,
    wound = spells.POISON_ITEMS_WOUND,
    crippling = spells.POISON_ITEMS_CRIPPLING,
    mind_numbing = spells.POISON_ITEMS_MIND_NUMBING,
}
local POISON_FALLBACK_ORDER = { "instant", "deadly", "wound", "crippling", "mind_numbing" }

local function build_poison_priority(selected_key)
    if selected_key == "disabled" then
        return nil
    end

    local items = {}
    local seen = {}
    local function append_category(key)
        if seen[key] then
            return
        end
        seen[key] = true
        local item_list = POISON_ITEM_TABLES[key]
        if not item_list then
            return
        end
        for _, item_id in ipairs(item_list) do
            table.insert(items, item_id)
        end
    end

    append_category(selected_key)
    for _, key in ipairs(POISON_FALLBACK_ORDER) do
        append_category(key)
    end

    return #items > 0 and items or nil
end

local function current_poison_loadout()
    local main_idx = menu.main_hand_poison and menu.main_hand_poison:get() or 2
    local off_idx = menu.off_hand_poison and menu.off_hand_poison:get() or 3
    return {
        main_hand_items = build_poison_priority(POISON_OPTION_KEYS[main_idx] or "instant"),
        off_hand_items = build_poison_priority(POISON_OPTION_KEYS[off_idx] or "deadly"),
    }
end
local force_apply_poisons_cp = false

local _visual_on_cast = esp_renderer.on_cast
function esp_renderer.on_cast(spell_id, name, col, target_name)
    if spell_id and core and core.time and core.spell_book and core.spell_book.get_spell_cooldown then
        local now_s = _core_time()
        local cd_s = tonumber(_get_spell_cd(spell_id)) or 0
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

local _visual_tracked_auras = { n = 0 }

local function visual_build_tracked_auras(me, target)
    _visual_tracked_auras.n = 0
    if me and me:is_in_combat() then
        _visual_tracked_auras.n = _visual_tracked_auras.n + 1
        _visual_tracked_auras[_visual_tracked_auras.n] = { label = "Combat", active = true }
    end
    if target and target:is_valid() and not target:is_dead() then
        if target:is_casting_spell() then
            _visual_tracked_auras.n = _visual_tracked_auras.n + 1
            _visual_tracked_auras[_visual_tracked_auras.n] = { label = "Cast", active = true }
        end
        if target:is_channelling_spell() then
            _visual_tracked_auras.n = _visual_tracked_auras.n + 1
            _visual_tracked_auras[_visual_tracked_auras.n] = { label = "Channel", active = true }
        end
    end
    for i = _visual_tracked_auras.n + 1, 4 do
        _visual_tracked_auras[i] = nil
    end
    return _visual_tracked_auras
end

local function visual_update_snapshot(me, target)
    if not me then return end
    local in_combat = me:is_in_combat()
    if in_combat and not _visual_runtime.in_combat then
        dps_meter.on_combat_start()
        _visual_runtime.in_combat = true
        _visual_runtime.last_me_hp_pct = nil
        _visual_runtime.last_target_hp_pct = nil
        smart_cast_manager.clear_all_pending()
    elseif (not in_combat) and _visual_runtime.in_combat then
        dps_meter.on_combat_end()
        _visual_runtime.in_combat = false
        _visual_runtime.last_me_hp_pct = nil
        _visual_runtime.last_target_hp_pct = nil
        smart_cast_manager.reset()
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
        spec = "EAXRogueSubtlety",
    })

    local snapshot = visual_state.build_snapshot({
        now_s = _core_time(),
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
    local me = _get_local_player()
    if not me or me:is_dead() then return end
    local target = me:get_target()
    visual_update_snapshot(me, target)
end)
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
    cloak_id = nil,
    premeditation_id = nil,
    cheap_shot_id = nil,
    ambush_id = nil,
    expose_armor_id = nil,
    backstab_id = nil,
    hemorrhage_id = nil,
    sinister_strike_id = nil,
    slice_and_dice_id = nil,
    rupture_id = nil,
    eviscerate_id = nil,
    shadowstep_id = nil,
    preparation_id = nil,
    vanish_id = nil,
    feint_id = nil,
    combo_points = 0,
    combo_target = nil,
    prev_toggle_state = false,
    last_cast_time = 0,
    cached_mode = "solo",
    set_multiplier = 1.0,
}

local ctx_cache = rotation_context.new({
    important_buffs = {
        slice_and_dice = spells.BUFF_SLICE_AND_DICE,
        stealth = spells.BUFF_STEALTH,
    },
    important_debuffs = {
        rupture = spells.DEBUFF_RUPTURE,
        deadly_poison = spells.DEBUFF_DEADLY_POISON,
    },
})

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
    runtime.expose_armor_id = utils.resolve_spell_id(spells.EXPOSE_ARMOR)
    runtime.backstab_id = utils.resolve_spell_id(spells.BACKSTAB)
    runtime.hemorrhage_id = utils.resolve_spell_id(spells.HEMORRHAGE)
    runtime.sinister_strike_id = utils.resolve_spell_id(spells.SINISTER_STRIKE)
    runtime.slice_and_dice_id = utils.resolve_spell_id(spells.SLICE_AND_DICE)
    runtime.rupture_id = utils.resolve_spell_id(spells.RUPTURE)
    runtime.eviscerate_id = utils.resolve_spell_id(spells.EVISCERATE)
    runtime.shadowstep_id = utils.resolve_spell_id(spells.SHADOWSTEP)
    runtime.preparation_id = utils.resolve_spell_id(spells.PREPARATION)
    runtime.vanish_id = utils.resolve_spell_id(spells.VANISH)
    runtime.feint_id = utils.resolve_spell_id(spells.FEINT)
    runtime.cloak_id = utils.resolve_spell_id({ 31224 })
end

local function log_resolved_spells()
    core.log(
        "[EAX Rogue Subtlety] Resolved: Premed=" .. tostring(runtime.premeditation_id)
            .. " Ambush=" .. tostring(runtime.ambush_id)
            .. " Backstab=" .. tostring(runtime.backstab_id)
            .. " Hemo=" .. tostring(runtime.hemorrhage_id)
            .. " SS=" .. tostring(runtime.sinister_strike_id)
    )
end

resolve_spells()
log_resolved_spells()

local subtlety_rotation_suspended_logged = false

local function is_subtlety_rotation_available()
    local available = runtime.hemorrhage_id ~= nil or runtime.premeditation_id ~= nil or runtime.shadowstep_id ~= nil
    if not available and not subtlety_rotation_suspended_logged then
        subtlety_rotation_suspended_logged = true
        core.log("[EAX Rogue Subtlety] No Subtlety signature talent spell detected; suspending Subtlety rotation to avoid off-spec conflicts.")
    end
    return available
end

local function note_cast()
    runtime.last_cast_time = _core_time()
end

local function invalidate_ctx()
    rotation_context.invalidate(ctx_cache)
end

local function is_gcd_ready()
    return smart_cast_manager.is_gcd_ready()
end

local function is_pending_cast(spell_id)
    if not spell_id then return false end
    return smart_cast_manager.is_pending(spell_id)
end

local function mark_pending_cast(spell_id, timeout_s, options)
    if not spell_id then return end
    options = options or {}
    smart_cast_manager.on_cast_attempt(spell_id, options.action_key or "unknown", {
        triggers_gcd = true,
        category = options.category,
        cast_time = options.cast_time,
    })
end

-- Intelligent throttling for specific ability categories
local function should_throttle_dot(action_key)
    return smart_cast_manager.should_throttle(action_key, "dots")
end
local function should_throttle_filler(action_key)
    return smart_cast_manager.should_throttle(action_key, "filler")
end
local function should_throttle_aoe(action_key)
    return smart_cast_manager.should_throttle(action_key, "aoe")
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
local function get_current_combo_points(me)
    if not me then
        return nil
    end

    if enums and enums.power_type and enums.power_type.COMBOPOINTS_TBC ~= nil then
        local ok1, v1 = pcall(function() return me:get_power(enums.power_type.COMBOPOINTS_TBC) end)
        if ok1 and type(v1) == "number" and v1 >= 0 then
            return v1
        end
    end

    if enums and enums.power_type and enums.power_type.COMBOPOINTS ~= nil then
        local ok2, v2 = pcall(function() return me:get_power(enums.power_type.COMBOPOINTS) end)
        if ok2 and type(v2) == "number" and v2 >= 0 then
            return v2
        end
    end

    if type(me.combo_points_current) == "function" then
        local ok3, v3 = pcall(function() return me:combo_points_current() end)
        if ok3 and type(v3) == "number" and v3 >= 0 then
            return v3
        end
    end

    return nil
end


local function track_target(me, target)
    local cp = get_current_combo_points(me)
    if cp == nil then return end

    runtime.combo_points = math.max(0, math.min(SUB_FINISHER_COMBO_POINTS, cp))
    runtime.combo_target = (runtime.combo_points > 0 and target and target:is_valid()) and target or nil
end

local function get_snd_refresh_window_ms()
    local refresh_seconds = menu.snd_refresh_seconds and menu.snd_refresh_seconds:get() or 3
    return math.max(SND_REFRESH_CRITICAL_MS, refresh_seconds * 1000)
end

local function is_stealthed(me)
    return utils.has_buff(me, spells.BUFF_STEALTH)
end

local function should_use_cheap_shot()
    return current_mode() == "solo"
end

local function try_premeditation(me, target)
    if not menu.use_premeditation:get_state() then
        return false
    end
    if current_mode() ~= "solo" then
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

local function try_cheap_shot(me, target, ctx)
    if not menu.use_cheap_shot:get_state() or not should_use_cheap_shot() then
        return false
    end
    if not runtime.cheap_shot_id or not is_stealthed(me) or not utils.can_attack(me, target) then
        return false
    end
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_CHEAP_SHOT) > 0 then
        return false
    end
    if ctx then
        local can_cast = resource_gate.rogue.can_builder(ctx, 40, runtime.combo_points, 5)
        if not can_cast then
            return false
        end
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

local function try_ambush(me, target, ctx)
    if not menu.use_ambush:get_state() then
        return false
    end
    if current_mode() ~= "solo" then
        return false
    end
    if not runtime.ambush_id or not is_stealthed(me) or not utils.can_attack(me, target) then
        return false
    end
    if ctx then
        local can_cast = resource_gate.rogue.can_builder(ctx, 70, runtime.combo_points, 5)
        if not can_cast then
            return false
        end
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

local function try_slice_and_dice(me, target, ctx)
    if not menu.use_slice_and_dice:get_state() then
        return false
    end
    if not runtime.slice_and_dice_id or runtime.combo_points <= 0 or not utils.can_attack(me, target) then
        return false
    end

    local remaining_ms = utils.get_buff_remaining_ms(me, spells.BUFF_SLICE_AND_DICE)
    local refresh_window_ms = get_snd_refresh_window_ms()
    if remaining_ms > SND_CLIP_GUARD_MS then
        return false
    end
    if remaining_ms > refresh_window_ms and remaining_ms > 0 then
        return false
    end

    local policy = encounter_manager.get_policy(me)
    local enemy_count = encounter_manager.enemy_count_in_range(me, 8)
    local expose_assigned = menu.use_expose_armor and menu.use_expose_armor:get_state()
    local expose_missing = expose_assigned and runtime.expose_armor_id and not utils.has_debuff(target, spells.DEBUFF_EXPOSE_ARMOR) and not utils.has_debuff(target, spells.DEBUFF_SUNDER_ARMOR)
    if expose_missing and current_mode() ~= "solo" and runtime.combo_points >= 1 then
        return false
    end
    local regular_min_combo_points = math.min(menu.finisher_combo_points:get(), 3)
    if enemy_count >= 2 or (policy and policy.burn_phase) then
        regular_min_combo_points = 2
    end
    local min_combo_points = remaining_ms > 0 and regular_min_combo_points or 2
    if runtime.combo_points < min_combo_points or runtime.combo_points > SUB_FINISHER_COMBO_POINTS then
        return false
    end
    if ctx then
        local can_cast = resource_gate.rogue.can_finisher(ctx, 25, runtime.combo_points, min_combo_points)
        if not can_cast then
            return false
        end
    end
    if not utils.can_cast_target(runtime.slice_and_dice_id, me, target) then
        return false
    end

    if utils.cast_target(runtime.slice_and_dice_id, target, "Slice and Dice") then
        utils.log_debug(menu, "Slice and Dice")
        note_cast()
        return true
    end

    return false
end

local function try_expose_armor(me, target, ctx)
    if not menu.use_expose_armor:get_state() then
        return false
    end
    if current_mode() == "solo" then
        return false
    end
    if not runtime.expose_armor_id or not utils.can_attack(me, target) then
        return false
    end
    if runtime.combo_points < SUB_FINISHER_COMBO_POINTS then
        return false
    end
    if utils.has_debuff(target, spells.DEBUFF_EXPOSE_ARMOR) or utils.has_debuff(target, spells.DEBUFF_SUNDER_ARMOR) then
        return false
    end
    if ctx then
        local can_cast = resource_gate.rogue.can_finisher(ctx, 25, runtime.combo_points, SUB_FINISHER_COMBO_POINTS)
        if not can_cast then
            return false
        end
    end
    if not utils.can_cast_hostile(runtime.expose_armor_id, me, target) then
        return false
    end
    if utils.cast_target(runtime.expose_armor_id, target, "Expose Armor") then
        utils.log_debug(menu, "Expose Armor")
        note_cast()
        return true
    end
    return false
end

local function try_rupture(me, target, ctx)
    if not menu.use_rupture:get_state() then
        return false
    end
    if not runtime.rupture_id or not utils.can_attack(me, target) then
        return false
    end
    local min_combo_points = menu.finisher_combo_points:get()
    if runtime.combo_points < min_combo_points then
        return false
    end
    if ctx then
        local can_cast = resource_gate.rogue.can_finisher(ctx, 25, runtime.combo_points, min_combo_points)
        if not can_cast then
            return false
        end
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

local function try_eviscerate(me, target, ctx)
    if not menu.use_eviscerate:get_state() then
        return false
    end
    if not runtime.eviscerate_id or not utils.can_attack(me, target) then
        return false
    end
    if runtime.combo_points < menu.finisher_combo_points:get() then
        return false
    end
    if ctx then
        local can_cast = resource_gate.rogue.can_finisher(ctx, 35, runtime.combo_points, 4)
        if not can_cast then
            return false
        end
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

local function try_backstab(me, target, ctx)
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
    if ctx then
        local can_cast = resource_gate.rogue.can_builder(ctx, 60, runtime.combo_points, 5)
        if not can_cast then
            return false
        end
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

local function try_hemorrhage(me, target, ctx)
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
    if ctx then
        local can_cast = resource_gate.rogue.can_builder(ctx, 35, runtime.combo_points, 5)
        if not can_cast then
            return false
        end
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

local function try_sinister_strike(me, target, ctx)
    if not runtime.sinister_strike_id or not utils.can_attack(me, target) then
        return false
    end
    if runtime.combo_points >= SUB_FINISHER_COMBO_POINTS then
        return false
    end
    if ctx then
        local can_cast = resource_gate.rogue.can_builder(ctx, 45, runtime.combo_points, SUB_FINISHER_COMBO_POINTS)
        if not can_cast then
            return false
        end
    end
    if not utils.can_cast_hostile(runtime.sinister_strike_id, me, target) then
        return false
    end

    if utils.cast_target(runtime.sinister_strike_id, target, "Sinister Strike") then
        utils.log_debug(menu, "Sinister Strike")
        note_cast()
        esp_renderer.on_cast(runtime.sinister_strike_id, "Sinister Strike", color.yellow(220))
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
    if not utils.can_cast_self(runtime.feint_id, me) then return false end
    if utils.cast_self(runtime.feint_id, me, "Feint") then
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

    local deps = { now_s = _core_time, get_gcd = _get_gcd }
    local ctx = rotation_context.get(ctx_cache, me, target, deps)

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
    local hold_offense = dps_risk.should_hold_offense(dps_runtime.build_snapshot(me, target, encounter_manager, ttd_tracker))
    if not hold_offense then
        racial_manager.try_offensive(me)
    end
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
        if not hold_offense and try_premeditation(me, target) then
            invalidate_ctx()
            return true
        end
        if try_cheap_shot(me, target, ctx) then
            invalidate_ctx()
            return true
        end
        if try_ambush(me, target, ctx) then
            invalidate_ctx()
            return true
        end
    end

    if try_expose_armor(me, target, ctx) then invalidate_ctx() return true end
    if try_slice_and_dice(me, target, ctx) then invalidate_ctx() return true end
    if try_feint(me) then invalidate_ctx() return true end
    if try_rupture(me, target, ctx) then
        invalidate_ctx()
        return true
    end
    if try_eviscerate(me, target, ctx) then
        invalidate_ctx()
        return true
    end
    if try_backstab(me, target, ctx) then
        invalidate_ctx()
        return true
    end
    if try_hemorrhage(me, target, ctx) then
        invalidate_ctx()
        return true
    end
    if try_sinister_strike(me, target, ctx) then
        invalidate_ctx()
        return true
    end

    if try_shadowstep(me, target) then
        invalidate_ctx()
        return true
    end
    if try_preparation(me) then
        invalidate_ctx()
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

reactive_adapter = {
    spec = "EAXRogueSubtlety",
    actions = {
        life_save_self = {
            handler = function(_, action_deps)
                return defensive_manager.try_defensive(action_deps.me, "rogue", utils)
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

                return interrupt_manager.try_interrupt(action_deps.me, interrupt_target, "rogue", utils)
            end,
        },
        anti_overheal = { noop = "unsupported" },
        anti_aggro = {
            handler = function(_, action_deps)
                local snapshot = dps_runtime.build_snapshot(action_deps.me, action_deps.current_target, encounter_manager, ttd_tracker)
                if not dps_risk.should_drop_threat(snapshot) then
                    return false
                end
                return try_feint and try_feint(action_deps.me) or false
            end,
        },
        throughput_resume = { noop = "unsupported" },
    },
}

local function on_render()
    esp_renderer.on_render(menu)
end

local CP_BUILDERS = {}
local CP_FINISHERS = {}

local function register_cp_spell_set(dst, spell_list)
    if not spell_list then
        return
    end
    for _, id in ipairs(spell_list) do
        dst[id] = true
    end
end

local function build_cp_spell_sets()
    register_cp_spell_set(CP_BUILDERS, spells.PREMEDITATION)
    register_cp_spell_set(CP_BUILDERS, spells.CHEAP_SHOT)
    register_cp_spell_set(CP_BUILDERS, spells.AMBUSH)
    register_cp_spell_set(CP_BUILDERS, spells.BACKSTAB)
    register_cp_spell_set(CP_BUILDERS, spells.HEMORRHAGE)
    register_cp_spell_set(CP_BUILDERS, spells.SINISTER_STRIKE)
    register_cp_spell_set(CP_FINISHERS, spells.SLICE_AND_DICE)
    register_cp_spell_set(CP_FINISHERS, spells.RUPTURE)
    register_cp_spell_set(CP_FINISHERS, spells.EVISCERATE)
end

build_cp_spell_sets()

local _last_cp_event_at = 0
local CP_EVENT_DEDUP_WINDOW_S = 0.15

local function get_builder_combo_gain(spell_id)
    if runtime.premeditation_id and spell_id == runtime.premeditation_id then
        return 2
    end
    return 1
end

local function on_spell_cast(data)
    if not data or not data.spell_id then return end

    local me = _get_local_player()
    if not me then return end
    if data.caster and data.caster:is_valid() and not utils.same_unit(data.caster, me) then
        return
    end

    local sid = data.spell_id
    if not CP_BUILDERS[sid] and not CP_FINISHERS[sid] then
        return
    end

    local now = _core_time()
    if (now - _last_cp_event_at) < CP_EVENT_DEDUP_WINDOW_S then
        return
    end
    _last_cp_event_at = now

    if CP_BUILDERS[sid] then
        local api_cp = get_current_combo_points(me)
        if api_cp ~= nil then
            runtime.combo_points = math.max(0, math.min(SUB_FINISHER_COMBO_POINTS, api_cp))
        else
            runtime.combo_points = math.min(SUB_FINISHER_COMBO_POINTS, runtime.combo_points + get_builder_combo_gain(sid))
        end
        if data.target and data.target:is_valid() then
            runtime.combo_target = data.target
        end
        return
    end

    runtime.combo_points = 0
    runtime.combo_target = nil
end

core.register_on_spell_cast_callback(on_spell_cast)

-- ESP only renders when this spec is enabled
core.register_on_render_callback(function()
    if not menu or not menu.enabled or not menu.enabled:get_state() then return end
    on_render()
end)
-- __EAX_ESP_GUARD
core.register_on_update_callback(function()
    if (not runtime.backstab_id or not runtime.hemorrhage_id) and utils.throttle("sub_spell_resolve", 2.0) then
        resolve_spells()
    end
    if utils.throttle("mode_refresh", 2.0) then
        runtime.cached_mode = current_mode()
    end

    if utils.throttle("set_bonus_check", 5.0) then
        local me = _get_local_player()
        if me then
            update_set_bonus(me)
        end
    end

    handle_toggle()
    if not menu.enabled:get_state() then
        return
    end

    local me = _get_local_player()
    if not me or me:is_dead() then
        return
    end
    if force_apply_poisons_cp then
        poison_manager.force_reapply()
        force_apply_poisons_cp = false
        core.log("[EAX Rogue Subtlety] Force reapply poisons requested")
    end
    if poison_manager.try_apply_poisons(me, menu, utils, current_poison_loadout()) then
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
        local now = _core_time()
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
