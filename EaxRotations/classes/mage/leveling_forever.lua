-- leveling_forever.lua — Mage leveling delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 mage leveling delta over the vanilla baseline: the HOT STREAK
--        spend — the leveling fire branch gains the Forever stacking-proc
--        lane (3 crit-fueled stacks, 15s, each stack cutting Pyroblast's
--        cast; spent at the DBC-confirmed 3-stack cap) exactly as the fire
--        spec delta carries it.
-- WHEN:  any combat while leveling, Forever client (class loader prefers
--        _forever over _vanilla).
-- WHY:   docs/forever/kits/mage.md: "Hot Streak — non-periodic Fire crits
--        (Fireball/Frostfire/Fire Blast/Scorch) stack up to 3x, 15s; each
--        stack cuts Pyroblast cast -25% ... consumed on cast" (DBC-CONFIRMED
--        2026-09-17: 400625 CumulativeAura=3) and the leveling bullet
--        "school-swap Frostfire for resist-varying leveling targets; Hot
--        Streak availability timing." The FROSTFIRE half stays DELIBERATELY
--        ABSENT: the kit's own unconfirmed list says the lower-resist
--        mechanic "needs DBC proof before any school-choice lane encodes it"
--        — a guessed school-swap is worse than a missing one; the plain
--        Frostfire Bolt nuke is likewise not a leveling lane the kit asks
--        for. DBC FINDINGS (1.60.1.69893): Hot Streak resolves as 400625 in
--        the buff mirror (the builder's BUFF_OVERRIDES pin); Pyroblast is
--        era-shared from the class map.
-- SAFETY: ZERO numeric spell-ID literals — Hot Streak resolves BY NAME
--        through the buff mirror; the spent spell (Pyroblast) is era-shared
--        from the class map. A nil lookup leaves the lane dormant — never a
--        guessed ID. The vanilla baseline is loaded through an intercepted
--        registration (affliction/demonology_forever template) so this file
--        edits nothing in leveling_vanilla.lua and its safe_state-backed
--        get_state is reused unchanged. The lane mirrors the baseline's fire
--        nuke gates (target, combat, movement, the 10% mana floor) and the
--        fire spec delta's stack handling (a 0/nil stack read fails open to
--        the presence gate). Splice geometry: the lane lands immediately
--        above the baseline's "Fireball" (fallback: "Scorch"; then append).

local NS = _G.EaxRotations
if not NS then return nil end

local forever = require("shared/spec_kit_forever_delta")

local SPELLS = NS.MageSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: the vanilla baseline is loaded through the shared
-- forever-delta owner (spec_kit_forever_delta.lua) while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, it fails loudly there — a silently missing
-- "leveling" playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local baseline = forever.forever_delta("mage leveling", "classes/mage/leveling_vanilla")

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- proc resolves the buff mirror. A nil lookup leaves the lane dormant --
-- never a guessed ID. Sentinel stand-ins are seeded per mirror by the
-- battery's build_ns so mirror selection itself is pinned.
-- ---------------------------------------------------------------------------
local mirrors = forever.mirrors()
local resolve_id = forever.resolve_id
local by_buff = mirrors.buff

local HOT_STREAK_BUFF = resolve_id(by_buff, "Hot Streak")
local PYROBLAST = SPELLS.Pyroblast or nil

-- ---------------------------------------------------------------------------
-- Shared helpers. The spend waits for the DBC-confirmed 3-stack cap; a
-- 0/nil stack read fails open to the presence gate (a degraded aura API must
-- not stall the finisher).
-- ---------------------------------------------------------------------------
local HS_SPEND_STACKS = 3
local MANA_FLOOR = 10

local function setting(context, key, default)
    local settings = context and context.settings
    if settings and settings[key] ~= nil then return settings[key] end
    if NS.get_setting then
        local ok, value = pcall(NS.get_setting, key, default)
        if ok and value ~= nil then return value end
    end
    return default
end

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

local function player_buff_up(id)
    if not id then return false end
    if type(NS.has_player_buff) == "function" then
        local ok, up = pcall(NS.has_player_buff, id)
        if ok then return up == true end
    end
    if type(NS.buff_up) ~= "function" then return false end
    local ok, up = pcall(NS.buff_up, NS.PLAYER_UNIT, id)
    return ok and up == true
end

-- ---------------------------------------------------------------------------
-- Delta lanes. The Hot Streak spend leads the fire nuke block.
-- ---------------------------------------------------------------------------
local delta_pyro = {}

if HOT_STREAK_BUFF and PYROBLAST then
    delta_pyro[#delta_pyro + 1] = {
        name = "Forever_HotStreakPyro",
        matches = function(context, s)
            if not s or not s.target then return false end
            if not s.in_combat then return false end
            if s.is_moving then return false end
            if (s.mana_pct or 100) < setting(context, "mage_leveling_hs_mana_floor", MANA_FLOOR) then return false end
            if not has_valid_enemy(context) then return false end
            if not player_buff_up(HOT_STREAK_BUFF) then return false end
            local stacks = 0
            if type(NS.buff_stacks) == "function" then
                local ok, read = pcall(NS.buff_stacks, NS.PLAYER_UNIT, { HOT_STREAK_BUFF })
                if ok and type(read) == "number" then stacks = read end
            end
            if stacks > 0 and stacks < setting(context, "mage_leveling_hs_spend_stacks", HS_SPEND_STACKS) then
                return false
            end
            return NS.spell_ready(PYROBLAST, s.target)
        end,
        execute = function(context, s)
            return NS.try_cast(PYROBLAST, s.target,
                "[FOREVER-LEVELING] Hot Streak fast Pyroblast")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: the spend lane immediately above the baseline's
-- "Fireball" (fallback: "Scorch"; then append). Re-registering the playstyle
-- name replaces the baseline wholesale — the combined list IS the
-- "leveling" playstyle on Forever.
-- ---------------------------------------------------------------------------
local PYRO_ANCHORS = { Fireball = true, Scorch = true }

local combined = {}
local pyro_done = false
local function insert_pyro()
    if pyro_done then return end
    for j = 1, #delta_pyro do combined[#combined + 1] = delta_pyro[j] end
    pyro_done = true
end
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name and PYRO_ANCHORS[name] then insert_pyro() end
    combined[#combined + 1] = st
end
insert_pyro()

baseline.register(combined)
if NS.log then NS.log("Mage leveling Forever delta registered (" ..
    #delta_pyro .. " hot-streak lane over " .. #baseline.strategies ..
    " baseline lanes)") end

return combined
