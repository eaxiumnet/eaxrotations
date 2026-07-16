-- bear_vanilla.lua — Druid Bear (feral tank) rotation for Vanilla/Classic Era.
-- WHAT:  tank rotation (Maul, Swipe, Bash, demo roar, defensive CDs).
-- WHEN:  combat, in bear form, when NS.is_vanilla() is true.
-- WHY:   expansion-aware loader selects _vanilla suffix for Classic Era.
-- SAFETY: nil-guards on NS, SPELLS, and TBC data fallback.

local NS = _G.EaxRotations
if not NS then return nil end
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { ITEMS = { healthstones = {}, potions = {} } } end
local TBC_ITEMS = TBC.ITEMS or {}
local TBC_POTIONS = TBC_ITEMS.potions or {}
local spec_kit = require("shared/spec_kit_sylvanas")
local leveling_helpers = require("shared/leveling_helpers_sylvanas")

local BASE_SPELLS = NS.DruidSpells or {}
local SPELLS = BASE_SPELLS

local BASH = BASE_SPELLS.Bash or (NS.spell_action and NS.spell_action({ 8983, 6798, 5211 }, "Bash"))
local ENRAGE = BASE_SPELLS.Enrage or (NS.spell_action and NS.spell_action({ 5229 }, "Enrage"))
local MARK_OF_THE_WILD = BASE_SPELLS.MarkOfTheWild or (NS.spell_action and NS.spell_action({ 9885, 9884, 8907, 6756, 5234, 5232, 1126 }, "MarkOfTheWild"))
local GIFT_OF_THE_WILD = BASE_SPELLS.GiftOfTheWild or (NS.spell_action and NS.spell_action({ 21850, 21849 }, "GiftOfTheWild"))
local THORNS = BASE_SPELLS.Thorns or (NS.spell_action and NS.spell_action({ 9910, 9756, 8914, 1075, 782, 467 }, "Thorns"))
local STANCE_BEAR = 1
local STANCE_CASTER = 0
local RAGE_CAP = 100
local RAGE_LOW = 15
local RAGE_SWIPE = 20
local RAGE_MAUL = 15
local RAGE_DEMO_ROAR = 10
local RAGE_FRENZIED_REGEN = 10
local RAGE_CHALLENGING_ROAR = 5
local RAGE_POOL_PULL = 20
local DEMO_ROAR_REFRESH = 5
local THORNS_REFRESH = 30
local MOTW_REFRESH = 120
local MELEE_RANGE = 5
local CHARGE_MIN_RANGE = 8
local CHARGE_MAX_RANGE = 25
local AOE_SCAN_RANGE = 8
local PACK_SCAN_RANGE = 10
local SCAN_INTERVAL = 0.5
local TAUNT_COOLDOWN_WINDOW = 8
local CHALLENGING_ROAR_ENEMY_COUNT = 3
local OOC_ENRAGE_RAGE_MAX = 20
local HIGH_RAGE = 75

local FAERIE_FIRE_DEBUFF = { 17392, 17391, 17390, 16857,  9907, 9749, 778, 770 }
local DEMO_ROAR_DEBUFF = { 9898, 9747, 9490, 1735, 99, 11556, 6190, 1160 }
local MARK_BUFF = { 9885, 9884, 8907, 6756, 5234, 5232, 1126, 21850, 21849 }
local THORNS_BUFF = { 9910, 9756, 8914, 1075, 782, 467 }
local CLEARCASTING_BUFF = { 16870 }
local BARKSKIN_BUFF = { 22812 }
local FRENZIED_REGEN_BUFF = { 22842 }

local HEALTHSTONE_IDS = TBC_ITEMS.healthstones or { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }
local HEALING_POTION_IDS = {
    TBC_POTIONS.major_healing or 13446,
    TBC_POTIONS.greater_healing or 1710,
    TBC_POTIONS.healing or 929,
    TBC_POTIONS.lesser_healing or 858,
}

