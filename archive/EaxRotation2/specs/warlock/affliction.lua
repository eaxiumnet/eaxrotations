local izi = require("common/izi_sdk")

local SPELL = {
    ShadowBolt      = izi.spell(27209, 25307, 11661, 11660, 11659, 7641, 11006, 1088, 705, 695, 686),
    Corruption      = izi.spell(27216, 25311, 11672, 11671, 7648, 6223, 6222, 172),
    Agony           = izi.spell(27218, 11713, 11712, 11711, 6217, 1014, 980),
    SiphonLife      = izi.spell(30911, 27264, 18881, 18880, 18879, 18265),
    UnstableAfflict = izi.spell(30405, 30404, 30108),
    Immolate        = izi.spell(27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348),
    LifeTap         = izi.spell(27222, 11689, 11688, 11687, 1456, 1455, 1454),
    DrainSoul       = izi.spell(27217, 11675, 8289, 8288, 1120),
    Fear            = izi.spell(6215, 6213, 5782),
    HowlOfTerror    = izi.spell(17928, 5484),
    DeathCoil       = izi.spell(27223, 17926, 17925, 6789),
    ShadowWard      = izi.spell(28610, 11740, 11739, 6229),
    DemonArmor      = izi.spell(27260, 11735, 11734, 11733, 706),
    FelArmor        = izi.spell(28189, 28176),
    AmplifyCurse    = izi.spell(18288),
    CreateHealthstone = izi.spell(27230, 11730, 11729, 5699, 6202, 6201),
}

local CORRUPTION_IDS     = { 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }
local AGONY_IDS          = { 27218, 11713, 11712, 11711, 6217, 1014, 980 }
local SIPHON_IDS         = { 30911, 27264, 18881, 18880, 18879, 18265 }
local UNSTABLE_IDS       = { 30405, 30404, 30108 }
local IMMOLATE_IDS       = { 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }
local FEL_ARMOR_IDS      = { 28189, 28176 }
local DEMON_ARMOR_IDS    = { 27260, 11735, 11734, 11733, 706 }

local DOT_REFRESH = 1.5
local EXECUTE_HP  = 25

local M = {}

function M.tick(me, target, enemies)
    if not me:is_in_combat() then return false end

    if me:mana_pct() < 10 then
        if SPELL.LifeTap:cast_safe(me) then return true end
    end

    if me:buff_down(FEL_ARMOR_IDS) and SPELL.FelArmor:is_learned() then
        if SPELL.FelArmor:cast_safe(me) then return true end
    end

    if me:buff_down(DEMON_ARMOR_IDS) and not SPELL.FelArmor:is_learned() then
        if SPELL.DemonArmor:cast_safe(me) then return true end
    end

    if target then
        local hp = target:get_health_percentage() or 100

        if hp <= EXECUTE_HP then
            if SPELL.DrainSoul:cast_safe(target) then return true end
        end

        if SPELL.Corruption:is_learned() and target:debuff_remains(CORRUPTION_IDS) < DOT_REFRESH then
            if SPELL.Corruption:cast_safe(target) then return true end
        end
        if SPELL.Agony:is_learned() and target:debuff_remains(AGONY_IDS) < DOT_REFRESH then
            if SPELL.Agony:cast_safe(target) then return true end
        end
        if SPELL.SiphonLife:is_learned() and target:debuff_remains(SIPHON_IDS) < DOT_REFRESH then
            if SPELL.SiphonLife:cast_safe(target) then return true end
        end
        if SPELL.UnstableAfflict:is_learned() and target:debuff_remains(UNSTABLE_IDS) < DOT_REFRESH then
            if SPELL.UnstableAfflict:cast_safe(target) then return true end
        end
        if SPELL.Immolate:is_learned() and target:debuff_remains(IMMOLATE_IDS) < DOT_REFRESH then
            if SPELL.Immolate:cast_safe(target) then return true end
        end

        if SPELL.AmplifyCurse:is_learned() and SPELL.AmplifyCurse:cooldown_up() then
            if SPELL.AmplifyCurse:cast_safe(me) then return true end
        end

        if SPELL.ShadowBolt:cast_safe(target) then return true end
    end

    return false
end

return M
