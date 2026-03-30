-- main.lua  |  Eax Hunter Marksmanship  |  TBC
-- Priority: Kill Command > Aimed Shot > Serpent Sting > Arcane Shot > Multi > Steady

local menu    = require("menu")
local spells  = require("spells")
local utils   = require("utils")
local creature_utils = require("creature_utils")
local rotation_context = require("rotation_context")
local resource_gate = require("resource_gate")
local eax_utils = require("eax_utils")
local color   = require("color")
local common_color = nil
local function to_api_color(c)
    if not common_color then
        local ok, mod = pcall(require, "common/color")
        if ok then common_color = mod end
    end
    if common_color and c and type(c) == "table" and c.r and c.g and c.b then
        return common_color.new(c.r, c.g, c.b, c.a)
    end
    return c
end
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
esp_renderer.init("mm", "Hunter MM")
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
        spec = "EAXHunterMarksmanship",
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
    kill_command_id     = nil,
    hunters_mark_id     = nil,
    serpent_sting_id    = nil,
    scorpid_sting_id    = nil,
    viper_sting_id      = nil,
    aspect_hawk_id      = nil,
    viper_aspect_id     = nil,
    raptor_strike_id    = nil,
    wing_clip_id        = nil,
    concussive_shot_id  = nil,
    mend_pet_id         = nil,
    revive_pet_id       = nil,
    call_pet_id         = nil,
    disengage_id        = nil,
    feign_death_id      = nil,
    rapid_fire_id       = nil,
    misdirection_id     = nil,
    immolation_trap_id  = nil,
    freezing_trap_id    = nil,
    trueshot_aura_id    = nil,
    deterrence_id       = nil,
    flare_id            = nil,
    scare_beast_id      = nil,
    -- state
    last_wing_clip_cast_count = 0,
    last_concussive_cast_count = 0,
    last_viper_sting_cast_count = 0,
    last_disengage_cast_count = 0,
    last_kill_command_cast_count = 0,
    last_hunters_mark_cast_count = 0,
    last_serpent_sting_cast_count = 0,
    last_scorpid_sting_cast_count = 0,
    last_aspect_cast_count = 0,
    last_raptor_strike_cast_count = 0,
    last_arcane_shot_cast_count = 0,
    last_aimed_shot_cast_count = 0,
    last_steady_shot_cast_count = 0,
    last_multi_shot_cast_count = 0,
    last_bestial_wrath_cast_count = 0,
    last_rapid_fire_cast_count = 0,
    last_misdirection_cast_count = 0,
    last_intimidation_cast_count = 0,
    last_trap_time      = 0,
    last_deterrence_cast_count = -1,
    last_scare_beast_cast_count = -1,
    last_flare_time     = 0,
    pet_autocast_guid   = nil,
    pet_autocast_mode   = nil,
    pet_autocast_configured = false,
    kc_commit_started_at = 0,
    kc_commit_target_guid = nil,
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

local try_deterrence
local try_scare_beast
local try_flare
local sync_pet_autocast

local function resolve()
    local now = _core_time()
    if (now - rt.last_spell_refresh) < SPELL_REFRESH then return end
    rt.last_spell_refresh = now
    rt.auto_shot_id        = utils.resolve_spell_id(spells.AUTO_SHOT)
    rt.aimed_shot_id       = utils.resolve_spell_id(spells.AIMED_SHOT)
    rt.arcane_shot_id      = utils.resolve_spell_id(spells.ARCANE_SHOT)
    rt.steady_shot_id      = utils.resolve_spell_id(spells.STEADY_SHOT)
    rt.multi_shot_id       = utils.resolve_spell_id(spells.MULTI_SHOT)
    rt.kill_command_id     = utils.resolve_spell_id(spells.KILL_COMMAND)
    rt.hunters_mark_id     = utils.resolve_spell_id(spells.HUNTERS_MARK)
    rt.serpent_sting_id    = utils.resolve_spell_id(spells.SERPENT_STING)
    rt.scorpid_sting_id    = utils.resolve_spell_id(spells.SCORPID_STING)
    rt.viper_sting_id      = utils.resolve_spell_id(spells.VIPER_STING)
    rt.aspect_hawk_id      = utils.resolve_spell_id(spells.ASPECT_OF_THE_HAWK)
    rt.viper_aspect_id     = utils.resolve_spell_id(spells.ASPECT_OF_THE_VIPER)
    rt.aspect_cheetah_id   = utils.resolve_spell_id(spells.ASPECT_OF_THE_CHEETAH)
    rt.aspect_pack_id      = utils.resolve_spell_id(spells.ASPECT_OF_THE_PACK)
    rt.raptor_strike_id    = utils.resolve_spell_id(spells.RAPTOR_STRIKE)
    rt.wing_clip_id        = utils.resolve_spell_id(spells.WING_CLIP)
    rt.concussive_shot_id  = utils.resolve_spell_id(spells.CONCUSSIVE_SHOT)
    rt.mend_pet_id         = utils.resolve_spell_id(spells.MEND_PET)
    rt.revive_pet_id       = utils.resolve_spell_id(spells.REVIVE_PET)
    rt.call_pet_id         = utils.resolve_spell_id(spells.CALL_PET)
    rt.disengage_id        = utils.resolve_spell_id(spells.DISENGAGE)
    rt.feign_death_id      = utils.resolve_spell_id(spells.FEIGN_DEATH)
    rt.rapid_fire_id       = utils.resolve_spell_id(spells.RAPID_FIRE)
    rt.misdirection_id     = utils.resolve_spell_id(spells.MISDIRECTION)
    rt.immolation_trap_id  = utils.resolve_spell_id(spells.IMMOLATION_TRAP)
    rt.freezing_trap_id    = utils.resolve_spell_id(spells.FREEZING_TRAP)
    rt.trueshot_aura_id    = utils.resolve_spell_id(spells.TRUESHOT_AURA)
    rt.deterrence_id       = utils.resolve_spell_id(spells.DETERRENCE)
    rt.flare_id            = utils.resolve_spell_id(spells.FLARE)
    rt.scare_beast_id      = utils.resolve_spell_id(spells.SCARE_BEAST)
