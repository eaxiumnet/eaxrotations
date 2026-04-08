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

-- --- Arena/BG Awareness ------------------------------------------------------

function pvp_manager.get_arena_size()
    local ok, size = pcall(function()
        if GetNumBattlefieldScores then
            local scores = GetNumBattlefieldScores()
            if scores and scores > 0 then return "battleground" end
        end
        if IsActiveBattlefieldArena then
            return IsActiveBattlefieldArena() and "arena" or nil
        end
        return nil
    end)
    return ok and size or nil
end

function pvp_manager.get_bg_objectives()
    -- Returns table of BG objectives (flags, nodes, etc.)
    local objectives = {}
    local ok, result = pcall(function()
        if GetBattlefieldTeamInfo then
            local _, ally_score, _, enemy_score = GetBattlefieldTeamInfo(0)
            objectives.ally_score = ally_score or 0
            objectives.enemy_score = enemy_score or 0
        end
        if GetNumBattlefieldScores then
            local num = GetNumBattlefieldScores()
            objectives.player_count = num or 0
        end
    end)
    return ok and objectives or {}
end

function pvp_manager.is_flag_carrier(unit)
    if not unit or not unit:is_valid() then return false end
    -- Check for flag carrier buffs (WG, AB, EotS)
    local flag_buffs = {
        23333, -- Warsong Flag
        23335, -- Silverwing Flag
        34976, -- Netherstorm Flag
        12345, -- Arathi Basin resources
    }
    for _, buff_id in ipairs(flag_buffs) do
        if unit.has_buff and unit:has_buff(buff_id) then
            return true
        end
    end
    return false
end

-- --- Spec-Specific PvP Cooldowns ---------------------------------------------

-- Rogue PvP cooldowns
function pvp_manager.try_rogue_pvp_cooldowns(me, target)
    if not me or not me:is_valid() or not target then return false end
    local hp = me.get_health_percentage and me:get_health_percentage() or 100
    local target_hp = target.get_health_percentage and target:get_health_percentage() or 100

    -- Evasion when HP < 30% and being attacked by players
    if hp < 30 then
        local evasion_id = 5277
        if core.spell_book.is_usable_spell(evasion_id) then
            core.input.cast_target_spell(evasion_id, me)
            return true
        end
    end

    -- Cloak of Shadows when CCed or low HP
    if hp < 40 or pvp_manager.is_cced(me) then
        local cloak_id = 31224
        if core.spell_book.is_usable_spell(cloak_id) then
            core.input.cast_target_spell(cloak_id, me)
            return true
        end
    end

    -- Vanish when HP < 20%
    if hp < 20 then
        local vanish_id = 1856
        if core.spell_book.is_usable_spell(vanish_id) then
            core.input.cast_target_spell(vanish_id, me)
            return true
        end
    end

    return false
end

-- Warrior PvP cooldowns
function pvp_manager.try_warrior_pvp_cooldowns(me, target)
    if not me or not me:is_valid() or not target then return false end
    local hp = me.get_health_percentage and me:get_health_percentage() or 100

    -- Berserker Rage when feared/rooted
    if pvp_manager.is_cced(me) then
        local berserker_rage_id = 18499
        if core.spell_book.is_usable_spell(berserker_rage_id) then
            core.input.cast_target_spell(berserker_rage_id, me)
            return true
        end
    end

    -- Shield Wall when HP < 30%
    if hp < 30 then
        local shield_wall_id = 871
        if core.spell_book.is_usable_spell(shield_wall_id) then
            core.input.cast_target_spell(shield_wall_id, me)
            return true
        end
    end

    -- Last Stand when HP < 25%
    if hp < 25 then
        local last_stand_id = 12975
        if core.spell_book.is_usable_spell(last_stand_id) then
            core.input.cast_target_spell(last_stand_id, me)
            return true
        end
    end

    return false
end

