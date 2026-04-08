-- mana_conservator.lua
-- Mana conservation system for all Eax caster/healer specs (1-70 leveling safe).
-- When mana drops below a threshold, switches to wanding or melee attacks
-- instead of casting expensive spells, preserving mana for burst situations.
--
-- Wire into any caster spec's on_update BEFORE the main rotation logic:
--
--   local mana_conservator = require("libraries/mana_conservator")
--   -- Returns true if we are in mana-conserve mode (caller should skip normal rotation)
--   if mana_conservator.on_update(me, target, menu, utils) then return end
--
-- The module auto-detects whether the player has a wand equipped.
-- Falls back to melee auto-attack for specs without wands.
--
-- v1.0.0

local mana_conservator = {}

-- --- Constants ----------------------------------------------------------------

-- Spell ID 5019 = "Shoot" (wand ranged auto attack)
local WAND_SPELL_ID    = 5019
-- Spell ID 6603 = "Attack" (melee auto attack start)
local MELEE_SPELL_ID   = 6603

-- Inventory slot for ranged weapon (wand slot in TBC = slot 18)
local RANGED_SLOT      = 18
local POWER_TYPE_MANA  = 0

-- --- Internal state -----------------------------------------------------------

local last_wand_toggle_time  = 0
local last_melee_start_time  = 0
local WAND_TOGGLE_THROTTLE   = 0.5   -- seconds between wand start/stop attempts
local MELEE_START_THROTTLE   = 1.0   -- seconds between melee start attempts
local conserve_mode_active   = false
local last_mana_pct          = nil
local _eax_utils             = nil

-- --- Helpers ------------------------------------------------------------------

local function is_leveling_character(me)
    if not me or not me.is_valid or not me:is_valid() or not me.get_level then return false end
    local lvl = me:get_level() or 0
    return lvl > 0 and lvl < 70
end

local function get_mana_pct(me)
    local max_mana = me:get_max_power(POWER_TYPE_MANA)
    if max_mana <= 0 then return 100 end
    return (me:get_power(POWER_TYPE_MANA) / max_mana) * 100
end

local function has_wand_equipped(me)
    -- Check if a wand is in the ranged slot (slot 18)
    local ok, slot_info = pcall(function()
        return me:get_item_at_inventory_slot(RANGED_SLOT)
    end)
    if not ok or not slot_info or not slot_info.object then return false end
    local item = slot_info.object
    if not item or (item.is_valid and not item:is_valid()) then return false end
    -- Item exists in ranged slot; check if Shoot is usable (wand is equipped)
    local can_shoot = pcall(function()
        return core.spell_book.is_spell_learned(WAND_SPELL_ID)
    end)
    return can_shoot and core.spell_book.is_spell_learned(WAND_SPELL_ID)
end

local function is_wanding(me)
    -- Check if we are currently auto-attacking with wand (ranged)
    local ok, result = pcall(function()
        return me:is_auto_attacking()
    end)
    if not ok then return false end
    -- is_auto_attacking() returns true for any auto-attack; we also
    -- check if the current spell being channeled is Shoot (5019)
    return result == true
end

local function is_actively_regenerating(me)
    local mana_pct = get_mana_pct(me)
    local was_regenerating = last_mana_pct ~= nil and mana_pct > (last_mana_pct + 0.1)
    last_mana_pct = mana_pct
    return was_regenerating
end

local function is_eating_or_drinking(me)
    if _eax_utils == nil then
        local ok, mod = pcall(require, "libraries/eax_utils")
        _eax_utils = ok and mod or false
    end

    if _eax_utils and _eax_utils.is_eating_or_drinking then
        return _eax_utils.is_eating_or_drinking(me)
    end

    return false
end

local function start_wand(me, target)
    if not target or not target:is_valid() or target:is_dead() then return false end
    local now = core.time()
    if (now - last_wand_toggle_time) < WAND_TOGGLE_THROTTLE then return false end
    last_wand_toggle_time = now

    -- Use spell_queue to cast Shoot on target
    local ok, spell_queue = pcall(require, "common/modules/spell_queue")
    if ok and spell_queue then
        spell_queue:queue_spell_target(WAND_SPELL_ID, target, 1, "Wand")
        return true
    end
    -- Fallback: direct cast via input
    local cast_ok = pcall(function()
        core.input.cast_spell(WAND_SPELL_ID, target)
    end)
    return cast_ok
end

local function start_melee(me, target)
    if not target or not target:is_valid() or target:is_dead() then return false end
    if me:is_auto_attacking() then return false end
    local now = core.time()
    if (now - last_melee_start_time) < MELEE_START_THROTTLE then return false end
    last_melee_start_time = now

    -- Queue melee attack (Attack spell = 6603)
    local ok, spell_queue = pcall(require, "common/modules/spell_queue")
    if ok and spell_queue then
        spell_queue:queue_spell_target(MELEE_SPELL_ID, target, 1, "Melee Attack")
        return true
    end
    local cast_ok = pcall(function()
        core.input.cast_spell(MELEE_SPELL_ID, target)
    end)
    return cast_ok
