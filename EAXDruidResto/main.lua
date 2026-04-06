-- EAX Druid Restoration | Project Sylvanas
-- Priority: Lifebloom -> Rejuvenation -> Regrowth -> Swiftmend

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")

-- Hot-path local caching
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player

-- Runtime state
local rt = {
    last_spell_refresh = 0,
    cached_mode = "solo",
    prev_toggle_state = false,
    -- Spell IDs
    rejuvenation_id = nil,
    regrowth_id = nil,
    lifebloom_id = nil,
    swiftmend_id = nil,
    healing_touch_id = nil,
    tranquility_id = nil,
    natures_swiftness_id = nil,
    innervate_id = nil,
    remove_curse_id = nil,
    abolish_poison_id = nil,
    tree_form_id = nil,
    -- State
    last_lifebloom_cast = 0,
}

local SPELL_REFRESH = 1.0
local MODE_REFRESH = 4.5
local LIFEBLOOM_REFRESH = 3.0

-- Helpers
local function get_me() return _get_local_player() end

local function resolve()
    local now = _core_time()
    if (now - rt.last_spell_refresh) < SPELL_REFRESH then return end
    rt.last_spell_refresh = now
    rt.rejuvenation_id = utils.resolve_spell_id(spells.REJUVENATION)
    rt.regrowth_id = utils.resolve_spell_id(spells.REGROWTH)
    rt.lifebloom_id = utils.resolve_spell_id(spells.LIFEBLOOM)
    rt.swiftmend_id = utils.resolve_spell_id(spells.SWIFTMEND)
    rt.healing_touch_id = utils.resolve_spell_id(spells.HEALING_TOUCH)
    rt.tranquility_id = utils.resolve_spell_id(spells.TRANQUILITY)
    rt.natures_swiftness_id = utils.resolve_spell_id(spells.NATURES_SWIFTNESS)
    rt.innervate_id = utils.resolve_spell_id(spells.INNERVATE)
    rt.remove_curse_id = utils.resolve_spell_id(spells.REMOVE_CURSE)
    rt.abolish_poison_id = utils.resolve_spell_id(spells.ABOLISH_POISON)
    rt.tree_form_id = utils.resolve_spell_id(spells.TREE_OF_LIFE_FORM)
end

local function mana_pct(me)
    return utils.mana_pct(me)
end

local function has_buff(unit, tbl)
    return utils.has_buff(unit, tbl)
end

local function get_lowest_hp_party_member()
    local me = get_me()
    if not me then return nil end
    local lowest = nil
    local lowest_hp = 1.0
    for _, o in ipairs(core.object_manager.get_all_objects()) do
        if o and o:is_valid() and o:is_unit() and not o:is_dead() then
            if o:is_party_member() or utils.same_unit(o, me) then
                local hp = utils.get_health_pct(o)
                if hp < lowest_hp then
                    lowest_hp = hp
                    lowest = o
                end
            end
        end
    end
    return lowest, lowest_hp
end

local function get_tank()
    for _, o in ipairs(core.object_manager.get_all_objects()) do
        if o and o:is_valid() and o:is_unit() and not o:is_dead() and o:is_party_member() then
            if o:is_tank() then return o end
        end
    end
    return nil
end

local function detect_mode()
    local n = 0
    for _, o in ipairs(core.object_manager.get_all_objects()) do
        if o and o:is_valid() and o:is_unit() and not o:is_dead() and o:is_party_member() then
            n = n + 1
        end
    end
    if n == 0 then return "solo" elseif n <= 4 then return "dungeon" end
    return "raid"
end

local function active_mode()
    local s = (menu.mode and menu.mode:get_value()) or 1
    if s == 2 then return "solo" elseif s == 3 then return "dungeon" elseif s == 4 then return "raid" end
    return rt.cached_mode
end

-- Healing functions
local function try_tree_form(me)
    if not rt.tree_form_id then return false end
    if has_buff(me, spells.BUFF_TREE_OF_LIFE_FORM) then return false end
    if not utils.can_cast_self(rt.tree_form_id, me) then return false end
    if utils.cast_self(rt.tree_form_id, me) then
        utils.log_debug(menu, "Tree of Life Form")
        return true
    end
    return false
end

local function try_lifebloom(me, target)
    if not menu.use_lifebloom or not menu.use_lifebloom:is_checked() then return false end
    if not rt.lifebloom_id then return false end
    if has_buff(target, spells.BUFF_LIFEBLOOM) then return false end
    if not utils.can_cast_target(rt.lifebloom_id, me, target) then return false end
    if utils.cast_target(rt.lifebloom_id, me, target) then
        utils.log_debug(menu, "Lifebloom")
        return true
    end
    return false
end

local function try_rejuvenation(me, target)
    if not menu.use_rejuvenation or not menu.use_rejuvenation:is_checked() then return false end
    if not rt.rejuvenation_id then return false end
    if has_buff(target, spells.BUFF_REJUVENATION) then return false end
    if not utils.can_cast_target(rt.rejuvenation_id, me, target) then return false end
    if utils.cast_target(rt.rejuvenation_id, me, target) then
        utils.log_debug(menu, "Rejuvenation")
        return true
    end
    return false
end

