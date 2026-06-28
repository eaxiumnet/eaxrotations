-- Shared Helper: Consumable Manager
-- ============================================================================
-- ============================================================================

local _G = _G
local NS = _G.EaxRotations
local M = {}

local type = type
local EMPTY = {}
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { ITEMS = {}, BUFFS = {} } end

-- Throttle: don't check consumables more than once per 3s
local _last_check = 0

-- ============================================================================
-- TBC CONSUMABLE ITEM IDs
-- ============================================================================

local FLASKS = TBC.ITEMS.flasks or EMPTY
local COMBAT_POTIONS = TBC.ITEMS.potions or EMPTY
local ELIXIRS = TBC.ITEMS.elixirs or EMPTY
local FOOD = TBC.ITEMS.food or EMPTY
local DRINKS = TBC.ITEMS.drinks or EMPTY
local WEAPON_BUFFS = TBC.ITEMS.weapon_buffs or EMPTY
local DRUMS = TBC.ITEMS.drums or EMPTY
local HEALTHSTONES = TBC.ITEMS.healthstones or EMPTY
local RUNES = TBC.ITEMS.runes or EMPTY
local BANDAGES = TBC.ITEMS.bandages or EMPTY
local SCROLLS = TBC.ITEMS.scrolls or EMPTY

local ACTIVE_BUFFS = TBC.BUFFS or EMPTY

-- ============================================================================
-- ROLE DETECTION
-- ============================================================================

local ENUMS = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4,
    PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11,
}

local HEALING_PLAYSTYLES = {
    holy = true, discipline = true, restoration = true, resto = true,
}

function M.get_role(class_id, active_playstyle)
    if active_playstyle and HEALING_PLAYSTYLES[active_playstyle:lower()] then
        return "healer"
    end
    if class_id == ENUMS.WARRIOR then
        return "melee" -- arms/fury, protection handled separately
    elseif class_id == ENUMS.PALADIN then
        return "melee" -- ret/prot
    elseif class_id == ENUMS.HUNTER then
        return "ranged"
    elseif class_id == ENUMS.ROGUE then
        return "melee"
    elseif class_id == ENUMS.PRIEST then
        return "caster"
    elseif class_id == ENUMS.SHAMAN then
        if active_playstyle and active_playstyle:lower() == "enhancement" then
            return "melee"
        end
        return "caster" -- elemental/restoration
    elseif class_id == ENUMS.MAGE then
        return "caster"
    elseif class_id == ENUMS.WARLOCK then
        return "caster"
    elseif class_id == ENUMS.DRUID then
        if active_playstyle then
            local ap = active_playstyle:lower()
            if ap == "cat" or ap == "bear" or ap == "feral" then
                return "melee"
            end
        end
        return "caster" -- balance/resto
    end
    return "caster"
end

-- ============================================================================
-- HELPERS
-- ============================================================================

local function item_ready(item_id)
    if not item_id then return false end
    if type(NS.is_item_ready) == "function" then
        local ok, ready = pcall(NS.is_item_ready, item_id)
        if ok then return ready == true end
    end
    return true -- unknown state = assume ready
end

local function has_item(item_id)
    if not item_id then return false end
    if type(NS.has_item) ~= "function" then return true end
    local ok, result = pcall(NS.has_item, item_id)
    if not ok then return true end
    return result == true
end

local function player_has_any_buff(ids)
    if type(ids) ~= "table" then return false end
    local me = (NS.GetPlayer and NS.GetPlayer()) or nil
    if not me then return false end
    if type(NS.has_player_buff) == "function" then
        local ok, result = pcall(NS.has_player_buff, ids)
        if ok and result == true then return true end
    end
    if type(NS.buff_up) == "function" then
        local ok, result = pcall(NS.buff_up, me, ids)
        if ok and result == true then return true end
    end
    if type(NS.has_buff) == "function" then
        for i = 1, #ids do
            local ok, result = pcall(NS.has_buff, me, ids[i])
            if ok and result == true then return true end
        end
    end
    return false
end

local function has_any_weapon_enchant()
    local weapon = NS and NS.WeaponImbueManager
    if type(weapon) ~= "table" then return false end
    if type(weapon.get_status) ~= "function" then return false end
    local ok, status = pcall(weapon.get_status)
    if not ok or type(status) ~= "table" then return false end
    return status.mh_imbue ~= nil or status.oh_imbue ~= nil
end

local function use_item(item_id, target, log_msg)
    if not item_id then return false end
    if not has_item(item_id) then return false end
    if not item_ready(item_id) then return false end
    local use_fn = NS.use_item_by_id
    local target_unit = target or (NS.GetPlayer and NS.GetPlayer()) or nil
    if type(use_fn) ~= "function" then return false end
    local ok, result = pcall(use_fn, item_id, target_unit)
    return ok and result ~= false
