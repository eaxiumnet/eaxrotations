-- main.lua | EAX Hunter BM | TBC
-- Priority: Kill Command -> Bestial Wrath -> Intimidation -> Serpent/arcane weaving -> Steady Shot

-- Load header first to check if we should load at all
local header = require("header")
if not header.load then
    return
end

local menu    = require("libraries/menu")
local spells  = require("libraries/spells")
local utils   = require("libraries/utils")
local middleware_manager = require("libraries/middleware_manager")
local dashboard = require("libraries/dashboard")
local dashboard_config = require("libraries/dashboard_config")
local _compat = require("libraries/rotation_compat")
local ooc_manager = require("libraries/ooc_manager")

-- Burst & Trinket Automation (ported from Flux)
local burst_manager = require("libraries/burst_manager")
local trinket_manager = require("libraries/trinket_manager")
local combat_forecast = require("libraries/combat_forecast")
local force_commands = require("libraries/force_commands")

-- Swing timer for shot rotation timing (prevents Auto Shot clipping)
local swing_timer = require("libraries/swing_timer")

-- Hunter Clip Tracker (ported from Flux)
local clip_tracker = require("libraries/hunter_clip_tracker")

-- Hot-path local caching (performance critical)
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown

-- Pet autocast API caching
local _get_pet_action_info = core.spell_book.get_pet_action_info
local _enable_pet_autocast = core.input.enable_pet_autocast
local _disable_pet_autocast = core.input.disable_pet_autocast

-- Runtime state -------------------------------------------------------------
local rt = {
    last_spell_refresh = 0,
    last_clip_tracker_update = 0,
    revive_in_progress = false,
    revive_started_at  = 0,
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
    last_bestial_wrath_cast_count = -1,
    last_rapid_fire_cast_count = -1,
    last_misdirection_cast_count = -1,
    last_intimidation_cast_count = -1,
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
    -- French rotation tracking (5:5:1:1 cycle)
    french_rotation_step = 0,  -- 0-4 for 5-step French rotation
    last_french_cast_time = 0,
    -- Pet autocast sync state
    pet_autocast_guid = nil,
    pet_autocast_mode = nil,
    pet_autocast_configured = false,
    pet_autocast_last_scan = 0,
}

local SPELL_REFRESH     = 1.0
local MODE_REFRESH      = 4.5
local AUTO_CLIP_MS      = 200

-- -- Helpers (defined early - used by resolve) ----------------------------------
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
    rt.misdirection_id     = utils.resolve_spell_id(spells.MISDIRECTION)
    rt.viper_aspect_id     = utils.resolve_spell_id(spells.ASPECT_OF_THE_VIPER)
    rt.hunters_mark_id     = utils.resolve_spell_id(spells.HUNTERS_MARK)
    rt.serpent_sting_id    = utils.resolve_spell_id(spells.SERPENT_STING)
    rt.aspect_hawk_id      = utils.resolve_spell_id(spells.ASPECT_OF_THE_HAWK)
    rt.aspect_hawk_resolved = utils.resolve_spell_id(spells.ASPECT_OF_THE_HAWK)
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
local function is_moving()   local me = get_me(); local ok_moving, is_moving = pcall(function() return me:is_moving() end)
    return ok_moving and is_moving end

-- Squared distance for performance
local function dist_squared(target)
    local me = get_me(); if not me or not target then return 999999 end
    local ok_p1, p1 = pcall(function() return me:get_position() end)
    local ok_p2, p2 = pcall(function() return target:get_position() end)
    if not ok_p1 then p1 = nil end
    if not ok_p2 then p2 = nil end
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
local function hp_pct(me) 
    local ok_hp, hp = pcall(function() return me:get_health() end)
    local ok_max, max_hp = pcall(function() return me:get_max_health() end)
    return (ok_hp and ok_max and hp and max_hp and max_hp > 0) and ((hp / max_hp) * 100) / 100 or 1
