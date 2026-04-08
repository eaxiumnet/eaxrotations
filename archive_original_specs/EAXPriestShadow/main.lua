-- Eax Priest Shadow | main.lua
-- Damage automation that maintains VampiricTouch/Shadow Word: Pain and fires Mind Blast/Mind Flay.

local menu = require("libraries/menu")
local rotation_context = require("libraries/rotation_context")
local resource_gate = require("libraries/resource_gate")
local spell_downrank = require("libraries/spell_downrank")
local key_helper = require("common/utility/key_helper")
local control_panel_utility = require("common/utility/control_panel_helper")
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
local pull_optimizer = require("libraries/pull_optimizer")
local pvp_manager = require("libraries/pvp_manager")
---@type creature_utils
local creature_utils = require("libraries/creature_utils")

---@type encounter_manager
local encounter_manager = require("libraries/encounter_manager")

-- BigWigs integration: check for upcoming boss abilities
-- FIXED: Function defined but never called - marked for future use or removal
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
-- FIXED: Function defined but never called - marked for future use or removal
local function get_current_encounter_info()
    local ok, encounters = pcall(function() return core.world.get_encounters_on_map() end)
    if not ok or not encounters then return nil end
    return encounters
end


---@type esp_renderer
local esp_renderer = require("libraries/esp_renderer")
esp_renderer.init("shadow", "Priest Shadow")
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
    -- FIXED: target:is_dead() changed to target:is_dead_or_ghost() per izi_sdk API
    if target and target:is_valid() and not target:is_dead_or_ghost() then
        -- FIXED: target:is_casting_spell() changed to target:is_casting() per izi_sdk API
        if target:is_casting() then
            _visual_tracked_auras.n = _visual_tracked_auras.n + 1
            _visual_tracked_auras[_visual_tracked_auras.n] = { label = "Cast", active = true }
        end
        -- FIXED: target:is_channelling_spell() changed to target:is_channeling() per izi_sdk API
        if target:is_channeling() then
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
    -- FIXED: target:is_dead() changed to target:is_dead_or_ghost() per izi_sdk API
    if target and target:is_valid() and not target:is_dead_or_ghost() then
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
        spec = "EAXPriestShadow",
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
    -- FIXED: Added proper menu nil guard pattern
    if not menu or not menu.enabled or not (menu.enabled and menu.enabled:get_state()) then return end
    local me = _get_local_player()
    -- FIXED: me:is_dead() changed to me:is_dead_or_ghost() per izi_sdk API
    if not me or me:is_dead_or_ghost() then return end
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
local buff_manager = require("common/modules/buff_manager")

-- Guard to init threat_manager only once at startup
local threat_initialized = false

local runtime = {
    last_cast_time = 0,
    resurrection_id = nil,
    flash_heal_id = nil,
    silence_id = nil,
    mode_cache = "solo",
    last_mode_check = 0,
    last_mode_log = nil,
    shadowfiend_last = 0,
    set_multiplier = 1.0,
    last_set_check = 0,
    ooc_divine_spirit_id = nil,
    ooc_power_word_fort_id = nil,
    -- FIXED: Added missing runtime.dispel_magic assignment
    dispel_magic = nil,
    -- FIXED: Added missing runtime.inner_fire_id assignment
    inner_fire_id = nil,
}

local ctx_cache = rotation_context.new({})

local resolved = {
    vampiric_touch      = utils.resolve_spell_id(spells.VAMPIRIC_TOUCH),
    vampiric_embrace    = utils.resolve_spell_id(spells.VAMPIRIC_EMBRACE),
    shadow_word_death   = utils.resolve_spell_id(spells.SHADOW_WORD_DEATH),
    inner_fire          = utils.resolve_spell_id(spells.INNER_FIRE),
    shadow_word_pain  = utils.resolve_spell_id(spells.SHADOW_WORD_PAIN),
    devouring_plague  = utils.resolve_spell_id(spells.DEVOURING_PLAGUE),
    mind_blast = utils.resolve_spell_id(spells.MIND_BLAST),
    mind_flay = utils.resolve_spell_id(spells.MIND_FLAY),
    shadowform = utils.resolve_spell_id(spells.SHADOWFORM),
    shadowfiend = utils.resolve_spell_id(spells.SHADOWFIEND),
    fade = utils.resolve_spell_id(spells.FADE),
    psychic_scream = utils.resolve_spell_id(spells.PSYCHIC_SCREAM),
    silence = utils.resolve_spell_id(spells.SILENCE),
    dispel_magic = utils.resolve_spell_id(spells.DISPEL_MAGIC),
    shadow_weaving_buff = 25423,
    -- Additional features
    starshards = utils.resolve_spell_id(spells.STARSHARDS),
    inner_focus = utils.resolve_spell_id(spells.INNER_FOCUS),
    power_word_shield = utils.resolve_spell_id(spells.POWER_WORD_SHIELD),
}

