-- =============================================================================
-- profession_constants.lua — Skill line IDs, names, and enum mappings.
-- =============================================================================
-- WHAT:  Static lookup tables mapping SkillLine.dbc IDs to profession names
--        and core.profession enum values.
-- WHEN:  Loaded once at startup by crafting_engine.lua and api_surface.lua.
-- WHY:   Centralizes all profession identity data so the crafting engine and
--        API adapter share a single source of truth.
-- SAFETY: Pure data module — no runtime API calls, no side effects.
-- =============================================================================

local M = {}

-- -----------------------------------------------------------------------------
-- SkillLine.dbc IDs (WoW 2.5.5 client)
-- These are the canonical numeric IDs used by core.spell_book.get_profession_info()
-- to identify which profession a spell-tab index belongs to.
-- -----------------------------------------------------------------------------
M.SKILL_ALCHEMY        = 171
M.SKILL_BLACKSMITHING  = 164
M.SKILL_LEATHERWORKING = 165
M.SKILL_TAILORING      = 197
M.SKILL_ENGINEERING    = 202
M.SKILL_ENCHANTING     = 333
M.SKILL_COOKING        = 185
M.SKILL_FIRST_AID      = 129
M.SKILL_JEWELCRAFTING  = 755
M.SKILL_HERBALISM      = 182
M.SKILL_MINING         = 186
M.SKILL_SKINNING       = 393
M.SKILL_FISHING        = 356

-- -----------------------------------------------------------------------------
-- Skill ID → localized name (English; used as fallback for CastSpellByName).
-- -----------------------------------------------------------------------------
M.SKILL_NAMES = {
  [171] = "Alchemy",
  [164] = "Blacksmithing",
  [165] = "Leatherworking",
  [197] = "Tailoring",
  [202] = "Engineering",
  [333] = "Enchanting",
  [185] = "Cooking",
  [129] = "First Aid",
  [755] = "Jewelcrafting",
  [182] = "Herbalism",
  [186] = "Mining",
  [393] = "Skinning",
  [356] = "Fishing",
}

-- -----------------------------------------------------------------------------
-- Reverse map: name → skill ID (case-insensitive lookup helper).
-- -----------------------------------------------------------------------------
M.NAME_TO_SKILL = {}
for id, name in pairs(M.SKILL_NAMES) do
  M.NAME_TO_SKILL[name:lower()] = id
end

-- -----------------------------------------------------------------------------
-- Professions that use the Craft UI (GetNumCrafts / DoCraft) instead of
-- the TradeSkill UI (GetNumTradeSkills / DoTradeSkill).
-- On TBC Classic, only Enchanting uses the Craft window.
-- -----------------------------------------------------------------------------
M.CRAFT_UI_SKILLS = {
  [333] = true,  -- Enchanting
}

-- -----------------------------------------------------------------------------
-- Professions that can be crafted (have a window to open).
-- Gathering professions (Herbalism, Mining, Skinning, Fishing) are excluded
-- — they don't have a crafting window.
-- -----------------------------------------------------------------------------
M.CRAFTABLE_SKILLS = {
  [171] = true,  -- Alchemy
  [164] = true,  -- Blacksmithing
  [165] = true,  -- Leatherworking
  [197] = true,  -- Tailoring
  [202] = true,  -- Engineering
  [333] = true,  -- Enchanting
  [185] = true,  -- Cooking
  [129] = true,  -- First Aid
  [755] = true,  -- Jewelcrafting
}

-- -----------------------------------------------------------------------------
-- Skill ID → core.profession enum name.
-- This maps SkillLine.dbc IDs to the string keys of the core.profession table
-- (e.g. core.profession.ALCHEMY). The actual numeric enum values are resolved
-- at runtime from APISurface.PROFESSION_ENUM since they are opaque ordinals.
-- -----------------------------------------------------------------------------
M.SKILL_TO_ENUM_NAME = {
  [171] = "ALCHEMY",
  [164] = "BLACKSMITHING",
  [165] = "LEATHERWORKING",
  [197] = "TAILORING",
  [202] = "ENGINEERING",
  [333] = "ENCHANTING",
  [185] = "COOKING",
  [129] = "FIRST_AID",
  [755] = "JEWELCRAFTING",
  [186] = "MINING",
  [393] = "SKINNING",
  [356] = "FISHING",
}

-- -----------------------------------------------------------------------------
-- Max skill level per rank tier (Vanilla/TBC).
-- Used by get_profession_max_rank as a fallback when the API doesn't report it.
-- -----------------------------------------------------------------------------
M.MAX_SKILL_BY_RANK = {
  [1] = 75,    -- Apprentice
  [2] = 150,   -- Journeyman
  [3] = 225,   -- Expert
  [4] = 300,   -- Artisan (Vanilla cap)
  [5] = 375,   -- Master (TBC cap)
}

-- TBC max skill cap
M.TBC_MAX_SKILL = 375

return M
