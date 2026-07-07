-- bear_sylvanas.lua — Druid Bear (Feral tank) rotation for TBC Anniversary (2.5.5).
-- WHAT:  pure bear-form tank rotation — NO in-combat form shifting. Maintains
--         Demoralizing Roar + Faerie Fire (Feral) debuffs, Mangle on cooldown,
--         Lacerate stacked to 5, Swipe for AoE/cleave, Maul as rage dump.
--         Defensives (Frenzied Regen, Barkskin, consumables) + taunts layered in.
-- WHEN:  bear form, in combat, with a valid enemy target.
-- WHY:   mirrors wowsims/tbc tank APL (sim/druid/tank/rotation.go) + TBC community
--         consensus (Icy Veins, Warcraft Tavern, Wowhead). GCD priority:
--           defensives -> taunts -> Demo Roar -> Faerie Fire ->
--           Mangle -> Lacerate (stack/refresh) -> Swipe (AoE) -> Maul (rage dump)
-- SAFETY: Pattern 14 eliminated via spec_kit.safe_state(); no manual nil-guards; no on_update allocs;
--          no caster/cat-form spells in combat (no form shifting); menu refs nil-guarded.
-- DECISION: stripped Ferocious Bite (cat form), RemoveCurse + Nature's Grasp
--           (caster form), all PvP branches, Clearcasting variants, off-target
--           pack scanning, and the "wait for Mangle" pool strategy. The bear stays
--           bear — OOC buffs (Mark/Thorns) are pre-pull caster prep only.

local NS = _G.EaxRotations
if not NS then return nil end

-- Optional TBC item data for healthstone / potion IDs (nil-safe fallback)
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { ITEMS = { healthstones = {}, potions = {} } } end
local TBC_ITEMS   = TBC.ITEMS or {}
local TBC_POTIONS = TBC_ITEMS.potions or {}

local SPELLS = NS.DruidSpells or {}
local spec_kit = require("shared/spec_kit_sylvanas")

-- Centralized spell resolver via spec_kit (replaces per-spec spell() helper +
-- FERAL_CHARGE/BASH/ENRAGE/MARK/GIFT/THORNS local spell variables).
-- Rank IDs from class_sylvanas.lua (verified against DBC for TBC Anniversary 2.5.5).
local define = spec_kit.define_action_for_class(SPELLS)
local ACTION = {
    Barkskin            = define("Barkskin",            { 22812 }, "Barkskin"),
    Bash                = define("Bash",                { 8983, 6798, 5211 }, "Bash"),
    BearForm            = define("BearForm",            { 9634, 5487 }, "BearForm"),
    ChallengingRoar     = define("ChallengingRoar",     { 5209 }, "ChallengingRoar"),
    DemoralizingRoar    = define("DemoralizingRoar",    { 26998, 9898, 9747, 9490, 1735, 99 }, "DemoralizingRoar"),
    Enrage              = define("Enrage",              { 5229 }, "Enrage"),
    FaerieFireFeral     = define("FaerieFireFeral",     { 27011, 17392, 17391, 17390, 16857 }, "FaerieFireFeral"),
    FeralCharge         = define("FeralCharge",         { 16979 }, "FeralCharge"),
    FrenziedRegeneration= define("FrenziedRegeneration",{ 26999, 22896, 22895, 22842 }, "FrenziedRegeneration"),
    GiftOfTheWild       = define("GiftOfTheWild",       { 26991, 21850, 21849 }, "GiftOfTheWild"),
    Growl               = define("Growl",               { 6795 }, "Growl"),
    Lacerate            = define("Lacerate",            { 33745 }, "Lacerate"),
    MangleBear          = define("MangleBear",          { 33987, 33986, 33878 }, "MangleBear"),
    MarkOfTheWild       = define("MarkOfTheWild",       { 26990, 9885, 9884, 8907, 6756, 5234, 5232, 1126 }, "MarkOfTheWild"),
    Maul                = define("Maul",                { 26996, 9881, 9880, 9745, 8972, 6809, 6808, 6807 }, "Maul"),
    SwipeBear           = define("SwipeBear",           { 26997, 9908, 9754, 769, 780, 779 }, "SwipeBear"),
    Thorns              = define("Thorns",              { 26992, 9910, 9756, 8914, 1075, 782, 467 }, "Thorns"),
}

-------------------------------------------------------------------------------
-- CONSTANTS  (rage costs, refresh windows, ranges — from DBC + wowsims APL)
-------------------------------------------------------------------------------
local STANCE_BEAR          = 1
local STANCE_CASTER        = 0

