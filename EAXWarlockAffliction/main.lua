-- main.lua
-- Eax Warlock Affliction | Rotation logic

local menu = require("libraries/menu")
local rotation_context = require("libraries/rotation_context")
local resource_gate = require("libraries/resource_gate")
local spell_downrank = require("libraries/spell_downrank")
local spells = require("libraries/spells")
local utils = require("libraries/utils")

if not utils.same_unit then
    function utils.same_unit(a, b)
        return a ~= nil and a == b
    end
end
local eax_utils = require("libraries/eax_utils")
local color     = require("libraries/color")

---@type interrupt_manager
local interrupt_manager = require("libraries/interrupt_manager")
---@type ooc_manager
local ooc_manager = require("libraries/ooc_manager")

---@type consumables_manager
local consumables_manager = require("libraries/consumables_manager")

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


---@type esp_renderer
local esp_renderer = require("libraries/esp_renderer")
esp_renderer.init("affli", "Warlock Affli")
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
        spec = "EAXWarlockAffliction",
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

---@type mana_conservator
local mana_conservator = require("libraries/mana_conservator")
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
    unstable_affliction_id = nil,
    corruption_id = nil,
    siphon_life_id = nil,
    curse_agony_id = nil,
    curse_doom_id = nil,
    drain_soul_id = nil,
    shadow_bolt_id = nil,
    life_tap_id = nil,
    howl_of_terror_id = nil,
    seed_of_corruption_id = nil,
    last_cast_time = 0,
    pending_casts = {},
    cached_mode = "solo",
    prev_toggle_state = false,
    set_multiplier = 1.0,
    nightfall_active = false,
    -- Warlock utility
    soulstone_id = nil,
    create_healthstone_id = nil,
    create_soulstone_id = nil,
    last_healthstone_create = 0,
    last_soulstone_apply = 0,
}

local ctx_cache = rotation_context.new({})

local GCD_INTERVAL_S = 0.05
local PENDING_CAST_TIMEOUT_S = 2.5
local DOT_REFRESH_MS = 3000
local CURSE_REFRESH_MS = 2000
local LIFE_TAP_MANA_PCT = 0.45
local DRAIN_SOUL_HP_PCT = 0.25

local function resolve_spells()
    runtime.fel_armor_id          = utils.resolve_spell_id(spells.FEL_ARMOR)
    runtime.curse_of_elements_id  = utils.resolve_spell_id(spells.CURSE_OF_ELEMENTS)
    runtime.death_coil_id         = utils.resolve_spell_id(spells.DEATH_COIL)
    runtime.unstable_affliction_id = utils.resolve_spell_id(spells.UNSTABLE_AFFLICTION)
    runtime.corruption_id = utils.resolve_spell_id(spells.CORRUPTION)
    runtime.siphon_life_id = utils.resolve_spell_id(spells.SIPHON_LIFE)
    runtime.curse_agony_id = utils.resolve_spell_id(spells.CURSE_OF_AGONY)
    runtime.curse_doom_id = utils.resolve_spell_id(spells.CURSE_OF_DOOM)
    runtime.drain_soul_id = utils.resolve_spell_id(spells.DRAIN_SOUL)
    runtime.shadow_bolt_id = utils.resolve_spell_id(spells.SHADOW_BOLT)
    runtime.life_tap_id       = utils.resolve_spell_id(spells.LIFE_TAP)
    runtime.howl_of_terror_id     = utils.resolve_spell_id(spells.HOWL_OF_TERROR)
    runtime.seed_of_corruption_id = utils.resolve_spell_id(spells.SEED_OF_CORRUPTION)
    runtime.soulstone_id = utils.resolve_spell_id(spells.SOULSTONE)
    runtime.create_healthstone_id = utils.resolve_spell_id(spells.CREATE_HEALTHSTONE)
    runtime.create_soulstone_id = utils.resolve_spell_id(spells.CREATE_SOULSTONE)
end

