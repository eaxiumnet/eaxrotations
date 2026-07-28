-- arcane_sylvanas.lua — Mage Arcane rotation for TBC Anniversary (2.5.5).
-- WHAT:  burst/conserve DPS spec — AB stacking, AP+PoM, wowsims-aligned burn/conserve
--         phase state machine with MTTE-based mana management.
-- WHEN:  combat, with valid enemy target.
-- WHY:   mirrors wowsims APL: ConserveRotation (AB3→Frostbolt), ManaGem at mana gap,
--         Evocation when AP+IV inactive & mana<20%, PoM at end of AP window.
-- SAFETY: Pattern 14 nil-guards via spec_kit.safe_state; no on_update() allocs;
--          phase state machine with hysteresis prevents flip-flopping.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.MageSpells or {}

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
local _base_define = spec_kit.define_action_for_class(SPELLS)
-- Nil-safe wrapper: in unit-test environments SPELLS is empty → _base_define
-- returns nil; fall back to NS.spell_action or a raw { id, name } table.
local function define(name, ids, label)
    local result = _base_define(name, ids, label)
    if result then return result end
    if NS.spell_action then return NS.spell_action(ids, label) end
    return { id = ids, name = name }
end
local ACTION = {
    ArcaneBlast    = define("ArcaneBlast",    {30451}, "ArcaneBlast"),
    ArcaneMissiles = define("ArcaneMissiles", {38699, 25345, 10212, 10211, 8418, 8417, 8416, 5145, 5144, 5143}, "ArcaneMissiles"),
    ArcanePower    = define("ArcanePower",    {12042}, "ArcanePower"),
    Blink          = define("Blink",          {1953}, "Blink"),
    ColdSnap       = define("ColdSnap",       {11958}, "ColdSnap"),
    Evocation      = define("Evocation",      {12051}, "Evocation"),
    FireBlast      = define("FireBlast",      {27079, 27078, 10199, 10197, 8413, 8412, 2138, 2137, 2136}, "FireBlast"),
    Fireball       = define("Fireball",       {27070, 25306, 10151, 10150, 10149, 10148, 8402, 8401, 8400, 3140, 145, 143, 133}, "Fireball"),
    FrostNova      = define("FrostNova",      {27088, 10230, 6131, 865, 122}, "FrostNova"),
    Frostbolt      = define("Frostbolt",      {27072, 25304, 10181, 10180, 10179, 8408, 8407, 8406, 7322, 837, 205, 116}, "Frostbolt"),
    IceBarrier     = define("IceBarrier",     {33405, 27134, 13033, 13032, 13031, 11426}, "IceBarrier"),
    IceBlock       = define("IceBlock",       {45438}, "IceBlock"),
    IcyVeins       = define("IcyVeins",       {12472}, "IcyVeins"),
    ManaShield     = define("ManaShield",     {27131, 10193, 10192, 10191, 8495, 8494, 1463}, "ManaShield"),
    Polymorph      = define("Polymorph",      {12826, 12825, 12824, 118}, "Polymorph"),
    PresenceOfMind = define("PresenceOfMind", {12043}, "PresenceOfMind"),
    Slow           = define("Slow",           {31589}, "Slow"),
}
local _planner_ok, planner = pcall(require, "shared/cooldown_planner_sylvanas")
if not _planner_ok or type(planner) ~= "table" then planner = nil end
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { SPELLS = { mage = {} } } end
local TBC_MAGE = (TBC.SPELLS and TBC.SPELLS.mage) or {}

-- ============================================================================
-- Buff / Debuff IDs
-- ============================================================================
local ARCANE_BLAST_DEBUFF = { 36032, 36033, 36034 }  -- AB debuff: increases mana cost, reduces cast time
local ARCANE_POWER_BUFF = { 12042 }
local PRESENCE_OF_MIND_BUFF = { 12043 }
local ICE_BARRIER_BUFF = { 13032, 13031, 13033 }
local MANA_SHIELD_BUFF = { 27131, 10193, 10192, 10191, 8495, 8494, 1463 }
local CLEARCASTING_BUFF = { 12536 }  -- Clearcasting proc from Arcane Concentration talent
local SLOW_DEBUFF = { 31589 }
local FROST_NOVA_ROOTS = TBC_MAGE.frost_nova or { 27088, 10230, 6131, 865, 122 }