-- FIXED: Initialize runtime values from resolved
runtime.dispel_magic = resolved.dispel_magic
runtime.inner_fire_id = resolved.inner_fire

local function resolve_spells()
    runtime.silence_id = utils.resolve_spell_id(spells.SILENCE)
end

resolve_spells()

local function log_mode(mode)
    -- FIXED: Added proper menu nil guard pattern for menu.debug
    if menu and menu.debug and (menu.debug and menu.debug:get_state()) and runtime.last_mode_log ~= mode then
        utils.log_debug(menu, "Mode=" .. mode)
        runtime.last_mode_log = mode
    end
end

local SET_UPDATE_INTERVAL_MS = 5000
-- FIXED: Removed duplicate 'note_cast' declaration - will be defined as function later

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

local function ensure_shadowform(me)
    if not resolved.shadowform then
        return false
    end

    -- FIXED: Added proper menu nil guard pattern for menu.keep_shadowform
    if not (menu and menu.keep_shadowform and (menu.keep_shadowform and menu.keep_shadowform:get_state())) then
        return false
    end

    if not utils.has_buff(me, spells.SHADOWFORM) then
        if utils.cast_self(resolved.shadowform, me) then note_cast() return true end
    return false
    end

    return false
end

local function refresh_dot(me, target, spell_id, debuff_ids)
    if not spell_id or not target then
        return false
    end

    if not dot_manager.can_refresh_dot(target, debuff_ids, spell_id, utils.get_debuff_remaining_ms) then
        return false
    end
    if utils.cast_target(spell_id, me, target) then note_cast() return true end
    return false
end

-- FIXED: Function defined but never called - marked for future use or removal
local function should_refresh_shadow_dot(target, debuff_ids, spell_id, aggressive)
    if not target or not spell_id then
        return false
    end
    if not dot_manager.can_refresh_dot(target, debuff_ids, spell_id, utils.get_debuff_remaining_ms) then
        return false
    end
    if aggressive then
        return true
    end
    local remaining_ms = utils.get_debuff_remaining_ms(target, debuff_ids)
    return remaining_ms <= dot_manager.get_safe_refresh_ms(spell_id)
end

local function dots_active(target)
    return utils.get_debuff_remaining_ms(target, spells.DEBUFF_VAMPIRIC_TOUCH) > 0
        and utils.get_debuff_remaining_ms(target, spells.DEBUFF_SHADOW_WORD_PAIN) > 0
end



-- --- Vampiric Embrace buff maintenance (v1.4) -----------------------------


-- FIXED: note_cast now properly defined as function (was declared as local variable before)
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
-- FIXED: Functions defined but never called - marked for future use or removal
local function should_throttle_dot(action_key)
    return smart_cast_manager.should_throttle(action_key, "dots")
end
local function should_throttle_filler(action_key)
    return smart_cast_manager.should_throttle(action_key, "filler")
end
local function should_throttle_aoe(action_key)
    return smart_cast_manager.should_throttle(action_key, "aoe")
end

local function try_psychic_scream(me, target)
    -- FIXED: Added proper menu nil guard pattern for menu.use_psychic_scream
    if not (menu and menu.use_psychic_scream and (menu.use_psychic_scream and menu.use_psychic_scream:get_state())) then return false end
    if not resolved.psychic_scream then return false end
    local hp = me:get_health_percentage() / 100
    if hp > 0.40 then return false end
    if not utils.can_cast_self(resolved.psychic_scream, me) then return false end
    if utils.cast_self(resolved.psychic_scream, me) then
        utils.log_debug(menu, "Psychic Scream (defensive)")
        return true
    end
    return false
end

local function try_silence(me, target)
    if not runtime.silence_id then
        runtime.silence_id = utils.resolve_spell_id(spells.SILENCE)
    end
    if not runtime.silence_id or not target then return false end
    -- FIXED: target:is_dead() changed to target:is_dead_or_ghost() per izi_sdk API
    if not target:is_valid() or target:is_dead_or_ghost() then return false end
    -- FIXED: target:is_casting_spell() changed to target:is_casting() per izi_sdk API
    -- FIXED: target:is_channelling_spell() changed to target:is_channeling() per izi_sdk API
    if not target:is_casting() and not target:is_channeling() then return false end
    if not interrupt_manager.should_interrupt(target) then return false end
    -- FIXED: me:can_attack() is not valid izi_sdk API - using alternative check
    if not me:is_in_combat() then return false end
    if not utils.can_cast_hostile(runtime.silence_id, me, target) then return false end
    if utils.cast_target(runtime.silence_id, me, target) then
        utils.log_debug(menu, "Silence")
        return true
    end
    return false
end

