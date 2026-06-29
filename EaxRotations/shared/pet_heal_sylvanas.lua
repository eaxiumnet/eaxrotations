-- pet_heal_sylvanas.lua — Include party/raid pets in healing target scan.
-- WHAT:  Extends the healing target list to include Hunter/Warlock pets.
-- WHEN:  Any healing spec in group content with heal_pets enabled.
-- WHY:   Hunters and warlocks expect their pets to be healed in dungeons/raids.
-- SAFETY: All API calls nil-guarded; pet entries get 0.6x triage weight to avoid
-- DECISION: Hunter/Warlock pet healing dispatcher using 0.6x triage weight.
--         pets outranking players. Falls back gracefully when pet APIs unavailable.
-- Decision: Separate module so build_healing_entries can optionally append pets
--           without complicating the core healing scan.

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local type = type
local ipairs = ipairs
local pcall = pcall
local tostring = tostring

local M = {}
NS.PetHeal = M

-- ---------------------------------------------------------------------------
-- Defaults
-- ---------------------------------------------------------------------------
local DEFAULT_ENABLED = true
local DEFAULT_PET_WEIGHT = 0.6   -- Pet HP is multiplied by this for triage scoring
local DEFAULT_MAX_PET_HP_PCT = 80 -- Only include pets below 80% (ignore full-health pets)

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function safe_number(v, fallback)
    fallback = fallback or 0
    return type(v) == "number" and v or fallback
end

local function unit_hp_pct(unit)
    if not unit then return nil end
    local ok, pct = pcall(function()
        if unit.get_health_percentage then return unit:get_health_percentage() end
        if NS.unit_health_pct then return NS.unit_health_pct(unit) end
        return nil
    end)
    if ok and type(pct) == "number" then return pct end
    return nil
end

local function unit_max_hp(unit)
    if not unit then return 0 end
    local ok, val = pcall(function()
        if unit.get_max_health then return unit:get_max_health() end
        return 0
    end)
    if ok and type(val) == "number" then return val end
    return 0
end

local function unit_hp(unit)
    if not unit then return 0 end
    local ok, val = pcall(function()
        if unit.get_health then return unit:get_health() end
        return 0
    end)
    if ok and type(val) == "number" then return val end
    return 0
end

local function unit_alive(unit)
    if not unit then return false end
    local ok, alive = pcall(function()
        if unit.is_dead then return not unit:is_dead() end
        if unit.is_ghost then return not unit:is_ghost() end
        return true
    end)
    return ok and alive ~= false
end

local function unit_distance(a, b)
    if not a or not b then return 999 end
    if NS.unit_distance then
        local ok, d = pcall(NS.unit_distance, a, b)
        if ok and type(d) == "number" then return d end
    end
    return 999
end

-- ---------------------------------------------------------------------------
-- Pet scanning
-- ---------------------------------------------------------------------------
-- Static table for pet scanning (Pattern 4: no per-frame allocs)
local _pet_scan = { n = 0 }

--- Gather party/raid pets via available APIs.
-- @param me  game_object  Local player (for distance filtering)
-- @return table  Array of pet game_objects
local function scan_pets(me)
    _pet_scan.n = 0

    -- Try core.object_manager.get_party_pets if available
    local om = core and core.object_manager
    if om then
        local ok, list = pcall(function()
            if type(om.get_party_pets) == "function" then
                return om:get_party_pets()
            end
            return nil
        end)
        if ok and type(list) == "table" then
            for _, pet in ipairs(list) do
                if pet and unit_alive(pet) then
                    _pet_scan.n = _pet_scan.n + 1
                    _pet_scan[_pet_scan.n] = pet
                end
            end
        end
    end

    -- Fallback: scan visible objects and check if they are pets of party members
    if _pet_scan.n == 0 and om and type(om.get_visible_objects) == "function" then
        local ok_vis, visible = pcall(om.get_visible_objects, om)
        if ok_vis and type(visible) == "table" then
            for _, obj in ipairs(visible) do
                if obj and unit_alive(obj) then
                    local ok_pet, is_pet = pcall(function()
                        if obj.is_pet then return obj:is_pet() end
                        if obj.get_unit_type then return obj:get_unit_type() == 3 end -- 3 = pet
                        return false
                    end)
                    if ok_pet and is_pet then
                        _pet_scan.n = _pet_scan.n + 1
                        _pet_scan[_pet_scan.n] = obj
                    end
                end
            end
        end
    end

    return _pet_scan, _pet_scan.n
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Append pet entries to an existing healing entries array.
-- @param out       table   Existing entries array (mutated in-place)
-- @param count     number  Current number of valid entries in out
-- @param me        game_object  Local player
-- @param settings  table|nil    Context settings (heal_pets, pet_weight, etc.)
-- @return number   New count after appending pet entries
function M.append_entries(out, count, me, settings)
    if type(out) ~= "table" then return count or 0 end
    count = safe_number(count, 0)

    settings = settings or (NS.settings or {})
    local enabled = settings.heal_pets
    if enabled == nil then enabled = DEFAULT_ENABLED end
    if not enabled then return count end

    local pets, pet_count = scan_pets(me)
    if pet_count <= 0 then return count end

    local weight = safe_number(settings.pet_weight, DEFAULT_PET_WEIGHT)
    local max_hp_pct = safe_number(settings.pet_max_hp_pct, DEFAULT_MAX_PET_HP_PCT)

    for i = 1, pet_count do
        local pet = pets[i]
        if pet then
            local hp_pct = unit_hp_pct(pet)
            if hp_pct and hp_pct < max_hp_pct then
                local max_hp = unit_max_hp(pet)
                local hp = unit_hp(pet)
                local dist = unit_distance(me, pet)
                if dist <= 40 then
                    count = count + 1
                    out[count] = {
                        unit = pet,
                        hp = hp_pct,
                        effective_hp = hp_pct * weight,
                        current_hp = hp,
                        max_hp = max_hp,
                        deficit = math.max(0, max_hp - hp),
                        effective_deficit = math.max(0, max_hp - hp),
                        incoming_dps = 0,
                        time_to_die = 999,
                        is_player = false,
                        is_tank = false,
                        is_pet = true,
                    }
                end
            end
        end
    end

    return count
end

--- Get the number of pet entries that would be appended (for AoE heal logic).
-- @param me        game_object  Local player
-- @param settings  table|nil
-- @return number  Count of pets that need healing
function M.count_injured_pets(me, settings)
    settings = settings or (NS.settings or {})
    local enabled = settings.heal_pets
    if enabled == nil then enabled = DEFAULT_ENABLED end
    if not enabled then return 0 end

    local pets, pet_count = scan_pets(me)
    if pet_count <= 0 then return 0 end

    local max_hp_pct = safe_number(settings.pet_max_hp_pct, DEFAULT_MAX_PET_HP_PCT)
    local injured = 0
    for i = 1, pet_count do
        local pet = pets[i]
        if pet then
            local hp_pct = unit_hp_pct(pet)
            if hp_pct and hp_pct < max_hp_pct then
                local dist = unit_distance(me, pet)
                if dist <= 40 then
                    injured = injured + 1
                end
            end
        end
    end
    return injured
end

if NS.log then NS.log("PetHeal module loaded") end
return M