local function try_regrowth(me, target)
    if not menu.use_regrowth or not menu.use_regrowth:is_checked() then return false end
    if not rt.regrowth_id then return false end
    if has_buff(target, spells.BUFF_REGROWTH) then return false end
    if not utils.can_cast_target(rt.regrowth_id, me, target) then return false end
    if utils.cast_target(rt.regrowth_id, me, target) then
        utils.log_debug(menu, "Regrowth")
        return true
    end
    return false
end

local function try_swiftmend(me, target)
    if not menu.use_swiftmend or not menu.use_swiftmend:is_checked() then return false end
    if not rt.swiftmend_id then return false end
    if not (has_buff(target, spells.BUFF_REJUVENATION) or has_buff(target, spells.BUFF_REGROWTH)) then return false end
    local threshold = ((menu.swiftmend_hp and menu.swiftmend_hp:get_value()) or 40) / 100
    if utils.get_health_pct(target) > threshold then return false end
    if not utils.can_cast_target(rt.swiftmend_id, me, target) then return false end
    if utils.cast_target(rt.swiftmend_id, me, target) then
        utils.log_debug(menu, "Swiftmend")
        return true
    end
    return false
end

local function try_natures_swiftness_heal(me, target)
    if not menu.use_natures_swiftness or not menu.use_natures_swiftness:is_checked() then return false end
    if not rt.natures_swiftness_id then return false end
    local threshold = ((menu.emergency_hp and menu.emergency_hp:get_value()) or 30) / 100
    if utils.get_health_pct(target) > threshold then return false end
    if not utils.can_cast_self(rt.natures_swiftness_id, me) then return false end
    if utils.cast_self(rt.natures_swiftness_id, me) then
        utils.log_debug(menu, "Nature's Swiftness")
        return true
    end
    return false
end

local function try_innervate(me)
    if not menu.use_innervate or not menu.use_innervate:is_checked() then return false end
    if not rt.innervate_id then return false end
    local threshold = ((menu.innervate_mana and menu.innervate_mana:get_value()) or 20) / 100
    if mana_pct(me) > threshold then return false end
    if not utils.can_cast_self(rt.innervate_id, me) then return false end
    if utils.cast_self(rt.innervate_id, me) then
        utils.log_debug(menu, "Innervate")
        return true
    end
    return false
end

local function try_remove_curse(me, target)
    if not menu.auto_dispel_curse or not menu.auto_dispel_curse:is_checked() then return false end
    if not rt.remove_curse_id then return false end
    if not utils.can_cast_target(rt.remove_curse_id, me, target) then return false end
    if utils.cast_target(rt.remove_curse_id, me, target) then
        utils.log_debug(menu, "Remove Curse")
        return true
    end
    return false
end

local function try_abolish_poison(me, target)
    if not menu.auto_dispel_poison or not menu.auto_dispel_poison:is_checked() then return false end
    if not rt.abolish_poison_id then return false end
    if has_buff(target, spells.BUFF_ABOLISH_POISON) then return false end
    if not utils.can_cast_target(rt.abolish_poison_id, me, target) then return false end
    if utils.cast_target(rt.abolish_poison_id, me, target) then
        utils.log_debug(menu, "Abolish Poison")
        return true
    end
    return false
end

-- Main rotation
local function do_rotation(me)
    -- Ensure in tree form
    if not has_buff(me, spells.BUFF_TREE_OF_LIFE_FORM) then
        if try_tree_form(me) then return end
    end

    -- Cooldowns
    if try_innervate(me) then return end

    -- Get healing targets
    local tank = get_tank()
    local lowest, lowest_hp = get_lowest_hp_party_member()

    -- Emergency healing
    if lowest and lowest_hp < 0.3 then
        if try_natures_swiftness_heal(me, lowest) then return end
        if try_swiftmend(me, lowest) then return end
    end

    -- Tank healing priority
    local prioritize_tank = menu.prioritize_tank and menu.prioritize_tank:is_checked()
    if tank and prioritize_tank then
        if try_swiftmend(me, tank) then return end
        if try_lifebloom(me, tank) then return end
        if try_rejuvenation(me, tank) then return end
        if try_regrowth(me, tank) then return end
    end

    -- Raid healing
    if lowest and lowest_hp < 0.8 then
        if try_swiftmend(me, lowest) then return end
        if try_rejuvenation(me, lowest) then return end
        if try_regrowth(me, lowest) then return end
    end

    -- Dispel
    if lowest then
        if try_remove_curse(me, lowest) then return end
        if try_abolish_poison(me, lowest) then return end
    end
end

-- Update loop
local function on_update()
    resolve()
    local me = get_me()
    if utils.throttle("restomode", MODE_REFRESH) then
        rt.cached_mode = detect_mode()
    end
    if not menu or not menu.is_enabled() then return end
    if not me or me:is_dead() then return end

    do_rotation(me)
end

core.register_on_update_callback(on_update)

-- Export toggle settings for external access
local NS = _G.EAXDruidResto and _G.EAXDruidResto.NS or {}
_G.EAXDruidResto = _G.EAXDruidResto or {}
_G.EAXDruidResto.NS = NS
NS.toggle_menu = menu.toggle_menu

return {}