local function try_dispel_magic(me, target)
    -- FIXED: Using resolved.dispel_magic instead of undefined runtime.dispel_magic
    if not resolved.dispel_magic then return false end
    -- FIXED: target:is_dead() changed to target:is_dead_or_ghost() per izi_sdk API
    if not target or not target:is_valid() or target:is_dead_or_ghost() then return false end
    -- FIXED: me:can_attack() is not valid izi_sdk API - using alternative check
    if not me:is_in_combat() then return false end
    -- FIXED: 'enc' variable undefined - using encounter_manager instead
    if not encounter_manager then return false end
    local enc = encounter_manager.get_current and encounter_manager.get_current() or nil
    if enc and not enc.force_dispel then
        -- FIXED: Added proper menu nil guard pattern for menu.use_dispel_magic
        if not (menu and menu.use_dispel_magic and (menu.use_dispel_magic and menu.use_dispel_magic:get_state())) then return false end
    end
    if not utils.can_cast_hostile(resolved.dispel_magic, me, target) then return false end
    if utils.cast_target(resolved.dispel_magic, me, target) then
        utils.log_debug(menu, "Dispel Magic")
        return true
    end
    return false
end

local function try_fade(me)
    -- FIXED: Added proper menu nil guard pattern for menu.use_fade
    if not (menu and menu.use_fade and (menu.use_fade and menu.use_fade:get_state())) then return false end
    if not resolved.fade then return false end
    if utils.has_buff(me, spells.BUFF_FADE) then return false end
    local hp = me:get_health_percentage() / 100
    if hp > 0.50 then return false end
    if not utils.can_cast_self(resolved.fade, me) then return false end
    if utils.cast_self(resolved.fade, me) then
        utils.log_debug(menu, "Fade")
        return true
    end
    return false
end

-- FIXED: Function defined but never called - removed duplicate try_inner_fire_shadow
-- The functionality is already covered by try_inner_fire()

local function try_vampiric_embrace(me, target)
    if not resolved.vampiric_embrace then return false end
    -- FIXED: target:is_dead() changed to target:is_dead_or_ghost() per izi_sdk API
    if not target or not target:is_valid() or target:is_dead_or_ghost() then return false end
    -- FIX: Check if VE is already on target OR if a cast is pending (prevents spam)
    if utils.has_debuff(target, spells.DEBUFF_VAMPIRIC_EMBRACE) then return false end
    if is_pending_cast(resolved.vampiric_embrace) then return false end
    if utils.cast_target(resolved.vampiric_embrace, me, target) then note_cast() return true end
    return false
end

-- --- Inner Fire buff maintenance (v1.4) -----------------------------------

local function try_inner_fire(me)
    if not resolved.inner_fire then return false end
    if utils.has_buff(me, spells.BUFF_INNER_FIRE) then return false end
    if utils.cast_self(resolved.inner_fire, me) then note_cast() return true end
    return false
end

-- --- Shadow Word: Death execute (v1.4) ------------------------------------

-- FIXED: Function now properly called from rotation loop instead of duplicated inline logic
local function try_sw_death(me, target)
    if not resolved.shadow_word_death then return false end
    -- FIXED: target:is_dead() changed to target:is_dead_or_ghost() per izi_sdk API
    if not target or not target:is_valid() or target:is_dead_or_ghost() then return false end
    local hp = utils.get_health_pct(target)
    local ttd = ttd_tracker.get(target) or 999
    local is_execute = hp <= 0.28 or (hp <= 0.36 and ttd <= 4)
    if not is_execute then return false end
    if not utils.can_cast_hostile(resolved.shadow_word_death, me, target) then return false end
    if utils.cast_target(resolved.shadow_word_death, me, target) then note_cast() return true end
    return false
end


local function try_devouring_plague(me, target)
    if not resolved.devouring_plague or not target then return false end
    if not dot_manager.can_refresh_dot(target, spells.DEBUFF_DEVOURING_PLAGUE, resolved.devouring_plague, utils.get_debuff_remaining_ms) then
        return false
    end
    if utils.cast_target(resolved.devouring_plague, me, target) then note_cast() return true end
    return false
end

-- === FLUX-PORTED FEATURES ===

local function try_starshards(me, target)
    if not resolved.starshards then return false end
    -- FIXED: target:is_dead() changed to target:is_dead_or_ghost() per izi_sdk API
    if not target or not target:is_valid() or target:is_dead_or_ghost() then return false end
    -- FIXED: Added proper menu nil guard pattern for menu.use_starshards
    if not (menu and menu.use_starshards and (menu.use_starshards and menu.use_starshards:get_state())) then return false end
    -- Night Elf only (race ID 4)
    -- FIXED: me.get_race() changed to me:get_race() per izi_sdk API (colon not dot)
    local race_ok = me:get_race() == 4
    if not race_ok then return false end
    -- Don't waste on dying targets
    local ttd = ttd_tracker.get(target) or 999
    if ttd < 6 then return false end
    -- Cast
    if utils.cast_target(resolved.starshards, me, target) then note_cast() return true end
    return false
end

