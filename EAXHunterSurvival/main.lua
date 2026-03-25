-- main.lua  |  EAX Hunter Survival  |  TBC
-- Priority: Serpent Sting > Aimed Shot > Arcane Shot > Multi > Steady

local menu    = require("menu")
local spells  = require("spells")
local utils   = require("utils")
local rotation_context = require("rotation_context")
local resource_gate = require("resource_gate")
local eax_utils = require("eax_utils")
local color   = require("color")
---@type buff_manager
local buff_manager  = require("common/modules/buff_manager")
---@type interrupt_manager
local interrupt_manager = require("interrupt_manager")
---@type ooc_manager
local ooc_manager   = require("ooc_manager")
---@type vendor_automation
local vendor_automation = require("vendor_automation")
---@type consumables_manager
local consumables_manager = require("consumables_manager")
---@type mount_manager
local mount_manager = require("mount_manager")
---@type leveling_manager
local leveling_manager  = require("leveling_manager")
---@type encounter_manager
local encounter_manager = require("encounter_manager")
local enc = nil
---@type esp_renderer
local esp_renderer  = require("esp_renderer")
esp_renderer.init("sv", "Hunter SV")
-- Smart Cast Manager - addresses spam/sluggishness
local smart_cast_manager = require("smart_cast_manager")

-- Phase 04 visual telemetry wiring
local dps_meter = require("dps_meter")
local cooldown_tracker = require("cooldown_tracker")
local visual_state = require("visual_state")
local reactive_runtime = require("reactive_runtime")
local dps_risk = require("dps_risk")
local dps_runtime = require("dps_runtime")

-- Hot-path local caching (performance critical)
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown
local _get_spell_cd = core.spell_book.get_spell_cooldown

smart_cast_manager.init({
    core_time = _core_time,
    get_gcd = _get_gcd,
    get_spell_cd = _get_spell_cd,
})

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
        smart_cast_manager.clear_all_pending()
    elseif (not in_combat) and _visual_runtime.in_combat then
        dps_meter.on_combat_end()
        _visual_runtime.in_combat = false
        _visual_runtime.last_me_hp_pct = nil
        _visual_runtime.last_target_hp_pct = nil
        smart_cast_manager.reset()
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
        spec = "EAXHunterSurvival",
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
local ttd_tracker   = require("ttd_tracker")
---@type racial_manager
local racial_manager = require("racial_manager")
---@type defensive_manager
local defensive_manager = require("defensive_manager")
---@type threat_manager
local threat_manager = require("threat_manager")
---@type swing_timer
local swing_timer = require("swing_timer")

-- Guard to init threat_manager only once at startup
local threat_initialized = false

---@type control_panel_helper
local key_helper = require("common/utility/key_helper")
local control_panel_utility = require("common/utility/control_panel_helper")

local rt = {
    auto_shot_id        = nil,
    aimed_shot_id       = nil,
    arcane_shot_id      = nil,
    steady_shot_id      = nil,
    multi_shot_id       = nil,
    hunters_mark_id     = nil,
    serpent_sting_id    = nil,
    aspect_hawk_id      = nil,
    viper_aspect_id     = nil,
    raptor_strike_id    = nil,
    mongoose_bite_id    = nil,
    wing_clip_id        = nil,
    concussive_shot_id  = nil,
    kill_command_id     = nil,
    mend_pet_id         = nil,
    revive_pet_id       = nil,
    call_pet_id         = nil,
    disengage_id        = nil,
    feign_death_id      = nil,
    rapid_fire_id       = nil,
    explosive_trap_id   = nil,
    immolation_trap_id  = nil,
    freezing_trap_id    = nil,
    -- state
    last_wing_clip_cast_count = 0,
    last_concussive_cast_count = 0,
    last_disengage_cast_count = 0,
    last_kill_command_cast_count = 0,
    last_hunters_mark_cast_count = 0,
    last_serpent_sting_cast_count = 0,
    last_aspect_cast_count = 0,
    last_raptor_strike_cast_count = 0,
    last_mongoose_bite_cast_count = 0,
    last_arcane_shot_cast_count = 0,
    last_aimed_shot_cast_count = 0,
    last_steady_shot_cast_count = 0,
    last_multi_shot_cast_count = 0,
    last_rapid_fire_cast_count = 0,
    last_trap_time      = 0,
    last_spell_refresh  = 0,
    haste_breakpoint    = "2:1",
    cached_mode         = "solo",
    prev_toggle_state   = false,
}

