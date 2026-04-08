-- main.lua | EAX Hunter MM | Project Sylvanas
-- Priority: Aimed Shot → Serpent Sting → Arcane/Steady weave

local menu    = require("libraries/menu")
local spells  = require("libraries/spells")
local utils   = require("libraries/utils")
local middleware_manager = require("libraries/middleware_manager")
local dashboard = require("libraries/dashboard")
local dashboard_config = require("libraries/dashboard_config")
local _compat = require("libraries/rotation_compat")
local ooc_manager = require("libraries/ooc_manager")
local burst_manager = require("libraries/burst_manager")
local trinket_manager = require("libraries/trinket_manager")
local combat_forecast = require("libraries/combat_forecast")
local force_commands = require("libraries/force_commands")

-- Hunter Clip Tracker (ported from Flux)
local clip_tracker = require("libraries/hunter_clip_tracker")

-- Hot-path local caching
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown

-- Runtime state -------------------------------------------------------------
local rt = {
    last_spell_refresh = 0,
    last_clip_tracker_update = 0,
    auto_shot_id       = nil,
    aimed_shot_id      = nil,
    arcane_shot_id     = nil,
    steady_shot_id     = nil,
    multi_shot_id      = nil,
    kill_command_id    = nil,
    silencing_shot_id  = nil,
    readiness_id       = nil,
    trueshot_aura_id   = nil,
    mend_pet_id        = nil,
    revive_pet_id      = nil,
    call_pet_id        = nil,
    disengage_id       = nil,
    feign_death_id     = nil,
    concussive_shot_id = nil,
    scorpid_sting_id   = nil,
    viper_sting_id     = nil,
    rapid_fire_id      = nil,
    misdirection_id    = nil,
    viper_aspect_id    = nil,
    hunters_mark_id    = nil,
    serpent_sting_id   = nil,
    aspect_hawk_id     = nil,
    aspect_monkey_id   = nil,
    aspect_cheetah_id  = nil,
    aspect_pack_id     = nil,
    raptor_strike_id   = nil,
    wing_clip_id       = nil,
    immolation_trap_id = nil,
    freezing_trap_id   = nil,
    frost_trap_id      = nil,
    deterrence_id      = nil,
    flare_id           = nil,
    scare_beast_id     = nil,
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
    last_rapid_fire_cast_count = -1,
    last_readiness_cast_count = -1,
    last_misdirection_cast_count = -1,
    last_silencing_shot_cast_count = -1,
    last_trap_time     = 0,
    last_deterrence_cast_count = -1,
    last_scare_beast_cast_count = -1,
    last_flare_time    = 0,
    aspect_last_scan_time = 0,
    aspect_last_in_melee = false,
    aspect_last_mode = nil,
    aspect_last_target_guid = nil,
    last_disengage_time = 0,
    cached_mode        = "solo",
    prev_toggle_state  = false,
    combat_start_time  = 0,
    in_combat          = false,
}

local SPELL_REFRESH     = 1.0
local MODE_REFRESH      = 4.5

