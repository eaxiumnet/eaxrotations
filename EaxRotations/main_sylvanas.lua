-- Readability notes:
--   What: update dispatcher for class middleware and selected playstyle strategies.
--   When: main.lua calls on_rotation_update from the Sylvanas update callback.
--   Why: all strategies share one protected execution path and cannot call nil execute.
--   Safety: matches and execute are pcall-wrapped; bad entries are logged and skipped.

-- Decision notes:
--   Dispatcher owns one context table and reuses it to avoid per-frame allocation churn.
--   Selected target is never auto-replaced; rotations act on player intent unless a class strategy explicitly says otherwise.
--   First successful strategy wins, which makes priority order auditable and prevents double-casting in one tick.
local NS = _G.EaxRotations
if not NS then return nil end

local M = {}
local _context = {}
local _combat_start_time = nil
local was_in_combat = false
local _ooc_ok, ooc_manager = pcall(require, "shared/ooc_manager_sylvanas")
if not _ooc_ok then ooc_manager = nil end
local _burst_ok, BurstLogic = pcall(require, "shared/burst_logic_sylvanas")
if not _burst_ok or type(BurstLogic) ~= "table" then BurstLogic = { should_auto_burst = function() return nil end } end
local _forecast_gate_ok = pcall(require, "shared/combat_forecast_gate_sylvanas")
if not _forecast_gate_ok and not NS.should_use_long_cd then NS.should_use_long_cd = function() return true end end
local _combat_forecast_ok, combat_forecast = pcall(require, "common/modules/combat_forecast")
if not _combat_forecast_ok or type(combat_forecast) ~= "table" then combat_forecast = nil end
local _buff_db_ok, buffs = pcall(require, "common/buff_db")
if not _buff_db_ok or type(buffs) ~= "table" then buffs = {} end
local BLOODLUST_IDS = buffs.BLOODLUST or { 2825, 32182 }
local DRUMS_IDS = buffs.DRUMS or { 35475, 35474, 35473, 35476 }

-- Spell queue module is loaded here so the dispatcher knows it is available.
-- Actual queueing happens inside NS.try_cast() in core_sylvanas.lua.
local _spell_queue_ok, spell_queue_module = pcall(require, "common/modules/spell_queue")
if not _spell_queue_ok or type(spell_queue_module) ~= "table" then spell_queue_module = nil end

-- Expose for strategy access; nil if unavailable.
NS.spell_queue = spell_queue_module

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if ok then return a end
    NS.log_error("rotation callback failed: " .. tostring(a))
    return nil
end

if NS.init_izi_buff_events then pcall(NS.init_izi_buff_events) end

local function get_target(me)
    local fallback_get_target = NS.safe_field and NS.safe_field(me, "get_target") or nil
    return NS.GetTarget and NS.GetTarget() or (fallback_get_target and safe(fallback_get_target, me) or nil)
end

local function valid_enemy(me, target)
    return NS.is_hostile_unit and NS.is_hostile_unit(me, target) or false
end

local function find_enemy_target(me, selected)
    if valid_enemy(me, selected) then return selected end
    return nil  -- Never auto-acquire enemies; only cast on selected target
end

local _cached_enemies, _cached_enemies_time = nil, -1
local function throttled_enemies()
    local now = NS.game_time_ms()
    if now - _cached_enemies_time > 100 then
        _cached_enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(40) or nil
        _cached_enemies_time = now
    end
    return _cached_enemies
end

local function throttled_enemies_count()
    local enemies = throttled_enemies()
    if type(enemies) ~= "table" then return 0 end
    return enemies.n or #enemies
end

local function combo_points(me)
    local combo_points_current = NS.safe_field and NS.safe_field(me, "combo_points_current") or nil
    local v = combo_points_current and safe(combo_points_current, me) or nil
    local get_power = NS.safe_field and NS.safe_field(me, "get_power") or nil
    if type(v) ~= "number" and get_power then v = safe(get_power, me, 4) end
    return type(v) == "number" and v or 0
end

local function target_time_to_die(target)
    local time_to_die = NS.safe_field and (NS.safe_field(target, "time_to_die") or NS.safe_field(target, "get_time_to_death")) or nil
    local value = time_to_die and safe(time_to_die, target) or nil
    return type(value) == "number" and value > 0 and value or nil
end

local function unit_bool(unit, ...)
    if not unit or not NS.safe_field then return false end
    for i = 1, select("#", ...) do
        local fn = NS.safe_field(unit, select(i, ...))
        if fn and safe(fn, unit) == true then return true end
    end
    return false
