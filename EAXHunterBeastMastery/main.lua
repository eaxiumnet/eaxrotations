-- main.lua  |  EAX Hunter Beast Mastery  |  TBC
-- Priority: Bestial Wrath > Rapid Fire > Kill Command > Arcane Shot > Serpent Sting > Aimed Shot > Multi > Steady

local menu    = require("menu")
local spells  = require("spells")
local utils   = require("utils")
local eax_utils = require("eax_utils")
local color   = require("color")
---@type buff_manager
local buff_manager  = require("common/modules/buff_manager")
---@type interrupt_manager
local interrupt_manager = require("eax_shared/interrupt_manager")
---@type ooc_manager
local ooc_manager   = require("eax_shared/ooc_manager")
---@type vendor_automation
local vendor_automation = require("eax_shared/vendor_automation")
---@type consumables_manager
local consumables_manager = require("eax_shared/consumables_manager")
---@type mount_manager
local mount_manager = require("eax_shared/mount_manager")
---@type leveling_manager
local leveling_manager  = require("leveling_manager")
---@type encounter_manager
local encounter_manager = require("eax_shared/encounter_manager")
local enc = nil
---@type esp_renderer
local esp_renderer  = require("esp_renderer")
esp_renderer.init("bm", "Hunter BM")


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
        spec = "EAXHunterBeastMastery",
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
local racial_manager = require("eax_shared/racial_manager")
---@type defensive_manager
local defensive_manager = require("eax_shared/defensive_manager")
---@type threat_manager
local threat_manager = require("eax_shared/threat_manager")
---@type swing_timer
local swing_timer = require("eax_shared/swing_timer")

-- Guard to init threat_manager only once at startup
local threat_initialized = false

---@type control_panel_helper
local key_helper = require("common/utility/key_helper")
local control_panel_utility = require("common/utility/control_panel_helper")
---@type kiting_manager
local kiting_manager = require("kiting_manager")
kiting_manager.init({})
---@type pet_manager
local pet_manager = require("pet_manager")
pet_manager.init({})
---@type talent_manager
local talent_manager = require("talent_manager")
talent_manager.init()
---@type set_bonus
local set_bonus = require("set_bonus")

-- ── Runtime state ─────────────────────────────────────────────────────────────
local rt = {
    last_talent_refresh = 0,
    revive_in_progress = false,
    auto_shot_id       = nil,
    aimed_shot_id      = nil,
    arcane_shot_id     = nil,
    steady_shot_id     = nil,
    multi_shot_id      = nil,
    kill_command_id    = nil,
    bestial_wrath_id   = nil,
    intimidation_id    = nil,
    mend_pet_id        = nil,
    revive_pet_id      = nil,
    call_pet_id        = nil,
    disengage_id       = nil,
    feign_death_id     = nil,
    concussive_shot_id = nil,
    scorpid_sting_id   = nil,
    viper_sting_id     = nil,
    rapid_fire_id      = nil,
    viper_aspect_id    = nil,
    hunters_mark_id    = nil,
    serpent_sting_id   = nil,
    aspect_hawk_id     = nil,
    raptor_strike_id   = nil,
    wing_clip_id       = nil,
    immolation_trap_id = nil,
    freezing_trap_id   = nil,
    frost_trap_id      = nil,
    -- pet ability cache (populated from get_pet_spells())
    pet_growl_id       = nil,  -- taunt
    pet_damage_id      = nil,  -- primary damage ability (Claw/Bite/Gore etc)
    pet_special_id     = nil,  -- special: Furious Howl, Screech, Thunderstomp etc
    pet_spells_scanned = false,
    -- state
    last_wing_clip_cast_count = -1,
    last_concussive_cast_count = -1,
    last_viper_sting_cast_count = -1,
    last_disengage_cast_count = -1,
    last_kill_command_cast_count = -1,
    last_hunters_mark_cast_count = -1,
    last_serpent_sting_cast_count = -1,
    last_scorpid_sting_cast_count = -1,
    last_aspect_cast_count = -1,
    last_arcane_shot_cast_count = -1,
    last_aimed_shot_cast_count = -1,
    last_steady_shot_cast_count = -1,
    last_multi_shot_cast_count = -1,
    last_bestial_wrath_cast_count = -1,
    last_rapid_fire_cast_count = -1,
    last_intimidation_cast_count = -1,
    last_trap_time     = 0,
    last_disengage_time = 0,
    last_spell_refresh = 0,
    haste_breakpoint   = "2:1",
    cached_mode        = "solo",
    prev_toggle_state  = false,
    set_multiplier     = 1.0,
}

