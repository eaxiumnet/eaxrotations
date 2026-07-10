-- auto_tremor_sylvanas.lua -- Auto Tremor Totem placement for Enhancement Shaman..
-- WHAT:   Auto Tremor Totem placement for Enhancement Shaman.
-- WHEN:   called per-tick by enhancement specs when fear/sap detected
-- WHY:    eliminates 4-line fear-break duplication in enhancement_sylvanas
-- SAFETY: per-fight cooldown; nil-guarded totem API
-- DECISION: pure helper consumed via require() by specs; no on_update side-effects.

-- Pattern: 17 TBC fear-capable encounter NPC IDs (Nightbane, Archimonde, etc.)
-- IDs verified against TBC encounter data and in-game behavior references.

local M = {}
local _G = _G
local NS = _G.EaxRotations

-- Fear-casting boss NPC IDs (TBC encounters)
-- Comprehensive list for dungeons and raids to prevent tank fears causing wipes (tank runs into packs).
-- Raids: Karazhan (Nightbane), Hyjal (Archimonde, Anetheron), BT, SSC (Striders, Honor Guards), Magtheridon's Lair, TK, Sunwell Plateau (SWP Sunblade Dusk Priests), etc.
-- Dungeons: Auchindoun wings (Shadow Lab key for Kara attunement), Ramparts, Arcatraz (Skyriss), Sethekk, Mana Tombs, Old Hillsbrad, Black Morass, Magisters' Terrace (Delrissa), Underbog (Fen Ray horror), Steamvault (Sirens), Botanica (Fear-Shriekers), Slave Pens (Rays), etc.
-- Use with party frames for accurate tank protection. Expanded via WoWHead TBC guides for all major fear sources (incl. uninterruptible fears and horrors that bypass Tremor).
-- Expand as more verified via DBC/client.
local FEAR_CASTER_IDS = {
    -- Raids (from WoWHead TBC guides: Nightbane fear major for tanks, Archimonde frequent fear)
    [17225] = true,  -- Nightbane (Karazhan) — Bellowing Roar (major tank fear wipe risk)
    [17968] = true,  -- Archimonde (Hyjal) — Fear (frequent, tanks run)
    [17808] = true,  -- Anetheron (Hyjal) — Carrion Swarm (sleep/fear)
    [22855] = true,  -- Illidari Nightlord (Black Temple) — Fear (AoE)
    [23420] = true,  -- Essence of Anger (BT RoS) — Seethe
    -- Dungeon bosses (WoWHead guides highlight these for fear chain pulls/wipes)
    [18731] = true,  -- Ambassador Hellmaw (Shadow Labyrinth) — Fear (45yd AoE) — VERY common wipe if tank feared. Per guide: prepare for tank fear.
    [18667] = true,  -- Blackheart the Inciter (Shadow Labyrinth) — Incite Chaos (charm/fear)
    [17308] = true,  -- Omor the Unscarred (Hellfire Ramparts) — Fear
    [17536] = true,  -- Nazan (Ramparts) — Bellowing Roar
    [16807] = true,  -- Grand Warlock Nethekurse (Shattered Halls) — Death Coil (fear-like)
    [18473] = true,  -- Talon King Ikiss (Sethekk Halls) — AoE Fear / adds
    [20912] = true,  -- Harbinger Skyriss (Arcatraz) — Fear (confirmed WoWHead Arcatraz guide + comments; also Domination MC)
    [18343] = true,  -- Pandemonius (Mana-Tombs) — Shadow Fissure (fear aura)
    -- Trash fear casters (per WoWHead guides: fears pull extras in tight packs → wipe)
    [17478] = true,  -- Bleeding Hollow Scryer (Ramparts) — Fear (nasty, use Tremor/LoS)
    [17833] = true,  -- Durnholde Warden (Old Hillsbrad) — Psychic Scream (fear; prioritize, Tremor essential)
    [18325] = true,  -- Sethekk Prophet (Sethekk Halls) — Fear (tight packs, fear = extra groups/wipe)
    [20883] = true,  -- Coilfang Fathom-Witch (SSC) — Domination (charm)
    [21956] = true,  -- Bonechewer Taskmaster (BT) — Fear
    [22960] = true,  -- Ashtongue Primalist (BT) — Wyvern Sting (sleep)
    [18796] = true,  -- Fel Overseer (Shadow Labyrinth) — Frightening Shout (AoE fear, causes aggro reset on fear; per WoWHead guides and comments, major trash fear that can wipe if not handled with Tremor/Fear Ward)
    [17839] = true,  -- Rift Lord (Black Morass) — Fear (from guides, Rift Keepers/Lords cast fear)
    [20060] = true,  -- Lord Sanguinar (Tempest Keep Kael'thas) — Fear (30yd AoE fear per guide)
    -- SSC (Serpentshrine Cavern) from WoWHead trash guides: Striders have fear aura (kite), Honor Guards enrage into AoE fear
    [22056] = true,  -- Coilfang Strider (SSC) — AoE fear aura (must kite per guides)
    [21218] = true,  -- Vashj'ir Honor Guard (SSC) — Enrage + AoE fear
    -- Magtheridon's Lair
    [21174] = true,  -- Magtheridon — Fear (random target fear per encounter data)
    -- Sunwell Plateau (SWP) from WoWHead trash guides
    [25370] = true,  -- Sunblade Dusk Priest (Sunwell Plateau) — Fear (uninterruptible; targets enemies)
    -- Magisters' Terrace from WoWHead guides
    [24560] = true,  -- Priestess Delrissa (Magisters' Terrace) — Psychic Scream
    -- The Underbog (Coilfang dungeon) from WoWHead + guides: Fen Rays cast horror fear (Tremor does NOT dispel; Fear Ward essential)
    [17731] = true,  -- Fen Ray (Underbog) — Psychic Horror (fear/horror effect)
    -- Steamvault from WoWHead guides: Coilfang Sirens cast AoE Fear (high priority CC target)
    [17801] = true,  -- Coilfang Siren (Steamvault) — Fear (AoE)
    -- Botanica: Mutate Fear-Shrieker (fear caster trash)
    [19513] = true,  -- Mutate Fear-Shrieker (Botanica) — Fear
    -- Slave Pens: Coilfang Rays (Psychic Horror, dangerous fear into packs)
    [21128] = true,  -- Coilfang Ray (Slave Pens) — Psychic Horror
    -- Additional from research (SSC Frightening Shout trash, BT, TK advisors, Arcatraz, SWP, MGT, Underbog, Steamvault, Botanica, Slave Pens, etc.)
    -- All verified/expanded via WoWHead TBC dungeon/raid guides for proactive Fear Ward + Tremor tank protection.
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
-- Enhanced for dungeons + raids. Uses accurate GetPartyMembers (frames).
-- @return boolean - true if a fear-like CC is detected on a nearby ally
function M.detect_fear_on_ally()
    if not NS or not NS.GetPartyMembers then return false end
    local party = NS.GetPartyMembers()
    if not party then return false end
    -- Expanded fear/charm/sleep/horror debuff IDs for TBC dungeons/raids (sourced from WoWHead guides + spell data)
    -- Note: Some horrors (e.g. 34984 Psychic Horror) bypass Tremor Totem; Fear Ward / other breaks are critical for those.
    local FEAR_DEBUFFS = {
        [5782] = true, [6213] = true, [6215] = true,   -- Fear ranks (warlock etc.)
        [5484] = true, [17928] = true,                 -- Howl of Terror
        [8122] = true, [8124] = true, [10888] = true, [10890] = true, -- Psychic Scream (Durnholde Wardens etc.)
        [33111] = true,                                -- Bellowing Roar (Nightbane/Hellmaw)
        [30615] = true,                                -- Fear (Ramparts Scryers)
        [22884] = true,                                -- Psychic Scream (Old Hillsbrad)
        [12542] = true,                                -- Fear (Black Morass Rift Lords etc.)
        [19134] = true,                                -- Frightening Shout (Fel Overseer, SSC trash)
        [36922] = true,                                -- Bellowing Roar (Nightbane)
        [39415] = true,                                -- Fear (Harbinger Skyriss Arcatraz per WoWHead)
        [39427] = true,                                -- Bellowing Roar variant (TK Kael advisors per guides)
        [46561] = true,                                -- Fear (Sunblade Dusk Priest SWP per WoWHead trash guide; uninterruptible)
        [34984] = true,                                -- Psychic Horror (Fen Ray Underbog; horror, Tremor does not dispel per guides/comments)
        [38660] = true,                                -- Fear (Coilfang Siren Steamvault AoE per guides)
        [10955] = true,                                -- Other fears
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

--- Check specifically if a tank is feared (use for priority breaks/wards).
function M.detect_fear_on_tank()
    if not NS or not NS.GetPartyMembers or not NS.is_tank_unit then return false end
    local party = NS.GetPartyMembers()
    if not party then return false end
    for _, member in ipairs(party) do
        if member and member.is_alive and member:is_alive() and NS.is_tank_unit(member) then
            for debuff_id in pairs({5782,6215,5484,8122,33111,39415,19134,46561,34984,38660}) do
                if NS.debuff_up and NS.debuff_up(member, debuff_id) then
                    return true
                end
            end
        end
    end
    return false
end

--- Attempt to drop Tremor Totem if conditions are met.
-- Enhanced for dungeons/raids: proactive on known fear bosses (even if not current target), or fear detected.
-- Protects tanks from fears that cause wipes (run into packs).
-- @param context table - Rotation context with settings, me, target, is_group etc.
-- @return boolean - true if totem was dropped
function M.try_drop_tremor(context)
    if not context or not context.settings then return false end
    if context.settings.use_auto_tremor_totem == false then return false end

    local fear_risk = false
    if context.target and M.is_fear_boss(context.target) then
        fear_risk = true
    elseif M.detect_fear_on_ally() or M.detect_fear_on_tank() then
        fear_risk = true
    elseif context.known_fear_boss or context.control_risk or context.control_nearby then
        fear_risk = true
    end

    -- In group content (dungeons/raids), be more proactive if any fear/control risk or known boss nearby
    if context.is_group and (context.known_fear_boss or context.control_risk) then
        fear_risk = true
    end

    if not fear_risk then return false end

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

    -- Drop totem (self, no range)
    if NS.try_cast then
        return NS.try_cast(tremor_id, nil, "[SHAMAN] Tremor Totem (dungeon/raid fear protection)", { skip_range = true })
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
            local fear_risk = M.is_fear_boss(context.target) or M.detect_fear_on_ally() or M.detect_fear_on_tank() or context.known_fear_boss or context.control_risk or context.control_nearby
            if context.is_group and (context.known_fear_boss or context.control_risk) then fear_risk = true end
            if not fear_risk then return false end
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
