-- EAX Priest Shadow | main.lua
-- Damage automation that maintains VampiricTouch/Shadow Word: Pain and fires Mind Blast/Mind Flay.

local menu = require("menu")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")

---@type interrupt_manager
local interrupt_manager = require("common/eax_shared/interrupt_manager")
---@type ttd_tracker
local ttd_tracker = require("common/eax_shared/ttd_tracker")
---@type racial_manager
local racial_manager = require("common/eax_shared/racial_manager")
---@type defensive_manager
local defensive_manager = require("common/eax_shared/defensive_manager")

local runtime = {
    mode_cache = "solo",
    last_mode_check = 0,
    last_mode_log = nil,
    shadowfiend_last = 0,
}

local resolved = {
    vampiric_touch    = utils.resolve_spell_id(spells.VAMPIRIC_TOUCH),
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
        return true
    end

    return false
end

core.register_on_update_callback(function()
    if not menu.enabled:get_state() then
        return
    end

    local me = core.object_manager.get_local_player()
    if not me or not me:is_valid() or me:is_dead() or not me:is_in_combat() then
        return
    end

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
        refresh_dot(me, target, resolved.vampiric_touch, spells.VAMPIRIC_TOUCH, dot_window_ms)
        refresh_dot(me, target, resolved.shadow_word_pain, spells.SHADOW_WORD_PAIN, dot_window_ms)
        if try_devouring_plague(me, target) then return end

        if not try_mind_blast(me, target) then
            try_mind_flay(me, target)
        end
    end

    try_shadowfiend(me)
end)

core.register_on_render_menu_callback(function()
    menu.render()
end)
