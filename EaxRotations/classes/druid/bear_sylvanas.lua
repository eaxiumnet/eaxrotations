-- bear_sylvanas.lua — Druid Bear (Feral tank) rotation for TBC Anniversary (2.5.5).
-- WHAT:  pure bear-form tank rotation — NO in-combat form shifting. Maintains
--         Demoralizing Roar + Faerie Fire (Feral) debuffs, Mangle on cooldown,
--         Lacerate stacked to 5, Swipe for AoE/cleave, Maul as rage dump.
--         Defensives (Frenzied Regen, Barkskin, consumables) + taunts layered in.
-- WHEN:  bear form, in combat, with a valid enemy target.
-- WHY:   mirrors wowsims/tbc tank APL (sim/druid/tank/rotation.go) + TBC community
--         consensus (Icy Veins, Warcraft Tavern, Wowhead). GCD priority:
--           defensives -> taunts -> Faerie Fire -> Demo Roar ->
--           Mangle -> Lacerate (stack/refresh) -> Swipe (AoE) -> Maul (rage dump)
-- SAFETY: Pattern 14 eliminated via spec_kit.safe_state(); no manual nil-guards; no on_update allocs;
--          no caster/cat-form spells in combat (no form shifting); menu refs nil-guarded.
-- DECISION: stripped Ferocious Bite (cat form), RemoveCurse + Nature's Grasp
--           (caster form), all PvP branches, Clearcasting variants, off-target
--           pack scanning, and the "wait for Mangle" pool strategy. The bear stays
--           bear — OOC buffs (Mark/Thorns) are pre-pull caster prep only.
-- LOW-LEVEL: pre-Mangle Maul threshold auto-scales by level (never above menu);
--           Swipe cleave skips Lacerate-stack gate until Lacerate is learned;
--           Demo Roar skips dying single-target trash (HP% + TTD).

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

-- Static reusable opts table to avoid per-frame allocation in hot path (Pattern 4)
local _opts = {}

local SPELLS = NS.DruidSpells or {}
local spec_kit = require("shared/spec_kit_sylvanas")

-- Fallback merge_state for test environments that mock an older spec_kit
-- without the shared helper. Production uses spec_kit.merge_state.
local merge_state = spec_kit.merge_state or function(build_state, context, state_override)
    local s = build_state(context)
    if not state_override or next(state_override) == nil then return s end
    local merged = {}
    for k, v in pairs(s) do merged[k] = v end
    for k, v in pairs(state_override) do merged[k] = v end
    local mt = getmetatable(s)
    if mt then
        local mt_copy = {}
        for k, v in pairs(mt) do mt_copy[k] = v end
        mt_copy.__newindex = nil
        setmetatable(merged, mt_copy)
    end
    return merged
end
local dsl = require("shared/strategy_dsl_sylvanas")
local _hp_ok, HealthPred = pcall(require, "shared/health_pred_helper_sylvanas")
if not _hp_ok or type(HealthPred) ~= "table" then HealthPred = nil end

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
    MarkOfTheWild       = define("MarkOfTheWild",       { 26990, 9885, 9884, 8907, 5234, 6756, 5232, 1126 }, "MarkOfTheWild"),
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
local DEMO_ROAR_DEBUFF = { 26998, 9898, 9747, 9490, 1735, 99, 25203, 11556, 6190, 1160 }
local _rbf_ok, RBF = pcall(require, "shared/ranked_buff_families_sylvanas")
-- GotW first (better than MotW), then MotW high→low + alternate aura IDs (Vanilla∪TBC∪WotLK).
local MARK_BUFF = (_rbf_ok and RBF and RBF.detect("mark_of_the_wild")) or { 26991, 21850, 21849, 26990, 9885, 9884, 8907, 5234, 6756, 5232, 1126, 24752, 39233, 16878 }
local THORNS_BUFF = (_rbf_ok and RBF and RBF.detect("thorns")) or { 26992, 9910, 9756, 8914, 1075, 782, 467 }
local CLEARCASTING_BUFF = { 16870 }
local BARKSKIN_BUFF = { 22812 }
local FRENZIED_REGEN_BUFF = { 22842 }


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
    use_barkskin = false,
    use_challenging_roar = false,
    demo_roar_enabled = true,
    use_cooldowns = true,
    use_self_buffs = true,
    auto_bear_form = true,
    use_pvp_cc_gate = true,
    is_target_boss = false,  is_target_player = false,
    -- auras
    has_clearcasting = false,  has_barkskin = false,  has_frenzied_regen = false,
    faerie_remains = 0,  lacerate_remains = 0,  lacerate_stacks = 0,  demo_remains = 0,
    -- readiness
    mangle_ready = false,  mangle_cd = 0,
    -- threat (target-of-target)
    target_target_exists = false,  target_target_is_me = false,
    target_target_is_tank = false,  target_target_is_player = false,
    target_target_is_healer = false,
    -- interrupt
    target_is_casting = false,  target_interruptible = true,
    -- taunt tracking
    recent_taunt = 0,
    -- rage tracking
    -- swing timer
    swing_remains = 99,
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
    _opts.skip_range = (action.requires_target == false) or nil
    _opts.expected_cooldown = action.cooldown or nil
    _opts.min_interval = nil  -- do not leak Maul throttle into other spells
    return NS.spell_ready(action.spell, target, _opts)
