-- EAX Priest Shadow | main.lua
-- Damage automation that maintains VampiricTouch/Shadow Word: Pain and fires Mind Blast/Mind Flay.

local menu = require("menu")
local key_helper = require("common/utility/key_helper")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")
local color     = require("color")

---@type interrupt_manager
local interrupt_manager = require("interrupt_manager")
---@type ooc_manager
local ooc_manager = require("ooc_manager")
---@type leveling_manager
local leveling_manager = require("leveling_manager")
---@type creature_utils
local creature_utils = require("creature_utils")

---@type encounter_manager
local encounter_manager = require("encounter_manager")


---@type esp_renderer
local esp_renderer = require("esp_renderer")
esp_renderer.init("shadow", "Priest Shadow")
---@type ttd_tracker
local ttd_tracker = require("ttd_tracker")
---@type racial_manager
local racial_manager = require("racial_manager")
---@type defensive_manager
local defensive_manager = require("defensive_manager")

---@type mana_conservator
local mana_conservator = require("mana_conservator")

local runtime = {
    resurrection_id = nil,
    flash_heal_id = nil,
    mode_cache = "solo",
    last_mode_check = 0,
    last_mode_log = nil,
    shadowfiend_last = 0,
    set_multiplier = 1.0,
    last_set_check = 0,
}

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
}

local function log_mode(mode)
    if menu.debug:get_state() and runtime.last_mode_log ~= mode then
        utils.log_debug(menu, "Mode=" .. mode)
        runtime.last_mode_log = mode
    end
end

local SET_UPDATE_INTERVAL_MS = 5000
local PRIEST_SET_NAMES = { "Vestments", "Absolution", "AbsolutionRegalia" }

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
        return utils.cast_self(resolved.shadowform, me)
    end

    return false
end

local function refresh_dot(me, target, spell_id, buff_ids, window_ms)
    if not spell_id or not target then
        return false
    end

    local remaining = utils.get_buff_remaining_ms(target, buff_ids)
    if remaining <= window_ms then
        return utils.cast_target(spell_id, me, target)
    end

    return false
end



-- --- Vampiric Embrace buff maintenance (v1.4) -----------------------------

local function try_vampiric_embrace(me)
    if not resolved.vampiric_embrace then return false end
    if utils.has_buff(me, spells.BUFF_VAMPIRIC_EMBRACE) then return false end
    return utils.cast_self(resolved.vampiric_embrace, me)
end

-- --- Inner Fire buff maintenance (v1.4) -----------------------------------

local function try_inner_fire(me)
    if not resolved.inner_fire then return false end
    if utils.has_buff(me, spells.BUFF_INNER_FIRE) then return false end
    if not menu.maintain_inner_fire or not menu.maintain_inner_fire:get_state() then return false end
    return utils.cast_self(resolved.inner_fire, me)
end

-- --- Shadow Word: Death execute (v1.4) ------------------------------------

local function try_sw_death(me, target)
    if not resolved.shadow_word_death then return false end
    if not menu.use_sw_death or not menu.use_sw_death:get_state() then return false end
    -- SW:D deals damage but also damages caster if it doesn't kill
    -- Use only below 25% HP (execute) or when TTD < 4s
    local hp = utils.get_health_pct(target)
    local is_execute = hp < 0.25 or ttd_tracker.get(target) < 4
    if not is_execute then return false end
    if not utils.can_cast_target(resolved.shadow_word_death, me, target) then return false end
    return utils.cast_target(resolved.shadow_word_death, target, "SW:Death")
end


local function try_devouring_plague(me, target)
    if not resolved.devouring_plague or not target then return false end
    if not menu.use_devouring_plague or not menu.use_devouring_plague:get_state() then return false end
    local dot_window_ms = menu.dot_refresh_window:get() * 1000
    local remain = utils.get_debuff_remaining_ms(target, spells.DEVOURING_PLAGUE)
    if remain > dot_window_ms then return false end
    return utils.cast_target(resolved.devouring_plague, me, target)
end


local function try_mind_blast(me, target)
    if not resolved.mind_blast or not target then
        return false
    end

    local dot_window_ms = menu.dot_refresh_window:get() * 1000
    local burst_window_ms = menu.mind_blast_burst_window:get() * 1000
    local vt_remain = utils.get_buff_remaining_ms(target, spells.VAMPIRIC_TOUCH)
    local swp_remain = utils.get_buff_remaining_ms(target, spells.SHADOW_WORD_PAIN)

    if vt_remain >= dot_window_ms and swp_remain >= dot_window_ms then
        return utils.cast_target(resolved.mind_blast, me, target)
    end

    if menu.mind_blast_burst:get_state() and (vt_remain <= burst_window_ms or swp_remain <= burst_window_ms) then
        return utils.cast_target(resolved.mind_blast, me, target)
    end

    return false
