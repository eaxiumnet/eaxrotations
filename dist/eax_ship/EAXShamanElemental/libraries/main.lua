-- main.lua
-- Eax Shaman Elemental | Rotation driver
-- APIs validated against core, object_manager, and spellbook docs

local menu = require("menu")
local rotation_context = require("rotation_context")
local resource_gate = require("resource_gate")
local spells = require("spells")
local utils = require("utils")

if not utils.same_unit then
    function utils.same_unit(a, b)
        return a ~= nil and a == b
    end
end
local eax_utils = require("eax_utils")
local dispel_engine = require("dispel_engine")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

---@type interrupt_manager
local interrupt_manager = require("interrupt_manager")
---@type ooc_manager
local ooc_manager = require("ooc_manager")
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
---@type totem_manager
local totem_manager = require("totem_manager")
-- Module-level encounter policy cache (updated each tick)
local enc = nil


---@type esp_renderer
local esp_renderer = require("esp_renderer")
esp_renderer.init("elemental", "Shaman Ele")
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
        spec = "EAXShamanElemental",
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

---@type mana_conservator
local mana_conservator = require("mana_conservator")
local _mana_manager_ok, mana_manager = pcall(require, "mana_manager")
if not _mana_manager_ok then mana_manager = nil end

---@type key_helper
---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")
---@type color
local color = require("color")

local GCD_INTERVAL = 1.5  -- actual TBC GCD duration
local MODE_REFRESH_INTERVAL = 4.5
local PENDING_CAST_TIMEOUT_S = 2.5  -- covers cast time + travel
local LIGHTNING_SHIELD_STACK_FLOOR = 6
local BLOODLUST_HEROISM_BUFFS = { 2825, 32182 }

local MODE_PROFILE = {
    solo = {
        aoe_threshold = 2,
        mana_floor = 10,
        chain_lightning_mana = 35,
        range_min = 0,
        range_max = 32,
        execute_hp = 0,
    },
    dungeon = {
        aoe_threshold = 3,
        mana_floor = 18,
        chain_lightning_mana = 45,
        range_min = 0,
        range_max = 33,
        execute_hp = 40,
    },
    raid = {
        aoe_threshold = 4,
        mana_floor = 22,
        chain_lightning_mana = 55,
        range_min = 0,
        range_max = 34,
        execute_hp = 50,
    },
}

local runtime = {
    ancestral_spirit_id = nil,
    lightning_bolt_id = nil,
    chain_lightning_id = nil,
    flame_shock_id = nil,
    elemental_mastery_id = nil,
    natures_swiftness_id = nil,
    totem_of_wrath_id = nil,
    mana_spring_id = nil,
    water_shield_id     = nil,
    lightning_shield_id = nil,
    healing_wave_id     = nil,
    ghost_wolf_id       = nil,
    totemic_call_id     = nil,
    purge_id = nil,
    cure_poison_id = nil,
    cure_disease_id = nil,
    last_cast_time = 0,
    pending_casts = {},
    cached_mode = "solo",
    prev_toggle_state = false,
    totem_last_apply = {},
    last_ns_at = 0,
    set_multiplier = 1.0,
    lightning_shield_stacks = 0,
}

local ctx_cache = rotation_context.new({})

local TOTEM_ROTATION = {
    { name = "wrath", id_field = "totem_of_wrath_id", toggle = menu.auto_totem_wrath, label = "Totem of Wrath", slot = 1, duration = 115 },
    { name = "mana_spring", id_field = "mana_spring_id", toggle = menu.auto_totem_mana, label = "Mana Spring Totem", slot = 3, duration = 115 },
}

local target_will_die_before_cast_finishes

local function is_totem_slot_empty(slot)
    if not slot or not core.spell_book or not core.spell_book.get_totem_info then
        return true
    end
    local info = core.spell_book.get_totem_info(slot)
    return not (info and info.have_totem)
end

local function should_refresh_totem(entry, now)
    local last = runtime.totem_last_apply[entry.name] or 0
    if entry.slot and is_totem_slot_empty(entry.slot) then
        return last == 0 or (now - last) >= 2.0
    end
    return entry.duration and last > 0 and (now - last) >= entry.duration
