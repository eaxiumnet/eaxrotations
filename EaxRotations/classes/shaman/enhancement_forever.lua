-- enhancement_forever.lua — Shaman Enhancement delta for WoW Forever (beta).
-- WHAT:  Forever kit deltas spliced ON TOP of the vanilla baseline: a
--        Maelstrom Weapon stack-gated Lightning Bolt weave (spend at the
--        DBC-confirmed 5-stack cap) and a re-cadenced Stormstrike core (8s
--        baseline CD) in the weave block, plus a Fire Nova spell lane (the
--        totem-detonating cast row, gated on a live Fire Totem) replacing
--        the totem-drop semantics; re-registered as the "enhancement"
--        playstyle with the vanilla strategies kept below.
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/shaman.md (Icy Veins class overview, 2026-09-15;
--        beta DBC verification 2026-09-17): Maelstrom Weapon stacks (cap 5,
--        CumulativeAura) make Lightning Bolt an instant weave filler (the
--        battlemage rework); Stormstrike drops from a 20s TBC CD to an 8s
--        baseline; Fire Nova is no longer a totem — it detonates your Fire
--        Totem as a plain spell (the vanilla totem-twist lanes collapse into
--        a spell gate). Shocks and the weapon imbues were re-verified against
--        the client: Earth Shock 10414@60 / Flame Shock 29228@60 / Frost
--        Shock 10473@58 and the class-map imbue tops (Rockbiter 16316,
--        Flametongue 16342, Windfury 16362) are the trainer-taught casts; the
--        408/1220-series name-mates are internal or variant rows (no lane
--        change).
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
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): cast
-- lanes resolve through the max-rank mirror and buff lanes through the buff
-- mirror; a nil lookup in either mirror leaves the lane dormant -- never a
-- guessed ID. Maelstrom Weapon gates on the BUFF row (408505, "Reduces the
-- cast time ... of your next Lightning Bolt" -- the 408498 baseline is the
-- talent text; SpellAuraOptions CumulativeAura=5 is the stack cap). Fire
-- Nova casts the max-rank mirror's player-cast row (408345@52, trainer-
-- taught, 520 mana, 1.5s GCD, 6s category CD -- the internal 8349/11307
-- damage rows win the raw @52 tie by lowest id and are pinned away in the
-- builder's MAXRANK_OVERRIDES). Exact client names come from
-- docs/forever/kits/shaman.md; sentinel stand-ins are seeded per mirror by
-- the battery's build_ns so mirror selection itself is pinned.
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

local MAELSTROM_WEAPON_BUFF = resolve_id(by_buff, "Maelstrom Weapon")
local FIRE_NOVA_SPELL = resolve_id(by_maxrank, "Fire Nova")

-- ---------------------------------------------------------------------------
-- Shared helpers and Forever constants. Thresholds are menu-tunable via
-- spec_kit.setting; "estimated" values are tuned on beta day.
-- ---------------------------------------------------------------------------
local format = string.format
local EMPTY_OPTS = {}

local FOREVER_MW_LB_MANA_FLOOR = 30    -- weave filler: never at starvation
-- DBC-confirmed (SpellAuraOptions 408505 CumulativeAura=5; talent row 408498
-- third effect base_points 5): Maelstrom Weapon caps at 5 stacks, each stack
-- cutting the next Lightning Bolt's cast time (aura 108, -20%/stack), so
-- spending early wastes the instant window the kit is built around.
local FOREVER_MW_SPEND_STACKS = 5
-- DBC-confirmed: RecoveryTime 8000 on Stormstrike 17364 (kit: 8s baseline).
local FOREVER_STORMSTRIKE_CD_ESTIMATE = 8
local FOREVER_FIRE_NOVA_MANA_FLOOR = 30
-- Fire totem slot (WoW totem slots: 1 fire, 2 earth, 3 water, 4 air). The
-- Forever Fire Nova detonates the ACTIVE fire totem, so the lane holds when
-- the client reports none.
local FOREVER_FIRE_TOTEM_SLOT = 1

local function setting(context, key, default)
    return spec_kit.setting(context, key, default)
end

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

-- Live-fire-totem probe (NS.get_totem_info, core_sylvanas). Fail-open when
-- the API is unavailable; the engine wrapper returns a table with
-- have_totem, while the battery's no-totem shape is the literal false.
local function fire_totem_up()
    local get_info = NS.get_totem_info
    if type(get_info) ~= "function" then return true end
    local info = get_info(FOREVER_FIRE_TOTEM_SLOT)
    if info == false then return false end
    if type(info) == "table" and info.have_totem == false then return false end
    return true
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
-- them as the top filler). Gates on the buff being present AND, when the
-- stack read is usable, on the 5-stack cap (DBC CumulativeAura=5) so the
-- instant window is never wasted on a low-stack spender; a 0/nil stack read
-- fails open to the presence gate so a degraded aura API cannot stall the
-- weave. Battery drives the buff through the sentinel id and the stack
-- count through the buff_remains_map bank.
if MAELSTROM_WEAPON_BUFF then
    delta_weave[#delta_weave + 1] = {
        name = "Forever_MaelstromWeave",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if (s.mana_pct or 100) < setting(context, "enh_forever_mw_mana_floor", FOREVER_MW_LB_MANA_FLOOR) then return false end
            if not NS.has_player_buff(MAELSTROM_WEAPON_BUFF) then return false end
            local stacks = 0
            if NS.buff_stacks then
                stacks = NS.buff_stacks(NS.PLAYER_UNIT, { MAELSTROM_WEAPON_BUFF }) or 0
            end
            if stacks > 0 and stacks < setting(context, "enh_forever_mw_spend_stacks", FOREVER_MW_SPEND_STACKS) then
                return false
            end
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

-- Fire Nova spell (kit: no longer a totem — the max-rank mirror's cast row
-- 408345 detonates your live Fire Totem, +15y with Elemental Reach). Sits
-- above the baseline's totem-twist lane so the spell semantics replace the
-- drop semantics when the bridge resolves the name; holds when no fire totem
-- is up (the detonation is a no-op without one). Dormant until then.
if FIRE_NOVA_SPELL then
    delta_nova[#delta_nova + 1] = {
        name = "Forever_FireNovaSpell",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if not fire_totem_up() then return false end
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