local function log_spells()
    core.log("[Eax Warlock Affliction] Resolved spells: UA=" .. tostring(runtime.unstable_affliction_id)
        .. " CORR=" .. tostring(runtime.corruption_id)
        .. " SL=" .. tostring(runtime.siphon_life_id)
        .. " Curse=" .. tostring(runtime.curse_agony_id or runtime.curse_doom_id)
        .. " DS=" .. tostring(runtime.drain_soul_id)
        .. " SB=" .. tostring(runtime.shadow_bolt_id))
end

resolve_spells()
log_spells()

local function target_has_utility_curse(target)
    return target and (
        utils.has_debuff(target, spells.DEBUFF_CURSE_OF_ELEMENTS)
        or utils.has_debuff(target, spells.DEBUFF_CURSE_OF_WEAKNESS)
        or utils.has_debuff(target, spells.DEBUFF_CURSE_OF_TONGUES)
        or utils.has_debuff(target, spells.DEBUFF_CURSE_OF_RECKLESSNESS)
    )
end

local function update_set_bonus()
    local me = _get_local_player()
    if not me then return end
    
    local voidheart_mult = utils.get_set_multiplier(me, "Voidheart")
    local voidheart_regalia_mult = utils.get_set_multiplier(me, "VoidheartRegalia")
    local malefic_mult = utils.get_set_multiplier(me, "Malefic")
    
    runtime.set_multiplier = voidheart_mult
    if voidheart_regalia_mult > runtime.set_multiplier then
        runtime.set_multiplier = voidheart_regalia_mult
    end
    if malefic_mult > runtime.set_multiplier then
        runtime.set_multiplier = malefic_mult
    end
    
    if runtime.set_multiplier > 1.0 then
        utils.log_debug(menu, "Set bonus: " .. tostring(runtime.set_multiplier))
    end
end

local function check_nightfall(me)
    runtime.nightfall_active = utils.has_buff(me, spells.BUFF_NIGHTFALL)
    return runtime.nightfall_active
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

local function get_effective_mode()
    local idx = menu.mode:get()
    if idx == 2 then
        return "solo"
    elseif idx == 3 then
        return "dungeon"
    elseif idx == 4 then
        return "raid"
    end
    return runtime.cached_mode
end

local function refresh_mode_cache()
    local me = _get_local_player()
    if not me then
        return
    end
    runtime.cached_mode = utils.detect_mode(me) or runtime.cached_mode or "solo"
end

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        menu.enabled:set(not menu.enabled:get_state())
        utils.log_debug(menu, "Toggle -> " .. tostring(menu.enabled:get_state()))
    end
    runtime.prev_toggle_state = current
end

local function is_valid_target(me, target)
    if not me or not target then
        return false
    end
    if not target:is_valid() or target:is_dead() then
        return false
    end
    return me:can_attack(target)
end

local function should_refresh_debuff(target, debuff_ids, threshold_ms)
    if not target or not debuff_ids then
        return true
    end
    local remaining = utils.get_debuff_remaining_ms(target, debuff_ids)
    return remaining <= threshold_ms
end

local function is_within_range(a, b, max_range)
    if not a or not b or not max_range then
        return false
    end

    local ok_a, pos_a = pcall(function() return a:get_position() end)
    local ok_b, pos_b = pcall(function() return b:get_position() end)
    if not ok_a or not ok_b or not pos_a or not pos_b then
        return false
    end

    local dx = pos_a.x - pos_b.x
    local dy = pos_a.y - pos_b.y
    local dz = pos_a.z - pos_b.z
    return (dx * dx + dy * dy + dz * dz) <= (max_range * max_range)
end


local function try_fel_armor(me)
    if not runtime.fel_armor_id then return false end
    if utils.has_buff(me, spells.BUFF_FEL_ARMOR) then return false end
    if not utils.can_cast_self(runtime.fel_armor_id, me) then return false end
    if utils.cast_self(runtime.fel_armor_id, me) then
        invalidate_ctx()
        utils.log_debug(menu, "Fel Armor")
        return true
    end
    return false
end

