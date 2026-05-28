local izi = require("common/izi_sdk")

local SPELL = {
    InnerFire      = izi.spell(25431, 10952, 10951, 1006, 602, 7128, 588),
    PowerWordShield= izi.spell(25218, 25217, 10901, 10900, 10899, 10898, 6066, 6065, 3747, 600, 592, 17),
    Renew          = izi.spell(25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139),
    HolyFire       = izi.spell(25384, 15261, 15267, 15266, 15265, 15264, 15263, 15262, 14914),
    Smite          = izi.spell(25364, 25363, 10934, 10933, 6060, 1004, 984, 598, 591, 585),
    ShadowWordPain = izi.spell(25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589),
    MindBlast      = izi.spell(25375, 25372, 10947, 10946, 10945, 8106, 8105, 8104, 8103, 8102, 8092),
    ShadowWordDeath= izi.spell(32996, 32379),
    DevouringPlague= izi.spell(25467, 19280, 19279, 19278, 19277, 19276, 2944),
    Shadowfiend    = izi.spell(34433),
}

local INNER_FIRE = { 25431, 10952, 10951, 1006, 602, 7128, 588 }
local RENEW = { 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }
local WEAKENED_SOUL = { 6788 }
local HOLY_FIRE_DOT = { 25384, 15261, 15267, 15266, 15265, 15264, 15263, 15262, 14914 }
local SWP = { 25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589 }
local DP = { 25467, 19280, 19279, 19278, 19277, 19276, 2944 }

local M = {}

function M.tick(me, target, enemies)
    if not me:is_in_combat() then return false end

    if me:buff_down(INNER_FIRE) and SPELL.InnerFire:cast_safe(me) then return true end

    local hp = me:get_health_percentage() or 100
    local mana = me:mana_pct() or 100
    if hp < 45 and me:debuff_down(WEAKENED_SOUL) then
        if SPELL.PowerWordShield:cast_safe(me) then return true end
    end
    if hp < 70 and me:buff_down(RENEW) then
        if SPELL.Renew:cast_safe(me) then return true end
    end
    if mana < 35 and target and SPELL.Shadowfiend:is_learned() then
        if SPELL.Shadowfiend:cast_safe(target) then return true end
    end

    if target then
        if target:debuff_remains(HOLY_FIRE_DOT) < 2 then
            if SPELL.HolyFire:cast_safe(target) then return true end
        end
        if target:debuff_down(SWP) and mana > 30 then
            if SPELL.ShadowWordPain:cast_safe(target) then return true end
        end
        if target:debuff_remains(DP) < 2 and SPELL.DevouringPlague:is_learned() then
            if SPELL.DevouringPlague:cast_safe(target) then return true end
        end
        if mana > 25 and SPELL.MindBlast:cast_safe(target) then return true end
        if hp > 70 and SPELL.ShadowWordDeath:is_learned() then
            if SPELL.ShadowWordDeath:cast_safe(target) then return true end
        end
        if SPELL.Smite:cast_safe(target) then return true end
    end

    return false
end

return M
