-- consumable_manager_sylvanas.lua -- centralized inventory + cooldown check + cast wrapper for consumables.
-- WHAT:   centralized inventory + cooldown check + cast wrapper for consumables
-- WHEN:   called per-frame in combat by every spec
-- WHY:    single Settings-aware entry for all consumables, removes per-spec bloat
-- SAFETY: is_spell_learned() gate; combat-mode respect; item-id validity table-fenced
-- DECISION: consumed by specs via require(); no on_update side-effects.

local _G = _G
local NS = _G.EaxRotations
local M = {}

local type = type
local EMPTY = {}
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { ITEMS = {}, BUFFS = {} } end

-- Throttle: don't check consumables more than once per 3s
local _last_check = 0
local _last_should_check = 0

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

-- Forward declarations for use_item -> invalidate_bag_cache.
local invalidate_bag_cache

local function use_item(item_id, target, log_msg)
    if not item_id then return false end
    if not has_item(item_id) then return false end
    if not item_ready(item_id) then return false end
    local use_fn = NS.use_item_by_id
    local target_unit = target or (NS.GetPlayer and NS.GetPlayer()) or nil
    if type(use_fn) ~= "function" then return false end
    local ok, result = pcall(use_fn, item_id, target_unit)
    if ok and result ~= false then
        -- Consumable used: invalidate the bag-cache entry for this id so the
        -- next scan reflects the actual inventory state.
        invalidate_bag_cache(item_id)
    end
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
-- BAG SCAN (fast path)
-- ============================================================================
--
-- ``has_item`` iterates all 5 bags (200 slots) for each call.  When a player
-- has *no* consumables in bags, the manager used to still call ``has_item`` 4+
-- times per category and ~70 times total per ``on_update`` invocation.  This
-- helper short-circuits the whole consumable pipeline by scanning the bags
-- ONCE and reporting which item IDs (out of a provided list) the player has.
--
-- A 50 ms TTL cache keeps the per-frame cost bounded: at 20 Hz the dispatcher
-- hits the cache every frame, but a real scan only fires after the player
-- picks up / consumes an item (or after 50 ms, whichever is first).
--
-- (Resolves the "didn't check our bags before changing to auto consume" issue
--  reported by the user on 2026-06-29.)
local _bag_cache = { ts = 0, present = nil } -- present = {[item_id] = true}
local BAG_CACHE_TTL = 0.5                       -- 500 ms; 20 ticks at 40 fps

local function scan_bags_for_ids(ids)
    if type(ids) ~= "table" or #ids == 0 then return {} end
    local now = NS.time_now and NS.time_now() or 0
    if _bag_cache.present and (now - _bag_cache.ts) < BAG_CACHE_TTL then
        return _bag_cache.present
    end
    local present = {}
    -- Avoid re-entering ``has_item`` (200-slot scan per call).  Instead, call
    -- ``core.inventory.get_items_in_bag`` once per bag and build a set of
    -- present item ids, then intersect with the requested list.
    local core = NS.core
    local inventory = core and core.inventory or nil
    local get_items_in_bag = inventory and inventory.get_items_in_bag
    if type(get_items_in_bag) ~= "function" then
        -- Fall back to per-id has_item (slow path) so the manager still works
        -- on engine builds that don't expose the inventory module.
        local safe
        pcall(function() safe = NS.safe end)
        for i = 1, #ids do
            local id = ids[i]
            if type(id) == "number" and id > 0 then
                local ok, hit = pcall(NS.has_item, id)
                if ok and hit == true then present[id] = true end
            end
        end
        _bag_cache.ts = now
        _bag_cache.present = present
        return present
    end
    local safe
    pcall(function() safe = NS.safe end)
    for bag_id = 0, 4 do
        local ok, items = pcall(get_items_in_bag, bag_id)
        if ok and type(items) == "table" then
            for i = 1, #items do
                local entry = items[i]
                local id = type(entry) == "number" and entry
                    or (type(entry) == "table" and (entry.item_id or entry.entry or entry.id))
                if type(id) == "number" and id > 0 then
                    present[id] = true
                end
            end
        end
    end
    _bag_cache.ts = now
    _bag_cache.present = present
    return present
