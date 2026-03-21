-- EAX Rogue Assassination | main.lua

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
local interrupt_manager = require("eax_shared/interrupt_manager")
---@type ooc_manager
local ooc_manager = require("eax_shared/ooc_manager")
---@type vendor_automation
local vendor_automation = require("eax_shared/vendor_automation")
---@type consumables_manager
local consumables_manager = require("eax_shared/consumables_manager")
---@type mount_manager
local mount_manager = require("eax_shared/mount_manager")
---@type leveling_manager
local leveling_manager = require("leveling_manager")
---@type encounter_manager
local encounter_manager = require("eax_shared/encounter_manager")
-- Module-level encounter policy cache (updated each tick)
local enc = nil


---@type esp_renderer
local esp_renderer = require("esp_renderer")
esp_renderer.init("assa", "Rogue Assa")


-- Phase 04 visual telemetry wiring
local dps_meter = require("eax_shared/dps_meter")
local cooldown_tracker = require("eax_shared/cooldown_tracker")
local visual_state = require("eax_shared/visual_state")
local reactive_runtime = require("eax_shared/reactive_runtime")
local dps_risk = require("eax_shared/dps_risk")
local dps_runtime = require("eax_shared/dps_runtime")

-- Hot-path local caching (performance critical)
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown
local _get_spell_cd = core.spell_book.get_spell_cooldown

local _visual_ttd_tracker = nil
local _visual_ttd_ok, _visual_ttd_mod = pcall(require, "ttd_tracker")
if _visual_ttd_ok and _visual_ttd_mod then
    _visual_ttd_tracker = _visual_ttd_mod
end

local _visual_runtime = {
    in_combat = false,
    last_me_hp_pct = nil,
    last_target_hp_pct = nil,
    reactive_state = {},
}

local reactive_adapter = {}

local _visual_on_cast = esp_renderer.on_cast
function esp_renderer.on_cast(spell_id, name, col, target_name)
    if spell_id and core and core.time and core.spell_book and core.spell_book.get_spell_cooldown then
        local now_s = _core_time()
        local cd_s = tonumber(_get_spell_cd(spell_id)) or 0
        cooldown_tracker.set_next_spell(spell_id, now_s, cd_s)
    end
    return _visual_on_cast(spell_id, name, col, target_name)
end

local function visual_get_ttd_seconds(target)
    if not _visual_ttd_tracker or not _visual_ttd_tracker.get then return "--" end
    local ok, value = pcall(function() return _visual_ttd_tracker.get(target) end)
    if not ok then return "--" end
    local ttd_value = tonumber(value)
    if not ttd_value then return "--" end
    return ttd_value
end

local _visual_tracked_auras = { n = 0 }

local function visual_build_tracked_auras(me, target)
    _visual_tracked_auras.n = 0
    if me and me:is_in_combat() then
        _visual_tracked_auras.n = _visual_tracked_auras.n + 1
        _visual_tracked_auras[_visual_tracked_auras.n] = { label = "Combat", active = true }
    end
    if target and target:is_valid() and not target:is_dead() then
        if target:is_casting_spell() then
            _visual_tracked_auras.n = _visual_tracked_auras.n + 1
            _visual_tracked_auras[_visual_tracked_auras.n] = { label = "Cast", active = true }
        end
        if target:is_channelling_spell() then
            _visual_tracked_auras.n = _visual_tracked_auras.n + 1
            _visual_tracked_auras[_visual_tracked_auras.n] = { label = "Channel", active = true }
        end
    end
    for i = _visual_tracked_auras.n + 1, 4 do
        _visual_tracked_auras[i] = nil
    end
    return _visual_tracked_auras
end