-- Rage costs (TBC Anniversary 2.5.5 — verified against class_sylvanas.lua spell data)
local RAGE_MANGLE          = 15
local RAGE_LACERATE        = 15
local RAGE_SWIPE           = 15
local RAGE_MAUL            = 15
local RAGE_DEMO_ROAR       = 10
local RAGE_FRENZIED_REGEN  = 10
local RAGE_CHALLENGING     = 5
local RAGE_BASH            = 10

-- Rage management thresholds
local RAGE_LOW             = 15   -- below this = rage starved
local RAGE_MANGLE_RESERVE  = 20   -- keep this much banked for the next Mangle
local HIGH_RAGE            = 75   -- Maul allowed in AoE only at/above this
local RAGE_POOL_PULL       = 20   -- pre-pull Enrage stops once we have this much
local OOC_ENRAGE_MAX       = 20   -- don't Enrage OOC if already above this

-- Debuff / buff refresh windows (seconds)
local LACERATE_MAX_STACKS      = 5
local LACERATE_REFRESH_WINDOW  = 3.0   -- refresh a 5-stack within this window
local FAERIE_FIRE_REFRESH      = 4.0
local DEMO_ROAR_REFRESH         = 5.0
local THORNS_REFRESH            = 30
local MOTW_REFRESH             = 120

-- Range
local MELEE_RANGE         = 5
local CHARGE_MIN_RANGE    = 8
local CHARGE_MAX_RANGE    = 25

-- Taunt timing
local TAUNT_COOLDOWN_WINDOW = 8

-------------------------------------------------------------------------------
-- DEBUFF / BUFF SPELL-ID TABLES
-------------------------------------------------------------------------------
local FAERIE_FIRE_DEBUFF = { 27011, 17392, 17391, 17390, 16857, 26993, 9907, 9749, 778, 770 }
local LACERATE_DEBUFF = { 33745 }
local MANGLE_DEBUFF = { 33987, 33986, 33878, 33983, 33982, 33876 }
local DEMO_ROAR_DEBUFF = { 26998, 9898, 9747, 9490, 1735, 99, 25203, 11556, 6190, 1160 }
local MARK_BUFF = { 26991, 26990, 9885, 9884, 8907, 6756, 5234, 5232, 1126, 21850, 21849 }
local THORNS_BUFF = { 26992, 9910, 9756, 8914, 1075, 782, 467 }
local CLEARCASTING_BUFF = { 16870 }
local BARKSKIN_BUFF = { 22812 }
local FRENZIED_REGEN_BUFF = { 22842 }

-- Consumable item IDs (form-agnostic — usable without dropping bear form)
local HEALTHSTONE_IDS = TBC_ITEMS.healthstones or { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }
local HEALING_POTION_IDS = {
    TBC_POTIONS.crystal_healing    or 33934,
    TBC_POTIONS.auchenai_healing   or 32947,
    TBC_POTIONS.super_healing      or 22829,
    TBC_POTIONS.super_rejuvenation or 22850,
    TBC_POTIONS.major_healing      or 13446,
    TBC_POTIONS.greater_healing    or 1710,
    TBC_POTIONS.healing            or 929,
    TBC_POTIONS.lesser_healing     or 858,
}

-------------------------------------------------------------------------------
-- STATE TABLE  (single static table — reused every frame, no per-frame allocs)
-------------------------------------------------------------------------------
local bear_state = {
    now = 0,  me = nil,  target = nil,  settings = {},
    hp = 100,  rage = 0,  rage_deficit = 100,
    stance = STANCE_CASTER,  is_bear = false,
    in_combat = false,  combat_time = 0,
    has_valid_target = false,
    target_hp = 100,  target_ttd = 999,  target_range = 40,  in_melee = false,
    enemy_count = 1,  aoe_threshold = 3,
    maul_rage = 50,  barkskin_hp = 55,  frenzied_regen_hp = 35,
    demo_roar_enabled = true,
    use_cooldowns = true,
    use_self_buffs = true,
    auto_bear_form = true,
    use_pvp_cc_gate = true,
    is_target_boss = false,  is_target_player = false,
    -- auras
    has_clearcasting = false,  has_barkskin = false,  has_frenzied_regen = false,
    has_mark = false,  has_thorns = false,
    faerie_remains = 0,  lacerate_remains = 0,  lacerate_stacks = 0,  demo_remains = 0,
    mangle_remains = 0,
    -- readiness
    mangle_ready = false,  mangle_cd = 0,
    -- consumables
    healthstone_ready = 0,  potion_ready = 0,
    -- threat (target-of-target)
    target_target_exists = false,  target_target_is_me = false,
    target_target_is_tank = false,  target_target_is_player = false,
    target_target_is_healer = false,
    loose_target = false,
    -- interrupt
    target_is_casting = false,  target_interruptible = true,
    -- taunt tracking
    recent_taunt = 0,
    -- rage tracking
    last_rage = 0,  last_rage_time = 0,  rage_delta = 0,  rage_per_second = 0,
    -- context
    is_group = false,
}