local SPELL_REFRESH     = 1.0
local MODE_REFRESH      = 4.5
local SHOT_DEBUG_INTERVAL = 3.0
local AUTO_CLIP_MS      = 200   -- don't fire instant within 200ms of auto
local TALENT_REFRESH    = 2.0  -- throttle talent updates

-- ── Helpers (defined early — used by resolve) ──────────────────────────────────
local function get_me()  return _get_local_player() end
local function get_pet()
    local me = get_me(); if not me then return nil end
    local ok, p = pcall(function() return me:get_pet() end)
    return (ok and p and p:is_valid()) and p or nil
end

local function resolve()
    local now = _core_time()
    if (now - rt.last_spell_refresh) < SPELL_REFRESH then return end
    rt.last_spell_refresh = now
    if (now - (rt.last_talent_refresh or 0)) >= TALENT_REFRESH then
        rt.last_talent_refresh = now
        talent_manager.update()
    end
    local me = get_me()
    if me then
        rt.set_multiplier = set_bonus.get_best_multiplier(me)
    end
    rt.auto_shot_id        = utils.resolve_spell_id(spells.AUTO_SHOT)
    rt.aimed_shot_id       = utils.resolve_spell_id(spells.AIMED_SHOT)
    rt.arcane_shot_id      = utils.resolve_spell_id(spells.ARCANE_SHOT)
    rt.steady_shot_id      = utils.resolve_spell_id(spells.STEADY_SHOT)
    rt.multi_shot_id       = utils.resolve_spell_id(spells.MULTI_SHOT)
    rt.kill_command_id     = utils.resolve_spell_id(spells.KILL_COMMAND)
    rt.bestial_wrath_id    = utils.resolve_spell_id(spells.BESTIAL_WRATH)
    rt.intimidation_id     = utils.resolve_spell_id(spells.INTIMIDATION)
    rt.mend_pet_id         = utils.resolve_spell_id(spells.MEND_PET)
    rt.revive_pet_id       = utils.resolve_spell_id(spells.REVIVE_PET)
    rt.call_pet_id         = utils.resolve_spell_id(spells.CALL_PET)
    rt.disengage_id        = utils.resolve_spell_id(spells.DISENGAGE)
    rt.feign_death_id      = utils.resolve_spell_id(spells.FEIGN_DEATH)
    rt.concussive_shot_id  = utils.resolve_spell_id(spells.CONCUSSIVE_SHOT)
    rt.scorpid_sting_id    = utils.resolve_spell_id(spells.SCORPID_STING)
    rt.viper_sting_id      = utils.resolve_spell_id(spells.VIPER_STING)
    rt.rapid_fire_id       = utils.resolve_spell_id(spells.RAPID_FIRE)
    rt.viper_aspect_id     = utils.resolve_spell_id(spells.ASPECT_OF_THE_VIPER)
    rt.hunters_mark_id     = utils.resolve_spell_id(spells.HUNTERS_MARK)
    rt.serpent_sting_id    = utils.resolve_spell_id(spells.SERPENT_STING)
    rt.aspect_hawk_id      = utils.resolve_spell_id(spells.ASPECT_OF_THE_HAWK)
    rt.aspect_monkey_id    = utils.resolve_spell_id(spells.ASPECT_OF_THE_MONKEY)
    rt.raptor_strike_id    = utils.resolve_spell_id(spells.RAPTOR_STRIKE)
    rt.wing_clip_id        = utils.resolve_spell_id(spells.WING_CLIP)
    rt.immolation_trap_id  = utils.resolve_spell_id(spells.IMMOLATION_TRAP)
    rt.freezing_trap_id    = utils.resolve_spell_id(spells.FREEZING_TRAP)
    rt.frost_trap_id       = utils.resolve_spell_id(spells.FROST_TRAP)
end

