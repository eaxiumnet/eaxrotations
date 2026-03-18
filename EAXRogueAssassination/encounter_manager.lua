-- encounter_manager.lua
-- TBC dungeon and raid encounter awareness for all EAX specs.
-- Uses only documented Sylvanas API:
--   core.get_instance_name() — returns current instance/zone name
--   unit:get_name()          — boss name matching
--   unit:is_boss()           — boss classification check
--   unit:get_classification() — 1=elite, 2=rareelite, 3=worldboss
--
-- Returns an encounter_policy table that rotation modules use to gate
-- cooldowns, adjust behaviour, and set interrupt priority.
--
-- Usage:
--   local em  = require("encounter_manager")
--   local enc = em.get_policy(me)
--   if enc.hold_cooldowns then return false end  -- skip burst CDs
--   if enc.interrupt_priority then ... end       -- boss is interruptable
--
-- v1.0.0

local encounter_manager = {}

-- ─── Default policy ───────────────────────────────────────────────────────────
-- All fields default to "normal PvE" values.

local DEFAULT_POLICY = {
    encounter_id        = "default",
    is_boss             = false,
    -- Cooldown gating
    hold_cooldowns      = false,   -- save CDs for pull/burst window
    burn_phase          = false,   -- active burn (use all CDs now)
    -- Rotation modifiers
    avoid_close_range   = false,   -- stay 8+ yds back (knockback bosses)
    min_range           = nil,     -- override minimum cast range (yds)
    aoe_safe            = true,    -- safe to use AoE
    -- Interrupt / dispel
    interrupt_priority  = false,   -- target has high-priority interruptable cast
    force_decurse       = false,   -- always remove curses immediately
    force_dispel        = false,   -- always dispel magic/disease immediately
    -- Pet / utility
    pet_follow          = false,   -- pet should follow (avoid boss AoE)
    disable_pet_attack  = false,   -- don't send pet in (e.g. MC risk)
    -- Healer hints (for healing specs)
    tank_damage_heavy   = false,   -- tank is taking heavy sustained damage
    raid_aoe_heavy      = false,   -- raid-wide AoE incoming
    healer_mana_call    = false,   -- innervate / mana tide urgently needed
}

local function copy_default()
    local p = {}
    for k, v in pairs(DEFAULT_POLICY) do p[k] = v end
    return p
end

-- ─── Boss database ────────────────────────────────────────────────────────────
-- Keyed by lowercase boss name (or substring).
-- Each entry overrides fields from DEFAULT_POLICY.
--
-- Sources:
--   OpenDruid2/encounters/catalog.lua  — policy tags per boss
--   OpenMage2/encounters/raid_pack_tbc_v2.lua — range/CD overrides
--   OpenPriest/data/bosses/tbc.lua — special ability IDs