end

local function execute_action(context, action)
    if not action or not action.spell then return false end
    local target = (action.target == "self" or action.requires_target == false)
                    and (context.me or (NS.GetPlayer and NS.GetPlayer())) or context.target
    if not target then return false end
    _opts.skip_range = (action.requires_target == false) or nil
    _opts.expected_cooldown = action.cooldown or nil
    _opts.min_interval = nil  -- do not leak Maul throttle into other spells
    if not NS.try_cast then return false end  -- test env fallback (no engine)
    return NS.try_cast(action.spell, target, "[BEAR]", _opts)
end

local function safe_method(unit, method, fallback)
    if not unit then return fallback end
    local fn = NS.safe_field and NS.safe_field(unit, method) or unit[method]
    if type(fn) ~= "function" then return fallback end
    local ok, result = pcall(fn, unit)
    if not ok or result == nil then return fallback end
    return result
end

local function current_rage(context, unit)
    local get_power = unit and (NS.safe_field and NS.safe_field(unit, "get_power") or unit.get_power)
    if type(get_power) == "function" then
        local ok, rage = pcall(get_power, unit, NS.POWER_RAGE or 1)
        if ok and type(rage) == "number" then return rage end
    end
    return context.rage or 0
end

local function safe_debuff_remains(unit, ids)
    if not unit or type(NS.debuff_remains) ~= "function" then return 0 end
    local ok, remains = pcall(NS.debuff_remains, unit, ids)
    if ok and type(remains) == "number" then return remains end
    return 0
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
    if elapsed > 0 and elapsed < 5 then
    else
    end
    state.last_rage_time = now
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
    faerie_remains = 0,  lacerate_remains = 0,  lacerate_stacks = 0,
    demo_remains = 0,  mangle_remains = 0,
    mangle_ready = false,  mangle_cd = 0,
    swing_remains = 99,
    target_target_exists = false,  target_target_is_me = false,
    target_target_is_tank = false,  target_target_is_player = false,
    target_target_is_healer = false,  loose_target = false,
    target_is_casting = false,  target_interruptible = true,
    recent_taunt = 0,
    is_group = false,
}

-------------------------------------------------------------------------------
-- BUILD STATE  (throttled to once per frame via context.now)
-------------------------------------------------------------------------------
local _last_build_time = -1

