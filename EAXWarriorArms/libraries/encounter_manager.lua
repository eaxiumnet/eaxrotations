-- encounter_manager.lua
-- ../eax_shared/encounter_manager.lua
-- TBC dungeon and raid encounter awareness for all Eax specs.

local encounter_manager = {}

local DEFAULT_POLICY = {
    encounter_id        = "default",
    is_boss             = false,
    hold_cooldowns      = false,
    burn_phase          = false,
    avoid_close_range   = false,
    min_range           = nil,
    aoe_safe            = true,
    interrupt_priority  = false,
    force_decurse       = false,
    force_dispel        = false,
    pet_follow          = false,
    disable_pet_attack  = false,
    tank_damage_heavy   = false,
    raid_aoe_heavy      = false,
    healer_mana_call    = false,
}

local function copy_default()
    local p = {}
    for k, v in pairs(DEFAULT_POLICY) do p[k] = v end
    return p
end

local BOSS_DB = {
    ["watchkeeper gargolmar"]  = { is_boss=true, tank_damage_heavy=true },
    ["omor the unscarred"]     = { is_boss=true, force_decurse=true },
    ["vazruden"]               = { is_boss=true, raid_aoe_heavy=true, avoid_close_range=true },
    ["nazan"]                  = { is_boss=true, raid_aoe_heavy=true, avoid_close_range=true },
    ["the maker"]              = { is_boss=true },
    ["broggok"]                = { is_boss=true, force_dispel=true },
    ["keli'dan the breaker"]   = { is_boss=true, raid_aoe_heavy=true, hold_cooldowns=true },
    ["grand warlock nethekurse"]={ is_boss=true, interrupt_priority=true },
    ["warbringer o'mrogg"]     = { is_boss=true },
    ["warchief kargath bladefist"]={ is_boss=true, avoid_close_range=true },
    ["mennu the betrayer"]     = { is_boss=true, interrupt_priority=true },
    ["rokmar the crackler"]    = { is_boss=true, tank_damage_heavy=true },
    ["quagmirran"]             = { is_boss=true, force_dispel=true },
    ["hungarfen"]              = { is_boss=true, force_dispel=true },
    ["ghaz'an"]                = { is_boss=true, tank_damage_heavy=true },
    ["swamplord musel'ek"]     = { is_boss=true },
    ["the black stalker"]      = { is_boss=true, raid_aoe_heavy=true },
    ["hydromancer thespia"]    = { is_boss=true, avoid_close_range=true },
    ["mekgineer steamrigger"]  = { is_boss=true, aoe_safe=false },
    ["warlord kalithresh"]     = { is_boss=true, tank_damage_heavy=true },
    ["pandemonius"]            = { is_boss=true, avoid_close_range=true },
    ["tavarok"]                = { is_boss=true, raid_aoe_heavy=true },
    ["nexus-prince shaffar"]   = { is_boss=true, aoe_safe=false },
    ["shirrak the dead watcher"]={ is_boss=true, interrupt_priority=false },
    ["exarch maladaar"]        = { is_boss=true },
    ["darkweaver syth"]        = { is_boss=true },
    ["anzu"]                   = { is_boss=true },
    ["talon king ikiss"]       = { is_boss=true, raid_aoe_heavy=true, hold_cooldowns=true },
    ["ambassador hellmaw"]     = { is_boss=true },
    ["blackheart the inciter"] = { is_boss=true, disable_pet_attack=true, aoe_safe=false },
    ["grandmaster vorpil"]     = { is_boss=true, avoid_close_range=true, aoe_safe=false },
    ["murmur"]                 = { is_boss=true, raid_aoe_heavy=true, hold_cooldowns=true,
                                    avoid_close_range=true, min_range=15 },
    ["lieutenant drake"]       = { is_boss=true },
    ["captain skarloc"]        = { is_boss=true },
    ["epoch hunter"]           = { is_boss=true },
    ["chrono lord deja"]       = { is_boss=true },
    ["temporus"]               = { is_boss=true, tank_damage_heavy=true },
    ["aeonus"]                 = { is_boss=true },
    ["gatewatcher gyro-kill"]  = { is_boss=true },
    ["gatewatcher iron-hand"]  = { is_boss=true },
    ["mechano-lord capacitus"] = { is_boss=true, raid_aoe_heavy=true },
    ["nethermancer sepethrea"] = { is_boss=true, raid_aoe_heavy=true, avoid_close_range=true },
    ["pathaleon the calculator"]={ is_boss=true, disable_pet_attack=true },
    ["commander sarannis"]     = { is_boss=true },
    ["high botanist freywinn"] = { is_boss=true, interrupt_priority=true },
    ["thorngrin the tender"]   = { is_boss=true, tank_damage_heavy=true },
    ["laj"]                    = { is_boss=true },
    ["warp splinter"]          = { is_boss=true, raid_aoe_heavy=true },
    ["zereketh the unbound"]  = { is_boss=true, raid_aoe_heavy=true },
    ["dalliah the doomsayer"] = { is_boss=true, avoid_close_range=true },
    ["wrath-scryer soccothrates"]={ is_boss=true, avoid_close_range=true },
    ["harbinger skyriss"]     = { is_boss=true, disable_pet_attack=true },
    ["selin fireheart"]        = { is_boss=true, burn_phase=true },
    ["vexallus"]               = { is_boss=true, healer_mana_call=true },
    ["priestess delrissa"]     = { is_boss=true, aoe_safe=false, disable_pet_attack=true },
    ["kael'thas sunstrider"]   = { is_boss=true, hold_cooldowns=true, raid_aoe_heavy=true,
                                    avoid_close_range=true },
    ["attumen the huntsman"]   = { is_boss=true, force_decurse=true },
    ["moroes"]                 = { is_boss=true },
    ["maiden of virtue"]       = { is_boss=true, interrupt_priority=true, raid_aoe_heavy=true },
    ["the big bad wolf"]       = { is_boss=true, avoid_close_range=false },
    ["romulo"]                 = { is_boss=true },
    ["julianne"]               = { is_boss=true, interrupt_priority=true },
    ["the curator"]            = { is_boss=true, healer_mana_call=true, burn_phase=true },
    ["terestian illhoof"]      = { is_boss=true, raid_aoe_heavy=true },
    ["shade of aran"]          = { is_boss=true, avoid_close_range=true, min_range=18,
                                    aoe_safe=false, hold_cooldowns=false },
    ["netherspite"]            = { is_boss=true, healer_mana_call=true },
    ["prince malchezaar"]      = { is_boss=true, hold_cooldowns=true, raid_aoe_heavy=true },
    ["nightbane"]              = { is_boss=true, raid_aoe_heavy=true },
    ["high king maulgar"]      = { is_boss=true, force_decurse=true, aoe_safe=false },
    ["gruul the dragonkiller"] = { is_boss=true, hold_cooldowns=true, avoid_close_range=true, min_range=18 },
    ["magtheridon"]            = { is_boss=true, raid_aoe_heavy=true, interrupt_priority=true },
    ["hydross the unstable"]   = { is_boss=true, force_decurse=true, aoe_safe=false },
    ["the lurker below"]       = { is_boss=true, avoid_close_range=true },
    ["leotheras the blind"]   = { is_boss=true, raid_aoe_heavy=true, disable_pet_attack=true },
    ["fathom-lord karathress"] = { is_boss=true, aoe_safe=false },
    ["morogrim tidewalker"]    = { is_boss=true, raid_aoe_heavy=true },
    ["lady vashj"]             = { is_boss=true, hold_cooldowns=true, disable_pet_attack=true,
                                    raid_aoe_heavy=true },
    ["al'ar"]                  = { is_boss=true, avoid_close_range=true, hold_cooldowns=true },
    ["void reaver"]            = { is_boss=true, avoid_close_range=true, min_range=20, hold_cooldowns=true },
    ["high astromancer solarian"]={ is_boss=true, raid_aoe_heavy=true, hold_cooldowns=true },
    ["rage winterchill"]       = { is_boss=true, force_decurse=true, raid_aoe_heavy=true },
    ["anetheron"]              = { is_boss=true, raid_aoe_heavy=true },
    ["kaz'rogal"]              = { is_boss=true, healer_mana_call=true },
    ["azgalor"]                = { is_boss=true, raid_aoe_heavy=true, hold_cooldowns=true },
    ["archimonde"]             = { is_boss=true, hold_cooldowns=true, avoid_close_range=true,
                                    pet_follow=true, disable_pet_attack=true, raid_aoe_heavy=true },
    ["high warlord naj'entus"] = { is_boss=true, tank_damage_heavy=true },
    ["supremus"]               = { is_boss=true, avoid_close_range=true },
    ["shade of akama"]         = { is_boss=true, aoe_safe=true },
    ["teron gorefiend"]         = { is_boss=true, hold_cooldowns=true },
    ["gurtogg bloodboil"]       = { is_boss=true, tank_damage_heavy=true, hold_cooldowns=true },
    ["reliquary of souls"]      = { is_boss=true, interrupt_priority=true, hold_cooldowns=true,
                                    healer_mana_call=true },
    ["mother shahraz"]          = { is_boss=true, tank_damage_heavy=true, hold_cooldowns=true },
    ["illidari council"]        = { is_boss=true, interrupt_priority=true, aoe_safe=false,
                                    disable_pet_attack=true },
    ["illidan stormrage"]       = { is_boss=true, hold_cooldowns=true, avoid_close_range=true,
                                    pet_follow=true, raid_aoe_heavy=true },
    ["nalorakk"]               = { is_boss=true, tank_damage_heavy=true },
    ["akil'zon"]               = { is_boss=true, raid_aoe_heavy=true, aoe_safe=false },
    ["jan'alai"]               = { is_boss=true, raid_aoe_heavy=true, aoe_safe=false },
    ["halazzi"]                = { is_boss=true, force_dispel=true },
    ["hex lord malacrass"]     = { is_boss=true, force_decurse=true, interrupt_priority=true },
    ["zul'jin"]                = { is_boss=true, hold_cooldowns=true, avoid_close_range=true,
                                    raid_aoe_heavy=true },
    ["kalecgos"]               = { is_boss=true, force_decurse=true, hold_cooldowns=true },
    ["brutallus"]              = { is_boss=true, tank_damage_heavy=true, burn_phase=true, hold_cooldowns=false },
    ["felmyst"]                = { is_boss=true, raid_aoe_heavy=true, avoid_close_range=true,
                                    force_dispel=true },
    ["eredar twins"]           = { is_boss=true, raid_aoe_heavy=true, force_decurse=true },
    ["m'uru"]                  = { is_boss=true, raid_aoe_heavy=true, healer_mana_call=true,
                                    hold_cooldowns=true, aoe_safe=false },
    ["kil'jaeden"]              = { is_boss=true, hold_cooldowns=true, avoid_close_range=true,
                                    pet_follow=true, disable_pet_attack=true,
                                    raid_aoe_heavy=true, healer_mana_call=true },
}

