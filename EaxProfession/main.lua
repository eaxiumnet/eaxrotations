-- =============================================================================
-- main.lua — Entry point for EaxProfession (Project Sylvanas crafting plugin).
-- =============================================================================
-- WHAT:  Sylvanas plugin that automates crafting professions using Silvi's
--        2026-07-01 profession API additions (core.profession, core.trade_skill,
--        core.craft, core.skill, core.spell_book.get_professions).
-- WHEN:  Loaded by the Sylvanas runtime. Registers on_update + on_render_menu
--        callbacks. Dispatches to the crafting engine when enabled.
-- WHY:   Clean, standalone, single-purpose crafting automation — no gathering,
--        no navigation, no combat. Just craft.
-- SAFETY: All runtime access goes through api_surface (pcall-wrapped). Menu
--        widgets are nil-guarded. No per-frame allocations.
-- =============================================================================

local APISurface       = require("core/api_surface")
local CraftingEngine   = require("professions/crafting_engine")
local Menu             = require("ui/menu")
local Constants        = require("data/profession_constants")

-- -----------------------------------------------------------------------------
-- Build the menu tree at load time
-- -----------------------------------------------------------------------------
Menu.build()

-- -----------------------------------------------------------------------------
-- Professions list (indexed by combobox selection — 1-based)
-- -----------------------------------------------------------------------------
local PROFESSION_ORDER = {
  Constants.SKILL_ALCHEMY,
  Constants.SKILL_BLACKSMITHING,
  Constants.SKILL_LEATHERWORKING,
  Constants.SKILL_TAILORING,
  Constants.SKILL_ENGINEERING,
  Constants.SKILL_ENCHANTING,
  Constants.SKILL_COOKING,
  Constants.SKILL_FIRST_AID,
  Constants.SKILL_JEWELCRAFTING,
}

-- -----------------------------------------------------------------------------
-- on_update — Called every frame by the Sylvanas runtime.
-- Throttled to avoid spamming the trade_skill API every frame.
-- -----------------------------------------------------------------------------
local _last_update_time = 0
local _update_interval  = 1.0  -- seconds between craft attempts

function on_update()
  if not Menu.is_enabled() then return end

  -- Throttle: only attempt crafting once per second
  local now = core and core.time and core.time() or 0
  if now - _last_update_time < _update_interval then return end
  _last_update_time = now

  -- Get selected profession
  local prof_idx = Menu.get_profession_index()
  local skill_id = PROFESSION_ORDER[prof_idx]
  if not skill_id then return end

  -- Verify the player has this profession
  if not CraftingEngine.can_craft_profession(skill_id) then return end

  -- Open the profession window if auto-open is enabled
  if Menu.is_auto_open() then
    CraftingEngine.open_profession(skill_id)
  end

  -- Skill-gain mode: when enabled, only orange/yellow recipes (skill-ups) are
  -- eligible. This passes a filter hint to the crafting engine so it skips
  -- grey/green recipes that would waste reagents for no skill gain.
  local skill_gain = Menu.is_skill_gain_mode()

  -- Execute the selected crafting mode
  if Menu.is_mass_craft() then
    CraftingEngine.craft_all(skill_id, Menu.get_craft_count(), skill_gain)
  else
    local filter = Menu.get_recipe_filter()
    if filter and filter ~= "" then
      if Constants.CRAFT_UI_SKILLS[skill_id] then
        CraftingEngine.craft_enchant_by_name(skill_id, filter, skill_gain)
      else
        CraftingEngine.craft_by_name(skill_id, filter, Menu.get_craft_count(), skill_gain)
      end
    end
  end
end

-- -----------------------------------------------------------------------------
-- on_render_menu — Draw the menu UI (called by Sylvanas when menu is open)
-- Delegates to Menu.render() which draws the tree_node + all widgets.
-- Previously referenced an undefined global `_menu` (it was file-local in
-- menu.lua) so the menu NEVER rendered. Now fixed.
-- -----------------------------------------------------------------------------
function on_render_menu()
  Menu.render()
end

-- -----------------------------------------------------------------------------
-- on_render — Draw ESP / overlays (stub — no rendering needed for crafting)
-- -----------------------------------------------------------------------------
function on_render()
  -- Crafting is stationary; no ESP overlay needed.
  -- Stub kept for API symmetry with other Eax plugins.
end

return {
  api_surface     = APISurface,
  crafting_engine = CraftingEngine,
  menu            = Menu,
  constants       = Constants,
}
