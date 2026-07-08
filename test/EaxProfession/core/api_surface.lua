-- =============================================================================
-- api_surface.lua — Single API adapter for all Project Sylvanas runtime calls.
-- =============================================================================
-- WHAT:  The ONLY module in EaxProfession that touches raw `core.*` globals.
--        Every other module calls functions on this adapter instead.
-- WHEN:  Loaded once at startup; cached references are reused every frame.
-- WHY:   1. Clean abstraction over Sylvanas runtime APIs.
--        2. All pcall wrapping in one place — callers never crash.
--        3. Safe defaults when APIs are absent (graceful degradation).
--        4. Centralized documentation of every API used.
--        5. Easy migration when Silvi adds/changes APIs.
-- SAFETY: Every function is pcall-wrapped. Nil `core` is handled at load time.
--         No per-frame allocations — all namespace references cached at load.
-- =============================================================================
-- API namespaces covered (added by Silvi 2026-07-01):
--   core.spell_book.get_professions / get_profession_info
--   core.profession (enum + open_profession)
--   core.trade_skill (classic index-based + retail C_TradeSkillUI)
--   core.craft (classic Craft UI for Enchanting)
--   core.skill (classic Skill window)
-- =============================================================================

local M = {}

-- -----------------------------------------------------------------------------
-- API Caching at Load Time
-- -----------------------------------------------------------------------------
-- Cache namespace references ONCE at module load. This avoids per-call table
-- lookups (`core.trade_skill.do_trade_skill` → 3 table indexes per call) and
-- is the #1 performance pattern for Sylvanas plugins.
--
-- If `core` is nil (unit-test environment or runtime not ready), all cached
-- references fall back to empty tables and every wrapper returns safe defaults.
-- -----------------------------------------------------------------------------
local _core        = core or {}
local _spell_book  = _core.spell_book or {}
local _profession  = _core.profession or {}
local _trade_skill = _core.trade_skill or {}
local _craft       = _core.craft or {}
local _skill       = _core.skill or {}

-- The core.profession enum table (passed through for consumers).
-- Contains: ALCHEMY, BLACKSMITHING, COOKING, ENCHANTING, ENGINEERING,
-- FIRST_AID, FISHING, INSCRIPTION, JEWELCRAFTING, LEATHERWORKING,
-- MINING, SKINNING, TAILORING.
M.PROFESSION_ENUM = _profession

-- =============================================================================
-- core.spell_book — Profession Discovery
-- =============================================================================

--- Get the player's profession spell-tab indices.
-- Wraps `core.spell_book.get_professions()`. Returns a table with named slots:
-- `{ prof1 = N, prof2 = N, cooking = N, fishing = N, archaeology = N }`.
-- @return table slots (empty table if API unavailable or call fails)
function M.get_professions()
  local fn = _spell_book.get_professions
  if type(fn) ~= "function" then return {} end
  local ok, result = pcall(fn)
  if ok and type(result) == "table" then return result end
  return {}
end

--- Get detailed info for a profession spell-tab index.
-- Wraps `core.spell_book.get_profession_info(index)`.
-- @param index integer  Spell-tab index from get_professions()
-- @return table|nil  info { name, skill_level, max_skill_level, skill_line, ... }
function M.get_profession_info(index)
  if type(index) ~= "number" then return nil end
  local fn = _spell_book.get_profession_info
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn, index)
  if ok and type(result) == "table" then return result end
  return nil
end

--- Get the player's current skill rank for a profession skill-line ID.
-- Iterates get_professions() + get_profession_info() to find the matching
-- skill_line, then returns its skill_level. Falls back to legacy
-- core.get_player_skill_index() if the new API is unavailable.
-- @param skill_line_id integer  SkillLine.dbc ID (e.g. 171 for Alchemy)
-- @return integer  rank (0 when unknown, not learned, or API absent)
function M.get_profession_skill_rank(skill_line_id)
  if type(skill_line_id) ~= "number" or skill_line_id <= 0 then return 0 end

  -- Primary: new profession API (Silvi 2026-07-01)
  local fn = _spell_book.get_professions
  if type(fn) == "function" then
    local ok, slots = pcall(fn)
    if ok and type(slots) == "table" then
      for _, idx in pairs(slots) do
        if type(idx) == "number" then
          local info = M.get_profession_info(idx)
          if info and info.skill_line == skill_line_id then
            return math.max(0, math.floor(info.skill_level or 0))
          end
        end
      end
    end
  end

  -- Fallback: legacy core.get_player_skill_index (older Sylvanas builds)
  local legacy = _core.get_player_skill_index
  if type(legacy) == "function" then
    local ok2, rank = pcall(legacy, skill_line_id)
    if ok2 and type(rank) == "number" then
      return math.max(0, math.floor(rank))
    end
  end

  return 0
