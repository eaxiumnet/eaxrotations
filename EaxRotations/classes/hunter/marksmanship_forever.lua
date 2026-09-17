-- marksmanship_forever.lua — Hunter Marksmanship delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 MM delta over the vanilla baseline: a context-gated Sniper
--        Shot burst lane (DBC: 4s cast, 15s cooldown, execute/PvP window
--        only — the kit's "not a rotation filler"), the DBC-confirmed
--        shared Aimed/Multi cooldown reordered so Multi wins its 2+-target
--        gate, and the LONE WOLF FORK: when the talent is learned the
--        pet-recall/maintenance lanes are dropped (summoning a pet cancels
--        the +21% petless damage).
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/hunter.md (Icy Veins overview 2026-09-15; beta DBC
--        2026-09-17): "Sniper Shot (31-pt capstone): massive 4s-cast shot;
--        strong burst, may be a PvE damage loss at that cast time — treat as
--        PvP/execute-style burst lane, gate on context (not a rotation
--        filler)" and "Lone Wolf: petless +20% damage — MM's defining fork;
--        needs a pet-present context field to branch". DBC: Sniper Shot
--        1310687@40 / 1310785@48 / **1310786@58**, cast 4000ms, RecoveryTime
--        15000; Lone Wolf 415370 = "You deal 21% increased damage with all
--        attacks while you do not have an active pet" (aura 79); Aimed Shot
--        19434/20904 and Multi-Shot 2643 share SpellCategory 2 at 6000ms.
-- SAFETY: ZERO numeric spell-ID literals — Sniper Shot resolves BY NAME
--        through the maxrank mirror, Lone Wolf through the same mirror for
--        the talent-known check (NS.is_spell_learned, nil-guarded: an
--        unknown API or a nil lookup keeps the baseline pet lanes instead of
--        guessing). A nil Sniper lookup leaves that lane dormant. The vanilla
--        baseline is loaded through an intercepted registration (holy_forever
--        template) so this file edits nothing in marksmanship_vanilla.lua and
--        its safe_state-backed get_state is reused unchanged. Splice
--        geometry: the Sniper lane and the reordered Multi lane land
--        immediately above the baseline's in-combat Aimed lane (fallback:
--        above the prepull Aimed lane; then append) — below every
--        buff/pet/defensive lane that survives the Lone Wolf fork.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.HunterSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: require the vanilla file while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, fail loudly — a silently missing "marksmanship"
-- playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local registry = NS.rotation_registry
if not registry or type(registry.register) ~= "function" then
    error("[FOREVER] hunter marksmanship delta: rotation_registry unavailable", 0)
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
package.loaded["classes/hunter/marksmanship_vanilla"] = nil
local baseline_ok, baseline_result = pcall(require, "classes/hunter/marksmanship_vanilla")
registry.register = original_register
if not baseline_ok or type(baseline) ~= "table" or type(baseline.strategies) ~= "table" then
    error("[FOREVER] hunter marksmanship delta: baseline load failed: " .. tostring(baseline_result), 0)
end

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- Sniper Shot CAST and the Lone Wolf TALENT ROW both resolve through the
-- maxrank mirror. A nil lookup leaves the Sniper lane dormant and keeps the
-- baseline pet lanes (fail-closed) -- never a guessed ID. Sentinel stand-ins
-- are seeded per mirror by the battery's build_ns.
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

local SNIPER_SHOT = resolve_id(by_maxrank, "Sniper Shot")
local LONE_WOLF = resolve_id(by_maxrank, "Lone Wolf")

-- ---------------------------------------------------------------------------
-- Shared helpers and Forever constants. Thresholds are menu-tunable via
-- spec_kit.setting; "estimated" values are tuned on beta day.
-- ---------------------------------------------------------------------------
local EMPTY_OPTS = {}

-- DBC-confirmed: Sniper Shot RecoveryTime 15000, cast 4000ms; the kit's
-- execute-style context gate is 20% target HP (mirrors the repo's Execute
-- threshold) or any PvP situation.
local FOREVER_SNIPER_CD = 15
local FOREVER_SNIPER_EXECUTE_HP = 20