local function try_curse_of_elements(me, target)
    if not menu.use_curse_of_elements or not menu.use_curse_of_elements:get_state() then return false end
    if not runtime.curse_of_elements_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if target_has_utility_curse(target) and not utils.has_debuff(target, spells.DEBUFF_CURSE_OF_ELEMENTS) then return false end
    if utils.has_debuff(target, spells.DEBUFF_CURSE_OF_ELEMENTS) then return false end
    if not utils.can_cast_hostile(runtime.curse_of_elements_id, me, target) then return false end
    if utils.cast_target(runtime.curse_of_elements_id, target) then
        invalidate_ctx()
        utils.log_debug(menu, "Curse of Elements")
        return true
    end
    return false
end

local function try_death_coil(me, target)
    if not menu.use_death_coil or not menu.use_death_coil:get_state() then return false end
    if not runtime.death_coil_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    local hp = me:get_health_percentage() / 100
    if hp > 0.40 then return false end  -- defensive
    if not utils.can_cast_hostile(runtime.death_coil_id, me, target) then return false end
    if utils.cast_target(runtime.death_coil_id, target) then
        invalidate_ctx()
        utils.log_debug(menu, "Death Coil (defensive)")
        return true
    end
    return false
end

local function try_cast_spell(me, spell_id, target, label)
    if not spell_id then
        return false
    end
    if is_pending_cast(spell_id) then
        return false
    end
    if not utils.can_cast_hostile(spell_id, me, target) then
        return false
    end
    if utils.cast_target(spell_id, target) then
        mark_pending_cast(spell_id)
        note_cast()
        utils.log_debug(menu, label .. " -> cast")
        return true
    end
    return false
end


local function try_seed_of_corruption(me, target, enemy_count)
    if enc and not enc.aoe_safe then return false end
    if not menu.use_seed_of_corruption or not menu.use_seed_of_corruption:get_state() then return false end
    if not runtime.seed_of_corruption_id then return false end
    if (enemy_count or 1) < 3 then return false end
    if me:is_moving() then return false end
    if utils.has_debuff(target, spells.DEBUFF_SEED_OF_CORRUPTION) then return false end
    if not utils.can_cast_hostile(runtime.seed_of_corruption_id, me, target) then return false end
    if utils.cast_target(runtime.seed_of_corruption_id, target, "Seed of Corruption") then
        utils.log_debug(menu, "Seed of Corruption (AoE)")
        return true
    end
    return false
end


local function try_refresh_dots(me, target)
    if menu.use_unstable_affliction:get_state()
        and dot_manager.can_refresh_dot(target, spells.UNSTABLE_AFFLICTION, runtime.unstable_affliction_id, utils.get_debuff_remaining_ms) then
        if try_cast_spell(me, runtime.unstable_affliction_id, target, "Unstable Affliction") then
            esp_renderer.on_cast(nil, "Refresh DoTs", color.purple(220))
            return true
        end
    end
    if menu.use_corruption:get_state()
        and dot_manager.can_refresh_dot(target, spells.CORRUPTION, runtime.corruption_id, utils.get_debuff_remaining_ms) then
        if try_cast_spell(me, runtime.corruption_id, target, "Corruption") then
            return true
        end
    end
    -- Siphon Life: only refresh if UA and Corruption are stable (not about to expire)
    if menu.use_siphon_life:get_state() then
        local ua_stable = not runtime.unstable_affliction_id or utils.get_debuff_remaining_ms(target, spells.UNSTABLE_AFFLICTION) > 3000
        local corr_stable = not runtime.corruption_id or utils.get_debuff_remaining_ms(target, spells.CORRUPTION) > 3000
        if ua_stable and corr_stable and dot_manager.can_refresh_dot(target, spells.SIPHON_LIFE, runtime.siphon_life_id, utils.get_debuff_remaining_ms) then
            if try_cast_spell(me, runtime.siphon_life_id, target, "Siphon Life") then
                return true
            end
        end
    end
    return false
end

local function target_has_utility_curse(target)
    return target and (
        utils.has_debuff(target, spells.DEBUFF_CURSE_OF_ELEMENTS)
        or utils.has_debuff(target, spells.DEBUFF_CURSE_OF_WEAKNESS)
        or utils.has_debuff(target, spells.DEBUFF_CURSE_OF_TONGUES)
        or utils.has_debuff(target, spells.DEBUFF_CURSE_OF_RECKLESSNESS)
    )
