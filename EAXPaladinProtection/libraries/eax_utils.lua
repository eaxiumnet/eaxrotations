local utils = {}

-- TBC Drink buff IDs (verified TBC Classic values)
local _DRINK_BUFF_IDS = { 430, 2639, 1133, 10250, 22734, 27089 }
-- TBC Eat buff IDs (verified TBC Classic values)
local _EAT_BUFF_IDS = { 433, 787, 1131, 5004, 5005, 7737, 18191, 35270 }

function utils.is_eating_or_drinking(me)
    if not me or not me:is_valid() then return false end
    
    local buff_manager = require("common/modules/buff_manager")
    
    -- Check drink buffs
    local drink_data = buff_manager:get_buff_data(me, _DRINK_BUFF_IDS)
    if drink_data and drink_data.is_active then return true end
    
    -- Check eat buffs
    local eat_data = buff_manager:get_buff_data(me, _EAT_BUFF_IDS)
    if eat_data and eat_data.is_active then return true end
    
    -- Check if casting food/drink
    local ok_cast, is_casting = pcall(function() return me:is_casting_spell() end)
    if ok_cast and is_casting then
        local ok_spell, spell_id = pcall(function() return me:get_current_spell() end)
        if ok_spell and spell_id then
            local food_spells = { [433] = true, [434] = true, [435] = true }
            if food_spells[spell_id] then return true end
        end
    end
    
    return false
end

return utils
