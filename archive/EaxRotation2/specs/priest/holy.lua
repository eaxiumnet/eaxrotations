local izi = require("common/izi_sdk")

local SPELL = {
    FlashHeal      = izi.spell(25235, 25233, 10917, 10916, 10915, 9474, 9473, 9472, 2061),
    GreaterHeal    = izi.spell(25213, 25210, 25314, 10965, 10964, 10963, 2060),
    Renew          = izi.spell(25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139),
    PrayerOfMending= izi.spell(33076),
    CircleOfHealing= izi.spell(34866, 34865, 34864, 34863, 34861),
    PrayerOfHealing= izi.spell(25308, 25316, 10961, 10960, 996, 596),
    BindingHeal    = izi.spell(32546),
    DesperatePrayer= izi.spell(25437, 19243, 19242, 19241, 19240, 19238, 19236, 13908),
    InnerFire      = izi.spell(25431, 10952, 10951, 1006, 602, 7128, 588),
    PowerWordShield= izi.spell(25218, 25217, 10901, 10900, 10899, 10898, 6066, 6065, 3747, 600, 592, 17),
    Smite          = izi.spell(25364, 25363, 10934, 10933, 6060, 1004, 984, 598, 591, 585),
    HolyFire       = izi.spell(25384, 15261, 15267, 15266, 15265, 15264, 15263, 15262, 14914),
}

local INNER_FIRE = { 25431, 10952, 10951, 1006, 602, 7128, 588 }
local RENEW = { 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }
local WEAKENED_SOUL = { 6788 }
local HOLY_FIRE_DOT = { 25384, 15261, 15267, 15266, 15265, 15264, 15263, 15262, 14914 }

local M = {}

local function lowest_friend(me)
    local best, hp = me, me:get_health_percentage() or 100
    for _, unit in ipairs(izi.friends() or {}) do
        local unit_hp = unit and unit:get_health_percentage() or 100
        if unit_hp < hp then best, hp = unit, unit_hp end
    end
    return best, hp
end

function M.tick(me, target, enemies)
    if not me:is_in_combat() then return false end

    if me:buff_down(INNER_FIRE) and SPELL.InnerFire:cast_safe(me) then return true end

    local ally, hp = lowest_friend(me)
    local mana = me:mana_pct() or 100
    local self_hp = me:get_health_percentage() or 100

    if self_hp < 25 and SPELL.DesperatePrayer:is_learned() then
        if SPELL.DesperatePrayer:cast_safe(me) then return true end
    end
    if hp < 30 and ally:debuff_down(WEAKENED_SOUL) then
        if SPELL.PowerWordShield:cast_safe(ally) then return true end
    end
    if hp < 40 and SPELL.FlashHeal:cast_safe(ally) then return true end
    if hp < 55 and SPELL.PrayerOfMending:is_learned() then
        if SPELL.PrayerOfMending:cast_safe(ally) then return true end
    end
    if hp < 65 and SPELL.BindingHeal:is_learned() then
        if SPELL.BindingHeal:cast_safe(ally) then return true end
    end
    if hp < 75 and mana > 20 and SPELL.GreaterHeal:cast_safe(ally) then return true end
    if hp < 90 and ally:buff_down(RENEW) and SPELL.Renew:cast_safe(ally) then return true end
    if hp < 80 and SPELL.CircleOfHealing:is_learned() then
        if SPELL.CircleOfHealing:cast_safe(ally) then return true end
    end
    if hp < 75 and mana > 35 and SPELL.PrayerOfHealing:cast_safe(me) then return true end
    if target and target:debuff_down(HOLY_FIRE_DOT) and SPELL.HolyFire:cast_safe(target) then return true end
    if target and mana > 45 and SPELL.Smite:cast_safe(target) then return true end

    return false
end

return M