end

local function resolve_spells()
    runtime.earth_shock_id  = utils.resolve_spell_id(spells.EARTH_SHOCK)
    runtime.frost_shock_id  = utils.resolve_spell_id(spells.FROST_SHOCK)
    runtime.lightning_bolt_id = utils.resolve_spell_id(spells.LIGHTNING_BOLT)
    runtime.chain_lightning_id = utils.resolve_spell_id(spells.CHAIN_LIGHTNING)
    runtime.flame_shock_id = utils.resolve_spell_id(spells.FLAME_SHOCK)
    runtime.elemental_mastery_id = utils.resolve_spell_id(spells.ELEMENTAL_MASTERY)
    runtime.natures_swiftness_id = utils.resolve_spell_id(spells.NATURES_SWIFTNESS)
    runtime.totem_of_wrath_id = utils.resolve_spell_id(spells.TOTEM_OF_WRATH)
    runtime.mana_spring_id = utils.resolve_spell_id(spells.MANA_SPRING_TOTEM)
    runtime.water_shield_id     = utils.resolve_spell_id(spells.WATER_SHIELD)
    runtime.lightning_shield_id = utils.resolve_spell_id(spells.LIGHTNING_SHIELD)
    runtime.healing_wave_id     = utils.resolve_spell_id(spells.HEALING_WAVE)
    runtime.ghost_wolf_id       = utils.resolve_spell_id(spells.GHOST_WOLF)
    runtime.totemic_call_id     = utils.resolve_spell_id(spells.TOTEMIC_CALL)
    runtime.purge_id = utils.resolve_spell_id(spells.PURGE)
    runtime.cure_poison_id = utils.resolve_spell_id(spells.CURE_POISON)
    runtime.cure_disease_id = utils.resolve_spell_id(spells.CURE_DISEASE)
    runtime.ancestral_spirit_id  = utils.resolve_spell_id(spells.ANCESTRAL_SPIRIT)
end

local function should_abort_lightning_bolt_commit(me, target)
    if not target or not target:is_valid() or target:is_dead() then
        return true
    end
    return target_will_die_before_cast_finishes(me, target, runtime.lightning_bolt_id, 0.35)
end

local function log_resolved_spells()
    utils.log_debug(menu, "Spells resolved: LB=" .. tostring(runtime.lightning_bolt_id)
        .. " CL=" .. tostring(runtime.chain_lightning_id)
        .. " FS=" .. tostring(runtime.flame_shock_id)
        .. " EM=" .. tostring(runtime.elemental_mastery_id))
end

local function refresh_mode_cache()
    local me = _get_local_player()
    runtime.cached_mode = me and utils.detect_mode(me) or runtime.cached_mode
end

local function get_effective_mode()
    local selection = menu.mode:get()
    if selection == 2 then
        return "solo"
    elseif selection == 3 then
        return "dungeon"
    elseif selection == 4 then
        return "raid"
    end
    return runtime.cached_mode
end

local function get_mode_profile()
    local mode = get_effective_mode()
    return MODE_PROFILE[mode] or MODE_PROFILE.solo
end

local function note_cast()
    runtime.last_cast_time = _core_time()
    rotation_context.invalidate(ctx_cache)
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

local function try_cast_target(me, target, spell_id, label)
    if not spell_id or not target or not target:is_valid() or target:is_dead() then
        return false
    end
    if not utils.is_valid_hostile(me, target) then
        return false
    end
    if not totem_manager.can_cast_spell(label) then
        totem_manager.try_workaround(me, label)
        return false
    end
    if is_pending_cast(spell_id) then
        return false
    end
    if not utils.cast_target(spell_id, me, target) then
        return false
    end
    mark_pending_cast(spell_id)
    note_cast()
    local target_name = target:get_name() or "?"
    esp_renderer.on_cast(spell_id, label, color.cyan(220), target_name)
    utils.log_debug(menu, label .. " cast")
    return true
end

