-- leveling_forever.lua — Shaman leveling delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 shaman leveling delta over the vanilla baseline: the
--        IMPROVED GHOST WOLF escape lane — the kit's table reads "Ghost
--        Wolf: 2.0s baseline; Improved makes it instant + usable
--        everywhere", so with the talent (16262) learned the wolf becomes
--        an IN-COMBAT disengage: low HP + a mob on you -> shift and run.
--        The baseline's GhostWolf lane only fires OUT of combat (travel,
--        and it skips when a target is within 20y), so this is the missing
--        half of the kit's "mobility lane (kiting, gap-close in Enh)".
-- WHEN:  any combat while leveling, Forever client (class loader prefers
--        _forever over _vanilla).
-- WHY:   docs/forever/kits/shaman.md: "Ghost Wolf: 2.0s baseline; Improved
--        makes it instant + usable everywhere — mobility lane (kiting,
--        gap-close in Enh); instant everywhere also affects
--        disengage/reposition logic" and the leveling bullet "early
--        Stormstrike (8s CD) leveling loop per the page's build sketch,
--        instant Ghost Wolf mobility, early imbues." The other two halves
--        need NO lane: the baseline's stormstrike_ready carries no expected
--        cooldown, so the client's 8s RecoveryTime already drives the
--        existing Stormstrike lane (the class map's stale cooldown = 10
--        data field is never read); the WeaponImbue lane already covers
--        early imbues (Elemental Weapons "pickable much earlier" is a
--        talent-tree position change). DBC FINDINGS (1.60.1.69893): Ghost
--        Wolf 2645 (level 20, "Only useable outdoors" on the base row) and
--        Improved Ghost Wolf 16262 resolve in all three bridge mirrors;
--        the rune variant 415233 adds the damage-taken reduction.
-- SAFETY: ZERO numeric spell-ID literals — Ghost Wolf and the talent gate
--        resolve BY NAME through the bridge mirrors. A nil lookup leaves
--        the lane dormant — never a guessed ID. The vanilla baseline is
--        loaded through an intercepted registration
--        (affliction/demonology_forever template) so this file edits nothing
--        in leveling_vanilla.lua and its safe_state-backed get_state is
--        reused unchanged. The lane skips when the wolf is already up.
--        Splice geometry: the escape lane lands immediately above the
--        baseline's "GhostWolf" travel lane (fallback: "Wand"; then append).

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
-- "leveling" playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local baseline = forever.forever_delta("shaman leveling", "classes/shaman/leveling_vanilla")

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- cast resolves the maxrank mirror, the talent gate the rank-1 mirror, the
-- already-a-wolf check the buff mirror. A nil lookup leaves the lane
-- dormant -- never a guessed ID. Sentinel stand-ins are seeded per mirror
-- by the battery's build_ns so mirror selection itself is pinned.
-- ---------------------------------------------------------------------------
local mirrors = forever.mirrors()
local resolve_id = forever.resolve_id
local by_name, by_maxrank, by_buff = mirrors.name, mirrors.maxrank, mirrors.buff

local GHOST_WOLF = resolve_id(by_maxrank, "Ghost Wolf")
local GHOST_WOLF_R1 = resolve_id(by_name, "Ghost Wolf")
local IMPROVED_GHOST_WOLF = resolve_id(by_name, "Improved Ghost Wolf")
local GHOST_WOLF_BUFF = resolve_id(by_buff, "Ghost Wolf")

-- ---------------------------------------------------------------------------
-- Shared helpers. The escape threshold is menu-tunable; the form check
-- keeps the lane from re-shifting while already a wolf.
-- ---------------------------------------------------------------------------
local ESCAPE_HP = 35

local function setting(context, key, default)
    local settings = context and context.settings
    if settings and settings[key] ~= nil then return settings[key] end
    if NS.get_setting then
        local ok, value = pcall(NS.get_setting, key, default)
        if ok and value ~= nil then return value end
    end
    return default
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

local function wolf_up()
    if not GHOST_WOLF_BUFF or type(NS.buff_up) ~= "function" then return false end
    local ok, up = pcall(NS.buff_up, NS.PLAYER_UNIT, GHOST_WOLF_BUFF)
    return ok and up == true
end

-- ---------------------------------------------------------------------------
-- Delta lanes. The escape lane leads the baseline's out-of-combat travel
-- lane (same button, opposite context).
-- ---------------------------------------------------------------------------
local delta_escape = {}

if GHOST_WOLF and IMPROVED_GHOST_WOLF and knows_any(IMPROVED_GHOST_WOLF) then
    delta_escape[#delta_escape + 1] = {
        name = "Forever_GhostWolfEscape",
        matches = function(context, s)
            if not s or not s.in_combat then return false end
            if (s.hp or 100) > setting(context, "shaman_forever_wolf_escape_hp", ESCAPE_HP) then return false end
            if wolf_up() then return false end
            return NS.spell_ready(GHOST_WOLF, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function(context)
            return NS.try_cast(GHOST_WOLF, NS.PLAYER_UNIT,
                "[FOREVER-LEVELING] Ghost Wolf escape (Improved, in-combat)")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: the escape lane immediately above the baseline's
-- "GhostWolf" travel lane (fallback: "Wand"; then append). Re-registering
-- the playstyle name replaces the baseline wholesale — the combined list IS
-- the "leveling" playstyle on Forever.
-- ---------------------------------------------------------------------------
local ESCAPE_ANCHORS = { GhostWolf = true, Wand = true }

local combined = {}
local escape_done = false
local function insert_escape()
    if escape_done then return end
    for j = 1, #delta_escape do combined[#combined + 1] = delta_escape[j] end
    escape_done = true
end
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name and ESCAPE_ANCHORS[name] then insert_escape() end
    combined[#combined + 1] = st
end
insert_escape()

baseline.register(combined)
if NS.log then NS.log("Shaman leveling Forever delta registered (" ..
    #delta_escape .. " ghost-wolf escape lane over " .. #baseline.strategies ..
    " baseline lanes)") end

return combined