local function visual_update_snapshot(me, target)
    if not me then return end
    local in_combat = me:is_in_combat()
    if in_combat and not _visual_runtime.in_combat then
        dps_meter.on_combat_start()
        _visual_runtime.in_combat = true
        _visual_runtime.last_me_hp_pct = nil
        _visual_runtime.last_target_hp_pct = nil
    elseif (not in_combat) and _visual_runtime.in_combat then
        dps_meter.on_combat_end()
        _visual_runtime.in_combat = false
        _visual_runtime.last_me_hp_pct = nil
        _visual_runtime.last_target_hp_pct = nil
    end

    local me_hp_pct = tonumber(me:get_health_percentage())
    if in_combat and _visual_runtime.last_me_hp_pct and me_hp_pct and me_hp_pct > _visual_runtime.last_me_hp_pct then
        dps_meter.on_heal(me_hp_pct - _visual_runtime.last_me_hp_pct)
    end
    _visual_runtime.last_me_hp_pct = me_hp_pct

    local target_hp_pct = nil
    if target and target:is_valid() and not target:is_dead() then
        target_hp_pct = tonumber(target:get_health_percentage())
    end
    if in_combat and _visual_runtime.last_target_hp_pct and target_hp_pct and target_hp_pct < _visual_runtime.last_target_hp_pct then
        dps_meter.on_damage(_visual_runtime.last_target_hp_pct - target_hp_pct)
    end
    _visual_runtime.last_target_hp_pct = target_hp_pct

    reactive_runtime.update_tick(me, target, {
        adapter = reactive_adapter,
        encounter_manager = encounter_manager,
        state = _visual_runtime.reactive_state,
        spec = "EAXRogueAssassination",
    })

    local snapshot = visual_state.build_snapshot({
        now_s = _core_time(),
        ttd_seconds = visual_get_ttd_seconds(target),
        tracked_auras = visual_build_tracked_auras(me, target),
    })

    if esp_renderer.update_visual_snapshot then
        esp_renderer.update_visual_snapshot(snapshot)
    elseif esp_renderer.set_visual_snapshot then
        esp_renderer.set_visual_snapshot(snapshot)
    end
end

core.register_on_update_callback(function()
    if not menu or not menu.enabled or not menu.enabled:get_state() then return end
    local me = _get_local_player()
    if not me or me:is_dead() then return end
    local target = me:get_target()
    visual_update_snapshot(me, target)
end)
---@type ttd_tracker
local ttd_tracker = require("ttd_tracker")
---@type racial_manager
local racial_manager = require("eax_shared/racial_manager")
---@type defensive_manager
local defensive_manager = require("eax_shared/defensive_manager")
---@type threat_manager
local threat_manager = require("eax_shared/threat_manager")

-- Guard to init threat_manager only once at startup
local threat_initialized = false

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local runtime = {
    mutilate_id = nil,
    envenom_id = nil,
    eviscerate_id = nil,
    slice_and_dice_id = nil,
    rupture_id = nil,
    kick_id = nil,
    cold_blood_id = nil,
    shiv_id = nil,
    evasion_id = nil,
    combo_points = 0,
    combo_target = nil,
    cached_mode = "solo",
    prev_toggle_state = false,
    last_cast_time = 0,
    set_multiplier = 1.0,
}

local GCD_CAST_INTERVAL = 1.0  -- TBC GCD
local ASSA_FINISHER_COMBO_POINTS = 5
local SND_REFRESH_CRITICAL_MS = 2000
local SND_CLIP_GUARD_MS = 10000

local function resolve_spells()
    runtime.mutilate_id = utils.resolve_spell_id(spells.MUTILATE)
    runtime.envenom_id = utils.resolve_spell_id(spells.ENVENOM)
    runtime.eviscerate_id = utils.resolve_spell_id(spells.EVISCERATE)
    runtime.slice_and_dice_id = utils.resolve_spell_id(spells.SLICE_AND_DICE)
    runtime.rupture_id = utils.resolve_spell_id(spells.RUPTURE)
    runtime.kick_id  = utils.resolve_spell_id(spells.KICK)
    runtime.shiv_id  = utils.resolve_spell_id(spells.SHIV)
    runtime.cold_blood_id = utils.resolve_spell_id(spells.COLD_BLOOD)
    runtime.garrote_id = utils.resolve_spell_id(spells.GARROTE)
    runtime.riposte_id = utils.resolve_spell_id(spells.RIPOSTE)
end

local function log_resolved_spells()
    core.log(
        "[EAX Rogue Assassination] Resolved: Mut=" .. tostring(runtime.mutilate_id)
            .. " Env=" .. tostring(runtime.envenom_id)
            .. " SnD=" .. tostring(runtime.slice_and_dice_id)
            .. " Rupt=" .. tostring(runtime.rupture_id)
    )
