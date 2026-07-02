-- =============================================================================
-- crafting_engine.lua — Clean crafting automation engine for TBC Classic.
-- =============================================================================
-- WHAT:  High-level crafting automation: open profession, scan recipes, check
--        reagents, craft by name/index, mass-produce, track statistics.
-- WHEN:  Called from main.lua on_update when crafting mode is enabled.
-- WHY:   Provides a clean, single-purpose engine that wraps api_surface.lua
--        into usable crafting operations. No gathering, no navigation — just
--        crafting.
-- SAFETY: All API calls go through api_surface (pcall-wrapped). No per-frame
--         allocations. State is static. Nil-guarded throughout.
-- =============================================================================

local APISurface = require("core/api_surface")
local Constants  = require("data/profession_constants")

local M = {}

-- -----------------------------------------------------------------------------
-- Static State (reused every frame — no allocations)
-- -----------------------------------------------------------------------------
local _stats = {
  crafts_attempted  = 0,
  crafts_succeeded  = 0,
  last_craft_time   = 0,
  last_craft_name   = "",
}

-- Skill ID → profession enum value (built lazily on first open_profession call)
local _skill_to_enum = nil

-- Maximum queue size for mass production
M.MAX_QUEUE_SIZE = 50

-- Minimum delay between crafts (seconds) to respect GCD
M.CRAFT_COOLDOWN_S = 0.8

-- -----------------------------------------------------------------------------
-- Internal: Build skill-to-enum mapping from PROFESSION_ENUM
-- -----------------------------------------------------------------------------
local function ensure_skill_to_enum()
  if _skill_to_enum then return end
  local enum = APISurface.PROFESSION_ENUM
  if not enum or type(enum) ~= "table" then
    _skill_to_enum = {}
    return
  end
  _skill_to_enum = {}
  for skill_id, enum_name in pairs(Constants.SKILL_TO_ENUM_NAME) do
    local enum_val = enum[enum_name]
    if type(enum_val) == "number" then
      _skill_to_enum[skill_id] = enum_val
    end
  end
end

-- =============================================================================
-- Skill Rank Checking
-- =============================================================================

--- Get the player's current skill rank for a profession.
-- @param skill_id integer  SkillLine.dbc ID (e.g. 171 for Alchemy)
-- @return integer  rank (0 if not learned or API unavailable)
function M.get_skill_rank(skill_id)
  return APISurface.get_profession_skill_rank(skill_id)
end

--- Get the max skill level for a profession.
-- @param skill_id integer
-- @return integer  max_rank (0 if unavailable)
function M.get_skill_max_rank(skill_id)
  return APISurface.get_profession_max_rank(skill_id)
end

--- Check if the player has learned a profession.
-- @param skill_id integer
-- @return boolean
function M.has_profession(skill_id)
  return M.get_skill_rank(skill_id) > 0
end

--- Check if a profession can be crafted (has a window to open).
-- Gathering professions (Herbalism, Mining, Skinning, Fishing) return false.
-- @param skill_id integer
-- @return boolean
function M.can_craft_profession(skill_id)
  if not Constants.CRAFTABLE_SKILLS[skill_id] then return false end
  return M.has_profession(skill_id)
end

-- =============================================================================
-- Profession Window Management
-- =============================================================================

--- Open a profession window.
-- Tries core.profession.open_profession() (enum-based, locale-independent)
-- first, then falls back to CastSpellByName (legacy). The enum mapping is
-- built lazily from APISurface.PROFESSION_ENUM on first call.
-- @param skill_id integer  SkillLine.dbc ID
-- @return boolean  true if the open was issued
function M.open_profession(skill_id)
  local name = Constants.SKILL_NAMES[skill_id]
  if not name then return false end

  -- Primary: core.profession.open_profession (enum-based, locale-independent)
  ensure_skill_to_enum()
  local enum_val = _skill_to_enum[skill_id]
  if enum_val then
    if APISurface.open_profession(enum_val) then
      return true
    end
  end

  -- Fallback: CastSpellByName (legacy, locale-dependent)
  local fn = core and core.input and core.input.cast_spell_by_name
  if type(fn) == "function" then
    local ok = pcall(fn, name)
    return ok
  end

  return false
end

--- Close any open profession windows.
function M.close()
  APISurface.close_trade_skill()
  APISurface.close_craft()
end

-- =============================================================================
-- Recipe Scanning — TradeSkill Window
-- =============================================================================

