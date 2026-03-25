-- pet_manager.lua  |  Full Pet AI State Machine  |  TBC
-- State machine: IDLE -> ENGAGING -> FIGHTING -> RETREATING

local pet_manager = {}

local STATE_IDLE = 0
local STATE_ENGAGING = 1
local STATE_FIGHTING = 2
local STATE_RETREATING = 3

pet_manager.state = STATE_IDLE
pet_manager.last_target_guid = nil
pet_manager.pet_spells_scanned = false
pet_manager.last_pet_attack = 0
pet_manager.last_pet_focus_report = 0

local PET_GROWL_IDS  = { 2649, 14268, 14269, 14270, 14271, 14925 }
local PET_CLAW_IDS   = { 2981, 14261, 14262, 14263, 14264, 14265 }
local PET_BITE_IDS  = { 17253, 17254, 17255, 17256, 17257, 27050 }
local PET_GORE_IDS  = { 35290, 35291 }
local PET_HOWL_IDS  = { 24597, 24598, 24599, 24600 }
local PET_SCREECH_IDS = { 24604 }
local PET_THUNDER_IDS = { 26090, 26093 }
local PET_LIGHTNING_IDS = { 25011, 25012, 25013, 25014, 25015, 25016 }
local PET_POISON_IDS = { 24640 }

local PET_SPECIAL_PRIORITY = {
    { ids = PET_HOWL_IDS,     type = "howl" },
    { ids = PET_SCREECH_IDS,  type = "screech" },
    { ids = PET_THUNDER_IDS,  type = "thunderstomp" },
}

function pet_manager.init(state_by_spec)
    pet_manager.state_by_spec = state_by_spec or {}
end

local function get_spec_state(spec_name)
    if not pet_manager.state_by_spec then
        pet_manager.state_by_spec = {}
    end
    if not pet_manager.state_by_spec[spec_name] then
        pet_manager.state_by_spec[spec_name] = {
            state = STATE_IDLE,
            last_target_guid = nil,
            pet_spells_scanned = false,
            growl_id = nil,
            damage_id = nil,
            special_id = nil,
            special_type = nil,
            pet_focus = 100,
            last_growl = 0,
            last_damage = 0,
            last_special = 0,
            last_mend = 0,
            last_follow = 0,
        }
    end
    return pet_manager.state_by_spec[spec_name]
end

function pet_manager.get_pet(me)
    if not me then return nil end
    local ok, p = pcall(function() return me:get_pet() end)
    return (ok and p and p:is_valid()) and p or nil
end

function pet_manager.get_pet_raw(me)
    if not me then return nil end
    local ok, p = pcall(function() return me:get_pet() end)
    return ok and p or nil
end

function pet_manager.get_spec_state(spec_name)
    return get_spec_state(spec_name)
end

function pet_manager.pet_alive(p)
    return p and not p:is_dead()
end

function pet_manager.scan_pet_spells(st)
    if st.pet_spells_scanned then return end
    local list = core.spell_book.get_pet_spells()
    local known = {}
    if list and #list > 0 then
        for _, s in ipairs(list) do
            local id = type(s) == "number" and s or (type(s) == "table" and (s.spell_id or s.id) or nil)
            if id then known[id] = true end
        end
    else
        for _, group in ipairs({ PET_GROWL_IDS, PET_CLAW_IDS, PET_BITE_IDS, PET_GORE_IDS, PET_LIGHTNING_IDS, PET_HOWL_IDS, PET_SCREECH_IDS, PET_THUNDER_IDS }) do
            for _, id in ipairs(group) do
                if core.spell_book.is_spell_learned(id) then
                    known[id] = true
                end
            end
        end
    end
    for i = #PET_GROWL_IDS, 1, -1 do
        if known[PET_GROWL_IDS[i]] then st.growl_id = PET_GROWL_IDS[i]; break end
    end
    for _, group in ipairs({ PET_CLAW_IDS, PET_BITE_IDS, PET_GORE_IDS, PET_LIGHTNING_IDS, PET_POISON_IDS }) do
        if not st.damage_id then
            for i = #group, 1, -1 do
                if known[group[i]] then st.damage_id = group[i]; break end
            end
        end
    end
    for _, entry in ipairs(PET_SPECIAL_PRIORITY) do
        if not st.special_id then
            for i = #entry.ids, 1, -1 do
                if known[entry.ids[i]] then st.special_id = entry.ids[i]; st.special_type = entry.type; break end
            end
        end
    end
    st.pet_spells_scanned = true
    core.log(string.format("[Pet AI] growl=%s dmg=%s special=%s (%s)",
        tostring(st.growl_id), tostring(st.damage_id), tostring(st.special_id), tostring(st.special_type)))
