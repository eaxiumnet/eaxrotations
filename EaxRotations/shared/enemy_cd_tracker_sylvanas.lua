-- ============================================================================
-- Shared Helper: Enemy Cooldown Tracker
-- ============================================================================
-- Readability notes:
--   What: tracks enemy major cooldowns from observed spell casts for TBC Arena.
--   When: PvP situations where knowing enemy defensive/offensive availability matters.
--   Why: enables smarter burst windows, CC chains, and defensive reactions.
--   Safety: uses spell cast callbacks, GUID validation, expiry cleanup.

local M = {}
local _G = _G
local NS = _G.EaxRotations

local EMPTY = {}

local function now()
    return NS and NS.time_now and NS.time_now() or 0
end

-- TBC Major Cooldown Database (spell_id = cooldown_seconds)
-- Only TBC spells (patch 2.4.3)
local COOLDOWNS = {
    -- Mage
    [45438] = 300,    -- Ice Block (5 min)
    [27619] = 300,    -- Ice Block (Rank 2)
    [11958] = 480,    -- Cold Snap (8 min)
    [2139] = 24,      -- Counterspell (24s, but tracked for recent use)
    [12472] = 180,    -- Icy Veins (3 min)
    [12042] = 180,    -- Arcane Power (3 min)
    [12043] = 180,    -- Presence of Mind (3 min)
    [31687] = 180,    -- Summon Water Elemental
    
    -- Paladin
    [642] = 300,      -- Divine Shield (5 min)
    [1020] = 300,     -- Divine Shield (Rank 2)
    [1022] = 300,     -- Blessing of Protection (5 min)
    [5599] = 300,     -- Blessing of Protection (Rank 2)
    [10278] = 300,    -- Blessing of Protection (Rank 3)
    [19752] = 3600,   -- Divine Intervention (1 hour)
    [20066] = 60,     -- Repentance (1 min)
    [31884] = 120,    -- Avenging Wrath (2 min)
    
    -- Warrior
    [871] = 300,      -- Shield Wall (5 min)
    [12975] = 480,    -- Last Stand (8 min)
    [1719] = 300,     -- Recklessness (5 min)
    [23920] = 10,     -- Spell Reflection (10s)
    [12328] = 180,    -- Sweeping Strikes (3 min)
    [12292] = 30,     -- Death Wish (30s)
    [18499] = 30,     -- Berserker Rage (30s)
    [2687] = 60,      -- Bloodrage (1 min)
    [25275] = 30,     -- Intercept (30s)
    [20617] = 30,     -- Intercept (Rank 1)
    [20616] = 30,     -- Intercept (Rank 2)
    [25272] = 30,     -- Intercept (Rank 3)
    [25274] = 30,     -- Intercept (Rank 4)
    [25275] = 30,     -- Intercept (Rank 5)
    
    -- Rogue
    [26669] = 300,    -- Evasion (5 min) - TBC rank
    [5277] = 300,     -- Evasion (Rank 1)
    [31224] = 60,     -- Cloak of Shadows (1 min)
    [1856] = 300,     -- Vanish (5 min) - Rank 1
    [1857] = 300,     -- Vanish (Rank 2)
    [26889] = 300,    -- Vanish (Rank 3)
    [14185] = 600,    -- Preparation (10 min)
    [13750] = 180,    -- Adrenaline Rush (3 min)
    [13877] = 120,    -- Blade Flurry (2 min)
    [8643] = 20,      -- Kidney Shot cooldown for tracking
    [2094] = 180,     -- Blind (3 min)
    [2983] = 60,      -- Sprint (1 min)
    
    -- Hunter
    [19574] = 120,    -- Bestial Wrath (2 min)
    [19263] = 300,    -- Deterrence (5 min) - TBC rank
    [23989] = 300,    -- Readiness (5 min)
    [3045] = 300,     -- Rapid Fire (5 min)
    [19386] = 60,     -- Wyvern Sting (1 min)
    [34477] = 120,    -- Misdirection (2 min)
    [5384] = 30,      -- Feign Death (30s)
    
    -- Warlock
    [6789] = 120,     -- Death Coil (2 min)
    [19647] = 24,     -- Spell Lock (24s - Felhunter)
    [19244] = 24,     -- Spell Lock (Rank 1)
    [19245] = 24,     -- Spell Lock (Rank 2)
    [19644] = 24,     -- Spell Lock (Rank 3)
    [19645] = 24,     -- Spell Lock (Rank 4)
    [19646] = 24,     -- Spell Lock (Rank 5)
    [19647] = 24,     -- Spell Lock (Rank 6)
    [30414] = 20,     -- Shadowfury (20s)
    [30283] = 20,     -- Shadowfury (Rank 1)
    [30413] = 20,     -- Shadowfury (Rank 2)
    [30414] = 20,     -- Shadowfury (Rank 3)
    [18288] = 180,    -- Amplify Curse (3 min)
    [18708] = 900,    -- Feldom (15 min)
    [1122] = 1200,    -- Inferno (20 min)
    
    -- Priest
    [33206] = 120,    -- Pain Suppression (2 min)
    [10060] = 180,    -- Power Infusion (3 min)
    [8122] = 23,      -- Psychic Scream (23s)
    [8124] = 23,      -- Psychic Scream (Rank 2)
    [10888] = 23,     -- Psychic Scream (Rank 3)
    [10890] = 23,     -- Psychic Scream (Rank 4)
    [15487] = 45,     -- Silence (45s)
    [6346] = 180,     -- Fear Ward (3 min)
    [34433] = 300,    -- Shadowfiend (5 min)
    [32379] = 12,     -- Shadow Word: Death (12s)
    [32996] = 12,     -- Shadow Word: Death (Rank 2)
    
    -- Druid
    [22812] = 60,     -- Barkskin (1 min)
    [17116] = 180,    -- Nature's Swiftness (3 min) - Druid
    [16188] = 180,    -- Nature's Swiftness (3 min) - Shaman (also in table)
    [29166] = 360,    -- Innervate (6 min)
    [33831] = 180,    -- Force of Nature (3 min) - Treants
    [16979] = 15,     -- Feral Charge (15s)
    [18562] = 15,     -- Swiftmend (TBC Rank 1)
    [26980] = 15,     -- Swiftmend (TBC Rank 2)
    
    -- Shaman
    [2825] = 600,     -- Bloodlust (10 min)
    [32182] = 600,    -- Heroism (10 min) - Alliance equivalent
    [30823] = 120,    -- Shamanistic Rage (2 min)
    [16166] = 180,    -- Elemental Mastery (3 min)
    [17364] = 10,     -- Stormstrike (10s)
    [25454] = 10,     -- Stormstrike (Rank 2-5)
    [25500] = 10,     -- Stormstrike (Rank 3)
    [25501] = 10,     -- Stormstrike (Rank 4)
    [25502] = 10,     -- Stormstrike (Rank 5)
    [2062] = 600,     -- Earth Elemental Totem (10 min)
    [2894] = 600,     -- Fire Elemental Totem (10 min)
}

