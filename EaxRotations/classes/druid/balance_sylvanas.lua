-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "classes/druid/balance_sylvanas.lua"
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

local _G_E = rawget(_G, "EaxRotations")
if not _G_E then return nil end
local SPELLS = _G_E.DruidSpells or {}
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { ITEMS = { potions = {} } } end
local _TBC_P = (TBC.ITEMS and TBC.ITEMS.potions) or {}

local _INSECT_DEBUFF = { 27013, 24977, 24976, 24975, 24974, 5570 }
local _MOONFIRE_DEBUFF = { 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }
local _FAERIE_DEBUFF  = { 26993, 9907, 9749, 778, 770 }
local _NATURES_BUFF = { 16880 }
local _BARKSKIN_BUFF = { 22812 }
local _MOTW_BUFF = { 26991, 9885, 9884, 8907, 5234, 6756, 5232, 1126 }
local _HEALER_IDS = { [2]=true, [5]=true, [7]=true, [11]=true }

local _LOCAL_SPELLS = {
    Innervate    = _G_E.spell_action({ 29166 }, "Innervate"),
    Rebirth      = _G_E.spell_action({ 26994,20748,20747,20742,20739,20484 }, "Rebirth"),
    Thorns       = _G_E.spell_action({ 26992,9910,9756,8914,1075,782,467 }, "Thorns"),
    Cyclone      = _G_E.spell_action({ 33786 }, "Cyclone"),
    EntanglingRoots = _G_E.spell_action({ 26989,9853,9852,5196,5195,1062,339 }, "EntanglingRoots"),
    NaturesGrasp = _G_E.spell_action({ 27009,17329,16813,16812,16811,16810,16689 }, "NaturesGrasp"),
    WarStomp     = _G_E.spell_action({ 20549 }, "WarStomp"),
    MarkOfTheWild= _G_E.spell_action({ 26991,9885,9884,8907,5234,6756,5232,1126 }, "MarkOfTheWild"),
}

local _MANA_POTION = {
    _TBC_P.crystal_mana or 33935,
    _TBC_P.auchenai_mana or 32948,
    _TBC_P.super_mana or 22832,
    _TBC_P.super_rejuvenation or 22850,
    _TBC_P.major_mana or 13444,
    _TBC_P.superior_mana or 13443,
}

local _INSECT_MIN_SP = 800
local _MOONFIRE_MIN_SP = 800

local _ACT_FON = { name="ForceOfNature", spell=SPELLS.ForceOfNature, position="target", combat=true, setting="use_cooldowns", cooldown=180, min_mana=25 }
local _ACT_HUR = { name="Hurricane", spell=SPELLS.Hurricane, position="target", enemy_count=3, not_moving=true, min_mana=35, cooldown=60 }
local _ACT_SF  = { name="Starfire", spell=SPELLS.Starfire, not_moving=true, min_mana=15 }
local _ACT_WR  = { name="Wrath", spell=SPELLS.Wrath, not_moving=true, min_mana=10 }
local _ACT_MF  = { name="Moonfire", spell=SPELLS.Moonfire, position="target", min_mana=10 }
local _ACT_IS  = { name="InsectSwarm", spell=SPELLS.InsectSwarm, position="target", min_mana=10 }

local _state = {
    insect_remains=0, moonfire_remains=0, ff_remains=0, natures_grace_active=false,
    barkskin_active=false, mana_pct=100, mana_potion_id=nil,
    enemy_count=1, target_ttd=999, innervate_target=nil, spell_damage=0,
}

