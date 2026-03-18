-- EAX Rogue Combat | main.lua

local menu = require("menu")
local enums = (function()
    local ok, e = pcall(require, "common/enums")
    return ok and e or nil
end)()
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")
local color     = require("color")

---@type interrupt_manager
local interrupt_manager = require("interrupt_manager")
---@type ooc_manager
local ooc_manager = require("ooc_manager")
---@type leveling_manager
local leveling_manager = require("leveling_manager")
---@type encounter_manager
local encounter_manager = require("encounter_manager")
-- Module-level encounter policy cache (updated each tick)
local enc = nil


---@type esp_renderer
local esp_renderer = require("esp_renderer")
esp_renderer.init("combat", "Rogue Combat")
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
    sinister_strike_id = nil,
    slice_and_dice_id = nil,
    eviscerate_id = nil,
    rupture_id = nil,
    kick_id = nil,
    blade_flurry_id = nil,
    adrenaline_rush_id = nil,
    killing_spree_id = nil,
    evasion_id = nil,
    feint_id = nil,
    garrote_id = nil,
    riposte_id = nil,
    expose_armor_id = nil,
    shiv_id = nil,
    combo_points = 0,
    combo_target = nil,
    prev_toggle_state = false,
    last_cast_time = 0,
    cached_mode = "solo",
    set_multiplier = 1.0,
}

local GCD_CAST_INTERVAL = 1.0  -- TBC GCD

local function resolve_spells()
    runtime.sinister_strike_id = utils.resolve_spell_id(spells.SINISTER_STRIKE)
    runtime.slice_and_dice_id = utils.resolve_spell_id(spells.SLICE_AND_DICE)
    runtime.eviscerate_id = utils.resolve_spell_id(spells.EVISCERATE)
    runtime.rupture_id = utils.resolve_spell_id(spells.RUPTURE)
    runtime.kick_id = utils.resolve_spell_id(spells.KICK)
    runtime.blade_flurry_id = utils.resolve_spell_id(spells.BLADE_FLURRY)
    runtime.adrenaline_rush_id = utils.resolve_spell_id(spells.ADRENALINE_RUSH)
    runtime.garrote_id = utils.resolve_spell_id(spells.GARROTE)
    runtime.riposte_id = utils.resolve_spell_id(spells.RIPOSTE)
    runtime.killing_spree_id   = utils.resolve_spell_id(spells.KILLING_SPREE)
    runtime.evasion_id        = utils.resolve_spell_id(spells.EVASION)
    runtime.feint_id   = utils.resolve_spell_id(spells.FEINT)
    runtime.shiv_id    = utils.resolve_spell_id(spells.SHIV)
    runtime.expose_armor_id   = utils.resolve_spell_id(spells.EXPOSE_ARMOR)
end

local function log_resolved_spells()
    core.log(
        "[EAX Rogue Combat] Resolved: SS=" .. tostring(runtime.sinister_strike_id)
            .. " SnD=" .. tostring(runtime.slice_and_dice_id)
            .. " EV=" .. tostring(runtime.eviscerate_id)
            .. " RUP=" .. tostring(runtime.rupture_id)
    )
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

local function current_mode()
    return utils.get_selected_mode(menu)
end

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        menu.enabled:set(not menu.enabled:get_state())
    end
    runtime.prev_toggle_state = current
end

-- Read combo points using native game_object API on ME (the player).
-- Key fix: get_power() must be called on the PLAYER, not on cp_obj (the target mob).
-- Calling it on cp_obj always returned 0 because mobs have no combo points.
local function get_current_combo_points(me, target)
    -- Method 1: native game_object API, TBC-specific power type
    local ok1, v1 = pcall(function() return me:get_power(enums.power_type.COMBOPOINTS_TBC) end)
    if ok1 and type(v1) == "number" and v1 > 0 then return v1 end

    -- Method 2: native game_object API, retail enum fallback (COMBOPOINTS = 4)
    local ok2, v2 = pcall(function() return me:get_power(enums.power_type.COMBOPOINTS) end)
    if ok2 and type(v2) == "number" and v2 > 0 then return v2 end

    return nil  -- all failed, keep cast-callback count
