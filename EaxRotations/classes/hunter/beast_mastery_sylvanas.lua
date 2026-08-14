-- beast_mastery_sylvanas.lua — Hunter Beast Mastery rotation for TBC Anniversary (2.5.5).
-- WHAT:  pet-focused DPS spec — Kill Command (off-GCD) → Bestial Wrath → Multi-Shot
--         (AoE) → Serpent Sting → Arcane Shot → Steady Shot filler, with Mend Pet,
--         Hawk/Viper auto-aspect swapping, melee weaving, and CD alignment (Rapid Fire,
--         Readiness, Intimidation, Trinkets).
-- WHEN:  combat, with valid enemy target and active pet.
-- WHY:   mirrors wowsims/tbc BM APL (sim/hunter/beast_mastery/rotation.go) + Icy Veins
--         BM priority: KC > BW > Multi-Shot > Serpent > Arcane > Steady.
-- SAFETY: Pattern 14 nil-guards via spec_kit.safe_state; no on_update() allocs; mounted
--          bail gate on every match function; auto-aspect hysteresis (Viper ≤5%, Hawk ≥25%).
local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end
local SPELLS = NS.HunterSpells or {}

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
local leveling_helpers = require("shared/leveling_helpers_sylvanas")
local define = spec_kit.define_action_for_class(SPELLS)
local ACTION = {
    ArcaneShot       = define("ArcaneShot",       {27019, 14287, 14286, 14285, 14284, 14283, 14282, 14281, 3044}, "ArcaneShot"),
    AspectOfTheHawk  = define("AspectOfTheHawk",  {27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165}, "AspectOfTheHawk"),
    AspectOfTheViper = define("AspectOfTheViper", {34074}, "AspectOfTheViper"),
    BestialWrath     = define("BestialWrath",     {19574}, "BestialWrath"),
    CallPet          = define("CallPet",          {883}, "CallPet"),
    ExplosiveTrap    = define("ExplosiveTrap",    {27025, 14317, 14316, 13813}, "ExplosiveTrap"),
    FeignDeath       = define("FeignDeath",       {5384}, "FeignDeath"),
    FreezingTrap     = define("FreezingTrap",     {14311, 14310, 1499}, "FreezingTrap"),
    HuntersMark      = define("HuntersMark",      {14325, 14324, 14323, 1130}, "HuntersMark"),
    Intimidation     = define("Intimidation",     {19577}, "Intimidation"),
    KillCommand      = define("KillCommand",      {34026}, "KillCommand"),
    MendPet          = define("MendPet",          {27046, 13544, 13543, 13542, 3662, 3661, 3111, 136}, "MendPet"),
    MultiShot        = define("MultiShot",        {27021, 25294, 14290, 14289, 14288, 2643}, "MultiShot"),
    RapidFire        = define("RapidFire",        {3045}, "RapidFire"),
    Readiness        = define("Readiness",        {23989}, "Readiness"),
    RevivePet        = define("RevivePet",        {982}, "RevivePet"),
    ScorpidSting     = define("ScorpidSting",     {3043}, "ScorpidSting"),
    SerpentSting     = define("SerpentSting",     {27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978}, "SerpentSting"),
    SteadyShot       = define("SteadyShot",       {34120}, "SteadyShot"),
    ViperSting       = define("ViperSting",       {27018, 14280, 14279, 3034}, "ViperSting"),
}
local hunter_core = require("shared/hunter_core_sylvanas")
local shot_timer = require("shared/shot_timer_sylvanas")
-- Load-for-side-effect: targeting_sylvanas installs NS.Targeting (consumed
-- nil-guarded by restoration_sylvanas:271 and multidot_engagement_filter:227).
-- The returned table is not used by this file — keep the require, drop the local.
require("shared/targeting_sylvanas")
local pet_manager = require("shared/pet_manager_sylvanas")
local potion_helper = require("shared/potion_helper_sylvanas")
local _planner_ok, planner = pcall(require, "shared/cooldown_planner_sylvanas")
if not _planner_ok or type(planner) ~= "table" then planner = nil end
local _inv_ok, inventory_helper = pcall(require, "common/utility/inventory_helper")

-- ============================================================================
-- Constants
-- ============================================================================
local ARCANE_SHOT_MANA_FLOOR = 50   -- BM mana floor: below 50% save mana for Kill Command & pet abilities
local ARCANE_SHOT_MANA_FLOOR_PRE_STEADY = 20  -- Pre-62: Steady Shot unavailable; Arcane is the filler
local MULTI_SHOT_MANA_FLOOR = 15    -- Suppress expensive AoE below 15%
local STEADY_SHOT_LEVEL = 62
local SERPENT_STING_IDS  = { 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }
local HUNTER_MARK_IDS    = { 14325, 14324, 14323, 1130 }
local ASPECT_HAWK_IDS    = { 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 }
local ASPECT_VIPER_IDS   = { 34074 }
local ASPECT_CHEETAH_IDS = { 5118 }
local MISDIRECTION_ID    = 34477
local RAPTOR_STRIKE_IDS  = { 27014, 14266, 14265, 14264, 14263, 14262, 14261, 14260, 2973 }
local CONCUSSIVE_SHOT_IDS = { 5116 }
local VOLLEY_IDS          = { 27022, 14295, 14294, 1510 }
local BLOODLUST_HEROISM_BUFFS = { 2825, 32182 }
-- Deterrence (rank 1, TBC) — the emergency-dodge buff checked by the
-- Deterrence strategy; was read-but-never-written (read-side audit 2026-08).
local DETERRENCE_BUFF = { 19263 }
local is_item_ready

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

-- Safe API wrappers (mirror leveling_sylvanas pattern): a single API failure
-- (e.g. native spell_helper path) must never blank the whole build_state.
--
-- DIAGNOSTIC (2026-08-06): the live client showed BM auto-attack only. These
-- wrappers swallow any routine API error with no visible trace, which made the
-- live failure invisible; warn_swallowed() re-emits the error text (throttled
-- 2s like safe()). One root cause was identified and fixed (2026-08-09): the
-- is_item_ready forward-declaration shadowing deaded the Trinket lane live.
-- Keep warn_swallowed as a throttled safety net for other potential live API
-- errors — it is harmless and costs nothing when no error occurs.
local _last_swallowed_warn = 0
local function warn_swallowed(label, err)
    local now = (NS.time_now and NS.time_now()) or 0
    if now - _last_swallowed_warn <= 2 then return end
    _last_swallowed_warn = now
    if NS.log then NS.log("BM swallowed API error [" .. label .. "]: " .. tostring(err)) end
