---@type buff_manager
local buff_manager = require("common/modules/buff_manager")
-- leveling_manager.lua
-- Wanding, melee fallback, and mana conservation for leveling 1-70.
-- Uses only documented Sylvanas API: auto_attack_helper, core.spell_book, game_object methods.
--
-- Usage in do_rotation (caster specs):
--   if leveling_manager.try_wand(me, target, menu) then return true end
--   if not leveling_manager.has_enough_mana(me, menu) then
--       leveling_manager.ensure_melee(me, target)
--       return false
--   end
--
-- Usage in do_rotation (melee specs with mana):
--   if leveling_manager.is_conserving_mana(me, menu) then
--       leveling_manager.ensure_melee(me, target)
--   end
--
-- v1.7.0

local leveling_manager = {}

-- --- Constants ----------------------------------------------------------------

local WAND_SPELL_ID  = 5019   -- "Shoot" wand ranged auto-attack
local MELEE_TYPE     = 6603   -- auto_attack_helper.ATTACK_TYPE.MELEE
local RANGED_TYPE    = 75     -- auto_attack_helper.ATTACK_TYPE.RANGED (Hunter)
local RANGED_SLOT    = 18     -- inventory slot for wand/ranged weapon
local WAND_THROTTLE  = 2.0    -- seconds between wand start attempts

-- Spirit Tap buff ID (Shadow Priest talent)
local SPIRIT_TAP_BUFF = 15271

-- --- Lazy-loaded dependencies -------------------------------------------------

local _aa
local function get_aa()
    if not _aa then
        local ok, aa = pcall(require, "common/utility/auto_attack_helper")
        if ok and aa then _aa = aa end
    end
    return _aa
end

-- --- Internal state -----------------------------------------------------------

local last_wand_time = 0

-- --- Mana utilities -----------------------------------------------------------

function leveling_manager.get_mana_pct(me)
    if not me or not me:is_valid() then return 1.0 end
    local ok, pct = pcall(function()
        -- power type 0 = mana in TBC
        local max_m = me:get_max_power(0)
        if max_m <= 0 then return 1.0 end
        return me:get_power(0) / max_m
    end)
    return (ok and type(pct) == "number") and math.max(0, math.min(1, pct)) or 1.0
end

-- Returns true if mana is above the casting floor (rotation can proceed normally)
function leveling_manager.has_enough_mana(me, menu)
    local floor = 0.20
    if menu and menu.leveling_mana_floor then
        local ok, v = pcall(function() return menu.leveling_mana_floor:get() end)
        if ok and type(v) == "number" then floor = v / 100.0 end
    end
    return leveling_manager.get_mana_pct(me) >= floor
end

-- Returns true when mana is below conservation threshold (skip expensive spells)
function leveling_manager.is_conserving_mana(me, menu)
    if not menu or not menu.leveling_conserve_mana then return false end
    local ok, enabled = pcall(function() return menu.leveling_conserve_mana:get_state() end)
    if not (ok and enabled) then return false end
    return leveling_manager.get_mana_pct(me) < 0.40
end

-- --- Wand detection -----------------------------------------------------------

local function has_wand_equipped()
    -- The "Shoot" spell (5019) is only in spellbook when a wand is equipped
    local ok, learned = pcall(function()
        return core.spell_book.is_spell_learned(WAND_SPELL_ID)
    end)
    return ok and learned == true
end

local function is_wanding()
    -- is_current_spell returns true when Shoot is auto-repeating
    local ok, cur = pcall(function()
        return core.spell_book.is_current_spell(WAND_SPELL_ID)
    end)
    return ok and cur == true
end

-- --- Wand logic ---------------------------------------------------------------

local function should_wand(me, target, menu)
    if not menu or not menu.use_wand then return false end
    local ok, enabled = pcall(function() return menu.use_wand:get_state() end)
    if not (ok and enabled) then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    if me:is_moving() then return false end
    if not has_wand_equipped() then return false end

    local mana_pct = leveling_manager.get_mana_pct(me)
    local wand_floor = 0.25
    if menu.wand_mana_floor then
        local ok2, v = pcall(function() return menu.wand_mana_floor:get() end)
        if ok2 and type(v) == "number" then wand_floor = v / 100.0 end
    end
    if mana_pct <= wand_floor then return true end

    -- Wand-finish low HP targets to save mana
    local wand_hp = 0.20
    if menu.wand_at_hp then
        local ok2, v = pcall(function() return menu.wand_at_hp:get() end)
        if ok2 and type(v) == "number" then wand_hp = v / 100.0 end
    end
    local t_hp = (target.get_health_percentage) and (target:get_health_percentage() / 100) or 1.0
    if t_hp <= wand_hp then return true end

    return false
end

