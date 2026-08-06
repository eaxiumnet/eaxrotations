-- marksmanship_sylvanas.lua — Hunter Marksmanship rotation for TBC Anniversary (2.5.5).
-- WHAT:  ranged DPS spec (Aimed Shot, Trueshot Aura, Rapid Fire, Steady Shot weave,
--         Aspect Hawk/Viper dynamic swap, pet management, melee weaving).
-- WHEN:  combat, with valid enemy target.
-- WHY:   mirrors wowsims APL: Aimed Shot > Multi-Shot > Steady Shot filler.
-- SAFETY: state.* reads nil-guarded via spec_kit.safe_state(); no on_update allocs;
--          registration guarded.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.HunterSpells or {}

-- spec_kit migration #23
local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
local define = spec_kit.define_action_for_class(SPELLS)
local ACTION = {
    AimedShot        = define("AimedShot",        { 27065, 20904, 20903, 20902, 20901, 20900, 19434 }, "AimedShot"),
    ArcaneShot       = define("ArcaneShot",       { 27019, 14287, 14286, 14285, 14284, 14283, 14282, 14281, 3044 }, "ArcaneShot"),
    AspectOfTheHawk  = define("AspectOfTheHawk",  { 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 }, "AspectOfTheHawk"),
    AspectOfTheViper = define("AspectOfTheViper", { 34074 }, "AspectOfTheViper"),
    BestialWrath     = define("BestialWrath",     { 19574 }, "BestialWrath"),
    CallPet          = define("CallPet",          { 883 }, "CallPet"),
    ExplosiveTrap    = define("ExplosiveTrap",    { 27025, 14317, 14316, 13813 }, "ExplosiveTrap"),
    FeignDeath       = define("FeignDeath",       { 5384 }, "FeignDeath"),
    FreezingTrap     = define("FreezingTrap",     { 14311, 14310, 1499 }, "FreezingTrap"),
    HuntersMark      = define("HuntersMark",      { 14325, 14324, 14323, 1130 }, "Hunter's Mark"),
    KillCommand      = define("KillCommand",      { 34026 }, "KillCommand"),
    MendPet          = define("MendPet",          { 27046, 13544, 13543, 13542, 3662, 3661, 3111, 136 }, "MendPet"),
    MultiShot        = define("MultiShot",        { 27021, 25294, 14290, 14289, 14288, 2643 }, "MultiShot"),
    RapidFire        = define("RapidFire",        { 3045 }, "RapidFire"),
    RaptorStrike     = define("RaptorStrike",     { 27014, 14266, 14265, 14264, 14263, 14262, 14261, 14260, 2973 }, "RaptorStrike"),
    Readiness        = define("Readiness",        { 23989 }, "Readiness"),
    RevivePet        = define("RevivePet",        { 982 }, "RevivePet"),
    SerpentSting     = define("SerpentSting",     { 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }, "SerpentSting"),
    SilencingShot    = define("SilencingShot",    { 34490 }, "SilencingShot"),
    SteadyShot       = define("SteadyShot",       { 34120 }, "SteadyShot"),
    TrueshotAura     = define("TrueshotAura",     { 19506, 20905, 20906 }, "TrueshotAura"),
    ViperSting       = define("ViperSting",       { 27018, 14280, 14279, 3034 }, "ViperSting"),
    WingClip         = define("WingClip",         { 14268, 14267, 2974 }, "WingClip"),
}
local pet_manager = require("shared/pet_manager_sylvanas")
local shot_timer = require("shared/shot_timer_sylvanas")
local SpellQueue = require("shared/spell_queue_helper_sylvanas")
local potion_helper = require("shared/potion_helper_sylvanas")
local _inv_ok, inventory_helper = pcall(require, "common/utility/inventory_helper")

local MULTI_SHOT_CAST_MS = 500
local AIMED_SHOT_CAST_MS = 2500

local function can_cast_steady()
    local tracker = NS.HunterClipTracker
    if tracker and type(tracker.can_cast_steady) == "function" then
        return tracker.can_cast_steady() ~= false
    end
    return true
end

local function can_cast_before_auto(cast_ms)
    local tracker = NS.HunterClipTracker
    if tracker and type(tracker.ms_until_auto) == "function" then
        local remain = tracker.ms_until_auto()
        local buf = (shot_timer.get_auto_shot_buffer_ms and shot_timer.get_auto_shot_buffer_ms()) or 150
        return remain == 0 or remain > cast_ms + buf
    end
    return true
end

local function record_manual_shot()
    local tracker = NS.HunterClipTracker
    if tracker and type(tracker.record_manual_shot) == "function" then
        tracker.record_manual_shot()
    end
