-- demonology_forever.lua — Warlock Demonology delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 demonology delta over the vanilla baseline: the DEMONIC PACT
--        partner-maintenance lane (Demonic Pact 425464: "Your Demonic
--        Sacrifice effect is no longer cancelled by summoning a different
--        Demon pet. Resummoning the sacrificed pet will still cancel the
--        effect." — the lane summons the OTHER demon while a sacrifice aura
--        is up, so the school buff and a fighting pet coexist) and the
--        DECIMATION execute lane (the proc on a sub-35% target makes Soul
--        Fire shard-free with a reduced cast — the lane spends the window).
-- WHEN:  combat and out of combat (the partner lane is pet maintenance);
--        Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/warlock.md: "Demonic Pact (NEW capstone):
--        Demonic Sacrifice's buff PERSISTS when a different demon is
--        summoned (re-summoning the sacrificed one cancels) — a
--        buff-juggling rotation: sacrifice Imp (+15% Shadow) or Succubus
--        (+15% Fire), then summon the OTHER demon to fight alongside" and
--        "Decimation: ... vs <=35% HP targets ... SF cast -40%, no Soul
--        Shard cost — execute lane". DBC FINDINGS (1.60.1.69893): Demonic
--        Pact 425464 is a Warlock talent row whose text confirms the
--        persistence rule (the P3 probe is resolved by the client text);
--        the sacrifice auras are separately named rows — BURNING SHADOW
--        18789 (Imp -> +Shadow) and TOUCH OF FIRE 18791 (Succubus -> +Fire) —
--        so the lane reads the aura's own name; Decimation 440870 is the
--        talent ("Reduces the cooldown of your Soul Fire spell by $m2%...")
--        while the applied proc is 440873, pinned in the builder's
--        BUFF_OVERRIDES. NOTE: Demonic Sacrifice itself (18788) has no
--        SpellClassOptions row in this client's DBC, so the bridge's
--        player-spell index cannot carry it — the sacrifice cast stays a
--        MANUAL choice (as in the vanilla baseline, where DS/Ruin is a
--        pre-pull decision); the delta automates the half the new mechanic
--        created (keep the partner out without cancelling the buff).
--        Recorded probes: Demonic Brand pet-tank lane (Searing Pain threat,
--        pet consumes the brand — undocumented threat values), the
--        sacrifice-school choice itself, and whether Demonic Sacrifice is
--        trainer/engraving-granted at 60 on the beta.
-- SAFETY: ZERO numeric spell-ID literals — Demonic Pact, the sacrifice auras,
--        Decimation and both summons resolve BY NAME through the bridge
--        mirrors; a nil lookup leaves the lane dormant — never a guessed ID.
--        The vanilla baseline is loaded through an intercepted registration
--        (affliction_forever/holy_forever template) so this file edits
--        nothing in demonology_vanilla.lua and its safe_state-backed
--        get_state is reused unchanged. Splice geometry: the partner lane
--        lands immediately above the baseline's "FelDomination" lane and the
--        Decimation lane immediately above "ShadowBoltFiller" (fallbacks:
--        "HealthFunnel" / "Wand"; then append) — below every
--        survival/defensive lane.

local NS = _G.EaxRotations
if not NS then return nil end

local SPELLS = NS.WarlockSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: require the vanilla file while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, fail loudly — a silently missing "demonology"
-- playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local registry = NS.rotation_registry
if not registry or type(registry.register) ~= "function" then
    error("[FOREVER] warlock demonology delta: rotation_registry unavailable", 0)
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
package.loaded["classes/warlock/demonology_vanilla"] = nil
local baseline_ok, baseline_result = pcall(require, "classes/warlock/demonology_vanilla")
registry.register = original_register
if not baseline_ok or type(baseline) ~= "table" or type(baseline.strategies) ~= "table" then
    error("[FOREVER] warlock demonology delta: baseline load failed: " .. tostring(baseline_result), 0)
end

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- summon CASTS resolve through the maxrank mirror (a level-60 warlock summons
-- the top-rank demon, not the level-1 baseline), the talent gate through the
-- rank-1 mirror, and the sacrifice/Decimation auras through the buff mirror.
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
local by_buff = (ForeverBridge
    and type(ForeverBridge.spell_buff_by_name_forever) == "table")
    and ForeverBridge.spell_buff_by_name_forever or {}

local function resolve_id(map, client_name)
    local id = map[client_name]
    if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then return nil end
    return id
end

local DEMONIC_PACT = resolve_id(by_name, "Demonic Pact")
local BURNING_SHADOW = resolve_id(by_buff, "Burning Shadow")
local TOUCH_OF_FIRE = resolve_id(by_buff, "Touch of Fire")
local DECIMATION_BUFF = resolve_id(by_buff, "Decimation")
local SUMMON_IMP = resolve_id(by_maxrank, "Summon Imp")
local SUMMON_SUCCUBUS = resolve_id(by_maxrank, "Summon Succubus")
local SOUL_FIRE = SPELLS.SoulFire or nil

