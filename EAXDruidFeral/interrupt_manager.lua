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
        { id = 14768, name = "counter_shot",    type = "fast" },
        -- Marksmanship talent: Silencing Shot
        { id = 34490, name = "silencing_shot",  type = "fast" },
    },
    paladin = {
        { id = 31935, name = "rebuke", type = "fast" },
        { id = 20066, name = "hammer_of_justice", type = "stun" },
    },
    shaman = {
        -- TBC: Earth Shock is the shaman interrupt (Wind Shear = Wrath+)
        { id = 10414, name = "earth_shock",   type = "fast" },   -- Earth Shock rank 8
        { id = 10413, name = "earth_shock",   type = "fast" },   -- rank 7
        { id = 10412, name = "earth_shock",   type = "fast" },   -- rank 6
        { id = 8042,  name = "earth_shock",   type = "fast" },   -- rank 5
        { id = 8044,  name = "earth_shock",   type = "fast" },   -- rank 4
        { id = 8045,  name = "earth_shock",   type = "fast" },   -- rank 3
        { id = 8046,  name = "earth_shock",   type = "fast" },   -- rank 2
        { id = 49,    name = "earth_shock",   type = "fast" },   -- rank 1
    },
    mage = {
        { id = 2139, name = "counterspell", type = "fast" },
    },
    priest = {
        { id = 15487, name = "silence", type = "fast" },
    },
    druid = {
        -- TBC: Skull Bash is Cataclysm+. Feral uses Feral Charge (Cat) to kick.
        -- Bear form: Bash (stun, not a true interrupt but the best available)
        { id = 8983,  name = "bash",              type = "stun" },  -- Bash rank 3
        { id = 1822,  name = "bash",              type = "stun" },  -- rank 2
        { id = 5211,  name = "bash",              type = "stun" },  -- rank 1
        -- Caster form: Cyclone (DR-limited, last resort)
        { id = 33786, name = "cyclone",           type = "stun" },
    },
    warlock = {
        { id = 19647, name = "shadowfury",  type = "stun" },
        -- Felhunter pet ability: Spell Lock (channelled silence/interrupt)
        { id = 24259, name = "spell_lock",  type = "fast" },
    },
}


-- Priority interrupt whitelist (from OpenWarrior2/core/interrupt_library.lua)
-- Higher weight = higher priority interrupt target
local DANGEROUS_SPELLS = {
    -- Healing
    [2061]  = 70,  -- Flash Heal
    [331]   = 70,  -- Healing Wave
    [20473] = 65,  -- Holy Shock
    [635]   = 60,  -- Holy Light
    -- CC
    [118]   = 80,  -- Polymorph
    [5484]  = 75,  -- Howl of Terror
    [8122]  = 75,  -- Psychic Scream
    [2094]  = 70,  -- Blind
    -- Big nukes
    [116]   = 50,  -- Frostbolt
    [133]   = 50,  -- Fireball
    [686]   = 50,  -- Shadow Bolt
    -- Buffs/summons worth interrupting
    [755]   = 55,  -- Health Funnel
    [20484] = 60,  -- Rebirth (battle rez)
}

local function get_interrupt_priority(target)
    if not target or not target:is_casting_spell() then return 0 end
    local spell_id = target.get_active_spell_id and target:get_active_spell_id()
    if spell_id and DANGEROUS_SPELLS[spell_id] then
        return DANGEROUS_SPELLS[spell_id]
    end
    return 25  -- default weight for unknown spells
end


function interrupt_manager.get_interrupt_spells(class_name)
    return INTERRUPT_SPELLS[class_name] or {}
end

function interrupt_manager.should_interrupt(target)
    if not target then return false end
    if not target:is_casting_spell() and not target:is_channelling_spell() then return false end
    if target:is_casting_spell() and not target:is_active_spell_interruptable() then return false end
    return true
end

function interrupt_manager.get_priority(target)
    return get_interrupt_priority(target)
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