local function pet_alive()   local p = get_pet(); return p and not p:is_dead() end
-- ── Pet spell discovery ───────────────────────────────────────────────────────
local PET_GROWL_IDS  = { 2649, 14921, 14922, 14923, 14924, 14925 }
local PET_CLAW_IDS   = { 2981, 14261, 14262, 14263, 14264, 14265 }
local PET_BITE_IDS   = { 17253, 17254, 17255, 17256, 17257, 27050 }
local PET_GORE_IDS   = { 35290, 35291 }
local PET_HOWL_IDS   = { 24597, 24598, 24599, 24600 }
local PET_SCREECH_IDS= { 24604 }
local PET_THUNDER_IDS= { 26090, 26093 }
local PET_LIGHTNING_IDS = { 25011, 25012, 25013, 25014, 25015, 25016 }
local PET_POISON_IDS = { 24640 }

local function scan_pet_spells()
    if rt.pet_spells_scanned then return end
    -- Try API first
    local list = core.spell_book.get_pet_spells()
    local known = {}
    if list and #list > 0 then
        for _, s in ipairs(list) do
            local id = type(s) == "number" and s or (type(s) == "table" and (s.spell_id or s.id) or nil)
            if id then known[id] = true end
        end
    else
        -- Fallback: check all known pet spell IDs via is_spell_learned
        for _, group in ipairs({ PET_GROWL_IDS, PET_CLAW_IDS, PET_BITE_IDS, PET_GORE_IDS, PET_LIGHTNING_IDS, PET_HOWL_IDS, PET_SCREECH_IDS, PET_THUNDER_IDS }) do
            for _, id in ipairs(group) do
                if core.spell_book.is_spell_learned(id) then
                    known[id] = true
                end
            end
        end
    end
    for i = #PET_GROWL_IDS, 1, -1 do
        if known[PET_GROWL_IDS[i]] then rt.pet_growl_id = PET_GROWL_IDS[i]; break end
    end
    for _, group in ipairs({ PET_CLAW_IDS, PET_BITE_IDS, PET_GORE_IDS, PET_LIGHTNING_IDS, PET_POISON_IDS }) do
        if not rt.pet_damage_id then
            for i = #group, 1, -1 do
                if known[group[i]] then rt.pet_damage_id = group[i]; break end
            end
        end
    end
    for _, group in ipairs({ PET_HOWL_IDS, PET_SCREECH_IDS, PET_THUNDER_IDS }) do
        if not rt.pet_special_id then
            for i = #group, 1, -1 do
                if known[group[i]] then rt.pet_special_id = group[i]; break end
            end
        end
    end
    rt.pet_spells_scanned = true
    core.log(string.format("[EAX BM] Pet: growl=%s dmg=%s special=%s",
        tostring(rt.pet_growl_id), tostring(rt.pet_damage_id), tostring(rt.pet_special_id)))
end

local function try_pet_ability(spell_id, target)
    if not spell_id or not target or not target:is_valid() then return false end
    if _get_spell_cd(spell_id) > 0 then return false end
    core.input.pet_cast_target_spell(spell_id, target)
    return true
end

