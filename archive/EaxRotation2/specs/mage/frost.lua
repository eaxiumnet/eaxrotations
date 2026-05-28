local izi = require("common/izi_sdk")

local SPELL = {
    Frostbolt       = izi.spell(27072, 27071, 25304, 10181, 10180, 10179, 8408, 8407, 8406, 7322, 837, 205, 116),
    IceLance        = izi.spell(30455),
    ConeOfCold      = izi.spell(27087, 10161, 10160, 10159, 8492, 120),
    FrostNova       = izi.spell(27088, 10230, 6131, 865, 122),
    Blizzard        = izi.spell(27085, 10187, 10186, 10185, 8427, 6141, 10),
    IceBarrier      = izi.spell(33405, 27134, 13033, 13032, 13031, 11426),
    IceBlock        = izi.spell(45438, 27619),
    IcyVeins        = izi.spell(12472),
    Evocation       = izi.spell(12051),
    ManaShield      = izi.spell(27131, 10193, 10192, 10191, 8495, 8494, 1463),
    ArcaneIntellect = izi.spell(27127, 27126, 10157, 10156, 1461, 1460, 1459, 23028),
    Counterspell    = izi.spell(2139),
    FireBlast       = izi.spell(27080, 27079, 10201, 10200, 10199, 8413, 8412, 2138, 2137, 2136),
    Scorch          = izi.spell(27074, 27073, 10207, 10206, 10205, 8446, 8445, 8444, 2948),
    PresenceOfMind  = izi.spell(12043),
    RemoveCurse     = izi.spell(475),
    ArcaneMissiles  = izi.spell(27075, 25345, 10212, 10211, 8417, 8416, 5145, 5144, 5143),
}

local ICE_BLOCK_BUFF    = { 45438, 27619 }
local ICE_BARRIER_BUFF  = { 13032, 13031, 13033 }
local MANA_SHIELD_BUFF  = { 27131, 10193, 10192, 10191, 8495, 8494, 1463 }
local ARCANE_INTELLECT  = { 27127, 27126, 10157, 10156, 1461, 1460, 1459, 23028 }
local FROST_NOVA_ROOTS  = { 27088, 10230, 6131, 865, 122 }

local M = {}

function M.tick(me, target, enemies)
    if not me:is_in_combat() then return false end

    if me:mana_pct() and me:mana_pct() < 15 then
        if SPELL.Evocation:is_learned() and SPELL.Evocation:cast_safe(me) then return true end
    end

    if me:buff_down(ICE_BARRIER_BUFF) and SPELL.IceBarrier:is_learned() then
        if SPELL.IceBarrier:cast_safe(me) then return true end
    end

    if me:buff_down(ARCANE_INTELLECT) and SPELL.ArcaneIntellect:is_learned() then
        if SPELL.ArcaneIntellect:cast_safe(me) then return true end
    end

    if me:buff_down(MANA_SHIELD_BUFF) and SPELL.ManaShield:is_learned() and me:mana_pct() > 30 then
        if SPELL.ManaShield:cast_safe(me) then return true end
    end

    if target then
        if target:is_casting() and SPELL.Counterspell:is_learned() then
            if SPELL.Counterspell:cast_safe(target) then return true end
        end

        local hp = target:get_health_percentage() or 100
        if hp < 20 and SPELL.IceBlock:is_learned() and me:buff_down(ICE_BLOCK_BUFF) then
            if SPELL.IceBlock:cast_safe(me) then return true end
        end

        if SPELL.IcyVeins:is_learned() and SPELL.IcyVeins:cooldown_up() then
            if SPELL.IcyVeins:cast_safe(me) then return true end
        end

        if not target:has_debuff(FROST_NOVA_ROOTS) and SPELL.FrostNova:is_learned() then
            if SPELL.FrostNova:cast_safe(me) then return true end
        end

        local nearby = 0
        for _, e in ipairs(enemies) do
            if e and e:is_valid() and e:distance() <= 10 then nearby = nearby + 1 end
        end
        if nearby >= 2 and SPELL.ConeOfCold:is_learned() then
            if SPELL.ConeOfCold:cast_safe(me) then return true end
        end

        if nearby >= 3 and SPELL.Blizzard:is_learned() then
            if SPELL.Blizzard:cast_safe(me) then return true end
        end

        if SPELL.Frostbolt:is_learned() then
            if SPELL.Frostbolt:cast_safe(target) then return true end
        end

        if SPELL.FireBlast:is_learned() then
            if SPELL.FireBlast:cast_safe(target) then return true end
        end
    end

    return false
end

return M
