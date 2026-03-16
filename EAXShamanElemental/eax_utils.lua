-- eax_utils.lua
-- EAX Universal Utilities - Local module for DPS

local eax_utils = {}

--- Focus Target Priority
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

--- Combat-aware Self HP
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