local ctx_cache = rotation_context.new({
    important_buffs = {},
    important_debuffs = {},
})

local SPELL_REFRESH = 1.0
local MODE_REFRESH  = 4.5
local AUTO_CLIP_MS  = 200

local function resolve()
    local now = _core_time()
    if (now - rt.last_spell_refresh) < SPELL_REFRESH then return end
    rt.last_spell_refresh = now
    rt.auto_shot_id        = utils.resolve_spell_id(spells.AUTO_SHOT)
    rt.aimed_shot_id       = utils.resolve_spell_id(spells.AIMED_SHOT)
    rt.arcane_shot_id      = utils.resolve_spell_id(spells.ARCANE_SHOT)
    rt.steady_shot_id      = utils.resolve_spell_id(spells.STEADY_SHOT)
    rt.multi_shot_id       = utils.resolve_spell_id(spells.MULTI_SHOT)
    rt.hunters_mark_id     = utils.resolve_spell_id(spells.HUNTERS_MARK)
    rt.serpent_sting_id    = utils.resolve_spell_id(spells.SERPENT_STING)
    rt.aspect_hawk_id      = utils.resolve_spell_id(spells.ASPECT_OF_THE_HAWK)
    rt.viper_aspect_id     = utils.resolve_spell_id(spells.ASPECT_OF_THE_VIPER)
    rt.raptor_strike_id    = utils.resolve_spell_id(spells.RAPTOR_STRIKE)
    rt.mongoose_bite_id    = utils.resolve_spell_id(spells.MONGOOSE_BITE)
    rt.wing_clip_id        = utils.resolve_spell_id(spells.WING_CLIP)
    rt.concussive_shot_id  = utils.resolve_spell_id(spells.CONCUSSIVE_SHOT)
    rt.kill_command_id     = utils.resolve_spell_id(spells.KILL_COMMAND)
    rt.mend_pet_id         = utils.resolve_spell_id(spells.MEND_PET)
    rt.revive_pet_id       = utils.resolve_spell_id(spells.REVIVE_PET)
    rt.call_pet_id         = utils.resolve_spell_id(spells.CALL_PET)
    rt.disengage_id        = utils.resolve_spell_id(spells.DISENGAGE)
    rt.feign_death_id      = utils.resolve_spell_id(spells.FEIGN_DEATH)
    rt.rapid_fire_id       = utils.resolve_spell_id(spells.RAPID_FIRE)
    rt.explosive_trap_id   = utils.resolve_spell_id(spells.EXPLOSIVE_TRAP)
    rt.immolation_trap_id  = utils.resolve_spell_id(spells.IMMOLATION_TRAP)
    rt.freezing_trap_id    = utils.resolve_spell_id(spells.FREEZING_TRAP)
end

local function is_gcd_ready()
    return smart_cast_manager.is_gcd_ready()
end

local function invalidate_ctx()
    rotation_context.invalidate(ctx_cache)
end

local function is_pending_cast(spell_id)
    if not spell_id then return false end
    return smart_cast_manager.is_pending(spell_id)
end

local function mark_pending_cast(spell_id, timeout_s, options)
    if not spell_id then return end
    options = options or {}
    smart_cast_manager.on_cast_attempt(spell_id, options.action_key or "unknown", {
        triggers_gcd = true,
        category = options.category,
        cast_time = options.cast_time,
    })
end

-- Intelligent throttling for specific ability categories
local function should_throttle_dot(action_key)
    return smart_cast_manager.should_throttle(action_key, "dots")
end
local function should_throttle_filler(action_key)
    return smart_cast_manager.should_throttle(action_key, "filler")
end
local function should_throttle_aoe(action_key)
    return smart_cast_manager.should_throttle(action_key, "aoe")
end

local function get_me()  return _get_local_player() end
local function get_pet()
    local me = get_me(); if not me then return nil end
    local ok,p = pcall(function() return me:get_pet() end)
    return (ok and p and p:is_valid()) and p or nil
end
local function pet_alive()  local p = get_pet(); return p and not p:is_dead() end
local function is_moving()  local me = get_me(); return me and me.is_moving and me:is_moving() end
local function dist(t)
    local me = get_me(); if not me or not t then return 999 end
    local p1,p2 = me:get_position(), t:get_position()
    if not p1 or not p2 then return 999 end
    local dx,dy,dz = p1.x-p2.x, p1.y-p2.y, p1.z-p2.z
    return math.sqrt(dx*dx+dy*dy+dz*dz)
