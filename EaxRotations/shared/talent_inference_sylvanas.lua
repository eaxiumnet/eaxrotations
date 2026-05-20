-- ============================================================================
-- Shared Helper: Talent Inference
-- ============================================================================
local M = {}
local _G = _G
local NS = _G.EaxRotations

-- Talent inference tables
-- Maps "signature spells" to talent presence
local TALENT_SIGNATURES = {
    -- Priest
    priest = {
        shadowform = { ids = { 15473 }, talent = "Shadowform", tree = "shadow" },
        vampiric_touch = { ids = { 34914, 34916, 34917 }, talent = "Vampiric Touch", tree = "shadow" },
        pain_suppression = { ids = { 33206 }, talent = "Pain Suppression", tree = "discipline" },
        power_infusion = { ids = { 10060 }, talent = "Power Infusion", tree = "discipline" },
        circle_of_healing = { ids = { 34861, 34863, 34864, 34865, 34866 }, talent = "Circle of Healing", tree = "holy" },
    },
    
    -- Mage
    mage = {
        ice_barrier = { ids = { 11426, 13031, 13032, 13033 }, talent = "Ice Barrier", tree = "frost" },
        combustion = { ids = { 11129 }, talent = "Combustion", tree = "fire" },
        arcane_power = { ids = { 12042 }, talent = "Arcane Power", tree = "arcane" },
        presence_of_mind = { ids = { 12043 }, talent = "Presence of Mind", tree = "arcane" },
        pyroblast = { ids = { 11366, 12505, 12522, 12523, 12524, 12525, 12526, 18809, 27132, 27133 }, talent = "Pyroblast", tree = "fire" },
    },
    
    -- Warlock
    warlock = {
        soul_link = { ids = { 19028 }, talent = "Soul Link", tree = "demonology" },
        conflagrate = { ids = { 17962, 18930, 18931, 18932, 27266, 27267 }, talent = "Conflagrate", tree = "destruction" },
        shadow_mastery = { ids = { 18272, 18273, 18274, 18275 }, talent = "Shadow Mastery", tree = "affliction" },
        unholy_power = { ids = { 18773, 18774, 18775, 18776, 18777 }, talent = "Unholy Power", tree = "demonology" },
    },
    
    -- Warrior
    warrior = {
        mortal_strike = { ids = { 12294, 21551, 21552, 21553, 25248, 30330 }, talent = "Mortal Strike", tree = "arms" },
        bloodthirst = { ids = { 23881, 23892, 23893, 23894, 25251, 30335 }, talent = "Bloodthirst", tree = "fury" },
        shield_slam = { ids = { 23922, 23923, 23924, 23925, 25258, 30356 }, talent = "Shield Slam", tree = "protection" },
        tactical_mastery = { ids = { 12295, 12676, 12677 }, talent = "Tactical Mastery", tree = "arms" },
        death_wish = { ids = { 12292 }, talent = "Death Wish", tree = "fury" },
    },
    
    -- Rogue
    rogue = {
        mutilate = { ids = { 32684, 34411, 34412, 34413 }, talent = "Mutilate", tree = "assassination" },
        adrenaline_rush = { ids = { 13750 }, talent = "Adrenaline Rush", tree = "combat" },
        hemo = { ids = { 16511, 17347, 17348, 26864, 26865 }, talent = "Hemorrhage", tree = "subtlety" },
        preparation = { ids = { 14185 }, talent = "Preparation", tree = "subtlety" },
    },
    
    -- Hunter
    hunter = {
        bestial_wrath = { ids = { 19574 }, talent = "Bestial Wrath", tree = "beast_mastery" },
        aimed_shot = { ids = { 19434, 20900, 20901, 20902, 20903, 20904 }, talent = "Aimed Shot", tree = "marksmanship" },
        scatter_shot = { ids = { 19503 }, talent = "Scatter Shot", tree = "survival" },
        wyvern_sting = { ids = { 19386, 24132, 24133, 27068 }, talent = "Wyvern Sting", tree = "survival" },
    },
    
    -- Shaman
    shaman = {
        elemental_mastery = { ids = { 16166 }, talent = "Elemental Mastery", tree = "elemental" },
        shamanistic_rage = { ids = { 30823 }, talent = "Shamanistic Rage", tree = "enhancement" },
        mana_tide = { ids = { 16190 }, talent = "Mana Tide Totem", tree = "restoration" },
        nature_swiftness = { ids = { 16188 }, talent = "Nature's Swiftness", tree = "restoration" },
        dual_wield = { ids = { 30798 }, talent = "Dual Wield", tree = "enhancement" },
    },
    
    -- Druid
    druid = {
        swiftmend = { ids = { 18562 }, talent = "Swiftmend", tree = "restoration" },
        innervate = { ids = { 29166 }, talent = "Innervate", tree = "restoration" },
        force_of_nature = { ids = { 33831 }, talent = "Force of Nature", tree = "balance" },
        mangle = { ids = { 33982, 33983 }, talent = "Mangle", tree = "feral" },
    },
    
    -- Paladin
    paladin = {
        holy_shock = { ids = { 20473, 20929, 20930, 27174, 27175 }, talent = "Holy Shock", tree = "holy" },
        avengers_shield = { ids = { 31935, 32699, 32700 }, talent = "Avenger's Shield", tree = "protection" },
        crusader_strike = { ids = { 35395 }, talent = "Crusader Strike", tree = "retribution" },
        divine_favor = { ids = { 20216 }, talent = "Divine Favor", tree = "holy" },
    },
}