-- Mage PvP cooldowns
function pvp_manager.try_mage_pvp_cooldowns(me, target)
    if not me or not me:is_valid() or not target then return false end
    local hp = me.get_health_percentage and me:get_health_percentage() or 100

    -- Ice Block when HP < 20% or CCed
    if hp < 20 or pvp_manager.is_cced(me) then
        local ice_block_id = 45438
        if core.spell_book.is_usable_spell(ice_block_id) then
            core.input.cast_target_spell(ice_block_id, me)
            return true
        end
    end

    -- Blink when rooted or HP < 30%
    if hp < 30 then
        local blink_id = 1953
        if core.spell_book.is_usable_spell(blink_id) then
            core.input.cast_target_spell(blink_id, me)
            return true
        end
    end

    return false
end

-- Druid PvP cooldowns
function pvp_manager.try_druid_pvp_cooldowns(me, target)
    if not me or not me:is_valid() or not target then return false end
    local hp = me.get_health_percentage and me:get_health_percentage() or 100

    -- Barkskin when HP < 40%
    if hp < 40 then
        local barkskin_id = 22812
        if core.spell_book.is_usable_spell(barkskin_id) then
            core.input.cast_target_spell(barkskin_id, me)
            return true
        end
    end

    -- Nature's Swiftness + Healing Touch when HP < 30%
    if hp < 30 then
        local ns_id = 17116
        if core.spell_book.is_usable_spell(ns_id) then
            core.input.cast_target_spell(ns_id, me)
            return true
        end
    end

    return false
end

-- Priest PvP cooldowns
function pvp_manager.try_priest_pvp_cooldowns(me, target)
    if not me or not me:is_valid() or not target then return false end
    local hp = me.get_health_percentage and me:get_health_percentage() or 100

    -- Pain Suppression when HP < 35%
    if hp < 35 then
        local ps_id = 33206
        if core.spell_book.is_usable_spell(ps_id) then
            core.input.cast_target_spell(ps_id, me)
            return true
        end
    end

    -- Dispersion when HP < 25%
    if hp < 25 then
        local dispersion_id = 47585
        if core.spell_book.is_usable_spell(dispersion_id) then
            core.input.cast_target_spell(dispersion_id, me)
            return true
        end
    end

    return false
end

-- Paladin PvP cooldowns
function pvp_manager.try_paladin_pvp_cooldowns(me, target)
    if not me or not me:is_valid() or not target then return false end
    local hp = me.get_health_percentage and me:get_health_percentage() or 100

    -- Divine Shield when HP < 20%
    if hp < 20 then
        local ds_id = 642
        if core.spell_book.is_usable_spell(ds_id) then
            core.input.cast_target_spell(ds_id, me)
            return true
        end
    end

    -- Blessing of Protection when HP < 30%
    if hp < 30 then
        local bop_id = 1022
        if core.spell_book.is_usable_spell(bop_id) then
            core.input.cast_target_spell(bop_id, me)
            return true
        end
    end

    return false
end

-- Shaman PvP cooldowns
function pvp_manager.try_shaman_pvp_cooldowns(me, target)
    if not me or not me:is_valid() or not target then return false end
    local hp = me.get_health_percentage and me:get_health_percentage() or 100

    -- Shamanistic Rage when HP < 40%
    if hp < 40 then
        local sr_id = 30823
        if core.spell_book.is_usable_spell(sr_id) then
            core.input.cast_target_spell(sr_id, me)
            return true
        end
    end

    -- Wind Shear (interrupt) on caster targets
    if target then
        local class = target.get_class and target:get_class() or nil
        if class and (class == "MAGE" or class == "WARLOCK" or class == "PRIEST") then
            local ws_id = 57994
            if core.spell_book.is_usable_spell(ws_id) then
                core.input.cast_target_spell(ws_id, me)
                return true
            end
        end
    end

    return false
end