end

local function target_prefers_caster_curse(target)
    if not target or not target:is_valid() or target:is_dead() then
        return false
    end
    if target.is_casting_spell and target:is_casting_spell() then
        return true
    end
    if target.is_channelling_spell and target:is_channelling_spell() then
        return true
    end
    if target.get_max_power then
        local ok, max_mana = pcall(function() return target:get_max_power(0) end)
        if ok and type(max_mana) == "number" and max_mana > 0 then
            return true
        end
    end
    return false
end

local function should_hold_filler_for_dot_refresh(target)
    if not target or not target:is_valid() or target:is_dead() then
        return false
    end
    local refresh_window_ms = 2500
    if menu.use_unstable_affliction:get_state() and runtime.unstable_affliction_id
        and utils.get_debuff_remaining_ms(target, spells.UNSTABLE_AFFLICTION) <= refresh_window_ms then
        return true
    end
    if menu.use_corruption:get_state() and runtime.corruption_id
        and utils.get_debuff_remaining_ms(target, spells.CORRUPTION) <= refresh_window_ms then
        return true
    end
    if menu.use_siphon_life:get_state() and runtime.siphon_life_id
        and utils.get_debuff_remaining_ms(target, spells.SIPHON_LIFE) <= refresh_window_ms then
        return true
    end
    return false
end

local function get_selected_curse(mode, target)
    local in_group_content = mode == "dungeon" or mode == "raid"
    if in_group_content and runtime.curse_of_elements_id then
        return runtime.curse_of_elements_id, spells.DEBUFF_CURSE_OF_ELEMENTS, "Curse of Elements", true
    end

    local ttd_s = visual_get_ttd_seconds(target)
    if menu.prefer_doom:get_state() and runtime.curse_doom_id and type(ttd_s) == "number" and ttd_s >= 60 then
        return runtime.curse_doom_id, spells.DEBUFF_CURSE_OF_DOOM, "Curse of Doom", false
    end

    if runtime.curse_agony_id then
        return runtime.curse_agony_id, spells.DEBUFF_CURSE_OF_AGONY, "Curse of Agony", false
    end

    if runtime.curse_doom_id then
        return runtime.curse_doom_id, spells.DEBUFF_CURSE_OF_DOOM, "Curse of Doom", false
    end

    return nil, nil, nil, false
end

local function try_apply_curse(me, target, mode)
    if not menu.use_curse:get_state() then return false end
    local curse_id, debuff_ids, label, selected_is_utility = get_selected_curse(mode, target)
    if not curse_id or not debuff_ids then return false end
    if selected_is_utility then
        if target_has_utility_curse(target) and not utils.has_debuff(target, debuff_ids) then return false end
    elseif target_has_utility_curse(target) then
        return false
    end
    
    -- Use dot_manager to check if safe to refresh (never clip final tick)
    if not dot_manager.can_refresh_dot(target, debuff_ids, curse_id, utils.get_debuff_remaining_ms) then
        return false
    end
    
    -- Amplify Curse before casting for +doom/+agony duration (v1.3)
    if not selected_is_utility and runtime.amplify_curse_id and utils.can_cast_self(runtime.amplify_curse_id, me) then
        utils.cast_self_fast(runtime.amplify_curse_id, me)
        utils.log_debug(menu, "Amplify Curse")
    end
    return try_cast_spell(me, curse_id, target, label or "Curse")
end

local function try_execute(me, target)
    if not runtime.drain_soul_id or not target or not target:is_valid() or target:is_dead() then
        return false
    end
    local hp_pct = utils.get_health_pct(target)
    if hp_pct > DRAIN_SOUL_HP_PCT then
        return false
    end
    if not menu.use_drain_soul:get_state() then
        return false
    end
    local ttd_s = nil
    if ttd_tracker and ttd_tracker.get then
        local ok, value = pcall(function() return ttd_tracker.get(target) end)
        if ok then ttd_s = tonumber(value) end
    end
    -- Don't channel if target will die before channel finishes (~3s)
    if ttd_s and ttd_s > 0 and ttd_s < 3 then
        return false
    end
    if ttd_s and ttd_s > 0 then
        local commit_window_s = 2.0
        if ttd_s < commit_window_s then
            return false
        end
        if ttd_s > 6 and should_hold_filler_for_dot_refresh(target) then
            return false
        end
    end
    return try_cast_spell(me, runtime.drain_soul_id, target, "Drain Soul")