end

local function try_use_first(items, target, log_prefix)
    if type(items) ~= "table" then return false end
    for i = 1, #items do
        local id = items[i]
        if use_item(id, target, log_prefix .. " (item " .. tostring(id) .. ")") then
            return true
        end
    end
    return false
end

-- ============================================================================
-- CONSUMABLE ACTIONS
-- ============================================================================

function M.use_healthstone(context)
    if not context or (context.hp or 100) > 50 then return false end
    return try_use_first(HEALTHSTONES, context.me, "Healthstone")
end

function M.use_mana_potion(context)
    if not context or (context.mana_pct or 100) > 40 then return false end
    local ids = {
        COMBAT_POTIONS.super_mana,
        COMBAT_POTIONS.fel_mana,
        COMBAT_POTIONS.super_rejuvenation,
    }
    for i = 1, #ids do
        if use_item(ids[i], context.me, "Mana Potion") then return true end
    end
    return false
end

function M.use_health_potion(context)
    if not context or (context.hp or 100) > 35 then return false end
    if use_item(COMBAT_POTIONS.nightmare_seed, context.me, "Nightmare Seed") then return true end
    if use_item(COMBAT_POTIONS.super_healing, context.me, "Super Healing Potion") then return true end
    if use_item(COMBAT_POTIONS.fel_regeneration, context.me, "Fel Regeneration Potion") then return true end
    if use_item(COMBAT_POTIONS.super_rejuvenation, context.me, "Super Rejuvenation Potion") then return true end
    return false
end

function M.use_combat_potion(context)
    if not context then return false end
    if player_has_any_buff(ACTIVE_BUFFS.potions) then return false end
    local role = M.get_role(context.player_class, context.active_playstyle)
    if role == "caster" or role == "healer" then
        -- Priority: Destruction > Haste > Mana.
        if use_item(COMBAT_POTIONS.destruction, nil, "Destruction Potion") then return true end
        if use_item(COMBAT_POTIONS.haste, nil, "Haste Potion") then return true end
    else
        -- Melee/ranged: Haste > Heroic/Insane Strength > Destruction.
        if use_item(COMBAT_POTIONS.haste, nil, "Haste Potion") then return true end
        if use_item(COMBAT_POTIONS.heroic, nil, "Heroic Potion") then return true end
        if use_item(COMBAT_POTIONS.insane_strength, nil, "Insane Strength Potion") then return true end
        if use_item(COMBAT_POTIONS.destruction, nil, "Destruction Potion") then return true end
    end
    return false
end

function M.use_flask(context)
    if not context then return false end
    if player_has_any_buff(ACTIVE_BUFFS.flasks) then return false end
    local role = M.get_role(context.player_class, context.active_playstyle)
    if role == "melee" or role == "ranged" then
        if use_item(FLASKS.shattrath_relentless_assault, context.me, "Shattrath Flask of Relentless Assault") then return true end
        return use_item(FLASKS.relentless_assault, context.me, "Flask of Relentless Assault")
    elseif role == "caster" then
        if use_item(FLASKS.shattrath_supreme_power, context.me, "Shattrath Flask of Supreme Power") then return true end
        if use_item(FLASKS.supreme_power, context.me, "Flask of Supreme Power") then return true end
        if use_item(FLASKS.shattrath_blinding_light, context.me, "Shattrath Flask of Blinding Light") then return true end
        if use_item(FLASKS.blinding_light, context.me, "Flask of Blinding Light") then return true end
        if use_item(FLASKS.shattrath_pure_death, context.me, "Shattrath Flask of Pure Death") then return true end
        return use_item(FLASKS.pure_death, context.me, "Flask of Pure Death")
    elseif role == "healer" then
        if use_item(FLASKS.shattrath_mighty_restoration, context.me, "Shattrath Flask of Mighty Restoration") then return true end
        if use_item(FLASKS.mighty_restoration, context.me, "Flask of Mighty Restoration") then return true end
        return use_item(FLASKS.distilled_wisdom, context.me, "Flask of Distilled Wisdom")
    end
    if use_item(FLASKS.shattrath_fortification, context.me, "Shattrath Flask of Fortification") then return true end
    if use_item(FLASKS.fortification, context.me, "Flask of Fortification") then return true end
    return use_item(FLASKS.titans, context.me, "Flask of the Titans")
end

