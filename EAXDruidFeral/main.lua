-- EAX Druid Feral | main.lua
-- Dual-lane cat and bear rotation logic with automatic form detection.

local menu = require("menu")
local enums = (function()
    local ok, e = pcall(require, "common/enums")
    return ok and e or nil
end)()
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")
local color     = require("color")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

---@type interrupt_manager
local interrupt_manager = require("interrupt_manager")
---@type ooc_manager
local ooc_manager = require("ooc_manager")
---@type leveling_manager
local leveling_manager = require("leveling_manager")
---@type creature_utils
local creature_utils = require("creature_utils")

---@type encounter_manager
local encounter_manager = require("encounter_manager")
-- Module-level encounter policy cache (updated each tick)
local enc = nil


---@type esp_renderer
local esp_renderer = require("esp_renderer")
esp_renderer.init("feral", "Druid Feral")

-- ── ESP Proc indicators ──────────────────────────────────────────────────────
-- Role-aware: cat procs only show in cat lane, bear/guardian procs in bear lane.
-- Combo points shown as a 5-pip bar, not a simple on/off.

-- Cat lane procs
esp_renderer.add_proc("Tiger's Fury", function()
    local me = core.object_manager.get_local_player()
    return me and utils.has_buff(me, spells.BUFF_TIGERS_FURY)
end, color.gold(240), color.cyan(60), "cat")

esp_renderer.add_proc("Clearcasting", function()
    local me = core.object_manager.get_local_player()
    return me and utils.has_buff(me, spells.BUFF_CLEARCASTING)
end, color.cyan(240), color.cyan(50), "cat")

esp_renderer.add_proc("Berserk", function()
    local me = core.object_manager.get_local_player()
    return me and utils.has_buff(me, spells.BUFF_BERSERK)
end, color.orange(240), color.cyan(60), "any")

-- Bear / Guardian lane procs
esp_renderer.add_proc("Survival Instincts", function()
    local me = core.object_manager.get_local_player()
    return me and utils.has_buff(me, spells.BUFF_SURVIVAL_INSTINCTS)
end, color.green(240), color.cyan(60), "bear")

esp_renderer.add_proc("Frenzied Regen", function()
    local me = core.object_manager.get_local_player()
    return me and utils.has_buff(me, spells.BUFF_FRENZIED_REGENERATION)
end, color.green(240), color.cyan(60), "bear")

esp_renderer.add_proc("Enrage", function()
    local me = core.object_manager.get_local_player()
    return me and utils.has_buff(me, spells.BUFF_ENRAGE)
end, color.orange(230), color.cyan(60), "bear")
---@type ttd_tracker
local ttd_tracker = require("ttd_tracker")
---@type racial_manager
local racial_manager = require("racial_manager")
---@type defensive_manager
local defensive_manager = require("defensive_manager")

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local runtime = {
    rebirth_id = nil,
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
    lacerate_id = nil,
    last_shift_at = 0,
    bear_charge_shift_at = 0,  -- timestamp of last bear-shift-for-charge; suppresses snap-back
    maim_id = nil,
    prev_toggle_state = false,
    last_cast_time = 0,
    cached_mode = "solo",
    current_lane = "cat",
    combo_points = 0,
    combo_target_key = nil,
    pending_casts = {},
    set_multiplier = 1.0,
    ooc_mark_of_the_wild_id = nil,
    remove_curse_id = nil,
    caster_form_cancel_id = nil,
    prowl_id = nil,
    pounce_id = nil,
    bash_id = nil,
    dash_id = nil,
    feral_charge_bear_id = nil,
    ravage_id = nil,
    travel_form_id = nil,
    abolish_poison_id = nil,
    natures_grasp_id = nil,
    barkskin_id = nil,
    claw_id = nil,
    innervate_id = nil,
    cyclone_id = nil,
    entangling_roots_id = nil,
    war_stomp_id = nil,
    survival_instincts_id = nil,
    enrage_id = nil,
    challenging_roar_id = nil,
    healing_touch_id = nil,
}

local GCD_CAST_INTERVAL = 1.0  -- TBC GCD
local PENDING_CAST_TIMEOUT_S = 2.5
local FAST_PENDING_CAST_TIMEOUT_S = 0.75

-- Wire up HUD context now that runtime exists
esp_renderer.set_context(spells, utils, runtime)
-- Energy pooling: at CP=4, wait for this much energy before the final Shred
-- so you can chain Shred → finisher without an energy gap.
local ENERGY_POOL_FOR_SHRED = 75

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
    runtime.rebirth_id  = utils.resolve_spell_id(spells.REBIRTH)
    runtime.berserk_id            = utils.resolve_spell_id(spells.BERSERK)
    runtime.demoralizing_roar_id   = utils.resolve_spell_id(spells.DEMORALIZING_ROAR)
    runtime.lacerate_id             = utils.resolve_spell_id(spells.LACERATE)
    runtime.maim_id                = utils.resolve_spell_id(spells.MAIM)
    runtime.remove_curse_id        = utils.resolve_spell_id(spells.REMOVE_CURSE)
    runtime.prowl_id               = utils.resolve_spell_id(spells.PROWL)
    runtime.pounce_id              = utils.resolve_spell_id(spells.POUNCE)
    runtime.bash_id                = utils.resolve_spell_id(spells.BASH)
    runtime.dash_id                = utils.resolve_spell_id(spells.DASH)
    runtime.feral_charge_bear_id   = utils.resolve_spell_id(spells.FERAL_CHARGE_BEAR)
    runtime.ravage_id              = utils.resolve_spell_id(spells.RAVAGE)
    runtime.travel_form_id         = utils.resolve_spell_id(spells.TRAVEL_FORM)
    runtime.abolish_poison_id      = utils.resolve_spell_id(spells.ABOLISH_POISON)
    runtime.natures_grasp_id       = utils.resolve_spell_id(spells.NATURES_GRASP)
    runtime.barkskin_id            = utils.resolve_spell_id(spells.BARKSKIN)
    runtime.claw_id                = utils.resolve_spell_id(spells.CLAW)
    runtime.innervate_id           = utils.resolve_spell_id(spells.INNERVATE)
    runtime.ooc_mark_of_the_wild_id = utils.resolve_spell_id(spells.MARK_OF_THE_WILD)
    runtime.cyclone_id             = utils.resolve_spell_id(spells.CYCLONE)
    runtime.entangling_roots_id    = utils.resolve_spell_id(spells.ENTANGLING_ROOTS)
    runtime.war_stomp_id           = utils.resolve_spell_id(spells.WAR_STOMP)
    runtime.survival_instincts_id  = utils.resolve_spell_id(spells.SURVIVAL_INSTINCTS)
    runtime.enrage_id              = utils.resolve_spell_id(spells.ENRAGE)
    runtime.challenging_roar_id    = utils.resolve_spell_id(spells.CHALLENGING_ROAR)
    runtime.healing_touch_id       = utils.resolve_spell_id(spells.HEALING_TOUCH)
end

local function log_resolved_spells()
    core.log("[EAX Druid Feral] Resolved: CatMangle=" .. tostring(runtime.mangle_cat_id)
        .. " Shred=" .. tostring(runtime.shred_id)
        .. " Rip=" .. tostring(runtime.rip_id)
        .. " BearMangle=" .. tostring(runtime.mangle_bear_id)
        .. " Swipe=" .. tostring(runtime.swipe_id)
        .. " Growl=" .. tostring(runtime.growl_id))
end

local function update_set_bonus(me)
    local nordrassil_mult         = utils.get_set_multiplier(me, "Nordrassil")
    local nordrassil_harness_mult = utils.get_set_multiplier(me, "NordrassilHarness")
    local malorne_mult            = utils.get_set_multiplier(me, "Malorne")
    local malorne_harness_mult    = utils.get_set_multiplier(me, "MalorneHarness")
    local nordrassil_battle_mult  = utils.get_set_multiplier(me, "NordrassilBattlegear")
    local thunderheart_mult       = utils.get_set_multiplier(me, "ThunderhearBattlegear")
    runtime.set_multiplier = math.max(
        nordrassil_mult, nordrassil_harness_mult, malorne_mult,
        malorne_harness_mult, nordrassil_battle_mult, thunderheart_mult)
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

-- Combo point sync.
-- Primary: me:get_power(4) — raw core API, combo points power type index 4.
-- get_combo_points_target() is used only for target validation, NOT for reading the count.
-- Calling get_power() on cp_obj (the mob) always returns 0 — CPs live on the player.
-- Fallback: me:combo_points_current() via izi_sdk if core API returns nothing.
-- Cast-callback counter remains active as last resort.
local function sync_combo_target(me, target)
    -- Read combo points from ME (the player) using the native game_object API.
    -- Confirmed working: me:get_power(enums.power_type.COMBOPOINTS_TBC)
    -- Key insight: must call on the PLAYER, not on cp_obj (the target).

    -- Method 1: native game_object API, TBC-specific power type
    local ok1, v1 = pcall(function() return me:get_power(enums.power_type.COMBOPOINTS_TBC) end)
    if ok1 and type(v1) == "number" and v1 > 0 then
        runtime.combo_points = v1
        return
    end

    -- Method 2: native game_object API, retail enum fallback (COMBOPOINTS = 4)
    local ok2, v2 = pcall(function() return me:get_power(enums.power_type.COMBOPOINTS) end)
    if ok2 and type(v2) == "number" and v2 > 0 then
        runtime.combo_points = v2
        return
    end

    -- All methods returned 0 or failed, cast-callback counter stays active
end