end

local function try_filler(me, target)
    if should_hold_filler_for_dot_refresh(target) then
        return false
    end
    if menu.use_shadow_bolt:get_state() then
        -- Leveling: use appropriate spell rank
        local shadow_bolt_id = runtime.shadow_bolt_id
        if menu.leveling_conserve_mana and menu.leveling_conserve_mana:get_state() then
            local player_level = me.get_level and me:get_level() or 70
            local target_level = target.get_level and target:get_level() or 70
            local mana_pct = utils.get_mana_pct(me)
            shadow_bolt_id = spell_downrank.select_dps_rank(spells.SHADOW_BOLT, target_level, player_level, mana_pct) or shadow_bolt_id
        end
        local cast_time_ms = mana_manager.get_spell_cast_time_ms(shadow_bolt_id)
        local cast_time_s = cast_time_ms / 1000
        local ttd_s = nil
        if ttd_tracker and ttd_tracker.get then
            local ok, value = pcall(function() return ttd_tracker.get(target) end)
            if ok then ttd_s = tonumber(value) end
        end
        if ttd_s and ttd_s > 0 and ttd_s < (cast_time_s + 0.5) then
            return false
        end
        -- Nightfall: prioritize instant Shadow Bolt
        if check_nightfall(me) then
            return try_cast_spell(me, shadow_bolt_id, target, "Shadow Bolt (Nightfall)")
        end
        return try_cast_spell(me, shadow_bolt_id, target, "Shadow Bolt")
    end
    return false
end

local function try_life_tap(me)
    if not menu.use_life_tap:get_state() or not runtime.life_tap_id then
        return false
    end
    local mana_pct = utils.get_mana_pct(me)
    -- Pre-regen: also tap when a major CD (Corruption, UA) coming off CD soon
    -- and we need mana to sustain, even if above the normal threshold
    local pre_regen_needed = mana_pct < 0.50
    -- Use mana_manager for clip-safe life tap (HP + mana + cooldown checks)
    if not mana_manager.should_life_tap(me, menu) and not pre_regen_needed then
        return false
    end
    if not utils.can_cast_self(runtime.life_tap_id, me) then
        return false
    end
    if utils.cast_self(runtime.life_tap_id, me) then
        runtime.last_cast_time = _core_time()
        utils.log_debug(menu, "Life Tap")
                esp_renderer.on_cast(runtime.life_tap_id, "Shadow Bolt", color.new(180,100,220,220))
                esp_renderer.on_cast(runtime.life_tap_id, "Drain Soul", color.green(220))
        return true
    end
    return false
end


-- --- Howl of Terror (v1.2) ------------------------------------------------

local function try_howl_of_terror(me)
    if not menu.use_howl_of_terror or not menu.use_howl_of_terror:get_state() then return false end
    if not runtime.howl_of_terror_id then return false end
    local hp = me:get_health_percentage() / 100
    if hp > 0.40 then return false end
    -- Only worth using if multiple enemies are attacking us
    local melee_attackers = 0
    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead()
           and me:can_attack(obj) and is_within_range(me, obj, 10) then
            melee_attackers = melee_attackers + 1
        end
    end
    if melee_attackers < 1 then return false end
    if not utils.can_cast_self(runtime.howl_of_terror_id, me) then return false end
    if utils.cast_self(runtime.howl_of_terror_id, me) then
        utils.log_debug(menu, "Howl of Terror")
        return true
    end
    return false
end



-- --- Pet selection + management (v1.4) ------------------------------------

local PET_NPC_IDS = {
    imp = 416,
    voidwalker = 1860,
    succubus = 1863,
    felhunter = 417,
    felguard = 17252,
}

