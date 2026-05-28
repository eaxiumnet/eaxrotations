local izi = require("common/izi_sdk")

local SPELL = {
    HealingTouch   = izi.spell(26979, 26978, 25297, 9889, 9888, 9758, 8903, 6778, 5189, 5188, 5187, 5186, 5185),
    Regrowth       = izi.spell(26980, 9858, 9857, 9856, 9750, 8941, 8940, 8939, 8938, 8936),
    Rejuvenation   = izi.spell(26982, 26981, 25299, 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774),
    Lifebloom      = izi.spell(33763),
    Swiftmend      = izi.spell(18562),
    NaturesSwiftness = izi.spell(17116),
    Tranquility    = izi.spell(26983, 9863, 9862, 8918, 740),
    TreeOfLifeForm = izi.spell(33891),
    Barkskin       = izi.spell(22812),
    Innervate      = izi.spell(29166),
    RemoveCurse    = izi.spell(2782),
    AbolishPoison  = izi.spell(2893),
    Moonfire       = izi.spell(26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921),
    InsectSwarm    = izi.spell(27013, 24977, 24976, 24975, 24974, 5570),
    Wrath          = izi.spell(26985, 26984, 9912, 8905, 6780, 5180, 5179, 5178, 5177, 5176),
}

local TREE_FORM = 33891
local REJUVENATION_BUFF = { 26982, 26981, 25299, 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774 }
local REGROWTH_BUFF = { 26980, 9858, 9857, 9856, 9750, 8941, 8940, 8939, 8938, 8936 }
local LIFEBLOOM_BUFF = { 33763 }
local MOONFIRE_DEBUFF = { 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }
local INSECT_SWARM_DEBUFF = { 27013, 24977, 24976, 24975, 24974, 5570 }

local M = {}

function M.tick(me, target, enemies)
    if not me:is_in_combat() then return false end

    local hp = me:get_health_percentage() or 100
    if hp < 45 and SPELL.Barkskin:is_learned() then
        if SPELL.Barkskin:cast_safe(me) then return true end
    end
    if hp < 25 and SPELL.NaturesSwiftness:is_learned() then
        if SPELL.NaturesSwiftness:cast_safe(me) then return true end
    end
    if hp < 35 and SPELL.Swiftmend:is_learned() and (me:buff_up(REJUVENATION_BUFF) or me:buff_up(REGROWTH_BUFF)) then
        if SPELL.Swiftmend:cast_safe(me) then return true end
    end
    if hp < 50 and SPELL.HealingTouch:cast_safe(me) then return true end
    if hp < 70 and me:buff_down(REGROWTH_BUFF) then
        if SPELL.Regrowth:cast_safe(me) then return true end
    end
    if hp < 90 and me:buff_down(REJUVENATION_BUFF) then
        if SPELL.Rejuvenation:cast_safe(me) then return true end
    end
    if hp < 95 and me:buff_down(LIFEBLOOM_BUFF) then
        if SPELL.Lifebloom:cast_safe(me) then return true end
    end

    if me:mana_pct() and me:mana_pct() < 20 and SPELL.Innervate:is_learned() then
        if SPELL.Innervate:cast_safe(me) then return true end
    end
    if not me:has_buff(TREE_FORM) and SPELL.TreeOfLifeForm:is_learned() then
        if SPELL.TreeOfLifeForm:cast_safe(me) then return true end
    end
    if hp < 40 and SPELL.Tranquility:is_learned() then
        if SPELL.Tranquility:cast_safe(me) then return true end
    end

    if target then
        if target:debuff_remains(MOONFIRE_DEBUFF) < 3 then
            if SPELL.Moonfire:cast_safe(target) then return true end
        end
        if target:debuff_remains(INSECT_SWARM_DEBUFF) < 3 then
            if SPELL.InsectSwarm:cast_safe(target) then return true end
        end
        if SPELL.Wrath:cast_safe(target) then return true end
    end

    return false
end

return M