end

resolve_spells()
log_resolved_spells()

local function current_mode()
    return utils.get_selected_mode(menu)
end

local function note_cast()
    runtime.last_cast_time = _core_time()
end

local function is_gcd_ready()
    if (_core_time() - runtime.last_cast_time) < GCD_CAST_INTERVAL then
        return false
    end

    return _get_gcd() <= 0
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


local function reset_combo_points_if_needed(me, target)
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


local function try_vanish(me, target)
    if not menu.use_vanish or not menu.use_vanish:get_state() then return false end
    if not runtime.vanish_id then return false end
    local hp = me:get_health_percentage() / 100
    if hp > 0.30 then return false end  -- emergency only
    if not utils.can_cast_self(runtime.vanish_id, me) then return false end
    if utils.cast_self(runtime.vanish_id, me) then
        utils.log_debug(menu, "Vanish (emergency)")
        return true
    end
    return false
end

local function try_sprint_rogue(me, target)
    if not menu.use_sprint or not menu.use_sprint:get_state() then return false end
    if not runtime.sprint_id then return false end
    if not target or not target:is_valid() then return false end
    if utils.has_buff(me, spells.BUFF_SPRINT) then return false end
    -- Use sprint when target is out of melee range
    if utils.is_melee_target(me, target) then return false end
    if not utils.can_cast_self(runtime.sprint_id, me) then return false end
    if utils.cast_self(runtime.sprint_id, me) then
        utils.log_debug(menu, "Sprint")
        return true
    end
    return false
end

local function try_blind(me, target)
    if not menu.use_blind or not menu.use_blind:get_state() then return false end
    if not runtime.blind_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    local hp = me:get_health_percentage() / 100
    if hp > 0.35 then return false end  -- defensive use when low
    if not utils.can_cast_hostile(runtime.blind_id, me, target) then return false end
    if utils.cast_target(runtime.blind_id, target) then
        utils.log_debug(menu, "Blind (defensive)")
        return true
    end
    return false
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

local function try_cold_blood(me)
    local mode = current_mode()
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_cold_blood:get_state() then
        return false
    end
    if mode == "solo" then
        return false
    end
    if not runtime.cold_blood_id then
        return false
    end
    if utils.get_buff_remaining_ms(me, spells.BUFF_COLD_BLOOD) > 0 then
        return false
    end
    if not utils.can_cast_self(runtime.cold_blood_id, me) then
        return false
    end

    if utils.cast_self_fast(runtime.cold_blood_id, me, "Cold Blood") then
        utils.log_debug(menu, "Cold Blood")
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

    local policy = encounter_manager.get_policy(me)
    local enemy_count = encounter_manager.enemy_count_in_range(me, 8)
    local min_combo_points = (enemy_count >= 2 or (policy and policy.burn_phase)) and 3 or 4
    if runtime.combo_points < min_combo_points or runtime.combo_points > ASSA_FINISHER_COMBO_POINTS then
        return false
    end

    local remaining_ms = utils.get_buff_remaining_ms(me, spells.BUFF_SLICE_AND_DICE)
    if remaining_ms > SND_CLIP_GUARD_MS then
        return false
    end
    if remaining_ms > SND_REFRESH_CRITICAL_MS and remaining_ms > 0 then
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

local function try_envenom(me, target)
    if not menu.use_envenom:get_state() then
        return false
    end
    if not runtime.envenom_id or not utils.can_attack(me, target) then
        return false
    end
    if runtime.combo_points < menu.envenom_combo_points:get() then
        return false
    end

    local poison_stacks = utils.get_debuff_stacks(target, spells.DEBUFF_DEADLY_POISON)
    if poison_stacks < menu.poison_stack_threshold:get() then
        return false
    end
    if not utils.can_cast_hostile(runtime.envenom_id, me, target) then
        return false
    end

    if not hold_offense and try_cold_blood(me) then
                esp_renderer.on_cast(nil, "Envenom", color.green(220))
        return true
    end

    if utils.cast_target(runtime.envenom_id, target, "Envenom") then
        utils.log_debug(menu, "Envenom at " .. tostring(poison_stacks) .. " stacks")
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
    if runtime.combo_points < menu.rupture_combo_points:get() then
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
    if runtime.combo_points < 4 then
        return false
    end
    if not utils.can_cast_hostile(runtime.eviscerate_id, me, target) then
        return false
    end

    if not hold_offense and try_cold_blood(me) then
        return true
    end

    if utils.cast_target(runtime.eviscerate_id, target, "Eviscerate") then
        utils.log_debug(menu, "Eviscerate")
        note_cast()
        return true
    end

    return false
