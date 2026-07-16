-- frost_wotlk.lua — Death Knight Frost DPS rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies: disease maintenance (Icy Touch / Plague Strike), Killing Machine
--        Frost Strike, Rime Howling Blast, Obliterate, Blood Strike filler, Unbreakable Armor,
--        Horn of Winter, Frost Presence, Empower Rune Weapon, Mind Freeze interrupt.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims Frost 2H APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); rune/presence/interrupt managers
--         are pcall-loaded and nil-guarded so the spec still loads if a module is absent.
-- DECISION: rune_manager supplies rune/runic-power state; presence_manager arbitrates Frost
--           Presence; interrupt_manager supplies Mind Freeze. Reference: Frost2W_DPS_DarhangeR.

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.DeathKnightSpells or {}

-- Optional shared managers (pcall-guarded: spec still loads if a module is missing).
local _ok_rune, rune_manager = pcall(require, "shared/rune_manager_sylvanas")
if not _ok_rune then rune_manager = nil end
local _ok_pres, presence_manager = pcall(require, "shared/presence_manager_sylvanas")
if not _ok_pres then presence_manager = nil end
local _ok_int, interrupt_manager = pcall(require, "shared/interrupt_manager_sylvanas")
if not _ok_int then interrupt_manager = nil end

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    IcyTouch = define("IcyTouch", { 45477, 49903, 49904, 49909 }, "IcyTouch"),
    PlagueStrike = define("PlagueStrike", { 49917, 49918, 49919, 49920, 49921 }, "PlagueStrike"),
    Obliterate = define("Obliterate", { 49020, 51423, 51424, 51425 }, "Obliterate"),
    HowlingBlast = define("HowlingBlast", { 49184, 51409, 51410, 51411 }, "HowlingBlast"),
    FrostStrike = define("FrostStrike", { 55268, 49143, 51414, 51415, 51416, 51417, 51418, 51419, 51420, 51421 }, "FrostStrike"),
    BloodStrike = define("BloodStrike", { 45902, 49926, 49927, 49928, 49929, 49930 }, "BloodStrike"),
    HornOfWinter = define("HornOfWinter", { 57330, 57623 }, "HornOfWinter"),
    UnbreakableArmor = define("UnbreakableArmor", 51271, "UnbreakableArmor"),
    EmpowerRuneWeapon = define("EmpowerRuneWeapon", 47568, "EmpowerRuneWeapon"),
    MindFreeze = define("MindFreeze", 47528, "MindFreeze"),
    FrostPresence = define("FrostPresence", 48263, "FrostPresence"),
}

-- Disease / proc / buff ID tables (single-rank diseases per 3.3.5a DBC).
local FROST_FEVER = { 55095 }
local BLOOD_PLAGUE = { 55078 }
local HORN_OF_WINTER_BUFF = { 57330, 57623 }
local KILLING_MACHINE_BUFF = { 51124 }
local RIME_BUFF = { 59052 }
local UNBREAKABLE_ARMOR_BUFF = { 51271 }
local FROST_PRESENCE_BUFF = { 48263 }

-- Frost DK raw state (safe_state proxy applies Pattern 14 defaults in build_state).
local frost_state = {
    hp = 100,
    target_hp = 100,
    enemy_count = 1,
    in_combat = false,
    frost_fever_remains = 0,
    blood_plague_remains = 0,
    horn_of_winter_up = false,
    runic_power = 0,
    rime_proc = false,
    killing_machine = false,
    blood_runes_ready = 0,
    frost_runes_ready = 0,
    unholy_runes_ready = 0,
    death_runes_ready = 0,
    total_runes_ready = 0,
    unbreakable_armor_up = false,
    unbreakable_armor_ready = false,
    empower_rune_weapon_ready = false,
    frost_presence_up = false,
    presence = 1,
}