end
local function auto_eta(me)
    return swing_timer.get_time_to_swing(me) * 1000
end
local function allow_instant(me) return swing_timer.is_swing_safe(me, AUTO_CLIP_MS / 1000) end
local function can_cast_casted_spell(me, cast_time) return swing_timer.can_cast_before_swing(me, cast_time, 0.1) end
local function get_haste_breakpoint(me)
    local effective_speed = swing_timer.get_mh_speed(me)
    if not effective_speed or effective_speed <= 0 then
        effective_speed = 2.8
    end
    local base_speed = 2.8 -- typical base weapon speed assumption
    local haste = (base_speed / effective_speed) - 1
    if haste < 0.15 then return "2:1"
    elseif haste < 0.45 then return "1:1"
    elseif haste < 0.75 then return "1:2"
    else return "1:3"
    end
end

local function mana_pct(me)
    local ok,mp = pcall(function() return me:get_power(0) end)
    local ok2,mm = pcall(function() return me:get_max_power(0) end)
    if ok and ok2 and mm and mm>0 then return mp/mm end; return 1.0
end
local function hp_pct(me) return (me:get_health_percentage() or 100)/100 end
local function has_debuff(t, tbl)
    if not t or not t:is_valid() then return false end
    local d = t:get_debuff_data(tbl)
    if d and d.is_active then return true end
    d = t:get_aura_data(tbl)
    return d ~= nil and d.is_active == true
end
local function debuff_rem(t, tbl)
    if not t or not t:is_valid() then return 0 end
    local d = t:get_debuff_data(tbl)
    if d and d.is_active and (d.remaining or 0) > 0 then return d.remaining end
    d = t:get_aura_data(tbl)
    if d and d.is_active and (d.remaining or 0) > 0 then return d.remaining end
    return 0
end
local function detect_mode()
    local n=0
    for _,o in ipairs(core.object_manager.get_all_objects()) do
        if o and o:is_valid() and o:is_unit() and not o:is_dead() and o:is_party_member() then n=n+1 end
    end
    if n==0 then return "solo" elseif n<=4 then return "dungeon" end; return "raid"
end
local function active_mode()
    local s = menu.mode and menu.mode:get() or 1
    if s==2 then return "solo" elseif s==3 then return "dungeon" elseif s==4 then return "raid" end
    return rt.cached_mode
end
local _last_pet_attack_guid = nil
local function pet_attack(t)
    if not t or not t:is_valid() then return end
    local p = get_pet(); if not p then return end
    local ok, guid = pcall(function() return tostring(t:get_guid()) end)
    if not ok or not guid then return end
    if _last_pet_attack_guid == guid then return end
    _last_pet_attack_guid = guid
    core.input.pet_attack(t)
end

local function pet_is_engaged_on_target(pet, target)
    if not pet or not pet:is_valid() or pet:is_dead() or not target or not target:is_valid() or target:is_dead() then
        return false
    end

    local ok, pet_target = pcall(function() return pet:get_target() end)
    if ok and pet_target and pet_target:is_valid() and utils.same_unit and utils.same_unit(pet_target, target) then
        return true
    end

    local pp, tp = pet:get_position(), target:get_position()
    if not pp or not tp then
        return false
    end

    local dx, dy, dz = pp.x - tp.x, pp.y - tp.y, pp.z - tp.z
    return (dx * dx + dy * dy + dz * dz) <= 100
end

-- ── Aspects ───────────────────────────────────────────────────────────────────
local function try_aspect_viper(me)
    if not rt.viper_aspect_id then return false end
    if not menu.use_aspect_viper or not menu.use_aspect_viper:get_state() then return false end
    local mp    = mana_pct(me)
    local enter = (menu.viper_mana_enter and menu.viper_mana_enter:get() or 35)/100
    local exit  = (menu.viper_mana_exit  and menu.viper_mana_exit:get()  or 85)/100
    local on_viper = utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_VIPER)
    if on_viper and mp >= exit then
        if rt.aspect_hawk_id and utils.can_cast_self(rt.aspect_hawk_id, me) then
            rt.last_aspect_cast_count = core.spell_book.get_spell_cast_count(rt.aspect_hawk_id)
            utils.cast_self(rt.aspect_hawk_id, me)
            utils.log_debug(menu, "Aspect of the Hawk")
            return true
        end
        return false
    end
    if not on_viper and mp < enter then
        if utils.can_cast_self(rt.viper_aspect_id, me) then
            utils.cast_self(rt.viper_aspect_id, me)
            utils.log_debug(menu, "Aspect of the Viper"); return true
        end
    end
    return false