end

-- ============================================================================
-- Buff & Debuff ID tables
-- ============================================================================
local HUNTERS_MARK_DEBUFF = { 14325, 14324, 14323, 1130 }
local SERPENT_STING_DEBUFF = { 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }
local ASPECT_HAWK_BUFF = { 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 }
local ASPECT_VIPER_BUFF = { 34074 }

local MISDIRECTION_ID = 34477
local WING_CLIP_DEBUFF = { 2974 }
local RAPTOR_STRIKE_IDS = { 27014, 14266, 14265, 14264, 14263, 14262, 14261, 14260, 2973 }
local CONCUSSIVE_SHOT_IDS = { 5116 }
local VOLLEY_IDS = { 27022, 14295, 14294, 1510 }

local SERPENT_STING_REFRESH_SEC = 1.5

local HEALTHSTONE_IDS = { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }
local function first_ready_item(ids)
    if type(inventory_helper) ~= "table" then return nil end
    if type(inventory_helper.has_item) ~= "function" then return nil end
    for _, id in ipairs(ids) do
        local ok, has = pcall(inventory_helper.has_item, id)
        if ok and has then return id end
    end
    return nil
end

-- Safe API wrappers (mirror beast_mastery/leveling): a single API failure must
-- never blank build_state (dispatcher falls back to raw context on throw).
--
-- TEMP DIAGNOSTIC (2026-08-06): live BM regression; swallowed errors are
-- re-emitted (throttled 2s) so the crashing call is visible in the console.
-- REMOVE once the live root cause is identified.
local _last_swallowed_warn = 0
local function warn_swallowed(label, err)
    local now = (NS.time_now and NS.time_now()) or 0
    if now - _last_swallowed_warn <= 2 then return end
    _last_swallowed_warn = now
    if NS.log then NS.log("MM swallowed API error [" .. label .. "]: " .. tostring(err)) end
end

-- Spell readiness comes from REAL API returns (IZI castability + core
-- cooldown) — no hardcoded stand-in values. The native spell_helper path in
-- NS.spell_ready is deliberately NOT used for readiness; castability is asked
-- of the IZI spell object instead.
local function izi_spell_for(spell)
    if not NS.izi or type(NS.izi.spell) ~= "function" then return nil end
    local ids
    if type(spell) == "number" then ids = spell
    elseif type(spell) == "table" then
        if spell._meta and spell._meta.ids then ids = spell._meta.ids
        elseif spell.ids then ids = spell.ids
        else ids = spell end
    end
    if ids == nil then return nil end
    local ok, s = pcall(NS.izi.spell, ids)
    if not ok then warn_swallowed("izi.spell", s); return nil end
    return s
end

local function spell_ready(spell, target, opts)
    if not spell then return false end
    opts = opts or {}
    -- 1) Cooldown: real cooldown API return (spell_helper charges → core
    --    spell_book information → cast-history); >0 means not ready.
    if NS.cooldown_remains then
        local cd = NS.cooldown_remains(spell, opts.expected_cooldown)
        if cd > 0 then return false end
    end
    -- 2) Castability: IZI spell object (range/facing/usable/charges).
    --    GCD skipped here — NS.try_cast/izi cast_safe enforces the global at
    --    cast time; skip_moving is on because hunter instants cast while moving.
    local izi_spell = izi_spell_for(spell)
    if izi_spell and type(izi_spell.is_castable_to_unit) == "function" and target then
        local ok, res = pcall(izi_spell.is_castable_to_unit, izi_spell, target, {
            skip_gcd = true,
            skip_moving = true,
            skip_facing = opts.skip_facing == true,
            skip_range = opts.skip_range == true,
        })
        if not ok then warn_swallowed("izi is_castable_to_unit", res); return false end
        return res == true
    end
    -- 3) Non-IZI runtime (unit-test harness): NS.spell_ready's real return.
    if NS.spell_ready then return NS.spell_ready(spell, target, opts) == true end
    return false
end

local function safe_buff_up(unit, ids)
    if not unit or not NS.buff_up then return false end
    local ok, a = pcall(NS.buff_up, unit, ids)
    return ok and a or false
end

local function safe_debuff_up(unit, ids)
    if not unit or not NS.debuff_up then return false end
    local ok, a = pcall(NS.debuff_up, unit, ids)
    return ok and a or false
end

local function safe_cooldown_remains(spell)
    if not NS.cooldown_remains then return 0 end
    local ok, a = pcall(NS.cooldown_remains, spell)
    if ok and type(a) == "number" then return a end
    return 0