local function build_state(context)
    local state    = bear_state
    local is_group = context.is_group or false
    local now      = context.now
    -- Frame cache: wrap in safe_state so nil-guard defaults still apply on
    -- cache hits (mirrors arms_sylvanas:379 / affliction_sylvanas:422 and the
    -- vanilla mirror bear_vanilla:366; returning the raw table bypassed
    -- Pattern-14 nil-guards and read nil for schema-only fields live).
    if now and now == _last_build_time then return spec_kit.safe_state(state, BEAR_SCHEMA) end
    now = now or (NS.time_now and NS.time_now() or 0)
    state.now = now
    if context.now then _last_build_time = now end

    state.is_group = is_group
    state.settings = context.settings
    state.me        = context.me or (NS.GetPlayer and NS.GetPlayer()) or nil
    state.target    = context.target
    state.hp        = context.hp or 100
    state.rage      = current_rage(context, state.me)
    state.stance    = context.stance or (NS.get_player_stance and NS.get_player_stance()) or STANCE_CASTER
    state.in_combat   = context.in_combat == true
    state.combat_time = context.combat_time or 0
    -- IZI SDK: time_in_combat() provides more accurate combat timing
    if state.me and type(state.me.time_in_combat) == "function" then
        local ok_t, t = pcall(state.me.time_in_combat, state.me)
        if ok_t and type(t) == "number" then state.combat_time = t end
    end
    state.has_valid_target = (context.has_valid_enemy_target ~= false) and (state.target ~= nil)
    state.target_hp    = context.target_hp or 100
    state.target_ttd   = context.ttd or context.target_ttd or 999
    state.level        = context.level or context.player_level or 70
    state.target_range = context.target_range or context.target_distance or 40
    state.in_melee     = context.in_melee_range == true or state.target_range <= MELEE_RANGE
    state.enemy_count  = context.enemy_count or context.enemies_count or 1
    state.is_target_boss = context.target_is_boss == true
                           or (NS.unit_is_boss and NS.unit_is_boss(state.target)) or false

    -- form
    if NS.has_form then
        state.is_bear = NS.has_form("bear")
    else
        state.is_bear = state.stance == STANCE_BEAR or context.stance == nil
    end

    -- settings (Pattern 8: nil-guarded via NS.setting_number / NS.setting_bool)
    state.aoe_threshold     = spec_kit.setting_number(context, "bear_aoe_threshold",
                                   spec_kit.setting_number(context, "aoe_threshold", 3))
    state.maul_rage         = spec_kit.setting_number(context, "bear_maul_rage", 30)
    local group_aware = spec_kit.setting_bool(context, "druid_group_aware_defensives", true)
    state.barkskin_hp       = spec_kit.setting_number(context, "bear_barkskin_hp",
                                   (group_aware and is_group) and 70 or 55)
    state.frenzied_regen_hp = spec_kit.setting_number(context, "bear_frenzied_regen_hp",
                                   (group_aware and is_group) and 50 or 35)
    state.use_barkskin        = spec_kit.setting_bool(context, "bear_use_barkskin", false)
    state.use_challenging_roar= spec_kit.setting_bool(context, "bear_use_challenging_roar", false)
    state.demo_roar_enabled = spec_kit.setting_bool(context, "bear_demo_roar", true)
    -- Toggleable settings (Pattern 8: nil-guarded, default to enabled)
    state.use_cooldowns     = spec_kit.setting_bool(context, "use_cooldowns", true)
    state.use_self_buffs    = spec_kit.setting_bool(context, "use_self_buffs", true)
    state.auto_bear_form    = spec_kit.setting_bool(context, "auto_bear_form_ooc", true)
    state.use_pvp_cc_gate   = spec_kit.setting_bool(context, "use_pvp_cc_gating", true)

    -- auras (nil-safe; broken-API guard for crashy private servers)
    state.has_clearcasting   = (NS.buff_up and NS.buff_up(state.me, CLEARCASTING_BUFF)) or false
    state.has_barkskin       = (NS.buff_up and NS.buff_up(state.me, BARKSKIN_BUFF)) or false
    state.has_frenzied_regen = (NS.buff_up and NS.buff_up(state.me, FRENZIED_REGEN_BUFF)) or false
    state.faerie_remains     = safe_debuff_remains(state.target, FAERIE_FIRE_DEBUFF)
    state.lacerate_remains   = safe_debuff_remains(state.target, LACERATE_DEBUFF)
    state.lacerate_stacks    = (NS.get_debuff_stacks and NS.get_debuff_stacks(state.target, LACERATE_DEBUFF))
                               or (NS.debuff_stacks and NS.debuff_stacks(state.target, LACERATE_DEBUFF)) or 0
    state.demo_remains       = safe_debuff_remains(state.target, DEMO_ROAR_DEBUFF)

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
                         and not state.target_target_is_me

    -- interrupt info
    state.target_is_casting = (safe_method(state.target, "is_casting", false) == true)
                              or (safe_method(state.target, "is_channeling", false) == true)
    local iv = safe_method(state.target, "is_interruptible", nil)
    if iv == nil then iv = safe_method(state.target, "is_cast_interruptible", nil) end
    state.target_interruptible = iv ~= false

    -- Swing timer for Maul gating
    local swing_remains = 99
    if state.me and NS.swing_time_until then
        local ok, sr = pcall(NS.swing_time_until, state.me)
        if ok and type(sr) == "number" then swing_remains = sr end
    end
    state.swing_remains = swing_remains

    update_rage_tracking(state)

    if NS.SnapThreat and type(NS.SnapThreat.check) == "function" and state.is_bear then
        local snap_spell = NS.SnapThreat.check(state.me, state.target, context.settings, {
            spell_id = ACTION.Growl,
            fallback_id = ACTION.MangleBear or ACTION.Maul,
        })
        if snap_spell and NS.try_cast and state.target then
            pcall(NS.try_cast, snap_spell, state.target, "[BEAR] Snap Threat opener")
        end
    end

    return spec_kit.safe_state(state, BEAR_SCHEMA)
end

-------------------------------------------------------------------------------
-- MATCH FUNCTIONS  (one per strategy; APL priority enforced by table order)
-------------------------------------------------------------------------------