local bear_state = {
    now = 0,
    me = nil,
    target = nil,
    settings = nil,
    hp = 100,
    rage = 0,
    rage_deficit = 100,
    stance = STANCE_CASTER,
    in_combat = false,
    combat_time = 0,
    target_hp = 100,
    target_ttd = 999,
    target_range = 40,
    in_melee = false,
    enemy_count = 1,
    aoe_threshold = 3,
    maul_rage = 50,
    barkskin_hp = 55,
    frenzied_regen_hp = 35,
    demo_roar_enabled = true,

    should_burst = false,
    has_valid_target = false,
    is_bear = false,
    is_target_boss = false,
    is_target_player = false,
    target_is_casting = false,
    target_interruptible = true,
    target_target_is_me = false,
    target_target_exists = false,
    target_target_is_player = false,
    target_target_is_tank = false,
    target_target_is_healer = false,
    has_clearcasting = false,
    has_barkskin = false,
    has_frenzied_regen = false,
    has_mark = false,
    has_thorns = false,
    faerie_remains = 0,
    demo_remains = 0,
    swipe_ready = false,
    maul_ready = false,
    growl_ready = false,
    challenging_ready = false,
    barkskin_ready = false,
    frenzied_ready = false,
    bash_ready = false,
    faerie_ready = false,
    demo_ready = false,
    enrage_ready = false,
    group_pressure = false,
    heavy_damage = false,
    emergency_damage = false,
    loose_target = false,
    off_target = nil,
    off_target_threat_low = false,
    pack_needs_demo = false,
    pack_elites = 0,
    pack_loose = 0,
    pack_secure = 0,
    healthstone_ready = 0,
    potion_ready = 0,
    recent_taunt = 0,
    last_rage = 0,
    last_rage_time = 0,
    rage_delta = 0,
    rage_per_second = 1,
    last_scan_time = 1,
}

local off_target_buffer = { n = 0 }



local function spell_exists(spell)
    if not spell then return false end
    if NS.spell_exists then return NS.spell_exists(spell) end
    return true
end

local function spell_ready(spell, target, expected_cooldown)
    if not spell_exists(spell) then return false end
    if NS.spell_ready then
        if expected_cooldown then
            return NS.spell_ready(spell, target, { expected_cooldown = expected_cooldown })
        end
        return NS.spell_ready(spell, target)
    end
    return true
end



local function safe_method(unit, method, fallback)
    if not unit then return fallback end
    local fn = NS.safe_field and NS.safe_field(unit, method) or unit[method]
    if type(fn) ~= "function" then return fallback end
    local ok, result = pcall(fn, unit)
    if not ok or result == nil then return fallback end
    return result
end

local function safe_method_arg(unit, method, arg, fallback)
    if not unit then return fallback end
    local fn = NS.safe_field and NS.safe_field(unit, method) or unit[method]
    if type(fn) ~= "function" then return fallback end
    local ok, result = pcall(fn, unit, arg)
    if not ok or result == nil then return fallback end
    return result
end

local function same_unit(left, right)
    if not left or not right then return false end
    if NS.same_unit then return NS.same_unit(left, right) end
    return left == right
end

local function unit_distance(unit, other)
    if NS.unit_distance then return NS.unit_distance(unit, other) end
    return 999
end

local function is_hostile(unit, me)
    if not unit or not me then return false end
    if NS.is_hostile_unit then return NS.is_hostile_unit(me, unit) end
    return unit == bear_state.target
end

local function is_alive(unit)
    if not unit then return false end
    if NS.unit_alive then return NS.unit_alive(unit) end
    return true
end

local function get_target_of(unit)
    if not unit then return nil end
    return safe_method(unit, "get_target", nil)
end

local function is_tank(unit)
    local role = safe_method(unit, "get_group_role", nil)
    return role == 0 or role == "tank" or role == "TANK"
end

local function is_healer(unit)
    local role = safe_method(unit, "get_group_role", nil)
    return role == 1 or role == "healer" or role == "HEALER"
end

local function unit_is_player(unit)
    return safe_method(unit, "is_player", false) == true
end

local function target_is_casting(unit)
    if not unit then return false end
    if safe_method(unit, "is_casting", false) == true then return true end
    return safe_method(unit, "is_channeling", false) == true
