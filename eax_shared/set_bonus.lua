-- set_bonus.lua  |  Dynamic Set Bonus Detection  |  TBC Classic
-- Scans equipped gear for T4/T5/T6 set pieces and provides multipliers

local set_bonus = {}

local INV_SLOT_HEAD     = 1
local INV_SLOT_SHOULDER = 3
local INV_SLOT_CHEST    = 5
local INV_SLOT_LEGS     = 7
local INV_SLOT_HAND     = 10

-- TBC tier set detection only needs the five armor-piece slots.
-- Weapon slots (16/17) and other equipment slots are intentionally excluded
-- because T4/T5/T6 set bonuses are never granted by weapons, rings, cloaks,
-- trinkets, or similar non-tier slots.
local ALL_SLOTS = {
    INV_SLOT_HEAD,
    INV_SLOT_SHOULDER,
    INV_SLOT_CHEST,
    INV_SLOT_LEGS,
    INV_SLOT_HAND,
}

--[[
  All TBC Classic Tier Sets with item IDs and bonus multipliers.
  Naming convention:
    - T4 tier = Dungeon/entry raid sets (Karazhan, Gruul, Magtheridon)
    - T5 tier = Serpentshrine Cavern, Tempest Keep
    - T6 tier = Black Temple, Sunwell Plateau

  Each set entry: [setName] = { items = {...}, bonuses = { [2] = mult, [4] = mult } }
  bonuses are damage multipliers (1.05 = +5% damage)
]]

