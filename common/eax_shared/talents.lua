-- talents.lua
-- Talent detection via spell presence

local talents = {}

local TALENT_SPELLS = {
    enrage = {12292, 12300, 12301, 12302, 12856},
    improved_execute = {12712, 12721, 12723},
    improved_kidney_shot = {14082, 14093},
    improved_aspects = {19116, 19118, 19120},
    demonic_embrace = {18693, 18694, 18695},
    shadow_mastery = {17824, 17825, 17826},
}

function talents.has_talent(talent_name)
    local spell_ids = TALENT_SPELLS[talent_name]
    if not spell_ids then return false end
    
    for _, spell_id in ipairs(spell_ids) do
        if core.spell_book.find_spell_by_id(spell_id) then
            return true
        end
    end
    return false
end

return talents
