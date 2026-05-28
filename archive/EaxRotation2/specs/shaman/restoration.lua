local izi = require("common/izi_sdk")

local SPELL = {
    ChainHeal         = izi.spell(25423, 25422, 10623, 10622, 1064),
    HealingWave       = izi.spell(25396, 25391, 25357, 10396, 10395, 8005, 959, 939, 913, 547, 332, 331),
    LesserHealingWave = izi.spell(25420, 10468, 10467, 10466, 8010, 8008, 8004),
    EarthShield       = izi.spell(32594, 32593, 974),
    WaterShield       = izi.spell(33736, 24398, 23575),
    ManaTideTotem     = izi.spell(16190),
    NaturesSwiftness  = izi.spell(16188),
    EarthShock        = izi.spell(25454, 10414, 10413, 10412, 8046, 8045, 8044, 8042),
}

local WATER_SHIELD_BUFF = { 33736, 24398, 23575 }
local EARTH_SHIELD_BUFF = { 32594, 32593, 974 }

local M = {}

local function lowest_ally(me)
    local lowest = me
    local lowest_hp = me:get_health_percentage() or 100
    local friends = izi.friends() or {}
    for _, ally in ipairs(friends) do
        local hp = ally and ally:get_health_percentage() or 100
        if hp < lowest_hp then
            lowest = ally
            lowest_hp = hp
        end
    end
    return lowest, lowest_hp
end

function M.tick(me, target, enemies)
    if not me:is_in_combat() then return false end

    if me:buff_down(WATER_SHIELD_BUFF) then
        if SPELL.WaterShield:cast_safe(me) then return true end
    end
    if me:mana_pct() < 35 then
        if SPELL.ManaTideTotem:cast_safe(me) then return true end
    end

    local ally, hp = lowest_ally(me)
    if ally and hp < 30 then
        if SPELL.NaturesSwiftness:is_learned() then
            if SPELL.NaturesSwiftness:cast_safe(me) then return true end
        end
        if SPELL.LesserHealingWave:cast_safe(ally) then return true end
    end
    if ally and hp < 55 then
        if SPELL.ChainHeal:cast_safe(ally) then return true end
    end
    if ally and hp < 75 then
        if SPELL.HealingWave:cast_safe(ally) then return true end
    end
    if ally and ally:buff_down(EARTH_SHIELD_BUFF) and SPELL.EarthShield:is_learned() then
        if SPELL.EarthShield:cast_safe(ally) then return true end
    end

    if target and target:is_casting() then
        if SPELL.EarthShock:cast_safe(target) then return true end
    end

    return false
end

return M