-- OOC BUFFS (pre-pull caster-form prep — never cast in combat) ----------------
-- CRITICAL: MotW / Gift / Thorns are caster-form spells. Casting them while in
-- bear form cancels the form in TBC, which then re-triggers BearForm → Enrage
-- → MotW loops (live log: MotW/Thorns mid-pull on player name).

local function mark_matches(context, action)
    local s = build_state(context)
    if not s.use_self_buffs then return false end   -- gated on Self Buffs setting
    if s.in_combat then return false end
    if s.is_bear then return false end              -- never break bear form for buffs
    local spell = ACTION.MarkOfTheWild or action
    -- When aura APIs return remains=0, recent-cast lockout stops MotW spam.
    -- Never overwrite Gift / higher MotW with a worse MotW rank.
    if NS.buff_would_downgrade and NS.buff_would_downgrade(s.me, MARK_BUFF, spell) then return false end
    if (NS.buff_remains and NS.buff_remains(s.me, MARK_BUFF) or 0) > MOTW_REFRESH then return false end
    return action_ready(context, action)
end

local function thorns_matches(context, action)
    local s = build_state(context)
    if not s.use_self_buffs then return false end   -- gated on Self Buffs setting
    if s.in_combat then return false end
    if s.is_bear then return false end              -- never break bear form for buffs
    local spell = ACTION.Thorns or action
    -- Live log: Thorns 782 re-queued every GCD while aura API reports missing.
    if NS.buff_would_downgrade and NS.buff_would_downgrade(s.me, THORNS_BUFF, spell) then return false end
    if (NS.buff_remains and NS.buff_remains(s.me, THORNS_BUFF) or 0) > THORNS_REFRESH then return false end
    return action_ready(context, action)
end

-- BEAR FORM (shift into bear — the one allowed shift; OOC or just entering combat) --

local _last_bear_form_attempt = 0
local BEAR_FORM_RESHIFT_INTERVAL = 3.0
-- After a successful queue, hold re-shift longer so form buff can apply before we re-queue.
local BEAR_FORM_POST_CAST_LOCKOUT = 1.5
local _bear_form_cast_at = 0

-- PRE-PULL RAGE GEN ----------------------------------------------------------

local function pre_pull_enrage_matches(context, action)
    local s = build_state(context)
    if (s.rage or 0) >= RAGE_POOL_PULL then return false end
    if (s.rage or 0) > OOC_ENRAGE_MAX then return false end
    return action_ready(context, action)
end

-- PULL / GAP CLOSE -----------------------------------------------------------

local function feral_charge_pull_matches(context, action)
    local s = build_state(context)
    local rng = s.target_range or 30
    if rng < CHARGE_MIN_RANGE or rng > CHARGE_MAX_RANGE then return false end
    if s.in_combat and (s.combat_time or 0) > 6 then return false end
    return action_ready(context, action)
end

local function faerie_fire_pull_matches(context, action)
    local s = build_state(context)
    -- pull only; never chain-pull mid-combat
    if (context.target_armor or 0) == 1 then return false end   -- mob has no armor
    if s.in_melee then return false end
    if (s.target_range or 40) > 30 then return false end
    if (s.faerie_remains or 0) > FAERIE_FIRE_REFRESH then return false end
    return action_ready(context, action)
end

-- DEFENSIVES -----------------------------------------------------------------

local function barkskin_matches(context, action)
    local s = build_state(context)
    if not s.in_combat then return false end
    if not s.use_barkskin then return false end    -- gated on dedicated toggle (default OFF)
    if s.is_bear then return false end             -- Barkskin breaks bear form in TBC
    if s.has_barkskin then return false end
    if (s.hp or 100) > s.barkskin_hp then return false end
    if (s.hp or 100) <= 15 then return false end   -- save for Frenzied Regen
    return action_ready(context, action)
end

-- TAUNTS ---------------------------------------------------------------------

local function challenging_roar_matches(context, action)
    if not spec_kit.setting_bool(context, "auto_taunt", true) then return false end
    local s = build_state(context)
    if not s.use_challenging_roar then return false end  -- gated on dedicated toggle (default OFF)
    if (s.enemy_count or 0) < 3 then return false end
    return action_ready(context, action)
end

local function growl_matches(context, action)
    if not spec_kit.setting_bool(context, "auto_taunt", true) then return false end
    local s = build_state(context)
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
    if not spec_kit.setting_bool(context, "use_interrupt", true) then return false end
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