end

local KILL_COMMAND_SETTLE_S = 0.20

local function pet_is_committed_on_target(pet, target, now)
    if not pet_is_engaged_on_target(pet, target) then
        rt.kc_commit_started_at = 0
        rt.kc_commit_target_guid = nil
        return false
    end

    local ok, target_guid = pcall(function() return tostring(target:get_guid()) end)
    if not ok or not target_guid then return false end

    if rt.kc_commit_target_guid ~= target_guid then
        rt.kc_commit_target_guid = target_guid
        rt.kc_commit_started_at = now or _core_time()
        return false
    end

    local started_at = rt.kc_commit_started_at or 0
    if started_at <= 0 then
        rt.kc_commit_started_at = now or _core_time()
        return false
    end

    return ((now or _core_time()) - started_at) >= KILL_COMMAND_SETTLE_S
end

-- -- Helpers -------------------------------------------------------------------
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

local function get_direct_focus_unit(current_target)
    local ok, focus = pcall(function() return core.input.get_focus() end)
    if not ok or not focus or not focus.is_valid or not focus:is_valid() or focus:is_dead() then return nil end
    if current_target and utils.same_unit and utils.same_unit(focus, current_target) then return nil end
    return focus
end

local function can_use_travel_aspect(me)
    if not me or me:is_in_combat() then return false end
    if not menu.auto_travel_aspect or not menu.auto_travel_aspect:get_state() then return false end
    if not is_moving() then return false end
    local ok_mounted, mounted = pcall(function() return me:is_mounted() end)
    if ok_mounted and mounted then return false end
    local ok_casting, casting = pcall(function() return me:is_casting_spell() end)
    local ok_channel, channeling = pcall(function() return me:is_channelling_spell() end)
    if (ok_casting and casting) or (ok_channel and channeling) then return false end
    return true
end

local function try_travel_aspect(me)
    if not can_use_travel_aspect(me) then return false end
    local use_pack = menu.use_pack_as_travel_aspect and menu.use_pack_as_travel_aspect:get_state()
    local mode = active_mode()
    local use_pack_now = use_pack and (mode == "dungeon" or mode == "raid")
    local travel_id = use_pack_now and rt.aspect_pack_id or rt.aspect_cheetah_id
    local travel_buff = use_pack_now and spells.BUFF_ASPECT_OF_THE_PACK or spells.BUFF_ASPECT_OF_THE_CHEETAH
    if not travel_id or utils.has_buff(me, travel_buff) then return false end
    if rt.last_aspect_cast_count == core.spell_book.get_spell_cast_count(travel_id) then return false end
    if utils.can_cast_self(travel_id, me) then
        rt.last_aspect_cast_count = core.spell_book.get_spell_cast_count(travel_id)
        utils.cast_self(travel_id, me)
        utils.log_debug(menu, use_pack_now and "Aspect of the Pack" or "Aspect of the Cheetah")
        return true
    end
    return false
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

-- -- Aspects -------------------------------------------------------------------
local function try_aspect_viper(me)
    if not rt.viper_aspect_id then return false end
    if not menu.use_aspect_viper or not menu.use_aspect_viper:get_state() then return false end
    local mp = mana_pct(me)
    local enter = (menu.viper_mana_enter and menu.viper_mana_enter:get() or 35)/100
    local exit  = (menu.viper_mana_exit  and menu.viper_mana_exit:get()  or 85)/100
    local on_viper = utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_VIPER)
    if on_viper and mp >= exit then
        if rt.aspect_hawk_id and utils.can_cast_self(rt.aspect_hawk_id, me) then
            utils.cast_self(rt.aspect_hawk_id, me)
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
    if me:is_in_combat() and (utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_CHEETAH) or utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_PACK)) then
        if rt.last_aspect_cast_count == core.spell_book.get_spell_cast_count(rt.aspect_hawk_id) then return false end
        if utils.can_cast_self(rt.aspect_hawk_id, me) then
            rt.last_aspect_cast_count = core.spell_book.get_spell_cast_count(rt.aspect_hawk_id)
            utils.cast_self(rt.aspect_hawk_id, me)
            utils.log_debug(menu, "Aspect of the Hawk"); return true
        end
    end
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