function M.use_elixir(context)
    if not context then return false end
    if player_has_any_buff(ACTIVE_BUFFS.flasks) then return false end
    local role = M.get_role(context.player_class, context.active_playstyle)
    if role == "ranged" then
        if use_item(ELIXIRS.major_agility, context.me, "Elixir of Major Agility") then return true end
        return use_item(ELIXIRS.major_mageblood, context.me, "Elixir of Major Mageblood")
    elseif role == "melee" then
        if use_item(ELIXIRS.major_strength, context.me, "Elixir of Major Strength") then return true end
        return use_item(ELIXIRS.major_agility, context.me, "Elixir of Major Agility")
    elseif role == "caster" then
        if use_item(ELIXIRS.adept, context.me, "Adept's Elixir") then return true end
        if use_item(ELIXIRS.major_firepower, context.me, "Elixir of Major Firepower") then return true end
        if use_item(ELIXIRS.major_frost_power, context.me, "Elixir of Major Frost Power") then return true end
        if use_item(ELIXIRS.major_shadow_power, context.me, "Elixir of Major Shadow Power") then return true end
        return use_item(ELIXIRS.major_mageblood, context.me, "Elixir of Major Mageblood")
    elseif role == "healer" then
        if use_item(ELIXIRS.draenic_wisdom, context.me, "Elixir of Draenic Wisdom") then return true end
        if use_item(ELIXIRS.major_mageblood, context.me, "Elixir of Major Mageblood") then return true end
        return use_item(ELIXIRS.major_fortitude, context.me, "Elixir of Major Fortitude")
    end
    return false
end

function M.use_food(context)
    if not context then return false end
    if player_has_any_buff(ACTIVE_BUFFS.food) or player_has_any_buff(ACTIVE_BUFFS.refreshment) then return false end
    local role = M.get_role(context.player_class, context.active_playstyle)
    if role == "melee" then
        if use_item(FOOD.spicy_hot_talbuk, nil, "Spicy Hot Talbuk") then return true end
        if use_item(FOOD.warp_burger, nil, "Warp Burger") then return true end
        return use_item(FOOD.grilled_mudfish, nil, "Grilled Mudfish")
    elseif role == "ranged" then
        if use_item(FOOD.ravager_dog, nil, "Ravager Dog") then return true end
        if use_item(FOOD.spicy_hot_talbuk, nil, "Spicy Hot Talbuk") then return true end
        return use_item(FOOD.warp_burger, nil, "Warp Burger")
    elseif role == "caster" then
        if use_item(FOOD.blackened_basilisk, nil, "Blackened Basilisk") then return true end
        if use_item(FOOD.crunchy_serpent, nil, "Crunchy Serpent") then return true end
        return use_item(FOOD.poached_bluefish, nil, "Poached Bluefish")
    elseif role == "healer" then
        if use_item(FOOD.golden_fish_sticks, nil, "Golden Fish Sticks") then return true end
        return use_item(FOOD.blackened_sporefish, nil, "Blackened Sporefish")
    end
    return use_item(FOOD.roasted_clefthoof, nil, "Roasted Clefthoof")
end

function M.use_drink(context)
    if not context or (context.mana_pct or 100) > 65 then return false end
    if player_has_any_buff(ACTIVE_BUFFS.drink) or player_has_any_buff(ACTIVE_BUFFS.refreshment) then return false end
    if use_item(DRINKS.conjured_manna_biscuit, nil, "Conjured Manna Biscuit") then return true end
    if use_item(DRINKS.conjured_mountain_spring_water, nil, "Conjured Mountain Spring Water") then return true end
    if use_item(DRINKS.filtered_draenic_water, nil, "Filtered Draenic Water") then return true end
    if use_item(DRINKS.star_tears, nil, "Star's Tears") then return true end
    return use_item(DRINKS.purified_draenic_water, nil, "Purified Draenic Water")
end

function M.use_weapon_buff(context)
    if has_any_weapon_enchant() then return false end
    local role = M.get_role(context.player_class, context.active_playstyle)
    if role == "caster" or role == "healer" then
        if use_item(WEAPON_BUFFS.superior_wizard_oil, nil, "Superior Wizard Oil") then return true end
        if use_item(WEAPON_BUFFS.brilliant_wizard_oil, nil, "Brilliant Wizard Oil") then return true end
        if use_item(WEAPON_BUFFS.superior_mana_oil, nil, "Superior Mana Oil") then return true end
        return use_item(WEAPON_BUFFS.brilliant_mana_oil, nil, "Brilliant Mana Oil")
    else
        if use_item(WEAPON_BUFFS.adamantite_sharpening_stone, nil, "Adamantite Sharpening Stone") then return true end
        if use_item(WEAPON_BUFFS.adamantite_weightstone, nil, "Adamantite Weightstone") then return true end
        if use_item(WEAPON_BUFFS.fel_sharpening_stone, nil, "Fel Sharpening Stone") then return true end
        return use_item(WEAPON_BUFFS.fel_weightstone, nil, "Fel Weightstone")
    end
