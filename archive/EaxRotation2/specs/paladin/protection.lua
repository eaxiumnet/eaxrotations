local izi = require("common/izi_sdk")

local SPELL = {
    HolyShield      = izi.spell(20925, 20927, 20928, 27179),
    AvengerShield   = izi.spell(31935, 32699, 32700),
    Judgement       = izi.spell(20271),
    Consecration    = izi.spell(26573, 20116, 20922, 20923, 20924, 27173),
    Exorcism        = izi.spell(879, 5614, 5615, 10312, 10313, 10314, 27138),
    HammerWrath     = izi.spell(24239, 24274, 24275, 27180),
    HammerJustice   = izi.spell(853, 5588, 5589, 10308),
    DivineProtection= izi.spell(498),
    DivineShield    = izi.spell(642, 1020),
    LayOnHands      = izi.spell(633, 2800, 10310, 27154),
    RighteousDefense= izi.spell(31789),
    BlessingOfProtection = izi.spell(1022, 5599, 10278),
    SealOfRighteousness = izi.spell(20154, 21084, 20287, 20288, 20289, 20290, 20291, 20292, 20293, 27155),
    SealOfCommand   = izi.spell(20375, 20915, 20918, 20919, 20920, 27170),
    FlashOfLight    = izi.spell(19750, 19939, 19940, 19941, 19942, 19943, 27137),
    HolyLight       = izi.spell(635, 639, 647, 1026, 1042, 3472, 10328, 10329, 25292, 27135, 27136),
    Cleanse         = izi.spell(4987),
    AvengingWrath   = izi.spell(31884),
    TurnEvil        = izi.spell(10326),
}

local HOLY_SHIELD_BUFF    = { 20925, 20927, 20928, 27179 }
local SEAL_RIGHTEOUS_BUFF = { 27155, 20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084 }
local SEAL_COMMAND_BUFF   = { 27170, 20920, 20919, 20918, 20915, 20375 }
local FORBEARANCE_DEBUFF  = { 25771 }

local M = {}

function M.tick(me, target, enemies)
    if not me:is_in_combat() then return false end

    if me:buff_down(HOLY_SHIELD_BUFF) and SPELL.HolyShield:is_learned() then
        if SPELL.HolyShield:cast_safe(me) then return true end
    end

    if me:buff_down(SEAL_RIGHTEOUS_BUFF) and me:buff_down(SEAL_COMMAND_BUFF) then
        if SPELL.SealOfRighteousness:is_learned() and SPELL.SealOfRighteousness:cast_safe(me) then return true end
        if SPELL.SealOfCommand:is_learned() and SPELL.SealOfCommand:cast_safe(me) then return true end
    end

    local hp = me:get_health_percentage() or 100
    if hp < 20 and SPELL.DivineShield:is_learned() and me:debuff_down(FORBEARANCE_DEBUFF) then
        if SPELL.DivineShield:cast_safe(me) then return true end
    end

    if hp < 30 and SPELL.DivineProtection:is_learned() and me:debuff_down(FORBEARANCE_DEBUFF) then
        if SPELL.DivineProtection:cast_safe(me) then return true end
    end

    if hp < 15 and SPELL.LayOnHands:is_learned() and me:debuff_down(FORBEARANCE_DEBUFF) then
        if SPELL.LayOnHands:cast_safe(me) then return true end
    end

    if target then
        local t_hp = target:get_health_percentage() or 100
        if t_hp <= 20 and SPELL.HammerWrath:is_learned() then
            if SPELL.HammerWrath:cast_safe(target) then return true end
        end

        if SPELL.AvengerShield:is_learned() then
            if SPELL.AvengerShield:cast_safe(target) then return true end
        end

        if SPELL.Judgement:is_learned() then
            if SPELL.Judgement:cast_safe(target) then return true end
        end

        if SPELL.Consecration:is_learned() then
            if SPELL.Consecration:cast_safe(me) then return true end
        end

        if SPELL.Exorcism:is_learned() then
            if SPELL.Exorcism:cast_safe(target) then return true end
        end

        if target:is_casting() and SPELL.HammerJustice:is_learned() then
            if SPELL.HammerJustice:cast_safe(target) then return true end
        end

        if SPELL.RighteousDefense:is_learned() then
            if SPELL.RighteousDefense:cast_safe(target) then return true end
        end
    end

    return false
end

return M
