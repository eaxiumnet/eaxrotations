-- main.lua
-- Eax Shaman Enhancement | Stormstrike-driven melee
-- APIs validated against core, object_manager, and spellbook docs

require("common/wow_api_clone")  -- exposes GetWeaponEnchantInfo for temp enchant detection
local menu = require("libraries/menu")
local spells = require("libraries/spells")
local rotation_context = require("libraries/rotation_context")
local resource_gate = require("libraries/resource_gate")
local utils = require("libraries/utils")

if not utils.same_unit then
    function utils.same_unit(a, b)
        return a ~= nil and a == b
    end
end
local eax_utils = require("libraries/eax_utils")
local dispel_engine = require("libraries/dispel_engine")

---@type interrupt_manager
local interrupt_manager = require("libraries/interrupt_manager")
---@type ooc_manager
local ooc_manager = require("libraries/ooc_manager")
---@type consumables_manager
local consumables_manager = require("libraries/consumables_manager")
---@type leveling_manager
local leveling_manager = require("libraries/leveling_manager")
---@type encounter_manager
local encounter_manager = require("libraries/encounter_manager")
---@type totem_manager
local totem_manager = require("libraries/totem_manager")
local pvp_manager = require("libraries/pvp_manager")
---@type swing_timer
local swing_timer = require("libraries/swing_timer")
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


---@type esp_renderer
local esp_renderer = require("libraries/esp_renderer")
esp_renderer.init("enhance", "Shaman Enh")
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
local runtime
local has_flame_shock

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
        runtime.last_windfury_drop = 0
        runtime.totem_last_apply = {}
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
        spec = "EAXShamanEnhancement",
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

---@type key_helper
---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")
---@type color
local color = require("libraries/color")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

local GCD_INTERVAL = 1.5  -- actual TBC GCD duration
local MODE_REFRESH_INTERVAL = 4.5
local PENDING_CAST_TIMEOUT_S = 2.5
local dev_id = "eax_shaman_enhancement_"
local LIGHTNING_SHIELD_STACK_FLOOR = 6

local MODE_PROFILE = {
    solo = { aoe_threshold = 2, mana_floor = 5, swing_clip_ms = 140 },
    dungeon = { aoe_threshold = 3, mana_floor = 10, swing_clip_ms = 160 },
    raid = { aoe_threshold = 4, mana_floor = 15, swing_clip_ms = 170 },
}

local CURE_DISEASE_TYPE = 3
local CURE_POISON_TYPE = 4

local function target_has_cure_debuff(unit, dispel_type)
    if not unit or not unit.get_debuffs then return false end
    local ok, debuffs = pcall(function() return unit:get_debuffs() end)
    if not ok or not debuffs then return false end
    for _, debuff in ipairs(debuffs) do
        if debuff and debuff.type == dispel_type then
            return true
        end
    end
    return false
end

runtime = {
    ancestral_spirit_id = nil,
    stormstrike_id = nil,
    shamanistic_rage_id = nil,
    earth_shock_id = nil,
    flame_shock_id = nil,
    frost_shock_id = nil,
    chain_lightning_id = nil,
    lightning_bolt_id = nil,
    purge_id = nil,
    cure_poison_id = nil,
    cure_disease_id = nil,
    windfury_totem_id = nil,
    windfury_weapon_id = nil,
    water_shield_id      = nil,
    lightning_shield_id  = nil,
    healing_wave_id      = nil,
    lesser_hw_id         = nil,
    ghost_wolf_id        = nil,
    searing_totem_id = nil,
    magma_totem_id = nil,
    grace_of_air_id = nil,
    wrath_of_air_id = nil,
    strength_earth_id = nil,
    mana_spring_id = nil,
    last_windfury_drop = 0,
    flametongue_weapon_id = nil,
    last_windfury_at      = 0,
    last_flametongue_at   = 0,
    wind_shear_id = nil,
    set_multiplier = 1.0,
    last_cast_time = 0,
    pending_casts = {},
    cached_mode = "solo",
    prev_toggle_state = false,
    fire_nova_totem_id = nil,
    last_fire_nova_drop = 0,
    last_stormstrike_debuff_at = 0,
    totem_last_apply = {},
    last_potion_at = 0,
}

local ctx_cache = rotation_context.new({
    important_buffs = {},
    important_debuffs = {},
})

local MANA_POTION_IDS = { 33447, 22832, 13444, 6149, 3827 }

local TOTEM_ROTATION = {
    { name = "windfury", id_field = "windfury_totem_id", toggle = menu.auto_totem_windfury, label = "Windfury Totem", slot = 4, duration = 115 },
}

local TOTEM_SLOTS = {
    windfury = 4,
    support_air = 4,
    earth_totem = 2,
    water_totem = 3,
    fire_totem = 1,
}