-- ---------------------------------------------------------------------------
-- Shared helpers. Soul Fire has no RecoveryTime row on this client (only the
-- 1.5s StartRecoveryTime), so the lane adds the DBC-proven Decimation window
-- to the buff read and lets spell_ready handle readiness.
-- ---------------------------------------------------------------------------
local EMPTY_OPTS = {}
local SKIP_RANGE = { skip_range = true }

local function knows(id)
    if type(id) ~= "number" or type(NS.is_spell_learned) ~= "function" then return false end
    local ok, learned = pcall(NS.is_spell_learned, id)
    return ok and learned == true
end

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

local function aura_up(unit, id)
    if not unit or not id or type(NS.buff_up) ~= "function" then return false end
    local ok, up = pcall(NS.buff_up, unit, id)
    return ok and up == true
end

-- Demonic Pact partner: the sacrificed demon's school aura decides which ONE
-- demon may be summoned without cancelling it — the sacrificed pet itself is
-- forbidden (its aura dies), every other demon is legal. The kit's loop uses
-- the two school demons, so the mapping is Burning Shadow -> Succubus and
-- Touch of Fire -> Imp (the Voidwalker/Felhunter sacrifice auras — Fel Energy
-- / Fel Stamina — are not school buffs and stay unlaned).
local function partner_for(me)
    if aura_up(me, BURNING_SHADOW) then return SUMMON_SUCCUBUS end
    if aura_up(me, TOUCH_OF_FIRE) then return SUMMON_IMP end
    return nil
end

-- ---------------------------------------------------------------------------
-- Delta lanes. The partner lane is pet maintenance (sits above the
-- baseline's Fel Domination emergency); the Decimation lane replaces Shadow
-- Bolt inside the proc window (sits above ShadowBoltFiller).
-- ---------------------------------------------------------------------------
local delta_pet = {}
local delta_execute = {}

if DEMONIC_PACT and knows(DEMONIC_PACT) and (SUMMON_IMP or SUMMON_SUCCUBUS) then
    delta_pet[#delta_pet + 1] = {
        name = "Forever_DemonicPactPartner",
        matches = function(context, s)
            if s and s.has_pet then return false end
            local partner = partner_for(context.me)
            if not partner then return false end
            return NS.spell_ready(partner, context.me, SKIP_RANGE)
        end,
        execute = function(context)
            local partner = partner_for(context.me)
            if not partner then return false end
            return NS.try_cast(partner, context.me,
                "[FOREVER-DEMO] Demonic Pact partner (sacrifice aura up, summon the other demon)")
        end,
    }
end

if DECIMATION_BUFF and SOUL_FIRE then
    delta_execute[#delta_execute + 1] = {
        name = "Forever_Decimation",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if not aura_up(context.me, DECIMATION_BUFF) then return false end
            return NS.spell_ready(SOUL_FIRE, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(SOUL_FIRE, context.target,
                "[FOREVER-DEMO] Decimation Soul Fire (shard-free execute window)")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: the partner lane goes immediately above the
-- baseline's "FelDomination" lane (fallback: above "HealthFunnel"; then
-- append) and the Decimation lane immediately above "ShadowBoltFiller"
-- (fallback: above "Wand"; then append). Re-registering the playstyle name
-- replaces the baseline wholesale — the combined list IS the "demonology"
-- playstyle on Forever.
-- ---------------------------------------------------------------------------
local PARTNER_ANCHORS = { FelDomination = true, HealthFunnel = true }
local DECIMATION_ANCHORS = { ShadowBoltFiller = true, Wand = true }

local combined = {}
local pet_done = false
local execute_done = false
local function insert_pet()
    if pet_done then return end
    for j = 1, #delta_pet do combined[#combined + 1] = delta_pet[j] end
    pet_done = true
end
local function insert_execute()
    if execute_done then return end
    for j = 1, #delta_execute do combined[#combined + 1] = delta_execute[j] end
    execute_done = true
end
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name and PARTNER_ANCHORS[name] then insert_pet() end
    if name and DECIMATION_ANCHORS[name] then insert_execute() end
    combined[#combined + 1] = st
end
insert_pet()
insert_execute()

original_register(registry, baseline.name, combined, baseline.options)
if NS.log then NS.log("Warlock demonology Forever delta registered (" ..
    #delta_pet .. " demonic-pact partner + " .. #delta_execute ..
    " decimation lane over " .. #baseline.strategies .. " baseline lanes)") end

return combined
