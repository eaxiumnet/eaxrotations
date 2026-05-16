-- ============================================================================
-- Shared Runtime Helper: Out-of-Combat Manager
-- ============================================================================
local _G = _G
local NS = _G.EaxRotations

local M = {}

local type, tostring = type, tostring
local EMPTY = {}
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { BUFFS = {} } end

local _registered = false
local _last_check = -1000
local _spell_cache = {}
local _work_ids = { n = 0 }

local CLASS = NS and NS.CLASS_ID or {
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
    SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11,
}

-- Buff ID lists are static n-tables. Numeric indices remain contiguous so the
-- existing NS.buff_remains(ids) helper can consume them without allocation.
local BUFFS = {
    battle_shout = { n = 8, 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 },
    commanding_shout = { n = 1, 469 },
    aspect_hawk = { n = 8, 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 },
    mage_armor = { n = 4, 27125, 22783, 22782, 6117 },
    molten_armor = { n = 1, 30482 },
    arcane_intellect = { n = 8, 27126, 10157, 10156, 1461, 1460, 1459, 23028, 27127 },
    righteous_fury = { n = 1, 25780 },
    inner_fire = { n = 7, 25431, 10952, 10951, 1006, 602, 7128, 588 },
    power_word_fortitude = { n = 7, 25389, 10938, 10937, 2791, 1245, 1244, 1243 },
    water_shield = { n = 3, 33736, 24398, 23575 },
    lightning_shield = { n = 9, 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 },
    mark_of_the_wild = { n = 11, 26991, 26990, 9885, 9884, 8907, 6756, 5234, 5232, 1126, 21850, 21849 },
    thorns = { n = 7, 26992, 9910, 9756, 8914, 1075, 782, 467 },
    fel_armor = { n = 2, 28189, 28176 },
    demon_armor = { n = 8, 27260, 11735, 11734, 11733, 1086, 706, 687, 696 },
}

local DEFAULT_BUFFS_BY_CLASS = {
    [CLASS.WARRIOR] = {
        { key = "battle_shout", label = "Battle Shout", buff = BUFFS.battle_shout, spell = { 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 } },
    },
    [CLASS.HUNTER] = {
        { key = "aspect_hawk", label = "Aspect of the Hawk", buff = BUFFS.aspect_hawk, spell = { 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 } },
    },
    [CLASS.MAGE] = {
        { key = "mage_armor", label = "Mage Armor", buff = BUFFS.mage_armor, spell = { 27125, 22783, 22782, 6117 } },
        { key = "arcane_intellect", label = "Arcane Intellect", buff = BUFFS.arcane_intellect, spell = { 27126, 10157, 10156, 1461, 1460, 1459 } },
    },
    [CLASS.PALADIN] = {
        { key = "righteous_fury", label = "Righteous Fury", buff = BUFFS.righteous_fury, spell = 25780, opt_in = true },
    },
    [CLASS.PRIEST] = {
        { key = "inner_fire", label = "Inner Fire", buff = BUFFS.inner_fire, spell = { 25431, 10952, 10951, 1006, 602, 7128, 588 } },
        { key = "power_word_fortitude", label = "Power Word: Fortitude", buff = BUFFS.power_word_fortitude, spell = { 25389, 10938, 10937, 2791, 1245, 1244, 1243 } },
    },
    [CLASS.SHAMAN] = {
        {
            key = "water_shield",
            label = "Water Shield",
            buff = BUFFS.water_shield,
            spell = { name = "Water Shield", ids = { 33736, 24398 }, levels = { 66, 60 }, power_type = "none" },
            min_level = 60,
        },
        {
            key = "lightning_shield",
            label = "Lightning Shield",
            buff = BUFFS.lightning_shield,
            spell = { name = "Lightning Shield", ids = { 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }, levels = { 70, 62, 52, 44, 36, 28, 20, 14, 1 } },
            opt_in = true,
            default_below_level = 60,
        },
    },
    [CLASS.WARLOCK] = {
        { key = "fel_armor", label = "Fel Armor", buff = BUFFS.fel_armor, spell = { 28189, 28176 } },
        { key = "demon_armor", label = "Demon Armor", buff = BUFFS.demon_armor, spell = { 27260, 11735, 11734, 11733, 1086, 706, 687 }, fallback = true },
    },
    [CLASS.DRUID] = {
        { key = "mark_of_the_wild", label = "Mark of the Wild", buff = BUFFS.mark_of_the_wild, spell = { 26990, 9885, 9884, 8907, 6756, 5234, 5232, 1126 } },
        { key = "thorns", label = "Thorns", buff = BUFFS.thorns, spell = { 26992, 9910, 9756, 8914, 1075, 782, 467 }, opt_in = true },
    },
}