local function is_totem_slot_empty(slot)
    if not slot or not core.spell_book or not core.spell_book.get_totem_info then
        return true
    end
    local info = core.spell_book.get_totem_info(slot)
    return not (info and info.have_totem)
end

local function should_refresh_named_totem(name, slot, duration_s)
    local now = _core_time()
    local last = runtime.totem_last_apply[name] or 0
    if slot and is_totem_slot_empty(slot) then
        return true, now
    end
    return (duration_s and last > 0 and (now - last) >= duration_s) == true, now
end

local SHOCK_TABLE = {
    [1] = { id_field = "earth_shock_id", debuff = spells.EARTH_SHOCK, label = "Earth Shock" },
    [2] = { id_field = "flame_shock_id", debuff = spells.FLAME_SHOCK, label = "Flame Shock" },
    [3] = { id_field = "frost_shock_id", debuff = spells.FROST_SHOCK, label = "Frost Shock" },
}

local function resolve_spells()
    runtime.stormstrike_id = utils.resolve_spell_id(spells.STORMSTRIKE)
    runtime.shamanistic_rage_id = utils.resolve_spell_id(spells.SHAMANISTIC_RAGE)
    runtime.earth_shock_id = utils.resolve_spell_id(spells.EARTH_SHOCK)
    runtime.flame_shock_id = utils.resolve_spell_id(spells.FLAME_SHOCK)
    runtime.frost_shock_id = utils.resolve_spell_id(spells.FROST_SHOCK)
    runtime.chain_lightning_id = utils.resolve_spell_id(spells.CHAIN_LIGHTNING)
    runtime.lightning_bolt_id = utils.resolve_spell_id(spells.LIGHTNING_BOLT)
    runtime.purge_id = utils.resolve_spell_id(spells.PURGE)
    runtime.cure_poison_id = utils.resolve_spell_id(spells.CURE_POISON)
    runtime.cure_disease_id = utils.resolve_spell_id(spells.CURE_DISEASE)
    runtime.windfury_totem_id      = utils.resolve_spell_id(spells.WINDFURY_TOTEM)
    runtime.windfury_weapon_id    = utils.resolve_spell_id(spells.WINDFURY_WEAPON)
    runtime.water_shield_id      = utils.resolve_spell_id(spells.WATER_SHIELD)
    runtime.lightning_shield_id  = utils.resolve_spell_id(spells.LIGHTNING_SHIELD)
    runtime.healing_wave_id      = utils.resolve_spell_id(spells.HEALING_WAVE)
    runtime.lesser_hw_id         = utils.resolve_spell_id(spells.LESSER_HEALING_WAVE)
    runtime.ghost_wolf_id        = utils.resolve_spell_id(spells.GHOST_WOLF)
    runtime.searing_totem_id   = utils.resolve_spell_id(spells.SEARING_TOTEM)
    runtime.magma_totem_id     = utils.resolve_spell_id(spells.MAGMA_TOTEM)
    runtime.grace_of_air_id    = utils.resolve_spell_id(spells.GRACE_OF_AIR_TOTEM)
    runtime.wrath_of_air_id    = utils.resolve_spell_id(spells.WRATH_OF_AIR_TOTEM)
    runtime.strength_earth_id  = utils.resolve_spell_id(spells.STRENGTH_OF_EARTH_TOTEM)
    runtime.mana_spring_id     = utils.resolve_spell_id(spells.MANA_SPRING_TOTEM)
    runtime.magma_totem_id         = utils.resolve_spell_id(spells.MAGMA_TOTEM)
    runtime.flametongue_weapon_id   = utils.resolve_spell_id(spells.FLAMETONGUE_WEAPON)
    runtime.ancestral_spirit_id  = utils.resolve_spell_id(spells.ANCESTRAL_SPIRIT)
    runtime.fire_nova_totem_id     = utils.resolve_spell_id(spells.FIRE_NOVA_TOTEM)
end

local function log_resolved_spells()
    utils.log_debug(menu, "Resolved Stormstrike=" .. tostring(runtime.stormstrike_id))
    -- Always log these so player can see what's available
    core.log("[Eax Enh] Stormstrike ID: " .. tostring(runtime.stormstrike_id))
    -- Scan for Stormstrike if not found by ID table
    if not runtime.stormstrike_id then
        -- Try scanning common TBC+custom server Stormstrike IDs
        local alt_ids = { 17364, 17423, 17424, 17425, 32175, 32176, 38967 }
        for _, id in ipairs(alt_ids) do
            if core.spell_book.is_spell_learned(id) then
                core.log("[Eax Enh] Found Stormstrike at alt ID: " .. id)
                runtime.stormstrike_id = id
                break
            end
        end
        if not runtime.stormstrike_id then
            core.log("[Eax Enh] Stormstrike not in spellbook - is Enhancement talent learned?")
        end
    end
end