end

local function safe_any(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if ok then return a end
    warn_swallowed(tostring(fn), a)
    return nil
end

-- Spell readiness comes from REAL API returns (IZI castability + core
-- cooldown) — no hardcoded stand-in values. IZI is the primary castability
-- read; when IZI reports not-castable, NS.spell_ready (the engine readiness
-- API every working spec runs on) is consulted before blocking, and the
-- final cooldown/range/usable gate runs in NS.try_cast at cast time.
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
        if not ok then
            warn_swallowed("izi is_castable_to_unit", res)
        elseif res == true then
            return true
        end
        -- IZI said not-castable (or threw): do not let a single API verdict
        -- blank the spell. Consult NS.spell_ready — the repo-standard
        -- readiness API every working spec runs on — before blocking. IZI has
        -- been observed false-gating enemy-target casts on the live client
        -- while NS.spell_ready says ready. The authoritative cooldown/range/
        -- usable gate still runs in NS.try_cast/evaluate_cast at cast time, so
        -- a genuinely OOR or on-CD spell is still rejected there.
        if NS.spell_ready then
            local ok2, ready2 = pcall(NS.spell_ready, spell, target, opts)
            if ok2 and ready2 == true then
                warn_swallowed("izi-not-castable but NS.spell_ready ready")
                return true
            end
            return false
        end
        return false
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

local function safe_is_spell_learned(spell)
    if not NS.is_spell_learned then return false end
    local ok, a = pcall(NS.is_spell_learned, spell)
    return ok and a or false
end

local function safe_cooldown_remains(spell, expected_cooldown)
    if not NS.cooldown_remains then return 0 end
    local ok, a = pcall(NS.cooldown_remains, spell, expected_cooldown)
    if ok and type(a) == "number" then return a end
    return 0
end

-- ============================================================================
-- Schema (Pattern 14 nil-guard defaults via spec_kit.safe_state)
-- ============================================================================
local BM_SCHEMA = {
    -- Pet state (Pattern 14: assume alive → skip summons)
    pet_alive = true,  has_pet = true,  pet_hp = 100,  has_pet_spell = true,
    -- Resources (Pattern 14: assume full/zero → skip defensives/spenders)
    mana_pct = 100,  hp_pct = 100,  enemy_count = 0,  threat_level = 0,
    in_combat = false,  is_mounted = false,  in_dead_zone = false,
    -- Aspect state
    has_hawk = false,  has_viper = false,  has_cheetah = false,
    -- Debuff state
    has_hunters_mark = false,  has_serpent_sting = false,  wing_clip_active = false,
    -- Spell readiness (no hardcoded stand-ins: unset means NOT ready)
    hunters_mark_ready = false,  serpent_sting_ready = false,
    arcane_shot_ready = false,  steady_shot_ready = false,  multi_shot_ready = false,
    kill_command_ready = false,  bestial_wrath_ready = false,  intimidation_ready = false,
    rapid_fire_ready = false,  rapid_fire_cd = 0,
    feign_death_ready = false,  mend_pet_ready = false,
    call_pet_ready = false,  revive_pet_ready = false,
    readiness_ready = false,  raptor_strike_ready = false,
    concussive_shot_ready = false,  volley_ready = false,  explosive_trap_ready = false,
    -- Trinkets
    trinket_1_id = nil,  trinket_2_id = nil,
    trinket_1_ready = false,  trinket_2_ready = false,
    -- Parity settings (safe defaults)
    multishot_mode = 2,  pull_mode = "combat_only",
    use_cooldowns = true,  use_misdirection = false,  misdirection_target = nil,
    trinket_mode = "off",  shot_buffer = 150,
    -- Melee & AoE
    use_melee = true,  hunter_melee_weave = true,  hunter_shot_timer_buffer = 150,
    aoe_threshold = 3,  use_volley = false,  use_explosive_trap = false,
    auto_aspect = true,  healthstone_ready = 0,
    viper_mana_threshold = 5,  viper_exit_threshold = 25,
    distance_sq = 10000,  is_group = false,
    -- Power windows
    bloodlust_active = false,  major_cd_active = false,  major_cd_window = false,
    has_deterrence = false,
    -- Leveling (Pattern: pre-Steady Shot silent-gate fix)
    level = 70,
    pre_steady_leveling = false,
}

-- ============================================================================
-- State builder
-- ============================================================================
local state = {
    pet_alive = false, pet_hp = 100, has_pet = false,
    mana_pct = 100, in_combat = false, enemy_count = 1,
    has_hawk = false, has_viper = false, has_cheetah = false,
    has_hunters_mark = false, has_serpent_sting = false,
    steady_shot_ready = false, arcane_shot_ready = false,
    multi_shot_ready = false, kill_command_ready = false,
    bestial_wrath_ready = false, rapid_fire_ready = false, rapid_fire_cd = 0,
    feign_death_ready = false, mend_pet_ready = false,
    call_pet_ready = false, revive_pet_ready = false,
    hunters_mark_ready = false, serpent_sting_ready = false,
    readiness_ready = false,
    -- parity features
    sting_mode = "serpent",
    fd_mode = "high_threat",
    multishot_mode = 2,
    use_cooldowns = true,
    use_misdirection = false,
    misdirection_target = nil,
    trinket_mode = "off",
    shot_buffer = 150,
    threat_level = 0,
    is_mounted = false,
    has_pet_spell = false,
    -- Melee & AoE features (parity parity)
    use_melee = true,
    hunter_melee_weave = true,
    hunter_shot_timer_buffer = 150,
    raptor_strike_ready = false,
    concussive_shot_ready = false,
    volley_ready = false,
    explosive_trap_ready = false,
    aoe_threshold = 3,
    use_volley = false,
    use_explosive_trap = false,
    trinket_1_id = nil,
    trinket_2_id = nil,
    trinket_1_ready = false,
    trinket_2_ready = false,
    auto_aspect = true,
    healthstone_ready = 0,
    level = 70,
    pre_steady_leveling = false,
}

local function build_state(context)
    local me = context.me or NS.GetPlayer()
    local target = context.target
    -- Core state
    state.is_group = context.is_group or false
    state.is_mounted = context.is_mounted or false
    state.in_combat = context.in_combat or false
    state.enemy_count = context.enemy_count or context.enemies_count
    state.mana_pct = context.mana_pct or (me and NS.mana_pct and NS.mana_pct(me))
    -- hp_pct was never assigned: Healthstone (hp<=28) and Deterrence (hp<=25)
    -- matched against the 100 default forever, so both lanes were dead in live.
    state.hp_pct = context.hp or (me and NS.health_pct and NS.health_pct(me)) or 100
    state.threat_level = context.threat_level or 0

    -- Pet state
    local pet = hunter_core.get_pet()
    state.has_pet = pet ~= nil
    state.pet_alive = hunter_core.pet_alive()
    state.pet_hp = hunter_core.pet_hp_pct()
    state.has_pet_spell = me and safe_is_spell_learned(ACTION.CallPet) or false

    -- Aspect state
    state.has_hawk = me and safe_buff_up(me, ASPECT_HAWK_IDS) or false
    state.has_viper = me and safe_buff_up(me, ASPECT_VIPER_IDS) or false
    state.has_cheetah = me and safe_buff_up(me, ASPECT_CHEETAH_IDS) or false

    -- Debuff state
    if target then
        state.has_hunters_mark = safe_debuff_up(target, HUNTER_MARK_IDS) or false
        state.has_serpent_sting = safe_debuff_up(target, SERPENT_STING_IDS) or false
    end

    -- Spell readiness
    state.hunters_mark_ready = target and spell_ready(ACTION.HuntersMark, target) or false
    state.serpent_sting_ready = target and spell_ready(ACTION.SerpentSting, target) or false
    state.arcane_shot_ready = target and spell_ready(ACTION.ArcaneShot, target) or false
    state.steady_shot_ready = target and spell_ready(ACTION.SteadyShot, target) or false
    state.multi_shot_ready = target and spell_ready(ACTION.MultiShot, target) or false
    state.kill_command_ready = target and spell_ready(ACTION.KillCommand, target) or false
    state.bestial_wrath_ready = me and spell_ready(ACTION.BestialWrath, me, { skip_range = true }) or false
    state.intimidation_ready = me and spell_ready(ACTION.Intimidation, me, { skip_range = true }) or false
    state.rapid_fire_ready = me and spell_ready(ACTION.RapidFire, me, { skip_range = true }) or false
    -- Rapid Fire CD (DBC-verified 300s / 5 min in TBC 2.5.5 — spell 3045
    -- RecoveryTime 300000). The expected_cooldown hint feeds the cast-history
    -- fallback in NS.cooldown_remains: without it a freshly-cast Rapid Fire
    -- reads as re-ready after ~2.5s and the Readiness lane (rapid_fire_cd >= 60)
    -- could never fire from cast history.
    state.rapid_fire_cd = safe_cooldown_remains(ACTION.RapidFire, 300) or 0
    state.feign_death_ready = me and spell_ready(ACTION.FeignDeath, me, { skip_range = true }) or false
    state.mend_pet_ready = me and spell_ready(ACTION.MendPet, me, { skip_range = true }) or false
    state.call_pet_ready = me and spell_ready(ACTION.CallPet, me, { skip_range = true }) or false
    state.revive_pet_ready = me and spell_ready(ACTION.RevivePet, me, { skip_range = true }) or false
    state.readiness_ready = me and spell_ready(ACTION.Readiness, me, { skip_range = true, expected_cooldown = 300 }) or false
    -- Raptor Strike ready (melee weaving)
    state.raptor_strike_ready = target and spell_ready(RAPTOR_STRIKE_IDS, target) or false
    -- Concussive Shot ready
    state.concussive_shot_ready = target and spell_ready(CONCUSSIVE_SHOT_IDS, target) or false
    -- Volley ready (AoE)
    state.volley_ready = target and spell_ready(VOLLEY_IDS, target) or false
    -- Explosive Trap ready (AoE)
    state.explosive_trap_ready = me and spell_ready(ACTION.ExplosiveTrap, me, { skip_range = true, expected_cooldown = 30 }) or false

    -- Trinket state
    if NS.TrinketManager and type(NS.TrinketManager.get_equipped_trinkets) == "function" then
        local trinkets = safe_any(NS.TrinketManager.get_equipped_trinkets)
        if trinkets then
            state.trinket_1_id = trinkets[1] and trinkets[1].item_id or nil
            state.trinket_2_id = trinkets[2] and trinkets[2].item_id or nil
        end
    end
    state.trinket_1_ready = state.trinket_1_id ~= nil and safe_any(is_item_ready, me, state.trinket_1_id) or false
    state.trinket_2_ready = state.trinket_2_id ~= nil and safe_any(is_item_ready, me, state.trinket_2_id) or false

    -- parity settings (via spec_kit)
    state.sting_mode = spec_kit.setting(context, "sting_mode", "serpent")
    state.fd_mode = spec_kit.setting(context, "fd_mode", (spec_kit.setting_bool(context, "use_threat_drop", false) and "high_threat" or "off"))
    state.multishot_mode = spec_kit.setting_number(context, "multishot_mode", spec_kit.setting_number(context, "aoe_threshold", 2))
    state.use_cooldowns = spec_kit.setting_bool(context, "use_cooldowns", true)
    state.use_misdirection = spec_kit.setting_bool(context, "use_misdirection", false)
    local dyn_buf = (hunter_core and hunter_core.get_auto_shot_buffer_ms and hunter_core.get_auto_shot_buffer_ms()) or 150
    state.shot_buffer = spec_kit.setting_number(context, "shot_buffer", dyn_buf)

    -- Melee & AoE settings (parity parity)
    state.use_melee = spec_kit.setting_bool(context, "use_melee", true)
    state.hunter_melee_weave = spec_kit.setting_bool(context, "hunter_melee_weave", true)
    state.hunter_shot_timer_buffer = spec_kit.setting_number(context, "hunter_shot_timer_buffer", 150)
    state.use_volley = spec_kit.setting_bool(context, "use_volley", false)
    state.use_explosive_trap = spec_kit.setting_bool(context, "use_explosive_trap", false)
    state.aoe_threshold = spec_kit.setting_number(context, "aoe_threshold", spec_kit.setting_number(context, "volley_threshold", 3))
    state.trinket_mode = spec_kit.setting(context, "trinket_mode", "off")
    state.auto_aspect = spec_kit.setting_bool(context, "hunter_auto_aspect", true)
    -- Wowsims-aligned Viper/Hawk thresholds: enter Viper at 5%, exit at 25%
    state.viper_mana_threshold = spec_kit.setting_number(context, "hunter_viper_mana_threshold", 5)
    state.viper_exit_threshold = spec_kit.setting_number(context, "hunter_viper_exit_threshold", 25)
    state.distance_sq = context.distance_sq or (context.target_range and context.target_range * context.target_range) or (context.distance and context.distance * context.distance)
    -- Dead zone: target inside melee range (< 5yd) where ranged attacks fail.
    -- Computed from the squared distance (5yd = 25) so Multishot/Steady are
    -- gated correctly; was read-but-never-written (read-side audit 2026-08).
    state.in_dead_zone = state.distance_sq ~= nil and state.distance_sq < 25
    state.has_deterrence = me and safe_buff_up(me, DETERRENCE_BUFF) or false
    state.healthstone_ready = first_ready_item(HEALTHSTONE_IDS) or 0

    -- Major power-window awareness for cooldown alignment
    state.bloodlust_active = me and safe_buff_up(me, BLOODLUST_HEROISM_BUFFS) or false
    state.major_cd_active = (planner and type(planner.is_major_offensive_cd_active) == "function") and safe_any(planner.is_major_offensive_cd_active, context) or false
    state.major_cd_window = state.bloodlust_active or state.major_cd_active

    -- Pre-Steady Shot leveling: Steady is learned at 62. Without it, Arcane Shot is the
    -- only real filler — the endgame 50% mana floor would silence the rotation at 20-61.
    state.level = leveling_helpers.level_from_context(context, 70)
    state.pre_steady_leveling = (state.level < STEADY_SHOT_LEVEL)
        or (context.is_leveling == true and not state.steady_shot_ready)

    return spec_kit.safe_state(state, BM_SCHEMA)
end

-- ============================================================================
-- Helper: is target worth a sting? (HP% gate)
-- ============================================================================
local function sting_worthwhile(target, hp_gate)
    if not target then return false end
    hp_gate = hp_gate or 30
    local target_hp = target.get_health_percentage and target:get_health_percentage() or 100
    return target_hp >= hp_gate
end

-- ============================================================================
-- Helper: should use cooldowns? (TTD gate)
-- ============================================================================
local function cooldowns_allowed(context)
    return state.use_cooldowns and state.in_combat
end

-- ============================================================================
-- Helper: check item cooldown (trinkets, potions)
-- ============================================================================
is_item_ready = function(me, item_id)
    if not me or not item_id then return false end
    local cd_fn = me.get_item_cooldown
    if cd_fn then
        local start, dur = cd_fn(me, item_id)
        if start and dur then
            local remaining = (start + dur) - (NS.time_now and NS.time_now() or 0)
            return remaining <= 0.5
        end
    end
    return true
end


-- ============================================================================
-- Match functions
-- ============================================================================

-- Mounted bail: skip everything if mounted
local function mounted_bail(context, s)
    if s.is_mounted then return false end
    return true
end

-- OUT OF COMBAT — Pet management
local function call_pet_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if s.in_combat then return false end
    if not s.has_pet_spell then return false end
    if s.has_pet then return false end
    if not s.call_pet_ready then return false end
    return true
end

local function revive_pet_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if s.in_combat then return false end
    if not s.has_pet_spell then return false end
    if s.has_pet and s.pet_alive then return false end
    if s.call_pet_ready and not s.has_pet then
        -- Let Call Pet handle first attempt
        return false
    end
    if not s.revive_pet_ready then return false end
    return true
end

-- Aspect management (OOC — Cheetah for speed if auto mode)
-- (Handled inline in strategy for simplicity)

-- OUT OF COMBAT — Aspect of the Hawk on login/respawn
local function ooc_aspect_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if s.in_combat then return false end
    if not s.auto_aspect then return false end
    if s.has_hawk then return false end
    if not spell_ready(ACTION.AspectOfTheHawk, context.me, { skip_range = true }) then return false end
    return true
end

-- Auto Aspect: in-combat Hawk/Viper switching
local function auto_aspect_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not s.auto_aspect then return false end
    -- Wowsims-aligned: Viper at <=5%, Hawk when recovered >25%
    if not s.has_viper and (s.mana_pct or 100) <= (s.viper_mana_threshold or 5) then
        if spell_ready(ACTION.AspectOfTheViper, context.me, { skip_range = true }) then
            return true
        end
    end
    if not s.has_hawk and (s.mana_pct or 100) > (s.viper_exit_threshold or 25) then
        if spell_ready(ACTION.AspectOfTheHawk, context.me, { skip_range = true }) then
            return true
        end
    end
    return false
end

local function auto_aspect_execute(context)
    local s = state
    if not s.has_viper and (s.mana_pct or 100) <= (s.viper_mana_threshold or 5) then
        return NS.try_cast(ACTION.AspectOfTheViper, context.me, "[BEAST_MASTERY] AutoAspect Viper", { skip_range = true })
    end
    return NS.try_cast(ACTION.AspectOfTheHawk, context.me, "[BEAST_MASTERY] AutoAspect Hawk", { skip_range = true })
end

-- Misdirection (pull window)
local function misdirection_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.use_misdirection then return false end
    if not s.in_combat then return false end
    local combat_time = context.combat_time or 0
    if combat_time > 6 then return false end
    if not (NS.is_spell_learned and NS.is_spell_learned(MISDIRECTION_ID)) then return false end
    if not spell_ready(MISDIRECTION_ID, context.me) then return false end
    -- Check if already active
    if NS.has_buff and context.me then
        if NS.has_buff(context.me, MISDIRECTION_ID) then return false end
    end
    return true
end

-- Intimidation (BM pet stun, 60s CD) — combat-only; without the in_combat
-- gate the stun was cast OOC every tick (live-correctness audit 2026-08).
local function intimidation_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not s.pet_alive then return false end
    if not s.intimidation_ready then return false end
    return true
end

-- Multi-Shot (configurable threshold, CC-safe and mana-gated)
local function multi_shot_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if s.in_dead_zone then return false end
    if s.multishot_mode == 0 then return false end
    if not NS.aoe_target_meets or not NS.aoe_target_meets(s.multishot_mode or 2, (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_8) or 8, context.target, context, s) then return false end
    if not s.multi_shot_ready then return false end
    -- CC gate: skip Multi-Shot near breakable CC (sheep/trap/sap)
    if context.has_breakable_cc_nearby then return false end
    -- Mana gate: suppress Multi-Shot below 15% mana (expensive AoE)
    if (s.mana_pct or 100) < MULTI_SHOT_MANA_FLOOR then return false end
    -- Check auto-shot clipping
    if not hunter_core.can_cast_instant(500, s.shot_buffer) then return false end
    return true
end

-- Feign Death (threat management)
local function feign_death_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if s.fd_mode == "off" then return false end
    if not hunter_core.should_feign_death(s.threat_level, s.fd_mode) then return false end
    if not s.feign_death_ready then return false end
    return true
end

-- Sting application (Serpent/Scorpid/Viper based on mode)
local function sting_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not context.target then return false end
    if s.sting_mode == "none" or not s.sting_mode then return false end
    -- Check HP gate (don't sting low-HP targets)
    if not sting_worthwhile(context.target, 30) then return false end

    if s.sting_mode == "serpent" then
        if s.has_serpent_sting then return false end
        if not s.serpent_sting_ready then return false end
        return true
    end
    -- Other stings not implemented yet (Scorpid/Viper via middleware)
    return false
end

-- Serpent Sting refresh (within refresh window)
local function serpent_refresh_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not context.target then return false end
    if s.sting_mode ~= "serpent" then return false end
    if not s.has_serpent_sting then return false end
    if not sting_worthwhile(context.target, 30) then return false end
    -- Check remaining time
    local remains = hunter_core.sting_remains(context.target, "serpent")
    if remains > 3 then return false end
    if not s.serpent_sting_ready then return false end
    return true
end

-- Arcane Shot (instant filler). Endgame BM saves mana for Kill Command (50% floor).
-- Pre-Steady Shot (<62) the floor is relaxed — Steady is unavailable so Arcane is the filler.
local function arcane_shot_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if s.in_dead_zone then return false end
    if not s.arcane_shot_ready then return false end
    local mana_floor = s.pre_steady_leveling and ARCANE_SHOT_MANA_FLOOR_PRE_STEADY or ARCANE_SHOT_MANA_FLOOR
    if (s.mana_pct or 100) < mana_floor then return false end
    -- Check auto-shot clipping for instant
    if not hunter_core.can_cast_instant(500, s.shot_buffer) then return false end
    return true
end

-- Pre-Steady leveling Arcane: no mana floor — keep casting when Steady is not yet learned.
local function leveling_arcane_shot_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not s.pre_steady_leveling then return false end
    if s.in_dead_zone then return false end
    if not s.arcane_shot_ready then return false end
    if not hunter_core.can_cast_instant(500, s.shot_buffer) then return false end
    return true
end

-- Pre-Steady leveling Serpent Sting: ensure DoT is applied when Steady is unavailable.
local function leveling_sting_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not s.pre_steady_leveling then return false end
    if not context.target then return false end
    if s.has_serpent_sting then return false end
    if (s.mana_pct or 100) < 25 then return false end
    if not s.serpent_sting_ready then return false end
    return true
end

-- Steady Shot (primary filler, 62+)
local function steady_shot_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if s.in_dead_zone then return false end
    if not s.steady_shot_ready then return false end
    -- Check auto-shot clipping for steady (via shot_timer if available)
    if shot_timer.should_delay_cast and shot_timer.should_delay_cast(context, s.hunter_shot_timer_buffer) then return false end
    if not hunter_core.can_cast_steady(s.shot_buffer) then return false end
    -- Not while moving (steady requires standing still)
    if context.is_moving then return false end
    return true
end

-- Freezing Trap (OOC, CC)
local function freezing_trap_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if s.in_combat then return false end
    if not context.target then return false end
    if not spell_ready(ACTION.FreezingTrap, context.me, { skip_range = true }) then return false end
    return true
end

-- ============================================================================
-- parity parity match functions (Melee, AoE, Trinkets)
-- ============================================================================

-- Raptor Strike: melee weaving when target in melee range (5yd)
local function raptor_strike_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    -- Backward compat: accept both hunter_melee_weave (new) and use_melee (legacy)
    local melee_enabled
    if s.hunter_melee_weave ~= nil then
        melee_enabled = s.hunter_melee_weave
    else
        melee_enabled = s.use_melee ~= false
    end
    if not melee_enabled then return false end
    if not context.target then return false end
    -- Squared distance: 5yd = 25
    local dsq = s.distance_sq or (context.distance and context.distance * context.distance) or 10000
    if dsq > 25 then return false end
    if not s.raptor_strike_ready then return false end
    -- Don't clip auto-shot
    if not hunter_core.can_cast_instant(500, s.shot_buffer) then return false end
    return true
end

-- Concussive Shot: slow chasing mobs (15yd max range, skip in melee)
local function concussive_shot_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not context.target then return false end
    if not s.concussive_shot_ready then return false end
    -- Squared distance: skip if in melee (< 8yd = 64), max range 15yd = 225
    local dist_sq = s.distance_sq or (context.distance and context.distance * context.distance) or 10000
    if dist_sq < 64 then return false end
    if dist_sq > 225 then return false end
    -- Check auto-shot clipping
    if not hunter_core.can_cast_instant(500, s.shot_buffer) then return false end
    return true
end

-- Volley: AoE channeled (respects threshold)
local function volley_matches(context, s)
    if context.is_channeling then return false end
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not s.use_volley then return false end
    if not NS.aoe_target_meets or not NS.aoe_target_meets(s.aoe_threshold or 3, (NS.AOE_RADIUS and NS.AOE_RADIUS.GROUND_8) or 8, context.target, context, s) then return false end
    if not s.volley_ready then return false end
    if context.is_moving then return false end
    return true
end

-- Explosive Trap: AoE ground placement
local function explosive_trap_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not s.use_explosive_trap then return false end
    if not NS.aoe_self_meets or not NS.aoe_self_meets(s.aoe_threshold or 3, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_10) or 10, context, s) then return false end
    if not s.explosive_trap_ready then return false end
    return true
end

-- Trinket: on-use trinket activation during combat
local function trinket_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not cooldowns_allowed(context) then return false end
    if s.trinket_mode == "off" then return false end
    if s.trinket_mode == "slot1" or s.trinket_mode == "both" then
        if s.trinket_1_id and s.trinket_1_ready then
            return true
        end
    end
    if s.trinket_mode == "slot2" or s.trinket_mode == "both" then
        if s.trinket_2_id and s.trinket_2_ready then
            return true
        end
    end
    return false
end

-- ============================================================================
-- Execute helpers
-- ============================================================================
local function execute_spell(context, name, id, target, prefix)
    prefix = prefix or "[BEAST_MASTERY]"
    if not id then return false end
    local t = target or context.target or context.me
    if not t then return false end
    return NS.try_cast and NS.try_cast(id, t, prefix .. " " .. name) or false
end

local function execute_misdirection(context)
    local prefix = "[BEAST_MASTERY]"
    local target = nil
    -- Try focus target first
    if NS.GetFocus then
        target = NS.GetFocus()
    end
    -- Fallback to pet
    if not target then
        target = hunter_core.get_pet()
    end
    -- Self-Misdirection is invalid (bounces the buff back with no redirect) —
    -- only cast when focus or pet target exists; skip otherwise.
    if not target then
        return false
    end
    return NS.try_cast(MISDIRECTION_ID, target, prefix .. " Misdirection", { skip_range = true })
end

-- ============================================================================
-- Inline strategy helpers for OOC aspect
-- ============================================================================
local function ooc_aspect_execute(context)
    return NS.try_cast(ACTION.AspectOfTheHawk, context.me, "[BEAST_MASTERY] AspectOfTheHawk", { skip_range = true })
end

-- Trinket execute: use on-use trinkets based on mode
local function execute_trinket(context, s)
    local prefix = "[BEAST_MASTERY]"
    if not s then
        local ctx_built = build_state(context)
        s = ctx_built
    end
    if s.trinket_mode == "slot1" or s.trinket_mode == "both" then
        if s.trinket_1_id and s.trinket_1_ready then
            if NS.use_item_by_id then
                local ok = NS.use_item_by_id(s.trinket_1_id, context.me)
                if ok then return true end
            end
        end
    end
    if s.trinket_mode == "slot2" or s.trinket_mode == "both" then
        if s.trinket_2_id and s.trinket_2_ready then
            if NS.use_item_by_id then
                local ok = NS.use_item_by_id(s.trinket_2_id, context.me)
                if ok then return true end
            end
        end
    end
    return false
end

-- ============================================================================
-- Strategies
-- ============================================================================
local strategies = {
    -- Auto Health Potion — gate on context.has_health_potion (inventory_helper)
    { name = "HealthPotion",
      matches = function(context)
          if not context.in_combat then return false end
          if not spec_kit.setting_bool(context, "use_auto_potions", true) then return false end
          if not context.has_health_potion then return false end
          if (context.hp or 100) > 35 then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.HEALTH_POTION_IDS) end },
    -- Auto Mana Potion — gate on context.has_mana_potion (inventory_helper)
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
    -- 1. OOC: Call Pet
    -- Deterrence -- emergency dodge/parry when critically low
    { name = "Deterrence",
      matches = function(context, state)
          if not context.in_combat then return false end
          if (state.hp_pct or 100) > 25 then return false end
          if state.has_deterrence then return false end
          return spell_ready(19263, context.me, { skip_range = true })
      end,
      execute = function(context) return NS.try_cast(19263, context.me, "[BEAST_MASTERY] Deterrence", { skip_range = true, expected_cooldown = 300 }) end },
    {
        name = "CallPet",
        matches = call_pet_matches,
        execute = function(context) return NS.try_cast(ACTION.CallPet, context.me, "[BEAST_MASTERY] CallPet", { skip_range = true }) end,
    },
    -- 2. OOC: Revive Pet
    {
        name = "RevivePet",
        matches = revive_pet_matches,
        execute = function(context) return NS.try_cast(ACTION.RevivePet, context.me, "[BEAST_MASTERY] RevivePet", { skip_range = true }) end,
    },
    -- 3. OOC: Aspect of the Hawk (initial buff)
    {
        name = "AspectOfTheHawk_OOC",
        matches = ooc_aspect_matches,
        execute = ooc_aspect_execute,
    },
    -- 3a. Auto Aspect (in-combat Hawk/Viper)
    {
        name = "AutoAspect",
        matches = auto_aspect_matches,
        execute = auto_aspect_execute,
    },
    -- 4. Misdirection (pull window)
    {
        name = "Misdirection",
        matches = misdirection_matches,
        execute = execute_misdirection,
    },
    -- 5. Mend Pet    -- Pet State: set defensive when pet HP is critically low to preserve it
    { name = "PetDefensive",
      matches = function(context, state)
          if not state.pet_alive then return false end
          if not state.in_combat then return false end
          if (state.pet_hp or 100) > 40 then return false end
          return true
      end,
      execute = function() return pet_manager.set_defensive() end },
    -- Pet State: set passive when player HP is critically low (survival mode)
    { name = "PetPassive",
      matches = function(context, state)
          if not state.pet_alive then return false end
          if not state.in_combat then return false end
          if (context.hp or 100) > 25 then return false end
          return true
      end,
      execute = function() return pet_manager.set_passive() end },
    -- Pet State: set aggressive during combat when pet is healthy
    { name = "PetAggressive",
      matches = function(context, state)
          if not state.pet_alive then return false end
          if not state.in_combat then return false end
          if (state.pet_hp or 100) < 50 then return false end
          return true
      end,
      execute = function() return pet_manager.set_aggressive() end },
    { name = "MendPet" }, -- DSL-substituted at runtime
    -- 6. Hunter's Mark
    { name = "HuntersMark" }, -- DSL-substituted at runtime
    -- 9. Freezing Trap (OOC CC)
    {
        name = "FreezingTrap",
        matches = freezing_trap_matches,
        execute = function(context) return NS.try_cast(ACTION.FreezingTrap, context.me, "[BEAST_MASTERY] FreezingTrap", { skip_range = true, expected_cooldown = 30 }) end,
    },
    -- 10. Kill Command (off-GCD, highest DPS ability for BM — IcyVeins #1 priority)
    { name = "KillCommand" }, -- DSL-substituted at runtime
    -- 11. Bestial Wrath
    { name = "BestialWrath" }, -- DSL-substituted at runtime
    -- 11b. Intimidation (BM pet stun)
    {
        name = "Intimidation",
        matches = intimidation_matches,
        execute = function(context) return NS.try_cast(ACTION.Intimidation, context.target, "[BEAST_MASTERY] Intimidation") end,
    },
    -- 12. Rapid Fire
    { name = "RapidFire" }, -- DSL-substituted at runtime
    -- 13. Readiness (reset CDs)
    { name = "Readiness" }, -- DSL-substituted at runtime
    -- 14. Feign Death (threat management)
    {
        name = "FeignDeath",
        matches = feign_death_matches,
        execute = function(context) return NS.try_cast(ACTION.FeignDeath, context.me, "[BEAST_MASTERY] FeignDeath", { skip_range = true }) end,
    },
    -- 15. Adaptive rotation (DPS-optimal shot selection, setting-gated)
    {
        name = "AdaptiveRotation",
        matches = function(context)
            if not NS.HunterAdaptive then return false end
            if not (spec_kit.setting_bool(context, "use_adaptive_rotation", false)) then return false end
            if not context.in_combat or not context.target then return false end
            return true
        end,
        execute = function(context)
            return (NS.create_adaptive_rotation_strategy and NS.create_adaptive_rotation_strategy()(context)) or false
        end,
    },
    -- 16. Serpent Sting (maintain DoT — wowsims/tbc tryUsePrioGCD applies the
    -- sting BEFORE the shots; MultiShot/ArcaneShot follow)
    {
        name = "SerpentSting",
        matches = sting_matches,
        execute = function(context) return NS.try_cast(ACTION.SerpentSting, context.target, "[BEAST_MASTERY] SerpentSting") end,
    },
    -- 16b. Serpent Sting refresh so the DoT does not fall off mid-fight
    {
        name = "SerpentStingRefresh",
        matches = serpent_refresh_matches,
        execute = function(context) return NS.try_cast(ACTION.SerpentSting, context.target, "[BEAST_MASTERY] SerpentSting refresh") end,
    },
    -- 17. Multi-Shot (AoE)
    {
        name = "MultiShot",
        matches = multi_shot_matches,
        execute = function(context)
            local result = NS.try_cast(ACTION.MultiShot, context.target, "[BEAST_MASTERY] MultiShot")
            if result then hunter_core.record_instant_shot() end
            return result
        end,
    },
    -- 18. Pre-Steady leveling: Arcane/Sting fillers when Steady Shot is not yet learned (lvl < 62)
    {
        name = "LevelingArcaneShot",
        matches = leveling_arcane_shot_matches,
        execute = function(context)
            local result = NS.try_cast(ACTION.ArcaneShot, context.target, "[BEAST_MASTERY] ArcaneShot (leveling)")
            if result then hunter_core.record_instant_shot() end
            return result
        end,
    },
    {
        name = "LevelingSting",
        matches = leveling_sting_matches,
        execute = function(context) return NS.try_cast(ACTION.SerpentSting, context.target, "[BEAST_MASTERY] SerpentSting (leveling)") end,
    },
    -- 17. Arcane Shot (instant filler)
    {
        name = "ArcaneShot",
        matches = arcane_shot_matches,
        execute = function(context)
            local result = NS.try_cast(ACTION.ArcaneShot, context.target, "[BEAST_MASTERY] ArcaneShot")
            if result then hunter_core.record_instant_shot() end
            return result
        end,
    },
    -- 18. Steady Shot (primary filler)
    {
        name = "SteadyShot",
        matches = steady_shot_matches,
        execute = function(context)
            local result = NS.try_cast(ACTION.SteadyShot, context.target, "[BEAST_MASTERY] SteadyShot")
            if result then hunter_core.record_steady_start() end
            return result
        end,
    },
    -- 20. Trinkets (on-use, during combat, respects cooldown toggle)
    {
        name = "Trinket",
        matches = trinket_matches,
        execute = function(context, s)
            -- Dispatcher already built state once this tick (get_state); use it
            -- instead of rebuilding build_state per execute (frame-cache parity).
            -- Fallback rebuild only when a direct caller omits state (tests).
            if not s or (type(s) == "table" and not getmetatable(s) and next(s) == nil) then
                s = build_state(context)
            end
            return execute_trinket(context, s)
        end,
    },
    -- 21. Concussive Shot (kiting utility)
    {
        name = "ConcussiveShot",
        matches = concussive_shot_matches,
        execute = function(context) return NS.try_cast(CONCUSSIVE_SHOT_IDS, context.target, "[BEAST_MASTERY] ConcussiveShot") end,
    },
    -- 22. Volley (AoE channeled)
    {
        name = "Volley",
        matches = volley_matches,
        execute = function(context)
            local t = context.target
            local r = (NS.AOE_RADIUS and NS.AOE_RADIUS.GROUND_8) or 8
            if NS.cast_ground_aoe then return NS.cast_ground_aoe(VOLLEY_IDS, t, r, 35, "[BEAST_MASTERY] Volley") end
            local spell_id = NS.get_spell_id(VOLLEY_IDS)
            local pos = t and spell_id and NS.get_aoe_cast_position and NS.get_aoe_cast_position(spell_id, t, r, 35)
            if pos then return NS.try_cast_position(VOLLEY_IDS, pos, t, "[BEAST_MASTERY] Volley") end
            return NS.try_cast(VOLLEY_IDS, t, "[BEAST_MASTERY] Volley")
        end,
    },
    -- 23. Explosive Trap (AoE ground placement)
    {
        name = "ExplosiveTrap",
        matches = explosive_trap_matches,
        execute = function(context) return NS.try_cast(ACTION.ExplosiveTrap, context.me, "[BEAST_MASTERY] ExplosiveTrap", { skip_range = true, expected_cooldown = 30 }) end,
    },
    -- 24. Raptor Strike (melee weaving)
    {
        name = "RaptorStrike",
        matches = raptor_strike_matches,
        execute = function(context) return NS.try_cast(RAPTOR_STRIKE_IDS, context.target, "[BEAST_MASTERY] RaptorStrike") end,
    },
}

-- ============================================================================
-- Strategy DSL definitions (7th DSL adopter — first hunter/pet-management spec)
-- Converts 6 strategies to declarative DSL, preserving priority order via
-- in-place substitution. Exercises: pet management (KillCommand, MendPet,
-- BestialWrath), cooldown alignment (BestialWrath, RapidFire, Readiness),
-- debuff tracking (HuntersMark), and the first state-comparison ops (pet_hp,
-- rapid_fire_cd). Resource model: focus/mana + pet management.
-- ============================================================================
local DSL_DEFS = {
    -- KillCommand: off-GCD pet ability, highest BM priority (IcyVeins #1).
    -- Conditions: not mounted, in combat, pet alive, spell ready.
    {
        name = "KillCommand",
        conditions = {
            { type = "custom", fn = function(context, state)
                if state.is_mounted then return false end
                return true
            end },
            { type = "in_combat" },
            { type = "state", field = "pet_alive", op = "truthy" },
            { type = "state", field = "kill_command_ready", op = "truthy" },
        },
        execute = function(context)
            return NS.try_cast(ACTION.KillCommand, context.target, "[BEAST_MASTERY] KillCommand")
        end,
    },
    -- BestialWrath: major CD aligned with power windows (Bloodlust/Drums/trinkets).
    -- Conditions: not mounted, cooldowns allowed, boss-only gate, pet alive,
    -- spell ready, TTD gate, CD alignment (major_cd_window or combat_time ≥ 45).
    {
        name = "BestialWrath",
        conditions = {
            { type = "custom", fn = function(context, state)
                if state.is_mounted then return false end
                if not (state.use_cooldowns and state.in_combat) then return false end
                -- IZI SDK: skip offensive CD if target is damage-immune
                local target = context.target
                if target and type(target.is_damage_immune) == "function" then
                    local ok, immune = pcall(target.is_damage_immune, target)
                    if ok and immune then return false end
                end
                return true
            end },
            { type = "custom", fn = function(context, state)
                if not (NS.gate_cooldown_boss_only and NS.gate_cooldown_boss_only(context)) then return false end
                return true
            end },
            { type = "state", field = "pet_alive", op = "truthy" },
            { type = "state", field = "bestial_wrath_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if context.ttd_known and (context.ttd or 0) < 15 then return false end
                local align = state.major_cd_window or false
                local combat_time = context.combat_time or 0
                local ttd = context.ttd or 999
                if not align and combat_time < 45 and ttd > 15 then return false end
                return true
            end },
        },
        execute = function(context)
            local pet = hunter_core.get_pet()
            local target = pet or context.me
            return NS.try_cast(ACTION.BestialWrath, target, "[BEAST_MASTERY] BestialWrath", { skip_range = true })
        end,
    },
    -- RapidFire: personal DPS cooldown.
    -- Conditions: not mounted, cooldowns allowed, spell ready.
    {
        name = "RapidFire",
        conditions = {
            { type = "custom", fn = function(context, state)
                if state.is_mounted then return false end
                if not (state.use_cooldowns and state.in_combat) then return false end
                return true
            end },
            { type = "state", field = "rapid_fire_ready", op = "truthy" },
        },
        execute = function(context)
            return NS.try_cast(ACTION.RapidFire, context.me, "[BEAST_MASTERY] RapidFire", { skip_range = true })
        end,
    },
    -- Readiness: reset Rapid Fire when it has substantial cooldown remaining.
    -- Conditions: not mounted, cooldowns allowed, use_readiness setting,
    --              spell ready, Rapid Fire CD >= 60s.
    {
        name = "Readiness",
        conditions = {
            { type = "custom", fn = function(context, state)
                if state.is_mounted then return false end
                if not (state.use_cooldowns and state.in_combat) then return false end
                return true
            end },
            { type = "setting", key = "use_readiness", default = true },
            { type = "state", field = "readiness_ready", op = "truthy" },
            { type = "state", field = "rapid_fire_cd", op = ">=", value = 60 },
        },
        execute = function(context)
            return NS.try_cast(ACTION.Readiness, context.me, "[BEAST_MASTERY] Readiness", { skip_range = true, expected_cooldown = 300 })
        end,
    },
    -- MendPet: heal pet when critically low.
    -- Conditions: not mounted, in combat, pet alive, pet_hp ≤ 45, spell ready.
    {
        name = "MendPet",
        conditions = {
            { type = "custom", fn = function(context, state)
                if state.is_mounted then return false end
                return true
            end },
            { type = "in_combat" },
            { type = "state", field = "pet_alive", op = "truthy" },
            { type = "state", field = "pet_hp", op = "<=", value = 45 },
            { type = "state", field = "mend_pet_ready", op = "truthy" },
        },
        execute = function(context)
            local pet = hunter_core.get_pet()
            if not pet then return false end
            local result = NS.try_cast(ACTION.MendPet, pet, "[BEAST_MASTERY] MendPet")
            if result then hunter_core.record_mend() end
            return result
        end,
    },
    -- HuntersMark: apply debuff at combat start.
    -- Conditions: not broken_api throttled, not mounted, in combat, target exists,
    -- debuff not already applied, spell ready.
    {
        name = "HuntersMark",
        conditions = {
            { type = "custom", fn = function(context, state)
                return true
            end },
            { type = "custom", fn = function(context, state)
                if state.is_mounted then return false end
                return true
            end },
            { type = "in_combat" },
            { type = "custom", fn = function(context, state)
                if not context.target then return false end
                return true
            end },
            { type = "state", field = "has_hunters_mark", op = "falsy" },
            { type = "state", field = "hunters_mark_ready", op = "truthy" },
        },
        execute = function(context)
            return NS.try_cast(ACTION.HuntersMark, context.target, "[BEAST_MASTERY] HuntersMark")
        end,
    },
}

-- In-place substitution: replace matching strategy entries with DSL-compiled versions,
-- preserving priority order. Named match functions remain as dead code (cleaned up later).
local DSL_STRATEGIES = dsl.compile_strategies(DSL_DEFS, { get_state = build_state })
local _dsl_by_name = {}
for _i = 1, #DSL_STRATEGIES do _dsl_by_name[DSL_STRATEGIES[_i].name] = DSL_STRATEGIES[_i] end
for _i = 1, #strategies do
    local _dsl = _dsl_by_name[strategies[_i].name]
    if _dsl then
        strategies[_i] = _dsl
    end
end

-- Register strategies
if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("beast_mastery", strategies, { get_state = build_state })
end
if NS.log then NS.log("Hunter beast mastery rotation registered") end
-- Hunter beast_mastery rotation registered

return { strategies = strategies, build_state = build_state }