end


local function track_target(me, target)
    -- Read combo points directly from the API every tick via izi_sdk.
    local cp = get_current_combo_points(me, target)
    if cp == nil then return end  -- API bug, keep existing count

    -- Confirm CPs are on the current target, not a previous one
    local cp_target_ok, cp_target = pcall(function() return me:get_combo_points_target() end)
    if cp_target_ok and cp_target and cp_target:is_valid() then
        if target and not utils.same_unit(cp_target, target) then
            cp = 0
        end
    end

    runtime.combo_points = cp or 0
    runtime.combo_target = target
end

local function should_use_major_cooldowns(me)
    if not me or not me:is_in_combat() then
        return false
    end

    local mode = current_mode()
    if mode == "solo" then
        return false
    elseif mode == "dungeon" then
        return runtime.combo_points >= 3
    end

    return runtime.combo_points >= 4
end

local function try_kick(me, target)
    if not menu.use_kick:get_state() then
        return false
    end
    if not runtime.kick_id or not utils.can_attack(me, target) then
        return false
    end
    if not target:is_casting_spell() and not target:is_channelling_spell() then
        return false
    end
    if target:is_casting_spell() and not target:is_active_spell_interruptable() then
        return false
    end
    if not utils.can_cast_hostile(runtime.kick_id, me, target) then
        return false
    end

    if utils.cast_target_fast(runtime.kick_id, target, "Kick") then
        utils.log_debug(menu, "Kick")
        note_cast()
        return true
    end

    return false
end

local function try_blade_flurry(me, target)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_blade_flurry:get_state() then
        return false
    end
    if not runtime.blade_flurry_id or not me:is_in_combat() then
        return false
    end
    if utils.get_buff_remaining_ms(me, spells.BUFF_BLADE_FLURRY) > 0 then
        return false
    end
    if utils.enemy_count_in_radius(me, 8) < menu.aoe_enemy_count:get() and current_mode() == "solo" then
        return false
    end
    if not utils.can_cast_self(runtime.blade_flurry_id, me) then
        return false
    end

    if utils.cast_self_fast(runtime.blade_flurry_id, me, "Blade Flurry") then
        utils.log_debug(menu, "Blade Flurry")
        note_cast()
        return true
    end

    return false
end

local function try_adrenaline_rush(me)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_adrenaline_rush:get_state() then
        return false
    end
    if not runtime.adrenaline_rush_id or not should_use_major_cooldowns(me) then
        return false
    end
    if utils.get_buff_remaining_ms(me, spells.BUFF_ADRENALINE_RUSH) > 0 then
        return false
    end
    if not utils.can_cast_self(runtime.adrenaline_rush_id, me) then
        return false
    end

    if utils.cast_self_fast(runtime.adrenaline_rush_id, me, "Adrenaline Rush") then
        utils.log_debug(menu, "Adrenaline Rush")
        note_cast()
        return true
    end

    return false
end

local function try_slice_and_dice(me)
    if not menu.use_slice_and_dice:get_state() then
        return false
    end
    if not runtime.slice_and_dice_id or runtime.combo_points <= 0 then
        return false
    end

    local remaining_ms = utils.get_buff_remaining_ms(me, spells.BUFF_SLICE_AND_DICE)
    if remaining_ms > (menu.snd_refresh_seconds:get() * 1000) then
        return false
    end
    if not utils.can_cast_self(runtime.slice_and_dice_id, me) then
        return false
    end

    if utils.cast_self(runtime.slice_and_dice_id, me, "Slice and Dice") then
        utils.log_debug(menu, "Slice and Dice")
        note_cast()
        return true
    end

    return false
end

