-- EAX Druid Bear | Project Sylvanas
-- Priority: Mangle -> Lacerate -> Swipe -> Maul

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
    maul_id = nil,
    swipe_id = nil,
    lacerate_id = nil,
    mangle_bear_id = nil,
    demo_roar_id = nil,
    frenzied_regen_id = nil,
    growl_id = nil,
    challenging_roar_id = nil,
    bash_id = nil,
    enrage_id = nil,
    barkskin_id = nil,
    bear_form_id = nil,
    -- State
    lacerate_stacks = 0,
}

local SPELL_REFRESH = 1.0
local MODE_REFRESH = 4.5

-- Helpers
local function get_me() return _get_local_player() end

local function resolve()
    local now = _core_time()
    if (now - rt.last_spell_refresh) < SPELL_REFRESH then return end
    rt.last_spell_refresh = now
    rt.maul_id = utils.resolve_spell_id(spells.MAUL)
    rt.swipe_id = utils.resolve_spell_id(spells.SWIPE)
    rt.lacerate_id = utils.resolve_spell_id(spells.LACERATE)
    rt.mangle_bear_id = utils.resolve_spell_id(spells.MANGLE_BEAR)
    rt.demo_roar_id = utils.resolve_spell_id(spells.DEMORALIZING_ROAR)
    rt.frenzied_regen_id = utils.resolve_spell_id(spells.FRENZIED_REGENERATION)
    rt.growl_id = utils.resolve_spell_id(spells.GROWL)
    rt.challenging_roar_id = utils.resolve_spell_id(spells.CHALLENGING_ROAR)
    rt.bash_id = utils.resolve_spell_id(spells.BASH)
    rt.enrage_id = utils.resolve_spell_id(spells.ENRAGE)
    rt.barkskin_id = utils.resolve_spell_id(spells.BARKSKIN)
    rt.bear_form_id = utils.resolve_spell_id(spells.BEAR_FORM) or utils.resolve_spell_id(spells.DIRE_BEAR_FORM)
end

local function rage(me)
    return utils.get_rage(me)
end

local function has_debuff(target, tbl)
    return utils.has_debuff(target, tbl)
end

local function debuff_stacks(target, spell_id)
    if not target or not target:is_valid() then return 0 end
    local d = target:get_debuff_data({ spell_id })
    if d and d.is_active then return d.stacks or 0 end
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
    local s = (menu.mode and menu.mode:get()) or 1
    if s == 2 then return "solo" elseif s == 3 then return "dungeon" elseif s == 4 then return "raid" end
    return rt.cached_mode
end

-- Rotation functions
local function try_bear_form(me)
    if not rt.bear_form_id then return false end
    if utils.has_buff(me, spells.BUFF_BEAR_FORM) then return false end
    if not utils.can_cast_self(rt.bear_form_id, me) then return false end
    if utils.cast_self(rt.bear_form_id, me) then
        utils.log_debug(menu, "Bear Form")
        return true
    end
    return false
end

local function try_frenzied_regeneration(me)
    if not (menu.use_frenzied_regen and menu.use_frenzied_regen:is_checked()) then return false end
    if not rt.frenzied_regen_id then return false end
    local threshold = ((menu.frenzied_regen_hp and menu.frenzied_regen_hp:get_value()) or 30) / 100
    if utils.get_health_pct(me) > threshold then return false end
    if rage(me) < 10 then return false end
    if not utils.can_cast_self(rt.frenzied_regen_id, me) then return false end
    if utils.cast_self(rt.frenzied_regen_id, me) then
        utils.log_debug(menu, "Frenzied Regeneration")
        return true
    end
    return false
end

local function try_barkskin(me)
    if not (menu.use_barkskin and menu.use_barkskin:is_checked()) then return false end
    if not rt.barkskin_id then return false end
    local threshold = ((menu.barkskin_hp and menu.barkskin_hp:get_value()) or 40) / 100
    if utils.get_health_pct(me) > threshold then return false end
    if not utils.can_cast_self(rt.barkskin_id, me) then return false end
    if utils.cast_self(rt.barkskin_id, me) then
        utils.log_debug(menu, "Barkskin")
        return true
    end
    return false
end

local function try_growl(me, t)
    if not (menu.use_growl and menu.use_growl:is_checked()) then return false end
    if not rt.growl_id then return false end
    if not utils.can_cast_hostile(rt.growl_id, me, t) then return false end
    if utils.cast_target(rt.growl_id, me, t) then
        utils.log_debug(menu, "Growl")
        return true
    end
    return false
end

local function try_challenging_roar(me)
    if not (menu.use_challenging_roar and menu.use_challenging_roar:is_checked()) then return false end
    if not rt.challenging_roar_id then return false end
    if not utils.can_cast_self(rt.challenging_roar_id, me) then return false end
    if utils.cast_self(rt.challenging_roar_id, me) then
        utils.log_debug(menu, "Challenging Roar")
        return true
    end
    return false
