-- bear_forever.lua — Druid Feral Bear delta for WoW Forever (beta 2026-09-17).
-- WHAT:  ADDITIVE day-1 bear rotation over the vanilla baseline: Berserk
--        (the form-branched 3-min CD — bear branch removes the Mangle
--        cooldown and makes it strike up to 4 targets), Mangle (6s CD nuke,
--        15 rage) and Lacerate (threat bleed, 5 stacks / 15s, 15 rage)
--        inserted above the baseline's Swipe/Maul lanes, so Maul degrades
--        to the rage dump it is supposed to be.
-- WHEN:  combat, bear form, Forever client (class loader prefers _forever).
-- WHY:   docs/forever/kits/druid.md (Icy Veins overview 2026-09-15; beta DBC
--        2026-09-17): "Mangle (talent) + Lacerate (trainer): bear finally
--        has a rotation — Mangle (6s CD nuke), Lacerate (threat + bleed,
--        stacks to 5), both cost rage; Maul demoted to rage dump." The DBC
--        confirms the shapes: Mangle 407995@25 … 1238073@60 with
--        CategoryRecoveryTime 6000 and a threat effect row; Lacerate
--        414644@42 / 1235826@50 / 1235827@58 with CumulativeAura 5,
--        SpellDuration 8 = 15s and a bleed aura row; Berserk 417141 (bear
--        branch op 11 −100% Mangle cooldown, op 17 +3 targets).
-- SAFETY: ZERO numeric spell-ID literals — the fail-closed forever audit
--        (run_forever_audit_tests.lua) resolves every ID through the bridge.
--        Berserk and Mangle resolve BY NAME through the maxrank mirror
--        (Mangle's max rank is the druid 1238073@60; the TBC class-map
--        MangleBear ids 33987/33986/33878 are absent from this client, so a
--        class-map lane would be dead in production), Lacerate's cast and
--        debuff id through the same mirror, with the stack read via
--        NS.debuff_stacks (Pattern 11). A nil lookup leaves the lane dormant
--        — never a guessed ID. The vanilla baseline is loaded through an
--        intercepted registration (holy_forever template) so this file edits
--        nothing in bear_vanilla.lua, and its safe_state-backed get_state is
--        reused unchanged. Splice geometry: the three delta lanes land just
--        above the baseline's "SwipeAoE" rotational block — below every
--        defensive/utility/taunt lane — so no emergency cast is shadowed.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.DruidSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: require the vanilla file while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, fail loudly — a silently missing "bear" playstyle is
-- worse than a hard error.
-- ---------------------------------------------------------------------------
local registry = NS.rotation_registry
if not registry or type(registry.register) ~= "function" then
    error("[FOREVER] druid bear delta: rotation_registry unavailable", 0)
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
package.loaded["classes/druid/bear_vanilla"] = nil
local baseline_ok, baseline_result = pcall(require, "classes/druid/bear_vanilla")
registry.register = original_register
if not baseline_ok or type(baseline) ~= "table" or type(baseline.strategies) ~= "table" then
    error("[FOREVER] druid bear delta: baseline load failed: " .. tostring(baseline_result), 0)
end

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- three casts resolve through the maxrank mirror; Lacerate's debuff probes
-- use the same id (the client's Lacerate rows ARE the applied bleed rows,
-- like the seals). A nil lookup leaves the lane dormant -- never a guessed
-- ID. Sentinel stand-ins are seeded per mirror by the battery's build_ns so
-- mirror selection itself is pinned.
-- ---------------------------------------------------------------------------
local ok_bridge, ForeverBridge = pcall(require,
    "shared/wowhead_data_bridge_spell_index_forever_sylvanas")
if not ok_bridge or type(ForeverBridge) ~= "table" then ForeverBridge = nil end
local by_maxrank = (ForeverBridge
    and type(ForeverBridge.spell_maxrank_by_name_forever) == "table")
    and ForeverBridge.spell_maxrank_by_name_forever or {}

local function resolve_id(map, client_name)
    local id = map[client_name]
    if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then return nil end
    return id
end

local BERSERK = resolve_id(by_maxrank, "Berserk")
local MANGLE_BEAR = resolve_id(by_maxrank, "Mangle")
local LACERATE = resolve_id(by_maxrank, "Lacerate")

-- ---------------------------------------------------------------------------
-- Shared helpers and Forever constants. Thresholds are menu-tunable via
-- spec_kit.setting; "estimated" values are tuned on beta day.
-- ---------------------------------------------------------------------------
local format = string.format
local EMPTY_OPTS = {}
local SELF_OPTS = { skip_range = true }

-- DBC-confirmed: CategoryRecoveryTime 6000 on every Mangle rank, RecoveryTime
-- 180000 (15s aura) on the druid Berserk 417141.
local FOREVER_MANGLE_CD = 6
local FOREVER_BERSERK_CD = 180
local FOREVER_MANGLE_RAGE = 15
local FOREVER_LACERATE_RAGE = 15
-- DBC-confirmed: Lacerate CumulativeAura 5, SpellDuration 8 = 15s. Refresh
-- when the stack is short or the bleed is inside this window.
local FOREVER_LACERATE_STACKS = 5
local FOREVER_LACERATE_REFRESH = 4