-- Primary tree scores (accumulate points per tree)
local TREE_WEIGHTS = {
    priest = { discipline = 0, holy = 0, shadow = 0 },
    mage = { arcane = 0, fire = 0, frost = 0 },
    warlock = { affliction = 0, demonology = 0, destruction = 0 },
    warrior = { arms = 0, fury = 0, protection = 0 },
    rogue = { assassination = 0, combat = 0, subtlety = 0 },
    hunter = { beast_mastery = 0, marksmanship = 0, survival = 0 },
    shaman = { elemental = 0, enhancement = 0, restoration = 0 },
    druid = { balance = 0, feral = 0, restoration = 0 },
    paladin = { holy = 0, protection = 0, retribution = 0 },
}

-- Check if any spell in list is learned
local function has_any_spell_learned(spell_ids)
    if not NS or not NS.is_spell_learned then return false end
    
    for _, spell_id in ipairs(spell_ids) do
        local ok, learned = pcall(NS.is_spell_learned, spell_id)
        if ok and learned then
            return true
        end
    end
    
    return false
end

-- Infer talents for a class
function M.infer(class)
    if not class then return nil end
    
    local signatures = TALENT_SIGNATURES[class]
    if not signatures then return nil end
    
    local inferred = {
        class = class,
        talents = {},
        primary_tree = nil,
        secondary_trees = {},
        tree_scores = {},
    }
    
    -- Initialize tree scores
    local tree_scores = {}
    for tree_name, _ in pairs(TREE_WEIGHTS[class] or {}) do
        tree_scores[tree_name] = 0
    end
    
    -- Check each signature spell
    for talent_key, data in pairs(signatures) do
        if has_any_spell_learned(data.ids) then
            inferred.talents[data.talent] = true
            
            -- Add weight to tree
            if data.tree then
                tree_scores[data.tree] = (tree_scores[data.tree] or 0) + 1
            end
        else
            inferred.talents[data.talent] = false
        end
    end
    
    -- Determine primary tree
    local max_score = 0
    local primary_tree = nil
    
    for tree_name, score in pairs(tree_scores) do
        inferred.tree_scores[tree_name] = score
        if score > max_score then
            max_score = score
            primary_tree = tree_name
        end
    end
    
    inferred.primary_tree = primary_tree
    
    -- Determine secondary trees
    for tree_name, score in pairs(tree_scores) do
        if tree_name ~= primary_tree and score > 0 then
            table.insert(inferred.secondary_trees, tree_name)
        end
    end
    
    return inferred
end

-- Check if specific talent is present
function M.has_talent(class, talent_key)
    local inferred = M.infer(class)
    if not inferred then return false end
    
    return inferred.talents[talent_key] or false
end

-- Get primary tree
function M.get_primary_tree(class)
    local inferred = M.infer(class)
    if not inferred then return nil end
    
    return inferred.primary_tree
end

-- Get inferred spec name
function M.get_inferred_spec(class)
    local primary = M.get_primary_tree(class)
    if not primary then return "unknown" end
    
    -- Map tree to spec name
    local spec_map = {
        -- Warrior
        arms = "Arms",
        fury = "Fury",
        protection = "Protection",
        -- Rogue
        assassination = "Assassination",
        combat = "Combat",
        subtlety = "Subtlety",
        -- Hunter
        beast_mastery = "Beast Mastery",
        marksmanship = "Marksmanship",
        survival = "Survival",
        -- Mage
        arcane = "Arcane",
        fire = "Fire",
        frost = "Frost",
        -- Warlock
        affliction = "Affliction",
        demonology = "Demonology",
        destruction = "Destruction",
        -- Priest
        discipline = "Discipline",
        holy = "Holy",
        shadow = "Shadow",
        -- Paladin
        holy = "Holy",
        protection = "Protection",
        retribution = "Retribution",
        -- Shaman
        elemental = "Elemental",
        enhancement = "Enhancement",
        restoration = "Restoration",
        -- Druid
        balance = "Balance",
        feral = "Feral",
        restoration = "Restoration",
    }
    
    return spec_map[primary] or primary
end

-- Cached results
local cache = {}

-- Cached infer with refresh
function M.infer_cached(class, ttl)
    ttl = ttl or 30  -- 30 second cache
    
    local now = NS and NS.time_now and NS.time_now() or 0
    local cached = cache[class]
    
    if cached and (now - cached.timestamp) < ttl then
        return cached.data
    end
    
    local result = M.infer(class)
    cache[class] = {
        data = result,
        timestamp = now,
    }
    
    return result
end

-- Clear cache
function M.clear_cache()
    cache = {}
end

-- Get full talent report
function M.get_report(class)
    local inferred = M.infer_cached(class)
    if not inferred then
        return "Unable to infer talents for " .. tostring(class)
    end
    
    local report = "[TalentInference] " .. class .. " - " .. inferred.primary_tree .. "\n"
    report = report .. "  Primary: " .. tostring(inferred.primary_tree) .. "\n"
    report = report .. "  Tree Scores: "
    for tree, score in pairs(inferred.tree_scores) do
        report = report .. tree .. "=" .. score .. " "
    end
    report = report .. "\n  Known Talents: "
    for talent, present in pairs(inferred.talents) do
        if present then
            report = report .. talent .. " "
        end
    end
    
    return report
end

if NS then
    NS.TalentInference = M
end

return M