local function try_rupture(me, target)
    if not menu.use_rupture:get_state() then
        return false
    end
    if not runtime.rupture_id or not utils.can_attack(me, target) then
        return false
    end
    if runtime.combo_points < menu.finish_combo_points:get() then
        return false
    end
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_RUPTURE) > 3000 then return false end
    -- TTD gate: don't Rupture if fight ending before it expires (v1.3)
    if ttd_tracker.get(target) < 12 then return false end
    if not utils.can_cast_hostile(runtime.rupture_id, me, target) then
        return false
    end

    if utils.cast_target(runtime.rupture_id, target, "Rupture") then
        utils.log_debug(menu, "Rupture")
        note_cast()
                esp_renderer.on_cast(runtime.rupture_id, "Rupture", color.orange(220))
        return true
    end

    return false
end

local function try_eviscerate(me, target)
    if not menu.use_eviscerate:get_state() then
        return false
    end
    if not runtime.eviscerate_id or not utils.can_attack(me, target) then
        return false
    end
    if runtime.combo_points < menu.finish_combo_points:get() then
        return false
    end
    if utils.get_buff_remaining_ms(me, spells.BUFF_SLICE_AND_DICE) < 2000 then
        return false
    end
    if not utils.can_cast_hostile(runtime.eviscerate_id, me, target) then
        return false
    end

    if utils.cast_target(runtime.eviscerate_id, target, "Eviscerate") then
        utils.log_debug(menu, "Eviscerate")
        note_cast()
                esp_renderer.on_cast(runtime.eviscerate_id, "Eviscerate", color.red(220))
        return true
    end

    return false
end

local function try_sinister_strike(me, target)
    if not menu.use_sinister_strike:get_state() then
        return false
    end
    if not runtime.sinister_strike_id or not utils.can_attack(me, target) then
        return false
    end
    if runtime.combo_points >= 5 then
        return false
    end
    if not utils.can_cast_hostile(runtime.sinister_strike_id, me, target) then
        return false
    end

    if utils.cast_target(runtime.sinister_strike_id, target, "Sinister Strike") then
        utils.log_debug(menu, "Sinister Strike")
        note_cast()
                esp_renderer.on_cast(runtime.sinister_strike_id, "Sinister Strike", color.yellow(220))
        return true
    end

    return false
end

local function try_evasion(me)
    if not menu.use_evasion:get_state() then return false end
    if not runtime.evasion_id then
        runtime.evasion_id        = utils.resolve_spell_id(spells.EVASION)
    runtime.feint_id   = utils.resolve_spell_id(spells.FEINT)
    runtime.shiv_id    = utils.resolve_spell_id(spells.SHIV)
    runtime.expose_armor_id   = utils.resolve_spell_id(spells.EXPOSE_ARMOR)
    end
    if not runtime.evasion_id then return false end
    local hp_pct = me:get_health_percentage() / 100
    if hp_pct > (menu.evasion_hp_pct:get() / 100) then return false end
    if utils.has_buff(me, spells.BUFF_EVASION) then return false end
    if not utils.can_cast_self(runtime.evasion_id, me) then return false end
    if utils.cast_self(runtime.evasion_id, me) then
        utils.log_debug(menu, "Evasion")
        return true
    end
    return false
end


-- --- Killing Spree (v1.1) -------------------------------------------------

local function try_killing_spree(me, target)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_killing_spree or not menu.use_killing_spree:get_state() then return false end
    if not runtime.killing_spree_id then return false end
    if not me:is_in_combat() then return false end
    -- Use with Blade Flurry for maximum effect
    if not utils.can_cast_hostile(runtime.killing_spree_id, me, target) then return false end
    if utils.cast_target(runtime.killing_spree_id, target, "Killing Spree") then
        utils.log_debug(menu, "Killing Spree")
        return true
    end
    return false
end



-- --- Feint - threat drop (v1.3) ------------------------------------------


-- --- Shiv - Deadly Poison refresh (v1.4) ---------------------------------
-- Use Shiv when Deadly Poison has < 2s remaining on target to refresh it
-- without consuming a combo point (costs energy, not CP).

local DEADLY_POISON_REFRESH_MS = 2000

