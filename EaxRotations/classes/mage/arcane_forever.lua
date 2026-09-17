-- arcane_forever.lua — Mage Arcane delta for WoW Forever (beta).
-- WHAT:  Forever kit delta spliced ON TOP of the vanilla baseline: the
--        Arcane Blast 4-stack spam block (the stack dies if ANY other spell
--        casts — so the block skips when Arcane Missiles is in a cusp
--        window) plus a Missile Barrage fast-AM spending lane; re-registered
--        as the "arcane" playstyle with the vanilla strategies kept below.
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/mage.md (Icy Veins class overview, 2026-09-15):
--        Arcane Blast gains a 4-stack damage buff that dies on ANY other
--        spell cast — the first genuinely new rotation shape for arcane.
--        Missile Barrage proc makes the next Arcane Missiles instant — a
--        spending lane for the proc window.
-- SAFETY: ZERO numeric spell-ID literals — the fail-closed forever audit
--        (run_forever_audit_tests.lua) resolves every ID through the bridge.
--        Arcane Blast / Missile Barrage resolve BY NAME through the
--        DBC-derived bridge module
--        (shared/wowhead_data_bridge_spell_index_forever_sylvanas.lua,
--        pcall-required as an optional module); a nil lookup leaves the lane
--        dormant — never a guessed ID. Arcane Missiles is era-shared from
--        the class map (NS.MageSpells). The vanilla baseline is loaded
--        through an intercepted registration (holy_forever template) so
--        this file edits nothing in arcane_vanilla.lua, and its
--        safe_state-backed get_state is reused unchanged. Splice geometry:
--        the AB-spam block sits BELOW "ArcaneMissiles" (baseline lane #2,
--        can_cast-vetoed) so the veto cannot shadow the loop, and ABOVE
--        "Frostbolt" (lane #3) so the stack loop outranks the filler —
--        everything below the baseline's defensive head lanes.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.MageSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: require the vanilla file while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, fail loudly — a silently missing "arcane" playstyle
-- is worse than a hard error.
-- ---------------------------------------------------------------------------
local registry = NS.rotation_registry
if not registry or type(registry.register) ~= "function" then
    error("[FOREVER] mage arcane delta: rotation_registry unavailable", 0)
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
package.loaded["classes/mage/arcane_vanilla"] = nil
local baseline_ok, baseline_result = pcall(require, "classes/mage/arcane_vanilla")
registry.register = original_register
if not baseline_ok or type(baseline) ~= "table" or type(baseline.strategies) ~= "table" then
    error("[FOREVER] mage arcane delta: baseline load failed: " .. tostring(baseline_result), 0)
end

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- Arcane Blast STACK check resolves through the buff mirror (400573, the
-- stack-aura rows) while the CAST resolves through the max-rank mirror
-- (1239700@60, the top damage rank -- the nuke description even references
-- the 400573 stack rows by id); Missile Barrage gates on the buff mirror
-- (400589, the proc buff triggered by the 400588 talent row). A nil lookup
-- in either mirror leaves the lane dormant -- never a guessed ID. Sentinel
-- stand-ins are seeded per mirror by the battery's build_ns so mirror
-- selection itself is pinned.
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

local ARCANE_BLAST_BUFF = resolve_id(by_buff, "Arcane Blast")
local ARCANE_BLAST_NUKE = resolve_id(by_maxrank, "Arcane Blast")
local MISSILE_BARRAGE_BUFF = resolve_id(by_buff, "Missile Barrage")

-- ---------------------------------------------------------------------------
-- Shared helpers and Forever constants. Thresholds are menu-tunable via
-- spec_kit.setting; "estimated" values are tuned on beta day.
-- ---------------------------------------------------------------------------
local format = string.format
local EMPTY_OPTS = {}

local FOREVER_AB_MANA_FLOOR = 30
local FOREVER_AM_CUSP_SECONDS = 2   -- AM within N s of ready: hold the loop
local FOREVER_MB_MANA_FLOOR = 20

local function setting(context, key, default)
    return spec_kit.setting(context, key, default)
end

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

-- ---------------------------------------------------------------------------
-- Delta lanes. Splice geometry (see header): the AB-spam block lands BELOW
-- the baseline's "ArcaneMissiles" lane (its can_cast veto must never shadow
-- the loop) and ABOVE "Frostbolt" (the filler); the Missile Barrage spend
-- lands ABOVE "ArcaneMissiles" (proc window is a strictly better AM).
-- ---------------------------------------------------------------------------

