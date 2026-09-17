-- protection_forever.lua — Warrior Protection delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 prot delta over the vanilla baseline: the Thunder Clap lane is
--        REPLACED with a stance-agnostic version (DBC/kit: TC is usable in
--        Defensive Stance now — the baseline hard-gated it to Battle Stance,
--        so the "TC becomes a core prot AoE threat lane" change could never
--        fire in the tanking stance) and the Vanguard Charge opener is added
--        (the new passive makes out-of-combat Charge legal in Defensive
--        Stance; gated on the passive being learned).
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/warrior.md (Icy Veins overview 2026-09-13; beta DBC
--        2026-09-17): class-wide "**Thunder Clap usable in Defensive
--        Stance** — Prot AoE-tank loop opens up (was stance-locked); TC
--        becomes a core prot AoE threat lane" and prot "**Vanguard** (NEW):
--        Charge usable in Defensive Stance (NOT in combat) — opener
--        gap-close for prot; no mid-fight charge lane". DBC: Vanguard
--        1310317 = "Your Charge ability is now usable while in Defensive
--        Stance" (aura 332 override rows pointing at the Charge ids);
--        Shield Wall 871 RecoveryTime 900000 and Last Stand 12975
--        RecoveryTime 180000 confirm the "prot baseline CD reductions"
--        (15min/3min, down from vanilla's 30/10) — the baseline's separate
--        defensive lanes need no change for that. Shield Slam 23925 /
--        Revenge 25288 value changes need no lane either. "Shield is
--        structural" is a talent-condition note: the engine validates the
--        shield on cast, and no shield-type API read exists in this tree —
--        documented, not guessed.
-- SAFETY: ZERO numeric spell-ID literals — Vanguard resolves BY NAME through
--        the bridge (dormant without it); the Charge/Thunder Clap casts and
--        the state gates are era-shared from the class map and the baseline's
--        own build_state. The vanilla baseline is loaded through an
--        intercepted registration (holy_forever template) so this file edits
--        nothing in protection_vanilla.lua and its safe_state-backed
--        get_state is reused unchanged. Splice geometry: the Vanguard charge
--        lane lands above the baseline's "Revenge" lane (below the
--        defensive/potion head lanes), and the replacement Thunder Clap lane
--        takes the baseline lane's exact position — no defensive lane is
--        shadowed.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.WarriorSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: require the vanilla file while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, fail loudly — a silently missing "protection"
-- playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local registry = NS.rotation_registry
if not registry or type(registry.register) ~= "function" then
    error("[FOREVER] warrior protection delta: rotation_registry unavailable", 0)
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
package.loaded["classes/warrior/protection_vanilla"] = nil
local baseline_ok, baseline_result = pcall(require, "classes/warrior/protection_vanilla")
registry.register = original_register
if not baseline_ok or type(baseline) ~= "table" or type(baseline.strategies) ~= "table" then
    error("[FOREVER] warrior protection delta: baseline load failed: " .. tostring(baseline_result), 0)
end

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b):
-- Vanguard (the new passive) resolves through the maxrank mirror; a nil
-- lookup leaves the charge lane dormant -- never a guessed ID. Sentinel
-- stand-ins are seeded per mirror by the battery's build_ns.
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

local VANGUARD = resolve_id(by_maxrank, "Vanguard")

-- ---------------------------------------------------------------------------
-- Shared helpers and Forever constants. Thresholds are menu-tunable via
-- spec_kit.setting; "estimated" values are tuned on beta day.
-- ---------------------------------------------------------------------------
local EMPTY_OPTS = {}
local SELF_OPTS = { skip_range = true }

local STANCE_BATTLE = 1      -- the repo's stance enum (battle 1 / defensive 2 / berserker 3)
local STANCE_DEFENSIVE = 2
local CHARGE_MIN_RANGE = 8   -- classic Charge dead zone
local CHARGE_MAX_RANGE = 25  -- classic Charge max range
local FOREVER_TC_RAGE = 20   -- vanilla-ish TC cost (Improved Thunder Clap only cheapens it)