end

--- Get max skill level for a profession skill-line ID.
-- @param skill_line_id integer  SkillLine.dbc ID
-- @return integer  max_rank (0 when unknown or API absent)
function M.get_profession_max_rank(skill_line_id)
  if type(skill_line_id) ~= "number" or skill_line_id <= 0 then return 0 end

  local fn = _spell_book.get_professions
  if type(fn) ~= "function" then return 0 end
  local ok, slots = pcall(fn)
  if not ok or type(slots) ~= "table" then return 0 end

  for _, idx in pairs(slots) do
    if type(idx) == "number" then
      local info = M.get_profession_info(idx)
      if info and info.skill_line == skill_line_id then
        return math.max(0, math.floor(info.max_skill_level or 0))
      end
    end
  end
  return 0
end

-- =============================================================================
-- core.profession — Enum + Window Opener
-- =============================================================================

--- Open a profession window by enum value.
-- Wraps `core.profession.open_profession(enum)`. Opens the window by casting
-- the profession's Apprentice-rank spell (locale-independent).
-- @param profession_enum integer  A core.profession.* enum value
-- @return boolean  true if the open/cast was issued; false if unavailable
function M.open_profession(profession_enum)
  if type(profession_enum) ~= "number" then return false end
  local fn = _profession.open_profession
  if type(fn) ~= "function" then return false end
  local ok, result = pcall(fn, profession_enum)
  return ok and result == true
end

-- =============================================================================
-- core.trade_skill — Classic Index-Based TradeSkill API
-- =============================================================================
-- These functions operate on the currently-open TradeSkill window. The window
-- must be opened first via open_profession() or CastSpellByName.
-- -----------------------------------------------------------------------------

--- Craft `repeat_count` copies of the trade-skill at `index` (DoTradeSkill).
-- @param index integer  Trade-skill list index
-- @param repeat_count? integer  Number of copies (default 1)
-- @return boolean  true if the call was issued; false if API unavailable
function M.do_trade_skill(index, repeat_count)
  if type(index) ~= "number" then return false end
  local fn = _trade_skill.do_trade_skill
  if type(fn) ~= "function" then return false end
  local ok = pcall(fn, index, repeat_count or 1)
  return ok
end

--- Get the number of entries in the open trade-skill window.
-- @return integer  count (0 if window closed or API unavailable)
function M.get_num_trade_skills()
  local fn = _trade_skill.get_num_trade_skills
  if type(fn) ~= "function" then return 0 end
  local ok, result = pcall(fn)
  if ok and type(result) == "number" then return math.floor(result) end
  return 0
end

--- Get trade-skill info for a list index (GetTradeSkillInfo).
-- @param index integer  Trade-skill list index
-- @return table|nil  info { name, type, num_available, is_expanded, ... }
function M.get_trade_skill_info(index)
  if type(index) ~= "number" then return nil end
  local fn = _trade_skill.get_trade_skill_info
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn, index)
  if ok and type(result) == "table" then return result end
  return nil
end

--- Get the number of reagents for a trade-skill (GetTradeSkillNumReagents).
-- @param index integer  Trade-skill list index
-- @return integer  count (0 if unavailable)
function M.get_trade_skill_num_reagents(index)
  if type(index) ~= "number" then return 0 end
  local fn = _trade_skill.get_trade_skill_num_reagents
  if type(fn) ~= "function" then return 0 end
  local ok, result = pcall(fn, index)
  if ok and type(result) == "number" then return math.floor(result) end
  return 0
end

--- Get reagent info for a trade-skill (GetTradeSkillReagentInfo).
-- @param index integer  Trade-skill list index
-- @param reagent_index integer  1-based reagent index
-- @return table|nil  info { name, texture, count, player_count }
function M.get_trade_skill_reagent_info(index, reagent_index)
  if type(index) ~= "number" or type(reagent_index) ~= "number" then return nil end
  local fn = _trade_skill.get_trade_skill_reagent_info
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn, index, reagent_index)
  if ok and type(result) == "table" then return result end
  return nil
end

--- Get the current trade-skill line (GetTradeSkillLine).
-- @return table|nil  { name, rank, max_rank, skill_line_modifier }
function M.get_trade_skill_line()
  local fn = _trade_skill.get_trade_skill_line
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn)
  if ok and type(result) == "table" then return result end
  return nil
end

