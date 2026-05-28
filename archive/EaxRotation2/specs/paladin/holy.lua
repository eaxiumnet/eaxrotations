local izi = require("common/izi_sdk")

local SPELL = {
    FlashOfLight    = izi.spell(19750, 19939, 19940, 19941, 19942, 19943, 27137),
    HolyLight       = izi.spell(635, 639, 647, 1026, 1042, 3472, 10328, 10329, 25292, 27135, 27136),
    HolyShock       = izi.spell(20473, 20929, 20930, 27174),
    LayOnHands      = izi.spell(633, 2800, 10310, 27154),
    DivineFavor     = izi.spell(20216),
    DivineIllumination = izi.spell(31842),
    AvengingWrath   = izi.spell(31884),
    Cleanse         = izi.spell(4987),
    SealOfLight     = izi.spell(20165, 20347, 20348, 20349, 27160),
    SealOfWisdom    = izi.spell(20166, 20356, 20357, 27166),
    Judgement       = izi.spell(20271),
    Consecration    = izi.spell(26573, 20116, 20922, 20923, 20924, 27173),
    HolyShield      = izi.spell(20925, 20927, 20928, 27179),
    BlessingOfWisdom= izi.spell(19742, 19850, 19852, 19853, 19854, 25290, 27143),
    BlessingOfLight = izi.spell(19977, 19978, 19979, 27144),
    BlessingOfKings = izi.spell(20217),
    BlessingOfProtection = izi.spell(1022, 5599, 10278),
    DivineProtection= izi.spell(498),
    DivineShield    = izi.spell(642, 1020),
    HammerOfWrath   = izi.spell(24239, 24274, 24275, 27180),
    HammerOfJustice = izi.spell(853, 5588, 5589, 10308),
    TurnEvil        = izi.spell(10326),
}

local SEAL_OF_LIGHT_BUFF  = { 20165, 20347, 20348, 20349, 27160 }
local SEAL_OF_WISDOM_BUFF = { 20166, 20356, 20357, 27166 }
local FORBEARANCE_DEBUFF  = { 25771 }
local BLESSING_OF_WISDOM  = { 19742, 19850, 19852, 19853, 19854, 25290, 27143 }
local BLESSING_OF_LIGHT   = { 19977, 19978, 19979, 27144 }
local BLESSING_OF_KINGS   = { 20217 }

local M = {}

function M.tick(me, target, enemies)
    if not me:is_in_combat() then return false end

    if me:mana_pct() and me:mana_pct() < 20 then
        if SPELL.DivineIllumination:is_learned() and SPELL.DivineIllumination:cooldown_up() then
            if SPELL.DivineIllumination:cast_safe(me) then return true end
        end
        if SPELL.DivineFavor:is_learned() and SPELL.DivineFavor:cooldown_up() then
            if SPELL.DivineFavor:cast_safe(me) then return true end
        end
    end

    if me:buff_down(SEAL_OF_LIGHT_BUFF) and me:buff_down(SEAL_OF_WISDOM_BUFF) then
        if SPELL.SealOfLight:is_learned() and SPELL.SealOfLight:cast_safe(me) then return true end
        if SPELL.SealOfWisdom:is_learned() and SPELL.SealOfWisdom:cast_safe(me) then return true end
    end

    if me:buff_down(BLESSING_OF_WISDOM) then
        if SPELL.BlessingOfWisdom:is_learned() and SPELL.BlessingOfWisdom:cast_safe(me) then return true end
    end

    if me:buff_down(BLESSING_OF_LIGHT) then
        if SPELL.BlessingOfLight:is_learned() and SPELL.BlessingOfLight:cast_safe(me) then return true end
    end

    if me:buff_down(BLESSING_OF_KINGS) then
        if SPELL.BlessingOfKings:is_learned() and SPELL.BlessingOfKings:cast_safe(me) then return true end
    end

    local hp = me:get_health_percentage() or 100
    if hp < 25 and SPELL.LayOnHands:is_learned() and me:debuff_down(FORBEARANCE_DEBUFF) then
        if SPELL.LayOnHands:cast_safe(me) then return true end
    end

    if hp < 35 and SPELL.DivineProtection:is_learned() and me:debuff_down(FORBEARANCE_DEBUFF) then
        if SPELL.DivineProtection:cast_safe(me) then return true end
    end

    if target then
        local t_hp = target:get_health_percentage() or 100
        if t_hp <= 20 and SPELL.HammerOfWrath:is_learned() then
            if SPELL.HammerOfWrath:cast_safe(target) then return true end
        end

        if SPELL.HolyShock:is_learned() then
            if SPELL.HolyShock:cast_safe(target) then return true end
        end

        if SPELL.Judgement:is_learned() then
            if SPELL.Judgement:cast_safe(target) then return true end
        end

        if SPELL.Consecration:is_learned() then
            if SPELL.Consecration:cast_safe(me) then return true end
        end

        if SPELL.HolyLight:is_learned() then
            if SPELL.HolyLight:cast_safe(me) then return true end
        end

        if SPELL.FlashOfLight:is_learned() then
            if SPELL.FlashOfLight:cast_safe(me) then return true end
        end
    end

    return false
end

return M
