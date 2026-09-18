-- leveling_forever.lua — Warrior leveling delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 warrior leveling delta over the vanilla baseline: the VICTORY
--        RUSH kill-chain sustain lane — the rune-granted ("Engrave Gloves -
--        Victory Rush", 403470) level-20 ability: "Instantly attack the
--        target causing ${1+$AP*$m3/100} damage and healing you for $s2% of
--        your maximum health. Only useable within $402975d after you kill a
--        non-trivial enemy" (30s cooldown; the enabler is the VICTORIOUS
--        buff 402975, "Follows killing an enemy").
-- WHEN:  any combat while leveling, Forever client (class loader prefers
--        _forever over _vanilla).
-- WHY:   docs/forever/kits/warrior.md: "Victory Rush kill-chain sustain
--        lane, rage-formula watch (leveling is where starvation bites
--        first)." The vanilla leveling baseline has no kill-window lane at
--        all, so the post-kill heal + damage is a pure addition to leveling
--        sustain (the classic chain-pulling rhythm). DBC FINDINGS
--        (1.60.1.69893): Victory Rush 402927 is Warrior-classed (level 20,
--        30s RecoveryTime) and resolves in all three bridge mirrors; the
--        VICTORIOUS enabler 402975 also resolves in all three mirrors
--        (aura text "Victory Rush recently activated"), so no builder pin is
--        needed. The rage-formula watch is the standing P2 probe (the
--        formula is not client-resolvable) — recorded, no lane.
-- SAFETY: ZERO numeric spell-ID literals — Victory Rush and the Victorious
--        enabler resolve BY NAME through the bridge mirrors. The ability is
--        rune-granted, so the lane is learn-gated (fail-closed for
--        un-engraved warriors). A nil lookup leaves the lane dormant —
--        never a guessed ID. The vanilla baseline is loaded through an
--        intercepted registration (affliction/demonology_forever template)
--        so this file edits nothing in leveling_vanilla.lua and its
--        safe_state-backed get_state is reused unchanged. The lane mirrors
--        the baseline's melee-lane gates (combat, target, melee range).
--        Splice geometry: Victory Rush lands immediately above the
--        baseline's "Execute" lane (fallback: "Bloodthirst"; then append).

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
-- "leveling" playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local baseline = forever.forever_delta("warrior leveling", "classes/warrior/leveling_vanilla")

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- cast and the kill-window buff both resolve through the bridge mirrors.
-- A nil lookup leaves the lane dormant -- never a guessed ID. Sentinel
-- stand-ins are seeded per mirror by the battery's build_ns so mirror
-- selection itself is pinned.
-- ---------------------------------------------------------------------------
local mirrors = forever.mirrors()
local resolve_id = forever.resolve_id
local by_name, by_maxrank, by_buff = mirrors.name, mirrors.maxrank, mirrors.buff

local VICTORY_RUSH = resolve_id(by_maxrank, "Victory Rush")
local VICTORY_RUSH_R1 = resolve_id(by_name, "Victory Rush")
local VICTORIOUS = resolve_id(by_buff, "Victorious")

-- ---------------------------------------------------------------------------
-- Shared helpers. Victory Rush's DBC cooldown is 30s; the lane is
-- learn-gated because the ability is rune-granted.
-- ---------------------------------------------------------------------------
local VICTORY_RUSH_OPTS = { expected_cooldown = 30 }

local function knows_any(id_a, id_b)
    if type(NS.is_spell_learned) ~= "function" then return false end
    for _, id in ipairs({ id_a, id_b or id_a }) do
        if type(id) == "number" then
            local ok, learned = pcall(NS.is_spell_learned, id)
            if ok and learned == true then return true end
        end
    end
    return false
end

local function victorious_up(context)
    if not VICTORIOUS or type(NS.buff_up) ~= "function" then return false end
    local ok, up = pcall(NS.buff_up, context.me, VICTORIOUS)
    return ok and up == true
end

-- ---------------------------------------------------------------------------
-- Delta lanes. Victory Rush leads the damage block: the kill window is
-- short and the heal is the point (sustain while chain-pulling).
-- ---------------------------------------------------------------------------
local delta_sustain = {}

if VICTORY_RUSH and VICTORIOUS and knows_any(VICTORY_RUSH, VICTORY_RUSH_R1) then
    delta_sustain[#delta_sustain + 1] = {
        name = "Forever_VictoryRush",
        matches = function(context, s)
            if not s or not s.in_combat then return false end
            if not s.target then return false end
            if not s.in_melee_range then return false end
            if not victorious_up(context) then return false end
            return NS.spell_ready(VICTORY_RUSH, context.target, VICTORY_RUSH_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(VICTORY_RUSH, context.target,
                "[FOREVER-LEVELING] Victory Rush (kill window)")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: Victory Rush immediately above the baseline's
-- "Execute" (fallback: "Bloodthirst"; then append). Re-registering the
-- playstyle name replaces the baseline wholesale — the combined list IS the
-- "leveling" playstyle on Forever.
-- ---------------------------------------------------------------------------
local SUSTAIN_ANCHORS = { Execute = true, Bloodthirst = true }

local combined = {}
local sustain_done = false
local function insert_sustain()
    if sustain_done then return end
    for j = 1, #delta_sustain do combined[#combined + 1] = delta_sustain[j] end
    sustain_done = true
end
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name and SUSTAIN_ANCHORS[name] then insert_sustain() end
    combined[#combined + 1] = st
end
insert_sustain()

baseline.register(combined)
if NS.log then NS.log("Warrior leveling Forever delta registered (" ..
    #delta_sustain .. " victory-rush lane over " .. #baseline.strategies ..
    " baseline lanes)") end

return combined