end

-- ============================================================================
-- State schema (nil-guard defaults for spec_kit.safe_state)
-- ============================================================================
local MM_SCHEMA = {
    has_pet = false,  pet_alive = false,  pet_dead = false,
    pre_steady_leveling = false,  pet_hp_pct = 100,
    has_hunters_mark = false,  has_serpent_sting = false,  serpent_sting_remains = 0,
    has_aspect_hawk = false,  has_aspect_viper = false,
    mend_pet_ready = false,  hunters_mark_ready = false,
    rapid_fire_ready = false,  rapid_fire_cd = 0,
    aimed_shot_prepull_ready = false,  aimed_shot_ready = false,
    silencing_shot_ready = false,  target_is_casting = false,  target_interruptible = false,
    kill_command_ready = false,  multi_shot_ready = false,
    steady_shot_ready = false,  arcane_shot_ready = false,  serpent_sting_ready = false,
    call_pet_ready = false,  revive_pet_ready = false,
    feign_death_ready = false,  freezing_trap_ready = false,
    viper_sting_ready = false,  readiness_ready = false,
    trueshot_aura_ready = false,  trueshot_aura_active = false,
    raptor_strike_ready = false,  concussive_shot_ready = false,  volley_ready = false,
    explosive_trap_ready = false,  wing_clip_active = false,  wing_clip_ready = false,
    bestial_wrath_ready = false,  has_deterrence = false,
    mana_pct = 100,  in_combat = false,  enemy_count = 1,  is_ooc = false,
    hunter_melee_weave = true,  hunter_shot_timer_buffer = 150,
    healthstone_ready = 0,  distance_sq = 10000,  is_group = false,
}

-- ============================================================================
-- State builder
-- ============================================================================
local mm_state = {
    has_pet = false,
    pet_alive = false,
    pet_dead = false,
    pre_steady_leveling = false,
    pet_hp_pct = 100,
    has_hunters_mark = false,
    has_serpent_sting = false,
    serpent_sting_remains = 0,
    has_aspect_hawk = false,
    has_aspect_viper = false,
    mend_pet_ready = false,
    hunters_mark_ready = false,
    rapid_fire_ready = false,
    rapid_fire_cd = 0,
    aimed_shot_prepull_ready = false,
    aimed_shot_ready = false,
    silencing_shot_ready = false,
    target_is_casting = false,
    target_interruptible = false,
    kill_command_ready = false,
    multi_shot_ready = false,
    steady_shot_ready = false,
    arcane_shot_ready = false,
    serpent_sting_ready = false,
    call_pet_ready = false,
    revive_pet_ready = false,
    feign_death_ready = false,
    freezing_trap_ready = false,
    viper_sting_ready = false,
    readiness_ready = false,
    trueshot_aura_ready = false,
    trueshot_aura_active = false,
    raptor_strike_ready = false,
    concussive_shot_ready = false,
    volley_ready = false,
    explosive_trap_ready = false,
    wing_clip_active = false,
    use_misdirection = false,
    mana_pct = 100,
    in_combat = false,
    enemy_count = 1,
    is_ooc = false,
    hunter_melee_weave = true,
    hunter_shot_timer_buffer = 150,
    healthstone_ready = 0,
    distance_sq = 10000,
}