local function do_pet_abilities(t)
    local p = get_pet()
    if not p or not p:is_valid() or p:is_dead() then return end
    if not rt.pet_spells_scanned then scan_pet_spells() end

    -- Only fire pet abilities when pet is close enough to actually be in combat
    -- (pet within 10 yards of target = it's in melee/fighting)
    local pp = p:get_position()
    local tp = t and t:get_position()
    if pp and tp then
        local dx,dy,dz = pp.x-tp.x, pp.y-tp.y, pp.z-tp.z
        if math.sqrt(dx*dx+dy*dy+dz*dz) > 10 then return end
    end

    -- 1. Growl on cooldown - keeps threat on pet so it tanks
    try_pet_ability(rt.pet_growl_id, t)
    -- 2. Primary damage ability on cooldown (Claw/Bite/Gore/Lightning)
    try_pet_ability(rt.pet_damage_id, t)
    -- 3. Special on cooldown (Furious Howl/Screech/Thunderstomp)
    try_pet_ability(rt.pet_special_id, t)
end

local function is_moving()   local me = get_me(); return me and me.is_moving and me:is_moving() end
local function dist(target)
    local me = get_me(); if not me or not target then return 999 end
    local p1, p2 = me:get_position(), target:get_position()
    if not p1 or not p2 then return 999 end
    local dx,dy,dz = p1.x-p2.x, p1.y-p2.y, p1.z-p2.z
    return math.sqrt(dx*dx+dy*dy+dz*dz)
end
local function auto_eta(me)
    if me and me.get_auto_attack_timer_ms then
        local ok,v = pcall(function() return me:get_auto_attack_timer_ms() end)
        if ok and type(v)=="number" then return v end
    end
    return 9999
end
local function allow_instant(me) return auto_eta(me) > AUTO_CLIP_MS end
local function can_cast_casted_spell(me, cast_time) return swing_timer.can_cast_before_swing(me, cast_time, 0.1) end
local function get_haste_breakpoint(me)
    local eta = auto_eta(me) -- ms
    local effective_speed = eta / 1000
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
    if ok and ok2 and mm and mm>0 then return mp/mm end
    return 1.0
end
local function hp_pct(me) return (me:get_health_percentage() or 100)/100 end

local function has_debuff(target, tbl)
    if not target or not target:is_valid() then return false end
    -- Use game_object API directly: check debuff slot then aura slot
    local d = target:get_debuff_data(tbl)
    if d and d.is_active then return true end
    d = target:get_aura_data(tbl)
    return d ~= nil and d.is_active == true
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
    local n=0
    for _,o in ipairs(core.object_manager.get_all_objects()) do
        if o and o:is_valid() and o:is_unit() and not o:is_dead() and o:is_party_member() then n=n+1 end
    end
    if n==0 then return "solo" elseif n<=4 then return "dungeon" end
    return "raid"
end
local function active_mode()
    local s = menu.mode and menu.mode:get() or 1
    if s==2 then return "solo" elseif s==3 then return "dungeon" elseif s==4 then return "raid" end
    return rt.cached_mode
end

-- ── Pet attack ────────────────────────────────────────────────────────────────
local _last_pet_attack_guid = nil
local function pet_attack(target)
    if not target or not target:is_valid() then return end
    local p = get_pet(); if not p then return end
    local ok, guid = pcall(function() return tostring(target:get_guid()) end)
    if not ok or not guid then return end
    if _last_pet_attack_guid == guid then return end
    _last_pet_attack_guid = guid
    pcall(function() p:cast_spell(23145) end)
end

-- ── Aspect management ─────────────────────────────────────────────────────────
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
            utils.log_debug(menu, "Aspect of the Hawk (mana recovered)")
        end
        return false
    end
    if not on_viper and mp < enter then
        if utils.can_cast_self(rt.viper_aspect_id, me) then
            utils.cast_self(rt.viper_aspect_id, me)
            utils.log_debug(menu, "Aspect of the Viper")
            return true
        end
    end
    return false
end

local function try_aspect(me)
    if utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_VIPER) then return false end

    -- Check if any enemy is attacking us in melee range
    local in_melee = false
    for _, o in ipairs(core.object_manager.get_all_objects()) do
        if o and o:is_valid() and o:is_unit() and not o:is_dead() and me:can_attack(o) then
            local ok, ot = pcall(function() return o:get_target() end)
            if ok and ot and utils.same_unit(ot, me) then
                local p1, p2 = me:get_position(), o:get_position()
                if p1 and p2 then
                    local dx,dy,dz = p1.x-p2.x, p1.y-p2.y, p1.z-p2.z
                    if math.sqrt(dx*dx+dy*dy+dz*dz) <= 8 then
                        in_melee = true; break
                    end
                end
            end
        end
    end

    -- In melee: use Monkey for dodge. Out of melee: use Hawk for AP/DPS.
    if in_melee and rt.aspect_monkey_id then
        if utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_MONKEY) then return false end
        if rt.last_aspect_cast_count == core.spell_book.get_spell_cast_count(rt.aspect_monkey_id) then return false end
        if utils.can_cast_self(rt.aspect_monkey_id, me) then
            rt.last_aspect_cast_count = core.spell_book.get_spell_cast_count(rt.aspect_monkey_id)
            utils.cast_self(rt.aspect_monkey_id, me)
            utils.log_debug(menu, "Aspect of the Monkey"); return true
        end
    else
        if not rt.aspect_hawk_id then return false end
        if utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_HAWK) then return false end
        if rt.last_aspect_cast_count == core.spell_book.get_spell_cast_count(rt.aspect_hawk_id) then return false end
        if utils.can_cast_self(rt.aspect_hawk_id, me) then
            rt.last_aspect_cast_count = core.spell_book.get_spell_cast_count(rt.aspect_hawk_id)
            utils.cast_self(rt.aspect_hawk_id, me)
            utils.log_debug(menu, "Aspect of the Hawk"); return true
        end
    end
    return false
