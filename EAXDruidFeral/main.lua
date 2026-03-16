-- EAX Druid Feral | main.lua
-- Dual-lane cat and bear rotation logic with automatic form detection.

local menu = require("menu")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")

---@type interrupt_manager
local interrupt_manager = require("common/eax_shared/interrupt_manager")
---@type ttd_tracker
local ttd_tracker = require("common/eax_shared/ttd_tracker")
---@type racial_manager
local racial_manager = require("common/eax_shared/racial_manager")
---@type defensive_manager
local defensive_manager = require("common/eax_shared/defensive_manager")

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local runtime = {
    cat_form_id = nil,
    bear_form_id = nil,
    faerie_fire_feral_id = nil,
    mangle_cat_id = nil,
    rake_id = nil,
    shred_id = nil,
    rip_id = nil,
    ferocious_bite_id = nil,
    tigers_fury_id = nil,
    mangle_bear_id = nil,
    maul_id = nil,
    swipe_id = nil,
    growl_id = nil,
    frenzied_regeneration_id = nil,
    berserk_id = nil,
    demoralizing_roar_id = nil,
    maim_id = nil,
    prev_toggle_state = false,
    last_cast_time = 0,
    cached_mode = "solo",
    current_lane = "cat",
    combo_points = 0,
    combo_target_key = nil,
    pending_casts = {},
}

local GCD_CAST_INTERVAL = 0.05
local PENDING_CAST_TIMEOUT_S = 1.25
local FAST_PENDING_CAST_TIMEOUT_S = 0.75

local function resolve_spells()
    runtime.cat_form_id = utils.resolve_spell_id(spells.CAT_FORM)
    runtime.bear_form_id = utils.resolve_spell_id(spells.BEAR_FORM)
    runtime.faerie_fire_feral_id = utils.resolve_spell_id(spells.FAERIE_FIRE_FERAL)
    runtime.mangle_cat_id = utils.resolve_spell_id(spells.MANGLE_CAT)
    runtime.rake_id = utils.resolve_spell_id(spells.RAKE)
    runtime.shred_id = utils.resolve_spell_id(spells.SHRED)
    runtime.rip_id = utils.resolve_spell_id(spells.RIP)
    runtime.ferocious_bite_id = utils.resolve_spell_id(spells.FEROCIOUS_BITE)
    runtime.tigers_fury_id = utils.resolve_spell_id(spells.TIGERS_FURY)
    runtime.mangle_bear_id = utils.resolve_spell_id(spells.MANGLE_BEAR)
    runtime.maul_id = utils.resolve_spell_id(spells.MAUL)
    runtime.swipe_id = utils.resolve_spell_id(spells.SWIPE)
    runtime.growl_id = utils.resolve_spell_id(spells.GROWL)
    runtime.frenzied_regeneration_id = utils.resolve_spell_id(spells.FRENZIED_REGENERATION)
    runtime.berserk_id            = utils.resolve_spell_id(spells.BERSERK)
    runtime.demoralizing_roar_id   = utils.resolve_spell_id(spells.DEMORALIZING_ROAR)
    runtime.maim_id                = utils.resolve_spell_id(spells.MAIM)
end

local function log_resolved_spells()
    core.log("[EAX Druid Feral] Resolved: CatMangle=" .. tostring(runtime.mangle_cat_id)
        .. " Shred=" .. tostring(runtime.shred_id)
        .. " Rip=" .. tostring(runtime.rip_id)
        .. " BearMangle=" .. tostring(runtime.mangle_bear_id)
        .. " Swipe=" .. tostring(runtime.swipe_id)
        .. " Growl=" .. tostring(runtime.growl_id))
end

resolve_spells()
log_resolved_spells()

local function note_cast()
    runtime.last_cast_time = core.time()
end

local function is_gcd_ready()
    if (core.time() - runtime.last_cast_time) < GCD_CAST_INTERVAL then
        return false
    end
    return core.spell_book.get_global_cooldown() <= 0
end

local function is_pending_cast(spell_id)
    if not spell_id then return false end
    local pending = runtime.pending_casts[spell_id]
    if not pending then return false end
    if (core.time() - pending.requested_at) >= pending.timeout_s then
        runtime.pending_casts[spell_id] = nil
        return false
    end
    return true