end
local function try_aspect(me)
    if not rt.aspect_hawk_id then return false end
    if utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_HAWK) then return false end
    if utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_VIPER) then return false end
    if rt.last_aspect_cast_count == core.spell_book.get_spell_cast_count(rt.aspect_hawk_id) then return false end
    if utils.can_cast_self(rt.aspect_hawk_id, me) then
        rt.last_aspect_cast_count = core.spell_book.get_spell_cast_count(rt.aspect_hawk_id)
        utils.cast_self(rt.aspect_hawk_id, me)
        utils.log_debug(menu, "Aspect of the Hawk"); return true
    end
    return false
end

-- ── Pet ───────────────────────────────────────────────────────────────────────
local function try_revive(me)
    if not menu.use_revive_pet or not menu.use_revive_pet:get_state() then return false end
    if pet_alive() then return false end
    if me:is_in_combat() then return false end  -- never summon/revive mid-combat

    local p = get_pet()
    if p and p:is_dead() then
        -- Pet died - Revive Pet (long cast, OOC only)
        if rt.revive_pet_id and utils.can_cast_self(rt.revive_pet_id, me) then
            utils.cast_self(rt.revive_pet_id, me)
            utils.log_debug(menu, "Revive Pet"); return true
        end
    elseif not p then
        -- No pet summoned at all - Call Pet
        if rt.call_pet_id and utils.can_cast_self(rt.call_pet_id, me) then
            utils.cast_self(rt.call_pet_id, me)
            utils.log_debug(menu, "Call Pet"); return true
        end
    end
    return false
end
local function try_mend(me)
    if not menu.use_mend_pet or not menu.use_mend_pet:get_state() then return false end
    if not rt.mend_pet_id then return false end
    local p = get_pet(); if not p or p:is_dead() then return false end
    local thresh = menu.mend_pet_hp and menu.mend_pet_hp:get() or 50
    if (p:get_health_percentage() or 100) > thresh then return false end
    -- Mend Pet has 15 yard range - only cast when pet is nearby
    local pp, mp = p:get_position(), me:get_position()
    if pp and mp then
        local dx,dy,dz = pp.x-mp.x, pp.y-mp.y, pp.z-mp.z
        if math.sqrt(dx*dx+dy*dy+dz*dz) > 14 then return false end
    end
    if is_moving() then return false end
    local bd = p:get_buff_data(spells.MEND_PET)
    if bd and bd.is_active then return false end
    if utils.can_cast_self(rt.mend_pet_id, me) then
        utils.cast_self(rt.mend_pet_id, me)
        utils.log_debug(menu, "Mend Pet"); return true
    end
    return false
end

-- ── Shots ─────────────────────────────────────────────────────────────────────
local function try_hunters_mark(me, t)
    if not menu.use_hunters_mark or not menu.use_hunters_mark:get_state() then return false end
    if not rt.hunters_mark_id then return false end
    if has_debuff(t, spells.DEBUFF_HUNTERS_MARK) then return false end
    if rt.last_hunters_mark_cast_count == core.spell_book.get_spell_cast_count(rt.hunters_mark_id) then return false end
    if not utils.can_cast_hostile(rt.hunters_mark_id, me, t) then return false end
    if utils.cast_target(rt.hunters_mark_id, t) then
        rt.last_hunters_mark_cast_count = core.spell_book.get_spell_cast_count(rt.hunters_mark_id)
        utils.log_debug(menu, "Hunter's Mark"); return true
    end
    return false