end

-- ── Pet management ────────────────────────────────────────────────────────────
local function try_revive(me)
    if not menu.use_revive_pet or not menu.use_revive_pet:get_state() then return false end
    if pet_alive() then return false end
    if me:is_in_combat() then return false end  -- never summon/revive mid-combat

    local p = get_pet()
    if p and p:is_dead() then
        -- Pet died - Revive Pet (long cast, OOC only)
        if rt.revive_pet_id and utils.can_cast_self(rt.revive_pet_id, me) then
            utils.cast_self(rt.revive_pet_id, me)
            rt.pet_spells_scanned = false  -- rescan after revive
        utils.log_debug(menu, "Revive Pet"); return true
        end
    elseif not p then
        -- No pet summoned at all - Call Pet
        if rt.call_pet_id and utils.can_cast_self(rt.call_pet_id, me) then
            rt.pet_spells_scanned = false  -- rescan after call
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
    -- Don't recast if already channelling Mend Pet
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

local function try_serpent_sting(me, t)
    if not menu.use_serpent_sting or not menu.use_serpent_sting:get_state() then return false end
    if not rt.serpent_sting_id then return false end
    if debuff_rem(t, spells.DEBUFF_SERPENT_STING) > 3000 then return false end
    if not utils.can_fire(me, "serpent_sting") then return false end
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
    if active_mode() == "solo" then return false end
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

local function try_bestial_wrath(me, t)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_bestial_wrath or not menu.use_bestial_wrath:get_state() then return false end
    if not rt.bestial_wrath_id or not pet_alive() then return false end
    if utils.has_buff(me, spells.BUFF_BESTIAL_WRATH) then return false end
    if rt.last_bestial_wrath_cast_count == core.spell_book.get_spell_cast_count(rt.bestial_wrath_id) then return false end
    if utils.can_cast_self(rt.bestial_wrath_id, me) then
        rt.last_bestial_wrath_cast_count = core.spell_book.get_spell_cast_count(rt.bestial_wrath_id)
        utils.cast_self(rt.bestial_wrath_id, me)
        utils.log_debug(menu, "Bestial Wrath")
        esp_renderer.on_cast(rt.bestial_wrath_id, "Bestial Wrath", color.orange(240))
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

local function try_intimidation(me, t)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_intimidation or not menu.use_intimidation:get_state() then return false end
    if not rt.intimidation_id or not pet_alive() then return false end
    if not allow_instant(me) then return false end
    if rt.last_intimidation_cast_count == core.spell_book.get_spell_cast_count(rt.intimidation_id) then return false end
    if not utils.can_cast_hostile(rt.intimidation_id, me, t) then return false end
    if utils.cast_target(rt.intimidation_id, t) then
        rt.last_intimidation_cast_count = core.spell_book.get_spell_cast_count(rt.intimidation_id)
        utils.log_debug(menu, "Intimidation"); return true
    end
    return false
end

local function try_kill_command(me, t)
    if not menu.use_kill_command or not menu.use_kill_command:get_state() then return false end
    if not rt.kill_command_id or not pet_alive() then return false end
    if rt.last_kill_command_cast_count == core.spell_book.get_spell_cast_count(rt.kill_command_id) then return false end
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

