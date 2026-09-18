-- leveling_forever.lua — Druid leveling delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 druid leveling delta over the vanilla baseline: the OMEN OF
--        CLARITY clearcast weave — with Omen of Clarity now an era-wide
--        baseline proc ("Your spells and attacks have a chance to grant you
--        Clearcasting, reducing the Mana, Rage, or Energy cost of your next
--        damage or healing spell or offensive ability", 16864), the leveling
--        cat fires its EXPENSIVE ability inside the free-cast window: Shred
--        when behind, Claw otherwise — the baseline's flat energy floors
--        (Shred >= 42, Claw >= 45) would otherwise block the free cast.
-- WHEN:  any combat while leveling, Forever client (class loader prefers
--        _forever over _vanilla).
-- WHY:   docs/forever/kits/druid.md: "form-change energy model changes early
--        cat leveling; Omen baseline helps all specs." The form-change half
--        needs NO lane: the Furor rework (probe P2 #1) makes a shift-out/in
--        a capped restore that can never net energy, and the vanilla
--        leveling baseline carries no powershift lane to drop (unlike the
--        cat spec delta, which was destructive for that reason) — recorded
--        in the kit checklist. The Omen half is this lane. DBC FINDINGS
--        (1.60.1.69893): Omen of Clarity resolves as 16864 in all three
--        bridge mirrors; the cat_vanilla precedent (ShredOmen) reads the
--        same id as the clearcast buff, so the leveling lane does the same.
-- SAFETY: ZERO numeric spell-ID literals — Omen of Clarity resolves BY NAME
--        through the buff mirror. A nil lookup leaves the lane dormant —
--        never a guessed ID. The vanilla baseline is loaded through an
--        intercepted registration (affliction/demonology_forever template)
--        so this file edits nothing in leveling_vanilla.lua and its
--        safe_state-backed get_state is reused unchanged. The lane mirrors
--        the baseline's cat-lane gates exactly (cat form, combat, target,
--        the < 5 combo-point overbuild guard) and only waives the energy
--        floors the free cast makes irrelevant. Splice geometry: the
--        clearcast lane lands immediately above the baseline's "Shred"
--        lane (fallback: "Claw"; then append).

local NS = _G.EaxRotations
if not NS then return nil end

local forever = require("shared/spec_kit_forever_delta")

local SPELLS = NS.DruidSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: the vanilla baseline is loaded through the shared
-- forever-delta owner (spec_kit_forever_delta.lua) while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, it fails loudly there — a silently missing
-- "leveling" playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local baseline = forever.forever_delta("druid leveling", "classes/druid/leveling_vanilla")

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- clearcast buff resolves the buff mirror. A nil lookup leaves the lane
-- dormant -- never a guessed ID. Sentinel stand-ins are seeded per mirror by
-- the battery's build_ns so mirror selection itself is pinned.
-- ---------------------------------------------------------------------------
local mirrors = forever.mirrors()
local resolve_id = forever.resolve_id
local by_buff = mirrors.buff

local OMEN_OF_CLARITY = resolve_id(by_buff, "Omen of Clarity")
local SHRED = SPELLS.Shred or nil
local CLAW = SPELLS.Claw or nil

-- ---------------------------------------------------------------------------
-- Shared helpers. The combo-point ceiling mirrors the baseline's cat lanes
-- (never overbuild past a finisher).
-- ---------------------------------------------------------------------------
local CP_CEILING = 5

local function has_valid_enemy(context)
    return context and context.target and context.has_valid_enemy_target ~= false
end

local function clearcasting(context)
    if not OMEN_OF_CLARITY or type(NS.buff_up) ~= "function" then return false end
    local ok, up = pcall(NS.buff_up, context.me, OMEN_OF_CLARITY)
    return ok and up == true
end

-- The expensive pick: Shred from behind, Claw otherwise (both free inside
-- the window).
local function clearcast_pick(context, s)
    if s.is_behind and SHRED and s.shred_ready then return SHRED end
    if CLAW and s.claw_ready then return CLAW end
    return nil
end

-- ---------------------------------------------------------------------------
-- Delta lanes. The clearcast weave leads the cat damage block.
-- ---------------------------------------------------------------------------
local delta_weave = {}

if OMEN_OF_CLARITY and (SHRED or CLAW) then
    delta_weave[#delta_weave + 1] = {
        name = "Forever_OmenClearcast",
        matches = function(context, s)
            if not s or not s.is_cat then return false end
            if not s.in_combat then return false end
            if not s.target then return false end
            if not has_valid_enemy(context) then return false end
            if (s.combo_points or 0) >= CP_CEILING then return false end
            if not clearcasting(context) then return false end
            return clearcast_pick(context, s) ~= nil
        end,
        execute = function(context, s)
            local pick = clearcast_pick(context, s)
            if not pick then return false end
            return NS.try_cast(pick, context.target,
                "[FOREVER-LEVELING] Omen clearcast (free cast)")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: the clearcast lane immediately above the baseline's
-- "Shred" (fallback: "Claw"; then append). Re-registering the playstyle
-- name replaces the baseline wholesale — the combined list IS the
-- "leveling" playstyle on Forever.
-- ---------------------------------------------------------------------------
local WEAVE_ANCHORS = { Shred = true, Claw = true }

local combined = {}
local weave_done = false
local function insert_weave()
    if weave_done then return end
    for j = 1, #delta_weave do combined[#combined + 1] = delta_weave[j] end
    weave_done = true
end
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name and WEAVE_ANCHORS[name] then insert_weave() end
    combined[#combined + 1] = st
end
insert_weave()

baseline.register(combined)
if NS.log then NS.log("Druid leveling Forever delta registered (" ..
    #delta_weave .. " omen-clearcast lane over " .. #baseline.strategies ..
    " baseline lanes)") end

return combined