local BOSS_DB = {
    -- ═══════════════════════════════════════════════════════════════
    -- HELLFIRE CITADEL
    -- ═══════════════════════════════════════════════════════════════
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

    -- ═══════════════════════════════════════════════════════════════
    -- COILFANG RESERVOIR
    -- ═══════════════════════════════════════════════════════════════
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

    -- ═══════════════════════════════════════════════════════════════
    -- AUCHINDOUN
    -- ═══════════════════════════════════════════════════════════════
    ["pandemonius"]            = { is_boss=true, avoid_close_range=true },
    ["tavarok"]                = { is_boss=true, raid_aoe_heavy=true },
    ["nexus-prince shaffar"]   = { is_boss=true, aoe_safe=false },
    ["shirrak the dead watcher"]={ is_boss=true, interrupt_priority=false }, -- inhibits casting
    ["exarch maladaar"]        = { is_boss=true },
    ["darkweaver syth"]        = { is_boss=true },
    ["anzu"]                   = { is_boss=true },
    ["talon king ikiss"]       = { is_boss=true, raid_aoe_heavy=true, hold_cooldowns=true },
    ["ambassador hellmaw"]     = { is_boss=true },
    ["blackheart the inciter"] = { is_boss=true, disable_pet_attack=true, aoe_safe=false },
    ["grandmaster vorpil"]     = { is_boss=true, avoid_close_range=true, aoe_safe=false },
    ["murmur"]                 = { is_boss=true, raid_aoe_heavy=true, hold_cooldowns=true,
                                    avoid_close_range=true, min_range=15 },

    -- ═══════════════════════════════════════════════════════════════
    -- CAVERNS OF TIME
    -- ═══════════════════════════════════════════════════════════════
    ["lieutenant drake"]       = { is_boss=true },
    ["captain skarloc"]        = { is_boss=true },
    ["epoch hunter"]           = { is_boss=true },
    ["chrono lord deja"]       = { is_boss=true },
    ["temporus"]               = { is_boss=true, tank_damage_heavy=true },
    ["aeonus"]                 = { is_boss=true },

    -- ═══════════════════════════════════════════════════════════════
    -- TEMPEST KEEP DUNGEONS
    -- ═══════════════════════════════════════════════════════════════
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
    ["zereketh the unbound"]   = { is_boss=true, raid_aoe_heavy=true },
    ["dalliah the doomsayer"]  = { is_boss=true, avoid_close_range=true },
    ["wrath-scryer soccothrates"]={ is_boss=true, avoid_close_range=true },
    ["harbinger skyriss"]      = { is_boss=true, disable_pet_attack=true },

    -- ═══════════════════════════════════════════════════════════════
    -- MAGISTERS' TERRACE
    -- ═══════════════════════════════════════════════════════════════
    ["selin fireheart"]        = { is_boss=true, burn_phase=true },
    ["vexallus"]               = { is_boss=true, healer_mana_call=true },
    ["priestess delrissa"]     = { is_boss=true, aoe_safe=false, disable_pet_attack=true },
    ["kael'thas sunstrider"]   = { is_boss=true, hold_cooldowns=true, raid_aoe_heavy=true,
                                    avoid_close_range=true },

    -- ═══════════════════════════════════════════════════════════════
    -- KARAZHAN
    -- ═══════════════════════════════════════════════════════════════
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

    -- ═══════════════════════════════════════════════════════════════
    -- GRUUL'S LAIR / MAGTHERIDON
    -- ═══════════════════════════════════════════════════════════════
    ["high king maulgar"]      = { is_boss=true, force_decurse=true, aoe_safe=false },
    ["gruul the dragonkiller"] = { is_boss=true, hold_cooldowns=true, avoid_close_range=true,
                                    min_range=18 },
    ["magtheridon"]            = { is_boss=true, raid_aoe_heavy=true, interrupt_priority=true },

    -- ═══════════════════════════════════════════════════════════════
    -- SERPENTSHRINE CAVERN
    -- ═══════════════════════════════════════════════════════════════
    ["hydross the unstable"]   = { is_boss=true, force_decurse=true, aoe_safe=false },
    ["the lurker below"]       = { is_boss=true, avoid_close_range=true },
    ["leotheras the blind"]    = { is_boss=true, raid_aoe_heavy=true, disable_pet_attack=true },
    ["fathom-lord karathress"] = { is_boss=true, aoe_safe=false },
    ["morogrim tidewalker"]    = { is_boss=true, raid_aoe_heavy=true },
    ["lady vashj"]             = { is_boss=true, hold_cooldowns=true, disable_pet_attack=true,
                                    raid_aoe_heavy=true },

    -- ═══════════════════════════════════════════════════════════════
    -- THE EYE (TEMPEST KEEP RAID)
    -- ═══════════════════════════════════════════════════════════════
    ["al'ar"]                  = { is_boss=true, avoid_close_range=true, hold_cooldowns=true },
    ["void reaver"]            = { is_boss=true, avoid_close_range=true, min_range=20,
                                    hold_cooldowns=true },
    ["high astromancer solarian"]={ is_boss=true, raid_aoe_heavy=true, hold_cooldowns=true },
    ["kael'thas sunstrider"]   = { is_boss=true, hold_cooldowns=true, aoe_safe=false,
                                    avoid_close_range=true, disable_pet_attack=true },

    -- ═══════════════════════════════════════════════════════════════
    -- HYJAL SUMMIT
    -- ═══════════════════════════════════════════════════════════════
    ["rage winterchill"]       = { is_boss=true, force_decurse=true, raid_aoe_heavy=true },
    ["anetheron"]              = { is_boss=true, raid_aoe_heavy=true },
    ["kaz'rogal"]              = { is_boss=true, healer_mana_call=true },
    ["azgalor"]                = { is_boss=true, raid_aoe_heavy=true, hold_cooldowns=true },
    ["archimonde"]             = { is_boss=true, hold_cooldowns=true, avoid_close_range=true,
                                    pet_follow=true, disable_pet_attack=true,
                                    raid_aoe_heavy=true },

    -- ═══════════════════════════════════════════════════════════════
    -- BLACK TEMPLE
    -- ═══════════════════════════════════════════════════════════════
    ["high warlord naj'entus"] = { is_boss=true, tank_damage_heavy=true },
    ["supremus"]               = { is_boss=true, avoid_close_range=true },
    ["shade of akama"]         = { is_boss=true, aoe_safe=true },
    ["teron gorefiend"]        = { is_boss=true, hold_cooldowns=true },
    ["gurtogg bloodboil"]      = { is_boss=true, tank_damage_heavy=true, hold_cooldowns=true },
    ["reliquary of souls"]     = { is_boss=true, interrupt_priority=true, hold_cooldowns=true,
                                    healer_mana_call=true },
    ["mother shahraz"]         = { is_boss=true, tank_damage_heavy=true, hold_cooldowns=true },
    ["illidari council"]       = { is_boss=true, interrupt_priority=true, aoe_safe=false,
                                    disable_pet_attack=true },
    ["illidan stormrage"]      = { is_boss=true, hold_cooldowns=true, avoid_close_range=true,
                                    pet_follow=true, raid_aoe_heavy=true },

    -- ═══════════════════════════════════════════════════════════════
    -- ZUL'AMAN
    -- ═══════════════════════════════════════════════════════════════
    ["nalorakk"]               = { is_boss=true, tank_damage_heavy=true },
    ["akil'zon"]               = { is_boss=true, raid_aoe_heavy=true, aoe_safe=false },
    ["jan'alai"]               = { is_boss=true, raid_aoe_heavy=true, aoe_safe=false },
    ["halazzi"]                = { is_boss=true, force_dispel=true },
    ["hex lord malacrass"]     = { is_boss=true, force_decurse=true, interrupt_priority=true },
    ["zul'jin"]                = { is_boss=true, hold_cooldowns=true, avoid_close_range=true,
                                    raid_aoe_heavy=true },

    -- ═══════════════════════════════════════════════════════════════
    -- SUNWELL PLATEAU
    -- ═══════════════════════════════════════════════════════════════
    ["kalecgos"]               = { is_boss=true, force_decurse=true, hold_cooldowns=true },
    ["brutallus"]              = { is_boss=true, tank_damage_heavy=true, burn_phase=true,
                                    hold_cooldowns=false },
    ["felmyst"]                = { is_boss=true, raid_aoe_heavy=true, avoid_close_range=true,
                                    force_dispel=true },
    ["eredar twins"]           = { is_boss=true, raid_aoe_heavy=true, force_decurse=true },
    ["m'uru"]                  = { is_boss=true, raid_aoe_heavy=true, healer_mana_call=true,
                                    hold_cooldowns=true, aoe_safe=false },
    ["kil'jaeden"]             = { is_boss=true, hold_cooldowns=true, avoid_close_range=true,
                                    pet_follow=true, disable_pet_attack=true,
                                    raid_aoe_heavy=true, healer_mana_call=true },
}