local function build_state(context)
    local state = spec_kit.safe_state(frost_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target

    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false

    state.frost_fever_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FROST_FEVER)) or 0
    state.blood_plague_remains = (target and NS.debuff_remains and NS.debuff_remains(target, BLOOD_PLAGUE)) or 0
    state.horn_of_winter_up = (me and NS.buff_up and NS.buff_up(me, HORN_OF_WINTER_BUFF)) or false
    state.rime_proc = (me and NS.buff_up and NS.buff_up(me, RIME_BUFF)) or false
    state.killing_machine = (me and NS.buff_up and NS.buff_up(me, KILLING_MACHINE_BUFF)) or false
    state.unbreakable_armor_up = (me and NS.buff_up and NS.buff_up(me, UNBREAKABLE_ARMOR_BUFF)) or false
    state.frost_presence_up = (me and NS.buff_up and NS.buff_up(me, FROST_PRESENCE_BUFF)) or false
    state.presence = state.frost_presence_up and 2 or 1

    -- Runic power via rune_manager (primary) with direct unit API fallback.
    if rune_manager and rune_manager.get_runic_power then
        state.runic_power = rune_manager.get_runic_power(me) or 0
    else
        state.runic_power = (me and me.get_runic_power and me:get_runic_power()) or 0
    end

    -- Rune availability via rune_manager (falls back to 0 when rune APIs are absent).
    if rune_manager then
        state.blood_runes_ready = (rune_manager.get_blood_runes_ready and rune_manager.get_blood_runes_ready()) or 0
        state.frost_runes_ready = (rune_manager.get_frost_runes_ready and rune_manager.get_frost_runes_ready()) or 0
        state.unholy_runes_ready = (rune_manager.get_unholy_runes_ready and rune_manager.get_unholy_runes_ready()) or 0
        state.death_runes_ready = (rune_manager.get_death_runes_ready and rune_manager.get_death_runes_ready()) or 0
    else
        state.blood_runes_ready = 0
        state.frost_runes_ready = 0
        state.unholy_runes_ready = 0
        state.death_runes_ready = 0
    end
    state.total_runes_ready = (state.blood_runes_ready + state.frost_runes_ready
        + state.unholy_runes_ready + state.death_runes_ready)

    state.unbreakable_armor_ready = (ACTION.UnbreakableArmor and ACTION.UnbreakableArmor.cooldown_remaining
        and ACTION.UnbreakableArmor:cooldown_remaining() <= 0) or false
    state.empower_rune_weapon_ready = (ACTION.EmpowerRuneWeapon and ACTION.EmpowerRuneWeapon.cooldown_remaining
        and ACTION.EmpowerRuneWeapon:cooldown_remaining() <= 0) or false

    return state
end

-- Match functions (each returns a strict boolean) --------------------------------

local function horn_of_winter_matches(context, state)
    return state.horn_of_winter_up == false
end

local function frost_presence_matches(context, state)
    if not (NS.is_wotlk and NS.is_wotlk()) then return false end
    local mode = spec_kit.setting(context, "presence_mode", "auto")
    if mode == "manual" then return false end
    -- Frost DK DPS default presence is Frost (per spec contract); honor explicit overrides.
    local desired = mode
    if mode == "auto" then desired = "frost" end
    if desired ~= "frost" then return false end
    if presence_manager and presence_manager.should_switch_presence then
        return presence_manager.should_switch_presence(context, state, "frost") and true or false
    end
    return state.frost_presence_up == false
end

local function unbreakable_armor_matches(context, state)
    if not state.in_combat then return false end
    if state.unbreakable_armor_up then return false end
    if not state.unbreakable_armor_ready then return false end
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 60) then return false end
    return true
end

local function empower_rune_weapon_matches(context, state)
    if not state.in_combat then return false end
    if not state.empower_rune_weapon_ready then return false end
    if (state.total_runes_ready or 0) > 0 then return false end
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 120) then return false end
    return true
end

local function icy_touch_matches(context, state)
    return (state.frost_fever_remains or 0) < 3
end

local function plague_strike_matches(context, state)
    return (state.blood_plague_remains or 0) < 3
end

local function howling_blast_matches(context, state)
    -- Rime proc grants a free Howling Blast; AoE uses it when Frost Fever is up.
    if state.rime_proc then return true end
    if (state.frost_fever_remains or 0) > 0
        and NS.aoe_target_meets and NS.aoe_target_meets(3, (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_10) or 10, context and context.target, context, state) then
        return true
    end
    return false