local function refresh_mode_cache()
    local me = _get_local_player()
    if not me or me:is_dead() then return end
    runtime.cached_mode = utils.detect_mode(me)
end

local function get_effective_mode()
    local selection = menu.mode:get()
    if selection == 2 then return "solo" end
    if selection == 3 then return "dungeon" end
    if selection == 4 then return "raid" end
    return runtime.cached_mode
end

local function get_mode_profile()
    local mode = get_effective_mode()
    return MODE_PROFILE[mode] or MODE_PROFILE.solo
end

local function is_gcd_ready()
    return smart_cast_manager.is_gcd_ready()
end

local function invalidate_ctx()
    rotation_context.invalidate(ctx_cache)
end

local function note_cast()
    runtime.last_cast_time = _core_time()
    invalidate_ctx()
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
    if not spell_id or not me or not me:is_valid() then return false end
    if not totem_manager.can_cast_spell(label) then
        totem_manager.try_workaround(me, label)
        return false
    end
    if is_pending_cast(spell_id) then return false end
    if not utils.can_cast_self(spell_id, me) then return false end
    if not utils.cast_self(spell_id, me) then return false end
    mark_pending_cast(spell_id)
    note_cast()
    esp_renderer.on_cast(spell_id, label, color.yellow(220), "Self")
    utils.log_debug(menu, label .. " cast")
    return true
end

local function ensure_totems(me)
    if not menu.auto_totems:get_state() then return end
    if menu.use_totem_twist and menu.use_totem_twist:get_state() then return false end
    local now = _core_time()
    for _, entry in ipairs(TOTEM_ROTATION) do
        if entry.toggle:get_state() then
            local spell_id = runtime[entry.id_field]
            if spell_id and utils.can_cast_self(spell_id, me) then
                local should_refresh = should_refresh_named_totem(entry.name, entry.slot, entry.duration)
                if should_refresh then
                    if try_cast_self(me, spell_id, entry.label) then
                        runtime.totem_last_apply[entry.name] = now
                        runtime.last_windfury_drop = now
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function try_shamanistic_rage(me, ctx)
    if not menu.use_cooldowns:get_state() or not runtime.shamanistic_rage_id then
        return false
    end
    local can_cast = resource_gate.shaman.has_mana_pct(ctx, 0.15)
    if not can_cast then
        return false
    end
    local mana_pct = utils.get_mana_pct(me)
    if mana_pct <= (menu.shamanistic_rage_mana:get() / 100) then
        return try_cast_self(me, runtime.shamanistic_rage_id, "Shamanistic Rage")
    end
    return false
end

local function try_mana_potion(me)
    if not menu.use_cooldowns:get_state() then
        return false
    end
    local mana_pct = utils.get_mana_pct(me)
    if mana_pct > 0.35 then
        return false
    end
    local now = _core_time()
    if (now - runtime.last_potion_at) < 120.0 then
        return false
    end
    for _, item_id in ipairs(MANA_POTION_IDS) do
        local cd = me:get_item_cooldown(item_id)
        if cd <= 0 and core.input.use_item(item_id) then
            runtime.last_potion_at = now
            utils.log_debug(menu, "Mana Potion (" .. tostring(item_id) .. ")")
            return true
        end
    end
    return false
end

local function try_stormstrike(me, target, ctx)
    if not runtime.stormstrike_id then
        utils.log_debug(menu, "Stormstrike: no spell ID resolved (not learned?)")
        return false
    end
    if not target then return false end
    local can_cast = resource_gate.shaman.has_mana_pct(ctx, 0.10)
    if not can_cast then
        return false
    end
    if not utils.is_melee_target(me, target) then
        utils.log_debug(menu, "Stormstrike: target not in melee range")
        return false
    end
    local cd = _get_spell_cd(runtime.stormstrike_id)
    if cd > 0 then
        utils.log_debug(menu, "Stormstrike: on cooldown " .. string.format("%.1f", cd) .. "s")
        return false
    end
    if try_cast_target(me, target, runtime.stormstrike_id, "Stormstrike") then
        runtime.last_stormstrike_at = _core_time()
        runtime.last_stormstrike_debuff_at = _core_time()
        return true
    end
    return false
end

local function should_chain_lightning_weave()
    if runtime.last_stormstrike_at == 0 then
        return false
    end
    local profile = get_mode_profile()
    local now = _core_time()
    local clip_window = math.max(menu.swing_clip_ms:get(), profile.swing_clip_ms) / 1000
    return (now - runtime.last_stormstrike_at) >= clip_window
end

local function get_swing_clip_window_s()
    local profile = get_mode_profile()
    return math.max(menu.swing_clip_ms:get(), profile.swing_clip_ms) / 1000
end

local function is_melee_swing_safe(me, extra_buffer_s)
    return swing_timer.is_swing_safe(me, get_swing_clip_window_s() + (extra_buffer_s or 0))
end