end

local function mark_pending_cast(spell_id, timeout_s)
    if not spell_id then return end
    runtime.pending_casts[spell_id] = {
        requested_at = core.time(),
        timeout_s = timeout_s or PENDING_CAST_TIMEOUT_S,
    }
end

local function detect_mode(me)
    local objects = core.object_manager.get_all_objects()
    local party_count = 0

    for i = 1, #objects do
        local obj = objects[i]
        if obj
            and obj:is_valid()
            and obj:is_unit()
            and not obj:is_dead()
            and not utils.same_unit(me, obj)
            and obj:is_party_member()
        then
            party_count = party_count + 1
        end
    end

    if party_count == 0 then
        return "solo"
    elseif party_count <= 4 then
        return "dungeon"
    end
    return "raid"
end

local function get_effective_mode()
    local idx = menu.mode:get()
    if idx == 2 then return "solo" end
    if idx == 3 then return "dungeon" end
    if idx == 4 then return "raid" end
    return runtime.cached_mode
end

local function is_valid_hostile_target(me, target)
    return target and target:is_valid() and not target:is_dead() and me:can_attack(target)
end

local function sync_combo_target(target)
    local target_key = utils.get_target_key(target)
    if not target_key then
        runtime.combo_points = 0
        runtime.combo_target_key = nil
        return
    end

    if runtime.combo_target_key ~= target_key then
        runtime.combo_points = 0
        runtime.combo_target_key = target_key
    end
end

local function get_requested_lane(me)
    local lane_idx = menu.lane:get()
    if lane_idx == 2 then return "cat" end
    if lane_idx == 3 then return "bear" end

    if utils.has_buff(me, spells.BUFF_CAT_FORM) then
        return "cat"
    end
    if utils.has_buff(me, spells.BUFF_BEAR_FORM) then
        return "bear"
    end

    if runtime.current_lane then
        return runtime.current_lane
    end

    if get_effective_mode() == "solo" then
        return "cat"
    end
    return "bear"
end

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        local was_enabled = menu.enabled:get_state()
        menu.enabled:set(not was_enabled)
        utils.log_debug(menu, "Toggle -> " .. tostring(not was_enabled))
    end
    runtime.prev_toggle_state = current
end