-- ============================================================================
-- Constants
-- ============================================================================
local AB_BASE_MANA_COST = 195              -- AB rank 1 (~20% of ~975 base mana)
local AB_MANA_MULT_PER_STACK = 0.75         -- Each stack: +75% mana cost
local AB_BASE_CAST_TIME = 2.5               -- Base cast time (seconds)
local AB_CAST_REDUCTION_PER_STACK = 0.1     -- Each stack: -0.1s cast time
local AB_STACK_DURATION = 8                 -- Stacks last 8 seconds

-- MTTE constants (conservative estimates including Fire Blast / Frostbolt filler)
local MTTE_BURN_MPS_MULT = 1.4              -- Add 40% overhead for rotations with instant casts
local MTTE_CONSERVE_MPS = 80                -- ~80 mana/sec during conserve (Frostbolt filler + regen)

-- Wowsims APL-aligned thresholds
local CONSERVE_START_PCT = 20               -- Enter conserve at 20% mana
local CONSERVE_END_PCT = 30                 -- Exit conserve at 30% mana
local DELAY_MAJOR_CDS_S = 10                -- Delay major CDs 10s into combat

-- Bloodlust / Heroism buff IDs
local BLOODLUST_BUFFS = { 2825, 32182 }

local MANA_GEM_ITEM_IDS = { 22044, 8008, 8007, 5513, 5514 } -- Emerald, Ruby, Citrine, Jade, Agate.

-- Phases (wowsims-aligned: burn = AB spam; conserve = AB3->Frostbolt)
local PHASE_BURN = "burn"
local PHASE_CONSERVE = "conserve"
local PHASE_EMERGENCY = "emergency"

-- Root/snare debuff IDs (used by Blink escape)
local COMMON_SNARES = { 122, 116, 120, 339, 5116, 3409, 3600, 12494, 13099 }

local HEALTHSTONE_IDS = { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }
local function first_ready_item(item_ids)
    if not NS.is_item_ready then return 0 end
    for i = 1, #item_ids do
        local item_id = item_ids[i]
        if NS.is_item_ready(item_id) then return item_id end
    end
    return 0
end

-- ============================================================================
-- Phase State Machine State
-- ============================================================================
local ARCANE_SCHEMA = {
    phase = PHASE_CONSERVE,  ab_stacks = 0,  ab_remains = 0,
    has_arcane_power = false,  has_presence_of_mind = false,
    has_ice_barrier = false,  has_mana_shield = false,  has_clearcasting = false,
    mana_pct = 100,  hp_pct = 100,  max_mana = 15000,
    in_combat = false,  is_moving = false,  is_group = false,
    target_casting = false,
    min_mtte = 12,  mtte_burn = 999,  mtte_conserve = 999,
    mana_gem_available = false,  evocation_available = false,
    bloodlust_active = false,  can_burn = false,  should_conserve = false,
    healthstone_ready = 0,  current_mana = 15000,  mana_regen = 0,
    has_serpent_coil = false,  arcane_power_available = false,
    icy_veins_remains = 0,  cold_snap_remains = 0,  combat_time = 0,
}

local arcane_state = {
    phase = PHASE_CONSERVE,
    ab_stacks = 0,
    ab_remains = 0,
    has_arcane_power = false,
    has_presence_of_mind = false,
    has_ice_barrier = false,
    has_mana_shield = false,
    mana_pct = 100,
    hp_pct = 100,
    max_mana = 15000,
    in_combat = false,
    is_moving = false,
    target_casting = false,
    min_mtte = 12,
    mtte_burn = 999,
    mtte_conserve = 999,
    mana_gem_available = false,
    evocation_available = false,
    bloodlust_active = false,
    can_burn = false,
    should_conserve = false,
    healthstone_ready = 0,
    current_mana = 15000,
    mana_regen = 0,
    has_serpent_coil = false,  -- Serpent-Coil Braid (37445) for mana gem optimization
}

-- ============================================================================
-- Helper Functions
-- ============================================================================

--- Get current Arcane Blast stack count and remaining duration
local function get_ab_stacks(me)
    if not me then return 0, 0 end
    local stacks = NS.debuff_stacks and NS.debuff_stacks(me, ARCANE_BLAST_DEBUFF) or 0
    local remains = NS.debuff_remains and NS.debuff_remains(me, ARCANE_BLAST_DEBUFF) or 0
    return stacks, remains
end

local function first_ready_mana_gem()
    if not NS.is_item_ready then return nil end
    for _, item_id in ipairs(MANA_GEM_ITEM_IDS) do
        local ok, ready = pcall(NS.is_item_ready, item_id)
        if ok and ready then return item_id end
    end
    return nil