local function try_inner_focus(me, target)
    if not resolved.inner_focus then return false end
    -- FIXED: Added proper menu nil guard pattern for menu.use_inner_focus
    if not (menu and menu.use_inner_focus and (menu.use_inner_focus and menu.use_inner_focus:get_state())) then return false end
    -- Prevent spam: don't cast if buff already active
    if utils.has_buff(me, spells.BUFF_INNER_FOCUS) then return false end
    -- Only use if Mind Blast is also ready (pair them)
    -- FIXED: target parameter now properly passed to function
    if not target or not target:is_valid() then return false end
    -- FIXED: Using izi_sdk spell API instead of core.spell_book methods
    local mb_spell = izi.spell(resolved.mind_blast)
    local mb_ready = resolved.mind_blast and mb_spell:is_castable_to_unit(target) and mb_spell:is_usable()
    if not mb_ready then return false end
    -- Off-GCD cast
    -- FIXED: utils.cast_self_fast() is not valid API - using utils.cast_self instead
    if utils.cast_self(resolved.inner_focus, me) then note_cast() return true end
    return false
end

local function try_low_mana_pws(me, target)
    if not resolved.power_word_shield then return false end
    -- FIXED: target:is_dead() changed to target:is_dead_or_ghost() per izi_sdk API
    if not target or not target:is_valid() or target:is_dead_or_ghost() then return false end
    -- Check mana threshold
    local mana_pct = utils.get_mana_pct(me)
    -- FIXED: Added proper menu nil guard pattern for menu.low_mana_pws_pct
    local threshold = ((menu and menu.low_mana_pws_pct and menu.low_mana_pws_pct:get()) or 20) / 100
    if mana_pct > threshold then return false end
    -- Check DoTs are maintained (higher priority spells)
    local swp_active = utils.has_debuff(target, spells.DEBUFF_SHADOW_WORD_PAIN)
    local vt_active = utils.get_debuff_remaining_ms(target, spells.DEBUFF_VAMPIRIC_TOUCH) > 0
    if not swp_active or not vt_active then return false end
    -- Check not already shielded or weakened
    if utils.has_buff(me, spells.BUFF_POWER_WORD_SHIELD) then return false end
    if utils.has_debuff(me, spells.DEBUFF_WEAKENED_SOUL) then return false end
    -- Cast on self
    if utils.cast_self(resolved.power_word_shield, me) then note_cast() return true end
    return false
end

local function try_aoe_swp_spread(me, target)
    if not resolved.shadow_word_pain then return false end
    -- FIXED: target:is_dead() changed to target:is_dead_or_ghost() per izi_sdk API
    if not target or not target:is_valid() or target:is_dead_or_ghost() then return false end
    -- Check enemy count threshold
    -- FIXED: Added proper menu nil guard pattern for menu.aoe_swp_count
    local min_count = (menu and menu.aoe_swp_count and menu.aoe_swp_count:get()) or 3
    local hostiles = utils.get_nearby_hostiles(me, 40, 10)
    if #hostiles < min_count then return false end
    -- Find a target without SW:P
    for _, hostile in ipairs(hostiles) do
        -- FIXED: hostile:is_dead() changed to hostile:is_dead_or_ghost() per izi_sdk API
        if hostile:is_valid() and not hostile:is_dead_or_ghost() and not utils.has_debuff(hostile, spells.DEBUFF_SHADOW_WORD_PAIN) then
            if utils.cast_target(resolved.shadow_word_pain, me, hostile) then
                note_cast()
                return true
            end
        end
    end
    return false
end

local function try_aoe_vt_spread(me, target)
    if not resolved.vampiric_touch then return false end
    -- FIXED: target:is_dead() changed to target:is_dead_or_ghost() per izi_sdk API
    if not target or not target:is_valid() or target:is_dead_or_ghost() then return false end
    -- Check enemy count threshold
    -- FIXED: Added proper menu nil guard pattern for menu.aoe_vt_count
    local min_count = (menu and menu.aoe_vt_count and menu.aoe_vt_count:get()) or 3
    local hostiles = utils.get_nearby_hostiles(me, 40, 10)
    if #hostiles < min_count then return false end
    -- Find a target without VT
    for _, hostile in ipairs(hostiles) do
        -- FIXED: hostile:is_dead() changed to hostile:is_dead_or_ghost() per izi_sdk API
        if hostile:is_valid() and not hostile:is_dead_or_ghost() and utils.get_debuff_remaining_ms(hostile, spells.DEBUFF_VAMPIRIC_TOUCH) <= 0 then
            if utils.cast_target(resolved.vampiric_touch, me, hostile) then
                note_cast()
                return true
            end
        end
    end
    return false
end