local PET_SUMMON_BY_CLASS = {
    [CLASS.HUNTER] = { key = "hunter_call_pet", label = "Call Pet", spell = 883, cooldown = 10 },
    [CLASS.WARLOCK] = { key = "warlock_summon_imp", label = "Summon Imp", spell = 688, cooldown = 10 },
}

local FOOD_BUFFS = { n = 0 }
do
    local food_buffs = (TBC.BUFFS and TBC.BUFFS.food) or EMPTY
    for i = 1, #food_buffs do
        FOOD_BUFFS.n = FOOD_BUFFS.n + 1
        FOOD_BUFFS[FOOD_BUFFS.n] = food_buffs[i]
    end
end

local HEALING_PLAYSTYLES = {
    holy = true,
    discipline = true,
    restoration = true,
    resto = true,
}

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    return nil
end

local function safe_field(obj, key)
    if NS and NS.safe_field then return NS.safe_field(obj, key) end
    if not obj then return nil end
    local ok, value = pcall(function() return obj[key] end)
    return ok and value or nil
end

local function get_setting(settings, key, default)
    if settings and settings[key] ~= nil then return settings[key] end
    if NS and NS.get_setting then return NS.get_setting(key, default) end
    return default
end

local function enabled(settings, key, default)
    return get_setting(settings, key, default) ~= false
end

local function get_player()
    return NS and NS.GetPlayer and NS.GetPlayer() or nil
end

local function get_class_id(me)
    if NS and type(NS.player_class_id) == "number" then return NS.player_class_id end
    local get_class = safe_field(me, "get_class")
    local class_id = get_class and safe(get_class, me) or nil
    return type(class_id) == "number" and class_id or nil
end

local function get_player_level(me)
    local get_effective_level = safe_field(me, "get_effective_level")
    local level = get_effective_level and safe(get_effective_level, me) or nil
    if type(level) ~= "number" then
        local get_level = safe_field(me, "get_level")
        level = get_level and safe(get_level, me) or nil
    end
    return type(level) == "number" and level or 70
end

local function get_spell(entry)
    local key = entry and entry.key
    if not key then return nil end
    local spell = _spell_cache[key]
    if not spell and NS and NS.spell_action then
        spell = NS.spell_action(entry.spell, entry.label)
        _spell_cache[key] = spell
    end
    return spell
end

local function reset_work_ids(source)
    local old_n = _work_ids.n or 0
    _work_ids.n = 0
    if type(source) ~= "table" then
        for i = 1, old_n do _work_ids[i] = nil end
        return _work_ids
    end
    local n = source.n or #source
    for i = 1, n do
        local id = source[i]
        if type(id) == "number" then
            _work_ids.n = _work_ids.n + 1
            _work_ids[_work_ids.n] = id
        end
    end
    for i = _work_ids.n + 1, old_n do _work_ids[i] = nil end
    return _work_ids
end

local function context_or_default(context)
    if type(context) == "table" then return context end
    context = NS and NS.GetCurrentContext and NS.GetCurrentContext() or nil
    if type(context) == "table" then return context end

    local me = get_player()
    if not me then return nil end
    local is_in_combat = safe_field(me, "is_in_combat")
    return {
        me = me,
        settings = NS and NS.settings or EMPTY,
        in_combat = is_in_combat and safe(is_in_combat, me) == true or false,
        mana_pct = NS and NS.mana_pct and NS.mana_pct(me) or 100,
        active_playstyle = NS and NS.get_setting and NS.get_setting("active_playstyle") or nil,
    }
end

local function is_healer_context(context)
    local active = tostring(context and context.active_playstyle or ""):lower()
    if HEALING_PLAYSTYLES[active] then return true end
    local settings = context and context.settings or EMPTY
    return settings.healing_enabled == true and settings.damage_enabled == false
end

