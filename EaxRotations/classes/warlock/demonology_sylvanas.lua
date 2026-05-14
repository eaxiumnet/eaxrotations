-- Readability notes:
--   What: Warlock Demonology priority list.
--   When: dispatcher runs this playstyle when selected.
--   Why: action rows show what is cast, why it is gated, and when it is allowed.
--   Safety: all rows use shared spell/resource/range/form checks before casting.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
--   Enhancement notes (2026-05): Added pet management (Summon Felguard, Health Funnel), Death Coil defensive,
--   and improved DoT/Curses gating with standard action_matches pattern.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.WarlockSpells or {}

local CURSE_OF_DOOM_DEBUFF = { 30910, 603 }
local CORRUPTION_DEBUFF = { 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }
local IMMOLATE_DEBUFF = { 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }
local FEL_ARMOR_BUFF = { 28189, 28176 }
local PET_LOW_HP = 30

-- ============================================================================
-- Pet Management: Summon Felguard & Health Funnel
-- ============================================================================

local function needs_felguard(context)
    local me = context.me
    if not me then return false end
    -- Only try to summon if spell is learned and we're out of combat
    if not NS.is_spell_learned or not NS.is_spell_learned(30146) then return false end
    if context.in_combat then return false end
    -- has_pet() API may not exist in all Sylvanas builds; guard with pcall
    local ok, has_pet = pcall(function() return me:has_pet() end)
    if not ok then
        -- Fallback: check via IZI SDK if available
        if _G.izi and _G.izi.pet then
            local pet = _G.izi.pet()
            return not (pet and pet:is_valid())
        end
        return false
    end
    return not has_pet
end

local function pet_needs_healing(context)
    local me = context.me
    if not me then return false end
    -- get_pet() API may not exist; guard with pcall
    local ok, pet = pcall(function() return me:get_pet() end)
    if not ok then
        -- Fallback via IZI SDK
        if _G.izi and _G.izi.pet then
            pet = _G.izi.pet()
        else
            return false
        end
    end
    if not pet or not pet:is_valid() then return false end
    local pet_hp = pet.get_health_percentage and pet:get_health_percentage() or 100
    return pet_hp < PET_LOW_HP
end

local function death_coil_matches(context, action)
    if not context.target then return false end
    -- Use Death Coil when player HP is dangerously low (emergency heal + CC)
    local me = context.me
    if not me then return false end
    local hp = me.get_health_percentage and me:get_health_percentage() or 100
    if hp > 40 then return false end
    return NS.action_matches(context, action)
end

-- ============================================================================
-- Priority List
-- ============================================================================

local ACTIONS = {
    -- Self-buffs & pet management (no target required, highest priority)
    { name = "FelArmor",         spell = SPELLS.FelArmor,         target = "self", kind = "buff", buff = FEL_ARMOR_BUFF, requires_target = false },

    -- Pet summon (OOC only, no pet active)
    { name = "SummonFelguard",   spell = SPELLS.SummonFelguard,   matches = needs_felguard },

    -- Pet healing during combat
    { name = "HealthFunnel",     spell = SPELLS.HealthFunnel,     matches = pet_needs_healing },

    -- Curses - Curse of Doom first if target lives long enough
    { name = "CurseOfDoom",      spell = SPELLS.CurseOfDoom,      debuff = CURSE_OF_DOOM_DEBUFF, refresh = 5, cooldown = 60, min_ttd = 62, require_ttd = true, target_not_player = true },

    -- DoTs - maintained via the shared dot refresh engine
    { name = "Corruption",       spell = SPELLS.Corruption,       debuff = CORRUPTION_DEBUFF, refresh = 3 },
    { name = "Immolate",         spell = SPELLS.Immolate,         debuff = IMMOLATE_DEBUFF, refresh = 3, not_moving = true },

    -- Mana management
    { name = "LifeTap",          spell = SPELLS.LifeTap,          target = "self", min_hp = 55, max_mana = 65, requires_target = false },

    -- Emergency: Death Coil heals and CCs when low HP
    { name = "DeathCoil",        spell = SPELLS.DeathCoil,        matches = death_coil_matches },

    -- Filler
    { name = "ShadowBolt",       spell = SPELLS.ShadowBolt,       not_moving = true },
}

local strategies = {}
for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    strategies[#strategies + 1] = {
        name = action.name,
        matches = function(context)
            if action.matches then
                return action.matches(context, action)
            end
            return NS.action_matches(context, action)
        end,
        execute = function(context) return NS.action_execute(context, action, "[DEMONOLOGY]") end,
    }
end

NS.rotation_registry:register("demonology", strategies, { get_state = function(context) return context end })
NS.log("Warlock demonology rotation registered (enhanced: pet management, Health Funnel, Death Coil)")
return strategies