local SUMMON_SPELLS = {
    imp        = spells.SUMMON_IMP,
    voidwalker = spells.SUMMON_VOIDWALKER,
    succubus   = spells.SUMMON_SUCCUBUS,
    felhunter  = spells.SUMMON_FELHUNTER,
    felguard   = spells.SUMMON_FELGUARD,
}

local PET_REQUIRES_SHARD = {
    imp = false,
    voidwalker = true,
    succubus = true,
    felhunter = true,
    felguard = true,
}

local count_soul_shards

local function get_pet_npc_id()
    local me = _get_local_player()
    if not me then return 0 end
    local pet = me.get_pet and me:get_pet() or nil
    if not pet or not pet:is_valid() or pet:is_dead() then return 0 end
    return pet.get_npc_id and pet:get_npc_id() or 0
end

local function current_pet_name()
    local npc = get_pet_npc_id()
    for name, id in pairs(PET_NPC_IDS) do
        if npc == id then return name end
    end
    return "none"
end

local function desired_pet_name(mode)
    local pet_mode = menu.preferred_pet and menu.preferred_pet:get() or 1
    if pet_mode == 2 then return "imp" end
    if pet_mode == 3 then return "voidwalker" end
    if pet_mode == 4 then return "succubus" end
    if pet_mode == 5 then return "felhunter" end
    if pet_mode == 6 then return "felguard" end
    return nil
end

local function try_summon_correct_pet(me, mode)
    if me:is_in_combat() then return false end  -- never summon mid-combat
    if not utils.throttle("warlock_pet_check", 5.0) then return false end

    local current = current_pet_name()
    local desired = desired_pet_name(mode)
    if not desired then return false end

    if current == desired then return false end  -- already correct

    local spell_table = SUMMON_SPELLS[desired]
    if not spell_table then return false end
    local spell_id = utils.resolve_spell_id(spell_table)
    if not spell_id then return false end
    if PET_REQUIRES_SHARD[desired] and count_soul_shards() < 1 then
        if utils.throttle("eax_affliction_pet_shard_warning", 10.0) then
            core.log("[Eax Warlock Affliction] Cannot summon " .. desired .. ": need at least 1 Soul Shard.")
            core.graphics.add_notification(
                "eax_affliction_pet_shard_warning",
                "[EAX] Pet Summon Blocked",
                "Cannot summon " .. desired .. ": need at least 1 Soul Shard.",
                6.0,
                require("common/color").new(255, 180, 80, 255)
            )
        end
        return false
    end
    if not utils.can_cast_self(spell_id, me) then return false end

    utils.cast_self(spell_id, me)
    utils.log_debug(menu, "Summoning " .. desired)
    return true
end

-- --- Soul Shard farming (v1.4) --------------------------------------------
-- Use Drain Soul on targets below 10% HP to collect shards

local SHARD_FARM_HP_PCT = 0.10
local SHARD_ITEM_IDS = { 6265 }  -- Soul Shard (stacks, any version)

count_soul_shards = function()
    if not core or not core.inventory or not core.inventory.get_items_in_bag then
        return 0
    end

    local total = 0
    for bag = 0, 4 do
        local ok, items = pcall(function()
            return core.inventory.get_items_in_bag(bag)
        end)
        if ok and items then
            for _, slot in ipairs(items) do
                local item = slot and slot.object
                if item and item.is_valid and item:is_valid() and item.get_item_id and item:get_item_id() == 6265 then
                    if item.get_item_stack_count then
                        total = total + (item:get_item_stack_count() or 1)
                    else
                        total = total + 1
                    end
                end
            end
        end
    end
    return total
end

local function try_soul_shard_farm(me, target, drain_soul_id)
    if not menu.auto_shard_farm or not menu.auto_shard_farm:get_state() then return false end
    if not drain_soul_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    local hp = utils.get_health_pct(target)
    if hp > SHARD_FARM_HP_PCT then return false end
    -- Only farm if below the shard threshold set in menu
    local min_shards = menu.min_shards and menu.min_shards:get() or 3
    if count_soul_shards() >= min_shards then return false end
    if not utils.can_cast_hostile(drain_soul_id, me, target) then return false end
    if utils.cast_target(drain_soul_id, target, "Drain Soul (shard)") then
        utils.log_debug(menu, "Drain Soul for shard farm")
        return true
    end
    return false