-- MM: Maintain Trueshot Aura OOC/in-combat (passive-ish aura)
local function try_trueshot_aura(me)
    if not menu.use_trueshot_aura or not menu.use_trueshot_aura:get_state() then return false end
    if not rt.trueshot_aura_id then return false end
    if utils.has_buff(me, spells.BUFF_TRUESHOT_AURA) then return false end
    if utils.can_cast_self(rt.trueshot_aura_id, me) then
        utils.cast_self(rt.trueshot_aura_id, me)
        utils.log_debug(menu, "Trueshot Aura"); return true
    end
    return false
end

local STEALTH = {1784, 1785, 1786, 1787}
local VANISH = {1856, 1857, 26889}
local PROWL = {5215, 9913}
local SHADOWMELD = {58984}
local INVIS = {66, 110959}
local SPRINT = {2983, 8696, 11305}
local DASH = {1850, 9821}

local function has_stealth_like_buff(unit)
    return utils.has_buff(unit, STEALTH)
        or utils.has_buff(unit, VANISH)
        or utils.has_buff(unit, PROWL)
        or utils.has_buff(unit, SHADOWMELD)
        or utils.has_buff(unit, INVIS)
end

local function get_unit_position(unit)
    if not unit then return nil end
    local ok, pos = pcall(function() return unit:get_position() end)
    if not ok then return nil end
    return pos
end

local function ensure_world_pos(pos)
    if not pos or type(pos.x) ~= "number" or type(pos.y) ~= "number" or type(pos.z) ~= "number" then return nil end
    if pos.clone then
        local ok, cloned = pcall(function() return pos:clone() end)
        if ok and cloned then return cloned end
    end
    local ok_vec3, vec3 = pcall(require, "common/geometry/vector_3")
    if ok_vec3 and vec3 and vec3.new then
        local ok_new, native = pcall(function() return vec3.new(pos.x, pos.y, pos.z) end)
        if ok_new and native then return native end
    end
    return pos
end

local function get_unit_guid(unit)
    if not unit then return nil end
    local ok, guid = pcall(function() return tostring(unit:get_guid()) end)
    if not ok then return nil end
    return guid
end

local function get_unit_class_id(unit)
    if not unit or not unit.get_class then return nil end
    local ok, class_id = pcall(function() return unit:get_class() end)
    return ok and class_id or nil
end

local function is_stealth_capable_class(class_id)
    return class_id == 4 or class_id == 11
end

local FLARE_SAFE_CAST_RANGE = 28.0

local function clamp_flare_cast_pos(me, pos)
    local me_pos = nil
    if me and me.get_position then
        local ok, result = pcall(function() return me:get_position() end)
        if ok then me_pos = result end
    end
    if not me_pos or not pos then return pos end
    if type(me_pos.x) ~= "number" or type(me_pos.y) ~= "number" or type(me_pos.z) ~= "number" then return pos end
    if type(pos.x) ~= "number" or type(pos.y) ~= "number" or type(pos.z) ~= "number" then return pos end
    local dx, dy, dz = pos.x - me_pos.x, pos.y - me_pos.y, pos.z - me_pos.z
    local dist2 = dx * dx + dy * dy + dz * dz
    if not dist2 or dist2 <= FLARE_SAFE_CAST_RANGE * FLARE_SAFE_CAST_RANGE then return pos end
    local dist = math.sqrt(dist2)
    if not dist or dist <= 0 then return pos end
    local scale = FLARE_SAFE_CAST_RANGE / dist
    local clamped = { x = me_pos.x + dx * scale, y = me_pos.y + dy * scale, z = me_pos.z + dz * scale }
    return ensure_world_pos(clamped) or pos
end

local function get_stealth_projection_profile(track)
    local class_id = track and track.class_id or nil
    if class_id == 4 then
        return { max_project_s = 2.6, speed_mult = 1.15 }
    elseif class_id == 11 then
        return { max_project_s = 2.2, speed_mult = 1.05 }
    end
    return { max_project_s = 2.0, speed_mult = 1.0 }
end

local function predict_stealth_position(track, current_pos)
    if not track or not current_pos then return current_pos end
    local now = _core_time()
    local start_pos = track.entry_pos or current_pos
    if type(start_pos.x) ~= "number" or type(start_pos.y) ~= "number" or type(start_pos.z) ~= "number" then return current_pos end
    if type(current_pos.x) ~= "number" or type(current_pos.y) ~= "number" or type(current_pos.z) ~= "number" then return current_pos end
    local pred_s = menu.stealth_prediction_s and menu.stealth_prediction_s:get() or 0
    local stealth_age = math.max(0, now - (track.stealth_ts or now))
    local profile = get_stealth_projection_profile(track)
    local project_s = math.min(profile.max_project_s or 2.0, stealth_age + pred_s)
    local vx = track.entry_vel_x or track.vel_x
    local vy = track.entry_vel_y or track.vel_y
    local vz = track.entry_vel_z or track.vel_z
    local speed = tonumber(track.entry_speed or track.speed) or 0
    speed = speed * (profile.speed_mult or 1.0)
    local clone_ok, predicted = pcall(function()
        if current_pos.clone then
            local p = current_pos:clone()
            p.x = start_pos.x
            p.y = start_pos.y
            p.z = start_pos.z
            if vx and vy and vz then
                p.x = p.x + vx * project_s
                p.y = p.y + vy * project_s
                p.z = p.z + vz * project_s
            elseif track.entry_dir_x and track.entry_dir_y then
                p.x = p.x + track.entry_dir_x * speed * project_s
                p.y = p.y + track.entry_dir_y * speed * project_s
                p.z = p.z + (track.entry_dir_z or 0) * speed * project_s
            end
            return p
        end
    end)
    if clone_ok and predicted then return predicted end
    return current_pos