end
local function try_serpent_sting(me, t, ctx)
    if not menu.use_serpent_sting or not menu.use_serpent_sting:get_state() then return false end
    if not rt.serpent_sting_id then return false end
    if not resource_gate.hunter.has_mana_pct(ctx, 0.10) then return false end
    if debuff_rem(t, spells.DEBUFF_SERPENT_STING) > 3000 then return false end
    if rt.last_serpent_sting_cast_count == core.spell_book.get_spell_cast_count(rt.serpent_sting_id) then return false end
    if not allow_instant(me) then return false end
    if not utils.can_cast_hostile(rt.serpent_sting_id, me, t) then return false end
    if utils.cast_target(rt.serpent_sting_id, t) then
        rt.last_serpent_sting_cast_count = core.spell_book.get_spell_cast_count(rt.serpent_sting_id)
        utils.log_debug(menu, "Serpent Sting")
        esp_renderer.on_cast(rt.serpent_sting_id, "Serpent Sting", color.green(220))
        return true
    end
    return false
end
local function try_arcane_shot(me, t, ctx)
    if not menu.use_arcane_shot or not menu.use_arcane_shot:get_state() then return false end
    if not rt.arcane_shot_id then return false end
    if not resource_gate.hunter.has_mana_pct(ctx, 0.15) then return false end
    if not allow_instant(me) then return false end
    if rt.last_arcane_shot_cast_count == core.spell_book.get_spell_cast_count(rt.arcane_shot_id) then return false end
    if not utils.can_cast_hostile(rt.arcane_shot_id, me, t) then return false end
    if utils.cast_target(rt.arcane_shot_id, t) then
        rt.last_arcane_shot_cast_count = core.spell_book.get_spell_cast_count(rt.arcane_shot_id)
        utils.log_debug(menu, "Arcane Shot"); return true
    end
    return false
end
local function try_multi_shot(me, t, ctx)
    if enc and not enc.aoe_safe then return false end
    if not menu.use_multi_shot or not menu.use_multi_shot:get_state() then return false end
    if not rt.multi_shot_id then return false end
    if not resource_gate.hunter.has_mana_pct(ctx, 0.20) then return false end
    if encounter_manager.enemy_count_in_range(me, 10) < 2 then return false end
    if active_mode()=="solo" then return false end
    if is_moving() then return false end
    if not allow_instant(me) then return false end
    if rt.last_multi_shot_cast_count == core.spell_book.get_spell_cast_count(rt.multi_shot_id) then return false end
    if not utils.can_cast_hostile(rt.multi_shot_id, me, t) then return false end
    if utils.cast_target(rt.multi_shot_id, t) then
        rt.last_multi_shot_cast_count = core.spell_book.get_spell_cast_count(rt.multi_shot_id)
        utils.log_debug(menu, "Multi-Shot"); return true
    end
    return false
end
local function try_aimed_shot(me, t)
    if not menu.use_aimed_shot or not menu.use_aimed_shot:get_state() then return false end
    if not rt.aimed_shot_id then return false end
    if is_moving() then return false end
    if not can_cast_casted_spell(me, 2.0) then return false end
    if rt.last_aimed_shot_cast_count == core.spell_book.get_spell_cast_count(rt.aimed_shot_id) then return false end
    if not utils.can_cast_hostile(rt.aimed_shot_id, me, t) then return false end
    if utils.cast_target(rt.aimed_shot_id, t) then
        rt.last_aimed_shot_cast_count = core.spell_book.get_spell_cast_count(rt.aimed_shot_id)
        utils.log_debug(menu, "Aimed Shot"); return true
    end
    return false
end
local function try_steady_shot(me, t)
    if not menu.use_steady_shot or not menu.use_steady_shot:get_state() then return false end
    if not rt.steady_shot_id then return false end
    if is_moving() then return false end
    if not can_cast_casted_spell(me, 1.5) then return false end
    if rt.last_steady_shot_cast_count == core.spell_book.get_spell_cast_count(rt.steady_shot_id) then return false end
    if not utils.can_cast_hostile(rt.steady_shot_id, me, t) then return false end
    if utils.cast_target(rt.steady_shot_id, t) then
        rt.last_steady_shot_cast_count = core.spell_book.get_spell_cast_count(rt.steady_shot_id)
        utils.log_debug(menu, "Steady Shot")
        esp_renderer.on_cast(rt.steady_shot_id, "Steady Shot", color.cyan(220))
        return true
    end
    return false
