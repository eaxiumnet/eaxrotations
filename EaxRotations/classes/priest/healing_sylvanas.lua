-- healing_sylvanas.lua — Priest Healing Utilities for Holy and Discipline.
-- WHAT:  shared party/raid scanning, PW:S absorb tracking, and heal target selection.
-- WHEN:  loaded by holy_sylvanas.lua and discipline_sylvanas.lua during addon load.
-- WHY:   centralizes healing logic so both specs share the same triage and absorb math.
-- SAFETY: NS guard at load; buff_points nil-guarded (Pattern 11); no per-frame allocations.

-- ============================================================================
-- Priest Healing Utilities (EaxRotations)
-- Shared healing target scanning for Holy and Discipline playstyles
-- ============================================================================
local _G = _G
local NS = _G.EaxRotations
if not NS then
    if type(core) == "table" and type(core.log_error) == "function" then
        core.log_error("[EaxRotations ERROR] Core module not loaded!")
    else
        print("[EaxRotations ERROR] Core module not loaded!")
    end
    return
end

local _ok_enums, enums = pcall(require, "common/enums")
if not _ok_enums or type(enums) ~= "table" or type(enums.class_id) ~= "table" then enums = { class_id = NS.CLASS_ID } end
local load_player = NS.GetPlayer and NS.GetPlayer()
local ok_cls, cls_id = pcall(function() return load_player and load_player:get_class() end)
if not ok_cls or cls_id ~= enums.class_id.PRIEST then return end

local math_floor = math.floor
local ipairs = ipairs

local PARTY_UNITS = { "player", "party1", "party2", "party3", "party4" }
local RAID_UNITS = {}
for i = 1, 40 do RAID_UNITS[i] = "raid" .. i end

local healing_targets = {}
local healing_targets_count = 0
local scan_frame = 0

NS.PriestHealing = {}

local WEAKENED_SOUL_DEBUFF_IDS = { 6788 }
local RENEW_BUFF_IDS = { 139, 6074, 6075, 6076, 6077, 6078, 10927, 10928, 10929, 25315, 25221, 25222 }
local POWER_WORD_SHIELD_BUFF_IDS = { 25218, 25217, 10901, 10900, 10899, 10898, 6066, 6065, 3747, 600, 592, 17 }
-- Shared helpers from core_sylvanas.lua
local buff_up, debuff_up, predict_effective_deficit, buff_remains = NS.import_helpers("buff_up", "debuff_up", "predict_effective_deficit", "buff_remains")

local function has_weakened_soul(unit)
    if not unit then return true end
    for _, debuff_id in ipairs(WEAKENED_SOUL_DEBUFF_IDS) do
        if debuff_up(unit, debuff_id) then return true end
    end
    return false
end

local function has_renew(unit)
    if not unit then return false end
    for _, buff_id in ipairs(RENEW_BUFF_IDS) do
        if buff_up(unit, buff_id) then return true end
    end
    return false
end

--- Returns remaining seconds on Renew, or 0 if not present.
--- Used to avoid early refresh (wasted ticks) per Research divergence table.
local function renew_remains(unit)
    if not unit then return 0 end
    if type(buff_remains) ~= "function" then
        -- Fallback: if buff_remains isn't available, use has_renew as binary
        return has_renew(unit) and 999 or 0
    end
    local longest = 0
    for _, buff_id in ipairs(RENEW_BUFF_IDS) do
        local r = buff_remains(unit, buff_id)
        if r and r > longest then longest = r end
    end
    return longest
end

local function has_pws(unit)
    if not unit then return false end
    for _, buff_id in ipairs(POWER_WORD_SHIELD_BUFF_IDS) do
        if buff_up(unit, buff_id) then return true end
    end
    return false
end

--- Returns the remaining absorb amount on a Power Word: Shield buff.
--- Uses buff.points[1] which contains the absorb remaining value.
--- Returns 0 if no PW:S buff is present.
---@param unit game_object The unit to check.
---@return number absorb_remaining The absorb remaining on the shield, or 0.
local function pws_absorb_remaining(unit)
    if not unit then return 0 end
    if type(NS.buff_points) ~= "function" then
        -- Fallback: buff_points not yet available (core loaded after this module)
        return has_pws(unit) and 1 or 0
    end
    local points = NS.buff_points(unit, POWER_WORD_SHIELD_BUFF_IDS)
    if not points then return 0 end
    return points[1] or 0
end

NS.PriestHealing.pws_absorb_remaining = pws_absorb_remaining

NS.PriestHealing.has_weakened_soul = has_weakened_soul
NS.PriestHealing.has_renew = has_renew
NS.PriestHealing.renew_remains = renew_remains
NS.PriestHealing.has_pws = has_pws

NS.PriestHealing.predict_effective_deficit = predict_effective_deficit

-- Magic debuff detection for Dispel Magic gate (used by Holy + Disc)
-- Uses NS.has_dispel_type_debuff when available; falls back to manual scan.
local DANGEROUS_MAGIC_DEBUFF_IDS = {
    12826 -- Polymorph
    , 61305 -- Polymorph (Black Cat)
    , 61721 -- Polymorph (Rabbit)
    , 61780 -- Polymorph (Turkey)
    , 26373 -- Hibernate
    , 19386 -- Wyvern Sting
    , 14326 -- Sleep
    , 5782 -- Fear
    , 6213 -- Fear
    , 17962 -- Death Coil
    , 15122 -- Repentance
    , 605 -- Mind Control
    , 20537 -- Arcane Torrent (silence)
    , 15487 -- Silence
    , 18469 -- Counterspell (silence)
    -- Expanded from WoWHead TBC dungeon/raid research for dangerous magic that kills or slows clears (MC, horror, AoE fear, silences, dots)
    , 32830 -- Possess (Auchenai Crypts MC - not easily dispelled)
    , 34984 -- Psychic Horror (Underbog/Slave Pens - bypasses Tremor)
    , 38660 -- Fear (Steamvault Coilfang Siren AoE)
    , 46561 -- Fear (Sunwell Dusk Priest - uninterruptible)
    , 17172 -- Devouring Plague
    , 10890, 10888, 8124, 8122 -- Psychic Scream
    , 18425 -- Improved Counterspell silence
    , 18425 -- Improved Counterspell (silence)
}