-- -- Helpers ------------------------------------------------------------------
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
    local me = get_me()
    rt.auto_shot_id        = utils.resolve_spell_id(spells.AUTO_SHOT)
    rt.aimed_shot_id       = utils.resolve_spell_id(spells.AIMED_SHOT)
    rt.arcane_shot_id      = utils.resolve_spell_id(spells.ARCANE_SHOT)
    rt.steady_shot_id      = utils.resolve_spell_id(spells.STEADY_SHOT)
    rt.multi_shot_id       = utils.resolve_spell_id(spells.MULTI_SHOT)
    rt.kill_command_id     = utils.resolve_spell_id(spells.KILL_COMMAND)
    rt.silencing_shot_id   = utils.resolve_spell_id(spells.SILENCING_SHOT)
    rt.readiness_id        = utils.resolve_spell_id(spells.READINESS)
    rt.trueshot_aura_id    = utils.resolve_spell_id(spells.TRUESHOT_AURA)
    rt.mend_pet_id         = utils.resolve_spell_id(spells.MEND_PET)
    rt.revive_pet_id       = utils.resolve_spell_id(spells.REVIVE_PET)
    rt.call_pet_id         = utils.resolve_spell_id(spells.CALL_PET)
    rt.disengage_id        = utils.resolve_spell_id(spells.DISENGAGE)
    rt.feign_death_id      = utils.resolve_spell_id(spells.FEIGN_DEATH)
    rt.concussive_shot_id  = utils.resolve_spell_id(spells.CONCUSSIVE_SHOT)
    rt.scorpid_sting_id    = utils.resolve_spell_id(spells.SCORPID_STING)
    rt.viper_sting_id      = utils.resolve_spell_id(spells.VIPER_STING)
    rt.rapid_fire_id       = utils.resolve_spell_id(spells.RAPID_FIRE)
    rt.misdirection_id     = utils.resolve_spell_id(spells.MISDIRECTION)
    rt.viper_aspect_id     = utils.resolve_spell_id(spells.ASPECT_OF_THE_VIPER)
    rt.hunters_mark_id     = utils.resolve_spell_id(spells.HUNTERS_MARK)
    rt.serpent_sting_id    = utils.resolve_spell_id(spells.SERPENT_STING)
    rt.aspect_hawk_id      = utils.resolve_spell_id(spells.ASPECT_OF_THE_HAWK)
    rt.aspect_monkey_id    = utils.resolve_spell_id(spells.ASPECT_OF_THE_MONKEY)
    rt.aspect_cheetah_id   = utils.resolve_spell_id(spells.ASPECT_OF_THE_CHEETAH)
    rt.aspect_pack_id      = utils.resolve_spell_id(spells.ASPECT_OF_THE_PACK)
    rt.raptor_strike_id    = utils.resolve_spell_id(spells.RAPTOR_STRIKE)
    rt.wing_clip_id        = utils.resolve_spell_id(spells.WING_CLIP)
    rt.immolation_trap_id  = utils.resolve_spell_id(spells.IMMOLATION_TRAP)
    rt.freezing_trap_id    = utils.resolve_spell_id(spells.FREEZING_TRAP)
    rt.frost_trap_id       = utils.resolve_spell_id(spells.FROST_TRAP)
    rt.deterrence_id       = utils.resolve_spell_id(spells.DETERRENCE)
    rt.flare_id            = utils.resolve_spell_id(spells.FLARE)
    rt.scare_beast_id      = utils.resolve_spell_id(spells.SCARE_BEAST)
end

local function pet_alive()   local p = get_pet(); return p and not p:is_dead() end
local function is_moving()   local me = get_me(); return me and me.is_moving and me:is_moving() end

local function dist_squared(target)
    local me = get_me(); if not me or not target then return 999999 end
    local p1, p2 = me:get_position(), target:get_position()
    if not p1 or not p2 then return 999999 end
    local dx,dy,dz = p1.x-p2.x, p1.y-p2.y, p1.z-p2.z
    return (dx*dx + dy*dy + dz*dz)
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
    local s = (menu.mode and menu.mode:get()) or 1
    if s==2 then return "solo" elseif s==3 then return "dungeon" elseif s==4 then return "raid" end
    return rt.cached_mode
end

-- -- Aspect management ---------------------------------------------------------
local function try_aspect_viper(me)
    if not rt.viper_aspect_id then return false end
    if not (menu.use_aspect_viper and menu.use_aspect_viper:get_state()) then return false end
    local mp = mana_pct(me)
    local enter = ((menu.viper_mana_enter and menu.viper_mana_enter:get()) or 35)/100
    local exit  = ((menu.viper_mana_exit  and menu.viper_mana_exit:get())  or 85)/100
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
            return true
        end
    end
    return false
end

