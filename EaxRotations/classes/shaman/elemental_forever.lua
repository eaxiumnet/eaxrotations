-- elemental_forever.lua — Shaman Elemental delta for WoW Forever (beta).
-- WHAT:  Forever kit deltas spliced ON TOP of the vanilla baseline: a
--        Lava Burst nuke lane hard-gated on Flame Shock being up (+20% on
--        shocked targets — the flagship keep-FS-up loop) and a Fire Nova
--        spell lane; re-registered as the "elemental" playstyle with the
--        vanilla strategies kept below.
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/shaman.md (Icy Veins class overview, 2026-09-15):
--        Lava Burst is the capstone nuke with +20% damage on Flame-Shocked
--        targets, making FS uptime a rotation-shaping dependency; Fire Nova
--        is no longer a totem — it detonates your Fire Totem as a plain
--        spell (the vanilla totem-drop semantics collapse into a spell
--        gate).
-- SAFETY: ZERO numeric spell-ID literals — the fail-closed forever audit
--        (run_forever_audit_tests.lua) resolves every ID through the bridge.
--        Forever-new spells resolve BY NAME through the DBC-derived bridge
--        module (shared/wowhead_data_bridge_spell_index_forever_sylvanas.lua,
--        pcall-required as an optional module); a nil lookup leaves the lane
--        dormant — never a guessed ID. Era-shared spells (Lava Burst is NOT
--        in the TBC-era class map — it resolves by name; Flame Shock ids
--        come from the class map action) keep every read map/bridge-driven.
--        The vanilla baseline is loaded through an intercepted registration
--        (holy_forever template) so this file edits nothing in
--        elemental_vanilla.lua, and its safe_state-backed get_state is
--        reused unchanged. New lanes sit just above the baseline's
--        "LightningBolt" nuke block — never above a defensive/utility lane.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.ShamanSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: require the vanilla file while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, fail loudly — a silently missing "elemental"
-- playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local registry = NS.rotation_registry
if not registry or type(registry.register) ~= "function" then
    error("[FOREVER] shaman elemental delta: rotation_registry unavailable", 0)
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
package.loaded["classes/shaman/elemental_vanilla"] = nil
local baseline_ok, baseline_result = pcall(require, "classes/shaman/elemental_vanilla")
registry.register = original_register
if not baseline_ok or type(baseline) ~= "table" or type(baseline.strategies) ~= "table" then
    error("[FOREVER] shaman elemental delta: baseline load failed: " .. tostring(baseline_result), 0)
end

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): both
-- lanes CAST, so both resolve through the max-rank mirror (Lava Burst
-- 1238300@60 with the +20% Flame Shock bonus in its description text;
-- Fire Nova 11307@52, the damage row). A nil lookup leaves the lane
-- dormant -- never a guessed ID. Sentinel stand-ins are seeded per mirror
-- by the battery's build_ns so mirror selection itself is pinned.
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

local LAVA_BURST_SPELL = resolve_id(by_maxrank, "Lava Burst")
local FIRE_NOVA_SPELL = resolve_id(by_maxrank, "Fire Nova")

-- Zero-literal Flame Shock debuff table: reuse the class map's rank list.
local FLAME_SHOCK_DEBUFF = SPELLS.FlameShock and SPELLS.FlameShock.ids or nil

-- ---------------------------------------------------------------------------
-- Shared helpers and Forever constants. Thresholds are menu-tunable via
-- spec_kit.setting; "estimated" values are tuned on beta day.
-- ---------------------------------------------------------------------------
local format = string.format
local EMPTY_OPTS = {}

local FOREVER_LB_MANA_FLOOR = 25
local FOREVER_NOVA_MANA_FLOOR = 30
local FOREVER_FS_MIN_REMAINS = 2   -- cast LB while FS comfortably up

local function setting(context, key, default)
    return spec_kit.setting(context, key, default)
end

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

-- ---------------------------------------------------------------------------
-- Delta lanes. Rotational deltas only in this file: the Lava Burst + Fire
-- Nova lanes sit just above the baseline's "ChainLightning" nuke (the top
-- damage lane below ElementalMastery), so they win the nuke slot when their
-- gates pass and no defensive/utility lane is shadowed.
-- ---------------------------------------------------------------------------

local delta_nuke = {}

-- Lava Burst (kit: capstone nuke, +20% on Flame-Shocked targets). Hard FS
-- dependency: only while the target's Flame Shock has comfortable remains —
-- the classic keep-FS-up loop this delta exists to enforce. Battery drives
-- FS through the debuff_remains_map on the primary target (sentinel spell
-- id for Lava Burst comes from the bridge map).
if LAVA_BURST_SPELL then
    delta_nuke[#delta_nuke + 1] = {
        name = "Forever_LavaBurstShocked",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if (s.mana_pct or 100) < setting(context, "ele_forever_lb_mana_floor", FOREVER_LB_MANA_FLOOR) then return false end
            if not FLAME_SHOCK_DEBUFF then return false end
            if (NS.debuff_remains(context.target, FLAME_SHOCK_DEBUFF) or 0)
                < setting(context, "ele_forever_fs_min_remains", FOREVER_FS_MIN_REMAINS) then return false end
            return NS.spell_ready(LAVA_BURST_SPELL, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(LAVA_BURST_SPELL, context.target,
                "[FOREVER-ELE] Lava Burst (Flame-Shocked target)")
        end,
    }
end

-- Fire Nova spell (kit: no longer a totem — detonates your live Fire Totem,
-- +15y with Elemental Reach). Above the baseline nuke block so the spell
-- semantics win while it is off cooldown in the AoE window. Dormant until
-- the bridge resolves the name.
if FIRE_NOVA_SPELL then
    delta_nuke[#delta_nuke + 1] = {
        name = "Forever_FireNovaSpell",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if (s.mana_pct or 100) < setting(context, "ele_forever_nova_mana_floor", FOREVER_NOVA_MANA_FLOOR) then return false end
            return NS.spell_ready(FIRE_NOVA_SPELL, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(FIRE_NOVA_SPELL, context.target,
                "[FOREVER-ELE] Fire Nova (detonates Fire Totem)")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: delta lanes go above the baseline's LightningBolt
-- nuke block. Re-registering the playstyle name replaces the baseline
-- wholesale — the combined list IS the "elemental" playstyle on Forever.
-- ---------------------------------------------------------------------------
local combined = {}
local nuke_inserted = false
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    if not nuke_inserted and type(st) == "table" and st.name == "ChainLightning" then
        for j = 1, #delta_nuke do combined[#combined + 1] = delta_nuke[j] end
        nuke_inserted = true
    end
    combined[#combined + 1] = st
end
if not nuke_inserted then
    for j = 1, #delta_nuke do combined[#combined + 1] = delta_nuke[j] end
end

original_register(registry, baseline.name, combined, baseline.options)
if NS.log then NS.log("Shaman elemental Forever delta registered (" ..
    #delta_nuke .. " nuke lanes over " .. #baseline.strategies ..
    " baseline lanes)") end

return combined