end

local function use_mana_gem()
    local item_id = first_ready_mana_gem()
    if not item_id or not NS.use_item_by_id then return false end
    local ok, used = pcall(NS.use_item_by_id, item_id)
    return ok and used == true
end

--- Calculate MTTE at a given AB stack level using actual player max mana.
--- @param mana_pct number Current mana percentage (0-100)
--- @param ab_stacks number Current AB stacks (0-3)
--- @param max_mana number Player's maximum mana pool
--- @return number mtte Seconds until empty at this stack level (999 if indefinitely sustainable)
local function calc_mtte(mana_pct, ab_stacks, max_mana)
    if mana_pct <= 0 then return 0 end
    local est_mana = max_mana * (mana_pct / 100)
    if ab_stacks <= 0 then
        -- Conserve: AM filler costs ~310 mana per 5s channel, plus regen
        if MTTE_CONSERVE_MPS <= 0 then return 999 end
        return est_mana / MTTE_CONSERVE_MPS
    end
    local mana_cost = AB_BASE_MANA_COST * (1 + AB_MANA_MULT_PER_STACK * ab_stacks)
    local cast_time = math.max(1.0, AB_BASE_CAST_TIME - AB_CAST_REDUCTION_PER_STACK * ab_stacks)
    local mps = (mana_cost / cast_time) * MTTE_BURN_MPS_MULT
    if mps <= 0 then return 999 end
    return est_mana / mps
end

-- Settings access via spec_kit (Pattern 8 / canonical Pattern 16)