local delta_barrage = {}

-- Missile Barrage spend (kit: proc makes the next Arcane Missiles instant).
-- Above AM so the proc window beats the baseline's channel. Battery drives
-- the buff through the sentinel id (buff_remains_map).
if MISSILE_BARRAGE_BUFF then
    delta_barrage[#delta_barrage + 1] = {
        name = "Forever_MissileBarrageAM",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if (s.mana_pct or 100) < setting(context, "arc_forever_mb_mana_floor", FOREVER_MB_MANA_FLOOR) then return false end
            if not NS.has_player_buff(MISSILE_BARRAGE_BUFF) then return false end
            return NS.spell_ready(SPELLS.ArcaneMissiles, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.ArcaneMissiles, context.target,
                "[FOREVER-ARC] Missile Barrage instant Arcane Missiles")
        end,
    }
end

local delta_spam = {}

-- Arcane Blast 4-stack spam (kit: stacks die on any other spell — while
-- building/holding stacks, AB is the ONLY cast; skip during the AM cusp
-- window because casting AB there would eat the cusp for nothing). Battery
-- drives the buff through the sentinel id.
if ARCANE_BLAST_BUFF and ARCANE_BLAST_NUKE then
    delta_spam[#delta_spam + 1] = {
        name = "Forever_ArcaneBlastSpam",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if (s.mana_pct or 100) < setting(context, "arc_forever_ab_mana_floor", FOREVER_AB_MANA_FLOOR) then return false end
            if not NS.has_player_buff(ARCANE_BLAST_BUFF) then return false end
            if NS.cooldown_remains(SPELLS.ArcaneMissiles) < FOREVER_AM_CUSP_SECONDS then return false end
            return NS.spell_ready(ARCANE_BLAST_NUKE, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(ARCANE_BLAST_NUKE, context.target,
                "[FOREVER-ARC] Arcane Blast stack loop")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: barrage lane ABOVE "ArcaneMissiles"; spam block
-- BELOW it and ABOVE "Frostbolt". Re-registering the playstyle name
-- replaces the baseline wholesale — the combined list IS the "arcane"
-- playstyle on Forever.
-- ---------------------------------------------------------------------------
local combined = {}
local barrage_inserted = false
local spam_inserted = false
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    if not barrage_inserted and type(st) == "table" and st.name == "ArcaneMissiles" then
        for j = 1, #delta_barrage do combined[#combined + 1] = delta_barrage[j] end
        barrage_inserted = true
    end
    if not spam_inserted and type(st) == "table" and st.name == "Frostbolt" then
        for j = 1, #delta_spam do combined[#combined + 1] = delta_spam[j] end
        spam_inserted = true
    end
    combined[#combined + 1] = st
end
if not barrage_inserted then
    for j = 1, #delta_barrage do combined[#combined + 1] = delta_barrage[j] end
end
if not spam_inserted then
    for j = 1, #delta_spam do combined[#combined + 1] = delta_spam[j] end
end

original_register(registry, baseline.name, combined, baseline.options)
if NS.log then NS.log("Mage arcane Forever delta registered (" ..
    #delta_barrage .. " barrage + " .. #delta_spam .. " spam lanes over " ..
    #baseline.strategies .. " baseline lanes)") end

return combined
