-- =============================================================================
-- menu.lua — Menu widget setup + render for EaxProfession.
-- =============================================================================
-- WHAT:  Creates, stores, and RENDERS all Sylvanas menu widgets for the
--        crafting plugin. Exposes M.render() so main.lua's on_render_menu
--        can actually draw the tree_node + widgets into the main menu.
-- WHEN:  M.build() called once at startup (from main.lua). M.render() called
--        per-frame from on_render_menu while the menu is open.
-- WHY:   The previous version built widgets into a file-local _menu table that
--        main.lua could never see (it referenced a global _menu that did not
--        exist) — so the ENTIRE menu UI was invisible/non-functional. It also
--        created a combobox without supplying option labels (render requires
--        an options table per apidocs/pages/dev/api/ui.md) and never created
--        the wrapping tree_node or registered the render callback.
-- SAFETY: Every constructor is nil-guarded via safe_menu() (Pattern 1, AGENTS.md):
--         when core.menu or a constructor is absent (tests / older runtime), a
--         DUMMY widget with safe get/get_state defaults is returned instead.
--         All :get()/:get_state() accessors are nil-guarded with documented
--         fallbacks. No per-frame allocations.
-- =============================================================================

local M = {}

-- -----------------------------------------------------------------------------
-- Profession option labels, indexed to match PROFESSION_ORDER in main.lua.
-- The combobox stores a 1-based index; get_profession_index() maps it back.
-- -----------------------------------------------------------------------------
M.PROFESSION_OPTIONS = {
  "Alchemy",
  "Blacksmithing",
  "Leatherworking",
  "Tailoring",
  "Engineering",
  "Enchanting",
  "Cooking",
  "First Aid",
  "Jewelcrafting",
}

-- -----------------------------------------------------------------------------
-- Dummy widget — safe defaults when core.menu is unavailable (tests/old runtime)
-- -----------------------------------------------------------------------------
local DUMMY = {
  get_state = function() return false end,
  set       = function() end,
  get       = function() return 0 end,
  render    = function() end,
}

-- Safe menu constructor: returns DUMMY on any failure (nil core.menu, missing
-- constructor, or pcall error). Handles both `core.menu` being nil AND being
-- an empty table (the test mock sets core.menu = {}).
local function safe_menu(factory, ...)
  local c = rawget(_G, "core")
  local menu = c and c.menu
  if type(menu) ~= "table" then return DUMMY end
  if type(factory) ~= "function" then return DUMMY end
  local ok, result = pcall(factory, ...)
  if ok and result ~= nil then return result end
  return DUMMY
end

-- -----------------------------------------------------------------------------
-- Widget cache (populated by build(); reused every render frame)
-- -----------------------------------------------------------------------------
local _w = {}

-- -----------------------------------------------------------------------------
-- Build the menu tree ONCE at startup.
-- -----------------------------------------------------------------------------
function M.build()
  local c = rawget(_G, "core")
  local menu = c and c.menu
  -- No menu API at all → all widget refs stay DUMMY; accessors return defaults.
  if type(menu) ~= "table" then return end

  _w.root            = safe_menu(menu.tree_node)
  _w.enabled         = safe_menu(menu.checkbox, true,  "eaxprof_enabled")
  _w.profession      = safe_menu(menu.combobox, 1, "eaxprof_profession")
  _w.recipe_filter   = safe_menu(menu.text_input, "", "eaxprof_recipe_filter")
  _w.craft_count     = safe_menu(menu.slider_int, 1, 50, 1, "eaxprof_craft_count")
  _w.mass_craft      = safe_menu(menu.checkbox, false, "eaxprof_mass_craft")
  _w.auto_open       = safe_menu(menu.checkbox, true,  "eaxprof_auto_open")
  _w.skill_gain_mode = safe_menu(menu.checkbox, false, "eaxprof_skill_gain_mode")
end

