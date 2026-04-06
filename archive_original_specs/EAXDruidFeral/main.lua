-- Eax Druid Feral | main.lua
-- Dual-lane cat and bear rotation logic with automatic form detection.
-- AUDIT FIXES APPLIED: 2026-04-05 - See -- FIXED: comments throughout

local menu = require("libraries/menu")
local rotation_context = require("libraries/rotation_context")
local resource_gate = require("libraries/resource_gate")
local enums = (function()
    local ok, e = pcall(require, "common/enums")
    return ok and e or nil
end)()
local spells = require("libraries/spells")
local utils = require("libraries/utils")

if not utils.same_unit then
    function utils.same_unit(a, b)
        return a ~= nil and a == b
    end
end
local eax_utils = require("libraries/eax_utils")
local color     = require("libraries/color")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

---@type interrupt_manager
local interrupt_manager = require("libraries/interrupt_manager")
---@type ooc_manager
local ooc_manager = require("libraries/ooc_manager")
---@type consumables_manager
local consumables_manager = require("libraries/consumables_manager")
---@type leveling_manager
local leveling_manager = require("libraries/leveling_manager")
local pvp_manager = require("libraries/pvp_manager")
---@type creature_utils
local creature_utils = require("libraries/creature_utils")

---@type encounter_manager
local encounter_manager = require("libraries/encounter_manager")
---@type threat_manager
local threat_manager = require("libraries/threat_manager")
---@type key_helper
local key_helper = require("common/utility/key_helper")

local control_panel_utility = require("common/utility/control_panel_helper")

-- Additional managers for feral rotation
local racial_manager = require("libraries/racial_manager")
local defensive_manager = require("libraries/defensive_manager")
local tank_recovery = require("libraries/tank_recovery")

-- Runtime table for spell IDs and state
local runtime = {
    -- Form spells
    cat_form_id = nil,
    bear_form_id = nil,
    travel_form_id = nil,
    prowl_id = nil,
    -- Combat spells
    shred_id = nil,
    mangle_cat_id = nil,
    mangle_bear_id = nil,
    lacerate_id = nil,
    swipe_id = nil,
    maul_id = nil,
    bash_id = nil,
    cyclone_id = nil,
    entangling_roots_id = nil,
    feral_charge_bear_id = nil,
    -- Utility spells
    innervate_id = nil,
    rebirth_id = nil,
    barkskin_id = nil,
    natures_grasp_id = nil,
    abolish_poison_id = nil,
    war_stomp_id = nil,
    enrage_id = nil,
    demoralizing_roar_id = nil,
    -- Buffs
    ooc_mark_of_the_wild_id = nil,
    -- State
    cached_mode = nil,
    current_lane = nil,
    combo_points = 0,
    energy_costs = {},
    -- FIXED: Added failure tracking to prevent form shift spam when OOM
    last_failed_form_shift = 0,
}

-- FIXED: Added missing context cache for rotation context
local ctx_cache = {}

-- FIXED: Added missing threat initialized flag
local threat_initialized = false

-- FIXED: Added POWER_TYPE_COMBO_POINTS constant
local POWER_TYPE_COMBO_POINTS = 4

-- Stub for set bonus tracking (not implemented in this version)
local function update_set_bonus(me)
    -- No-op: set bonus tracking not implemented
end

-- FIXED: Added missing spell resolution function
local function resolve_spells()
    -- Form spells
    runtime.cat_form_id = utils.resolve_spell_id(spells.CAT_FORM)
    runtime.bear_form_id = utils.resolve_spell_id(spells.BEAR_FORM)
    runtime.dire_bear_form_id = utils.resolve_spell_id(spells.DIRE_BEAR_FORM)
    runtime.travel_form_id = utils.resolve_spell_id(spells.BUFF_TRAVEL_FORM)
    runtime.prowl_id = utils.resolve_spell_id(spells.PROWL)
    
    -- Cat spells
    runtime.shred_id = utils.resolve_spell_id(spells.SHRED)
    runtime.mangle_cat_id = utils.resolve_spell_id(spells.MANGLE_CAT)
    runtime.rake_id = utils.resolve_spell_id(spells.RAKE)
    runtime.rip_id = utils.resolve_spell_id(spells.RIP)
    runtime.ferocious_bite_id = utils.resolve_spell_id(spells.FEROCIOUS_BITE)
    runtime.tigers_fury_id = utils.resolve_spell_id(spells.TIGERS_FURY)
    runtime.claw_id = utils.resolve_spell_id(spells.CLAW)
    runtime.maim_id = utils.resolve_spell_id(spells.MAIM)
    runtime.pounce_id = utils.resolve_spell_id(spells.POUNCE)
    runtime.ravage_id = utils.resolve_spell_id(spells.RAVAGE)
    runtime.dash_id = utils.resolve_spell_id(spells.DASH)
    runtime.cower_id = utils.resolve_spell_id(spells.COWER)
    runtime.faerie_fire_feral_id = utils.resolve_spell_id(spells.FAERIE_FIRE_FERAL)
    
    -- Bear spells
    runtime.mangle_bear_id = utils.resolve_spell_id(spells.MANGLE_BEAR)
    runtime.lacerate_id = utils.resolve_spell_id(spells.LACERATE)
    runtime.swipe_id = utils.resolve_spell_id(spells.SWIPE)
    runtime.maul_id = utils.resolve_spell_id(spells.MAUL)
    runtime.growl_id = utils.resolve_spell_id(spells.GROWL)
    runtime.bash_id = utils.resolve_spell_id(spells.BASH)
    runtime.demoralizing_roar_id = utils.resolve_spell_id(spells.DEMORALIZING_ROAR)
    runtime.feral_charge_bear_id = utils.resolve_spell_id(spells.FERAL_CHARGE_BEAR)
    runtime.frenzied_regeneration_id = utils.resolve_spell_id(spells.FRENZIED_REGENERATION)
    runtime.enrage_id = utils.resolve_spell_id(spells.ENRAGE)
    runtime.challenging_roar_id = utils.resolve_spell_id(spells.CHALLENGING_ROAR)
    
    -- Utility spells
    runtime.innervate_id = utils.resolve_spell_id(spells.INNERVATE)
    runtime.rebirth_id = utils.resolve_spell_id(spells.REBIRTH)
    runtime.barkskin_id = utils.resolve_spell_id(spells.BARKSKIN)
    runtime.natures_grasp_id = utils.resolve_spell_id(spells.NATURES_GRASP)
    runtime.abolish_poison_id = utils.resolve_spell_id(spells.ABOLISH_POISON)
    runtime.war_stomp_id = utils.resolve_spell_id(spells.WAR_STOMP)
    runtime.cyclone_id = utils.resolve_spell_id(spells.DEBUFF_CYCLONE)
    runtime.entangling_roots_id = utils.resolve_spell_id(spells.DEBUFF_ENTANGLING_ROOTS)
    runtime.survival_instincts_id = utils.resolve_spell_id(spells.SURVIVAL_INSTINCTS)
    
    -- OOC buffs
    runtime.ooc_mark_of_the_wild_id = utils.resolve_spell_id(spells.MARK_OF_THE_WILD)
    
    -- Healing spells (OOC)
    runtime.healing_touch_id = utils.resolve_spell_id(spells.HEALING_TOUCH)
    runtime.regrowth_id = utils.resolve_spell_id(spells.REGROWTH)
    runtime.rejuvenation_id = utils.resolve_spell_id(spells.REJUVENATION)
    runtime.remove_curse_id = utils.resolve_spell_id(spells.REMOVE_CURSE)
    
    -- Cache energy costs
    runtime.energy_costs = {
        shred = 40,
        mangle_cat = 40,
        rake = 40,
        rip = 30,
        ferocious_bite = 35,
        claw = 45,
        maim = 35,
        pounce = 50,
        ravage = 55,
    }
    
    -- Rage costs (bear)
    runtime.rage_costs = {
        mangle_bear = 15,
        lacerate = 15,
        swipe = 20,
        maul = 15,
        growl = 0,
        bash = 10,
        demoralizing_roar = 10,
    }
end

-- Call resolve_spells on load
resolve_spells()

-- Hot-path local caching (performance critical)
local _core_time = core.time

-- Module-level encounter policy cache (updated each tick)
local enc = nil

-- FLUX CONSTANTS (v1.9.x) - Ported from flux cat.lua
local Constants = {
    ENERGY = {
        CRITICAL = 10,              -- Critical energy threshold for emergency shift
        EARLY_SHIFT = 20,           -- Early shift threshold without Wolfshead
        EARLY_SHIFT_WOLFSHEAD = 25, -- Early shift threshold with Wolfshead
        BITE_TRICK_MAX = 39,        -- Maximum energy for bite trick
        TICK_THRESHOLD = 1.0,       -- Tick optimization threshold (seconds)
        POOL_FOR_SHRED = 75,        -- Energy to pool for final Shred before finisher
        POOL_FOR_BITE = 175,        -- Energy to pool for Ferocious Bite (max CP cost)
    },
    POWERSHIFT = {
        FUROR_ENERGY = 40,          -- Energy from Furor talent on shift
        WOLFSHEAD_BONUS = 20,       -- Additional energy from Wolfshead Helm
        MIN_INTERVAL = 1.2,         -- Minimum interval between powershifts (Wolfshead)
        MIN_INTERVAL_NO_WH = 1.5,   -- Minimum interval without Wolfshead
    },
    TIMING = {
        PENDING_CAST_TIMEOUT = 1.5,    -- seconds
        FAST_PENDING_CAST_TIMEOUT = 0.8, -- seconds for fast-retry spells
        MANGLE_REFRESH_MS = 3000,      -- 3 seconds
        LACERATE_REFRESH_MS = 3000,    -- 3 seconds
    },
}

-- FIXED: Added pending cast tracking system
local _pending_casts = {}
local function is_pending_cast(spell_id)
    if not spell_id then return false end
    local expire_time = _pending_casts[spell_id]
    if not expire_time then return false end
    if _core_time() > expire_time then
        _pending_casts[spell_id] = nil
        return false
    end
    return true
end

local function mark_pending_cast(spell_id, timeout)
    if not spell_id then return end
    _pending_casts[spell_id] = _core_time() + (timeout or Constants.TIMING.PENDING_CAST_TIMEOUT)
end

local function note_cast()
    -- No-op for cast tracking hooks
end

-- FIXED: Added missing form detection functions
local function is_in_any_bear_form(me)
    if not me or not me:is_valid() then return false end
    return utils.has_buff(me, spells.BUFF_BEAR_FORM) or utils.has_buff(me, spells.BUFF_DIRE_BEAR_FORM)
end

local function detect_ctx_form(me)
    if not me or not me:is_valid() then return "caster" end
    if utils.is_in_cat_form(me, spells) then return "cat" end
    if is_in_any_bear_form(me) then return "bear" end
    return "caster"
end

local function invalidate_ctx()
    ctx_cache = {}
end

-- FIXED: Added missing GCD check function
local function is_gcd_ready()
    local gcd = core.spell_book.get_global_cooldown()
    return gcd <= 0
end

-- FIXED: Added missing target validation function
local function is_valid_hostile_target(me, target)
    if not me or not target then return false end
    if not target:is_valid() then return false end
    if target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    return true
end

-- FIXED: Added missing lane detection function
local function get_requested_lane(me)
    local lane_setting = (menu.lane and menu.lane:get()) or 1
    if lane_setting == 2 then return "cat" end
    if lane_setting == 3 then return "bear" end
    -- Auto mode - detect based on form
    if utils.is_in_cat_form(me, spells) then return "cat" end
    if is_in_any_bear_form(me) then return "bear" end
    return "cat" -- Default to cat
end

-- FIXED: Added missing mode detection function
local function get_effective_mode()
    return runtime.cached_mode or "solo"
end

-- FIXED: Added missing TTD tracker stub
local ttd_tracker = {
    _data = {},
    update = function(target)
        if not target or not target:is_valid() then return end
        -- Simplified TTD tracking
    end,
    get = function(target)
        if not target or not target:is_valid() then return 0 end
        -- Return estimated time to die (simplified)
        local hp_pct = utils.get_health_pct(target)
        if hp_pct <= 0 then return 0 end
        -- Rough estimate: assume 10 seconds per 100% HP at current damage rate
        return hp_pct * 10
    end
}

-- FIXED: Added missing energy tick tracking
local _last_energy = 0
local _last_tick_time = 0
local function update_energy_tick(current_energy, in_cat, me)
    if not in_cat then return end
    if current_energy > _last_energy then
        _last_tick_time = _core_time()
    end
    _last_energy = current_energy
end

