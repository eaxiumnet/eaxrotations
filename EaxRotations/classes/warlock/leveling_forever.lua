-- leveling_forever.lua — Warlock leveling delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 warlock leveling delta over the vanilla baseline: the
--        BANES-NOT-CURSES pair — with Bane of Agony and Curse of the
--        Elements in separate aura families on this client ("Bane of Havoc
--        is limited to 1 target, and only one Bane per Warlock can be
--        active on any one target" — the family texts name Banes, not
--        Curses), the leveling rotation maintains BOTH: the baseline's Bane
--        of Agony dot lane stays, and this lane applies CURSE OF THE
--        ELEMENTS alongside it for long-lived targets.
-- WHEN:  any combat while leveling, Forever client (class loader prefers
--        _forever over _vanilla).
-- WHY:   docs/forever/kits/warlock.md: "Banes are no longer Curses (Bane of
--        Agony/Doom) — Curse-slot collision gone: maintain Bane of Agony
--        AND Curse of the Elements/Recklessness simultaneously — dot-count
--        and debuff-tracking lanes change shape" and the leveling bullet
--        "Banes-not-curses slot math from early levels". The kit's pet-Move-
--        To half is explicitly "no rotation-lane impact" (the API exposes no
--        move command) — recorded, no lane. DBC FINDINGS (1.60.1.69893):
--        Curse of the Elements resolves as 440892 (rank-1) / 1311680
--        (maxrank) in the bridge mirrors; the Bane of Agony debuff read uses
--        the class-map CurseOfAgony ladder (the same ids the baseline's own
--        CURSE_OF_AGONY_IDS list carries, so every leveling rank resolves).
--        [PROBE (P3): the in-game slot mechanics — if a Bane and a Curse
--        turn out to share one slot after all, this lane would churn against
--        the baseline's Bane lane and must be removed.]
-- SAFETY: ZERO numeric spell-ID literals — Curse of the Elements resolves
--        BY NAME through the bridge mirrors and the Bane read reuses the
--        class map. A nil lookup leaves the lane dormant — never a guessed
--        ID. The vanilla baseline is loaded through an intercepted
--        registration (affliction/demonology_forever template) so this file
--        edits nothing in leveling_vanilla.lua and its safe_state-backed
--        get_state is reused unchanged. The lane mirrors the baseline's
--        curse-lane guards (leveling context, combat, target, a mana floor)
--        and requires the Bane to be up first. Splice geometry: the lane
--        lands immediately above the baseline's "SiphonLife" lane — i.e.
--        directly BELOW its "CurseOfAgony" (Bane-first, amp-second).

local NS = _G.EaxRotations
if not NS then return nil end

local forever = require("shared/spec_kit_forever_delta")

local leveling = require("shared/leveling_sylvanas")
local SPELLS = NS.WarlockSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: the vanilla baseline is loaded through the shared
-- forever-delta owner (spec_kit_forever_delta.lua) while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, it fails loudly there — a silently missing
-- "leveling" playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local baseline = forever.forever_delta("warlock leveling", "classes/warlock/leveling_vanilla")

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- Curse cast + debuff read resolve the bridge mirrors (both rungs), the
-- Bane read the class-map ladder. A nil lookup leaves the lane dormant --
-- never a guessed ID. Sentinel stand-ins are seeded per mirror by the
-- battery's build_ns so mirror selection itself is pinned.
-- ---------------------------------------------------------------------------
local mirrors = forever.mirrors()
local resolve_id = forever.resolve_id
local by_name, by_maxrank = mirrors.name, mirrors.maxrank

local CURSE_OF_ELEMENTS = resolve_id(by_maxrank, "Curse of the Elements")
local CURSE_OF_ELEMENTS_R1 = resolve_id(by_name, "Curse of the Elements")
local CURSE_OF_ELEMENTS_IDS = { CURSE_OF_ELEMENTS, CURSE_OF_ELEMENTS_R1 }
local BANE_OF_AGONY_IDS = (SPELLS.CurseOfAgony and SPELLS.CurseOfAgony._meta
    and SPELLS.CurseOfAgony._meta.ids) or nil

-- ---------------------------------------------------------------------------
-- Shared helpers. The mana floor mirrors the baseline's curse-lane spirit
-- (leveling warlocks tap/drain around 30% mana).
-- ---------------------------------------------------------------------------
local MANA_FLOOR = 25
local COE_REFRESH = 2

local context_allowed = leveling.create_context_guard()

local function setting(context, key, default)
    local settings = context and context.settings
    if settings and settings[key] ~= nil then return settings[key] end
    if NS.get_setting then
        local ok, value = pcall(NS.get_setting, key, default)
        if ok and value ~= nil then return value end
    end
    return default
end

local function debuff_remains(target, ids)
    if not target or not ids or type(NS.debuff_remains) ~= "function" then return 0 end
    local ok, remains = pcall(NS.debuff_remains, target, ids)
    if ok and type(remains) == "number" then return remains end
    return 0
end

-- ---------------------------------------------------------------------------
-- Delta lanes. The amp lane sits below the Bane lane: the dot first, the
-- curse alongside it.
-- ---------------------------------------------------------------------------
local delta_amp = {}

if CURSE_OF_ELEMENTS and BANE_OF_AGONY_IDS then
    delta_amp[#delta_amp + 1] = {
        name = "Forever_CurseOfElements",
        matches = function(context, s)
            if not context_allowed(context) then return false end
            if not s or not s.target then return false end
            if not s.in_combat then return false end
            if (s.mana_pct or 100) < setting(context, "warlock_forever_coe_mana", MANA_FLOOR) then return false end
            -- The pair: the Bane must already be rolling (Banes and Curses
            -- are separate families on this client — the kit's slot math).
            if debuff_remains(s.target, BANE_OF_AGONY_IDS) <= 0 then return false end
            if debuff_remains(s.target, CURSE_OF_ELEMENTS_IDS) > setting(context, "warlock_forever_coe_refresh", COE_REFRESH) then
                return false
            end
            return NS.spell_ready(CURSE_OF_ELEMENTS, s.target)
        end,
        execute = function(context, s)
            return NS.try_cast(CURSE_OF_ELEMENTS, s.target,
                "[FOREVER-LEVELING] Curse of the Elements (Bane pair)")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: the amp lane lands immediately above the baseline's
-- "SiphonLife" lane — directly below its "CurseOfAgony" (Bane first, amp
-- second; fallback: "DrainLife"; then append). Re-registering the playstyle
-- name replaces the baseline wholesale — the combined list IS the
-- "leveling" playstyle on Forever.
-- ---------------------------------------------------------------------------
local AMP_ANCHORS = { SiphonLife = true, DrainLife = true }

local combined = {}
local amp_done = false
local function insert_amp()
    if amp_done then return end
    for j = 1, #delta_amp do combined[#combined + 1] = delta_amp[j] end
    amp_done = true
end
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name and AMP_ANCHORS[name] then insert_amp() end
    combined[#combined + 1] = st
end
insert_amp()

baseline.register(combined)
if NS.log then NS.log("Warlock leveling Forever delta registered (" ..
    #delta_amp .. " curse-of-elements pair lane over " .. #baseline.strategies ..
    " baseline lanes)") end

return combined
