-- talent_manager.lua  |  Full Talent Tree Parsing  |  TBC
-- Detects BM Hunter talents via spell resolution, applies damage multipliers

local talent_manager = {}
local spell_resolver = require("spell_resolver")

talent_manager.talents = {
    go_for_the_throat = false,
    frenzy = false,
    ferocious_inspiration = false,
    bestial_wrath = false,
    the_beast_within = false,
    unleashed_fury = false,
    serpents_swiftness = false,
    focused_fire = false,
    improved_aspects = 0,
    kill_command = false,
    unmanned = false,
    roar_of_sacrifice = false,
}

talent_manager.multipliers = {
    pet_damage = 1.0,
    player_damage = 1.0,
    ranged_speed = 1.0,
}

talent_manager.initialized = false

local TALENT_SPELLS = {
    go_for_the_throat = 34954,
    frenzy = 19625,
    ferocious_inspiration = 34460,
    bestial_wrath = 19574,
    the_beast_within = 34692,
    unleashed_fury = 52402,
    serpents_swiftness = 34026,
    focused_fire = 19624,
    kill_command = 34026,
    roar_of_sacrifice = 34655,
}

function talent_manager.init()
    talent_manager.initialized = true
end

function talent_manager.update()
    if not talent_manager.update_counter then talent_manager.update_counter = 0 end
    if talent_manager.update_counter < 3 then
        talent_manager.update_counter = talent_manager.update_counter + 1
        return
    end
    talent_manager.update_counter = 0
    if not talent_manager.initialized then
        talent_manager.init()
    end

    talent_manager.talents.go_for_the_throat = core.spell_book.is_spell_learned(TALENT_SPELLS.go_for_the_throat)
    talent_manager.talents.frenzy = core.spell_book.is_spell_learned(TALENT_SPELLS.frenzy)
    talent_manager.talents.ferocious_inspiration = core.spell_book.is_spell_learned(TALENT_SPELLS.ferocious_inspiration)
    talent_manager.talents.bestial_wrath = core.spell_book.is_spell_learned(TALENT_SPELLS.bestial_wrath)
    talent_manager.talents.the_beast_within = core.spell_book.is_spell_learned(TALENT_SPELLS.the_beast_within)
    talent_manager.talents.unleashed_fury = core.spell_book.is_spell_learned(TALENT_SPELLS.unleashed_fury)
    talent_manager.talents.serpent_swiftness = core.spell_book.is_spell_learned(TALENT_SPELLS.serpents_swiftness)
    talent_manager.talents.focused_fire = core.spell_book.is_spell_learned(TALENT_SPELLS.focused_fire)
    talent_manager.talents.kill_command = core.spell_book.is_spell_learned(TALENT_SPELLS.kill_command)
    talent_manager.talents.roar_of_sacrifice = core.spell_book.is_spell_learned(TALENT_SPELLS.roar_of_sacrifice)

    local t = talent_manager.talents

    talent_manager.multipliers.pet_damage = 1.0
    if t.unleashed_fury then
        talent_manager.multipliers.pet_damage = talent_manager.multipliers.pet_damage * 1.04
    end
    if t.frenzy then
        talent_manager.multipliers.pet_damage = talent_manager.multipliers.pet_damage * 1.1
    end

    talent_manager.multipliers.player_damage = 1.0
    if t.the_beast_within then
        talent_manager.multipliers.player_damage = talent_manager.multipliers.player_damage * 1.1
    end
    if t.focused_fire then
        talent_manager.multipliers.player_damage = talent_manager.multipliers.player_damage * 1.03
    end

    talent_manager.multipliers.ranged_speed = 1.0
    if t.serpent_swiftness then
        talent_manager.multipliers.ranged_speed = talent_manager.multipliers.ranged_speed * 1.04
    end

    local log_str = "[Talent AI]"
    if t.bestial_wrath then log_str = log_str .. " BW" end
    if t.the_beast_within then log_str = log_str .. " TBW" end
    if t.frenzy then log_str = log_str .. " Frenzy" end
    if t.unleashed_fury then log_str = log_str .. " UF" end
    if t.serpent_swiftness then log_str = log_str .. " SS" end
    if t.go_for_the_throat then log_str = log_str .. " GftT" end
    if t.ferocious_inspiration then log_str = log_str .. " FI" end
    core.log(log_str .. string.format(" pet_dmg=%.2f player_dmg=%.2f ranged_speed=%.2f",
        talent_manager.multipliers.pet_damage,
        talent_manager.multipliers.player_damage,
        talent_manager.multipliers.ranged_speed))

    -- Invalidate spell ID cache when talents change (player respecced)
    spell_resolver.invalidate_cache()
end

function talent_manager.has_talent(name)
    return talent_manager.talents[name] == true
end

function talent_manager.get_multiplier(mtype)
    return talent_manager.multipliers[mtype] or 1.0
end

function talent_manager.get_pet_damage_multiplier()
    return talent_manager.multipliers.pet_damage
end

function talent_manager.get_player_damage_multiplier()
    return talent_manager.multipliers.player_damage
end

function talent_manager.get_ranged_speed_multiplier()
    return talent_manager.multipliers.ranged_speed
end

function talent_manager.should_burst(me)
    local has_bw = talent_manager.has_talent("bestial_wrath")
    local has_tbw = talent_manager.has_talent("the_beast_within")
    return has_bw and has_tbw
end

function talent_manager.pet_focus_on_crit()
    return talent_manager.has_talent("go_for_the_throat")
end

function talent_manager.party_damage_on_pet_crit()
    return talent_manager.has_talent("ferocious_inspiration")
end

return talent_manager
