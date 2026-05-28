local izi = require("common/izi_sdk")

local SPELL = {
    Fireball        = izi.spell(133, 143, 145, 3140, 8400, 8401, 8402, 10148, 10149, 10150, 25306, 27070),
    Scorch          = izi.spell(2948, 8444, 8445, 8446, 10205, 10206, 10207, 27073, 27074),
    FireBlast       = izi.spell(2136, 2137, 2138, 8412, 8413, 10199, 10200, 10201, 27079, 27080),
    Pyroblast       = izi.spell(11366, 12505, 12522, 12523, 12524, 12525, 12526, 18809, 27132),
    Combustion      = izi.spell(11129),
    DragonsBreath   = izi.spell(31661, 33041, 33042, 33043),
    BlastWave       = izi.spell(11113, 13018, 13019, 13020, 13021, 27133, 33933),
    Flamestrike     = izi.spell(2120, 2121, 8422, 8423, 10215, 10216, 27086),
    Evocation       = izi.spell(12051),
    ManaShield      = izi.spell(1463, 8494, 8495, 10191, 10192, 10193, 27131),
    ArcaneIntellect = izi.spell(1459, 1460, 1461, 10156, 10157, 27126, 23028, 27127),
    MoltenArmor     = izi.spell(30482),
    MageArmor       = izi.spell(6117, 22782, 22783, 27125),
    IceBarrier      = izi.spell(11426, 13031, 13032, 13033, 27134, 33405),
    FireWard        = izi.spell(543, 8457, 8458, 10223, 10225, 27128),
    Counterspell    = izi.spell(2139),
    RemoveCurse     = izi.spell(475),
    ConjureManaEmerald = izi.spell(27101),
}

local MOLTEN_ARMOR_BUFF   = { 30482 }
local MAGE_ARMOR_BUFF     = { 6117, 22782, 22783, 27125 }
local ICE_BARRIER_BUFF    = { 13032, 13031, 13033 }
local ARCANE_INTELLECT    = { 27126, 10157, 10156, 1461, 1460, 1459, 23028, 27127 }
local MANA_SHIELD_BUFF    = { 27131, 10193, 10192, 10191, 8495, 8494, 1463 }
local SCORCH_DEBUFF       = { 2948, 8444, 8445, 8446, 10205, 10206, 10207, 27073, 27074 }

local M = {}

function M.tick(me, target, enemies)
    if not me:is_in_combat() then return false end

    if me:mana_pct() and me:mana_pct() < 15 then
        if SPELL.Evocation:is_learned() and SPELL.Evocation:cast_safe(me) then return true end
    end

    if me:buff_down(MOLTEN_ARMOR_BUFF) and me:buff_down(MAGE_ARMOR_BUFF) then
        if SPELL.MoltenArmor:is_learned() and SPELL.MoltenArmor:cast_safe(me) then return true end
        if SPELL.MageArmor:is_learned() and SPELL.MageArmor:cast_safe(me) then return true end
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

        if SPELL.Combustion:is_learned() and SPELL.Combustion:cooldown_up() then
            if SPELL.Combustion:cast_safe(me) then return true end
        end

        if SPELL.Scorch:is_learned() and target:debuff_remains(SCORCH_DEBUFF) < 3 then
            if SPELL.Scorch:cast_safe(target) then return true end
        end

        if SPELL.Pyroblast:is_learned() then
            if SPELL.Pyroblast:cast_safe(target) then return true end
        end

        if SPELL.Fireball:is_learned() then
            if SPELL.Fireball:cast_safe(target) then return true end
        end

        if SPELL.FireBlast:is_learned() then
            if SPELL.FireBlast:cast_safe(target) then return true end
        end
    end

    return false
end

return M