local cache_policy  = nil
local cache_time    = 0
local CACHE_TTL     = 2.0

local function normalize(s)
    return s and string.lower(tostring(s)) or ""
end

local function match_boss(name)
    local low = normalize(name)
    if BOSS_DB[low] then return BOSS_DB[low] end
    for key, data in pairs(BOSS_DB) do
        if low:find(key, 1, true) or key:find(low, 1, true) then
            return data
        end
    end
    return nil
end

local function scan_enemies_for_boss()
    local objects = core.object_manager.get_all_objects()
    if not objects then return nil, nil end
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() then
            local ok_cls, cls = pcall(function() return obj:get_classification() end)
            local ok_boss, is_b = pcall(function() return obj:is_boss() end)
            if (ok_boss and is_b) or (ok_cls and cls and cls >= 1) then
                local ok_name, name = pcall(function() return obj:get_name() end)
                if ok_name and name then
                    local entry = match_boss(name)
                    if entry then return entry, name end
                end
            end
        end
    end
    return nil, nil
end

function encounter_manager.get_policy(me)
    local now = core.time()
    if cache_policy and (now - cache_time) < CACHE_TTL then
        return cache_policy
    end

    local policy = copy_default()
    cache_time = now

    if me then
        local ok_t, tgt = pcall(function() return me:get_target() end)
        if ok_t and tgt and tgt:is_valid() and not tgt:is_dead() then
            local ok_n, tname = pcall(function() return tgt:get_name() end)
            if ok_n and tname then
                local entry = match_boss(tname)
                if entry then
                    for k, v in pairs(entry) do policy[k] = v end
                    policy.encounter_id = normalize(tname)
                    cache_policy = policy
                    return policy
                end
            end
        end
    end

    local entry, name = scan_enemies_for_boss()
    if entry then
        for k, v in pairs(entry) do policy[k] = v end
        policy.encounter_id = normalize(name or "unknown")
    end

    cache_policy = policy
    return policy
