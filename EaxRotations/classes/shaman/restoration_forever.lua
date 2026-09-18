-- restoration_forever.lua — Shaman Restoration delta for WoW Forever (beta).
-- WHAT:  Forever kit deltas spliced ON TOP of the vanilla baseline: the
--        RIPTIDE loop (direct heal + 15s HoT, and the DBC-verified +25%
--        Chain Heal amplifier on its target — the keep-Riptide-up cycle)
--        and a WATER SHIELD replacement lane (the Forever rework's globes/
--        orb design replaces the vanilla Lightning Shield default the
--        baseline drops on a resto). Re-registered as the "restoration"
--        playstyle with the vanilla strategies kept below.
-- WHEN:  combat, Forever client (class loader prefers _forever over
--        _vanilla; every other era keeps restoration_vanilla/sylvanas/sod/
--        wotlk untouched).
-- WHY:   docs/forever/kits/shaman.md (Icy Veins class overview, 2026-09-15/
--        17): "Riptide (31-pt capstone): direct heal + HoT + Chain Heal
--        +25% on its target — the keep-Riptide-up loop arrives in Forever;
--        Riptide becomes the most-loaded heal lane" and "New Water Shield:
--        2% mana per orb spent; healing crits can trigger". DBC
--        VERIFICATION (wowsims_forever.db 1.60.1.69893): Riptide ladder
--        408521@40 / 1239242@50 / 1239243@60 under the Restoration skill
--        line (SkillLineAbility 374), each row = direct heal + 3s-tick HoT
--        over 15s (SpellDuration 15000) + a +25% Chain Heal amplifier
--        (EffectIndex 2, base 25), CategoryRecoveryTime 6000 (6s lane CD),
--        1.5s cast. The +25% amp makes Riptide-on-lowest the setup cast for
--        the baseline's ChainHeal lane — the delta lanes sit immediately
--        above "ChainHeal" (positional dispatch: main_sylvanas.lua
--        run_list line 1757 is a first-match list walk; priority fields
--        are inert) so the amp is applied before the
--        multi-target payoff. Healing Way stays the baseline's tank lane
--        (the Forever talent is a flat +25% Healing Wave — no stack upkeep
--        to manage). Mana Tide / Nature's Swiftness / cleanse / totem
--        lanes need no delta.
-- SAFETY: ZERO numeric spell-ID literals — Riptide and Water Shield resolve
--        BY NAME through the DBC-derived bridge mirrors
--        (shared/wowhead_data_bridge_spell_index_forever_sylvanas.lua,
--        pcall-required as an optional module); a nil lookup leaves the
--        lane dormant — never a guessed ID. The vanilla baseline is loaded
--        through an intercepted registration (holy_forever template) so
--        this file edits nothing in restoration_vanilla.lua and its
--        safe_state-backed get_state is reused unchanged. New lanes sit
--        just above the baseline's "ChainHeal" heal — never above an
--        emergency (NaturesSwiftness/ManaTide) lane.

local NS = _G.EaxRotations
if not NS then return nil end

local forever = require("shared/spec_kit_forever_delta")

local SPELLS = NS.ShamanSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: the vanilla baseline is loaded through the shared
-- forever-delta owner (spec_kit_forever_delta.lua) while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, it fails loudly there — a silently missing
-- "restoration" playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local baseline = forever.forever_delta("shaman restoration", "classes/shaman/restoration_vanilla")

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): both
-- lanes resolve through the max-rank mirror (Riptide 1239243@60, the
-- 841-direct/161-tick/+25% amp row; Water Shield 408510@20, the globes
-- rework). A nil lookup leaves the lane dormant -- never a guessed ID.
-- Sentinel stand-ins are seeded per mirror by the battery's build_ns so
-- mirror selection itself is pinned.
-- ---------------------------------------------------------------------------
local mirrors = forever.mirrors()
local resolve_id = forever.resolve_id
local by_name, by_maxrank = mirrors.name, mirrors.maxrank

local RIPTIDE_SPELL = resolve_id(by_maxrank, "Riptide")
local WATER_SHIELD_SPELL = resolve_id(by_maxrank, "Water Shield")
-- The Riptide HoT/amp buff rides the cast's own row family; the debuff/buff
-- read resolves the name through the rank-1 mirror (the lowest cast rank,
-- the family anchor the aura rows share). Distinct from the cast mirror on
-- purpose: mirror SELECTION is pinned by the unit suite (19000/19100 ranges).
local RIPTIDE_BUFF = resolve_id(by_name, "Riptide")

-- ---------------------------------------------------------------------------
-- Shared helpers and Forever constants. Thresholds are menu-tunable via
-- spec_kit.setting; "estimated" values are tuned on beta day.
-- ---------------------------------------------------------------------------
local EMPTY_OPTS = {}
local RIPTIDE_OPTS = { expected_cooldown = 6 }   -- DBC CategoryRecoveryTime 6000
local RIPTIDE_MIN_REMAINS = 3                    -- re-apply while the amp expires
local RIPTIDE_HP_CEILING = 90                    -- don't waste the direct heal
local RIPTIDE_MANA_FLOOR = 20
local WATER_SHIELD_MANA_FLOOR = 25

local setting = forever.setting