--- Scan all recipes in the open TradeSkill window.
-- @return table[]  recipes { index, name, type, num_available, num_reagents, cooldown }
function M.scan_trade_skill_recipes()
  local recipes = {}
  local count = APISurface.get_num_trade_skills()
  if count <= 0 then return recipes end

  for i = 1, count do
    local info = APISurface.get_trade_skill_info(i)
    if info and info.name and info.name ~= "" and info.type ~= "header" then
      recipes[#recipes + 1] = {
        index         = i,
        name          = info.name,
        type          = info.type or "",
        num_available = info.num_available or 0,
        num_reagents  = APISurface.get_trade_skill_num_reagents(i),
        cooldown      = APISurface.get_trade_skill_cooldown(i),
      }
    end
  end

  return recipes
end

--- Find a recipe by name (case-insensitive substring match).
-- @param skill_id integer  Unused for window scanning; kept for API symmetry
-- @param recipe_name string  Name or substring to search for
-- @return table|nil  recipe entry from scan_trade_skill_recipes()
function M.find_recipe(skill_id, recipe_name)
  if type(recipe_name) ~= "string" or recipe_name == "" then return nil end
  local lower = recipe_name:lower()
  local recipes = M.scan_trade_skill_recipes()
  for _, recipe in ipairs(recipes) do
    if recipe.name:lower():find(lower, 1, true) then
      return recipe
    end
  end
  return nil
end

--- Check if the player has enough reagents for a trade-skill recipe.
-- @param index integer  Trade-skill list index
-- @return boolean  true if all reagents are available
function M.has_reagents(index)
  local num_reagents = APISurface.get_trade_skill_num_reagents(index)
  if num_reagents <= 0 then return true end

  for r = 1, num_reagents do
    local info = APISurface.get_trade_skill_reagent_info(index, r)
    if info then
      local needed   = info.count or 0
      local have     = info.player_count or 0
      if have < needed then
        return false
      end
    end
  end
  return true
end

-- =============================================================================
-- Recipe Scanning — Craft Window (Enchanting)
-- =============================================================================

--- Scan all recipes in the open Craft window (Enchanting).
-- @return table[]  recipes { index, name, type, num_available, num_reagents }
function M.scan_craft_recipes()
  local recipes = {}
  local count = APISurface.get_num_crafts()
  if count <= 0 then return recipes end

  for i = 1, count do
    local info = APISurface.get_craft_info(i)
    if info and info.name and info.name ~= "" and info.type ~= "header" then
      recipes[#recipes + 1] = {
        index         = i,
        name          = info.name,
        type          = info.type or "",
        num_available = info.num_available or 0,
        num_reagents  = APISurface.get_craft_num_reagents(i),
      }
    end
  end

  return recipes
end

--- Find a recipe in the Craft window by name (case-insensitive substring).
-- @param recipe_name string
-- @return table|nil
function M.find_craft_recipe(recipe_name)
  if type(recipe_name) ~= "string" or recipe_name == "" then return nil end
  local lower = recipe_name:lower()
  local recipes = M.scan_craft_recipes()
  for _, recipe in ipairs(recipes) do
    if recipe.name:lower():find(lower, 1, true) then
      return recipe
    end
  end
  return nil
end


-- =============================================================================
-- Crafting Operations
-- =============================================================================

--- Craft a recipe by name in a TradeSkill profession.
-- Opens the profession window, finds the recipe, and crafts it.
-- @param skill_id integer  SkillLine.dbc ID
-- @param recipe_name string  Recipe name (substring match)
-- @param count? integer  Number to craft (default 1)
-- @return boolean  true if the craft was issued
function M.craft_by_name(skill_id, recipe_name, count)
  if not M.can_craft_profession(skill_id) then return false end
  if type(recipe_name) ~= "string" then return false end
  count = count or 1

  -- Open the profession window
  M.open_profession(skill_id)

  -- Find the recipe
  local recipe = M.find_recipe(skill_id, recipe_name)
  if not recipe then return false end

  -- Check reagents and cooldown
  if not M.has_reagents(recipe.index) then return false end
  if recipe.cooldown > 0 then return false end

  -- Craft
  local ok = APISurface.do_trade_skill(recipe.index, count)
  if ok then
    _stats.crafts_attempted = _stats.crafts_attempted + 1
    _stats.crafts_succeeded = _stats.crafts_succeeded + 1
    _stats.last_craft_name  = recipe.name
  end
  return ok
end

