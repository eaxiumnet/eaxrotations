-- target_finder.lua
-- Target selection with focus priority

local target_finder = {}

function target_finder.is_valid_hostile(me, target)
    return target and target:is_valid() and not target:is_dead() and me:can_attack(target)
end

function target_finder.find_valid_target(me)
    local target = me:get_target()
    if target_finder.is_valid_hostile(me, target) then
        return target
    end
    
    local objects = core.object_manager.get_visible_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if target_finder.is_valid_hostile(me, obj) then
            return obj
        end
    end
    
    return nil
end

function target_finder.get_focus_target(menu_settings)
    if not menu_settings or not menu_settings.focus_priority then
        return nil
    end
    
    local focus_enabled = false
    if type(menu_settings.focus_priority.get_state) == "function" then
        focus_enabled = menu_settings.focus_priority:get_state()
    end
    
    if not focus_enabled then return nil end
    if not core.input or not core.input.get_focus then return nil end
    
    local focus = core.input.get_focus()
    if not focus or not focus.is_valid or not focus:is_valid() then return nil end
    if focus.is_dead and focus:is_dead() then return nil end
    
    return focus
end

return target_finder