end

local function build_context()
    for k in pairs(_context) do _context[k] = nil end
    local me = NS.GetPlayer()
    if not me then NS.current_context = nil; return nil end
    local selected_target = get_target(me)
    local target = find_enemy_target(me, selected_target)
    local is_in_combat = NS.safe_field and NS.safe_field(me, "is_in_combat") or nil
    local in_combat = is_in_combat and safe(is_in_combat, me) == true or false
    
    -- Combat start/end detection for callbacks
    if in_combat and not was_in_combat then
        -- Combat started
        if NS._fire_combat_start then NS._fire_combat_start(_context) end
    elseif not in_combat and was_in_combat then
        -- Combat ended
        if NS._fire_combat_end then NS._fire_combat_end(_context) end
    end
    was_in_combat = in_combat
    
    if not _combat_start_time and me and in_combat then _combat_start_time = NS.time_now() end
    if _combat_start_time and me and not in_combat then _combat_start_time = nil end
    local enemy_ok = valid_enemy(me, target)
    local count = throttled_enemies_count()
    local ttd = enemy_ok and target_time_to_die(target) or nil
    _context.me = me
    _context.target = target
    _context.in_combat = in_combat
    _context.has_target = target ~= nil
    _context.has_valid_enemy_target = enemy_ok
    _context.target_hp = enemy_ok and NS.unit_health_pct(target) or 100
    _context.hp = NS.unit_health_pct(me)
    _context.player_hp = _context.hp
    _context.mana_pct = NS.mana_pct(me)
    _context.player_mana = _context.mana_pct
    _context.player_mana_pct = _context.mana_pct
    _context.gcd_remains = NS.gcd_remains and NS.gcd_remains() or 0
    _context.on_gcd = (_context.gcd_remains or 0) > 0
    _context.combat_time = _combat_start_time and (NS.time_now() - _combat_start_time) or 0
    _context.rage = NS.power_current(NS.POWER_RAGE)
    _context.player_rage = _context.rage
    _context.energy = NS.power_current(NS.POWER_ENERGY)
    _context.player_energy = _context.energy
    _context.focus = NS.power_current(NS.POWER_FOCUS)
    _context.bloodlust_active = me and NS.buff_up(me, BLOODLUST_IDS) or false
    _context.drums_active = me and NS.buff_up(me, DRUMS_IDS) or false
    _context.should_burst = BurstLogic.should_auto_burst(_context, {
        is_bloodlust_active = function() return _context.bloodlust_active end,
        is_drums_active = function() return _context.drums_active end,
    })
    _context.burst_reason = _context.should_burst and "burst_conditions_met" or nil
    -- target_distance uses get_distance when available, otherwise falls back to melee range check
    local dist_ok, dist_val = pcall(function() return target and NS.safe_field(target, "get_distance") and target:get_distance(me) end)
    _context.target_range = (dist_ok and type(dist_val) == "number") and dist_val or (_context.in_melee_range and 5 or 40)
    _context.target_distance = _context.target_range
    _context.in_melee_range = target and target.is_in_melee_range and target:is_in_melee_range(5) or false
    _context.combo_points = combo_points(me)
    _context.enemy_count = count
    _context.enemies_count = count
    _context.stance = NS.get_player_stance()
    _context.is_moving = unit_bool(me, "is_moving")
    _context.is_casting = unit_bool(me, "is_casting", "is_casting_spell")
    _context.is_channeling = unit_bool(me, "is_channeling", "is_channelling_spell")
    if not _context.is_casting and not _context.is_channeling then
        _context.is_channeling = unit_bool(me, "is_channeling_or_casting")
    end
    _context.is_pvp = NS.is_pvp_zone and NS.is_pvp_zone() or false
    _context.settings = NS.settings or {}
    _context.ttd = ttd or 999
    _context.force_burst = NS.force_burst_active and NS.force_burst_active() or false
    _context.force_defensive = NS.force_defensive_active and NS.force_defensive_active() or false
    _context.force_gap = NS.force_gap_active and NS.force_gap_active() or false
    _context.has_breakable_cc_nearby = NS.has_breakable_cc_nearby and NS.has_breakable_cc_nearby() or false
    _context.target_is_player = target and NS.safe_field and NS.safe_field(target, "is_player") and target:is_player() or false
    _context.target_is_boss = target and NS.safe_field and NS.safe_field(target, "is_boss") and target:is_boss() or false
    _context.ttd = ttd or 999
    if combat_forecast and type(combat_forecast.get_forecast_single) == "function" then
        local ok, forecast = pcall(combat_forecast.get_forecast_single, target)
        if ok and type(forecast) == "number" and forecast > 0 then
            _context.combat_length_forecast = forecast
        else
            _context.combat_length_forecast = _context.ttd or 999
        end
    else
        _context.combat_length_forecast = _context.ttd or 999
    end
    _context.ttd_known = ttd ~= nil
    NS.current_context = _context
    return _context
