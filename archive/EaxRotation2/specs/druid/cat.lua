local izi = require("common/izi_sdk")

local SPELL = {
    CatForm        = izi.spell(768),
    MangleCat      = izi.spell(33983, 33982, 33876),
    Shred          = izi.spell(27002, 27001, 9830, 9829, 8992, 6800, 5221),
    Rake           = izi.spell(27003, 9904, 1824, 1823, 1822),
    Rip            = izi.spell(27008, 9896, 9894, 9752, 9493, 9492, 1079),
    FerociousBite  = izi.spell(24248, 22829, 22828, 22827, 22568),
    Claw           = izi.spell(27000, 9850, 9849, 5201, 3029, 1082),
    FaerieFireFeral = izi.spell(27011, 17392, 17391, 17390, 16857),
    TigersFury     = izi.spell(9846, 9845, 6793, 5217),
    Pounce         = izi.spell(27006, 9827, 9823, 9005),
    Ravage         = izi.spell(27005, 9867, 9866, 6787, 6785),
    Maim           = izi.spell(22570),
    Barkskin       = izi.spell(22812),
}

local CAT_FORM = 768
local PROWL_BUFF = { 9913, 6783, 5215 }
local TIGERS_FURY_BUFF = { 9846, 9845, 6793, 5217 }
local RIP_DEBUFF = { 27008, 9896, 9894, 9752, 9493, 9492, 1079 }
local RAKE_DEBUFF = { 27003, 9904, 1824, 1823, 1822 }
local MANGLE_DEBUFF = { 33876, 33983, 33982, 33878, 33986, 33987 }
local FAERIE_FIRE_DEBUFF = { 27011, 17392, 17391, 17390, 16857, 26993, 9907, 9749, 778, 770 }

local M = {}

function M.tick(me, target, enemies)
    if not me:is_in_combat() then return false end

    if not me:has_buff(CAT_FORM) then
        if SPELL.CatForm:cast_safe(me) then return true end
    end
    if (me:get_health_percentage() or 100) < 45 and SPELL.Barkskin:is_learned() then
        if SPELL.Barkskin:cast_safe(me) then return true end
    end

    if target then
        if me:buff_up(PROWL_BUFF) then
            if SPELL.Pounce:cast_safe(target) then return true end
            if SPELL.Ravage:cast_safe(target) then return true end
        end
        if target:is_casting() and SPELL.Maim:is_learned() then
            if SPELL.Maim:cast_safe(target) then return true end
        end
        if target:debuff_remains(FAERIE_FIRE_DEBUFF) < 5 then
            if SPELL.FaerieFireFeral:cast_safe(target) then return true end
        end
        if me:buff_down(TIGERS_FURY_BUFF) and SPELL.TigersFury:is_learned() then
            if SPELL.TigersFury:cast_safe(me) then return true end
        end
        if target:debuff_remains(RIP_DEBUFF) < 3 then
            if SPELL.Rip:cast_safe(target) then return true end
        end
        if target:debuff_remains(RAKE_DEBUFF) < 3 then
            if SPELL.Rake:cast_safe(target) then return true end
        end
        if target:debuff_remains(MANGLE_DEBUFF) < 3 then
            if SPELL.MangleCat:cast_safe(target) then return true end
        end
        if SPELL.FerociousBite:cast_safe(target) then return true end
        if SPELL.Shred:cast_safe(target) then return true end
        if SPELL.Claw:cast_safe(target) then return true end
    end

    return false
end

return M
