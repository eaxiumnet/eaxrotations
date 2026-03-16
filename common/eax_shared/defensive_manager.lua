-- defensive_manager.lua
-- Layered HP threshold defensive system

local defensive_manager = {}

local DEFENSIVE_TIERS = {
    warrior = {
        { hp = 0.90, spell_ids = {12282, 12184}, name = "victory_rush" },
        { hp = 0.70, spell_ids = {12975}, name = "last_stand" },
        { hp = 0.50, spell_ids = {55694, 55693}, name = "enraged_regeneration" },
        { hp = 0.30, spell_ids = {871, 12976}, name = "shield_wall" },
    },
    rogue = {
        { hp = 0.40, spell_ids = {5277}, name = "evasion" },
        { hp = 0.25, spell_ids = {1856, 1857}, name = "vanish" },
    },
    hunter = {
        { hp = 0.30, spell_ids = {5384}, name = "feign_death" },
    },
    paladin = {
        { hp = 0.30, spell_ids = {642}, name = "divine_shield" },
        { hp = 0.40, spell_ids = {1044}, name = "blessing_of_protection" },
        { hp = 0.50, spell_ids = {20217}, name = "blessing_of_sacrifice" },
    },
    druid = {
        { hp = 0.40, spell_ids = {22812, 22842}, name = "barkskin" },
        { hp = 0.30, spell_ids = {61336}, name = "survival_instincts" },
    },
    mage = {
        { hp = 0.20, spell_ids = {45438}, name = "ice_block" },
    },
    priest = {
        { hp = 0.30, spell_ids = {33206}, name = "pain_suppression" },
    },
    shaman = {
        { hp = 0.30, spell_ids = {30823}, name = "shamanistic_rage" },
    },
    warlock = {
        { hp = 0.25, spell_ids = {47891}, name = "soul_harvest" },
    },
    deathknight = {
        { hp = 0.30, spell_ids = {48792}, name = "icebound_fortitude" },
    },
}

function defensive_manager.get_defensives(class_name)
    return DEFENSIVE_TIERS[class_name] or {}
end

function defensive_manager.get_defensive(hp_pct, class_name)
    local defensives = defensive_manager.get_defensives(class_name)
    for _, def in ipairs(defensives) do
        if hp_pct <= def.hp then
            return def
        end
    end
    return nil
end

function defensive_manager.try_defensive(me, class_name, utils_module)
    local hp_pct = me:get_health_percentage() / 100
    local defensive = defensive_manager.get_defensive(hp_pct, class_name)
    
    if not defensive then return false end
    
    local spell_id = utils_module.resolve_spell_id(defensive.spell_ids)
    if not spell_id then return false end
    
    if not utils_module.can_cast_self(spell_id, me) then return false end
    if utils_module.cast_self(spell_id, me) then
        return true
    end
    
    return false
end

return defensive_manager
