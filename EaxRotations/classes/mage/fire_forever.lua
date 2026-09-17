-- fire_forever.lua — Mage Fire delta for WoW Forever (beta).
-- WHAT:  Forever kit delta spliced ON TOP of the vanilla baseline: a Hot
--        Streak spending lane (crit-fueled stacking buff → fast Pyroblast)
--        inserted above the baseline's Pyroblast lane; re-registered as the
--        "fire" playstyle with the vanilla strategies kept below.
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/mage.md (Icy Veins class overview, 2026-09-15):
--        Hot Streak gives fire a 3-stack crit-fueled Pyroblast cast-cut —
--        the spec's first genuine stacking rotation mechanic. The kit also
--        names Wake of Fire's kill-chain Fire Blast, but its exact reset
--        semantics were not pinned in the transcription; that lane is
--        DELIBERATELY ABSENT until beta-day confirmation (a guessed lane is
--        worse than a missing one) — add it to this file once confirmed.
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

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.MageSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: require the vanilla file while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, fail loudly — a silently missing "fire" playstyle
-- is worse than a hard error.
-- ---------------------------------------------------------------------------
local registry = NS.rotation_registry
if not registry or type(registry.register) ~= "function" then
    error("[FOREVER] mage fire delta: rotation_registry unavailable", 0)
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
package.loaded["classes/mage/fire_vanilla"] = nil
local baseline_ok, baseline_result = pcall(require, "classes/mage/fire_vanilla")
registry.register = original_register
if not baseline_ok or type(baseline) ~= "table" or type(baseline.strategies) ~= "table" then
    error("[FOREVER] mage fire delta: baseline load failed: " .. tostring(baseline_result), 0)
end

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- Hot Streak gate resolves through the BUFF mirror (400625, the Forever
-- stacking proc per its own description text -- the 48108 baseline is the
-- legacy 2-in-a-row row). A nil lookup leaves the lane dormant -- never a
-- guessed ID. Sentinel stand-ins are seeded per mirror by the battery's
-- build_ns so mirror selection itself is pinned.
-- ---------------------------------------------------------------------------
local ok_bridge, ForeverBridge = pcall(require,
    "shared/wowhead_data_bridge_spell_index_forever_sylvanas")
if not ok_bridge or type(ForeverBridge) ~= "table" then ForeverBridge = nil end
local by_buff = (ForeverBridge
    and type(ForeverBridge.spell_buff_by_name_forever) == "table")
    and ForeverBridge.spell_buff_by_name_forever or {}

local function resolve_id(map, client_name)
    local id = map[client_name]
    if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then return nil end
    return id
end

local HOT_STREAK_BUFF = resolve_id(by_buff, "Hot Streak")

-- ---------------------------------------------------------------------------
-- Shared helpers and Forever constants. Thresholds are menu-tunable via
-- spec_kit.setting; "estimated" values are tuned on beta day.
-- ---------------------------------------------------------------------------
local format = string.format
local EMPTY_OPTS = {}

local FOREVER_HS_MANA_FLOOR = 20

local function setting(context, key, default)
    return spec_kit.setting(context, key, default)
end

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

-- ---------------------------------------------------------------------------
-- Delta lanes. The Hot Streak spend sits just above the baseline's
-- "Pyroblast" lane: same spell, strictly better cast economics while the
-- buff is up. No defensive lane is shadowed.
-- ---------------------------------------------------------------------------

local delta_pyro = {}

-- Hot Streak spend (kit: 3 crit-fueled stacks → fast Pyroblast). Gates on
-- the buff being present; the stack-count gate (spend at 3 exactly vs >=2)
-- is a beta-day upgrade once aura points are confirmed on the client.
-- Battery drives the buff through the sentinel id (buff_remains_map).
if HOT_STREAK_BUFF then
    delta_pyro[#delta_pyro + 1] = {
        name = "Forever_HotStreakPyro",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if (s.mana_pct or 100) < setting(context, "fire_forever_hs_mana_floor", FOREVER_HS_MANA_FLOOR) then return false end
            if not NS.has_player_buff(HOT_STREAK_BUFF) then return false end
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

original_register(registry, baseline.name, combined, baseline.options)
if NS.log then NS.log("Mage fire Forever delta registered (" ..
    #delta_pyro .. " hot-streak lane over " .. #baseline.strategies ..
    " baseline lanes)") end

return combined
