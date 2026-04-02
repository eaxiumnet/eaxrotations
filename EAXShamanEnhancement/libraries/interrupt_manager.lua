-- interrupt_manager.lua
-- interrupt_manager.lua
-- Priority-based interrupt system for all TBC Classic classes.
-- Consolidated from per-spec implementations.

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
        { id = 34490, name = "silencing_shot",  type = "fast" },
    },
    paladin = {
        -- TBC Paladin has no dedicated fast interrupt; only a stun-based stop.
        { id = 20066, name = "hammer_of_justice", type = "stun" },
    },
    shaman = {
        { id = 10414, name = "earth_shock",   type = "fast" },
        { id = 10413, name = "earth_shock",   type = "fast" },
        { id = 10412, name = "earth_shock",   type = "fast" },
        { id = 8042,  name = "earth_shock",   type = "fast" },
        { id = 8044,  name = "earth_shock",   type = "fast" },
        { id = 8045,  name = "earth_shock",   type = "fast" },
        { id = 8046,  name = "earth_shock",   type = "fast" },
        { id = 49,    name = "earth_shock",   type = "fast" },
    },
    mage = {
        { id = 2139, name = "counterspell", type = "fast" },
    },
    priest = {
        { id = 15487, name = "silence", type = "fast" },
    },
    druid = {
        { id = 8983,  name = "bash",              type = "stun" },
        { id = 1822,  name = "bash",              type = "stun" },
        { id = 5211,  name = "bash",              type = "stun" },
        -- Cyclone is crowd control and should not be used by the generic boss interrupt path.
    },
    warlock = {
        { id = 19647, name = "shadowfury",  type = "stun" },
        { id = 24259, name = "spell_lock",  type = "fast" },
    },
}

-- Minimum cast time remaining to bother interrupting (ms)
-- Server latency means we can't react if cast finishes in < 200ms
local MIN_CAST_TIME_MS = 200

-- Class IDs for healer detection
local HEALER_CLASSES = {
    [5] = true,   -- Priest
    [11] = true,  -- Druid
    [2] = true,   -- Paladin
    [7] = true,   -- Shaman
}

local DANGEROUS_SPELLS = {
    -- Existing healing spells
    [635]   = 90,  [25292] = 90,  [27135] = 90,
    [20473] = 85,  [19750] = 75,  [27137] = 75,
    [2061]  = 85,  [25233] = 85,  [2060]  = 80,
    [25314] = 80,  [596]   = 75,  [25316] = 75,
    [139]   = 65,
    [8936]  = 80,  [25299] = 80,  [5185]  = 70,
    [25297] = 70,
    [331]   = 85,  [25357] = 85,  [8004]  = 75,
    [25420] = 75,  [1064]  = 80,  [25422] = 80,
    [755]   = 65,
    [118]   = 95,  [28272] = 95,  [28271] = 95,
    [12826] = 95,  [33786] = 90,  [605]   = 90,
    [5484]  = 85,  [8122]  = 85,  [8124]  = 85,
    [10890] = 85,  [2094]  = 80,  [6358]  = 80,
    [710]   = 85,  [18647] = 85,
    [2006]  = 95,  [20484] = 95,  [2008]  = 90,
    [8171]  = 90,  [10060] = 90,
    [116]   = 60,  [25304] = 60,  [133]   = 60,
    [27070] = 60,  [11366] = 65,  [27085] = 65,
    [686]   = 55,  [25307] = 55,  [1120]  = 60,
    [11675] = 60,  [2812]  = 55,  [25364] = 55,
    [9739]  = 55,  [25298] = 55,  [5570]  = 50,
    [24974] = 50,
    [688]   = 70,  [691]   = 70,  [712]   = 70,
    [697]   = 70,  [30146] = 70,
    -- Boss encounter dangerous casts
    [30511] = 92,  -- Magtheridon Shadow Nova
    [36092] = 95,  -- M'uru Void Blast
    [45742] = 95,  -- Kil'jaeden Flame Spike
    [45770] = 92,  -- Kil'jaeden Shadow Spike
    [34917] = 90,  -- Vampiric Touch (shadow priest)
    [26555] = 85,  -- Void Reaver Pounding
    -- Additional healer spells with priority
    [5040]  = 85,  -- Nourish
    [26980] = 85,  -- Healing Touch rank 13
    [20787] = 80,  -- Regrowth rank 9
    [26981] = 80,  -- Rejuvenation rank 13
    [25423] = 88,  -- Chain Heal rank 4
}

