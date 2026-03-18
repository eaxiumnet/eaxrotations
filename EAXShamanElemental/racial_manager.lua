-- racial_manager.lua
-- Handles racial ability cooldowns for all TBC Classic races.
-- Each racial is only fired when in combat and the spell is off cooldown.
-- Offensive racials (Blood Fury, Berserking) sync with burst windows.
-- Defensive/utility racials fire reactively.

local racial_manager = {}

-- Spell IDs by racial
local RACIALS = {
    -- Offensive
    blood_fury   = { 20572 },           -- Orc (melee/hunter) AP burst
    berserking   = { 26297 },           -- Troll haste burst
    -- Interrupt / utility
    arcane_torrent = { 28730, 25046, 23160, 15533, 50613 }, -- Blood Elf silence/mana
    war_stomp    = { 20549 },           -- Tauren AoE stun
    -- Defensive / escape
    stoneform    = { 20594 },           -- Dwarf (clears poison/bleed/disease)
    shadowmeld   = { 58984, 1784 },     -- Night Elf (cancel combat)
    escape_artist = { 20589 },          -- Gnome (root/slow removal)
    will_of_forsaken = { 7744 },        -- Undead (fear/charm/sleep removal)
    every_man_for_himself = { 59752 },  -- Human (stun removal — Wrath, included for future)
}

-- Which racials are offensive (sync with burst)
local OFFENSIVE = { blood_fury = true, berserking = true }

-- Cache: resolved spell IDs per character session
local resolved = {}

local function resolve(name)
    if resolved[name] then return resolved[name] end
    local ids = RACIALS[name]
    if not ids then return nil end
    for _, id in ipairs(ids) do
        if core.spell_book.is_spell_learned(id) then
            resolved[name] = id
            return id
        end
    end
    return nil
end

-- Try to fire a single racial by name.
-- Returns true if cast was attempted.
local function try_racial(me, name)
    local id = resolve(name)
    if not id then return false end
    if core.spell_book.get_spell_cooldown(id) > 0 then return false end
    if not core.spell_book.is_usable_spell(id) then return false end
    local _sq_ok, _sq = pcall(require, "common/modules/spell_queue")
    if _sq_ok and _sq then
        _sq:queue_spell_target_fast(id, me, 1)
        return true
    end
    -- fallback
    if core.spell_book.cast_spell then
        pcall(core.spell_book.cast_spell, id, me)
    end
    return true
end

-- Try all offensive racials. Call at start of burst window.
function racial_manager.try_offensive(me)
    if not me or not me:is_in_combat() then return false end
    if try_racial(me, "blood_fury")  then return true end
    if try_racial(me, "berserking")  then return true end
    return false
end

-- Try utility/interrupt racial (Arcane Torrent, War Stomp).
-- target may be nil for non-targeted racials.
function racial_manager.try_utility(me, target)
    -- Arcane Torrent: use as interrupt fallback
    if target and (target:is_casting_spell() or target:is_channelling_spell()) then
        if try_racial(me, "arcane_torrent") then return true end
    end
    -- War Stomp: use as interrupt or when overwhelmed (2+ melee)
    if target and target:is_casting_spell() then
        if try_racial(me, "war_stomp") then return true end
    end
    return false
end

-- Try defensive racials. Call when HP drops below threshold or CC applied.
function racial_manager.try_defensive(me)
    if not me then return false end
    local hp = me:get_health_percentage() / 100
    -- Stoneform: clear DoTs/bleeds when low
    if hp < 0.50 then
        if try_racial(me, "stoneform") then return true end
    end
    -- Escape Artist: when rooted/slowed (can't detect directly — use on low HP)
    if hp < 0.40 then
        if try_racial(me, "escape_artist") then return true end
    end
    -- Will of the Forsaken: if feared/charmed (approximate via low HP)
    if hp < 0.35 then
        if try_racial(me, "will_of_forsaken") then return true end
    end
    return false
end

-- Convenience: try offensive → utility → defensive in one call.
function racial_manager.try_all(me, target)
    if racial_manager.try_offensive(me) then return true end
    if racial_manager.try_utility(me, target) then return true end
    if racial_manager.try_defensive(me) then return true end
    return false
end

return racial_manager