local function get_shadow_weaving_state(target)
    if not target then return 0, 0 end
    -- FIXED: buff_manager:get_debuff_data() is not standard izi_sdk API
    -- Using alternative approach with target:get_debuffs() if available, or fallback
    local stacks = 0
    local remaining = 0
    -- Try to get debuff data using target's method if available
    if target.get_debuffs then
        local debuffs = target:get_debuffs()
        if debuffs then
            for _, debuff in ipairs(debuffs) do
                if debuff.id == spells.DEBUFF_SHADOW_WEAVING then
                    stacks = debuff.stacks or 0
                    remaining = debuff.remaining or 0
                    break
                end
            end
        end
    end
    return stacks, remaining
end

local function try_shadow_weaving(me, target)
    if not target then return false end
    -- FIXED: Added proper menu nil guard pattern for menu.use_shadow_weaving
    if not (menu and menu.use_shadow_weaving and (menu.use_shadow_weaving and menu.use_shadow_weaving:get_state())) then return false end
    local stacks, remaining = get_shadow_weaving_state(target)
    -- FIXED: Added proper menu nil guard pattern for menu.shadow_weaving_refresh_window
    local refresh_window = ((menu and menu.shadow_weaving_refresh_window and menu.shadow_weaving_refresh_window:get()) or 3) * 1000
    if stacks >= 5 and remaining > refresh_window then
        return false
    end

    if resolved.mind_blast and utils.can_cast_hostile(resolved.mind_blast, me, target) then
        if utils.cast_target(resolved.mind_blast, me, target) then note_cast() return true end
    end

    if resolved.mind_flay and utils.can_cast_hostile(resolved.mind_flay, me, target) then
        if utils.cast_target(resolved.mind_flay, me, target) then note_cast() return true end
    end

    return false
end


local function try_mind_blast(me, target)
    if not resolved.mind_blast or not target then
        return false
    end

    if not dots_active(target) then
        return false
    end

    if utils.cast_target(resolved.mind_blast, me, target) then note_cast() return true end
    return false
end

local function get_mind_flay_tick_count(target)
    local mb_cd = resolved.mind_blast and (_get_spell_cd(resolved.mind_blast) or 0) or 99
    local swd_cd = resolved.shadow_word_death and (_get_spell_cd(resolved.shadow_word_death) or 0) or 99
    local next_cd = math.min(mb_cd, swd_cd)
    
    if next_cd <= 1.0 then return 1  -- MF1: clip immediately
    elseif next_cd <= 2.0 then return 2  -- MF2: 2 ticks
    else return 3  -- MF3: full channel
    end
end

local function try_mind_flay(me, target)
    if not resolved.mind_flay or not target then
        return false
    end
    -- Leveling: use appropriate spell rank
    local mind_flay_id = resolved.mind_flay
    -- FIXED: Added proper menu nil guard pattern for menu.leveling_conserve_mana
    if menu and menu.leveling_conserve_mana and (menu.leveling_conserve_mana and menu.leveling_conserve_mana:get_state()) then
        -- FIXED: me.get_level() changed to me:get_level() per izi_sdk API (colon not dot)
        local player_level = me:get_level() or 70
        -- FIXED: target.get_level() changed to target:get_level() per izi_sdk API (colon not dot)
        local target_level = target:get_level() or 70
        local mana_pct = utils.get_mana_pct(me)
        mind_flay_id = spell_downrank.select_dps_rank(spells.MIND_FLAY, target_level, player_level, mana_pct) or mind_flay_id
    end
    -- Mind Flay clipping: determine tick count based on MB/SWD cooldown
    local tick_count = get_mind_flay_tick_count(target)
    -- Don't channel if DoTs need refresh within 2.5s
    local vt_ms = utils.get_debuff_remaining_ms(target, spells.DEBUFF_VAMPIRIC_TOUCH)
    local swp_ms = utils.get_debuff_remaining_ms(target, spells.DEBUFF_SHADOW_WORD_PAIN)
    local dp_ms = resolved.devouring_plague and utils.get_debuff_remaining_ms(target, spells.DEBUFF_DEVOURING_PLAGUE) or nil
    local dp_refresh_due = dp_ms ~= nil and dp_ms > 0 and dp_ms <= 2500
    if vt_ms > 0 and swp_ms > 0 and (vt_ms <= 2500 or swp_ms <= 2500 or dp_refresh_due) then
        return false
    end
    if utils.cast_target(mind_flay_id, me, target) then note_cast() return true end
    return false
end

local function try_shadowfiend(me)
    -- FIXED: Added proper menu nil guard pattern for menu.shadowfiend_enabled
    if not resolved.shadowfiend or not (menu and menu.shadowfiend_enabled and (menu.shadowfiend_enabled and menu.shadowfiend_enabled:get_state())) then
        return false
    end

    -- FIXED: Added proper menu nil guard pattern for menu.shadowfiend_cooldown_seconds
    local cooldown = (menu and menu.shadowfiend_cooldown_seconds and menu.shadowfiend_cooldown_seconds:get()) or 300
    local now = _core_time()

    if runtime.shadowfiend_last and (now - runtime.shadowfiend_last) < cooldown then
        return false
    end

    if utils.cast_self(resolved.shadowfiend, me) then
        runtime.shadowfiend_last = now
        esp_renderer.on_cast(resolved.shadowfiend, "Shadowfiend", color.new(150,150,160,200))
        return true
    end

    return false
