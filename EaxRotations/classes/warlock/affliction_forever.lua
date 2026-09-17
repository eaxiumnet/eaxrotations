-- affliction_forever.lua — Warlock Affliction delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 affliction delta over the vanilla baseline: the new WRACK
--        amplify DoT (the kit's "Drain Hope" capstone — renamed in the beta
--        client), the engraving-granted HAUNT amplify nuke (15s CD) and
--        UNSTABLE AFFLICTION (18s DoT, which shares the one-per-warlock
--        Immolate slot — the baseline's Immolate lane is dropped while UA is
--        learned), all spliced above the baseline's dot block.
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/warlock.md (hands-on overview 2026-09-15; beta DBC
--        2026-09-17): "Drain Hope (NEW capstone): 6s channel DoT that +10%s
--        the warlock's other Shadow DoTs on the target — the new filler with
--        an amplify-window: rotation now sequences drains around dot
--        windows" and "DoTs can critically strike — THE mechanical shift".
--        DBC FINDING: **no spell named Drain Hope exists in the beta client
--        (any class)** — the kit's capstone is WRACK 1316697@40: "Tears the
--        target apart from within, dealing $s1 Shadow damage every $t sec and
--        increasing the damage they take from your other Shadow damage over
--        time effects by $s2%. Lasts $d" (6s, instant, no CD, 200 mana) and
--        Improved Drains 403511 names Wrack explicitly ("your Drain Life,
--        Drain Soul, and Wrack spells"). Haunt (403501@40 … 1293694@60,
--        15s CD, 12s amplify) and Unstable Affliction (427717@40 …
--        1242971@60, 18s, "Only one Unstable Affliction or Immolate per
--        Warlock") are ENGRAVING-granted ("Engrave Gloves - Haunt",
--        "Engrave Bracers - Unstable Affliction") — the delta gates those
--        lanes on NS.is_spell_learned (either mirror id), fail-closed to the
--        baseline when not engraved.
-- SAFETY: ZERO numeric spell-ID literals — Wrack/Haunt/Unstable Affliction
--        all resolve BY NAME through the bridge mirrors; a nil lookup leaves
--        the lane dormant — never a guessed ID. The vanilla baseline is
--        loaded through an intercepted registration (holy_forever template)
--        so this file edits nothing in affliction_vanilla.lua and its
--        safe_state-backed get_state is reused unchanged. Splice geometry:
--        the delta lanes land immediately above the baseline's "CorruptionDoT"
--        lane (fallback: above "SiphonLife"; then append) — below every
--        survival/mana/pet lane.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.WarlockSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: require the vanilla file while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, fail loudly — a silently missing "affliction"
-- playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local registry = NS.rotation_registry
if not registry or type(registry.register) ~= "function" then
    error("[FOREVER] warlock affliction delta: rotation_registry unavailable", 0)
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
package.loaded["classes/warlock/affliction_vanilla"] = nil
local baseline_ok, baseline_result = pcall(require, "classes/warlock/affliction_vanilla")
registry.register = original_register
if not baseline_ok or type(baseline) ~= "table" or type(baseline.strategies) ~= "table" then
    error("[FOREVER] warlock affliction delta: baseline load failed: " .. tostring(baseline_result), 0)
end

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- amplifies resolve through the maxrank mirror for the CAST and both mirrors
-- for the talent-known check (an engraving can grant the rank-1 row while
-- the rotation casts the top rank). A nil lookup leaves the lane dormant --
-- never a guessed ID. Sentinel stand-ins are seeded per mirror by the
-- battery's build_ns so mirror selection itself is pinned.
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

local WRACK = resolve_id(by_maxrank, "Wrack")
local HAUNT = resolve_id(by_maxrank, "Haunt")
local HAUNT_R1 = resolve_id(by_name, "Haunt")
local UNSTABLE_AFFLICTION = resolve_id(by_maxrank, "Unstable Affliction")
local UNSTABLE_AFFLICTION_R1 = resolve_id(by_name, "Unstable Affliction")

-- ---------------------------------------------------------------------------
-- Shared helpers and Forever constants. Thresholds are menu-tunable via
-- spec_kit.setting; "estimated" values are tuned on beta day.
-- ---------------------------------------------------------------------------
local EMPTY_OPTS = {}

-- DBC-confirmed: Wrack 1316697 = 6s DoT, instant, no cooldown; Haunt =
-- RecoveryTime 15000, 12s amplify; Unstable Affliction = 18s DoT, 1.5s cast.
-- The refresh window mirrors the baseline's DOT_REFRESH_WINDOW (1.5s).
local FOREVER_WRACK_REFRESH = 1.5
local FOREVER_HAUNT_CD = 15
local FOREVER_UA_REFRESH = 1.5