-- ============================================================================
-- State Builder (called once per frame by the framework)
-- ============================================================================
local function build_state(context)
    local me = context.me or NS.GetPlayer()
    local s = arcane_state

    -- Basic state
    s.is_group = context.is_group or false
    s.mana_pct = context.mana_pct or (me and NS.unit_mana_pct and NS.unit_mana_pct(me)) or 100
    s.hp_pct = context.hp or (me and NS.unit_health_pct and NS.unit_health_pct(me)) or 100
    s.in_combat = context.in_combat or false
    s.is_moving = context.is_moving or false
    s.target_casting = context.target and context.target.is_casting and context.target:is_casting() or false
    s.combat_time = context.combat_time or 0

    if me then
        -- Actual max mana for realistic MTTE. Use documented Sylvanas API get_max_power.
        local power_type = NS.POWER_MANA or 0
        s.max_mana = 15000
        if me.get_max_power and type(me.get_max_power) == "function" then
            local ok, val = pcall(me.get_max_power, me, power_type)
            if ok and type(val) == "number" and val > 0 then s.max_mana = val end
        elseif me.get_max_mana and type(me.get_max_mana) == "function" then
            -- Fallback: undocumented but sometimes present
            local ok, val = pcall(me.get_max_mana, me)
            if ok and type(val) == "number" and val > 0 then s.max_mana = val end
        elseif NS.unit_max_mana and type(NS.unit_max_mana) == "function" then
            local ok, val = pcall(NS.unit_max_mana, me)
            if ok and type(val) == "number" and val > 0 then s.max_mana = val end
        end
        if s.max_mana <= 0 then s.max_mana = 15000 end

        s.ab_stacks, s.ab_remains = get_ab_stacks(me)
        s.has_arcane_power = NS.buff_up and NS.buff_up(me, ARCANE_POWER_BUFF) or false
        s.has_presence_of_mind = NS.buff_up and NS.buff_up(me, PRESENCE_OF_MIND_BUFF) or false
        s.has_ice_barrier = NS.buff_up and NS.buff_up(me, ICE_BARRIER_BUFF) or false
        s.has_mana_shield = NS.buff_up and NS.buff_up(me, MANA_SHIELD_BUFF) or false
        s.bloodlust_active = NS.buff_up and NS.buff_up(me, BLOODLUST_BUFFS) or false
        s.has_serpent_coil = NS.buff_up and NS.buff_up(me, {37445}) or false
        s.icy_veins_remains = NS.cooldown_remains and NS.cooldown_remains(ACTION.IcyVeins) or 0
        s.cold_snap_remains = NS.cooldown_remains and NS.cooldown_remains(ACTION.ColdSnap) or 0
        -- Current mana for gem optimization
        s.current_mana = 0
        if me.get_power and type(me.get_power) == "function" then
            local ok, val = pcall(me.get_power, me, NS.POWER_MANA or 0)
            if ok and type(val) == "number" then s.current_mana = val end
        end
        s.mana_regen = 0
        if me.get_power_regen and type(me.get_power_regen) == "function" then
            local ok, val = pcall(me.get_power_regen, me, NS.POWER_MANA or 0)
            if ok and type(val) == "number" then s.mana_regen = val end
        end
    end

    -- Cooldown availability
    s.evocation_available = me and NS.spell_ready and NS.spell_ready(ACTION.Evocation, me, { skip_range = true }) or false
    s.mana_gem_available = false
    if me then s.mana_gem_available = first_ready_mana_gem() ~= nil end
    s.arcane_power_available = me and NS.spell_ready and NS.spell_ready(ACTION.ArcanePower, me, { skip_range = true }) or false
    s.has_clearcasting = NS.buff_up and NS.buff_up(me, CLEARCASTING_BUFF) or false

    -- MTTE calculations using actual max mana
    local cur_stacks = s.ab_stacks
    s.mtte_burn = calc_mtte(s.mana_pct, math.max(cur_stacks, 2), s.max_mana)
    s.mtte_conserve = calc_mtte(s.mana_pct, 0, s.max_mana)

    -- Wowsims APL-aligned phase decision
    -- Conserve Start = 20%, Conserve End = 30%, Delay Major CDs = 10s
    local burn_enabled = spec_kit.setting_bool(context, "arcane_use_burn", true)
    local min_mtte = spec_kit.setting_number(context, "arcane_mtte_min", 12)
    s.min_mtte = min_mtte

    -- Emergency: mana critically low
    if (s.mana_pct or 100) < 10 then
        s.phase = PHASE_EMERGENCY
        s.can_burn = false
        s.should_conserve = true
        return s
    end

    -- Determine if we can sustain a burn phase (wowsims: AvailableMana >= BurnManaNeeded)
    local available_mana = s.current_mana + (s.mana_regen + 49) * ((context.ttd or 180) / 2)
    local burn_mana_needed = 760 * ((context.ttd or 180) / 1.5)
    s.can_burn = burn_enabled
        and s.mana_pct >= CONSERVE_START_PCT + 10  -- ~30% to start burn
        and available_mana >= burn_mana_needed
        and not s.has_arcane_power  -- don't re-evaluate mid-burn CD

    -- Bloodlust overrides: burn while BL is up with sufficient mana
    if s.bloodlust_active and s.mana_pct >= CONSERVE_START_PCT then
        s.can_burn = true
    end

    -- Determine if we should conserve (wowsims: currentManaPercent <= Conserve Start)
    s.should_conserve = s.mana_pct <= CONSERVE_START_PCT
        or s.mtte_burn < 5
        or (s.phase == PHASE_CONSERVE and s.mana_pct < CONSERVE_END_PCT)

    -- Phase transition logic (wowsims-aligned)
    if s.should_conserve then
        s.phase = PHASE_CONSERVE
    elseif s.can_burn then
        s.phase = PHASE_BURN
    elseif s.phase ~= PHASE_BURN and s.phase ~= PHASE_CONSERVE then
        s.phase = PHASE_CONSERVE
    end
    -- Once in burn, stay in burn until we drop below conserve threshold
    if s.phase == PHASE_BURN and s.mana_pct <= CONSERVE_START_PCT then
        s.phase = PHASE_CONSERVE
    end

    return spec_kit.safe_state(s, ARCANE_SCHEMA)
end



-- ============================================================================
-- Match Functions (receive state from framework via get_state)
-- ============================================================================

--- Polymorph: crowd control in PvP
local function polymorph_matches(context, s)
    if NS.DRTracker and NS.DRTracker.is_dr_immune and context.cc_target and NS.DRTracker.is_dr_immune(context.cc_target, "incapacitate") then return false end
    if NS.pvp_trinket_used_recently and NS.pvp_trinket_used_recently(context.cc_target) then return false end
    local group_aware = spec_kit.setting_bool(context, "mage_group_aware_utility", true)
    if not (context.is_pvp or (group_aware and context.is_group)) then return false end
    if not context.cc_target then return false end
    if context.is_moving then return false end
    -- IZI SDK: skip Polymorph if target is already CC'd
    local cc_t = context.cc_target
    if cc_t and type(cc_t.is_cc) == "function" then
        local ok, cc = pcall(cc_t.is_cc, cc_t)
        if ok and cc then return false end
    end
    return true
end

