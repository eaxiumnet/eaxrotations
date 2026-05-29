
local NS = _G.EaxRotations
if not NS then return nil end

local BASE_SPELLS = NS.DruidSpells or {}
local SPELLS = BASE_SPELLS

local POUNCE = BASE_SPELLS.Pounce or (NS.spell_action and NS.spell_action({ 9827, 9005 }, "Pounce"))
local TRACK_HUMANOIDS = BASE_SPELLS.TrackHumanoids or (NS.spell_action and NS.spell_action({ 5225 }, "TrackHumanoids"))

local STANCE_CAT = 3
local ENERGY_CAP = 100
local ENERGY_TICK_INTERVAL = 2.0
local ENERGY_PER_TICK = 20
local POWERSHIFT_GAIN_FUROR = 40
local POWERSHIFT_GAIN_WOLFSHEAD = 60
local POWERSHIFT_IGNORE_WINDOW = 0.8
local POWERSHIFT_MIN_MANA = 8
local POWERSHIFT_SAFE_CP = 4
local SHRED_COST = 42
local RAKE_COST = 35
local RIP_COST = 30
local BITE_COST = 35
local RAVAGE_COST = 60
local POUNCE_COST = 50
local TIGERS_FURY_ENERGY = 30
local RIP_REFRESH_WINDOW = 2.0
local RAKE_REFRESH_WINDOW = 3.0
local FAERIE_FIRE_REFRESH = 6.0
local MIN_RIP_TTD = 10.0
local MIN_RAKE_TTD = 6.0
local EXECUTE_HP = 25
local HARD_EXECUTE_HP = 20
local MELEE_RANGE = 5.0
local DASH_RANGE = 12.0
local TRAVEL_FORM_RANGE = 25.0
local LONG_TTD = 20.0
local SHORT_TTD = 8.0
local AP_UPGRADE_RATIO = 1.08
local STRONG_AP_UPGRADE_RATIO = 1.15
local HIGH_AP_UPGRADE_RATIO = 1.05

local RIP_DEBUFF = { 1079 }
local RAKE_DEBUFF = { 9904, 1824, 1823, 1822 }
local FAERIE_FIRE_DEBUFF = { 17392, 17391, 17390, 16857,  9907, 9749, 778, 770 }
local PROWL_BUFF = { 9913, 6783, 5215 }
local POUNCE_DEBUFF = { 9827, 9005 }
local OMEN_OF_CLARITY_BUFF = { 16864 }
local TIGERS_FURY_BUFF = { 9846, 9845, 6793, 5217 }
local DASH_BUFF = { 9821, 1850 }
local BARKSKIN_BUFF = { 22812 }
local TRACK_HUMANOIDS_BUFF = { 5225 }
local WOLFSHEAD_BUFF = { 17770 }

local cat_state = {
    now = 0,
    me = nil,
    target = nil,
    settings = nil,
    hp = 100,
    mana_pct = 100,
    energy = 0,
    projected_energy = 0,
    combo_points = 0,
    enemy_count = 1,
    target_hp = 100,
    target_ttd = 0,
    target_range = 0,
    in_combat = false,
    is_pvp = false,
    is_player_target = false,
    is_stealthed = false,
    is_cat = false,
    is_behind = false,
    clearcasting = false,
    has_tigers_fury = false,
    has_dash = false,
    has_barkskin = false,
    has_track_humanoids = false,
    has_wolfshead = false,
    rip_remains = 0,
    rake_remains = 0,
    faerie_fire_remains = 0,
    pounce_remains = 0,
    rip_ap = 0,
    rake_ap = 0,
    attack_power = 0,
    next_tick_in = ENERGY_TICK_INTERVAL,
    last_energy = 0,
    last_tick_time = 0,
    last_shift_time = -100,
    tick_confident = false,
    pooling = false,
    should_powershift = false,
    should_pool_for_rip = false,
    should_pool_for_shred = false,
    should_execute = false,
    should_tab_rake = false,
    should_aoe = false,
}

local snapshot_state = {
    rip_target = nil,
    rake_target = nil,
    rip_ap = 0,
    rake_ap = 0,
    rip_cast_time = 0,
    rake_cast_time = 0,
}

local function safe_method(object, method_name, fallback)
    if not object then return fallback end
    local method = object[method_name]
    if type(method) ~= "function" then return fallback end
    local ok, value = pcall(method, object)
    if not ok or value == nil then return fallback end
    return value
end