-- Categorized lists for quick checking
local defensive_cooldowns = {
    -- Major defensive cooldowns
    [45438] = true, -- Ice Block
    [642] = true,   -- Divine Shield
    [871] = true,   -- Shield Wall
    [12975] = true, -- Last Stand
    [26669] = true, -- Evasion
    [31224] = true, -- Cloak of Shadows
    [1856] = true,  -- Vanish
    [19263] = true, -- Deterrence
    [22812] = true, -- Barkskin
    [33206] = true, -- Pain Suppression
}

local offensive_cooldowns = {
    -- Major offensive cooldowns
    [12472] = true, -- Icy Veins
    [12042] = true, -- Arcane Power
    [1719] = true,  -- Recklessness
    [12292] = true, -- Death Wish
    [13750] = true, -- Adrenaline Rush
    [13877] = true, -- Blade Flurry
    [19574] = true, -- Bestial Wrath
    [3045] = true,  -- Rapid Fire
    [2825] = true,  -- Bloodlust
    [32182] = true, -- Heroism
    [30823] = true, -- Shamanistic Rage
    [16166] = true, -- Elemental Mastery
    [10060] = true, -- Power Infusion
    [31884] = true, -- Avenging Wrath
}

-- State storage: {[guid] = {[spell_id] = {used_at = T, ready_at = T, duration = N}}}
local cd_state = {}

local EXPIRY_BUFFER = 60  -- Keep entries 60s past ready time for history

-- Get unit GUID safely
local function get_unit_guid(unit)
    if not unit then return nil end
    if type(unit) == "string" then return unit end
    local ok, guid = pcall(function() return unit:get_guid() end)
    if ok and type(guid) == "string" then return guid end
    return nil
end

-- Record a cooldown usage
-- Called from spell cast callback when we observe an enemy using a cooldown
function M.record_cast(caster, spell_id)
    if not spell_id then return end
    
    local cooldown = COOLDOWNS[spell_id]
    if not cooldown then return end  -- Not a tracked cooldown
    
    local guid = get_unit_guid(caster)
    if not guid then return end
    
    local t = now()
    local entry = cd_state[guid]
    if not entry then
        entry = {}
        cd_state[guid] = entry
    end
    
    entry[spell_id] = {
        used_at = t,
        ready_at = t + cooldown,
        duration = cooldown,
    }