end

local function has_debuff(target, tbl)
    if not target or not target:is_valid() then return false end
    local ok_d, d = pcall(function() return target:get_debuff_data(tbl) end)
    if not ok_d then d = nil end
    if d and d.is_active then return true end
    local ok_a, d = pcall(function() return target:get_aura_data(tbl) end)
    if not ok_a then d = nil end
    return d ~= nil and d.is_active == true
end
local function debuff_rem(target, tbl)
    if not target or not target:is_valid() then return 0 end
    local ok_d, d = pcall(function() return target:get_debuff_data(tbl) end)
    if not ok_d then d = nil end
    if d and d.is_active and (d.remaining or 0) > 0 then return d.remaining end
    local ok_a, d = pcall(function() return target:get_aura_data(tbl) end)
    if not ok_a then d = nil end
    if d and d.is_active and (d.remaining or 0) > 0 then return d.remaining end
    return 0
end

local function detect_mode()
    local n=0
    local ok_objects, all_objects = pcall(function() return core.object_manager.get_all_objects() end)
    if not ok_objects then all_objects = {} end
    for _, o in ipairs(all_objects) do
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
    local ok_target, target = pcall(function() if me and me.get_target then return me:get_target() end return nil end)
    if not ok_target then target = nil end
    local target_guid = nil
    local ok_valid, is_valid = pcall(function() return target:is_valid() end)
    if target and ok_valid and is_valid then
        if target.get_guid then
            local ok_guid, guid = pcall(function() return target:get_guid() end)
            if ok_guid and guid then target_guid = tostring(guid) end
        end
        -- Fallback if get_guid fails or not available
        if not target_guid then
            local ok_npc, npc_id = pcall(function() return target:get_npc_id() end)
    if not ok_npc then npc_id = 0 end
            local ok_pos, pos = pcall(function() return target:get_position() end)
    if not ok_pos then pos = nil end
            if pos then
                target_guid = string.format("%d_%.1f_%.1f", npc_id, pos.x, pos.y)
            end
        end
    end
    local in_melee = rt.aspect_last_in_melee
    local need_scan = (now - (rt.aspect_last_scan_time or 0)) >= 0.75
        or rt.aspect_last_mode ~= active_mode()
        or rt.aspect_last_target_guid ~= target_guid
    if need_scan then
        in_melee = false
        local ok_objects, all_objects = pcall(function() return core.object_manager.get_all_objects() end)
    if not ok_objects then all_objects = {} end
    for _, o in ipairs(all_objects) do
            if o and o:is_valid() and o:is_unit() and not o:is_dead() and me:can_attack(o) then
                local ok_ot, ot = pcall(function() return o:get_target() end)
    if not ok_ot then ot = nil end
                if ok and ot and utils.same_unit(ot, me) then
                    local ok_p1, p1 = pcall(function() return me:get_position() end)
    local ok_p2, p2 = pcall(function() return o:get_position() end)
    if not ok_p1 then p1 = nil end
    if not ok_p2 then p2 = nil end
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
    local ok_dead, is_dead = pcall(function() return p:is_dead() end)
    if p and ok_dead and is_dead then
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
    local ok_hp, hp = pcall(function() return p:get_health() end)
local ok_max, max_hp = pcall(function() return p:get_max_health() end)
local p_hp = (ok_hp and ok_max and hp and max_hp and max_hp > 0) and ((hp / max_hp) * 100) or 100
if p_hp > thresh then return false end
    local ok_pp, pp = pcall(function() return p:get_position() end)
    local ok_mp, mp = pcall(function() return me:get_position() end)
    if not ok_pp then pp = nil end
    if not ok_mp then mp = nil end
    if pp and mp then
        local dx,dy,dz = pp.x-mp.x, pp.y-mp.y, pp.z-mp.z
        if (dx*dx + dy*dy + dz*dz) > 196 then return false end
    end
    if is_moving() then return false end
    local ok_bd, bd = pcall(function() return p:get_buff_data(spells.MEND_PET) end)
    if not ok_bd then bd = nil end
    if bd and bd.is_active then return false end
    if utils.can_cast_self(rt.mend_pet_id, me) then
        utils.cast_self(rt.mend_pet_id, me)
        return true
    end
    return false
