-- TBC Balance Druid priority list with Starfire/Wrath cycling,

-- ============================================================================
-- What: TBC Druid Balance priority list with Starfire/Wrath cycling, Nature's Grace, Hurricane
-- When: Evaluated every tick via main_sylvanas.lua dispatcher
-- Why: Priority-list early-exit keeps evaluation fast
-- Safety: All settings nil-guarded; API via NS.* wrappers; pcall optional TBC data; conservative defaults
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.DruidSpells or {}
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { ITEMS = { potions = {} } } end
local TBC_POTIONS = (TBC.ITEMS and TBC.ITEMS.potions) or {}

-- ============================================================================
-- Debuff & Buff ID tables
-- ============================================================================
local INSECT_SWARM_DEBUFF = { 27013, 24977, 24976, 24975, 24974, 5570 }
local MOONFIRE_DEBUFF     = { 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }
local FAERIE_FIRE_DEBUFF  = { 26993, 9907, 9749, 778, 770 }
local NATURES_GRACE_BUFF  = { 16880 }
local MARK_OF_THE_WILD_BUFF = { 26991, 9885, 9884, 8907, 5234, 6756, 5232, 1126 }
-- Healer class IDs for Innervate priority: Paladin(2), Priest(5), Shaman(7), Druid(11)
local HEALER_CLASS_IDS = { [2] = true, [5] = true, [7] = true, [11] = true }

-- Local spell actions for spells not yet in class table
local LOCAL_SPELLS = {
    Innervate    = NS.spell_action({ 29166 }, "Innervate"),
    Rebirth      = NS.spell_action({ 26994, 20748, 20747, 20742, 20739, 20484 }, "Rebirth"),
    Thorns       = NS.spell_action({ 26992, 9910, 9756, 8914, 1075, 782, 467 }, "Thorns"),
    Cyclone      = NS.spell_action({ 33786 }, "Cyclone"),
    EntanglingRoots = NS.spell_action({ 26989, 9853, 9852, 5196, 5195, 1062, 339 }, "EntanglingRoots"),
    NaturesGrasp    = NS.spell_action({ 27009, 17329, 16813, 16812, 16811, 16810, 16689 }, "NaturesGrasp"),
    WarStomp        = NS.spell_action({ 20549 }, "WarStomp"),
    MarkOfTheWild   = NS.spell_action({ 26991, 9885, 9884, 8907, 5234, 6756, 5232, 1126 }, "MarkOfTheWild"),
}

local MANA_POTION_IDS = {
    TBC_POTIONS.crystal_mana or 33935,
    TBC_POTIONS.auchenai_mana or 32948,
    TBC_POTIONS.super_mana or 22832,
    TBC_POTIONS.super_rejuvenation or 22850,
    TBC_POTIONS.major_mana or 13444,
    TBC_POTIONS.superior_mana or 13443,
}

-- ============================================================================
-- Action definitions (retained for backward compat)
-- ============================================================================
local FORCE_OF_NATURE_ACTION = { name = "ForceOfNature", spell = SPELLS.ForceOfNature, position = "target", combat = true, setting = "use_cooldowns", cooldown = 180, min_mana = 25 }
local HURRICANE_ACTION       = { name = "Hurricane", spell = SPELLS.Hurricane, position = "target", enemy_count = 3, not_moving = true, min_mana = 35, cooldown = 60 }
local STARFIRE_ACTION        = { name = "Starfire", spell = SPELLS.Starfire, not_moving = true, min_mana = 15 }
local WRATH_ACTION           = { name = "Wrath", spell = SPELLS.Wrath, not_moving = true, min_mana = 10 }
local MOONFIRE_ACTION        = { name = "Moonfire", spell = SPELLS.Moonfire, position = "target", min_mana = 10 }
local INSECT_SWARM_ACTION    = { name = "InsectSwarm", spell = SPELLS.InsectSwarm, position = "target", min_mana = 10 }

-- SP breakpoints for DoT value gating (from Research.md: 800 = GCD-positive threshold)
local INSECT_SWARM_MIN_SP_DEFAULT = 800
local MOONFIRE_MIN_SP_DEFAULT = 800

-- ============================================================================
-- State builder (pre-allocated, no GC in combat)
-- ============================================================================
local balance_state = {
    insect_remains = 0,
    moonfire_remains = 0,
    ff_remains = 0,
    natures_grace_active = false,
    barkskin_active = false,
    mana_pct = 100,
    mana_potion_id = nil,
    enemy_count = 1,
    target_ttd = 999,
    innervate_target = nil,
    spell_damage = 0,
}

