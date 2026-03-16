-- interrupt_manager.lua
-- Priority-based interrupt system

local interrupt_manager = {}

local INTERRUPT_SPELLS = {
    warrior = {
        { id = 6552, name = "pummel", type = "fast" },
        { id = 6554, name = "pummel", type = "fast" },
    },
    rogue = {
        { id = 1766, name = "kick", type = "fast" },
        { id = 8959, name = "kick", type = "fast" },
        { id = 17699, name = "kick", type = "fast" },
    },
    hunter = {
        { id = 14768, name = "counter_shot", type = "fast" },
    },
    paladin = {
        { id = 31935, name = "rebuke", type = "fast" },
        { id = 20066, name = "hammer_of_justice", type = "stun" },
    },
    shaman = {
        { id = 57994, name = "wind_shear", type = "fast" },
    },
    mage = {
        { id = 2139, name = "counterspell", type = "fast" },
    },
    priest = {
        { id = 15487, name = "silence", type = "fast" },
    },
    druid = {
        { id = 80965, name = "skull_bash", type = "fast" },
    },
    warlock = {
        { id = 19647, name = "shadowfury", type = "stun" },
    },
}

function interrupt_manager.get_interrupt_spells(class_name)
    return INTERRUPT_SPELLS[class_name] or {}
end

function interrupt_manager.should_interrupt(target)
    if not target then return false end
    if not target:is_casting_spell() then return false end
    if not target:is_active_spell_interruptable() then return false end
    return true
end

function interrupt_manager.try_interrupt(me, target, class_name, utils_module)
    if not interrupt_manager.should_interrupt(target) then return false end
    
    local spells = interrupt_manager.get_interrupt_spells(class_name)
    if #spells == 0 then return false end
    
    for _, spell in ipairs(spells) do
        if spell.type == "fast" then
            local spell_id = utils_module.resolve_spell_id(spell.id)
            if spell_id and utils_module.can_cast_target(spell_id, me, target) then
                if utils_module.cast_target(spell_id, me, target) then
                    return true
                end
            end
        end
    end
    
    for _, spell in ipairs(spells) do
        if spell.type ~= "fast" then
            local spell_id = utils_module.resolve_spell_id(spell.id)
            if spell_id and utils_module.can_cast_target(spell_id, me, target) then
                if utils_module.cast_target(spell_id, me, target) then
                    return true
                end
            end
        end
    end
    
    return false
end

return interrupt_manager