local function try_cast_self(me, spell_id, label)
    if not spell_id or not me or not me:is_valid() then
        return false
    end
    if is_pending_cast(spell_id) then
        return false
    end
    if not totem_manager.can_cast_spell(label) then
        totem_manager.try_workaround(me, label)
        return false
    end
    if not utils.can_cast_self(spell_id, me) then
        return false
    end
    if not utils.cast_self(spell_id, me) then
        return false
    end
    mark_pending_cast(spell_id)
    note_cast()
    esp_renderer.on_cast(spell_id, label, color.cyan(220), "Self")
    utils.log_debug(menu, label .. " cast")
    return true
end

local function get_target_ttd_seconds(target)
    if not target or not ttd_tracker then return nil end
    local ok, value = pcall(function() return ttd_tracker.get(target) end)
    if not ok then return nil end
    return tonumber(value)
end

local function get_spell_cast_time_seconds(spell_id, me)
    if not spell_id or not mana_manager or not mana_manager.get_spell_cast_time_ms then return nil end
    local ok, value = pcall(function() return mana_manager.get_spell_cast_time_ms(spell_id, me) end)
    if not ok then return nil end
    local ms = tonumber(value)
    return ms and ms > 0 and (ms / 1000) or nil
end

target_will_die_before_cast_finishes = function(me, target, spell_id, buffer_s)
    local ttd_s = get_target_ttd_seconds(target)
    local cast_s = get_spell_cast_time_seconds(spell_id, me)
    if not ttd_s or not cast_s then return false end
    return ttd_s <= (cast_s + (buffer_s or 0.25))
end

local function ensure_totems(me, target)
    if not menu.auto_totems:get_state() then
        return false
    end
    if me:is_in_combat() then
        local hp_pct = utils.get_health_pct(me)
        local mana_pct = utils.get_mana_pct(me)
        if hp_pct and hp_pct < 0.60 then
            return false
        end
        if mana_pct and mana_pct < 0.25 then
            return false
        end
        if target and target:is_valid() and not target:is_dead() then
            local ok_cast, casting = pcall(function() return target:is_casting_spell() end)
            local ok_chan, channelling = pcall(function() return target:is_channelling_spell() end)
            if (ok_cast and casting) or (ok_chan and channelling) then
                return false
            end
        end
    end
    local now = _core_time()
    for _, entry in ipairs(TOTEM_ROTATION) do
        if entry.toggle:get_state() then
            local spell_id = runtime[entry.id_field]
            if spell_id and utils.can_cast_self(spell_id, me) then
                if should_refresh_totem(entry, now) then
                    if try_cast_self(me, spell_id, entry.label) then
                        runtime.totem_last_apply[entry.name] = now
                        return true
                    end
                end
            end
        end
    end
    return false
end


local function try_earth_shock_interrupt(me, target)
    if not menu.use_earth_shock or not menu.use_earth_shock:get_state() then return false end
    if not runtime.earth_shock_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    local ok, casting = pcall(function() return target:is_casting_spell() end)
    local ok2, channing = pcall(function() return target:is_channelling_spell() end)
    if not ((ok and casting) or (ok2 and channing)) then return false end
    if not utils.can_cast_hostile(runtime.earth_shock_id, me, target) then return false end
    if utils.cast_target(runtime.earth_shock_id, me, target) then
        invalidate_ctx()
        utils.log_debug(menu, "Earth Shock (interrupt)")
        return true
    end
    return false
end

local function try_frost_shock_slow(me, target)
    if not menu.use_frost_shock or not menu.use_frost_shock:get_state() then return false end
    if not runtime.frost_shock_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    -- Use frost shock to slow melee attackers chasing us
    local ok, moving = pcall(function() return target:is_moving() end)
    if not (ok and moving) then return false end
    if not utils.can_cast_hostile(runtime.frost_shock_id, me, target) then return false end
    if utils.cast_target(runtime.frost_shock_id, me, target) then
        invalidate_ctx()
        utils.log_debug(menu, "Frost Shock (slow)")
        return true
    end
    return false
end

local function try_purge(me, target)
    if not runtime.purge_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    if not ((enc and enc.force_dispel) or menu.use_purge:get_state()) then return false end
    if not utils.can_cast_hostile(runtime.purge_id, me, target) then return false end
    if utils.cast_target(runtime.purge_id, me, target) then
        invalidate_ctx()
        utils.log_debug(menu, "Purge")
        return true
    end
    return false
