local izi = require("common/izi_sdk")

local SPELL = {
    LightningBolt     = izi.spell(25449, 25448, 15208, 15207, 10392, 10391, 6041, 943, 915, 548, 529, 403),
    ChainLightning    = izi.spell(25442, 25439, 10605, 2860, 930, 421),
    FlameShock        = izi.spell(25457, 29228, 10448, 10447, 8053, 8052, 8050),
    EarthShock        = izi.spell(25454, 10414, 10413, 10412, 8046, 8045, 8044, 8042),
    FrostShock        = izi.spell(25464, 10473, 10472, 8058, 8056),
    LightningShield   = izi.spell(25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324),
    WaterShield       = izi.spell(33736, 24398, 23575),
    ElementalMastery  = izi.spell(16166),
    HealingWave       = izi.spell(25396, 25391, 25357, 10396, 10395, 8005, 959, 939, 913, 547, 332, 331),
}

local LIGHTNING_SHIELD_BUFF = { 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }
local WATER_SHIELD_BUFF = { 33736, 24398, 23575 }
local FLAME_SHOCK_DEBUFF = { 25457, 29228, 10448, 10447, 8053, 8052, 8050 }

local M = {}

function M.tick(me, target, enemies)
    if not me:is_in_combat() then return false end

    if me:buff_down(LIGHTNING_SHIELD_BUFF) then
        if SPELL.LightningShield:cast_safe(me) then return true end
    end
    if me:mana_pct() < 45 and me:buff_down(WATER_SHIELD_BUFF) then
        if SPELL.WaterShield:cast_safe(me) then return true end
    end

    local hp = me:get_health_percentage() or 100
    if hp < 40 then
        if SPELL.HealingWave:cast_safe(me) then return true end
    end

    if target and target:is_casting() then
        if SPELL.EarthShock:cast_safe(target) then return true end
    end

    if target then
        if SPELL.ElementalMastery:is_learned() then
            if SPELL.ElementalMastery:cast_safe(me) then return true end
        end
        if target:debuff_remains(FLAME_SHOCK_DEBUFF) < 3 then
            if SPELL.FlameShock:cast_safe(target) then return true end
        end
        if SPELL.ChainLightning:cast_safe(target) then return true end
        if SPELL.EarthShock:cast_safe(target) then return true end
        if SPELL.FrostShock:cast_safe(target) then return true end
        if SPELL.LightningBolt:cast_safe(target) then return true end
    end

    return false
end

return M