local function try_shiv(me, target)
    if not menu.use_shiv or not menu.use_shiv:get_state() then return false end
    if not runtime.shiv_id then return false end
    -- Only worth using when Deadly Poison active and about to expire
    local dp_remain = utils.get_debuff_remaining_ms(target, spells.DEBUFF_DEADLY_POISON)
    if dp_remain <= 0 then return false end          -- not active
    if dp_remain > DEADLY_POISON_REFRESH_MS then return false end  -- not expiring yet
    if not utils.can_cast_hostile(runtime.shiv_id, me, target) then return false end
    if utils.cast_target(runtime.shiv_id, target, "Shiv") then
        utils.log_debug(menu, "Shiv (Deadly Poison refresh)")
        note_cast()
        return true
    end
    return false
end


local function try_feint(me)
    if not menu.use_feint or not menu.use_feint:get_state() then return false end
    if not runtime.feint_id then return false end
    -- Use Feint when threat is dangerously high (approximated by boss target)
    -- or when HP is low in solo as a damage-reduction tool
    local mode = current_mode()
    if mode == "raid" or mode == "dungeon" then
        if not utils.can_cast_hostile(runtime.feint_id, me, me:get_target()) then return false end
        if utils.cast_target(runtime.feint_id, me:get_target(), "Feint") then
            utils.log_debug(menu, "Feint")
            note_cast()
            return true
        end
    end
    return false
end

-- --- Expose Armor - boss-only debuff (v1.3) -------------------------------
-- Use as 5-CP finisher on bosses when Sunder Armor is not present.
-- Only in dungeon/raid mode where it matters.

local function try_expose_armor(me, target)
    if not menu.use_expose_armor or not menu.use_expose_armor:get_state() then return false end
    if not runtime.expose_armor_id then return false end
    local mode = current_mode()
    if mode == "solo" then return false end
    -- Only use if Expose Armor not active AND Sunder Armor not active
    if utils.has_debuff(target, spells.DEBUFF_EXPOSE_ARMOR) then return false end
    if utils.has_debuff(target, spells.DEBUFF_SUNDERED_ARMOR) then return false end
    -- Need at least 4 combo points
    if runtime.combo_points < 4 then return false end
    if not utils.can_cast_hostile(runtime.expose_armor_id, me, target) then return false end
    if utils.cast_target(runtime.expose_armor_id, target, "Expose Armor") then
        utils.log_debug(menu, "Expose Armor")
        note_cast()
        return true
    end
    return false
end



-- --- Garrote opener (stealth) (v1.6) -----------------------------------------
-- Apply Garrote from stealth: strong bleed, silences for 3s, no CD.
-- Higher DPS than Ambush for Assassination; used for openers.

local function try_garrote(me, target)
    if not menu.use_garrote or not menu.use_garrote:get_state() then return false end
    if not runtime.garrote_id then return false end
    if not utils.has_buff(me, spells.BUFF_STEALTH) then return false end
    if not utils.is_melee_target(me, target) then return false end
    if utils.has_debuff(target, spells.DEBUFF_GARROTE) then return false end
    if not utils.can_cast_hostile(runtime.garrote_id, me, target) then return false end
    if utils.cast_target(runtime.garrote_id, target, "Garrote") then
        utils.log_debug(menu, "Garrote (stealth opener)")
        note_cast()
        return true
    end
    return false
end

-- --- Riposte (v1.6) - after parry --------------------------------------------
-- Free attack that disarms target for 6s; Combat talent. Use immediately after parry.

local function try_riposte(me, target)
    if spec ~= "combat" then return false end  -- Combat only
    if not menu.use_riposte or not menu.use_riposte:get_state() then return false end
    if not runtime.riposte_id then return false end
    -- Riposte is only usable after a parry (the game makes it usable automatically)
    if not utils.can_cast_hostile(runtime.riposte_id, me, target) then return false end
    if utils.cast_target(runtime.riposte_id, target, "Riposte") then
        utils.log_debug(menu, "Riposte")
        note_cast()
        return true
    end
    return false
end