end

local function target_cast_interruptible(unit)
    local value = safe_method(unit, "is_interruptible", nil)
    if value ~= nil then return value == true end
    value = safe_method(unit, "is_cast_interruptible", nil)
    if value ~= nil then return value == true end
    return true
end

local function first_ready_item(item_ids)
    if not NS.is_item_ready then return 0 end
    for i = 1, #item_ids do
        local item_id = item_ids[i]
        if NS.is_item_ready(item_id) then return item_id end
    end
    return 0
end

local function clear_off_targets()
    for i = 1, off_target_buffer.n do off_target_buffer[i] = nil end
    off_target_buffer.n = 0
end

local function append_off_target(unit)
    if not unit or off_target_buffer.n >= 12 then return end
    off_target_buffer.n = off_target_buffer.n + 1
    off_target_buffer[off_target_buffer.n] = unit
end

local function scan_pack(state)
    clear_off_targets()
    state.pack_elites = 0
    state.pack_loose = 0
    state.pack_secure = 0
    state.off_target = nil
    state.off_target_threat_low = false
    state.pack_needs_demo = false

    if not NS.get_visible_units or not state.me then return end
    local units, count = NS.get_visible_units(false, 50)
    if type(units) ~= "table" or not count then return end

    local best_score = -1
    for i = 1, count do
        local unit = units[i]
        if unit and not same_unit(unit, state.me) and is_alive(unit) and is_hostile(unit, state.me) then
            local distance = unit_distance(unit, state.me)
            if distance <= PACK_SCAN_RANGE then
                append_off_target(unit)
                local unit_target = get_target_of(unit)
                local targets_me = same_unit(unit_target, state.me)
                local elite = safe_method(unit, "is_elite", false) == true or safe_method(unit, "is_boss", false) == true
                local demo_remains = NS.debuff_remains(unit, DEMO_ROAR_DEBUFF) or 0
                local score = 0

                if elite then state.pack_elites = state.pack_elites + 1 end
                if targets_me then
                    state.pack_secure = state.pack_secure + 1
                else
                    state.pack_loose = state.pack_loose + 1
                    score = score + 50
                end
                if demo_remains <= DEMO_ROAR_REFRESH then state.pack_needs_demo = true end
                if elite then score = score + 10 end
                if distance <= AOE_SCAN_RANGE then score = score + 5 end

                if unit ~= state.target and score > best_score then
                    best_score = score
                    state.off_target = unit
                    state.off_target_threat_low = not targets_me
                end
            end
        end
    end
end

local function lazy_scan_pack(state)
    if not state.now then return end
    if state.now - (state.last_scan_time or 0) >= SCAN_INTERVAL then
        scan_pack(state)
        state.last_scan_time = state.now
    end
end

local function update_rage_tracking(state)
    local now = state.now
    local elapsed = now - (state.last_rage_time or 0)
    state.rage_delta = (state.rage or 0) - (state.last_rage or state.rage or 0)
    if elapsed > 0 and elapsed < 5 then
        state.rage_per_second = state.rage_delta / elapsed
    else
        state.rage_per_second = 0
    end
    state.last_rage = state.rage
    state.last_rage_time = now
    state.rage_deficit = RAGE_CAP - (state.rage or 0)
end

-- Throttle build_state to once per frame to avoid rebuilding state N times
-- per frame (once per strategy match function). Uses context.now when
-- available (real game); falls back to no caching in test environments.
local _last_build_state_time = -1