--- Frost Nova: self-peel when target is in melee range
local function frost_nova_matches(context, s)
    local group_aware = spec_kit.setting_bool(context, "mage_group_aware_utility", true)
    if not (context.is_pvp or context.is_leveling or context.is_solo or (group_aware and context.is_group)) then return false end
    if not context.target then return false end
    local me = context.me
    if not me then return false end
    local dist = me.get_distance and me:get_distance(context.target) or 40
    if dist > 10 then return false end
    return true
end

--- Arcane Blast: primary nuke, stack management per phase.
-- Wowsims conserve: build to 3 stacks, then Frostbolt to maintain buff without high mana cost.
local function arcane_blast_matches(context, s)
    if s.is_moving then return false end
    if not context.target then return false end

    -- Phase-based stack limits
    local max_stacks
    if s.phase == PHASE_BURN then
        max_stacks = spec_kit.setting_number(context, "arcane_burn_max_stacks", 4)
    else
        max_stacks = spec_kit.setting_number(context, "arcane_conserve_max_stacks", 3)
        -- Emergency: always 0 stacks
        if s.phase == PHASE_EMERGENCY then max_stacks = 0 end
    end

    -- Zero-stack mode: never cast AB
    if max_stacks == 0 then return false end

    -- Conserve rotation: at 3 stacks with AB buff time > cast time, skip AB (Frostbolt fills)
    if s.phase == PHASE_CONSERVE and (s.ab_stacks or 0) >= 3 then
        local ab_cast_time = math.max(1.0, AB_BASE_CAST_TIME - AB_CAST_REDUCTION_PER_STACK * 3)
        if (s.ab_remains or 0) > ab_cast_time then
            return false  -- Let Frostbolt maintain the buff
        end
    end

    -- If we're already at max stacks for our phase, only cast AB to maintain them
    if (s.ab_stacks or 0) >= max_stacks then
        if (s.ab_remains or 0) > 1.5 then return false end  -- Not about to drop
    end

    -- Don't build stacks if mana is critically low
    -- Clearcasting: always consume on AB (highest mana cost) per research Angle 5
    if s.has_clearcasting then return true end

    if (s.mana_pct or 100) < 15 then
        if (s.ab_stacks or 0) >= max_stacks then return false end
        -- Allow building to 1 stack max when below 15% mana
        if max_stacks > 0 and (s.ab_stacks or 0) >= 1 then return false end
    end

    return NS.spell_ready(ACTION.ArcaneBlast, context.target)
end

--- Fire Blast: instant filler, use on cooldown or while moving
local function fire_blast_matches(context, s)
    if not context.target then return false end
    -- Priority while moving (instant cast)
    if s.is_moving then return true end
    -- Priority when AB is at max stacks (weave instant between AB casts)
    local max_stacks = s.phase == PHASE_BURN
        and spec_kit.setting_number(context, "arcane_burn_max_stacks", 3)
        or spec_kit.setting_number(context, "arcane_conserve_max_stacks", 0)
    if (s.ab_stacks or 0) >= max_stacks then return true end
    -- Otherwise fire blast as filler
    return true
end

--- Arcane Missiles: Clearcasting consumer only (wowsims does not use AM as filler).
local function arcane_missiles_matches(context, s)
    if context.is_channeling then return false end
    if s.is_moving then return false end
    if not context.target then return false end

    -- Clearcasting: always consume free AM casts (per research Angle 5)
    if s.has_clearcasting then return true end

    -- Wowsims APL does not use AM as filler; AB and Frostbolt are the primary spells.
    -- Keep AM as emergency low-mana filler only.
    if s.phase == PHASE_EMERGENCY and (s.mana_pct or 100) < 10 then
        return NS.spell_ready(ACTION.ArcaneMissiles, context.target)
    end

    return false
end

--- Frostbolt: conserve rotation filler (wowsims APL ConserveRotation).
-- At 3 AB stacks with buff time > cast time, cast Frostbolt to maintain buff cheaply.
local function frostbolt_conserve_matches(context, s)
    if s.is_moving then return false end
    if not context.target then return false end
    if s.phase ~= PHASE_CONSERVE then return false end
    if (s.ab_stacks or 0) < 3 then return false end
    local ab_cast_time = math.max(1.0, AB_BASE_CAST_TIME - AB_CAST_REDUCTION_PER_STACK * 3)
    if (s.ab_remains or 0) <= ab_cast_time then return false end  -- Buff about to drop, maintain with AB
    return NS.spell_ready(ACTION.Frostbolt, context.target)
