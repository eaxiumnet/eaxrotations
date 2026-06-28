-- ============================================================================
-- Shared Helper: Pet Manager (Hunter + Warlock)
-- ============================================================================
-- Ported from archive EAXHunterBeastMastery pet_manager.lua
-- State machine: IDLE -> ENGAGING -> FIGHTING -> RETREATING
-- Safety: nil-guarded, throttled, no raw API calls.
-- ============================================================================

local NS = _G.EaxRotations
local M = {}

-- Platform-provided pet handler for engine-level pet state management
local _ph_ok, pet_handler = pcall(require, "common/utility/pet_handler")
if not _ph_ok or type(pet_handler) ~= "table" then pet_handler = nil end

local STATE_IDLE, STATE_ENGAGING, STATE_FIGHTING, STATE_RETREATING = 0, 1, 2, 3

local _states = {}

local PET_GROWL = { 2649, 14268, 14269, 14270, 14271, 14925 }
local PET_CLAW = { 2981, 14261, 14262, 14263, 14264, 14265 }
local PET_BITE = { 17253, 17254, 17255, 17256, 17257, 27050 }
local PET_GORE = { 35290, 35291 }
local PET_HOWL = { 24597, 24598, 24599, 24600 }
local PET_SCREECH = { 24604 }
local PET_THUNDER = { 26090, 26093 }
local PET_LIGHTNING = { 25011, 25012, 25013, 25014, 25015, 25016 }
local PET_POISON = { 24640 }

local PET_SPECIALS = {
    { ids = PET_HOWL, type = "howl" },
    { ids = PET_SCREECH, type = "screech" },
    { ids = PET_THUNDER, type = "thunderstomp" },
}

local function _get_state(spec)
    if not _states[spec] then
        _states[spec] = {
            state = STATE_IDLE, last_target_guid = nil,
            pet_spells_scanned = false, growl_id = nil,
            damage_id = nil, special_id = nil, special_type = nil,
            last_growl = 0, last_damage = 0, last_special = 0,
            last_mend = 0, last_follow = 0,
        }
    end
    return _states[spec]
end

function M.get_pet(me)
    if not me then return nil end
    local ok, p = pcall(function() return me:get_pet() end)
    return ok and p or nil
end

function M.pet_alive(p)
    if not p then return false end
    local ok, dead = pcall(p.is_dead, p)
    return ok and not dead
end

function M.try_cast(spell_id, target)
    if not spell_id then return false end
    local cd = 0
    local ok, cd_val = pcall(function()
        return core and core.spell_book and core.spell_book.get_spell_cooldown and core.spell_book.get_spell_cooldown(spell_id)
    end)
    if ok and cd_val then cd = cd_val end
    if cd > 0 then return false end
    if not target then return false end
    local ok2 = pcall(function()
        return core and core.input and core.input.pet_cast_target_spell and core.input.pet_cast_target_spell(spell_id, target)
    end)
    return ok2
end

function M.scan_spells(st)
    if st.pet_spells_scanned then return end
    for i = #PET_GROWL, 1, -1 do
        if NS.spell_id_is_known(PET_GROWL[i]) then st.growl_id = PET_GROWL[i]; break end
    end
    for _, group in ipairs({ PET_CLAW, PET_BITE, PET_GORE, PET_LIGHTNING, PET_POISON }) do
        if not st.damage_id then
            for i = #group, 1, -1 do
                if NS.spell_id_is_known(group[i]) then st.damage_id = group[i]; break end
            end
        end
    end
    for _, entry in ipairs(PET_SPECIALS) do
        if not st.special_id then
            for i = #entry.ids, 1, -1 do
                if NS.spell_id_is_known(entry.ids[i]) then st.special_id = entry.ids[i]; st.special_type = entry.type; break end
            end
        end
    end
    st.pet_spells_scanned = true
end

function M.on_update(me, target, spec)
    if not me then return end
    local st = _get_state(spec or "default")
    local pet = M.get_pet(me)
    if not pet or not M.pet_alive(pet) then
        st.state = STATE_IDLE; st.last_target_guid = nil; return
    end
    M.scan_spells(st)
    local now = NS.time_now and NS.time_now() or 0
    if not target then st.state = STATE_IDLE; return end
    local ok_guid, guid = pcall(function() return target:get_guid() end)
    local guid = ok_guid and guid or nil
    if st.state == STATE_IDLE or st.last_target_guid ~= guid then
        local ok = pcall(function()
            return core and core.input and core.input.pet_attack and core.input.pet_attack(target)
        end)
        if ok then st.state = STATE_ENGAGING; st.last_target_guid = guid end
        return
    end
    if st.growl_id and now - st.last_growl > 5 then
        if M.try_cast(st.growl_id, target) then st.last_growl = now; return end
    end
    if st.damage_id and now - st.last_damage > 2 then
        if M.try_cast(st.damage_id, target) then st.last_damage = now; return end
    end
    if st.special_id and now - st.last_special > 6 then
        if M.try_cast(st.special_id, target) then st.last_special = now; return end
    end
    st.state = STATE_FIGHTING
end

function M.set_passive(delay)
    if pet_handler and type(pet_handler.set_pet_state) == "function" then
        if pet_handler.pet_state and pet_handler.pet_state.PASSIVE then
            return pcall(pet_handler.set_pet_state, pet_handler, pet_handler.pet_state.PASSIVE, delay or 0)
        end
    end
    return false
end

function M.set_aggressive(delay)
    if pet_handler and type(pet_handler.set_pet_state) == "function" then
        if pet_handler.pet_state and pet_handler.pet_state.AGGRESSIVE then
            return pcall(pet_handler.set_pet_state, pet_handler, pet_handler.pet_state.AGGRESSIVE, delay or 0)
        end
    end
    return false
end

function M.set_defensive(delay)
    if pet_handler and type(pet_handler.set_pet_state) == "function" then
        if pet_handler.pet_state and pet_handler.pet_state.DEFENSIVE then
            return pcall(pet_handler.set_pet_state, pet_handler, pet_handler.pet_state.DEFENSIVE, delay or 0)
        end
    end
    return false
end

return M