--- Check if a unit has a dangerous magic debuff worth dispelling.
-- @param unit game_object|nil
-- @return boolean
local function has_dangerous_dispel(unit)
    if not unit then return false end
    -- Fast path: use shared type-based debuff checker
    if NS.has_dispel_type_debuff then
        local ok, result = pcall(NS.has_dispel_type_debuff, unit, "Magic")
        if ok and result == true then return true end
    end
    -- Fallback: scan known dangerous magic debuff IDs
    if NS.debuff_up then
        for i = 1, #DANGEROUS_MAGIC_DEBUFF_IDS do
            local ok, up = pcall(NS.debuff_up, unit, DANGEROUS_MAGIC_DEBUFF_IDS[i])
            if ok and up then return true end
        end
    end
    return false
end

--- Check if a unit has a disease debuff worth dispelling.
-- @param unit game_object|nil
-- @return boolean
local function has_disease(unit)
    if not unit then return false end
    -- Fast path: use shared type-based debuff checker
    if NS.has_dispel_type_debuff then
        local ok, result = pcall(NS.has_dispel_type_debuff, unit, "Disease")
        if ok and result == true then return true end
    end
    -- Fallback: use has_debuff with known disease IDs
    local DISEASE_DEBUFF_IDS = {
        3427 -- Infected Wound
        , 16428 -- Mangle (TBC disease flag)
        , 19615 -- Fling
        , 3434 -- Wandering Plague
        , 17172 -- Devouring Plague
    }
    if NS.debuff_up then
        for i = 1, #DISEASE_DEBUFF_IDS do
            local ok, up = pcall(NS.debuff_up, unit, DISEASE_DEBUFF_IDS[i])
            if ok and up then return true end
        end
    end
    return false
end

NS.PriestHealing.has_dangerous_dispel = has_dangerous_dispel
NS.PriestHealing.has_disease = has_disease

local is_in_raid = NS.is_in_raid or function() return false end
local is_in_party = NS.is_in_party or function() return false end

local build_healing_entries = NS.build_healing_entries or function() return false end
local healing_get_tank = NS.healing_get_tank or function() return nil end
local healing_get_lowest_hp = NS.healing_get_lowest_hp or function() return nil end
local healing_count_below_hp = NS.healing_count_below_hp or function() return 0 end

local function scan_healing_targets()
    local current_frame = math_floor(NS.game_time_ms() / (1000 / 60))

    if current_frame > 0 and current_frame == scan_frame then
        return healing_targets, healing_targets_count
    end
    scan_frame = current_frame

    healing_targets_count = build_healing_entries(healing_targets, function(entry, unit)
        entry.has_renew = has_renew(unit)
        entry.renew_remains = renew_remains(unit)
        entry.has_pws = has_pws(unit)
        entry.has_weakened_soul = has_weakened_soul(unit)
    end)

    return healing_targets, healing_targets_count
end

NS.PriestHealing.scan_healing_targets = scan_healing_targets

local function get_tank_target()
    scan_healing_targets()
    return healing_get_tank(healing_targets, healing_targets_count)
end

NS.PriestHealing.get_tank_target = get_tank_target

local function get_lowest_hp_target(threshold)
    threshold = threshold or 100
    scan_healing_targets()
    return healing_get_lowest_hp(healing_targets, healing_targets_count, threshold)
end

NS.PriestHealing.get_lowest_hp_target = get_lowest_hp_target

local function count_below_hp(threshold)
    threshold = threshold or 100
    scan_healing_targets()
    return healing_count_below_hp(healing_targets, healing_targets_count, threshold)
end

NS.PriestHealing.count_below_hp = count_below_hp
NS.PriestHealing.is_in_raid = is_in_raid
NS.PriestHealing.is_in_party = is_in_party
NS.PriestHealing.PARTY_UNITS = PARTY_UNITS
NS.PriestHealing.RAID_UNITS = RAID_UNITS

--- Counts injured units in the player's subgroup only.
--- Uses the new core.party / get_party_frames backed NS.GetPartyMembers() for
--- accurate, current subgroup (the player's exact party in raids).
--- This is more reliable than is_party_member pcalls and leverages the frames API.
---@param threshold number HP threshold (0-100) to count as injured.
---@return integer count Number of injured subgroup members.
local function count_subgroup_below_hp(threshold)
    -- Prefer the accurate party list from new party frames feature
    local party = NS.GetPartyMembers and NS.GetPartyMembers() or nil
    if not party or #party == 0 then
        -- Fallback to full entries scan
        local entries, count = scan_healing_targets()
        if count == 0 or not entries then return 0 end
        local injured = 0
        for i = 1, count do
            local entry = entries[i]
            if entry and entry.effective_hp and entry.effective_hp < threshold then
                injured = injured + 1
            end
        end
        return injured
    end
    local injured = 0
    for i = 1, #party do
        local u = party[i]
        if u then
            local hp = NS.unit_health_pct and NS.unit_health_pct(u) or 100
            if hp < threshold then
                injured = injured + 1
            end
        end
    end
    return injured
end

NS.PriestHealing.count_subgroup_below_hp = count_subgroup_below_hp

-- Healing utilities loaded
return NS.PriestHealing