end
local function try_kill_command(me, t)
    if not menu.use_kill_command or not menu.use_kill_command:get_state() then return false end
    if not rt.kill_command_id or not pet_alive() then return false end
    if rt.last_kill_command_cast_count == core.spell_book.get_spell_cast_count(rt.kill_command_id) then return false end
    local pet = get_pet()
    if not pet_is_engaged_on_target(pet, t) then return false end
    if not allow_instant(me) then return false end
    if not utils.can_cast_hostile(rt.kill_command_id, me, t) then return false end
    if utils.cast_target(rt.kill_command_id, t) then
        rt.last_kill_command_cast_count = core.spell_book.get_spell_cast_count(rt.kill_command_id)
        utils.log_debug(menu, "Kill Command")
        esp_renderer.on_cast(rt.kill_command_id, "Kill Command", color.red(220))
        return true
    end
    return false
end
local function try_rapid_fire(me)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_rapid_fire or not menu.use_rapid_fire:get_state() then return false end
    if not rt.rapid_fire_id or not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_RAPID_FIRE) then return false end
    if rt.last_rapid_fire_cast_count == core.spell_book.get_spell_cast_count(rt.rapid_fire_id) then return false end
    if utils.can_cast_self(rt.rapid_fire_id, me) then
        rt.last_rapid_fire_cast_count = core.spell_book.get_spell_cast_count(rt.rapid_fire_id)
        utils.cast_self(rt.rapid_fire_id, me)
        utils.log_debug(menu, "Rapid Fire")
        esp_renderer.on_cast(rt.rapid_fire_id, "Rapid Fire", color.gold(240))
        return true
    end
    return false
end
local function try_raptor_strike(me, t)
    if not menu.use_raptor_strike or not menu.use_raptor_strike:get_state() then return false end
    if not rt.raptor_strike_id or dist(t)>5 then return false end
    if rt.last_raptor_strike_cast_count == core.spell_book.get_spell_cast_count(rt.raptor_strike_id) then return false end
    if not utils.can_cast_hostile(rt.raptor_strike_id, me, t) then return false end
    if utils.cast_target(rt.raptor_strike_id, t) then
        rt.last_raptor_strike_cast_count = core.spell_book.get_spell_cast_count(rt.raptor_strike_id)
        utils.log_debug(menu, "Raptor Strike"); return true
    end
    return false
end
local function try_mongoose_bite(me, t, ctx)
    if not menu.use_mongoose_bite or not menu.use_mongoose_bite:get_state() then return false end
    if not rt.mongoose_bite_id or dist(t) > 5 then return false end
    if not resource_gate.hunter.has_mana_pct(ctx, 0.10) then return false end
    if rt.last_mongoose_bite_cast_count == core.spell_book.get_spell_cast_count(rt.mongoose_bite_id) then return false end
    if not utils.can_cast_hostile(rt.mongoose_bite_id, me, t) then return false end
    if utils.cast_target(rt.mongoose_bite_id, t) then
        rt.last_mongoose_bite_cast_count = core.spell_book.get_spell_cast_count(rt.mongoose_bite_id)
        utils.log_debug(menu, "Mongoose Bite"); return true
    end
    return false
end
local function try_wing_clip(me, t)
    if not menu.use_wing_clip or not menu.use_wing_clip:get_state() then return false end
    if not rt.wing_clip_id or dist(t)>5 then return false end
    if has_debuff(t, spells.DEBUFF_WING_CLIP) then return false end
    if rt.last_wing_clip_cast_count == core.spell_book.get_spell_cast_count(rt.wing_clip_id) then return false end
    if not utils.can_cast_hostile(rt.wing_clip_id, me, t) then return false end
    if utils.cast_target(rt.wing_clip_id, t) then
        rt.last_wing_clip_cast_count = core.spell_book.get_spell_cast_count(rt.wing_clip_id)
        utils.log_debug(menu, "Wing Clip"); return true
    end
    return false
end
local function try_concussive(me, t)
    if not menu.use_concussive or not menu.use_concussive:get_state() then return false end
    if not rt.concussive_shot_id then return false end
    -- Don't recast while slow is active
    if has_debuff(t, spells.DEBUFF_CONCUSSIVE) then return false end
    if rt.last_concussive_cast_count == core.spell_book.get_spell_cast_count(rt.concussive_shot_id) then return false end
    if not allow_instant(me) then return false end
    if not utils.can_cast_hostile(rt.concussive_shot_id, me, t) then return false end
    if utils.cast_target(rt.concussive_shot_id, t) then
        rt.last_concussive_cast_count = core.spell_book.get_spell_cast_count(rt.concussive_shot_id)
        utils.log_debug(menu, "Concussive Shot"); return true
    end
    return false