local function safe_method_arg(object, method_name, arg, fallback)
    if not object then return fallback end
    local method = object[method_name]
    if type(method) ~= "function" then return fallback end
    local ok, value = pcall(method, object, arg)
    if not ok or value == nil then return fallback end
    return value
end



local function spell_exists(spell)
    if spell == nil then return false end
    if not NS.spell_exists then return true end
    return NS.spell_exists(spell)
end

local function spell_ready(spell, target, opts)
    if not spell_exists(spell) then return false end
    return NS.spell_ready and NS.spell_ready(spell, target, opts) or false
end

local function buff_up(unit, buff)
    return unit ~= nil and NS.buff_up and NS.buff_up(unit, buff) or false
end

local function debuff_remains(unit, debuff)
    return unit ~= nil and NS.debuff_remains and NS.debuff_remains(unit, debuff) or 0
end

local function get_attack_power(context, me)
    if context and type(context.attack_power) == "number" then return context.attack_power end
    if NS.attack_power then return NS.attack_power() or 0 end
    if NS.get_attack_power then return NS.get_attack_power() or 0 end
    local ap = safe_method(me, "get_attack_power", nil)
    if type(ap) == "number" then return ap end
    return 0
end

local function get_combo_points(context, target)
    if type(context.combo_points) == "number" then return context.combo_points end
    if type(context.cp) == "number" then return context.cp end
    if NS.combo_points then return NS.combo_points(target) or 0 end
    if NS.get_combo_points then return NS.get_combo_points(target) or 0 end
    return 0
end

local function get_energy(context)
    if type(context.energy) == "number" then return context.energy end
    local me = context.me or (NS.GetPlayer and NS.GetPlayer())
    local from_unit = safe_method_arg(me, "get_power", NS.POWER_ENERGY or 3, nil)
    if type(from_unit) == "number" then return from_unit end
    if NS.power_current and NS.POWER_ENERGY then return NS.power_current(NS.POWER_ENERGY) or 0 end
    if NS.energy then return NS.energy() or 0 end
    return 0
end

local function get_mana_pct(context)
    if type(context.mana_pct) == "number" then return context.mana_pct end
    if NS.power_pct and NS.POWER_MANA then return NS.power_pct(NS.POWER_MANA) or 100 end
    return 100
end

local function get_now()
    return NS.time_now and NS.time_now() or 0
end

local function is_target_player(target, context)
    if context and context.is_target_player ~= nil then return context.is_target_player == true end
    if context and context.target_is_player ~= nil then return context.target_is_player == true end
    return safe_method(target, "is_player", false) == true
end

local function get_target_range(me, target, context)
    if type(context.target_range) == "number" then return context.target_range end
    if type(context.range) == "number" then return context.range end
    return safe_method_arg(me, "get_distance", target, 0)
end

local function is_behind_target(target, context, settings)
    if NS.setting_bool(settings, "cat_shred_positional", true) == false then return true end
    if context and context.is_behind ~= nil then return context.is_behind == true end
    if NS.is_behind_target then return NS.is_behind_target(target) == true end
    return false
end

local function estimate_next_tick(state)
    if not state.tick_confident or state.last_tick_time <= 0 then return ENERGY_TICK_INTERVAL end
    local elapsed = state.now - state.last_tick_time
    if elapsed < 0 or elapsed > ENERGY_TICK_INTERVAL * 3 then return ENERGY_TICK_INTERVAL end
    local ticks = math.floor(elapsed / ENERGY_TICK_INTERVAL)
    local since_last = elapsed - (ticks * ENERGY_TICK_INTERVAL)
    return math.max(0, ENERGY_TICK_INTERVAL - since_last)
end

local function update_energy_tick(state)
    local delta = state.energy - state.last_energy
    if delta > 0 and delta <= 25 and (state.now - state.last_shift_time) > POWERSHIFT_IGNORE_WINDOW then
        state.last_tick_time = state.now
        state.tick_confident = true
    end
    state.last_energy = state.energy
    state.next_tick_in = estimate_next_tick(state)
    state.projected_energy = math.min(ENERGY_CAP, state.energy + ENERGY_PER_TICK)
end

local function should_wait_for_tick(state, required_energy)
    if (state.energy or 0) >= required_energy then return false end
    if state.next_tick_in > 0.45 then return false end
    return state.energy + ENERGY_PER_TICK >= required_energy
end

local function should_snapshot_upgrade(current_ap, snapshotted_ap, remains, refresh_window, ratio)
    if remains > refresh_window then return false end
    if current_ap <= 0 or snapshotted_ap <= 0 then return false end
    return current_ap > snapshotted_ap * ratio
