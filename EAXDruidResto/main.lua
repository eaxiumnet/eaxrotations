-- EAX Druid Restoration | Project Sylvanas
-- Priority: Lifebloom -> Rejuvenation -> Regrowth -> Swiftmend

-- Load header first to check if we should load at all
local header = require("header")
if not header.load then
    return
end

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")
local middleware_manager = require("libraries/middleware_manager")
local dashboard = require("libraries/dashboard")
local ooc_manager = require("libraries/ooc_manager")
local hot_manager = require("libraries/hot_manager")
local mana_manager = require("libraries/mana_manager")
local form_consumables = require("libraries/form_consumables")

-- Hot-path local caching
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown

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
    barkskin_id = nil,
    -- PvP Spell IDs
    entangling_roots_id = nil,
    hibernate_id = nil,
    cyclone_id = nil,
    -- Form Spell IDs (for form_consumables)
    cat_form_id = nil,
    bear_form_id = nil,
    moonkin_form_id = nil,
    tree_form_id = nil,
    -- State
    last_lifebloom_cast = 0,
    -- Middleware and PvP state
    middleware_initialized = false,
    pvp_context = nil,
    last_pvp_check = 0,
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
    -- Healing Touch: use rank-based selection from menu
    local ht_rank = (menu.healing_touch_rank and menu.healing_touch_rank:get()) or 12
    rt.healing_touch_id = spells.HEALING_TOUCH_RANKS[ht_rank]
    rt.tranquility_id = utils.resolve_spell_id(spells.TRANQUILITY)
    rt.natures_swiftness_id = utils.resolve_spell_id(spells.NATURES_SWIFTNESS)
    rt.innervate_id = utils.resolve_spell_id(spells.INNERVATE)
    rt.remove_curse_id = utils.resolve_spell_id(spells.REMOVE_CURSE)
    rt.abolish_poison_id = utils.resolve_spell_id(spells.ABOLISH_POISON)
    rt.tree_form_id = utils.resolve_spell_id(spells.TREE_OF_LIFE_FORM)
    rt.barkskin_id = utils.resolve_spell_id(spells.BARKSKIN)
    rt.rebirth_id = utils.resolve_spell_id(spells.REBIRTH)
    rt.mark_of_the_wild_id = utils.resolve_spell_id(spells.MARK_OF_THE_WILD)
    rt.thorns_id = utils.resolve_spell_id(spells.THORNS)
    -- PvP spells
    rt.entangling_roots_id = utils.resolve_spell_id(spells.ENTANGLING_ROOTS)
    rt.hibernate_id = utils.resolve_spell_id(spells.HIBERNATE)
    rt.cyclone_id = utils.resolve_spell_id(spells.CYCLONE)
    -- Form spells (for form_consumables)
    rt.cat_form_id = utils.resolve_spell_id(spells.CAT_FORM)
    rt.bear_form_id = utils.resolve_spell_id(spells.BEAR_FORM)
    rt.moonkin_form_id = utils.resolve_spell_id(spells.MOONKIN_FORM)
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
    if not me then return nil, 1.0 end
    
    -- Use heal_utils for effective ally finding (considers incoming heals/damage)
    local lowest = utils.find_lowest_effective_ally(me, 100, false)
    if lowest then
        local hp = utils.get_health_pct(lowest)
        return lowest, hp
    end
    
    return nil, 1.0
end

local function get_tank()
    local me = get_me()
    if not me then return nil end
    return utils.get_tank_unit(me)
end

local function detect_mode()
    local n = 0
    local ok_objects, all_objects = pcall(function() return core.object_manager.get_all_objects() end)
    if not ok_objects then all_objects = {} end
    for _, o in ipairs(all_objects) do
        if o and o:is_valid() and o:is_unit() and not o:is_dead() and o:is_party_member() then
            n = n + 1
        end
    end
    if n == 0 then return "solo" elseif n <= 4 then return "dungeon" end
    return "raid"
end