end

local function try_mind_flay(me, target)
    if not resolved.mind_flay or not target then
        return false
    end

    return utils.cast_target(resolved.mind_flay, me, target)
end

local function try_shadowfiend(me)
    if not resolved.shadowfiend or not menu.shadowfiend_enabled:get_state() then
        return false
    end

    local cooldown = menu.shadowfiend_cooldown_seconds:get()
    local now = core.time()

    if runtime.shadowfiend_last and (now - runtime.shadowfiend_last) < cooldown then
        return false
    end

    if utils.cast_self(resolved.shadowfiend, me) then
        runtime.shadowfiend_last = now
                esp_renderer.on_cast(nil, "Mind Blast", color.purple(220))
                esp_renderer.on_cast(nil, "Mind Flay", color.new(180,100,220,220))
                esp_renderer.on_cast(nil, "Shadowfiend", color.new(150,150,160,200))
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
    local cast_target = target or me
    if not cast_target:is_valid() then return false end
    if not utils.can_cast_target(runtime.flash_heal_id, me, cast_target) then return false end
    if utils.cast_target(runtime.flash_heal_id, me, cast_target) then
        utils.log_debug(menu, "Flash Heal (emergency)")
        return true
    end
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
    if not menu.enabled:get_state() then
        return
    end
    -- Leveling fallback: wand enemy when mana low

    local me = core.object_manager.get_local_player()
    if not me or not me:is_valid() or me:is_dead() or not me:is_in_combat() then
        return
    end
        ooc_manager.on_update(me, menu, utils, {
        group_buffs = {
            { spell_id = utils.resolve_spell_id(spells.POWER_WORD_FORT),
               buff_ids = spells.BUFF_POWER_WORD_FORT,
               name = "Power Word: Fortitude",
               toggle = menu.ooc_group_buff },
            { spell_id = utils.resolve_spell_id(spells.DIVINE_SPIRIT),
               buff_ids = spells.BUFF_DIVINE_SPIRIT,
               name = "Divine Spirit",
               toggle = menu.ooc_group_buff },
        },
    })
    if eax_utils.is_eating_or_drinking(me) then return end

    update_set_bonus(me)

    local mode = utils.get_effective_mode(menu, runtime)
    log_mode(mode)

    ensure_shadowform(me)

    local target = me:get_target()
    
    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and focus_target:is_valid() then
        target = focus_target
    end
    
    -- Self-emergency
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_flash_heal then try_flash_heal(me, me) end
    end
    
    -- Mana conservator: wand/melee when low on mana (leveling safety)
    if mana_conservator.on_update(me, target, menu, utils) then return end

    if target and target:is_valid() and not target:is_dead() and me:can_attack(target) then
        -- Interrupt
        if interrupt_manager.should_interrupt(target) then
            if interrupt_manager.try_interrupt(me, target, "priest", utils) then
                return
            end
        end

        -- Racial CDs
        racial_manager.try_offensive(me)
        racial_manager.try_utility(me, target)

        -- Defensive abilities
    ttd_tracker.update(target)

        if defensive_manager.try_defensive(me, "priest", utils) then
            return
        end

        local dot_window_ms = menu.dot_refresh_window:get() * 1000
        try_vampiric_embrace(me)
        try_inner_fire(me)
        refresh_dot(me, target, resolved.vampiric_touch, spells.VAMPIRIC_TOUCH, dot_window_ms)
        refresh_dot(me, target, resolved.shadow_word_pain, spells.SHADOW_WORD_PAIN, dot_window_ms)
        if try_devouring_plague(me, target) then return end

        if not try_mind_blast(me, target) then
            try_mind_flay(me, target)
        end
    end

    try_shadowfiend(me)
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
        if menu.enabled:get_state() then
        if menu.use_cooldowns then
            local cur_psh_cds = menu.use_cooldowns:get_state()
            local nxt_psh_cds = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX PSh] Cooldowns", cur_psh_cds, 0, false, "eax_psh_cds_cp")
            if nxt_psh_cds ~= cur_psh_cds then menu.use_cooldowns:set(nxt_psh_cds) end
        end
        if menu.focus_priority then
            local cur_psh_focus = menu.focus_priority:get_state()
            local nxt_psh_focus = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX PSh] Focus Priority", cur_psh_focus, 0, false, "eax_psh_focus_cp")
            if nxt_psh_focus ~= cur_psh_focus then menu.focus_priority:set(nxt_psh_focus) end
        end
        if menu.use_racial then
            local cur_psh_racial = menu.use_racial:get_state()
            local nxt_psh_racial = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX PSh] Use Racial", cur_psh_racial, 0, false, "eax_psh_racial_cp")
            if nxt_psh_racial ~= cur_psh_racial then menu.use_racial:set(nxt_psh_racial) end
        end
        end
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