-- DEBUFF MAINTENANCE  (wowsims: Faerie Fire + Demo Roar) ---------------------
-- NOTE: FaerieFireFeral MUST be registered BEFORE DemoralizingRoar (wowsims/tbc
--       sim/druid/tank/rotation.go checks FF first; test contract mirrors it).

local _demo_roar_attempts = {} -- keyed by target guid -> timestamp of last attempt
local DEMO_ROAR_IMMUNE_COOLDOWN = 8
local DEMO_ROAR_RANGE = 10

local function target_key(target)
    if not target then return nil end
    if target.get_guid then
        local ok, guid = pcall(target.get_guid, target)
        if ok and guid then return guid end
    end
    return tostring(target)
end

local function target_is_demo_immune(s)
    local key = target_key(s.target)
    if not key then return false end
    local last = _demo_roar_attempts[key]
    if not last then return false end
    if (s.now or 0) - last < DEMO_ROAR_IMMUNE_COOLDOWN then
        if (s.demo_remains or 0) <= 0 then
            return true
        end
    end
    return false
end

-- CORE ROTATION  (wowsims APL) ----------------------------------------------

local function swipe_aoe_matches(context, action)
    local s = build_state(context)
    -- TBC Swipe requires a hostile melee target (not self). Self-cast spam-loops
    -- when the client rejects the cast and the strategy rematches every frame.
    if not s.in_combat and NS.spell_ready then return false end
    -- Fallback: if the engine AoE helper is unavailable or disagrees with the
    -- context enemy count, trust the context when it reports enough enemies.
    local aoe_ok = NS.aoe_target_meets and NS.aoe_target_meets(s.aoe_threshold or 3, (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_8) or 8, context.target, context, s)
    if not aoe_ok and (s.enemy_count or 0) < (s.aoe_threshold or 3) then return false end
    if s.use_pvp_cc_gate and context.has_breakable_cc_nearby then return false end
    if not rage_allows_filler(s, RAGE_SWIPE) then
        -- High-rage bypass: don't sit rage-capped in AoE just because Mangle
        -- is about to come off cooldown.
        if (s.rage or 0) < 70 then return false end
    end
    return action_ready(context, action)
end

local function swipe_cleave_matches(context, action)
    local s = build_state(context)
    -- TBC Swipe requires a hostile melee target (not self). See swipe_aoe_matches.
    if not s.in_combat and NS.spell_ready then return false end
    local aoe_ok = NS.aoe_target_meets and NS.aoe_target_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_8) or 8, context.target, context, s)
    if not aoe_ok and (s.enemy_count or 0) < 2 then return false end
    if s.use_pvp_cc_gate and context.has_breakable_cc_nearby then return false end
    if s.target and spell_exists(ACTION.Lacerate) and (s.lacerate_stacks or 0) < 3 and (s.target_ttd or 999) > 8 then return false end
    if not rage_allows_filler(s, RAGE_SWIPE) then return false end
    return action_ready(context, action)
end

local function swing_timer_gate(context, state)
    if not spec_kit.setting_bool(context, "bear_swing_timer", true) then return true end
    local swing_remains = (state and state.swing_remains) or 99
    -- Unknown (999) / disabled timer: fail open. Near-swing (0–0.15s): hold re-queue.
    return swing_remains > 0.15 or swing_remains < 0
end

-- Maul rank IDs (TBC) — used with is_current_spell to detect an already-queued next swing.
local MAUL_IDS = { 26996, 9881, 9880, 9745, 8972, 6809, 6808, 6807 }

local function maul_is_queued()
    -- WoW "current spell" = next-swing ability already armed (Maul/HS/Cleave).
    if not NS.is_current_spell then return false end
    for i = 1, #MAUL_IDS do
        if NS.is_current_spell(MAUL_IDS[i]) then return true end
    end
    -- Also check the resolved action id (highest learned rank).
    if ACTION.Maul and NS.get_spell_id then
        local id = NS.get_spell_id(ACTION.Maul)
        if type(id) == "number" and NS.is_current_spell(id) then return true end
    end
    return false
end

-- Maul: on-next-swing rage dump (does NOT consume a GCD — independent of the
-- GCD chain). With Mangle learned: menu threshold only. Without Mangle: primary
-- spender — level-scaled threshold, never raised above the menu setting.
-- SAFETY: never re-queue while already current (spam loop in spell queue log).
local function maul_execute(context, action)
    -- min_interval: belt-and-suspenders when is_current_spell is stubbed/broken
    -- so we do not re-queue Maul every dispatcher tick (live spam log).
    if not action or not action.spell then return false end
    local target = context and context.target
    if not target then return false end
    _opts.skip_range = nil
    _opts.expected_cooldown = action.cooldown or nil
    _opts.min_interval = 0.5
    if not NS.try_cast then return false end
    return NS.try_cast(action.spell, target, "[BEAR]", _opts)