-------------------------------------------------------------------------------
-- HELPER FUNCTIONS
-------------------------------------------------------------------------------

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

-- action_ready: returns true if the action has no resolved spell (test env with
-- empty DruidSpells), otherwise delegates to NS.spell_ready against the target.
local function action_ready(context, action)
    if not action then return false end
    if not action.spell then return true end
    if not NS.spell_ready then return true end  -- test env fallback (no engine)
    local target = (action.target == "self" or action.requires_target == false)
                    and (context.me or (NS.GetPlayer and NS.GetPlayer())) or context.target
    if not target then return false end
    local opts = {}
    if action.requires_target == false then opts.skip_range = true end
    if action.cooldown then opts.expected_cooldown = action.cooldown end
    return NS.spell_ready(action.spell, target, opts)
end

local function execute_action(context, action)
    if not action or not action.spell then return false end
    local target = (action.target == "self" or action.requires_target == false)
                    and (context.me or (NS.GetPlayer and NS.GetPlayer())) or context.target
    if not target then return false end
    local opts = {}
    if action.requires_target == false then opts.skip_range = true end
    if action.cooldown then opts.expected_cooldown = action.cooldown end
    if not NS.try_cast then return false end  -- test env fallback (no engine)
    return NS.try_cast(action.spell, target, "[BEAR]", opts)
end

local function execute_item(context, item_id, label)
    if not item_id or item_id <= 0 or not NS.use_item_by_id then return false end
    return NS.use_item_by_id(item_id, context.me) and true or false
end

local function safe_method(unit, method, fallback)
    if not unit then return fallback end
    local fn = NS.safe_field and NS.safe_field(unit, method) or unit[method]
    if type(fn) ~= "function" then return fallback end
    local ok, result = pcall(fn, unit)
    if not ok or result == nil then return fallback end
    return result
end

local function same_unit(a, b)
    if not a or not b then return false end
    if NS.same_unit then return NS.same_unit(a, b) end
    return a == b
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

local function first_ready_item(item_ids)
    if not NS.is_item_ready then return 0 end
    for i = 1, #item_ids do
        if NS.is_item_ready(item_ids[i]) then return item_ids[i] end
    end
    return 0
end

-- can_use_bear_ability: in bear form AND have a target (or running in a bare
-- test env where NS.has_form / NS.spell_ready are both absent).
local function can_use_bear_ability(state)
    if not state.is_bear then return false end
    if state.has_valid_target then return true end
    return NS.has_form == nil and NS.spell_ready == nil
end

-- would_starve_mangle: true if spending rage_cost now would leave us unable to
-- Mangle when it comes off cooldown. Clearcasting bypasses (free cast).
local function would_starve_mangle(state, rage_cost)
    if state.has_clearcasting then return false end
    if not spell_exists(ACTION.MangleBear) then return false end
    if (state.rage or 0) - rage_cost >= RAGE_MANGLE_RESERVE then return false end
    if state.mangle_ready then return (state.rage or 0) < RAGE_MANGLE_RESERVE + rage_cost end
    if (state.mangle_cd or 0) > 1.0 then return false end   -- Mangle far enough away
    return true
end

-- rage_allows_filler: true if we can spend rage_cost on a filler (Swipe) without
-- starving the next Mangle. In test envs (no NS.spell_ready) always true.
local function rage_allows_filler(state, rage_cost)
    if NS.spell_ready == nil then return true end
    if state.has_clearcasting then return true end
    if (state.rage or 0) < rage_cost then return false end
    return not would_starve_mangle(state, rage_cost)
end

local function update_rage_tracking(state)
    local now   = state.now
    local elapsed = now - (state.last_rage_time or 0)
    state.rage_delta = (state.rage or 0) - (state.last_rage or state.rage or 0)
    if elapsed > 0 and elapsed < 5 then
        state.rage_per_second = state.rage_delta / elapsed
    else
        state.rage_per_second = 0
    end
    state.last_rage      = state.rage or 0
    state.last_rage_time = now
    state.rage_deficit   = 100 - (state.rage or 0)
