-- discipline_forever.lua — Priest Discipline delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 discipline delta over the vanilla baseline: PENANCE in both
--        modes (the new core button — "Launches a volley of holy light at
--        the target, causing $1316993s1 Holy damage to an enemy, or
--        $1316991s1 healing to an ally, instantly and every $402261t2 sec
--        for $402261d"), and the SOUL WARDING shield loop with DIVINE AEGIS
--        absorb accounting (the Pattern 12 interplay: the shield decision
--        counts the PW:S absorb AND the Aegis shield).
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/priest.md: "Penance — the spec's new core button
--        (offensive mode feeds the Smite build below)", "Divine Aegis:
--        critical heals shield the target for 5-15% of the heal — crit-heal
--        absorbs stack on top of PW:S absorbs (Pattern 12 interplay: absorb
--        accounting must track BOTH shields)", "Soul Warding: PW:S cooldown
--        -4s + mana cost -15% — the shield loop spins faster; refresh
--        thresholds re-derive". DBC FINDINGS (1.60.1.69893): Penance ladder
--        402174@30 / 1240720@40 / 1240721@50 / 1316995@60 (the cast row —
--        the internal channel rows 1316991/1316993 win the raw @60 tie, so
--        the cast is pinned in the builder's MAXRANK_OVERRIDES),
--        CategoryRecoveryTime 12000, trainer-taught under Discipline.
--        Divine Aegis: the applied absorb row is 431624 (effect 6 aura 69,
--        base 2) while the rank-1 baseline 431622 is the talent text —
--        pinned in the builder's BUFF_OVERRIDES. Soul Warding 402000:
--        effect rows confirm -4000 ms PW:S cooldown + -15% mana (PW:S itself
--        carries CategoryRecoveryTime 4000, so the loop becomes
--        Weakened-Soul-limited). Renewed Hope 425280 shaves 5s of Weakened
--        Soul on Flash Heal/.../Penance casts and Twin Disciplines 1225132
--        gives instant casts +5% — both passive on the existing lanes, no
--        new lane. Power in Light 1309969 is +15% Smite/Penance damage vs
--        your Holy Fire (the kit's "up to +10%" corrected) and gates the
--        offensive Penance lane.
-- SAFETY: ZERO numeric spell-ID literals — Penance, Soul Warding and Divine
--        Aegis resolve BY NAME through the bridge mirrors; the Holy Fire
--        debuff read reuses the class-map ladder. A nil lookup leaves the
--        lane dormant — never a guessed ID. The vanilla baseline is loaded
--        through an intercepted registration (affliction/demonology_forever
--        template) so this file edits nothing in discipline_vanilla.lua and
--        its safe_state-backed get_state is reused unchanged. The offensive
--        lane mirrors the baseline's group-stable idle gate with its own
--        local check (the baseline's helpers are file-local) so the priest
--        never DPSes while an ally needs healing. Splice geometry: the Soul
--        Warding shield leads the shield block ("PowerWordShieldTank"),
--        Penance-heal leads the heal block ("EmergencyFlashHeal") and
--        Penance-damage the idle block ("IdleSmite"); fallbacks and the
--        append path mirror the other deltas.

local NS = _G.EaxRotations
if not NS then return nil end

local forever = require("shared/spec_kit_forever_delta")

local SPELLS = NS.PriestSpells or {}
local Healing = NS.PriestHealing
if type(Healing) ~= "table" then
    local ok_healing, mod = pcall(require, "classes/priest/healing_sylvanas")
    if ok_healing and type(mod) == "table" then Healing = mod end
end

-- ---------------------------------------------------------------------------
-- Baseline capture: the vanilla baseline is loaded through the shared
-- forever-delta owner (spec_kit_forever_delta.lua) while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, it fails loudly there — a silently missing
-- "discipline" playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local baseline = forever.forever_delta("priest discipline", "classes/priest/discipline_vanilla")

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- Penance cast resolves the maxrank mirror, the learn gates read both
-- mirrors (a mid-level priest has a lower rank learned while the lane casts
-- max rank), Soul Warding and the Divine Aegis absorb read the rank-1/buff
-- mirrors. A nil lookup leaves the lane dormant -- never a guessed ID.
-- Sentinel stand-ins are seeded per mirror by the battery's build_ns so
-- mirror selection itself is pinned.
-- ---------------------------------------------------------------------------
local mirrors = forever.mirrors()
local resolve_id = forever.resolve_id
local by_name, by_maxrank, by_buff = mirrors.name, mirrors.maxrank, mirrors.buff

local PENANCE = resolve_id(by_maxrank, "Penance")
local PENANCE_R1 = resolve_id(by_name, "Penance")
local SOUL_WARDING = resolve_id(by_name, "Soul Warding")
local DIVINE_AEGIS = resolve_id(by_buff, "Divine Aegis")
local HOLY_FIRE_IDS = (SPELLS.HolyFire and SPELLS.HolyFire._meta
    and SPELLS.HolyFire._meta.ids) or nil

-- ---------------------------------------------------------------------------
-- Shared helpers. Penance's DBC cooldown is 12s (CategoryRecoveryTime), the
-- shield loop's PW:S CD is 4s without Soul Warding and 0s with it.
-- ---------------------------------------------------------------------------
local PENANCE_OPTS = { expected_cooldown = 12 }
local CONSUME_MANA_FLOOR = 15
local IDLE_MANA_FLOOR = 35
local GROUP_STABLE_HP = 92
local setting = forever.setting

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

local function aegis_absorb(unit)
    if not unit or not DIVINE_AEGIS or type(NS.buff_points) ~= "function" then return 0 end
    local ok, points = pcall(NS.buff_points, unit, DIVINE_AEGIS)
    if not ok or type(points) ~= "table" then return 0 end
    return points[1] or 0
end

-- Pattern 12 interplay: the shield decision counts BOTH shields — the live
-- PW:S absorb and the Divine Aegis crit-heal shield.
local function combined_absorb(unit)
    local pws = 0
    if type(Healing) == "table" and type(Healing.pws_absorb_remaining) == "function" then
        local ok, absorb = pcall(Healing.pws_absorb_remaining, unit)
        if ok and type(absorb) == "number" then pws = absorb end
    end
    return pws + aegis_absorb(unit)
end

local function holy_fire_up(context)
    if not HOLY_FIRE_IDS or type(NS.debuff_up) ~= "function" then return false end
    local ok, up = pcall(NS.debuff_up, context.target, HOLY_FIRE_IDS)
    return ok and up == true
end

-- ---------------------------------------------------------------------------
-- Delta lanes. The shield lane leads the shield block, Penance-heal the heal
-- block and Penance-damage the idle block.
-- ---------------------------------------------------------------------------
local delta_shield = {}
local delta_heal = {}
local delta_idle = {}

if SOUL_WARDING and knows_any(SOUL_WARDING) then
    delta_shield[#delta_shield + 1] = {
        name = "Forever_SoulWardingShield",
        matches = function(context, s)
            local target = s.tank or s.lowest
            if not target or not target.unit then return false end
            if (target.effective_hp or 100) > setting(context, "discipline_forever_shield_hp", 75) then return false end
            if target.has_weakened_soul then return false end
            if not s.pws_ready then return false end
            if combined_absorb(target.unit) > setting(context, "discipline_forever_shield_absorb", 300) then return false end
            return true
        end,
        execute = function(context, s)
            local target = s.tank or s.lowest
            if not target or not target.unit then return false end
            return NS.try_cast(SPELLS.PowerWordShield, target.unit,
                string.format("[FOREVER-DISC] PW:S (Soul Warding loop) %.0f%%", target.effective_hp or 0))
        end,
    }
end

if PENANCE and knows_any(PENANCE, PENANCE_R1) then
    delta_heal[#delta_heal + 1] = {
        name = "Forever_PenanceHeal",
        matches = function(context, s)
            if context.is_moving then return false end
            if not s.lowest or not s.lowest.unit then return false end
            if (s.lowest.effective_hp or 100) > setting(context, "discipline_forever_penance_hp", 65) then return false end
            if (s.mana_pct or 100) < CONSUME_MANA_FLOOR then return false end
            return NS.spell_ready(PENANCE, s.lowest.unit, PENANCE_OPTS)
        end,
        execute = function(context, s)
            if not s.lowest or not s.lowest.unit then return false end
            return NS.try_cast(PENANCE, s.lowest.unit,
                string.format("[FOREVER-DISC] Penance heal %.0f%%", s.lowest.effective_hp or 0))
        end,
    }

    delta_idle[#delta_idle + 1] = {
        name = "Forever_PenanceDamage",
        matches = function(context, s)
            if context.is_moving then return false end
            if not context.in_combat then return false end
            if not has_valid_enemy(context) then return false end
            if (s.mana_pct or 100) < IDLE_MANA_FLOOR then return false end
            -- Mirror the baseline's group_stable_for_idle_damage (its helper
            -- is file-local): never DPS while an ally sits below 92%.
            if s.lowest and (s.lowest.effective_hp or 100) < GROUP_STABLE_HP then return false end
            if not holy_fire_up(context) then return false end
            return NS.spell_ready(PENANCE, context.target, PENANCE_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(PENANCE, context.target,
                "[FOREVER-DISC] Penance damage (Power in Light window)")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: the Soul Warding shield goes immediately above the
-- baseline's "PowerWordShieldTank" lane (fallback: "EmergencyPowerWordShield"),
-- Penance-heal above "EmergencyFlashHeal" (fallback: "FriendlyTarget") and
-- Penance-damage above "IdleSmite" (fallback: "HolyFire"); then append.
-- Re-registering the playstyle name replaces the baseline wholesale — the
-- combined list IS the "discipline" playstyle on Forever.
-- ---------------------------------------------------------------------------
local SHIELD_ANCHORS = { PowerWordShieldTank = true, EmergencyPowerWordShield = true }
local HEAL_ANCHORS = { EmergencyFlashHeal = true, FriendlyTarget = true }
local IDLE_ANCHORS = { IdleSmite = true, HolyFire = true }

local combined = {}
local shield_done = false
local heal_done = false
local idle_done = false
local function insert_shield()
    if shield_done then return end
    for j = 1, #delta_shield do combined[#combined + 1] = delta_shield[j] end
    shield_done = true
end
local function insert_heal()
    if heal_done then return end
    for j = 1, #delta_heal do combined[#combined + 1] = delta_heal[j] end
    heal_done = true
end
local function insert_idle()
    if idle_done then return end
    for j = 1, #delta_idle do combined[#combined + 1] = delta_idle[j] end
    idle_done = true
end
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name and SHIELD_ANCHORS[name] then insert_shield() end
    if name and HEAL_ANCHORS[name] then insert_heal() end
    if name and IDLE_ANCHORS[name] then insert_idle() end
    combined[#combined + 1] = st
end
insert_shield()
insert_heal()
insert_idle()

baseline.register(combined)
if NS.log then NS.log("Priest discipline Forever delta registered (" ..
    #delta_shield .. " soul-warding shield + " .. #delta_heal .. " penance-heal + " ..
    #delta_idle .. " penance-damage lanes over " .. #baseline.strategies ..
    " baseline lanes)") end

return combined
