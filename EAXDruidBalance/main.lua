-- EAX Druid Balance | Project Sylvanas
-- Priority: Faerie Fire -> DoTs -> Nukes -> AoE

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")

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
    starfire_id = nil,
    wrath_id = nil,
    moonfire_id = nil,
    insect_swarm_id = nil,
    faerie_fire_id = nil,
    hurricane_id = nil,
    force_of_nature_id = nil,
    innervate_id = nil,
    barkskin_id = nil,
    moonkin_form_id = nil,
    -- Cast tracking
    last_moonfire_cast = 0,
    last_insect_swarm_cast = 0,
    last_faerie_fire_cast = 0,
}

local SPELL_REFRESH = 1.0
local MODE_REFRESH = 4.5
local DOT_REFRESH_THRESHOLD = 3.0

-- Helpers
local function get_me() return _get_local_player() end

local function resolve()
    local now = _core_time()
    if (now - rt.last_spell_refresh) < SPELL_REFRESH then return end
    rt.last_spell_refresh = now
    rt.starfire_id = utils.resolve_spell_id(spells.STARFIRE)
    rt.wrath_id = utils.resolve_spell_id(spells.WRATH)
    rt.moonfire_id = utils.resolve_spell_id(spells.MOONFIRE)
    rt.insect_swarm_id = utils.resolve_spell_id(spells.INSECT_SWARM)
    rt.faerie_fire_id = utils.resolve_spell_id(spells.FAERIE_FIRE)
    rt.hurricane_id = utils.resolve_spell_id(spells.HURRICANE)
    rt.force_of_nature_id = utils.resolve_spell_id(spells.FORCE_OF_NATURE)
    rt.innervate_id = utils.resolve_spell_id(spells.INNERVATE)
    rt.barkskin_id = utils.resolve_spell_id(spells.BARKSKIN)
    rt.moonkin_form_id = utils.resolve_spell_id(spells.MOONKIN_FORM)
end

local function is_moving()
    local me = get_me()
    return me and me.is_moving and me:is_moving()
end

local function mana_pct(me)
    return utils.mana_pct(me)
end

local function has_debuff(target, tbl)
    return utils.has_debuff(target, tbl)
end

local function debuff_rem(target, tbl)
    if not target or not target:is_valid() then return 0 end
    local d = target:get_debuff_data(tbl)
    if d and d.is_active and (d.remaining or 0) > 0 then return d.remaining end
    d = target:get_aura_data(tbl)
    if d and d.is_active and (d.remaining or 0) > 0 then return d.remaining end
    return 0
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
    local s = menu.get_setting("mode", 1)
    if s == 2 then return "solo" elseif s == 3 then return "dungeon" elseif s == 4 then return "raid" end
    return rt.cached_mode
end

-- Rotation functions
local function try_faerie_fire(me, t)
    if not menu.get_setting("use_faerie_fire", true) then return false end
    if not rt.faerie_fire_id then return false end
    if has_debuff(t, spells.DEBUFF_FAERIE_FIRE) then return false end
    if not utils.can_cast_hostile(rt.faerie_fire_id, me, t) then return false end
    if utils.cast_target(rt.faerie_fire_id, me, t) then
        utils.log_debug(menu, "Faerie Fire")
        return true
    end
    return false
end

local function try_moonfire(me, t)
    if not menu.get_setting("use_moonfire", true) then return false end
    if not rt.moonfire_id then return false end
    local rem = debuff_rem(t, spells.DEBUFF_MOONFIRE)
    if rem > DOT_REFRESH_THRESHOLD then return false end
    if not utils.can_cast_hostile(rt.moonfire_id, me, t) then return false end
    if utils.cast_target(rt.moonfire_id, me, t) then
        rt.last_moonfire_cast = _core_time()
        utils.log_debug(menu, "Moonfire")
        return true
    end
    return false
end

local function try_insect_swarm(me, t)
    if not menu.get_setting("use_insect_swarm", true) then return false end
    if not rt.insect_swarm_id then return false end
    local rem = debuff_rem(t, spells.DEBUFF_INSECT_SWARM)
    if rem > DOT_REFRESH_THRESHOLD then return false end
    if not utils.can_cast_hostile(rt.insect_swarm_id, me, t) then return false end
    if utils.cast_target(rt.insect_swarm_id, me, t) then
        rt.last_insect_swarm_cast = _core_time()
        utils.log_debug(menu, "Insect Swarm")
        return true
    end
    return false
end

local function try_starfire(me, t)
    if not menu.get_setting("use_starfire", true) then return false end
    if not rt.starfire_id then return false end
    if is_moving() then return false end
    if not utils.can_cast_hostile(rt.starfire_id, me, t) then return false end
    if utils.cast_target(rt.starfire_id, me, t) then
        utils.log_debug(menu, "Starfire")
        return true
    end
    return false
end

local function try_wrath(me, t)
    if not menu.get_setting("use_wrath", true) then return false end
    if not rt.wrath_id then return false end
    if not utils.can_cast_hostile(rt.wrath_id, me, t) then return false end
    if utils.cast_target(rt.wrath_id, me, t) then
        utils.log_debug(menu, "Wrath")
        return true
    end
    return false