local function build_state(context)
    local state = bear_state
    local now = context.now
    if now and now == _last_build_state_time then return state end
    now = now or (NS.time_now and NS.time_now() or 0)
    if context.now then _last_build_state_time = now end
    state.now = now
    state.me = context.me or (NS.GetPlayer and NS.GetPlayer()) or nil
    state.target = context.target
    state.hp = context.hp or 100
    state.level = context.level or context.player_level or 60
    state.rage = context.rage or 0
    state.stance = context.stance or (NS.get_player_stance and NS.get_player_stance()) or STANCE_CASTER
    state.in_combat = context.in_combat == true
    state.combat_time = context.combat_time or 0
    state.target_hp = context.target_hp or 100
    state.target_ttd = context.ttd or 999
    state.target_range = context.target_range or context.target_distance or 40
    state.in_melee = context.in_melee_range == true or state.target_range <= MELEE_RANGE
    state.enemy_count = context.enemy_count or context.enemies_count or 1
    state.aoe_threshold = spec_kit.setting_number(context, "bear_aoe_threshold", spec_kit.setting_number(context, "aoe_threshold", 3))
    state.maul_rage = spec_kit.setting_number(context, "bear_maul_rage", 40)
    state.barkskin_hp = spec_kit.setting_number(context, "bear_barkskin_hp", 55)
    state.frenzied_regen_hp = spec_kit.setting_number(context, "bear_frenzied_regen_hp", 35)
    state.demo_roar_enabled = spec_kit.setting_bool(context, "bear_demo_roar", true)
    state.should_burst = context.should_burst == true
    state.has_valid_target = context.has_valid_enemy_target ~= false and state.target ~= nil
    if NS.has_form then
        state.is_bear = NS.has_form("bear")
    else
        state.is_bear = state.stance == STANCE_BEAR or context.stance == nil
    end
    state.is_target_boss = context.target_is_boss == true or safe_method(state.target, "is_boss", false) == true
    state.is_target_player = context.target_is_player == true or unit_is_player(state.target)
    state.target_is_casting = target_is_casting(state.target)
    state.target_interruptible = target_cast_interruptible(state.target)

    local target_target = get_target_of(state.target)
    state.target_target_exists = target_target ~= nil
    state.target_target_is_me = same_unit(target_target, state.me)
    state.target_target_is_player = unit_is_player(target_target)
    state.target_target_is_tank = is_tank(target_target)
    state.target_target_is_healer = is_healer(target_target)

    local skip_aura = NS.broken_api_throttled and NS.broken_api_throttled(22812, 3.0) or false
    if not skip_aura then
        state.has_clearcasting = NS.buff_up(state.me, CLEARCASTING_BUFF) or false
        state.has_barkskin = NS.buff_up(state.me, BARKSKIN_BUFF) or false
        state.has_frenzied_regen = NS.buff_up(state.me, FRENZIED_REGEN_BUFF) or false
        state.has_mark = NS.buff_up(state.me, MARK_BUFF) or false
        state.has_thorns = (NS.buff_remains(state.me, THORNS_BUFF) or 0) > THORNS_REFRESH
        state.faerie_remains = NS.debuff_remains(state.target, FAERIE_FIRE_DEBUFF) or 0
        state.demo_remains = NS.debuff_remains(state.target, DEMO_ROAR_DEBUFF) or 0
    end

    state.swipe_ready = spell_ready(SPELLS.SwipeBear, state.me)
    state.maul_ready = spell_ready(SPELLS.Maul, state.target)
    state.growl_ready = spell_ready(SPELLS.Growl, state.target)
    state.challenging_ready = spell_ready(SPELLS.ChallengingRoar, state.me)
    state.barkskin_ready = spell_ready(SPELLS.Barkskin, state.me)
    state.frenzied_ready = spell_ready(SPELLS.FrenziedRegeneration, state.me)
    state.bash_ready = spell_ready(BASH, state.target)
    state.faerie_ready = spell_ready(SPELLS.FaerieFireFeral, state.target)
    state.demo_ready = spell_ready(SPELLS.DemoralizingRoar, state.me)
    state.enrage_ready = spell_ready(ENRAGE, state.me)
    state.loose_target = state.has_valid_target and state.target_target_exists and not state.target_target_is_me
    state.healthstone_ready = first_ready_item(HEALTHSTONE_IDS)
    state.potion_ready = first_ready_item(HEALING_POTION_IDS)

    scan_pack(state)
    state.group_pressure = (state.enemy_count or 1) >= (state.aoe_threshold or 3) or (state.pack_loose or 0) > 0
    state.heavy_damage = (state.hp or 100) <= (state.frenzied_regen_hp or 35) or ((state.hp or 100) <= (state.barkskin_hp or 55) and ((state.enemy_count or 1) >= 2 or (state.pack_elites or 0) > 0))
    state.emergency_damage = (state.hp or 100) <= 30 and (state.pack_loose or 0) > 0

    update_rage_tracking(state)
    return state
