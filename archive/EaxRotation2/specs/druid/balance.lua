local izi = require("common/izi_sdk")

local SPELL = {
    Starfire       = izi.spell(26986, 25298, 9876, 9875, 8951, 8950, 8949, 2912),
    Wrath          = izi.spell(26985, 26984, 9912, 8905, 6780, 5180, 5179, 5178, 5177, 5176),
    Moonfire       = izi.spell(26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921),
    InsectSwarm    = izi.spell(27013, 24977, 24976, 24975, 24974, 5570),
    FaerieFire     = izi.spell(26993, 9907, 9749, 778, 770),
    Hurricane      = izi.spell(27012, 17402, 17401, 16914),
    ForceOfNature  = izi.spell(33831),
    Barkskin       = izi.spell(22812),
    Innervate      = izi.spell(29166),
    MoonkinForm    = izi.spell(24858),
    MarkOfTheWild  = izi.spell(26990, 9885, 9884, 8907, 5234, 6756, 5232, 1126),
    Thorns         = izi.spell(26992, 9910, 9756, 8914, 1075, 782, 467),
}

local MOONKIN_FORM = 24858
local MARK_BUFF = { 26991, 26990, 9885, 9884, 8907, 6756, 5234, 5232, 1126, 21850, 21849 }
local THORNS_BUFF = { 26992, 9910, 9756, 8914, 1075, 782, 467 }
local MOONFIRE_DEBUFF = { 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }
local INSECT_SWARM_DEBUFF = { 27013, 24977, 24976, 24975, 24974, 5570 }
local FAERIE_FIRE_DEBUFF = { 26993, 9907, 9749, 778, 770 }
local DOT_REFRESH = 2

local M = {}

function M.tick(me, target, enemies)
    if not me:is_in_combat() then return false end

    if not me:has_buff(MOONKIN_FORM) and SPELL.MoonkinForm:is_learned() then
        if SPELL.MoonkinForm:cast_safe(me) then return true end
    end
    if me:buff_down(MARK_BUFF) then
        if SPELL.MarkOfTheWild:cast_safe(me) then return true end
    end
    if me:buff_down(THORNS_BUFF) then
        if SPELL.Thorns:cast_safe(me) then return true end
    end

    local hp = me:get_health_percentage() or 100
    if hp < 50 and SPELL.Barkskin:is_learned() then
        if SPELL.Barkskin:cast_safe(me) then return true end
    end
    if me:mana_pct() and me:mana_pct() < 20 and SPELL.Innervate:is_learned() then
        if SPELL.Innervate:cast_safe(me) then return true end
    end

    if target then
        if target:debuff_remains(FAERIE_FIRE_DEBUFF) < 5 then
            if SPELL.FaerieFire:cast_safe(target) then return true end
        end
        if target:debuff_remains(INSECT_SWARM_DEBUFF) < DOT_REFRESH then
            if SPELL.InsectSwarm:cast_safe(target) then return true end
        end
        if target:debuff_remains(MOONFIRE_DEBUFF) < DOT_REFRESH then
            if SPELL.Moonfire:cast_safe(target) then return true end
        end
        if SPELL.ForceOfNature:is_learned() then
            if SPELL.ForceOfNature:cast_safe(target) then return true end
        end
        if SPELL.Hurricane:is_learned() then
            if SPELL.Hurricane:cast_safe(target) then return true end
        end
        if SPELL.Starfire:cast_safe(target) then return true end
        if SPELL.Wrath:cast_safe(target) then return true end
    end

    return false
end

return M
