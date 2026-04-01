-- pvp_manager.lua
-- Shared PvP detection, targeting, and cooldown management for arena/BG/world PvP.

local pvp_manager = {}

-- --- PvP Detection -----------------------------------------------------------

function pvp_manager.is_in_pvp_instance()
    -- Check if we're in an arena or battleground
    local ok, in_arena = pcall(function()
        return IsActiveBattlefieldArena and IsActiveBattlefieldArena()
    end)
    if ok and in_arena then return "arena" end

    local ok2, in_bg = pcall(function()
        return GetBattlefieldStatus and true
    end)
    if ok2 and in_bg then return "battleground" end

    return nil
end

function pvp_manager.is_world_pvp(me)
    if not me or not me:is_valid() then return false end
    local ok, is_pvp = pcall(function() return me:is_pvp() end)
    return ok and is_pvp
end

-- --- Enemy Player Targeting --------------------------------------------------

function pvp_manager.find_enemy_players(me, radius)
    radius = radius or 40
    local players = {}
    local objects = core.object_manager.get_all_objects()
    local me_pos = me.get_position and me:get_position()
    local radius_sq = radius * radius

    for _, obj in ipairs(objects) do
        if obj and obj:is_valid() and obj:is_unit() and obj:is_player()
            and not obj:is_dead() and me:can_attack(obj) then
            -- Check range
            if me_pos and obj.get_position then
                local obj_pos = obj:get_position()
                if obj_pos then
                    local dx = me_pos.x - obj_pos.x
                    local dy = me_pos.y - obj_pos.y
                    local dz = me_pos.z - obj_pos.z
                    if (dx * dx + dy * dy + dz * dz) <= radius_sq then
                        table.insert(players, obj)
                    end
                end
            else
                table.insert(players, obj)
            end
        end
    end
    return players
end

function pvp_manager.priority_target(me, players)
    -- Priority: Healers > Casters > Melee
    -- Role: 0=tank, 1=healer, 2=dps, 3=unknown
    local healer = nil
    local caster = nil
    local melee = nil

    for _, p in ipairs(players) do
        local role = p.get_group_role and p:get_group_role() or 3
        local class = p.get_class and p:get_class() or nil

        -- Healer priority
        if role == 1 then
            healer = p
            break
        end

        -- Caster detection (classes that are typically casters)
        if class and (class == "MAGE" or class == "WARLOCK" or class == "PRIEST" or class == "DRUID") then
            if not caster then caster = p end
        else
            if not melee then melee = p end
        end
    end

    return healer or caster or melee or (players[1])
end

-- --- CC Tracking -------------------------------------------------------------

local CC_SPELL_IDS = {
    -- Polymorph
    118, 12824, 12825, 12826,
    -- Fear
    5782, 6213, 6215,
    -- Sap
    6770, 2070, 11297,
    -- Blind
    2094,
    -- Gouge
    1776,
    -- Cyclone
    33786,
    -- Hex
    51514,
    -- Freezing Trap
    3355,
    -- Scatter Shot
    19503,
    -- Mind Control
    605,
    -- Shackle Undead
    9484,
    -- Banish
    710,
    -- Seduction
    6358,
}

function pvp_manager.is_cced(unit)
    if not unit or not unit:is_valid() then return false end
    for _, cc_id in ipairs(CC_SPELL_IDS) do
        if unit.has_buff and unit:has_buff(cc_id) then
            return true
        end
    end
    return false
end

-- --- PvP Cooldowns -----------------------------------------------------------

function pvp_manager.should_use_pvp_trinket(me)
    if not me or not me:is_valid() then return false end
    -- Use trinket when CCed
    if pvp_manager.is_cced(me) then return true end
    return false
end

function pvp_manager.should_use_defensive_cd(me, target)
    if not me or not me:is_valid() then return false end
    local hp = me.get_health_percentage and me:get_health_percentage() or 100
    -- Use defensive CD when HP < 40% and being attacked
    if hp < 40 then
        local attackers = 0
        local objects = core.object_manager.get_all_objects()
        for _, obj in ipairs(objects) do
            if obj and obj:is_valid() and obj:is_unit() and obj:is_player()
                and me:can_attack(obj) then
                local t = obj.get_target and obj:get_target()
                if t and t == me then
                    attackers = attackers + 1
                end
            end
        end
        if attackers >= 1 then return true end
    end
    return false
end

return pvp_manager
