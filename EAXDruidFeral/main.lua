require("libraries/path_bootstrap")
-- EAX Druid Feral | Project Sylvanas
-- Priority: Prowl -> Ravage -> DoTs -> Finishers -> Builders

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")
local energy_tick = require("libraries/energy_tick")

-- Hot-path local caching
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player

-- Runtime state
local rt = {
    last_spell_refresh = 0,
    cached_mode = "solo",
    prev_toggle_state = false,
    -- Spell IDs
    shred_id = nil,
    rake_id = nil,
    rip_id = nil,
    ferocious_bite_id = nil,
    mangle_cat_id = nil,
    tigers_fury_id = nil,
    prowl_id = nil,
    ravage_id = nil,
    cat_form_id = nil,
    faerie_fire_id = nil,
    -- State
    last_powershift_time = 0,
    spell_costs = {
        shred = 42,
        mangle = 40,
        rake = 35,
        rip = 30,
        ferocious_bite = 35,
        ravage = 60,
        tigers_fury = 30,
    },
}

local SPELL_REFRESH = 1.0
local MODE_REFRESH = 4.5
local ENERGY_TICK = 2.0
local SHIFT_COOLDOWN = 1.0

-- Helpers
local function get_me() return _get_local_player() end

local function resolve()
    local now = _core_time()
    if (now - rt.last_spell_refresh) < SPELL_REFRESH then return end
    rt.last_spell_refresh = now

    local function get_spell_cost(spell_id, fallback)
        if not spell_id then return fallback end
        if core.spell_book and core.spell_book.get_spell_power_cost then
            local cost = core.spell_book.get_spell_power_cost(spell_id)
            if cost and cost > 0 then return cost end
        end
        return fallback
    end

    rt.shred_id = utils.resolve_spell_id(spells.SHRED)
    rt.rake_id = utils.resolve_spell_id(spells.RAKE)
    rt.rip_id = utils.resolve_spell_id(spells.RIP)
    rt.ferocious_bite_id = utils.resolve_spell_id(spells.FEROCIOUS_BITE)
    rt.mangle_cat_id = utils.resolve_spell_id(spells.MANGLE_CAT)
    rt.tigers_fury_id = utils.resolve_spell_id(spells.TIGERS_FURY)
    rt.prowl_id = utils.resolve_spell_id(spells.PROWL)
    rt.ravage_id = utils.resolve_spell_id(spells.RAVAGE)
    rt.cat_form_id = utils.resolve_spell_id(spells.CAT_FORM)
    rt.faerie_fire_id = utils.resolve_spell_id(spells.FAERIE_FIRE_FERAL) or utils.resolve_spell_id(spells.FAERIE_FIRE)

    rt.spell_costs.shred = get_spell_cost(rt.shred_id, 42)
    rt.spell_costs.mangle = get_spell_cost(rt.mangle_cat_id, 40)
    rt.spell_costs.rake = get_spell_cost(rt.rake_id, 35)
    rt.spell_costs.rip = get_spell_cost(rt.rip_id, 30)
    rt.spell_costs.ferocious_bite = get_spell_cost(rt.ferocious_bite_id, 35)
    rt.spell_costs.ravage = get_spell_cost(rt.ravage_id, 60)
    rt.spell_costs.tigers_fury = get_spell_cost(rt.tigers_fury_id, 30)
end

local function energy(me)
    return utils.get_energy(me)
end

local function combo_points(me)
    return utils.get_combo_points(me)
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

local function is_stealthed(me)
    return utils.has_buff(me, spells.BUFF_PROWL)
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
local function try_cat_form(me)
    if not rt.cat_form_id then return false end
    if utils.has_buff(me, spells.BUFF_CAT_FORM) then return false end
    if not utils.can_cast_self(rt.cat_form_id, me) then return false end
    if utils.cast_self(rt.cat_form_id, me) then
        utils.log_debug(menu, "Cat Form")
        return true
    end
    return false
end

local function try_prowl(me)
    if not (menu.use_prowl_opener and menu.use_prowl_opener:is_checked()) then return false end
    if not rt.prowl_id then return false end
    if me:is_in_combat() then return false end
    if is_stealthed(me) then return false end
    if not utils.can_cast_self(rt.prowl_id, me) then return false end
    if utils.cast_self(rt.prowl_id, me) then
        utils.log_debug(menu, "Prowl")
        return true
    end
    return false
end

local function try_ravage(me, t)
    if not rt.ravage_id then return false end
    if not is_stealthed(me) then return false end
    if energy(me) < 60 then return false end
    if not utils.can_cast_hostile(rt.ravage_id, me, t) then return false end
    if utils.cast_target(rt.ravage_id, me, t) then
        utils.log_debug(menu, "Ravage")
        return true
    end
    return false
