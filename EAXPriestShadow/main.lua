-- Eax Priest Shadow | main.lua
-- Damage automation that maintains VampiricTouch/Shadow Word: Pain and fires Mind Blast/Mind Flay.

local menu = require("libraries/menu")
local rotation_context = require("libraries/rotation_context")
local resource_gate = require("libraries/resource_gate")
local spell_downrank = require("libraries/spell_downrank")
local key_helper = require("common/utility/key_helper")
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
local pull_optimizer = require("eax_shared/pull_optimizer")
local pvp_manager = require("eax_shared/pvp_manager")
---@type creature_utils
local creature_utils = require("libraries/creature_utils")

---@type encounter_manager
local encounter_manager = require("libraries/encounter_manager")

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
}

local function resolve_spells()
    runtime.silence_id = utils.resolve_spell_id(spells.SILENCE)
end

resolve_spells()

local function log_mode(mode)
    if menu.debug:get_state() and runtime.last_mode_log ~= mode then
        utils.log_debug(menu, "Mode=" .. mode)
        runtime.last_mode_log = mode
    end
end

local SET_UPDATE_INTERVAL_MS = 5000
local PRIEST_SET_NAMES = { "Vestments", "Absolution", "AbsolutionRegalia" }
local note_cast

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

    if not menu.keep_shadowform:get_state() then
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
    if utils.cast_target(spell_id, target) then note_cast() return true end
    return false
end

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


note_cast = function()
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

local function try_psychic_scream(me, target)
    if not menu.use_psychic_scream or not menu.use_psychic_scream:get_state() then return false end
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
    if not target:is_valid() or target:is_dead() then return false end
    if not target:is_casting_spell() and not target:is_channelling_spell() then return false end
    if not interrupt_manager.should_interrupt(target) then return false end
    if not me:can_attack(target) then return false end
    if not utils.can_cast_hostile(runtime.silence_id, me, target) then return false end
    if utils.cast_target(runtime.silence_id, me, target) then
        utils.log_debug(menu, "Silence")
        return true
    end
    return false
end

local function try_dispel_magic(me, target)
    if not runtime.dispel_magic then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    if enc and not enc.force_dispel and not menu.use_dispel_magic:get_state() then return false end
    if not utils.can_cast_hostile(runtime.dispel_magic, me, target) then return false end
    if utils.cast_target(runtime.dispel_magic, me, target) then
        utils.log_debug(menu, "Dispel Magic")
        return true
    end
    return false
end

local function try_fade(me)
    if not menu.use_fade or not menu.use_fade:get_state() then return false end
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

local function try_inner_fire_shadow(me)
    if not runtime.inner_fire_id then return false end
    if utils.has_buff(me, spells.BUFF_INNER_FIRE) then return false end
    if not utils.can_cast_self(runtime.inner_fire_id, me) then return false end
    if utils.cast_self(runtime.inner_fire_id, me) then
        utils.log_debug(menu, "Inner Fire")
        return true
    end
    return false
end

local function try_vampiric_embrace(me)
    if not resolved.vampiric_embrace then return false end
    if utils.has_buff(me, spells.BUFF_VAMPIRIC_EMBRACE) then return false end
    if utils.cast_self(resolved.vampiric_embrace, me) then note_cast() return true end
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

local function try_sw_death(me, target)
    if not resolved.shadow_word_death then return false end
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

local function get_shadow_weaving_state(target)
    if not target then return 0, 0 end
    local data = buff_manager:get_debuff_data(target, spells.DEBUFF_SHADOW_WEAVING)
    if not data or not data.is_active then
        return 0, 0
    end
    local stacks = tonumber(data.stack_count or data.stacks or data.stack or 0) or 0
    local remaining = tonumber(data.remaining or 0) or 0
    return stacks, remaining
end

