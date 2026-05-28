local izi = require("common/izi_sdk")

local SPELL = {
    ShieldSlam         = izi.spell(30356, 25258, 23925, 23924, 23923, 23922),
    Devastate          = izi.spell(30022, 30016, 20243),
    SunderArmor        = izi.spell(25225, 11597, 11596, 8380, 7405, 7386),
    Revenge            = izi.spell(30357, 25269, 25288, 11601, 11600, 7379, 6574, 6572),
    ShieldBlock        = izi.spell(2565),
    ShieldBash         = izi.spell(1672, 1671, 72),
    Execute            = izi.spell(25236, 25234, 20662, 20661, 20660, 20658, 5308),
    HeroicStrike       = izi.spell(30324, 29707, 25286, 11567, 11566, 11565, 11564, 1608, 285, 284, 78),
    Cleave             = izi.spell(25231, 20569, 11609, 11608, 7369, 845),
    DemoralizingShout  = izi.spell(25203, 25202, 11556, 11555, 11554, 6190, 1160),
    ThunderClap        = izi.spell(25264, 11581, 11580, 8205, 8204, 8198, 6343),
    BattleShout        = izi.spell(2048, 25289, 11551, 11550, 11549, 6192, 5242, 6673),
    LastStand          = izi.spell(12975),
    ShieldWall         = izi.spell(871),
    Bloodrage          = izi.spell(2687),
}

local BATTLE_SHOUT_BUFF = { 2048, 25289, 11551, 11550, 11549, 6192, 5242, 6673 }
local SHIELD_BLOCK_BUFF = { 2565 }
local LAST_STAND_BUFF = { 12975 }
local SHIELD_WALL_BUFF = { 871 }
local SUNDER_DEBUFF = { 25225, 11597, 11596, 8380, 7405, 7386 }
local DEMO_SHOUT_DEBUFF = { 25203, 25202, 11556, 11555, 11554, 6190, 1160 }
local THUNDER_CLAP_DEBUFF = { 25264, 11581, 11580, 8205, 8204, 8198, 6343 }

local M = {}

function M.tick(me, target, enemies)
    if not me:is_in_combat() then return false end
    local rage = me:get_power(1) or 0
    local hp = me:get_health_percentage() or 100

    if rage >= 10 and me:buff_down(BATTLE_SHOUT_BUFF) then
        if SPELL.BattleShout:cast_safe(me) then return true end
    end
    if hp < 35 and me:buff_down(SHIELD_WALL_BUFF) then
        if SPELL.ShieldWall:cast_safe(me) then return true end
    end
    if hp < 35 and me:buff_down(LAST_STAND_BUFF) then
        if SPELL.LastStand:cast_safe(me) then return true end
    end
    if rage >= 10 and me:buff_down(SHIELD_BLOCK_BUFF) then
        if SPELL.ShieldBlock:cast_safe(me) then return true end
    end

    if target and target:is_casting() then
        if SPELL.ShieldBash:cast_safe(target) then return true end
    end

    if target then
        local target_hp = target:get_health_percentage() or 100
        if rage < 20 then
            if SPELL.Bloodrage:cast_safe(me) then return true end
        end
        if rage >= 20 then
            if SPELL.ShieldSlam:cast_safe(target) then return true end
        end
        if rage >= 5 then
            if SPELL.Revenge:cast_safe(target) then return true end
        end
        if target:debuff_down(SUNDER_DEBUFF) and rage >= 15 then
            if SPELL.SunderArmor:cast_safe(target) then return true end
        end
        if target:debuff_remains(SUNDER_DEBUFF) > 0 and rage >= 15 then
            if SPELL.Devastate:cast_safe(target) then return true end
        end
        if target_hp < 20 and rage >= 15 then
            if SPELL.Execute:cast_safe(target) then return true end
        end
        if target:debuff_remains(THUNDER_CLAP_DEBUFF) < 3 and rage >= 20 then
            if SPELL.ThunderClap:cast_safe(me) then return true end
        end
        if target:debuff_remains(DEMO_SHOUT_DEBUFF) < 5 and rage >= 10 then
            if SPELL.DemoralizingShout:cast_safe(me) then return true end
        end
        if rage >= 70 then
            if SPELL.HeroicStrike:cast_safe(target) then return true end
        end
        if rage >= 60 then
            if SPELL.Cleave:cast_safe(target) then return true end
        end
    end

    return false
end

return M