local function try_arcane_shot(me, t)
    if not menu.use_arcane_shot or not menu.use_arcane_shot:get_state() then return false end
    if not rt.arcane_shot_id then return false end
    if not allow_instant(me) then return false end
    if not utils.can_fire(me, "arcane_shot") then return false end
    if rt.last_arcane_shot_cast_count == core.spell_book.get_spell_cast_count(rt.arcane_shot_id) then return false end
    if not utils.can_cast_hostile(rt.arcane_shot_id, me, t) then return false end
    if utils.throttle("arcane_ok", 5.0) then
        core.log(string.format("[EAX DEBUG] arcane OK: id=%d", rt.arcane_shot_id))
    end
    if utils.cast_target(rt.arcane_shot_id, t) then
        rt.last_arcane_shot_cast_count = core.spell_book.get_spell_cast_count(rt.arcane_shot_id)
        utils.log_debug(menu, "Arcane Shot"); return true
    end
    return false
end

local function try_multi_shot(me, t)
    if enc and not enc.aoe_safe then return false end
    if not menu.use_multi_shot or not menu.use_multi_shot:get_state() then return false end
    if not rt.multi_shot_id then return false end
    if active_mode() == "solo" then return false end
    if is_moving() then return false end
    if not utils.can_fire(me, "multi_shot") then return false end
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
    if not utils.can_fire(me, "aimed_shot") then return false end
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
    if not utils.can_fire(me, "steady_shot") then return false end
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

local function try_raptor_strike(me, t)
    if not menu.use_raptor_strike or not menu.use_raptor_strike:get_state() then return false end
    if not rt.raptor_strike_id or dist(t) > 5 then return false end
    -- Raptor Strike queues on next swing - use cast_count to avoid re-queuing every frame
    if rt.last_raptor_strike_cast_count == core.spell_book.get_spell_cast_count(rt.raptor_strike_id) then return false end
    if not utils.can_cast_hostile(rt.raptor_strike_id, me, t) then return false end
    if utils.cast_target(rt.raptor_strike_id, t) then
        rt.last_raptor_strike_cast_count = core.spell_book.get_spell_cast_count(rt.raptor_strike_id)
        utils.log_debug(menu, "Raptor Strike"); return true
    end
    return false
end

local function try_wing_clip(me, t)
    if not menu.use_wing_clip or not menu.use_wing_clip:get_state() then return false end
    if not rt.wing_clip_id or dist(t) > 5 then return false end
    -- Don't recast while slow debuff is still active
    if has_debuff(t, spells.DEBUFF_WING_CLIP) then return false end
    -- Throttle: max once every 8 sec regardless of debuff detection
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
    local tid = sel == 2 and rt.frost_trap_id or rt.immolation_trap_id
    if not tid then return false end
    if utils.can_cast_self(tid, me) then
        utils.cast_self(tid, me)
        rt.last_trap_time = _core_time()
        utils.log_debug(menu, "Trap placed"); return true
    end
    return false
end

-- ── Main rotation ─────────────────────────────────────────────────────────────
local function do_rotation(me, t)
    local d = dist(t)
    if d <= 40 then if t:get_position() then core.input.look_at(t:get_position()) end end

    if try_feign_death(me) then return end

    local now = _core_time()
    local bm_state = pet_manager.get_spec_state("bm")
    local kiting_state, should_kite = kiting_manager.update(me, t, rt, spells, utils, now, "bm")

    if should_kite then
        if kiting_manager.try_kiting_sequence(me, t, rt, spells, utils, menu, "bm") then return end
    end

    try_aspect_viper(me)
    try_aspect(me)

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

    local mana = utils.get_mana(me)

    ttd_tracker.update(t)

    if pet_manager.try_revive_call(me, bm_state, rt, utils, now) then return end

    local pet = get_pet()
    pet_manager.on_update(me, t, bm_state, now, menu, utils)

    if pet_manager.pet_alive(pet) then
        pet_manager.pet_attack(me, t, bm_state, now)
        try_kill_command(me, t)
    end

    if pet_manager.try_mend(me, pet, bm_state, rt, spells, utils, menu, now) then return end

    if try_trap(me, t) then return end
    if try_hunters_mark(me, t) then return end

    if d > 35 then
        return
    end

    if d <= 5 then
        if try_raptor_strike(me, t) then
            core.input.move_forward_start()
            return
        end
        core.input.move_forward_stop()
        if try_arcane_shot(me, t) then return end
        if try_steady_shot(me, t) then return end
        return
    end

    if try_scorpid_sting(me, t) then return end
    if try_viper_sting(me, t) then return end
    if try_serpent_sting(me, t) then return end

    if not hold_offense and try_bestial_wrath(me, t) then return end
    if try_intimidation(me, t) then return end

    if try_arcane_shot(me, t) then return end
    if try_aimed_shot(me, t) then return end
    if try_multi_shot(me, t) then return end
    if try_steady_shot(me, t) then return end