-- -----------------------------------------------------------------------------
-- Render the menu tree into the main menu.
-- Called every frame from main.lua's on_render_menu callback.
-- -----------------------------------------------------------------------------
function M.render()
  -- tree_node:render(header, callback) — only valid inside the menu callback.
  if not _w.root then return end
  local root = _w.root
  if type(root.render) ~= "function" then return end

  local ok, err = pcall(root.render, root, "EaxProfession — Crafting Automation", function()
    if _w.enabled and _w.enabled.render then
      _w.enabled:render("Enable Crafting", "Master toggle for automated crafting.")
    end
    if _w.profession and _w.profession.render then
      _w.profession:render("Profession", M.PROFESSION_OPTIONS, "Which profession to automate.")
    end
    if _w.recipe_filter and _w.recipe_filter.render then
      _w.recipe_filter:render("Recipe Filter", "Substring match; blank = craft any available recipe.")
    end
    if _w.craft_count and _w.craft_count.render then
      _w.craft_count:render("Craft Count", "How many to craft (single-recipe mode).")
    end
    if _w.mass_craft and _w.mass_craft.render then
      _w.mass_craft:render("Mass Craft", "Craft ALL available recipes up to Craft Count each.")
    end
    if _w.auto_open and _w.auto_open.render then
      _w.auto_open:render("Auto-Open Window", "Open the profession window automatically.")
    end
    if _w.skill_gain_mode and _w.skill_gain_mode.render then
      _w.skill_gain_mode:render("Skill-Gain Mode", "Only craft orange/yellow recipes for skill ups.")
    end
  end)
  if not ok then
    -- Never crash the menu loop on a render error.
    local c = rawget(_G, "core")
    if c and type(c.log) == "function" then
      pcall(c.log, "[EaxProfession] menu render error: " .. tostring(err))
    end
  end
end

-- -----------------------------------------------------------------------------
-- Nil-guarded widget accessors.
-- Each returns the widget's current value or a safe default if the widget
-- is nil/DUMMY (menu not built, runtime missing, etc.).
-- -----------------------------------------------------------------------------

--- Is the crafting plugin enabled?
-- @return boolean
function M.is_enabled()
  return (_w.enabled and _w.enabled.get_state and _w.enabled:get_state()) or false
end

--- Get the selected profession index (1-based combobox).
-- Clamps to >= 1 so a DUMMY/missing widget (returns 0) yields a valid index.
-- @return integer
function M.get_profession_index()
  local idx = (_w.profession and _w.profession.get and _w.profession:get()) or 1
  if type(idx) ~= "number" or idx < 1 then idx = 1 end
  return idx
end

--- Get the recipe name filter text.
-- @return string
function M.get_recipe_filter()
  local f = (_w.recipe_filter and _w.recipe_filter.get and _w.recipe_filter:get())
  if type(f) ~= "string" then return "" end
  return f
end

--- Get the craft count.
-- Clamps to >= 1 so a DUMMY/missing widget (returns 0) yields a valid count.
-- @return integer
function M.get_craft_count()
  local cnt = (_w.craft_count and _w.craft_count.get and _w.craft_count:get()) or 1
  if type(cnt) ~= "number" or cnt < 1 then cnt = 1 end
  return cnt
end

--- Is mass craft mode enabled?
-- @return boolean
function M.is_mass_craft()
  return (_w.mass_craft and _w.mass_craft.get_state and _w.mass_craft:get_state()) or false
end

--- Should the profession window auto-open?
-- @return boolean
function M.is_auto_open()
  return (_w.auto_open and _w.auto_open.get_state and _w.auto_open:get_state()) or true
end

--- Is skill-gain mode enabled? (only craft orange/yellow recipes)
-- @return boolean
function M.is_skill_gain_mode()
  return (_w.skill_gain_mode and _w.skill_gain_mode.get_state and _w.skill_gain_mode:get_state()) or false
end

return M