end

local function action_ready(context, action)
    if not action then return false end
    if not action.spell then return true end
    local target = (action.target == "self" or action.requires_target == false) and (context.me or NS.GetPlayer()) or context.target
    if not target then return false end
    local opts = {}
    if action.requires_target == false then opts.skip_range = true end
    if action.cooldown then opts.expected_cooldown = action.cooldown end
    return NS.spell_ready(action.spell, target, opts)
end

local function execute_action(context, action)
    if not action or not action.spell then return false end
    local target = (action.target == "self" or action.requires_target == false) and (context.me or NS.GetPlayer()) or context.target
    if not target then return false end
    local opts = {}
    if action.requires_target == false then opts.skip_range = true end
    if action.cooldown then opts.expected_cooldown = action.cooldown end
    return NS.try_cast(action.spell, target, "[BEAR]", opts)
end

local function execute_item(context, item_id, label)
    if item_id <= 0 or not NS.use_item_by_id then return false end
    return NS.use_item_by_id(item_id, context.me) and true or false
end

local function can_use_bear_ability(state)
    if not state.is_bear then return false end
    if state.has_valid_target then return true end
    return NS.has_form == nil and NS.spell_ready == nil
end

local function bear_form_matches(context, action)
    local state = build_state(context)
    if state.is_bear then return false end
    return action_ready(context, action)
end

local function mark_matches(context, action)
    local state = build_state(context)
    if state.in_combat then return false end
    if state.is_bear then return false end  -- MotW cancels bear form
    if (NS.buff_remains(state.me, MARK_BUFF) or 0) > MOTW_REFRESH then return false end
    return action_ready(context, action)
end

local function thorns_matches(context, action)
    local state = build_state(context)
    if state.in_combat then return false end
    if state.is_bear then return false end  -- Thorns cancels bear form
    if (NS.buff_remains(state.me, THORNS_BUFF) or 0) > THORNS_REFRESH then return false end
    return action_ready(context, action)
end

local function pre_pull_enrage_matches(context, action)
    local state = build_state(context)
    if not state.is_bear or state.in_combat then return false end
    if (state.rage or 0) >= RAGE_POOL_PULL then return false end
    if (state.rage or 0) > OOC_ENRAGE_RAGE_MAX then return false end
    return action_ready(context, action)
end

local function faerie_fire_pull_matches(context, action)
    local state = build_state(context)
    if not state.is_bear or not state.has_valid_target then return false end
    if (context.target_armor or 0) <= 0 and not leveling_helpers.is_low_level(state.level) then return false end
    if state.in_melee then return false end
    if (state.target_range or 40) > 30 then return false end
    if (state.faerie_remains or 0) > 4 then return false end
    return action_ready(context, action)
end

local function healthstone_matches(context)
    local state = build_state(context)
    if not state.in_combat then return false end
    if (state.hp or 100) > 28 then return false end
    return (state.healthstone_ready or 0) > 0
end

local function potion_matches(context)
    local state = build_state(context)
    if not state.in_combat then return false end
    if (state.healthstone_ready or 0) > 0 and (state.hp or 100) <= 28 then return false end
    if (state.hp or 100) > 32 then return false end
    return (state.potion_ready or 0) > 0
end

local function frenzied_regen_matches(context, action)
    local state = build_state(context)
    if not state.is_bear or not state.in_combat then return false end
    if state.has_frenzied_regen then return false end
    if (state.rage or 0) < RAGE_FRENZIED_REGEN then return false end
    if (state.hp or 100) > state.frenzied_regen_hp then return false end
    return action_ready(context, action)
end

