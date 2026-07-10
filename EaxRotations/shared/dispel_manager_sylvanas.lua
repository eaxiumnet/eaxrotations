-- dispel_manager_sylvanas.lua — Automated dispel/cleanse for TBC Anniversary (2.5.5).
-- WHAT:  Auto-dispel party/raid members (and self) for dispellable debuffs.
-- WHEN:  Any healer or class with dispel in group content.
-- WHY:   Reduces manual dispel burden in raids/dungeons.
-- SAFETY: Throttled (max 1 dispel per 3s); skips during critical healing
-- DECISION: 5-class dispel dispatcher with 3s throttle and tank-priority.
--         (tank < 50% HP); nil-guarded settings; priority-based targeting.

local _G = _G
local NS = _G.EaxRotations
local spec_kit = require("shared/spec_kit_sylvanas")
if not NS then return end

local M = {}
NS.DispelManager = M

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------
local DISPEL_THROTTLE_SECONDS = 3
local TANK_CRITICAL_HP = 50

-- Debuff type to spell mapping (class-specific)
local CLASS_DISPELS = {
    PRIEST = {
        magic = { spell = "DispelMagic", ids = { 988, 527 } },
        magic_mass = { spell = "MassDispel", ids = { 32375 } },  -- TBC Mass Dispel for AoE efficiency in dungeons
        disease = { spell = "AbolishDisease", ids = { 552 } },
        disease_alt = { spell = "CureDisease", ids = { 528 } },
    },
    PALADIN = {
        poison = { spell = "Cleanse", ids = { 4987 } },
        disease = { spell = "Cleanse", ids = { 4987 } },
        magic = { spell = "Cleanse", ids = { 4987 } },  -- Requires Sacred Cleansing talent in TBC
    },
    SHAMAN = {
        poison = { spell = "CurePoison", ids = { 526 } },
        disease = { spell = "CureDisease", ids = { 2870 } },
    },
    DRUID = {
        poison = { spell = "AbolishPoison", ids = { 2893 } },
        poison_alt = { spell = "CurePoison", ids = { 8946 } },
        curse = { spell = "RemoveCurse", ids = { 2782 } },
    },
    MAGE = {
        curse = { spell = "RemoveCurse", ids = { 475 } },
    },
    -- Warlock pet for magic dispel in dungeons (Devour Magic)
    WARLOCK = {
        magic = { spell = "DevourMagic", ids = { 19505, 19731, 19734, 19736 } }, -- ranks for Felhunter
    },
}

-- Class ID mapping for determining dispel capabilities
local CLASS_ID_MAP = {
    [5] = "PRIEST",
    [2] = "PALADIN",
    [7] = "SHAMAN",
    [11] = "DRUID",
    [8] = "MAGE",
    [9] = "WARLOCK",
}

-- ---------------------------------------------------------------------------
-- Settings helper
-- ---------------------------------------------------------------------------
local function setting(context, key, fallback)
    local s = context and context.settings
    if s and s[key] ~= nil then return s[key] end
    if NS.get_setting then return NS.get_setting(key, fallback) end
    return fallback
end

-- ---------------------------------------------------------------------------
-- Throttle tracking
-- ---------------------------------------------------------------------------
local _last_dispel_at = -999

function M.is_throttled()
    local now = (NS.time_now and NS.time_now()) or 0
    return (now - _last_dispel_at) < DISPEL_THROTTLE_SECONDS
end

function M.record_dispel()
    _last_dispel_at = NS.time_now and NS.time_now() or 0
end

-- ---------------------------------------------------------------------------
-- Get player's class key for dispel lookups
-- ---------------------------------------------------------------------------
local function get_player_class_key()
    local me = NS.GetPlayer and NS.GetPlayer()
    if not me then return nil end
    local ok, class_id = pcall(function() return me:get_class() end)
    if ok and class_id then
        return CLASS_ID_MAP[class_id]
    end
    return nil
end

-- Enhanced for dungeons: use accurate party from previous group mechanics work
local function get_accurate_party(context)
    if context and context.party_members and #context.party_members > 0 then
        return context.party_members
    end
    if NS.GetPartyMembers then
        local ok, members = pcall(NS.GetPartyMembers)
        if ok and members then return members end
    end
    return context.party or {}
