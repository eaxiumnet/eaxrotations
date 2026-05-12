-- Readability notes:
--   What: Shaman Enhancement priority list.
--   When: dispatcher runs this playstyle when selected.
--   Why: action rows show what is cast, why it is gated, and when it is allowed.
--   Safety: all rows use shared spell/resource/range/form checks before casting.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.ShamanSpells or {}

local AIR_TWIST_HOLD_MS = 9000
local AIR_TWIST_SWAP_DELAY_MS = 1300
local TOTEM_REFRESH_MS = 115000

local totem_state = {
    next_air = "windfury",
    last_air_ms = -100000,
    last_windfury_ms = -100000,
    last_strength_ms = -100000,
    last_mana_ms = -100000,
}

local function build_state(context)
    totem_state.now_ms = NS.game_time_ms()
    return totem_state
end

local function can_manage_totems(context)
    return context.settings.enhancement_manage_totems == true or context.settings.enhancement_totem_twisting == true
end

local function can_drop_totem(context, spell)
    if not can_manage_totems(context) then return false end
    if (context.mana_pct or 100) < 25 then return false end
    return NS.spell_ready(spell, NS.PLAYER_UNIT, { skip_range = true })
end

local strategies = {
    {
        name = "StrengthOfEarthTotem",
        category = "utility",
        matches = function(context, state)
            if not can_drop_totem(context, SPELLS.StrengthOfEarthTotem) then return false end
            return state.now_ms - state.last_strength_ms >= TOTEM_REFRESH_MS
        end,
        execute = function(_, state)
            if NS.try_cast(SPELLS.StrengthOfEarthTotem, NS.PLAYER_UNIT, "[ENHANCEMENT] Strength of Earth Totem") then
                state.last_strength_ms = state.now_ms
                return true
            end
            return false
        end,
    },
    {
        name = "ManaSpringTotem",
        category = "utility",
        matches = function(context, state)
            if not can_drop_totem(context, SPELLS.ManaSpringTotem) then return false end
            return state.now_ms - state.last_mana_ms >= TOTEM_REFRESH_MS
        end,
        execute = function(_, state)
            if NS.try_cast(SPELLS.ManaSpringTotem, NS.PLAYER_UNIT, "[ENHANCEMENT] Mana Spring Totem") then
                state.last_mana_ms = state.now_ms
                return true
            end
            return false
        end,
    },
    {
        name = "WindfuryTotemTwist",
        category = "utility",
        matches = function(context, state)
            if context.settings.enhancement_totem_twisting ~= true then return false end
            if not context.in_combat then return false end
            if not can_drop_totem(context, SPELLS.WindfuryTotem) then return false end
            return state.next_air == "windfury" and state.now_ms - state.last_air_ms >= AIR_TWIST_HOLD_MS
        end,
        execute = function(_, state)
            if NS.try_cast(SPELLS.WindfuryTotem, NS.PLAYER_UNIT, "[ENHANCEMENT] Windfury Totem twist") then
                state.next_air = "grace"
                state.last_air_ms = state.now_ms
                state.last_windfury_ms = state.now_ms
                return true
            end
            return false
        end,
    },
    {
        name = "GraceOfAirTotemTwist",
        category = "utility",
        matches = function(context, state)
            if context.settings.enhancement_totem_twisting ~= true then return false end
            if not context.in_combat then return false end
            if not can_drop_totem(context, SPELLS.GraceOfAirTotem) then return false end
            return state.next_air == "grace" and state.now_ms - state.last_air_ms >= AIR_TWIST_SWAP_DELAY_MS
        end,
        execute = function(_, state)
            if NS.try_cast(SPELLS.GraceOfAirTotem, NS.PLAYER_UNIT, "[ENHANCEMENT] Grace of Air Totem twist") then
                state.next_air = "windfury"
                state.last_air_ms = state.now_ms
                return true
            end
            return false
        end,
    },
    {
        name = "WindfuryTotemMaintain",
        category = "utility",
        matches = function(context, state)
            if context.settings.enhancement_manage_totems ~= true then return false end
            if context.settings.enhancement_totem_twisting == true then return false end
            if not can_drop_totem(context, SPELLS.WindfuryTotem) then return false end
            return state.now_ms - state.last_windfury_ms >= TOTEM_REFRESH_MS
        end,
        execute = function(_, state)
            if NS.try_cast(SPELLS.WindfuryTotem, NS.PLAYER_UNIT, "[ENHANCEMENT] Windfury Totem") then
                state.last_windfury_ms = state.now_ms
                return true
            end
            return false
        end,
    },
}

local ACTIONS = {
    { name = "LightningShield", spell = SPELLS.LightningShield, target = "self", kind = "buff", buff = { 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }, requires_target = false },
    { name = "ShamanisticRage", spell = SPELLS.ShamanisticRage, target = "self", combat = true, cooldown = 120, requires_target = false },
    { name = "Bloodlust", spell = SPELLS.Bloodlust, target = "self", combat = true, setting = "use_cooldowns", cooldown = 600, min_mana = 25, requires_target = false },
    { name = "Stormstrike", spell = SPELLS.Stormstrike, cooldown = 10 },
    { name = "FlameShock", spell = SPELLS.FlameShock, debuff = { 25457, 29228, 10448, 10447, 8053, 8052, 8050 }, refresh = 3, cooldown = 6 },
    { name = "EarthShock", spell = SPELLS.EarthShock, cooldown = 6 },
}

for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    strategies[#strategies + 1] = {
        name = action.name,
        matches = function(context) return NS.action_matches(context, action) end,
        execute = function(context) return NS.action_execute(context, action, "[ENHANCEMENT]") end,
    }
end

NS.rotation_registry:register("enhancement", strategies, { get_state = build_state })
NS.log("Shaman enhancement rotation registered")
return strategies
