-- enhancement_forever.lua — Shaman Enhancement delta for WoW Forever (beta).
-- WHAT:  Forever kit deltas spliced ON TOP of the vanilla baseline: a
--        Maelstrom Weapon stack-gated Lightning Bolt weave and a re-cadenced
--        Stormstrike core (8s baseline CD) in the weave block, plus a Fire
--        Nova spell lane replacing the totem-drop semantics; re-registered
--        as the "enhancement" playstyle with the vanilla strategies kept
--        below.
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/shaman.md (Icy Veins class overview, 2026-09-15):
--        Maelstrom Weapon stacks make Lightning Bolt an instant weave filler
--        (the battlemage rework); Stormstrike drops from a 20s TBC CD to an
--        8s baseline; Fire Nova is no longer a totem — it detonates your Fire
--        Totem as a plain spell (the vanilla totem-twist lanes collapse into
--        a spell gate).
-- SAFETY: ZERO numeric spell-ID literals — the fail-closed forever audit
--        (run_forever_audit_tests.lua) resolves every ID through the bridge.
--        Forever-new spells resolve BY NAME through the DBC-derived bridge
--        module (shared/wowhead_data_bridge_spell_index_forever_sylvanas.lua,
--        pcall-required as an optional module); a nil lookup leaves the lane
--        dormant — never a guessed ID. Era-shared spells (Stormstrike,
--        Lightning Bolt) come from the class map (NS.ShamanSpells). The
--        vanilla baseline is loaded through an intercepted registration
--        (holy_forever template) so this file edits nothing in
--        enhancement_vanilla.lua, and its safe_state-backed get_state is
--        reused unchanged. New lanes sit just above the baseline's
--        "LightningBolt" filler block — never above a defensive/utility lane.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.ShamanSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: require the vanilla file while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, fail loudly — a silently missing "enhancement"
-- playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local registry = NS.rotation_registry
if not registry or type(registry.register) ~= "function" then
    error("[FOREVER] shaman enhancement delta: rotation_registry unavailable", 0)
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
package.loaded["classes/shaman/enhancement_vanilla"] = nil
local baseline_ok, baseline_result = pcall(require, "classes/shaman/enhancement_vanilla")
registry.register = original_register
if not baseline_ok or type(baseline) ~= "table" or type(baseline.strategies) ~= "table" then
    error("[FOREVER] shaman enhancement delta: baseline load failed: " .. tostring(baseline_result), 0)
end

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- bridge is empty until the beta DBC lands, so before beta day the
-- bridge-resolved lanes stay dormant. Exact client names come from
-- docs/forever/kits/shaman.md; sentinel stand-ins for these names are
-- seeded by the battery's build_ns so the lanes are observable (Pattern 17)
-- today and byte-identical in production once the real bridge arrives.
-- ---------------------------------------------------------------------------
local ok_bridge, ForeverBridge = pcall(require,
    "shared/wowhead_data_bridge_spell_index_forever_sylvanas")
if not ok_bridge or type(ForeverBridge) ~= "table" then ForeverBridge = nil end
local by_name = (ForeverBridge
    and type(ForeverBridge.spell_index_by_name_forever) == "table")
    and ForeverBridge.spell_index_by_name_forever or {}

local function resolve_id(client_name)
    local id = by_name[client_name]
    if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then return nil end
    return id
end

local MAELSTROM_WEAPON_BUFF = resolve_id("Maelstrom Weapon")
local FIRE_NOVA_SPELL = resolve_id("Fire Nova")

-- ---------------------------------------------------------------------------
-- Shared helpers and Forever constants. Thresholds are menu-tunable via
-- spec_kit.setting; "estimated" values are tuned on beta day.
-- ---------------------------------------------------------------------------
local format = string.format
local EMPTY_OPTS = {}

local FOREVER_MW_LB_MANA_FLOOR = 30    -- weave filler: never at starvation
local FOREVER_STORMSTRIKE_CD_ESTIMATE = 8  -- kit: 8s baseline (was 20s)
local FOREVER_FIRE_NOVA_MANA_FLOOR = 30

local function setting(context, key, default)
    return spec_kit.setting(context, key, default)
end

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

