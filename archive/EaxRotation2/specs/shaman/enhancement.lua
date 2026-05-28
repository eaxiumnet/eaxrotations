local izi = require("common/izi_sdk")

local SPELL = {
    Stormstrike       = izi.spell(17364),
    ShamanisticRage   = izi.spell(30823),
    WindfuryWeapon    = izi.spell(25505, 16362, 10486, 8235, 8232),
    LightningShield   = izi.spell(25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324),
    WaterShield       = izi.spell(33736, 24398, 23575),
    FlameShock        = izi.spell(25457, 29228, 10448, 10447, 8053, 8052, 8050),
    EarthShock        = izi.spell(25454, 10414, 10413, 10412, 8046, 8045, 8044, 8042),
    FrostShock        = izi.spell(25464, 10473, 10472, 8058, 8056),
    LightningBolt     = izi.spell(25449, 25448, 15208, 15207, 10392, 10391, 6041, 943, 915, 548, 529, 403),
    ChainLightning    = izi.spell(25442, 25439, 10605, 2860, 930, 421),
    LesserHealingWave = izi.spell(25420, 10468, 10467, 10466, 8010, 8008, 8004),
}

local WINDFURY_WEAPON_BUFF = { 25505, 16362, 10486, 8235, 8232 }
local LIGHTNING_SHIELD_BUFF = { 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }
local WATER_SHIELD_BUFF = { 33736, 24398, 23575 }
local FLAME_SHOCK_DEBUFF = { 25457, 29228, 10448, 10447, 8053, 8052, 8050 }
local SHAMANISTIC_RAGE_BUFF = { 30823 }

local M = {}

function M.tick(me, target, enemies)
    if not me:is_in_combat() then return false end

    if me:buff_down(WINDFURY_WEAPON_BUFF) then
        if SPELL.WindfuryWeapon:cast_safe(me) then return true end
    end
    if me:buff_down(LIGHTNING_SHIELD_BUFF) and me:mana_pct() >= 35 then
        if SPELL.LightningShield:cast_safe(me) then return true end
    end
    if me:mana_pct() < 35 and me:buff_down(WATER_SHIELD_BUFF) then
        if SPELL.WaterShield:cast_safe(me) then return true end
    end

    local hp = me:get_health_percentage() or 100
    if hp < 35 then
        if SPELL.LesserHealingWave:cast_safe(me) then return true end
    end
    if me:mana_pct() < 45 and me:buff_down(SHAMANISTIC_RAGE_BUFF) then
        if SPELL.ShamanisticRage:cast_safe(me) then return true end
    end

    if target and target:is_casting() then
        if SPELL.EarthShock:cast_safe(target) then return true end
    end

    if target then
        if SPELL.Stormstrike:cast_safe(target) then return true end
        if target:debuff_remains(FLAME_SHOCK_DEBUFF) < 3 then
            if SPELL.FlameShock:cast_safe(target) then return true end
        end
        if SPELL.EarthShock:cast_safe(target) then return true end
        if SPELL.FrostShock:cast_safe(target) then return true end
        if SPELL.ChainLightning:cast_safe(target) then return true end
        if SPELL.LightningBolt:cast_safe(target) then return true end
    end

    return false
end

return M
