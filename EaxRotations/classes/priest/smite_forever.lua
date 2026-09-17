-- smite_forever.lua — Priest Smite delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 smite delta over the vanilla baseline: the POWER IN LIGHT
--        core ("Your Smite and Penance spells deal $m1% increased damage to
--        targets afflicted with your Holy Fire" — 1309969, +15% per the
--        effect dump) as two pieces — PENANCE as the new core nuke (the
--        dual-mode cast 1316995, 12s CategoryRecoveryTime, fired in its
--        damage mode only while the Holy Fire debuff is up) and HOLY FIRE
--        UPKEEP (the debuff is now the Smite/Penance multiplier, so the
--        baseline's cast-on-cooldown lane is REPLACED by a debuff-driven
--        refresh that fires when the aura is missing or inside 2s of
--        expiry).
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/priest.md: "Power in Light: Smite + Penance deal
--        up to +10% vs Holy-Fire-kept targets — the repo's dedicated SMITE
--        spec file gains real kit support: Holy Fire becomes a maintenance
--        debuff (hard lane gate, FS-style)" and "Penance (above) — the
--        spec's new core button (offensive mode feeds the Smite build
--        below)". DBC FINDINGS (1.60.1.69893): Power in Light 1309969 is a
--        passive (aura 4 dummy, base 15 — the kit's "up to +10%" corrected
--        to 15%, same correction as the discipline day-1); Penance ladder
--        402174@30 / 1240720@40 / 1240721@50 / 1316995@60 (the cast row
--        pinned in the builder's MAXRANK_OVERRIDES, 12s category cooldown);
--        Holy Fire's debuff is applied by the cast row itself (aura 3
--        periodic damage on 15261 and the ladder), so the upkeep read uses
--        the class-map ladder. Smite itself needs no lane: the +15% applies
--        automatically to every cast while the debuff holds.
-- SAFETY: ZERO numeric spell-ID literals — Power in Light and Penance
--        resolve BY NAME through the bridge mirrors; the Holy Fire debuff
--        read reuses the class-map ladder. A nil lookup leaves the lane
--        dormant — never a guessed ID. The vanilla baseline is loaded
--        through an intercepted registration (affliction/demonology_forever
--        template) so this file edits nothing in smite_vanilla.lua and its
--        safe_state-backed get_state is reused unchanged. Splice geometry:
--        the Penance lane goes immediately above the baseline's "MindBlast"
--        nuke (fallback: "SmiteFiller") and the upkeep lane takes the
--        replaced "HolyFire" lane's exact position; then append.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.PriestSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: require the vanilla file while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, fail loudly — a silently missing "smite" playstyle
-- is worse than a hard error.
-- ---------------------------------------------------------------------------
local registry = NS.rotation_registry
if not registry or type(registry.register) ~= "function" then
    error("[FOREVER] priest smite delta: rotation_registry unavailable", 0)
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
package.loaded["classes/priest/smite_vanilla"] = nil
local baseline_ok, baseline_result = pcall(require, "classes/priest/smite_vanilla")
registry.register = original_register
if not baseline_ok or type(baseline) ~= "table" or type(baseline.strategies) ~= "table" then
    error("[FOREVER] priest smite delta: baseline load failed: " .. tostring(baseline_result), 0)
end

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- Penance cast resolves the maxrank mirror, the learn gates read both
-- mirrors, Power in Light the rank-1 mirror. A nil lookup leaves the lane
-- dormant -- never a guessed ID. Sentinel stand-ins are seeded per mirror
-- by the battery's build_ns so mirror selection itself is pinned.
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

local POWER_IN_LIGHT = resolve_id(by_name, "Power in Light")
local PENANCE = resolve_id(by_maxrank, "Penance")
local PENANCE_R1 = resolve_id(by_name, "Penance")
local HOLY_FIRE = SPELLS.HolyFire or nil
local HOLY_FIRE_IDS = (HOLY_FIRE and HOLY_FIRE._meta and HOLY_FIRE._meta.ids) or nil

