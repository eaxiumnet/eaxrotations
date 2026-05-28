local izi = require("common/izi_sdk")

local SPELL = {
    Stealth       = izi.spell(1787, 1786, 1785, 1784),
    Kick          = izi.spell(38768, 1769, 1768, 1767, 1766),
    AdrenalineRush = izi.spell(13750),
    BladeFlurry   = izi.spell(13877),
    SliceAndDice  = izi.spell(6774, 5171),
    Rupture       = izi.spell(26867, 11275, 11274, 11273, 8640, 8639, 1943),
    Eviscerate    = izi.spell(31016, 26865, 11300, 11299, 8624, 8623, 6762, 6761, 6760, 2098),
    ExposeArmor   = izi.spell(26866, 11198, 11197, 8650, 8649, 8647),
    SinisterStrike= izi.spell(26862, 26861, 11294, 11293, 8621, 1760, 1759, 1758, 1757, 1752),
    Gouge         = izi.spell(38764, 11286, 11285, 8629, 1777, 1776),
    Feint         = izi.spell(27448, 25302, 11303, 8637, 6768, 1966),
    Evasion       = izi.spell(26669, 5277),
    Vanish        = izi.spell(26889, 1857, 1856),
}

local STEALTH = { 1787, 1786, 1785, 1784 }
local SND = { 6774, 5171 }
local RUPTURE = { 26867, 11275, 11274, 11273, 8640, 8639, 1943 }
local ADRENALINE_RUSH = { 13750 }
local BLADE_FLURRY = { 13877 }

local M = {}

local function combo(me)
    if me.combo_points_current then return me:combo_points_current() or 0 end
    if me.get_power then return me:get_power() or 0 end
    return 0
end

function M.tick(me, target, enemies)
    if not me:is_in_combat() then return false end
    local hp = me:get_health_percentage() or 100
    if hp < 30 and SPELL.Vanish:cast_safe(me) then return true end
    if hp < 40 and SPELL.Evasion:cast_safe(me) then return true end
    if not target then return false end
    if target:is_casting() and SPELL.Kick:cast_safe(target) then return true end

    if me:buff_down(ADRENALINE_RUSH) and SPELL.AdrenalineRush:is_learned() then
        if SPELL.AdrenalineRush:cast_safe(me) then return true end
    end
    if me:buff_down(BLADE_FLURRY) and SPELL.BladeFlurry:is_learned() then
        if SPELL.BladeFlurry:cast_safe(me) then return true end
    end

    local cp = combo(me)
    if cp >= 2 and me:buff_down(SND) then
        if SPELL.SliceAndDice:cast_safe(me) then return true end
    end
    if cp >= 5 and target:debuff_remains(RUPTURE) < 3 then
        if SPELL.Rupture:cast_safe(target) then return true end
    end
    if cp >= 5 and SPELL.Eviscerate:cast_safe(target) then return true end
    if cp >= 3 and SPELL.ExposeArmor:cast_safe(target) then return true end
    if target:is_casting() and SPELL.Gouge:cast_safe(target) then return true end
    if hp < 70 and SPELL.Feint:cast_safe(me) then return true end
    if me:buff_up(STEALTH) then return false end
    if SPELL.SinisterStrike:cast_safe(target) then return true end

    return false
end

return M