end

-- RAGE GEN (in-combat, when starved) -----------------------------------------

local function enrage_combat_matches(context, action)
    local s = build_state(context)
    if s.is_target_boss then return false end
    if (s.rage or 0) > RAGE_LOW then return false end
    if (s.hp or 100) < 60 and (s.enemy_count or 0) >= 2 then return false end
    if s.mangle_ready and (s.rage or 0) < RAGE_MANGLE then return action_ready(context, action) end
    if (s.lacerate_stacks or 0) < LACERATE_MAX_STACKS and (s.rage or 0) < RAGE_LACERATE then return action_ready(context, action) end
    return false
end

-------------------------------------------------------------------------------
-- DSL DEFS  (declarative equivalents for 7 core strategies)
-- WHY:   validates DSL generality across rage tanking + bear form mechanics.
-- NOTE:  Conditions below are intentionally faithful to the imperative match
--        functions above so behavior is preserved exactly.
-------------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "BearForm",
        conditions = {
            { type = "custom", fn = function(context, state)
                if state.is_bear then return false end
                if not state.auto_bear_form then return false end
                local now = state.now or (NS.time_now and NS.time_now()) or 0
                if now - _last_bear_form_attempt < BEAR_FORM_RESHIFT_INTERVAL then return false end
                if now - _bear_form_cast_at < BEAR_FORM_POST_CAST_LOCKOUT then return false end
                if not action_ready(context, { spell = ACTION.BearForm, target = "self", requires_target = false }) then return false end
                _last_bear_form_attempt = now
                return true
            end },
        },
        action = { type = "custom", fn = function(context, state)
            local ok = execute_action(context, { spell = ACTION.BearForm, target = "self", requires_target = false })
            if ok then
                _bear_form_cast_at = (context and context.now) or (NS.time_now and NS.time_now()) or 0
            end
            return ok
        end },
    },
    {
        name = "FrenziedRegeneration",
        conditions = {
            { type = "custom", fn = function(context, state)
                if not state.is_bear or not state.in_combat then return false end
                if not state.use_cooldowns then return false end
                if state.has_frenzied_regen then return false end
                if (state.rage or 0) < RAGE_FRENZIED_REGEN then return false end
                local hp = state.hp or 100
                local threshold = state.frenzied_regen_hp or 35
                if hp > threshold then
                    local me = state.me or (NS.GetPlayer and NS.GetPlayer())
                    local pred_hp = hp
                    if me and HealthPred and HealthPred.predicted_hp_pct then
                        local ok, pct = pcall(HealthPred.predicted_hp_pct, me, 2.0)
                        if ok and type(pct) == "number" then pred_hp = pct end
                    end
                    if pred_hp > threshold then return false end
                end
                return action_ready(context, { spell = ACTION.FrenziedRegeneration, target = "self", requires_target = false })
            end },
        },
        action = { type = "cast", spell = ACTION.FrenziedRegeneration, target = "self" },
    },
    {
        name = "FaerieFireFeral",
        conditions = {
            { type = "custom", fn = function(context, state)
                if not state.is_bear or not state.in_combat or not state.has_valid_target then return false end
                if (context.target_armor or 0) == 1 then return false end
                if (state.target_range or 40) > 30 then return false end
                if (state.faerie_remains or 0) > FAERIE_FIRE_REFRESH then return false end
                return action_ready(context, { spell = ACTION.FaerieFireFeral })
            end },
        },
        action = { type = "cast", spell = ACTION.FaerieFireFeral },
    },
    {
        name = "DemoralizingRoar",
        conditions = {
            { type = "custom", fn = function(context, state)
                if not state.is_bear or not state.in_combat or not state.demo_roar_enabled then return false end
                if (state.target_range or 40) > DEMO_ROAR_RANGE then return false end
                if (state.enemy_count or 0) <= 0 then return false end
                if (state.demo_remains or 0) > DEMO_ROAR_REFRESH then return false end
                if target_is_demo_immune(state) then return false end
                if (state.enemy_count or 0) < 2 and not state.is_target_boss then
                    if (state.target_ttd or 999) < 10 then return false end
                    if (state.target_hp or 100) <= 20 then return false end
                end
                return action_ready(context, { spell = ACTION.DemoralizingRoar, target = "self", requires_target = false, cooldown = 25 })
            end },
        },
        action = { type = "custom", fn = function(context, state)
            local ok = execute_action(context, { spell = ACTION.DemoralizingRoar, target = "self", requires_target = false, cooldown = 25 })
            local key = target_key(state.target)
            if key then _demo_roar_attempts[key] = state.now end
            return ok
        end },
    },
    {
        name = "MangleBear",
        conditions = {
            { type = "custom", fn = function(context, state)
                if not can_use_bear_ability(state) then return false end
                return action_ready(context, { spell = ACTION.MangleBear })
            end },
        },
        action = { type = "cast", spell = ACTION.MangleBear },
    },
    {
        name = "Lacerate",
        conditions = {
            { type = "custom", fn = function(context, state)
                if not state.target or not can_use_bear_ability(state) then return false end
                if (state.enemy_count or 0) >= (state.aoe_threshold or 3) and (state.lacerate_stacks or 0) >= 3 then return false end
                if (state.lacerate_stacks or 0) < LACERATE_MAX_STACKS then return action_ready(context, { spell = ACTION.Lacerate }) end
                if (state.lacerate_remains or 0) <= LACERATE_REFRESH_WINDOW then return action_ready(context, { spell = ACTION.Lacerate }) end
                return false
            end },
        },
        action = { type = "cast", spell = ACTION.Lacerate },
    },
    {
        name = "Maul",
        conditions = {
            { type = "custom", fn = function(context, state)
                if not can_use_bear_ability(state) then return false end
                if maul_is_queued() then return false end
                local maul_threshold = state.maul_rage or 30
                if not spell_exists(ACTION.MangleBear) then
                    local scaled = math.max(15, math.min(40, 15 + math.floor((state.level or 70) / 2)))
                    if scaled < maul_threshold then maul_threshold = scaled end
                end
                if (state.rage or 0) < maul_threshold then return false end
                if not state.target and NS.spell_ready == nil then return action_ready(context, { spell = ACTION.Maul }) end
                if would_starve_mangle(state, RAGE_MAUL) then return false end
                if not state.is_target_boss and (state.target_ttd or 999) < 3 then return false end
                if not swing_timer_gate(context, state) then return false end
                -- Maul is on-next-swing and does not share the GCD, so do not gate
                -- it on spell_ready/GCD. This fixes rage-capping while Lacerate/Swipe
                -- consume GCD ticks.
                return true
            end },
        },
        action = { type = "custom", fn = function(context, state)
            return maul_execute(context, { spell = ACTION.Maul })
        end },
    },
}

