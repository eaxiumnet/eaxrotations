-- survival_forever.lua — Hunter Survival delta for WoW Forever (beta 2026-09-17).
-- WHAT:  ADDITIVE day-1 melee-survival delta over the vanilla baseline:
--        a Mongoose Bite core lane (proc-activated counterattack, no longer
--        dodge-only — DBC: 5s category CD) and the new Strider Kick (8s CD
--        melee strike), both melee-range gated and spliced above the
--        baseline's Raptor Strike; plus a reorder of the ranged block so the
--        DBC-confirmed shared Aimed/Multi-Shot cooldown picks Multi-Shot
--        first whenever its 2+-target gate holds (the baseline offered Aimed
--        first, so the shared CD starved Multi on every multi-pull).
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/hunter.md (Icy Veins overview 2026-09-15; beta DBC
--        2026-09-17): Survival is "primarily melee now (dual-wield focused),
--        traps woven throughout" with "Expose Prey + Lacerating Strikes make
--        Mongoose Bite stronger and more frequent — Mongoose moves from
--        situational proc-lane to core" and the NEW "Strider Kick" rotational
--        melee ability. DBC: Mongoose Bite 1495@16/14271@58 with
--        CategoryRecoveryTime 5000 (class 9); Strider Kick 1317257@30,
--        "deals $s2% melee weapon damage", RecoveryTime 8000; Aimed Shot
--        19434/20904 and Multi-Shot 2643 both carry CategoryRecoveryTime 6000
--        in the SAME SpellCategory 2 — confirmed shared cooldown.
-- SAFETY: ZERO numeric spell-ID literals — Mongoose Bite is era-shared from
--        the class map (NS.HunterSpells), Strider Kick resolves BY NAME
--        through the maxrank mirror (dormant on a nil lookup), and the shot
--        reorder touches no ids. The vanilla baseline is loaded through an
--        intercepted registration (holy_forever template) so this file edits
--        nothing in survival_vanilla.lua, and its safe_state-backed
--        get_state is reused unchanged. Splice geometry: the melee block
--        lands immediately above the baseline's "RaptorStrike" lane (the
--        first melee lane, itself above the shot block) and the Multi-Shot
--        lane is re-emitted immediately above "AimedShot" — never above the
--        pet/defensive/utility head lanes.
--        NOT here (documented in the kit): Aspect of the Beast — its client
--        rows are BaseLevel 0 (13161/1299445/1299446/1299447), so the bridge
--        builder's level guard excludes the whole aspect from the mirrors and
--        the class map has no entry: a lane would be permanently dormant.
--        Traps-in-combat is a game-mechanic change (no lane change needed —
--        the baseline trap lanes simply stop being pre-combat-only).

local NS = _G.EaxRotations
if not NS then return nil end

local forever = require("shared/spec_kit_forever_delta")

local SPELLS = NS.HunterSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: the vanilla baseline is loaded through the shared
-- forever-delta owner (spec_kit_forever_delta.lua) while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, it fails loudly there — a silently missing
-- "survival" playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local baseline = forever.forever_delta("hunter survival", "classes/hunter/survival_vanilla")

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): Strider
-- Kick resolves through the maxrank mirror (1317257, the only rank row); a
-- nil lookup leaves the lane dormant -- never a guessed ID. Sentinel
-- stand-ins are seeded per mirror by the battery's build_ns so mirror
-- selection itself is pinned. Mongoose Bite is era-shared (class map).
-- ---------------------------------------------------------------------------
local mirrors = forever.mirrors()
local resolve_id = forever.resolve_id
local by_maxrank = mirrors.maxrank

local STRIDER_KICK = resolve_id(by_maxrank, "Strider Kick")

-- ---------------------------------------------------------------------------
-- Shared helpers and Forever constants. Thresholds are menu-tunable via
-- spec_kit.setting; "estimated" values are tuned on beta day.
-- ---------------------------------------------------------------------------
local EMPTY_OPTS = {}