local function build_state(context)
    local target = context.target
    -- DoT remains
    if target then
        balance_state.insect_remains = NS.debuff_remains and NS.debuff_remains(target, INSECT_SWARM_DEBUFF) or 0
        balance_state.moonfire_remains = NS.debuff_remains and NS.debuff_remains(target, MOONFIRE_DEBUFF) or 0
        balance_state.ff_remains = NS.debuff_remains and NS.debuff_remains(target, FAERIE_FIRE_DEBUFF) or 0
    else
        balance_state.insect_remains = 0
        balance_state.moonfire_remains = 0
        balance_state.ff_remains = 0
    end
    -- Nature's Grace proc
    balance_state.natures_grace_active = NS.has_player_buff(NATURES_GRACE_BUFF)
    -- Barkskin buff tracking (for Hurricane safety gate)
    balance_state.barkskin_active = NS.has_player_buff({ 22812 })
    -- Mana tracking
    balance_state.mana_pct = context.mana_pct or context.mana or 100
    balance_state.enemy_count = context.enemy_count or 1
    balance_state.target_ttd = context.ttd or context.target_ttd or 999
    -- Find usable mana potion
    balance_state.mana_potion_id = nil
    for _, id in ipairs(MANA_POTION_IDS) do
        if NS.is_item_ready and NS.is_item_ready(id) then
            balance_state.mana_potion_id = id
            break
        end
    end
    -- SP-aware DoT gating: falls back through context (middleware) then to 0
    balance_state.spell_damage = (NS.get_spell_damage and NS.get_spell_damage()) or context.spell_damage or 0
    -- Smart Innervate target: prefer other healers at low mana, fall back to self
    balance_state.innervate_target = nil
    local healer_mana_floor = (context.settings and context.settings.balance_innervate_mana) or 30
    if context.in_combat and context.is_group and context.me and NS.GetPartyMembers then
        local party = NS.GetPartyMembers()
        if party and type(party) == "table" then
            for _, u in ipairs(party) do
                if u then
                    local is_self = NS.same_unit and NS.same_unit(u, context.me)
                    if not is_self then
                        local class_id = nil
                        if NS.safe_field then
                            local getter = NS.safe_field(u, "get_class")
                            if getter then
                                local ok, val = pcall(getter, u)
                                if ok and type(val) == "number" then class_id = val end
                            end
                        end
                        if class_id and HEALER_CLASS_IDS[class_id] and NS.mana_pct then
                            local mana = NS.mana_pct(u)
                            if mana <= (healer_mana_floor + 5) then
                                balance_state.innervate_target = u
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    if not balance_state.innervate_target then
        if (balance_state.mana_pct or 100) <= healer_mana_floor then
            balance_state.innervate_target = context.me
        end
    end
    return balance_state
end

-- ============================================================================
-- Helper functions
-- ============================================================================

-- Choose Starfire vs Wrath based on mana and Nature's Grace
local function mana_now(state, context)
    return state.mana_pct or context.mana or context.mana_pct or 100
end

local function choose_nuke(state, context)
    local settings = context.settings
    local mana_floor = (settings and settings.balance_starfire_mana) or 40
    local m = mana_now(state, context)
    -- At low mana, Wrath is more efficient (lower cast time, lower cost)
    if m < mana_floor then
        return "wrath"
    end
    -- Nature's Grace active: Starfire benefits more from haste
    if state.natures_grace_active then
        return "starfire"
    end
    -- Default: Starfire for higher DPS
    return "starfire"
end

