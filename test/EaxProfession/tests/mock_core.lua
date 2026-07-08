-- =============================================================================
-- mock_core.lua — Mock `core` global for unit testing EaxProfession.
-- =============================================================================
-- WHAT:  Simulates all Project Sylvanas profession APIs for offline testing.
-- WHEN:  Required by test files before loading api_surface.lua / crafting_engine.lua.
-- WHY:   Tests run in plain Lua (no Sylvanas runtime). This mock provides the
--        `core` global that api_surface.lua caches at load time.
-- SAFETY: Pure Lua, no side effects. reset() wipes all state between tests.
-- =============================================================================

local M = {}

-- -----------------------------------------------------------------------------
-- State (resettable between tests)
-- -----------------------------------------------------------------------------
function M.reset()
  M._skill_ranks = {}           -- skill_line_id → rank
  M._skill_max = {}             -- skill_line_id → max_rank
  M._trade_skill_recipes = {}   -- index → recipe info
  M._craft_recipes = {}         -- index → craft info
  M._trade_skill_do_calls = {}  -- recorded do_trade_skill calls
  M._craft_do_calls = {}        -- recorded do_craft calls
  M._profession_opened = nil    -- last open_profession enum value
  M._trade_skill_window_open = false
  M._craft_window_open = false
  M._cast_spell_by_name_calls = {}
  M._time = 0
end

-- Initialize state
M.reset()

-- Skill line names (mirrors profession_constants.lua)
local SKILL_NAMES = {
  [171] = "Alchemy", [164] = "Blacksmithing", [165] = "Leatherworking",
  [197] = "Tailoring", [202] = "Engineering",  [333] = "Enchanting",
  [185] = "Cooking",  [129] = "First Aid",    [755] = "Jewelcrafting",
  [182] = "Herbalism", [186] = "Mining",       [393] = "Skinning",
  [356] = "Fishing",
}

-- -----------------------------------------------------------------------------
-- core.spell_book — Profession Discovery Mock
-- -----------------------------------------------------------------------------
M.spell_book = {}

--- Returns profession spell-tab indices derived from _skill_ranks.
function M.spell_book.get_professions()
  local slots = {}
  local prof_count = 0
  local slot_idx = 1
  for skill_id, rank in pairs(M._skill_ranks) do
    if type(rank) == "number" and rank > 0 and SKILL_NAMES[skill_id] then
      prof_count = prof_count + 1
      if prof_count == 1 then
        slots.prof1 = slot_idx; slot_idx = slot_idx + 1
      elseif prof_count == 2 then
        slots.prof2 = slot_idx; slot_idx = slot_idx + 1
      elseif skill_id == 185 then
        slots.cooking = slot_idx; slot_idx = slot_idx + 1
      end
    end
  end
  return slots
end