end

-- ── Toggle ────────────────────────────────────────────────────────────────────
local function handle_toggle()
    local cur = menu.toggle_key and menu.toggle_key:get_state()
    if cur and not rt.prev_toggle_state then
        menu.enabled:set(not menu.enabled:get_state())
    end
    rt.prev_toggle_state = cur or false
end

-- ── Update loop ───────────────────────────────────────────────────────────────
local function on_update()
    resolve()

    if utils.throttle("bm_mode", MODE_REFRESH) then rt.cached_mode = utils.detect_mode(me) end
    handle_toggle()
    if not menu.enabled or not menu.enabled:get_state() then return end
    local me = get_me()
    if not me or me:is_dead() then return end
    if not threat_initialized then threat_manager.init(me); threat_initialized = true end
    ooc_manager.on_update(me, menu, utils, {})
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
    local focus = eax_utils.get_focus_target(menu)
    if focus and not me:can_attack(focus) then focus = nil end
    local t = focus or utils.find_best_target(me)
    if not t or not t:is_valid() or t:is_dead() then
        _last_pet_attack_guid = nil
        if utils.throttle("pet_ctrl_idle", 2.0) then
            local p = get_pet()
            if p and pet_manager.pet_alive(p) then
                core.input.set_pet_aggressive()
                core.input.set_pet_follow()
            end
        end
        return
    end
    -- Reset pet attack when target changes to a different enemy
    if _last_pet_attack_guid then
        local ok, guid = pcall(function() return tostring(t:get_guid()) end)
        if ok and guid and guid ~= _last_pet_attack_guid then
            _last_pet_attack_guid = nil
        end
    end
    -- In combat: set defensive so pet only attacks what WE tell it to
    if utils.throttle("pet_ctrl_combat", 3.0) then
        local ok, pet = pcall(function() return me:get_pet() end)
        if ok and pet and pet:is_valid() and not pet:is_dead() then
            core.input.set_pet_defensive()
        end
    end
    do_rotation(me, t)
end

reactive_adapter = {
    spec = "EAXHunterBeastMastery",
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
local _win  = core.menu.window("eaxhunterbm_win")
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
        -- Master toggle (shows keybind if bound)
        local toggle_key = menu.toggle_key:get_key_code()
        local lbl_enabled = "[EAX BM] Enabled"
        if toggle_key ~= 7 then
            lbl_enabled = lbl_enabled .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        add_cb(lbl_enabled, menu.enabled, "eax_bm_enabled_cp")
        if menu.enabled and menu.enabled:get_state() then
            add_cb("[EAX BM] Bestial Wrath",   menu.use_bestial_wrath,  "eax_bm_bw_cp")
            add_cb("[EAX BM] Rapid Fire",       menu.use_rapid_fire,     "eax_bm_rf_cp")
            add_cb("[EAX BM] Auto Viper",       menu.use_aspect_viper,   "eax_bm_viper_cp")
            add_cb("[EAX BM] Kill Command",     menu.use_kill_command,   "eax_bm_kc_cp")
            add_cb("[EAX BM] Mend Pet",         menu.use_mend_pet,       "eax_bm_mend_cp")
            add_cb("[EAX BM] Use Traps",        menu.use_traps,          "eax_bm_traps_cp")
            add_cb("[EAX BM] Focus Priority",   menu.focus_priority,     "eax_bm_focus_cp")
            add_cb("[EAX BM] Use Racial",       menu.use_racial,         "eax_bm_racial_cp")
        end
        return elements
    end)
end

do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    if not _G.__EAX_LOADED["Hunter"] then _G.__EAX_LOADED["Hunter"] = {} end
    _G.__EAX_LOADED["Hunter"]["BeastMastery"] = function()
        return menu and menu.enabled and menu.enabled:get_state()
    end
end

core.log("[EAX Hunter BM] Loaded")
return {}