end

-- -- Pet autocast synchronization ---------------------------------------------
local function sync_pet_autocast(me)
    -- Menu guard: check if feature enabled
    if not (menu.sync_pet_autocast and menu.sync_pet_autocast:get_state()) then return end
    
    local pet = get_pet()
    if not pet then 
        rt.pet_autocast_guid, rt.pet_autocast_mode, rt.pet_autocast_configured = nil, nil, false
        return 
    end
    
    -- Get pet GUID safely
    local guid = nil
    pcall(function() guid = tostring(pet:get_guid()) end)
    
    local mode = active_mode()
    local now = _core_time()
    
    -- Throttle: only scan every 1.5s, or when pet/mode changes
    if rt.pet_autocast_configured and rt.pet_autocast_guid == guid and rt.pet_autocast_mode == mode 
       and (now - (rt.pet_autocast_last_scan or 0)) < 1.5 then 
        return 
    end
    
    -- Get pet action info safely with pcall
    local ok, actions = pcall(function() return _get_pet_action_info() end)
    if not ok or type(actions) ~= "table" then return end
    
    -- Define which abilities should have autocast enabled
    local want = { 
        Claw = true, 
        Bite = true, 
        Gore = true, 
        ["Lightning Breath"] = true, 
        ["Poison Spit"] = true, 
        ["Furious Howl"] = true, 
        Screech = true, 
        Thunderstomp = true 
    }
    
    -- Helper to extract autocast state from various API formats
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
    
    -- Process each pet action
    for _, a in ipairs(actions) do
        local name = a and (a.name or a[1])
        local autocast = current_autocast_state(a)
        
        if name and autocast ~= nil then
            -- Determine if this ability should be enabled
            -- Growl is special: disable in group if menu option set
            local enabled = want[name] or (name == "Growl" and not (
                (menu.disable_growl_in_group and menu.disable_growl_in_group:get_state()) 
                and mode ~= "solo"
            ))
            
            -- Toggle autocast if needed
            if enabled ~= autocast then
                if enabled then 
                    pcall(function() _enable_pet_autocast(name) end)
                else 
                    pcall(function() _disable_pet_autocast(name) end)
                end
            end
        end
    end
    
    -- Update cached state
    rt.pet_autocast_guid = guid
    rt.pet_autocast_mode = mode
    rt.pet_autocast_configured = true
    rt.pet_autocast_last_scan = now
end

-- -- Shots ---------------------------------------------------------------------
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

local function try_bestial_wrath(me)
    if not (menu.use_bestial_wrath and menu.use_bestial_wrath:get_state()) then return false end
    if not rt.bestial_wrath_id or not pet_alive() then return false end
    if utils.has_buff(me, spells.BUFF_BESTIAL_WRATH) then return false end
    if rt.last_bestial_wrath_cast_count == core.spell_book.get_spell_cast_count(rt.bestial_wrath_id) then return false end
    if utils.can_cast_self(rt.bestial_wrath_id, me) then
        rt.last_bestial_wrath_cast_count = core.spell_book.get_spell_cast_count(rt.bestial_wrath_id)
        utils.cast_self(rt.bestial_wrath_id, me)
        return true
    end
    return false
end

local function try_rapid_fire(me)
    if not (menu.use_rapid_fire and menu.use_rapid_fire:get_state()) then return false end
    if not rt.rapid_fire_id then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_RAPID_FIRE) then return false end
    if rt.last_rapid_fire_cast_count == core.spell_book.get_spell_cast_count(rt.rapid_fire_id) then return false end
    if utils.can_cast_self(rt.rapid_fire_id, me) then
        rt.last_rapid_fire_cast_count = core.spell_book.get_spell_cast_count(rt.rapid_fire_id)
        utils.cast_self(rt.rapid_fire_id, me)
        return true
    end
    return false