end

local function build_state(context)
    local state = cat_state
    local settings = context.settings or NS.settings or {}
    state.now = get_now()
    state.me = context.me or (NS.GetPlayer and NS.GetPlayer()) or nil
    state.target = context.target
    state.settings = settings
    state.hp = context.hp or 100
    state.mana_pct = get_mana_pct(context)
    state.energy = get_energy(context)
    state.combo_points = get_combo_points(context, state.target)
    state.enemy_count = context.enemy_count or context.enemies_count or 1
    state.target_hp = context.target_hp or 100
    state.target_ttd = context.ttd or 999
    state.target_range = get_target_range(state.me, state.target, context)
    state.in_combat = context.in_combat == true
    state.is_pvp = context.is_pvp == true
    state.is_player_target = is_target_player(state.target, context)
    state.is_behind = is_behind_target(state.target, context, settings)

    if NS.has_form then
        state.is_cat = NS.has_form("cat")
    else
        state.is_cat = context.stance == STANCE_CAT or context.stance == nil
    end

    state.is_stealthed = buff_up(state.me, PROWL_BUFF)
    state.clearcasting = buff_up(state.me, OMEN_OF_CLARITY_BUFF)
    state.has_tigers_fury = buff_up(state.me, TIGERS_FURY_BUFF)
    state.has_dash = buff_up(state.me, DASH_BUFF)
    state.has_barkskin = buff_up(state.me, BARKSKIN_BUFF)
    state.has_track_humanoids = buff_up(state.me, TRACK_HUMANOIDS_BUFF)
    state.has_wolfshead = buff_up(state.me, WOLFSHEAD_BUFF)

    state.rip_remains = debuff_remains(state.target, RIP_DEBUFF)
    state.rake_remains = debuff_remains(state.target, RAKE_DEBUFF)
    state.faerie_fire_remains = debuff_remains(state.target, FAERIE_FIRE_DEBUFF)
    state.pounce_remains = debuff_remains(state.target, POUNCE_DEBUFF)

    state.attack_power = get_attack_power(context, state.me)
    state.rip_ap = snapshot_state.rip_ap
    state.rake_ap = snapshot_state.rake_ap

    update_energy_tick(state)

    state.pooling = false
    state.should_powershift = false
    state.should_pool_for_rip = false
    state.should_pool_for_shred = false
    state.should_execute = state.target_hp <= EXECUTE_HP
    state.should_tab_rake = false
    state.should_aoe = state.enemy_count >= 3

    return state
end

local function execute_cast(spell, target, label)
    if not spell then return false end
    if not target then return false end
    return NS.try_cast and NS.try_cast(spell, target, "[CAT] " .. label) or false
end

local function action_ready(spell, target, opts)
    if not spell_exists(spell) then return false end
    return NS.spell_ready and NS.spell_ready(spell, target, opts or {}) or false
end