local function try_shift_form(me, lane)
    if not menu.auto_form:get_state() then return false end

    if lane == "cat" then
        if not runtime.cat_form_id or utils.has_buff(me, spells.BUFF_CAT_FORM) then return false end
        if is_pending_cast(runtime.cat_form_id) then return false end
        if not utils.can_cast_self(runtime.cat_form_id, me) then return false end
        if utils.cast_self(runtime.cat_form_id, me) then
            mark_pending_cast(runtime.cat_form_id, PENDING_CAST_TIMEOUT_S)
            utils.log_debug(menu, "Shift -> Cat Form")
            note_cast()
            return true
        end
        return false
    end

    if not runtime.bear_form_id or utils.has_buff(me, spells.BUFF_BEAR_FORM) then return false end
    if is_pending_cast(runtime.bear_form_id) then return false end
    if not utils.can_cast_self(runtime.bear_form_id, me) then return false end
    if utils.cast_self(runtime.bear_form_id, me) then
        mark_pending_cast(runtime.bear_form_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Shift -> Bear Form")
        note_cast()
        return true
    end

    return false
end

local function try_faerie_fire(me, target)
    if not menu.use_faerie_fire:get_state() then return false end
    if not runtime.faerie_fire_feral_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_FAERIE_FIRE) >= 3000 then return false end
    if is_pending_cast(runtime.faerie_fire_feral_id) then return false end
    if not utils.can_cast_target(runtime.faerie_fire_feral_id, me, target) then return false end

    if utils.cast_target(runtime.faerie_fire_feral_id, me, target) then
        mark_pending_cast(runtime.faerie_fire_feral_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Faerie Fire (Feral)")
        note_cast()
        return true
    end

    return false
end

local function try_tigers_fury(me)
    if not menu.use_tigers_fury:get_state() then return false end
    if not runtime.tigers_fury_id then return false end
    if utils.get_energy(me) > menu.tigers_fury_energy:get() then return false end
    if utils.has_buff(me, spells.BUFF_TIGERS_FURY) then return false end
    if is_pending_cast(runtime.tigers_fury_id) then return false end
    if not utils.can_cast_self(runtime.tigers_fury_id, me) then return false end

    if utils.cast_self_fast(runtime.tigers_fury_id, me) then
        mark_pending_cast(runtime.tigers_fury_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Tiger's Fury")
        note_cast()
        return true
    end

    return false
end

local function try_rip(me, target)
    if not menu.use_rip:get_state() then return false end
    if not runtime.rip_id then return false end
    if runtime.combo_points < menu.rip_combo_points:get() then return false end
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_RIP) > (menu.rip_refresh_seconds:get() * 1000) then return false end
    if is_pending_cast(runtime.rip_id) then return false end
    if not utils.can_cast_target(runtime.rip_id, me, target) then return false end

    if utils.cast_target(runtime.rip_id, me, target) then
        mark_pending_cast(runtime.rip_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Rip")
        note_cast()
        return true
    end

    return false
end

local function try_ferocious_bite(me, target, target_hp_pct)
    if not menu.use_ferocious_bite:get_state() then return false end
    if not runtime.ferocious_bite_id then return false end
    if runtime.combo_points < menu.bite_combo_points:get() then return false end
    if target_hp_pct > (menu.bite_hp_pct:get() / 100) then return false end
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_RIP) <= 3200 then return false end
    if is_pending_cast(runtime.ferocious_bite_id) then return false end
    if not utils.can_cast_target(runtime.ferocious_bite_id, me, target) then return false end

    if utils.cast_target(runtime.ferocious_bite_id, me, target) then
        mark_pending_cast(runtime.ferocious_bite_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Ferocious Bite")
        note_cast()
        return true
    end

    return false
end

local function try_mangle_cat(me, target)
    if not menu.use_mangle_cat:get_state() then return false end
    if not runtime.mangle_cat_id then return false end
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_MANGLE) > 1500 then return false end
    if is_pending_cast(runtime.mangle_cat_id) then return false end
    if not utils.can_cast_target(runtime.mangle_cat_id, me, target) then return false end

    if utils.cast_target(runtime.mangle_cat_id, me, target) then
        mark_pending_cast(runtime.mangle_cat_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Mangle (Cat)")
        note_cast()
        return true
    end

    return false
end

local function try_rake(me, target)
    if not menu.use_rake:get_state() then return false end
    if not runtime.rake_id then return false end
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_RAKE) > (menu.rake_refresh_seconds:get() * 1000) then return false end
    if is_pending_cast(runtime.rake_id) then return false end
    if not utils.can_cast_target(runtime.rake_id, me, target) then return false end

    if utils.cast_target(runtime.rake_id, me, target) then
        mark_pending_cast(runtime.rake_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Rake")
        note_cast()
        return true
    end

    return false
end

local function try_shred_or_filler(me, target)
    if menu.use_shred:get_state() and runtime.shred_id and runtime.combo_points < 5 then
        if not is_pending_cast(runtime.shred_id) and utils.can_cast_target(runtime.shred_id, me, target) then
            if utils.cast_target(runtime.shred_id, me, target) then
                mark_pending_cast(runtime.shred_id, PENDING_CAST_TIMEOUT_S)
                utils.log_debug(menu, "Shred")
                note_cast()
                return true
            end
        end
    end

    if runtime.mangle_cat_id and not is_pending_cast(runtime.mangle_cat_id) and utils.can_cast_target(runtime.mangle_cat_id, me, target) then
        if utils.cast_target(runtime.mangle_cat_id, me, target) then
            mark_pending_cast(runtime.mangle_cat_id, PENDING_CAST_TIMEOUT_S)
            utils.log_debug(menu, "Cat filler Mangle")
            note_cast()
            return true
        end
    end

    return false
end

local function do_cat_rotation(me, target)
    local target_hp_pct = utils.get_health_pct(target)

    if try_tigers_fury(me) then return true end
    if try_maim(me, target) then return true end
    if try_faerie_fire(me, target) then return true end
    if not utils.is_melee_target(me, target) then return false end
    if try_rip(me, target) then return true end
    if try_ferocious_bite(me, target, target_hp_pct) then return true end
    if try_mangle_cat(me, target) then return true end
    if try_rake(me, target) then return true end
    if try_shred_or_filler(me, target) then return true end

    return false
end

local function try_growl(me, target)
    if not menu.auto_growl:get_state() then return false end
    if not runtime.growl_id then return false end
    if utils.target_is_me(target, me) then return false end
    if is_pending_cast(runtime.growl_id) then return false end
    if not utils.can_cast_target(runtime.growl_id, me, target) then return false end

    if utils.cast_target_fast(runtime.growl_id, target) then
        mark_pending_cast(runtime.growl_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Growl")
        note_cast()
        return true
    end

    return false
end

local function try_frenzied_regeneration(me)
    if not menu.use_frenzied_regeneration:get_state() then return false end
    if not runtime.frenzied_regeneration_id then return false end
    if utils.get_health_pct(me) >= (menu.frenzied_regeneration_hp_pct:get() / 100) then return false end
    if utils.get_rage(me) < 40 then return false end
    if utils.has_buff(me, spells.BUFF_FRENZIED_REGENERATION) then return false end
    if is_pending_cast(runtime.frenzied_regeneration_id) then return false end
    if not utils.can_cast_self(runtime.frenzied_regeneration_id, me) then return false end

    if utils.cast_self_fast(runtime.frenzied_regeneration_id, me) then
        mark_pending_cast(runtime.frenzied_regeneration_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Frenzied Regeneration")
        note_cast()
        return true
    end

    return false
end

local function try_berserk(me, enemy_count, mode)
    if not menu.use_berserk:get_state() then return false end
    if not runtime.berserk_id then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_BERSERK) then return false end
    if mode == "solo" and enemy_count < menu.swipe_enemy_count:get() then return false end
    if is_pending_cast(runtime.berserk_id) then return false end
    if not utils.can_cast_self(runtime.berserk_id, me) then return false end

    if utils.cast_self_fast(runtime.berserk_id, me) then
        mark_pending_cast(runtime.berserk_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Berserk")
        note_cast()
        return true
    end

    return false
end

local function try_mangle_bear(me, target)
    if not menu.use_mangle_bear:get_state() then return false end
    if not runtime.mangle_bear_id then return false end
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_MANGLE) > 1500 then return false end
    if is_pending_cast(runtime.mangle_bear_id) then return false end
    if not utils.can_cast_target(runtime.mangle_bear_id, me, target) then return false end

    if utils.cast_target(runtime.mangle_bear_id, me, target) then
        mark_pending_cast(runtime.mangle_bear_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Mangle (Bear)")
        note_cast()
        return true
    end

    return false
end

local function try_swipe(me, enemy_count)
    if not menu.use_swipe:get_state() then return false end
    if not runtime.swipe_id then return false end
    if enemy_count < menu.swipe_enemy_count:get() then return false end
    if is_pending_cast(runtime.swipe_id) then return false end
    if not utils.can_cast_self(runtime.swipe_id, me) then return false end

    if utils.cast_self(runtime.swipe_id, me) then
        mark_pending_cast(runtime.swipe_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Swipe")
        note_cast()
        return true
    end

    return false
end

local function try_maul(me, target)
    if not menu.use_maul:get_state() then return false end
    if not runtime.maul_id then return false end
    if utils.get_rage(me) < menu.maul_min_rage:get() then return false end
    if is_pending_cast(runtime.maul_id) then return false end
    if not utils.can_cast_melee(runtime.maul_id, me) then return false end

    if utils.cast_target_fast(runtime.maul_id, target) then
        mark_pending_cast(runtime.maul_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Maul")
        note_cast()
        return true
    end

    return false
end


-- ─── Bear utility (v1.1) ──────────────────────────────────────────────────

local function try_demoralizing_roar(me, target)
    if not menu.use_demoralizing_roar or not menu.use_demoralizing_roar:get_state() then return false end
    if not runtime.demoralizing_roar_id then return false end
    if utils.has_debuff(target, spells.DEBUFF_DEMORALIZING_ROAR) then return false end
    if utils.cast_target(runtime.demoralizing_roar_id, target, "Demoralizing Roar") then
        utils.log_debug(menu, "Demoralizing Roar")
        return true
    end
    return false
end

-- ─── Cat utility (v1.1) ───────────────────────────────────────────────────

local function try_maim(me, target)
    if not menu.use_maim or not menu.use_maim:get_state() then return false end
    if not runtime.maim_id then return false end
    -- Maim as interrupt when Skull Bash is on CD
    if not interrupt_manager.should_interrupt(target) then return false end
    local cp = eax_utils.get_combo_points and eax_utils.get_combo_points(me) or 0
    if cp < 1 then return false end
    if utils.cast_target(runtime.maim_id, target, "Maim") then
        utils.log_debug(menu, "Maim (interrupt)")
        return true
    end
    return false
end


local function do_bear_rotation(me, target)
    local mode = get_effective_mode()
    local enemy_count = utils.enemy_count_in_radius(me, 8)

    if try_frenzied_regeneration(me) then return true end
    if try_growl(me, target) then return true end
    if try_faerie_fire(me, target) then return true end
    if not utils.is_melee_target(me, target) then return false end
    if try_berserk(me, enemy_count, mode) then return true end
    if try_demoralizing_roar(me, target) then return true end
    if try_mangle_bear(me, target) then return true end
    if try_swipe(me, enemy_count) then return true end
    if try_maul(me, target) then return true end

    if runtime.mangle_bear_id and not is_pending_cast(runtime.mangle_bear_id) and utils.can_cast_target(runtime.mangle_bear_id, me, target) then
        if utils.cast_target(runtime.mangle_bear_id, me, target) then
            mark_pending_cast(runtime.mangle_bear_id, PENDING_CAST_TIMEOUT_S)
            utils.log_debug(menu, "Bear filler Mangle")
            note_cast()
            return true
        end
    end

    return false
end

local function do_rotation(me, target)
    if not is_gcd_ready() then return false end

    ttd_tracker.update(target)
    local lane = get_requested_lane(me)
    runtime.current_lane = lane

    if try_shift_form(me, lane) then return true end
    if not is_valid_hostile_target(me, target) then return false end

    sync_combo_target(target)

    if lane == "cat" then
        return do_cat_rotation(me, target)
    end
    return do_bear_rotation(me, target)
end

core.register_on_update_callback(function()
    local me = core.object_manager.get_local_player()
    if not me then return end

    if utils.throttle("eaxdruidferal_mode_refresh", 5.0) then
        runtime.cached_mode = detect_mode(me)
    end

    handle_toggle()

    if not menu.enabled:get_state() then return end
    if me:is_dead() then return end

    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    local target = focus_target or me:get_target()

    -- Interrupt
    if target and target:is_valid() and target:is_enemy() and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "druid", utils) then
            return
        end
    end

    -- Racial CDs
    racial_manager.try_offensive(me)
    racial_manager.try_utility(me, target)

    -- Defensive abilities
    if defensive_manager.try_defensive(me, "druid", utils) then
        return
    end

    -- Self-emergency healing
    local self_threshold = eax_utils.get_self_heal_threshold(me, menu.frenzied_regeneration_hp_pct:get() / 100.0, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_frenzied_regeneration(me) then return end
    end

    do_rotation(me, target)
end)

core.register_on_render_menu_callback(function()
    menu.render()
end)

core.register_on_render_control_panel_callback(function()
    local control_panel_elements = {}
    local enable_toggle_key = menu.toggle_key:get_key_code()
    local enable_toggle_name = "[EAX Druid Feral] Enable (" .. key_helper:get_key_name(enable_toggle_key) .. ")"
    control_panel_utility:insert_toggle_(control_panel_elements, enable_toggle_name, menu.toggle_key)
    return control_panel_elements
end)

core.register_on_spell_cast_callback(function(data)
    if not data then return end

    local me = core.object_manager.get_local_player()
    if not me or not data.caster or not utils.same_unit(data.caster, me) then return end

    if data.spell_id == runtime.mangle_cat_id or data.spell_id == runtime.rake_id or data.spell_id == runtime.shred_id then
        runtime.combo_points = math.min(runtime.combo_points + 1, 5)
        return
    end

    if data.spell_id == runtime.rip_id or data.spell_id == runtime.ferocious_bite_id then
        runtime.combo_points = 0
        return
    end
end)

core.log("[EAX Druid Feral] Loaded v1.0.0")