end

local function capture_stealth_entry_snapshot(track, obj, now)
    if not track or track.entry_ts == now then return end
    track.entry_ts = now
    if track.pos then
        track.entry_pos = track.pos.clone and track.pos:clone() or { x = track.pos.x, y = track.pos.y, z = track.pos.z }
    end
    local speed_mult = 1.0
    if utils.has_buff(obj, SPRINT) then
        speed_mult = 1.7
    elseif utils.has_buff(obj, DASH) then
        speed_mult = 1.6
    end
    local base_speed = tonumber(track.speed) or 0
    track.entry_speed = math.max(base_speed, 4.5) * speed_mult
    track.entry_vel_x = (track.vel_x or 0) * speed_mult
    track.entry_vel_y = (track.vel_y or 0) * speed_mult
    track.entry_vel_z = (track.vel_z or 0) * speed_mult
    if obj and obj.get_movement_direction then
        local ok_dir, dir = pcall(function() return obj:get_movement_direction() end)
        if ok_dir and dir and type(dir.x) == "number" and type(dir.y) == "number" then
            track.entry_dir_x = dir.x
            track.entry_dir_y = dir.y
            track.entry_dir_z = dir.z or 0
        end
    end
end

local function find_nearby_stealth_target(me)
    local scan_radius = menu.stealth_scan_radius and menu.stealth_scan_radius:get() or 20
    local scan_r2 = scan_radius * scan_radius
    local me_pos = get_unit_position(me)
    if not me_pos then return nil end
    local now = _core_time()
    rt.stealth_tracks = rt.stealth_tracks or {}
    for _, track in pairs(rt.stealth_tracks) do
        if track then track.seen_this_scan = false end
    end
    local best, best_d2 = nil, scan_r2
    for _, obj in ipairs(core.object_manager.get_all_objects()) do
        local ok_valid, valid = pcall(function() return obj and obj:is_valid() end)
        local ok_attack, can_attack = pcall(function() return obj and me:can_attack(obj) end)
        if ok_valid and valid and obj and obj:is_unit() and not obj:is_dead() and ok_attack and can_attack then
            local pos = get_unit_position(obj)
            if pos and type(pos.x) == "number" and type(pos.y) == "number" and type(pos.z) == "number" then
                local dx, dy, dz = pos.x - me_pos.x, pos.y - me_pos.y, pos.z - me_pos.z
                local d2 = dx * dx + dy * dy + dz * dz
                local guid = get_unit_guid(obj)
                if guid and d2 <= scan_r2 then
                    local track = rt.stealth_tracks[guid] or { guid = guid }
                    track.pos = pos.clone and pos:clone() or { x = pos.x, y = pos.y, z = pos.z }
                    track.ts = now
                    track.last_seen = now
                    track.last_d2 = d2
                    if track.prev_pos and track.prev_ts and now > track.prev_ts then
                        local dt = now - track.prev_ts
                        if dt > 0 then
                            local dx = track.pos.x - track.prev_pos.x
                            local dy = track.pos.y - track.prev_pos.y
                            local dz = track.pos.z - track.prev_pos.z
                            track.speed = math.sqrt(dx*dx + dy*dy + dz*dz) / dt
                            track.vel_x = dx / dt
                            track.vel_y = dy / dt
                            track.vel_z = dz / dt
                        end
                    end
                    track.prev_pos = track.pos.clone and track.pos:clone() or { x = track.pos.x, y = track.pos.y, z = track.pos.z }
                    track.prev_ts = now
                    track.seen_this_scan = true
                    if track.class_id == nil then
                        track.class_id = get_unit_class_id(obj)
                    end
                    rt.stealth_tracks[guid] = track
                end
                if d2 <= best_d2 and has_stealth_like_buff(obj) then
                    if guid then
                        local track = rt.stealth_tracks[guid]
                        if not track then
                            track = { guid = guid }
                            rt.stealth_tracks[guid] = track
                        end
                        if not track.stealth_active then
                            track.stealth_ts = now
                            capture_stealth_entry_snapshot(track, obj, now)
                        end
                        track.stealth_active = true
                        track.inferred_stealth = false
                    end
                    best, best_d2 = obj, d2
                elseif guid then
                    local track = rt.stealth_tracks[guid]
                    if track then
                        track.stealth_active = false
                        track.inferred_stealth = false
                    end
                end
            end
        end
    end
    for guid, track in pairs(rt.stealth_tracks) do
        if track and track.seen_this_scan == false and is_stealth_capable_class(track.class_id) and track.last_seen and (now - track.last_seen) <= 0.75 and not track.stealth_active then
            track.stealth_ts = now
            track.stealth_active = true
            track.inferred_stealth = true
            if not track.entry_ts or track.entry_ts ~= now then
                track.entry_ts = now
                if track.pos then
                    track.entry_pos = track.pos.clone and track.pos:clone() or { x = track.pos.x, y = track.pos.y, z = track.pos.z }
                end
                track.entry_speed = math.max(tonumber(track.speed) or 0, 4.5)
                track.entry_vel_x = track.vel_x or 0
                track.entry_vel_y = track.vel_y or 0
                track.entry_vel_z = track.vel_z or 0
            end
        end
        if track then track.seen_this_scan = nil end
    end
    for guid, track in pairs(rt.stealth_tracks) do
        if not track.ts or (now - track.ts) > 8 then
            rt.stealth_tracks[guid] = nil
        end
    end
    return best
