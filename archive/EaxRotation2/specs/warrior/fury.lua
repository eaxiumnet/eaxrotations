local izi = require("common/izi_sdk")

local SPELL = {
    Bloodthirst        = izi.spell(30335, 25251, 23894, 23893, 23892, 23881),
    Whirlwind          = izi.spell(1680),
    Execute            = izi.spell(25236, 25234, 20662, 20661, 20660, 20658, 5308),
    Rampage            = izi.spell(30033, 30030, 29801),
    HeroicStrike       = izi.spell(30324, 29707, 25286, 11567, 11566, 11565, 11564, 1608, 285, 284, 78),
    Cleave             = izi.spell(25231, 20569, 11609, 11608, 7369, 845),
    BattleShout        = izi.spell(2048, 25289, 11551, 11550, 11549, 6192, 5242, 6673),
    BerserkerRage      = izi.spell(18499),
    DeathWish          = izi.spell(12292),
    Recklessness       = izi.spell(1719),
    Bloodrage          = izi.spell(2687),
    Pummel             = izi.spell(6554, 6552),
    SunderArmor        = izi.spell(25225, 11597, 11596, 8380, 7405, 7386),
}

local BATTLE_SHOUT_BUFF = { 2048, 25289, 11551, 11550, 11549, 6192, 5242, 6673 }
local BERSERKER_RAGE_BUFF = { 18499 }
local DEATH_WISH_BUFF = { 12292 }
local RECKLESSNESS_BUFF = { 1719 }
local RAMPAGE_BUFF = { 30033, 30030, 29801 }
local SUNDER_DEBUFF = { 25225, 11597, 11596, 8380, 7405, 7386 }

local M = {}

function M.tick(me, target, enemies)
    if not me:is_in_combat() then return false end
    local rage = me:get_power(1) or 0

    if rage >= 10 and me:buff_down(BATTLE_SHOUT_BUFF) then
        if SPELL.BattleShout:cast_safe(me) then return true end
    end
    if me:buff_down(BERSERKER_RAGE_BUFF) then
        if SPELL.BerserkerRage:cast_safe(me) then return true end
    end

    if target and target:is_casting() then
        if SPELL.Pummel:cast_safe(target) then return true end
    end

    if target then
        local hp = target:get_health_percentage() or 100
        if rage < 20 then
            if SPELL.Bloodrage:cast_safe(me) then return true end
        end
        if rage >= 10 and me:buff_down(DEATH_WISH_BUFF) then
            if SPELL.DeathWish:cast_safe(me) then return true end
        end
        if hp < 35 and me:buff_down(RECKLESSNESS_BUFF) then
            if SPELL.Recklessness:cast_safe(me) then return true end
        end
        if rage >= 30 and me:buff_down(RAMPAGE_BUFF) then
            if SPELL.Rampage:cast_safe(me) then return true end
        end
        if hp < 20 and rage >= 15 then
            if SPELL.Execute:cast_safe(target) then return true end
        end
        if rage >= 30 then
            if SPELL.Bloodthirst:cast_safe(target) then return true end
        end
        if rage >= 25 then
            if SPELL.Whirlwind:cast_safe(target) then return true end
        end
        if target:debuff_down(SUNDER_DEBUFF) and rage >= 15 then
            if SPELL.SunderArmor:cast_safe(target) then return true end
        end
        if rage >= 60 then
            if SPELL.HeroicStrike:cast_safe(target) then return true end
        end
        if rage >= 55 then
            if SPELL.Cleave:cast_safe(target) then return true end
        end
    end

    return false
end

return M