end
local function try_disengage(me)
    if not menu.use_disengage or not menu.use_disengage:get_state() then return false end
    if not rt.disengage_id then return false end
    if rt.last_disengage_cast_count == core.spell_book.get_spell_cast_count(rt.disengage_id) then return false end
    if utils.can_cast_self(rt.disengage_id, me) then
        utils.cast_self(rt.disengage_id, me)
        rt.last_disengage_cast_count = core.spell_book.get_spell_cast_count(rt.disengage_id)
        utils.log_debug(menu, "Disengage"); return true
    end
    return false
end
local function try_feign_death(me)
    if not menu.use_feign_death or not menu.use_feign_death:get_state() then return false end
    if not rt.feign_death_id then return false end
    local thresh = (menu.feign_death_hp and menu.feign_death_hp:get() or 20)/100
    if hp_pct(me) > thresh then return false end
    if utils.can_cast_self(rt.feign_death_id, me) then
        utils.cast_self(rt.feign_death_id, me)
        utils.log_debug(menu, "Feign Death"); return true
    end
    return false
end
local function try_trap(me, t)
    if not menu.use_traps or not menu.use_traps:get_state() then return false end
    if dist(t) > 6 then return false end
    local interval = menu.trap_interval and menu.trap_interval:get() or 30
    if (_core_time() - rt.last_trap_time) < interval then return false end
    local sel = menu.trap_selection and menu.trap_selection:get() or 1
    local tid
    if sel == 1 then
        if menu.use_immolation_trap and menu.use_immolation_trap:get_state() then
            tid = rt.immolation_trap_id
        end
    elseif sel == 2 then
        if menu.use_explosive_trap and menu.use_explosive_trap:get_state() then
            tid = rt.explosive_trap_id
        end
    elseif sel == 3 then tid = rt.freezing_trap_id end
    if not tid then return false end
    if utils.can_cast_self(tid, me) then
        utils.cast_self(tid, me); rt.last_trap_time = _core_time()
        utils.log_debug(menu, "Trap placed"); return true
    end
    return false
end

-- ── Rotation ──────────────────────────────────────────────────────────────────
local function do_rotation(me, t)
    local d = dist(t)
    local deps = { now_s = _core_time, get_gcd = _get_gcd }
    local ctx = rotation_context.get(ctx_cache, me, t, deps)


    if try_feign_death(me) then return end

    if d <= 8 then
        try_concussive(me, t)
        try_wing_clip(me, t)
        if try_disengage(me) then return end
        -- No disengage available - fall through and keep shooting
    end

    if try_aspect_viper(me) then return end
    if try_aspect(me) then return end

    -- Update haste breakpoint detection
    rt.haste_breakpoint = get_haste_breakpoint(me)

    if interrupt_manager.should_interrupt(t) then
        interrupt_manager.try_interrupt(me, t, "hunter", utils)
    end

    enc = encounter_manager.get_policy(me)
    local hold_offense = dps_risk.should_hold_offense(dps_runtime.build_snapshot(me, t, encounter_manager, ttd_tracker))
    if not hold_offense then
        racial_manager.try_offensive(me)
    end
    racial_manager.try_utility(me, t)
    racial_manager.try_defensive(me)
    if not hold_offense then try_rapid_fire(me) end
    if defensive_manager.try_defensive(me, "hunter", utils) then return end
    ttd_tracker.update(t)

    if pet_alive() then
        pet_attack(t)
        try_kill_command(me, t)
    end
    try_mend(me)
    if try_trap(me, t) then return end
    if try_hunters_mark(me, t) then return end

    if me:is_in_combat() and d > 5 and d <= 40 and not is_moving() then
        leveling_manager.ensure_ranged(me, t)
    end

    if d > 40 then return end

    if utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_VIPER)
        and mana_pct(me) < ((menu.viper_mana_exit and menu.viper_mana_exit:get() or 85) / 100) then
        return
    end

    if try_serpent_sting(me, t, ctx) then
        invalidate_ctx()
        return
    end

    if try_aimed_shot(me, t) then return end
    if try_multi_shot(me, t, ctx) then
        invalidate_ctx()
        return
    end
    if try_arcane_shot(me, t, ctx) then
        invalidate_ctx()
        return
    end
    if try_steady_shot(me, t) then return end

    if d <= 5 then
        if try_mongoose_bite(me, t, ctx) then
            invalidate_ctx()
            return
        end
        try_raptor_strike(me, t)
    end
    if me:is_in_combat() and not is_moving() then
        leveling_manager.ensure_ranged(me, t)
    end