end

local function find_recent_stealth_track(me)
    local scan_radius = menu.stealth_scan_radius and menu.stealth_scan_radius:get() or 20
    local scan_r2 = scan_radius * scan_radius
    local now = _core_time()
    local best_track, best_d2 = nil, scan_r2
    rt.stealth_tracks = rt.stealth_tracks or {}
    for _, track in pairs(rt.stealth_tracks) do
        if track and track.pos and track.last_d2 and track.last_d2 <= best_d2 then
            local had_stealth = track.stealth_ts and (now - track.stealth_ts) <= 5.5
            if had_stealth then
                best_track = track
                best_d2 = track.last_d2
            end
        end
    end
    return best_track
end

local function render_stealth_overlay(me)
    if not menu.stealth_overlay_enabled or not menu.stealth_overlay_enabled:get_state() then return end
    rt.stealth_tracks = rt.stealth_tracks or {}
    local now = _core_time()
    local best_track, best_age = nil, 999
    for _, track in pairs(rt.stealth_tracks) do
        if track and track.pos and track.stealth_ts and (now - track.stealth_ts) <= 5.5 then
            local age = now - track.stealth_ts
            if age < best_age then best_track, best_age = track, age end
        end
    end
    if not best_track then return end
    local pos = ensure_world_pos(predict_stealth_position(best_track, best_track.pos))
    if not pos or type(pos.x) ~= "number" or type(pos.y) ~= "number" or type(pos.z) ~= "number" then return end
    local speed = tonumber(best_track.entry_speed or best_track.speed) or 0
    local age = math.max(0, now - (best_track.stealth_ts or now))
    local scan_radius = menu.stealth_scan_radius and menu.stealth_scan_radius:get() or 20
    local effective_speed = math.max(4.0, speed)
    local ring_r = math.min(math.min(24, scan_radius * 0.9), math.max(3.0, 3.0 + effective_speed * age * 1.1))
    local col = color.red(140)
    local api_col = to_api_color(col)
    local layers, steps = 10, 24
    for layer = layers, 1, -1 do
        local frac = layer / layers
        local layer_r = math.max(0.5, ring_r * frac)
        local layer_alpha = math.floor(28 + (1.0 - frac * 0.55) * 120)
        local layer_col = to_api_color(color.red(layer_alpha))
        for i = 1, steps do
            local a0 = (i - 1) * (math.pi * 2 / steps)
            local a1 = i * (math.pi * 2 / steps)
            local p1 = ensure_world_pos({ x = pos.x + math.cos(a0) * layer_r, y = pos.y + math.sin(a0) * layer_r, z = pos.z + 0.2 })
            local p2 = ensure_world_pos({ x = pos.x + math.cos(a1) * layer_r, y = pos.y + math.sin(a1) * layer_r, z = pos.z + 0.2 })
            if p1 and p2 and core.graphics.line_3d then pcall(core.graphics.line_3d, p1, p2, layer_col, 2.2) end
        end
    end
    local overlay_vx = best_track.entry_vel_x or best_track.vel_x
    local overlay_vy = best_track.entry_vel_y or best_track.vel_y
    local overlay_vz = best_track.entry_vel_z or best_track.vel_z
    if menu.stealth_overlay_direction and menu.stealth_overlay_direction:get_state() and speed > 0 and overlay_vx and overlay_vy and overlay_vz then
        local tick = ensure_world_pos({ x = pos.x + overlay_vx * math.min(math.max(3.0, ring_r * 0.65), 8.0), y = pos.y + overlay_vy * math.min(math.max(3.0, ring_r * 0.65), 8.0), z = pos.z + overlay_vz * math.min(math.max(3.0, ring_r * 0.65), 8.0) })
        if tick and core.graphics.line_3d then pcall(core.graphics.line_3d, pos, tick, api_col, 2.0) end
    end
    if core.graphics.text_3d then
        local me_pos = me and me.get_position and me:get_position() or nil
        local d = 0
        if me_pos then
            local dx, dy, dz = pos.x - me_pos.x, pos.y - me_pos.y, pos.z - me_pos.z
            d = math.sqrt(dx*dx + dy*dy + dz*dz)
        end
        local label_pos = ensure_world_pos({ x = pos.x, y = pos.y, z = pos.z + 1.5 })
        if label_pos then pcall(core.graphics.text_3d, string.format("Stealth ? %dy", math.floor(d + 0.5)), label_pos, 14, api_col) end
    end
