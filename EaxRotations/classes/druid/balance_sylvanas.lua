-- balance_sylvanas.lua — Druid Balance (moonkin) rotation for TBC Anniversary (2.5.5).
-- WHAT:  ranged DPS rotation (Moonfire + Insect Swarm up, Starfire / Wrath filler, Eclipse-aware).
-- WHEN:  combat, in caster form, mana and target are valid.
-- WHY:   mirrors priority APL
--          (Moonfire > Insect Swarm > Eclipse proc Starfire > Starfire > Wrath)
--          with mana-aware fallback to wand / potions.
-- SAFETY: every state.* read is nil-guarded per Pattern 14.
--          no on_update() allocs (static _t reused per tick).

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.DruidSpells or {}
local _potion_helper = require("shared/potion_helper_sylvanas")
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { ITEMS = { potions = {} } } end
local _TBC_P = (TBC.ITEMS and TBC.ITEMS.potions) or {}
local _fnd_mod = require("shared/find_dead_party_ally_sylvanas")
local _find_dead_helper = _fnd_mod and _fnd_mod.find_dead_party_ally or nil
local _find_dead = NS.find_dead_party_ally or _find_dead_helper

local _INSECT_DEBUFF = { 27013, 24977, 24976, 24975, 24974, 5570 }
local _MOONFIRE_DEBUFF = { 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }
local _FAERIE_DEBUFF  = { 26993, 9907, 9749, 778, 770 }
local _NATURES_BUFF = { 16880 }
local _BARKSKIN_BUFF = { 22812 }
local _MOTW_BUFF = { 26991, 9885, 9884, 8907, 5234, 6756, 5232, 1126 }
local _HEALER_IDS = { [2]=true, [5]=true, [7]=true, [11]=true }
local _INNERVATE_SCAN_INTERVAL = 2.0
local _last_innervate_scan_time = 0

local _LOCAL_SPELLS = {
    Innervate    = NS.spell_action({ 29166 }, "Innervate"),
    Rebirth      = NS.spell_action({ 26994,20748,20747,20742,20739,20484 }, "Rebirth"),
    Thorns       = NS.spell_action({ 26992,9910,9756,8914,1075,782,467 }, "Thorns"),
    Cyclone      = NS.spell_action({ 33786 }, "Cyclone"),
    EntanglingRoots = NS.spell_action({ 26989,9853,9852,5196,5195,1062,339 }, "EntanglingRoots"),
    NaturesGrasp = NS.spell_action({ 27009,17329,16813,16812,16811,16810,16689 }, "NaturesGrasp"),
    WarStomp     = NS.spell_action({ 20549 }, "WarStomp"),
    MarkOfTheWild= NS.spell_action({ 26991,9885,9884,8907,5234,6756,5232,1126 }, "MarkOfTheWild"),
}

local _INSECT_MIN_SP = 800
local _MOONFIRE_MIN_SP = 800

local HEALTHSTONE_IDS = { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }

local function first_ready_item(item_ids)
    if not NS.is_item_ready then return 0 end
    for i = 1, #item_ids do
        local item_id = item_ids[i]
        if NS.is_item_ready(item_id) then return item_id end
    end
    return 0
end

local _ACT_FON = { name="ForceOfNature", spell=SPELLS.ForceOfNature, position="target", combat=true, setting="use_cooldowns", cooldown=180, min_mana=25 }
local _ACT_HUR = { name="Hurricane", spell=SPELLS.Hurricane, position="target", enemy_count=3, not_moving=true, min_mana=35, cooldown=60 }
local _ACT_SF  = { name="Starfire", spell=SPELLS.Starfire, not_moving=true, min_mana=15 }
local _ACT_WR  = { name="Wrath", spell=SPELLS.Wrath, not_moving=true, min_mana=10 }
local _ACT_MF  = { name="Moonfire", spell=SPELLS.Moonfire, position="target", min_mana=10 }
local _ACT_IS  = { name="InsectSwarm", spell=SPELLS.InsectSwarm, position="target", min_mana=10 }