end

function encounter_manager.reset()
    cache_policy = nil
    cache_time   = 0
end

function encounter_manager.is_in_raid()
    local ok, inst = pcall(function() return core.get_instance_type() end)
    if ok and inst then
        local low = string.lower(tostring(inst))
        return low == "raid" or low == "pvpzone"
    end
    return false
end

function encounter_manager.is_instanced()
    local ok, inst = pcall(function() return core.get_instance_type() end)
    if ok and inst and tostring(inst) ~= "" and string.lower(tostring(inst)) ~= "none" then
        return true
    end
    return false
end

-- AoE detection - scan for nearby enemies
-- Returns estimated number of hostile targets within range of player
local function count_nearby_enemies(me, range_yards)
    local count = 0
    local enemies = core.object_manager.get_units_in_range(me, range_yards or 10)
    if enemies then
        for _, unit in ipairs(enemies) do
            if unit and unit:is_valid() and not unit:is_dead() and me:can_attack(unit) then
                count = count + 1
            end
        end
    end
    return count
end

function encounter_manager.enemy_count_in_range(me, range_yards)
    if not me or not me:is_valid() then
        return 0
    end
    return count_nearby_enemies(me, range_yards or 10)
end

function encounter_manager.is_target_behind(me, target)
    if not me or not target or not target:is_valid() then
        return false
    end

    local ok_behind, behind = pcall(function() return me:is_behind(target) end)
    if ok_behind and behind ~= nil then
        return behind
    end

    local ok_behind_unit, behind_unit = pcall(function() return me:is_behind_unit(target) end)
    if ok_behind_unit and behind_unit ~= nil then
        return behind_unit
    end

    return false