local function can_weave_chain_lightning(me)
    return swing_timer.can_cast_before_swing(me, 1.5, get_swing_clip_window_s())
end

local ENH_FLAME_SHOCK_REFRESH_MS = 3000
local ENH_EARTH_SHOCK_SHORT_TTD_S = 8.0

local function get_enh_target_ttd_seconds(target)
    if not target or not ttd_tracker or not ttd_tracker.get then return nil end
    local ok, value = pcall(function() return ttd_tracker.get(target) end)
    if not ok then return nil end
    return tonumber(value)
end

local function get_enh_debuff_remaining_ms(target, debuff_ids)
    if not target or not target:is_valid() or not debuff_ids then return 0 end
    local data = buff_manager:get_debuff_data(target, debuff_ids)
    if data and data.is_active then
        return tonumber(data.remaining or data.remaining_time or 0) or 0
    end
    return 0
end

local function try_chain_lightning_weave(me, target, ctx)
    if not menu.use_chain_lightning_weave:get_state() or not runtime.chain_lightning_id or not target then
        return false
    end
    local can_cast = resource_gate.shaman.has_mana_pct(ctx, 0.15)
    if not can_cast then
        return false
    end
    if not should_chain_lightning_weave() then return false end
    if not can_weave_chain_lightning(me) then return false end
    local profile = get_mode_profile()
    local enemies = utils.count_enemies_in_range(me, spells.CHAIN_LIGHTNING_RADIUS)
    local mana_pct = utils.get_mana_pct(me)
    if mana_pct < (profile.mana_floor / 100) then return false end
    local target_ttd = get_enh_target_ttd_seconds(target)
    local allow_single_target_weave = mana_pct >= 0.35 and target_ttd and target_ttd >= 8
    if enemies < profile.aoe_threshold and not allow_single_target_weave then return false end
    return try_cast_target(me, target, runtime.chain_lightning_id, "Chain Lightning")
end

local function try_shock(me, target, ctx)
    if not target or not utils.is_valid_hostile(me, target) then
        return false
    end
    if not is_melee_swing_safe(me) then
        return false
    end
    local shock_index = menu.shock_mode:get()
    local shock_entry = SHOCK_TABLE[shock_index]
    if not shock_entry then return false end
    local spell_id = runtime[shock_entry.id_field]
    if not spell_id then return false end
    if shock_entry.id_field == "frost_shock_id" then
        if utils.has_debuff(target, shock_entry.debuff) then return false end
    elseif shock_entry.id_field == "flame_shock_id" then
        if get_enh_debuff_remaining_ms(target, spells.DEBUFF_FLAME_SHOCK) > ENH_FLAME_SHOCK_REFRESH_MS then
            return false
        end
    elseif shock_entry.id_field == "earth_shock_id" then
        local target_ttd = get_enh_target_ttd_seconds(target)
        local short_window = target_ttd and target_ttd > 0 and target_ttd <= ENH_EARTH_SHOCK_SHORT_TTD_S
        if not has_flame_shock(target) and not short_window then
            return false
        end
    end
    return try_cast_target(me, target, spell_id, shock_entry.label)
end


-- --- Weapon Imbue Maintenance (v1.1) --------------------------------------

local IMBUE_DURATION_S = 29 * 60    -- fallback timer
local ENCHANT_REFRESH_MS = 5 * 60 * 1000

local function get_weapon_enchant_state()
    if type(GetWeaponEnchantInfo) ~= "function" then
        return nil
    end

    local ok, has_mh, mh_expiration_ms, _, _, has_oh, oh_expiration_ms = pcall(GetWeaponEnchantInfo)
    if not ok then
        return nil
    end

    return {
        has_mh = has_mh == true,
        mh_expiration_ms = tonumber(mh_expiration_ms) or 0,
        has_oh = has_oh == true,
        oh_expiration_ms = tonumber(oh_expiration_ms) or 0,
    }
end

local function enchant_needs_refresh(is_active, expiration_ms, last_applied_at)
    if is_active then
        return expiration_ms > 0 and expiration_ms <= ENCHANT_REFRESH_MS
    end

    if last_applied_at <= 0 then
        return true
    end

    return (_core_time() - last_applied_at) >= IMBUE_DURATION_S
end

local function try_cast_self_direct(me, spell_id, label, cast_color)
    if not spell_id or not me or not me:is_valid() then return false end
    if is_pending_cast(spell_id) then return false end
    if not utils.can_cast_self(spell_id, me) then return false end
    if not utils.cast_self(spell_id, me) then return false end
    mark_pending_cast(spell_id)
    note_cast()
    esp_renderer.on_cast(spell_id, label, cast_color or color.yellow(220), "Self")
    utils.log_debug(menu, label .. " cast")
    return true
end

