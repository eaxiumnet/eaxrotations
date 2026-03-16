-- pet_manager.lua
-- Hunter and Warlock pet management

local pet_manager = {}

function pet_manager.has_pet()
    return core.pet and core.pet.get_pet ~= nil
end

function pet_manager.get_pet()
    if not core.pet then return nil end
    return core.pet.get_pet()
end

function pet_manager.is_pet_alive()
    local pet = pet_manager.get_pet()
    return pet and pet:is_valid() and not pet:is_dead()
end

function pet_manager.pet_attack(target)
    if not target or not target:is_valid() then return false end
    if not core.pet or not core.pet.attack then return false end
    return core.pet.attack(target)
end

function pet_manager.pet_stay()
    if not core.pet or not core.pet.stay then return false end
    return core.pet.stay()
end

return pet_manager