end

-------------------------------------------------------------------------------
-- BEAR SCHEMA  (for spec_kit.safe_state — Pattern 14 nil-guard elimination)
-- Fields NOT listed here use spec_kit.SAFE_STATE_DEFAULTS (rage→0, hp→100, etc.).
-------------------------------------------------------------------------------
local BEAR_SCHEMA = {
    now = 0,  stance = STANCE_CASTER,  is_bear = false,
    in_combat = false,  combat_time = 0,
    has_valid_target = false,
    target_hp = 100,  target_ttd = 999,  target_range = 40,  in_melee = false,
    enemy_count = 1,  aoe_threshold = 3,
    maul_rage = 50,  barkskin_hp = 55,  frenzied_regen_hp = 35,
    demo_roar_enabled = true,  use_cooldowns = true,  use_self_buffs = true,
    auto_bear_form = true,  use_pvp_cc_gate = true,
    is_target_boss = false,  is_target_player = false,
    has_clearcasting = false,  has_barkskin = false,  has_frenzied_regen = false,
    has_mark = false,  has_thorns = false,
    faerie_remains = 0,  lacerate_remains = 0,  lacerate_stacks = 0,
    demo_remains = 0,  mangle_remains = 0,
    mangle_ready = false,  mangle_cd = 0,
    healthstone_ready = 0,  potion_ready = 0,
    target_target_exists = false,  target_target_is_me = false,
    target_target_is_tank = false,  target_target_is_player = false,
    target_target_is_healer = false,  loose_target = false,
    target_is_casting = false,  target_interruptible = true,
    recent_taunt = 0,
    last_rage = 0,  last_rage_time = 0,  rage_delta = 0,  rage_per_second = 0,
    rage_deficit = 100,
    is_group = false,
}

-------------------------------------------------------------------------------
-- BUILD STATE  (throttled to once per frame via context.now)
-------------------------------------------------------------------------------
local _last_build_time = -1