local function active_mode()
    local s = (menu.mode and menu.mode:get()) or 1
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
    if not menu.use_lifebloom or not menu.use_lifebloom:get_state() then return false end
    if not rt.lifebloom_id then return false end
    
    -- Use hot_manager for Lifebloom 3-stack management
    local stacks = hot_manager.get_lifebloom_stacks(target)
    local needs_refresh = hot_manager.is_lifebloom_refresh_needed(target, 3)
    
    -- Check if we should allow bloom for mana return
    local allow_bloom_enabled = (menu.lifebloom_allow_bloom and menu.lifebloom_allow_bloom:get_state()) or false
    if allow_bloom_enabled and hot_manager.should_allow_bloom(target, me) then
        utils.log_debug(menu, "Lifebloom: Allowing bloom for mana return")
        return false
    end
    
    -- Only cast if we need to build stacks or refresh
    if stacks >= 3 and not needs_refresh then return false end
    
    if not utils.can_cast_target(rt.lifebloom_id, me, target) then return false end
    if utils.cast_target(rt.lifebloom_id, me, target) then
        utils.log_debug(menu, "Lifebloom (stack " .. tostring(stacks + 1) .. "/3)")
        return true
    end
    return false
end

local function try_rejuvenation(me, target)
    if not menu.use_rejuvenation or not menu.use_rejuvenation:get_state() then return false end
    if not rt.rejuvenation_id then return false end
    
    -- Use hot_manager to check for existing Rejuvenation (blanketing)
    if hot_manager.has_hot(target, spells.REJUVENATION) then return false end
    
    if not utils.can_cast_target(rt.rejuvenation_id, me, target) then return false end
    if utils.cast_target(rt.rejuvenation_id, me, target) then
        utils.log_debug(menu, "Rejuvenation")
        return true
    end
    return false
end

local function try_regrowth(me, target)
    if not menu.use_regrowth or not menu.use_regrowth:get_state() then return false end
    if not rt.regrowth_id then return false end
    
    -- Use hot_manager to check for existing Regrowth (blanketing)
    if hot_manager.has_hot(target, spells.REGROWTH) then return false end
    
    if not utils.can_cast_target(rt.regrowth_id, me, target) then return false end
    if utils.cast_target(rt.regrowth_id, me, target) then
        utils.log_debug(menu, "Regrowth")
        return true
    end
    return false
end

local function try_swiftmend(me, target)
    if not menu.use_swiftmend or not menu.use_swiftmend:get_state() then return false end
    if not rt.swiftmend_id then return false end
    
    -- Use hot_manager to check if target has a consumable HoT (Rejuvenation or Regrowth)
    local has_rejuv = hot_manager.has_hot(target, spells.REJUVENATION)
    local has_regrowth = hot_manager.has_hot(target, spells.REGROWTH)
    if not has_rejuv and not has_regrowth then return false end
    
    local threshold = ((menu.swiftmend_hp_pct and menu.swiftmend_hp_pct:get()) or 40) / 100
    if utils.get_health_pct(target) > threshold then return false end
    if not utils.can_cast_target(rt.swiftmend_id, me, target) then return false end
    if utils.cast_target(rt.swiftmend_id, me, target) then
        utils.log_debug(menu, "Swiftmend")
        return true
    end
    return false
end

local function try_natures_swiftness_heal(me, target)
    if not menu.use_natures_swiftness or not menu.use_natures_swiftness:get_state() then return false end
    if not rt.natures_swiftness_id then return false end
    local threshold = ((menu.emergency_hp and menu.emergency_hp:get()) or 30) / 100
    if utils.get_health_pct(target) > threshold then return false end
    if not utils.can_cast_self(rt.natures_swiftness_id, me) then return false end
    if utils.cast_self(rt.natures_swiftness_id, me) then
        utils.log_debug(menu, "Nature's Swiftness")
        return true
    end
    return false
end

local function try_healing_touch(me, target)
    if not menu.use_healing_touch or not menu.use_healing_touch:get_state() then return false end
    if not rt.healing_touch_id then return false end
    
    -- Get threshold from menu (default 40%)
    local threshold = ((menu.healing_touch_tank_threshold and menu.healing_touch_tank_threshold:get()) or 40) / 100
    if utils.get_health_pct(target) > threshold then return false end
    
    -- Prioritize tanks - only cast if target is a tank
    if not utils.is_unit_tank(target) then return false end
    
    if not utils.can_cast_target(rt.healing_touch_id, me, target) then return false end
    if utils.cast_target(rt.healing_touch_id, me, target) then
        utils.log_debug(menu, "Healing Touch")
        return true
    end
    return false
end