-------------------------------------------------------------------------------
-- ACTIONS TABLE  (bear-form abilities + OOC prep — NO caster/cat combat spells)
-- Order = dispatch priority (first match wins).
-------------------------------------------------------------------------------

local function taunt_execute(context, action)
    local ok = execute_action(context, action)
    if ok then bear_state.recent_taunt = bear_state.now end
    return ok
end

-------------------------------------------------------------------------------
-- CENTRALIZED BASE MATCH GUARDS
-- WHY:  eliminates repeated is_bear/in_combat/target boilerplate from every
--       match function. Per-strategy logic stays in *_matches(); generic guards
--       are declared as properties in the ACTIONS table.
-- WHEN: applied to the strategies table after DSL substitution so DSL and
--       imperative strategies share the same guard layer.
-------------------------------------------------------------------------------
local function base_guard_passes(action_def, s)
    if action_def.spell and NS.spell_exists and not spell_exists(action_def.spell) then return false end
    if action_def.requires_target ~= false and not s.has_valid_target then return false end
    if action_def.required_form == "bear" and not s.is_bear then return false end
    if action_def.requires_in_combat and not s.in_combat then return false end
    if action_def.requires_not_in_combat and s.in_combat then return false end
    if action_def.min_rage and (s.rage or 0) < action_def.min_rage then return false end
    return true
end


local function apply_base_matches(strategies, actions)
    for i = 1, #strategies do
        local action = actions[i]
        local original_matches = strategies[i].matches
        strategies[i].matches = function(context, state)
            local s = merge_state(build_state, context, state)
            if not base_guard_passes(action, s) then return false end
            return original_matches(context, s)
        end
    end
end

