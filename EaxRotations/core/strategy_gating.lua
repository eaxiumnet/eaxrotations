-- core/strategy_gating.lua — Shared strategy category classification and gating.
-- WHAT:  Classifies strategies into categories (healing/damage/cooldown/utility)
--        and gates them based on user settings (utility_enabled, damage_enabled, etc.).
-- WHY:   Previously duplicated between core_sylvanas.lua and main_sylvanas.lua with
--        divergent return signatures (core: 1 value, main: 3 values). This module
--        is the single source of truth.
-- SAFETY: All settings reads are nil-guarded. Returns ("damage", false, "allowed")
--         as safe defaults when context is missing.

local M = {}

-- Playstyles that are healers (strategies default to healing, damage is blocked)
M.HEALING_PLAYSTYLES = {
    holy = true,
    discipline = true,
    restoration = true,
    resto = true,
}

-- Strategy name substrings → category mapping
M.HEALING_NAMES = {
    "heal", "renew", "mending", "lifebloom", "rejuvenation", "regrowth",
    "powerwordshield", "pws", "circleofhealing", "prayerofhealing",
    "bindingheal", "holyshock", "layonhands", "earthshield", "smartgroupheal",
    "smartheal", "naturesswiftness",
}

M.DAMAGE_NAMES = {
    "idle", "smite", "shadowwordpain", "holyfire", "mindblast",
    "shadowworddeath", "mindflay", "judgement", "crusaderstrike",
    "consecration", "execute", "mortalstrike", "whirlwind", "bloodthirst",
    "fireball", "frostbolt", "arcane", "scorch", "shadowbolt",
}

M.COOLDOWN_NAMES = {
    "avengingwrath", "combustion", "icyveins", "arcanepower", "rapidfire",
    "bestialwrath", "bloodfury", "berserking", "innervate", "shadowfiend",
    "innerfocus", "sweepingstrikes", "recklessness", "deathwish",
    "bladeflurry", "adrenalinerush", "bloodlust", "shamanisticrage",
}

M.UTILITY_NAMES = {
    "interrupt", "kick", "pummel", "counterspell", "spelllock", "silence",
    "cleanse", "dispel", "purify", "cure", "fade", "feign", "vanish",
    "evasion", "sprint", "cower", "righteousfury", "battletrance",
    "battleshout", "commandingshout", "watershield", "shadowform",
    "bearform", "catform", "moonkinform", "stance", "thunderclap",
    "demoshout", "demoralizing", "sunder", "faeriefire",
}

M.DEFENSIVE_NAMES = {
    "shieldblock", "barkskin", "iceblock", "manashield", "divineshield",
    "frenziedregeneration", "shieldwall", "laststand", "holyshield",
}

--- Check if a string contains any of the needle substrings (literal, case-sensitive).
---@param value string The string to search.
---@param needles table Array of substring literals to look for.
---@return boolean true if any needle is found in value.
function M.contains_any(value, needles)
    if type(value) ~= "string" then return false end
    for i = 1, #needles do
        if value:find(needles[i], 1, true) then return true end
    end
    return false
end

--- Classify a strategy into a category: "healing" | "damage" | "cooldown" | "utility".
--- Uses per-playstyle caching to avoid repeated string.find calls.
---@param strategy table Strategy object with .name field.
---@param list_name string|nil "middleware" or playstyle name.
---@param active string|nil The active playstyle name.
---@return string category The strategy category.
function M.strategy_category(strategy, list_name, active)
    if type(strategy) ~= "table" then return "damage" end
    if type(strategy.category) == "string" then return strategy.category end

    -- Per-playstyle cache: category is stable for the same active playstyle.
    -- Eliminates ~3160 string.find calls/frame after first evaluation per playstyle.
    local cat_cache = strategy._cat_cache
    if active and cat_cache and cat_cache[active] then return cat_cache[active] end
    if active and not cat_cache then cat_cache = {}; strategy._cat_cache = cat_cache end

    local name = tostring(strategy.name or ""):lower():gsub("%s+", "")

    local cat
    if M.contains_any(name, M.HEALING_NAMES) then cat = "healing"
    elseif M.contains_any(name, M.DEFENSIVE_NAMES) then cat = "utility"
    elseif strategy.is_burst or M.contains_any(name, M.COOLDOWN_NAMES) then cat = "cooldown"
    elseif M.contains_any(name, M.UTILITY_NAMES) then cat = "utility"
    elseif list_name == "middleware" then cat = "utility"
    elseif M.HEALING_PLAYSTYLES[tostring(active or ""):lower()] then
        if M.contains_any(name, M.DAMAGE_NAMES) then cat = "damage"
        else cat = "healing" end
    else cat = "damage"
    end

    if active then cat_cache[active] = cat end
    return cat
end

--- Check if a strategy is allowed given the current settings.
--- Returns 3 values for diagnostic logging: allowed, reason, category.
---@param strategy table Strategy object.
---@param list_name string|nil "middleware" or playstyle name.
---@param active string|nil The active playstyle name.
---@param context table Rotation context with .settings and .should_burst.
---@return boolean allowed True if the strategy should run.
---@return string reason Diagnostic reason string.
---@return string category The strategy category.
function M.strategy_allowed(strategy, list_name, active, context)
    local settings = (context and context.settings) or {}
    local category = M.strategy_category(strategy, list_name, active)
    local is_healer = M.HEALING_PLAYSTYLES[tostring(active or ""):lower()] == true

    if is_healer and category == "damage" then return false, "healer_damage_blocked", category end
    if settings.utility_enabled == false and category == "utility" then return false, "utility_disabled", category end
    if settings.healing_enabled == false and (category == "healing" or (is_healer and category == "cooldown")) then return false, "healing_disabled", category end
    if settings.damage_enabled == false and (category == "damage" or (category == "cooldown" and not is_healer)) then return false, "damage_disabled", category end
    if settings.use_cooldowns == false and category == "cooldown" and not (context and context.should_burst) then return false, "cooldowns_disabled", category end
    return true, "allowed", category
end

--- Check if a playstyle is a healer playstyle.
---@param active string|nil Playstyle name.
---@return boolean true if the playstyle is a healer.
function M.is_healer_playstyle(active)
    return M.HEALING_PLAYSTYLES[tostring(active or ""):lower()] == true
end

return M
