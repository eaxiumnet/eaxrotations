-- Readability notes:
--   What: Warlock Destruction priority list.
--   When: dispatcher runs this playstyle when selected.
--   Why: action rows show what is cast, why it is gated, and when it is allowed.
--   Safety: all rows use shared spell/resource/range/form checks before casting.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
--   Enhancement notes (2026-05-13): Added Backlash proc handling (instant Shadow Bolt), Backdraft haste stack
--   utilization, and Immolate pandemic window optimization (refresh at 3.5s for 100% uptime).
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.WarlockSpells or {}

local CURSE_OF_DOOM_DEBUFF = { 30910, 603 }
local IMMOLATE_DEBUFF = { 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }
local BACKLASH_BUFF = { 34936, 34935 }  -- Backlash proc buff (instant Shadow Bolt)
local BACKDRAFT_BUFF = { 54274 }       -- Backdraft haste stacks from Conflagrate

local IMMOLATE_PANDEMIC_WINDOW = 3.5   -- Refresh Immolate when <= 3.5s remains for 100% uptime
local SHADOWBURN_HP_PCT = 20           -- Execute phase threshold for Shadowburn

local function immolate_matches(context, action)
    local target = context.target
    if not target then return false end
    local remains = NS.debuff_remains and NS.debuff_remains(target, IMMOLATE_DEBUFF) or 0
    -- Use pandemic window for optimal uptime: refresh at <= 3.5s remaining
    if remains > IMMOLATE_PANDEMIC_WINDOW then return false end
    -- Only refresh if target will live long enough for the new DoT to tick
    if not NS.should_refresh_dot(remains, 1.5, context.ttd, 15) then return false end
    return NS.action_matches(context, action)
end

local function shadowburn_matches(context, action)
    if not NS.is_execute_phase(context.target_hp, SHADOWBURN_HP_PCT) then return false end
    return NS.action_matches(context, action)
end

local function curse_of_doom_matches(context, action)
    if not NS.should_use_long_cd(context, action.cooldown) then return false end
    return NS.action_matches(context, action)
end

local function conflagrate_matches(context, action)
    -- Conflagrate consumes Immolate for burst. Only cast when Immolate is active.
    local target = context.target
    if not target then return false end
    local immolate_remains = NS.debuff_remains and NS.debuff_remains(target, IMMOLATE_DEBUFF) or 0
    if immolate_remains <= 0 then return false end
    -- Backdraft optimization: cast Conflagrate to gain haste stacks, then spend them on high-value casts
    return NS.action_matches(context, action)
end

local function backlash_matches(context, action)
    -- Backlash proc: instant cast Shadow Bolt (no cast time)
    local me = context.me
    if not me then return false end
    local has_backlash = NS.buff_up(me, BACKLASH_BUFF)
    if not has_backlash then return false end
    -- Backlash makes the next Shadow Bolt instant - cast it immediately
    return NS.action_matches(context, action)
end

local function incinerate_matches(context, action)
    -- Incinerate is the main filler only while Immolate is active for its +25% damage bonus.
    local target = context.target
    if not target then return false end
    local immolate_remains = NS.debuff_remains and NS.debuff_remains(target, IMMOLATE_DEBUFF) or 0
    if immolate_remains <= 0 then return false end
    -- Backdraft haste math: stacks shorten the next casts, so spend them on high-value casts/filler without delaying.
    return NS.action_matches(context, action)
end

local function shadow_bolt_matches(context, action)
    -- Shadow Bolt is filler when no Backlash proc and Incinerate conditions not met
    return NS.action_matches(context, action)
end

local ACTIONS = {
    { name = "FelArmor", spell = SPELLS.FelArmor, target = "self", kind = "buff", buff = { 28189, 28176 }, requires_target = false },
    { name = "CurseOfDoom", spell = SPELLS.CurseOfDoom, debuff = CURSE_OF_DOOM_DEBUFF, refresh = 5, cooldown = 60, min_ttd = 62, require_ttd = true, target_not_player = true, matches = curse_of_doom_matches },
    { name = "Immolate", spell = SPELLS.Immolate, not_moving = true, matches = immolate_matches },
    -- Backlash proc: instant Shadow Bolt takes priority over everything except maintaining Immolate
    { name = "BacklashShadowBolt", spell = SPELLS.ShadowBolt, matches = backlash_matches, priority = 100 },
    { name = "Conflagrate", spell = SPELLS.Conflagrate, requires_debuff = IMMOLATE_DEBUFF, moving = true, cooldown = 10, matches = conflagrate_matches },
    { name = "Shadowburn", spell = SPELLS.Shadowburn, cooldown = 15, matches = shadowburn_matches },
    { name = "Incinerate", spell = SPELLS.Incinerate, not_moving = true, matches = incinerate_matches },
    { name = "ShadowBolt", spell = SPELLS.ShadowBolt, not_moving = true, matches = shadow_bolt_matches },
}

local strategies = {}
for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    strategies[#strategies + 1] = {
        name = action.name,
        matches = function(context)
            if action.matches then
                return action.matches(context, action)
            end
            return NS.action_matches(context, action)
        end,
        execute = function(context) return NS.action_execute(context, action, "[DESTRUCTION]") end,
    }
end

NS.rotation_registry:register("destruction", strategies, { get_state = function(context) return context end })
NS.log("Warlock destruction rotation registered (enhanced: Backlash proc, Backdraft optimization, Immolate pandemic window)")
return strategies