local function try_aspect(me)
    if me:is_in_combat() and (utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_CHEETAH) or utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_PACK)) then
        if not rt.aspect_monkey_id then return false end
        if rt.last_aspect_cast_count == core.spell_book.get_spell_cast_count(rt.aspect_monkey_id) then return false end
        if utils.can_cast_self(rt.aspect_monkey_id, me) then
            rt.last_aspect_cast_count = core.spell_book.get_spell_cast_count(rt.aspect_monkey_id)
            utils.cast_self(rt.aspect_monkey_id, me)
            return true
        end
    end
    if utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_VIPER) then return false end
    local now = _core_time()
    local target = me:get_target()
    local target_guid = nil
    if target and target.is_valid then
        local ok_guid, guid = pcall(function() return target:get_guid() end)
        if ok_guid and guid then target_guid = tostring(guid) end
    end
    local in_melee = rt.aspect_last_in_melee
    local need_scan = (now - (rt.aspect_last_scan_time or 0)) >= 0.75
        or rt.aspect_last_mode ~= active_mode()
        or rt.aspect_last_target_guid ~= target_guid
    if need_scan then
        in_melee = false
        for _, o in ipairs(core.object_manager.get_all_objects()) do
            if o and o:is_valid() and o:is_unit() and not o:is_dead() and me:can_attack(o) then
                local ok, ot = pcall(function() return o:get_target() end)
                if ok and ot and utils.same_unit(ot, me) then
                    local p1, p2 = me:get_position(), o:get_position()
                    if p1 and p2 then
                        local dx,dy,dz = p1.x-p2.x, p1.y-p2.y, p1.z-p2.z
                        if (dx*dx + dy*dy + dz*dz) <= 64 then
                            in_melee = true; break
                        end
                    end
                end
            end
        end
        rt.aspect_last_scan_time = now
        rt.aspect_last_in_melee = in_melee
        rt.aspect_last_mode = active_mode()
        rt.aspect_last_target_guid = target_guid
    end
    if in_melee and rt.aspect_monkey_id then
        if utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_MONKEY) then return false end
        if rt.last_aspect_cast_count == core.spell_book.get_spell_cast_count(rt.aspect_monkey_id) then return false end
        if utils.can_cast_self(rt.aspect_monkey_id, me) then
            rt.last_aspect_cast_count = core.spell_book.get_spell_cast_count(rt.aspect_monkey_id)
            utils.cast_self(rt.aspect_monkey_id, me)
            return true
        end
    else
        if not rt.aspect_hawk_id then return false end
        if utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_HAWK) then return false end
        if rt.last_aspect_cast_count == core.spell_book.get_spell_cast_count(rt.aspect_hawk_id) then return false end
        if utils.can_cast_self(rt.aspect_hawk_id, me) then
            rt.last_aspect_cast_count = core.spell_book.get_spell_cast_count(rt.aspect_hawk_id)
            utils.cast_self(rt.aspect_hawk_id, me)
            return true
        end
    end
    return false
end

-- -- Pet management ------------------------------------------------------------
local function try_revive(me)
    if not (menu.use_revive_pet and menu.use_revive_pet:get_state()) then return false end
    if pet_alive() then return false end
    if me:is_in_combat() then return false end
    local p = get_pet()
    if p and p:is_dead() then
        if rt.revive_pet_id and utils.can_cast_self(rt.revive_pet_id, me) then
            utils.cast_self(rt.revive_pet_id, me)
            return true
        end
    elseif not p then
        if rt.call_pet_id and utils.can_cast_self(rt.call_pet_id, me) then
            utils.cast_self(rt.call_pet_id, me)
            return true
        end
    end
    return false
end

local function try_mend(me)
    if not (menu.use_mend_pet and menu.use_mend_pet:get_state()) then return false end
    if not rt.mend_pet_id then return false end
    local p = get_pet(); if not p or p:is_dead() then return false end
    local thresh = (menu.mend_pet_hp and menu.mend_pet_hp:get()) or 50
    if (p:get_health_percentage() or 100) > thresh then return false end
    local pp, mp = p:get_position(), me:get_position()
    if pp and mp then
        local dx,dy,dz = pp.x-mp.x, pp.y-mp.y, pp.z-mp.z
        if (dx*dx + dy*dy + dz*dz) > 196 then return false end
    end
    if is_moving() then return false end
    local bd = p:get_buff_data(spells.MEND_PET)
    if bd and bd.is_active then return false end
    if utils.can_cast_self(rt.mend_pet_id, me) then
        utils.cast_self(rt.mend_pet_id, me)
        return true
    end
    return false
end

-- -- Shots --------------------------------------------------------------------
local function serpent_sting_refresh_due(t)
    local rem_ms = debuff_rem(t, spells.DEBUFF_SERPENT_STING)
    return rem_ms <= 2500
end

