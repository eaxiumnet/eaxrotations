-- Readability notes:
--   What: Paladin Retribution priority list with optional TBC seal twisting.
--   When: dispatcher runs this playstyle when selected.
--   Why: Ret damage in TBC is built around seals, Crusader Strike, Judgement, and swing-timed seal twists.
--   Safety: all rows use shared spell/resource/range/form checks before casting.

-- Decision notes:
--   Seal twisting is timing-sensitive, so this file uses explicit strategy functions instead of only static action rows.
--   The twist implementation is conservative: prep Rank 1 Seal of Command, then cast Seal of Blood in the final swing window.
--   If swing timing is unavailable, the rotation falls back to a normal FCFS seal/strike/judgement loop.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.PaladinSpells or {}

local SEAL_COMMAND_BUFF = { 27170, 20920, 20919, 20918, 20915, 20375 }
local SEAL_BLOOD_BUFF = { 31892 }
local SEAL_RIGHTEOUSNESS_BUFF = { 27155, 20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084 }
local TWIST_WINDOW = 0.45
local PREP_WINDOW = 0.65
local DEMON_OR_UNDEAD = { [3] = true, [6] = true }

local ret_state = {
    swing_remains = nil,
    has_command = false,
    has_blood = false,
    has_righteousness = false,
}

local function build_state(context)
    ret_state.swing_remains = NS.get_time_until_swing and NS.get_time_until_swing() or nil
    ret_state.has_command = NS.has_player_buff(SEAL_COMMAND_BUFF)
    ret_state.has_blood = NS.has_player_buff(SEAL_BLOOD_BUFF)
    ret_state.has_righteousness = NS.has_player_buff(SEAL_RIGHTEOUSNESS_BUFF)
    return ret_state
end

local function has_any_damage_seal(state)
    return state.has_command or state.has_blood or state.has_righteousness
end

local strategies = {
    {
        name = "SealTwistBlood",
        matches = function(context, state)
            if context.settings.seal_twisting == false then return false end
            if not state.swing_remains or state.swing_remains > TWIST_WINDOW then return false end
            if not state.has_command or state.has_blood then return false end
            return NS.spell_ready(SPELLS.SealBlood, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(SPELLS.SealBlood, NS.PLAYER_UNIT, "[RETRIBUTION] Twist Seal of Blood")
        end,
    },
    {
        name = "SealTwistPrepCommand",
        matches = function(context, state)
            if context.settings.seal_twisting == false then return false end
            if not state.swing_remains or state.swing_remains <= PREP_WINDOW then return false end
            if state.has_command then return false end
            return NS.spell_ready(SPELLS.SealCommandRank1, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(SPELLS.SealCommandRank1, NS.PLAYER_UNIT, "[RETRIBUTION] Prep Rank 1 Seal of Command")
        end,
    },
    {
        name = "SealBloodFallback",
        matches = function(context, state)
            if context.settings.seal_twisting ~= false and state.swing_remains then return false end
            if state.has_blood then return false end
            return NS.spell_ready(SPELLS.SealBlood, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(SPELLS.SealBlood, NS.PLAYER_UNIT, "[RETRIBUTION] Seal of Blood")
        end,
    },
    {
        name = "SealCommandFallback",
        matches = function(context, state)
            if context.settings.seal_twisting ~= false and state.swing_remains then return false end
            if state.has_command or state.has_blood then return false end
            return NS.spell_ready(SPELLS.SealCommand, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(SPELLS.SealCommand, NS.PLAYER_UNIT, "[RETRIBUTION] Seal of Command")
        end,
    },
    {
        name = "AvengingWrath",
        is_burst = true,
        matches = function(context)
            if not (context.should_burst or (context.settings and context.settings.use_cooldowns ~= false)) then return false end
            if not NS.should_use_long_cd(context, 180) then return false end
            return NS.spell_ready(SPELLS.AvengingWrath, NS.PLAYER_UNIT, { skip_range = true, expected_cooldown = 180 })
        end,
        execute = function()
            return NS.try_cast(SPELLS.AvengingWrath, NS.PLAYER_UNIT, "[RETRIBUTION] Avenging Wrath")
        end,
    },
    {
        name = "CrusaderStrike",
        matches = function(context)
            return context.has_valid_enemy_target and NS.spell_ready(SPELLS.CrusaderStrike, context.target, { expected_cooldown = 6 })
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.CrusaderStrike, context.target, "[RETRIBUTION] Crusader Strike")
        end,
    },
    {
        name = "Judgement",
        matches = function(context, state)
            if not has_any_damage_seal(state) then return false end
            return context.has_valid_enemy_target and NS.spell_ready(SPELLS.Judgement, context.target, { expected_cooldown = 10 })
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Judgement, context.target, "[RETRIBUTION] Judgement")
        end,
    },
    {
        name = "HammerOfWrath",
        matches = function(context)
            if not context.has_valid_enemy_target or not NS.is_execute_phase(context.target_hp, 20) then return false end
            return NS.spell_ready(SPELLS.HammerOfWrath, context.target, { expected_cooldown = 6 })
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.HammerOfWrath, context.target, "[RETRIBUTION] Hammer of Wrath")
        end,
    },
    {
        name = "Exorcism",
        matches = function(context)
            return NS.action_matches(context, { name = "Exorcism", spell = SPELLS.Exorcism, not_moving = true, cooldown = 15, min_mana = 20, creature_types = DEMON_OR_UNDEAD })
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Exorcism, context.target, "[RETRIBUTION] Exorcism")
        end,
    },
    {
        name = "Consecration",
        matches = function(context)
            if (context.enemy_count or 0) < (context.settings.aoe_threshold or 3) then return false end
            return NS.spell_ready(SPELLS.Consecration, NS.PLAYER_UNIT, { skip_range = true, expected_cooldown = 8 })
        end,
        execute = function()
            return NS.try_cast(SPELLS.Consecration, NS.PLAYER_UNIT, "[RETRIBUTION] Consecration")
        end,
    },
}

NS.rotation_registry:register("retribution", strategies, { get_state = build_state })
NS.log("Paladin retribution rotation registered")
return strategies