local function build_state(context)
    local me = context.me or NS.GetPlayer()
    local target = context.target
    local pet = context.pet or (NS.GetPet and NS.GetPet()) or nil
    local pet_alive = pet and ((NS.unit_alive and NS.unit_alive(pet)) or (pet.is_alive and pet:is_alive()) or false) or false

    mm_state.has_pet = pet ~= nil
    mm_state.pet_alive = pet_alive == true
    mm_state.pet_dead = context.pet_dead == true or (pet ~= nil and not mm_state.pet_alive)
    mm_state.pet_hp_pct = mm_state.pet_alive and pet.get_health_percentage and pet:get_health_percentage() or 100
    mm_state.has_hunters_mark = target and safe_debuff_up(target, HUNTERS_MARK_DEBUFF) or false
    mm_state.has_serpent_sting = target and safe_debuff_up(target, SERPENT_STING_DEBUFF) or false
    mm_state.serpent_sting_remains = target and (function()
        if not NS.debuff_remains then return 0 end
        local ok, rem = pcall(NS.debuff_remains, target, SERPENT_STING_DEBUFF)
        if ok and type(rem) == "number" then return rem end
        return 0
    end)() or 0
    mm_state.has_aspect_hawk = me and safe_buff_up(me, ASPECT_HAWK_BUFF) or false
    mm_state.has_aspect_viper = me and safe_buff_up(me, ASPECT_VIPER_BUFF) or false
    mm_state.mend_pet_ready = me and spell_ready(ACTION.MendPet, me, { skip_range = true }) or false
    mm_state.hunters_mark_ready = target and spell_ready(ACTION.HuntersMark, target) or false
    mm_state.rapid_fire_ready = me and spell_ready(ACTION.RapidFire, me, { skip_range = true, expected_cooldown = 300 }) or false
    mm_state.rapid_fire_cd = safe_cooldown_remains(ACTION.RapidFire) or 0
    mm_state.aimed_shot_prepull_ready = target and spell_ready(ACTION.AimedShot, target, { expected_cooldown = 6 }) or false
    mm_state.aimed_shot_ready = target and spell_ready(ACTION.AimedShot, target, { expected_cooldown = 6 }) or false
    mm_state.silencing_shot_ready = target and spell_ready(ACTION.SilencingShot, target, { expected_cooldown = 20 }) or false
    mm_state.target_is_casting = target and ((target.is_casting and target:is_casting()) or false)
    mm_state.target_interruptible = mm_state.target_is_casting and (function()
        if not NS.is_interruptible then return false end
        local ok, inter = pcall(NS.is_interruptible, target)
        return ok and inter or false
    end)() or false
    mm_state.kill_command_ready = target and spell_ready(ACTION.KillCommand, target, { expected_cooldown = 5 }) or false
    mm_state.multi_shot_ready = target and spell_ready(ACTION.MultiShot, target, { expected_cooldown = 10 }) or false
    mm_state.steady_shot_ready = target and spell_ready(ACTION.SteadyShot, target) or false
    mm_state.arcane_shot_ready = target and spell_ready(ACTION.ArcaneShot, target, { expected_cooldown = 6 }) or false
    mm_state.serpent_sting_ready = target and spell_ready(ACTION.SerpentSting, target) or false
    mm_state.call_pet_ready = me and spell_ready(ACTION.CallPet, me, { skip_range = true }) or false
    mm_state.revive_pet_ready = me and spell_ready(ACTION.RevivePet, me, { skip_range = true }) or false
    mm_state.feign_death_ready = me and spell_ready(ACTION.FeignDeath, me, { skip_range = true, expected_cooldown = 30 }) or false
    mm_state.freezing_trap_ready = me and spell_ready(ACTION.FreezingTrap, me, { skip_range = true, expected_cooldown = 30 }) or false
    mm_state.viper_sting_ready = target and spell_ready(ACTION.ViperSting, target, { expected_cooldown = 8 }) or false
    mm_state.readiness_ready = me and spell_ready(ACTION.Readiness, me, { skip_range = true, expected_cooldown = 300 }) or false
    mm_state.trueshot_aura_ready = me and spell_ready(ACTION.TrueshotAura, me, { skip_range = true, expected_cooldown = 120 }) or false
    mm_state.trueshot_aura_active = me and safe_buff_up(me, { 19506, 20905, 20906 }) or false
    mm_state.raptor_strike_ready = target and spell_ready(RAPTOR_STRIKE_IDS, target) or false
    mm_state.concussive_shot_ready = target and spell_ready(CONCUSSIVE_SHOT_IDS, target) or false
    mm_state.volley_ready = target and spell_ready(VOLLEY_IDS, target) or false
    mm_state.explosive_trap_ready = me and spell_ready(ACTION.ExplosiveTrap, me, { skip_range = true, expected_cooldown = 30 }) or false
    mm_state.wing_clip_active = target and safe_debuff_up(target, WING_CLIP_DEBUFF) or false
    mm_state.wing_clip_ready = target and spell_ready(ACTION.WingClip, target) or false
    mm_state.use_misdirection = spec_kit.setting_bool(context, "use_misdirection", false)
    mm_state.is_group = context.is_group or false
    mm_state.mana_pct = context.mana_pct or (me and NS.mana_pct and NS.mana_pct(me))
    mm_state.in_combat = context.in_combat or false
    mm_state.enemy_count = context.enemy_count or context.enemies_count
    mm_state.is_ooc = not mm_state.in_combat
    mm_state.pre_steady_leveling = ((context.player_level or 70) < 62) or (context.is_leveling == true and not mm_state.steady_shot_ready)
    mm_state.hunter_melee_weave = spec_kit.setting_bool(context, "hunter_melee_weave", true)
    mm_state.hunter_shot_timer_buffer = spec_kit.setting_number(context, "hunter_shot_timer_buffer", 150)
    mm_state.distance_sq = context.distance_sq or (context.target_range and context.target_range * context.target_range) or (context.distance and context.distance * context.distance)
    mm_state.healthstone_ready = first_ready_item(HEALTHSTONE_IDS) or 0

    return spec_kit.safe_state(mm_state, MM_SCHEMA)