local function do_rotation(me, target)
    if not is_gcd_ready() then
        return false
    end

    -- Interrupt
    -- Interrupt (Kick)
    if target and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "rogue", utils) then
            return true
        end
    end

    -- Racial CDs
    racial_manager.try_offensive(me)
    racial_manager.try_utility(me, target)
    racial_manager.try_defensive(me)

    -- Defensive abilities
    ttd_tracker.update(target)

    if defensive_manager.try_defensive(me, "rogue", utils) then
        return true
    end

    if try_kick(me, target) then
        return true
    end

    if should_use_major_cooldowns(me) then
        if try_blade_flurry(me, target) then
            return true
        end
        if try_adrenaline_rush(me) then return true end
        if try_killing_spree(me, target) then return true end
    end

    if not utils.can_attack(me, target) then
        return false
    end

    track_target(me, target)

    if try_slice_and_dice(me) then return true end
    if try_expose_armor(me, target) then return true end
    if try_feint(me) then return true end
    if try_rupture(me, target) then
        return true
    end
    if try_eviscerate(me, target) then
        return true
    end
    if try_garrote(me, target) then return true end
    if try_riposte(me, target) then return true end
    if try_shiv(me, target) then return true end
    if try_sinister_strike(me, target) then return true end

    -- Auto-attack fallback for leveling 1-70
    -- (ensure_melee_auto_attack is called in the core combat lanes above)

    return false
end


local function update_set_bonus(me)
    local max_mult = 1.0
    local sets = { "Deathmantle", "DeathmantleBattlegear", "Terror" }
    for _, set_name in ipairs(sets) do
        local mult = utils.get_set_multiplier(me, set_name)
        if mult > max_mult then
            max_mult = mult
        end
    end
    runtime.set_multiplier = max_mult
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
core.register_on_update_callback(function()
    if utils.throttle("mode_refresh", 2.0) then
        runtime.cached_mode = current_mode()
    end

    if utils.throttle("set_bonus_check", 5.0) then
        local me = core.object_manager.get_local_player()
        if me then
            update_set_bonus(me)
        end
    end

    handle_toggle()
    if not menu.enabled:get_state() then
        return
    end

    local me = core.object_manager.get_local_player()
    if not me or me:is_dead() then
        return
    end
        ooc_manager.on_update(me, menu, utils)
    if eax_utils.is_eating_or_drinking(me) then return end

    enc = encounter_manager.get_policy(me)
    do_rotation(me, utils.find_best_target(me))
    
    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and focus_target:is_valid() then
        core.input.set_target(focus_target)
    end
    
    -- Self-emergency
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.35, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        try_evasion(me)
    end
end)



-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxroguecombat_space_win")
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
        local label = "EAX Rogue Combat] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxroguecombat_enabled_cp")
        if menu.enabled:get_state() then
        if menu.use_cooldowns then
            local cur_rco_cds = menu.use_cooldowns:get_state()
            local nxt_rco_cds = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX RCo] Cooldowns", cur_rco_cds, 0, false, "eax_rco_cds_cp")
            if nxt_rco_cds ~= cur_rco_cds then menu.use_cooldowns:set(nxt_rco_cds) end
        end
        if menu.focus_priority then
            local cur_rco_focus = menu.focus_priority:get_state()
            local nxt_rco_focus = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX RCo] Focus Priority", cur_rco_focus, 0, false, "eax_rco_focus_cp")
            if nxt_rco_focus ~= cur_rco_focus then menu.focus_priority:set(nxt_rco_focus) end
        end
        if menu.use_racial then
            local cur_rco_racial = menu.use_racial:get_state()
            local nxt_rco_racial = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX RCo] Use Racial", cur_rco_racial, 0, false, "eax_rco_racial_cp")
            if nxt_rco_racial ~= cur_rco_racial then menu.use_racial:set(nxt_rco_racial) end
        end
        end
        return elements
    end)
end


-- -- EAX Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Rogue"
    local _eax_spec  = "Combat"
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
core.log("[EAX Rogue Combat] Loaded " .. (_pi and _pi.plugin_version or "?"))