end

-- Movement phase encounters - bosses with movement mechanics
local MOVEMENT_PHASE_BOSSES = {
    ["prince malchezaar"]         = { min_range = 20 },
    ["gruul the dragonkiller"]    = { min_range = 18 },
    ["magtheridon"]               = { min_range = 15 },
    ["alar"]                      = { min_range = 20 },
    ["void reaver"]               = { min_range = 20 },
    ["high astromancer solarian"] = { min_range = 20 },
    ["teron gorefiend"]           = { aoe_safe = false },
    ["illidan stormrage"]         = { movement_phase = true },
    ["lady vashj"]                = { movement_phase = true },
    ["brutallus"]                 = { movement_phase = true },
    ["felmyst"]                   = { movement_phase = true },
}

-- Burn phase encounters - hold cooldowns until target reaches threshold HP
local BURN_PHASE_BOSSES = {
    ["gruul the dragonkiller"]    = { burn_until_pct = 0.30 },
    ["magtheridon"]               = { burn_until_pct = 0.35 },
    ["selin fireheart"]           = { burn_until_pct = 0.30 },
    ["the curator"]               = { burn_until_pct = 0.15 },
    ["brutallus"]                 = { burn_until_pct = 0.30 },
    ["m'uru"]                     = { burn_until_pct = 0.20 },
    ["kil'jaeden"]                = { burn_until_pct = 0.30 },
    ["teron gorefiend"]            = { burn_until_pct = 0.30 },
    ["gurtogg bloodboil"]         = { burn_until_pct = 0.25 },
}

-- Check if current encounter is AoE-safe
-- Returns false if too many enemies nearby (prevents face-pull in dungeons)
function encounter_manager.is_aoe_safe(me)
    local policy = encounter_manager.get_policy(me)
    if not policy.aoe_safe then
        local nearby = count_nearby_enemies(me, 10)
        if nearby > 3 then
            return false  -- Multiple targets, AoE encounter
        end
    end
    return true
end

-- Check if current encounter has a movement phase
-- Returns true if player is moving or within minimum range of a movement boss
function encounter_manager.is_movement_phase(me)
    local policy = encounter_manager.get_policy(me)
    if not policy or not policy.encounter_id then return false end
    local entry = MOVEMENT_PHASE_BOSSES[policy.encounter_id]
    if entry and entry.movement_phase then
        -- Check if player is currently moving
        local ok_moving, is_moving = pcall(function() return core.navigation.is_moving() end)
        if ok_moving and is_moving then
            return true
        end
        -- Check if boss is at min_range
        local ok_tgt, tgt = pcall(function() return me:get_target() end)
        if ok_tgt and tgt and tgt:is_valid() then
            local ok_dist, dist = pcall(function() return core.navigation.get_distance_to(tgt) end)
            if ok_dist and dist and entry.min_range and dist < entry.min_range then
                return true
            end
        end
    end
    return false
end

-- Get minimum range for current encounter
function encounter_manager.get_min_range(me)
    local policy = encounter_manager.get_policy(me)
    if policy and policy.min_range then
        return policy.min_range
    end
    return nil
end

-- Check if player should hold cooldowns for burn phase
-- @param me player unit
-- @return boolean (hold_cds), number (burn_until_pct)
function encounter_manager.should_hold_cooldowns(me)
    local policy = encounter_manager.get_policy(me)
    if not policy then return false, 0 end
    if not policy.hold_cooldowns then return false, 0 end

    local target = me:get_target()
    if not target or not target:is_valid() then return false, 0 end

    local ok_hp, hp_pct = pcall(function() return target:get_health_percentage() end)
    if not ok_hp then return false, 0 end
    hp_pct = hp_pct / 100

    local burn_entry = BURN_PHASE_BOSSES[policy.encounter_id]
    local burn_until_pct = burn_entry and burn_entry.burn_until_pct or 0.30

    if hp_pct > burn_until_pct then
        return true, burn_until_pct
    end
    return false, burn_until_pct
end

-- Get burn phase target HP threshold for a given encounter
function encounter_manager.get_burn_threshold(encounter_id)
    local entry = BURN_PHASE_BOSSES[encounter_id]
    return entry and entry.burn_until_pct or 0.30
end

return encounter_manager
