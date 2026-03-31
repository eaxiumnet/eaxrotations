-- Eax Druid Balance | main.lua
-- Callback registration, mode handling, and balance rotation logic.

local menu = require("libraries/menu")
local rotation_context = require("libraries/rotation_context")
local resource_gate = require("libraries/resource_gate")
local spells = require("libraries/spells")
local utils = require("libraries/utils")

if not utils.same_unit then
    function utils.same_unit(a, b)
        return a ~= nil and a == b
    end
end
local eax_utils = require("libraries/eax_utils")
local color     = require("libraries/color")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")
local enums = (function()
    local ok, e = pcall(require, "common/enums")
    return ok and e or nil
end)()

---@type interrupt_manager
local interrupt_manager = require("libraries/interrupt_manager")
---@type ooc_manager
local ooc_manager = require("libraries/ooc_manager")
---@type vendor_automation
local vendor_automation = require("libraries/vendor_automation")
---@type consumables_manager
local consumables_manager = require("libraries/consumables_manager")
---@type mount_manager
local mount_manager = require("libraries/mount_manager")

---@type leveling_manager
local leveling_manager = require("libraries/leveling_manager")
---@type creature_utils
local creature_utils = require("libraries/creature_utils")

---@type encounter_manager
local encounter_manager = require("libraries/encounter_manager")
-- Module-level encounter policy cache (updated each tick)
local enc = nil

-- BigWigs integration: check for upcoming boss abilities
local function is_bigwigs_danger_window()
    local ok, bw = pcall(function() return core.addons.bigwigs end)
    if not ok or not bw then return false end
    local bars = bw.get_bars and bw:get_bars() or {}
    for _, bar in ipairs(bars) do
        if bar and bar.remaining and bar.remaining < 3.0 then
            return true
        end
    end
    return false
end

-- Dynamic encounter detection from API
local function get_current_encounter_info()
    local ok, encounters = pcall(function() return core.world.get_encounters_on_map() end)
    if not ok or not encounters then return nil end
    return encounters
end

-- Flyable area check for travel form decisions
local function should_use_travel_form()
    local ok, flyable = pcall(function() return core.world.is_flyable_area() end)
    if ok and not flyable then
        return false
    end
    return true
end


---@type esp_renderer
local esp_renderer = require("libraries/esp_renderer")

---@type mana_conservator
local mana_conservator = require("libraries/mana_conservator")
esp_renderer.init("balance", "Druid Balance")

-- Smart Cast Manager - addresses spam/sluggishness
local smart_cast_manager = require("libraries/smart_cast_manager")
-- Phase 04 visual telemetry wiring
local dps_meter = require("libraries/dps_meter")
local cooldown_tracker = require("libraries/cooldown_tracker")
local visual_state = require("libraries/visual_state")
local reactive_runtime = require("libraries/reactive_runtime")
local dps_risk = require("libraries/dps_risk")
local dps_runtime = require("libraries/dps_runtime")

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
local _visual_ttd_ok, _visual_ttd_mod = pcall(require, "libraries/ttd_tracker")
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
        -- Reset smart cast manager on combat start
        smart_cast_manager.clear_all_pending()
    elseif (not in_combat) and _visual_runtime.in_combat then
        dps_meter.on_combat_end()
        _visual_runtime.in_combat = false
        _visual_runtime.last_me_hp_pct = nil
        _visual_runtime.last_target_hp_pct = nil
        -- Reset smart cast manager on combat end (keep adaptive stats)
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
        spec = "EAXDruidBalance",
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
local ttd_tracker = require("libraries/ttd_tracker")
---@type racial_manager
local racial_manager = require("libraries/racial_manager")
---@type defensive_manager
local defensive_manager = require("libraries/defensive_manager")
---@type dot_manager
local dot_manager = require("libraries/dot_manager")
---@type mana_manager
local mana_manager = require("libraries/mana_manager")
---@type threat_manager
local threat_manager = require("libraries/threat_manager")