-- FIXED: Added missing Tiger's Fury queue tracking
local _tigers_fury_queued = false
local _tigers_fury_queued_at = 0
local function update_tigers_fury_queued_state(me)
    -- Check if Tiger's Fury buff is active
    if utils.has_buff(me, spells.BUFF_TIGERS_FURY) then
        if not _tigers_fury_queued then
            _tigers_fury_queued = true
            _tigers_fury_queued_at = _core_time()
        end
    else
        _tigers_fury_queued = false
    end
end

local function is_tigers_fury_queued()
    if not _tigers_fury_queued then return false end
    -- Queue state expires after 6 seconds (TF duration)
    if (_core_time() - _tigers_fury_queued_at) > 6 then
        _tigers_fury_queued = false
        return false
    end
    return true
end

-- FIXED: Added missing shred builder preference function
local function should_prefer_shred_builder(me, target)
    -- Prefer Shred when behind target and have energy
    if not utils.is_behind_target(me, target) then return false end
    local energy = utils.get_energy(me)
    return energy >= 40 -- Shred costs 40 energy
end

-- FIXED: Added missing tick optimization check
local function should_prefer_mangle_for_tick(me, in_cat)
    if not in_cat then return false end
    -- Check if energy tick is imminent (within 1 second)
    local time_since_tick = _core_time() - _last_tick_time
    return time_since_tick > 1.5 and time_since_tick < 2.0
end

-- FIXED: Added missing mangle debuff check
local function mangle_debuff_confirmed_by_other(target, debuff_ids, me)
    return utils.debuff_applied_by_other(target, debuff_ids, me, 3000)
end

-- FIXED: Added missing Rip guard function
local function rip_needs_refresh_soon(target, cp, rip_rem, ttd)
    if cp < 4 then return false end -- Not enough CP for Rip
    if rip_rem > 3000 then return false end -- Still has plenty of time
    if ttd > 0 and ttd < 5 then return false end -- Target dying soon
    return true
end

-- BigWigs integration: check for upcoming boss abilities
local function is_bigwigs_danger_window()
    local ok, bw = pcall(function() return core.addons.bigwigs end)
    if not ok or not bw then return false end
    local bars = bw.get_bars and bw:get_bars() or {}
    for _, bar in ipairs(bars) do
        if bar and bar.remaining and bar.remaining < 3.0 then
            return true
        end
    end
    return false
end

-- -- Feral Charge - Bear (gap closer) --------------------------------------
local function try_feral_charge_bear(me, target)
    if not runtime.feral_charge_bear_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    -- Only use in bear form or when we can shift to bear
    if not is_in_any_bear_form(me) then return false end
    -- Check range - charge is typically 8-25 yards
    -- FIXED: Changed from get_distance_to (invalid API) to distance_to (valid izi_sdk API)
    local dist = me:distance_to(target)
    if dist < 8 or dist > 25 then return false end
    -- Must be facing target - using pcall since is_facing may not be available
    local ok_facing, is_facing_result = pcall(function() return me:is_facing(target) end)
    if ok_facing and not is_facing_result then return false end
    -- Don't charge if already in melee range
    if utils.is_melee_target(me, target) then return false end
    if is_pending_cast(runtime.feral_charge_bear_id) then return false end
    if not utils.can_cast_hostile(runtime.feral_charge_bear_id, me, target) then return false end
    if utils.cast_target(runtime.feral_charge_bear_id, target) then
        -- FIXED: Added nil guard for menu.debug
        utils.log_debug(menu, "Feral Charge (Bear)")
        note_cast()
        return true
    end
    return false
end

-- -- Travel Form (OOC movement) ---------------------------------------------

-- -- Innervate (OOC mana restore) -------------------------------------------
local function try_innervate(me)
    -- FIXED: Added proper nil guard pattern for menu access
    if not (menu.use_innervate and menu.use_innervate:get_state()) then return false end
    if not runtime.innervate_id then return false end
    if me:is_in_combat() then return false end
    -- Don't fire during a bear form transition (charge/regen shift window)
    if utils.has_buff(me, spells.BUFF_BEAR_FORM) or utils.has_buff(me, spells.BUFF_DIRE_BEAR_FORM) then
        return false
    end
    local ok, mp = pcall(function()
        local max_mp = me:get_max_power(0)
        if not max_mp or max_mp <= 0 then return nil end
        return me:get_power(0) / max_mp
    end)
    -- FIXED: Added proper nil guard for menu.innervate_mana_pct
    if ok and type(mp) == "number" and mp > (((menu.innervate_mana_pct and menu.innervate_mana_pct:get()) or 30) / 100.0) then return false end
    if not utils.can_cast_self(runtime.innervate_id, me) then return false end
    if utils.cast_self(runtime.innervate_id, me) then
        utils.log_debug(menu, "Innervate (OOC mana restore)")
        note_cast()
        return true
    end
    return false
end

local function try_travel_form(me)
    -- FIXED: Added proper nil guard pattern for menu access
    if not (menu.use_travel_form and menu.use_travel_form:get_state()) then return false end
    if not runtime.travel_form_id then return false end
    if me:is_in_combat() then return false end
    if me:is_mounted() then return false end
    if utils.has_buff(me, spells.BUFF_TRAVEL_FORM) then return false end
    -- Never fight prowl - if stealthed or prowl just cast, back off entirely
    if utils.is_prowling(me, spells.BUFF_PROWL) then return false end
    if runtime.prowl_id and is_pending_cast(runtime.prowl_id) then return false end
    -- Don't shift to travel form if there's a hostile target selected - combat imminent
    local sel = me:get_target()
    if sel and sel:is_valid() and not sel:is_dead() and me:can_attack(sel) then
        return false
    end
    -- If in cat/bear form, we need to drop to caster form first before travel
    -- form becomes usable. But only drop form if prowl is NOT the intended
    -- next action - if prowl is enabled and no target, prowl should win.
    local in_cat  = utils.is_in_cat_form(me, spells)
    local in_bear = utils.has_buff(me, spells.BUFF_BEAR_FORM) or utils.has_buff(me, spells.BUFF_DIRE_BEAR_FORM)
    if in_cat then
        -- Cat form OOC with prowl enabled -> let prowl handle it, not travel form
        -- FIXED: Added proper nil guard for menu.use_prowl
        if (menu.use_prowl and menu.use_prowl:get_state()) and runtime.prowl_id then return false end
        -- Already waiting for form to drop - don't spam CancelShapeshiftForm
        if runtime.cat_form_id and is_pending_cast(runtime.cat_form_id) then return false end
        -- Drop cat form so travel form can cast next tick
        local dropped = false
        pcall(function()
            if CancelShapeshiftForm then
                CancelShapeshiftForm()
                dropped = true
            end
        end)
        if not dropped and runtime.cat_form_id then
            -- Fallback: cast cat form again to toggle it off
            utils.cast_self(runtime.cat_form_id, me)
        end
        -- Block re-entry for 1.5s while the server processes the form drop
        if runtime.cat_form_id then
            mark_pending_cast(runtime.cat_form_id, 1.5)
        end
        utils.log_debug(menu, "Travel Form: dropping cat form")
        return false
    end
    if in_bear then
        local ok = pcall(function()
            if CancelShapeshiftForm then CancelShapeshiftForm() end
        end)
        if not ok and runtime.bear_form_id then utils.cast_self(runtime.bear_form_id, me) end
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

-- -- Abolish Poison ---------------------------------------------------------
local function try_abolish_poison(me)
    -- FIXED: Added proper nil guard pattern for menu access
    if not (menu.use_abolish_poison and menu.use_abolish_poison:get_state()) then return false end
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

-- -- Nature's Grasp ---------------------------------------------------------
local function try_natures_grasp(me)
    -- FIXED: Added proper nil guard pattern for menu access
    if not (menu.use_natures_grasp and menu.use_natures_grasp:get_state()) then return false end
    if not runtime.natures_grasp_id then return false end
    if is_in_any_bear_form(me) or utils.is_in_cat_form(me, spells) then return false end
    if not utils.can_cast_self(runtime.natures_grasp_id, me) then return false end
    if utils.cast_self(runtime.natures_grasp_id, me) then
        utils.log_debug(menu, "Nature's Grasp")
        note_cast()
        return true
    end
    return false
end


-- -- Barkskin ---------------------------------------------------------------
local function try_barkskin(me)
    -- FIXED: Added proper nil guard pattern for menu access
    if not (menu.use_barkskin and menu.use_barkskin:get_state()) then return false end
    if not runtime.barkskin_id then return false end
    if utils.has_buff(me, spells.BUFF_BARKSKIN) then return false end
    local hp_pct = utils.get_health_pct(me)
    -- FIXED: Added proper nil guard for menu.barkskin_hp_pct
    if hp_pct > (((menu.barkskin_hp_pct and menu.barkskin_hp_pct:get()) or 40) / 100.0) then return false end
    if not utils.can_cast_self(runtime.barkskin_id, me) then return false end
    if utils.cast_self(runtime.barkskin_id, me) then
        utils.log_debug(menu, "Barkskin")
        note_cast()
        return true
    end
    return false
end

-- -- Helpers for smart CC decisions ---------------------------------------

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
    -- Only evaluate players - NPCs don't have meaningful healer roles
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

-- -- War Stomp (Tauren racial AoE stun) ------------------------------------
local function try_war_stomp(me, target)
    -- FIXED: Added proper nil guard pattern for menu access
    if not (menu.use_war_stomp and menu.use_war_stomp:get_state()) then return false end
    if not runtime.war_stomp_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not utils.is_melee_target(me, target) then return false end
    if is_pending_cast(runtime.war_stomp_id) then return false end
    if not utils.can_cast_self(runtime.war_stomp_id, me) then return false end
    -- Never interrupt a finisher - CPs are too valuable to waste on a stomp
    local min_finisher_cp = 99
    -- FIXED: Added proper nil guards for menu.rip_combo_points
    if (menu.use_rip and menu.use_rip:get_state()) then
        min_finisher_cp = math.min(min_finisher_cp, (menu.rip_combo_points and menu.rip_combo_points:get()) or 5)
    end
    if (menu.use_ferocious_bite and menu.use_ferocious_bite:get_state()) then
        min_finisher_cp = math.min(min_finisher_cp, 5)
    end
    if runtime.combo_points >= min_finisher_cp then return false end
    local attackers = count_melee_attackers(me)
    local my_hp = me:get_health_percentage() / 100
    -- FIXED: Added proper nil guards for menu.war_stomp_hp_pct and menu.war_stomp_attackers
    local stomp_hp = ((menu.war_stomp_hp_pct and menu.war_stomp_hp_pct:get()) or 40) / 100
    local stomp_attackers = (menu.war_stomp_attackers and menu.war_stomp_attackers:get()) or 3
    -- Fire when enough enemies are swarming, OR health is critically low
    local should_stomp = attackers >= stomp_attackers or (stomp_hp > 0 and my_hp < stomp_hp)
    if not should_stomp then return false end
    if utils.cast_self(runtime.war_stomp_id, me) then
        mark_pending_cast(runtime.war_stomp_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "War Stomp (attackers=" .. attackers .. " hp=" .. string.format("%.0f%%", my_hp * 100) .. ")")
        note_cast()
        return true
    end
    return false
end