local function get_interrupt_priority(target)
    if not target or not target:is_casting_spell() then return 0 end
    local spell_id = target.get_active_spell_id and target:get_active_spell_id()
    if spell_id and DANGEROUS_SPELLS[spell_id] then
        return DANGEROUS_SPELLS[spell_id]
    end
    return 25
end

function interrupt_manager.get_interrupt_spells(class_name)
    return INTERRUPT_SPELLS[class_name] or {}
end

function interrupt_manager.should_interrupt(target)
    if not target then return false end
    if not target:is_casting_spell() and not target:is_channelling_spell() then return false end
    if target:is_casting_spell() and not target:is_active_spell_interruptable() then return false end

    -- Don't interrupt if cast finishes in < 200ms (server latency means too late)
    local remaining_ms = 0
    if target:is_casting_spell() then
        local ok_rem, rem = pcall(function() return target:get_spell_cast_time_remaining() end)
        if ok_rem and rem then remaining_ms = rem end
    elseif target:is_channelling_spell() then
        local ok_rem, rem = pcall(function() return target:get_channel_cast_time_remaining() end)
        if ok_rem and rem then remaining_ms = rem end
    end
    if remaining_ms > 0 and remaining_ms < MIN_CAST_TIME_MS then
        return false
    end

    return true
end

function interrupt_manager.get_priority(target)
    return get_interrupt_priority(target)
end

-- Check if a target should be interrupted and return its priority score
-- @return should_interrupt (boolean), priority_score (number)
function interrupt_manager.should_interrupt_target(target)
    if not target then return false, 0 end
    if not interrupt_manager.should_interrupt(target) then return false, 0 end

    -- Get spell priority
    local spell_priority = 25
    local ok_id, spell_id = pcall(function() return target:get_active_spell_id() end)
    if ok_id and spell_id and DANGEROUS_SPELLS[spell_id] then
        spell_priority = DANGEROUS_SPELLS[spell_id]
    end

    -- Healer bonus: +50 if casting a heal on a player
    local healer_bonus = 0
    local ok_cls, cls = pcall(function() return target:get_class() end)
    if ok_cls and cls and HEALER_CLASSES[cls] then
        -- Check if target is casting on a player (healing)
        local ok_tgt, cast_target = pcall(function() return target:get_target() end)
        if ok_tgt and cast_target and cast_target:is_valid() then
            local ok_tcls, tcls = pcall(function() return cast_target:get_class() end)
            if ok_tcls and tcls then
                -- Healer casting on any player gets bonus
                healer_bonus = 50
            end
        end
    end

    local total_priority = spell_priority + healer_bonus
    return true, total_priority
end

-- Find the best interrupt target from all nearby enemies
-- @param me player unit
-- @return best target (unit) or nil
function interrupt_manager.get_best_interrupt_target(me)
    if not me then return nil end

    -- Get enemies in interrupt range (~10 yards for most classes)
    local ok_units, enemies = pcall(function()
        return core.object_manager.get_units_in_range(me, 10)
    end)
    if not ok_units or not enemies then return nil end

    local best_target = nil
    local best_priority = 0

    for _, unit in ipairs(enemies) do
        if unit and unit:is_valid() and not unit:is_dead() and me:can_attack(unit) then
            local should_int, priority = interrupt_manager.should_interrupt_target(unit)
            if should_int and priority > best_priority then
                best_priority = priority
                best_target = unit
            end
        end
    end

    return best_target
end

local _last_cast = {}
local CC_RECAST_DELAY = {
    [33786] = 20.0,
    [8983]  = 10.0,
    [5211]  = 10.0,
    [1822]  = 10.0,
    [20066] = 10.0,
    [19647] = 20.0,
}
local DEFAULT_CC_RECAST_DELAY = 2.0

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