local function get_requested_lane(me)
    local lane_idx = menu.lane:get()
    if lane_idx == 2 then return "cat" end
    if lane_idx == 3 then return "bear" end
    if lane_idx == 4 then return "guardian" end

    -- Mana fallback: if mana is below the shift floor and we're already in
    -- bear form, stay in bear/guardian and use rage-based abilities.
    local mana_floor = menu.shift_mana_floor:get() / 100
    if mana_floor > 0 and utils.get_mana_pct(me) < mana_floor then
        if utils.has_buff(me, spells.BUFF_BEAR_FORM) then
            -- Preserve guardian lane if that's what was selected
            return lane_idx == 4 and "guardian" or "bear"
        end
        return "cat"
    end

    -- Auto mode: role/mode decides the lane, not the current form.
    local mode = get_effective_mode()
    if mode == "solo" then return "cat" end
    local ok_r, role = pcall(function() return me:get_group_role() end)
    if not ok_r then role = 0 end
    if role == 2 then return "guardian" end  -- tank role → guardian
    return "cat"
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

    -- Mana floor: don't spend mana on form shifts when running low.
    -- Stay in the current form and use its rotation instead.
    local mana_floor = menu.shift_mana_floor:get() / 100
    if mana_floor > 0 and utils.get_mana_pct(me) < mana_floor then return false end

    local target = me:get_target()
    local target_valid = target and target:is_valid() and not target:is_dead() and me:can_attack(target)
    local in_melee = target_valid and utils.is_melee_target(me, target)

    -- Break travel form immediately when a hostile target is explicitly selected
    -- and we're ready to engage — don't wait for is_in_combat().
    -- Use me:get_target() directly (player's actual selected target) rather
    -- than find_best_target so we don't break form just because a mob exists nearby.
    local in_travel = utils.has_buff(me, spells.BUFF_TRAVEL_FORM)
    local explicit_target = me:get_target()
    local explicit_hostile = explicit_target
        and explicit_target:is_valid()
        and not explicit_target:is_dead()
        and me:can_attack(explicit_target)
    if in_travel and explicit_hostile then
        -- Fall through to normal shift logic below
    elseif not me:is_in_combat() then
        return false
    end

    if lane == "cat" then
        -- Don't shift to cat while out of melee range and charge is available —
        -- bear needs to close the gap first via Feral Charge.
        -- Also suppress snap-back for 2s after we committed a bear shift for
        -- a charge — avoids wasting a GCD if range flickers by one tick.
        local charge_shift_hold = 2.0
        if (core.time() - runtime.bear_charge_shift_at) < charge_shift_hold then
            return false
        end
        if runtime.feral_charge_bear_id and target_valid and not in_melee then
            -- Only hold the cat shift if charge is actually in range to fire
            if core.spell_book.is_spell_in_range(runtime.feral_charge_bear_id, target, me) then
                return false
            end
        end
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

    -- Bear / Guardian lane: shift to bear form
    -- For guardian (tank), skip the charge-range check — tank should always
    -- be in bear form regardless of distance.
    if lane == "bear" then
        if target_valid and not in_melee then
            if runtime.feral_charge_bear_id then
                if not core.spell_book.is_spell_in_range(runtime.feral_charge_bear_id, target, me) then
                    return false  -- too far even for charge — stay in current form
                end
            end
        end
    end
    -- Guardian: always shift to bear, no range restriction

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
    -- Never break stealth with Faerie Fire
    if utils.has_buff(me, spells.BUFF_PROWL) then return false end
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_FAERIE_FIRE) >= 3000 then return false end
    if is_pending_cast(runtime.faerie_fire_feral_id) then return false end
    if not utils.can_cast_hostile(runtime.faerie_fire_feral_id, me, target) then return false end

    if utils.cast_target(runtime.faerie_fire_feral_id, target) then
        mark_pending_cast(runtime.faerie_fire_feral_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Faerie Fire (Feral)")
        note_cast()
        return true
    end

    return false
end

local function try_tigers_fury(me, target)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_tigers_fury:get_state() then return false end
    if not runtime.tigers_fury_id then return false end
    if utils.get_energy(me) > menu.tigers_fury_energy:get() then return false end
    if utils.has_buff(me, spells.BUFF_TIGERS_FURY) then return false end
    -- Never fire at high CP when a finisher is ready — the GCD is better spent
    -- on Rip or Ferocious Bite. Tiger's Fury is a builder-phase cooldown.
    if target then
        local rip_ready = menu.use_rip:get_state()
            and not creature_utils.is_bleed_immune(target)
            and runtime.combo_points >= menu.rip_combo_points:get()
        local bite_ready = menu.use_ferocious_bite:get_state()
            and runtime.combo_points >= 5
        if rip_ready or bite_ready then return false end
    end
    -- Also avoid TF when at 4 CP and about to get the final builder —
    -- don't waste it on a Fury proc that gets immediately capped by a finisher
    if runtime.combo_points >= 4 then return false end
    if is_pending_cast(runtime.tigers_fury_id) then return false end
    if not utils.can_cast_self(runtime.tigers_fury_id, me) then return false end

    if utils.cast_self_fast(runtime.tigers_fury_id, me) then
        mark_pending_cast(runtime.tigers_fury_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Tiger's Fury (CP=" .. runtime.combo_points .. ")")
        note_cast()
        return true
    end

    return false
end


local function try_rip(me, target)
    if not menu.use_rip:get_state() then return false end
    if creature_utils.is_bleed_immune(target) then return false end
    local ttd = ttd_tracker.get(target)
    if ttd > 0 and ttd < 12 then return false end
    if not runtime.rip_id then return false end
    if runtime.combo_points < menu.rip_combo_points:get() then return false end
    local rip_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_RIP)
    if rip_rem > (menu.rip_refresh_seconds:get() * 1000) then return false end
    -- Snapshotting: if Rip isn't active yet (or is almost gone) and we have
    -- Tiger's Fury or Berserk available but not active, hold briefly.
    -- Only delay if the buff is about to come off cooldown (CD < 2s).
    if rip_rem <= 0 then
        local has_tf     = utils.has_buff(me, spells.BUFF_TIGERS_FURY)
        local has_berserk = utils.has_buff(me, spells.BUFF_BERSERK)
        if not has_tf and not has_berserk then
            local tf_cd = runtime.tigers_fury_id and core.spell_book.get_spell_cooldown(runtime.tigers_fury_id) or 99
            if tf_cd > 0 and tf_cd < 2.0 then
                return false  -- TF incoming in <2s, wait to snapshot
            end
        end
    end
    if is_pending_cast(runtime.rip_id) then return false end
    if not utils.can_cast_hostile(runtime.rip_id, me, target) then return false end

    if utils.cast_target(runtime.rip_id, target) then
        mark_pending_cast(runtime.rip_id, PENDING_CAST_TIMEOUT_S)
        local snap = utils.has_buff(me, spells.BUFF_TIGERS_FURY) and " [TF]"
                  or utils.has_buff(me, spells.BUFF_BERSERK) and " [Berserk]" or ""
        utils.log_debug(menu, "Rip" .. snap)
        note_cast()
        return true
    end

    return false
end

local function try_ferocious_bite(me, target, target_hp_pct)
    if not menu.use_ferocious_bite:get_state() then return false end
    if not runtime.ferocious_bite_id then return false end
    if runtime.combo_points < 1 then return false end

    local killshot_threshold = menu.bite_killshot_hp_pct:get() / 100

    if target_hp_pct <= killshot_threshold then
        -- Killshot mode: target is low enough to finish off — dump any CPs now
        -- Skip the Rip check entirely; the mob is dying anyway
    else
        -- Normal mode: only spend CPs at max (5) as a finisher
        if runtime.combo_points < 5 then return false end
        -- If Rip is active but expiring, let try_rip refresh it first
        local rip_relevant = menu.use_rip:get_state() and not creature_utils.is_bleed_immune(target)
        if rip_relevant then
            local rip_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_RIP)
            if rip_rem > 0 and rip_rem <= 3200 then return false end
        end
    end

    if is_pending_cast(runtime.ferocious_bite_id) then return false end
    if not utils.can_cast_hostile(runtime.ferocious_bite_id, me, target) then return false end

    if utils.cast_target(runtime.ferocious_bite_id, target) then
        mark_pending_cast(runtime.ferocious_bite_id, PENDING_CAST_TIMEOUT_S)
        local mode = target_hp_pct <= killshot_threshold and "killshot" or "finisher"
        utils.log_debug(menu, "Ferocious Bite (" .. mode .. " CP=" .. runtime.combo_points .. ")")
        note_cast()
        return true
    end

    return false
end

-- Safe check: only skip mangle if we can CONFIRM another player applied it.
-- The built-in debuff_applied_by_other returns true when caster info is
-- missing (common on private servers), causing false positives that suppress
-- our own Mangle indefinitely. This version only returns true when the caster
-- field is present and verifiably not us.
local function mangle_debuff_confirmed_by_other(unit, id_table, me)
    if not unit or not unit:is_valid() then return false end
    local ok, cache = pcall(function()
        return buff_manager:get_debuff_cache(unit, 100)
    end)
    if not ok or not cache then return false end
    local id_set = {}
    for _, id in ipairs(id_table) do id_set[id] = true end
    for _, aura in ipairs(cache) do
        if aura.is_active and id_set[aura.buff_id] then
            local remaining = aura.remaining or 0
            if remaining >= 4000 then
                local caster = aura.caster
                if caster and caster:is_valid() and not utils.same_unit(caster, me) then
                    return true
                end
            end
        end
    end
    return false
end