end

local function try_auto_stealth_flare(me)
    local wants_flare = menu.auto_stealth_flare and menu.auto_stealth_flare:get_state()
    local wants_warning = menu.stealth_warning and menu.stealth_warning:get_state()
    if not wants_flare and not wants_warning then return false end
    local target = find_nearby_stealth_target(me)
    local guid, track, cast_pos, cast_target = nil, nil, nil, target
    if target then
        local pos = get_unit_position(target)
        if not pos then return false end
        guid = get_unit_guid(target)
        track = guid and rt.stealth_tracks and rt.stealth_tracks[guid] or nil
        cast_pos = clamp_flare_cast_pos(me, ensure_world_pos(predict_stealth_position(track, pos)))
    else
        track = find_recent_stealth_track(me)
        if not track or not track.pos then return false end
        guid = track.guid
        cast_pos = clamp_flare_cast_pos(me, ensure_world_pos(predict_stealth_position(track, track.pos)))
        cast_target = me
    end
    if not cast_pos then return false end
    if wants_warning and guid and track and track.stealth_ts and track.warned_stealth_ts ~= track.stealth_ts then
        esp_renderer.notify("stealth_flare_" .. guid, "Hunter Flare", "Stealth target detected.")
        track.warned_stealth_ts = track.stealth_ts
    end
    if not wants_flare or not rt.flare_id then return false end
    if (_core_time() - (rt.last_flare_attempt or 0)) < 0.40 then return false end
    if not (core.spell_book.is_spell_learned(rt.flare_id) and core.spell_book.get_spell_cooldown(rt.flare_id) <= 0 and core.spell_book.is_usable_spell(rt.flare_id)) then
        return false
    end
    local now = _core_time()
    rt.last_flare_attempt = now
    if utils.cast_position and utils.cast_position(rt.flare_id, cast_pos) then
        return true
    end
    return false
end

-- -- Pet -----------------------------------------------------------------------
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

-- -- Shots ---------------------------------------------------------------------
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
    -- Reapply Serpent Sting shortly before it falls off in TBC.
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
local function try_scorpid_sting(me, t)
    if not menu.use_scorpid_sting or not menu.use_scorpid_sting:get_state() then return false end
    if not rt.scorpid_sting_id then return false end
    if active_mode()=="solo" then return false end
    if has_debuff(t, spells.DEBUFF_SCORPID_STING) then return false end
    if rt.last_scorpid_sting_cast_count == core.spell_book.get_spell_cast_count(rt.scorpid_sting_id) then return false end
    if not allow_instant(me) then return false end
    if not utils.can_cast_hostile(rt.scorpid_sting_id, me, t) then return false end
    if utils.cast_target(rt.scorpid_sting_id, t) then
        rt.last_scorpid_sting_cast_count = core.spell_book.get_spell_cast_count(rt.scorpid_sting_id)
        utils.log_debug(menu, "Scorpid Sting"); return true
    end
    return false
end
local function try_viper_sting(me, t)
    if not menu.use_viper_sting or not menu.use_viper_sting:get_state() then return false end
    if not rt.viper_sting_id then return false end
    if has_debuff(t, spells.DEBUFF_VIPER_STING) then return false end
    if rt.last_viper_sting_cast_count == core.spell_book.get_spell_cast_count(rt.viper_sting_id) then return false end
    if not allow_instant(me) then return false end
    if not utils.can_cast_hostile(rt.viper_sting_id, me, t) then return false end
    if utils.cast_target(rt.viper_sting_id, t) then
        rt.last_viper_sting_cast_count = core.spell_book.get_spell_cast_count(rt.viper_sting_id)
        utils.log_debug(menu, "Viper Sting"); return true
    end
    return false
end
local function try_kill_command(me, t)
    if not rt.kill_command_id then return false end
    if not pet_alive() then return false end
    if rt.last_kill_command_cast_count == core.spell_book.get_spell_cast_count(rt.kill_command_id) then return false end
    local pet = get_pet()
    if not pet_is_committed_on_target(pet, t, _core_time()) then return false end
    if not allow_instant(me) then return false end
    if not utils.can_cast_hostile(rt.kill_command_id, me, t) then return false end
    if utils.cast_target(rt.kill_command_id, t) then
        rt.last_kill_command_cast_count = core.spell_book.get_spell_cast_count(rt.kill_command_id)
        utils.log_debug(menu, "Kill Command")
        esp_renderer.on_cast(rt.kill_command_id, "Kill Command", color.gold(220))
        return true
    end
    return false
