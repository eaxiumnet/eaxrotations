local izi = require("common/izi_sdk")

local SPELL = {
    Stealth       = izi.spell(1787, 1786, 1785, 1784),
    Sap           = izi.spell(11297, 2070, 6770),
    Premeditation = izi.spell(14183),
    Shadowstep    = izi.spell(36554),
    Ambush        = izi.spell(27441, 11269, 11268, 11267, 8725, 8724, 8676),
    Garrote       = izi.spell(26884, 26839, 11290, 11289, 8633, 8632, 8631, 703),
    CheapShot     = izi.spell(1833),
    Kick          = izi.spell(38768, 1769, 1768, 1767, 1766),
    Hemorrhage    = izi.spell(26864, 17348, 17347, 16511),
    SliceAndDice  = izi.spell(6774, 5171),
    Rupture       = izi.spell(26867, 11275, 11274, 11273, 8640, 8639, 1943),
    Eviscerate    = izi.spell(31016, 26865, 11300, 11299, 8624, 8623, 6762, 6761, 6760, 2098),
    KidneyShot    = izi.spell(8643, 408),
    Backstab      = izi.spell(26863, 25300, 11281, 11280, 11279, 8721, 2591, 2590, 2589, 53),
    GhostlyStrike = izi.spell(14278),
    Preparation   = izi.spell(14185),
    Evasion       = izi.spell(26669, 5277),
    CloakOfShadows= izi.spell(31224),
    Blind         = izi.spell(2094),
}

local STEALTH = { 1787, 1786, 1785, 1784 }
local SND = { 6774, 5171 }
local RUPTURE = { 26867, 11275, 11274, 11273, 8640, 8639, 1943 }
local HEMORRHAGE = { 26864, 17348, 17347, 16511 }
local GARROTE = { 26884, 26839, 11290, 11289, 8633, 8632, 8631, 703 }

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
    if me:buff_up(STEALTH) then
        if SPELL.Premeditation:is_learned() and SPELL.Premeditation:cast_safe(target) then return true end
        if SPELL.Shadowstep:is_learned() and SPELL.Shadowstep:cast_safe(target) then return true end
        if target:debuff_down(GARROTE) and SPELL.Garrote:cast_safe(target) then return true end
        if SPELL.Ambush:cast_safe(target) then return true end
        if SPELL.CheapShot:cast_safe(target) then return true end
    end

    if target:is_casting() and SPELL.Blind:cast_safe(target) then return true end
    if cp >= 3 and SPELL.KidneyShot:cast_safe(target) then return true end
    if cp >= 2 and me:buff_down(SND) then
        if SPELL.SliceAndDice:cast_safe(me) then return true end
    end
    if cp >= 4 and target:debuff_remains(RUPTURE) < 3 then
        if SPELL.Rupture:cast_safe(target) then return true end
    end
    if cp >= 5 and SPELL.Eviscerate:cast_safe(target) then return true end
    if target:debuff_down(HEMORRHAGE) and SPELL.Hemorrhage:cast_safe(target) then return true end
    if SPELL.GhostlyStrike:is_learned() and SPELL.GhostlyStrike:cast_safe(target) then return true end
    if SPELL.Backstab:cast_safe(target) then return true end
    if SPELL.Hemorrhage:is_learned() and SPELL.Hemorrhage:cast_safe(target) then return true end
    if hp < 40 and SPELL.Preparation:is_learned() then
        if SPELL.Preparation:cast_safe(me) then return true end
    end

    return false
end

return M
