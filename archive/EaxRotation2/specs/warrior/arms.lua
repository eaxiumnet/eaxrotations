local izi = require("common/izi_sdk")

local SPELL = {
    MortalStrike       = izi.spell(30330, 25248, 21553, 21552, 21551, 12294),
    Execute            = izi.spell(25236, 25234, 20662, 20661, 20660, 20658, 5308),
    Overpower          = izi.spell(11585, 7887, 7384),
    Rend               = izi.spell(25208, 11574, 11573, 6548, 6547, 772),
    Slam               = izi.spell(25242, 25241, 11605, 11604, 8820, 1464),
    Whirlwind          = izi.spell(1680),
    HeroicStrike       = izi.spell(30324, 29707, 25286, 11567, 11566, 11565, 11564, 1608, 285, 284, 78),
    Cleave             = izi.spell(25231, 20569, 11609, 11608, 7369, 845),
    BattleShout        = izi.spell(2048, 25289, 11551, 11550, 11549, 6192, 5242, 6673),
    SweepingStrikes    = izi.spell(12328),
    DeathWish          = izi.spell(12292),
    Recklessness       = izi.spell(1719),
    Bloodrage          = izi.spell(2687),
    Pummel             = izi.spell(6554, 6552),
}

local BATTLE_SHOUT_BUFF = { 2048, 25289, 11551, 11550, 11549, 6192, 5242, 6673 }
local SWEEPING_STRIKES_BUFF = { 12328 }
local DEATH_WISH_BUFF = { 12292 }
local RECKLESSNESS_BUFF = { 1719 }
local REND_DEBUFF = { 25208, 11574, 11573, 6548, 6547, 772 }

local M = {}

function M.tick(me, target, enemies)
    if not me:is_in_combat() then return false end
    local rage = me:get_power(1) or 0

    if rage >= 10 and me:buff_down(BATTLE_SHOUT_BUFF) then
        if SPELL.BattleShout:cast_safe(me) then return true end
    end

    if target and target:is_casting() then
        if SPELL.Pummel:cast_safe(target) then return true end
    end

    if target then
        local hp = target:get_health_percentage() or 100
        if rage < 20 then
            if SPELL.Bloodrage:cast_safe(me) then return true end
        end
        if rage >= 30 and me:buff_down(SWEEPING_STRIKES_BUFF) then
            if SPELL.SweepingStrikes:cast_safe(me) then return true end
        end
        if rage >= 10 and me:buff_down(DEATH_WISH_BUFF) then
            if SPELL.DeathWish:cast_safe(me) then return true end
        end
        if hp < 20 and rage >= 15 then
            if SPELL.Execute:cast_safe(target) then return true end
        end
        if rage >= 30 then
            if SPELL.MortalStrike:cast_safe(target) then return true end
        end
        if rage >= 5 then
            if SPELL.Overpower:cast_safe(target) then return true end
        end
        if hp > 25 and target:debuff_remains(REND_DEBUFF) < 3 and rage >= 10 then
            if SPELL.Rend:cast_safe(target) then return true end
        end
        if rage >= 25 then
            if SPELL.Whirlwind:cast_safe(target) then return true end
        end
        if rage >= 15 then
            if SPELL.Slam:cast_safe(target) then return true end
        end
        if rage >= 60 then
            if SPELL.HeroicStrike:cast_safe(target) then return true end
        end
        if rage >= 55 then
            if SPELL.Cleave:cast_safe(target) then return true end
        end
        if me:buff_down(RECKLESSNESS_BUFF) then
            if SPELL.Recklessness:cast_safe(me) then return true end
        end
    end

    return false
end

return M