local function barkskin_matches(context, action)
    local state = build_state(context)
    if not state.in_combat then return false end
    if state.has_barkskin then return false end
    if (state.hp or 100) > state.barkskin_hp then return false end
    if (state.hp or 100) <= 15 then return false end
    return action_ready(context, action)
end

local function challenging_roar_matches(context, action)
    local state = build_state(context)
    if not state.is_bear or not state.in_combat then return false end
    if (state.enemy_count or 0) < CHALLENGING_ROAR_ENEMY_COUNT and (state.pack_loose or 0) < 2 then return false end
    if (state.pack_loose or 0) < 2 and (state.hp or 100) < 45 then return false end
    return action_ready(context, action)
end

local function growl_matches(context, action)
    local state = build_state(context)
    if not can_use_bear_ability(state) then return false end
    if not state.loose_target then return false end
    if state.target_target_is_tank then return false end
    if state.target_target_is_player or state.target_target_is_healer then
        if (state.now or 0) - (state.recent_taunt or 0) < TAUNT_COOLDOWN_WINDOW then return false end
        return action_ready(context, action)
    end
    return false
end

local function bash_interrupt_matches(context, action)
    local state = build_state(context)
    if not can_use_bear_ability(state) then return false end
    if not state.target_is_casting or not state.target_interruptible then return false end
    if not state.in_melee then return false end
    return action_ready(context, action)
end

local function faerie_fire_matches(context, action)
    local state = build_state(context)
    if not state.target then return false end
    if not can_use_bear_ability(state) then return false end
    if (context.target_armor or 0) <= 0 and not leveling_helpers.is_low_level(state.level) then return false end
    if (state.faerie_remains or 0) > 4 then return false end
    return action_ready(context, action)
end

local function demo_roar_matches(context, action)
    local state = build_state(context)
    if not state.is_bear or not state.in_combat or not state.demo_roar_enabled then return false end
    if (state.enemy_count or 0) <= 0 then return false end
    if (state.demo_remains or 0) > DEMO_ROAR_REFRESH and not state.pack_needs_demo then return false end
    if (state.enemy_count or 0) < 2 and not state.is_target_boss and (state.target_ttd or 999) < 10 then return false end
    return action_ready(context, action)
end

local function swipe_aoe_matches(context, action)
    local state = build_state(context)
    if not state.is_bear then return false end
    if not state.in_combat and NS.spell_ready then return false end
    if (state.enemy_count or 0) < (state.aoe_threshold or 3) then return false end
    if context.has_breakable_cc_nearby then return false end
    if (state.rage or 0) < RAGE_SWIPE then return false end
    return action_ready(context, action)
end

local function swipe_cleave_matches(context, action)
    local state = build_state(context)
    if not state.is_bear then return false end
    if not state.in_combat and NS.spell_ready then return false end
    if (state.enemy_count or 0) < 2 then return false end
    if context.has_breakable_cc_nearby then return false end
    if (state.rage or 0) < RAGE_SWIPE then return false end
    return action_ready(context, action)
end

local function maul_matches(context, action)
    local state = build_state(context)
    if not can_use_bear_ability(state) then return false end
    if (state.enemy_count or 0) >= (state.aoe_threshold or 3) and (state.rage or 0) < HIGH_RAGE then return false end
    if (state.rage or 0) < (state.maul_rage or 40) then return false end
    return action_ready(context, action)
end

local function enrage_combat_matches(context, action)
    local state = build_state(context)
    if not state.is_bear or not state.in_combat then return false end
    if (state.rage or 0) > RAGE_LOW then return false end
    if (state.hp or 100) < 60 and (state.enemy_count or 0) >= 2 then return false end
    return action_ready(context, action)
end

local function taunt_execute(context, action)
    local ok = execute_action(context, action)
    if ok then bear_state.recent_taunt = bear_state.now end
    return ok
end

