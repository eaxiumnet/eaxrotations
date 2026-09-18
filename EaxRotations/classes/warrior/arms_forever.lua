-- arms_forever.lua — Warrior Arms delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 arms delta over the vanilla baseline: the new trainer-taught
--        SPEARING STRIKE (encounter-gated nuke: +123% weapon damage against
--        Giants/Dragonkin, dismounts mounted targets) spliced above Mortal
--        Strike, plus a Slam-lane REPLACEMENT for Improved Slam (the talent
--        removes the swing penalty AND cuts the cast/GCD, so the baseline's
--        swing-window gate would suppress most of the 15s-cooldown casts).
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/warrior.md (Icy Veins overview 2026-09-13; beta DBC
--        2026-09-17): arms "**Spearing Strike** (NEW): encounter-gated nuke
--        lane (fight-type context) + PvP dismount tool" and class-wide
--        "**Slam: baseline 15s cooldown** ... interacts with Arms' Improved
--        Slam". DBC: Spearing Strike 1310222@1 (class 4, trainer-taught under
--        Arms) = "A brutal attack that deals 41% weapon damage. Deals an
--        additional ${41*3}% weapon damage against Giants, Dragonkin, and
--        mounted targets" (15 rage; the kit's "40%/+80%" is corrected to
--        41%/123% by the client text); Improved Slam 12862 = "Reduces the
--        global cooldown and cast time of your Slam ability ... In addition,
--        Slam no longer interrupts your melee swing time"; Slam 1464/11605
--        CategoryRecoveryTime 15000 (confirmed in the fury pass).
--        BLOODTHRILL (1289682: "melee attacks against targets afflicted by
--        your Rend have a 16% chance to activate your Overpower ability") and
--        SUDDEN DEATH (440113: "allows one use of Execute regardless of the
--        target's health state") need NO lane here: the baseline's Overpower
--        lane already keys off the engine's readiness state (which includes
--        the activation), and an ungated Execute lane would shadow the whole
--        rotation if the engine's readiness did NOT include the proc — both
--        are recorded as in-game probes instead of guessed gates.
-- SAFETY: ZERO numeric spell-ID literals — Spearing Strike resolves BY NAME
--        through the maxrank mirror (dormant without it); Improved Slam (the
--        talent gate) through the same mirror; the casts come from the class
--        map and the baseline's own state. The vanilla baseline is loaded
--        through an intercepted registration (holy_forever template) so this
--        file edits nothing in arms_vanilla.lua and its safe_state-backed
--        get_state is reused unchanged. Splice geometry: Spearing Strike
--        lands immediately above the baseline's "MortalStrike" lane (fallback:
--        above "Rend"; then append); the Slam replacement takes the baseline
--        lane's exact position. No defensive/utility lane is shadowed.

local NS = _G.EaxRotations
if not NS then return nil end

local forever = require("shared/spec_kit_forever_delta")

local SPELLS = NS.WarriorSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: the vanilla baseline is loaded through the shared
-- forever-delta owner (spec_kit_forever_delta.lua) while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, it fails loudly there — a silently missing
-- "arms" playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local baseline = forever.forever_delta("warrior arms", "classes/warrior/arms_vanilla")

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- Spearing Strike cast and the Improved Slam talent row resolve through the
-- maxrank mirror; nil lookups leave their lane/branch dormant -- never a
-- guessed ID. Sentinel stand-ins are seeded per mirror by the battery.
-- ---------------------------------------------------------------------------
local mirrors = forever.mirrors()
local resolve_id = forever.resolve_id
local by_maxrank = mirrors.maxrank

local SPEARING_STRIKE = resolve_id(by_maxrank, "Spearing Strike")
local IMPROVED_SLAM = resolve_id(by_maxrank, "Improved Slam")

-- ---------------------------------------------------------------------------
-- Shared helpers and Forever constants. Thresholds are menu-tunable via
-- spec_kit.setting; "estimated" values are tuned on beta day.
-- ---------------------------------------------------------------------------
local EMPTY_OPTS = {}