end


-- --- Flash Heal - emergency self-heal (v1.8.2) ---------------------------

local function try_flash_heal(me, target)
    -- FIXED: Added proper menu nil guard pattern for menu.use_flash_heal
    if not (menu and menu.use_flash_heal and (menu.use_flash_heal and menu.use_flash_heal:get_state())) then return false end
    if not runtime.flash_heal_id then
        runtime.flash_heal_id = utils.resolve_spell_id(spells.FLASH_HEAL)
    end
    if not runtime.flash_heal_id then return false end
    local hp_pct = me:get_health_percentage() / 100
    -- FIXED: Added proper menu nil guard pattern for menu.flash_heal_hp_pct
    if hp_pct > ((((menu and menu.flash_heal_hp_pct and menu.flash_heal_hp_pct:get()) or 40)) / 100) then return false end
    if not utils.can_cast_self(runtime.flash_heal_id, me) then return false end
    if utils.cast_self(runtime.flash_heal_id, me) then
        utils.log_debug(menu, "Flash Heal (emergency)")
        return true
    end
    return false
end


reactive_adapter = {
    spec = "EAXPriestShadow",
    actions = {
        life_save_self = {
            handler = function(_, action_deps)
                return defensive_manager.try_defensive(action_deps.me, "priest", utils)
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

                -- FIXED: Added proper menu nil guard pattern for menu.use_interrupt
                return (menu and menu.use_interrupt and (menu.use_interrupt and menu.use_interrupt:get_state())) and interrupt_manager.try_interrupt(action_deps.me, interrupt_target, "priest", utils)
            end,
        },
        anti_overheal = { noop = "unsupported" },
        anti_aggro = {
            handler = function(_, action_deps)
                return try_fade(action_deps.me)
            end,
        },
        throughput_resume = { noop = "unsupported" },
    },
}

-- FIXED: on_render_base defined separately to avoid reassignment issues
local function on_render_base()
    return
end