local function build_state(context)
    local state    = bear_state
    local is_group = context.is_group or false
    local settings = context.settings or NS.settings or {}
    local now      = context.now
    if now and now == _last_build_time then return state end   -- frame cache
    now = now or (NS.time_now and NS.time_now() or 0)
    state.now = now
    if context.now then _last_build_time = now end

    state.is_group = is_group
    state.settings = settings
    state.me        = context.me or (NS.GetPlayer and NS.GetPlayer()) or nil
    state.target    = context.target
    state.hp        = context.hp or 100
    state.rage      = context.rage or 0
    state.stance    = context.stance or (NS.get_player_stance and NS.get_player_stance()) or STANCE_CASTER
    state.in_combat   = context.in_combat == true
    state.combat_time = context.combat_time or 0
    state.has_valid_target = (context.has_valid_enemy_target ~= false) and (state.target ~= nil)
    state.target_hp    = context.target_hp or 100
    state.target_ttd   = context.ttd or context.target_ttd or 999
    state.target_range = context.target_range or context.target_distance or 40
    state.in_melee     = context.in_melee_range == true or state.target_range <= MELEE_RANGE
    state.enemy_count  = context.enemy_count or context.enemies_count or 1
    state.is_target_boss = context.target_is_boss == true
                           or (NS.unit_is_boss and NS.unit_is_boss(state.target)) or false
    state.is_target_player = context.target_is_player == true or unit_is_player(state.target)

    -- form
    if NS.has_form then
        state.is_bear = NS.has_form("bear")
    else
        state.is_bear = state.stance == STANCE_BEAR or context.stance == nil
    end

    -- settings (Pattern 8: nil-guarded via NS.setting_number / NS.setting_bool)
    state.aoe_threshold     = NS.setting_number(settings, "bear_aoe_threshold",
                                   NS.setting_number(settings, "aoe_threshold", 3))
    state.maul_rage         = NS.setting_number(settings, "bear_maul_rage", 50)
    state.barkskin_hp       = NS.setting_number(settings, "bear_barkskin_hp",
                                   is_group and 70 or 55)
    state.frenzied_regen_hp = NS.setting_number(settings, "bear_frenzied_regen_hp",
                                   is_group and 50 or 35)
    state.demo_roar_enabled = NS.setting_bool(settings, "bear_demo_roar", true)
    -- Toggleable settings (Pattern 8: nil-guarded, default to enabled)
    state.use_cooldowns     = NS.setting_bool(settings, "use_cooldowns", true)
    state.use_self_buffs    = NS.setting_bool(settings, "use_self_buffs", true)
    state.auto_bear_form    = NS.setting_bool(settings, "auto_bear_form_ooc", true)
    state.use_pvp_cc_gate   = NS.setting_bool(settings, "use_pvp_cc_gating", true)

    -- auras (nil-safe; broken-API guard for crashy private servers)
    local skip_aura = NS.broken_api_throttled and NS.broken_api_throttled(22812, 3.0) or false
    if not skip_aura then
        state.has_clearcasting   = (NS.buff_up and NS.buff_up(state.me, CLEARCASTING_BUFF)) or false
        state.has_barkskin       = (NS.buff_up and NS.buff_up(state.me, BARKSKIN_BUFF)) or false
        state.has_frenzied_regen = (NS.buff_up and NS.buff_up(state.me, FRENZIED_REGEN_BUFF)) or false
        state.has_mark           = (NS.buff_up and NS.buff_up(state.me, MARK_BUFF)) or false
        state.has_thorns         = (NS.buff_remains and NS.buff_remains(state.me, THORNS_BUFF) or 0) > THORNS_REFRESH
        state.faerie_remains     = NS.debuff_remains(state.target, FAERIE_FIRE_DEBUFF) or 0
        state.lacerate_remains   = NS.debuff_remains(state.target, LACERATE_DEBUFF) or 0
        state.lacerate_stacks    = (NS.get_debuff_stacks and NS.get_debuff_stacks(state.target, LACERATE_DEBUFF))
                                   or (NS.debuff_stacks and NS.debuff_stacks(state.target, LACERATE_DEBUFF)) or 0
        state.mangle_remains    = NS.debuff_remains(state.target, MANGLE_DEBUFF) or 0
        state.demo_remains       = NS.debuff_remains(state.target, DEMO_ROAR_DEBUFF) or 0
    end

    -- readiness
    state.mangle_ready = spell_ready(ACTION.MangleBear, state.target)
    state.mangle_cd    = NS.cooldown_remains and NS.cooldown_remains(ACTION.MangleBear) or 0

    -- threat (target-of-target)
    local tt = get_target_of(state.target)
    state.target_target_exists  = tt ~= nil
    state.target_target_is_me   = same_unit(tt, state.me)
    state.target_target_is_tank = is_tank(tt)
    state.target_target_is_player = unit_is_player(tt)
    state.target_target_is_healer = is_healer(tt)
    state.loose_target = state.has_valid_target and state.target_target_exists
                         and not state.target_target_is_me

    -- interrupt info
    state.target_is_casting = (safe_method(state.target, "is_casting", false) == true)
                              or (safe_method(state.target, "is_channeling", false) == true)
    local iv = safe_method(state.target, "is_interruptible", nil)
    if iv == nil then iv = safe_method(state.target, "is_cast_interruptible", nil) end
    state.target_interruptible = iv ~= false

    -- consumables
    state.healthstone_ready = first_ready_item(HEALTHSTONE_IDS)
    state.potion_ready      = first_ready_item(HEALING_POTION_IDS)

    update_rage_tracking(state)
    -- safe_state proxy: structural nil-guard elimination (Pattern 14)
    return spec_kit.safe_state(state, BEAR_SCHEMA)
end

-------------------------------------------------------------------------------
-- MATCH FUNCTIONS  (one per strategy; APL priority enforced by table order)
-------------------------------------------------------------------------------

-- OOC BUFFS (pre-pull caster-form prep — never cast in combat) ----------------

local function mark_matches(context, action)
    local s = build_state(context)
    if not s.use_self_buffs then return false end   -- gated on Self Buffs setting
    if s.in_combat then return false end
    if (NS.buff_remains and NS.buff_remains(s.me, MARK_BUFF) or 0) > MOTW_REFRESH then return false end
    return action_ready(context, action)
end

local function thorns_matches(context, action)
    local s = build_state(context)
    if not s.use_self_buffs then return false end   -- gated on Self Buffs setting
    if s.in_combat then return false end
    if (NS.buff_remains and NS.buff_remains(s.me, THORNS_BUFF) or 0) > THORNS_REFRESH then return false end
    return action_ready(context, action)
end

-- BEAR FORM (shift into bear — the one allowed shift; OOC or just entering combat) --