local _strategies = {
    {
        name = "CatForm",
        matches = function(ctx, s)
            if s.is_cat then return false end
            return spell_ready(SPELLS.CatForm, ctx.me or NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function(ctx)
            return execute_cast(SPELLS.CatForm, ctx.me or NS.PLAYER_UNIT, "Cat Form")
        end,
    },
    {
        name = "TravelForm",
        matches = function(ctx, s)
            if ctx.in_combat then return false end
            if s.target_range > 0 and s.target_range < TRAVEL_FORM_RANGE then return false end
            return spell_ready(SPELLS.TravelForm, ctx.me or NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function(ctx)
            return execute_cast(SPELLS.TravelForm, ctx.me or NS.PLAYER_UNIT, "Travel Form")
        end,
    },
    {
        name = "TrackHumanoids",
        matches = function(ctx, s)
            if not s.is_pvp then return false end
            if s.has_track_humanoids then return false end
            return action_ready(TRACK_HUMANOIDS, ctx.me or NS.PLAYER_UNIT)
        end,
        execute = function(ctx)
            return execute_cast(TRACK_HUMANOIDS, ctx.me or NS.PLAYER_UNIT, "Track Humanoids")
        end,
    },
    {
        name = "Prowl",
        matches = function(ctx, s)
            if ctx.in_combat then return false end
            if s.is_stealthed then return false end
            if not s.is_cat then return false end
            return spell_ready(SPELLS.Prowl, ctx.me or NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function(ctx)
            return execute_cast(SPELLS.Prowl, ctx.me or NS.PLAYER_UNIT, "Prowl")
        end,
    },
    {
        name = "Barkskin",
        matches = function(ctx, s)
            local threshold = (s.settings and s.settings.cat_barkskin_hp) or 25
            if (s.hp or 100) > threshold then return false end
            if s.has_barkskin then return false end
            return spell_ready(SPELLS.Barkskin, ctx.me or NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function(ctx)
            return execute_cast(SPELLS.Barkskin, ctx.me or NS.PLAYER_UNIT, "Barkskin defense")
        end,
    },
    {
        name = "PounceOpener",
        matches = function(ctx, s)
            if not s.is_stealthed then return false end
            if not s.is_cat then return false end
            if not ctx.has_valid_enemy_target then return false end
            if s.pounce_remains > 0 then return false end
            return action_ready(POUNCE, s.target)
        end,
        execute = function(ctx)
            return execute_cast(POUNCE, ctx.target, "Pounce opener")
        end,
    },
    {
        name = "RavageOpener",
        matches = function(ctx, s)
            if not s.is_stealthed then return false end
            if not s.is_cat then return false end
            if not ctx.has_valid_enemy_target then return false end
            if s.target_hp > 90 then return false end
            if (s.energy or 0) < RAVAGE_COST then return false end
            return spell_ready(SPELLS.Ravage, s.target)
        end,
        execute = function(ctx)
            return execute_cast(SPELLS.Ravage, ctx.target, "Ravage opener")
        end,
    },
    {
        name = "StealthShred",
        matches = function(ctx, s)
            if not s.is_stealthed then return false end
            if not s.is_cat then return false end
            if not ctx.has_valid_enemy_target then return false end
            if not s.is_behind then return false end
            if (s.energy or 0) < SHRED_COST then return false end
            return spell_ready(SPELLS.Shred, s.target)
        end,
        execute = function(ctx)
            return execute_cast(SPELLS.Shred, ctx.target, "Stealth Shred")
        end,
    },
    {
        name = "Dash",
        matches = function(ctx, s)
            if not s.is_cat then return false end
            if not ctx.has_valid_enemy_target then return false end
            if s.target_range < DASH_RANGE then return false end
            if s.target_range > 40 then return false end
            if s.has_dash then return false end
            return spell_ready(SPELLS.Dash, ctx.me or NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function(ctx)
            return execute_cast(SPELLS.Dash, ctx.me or NS.PLAYER_UNIT, "Dash")
        end,
    },
    {
        name = "FaerieFireStealthLock",
        matches = function(ctx, s)
            if not s.is_stealthed then return false end
            if not ctx.has_valid_enemy_target then return false end
            if s.faerie_fire_remains > FAERIE_FIRE_REFRESH then return false end
            return spell_ready(SPELLS.FaerieFireFeral, s.target)
        end,
        execute = function(ctx)
            return execute_cast(SPELLS.FaerieFireFeral, ctx.target, "Faerie Fire Feral (stealth)")
        end,
    },
    {
        name = "FaerieFireFeral",
        matches = function(ctx, s)
            if not s.is_cat then return false end
            if not ctx.has_valid_enemy_target then return false end
            if s.faerie_fire_remains > FAERIE_FIRE_REFRESH then return false end
            return spell_ready(SPELLS.FaerieFireFeral, s.target)
        end,
        execute = function(ctx)
            return execute_cast(SPELLS.FaerieFireFeral, ctx.target, "Faerie Fire Feral")
        end,
    },
    {
        name = "RipSnapshot",
        matches = function(ctx, s)
            if not s.is_cat then return false end
            if not ctx.has_valid_enemy_target then return false end
            if s.combo_points < 1 then return false end
            if s.target_ttd < MIN_RIP_TTD then return false end
            if s.rip_remains > RIP_REFRESH_WINDOW then return false end
            if not s.is_behind then return false end
            if not should_snapshot_upgrade(s.attack_power, snapshot_state.rip_ap, s.rip_remains, RIP_REFRESH_WINDOW, AP_UPGRADE_RATIO) then return false end
            return action_ready(SPELLS.Rip, s.target)
        end,
        execute = function(ctx)
            snapshot_state.rip_ap = ctx.attack_power or 0
            snapshot_state.rip_target = ctx.target
            return execute_cast(SPELLS.Rip, ctx.target, "Rip (snapshot upgrade)")
        end,
    },
    {
        name = "FerociousBiteExecute",
        matches = function(ctx, s)
            if not s.is_cat then return false end
            if not ctx.has_valid_enemy_target then return false end
            if s.target_hp > EXECUTE_HP then return false end
            if s.combo_points < 1 then return false end
            if not s.should_execute then return false end
            if (s.energy or 0) < BITE_COST then return false end
            return action_ready(SPELLS.FerociousBite, s.target)
        end,
        execute = function(ctx)
            return execute_cast(SPELLS.FerociousBite, ctx.target, "Ferocious Bite (execute)")
        end,
    },
    {
        name = "TigersFury",
        matches = function(ctx, s)
            if not s.is_cat then return false end
            if s.has_tigers_fury then return false end
            if (s.energy or 0) < TIGERS_FURY_ENERGY then return false end
            return spell_ready(SPELLS.TigersFury, ctx.me or NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function(ctx)
            return execute_cast(SPELLS.TigersFury, ctx.me or NS.PLAYER_UNIT, "Tiger's Fury")
        end,
    },
    {
        name = "Powershift",
        matches = function(ctx, s)
            if not s.is_cat then return false end
            if not s.should_powershift then return false end
            if s.clearcasting then return false end
            if (s.mana_pct or 100) < POWERSHIFT_MIN_MANA then return false end
            if s.combo_points >= POWERSHIFT_SAFE_CP then return false end
            local now = get_now()
            if (now - s.last_shift_time) < POWERSHIFT_IGNORE_WINDOW then return false end
            return spell_ready(SPELLS.CatForm, ctx.me or NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function(ctx)
            cat_state.last_shift_time = get_now()
            return execute_cast(SPELLS.CatForm, ctx.me or NS.PLAYER_UNIT, "Powershift")
        end,
    },
    {
        name = "RakeSnapshot",
        matches = function(ctx, s)
            if not s.is_cat then return false end
            if not ctx.has_valid_enemy_target then return false end
            if s.target_ttd < MIN_RAKE_TTD then return false end
            if s.rake_remains > RAKE_REFRESH_WINDOW then return false end
            if not s.is_behind then return false end
            if not should_snapshot_upgrade(s.attack_power, snapshot_state.rake_ap, s.rake_remains, RAKE_REFRESH_WINDOW, STRONG_AP_UPGRADE_RATIO) then return false end
            return action_ready(SPELLS.Rake, s.target)
        end,
        execute = function(ctx)
            snapshot_state.rake_ap = ctx.attack_power or 0
            snapshot_state.rake_target = ctx.target
            return execute_cast(SPELLS.Rake, ctx.target, "Rake (snapshot upgrade)")
        end,
    },
    {
        name = "ShredOmen",
        matches = function(ctx, s)
            if not s.is_cat then return false end
            if not ctx.has_valid_enemy_target then return false end
            if not s.clearcasting then return false end
            if not s.is_behind then return false end
            return action_ready(SPELLS.Shred, s.target)
        end,
        execute = function(ctx)
            return execute_cast(SPELLS.Shred, ctx.target, "Shred (Omen)")
        end,
    },
    {
        name = "Rake",
        matches = function(ctx, s)
            if not s.is_cat then return false end
            if not ctx.has_valid_enemy_target then return false end
            if s.target_ttd < MIN_RAKE_TTD then return false end
            if s.rake_remains > RAKE_REFRESH_WINDOW then return false end
            if not s.is_behind then return false end
            if (s.energy or 0) < RAKE_COST then return false end
            return action_ready(SPELLS.Rake, s.target)
        end,
        execute = function(ctx)
            return execute_cast(SPELLS.Rake, ctx.target, "Rake")
        end,
    },
    {
        name = "Shred",
        matches = function(ctx, s)
            if not s.is_cat then return false end
            if not ctx.has_valid_enemy_target then return false end
            if not s.is_behind then return false end
            if (s.energy or 0) < SHRED_COST then return false end
            return action_ready(SPELLS.Shred, s.target)
        end,
        execute = function(ctx)
            return execute_cast(SPELLS.Shred, ctx.target, "Shred")
        end,
    },
    {
        name = "ClawFallback",
        matches = function(ctx, s)
            if not s.is_cat then return false end
            if not ctx.has_valid_enemy_target then return false end
            if (s.energy or 0) < 40 then return false end
            return spell_ready(SPELLS.Claw, s.target)
        end,
        execute = function(ctx)
            return execute_cast(SPELLS.Claw, ctx.target, "Claw (fallback)")
        end,
    },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("cat", _strategies, { get_state = build_state })
end
if NS.log then NS.log("Druid cat_vanilla rotation registered (Classic Vanilla)") end
return { strategies = _strategies, build_state = build_state }
