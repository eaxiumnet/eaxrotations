-- leveling_forever.lua — Hunter leveling delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 hunter leveling delta over the vanilla baseline: the shared
--        Aimed/Multi cooldown REORDER — with Aimed Shot now baseline for all
--        hunters and sharing SpellCategory 2 at 6000ms with Multi-Shot (the
--        BM/MM/SV day-1 DBC finding), the leveling file's lane order
--        (AimedShot above MultiShot) starves Multi on every multi-pull: the
--        pair is re-emitted Multi-first at the baseline's MultiShot position.
-- WHEN:  any combat while leveling, Forever client (class loader prefers
--        _forever over _vanilla).
-- WHY:   docs/forever/kits/hunter.md: "Aimed Shot baseline for all Hunters,
--        shares CD with Multi-Shot — the TBC Aimed-vs-Multi priority fork
--        becomes a shared-CD weave decision in EVERY hunter spec; Aimed no
--        longer a talent-gated rank pick" and the leveling bullet: "Aimed
--        Shot baseline reshapes early rotations; trap-in-combat opens
--        leveling tools." The same reorder the BM (#9), MM (#12) and SV (#8)
--        deltas carry applies to the leveling file; the checklist's
--        "obsolete shot-buffer/swing gates ... documented for the leveling
--        delta" note is honoured by NOT touching them (they only suppress
--        casts — harmless, and removing them is a separate concern).
--        TRAP-IN-COMBAT half: the baseline's FreezingTrap lane already
--        gates on in_combat (2+ enemies) — no delta needed; recorded in the
--        kit checklist.
-- SAFETY: no numeric spell-ID literals (this file resolves nothing — it only
--        reorders the baseline's own lanes). The vanilla baseline is loaded
--        through an intercepted registration (affliction/demonology_forever
--        template) so this file edits nothing in leveling_vanilla.lua and
--        its safe_state-backed get_state is reused unchanged. Splice
--        geometry: the baseline's AimedShot lane is captured; at the
--        baseline's "MultiShot" position the pair is emitted Multi-first
--        (melee fallback anchors: "AimedShot" for a baseline without the
--        Multi lane; then append) — no lane is duplicated and none is dead.

local NS = _G.EaxRotations
if not NS then return nil end

-- ---------------------------------------------------------------------------
-- Baseline capture: require the vanilla file while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, fail loudly — a silently missing "leveling"
-- playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local registry = NS.rotation_registry
if not registry or type(registry.register) ~= "function" then
    error("[FOREVER] hunter leveling delta: rotation_registry unavailable", 0)
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
package.loaded["classes/hunter/leveling_vanilla"] = nil
local baseline_ok, baseline_result = pcall(require, "classes/hunter/leveling_vanilla")
registry.register = original_register
if not baseline_ok or type(baseline) ~= "table" or type(baseline.strategies) ~= "table" then
    error("[FOREVER] hunter leveling delta: baseline load failed: " .. tostring(baseline_result), 0)
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: capture the baseline's "AimedShot" lane and emit the
-- pair Multi-first at the baseline's "MultiShot" position (the shared 6s
-- SpellCategory then picks the right shot for the target count). Re-
-- registering the playstyle name replaces the baseline wholesale — the
-- combined list IS the "leveling" playstyle on Forever.
-- ---------------------------------------------------------------------------
local baseline_has_multi = false
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    if type(st) == "table" and st.name == "MultiShot" then baseline_has_multi = true break end
end

local combined = {}
local aimed_lane = nil
local reordered = false
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name == "AimedShot" and baseline_has_multi then
        aimed_lane = st  -- emitted later, below MultiShot
    elseif name == "MultiShot" then
        combined[#combined + 1] = st
        if aimed_lane then
            combined[#combined + 1] = aimed_lane
            aimed_lane = nil
            reordered = true
        end
    else
        combined[#combined + 1] = st
    end
end
if aimed_lane then
    combined[#combined + 1] = aimed_lane
end

original_register(registry, baseline.name, combined, baseline.options)
if NS.log then NS.log("Hunter leveling Forever delta registered (" ..
    (reordered and "Multi-first shot reorder" or "no reorder (baseline lacked the pair)") ..
    " over " .. #baseline.strategies .. " baseline lanes)") end

return combined