end

local last_playstyle_warning = nil

local function normalize_playstyle(registry, active)
    if type(registry) ~= "table" or type(registry.playstyles) ~= "table" then return active end
    if active ~= nil and registry.playstyles[active] then return active end

    local wanted = tostring(active or ""):lower()
    if registry.playstyles[wanted] then return wanted end
    if wanted == "affinity" and registry.playstyles.affliction then return "affliction" end

    local config = registry.class_config or {}
    for i = 1, #(config.playstyles or {}) do
        local entry = config.playstyles[i]
        local name = type(entry) == "table" and entry.name or entry
        local display = type(entry) == "table" and entry.display_name or entry
        if type(name) == "string" and (wanted == name:lower() or wanted == tostring(display or ""):lower()) then
            return name
        end
    end

    local fallback = config.default_playstyle
    if fallback and registry.playstyles[fallback] then
        local key = tostring(active or "nil") .. "->" .. tostring(fallback)
        if last_playstyle_warning ~= key then
            last_playstyle_warning = key
            NS.log_warning("Invalid playstyle '" .. tostring(active) .. "'; falling back to " .. tostring(fallback))
        end
        if NS.set_setting then NS.set_setting("active_playstyle", fallback) end
        return fallback
    end
    return active
end

local last_trace_ms = -10000
local function trace_no_action(active, context, reason)
    if not NS.get_setting or not (NS.get_setting("debug_system", false) or NS.get_setting("log_context", false)) then return end
    local now = NS.game_time_ms and NS.game_time_ms() or 0
    if now - last_trace_ms < 1000 then return end
    last_trace_ms = now
    local gates = NS.explain_context_gates and NS.explain_context_gates(context) or "context=?"
    NS.log("[TRACE] no action active=" .. tostring(active) .. " reason=" .. tostring(reason or "none") .. " " .. gates)
end

local HEALING_PLAYSTYLES = {
    holy = true,
    discipline = true,
    restoration = true,
    resto = true,
}

local function contains_any(value, needles)
    if type(value) ~= "string" then return false end
    for i = 1, #needles do
        if value:find(needles[i], 1, true) then return true end
    end
    return false
end

local HEALING_NAMES = {
    "heal", "renew", "mending", "lifebloom", "rejuvenation", "regrowth",
    "powerwordshield", "pws", "circleofhealing", "prayerofhealing",
    "bindingheal", "holyshock", "layonhands", "earthshield", "smartgroupheal",
    "smartheal", "naturesswiftness",
}

local DAMAGE_NAMES = {
    "idle", "smite", "shadowwordpain", "holyfire", "mindblast",
    "shadowworddeath", "mindflay", "judgement", "crusaderstrike",
    "consecration", "execute", "mortalstrike", "whirlwind", "bloodthirst",
    "fireball", "frostbolt", "arcane", "scorch", "shadowbolt",
}

local COOLDOWN_NAMES = {
    "avengingwrath", "combustion", "icyveins", "arcanepower", "rapidfire",
    "bestialwrath", "bloodfury", "berserking", "innervate", "shadowfiend",
    "innerfocus", "sweepingstrikes", "recklessness", "deathwish",
    "bladeflurry", "adrenalinerush", "bloodlust", "shamanisticrage",
}

local UTILITY_NAMES = {
    "interrupt", "kick", "pummel", "counterspell", "spelllock", "silence",
    "cleanse", "dispel", "purify", "cure", "fade", "feign", "vanish",
    "evasion", "sprint", "cower", "righteousfury", "battletrance",
    "battleshout", "commandingshout", "watershield", "shadowform",
    "bearform", "catform", "moonkinform", "stance", "thunderclap",
    "demoshout", "demoralizing", "sunder", "faeriefire",
}

local DEFENSIVE_NAMES = {
    "shieldblock", "barkskin", "iceblock", "manashield", "divineshield",
    "frenziedregeneration", "shieldwall", "laststand", "holyshield",
}