local ALL_SETS = {

    -- =========================
    -- DRUID SETS
    -- =========================
    -- T4 (Tier 4): Nordrassil
    ["Nordrall"] = {
        items = { 29068, 29069, 29070, 29071, 29072 },
        bonuses = { [2] = 1.03, [4] = 1.08 }
    },
    -- T4: Nordrassil Harness
    ["NordrassilHarness"] = {
        items = { 30121, 30122, 30123, 30124, 30125 },
        bonuses = { [2] = 1.03, [4] = 1.08 }
    },
    -- T5: Malorne
    ["Malorne"] = {
        items = { 30207, 30208, 30209, 30210, 30211 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },
    -- T5: Malorne Harness
    ["MalorneHarness"] = {
        items = { 30909, 30910, 30911, 30912, 30913 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },
    -- T6: Nordrassil Battlegear
    ["NordrassilBattlegear"] = {
        items = { 32492, 32493, 32494, 32495, 32496 },
        bonuses = { [2] = 1.03, [4] = 1.08 }
    },
    -- T6: Thunderheart Battlegear
    ["ThunderheartBattlegear"] = {
        items = { 34161, 34162, 34163, 34164, 34165 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },

    -- =========================
    -- HUNTER SETS
    -- =========================
    -- T4: Cryptstalker
    ["Cryptstalker"] = {
        items = { 29055, 29056, 29057, 29058, 29059 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },
    -- T5: Cryptstalker Battlegear
    ["CryptstalkerBattlegear"] = {
        items = { 30103, 30104, 30105, 30106, 30107 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },
    -- T6: Cryptstalker Vindication
    ["CryptstalkerVindication"] = {
        items = { 30914, 30915, 30916, 30917, 30918 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },

    -- =========================
    -- MAGE SETS
    -- =========================
    -- T4: Aldor
    ["Aldor"] = {
        items = { 29059, 29060, 29061, 29062, 29063 },
        bonuses = { [2] = 1.03, [4] = 1.08 }
    },
    -- T4: Aldor Regalia
    ["AldorRegalia"] = {
        items = { 30109, 30110, 30111, 30112, 30113 },
        bonuses = { [2] = 1.03, [4] = 1.08 }
    },
    -- T5: Tirisfal
    ["Tirisfal"] = {
        items = { 30208, 30209, 30210, 30211, 30212 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },
    -- T5: Tirisfal Regalia
    ["TirisfalRegalia"] = {
        items = { 30892, 30893, 30894, 30895, 30896 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },
    -- T6: Tempest
    ["Tempest"] = {
        items = { 32470, 32471, 32472, 32473, 32474 },
        bonuses = { [2] = 1.03, [4] = 1.08 }
    },
    -- T6: Tempest Regalia
    ["TempestRegalia"] = {
        items = { 34166, 34167, 34168, 34169, 34170 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },

    -- =========================
    -- PALADIN SETS
    -- =========================
    -- T4: Justicar Battlegear
    ["JusticarBattlegear"] = {
        items = { 29071, 29072, 29073, 29074, 29075 },
        bonuses = { [2] = 1.03, [4] = 1.08 }
    },
    -- T4: Justicar Armor
    ["JusticarArmor"] = {
        items = { 30137, 30138, 30139, 30140, 30141 },
        bonuses = { [2] = 1.03, [4] = 1.08 }
    },
    -- T5: Crystalforge Battlegear
    ["CrystalforgeBattlegear"] = {
        items = { 30217, 30218, 30219, 30220, 30221 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },
    -- T5: Crystalforge Armor
    ["CrystalforgeArmor"] = {
        items = { 30902, 30903, 30904, 30905, 30906 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },
    -- T6: Lightbringer Battlegear
    ["LightbringerBattlegear"] = {
        items = { 32475, 32476, 32477, 32478, 32479 },
        bonuses = { [2] = 1.03, [4] = 1.08 }
    },
    -- T6: Lightbringer Armor
    ["LightbringerArmor"] = {
        items = { 34171, 34172, 34173, 34174, 34175 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },

    -- =========================
    -- PRIEST SETS
    -- =========================
    -- T4: Vestments of the Devout
    ["Vestments"] = {
        items = { 29065, 29066, 29067, 29068, 29069 },
        bonuses = { [2] = 1.03, [4] = 1.08 }
    },
    -- T4: Absolution
    ["Absolution"] = {
        items = { 30128, 30129, 30130, 30131, 30132 },
        bonuses = { [2] = 1.03, [4] = 1.08 }
    },
    -- T5: Absolution Regalia
    ["AbsolutionRegalia"] = {
        items = { 30897, 30898, 30899, 30900, 30901 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },
    -- T6: Incarnate
    ["Incarnate"] = {
        items = { 32464, 32465, 32466, 32467, 32468 },
        bonuses = { [2] = 1.03, [4] = 1.08 }
    },
    -- T6: Avatar
    ["Avatar"] = {
        items = { 34156, 34157, 34158, 34159, 34160 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },

    -- =========================
    -- ROGUE SETS
    -- =========================
    -- T4: Assassination
    ["Assassination"] = {
        items = { 29043, 29044, 29045, 29046, 29047 },
        bonuses = { [2] = 1.03, [4] = 1.08 }
    },
    -- T5: Netherblade
    ["Netherblade"] = {
        items = { 30200, 30201, 30202, 30203, 30204 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },
    -- T6: Deathmantle
    ["Deathmantle"] = {
        items = { 30885, 30886, 30887, 30888, 30889 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },
    -- T6: Slayer's Armor
    ["Slayers"] = {
        items = { 32454, 32455, 32456, 32457, 32458 },
        bonuses = { [2] = 1.03, [4] = 1.08 }
    },

    -- =========================
    -- SHAMAN SETS
    -- =========================
    -- T4: Cyclone (Elemental/Resto)
    ["Cyclone"] = {
        items = { 29060, 29061, 29062, 29063, 29064 },
        bonuses = { [2] = 1.03, [4] = 1.08 }
    },
    -- T4: Cataclysm (Enhancement)
    ["Cataclysm"] = {
        items = { 30117, 30118, 30119, 30120, 30121 },
        bonuses = { [2] = 1.03, [4] = 1.08 }
    },
    -- T5: Cyclone Regalia
    ["CycloneRegalia"] = {
        items = { 30878, 30879, 30880, 30881, 30882 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },
    -- T5: Cataclysm Regalia
    ["CataclysmRegalia"] = {
        items = { 30915, 30916, 30917, 30918, 30919 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },
    -- T6: Skyshatter Regalia (Elemental)
    ["SkyshatterRegalia"] = {
        items = { 32459, 32460, 32461, 32462, 32463 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },
    -- T6: Skyshatter Harness (Enhancement)
    ["SkyshatterHarness"] = {
        items = { 34151, 34152, 34153, 34154, 34155 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },

    -- =========================
    -- WARLOCK SETS
    -- =========================
    -- T4: Voidheart Raiment
    ["Voidheart"] = {
        items = { 29065, 29066, 29067, 29068, 29069 },
        bonuses = { [2] = 1.03, [4] = 1.08 }
    },
    -- T4: Voidheart Regalia
    ["VoidheartRegalia"] = {
        items = { 30125, 30126, 30127, 30128, 30129 },
        bonuses = { [2] = 1.03, [4] = 1.08 }
    },
    -- T5: Oblivion Raiment
    ["OblivionRaiment"] = {
        items = { 30205, 30206, 30207, 30208, 30209 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },
    -- T5: Corruptor Raiment
    ["CorruptorRaiment"] = {
        items = { 30910, 30911, 30912, 30913, 30914 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },
    -- T6: Malefic Raiment
    ["Malefic"] = {
        items = { 32482, 32483, 32484, 32485, 32486 },
        bonuses = { [2] = 1.03, [4] = 1.08 }
    },

    -- =========================
    -- WARRIOR SETS
    -- =========================
    -- T4: Warbringer (Protection)
    ["Warbringer"] = {
        items = { 29061, 29062, 29063, 29064, 29065 },
        bonuses = { [2] = 1.03, [4] = 1.08 }
    },
    -- T4: Warbringer Battlegear (Arms/Fury)
    ["WarbringerBattlegear"] = {
        items = { 30175, 30176, 30177, 30178, 30179 },
        bonuses = { [2] = 1.03, [4] = 1.08 }
    },
    -- T5: Destroyer Battlegear (Arms)
    ["DestroyerBattlegear"] = {
        items = { 30214, 30215, 30216, 30217, 30218 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },
    -- T5: Destroyer Armor (Fury)
    ["DestroyerArmor"] = {
        items = { 30897, 30898, 30899, 30900, 30901 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },
    -- T6: Onslaught Battlegear (Arms)
    ["OnslaughtBattlegear"] = {
        items = { 32469, 32470, 32471, 32472, 32473 },
        bonuses = { [2] = 1.03, [4] = 1.08 }
    },
    -- T6: Onslaught Armor (Fury/Prot)
    ["OnslaughtArmor"] = {
        items = { 34161, 34162, 34163, 34164, 34165 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },
    -- T6: Ymirjar (Fury)
    ["Ymirjar"] = {
        items = { 31193, 31194, 31195, 31196, 31197 },
        bonuses = { [2] = 1.05, [4] = 1.10 }
    },
}

local equipped_cache = {}
local equipped_cache_time = 0
local CACHE_TTL = 2.0

local function scan_equipped(me)
    if not me then return {} end
    local now = core and core.time and core.time() or 0
    if now - equipped_cache_time < CACHE_TTL and #equipped_cache > 0 then
        return equipped_cache
    end
    local items = {}
    for _, slot in ipairs(ALL_SLOTS) do
        local ok, slot_info = pcall(function() return me:get_item_at_inventory_slot(slot) end)
        if ok and slot_info and slot_info.object then
            local item = slot_info.object
            if item and item.is_valid and item:is_valid() then
                local item_id = item.get_item_id and item:get_item_id()
                if item_id and item_id > 0 then
                    items[item_id] = true
                end
            end
        end
    end
    equipped_cache = items
    equipped_cache_time = now
    return items
end

function set_bonus.update(me)
    equipped_cache = {}
    equipped_cache_time = 0
    scan_equipped(me)
end

function set_bonus.get_item_id_in_slot(me, slot_id)
    if not me then return nil end
    local ok, slot_info = pcall(function() return me:get_item_at_inventory_slot(slot_id) end)
    if not ok or not slot_info or not slot_info.object then return nil end
    local item = slot_info.object
    if not item or not item.is_valid or not item:is_valid() then return nil end
    return item.get_item_id and item:get_item_id()
end

function set_bonus.get_equipped_items(me)
    return scan_equipped(me)
end

function set_bonus.get_set_count(me, set_name)
    if not me then return 0 end
    local set_def = ALL_SETS[set_name]
    if not set_def or not set_def.items then return 0 end
    local equipped = scan_equipped(me)
    local count = 0
    for _, item_id in ipairs(set_def.items) do
        if equipped[item_id] then
            count = count + 1
        end
    end
    return count
end

function set_bonus.has_set_bonus(me, set_name, pieces_needed)
    if not me then return false end
    pieces_needed = pieces_needed or 2
    return set_bonus.get_set_count(me, set_name) >= pieces_needed
end

function set_bonus.get_multiplier(me, set_name)
    if not me then return 1.0 end
    local count = set_bonus.get_set_count(me, set_name)
    if count == 0 then return 1.0 end
    local set_def = ALL_SETS[set_name]
    if not set_def or not set_def.bonuses then return 1.0 end
    if count >= 4 and set_def.bonuses[4] then
        return set_def.bonuses[4]
    elseif count >= 2 and set_def.bonuses[2] then
        return set_def.bonuses[2]
    end
    return 1.0
end

function set_bonus.get_damage_multiplier(me)
    if not me then return 1.0 end
    local best = 1.0
    for set_name, _ in pairs(ALL_SETS) do
        local mult = set_bonus.get_multiplier(me, set_name)
        if mult > best then
            best = mult
        end
    end
    return best
end

function set_bonus.get_best_multiplier(me)
    return set_bonus.get_damage_multiplier(me)
end

function set_bonus.get_active_sets(me)
    if not me then return {} end
    local active = {}
    for set_name, set_def in pairs(ALL_SETS) do
        local count = set_bonus.get_set_count(me, set_name)
        if count >= 2 then
            local mult = set_bonus.get_multiplier(me, set_name)
            table.insert(active, {
                name = set_name,
                count = count,
                multiplier = mult,
            })
        end
    end
    return active
end

function set_bonus.get_set_names()
    local names = {}
    for name, _ in pairs(ALL_SETS) do
        table.insert(names, name)
    end
    return names
end

return set_bonus