-- ---------------------------------------------------------------------------
-- Delta lanes. Rotational deltas only in this file: the weave block sits
-- just above the baseline's "Stormstrike" lane (SS core above baseline SS,
-- MW weave above SS core — the mock-first dispatch order), and the Fire
-- Nova lane just above the baseline's "FireNovaReplacement" totem gate so
-- the spell semantics win when resolved. No defensive lane is shadowed.
-- ---------------------------------------------------------------------------

local delta_weave = {}

-- Maelstrom Weapon weave (kit: stacks make Lightning Bolt instant — spend
-- them as the top filler). Gates on the buff being present; the stack-count
-- threshold (spend at N stacks) is a beta-day upgrade once aura points are
-- confirmed on the client. Battery drives the buff through the sentinel id.
if MAELSTROM_WEAPON_BUFF then
    delta_weave[#delta_weave + 1] = {
        name = "Forever_MaelstromWeave",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if (s.mana_pct or 100) < setting(context, "enh_forever_mw_mana_floor", FOREVER_MW_LB_MANA_FLOOR) then return false end
            if not NS.has_player_buff(MAELSTROM_WEAPON_BUFF) then return false end
            return NS.spell_ready(SPELLS.LightningBolt, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.LightningBolt, context.target,
                "[FOREVER-ENH] Maelstrom Weapon Lightning Bolt weave")
        end,
    }
end

-- Stormstrike core re-cadence (kit: 8s baseline CD makes SS rotational, not
-- a burst pickup). Era-shared spell — always resolvable; the 8s cadence is
-- enforced by the baseline's expected_cooldown read, this lane guarantees
-- the cast happens whenever ready and a target exists (never outranks
-- totems/utility — it is inserted into the weave block).
delta_weave[#delta_weave + 1] = {
    name = "Forever_StormstrikeCore",
    matches = function(context, s)
        if not has_valid_enemy(context) then return false end
        return NS.spell_ready(SPELLS.Stormstrike, context.target,
            { expected_cooldown = FOREVER_STORMSTRIKE_CD_ESTIMATE })
    end,
    execute = function(context)
        return NS.try_cast(SPELLS.Stormstrike, context.target,
            "[FOREVER-ENH] Stormstrike core (8s cadence)")
    end,
}

local delta_nova = {}

-- Fire Nova spell (kit: no longer a totem — detonates your live Fire Totem,
-- +15y with Elemental Reach). Sits above the baseline's totem-twist lane so
-- the spell semantics replace the drop semantics when the bridge resolves
-- the name. Dormant until then.
if FIRE_NOVA_SPELL then
    delta_nova[#delta_nova + 1] = {
        name = "Forever_FireNovaSpell",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if (s.mana_pct or 100) < setting(context, "enh_forever_nova_mana_floor", FOREVER_FIRE_NOVA_MANA_FLOOR) then return false end
            return NS.spell_ready(FIRE_NOVA_SPELL, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(FIRE_NOVA_SPELL, context.target,
                "[FOREVER-ENH] Fire Nova (detonates Fire Totem)")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: the Fire Nova lane goes above the baseline's
-- FireNovaReplacement; the weave lanes go above the baseline's LightningBolt
-- filler. Re-registering the playstyle name replaces the baseline wholesale
-- — the combined list IS the "enhancement" playstyle on Forever.
-- ---------------------------------------------------------------------------
local combined = {}
local nova_inserted = false
local weave_inserted = false
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    if not nova_inserted and type(st) == "table" and st.name == "FireNovaReplacement" then
        for j = 1, #delta_nova do combined[#combined + 1] = delta_nova[j] end
        nova_inserted = true
    end
    if not weave_inserted and type(st) == "table" and st.name == "Stormstrike" then
        for j = 1, #delta_weave do combined[#combined + 1] = delta_weave[j] end
        weave_inserted = true
    end
    combined[#combined + 1] = st
end
if not nova_inserted then
    for j = 1, #delta_nova do combined[#combined + 1] = delta_nova[j] end
end
if not weave_inserted then
    for j = 1, #delta_weave do combined[#combined + 1] = delta_weave[j] end
end

original_register(registry, baseline.name, combined, baseline.options)
if NS.log then NS.log("Shaman enhancement Forever delta registered (" ..
    #delta_nova .. " nova + " .. #delta_weave .. " weave lanes over " ..
    #baseline.strategies .. " baseline lanes)") end

return combined