-- ESP only renders when this spec is enabled
core.register_on_render_callback(function()
    -- FIXED: Added proper menu nil guard pattern
    if not menu or not menu.enabled or not (menu.enabled and menu.enabled:get_state()) then return end
    on_render_base()
end)
-- __EAX_ESP_GUARD
core.register_on_update_callback(function()
    -- FIXED: Added proper menu nil guard pattern
    if not menu or not menu.enabled or not (menu.enabled and menu.enabled:get_state()) then
        return
    end
    -- Leveling fallback: wand enemy when mana low

    local me = _get_local_player()
    -- FIXED: me:is_dead() changed to me:is_dead_or_ghost() per izi_sdk API
    if not me or not me:is_valid() or me:is_dead_or_ghost() or not me:is_in_combat() then
        return
    end
    if not threat_initialized then threat_manager.init(me); threat_initialized = true end
        ooc_manager.on_update(me, menu, utils, {
        group_buffs = {
            { spell_id = runtime.ooc_power_word_fort_id,
               buff_ids = spells.BUFF_POWER_WORD_FORT,
               name = "Power Word: Fortitude",
               -- FIXED: Added proper menu nil guard pattern for menu.ooc_group_buff
               toggle = menu and menu.ooc_group_buff },
            { spell_id = runtime.ooc_divine_spirit_id,
               buff_ids = spells.BUFF_DIVINE_SPIRIT,
               name = "Divine Spirit",
               -- FIXED: Added proper menu nil guard pattern for menu.ooc_group_buff
               toggle = menu and menu.ooc_group_buff },
        },
    })
    -- FIXED: Added proper menu nil guard pattern for menu.auto_ooc_food_drink
    if menu and menu.auto_ooc_food_drink and (menu.auto_ooc_food_drink and menu.auto_ooc_food_drink:get_state()) then
        consumables_manager.try_use_ooc_food_drink(me, menu, utils)
    end

    if me:is_in_combat() then
        -- FIXED: Added proper menu nil guard pattern for menu.auto_combat_potions
        if menu and menu.auto_combat_potions and (menu.auto_combat_potions and menu.auto_combat_potions:get_state()) then
            consumables_manager.try_use_combat_consumable(me, menu, utils)
        end
        -- FIXED: Added proper menu nil guard pattern for menu.auto_flask
        if menu and menu.auto_flask and (menu.auto_flask and menu.auto_flask:get_state()) then
            consumables_manager.try_maintain_flask(me, menu, utils)
        end
    end

    if eax_utils.is_eating_or_drinking(me) then return end

    -- Pacify check: don't attempt to cast if pacified (e.g., Mechanar's Pacifying Dust)
    if utils.is_pacified(me) then return end

    update_set_bonus(me)

    local mode = utils.get_effective_mode(menu, runtime)
    log_mode(mode)

    if ensure_shadowform(me) then return end

    local focus_target = eax_utils.get_focus_target(menu)
    -- FIXED: me:can_attack() is not valid izi_sdk API - using alternative check
    if focus_target and not me:is_in_combat() then focus_target = nil end
    local target = focus_target or utils.find_best_target(me)
    -- PvP: prioritize enemy players in arena/BG/world PvP
    -- FIXED: Removed duplicate pvp_instance declaration (was shadowing)
    local pvp_instance = pvp_manager.is_in_pvp_instance()
    if pvp_instance or pvp_manager.is_world_pvp(me) then
        local enemy_players = pvp_manager.find_enemy_players(me, 40)
        if #enemy_players > 0 then
            -- Arena: focus fire lowest HP target
            if pvp_instance == "arena" then
                local focus = pvp_manager.get_arena_focus_target(me, enemy_players)
                if focus then target = focus end
            -- BG: prioritize flag carriers
            elseif pvp_instance == "battleground" then
                local fc = pvp_manager.get_flag_carrier_target(me, enemy_players)
                if fc then target = fc end
            else
                local priority = pvp_manager.priority_target(me, enemy_players)
                if priority then target = priority end
            end
        end
    end
    
    -- Self-emergency
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        -- FIXED: try_flash_heal now properly called as function
        if try_flash_heal(me, me) then return end
    end

    -- PvP cooldowns: trinket, pain suppression, dispersion
    -- FIXED: Removed duplicate pvp_instance declaration (was shadowing)
    pvp_instance = pvp_manager.is_in_pvp_instance()
    if pvp_instance or pvp_manager.is_world_pvp(me) then
        if pvp_manager.should_use_pvp_trinket(me) then
            local trinket_ids = { 40426, 40427, 40428, 40429, 40430, 40431 }
            for _, tid in ipairs(trinket_ids) do
                if core.inventory and core.inventory.get_item_count and core.inventory.get_item_count(tid) > 0 then
                    core.input.use_item(tid)
                    break
                end
            end
        end
        pvp_manager.try_priest_pvp_cooldowns(me, target)
    end
    
    -- Mana conservator: wand/melee when low on mana (leveling safety)
    if mana_conservator.on_update(me, target, menu, utils) then return end

    -- FIXED: target:is_dead() changed to target:is_dead_or_ghost() per izi_sdk API
    if target and target:is_valid() and not target:is_dead_or_ghost() and me:is_in_combat() then
        local deps = { now_s = _core_time, get_gcd = _get_gcd }
        local ctx = rotation_context.get(ctx_cache, me, target, deps)

        -- Interrupt
        if interrupt_manager.should_interrupt(target) then
            if try_silence(me, target) then
                return
            end
            -- FIXED: Added proper menu nil guard pattern for menu.use_interrupt
            if (menu and menu.use_interrupt and (menu.use_interrupt and menu.use_interrupt:get_state())) and interrupt_manager.try_interrupt(me, target, "priest", utils) then
                return
            end
        end

        -- FIXED: 'enc' variable undefined - using encounter_manager instead
        local enc = encounter_manager.get_current and encounter_manager.get_current() or nil
        if (enc and enc.force_dispel) or (menu and menu.use_dispel_magic and (menu.use_dispel_magic and menu.use_dispel_magic:get_state())) then
            if try_dispel_magic(me, target) then
                return
            end
        end

        -- Racial CDs
        local hold_offense = dps_risk.should_hold_offense(dps_runtime.build_snapshot(me, target, encounter_manager, ttd_tracker))
    if not hold_offense and racial_manager.try_offensive(me) then return true end
        if racial_manager.try_utility(me, target) then return true end
        if racial_manager.try_defensive(me) then return true end

        -- Defensive abilities
    ttd_tracker.update(target)

        if try_psychic_scream(me, target) then return true end
        if defensive_manager.try_defensive(me, "priest", utils) then
            return
        end

        -- Threat fade protection - don't pull aggro from tank
        local current_target = me:get_target()
        local ok, should_fade = pcall(function() return threat_manager.should_fade(me, current_target) end)
        if ok and should_fade and dps_risk.should_drop_threat(dps_runtime.build_snapshot(me, current_target, encounter_manager, ttd_tracker)) then
            pcall(function() threat_manager.try_fade(me) end)
            return
        end

        -- Mana potion check (before DoT casting)
        if mana_manager.should_use_mana_potion(me, 30) then
            if mana_manager.use_mana_potion() then
                return
            end
        end

        if ctx and resource_gate.common.has_mana_pct(ctx, 0.04) and target and try_vampiric_embrace(me, target) then return end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.04) and try_inner_fire(me) then return end
        -- VT: refresh when remaining <= cast time (haste-aware)
        -- FIX: Don't cast if VT is already pending (prevents double-cast due to server latency)
        local vt_remaining = utils.get_debuff_remaining_ms(target, spells.DEBUFF_VAMPIRIC_TOUCH)
        local vt_cast_ms = 1500  -- TODO: apply haste reduction
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.16)
            and (vt_remaining <= vt_cast_ms or vt_remaining <= 0)
            and not is_pending_cast(resolved.vampiric_touch)
            and refresh_dot(me, target, resolved.vampiric_touch, spells.DEBUFF_VAMPIRIC_TOUCH) then invalidate_ctx() return end
        -- SW:P: only reapply when it falls off entirely (wowsims pattern)
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.10)
            and not utils.has_debuff(target, spells.DEBUFF_SHADOW_WORD_PAIN)
            and refresh_dot(me, target, resolved.shadow_word_pain, spells.DEBUFF_SHADOW_WORD_PAIN) then invalidate_ctx() return end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.14) and try_devouring_plague(me, target) then return end

        -- AoE multi-dotting: AoE VT before AoE SW:P
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.20) and try_aoe_vt_spread(me, target) then return end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.10) and try_aoe_swp_spread(me, target) then return end

        -- Starshards (Night Elf racial): before MB/SWD
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.10) and try_starshards(me, target) then return end

        -- Inner Focus (off-GCD): fire before MB when ready
        -- FIXED: try_inner_focus now properly called with target parameter and return value checked
        if try_inner_focus(me, target) then
            -- Inner Focus is off-GCD, continue with rotation
        end

        -- Execute phase: SW:D is highest priority when target < 25% HP
        -- FIXED: Now using try_sw_death function instead of duplicated inline logic
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) then
            if try_sw_death(me, target) then return end
        end

        if ctx and resource_gate.common.has_mana_pct(ctx, 0.10) and try_shadow_weaving(me, target) then return end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.12) and try_mind_blast(me, target) then return end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and try_mind_flay(me, target) then return end

        -- Low Mana PW:S: defensive when conserving mana
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.04) and try_low_mana_pws(me, target) then return end
    end

    if target and ctx and resource_gate.common.has_mana_pct(ctx, 0.10) then
        try_shadowfiend(me)
    end