-- ============================================================================
-- Strategies (ordered priority: urgent → maintenance)
-- ============================================================================
local strategies = {
    -- ------------------------------------------------------------------------
    -- 1. Survival
    -- ------------------------------------------------------------------------
    {
        name = "BarkskinDefense",
        matches = function(context)
            local hp_threshold = (context.settings and context.settings.balance_barkskin_hp) or 40
            if (context.hp or 100) > hp_threshold then return false end
            return NS.spell_ready(SPELLS.Barkskin, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Barkskin, NS.PLAYER_UNIT, "[BALANCE] Barkskin defense")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 2. Mana potion at critical mana
    -- ------------------------------------------------------------------------
    {
        name = "ManaPotionEmergency",
        matches = function(context, state)
            local floor = 15
            if (state.mana_pct or context.mana or context.mana_pct or 100) > floor then return false end
            return state.mana_potion_id ~= nil
        end,
        execute = function(_, state)
            if NS.use_item_by_id then
                NS.use_item_by_id(state.mana_potion_id)
            end
            return true
        end,
    },

    -- ------------------------------------------------------------------------
    {
        name = "ForceOfNature",
        matches = function(context)
            if not context then return false end
            if not context.in_combat then return false end
            if not context.should_burst then return false end
            return NS.action_matches(context, FORCE_OF_NATURE_ACTION)
        end,
        execute = function(context)
            return NS.action_execute(context, FORCE_OF_NATURE_ACTION, "[BALANCE]")
        end,
    },

    -- 4b. Innervate self (fallback — only when no healer needs it more)
    -- ------------------------------------------------------------------------
    {
        name = "InnervateSelf",
        matches = function(context, state)
            if not context then return false end
            if not context.in_combat then return false end
            if not state.innervate_target then return false end
            local me = context.me or NS.GetPlayer()
            if not me then return false end
            if not (NS.same_unit and NS.same_unit(state.innervate_target, me)) then return false end
            return NS.spell_ready(LOCAL_SPELLS.Innervate, state.innervate_target, { skip_range = true })
        end,
        execute = function(_, state)
            return NS.try_cast(LOCAL_SPELLS.Innervate, state.innervate_target, "[BALANCE] Innervate self")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 5. Rebirth (battle rez — combat only, dead party member, not spammed)
    -- ------------------------------------------------------------------------
    {
        name = "RebirthBattleRez",
        matches = function(context)
            if not context.in_combat then return false end
            local find_dead = NS.find_dead_party_ally or (require("shared/find_dead_party_ally_sylvanas").find_dead_party_ally)
            local dead_ally = find_dead and find_dead() or nil
            if not dead_ally then return false end
            -- Only cast when the ally is a player and combat is stable (tank explicitly alive)
            local is_player = dead_ally.is_player and dead_ally:is_player()
            if not is_player then return false end
            if context.tank_alive == false then return false end
            return NS.spell_ready(LOCAL_SPELLS.Rebirth, dead_ally)
        end,
        execute = function(context)
            local find_dead = NS.find_dead_party_ally or (require("shared/find_dead_party_ally_sylvanas").find_dead_party_ally)
            local dead_ally = find_dead and find_dead() or nil
            if dead_ally then
                return NS.try_cast(LOCAL_SPELLS.Rebirth, dead_ally, "[BALANCE] Rebirth battle rez")
            end
            return false
        end,
    },

    -- ------------------------------------------------------------------------
    -- 6. Moonkin Form (if not active and talented)
    -- ------------------------------------------------------------------------
    {
        name = "MoonkinForm",
        matches = function(context)
            if not (context.settings and context.settings.balance_moonkin_auto) then return false end
            if context.in_combat then return false end
            return NS.spell_ready(SPELLS.MoonkinForm, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(SPELLS.MoonkinForm, NS.PLAYER_UNIT, "[BALANCE] Moonkin Form")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 7. Pre-Hurricane Barkskin (cast Barkskin before channeling Hurricane)
    -- Research.md Angle 1: Barkskin before Hurricane to prevent channel pushback.
    -- Fires only when HP is above the defensive Barkskin threshold (BarkskinDefense
    -- already handles the low-HP case). On the next tick, HurricaneAoE will match.
    -- ------------------------------------------------------------------------
    {
        name = "PreHurricaneBarkskin",
        matches = function(context, state)
            local min_targets = (context.settings and context.settings.balance_hurricane_targets) or 3
            if (state.enemy_count or context.enemy_count or 1) < min_targets then return false end
            if context.is_moving then return false end
            if (state.mana_pct or context.mana or context.mana_pct or 100) < 35 then return false end
            if state.barkskin_active then return false end
            if not NS.spell_ready(SPELLS.Barkskin, NS.PLAYER_UNIT, { skip_range = true }) then return false end
            -- Only pre-cast when HP is above the defense threshold (BarkskinDefense handles low HP)
            local barkskin_hp = (context.settings and context.settings.balance_barkskin_hp) or 40
            if (context.hp or 100) <= barkskin_hp then return false end
            return true
        end,
        execute = function()
            return NS.try_cast(SPELLS.Barkskin, NS.PLAYER_UNIT, "[BALANCE] Barkskin before Hurricane")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 8. Hurricane AoE (3+ targets) — requires Barkskin active when available
    -- ------------------------------------------------------------------------
    {
        name = "HurricaneAoE",
        matches = function(context, state)
            local min_targets = (context.settings and context.settings.balance_hurricane_targets) or 3
            if (state.enemy_count or context.enemy_count or 1) < min_targets then return false end
            if context.is_moving then return false end
            if (state.mana_pct or context.mana or context.mana_pct or 100) < 35 then return false end
            -- Research.md: always cast Barkskin before Hurricane to prevent channel pushback.
            -- If Barkskin is available but not active → PreHurricaneBarkskin handles it.
            -- If Barkskin is on cooldown → allow Hurricane without protection.
            if NS.spell_ready(SPELLS.Barkskin, NS.PLAYER_UNIT, { skip_range = true }) and not state.barkskin_active then
                return false
            end
            return NS.action_matches(context, HURRICANE_ACTION)
        end,
        execute = function(context)
            return NS.action_execute(context, HURRICANE_ACTION, "[BALANCE]")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 8. Faerie Fire (armor debuff maintenance)
    -- ------------------------------------------------------------------------
    {
        name = "FaerieFireDebuff",
        matches = function(context, state)
            local target = context.target
            if not target then return false end
            if not context.has_valid_enemy_target then return false end
            if (state.ff_remains or 0) > 5 then return false end
            -- Skip if a Feral is handling it
            if context.has_feral_druid then return false end
            return NS.spell_ready(SPELLS.FaerieFire, target)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.FaerieFire, context.target, "[BALANCE] Faerie Fire")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 9. Insect Swarm (DoT maintenance, refresh via should_refresh_dot with TTD gate)
    -- ------------------------------------------------------------------------
    {
        name = "InsectSwarmDoT",
        matches = function(context, state)
            if not context.target then return false end
            if not context.has_valid_enemy_target then return false end
            local settings = context.settings or {}
            if settings.balance_use_insect_swarm == false then return false end
            -- SP-aware gating: skip Insect Swarm when spell damage is below GCD-positive threshold
            local min_sp = settings.balance_insect_swarm_min_sp or INSECT_SWARM_MIN_SP_DEFAULT
            if (state.spell_damage or 0) < min_sp then return false end
            if (state.mana_pct or context.mana or context.mana_pct or 100) < 10 then return false end
            if NS.should_refresh_dot then
                if not NS.should_refresh_dot(state.insect_remains, 1.5, state.target_ttd, 12) then return false end
            else
                if (state.insect_remains or 0) > 2 then return false end
            end
            return NS.action_matches(context, INSECT_SWARM_ACTION)
        end,
        execute = function(context)
            return NS.action_execute(context, INSECT_SWARM_ACTION, "[BALANCE]")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 10. Moonfire (DoT maintenance, refresh via should_refresh_dot with TTD gate)
    -- ------------------------------------------------------------------------
    {
        name = "MoonfireDoT",
        matches = function(context, state)
            if not context.target then return false end
            if not context.has_valid_enemy_target then return false end
            -- SP-aware gating: skip Moonfire when spell damage is below GCD-positive threshold
            local settings = context.settings or {}
            local min_sp = settings.balance_moonfire_min_sp or MOONFIRE_MIN_SP_DEFAULT
            if (state.spell_damage or 0) < min_sp then return false end
            if (state.mana_pct or context.mana or context.mana_pct or 100) < 10 then return false end
            if NS.should_refresh_dot then
                if not NS.should_refresh_dot(state.moonfire_remains, 1.5, state.target_ttd, 12) then return false end
            else
                if (state.moonfire_remains or 0) > 2 then return false end
            end
            return NS.action_matches(context, MOONFIRE_ACTION)
        end,
        execute = function(context)
            return NS.action_execute(context, MOONFIRE_ACTION, "[BALANCE]")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 11. Starfire (primary nuke)
    -- ------------------------------------------------------------------------
    {
        name = "StarfirePrimary",
        matches = function(context, state)
            if context.is_moving then return false end
            if not context.has_valid_enemy_target then return false end
            if (state.mana_pct or context.mana or context.mana_pct or 100) < 15 then return false end
            local choice = choose_nuke(state, context)
            if choice ~= "starfire" then return false end
            return NS.action_matches(context, STARFIRE_ACTION)
        end,
        execute = function(context)
            return NS.action_execute(context, STARFIRE_ACTION, "[BALANCE]")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 12. Wrath (fallback nuke)
    -- ------------------------------------------------------------------------
    {
        name = "WrathFiller",
        matches = function(context, state)
            if context.is_moving then return false end
            if not context.has_valid_enemy_target then return false end
            if (state.mana_pct or context.mana or context.mana_pct or 100) < 10 then return false end
            return NS.action_matches(context, WRATH_ACTION)
        end,
        execute = function(context)
            return NS.action_execute(context, WRATH_ACTION, "[BALANCE]")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 13. Remove Curse (auto-dispel)
    -- ------------------------------------------------------------------------
    {
        name = "RemoveCurse",
        matches = function(context)
            if not (context.settings and context.settings.balance_auto_dispel) then return false end
            return NS.spell_ready(SPELLS.RemoveCurse, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(SPELLS.RemoveCurse, NS.PLAYER_UNIT, "[BALANCE] Remove Curse self")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 14. Mana Potion (proactive)
    -- ------------------------------------------------------------------------
    {
        name = "ManaPotion",
        matches = function(context, state)
            local threshold = (context.settings and context.settings.balance_mana_potion) or 25
            if (state.mana_pct or context.mana or context.mana_pct or 100) > threshold then return false end
            return state.mana_potion_id ~= nil
        end,
        execute = function(_, state)
            if NS.use_item_by_id then
                NS.use_item_by_id(state.mana_potion_id)
            end
            return true
        end,
    },

    -- ------------------------------------------------------------------------
    -- PvP Section
    -- ------------------------------------------------------------------------
    {
        name = "PvP_NaturesGrasp",
        matches = function(context)
            if not context.is_pvp then return false end
            if not context.melee_on_you then return false end
            return NS.spell_ready(LOCAL_SPELLS.NaturesGrasp, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(LOCAL_SPELLS.NaturesGrasp, NS.PLAYER_UNIT, "[BALANCE PvP] Nature's Grasp")
        end,
    },
    {
        name = "PvP_EntanglingRoots",
        matches = function(context)
            if not context.is_pvp then return false end
            if not context.melee_on_you then return false end
            return NS.spell_ready(LOCAL_SPELLS.EntanglingRoots, context.target)
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.EntanglingRoots, context.target, "[BALANCE PvP] Entangling Roots")
        end,
    },
    {
        name = "PvP_Cyclone",
        matches = function(context)
            if not context.is_pvp then return false end
            if not context.enemy_healer then return false end
            return NS.spell_ready(LOCAL_SPELLS.Cyclone, context.target)
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.Cyclone, context.target, "[BALANCE PvP] Cyclone on healer")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 17. War Stomp (Tauren racial: AoE stun on 4+ melee enemies)
    -- ------------------------------------------------------------------------
    {
        name = "WarStomp",
        matches = function(context, state)
            if not context.in_combat then return false end
            if (state.enemy_count or context.enemy_count or 1) < 4 then return false end
            return NS.spell_ready(LOCAL_SPELLS.WarStomp, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(LOCAL_SPELLS.WarStomp, NS.PLAYER_UNIT, "[BALANCE] War Stomp (4+ enemies)")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 18. Mark of the Wild self-buff (maintenance)
    -- ------------------------------------------------------------------------
    {
        name = "MarkOfTheWild",
        matches = function(context)
            if context.is_moving then return false end
            if NS.buff_up(NS.PLAYER_UNIT, MARK_OF_THE_WILD_BUFF) then return false end
            return NS.spell_ready(LOCAL_SPELLS.MarkOfTheWild, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(LOCAL_SPELLS.MarkOfTheWild, NS.PLAYER_UNIT, "[BALANCE] Mark of the Wild")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 19. Thorns self-buff (maintenance)
    -- ------------------------------------------------------------------------
    {
        name = "ThornsBuff",
        matches = function(context)
            if context.in_combat then return false end
            return NS.spell_ready(LOCAL_SPELLS.Thorns, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(LOCAL_SPELLS.Thorns, NS.PLAYER_UNIT, "[BALANCE] Thorns")
        end,
    },
}

NS.rotation_registry:register("balance", strategies, { get_state = build_state })
return { strategies = strategies, build_state = build_state }