end
local function try_aimed_shot(me, t, ctx)
    if not menu.use_aimed_shot or not menu.use_aimed_shot:get_state() then return false end
    if not rt.aimed_shot_id then return false end
    if not resource_gate.hunter.has_mana_pct(ctx, 0.20) then return false end
    if is_moving() then return false end
    if not can_cast_casted_spell(me, 2.0) then return false end
    if not utils.can_cast_hostile(rt.aimed_shot_id, me, t) then return false end
    if utils.cast_target(rt.aimed_shot_id, t) then
        utils.log_debug(menu, "Aimed Shot")
        esp_renderer.on_cast(rt.aimed_shot_id, "Aimed Shot", color.green(220))
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
local function try_steady_shot(me, t, ctx)
    if not menu.use_steady_shot or not menu.use_steady_shot:get_state() then return false end
    if not rt.steady_shot_id then return false end
    if not resource_gate.hunter.has_mana_pct(ctx, 0.05) then return false end
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
local function try_rapid_fire(me)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_rapid_fire or not menu.use_rapid_fire:get_state() then return false end
    if not rt.rapid_fire_id then return false end
    if not me:is_in_combat() then return false end
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

local function try_misdirection(me, t)
    if not menu.use_misdirection or not menu.use_misdirection:get_state() then return false end
    if not rt.misdirection_id then return false end
    if active_mode() == "solo" then return false end
    if not t or not t:is_valid() or t:is_dead() then return false end
    local focus = get_direct_focus_unit(t)
    if not focus or not focus:is_valid() or focus:is_dead() then return false end
    if focus == me or (utils.same_unit and utils.same_unit(focus, me)) then return false end
    if me:can_attack(focus) then return false end
    if utils.has_buff(me, spells.BUFF_MISDIRECTION) then return false end
    if rt.last_misdirection_cast_count == core.spell_book.get_spell_cast_count(rt.misdirection_id) then return false end
    if utils.cast_target(rt.misdirection_id, focus) then
        rt.last_misdirection_cast_count = core.spell_book.get_spell_cast_count(rt.misdirection_id)
        utils.log_debug(menu, "Misdirection")
        return true
    end
    return false
end
local function try_raptor_strike(me, t)
    if not menu.use_raptor_strike or not menu.use_raptor_strike:get_state() then return false end
    if not rt.raptor_strike_id or dist(t)>5 then return false end
    if not utils.can_cast_hostile(rt.raptor_strike_id, me, t) then return false end
    if utils.cast_target(rt.raptor_strike_id, t) then
        utils.log_debug(menu, "Raptor Strike"); return true
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
    local tid = sel==2 and rt.freezing_trap_id or rt.immolation_trap_id
    if not tid then return false end
    if utils.can_cast_self(tid, me) then
        utils.cast_self(tid, me); rt.last_trap_time = _core_time()
        utils.log_debug(menu, "Trap placed"); return true
    end
    return false
end

-- -- Rotation ------------------------------------------------------------------
local function do_rotation(me, t)
    local d = dist(t)
    local deps = { now_s = _core_time, get_gcd = _get_gcd }
    local ctx = rotation_context.get(ctx_cache, me, t, deps)


    if try_feign_death(me) then return end
    if try_deterrence(me) then return end

    if d <= 8 then
        try_concussive(me, t)
        try_wing_clip(me, t)
        if try_disengage(me) then return end
        -- No disengage available - fall through and keep shooting
    end

    -- Aura maintenance (passive)
    if try_travel_aspect(me) then return end
    if try_trueshot_aura(me) then return true end
    if try_aspect_viper(me) then return true end
    if try_aspect(me) then return true end

    -- Update haste breakpoint detection
    rt.haste_breakpoint = get_haste_breakpoint(me)

    if interrupt_manager.should_interrupt(t) then
        if interrupt_manager.try_interrupt(me, t, "hunter", utils) then return true end
    end

    enc = encounter_manager.get_policy(me)
    local hold_offense = dps_risk.should_hold_offense(dps_runtime.build_snapshot(me, t, encounter_manager, ttd_tracker))
    if not hold_offense and racial_manager.try_offensive(me) then return true end
    if racial_manager.try_utility(me, t) then return true end
    if racial_manager.try_defensive(me) then return true end
    if try_misdirection(me, t) then return true end
    if not hold_offense and try_rapid_fire(me) then return true end
    if defensive_manager.try_defensive(me, "hunter", utils) then return end
    ttd_tracker.update(t)

    if pet_alive() then pet_attack(t) end
    try_mend(me)
    if try_scare_beast(me, t) then return end
    if try_flare(me, t) then return end
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

    -- Sting group utility
    if try_scorpid_sting(me, t) then return end
    if try_viper_sting(me, t) then return end

    -- MM priority: Kill Command -> Aimed -> Serpent Sting -> Arcane -> Multi -> Steady
    if try_kill_command(me, t) then return end
    if try_aimed_shot(me, t, ctx) then
        invalidate_ctx()
        return
    end
    if try_serpent_sting(me, t, ctx) then
        invalidate_ctx()
        return
    end
    if try_arcane_shot(me, t, ctx) then
        invalidate_ctx()
        return
    end
    if try_multi_shot(me, t, ctx) then
        invalidate_ctx()
        return
    end
    if try_steady_shot(me, t, ctx) then
        invalidate_ctx()
        return
    end

    if d <= 5 then
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

    if utils.throttle("mm_mode", MODE_REFRESH) then rt.cached_mode = utils.detect_mode(me) end
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

    if try_auto_stealth_flare(me) then return end

    sync_pet_autocast(me)

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
    spec = "EAXHunterMarksmanship",
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

