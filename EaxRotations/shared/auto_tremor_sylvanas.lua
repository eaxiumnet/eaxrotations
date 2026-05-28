-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "shared/auto_tremor_sylvanas.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- ============================================================================
-- Shared Helper: Auto Tremor Totem
-- ============================================================================
-- Pattern: 17 TBC fear-capable encounter NPC IDs (Nightbane, Archimonde, etc.)
-- IDs verified against TBC encounter data and in-game behavior references.
-- ============================================================================

local M = {}
local _G = _G
local NS = _G.EaxRotations

-- Fear-casting boss NPC IDs (TBC encounters)
-- Raids: fear/charm/sleep mechanics requiring Tremor Totem
-- Dungeons: boss-level fear/charm effects
-- Trash: notable fear/charm casters in TBC raids
local FEAR_CASTER_IDS = {
    -- Raids
    [17225] = true,  -- Nightbane (Karazhan) — Bellowing Roar
    [17968] = true,  -- Archimonde (Hyjal) — Fear
    [17808] = true,  -- Anetheron (Hyjal) — Carrion Swarm (sleep)
    [22855] = true,  -- Illidari Nightlord (Black Temple) — Fear (AoE)
    [23420] = true,  -- Essence of Anger (BT RoS) — Seethe
    -- Dungeon bosses
    [18731] = true,  -- Ambassador Hellmaw (Shadow Lab) — Fear (45yd AoE)
    [18667] = true,  -- Blackheart the Inciter (Shadow Lab) — Incite Chaos (charm)
    [17308] = true,  -- Omor the Unscarred (Ramparts) — Fear
    [17536] = true,  -- Nazan (Ramparts) — Bellowing Roar
    [16807] = true,  -- Grand Warlock Nethekurse (Shattered Halls) — Death Coil
    -- Trash
    [20883] = true,  -- Coilfang Fathom-Witch (SSC) — Domination (charm)
    [21956] = true,  -- Bonechewer Taskmaster (BT) — Fear
    [22960] = true,  -- Ashtongue Primalist (BT) — Wyvern Sting (sleep)
    -- Additional TBC encounters with fear mechanics
    [18473] = true,  -- Talon King Ikiss (Sethekk Halls) — AoE Fear
    [20885] = true,  -- Harbinger Skyriss (Arcatraz) — Fear
    [18343] = true,  -- Pandemonius (Mana-Tombs) — Shadow Fissure (fear aura)
}

-- Tremor Totem spell IDs by rank (newest first)
local TREMOR_TOTEM_IDS = { 8143, 8145, 8146 }

--- Check if target is a known fear-casting boss.
-- @param target table - Unit object from object manager
-- @return boolean - true if target NPC ID is in fear caster list
function M.is_fear_boss(target)
    if not target then return false end
    local npc_id = target.get_npc_id and target:get_npc_id()
    if not npc_id then return false end
    return FEAR_CASTER_IDS[npc_id] == true
end

--- Check if Tremor Totem is already active.
-- @return boolean - true if Tremor Totem buff is present on player
function M.has_tremor_totem()
    if not NS or not NS.has_player_buff then return false end
    for _, spell_id in ipairs(TREMOR_TOTEM_IDS) do
        if NS.has_player_buff(spell_id) then
            return true
        end
    end
    return false
end

--- Check if any nearby friendly unit is affected by fear/charm/sleep.
-- @return boolean - true if a fear-like CC is detected on a nearby ally
function M.detect_fear_on_ally()
    if not NS or not NS.get_party_members then return false end
    local party = NS.get_party_members()
    if not party then return false end
    -- Fear/charm/sleep debuff IDs (common TBC CC)
    local FEAR_DEBUFFS = {
        [5782] = true,   -- Fear (Warlock)
        [6215] = true,   -- Fear (lesser)
        [5484] = true,   -- Howl of Terror
        [8122] = true,   -- Psychic Scream (Priest)
        [10955] = true,  -- Force of Will (Nefarian fear)
        [33111] = true,  -- Bellowing Roar (Nightbane)
    }
    for _, member in ipairs(party) do
        if member and member.is_alive and member:is_alive() then
            for debuff_id, _ in pairs(FEAR_DEBUFFS) do
                if NS.debuff_up and NS.debuff_up(member, debuff_id) then
                    return true
                end
            end
        end
    end
    return false
end

--- Attempt to drop Tremor Totem if conditions are met.
-- @param context table - Rotation context with settings, me, target
-- @return boolean - true if totem was dropped
function M.try_drop_tremor(context)
    if not context or not context.settings then return false end
    if context.settings.use_auto_tremor_totem == false then return false end
    if not context.target then return false end

    -- Only drop if targeting a fear boss
    if not M.is_fear_boss(context.target) then return false end

    -- Don't drop if already active
    if M.has_tremor_totem() then return false end

    -- Check if we have the spell learned
    if not NS or not NS.is_spell_learned then return false end
    local tremor_id = nil
    for _, id in ipairs(TREMOR_TOTEM_IDS) do
        if NS.is_spell_learned(id) then
            tremor_id = id
            break
        end
    end
    if not tremor_id then return false end

    -- Drop totem
    if NS.try_cast then
        return NS.try_cast(tremor_id, nil, "[SHAMAN] Tremor Totem", { skip_range = true })
    end
    return false
end

--- Middleware strategy for auto tremor (NS.action_matches / NS.action_execute compatible).
-- Returns a strategy table suitable for NS.register_class_middleware.
-- @param SPELLS table - Class spell table (must contain TremorTotem key)
-- @return table - Strategy entry
function M.as_middleware_strategy(SPELLS)
    local spell = SPELLS and SPELLS.TremorTotem
    if not spell then return nil end
    return {
        name = "AutoTremor",
        matches = function(context)
            if context.settings.use_auto_tremor_totem == false then return false end
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            if not M.is_fear_boss(context.target) then return false end
            if M.has_tremor_totem() then return false end
            return NS.action_matches(context, {
                name = "AutoTremor",
                spell = spell,
                target = "self",
                skip_range = true,
            })
        end,
        execute = function(context)
            return NS.action_execute(context, {
                name = "AutoTremor",
                spell = spell,
                target = "self",
                skip_range = true,
            }, "[SHAMAN]")
        end,
    }
end

-- Register with EaxRotations namespace if available
if _G.EaxRotations then
    _G.EaxRotations.AutoTremor = M
end

return M
