-- =============================================================================
-- menu.lua — Menu widget setup for EaxProfession.
-- =============================================================================
-- WHAT:  Creates and manages the Sylvanas menu UI for the crafting plugin.
-- WHEN:  Called once at startup from main.lua to build the menu tree.
-- WHY:   Centralizes all menu widget creation in one place with nil-guarded
--        accessors. All widgets are nil-guarded per Pattern 1 (AGENTS.md).
-- SAFETY: Every widget:get() call is guarded: (menu.x and menu.x:get()) or default.
-- =============================================================================

local M = {}

-- Menu widget references (populated by build())
local _menu = {}

-- -----------------------------------------------------------------------------
-- Build the menu tree.
-- Called once at startup. All widgets are stored in `_menu` for later access.
-- -----------------------------------------------------------------------------
function M.build()
  local menu = core and core.menu
  if not menu then return end

  -- Main window
  _menu.window = menu.window and menu.window("EaxProfession — Crafting Automation")

  -- Enable checkbox (master toggle)
  _menu.enabled = menu.checkbox(true, "eaxprof_enabled")

  -- Profession selection (combobox: 1=Alchemy, 2=Blacksmithing, ...)
  _menu.profession = menu.combobox(1, "eaxprof_profession")

  -- Recipe name filter (text input — not available on all clients, so pcall)
  if menu.text_input then
    _menu.recipe_filter = menu.text_input("", "eaxprof_recipe_filter")
  end

  -- Craft count slider
  _menu.craft_count = menu.slider_int(1, 50, 1, "eaxprof_craft_count")

  -- Mass craft checkbox
  _menu.mass_craft = menu.checkbox(false, "eaxprof_mass_craft")

  -- Auto-open window checkbox
  _menu.auto_open = menu.checkbox(true, "eaxprof_auto_open")
end

-- -----------------------------------------------------------------------------
-- Nil-guarded widget accessors.
-- Each returns the widget's current value or a safe default if the widget
-- is nil (menu not built, runtime missing, etc.).
-- -----------------------------------------------------------------------------

--- Is the crafting plugin enabled?
-- @return boolean
function M.is_enabled()
  return (_menu.enabled and _menu.enabled:get()) or false
end

--- Get the selected profession index (1-based combobox).
-- @return integer
function M.get_profession_index()
  return (_menu.profession and _menu.profession:get()) or 1
end

--- Get the recipe name filter text.
-- @return string
function M.get_recipe_filter()
  return (_menu.recipe_filter and _menu.recipe_filter:get()) or ""
end

--- Get the craft count.
-- @return integer
function M.get_craft_count()
  return (_menu.craft_count and _menu.craft_count:get()) or 1
end

--- Is mass craft mode enabled?
-- @return boolean
function M.is_mass_craft()
  return (_menu.mass_craft and _menu.mass_craft:get()) or false
end

--- Should the profession window auto-open?
-- @return boolean
function M.is_auto_open()
  return (_menu.auto_open and _menu.auto_open:get()) or true
end

return M