local function on_render()
    local me = get_me()
    if me then pcall(render_stealth_overlay, me) end
    esp_renderer.on_render(menu)
end

core.register_on_render_callback(function()
    if menu and menu.enabled and menu.enabled:get_state() then on_render() end
end)
core.register_on_update_callback(on_update)

local _vec2 = require("common/geometry/vector_2")
local _win  = core.menu.window("eaxhuntermm_win")
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
        local lbl_enabled = "[Eax MM] Enabled"
        if toggle_key ~= 7 then
            lbl_enabled = lbl_enabled .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        add_cb(lbl_enabled, menu.enabled, "eax_mm_enabled_cp")
        return elements
    end)
end

try_deterrence = function(me)
    if not menu.use_deterrence or not menu.use_deterrence:get_state() then return false end
    if not rt.deterrence_id then return false end
    if (me:get_health_percentage() or 100) > (menu.deterrence_hp and menu.deterrence_hp:get() or 12) then return false end
    if rt.last_deterrence_cast_count == core.spell_book.get_spell_cast_count(rt.deterrence_id) then return false end
    if utils.can_cast_self(rt.deterrence_id, me) then rt.last_deterrence_cast_count = core.spell_book.get_spell_cast_count(rt.deterrence_id); utils.cast_self(rt.deterrence_id, me); return true end
    return false
end

try_scare_beast = function(me, current_target)
    if not menu.use_scare_beast or not menu.use_scare_beast:get_state() then return false end
    if not rt.scare_beast_id then return false end
    local focus = get_direct_focus_unit(current_target); if not focus or not creature_utils.is_beast(focus) or not me:can_attack(focus) then return false end
    if rt.last_scare_beast_cast_count == core.spell_book.get_spell_cast_count(rt.scare_beast_id) then return false end
    if utils.cast_target(rt.scare_beast_id, focus) then rt.last_scare_beast_cast_count = core.spell_book.get_spell_cast_count(rt.scare_beast_id); return true end
    return false
end

try_flare = function(me, current_target)
    if not menu.use_flare or not menu.use_flare:get_state() then return false end
    if not rt.flare_id then return false end
    if (_core_time() - rt.last_flare_time) < 15 then return false end
    local focus = get_direct_focus_unit(current_target); if not focus then return false end
    local pos = focus:get_position(); if not pos then return false end
    local ok_spell_helper, spell_helper = pcall(require, "common/utility/spell_helper")
    if not ok_spell_helper or not spell_helper then return false end
    if not spell_helper.is_spell_castable_position or not spell_helper:is_spell_castable_position(rt.flare_id, me, focus, pos, false, false) then return false end
    if core.input.cast_spell_position and core.input.cast_spell_position(rt.flare_id, pos) then rt.last_flare_time = _core_time(); return true end
    return false
end

sync_pet_autocast = function(me)
    if not menu.sync_pet_autocast or not menu.sync_pet_autocast:get_state() then return end
    local ok, actions = pcall(function() return core.spell_book.get_pet_action_info() end)
    if not ok or type(actions) ~= "table" then return end
    local pet = get_pet(); if not pet then rt.pet_autocast_guid, rt.pet_autocast_mode, rt.pet_autocast_configured = nil, nil, false; return end
    local guid=nil; pcall(function() guid = tostring(pet:get_guid()) end)
    local mode = active_mode(); if rt.pet_autocast_configured and rt.pet_autocast_guid == guid and rt.pet_autocast_mode == mode then return end
    local want = { Claw=true, Bite=true, Gore=true, ["Lightning Breath"]=true, ["Poison Spit"]=true, ["Furious Howl"]=true, Screech=true, Thunderstomp=true }
    local function current_autocast_state(a)
        if type(a) ~= "table" then return nil end
        if a.autocast ~= nil then return a.autocast end
        if a.autocast_enabled ~= nil then return a.autocast_enabled end
        if a.is_autocast ~= nil then return a.is_autocast end
        if a.enabled ~= nil then return a.enabled end
        if a[3] ~= nil then return a[3] end
        if a[2] ~= nil then return a[2] end
        if type(a[1]) == "boolean" then return a[1] end
        return nil
    end
    for _, a in ipairs(actions) do local name = a and (a.name or a[1]); local autocast = current_autocast_state(a); if name and autocast ~= nil then local enabled = want[name] or (name == "Growl" and not (menu.disable_growl_in_group and menu.disable_growl_in_group:get_state() and mode ~= "solo")); if enabled ~= autocast then if enabled then core.input.enable_pet_autocast(name) else core.input.disable_pet_autocast(name) end end end end
    rt.pet_autocast_guid, rt.pet_autocast_mode, rt.pet_autocast_configured = guid, mode, true
end

do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    if not _G.__EAX_LOADED["Hunter"] then _G.__EAX_LOADED["Hunter"] = {} end
    _G.__EAX_LOADED["Hunter"]["Marksmanship"] = function()
        return menu and menu.enabled and menu.enabled:get_state()
    end
end

core.log("[Eax Hunter MM] Loaded")
return {}