-- Clearcasting exploitation: Free Healing Touch when Omen of Clarity procs
local function try_healing_touch_clearcasting(me, target)
    -- Only cast when Clearcasting is active (Omen of Clarity buff)
    if not utils.has_clearcasting(me) then return false end
    -- Check if Healing Touch is enabled in menu
    if not menu.use_healing_touch or not menu.use_healing_touch:get_state() then return false end
    if not rt.healing_touch_id then return false end
    -- Target must be injured
    if utils.get_health_pct(target) >= 1.0 then return false end
    -- Cast the highest rank Healing Touch for free
    if not utils.can_cast_target(rt.healing_touch_id, me, target) then return false end
    if utils.cast_target(rt.healing_touch_id, me, target) then
        utils.log_debug(menu, "Healing Touch (Clearcasting - FREE!)")
        return true
    end
    return false
end

-- Clearcasting exploitation: Free Regrowth when HT not available/priority
local function try_regrowth_clearcasting(me, target)
    -- Only cast when Clearcasting is active
    if not utils.has_clearcasting(me) then return false end
    -- Only use if we didn't already consume Clearcasting with HT
    if not rt.regrowth_id then return false end
    -- Target must be injured
    if utils.get_health_pct(target) >= 1.0 then return false end
    -- Don't cast if target already has Regrowth (blanketing)
    if hot_manager.has_hot(target, spells.REGROWTH) then return false end
    -- Cast Regrowth for free
    if not utils.can_cast_target(rt.regrowth_id, me, target) then return false end
    if utils.cast_target(rt.regrowth_id, me, target) then
        utils.log_debug(menu, "Regrowth (Clearcasting - FREE!)")
        return true
    end
    return false
end

local function try_rebirth(me)
    -- Battle resurrection: ONLY cast in combat
    if not me:is_in_combat() then return false end
    
    -- Check menu toggle (nil-guarded)
    local use_rebirth = (menu.use_rebirth and menu.use_rebirth:get_state()) or false
    if not use_rebirth then return false end
    
    -- Check if spell is available
    if not rt.rebirth_id then return false end
    
    -- Find a dead ally to resurrect
    local dead_ally = utils.find_dead_ally(me)
    if not dead_ally then return false end
    
    -- Check if we can cast on the target
    if not utils.can_cast_target(rt.rebirth_id, me, dead_ally) then return false end
    
    -- Cast Rebirth
    if utils.cast_target(rt.rebirth_id, me, dead_ally) then
        utils.log_debug(menu, "Rebirth (Battle Resurrection)")
        return true
    end
    return false
end

local function try_innervate(me)
    if not menu.use_innervate or not menu.use_innervate:get_state() then return false end
    if not rt.innervate_id then return false end
    local threshold = ((menu.innervate_mana_pct and menu.innervate_mana_pct:get()) or 20) / 100
    if mana_pct(me) > threshold then return false end
    if not utils.can_cast_self(rt.innervate_id, me) then return false end
    if utils.cast_self(rt.innervate_id, me) then
        utils.log_debug(menu, "Innervate")
        return true
    end
    return false
end

local function try_tranquility(me)
    if not menu.use_tranquility or not menu.use_tranquility:get_state() then return false end
    if not rt.tranquility_id then return false end
    -- Check if already channeling Tranquility
    if has_buff(me, spells.BUFF_TRANQUILITY) then return false end
    -- Check mana threshold (Tranquility is expensive)
    if mana_pct(me) < 20 then return false end
    -- Count injured allies below 70% HP
    local injured_count = utils.count_below_hp(me, 70)
    if injured_count < 3 then return false end
    if not utils.can_cast_self(rt.tranquility_id, me) then return false end
    if utils.cast_self(rt.tranquility_id, me) then
        utils.log_debug(menu, "Tranquility (" .. tostring(injured_count) .. " injured allies)")
        return true
    end
    return false
end

local function try_remove_curse(me, target)
    if not menu.use_remove_curse or not menu.use_remove_curse:get_state() then return false end
    if not rt.remove_curse_id then return false end
    if not utils.can_cast_target(rt.remove_curse_id, me, target) then return false end
    if utils.cast_target(rt.remove_curse_id, me, target) then
        utils.log_debug(menu, "Remove Curse")
        return true
    end
    return false
end

local function try_abolish_poison(me, target)
    if not menu.use_abolish_poison or not menu.use_abolish_poison:get_state() then return false end
    if not rt.abolish_poison_id then return false end
    if has_buff(target, spells.BUFF_ABOLISH_POISON) then return false end
    if not utils.can_cast_target(rt.abolish_poison_id, me, target) then return false end
    if utils.cast_target(rt.abolish_poison_id, me, target) then
        utils.log_debug(menu, "Abolish Poison")
        return true
    end
    return false