local ACTIONS = {
    -- OOC pre-pull buffs (caster-form prep — never in combat)
    { name = "MarkOfTheWild",    spell = ACTION.MarkOfTheWild, target = "self", requires_target = false, matches = mark_matches },
    { name = "GiftOfTheWild",    spell = ACTION.GiftOfTheWild, target = "self", requires_target = false, matches = mark_matches },
    { name = "Thorns",            spell = ACTION.Thorns,           target = "self", requires_target = false, matches = thorns_matches },

    -- Bear form (the one allowed shift — into bear, not out of it)
    -- DSL-substituted: matches/execute replaced by DSL compiled strategy.
    { name = "BearForm",         spell = ACTION.BearForm,  target = "self", requires_target = false },

    -- Pre-pull rage gen
    { name = "PrePullEnrage",    spell = ACTION.Enrage,           target = "self", requires_target = false,
      requires_not_in_combat = true, required_form = "bear", matches = pre_pull_enrage_matches },

    -- Pull / gap close
    { name = "FeralChargePull",  spell = ACTION.FeralCharge,     required_form = "bear", matches = feral_charge_pull_matches },
    { name = "FaerieFirePull",   spell = ACTION.FaerieFireFeral, required_form = "bear",
      requires_not_in_combat = true, matches = faerie_fire_pull_matches },

    -- Defensives
    -- DSL-substituted: matches replaced by DSL compiled strategy.
    { name = "FrenziedRegeneration", spell = ACTION.FrenziedRegeneration, target = "self",
      requires_target = false, required_form = "bear", requires_in_combat = true, min_rage = RAGE_FRENZIED_REGEN },
    { name = "Barkskin",         spell = ACTION.Barkskin,   target = "self", requires_target = false,
      requires_in_combat = true, matches = barkskin_matches },

    -- Taunts
    { name = "ChallengingRoar",  spell = ACTION.ChallengingRoar, target = "self",
      requires_target = false, required_form = "bear", requires_in_combat = true, min_rage = RAGE_CHALLENGING,
      matches = challenging_roar_matches, execute = taunt_execute },
    { name = "Growl",            spell = ACTION.Growl,     required_form = "bear", matches = growl_matches, execute = taunt_execute },

    -- Interrupt
    { name = "BashInterrupt",    spell = ACTION.Bash,             required_form = "bear",
      min_rage = RAGE_BASH, matches = bash_interrupt_matches },

    -- Debuffs (wowsims/tbc sim/druid/tank/rotation.go: Faerie Fire BEFORE
    -- Demoralizing Roar — FF is the armor debuff checked first in the dispatch)
    -- DSL-substituted: matches/execute replaced by DSL compiled strategy.
    { name = "FaerieFireFeral",  spell = ACTION.FaerieFireFeral, required_form = "bear", requires_in_combat = true },
    { name = "DemoralizingRoar", spell = ACTION.DemoralizingRoar, target = "self",
      requires_target = false, required_form = "bear", requires_in_combat = true, min_rage = RAGE_DEMO_ROAR,
      cooldown = 25 },


    -- Core rotation (wowsims APL)
    -- DSL-substituted: matches replaced by DSL compiled strategy.
    { name = "MangleBear",       spell = ACTION.MangleBear, required_form = "bear", min_rage = RAGE_MANGLE },
    { name = "Lacerate",         spell = ACTION.Lacerate, required_form = "bear", min_rage = RAGE_LACERATE },
    -- Swipe: hostile target required in TBC (melee cone). Do NOT use target="self"
    -- — self-cast is rejected by the client and spam-loops via the spell queue.
    { name = "SwipeAoE",         spell = ACTION.SwipeBear, required_form = "bear", min_rage = RAGE_SWIPE,
      matches = swipe_aoe_matches },
    { name = "Swipe",            spell = ACTION.SwipeBear, required_form = "bear", min_rage = RAGE_SWIPE,
      matches = swipe_cleave_matches },
    -- Maul is on-next-swing: custom execute with min_interval + is_current_spell gate.
    -- DSL-substituted: matches/execute replaced by DSL compiled strategy.
    { name = "Maul",             spell = ACTION.Maul, required_form = "bear", min_rage = RAGE_MAUL },

    -- Rage gen (in-combat, when starved)
    { name = "EnrageCombat",     spell = ACTION.Enrage,            target = "self", requires_target = false,
      required_form = "bear", requires_in_combat = true, matches = enrage_combat_matches },
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

-- Replace selected strategies with DSL-compiled equivalents.
-- NOTE: The strategies table above is built dynamically from the ACTIONS table.
-- Because parity strategies may be inserted or reordered in the future, we match
-- by name rather than numeric index to keep the substitution robust.
for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

-- Apply centralized base_matches guards on top of both imperative and DSL
-- strategies. This must happen AFTER DSL substitution so the wrapper does not
-- get overwritten by the compiled DSL strategy.
apply_base_matches(strategies, ACTIONS)

-------------------------------------------------------------------------------
-- REGISTER + RETURN
-------------------------------------------------------------------------------
if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("bear", strategies, { get_state = build_state })
end
if NS.log then NS.log("Druid bear rotation registered (clean APL: no in-combat form shifting)") end

return { strategies = strategies, build_state = build_state }
