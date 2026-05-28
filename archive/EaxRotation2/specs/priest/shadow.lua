local izi = require("common/izi_sdk")

local SPELL = {
    Shadowform     = izi.spell(15473),
    InnerFire      = izi.spell(25431, 10952, 10951, 1006, 602, 7128, 588),
    PowerWordShield= izi.spell(25218, 25217, 10901, 10900, 10899, 10898, 6066, 6065, 3747, 600, 592, 17),
    VampiricTouch  = izi.spell(34917, 34916, 34914),
    ShadowWordPain = izi.spell(25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589),
    VampiricEmbrace= izi.spell(15286),
    MindBlast      = izi.spell(25375, 25372, 10947, 10946, 10945, 8106, 8105, 8104, 8103, 8102, 8092),
    MindFlay       = izi.spell(25387, 18807, 17314, 17313, 17312, 17311, 15407),
    ShadowWordDeath= izi.spell(32996, 32379),
    DevouringPlague= izi.spell(25467, 19280, 19279, 19278, 19277, 19276, 2944),
    Shadowfiend    = izi.spell(34433),
    Silence        = izi.spell(15487),
    Fade           = izi.spell(25429, 10942, 10941, 9592, 9579, 9578, 586),
}

local SHADOWFORM = { 15473 }
local INNER_FIRE = { 25431, 10952, 10951, 1006, 602, 7128, 588 }
local WEAKENED_SOUL = { 6788 }
local VT = { 34917, 34916, 34914 }
local SWP = { 25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589 }
local VE = { 15286 }
local DP = { 25467, 19280, 19279, 19278, 19277, 19276, 2944 }

local M = {}

function M.tick(me, target, enemies)
    if not me:is_in_combat() then return false end
    if me:buff_down(SHADOWFORM) and SPELL.Shadowform:is_learned() then
        if SPELL.Shadowform:cast_safe(me) then return true end
    end
    if me:buff_down(INNER_FIRE) and SPELL.InnerFire:cast_safe(me) then return true end

    local hp = me:get_health_percentage() or 100
    local mana = me:mana_pct() or 100
    if hp < 35 and me:debuff_down(WEAKENED_SOUL) then
        if SPELL.PowerWordShield:cast_safe(me) then return true end
    end
    if mana < 35 and SPELL.Shadowfiend:is_learned() and target then
        if SPELL.Shadowfiend:cast_safe(target) then return true end
    end
    if hp < 45 and SPELL.Fade:cast_safe(me) then return true end

    if target then
        if target:is_casting() and SPELL.Silence:is_learned() then
            if SPELL.Silence:cast_safe(target) then return true end
        end
        if target:debuff_remains(VT) < 2 and SPELL.VampiricTouch:cast_safe(target) then return true end
        if target:debuff_remains(SWP) < 2 and SPELL.ShadowWordPain:cast_safe(target) then return true end
        if target:debuff_down(VE) and SPELL.VampiricEmbrace:cast_safe(target) then return true end
        if target:debuff_remains(DP) < 2 and SPELL.DevouringPlague:is_learned() then
            if SPELL.DevouringPlague:cast_safe(target) then return true end
        end
        if SPELL.MindBlast:cast_safe(target) then return true end
        if hp > 70 and SPELL.ShadowWordDeath:is_learned() then
            if SPELL.ShadowWordDeath:cast_safe(target) then return true end
        end
        if SPELL.MindFlay:cast_safe(target) then return true end
    end

    return false
end

return M