end

local function try_hurricane(me, t)
    if not menu.get_setting("use_hurricane", true) then return false end
    if not rt.hurricane_id then return false end
    if is_moving() then return false end
    local min_targets = menu.get_setting("hurricane_min_targets", 3)
    local count = 1
    local tp = t:get_position()
    if tp then
        for _, o in ipairs(core.object_manager.get_all_objects()) do
            if o and o:is_valid() and o:is_unit() and not o:is_dead() and me:can_attack(o) and o ~= t then
                local op = o:get_position()
                if op then
                    local dx, dy, dz = op.x - tp.x, op.y - tp.y, op.z - tp.z
                    if (dx * dx + dy * dy + dz * dz) <= 100 then
                        count = count + 1
                    end
                end
            end
        end
    end
    if count < min_targets then return false end
    if not utils.can_cast_hostile(rt.hurricane_id, me, t) then return false end
    if utils.cast_target(rt.hurricane_id, me, t) then
        utils.log_debug(menu, "Hurricane (" .. count .. " targets)")
        return true
    end
    return false
end

local function try_force_of_nature(me, t)
    if not menu.get_setting("use_force_of_nature", true) then return false end
    if not rt.force_of_nature_id then return false end
    if not utils.can_cast_hostile(rt.force_of_nature_id, me, t) then return false end
    if utils.cast_target(rt.force_of_nature_id, me, t) then
        utils.log_debug(menu, "Force of Nature")
        return true
    end
    return false
end

local function try_innervate(me)
    if not menu.get_setting("use_innervate", true) then return false end
    if not rt.innervate_id then return false end
    local threshold = menu.get_setting("innervate_mana", 20) / 100
    if mana_pct(me) > threshold then return false end
    if not utils.can_cast_self(rt.innervate_id, me) then return false end
    if utils.cast_self(rt.innervate_id, me) then
        utils.log_debug(menu, "Innervate")
        return true
    end
    return false
end

local function try_barkskin(me)
    if not menu.get_setting("use_barkskin", true) then return false end
    if not rt.barkskin_id then return false end
    local threshold = menu.get_setting("barkskin_hp", 30) / 100
    if utils.get_health_pct(me) > threshold then return false end
    if not utils.can_cast_self(rt.barkskin_id, me) then return false end
    if utils.cast_self(rt.barkskin_id, me) then
        utils.log_debug(menu, "Barkskin")
        return true
    end
    return false
end

local function try_moonkin_form(me)
    if not rt.moonkin_form_id then return false end
    if utils.has_buff(me, spells.BUFF_MOONKIN_FORM) then return false end
    if not utils.can_cast_self(rt.moonkin_form_id, me) then return false end
    if utils.cast_self(rt.moonkin_form_id, me) then
        utils.log_debug(menu, "Moonkin Form")
        return true
    end
    return false
end

-- Main rotation
local function do_rotation(me, t)
    -- Defensive
    if try_barkskin(me) then return end

    -- Cooldowns
    if try_innervate(me) then return end
    if try_force_of_nature(me, t) then return end

    -- Form check
    if not utils.has_buff(me, spells.BUFF_MOONKIN_FORM) then
        if try_moonkin_form(me) then return end
    end

    -- Rotation priority
    if try_faerie_fire(me, t) then return end
    if try_moonfire(me, t) then return end
    if try_insect_swarm(me, t) then return end
    if try_hurricane(me, t) then return end

    -- Mana tier check
    local mp = mana_pct(me)
    local tier2 = menu.get_setting("tier2_mana", 30) / 100
    if mp < tier2 then
        if try_wrath(me, t) then return end
    else
        if try_starfire(me, t) then return end
        if try_wrath(me, t) then return end
    end
end

-- Update loop
local function on_update()
    resolve()
    local me = get_me()
    if utils.throttle("balancemode", MODE_REFRESH) then
        rt.cached_mode = detect_mode()
    end
    if not menu or not menu.is_enabled() then return end
    if not me or me:is_dead() then return end

    local t = me:get_target()
    if not t or not t:is_valid() or t:is_dead() then return end
    if not me:can_attack(t) then return end

    do_rotation(me, t)
end

core.register_on_update_callback(on_update)
-- ============================================================================
-- RENDER CALLBACKS - Menu Registration
-- ============================================================================

-- Register render callbacks for menu system
core.register_on_render_callback(function()
    if menu and menu.on_render then
        local ok, err = pcall(menu.on_render)
        if not ok then
            core.log_error(string.format("[EAX Balance] Render error: %s", tostring(err)))
        end
    end
end)

core.register_on_render_menu_callback(function()
    if menu and menu.on_menu_render then
        local ok, err = pcall(menu.on_menu_menu_render)
        if not ok then
            core.log_error(string.format("[EAX Balance] Menu render error: %s", tostring(err)))
        end
    end
end)

-- Export toggle settings for external access
local NS = _G.EAXDruidBalance and _G.EAXDruidBalance.NS or {}
_G.EAXDruidBalance = _G.EAXDruidBalance or {}
_G.EAXDruidBalance.NS = NS
NS.toggle_menu = menu.toggle_menu

return {}
