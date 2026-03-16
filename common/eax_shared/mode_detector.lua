-- mode_detector.lua
-- Auto-detect solo/dungeon/raid mode

local mode_detector = {}
local last_refresh = 0
local REFRESH_INTERVAL = 5.0

function mode_detector.detect_mode()
    local objects = core.object_manager.get_all_objects()
    local party_count = 0
    
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() 
           and obj:is_party_member() then
            party_count = party_count + 1
        end
    end
    
    if party_count == 0 then
        return "solo"
    elseif party_count <= 4 then
        return "dungeon"
    end
    return "raid"
end

function mode_detector.get_effective_mode(menu_settings, cached_mode)
    if not menu_settings or not menu_settings.mode then
        return cached_mode or "solo"
    end
    
    local selection = menu_settings.mode:get()
    if selection == 2 then return "solo" end
    if selection == 3 then return "dungeon" end
    if selection == 4 then return "raid" end
    
    return cached_mode or "solo"
end

function mode_detector.should_refresh()
    local now = core.time()
    if (now - last_refresh) < REFRESH_INTERVAL then
        return false, nil
    end
    last_refresh = now
    return true, mode_detector.detect_mode()
end

return mode_detector