end

local function try_kill_command(me, t)
    if not (menu.use_kill_command and menu.use_kill_command:get_state()) then return false end
    if not rt.kill_command_id or not pet_alive() then return false end
    if rt.last_kill_command_cast_count == core.spell_book.get_spell_cast_count(rt.kill_command_id) then return false end
    local pet = get_pet()
    if not pet or not pet:is_valid() or pet:is_dead() then return false end
    if not utils.can_cast_hostile(rt.kill_command_id, me, t) then return false end
    if utils.cast_target(rt.kill_command_id, me, t) then
        rt.last_kill_command_cast_count = core.spell_book.get_spell_cast_count(rt.kill_command_id)
        return true
    end
    return false
end

local function try_arcane_shot(me, t)
    if not (menu.use_arcane_shot and menu.use_arcane_shot:get_state()) then return false end
    if not rt.arcane_shot_id then return false end
    if serpent_sting_refresh_due(t) then return false end
    if rt.last_arcane_shot_cast_count == core.spell_book.get_spell_cast_count(rt.arcane_shot_id) then return false end
    
    -- Check swing timer - Arcane is instant but still needs GCD
    -- Only cast if we won't clip an imminent Auto Shot
    if not swing_timer.can_cast_before_swing(me, 0.0, 0.1) then
        return false
    end
    
    -- Try Kill Command first (off-GCD)
    if pet_alive() and rt.kill_command_id then
        if utils.can_cast_hostile(rt.kill_command_id, me, t) then
            utils.cast_target(rt.kill_command_id, t, "Kill Command")
        end
    end
    
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
    
    -- Check swing timer - Multi-Shot has 0.5s cast time
    if not swing_timer.can_cast_before_swing(me, 0.5, 0.2) then
        return false
    end
    
    -- Try Kill Command first (off-GCD)
    if pet_alive() and rt.kill_command_id then
        if utils.can_cast_hostile(rt.kill_command_id, me, t) then
            utils.cast_target(rt.kill_command_id, t, "Kill Command")
        end
    end
    
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
    
    -- CRITICAL: Check swing timer to prevent clipping Auto Shot
    -- Steady Shot has 1.5s cast time, need to ensure it completes before next Auto
    if not swing_timer.can_cast_before_swing(me, 1.5, 0.2) then
        return false
    end
    
    -- Try Kill Command first (off-GCD, highest priority when available)
    if pet_alive() and rt.kill_command_id then
        if utils.can_cast_hostile(rt.kill_command_id, me, t) then
            utils.cast_target(rt.kill_command_id, t, "Kill Command")
        end
    end
    
    if utils.can_cast_hostile(rt.steady_shot_id, me, t) then
        if utils.cast_target(rt.steady_shot_id, me, t) then
            rt.last_steady_shot_cast_count = core.spell_book.get_spell_cast_count(rt.steady_shot_id)
            clip_tracker.on_spell_cast("Steady Shot", false)
            return true
        end
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
    local ok_hp, hp = pcall(function() return t:get_health() end)
    local ok_max, max_hp = pcall(function() return t:get_max_health() end)
    local target_hp = (ok_hp and ok_max and hp and max_hp and max_hp > 0) and ((hp / max_hp) * 100) or 100
    if not ok_hp then return false end
    local ok_player, is_player_val = pcall(function() return t:is_player() end)
    local is_player = ok_player and is_player_val or false
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

    -- Priority 1: Kill Command (when pet engaged) - HIGHEST PRIORITY
    if pet_alive() then
        if try_kill_command(me, t) then return end
    end

    -- Priority 2: Bestial Wrath (major DPS cooldown)
    if try_bestial_wrath(me) then return end

    -- Priority 3: Mend Pet (keep pet alive)
    if try_mend(me) then return end

    if try_rapid_fire(me) then return end
    if try_hunters_mark(me, t) then return end

    -- Ranged rotation
    if d2 > 1225 then return end  -- 35 yards squared

    if utils.has_buff(me, spells.BUFF_ASPECT_OF_THE_VIPER)
        and mana_pct(me) < (((menu.viper_mana_exit and menu.viper_mana_exit:get()) or 85) / 100) then
        return
    end

    -- Melee range
    if d2 <= 25 then  -- 5 yards squared
        if try_raptor_strike(me, t) then return end
        if try_wing_clip(me, t) then return end
        if try_arcane_shot(me, t) then return end
        if try_steady_shot(me, t) then return end
        return
    end

    if try_serpent_sting(me, t) then return end

    -- Standard shot rotation
    if try_multi_shot(me, t) then return end
    if try_arcane_shot(me, t) then return end
    if try_steady_shot(me, t) then return end