local _state = {
    insect_remains=0, moonfire_remains=0, ff_remains=0, natures_grace_active=false,
    barkskin_active=false, mana_pct=100,
    enemy_count=1, target_ttd=999, innervate_target=nil,
    healthstone_ready=0,
}

local function build_state(ctx)
    local t = ctx.target
    -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
    local _BARKSKIN_ID = type(SPELLS.Barkskin) == "table" and SPELLS.Barkskin[1] or 22812
    local skip_aura = NS.broken_api_throttled and NS.broken_api_throttled(_BARKSKIN_ID, 3.0) or false
    if not skip_aura then
        if t then
            _state.insect_remains = NS.debuff_remains and NS.debuff_remains(t, _INSECT_DEBUFF) or 0
            _state.moonfire_remains = NS.debuff_remains and NS.debuff_remains(t, _MOONFIRE_DEBUFF) or 0
            _state.ff_remains = NS.debuff_remains and NS.debuff_remains(t, _FAERIE_DEBUFF) or 0
        else
            _state.insect_remains = 0
            _state.moonfire_remains = 0
            _state.ff_remains = 0
        end
        _state.natures_grace_active = NS.has_player_buff(_NATURES_BUFF)
        _state.barkskin_active = NS.has_player_buff(_BARKSKIN_BUFF)
    end
    _state.is_group = ctx.is_group or false
    _state.mana_pct = ctx.mana_pct or ctx.mana or 100
    _state.enemy_count = ctx.enemy_count or 1
    _state.target_ttd = ctx.ttd or ctx.target_ttd or 999
    _state.innervate_target = nil
    local floor_mana = (ctx.settings and ctx.settings.balance_innervate_mana) or 30
    local now = NS.time_now and NS.time_now() or 0
    if now - _last_innervate_scan_time >= _INNERVATE_SCAN_INTERVAL then
        _last_innervate_scan_time = now
        if ctx.in_combat and ctx.is_group and ctx.me and NS.GetPartyMembers then
            local party = NS.GetPartyMembers()
            if party and type(party)=="table" then
                for _, u in ipairs(party) do
                    if u then
                        local is_self = NS.same_unit and NS.same_unit(u, ctx.me)
                        if not is_self then
                            local class_id = nil
                            if NS.safe_field then
                                local getter = NS.safe_field(u, "get_class")
                                if getter then
                                    local ok, val = pcall(getter, u)
                                    if ok and type(val)=="number" then class_id = val end
                                end
                            end
                            if class_id and _HEALER_IDS[class_id] and NS.mana_pct then
                                if NS.mana_pct(u) <= (floor_mana+5) then
                                    _state.innervate_target = u
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if not _state.innervate_target then
        if (_state.mana_pct or 100) <= floor_mana then _state.innervate_target = ctx.me end
    end
    _state.healthstone_ready = first_ready_item(HEALTHSTONE_IDS)
    return _state
end

local function _mana_now(s, ctx) return s.mana_pct or ctx.mana or ctx.mana_pct or 100 end

local function _choose_nuke(s, ctx)
    local settings = ctx.settings
    local mana_floor = (settings and settings.balance_starfire_mana) or 40
    local m = _mana_now(s, ctx)
    if m < mana_floor then return "wrath" end
    -- Nature's Grace active: Starfire for burst; otherwise Wrath for mana efficiency.
    if s.natures_grace_active then return "starfire" end
    return "wrath"
end

