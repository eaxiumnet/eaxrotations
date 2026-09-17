-- balance_forever.lua — Druid Balance delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 balance delta over the vanilla baseline: the ECLIPSE filler
--        loop. Eclipse (engraving-granted) makes Wrath charge up to 3
--        fast-cast Starfire charges, so the filler decision becomes:
--        charges up -> Starfire (the payoff), no charges -> Wrath (re-proc).
--        Both lanes sit above the baseline's StarfirePrimary/WrathFiller and
--        only exist while the engraving is learned and the charge read is
--        available — otherwise the classic priority is untouched.
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/druid.md (Icy Veins overview 2026-09-15; beta DBC
--        2026-09-17): the kit's balance section describes "Eclipse (NEW):
--        rewards alternating Wrath <-> Starfire; stacks up to 4 ... the
--        alternating-cast loop is the rotation's spine". DBC CORRECTION: the
--        client's Eclipse 408248 (granted by the "Engrave Belt - Eclipse"
--        rune) reads "Your Wrath spell reduces the cast time of your next 3
--        Starfire spells by X sec. Stores up to $408255u charges" — a
--        Wrath-procs-Starfire-haste loop, not a 4-stack alternation mechanic;
--        the charge buff row is 408255 (pinned in the builder's
--        BUFF_OVERRIDES because the name's lowest-id row is the talent text).
--        "Balance of Nature" does NOT exist in the client (only an NPC spell
--        named "Balance of Nature" 5414) — the kit's second talent claim has
--        no row. Nature's Grace ("increasing your spellcasting speed and
--        reducing your global cooldown ... for $16886d"), Dreamstate
--        ("damaging non-periodic criticals grant X% of your mana regeneration
--        while casting") and Moonkin Form ("all party members within X yards
--        have their critical strike chance increased ... exclusive with
--        Leader of the Pack") are passive auras — no lane, documented.
-- SAFETY: ZERO numeric spell-ID literals — Eclipse resolves BY NAME through
--        the bridge mirrors; nil lookups leave the lanes dormant — never a
--        guessed ID. The charge read is gated on NS.buff_stacks being a
--        function (a missing API keeps the baseline priority instead of
--        fail-open Wrath spam). The vanilla baseline is loaded through an
--        intercepted registration (holy_forever template) so this file edits
--        nothing in balance_vanilla.lua and its build_state is reused
--        unchanged. Splice geometry: both lanes land immediately above the
--        baseline's "StarfirePrimary" lane (fallback: above "WrathFiller";
--        then append) — below every defensive/utility lane.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.DruidSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: require the vanilla file while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, fail loudly — a silently missing "balance" playstyle
-- is worse than a hard error.
-- ---------------------------------------------------------------------------
local registry = NS.rotation_registry
if not registry or type(registry.register) ~= "function" then
    error("[FOREVER] druid balance delta: rotation_registry unavailable", 0)
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
package.loaded["classes/druid/balance_vanilla"] = nil
local baseline_ok, baseline_result = pcall(require, "classes/druid/balance_vanilla")
registry.register = original_register
if not baseline_ok or type(baseline) ~= "table" or type(baseline.strategies) ~= "table" then
    error("[FOREVER] druid balance delta: baseline load failed: " .. tostring(baseline_result), 0)
end

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- Eclipse talent row (the engraving gate) resolves through the maxrank
-- mirror and its charge buff through the buff mirror (the builder pin). A
-- nil lookup leaves the lanes dormant -- never a guessed ID. Sentinel
-- stand-ins are seeded per mirror by the battery's build_ns.
-- ---------------------------------------------------------------------------
local ok_bridge, ForeverBridge = pcall(require,
    "shared/wowhead_data_bridge_spell_index_forever_sylvanas")
if not ok_bridge or type(ForeverBridge) ~= "table" then ForeverBridge = nil end
local by_maxrank = (ForeverBridge
    and type(ForeverBridge.spell_maxrank_by_name_forever) == "table")
    and ForeverBridge.spell_maxrank_by_name_forever or {}
local by_buff = (ForeverBridge
    and type(ForeverBridge.spell_buff_by_name_forever) == "table")
    and ForeverBridge.spell_buff_by_name_forever or {}

local function resolve_id(map, client_name)
    local id = map[client_name]
    if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then return nil end
    return id
end

local ECLIPSE_TALENT = resolve_id(by_maxrank, "Eclipse")
local ECLIPSE_CHARGES = resolve_id(by_buff, "Eclipse")

-- ---------------------------------------------------------------------------
-- Shared helpers and Forever constants. Thresholds are menu-tunable via
-- spec_kit.setting; "estimated" values are tuned on beta day.
-- ---------------------------------------------------------------------------
local EMPTY_OPTS = {}

local FOREVER_ECLIPSE_MANA_FLOOR = 15

local function setting(context, key, default)
    return spec_kit.setting(context, key, default)
end

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

local function knows(id)
    if not id or type(NS.is_spell_learned) ~= "function" then return false end
    local ok, learned = pcall(NS.is_spell_learned, id)
    return ok and learned == true
end

-- Charges read: nil means "unreadable" (keep the baseline priority);
-- 0 means "no charges up" (time to re-proc with Wrath).
local function eclipse_charges()
    if type(NS.buff_stacks) ~= "function" or not ECLIPSE_CHARGES then return nil end
    local ok, stacks = pcall(NS.buff_stacks, NS.PLAYER_UNIT, { ECLIPSE_CHARGES })
    if not ok then return nil end
    if type(stacks) ~= "number" then return nil end
    return stacks
end

-- ---------------------------------------------------------------------------
-- Delta lanes. The pair replaces the filler decision only while the
-- engraving is learned and the charge read works.
-- ---------------------------------------------------------------------------

local delta_nukes = {}

local ECLIPSE_ACTIVE = ECLIPSE_TALENT and ECLIPSE_CHARGES and knows(ECLIPSE_TALENT)

if ECLIPSE_ACTIVE then
    delta_nukes[#delta_nukes + 1] = {
        name = "Forever_EclipseStarfire",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if s.is_moving or context.is_moving then return false end
            if (s.mana_pct or 100) < setting(context, "balance_forever_mana_floor", FOREVER_ECLIPSE_MANA_FLOOR) then return false end
            local charges = eclipse_charges()
            if not charges or charges <= 0 then return false end
            return NS.spell_ready(SPELLS.Starfire, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Starfire, context.target,
                "[FOREVER-BAL] Eclipse-empowered Starfire")
        end,
    }

    delta_nukes[#delta_nukes + 1] = {
        name = "Forever_EclipseWrath",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if s.is_moving or context.is_moving then return false end
            if (s.mana_pct or 100) < setting(context, "balance_forever_mana_floor", FOREVER_ECLIPSE_MANA_FLOOR) then return false end
            local charges = eclipse_charges()
            if charges == nil or charges > 0 then return false end
            return NS.spell_ready(SPELLS.Wrath, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Wrath, context.target,
                "[FOREVER-BAL] Eclipse re-proc Wrath")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: the pair lands immediately above the baseline's
-- "StarfirePrimary" lane (fallback: above "WrathFiller"; then append).
-- Re-registering the playstyle name replaces the baseline wholesale.
-- ---------------------------------------------------------------------------
local ANCHORS = { StarfirePrimary = true, WrathFiller = true }

local combined = {}
local nukes_inserted = false
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    if not nukes_inserted and type(st) == "table" and ANCHORS[st.name] then
        for j = 1, #delta_nukes do combined[#combined + 1] = delta_nukes[j] end
        nukes_inserted = true
    end
    combined[#combined + 1] = st
end
if not nukes_inserted then
    for j = 1, #delta_nukes do combined[#combined + 1] = delta_nukes[j] end
end

original_register(registry, baseline.name, combined, baseline.options)
if NS.log then NS.log("Druid balance Forever delta registered (" ..
    #delta_nukes .. " eclipse nuke lanes over " .. #baseline.strategies ..
    " baseline lanes)") end

return combined