end

-- -- Update loop ---------------------------------------------------------------
local function on_update()
    resolve()
    local me = get_me()
    if utils.throttle("bm_mode", MODE_REFRESH) then rt.cached_mode = detect_mode() end
    if not (menu.enabled and menu.enabled:get_state()) then return end
    local ok_dead, is_dead = pcall(function() return me:is_dead() end)
    if not me or (ok_dead and is_dead) then return end

    -- Sync dashboard settings (safe pcall for uninitialized menu items)
    local ok_show, show_dashboard = pcall(function() return menu.dashboard_enabled:get_state() end)
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

    -- Crowd Control check - return early if stunned/silenced/feared etc.
    if utils.is_cced and utils.is_cced(me) then return end

    -- Track combat state for clip tracker
    local ok_combat, in_combat_now = pcall(function() return me:is_in_combat() end)
    if not ok_combat then in_combat_now = false end
    if in_combat_now and not rt.in_combat then
        clip_tracker.on_combat_start()
    elseif not in_combat_now and rt.in_combat then
        clip_tracker.on_combat_end()
    end
    rt.in_combat = in_combat_now

    -- OOC Manager - handle out-of-combat buffs
    if not in_combat_now then
        ooc_manager.on_update(me, menu, utils, {
            group_buffs = {
                {
                    spell_id = rt.aspect_hawk_resolved,
                    buff_ids = spells.BUFF_ASPECT_OF_THE_HAWK,
                    name = "Aspect of the Hawk",
                    toggle = menu.use_aspect_hawk
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
    
    -- Sync pet autocast settings (throttled internally)
    sync_pet_autocast(me)

    local ok_t, t = pcall(function() return me:get_target() end)
    if not ok_t then t = nil end
    if not t or not t:is_valid() or t:is_dead() then return end
    local ok_attack, can_attack = pcall(function() return me:can_attack(t) end)
    if not (ok_attack and can_attack) then return end

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
    
    -- Burst & Trinket Automation (ported from Flux)
    local combat_time = _core_time() - (ctx.combat_start_time or _core_time())
    local is_burst_window = burst_manager.should_auto_burst(me, t, combat_time, menu)
    if is_burst_window then
        if try_bestial_wrath(me) then return end
        if try_rapid_fire(me) then return end
    end
    
    -- Sample combat forecast
    if combat_forecast and t and t:is_valid() then
        combat_forecast:sample(t)
    end
    
    -- Update trinket check to V2
    trinket_manager.check_trinkets_v2(me, t, is_burst_window, force_commands, combat_forecast, menu)

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
if header.load then
    local NS = _G.EAXHunterBM and _G.EAXHunterBM.NS or {}
    _G.EAXHunterBM = _G.EAXHunterBM or {}
    _G.EAXHunterBM.NS = NS
    NS.toggle_menu = menu.toggle_menu
end

return {}


