end

-- Check if a specific cooldown is ready for an enemy
-- Returns: true (ready), false (on cooldown), nil (unknown - never seen)
function M.is_enemy_cd_ready(unit_or_guid, spell_id)
    if not spell_id then return nil end
    
    local guid = get_unit_guid(unit_or_guid)
    if not guid then return nil end
    
    local entry = cd_state[guid]
    if not entry then return nil end  -- Never seen this enemy
    
    local cd_entry = entry[spell_id]
    if not cd_entry then return nil end  -- Never seen this spell from this enemy
    
    local t = now()
    return t >= cd_entry.ready_at
end

-- Get seconds remaining on a cooldown
-- Returns: 0 (ready), positive number (seconds), nil (unknown)
function M.get_cd_remaining(unit_or_guid, spell_id)
    if not spell_id then return nil end
    
    local status = M.is_enemy_cd_ready(unit_or_guid, spell_id)
    if status == nil then return nil end
    if status == true then return 0 end
    
    -- On cooldown, calculate remaining
    local guid = get_unit_guid(unit_or_guid)
    if not guid then return nil end
    
    local entry = cd_state[guid]
    if not entry then return nil end
    
    local cd_entry = entry[spell_id]
    if not cd_entry then return nil end
    
    local t = now()
    return math.max(0, cd_entry.ready_at - t)
end

-- Check if enemy has any defensive cooldown available
-- Returns: true (has defensive ready), false (none ready or unknown)
function M.has_defensive_available(unit)
    local guid = get_unit_guid(unit)
    if not guid then return false end
    
    local entry = cd_state[guid]
    if not entry then 
        -- Unknown enemy - assume they might have defensives
        return false  
    end
    
    -- Check if any defensive is ready
    for spell_id, _ in pairs(defensive_cooldowns) do
        local ready = M.is_enemy_cd_ready(guid, spell_id)
        if ready == true then
            return true
        end
    end
    
    return false
end

-- Check if enemy used a major offensive recently (last 30s)
-- Useful for deciding when to use defensive cooldowns
function M.has_major_offensive_active_or_recent(unit, recent_seconds)
    recent_seconds = recent_seconds or 30
    
    local guid = get_unit_guid(unit)
    if not guid then return false end
    
    local entry = cd_state[guid]
    if not entry then return false end
    
    local t = now()
    
    -- Check if any offensive was used recently
    for spell_id, _ in pairs(offensive_cooldowns) do
        local cd_entry = entry[spell_id]
        if cd_entry then
            local time_since_use = t - cd_entry.used_at
            if time_since_use >= 0 and time_since_use < recent_seconds then
                return true
            end
        end
    end
    
    return false
end

-- Get a summary of enemy cooldowns for display
-- Returns table: {[spell_id] = {used_at = T, ready_at = T, remaining = N, ready = bool}}
function M.get_enemy_cds(unit_or_guid)
    local guid = get_unit_guid(unit_or_guid)
    if not guid then return EMPTY end
    
    local entry = cd_state[guid]
    if not entry then return EMPTY end
    
    local t = now()
    local result = {}
    
    for spell_id, cd_entry in pairs(entry) do
        local remaining = math.max(0, cd_entry.ready_at - t)
        result[spell_id] = {
            used_at = cd_entry.used_at,
            ready_at = cd_entry.ready_at,
            remaining = remaining,
            ready = remaining == 0,
        }
    end
    
    return result
end

-- Clean up old entries
function M.cleanup()
    local t = now()
    for guid, entry in pairs(cd_state) do
        local has_recent = false
        for spell_id, cd_entry in pairs(entry) do
            -- Remove if expired by buffer
            if t > (cd_entry.ready_at + EXPIRY_BUFFER) then
                entry[spell_id] = nil
            else
                has_recent = true
            end
        end
        if not has_recent then
            cd_state[guid] = nil
        end
    end
end

-- Initialize: register spell cast callback
function M.init()
    if not NS then return end
    
    -- Register on spell cast callback
    -- Signature: function(spell_id, target, data)
    if NS.register_on_spell_cast then
        NS.register_on_spell_cast(function(spell_id, target, data)
            -- data contains caster info
            if data and data.caster and spell_id then
                M.record_cast(data.caster, spell_id)
            end
        end)
    end
    
    -- Periodic cleanup
    if NS.register_on_update_callback then
        local last_cleanup = 0
        NS.register_on_update_callback(function()
            local t = now()
            if t - last_cleanup > 120 then  -- Cleanup every 2 minutes
                M.cleanup()
                last_cleanup = t
            end
        end)
    end
end

if NS then
    NS.EnemyCDTracker = M
    M.init()
end

return M