local function try_hunters_mark(me, t)
    if not (menu.use_hunters_mark and menu.use_hunters_mark:get_state()) then return false end
    if not rt.hunters_mark_id then return false end
    local mode = (menu.hunters_mark_mode and menu.hunters_mark_mode:get()) or 1
    if mode == 3 then return false end
    if mode == 2 then
        if not t or not t:is_valid() then return false end
        if not t:is_boss() then return false end
    end
    if has_debuff(t, spells.DEBUFF_HUNTERS_MARK) then return false end
    if rt.last_hunters_mark_cast_count == core.spell_book.get_spell_cast_count(rt.hunters_mark_id) then return false end
    if not utils.can_cast_hostile(rt.hunters_mark_id, me, t) then return false end
    if utils.cast_target(rt.hunters_mark_id, me, t) then
        rt.last_hunters_mark_cast_count = core.spell_book.get_spell_cast_count(rt.hunters_mark_id)
        return true
    end
    return false
end

local function try_serpent_sting(me, t)
    if not (menu.use_serpent_sting and menu.use_serpent_sting:get_state()) then return false end
    if not rt.serpent_sting_id then return false end
    local ss_remaining = debuff_rem(t, spells.DEBUFF_SERPENT_STING)
    if ss_remaining > 2000 and ss_remaining > 0 then return false end
    if rt.last_serpent_sting_cast_count == core.spell_book.get_spell_cast_count(rt.serpent_sting_id) then return false end
    if not utils.can_cast_hostile(rt.serpent_sting_id, me, t) then return false end
    if utils.cast_target(rt.serpent_sting_id, me, t) then
        rt.last_serpent_sting_cast_count = core.spell_book.get_spell_cast_count(rt.serpent_sting_id)
        return true
    end
    return false
end

local function try_rapid_fire(me, t)
    if not (menu.use_rapid_fire and menu.use_rapid_fire:get_state()) then return false end
    if not rt.rapid_fire_id then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_RAPID_FIRE) then return false end
    if rt.last_rapid_fire_cast_count == core.spell_book.get_spell_cast_count(rt.rapid_fire_id) then return false end
    
    -- Check burst manager for auto-burst conditions
    local auto_burst = (menu.auto_burst_enabled and menu.auto_burst_enabled:get()) or false
    if auto_burst then
        local combat_time = rt.in_combat and (_core_time() - rt.combat_start_time) or 0
        local should_burst, reason = burst_manager.should_auto_burst(me, t, combat_time, menu)
        if not should_burst then
            return false
        end
    else
        -- Legacy TTD check when auto-burst is disabled
        local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
        if min_ttd > 0 and t then
            local forecast = require("libraries/combat_forecast")
            if not forecast:is_valid_forecast_logic(min_ttd, t, false) then
                return false
            end
        end
    end
    
    if utils.can_cast_self(rt.rapid_fire_id, me) then
        rt.last_rapid_fire_cast_count = core.spell_book.get_spell_cast_count(rt.rapid_fire_id)
        utils.cast_self(rt.rapid_fire_id, me)
        return true
    end
    return false
end

local function try_readiness(me, t)
    if not (menu.use_readiness and menu.use_readiness:get_state()) then return false end
    if not rt.readiness_id then return false end
    if rt.last_readiness_cast_count == core.spell_book.get_spell_cast_count(rt.readiness_id) then return false end
    local use_for_rf = (menu.readiness_rapid_fire and menu.readiness_rapid_fire:get_state()) or false
    if use_for_rf and core.spell_book.get_spell_cooldown(rt.rapid_fire_id) > 60 then
        -- Check burst manager for auto-burst conditions
        local auto_burst = (menu.auto_burst_enabled and menu.auto_burst_enabled:get()) or false
        if auto_burst then
            local combat_time = rt.in_combat and (_core_time() - rt.combat_start_time) or 0
            local should_burst, reason = burst_manager.should_auto_burst(me, t, combat_time, menu)
            if not should_burst then
                return false
            end
        else
            -- Legacy TTD check when auto-burst is disabled
            local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
            if min_ttd > 0 and t then
                local forecast = require("libraries/combat_forecast")
                if not forecast:is_valid_forecast_logic(min_ttd, t, false) then
                    return false
                end
            end
        end
        if utils.can_cast_self(rt.readiness_id, me) then
            rt.last_readiness_cast_count = core.spell_book.get_spell_cast_count(rt.readiness_id)
            utils.cast_self(rt.readiness_id, me)
            return true
        end
    end
    return false
end