-- Guard to init threat_manager only once at startup
local threat_initialized = false

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local runtime = {
    barkskin_id = nil,
    locked_target_guid = nil,   -- GUID of target we are currently DoTing
    locked_target_ref  = nil,   -- object reference
    rebirth_id = nil,
    moonkin_form_id = nil,
    faerie_fire_id = nil,
    moonfire_id = nil,
    insect_swarm_id = nil,
    wrath_id = nil,
    starfire_id = nil,
    force_of_nature_id = nil,
    hurricane_id = nil,
    innervate_id = nil,
    tranquility_id = nil,
    natures_grace_id = nil,
    prev_toggle_state = false,
    last_cast_time = 0,
    cached_mode = "solo",
    pending_casts = {},
    set_multiplier = 1.0,
    ooc_mark_of_the_wild_id = nil,
    remove_curse_id = nil,
    gift_of_the_wild_id = nil,
    mark_of_the_wild_id = nil,
}

local ctx_cache = rotation_context.new({
    important_buffs = {
        spells.BUFF_INNERVATE,
        spells.BUFF_MOONKIN_FORM,
    },
    important_debuffs = {
        spells.DEBUFF_FAERIE_FIRE,
        spells.DEBUFF_MOONFIRE,
        spells.DEBUFF_INSECT_SWARM,
    },
})

local GCD_CAST_INTERVAL = 1.5  -- TBC GCD
local PENDING_CAST_TIMEOUT_S = 2.5
local FAST_PENDING_CAST_TIMEOUT_S = 0.75
local BUFF_TYPE_CURSE = 4
local spell_resolution_done = false

local function resolve_spells()
    runtime.moonkin_form_id = utils.resolve_spell_id(spells.MOONKIN_FORM)
    runtime.faerie_fire_id = utils.resolve_spell_id(spells.FAERIE_FIRE)
    runtime.moonfire_id = utils.resolve_spell_id(spells.MOONFIRE)
    runtime.insect_swarm_id = utils.resolve_spell_id(spells.INSECT_SWARM)
    runtime.wrath_id = utils.resolve_spell_id(spells.WRATH)
    runtime.starfire_id = utils.resolve_spell_id(spells.STARFIRE)
    runtime.force_of_nature_id = utils.resolve_spell_id(spells.FORCE_OF_NATURE)
    runtime.hurricane_id = utils.resolve_spell_id(spells.HURRICANE)
    runtime.innervate_id = utils.resolve_spell_id(spells.INNERVATE)
    runtime.tranquility_id = utils.resolve_spell_id(spells.TRANQUILITY)
    runtime.rebirth_id  = utils.resolve_spell_id(spells.REBIRTH)
    runtime.remove_curse_id        = utils.resolve_spell_id(spells.REMOVE_CURSE)
    runtime.ooc_mark_of_the_wild_id = utils.resolve_spell_id(spells.MARK_OF_THE_WILD)
    runtime.gift_of_the_wild_id    = utils.resolve_spell_id(spells.GIFT_OF_THE_WILD)
    runtime.mark_of_the_wild_id    = utils.resolve_spell_id(spells.MARK_OF_THE_WILD)
    runtime.barkskin_id = utils.resolve_spell_id(spells.BARKSKIN)
    runtime.natures_grace_id = utils.resolve_spell_id(spells.BUFF_NATURES_GRACE)
end

local function log_resolved_spells()
    core.log("[Eax Druid Balance] Resolved: Moonfire=" .. tostring(runtime.moonfire_id)
        .. " InsectSwarm=" .. tostring(runtime.insect_swarm_id)
        .. " Wrath=" .. tostring(runtime.wrath_id)
        .. " Starfire=" .. tostring(runtime.starfire_id)
        .. " ForceOfNature=" .. tostring(runtime.force_of_nature_id)
        )
end

local function update_set_bonus(me)
    local nordrassil_mult = utils.get_set_multiplier(me, "Nordrassil")
    local nordrassil_harness_mult = utils.get_set_multiplier(me, "NordrassilHarness")
    local malorne_mult = utils.get_set_multiplier(me, "Malorne")
    runtime.set_multiplier = math.max(nordrassil_mult, nordrassil_harness_mult, malorne_mult)
end

-- Enhanced GCD management with smart cast manager
local function note_cast()
    runtime.last_cast_time = _core_time()
    rotation_context.invalidate(ctx_cache)
end

local function invalidate_ctx()
    rotation_context.invalidate(ctx_cache)
end