-- Live-buff probe on an ally entry (the heal-scan shape: .unit + optional
-- remains helper). The baseline's own state carries no per-ally aura data,
-- so the HoT read goes through NS.buff_remains on the entry's unit — the
-- same read shape the vanilla HealingWay stack gate uses on state.tank.
local function buff_remains_on(unit, ids)
    if not unit then return 0 end
    if not NS.buff_remains then return 0 end
    return NS.buff_remains(unit, ids) or 0
end

-- ---------------------------------------------------------------------------
-- Delta lanes. Rotational deltas only in this file: the Riptide setup lane
-- sits immediately above the baseline's "ChainHeal" lane (the amp must be
-- applied before the Chain Heal payoff reads the target), and the Water
-- Shield replacement replaces the baseline's Lightning Shield position.
-- ---------------------------------------------------------------------------

local delta_heal = {}
local delta_shield = {}

-- Riptide on the lowest ally: the +25% Chain Heal amplifier's setup cast.
-- Priority shape: apply/maintain Riptide on the ally the baseline's
-- ChainHeal lane will target (state.lowest — the same entry), so the very
-- next Chain Heal pays the amp. Holds when the lowest ally is healthy
-- (no direct-heal waste), the HoT is comfortably up, or mana is floored.
if RIPTIDE_SPELL then
    delta_heal[#delta_heal + 1] = {
        name = "Forever_RiptideAmpSetup",
        matches = function(context, s)
            local lowest = s and s.lowest
            if not lowest or not lowest.unit then return false end
            if (s.mana_pct or 100) < setting(context, "resto_forever_riptide_mana_floor", RIPTIDE_MANA_FLOOR) then return false end
            if (lowest.effective_hp or 100) > setting(context, "resto_forever_riptide_hp_ceiling", RIPTIDE_HP_CEILING) then return false end
            if buff_remains_on(lowest.unit, RIPTIDE_BUFF) > setting(context, "resto_forever_riptide_min_remains", RIPTIDE_MIN_REMAINS) then return false end
            return NS.spell_ready(RIPTIDE_SPELL, lowest.unit, RIPTIDE_OPTS)
        end,
        execute = function(context, s)
            local lowest = s and s.lowest
            if not lowest or not lowest.unit then return false end
            return NS.try_cast(RIPTIDE_SPELL, lowest.unit,
                string.format("[FOREVER-RESTO] Riptide (amp setup, %.0f%%)",
                    lowest.effective_hp or 0))
        end,
    }
end

-- Water Shield replacement (Forever rework: globes refund mana on hit and
-- on healing crits — the resto default shield; the vanilla baseline drops
-- Lightning Shield instead). Self-buff lane in the baseline's
-- LightningShield slot position; holds while any Elemental Shield is up
-- (the client enforces one shield — the baseline's has_lightning_shield
-- read is the same "already shielded" probe shape).
if WATER_SHIELD_SPELL then
    delta_shield[#delta_shield + 1] = {
        name = "Forever_WaterShieldDefault",
        matches = function(context, s)
            if not s or not s.in_combat then return false end
            if (s.mana_pct or 100) < setting(context, "resto_forever_ws_mana_floor", WATER_SHIELD_MANA_FLOOR) then return false end
            -- Reuse the baseline's own shield-state read: if a shield buff is
            -- already up, hold (the client allows one Elemental Shield).
            if s.has_lightning_shield then return false end
            return NS.spell_ready(WATER_SHIELD_SPELL, NS.PLAYER_UNIT, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(WATER_SHIELD_SPELL, NS.PLAYER_UNIT,
                "[FOREVER-RESTO] Water Shield (orb mana return)")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: the heal lane goes above the baseline's "ChainHeal"
-- lane (amp before payoff); the shield lane goes above the baseline's
-- "LightningShield" lane (replacing the shield choice, not shadowing any
-- emergency lane). Re-registering the playstyle name replaces the baseline
-- wholesale — the combined list IS the "restoration" playstyle on Forever.
-- ---------------------------------------------------------------------------
local combined = {}
local shield_inserted = false
local heal_inserted = false
local function insert_shield()
    if shield_inserted then return end
    for j = 1, #delta_shield do combined[#combined + 1] = delta_shield[j] end
    shield_inserted = true
end
local function insert_heal()
    if heal_inserted then return end
    for j = 1, #delta_heal do combined[#combined + 1] = delta_heal[j] end
    heal_inserted = true
end
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name == "LightningShield" then insert_shield() end
    if name == "ChainHeal" then insert_heal() end
    combined[#combined + 1] = st
end
-- Fallbacks (baseline lane renamed/removed): shield after NaturesSwiftness,
-- heal after HealingWay, then append at the end.
if not shield_inserted then
    for i = 1, #combined do
        local st = combined[i]
        if type(st) == "table" and st.name == "NaturesSwiftness" then
            insert_shield()
            break
        end
    end
    insert_shield()
end
if not heal_inserted then
    for i = 1, #combined do
        local st = combined[i]
        if type(st) == "table" and st.name == "HealingWay" then
            insert_heal()
            break
        end
    end
    insert_heal()
end

baseline.register(combined)
if NS.log then NS.log("Shaman restoration Forever delta registered (" ..
    #delta_shield .. " shield + " .. #delta_heal ..
    " heal lanes over " .. #baseline.strategies .. " baseline lanes)") end

return combined
