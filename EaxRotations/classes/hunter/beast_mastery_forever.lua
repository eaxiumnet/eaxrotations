-- beast_mastery_forever.lua — Hunter Beast Mastery delta for WoW Forever (beta 2026-09-17).
-- WHAT:  ADDITIVE day-1 BM delta over the vanilla baseline: a Summon Hawk
--        lane (the capstone-adjacent hawk assault — DBC: 6s cooldown in the
--        SAME SpellCategory as Arcane Shot, 18s lifespan) spliced
--        immediately above the baseline's Arcane Shot filler, so the shared
--        cooldown spends on hawk maintenance while hawks are cycling and
--        Arcane Shot only fills when the hawk lane is dormant.
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/hunter.md (Icy Veins overview 2026-09-15; beta DBC
--        2026-09-17): "Summon Hawk (capstone-adjacent talent): shares CD with
--        Arcane Shot; hawk attacks for up to 18s; max 2 hawks active
--        alongside the pet. Rotation keeps 2 hawks up and weaves shots
--        between — Arcane Shot becomes a hawk-refresh decision, not a
--        filler." The DBC CONFIRMS the shared cooldown (both in SpellCategory
--        1173, CategoryRecoveryTime 6000), the 18s lifespan (SpellDuration 85
--        on the summon row 1293248) and CORRECTS the cap: the client text
--        says "Only 3 hawks can be active at once". Three hawks at a 6s
--        shared CD expire exactly as the fourth cast lands, so casting on
--        cooldown IS the maintenance loop; the engine enforces the cap and no
--        guardian-count API exists to pre-check it (documented probe).
-- SAFETY: ZERO numeric spell-ID literals — Summon Hawk resolves BY NAME
--        through the maxrank mirror (1293527@60, the top rank of the
--        1293241@25 / 1293525@36 / 1293526@48 / 1293527@60 ladder); a nil
--        lookup leaves the lane dormant — never a guessed ID. Sentinel
--        stand-ins are seeded per mirror by the battery's build_ns so mirror
--        selection itself is pinned. The vanilla baseline is loaded through
--        an intercepted registration (holy_forever template) so this file
--        edits nothing in beast_mastery_vanilla.lua, and its safe_state-backed
--        get_state is reused unchanged. Splice geometry: the hawk lane lands
--        immediately above the baseline's "ArcaneShot" lane (below the
--        cooldowns/pet/defensive lanes), so it wins the shared cooldown
--        without shadowing anything defensive.

local NS = _G.EaxRotations
if not NS then return nil end

local forever = require("shared/spec_kit_forever_delta")

local SPELLS = NS.HunterSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: the vanilla baseline is loaded through the shared
-- forever-delta owner (spec_kit_forever_delta.lua) while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, it fails loudly there — a silently missing
-- "beast_mastery" playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local baseline = forever.forever_delta("hunter beast_mastery", "classes/hunter/beast_mastery_vanilla")

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- hawk CAST resolves through the maxrank mirror. A nil lookup leaves the
-- lane dormant -- never a guessed ID.
-- ---------------------------------------------------------------------------
local mirrors = forever.mirrors()
local resolve_id = forever.resolve_id
local by_maxrank = mirrors.maxrank

local SUMMON_HAWK = resolve_id(by_maxrank, "Summon Hawk")

-- ---------------------------------------------------------------------------
-- Shared helpers and Forever constants. Thresholds are menu-tunable via
-- spec_kit.setting; "estimated" values are tuned on beta day.
-- ---------------------------------------------------------------------------
local EMPTY_OPTS = {}

-- DBC-confirmed: CategoryRecoveryTime 6000 in SpellCategory 1173 (the same
-- category as Arcane Shot 3044/14287) — the shared cooldown is real.
local FOREVER_HAWK_CD = 6
local FOREVER_HAWK_MANA_FLOOR = 20

local setting = forever.setting

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

-- ---------------------------------------------------------------------------
-- Delta lane. One hawk-refresh lane, above the Arcane Shot filler that
-- shares its cooldown.
-- ---------------------------------------------------------------------------

local delta_hawk = {}

if SUMMON_HAWK then
    delta_hawk[#delta_hawk + 1] = {
        name = "Forever_SummonHawk",
        matches = function(context, s)
            if not s.in_combat then return false end
            if not has_valid_enemy(context) then return false end
            if (s.mana_pct or 100) < setting(context, "bm_forever_hawk_mana_floor", FOREVER_HAWK_MANA_FLOOR) then return false end
            return NS.spell_ready(SUMMON_HAWK, context.target, { expected_cooldown = FOREVER_HAWK_CD })
        end,
        execute = function(context)
            return NS.try_cast(SUMMON_HAWK, context.target,
                "[FOREVER-BM] Summon Hawk (shared CD with Arcane Shot)")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: the hawk lane goes immediately above the baseline's
-- "ArcaneShot" lane (fallback: above "SerpentSting"; then append).
-- Re-registering the playstyle name replaces the baseline wholesale — the
-- combined list IS the "beast_mastery" playstyle on Forever.
-- ---------------------------------------------------------------------------
local ANCHORS = { ArcaneShot = true, SerpentSting = true }

local combined = {}
local hawk_inserted = false
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    if not hawk_inserted and type(st) == "table" and ANCHORS[st.name] then
        for j = 1, #delta_hawk do combined[#combined + 1] = delta_hawk[j] end
        hawk_inserted = true
    end
    combined[#combined + 1] = st
end
if not hawk_inserted then
    for j = 1, #delta_hawk do combined[#combined + 1] = delta_hawk[j] end
end

baseline.register(combined)
if NS.log then NS.log("Hunter beast_mastery Forever delta registered (" ..
    #delta_hawk .. " hawk lane over " .. #baseline.strategies ..
    " baseline lanes)") end

return combined