-- Start wanding; returns true if wanding is active or was started
function leveling_manager.try_wand(me, target, menu)
    if not should_wand(me, target, menu) then return false end
    if is_wanding() then return true end  -- already firing, don't interrupt

    local now = core.time()
    if (now - last_wand_time) < WAND_THROTTLE then return false end
    last_wand_time = now

    local aa = get_aa()
    if aa and aa.start_attack then
        local ok, r = pcall(function() return aa:start_attack(target, aa.ATTACK_TYPE.WAND) end)
        if ok and r then return true end
    end
    -- Fallback: direct spell queue
    local ok2, sq = pcall(require, "common/modules/spell_queue")
    if ok2 and sq then
        pcall(function() sq:queue_spell_target(WAND_SPELL_ID, target, 1, "Wand") end)
        return true
    end
    return false
end

-- Stop wanding (called before casting a spell to break auto-repeat)
function leveling_manager.stop_wanding()
    if not is_wanding() then return end
    local aa = get_aa()
    if aa and aa.stop_attack then
        pcall(function() aa:stop_attack(nil, aa.ATTACK_TYPE.WAND) end)
    end
end

-- --- Melee / Ranged fallback --------------------------------------------------

function leveling_manager.ensure_melee(me, target)
    if not me or not target or not target:is_valid() or target:is_dead() then return end
    if not me:can_attack(target) then return end
    local aa = get_aa()
    if aa and aa.start_attack then
        pcall(function() aa:start_attack(target, aa.ATTACK_TYPE.MELEE) end)
    end
end

function leveling_manager.ensure_ranged(me, target)
    if not me or not target or not target:is_valid() or target:is_dead() then return end
    if not me:can_attack(target) or me:is_moving() then return end
    local aa = get_aa()
    if aa and aa.start_attack then
        pcall(function() aa:start_attack(target, aa.ATTACK_TYPE.RANGED) end)
    end
end

-- --- Spirit Tap (Priest Shadow) -----------------------------------------------
-- Wand-finish targets below 25% to proc Spirit Tap mana regen on kill.

function leveling_manager.should_wand_for_spirit_tap(me, target, menu)
    if not menu or not menu.use_spirit_tap_wand then return false end
    local ok, enabled = pcall(function() return menu.use_spirit_tap_wand:get_state() end)
    if not (ok and enabled) then return false end
    -- Don't bother if Spirit Tap buff is already up
    local ok2, data = pcall(function() return buff_manager:get_buff_data(me, SPIRIT_TAP_BUFF) end)
    if ok2 and data and data.is_active then return false end
    if not target or target:is_dead() then return false end
    local hp = (target.get_health_percentage) and (target:get_health_percentage() / 100) or 1.0
    return hp <= 0.25
end

-- --- Menu item factory --------------------------------------------------------

function leveling_manager.register_menu_items(menu_tbl, prefix)
    if not menu_tbl or not prefix then return end
    menu_tbl.use_wand               = core.menu.checkbox(true,  prefix .. "_use_wand")
    menu_tbl.wand_mana_floor        = core.menu.slider_int(5, 80, 25, prefix .. "_wand_mana_floor")
    menu_tbl.wand_at_hp             = core.menu.slider_int(5, 60, 20, prefix .. "_wand_at_hp")
    menu_tbl.leveling_mana_floor    = core.menu.slider_int(5, 50, 20, prefix .. "_lev_mana_floor")
    menu_tbl.leveling_conserve_mana = core.menu.checkbox(true,  prefix .. "_lev_conserve")
    menu_tbl.use_spirit_tap_wand    = core.menu.checkbox(true,  prefix .. "_spirit_tap_wand")
end

function leveling_manager.render_menu_items(menu_tbl)
    if not menu_tbl then return end
    if menu_tbl.use_wand              then menu_tbl.use_wand:render("Wand (Leveling)", "Auto-wand when low mana or target is low HP") end
    if menu_tbl.wand_mana_floor       then menu_tbl.wand_mana_floor:render("Wand Below Mana %", "Start wanding when mana drops below this") end
    if menu_tbl.wand_at_hp            then menu_tbl.wand_at_hp:render("Wand-Finish HP %", "Wand targets below this HP to save mana") end
    if menu_tbl.leveling_mana_floor   then menu_tbl.leveling_mana_floor:render("Stop Casting At %", "Block normal rotation below this mana") end
    if menu_tbl.leveling_conserve_mana then menu_tbl.leveling_conserve_mana:render("Mana Conservation", "Skip expensive spells when mana is low") end
    if menu_tbl.use_spirit_tap_wand   then menu_tbl.use_spirit_tap_wand:render("Spirit Tap Wand (Priest)", "Wand-finish for Spirit Tap mana regen") end
end

return leveling_manager
