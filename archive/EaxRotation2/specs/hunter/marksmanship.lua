local izi = require("common/izi_sdk")

local SPELL = {
    AimedShot      = izi.spell(27065, 20904, 20903, 20902, 20901, 20900, 19434),
    SteadyShot     = izi.spell(34120),
    ArcaneShot     = izi.spell(27019, 14287, 14286, 14285, 14284, 14283, 14282, 14281, 3044),
    MultiShot      = izi.spell(27021, 25294, 14290, 14289, 14288, 2643),
    SerpentSting   = izi.spell(27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978),
    ViperSting     = izi.spell(27018, 14280, 14279, 3034),
    HuntersMark    = izi.spell(14325, 14324, 14323, 1130),
    KillCommand    = izi.spell(34026),
    SilencingShot  = izi.spell(34490),
    RapidFire      = izi.spell(3045),
    Readiness      = izi.spell(23989),
    MendPet        = izi.spell(27046, 13544, 13543, 13542, 3662, 3661, 3111, 136),
    CallPet        = izi.spell(883),
    RevivePet      = izi.spell(982),
    FeignDeath     = izi.spell(5384),
    FreezingTrap   = izi.spell(14311, 14310, 1499),
    AspectHawk     = izi.spell(27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165),
    AspectViper    = izi.spell(34074),
}

local HUNTERS_MARK_DEBUFF = { 14325, 14324, 14323, 1130 }
local SERPENT_STING_DEBUFF = { 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }
local VIPER_STING_DEBUFF = { 27018, 14280, 14279, 3034 }
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
        if target:is_casting() and SPELL.SilencingShot:is_learned() then
            if SPELL.SilencingShot:cast_safe(target) then return true end
        end
        if target:debuff_down(HUNTERS_MARK_DEBUFF) then
            if SPELL.HuntersMark:cast_safe(target) then return true end
        end
        if (me:get_health_percentage() or 100) < 25 then
            if SPELL.FeignDeath:cast_safe(me) then return true end
        end
        if SPELL.RapidFire:is_learned() then
            if SPELL.RapidFire:cast_safe(me) then return true end
        end
        if SPELL.Readiness:is_learned() then
            if SPELL.Readiness:cast_safe(me) then return true end
        end
        if pet and SPELL.KillCommand:is_learned() then
            if SPELL.KillCommand:cast_safe(target) then return true end
        end
        if target:debuff_remains(SERPENT_STING_DEBUFF) < 3 then
            if SPELL.SerpentSting:cast_safe(target) then return true end
        end
        if mana < 40 and target:debuff_down(VIPER_STING_DEBUFF) then
            if SPELL.ViperSting:cast_safe(target) then return true end
        end
        if SPELL.AimedShot:cast_safe(target) then return true end
        if SPELL.MultiShot:cast_safe(target) then return true end
        if SPELL.SteadyShot:cast_safe(target) then return true end
        if SPELL.ArcaneShot:cast_safe(target) then return true end
    end

    return false
end

return M