end

local function try_rake(me, t)
    if not (menu.use_rake and menu.use_rake:is_checked()) then return false end
    if not rt.rake_id then return false end
    if has_debuff(t, spells.DEBUFF_RAKE) then return false end
    if energy(me) < 35 then return false end
    if not utils.can_cast_hostile(rt.rake_id, me, t) then return false end
    if utils.cast_target(rt.rake_id, me, t) then
        utils.log_debug(menu, "Rake")
        return true
    end
    return false
end

local function try_rip(me, t)
    if not (menu.use_rip and menu.use_rip:is_checked()) then return false end
    if not rt.rip_id then return false end
    if combo_points(me) < 5 then return false end
    if has_debuff(t, spells.DEBUFF_RIP) then return false end
    if energy(me) < 30 then return false end
    if not utils.can_cast_hostile(rt.rip_id, me, t) then return false end
    if utils.cast_target(rt.rip_id, me, t) then
        utils.log_debug(menu, "Rip")
        return true
    end
    return false
end

local function try_ferocious_bite(me, t)
    if not (menu.use_ferocious_bite and menu.use_ferocious_bite:is_checked()) then return false end
    if not rt.ferocious_bite_id then return false end
    if combo_points(me) < 4 then return false end
    if energy(me) < 35 then return false end
    if not utils.can_cast_hostile(rt.ferocious_bite_id, me, t) then return false end
    if utils.cast_target(rt.ferocious_bite_id, me, t) then
        utils.log_debug(menu, "Ferocious Bite")
        return true
    end
    return false
end

local function try_mangle(me, t)
    if not (menu.use_mangle and menu.use_mangle:is_checked()) then return false end
    if not rt.mangle_cat_id then return false end
    if has_debuff(t, spells.DEBUFF_MANGLE) then return false end
    if energy(me) < 40 then return false end
    if not utils.can_cast_hostile(rt.mangle_cat_id, me, t) then return false end
    if utils.cast_target(rt.mangle_cat_id, me, t) then
        utils.log_debug(menu, "Mangle")
        return true
    end
    return false
end

local function try_shred(me, t)
    if not (menu.use_shred and menu.use_shred:is_checked()) then return false end
    if not rt.shred_id then return false end
    if combo_points(me) >= 5 then return false end

    local e = energy(me)

    -- NEW: Tick optimization - prefer Mangle over Shred in dead-zone energy
    if menu.cat_tick_optimization and menu.cat_tick_optimization:is_checked() then
        if energy_tick.should_prefer_mangle(e, rt.spell_costs.mangle, rt.spell_costs.shred) then
            if utils.throttle("tick_opt_debug", 2.0) then
                utils.log_debug(menu, string.format("Tick opt: preferring Mangle over Shred (energy=%d, tick in %.2fs)",
                    e, energy_tick.time_until_next_tick()))
            end
            return false
        end
    end

    if e < 42 then return false end
    if not utils.can_cast_hostile(rt.shred_id, me, t) then return false end
    if utils.cast_target(rt.shred_id, me, t) then
        utils.log_debug(menu, "Shred")
        return true
    end
    return false
end

local function try_tigers_fury(me)
    if not (menu.use_tigers_fury and menu.use_tigers_fury:is_checked()) then return false end
    if not rt.tigers_fury_id then return false end
    if utils.has_buff(me, spells.BUFF_TIGERS_FURY) then return false end
    if energy(me) > 40 then return false end
    if not utils.can_cast_self(rt.tigers_fury_id, me) then return false end
    if utils.cast_self(rt.tigers_fury_id, me) then
        utils.log_debug(menu, "Tiger's Fury")
        return true
    end
    return false
end

local function try_powershift(me)
    if not (menu.auto_powershift and menu.auto_powershift:is_checked()) then return false end
    if not rt.cat_form_id then return false end
    if not utils.has_buff(me, spells.BUFF_CAT_FORM) then return false end

    local min_mana = ((menu.powershift_min_mana and menu.powershift_min_mana:get()) or 25) / 100
    if utils.mana_pct(me) < min_mana then return false end

    local e = energy(me)
    if e > 20 then return false end

    -- NEW: Check if we should delay for an imminent energy tick
    if energy_tick.should_delay_shift() then
        if utils.throttle("powershift_delay_debug", 2.0) then
            utils.log_debug(menu, string.format("Powershift delayed - tick in %.2fs", energy_tick.time_until_next_tick()))
        end
        return false
    end

    -- NEW: Use Wolfshead detection for energy calculation
    local has_wolfshead = energy_tick.is_wolfshead_equipped()
    local furor_energy = 40
    local wolfshead_bonus = has_wolfshead and 20 or 0
    local energy_after_shift = furor_energy + wolfshead_bonus

    if energy_after_shift <= e then
        if utils.throttle("powershift_no_gain", 3.0) then
            utils.log_debug(menu, "Powershift skipped - no energy gain")
        end
        return false
    end

    if not utils.can_cast_self(rt.cat_form_id, me) then return false end

    -- Record shift time for tick tracker BEFORE casting
    energy_tick.on_shift()

    if utils.cast_self(rt.cat_form_id, me) then
        rt.last_powershift_time = _core_time()
        utils.log_debug(menu, string.format("Powershift: %d -> %d energy (Wolfshead: %s)",
            e, energy_after_shift, tostring(has_wolfshead)))
        return true
    end
    return false