local function _build_state(ctx)
    local t = ctx.target
    -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
    local _BARKSKIN_ID = type(SPELLS.Barkskin) == "table" and SPELLS.Barkskin[1] or 22812
    local skip_aura = _G_E.broken_api_throttled and _G_E.broken_api_throttled(_BARKSKIN_ID, 3.0) or false
    if not skip_aura then
        if t then
            _state.insect_remains = _G_E.debuff_remains and _G_E.debuff_remains(t, _INSECT_DEBUFF) or 0
            _state.moonfire_remains = _G_E.debuff_remains and _G_E.debuff_remains(t, _MOONFIRE_DEBUFF) or 0
            _state.ff_remains = _G_E.debuff_remains and _G_E.debuff_remains(t, _FAERIE_DEBUFF) or 0
        else
            _state.insect_remains = 0
            _state.moonfire_remains = 0
            _state.ff_remains = 0
        end
        _state.natures_grace_active = _G_E.has_player_buff(_NATURES_BUFF)
        _state.barkskin_active = _G_E.has_player_buff(_BARKSKIN_BUFF)
    end
    _state.mana_pct = ctx.mana_pct or ctx.mana or 100
    _state.enemy_count = ctx.enemy_count or 1
    _state.target_ttd = ctx.ttd or ctx.target_ttd or 999
    _state.mana_potion_id = nil
    for _, id in ipairs(_MANA_POTION) do
        if _G_E.is_item_ready and _G_E.is_item_ready(id) then
            _state.mana_potion_id = id
            break
        end
    end
    _state.spell_damage = (_G_E.get_spell_damage and _G_E.get_spell_damage()) or ctx.spell_damage or 0
    _state.innervate_target = nil
    local floor_mana = (ctx.settings and ctx.settings.balance_innervate_mana) or 30
    if ctx.in_combat and ctx.is_group and ctx.me and _G_E.GetPartyMembers then
        local party = _G_E.GetPartyMembers()
        if party and type(party)=="table" then
            for _, u in ipairs(party) do
                if u then
                    local is_self = _G_E.same_unit and _G_E.same_unit(u, ctx.me)
                    if not is_self then
                        local class_id = nil
                        if _G_E.safe_field then
                            local getter = _G_E.safe_field(u, "get_class")
                            if getter then
                                local ok, val = pcall(getter, u)
                                if ok and type(val)=="number" then class_id = val end
                            end
                        end
                        if class_id and _HEALER_IDS[class_id] and _G_E.mana_pct then
                            if _G_E.mana_pct(u) <= (floor_mana+5) then
                                _state.innervate_target = u
                                break
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
    return _state
end

local function _mana_now(s, ctx) return s.mana_pct or ctx.mana or ctx.mana_pct or 100 end

local function _choose_nuke(s, ctx)
    local settings = ctx.settings
    local mana_floor = (settings and settings.balance_starfire_mana) or 40
    local m = _mana_now(s, ctx)
    if m < mana_floor then return "wrath" end
    if s.natures_grace_active then return "starfire" end
    return "starfire"
end

