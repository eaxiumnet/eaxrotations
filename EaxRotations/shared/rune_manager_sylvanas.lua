-- rune_manager_sylvanas.lua — Death Knight rune and runic-power state manager.
-- WHAT:  Exposes ready rune counts and runic power for WotLK Death Knight specs.
-- WHEN:  Called from Death Knight rotation specs every update tick.
-- WHY:   Centralizes rune-slot queries and runic-power reading so specs stay simple.
-- SAFETY: Nil-guards every API call; falls back to 0 when rune/power APIs are missing.
-- DECISION: Hybrid primary/fallback design per plans/wotlk-rune-api-verdict.md.

local _G = _G
local NS = _G.EaxRotations
if not NS then return nil end

local M = {}
NS.RuneManager = M

-- ---------------------------------------------------------------------------
-- Resolve power-type enum values with engine + hard-coded fallback.
-- ---------------------------------------------------------------------------
local _ok, _enums = pcall(require, "common/enums")
local POWER_RUNES       = (_ok and _enums and _enums.power_type and _enums.power_type.RUNES)       or 5
local POWER_RUNICPOWER  = (_ok and _enums and _enums.power_type and _enums.power_type.RUNICPOWER)  or 6

-- ---------------------------------------------------------------------------
-- Cache hot-path API references at module load.
-- ---------------------------------------------------------------------------
local _core_spell_book = _G.core and _G.core.spell_book or {}
local _get_rune_info        = _core_spell_book.get_rune_info
local _get_rune_type        = _core_spell_book.get_rune_type
local _is_rune_slot_active  = _core_spell_book.is_rune_slot_active

local _get_player = NS.GetPlayer

-- ---------------------------------------------------------------------------
-- Rune type index -> name mapping.
-- 1 = Blood, 2 = Unholy, 3 = Frost, 4 = Death
-- ---------------------------------------------------------------------------
local RUNE_TYPE_NAMES = {
    [1] = "blood",
    [2] = "unholy",
    [3] = "frost",
    [4] = "death",
}

-- ---------------------------------------------------------------------------
-- Internal helper: safely query a single rune slot.
-- Returns type_name (or nil) and ready boolean.
-- ---------------------------------------------------------------------------
local function query_slot(slot)
    if not _get_rune_type or not _get_rune_info then
        return nil, false
    end

    local ok_type, type_idx = pcall(_get_rune_type, slot)
    if not ok_type then return nil, false end

    local type_name = RUNE_TYPE_NAMES[type_idx]
    if not type_name then return nil, false end

    local ok_info, info = pcall(_get_rune_info, slot)
    local ready = false
    if ok_info and info and info.ready then
        ready = true
    end

    return type_name, ready
end

-- ---------------------------------------------------------------------------
-- Return a snapshot of all six rune slots.
-- Format: { blood=2, frost=2, unholy=2, death=0,
--           ready={ blood=1, frost=2, unholy=1, death=0 } }
-- ---------------------------------------------------------------------------
function M.get_rune_state()
    local counts = { blood = 0, frost = 0, unholy = 0, death = 0 }
    local ready  = { blood = 0, frost = 0, unholy = 0, death = 0 }

    for slot = 1, 6 do
        local type_name, is_ready = query_slot(slot)
        if type_name then
            counts[type_name] = counts[type_name] + 1
            if is_ready then
                ready[type_name] = ready[type_name] + 1
            end
        end
    end

    return {
        blood  = counts.blood,
        frost  = counts.frost,
        unholy = counts.unholy,
        death  = counts.death,
        ready  = ready,
    }
end

-- ---------------------------------------------------------------------------
-- Per-type ready rune count helpers.
-- ---------------------------------------------------------------------------
function M.get_blood_runes_ready()
    if not _get_rune_type or not _get_rune_info then return 0 end
    local state = M.get_rune_state()
    return state.ready.blood
end

function M.get_frost_runes_ready()
    if not _get_rune_type or not _get_rune_info then return 0 end
    local state = M.get_rune_state()
    return state.ready.frost
end

function M.get_unholy_runes_ready()
    if not _get_rune_type or not _get_rune_info then return 0 end
    local state = M.get_rune_state()
    return state.ready.unholy
end

function M.get_death_runes_ready()
    if not _get_rune_type or not _get_rune_info then return 0 end
    local state = M.get_rune_state()
    return state.ready.death
end

-- ---------------------------------------------------------------------------
-- Return current runic power for a unit (defaults to local player).
-- Primary path:  unit:get_power(POWER_RUNICPOWER)
-- Legacy fallback: unit:get_runic_power() for existing test mocks.
-- ---------------------------------------------------------------------------
function M.get_runic_power(unit)
    unit = unit or (_get_player and _get_player())
    if not unit then return 0 end

    if unit.get_power then
        local ok, val = pcall(unit.get_power, unit, POWER_RUNICPOWER)
        if ok then return val or 0 end
    end

    -- Legacy synthetic fallback (NOT the primary path).
    if unit.get_runic_power then
        local ok, val = pcall(unit.get_runic_power, unit)
        if ok then return val or 0 end
    end

    return 0
end

-- ---------------------------------------------------------------------------
-- Return runic power percentage (0-100).
-- Primary path: unit:get_power / unit:get_max_power * 100
-- ---------------------------------------------------------------------------
function M.get_runic_power_pct(unit)
    unit = unit or (_get_player and _get_player())
    if not unit then return 0 end

    if unit.get_power and unit.get_max_power then
        local ok_current, current = pcall(unit.get_power, unit, POWER_RUNICPOWER)
        local ok_max, max_power   = pcall(unit.get_max_power, unit, POWER_RUNICPOWER)
        if ok_current and ok_max and max_power and max_power > 0 then
            return (current / max_power) * 100
        end
    end

    return 0
end

return M