end

local function cooldowns_enabled(context)
    return spec_kit.setting_bool(context, "use_cooldowns", true)
end

-- ============================================================================
-- Match functions
-- ============================================================================
local function mend_pet_matches(context, s)
    if not s.pet_alive then return false end
    if (s.pet_hp_pct or 100) > 45 then return false end
    if not s.mend_pet_ready then return false end
    return true
end

local function hunters_mark_matches(context, s)
    if s.has_hunters_mark then return false end
    if not s.hunters_mark_ready then return false end
    return true
end

local function rapid_fire_matches(context, s)
    if not cooldowns_enabled(context) then return false end
    if not s.in_combat then return false end
    if not s.rapid_fire_ready then return false end
    -- TTD gate: don't waste 3min CD on a dying target
    if context.ttd_known and (context.ttd or 0) < 15 then return false end
    return true
end

local function aimed_shot_prepull_matches(context, s)
    if not s.is_ooc then return false end
    if not s.aimed_shot_prepull_ready then return false end
    if not can_cast_before_auto(AIMED_SHOT_CAST_MS) then return false end
    return true
end

local function kill_command_matches(context, s)
    if not s.in_combat then return false end
    if not s.pet_alive then return false end
    if not s.kill_command_ready then return false end
    return true
end

local function multi_shot_matches(context, s)
    if not s.multi_shot_ready then return false end
    if context.has_breakable_cc_nearby then return false end
    if (s.mana_pct or 100) < 15 then return false end
    if not can_cast_before_auto(MULTI_SHOT_CAST_MS) then return false end
    return true
end

local function steady_shot_matches(context, s)
    if not s.steady_shot_ready then return false end
    if shot_timer.should_delay_cast and shot_timer.should_delay_cast(context, s.hunter_shot_timer_buffer or 150) then return false end
    if not can_cast_steady() then return false end
    return true
end

local function arcane_shot_matches(context, s)
    if not s.arcane_shot_ready then return false end
    if (s.mana_pct or 100) < 20 then return false end
    return true
end

local function serpent_sting_matches(context, s)
    if s.has_serpent_sting and (s.serpent_sting_remains or 0) > SERPENT_STING_REFRESH_SEC then return false end
    if not s.serpent_sting_ready then return false end
    return true
end

local function aspect_hawk_matches(context, s)
    if s.has_aspect_hawk then return false end
    -- Wowsims-aligned: exit Viper at 25% (enter at 5% via aspect_viper_matches)
    if s.has_aspect_viper then
        local viper_end = spec_kit.setting_number(context, "mana_viper_end", 25)
        if (s.mana_pct or 100) <= viper_end then return false end
    end
    return true
end

local function aspect_viper_matches(context, s)
    if s.has_aspect_viper then return false end
    -- Wowsims-aligned: enter Viper at 5%
    if (s.mana_pct or 100) > 5 then return false end
    return true
end

local function call_pet_matches(context, s)
    if s.has_pet then return false end
    if s.in_combat then return false end
    if not s.call_pet_ready then return false end
    return true
end

local function revive_pet_matches(context, s)
    if s.has_pet and not s.pet_dead then return false end
    if s.in_combat then return false end
    if s.call_pet_ready and not s.pet_dead then return false end
    if not s.revive_pet_ready then return false end
    return true
end

local function feign_death_matches(context, s)
    if not s.in_combat then return false end
    if not s.feign_death_ready then return false end
    return true
end

local function freezing_trap_matches(context, s)
    if s.in_combat then return false end
    if not s.freezing_trap_ready then return false end
    return true
end

local function in_combat_aimed_shot_matches(context, s)
    -- Wowsims-aligned: Aimed Shot opener at <= 0.5s into combat when Serpent Sting not active.
    -- At combat start the auto-shot timer hasn't fired yet, so Aimed Shot doesn't clip.
    local combat_time = context.combat_time or 0
    if combat_time > 0.5 then return false end
    if not s.aimed_shot_ready then return false end
    if s.has_serpent_sting then return false end
    if not can_cast_before_auto(AIMED_SHOT_CAST_MS) then return false end
    return true
end

local function viper_sting_matches(context, s)
    if not s.viper_sting_ready then return false end
    return true
end

local function bestial_wrath_matches(context, s)
    return false