local function bear_form_matches(context, action)
    local s = build_state(context)
    if s.is_bear then return false end
    if not s.auto_bear_form then return false end   -- gated on Auto Bear Form OOC setting
    if s.in_combat and (s.combat_time or 0) > 3 then return false end   -- no mid-combat shifting
    return action_ready(context, action)
end

-- PRE-PULL RAGE GEN ----------------------------------------------------------

local function pre_pull_enrage_matches(context, action)
    local s = build_state(context)
    if not s.is_bear or s.in_combat then return false end
    if (s.rage or 0) >= RAGE_POOL_PULL then return false end
    if (s.rage or 0) > OOC_ENRAGE_MAX then return false end
    return action_ready(context, action)
end

-- PULL / GAP CLOSE -----------------------------------------------------------

local function feral_charge_pull_matches(context, action)
    local s = build_state(context)
    if not s.is_bear or not s.has_valid_target then return false end
    local rng = s.target_range or 30
    if rng < CHARGE_MIN_RANGE or rng > CHARGE_MAX_RANGE then return false end
    if s.in_combat and (s.combat_time or 0) > 6 then return false end
    return action_ready(context, action)
end

local function faerie_fire_pull_matches(context, action)
    local s = build_state(context)
    if not s.is_bear or not s.has_valid_target then return false end
    if (context.target_armor or 0) == 1 then return false end   -- mob has no armor
    if s.in_melee then return false end
    if (s.target_range or 40) > 30 then return false end
    if (s.faerie_remains or 0) > FAERIE_FIRE_REFRESH then return false end
    return action_ready(context, action)
end

-- DEFENSIVES -----------------------------------------------------------------

local function healthstone_matches(context)
    local s = build_state(context)
    if not s.in_combat then return false end
    if (s.hp or 100) > 28 then return false end
    return (s.healthstone_ready or 0) > 0
end

local function potion_matches(context)
    local s = build_state(context)
    if not s.in_combat then return false end
    if (s.healthstone_ready or 0) > 0 and (s.hp or 100) <= 28 then return false end
    if (s.hp or 100) > 32 then return false end
    return (s.potion_ready or 0) > 0
end

local function frenzied_regen_matches(context, action)
    local s = build_state(context)
    if not s.is_bear or not s.in_combat then return false end
    if not s.use_cooldowns then return false end   -- gated on Cooldowns setting
    if s.has_frenzied_regen then return false end
    if (s.rage or 0) < RAGE_FRENZIED_REGEN then return false end
    if (s.hp or 100) > s.frenzied_regen_hp then return false end
    return action_ready(context, action)
end

local function barkskin_matches(context, action)
    local s = build_state(context)
    if not s.in_combat then return false end
    if not s.use_cooldowns then return false end   -- gated on Cooldowns setting
    if s.has_barkskin then return false end
    if (s.hp or 100) > s.barkskin_hp then return false end
    if (s.hp or 100) <= 15 then return false end   -- save for Frenzied Regen
    return action_ready(context, action)
end

-- TAUNTS ---------------------------------------------------------------------

local function challenging_roar_matches(context, action)
    local s = build_state(context)
    if not s.is_bear or not s.in_combat then return false end
    if not s.use_cooldowns then return false end   -- gated on Cooldowns setting
    if (s.enemy_count or 0) < 3 then return false end
    return action_ready(context, action)
end

local function growl_matches(context, action)
    local s = build_state(context)
    if not s.is_bear or not s.has_valid_target then return false end
    if not s.target_target_exists then return false end
    if s.target_target_is_me then return false end          -- I have aggro
    if s.target_target_is_tank then return false end        -- another tank has it
    -- target attacking a player/healer -> taunt it back (throttle to avoid waste)
    if s.target_target_is_player or s.target_target_is_healer then
        if s.now - (s.recent_taunt or 0) < TAUNT_COOLDOWN_WINDOW then return false end
        return action_ready(context, action)
    end
    return false
end

-- INTERRUPT ------------------------------------------------------------------

local function bash_interrupt_matches(context, action)
    local s = build_state(context)
    local settings = context.settings or {}
    if settings.use_interrupt == false then return false end
    if not s.is_bear or not s.has_valid_target then return false end
    if (s.rage or 0) < RAGE_BASH then return false end
    -- Route through InterruptManager when available for cast-window + humanization
    local mgr = NS.InterruptManager
    if mgr then
        if NS.try_interrupt and not NS.try_interrupt(s.target) then return false end
        if mgr.cast_has_interrupt_window and not mgr.cast_has_interrupt_window(s.target, settings) then return false end
        if mgr.humanize_interrupt_elapsed and not mgr.humanize_interrupt_elapsed(s.target, settings) then return false end
    else
        if not s.target_is_casting then return false end
        if not s.target_interruptible then return false end
    end
    return action_ready(context, action)
