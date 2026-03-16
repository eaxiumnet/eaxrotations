-- eax_utils.lua
-- EAX Universal Utilities - Local module for healers

---@type unit_helper
local unit_helper = require("common/utility/unit_helper")

local eax_utils = {}

function eax_utils.should_stopcasting(me, menu_settings)
    if not menu_settings or not menu_settings.overheal_protection then
        return false
    end
    
    local overheal_enabled = false
    if type(menu_settings.overheal_protection.get_state) == "function" then
        overheal_enabled = menu_settings.overheal_protection:get_state()
    end
    
    if not overheal_enabled then
        return false
    end
    
    if not me or not me.is_casting_spell or not me:is_casting_spell() then
        return false
    end
    
    local target = me.get_active_spell_target and me:get_active_spell_target()
    if not target or not target.is_valid or not target:is_valid() or (target.is_dead and target:is_dead()) then
        return false
    end
    
    local hp_pct_inc, inc_dmg = unit_helper:get_health_percentage_inc(target, 2.0)
    local max_hp = target.get_max_health and target:get_max_health() or 1
    
    if hp_pct_inc >= 0.98 and inc_dmg < max_hp * 0.05 then
        return true
    end
    
    return false
end

function eax_utils.get_predictive_hp(unit, time_ahead_seconds)
    if not unit or not unit.is_valid or not unit:is_valid() then
        return 1.0, 0, 1.0, 0
    end
    local time_limit = time_ahead_seconds or 2.0
    return unit_helper:get_health_percentage_inc(unit, time_limit)
end

function eax_utils.get_focus_target(menu_settings)
    if not menu_settings or not menu_settings.focus_priority then
        return nil
    end
    
    local focus_enabled = false
    if type(menu_settings.focus_priority.get_state) == "function" then
        focus_enabled = menu_settings.focus_priority:get_state()
    end
    
    if not focus_enabled then
        return nil
    end
    
    if not core.input or not core.input.get_focus then
        return nil
    end
    
    local focus = core.input.get_focus()
    if not focus or not focus.is_valid or not focus:is_valid() then
        return nil
    end
    
    if focus.is_dead and focus:is_dead() then
        return nil
    end
    
    return focus
end

function eax_utils.get_self_heal_threshold(me, base_threshold, menu_settings)
    if not me or not me.is_valid or not me:is_valid() then
        return base_threshold
    end
    
    local in_combat = false
    if me.is_in_combat then
        in_combat = me:is_in_combat()
    end
    
    local boost = 0
    if menu_settings and menu_settings.combat_self_hp_boost then
        if type(menu_settings.combat_self_hp_boost.get) == "function" then
            boost = menu_settings.combat_self_hp_boost:get() / 100
        end
    end
    
    if in_combat then
        return math.min(base_threshold + boost, 0.95)
    else
        return base_threshold
    end
end

return eax_utils