end

local function dist_3d(p1, p2)
    if not p1 or not p2 then return 999 end
    local dx,dy,dz = p1.x-p2.x, p1.y-p2.y, p1.z-p2.z
    return math.sqrt(dx*dx+dy*dy+dz*dz)
end

local function get_pet_focus(pet)
    if not pet then return 100 end
    if pet.focus_current then
        local ok, f = pcall(function() return pet:focus_current() end)
        if ok and type(f) == "number" then return f end
    end
    local ok, f = pcall(function() return pet:get_power(2) end)
    return (ok and type(f) == "number" and f) or 100
end

local function try_pet_cast(spell_id, target, pet)
    if not spell_id or not target or not target:is_valid() then return false end
    if core.spell_book.get_spell_cooldown(spell_id) > 0 then return false end
    core.input.pet_cast_target_spell(spell_id, target)
    return true
end

function pet_manager.on_update(me, target, st, now, menu, utils)
    if not me then return end
    local pet = pet_manager.get_pet(me)
    if not pet then
        st.state = STATE_IDLE
        return
    end

    if not st.pet_spells_scanned then
        pet_manager.scan_pet_spells(st)
    end

    local pet_alive = pet_manager.pet_alive(pet)
    if not pet_alive then
        st.state = STATE_IDLE
        return
    end

    if me.is_moving and me:is_moving() then
        if st.state ~= STATE_IDLE then
            core.input.set_pet_follow()
            st.last_follow = now
            st.state = STATE_IDLE
        end
        return
    end

    local target_probe_ok, target_is_valid, target_is_dead, target_guid, target_pos = pcall(function()
        if not target then return false, nil, nil, nil end
        local valid = target:is_valid()
        local dead = target:is_dead()
        local guid = tostring(target:get_guid())
        local pos = target:get_position()
        return valid, dead, guid, pos
    end)
    if not target_probe_ok or not target_is_valid or target_is_dead or not target_guid then
        if st.state ~= STATE_IDLE then
            if now - st.last_follow > 1.0 then
                core.input.set_pet_follow()
                st.last_follow = now
            end
            st.state = STATE_IDLE
        end
        return
    end

    local pet_pos = pet:get_position()
    local me_pos = me:get_position()

    if not pet_pos or not target_pos or not me_pos then
        if st.state ~= STATE_IDLE then
            core.input.set_pet_follow()
            st.last_follow = now
            st.state = STATE_IDLE
        end
        return
    end

    -- Use squared distance to avoid sqrt (avoids math.sqrt overhead)
    local dx,dy,dz = pet_pos.x-target_pos.x, pet_pos.y-target_pos.y, pet_pos.z-target_pos.z
    local pet_to_target_sq = dx*dx+dy*dy+dz*dz
    st.pet_focus = get_pet_focus(pet)

    if st.state == STATE_IDLE then
        if target_is_valid and not target_is_dead then
            local pet = pet_manager.get_pet(me)
            if pet then pcall(function() pet:cast_spell(23145) end) end
            st.state = STATE_ENGAGING
            st.last_target_guid = target_guid
        end
        return
    end

    if st.last_target_guid ~= guid then
        local pet = pet_manager.get_pet(me)
        if pet then pcall(function() pet:cast_spell(23145) end) end
        st.last_target_guid = target_guid
        st.state = STATE_ENGAGING
        return
    end

    if pet_to_target_sq > 900 then  -- 30^2 = 900
        if now - st.last_follow > 1.0 then
            core.input.set_pet_follow()
            st.last_follow = now
        end
        st.state = STATE_RETREATING
        return
    end

    if pet_to_target_sq <= 25 then  -- 5^2 = 25
        st.state = STATE_FIGHTING
    else
        st.state = STATE_ENGAGING
    end

    if st.state == STATE_FIGHTING then
        if now - st.last_growl > 2.0 and st.growl_id then
            if try_pet_cast(st.growl_id, target, pet) then
                st.last_growl = now
            end
        end

        if st.pet_focus >= 20 and now - st.last_damage > 0.5 and st.damage_id then
            if try_pet_cast(st.damage_id, target, pet) then
                st.last_damage = now
            end
        end

        if st.special_id and st.special_type then
            local min_focus = 20
            if st.special_type == "howl" then
                min_focus = 25
            elseif st.special_type == "screech" then
                min_focus = 20
            elseif st.special_type == "thunderstomp" then
                min_focus = 25
            end
            if st.pet_focus >= min_focus and now - st.last_special > 1.0 then
                if try_pet_cast(st.special_id, target, pet) then
                    st.last_special = now
                end
            end
        end
    end