--- Close the trade-skill window (CloseTradeSkill).
function M.close_trade_skill()
  local fn = _trade_skill.close
  if type(fn) == "function" then pcall(fn) end
end

--- Get min/max quantity produced per craft (GetTradeSkillNumMade).
-- @param index integer  Trade-skill list index
-- @return table  { min_made, max_made } (empty table if unavailable)
function M.get_trade_skill_num_made(index)
  if type(index) ~= "number" then return {} end
  local fn = _trade_skill.get_trade_skill_num_made
  if type(fn) ~= "function" then return {} end
  local ok, result = pcall(fn, index)
  if ok and type(result) == "table" then return result end
  return {}
end


--- Get the remaining cooldown for a trade-skill in seconds.
-- @param index integer  Trade-skill list index
-- @return integer  seconds (0 if none or unavailable)
function M.get_trade_skill_cooldown(index)
  if type(index) ~= "number" then return 0 end
  local fn = _trade_skill.get_trade_skill_cooldown
  if type(fn) ~= "function" then return 0 end
  local ok, result = pcall(fn, index)
  if ok and type(result) == "number" then return math.floor(result) end
  return 0
end

--- Select a trade-skill list row (SelectTradeSkill).
-- @param index integer  Trade-skill list index
function M.select_trade_skill(index)
  if type(index) ~= "number" then return end
  local fn = _trade_skill.select_trade_skill
  if type(fn) == "function" then pcall(fn, index) end
end

--- Get the currently selected trade-skill index.
-- @return integer  index (0 if none)
function M.get_trade_skill_selection_index()
  local fn = _trade_skill.get_trade_skill_selection_index
  if type(fn) ~= "function" then return 0 end
  local ok, result = pcall(fn)
  if ok and type(result) == "number" then return math.floor(result) end
  return 0
end

--- Get how many repeat crafts are queued.
-- @return integer  count
function M.get_tradeskill_repeat_count()
  local fn = _trade_skill.get_tradeskill_repeat_count
  if type(fn) ~= "function" then return 0 end
  local ok, result = pcall(fn)
  if ok and type(result) == "number" then return math.floor(result) end
  return 0
end

--- Get the index of the first non-header trade-skill.
-- @return integer  index (0 if none)
function M.get_first_trade_skill()
  local fn = _trade_skill.get_first_trade_skill
  if type(fn) ~= "function" then return 0 end
  local ok, result = pcall(fn)
  if ok and type(result) == "number" then return math.floor(result) end
  return 0
end

--- Get max number of primary professions (always 2 on WoW).
-- @return integer  count (0 if unavailable)
function M.get_num_primary_professions()
  local fn = _trade_skill.get_num_primary_professions
  if type(fn) ~= "function" then return 0 end
  local ok, result = pcall(fn)
  if ok and type(result) == "number" then return math.floor(result) end
  return 0
end

--- Get the recipe item link for a trade-skill.
-- @param index integer
-- @return string|nil  link
function M.get_trade_skill_recipe_link(index)
  if type(index) ~= "number" then return nil end
  local fn = _trade_skill.get_trade_skill_recipe_link
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn, index)
  if ok then return result end
  return nil
end

--- Get the crafted item link for a trade-skill.
-- @param index integer
-- @return string|nil  link
function M.get_trade_skill_item_link(index)
  if type(index) ~= "number" then return nil end
  local fn = _trade_skill.get_trade_skill_item_link
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn, index)
  if ok then return result end
  return nil
end

--- Get the crafted item icon for a trade-skill.
-- @param index integer
-- @return string|nil  texture path
function M.get_trade_skill_icon(index)
  if type(index) ~= "number" then return nil end
  local fn = _trade_skill.get_trade_skill_icon
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn, index)
  if ok then return result end
  return nil
end

--- Get the required tools for a trade-skill.
-- @param index integer
-- @return string[]  tools (empty if none)
function M.get_trade_skill_tools(index)
  if type(index) ~= "number" then return {} end
  local fn = _trade_skill.get_trade_skill_tools
  if type(fn) ~= "function" then return {} end
  local ok, result = pcall(fn, index)
  if ok and type(result) == "table" then return result end
  return {}
end

--- Get a reagent's item link for a trade-skill.
-- @param index integer
-- @param reagent_index integer
-- @return string|nil  link
function M.get_trade_skill_reagent_item_link(index, reagent_index)
  if type(index) ~= "number" or type(reagent_index) ~= "number" then return nil end
  local fn = _trade_skill.get_trade_skill_reagent_item_link
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn, index, reagent_index)
  if ok then return result end
  return nil
end