local function setting(context, key, default)
    return spec_kit.setting(context, key, default)
end

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

local function knows(id)
    if not id or type(NS.is_spell_learned) ~= "function" then return false end
    local ok, learned = pcall(NS.is_spell_learned, id)
    return ok and learned == true
end

-- ---------------------------------------------------------------------------
-- Delta lanes. The Vanguard opener sits above the baseline's Revenge (below
-- every defensive/potion lane); the replacement TC lane takes the baseline's
-- own position.
-- ---------------------------------------------------------------------------

local delta_charge = {}

-- Vanguard Charge: out of combat only (the passive text is explicit), in
-- Defensive Stance, at Charge range. Gated on the passive being learned so
-- an un-talented warrior keeps the baseline's behavior exactly.
if VANGUARD and knows(VANGUARD) then
    delta_charge[#delta_charge + 1] = {
        name = "Forever_VanguardCharge",
        matches = function(context, s)
            if s.in_combat then return false end
            if s.stance ~= STANCE_DEFENSIVE then return false end
            if not has_valid_enemy(context) then return false end
            local dist = context.distance or context.target_distance or 0
            if dist < CHARGE_MIN_RANGE or dist > CHARGE_MAX_RANGE then return false end
            return NS.spell_ready(SPELLS.Charge, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Charge, context.target,
                "[FOREVER-PROT] Vanguard Charge opener")
        end,
    }
end

local delta_tc = {}

-- Thunder Clap, stance-agnostic (Forever unlocks it in Defensive Stance).
-- Same gates as the baseline lane it replaces: debuff refresh window, rage
-- cost, self-centred AoE.
delta_tc[#delta_tc + 1] = {
    name = "Forever_ThunderClap",
    matches = function(context, s)
        if s.stance ~= STANCE_DEFENSIVE and s.stance ~= STANCE_BATTLE then return false end
        if (s.tclap_remains or 0) > 5 then return false end
        if (s.rage or 0) < setting(context, "prot_forever_tc_rage", FOREVER_TC_RAGE) then return false end
        if not (NS.aoe_self_meets and NS.aoe_self_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8, context, s)) then
            return false
        end
        return NS.spell_ready(SPELLS.ThunderClap, context.me or NS.GetPlayer(), SELF_OPTS)
    end,
    execute = function(context)
        return NS.try_cast(SPELLS.ThunderClap, context.me or NS.GetPlayer(),
            "[FOREVER-PROT] Thunder Clap (stance-agnostic)")
    end,
}

-- ---------------------------------------------------------------------------
-- Splice + re-register: the Vanguard charge lane goes above "Revenge"
-- (fallback: above "ShieldSlam"; then append); the baseline's "ThunderClap"
-- lane is DROPPED and the replacement takes its position. Re-registering the
-- playstyle name replaces the baseline wholesale.
-- ---------------------------------------------------------------------------
local CHARGE_ANCHORS = { Revenge = true, ShieldSlam = true }
local REPLACED_LANES = { ThunderClap = true }

local combined = {}
local charge_inserted = false
local tc_inserted = false
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name == "ThunderClap" then
        for j = 1, #delta_tc do combined[#combined + 1] = delta_tc[j] end
        tc_inserted = true
    elseif not (name and REPLACED_LANES[name]) then
        if not charge_inserted and name and CHARGE_ANCHORS[name] then
            for j = 1, #delta_charge do combined[#combined + 1] = delta_charge[j] end
            charge_inserted = true
        end
        combined[#combined + 1] = st
    end
end
if not charge_inserted then
    for j = 1, #delta_charge do combined[#combined + 1] = delta_charge[j] end
end
if not tc_inserted then
    for j = 1, #delta_tc do combined[#combined + 1] = delta_tc[j] end
end

original_register(registry, baseline.name, combined, baseline.options)
if NS.log then NS.log("Warrior protection Forever delta registered (" ..
    #delta_charge .. " charge + " .. #delta_tc .. " TC lane, 1 replaced, over " ..
    #baseline.strategies .. " baseline lanes)") end

return combined
