-- EAX Priest Shadow | main.lua
-- Damage automation that maintains VampiricTouch/Shadow Word: Pain and fires Mind Blast/Mind Flay.

local menu = require("menu")
local rotation_context = require("rotation_context")
local resource_gate = require("resource_gate")
local key_helper = require("common/utility/key_helper")
local spells = require("spells")
local utils = require("utils")

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
---@type vendor_automation
local vendor_automation = require("vendor_automation")
---@type consumables_manager
local consumables_manager = require("consumables_manager")
---@type mount_manager
local mount_manager = require("mount_manager")
---@type leveling_manager
local leveling_manager = require("leveling_manager")
---@type creature_utils
local creature_utils = require("creature_utils")

---@type encounter_manager
local encounter_manager = require("encounter_manager")


---@type esp_renderer
local esp_renderer = require("esp_renderer")
esp_renderer.init("shadow", "Priest Shadow")
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
        smart_cast_manager.clear_all_pending()
    elseif (not in_combat) and _visual_runtime.in_combat then
        dps_meter.on_combat_end()
        _visual_runtime.in_combat = false
        _visual_runtime.last_me_hp_pct = nil
        _visual_runtime.last_target_hp_pct = nil
        smart_cast_manager.reset()
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
local ttd_tracker = require("ttd_tracker")
---@type racial_manager
local racial_manager = require("racial_manager")
---@type defensive_manager
local defensive_manager = require("defensive_manager")

---@type mana_conservator
local mana_conservator = require("mana_conservator")
---@type dot_manager
local dot_manager = require("dot_manager")
---@type mana_manager
local mana_manager = require("mana_manager")
---@type threat_manager
local threat_manager = require("threat_manager")

-- Guard to init threat_manager only once at startup
local threat_initialized = false

local runtime = {
    last_cast_time = 0,
    dispersion_id = nil,
    resurrection_id = nil,
    flash_heal_id = nil,
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
    shadow_weaving_buff = 25423,
}

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
    if utils.cast_target(spell_id, me, target) then note_cast() return true end
    return false
end

local function dots_active(target)
    return utils.get_debuff_remaining_ms(target, spells.DEBUFF_VAMPIRIC_TOUCH) > 0
        and utils.get_debuff_remaining_ms(target, spells.DEBUFF_SHADOW_WORD_PAIN) > 0
        and utils.get_debuff_remaining_ms(target, spells.DEBUFF_DEVOURING_PLAGUE) > 0
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
    local is_execute = hp <= 0.25 or (hp <= 0.35 and ttd <= 2)
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

local function try_mind_flay(me, target)
    if not resolved.mind_flay or not target then
        return false
    end
    if utils.cast_target(resolved.mind_flay, me, target) then note_cast() return true end
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

    local mode = utils.get_effective_mode(menu, runtime)
    log_mode(mode)

    if ensure_shadowform(me) then return end

    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and not me:can_attack(focus_target) then focus_target = nil end
    local target = focus_target or utils.find_best_target(me)
    
    -- Self-emergency
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_flash_heal then try_flash_heal(me, me) end
    end
    
    -- Mana conservator: wand/melee when low on mana (leveling safety)
    if mana_conservator.on_update(me, target, menu, utils) then return end

    if target and target:is_valid() and not target:is_dead() and me:can_attack(target) then
        local deps = { now_s = _core_time, get_gcd = _get_gcd }
        local ctx = rotation_context.get(ctx_cache, me, target, deps)

        -- Interrupt
        if interrupt_manager.should_interrupt(target) then
            if interrupt_manager.try_interrupt(me, target, "priest", utils) then
                return
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

        if try_psychic_scream(me, target) then return true end
        if defensive_manager.try_defensive(me, "priest", utils) then
            return
        end

        -- Threat fade protection — don't pull aggro from tank
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
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.16) and refresh_dot(me, target, resolved.vampiric_touch, spells.DEBUFF_VAMPIRIC_TOUCH) then invalidate_ctx() return end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.10) and refresh_dot(me, target, resolved.shadow_word_pain, spells.DEBUFF_SHADOW_WORD_PAIN) then invalidate_ctx() return end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.14) and try_devouring_plague(me, target) then return end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.12) and try_mind_blast(me, target) then return end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.12) and try_sw_death(me, target) then return end
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
        local label = "EAX Priest Shadow] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxpriestshadow_enabled_cp")
        return elements
    end)
end

-- -- EAX Conflict Detection -------------------------------------------------
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