end

-- ---------------------------------------------------------------------------
-- Check if the player can dispel a given debuff type.
-- ---------------------------------------------------------------------------
function M.can_dispel(debuff_type)
    if not debuff_type then return false end
    local class_key = get_player_class_key()
    if not class_key then return false end
    local dispels = CLASS_DISPELS[class_key]
    if not dispels then return false end
    return dispels[debuff_type] ~= nil
end

-- ---------------------------------------------------------------------------
-- Get the spell ID to use for dispelling a debuff type.
-- ---------------------------------------------------------------------------
function M.get_dispel_spell(debuff_type)
    if not debuff_type then return nil end
    local class_key = get_player_class_key()
    if not class_key then return nil end
    local dispels = CLASS_DISPELS[class_key]
    if not dispels then return nil end
    local entry = dispels[debuff_type] or dispels[debuff_type .. "_alt"]
    -- Dungeon opt: for priest magic in group, prefer MassDispel if learned for speed (AoE)
    if class_key == "PRIEST" and debuff_type == "magic" then
        local mass_entry = dispels.magic_mass
        if mass_entry and mass_entry.ids then
            for _, id in ipairs(mass_entry.ids) do
                if NS.is_spell_learned and NS.is_spell_learned(id) then
                    return id
                end
            end
        end
    end
    if not entry then return nil end
    if entry.ids and #entry.ids > 0 then
        for _, id in ipairs(entry.ids) do
            if NS.is_spell_learned and NS.is_spell_learned(id) then
                return id
            end
        end
        return entry.ids[1]
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Scan a unit for dispellable debuffs.
-- Returns: debuff_type string or nil, spell_id or nil
-- ---------------------------------------------------------------------------
function M.scan_unit_debuffs(unit)
    if not unit then return nil, nil end
    -- Use NS.debuff_types if available (API that returns debuff types)
    if NS.debuff_types then
        local ok, types = pcall(NS.debuff_types, unit)
        if ok and types then
            for _, debuff_type in ipairs(types) do
                if M.can_dispel(debuff_type) then
                    local spell_id = M.get_dispel_spell(debuff_type)
                    if spell_id then return debuff_type, spell_id end
                end
            end
        end
    end
    -- Fallback: scan all debuffs on the unit and categorize by type
    -- Uses unit:get_debuffs() when available, falls back to known magic IDs
    local all_debuffs = nil
    if unit and unit.get_debuffs then
        local ok, debuffs = pcall(unit.get_debuffs, unit)
        if ok and type(debuffs) == "table" then
            all_debuffs = debuffs
        end
    end
    if all_debuffs then
        for _, debuff in ipairs(all_debuffs) do
            local dtype = debuff and debuff.type
            if dtype and M.can_dispel(dtype) then
                local spell_id = M.get_dispel_spell(dtype)
                if spell_id then return dtype, spell_id end
            end
        end
    else
        -- Narrow fallback: known MAGIC debuff IDs only (expanded from WoWHead TBC dungeon research for dangerous effects that kill or slow clears)
        local MAGIC_DEBUFF_IDS = {
            118, 12824, 12825, 12826,  -- Polymorph
            5782, 6213, 6215,          -- Fear
            2637,                      -- Hibernate
            3600,                      -- Earthbind
            12528,                     -- Counterspell - Silence
            18469, 28730,              -- Silence (Improved Counterspell, Arcane Torrent)
            589, 594, 970,             -- Shadow Word: Pain
            348, 172,                  -- Immolate, Corruption
            -- Additional from WoWHead: common dungeon magic that causes death/slow (MC, dots, silences)
            32830,                     -- Possess (MC from Auchenai)
            34984,                     -- Psychic Horror
            38660,                     -- Fear (Siren)
            46561,                     -- Fear (Dusk Priest)
            17172,                     -- Devouring Plague (disease/magic)
        }
        for _, id in ipairs(MAGIC_DEBUFF_IDS) do
            if NS.has_debuff and NS.has_debuff(unit, id) then
                return "magic", M.get_dispel_spell("magic")
            end
        end
    end
    return nil, nil
end