end

local function readiness_matches(context, s)
    if not cooldowns_enabled(context) then return false end
    if not spec_kit.setting_bool(context, "use_readiness", true) then return false end
    if not s.in_combat then return false end
    if not s.readiness_ready then return false end
    -- TTD gate: don't waste 5min CD on a dying target
    if context.ttd_known and (context.ttd or 0) < 20 then return false end
    -- Use after Rapid Fire has been used (on CD) to reset it for a 2nd burst window
    -- MM does not have Bestial Wrath; only gate on Rapid Fire CD remaining
    if (s.rapid_fire_cd or 0) < 60 then return false end
    return true
end

local function trueshot_aura_matches(context, s)
    if not cooldowns_enabled(context) then return false end
    if not s.in_combat then return false end
    if s.trueshot_aura_active then return false end
    if not s.trueshot_aura_ready then return false end
    -- TTD gate: don't waste 2min CD on a dying target
    if context.ttd_known and (context.ttd or 0) < 10 then return false end
    return true
end

local function leveling_arcane_shot_matches(context, s)
    if not s.pre_steady_leveling then return false end
    if not s.arcane_shot_ready then return false end
    return true
end

local function leveling_sting_matches(context, s)
    if not s.pre_steady_leveling then return false end
    if s.has_serpent_sting then return false end
    if (s.mana_pct or 100) < 25 then return false end
    if not s.serpent_sting_ready then return false end
    return true
end

-- Raptor Strike: melee weaving when target in melee range (5yd)
local function raptor_strike_matches(context, s)
    if not s.in_combat then return false end
    if not s.hunter_melee_weave then return false end
    if not context.target then return false end
    local dsq = s.distance_sq or 10000
    if dsq > 25 then return false end
    if not s.raptor_strike_ready then return false end
    return true
end

-- Wing Clip: melee slow when target is moving away
local function wing_clip_matches(context, s)
    if not s.in_combat then return false end
    if not s.hunter_melee_weave then return false end
    if s.wing_clip_active then return false end
    if not context.target then return false end
    local dsq = s.distance_sq or 10000
    if dsq > 25 then return false end
    if not s.wing_clip_ready then return false end
    return true
end