end

local function frost_strike_km_matches(context, state)
    -- Killing Machine proc prioritizes Frost Strike (guaranteed crit) above Obliterate.
    if not state.killing_machine then return false end
    return (state.runic_power or 0) >= 40
end

local function obliterate_matches(context, state)
    if (state.frost_fever_remains or 0) <= 0 then return false end
    if (state.blood_plague_remains or 0) <= 0 then return false end
    -- Obliterate consumes one frost and one unholy rune (death runes substitute either).
    local frost = (state.frost_runes_ready or 0) + (state.death_runes_ready or 0)
    local unholy = (state.unholy_runes_ready or 0) + (state.death_runes_ready or 0)
    return frost >= 1 and unholy >= 1
end

local function frost_strike_matches(context, state)
    -- Primary runic-power spender (40 RP cost).
    return (state.runic_power or 0) >= 40
end

local function blood_strike_matches(context, state)
    -- Blood rune (or death rune) filler.
    local blood = (state.blood_runes_ready or 0) + (state.death_runes_ready or 0)
    return blood >= 1
end

-- Interrupt strategy via interrupt_manager (nil-safe fallback if manager absent).
local interrupt_strategy
if interrupt_manager and interrupt_manager.register_interrupt_spell then
    local ok, strat = pcall(interrupt_manager.register_interrupt_spell, "deathknight", "MindFreeze", SPELLS, nil)
    if ok and type(strat) == "table" then
        interrupt_strategy = strat
        if strat.name then strat.name = "MindFreeze" end
    end
end
if not interrupt_strategy then
    interrupt_strategy = {
        name = "MindFreeze",
        matches = function(context, state) return false end,
        execute = function(context) return false end,
    }
end

local strategies = {
    interrupt_strategy,
    { name = "HornOfWinter", matches = horn_of_winter_matches, execute = function(ctx) return ACTION.HornOfWinter and ACTION.HornOfWinter:cast_safe() end },
    { name = "FrostPresence", matches = frost_presence_matches, execute = function(ctx)
        return ACTION.FrostPresence and ACTION.FrostPresence:cast_safe() and true or false
      end },
    { name = "UnbreakableArmor", matches = unbreakable_armor_matches, execute = function(ctx) return ACTION.UnbreakableArmor and ACTION.UnbreakableArmor:cast_safe() end },
    { name = "EmpowerRuneWeapon", matches = empower_rune_weapon_matches, execute = function(ctx) return ACTION.EmpowerRuneWeapon and ACTION.EmpowerRuneWeapon:cast_safe() end },
    { name = "IcyTouch", matches = icy_touch_matches, execute = function(ctx) return ACTION.IcyTouch and ACTION.IcyTouch:cast_safe(ctx.target) end },
    { name = "PlagueStrike", matches = plague_strike_matches, execute = function(ctx) return ACTION.PlagueStrike and ACTION.PlagueStrike:cast_safe(ctx.target) end },
    { name = "HowlingBlast", matches = howling_blast_matches, execute = function(ctx) return ACTION.HowlingBlast and ACTION.HowlingBlast:cast_safe(ctx.target) end },
    { name = "FrostStrikeKM", matches = frost_strike_km_matches, execute = function(ctx) return ACTION.FrostStrike and ACTION.FrostStrike:cast_safe(ctx.target) end },
    { name = "Obliterate", matches = obliterate_matches, execute = function(ctx) return ACTION.Obliterate and ACTION.Obliterate:cast_safe(ctx.target) end },
    { name = "FrostStrike", matches = frost_strike_matches, execute = function(ctx) return ACTION.FrostStrike and ACTION.FrostStrike:cast_safe(ctx.target) end },
    { name = "BloodStrike", matches = blood_strike_matches, execute = function(ctx) return ACTION.BloodStrike and ACTION.BloodStrike:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("frost", strategies, { get_state = build_state })
end
if NS.log then NS.log("Death Knight frost rotation registered") end

return { strategies = strategies, build_state = build_state }