end

local function try_mutilate(me, target)
    if not menu.use_mutilate:get_state() then
        return false
    end
    if not runtime.mutilate_id or not utils.can_attack(me, target) then
        return false
    end
    if runtime.combo_points >= 5 then
        return false
    end
    if not utils.can_cast_hostile(runtime.mutilate_id, me, target) then
        return false
    end

    if utils.cast_target(runtime.mutilate_id, target, "Mutilate") then
        utils.log_debug(menu, "Mutilate")
        note_cast()
                esp_renderer.on_cast(runtime.mutilate_id, "Mutilate", color.purple(220))
        return true
    end

    return false
end


-- --- Feint - threat drop (v1.3) ------------------------------------------

local function try_feint(me)
    if not menu.use_feint or not menu.use_feint:get_state() then return false end
    if not runtime.feint_id then return false end
    local mode = utils.get_selected_mode and utils.get_selected_mode(menu) or "solo"
    if mode == "solo" then return false end
    if not utils.can_cast_hostile(runtime.feint_id, me, me:get_target()) then return false end
    if utils.cast_target(runtime.feint_id, me:get_target(), "Feint") then
        utils.log_debug(menu, "Feint")
        return true
    end
    return false
end



local function try_shiv(me, target)
    if not menu.use_shiv or not menu.use_shiv:get_state() then return false end
    if not runtime.shiv_id then return false end
    local dp_remain = utils.get_debuff_remaining_ms(target, spells.DEBUFF_DEADLY_POISON)
    if dp_remain <= 0 or dp_remain > 2000 then return false end
    if not utils.can_cast_hostile(runtime.shiv_id, me, target) then return false end
    if utils.cast_target(runtime.shiv_id, target, "Shiv") then
        utils.log_debug(menu, "Shiv (Deadly Poison refresh)")
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
    enc = encounter_manager.get_policy(me)
    if target and interrupt_manager.should_interrupt(target) and not enc.hold_cooldowns then
        if interrupt_manager.try_interrupt(me, target, "rogue", utils) then
            return true
        end
    end

    -- Racial CDs
    local hold_offense = dps_risk.should_hold_offense(dps_runtime.build_snapshot(me, target, encounter_manager, ttd_tracker))
    if not hold_offense then
        racial_manager.try_offensive(me)
    end
    racial_manager.try_utility(me, target)
    racial_manager.try_defensive(me)

    -- Defensive abilities
    ttd_tracker.update(target)

    if defensive_manager.try_defensive(me, "rogue", utils) then
        return true
    end

    if try_vanish(me, target) then return true end
    if try_sprint_rogue(me, target) then return true end
    if try_blind(me, target) then return true end
    if try_kick(me, target) then
        return true
    end

    if not utils.can_attack(me, target) then
        return false
    end

    reset_combo_points_if_needed(me, target)

    if try_slice_and_dice(me) then return true end
    if try_feint(me) then return true end
    if try_envenom(me, target) then
        return true
    end
    if try_rupture(me, target) then
        return true
    end
    if try_eviscerate(me, target) then
        return true
    end
    if try_garrote(me, target) then return true end
    if try_shiv(me, target) then return true end
    if try_mutilate(me, target) then return true end

    -- Auto-attack fallback for leveling 1-70
    -- (ensure_melee_auto_attack is called in the core combat lanes above)

    return false
end

-- --- Evasion - emergency dodge CD (v1.8.2) -------------------------------

local function try_evasion(me)
    if not menu.use_evasion:get_state() then return false end
    if not runtime.evasion_id then
        runtime.evasion_id = utils.resolve_spell_id(spells.EVASION)
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