local _strategies = {
    {
        name="BarkskinDefense",
        matches=function(ctx)
            local threshold = (ctx.settings and ctx.settings.balance_barkskin_hp) or 40
            if (ctx.hp or 100) > threshold then return false end
            return _G_E.spell_ready(SPELLS.Barkskin, _G_E.PLAYER_UNIT, { skip_range = true })
        end,
        execute=function()
            return _G_E.try_cast(SPELLS.Barkskin, _G_E.PLAYER_UNIT, "[BALANCE] Barkskin defense")
        end,
    },
    {
        name="ManaPotionEmergency",
        matches=function(_, s)
            local floor = 15
            if (s.mana_pct or 100) > floor then return false end
            return s.mana_potion_id ~= nil
        end,
        execute=function(_, s)
            if _G_E.use_item_by_id then _G_E.use_item_by_id(s.mana_potion_id) end
            return true
        end,
    },
    {
        name="ForceOfNature",
        matches=function(ctx)
            if not ctx or not ctx.in_combat then return false end
            if not ctx.should_burst then return false end
            return _G_E.action_matches(ctx, _ACT_FON)
        end,
        execute=function(ctx) return _G_E.action_execute(ctx, _ACT_FON, "[BALANCE]") end,
    },
    {
        name="MoonkinForm",
        matches=function(ctx)
            if not (ctx.settings and ctx.settings.balance_moonkin_auto) then return false end
            if ctx.in_combat then return false end
            return _G_E.spell_ready(SPELLS.MoonkinForm, _G_E.PLAYER_UNIT, { skip_range = true })
        end,
        execute=function()
            return _G_E.try_cast(SPELLS.MoonkinForm, _G_E.PLAYER_UNIT, "[BALANCE] Moonkin Form")
        end,
    },
    {
        name="InnervateSelf",
        matches=function(ctx, s)
            if not ctx or not ctx.in_combat then return false end
            if not s.innervate_target then return false end
            local me = ctx.me or _G_E.GetPlayer()
            if not me then return false end
            if not (_G_E.same_unit and _G_E.same_unit(s.innervate_target, me)) then return false end
            return _G_E.spell_ready(_LOCAL_SPELLS.Innervate, s.innervate_target, { skip_range = true })
        end,
        execute=function(_, s)
            return _G_E.try_cast(_LOCAL_SPELLS.Innervate, s.innervate_target, "[BALANCE] Innervate self")
        end,
    },
    {
        name="RebirthBattleRez",
        matches=function(ctx)
            if not ctx.in_combat then return false end
            local find_dead = _G_E.find_dead_party_ally or (require("shared/find_dead_party_ally_sylvanas").find_dead_party_ally)
            local dead = find_dead and find_dead() or nil
            if not dead then return false end
            if not (dead.is_player and dead:is_player()) then return false end
            if ctx.tank_alive==false then return false end
            return _G_E.spell_ready(_LOCAL_SPELLS.Rebirth, dead)
        end,
        execute=function(ctx)
            local find_dead = _G_E.find_dead_party_ally or (require("shared/find_dead_party_ally_sylvanas").find_dead_party_ally)
            local dead = find_dead and find_dead() or nil
            if dead then
                return _G_E.try_cast(_LOCAL_SPELLS.Rebirth, dead, "[BALANCE] Rebirth battle rez")
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
            if not _G_E.spell_ready(SPELLS.Barkskin, _G_E.PLAYER_UNIT, { skip_range=true }) then return false end
            local threshold = (ctx.settings and ctx.settings.balance_barkskin_hp) or 40
            if (ctx.hp or 100) <= threshold then return false end
            return true
        end,
        execute=function()
            return _G_E.try_cast(SPELLS.Barkskin, _G_E.PLAYER_UNIT, "[BALANCE] Barkskin before Hurricane")
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
            if not _G_E.spell_ready(SPELLS.Hurricane, ctx.target) then return false end
            if _G_E.spell_ready(SPELLS.Barkskin, _G_E.PLAYER_UNIT, { skip_range=true }) and not s.barkskin_active then return false end
            return _G_E.action_matches(ctx, _ACT_HUR)
        end,
        execute=function(ctx) return _G_E.action_execute(ctx, _ACT_HUR, "[BALANCE]") end,
    },
    {
        name="FaerieFireDebuff",
        matches=function(ctx, s)
            -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
            local skip = _G_E.broken_api_throttled and _G_E.broken_api_throttled(SPELLS.FaerieFire, 2.0) or false
            if not skip then
                if (s.ff_remains or 0) > 5 then return false end
            end
            local target = ctx.target
            if not target then return false end
            if not ctx.has_valid_enemy_target then return false end
            if ctx.has_feral_druid then return false end
            return _G_E.spell_ready(SPELLS.FaerieFire, target)
        end,
        execute=function(ctx)
            return _G_E.try_cast(SPELLS.FaerieFire, ctx.target, "[BALANCE] Faerie Fire")
        end,
    },
    {
        name="InsectSwarmDoT",
        matches=function(ctx, s)
            -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
            local skip = _G_E.broken_api_throttled and _G_E.broken_api_throttled(SPELLS.InsectSwarm, 2.0) or false
            if not skip then
                if (s.insect_remains or 0) > 2 then return false end
            end
            if not ctx.target then return false end
            if not ctx.has_valid_enemy_target then return false end
            local settings = ctx.settings or {}
            if settings.balance_use_insect_swarm == false then return false end
            local min_sp = settings.balance_insect_swarm_min_sp or _INSECT_MIN_SP
            if (s.spell_damage or 0) < min_sp then return false end
            if (s.mana_pct or 100) < 10 then return false end
            return _G_E.action_matches(ctx, _ACT_IS)
        end,
        execute=function(ctx) return _G_E.action_execute(ctx, _ACT_IS, "[BALANCE]") end,
    },
    {
        name="MoonfireDoT",
        matches=function(ctx, s)
            -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
            local skip = _G_E.broken_api_throttled and _G_E.broken_api_throttled(SPELLS.Moonfire, 2.0) or false
            if not skip then
                if (s.moonfire_remains or 0) > 2 then return false end
            end
            if not ctx.target then return false end
            if not ctx.has_valid_enemy_target then return false end
            local settings = ctx.settings or {}
            local min_sp = settings.balance_moonfire_min_sp or _MOONFIRE_MIN_SP
            if (s.spell_damage or 0) < min_sp then return false end
            if (s.mana_pct or 100) < 10 then return false end
            return _G_E.action_matches(ctx, _ACT_MF)
        end,
        execute=function(ctx) return _G_E.action_execute(ctx, _ACT_MF, "[BALANCE]") end,
    },
    {
        name="StarfirePrimary",
        matches=function(ctx, s)
            if ctx.is_moving then return false end
            if not ctx.has_valid_enemy_target then return false end
            if (s.mana_pct or 100) < 15 then return false end
            if _choose_nuke(s, ctx) ~= "starfire" then return false end
            return _G_E.action_matches(ctx, _ACT_SF)
        end,
        execute=function(ctx) return _G_E.action_execute(ctx, _ACT_SF, "[BALANCE]") end,
    },
    {
        name="WrathFiller",
        matches=function(ctx, s)
            if ctx.is_moving then return false end
            if not ctx.has_valid_enemy_target then return false end
            if (s.mana_pct or 100) < 10 then return false end
            return _G_E.action_matches(ctx, _ACT_WR)
        end,
        execute=function(ctx) return _G_E.action_execute(ctx, _ACT_WR, "[BALANCE]") end,
    },
    {
        name="RemoveCurse",
        matches=function(ctx)
            if not (ctx.settings and ctx.settings.balance_auto_dispel) then return false end
            return _G_E.spell_ready(SPELLS.RemoveCurse, _G_E.PLAYER_UNIT, { skip_range = true })
        end,
        execute=function()
            return _G_E.try_cast(SPELLS.RemoveCurse, _G_E.PLAYER_UNIT, "[BALANCE] Remove Curse self")
        end,
    },
    {
        name="ManaPotion",
        matches=function(_, s)
            local threshold = 25
            if (s.mana_pct or 100) > threshold then return false end
            return s.mana_potion_id ~= nil
        end,
        execute=function(_, s)
            if _G_E.use_item_by_id then _G_E.use_item_by_id(s.mana_potion_id) end
            return true
        end,
    },
    {
        name="PvP_NaturesGrasp",
        matches=function(ctx)
            if not ctx.is_pvp then return false end
            if not ctx.melee_on_you then return false end
            return _G_E.spell_ready(_LOCAL_SPELLS.NaturesGrasp, _G_E.PLAYER_UNIT, { skip_range = true })
        end,
        execute=function()
            return _G_E.try_cast(_LOCAL_SPELLS.NaturesGrasp, _G_E.PLAYER_UNIT, "[BALANCE PvP] Nature's Grasp")
        end,
    },
    {
        name="PvP_EntanglingRoots",
        matches=function(ctx)
            if not ctx.is_pvp then return false end
            if not ctx.melee_on_you then return false end
            return _G_E.spell_ready(_LOCAL_SPELLS.EntanglingRoots, ctx.target)
        end,
        execute=function(ctx)
            return _G_E.try_cast(_LOCAL_SPELLS.EntanglingRoots, ctx.target, "[BALANCE PvP] Entangling Roots")
        end,
    },
    {
        name="PvP_Cyclone",
        matches=function(ctx)
            if not ctx.is_pvp then return false end
            if not ctx.enemy_healer then return false end
            return _G_E.spell_ready(_LOCAL_SPELLS.Cyclone, ctx.target)
        end,
        execute=function(ctx)
            return _G_E.try_cast(_LOCAL_SPELLS.Cyclone, ctx.target, "[BALANCE PvP] Cyclone on healer")
        end,
    },
    {
        name="WarStomp",
        matches=function(ctx, s)
            if not ctx.in_combat then return false end
            if (s.enemy_count or ctx.enemy_count or 1) < 4 then return false end
            return _G_E.spell_ready(_LOCAL_SPELLS.WarStomp, _G_E.PLAYER_UNIT, { skip_range = true })
        end,
        execute=function()
            return _G_E.try_cast(_LOCAL_SPELLS.WarStomp, _G_E.PLAYER_UNIT, "[BALANCE] War Stomp (4+ enemies)")
        end,
    },
    {
        name="MarkOfTheWild",
        matches=function(ctx)
            -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
            local skip = _G_E.broken_api_throttled and _G_E.broken_api_throttled(SPELLS.MarkOfTheWild, 3.0) or false
            if not skip then
                if _G_E.buff_up(_G_E.PLAYER_UNIT, _MOTW_BUFF) then return false end
            end
            if ctx.is_moving then return false end
            return _G_E.spell_ready(_LOCAL_SPELLS.MarkOfTheWild, _G_E.PLAYER_UNIT, { skip_range = true })
        end,
        execute=function()
            return _G_E.try_cast(_LOCAL_SPELLS.MarkOfTheWild, _G_E.PLAYER_UNIT, "[BALANCE] Mark of the Wild")
        end,
    },
    {
        name="ThornsBuff",
        matches=function(ctx)
            -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
            local skip = _G_E.broken_api_throttled and _G_E.broken_api_throttled(SPELLS.Thorns, 3.0) or false
            if not skip then
                if _G_E.buff_up(_G_E.PLAYER_UNIT, {26992,9910,9756,8914,1075,782,467}) then return false end
            end
            if ctx.in_combat then return false end
            return _G_E.spell_ready(_LOCAL_SPELLS.Thorns, _G_E.PLAYER_UNIT, { skip_range = true })
        end,
        execute=function()
            return _G_E.try_cast(_LOCAL_SPELLS.Thorns, _G_E.PLAYER_UNIT, "[BALANCE] Thorns")
        end,
    },
}

_G_E.rotation_registry:register("balance", _strategies, { get_state = _build_state })
return { strategies = _strategies, build_state = _build_state }