end


local function do_rotation(me, target)
    if mana_conservator.on_update(me, target, menu, utils) then return end
    if not is_gcd_ready() then
        return
    end
    
    local deps = { now_s = _core_time, get_gcd = _get_gcd }
    local ctx = rotation_context.get(ctx_cache, me, target, deps)

    -- Interrupt (Shadowfury - if available)
    if target and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "warlock", utils) then
            return
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

    if (me:is_casting_spell() or me:is_channelling_spell()) and dps_risk.should_abort_commit(
        dps_runtime.build_snapshot(me, target, encounter_manager, ttd_tracker),
        {
            kind = me:is_channelling_spell() and "channel" or "cast",
            progress_pct = 0.20,
            remaining_s = 1.0,
            projected_damage_pct = 0.06,
        }
    ) then
        if SpellStopCasting then
            SpellStopCasting()
            return true
        end
    end

    if defensive_manager.try_defensive(me, "warlock", utils) then
        return
    end

    -- Threat fade protection - don't pull aggro from tank
    if me:is_in_combat() then
        local current_target = me:get_target()
        local ok, should_fade = pcall(function() return threat_manager.should_fade(me, current_target) end)
        if ok and should_fade and dps_risk.should_drop_threat(dps_runtime.build_snapshot(me, current_target, encounter_manager, ttd_tracker)) then
            pcall(function() threat_manager.try_fade(me) end)
            return
        end
    end

    -- Mana potion check (before main damage spells)
    if mana_manager.should_use_mana_potion(me, 30) then
        if mana_manager.use_mana_potion() then
            return
        end
    end

    local refresh_dots = ctx and resource_gate.common.has_mana_pct(ctx, 0.12) and try_refresh_dots(me, target)
    if refresh_dots then
        return
    end

    local effective_mode = get_effective_mode()

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.10) and try_apply_curse(me, target, effective_mode) then
        return
    end

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.10) then
        if try_soul_shard_farm(me, target, runtime.drain_soul_id) then
            return
        end
        if try_execute(me, target) then
            return
        end
    end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and try_filler(me, target) then
        return
    end
    try_life_tap(me)
end

-- --- Warlock Utility: Soulstone, Healthstone, Self-Soulstone (v1.0) --------

local SOULSTONE_COOLDOWN_S = 1800  -- 30 min CD
local HEALTHSTONE_COOLDOWN_S = 120  -- 2 min CD
local HEALTHSTONE_USE_HP = 0.50

local function try_create_healthstone(me)
    if not menu.use_create_healthstone or not menu.use_create_healthstone:get_state() then return false end
    if not runtime.create_healthstone_id then return false end
    if me:is_in_combat() then return false end
    if me:is_moving() then return false end
    local now = _core_time()
    if (now - runtime.last_healthstone_create) < HEALTHSTONE_COOLDOWN_S then return false end
    -- Check if we already have a healthstone in inventory
    local has_healthstone = false
    for _, item_id in ipairs(spells.HEALTHSTONE_ITEMS) do
        if core.inventory and core.inventory.get_item_count then
            local count = core.inventory.get_item_count(item_id)
            if count and count > 0 then has_healthstone = true; break end
        end
    end
    if has_healthstone then return false end
    if not utils.can_cast_self(runtime.create_healthstone_id, me) then return false end
    if utils.cast_self(runtime.create_healthstone_id, me) then
        runtime.last_healthstone_create = now
        utils.log_debug(menu, "Create Healthstone")
        return true
    end
    return false
end

local function try_use_healthstone(me)
    if not menu.use_create_healthstone or not menu.use_create_healthstone:get_state() then return false end
    if not me:is_in_combat() then return false end
    local hp = utils.get_health_pct(me)
    if hp > HEALTHSTONE_USE_HP then return false end
    for _, item_id in ipairs(spells.HEALTHSTONE_ITEMS) do
        if core.inventory and core.inventory.get_item_count then
            local count = core.inventory.get_item_count(item_id)
            if count and count > 0 then
                if core.input.use_item(item_id) then
                    utils.log_debug(menu, "Use Healthstone (HP=" .. math.floor(hp * 100) .. "%)")
                    return true
                end
            end
        end
    end
    return false
