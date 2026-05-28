local izi = require("common/izi_sdk")

local SPELL = {
    BearForm       = izi.spell(9634, 5487),
    MangleBear     = izi.spell(33987, 33986, 33878),
    Lacerate       = izi.spell(33745),
    Maul           = izi.spell(26996, 9881, 9880, 9745, 8972, 6809, 6808, 6807),
    SwipeBear      = izi.spell(26997, 9908, 9754, 769, 780, 779),
    DemoralizingRoar = izi.spell(26998, 9898, 9747, 9490, 1735, 99),
    FaerieFireFeral = izi.spell(27011, 17392, 17391, 17390, 16857),
    FeralCharge    = izi.spell(16979),
    Bash           = izi.spell(8983, 6798, 5211),
    Barkskin       = izi.spell(22812),
    FrenziedRegeneration = izi.spell(26999, 22896, 22895, 22842),
    Enrage         = izi.spell(5229),
}

local BEAR_FORM_1 = 5487
local BEAR_FORM_2 = 9634
local FAERIE_FIRE_DEBUFF = { 27011, 17392, 17391, 17390, 16857, 26993, 9907, 9749, 778, 770 }
local LACERATE_DEBUFF = { 33745 }
local MANGLE_DEBUFF = { 33987, 33986, 33878, 33983, 33982, 33876 }
local DEMO_ROAR_DEBUFF = { 26998, 9898, 9747, 9490, 1735, 99, 25203, 11556, 6190, 1160 }

local M = {}

function M.tick(me, target, enemies)
    if not me:is_in_combat() then return false end

    if not me:has_buff(BEAR_FORM_1) and not me:has_buff(BEAR_FORM_2) then
        if SPELL.BearForm:cast_safe(me) then return true end
    end

    local hp = me:get_health_percentage() or 100
    if hp < 45 and SPELL.Barkskin:is_learned() then
        if SPELL.Barkskin:cast_safe(me) then return true end
    end
    if hp < 30 and SPELL.FrenziedRegeneration:is_learned() then
        if SPELL.FrenziedRegeneration:cast_safe(me) then return true end
    end
    if SPELL.Enrage:is_learned() then
        if SPELL.Enrage:cast_safe(me) then return true end
    end

    if target then
        if target:is_casting() then
            if SPELL.Bash:cast_safe(target) then return true end
            if SPELL.FeralCharge:cast_safe(target) then return true end
        end
        if target:debuff_remains(FAERIE_FIRE_DEBUFF) < 5 then
            if SPELL.FaerieFireFeral:cast_safe(target) then return true end
        end
        if target:debuff_remains(DEMO_ROAR_DEBUFF) < 5 then
            if SPELL.DemoralizingRoar:cast_safe(me) then return true end
        end
        if target:debuff_remains(MANGLE_DEBUFF) < 3 then
            if SPELL.MangleBear:cast_safe(target) then return true end
        end
        if target:debuff_remains(LACERATE_DEBUFF) < 3 then
            if SPELL.Lacerate:cast_safe(target) then return true end
        end
        if SPELL.SwipeBear:cast_safe(me) then return true end
        if SPELL.Maul:cast_safe(target) then return true end
    end

    return false
end

return M
