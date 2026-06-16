-- What: Detects buff rank mismatches and triggers upgrades for self + party.
-- When: Called from OOC manager after self-buffs, before food/flask.
-- Why: OOC manager only refreshes on duration; never upgrades to a higher rank.
-- Safety: OOC-only, throttled per-spell, no combat casts.

local NS = _G.EaxRotations
if not NS then return nil end

local CLASS = NS.CLASS_ID or {
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
    SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11,
}

-- Party buff definitions by class. Arrays are high-to-low rank.
-- Each entry: { ids = <rank array>, key = <setting suffix> }
-- Paladin blessings skipped — already handled by paladin middleware.
local PARTY_BUFFS_BY_CLASS = {
    [CLASS.PRIEST] = {
        { ids = { 25389, 10938, 10937, 2791, 1245, 1244, 1243 }, key = "fort" },
        { ids = { 25433, 10958, 10957, 976 },                     key = "shadow_prot" },
    },
    [CLASS.MAGE] = {
        { ids = { 27126, 10157, 10156, 1461, 1460, 1459 }, key = "ai" },
    },
    [CLASS.DRUID] = {
        { ids = { 26991, 26990, 9885, 9884, 8907, 6756, 5234, 5232, 1126 }, key = "motw" },
        { ids = { 26992, 9910, 9756, 8914, 1075, 782, 467 },                key = "thorns" },
    },
}

-- Static spell cache: key -> spell_action object. Built once per class load.
local _spell_cache = {}

local function get_spell(entry)
    local key = entry.key
    if _spell_cache[key] then return _spell_cache[key] end
    local spell = NS.spell_action(entry.ids)
    _spell_cache[key] = spell
    return spell
end

-- Returns true if the active buff on `unit` is a lower rank than what we can cast.
-- Also returns true if no buff is active and we can cast the highest rank.
local function needs_upgrade(unit, entry)
    local ids = entry.ids
    local active_id, rank_pos = NS.buff_rank(unit, ids)
    if not active_id then
        -- No buff active — not an upgrade situation (OOC manager handles fresh buffs)
        return false
    end
    -- rank_pos > 1 means active buff is not the highest rank
    return rank_pos ~= nil and rank_pos > 1
end

-- Check self for buff rank upgrades.
local function check_self_buffs(context, settings, me, class_id)
    local entries = PARTY_BUFFS_BY_CLASS[class_id]
    if not entries then return false end

    for i = 1, #entries do
        local entry = entries[i]
        if needs_upgrade(me, entry) then
            local spell = get_spell(entry)
            if spell and NS.spell_ready(spell, me, { skip_range = true }) then
                if NS.broken_api_throttled and NS.broken_api_throttled(spell, 3.0) then
                    -- API unhealthy, skip
                else
                    if NS.try_cast(spell, me, "[BUFF_UP] self " .. entry.key) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- Check party members for buff rank upgrades.
local function check_party_buffs(context, settings, me, class_id)
    local entries = PARTY_BUFFS_BY_CLASS[class_id]
    if not entries then return false end

    local members = NS.GetPartyMembers()
    if type(members) ~= "table" then return false end

    for mi = 1, #members do
        local member = members[mi]
        if member and member.is_alive and member:is_alive() then
            for ei = 1, #entries do
                local entry = entries[ei]
                if needs_upgrade(member, entry) then
                    local spell = get_spell(entry)
                    if spell and NS.spell_ready(spell, member, { skip_range = true }) then
                        if NS.broken_api_throttled and NS.broken_api_throttled(spell, 3.0) then
                            -- API unhealthy, skip
                        else
                            if NS.try_cast(spell, member, "[BUFF_UP] party " .. entry.key) then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end

-- Entry point called from OOC manager.
-- Returns true if an upgrade cast was initiated.
local function try_buff_upgrades(context, settings, me)
    if not me then return false end
    local class_id = me.get_class_id and me:get_class_id() or 0
    if check_self_buffs(context, settings, me, class_id) then return true end
    if check_party_buffs(context, settings, me, class_id) then return true end
    return false
end

return {
    try_buff_upgrades = try_buff_upgrades,
    needs_upgrade = needs_upgrade,
    PARTY_BUFFS_BY_CLASS = PARTY_BUFFS_BY_CLASS,
}
