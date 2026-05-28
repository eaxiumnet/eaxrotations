local izi = require("common/izi_sdk")

local SPELL = {
    ArcaneBlast     = izi.spell(30451),
    ArcaneMissiles  = izi.spell(5143, 5144, 5145, 8416, 8417, 10211, 10212, 25345, 27075),
    ArcaneExplosion = izi.spell(1449, 8437, 8438, 8439, 10202, 10203, 10204, 27080, 27082),
    Fireball        = izi.spell(133, 143, 145, 3140, 8400, 8401, 8402, 10148, 10149, 10150, 25306, 27070),
    Frostbolt       = izi.spell(116, 205, 837, 7322, 8406, 8407, 8408, 10179, 10180, 10181, 25304, 27071, 27072),
    Evocation       = izi.spell(12051),
    ArcanePower     = izi.spell(12042),
    PresenceOfMind  = izi.spell(12043),
    ManaShield      = izi.spell(1463, 8494, 8495, 10191, 10192, 10193, 27131),
    ArcaneIntellect = izi.spell(1459, 1460, 1461, 10156, 10157, 27126, 23028, 27127),
    MageArmor       = izi.spell(6117, 22782, 22783, 27125),
    MoltenArmor     = izi.spell(30482),
    IceBarrier      = izi.spell(11426, 13031, 13032, 13033, 27134, 33405),
    Counterspell    = izi.spell(2139),
    RemoveCurse     = izi.spell(475),
    ConjureManaEmerald = izi.spell(27101),
    Slow            = izi.spell(31589),
}

local MAGE_ARMOR_BUFF     = { 6117, 22782, 22783, 27125 }
local MOLTEN_ARMOR_BUFF   = { 30482 }
local ICE_BARRIER_BUFF    = { 13032, 13031, 13033 }
local ARCANE_INTELLECT    = { 27126, 10157, 10156, 1461, 1460, 1459, 23028, 27127 }
local MANA_SHIELD_BUFF    = { 27131, 10193, 10192, 10191, 8495, 8494, 1463 }

local M = {}

function M.tick(me, target, enemies)
    if not me:is_in_combat() then return false end

    if me:mana_pct() and me:mana_pct() < 15 then
        if SPELL.Evocation:is_learned() and SPELL.Evocation:cast_safe(me) then return true end
    end

    if me:buff_down(MAGE_ARMOR_BUFF) and me:buff_down(MOLTEN_ARMOR_BUFF) then
        if SPELL.MageArmor:is_learned() and SPELL.MageArmor:cast_safe(me) then return true end
        if SPELL.MoltenArmor:is_learned() and SPELL.MoltenArmor:cast_safe(me) then return true end
    end

    if me:buff_down(ARCANE_INTELLECT) and SPELL.ArcaneIntellect:is_learned() then
        if SPELL.ArcaneIntellect:cast_safe(me) then return true end
    end

    if me:buff_down(MANA_SHIELD_BUFF) and SPELL.ManaShield:is_learned() and me:mana_pct() > 30 then
        if SPELL.ManaShield:cast_safe(me) then return true end
    end

    if SPELL.ArcanePower:is_learned() and SPELL.ArcanePower:cooldown_up() then
        if SPELL.ArcanePower:cast_safe(me) then return true end
    end

    if SPELL.PresenceOfMind:is_learned() and SPELL.PresenceOfMind:cooldown_up() then
        if SPELL.PresenceOfMind:cast_safe(me) then return true end
    end

    if target then
        if target:is_casting() and SPELL.Counterspell:is_learned() then
            if SPELL.Counterspell:cast_safe(target) then return true end
        end

        if SPELL.Slow:is_learned() and target:debuff_down({ 31589 }) then
            if SPELL.Slow:cast_safe(target) then return true end
        end

        if SPELL.ArcaneBlast:is_learned() then
            if SPELL.ArcaneBlast:cast_safe(target) then return true end
        end

        if SPELL.ArcaneMissiles:is_learned() then
            if SPELL.ArcaneMissiles:cast_safe(target) then return true end
        end

        if SPELL.Fireball:is_learned() then
            if SPELL.Fireball:cast_safe(target) then return true end
        end

        if SPELL.Frostbolt:is_learned() then
            if SPELL.Frostbolt:cast_safe(target) then return true end
        end
    end

    return false
end

return M