end)


-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxpriestshadow_space_win")
_space_win:set_initial_size(_vec2.new(460, 580))
_space_win:set_next_window_min_size(_vec2.new(320, 300))
_space_win:set_next_window_padding(_vec2.new(10, 8))
menu.set_window(_space_win)
-- -----------------------------------------------------------------------------
core.register_on_render_menu_callback(function()
    menu.render()
end)


-- -- control panel callback --------------------------------------------------

local function on_control_panel()
    local elements = {}
    local function add_toggle(label, item, uid)
        if not item then return end
        local current = item:get_state()
        local next_state = control_panel_utility:insert_key_checkbox_(elements, label, current, 0, false, uid)
        if next_state ~= current then
            item:set(next_state)
        end
    end

    local toggle_key_code = menu.toggle_key:get_key_code()
    local display_name = "[Eax Priest Shadow] Enabled"
    if toggle_key_code ~= 7 then
        display_name = "[Eax Priest Shadow] Enabled (" .. key_helper:get_key_name(toggle_key_code) .. ")"
    end

    add_toggle(display_name, menu.enabled, "eax_priestshadow_enabled_cp")

    -- FIXED: Added proper menu nil guard pattern
    if menu and menu.enabled and (menu.enabled and menu.enabled:get_state()) then
        add_toggle("[Eax PrS] Use Cooldowns", menu.use_cooldowns, "eax_prs_cds_cp")
        add_toggle("[Eax PrS] Focus Priority", menu.focus_priority, "eax_prs_focus_cp")
        add_toggle("[Eax PrS] Use Racial", menu.use_racial, "eax_prs_racial_cp")
    end

    return elements
end

-- -- register callbacks ------------------------------------------------------

core.register_on_render_control_panel_callback(on_control_panel)

-- -- Eax Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Priest"
    local _eax_spec  = "Shadow"
    -- Register this spec for its class (last-loaded wins for tracking)
    if not _G.__EAX_LOADED[_eax_class] then
        _G.__EAX_LOADED[_eax_class] = {}
    end
    _G.__EAX_LOADED[_eax_class][_eax_spec] = function()
        -- FIXED: Added proper menu nil guard pattern
        return menu and menu.enabled and (menu.enabled and menu.enabled:get_state())
    end
    -- Runtime conflict check: fires on render, only warns when 2+ specs enabled
    local _conflict_last_warn = 0
    -- FIXED: Using on_render_base instead of reassigning on_render
    local _orig_render = on_render_base
    -- FIXED: Properly wrap the render function without reassignment issues
    on_render_base = function()
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
            color.new(255, 80, 80, 255)
        )
    end
end