end

local function handle_toggle()
    local cur = menu.toggle_key and menu.toggle_key:get_state()
    if cur and not rt.prev_toggle_state then menu.enabled:set(not menu.enabled:get_state()) end
    rt.prev_toggle_state = cur or false
end

local function on_update()
    resolve()

    if utils.throttle("sv_mode", MODE_REFRESH) then rt.cached_mode = utils.detect_mode(me) end
    handle_toggle()
    if not menu.enabled or not menu.enabled:get_state() then return end
    local me = get_me()
    if not me or me:is_dead() then return end
    if not threat_initialized then threat_manager.init(me); threat_initialized = true end
    ooc_manager.on_update(me, menu, utils, {})
    if (menu.auto_mount and menu.auto_mount:get_state()) or (menu.auto_dismount and menu.auto_dismount:get_state()) then
        mount_manager.update_mount_state(me, menu, utils)
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
    if try_revive(me) then return end
    local focus = eax_utils.get_focus_target(menu)
    if focus and not me:can_attack(focus) then focus = nil end
    local t = focus or utils.find_best_target(me)
    if not t or not t:is_valid() or t:is_dead() then
        _last_pet_attack_guid = nil
        -- No target: keep pet defensive and following us so it doesn't roam
        if utils.throttle("pet_ctrl_idle", 2.0) then
            local ok, pet = pcall(function() return me:get_pet() end)
            if ok and pet and pet:is_valid() and not pet:is_dead() then
                if menu.pet_aggressive and menu.pet_aggressive:get_state() then
                    core.input.set_pet_aggressive()
                else
                    core.input.set_pet_defensive()
                end
                core.input.set_pet_follow()
            end
        end
        return
    end
    -- Enforce Defensive in combat so pet only attacks explicit targets
    if utils.throttle("pet_ctrl_combat", 3.0) then
        local ok, pet = pcall(function() return me:get_pet() end)
        if ok and pet and pet:is_valid() and not pet:is_dead() then
            core.input.set_pet_defensive()
        end
    end
    do_rotation(me, t)
end

reactive_adapter = {
    spec = "EAXHunterSurvival",
    actions = {
        life_save_self = {
            handler = function(_, action_deps)
                return defensive_manager.try_defensive(action_deps.me, "hunter", utils)
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

                return interrupt_manager.try_interrupt(action_deps.me, interrupt_target, "hunter", utils)
            end,
        },
        anti_overheal = { noop = "unsupported" },
        anti_aggro = {
            handler = function(_, action_deps)
                local snapshot = dps_runtime.build_snapshot(action_deps.me, action_deps.current_target, encounter_manager, ttd_tracker)
                if not dps_risk.should_drop_threat(snapshot) then
                    return false
                end
                return try_feign_death(action_deps.me)
            end,
        },
        throughput_resume = { noop = "unsupported" },
    },
}

local function on_render() esp_renderer.on_render(menu) end

core.register_on_render_callback(function()
    if menu and menu.enabled and menu.enabled:get_state() then on_render() end
end)
core.register_on_update_callback(on_update)

local _vec2 = require("common/geometry/vector_2")
local _win  = core.menu.window("eaxhuntersv_win")
_win:set_initial_size(_vec2.new(460, 640))
_win:set_next_window_min_size(_vec2.new(320, 300))
_win:set_next_window_padding(_vec2.new(10, 8))
menu.set_window(_win)
core.register_on_render_menu_callback(menu.render)


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
        local lbl_enabled = "[EAX SV] Enabled"
        if toggle_key ~= 7 then
            lbl_enabled = lbl_enabled .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        add_cb(lbl_enabled, menu.enabled, "eax_sv_enabled_cp")
        return elements
    end)
end

do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    if not _G.__EAX_LOADED["Hunter"] then _G.__EAX_LOADED["Hunter"] = {} end
    _G.__EAX_LOADED["Hunter"]["Survival"] = function()
        return menu and menu.enabled and menu.enabled:get_state()
    end
end

core.log("[EAX Hunter SV] Loaded")
return {}