end

local function try_cure_dispels(me)
    if not menu.use_dispels:get_state() then return false end
    local units = { me }
    local party_units = utils.get_party_units and utils.get_party_units(me) or {}
    for i = 1, #party_units do
        units[#units + 1] = party_units[i]
    end
    local best_target, priority = dispel_engine.find_best_target({
        candidates = units,
        priorities = {
            { type_def = { numeric = 4, name = "poison" }, label = "Cure Poison", spell_id = runtime.cure_poison_id },
            { type_def = { numeric = 3, name = "disease" }, label = "Cure Disease", spell_id = runtime.cure_disease_id },
        },
        get_hp = function(unit) return utils.get_health_pct(unit) end,
    })
    if best_target and priority and priority.spell_id and utils.can_cast_target(priority.spell_id, me, best_target) then
        if utils.cast_target(priority.spell_id, me, best_target) then return true end
    end
    return false
end

local function try_burst(me, target)
    if not menu.use_cooldowns:get_state() then
        return false
    end
    local profile = get_mode_profile()
    local mode = get_effective_mode()
    local target_hp = target and target:is_valid() and not target:is_dead() and utils.get_health_pct(target) or 0
    if runtime.elemental_mastery_id and (target and (target:is_boss() or mode == "raid" or target_hp >= 0.9)) then
        if try_cast_self(me, runtime.elemental_mastery_id, "Elemental Mastery") then
            return true
        end
    end
    local now = _core_time()
    if runtime.natures_swiftness_id and (now - runtime.last_ns_at) > 10 and target_hp > (profile.execute_hp or 0) / 100 then
        if try_cast_self(me, runtime.natures_swiftness_id, "Nature's Swiftness") then
            runtime.last_ns_at = now
            return true
        end
    end
    return false
end

local _flame_shock_last_applied = {}  -- [target_guid] = timestamp
local FLAME_SHOCK_REFRESH_BUFFER = 3.0
local EARTH_SHOCK_SHORT_TTD = 8.0

local function get_debuff_remaining_ms(unit, id_table)
    if not unit or not unit:is_valid() or not id_table then
        return 0
    end
    local data = buff_manager:get_debuff_data(unit, id_table)
    if data and data.is_active then
        return data.remaining or 0
    end
    return 0
end

local function try_flame_shock(me, target)
    if not menu.use_flame_shock:get_state() or not runtime.flame_shock_id then
        return false
    end
    if not target or not target:is_valid() or target:is_dead() then
        return false
    end
    local fs_remaining_ms = get_debuff_remaining_ms(target, spells.BUFF_FLAME_SHOCK)
    if fs_remaining_ms > (FLAME_SHOCK_REFRESH_BUFFER * 1000) then
        return false
    end
    local target_hp = utils.get_health_pct(target)
    local stop_pct = math.max(menu.flame_shock_stop_hp:get(), get_mode_profile().execute_hp) / 100
    if target_hp <= stop_pct then
        return false
    end
    local guid = tostring(target)
    if try_cast_target(me, target, runtime.flame_shock_id, "Flame Shock") then
        _flame_shock_last_applied[guid] = _core_time()
        return true
    end
    return false
end

local function try_earth_shock_damage(me, target)
    if not runtime.earth_shock_id or not target then
        return false
    end
    if not target:is_valid() or target:is_dead() then
        return false
    end
    local mana_pct = utils.get_mana_pct(me)
    local mana_stop = menu.mana_floor and menu.mana_floor:get() or 0
    if mana_stop > 0 and mana_pct < (mana_stop / 100) then
        return false
    end

    local profile = get_mode_profile()
    local execute_cutoff = math.max(menu.execute_hp:get(), profile.execute_hp) / 100
    local target_hp = utils.get_health_pct(target)
    local target_ttd = get_target_ttd_seconds(target)
    local fs_remaining_ms = get_debuff_remaining_ms(target, spells.BUFF_FLAME_SHOCK)
    local fs_remaining = fs_remaining_ms / 1000
    local flame_missing = fs_remaining_ms <= 0
    local short_window = (target_ttd and target_ttd > 0 and target_ttd <= EARTH_SHOCK_SHORT_TTD)
    local execute_window = target_hp <= execute_cutoff
    local ok_moving, moving_window = pcall(function() return me:is_moving() end)
    moving_window = ok_moving and moving_window or false

    if not (execute_window or short_window or moving_window) then
        return false
    end

    local ok_casting, hostile_casting = pcall(function() return target:is_casting_spell() or target:is_channelling_spell() end)
    if ok_casting and hostile_casting then
        return false
    end

    if (not flame_missing) and fs_remaining > FLAME_SHOCK_REFRESH_BUFFER and not (execute_window or short_window) then
        return false
    end

    return try_cast_target(me, target, runtime.earth_shock_id, "Earth Shock (damage)")
end

local function try_chain_lightning(me, target)
    if enc and not enc.aoe_safe then return false end
    if not runtime.chain_lightning_id or not target then
        return false
    end
    local profile = get_mode_profile()
    local threshold = math.max(menu.aoe_threshold:get(), profile.aoe_threshold)
    local enemy_count = utils.count_enemies_in_range(me, spells.CHAIN_LIGHTNING_RADIUS)
    local burn_phase = false
    if me and me:is_valid() and me:is_in_combat() then
        local hold_cooldowns, burn_until_pct = encounter_manager.should_hold_cooldowns(me)
        local target_hp = utils.get_health_pct(target)
        burn_phase = (not hold_cooldowns and burn_until_pct > 0 and target_hp <= burn_until_pct)
            or utils.has_buff(me, BLOODLUST_HEROISM_BUFFS)
            or (enc and enc.burn_phase)
    end
    if enemy_count < threshold and not burn_phase then
        local mana_pct = utils.get_mana_pct(me)
        local mana_cutoff = math.max(menu.chain_lightning_mana:get(), profile.chain_lightning_mana) / 100
        local target_ttd = get_target_ttd_seconds(target)
        if mana_pct < (mana_cutoff + 0.20) or not target_ttd or target_ttd < 10 then
            return false
        end
    end
    local mana_pct = utils.get_mana_pct(me)
    local mana_cutoff = math.max(menu.chain_lightning_mana:get(), profile.chain_lightning_mana) / 100
    if mana_pct < mana_cutoff then
        return false
    end
    return try_cast_target(me, target, runtime.chain_lightning_id, "Chain Lightning")
end

local function try_lightning_bolt(me, target)
    if not runtime.lightning_bolt_id or not target then
        return false
    end
    local profile = get_mode_profile()
    local mana_pct = utils.get_mana_pct(me)
    local mana_floor = math.max(menu.mana_floor:get(), profile.mana_floor) / 100
    if mana_pct < mana_floor then
        return false
    end
    local target_hp = utils.get_health_pct(target)
    local execute_cutoff = math.max(menu.execute_hp:get(), profile.execute_hp) / 100
    if target_hp <= execute_cutoff then
        return false
    end
    if target_will_die_before_cast_finishes(me, target, runtime.lightning_bolt_id, 0.35) then return false end
    local distance = utils.get_distance(me, target)
    local min_range = math.max(menu.range_min:get(), profile.range_min)
    local max_range = math.max(menu.range_max:get(), profile.range_max)
    if distance < min_range or distance > max_range then
        return false
    end
    return try_cast_target(me, target, runtime.lightning_bolt_id, "Lightning Bolt")
end


-- -- Shield maintenance --------------------------------------------------------
local function ensure_shield(me)
    local mode = menu.shield_mode and menu.shield_mode:get() or 2
    -- 0=None, 1=Lightning, 2=Water, 3=Auto
    if mode == 0 then return false end
    local use_water
    if mode == 1 then use_water = false
    elseif mode == 2 then use_water = true
    else use_water = (not me:is_in_combat()) and (me:get_level() or 0) >= 60 end

    if use_water and runtime.water_shield_id then
        if not utils.has_buff(me, spells.BUFF_WATER_SHIELD) then
            return try_cast_self(me, runtime.water_shield_id, "Water Shield")
        end
    elseif not use_water and runtime.lightning_shield_id then
        local ls = buff_manager:get_buff_data(me, spells.BUFF_LIGHTNING_SHIELD)
        runtime.lightning_shield_stacks = (ls and ls.is_active and (ls.stacks or 0)) or 0
        if (not ls or not ls.is_active) or runtime.lightning_shield_stacks < LIGHTNING_SHIELD_STACK_FLOOR then
            return try_cast_self(me, runtime.lightning_shield_id, "Lightning Shield")
        end
    end
    return false
end


-- -- Self-healing --------------------------------------------------------------
local function try_self_heal(me)
    if not menu.use_healing_wave or not menu.use_healing_wave:get_state() then return false end
    if not runtime.healing_wave_id then return false end
    local hp_pct = utils.get_health_pct(me)
    local threshold = (menu.healing_wave_hp and menu.healing_wave_hp:get() or 35) / 100
    if hp_pct > threshold then return false end
    return try_cast_self(me, runtime.healing_wave_id, "Healing Wave")
end

-- -- Ghost Wolf OOC ------------------------------------------------------------
local GHOST_WOLF_BUFF = { 2645 }
local function try_ghost_wolf(me)
    if not menu.use_ghost_wolf or not menu.use_ghost_wolf:get_state() then return false end
    if not runtime.ghost_wolf_id then return false end
    if me:is_in_combat() then return false end
    if utils.has_buff(me, GHOST_WOLF_BUFF) then return false end
    -- Block if eating, drinking, or any cast in progress
    if eax_utils.is_eating_or_drinking(me) then return false end
    local ok, casting = pcall(function() return me:is_casting_spell() end)
    if ok and casting then return false end
    local ok2, channing = pcall(function() return me:is_channelling_spell() end)
    if ok2 and channing then return false end
    return try_cast_self(me, runtime.ghost_wolf_id, "Ghost Wolf")
end

-- -- Totemic Call (recall for mana refund) -------------------------------------
local last_totemic_call = 0
local TOTEMIC_CALL_CD = 2.0
local function try_totemic_call(me)
    if not menu.use_totemic_call or not menu.use_totemic_call:get_state() then return false end
    if not runtime.totemic_call_id then return false end
    if (_core_time() - last_totemic_call) < TOTEMIC_CALL_CD then return false end
    -- Only recall if not in combat and mana is below 50%
    if me:is_in_combat() then return false end
    local mana_pct = utils.get_mana_pct(me)
    if mana_pct > 0.5 then return false end
    -- Check if any totems are active
    local has_totem = false
    for slot = 1, 4 do
        local ok, info = pcall(function() return core.spell_book.get_totem_info(slot) end)
        if ok and info and info.have_totem then has_totem = true; break end
    end
    if not has_totem then return false end
    if utils.can_cast_self(runtime.totemic_call_id, me) then
        if utils.cast_self(runtime.totemic_call_id, me) then
            last_totemic_call = _core_time()
            esp_renderer.on_cast(runtime.totemic_call_id, "Totemic Call", color.gold(220), "Self")
            return true
        end
    end
    return false
end

local function do_rotation(me, target)
    -- Lazy re-resolve: spells may not be learned yet at plugin load time
    if not runtime.lightning_bolt_id then resolve_spells() end
    -- Shield maintenance (always, even when GCD not ready)
    ensure_shield(me)
    -- Emergency self-heal
    if try_self_heal(me) then return true end

    if mana_conservator.on_update(me, target, menu, utils) then return end

    if try_cure_dispels(me) then return end

    if not is_gcd_ready() then
        return false
    end
    local deps = { now_s = _core_time, get_gcd = _get_gcd }
    local ctx = rotation_context.get(ctx_cache, me, target, deps)
    if target and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "shaman", utils) then
        return true
        end
    end


    -- Wanding / mana conservation (leveling 1-70)
    if leveling_manager.try_wand(me, target, menu) then return true end
    -- Encounter policy (boss-specific rotation adjustments)
    enc = encounter_manager.get_policy(me)

    -- Racial CDs
    local hold_offense = dps_risk.should_hold_offense(dps_runtime.build_snapshot(me, target, encounter_manager, ttd_tracker))
    if not hold_offense then
        if racial_manager.try_offensive(me) then return true end
    end
    if racial_manager.try_utility(me, target) then return true end
    if racial_manager.try_defensive(me) then return true end

    -- Defensive abilities
    ttd_tracker.update(target)

    if (me:is_casting_spell() or me:is_channelling_spell()) and should_abort_lightning_bolt_commit(me, target) then
        if SpellStopCasting then
            SpellStopCasting()
            return true
        end
    end

    if defensive_manager.try_defensive(me, "shaman", utils) then
        return true
    end

    if ensure_totems(me, target) then return true end
    if try_earth_shock_interrupt(me, target) then return true end
    if try_frost_shock_slow(me, target) then return true end
    if try_purge(me, target) then return true end
    if not hold_offense and try_burst(me, target) then return true end
    if ctx and resource_gate.shaman.has_mana_pct(ctx, 0.12) and try_flame_shock(me, target) then
        return true
    end
    if ctx and resource_gate.shaman.has_mana_pct(ctx, 0.12) and try_earth_shock_damage(me, target) then
        return true
    end
    if ctx and resource_gate.shaman.has_mana_pct(ctx, 0.18) and try_chain_lightning(me, target) then
        return true
    end
    if ctx and resource_gate.shaman.has_mana_pct(ctx, 0.10) and try_lightning_bolt(me, target) then
        return true
    end
    return false