local function try_weapon_imbues(me)
    if not utils.throttle("weapon_imbue_check", 5.0) then return false end
    if not is_melee_swing_safe(me) then return false end
    local enchant_state = get_weapon_enchant_state()

    -- Main hand: Windfury Weapon
    if runtime.windfury_weapon_id then
        local needs = enchant_needs_refresh(
            enchant_state and enchant_state.has_mh,
            enchant_state and enchant_state.mh_expiration_ms or 0,
            runtime.last_windfury_at
        )
        if needs and try_cast_self_direct(me, runtime.windfury_weapon_id, "Windfury Weapon", color.yellow(220)) then
            runtime.last_windfury_at = _core_time()
            return true
        end
    end
    -- Off hand: Flametongue Weapon
    if runtime.flametongue_weapon_id then
        local needs = enchant_needs_refresh(
            enchant_state and enchant_state.has_oh,
            enchant_state and enchant_state.oh_expiration_ms or 0,
            runtime.last_flametongue_at
        )
        if needs and try_cast_self_direct(me, runtime.flametongue_weapon_id, "Flametongue Weapon", color.orange(220)) then
            runtime.last_flametongue_at = _core_time()
            return true
        end
    end
    return false
end

-- --- Offensive CDs (v1.1) -------------------------------------------------

has_flame_shock = function(target)
    return utils.has_debuff(target, spells.DEBUFF_FLAME_SHOCK)
        or utils.has_debuff(target, spells.BUFF_FLAME_SHOCK)
        or utils.has_debuff(target, spells.FLAME_SHOCK)
end

local function try_flame_shock(me, target, ctx)
    if not runtime.flame_shock_id or not target then
        return false
    end
    if not is_melee_swing_safe(me) then
        return false
    end
    local can_cast = resource_gate.shaman.has_mana_pct(ctx, 0.10)
    if not can_cast then
        return false
    end
    if get_enh_debuff_remaining_ms(target, spells.DEBUFF_FLAME_SHOCK) > ENH_FLAME_SHOCK_REFRESH_MS then
        return false
    end
    if utils.get_mana_pct(me) < 0.20 then
        return false
    end
    return try_cast_target(me, target, runtime.flame_shock_id, "Flame Shock")
end

local function try_earth_shock(me, target, ctx)
    if not runtime.earth_shock_id or not target then
        return false
    end
    if not is_melee_swing_safe(me) then
        return false
    end
    local can_cast = resource_gate.shaman.has_mana_pct(ctx, 0.10)
    if not can_cast then
        return false
    end
    local target_ttd = get_enh_target_ttd_seconds(target)
    local short_window = target_ttd and target_ttd > 0 and target_ttd <= ENH_EARTH_SHOCK_SHORT_TTD_S
    if not has_flame_shock(target) and not short_window then
        return false
    end
    if utils.get_mana_pct(me) < 0.18 then
        return false
    end
    return try_cast_target(me, target, runtime.earth_shock_id, "Earth Shock")
end

local function try_frost_shock(me, target, ctx)
    if not runtime.frost_shock_id or not target then
        return false
    end
    if not is_melee_swing_safe(me) then
        return false
    end
    local can_cast = resource_gate.shaman.has_mana_pct(ctx, 0.10)
    if not can_cast then
        return false
    end
    if utils.has_debuff(target, spells.FROST_SHOCK) then
        return false
    end
    if utils.get_mana_pct(me) < 0.18 then
        return false
    end
    return try_cast_target(me, target, runtime.frost_shock_id, "Frost Shock")
end



-- --- Fire Totem maintenance (v1.3) ---------------------------------------
-- Maintain Searing Totem (single target) or Magma Totem (2+ enemies).
-- Totems have a 1-min duration; we re-drop when expired.

local FIRE_TOTEM_REFRESH_S = 55.0   -- re-drop 5s before expiry


-- --- Totem Twist (v1.4) ---------------------------------------------------
-- Pattern from tbc/ enhancement/rotation.go:
-- Drop Windfury Totem every 10s for the proc, then drop Grace/Wrath of Air
-- for the buff. In practice: WF first 1s, then default air totem for 9s.
-- Simple implementation: maintain WF + re-drop when expired.

local WF_TOTEM_DURATION_S   = 10.0
local AIR_TOTEM_DURATION_S  = 120.0
local TOTEM_EARLY_REFRESH_S = 5.0