end

-- PvP rotation functions
local function try_pvp_entangling_roots(me, t)
    if not rt.pvp_context or not rt.pvp_context.target_is_player then return false end
    if not (menu.pvp_entangling_roots and menu.pvp_entangling_roots:get()) then return false end
    if not rt.entangling_roots_id then return false end
    -- Check if target doesn't have roots already
    if utils.has_debuff(t, spells.DEBUFF_ENTANGLING_ROOTS) then return false end
    if not utils.can_cast_hostile(rt.entangling_roots_id, me, t) then return false end
    if utils.cast_target(rt.entangling_roots_id, me, t) then
        utils.log_debug(menu, "PvP: Entangling Roots")
        return true
    end
    return false
end

local function try_pvp_hibernate(me, t)
    if not rt.pvp_context or not rt.pvp_context.target_is_player then return false end
    if not (menu.pvp_hibernate and menu.pvp_hibernate:get()) then return false end
    if not rt.hibernate_id then return false end
    -- Check if target is beast or dragonkin
    local creature_type = nil
    if t.get_creature_type then
        local ok, ct = pcall(function() return t:get_creature_type() end)
        if ok then creature_type = ct end
    end
    if creature_type ~= "Beast" and creature_type ~= "Dragonkin" then return false end
    -- Check if target doesn't have hibernate already
    if utils.has_debuff(t, spells.DEBUFF_HIBERNATE) then return false end
    if not utils.can_cast_hostile(rt.hibernate_id, me, t) then return false end
    if utils.cast_target(rt.hibernate_id, me, t) then
        utils.log_debug(menu, "PvP: Hibernate")
        return true
    end
    return false
end

local function try_pvp_cyclone(me, t)
    if not rt.pvp_context or not rt.pvp_context.target_is_player then return false end
    if not (menu.pvp_cyclone and menu.pvp_cyclone:get()) then return false end
    if not rt.cyclone_id then return false end
    -- Check if target doesn't have cyclone already
    if utils.has_debuff(t, spells.DEBUFF_CYCLONE) then return false end
    if not utils.can_cast_hostile(rt.cyclone_id, me, t) then return false end
    if utils.cast_target(rt.cyclone_id, me, t) then
        utils.log_debug(menu, "PvP: Cyclone")
        return true
    end
    return false
end