local function try_trueshot_aura(me)
    if not (menu.use_trueshot_aura and menu.use_trueshot_aura:get_state()) then return false end
    if not rt.trueshot_aura_id then return false end
    if utils.has_buff(me, spells.BUFF_TRUESHOT_AURA) then return false end
    if utils.can_cast_self(rt.trueshot_aura_id, me) then
        utils.cast_self(rt.trueshot_aura_id, me)
        return true
    end
    return false
end

local function try_kill_command(me, t)
    if not (menu.use_kill_command and menu.use_kill_command:get_state()) then return false end
    if not rt.kill_command_id or not pet_alive() then return false end
    if rt.last_kill_command_cast_count == core.spell_book.get_spell_cast_count(rt.kill_command_id) then return false end
    if not utils.can_cast_hostile(rt.kill_command_id, me, t) then return false end
    if utils.cast_target(rt.kill_command_id, me, t) then
        rt.last_kill_command_cast_count = core.spell_book.get_spell_cast_count(rt.kill_command_id)
        return true
    end
    return false
end

local function try_aimed_shot(me, t)
    if not (menu.use_aimed_shot and menu.use_aimed_shot:get_state()) then return false end
    if not rt.aimed_shot_id then return false end
    if is_moving() then return false end
    if rt.last_aimed_shot_cast_count == core.spell_book.get_spell_cast_count(rt.aimed_shot_id) then return false end
    if not utils.can_cast_hostile(rt.aimed_shot_id, me, t) then return false end
    if utils.cast_target(rt.aimed_shot_id, me, t) then
        rt.last_aimed_shot_cast_count = core.spell_book.get_spell_cast_count(rt.aimed_shot_id)
        clip_tracker.on_spell_cast("Aimed Shot", false)
        return true
    end
    return false
end

local function try_arcane_shot(me, t)
    if not (menu.use_arcane_shot and menu.use_arcane_shot:get_state()) then return false end
    if not rt.arcane_shot_id then return false end
    if serpent_sting_refresh_due(t) then return false end
    if rt.last_arcane_shot_cast_count == core.spell_book.get_spell_cast_count(rt.arcane_shot_id) then return false end
    if not utils.can_cast_hostile(rt.arcane_shot_id, me, t) then return false end
    if utils.cast_target(rt.arcane_shot_id, me, t) then
        rt.last_arcane_shot_cast_count = core.spell_book.get_spell_cast_count(rt.arcane_shot_id)
        clip_tracker.on_spell_cast("Arcane Shot", false)
        return true
    end
    return false
end

local function try_multi_shot(me, t)
    if not (menu.use_multi_shot and menu.use_multi_shot:get_state()) then return false end
    if not rt.multi_shot_id then return false end
    if utils.get_aoe_count(me, t) < 2 then return false end
    if is_moving() then return false end
    if rt.last_multi_shot_cast_count == core.spell_book.get_spell_cast_count(rt.multi_shot_id) then return false end
    if not utils.can_cast_hostile(rt.multi_shot_id, me, t) then return false end
    if utils.cast_target(rt.multi_shot_id, me, t) then
        rt.last_multi_shot_cast_count = core.spell_book.get_spell_cast_count(rt.multi_shot_id)
        clip_tracker.on_spell_cast("Multi-Shot", false)
        return true
    end
    return false
end

local function try_steady_shot(me, t)
    if not (menu.use_steady_shot and menu.use_steady_shot:get_state()) then return false end
    if not rt.steady_shot_id then return false end
    if is_moving() then return false end
    if rt.last_steady_shot_cast_count == core.spell_book.get_spell_cast_count(rt.steady_shot_id) then return false end
    if not utils.can_cast_hostile(rt.steady_shot_id, me, t) then return false end
    if utils.cast_target(rt.steady_shot_id, me, t) then
        rt.last_steady_shot_cast_count = core.spell_book.get_spell_cast_count(rt.steady_shot_id)
        clip_tracker.on_spell_cast("Steady Shot", false)
        return true
    end
    return false
end

local function try_raptor_strike(me, t)
    if not (menu.use_raptor_strike and menu.use_raptor_strike:get_state()) then return false end
    if not rt.raptor_strike_id or dist_squared(t) > 25 then return false end
    if rt.last_raptor_strike_cast_count == core.spell_book.get_spell_cast_count(rt.raptor_strike_id) then return false end
    if not utils.can_cast_hostile(rt.raptor_strike_id, me, t) then return false end
    if utils.cast_target(rt.raptor_strike_id, me, t) then
        rt.last_raptor_strike_cast_count = core.spell_book.get_spell_cast_count(rt.raptor_strike_id)
        clip_tracker.on_spell_cast("Raptor Strike", true)
        return true
    end
    return false