local function try_totem_twist(me)
    if not menu.use_totem_twist or not menu.use_totem_twist:get_state() then return false end
    if not utils.throttle("totem_twist_check", 2.0) then return false end
    if me:is_moving() then return false end
    if not me:is_in_combat() then return false end
    if not is_melee_swing_safe(me) then return false end
    if get_effective_mode() == "solo" then return false end

    local now = _core_time()
    local time_since_wf = now - runtime.last_windfury_drop

    -- Drop Windfury Totem every 10 seconds
    if time_since_wf >= WF_TOTEM_DURATION_S and runtime.windfury_totem_id then
        if try_cast_self(me, runtime.windfury_totem_id, "Windfury Totem") then
            runtime.last_windfury_drop = now
            runtime.totem_last_apply.windfury = now
            return true
        end
    end

    -- In between WF drops: maintain Grace/Wrath of Air if not active
    if time_since_wf < 2.0 then return false end  -- just dropped WF, wait

    -- Check for Grace of Air buff on party (simplified: check self)
    local has_air_buff = utils.has_buff(me, spells.BUFF_GRACE_OF_AIR)
    local should_refresh_support_air, _ = should_refresh_named_totem("support_air", TOTEM_SLOTS.support_air, AIR_TOTEM_DURATION_S)
    should_refresh_support_air = should_refresh_support_air or (runtime.totem_last_apply.support_air or 0) <= 0
    if not has_air_buff or should_refresh_support_air then
        local air_id = runtime.wrath_of_air_id or runtime.grace_of_air_id
        if air_id and try_cast_self(me, air_id, "Wrath of Air / Grace of Air") then
            runtime.totem_last_apply.support_air = now
            return true
        end
    end

    return false
end

