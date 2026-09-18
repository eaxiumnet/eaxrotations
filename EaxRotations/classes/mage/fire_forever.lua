-- fire_forever.lua — Mage Fire delta for WoW Forever (beta).
-- WHAT:  Forever kit delta spliced ON TOP of the vanilla baseline: a Hot
--        Streak spending lane (crit-fueled stacking buff → fast Pyroblast,
--        spent at the DBC-confirmed 3-stack cap) inserted above the
--        baseline's Pyroblast lane; re-registered as the "fire" playstyle
--        with the vanilla strategies kept below.
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/mage.md (Icy Veins class overview, 2026-09-13;
--        beta DBC verification 2026-09-17): Hot Streak gives fire a
--        3-stack crit-fueled Pyroblast cast-cut — SpellAuraOptions on
--        400625 pins CumulativeAura=3, SpellDuration 8 = 15s, and the aura
--        row is a casting-time spellmod (op 10) at -25% per stack, i.e.
--        Pyroblast 4.5s/3s/1.5s at 1/2/3 stacks — the spec's first genuine
--        stacking rotation mechanic. The kit also names Wake of Fire's
--        kill-chain Fire Blast, but its exact reset semantics were not
--        pinned in the transcription; that lane is DELIBERATELY ABSENT until
--        in-game confirmation (a guessed lane is worse than a missing one)
--        — add it to this file once confirmed.
-- SAFETY: ZERO numeric spell-ID literals — the fail-closed forever audit
--        (run_forever_audit_tests.lua) resolves every ID through the bridge.
--        Hot Streak resolves BY NAME through the DBC-derived bridge module
--        (shared/wowhead_data_bridge_spell_index_forever_sylvanas.lua,
--        pcall-required as an optional module); a nil lookup leaves the lane
--        dormant — never a guessed ID. The spent spell (Pyroblast) is
--        era-shared from the class map (NS.MageSpells). The vanilla baseline
--        is loaded through an intercepted registration (holy_forever
--        template) so this file edits nothing in fire_vanilla.lua, and its
--        safe_state-backed get_state is reused unchanged. The delta lane
--        sits just above the baseline's "Pyroblast" lane — never above a
--        defensive/utility lane.

local NS = _G.EaxRotations
if not NS then return nil end

local forever = require("shared/spec_kit_forever_delta")

local SPELLS = NS.MageSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: the vanilla baseline is loaded through the shared
-- forever-delta owner (spec_kit_forever_delta.lua) while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, it fails loudly there — a silently missing
-- "fire" playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local baseline = forever.forever_delta("mage fire", "classes/mage/fire_vanilla")

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- Hot Streak gate resolves through the BUFF mirror (400625, the Forever
-- stacking proc per its own description text -- the 48108 baseline is the
-- legacy 2-in-a-row row). A nil lookup leaves the lane dormant -- never a
-- guessed ID. Sentinel stand-ins are seeded per mirror by the battery's
-- build_ns so mirror selection itself is pinned.
-- ---------------------------------------------------------------------------
local mirrors = forever.mirrors()
local resolve_id = forever.resolve_id
local by_buff = mirrors.buff

local HOT_STREAK_BUFF = resolve_id(by_buff, "Hot Streak")

-- ---------------------------------------------------------------------------
-- Shared helpers and Forever constants. Thresholds are menu-tunable via
-- spec_kit.setting; "estimated" values are tuned on beta day.
-- ---------------------------------------------------------------------------
local format = string.format
local EMPTY_OPTS = {}

local FOREVER_HS_MANA_FLOOR = 20
-- DBC-confirmed: SpellAuraOptions 400625 CumulativeAura=3 (the talent 400624
-- text: "stacking up to $400625s2 times"); the aura is a casting-time
-- spellmod at -25%/stack, so a spend below the cap gives up the instant
-- window the mechanic exists for.
local FOREVER_HS_SPEND_STACKS = 3

local setting = forever.setting

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

-- ---------------------------------------------------------------------------
-- Delta lanes. The Hot Streak spend sits just above the baseline's
-- "Pyroblast" lane: same spell, strictly better cast economics while the
-- buff is up. No defensive lane is shadowed.
-- ---------------------------------------------------------------------------

local delta_pyro = {}

-- Hot Streak spend (DBC: 3 crit-fueled stacks → fast Pyroblast). Gates on
-- the buff being present AND, when the stack read is usable, on the 3-stack
-- cap so the cast-cut window is not thrown away early; a 0/nil stack read
-- fails open to the presence gate so a degraded aura API cannot stall the
-- finisher. Battery drives the buff through the sentinel id and the stack
-- count through the buff_remains_map bank.
if HOT_STREAK_BUFF then
    delta_pyro[#delta_pyro + 1] = {
        name = "Forever_HotStreakPyro",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if (s.mana_pct or 100) < setting(context, "fire_forever_hs_mana_floor", FOREVER_HS_MANA_FLOOR) then return false end
            if not NS.has_player_buff(HOT_STREAK_BUFF) then return false end
            local stacks = 0
            if NS.buff_stacks then
                stacks = NS.buff_stacks(NS.PLAYER_UNIT, { HOT_STREAK_BUFF }) or 0
            end
            if stacks > 0 and stacks < setting(context, "fire_forever_hs_spend_stacks", FOREVER_HS_SPEND_STACKS) then
                return false
            end
            return NS.spell_ready(SPELLS.Pyroblast, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Pyroblast, context.target,
                "[FOREVER-FIRE] Hot Streak fast Pyroblast")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: the delta lane goes above the baseline's Pyroblast
-- lane. Re-registering the playstyle name replaces the baseline wholesale —
-- the combined list IS the "fire" playstyle on Forever.
-- ---------------------------------------------------------------------------
local combined = {}
local pyro_inserted = false
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    if not pyro_inserted and type(st) == "table" and st.name == "Pyroblast" then
        for j = 1, #delta_pyro do combined[#combined + 1] = delta_pyro[j] end
        pyro_inserted = true
    end
    combined[#combined + 1] = st
end
if not pyro_inserted then
    for j = 1, #delta_pyro do combined[#combined + 1] = delta_pyro[j] end
end

baseline.register(combined)
if NS.log then NS.log("Mage fire Forever delta registered (" ..
    #delta_pyro .. " hot-streak lane over " .. #baseline.strategies ..
    " baseline lanes)") end

return combined