local function setting(context, key, default)
    return spec_kit.setting(context, key, default)
end

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

local function knows_any(id_a, id_b)
    if type(NS.is_spell_learned) ~= "function" then return false end
    for _, id in ipairs({ id_a, id_b }) do
        if type(id) == "number" then
            local ok, learned = pcall(NS.is_spell_learned, id)
            if ok and learned == true then return true end
        end
    end
    return false
end

local function dot_remains(unit, id)
    if not unit or not id or not NS.debuff_remains then return 0 end
    return NS.debuff_remains(unit, { id }) or 0
end

-- ---------------------------------------------------------------------------
-- Delta lanes. The dot block sits above the baseline's first dot lane.
-- ---------------------------------------------------------------------------

local delta_dots = {}

-- Wrack: the beta client's amplify DoT (the kit's Drain Hope). Leads the dot
-- block so the other Shadow DoTs land inside its +10% amplify window.
if WRACK then
    delta_dots[#delta_dots + 1] = {
        name = "Forever_Wrack",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if dot_remains(context.target, WRACK) > setting(context, "aff_forever_wrack_refresh", FOREVER_WRACK_REFRESH) then return false end
            return NS.spell_ready(WRACK, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(WRACK, context.target,
                "[FOREVER-AFFL] Wrack (shadow-dot amplify)")
        end,
    }
end

-- Haunt: engraving-granted amplify nuke on a 15s cooldown (12s window).
-- Dormant unless the engraving is learned (either mirror id).
if HAUNT and knows_any(HAUNT, HAUNT_R1) then
    delta_dots[#delta_dots + 1] = {
        name = "Forever_Haunt",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            return NS.spell_ready(HAUNT, context.target, { expected_cooldown = FOREVER_HAUNT_CD })
        end,
        execute = function(context)
            return NS.try_cast(HAUNT, context.target,
                "[FOREVER-AFFL] Haunt (amplify window)")
        end,
    }
end

-- Unstable Affliction: engraving-granted 18s DoT that shares the
-- one-per-warlock Immolate slot. Dormant unless the engraving is learned.
local UA_LEARNED = UNSTABLE_AFFLICTION
    and knows_any(UNSTABLE_AFFLICTION, UNSTABLE_AFFLICTION_R1) or false
if UNSTABLE_AFFLICTION and UA_LEARNED then
    delta_dots[#delta_dots + 1] = {
        name = "Forever_UnstableAffliction",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if dot_remains(context.target, UNSTABLE_AFFLICTION) > setting(context, "aff_forever_ua_refresh", FOREVER_UA_REFRESH) then return false end
            return NS.spell_ready(UNSTABLE_AFFLICTION, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(UNSTABLE_AFFLICTION, context.target,
                "[FOREVER-AFFL] Unstable Affliction")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: the dot block goes immediately above the baseline's
-- "CorruptionDoT" lane (fallback: above "SiphonLife"; then append). While
-- Unstable Affliction is learned, the baseline's "ImmolateDoT" lane is
-- DROPPED (the DBC text: "Only one Unstable Affliction or Immolate per
-- Warlock can be active on any one target") so the rotation cannot churn
-- the shared slot. Re-registering the playstyle name replaces the baseline
-- wholesale — the combined list IS the "affliction" playstyle on Forever.
-- ---------------------------------------------------------------------------
local DOT_ANCHORS = { CorruptionDoT = true, SiphonLife = true }
local DROPPED_LANES = UA_LEARNED and { ImmolateDoT = true } or {}

local combined = {}
local dots_inserted = false
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name and DROPPED_LANES[name] then
        -- UA learned: Immolate's slot is contested; skip it.
    else
        if not dots_inserted and name and DOT_ANCHORS[name] then
            for j = 1, #delta_dots do combined[#combined + 1] = delta_dots[j] end
            dots_inserted = true
        end
        combined[#combined + 1] = st
    end
end
if not dots_inserted then
    for j = 1, #delta_dots do combined[#combined + 1] = delta_dots[j] end
end

original_register(registry, baseline.name, combined, baseline.options)
if NS.log then NS.log("Warlock affliction Forever delta registered (" ..
    #delta_dots .. " dot lanes" ..
    (UA_LEARNED and ", Immolate dropped (UA slot)" or "") .. " over " ..
    #baseline.strategies .. " baseline lanes)") end

return combined
