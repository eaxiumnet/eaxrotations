-- blood_wotlk.lua — Death Knight Blood DPS rotation for Wrath of the Lich King (3.3.5a).
-- WHAT:  priority-list strategies for Blood death knight: disease maintenance
--        (Icy Touch -> Plague Strike -> Pestilence refresh), Heart Strike spam,
--        Death Strike self-heal, Death Coil runic-power dump, Dancing Rune Weapon
--        on boss targets, and Vampiric Blood / Icebound Fortitude defensives.
-- WHEN:  combat with a valid enemy target; Blood Presence is the default DPS presence.
-- WHY:   mirrors the DarhangeR Blood_DPS PQR profile / SimulationCraft APL with
--        WotLK 3.3.5a mechanics (rune + runic-power economy, disease refresh windows).
-- SAFETY: all state.* reads are nil-guarded via spec_kit.safe_state(); rune and
--         runic-power state sourced from RuneManager; presence via PresenceManager;
--         interrupts via InterruptManager; no on_update() allocations.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit          = require("shared/spec_kit_sylvanas")
local RuneManager       = require("shared/rune_manager_sylvanas")
local PresenceManager   = require("shared/presence_manager_sylvanas")
local interrupt_manager = require("shared/interrupt_manager_sylvanas")

local SPELLS = NS.DeathKnightSpells or {}
local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    IcyTouch          = define("IcyTouch",          { 45477, 49903, 49904, 49909 }, "IcyTouch"),
    PlagueStrike      = define("PlagueStrike",      { 49917, 49918, 49919, 49920, 49921 }, "PlagueStrike"),
    Pestilence        = define("Pestilence",        { 50842 }, "Pestilence"),
    HeartStrike       = define("HeartStrike",       { 55050, 55258, 55259, 55260, 55261, 55262 }, "HeartStrike"),
    DeathStrike       = define("DeathStrike",       { 49998, 49999, 45463, 49924 }, "DeathStrike"),
    DeathCoil         = define("DeathCoil",         { 47541, 49892, 49893, 49894, 49895 }, "DeathCoil"),
    DancingRuneWeapon = define("DancingRuneWeapon", 49028, "DancingRuneWeapon"),
    HornOfWinter      = define("HornOfWinter",      { 57330, 57623 }, "HornOfWinter"),
    VampiricBlood     = define("VampiricBlood",     55233, "VampiricBlood"),
    IceboundFortitude = define("IceboundFortitude", 48792, "IceboundFortitude"),
    BloodPresence     = define("BloodPresence",     48266, "BloodPresence"),
}

local DK_CONST            = NS.DeathKnightConstants or {}
local FROST_FEVER         = DK_CONST.FROST_FEVER_DEBUFF or { 55095 }
local BLOOD_PLAGUE        = DK_CONST.BLOOD_PLAGUE_DEBUFF or { 55078 }
local HORN_OF_WINTER_BUFF = DK_CONST.HORN_OF_WINTER_BUFF or { 57330, 57623 }

local BLOOD_PRESENCE_BUFF  = { 48266 }
local FROST_PRESENCE_BUFF  = { 48263 }
local UNHOLY_PRESENCE_BUFF = { 48265 }

local blood_state = {
    hp                   = 100,
    target_hp            = 100,
    enemy_count          = 1,
    in_combat            = false,
    frost_fever_remains  = 0,
    blood_plague_remains = 0,
    horn_of_winter_up    = false,
    runic_power          = 0,
    presence             = nil,
}

-- safe_cast: invoke an action's cast_safe only when it is a real action table.
-- Guards minimal test mocks where NS.spell_action is absent and define_action
-- falls back to returning a bare spell id (a number).
local function safe_cast(action, target)
    if action and type(action) == "table" and type(action.cast_safe) == "function" then
        return action:cast_safe(target)
    end
    return false
end

