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
    -- === HEALING (highest priority) ===
    -- Paladin
    [635]   = 90,  -- Holy Light (rank 1-11; highest rank is 25292)
    [25292] = 90,  -- Holy Light rank 11
    [27135] = 90,  -- Holy Light rank 9
    [20473] = 85,  -- Holy Shock
    [19750] = 75,  -- Flash of Light
    [27137] = 75,  -- Flash of Light rank 6
    -- Priest
    [2061]  = 85,  -- Flash Heal
    [25233] = 85,  -- Flash Heal rank 9
    [2060]  = 80,  -- Greater Heal
    [25314] = 80,  -- Greater Heal rank 6
    [596]   = 75,  -- Prayer of Healing
    [25316] = 75,  -- Prayer of Healing rank 6
    [139]   = 65,  -- Renew (DoT heal - worth stopping before it starts)
    -- Druid
    [8936]  = 80,  -- Regrowth
    [25299] = 80,  -- Regrowth rank 10
    [5185]  = 70,  -- Healing Touch
    [25297] = 70,  -- Healing Touch rank 11
    -- Shaman
    [331]   = 85,  -- Healing Wave rank 1-11
    [25357] = 85,  -- Healing Wave rank 11
    [8004]  = 75,  -- Lesser Healing Wave
    [25420] = 75,  -- Lesser Healing Wave rank 7
    [1064]  = 80,  -- Chain Heal rank 1-5
    [25422] = 80,  -- Chain Heal rank 5
    -- Warlock
    [755]   = 65,  -- Health Funnel

    -- === CROWD CONTROL (high priority) ===
    [118]   = 95,  -- Polymorph
    [28272] = 95,  -- Polymorph: Pig
    [28271] = 95,  -- Polymorph: Turtle
    [12826] = 95,  -- Polymorph (rank 4)
    [33786] = 90,  -- Cyclone
    [605]   = 90,  -- Mind Control
    [5484]  = 85,  -- Howl of Terror
    [8122]  = 85,  -- Psychic Scream
    [8124]  = 85,  -- Psychic Scream rank 3
    [10890] = 85,  -- Psychic Scream rank 4
    [2094]  = 80,  -- Blind
    [6358]  = 80,  -- Seduction (succubus)
    [710]   = 85,  -- Banish
    [18647] = 85,  -- Banish rank 2

    -- === RESURRECTIONS ===
    [2006]  = 95,  -- Resurrection
    [20484] = 95,  -- Rebirth (Druid battle rez)
    [2008]  = 90,  -- Ancestral Spirit (Shaman)
    [8171]  = 90,  -- Ancestral Spirit rank 4
    [10060] = 90,  -- Power Infusion (Priest) - massive haste buff

    -- === BIG OFFENSIVE CASTS ===
    [116]   = 60,  -- Frostbolt
    [25304] = 60,  -- Frostbolt rank 12
    [133]   = 60,  -- Fireball
    [27070] = 60,  -- Fireball rank 12
    [11366] = 65,  -- Pyroblast
    [27085] = 65,  -- Pyroblast rank 9
    [686]   = 55,  -- Shadow Bolt
    [25307] = 55,  -- Shadow Bolt rank 11
    [1120]  = 60,  -- Drain Soul
    [11675] = 60,  -- Drain Soul rank 4
    [2812]  = 55,  -- Holy Smite / Smite
    [25364] = 55,  -- Smite rank 9
    [9739]  = 55,  -- Starfire
    [25298] = 55,  -- Starfire rank 8
    [5570]  = 50,  -- Insect Swarm
    [24974] = 50,  -- Insect Swarm rank 5

    -- === SUMMONS ===
    [688]   = 70,  -- Summon Imp
    [691]   = 70,  -- Summon Felhunter
    [712]   = 70,  -- Summon Succubus
    [697]   = 70,  -- Summon Voidwalker
    [30146] = 70,  -- Summon Felguard
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

-- Per-spell cast timestamps to prevent spam-casting CC/interrupt spells.
-- CC spells like Cyclone have long durations — we must not recast until
-- the spell_book cooldown clears AND enough time has passed.
local _last_cast = {}
local CC_RECAST_DELAY = {
    [33786] = 20.0,  -- Cyclone (20s duration)
    [8983]  = 10.0,  -- Bash (10s CD)
    [5211]  = 10.0,  -- Bash
    [1822]  = 10.0,  -- Bash
    [20066] = 10.0,  -- Hammer of Justice
    [19647] = 20.0,  -- Shadowfury
}
local DEFAULT_CC_RECAST_DELAY = 2.0  -- minimum gap for any interrupt spell

local function _can_recast(spell_id)
    local delay = CC_RECAST_DELAY[spell_id] or DEFAULT_CC_RECAST_DELAY
    local last = _last_cast[spell_id] or 0
    return (core.time() - last) >= delay
end

local function _mark_cast(spell_id)
    _last_cast[spell_id] = core.time()
end

function interrupt_manager.try_interrupt(me, target, class_name, utils_module)
    if not interrupt_manager.should_interrupt(target) then return false end

    local spells = interrupt_manager.get_interrupt_spells(class_name)
    if #spells == 0 then return false end

    for _, spell in ipairs(spells) do
        if spell.type == "fast" then
            local spell_id = utils_module.resolve_spell_id(spell.id)
            if spell_id and _can_recast(spell_id)
               and utils_module.can_cast_hostile(spell_id, me, target) then
                if utils_module.cast_target(spell_id, target) then
                    _mark_cast(spell_id)
                    return true
                end
            end
        end
    end

    for _, spell in ipairs(spells) do
        if spell.type ~= "fast" then
            local spell_id = utils_module.resolve_spell_id(spell.id)
            if spell_id and _can_recast(spell_id)
               and utils_module.can_cast_hostile(spell_id, me, target) then
                if utils_module.cast_target(spell_id, target) then
                    _mark_cast(spell_id)
                    return true
                end
            end
        end
    end

    return false
end

return interrupt_manager
