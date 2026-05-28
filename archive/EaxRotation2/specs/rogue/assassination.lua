local izi = require("common/izi_sdk")

local SPELL = {
    Stealth       = izi.spell(1787, 1786, 1785, 1784),
    Garrote       = izi.spell(26884, 26839, 11290, 11289, 8633, 8632, 8631, 703),
    CheapShot     = izi.spell(1833),
    Kick          = izi.spell(38768, 1769, 1768, 1767, 1766),
    ColdBlood     = izi.spell(14177),
    SliceAndDice  = izi.spell(6774, 5171),
    Rupture       = izi.spell(26867, 11275, 11274, 11273, 8640, 8639, 1943),
    Envenom       = izi.spell(32684, 32645),
    Eviscerate    = izi.spell(31016, 26865, 11300, 11299, 8624, 8623, 6762, 6761, 6760, 2098),
    Mutilate      = izi.spell(34413, 34412, 34411, 1329),
    Shiv          = izi.spell(5938),
    SinisterStrike= izi.spell(26862, 26861, 11294, 11293, 8621, 1760, 1759, 1758, 1757, 1752),
    Evasion       = izi.spell(26669, 5277),
    CloakOfShadows= izi.spell(31224),
}

local STEALTH = { 1787, 1786, 1785, 1784 }
local SND = { 6774, 5171 }
local RUPTURE = { 26867, 11275, 11274, 11273, 8640, 8639, 1943 }
local GARROTE = { 26884, 26839, 11290, 11289, 8633, 8632, 8631, 703 }
local DEADLY_POISON = { 27187, 27186, 26968, 26967, 25349, 25347, 11354, 11356, 11353, 11355, 2819, 2837, 2818, 2835 }

local M = {}

local function combo(me)
    if me.combo_points_current then return me:combo_points_current() or 0 end
    if me.get_power then return me:get_power() or 0 end
    return 0
end

function M.tick(me, target, enemies)
    if not me:is_in_combat() then return false end
    local hp = me:get_health_percentage() or 100
    if hp < 30 and SPELL.CloakOfShadows:cast_safe(me) then return true end
    if hp < 35 and SPELL.Evasion:cast_safe(me) then return true end
    if not target then return false end
    if target:is_casting() and SPELL.Kick:cast_safe(target) then return true end

    local cp = combo(me)
    if me:buff_up(STEALTH) and target:debuff_down(GARROTE) then
        if SPELL.Garrote:cast_safe(target) then return true end
        if SPELL.CheapShot:cast_safe(target) then return true end
    end
    if cp >= 5 and SPELL.ColdBlood:is_learned() then
        if SPELL.ColdBlood:cast_safe(me) then return true end
    end
    if cp >= 2 and me:buff_down(SND) then
        if SPELL.SliceAndDice:cast_safe(me) then return true end
    end
    if cp >= 4 and target:debuff_remains(DEADLY_POISON) > 0 then
        if SPELL.Envenom:cast_safe(target) then return true end
    end
    if cp >= 4 and target:debuff_remains(RUPTURE) < 3 then
        if SPELL.Rupture:cast_safe(target) then return true end
    end
    if target:debuff_remains(DEADLY_POISON) < 3 and SPELL.Shiv:cast_safe(target) then return true end
    if SPELL.Mutilate:is_learned() and SPELL.Mutilate:cast_safe(target) then return true end
    if SPELL.SinisterStrike:cast_safe(target) then return true end
    if cp >= 5 and SPELL.Eviscerate:cast_safe(target) then return true end

    return false
end

return M