-- ============================================================================
-- Strategies
-- ============================================================================
local strategies = {
    { name = "HealthPotion",
      matches = function(context)
          if not context.in_combat then return false end
          if not spec_kit.setting_bool(context, "use_auto_potions", true) then return false end
          if not context.has_health_potion then return false end
          if (context.hp or 100) > 35 then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.HEALTH_POTION_IDS) end },
    { name = "ManaPotion",
      matches = function(context)
          if not context.in_combat then return false end
          if not spec_kit.setting_bool(context, "use_auto_potions", true) then return false end
          if not context.has_mana_potion then return false end
          if (context.mana_pct or 100) > 25 then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.MANA_POTION_IDS) end },
    -- Auto Healthstone
    { name = "Healthstone",
      matches = function(ctx, state)
          if not ctx.in_combat then return false end
          if (state.hp_pct or 100) > 28 then return false end
          if (state.healthstone_ready or 0) <= 0 then return false end
          return true
      end,
      execute = function(ctx)
          local id = first_ready_item(HEALTHSTONE_IDS)
          if id then NS.use_item_by_id(id, ctx.me) end
      end },
    { name = "MendPet" },
    -- Deterrence -- emergency dodge/parry when critically low
    { name = "Deterrence",
      matches = function(context, state)
          if not context.in_combat then return false end
          if (state.hp_pct or 100) > 25 then return false end
          if state.has_deterrence then return false end
          return spell_ready(19263, context.me, { skip_range = true })
      end,
      execute = function(context) return NS.try_cast(19263, context.me, "[MARKSMANSHIP] Deterrence", { skip_range = true, expected_cooldown = 300 }) end },
    { name = "CallPet", matches = call_pet_matches, execute = function(context) return NS.try_cast(ACTION.CallPet, context.me, "[MARKSMANSHIP] Call Pet", { skip_range = true }) end },
    { name = "RevivePet", matches = revive_pet_matches, execute = function(context) return NS.try_cast(ACTION.RevivePet, context.me, "[MARKSMANSHIP] Revive Pet", { skip_range = true }) end },
    -- Pet State: set defensive when pet HP is critically low
    { name = "PetDefensive",
      matches = function(context, state)
          local pet = context.pet or (NS.GetPet and NS.GetPet()) or nil
          if not pet then return false end
          if not context.in_combat then return false end
          local hp = pet.get_health_percentage and pet:get_health_percentage() or 100
          if hp > 40 then return false end
          return true
      end,
      execute = function() return pet_manager.set_defensive() end },
    -- Pet State: set passive when player HP critically low (survival mode)
    { name = "PetPassive",
      matches = function(context, state)
          local pet = context.pet or (NS.GetPet and NS.GetPet()) or nil
          if not pet then return false end
          if not context.in_combat then return false end
          if (context.hp or 100) > 25 then return false end
          return true
      end,
      execute = function() return pet_manager.set_passive() end },
    -- Pet State: set aggressive during combat when pet is healthy
    { name = "PetAggressive",
      matches = function(context, state)
          local pet = context.pet or (NS.GetPet and NS.GetPet()) or nil
          if not pet then return false end
          if not context.in_combat then return false end
          local hp = pet.get_health_percentage and pet:get_health_percentage() or 100
          if hp < 50 then return false end
          return true
      end,
      execute = function() return pet_manager.set_aggressive() end },
    { name = "AspectOfTheHawk", matches = aspect_hawk_matches, execute = function(context) return NS.try_cast(ACTION.AspectOfTheHawk, context.me, "[MARKSMANSHIP] Aspect of the Hawk", { skip_range = true }) end },
    { name = "AspectOfTheViper", matches = aspect_viper_matches, execute = function(context) return NS.try_cast(ACTION.AspectOfTheViper, context.me, "[MARKSMANSHIP] Aspect of the Viper", { skip_range = true }) end },
    { name = "FreezingTrap" },
    { name = "HuntersMark" },
    { name = "RapidFire" },
    { name = "TrueshotAura", matches = trueshot_aura_matches, execute = function(context) return NS.try_cast(ACTION.TrueshotAura, context.me, "[MARKSMANSHIP] Trueshot Aura", { skip_range = true, expected_cooldown = 120 }) end },
    { name = "BestialWrath", matches = bestial_wrath_matches, execute = function(context) local pet = context.pet or (NS.GetPet and NS.GetPet()) or context.me; return NS.try_cast(ACTION.BestialWrath, pet, "[MARKSMANSHIP] Bestial Wrath", { skip_range = true, expected_cooldown = 120 }) end },
    { name = "Readiness", matches = readiness_matches, execute = function(context) return NS.try_cast(ACTION.Readiness, context.me, "[MARKSMANSHIP] Readiness", { skip_range = true, expected_cooldown = 300 }) end },
    { name = "InCombatAimedShot", matches = in_combat_aimed_shot_matches, execute = function(context) if NS.try_cast(ACTION.AimedShot, context.target, "[MARKSMANSHIP] Aimed Shot", { expected_cooldown = 6 }) then record_manual_shot() return true end return false end },
    { name = "AimedShotPrepull", matches = aimed_shot_prepull_matches, execute = function(context) if NS.try_cast(ACTION.AimedShot, context.target, "[MARKSMANSHIP] Aimed Shot (prepull)", { expected_cooldown = 6 }) then record_manual_shot() return true end return false end },
    { name = "KillCommand" },
    { name = "FeignDeath" },
    { name = "LevelingArcaneShot", matches = leveling_arcane_shot_matches, execute = function(context) if NS.try_cast(ACTION.ArcaneShot, context.target, "[MARKSMANSHIP] Arcane Shot (leveling)", { expected_cooldown = 6 }) then record_manual_shot() return true end return false end },
    { name = "LevelingSting", matches = leveling_sting_matches, execute = function(context) return NS.try_cast(ACTION.SerpentSting, context.target, "[MARKSMANSHIP] Serpent Sting (leveling)") end },
    { name = "AdaptiveRotation", matches = function(c) return NS.HunterAdaptive and (spec_kit.setting_bool(c, "use_adaptive_rotation", false)) and c.in_combat and c.target end, execute = function(c) return (NS.create_adaptive_rotation_strategy and NS.create_adaptive_rotation_strategy()(c)) or false end },
    { name = "MultiShot", matches = multi_shot_matches, execute = function(context) if NS.try_cast(ACTION.MultiShot, context.target, "[MARKSMANSHIP] Multi-Shot", { expected_cooldown = 10 }) then record_manual_shot() return true end return false end },
    { name = "ArcaneShot", matches = arcane_shot_matches, execute = function(context) if NS.try_cast(ACTION.ArcaneShot, context.target, "[MARKSMANSHIP] Arcane Shot", { expected_cooldown = 6 }) then record_manual_shot() return true end return false end },
    { name = "SteadyShot", matches = steady_shot_matches, execute = function(context)
        if spec_kit.setting_bool(context, "use_spell_queue_shots", false) then
            if SpellQueue.queue_spell_target(ACTION.SteadyShot, context.target, 1, "[MARKSMANSHIP] Steady Shot", true) then
                record_manual_shot()
                return true
            end
            return false
        end
        if NS.try_cast(ACTION.SteadyShot, context.target, "[MARKSMANSHIP] Steady Shot") then record_manual_shot() return true end return false
    end },
    { name = "ViperSting", matches = viper_sting_matches, execute = function(context) return NS.try_cast(ACTION.ViperSting, context.target, "[MARKSMANSHIP] Viper Sting", { expected_cooldown = 8 }) end },
    { name = "SerpentSting", matches = serpent_sting_matches, execute = function(context) return NS.try_cast(ACTION.SerpentSting, context.target, "[MARKSMANSHIP] Serpent Sting") end },
    { name = "RaptorStrike", matches = raptor_strike_matches, execute = function(context) return NS.try_cast(ACTION.RaptorStrike, context.target, "[MARKSMANSHIP] Raptor Strike") end },
    { name = "WingClip", matches = wing_clip_matches, execute = function(context) return NS.try_cast(ACTION.WingClip, context.target, "[MARKSMANSHIP] Wing Clip") end },
}

