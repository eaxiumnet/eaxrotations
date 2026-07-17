-- wotlk_data_sylvanas.lua -- WotLK 3.3.5a spell + item ID constants.
-- WHAT:  WotLK-only consumable, flask, elixir, food, drink, weapon buff, and bandage IDs.
-- WHEN:  loaded by shared modules when NS.is_wotlk() is true.
-- WHY:   keeps WotLK consumable data out of the TBC data module.
-- SAFETY: pure data; nil-tolerant key fetch.
-- DECISION: consumed via require(); no runtime side-effects.

local M = {}

M.ITEMS = {
    flasks = {
        frost_wyrm = 46376,
        endless_rage = 46377,
        pure_mojo = 46378,
        mighty_restoration_wotlk = 46379,
        stoneblood = 46380,
    },
    potions = {
        runic_healing = 33447,
        runic_mana = 33448,
        indestructible = 40093,
        haste_wotlk = 40070,
        wild_magic = 40211,
        speed_wotlk = 40212,
        mighty_thoughts = 40213,
        mighty_titan = 40214,
        potion_of_nightmares = 36934,
    },
    elixirs = {
        accuracy = 44331,
        armor_piercing = 44330,
        deadliness = 44327,
        expertise = 44329,
        lightning_speed = 44325,
        mighty_agility = 44328,
        mighty_strength = 44326,
        spirit = 44332,
        protection = 44333,
        mighty_defense = 44334,
        mighty_fortitude = 44335,
        spellpower = 44336,
        wisdom = 44337,
    },
    food = {
        fish_feast = 43015,
        dragonfin_filet = 43000,
        blackened_dragonfin = 42999,
        firecracker_salmon = 42998,
        spicy_fried_herring = 42997,
        spicy_blue_nettlefish = 42996,
        imperial_manta_steak = 42995,
        poached_northern_sculpin = 42994,
        rhinolicious_wormsteak = 42993,
        mighty_rhino_dogs = 42992,
        cuttlesteak = 42991,
        baked_manta_ray = 42990,
        grilled_sculpin = 42989,
        smoked_salmon = 42988,
        sweetened_soul = 44839,
        northrend_stew = 43268,
    },
    drinks = {
        honeymint_tea = 33454,
        pungent_seal_whey = 33444,
        refreshing_spring_water = 33025,
    },
    weapon_buffs = {
        shattrath_brilliant_wizard_oil = 34539,
        shattrath_brilliant_mana_oil = 34538,
        wizard_oil_wotlk = 22522,
        mana_oil_wotlk = 22521,
    },
    bandages = {
        frostweave = 34722,
        heavy_frostweave = 34721,
    },
}

M.BUFFS = {}

return M
