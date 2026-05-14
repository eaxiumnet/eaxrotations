-- Readability notes:
--   What: Druid Cat priority list.
--   When: dispatcher runs this playstyle when selected.
--   Why: action rows show what is cast, why it is gated, and when it is allowed.
--   Safety: all rows use shared spell/resource/range/form checks before casting.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
--   Enhancement notes (2026-05): Added Tiger's Fury energy pooling, Faerie Fire Feral armor reduction,
--   Omen of Clarity free-cast detection, Dash for PvP gap closing, and improved combo point gating.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.DruidSpells or {}

local RIP_DEBUFF = { 27008, 1079 }
local RAKE_DEBUFF = { 1822 }
local MANGLE_DEBUFF = { 33876, 33983, 33982, 33878, 33986, 33987 }
local FAERIE_FIRE_DEBUFF = { 27011, 17392, 17391, 17390, 16857 }
local PROWL_BUFF = { 9913, 6783, 5215 }
local OMEN_OF_CLARITY_BUFF = { 16864 }

local TIGERS_FURY_CD = 30
local ENERGY_POOL = 20  -- Energy to reserve before Tiger's Fury

-- ============================================================================
-- Custom Gating Functions
-- ============================================================================

local function rip_matches(context, action)
    local target = context.target
    if not target then return false end
    local remains = NS.debuff_remains and NS.debuff_remains(target, RIP_DEBUFF) or 0
    if not NS.should_refresh_dot(remains, 3, context.ttd, 12) then return false end
    return NS.action_matches(context, action)
end

local function rake_matches(context, action)
    local target = context.target
    if not target then return false end
    local remains = NS.debuff_remains and NS.debuff_remains(target, RAKE_DEBUFF) or 0
    if not NS.should_refresh_dot(remains, 3, context.ttd, 9) then return false end
    return NS.action_matches(context, action)
end

local function faerie_fire_matches(context, action)
    -- Maintain Faerie Fire (Feral) for armor reduction on target
    local target = context.target
    if not target then return false end
    if not NS.is_spell_learned or not NS.is_spell_learned(27011) then return false end
    local remains = NS.debuff_remains and NS.debuff_remains(target, FAERIE_FIRE_DEBUFF) or 0
    if remains > 3 then return false end
    -- Only apply if target will live long enough to benefit
    if context.ttd and context.ttd < 10 then return false end
    return NS.action_matches(context, action)
end

local function tigers_fury_matches(context, action)
    -- Use Tiger's Fury when energy is low to avoid capping energy from the restore
    local me = context.me
    if not me then return false end
    local energy = me.get_power and me:get_power(3) or 0
    local max_energy = me.get_max_power and me:get_max_power(3) or 100
    -- Only use when energy is low enough that the +60 won't cap us
    if (energy + 60) > max_energy then return false end
    -- Don't waste Tiger's Fury if target is about to die
    if context.ttd and context.ttd < 8 then return false end
    return NS.action_matches(context, action)
end

local function omen_clarity_matches(context, action)
    -- When Omen of Clarity procs, the next ability costs 0 energy.
    -- Prioritize Shred (highest damage per energy) when clearcasting.
    local me = context.me
    if not me then return false end
    local has_omen = NS.buff_up and NS.buff_up(me, OMEN_OF_CLARITY_BUFF)
    if not has_omen then return false end
    -- Use Shred with Omen proc (free cast)
    if action.spell == SPELLS.Shred then
        return NS.action_matches(context, action)
    end
    return false
end

local function dash_matches(context, action)
    -- Dash in PvP to close gaps or escape
    if not (context.is_pvp or (context.settings and context.settings.pvp_mode)) then return false end
    local me = context.me
    if not me then return false end
    -- Don't Dash if already dashing
    if NS.buff_up and NS.buff_up(me, { 33357, 9821, 1850 }) then return false end
    -- Only Dash when target is out of melee range
    if not context.target then return false end
    local dist = me.get_distance and me:get_distance(context.target) or 0
    if dist < 10 then return false end
    return NS.action_matches(context, action)
end

-- ============================================================================
-- Priority List
-- ============================================================================

local ACTIONS = {
    -- Form & stealth (out of combat)
    { name = "CatForm",          spell = SPELLS.CatForm,          target = "self", kind = "form", form = "cat", requires_target = false },
    { name = "Prowl",            spell = SPELLS.Prowl,            target = "self", kind = "buff", buff = PROWL_BUFF, ooc = true, required_form = "cat", requires_target = false },

    -- Stealth opener
    { name = "RavageOpener",     spell = SPELLS.Ravage,           requires_buff = PROWL_BUFF, requires_behind = true, min_energy = 60 },

    -- Movement / gap closer (PvP)
    { name = "Dash",             spell = SPELLS.Dash,              matches = dash_matches, requires_target = false },

    -- Debuffs (armor reduction, bleed amp)
    { name = "FaerieFireFeral",  spell = SPELLS.FaerieFireFeral,  matches = faerie_fire_matches, required_form = "cat" },
    { name = "MangleDebuff",     spell = SPELLS.MangleCat,        required_form = "cat", min_energy = 45, debuff = MANGLE_DEBUFF, refresh = 3 },

    -- Energy cooldown: Tiger's Fury when energy is low
    { name = "TigersFury",       spell = SPELLS.TigersFury,       required_form = "cat", cooldown = TIGERS_FURY_CD, matches = tigers_fury_matches },

    -- Finishers (combo point spenders)
    { name = "Rip",              spell = SPELLS.Rip,              required_form = "cat", min_combo = 4, min_energy = 30, matches = rip_matches },
    { name = "FerociousBite",    spell = SPELLS.FerociousBite,    required_form = "cat", target_max_hp = 25, min_combo = 4, min_energy = 35 },

    -- Omen of Clarity: free Shred when clearcasting
    { name = "ShredOmen",        spell = SPELLS.Shred,            required_form = "cat", requires_behind = true, matches = omen_clarity_matches },

    -- Builders (combo point generators)
    { name = "Shred",            spell = SPELLS.Shred,            required_form = "cat", requires_behind = true, min_energy = 40 },
    { name = "Rake",             spell = SPELLS.Rake,             required_form = "cat", min_energy = 40, matches = rake_matches },

    -- Fillers
    { name = "Mangle",           spell = SPELLS.MangleCat,        required_form = "cat", min_energy = 45 },
    { name = "Claw",             spell = SPELLS.Claw,             required_form = "cat", min_energy = 45 },
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
        execute = function(context) return NS.action_execute(context, action, "[CAT]") end,
    }
end

NS.rotation_registry:register("cat", strategies, { get_state = function(context) return context end })
NS.log("Druid cat rotation registered (enhanced: Tiger's Fury, Faerie Fire Feral, Omen of Clarity, Dash, energy pooling)")
return strategies