local function strategy_category(strategy, list_name, active)
    if type(strategy) ~= "table" then return "damage" end
    if type(strategy.category) == "string" then return strategy.category end
    local name = tostring(strategy.name or ""):lower():gsub("%s+", "")

    if contains_any(name, HEALING_NAMES) then return "healing" end
    if contains_any(name, DEFENSIVE_NAMES) then return "utility" end
    if strategy.is_burst or contains_any(name, COOLDOWN_NAMES) then return "cooldown" end
    if contains_any(name, UTILITY_NAMES) then return "utility" end
    if list_name == "middleware" then return "utility" end
    if HEALING_PLAYSTYLES[tostring(active or ""):lower()] then
        if contains_any(name, DAMAGE_NAMES) then return "damage" end
        return "healing"
    end

    return "damage"
end

local function strategy_allowed(strategy, list_name, active, context)
    local settings = context.settings or {}
    local category = strategy_category(strategy, list_name, active)
    local is_healer = HEALING_PLAYSTYLES[tostring(active or ""):lower()] == true

    if settings.utility_enabled == false and category == "utility" then return false end
    if settings.healing_enabled == false and (category == "healing" or (is_healer and category == "cooldown")) then return false end
    if settings.damage_enabled == false and (category == "damage" or (category == "cooldown" and not is_healer)) then return false end
    if settings.use_cooldowns == false and category == "cooldown" and not context.should_burst then return false end
    return true
end

local function run_list(name, list, options, context)
    if type(list) ~= "table" then return false end
    local state = context
    if options and options.get_state then state = safe(options.get_state, context) or context end
    if options and options.context_builder then state = safe(options.context_builder, context) or context end
    for i = 1, #list do
        local strategy = list[i]
        if type(strategy) == "table" then
            if not strategy_allowed(strategy, name, context.active_playstyle, context) then
                -- Toggle-disabled rows are skipped before matches so they do not mutate context.
            elseif type(strategy.execute) ~= "function" then
                NS.log_warning(name .. " strategy " .. tostring(strategy.name or i) .. " missing execute")
            else
                local ok = true
                if type(strategy.matches) == "function" then ok = safe(strategy.matches, context, state) == true end
                if ok and safe(strategy.execute, context, state) then return true end
            end
        end
    end
    return false
end

function M.on_rotation_update()
    local context = build_context()
    if not context then return false end
    if not context.in_combat and not context.has_valid_enemy_target then
        -- Only run OOC manager when there's no valid enemy target
        if ooc_manager and ooc_manager.on_update and safe(ooc_manager.on_update, context) then return true end
        trace_no_action("none", context, "idle_no_enemy")
        return false
    end
    local registry = NS.rotation_registry
    local config = registry and registry.class_config or nil
    local active = normalize_playstyle(registry, NS.get_setting("active_playstyle", config and config.default_playstyle))
    context.active_playstyle = active
    local class_key = config and config.class_key
    if run_list("middleware", class_key and NS.class_middleware[class_key], nil, context) then return true end
    local fired = run_list(tostring(active), registry and registry.playstyles[active], registry and registry.options[active], context)
    if not fired then trace_no_action(active, context, "strategies_blocked") end
    return fired
end

--[[
Unified dispatcher — available for classes that migrate to NS.register_strategy().
Combines middleware + playstyle strategies into a single priority-ordered dispatch list
registered via NS.register_strategy(). Uses NS.run_unified_strategies() instead of
the legacy two-loop run_list() approach.

Class middleware is still executed FIRST (via run_list) so existing class_middleware
files continue to work. As classes migrate middleware entries to register_strategy(),
that pre-flight will naturally become a no-op.
]]
function M.on_rotation_update_unified()
    local context = build_context()
    if not context then return false end
    if not context.in_combat and not context.has_valid_enemy_target then
        -- Only run OOC manager when there's no valid enemy target
        if ooc_manager and ooc_manager.on_update and safe(ooc_manager.on_update, context) then return true end
        trace_no_action("none", context, "idle_no_enemy")
        return false
    end
    local registry = NS.rotation_registry
    local config = registry and registry.class_config or nil
    local active = normalize_playstyle(registry, NS.get_setting("active_playstyle", config and config.default_playstyle))
    context.active_playstyle = active
    local class_key = config and config.class_key
    -- Run legacy class middleware first; new unified entries are in NS.unified_registry
    if run_list("middleware", class_key and NS.class_middleware[class_key], nil, context) then return true end
    local fired = NS.run_unified_strategies(context)
    if not fired then trace_no_action(active, context, "unified_strategies_blocked") end
    return fired
end

NS.on_rotation_update = M.on_rotation_update
NS.on_rotation_update_unified = M.on_rotation_update_unified
NS.log("Rotation dispatcher loaded")
return M