end

local function try_mangle(me, t)
    if not (menu.use_mangle and menu.use_mangle:is_checked()) then return false end
    if not rt.mangle_bear_id then return false end
    if rage(me) < 20 then return false end
    if not utils.can_cast_hostile(rt.mangle_bear_id, me, t) then return false end
    if utils.cast_target(rt.mangle_bear_id, me, t) then
        utils.log_debug(menu, "Mangle")
        return true
    end
    return false
end

local function try_lacerate(me, t)
    if not (menu.use_lacerate and menu.use_lacerate:is_checked()) then return false end
    if not rt.lacerate_id then return false end
    local stacks = debuff_stacks(t, rt.lacerate_id)
    if stacks >= 5 then return false end
    if rage(me) < 15 then return false end
    if not utils.can_cast_hostile(rt.lacerate_id, me, t) then return false end
    if utils.cast_target(rt.lacerate_id, me, t) then
        utils.log_debug(menu, "Lacerate (" .. (stacks + 1) .. "/5)")
        return true
    end
    return false
end

local function try_swipe(me, t)
    if not (menu.use_swipe and menu.use_swipe:is_checked()) then return false end
    if not rt.swipe_id then return false end
    local min_targets = (menu.swipe_min_targets and menu.swipe_min_targets:get()) or 2
    local count = 1
    local tp = t:get_position()
    if tp then
        for _, o in ipairs(core.object_manager.get_all_objects()) do
            if o and o:is_valid() and o:is_unit() and not o:is_dead() and me:can_attack(o) and o ~= t then
                local op = o:get_position()
                if op then
                    local dx, dy, dz = op.x - tp.x, op.y - tp.y, op.z - tp.z
                    if (dx * dx + dy * dy + dz * dz) <= 64 then
                        count = count + 1
                    end
                end
            end
        end
    end
    if count < min_targets then return false end
    if rage(me) < 20 then return false end
    if not utils.can_cast_hostile(rt.swipe_id, me, t) then return false end
    if utils.cast_target(rt.swipe_id, me, t) then
        utils.log_debug(menu, "Swipe (" .. count .. " targets)")
        return true
    end
    return false
end

local function try_demo_roar(me, t)
    if not (menu.use_demo_roar and menu.use_demo_roar:is_checked()) then return false end
    if not rt.demo_roar_id then return false end
    if has_debuff(t, spells.DEBUFF_DEMORALIZING_ROAR) then return false end
    if rage(me) < 10 then return false end
    if not utils.can_cast_hostile(rt.demo_roar_id, me, t) then return false end
    if utils.cast_target(rt.demo_roar_id, me, t) then
        utils.log_debug(menu, "Demoralizing Roar")
        return true
    end
    return false
end

local function try_maul(me, t)
    if not (menu.use_maul and menu.use_maul:is_checked()) then return false end
    if not rt.maul_id then return false end
    if rage(me) < 15 then return false end
    if not utils.can_cast_hostile(rt.maul_id, me, t) then return false end
    if utils.cast_target(rt.maul_id, me, t) then
        utils.log_debug(menu, "Maul")
        return true
    end
    return false
end

local function try_enrage(me)
    if not (menu.use_enrage and menu.use_enrage:is_checked()) then return false end
    if not rt.enrage_id then return false end
    if rage(me) > 30 then return false end
    if not utils.can_cast_self(rt.enrage_id, me) then return false end
    if utils.cast_self(rt.enrage_id, me) then
        utils.log_debug(menu, "Enrage")
        return true
    end
    return false
end

-- Main rotation
local function do_rotation(me, t)
    -- Ensure in bear form
    if not utils.has_buff(me, spells.BUFF_BEAR_FORM) then
        if try_bear_form(me) then return end
    end

    -- Defensive
    if try_frenzied_regeneration(me) then return end
    if try_barkskin(me) then return end

    -- Taunts
    if try_growl(me, t) then return end

    -- Cooldowns
    if try_enrage(me) then return end

    -- Rotation priority
    if try_mangle(me, t) then return end
    if try_demo_roar(me, t) then return end
    if try_lacerate(me, t) then return end
    if try_swipe(me, t) then return end
    if try_maul(me, t) then return end
end

-- Update loop
local function on_update()
    resolve()
    local me = get_me()
    if utils.throttle("bearmode", MODE_REFRESH) then
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

-- Export toggle settings for external access
local NS = _G.EAXDruidBear and _G.EAXDruidBear.NS or {}
_G.EAXDruidBear = _G.EAXDruidBear or {}
_G.EAXDruidBear.NS = NS
NS.toggle_menu = menu.toggle_menu

return {}