end

local function try_faerie_fire(me, t)
    if not (menu.use_faerie_fire and menu.use_faerie_fire:is_checked()) then return false end
    if not rt.faerie_fire_id then return false end
    if has_debuff(t, spells.DEBUFF_FAERIE_FIRE) then return false end
    if not utils.can_cast_hostile(rt.faerie_fire_id, me, t) then return false end
    if utils.cast_target(rt.faerie_fire_id, me, t) then
        utils.log_debug(menu, "Faerie Fire")
        return true
    end
    return false
end

-- Main rotation
local function do_rotation(me, t)
    if utils.throttle("energy_tick_debug", 3.0) and menu.debug and menu.debug:is_checked() then
        local tick_info = energy_tick.get_debug_info()
        core.log(string.format(
            "|cFF00FF00[Tick Debug]|r confident=%s time_until=%.2fs delay=%s wolfshead=%s",
            tostring(tick_info.confident),
            tick_info.time_until_next,
            tostring(tick_info.should_delay),
            tostring(tick_info.wolfshead)
        ))
    end

    -- Debug: Log entry and state
    if utils.throttle("feral_debug", 2.0) then
        local e = energy(me)
        local cp = combo_points(me)
        local rip_ok = utils.can_cast_hostile(rt.rip_id, me, t)
        local rake_ok = utils.can_cast_hostile(rt.rake_id, me, t)
        core.log(string.format("|cFF00FF00[EAX Feral]|r Energy=%d CP=%d RipOK=%s RakeOK=%s", e, cp, tostring(rip_ok), tostring(rake_ok)))
    end

    -- Ensure in cat form
    if not utils.has_buff(me, spells.BUFF_CAT_FORM) then
        if try_cat_form(me) then return end
    end

    -- Stealth opener
    if not me:is_in_combat() then
        if try_prowl(me) then return end
    end
    if is_stealthed(me) then
        if try_ravage(me, t) then return end
    end

    -- Cooldowns
    if try_tigers_fury(me) then return end

    -- Powershift if low energy
    if try_powershift(me) then return end

    -- Rotation priority
    if try_faerie_fire(me, t) then return end
    if try_rip(me, t) then return end
    if try_ferocious_bite(me, t) then return end
    if try_rake(me, t) then return end
    if try_mangle(me, t) then return end
    if try_shred(me, t) then return end
end

-- Update loop
local function on_update()
    resolve()
    local me = get_me()

    -- Update energy tick tracker
    local current_energy = energy(me)
    local in_cat_form = utils.has_buff(me, spells.BUFF_CAT_FORM)
    energy_tick.update(current_energy, in_cat_form)

    if utils.throttle("feral_mode", MODE_REFRESH) then
        rt.cached_mode = detect_mode()
    end

    -- Debug: Check if menu exists and is enabled
    if not menu then
        if utils.throttle("feral_no_menu", 5.0) then
            core.log("|cFFFF0000[EAX Feral]|r menu is nil!")
        end
        return
    end

    -- Debug: Check unified state directly
    local unified = require("EAX_Unified/menu")
    local is_enabled = menu.is_enabled()

    if utils.throttle("feral_debug_state", 3.0) then
        core.log(string.format("|cFFFFFF00[EAX Feral]|r is_enabled=%s unified=%s", tostring(is_enabled), tostring(unified ~= nil)))
    end

    if not is_enabled then
        return
    end

    if not me or me:is_dead() then return end

    local t = me:get_target()
    if not t or not t:is_valid() or t:is_dead() then return end
    if not me:can_attack(t) then return end

    do_rotation(me, t)
end

core.register_on_update_callback(on_update)

-- Export toggle settings for external access
local NS = _G.EAXDruidFeral_ and _G.EAXDruidFeral_.NS or {}
_G.EAXDruidFeral_ = _G.EAXDruidFeral_ or {}
_G.EAXDruidFeral_.NS = NS
NS.toggle_menu = menu.toggle_menu

return {}