end

function pet_manager.try_mend(me, pet, st, rt, spells, utils, menu, now)
    if not rt.mend_pet_id then return false end
    if not pet then return false end
    if pet_manager.pet_alive(pet) then return false end
    if me.is_moving and me:is_moving() then return false end
    if core.spell_book.get_spell_cooldown(rt.mend_pet_id) > 0 then return false end
    local pet_hp = pet:get_health_percentage() or 100
    if pet_hp > 50 then return false end
    local pp = pet:get_position()
    local mp = me:get_position()
    if pp and mp then
        local dx,dy,dz = pp.x-mp.x, pp.y-mp.y, pp.z-mp.z
        if (dx*dx+dy*dy+dz*dz) > 196 then return false end  -- 14^2 = 196
    end
    if now - st.last_mend < 5.0 then return false end
    if utils.can_cast_self(rt.mend_pet_id, me) then
        if utils.cast_self(rt.mend_pet_id, me) then
            st.last_mend = now
            return true
        end
    end
    return false
end

function pet_manager.try_revive_call(me, st, rt, utils, now)
    local p = pet_manager.get_pet_raw(me)
    if pet_manager.pet_alive(p) then
        rt.revive_in_progress = false
        rt.revive_started_at = 0
        return false
    end
    if me:is_in_combat() then return false end
    if me.is_moving and me:is_moving() then return false end
    rt.revive_started_at = rt.revive_started_at or 0
    if rt.revive_in_progress and (now - rt.revive_started_at) > 12.0 then
        rt.revive_in_progress = false
    end
    if rt.revive_in_progress then return false end
    if now - st.last_mend < 5.0 then return false end
    local pet_is_dead = false
    if p and p.is_dead then
        local ok_dead, is_dead = pcall(p.is_dead, p)
        pet_is_dead = ok_dead and is_dead
    end
    if pet_is_dead and rt.revive_pet_id then
        if utils.can_cast_self(rt.revive_pet_id, me) then
            if utils.cast_self(rt.revive_pet_id, me) then
                rt.revive_in_progress = true
                rt.revive_started_at = now
                st.last_mend = now
                st.pet_spells_scanned = false
                return true
            end
        end
    end
    if (not p) and rt.call_pet_id and utils.can_cast_self(rt.call_pet_id, me) then
        if utils.cast_self(rt.call_pet_id, me) then
            rt.revive_in_progress = true
            rt.revive_started_at = now
            st.last_mend = now
            st.pet_spells_scanned = false
            return true
        end
    end
    return false
end

function pet_manager.pet_attack(me, target, st, now)
    if not target or not target:is_valid() then return end
    if me.is_moving and me:is_moving() then return end
    local ok, guid = pcall(function() return tostring(target:get_guid()) end)
    if not ok or not guid then return end
    if st.last_target_guid == guid then return end
    st.last_target_guid = guid
    local pet = pet_manager.get_pet(me)
    if pet then
        pcall(function() pet:cast_spell(23145) end)
    end
end

function pet_manager.set_defensive(me, st, now)
    if now - st.last_follow > 2.0 then
        core.input.set_pet_defensive()
        st.last_follow = now
    end
end

function pet_manager.get_state_name(state)
    if state == STATE_IDLE then return "IDLE"
    elseif state == STATE_ENGAGING then return "ENGAGING"
    elseif state == STATE_FIGHTING then return "FIGHTING"
    elseif state == STATE_RETREATING then return "RETREATING" end
    return "UNKNOWN"
end

return pet_manager