local function setting(context, key, default)
    return spec_kit.setting(context, key, default)
end

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

-- Lone Wolf known = the petless fork. Nil API or nil lookup -> false, which
-- keeps the baseline pet lanes (fail-closed to the vanilla behavior).
local function has_lone_wolf()
    if not LONE_WOLF or type(NS.is_spell_learned) ~= "function" then return false end
    local ok, learned = pcall(NS.is_spell_learned, LONE_WOLF)
    return ok and learned == true
end

-- ---------------------------------------------------------------------------
-- Delta lanes. One context-gated burst lane; the pet fork and the shot
-- reorder are handled at splice time.
-- ---------------------------------------------------------------------------

local delta_burst = {}

if SNIPER_SHOT then
    delta_burst[#delta_burst + 1] = {
        name = "Forever_SniperShot",
        matches = function(context, s)
            if not s.in_combat then return false end
            if not has_valid_enemy(context) then return false end
            if context.is_moving then return false end
            local execute_hp = setting(context, "mm_forever_sniper_execute_hp", FOREVER_SNIPER_EXECUTE_HP)
            local in_window = context.is_pvp == true
                or (s.target_hp or 100) <= execute_hp
            if not in_window then return false end
            return NS.spell_ready(SNIPER_SHOT, context.target, { expected_cooldown = FOREVER_SNIPER_CD })
        end,
        execute = function(context)
            return NS.try_cast(SNIPER_SHOT, context.target,
                "[FOREVER-MM] Sniper Shot (execute/PvP window)")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register:
--   1. Lone Wolf fork: the pet recall/maintenance lanes are DROPPED when the
--      talent is learned (a summoned pet cancels the +21% petless damage).
--   2. Shot reorder: Multi-Shot is re-emitted immediately above the
--      in-combat Aimed lane (shared 6s category cooldown), and the Sniper
--      lane lands just above the pair.
--   3. Fallbacks: no Aimed anchor -> the pair appends at the tail; a missing
--      Multi lane -> the Aimed lane keeps its position.
-- Re-registering the playstyle name replaces the baseline wholesale — the
-- combined list IS the "marksmanship" playstyle on Forever.
-- ---------------------------------------------------------------------------
local PET_LANES = has_lone_wolf()
    and { CallPet = true, RevivePet = true, MendPet = true } or {}
local AIMED_ANCHORS = { InCombatAimedShot = true, AimedShotPrepull = true, AimedShot = true }

local baseline_has_multi = false
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    if type(st) == "table" and st.name == "MultiShot" then baseline_has_multi = true break end
end

local combined = {}
local burst_inserted = false
local aimed_lanes = {}
local function insert_burst()
    if burst_inserted then return end
    for j = 1, #delta_burst do combined[#combined + 1] = delta_burst[j] end
    burst_inserted = true
end
local function flush_aimed()
    for j = 1, #aimed_lanes do combined[#combined + 1] = aimed_lanes[j] end
    aimed_lanes = {}
end
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name and PET_LANES[name] then
        -- Lone Wolf fork: skip (dropped).
    elseif name == "MultiShot" then
        insert_burst()
        combined[#combined + 1] = st
        flush_aimed()
    elseif name and AIMED_ANCHORS[name] and baseline_has_multi then
        aimed_lanes[#aimed_lanes + 1] = st
    else
        if not burst_inserted and name and AIMED_ANCHORS[name] then insert_burst() end
        combined[#combined + 1] = st
    end
end
flush_aimed()
insert_burst()

original_register(registry, baseline.name, combined, baseline.options)
if NS.log then NS.log("Hunter marksmanship Forever delta registered (" ..
    #delta_burst .. " burst lane, shared-CD shot reorder" ..
    (has_lone_wolf() and ", Lone Wolf pet fork active" or "") .. " over " ..
    #baseline.strategies .. " baseline lanes)") end

return combined