-- ============================================================================
-- Strategy DSL definitions (20th DSL adopter — marksmanship hunter).
-- Converts 6 strategies to declarative DSL, preserving priority order via
-- in-place substitution.
-- ============================================================================
local DSL_DEFS = {
    {
        name = "MendPet",
        conditions = {
            { type = "state", field = "pet_alive", value = true },
            { type = "state", field = "pet_hp_pct", op = "<=", value = 45 },
            { type = "state", field = "mend_pet_ready", value = true },
        },
        execute = function(context)
            return NS.try_cast(ACTION.MendPet, context.pet or (NS.GetPet and NS.GetPet()) or context.me, "[MARKSMANSHIP] Mend Pet", { skip_range = true })
        end,
    },
    {
        name = "HuntersMark",
        conditions = {
            { type = "state", field = "has_hunters_mark", value = false },
            { type = "state", field = "hunters_mark_ready", value = true },
        },
        action = { type = "cast", spell = ACTION.HuntersMark, target = "target", label = "[MARKSMANSHIP] Hunter's Mark" },
    },
    {
        name = "RapidFire",
        conditions = {
            { type = "setting", key = "use_cooldowns", op = "truthy", default = true },
            { type = "state", field = "in_combat", value = true },
            { type = "state", field = "rapid_fire_ready", value = true },
            { type = "custom", fn = function(context, state)
                if context.ttd_known and (context.ttd or 0) < 15 then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.RapidFire, target = "self", opts = { skip_range = true, expected_cooldown = 300 }, label = "[MARKSMANSHIP] Rapid Fire" },
    },
    {
        name = "KillCommand",
        conditions = {
            { type = "state", field = "in_combat", value = true },
            { type = "state", field = "pet_alive", value = true },
            { type = "state", field = "kill_command_ready", value = true },
        },
        action = { type = "cast", spell = ACTION.KillCommand, target = "target", opts = { expected_cooldown = 5, skip_gcd = true }, label = "[MARKSMANSHIP] Kill Command" },
    },
    {
        name = "FeignDeath",
        conditions = {
            { type = "state", field = "in_combat", value = true },
            { type = "state", field = "feign_death_ready", value = true },
        },
        action = { type = "cast", spell = ACTION.FeignDeath, target = "self", opts = { skip_range = true, expected_cooldown = 30 }, label = "[MARKSMANSHIP] Feign Death" },
    },
    {
        name = "FreezingTrap",
        conditions = {
            { type = "state", field = "in_combat", value = false },
            { type = "state", field = "freezing_trap_ready", value = true },
        },
        action = { type = "cast", spell = ACTION.FreezingTrap, target = "self", opts = { skip_range = true, expected_cooldown = 30 }, label = "[MARKSMANSHIP] Freezing Trap" },
    },
}

-- Substitute DSL-compiled strategies into the list via name matching.
local dsl_map = {}
for _, def in ipairs(DSL_DEFS) do
    dsl_map[def.name] = def
end
for i, strat in ipairs(strategies) do
    if dsl_map[strat.name] then
        strategies[i] = dsl.compile_strategy(dsl_map[strat.name], { get_state = build_state })
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("marksmanship", strategies, { get_state = build_state })
end
if NS.log then NS.log("Hunter marksmanship rotation registered") end
return { strategies = strategies, build_state = build_state }
