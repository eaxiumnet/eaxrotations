-- balance_sylvanas.lua — Druid Balance (moonkin) rotation for TBC Anniversary (2.5.5).
-- WHAT:  ranged DPS rotation (Moonfire + Insect Swarm up, Faerie Fire, Starfire filler with Wrath for mana,
--         optional multi-DoT spread via TSHelper.get_dps_targets, Starfall, Force of Nature).
--         6 strategies use the declarative strategy DSL (fourth DSL adopter, first mana-based caster).
-- WHEN:  combat, in Moonkin form, with valid enemy target.
-- WHY:   mirrors wowsims/tbc-new balance APL and TBC guides (dots up, Faerie Fire, Starfire primary filler,
--         Starfall on CD, self-Innervate low mana, treants on CD; multi-DoT when enabled).
-- SAFETY: state.* reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end
local SPELLS = NS.DruidSpells or {}
local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
local _potion_helper = require("shared/potion_helper_sylvanas")
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { ITEMS = { potions = {} } } end
local _TBC_P = (TBC.ITEMS and TBC.ITEMS.potions) or {}
local _fnd_mod = require("shared/find_dead_party_ally_sylvanas")
local _find_dead_helper = _fnd_mod and _fnd_mod.find_dead_party_ally or nil
local _find_dead = NS.find_dead_party_ally or _find_dead_helper
local _ts_ok, TSHelper = pcall(require, "shared/ts_helper_sylvanas")
if not _ts_ok or type(TSHelper) ~= "table" then TSHelper = nil end
local _izi_ok, _izi = pcall(require, "common/izi_sdk")
if not _izi_ok or type(_izi) ~= "table" then _izi = nil end

local _INSECT_DEBUFF = { 27013, 24977, 24976, 24975, 24974, 5570 }
local _MOONFIRE_DEBUFF = { 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }
local _FAERIE_DEBUFF  = { 26993, 9907, 9749, 778, 770 }
local _NATURES_BUFF = { 16880 }
local _BARKSKIN_BUFF = { 22812 }
-- GotW first, then MotW ranks high→low (26990 = MotW r8, not Gift 26991).
local _MOTW_BUFF = { 26991, 21850, 21849, 26990, 9885, 9884, 8907, 5234, 6756, 5232, 1126, 24752, 39233, 16878 }
local _HEALER_IDS = { [2]=true, [5]=true, [7]=true, [11]=true }
local _INNERVATE_SCAN_INTERVAL = 2.0
local _last_innervate_scan_time = 0
local _MULTIDOT_SCAN_INTERVAL = 1.0
local _last_multidot_scan_time = 0