end

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        local enabled = menu.enabled:get_state()
        menu.enabled:set(not enabled)
        utils.log_debug(menu, "Toggle -> " .. tostring(not enabled))
    end
    runtime.prev_toggle_state = current
end

resolve_spells()
log_resolved_spells()

local function update_set_bonus()
    local me = _get_local_player()
    if not me then return end
    
    local cyclone_mult = utils.get_set_multiplier(me, "Cyclone")
    local cataclysm_mult = utils.get_set_multiplier(me, "Cataclysm")
    local skyshatter_mult = utils.get_set_multiplier(me, "Skyshatter")
    
    runtime.set_multiplier = cyclone_mult
    if cataclysm_mult > runtime.set_multiplier then
        runtime.set_multiplier = cataclysm_mult
    end
    if skyshatter_mult > runtime.set_multiplier then
        runtime.set_multiplier = skyshatter_mult
    end
    
    if runtime.set_multiplier > 1.0 then
        utils.log_debug(menu, "Set bonus: " .. tostring(runtime.set_multiplier))
    end
end


reactive_adapter = {
    spec = "EAXShamanElemental",
    actions = {
        life_save_self = {
            handler = function(_, action_deps)
                return defensive_manager.try_defensive(action_deps.me, "shaman", utils)
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

                return interrupt_manager.try_interrupt(action_deps.me, interrupt_target, "shaman", utils)
            end,
        },
        anti_overheal = { noop = "unsupported" },
        anti_aggro = { noop = "unsupported" },
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
    if not me or me:is_dead() then
        return
    end
    if utils.throttle("mode_refresh", MODE_REFRESH_INTERVAL) then
        refresh_mode_cache()
    end
    if utils.throttle("set_bonus", 5.0) then
        update_set_bonus()
    end
    handle_toggle()
    if not menu.enabled:get_state() then
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
    
    -- OOC: ghost wolf, totemic call
    if not me:is_in_combat() then
        try_ghost_wolf(me)
        try_totemic_call(me)
    end

    do_rotation(me, target)
end)


-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxshamanelemental_space_win")
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
        local current = menu.enabled:get_state()
        local toggle_key = menu.toggle_key:get_key_code()
        local label = "[Eax Shaman Elemental] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        local function add_cb(lbl, item, uid)
            if not item then return end
            local cur = item:get_state()
            local nxt = control_panel_utility:insert_key_checkbox_(elements, lbl, cur, 0, false, uid)
            if nxt ~= cur then item:set(nxt) end
        end
        local function add_kb(lbl, kb)
            if not kb then return end
            control_panel_utility:insert_toggle_(elements, lbl, kb, false)
        end
        add_cb(label,                           menu.enabled,         "eax_ele_enabled_cp")
        return elements
    end)
end



-- -- Eax Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Shaman"
    local _eax_spec  = "Elemental"
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

core.log("[Eax Shaman Elemental] Loaded")