end

-- --- Menu helpers -------------------------------------------------------------

local function get_conserve_threshold(menu)
    -- Default: conserve below 20% mana
    if menu and menu.mana_conserve_threshold then
        if type(menu.mana_conserve_threshold.get) == "function" then
            return menu.mana_conserve_threshold:get()
        end
    end
    return 20
end

local function get_conserve_stop_threshold(menu)
    -- Stop conserving once mana is back above this level
    if menu and menu.mana_conserve_stop_threshold then
        if type(menu.mana_conserve_stop_threshold.get) == "function" then
            return menu.mana_conserve_stop_threshold:get()
        end
    end
    return 35
end

local function is_conserve_enabled(menu)
    if menu and menu.mana_conserve_enabled then
        if type(menu.mana_conserve_enabled.get_state) == "function" then
            return menu.mana_conserve_enabled:get_state()
        end
    end
    return true  -- default enabled
end

-- --- Public API ---------------------------------------------------------------

---Returns true if the rotation should be suppressed while mana is actively recovering.
---Does not block rotation in combat or merely because mana is below a threshold.
---@param me game_object
---@param target game_object|nil
---@param menu table
---@param utils table
---@return boolean  suppress_rotation
function mana_conservator.on_update(me, target, menu, utils)
    if not me or not me:is_valid() or me:is_dead() then
        last_mana_pct = nil
        return false
    end
    if me:is_in_combat() then
        conserve_mode_active = false
        last_mana_pct = nil
        return false
    end
    if not is_leveling_character(me) then
        conserve_mode_active = false
        last_mana_pct = get_mana_pct(me)
        return false
    end
    if not is_conserve_enabled(menu) then
        conserve_mode_active = false
        last_mana_pct = get_mana_pct(me)
        return false
    end

    local mana_pct   = get_mana_pct(me)
    local threshold  = get_conserve_threshold(menu)
    local stop_thresh = get_conserve_stop_threshold(menu)

    -- Enter conserve mode below threshold
    if mana_pct <= threshold then
        conserve_mode_active = true
    end
    -- Exit conserve mode once mana recovers above stop threshold
    if conserve_mode_active and mana_pct >= stop_thresh then
        conserve_mode_active = false
    end

    if not conserve_mode_active then return false end

    -- Only suppress rotation while we are actively recovering mana, not merely
    -- because the threshold has been crossed.
    if is_eating_or_drinking(me) then return true end
    if is_actively_regenerating(me) then return true end

    return false
end

---Returns true if we are currently in mana-conserve mode (useful for UI display).
function mana_conservator.is_active()
    return conserve_mode_active
end

---Force-reset the conserve state (e.g. when leaving combat).
function mana_conservator.reset()
    conserve_mode_active = false
    last_mana_pct = nil
end

-- --- Menu element factory -----------------------------------------------------
-- Call this from a spec's menu.lua to register the required sliders/checkboxes.
-- prefix: unique string for savedvariables keys, e.g. "eax_mage_frost"
--
--   mana_conservator.register_menu_items(menu, "eax_mage_frost")
--
function mana_conservator.register_menu_items(menu_tbl, prefix)
    if not menu_tbl or not prefix then return end
    menu_tbl.mana_conserve_enabled = core.menu.checkbox(
        true, prefix .. "_mc_enabled")
    menu_tbl.mana_conserve_threshold = core.menu.slider_int(
        5, 50, 20, prefix .. "_mc_threshold")
    menu_tbl.mana_conserve_stop_threshold = core.menu.slider_int(
        10, 80, 35, prefix .. "_mc_stop")
end

---Render the mana conservator menu items inside an existing tree node.
---Call this from within a render callback.
function mana_conservator.render_menu_items(menu_tbl)
    if not menu_tbl then return end
    if menu_tbl.mana_conserve_enabled then
        menu_tbl.mana_conserve_enabled:render(
            "Mana Conservator",
            "Wand or melee when mana is low to avoid going OOM while leveling")
    end
    if menu_tbl.mana_conserve_threshold then
        menu_tbl.mana_conserve_threshold:render(
            "Conserve Below %",
            "Enter wand/melee mode when mana drops below this percentage")
    end
    if menu_tbl.mana_conserve_stop_threshold then
        menu_tbl.mana_conserve_stop_threshold:render(
            "Resume Casting At %",
            "Return to normal rotation once mana recovers to this percentage")
    end
end

return mana_conservator