end

local function try_soulstone_dead_ally(me)
    if not menu.use_soulstone or not menu.use_soulstone:get_state() then return false end
    if not runtime.soulstone_id then return false end
    if me:is_in_combat() then return false end
    if me:is_moving() then return false end
    local now = _core_time()
    if (now - runtime.last_soulstone_apply) < 30 then return false end  -- throttle
    -- Find dead party member
    local objects = core.object_manager.get_all_objects()
    for _, obj in ipairs(objects) do
        if obj and obj:is_valid() and obj:is_unit() and obj:is_player()
            and obj:is_party_member() and obj:is_dead() and not obj:is_ghost() then
            -- Check if already has soulstone
            if not utils.has_buff(obj, spells.SOULSTONE) then
                if utils.can_cast_target(runtime.soulstone_id, me, obj) then
                    if utils.cast_target(runtime.soulstone_id, obj, "Soulstone") then
                        runtime.last_soulstone_apply = now
                        utils.log_debug(menu, "Soulstone on " .. (obj.get_name and obj:get_name() or "party member"))
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function try_self_soulstone(me)
    if not menu.use_soulstone or not menu.use_soulstone:get_state() then return false end
    if not runtime.soulstone_id then return false end
    if me:is_in_combat() then return false end
    if me:is_moving() then return false end
    -- Only apply if we don't already have soulstone
    if utils.has_buff(me, spells.SOULSTONE) then return false end
    local now = _core_time()
    if (now - runtime.last_soulstone_apply) < 30 then return false end
    if not utils.can_cast_self(runtime.soulstone_id, me) then return false end
    if utils.cast_self(runtime.soulstone_id, me) then
        runtime.last_soulstone_apply = now
        utils.log_debug(menu, "Soulstone (self)")
        return true
    end
    return false
end


reactive_adapter = {
    spec = "EAXWarlockAffliction",
    actions = {
        life_save_self = {
            handler = function(_, action_deps)
                return defensive_manager.try_defensive(action_deps.me, "warlock", utils)
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

                return interrupt_manager.try_interrupt(action_deps.me, interrupt_target, "warlock", utils)
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
    if utils.throttle("mode_refresh", 5.0) then
        refresh_mode_cache()
    end
    if utils.throttle("set_bonus", 5.0) then
        update_set_bonus()
    end
    handle_toggle()
    if not menu.enabled:get_state() then
        return
    end
    local me = _get_local_player()
    if not me or me:is_dead() then
        return
    end
    if not threat_initialized then threat_manager.init(me); threat_initialized = true end
        ooc_manager.on_update(me, menu, utils)
    if menu.auto_ooc_food_drink and menu.auto_ooc_food_drink:get_state() then
        consumables_manager.try_use_ooc_food_drink(me, menu, utils)
    end

    -- Warlock utility: healthstone, soulstone
    if try_create_healthstone(me) then return end
    if try_soulstone_dead_ally(me) then return end
    if try_self_soulstone(me) then return end
    if try_use_healthstone(me) then return end

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
    if focus_target and not me:can_attack(focus_target) then focus_target = nil end
    local effective_mode = get_effective_mode()
    if not focus_target and try_summon_correct_pet(me, effective_mode) then return end
    local target = focus_target or utils.find_best_target(me)
    if not target then return end

    if focus_target and focus_target:is_valid() then
        target = focus_target
    end

    do_rotation(me, target)
end)


-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxwarlockaffliction_space_win")
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
        local label = "Eax Warlock Affli] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxwarlockaffliction_enabled_cp")
        return elements
    end)
end


-- -- Eax Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Warlock"
    local _eax_spec  = "Affliction"
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
core.log("[Eax Warlock Affliction] Loaded " .. (_pi and _pi.plugin_version or "?"))