end

function M.use_drums(context)
    if player_has_any_buff(ACTIVE_BUFFS.drums) then return false end
    if use_item(DRUMS.battle, nil, "Drums of Battle") then return true end
    if use_item(DRUMS.war, nil, "Drums of War") then return true end
    if use_item(DRUMS.speed, nil, "Drums of Speed") then return true end
    return false
end

function M.use_rune(context)
    if not context or (context.mana_pct or 100) > 40 then return false end
    if use_item(RUNES.dark, nil, "Dark Rune") then return true end
    return use_item(RUNES.demonic, nil, "Demonic Rune")
end

function M.use_bandage(context)
    if not context or context.in_combat ~= true or (context.hp or 100) > 30 then return false end
    if use_item(BANDAGES.heavy_netherweave, context.me, "Heavy Netherweave Bandage") then return true end
    if use_item(BANDAGES.netherweave, context.me, "Netherweave Bandage") then return true end
    if use_item(BANDAGES.heavy_runecloth, context.me, "Heavy Runecloth Bandage") then return true end
    return use_item(BANDAGES.runecloth, context.me, "Runecloth Bandage")
end

function M.use_scroll(context)
    if not context or player_has_any_buff(ACTIVE_BUFFS.scrolls) then return false end
    local role = M.get_role(context.player_class, context.active_playstyle)
    if role == "melee" or role == "ranged" then
        if use_item(SCROLLS.agility_v, context.me, "Scroll of Agility V") then return true end
        return use_item(SCROLLS.strength_v, context.me, "Scroll of Strength V")
    elseif role == "caster" then
        if use_item(SCROLLS.intellect_v, context.me, "Scroll of Intellect V") then return true end
        return use_item(SCROLLS.spirit_v, context.me, "Scroll of Spirit V")
    elseif role == "healer" then
        if use_item(SCROLLS.spirit_v, context.me, "Scroll of Spirit V") then return true end
        return use_item(SCROLLS.intellect_v, context.me, "Scroll of Intellect V")
    end
    return use_item(SCROLLS.stamina_v, context.me, "Scroll of Stamina V")
end

-- ============================================================================
-- MAIN ENTRY POINT
-- ============================================================================

function M.on_update(context)
    if not NS or type(context) ~= "table" then return false end

    -- Throttle to 3s
    local now = NS.time_now and NS.time_now() or 0
    if now - _last_check < 3 then return false end
    _last_check = now

    -- Check user settings
    local settings = context.settings or {}
    local enabled = settings.use_auto_consumables
    if enabled == nil then enabled = true end
    if enabled == false then return false end

    if not context.in_combat then
        -- OOC: try flasks, elixirs, food
        if settings.use_flasks ~= false and M.use_flask(context) then return true end
        if settings.use_elixirs ~= false and M.use_elixir(context) then return true end
        if settings.use_food ~= false and M.use_food(context) then return true end
        if settings.use_food ~= false and M.use_drink(context) then return true end
        if settings.use_scrolls ~= false and M.use_scroll(context) then return true end
        if settings.use_weapon_buffs ~= false and M.use_weapon_buff(context) then return true end
        return false
    end

    -- In combat: emergency consumables first
    if settings.use_healthstones ~= false and M.use_healthstone(context) then return true end
    if M.use_health_potion(context) then return true end
    if settings.use_bandages ~= false and M.use_bandage(context) then return true end
    if settings.use_mana_potions ~= false and M.use_mana_potion(context) then return true end

    -- Combat potions (once per fight, use at open)
    if settings.use_combat_potions ~= false and M.use_combat_potion(context) then return true end

    -- Drums / runes as filler
    if settings.use_drums ~= false and M.use_drums(context) then return true end
    if M.use_rune(context) then return true end

    return false
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

M.HEALTHSTONES = HEALTHSTONES
M.COMBAT_POTIONS = COMBAT_POTIONS
M.FLASKS = FLASKS
M.ELIXIRS = ELIXIRS
M.FOOD = FOOD
M.DRINKS = DRINKS
M.WEAPON_BUFFS = WEAPON_BUFFS
M.DRUMS = DRUMS
M.RUNES = RUNES
M.BANDAGES = BANDAGES
M.SCROLLS = SCROLLS
M.ACTIVE_BUFFS = ACTIVE_BUFFS

return M