reactive_adapter = {
    spec = "EAXRogueAssassination",
    actions = {
        life_save_self = {
            handler = function(_, action_deps)
                return defensive_manager.try_defensive(action_deps.me, "rogue", utils)
            end,
        },
        life_save_ally = { noop = "unsupported" },
        interrupt_control = {
            handler = function(_, action_deps)
                local interrupt_target = action_deps.target or action_deps.current_target
                if not interrupt_target or not interrupt_target:is_valid() then
                    return false
                end

                if not interrupt_manager.should_interrupt(interrupt_target) then
                    return false
                end

                return interrupt_manager.try_interrupt(action_deps.me, interrupt_target, "rogue", utils)
            end,
        },
        anti_overheal = { noop = "unsupported" },
        anti_aggro = {
            handler = function(_, action_deps)
                local snapshot = dps_runtime.build_snapshot(action_deps.me, action_deps.current_target, encounter_manager, ttd_tracker)
                if not dps_risk.should_drop_threat(snapshot) then
                    return false
                end
                return try_vanish(action_deps.me, action_deps.current_target)
            end,
        },
        throughput_resume = { noop = "unsupported" },
    },
}

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
        local me = _get_local_player()
        if me then
            update_set_bonus(me)
        end
    end

    handle_toggle()
    if not menu.enabled:get_state() then
        return
    end

    local me = _get_local_player()
    if not me or me:is_dead() then
        return
    end
        ooc_manager.on_update(me, menu, utils)
    if (menu.auto_mount and menu.auto_mount:get_state()) or (menu.auto_dismount and menu.auto_dismount:get_state()) then
        mount_manager.update_mount_state(me, menu, utils)
    end

    if menu.auto_ooc_food_drink and menu.auto_ooc_food_drink:get_state() then
        consumables_manager.try_use_ooc_food_drink(me, menu, utils)
    end

    if menu.auto_repair and menu.auto_repair:get_state() then
        vendor_automation.try_auto_repair(me, menu, utils)
    end

    if menu.auto_sell_greys and menu.auto_sell_greys:get_state() then
        vendor_automation.try_auto_sell_greys(me, menu, utils)
    end

    if me:is_in_combat() then
        if menu.auto_combat_potions and menu.auto_combat_potions:get_state() then
            consumables_manager.try_use_combat_consumable(me, menu, utils)
        end
        if menu.auto_flask and menu.auto_flask:get_state() then
            consumables_manager.try_maintain_flask(me, menu, utils)
        end
    end

    if eax_utils.is_eating_or_drinking(me) then return end

    do_rotation(me, utils.find_best_target(me))
    
    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and focus_target:is_valid() then
        core.input.set_target(focus_target)
    end
    
    -- Self-emergency (Rogue has Sprint, Evasion, etc)
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.35, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_evasion then try_evasion(me) end
    end
end)



-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxrogueassassination_space_win")
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
        local label = "EAX Rogue Assa] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxrogueassassination_enabled_cp")
        if menu.enabled:get_state() then
        if menu.use_cooldowns then
            local cur_ras_cds = menu.use_cooldowns:get_state()
            local nxt_ras_cds = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX RAs] Cooldowns", cur_ras_cds, 0, false, "eax_ras_cds_cp")
            if nxt_ras_cds ~= cur_ras_cds then menu.use_cooldowns:set(nxt_ras_cds) end
        end
        if menu.focus_priority then
            local cur_ras_focus = menu.focus_priority:get_state()
            local nxt_ras_focus = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX RAs] Focus Priority", cur_ras_focus, 0, false, "eax_ras_focus_cp")
            if nxt_ras_focus ~= cur_ras_focus then menu.focus_priority:set(nxt_ras_focus) end
        end
        if menu.use_racial then
            local cur_ras_racial = menu.use_racial:get_state()
            local nxt_ras_racial = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX RAs] Use Racial", cur_ras_racial, 0, false, "eax_ras_racial_cp")
            if nxt_ras_racial ~= cur_ras_racial then menu.use_racial:set(nxt_ras_racial) end
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
    local _eax_spec  = "Assassination"
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
        local now = _core_time()
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
core.log("[EAX Rogue Assassination] Loaded " .. (_pi and _pi.plugin_version or "?"))