-- DBC-confirmed: RecoveryTime 8000 on Strider Kick 1317257; Mongoose Bite's
-- counterattack rows carry CategoryRecoveryTime 5000. The melee range gate
-- mirrors the baseline's Raptor Strike/Wing Clip (6 yd).
local FOREVER_STRIDER_KICK_CD = 8
local FOREVER_MONGOOSE_CD = 5
local FOREVER_MELEE_RANGE = 6

local setting = forever.setting

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

local function melee_distance(context)
    local dist = context and (context.distance or context.target_distance)
    if type(dist) ~= "number" then return 100 end
    return dist
end

-- ---------------------------------------------------------------------------
-- Delta lanes. Melee block only: Mongoose Bite (the kit's new core, proc-
-- gated through the engine's own readiness check) then Strider Kick (8s
-- CD), immediately above the baseline's Raptor Strike.
-- ---------------------------------------------------------------------------

local delta_melee = {}

if SPELLS.MongooseBite then
    delta_melee[#delta_melee + 1] = {
        name = "Forever_MongooseBite",
        matches = function(context, s)
            if not s.in_combat then return false end
            if not has_valid_enemy(context) then return false end
            if melee_distance(context) > setting(context, "sv_forever_melee_range", FOREVER_MELEE_RANGE) then return false end
            -- The counterattack react window (dodge/parry/block, or the
            -- Expose Prey proc) is engine state: spell_ready is the only
            -- honest gate (the activation auras 5302/1310726 are classless
            -- rows the bridge cannot carry).
            return NS.spell_ready(SPELLS.MongooseBite, context.target, { expected_cooldown = FOREVER_MONGOOSE_CD })
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.MongooseBite, context.target,
                "[FOREVER-SV] Mongoose Bite (core counterattack)")
        end,
    }
end

if STRIDER_KICK then
    delta_melee[#delta_melee + 1] = {
        name = "Forever_StriderKick",
        matches = function(context, s)
            if not s.in_combat then return false end
            if not has_valid_enemy(context) then return false end
            if melee_distance(context) > setting(context, "sv_forever_melee_range", FOREVER_MELEE_RANGE) then return false end
            return NS.spell_ready(STRIDER_KICK, context.target, { expected_cooldown = FOREVER_STRIDER_KICK_CD })
        end,
        execute = function(context)
            return NS.try_cast(STRIDER_KICK, context.target,
                "[FOREVER-SV] Strider Kick")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: the melee block goes above "RaptorStrike" (fallback:
-- above "AimedShot"; then append) and the baseline's "MultiShot" lane is
-- re-emitted immediately above "AimedShot" so the shared 6s cooldown picks
-- the right shot for the target count. Re-registering the playstyle name
-- replaces the baseline wholesale — the combined list IS the "survival"
-- playstyle on Forever.
-- ---------------------------------------------------------------------------
local MELEE_ANCHORS = { RaptorStrike = true, AimedShot = true }

-- Pre-scan: the shot reorder only applies when both lanes exist (the real
-- baseline order is AimedShot THEN MultiShot, so the pair is re-emitted
-- Multi-first where the baseline's AimedShot sat).
local baseline_has_multi = false
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    if type(st) == "table" and st.name == "MultiShot" then baseline_has_multi = true break end
end

local combined = {}
local melee_inserted = false
local aimed_lane = nil
local function insert_melee()
    if melee_inserted then return end
    for j = 1, #delta_melee do combined[#combined + 1] = delta_melee[j] end
    melee_inserted = true
end
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name == "AimedShot" and baseline_has_multi then
        aimed_lane = st
    elseif name == "MultiShot" then
        insert_melee()
        combined[#combined + 1] = st
        if aimed_lane then
            combined[#combined + 1] = aimed_lane
            aimed_lane = nil
        end
    else
        if not melee_inserted and MELEE_ANCHORS[name] then insert_melee() end
        combined[#combined + 1] = st
    end
end
if aimed_lane then
    insert_melee()
    combined[#combined + 1] = aimed_lane
end
insert_melee()

baseline.register(combined)
if NS.log then NS.log("Hunter survival Forever delta registered (" ..
    #delta_melee .. " melee lanes, shot order rebalanced, over " ..
    #baseline.strategies .. " baseline lanes)") end

return combined