-- =============================================================================
-- core.trade_skill — Retail C_TradeSkillUI (recipe spell IDs)
-- =============================================================================
-- These functions use recipe spell IDs instead of window indices. They are
-- primarily for retail but are exposed on all clients for forward compatibility.
-- -----------------------------------------------------------------------------

--- Craft a recipe by spell ID (C_TradeSkillUI.CraftRecipe).
-- @param recipe_spell_id integer
-- @param num_casts? integer  Number of crafts to queue (default 1)
-- @param apply_concentration? boolean  Spend concentration (default false)
-- @return boolean  success
function M.craft_recipe(recipe_spell_id, num_casts, apply_concentration)
  if type(recipe_spell_id) ~= "number" then return false end
  local fn = _trade_skill.craft_recipe
  if type(fn) ~= "function" then return false end
  local ok = pcall(fn, recipe_spell_id, num_casts or 1, apply_concentration or false)
  return ok
end

--- Open a profession window by skill-line ID (C_TradeSkillUI.OpenTradeSkill).
-- @param skill_line_id integer
-- @return boolean  opened
function M.open_trade_skill(skill_line_id)
  if type(skill_line_id) ~= "number" then return false end
  local fn = _trade_skill.open_trade_skill
  if type(fn) ~= "function" then return false end
  local ok, result = pcall(fn, skill_line_id)
  return ok and result == true
end

--- Close the retail trade-skill window.
function M.close_trade_skill_retail()
  local fn = _trade_skill.close_trade_skill
  if type(fn) == "function" then pcall(fn) end
end

--- Get curated recipe info (C_TradeSkillUI.GetRecipeInfo).
-- @param recipe_spell_id integer
-- @param recipe_level? integer
-- @return table|nil  recipe_info
function M.get_recipe_info(recipe_spell_id, recipe_level)
  if type(recipe_spell_id) ~= "number" then return nil end
  local fn = _trade_skill.get_recipe_info
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn, recipe_spell_id, recipe_level or 0)
  if ok and type(result) == "table" then return result end
  return nil
end

--- Get all learned recipe spell IDs for the open profession.
-- @return integer[]  recipe_ids (empty if unavailable)
function M.get_all_recipe_ids()
  local fn = _trade_skill.get_all_recipe_ids
  if type(fn) ~= "function" then return {} end
  local ok, result = pcall(fn)
  if ok and type(result) == "table" then return result end
  return {}
end

--- Get how many copies of a recipe the player can craft.
-- @param recipe_spell_id integer
-- @param recipe_level? integer
-- @return integer  count
function M.get_craftable_count(recipe_spell_id, recipe_level)
  if type(recipe_spell_id) ~= "number" then return 0 end
  local fn = _trade_skill.get_craftable_count
  if type(fn) ~= "function" then return 0 end
  local ok, result = pcall(fn, recipe_spell_id, recipe_level or 0)
  if ok and type(result) == "number" then return math.floor(result) end
  return 0
end

--- Get the remaining cooldown for a recipe in seconds.
-- @param recipe_spell_id integer
-- @return integer  seconds (0 if none)
function M.get_recipe_cooldown(recipe_spell_id)
  if type(recipe_spell_id) ~= "number" then return 0 end
  local fn = _trade_skill.get_recipe_cooldown
  if type(fn) ~= "function" then return 0 end
  local ok, result = pcall(fn, recipe_spell_id)
  if ok and type(result) == "number" then return math.floor(result) end
  return 0
end

-- =============================================================================
-- core.craft — Classic Craft API (Enchanting / Beast Training)
-- =============================================================================
-- Enchanting uses the Craft UI instead of the TradeSkill UI on TBC Classic.
-- -----------------------------------------------------------------------------

--- Perform the craft at the given index (DoCraft).
-- @param index integer  Craft list index
-- @return boolean  success
function M.do_craft(index)
  if type(index) ~= "number" then return false end
  local fn = _craft.do_craft
  if type(fn) ~= "function" then return false end
  local ok = pcall(fn, index)
  return ok
end

--- Get the number of entries in the open craft window (GetNumCrafts).
-- @return integer  count (0 if window closed)
function M.get_num_crafts()
  local fn = _craft.get_num_crafts
  if type(fn) ~= "function" then return 0 end
  local ok, result = pcall(fn)
  if ok and type(result) == "number" then return math.floor(result) end
  return 0
end

--- Get info for a craft list row (GetCraftInfo).
-- @param index integer  Craft list index
-- @return table|nil  { name, sub_spell_name, type, num_available, ... }
function M.get_craft_info(index)
  if type(index) ~= "number" then return nil end
  local fn = _craft.get_craft_info
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn, index)
  if ok and type(result) == "table" then return result end
  return nil
