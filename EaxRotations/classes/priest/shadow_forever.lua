-- shadow_forever.lua — Priest Shadow delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 shadow delta over the vanilla baseline: SHADOW WORD: DEATH as
--        the Early Demise execute ("A word of dark binding that inflicts $s1
--        Shadow damage ... If your target is not killed by Shadow Word:
--        Death, you take backlash damage equal to $s3% of your maximum
--        health"; the Early Demise talent 1310076 adds "+30% critical strike
--        chance on targets at or below 20% health") and the DEVOURING
--        CONTAGION chaining lane ("Reduces the mana cost of your Devouring
--        Plague by $s1%. Targets that die while Devouring Plague it is
--        active spreads it, jumping to a nearby enemy within $s2 yards for
--        the remaining duration" — 1309950's effect rows: -50% mana, 10y
--        jump).
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/priest.md: "Early Demise: SW:D crit chance
--        +15/30% vs <=20% health targets — sharper execute lane" (the
--        vanilla baseline has NO SW:D lane at all — this is the execute it
--        never had) and "Devouring Contagion: DP mana cost -25/50%; targets
--        dying with DP spread it to a nearby enemy for the remaining
--        duration — AoE dot chaining lane on trash pulls". DBC FINDINGS
--        (1.60.1.69893): SW:D ladder 1309595@32 / 1309633@40 / 1309635@48 /
--        1309636@56 with CategoryRecoveryTime 15000 (the lane declares 15s);
--        Early Demise 1310076 is BaseLevel 0 — the builder's level guard
--        excludes it (the same class of gap as Fingers of Frost; recorded
--        as a probe), so the lane does not gate on the talent: its 20%-HP
--        window IS the talent's condition. Devouring Plague is
--        rune-granted on this client ("Gain the Devouring Plague ability"
--        rows 459713/1219275 reference the vanilla 19280 ladder), so the
--        baseline's spell_exists(class-map ladder) lane is the universal
--        path already — no delta needed. Improved Mind Flay 1225139
--        (+damage, +range, slow) is a pure passive on the baseline's
--        MindFlay lane (which carries no range gate): the extended range and
--        the slow apply to every existing cast — no new lane, recorded with
--        its in-game numbers as a probe.
-- SAFETY: ZERO numeric spell-ID literals — Shadow Word: Death and Devouring
--        Contagion resolve BY NAME through the bridge mirrors; the Devouring
--        Plague cast reuses the class-map ladder the baseline already casts.
--        A nil lookup leaves the lane dormant — never a guessed ID. The
--        vanilla baseline is loaded through an intercepted registration
--        (affliction/demonology_forever template) so this file edits nothing
--        in shadow_vanilla.lua and its safe_state-backed get_state is reused
--        unchanged. Both lanes respect the baseline's channel discipline
--        (`mf_channeling` / `should_clip_mf`) and mana floors. Splice
--        geometry: SW:D goes immediately above "MindBlast" and the Contagion
--        lane immediately above the dot block's head ("ShadowWordPain";
--        fallback "DevouringPlague").

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.PriestSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: require the vanilla file while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, fail loudly — a silently missing "shadow"
-- playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local registry = NS.rotation_registry
if not registry or type(registry.register) ~= "function" then
    error("[FOREVER] priest shadow delta: rotation_registry unavailable", 0)
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
package.loaded["classes/priest/shadow_vanilla"] = nil
local baseline_ok, baseline_result = pcall(require, "classes/priest/shadow_vanilla")
registry.register = original_register
if not baseline_ok or type(baseline) ~= "table" or type(baseline.strategies) ~= "table" then
    error("[FOREVER] priest shadow delta: baseline load failed: " .. tostring(baseline_result), 0)
end

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- SW:D cast resolves the maxrank mirror (the learn gate reads both), the
-- Contagion talent the rank-1 mirror. A nil lookup leaves the lane dormant
-- -- never a guessed ID. Sentinel stand-ins are seeded per mirror by the
-- battery's build_ns so mirror selection itself is pinned.
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