local function try_mangle_cat(me, target)
    if not menu.use_mangle_cat:get_state() then return false end
    if not runtime.mangle_cat_id then return false end
    local mangle_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_MANGLE)
    -- During Berserk, Mangle CD is reduced — refresh aggressively
    local refresh_threshold = utils.has_buff(me, spells.BUFF_BERSERK) and 3000 or 1500
    if mangle_rem > refresh_threshold then return false end
    if mangle_debuff_confirmed_by_other(target, spells.DEBUFF_MANGLE, me) then return false end
    if mangle_debuff_confirmed_by_other(target, spells.DEBUFF_TRAUMA, me) then return false end
    if is_pending_cast(runtime.mangle_cat_id) then return false end
    if not utils.can_cast_hostile(runtime.mangle_cat_id, me, target) then return false end

    if utils.cast_target(runtime.mangle_cat_id, target) then
        mark_pending_cast(runtime.mangle_cat_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Mangle (Cat)")
        note_cast()
        return true
    end

    return false
end


-- --- Rake trick improvement (v1.4) ---------------------------------------
-- From tbc/ feral/rotation.go: use Rake when energy is 35-55 and Mangle
-- is unavailable, rather than waiting for the next energy tick.

local RAKE_TRICK_MIN = 35
local RAKE_TRICK_MAX = 55


local SHIFT_ENERGY_THRESHOLD = 30
local SHIFT_MIN_INTERVAL_S   = 1.2
local WOLFSHEAD_ITEM_ID      = 8345

local function has_wolfshead(me)
    local ok, slot = pcall(function() return me:get_item_at_inventory_slot(1) end)
    if ok and slot and slot.object then
        local ok2, id = pcall(function() return slot.object:get_item_id() end)
        return ok2 and id == WOLFSHEAD_ITEM_ID
    end
    return false
end

-- --- Powershifting ------------------------------------------------------------
-- core.input.quick_cat replicates `/cast !Cat Form` behaviour:
-- casts Cat Form while already in Cat Form WITHOUT dropping the form first.
-- This is the classic TBC powershift trick - fires a zero-downtime shift that
-- triggers the energy regen from Wolfshead Helm / Natural Shapeshifter talent.
-- Only works on private/legacy servers (not retail).
-- Falls back to a normal form cast on servers that haven't patched this in.

local function try_powershift(me)
    if not menu.use_powershift or not menu.use_powershift:get_state() then return false end
    if not utils.has_buff(me, spells.BUFF_CAT_FORM) then return false end
    local energy = utils.get_energy and utils.get_energy(me) or 100
    local threshold = has_wolfshead(me) and SHIFT_ENERGY_THRESHOLD or 15
    if energy >= threshold then return false end
    local now = core.time()
    local min_i = has_wolfshead(me) and SHIFT_MIN_INTERVAL_S or 2.0
    if (now - runtime.last_shift_at) < min_i then return false end

    -- Use core.input.quick_cat if available - this is the PS implementation of
    -- `/cast !Cat Form`: casts Cat Form in-form without cancelling the buff first.
    -- It triggers the Wolfshead Helm energy restore and any on-shift procs without
    -- the usual brief human/caster form window, giving zero-downtime powershifting.
    local ok_qc, qc_result = pcall(function()
        return core.input.quick_cat()
    end)
    if ok_qc and qc_result then
        runtime.last_shift_at = now
        utils.log_debug(menu, "Powershift via quick_cat (energy=" .. tostring(math.floor(energy)) .. ")")
        return true
    end

    -- Fallback: normal cast_self (will briefly leave cat form on servers
    -- that don't support quick_cat, but still triggers Wolfshead on some cores)
    local cat_id = utils.resolve_spell_id(spells.CAT_FORM)
    if not cat_id or not utils.can_cast_self(cat_id, me) then return false end
    utils.cast_self(cat_id, me)
    runtime.last_shift_at = now
    utils.log_debug(menu, "Powershift via cast_self fallback (energy=" .. tostring(math.floor(energy)) .. ")")
    return true
end


local function try_rake_trick(me, target)
    -- Energy-sink Rake: only when Rake is absent AND energy is in the sweet
    -- spot AND we don't have enough CPs for a finisher yet.
    -- Prevents burning energy at CP=4/5 when a finisher should fire instead.
    if not menu.use_rake:get_state() then return false end
    if not runtime.rake_id then return false end
    if utils.has_debuff(target, spells.DEBUFF_RAKE) then return false end
    -- Don't rake-trick when a finisher is imminent
    if runtime.combo_points >= 4 then return false end
    local energy = utils.get_energy and utils.get_energy(me) or 0
    if energy < RAKE_TRICK_MIN or energy > RAKE_TRICK_MAX then return false end
    if is_pending_cast(runtime.rake_id) then return false end
    if not utils.can_cast_hostile(runtime.rake_id, me, target) then return false end
    if utils.cast_target(runtime.rake_id, target, "Rake trick") then
        utils.log_debug(menu, "Rake trick (energy sink)")
        mark_pending_cast(runtime.rake_id, 1.5)
        note_cast()
        return true
    end
    return false
end

local function try_rake(me, target)
    if not menu.use_rake:get_state() then return false end
    if creature_utils.is_bleed_immune(target) then return false end
    if not runtime.rake_id then return false end
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_RAKE) > (menu.rake_refresh_seconds:get() * 1000) then return false end
    if is_pending_cast(runtime.rake_id) then return false end
    -- Snapshotting: hold Rake briefly if Tiger's Fury is about to come off CD
    local rake_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_RAKE)
    if rake_rem <= 0 then
        local has_tf = utils.has_buff(me, spells.BUFF_TIGERS_FURY)
        if not has_tf then
            local tf_cd = runtime.tigers_fury_id and core.spell_book.get_spell_cooldown(runtime.tigers_fury_id) or 99
            if tf_cd > 0 and tf_cd < 2.0 then
                return false  -- TF incoming in <2s, wait to snapshot
            end
        end
    end
    if not utils.can_cast_hostile(runtime.rake_id, me, target) then return false end

    if utils.cast_target(runtime.rake_id, target) then
        mark_pending_cast(runtime.rake_id, PENDING_CAST_TIMEOUT_S)
        local snap = utils.has_buff(me, spells.BUFF_TIGERS_FURY) and " [TF]"
                  or utils.has_buff(me, spells.BUFF_BERSERK) and " [Berserk]" or ""
        utils.log_debug(menu, "Rake" .. snap)
        note_cast()
        return true
    end

    return false
end

local try_claw  -- forward declaration (defined after try_shred_or_filler)

local function try_shred_or_filler(me, target)
    local cp = runtime.combo_points
    local energy = utils.get_energy(me)

    if menu.use_shred:get_state() and runtime.shred_id and cp < 5 then
        if utils.is_behind_target(me, target) then
            -- Energy pooling: if we're one builder from a finisher, wait for
            -- enough energy to chain Shred → finisher without an energy gap.
            if cp >= 4 and energy < ENERGY_POOL_FOR_SHRED then
                return false  -- pool energy for the final Shred
            end
            if not is_pending_cast(runtime.shred_id) and utils.can_cast_hostile(runtime.shred_id, me, target) then
                if utils.cast_target(runtime.shred_id, target) then
                    mark_pending_cast(runtime.shred_id, PENDING_CAST_TIMEOUT_S)
                    utils.log_debug(menu, "Shred")
                    note_cast()
                    return true
                end
            end
        end
        -- Not behind: fall through to Mangle/Claw builders
    end

    if runtime.mangle_cat_id and menu.use_mangle_cat:get_state()
       and not is_pending_cast(runtime.mangle_cat_id)
       and not mangle_debuff_confirmed_by_other(target, spells.DEBUFF_MANGLE, me)
       and not mangle_debuff_confirmed_by_other(target, spells.DEBUFF_TRAUMA, me)
       and utils.can_cast_hostile(runtime.mangle_cat_id, me, target) then
        if utils.cast_target(runtime.mangle_cat_id, target) then
            mark_pending_cast(runtime.mangle_cat_id, PENDING_CAST_TIMEOUT_S)
            utils.log_debug(menu, "Cat filler Mangle")
            note_cast()
            return true
        end
    end

    -- Claw: last resort builder when Shred blocked and Mangle on CD
    if try_claw(me, target) then return true end

    return false
end
local function try_maim(me, target)
    if not menu.use_maim or not menu.use_maim:get_state() then return false end
    if not runtime.maim_id then return false end
    -- Maim is a CP finisher that happens to stun/interrupt.
    -- NEVER drain low CPs on an interrupt — only cast when at max CPs (5)
    -- AND the target is casting something that needs to be stopped.
    -- This prevents Maim from starving Rip / Ferocious Bite.
    if runtime.combo_points < 5 then return false end
    if not interrupt_manager.should_interrupt(target) then return false end
    -- If Rip is the preferred finisher, let Rip go instead
    local rip_ready = menu.use_rip:get_state()
        and not creature_utils.is_bleed_immune(target)
        and runtime.combo_points >= menu.rip_combo_points:get()
        and utils.get_debuff_remaining_ms(target, spells.DEBUFF_RIP) <= (menu.rip_refresh_seconds:get() * 1000)
    if rip_ready then return false end
    if not utils.can_cast_hostile(runtime.maim_id, me, target) then return false end
    if utils.cast_target(runtime.maim_id, target, "Maim") then
        utils.log_debug(menu, "Maim (CP5 interrupt)")
        note_cast()
        return true
    end
    return false
end

-- --- Root escape (TBC: shifting form cancels roots) -----------------------
-- Shifting out of animal form while rooted breaks the root.
-- try_shift_form will re-enter the correct form on the next tick.

