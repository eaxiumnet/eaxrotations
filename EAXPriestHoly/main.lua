-- EAX Priest Holy | main.lua
-- Healing rotation that keeps Renew, Greater Heal, and Prayer of Healing prioritized.

local menu = require("menu")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")

---@type interrupt_manager
local interrupt_manager = require("common/eax_shared/interrupt_manager")
---@type defensive_manager
local defensive_manager = require("common/eax_shared/defensive_manager")

local runtime = {
    mode_cache = "solo",
    last_mode_check = 0,
    last_mode_log = nil,
}

local resolved = {
    renew = utils.resolve_spell_id(spells.RENEW),
    greater_heal = utils.resolve_spell_id(spells.GREATER_HEAL),
    prayer_of_healing = utils.resolve_spell_id(spells.PRAYER_OF_HEALING),
    prayer_of_mending = utils.resolve_spell_id(spells.PRAYER_OF_MENDING),
}

local function log_mode(mode)
    if menu.debug:get_state() and runtime.last_mode_log ~= mode then
        utils.log_debug(menu, "Mode=" .. mode)
        runtime.last_mode_log = mode
    end
end

local function try_renew(me)
    if not resolved.renew then
        return false
    end

    local threshold = menu.renew_threshold:get() / 100
    local window_ms = menu.renew_refresh_seconds:get() * 1000
    local units = utils.get_party_units(me)
    local candidate = nil
    local lowest_pct = threshold

    for i = 1, #units do
        local unit = units[i]
        if unit then
            local pct = utils.get_health_pct(unit)
            if pct <= threshold and pct <= lowest_pct then
                local remaining = utils.get_buff_remaining_ms(unit, spells.RENEW)
                if remaining <= window_ms then
                    candidate = unit
                    lowest_pct = pct
                end
            end
        end
    end

    if not candidate then
        candidate = utils.find_low_health_ally(me, threshold, true)
    end

    if candidate and not utils.has_buff(candidate, spells.RENEW) then
        return utils.cast_target(resolved.renew, me, candidate)
    end

    return false
end

local function try_prayer_of_healing(me)
    if not resolved.prayer_of_healing or not menu.prayer_of_healing_enabled:get_state() then
        return false
    end

    local threshold = menu.prayer_of_healing_threshold:get() / 100
    local count = 0
    local units = utils.get_party_units(me)

    for i = 1, #units do
        local unit = units[i]
        if unit and utils.get_health_pct(unit) <= threshold then
            count = count + 1
        end
    end

    if count >= menu.prayer_of_healing_count:get() then
        return utils.cast_self(resolved.prayer_of_healing, me)
    end

    return false
end

local function try_greater_heal(me)
    if not resolved.greater_heal then
        return false
    end

    local threshold = menu.greater_heal_threshold:get() / 100
    local candidate = utils.find_low_health_ally(me, threshold, true)

    if candidate then
        return utils.cast_target(resolved.greater_heal, me, candidate)
    end

    return false
end

local function try_prayer_of_mending(me)
    if not resolved.prayer_of_mending or not menu.auto_prayer_of_mending:get_state() then
        return false
    end

    local threshold = menu.prayer_of_mending_threshold:get() / 100
    local candidate = utils.find_low_health_ally(me, threshold, true)

    if candidate and not utils.has_buff(candidate, spells.PRAYER_OF_MENDING) then
        return utils.cast_target(resolved.prayer_of_mending, me, candidate)
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

    -- Overheal Protection - cancel slow heals if target is healthy
    if eax_utils.should_stopcasting(me, menu) then
        if SpellStopCasting then SpellStopCasting() end
    end

    -- Interrupt (PVP)
    local target = me:get_target()
    if target and target:is_valid() and target:is_enemy() and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "priest", utils) then
            return
        end
    end

    -- Defensive abilities
    if defensive_manager.try_defensive(me, "priest", utils) then
        return
    end

    -- Focus Target Priority - heal focus target first
    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target then
        local focus_hp = focus_target:get_health_percentage()
        if focus_hp < menu.greater_heal_threshold:get() then
            if try_cast_spell(me, focus_target, resolved.greater_heal) then
                return
            end
        end
    end

    -- Combat-aware self HP threshold
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_cast_spell(me, me, resolved.greater_heal) then
            return
        end
    end

    local mode = utils.get_effective_mode(menu, runtime)
    log_mode(mode)

    try_renew(me)
    try_prayer_of_healing(me)
    try_greater_heal(me)
    try_prayer_of_mending(me)
end)

core.register_on_render_menu_callback(function()
    menu.render()
end)