local ACTIONS = {
    { name = "MarkOfTheWild", spell = MARK_OF_THE_WILD, target = "self", kind = "buff", buff = MARK_BUFF, ooc = true, requires_target = false, matches = mark_matches },
    { name = "GiftOfTheWild", spell = GIFT_OF_THE_WILD, target = "self", kind = "buff", buff = MARK_BUFF, ooc = true, requires_target = false, matches = mark_matches },
    { name = "Thorns", spell = THORNS, target = "self", kind = "buff", buff = THORNS_BUFF, ooc = true, requires_target = false, matches = thorns_matches },
    { name = "BearForm", spell = SPELLS.BearForm, target = "self", kind = "form", form = "bear", requires_target = false, matches = bear_form_matches },
    { name = "PrePullEnrage", spell = ENRAGE, target = "self", required_form = "bear", ooc = true, requires_target = false, matches = pre_pull_enrage_matches },
    { name = "FaerieFirePull", spell = SPELLS.FaerieFireFeral, required_form = "bear", debuff = FAERIE_FIRE_DEBUFF, refresh = 4, matches = faerie_fire_pull_matches },

    { name = "Healthstone", target = "self", requires_target = false, matches = healthstone_matches, execute = function(context) return execute_item(context, build_state(context).healthstone_ready, "Healthstone") end },
    { name = "HealingPotion", target = "self", requires_target = false, matches = potion_matches, execute = function(context) return execute_item(context, build_state(context).potion_ready, "Healing Potion") end },
    { name = "FrenziedRegeneration", spell = SPELLS.FrenziedRegeneration, target = "self", required_form = "bear", min_rage = RAGE_FRENZIED_REGEN, requires_target = false, matches = frenzied_regen_matches },
    { name = "Barkskin", spell = SPELLS.Barkskin, target = "self", requires_target = false, matches = barkskin_matches },

    { name = "ChallengingRoar", spell = SPELLS.ChallengingRoar, target = "self", required_form = "bear", min_rage = RAGE_CHALLENGING_ROAR, requires_target = false, matches = challenging_roar_matches, execute = taunt_execute },
    { name = "Growl", spell = SPELLS.Growl, required_form = "bear", matches = growl_matches, execute = taunt_execute },
    { name = "BashInterrupt", spell = BASH, required_form = "bear", min_rage = 10, matches = bash_interrupt_matches },

    { name = "FaerieFireFeral", spell = SPELLS.FaerieFireFeral, required_form = "bear", debuff = FAERIE_FIRE_DEBUFF, refresh = 4, matches = faerie_fire_matches },
    { name = "DemoralizingRoar", spell = SPELLS.DemoralizingRoar, target = "self", required_form = "bear", min_rage = RAGE_DEMO_ROAR, cooldown = 25, requires_target = false, matches = demo_roar_matches },
    -- Swipe requires a hostile melee target (not self) — self-cast spam-loops.
    { name = "SwipeAoE", spell = SPELLS.SwipeBear, required_form = "bear", min_rage = RAGE_SWIPE, is_aoe = true, enemy_count = 3, matches = swipe_aoe_matches },
    { name = "Swipe", spell = SPELLS.SwipeBear, required_form = "bear", min_rage = RAGE_SWIPE, is_aoe = true, enemy_count = 2, matches = swipe_cleave_matches },
    { name = "Maul", spell = SPELLS.Maul, required_form = "bear", min_rage = RAGE_MAUL, matches = maul_matches },
    { name = "EnrageCombat", spell = ENRAGE, target = "self", required_form = "bear", requires_target = false, matches = enrage_combat_matches },
    -- FerociousBiteExecute REMOVED: Ferocious Bite is a cat-form ability requiring combo
    -- points. A bear tank has no combo points and cannot cast it. Vanilla bear uses
    -- Maul > Swipe > Demo Roar per guide (no Mangle, no Lacerate in Classic).
}

local strategies = {}

for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    strategies[#strategies + 1] = {
        name = action.name,
        matches = function(context)
            if action.matches then return action.matches(context, action) end
            return action_ready(context, action)
        end,
        execute = function(context)
            if action.execute then return action.execute(context, action) end
            return execute_action(context, action)
        end,
    }
end

NS.rotation_registry:register("bear", strategies, { get_state = build_state })
-- Druid bear_vanilla rotation registered (Classic Vanilla)
return strategies