local function build_state(context)
    local state  = spec_kit.safe_state(blood_state)
    local target = context and context.target
    local me     = NS.me or (NS.GetPlayer and NS.GetPlayer())

    state.hp           = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.target_hp    = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count  = (context and context.enemy_count) or 1
    state.in_combat    = (context and context.in_combat) or false

    state.frost_fever_remains  = (target and NS.debuff_remains and NS.debuff_remains(target, FROST_FEVER)) or 0
    state.blood_plague_remains = (target and NS.debuff_remains and NS.debuff_remains(target, BLOOD_PLAGUE)) or 0

    state.horn_of_winter_up = (me and NS.buff_up and NS.buff_up(me, HORN_OF_WINTER_BUFF)) or false

    -- Runic power and rune snapshot sourced from RuneManager (shared module).
    state.runic_power = RuneManager.get_runic_power(me)
    state.rune_state  = RuneManager.get_rune_state()

    if me and NS.buff_up and NS.buff_up(me, BLOOD_PRESENCE_BUFF) then
        state.presence = PresenceManager.presence_id("blood")
    elseif me and NS.buff_up and NS.buff_up(me, FROST_PRESENCE_BUFF) then
        state.presence = PresenceManager.presence_id("frost")
    elseif me and NS.buff_up and NS.buff_up(me, UNHOLY_PRESENCE_BUFF) then
        state.presence = PresenceManager.presence_id("unholy")
    else
        state.presence = nil
    end

    return state
end

-- ---------------------------------------------------------------------------
-- Match functions (one per strategy)
-- ---------------------------------------------------------------------------

local function presence_matches(context, state)
    if not (NS.is_wotlk and NS.is_wotlk()) then return false end
    local desired = PresenceManager.get_optimal_presence(context, state)
    if not desired then return false end
    return PresenceManager.should_switch_presence(context, state, desired)
end

local function icebound_fortitude_matches(context, state)
    return (state.hp or 100) < 40
end

local function vampiric_blood_matches(context, state)
    return (state.hp or 100) < 50
end

local function horn_of_winter_matches(context, state)
    return not state.horn_of_winter_up
end

local function dancing_rune_weapon_matches(context, state)
    if not state.in_combat then return false end
    if (state.target_hp or 100) <= 50 then return false end
    if (state.runic_power or 0) < 60 then return false end
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 90) then return false end
    return true
end

local function pestilence_matches(context, state)
    local ff = (state.frost_fever_remains or 0)
    local bp = (state.blood_plague_remains or 0)
    if ff <= 0 or bp <= 0 then return false end
    return ff < 3 or bp < 3
end

local function icy_touch_matches(context, state)
    return (state.frost_fever_remains or 0) < 3
end

local function plague_strike_matches(context, state)
    return (state.blood_plague_remains or 0) < 3
end

local function death_strike_matches(context, state)
    return (state.hp or 100) < 80
end

local function heart_strike_matches(context, state)
    return true
end

local function death_coil_matches(context, state)
    return (state.runic_power or 0) >= 40
end

-- ---------------------------------------------------------------------------
-- Strategy table (ordered by priority, highest first)
-- ---------------------------------------------------------------------------

local interrupt_strategy = interrupt_manager.register_interrupt_spell(
    "deathknight", "MindFreeze", SPELLS)

local strategies = {
    interrupt_strategy,
    { name = "Presence",          matches = presence_matches,          execute = function(ctx) return safe_cast(ACTION.BloodPresence, NS.me) end },
    { name = "IceboundFortitude", matches = icebound_fortitude_matches, execute = function(ctx) return safe_cast(ACTION.IceboundFortitude, NS.me) end },
    { name = "VampiricBlood",     matches = vampiric_blood_matches,     execute = function(ctx) return safe_cast(ACTION.VampiricBlood, NS.me) end },
    { name = "HornOfWinter",      matches = horn_of_winter_matches,     execute = function(ctx) return safe_cast(ACTION.HornOfWinter) end },
    { name = "DancingRuneWeapon", matches = dancing_rune_weapon_matches, execute = function(ctx) return safe_cast(ACTION.DancingRuneWeapon) end },
    { name = "Pestilence",        matches = pestilence_matches,         execute = function(ctx) return safe_cast(ACTION.Pestilence, ctx.target) end },
    { name = "IcyTouch",          matches = icy_touch_matches,          execute = function(ctx) return safe_cast(ACTION.IcyTouch, ctx.target) end },
    { name = "PlagueStrike",      matches = plague_strike_matches,      execute = function(ctx) return safe_cast(ACTION.PlagueStrike, ctx.target) end },
    { name = "DeathStrike",       matches = death_strike_matches,       execute = function(ctx) return safe_cast(ACTION.DeathStrike, ctx.target) end },
    { name = "HeartStrike",       matches = heart_strike_matches,       execute = function(ctx) return safe_cast(ACTION.HeartStrike, ctx.target) end },
    { name = "DeathCoil",         matches = death_coil_matches,         execute = function(ctx) return safe_cast(ACTION.DeathCoil, ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("blood", strategies, { get_state = build_state })
end
if NS.log then NS.log("Death Knight blood rotation registered") end

return { strategies = strategies, build_state = build_state }
