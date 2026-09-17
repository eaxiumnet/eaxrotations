-- leveling_forever.lua — Paladin leveling delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 paladin leveling delta over the vanilla baseline: the HOLY
--        STRIKE strike lane — the Forever client's re-added level-6
--        Retribution trainer ability ("An instant strike that causes $m2%
--        weapon damage plus an additional $s1 as Holy damage", ladder
--        679@6 / 678@12 / 1866@20 / 680@28 / 2495@36 / 5569@44 / 10332@52 /
--        10333@60) — woven into the leveling seal/judgement loop between
--        Exorcism and Consecration.
-- WHEN:  any combat while leveling, Forever client (class loader prefers
--        _forever over _vanilla).
-- WHY:   docs/forever/kits/paladin.md: "Holy Strike from 6, Consecration
--        from 20, first spec to feel the kit at low level." The vanilla
--        leveling baseline has NO strike lane at all (its damage loop is
--        seal + Judgement + Exorcism/Hammer of Wrath + Consecration), so
--        the re-added instant strike is a pure addition to the leveling
--        pace. DBC FINDINGS (1.60.1.69893): the strike is trainer-taught
--        under Retribution; Consecration (26573@20 ... 20924@60) already has
--        a baseline lane (2+ enemies) — no delta needed. RANK NOTE: the
--        bridge mirrors carry one id per name, so the lane casts the
--        {maxrank 10333, rank-1 678} ladder — NS.get_spell_id picks the
--        highest LEARNED rank at cast time, which covers levels 12-60; the
--        @6 rank 679 and the intermediate ranks are not name-reachable
--        (recorded as a rank-ladder mirror probe for the close-out).
-- SAFETY: ZERO numeric spell-ID literals — Holy Strike resolves BY NAME
--        through the bridge mirrors; the ladder fails closed (an unlearned
--        ladder resolves nil, so the lane is dormant below its first known
--        rank). The vanilla baseline is loaded through an intercepted
--        registration (affliction/demonology_forever template) so this file
--        edits nothing in leveling_vanilla.lua and its safe_state-backed
--        get_state is reused unchanged. The lane mirrors the baseline's
--        leveling guards (context guard, combat, movement, the seal-up
--        damage-lane gate). Splice geometry: Holy Strike lands immediately
--        above the baseline's "Consecration" lane.

local NS = _G.EaxRotations
if not NS then return nil end

local leveling = require("shared/leveling_sylvanas")
local SPELLS = NS.PaladinSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: require the vanilla file while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, fail loudly — a silently missing "leveling"
-- playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local registry = NS.rotation_registry
if not registry or type(registry.register) ~= "function" then
    error("[FOREVER] paladin leveling delta: rotation_registry unavailable", 0)
end
local original_register = registry.register
local baseline = nil
registry.register = function(self, name, strategies, options)
    registry.register = original_register
    baseline = { name = name, strategies = strategies, options = options or {} }
    return true
end
-- Force baseline re-execution so its registration always reaches the
-- interceptor above, even if some earlier require() cached the module.
package.loaded["classes/paladin/leveling_vanilla"] = nil
local baseline_ok, baseline_result = pcall(require, "classes/paladin/leveling_vanilla")
registry.register = original_register
if not baseline_ok or type(baseline) ~= "table" or type(baseline.strategies) ~= "table" then
    error("[FOREVER] paladin leveling delta: baseline load failed: " .. tostring(baseline_result), 0)
end

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- strike resolves the maxrank + rank-1 mirrors into a two-rung ladder.
-- A nil lookup leaves the lane dormant -- never a guessed ID. Sentinel
-- stand-ins are seeded per mirror by the battery's build_ns so mirror
-- selection itself is pinned.
-- ---------------------------------------------------------------------------
local ok_bridge, ForeverBridge = pcall(require,
    "shared/wowhead_data_bridge_spell_index_forever_sylvanas")
if not ok_bridge or type(ForeverBridge) ~= "table" then ForeverBridge = nil end
local by_name = (ForeverBridge
    and type(ForeverBridge.spell_index_by_name_forever) == "table")
    and ForeverBridge.spell_index_by_name_forever or {}
local by_maxrank = (ForeverBridge
    and type(ForeverBridge.spell_maxrank_by_name_forever) == "table")
    and ForeverBridge.spell_maxrank_by_name_forever or {}

local function resolve_id(map, client_name)
    local id = map[client_name]
    if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then return nil end
    return id
end

local HOLY_STRIKE_MAX = resolve_id(by_maxrank, "Holy Strike")
local HOLY_STRIKE_R1 = resolve_id(by_name, "Holy Strike")
local HOLY_STRIKE = nil
if HOLY_STRIKE_MAX or HOLY_STRIKE_R1 then
    -- max-rank first: NS.get_spell_id walks the ladder and returns the
    -- highest LEARNED rung, so a level-12 paladin casts 678 and a level-60
    -- paladin 10333.
    HOLY_STRIKE = { ids = { HOLY_STRIKE_MAX, HOLY_STRIKE_R1 }, name = "HolyStrike" }
end

-- ---------------------------------------------------------------------------
-- Shared helpers. The strike is a 12s-cooldown instant (the holy-spec delta's
-- DBC note); the leveling guards mirror the baseline's file-local ones.
-- ---------------------------------------------------------------------------
local HOLY_STRIKE_OPTS = { expected_cooldown = 12 }
local context_allowed = leveling.create_context_guard()

local function has_valid_enemy(context)
    return context and context.target and context.has_valid_enemy_target ~= false
end

-- ---------------------------------------------------------------------------
-- Delta lanes. Holy Strike weaves into the damage block ahead of the AoE
-- lane (single-target strike first).
-- ---------------------------------------------------------------------------
local delta_strike = {}

if HOLY_STRIKE then
    delta_strike[#delta_strike + 1] = {
        name = "Forever_HolyStrike",
        matches = function(context, s)
            if not context_allowed(context) then return false end
            if not s or not s.target then return false end
            if not s.in_combat then return false end
            if s.is_moving then return false end
            -- Seal-up gate (damage lane): don't spend the GCD seal-less.
            if not s.has_any_seal and s.selected_seal ~= nil then return false end
            return NS.spell_ready(HOLY_STRIKE, context.target, HOLY_STRIKE_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(HOLY_STRIKE, context.target,
                "[FOREVER-LEVELING] Holy Strike")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: Holy Strike immediately above the baseline's
-- "Consecration" lane (fallback: "Seal"; then append). Re-registering the
-- playstyle name replaces the baseline wholesale — the combined list IS the
-- "leveling" playstyle on Forever.
-- ---------------------------------------------------------------------------
local STRIKE_ANCHORS = { Consecration = true, Seal = true }

local combined = {}
local strike_done = false
local function insert_strike()
    if strike_done then return end
    for j = 1, #delta_strike do combined[#combined + 1] = delta_strike[j] end
    strike_done = true
end
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name and STRIKE_ANCHORS[name] then insert_strike() end
    combined[#combined + 1] = st
end
insert_strike()

original_register(registry, baseline.name, combined, baseline.options)
if NS.log then NS.log("Paladin leveling Forever delta registered (" ..
    #delta_strike .. " holy-strike lane over " .. #baseline.strategies ..
    " baseline lanes)") end

return combined