-- Creature types the client text names (Giant = 5, Dragonkin = 2 in the
-- client's CreatureType enum; mounted has no API signal and is skipped).
local SPEARING_TYPES = { [2] = true, [5] = true }
local FOREVER_SPEARING_RAGE = 15
local FOREVER_SLAM_RAGE = 15     -- the baseline's SLAM_RAGE

local setting = forever.setting

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

local function knows(id)
    if not id or type(NS.is_spell_learned) ~= "function" then return false end
    local ok, learned = pcall(NS.is_spell_learned, id)
    return ok and learned == true
end

local function target_creature_type(unit)
    if not unit or not unit.get_creature_type then return nil end
    local ok, value = pcall(unit.get_creature_type, unit)
    return ok and value or nil
end

-- ---------------------------------------------------------------------------
-- Delta lanes. Spearing Strike above the core spender; the Slam replacement
-- takes the baseline lane's slot when the talent is learned.
-- ---------------------------------------------------------------------------

local delta_nuke = {}

if SPEARING_STRIKE then
    delta_nuke[#delta_nuke + 1] = {
        name = "Forever_SpearingStrike",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            local ctype = target_creature_type(context.target)
            if not (ctype and SPEARING_TYPES[ctype]) then return false end
            if (s.rage or 0) < setting(context, "arms_forever_spearing_rage", FOREVER_SPEARING_RAGE) then return false end
            return NS.spell_ready(SPEARING_STRIKE, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(SPEARING_STRIKE, context.target,
                "[FOREVER-ARMS] Spearing Strike (Giant/Dragonkin)")
        end,
    }
end

local delta_slam = {}

-- Improved Slam: the swing penalty is gone ("Slam no longer interrupts your
-- melee swing time"), so the baseline's "swing lands in (0.7, 1.5]" window
-- must not gate the 15s-cooldown cast. Same rage and priority guards, no
-- swing window.
if IMPROVED_SLAM and knows(IMPROVED_SLAM) then
    delta_slam[#delta_slam + 1] = {
        name = "Forever_SlamWeave",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if s.is_moving then return false end
            if (s.rage or 0) < setting(context, "arms_forever_slam_rage", FOREVER_SLAM_RAGE) then return false end
            if s.overpower_ready then return false end
            return NS.spell_ready(SPELLS.Slam, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Slam, context.target,
                "[FOREVER-ARMS] Slam (Improved Slam weave)")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: Spearing Strike goes immediately above "MortalStrike"
-- (fallback: above "Rend"; then append); the baseline's "Slam" lane is
-- DROPPED and the replacement takes its position when Improved Slam is
-- learned. Re-registering the playstyle name replaces the baseline wholesale.
-- ---------------------------------------------------------------------------
local NUKE_ANCHORS = { MortalStrike = true, Rend = true }
local REPLACED_LANES = (#delta_slam > 0) and { Slam = true } or {}

local combined = {}
local nuke_inserted = false
local slam_inserted = false
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name == "Slam" and REPLACED_LANES.Slam then
        for j = 1, #delta_slam do combined[#combined + 1] = delta_slam[j] end
        slam_inserted = true
    elseif not (name and REPLACED_LANES[name]) then
        if not nuke_inserted and name and NUKE_ANCHORS[name] then
            for j = 1, #delta_nuke do combined[#combined + 1] = delta_nuke[j] end
            nuke_inserted = true
        end
        combined[#combined + 1] = st
    end
end
if not nuke_inserted then
    for j = 1, #delta_nuke do combined[#combined + 1] = delta_nuke[j] end
end
if not slam_inserted then
    for j = 1, #delta_slam do combined[#combined + 1] = delta_slam[j] end
end

baseline.register(combined)
if NS.log then NS.log("Warrior arms Forever delta registered (" ..
    #delta_nuke .. " spearing + " .. #delta_slam .. " slam lane" ..
    ((#delta_slam > 0) and ", baseline Slam replaced" or "") .. " over " ..
    #baseline.strategies .. " baseline lanes)") end

return combined