--- Craft a recipe by index in a TradeSkill profession.
-- @param skill_id integer  SkillLine.dbc ID (for window opening)
-- @param index integer  Trade-skill list index
-- @param count? integer  Number to craft (default 1)
-- @return boolean  true if the craft was issued
function M.craft_by_index(skill_id, index, count)
  if not M.can_craft_profession(skill_id) then return false end
  if type(index) ~= "number" then return false end
  count = count or 1

  M.open_profession(skill_id)

  local info = APISurface.get_trade_skill_info(index)
  if not info or info.type == "header" then return false end
  if not M.has_reagents(index) then return false end
  if APISurface.get_trade_skill_cooldown(index) > 0 then return false end

  local ok = APISurface.do_trade_skill(index, count)
  if ok then
    _stats.crafts_attempted = _stats.crafts_attempted + 1
    _stats.crafts_succeeded = _stats.crafts_succeeded + 1
    _stats.last_craft_name  = info.name or ""
  end
  return ok
end

--- Craft an enchant by name (uses the Craft UI, not TradeSkill).
-- @param skill_id integer  Should be 333 (Enchanting)
-- @param recipe_name string  Enchant name (substring match)
-- @return boolean  true if the craft was issued
function M.craft_enchant_by_name(skill_id, recipe_name)
  if not M.can_craft_profession(skill_id) then return false end
  if type(recipe_name) ~= "string" then return false end

  M.open_profession(skill_id)

  local recipe = M.find_craft_recipe(recipe_name)
  if not recipe then return false end

  local ok = APISurface.do_craft(recipe.index)
  if ok then
    _stats.crafts_attempted = _stats.crafts_attempted + 1
    _stats.crafts_succeeded = _stats.crafts_succeeded + 1
    _stats.last_craft_name  = recipe.name
  end
  return ok
end

--- Mass-produce all available recipes in a profession.
-- Scans the open TradeSkill window and crafts everything that has reagents
-- and no cooldown, up to `max_per_recipe` copies each.
-- @param skill_id integer  SkillLine.dbc ID
-- @param max_per_recipe? integer  Max copies per recipe (default 1)
-- @return integer  total number of crafts issued
function M.craft_all(skill_id, max_per_recipe)
  if not M.can_craft_profession(skill_id) then return 0 end
  max_per_recipe = max_per_recipe or 1

  M.open_profession(skill_id)

  local recipes = M.scan_trade_skill_recipes()
  local total = 0

  for _, recipe in ipairs(recipes) do
    if recipe.cooldown <= 0 and recipe.num_available > 0 then
      local count = math.min(recipe.num_available, max_per_recipe)
      if M.has_reagents(recipe.index) then
        if APISurface.do_trade_skill(recipe.index, count) then
          total = total + count
          _stats.crafts_attempted = _stats.crafts_attempted + 1
          _stats.crafts_succeeded = _stats.crafts_succeeded + 1
          _stats.last_craft_name  = recipe.name
        end
      end
    end
  end

  return total
end

-- =============================================================================
-- Statistics
-- =============================================================================

--- Get crafting statistics.
-- @return table  { crafts_attempted, crafts_succeeded, last_craft_name }
function M.get_stats()
  return {
    crafts_attempted = _stats.crafts_attempted,
    crafts_succeeded = _stats.crafts_succeeded,
    last_craft_name  = _stats.last_craft_name,
  }
end

--- Reset crafting statistics.
function M.reset_stats()
  _stats.crafts_attempted = 0
  _stats.crafts_succeeded = 0
  _stats.last_craft_time  = 0
  _stats.last_craft_name  = ""
end

-- =============================================================================
-- Discovery: List Player's Professions
-- =============================================================================

--- Get a list of all professions the player has learned.
-- @return table[]  { skill_id, name, rank, max_rank, is_craftable }
function M.get_player_professions()
  local slots = APISurface.get_professions()
  local result = {}

  for _, idx in pairs(slots) do
    if type(idx) == "number" then
      local info = APISurface.get_profession_info(idx)
      if info and info.skill_line then
        local skill_id = info.skill_line
        result[#result + 1] = {
          skill_id     = skill_id,
          name         = info.name or Constants.SKILL_NAMES[skill_id] or "Unknown",
          rank         = math.floor(info.skill_level or 0),
          max_rank     = math.floor(info.max_skill_level or 0),
          is_craftable = Constants.CRAFTABLE_SKILLS[skill_id] == true,
        }
      end
    end
  end

  return result
end

return M