end

--- Returns true if at least one of ``ids`` is present in the player's bags.
--- Cached for BAG_CACHE_TTL seconds.
function M.has_any_consumable(ids)
    if type(ids) ~= "table" or #ids == 0 then return false end
    local present = scan_bags_for_ids(ids)
    for i = 1, #ids do
        local id = ids[i]
        if id and present[id] == true then return true end
    end
    return false
end

-- In-file alias for the helpers below.
local function has_any_item_in_bags(ids)
    return M.has_any_consumable(ids)
end

-- Invalidate the bag cache when a consumable is consumed (called by try_use_first).
invalidate_bag_cache = function(item_id)
    if not _bag_cache.present then return end
    if item_id then
        _bag_cache.present[item_id] = nil
    else
        -- Full invalidation (e.g., test reset, item added, etc.)
        _bag_cache.present = nil
    end
    _bag_cache.ts = 0
end

-- Public helper for tests / external triggers (zone change, BG end, etc).
function M.invalidate_bag_cache()
    invalidate_bag_cache(nil)
end

-- ============================================================================
-- CONSUMABLE ACTIONS
-- ============================================================================

function M.use_healthstone(context)
    if not context or (context.hp or 100) > 50 then return false end
    return try_use_first(HEALTHSTONES, context.me, "Healthstone")
end

-- Static mana potion priority list (Outland first, then leveling fallbacks).
-- Hoisted from M.use_mana_potion's old per-call literal to avoid garbage on every
-- mid-fight invocation. (Pattern 4: static table reuse.)
local MANA_POTION_IDS = nil -- lazily built after TBC data is loaded