end

--- Get the number of reagents for a craft (GetCraftNumReagents).
-- @param index integer  Craft list index
-- @return integer  count
function M.get_craft_num_reagents(index)
  if type(index) ~= "number" then return 0 end
  local fn = _craft.get_craft_num_reagents
  if type(fn) ~= "function" then return 0 end
  local ok, result = pcall(fn, index)
  if ok and type(result) == "number" then return math.floor(result) end
  return 0
end

--- Get reagent info for a craft (GetCraftReagentInfo).
-- @param index integer  Craft list index
-- @param reagent_index integer  1-based reagent index
-- @return table|nil  { name, texture, count, player_count }
function M.get_craft_reagent_info(index, reagent_index)
  if type(index) ~= "number" or type(reagent_index) ~= "number" then return nil end
  local fn = _craft.get_craft_reagent_info
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn, index, reagent_index)
  if ok and type(result) == "table" then return result end
  return nil
end

--- Close the craft window (CloseCraft).
function M.close_craft()
  local fn = _craft.close
  if type(fn) == "function" then pcall(fn) end
end

--- Get the name of the open craft window (GetCraftName).
-- @return string|nil  name
function M.get_craft_name()
  local fn = _craft.get_craft_name
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn)
  if ok then return result end
  return nil
end

--- Get the currently selected craft index (GetCraftSelectionIndex).
-- @return integer  index (0 if none)
function M.get_craft_selection_index()
  local fn = _craft.get_craft_selection_index
  if type(fn) ~= "function" then return 0 end
  local ok, result = pcall(fn)
  if ok and type(result) == "number" then return math.floor(result) end
  return 0
end

--- Select a craft list row (SelectCraft).
-- @param index integer
function M.select_craft(index)
  if type(index) ~= "number" then return end
  local fn = _craft.select_craft
  if type(fn) == "function" then pcall(fn, index) end
end

-- =============================================================================
-- core.skill — Classic Skill Window API
-- =============================================================================

--- Get the number of skill lines (GetNumSkillLines).
-- @return integer  count (0 if unavailable)
function M.get_num_skill_lines()
  local fn = _skill.get_num_skill_lines
  if type(fn) ~= "function" then return 0 end
  local ok, result = pcall(fn)
  if ok and type(result) == "number" then return math.floor(result) end
  return 0
end

--- Get info for a skill line (GetSkillLineInfo).
-- @param index integer  Skill-line index
-- @return table|nil  { name, is_header, is_expanded, skill_rank, ... }
function M.get_skill_line_info(index)
  if type(index) ~= "number" then return nil end
  local fn = _skill.get_skill_line_info
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn, index)
  if ok and type(result) == "table" then return result end
  return nil
end

--- Get the currently selected skill index (GetSelectedSkill).
-- @return integer  index (0 if none)
function M.get_selected_skill()
  local fn = _skill.get_selected_skill
  if type(fn) ~= "function" then return 0 end
  local ok, result = pcall(fn)
  if ok and type(result) == "number" then return math.floor(result) end
  return 0
end

--- Check if a trainer service teaches a spell (IsTrainerServiceLearnSpell).
-- @param index integer  Trainer service index
-- @return boolean  true if the service learns a spell
function M.is_trainer_service_learn_spell(index)
  if type(index) ~= "number" then return false end
  local fn = _skill.is_trainer_service_learn_spell
  if type(fn) ~= "function" then return false end
  local ok, result = pcall(fn, index)
  return ok and result == true
end

-- =============================================================================
-- Utility: API Availability Probing
-- =============================================================================

--- Check if the trade_skill API is available on this client.
-- @return boolean
function M.is_trade_skill_available()
  return type(_trade_skill.do_trade_skill) == "function"
     or type(_trade_skill.get_num_trade_skills) == "function"
end

--- Check if the craft API is available on this client.
-- @return boolean
function M.is_craft_available()
  return type(_craft.do_craft) == "function"
     or type(_craft.get_num_crafts) == "function"
end

--- Check if the profession enum API is available.
-- @return boolean
function M.is_profession_enum_available()
  return type(_profession.open_profession) == "function"
end

--- Get a summary of which API families are available on this client.
-- @return table  { trade_skill, craft, profession_enum, spell_book_professions }
function M.get_api_status()
  return {
    trade_skill            = M.is_trade_skill_available(),
    craft                  = M.is_craft_available(),
    profession_enum        = M.is_profession_enum_available(),
    spell_book_professions = type(_spell_book.get_professions) == "function",
  }
end

return M