local function try_shadow_weaving(me, target)
    if not target or not menu.use_shadow_weaving:get_state() then return false end
    local stacks, remaining = get_shadow_weaving_state(target)
    local refresh_window = (menu.shadow_weaving_refresh_window:get() or 3) * 1000
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
    if menu.leveling_conserve_mana and menu.leveling_conserve_mana:get_state() then
        local player_level = me.get_level and me:get_level() or 70
        local target_level = target.get_level and target:get_level() or 70
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
    if not resolved.shadowfiend or not menu.shadowfiend_enabled:get_state() then
        return false
    end

    local cooldown = menu.shadowfiend_cooldown_seconds:get()
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
    if not menu.use_flash_heal:get_state() then return false end
    if not runtime.flash_heal_id then
        runtime.flash_heal_id = utils.resolve_spell_id(spells.FLASH_HEAL)
    end
    if not runtime.flash_heal_id then return false end
    local hp_pct = me:get_health_percentage() / 100
    if hp_pct > (menu.flash_heal_hp_pct:get() / 100) then return false end
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

                return interrupt_manager.try_interrupt(action_deps.me, interrupt_target, "priest", utils)
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
    if not menu.enabled:get_state() then
        return
    end
    -- Leveling fallback: wand enemy when mana low

    local me = _get_local_player()
    if not me or not me:is_valid() or me:is_dead() or not me:is_in_combat() then
        return
    end
    if not threat_initialized then threat_manager.init(me); threat_initialized = true end
        ooc_manager.on_update(me, menu, utils, {
        group_buffs = {
            { spell_id = runtime.ooc_power_word_fort_id,
               buff_ids = spells.BUFF_POWER_WORD_FORT,
               name = "Power Word: Fortitude",
               toggle = menu.ooc_group_buff },
            { spell_id = runtime.ooc_divine_spirit_id,
               buff_ids = spells.BUFF_DIVINE_SPIRIT,
               name = "Divine Spirit",
               toggle = menu.ooc_group_buff },
        },
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

    update_set_bonus(me)

    local mode = utils.get_effective_mode(menu, runtime)
    log_mode(mode)

    if ensure_shadowform(me) then return end

    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and not me:can_attack(focus_target) then focus_target = nil end
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
    
    -- Self-emergency
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_flash_heal then try_flash_heal(me, me) end
    end

    -- PvP cooldowns: trinket, pain suppression, dispersion
    local pvp_instance = pvp_manager.is_in_pvp_instance()
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

    if target and target:is_valid() and not target:is_dead() and me:can_attack(target) then
        local deps = { now_s = _core_time, get_gcd = _get_gcd }
        local ctx = rotation_context.get(ctx_cache, me, target, deps)

        -- Interrupt
        if interrupt_manager.should_interrupt(target) then
            if try_silence(me, target) then
                return
            end
            if interrupt_manager.try_interrupt(me, target, "priest", utils) then
                return
            end
        end

        if (enc and enc.force_dispel) or menu.use_dispel_magic:get_state() then
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

        if ctx and resource_gate.common.has_mana_pct(ctx, 0.04) and try_vampiric_embrace(me) then return end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.04) and try_inner_fire(me) then return end
        -- VT: refresh when remaining <= cast time (haste-aware)
        local vt_remaining = utils.get_debuff_remaining_ms(target, spells.DEBUFF_VAMPIRIC_TOUCH)
        local vt_cast_ms = 1500  -- TODO: apply haste reduction
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.16)
            and (vt_remaining <= vt_cast_ms or vt_remaining <= 0)
            and refresh_dot(me, target, resolved.vampiric_touch, spells.DEBUFF_VAMPIRIC_TOUCH) then invalidate_ctx() return end
        -- SW:P: only reapply when it falls off entirely (wowsims pattern)
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.10)
            and not utils.has_debuff(target, spells.DEBUFF_SHADOW_WORD_PAIN)
            and refresh_dot(me, target, resolved.shadow_word_pain, spells.DEBUFF_SHADOW_WORD_PAIN) then invalidate_ctx() return end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.14) and try_devouring_plague(me, target) then return end

        -- Execute phase: SW:D is highest priority when target < 25% HP
        local target_hp_pct = target and target:is_valid() and target:get_health_percentage() / 100 or 1.0
        if target_hp_pct < 0.25 and resolved.shadow_word_death then
            if resource_gate.common.has_mana_pct(ctx, 0.08) then
                if utils.can_cast_hostile(resolved.shadow_word_death, me, target) then
                    if utils.cast_target(resolved.shadow_word_death, target, "Shadow Word: Death") then
                        mark_pending_cast(resolved.shadow_word_death, 2.0)
                        utils.log_debug(menu, "SW:D (execute)")
                        note_cast()
                        return
                    end
                end
            end
        end

        if ctx and resource_gate.common.has_mana_pct(ctx, 0.10) and try_shadow_weaving(me, target) then return end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.12) and try_mind_blast(me, target) then return end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and try_mind_flay(me, target) then return end
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
        local label = "Eax Priest Shadow] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxpriestshadow_enabled_cp")
        return elements
    end)
end

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