-- -- Cyclone (CC vs healers actively healing enemies) ----------------------
local function try_cyclone(me, target)
    -- FIXED: Added proper nil guard pattern for menu access
    if not (menu.use_cyclone and menu.use_cyclone:get_state()) then return false end
    if not runtime.cyclone_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if utils.same_unit(me, target) then return false end
    if not me:can_attack(target) then return false end
    -- Cyclone is last resort - only cast when already in caster form.
    -- Never shift out of cat/bear mid-rotation just to Cyclone.
    local in_cat  = utils.is_in_cat_form(me, spells)
    local in_bear = is_in_any_bear_form(me)
    if in_cat or in_bear then return false end
    -- Bash must be on cooldown - if Bash is available, use that instead
    if runtime.bash_id then
        -- FIXED: Changed _get_spell_cd to core.spell_book.get_spell_cooldown
        local bash_cd = core.spell_book.get_spell_cooldown(runtime.bash_id)
        if bash_cd <= 0 and core.spell_book.is_usable_spell(runtime.bash_id) then
            return false  -- Bash is available, don't waste a Cyclone
        end
    end
    -- Only for healers actively casting heals on enemies - not generic casts
    if not is_healing_our_target(target, me) and not is_healer(target) then return false end
    if is_pending_cast(runtime.cyclone_id) then return false end
    if utils.has_debuff(target, spells.DEBUFF_CYCLONE) then return false end
    if not utils.can_cast_hostile(runtime.cyclone_id, me, target) then return false end
    if utils.cast_target(runtime.cyclone_id, target) then
        mark_pending_cast(runtime.cyclone_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Cyclone (last resort healer CC)")
        note_cast()
        return true
    end
    return false
end

-- -- Entangling Roots (root kiting targets or casters running away) ---------
local function try_entangling_roots(me, target)
    -- FIXED: Added proper nil guard pattern for menu access
    if not (menu.use_entangling_roots and menu.use_entangling_roots:get_state()) then return false end
    if not runtime.entangling_roots_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if utils.same_unit(me, target) then return false end
    if is_pending_cast(runtime.entangling_roots_id) then return false end
    if utils.has_debuff(target, spells.DEBUFF_ENTANGLING_ROOTS) then return false end
    -- Auto: root when target is kiting us (moving, out of melee)
    if not is_kiting(me, target) then return false end
    if not utils.can_cast_hostile(runtime.entangling_roots_id, me, target) then return false end
    if utils.cast_target(runtime.entangling_roots_id, target) then
        mark_pending_cast(runtime.entangling_roots_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Entangling Roots (kiting)")
        note_cast()
        return true
    end
    return false
end

-- FIXED: Added missing cat rotation ability stubs
local function try_pounce(me, target)
    -- Stealth opener - Pounce (stun from stealth)
    if not (menu.use_pounce and menu.use_pounce:get_state()) then return false end
    if not runtime.pounce_id then return false end
    if not utils.is_prowling(me, spells.BUFF_PROWL) then return false end
    if not target or not target:is_valid() then return false end
    if target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    
    -- Must be in melee range for Pounce
    if not utils.is_melee_target(me, target) then return false end
    
    if is_pending_cast(runtime.pounce_id) then return false end
    if not utils.can_cast_hostile(runtime.pounce_id, me, target) then return false end
    
    if utils.cast_target(runtime.pounce_id, target) then
        mark_pending_cast(runtime.pounce_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Pounce (stealth opener)")
        note_cast()
        return true
    end
    return false
end

local function try_ravage(me, target)
    -- Stealth opener - Ravage (high damage from stealth, must be behind target)
    if not (menu.use_ravage and menu.use_ravage:get_state()) then return false end
    if not runtime.ravage_id then return false end
    if not utils.is_prowling(me, spells.BUFF_PROWL) then return false end
    if not target or not target:is_valid() then return false end
    if target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    
    -- Must be behind target for Ravage
    if not utils.is_behind_target(me, target) then return false end
    
    -- Must be in melee range
    if not utils.is_melee_target(me, target) then return false end
    
    if is_pending_cast(runtime.ravage_id) then return false end
    if not utils.can_cast_hostile(runtime.ravage_id, me, target) then return false end
    
    if utils.cast_target(runtime.ravage_id, target) then
        mark_pending_cast(runtime.ravage_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Ravage (stealth opener)")
        note_cast()
        return true
    end
    return false
end

local function try_dash(me)
    -- Dash - speed boost (stealth break, so only use OOC or when not stealthed)
    if not (menu.use_feral_charge and menu.use_feral_charge:get_state()) then return false end
    if not runtime.dash_id then return false end
    
    local me_player = core.object_manager.get_local_player()
    if not me_player then return false end
    
    -- Don't use if stealthed (would break stealth)
    if utils.is_prowling(me_player, spells.BUFF_PROWL) then return false end
    
    -- Only use when in cat form
    if not utils.is_in_cat_form(me_player, spells) then return false end
    
    -- Check if already active
    if utils.has_buff(me_player, spells.BUFF_DASH) then return false end
    
    -- Only use when moving toward a target
    local target = me_player:get_target()
    if not target or not target:is_valid() then return false end
    if target:is_dead() then return false end
    if not me_player:can_attack(target) then return false end
    
    -- Only use when out of melee range (gap closer)
    if utils.is_melee_target(me_player, target) then return false end
    
    if is_pending_cast(runtime.dash_id) then return false end
    if not utils.can_cast_self(runtime.dash_id, me_player) then return false end
    
    if utils.cast_self(runtime.dash_id, me_player) then
        mark_pending_cast(runtime.dash_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Dash")
        note_cast()
        return true
    end
    return false
end

local function try_prowl(me)
    -- Prowl - stealth (only OOC)
    if not (menu.use_prowl and menu.use_prowl:get_state()) then return false end
    if not runtime.prowl_id then return false end
    if me:is_in_combat() then return false end
    
    -- Must be in cat form to prowl
    if not utils.is_in_cat_form(me, spells) then return false end
    
    -- Don't prowl if already prowling
    if utils.is_prowling(me, spells.BUFF_PROWL) then return false end
    
    -- Don't prowl if there's a hostile target selected (about to pull)
    local target = me:get_target()
    if target and target:is_valid() and not target:is_dead() and me:can_attack(target) then
        return false
    end
    
    if is_pending_cast(runtime.prowl_id) then return false end
    if not utils.can_cast_self(runtime.prowl_id, me) then return false end
    
    if utils.cast_self(runtime.prowl_id, me) then
        mark_pending_cast(runtime.prowl_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Prowl")
        return true
    end
    return false
end

local function try_faerie_fire(me, target)
    -- Faerie Fire (Feral) - armor debuff
    if not (menu.use_faerie_fire and menu.use_faerie_fire:get_state()) then return false end
    if not runtime.faerie_fire_feral_id then return false end
    if not target or not target:is_valid() then return false end
    
    -- Can be used in any form, but check if debuff already present
    if utils.has_debuff(target, spells.DEBUFF_FAERIE_FIRE) then return false end
    
    -- Don't overwrite if target has Sunder Armor (same effect)
    if spells.DEBUFF_SUNDER_ARMOR and utils.has_debuff(target, spells.DEBUFF_SUNDER_ARMOR) then return false end
    
    -- Don't FF if target about to die
    local ttd = ttd_tracker.get(target)
    if ttd > 0 and ttd < 5 then return false end
    
    if is_pending_cast(runtime.faerie_fire_feral_id) then return false end
    if not utils.can_cast_hostile(runtime.faerie_fire_feral_id, me, target) then return false end
    
    if utils.cast_target(runtime.faerie_fire_feral_id, target) then
        mark_pending_cast(runtime.faerie_fire_feral_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Faerie Fire (Feral)")
        note_cast()
        return true
    end
    return false
end

local function try_rip(me, target, ctx)
    -- Rip - bleed finisher
    if not (menu.use_rip and menu.use_rip:get_state()) then return false end
    if not runtime.rip_id then return false end
    if not target or not target:is_valid() then return false end
    if not utils.is_in_cat_form(me, spells) then return false end
    
    -- Check combo points
    local required_cp = (menu.rip_combo_points and menu.rip_combo_points:get()) or 4
    if runtime.combo_points < required_cp then return false end
    
    -- Check if Rip is already on target
    local rip_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_RIP)
    local refresh_seconds = (menu.rip_refresh_seconds and menu.rip_refresh_seconds:get()) or 3
    if rip_rem > (refresh_seconds * 1000) then return false end
    
    -- Check energy
    local energy = utils.get_energy(me)
    local rip_energy = runtime.energy_costs.rip or 30
    if energy < rip_energy then return false end
    
    -- TTD check - don't rip if target dying too soon
    local ttd = ttd_tracker.get(target)
    if ttd > 0 and ttd < 8 then return false end
    
    -- Check for rip_only_elites setting
    if menu.rip_only_elites and menu.rip_only_elites:get_state() then
        local ok, classification = pcall(function() return target:get_classification() end)
        if not ok or not classification or classification < 2 then
            return false -- Not an elite or boss
        end
    end
    
    if is_pending_cast(runtime.rip_id) then return false end
    if not utils.can_cast_hostile(runtime.rip_id, me, target) then return false end
    
    if utils.cast_target(runtime.rip_id, target) then
        mark_pending_cast(runtime.rip_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Rip (" .. runtime.combo_points .. " CP)")
        note_cast()
        return true
    end
    return false
end

local function try_ferocious_bite(me, target, target_hp_pct, ctx)
    -- Ferocious Bite - execute finisher
    if not (menu.use_ferocious_bite and menu.use_ferocious_bite:get_state()) then return false end
    if not runtime.ferocious_bite_id then return false end
    if not target or not target:is_valid() then return false end
    if not utils.is_in_cat_form(me, spells) then return false end
    
    -- Check combo points
    local min_cp = (menu.bite_min_cp and menu.bite_min_cp:get()) or 5
    if runtime.combo_points < min_cp then return false end
    
    -- Check energy - FB uses all available energy for bonus damage
    local energy = utils.get_energy(me)
    local fb_energy = runtime.energy_costs.ferocious_bite or 35
    if energy < fb_energy then return false end
    
    -- Max energy check to avoid wasting excess energy
    local max_energy = (menu.bite_max_energy and menu.bite_max_energy:get()) or 39
    if energy > max_energy then return false end
    
    -- Execute mode check
    if menu.use_bite_execute and menu.use_bite_execute:get_state() then
        local killshot_hp = ((menu.bite_killshot_hp_pct and menu.bite_killshot_hp_pct:get()) or 15) / 100
        if target_hp_pct > killshot_hp then
            -- Not in execute range - check if we should FB anyway (no Rip, short TTD)
            local rip_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_RIP)
            local ttd = ttd_tracker.get(target)
            if rip_rem > 0 or (ttd > 0 and ttd > 10) then
                return false -- Save CPs for Rip
            end
        end
    else
        -- Not in execute mode - only FB if Rip not viable
        local rip_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_RIP)
        local ttd = ttd_tracker.get(target)
        if rip_rem > 0 or (ttd > 0 and ttd > 8) then
            return false -- Rip is better
        end
    end
    
    if is_pending_cast(runtime.ferocious_bite_id) then return false end
    if not utils.can_cast_hostile(runtime.ferocious_bite_id, me, target) then return false end
    
    if utils.cast_target(runtime.ferocious_bite_id, target) then
        mark_pending_cast(runtime.ferocious_bite_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Ferocious Bite (" .. runtime.combo_points .. " CP, " .. energy .. " energy)")
        note_cast()
        return true
    end
    return false
end

local function try_bite_trick(me, target)
    -- Bite Trick - low energy FB dump in "dead zone" (CP 3-5, energy 35-39)
    if not (menu.use_bite_trick and menu.use_bite_trick:get_state()) then return false end
    if not runtime.ferocious_bite_id then return false end
    if not target or not target:is_valid() then return false end
    if not utils.is_in_cat_form(me, spells) then return false end
    
    -- Must have combo points but not maxed for Rip
    if runtime.combo_points < 3 or runtime.combo_points > 5 then return false end
    
    -- Energy dead zone: enough for FB but not much more
    local energy = utils.get_energy(me)
    if energy < 35 or energy > Constants.ENERGY.BITE_TRICK_MAX then return false end
    
    -- Don't bite trick if Rip would be better
    local rip_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_RIP)
    local ttd = ttd_tracker.get(target)
    if rip_rem <= 0 and ttd > 8 then
        -- Rip would be better, but check if we can afford it
        local rip_energy = runtime.energy_costs.rip or 30
        if energy >= rip_energy then
            return false -- Can afford Rip, don't waste CP on FB
        end
    end
    
    if is_pending_cast(runtime.ferocious_bite_id) then return false end
    if not utils.can_cast_hostile(runtime.ferocious_bite_id, me, target) then return false end
    
    if utils.cast_target(runtime.ferocious_bite_id, target) then
        mark_pending_cast(runtime.ferocious_bite_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Ferocious Bite [Bite Trick] (" .. runtime.combo_points .. " CP, " .. energy .. " energy)")
        note_cast()
        return true
    end
    return false
end

local function try_maim(me, target)
    -- Maim - interrupt finisher (stun)
    if not (menu.use_maim and menu.use_maim:get_state()) then return false end
    if not runtime.maim_id then return false end
    if not target or not target:is_valid() then return false end
    if not utils.is_in_cat_form(me, spells) then return false end
    
    -- Only use at 5 CP as an interrupt
    if runtime.combo_points < 5 then return false end
    
    -- Target must be casting
    if not target:is_casting_spell() and not target:is_channelling_spell() then return false end
    
    -- Check energy
    local energy = utils.get_energy(me)
    local maim_energy = runtime.energy_costs.maim or 35
    if energy < maim_energy then return false end
    
    -- Don't Maim if Rip would be better (check TTD)
    local ttd = ttd_tracker.get(target)
    if ttd > 12 then
        -- Target will live long enough for Rip to be worthwhile
        local rip_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_RIP)
        if rip_rem <= 3000 then
            return false -- Rip would be better
        end
    end
    
    if is_pending_cast(runtime.maim_id) then return false end
    if not utils.can_cast_hostile(runtime.maim_id, me, target) then return false end
    
    if utils.cast_target(runtime.maim_id, target) then
        mark_pending_cast(runtime.maim_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Maim (interrupt)")
        note_cast()
        return true
    end
    return false
end

local function try_tigers_fury(me, target, ctx)
    -- Tiger's Fury - energy cooldown
    if not (menu.use_tigers_fury and menu.use_tigers_fury:get_state()) then return false end
    if not runtime.tigers_fury_id then return false end
    if not utils.is_in_cat_form(me, spells) then return false end
    
    -- Check if already active
    if utils.has_buff(me, spells.BUFF_TIGERS_FURY) then return false end
    
    -- Check energy threshold
    local energy = utils.get_energy(me)
    local tf_threshold = (menu.tigers_fury_energy and menu.tigers_fury_energy:get()) or 30
    if energy > tf_threshold then return false end
    
    -- Don't use TF if we're about to powershift (wastes the energy)
    if menu.use_powershift and menu.use_powershift:get_state() then
        if energy < Constants.ENERGY.CRITICAL then
            return false -- Let powershift handle low energy
        end
    end
    
    if is_pending_cast(runtime.tigers_fury_id) then return false end
    if not utils.can_cast_self(runtime.tigers_fury_id, me) then return false end
    
    if utils.cast_self(runtime.tigers_fury_id, me) then
        mark_pending_cast(runtime.tigers_fury_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Tiger's Fury")
        note_cast()
        return true
    end
    return false
end

local function try_mangle_cat(me, target, ctx)
    -- Mangle (Cat) - bleed debuff + builder
    if not (menu.use_mangle_cat and menu.use_mangle_cat:get_state()) then return false end
    if not runtime.mangle_cat_id then return false end
    if not target or not target:is_valid() then return false end
    if not utils.is_in_cat_form(me, spells) then return false end
    
    -- Check if Mangle debuff is already applied by us or another
    local mangle_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_MANGLE)
    if mangle_rem > Constants.TIMING.MANGLE_REFRESH_MS then return false end
    if mangle_debuff_confirmed_by_other(target, spells.DEBUFF_MANGLE, me) then return false end
    if mangle_debuff_confirmed_by_other(target, spells.DEBUFF_TRAUMA, me) then return false end
    
    -- Check energy
    local energy = utils.get_energy(me)
    local mangle_energy = runtime.energy_costs.mangle_cat or 40
    if energy < mangle_energy then return false end
    
    if is_pending_cast(runtime.mangle_cat_id) then return false end
    if not utils.can_cast_hostile(runtime.mangle_cat_id, me, target) then return false end
    
    if utils.cast_target(runtime.mangle_cat_id, target) then
        mark_pending_cast(runtime.mangle_cat_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Mangle (Cat)")
        note_cast()
        return true
    end
    return false
end

local function try_rake(me, target)
    -- Rake - bleed DoT builder
    if not (menu.use_rake and menu.use_rake:get_state()) then return false end
    if not runtime.rake_id then return false end
    if not target or not target:is_valid() then return false end
    if not utils.is_in_cat_form(me, spells) then return false end
    
    -- Check if Rake is already on target
    local rake_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_RAKE)
    local refresh_seconds = (menu.rake_refresh_seconds and menu.rake_refresh_seconds:get()) or 3
    if rake_rem > (refresh_seconds * 1000) then return false end
    
    -- Check energy
    local energy = utils.get_energy(me)
    local rake_energy = runtime.energy_costs.rake or 40
    if energy < rake_energy then return false end
    
    -- Don't overwrite early unless we're about to energy cap
    if rake_rem > 0 and energy < 90 then return false end
    
    if is_pending_cast(runtime.rake_id) then return false end
    if not utils.can_cast_hostile(runtime.rake_id, me, target) then return false end
    
    if utils.cast_target(runtime.rake_id, target) then
        mark_pending_cast(runtime.rake_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Rake")
        note_cast()
        return true
    end
    return false
end

local function try_rake_trick(me, target)
    -- Original Rake Trick - Rake at specific timing
    if not (menu.use_rake and menu.use_rake:get_state()) then return false end
    if not runtime.rake_id then return false end
    if not target or not target:is_valid() then return false end
    if not utils.is_in_cat_form(me, spells) then return false end
    
    local energy = utils.get_energy(me)
    -- Rake trick timing: apply Rake just before energy tick
    local time_since_tick = _core_time() - _last_tick_time
    if time_since_tick < 1.5 or time_since_tick > 1.9 then
        return false -- Not in the sweet spot
    end
    
    -- Don't overwrite existing Rake unless it's about to fall
    local rake_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_RAKE)
    if rake_rem > 3000 then return false end
    
    local rake_energy = runtime.energy_costs.rake or 40
    if energy < rake_energy then return false end
    
    if is_pending_cast(runtime.rake_id) then return false end
    if not utils.can_cast_hostile(runtime.rake_id, me, target) then return false end
    
    if utils.cast_target(runtime.rake_id, target) then
        mark_pending_cast(runtime.rake_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Rake [Trick]")
        note_cast()
        return true
    end
    return false
end

local function try_rake_trick_flux(me, target, ctx)
    -- Flux Rake Trick - Advanced timing optimization
    if not (menu.use_rake_trick_flux and menu.use_rake_trick_flux:get_state()) then return false end
    if not runtime.rake_id then return false end
    if not target or not target:is_valid() then return false end
    if not utils.is_in_cat_form(me, spells) then return false end
    
    -- Similar to regular rake trick but with more precise timing
    local time_since_tick = _core_time() - _last_tick_time
    local energy = utils.get_energy(me)
    
    -- Optimal: 1.8-1.95s after tick (just before next tick)
    if time_since_tick < 1.8 or time_since_tick > 1.95 then
        return false
    end
    
    -- Need enough energy for Rake but will gain tick energy immediately after
    local rake_energy = runtime.energy_costs.rake or 40
    if energy < rake_energy then return false end
    if energy > rake_energy + 20 then return false end -- Would waste energy
    
    -- Don't overwrite
    local rake_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_RAKE)
    if rake_rem > 2000 then return false end
    
    if is_pending_cast(runtime.rake_id) then return false end
    if not utils.can_cast_hostile(runtime.rake_id, me, target) then return false end
    
    if utils.cast_target(runtime.rake_id, target) then
        mark_pending_cast(runtime.rake_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Rake [Flux Trick]")
        note_cast()
        return true
    end
    return false
end

-- Helper for Claw when Shred is not available
local function try_claw(me, target)
    if not runtime.claw_id then return false end
    if not utils.is_in_cat_form(me, spells) then return false end
    
    local energy = utils.get_energy(me)
    local claw_energy = runtime.energy_costs.claw or 45
    if energy < claw_energy then return false end
    
    if is_pending_cast(runtime.claw_id) then return false end
    if not utils.can_cast_hostile(runtime.claw_id, me, target) then return false end
    
    if utils.cast_target(runtime.claw_id, target) then
        mark_pending_cast(runtime.claw_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Claw")
        note_cast()
        return true
    end
    return false
end

local function try_shred_or_filler(me, target, ctx)
    -- Shred or Claw filler - combo point builder
    if not (menu.use_shred and menu.use_shred:get_state()) then return false end
    if not target or not target:is_valid() then return false end
    if not utils.is_in_cat_form(me, spells) then return false end
    
    -- Must be behind target for Shred
    if not utils.is_behind_target(me, target) then 
        -- Try Claw instead if enabled and Shred requires behind
        if menu.use_claw and menu.use_claw:get_state() and runtime.claw_id then
            return try_claw(me, target)
        end
        return false 
    end
    
    if not runtime.shred_id then 
        -- Fallback to Claw if Shred not available
        if menu.use_claw and menu.use_claw:get_state() and runtime.claw_id then
            return try_claw(me, target)
        end
        return false 
    end
    
    -- Don't shred if we should be pooling for finisher
    if runtime.combo_points >= 5 then return false end
    
    -- Check energy
    local energy = utils.get_energy(me)
    local shred_energy = runtime.energy_costs.shred or 40
    if energy < shred_energy then return false end
    
    if is_pending_cast(runtime.shred_id) then return false end
    if not utils.can_cast_hostile(runtime.shred_id, me, target) then return false end
    
    if utils.cast_target(runtime.shred_id, target) then
        mark_pending_cast(runtime.shred_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Shred")
        note_cast()
        return true
    end
    return false
end

-- FIXED: Added missing powershift function stubs
local function try_critical_energy_shift(me)
    -- Emergency powershift at very low energy
    if not (menu.use_powershift and menu.use_powershift:get_state()) then return false end
    if not utils.is_in_cat_form(me, spells) then return false end
    
    local energy = utils.get_energy(me)
    -- Only shift at critically low energy
    if energy > Constants.ENERGY.CRITICAL then return false end
    
    -- Don't shift if we just shifted
    if is_pending_cast(runtime.cat_form_id or 0) then return false end
    
    return try_powershift(me)
end

local function try_rip_powershift(me, target)
    -- Powershift specifically to afford Rip when energy-starved
    if not (menu.use_powershift and menu.use_powershift:get_state()) then return false end
    if not utils.is_in_cat_form(me, spells) then return false end
    if not target or not target:is_valid() then return false end
    
    -- Must have CP for Rip
    local rip_cp = (menu.rip_combo_points and menu.rip_combo_points:get()) or 4
    if runtime.combo_points < rip_cp then return false end
    
    -- Check if Rip is viable
    local rip_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_RIP)
    if rip_rem > 3000 then return false end -- Rip still ticking
    
    -- Must be energy starved but need Rip soon
    local energy = utils.get_energy(me)
    local rip_energy = runtime.energy_costs.rip or 30
    if energy >= rip_energy then return false end -- Can afford Rip already
    if energy > Constants.ENERGY.CRITICAL then return false end -- Not critical yet
    
    local ttd = ttd_tracker.get(target)
    if ttd > 0 and ttd < 8 then return false end -- Target dying
    
    return try_powershift(me)
end

local function try_mangle_powershift(me, target)
    -- Powershift specifically to afford Mangle when energy-starved
    if not (menu.use_powershift and menu.use_powershift:get_state()) then return false end
    if not utils.is_in_cat_form(me, spells) then return false end
    if not target or not target:is_valid() then return false end
    
    -- Check if Mangle debuff needs refresh
    local mangle_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_MANGLE)
    if mangle_rem > 2000 then return false end -- Mangle still up
    if mangle_debuff_confirmed_by_other(target, spells.DEBUFF_MANGLE, me) then return false end
    if mangle_debuff_confirmed_by_other(target, spells.DEBUFF_TRAUMA, me) then return false end
    
    -- Must be energy starved
    local energy = utils.get_energy(me)
    local mangle_energy = runtime.energy_costs.mangle_cat or 40
    if energy >= mangle_energy then return false end -- Can afford already
    if energy > Constants.ENERGY.EARLY_SHIFT then return false end -- Not low enough
    
    return try_powershift(me)
end

local function try_wolfshead_shred_shift(me, target)
    -- Smart shift when Shred needed but energy low (Wolfshead Helm bonus)
    if not (menu.use_wolfshead_shred_shift and menu.use_wolfshead_shred_shift:get_state()) then return false end
    if not utils.is_in_cat_form(me, spells) then return false end
    if not target or not target:is_valid() then return false end
    if not utils.is_behind_target(me, target) then return false end -- Can't Shred
    
    local energy = utils.get_energy(me)
    -- With Wolfshead, shift at 25+ energy for 60 energy after shift
    local threshold = Constants.ENERGY.EARLY_SHIFT_WOLFSHEAD
    if energy > threshold then return false end
    if energy < 10 then return false end -- Too low, wait for more
    
    -- Don't shift if we can already afford Shred
    local shred_energy = runtime.energy_costs.shred or 40
    if energy >= shred_energy then return false end
    
    return try_powershift(me)
end

local function try_early_shift(me)
    -- Early shift when energy is low and not pooling
    if not (menu.use_powershift and menu.use_powershift:get_state()) then return false end
    if not utils.is_in_cat_form(me, spells) then return false end
    
    local energy = utils.get_energy(me)
    local threshold = Constants.ENERGY.EARLY_SHIFT
    if energy > threshold then return false end
    
    -- Don't early shift if we're pooling for something
    -- Check if we're deliberately conserving energy
    if runtime.combo_points >= 5 then
        -- Pooling for Rip/FB - don't shift
        return false
    end
    
    return try_powershift(me)
end

local function try_powershift(me)
    -- General powershift - shift out and back for energy
    if not (menu.use_powershift and menu.use_powershift:get_state()) then return false end
    if not runtime.cat_form_id then return false end
    if not utils.is_in_cat_form(me, spells) then return false end
    
    -- Check mana floor
    local mana_pct = utils.get_mana_pct(me)
    local min_mana = ((menu.powershift_min_mana and menu.powershift_min_mana:get()) or 20) / 100
    if mana_pct < min_mana then return false end
    
    -- Only powershift when energy is critically low
    local energy = utils.get_energy(me)
    if energy > Constants.ENERGY.CRITICAL then return false end
    
    -- Don't powershift if Tiger's Fury just used (waste of energy buff)
    if is_tigers_fury_queued() then return false end
    
    -- Don't powershift if we're pooling energy for something
    if energy > 50 then return false end
    
    -- Check GCD - powershift triggers GCD
    if not is_gcd_ready() then return false end
    
    -- Drop form
    pcall(function()
        if CancelShapeshiftForm then CancelShapeshiftForm() end
    end)
    
    -- Re-cast cat form (will give Furor energy on next tick)
    if utils.cast_self(runtime.cat_form_id, me) then
        mark_pending_cast(runtime.cat_form_id, Constants.TIMING.FAST_PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Powershift (energy=" .. energy .. ")")
        return true
    end
    return false
end

-- FIXED: Implemented bear rotation abilities
local function try_frenzied_regeneration(me)
    if not (menu.use_frenzied_regeneration and menu.use_frenzied_regeneration:get_state()) then return false end
    if not runtime.frenzied_regeneration_id then return false end
    if not is_in_any_bear_form(me) then return false end
    if utils.has_buff(me, spells.BUFF_FRENZIED_REGENERATION) then return false end
    local hp_pct = utils.get_health_pct(me)
    local threshold = ((menu.frenzied_regeneration_hp_pct and menu.frenzied_regeneration_hp_pct:get()) or 40) / 100.0
    if hp_pct > threshold then return false end
    if not utils.can_cast_self(runtime.frenzied_regeneration_id, me) then return false end
    if utils.cast_self(runtime.frenzied_regeneration_id, me) then
        utils.log_debug(menu, "Frenzied Regeneration")
        note_cast()
        return true
    end
    return false
end

local function try_growl(me, target)
    if not (menu.use_growl and menu.use_growl:get_state()) then return false end
    if not runtime.growl_id then return false end
    if not target or not target:is_valid() then return false end
    if not is_in_any_bear_form(me) then return false end
    -- Check if target is targeting someone else (taunt needed)
    local target_target = target:get_target()
    if not target_target or not target_target:is_valid() then return false end
    if utils.same_unit(target_target, me) then return false end -- Already targeting me
    if not utils.can_cast_hostile(runtime.growl_id, me, target) then return false end
    if is_pending_cast(runtime.growl_id) then return false end
    if utils.cast_target(runtime.growl_id, target) then
        mark_pending_cast(runtime.growl_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Growl")
        note_cast()
        return true
    end
    return false
end

local function try_bash(me, target)
    if not (menu.use_bash and menu.use_bash:get_state()) then return false end
    if not runtime.bash_id then return false end
    if not target or not target:is_valid() then return false end
    if not is_in_any_bear_form(me) then return false end
    if not utils.is_melee_target(me, target) then return false end
    if is_pending_cast(runtime.bash_id) then return false end
    if not utils.can_cast_hostile(runtime.bash_id, me, target) then return false end
    if utils.cast_target(runtime.bash_id, target) then
        mark_pending_cast(runtime.bash_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Bash")
        note_cast()
        return true
    end
    return false
end

local function try_survival_instincts(me)
    if not (menu.use_survival_instincts and menu.use_survival_instincts:get_state()) then return false end
    if not runtime.survival_instincts_id then return false end
    if utils.has_buff(me, spells.BUFF_SURVIVAL_INSTINCTS) then return false end
    local hp_pct = utils.get_health_pct(me)
    if hp_pct > 0.5 then return false end -- Only use when health is low
    if not utils.can_cast_self(runtime.survival_instincts_id, me) then return false end
    if utils.cast_self(runtime.survival_instincts_id, me) then
        utils.log_debug(menu, "Survival Instincts")
        note_cast()
        return true
    end
    return false
end

local function try_challenging_roar(me)
    if not (menu.use_challenging_roar and menu.use_challenging_roar:get_state()) then return false end
    if not runtime.challenging_roar_id then return false end
    if not is_in_any_bear_form(me) then return false end
    if is_pending_cast(runtime.challenging_roar_id) then return false end
    -- Only use when party members are in danger
    if not party_member_in_danger(me) then return false end
    if not utils.can_cast_self(runtime.challenging_roar_id, me) then return false end
    if utils.cast_self(runtime.challenging_roar_id, me) then
        mark_pending_cast(runtime.challenging_roar_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Challenging Roar")
        note_cast()
        return true
    end
    return false
end

local function try_taunt_off_party(me)
    if not (menu.auto_growl and menu.auto_growl:get_state()) then return false end
    if not runtime.growl_id then return false end
    if not is_in_any_bear_form(me) then return false end
    -- Find enemies targeting party members
    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() 
           and me:can_attack(obj) and obj:is_in_combat() then
            local target_target = obj:get_target()
            if target_target and target_target:is_valid() and not utils.same_unit(target_target, me) 
               and target_target:is_party_member() then
                if utils.can_cast_hostile(runtime.growl_id, me, obj) then
                    if is_pending_cast(runtime.growl_id) then return false end
                    if utils.cast_target(runtime.growl_id, obj) then
                        mark_pending_cast(runtime.growl_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
                        utils.log_debug(menu, "Growl (taunt off party)")
                        note_cast()
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- FIXED: Implemented OOC ability stubs
local function try_ooc_self_heal(me)
    if not (menu.use_ooc_self_heal and menu.use_ooc_self_heal:get_state()) then return false end
    if me:is_in_combat() then return false end
    local hp_pct = utils.get_health_pct(me)
    local threshold = ((menu.ooc_self_heal_hp_pct and menu.ooc_self_heal_hp_pct:get()) or 50) / 100.0
    if hp_pct > threshold then return false end
    -- Use Healing Touch or Regrowth if available
    if runtime.healing_touch_id and utils.can_cast_self(runtime.healing_touch_id, me) then
        if utils.cast_self(runtime.healing_touch_id, me) then
            utils.log_debug(menu, "Healing Touch (OOC)")
            note_cast()
            return true
        end
    end
    if runtime.regrowth_id and utils.can_cast_self(runtime.regrowth_id, me) then
        if utils.cast_self(runtime.regrowth_id, me) then
            utils.log_debug(menu, "Regrowth (OOC)")
            note_cast()
            return true
        end
    end
    return false
end

local function try_remove_curse_feral(me)
    if not (menu.use_remove_curse and menu.use_remove_curse:get_state()) then return false end
    if not runtime.remove_curse_id then return false end
    if me:is_in_combat() then return false end
    -- Check self for curse debuffs
    local auras = me:get_debuffs()
    if not auras then return false end
    for i = 1, #auras do
        local a = auras[i]
        if a and a.type and a.type == 2 then  -- type 2 = curse
            if utils.can_cast_self(runtime.remove_curse_id, me) then
                if utils.cast_self(runtime.remove_curse_id, me) then
                    utils.log_debug(menu, "Remove Curse (self)")
                    note_cast()
                    return true
                end
            end
            break
        end
    end
    return false
end

local function try_root_escape(me)
    if not (menu.use_root_escape and menu.use_root_escape:get_state()) then return false end
    -- Check if rooted (can't move)
    if me:is_moving() then return false end -- Not rooted if we can move
    -- Try to shift forms to break roots
    local in_cat = utils.is_in_cat_form(me, spells)
    local in_bear = is_in_any_bear_form(me)
    -- If in cat, shift to bear and back
    if in_cat and runtime.bear_form_id then
        pcall(function()
            if CancelShapeshiftForm then CancelShapeshiftForm() end
        end)
        if utils.cast_self(runtime.bear_form_id, me) then
            utils.log_debug(menu, "Root Escape: Cat -> Bear")
            return true
        end
    end
    -- If in bear, shift to cat and back
    if in_bear and runtime.cat_form_id then
        pcall(function()
            if CancelShapeshiftForm then CancelShapeshiftForm() end
        end)
        if utils.cast_self(runtime.cat_form_id, me) then
            utils.log_debug(menu, "Root Escape: Bear -> Cat")
            return true
        end
    end
    return false
end

local function try_shift_form(me, lane)
    -- Form shifting logic - handles switching to appropriate form for combat
    if not me or not me:is_valid() then return false end
    
    -- Check mana floor - don't shift if mana too low
    local mana_pct = utils.get_mana_pct(me)
    local min_mana = ((menu.shift_mana_floor and menu.shift_mana_floor:get()) or 20) / 100
    if mana_pct < min_mana then
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[FORM] Shift blocked - mana too low (" .. math.floor(mana_pct * 100) .. "% < " .. (min_mana * 100) .. "%)")
        end
        return false
    end
    
    -- Check if we're currently in travel form - must drop it first
    if utils.has_buff(me, spells.BUFF_TRAVEL_FORM) then
        -- Drop travel form
        local dropped = false
        pcall(function()
            if CancelShapeshiftForm then
                CancelShapeshiftForm()
                dropped = true
            end
        end)
        -- Mark as pending so we don't try again immediately
        if runtime.travel_form_id then
            mark_pending_cast(runtime.travel_form_id, 1.5)
        end
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[FORM] Dropping Travel Form")
        end
        return false -- Return false so we can shift to cat next tick
    end
    
    -- Determine target form based on lane
    local target_form = "cat" -- Default
    if lane == "bear" or lane == "guardian" then
        target_form = "bear"
    end
    
    -- Check if already in correct form
    if target_form == "cat" and utils.is_in_cat_form(me, spells) then
        return false -- Already in cat form
    end
    if target_form == "bear" and is_in_any_bear_form(me) then
        return false -- Already in bear form
    end
    
    -- Check if auto_form is enabled (or manual mode)
    local auto_form = true
    if menu.auto_form then
        auto_form = menu.auto_form:get_state()
    end
    
    -- Only auto-shift if enabled or lane is explicitly set
    -- FIXED: lane is a string ("cat"/"bear"/"guardian"), not a number
    -- Check the menu setting directly for auto mode
    local lane_setting = (menu.lane and menu.lane:get()) or 1
    if not auto_form and lane_setting == 1 then
        -- Auto mode disabled and menu set to "Auto" (index 1)
        return false
    end
    
    -- FIXED: Add throttle to prevent spam when cast fails (OOM, etc.)
    local last_failed_shift = runtime.last_failed_form_shift or 0
    if (core.time() - last_failed_shift) < 2.0 then
        return false -- Wait 2 seconds before retrying failed shift
    end
    
    -- Attempt to shift to target form
    if target_form == "cat" then
        if not runtime.cat_form_id then return false end
        -- Drop any current form first
        pcall(function()
            if CancelShapeshiftForm then CancelShapeshiftForm() end
        end)
        -- Cast cat form
        if utils.can_cast_self(runtime.cat_form_id, me) then
            if utils.cast_self(runtime.cat_form_id, me) then
                mark_pending_cast(runtime.cat_form_id, Constants.TIMING.FAST_PENDING_CAST_TIMEOUT)
                utils.log_debug(menu, "[FORM] -> Cat Form")
                return true
            else
                -- Cast failed (OOM, etc.) - mark failure time to prevent spam
                runtime.last_failed_form_shift = core.time()
            end
        else
            -- Cannot cast (cooldown, OOM, etc.) - mark failure time
            runtime.last_failed_form_shift = core.time()
        end
    elseif target_form == "bear" then
        if not runtime.bear_form_id and not runtime.dire_bear_form_id then return false end
        -- Drop any current form first
        pcall(function()
            if CancelShapeshiftForm then CancelShapeshiftForm() end
        end)
        -- Cast bear form (prefer Dire Bear if available)
        local form_to_cast = runtime.dire_bear_form_id or runtime.bear_form_id
        if form_to_cast and utils.can_cast_self(form_to_cast, me) then
            if utils.cast_self(form_to_cast, me) then
                mark_pending_cast(form_to_cast, Constants.TIMING.FAST_PENDING_CAST_TIMEOUT)
                utils.log_debug(menu, "[FORM] -> Bear Form")
                return true
            else
                -- Cast failed (OOM, etc.) - mark failure time to prevent spam
                runtime.last_failed_form_shift = core.time()
            end
        else
            -- Cannot cast (cooldown, OOM, etc.) - mark failure time
            runtime.last_failed_form_shift = core.time()
        end
    end
    
    return false
end

local function do_cat_rotation(me, target, ctx)
    local target_hp_pct = utils.get_health_pct(target)
    local in_stealth = utils.is_prowling(me, spells.BUFF_PROWL)
    local in_cat = utils.is_in_cat_form(me, spells)
    local current_energy = utils.get_energy(me)

    -- FLUX FIX v1.8.x: Update energy tick tracker every frame while in cat form
    -- This detects energy ticks (20 energy per 2s) for optimal powershifting
    -- Also detects swings from Furor energy (40 energy on auto-attack)
    update_energy_tick(current_energy, in_cat, me)
    
    -- FLUX v1.9.x: Update Tiger's Fury queued state tracking
    update_tigers_fury_queued_state(me)

    -- Defensive / self-cast (always safe, don't break stealth)
    if try_barkskin(me) then return true end
    if try_abolish_poison(me) then return true end

    -- While stealthed: ONLY fire stealth openers - nothing else hostile.
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

    -- FIXED: Moved Faerie Fire before melee check - it's a ranged ability
    if try_faerie_fire(me, target) then return true end
    
    -- FIXED: Removed early return that was blocking FF - now only blocks melee abilities
    if not utils.is_melee_target(me, target) then
        -- Not in melee range - can't use melee abilities
        -- But we've already tried ranged abilities above
        return false
    end

    -- -- Omen of Clarity (Clearcasting proc) ----------------------------------
    -- Free next ability - spend it immediately on the highest-value action.
    -- Priority: Shred (highest damage/CP) > Mangle (debuff maintenance) > Rake
    local has_clearcasting = utils.has_buff(me, spells.BUFF_CLEARCASTING)
    if has_clearcasting and runtime.combo_points < 5 then
        -- Shred is best value on a free proc
        -- FIXED: Added proper nil guard for menu.use_shred
        if (menu.use_shred and menu.use_shred:get_state()) and runtime.shred_id and should_prefer_shred_builder(me, target)
           and utils.is_behind_target(me, target)
           and not is_pending_cast(runtime.shred_id)
           and utils.can_cast_hostile(runtime.shred_id, me, target) then
            if utils.cast_target(runtime.shred_id, target) then
                mark_pending_cast(runtime.shred_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
                utils.log_debug(menu, "Shred [Clearcasting]")
                note_cast()
                return true
            end
        end
        -- Mangle if Shred is not the preferred free spender
        -- FIXED: Added proper nil guard for menu.use_mangle_cat
        if (menu.use_mangle_cat and menu.use_mangle_cat:get_state()) and runtime.mangle_cat_id
            and not is_pending_cast(runtime.mangle_cat_id)
            and utils.can_cast_hostile(runtime.mangle_cat_id, me, target) then
            if utils.cast_target(runtime.mangle_cat_id, target) then
                mark_pending_cast(runtime.mangle_cat_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
                utils.log_debug(menu, "Mangle [Clearcasting]")
                note_cast()
                return true
            end
        end
    end

    -- Calculate dynamic DoT refresh thresholds and Rip guard status
    local rip_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_RIP)
    local ttd = ttd_tracker.get(target)
    local cp = runtime.combo_points
    local rip_guard_active = rip_needs_refresh_soon(target, cp, rip_rem, ttd)

    -- Finishers first - always spend CPs before anything else
    if try_rip(me, target, ctx) then return true end
    if try_ferocious_bite(me, target, target_hp_pct, ctx) then return true end
    -- Bite Trick: low-energy FB dump when in energy dead zone (CP 3-5, energy 35-39)
    -- Guard: Don't Bite Trick if Rip needs refresh soon
    if not rip_guard_active then
        if try_bite_trick(me, target) then return true end
    end
    -- Maim: only at CP=5 when target is casting and Rip is not the right choice
    if try_maim(me, target) then return true end
    -- Tiger's Fury: energy recovery, fires during builder phase (CP < 4)
    -- Guard: Don't TF if queued or about to powershift
    if not is_tigers_fury_queued() then
        if try_tigers_fury(me, target, ctx) then return true end
    end
    -- Builder priority: Mangle (debuff) -> Rake (bleed) -> Shred/Claw
    if try_mangle_cat(me, target, ctx) then return true end
    if try_rake(me, target) then return true end
    -- Rake Trick: Flux version first, fallback to original
    if try_rake_trick_flux(me, target, ctx) then return true end
    if try_rake_trick(me, target) then return true end
    
    -- Shred with tick optimization: prefer Mangle over Shred when tick imminent
    -- to avoid dead GCD after Shred + tick
    if not should_prefer_mangle_for_tick(me, in_cat) then
        if try_shred_or_filler(me, target, ctx) then return true end
    else
        -- Tick optimization active: try Mangle builder first
        -- FIXED: Added proper nil guard for menu.use_mangle_cat
        if (menu.use_mangle_cat and menu.use_mangle_cat:get_state()) and runtime.mangle_cat_id then
            local mangle_energy = runtime.energy_costs.mangle_cat or 40
            if current_energy >= mangle_energy or has_clearcasting then
                if not is_pending_cast(runtime.mangle_cat_id) 
                   and utils.can_cast_hostile(runtime.mangle_cat_id, me, target) then
                    if utils.cast_target(runtime.mangle_cat_id, target) then
                        mark_pending_cast(runtime.mangle_cat_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
                        utils.log_debug(menu, "Mangle (tick optimization)")
                        note_cast()
                        return true
                    end
                end
            end
        end
        -- Fallback to normal shred/filler if Mangle not available
        if try_shred_or_filler(me, target, ctx) then return true end
    end

    -- FLUX POWERSHIFT VARIANTS (in priority order):
    -- 1. Critical Energy Shift - emergency powershift at very low energy
    if try_critical_energy_shift(me) then return true end
    -- 2. Rip Powershift - shift to afford Rip when energy-starved
    if try_rip_powershift(me, target) then return true end
    -- 3. Mangle Powershift - shift to afford Mangle debuff when energy-starved
    if try_mangle_powershift(me, target) then return true end
    -- 4. Wolfshead Shred Shift - smart shift when Shred needed but energy low (Wolfshead only)
    if try_wolfshead_shred_shift(me, target) then return true end
    -- 5. Early Shift - general powershift when energy is low and not pooling
    if try_early_shift(me) then return true end
    -- 6. General powershift (fallback)
    if try_powershift(me) then return true end

    -- Auto-attack fallback for leveling 1-70
    if me:is_in_combat() and target and target:is_valid() and not target:is_dead()
       and me:can_attack(target) then
        leveling_manager.ensure_melee(me, target)
    end

    -- DEBUG: Log when no spells were cast with spell attempt summary
    -- FIXED: Added proper nil guard for menu.debug
    if menu.debug and menu.debug:get_state() then
        utils.log_debug(menu, "[ROTATION] Cat rotation complete - no spells cast (attempted: Rip, FB, TF, Mangle, Rake, Shred)")
    end

    return false
end

local function try_mangle_bear(me, target, ctx)
    -- FIXED: Added proper nil guard for menu.use_mangle_bear
    if not (menu.use_mangle_bear and menu.use_mangle_bear:get_state()) then return false end
    if not runtime.mangle_bear_id then return false end
    local can_cast = resource_gate.feral.has_bear_rage(ctx, 12)
    if not can_cast then return false end
    local mangle_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_MANGLE)
    if mangle_rem > Constants.TIMING.MANGLE_REFRESH_MS then return false end
    if mangle_debuff_confirmed_by_other(target, spells.DEBUFF_MANGLE, me) then return false end
    if mangle_debuff_confirmed_by_other(target, spells.DEBUFF_TRAUMA, me) then return false end
    if is_pending_cast(runtime.mangle_bear_id) then return false end
    if not utils.can_cast_hostile(runtime.mangle_bear_id, me, target) then return false end

    if utils.cast_target(runtime.mangle_bear_id, target) then
        mark_pending_cast(runtime.mangle_bear_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Mangle (Bear)")
        note_cast()
        return true
    end

    return false
end

local function try_swipe(me, enemy_count, min_count_override, ctx)
    -- DEBUG: Entry logging
    -- FIXED: Added proper nil guard for menu.debug
    if menu.debug and menu.debug:get_state() then
        utils.log_debug(menu, "[SPELL] Attempting Swipe...")
    end
    
    if enc and not enc.aoe_safe then 
        -- FIXED: Added proper nil guard for menu.debug
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Swipe - BLOCKED: encounter not AOE safe")
        end
        return false 
    end
    -- FIXED: Added proper nil guard for menu.use_swipe
    if not (menu.use_swipe and menu.use_swipe:get_state()) then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Swipe - BLOCKED: disabled in menu")
        end
        return false 
    end
    if not runtime.swipe_id then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Swipe - BLOCKED: spell not available")
        end
        return false 
    end
    local can_cast = resource_gate.feral.has_bear_rage(ctx, 20)
    if not can_cast then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Swipe - BLOCKED: resource gate failed")
        end
        return false 
    end
    -- FIXED: Added proper nil guard for menu.swipe_enemy_count
    local min_count = min_count_override or ((menu.swipe_enemy_count and menu.swipe_enemy_count:get()) or 3)
    if enemy_count < min_count then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Swipe - BLOCKED: not enough enemies (" .. enemy_count .. " < " .. min_count .. ")")
        end
        return false 
    end
    if is_pending_cast(runtime.swipe_id) then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Swipe - BLOCKED: pending cast")
        end
        return false 
    end
    if not utils.can_cast_self(runtime.swipe_id, me) then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Swipe - BLOCKED: can_cast_self failed")
        end
        return false 
    end

    if utils.cast_self(runtime.swipe_id, me) then
        mark_pending_cast(runtime.swipe_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Swipe")
        note_cast()
        return true
    end

    return false
end

local function try_maul(me, target, ctx)
    -- DEBUG: Entry logging
    if menu.debug and menu.debug:get_state() then
        utils.log_debug(menu, "[SPELL] Attempting Maul...")
    end
    
    -- FIXED: Added proper nil guard for menu.use_maul
    if not (menu.use_maul and menu.use_maul:get_state()) then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Maul - BLOCKED: disabled in menu")
        end
        return false 
    end
    if not runtime.maul_id then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Maul - BLOCKED: spell not available")
        end
        return false 
    end
    local can_cast = resource_gate.feral.has_bear_rage(ctx, 15)
    if not can_cast then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Maul - BLOCKED: resource gate failed")
        end
        return false 
    end
    -- FIXED: Added proper nil guard for menu.maul_min_rage
    if utils.get_rage(me) < ((menu.maul_min_rage and menu.maul_min_rage:get()) or 20) then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Maul - BLOCKED: insufficient rage")
        end
        return false 
    end
    if is_pending_cast(runtime.maul_id) then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Maul - BLOCKED: pending cast")
        end
        return false 
    end
    if not utils.can_cast_melee(runtime.maul_id, me) then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Maul - BLOCKED: can_cast_melee failed")
        end
        return false 
    end

    if utils.cast_target_fast(runtime.maul_id, target) then
        mark_pending_cast(runtime.maul_id, Constants.TIMING.FAST_PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Maul")
        note_cast()
        return true
    end

    return false
end


-- --- Bear utility (v1.1) --------------------------------------------------

local function try_demoralizing_roar(me, target)
    -- DEBUG: Entry logging
    if menu.debug and menu.debug:get_state() then
        utils.log_debug(menu, "[SPELL] Attempting Demoralizing Roar...")
    end
    
    -- FIXED: Added proper nil guard for menu.use_demoralizing_roar
    if not (menu.use_demoralizing_roar and menu.use_demoralizing_roar:get_state()) then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Demoralizing Roar - BLOCKED: disabled in menu")
        end
        return false 
    end
    if not runtime.demoralizing_roar_id then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Demoralizing Roar - BLOCKED: spell not available")
        end
        return false 
    end
    -- Demoralizing Roar is an AoE - check nearby enemies, not just the target
    if utils.enemy_count_in_radius(me, 8) < 2 then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Demoralizing Roar - BLOCKED: not enough enemies nearby")
        end
        return false 
    end
    -- Use a generous remaining time so we don't recast constantly
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_DEMORALIZING_ROAR) > 4000 then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Demoralizing Roar - BLOCKED: debuff still active")
        end
        return false 
    end
    if is_pending_cast(runtime.demoralizing_roar_id) then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Demoralizing Roar - BLOCKED: pending cast")
        end
        return false 
    end
    if not utils.can_cast_self(runtime.demoralizing_roar_id, me) then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Demoralizing Roar - BLOCKED: can_cast_self failed")
        end
        return false 
    end
    if utils.cast_self(runtime.demoralizing_roar_id, me) then
        mark_pending_cast(runtime.demoralizing_roar_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
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
local LACERATE_REFRESH_MS   = Constants.TIMING.LACERATE_REFRESH_MS

local function try_lacerate(me, target)
    -- DEBUG: Entry logging
    if menu.debug and menu.debug:get_state() then
        utils.log_debug(menu, "[SPELL] Attempting Lacerate...")
    end
    
    -- FIXED: Added proper nil guard for menu.use_lacerate
    if not (menu.use_lacerate and menu.use_lacerate:get_state()) then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Lacerate - BLOCKED: disabled in menu")
        end
        return false 
    end
    if not runtime.lacerate_id then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Lacerate - BLOCKED: spell not available")
        end
        return false 
    end
    if not utils.has_buff(me, spells.BUFF_BEAR_FORM) and
       not utils.has_buff(me, spells.BUFF_DIRE_BEAR_FORM) then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Lacerate - BLOCKED: not in bear form")
        end
        return false 
    end
    if is_pending_cast(runtime.lacerate_id) then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Lacerate - BLOCKED: pending cast")
        end
        return false 
    end
    -- TTD gate: don't build Lacerate stacks if the fight is nearly over
    local ttd = ttd_tracker.get(target)
    if ttd > 0 and ttd < 8 then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Lacerate - BLOCKED: TTD too short (" .. ttd .. " < 8)")
        end
        return false 
    end
    if not utils.can_cast_hostile(runtime.lacerate_id, me, target) then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[SPELL] Lacerate - BLOCKED: can_cast_hostile failed")
        end
        return false 
    end

    local stacks    = utils.get_debuff_stacks(target, spells.DEBUFF_LACERATE)
    local remaining = utils.get_debuff_remaining_ms(target, spells.DEBUFF_LACERATE)

    local should_cast = (stacks < LACERATE_MAX_STACKS)
                     or (stacks >= LACERATE_MAX_STACKS and remaining <= LACERATE_REFRESH_MS)
    if not should_cast then return false end

    if utils.cast_target(runtime.lacerate_id, target) then
        mark_pending_cast(runtime.lacerate_id, Constants.TIMING.PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Lacerate (" .. tostring(math.min(stacks + 1, LACERATE_MAX_STACKS)) .. " stacks)")
        note_cast()
        return true
    end
    return false
end


local function do_bear_rotation(me, target, ctx)
    local mode = get_effective_mode()
    local enemy_count = utils.enemy_count_in_radius(me, 8)

    if try_frenzied_regeneration(me) then return true end
    if try_growl(me, target) then return true end
    if try_feral_charge_bear(me, target) then return true end
    if try_bash(me, target) then return true end
    if try_faerie_fire(me, target) then return true end
    if not utils.is_melee_target(me, target) then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[ROTATION] Bear rotation - target not in melee range")
        end
        return false 
    end
    if try_demoralizing_roar(me, target) then return true end
    if try_mangle_bear(me, target, ctx) then return true end
    if try_lacerate(me, target) then return true end
    if try_swipe(me, enemy_count, nil, ctx) then return true end
    if try_maul(me, target, ctx) then return true end

    -- DEBUG: Log when no spells were cast
    if menu.debug and menu.debug:get_state() then
        utils.log_debug(menu, "[ROTATION] Bear rotation complete - no spells cast (attempted: FrenziedRegen, Growl, Charge, Bash, FF, DemoRoar, MangleBear, Lacerate, Swipe, Maul)")
    end

    return false
end

-- -----------------------------------------------------------------------------
-- GUARDIAN / TANK ABILITIES
-- -----------------------------------------------------------------------------

local function try_enrage(me)
    -- FIXED: Added proper nil guard for menu.use_enrage
    if not (menu.use_enrage and menu.use_enrage:get_state()) then return false end
    if not runtime.enrage_id then return false end
    if utils.has_buff(me, spells.BUFF_ENRAGE) then return false end
    -- FIXED: Added proper nil guard for menu.enrage_rage_threshold
    if utils.get_rage(me) > ((menu.enrage_rage_threshold and menu.enrage_rage_threshold:get()) or 45) then return false end
    if is_pending_cast(runtime.enrage_id) then return false end
    if not utils.can_cast_self(runtime.enrage_id, me) then return false end
    if utils.cast_self_fast(runtime.enrage_id, me) then
        mark_pending_cast(runtime.enrage_id, Constants.TIMING.FAST_PENDING_CAST_TIMEOUT)
        utils.log_debug(menu, "Enrage (rage=" .. tostring(math.floor(utils.get_rage(me))) .. ")")
        note_cast()
        return true
    end
    return false
end

-- Scan party members - return true if any are below the configured HP threshold
local function party_member_in_danger(me)
    -- FIXED: Added proper nil guard for menu.challenging_roar_party_hp_pct
    local threshold = ((menu.challenging_roar_party_hp_pct and menu.challenging_roar_party_hp_pct:get()) or 40) / 100
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

local function do_guardian_rotation(me, target, ctx)
    local enemy_count = utils.enemy_count_in_radius(me, 8)
    local mode = get_effective_mode()

    -- Emergency defensive layer (highest priority)
    if try_survival_instincts(me) then return true end
    if try_frenzied_regeneration(me) then return true end
    if try_barkskin(me) then return true end

    -- Rage generation - do this early so we have rage for abilities
    if try_enrage(me) then return true end

    -- Gap closer / engage
    if try_feral_charge_bear(me, target) then return true end

    -- AoE taunt - pull threat off party before anything else
    if try_challenging_roar(me) then return true end
    if try_taunt_off_party(me) then return true end
    -- Single target taunt on primary target
    if try_growl(me, target) then return true end

    if try_bash(me, target) then return true end
    if try_faerie_fire(me, target) then return true end
    if not utils.is_melee_target(me, target) then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[ROTATION] Guardian rotation - target not in melee range")
        end
        return false 
    end

    if try_demoralizing_roar(me, target) then return true end

    -- Core threat rotation: Mangle -> Lacerate stacks -> Swipe AoE -> Maul rage dump
    if try_mangle_bear(me, target, ctx) then return true end
    if try_lacerate(me, target) then return true end
    -- FIXED: Added proper nil guard for menu.guardian_swipe_enemy_count
    if try_swipe(me, enemy_count, (menu.guardian_swipe_enemy_count and menu.guardian_swipe_enemy_count:get()) or 3, ctx) then return true end
    if try_maul(me, target, ctx) then return true end

    -- DEBUG: Log when no spells were cast
    if menu.debug and menu.debug:get_state() then
        utils.log_debug(menu, "[ROTATION] Guardian rotation complete - no spells cast (attempted: Survival, FrenziedRegen, Barkskin, Enrage, Charge, ChallengingRoar, TauntParty, Growl, Bash, FF, DemoRoar, MangleBear, Lacerate, Swipe, Maul)")
    end

    return false
end

local function do_rotation(me, target)
    -- DEBUG: Trace rotation execution
    if menu.debug and menu.debug:get_state() then
        utils.log_debug(menu, "[ROTATION] Starting - GCD ready: " .. tostring(is_gcd_ready()) .. ", Target valid: " .. tostring(is_valid_hostile_target(me, target)))
    end
    
    local ok_cp, api_cp = pcall(function() return me:get_power(POWER_TYPE_COMBO_POINTS) end)
    if ok_cp and type(api_cp) == "number" then
        runtime.combo_points = math.max(0, math.min(5, api_cp))
    end
    
    -- DEBUG: State snapshot at rotation start
    if menu.debug and menu.debug:get_state() then
        local energy = utils.get_energy(me)
        local rage = utils.get_rage(me)
        local form = detect_ctx_form(me)
        local in_melee = target and utils.is_melee_target(me, target)
        utils.log_debug(menu, "[STATE] Energy=" .. energy .. " Rage=" .. rage .. " CP=" .. runtime.combo_points .. " Form=" .. form .. " InMelee=" .. tostring(in_melee))
    end
    
    if not is_gcd_ready() then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[ROTATION] BLOCKED - GCD not ready")
        end
        return false 
    end

    ttd_tracker.update(target)
    local lane = get_requested_lane(me)
    runtime.current_lane = lane

    local current_form = detect_ctx_form(me)
    if ctx_cache.form ~= current_form then
        ctx_cache.form = current_form
        invalidate_ctx()
    end

    if try_root_escape(me) then return true end
    if try_shift_form(me, lane) then return true end
    if not is_valid_hostile_target(me, target) then
        -- DEBUG: Log why target validation failed
        if menu.debug and menu.debug:get_state() then
            local reason = "unknown"
            if not target then reason = "no_target"
            elseif not target:is_valid() then reason = "target_invalid"
            elseif target:is_dead() then reason = "target_dead"
            elseif not me:can_attack(target) then reason = "cannot_attack"
            end
            utils.log_debug(menu, "[ROTATION] BLOCKED - Target invalid: " .. reason)
        end
        -- No valid target - reset CPs only if we had a target before
        if runtime.combo_points > 0 then
            local ok, cp_obj = pcall(function() return me:get_combo_points_target() end)
            if not ok or not cp_obj or not cp_obj:is_valid() then
                runtime.combo_points = 0
            end
        end
        return false
    end

    -- Zero only on confirmed target death/change, not on combat-flag flicker
    do
        local ok, cp_obj = pcall(function() return me:get_combo_points_target() end)
        if ok and cp_obj and cp_obj:is_valid() then
            -- CPs are on a live target - check if it changed
            if target and not utils.same_unit(cp_obj, target) then
                runtime.combo_points = 0
            end
        elseif ok and (not cp_obj or not cp_obj:is_valid()) then
            -- No CP target at all - genuinely zero
            runtime.combo_points = 0
        end
    end

    local ctx = rotation_context.get(ctx_cache, me, target, {
        now_s = _core_time,
    })

    -- Prowl OOC when in cat form and no target yet
    if not me:is_in_combat() then
        if try_prowl(me) then return true end
    end

    -- DEBUG: Log which lane is being used
    if menu.debug and menu.debug:get_state() then
        utils.log_debug(menu, "[ROTATION] Lane detected: " .. lane .. ", Form: " .. tostring(current_form))
    end

    if lane == "cat" then
        return do_cat_rotation(me, target, ctx)
    elseif lane == "guardian" then
        return do_guardian_rotation(me, target, ctx)
    end
    return do_bear_rotation(me, target, ctx)
end

local GROUP_ROLE_HEALER = 1
local GROUP_ROLE_DAMAGER = 2

local function safe_get_guid(unit)
    if not unit or type(unit.get_guid) ~= "function" then
        return nil
    end

    local ok, guid = pcall(function() return unit:get_guid() end)
    if not ok or guid == nil then
        return nil
    end

    return tostring(guid)
end

local function get_cast_progress_pct(unit)
    if not unit or not unit:is_valid() then
        return 0
    end

    if type(unit.get_channeling_or_casting_pct) == "function" then
        local ok, pct = pcall(function() return unit:get_channeling_or_casting_pct() end)
        if ok and pct then
            return math.max(0, math.min((tonumber(pct) or 0) / 100, 1))
        end
    end

    return 0
end

local function classify_recovery_victim(me, victim)
    if not victim or not victim:is_valid() or utils.same_unit(me, victim) or not victim:is_party_member() then
        return nil
    end

    local ok, role_id = pcall(function() return victim:get_group_role() end)
    if not ok then
        return nil
    end

    if role_id == GROUP_ROLE_HEALER then
        return "healer"
    end
    if role_id == GROUP_ROLE_DAMAGER then
        return "damager"
    end

    return nil
end

local function is_interruptible_enemy(unit)
    if not unit or not unit:is_valid() then
        return false
    end
    if unit:is_casting_spell() then
        return unit:is_active_spell_interruptable()
    end
    return unit:is_channelling_spell()
end

local function build_tank_recovery_state(me, ctx)
    local candidates = {}
    local helper_candidates = {}
    local by_guid = {}
    local off_me_count = 0
    local dangerous_count = 0
    local objects = core.object_manager.get_all_objects()

    for i = 1, #objects do
        local unit = objects[i]
        if unit and unit:is_valid() and unit:is_unit() and not unit:is_dead() and me:can_attack(unit) and unit:is_in_combat() then
            local victim = unit:get_target()
            local victim_role = classify_recovery_victim(me, victim)
            if victim_role then
                local guid = safe_get_guid(unit)
                if guid then
                    local dangerous = unit:is_casting_spell() or unit:is_channelling_spell()
                    off_me_count = off_me_count + 1
                    if dangerous then
                        dangerous_count = dangerous_count + 1
                    end
                    local candidate = {
                        guid = guid,
                        unit = unit,
                        victim_role = victim_role,
                        dangerous_caster = dangerous,
                        interruptible = is_interruptible_enemy(unit),
                        cast_progress_pct = get_cast_progress_pct(unit),
                    }
                    candidates[#candidates + 1] = candidate
                    helper_candidates[#helper_candidates + 1] = candidate
                    by_guid[guid] = candidate
                end
            end
        end
    end

    local snapshot = {
        self = {
            hp_pct = (((ctx or {}).self or {}).hp_pct) or (me:get_health_percentage() / 100),
            incoming_damage_pct_2s = (((ctx or {}).self or {}).incoming_damage_pct_2s) or 0,
            incoming_heal_pct = (((ctx or {}).self or {}).incoming_heal_pct) or 0,
        },
        party = {
            group_collapse_risk = (((ctx or {}).party or {}).group_collapse_risk) or 0,
            threat_instability = math.min(1, (off_me_count * 0.45) + (dangerous_count > 0 and 0.20 or 0)),
        },
    }

    local choice = tank_recovery.select_recovery_target(me, {
        snapshot = snapshot,
        candidates = helper_candidates,
    })

    return {
        snapshot = snapshot,
        candidates = candidates,
        target = choice and by_guid[choice.guid] and by_guid[choice.guid].unit or nil,
    }
end


reactive_adapter = {
    spec = "EAXDruidFeral",
    actions = {
        life_save_self = {
            handler = function(_, action_deps)
                return defensive_manager.try_defensive(action_deps.me, "druid", utils)
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

                -- FIXED: Added proper nil guard for menu.use_interrupt
                return (menu.use_interrupt and menu.use_interrupt:get_state()) and interrupt_manager.try_interrupt(action_deps.me, interrupt_target, "druid", utils)
            end,
        },
        anti_overheal = { noop = "unsupported" },
        anti_aggro = {
            handler = function(ctx, action_deps)
                local recovery_state = build_tank_recovery_state(action_deps.me, ctx)
                if tank_recovery.should_prioritize_defensive(recovery_state.snapshot, {
                    candidates = recovery_state.candidates,
                }) then
                    if try_survival_instincts(action_deps.me) then return true end
                    if try_frenzied_regeneration(action_deps.me) then return true end
                    if try_barkskin(action_deps.me) then return true end
                    return defensive_manager.try_defensive(action_deps.me, "druid", utils)
                end

                local recovery_target = action_deps.target or recovery_state.target or action_deps.current_target
                if not recovery_target or not recovery_target:is_valid() then
                    return false
                end

                if try_challenging_roar(action_deps.me) then return true end
                if try_taunt_off_party(action_deps.me) then return true end
                if try_growl(action_deps.me, recovery_target) then return true end
                return try_bash(action_deps.me, recovery_target)
            end,
        },
        throughput_resume = { noop = "unsupported" },
    },
    resolve_target = function(action_id, ctx, action_deps)
        if action_id == "interrupt_control" then
            local current = action_deps.current_target
            if current and current:is_valid() and interrupt_manager.should_interrupt(current) then
                return current
            end
        end

        if action_id == "interrupt_control" or action_id == "anti_aggro" then
            local recovery_state = build_tank_recovery_state(action_deps.me, ctx)
            return recovery_state.target
        end

        return nil
    end,
}

local function on_render()
    return
end

-- ESP only renders when this spec is enabled
core.register_on_render_callback(function()
    -- FIXED: Added proper nil guard for menu.enabled
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

-- Track last time ANY builder incremented CP, to deduplicate same-cast events
local _last_cp_increment_time = 0
local _last_cast_seen = {}

local function on_spell_cast(data)
    if not data or not data.spell_id then return end

    -- Only count spells cast by the local player
    local me = core.object_manager.get_local_player()
    if not me then return end
    if data.caster and data.caster:is_valid() then
        if not utils.same_unit(data.caster, me) then return end
    end

    local sid = data.spell_id
    local now = _core_time()

    if CP_BUILDERS[sid] then
        -- Deduplicate: if ANY builder already incremented CP very recently,
        -- skip. Uses a short 0.15s window - duplicate events from the same cast
        -- happen within the same frame (microseconds apart), not 0.5s later.
        -- A longer window was blocking legitimate sequential builders (Rake -> Mangle).
        if (now - _last_cp_increment_time) < 0.15 then return end
        _last_cp_increment_time = now

        -- If this builder hit a different target than our current CP target,
        -- the old CPs are gone - reset before incrementing on the new target.
        local ok, cp_obj = pcall(function() return me:get_combo_points_target() end)
        if ok and cp_obj and cp_obj:is_valid() and data.target and data.target:is_valid() then
            if not utils.same_unit(cp_obj, data.target) then
                runtime.combo_points = 0
                utils.log_debug(menu, "[CP] target changed, reset to 0")
            end
        end
        -- Cast callback is only a backup. Server CP sync in do_rotation() is authoritative.
        local ok_cp, api_cp = pcall(function() return me:get_power(POWER_TYPE_COMBO_POINTS) end)
        if ok_cp and type(api_cp) == "number" and api_cp >= 0 then
            runtime.combo_points = math.max(0, math.min(5, api_cp))
        else
            runtime.combo_points = math.min(5, runtime.combo_points + 1)
        end
        utils.log_debug(menu, "[CP] builder " .. sid .. " -> CP=" .. runtime.combo_points)
    elseif CP_FINISHERS[sid] then
        -- Deduplicate finishers too
        if (now - _last_cp_increment_time) < 0.15 then return end
        _last_cp_increment_time = now
        runtime.combo_points = 0
        utils.log_debug(menu, "[CP] finisher " .. sid .. " -> CP=0")
    end
end

-- DEBUG: Comprehensive rotation blocker diagnostics
local function debug_rotation_blockers(me, target)
    -- FIXED: Added proper nil guard for menu.debug
    if not menu.debug or not menu.debug:get_state() then return end
    
    local blockers = {}
    
    if not is_gcd_ready() then
        table.insert(blockers, "gcd_not_ready")
    end
    
    if not is_valid_hostile_target(me, target) then
        table.insert(blockers, "invalid_target")
    end
    
    if me:is_dead() then
        table.insert(blockers, "player_dead")
    end
    
    if eax_utils.is_eating_or_drinking(me) then
        table.insert(blockers, "eating_drinking")
    end
    
    if not me:is_in_combat() then
        table.insert(blockers, "not_in_combat")
    end
    
    if #blockers > 0 then
        utils.log_debug(menu, "[BLOCKED] " .. table.concat(blockers, ", "))
    end
end

core.register_on_spell_cast_callback(on_spell_cast)
core.register_on_update_callback(function()
    local me = core.object_manager.get_local_player()
    if not me then return end
    
    -- Update control panel
    if control_panel_utility then
        control_panel_utility:on_update(menu)
    end
    
    if not threat_initialized then threat_manager.init(me); threat_initialized = true end

    if utils.throttle("eaxdruidferal_mode_refresh", 5.0) then
        runtime.cached_mode = utils.detect_mode(me)
    end

    if utils.throttle("eaxdruidferal_set_bonus", 10.0) then
        update_set_bonus(me)
    end

    -- FIXED: Added periodic spell resolution refresh (for talent changes, leveling)
    if utils.throttle("eaxdruidferal_spell_resolve", 30.0) then
        resolve_spells()
    end

    -- DEBUG: Log if menu is disabled (most common reason for no spell casting)
    -- FIXED: Added proper nil guard for menu.enabled
    if not (menu.enabled and menu.enabled:get_state()) then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[BLOCKED] menu.enabled is false - rotation disabled")
        end
        return 
    end

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
    if me:is_dead() then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[BLOCKED] player is dead")
        end
        return 
    end

    -- FIXED: Added proper nil guard for menu.auto_ooc_food_drink
    if menu.auto_ooc_food_drink and menu.auto_ooc_food_drink:get_state() then
        consumables_manager.try_use_ooc_food_drink(me, menu, utils)
    end

    if me:is_in_combat() then
        -- FIXED: Added proper nil guard for menu.auto_combat_potions
        if menu.auto_combat_potions and menu.auto_combat_potions:get_state() then
            consumables_manager.try_use_combat_consumable(me, menu, utils)
        end
        -- FIXED: Added proper nil guard for menu.auto_flask
        if menu.auto_flask and menu.auto_flask:get_state() then
            consumables_manager.try_maintain_flask(me, menu, utils)
        end
    end

    if eax_utils.is_eating_or_drinking(me) then return end

    -- OOC utility
    if not me:is_in_combat() then
        if try_ooc_self_heal(me) then return end
        if try_remove_curse_feral(me) then return end
        if try_innervate(me) then return end
        if try_abolish_poison(me) then return end
        -- Travel form last - prowl (fired in do_rotation below) takes priority,
        -- and travel form guards against active targets itself
        if try_travel_form(me) then return end
    end

    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    -- Validate focus target is hostile; if not, fall through to smart selector
    if focus_target and not me:can_attack(focus_target) then 
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "[TARGET] Focus target not hostile, falling back")
        end
        focus_target = nil 
    end
    -- Smart target selection: prioritize units actively fighting us/party
    local target = focus_target or utils.find_best_target(me)
    -- DEBUG: Log target selection results
    if menu.debug and menu.debug:get_state() then
        if not target then
            utils.log_debug(menu, "[TARGET] No target found (focus + find_best_target both nil)")
        elseif focus_target then
            utils.log_debug(menu, "[TARGET] Using focus target")
        else
            utils.log_debug(menu, "[TARGET] Using find_best_target result")
        end
    end
    -- PvP: prioritize enemy players in arena/BG/world PvP
    local pvp_instance = pvp_manager.is_in_pvp_instance()
    if pvp_instance or pvp_manager.is_world_pvp(me) then
        local enemy_players = pvp_manager.find_enemy_players(me, 40)
        if #enemy_players > 0 then
            local priority = pvp_manager.priority_target(me, enemy_players)
            if priority then target = priority end
        end
    end

    -- CP finisher lock: when CPs are at the finisher threshold, stick to the
    -- mob the CPs were built on. Switching targets at CP=5 wastes the finisher.
    if not focus_target then
        local min_finisher_cp = 99
        -- FIXED: Added proper nil guard for menu.use_rip
        if menu.use_rip and menu.use_rip:get_state() then
            min_finisher_cp = math.min(min_finisher_cp, (menu.rip_combo_points and menu.rip_combo_points:get()) or 5)
        end
        -- FIXED: Added proper nil guard for menu.use_ferocious_bite
        if menu.use_ferocious_bite and menu.use_ferocious_bite:get_state() then
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
    -- DEBUG: Log encounter policy blocks
    if menu.debug and menu.debug:get_state() then
        if enc and enc.hold_cooldowns then
            utils.log_debug(menu, "[BLOCKED] encounter policy holding cooldowns")
        end
    end

    -- Interrupt
    if target and target:is_valid() and me:can_attack(target) and interrupt_manager.should_interrupt(target) then
        -- FIXED: Added proper nil guard for menu.use_interrupt
        if (menu.use_interrupt and menu.use_interrupt:get_state()) and interrupt_manager.try_interrupt(me, target, "druid", utils) then
            return
        end
    end

    -- Racial CDs
    if racial_manager.try_offensive(me) then return true end
    if racial_manager.try_utility(me, target) then return true end
    if racial_manager.try_defensive(me) then return true end

    -- Defensive abilities
    if defensive_manager.try_defensive(me, "druid", utils) then
        return
    end

    -- Self-emergency healing
    -- FIXED: Added proper nil guard for menu.frenzied_regeneration_hp_pct
    local self_threshold = eax_utils.get_self_heal_threshold(me, ((menu.frenzied_regeneration_hp_pct and menu.frenzied_regeneration_hp_pct:get()) or 40) / 100.0, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_frenzied_regeneration(me) then return end
    end

    -- DEBUG: Check and log blockers before attempting rotation
    debug_rotation_blockers(me, target)

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
        -- FIXED: Added proper nil guard for menu.toggle_key
        local toggle_key = (menu.toggle_key and menu.toggle_key:get_key_code()) or 7
        local label = "Eax Druid Feral] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxdruidferal_enabled_cp")
        return elements
    end)
end


-- -- Eax Conflict Detection -------------------------------------------------
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
        -- FIXED: Added proper nil guard for menu.enabled
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
        core.log("[Eax WARNING] Multiple " .. _eax_class .. " specs enabled: "
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
core.log("[Eax Druid Feral] Loaded " .. (_pi and _pi.plugin_version or "?") .. "")