-- Main rotation
local function do_rotation(me, t)
    -- Form consumables check (healthstone/potion in any form)
    local consumable_hp_threshold = ((menu.consumable_health_threshold and menu.consumable_health_threshold:get()) or 35) / 100
    if form_consumables and form_consumables.check_and_use(me, menu, consumable_hp_threshold) then
        return
    end

    -- Mana recovery check (priority before healing)
    if (menu.use_mana_manager and menu.use_mana_manager:get()) then
        local recovered = mana_manager.check_and_recover(me, menu, mana_manager.CLASS_RECOVERY.DRUID)
        if recovered then return end
    end

    -- Ensure in tree form
    if not has_buff(me, spells.BUFF_TREE_OF_LIFE_FORM) then
        if try_tree_form(me) then return end
    end

    -- Cooldowns
    if try_rebirth(me) then return end
    if try_innervate(me) then return end
    if try_tranquility(me) then return end

    -- Clearcasting exploitation: Consume Omen of Clarity procs for free heals
    local tank = get_tank()
    local lowest, lowest_hp = get_lowest_hp_party_member()
    -- Priority: Clearcasting on tank first, then lowest HP ally
    if tank and utils.get_health_pct(tank) < 0.95 then
        if try_healing_touch_clearcasting(me, tank) then return end
        if try_regrowth_clearcasting(me, tank) then return end
    end
    if lowest and lowest_hp < 0.95 then
        if try_healing_touch_clearcasting(me, lowest) then return end
        if try_regrowth_clearcasting(me, lowest) then return end
    end

    -- Get healing targets
    local tank = get_tank()
    local lowest, lowest_hp = get_lowest_hp_party_member()

    -- Emergency healing
    if lowest and lowest_hp < 0.3 then
        if try_natures_swiftness_heal(me, lowest) then return end
        if try_healing_touch(me, lowest) then return end
        if try_swiftmend(me, lowest) then return end
    end

    -- Tank healing priority
    local prioritize_tank = menu.prioritize_tank and menu.prioritize_tank:get_state()
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
    if not me or not me:is_valid() then return end
    if utils.throttle("restomode", MODE_REFRESH) then
        rt.cached_mode = detect_mode()
    end
    if not (menu.enabled and menu.enabled:get_state()) then return end

    -- Initialize middleware on first run
    if not rt.middleware_initialized then
        middleware_manager.initialize(menu)
        rt.middleware_initialized = true
    end

    -- OOC handling
    if not me:is_in_combat() then
        ooc_manager.on_update(me, menu, utils, {
            rez_spell_id = rt.rebirth_id,
            group_buffs = {
                {
                    spell_id = rt.mark_of_the_wild_id,
                    buff_ids = spells.BUFF_MARK_OF_THE_WILD,
                    name = "Mark of the Wild",
                    toggle = menu.use_motw
                },
                {
                    spell_id = rt.tree_form_id,
                    buff_ids = spells.BUFF_TREE_OF_LIFE_FORM,
                    name = "Tree of Life",
                    toggle = menu.use_tree_of_life
                },
                {
                    spell_id = rt.thorns_id,
                    buff_ids = spells.BUFF_THORNS,
                    name = "Thorns",
                    toggle = menu.use_thorns
                },
            }
        })
        return  -- Exit after OOC buffs to prevent combat rotation
    end

    -- Build context and execute middleware
    local context = middleware_manager.build_context(me, menu)
    if middleware_manager.execute(nil, context) then
        return
    end

    -- CC Detection: Stop rotation if crowd controlled
    local cc_detector = require("libraries/cc_detector")
    local should_stop, cc_reason = cc_detector.should_stop_rotation(me)

    -- Druid special: Try shapeshift for roots before stopping
    if should_stop and cc_reason == "ROOTS" then
        if utils.try_shapeshift_root_break(me, menu) then
            return  -- Successfully broke root
        end
    end

    if should_stop then
        return  -- Stop rotation while CC'd
    end

    -- Sync dashboard settings (safe pcall for uninitialized menu items)
    local ok_show, show_dashboard = pcall(function() return menu.show_dashboard:get_state() end)
    if ok_show then
        dashboard.set_enabled(show_dashboard)
    end
    
    local ok_opacity, opacity = pcall(function() return menu.dashboard_opacity:get() end)
    if ok_opacity then
        dashboard.set_opacity(opacity)
    end
    
    local ok_scale, scale = pcall(function() return menu.dashboard_scale:get() end)
    if ok_scale then
        dashboard.set_scale(scale)
    end
    
    local ok_x, pos_x = pcall(function() return menu.dashboard_x:get() end)
    local ok_y, pos_y = pcall(function() return menu.dashboard_y:get() end)
    if ok_x and ok_y then
        dashboard.set_position(pos_x, pos_y)
    end

    local ok_dead, is_dead = pcall(function() return me:is_dead() end)
    if not me or (ok_dead and is_dead) then return end

    local ok_t, t = pcall(function() return me:get_target() end)
    if not ok_t then t = nil end
    if not t or not t:is_valid() or t:is_dead() then return end
    local ok_attack, can_attack = pcall(function() return me:can_attack(t) end)
    if not (ok_attack and can_attack) then return end

    -- PvP context detection
    local now = _core_time()
    if not rt.last_pvp_check or (now - rt.last_pvp_check) > 1.0 then
        rt.pvp_context = utils.detect_pvp_context(me, t)
        rt.last_pvp_check = now
    end

    -- PvP rotation
    if utils.is_pvp_active(menu, rt.pvp_context) then
        if try_pvp_entangling_roots(me, t) then return end
        if try_pvp_hibernate(me, t) then return end
        if try_pvp_cyclone(me, t) then return end
    end

    do_rotation(me, t)
end

core.register_on_update_callback(on_update)

-- Register menu render callback
core.register_on_render_menu_callback(function()
    menu.render()
end)

-- Initialize dashboard
local config = require("libraries/dashboard_config")
dashboard.init(config)
dashboard.register_render_callback()

-- Export toggle settings for external access (only if header loaded successfully)
if header.load then
    local NS = _G.EAXDruidResto and _G.EAXDruidResto.NS or {}
    _G.EAXDruidResto = _G.EAXDruidResto or {}
    _G.EAXDruidResto.NS = NS
    NS.toggle_menu = menu.toggle_menu
end

return {}