-- ---------------------------------------------------------------------------
-- Shared helpers. Penance's DBC cooldown is 12s (CategoryRecoveryTime); the
-- Holy Fire refresh window is 2s so the Power in Light multiplier never
-- lapses between the debuff's ticks.
-- ---------------------------------------------------------------------------
local PENANCE_OPTS = { expected_cooldown = 12 }
local HF_REFRESH = 2
local HF_OPTS = { expected_cooldown = 10 }

local function setting(context, key, default)
    return spec_kit.setting(context, key, default)
end

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

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

local function hf_remains(context)
    if not HOLY_FIRE_IDS or type(NS.debuff_remains) ~= "function" then return 0 end
    local ok, remains = pcall(NS.debuff_remains, context.target, HOLY_FIRE_IDS)
    if ok and type(remains) == "number" then return remains end
    return 0
end

local function hf_up(context)
    if not HOLY_FIRE_IDS or type(NS.debuff_up) ~= "function" then return false end
    local ok, up = pcall(NS.debuff_up, context.target, HOLY_FIRE_IDS)
    return ok and up == true
end

-- ---------------------------------------------------------------------------
-- Delta lanes. Penance leads the nuke block; the upkeep lane replaces the
-- baseline's cast-on-cooldown Holy Fire lane at its exact position.
-- ---------------------------------------------------------------------------
local delta_nuke = {}
local delta_upkeep = {}
local PIL_LEARNED = POWER_IN_LIGHT and knows_any(POWER_IN_LIGHT) or false

if PIL_LEARNED and PENANCE and knows_any(PENANCE, PENANCE_R1) then
    delta_nuke[#delta_nuke + 1] = {
        name = "Forever_Penance",
        matches = function(context, s)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            if not has_valid_enemy(context) then return false end
            if s.mana_emergency then return false end
            if not hf_up(context) then return false end  -- the Power in Light window
            return NS.spell_ready(PENANCE, context.target, PENANCE_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(PENANCE, context.target,
                "[FOREVER-SMITE] Penance (Power in Light window)")
        end,
    }
end

if PIL_LEARNED and HOLY_FIRE then
    delta_upkeep[#delta_upkeep + 1] = {
        name = "Forever_HolyFireUpkeep",
        matches = function(context, s)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            if not has_valid_enemy(context) then return false end
            if s.mana_emergency then return false end
            if hf_remains(context) > setting(context, "smite_forever_hf_refresh", HF_REFRESH) then
                return false
            end
            return NS.spell_ready(HOLY_FIRE, context.target, HF_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(HOLY_FIRE, context.target,
                "[FOREVER-SMITE] Holy Fire (Power in Light upkeep)")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: the Penance lane immediately above "MindBlast"
-- (fallback: "SmiteFiller"), the upkeep lane REPLACES "HolyFire" (the
-- cast-on-cooldown lane the Power in Light debuff-driven refresh supersedes)
-- and takes its position; then append. Re-registering the playstyle name
-- replaces the baseline wholesale — the combined list IS the "smite"
-- playstyle on Forever.
-- ---------------------------------------------------------------------------
local NUKE_ANCHORS = { MindBlast = true, SmiteFiller = true }
local DROPPED_LANES = (PIL_LEARNED and HOLY_FIRE) and { HolyFire = true } or {}

local combined = {}
local nuke_done = false
local upkeep_done = false
local function insert_nuke()
    if nuke_done then return end
    for j = 1, #delta_nuke do combined[#combined + 1] = delta_nuke[j] end
    nuke_done = true
end
local function insert_upkeep()
    if upkeep_done then return end
    for j = 1, #delta_upkeep do combined[#combined + 1] = delta_upkeep[j] end
    upkeep_done = true
end
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name and DROPPED_LANES[name] then
        insert_upkeep()  -- the replacement takes the dropped lane's position
    else
        if name and NUKE_ANCHORS[name] then insert_nuke() end
        combined[#combined + 1] = st
    end
end
insert_nuke()
insert_upkeep()

original_register(registry, baseline.name, combined, baseline.options)
if NS.log then NS.log("Priest smite Forever delta registered (" ..
    #delta_nuke .. " penance + " .. #delta_upkeep ..
    " holy-fire-upkeep lanes" ..
    (PIL_LEARNED and HOLY_FIRE and ", HolyFire lane replaced" or "") ..
    " over " .. #baseline.strategies .. " baseline lanes)") end

return combined
