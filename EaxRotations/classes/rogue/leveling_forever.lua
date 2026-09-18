-- leveling_forever.lua — Rogue leveling delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 rogue leveling delta over the vanilla baseline: MUTILATE from
--        early levels — the Forever ladder 1310707@30 / 399956@40 /
--        1241582@50 / 1241584@60 ("Instantly attacks with both weapons ...
--        Damage increased by $m4% against Poisoned targets. Awards $m1 Combo
--        Points") as the leveling builder above the baseline's Sinister
--        Strike: 2 combo points per cast beats 1 even without the poison
--        bonus, and the client's text carries NO behind clause (unlike the
--        TBC row — the #20 finding).
-- WHEN:  any combat while leveling, Forever client (class loader prefers
--        _forever over _vanilla).
-- WHY:   docs/forever/kits/rogue.md: "constant-regen energy reshapes early
--        leveling pace; Mutilate from early levels (Assassination leveling)."
--        BETA-VERIFICATION PASS (2026-09-18, P2 #3 CLOSED): constant-regen
--        energy is CONFIRMED (Icy Veins per-spec guides + class overview).
--        For the builder that means the real-cost gate IS the whole story:
--        Mutilate's DBC SpellPower cost is 60 energy on EVERY rank (rows
--        170015..314523, PowerType 3), so the gate below needs no pooling
--        floor or tick-sync offset — under constant regen the energy arrives
--        smoothly and the 2-CP builder fires the moment 60 is available.
--        DBC FINDINGS (1.60.1.69893): the ladder above; the lane casts the
--        {maxrank 1241584, rank-1 399956} bridge ladder — NS.get_spell_id
--        picks the highest LEARNED rung (levels 40-60); the @30 rank
--        1310707 is not name-reachable (the same rank-ladder-mirror gap the
--        paladin leveling day-1 recorded).
-- SAFETY: ZERO numeric spell-ID literals — Mutilate resolves BY NAME through
--        the bridge mirrors; the dagger eligibility mirrors the #20 helper
--        (both hands, shared/dagger_set, fail-closed). A nil lookup leaves
--        the lane dormant — never a guessed ID. The vanilla baseline is
--        loaded through an intercepted registration
--        (affliction/demonology_forever template) so this file edits nothing
--        in leveling_vanilla.lua and its safe_state-backed get_state is
--        reused unchanged. Splice geometry: the lane lands immediately above
--        the baseline's "SinisterStrike" builder (then append).

local NS = _G.EaxRotations
if not NS then return nil end

local SPELLS = NS.RogueSpells or {}

-- Dagger eligibility for Mutilate (mirrors assassination_forever.lua).
local _dagger_ok, dagger_set = pcall(require, "shared/dagger_set_sylvanas")
if not _dagger_ok or type(dagger_set) ~= "table" then dagger_set = nil end

-- ---------------------------------------------------------------------------
-- Baseline capture: require the vanilla file while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, fail loudly — a silently missing "leveling"
-- playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local registry = NS.rotation_registry
if not registry or type(registry.register) ~= "function" then
    error("[FOREVER] rogue leveling delta: rotation_registry unavailable", 0)
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
package.loaded["classes/rogue/leveling_vanilla"] = nil
local baseline_ok, baseline_result = pcall(require, "classes/rogue/leveling_vanilla")
registry.register = original_register
if not baseline_ok or type(baseline) ~= "table" or type(baseline.strategies) ~= "table" then
    error("[FOREVER] rogue leveling delta: baseline load failed: " .. tostring(baseline_result), 0)
end

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- builder resolves the maxrank + rank-1 mirrors into a two-rung ladder.
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

local MUTILATE_MAX = resolve_id(by_maxrank, "Mutilate")
local MUTILATE_R1 = resolve_id(by_name, "Mutilate")
local MUTILATE = nil
if MUTILATE_MAX or MUTILATE_R1 then
    MUTILATE = { ids = { MUTILATE_MAX, MUTILATE_R1 }, name = "Mutilate" }
end

-- ---------------------------------------------------------------------------
-- Shared helpers. Mutilate's DBC SpellPower cost is 60 energy on every rank
-- (beta 1.60.1.69893); under constant-regen energy (P2 #3 confirmed) the
-- real-cost gate below is the complete energy model — no pooling floor.
-- ---------------------------------------------------------------------------
local MUTILATE_ENERGY = 60

local function knows_any(id_a, id_b)
    if type(NS.is_spell_learned) ~= "function" then return false end
    for _, id in ipairs({ id_a, id_b or id_a }) do
        if type(id) == "number" then
            local ok, learned = pcall(NS.is_spell_learned, id)
            if ok and learned == true then return true end
        end
    end
    return false
end

-- Dagger eligibility: Mutilate strikes with BOTH weapons, so both hands
-- must hold a dagger (unknown items fail closed).
local function has_daggers()
    if not dagger_set or type(NS.get_equipped_item_id) ~= "function"
        or type(NS.EQUIPMENT_SLOTS) ~= "table" then
        return false
    end
    local is_dagger = dagger_set.is_dagger or {}
    local main_id = NS.get_equipped_item_id(NS.EQUIPMENT_SLOTS.MAIN_HAND)
    local off_id = NS.get_equipped_item_id(NS.EQUIPMENT_SLOTS.OFF_HAND)
    return (main_id and main_id ~= 0 and is_dagger[main_id] == true)
        and (off_id and off_id ~= 0 and is_dagger[off_id] == true)
        or false
end

-- ---------------------------------------------------------------------------
-- Delta lanes. The Mutilate builder leads the baseline's Sinister Strike.
-- ---------------------------------------------------------------------------
local delta_builder = {}

if MUTILATE and knows_any(MUTILATE_MAX, MUTILATE_R1) then
    delta_builder[#delta_builder + 1] = {
        name = "Forever_Mutilate",
        matches = function(context, s)
            if not s or not s.in_combat then return false end
            if not s.target then return false end
            if (s.combo_points or 0) >= (s.max_combo_points or 5) then return false end
            if (s.energy or 0) < MUTILATE_ENERGY then return false end
            if not has_daggers() then return false end
            return NS.spell_ready(MUTILATE, s.target)
        end,
        execute = function(context, s)
            return NS.try_cast(MUTILATE, s.target,
                "[FOREVER-LEVELING] Mutilate (2-CP builder)")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: the Mutilate builder immediately above the
-- baseline's "SinisterStrike" (the only anchor; then append). Re-registering
-- the playstyle name replaces the baseline wholesale — the combined list IS
-- the "leveling" playstyle on Forever.
-- ---------------------------------------------------------------------------
local BUILDER_ANCHORS = { SinisterStrike = true }

local combined = {}
local builder_done = false
local function insert_builder()
    if builder_done then return end
    for j = 1, #delta_builder do combined[#combined + 1] = delta_builder[j] end
    builder_done = true
end
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name and BUILDER_ANCHORS[name] then insert_builder() end
    combined[#combined + 1] = st
end
insert_builder()

original_register(registry, baseline.name, combined, baseline.options)
if NS.log then NS.log("Rogue leveling Forever delta registered (" ..
    #delta_builder .. " mutilate builder over " .. #baseline.strategies ..
    " baseline lanes)") end

return combined