end

local function try_wing_clip(me, t)
    if not (menu.use_wing_clip and menu.use_wing_clip:get_state()) then return false end
    if not rt.wing_clip_id or dist_squared(t) > 25 then return false end
    if has_debuff(t, spells.DEBUFF_WING_CLIP) then return false end
    if rt.last_wing_clip_cast_count == core.spell_book.get_spell_cast_count(rt.wing_clip_id) then return false end
    local ok_hp, target_hp = pcall(function() return t:get_health_percentage() end)
    if not ok_hp then return false end
    local ok_player, is_player = pcall(function() return t:is_player() end)
    if not ok_player then is_player = false end
    local threshold = is_player and ((menu.wing_clip_pvp_hp and menu.wing_clip_pvp_hp:get()) or 25) or ((menu.wing_clip_pve_hp and menu.wing_clip_pve_hp:get()) or 35)
    if target_hp > threshold then return false end
    if not utils.can_cast_hostile(rt.wing_clip_id, me, t) then return false end
    if utils.cast_target(rt.wing_clip_id, me, t) then
        rt.last_wing_clip_cast_count = core.spell_book.get_spell_cast_count(rt.wing_clip_id)
        clip_tracker.on_spell_cast("Wing Clip", true)
        return true
    end
    return false
end

local function try_feign_death(me)
    if not (menu.use_feign_death and menu.use_feign_death:get_state()) then return false end
    if not rt.feign_death_id then return false end
    local thresh = ((menu.feign_death_hp and menu.feign_death_hp:get()) or 20)/100
    if hp_pct(me) > thresh then return false end
    if utils.can_cast_self(rt.feign_death_id, me) then
        utils.cast_self(rt.feign_death_id, me)
        return true
    end
    return false
end

-- -- Main rotation -------------------------------------------------------------
local function do_rotation(me, t)
    local d2 = dist_squared(t)

    if try_feign_death(me) then return end
    if try_aspect_viper(me) then return end
    if try_aspect(me) then return end

    if pet_alive() then
        if try_kill_command(me, t) then return end
    end

    if try_rapid_fire(me, t) then return end
    if try_readiness(me, t) then return end
    if try_trueshot_aura(me) then return end
    if try_mend(me) then return end
    if try_hunters_mark(me, t) then return end

    if d2 > 1225 then return end

    if utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_VIPER)
        and mana_pct(me) < (((menu.viper_mana_exit and menu.viper_mana_exit:get()) or 85) / 100) then
        return
    end

    if d2 <= 25 then
        if try_raptor_strike(me, t) then return end
        if try_wing_clip(me, t) then return end
        if try_arcane_shot(me, t) then return end
        if try_steady_shot(me, t) then return end
        return
    end

    if try_aimed_shot(me, t) then return end
    if try_serpent_sting(me, t) then return end
    if try_multi_shot(me, t) then return end
    if try_arcane_shot(me, t) then return end
    if try_steady_shot(me, t) then return end
end