-- Warlock PvP cooldowns
function pvp_manager.try_warlock_pvp_cooldowns(me, target)
    if not me or not me:is_valid() or not target then return false end
    local hp = me.get_health_percentage and me:get_health_percentage() or 100

    -- Death Coil when HP < 35%
    if hp < 35 then
        local dc_id = 6789
        if core.spell_book.is_usable_spell(dc_id) then
            core.input.cast_target_spell(dc_id, me)
            return true
        end
    end

    -- Fear when being attacked by multiple players
    if hp < 50 then
        local fear_id = 5782
        if core.spell_book.is_usable_spell(fear_id) then
            core.input.cast_target_spell(fear_id, me)
            return true
        end
    end

    return false
end

-- Hunter PvP cooldowns
function pvp_manager.try_hunter_pvp_cooldowns(me, target)
    if not me or not me:is_valid() or not target then return false end
    local hp = me.get_health_percentage and me:get_health_percentage() or 100

    -- Deterrence when HP < 30%
    if hp < 30 then
        local det_id = 19263
        if core.spell_book.is_usable_spell(det_id) then
            core.input.cast_target_spell(det_id, me)
            return true
        end
    end

    -- Disengage when rooted or HP < 40%
    if hp < 40 then
        local disengage_id = 781
        if core.spell_book.is_usable_spell(disengage_id) then
            core.input.cast_target_spell(disengage_id, me)
            return true
        end
    end

    return false
end

-- --- Arena/BG-Specific Logic -------------------------------------------------

-- Arena 2v2/3v3 focus fire coordination
function pvp_manager.get_arena_focus_target(me, enemy_players)
    if not enemy_players or #enemy_players == 0 then return nil end
    -- In arena, focus the lowest HP enemy player
    local lowest_hp = nil
    local lowest_target = nil
    for _, p in ipairs(enemy_players) do
        local hp = p.get_health_percentage and p:get_health_percentage() or 100
        if not lowest_hp or hp < lowest_hp then
            lowest_hp = hp
            lowest_target = p
        end
    end
    return lowest_target
end

-- Battleground: flag carrier priority
function pvp_manager.get_flag_carrier_target(me, enemy_players)
    if not enemy_players or #enemy_players == 0 then return nil end
    for _, p in ipairs(enemy_players) do
        if pvp_manager.is_flag_carrier(p) then
            return p
        end
    end
    return nil
end

-- Battleground: node defense awareness
function pvp_manager.should_defend_node(me)
    local objectives = pvp_manager.get_bg_objectives()
    -- If enemy score is close to winning, prioritize defense
    if objectives.enemy_score and objectives.enemy_score >= 1500 then
        return true
    end
    return false
end

-- Arena: CC chain coordination
function pvp_manager.get_cc_chain_info(me, target)
    if not target or not target:is_valid() then return nil end
    local cc_remaining = 0
    for _, cc_id in ipairs(CC_SPELL_IDS) do
        local remaining = target.get_buff_remaining_ms and target:get_buff_remaining_ms(cc_id) or 0
        if remaining > 0 then
            cc_remaining = math.max(cc_remaining, remaining)
        end
    end
    return {
        is_cced = cc_remaining > 0,
        remaining_ms = cc_remaining,
    }
end

-- Arena: burst window coordination
function pvp_manager.should_burst_target(me, target)
    if not target or not target:is_valid() then return false end
    local hp = target.get_health_percentage and target:get_health_percentage() or 100
    -- Burst when target is below 35% HP
    if hp < 35 then return true end
    -- Burst when target is CCed
    if pvp_manager.is_cced(target) then return true end
    return false
end

-- Arena: defensive positioning
function pvp_manager.should_reposition(me, target)
    if not me or not me:is_valid() then return false end
    local hp = me.get_health_percentage and me:get_health_percentage() or 100
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
    -- Reposition when attacked by 2+ players and HP < 50%
    if attackers >= 2 and hp < 50 then return true end
    return false
end

return pvp_manager
