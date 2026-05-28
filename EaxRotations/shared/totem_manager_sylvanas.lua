-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "shared/totem_manager_sylvanas.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- ============================================================================
-- Shared Helper: Totem Manager (Shaman)
-- Per-school totem item reagent checking.
-- ============================================================================

local NS = _G.EaxRotations
local M = {}
local EMPTY = {}

---@type table<string, integer> Item IDs per totem school (from Vanilla/TBC classic).
local TOTEM_ITEMS = {
    earth = 5175,
    fire  = 5176,
    water = 5177,
    air   = 5178,
}

---@type table<string, string> Maps each TOTEM_SPELLS key to its school.
local TOTEM_SCHOOLS = {
    searing      = "fire",
    magma        = "fire",
    fire_nova    = "fire",
    stoneclaw    = "earth",
    strength     = "earth",
    windfury     = "air",
    grace_of_air = "air",
    trembling    = "earth",
    mana_spring  = "water",
    healing_stream = "water",
    windwall     = "air",
    sentry       = "air",
    fire_resist  = "fire",
    frost_resist = "water",
    nature_resist = "air",
}

-- TBC totem spell IDs (ranked newest-to-oldest)
local TOTEM_SPELLS = {
    searing      = { 25533, 20602, 20601, 10499, 10498, 3599 },
    magma        = { 25552, 20607, 20606, 10500, 10500, 8190 },
    fire_nova    = { 25547, 11315, 11314, 8499, 8498, 1535 },
    stoneclaw    = { 25526, 20614, 20613, 10502, 5730, 5730, 2484 },
    strength     = { 25528, 20610, 20609, 10504, 8155, 8075, 8071 },
    windfury     = { 25587, 20622, 20621, 10511, 8836, 8512 },
    grace_of_air = { 25359, 10627, 8835 },
    trembling    = { 25564, 11322, 11321, 11320, 11319, 11318, 11317, 11316, 8145, 8144, 8143 },
    mana_spring  = { 25570, 10497, 10496, 10495, 5675 },
    healing_stream = { 25569, 10507, 10506, 10505, 6379, 6378, 6377, 5394 },
    windwall     = { 25577, 10514, 10513, 10512, 9592, 15112 },
    sentry       = { 6495, 6494, 6493, 6492, 6491, 6490, 6489 },
    fire_resist  = { 25563, 10524, 10523, 10522, 8185, 8184, 8183, 8182 },
    frost_resist = { 25560, 10519, 10518, 10517, 8181, 8180, 8179, 8178 },
    nature_resist = { 25574, 10531, 10530, 10529, 10528, 10527, 10526, 10525 },
}

local _cache = {
    last_scan    = 0,
    scan_interval = 2.0,
    bag_items    = {},
    active_totems = {},
}

--- Scans bags for totem items (throttled to 2 s).
local function _scan_bags()
    local now = NS.time_now and NS.time_now() or 0
    if now - _cache.last_scan < _cache.scan_interval then return end
    _cache.last_scan = now
    local inventory = core and core.inventory
    if not inventory or not inventory.get_bag_items then return end
    local ok, items = pcall(inventory.get_bag_items)
    if not ok or type(items) ~= "table" then return end
    _cache.bag_items = {}
    for i = 1, #items do
        local item = items[i]
        local id = item and item.item_id or item
        if id then _cache.bag_items[id] = true end
    end
end

--- Returns true if the player has the totem item for the given school.
---@param school string "earth"|"fire"|"water"|"air"
---@return boolean
function M.has_totem_item(school)
    _scan_bags()
    local item_id = TOTEM_ITEMS[school]
    if not item_id then return false end
    return _cache.bag_items[item_id] == true
end

--- Returns true if the player has ANY totem item (fast-fail gate).
---@return boolean
function M.has_any_totem_item()
    _scan_bags()
    for _, id in pairs(TOTEM_ITEMS) do
        if _cache.bag_items[id] then return true end
    end
    return false
end

--- Returns the school for a given totem key.
---@param key string Key from TOTEM_SPELLS (e.g. "windfury", "searing")
---@return string|nil school "earth"|"fire"|"water"|"air" or nil
function M.totem_school(key)
    return TOTEM_SCHOOLS[key]
end

--- Attempts to place a totem by trying each spell ID in rank order.
--- Only tries if the matching school's totem item is in bags.
---@param spell_ids integer[] List of spell IDs (newest-to-oldest).
---@param school string "earth"|"fire"|"water"|"air"  School for reagent check.
---@return boolean success True if a totem was placed.
function M.place_totem(spell_ids, school)
    if type(spell_ids) ~= "table" then return false end
    -- Reagent guard: check per-school totem item
    if school then
        if not M.has_totem_item(school) then return false end
    elseif not M.has_any_totem_item() then
        return false
    end
    local me = NS.GetPlayer and NS.GetPlayer()
    if not me then return false end
    for i = 1, #spell_ids do
        local id = spell_ids[i]
        if NS.spell_ready({ id = id }, me, { skip_range = true }) then
            return NS.try_cast({ id = id }, me, "[TOTEM] place", { skip_range = true })
        end
    end
    return false
end

-- ============================================================================
-- Convenience placers (each knows its school)
-- ============================================================================

function M.place_stoneclaw()
    return M.place_totem(TOTEM_SPELLS.stoneclaw, "earth")
end
function M.place_strength()
    return M.place_totem(TOTEM_SPELLS.strength, "earth")
end
function M.place_windfury()
    return M.place_totem(TOTEM_SPELLS.windfury, "air")
end
function M.place_grace_of_air()
    return M.place_totem(TOTEM_SPELLS.grace_of_air, "air")
end
function M.place_mana_spring()
    return M.place_totem(TOTEM_SPELLS.mana_spring, "water")
end
function M.place_healing_stream()
    return M.place_totem(TOTEM_SPELLS.healing_stream, "water")
end
function M.place_searing()
    return M.place_totem(TOTEM_SPELLS.searing, "fire")
end
function M.place_magma()
    return M.place_totem(TOTEM_SPELLS.magma, "fire")
end

--- Combat-update dispatcher. Places the first available totem for the playstyle.
--- Each totem placement independently checks its school's reagent.
function M.on_combat_update(context, playstyle)
    if not context or not context.in_combat then return false end

    local debug = NS.get_setting and NS.get_setting("debug_system", false) or false

    if playstyle == "elemental" then
        if M.place_searing() then if debug then NS.log("[TOTEM] Searing Totem") end; return true end
        if M.place_mana_spring() then if debug then NS.log("[TOTEM] Mana Spring") end; return true end
        if M.place_windfury() then if debug then NS.log("[TOTEM] Windfury") end; return true end
    elseif playstyle == "enhancement" then
        if M.place_windfury() then if debug then NS.log("[TOTEM] Windfury") end; return true end
        if M.place_strength() then if debug then NS.log("[TOTEM] Strength of Earth") end; return true end
        if M.place_mana_spring() then if debug then NS.log("[TOTEM] Mana Spring") end; return true end
    elseif playstyle == "restoration" then
        if M.place_mana_spring() then if debug then NS.log("[TOTEM] Mana Spring") end; return true end
        if M.place_healing_stream() then if debug then NS.log("[TOTEM] Healing Stream") end; return true end
        if M.place_stoneclaw() then if debug then NS.log("[TOTEM] Stoneclaw") end; return true end
    else
        if M.place_windfury() then if debug then NS.log("[TOTEM] Windfury") end; return true end
        if M.place_strength() then if debug then NS.log("[TOTEM] Strength of Earth") end; return true end
    end
    return false
end

return M