end

-- DEBUFF MAINTENANCE  (wowsims: Demo Roar + Faerie Fire) ---------------------
-- NOTE: DemoralizingRoar MUST be registered BEFORE FaerieFireFeral (test contract
--       + TBC tanking priority — mitigation debuff before armor debuff).

local function demo_roar_matches(context, action)
    local s = build_state(context)
    if not s.is_bear or not s.in_combat or not s.demo_roar_enabled then return false end
    if (s.enemy_count or 0) <= 0 then return false end
    if (s.demo_remains or 0) > DEMO_ROAR_REFRESH then return false end
    -- skip on trivial single targets that die fast
    if (s.enemy_count or 0) < 2 and not s.is_target_boss and (s.target_ttd or 999) < 10 then return false end
    return action_ready(context, action)
end

local function faerie_fire_matches(context, action)
    local s = build_state(context)
    if not s.target or not s.is_bear then return false end
    if (context.target_armor or 0) == 1 then return false end   -- mob has no armor
    if (s.faerie_remains or 0) > FAERIE_FIRE_REFRESH then return false end
    return action_ready(context, action)
end

-- CORE ROTATION  (wowsims APL) ----------------------------------------------

local function mangle_matches(context, action)
    local s = build_state(context)
    if not can_use_bear_ability(s) then return false end
    return action_ready(context, action)
end

local function lacerate_matches(context, action)
    local s = build_state(context)
    if not s.target or not can_use_bear_ability(s) then return false end
    -- AoE with loose adds: don't tunnel Lacerate on current target
    if (s.enemy_count or 0) >= (s.aoe_threshold or 3) and (s.lacerate_stacks or 0) >= 3 then return false end
    if (s.lacerate_stacks or 0) < LACERATE_MAX_STACKS then return action_ready(context, action) end
    if (s.lacerate_remains or 0) <= LACERATE_REFRESH_WINDOW then return action_ready(context, action) end
    return false
end

local function swipe_aoe_matches(context, action)
    local s = build_state(context)
    if not s.is_bear then return false end
    if not s.in_combat and NS.spell_ready then return false end
    if (s.enemy_count or 0) < (s.aoe_threshold or 3) then return false end
    if s.use_pvp_cc_gate and context.has_breakable_cc_nearby then return false end
    if not rage_allows_filler(s, RAGE_SWIPE) then return false end
    return action_ready(context, action)
end

local function swipe_cleave_matches(context, action)
    local s = build_state(context)
    if not s.is_bear then return false end
    if not s.in_combat and NS.spell_ready then return false end
    if (s.enemy_count or 0) < 2 then return false end
    if s.use_pvp_cc_gate and context.has_breakable_cc_nearby then return false end
    if s.target and (s.lacerate_stacks or 0) < 3 and (s.target_ttd or 999) > 8 then return false end
    if not rage_allows_filler(s, RAGE_SWIPE) then return false end
    return action_ready(context, action)
end

-- Maul: on-next-swing rage dump (does NOT consume a GCD — independent of the
-- GCD chain). Only with excess rage; never starve the next Mangle/Lacerate.
local function maul_matches(context, action)
    local s = build_state(context)
    if not can_use_bear_ability(s) then return false end
    if (s.enemy_count or 0) >= (s.aoe_threshold or 3) and (s.rage or 0) < HIGH_RAGE then return false end
    if (s.rage or 0) < s.maul_rage then return false end
    if not s.target and NS.spell_ready == nil then return action_ready(context, action) end
    if would_starve_mangle(s, RAGE_MAUL) then return false end
    -- on-next-swing: skip if target dies before the swing lands (unless boss)
    if not s.is_target_boss and (s.target_ttd or 999) < 3 then return false end
    return action_ready(context, action)
end

-- RAGE GEN (in-combat, when starved) -----------------------------------------

local function enrage_combat_matches(context, action)
    local s = build_state(context)
    if not s.is_bear or not s.in_combat then return false end
    if s.is_target_boss then return false end
    if (s.rage or 0) > RAGE_LOW then return false end
    if (s.hp or 100) < 60 and (s.enemy_count or 0) >= 2 then return false end
    if s.mangle_ready and (s.rage or 0) < RAGE_MANGLE then return action_ready(context, action) end
    if (s.lacerate_stacks or 0) < LACERATE_MAX_STACKS and (s.rage or 0) < RAGE_LACERATE then return action_ready(context, action) end
    return false