-- -- Update loop ---------------------------------------------------------------
local function on_update()
    resolve()
    local me = get_me()
    if utils.throttle("mmmode", MODE_REFRESH) then rt.cached_mode = detect_mode() end
    if not (menu.enabled and menu.enabled:get_state()) then return end
    if not me or me:is_dead() then return end
    -- Sync dashboard settings (safe pcall for uninitialized menu items)
    local ok_show, show_dashboard = pcall(function() return menu.show_dashboard:get_state() end)
    if ok_show then
        dashboard.set_enabled(show_dashboard)
    end
    
    local ok_opacity, opacity = pcall(function() return menu.dashboard_opacity:get() end)
    if ok_opacity then
        dashboard.set_opacity(opacity)
    end
    
    local ok_scale, scale = pcall(function() return menu.dashboard_scale:get() end)
    if ok_scale then
        dashboard.set_scale(scale)
    end
    
    local ok_x, pos_x = pcall(function() return menu.dashboard_x:get() end)
    local ok_y, pos_y = pcall(function() return menu.dashboard_y:get() end)
    if ok_x and ok_y then
        dashboard.set_position(pos_x, pos_y)
    end

    -- Track combat state for burst manager and clip tracker
    local in_combat_now = me:is_in_combat()
    if in_combat_now and not rt.in_combat then
        rt.combat_start_time = _core_time()
        clip_tracker.on_combat_start()
    elseif not in_combat_now and rt.in_combat then
        clip_tracker.on_combat_end()
    end
    rt.in_combat = in_combat_now

    -- Crowd Control check - return early if stunned/silenced/feared etc.
    if utils.is_cced and utils.is_cced(me) then return end

    -- OOC handling: Aspect of the Hawk self-buff
    if not me:is_in_combat() then
        ooc_manager.on_update(me, menu, utils, {
            group_buffs = {
                {
                    spell_id = rt.aspect_hawk_id,
                    buff_ids = spells.BUFF_ASPECT_OF_THE_HAWK,
                    name = "Aspect of the Hawk",
                    toggle = menu.use_aspect_hawk
                },
                {
                    spell_id = rt.trueshot_aura_id,
                    buff_ids = spells.BUFF_TRUESHOT_AURA,
                    name = "Trueshot Aura",
                    toggle = menu.use_trueshot_aura
                },
            }
        })
    end

    -- Initialize middleware on first run
    if not middleware_manager.is_initialized() then
        middleware_manager.initialize(menu)
    end

    -- Initialize clip tracker
    local clip_enabled = (menu.clip_tracker_enabled and menu.clip_tracker_enabled:get_state()) or false
    if clip_tracker.is_enabled() ~= clip_enabled then
        clip_tracker.set_enabled(clip_enabled)
        clip_tracker.set_print_summary((menu.clip_tracker_print_summary and menu.clip_tracker_print_summary:get_state()) or true)
        clip_tracker.set_thresholds(
            (menu.clip_threshold_green and menu.clip_threshold_green:get()) or 125,
            (menu.clip_threshold_yellow and menu.clip_threshold_yellow:get()) or 250,
            (menu.clip_threshold_orange and menu.clip_threshold_orange:get()) or 500
        )
    end

    -- Update clip tracker (throttled)
    local now = _core_time()
    if (now - rt.last_clip_tracker_update) >= 0.5 then
        rt.last_clip_tracker_update = now
        clip_tracker.update(me)
    end

    if try_revive(me) then return end

    local t = me:get_target()
    if not t or not t:is_valid() or t:is_dead() then return end
    if not me:can_attack(t) then return end

    -- Build middleware context and execute
    local ctx = middleware_manager.build_context(me, t, {})
    local mw_result, mw_msg = middleware_manager.execute(nil, ctx)
    if mw_result then
        return
    end

    -- CC Detection: Stop rotation if crowd controlled
    local cc_detector = require("libraries/cc_detector")
    local should_stop, cc_reason = cc_detector.should_stop_rotation(me)

    if should_stop then
        return  -- Stop rotation while CC'd
    end

    -- Check trinkets before rotation
    local combat_time = rt.in_combat and (_core_time() - rt.combat_start_time) or 0
    local is_burst, _ = burst_manager.should_auto_burst(me, t, combat_time, menu)
    
    -- Sample combat forecast
    if combat_forecast and t and t:is_valid() then
        combat_forecast:sample(t)
    end
    
    -- Update trinket check to V2
    trinket_manager.check_trinkets_v2(me, t, is_burst, force_commands, combat_forecast, menu)

    do_rotation(me, t)
end

core.register_on_update_callback(on_update)

-- Initialize dashboard
if dashboard and dashboard.init then
    dashboard.init(dashboard_config)
    local ok_show, show_dashboard = pcall(function() return menu.dashboard_enabled:get_state() end)
    dashboard.set_enabled(ok_show and show_dashboard or false)
    dashboard.register_render_callback()
end

-- Initialize force_commands
if force_commands and force_commands.init then
    force_commands:init()
end

-- Export toggle settings for external access
local NS = _G.EAXHunterMM and _G.EAXHunterMM.NS or {}
_G.EAXHunterMM = _G.EAXHunterMM or {}
_G.EAXHunterMM.NS = NS
NS.toggle_menu = menu.toggle_menu

return {}