--- Returns profession info for a spell-tab index.
function M.spell_book.get_profession_info(index)
  local known = {}
  for skill_id, rank in pairs(M._skill_ranks) do
    if type(rank) == "number" and rank > 0 and SKILL_NAMES[skill_id] then
      known[#known + 1] = skill_id
    end
  end
  table.sort(known)
  local skill_id = known[index]
  if not skill_id then return nil end
  return {
    name            = SKILL_NAMES[skill_id],
    icon            = 0,
    skill_level     = math.floor(M._skill_ranks[skill_id] or 0),
    max_skill_level = M._skill_max[skill_id] or 375,
    num_abilities   = 0,
    spell_offset    = 0,
    skill_line      = skill_id,
    skill_modifier  = 0,
    skill_line_name = SKILL_NAMES[skill_id],
  }
end

-- -----------------------------------------------------------------------------
-- core.profession — Enum + Opener Mock
-- -----------------------------------------------------------------------------
M.profession = {
  ALCHEMY = 1, BLACKSMITHING = 2, COOKING = 3, ENCHANTING = 4,
  ENGINEERING = 5, FIRST_AID = 6, FISHING = 7, INSCRIPTION = 8,
  JEWELCRAFTING = 9, LEATHERWORKING = 10, MINING = 11, SKINNING = 12,
  TAILORING = 13,
}

function M.profession.open_profession(prof_enum)
  M._profession_opened = prof_enum
  M._trade_skill_window_open = true
  return true
end
-- -----------------------------------------------------------------------------
-- core.trade_skill — Classic + Retail Mock
-- -----------------------------------------------------------------------------
M.trade_skill = {}

function M.trade_skill.do_trade_skill(idx, repeat_count)
  M._trade_skill_do_calls[#M._trade_skill_do_calls + 1] = {
    index = idx, count = repeat_count or 1
  }
end

function M.trade_skill.get_num_trade_skills()
  if not M._trade_skill_window_open then return 0 end
  local count = 0
  for _ in pairs(M._trade_skill_recipes) do count = count + 1 end
  return count
end

function M.trade_skill.get_trade_skill_info(idx)
  if not M._trade_skill_window_open then return nil end
  local r = M._trade_skill_recipes[idx]
  if not r then return nil end
  return {
    name          = r.name,
    type          = r.type or "optimal",
    num_available = r.num_available or 0,
    is_expanded   = false,
    alt_verb      = "",
    num_skill_ups = 1,
  }
end

function M.trade_skill.get_trade_skill_num_reagents(idx)
  local r = M._trade_skill_recipes[idx]
  if not r or not r.reagents then return 0 end
  return #r.reagents
end

function M.trade_skill.get_trade_skill_reagent_info(idx, ri)
  local r = M._trade_skill_recipes[idx]
  if not r or not r.reagents then return nil end
  local reg = r.reagents[ri]
  if not reg then return nil end
  return {
    name         = reg.name or "Reagent",
    texture      = "",
    count        = reg.count or 1,
    player_count = reg.player_count or 0,
  }
end

function M.trade_skill.get_trade_skill_line()
  if not M._trade_skill_window_open then return nil end
  return { name = "MockTradeSkill", rank = 300, max_rank = 375, skill_line_modifier = 0 }
end

function M.trade_skill.close()
  M._trade_skill_window_open = false
end

function M.trade_skill.get_trade_skill_num_made(idx)
  return { min_made = 1, max_made = 1 }
end

function M.trade_skill.get_trade_skill_cooldown(idx)
  local r = M._trade_skill_recipes[idx]
  if not r then return 0 end
  return r.cooldown or 0
end

function M.trade_skill.select_trade_skill(idx) end
function M.trade_skill.get_trade_skill_selection_index() return 0 end
function M.trade_skill.get_tradeskill_repeat_count() return 0 end
function M.trade_skill.get_first_trade_skill() return 1 end
function M.trade_skill.get_num_primary_professions() return 2 end
function M.trade_skill.get_trade_skill_recipe_link(idx) return nil end
function M.trade_skill.get_trade_skill_item_link(idx) return nil end
function M.trade_skill.get_trade_skill_icon(idx) return nil end
function M.trade_skill.get_trade_skill_tools(idx) return {} end
function M.trade_skill.get_trade_skill_item_stats(idx) return {} end
function M.trade_skill.get_trade_skill_reagent_item_link(idx, ri) return nil end
function M.trade_skill.craft_recipe(spell_id, num_casts, apply_conc) end
function M.trade_skill.close_trade_skill() M._trade_skill_window_open = false end
function M.trade_skill.open_trade_skill(skill_line_id) return false end
function M.trade_skill.open_recipe(recipe_id) end
function M.trade_skill.get_recipe_info(spell_id, level) return nil end
function M.trade_skill.get_all_recipe_ids() return {} end
function M.trade_skill.get_craftable_count(spell_id, level) return 0 end
function M.trade_skill.get_recipe_cooldown(spell_id) return 0 end

-- -----------------------------------------------------------------------------
-- core.craft — Enchanting Mock
-- -----------------------------------------------------------------------------
M.craft = {}

function M.craft.do_craft(idx)
  M._craft_do_calls[#M._craft_do_calls + 1] = idx
end

function M.craft.get_num_crafts()
  if not M._craft_window_open then return 0 end
  local count = 0
  for _ in pairs(M._craft_recipes) do count = count + 1 end
  return count
end

function M.craft.get_craft_info(idx)
  if not M._craft_window_open then return nil end
  local r = M._craft_recipes[idx]
  if not r then return nil end
  return {
    name           = r.name,
    sub_spell_name = "",
    type           = r.type or "optimal",
    num_available  = r.num_available or 0,
    is_expanded    = false,
    training_point_cost = 0,
    required_level = 0,
  }
end

function M.craft.get_craft_num_reagents(idx)
  local r = M._craft_recipes[idx]
  if not r or not r.reagents then return 0 end
  return #r.reagents
end

function M.craft.get_craft_reagent_info(idx, ri)
  local r = M._craft_recipes[idx]
  if not r or not r.reagents then return nil end
  local reg = r.reagents[ri]
  if not reg then return nil end
  return {
    name         = reg.name or "Reagent",
    texture      = "",
    count        = reg.count or 1,
    player_count = reg.player_count or 0,
  }
end

function M.craft.close() M._craft_window_open = false end
function M.craft.get_craft_item_link(idx) return nil end
function M.craft.get_craft_description(idx) return nil end
function M.craft.get_craft_name() return "Enchanting" end
function M.craft.get_craft_display_skill_line() return "Enchanting" end
function M.craft.get_craft_skill_line(idx) return nil end
function M.craft.get_craft_spell_focus(idx) return nil end
function M.craft.get_craft_selection_index() return 0 end
function M.craft.select_craft(idx) end
function M.craft.get_craft_reagent_item_link(idx, ri) return nil end
function M.craft.get_craft_icon(idx) return nil end

-- -----------------------------------------------------------------------------
-- core.skill — Skill Window Mock
-- -----------------------------------------------------------------------------
M.skill = {}
function M.skill.get_num_skill_lines() return 0 end
function M.skill.get_skill_line_info(idx) return nil end
function M.skill.get_selected_skill() return 0 end
function M.skill.set_selected_skill(idx) end
function M.skill.expand_skill_header(idx) end
function M.skill.collapse_skill_header(idx) end
function M.skill.is_trainer_service_learn_spell(idx) return false end

-- -----------------------------------------------------------------------------
-- core.input — CastSpellByName mock (for fallback open_profession)
-- -----------------------------------------------------------------------------
M.input = {}
function M.input.cast_spell_by_name(name)
  M._cast_spell_by_name_calls[#M._cast_spell_by_name_calls + 1] = name
  M._trade_skill_window_open = true
  return true
end

-- -----------------------------------------------------------------------------
-- core.time — Simple monotonic counter
-- -----------------------------------------------------------------------------
function M.time() return M._time end

-- -----------------------------------------------------------------------------
-- core.menu — Stub (not needed for crafting engine tests)
-- -----------------------------------------------------------------------------
M.menu = {}

-- -----------------------------------------------------------------------------
-- Install: Set the global `core` to this mock.
-- Call this at the top of each test file BEFORE requiring api_surface.
-- -----------------------------------------------------------------------------
function M.install()
  _G.core = M
end

return M

