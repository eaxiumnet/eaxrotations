local izi = require("common/izi_sdk")

local SPELL = {
    CrusaderStrike  = izi.spell(35395),
    Judgement       = izi.spell(20271),
    SealCommand     = izi.spell(20375, 20915, 20918, 20919, 20920, 27170),
    SealBlood       = izi.spell(31892),
    SealRighteous   = izi.spell(20154, 21084, 20287, 20288, 20289, 20290, 20291, 20292, 20293, 27155),
    SealCrusader    = izi.spell(20305, 20306, 20307, 20308, 27158, 21082, 20162),
    SealWisdom      = izi.spell(20166, 20356, 20357, 27166),
    Consecration    = izi.spell(26573, 20116, 20922, 20923, 20924, 27173),
    HammerWrath     = izi.spell(24239, 24274, 24275, 27180),
    HammerJustice   = izi.spell(853, 5588, 5589, 10308),
    Repentance      = izi.spell(20066),
    DivineProtection= izi.spell(498),
    BlessingFreedom = izi.spell(1044),
    BlessingProtection = izi.spell(1022, 5599, 10278),
    Purify          = izi.spell(1152),
    Cleanse         = izi.spell(4987),
    AvengingWrath   = izi.spell(31884),
    Exorcism        = izi.spell(879, 5614, 5615, 10312, 10313, 10314, 27138),
    DivineShield    = izi.spell(642, 1020),
    FlashOfLight    = izi.spell(19750, 19939, 19940, 19941, 19942, 19943, 27137),
    HolyLight       = izi.spell(635, 639, 647, 1026, 1042, 3472, 10328, 10329, 25292, 27135, 27136),
}

local SEAL_COMMAND_BUFF   = { 27170, 20920, 20919, 20918, 20915, 20375 }
local SEAL_BLOOD_BUFF     = { 31892 }
local SEAL_RIGHTEOUS_BUFF = { 27155, 20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084 }
local SEAL_CRUSADER_BUFF  = { 27158, 20308, 20307, 20306, 20305, 21082, 20162 }
local SEAL_WISDOM_BUFF    = { 27166, 20357, 20356, 20166 }
local FORBEARANCE_DEBUFF  = { 25771 }

local M = {}

function M.tick(me, target, enemies)
    if not me:is_in_combat() then return false end

    if me:buff_down(SEAL_COMMAND_BUFF) and me:buff_down(SEAL_BLOOD_BUFF) and me:buff_down(SEAL_RIGHTEOUS_BUFF) then
        if SPELL.SealCommand:is_learned() and SPELL.SealCommand:cast_safe(me) then return true end
        if SPELL.SealBlood:is_learned() and SPELL.SealBlood:cast_safe(me) then return true end
        if SPELL.SealRighteous:is_learned() and SPELL.SealRighteous:cast_safe(me) then return true end
    end

    if me:buff_down(SEAL_COMMAND_BUFF) and me:buff_down(SEAL_BLOOD_BUFF) and me:buff_down(SEAL_RIGHTEOUS_BUFF) then
        if SPELL.SealCrusader:is_learned() and SPELL.SealCrusader:cast_safe(me) then return true end
        if SPELL.SealWisdom:is_learned() and SPELL.SealWisdom:cast_safe(me) then return true end
    end

    local hp = me:get_health_percentage() or 100
    if hp < 30 and SPELL.DivineProtection:is_learned() and me:debuff_down(FORBEARANCE_DEBUFF) then
        if SPELL.DivineProtection:cast_safe(me) then return true end
    end

    if hp < 20 and SPELL.DivineShield:is_learned() and me:debuff_down(FORBEARANCE_DEBUFF) then
        if SPELL.DivineShield:cast_safe(me) then return true end
    end

    if me:mana_pct() and me:mana_pct() < 15 then
        if SPELL.FlashOfLight:is_learned() and SPELL.FlashOfLight:cast_safe(me) then return true end
    end

    if target then
        local t_hp = target:get_health_percentage() or 100
        if t_hp <= 20 and SPELL.HammerWrath:is_learned() then
            if SPELL.HammerWrath:cast_safe(target) then return true end
        end

        if SPELL.CrusaderStrike:is_learned() then
            if SPELL.CrusaderStrike:cast_safe(target) then return true end
        end

        if SPELL.Judgement:is_learned() then
            if SPELL.Judgement:cast_safe(target) then return true end
        end

        if SPELL.AvengingWrath:is_learned() and SPELL.AvengingWrath:cooldown_up() then
            if SPELL.AvengingWrath:cast_safe(me) then return true end
        end

        if SPELL.Consecration:is_learned() then
            if SPELL.Consecration:cast_safe(me) then return true end
        end

        if target:is_casting() and SPELL.HammerJustice:is_learned() then
            if SPELL.HammerJustice:cast_safe(target) then return true end
        end

        if SPELL.Repentance:is_learned() then
            if SPELL.Repentance:cast_safe(target) then return true end
        end

        if SPELL.Exorcism:is_learned() then
            if SPELL.Exorcism:cast_safe(target) then return true end
        end
    end

    return false
end

return M