local function try_root_escape(me)
    if not menu.use_root_escape:get_state() then return false end
    -- Only act if actually rooted
    if not me:is_rooted(400) then return false end
    -- Only if in an animal form (cat or bear)
    local in_animal = utils.has_buff(me, spells.BUFF_CAT_FORM)
                   or utils.has_buff(me, spells.BUFF_BEAR_FORM)
    if not in_animal then return false end
    -- Cancel form by cancelling the aura (standard TBC technique)
    -- We call cast_self on an invalid form to trigger cancellation,
    -- or use the bare CancelShapeshiftForm if exposed
    local ok = pcall(function()
        if CancelShapeshiftForm then CancelShapeshiftForm() end
    end)
    if not ok then
        -- Fallback: cast self without buff active check to trigger drop
        if runtime.cat_form_id and utils.has_buff(me, spells.BUFF_CAT_FORM) then
            core.spell_book.cast_spell(runtime.cat_form_id)
        elseif runtime.bear_form_id then
            core.spell_book.cast_spell(runtime.bear_form_id)
        end
    end
    utils.log_debug(menu, "Root escape: shifted out of form")
    note_cast()
    return true
end

local function try_remove_curse_feral(me)
    if not menu.use_remove_curse:get_state() then return false end
    if not runtime.remove_curse_id then return false end
    -- Only castable in caster form
    if utils.has_buff(me, spells.BUFF_CAT_FORM) or utils.has_buff(me, spells.BUFF_BEAR_FORM) then return false end
    if is_pending_cast(runtime.remove_curse_id) then return false end
    -- Scan self and party for curses
    local units = { me }
    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead()
           and obj:is_party_member() then
            units[#units + 1] = obj
        end
    end
    for _, unit in ipairs(units) do
        local cache = buff_manager:get_debuff_cache(unit, 100)
        for _, aura in ipairs(cache) do
            if aura.is_active and aura.buff_type == enums.buff_type.CURSE then
                if utils.can_cast_hostile(runtime.remove_curse_id, me, unit) then
                    if utils.cast_target(runtime.remove_curse_id, unit) then
                        mark_pending_cast(runtime.remove_curse_id, PENDING_CAST_TIMEOUT_S)
                        utils.log_debug(menu, "Remove Curse -> " .. (unit.get_name and unit:get_name() or "ally"))
                        note_cast()
                        return true
                    end
                end
                break
            end
        end
    end
    return false
end


-- ── Prowl ─────────────────────────────────────────────────────────────────
-- ── OOC Self-Heal ─────────────────────────────────────────────────────────
-- When out of combat and HP is low, shift to caster form and cast Healing
-- Touch to top up. Shifts back into the appropriate form on next tick via
-- try_shift_form. Only fires when not already casting and not eating/drinking.
local function try_ooc_self_heal(me)
    if not menu.use_ooc_self_heal:get_state() then return false end
    if not runtime.healing_touch_id then return false end
    if me:is_in_combat() then return false end
    local hp = me:get_health_percentage() / 100
    if hp >= (menu.ooc_self_heal_hp_pct:get() / 100) then return false end
    -- Don't burn mana healing minor scratches — only heal if mana is healthy
    -- enough to afford it. Below 50% mana, save it for the next fight.
    local ok_mp, cur_mp = pcall(function()
        return me:get_power(0) / me:get_max_power(0)
    end)
    if ok_mp and type(cur_mp) == "number" and cur_mp < 0.50 then return false end
    -- Must be in caster form to cast — if in cat/bear, shift out first
    local in_animal = utils.has_buff(me, spells.BUFF_CAT_FORM)
                   or utils.has_buff(me, spells.BUFF_BEAR_FORM)
    if in_animal then
        -- Cancel form to enable healing — try_shift_form will re-enter on next tick
        local ok = pcall(function()
            if CancelShapeshiftForm then CancelShapeshiftForm() end
        end)
        if not ok then
            if runtime.cat_form_id and utils.has_buff(me, spells.BUFF_CAT_FORM) then
                core.spell_book.cast_spell(runtime.cat_form_id)
            elseif runtime.bear_form_id then
                core.spell_book.cast_spell(runtime.bear_form_id)
            end
        end
        utils.log_debug(menu, "OOC self-heal: dropping form to cast")
        return false  -- cast next tick once in caster form
    end
    -- Check mana floor — don't heal if we'll be left with nothing
    local mana_floor = menu.shift_mana_floor:get() / 100
    if mana_floor > 0 and utils.get_mana_pct(me) < mana_floor then return false end
    if is_pending_cast(runtime.healing_touch_id) then return false end
    if not utils.can_cast_self(runtime.healing_touch_id, me) then return false end
    if utils.cast_self(runtime.healing_touch_id, me) then
        mark_pending_cast(runtime.healing_touch_id, 3.0)
        utils.log_debug(menu, "OOC Healing Touch (hp=" .. string.format("%.0f%%", hp * 100) .. ")")
        note_cast()
        return true
    end
    return false
end

local function try_prowl(me)
    if not menu.use_prowl:get_state() then return false end
    if not runtime.prowl_id then return false end
    if me:is_in_combat() then return false end
    -- Don't prowl if we still have combo points — means combat just ended or
    -- the server briefly dropped the combat flag between hits
    if runtime.combo_points > 0 then return false end
    -- Don't prowl if any enemy is within aggro range (would break immediately)
    if utils.enemy_count_in_radius(me, 10) > 0 then return false end
    if utils.has_buff(me, spells.BUFF_PROWL) then return false end
    if not utils.has_buff(me, spells.BUFF_CAT_FORM) then return false end
    if utils.can_cast_self(runtime.prowl_id, me) then
        if utils.cast_self(runtime.prowl_id, me) then
            mark_pending_cast(runtime.prowl_id, PENDING_CAST_TIMEOUT_S)
            utils.log_debug(menu, "Prowl")
            note_cast()
            return true
        end
    end
    return false
end

-- ── Pounce (stealth opener) ────────────────────────────────────────────────
local function try_pounce(me, target)
    if not menu.use_pounce:get_state() then return false end
    if not runtime.pounce_id then return false end
    if not utils.has_buff(me, spells.BUFF_PROWL) then return false end
    if is_pending_cast(runtime.pounce_id) then return false end
    if not utils.can_cast_hostile(runtime.pounce_id, me, target) then return false end
    if utils.cast_target(runtime.pounce_id, target) then
        mark_pending_cast(runtime.pounce_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Pounce (stealth opener)")
        note_cast()
        return true
    end
    return false
end

-- ── Ravage (stealth, from front unlike Shred) ─────────────────────────────
local function try_ravage(me, target)
    if not menu.use_ravage:get_state() then return false end
    if not runtime.ravage_id then return false end
    if not utils.has_buff(me, spells.BUFF_PROWL) then return false end
    if not utils.can_cast_hostile(runtime.ravage_id, me, target) then return false end
    if utils.cast_target(runtime.ravage_id, target) then
        utils.log_debug(menu, "Ravage (stealth)")
        note_cast()
        return true
    end
    return false
end

-- ── Feral Charge (Cat) ────────────────────────────────────────────────────
local function try_dash(me)
    -- Dash: cat form sprint to close gap OOC or when target is far
    if not menu.use_feral_charge:get_state() then return false end
    if not runtime.dash_id then return false end
    if not utils.has_buff(me, spells.BUFF_CAT_FORM) then return false end
    if utils.has_buff(me, spells.BUFF_DASH) then return false end
    if not utils.can_cast_self(runtime.dash_id, me) then return false end
    if utils.cast_self(runtime.dash_id, me) then
        utils.log_debug(menu, "Dash")
        note_cast()
        return true
    end
    return false
end

local function try_feral_charge_bear(me, target)
    if not menu.use_feral_charge:get_state() then return false end
    if not runtime.feral_charge_bear_id then return false end
    -- Never shift to bear OOC just to charge — only gap-close once already fighting
    if not me:is_in_combat() then return false end
    if utils.is_melee_target(me, target) then return false end
    -- Only shift to bear / attempt charge if the target is actually within
    -- Feral Charge range. If they're too far away, don't waste the form shift.
    if not core.spell_book.is_spell_in_range(runtime.feral_charge_bear_id, target, me) then
        return false
    end
    -- Must be in bear form to cast it
    if not utils.has_buff(me, spells.BUFF_BEAR_FORM) then
        local mana_floor = menu.shift_mana_floor:get() / 100
        if mana_floor > 0 and utils.get_mana_pct(me) < mana_floor then return false end
        if menu.auto_form:get_state() and runtime.bear_form_id then
            if utils.can_cast_self(runtime.bear_form_id, me) then
                utils.cast_self(runtime.bear_form_id, me)
                runtime.bear_charge_shift_at = core.time()
                utils.log_debug(menu, "Shifting Bear for Feral Charge")
            end
        end
        return false
    end
    if not utils.can_cast_hostile(runtime.feral_charge_bear_id, me, target) then return false end
    if utils.cast_target(runtime.feral_charge_bear_id, target) then
        utils.log_debug(menu, "Feral Charge (Bear)")
        note_cast()
        return true
    end
    return false
end

-- ── Bash (Bear stun) ──────────────────────────────────────────────────────
local function try_bash(me, target)
    if not menu.use_bash:get_state() then return false end
    if not runtime.bash_id then return false end
    if not utils.has_buff(me, spells.BUFF_BEAR_FORM) then return false end
    if utils.has_debuff(target, spells.DEBUFF_BASH) then return false end
    if not utils.can_cast_hostile(runtime.bash_id, me, target) then return false end
    if utils.cast_target(runtime.bash_id, target) then
        utils.log_debug(menu, "Bash (stun)")
        note_cast()
        return true
    end
    return false
end


-- ── Travel Form (OOC movement) ─────────────────────────────────────────────

-- ── Innervate (OOC mana restore) ───────────────────────────────────────────
local function try_innervate(me)
    if not menu.use_innervate:get_state() then return false end
    if not runtime.innervate_id then return false end
    if me:is_in_combat() then return false end
    local mana_pct = utils.get_health_pct(me)  -- reuse get_mana_pct if available
    local ok, mp = pcall(function()
        return me:get_power(0) / me:get_max_power(0)
    end)
    if ok and type(mp) == "number" and mp > (menu.innervate_mana_pct:get() / 100.0) then return false end
    if not utils.can_cast_self(runtime.innervate_id, me) then return false end
    if utils.cast_self(runtime.innervate_id, me) then
        utils.log_debug(menu, "Innervate (OOC mana restore)")
        note_cast()
        return true
    end
    return false
end

local function try_travel_form(me)
    if not menu.use_travel_form:get_state() then return false end
    if not runtime.travel_form_id then return false end
    if me:is_in_combat() then return false end
    if me:is_mounted() then return false end
    if utils.has_buff(me, spells.BUFF_TRAVEL_FORM) then return false end
    -- Never fight prowl — if stealthed or prowl just cast, back off entirely
    if utils.has_buff(me, spells.BUFF_PROWL) then return false end
    if runtime.prowl_id and is_pending_cast(runtime.prowl_id) then return false end
    -- Don't shift to travel form if there's a hostile target selected — combat imminent
    local sel = me:get_target()
    if sel and sel:is_valid() and not sel:is_dead() and me:can_attack(sel) then
        return false
    end
    -- If in cat/bear form, we need to drop to caster form first before travel
    -- form becomes usable. But only drop form if prowl is NOT the intended
    -- next action — if prowl is enabled and no target, prowl should win.
    local in_cat  = utils.has_buff(me, spells.BUFF_CAT_FORM)
    local in_bear = utils.has_buff(me, spells.BUFF_BEAR_FORM) or utils.has_buff(me, spells.BUFF_DIRE_BEAR_FORM)
    if in_cat then
        -- Cat form OOC with prowl enabled → let prowl handle it, not travel form
        if menu.use_prowl:get_state() and runtime.prowl_id then return false end
        -- Cat form OOC, prowl disabled → drop to caster so travel form can cast
        local ok = pcall(function()
            if CancelShapeshiftForm then CancelShapeshiftForm() end
        end)
        if not ok then core.spell_book.cast_spell(runtime.cat_form_id) end
        utils.log_debug(menu, "Travel Form: dropping cat form")
        return false  -- cast travel form next tick in caster form
    end
    if in_bear then
        local ok = pcall(function()
            if CancelShapeshiftForm then CancelShapeshiftForm() end
        end)
        if not ok and runtime.bear_form_id then core.spell_book.cast_spell(runtime.bear_form_id) end
        utils.log_debug(menu, "Travel Form: dropping bear form")
        return false
    end
    if not utils.can_cast_self(runtime.travel_form_id, me) then return false end
    if utils.cast_self(runtime.travel_form_id, me) then
        utils.log_debug(menu, "Travel Form (OOC)")
        note_cast()
        return true
    end
    return false
end

-- ── Abolish Poison ─────────────────────────────────────────────────────────
local function try_abolish_poison(me)
    if not menu.use_abolish_poison:get_state() then return false end
    if not runtime.abolish_poison_id then return false end
    -- Check self for poison debuffs
    local auras = me:get_debuffs()
    if not auras then return false end
    for i = 1, #auras do
        local a = auras[i]
        if a and a.type and a.type == 4 then  -- type 4 = poison
            if utils.can_cast_self(runtime.abolish_poison_id, me) then
                if utils.cast_self(runtime.abolish_poison_id, me) then
                    utils.log_debug(menu, "Abolish Poison (self)")
                    note_cast()
                    return true
                end
            end
            break
        end
    end
    return false
end

-- ── Nature's Grasp ─────────────────────────────────────────────────────────
local function try_natures_grasp(me)
    if not menu.use_natures_grasp:get_state() then return false end
    if not runtime.natures_grasp_id then return false end
    if utils.has_buff(me, spells.BUFF_BEAR_FORM) or utils.has_buff(me, spells.BUFF_CAT_FORM) then return false end
    if not utils.can_cast_self(runtime.natures_grasp_id, me) then return false end
    if utils.cast_self(runtime.natures_grasp_id, me) then
        utils.log_debug(menu, "Nature's Grasp")
        note_cast()
        return true
    end
    return false
end


-- ── Barkskin ───────────────────────────────────────────────────────────────
local function try_barkskin(me)
    if not menu.use_barkskin:get_state() then return false end
    if not runtime.barkskin_id then return false end
    if utils.has_buff(me, spells.BUFF_BARKSKIN) then return false end
    local hp_pct = utils.get_health_pct(me)
    if hp_pct > (menu.barkskin_hp_pct:get() / 100.0) then return false end
    if not utils.can_cast_self(runtime.barkskin_id, me) then return false end
    if utils.cast_self(runtime.barkskin_id, me) then
        utils.log_debug(menu, "Barkskin")
        note_cast()
        return true
    end
    return false
end

-- ── Claw (builder when Shred not available / not behind) ───────────────────
try_claw = function(me, target)
    if not menu.use_claw or not menu.use_claw:get_state() then return false end
    if not runtime.claw_id then return false end
    if runtime.combo_points >= 5 then return false end
    if not utils.can_cast_hostile(runtime.claw_id, me, target) then return false end
    if utils.cast_target(runtime.claw_id, target) then
        utils.log_debug(menu, "Claw (builder)")
        note_cast()
        return true
    end
    return false
end

-- ── Helpers for smart CC decisions ───────────────────────────────────────

-- Count enemies in melee range hitting me or party
local function count_melee_attackers(me)
    local count = 0
    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() and me:can_attack(obj) then
            local ok, tgt = pcall(function() return obj:get_target() end)
            if ok and tgt and tgt:is_valid() then
                local targeting_me    = utils.same_unit(tgt, me)
                local targeting_party = tgt:is_party_member()
                if (targeting_me or targeting_party) and utils.is_melee_target(me, obj) then
                    count = count + 1
                end
            end
        end
    end
    return count
end

-- True if unit is a healer (by role or class heuristic)
local HEALER_CLASSES = { [2]=true, [5]=true, [7]=true, [11]=true } -- Paladin, Priest, Shaman, Druid
local function is_healer(unit)
    if not unit or not unit:is_valid() then return false end
    -- Only evaluate players — NPCs don't have meaningful healer roles
    local ok_p, is_p = pcall(function() return unit:is_player() end)
    if not (ok_p and is_p) then return false end
    local ok_r, role = pcall(function() return unit:get_group_role() end)
    if ok_r and role == 1 then return true end  -- 1 = healer role
    -- Fallback: class heuristic for PvP where role isn't set
    local ok_c, cls = pcall(function() return unit:get_class() end)
    if ok_c and HEALER_CLASSES[cls] then
        -- Only count as healer if they're actually casting
        local ok_cast, casting = pcall(function() return unit:is_casting_spell() end)
        local ok_chan, channing = pcall(function() return unit:is_channelling_spell() end)
        return (ok_cast and casting) or (ok_chan and channing)
    end
    return false
end

-- True if target is actively casting/channelling a heal on someone we're fighting
local function is_healing_our_target(unit, me)
    local ok_cast, casting = pcall(function() return unit:is_casting_spell() end)
    local ok_chan, channing = pcall(function() return unit:is_channelling_spell() end)
    if not ((ok_cast and casting) or (ok_chan and channing)) then return false end
    local ok_t, spell_tgt = pcall(function() return unit:get_active_spell_target() end)
    if not ok_t or not spell_tgt or not spell_tgt:is_valid() then return false end
    -- Target of the heal must be an enemy of me (they're healing a mob/player fighting us)
    local ok_atk, can_atk = pcall(function() return me:can_attack(spell_tgt) end)
    return ok_atk and can_atk
end

-- True if target is moving away (kiting us)
local function is_kiting(me, target)
    local ok1, pos_me  = pcall(function() return me:get_position() end)
    local ok2, pos_tgt = pcall(function() return target:get_position() end)
    local ok3, moving  = pcall(function() return target:is_moving() end)
    if not ok1 or not ok2 or not ok3 or not moving then return false end
    -- Check if target is moving and not in melee range
    return moving and not utils.is_melee_target(me, target)
end

-- ── War Stomp (Tauren racial AoE stun) ────────────────────────────────────
local function try_war_stomp(me, target)
    if not menu.use_war_stomp or not menu.use_war_stomp:get_state() then return false end
    if not runtime.war_stomp_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not utils.is_melee_target(me, target) then return false end
    if is_pending_cast(runtime.war_stomp_id) then return false end
    if not utils.can_cast_self(runtime.war_stomp_id, me) then return false end
    -- Never interrupt a finisher — CPs are too valuable to waste on a stomp
    local min_finisher_cp = 99
    if menu.use_rip:get_state() then
        min_finisher_cp = math.min(min_finisher_cp, menu.rip_combo_points:get())
    end
    if menu.use_ferocious_bite:get_state() then
        min_finisher_cp = math.min(min_finisher_cp, 5)
    end
    if runtime.combo_points >= min_finisher_cp then return false end
    local attackers = count_melee_attackers(me)
    local my_hp = me:get_health_percentage() / 100
    local stomp_hp = menu.war_stomp_hp_pct:get() / 100
    local stomp_attackers = menu.war_stomp_attackers:get()
    -- Fire when enough enemies are swarming, OR health is critically low
    local should_stomp = attackers >= stomp_attackers or (stomp_hp > 0 and my_hp < stomp_hp)
    if not should_stomp then return false end
    if utils.cast_self(runtime.war_stomp_id, me) then
        mark_pending_cast(runtime.war_stomp_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "War Stomp (attackers=" .. attackers .. " hp=" .. string.format("%.0f%%", my_hp * 100) .. ")")
        note_cast()
        return true
    end
    return false
end

-- ── Cyclone (CC vs healers actively healing enemies) ──────────────────────
local function try_cyclone(me, target)
    if not menu.use_cyclone or not menu.use_cyclone:get_state() then return false end
    if not runtime.cyclone_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if utils.same_unit(me, target) then return false end
    if not me:can_attack(target) then return false end
    -- Cyclone is last resort — only cast when already in caster form.
    -- Never shift out of cat/bear mid-rotation just to Cyclone.
    local in_cat  = utils.has_buff(me, spells.BUFF_CAT_FORM)
    local in_bear = utils.has_buff(me, spells.BUFF_BEAR_FORM)
    if in_cat or in_bear then return false end
    -- Bash must be on cooldown — if Bash is available, use that instead
    if runtime.bash_id then
        local bash_cd = core.spell_book.get_spell_cooldown(runtime.bash_id)
        if bash_cd <= 0 and core.spell_book.is_usable_spell(runtime.bash_id) then
            return false  -- Bash is available, don't waste a Cyclone
        end
    end
    -- Only for healers actively casting heals on enemies — not generic casts
    if not is_healing_our_target(target, me) and not is_healer(target) then return false end
    if is_pending_cast(runtime.cyclone_id) then return false end
    if utils.has_debuff(target, spells.DEBUFF_CYCLONE) then return false end
    if not utils.can_cast_hostile(runtime.cyclone_id, me, target) then return false end
    if utils.cast_target(runtime.cyclone_id, target) then
        mark_pending_cast(runtime.cyclone_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Cyclone (last resort healer CC)")
        note_cast()
        return true
    end
    return false
end

-- ── Entangling Roots (root kiting targets or casters running away) ─────────
local function try_entangling_roots(me, target)
    if not menu.use_entangling_roots or not menu.use_entangling_roots:get_state() then return false end
    if not runtime.entangling_roots_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if utils.same_unit(me, target) then return false end
    if is_pending_cast(runtime.entangling_roots_id) then return false end
    if utils.has_debuff(target, spells.DEBUFF_ENTANGLING_ROOTS) then return false end
    -- Auto: root when target is kiting us (moving, out of melee)
    if not is_kiting(me, target) then return false end
    if not utils.can_cast_hostile(runtime.entangling_roots_id, me, target) then return false end
    if utils.cast_target(runtime.entangling_roots_id, target) then
        mark_pending_cast(runtime.entangling_roots_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Entangling Roots (kiting)")
        note_cast()
        return true
    end
    return false
end

local function do_cat_rotation(me, target)
    local target_hp_pct = utils.get_health_pct(target)
    local in_stealth = utils.has_buff(me, spells.BUFF_PROWL)

    -- Defensive / self-cast (always safe, don't break stealth)
    if try_barkskin(me) then return true end
    if try_abolish_poison(me) then return true end

    -- While stealthed: ONLY fire stealth openers — nothing else hostile.
    -- Dash and Feral Charge must NOT run here; they break stealth before
    -- Pounce/Ravage can land.
    if in_stealth then
        if try_pounce(me, target) then return true end
        if try_ravage(me, target) then return true end
        return false
    end

    -- Gap closer (only outside stealth)
    if try_feral_charge_bear(me, target) then return true end
    if try_dash(me) then return true end

    -- CC (use before burning resources)
    if try_war_stomp(me, target) then return true end
    if try_cyclone(me, target) then return true end
    if try_entangling_roots(me, target) then return true end

    if try_faerie_fire(me, target) then return true end
    if not utils.is_melee_target(me, target) then return false end

    -- ── Omen of Clarity (Clearcasting proc) ──────────────────────────────────
    -- Free next ability — spend it immediately on the highest-value action.
    -- Priority: Shred (highest damage/CP) > Mangle (debuff maintenance) > Rake
    local has_clearcasting = utils.has_buff(me, spells.BUFF_CLEARCASTING)
    if has_clearcasting and runtime.combo_points < 5 then
        -- Shred is best value on a free proc
        if menu.use_shred:get_state() and runtime.shred_id
           and utils.is_behind_target(me, target)
           and not is_pending_cast(runtime.shred_id)
           and utils.can_cast_hostile(runtime.shred_id, me, target) then
            if utils.cast_target(runtime.shred_id, target) then
                mark_pending_cast(runtime.shred_id, PENDING_CAST_TIMEOUT_S)
                utils.log_debug(menu, "Shred [Clearcasting]")
                note_cast()
                return true
            end
        end
        -- Mangle if not behind
        if menu.use_mangle_cat:get_state() and runtime.mangle_cat_id
           and not is_pending_cast(runtime.mangle_cat_id)
           and utils.can_cast_hostile(runtime.mangle_cat_id, me, target) then
            if utils.cast_target(runtime.mangle_cat_id, target) then
                mark_pending_cast(runtime.mangle_cat_id, PENDING_CAST_TIMEOUT_S)
                utils.log_debug(menu, "Mangle [Clearcasting]")
                note_cast()
                return true
            end
        end
    end

    -- Finishers first — always spend CPs before anything else
    if try_rip(me, target) then return true end
    if try_ferocious_bite(me, target, target_hp_pct) then return true end
    -- Maim: only at CP=5 when target is casting and Rip is not the right choice
    if try_maim(me, target) then return true end
    -- Tiger's Fury: energy recovery, fires during builder phase (CP < 4)
    if try_tigers_fury(me, target) then return true end
    -- Builder priority: Mangle (debuff) → Rake (bleed) → Shred/Claw
    if try_mangle_cat(me, target) then return true end
    if try_rake(me, target) then return true end
    if try_rake_trick(me, target) then return true end
    if try_shred_or_filler(me, target) then return true end
    if try_powershift(me) then return true end

    -- Auto-attack fallback for leveling 1-70
    if me:is_in_combat() and target and target:is_valid() and not target:is_dead()
       and me:can_attack(target) then
        leveling_manager.ensure_melee(me, target)
    end

    return false
end

local function try_growl(me, target)
    if not menu.auto_growl:get_state() then return false end
    if not runtime.growl_id then return false end
    if utils.target_is_me(target, me) then return false end
    if is_pending_cast(runtime.growl_id) then return false end
    if not utils.can_cast_hostile(runtime.growl_id, me, target) then return false end

    if utils.cast_target_fast(runtime.growl_id, target) then
        mark_pending_cast(runtime.growl_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Growl")
        note_cast()
                esp_renderer.on_cast(nil, "Cat Rotation", color.yellow(220))
        return true
    end

    return false
end

local function try_frenzied_regeneration(me)
    if not menu.use_frenzied_regeneration:get_state() then return false end
    if not runtime.frenzied_regeneration_id then return false end
    if utils.get_health_pct(me) >= (menu.frenzied_regeneration_hp_pct:get() / 100) then return false end
    if utils.has_buff(me, spells.BUFF_FRENZIED_REGENERATION) then return false end

    -- If we're in cat form (or caster), shift to bear first so we can use Frenzied Regen.
    -- Only do this in combat — no point emergency-shifting while OOC.
    local in_bear = utils.has_buff(me, spells.BUFF_BEAR_FORM) or utils.has_buff(me, spells.BUFF_DIRE_BEAR_FORM)
    if not in_bear then
        if me:is_in_combat() and menu.auto_form:get_state() and runtime.bear_form_id then
            if not is_pending_cast(runtime.bear_form_id) and utils.can_cast_self(runtime.bear_form_id, me) then
                utils.cast_self(runtime.bear_form_id, me)
                mark_pending_cast(runtime.bear_form_id, PENDING_CAST_TIMEOUT_S)
                runtime.bear_charge_shift_at = core.time()  -- suppress cat snap-back for 2s
                utils.log_debug(menu, "Shifting Bear for Frenzied Regen")
            end
        end
        return false  -- cast Frenzied Regen on the next tick once in bear form
    end

    -- In bear form: require enough rage to actually cast it
    if utils.get_rage(me) < 40 then return false end
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
    if enc and enc.hold_cooldowns then return false end
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
    local mangle_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_MANGLE)
    -- During Berserk, Mangle CD is 1.5s — spam it aggressively for threat
    local refresh_threshold = utils.has_buff(me, spells.BUFF_BERSERK) and 3000 or 1500
    if mangle_rem > refresh_threshold then return false end
    if mangle_debuff_confirmed_by_other(target, spells.DEBUFF_MANGLE, me) then return false end
    if mangle_debuff_confirmed_by_other(target, spells.DEBUFF_TRAUMA, me) then return false end
    if is_pending_cast(runtime.mangle_bear_id) then return false end
    if not utils.can_cast_hostile(runtime.mangle_bear_id, me, target) then return false end

    if utils.cast_target(runtime.mangle_bear_id, target) then
        mark_pending_cast(runtime.mangle_bear_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Mangle (Bear)")
        note_cast()
        return true
    end

    return false
end

local function try_swipe(me, enemy_count, min_count_override)
    if enc and not enc.aoe_safe then return false end
    if not menu.use_swipe:get_state() then return false end
    if not runtime.swipe_id then return false end
    local min_count = min_count_override or menu.swipe_enemy_count:get()
    if enemy_count < min_count then return false end
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


-- --- Bear utility (v1.1) --------------------------------------------------

local function try_demoralizing_roar(me, target)
    if not menu.use_demoralizing_roar or not menu.use_demoralizing_roar:get_state() then return false end
    if not runtime.demoralizing_roar_id then return false end
    -- Demoralizing Roar is an AoE — check nearby enemies, not just the target
    -- Use a generous remaining time so we don't recast constantly
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_DEMORALIZING_ROAR) > 4000 then return false end
    if is_pending_cast(runtime.demoralizing_roar_id) then return false end
    if not utils.can_cast_self(runtime.demoralizing_roar_id, me) then return false end
    if utils.cast_self(runtime.demoralizing_roar_id, me) then
        mark_pending_cast(runtime.demoralizing_roar_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Demoralizing Roar")
        note_cast()
        return true
    end
    return false
end

-- --- Cat utility (v1.1) ---------------------------------------------------




-- --- Lacerate - bear DoT / threat (v1.3) ---------------------------------
-- Core TBC bear ability. Stacks to 5, each stack increases bleed damage.
-- Priority: maintain at 5 stacks; refresh when < 3s remaining.

local LACERATE_MAX_STACKS   = 5
local LACERATE_REFRESH_MS   = 3000

local function try_lacerate(me, target)
    if not menu.use_lacerate or not menu.use_lacerate:get_state() then return false end
    if not runtime.lacerate_id then return false end
    if not utils.has_buff(me, spells.BUFF_BEAR_FORM) and
       not utils.has_buff(me, spells.BUFF_DIRE_BEAR_FORM) then return false end
    if is_pending_cast(runtime.lacerate_id) then return false end
    -- TTD gate: don't build Lacerate stacks if the fight is nearly over
    local ttd = ttd_tracker.get(target)
    if ttd > 0 and ttd < 8 then return false end
    if not utils.can_cast_hostile(runtime.lacerate_id, me, target) then return false end

    local stacks    = utils.get_debuff_stacks(target, spells.DEBUFF_LACERATE)
    local remaining = utils.get_debuff_remaining_ms(target, spells.DEBUFF_LACERATE)

    local should_cast = (stacks < LACERATE_MAX_STACKS)
                     or (stacks >= LACERATE_MAX_STACKS and remaining <= LACERATE_REFRESH_MS)
    if not should_cast then return false end

    if utils.cast_target(runtime.lacerate_id, target) then
        mark_pending_cast(runtime.lacerate_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Lacerate (" .. tostring(math.min(stacks + 1, LACERATE_MAX_STACKS)) .. " stacks)")
        note_cast()
        return true
    end
    return false
end


local function do_bear_rotation(me, target)
    local mode = get_effective_mode()
    local enemy_count = utils.enemy_count_in_radius(me, 8)

    if try_frenzied_regeneration(me) then return true end
    if try_growl(me, target) then return true end
    if try_feral_charge_bear(me, target) then return true end
    if try_bash(me, target) then return true end
    if try_faerie_fire(me, target) then return true end
    if not utils.is_melee_target(me, target) then return false end
    if try_berserk(me, enemy_count, mode) then return true end
    if try_demoralizing_roar(me, target) then return true end
    if try_mangle_bear(me, target) then return true end
    if try_lacerate(me, target) then return true end
    if try_swipe(me, enemy_count) then return true end
    if try_maul(me, target) then return true end

    return false
end

-- ─────────────────────────────────────────────────────────────────────────────
-- GUARDIAN / TANK ABILITIES
-- ─────────────────────────────────────────────────────────────────────────────

local function try_survival_instincts(me)
    if not menu.use_survival_instincts:get_state() then return false end
    if not runtime.survival_instincts_id then return false end
    if utils.has_buff(me, spells.BUFF_SURVIVAL_INSTINCTS) then return false end
    local hp = me:get_health_percentage() / 100
    if hp > (menu.survival_instincts_hp_pct:get() / 100) then return false end
    -- Respect CD overlap setting — if Frenzied Regen is already active and
    -- overlap is off, hold SI for when Regen expires
    if not menu.tank_cd_overlap:get_state() then
        if utils.has_buff(me, spells.BUFF_FRENZIED_REGENERATION) then return false end
    end
    if is_pending_cast(runtime.survival_instincts_id) then return false end
    if not utils.can_cast_self(runtime.survival_instincts_id, me) then return false end
    if utils.cast_self_fast(runtime.survival_instincts_id, me) then
        mark_pending_cast(runtime.survival_instincts_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Survival Instincts")
        note_cast()
        return true
    end
    return false
end

local function try_enrage(me)
    if not menu.use_enrage:get_state() then return false end
    if not runtime.enrage_id then return false end
    if utils.has_buff(me, spells.BUFF_ENRAGE) then return false end
    if utils.get_rage(me) > menu.enrage_rage_threshold:get() then return false end
    if is_pending_cast(runtime.enrage_id) then return false end
    if not utils.can_cast_self(runtime.enrage_id, me) then return false end
    if utils.cast_self_fast(runtime.enrage_id, me) then
        mark_pending_cast(runtime.enrage_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Enrage (rage=" .. tostring(math.floor(utils.get_rage(me))) .. ")")
        note_cast()
        return true
    end
    return false
end

-- Scan party members — return true if any are below the configured HP threshold
local function party_member_in_danger(me)
    local threshold = menu.challenging_roar_party_hp_pct:get() / 100
    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead()
           and not utils.same_unit(obj, me) and obj:is_party_member() then
            if utils.get_health_pct(obj) < threshold then
                return true
            end
        end
    end
    return false
end

local function try_challenging_roar(me)
    if not menu.use_challenging_roar:get_state() then return false end
    if not runtime.challenging_roar_id then return false end
    if not utils.has_buff(me, spells.BUFF_BEAR_FORM) then return false end
    -- Only fire when a party member is being hammered
    if not party_member_in_danger(me) then return false end
    -- Growl should be on cooldown first — Challenging Roar is the AoE fallback
    if runtime.growl_id then
        local growl_cd = core.spell_book.get_spell_cooldown(runtime.growl_id)
        if growl_cd <= 0 then return false end  -- growl is available, use that first
    end
    if is_pending_cast(runtime.challenging_roar_id) then return false end
    if not utils.can_cast_self(runtime.challenging_roar_id, me) then return false end
    if utils.cast_self(runtime.challenging_roar_id, me) then
        mark_pending_cast(runtime.challenging_roar_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Challenging Roar (party in danger)")
        note_cast()
        return true
    end
    return false
end

-- Taunt any mob attacking a party member that isn't targeting me
local function try_taunt_off_party(me)
    if not menu.auto_growl:get_state() then return false end
    if not runtime.growl_id then return false end
    if core.spell_book.get_spell_cooldown(runtime.growl_id) > 0 then return false end
    if is_pending_cast(runtime.growl_id) then return false end
    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead()
           and me:can_attack(obj) then
            local ok, obj_target = pcall(function() return obj:get_target() end)
            if ok and obj_target and obj_target:is_valid()
               and not utils.same_unit(obj_target, me)
               and obj_target:is_party_member()
               and utils.is_melee_target(me, obj) then
                if utils.can_cast_hostile(runtime.growl_id, me, obj) then
                    if utils.cast_target(runtime.growl_id, obj) then
                        mark_pending_cast(runtime.growl_id, FAST_PENDING_CAST_TIMEOUT_S)
                        utils.log_debug(menu, "Growl -> taunt off party member")
                        note_cast()
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function do_guardian_rotation(me, target)
    local enemy_count = utils.enemy_count_in_radius(me, 8)
    local mode = get_effective_mode()

    -- Emergency defensive layer (highest priority)
    if try_survival_instincts(me) then return true end
    if try_frenzied_regeneration(me) then return true end
    if try_barkskin(me) then return true end

    -- Rage generation — do this early so we have rage for abilities
    if try_enrage(me) then return true end

    -- Gap closer / engage
    if try_feral_charge_bear(me, target) then return true end

    -- AoE taunt — pull threat off party before anything else
    if try_challenging_roar(me) then return true end
    if try_taunt_off_party(me) then return true end
    -- Single target taunt on primary target
    if try_growl(me, target) then return true end

    if try_bash(me, target) then return true end
    if try_faerie_fire(me, target) then return true end
    if not utils.is_melee_target(me, target) then return false end

    if try_berserk(me, enemy_count, mode) then return true end
    if try_demoralizing_roar(me, target) then return true end

    -- Core threat rotation: Mangle → Lacerate stacks → Swipe AoE → Maul rage dump
    if try_mangle_bear(me, target) then return true end
    if try_lacerate(me, target) then return true end
    if try_swipe(me, enemy_count, menu.guardian_swipe_enemy_count:get()) then return true end
    if try_maul(me, target) then return true end

    return false
end

local function do_rotation(me, target)
    if not is_gcd_ready() then return false end

    ttd_tracker.update(target)
    local lane = get_requested_lane(me)
    runtime.current_lane = lane

    if try_root_escape(me) then return true end
    if try_shift_form(me, lane) then return true end
    if not is_valid_hostile_target(me, target) then
        -- No valid target - reset CPs only if we had a target before
        if runtime.combo_points > 0 then
            local ok, cp_obj = pcall(function() return me:get_combo_points_target() end)
            if not ok or not cp_obj or not cp_obj:is_valid() then
                runtime.combo_points = 0
            end
        end
        return false
    end

    -- Sync combo points from API; fall back to cast-callback counter.
    -- IMPORTANT: only zero the counter when we are certain the CPs are gone —
    -- i.e. the target actually died or changed. Never zero just because
    -- is_in_combat() briefly returned false (private servers drop the flag
    -- between hits, which would wipe the counter mid-fight).
    if me:is_in_combat() and target and target:is_valid() and not target:is_dead() then
        sync_combo_target(me, target)
    end
    -- Zero only on confirmed target death/change, not on combat-flag flicker
    do
        local ok, cp_obj = pcall(function() return me:get_combo_points_target() end)
        if ok and cp_obj and cp_obj:is_valid() then
            -- CPs are on a live target — check if it changed
            if target and not utils.same_unit(cp_obj, target) then
                runtime.combo_points = 0
            end
        elseif ok and (not cp_obj or not cp_obj:is_valid()) then
            -- No CP target at all — genuinely zero
            runtime.combo_points = 0
        end
    end

    -- Prowl OOC when in cat form and no target yet
    if not me:is_in_combat() then
        if try_prowl(me) then return true end
    end

    if lane == "cat" then
        return do_cat_rotation(me, target)
    elseif lane == "guardian" then
        return do_guardian_rotation(me, target)
    end
    return do_bear_rotation(me, target)
end


local function on_render()
    esp_renderer.on_render(menu)
end

-- ESP only renders when this spec is enabled
core.register_on_render_callback(function()
    if not menu or not menu.enabled or not menu.enabled:get_state() then return end
    on_render()
end)
-- __EAX_ESP_GUARD
-- Combo point tracking via cast callback
-- Last-resort fallback if both me:get_power(4) and me:combo_points_current() fail.
-- Proper API calls are attempted first in sync_combo_target().
local CP_BUILDERS = {}
local CP_FINISHERS = {}
local function build_cp_spell_sets()
    -- Build directly from the spells tables so nothing drifts out of sync.
    local builder_tables = {
        spells.RAKE, spells.SHRED, spells.MANGLE_CAT,
        spells.RAVAGE, spells.POUNCE, spells.CLAW,
    }
    for _, tbl in ipairs(builder_tables) do
        for _, id in ipairs(tbl) do CP_BUILDERS[id] = true end
    end

    local finisher_tables = {
        spells.RIP, spells.FEROCIOUS_BITE, spells.MAIM,
    }
    for _, tbl in ipairs(finisher_tables) do
        for _, id in ipairs(tbl) do CP_FINISHERS[id] = true end
    end
end
build_cp_spell_sets()

local function on_spell_cast(data)
    if not data or not data.spell_id then return end
    local sid = data.spell_id
    if CP_BUILDERS[sid] then
        -- If this builder hit a different target than our current CP target,
        -- the old CPs are gone — reset before incrementing on the new target.
        local me = core.object_manager.get_local_player()
        if me then
            local ok, cp_obj = pcall(function() return me:get_combo_points_target() end)
            if ok and cp_obj and cp_obj:is_valid() and data.target and data.target:is_valid() then
                if not utils.same_unit(cp_obj, data.target) then
                    runtime.combo_points = 0
                    utils.log_debug(menu, "[CP] target changed, reset to 0")
                end
            end
        end
        runtime.combo_points = math.min(5, runtime.combo_points + 1)
        utils.log_debug(menu, "[CP] builder " .. sid .. " -> CP=" .. runtime.combo_points)
    elseif CP_FINISHERS[sid] then
        runtime.combo_points = 0
        utils.log_debug(menu, "[CP] finisher " .. sid .. " -> CP=0")
    end
end

core.register_on_spell_cast_callback(on_spell_cast)
core.register_on_update_callback(function()
    local me = core.object_manager.get_local_player()
    if not me then return end

    if utils.throttle("eaxdruidferal_mode_refresh", 5.0) then
        runtime.cached_mode = detect_mode(me)
    end

    if utils.throttle("eaxdruidferal_set_bonus", 10.0) then
        update_set_bonus(me)
    end

    handle_toggle()

    if not menu.enabled:get_state() then return end

    -- OOC management (drink/eat/rez/group buffs)
    ooc_manager.on_update(me, menu, utils, {
        rez_spell_id = runtime.rebirth_id,
        group_buffs = {
            { spell_id = runtime.ooc_mark_of_the_wild_id,
               buff_ids = spells.BUFF_MARK_OF_THE_WILD,
               name = "Mark Of The Wild",
               toggle = menu.ooc_group_buff },
        },
    })
    if me:is_dead() then return end
    if eax_utils.is_eating_or_drinking(me) then return end

    -- OOC utility
    if not me:is_in_combat() then
        if try_ooc_self_heal(me) then return end
        if try_remove_curse_feral(me) then return end
        if try_innervate(me) then return end
        if try_abolish_poison(me) then return end
        -- Travel form last — prowl (fired in do_rotation below) takes priority,
        -- and travel form guards against active targets itself
        if try_travel_form(me) then return end
    end

    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    -- Validate focus target is hostile; if not, fall through to smart selector
    if focus_target and not me:can_attack(focus_target) then focus_target = nil end
    -- Smart target selection: prioritize units actively fighting us/party
    local target = focus_target or utils.find_best_target(me)

    -- CP finisher lock: when CPs are at the finisher threshold, stick to the
    -- mob the CPs were built on. Switching targets at CP=5 wastes the finisher.
    if not focus_target then
        local min_finisher_cp = 99
        if menu.use_rip:get_state() then
            min_finisher_cp = math.min(min_finisher_cp, menu.rip_combo_points:get())
        end
        if menu.use_ferocious_bite:get_state() then
            min_finisher_cp = math.min(min_finisher_cp, 5)
        end
        if runtime.combo_points >= min_finisher_cp then
            local ok, cp_obj = pcall(function() return me:get_combo_points_target() end)
            if ok and cp_obj and cp_obj:is_valid() and not cp_obj:is_dead() and me:can_attack(cp_obj) then
                target = cp_obj
            end
        end
    end


    -- Mana conservation (leveling 1-70)
    if leveling_manager.is_conserving_mana(me, menu) then
        leveling_manager.ensure_melee(me, target)
    end
    -- Encounter policy (boss-specific rotation adjustments)
    enc = encounter_manager.get_policy(me)

    -- Interrupt
    if target and target:is_valid() and me:can_attack(target) and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "druid", utils) then
            return
        end
    end

    -- Racial CDs
    racial_manager.try_offensive(me)
    racial_manager.try_utility(me, target)
    racial_manager.try_defensive(me)

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


-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxdruidferal_space_win")
_space_win:set_initial_size(_vec2.new(460, 580))
_space_win:set_next_window_min_size(_vec2.new(320, 300))
_space_win:set_next_window_padding(_vec2.new(10, 8))
menu.set_window(_space_win)
-- -----------------------------------------------------------------------------
core.register_on_render_menu_callback(function()
    menu.render()
end)

if control_panel_utility then
    core.register_on_render_control_panel_callback(function()
        local elements = {}
        local function add_cb(label, item, uid)
            if not item then return end
            local cur = item:get_state()
            local nxt = control_panel_utility:insert_key_checkbox_(elements, label, cur, 0, false, uid)
            if nxt ~= cur then item:set(nxt) end
        end
        local toggle_key = menu.toggle_key:get_key_code()
        local label = "EAX Druid Feral] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxdruidferal_enabled_cp")
        if menu.enabled:get_state() then
        if menu.use_cooldowns then
            local cur_fer_cds = menu.use_cooldowns:get_state()
            local nxt_fer_cds = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX Fer] Cooldowns", cur_fer_cds, 0, false, "eax_fer_cds_cp")
            if nxt_fer_cds ~= cur_fer_cds then menu.use_cooldowns:set(nxt_fer_cds) end
        end
        if menu.use_powershift then
            local cur_fer_ps = menu.use_powershift:get_state()
            local nxt_fer_ps = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX Fer] Powershift", cur_fer_ps, 0, false, "eax_fer_ps_cp")
            if nxt_fer_ps ~= cur_fer_ps then menu.use_powershift:set(nxt_fer_ps) end
        end
        if menu.focus_priority then
            local cur_fer_focus = menu.focus_priority:get_state()
            local nxt_fer_focus = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX Fer] Focus Priority", cur_fer_focus, 0, false, "eax_fer_focus_cp")
            if nxt_fer_focus ~= cur_fer_focus then menu.focus_priority:set(nxt_fer_focus) end
        end
        if menu.use_racial then
            local cur_fer_racial = menu.use_racial:get_state()
            local nxt_fer_racial = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX Fer] Use Racial", cur_fer_racial, 0, false, "eax_fer_racial_cp")
            if nxt_fer_racial ~= cur_fer_racial then menu.use_racial:set(nxt_fer_racial) end
        end
        end
        return elements
    end)
end


-- -- EAX Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Druid"
    local _eax_spec  = "Feral"
    -- Register this spec for its class (last-loaded wins for tracking)
    if not _G.__EAX_LOADED[_eax_class] then
        _G.__EAX_LOADED[_eax_class] = {}
    end
    _G.__EAX_LOADED[_eax_class][_eax_spec] = function()
        return menu and menu.enabled and menu.enabled:get_state()
    end
    -- Runtime conflict check: fires on render, only warns when 2+ specs enabled
    local _conflict_last_warn = 0
    local _orig_render = on_render
    on_render = function()
        if _orig_render then _orig_render() end
        local specs = _G.__EAX_LOADED[_eax_class]
        if not specs then return end
        local enabled_specs = {}
        for spec_name, is_enabled_fn in pairs(specs) do
            if is_enabled_fn and is_enabled_fn() then
                table.insert(enabled_specs, spec_name)
            end
        end
        if #enabled_specs < 2 then return end
        local now = core.time()
        if (now - _conflict_last_warn) < 10 then return end
        _conflict_last_warn = now
        local names = table.concat(enabled_specs, " + ")
        core.log("[EAX WARNING] Multiple " .. _eax_class .. " specs enabled: "
            .. names .. ". Disable all but one.")
        core.graphics.add_notification(
            "eax_conflict_" .. _eax_class,
            "[EAX] Conflict!",
            "Multiple " .. _eax_class .. " specs enabled: " .. names .. " - Disable all but one in the bot menu.",
            8.0,
            require("common/color").new(255, 80, 80, 255)
        )
    end
end

local _pi = pcall(require, "plugin_info") and require("plugin_info") or nil
core.log("[EAX Druid Feral] Loaded " .. (_pi and _pi.plugin_version or "?") .. "")