local function below_healer_mana_floor(context, settings)
    if not is_healer_context(context) then return false end
    local threshold = get_setting(settings, "ooc_mana_threshold", 30)
    local mana = context and (context.mana_pct or context.player_mana_pct) or nil
    if type(mana) ~= "number" and NS and NS.mana_pct then mana = NS.mana_pct(context and context.me) end
    return type(mana) == "number" and mana < threshold
end

local function should_handle_buff(settings, entry, player_level)
    if not entry then return false end
    local explicit = get_setting(settings, "ooc_buff_" .. entry.key, nil)
    if explicit == false then return false end
    if entry.min_level and player_level < entry.min_level then return false end
    if entry.max_level and player_level > entry.max_level then return false end
    if entry.opt_in and explicit ~= true then
        if entry.default_below_level and player_level < entry.default_below_level then return true end
        return false
    end
    return true
end

local function try_self_buffs(context, settings, me, class_id)
    if below_healer_mana_floor(context, settings) then return false end

    local entries = DEFAULT_BUFFS_BY_CLASS[class_id]
    if type(entries) ~= "table" then return false end
    local threshold = get_setting(settings, "ooc_buff_threshold", 30)
    local player_level = get_player_level(me)

    for i = 1, #entries do
        local entry = entries[i]
        if should_handle_buff(settings, entry, player_level) then
            local ids = reset_work_ids(entry.buff)
            local remains = NS and NS.buff_remains and NS.buff_remains(me, ids)
            if remains == nil then
                -- buff API unavailable, skip to avoid recast spam
                remains = threshold + 1
            end
            if remains <= threshold then
                local spell = get_spell(entry)
                if spell and NS and NS.try_cast and NS.try_cast(spell, me, "[OOC] " .. entry.label, { skip_range = true }) then
                    return true
                end
            end
        end
    end
    return false
end

local function try_pet_summon(settings, me, class_id)
    if not enabled(settings, "ooc_summon_pet", true) then return false end
    local entry = PET_SUMMON_BY_CLASS[class_id]
    if not entry then return false end
    -- Check if pet already exists (multi-layer detection for broken API builds)
    if NS and NS.GetPet and NS.GetPet() then return false end
    if me and me.has_pet then
        local ok, has = pcall(function() return me:has_pet() end)
        if ok and has then return false end
    end
    local spell = get_spell(entry)
    return spell and NS and NS.try_cast and NS.try_cast(spell, me, "[OOC] " .. entry.label, { skip_range = true, expected_cooldown = entry.cooldown }) == true or false
end

local function try_food_flask(settings, me)
    -- Skip if consumable_manager handles this
    if settings.use_auto_consumables ~= false and (settings.use_food ~= false or settings.use_flasks ~= false) then return false end
    if get_setting(settings, "use_food_flask", false) ~= true then return false end
    if NS and NS.has_player_buff and NS.has_player_buff(FOOD_BUFFS) then return false end

    local spell_id = get_setting(settings, "ooc_food_flask_spell", nil)
    if type(spell_id) ~= "number" then return false end
    local entry = { key = "food_flask_" .. tostring(spell_id), label = "Food/Flask", spell = spell_id }
    local spell = get_spell(entry)
    return spell and NS and NS.try_cast and NS.try_cast(spell, me, "[OOC] Food/Flask", { skip_range = true }) == true or false
end

function M.on_update(context)
    if not NS then return false end
    context = context_or_default(context)
    if not context or context.in_combat then return false end

    local settings = context.settings or NS.settings or EMPTY
    if get_setting(settings, "use_ooc_manager", true) == false then return false end

    local now = NS.time_now and NS.time_now() or 0
    if now - _last_check < 1 then return false end
    _last_check = now

    local me = context.me or get_player()
    if not me then return false end
    local class_id = get_class_id(me)
    if not class_id then return false end

    if try_pet_summon(settings, me, class_id) then return true end
    if try_self_buffs(context, settings, me, class_id) then return true end
    if try_food_flask(settings, me) then return true end
    return false
end

function M.register_ooc_manager()
    if _registered then return true end
    if not NS or type(NS.register_on_update_callback) ~= "function" then return false end
    local ok = NS.register_on_update_callback(function()
        local context = NS.GetCurrentContext and NS.GetCurrentContext() or nil
        return M.on_update(context)
    end)
    _registered = ok ~= false
    return _registered
end

if NS then
    NS.OOCManager = M
    NS.ooc_manager = M
    NS.register_ooc_manager = M.register_ooc_manager
end

return M