-- Smart GCD ready check - uses actual GCD tracking
local function is_gcd_ready()
    -- Use smart_cast_manager for intelligent GCD detection
    return smart_cast_manager.is_gcd_ready()
end

-- Smart pending cast check with adaptive timeouts
local function is_pending_cast(spell_id)
    if not spell_id then return false end
    -- Use smart_cast_manager for adaptive pending management
    return smart_cast_manager.is_pending(spell_id)
end

-- Smart pending cast marking with automatic categorization
local function mark_pending_cast(spell_id, timeout_s, options)
    if not spell_id then return end
    options = options or {}
    
    -- Let smart_cast_manager handle adaptive timeouts
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

local function get_effective_mode()
    local idx = menu.mode:get()
    if idx == 2 then return "solo" end
    if idx == 3 then return "dungeon" end
    if idx == 4 then return "raid" end
    return runtime.cached_mode
end

local function is_valid_hostile_target(me, target)
    return target and target:is_valid() and not target:is_dead() and me:can_attack(target)
end

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        local was_enabled = menu.enabled:get_state()
        menu.enabled:set(not was_enabled)
        utils.log_debug(menu, "Toggle -> " .. tostring(not was_enabled))
    end
    runtime.prev_toggle_state = current
end

local function try_moonkin_form(me)
    if not menu.force_moonkin or not menu.force_moonkin:get_state() then return false end
    if not runtime.moonkin_form_id then return false end
    if utils.has_buff(me, spells.BUFF_MOONKIN_FORM) then return false end
    if is_pending_cast(runtime.moonkin_form_id) then return false end
    if not utils.can_cast_self(runtime.moonkin_form_id, me) then return false end

    if utils.cast_self(runtime.moonkin_form_id, me) then
        mark_pending_cast(runtime.moonkin_form_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Moonkin Form")
        note_cast()
        return true
    end

    return false
end

local function try_innervate(me, mana_pct)
    if not menu.use_innervate or not menu.use_innervate:get_state() then return false end
    if not runtime.innervate_id then return false end
    if mana_pct >= ((menu.innervate_mana_pct and menu.innervate_mana_pct:get() or 30) / 100) then return false end
    if utils.has_buff(me, spells.BUFF_INNERVATE) then return false end
    if is_pending_cast(runtime.innervate_id) then return false end
    if not utils.can_cast_self(runtime.innervate_id, me) then return false end

    if utils.cast_self(runtime.innervate_id, me) then
        mark_pending_cast(runtime.innervate_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Innervate")
        note_cast()
        return true
    end

    return false
end

local function try_tranquility(me)
    if not menu.use_tranquility or not menu.use_tranquility:get_state() then return false end
    if not runtime.tranquility_id then return false end
    if utils.get_health_pct(me) >= ((menu.tranquility_hp_pct and menu.tranquility_hp_pct:get() or 35) / 100) then return false end
    if is_pending_cast(runtime.tranquility_id) then return false end
    if not utils.can_cast_self(runtime.tranquility_id, me) then return false end

    if utils.cast_self_fast(runtime.tranquility_id, me) then
        mark_pending_cast(runtime.tranquility_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Emergency Tranquility")
        note_cast()
        return true
    end

    return false
end

local function try_faerie_fire(me, target, ctx)
    if not menu.use_faerie_fire or not menu.use_faerie_fire:get_state() then return false end
    if not runtime.faerie_fire_id then return false end
    if is_pending_cast(runtime.faerie_fire_id) then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not ctx or not resource_gate.common.has_mana_pct(ctx, 0.08) then return false end
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_FAERIE_FIRE) > 5000 then return false end
    if not utils.can_cast_hostile(runtime.faerie_fire_id, me, target) then return false end
    if utils.cast_target(runtime.faerie_fire_id, target) then
        mark_pending_cast(runtime.faerie_fire_id, PENDING_CAST_TIMEOUT_S, { action_key = "faerie_fire", category = "dots" })
        utils.log_debug(menu, "Faerie Fire")
        note_cast()
        return true
    end
    return false
end

local function try_moonfire(me, target, ctx)
    if not menu.use_moonfire or not menu.use_moonfire:get_state() then return false end
    if not runtime.moonfire_id then return false end
    if is_pending_cast(runtime.moonfire_id) then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not ctx or not resource_gate.common.has_mana_pct(ctx, 0.10) then return false end
    -- FLUX pattern: refresh at ≤ 2s remaining (instant cast)
    local refresh_ms = 2000
    local remaining = utils.get_debuff_remaining_ms(target, spells.DEBUFF_MOONFIRE)
    if remaining > refresh_ms and remaining > 0 then return false end
    if should_throttle_dot("moonfire") then return false end
    if not utils.can_cast_hostile(runtime.moonfire_id, me, target) then return false end
    if utils.cast_target(runtime.moonfire_id, target) then
        mark_pending_cast(runtime.moonfire_id, PENDING_CAST_TIMEOUT_S, { action_key = "moonfire", category = "dots" })
        utils.log_debug(menu, "Moonfire")
        note_cast()
        esp_renderer.on_cast(runtime.moonfire_id, "Moonfire", color.blue(220))
        return true
    end
    return false
end

local function try_insect_swarm(me, target, ctx)
    if not menu.use_insect_swarm or not menu.use_insect_swarm:get_state() then return false end
    if not runtime.insect_swarm_id then return false end
    if is_pending_cast(runtime.insect_swarm_id) then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not ctx or not resource_gate.common.has_mana_pct(ctx, 0.10) then return false end
    -- FLUX pattern: refresh at ≤ 2s remaining (instant cast)
    local refresh_ms = 2000
    local remaining = utils.get_debuff_remaining_ms(target, spells.DEBUFF_INSECT_SWARM)
    if remaining > refresh_ms and remaining > 0 then return false end
    if should_throttle_dot("insect_swarm") then return false end
    if not utils.can_cast_hostile(runtime.insect_swarm_id, me, target) then return false end
    if utils.cast_target(runtime.insect_swarm_id, target) then
        mark_pending_cast(runtime.insect_swarm_id, PENDING_CAST_TIMEOUT_S, { action_key = "insect_swarm", category = "dots" })
        utils.log_debug(menu, "Insect Swarm")
        note_cast()
        return true
    end
    return false
end

local function try_force_of_nature(me, target, mana_pct)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_force_of_nature or not menu.use_force_of_nature:get_state() then return false end
    if not runtime.force_of_nature_id then return false end
    if not me:is_in_combat() then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if mana_pct < 0.20 then return false end
    if is_pending_cast(runtime.force_of_nature_id) then return false end
    if not utils.can_cast_self(runtime.force_of_nature_id, me) then return false end

    if utils.cast_self(runtime.force_of_nature_id, me) then
        mark_pending_cast(runtime.force_of_nature_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Force of Nature")
        note_cast()
        return true
    end

    return false
end

local function try_starfire(me, target, ctx, mana_tier)
    if not runtime.starfire_id then return false end
    if is_pending_cast(runtime.starfire_id) then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if me:is_moving() then return false end
    -- Emergency mana tier: skip Starfire
    if mana_tier == "emergency" then return false end
    if not ctx or not resource_gate.common.has_mana_pct(ctx, 0.05) then return false end
    if should_throttle_filler("starfire") then return false end
    local cast_time_ms = mana_manager.get_spell_cast_time_ms(runtime.starfire_id)
    local cast_time_s = cast_time_ms / 1000
    local ttd_s = nil
    if ttd_tracker and ttd_tracker.get then
        local ok, value = pcall(function() return ttd_tracker.get(target) end)
        if ok then ttd_s = tonumber(value) end
    end
    if ttd_s and ttd_s > 0 and ttd_s < (cast_time_s + 0.5) then return false end
    -- Nature's Grace: if buff is active, prioritize Starfire more aggressively
    local has_natures_grace = runtime.natures_grace_id and utils.has_buff(me, spells.BUFF_NATURES_GRACE)
    if not has_natures_grace and mana_tier == "conserve" then return false end
    if not utils.can_cast_hostile(runtime.starfire_id, me, target) then return false end
    if utils.cast_target(runtime.starfire_id, target) then
        mark_pending_cast(runtime.starfire_id, PENDING_CAST_TIMEOUT_S, { action_key = "starfire", category = "long" })
        utils.log_debug(menu, "Starfire")
        note_cast()
        esp_renderer.on_cast(runtime.starfire_id, "Starfire", color.purple(220))
        return true
    end
    return false
end

local function try_wrath(me, target, ctx)
    if not runtime.wrath_id then return false end
    if is_pending_cast(runtime.wrath_id) then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if me:is_moving() then return false end
    if not ctx or not resource_gate.common.has_mana_pct(ctx, 0.05) then return false end
    if should_throttle_filler("wrath") then return false end
    local cast_time_ms = mana_manager.get_spell_cast_time_ms(runtime.wrath_id)
    local cast_time_s = cast_time_ms / 1000
    local ttd_s = nil
    if ttd_tracker and ttd_tracker.get then
        local ok, value = pcall(function() return ttd_tracker.get(target) end)
        if ok then ttd_s = tonumber(value) end
    end
    if ttd_s and ttd_s > 0 and ttd_s < (cast_time_s + 0.5) then return false end
    if not utils.can_cast_hostile(runtime.wrath_id, me, target) then return false end
    if utils.cast_target(runtime.wrath_id, target) then
        mark_pending_cast(runtime.wrath_id, PENDING_CAST_TIMEOUT_S, { action_key = "wrath", category = "filler" })
        utils.log_debug(menu, "Wrath")
        note_cast()
        esp_renderer.on_cast(runtime.wrath_id, "Wrath", color.blue(220))
        return true
    end
    return false
end

local function try_hurricane(me, enemy_count, mana_pct)
    if enc and not enc.aoe_safe then return false end
    if not menu.use_hurricane or not menu.use_hurricane:get_state() then return false end
    if not runtime.hurricane_id then return false end
    local min_targets = menu.hurricane_min_targets and (menu.hurricane_min_targets and menu.hurricane_min_targets:get() or 3) or 3
    local mana_floor  = menu.hurricane_mana_floor and ((menu.hurricane_mana_floor and menu.hurricane_mana_floor:get() or 40) / 100) or 0.40
    if enemy_count < min_targets then return false end
    if mana_pct < mana_floor then return false end
    if me:is_moving() then return false end
    -- Intelligent AoE throttling - prevent rapid hurricane spam
    if should_throttle_aoe("hurricane") then return false end
    if not utils.can_cast_self(runtime.hurricane_id, me) then return false end
    if utils.cast_self(runtime.hurricane_id, me) then
        mark_pending_cast(runtime.hurricane_id, PENDING_CAST_TIMEOUT_S, { action_key = "hurricane", category = "channel" })
        utils.log_debug(menu, "Hurricane (AoE x" .. tostring(enemy_count) .. ")")
        esp_renderer.on_cast(runtime.hurricane_id, "Hurricane", color.cyan(220))
        note_cast()
        return true
    end
    return false
end

-- --- Root escape -----------------------------------------------------------
local function try_root_escape_balance(me)
    if not menu.use_root_escape or not menu.use_root_escape:get_state() then return false end
    if not me:is_rooted(400) then return false end
    if not utils.has_buff(me, spells.BUFF_MOONKIN_FORM) then return false end
    local ok = pcall(function()
        if CancelShapeshiftForm then CancelShapeshiftForm() end
    end)
    if not ok and runtime.moonkin_form_id then
        core.spell_book.cast_spell(runtime.moonkin_form_id)
    end
    utils.log_debug(menu, "Balance root escape: shifted out of Moonkin")
    return true
end

-- --- Remove Curse (scans self + party) ------------------------------------
local function try_remove_curse_balance(me)
    if not menu.use_remove_curse or not menu.use_remove_curse:get_state() then return false end
    if not runtime.remove_curse_id then return false end
    if is_pending_cast(runtime.remove_curse_id) then return false end
    local units = { me }
    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead()
           and obj:is_party_member() then
            units[#units + 1] = obj
        end
    end
    for _, unit in ipairs(units) do
        local cache = buff_manager:get_debuff_cache(unit, 100)
        for _, aura in ipairs(cache) do
            if aura.is_active and aura.buff_type == BUFF_TYPE_CURSE then
                if utils.can_cast_unit(runtime.remove_curse_id, me, unit) then
                    if utils.cast_unit(runtime.remove_curse_id, me, unit) then
                        mark_pending_cast(runtime.remove_curse_id, PENDING_CAST_TIMEOUT_S)
                        utils.log_debug(menu, "Remove Curse -> " .. (unit.get_name and unit:get_name() or "ally"))
                        note_cast()
                        return true
                    end
                end
                break
            end
        end
    end
    return false
end


-- -- Target lock --------------------------------------------------------------
-- Balance applies multiple DoTs to one target before nuking. Without a target
-- lock, find_best_target can switch mid-rotation causing DoTs to be applied to
-- different mobs every tick.
local function get_locked_target(me)
    if runtime.locked_target_ref and runtime.locked_target_ref:is_valid()
       and not runtime.locked_target_ref:is_dead()
       and me:can_attack(runtime.locked_target_ref) then
        return runtime.locked_target_ref
    end
    -- Lock expired or target dead - clear
    runtime.locked_target_guid = nil
    runtime.locked_target_ref  = nil
    return nil
end

local function set_locked_target(target)
    if not target or not target:is_valid() then return end
    local ok, guid = pcall(function() return target:get_guid() end)
    runtime.locked_target_guid = ok and guid or nil
    runtime.locked_target_ref  = target
end

local function should_switch_target(me, current_lock, new_target)
    if not current_lock then return true end
    if not new_target then return false end
    local mf_rem = utils.get_debuff_remaining_ms(current_lock, spells.DEBUFF_MOONFIRE)
    local is_rem = utils.get_debuff_remaining_ms(current_lock, spells.DEBUFF_INSECT_SWARM)
    if mf_rem > 0 or is_rem > 0 then return false end
    return true
end

local function try_barkskin_defensive(me)
    if not menu.use_barkskin or not menu.use_barkskin:get_state() then return false end
    if not runtime.barkskin_id then return false end
    if utils.has_buff(me, spells.BUFF_BARKSKIN) then return false end
    local hp = me:get_health_percentage() / 100
    local threshold = menu.use_barkskin_hp_pct and ((menu.use_barkskin_hp_pct and menu.use_barkskin_hp_pct:get() or 40) / 100) or 0.40
    if hp > threshold then return false end
    if not utils.can_cast_self(runtime.barkskin_id, me) then return false end
    if utils.cast_self(runtime.barkskin_id, me) then
        invalidate_ctx()
        utils.log_debug(menu, "Barkskin (defensive)")
        return true
    end
    return false
end
local function do_rotation(me, target, menu, utils)
    if not me:is_in_combat() and mana_conservator.on_update(me, target, menu, utils) then return true end

    if not is_gcd_ready() then return false end

    local deps = { now_s = _core_time, get_gcd = _get_gcd }
    local ctx = rotation_context.get(ctx_cache, me, target, deps)

    -- Mana potion check (before main damage spells)
    if mana_manager.should_use_mana_potion(me, 30) then
        if mana_manager.use_mana_potion() then
            return true
        end
    end

    local mana_pct = utils.get_mana_pct(me)

    -- Mana tier system for TBC balance druid
    local mana_tier = "full"
    if mana_pct < 0.30 then
        mana_tier = "emergency"
    elseif mana_pct < 0.70 then
        mana_tier = "conserve"
    end

    if try_root_escape_balance(me) then return true end
    if try_innervate(me, mana_pct) then return true end
    if try_moonkin_form(me) then return true end
    if try_tranquility(me) then return true end
    if try_remove_curse_balance(me) then return true end

    if not is_valid_hostile_target(me, target) then
        runtime.locked_target_guid = nil
        runtime.locked_target_ref  = nil
        return false
    end

    -- Target lock: stick to one target while applying DoTs
    local locked = get_locked_target(me)
    if should_switch_target(me, locked, target) then
        set_locked_target(target)
        locked = target
    end
    local dot_target = locked or target

    ttd_tracker.update(dot_target)

    if try_faerie_fire(me, dot_target, ctx) then return true end
    if try_insect_swarm(me, dot_target, ctx) then return true end
    if try_moonfire(me, dot_target, ctx) then return true end
    if try_starfire(me, dot_target, ctx, mana_tier) then return true end
    if try_wrath(me, dot_target, ctx) then return true end

    return false
end


reactive_adapter = {
    spec = "EAXDruidBalance",
    actions = {
        life_save_self = {
            handler = function(_, action_deps)
                return defensive_manager.try_defensive(action_deps.me, "druid", utils)
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

                return interrupt_manager.try_interrupt(action_deps.me, interrupt_target, "druid", utils)
            end,
        },
        anti_overheal = { noop = "unsupported" },
        anti_aggro = {
            handler = function(_, action_deps)
                local snapshot = dps_runtime.build_snapshot(action_deps.me, action_deps.current_target, encounter_manager, ttd_tracker)
                if not dps_risk.should_drop_threat(snapshot) then
                    return false
                end
                local ok, faded = pcall(function()
                    return threat_manager.try_fade(action_deps.me)
                end)
                if not ok then
                    return false
                end
                return faded ~= false
            end,
        },
        throughput_resume = { noop = "unsupported" },
    },
}

local function on_render()
    return
end

-- ESP only renders when this spec is enabled
core.register_on_render_callback(function()
    if not menu or not menu.enabled or not menu.enabled:get_state() then return end
    on_render()
end)
-- __EAX_ESP_GUARD
core.register_on_update_callback(function()
    local me = _get_local_player()
    if not me then return end
    if not spell_resolution_done then
        resolve_spells()
        log_resolved_spells()
        spell_resolution_done = true
    end
    if not threat_initialized then threat_manager.init(me); threat_initialized = true end

    if utils.throttle("eaxdruidbalance_mode_refresh", 5.0) then
        runtime.cached_mode = utils.detect_mode(me)
    end

    if utils.throttle("eaxdruidbalance_set_bonus", 10.0) then
        update_set_bonus(me)
    end

    handle_toggle()

    if not menu.enabled or not menu.enabled:get_state() then return end

    -- OOC management (drink/eat/rez/group buffs)
    ooc_manager.on_update(me, menu, utils, {
        rez_spell_id = runtime.rebirth_id,
        group_buffs = {
            { spell_id = runtime.ooc_mark_of_the_wild_id,
               buff_ids = spells.BUFF_MARK_OF_THE_WILD,
               name = "Mark Of The Wild",
               toggle = menu.ooc_group_buff },
            { spell_id = runtime.gift_of_the_wild_id,
               buff_ids = spells.BUFF_GIFT_OF_THE_WILD,
               name = "Gift Of The Wild",
               toggle = menu.ooc_group_buff },
        },
    })
    if me:is_dead() then return end
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


    -- Wanding / mana conservation (leveling 1-70)
    if leveling_manager.try_wand(me, target, menu) then return true end
    -- Encounter policy (boss-specific rotation adjustments)
    enc = encounter_manager.get_policy(me)

    -- Interrupt
    if target and target:is_valid() and me:can_attack(target) and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "druid", utils) then
            return
        end
    end

    -- Racial CDs
    local hold_offense = dps_risk.should_hold_offense(dps_runtime.build_snapshot(me, target, encounter_manager, ttd_tracker))
    if not hold_offense then
        if racial_manager.try_offensive(me) then return true end
    end
    if racial_manager.try_utility(me, target) then return true end
    if racial_manager.try_defensive(me) then return true end

    -- Defensive abilities
    if try_barkskin_defensive(me) then return true end
    if defensive_manager.try_defensive(me, "druid", utils) then
        return
    end

    -- Threat fade protection - don't pull aggro from tank
    local current_target = me:get_target()
    local ok, should_fade = pcall(function() return threat_manager.should_fade(me, current_target) end)
    if ok and should_fade and dps_risk.should_drop_threat(dps_runtime.build_snapshot(me, current_target, encounter_manager, ttd_tracker)) then
        pcall(function() threat_manager.try_fade(me) end)
        return
    end

    -- Self-emergency healing
    local self_threshold = eax_utils.get_self_heal_threshold(me, (menu.tranquility_hp_pct and menu.tranquility_hp_pct:get() or 35) / 100.0, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_tranquility(me) then return end
    end

    do_rotation(me, target, menu, utils)
end)


-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxdruidbalance_space_win")
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
        local label = "Eax Druid Balance] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxdruidbalance_enabled_cp")
        return elements
    end)
end


-- -- Eax Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Druid"
    local _eax_spec  = "Balance"
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
        core.log("[Eax WARNING] Multiple " .. _eax_class .. " specs enabled: "
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
core.log("[Eax Druid Balance] Loaded " .. (_pi and _pi.plugin_version or "?"))