-- ─── Internal state ───────────────────────────────────────────────────────────

local cache_policy  = nil
local cache_time    = 0
local CACHE_TTL     = 2.0   -- seconds between re-evaluations

-- ─── Matching ─────────────────────────────────────────────────────────────────

local function normalize(s)
    return s and string.lower(tostring(s)) or ""
end

local function match_boss(name)
    local low = normalize(name)
    -- Exact match first
    if BOSS_DB[low] then return BOSS_DB[low] end
    -- Substring match for bosses with phase suffixes / variants
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
            -- Only check boss/elite units
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

-- ─── Public API ───────────────────────────────────────────────────────────────

--- Returns the current encounter policy. Cached for CACHE_TTL seconds.
--- @param me game_object  the local player
--- @return table          encounter_policy
function encounter_manager.get_policy(me)
    local now = core.time()
    if cache_policy and (now - cache_time) < CACHE_TTL then
        return cache_policy
    end

    local policy = copy_default()
    cache_time = now

    -- Check current target first (fastest path)
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

    -- Scan all objects for a boss
    local entry, name = scan_enemies_for_boss()
    if entry then
        for k, v in pairs(entry) do policy[k] = v end
        policy.encounter_id = normalize(name or "unknown")
    end

    cache_policy = policy
    return policy
end

--- Force cache invalidation (call on zone change / combat end)
function encounter_manager.reset()
    cache_policy = nil
    cache_time   = 0
end

--- Returns true if we are currently in a named TBC raid instance
function encounter_manager.is_in_raid()
    local ok, inst = pcall(function() return core.get_instance_type() end)
    if ok and inst then
        local low = string.lower(tostring(inst))
        return low == "raid" or low == "pvpzone"
    end
    return false
end

--- Returns true if we are in a dungeon or raid instance
function encounter_manager.is_instanced()
    local ok, inst = pcall(function() return core.get_instance_type() end)
    if ok and inst and tostring(inst) ~= "" and string.lower(tostring(inst)) ~= "none" then
        return true
    end
    return false
end

return encounter_manager