end

--- Fire Blast (execute): wowsims — cast when target about to die (remainingTime < AB cast time).
local function fire_blast_execute_matches(context, s)
    if not context.target then return false end
    if not (context.ttd_known and context.ttd > 0) then return false end
    local ab_cast_time = math.max(1.0, AB_BASE_CAST_TIME - AB_CAST_REDUCTION_PER_STACK * (s.ab_stacks or 0))
    if context.ttd >= ab_cast_time then return false end
    return NS.spell_ready(ACTION.FireBlast, context.target)
end

--- Low-level bolt (Fireball/Frostbolt for leveling before AB is learned)
local function low_level_bolt_matches(context, s)
    if not context.is_leveling then return false end
    if s.is_moving then return false end
    if NS.spell_exists(ACTION.ArcaneBlast) then return false end
    return true
end

-- ============================================================================
-- Declarative Strategy DSL
-- ============================================================================
local DSL_DEFS = {
    {
        name = "IceBarrier",
        conditions = {
            { type = "custom", fn = function(context, state)
                return true
            end },
            { type = "setting", key = "use_defensives", op = "!=", value = false },
            { type = "setting", key = "use_ice_barrier", op = "!=", value = false },
            { type = "state", field = "has_ice_barrier", op = "==", value = false },
            { type = "state", field = "hp_pct", op = "<=", value = 60 },
        },
        action = { type = "cast", spell = ACTION.IceBarrier, target = "self", opts = { skip_range = true }, label = "[ARCANE] IceBarrier" },
    },
    {
        name = "ManaShield",
        conditions = {
            { type = "custom", fn = function(context, state)
                return true
            end },
            { type = "setting", key = "use_defensives", op = "!=", value = false },
            { type = "setting", key = "use_mana_shield", op = "!=", value = false },
            { type = "state", field = "has_mana_shield", op = "==", value = false },
            { type = "state", field = "hp_pct", op = "<=", value = 40 },
            { type = "state", field = "mana_pct", op = ">=", value = 30 },
        },
        action = { type = "cast", spell = ACTION.ManaShield, target = "self", opts = { skip_range = true }, label = "[ARCANE] ManaShield" },
    },
    {
        name = "PresenceOfMind",
        conditions = {
            { type = "setting", key = "use_cooldowns", op = "!=", value = false },
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "has_presence_of_mind", op = "==", value = false },
            { type = "custom", fn = function(context, state)
                -- Wowsims: PoM when AP is active and about to expire (<= AB cast time remaining)
                if state.has_arcane_power then
                    local ab_cast_time = math.max(1.0, AB_BASE_CAST_TIME - AB_CAST_REDUCTION_PER_STACK * (state.ab_stacks or 0))
                    local ap_remains = NS.buff_remains and NS.buff_remains(context.me, ARCANE_POWER_BUFF) or 0
                    if ap_remains > 0 and ap_remains <= ab_cast_time then
                        return true
                    end
                end
                -- Fallback: use PoM during burn phase or bloodlust
                if state.phase ~= PHASE_BURN and not state.bloodlust_active then return false end
                -- Sync with AP: fire PoM only when AP is already active or on cooldown
                local ap_active = state.has_arcane_power or false
                local ap_on_cd = state.arcane_power_available == false
                if not ap_active and not ap_on_cd then return false end
                -- Use PoM while moving to maintain DPS
                if state.is_moving then return true end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.PresenceOfMind, target = "self", opts = { skip_range = true }, label = "[ARCANE] PresenceOfMind" },
    },
    {
        name = "ArcanePower",
        conditions = {
            { type = "setting", key = "use_cooldowns", op = "!=", value = false },
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "has_arcane_power", op = "==", value = false },
            { type = "setting", key = "arcane_use_burn", op = "!=", value = false },
            { type = "custom", fn = function(context, state)
                if not (NS.gate_cooldown_boss_only and NS.gate_cooldown_boss_only(context)) then return false end
                -- IZI SDK: skip offensive CD if target is damage-immune
                local target = context.target
                if target and type(target.is_damage_immune) == "function" then
                    local ok, immune = pcall(target.is_damage_immune, target)
                    if ok and immune then return false end
                end
                local cd_window = state.bloodlust_active
                    or ((state.icy_veins_remains or 0) > 0)
                    or (planner and planner.is_major_offensive_cd_active and planner.is_major_offensive_cd_active(context))
                    or false
                if state.phase ~= PHASE_BURN and not cd_window then return false end
                if (state.mana_pct or 0) < 35 then return false end
                if (state.ab_stacks or 0) >= 2 then return true end
                if state.phase == PHASE_BURN and (state.mana_pct or 0) >= 50 then return true end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.ArcanePower, target = "self", opts = { skip_range = true }, label = "[ARCANE] ArcanePower" },
    },
    {
        name = "Evocation",
        conditions = {
            { type = "setting", key = "use_evocation", op = "!=", value = false },
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "evocation_available", op = "truthy" },
            { type = "custom", fn = function(context, state)
                local evo_mana = spec_kit.setting_number(context, "arcane_evocation_mana", 20)
                local ap_inactive = not state.has_arcane_power
                local iv_inactive = (state.icy_veins_remains or 0) <= 0
                if ap_inactive and iv_inactive and (state.mana_pct or 100) <= CONSERVE_START_PCT then
                    return true
                end
                if (state.mana_pct or 100) <= evo_mana then
                    return true
                end
                if state.phase == PHASE_CONSERVE and (state.mana_pct or 100) <= 30 then
                    return true
                end
                return false
            end },
        },
        action = { type = "cast", spell = ACTION.Evocation, target = "self", opts = { skip_range = true }, label = "[ARCANE] Evocation" },
    },
    {
        name = "ManaGem",
        conditions = {
            { type = "setting", key = "use_mana_gem", op = "!=", value = false },
            { type = "state", field = "mana_gem_available", op = "truthy" },
            { type = "custom", fn = function(context, state)
                local gem_restore = state.has_serpent_coil and 3100 or 2500
                local current_mana = state.current_mana or (state.max_mana or 15000) * (state.mana_pct or 100) / 100
                local max_mana = state.max_mana or 15000
                local threshold = current_mana + gem_restore + (state.mana_regen or 0)
                if max_mana > threshold then
                    return true
                end
                local gem_mana = spec_kit.setting_number(context, "arcane_mana_gem_mana", 55)
                if (state.mana_pct or 100) <= gem_mana then
                    return true
                end
                return false
            end },
        },
        action = { type = "custom", fn = function(context, state) return use_mana_gem() end },
    },
}