local function build_mana_potion_ids()
    if MANA_POTION_IDS then return MANA_POTION_IDS end
    local list = {}
    local add = function(id) if id and id > 0 then list[#list + 1] = id end end
    add(COMBAT_POTIONS.super_mana)
    add(COMBAT_POTIONS.fel_mana)
    add(COMBAT_POTIONS.super_rejuvenation)
    add(COMBAT_POTIONS.crystal_mana)
    add(COMBAT_POTIONS.auchenai_mana)
    add(COMBAT_POTIONS.major_mana)
    add(COMBAT_POTIONS.superior_mana)
    MANA_POTION_IDS = list
    return list
end

function M.use_mana_potion(context)
    if not context then return false end
    -- Honour both the master toggle and the per-category toggle.
    local settings = context.settings or {}
    if settings.use_auto_consumables == false then return false end
    if settings.use_mana_potions == false then return false end
    -- Threshold is configurable; default 40% (legacy behaviour).
    local threshold = settings.mana_potion_threshold
    if type(threshold) ~= "number" then threshold = 40 end
    if (context.mana_pct or 100) > threshold then return false end
    local ids = build_mana_potion_ids()
    for i = 1, #ids do
        if use_item(ids[i], context.me, "Mana Potion") then return true end
    end
    return false
end

-- Static health potion priority list. Order = Outland > leveling. (Pattern 4)
local HEALTH_POTION_IDS = nil

local function build_health_potion_ids()
    if HEALTH_POTION_IDS then return HEALTH_POTION_IDS end
    local list = {}
    local add = function(id) if id and id > 0 then list[#list + 1] = id end end
    add(COMBAT_POTIONS.nightmare_seed)
    add(COMBAT_POTIONS.super_healing)
    add(COMBAT_POTIONS.fel_regeneration)
    add(COMBAT_POTIONS.super_rejuvenation)
    HEALTH_POTION_IDS = list
    return list
end

function M.use_health_potion(context)
    if not context then return false end
    -- BUGFIX (2026-06-29): previously this function fired unconditionally on every
    -- call to on_update when HP <= 35%, with NO master toggle and NO per-setting
    -- gate. The user reported that disabling "Auto Consumables" did not stop the
    -- rotation from chugging health potions. Now both gates are honoured.
    local settings = context.settings or {}
    if settings.use_auto_consumables == false then return false end
    if settings.use_health_potions == false then return false end
    -- Threshold is configurable; default 35% (legacy).
    local threshold = settings.health_potion_threshold
    if type(threshold) ~= "number" then threshold = 35 end
    if (context.hp or 100) > threshold then return false end
    -- Fast-path: if we have NO health potions in bags, return immediately.
    -- (Per the user's report: "we didnt check our bags before changing to auto
    -- consume."  Without this guard, the manager would call use_item() 4 times,
    -- each doing 5 bag lookups, every 3s while at low HP, even with empty bags.)
    if not has_any_item_in_bags(build_health_potion_ids()) then return false end
    local ids = build_health_potion_ids()
    for i = 1, #ids do
        if use_item(ids[i], context.me, "Health Potion") then return true end
    end
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
    if (context.hp or 100) > 75 then return false end
    if player_has_any_buff(ACTIVE_BUFFS.food) or player_has_any_buff(ACTIVE_BUFFS.refreshment) then return false end
    local role = M.get_role(context.player_class, context.active_playstyle)
    if role == "melee" then
        if use_item(FOOD.spicy_hot_talbuk, nil, "Spicy Hot Talbuk") then return true end
        if use_item(FOOD.warp_burger, nil, "Warp Burger") then return true end
        if use_item(FOOD.grilled_mudfish, nil, "Grilled Mudfish") then return true end
    elseif role == "ranged" then
        if use_item(FOOD.ravager_dog, nil, "Ravager Dog") then return true end
        if use_item(FOOD.spicy_hot_talbuk, nil, "Spicy Hot Talbuk") then return true end
        if use_item(FOOD.warp_burger, nil, "Warp Burger") then return true end
    elseif role == "caster" then
        if use_item(FOOD.blackened_basilisk, nil, "Blackened Basilisk") then return true end
        if use_item(FOOD.crunchy_serpent, nil, "Crunchy Serpent") then return true end
        if use_item(FOOD.poached_bluefish, nil, "Poached Bluefish") then return true end
    elseif role == "healer" then
        if use_item(FOOD.golden_fish_sticks, nil, "Golden Fish Sticks") then return true end
        if use_item(FOOD.blackened_sporefish, nil, "Blackened Sporefish") then return true end
    end
    -- Leveling food fallbacks (lower-level health food)
    if use_item(FOOD.herb_baked_egg, nil, "Herb Baked Egg") then return true end
    if use_item(FOOD.cooked_gladeflinger, nil, "Cooked Gladeflinger") then return true end
    if use_item(FOOD.mithril_head_trout, nil, "Mithril Head Trout") then return true end
    if use_item(FOOD.baked_salmon, nil, "Baked Salmon") then return true end
    if use_item(FOOD.cooked_crab_claw, nil, "Cooked Crab Claw") then return true end
    return use_item(FOOD.spiced_chili_crab, nil, "Spiced Chili Crab")
end

function M.use_drink(context)
    if not context or (context.mana_pct or 100) > 80 then return false end
    if player_has_any_buff(ACTIVE_BUFFS.drink) or player_has_any_buff(ACTIVE_BUFFS.refreshment) then return false end
    -- Try high-end drinks first, then fall back to leveling drinks
    if use_item(DRINKS.conjured_manna_biscuit, nil, "Conjured Manna Biscuit") then return true end
    if use_item(DRINKS.conjured_mountain_spring_water, nil, "Conjured Mountain Spring Water") then return true end
    if use_item(DRINKS.filtered_draenic_water, nil, "Filtered Draenic Water") then return true end
    if use_item(DRINKS.star_tears, nil, "Star's Tears") then return true end
    if use_item(DRINKS.purified_draenic_water, nil, "Purified Draenic Water") then return true end
    -- Leveling drink fallbacks (lower-level water)
    if use_item(DRINKS.gray_mountains_water, nil, "Gray Mountain Water") then return true end
    if use_item(DRINKS.purified_water, nil, "Purified Water") then return true end
    if use_item(DRINKS.gold_tea, nil, "Gold Tea") then return true end
    if use_item(DRINKS.moonberry_juice, nil, "Moonberry Juice") then return true end
    if use_item(DRINKS.sweet_nectar, nil, "Sweet Nectar") then return true end
    if use_item(DRINKS.spring_water, nil, "Spring Water") then return true end
    if use_item(DRINKS.melon_juice, nil, "Melon Juice") then return true end
    return use_item(DRINKS.ice_cold_milk, nil, "Ice Cold Milk")
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

-- Static rune priority list. (Pattern 4)
local RUNE_IDS = nil

local function build_rune_ids()
    if RUNE_IDS then return RUNE_IDS end
    local list = {}
    local add = function(id) if id and id > 0 then list[#list + 1] = id end end
    add(RUNES.dark)
    add(RUNES.demonic)
    RUNE_IDS = list
    return list
end

function M.use_rune(context)
    if not context then return false end
    -- BUGFIX (2026-06-29): same auto-consume disable bug as use_health_potion —
    -- used to fire on low mana regardless of the master toggle. Now respects both.
    local settings = context.settings or {}
    if settings.use_auto_consumables == false then return false end
    if settings.use_dark_runes == false then return false end
    if (context.mana_pct or 100) > 40 then return false end
    if not has_any_item_in_bags(build_rune_ids()) then return false end
    local ids = build_rune_ids()
    for i = 1, #ids do
        if use_item(ids[i], context.me, "Rune") then return true end
    end
    return false
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

--- Match function throttle: prevents AutoConsumable middleware from re-evaluating
--- every frame. Returns true only once per 3s when in combat.
--- @param context table Rotation context
--- @return boolean should_check
function M.should_check(context)
    if not context then return false end
    -- BUGFIX (2026-06-29): honor the master ``use_auto_consumables`` toggle
    -- HERE (not just in on_update) so the dispatcher doesn't log
    -- ``match=true, executed=false`` every 3s when the user has explicitly
    -- disabled auto-consumables.  ``should_check`` is the gate that feeds
    -- both the run_list trace and the per-cycle work; it must agree with
    -- the executor's gate.
    local settings = context.settings or {}
    if settings.use_auto_consumables == false then return false end
    -- Skip while already drinking or eating (don't spam consumables mid-channel)
    if player_has_any_buff(ACTIVE_BUFFS.drink) or player_has_any_buff(ACTIVE_BUFFS.refreshment) then return false end
    if player_has_any_buff(ACTIVE_BUFFS.food) then return false end
    -- Allow OOC checks if player needs food/drink (low mana or HP)
    if not context.in_combat then
        local hp = context.hp or 100
        local mana = context.mana_pct or 100
        if hp >= 80 and mana >= 80 then return false end
    end
    -- In combat: only check if HP or mana is actually low (prevents trace spam and wasted cycles)
    if context.in_combat then
        local hp = context.hp or 100
        local mana = context.mana_pct or 100
        if hp > 60 and mana > 50 then return false end
    end
    local now = NS.time_now and NS.time_now() or 0
    if now - _last_should_check < 3 then return false end
    _last_should_check = now
    return true
end

-- Aggregated lists for the fast-path bag scan in on_update.  We build them
-- once at first use so we can ask "does the player have ANY consumable that
-- could conceivably fire given the current settings?" in a single bag scan.
-- (Per the user's report on 2026-06-29: "we didnt check our bags before
--  changing to auto consume" — without this check the manager would iterate
--  4-8 items per category even when the player has empty bags, wasting
--  hundreds of ``has_item`` calls per minute.)
local _all_potion_ids = nil
local _all_food_drink_ids = nil
local _all_consumable_ids = nil

local function build_all_potion_ids()
    if _all_potion_ids then return _all_potion_ids end
    local list = {}
    local seen = {}
    local add = function(id)
        if type(id) == "number" and id > 0 and not seen[id] then
            seen[id] = true
            list[#list + 1] = id
        end
    end
    for _, t in ipairs({ HEALTHSTONES, COMBAT_POTIONS, RUNES, BANDAGES }) do
        if type(t) == "table" then
            for _, id in pairs(t) do add(id) end
        end
    end
    _all_potion_ids = list
    return list
end

local function build_all_food_drink_ids()
    if _all_food_drink_ids then return _all_food_drink_ids end
    local list = {}
    local seen = {}
    local add = function(id)
        if type(id) == "number" and id > 0 and not seen[id] then
            seen[id] = true
            list[#list + 1] = id
        end
    end
    for _, t in ipairs({ FLASKS, ELIXIRS, FOOD, DRINKS, SCROLLS, WEAPON_BUFFS, DRUMS }) do
        if type(t) == "table" then
            for _, id in pairs(t) do add(id) end
        end
    end
    _all_food_drink_ids = list
    return list
end

local function build_all_consumable_ids()
    if _all_consumable_ids then return _all_consumable_ids end
    local list = {}
    local seen = {}
    local add = function(id)
        if type(id) == "number" and id > 0 and not seen[id] then
            seen[id] = true
            list[#list + 1] = id
        end
    end
    for _, id in ipairs(build_all_potion_ids()) do add(id) end
    for _, id in ipairs(build_all_food_drink_ids()) do add(id) end
    _all_consumable_ids = list
    return list
end

-- Pre-compute at module load so first call is hot.  Non-fatal if TBC data
-- isn't present yet (build_* just returns empty lists).
do
    pcall(build_all_consumable_ids)
end

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

    -- BUGFIX (2026-06-29): "we didnt check our bags before changing to auto
    -- consume."  Before any category work, do a single bag scan to determine
    -- whether the player has ANY consumable item in their bags.  If the
    -- answer is no, short-circuit immediately.  This saves 4-8 ``has_item``
    -- calls per category (each is a 5-bag scan = up to 200 slot iterations)
    -- whenever the player has empty bags.  Cached for 500 ms.
    local _bag_present = scan_bags_for_ids(build_all_consumable_ids())
    local function has_consumable_in_bags(ids)
        for i = 1, #ids do
            if _bag_present[ids[i]] == true then return true end
        end
        return false
    end

    if not context.in_combat then
        -- OOC: try flasks, elixirs, food.  Fast-path: only attempt a category
        -- if the player actually has at least one item from that category's
        -- list.  This is what the user asked for: "check our bags before
        -- changing to auto consume".
        if settings.use_flasks ~= false and has_consumable_in_bags(FLASKS) and M.use_flask(context) then return true end
        if settings.use_elixirs ~= false and has_consumable_in_bags(ELIXIRS) and M.use_elixir(context) then return true end
        if settings.use_food ~= false and (has_consumable_in_bags(FOOD) or has_consumable_in_bags(DRINKS)) then
            if M.use_food(context) then return true end
            if M.use_drink(context) then return true end
        end
        if settings.use_scrolls ~= false and has_consumable_in_bags(SCROLLS) and M.use_scroll(context) then return true end
        if settings.use_weapon_buffs ~= false and has_consumable_in_bags(WEAPON_BUFFS) and M.use_weapon_buff(context) then return true end
        return false
    end

    -- In combat: emergency consumables first.
    -- Each per-setting gate is explicit; the self-gating ``use_health_potion``
    -- and ``use_rune`` are still called but they short-circuit immediately
    -- when their per-setting is false, so this is fine.
    if settings.use_healthstones ~= false and has_consumable_in_bags(HEALTHSTONES) and M.use_healthstone(context) then return true end
    if has_consumable_in_bags(build_health_potion_ids()) and M.use_health_potion(context) then return true end
    if settings.use_bandages ~= false and has_consumable_in_bags(BANDAGES) and M.use_bandage(context) then return true end
    if has_consumable_in_bags(build_mana_potion_ids()) and M.use_mana_potion(context) then return true end

    -- Combat potions (once per fight, use at open)
    if settings.use_combat_potions ~= false and has_consumable_in_bags(COMBAT_POTIONS) and M.use_combat_potion(context) then return true end

    -- Drums / runes as filler
    if settings.use_drums ~= false and has_consumable_in_bags(DRUMS) and M.use_drums(context) then return true end
    if has_consumable_in_bags(build_rune_ids()) and M.use_rune(context) then return true end

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
