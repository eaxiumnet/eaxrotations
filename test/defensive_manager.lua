-- defensive_manager.lua
-- Layered HP threshold defensive system for TBC Classic

local defensive_manager = {}

local DEFENSIVE_TIERS = {
    warrior = {
        -- TBC: Last Stand (Protection talent) - 30% max HP boost for 20s
        { hp = 0.60, spell_ids = {12975}, name = "last_stand" },
        -- TBC: Berserker Rage - immune to fear/incapacitate, generates rage
        { hp = 0.50, spell_ids = {18499}, name = "berserker_rage" },
        -- TBC: Shield Wall (requires shield - Prot/Arms) - 75% damage reduction
        { hp = 0.30, spell_ids = {871, 8538, 8539}, name = "shield_wall" },
    },
    rogue = {
        -- Cloak of Shadows: dispels all magic debuffs, 1-min CD
        { id = 31224, name = "cloak_of_shadows", hp_threshold = 0.80, type = "dispel" },
        { hp = 0.40, spell_ids = {5277}, name = "evasion" },
        { hp = 0.25, spell_ids = {1856}, name = "vanish" },
    },
    hunter = {
        { hp = 0.30, spell_ids = {5384}, name = "feign_death" },
    },
    paladin = {
        { hp = 0.25, spell_ids = {1044}, name = "hand_of_freedom" },
        { hp = 0.30, spell_ids = {642}, name = "divine_shield" },
        { hp = 0.50, spell_ids = {20217}, name = "blessing_of_sacrifice" },
    },
    druid = {
        { hp = 0.40, spell_ids = {22812}, name = "barkskin" },
        { hp = 0.30, spell_ids = {61336}, name = "survival_instincts" },
    },
    mage = {
        { hp = 0.20, spell_ids = {11958, 27619}, name = "ice_block" },
    },
    priest = {
        { hp = 0.30, spell_ids = {33206}, name = "pain_suppression" },
    },
    shaman = {
        { hp = 0.30, spell_ids = {30823}, name = "shamanistic_rage" },
    },
    warlock = {
        -- TBC: Drain Life as emergency self-heal
        { hp = 0.35, spell_ids = {27221, 11700, 11699, 3699, 1455, 1454, 689}, name = "drain_life" },
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