local function try_cure_dispels(me)
    if not menu.use_dispels or not menu.use_dispels:get_state() then return false end
    if not (runtime.cure_poison_id or runtime.cure_disease_id) then return false end
    local units = { me }
    local party_units = utils.get_party_units and utils.get_party_units(me) or {}
    for i = 1, #party_units do
        units[#units + 1] = party_units[i]
    end
    local best_target, priority = dispel_engine.find_best_target({
        candidates = units,
        priorities = {
            { type_def = { numeric = CURE_POISON_TYPE, name = "poison" }, label = "Cure Poison", spell_id = runtime.cure_poison_id },
            { type_def = { numeric = CURE_DISEASE_TYPE, name = "disease" }, label = "Cure Disease", spell_id = runtime.cure_disease_id },
        },
        get_hp = function(unit) return utils.get_health_pct(unit) end,
    })
    if best_target and priority and priority.spell_id
        and utils.can_cast_target(priority.spell_id, me, best_target)
        and utils.cast_target(priority.spell_id, me, best_target) then
        note_cast()
        utils.log_debug(menu, priority.label)
        return true
    end
    return false
end

local function try_purge(me, target)
    if not runtime.purge_id then return false end
    if not (enc and enc.force_dispel) then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    if not utils.can_cast_hostile(runtime.purge_id, me, target) then return false end
    if utils.cast_target(runtime.purge_id, me, target) then
        note_cast()
        utils.log_debug(menu, "Purge")
        return true
    end
    return false
end

-- --- Strength/Mana totem maintenance (v1.4) ------------------------------

local function try_earth_totem(me)
    if not menu.use_earth_totem or not menu.use_earth_totem:get_state() then return false end
    if me:is_moving() then return false end
    if not is_melee_swing_safe(me) then return false end
    local should_refresh, now = should_refresh_named_totem("earth_totem", TOTEM_SLOTS.earth_totem, 115.0)
    if not should_refresh then return false end
    if runtime.strength_earth_id and try_cast_self(me, runtime.strength_earth_id, "Strength of Earth Totem") then
        runtime.totem_last_apply.earth_totem = now
        return true
    end
    return false
end

local function try_water_totem(me)
    if not menu.use_water_totem or not menu.use_water_totem:get_state() then return false end
    if me:is_moving() then return false end
    if not is_melee_swing_safe(me) then return false end
    local should_refresh, now = should_refresh_named_totem("water_totem", TOTEM_SLOTS.water_totem, 115.0)
    if not should_refresh then return false end
    if runtime.mana_spring_id and try_cast_self(me, runtime.mana_spring_id, "Mana Spring Totem") then
        runtime.totem_last_apply.water_totem = now
        return true
    end
    return false
end


local function try_fire_totem(me, enemy_count)
    if not menu.use_fire_totem or not menu.use_fire_totem:get_state() then return false end
    -- Don't drop totems while moving
    if me and me.is_moving and me:is_moving() then return false end
    if not is_melee_swing_safe(me) then return false end

    -- Choose totem type by enemy count
    local use_magma = enemy_count and enemy_count >= 3
    local totem_id = (enemy_count and enemy_count >= 3)
        and runtime.magma_totem_id
        or runtime.searing_totem_id

    if not totem_id then return false end
    local label = use_magma and "Magma Totem" or "Searing Totem"
    local duration_s = use_magma and 18.0 or FIRE_TOTEM_REFRESH_S
    local should_refresh, now = should_refresh_named_totem("fire_totem", TOTEM_SLOTS.fire_totem, duration_s)
    if not should_refresh then
        return false
    end
    if try_cast_self(me, totem_id, label) then
        runtime.totem_last_apply.fire_totem = now
        return true
    end
    return false
end

-- Fire Nova Totem twist: drop Fire Nova every 15s for AoE burst
local FIRE_NOVA_CD_S = 15.0

local function try_fire_nova_twist(me, enemy_count)
    if not menu.use_fire_nova_twist or not menu.use_fire_nova_twist:get_state() then return false end
    if not runtime.fire_nova_totem_id then return false end
    if enemy_count and enemy_count < 3 then return false end
    if me:is_moving() then return false end
    if not is_melee_swing_safe(me) then return false end
    local now = _core_time()
    if (now - runtime.last_fire_nova_drop) < FIRE_NOVA_CD_S then return false end
    if try_cast_self(me, runtime.fire_nova_totem_id, "Fire Nova Totem") then
        runtime.last_fire_nova_drop = now
        return true
    end
    return false
end



-- -- Shield maintenance --------------------------------------------------------
local function ensure_shield(me)
    local mode = menu.shield_mode and menu.shield_mode:get() or 3
    if mode == 0 then return false end
    -- Auto mode: Lightning Shield for Enhancement (melee DPS), Water at 60+
    local use_water
    if mode == 1 then use_water = false
    elseif mode == 2 then use_water = true
    else use_water = (me:get_level() or 0) >= 60 end

    if use_water and runtime.water_shield_id then
        if not utils.has_buff(me, spells.BUFF_WATER_SHIELD) then
            return try_cast_self(me, runtime.water_shield_id, "Water Shield")
        end
    elseif not use_water and runtime.lightning_shield_id then
        local ls = buff_manager:get_buff_data(me, spells.BUFF_LIGHTNING_SHIELD)
        local ls_stacks = (ls and ls.is_active and (ls.stacks or ls.count or 0)) or 0
        if (not ls or not ls.is_active) or ls_stacks < LIGHTNING_SHIELD_STACK_FLOOR then
            return try_cast_self(me, runtime.lightning_shield_id, "Lightning Shield")
        end
    end
    return false
end

-- -- Self-healing --------------------------------------------------------------
local function try_self_heal(me)
    if not menu.use_healing_wave or not menu.use_healing_wave:get_state() then return false end
    local hp_pct = utils.get_health_pct(me)
    local threshold = (menu.healing_wave_hp and menu.healing_wave_hp:get() or 40) / 100
    if hp_pct > threshold then return false end
    -- Prefer Lesser Healing Wave (faster cast, less mana) if available
    local prefer_lhw = menu.use_lesser_healing_wave and menu.use_lesser_healing_wave:get_state()
    if prefer_lhw and runtime.lesser_hw_id then
        return try_cast_self(me, runtime.lesser_hw_id, "Lesser Healing Wave")
    end
    if runtime.healing_wave_id then
        return try_cast_self(me, runtime.healing_wave_id, "Healing Wave")
    end
    return false
end

-- -- Ghost Wolf OOC ------------------------------------------------------------
local GHOST_WOLF_BUFF = { 2645 }
local function try_ghost_wolf(me)
    if not menu.use_ghost_wolf or not menu.use_ghost_wolf:get_state() then return false end
    if not runtime.ghost_wolf_id then return false end
    if me:is_in_combat() then return false end
    if utils.has_buff(me, GHOST_WOLF_BUFF) then return false end
    if eax_utils.is_eating_or_drinking(me) then return false end
    local ok, casting = pcall(function() return me:is_casting_spell() end)
    if ok and casting then return false end
    local ok2, channing = pcall(function() return me:is_channelling_spell() end)
    if ok2 and channing then return false end
    return try_cast_self(me, runtime.ghost_wolf_id, "Ghost Wolf")
end

-- -- Lightning Bolt ranged pull ------------------------------------------------
local function try_lb_pull(me, target)
    if not menu.use_lb_pull or not menu.use_lb_pull:get_state() then return false end
    if not runtime.lightning_bolt_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not utils.is_valid_hostile(me, target) then return false end
    local pull_range = menu.lb_pull_range and menu.lb_pull_range:get() or 25
    local dist = utils.get_distance(me, target)
    if dist < pull_range then return false end  -- close enough to melee, skip
    return try_cast_target(me, target, runtime.lightning_bolt_id, "Lightning Bolt (Pull)")
end

local function do_rotation(me, target)
    -- Lazy re-resolve: spells may not be learned yet at plugin load time
    if not runtime.stormstrike_id then resolve_spells() end
    if not is_gcd_ready() then return false end
    local ctx = rotation_context.get(ctx_cache, me, target, {
        now_s = _core_time,
    })
    -- Interrupt (Earth Shock / Wind Shear)
    if target and interrupt_manager.should_interrupt(target) then
        if menu.use_interrupt:get_state() and interrupt_manager.try_interrupt(me, target, "shaman", utils) then
            return true
        end
    end


    -- Mana conservation (leveling 1-70)
    if leveling_manager.is_conserving_mana(me, menu) then
        leveling_manager.ensure_melee(me, target)
    end
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
    if defensive_manager.try_defensive(me, "shaman", utils) then
        return true
    end

    if try_cure_dispels(me) then return true end
    if try_purge(me, target) then return true end

    -- Weapon imbues (out of combat / throttled)
    try_weapon_imbues(me)

    -- TTD tracking
    ttd_tracker.update(target)

    -- Offensive CDs
    if try_mana_potion(me) then return true end
    if try_shamanistic_rage(me, ctx) then return true end
    if try_stormstrike(me, target, ctx) then return true end
    local shock_mode = menu.shock_mode and menu.shock_mode:get() or 1
    -- Flame Shock maintenance (always, not shock_mode gated)
    if try_flame_shock(me, target, ctx) then return true end
    -- Shock filler (based on shock_mode)
    if shock_mode == 1 and try_earth_shock(me, target, ctx) then return true end
    if shock_mode == 2 and try_frost_shock(me, target, ctx) then return true end
    if try_chain_lightning_weave(me, target, ctx) then return true end
    if try_shock(me, target, ctx) then return true end

    if ensure_totems(me) then return true end
    -- Totem maintenance
    local _enh_enemies = utils.enemy_count_in_radius and utils.enemy_count_in_radius(me, 10) or 1
    if try_totem_twist(me) then return true end
    if try_fire_nova_twist(me, _enh_enemies) then return true end
    if try_fire_totem(me, _enh_enemies) then return true end
    if try_earth_totem(me) then return true end
    if try_water_totem(me) then return true end
    -- Auto-attack fallback for leveling 1-70
    if me:is_in_combat() and target and target:is_valid() and not target:is_dead()
       and me:can_attack(target) then
        leveling_manager.ensure_melee(me, target)
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
    spec = "EAXShamanEnhancement",
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

                return menu.use_interrupt:get_state() and interrupt_manager.try_interrupt(action_deps.me, interrupt_target, "shaman", utils)
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
    if not me or me:is_dead() then return end

    if utils.throttle("mode_refresh", MODE_REFRESH_INTERVAL) then
        refresh_mode_cache()
    end
    if utils.throttle("set_bonus", 5.0) then
        update_set_bonus()
    end
    handle_toggle()
    if not menu.enabled:get_state() then return end

    -- OOC management (drink/eat/rez/group buffs)
    ooc_manager.on_update(me, menu, utils, {
        rez_spell_id = runtime.ancestral_spirit_id,
        show_enchant_warning = true,
    })
    if menu.auto_ooc_food_drink and menu.auto_ooc_food_drink:get_state() then
        consumables_manager.try_use_ooc_food_drink(me, menu, utils)
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
    local focus_target = eax_utils.get_focus_target(menu)
    -- Validate focus target is hostile; if not, fall through to smart selector
    if focus_target and not me:can_attack(focus_target) then focus_target = nil end
    -- Smart target selection: prioritize units actively fighting us/party
    local target = focus_target or utils.find_best_target(me)
    -- PvP: prioritize enemy players in arena/BG/world PvP
    local pvp_instance = pvp_manager.is_in_pvp_instance()
    if pvp_instance or pvp_manager.is_world_pvp(me) then
        local enemy_players = pvp_manager.find_enemy_players(me, 40)
        if #enemy_players > 0 then
            local priority = pvp_manager.priority_target(me, enemy_players)
            if priority then target = priority end
        end
    end
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = utils.get_health_pct(me)
    if my_hp < self_threshold then
        -- Enhancement self-heal: use Lesser Healing Wave if learned, else skip
        -- (Shamanistic Rage handles mana-based self-sustain; NS is not in this rotation)
        local lhw_id = utils.resolve_spell_id({ 25420, 10468, 10467, 10466, 8010, 8008, 8004 })
        if lhw_id and try_cast_self(me, lhw_id, "Lesser Healing Wave") then
            return
        end
    end
    -- OOC: ghost wolf
    if not me:is_in_combat() then
        try_ghost_wolf(me)
    end

    do_rotation(me, target)
end)


-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxshamanenhancement_space_win")
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
            local nxt = control_panel_utility:insert_key_checkbox_(
                elements, label, cur, 0, false, uid)
            if nxt ~= cur then item:set(nxt) end
        end
        local toggle_key = menu.toggle_key:get_key_code()
        local label = "[Eax Shaman Enhancement] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        local function add_kb(lbl, kb)
            if not kb then return end
            control_panel_utility:insert_toggle_(elements, lbl, kb, false)
        end
        add_cb(label,                           menu.enabled,                   "eax_enh_enabled_cp")
        return elements
    end)
end



-- -- Eax Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Shaman"
    local _eax_spec  = "Enhancement"
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

core.log("[Eax Shaman Enhancement] Loaded")
