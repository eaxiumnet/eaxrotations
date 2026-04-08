-- racial_manager.lua
-- racial_manager.lua
-- Handles racial ability cooldowns for all TBC Classic races.

local racial_manager = {}

local function pcall_bool(fn)
    local ok, result = pcall(fn)
    return ok and result == true
end

local RACIALS = {
    blood_fury   = { 20572 },
    berserking  = { 26297 },
    arcane_torrent = { 28730, 25046, 23160, 15533, 50613 },
    war_stomp    = { 20549 },
    stoneform    = { 20594 },
    shadowmeld   = { 58984, 1784 },
    escape_artist = { 20589 },
    will_of_forsaken = { 7744 },
    every_man_for_himself = { 59752 },
}

local OFFENSIVE = { blood_fury = true, berserking = true }
local resolved = {}

local function resolve(name)
    if resolved[name] then return resolved[name] end
    local ids = RACIALS[name]
    if not ids then return nil end
    for _, id in ipairs(ids) do
        if core.spell_book.is_spell_learned(id) then
            resolved[name] = id
            return id
        end
    end
    return nil
end

local function try_racial(me, name)
    local id = resolve(name)
    if not id then return false end
    if core.spell_book.get_spell_cooldown(id) > 0 then return false end
    if not core.spell_book.is_usable_spell(id) then return false end
    local _sq_ok, _sq = pcall(require, "common/modules/spell_queue")
    if _sq_ok and _sq then
        _sq:queue_spell_target_fast(id, me, 1)
        return true
    end
    if core.input.cast_target_spell then
        pcall(core.input.cast_target_spell, id, me)
    end
    return true
end

function racial_manager.try_offensive(me)
    if not me or not me:is_in_combat() then return false end
    if try_racial(me, "blood_fury")  then return true end
    if try_racial(me, "berserking")  then return true end
    return false
end

function racial_manager.try_utility(me, target)
    if not target or not target:is_valid() or not me:can_attack(target) then return false end
    if target:is_casting_spell() or target:is_channelling_spell() then
        if try_racial(me, "arcane_torrent") then return true end
    end
    if target:is_casting_spell() then
        if try_racial(me, "war_stomp") then return true end
    end
    return false
end

function racial_manager.try_defensive(me)
    if not me then return false end

    local is_rooted = pcall_bool(function() return me:is_rooted(400) end)
    local is_slowed = pcall_bool(function() return me:is_slowed(0.30, 400) end)
    if is_rooted or is_slowed then
        if try_racial(me, "escape_artist") then return true end
    end

    local is_feared   = pcall_bool(function() return me:is_feared(400) end)
    local is_charmed  = pcall_bool(function()
        local enums_ok, en = pcall(require, "common/enums")
        if enums_ok and en and en.cc_flags then
            return me:is_cc(400, en.cc_flags.CHARM)
        end
        return false
    end)
    if is_feared or is_charmed then
        if try_racial(me, "will_of_forsaken") then return true end
    end

    local has_harmful = pcall_bool(function()
        local bm_ok, bm = pcall(require, "common/modules/buff_manager")
        if not (bm_ok and bm) then return false end
        local cache = bm:get_debuff_cache(me, 60)
        local en_ok, en = pcall(require, "common/enums")
        if not (en_ok and en and en.buff_type) then return false end
        for _, aura in ipairs(cache) do
            if aura.is_active then
                if aura.buff_type == en.buff_type.POISON
                or aura.buff_type == en.buff_type.DISEASE then
                    return true
                end
            end
        end
        return false
    end)
    if has_harmful then
        if try_racial(me, "stoneform") then return true end
    end

    return false
end

function racial_manager.try_all(me, target)
    if racial_manager.try_offensive(me) then return true end
    if racial_manager.try_utility(me, target) then return true end
    if racial_manager.try_defensive(me) then return true end
    return false
end

function racial_manager.try_racial(me, name)
    return try_racial(me, name)
end

return racial_manager
