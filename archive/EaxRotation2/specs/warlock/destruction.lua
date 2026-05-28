local izi = require("common/izi_sdk")

local SPELL = {
    ShadowBolt      = izi.spell(27209, 25307, 11661, 11660, 11659, 7641, 11006, 1088, 705, 695, 686),
    Immolate        = izi.spell(27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348),
    Incinerate      = izi.spell(32231, 29722),
    Conflagrate     = izi.spell(18932, 18931, 18930, 17962),
    SearingPain     = izi.spell(30459, 27210, 17923, 17922, 17921, 17920, 17919, 5676),
    SoulFire        = izi.spell(30545, 27211, 17924, 6353),
    RainOfFire      = izi.spell(27212, 11678, 11677, 6219, 5740),
    Hellfire        = izi.spell(27213, 11684, 11683, 1949),
    LifeTap         = izi.spell(27222, 11689, 11688, 11687, 1456, 1455, 1454),
    DarkPact        = izi.spell(27265, 18938, 18937, 18220),
    Shadowburn      = izi.spell(30546, 27263, 18871, 18870, 18869, 18868, 18867, 17877),
    DeathCoil       = izi.spell(27223, 17926, 17925, 6789),
    HowlOfTerror    = izi.spell(17928, 5484),
    Fear            = izi.spell(6215, 6213, 5782),
    ShadowWard      = izi.spell(28610, 11740, 11739, 6229),
    DemonArmor      = izi.spell(27260, 11735, 11734, 11733, 706),
    FelArmor        = izi.spell(28189, 28176),
    Soulshatter     = izi.spell(29858),
    CurseOfElements = izi.spell(27228, 11722, 11721, 1490),
    CurseOfAgony    = izi.spell(27218, 11713, 11712, 11711, 6217, 1014, 980),
    CreateHealthstone = izi.spell(27230, 11730, 11729, 5699, 6202, 6201),
    SeedOfCorruption= izi.spell(27243, 30413),
}

local IMMOLATE_IDS       = { 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }
local FEL_ARMOR_IDS      = { 28189, 28176 }
local DEMON_ARMOR_IDS    = { 27260, 11735, 11734, 11733, 706 }

local DOT_REFRESH = 1.5

local M = {}

function M.tick(me, target, enemies)
    if not me:is_in_combat() then return false end

    if me:mana_pct() < 10 then
        if SPELL.LifeTap:cast_safe(me) then return true end
        if SPELL.DarkPact:cast_safe(me) then return true end
    end

    if me:buff_down(FEL_ARMOR_IDS) and SPELL.FelArmor:is_learned() then
        if SPELL.FelArmor:cast_safe(me) then return true end
    end
    if me:buff_down(DEMON_ARMOR_IDS) and not SPELL.FelArmor:is_learned() then
        if SPELL.DemonArmor:cast_safe(me) then return true end
    end

    if target then
        local hp = target:get_health_percentage() or 100
        if hp <= 20 and SPELL.Shadowburn:is_learned() then
            if SPELL.Shadowburn:cast_safe(target) then return true end
        end

        if SPELL.Immolate:is_learned() and target:debuff_remains(IMMOLATE_IDS) < DOT_REFRESH then
            if SPELL.Immolate:cast_safe(target) then return true end
        end
        if SPELL.CurseOfElements:is_learned() and target:debuff_remains({ 27228, 11722, 11721, 1490 }) < DOT_REFRESH then
            if SPELL.CurseOfElements:cast_safe(target) then return true end
        end
        if SPELL.CurseOfAgony:is_learned() and target:debuff_remains({ 27218, 11713, 11712, 11711, 6217, 1014, 980 }) < DOT_REFRESH then
            if SPELL.CurseOfAgony:cast_safe(target) then return true end
        end

        if SPELL.Conflagrate:is_learned() then
            if SPELL.Conflagrate:cast_safe(target) then return true end
        end

        if SPELL.Incinerate:is_learned() then
            if SPELL.Incinerate:cast_safe(target) then return true end
        end

        if SPELL.SoulFire:is_learned() then
            if SPELL.SoulFire:cast_safe(target) then return true end
        end

        if SPELL.ShadowBolt:cast_safe(target) then return true end
    end

    return false
end

return M
