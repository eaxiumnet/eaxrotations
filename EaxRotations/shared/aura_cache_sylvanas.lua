-- aura_cache_sylvanas.lua — Per-frame unit aura snapshot cache for TBC Anniversary (2.5.5).
-- WHAT:  snapshots UnitBuff/UnitDebuff once per tick into O(1) hash tables.
-- WHEN:  one M.snapshot(unit) call per frame, then M.find_buff/M.find_debuff lookups.
-- WHY:   avoids repeated UnitBuff/UnitDebuff calls across strategies within the same tick.
-- SAFETY: no on_update() garbage; self-validating TTL check on every lookup.

local _G = _G
local core = _G.core
local M = {}

M.TTL_MS = 50  -- snapshot valid for 50ms (one frame at 20fps)

-- Cache: unit (game_object) → { ts = core.time(), buffs = { [id] = true }, debuffs = { [id] = true } }
-- Using unit directly as key; Sylvanas returns stable userdata wrappers for the same in-game entity.
M._cache = {}

local _core_time = core and core.time
local _type = type
local _pcall = pcall
local _ipairs = ipairs
local _pairs = pairs

local function _now()
    return _core_time and _core_time() or 0
end

--- Populate the unit's buff/debuff snapshot tables from current aura state.
--- Clears old entries and repopulates fresh from unit:get_buffs() / unit:get_debuffs().
---@param unit game_object|nil The unit to snapshot.
function M.snapshot(unit)
    if not unit then return end
    local entry = M._cache[unit]
    local now = _now()

    -- Reuse existing entry tables or create fresh ones
    if not entry then
        entry = { ts = 0, buffs = {}, debuffs = {} }
        M._cache[unit] = entry
    end

    entry.ts = now

    -- Repopulate buffs
    local buffs = entry.buffs
    for k in _pairs(buffs) do buffs[k] = nil end  -- clear inline (Pattern 4: no new table)
    local ok, rawbuffs = _pcall(function() return unit:get_buffs() end)
    if ok and _type(rawbuffs) == "table" then
        for _, aura in _ipairs(rawbuffs) do
            if _type(aura) == "table" and aura.buff_id then
                buffs[aura.buff_id] = true
            end
        end
    end

    -- Repopulate debuffs
    local debuffs = entry.debuffs
    for k in _pairs(debuffs) do debuffs[k] = nil end
    local ok2, rawdebuffs = _pcall(function() return unit:get_debuffs() end)
    if ok2 and _type(rawdebuffs) == "table" then
        for _, aura in _ipairs(rawdebuffs) do
            if _type(aura) == "table" and aura.buff_id then
                debuffs[aura.buff_id] = true
            end
        end
    end
end

--- Validate TTL and optionally re-snapshot if expired.
--- Returns the unit's cache entry or nil if unit is invalid.
local function _get_entry(unit)
    if not unit then return nil end
    local entry = M._cache[unit]
    if not entry then return nil end
    if _now() - entry.ts > M.TTL_MS then
        -- TTL expired — re-snapshot inline
        M.snapshot(unit)
        entry = M._cache[unit]
    end
    return entry
end

--- Check if a specific buff ID is active on the unit.
--- Returns true if buff found in snapshot (with TTL validation), false otherwise.
---@param unit game_object|nil
---@param id number Buff spell ID to check.
---@return boolean
function M.find_buff(unit, id)
    local entry = _get_entry(unit)
    if not entry then return false end
    return entry.buffs[id] == true
end

--- Check if ANY buff ID from the provided array is active on the unit.
--- Short-circuits on first match.
---@param unit game_object|nil
---@param ids table Array of buff spell IDs.
---@return boolean
function M.find_buffs(unit, ids)
    local entry = _get_entry(unit)
    if not entry then return false end
    for i = 1, #ids do
        if entry.buffs[ids[i]] then return true end
    end
    return false
end

--- Check if a specific debuff ID is active on the unit.
--- Returns true if debuff found in snapshot (with TTL validation), false otherwise.
---@param unit game_object|nil
---@param id number Debuff spell ID to check.
---@return boolean
function M.find_debuff(unit, id)
    local entry = _get_entry(unit)
    if not entry then return false end
    return entry.debuffs[id] == true
end

return M