local strategies = {
    {
        name="BarkskinDefense",
        matches=function(ctx)
            local threshold = (ctx.settings and ctx.settings.balance_barkskin_hp) or 40
            if (ctx.hp or 100) > threshold then return false end
            return NS.spell_ready(SPELLS.Barkskin, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute=function()
            return NS.try_cast(SPELLS.Barkskin, NS.PLAYER_UNIT, "[BALANCE] Barkskin defense")
        end,
    },
    {
        name="ManaPotionEmergency",
        matches=function(_, s)
            local floor = 15
            if (s.mana_pct or 100) > floor then return false end
            return true
        end,
        execute=function(ctx)
            return _potion_helper.try_use_potion(ctx, _potion_helper.MANA_POTION_IDS)
        end,
    },
    {
        name="ForceOfNature",
        matches=function(ctx)
            if not ctx or not ctx.in_combat then return false end
            if not ctx.should_burst then return false end
            if ctx.settings and ctx.settings.balance_use_force_of_nature == false then return false end
            return NS.action_matches(ctx, _ACT_FON)
        end,
        execute=function(ctx) return NS.action_execute(ctx, _ACT_FON, "[BALANCE]") end,
    },
    {
        name="MoonkinForm",
        matches=function(ctx)
            if not (ctx.settings and ctx.settings.balance_moonkin_auto) then return false end
            if ctx.in_combat then return false end
            return NS.spell_ready(SPELLS.MoonkinForm, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute=function()
            return NS.try_cast(SPELLS.MoonkinForm, NS.PLAYER_UNIT, "[BALANCE] Moonkin Form")
        end,
    },
    {
        name="InnervateSelf",
        matches=function(ctx, s)
            if not ctx or not ctx.in_combat then return false end
            if not s.innervate_target then return false end
            local me = ctx.me or NS.GetPlayer()
            if not me then return false end
            if not (NS.same_unit and NS.same_unit(s.innervate_target, me)) then return false end
            return NS.spell_ready(_LOCAL_SPELLS.Innervate, s.innervate_target, { skip_range = true })
        end,
        execute=function(_, s)
            return NS.try_cast(_LOCAL_SPELLS.Innervate, s.innervate_target, "[BALANCE] Innervate self")
        end,
    },
    {
        name="RebirthBattleRez",
        matches=function(ctx)
            if not ctx.in_combat then return false end
            local find_dead = _find_dead
            local dead = find_dead and find_dead() or nil
            if not dead then return false end
            if not (dead.is_player and dead:is_player()) then return false end
            if ctx.tank_alive==false then return false end
            return NS.spell_ready(_LOCAL_SPELLS.Rebirth, dead)
        end,
        execute=function(ctx)
            local find_dead = _find_dead
            local dead = find_dead and find_dead() or nil
            if dead then
                return NS.try_cast(_LOCAL_SPELLS.Rebirth, dead, "[BALANCE] Rebirth battle rez")
            end
            return false
        end,
    },
    {
        name="PreHurricaneBarkskin",
        matches=function(ctx, s)
            local min_targets = (ctx.settings and ctx.settings.balance_hurricane_targets) or 3
            if (s.enemy_count or ctx.enemy_count or 1) < min_targets then return false end
            if ctx.is_moving then return false end
            if (s.mana_pct or 100) < 35 then return false end
            if s.barkskin_active then return false end
            if not NS.spell_ready(SPELLS.Barkskin, NS.PLAYER_UNIT, { skip_range=true }) then return false end
            local threshold = (ctx.settings and ctx.settings.balance_barkskin_hp) or 40
            if (ctx.hp or 100) <= threshold then return false end
            return true
        end,
        execute=function()
            return NS.try_cast(SPELLS.Barkskin, NS.PLAYER_UNIT, "[BALANCE] Barkskin before Hurricane")
        end,
    },
    {
        name="HurricaneAoE",
        matches=function(ctx, s)
            local min_targets = (ctx.settings and ctx.settings.balance_hurricane_targets) or 3
            if (s.enemy_count or ctx.enemy_count or 1) < min_targets then return false end
            if ctx.is_moving then return false end
            if (s.mana_pct or 100) < 35 then return false end
            if not SPELLS.Hurricane then return false end
            if not NS.spell_ready(SPELLS.Hurricane, ctx.target) then return false end
            if NS.spell_ready(SPELLS.Barkskin, NS.PLAYER_UNIT, { skip_range=true }) and not s.barkskin_active then return false end
            return NS.action_matches(ctx, _ACT_HUR)
        end,
        execute=function(ctx) return NS.action_execute(ctx, _ACT_HUR, "[BALANCE]") end,
    },
    {
        name="FaerieFireDebuff",
        matches=function(ctx, s)
            -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
            local skip = NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.FaerieFire, 2.0) or false
            if not skip then
                if (s.ff_remains or 0) > 5 then return false end
            end
            local target = ctx.target
            if not target then return false end
            if not ctx.has_valid_enemy_target then return false end
            -- Skip if target has no armor (API unavailable or already fully reduced)
            if (ctx.target_armor or 0) <= 0 then return false end
            if ctx.has_feral_druid then return false end
            return NS.spell_ready(SPELLS.FaerieFire, target)
        end,
        execute=function(ctx)
            return NS.try_cast(SPELLS.FaerieFire, ctx.target, "[BALANCE] Faerie Fire")
        end,
    },
    {
        name="InsectSwarmDoT",
        matches=function(ctx, s)
            -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
            local skip = NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.InsectSwarm, 2.0) or false
            if not skip then
                if (s.insect_remains or 0) > 2 then return false end
            end
            if not ctx.target then return false end
            if not ctx.has_valid_enemy_target then return false end
            local settings = ctx.settings or {}
            if settings.balance_use_insect_swarm == false then return false end
            local min_sp = settings.balance_insect_swarm_min_sp or _INSECT_MIN_SP
            if (s.mana_pct or 100) < 10 then return false end
            return NS.action_matches(ctx, _ACT_IS)
        end,
        execute=function(ctx) return NS.action_execute(ctx, _ACT_IS, "[BALANCE]") end,
    },
    {
        name="MoonfireDoT",
        matches=function(ctx, s)
            -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
            local skip = NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.Moonfire, 2.0) or false
            if not skip then
                if (s.moonfire_remains or 0) >= 3 then return false end
            end
            if not ctx.target then return false end
            if not ctx.has_valid_enemy_target then return false end
            local settings = ctx.settings or {}
            local min_sp = settings.balance_moonfire_min_sp or _MOONFIRE_MIN_SP
            if (s.mana_pct or 100) < 10 then return false end
            return NS.action_matches(ctx, _ACT_MF)
        end,
        execute=function(ctx) return NS.action_execute(ctx, _ACT_MF, "[BALANCE]") end,
    },
    {
        name="MovingMoonfire",
        matches=function(ctx, s)
            if not ctx.is_moving then return false end
            if not ctx.has_valid_enemy_target then return false end
            local skip = NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.Moonfire, 2.0) or false
            if not skip then
                if (s.moonfire_remains or 0) >= 3 then return false end
            end
            if (s.mana_pct or 100) < 10 then return false end
            return NS.action_matches(ctx, _ACT_MF)
        end,
        execute=function(ctx) return NS.action_execute(ctx, _ACT_MF, "[BALANCE]") end,
    },
    {
        name="StarfirePrimary",
        matches=function(ctx, s)
            if ctx.is_moving then return false end
            if not ctx.has_valid_enemy_target then return false end
            if (s.mana_pct or 100) < 15 then return false end
            if _choose_nuke(s, ctx) ~= "starfire" then return false end
            return NS.action_matches(ctx, _ACT_SF)
        end,
        execute=function(ctx) return NS.action_execute(ctx, _ACT_SF, "[BALANCE]") end,
    },
    {
        name="WrathFiller",
        matches=function(ctx, s)
            if ctx.is_moving then return false end
            if not ctx.has_valid_enemy_target then return false end
            if (s.mana_pct or 100) < 10 then return false end
            return NS.action_matches(ctx, _ACT_WR)
        end,
        execute=function(ctx) return NS.action_execute(ctx, _ACT_WR, "[BALANCE]") end,
    },
    {
        name="RemoveCurse",
        matches=function(ctx)
            if not (ctx.settings and ctx.settings.balance_auto_dispel) then return false end
            return NS.spell_ready(SPELLS.RemoveCurse, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute=function()
            return NS.try_cast(SPELLS.RemoveCurse, NS.PLAYER_UNIT, "[BALANCE] Remove Curse self")
        end,
    },
    {
        name="ManaPotion",
        matches=function(_, s)
            local threshold = 25
            if (s.mana_pct or 100) > threshold then return false end
            return true
        end,
        execute=function(ctx)
            return _potion_helper.try_use_potion(ctx, _potion_helper.MANA_POTION_IDS)
        end,
    },
    {
        name="PvP_NaturesGrasp",
        matches=function(ctx)
            if not ctx.is_pvp then return false end
            if not (ctx.melee_on_you or false) then return false end
            return NS.spell_ready(_LOCAL_SPELLS.NaturesGrasp, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute=function()
            return NS.try_cast(_LOCAL_SPELLS.NaturesGrasp, NS.PLAYER_UNIT, "[BALANCE PvP] Nature's Grasp")
        end,
    },
    {
        name="PvP_EntanglingRoots",
        matches=function(ctx)
            if NS.pvp_trinket_used_recently(ctx.target) then return false end
            if not ctx.is_pvp then return false end
            if not (ctx.melee_on_you or false) then return false end
            return NS.spell_ready(_LOCAL_SPELLS.EntanglingRoots, ctx.target)
        end,
        execute=function(ctx)
            return NS.try_cast(_LOCAL_SPELLS.EntanglingRoots, ctx.target, "[BALANCE PvP] Entangling Roots")
        end,
    },
    {
        name="PvP_Cyclone",
        matches=function(ctx)
            if NS.DRTracker and NS.DRTracker.is_dr_immune and ctx.target and NS.DRTracker.is_dr_immune(ctx.target, "cyclone") then return false end
            if NS.pvp_trinket_used_recently(ctx.target) then return false end
            if not ctx.is_pvp then return false end
            if not (ctx.enemy_healer or false) then return false end
            return NS.spell_ready(_LOCAL_SPELLS.Cyclone, ctx.target)
        end,
        execute=function(ctx)
            return NS.try_cast(_LOCAL_SPELLS.Cyclone, ctx.target, "[BALANCE PvP] Cyclone on healer")
        end,
    },
    {
        name="WarStomp",
        matches=function(ctx, s)
            if not ctx.in_combat then return false end
            if (s.enemy_count or ctx.enemy_count or 1) < 4 then return false end
            return NS.spell_ready(_LOCAL_SPELLS.WarStomp, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute=function()
            return NS.try_cast(_LOCAL_SPELLS.WarStomp, NS.PLAYER_UNIT, "[BALANCE] War Stomp (4+ enemies)")
        end,
    },
    {
        name="Healthstone",
        matches=function(ctx, s)
            if not ctx.in_combat then return false end
            if (ctx.hp or 100) > 28 then return false end
            return (s.healthstone_ready or 0) > 0
        end,
        execute=function(ctx)
            local item_id = first_ready_item(HEALTHSTONE_IDS)
            if item_id > 0 and NS.use_item_by_id then
                return NS.use_item_by_id(item_id, ctx.me) and true or false
            end
            return false
        end,
    },
    {
        name="MarkOfTheWild",
        matches=function(ctx)
            -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
            local skip = NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.MarkOfTheWild, 3.0) or false
            if not skip then
                if NS.buff_up(NS.PLAYER_UNIT, _MOTW_BUFF) then return false end
            end
            if ctx.is_moving then return false end
            return NS.spell_ready(_LOCAL_SPELLS.MarkOfTheWild, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute=function()
            return NS.try_cast(_LOCAL_SPELLS.MarkOfTheWild, NS.PLAYER_UNIT, "[BALANCE] Mark of the Wild")
        end,
    },
    {
        name="ThornsBuff",
        matches=function(ctx)
            -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
            local skip = NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.Thorns, 3.0) or false
            if not skip then
                if NS.buff_up(NS.PLAYER_UNIT, {26992,9910,9756,8914,1075,782,467}) then return false end
            end
            if ctx.in_combat then return false end
            return NS.spell_ready(_LOCAL_SPELLS.Thorns, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute=function()
            return NS.try_cast(_LOCAL_SPELLS.Thorns, NS.PLAYER_UNIT, "[BALANCE] Thorns")
        end,
    },
}

NS.rotation_registry:register("balance", strategies, { get_state = build_state })
return { strategies = strategies, build_state = build_state }