-- ---------------------------------------------------------------------------
-- Priority-based target selection for dispel.
-- Priority: "self" -> player first, "tank" -> tank first, "all" -> lowest HP first
-- ---------------------------------------------------------------------------
function M.find_dispel_target(context, state)
    local priority = setting(context, "dispel_priority", "all")
    local me = context.me or NS.GetPlayer and NS.GetPlayer()
    if not me then return nil, nil end

    -- Self check (highest priority when priority == "self")
    if priority == "self" then
        local dtype, spell_id = M.scan_unit_debuffs(me)
        if dtype then return me, spell_id, dtype end
        return nil, nil, nil
    end

    local party = get_accurate_party(context)

    -- Dungeon optimization: always prefer tank first in group content (from previous party_tanks work)
    local is_dungeon_group = context and context.is_group and not (context.is_pvp)
    if is_dungeon_group and state and state.tank and state.tank.unit then
        local dtype, spell_id = M.scan_unit_debuffs(state.tank.unit)
        if dtype then return state.tank.unit, spell_id, dtype end
    end

    -- Tank check (highest priority when priority == "tank")
    if priority == "tank" and state and state.tank and state.tank.unit then
        local dtype, spell_id = M.scan_unit_debuffs(state.tank.unit)
        if dtype then return state.tank.unit, spell_id, dtype end
    end

    -- All: scan self + party, prefer lowest HP first. In dungeons, also consider control_risk for magic
    local candidates = {}
    local function add(unit)
        if not unit then return end
        local dtype, spell_id = M.scan_unit_debuffs(unit)
        if dtype then
            local hp = 100
            if NS.unit_health_pct then
                local ok, val = pcall(NS.unit_health_pct, unit)
                if ok then hp = val or 100 end
            end
            -- Dungeon boost: if control_risk and magic, higher priority (lower effective hp)
            local effective_hp = hp
            if is_dungeon_group and context.control_risk and dtype == "magic" then
                effective_hp = hp - 20  -- boost priority for control magic
            end
            candidates[#candidates + 1] = { unit = unit, hp = effective_hp, dtype = dtype, spell_id = spell_id }
        end
    end

    add(me)
    for _, member in ipairs(party) do
        add(member)
    end

    if #candidates == 0 then return nil, nil, nil end

    -- Sort by HP ascending (lowest HP first)
    table.sort(candidates, function(a, b) return a.hp < b.hp end)

    return candidates[1].unit, candidates[1].spell_id, candidates[1].dtype
end

-- ---------------------------------------------------------------------------
-- Main entry point: should we dispel now?
-- Returns: boolean, target, spell_id
-- ---------------------------------------------------------------------------
function M.should_dispel(context, state)
    if not setting(context, "auto_dispel", true) then return false, nil, nil end
    if M.is_throttled() then return false, nil, nil end

    -- Dungeon optimization: if control_risk or fear_nearby (from previous mechanics), be more aggressive on dispels to avoid deaths
    local is_dungeon = context and context.is_group
    if is_dungeon and (context.control_risk or context.fear_nearby) then
        -- force check even if low hp sometimes, but still respect throttle
    end

    -- Skip dispelling during critical healing moments (but allow in high risk)
    local skip_critical = not (is_dungeon and context.control_risk)
    if skip_critical and state and state.tank and state.tank_hp then
        if (state.tank_hp or 100) < TANK_CRITICAL_HP then return false, nil, nil end
    end
    if skip_critical and state and state.lowest_hp and state.lowest_hp < TANK_CRITICAL_HP then
        return false, nil, nil
    end

    local target, spell_id, dtype = M.find_dispel_target(context, state)
    if not target or not spell_id then return false, nil, nil end

    -- Check GCD / casting state
    if context.is_casting or context.is_channeling then return false, nil, nil end

    return true, target, spell_id
end

-- ---------------------------------------------------------------------------
-- Execute a dispel on the target.
-- ---------------------------------------------------------------------------
function M.execute_dispel(target, spell_id)
    if not target or not spell_id then return false end
    local ok = false
    if NS.try_cast then
        ok = NS.try_cast(spell_id, target, "[DISPEL] Auto-dispel")
    end
    if ok then M.record_dispel() end
    return ok
end

-- module initialized
return M
