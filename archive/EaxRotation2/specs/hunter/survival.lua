local izi = require("common/izi_sdk")

local SPELL = {
    SteadyShot     = izi.spell(34120),
    ArcaneShot     = izi.spell(27019, 14287, 14286, 14285, 14284, 14283, 14282, 14281, 3044),
    MultiShot      = izi.spell(27021, 25294, 14290, 14289, 14288, 2643),
    SerpentSting   = izi.spell(27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978),
    ScorpidSting   = izi.spell(3043),
    ViperSting     = izi.spell(27018, 14280, 14279, 3034),
    WyvernSting    = izi.spell(27068, 24133, 24132, 19386),
    HuntersMark    = izi.spell(14325, 14324, 14323, 1130),
    KillCommand    = izi.spell(34026),
    RapidFire      = izi.spell(3045),
    Readiness      = izi.spell(23989),
    ExplosiveTrap  = izi.spell(27025, 14317, 14316, 13813),
    ConcussiveShot = izi.spell(5116),
    RaptorStrike   = izi.spell(27014, 14266, 14265, 14264, 14263, 14262, 14261, 14260, 2973),
    WingClip       = izi.spell(14268, 14267, 2974),
    MendPet        = izi.spell(27046, 13544, 13543, 13542, 3662, 3661, 3111, 136),
    CallPet        = izi.spell(883),
    RevivePet      = izi.spell(982),
    AspectHawk     = izi.spell(27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165),
    AspectViper    = izi.spell(34074),
}

local HUNTERS_MARK_DEBUFF = { 14325, 14324, 14323, 1130 }
local SERPENT_STING_DEBUFF = { 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }
local SCORPID_STING_DEBUFF = { 3043 }
local VIPER_STING_DEBUFF = { 27018, 14280, 14279, 3034 }
local WING_CLIP_DEBUFF = { 14268, 14267, 2974 }
local ASPECT_HAWK_BUFF = { 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 }
local ASPECT_VIPER_BUFF = { 34074 }

local M = {}

function M.tick(me, target, enemies)
    if not me:is_in_combat() then return false end

    local pet = me.get_pet and me:get_pet() or nil
    local mana = me:mana_pct() or 100

    if not pet and SPELL.CallPet:is_learned() then
        if SPELL.CallPet:cast_safe(me) then return true end
    end
    if pet and pet.is_alive and not pet:is_alive() and SPELL.RevivePet:is_learned() then
        if SPELL.RevivePet:cast_safe(me) then return true end
    end
    if pet and pet.get_health_percentage and pet:get_health_percentage() < 45 then
        if SPELL.MendPet:cast_safe(pet) then return true end
    end
    if mana < 20 and me:buff_down(ASPECT_VIPER_BUFF) then
        if SPELL.AspectViper:cast_safe(me) then return true end
    end
    if mana >= 30 and me:buff_down(ASPECT_HAWK_BUFF) then
        if SPELL.AspectHawk:cast_safe(me) then return true end
    end

    if target then
        if target:debuff_down(HUNTERS_MARK_DEBUFF) then
            if SPELL.HuntersMark:cast_safe(target) then return true end
        end
        if SPELL.RapidFire:is_learned() then
            if SPELL.RapidFire:cast_safe(me) then return true end
        end
        if SPELL.Readiness:is_learned() then
            if SPELL.Readiness:cast_safe(me) then return true end
        end
        if target:debuff_down(SCORPID_STING_DEBUFF) then
            if SPELL.ScorpidSting:cast_safe(target) then return true end
        end
        if mana < 40 and target:debuff_down(VIPER_STING_DEBUFF) then
            if SPELL.ViperSting:cast_safe(target) then return true end
        end
        if target:debuff_remains(SERPENT_STING_DEBUFF) < 3 then
            if SPELL.SerpentSting:cast_safe(target) then return true end
        end
        if target:is_casting() then
            if SPELL.WyvernSting:cast_safe(target) then return true end
            if SPELL.ConcussiveShot:cast_safe(target) then return true end
        end
        if SPELL.ExplosiveTrap:is_learned() then
            if SPELL.ExplosiveTrap:cast_safe(me) then return true end
        end
        if pet and SPELL.KillCommand:is_learned() then
            if SPELL.KillCommand:cast_safe(target) then return true end
        end
        if target:debuff_down(WING_CLIP_DEBUFF) then
            if SPELL.WingClip:cast_safe(target) then return true end
        end
        if SPELL.MultiShot:cast_safe(target) then return true end
        if SPELL.SteadyShot:cast_safe(target) then return true end
        if SPELL.ArcaneShot:cast_safe(target) then return true end
        if SPELL.RaptorStrike:cast_safe(target) then return true end
    end

    return false
end

return M
