-- ============================================================================
-- Priest Healing Utilities (EaxRotations)
-- Shared healing target scanning for Holy and Discipline playstyles
-- ============================================================================
-- Readability notes:
--   What: shared Priest healing scan, triage, and spell recommendation helpers.
--   When: Holy and Discipline need to decide who should receive the next heal.
--   Why: Priest has a wide toolkit, so target scoring lives outside the strategy list.
--   Safety: missing party data, aura data, or API methods produce safe fallback decisions.

-- Decision notes:
--   Healing helpers scan and decorate targets once per frame so multiple strategies share the same triage data.
--   Effective HP uses incoming heals and absorbs when the API exposes them; this avoids sniping heals already covered.
--   Target data is intentionally nil-tolerant because party/raid objects can disappear during zoning, death, or range changes.
local _G = _G
local NS = _G.EaxRotations
if not NS then
    print("[EaxRotations ERROR] Core module not loaded!")
    return
end

local enums = require("common/enums")
if type(enums) ~= "table" or type(enums.class_id) ~= "table" then enums = { class_id = NS.CLASS_ID } end
local load_player = NS.GetPlayer()
if not load_player or load_player:get_class() ~= enums.class_id.PRIEST then return end


local math_floor = math.floor
local ipairs = ipairs

local PARTY_UNITS = { "player", "party1", "party2", "party3", "party4" }
local RAID_UNITS = {}
for i = 1, 40 do RAID_UNITS[i] = "raid" .. i end

local healing_targets = {}
local healing_targets_count = 0
local scan_frame = 0

NS.PriestHealing = {}

local WEAKENED_SOUL_DEBUFF_IDS = { 6788, 6789, 6790, 6791, 6792, 6793, 25368 }
local RENEW_BUFF_IDS = { 139, 6074, 6075, 6076, 6077, 6078, 10927, 10928, 10929, 25315, 25221, 25222 }
local POWER_WORD_SHIELD_BUFF_IDS = { 17, 592, 600, 602, 1006, 5573, 10060, 11419, 12479, 12480, 12481, 12482, 12483, 14768, 15363, 17000, 17004, 17191, 25218, 25219, 25368, 25369, 25370, 25371, 25375, 32744 }
-- Shared helpers from core_sylvanas.lua
local buff_up, debuff_up, predict_effective_deficit = NS.import_helpers("buff_up", "debuff_up", "predict_effective_deficit")

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

local function has_pws(unit)
    if not unit then return false end
    for _, buff_id in ipairs(POWER_WORD_SHIELD_BUFF_IDS) do
        if buff_up(unit, buff_id) then return true end
    end
    return false
end

NS.PriestHealing.has_weakened_soul = has_weakened_soul
NS.PriestHealing.has_renew = has_renew
NS.PriestHealing.has_pws = has_pws

NS.PriestHealing.predict_effective_deficit = predict_effective_deficit

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

NS.log("Healing utilities loaded")
return NS.PriestHealing