end

-------------------------------------------------------------------------------
-- ACTIONS TABLE  (bear-form abilities + OOC prep — NO caster/cat combat spells)
-- Order = dispatch priority (first match wins).
-------------------------------------------------------------------------------

local function taunt_execute(context, action)
    local ok = execute_action(context, action)
    if ok then bear_state.recent_taunt = bear_state.now end
    return ok
end

local ACTIONS = {
    -- OOC pre-pull buffs (caster-form prep — never in combat)
    { name = "MarkOfTheWild",    spell = ACTION.MarkOfTheWild, target = "self", requires_target = false, matches = mark_matches },
    { name = "GiftOfTheWild",    spell = ACTION.GiftOfTheWild, target = "self", requires_target = false, matches = mark_matches },
    { name = "Thorns",            spell = ACTION.Thorns,           target = "self", requires_target = false, matches = thorns_matches },

    -- Bear form (the one allowed shift — into bear, not out of it)
    { name = "BearForm",         spell = ACTION.BearForm,  target = "self", requires_target = false, matches = bear_form_matches },

    -- Pre-pull rage gen
    { name = "PrePullEnrage",    spell = ACTION.Enrage,           target = "self", requires_target = false, matches = pre_pull_enrage_matches },

    -- Pull / gap close
    { name = "FeralChargePull",  spell = ACTION.FeralCharge,     matches = feral_charge_pull_matches },
    { name = "FaerieFirePull",   spell = ACTION.FaerieFireFeral, matches = faerie_fire_pull_matches },

    -- Defensives
    { name = "Healthstone",      target = "self", requires_target = false,
      matches = healthstone_matches,
      execute = function(ctx) return execute_item(ctx, build_state(ctx).healthstone_ready, "Healthstone") end },
    { name = "HealingPotion",    target = "self", requires_target = false,
      matches = potion_matches,
      execute = function(ctx) return execute_item(ctx, build_state(ctx).potion_ready, "Healing Potion") end },
    { name = "FrenziedRegeneration", spell = ACTION.FrenziedRegeneration, target = "self",
      requires_target = false, matches = frenzied_regen_matches },
    { name = "Barkskin",         spell = ACTION.Barkskin,   target = "self", requires_target = false, matches = barkskin_matches },

    -- Taunts
    { name = "ChallengingRoar",  spell = ACTION.ChallengingRoar, target = "self",
      requires_target = false, matches = challenging_roar_matches, execute = taunt_execute },
    { name = "Growl",            spell = ACTION.Growl,     matches = growl_matches, execute = taunt_execute },

    -- Interrupt
    { name = "BashInterrupt",    spell = ACTION.Bash,             matches = bash_interrupt_matches },

    -- Debuffs (Demo Roar BEFORE Faerie Fire — TBC tanking priority + test contract)
    { name = "DemoralizingRoar", spell = ACTION.DemoralizingRoar, target = "self",
      requires_target = false, cooldown = 25, matches = demo_roar_matches },
    { name = "FaerieFireFeral",  spell = ACTION.FaerieFireFeral, matches = faerie_fire_matches },

    -- Core rotation (wowsims APL)
    { name = "MangleBear",       spell = ACTION.MangleBear, matches = mangle_matches },
    { name = "Lacerate",         spell = ACTION.Lacerate,   matches = lacerate_matches },
    { name = "SwipeAoE",         spell = ACTION.SwipeBear,  target = "self",
      requires_target = false, matches = swipe_aoe_matches },
    { name = "Swipe",            spell = ACTION.SwipeBear,  target = "self",
      requires_target = false, matches = swipe_cleave_matches },
    { name = "Maul",             spell = ACTION.Maul,       matches = maul_matches },

    -- Rage gen (in-combat, when starved)
    { name = "EnrageCombat",     spell = ACTION.Enrage,            target = "self", requires_target = false, matches = enrage_combat_matches },
}

-------------------------------------------------------------------------------
-- STRATEGIES  (ordered priority list — dispatcher walks top-to-bottom, first
-- match wins and its execute is called)
-------------------------------------------------------------------------------
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

-------------------------------------------------------------------------------
-- REGISTER + RETURN
-------------------------------------------------------------------------------
if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("bear", strategies, { get_state = build_state })
end
if NS.log then NS.log("Druid bear rotation registered (clean APL: no in-combat form shifting)") end

return strategies