-- ============================================================================
-- Strategies (state passed by framework via get_state)
-- ============================================================================
local strategies = {
    -- Defensives (highest priority)
    { name = "IceBarrier" },  -- DSL-substituted at runtime
    { name = "IceBlock",
      matches = function(context, s)
          local group_aware = spec_kit.setting_bool(context, "mage_group_aware_defensives", true)
          local threshold = (group_aware and s.is_group) and 30 or 20
          return (s.hp_pct or 100) <= threshold and NS.spell_ready(ACTION.IceBlock)
      end,
      execute = function() return NS.try_cast(ACTION.IceBlock, NS.PLAYER_UNIT, "[ARCANE] IceBlock", { skip_range = true }) end },
    { name = "ColdSnap",
      matches = function(context, s)
          local group_aware = spec_kit.setting_bool(context, "mage_group_aware_defensives", true)
          local threshold = (group_aware and s.is_group) and 45 or 35
          return (s.hp_pct or 100) <= threshold and not NS.spell_ready(ACTION.IceBlock) and NS.spell_ready(ACTION.ColdSnap)
      end,
      execute = function() return NS.try_cast(ACTION.ColdSnap, NS.PLAYER_UNIT, "[ARCANE] ColdSnap", { skip_range = true }) end },
    { name = "Blink",
      matches = function(context, s) return s.in_combat and (context.self_rooted_snared or (NS.has_player_debuff and NS.has_player_debuff(COMMON_SNARES) or false)) and NS.spell_ready(ACTION.Blink) end,
      execute = function() return NS.try_cast(ACTION.Blink, NS.PLAYER_UNIT, "[ARCANE] Blink", { skip_range = true }) end },
    { name = "ManaShield" },  -- DSL-substituted at runtime
    { name = "Healthstone",
      matches = function(context, state)
          if not context.in_combat then return false end
          if (state.hp_pct or 100) > 28 then return false end
          return (state.healthstone_ready or 0) > 0
      end,
      execute = function(context)
          local item_id = first_ready_item(HEALTHSTONE_IDS)
          if item_id > 0 and NS.use_item_by_id then
              return NS.use_item_by_id(item_id, context.me) and true or false
          end
          return false
      end,
    },

    -- CC / Utility
    { name = "Polymorph",
      matches = polymorph_matches,
      execute = function(context) return NS.try_cast(ACTION.Polymorph, context.cc_target or context.target, "[ARCANE] Polymorph") end },
    { name = "FrostNova",
      matches = frost_nova_matches,
      execute = function(context) return NS.try_cast(ACTION.FrostNova, context.target, "[ARCANE] FrostNova") end },
    { name = "Slow",
      matches = function(context, s)
          if not context.is_pvp then return false end
          if not context.target then return false end
          local me = context.me
          if not me then return false end
          local dist = me.get_distance and me:get_distance(context.target) or 40
          if dist <= 8 then return false end
          return true
      end,
      execute = function(context) return NS.try_cast(ACTION.Slow, context.target, "[ARCANE] Slow") end },

    -- Burst cooldowns (synced with burn phase)
    { name = "PresenceOfMind" },  -- DSL-substituted at runtime
    { name = "ArcanePower" },  -- DSL-substituted at runtime

    -- Burst cooldowns
    { name = "IcyVeins",
      matches = function(context, s)
          if not s.in_combat then return false end
          if not context.target then return false end
          if s.phase ~= "burn" then return false end
          if s.icy_veins_remains and s.icy_veins_remains > 0 then return false end
          return NS.spell_ready(ACTION.IcyVeins, NS.PLAYER_UNIT, { skip_range = true })
      end,
      execute = function()
          return NS.try_cast(ACTION.IcyVeins, NS.PLAYER_UNIT, "[ARCANE] IcyVeins", { skip_range = true })
      end },
    { name = "ColdSnapIVReset",
      matches = function(context, s)
          if not s.in_combat then return false end
          if s.phase ~= "burn" then return false end
          if s.cold_snap_remains and s.cold_snap_remains > 0 then return false end
          if not (s.icy_veins_remains and s.icy_veins_remains > 3) then return false end
          return NS.spell_ready(ACTION.ColdSnap, NS.PLAYER_UNIT, { skip_range = true })
      end,
      execute = function()
          return NS.try_cast(ACTION.ColdSnap, NS.PLAYER_UNIT, "[ARCANE] ColdSnapIVReset", { skip_range = true })
      end },
    -- Mana management
    { name = "Evocation" },  -- DSL-substituted at runtime
    { name = "ManaGem" },  -- DSL-substituted at runtime

    -- Primary nuke: Arcane Blast (stack management)
    { name = "ArcaneBlast",
      matches = arcane_blast_matches,
      execute = function(context) return NS.try_cast(ACTION.ArcaneBlast, context.target, "[ARCANE] ArcaneBlast") end },

    -- Execute: Fire Blast when target about to die (instant > casting)
    { name = "FireBlastExecute",
      matches = fire_blast_execute_matches,
      execute = function(context) return NS.try_cast(ACTION.FireBlast, context.target, "[ARCANE] FireBlast (execute)") end },

    -- Instant filler
    { name = "FireBlast",
      matches = fire_blast_matches,
      execute = function(context) return NS.try_cast(ACTION.FireBlast, context.target, "[ARCANE] FireBlast") end },

    -- Conserve rotation: Frostbolt at 3 AB stacks to maintain buff cheaply
    { name = "FrostboltConserve",
      matches = frostbolt_conserve_matches,
      execute = function(context) return NS.try_cast(ACTION.Frostbolt, context.target, "[ARCANE] Frostbolt (conserve)") end },

    -- Clearcasting AM (only)
    { name = "ArcaneMissiles",
      matches = arcane_missiles_matches,
      execute = function(context) return NS.try_cast(ACTION.ArcaneMissiles, context.target, "[ARCANE] ArcaneMissiles") end },

    -- Leveling fillers (pre-AB)
    { name = "FireballLeveling",
      matches = function(context, s) return low_level_bolt_matches(context, s) end,
      execute = function(context) return NS.try_cast(ACTION.Fireball, context.target, "[ARCANE] Fireball") end },
    { name = "FrostboltLeveling",
      matches = function(context, s) return low_level_bolt_matches(context, s) end,
      execute = function(context) return NS.try_cast(ACTION.Frostbolt, context.target, "[ARCANE] Frostbolt") end },
}

-- Replace imperative match functions with DSL-compiled equivalents.
for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("arcane", strategies, { get_state = build_state })
end
if NS.log then NS.log("Mage arcane rotation registered") end
-- Mage arcane rotation registered (burn/conserve phase state machine + configurable AB stack limits)
return { strategies = strategies, build_state = build_state }