local function setting(context, key, default)
    return spec_kit.setting(context, key, default)
end

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

local function lacerate_stacks(unit)
    if not unit or not NS.debuff_stacks then return 0 end
    return NS.debuff_stacks(unit, { LACERATE }) or 0
end

-- ---------------------------------------------------------------------------
-- Delta lanes. Rotational deltas only: Berserk (cooldown) first, then the
-- Mangle nuke, then the Lacerate stack builder — all just above the
-- baseline's AoE/cleave Swipe block, so the taunt/defensive head lanes keep
-- first refusal.
-- ---------------------------------------------------------------------------

local delta_block = {}

-- Berserk-bear (DBC: 180s CD, 15s; bear branch removes the Mangle cooldown
-- and makes it strike up to 4 targets; fear immunity). Fires on the long-CD
-- gate with Mangle's rage in hand so the window is not wasted; the AoE
-- payoff applies automatically on multi-target pulls.
if BERSERK then
    delta_block[#delta_block + 1] = {
        name = "Forever_BerserkBear",
        matches = function(context, s)
            if not s.is_bear then return false end
            if not context or not context.in_combat then return false end
            if not has_valid_enemy(context) then return false end
            if (s.rage or 0) < setting(context, "bear_forever_berserk_rage", FOREVER_MANGLE_RAGE) then return false end
            if NS.should_use_long_cd and not NS.should_use_long_cd(context, FOREVER_BERSERK_CD) then return false end
            return NS.spell_ready(BERSERK, NS.PLAYER_UNIT, SELF_OPTS)
        end,
        execute = function()
            return NS.try_cast(BERSERK, NS.PLAYER_UNIT,
                "[FOREVER-BEAR] Berserk (Mangle CD removed, 4 targets)", SELF_OPTS)
        end,
    }
end

-- Mangle (bear): the 6s-CD nuke that replaced Maul-spam as the core. Above
-- the Swipe block so it lands on cooldown; the class-map MangleBear action
-- cannot be used here — its TBC ids are absent from this client.
if MANGLE_BEAR then
    delta_block[#delta_block + 1] = {
        name = "Forever_MangleBear",
        matches = function(context, s)
            if not s.is_bear then return false end
            if not has_valid_enemy(context) then return false end
            if (s.rage or 0) < setting(context, "bear_forever_mangle_rage", FOREVER_MANGLE_RAGE) then return false end
            return NS.spell_ready(MANGLE_BEAR, context.target, { expected_cooldown = FOREVER_MANGLE_CD })
        end,
        execute = function(context)
            return NS.try_cast(MANGLE_BEAR, context.target,
                "[FOREVER-BEAR] Mangle")
        end,
    }
end

-- Lacerate: build to the DBC-confirmed 5 stacks and refresh before the 15s
-- bleed expires. Requires the combat context (the vanilla file's bear form
-- gates apply to the baseline lanes; this one is additive above them).
if LACERATE then
    delta_block[#delta_block + 1] = {
        name = "Forever_Lacerate",
        matches = function(context, s)
            if not s.is_bear then return false end
            if not context or not context.in_combat then return false end
            if not has_valid_enemy(context) then return false end
            if (s.rage or 0) < setting(context, "bear_forever_lacerate_rage", FOREVER_LACERATE_RAGE) then return false end
            local stacks = lacerate_stacks(context.target)
            local remains = NS.debuff_remains and NS.debuff_remains(context.target, { LACERATE }) or 0
            if stacks >= setting(context, "bear_forever_lacerate_stacks", FOREVER_LACERATE_STACKS)
                and remains > setting(context, "bear_forever_lacerate_refresh", FOREVER_LACERATE_REFRESH) then
                return false
            end
            return NS.spell_ready(LACERATE, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(LACERATE, context.target,
                format("[FOREVER-BEAR] Lacerate (%d stacks)", lacerate_stacks(context.target)))
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: the delta block lands just above the baseline's
-- "SwipeAoE" rotational block (fallback: above "Maul"; then append). Maul
-- itself is untouched — with Mangle on cooldown and Lacerate stacked above
-- it, the baseline's rage-gated Maul lane is the dump by construction.
-- Re-registering the playstyle name replaces the baseline wholesale — the
-- combined list IS the "bear" playstyle on Forever.
-- ---------------------------------------------------------------------------
local ANCHORS = { SwipeAoE = true, Maul = true }

local combined = {}
local block_inserted = false
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    if not block_inserted and type(st) == "table" and ANCHORS[st.name] then
        for j = 1, #delta_block do combined[#combined + 1] = delta_block[j] end
        block_inserted = true
    end
    combined[#combined + 1] = st
end
if not block_inserted then
    for j = 1, #delta_block do combined[#combined + 1] = delta_block[j] end
end

original_register(registry, baseline.name, combined, baseline.options)
if NS.log then NS.log("Druid bear Forever delta registered (" ..
    #delta_block .. " lanes over " .. #baseline.strategies ..
    " baseline lanes)") end

return combined