local SHADOW_WORD_DEATH = resolve_id(by_maxrank, "Shadow Word: Death")
local SHADOW_WORD_DEATH_R1 = resolve_id(by_name, "Shadow Word: Death")
local DEVOURING_CONTAGION = resolve_id(by_name, "Devouring Contagion")
local DEVOURING_PLAGUE = SPELLS.DevouringPlague or nil

-- ---------------------------------------------------------------------------
-- Shared helpers. SW:D's DBC cooldown is 15s (CategoryRecoveryTime), the
-- Contagion jump radius is 10y and the mana reduction 50% (effect rows).
-- ---------------------------------------------------------------------------
local SWD_OPTS = { expected_cooldown = 15 }
local SWD_EXECUTE_HP = 20
local CONTAGION_REFRESH = 6

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

-- Mirror the baseline's file-local can_break_mind_flay: never clip a live
-- Mind Flay channel unless the rotation already decided to clip it.
local function can_break_channel(s)
    return (not s.mf_channeling) or s.should_clip_mf == true
end

-- ---------------------------------------------------------------------------
-- Delta lanes. SW:D leads the nuke block, the Contagion lane the dot block.
-- ---------------------------------------------------------------------------
local delta_nuke = {}
local delta_dot = {}

if SHADOW_WORD_DEATH and knows_any(SHADOW_WORD_DEATH, SHADOW_WORD_DEATH_R1) then
    delta_nuke[#delta_nuke + 1] = {
        name = "Forever_ShadowWordDeath",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if (context.target_hp or 100) > setting(context, "shadow_forever_swd_hp", SWD_EXECUTE_HP) then return false end
            if s.mana_emergency then return false end
            if not can_break_channel(s) then return false end
            return NS.spell_ready(SHADOW_WORD_DEATH, context.target, SWD_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(SHADOW_WORD_DEATH, context.target,
                "[FOREVER-SHADOW] Shadow Word: Death (Early Demise execute)")
        end,
    }
end

if DEVOURING_CONTAGION and DEVOURING_PLAGUE and knows_any(DEVOURING_CONTAGION) then
    delta_dot[#delta_dot + 1] = {
        name = "Forever_DevouringContagion",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if not s.devouring_plague_known then return false end
            if s.combat_mode ~= "cleave" and s.combat_mode ~= "aoe" then return false end
            if not can_break_channel(s) then return false end
            if s.mana_emergency then return false end
            if (s.dp_remaining or 0) > setting(context, "shadow_forever_contagion_refresh", CONTAGION_REFRESH) then return false end
            return NS.spell_ready(DEVOURING_PLAGUE, context.target)
        end,
        execute = function(context)
            return NS.try_cast(DEVOURING_PLAGUE, context.target,
                "[FOREVER-SHADOW] Devouring Plague (Contagion chain maintenance)")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: SW:D immediately above the baseline's "MindBlast"
-- nuke (fallback: "MindFlay"), the Contagion lane immediately above the dot
-- block's head "ShadowWordPain" (fallback: "DevouringPlague"); then append.
-- Re-registering the playstyle name replaces the baseline wholesale — the
-- combined list IS the "shadow" playstyle on Forever.
-- ---------------------------------------------------------------------------
local NUKE_ANCHORS = { MindBlast = true, MindFlay = true }
local DOT_ANCHORS = { DevouringPlague = true, ShadowWordPain = true }

local combined = {}
local nuke_done = false
local dot_done = false
local function insert_nuke()
    if nuke_done then return end
    for j = 1, #delta_nuke do combined[#combined + 1] = delta_nuke[j] end
    nuke_done = true
end
local function insert_dot()
    if dot_done then return end
    for j = 1, #delta_dot do combined[#combined + 1] = delta_dot[j] end
    dot_done = true
end
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name and NUKE_ANCHORS[name] then insert_nuke() end
    if name and DOT_ANCHORS[name] then insert_dot() end
    combined[#combined + 1] = st
end
insert_nuke()
insert_dot()

original_register(registry, baseline.name, combined, baseline.options)
if NS.log then NS.log("Priest shadow Forever delta registered (" ..
    #delta_nuke .. " shadow-word-death + " .. #delta_dot ..
    " devouring-contagion lanes over " .. #baseline.strategies ..
    " baseline lanes)") end

return combined