-- CC debuff IDs that damage would break (don't multi-DoT these targets)
local CC_DEBUFF_IDS = {
    118, 12824, 12825, 12826, 28271, 28272,  -- Polymorph
    6770, 2070, 11297,                        -- Sap
    1776,                                     -- Gouge
    2094,                                     -- Blind
    3355, 14308, 14309,                       -- Freezing Trap
    20066,                                    -- Repentance
    19386,                                    -- Wyvern Sting
    5782, 6213, 6215, 5484, 17928,            -- Fear / Howl of Terror
    2637, 18657, 18658,                       -- Hibernate
    33786,                                    -- Cyclone
    18647,                                    -- Banish
}

local function is_cc_target(unit)
    if not unit or not NS.debuff_up then return false end
    for _, cc_id in ipairs(CC_DEBUFF_IDS) do
        if NS.debuff_up(unit, { cc_id }) then return true end
    end
    return false
end

local function _unit_hp_pct(unit)
    if not unit then return 100 end
    local ok, hp = pcall(function() return unit:get_health_percentage() end)
    if ok and type(hp) == "number" then return hp end
    return 100
end

local function _is_valid_enemy(unit)
    if not unit then return false end
    local ok_v, valid = pcall(function()
        if unit.is_valid then return unit:is_valid() end
        return true
    end)
    if ok_v and valid == false then return false end
    local ok_d, dead = pcall(function()
        if unit.is_dead then return unit:is_dead() end
        return false
    end)
    if ok_d and dead then return false end
    return true
end

--- Collect enemy list for multi-DoT: prefer TSHelper.get_dps_targets, fall back to GetEnemiesInRange, then IZI.
---@param range number|nil
---@return table enemies
local function _multidot_enemy_list(range)
    if TSHelper and TSHelper.get_dps_targets then
        local ok, result = pcall(TSHelper.get_dps_targets, 10)
        if ok and type(result) == "table" and #result > 0 then
            return result
        end
    end
    if NS.GetEnemiesInRange then
        local ok, result = pcall(NS.GetEnemiesInRange, range or 30)
        if ok and type(result) == "table" and #result > 0 then return result end
    end
    -- IZI enemies() fallback (always available at runtime)
    if _izi and _izi.enemies then
        local ok, result = pcall(_izi.enemies, range or 30)
        if ok and type(result) == "table" then return result end
    end
    return {}
end

--- Check if a unit is in combat (engaged with someone — don't DoT patrols).
local function _is_in_combat(unit)
    if not unit then return false end
    local ok, combat = pcall(function()
        if unit.is_in_combat then return unit:is_in_combat() end
        return true  -- assume engaged if API unavailable
    end)
    return (ok and combat) or false
end

--- Find a valid enemy missing any of the given debuff IDs (multi-DoT spread target).
--- Skips CC'd targets, targets under 20% HP, and non-combat patrols.
---@param debuff_ids table
---@param range number|nil
---@return game_object|nil
local function _find_multidot_target(debuff_ids, range)
    if not debuff_ids then return nil end
    local enemies = _multidot_enemy_list(range)
    for _, enemy in ipairs(enemies) do
        if _is_valid_enemy(enemy) and _is_in_combat(enemy) and not is_cc_target(enemy) and _unit_hp_pct(enemy) >= 20 then
            -- IZI SDK: skip damage-immune targets (Divine Shield, Ice Block, etc.)
            local skip_immune = false
            if type(enemy.is_damage_immune) == "function" then
                local ok_im, im = pcall(enemy.is_damage_immune, enemy)
                if ok_im and im then skip_immune = true end
            end
            if not skip_immune then
                local has_dot = NS.debuff_up and NS.debuff_up(enemy, debuff_ids)
                if not has_dot then
                    return enemy
                end
            end
        end
    end
    return nil
end

--- Count enemies that currently have any of the given debuff IDs.
---@param debuff_ids table
---@param range number|nil
---@return number
local function _count_dotted(debuff_ids, range)
    local count = 0
    if not debuff_ids or not NS.debuff_up then return 0 end
    local enemies = _multidot_enemy_list(range)
    for _, enemy in ipairs(enemies) do
        if _is_valid_enemy(enemy) and NS.debuff_up(enemy, debuff_ids) then
            count = count + 1
        end
    end
    return count
end

-- Centralized spell resolver via spec_kit (replaces per-spec _LOCAL_SPELLS).
local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    Innervate       = define("Innervate", { 29166 }, "Innervate"),
    Rebirth         = define("Rebirth", { 26994,20748,20747,20742,20739,20484 }, "Rebirth"),
    Thorns          = define("Thorns", { 26992,9910,9756,8914,1075,782,467 }, "Thorns"),
    Cyclone         = define("Cyclone", { 33786 }, "Cyclone"),
    EntanglingRoots = define("EntanglingRoots", { 26989,9853,9852,5196,5195,1062,339 }, "EntanglingRoots"),
    NaturesGrasp    = define("NaturesGrasp", { 27009,17329,16813,16812,16811,16810,16689 }, "NaturesGrasp"),
    WarStomp        = define("WarStomp", { 20549 }, "WarStomp"),
    MarkOfTheWild   = define("MarkOfTheWild", { 26990,9885,9884,8907,5234,6756,5232,1126 }, "MarkOfTheWild"),
}

local _INSECT_MIN_SP = 800
local _MOONFIRE_MIN_SP = 800

local HEALTHSTONE_IDS = { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }
local MANA_GEM_ITEM_IDS = { 22044, 8008, 8007, 5513, 5514 } -- Emerald, Ruby, Citrine, Jade, Agate.

local function first_ready_mana_gem()
    if not NS.is_item_ready then return nil end
    for _, item_id in ipairs(MANA_GEM_ITEM_IDS) do
        local ok, ready = pcall(NS.is_item_ready, item_id)
        if ok and ready then return item_id end
    end
    return nil
end

local function use_mana_gem()
    local item_id = first_ready_mana_gem()
    if not item_id or not NS.use_item_by_id then return false end
    local ok, used = pcall(NS.use_item_by_id, item_id)
    return ok and used == true
end

local function first_ready_item(item_ids)
    if not NS.is_item_ready then return 0 end
    for i = 1, #item_ids do
        local item_id = item_ids[i]
        if NS.is_item_ready(item_id) then return item_id end
    end
    return 0
end

local _ACT_FON = { name="ForceOfNature", spell=SPELLS.ForceOfNature, position="target", combat=true, setting="use_cooldowns", cooldown=180, min_mana=25 }
local _ACT_HUR = { name="Hurricane", spell=SPELLS.Hurricane, position="target", enemy_count=3, hit_radius=8, hit_origin="target", not_moving=true, min_mana=35, cooldown=60 }
local _ACT_SF  = { name="Starfire", spell=SPELLS.Starfire, not_moving=true, min_mana=15 }
local _ACT_WR  = { name="Wrath", spell=SPELLS.Wrath, not_moving=true, min_mana=10 }
local _ACT_MF  = { name="Moonfire", spell=SPELLS.Moonfire, position="target", min_mana=10 }
local _ACT_IS  = { name="InsectSwarm", spell=SPELLS.InsectSwarm, position="target", min_mana=10 }

local _state = {
    insect_remains=0, moonfire_remains=0, ff_remains=0, natures_grace_active=false,
    barkskin_active=false, mana_pct=100,
    enemy_count=1, target_ttd=999, innervate_target=nil,
    healthstone_ready=0,
    multidot_enabled=false, multidot_max=3, multidot_range=30,
    dotted_moonfire_count=0, dotted_insect_count=0,
}

-- Schema for safe_state: custom defaults override kit defaults.
local BALANCE_SCHEMA = {
    insect_remains = 0,
    moonfire_remains = 0,
    ff_remains = 0,
    natures_grace_active = false,
    barkskin_active = false,
    mana_pct = 100,
    enemy_count = 1,
    target_ttd = 999,
    innervate_target = nil,
    healthstone_ready = 0,
    is_group = false,
    multidot_enabled = false,
    multidot_max = 3,
    multidot_range = 30,
    dotted_moonfire_count = 0,
    dotted_insect_count = 0,
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
        local group_aware = spec_kit.setting_bool(ctx, "druid_group_aware_utility", true)
        if ctx.in_combat and (group_aware and ctx.is_group) and ctx.me and NS.GetPartyMembers then
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

    -- Multi-DoT settings + throttled dotted-count scan (1s)
    local settings = ctx.settings or {}
    _state.multidot_enabled = settings.balance_multidot_enabled == true
    _state.multidot_max = settings.balance_multidot_max or 3
    _state.multidot_range = settings.balance_multidot_range or 30
    if _state.multidot_enabled and ctx.in_combat and (_state.enemy_count or 1) >= 2 then
        if now - _last_multidot_scan_time >= _MULTIDOT_SCAN_INTERVAL then
            _last_multidot_scan_time = now
            local range = _state.multidot_range
            _state.dotted_moonfire_count = _count_dotted(_MOONFIRE_DEBUFF, range)
            _state.dotted_insect_count = _count_dotted(_INSECT_DEBUFF, range)
        end
    else
        _state.dotted_moonfire_count = 0
        _state.dotted_insect_count = 0
    end

    -- safe_state proxy: structural nil-guard elimination (Pattern 14)
    return spec_kit.safe_state(_state, BALANCE_SCHEMA)
end

local function _mana_now(s, ctx) return s.mana_pct or ctx.mana or ctx.mana_pct or 100 end

local function _choose_nuke(s, ctx)
    local settings = ctx.settings
    local m = _mana_now(s, ctx)
    -- Nature's Grace active: Starfire for burst (NG reduces cast time).
    if s.natures_grace_active then return "starfire" end
    -- Mana conservation: Wrath has higher DPM (damage per mana) than Starfire.
    -- Wowsims/tbc-new and guides default to Starfire (higher DPCT) and use Wrath for mana conservation or filler.
    local mana_floor = (settings and settings.balance_wrath_mana) or 35
    if m < mana_floor then return "wrath" end
    -- Default nuke: Starfire (higher DPCT — wowsims-aligned).
    return "starfire"
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
    { name="ManaPotionEmergency" },  -- DSL-substituted at runtime
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
    { name="MoonkinForm" },  -- DSL-substituted at runtime
    {
        name="InnervateSelf",
        matches=function(ctx, s)
            if not ctx or not ctx.in_combat then return false end
            if not s.innervate_target then return false end
            local me = ctx.me or NS.GetPlayer()
            if not me then return false end
            if not (NS.same_unit and NS.same_unit(s.innervate_target, me)) then return false end
            return NS.spell_ready(ACTION.Innervate, s.innervate_target, { skip_range = true })
        end,
        execute=function(_, s)
            return NS.try_cast(ACTION.Innervate, s.innervate_target, "[BALANCE] Innervate self")
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
            return NS.spell_ready(ACTION.Rebirth, dead)
        end,
        execute=function(ctx)
            local find_dead = _find_dead
            local dead = find_dead and find_dead() or nil
            if dead then
                return NS.try_cast(ACTION.Rebirth, dead, "[BALANCE] Rebirth battle rez")
            end
            return false
        end,
    },
    {
        name="PreHurricaneBarkskin",
        matches=function(ctx, s)
            local min_targets = (ctx.settings and ctx.settings.balance_hurricane_targets) or 3
            if not (NS.aoe_target_meets and NS.aoe_target_meets(min_targets, (NS.AOE_RADIUS and NS.AOE_RADIUS.GROUND_8) or 8, ctx.target, ctx)) then return false end
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
            if not (NS.aoe_target_meets and NS.aoe_target_meets(min_targets, (NS.AOE_RADIUS and NS.AOE_RADIUS.GROUND_8) or 8, ctx.target, ctx)) then return false end
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
        name="MoonfireSpread",
        matches=function(ctx, s)
            local settings = ctx.settings or {}
            if settings.balance_multidot_enabled ~= true then return false end
            if not ctx.in_combat then return false end
            if (s.enemy_count or ctx.enemy_count or 1) < 2 then return false end
            if (s.moonfire_remains or 0) <= 0 then return false end
            local max_dots = s.multidot_max or settings.balance_multidot_max or 3
            if (s.dotted_moonfire_count or 0) >= max_dots then return false end
            if (s.mana_pct or 100) < 10 then return false end
            if (ctx.target_hp_pct or ctx.target_hp or 100) <= 20 then return false end
            if not SPELLS.Moonfire then return false end
            local range = s.multidot_range or settings.balance_multidot_range or 30
            local target = _find_multidot_target(_MOONFIRE_DEBUFF, range)
            if not target then return false end
            if not NS.spell_ready(SPELLS.Moonfire, target) then return false end
            ctx._balance_mf_spread_target = target
            return true
        end,
        execute=function(ctx)
            local target = ctx._balance_mf_spread_target
            if not target then return false end
            return NS.try_cast(SPELLS.Moonfire, target, "[BALANCE] Moonfire Spread")
        end,
    },
    {
        name="InsectSwarmSpread",
        matches=function(ctx, s)
            local settings = ctx.settings or {}
            if settings.balance_multidot_enabled ~= true then return false end
            if settings.balance_use_insect_swarm == false then return false end
            if not ctx.in_combat then return false end
            if (s.enemy_count or ctx.enemy_count or 1) < 2 then return false end
            if (s.insect_remains or 0) <= 0 then return false end
            local max_dots = s.multidot_max or settings.balance_multidot_max or 3
            if (s.dotted_insect_count or 0) >= max_dots then return false end
            if (s.mana_pct or 100) < 10 then return false end
            if (ctx.target_hp_pct or ctx.target_hp or 100) <= 20 then return false end
            if not SPELLS.InsectSwarm then return false end
            local range = s.multidot_range or settings.balance_multidot_range or 30
            local target = _find_multidot_target(_INSECT_DEBUFF, range)
            if not target then return false end
            if not NS.spell_ready(SPELLS.InsectSwarm, target) then return false end
            ctx._balance_is_spread_target = target
            return true
        end,
        execute=function(ctx)
            local target = ctx._balance_is_spread_target
            if not target then return false end
            return NS.try_cast(SPELLS.InsectSwarm, target, "[BALANCE] Insect Swarm Spread")
        end,
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
            -- Starfire is the primary nuke (higher DPCT than Wrath).
            -- Wrath is only used for mana conservation (see WrathFiller).
            if _choose_nuke(s, ctx) == "wrath" then return false end
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
            -- Wrath is a mana-conservation filler (lower DPCT but cheaper).
            -- Only used when _choose_nuke says wrath (low mana or long fight conservation).
            if _choose_nuke(s, ctx) ~= "wrath" then return false end
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
        name="ManaGem",
        matches=function(_, s)
            -- Wowsims-aligned: fire when we'd benefit from a gem (mana < ~85%)
            local threshold = (s and s.mana_gem_threshold) or 85
            if (s.mana_pct or 100) > threshold then return false end
            return first_ready_mana_gem() ~= nil
        end,
        execute=function()
            return use_mana_gem()
        end,
    },
    { name="ManaPotion" },  -- DSL-substituted at runtime
    { name="PvP_NaturesGrasp" },  -- DSL-substituted at runtime
    {
        name="PvP_EntanglingRoots",
        matches=function(ctx)
            if NS.pvp_trinket_used_recently(ctx.target) then return false end
            if not ctx.is_pvp then return false end
            if not (ctx.melee_on_you or false) then return false end
            return NS.spell_ready(ACTION.EntanglingRoots, ctx.target)
        end,
        execute=function(ctx)
            return NS.try_cast(ACTION.EntanglingRoots, ctx.target, "[BALANCE PvP] Entangling Roots")
        end,
    },
    {
        name="PvP_Cyclone",
        matches=function(ctx)
            if NS.DRTracker and NS.DRTracker.is_dr_immune and ctx.target and NS.DRTracker.is_dr_immune(ctx.target, "cyclone") then return false end
            if NS.pvp_trinket_used_recently(ctx.target) then return false end
            if not ctx.is_pvp then return false end
            if not (ctx.enemy_healer or false) then return false end
            return NS.spell_ready(ACTION.Cyclone, ctx.target)
        end,
        execute=function(ctx)
            return NS.try_cast(ACTION.Cyclone, ctx.target, "[BALANCE PvP] Cyclone on healer")
        end,
    },
    { name="WarStomp" },  -- DSL-substituted at runtime
    { name="Healthstone" },  -- DSL-substituted at runtime
    {
        name="MarkOfTheWild",
        matches=function(ctx)
            if not spec_kit.setting_bool(ctx, "use_self_buffs", true) then return false end
            local spell = ACTION.MarkOfTheWild or SPELLS.MarkOfTheWild
            -- Recent-cast lockout (was inverted: throttled path used to keep casting).
            if NS.broken_api_throttled and NS.broken_api_throttled(spell, 300.0) then
                return false
            end
            -- Never overwrite Gift / higher MotW with a lower MotW rank.
            if NS.buff_would_downgrade and NS.buff_would_downgrade(NS.PLAYER_UNIT or ctx.me, _MOTW_BUFF, spell) then
                return false
            end
            if NS.buff_up and NS.buff_up(NS.PLAYER_UNIT, _MOTW_BUFF) then return false end
            if ctx.is_moving then return false end
            return NS.spell_ready(ACTION.MarkOfTheWild, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute=function()
            return NS.try_cast(ACTION.MarkOfTheWild, NS.PLAYER_UNIT, "[BALANCE] Mark of the Wild")
        end,
    },
    {
        name="ThornsBuff",
        matches=function(ctx)
            if not spec_kit.setting_bool(ctx, "use_self_buffs", true) then return false end
            local spell = ACTION.Thorns or SPELLS.Thorns
            local thorns_buffs = { 26992, 9910, 9756, 8914, 1075, 782, 467 }
            if NS.broken_api_throttled and NS.broken_api_throttled(spell, 300.0) then
                return false
            end
            if NS.buff_would_downgrade and NS.buff_would_downgrade(NS.PLAYER_UNIT or ctx.me, thorns_buffs, spell) then
                return false
            end
            if NS.buff_up and NS.buff_up(NS.PLAYER_UNIT, thorns_buffs) then return false end
            if ctx.in_combat then return false end
            return NS.spell_ready(ACTION.Thorns, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute=function()
            return NS.try_cast(ACTION.Thorns, NS.PLAYER_UNIT, "[BALANCE] Thorns")
        end,
    },
}

-- ============================================================================
-- Declarative Strategy DSL definitions (fourth DSL adopter, first mana-based caster)
-- ============================================================================
-- These strategies are compiled from declarative definitions and replace the
-- inline match/execute pairs in the strategies table above for the same names.
-- This proves the DSL generalizes beyond warrior rage and rogue energy/combo
-- points to mana-based caster resource models (mana thresholds, DoT windows,
-- spell readiness, PvP gates, AoE enemy count checks).
local DSL_DEFS = {
    {
        name = "ManaPotionEmergency",
        conditions = {
            { type = "state", field = "mana_pct", op = "<=", value = 15 },
        },
        action = { type = "custom", fn = function(context, state)
            return _potion_helper.try_use_potion(context, _potion_helper.MANA_POTION_IDS)
        end },
    },
    {
        name = "ManaPotion",
        conditions = {
            { type = "state", field = "mana_pct", op = "<=", value = 25 },
        },
        action = { type = "custom", fn = function(context, state)
            return _potion_helper.try_use_potion(context, _potion_helper.MANA_POTION_IDS)
        end },
    },
    {
        name = "MoonkinForm",
        conditions = {
            { type = "custom", fn = function(context, state)
                if not (context.settings and context.settings.balance_moonkin_auto) then return false end
                return true
            end },
            { type = "in_combat", invert = true },
            { type = "spell_ready", spell = SPELLS.MoonkinForm, target = "self", opts = { skip_range = true } },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(SPELLS.MoonkinForm, NS.PLAYER_UNIT, "[BALANCE] Moonkin Form")
        end },
    },
    {
        name = "WarStomp",
        conditions = {
            { type = "in_combat" },
            { type = "enemy_count", op = ">=", value = 4 },
            { type = "spell_ready", spell = ACTION.WarStomp, target = "self", opts = { skip_range = true } },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.WarStomp, NS.PLAYER_UNIT, "[BALANCE] War Stomp (4+ enemies)")
        end },
    },
    {
        name = "Healthstone",
        conditions = {
            { type = "in_combat" },
            { type = "hp_threshold", unit = "self", op = "<=", value = 28 },
            { type = "state", field = "healthstone_ready", op = ">", value = 0 },
        },
        action = { type = "custom", fn = function(context, state)
            local item_id = first_ready_item(HEALTHSTONE_IDS)
            if item_id > 0 and NS.use_item_by_id then
                return NS.use_item_by_id(item_id, context.me) and true or false
            end
            return false
        end },
    },
    {
        name = "PvP_NaturesGrasp",
        conditions = {
            { type = "is_pvp" },
            { type = "context", field = "melee_on_you", op = "truthy" },
            { type = "spell_ready", spell = ACTION.NaturesGrasp, target = "self", opts = { skip_range = true } },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.NaturesGrasp, NS.PLAYER_UNIT, "[BALANCE PvP] Nature's Grasp")
        end },
    },
}

-- Compile declarative strategies, injecting build_state so unit tests that call
-- strategy.matches(context) without state get a freshly-built state.
local DSL_STRATEGIES = dsl.compile_strategies(DSL_DEFS, { get_state = build_state })

-- ============================================================================
-- DSL in-place substitution (preserves priority order)
-- ============================================================================
-- Build a lookup of DSL strategies by name and replace the inline entries
-- at the same indices. This preserves the exact priority order while swapping
-- in the declaratively-compiled match/execute functions.
local DSL_BY_NAME = {}
for i = 1, #DSL_STRATEGIES do
    DSL_BY_NAME[DSL_STRATEGIES[i].name] = DSL_STRATEGIES[i]
end

for i = 1, #strategies do
    local dsl_strategy = DSL_BY_NAME[strategies[i].name]
    if dsl_strategy then
        strategies[i] = dsl_strategy
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("balance", strategies, { get_state = build_state })
end
return { strategies = strategies, build_state = build_state }

