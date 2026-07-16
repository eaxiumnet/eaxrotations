-- leveling_wotlk.lua — Death Knight leveling rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for death knight leveling in WotLK.
-- WHEN:  combat with valid enemy target.
-- WHY:   simple disease-first rotation using core leveling abilities.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

local spec_kit = require("shared/spec_kit_sylvanas")
local helpers = require("shared/leveling_helpers_sylvanas")
local SPELLS = NS.DeathKnightSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    IcyTouch = define("IcyTouch", { 49909, 49802, 49903, 49904, 49905, 49906 }, "IcyTouch"),
    PlagueStrike = define("PlagueStrike", { 49922, 49917, 49918, 49919, 49920, 49921 }, "PlagueStrike"),
    -- Blood Strike ranks (lexxer): 45902 r1 … 49930 max. Removed invalid 49932/49931.
    BloodStrike = define("BloodStrike", { 49930, 49929, 49928, 49927, 49926, 45902 }, "BloodStrike"),
    DeathStrike = define("DeathStrike", { 49998, 49999, 45463, 49924 }, "DeathStrike"),
    HeartStrike = define("HeartStrike", { 55263, 55050, 55259, 55260, 55261, 55262 }, "HeartStrike"),
    Obliterate = define("Obliterate", { 51425, 49020, 51423, 51424 }, "Obliterate"),
    HowlingBlast = define("HowlingBlast", { 51411, 49184, 51209, 51210, 51211, 51212, 51409, 51410 }, "HowlingBlast"),
    ScourgeStrike = define("ScourgeStrike", { 55271, 55090, 55265, 55270 }, "ScourgeStrike"),
    DeathCoil = define("DeathCoil", { 47541, 49892, 49893, 49894, 49895 }, "DeathCoil"),
    HornOfWinter = define("HornOfWinter", { 57623, 57330 }, "HornOfWinter"),
    MindFreeze = define("MindFreeze", 47528, "MindFreeze"),
    BloodPresence = define("BloodPresence", 48266, "BloodPresence"),
    -- AoE + runic-power dump (verified vs class_sylvanas.lua rank lists).
    Pestilence = define("Pestilence", { 50842 }, "Pestilence"),
    DeathAndDecay = define("DeathAndDecay", { 43265, 49936, 49937, 49938 }, "DeathAndDecay"),
    BloodBoil = define("BloodBoil", { 48721, 49939, 49940, 49941 }, "BloodBoil"),
    RuneStrike = define("RuneStrike", { 56815 }, "RuneStrike"),
    EmpowerRuneWeapon = define("EmpowerRuneWeapon", 47568, "EmpowerRuneWeapon"),
}

-- DK diseases are single aura IDs (lexxer wotlk). Removed fake "ranks" 55096-55100 / 55079-55083.
local FROST_FEVER = { 55095 }
local BLOOD_PLAGUE = { 55078 }
local HORN_OF_WINTER_BUFF = { 57623, 57330 }
local BLOOD_PRESENCE_BUFF = { 48266 }

local dk_state = {
    hp = 100,
    target_hp = 100,
    runic_power = 0,
    enemy_count = 1,
    in_combat = false,
    frost_fever_remains = 0,
    blood_plague_remains = 0,
    diseases_up = false,
    horn_of_winter_up = false,
    target_casting = false,
    blood_presence_up = false,
    empower_rune_weapon_ready = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(dk_state)
    local target = context and context.target
    state.hp = (NS.me and NS.me.get_health_percentage and NS.me:get_health_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.runic_power = (NS.me and NS.me.get_runic_power and NS.me:get_runic_power()) or 0
    state.enemy_count = (context and (context.enemies_count or context.enemy_count)) or 1
    state.in_combat = (context and context.in_combat) or false
    state.frost_fever_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FROST_FEVER)) or 0
    state.blood_plague_remains = (target and NS.debuff_remains and NS.debuff_remains(target, BLOOD_PLAGUE)) or 0
    state.diseases_up = (state.frost_fever_remains > 0) or (state.blood_plague_remains > 0)
    state.horn_of_winter_up = (NS.me and NS.buff_up and NS.buff_up(NS.me, HORN_OF_WINTER_BUFF)) or false
    state.target_casting = helpers.should_interrupt(target)
    state.blood_presence_up = (NS.me and NS.buff_up and NS.buff_up(NS.me, BLOOD_PRESENCE_BUFF)) or false
    state.empower_rune_weapon_ready = (ACTION.EmpowerRuneWeapon and ACTION.EmpowerRuneWeapon.cooldown_remaining
        and ACTION.EmpowerRuneWeapon:cooldown_remaining() <= 0) or false
    return state
end

local function mind_freeze_matches(context, state)
    return state.in_combat and state.target_casting == true
end

local function blood_presence_matches(context, state)
    return not state.blood_presence_up
end

local function horn_of_winter_matches(context, state)
    return not state.horn_of_winter_up
end

local function icy_touch_matches(context, state)
    return state.in_combat and state.frost_fever_remains < 3
end

local function plague_strike_matches(context, state)
    return state.in_combat and state.blood_plague_remains < 3
end

local function death_strike_matches(context, state)
    return state.in_combat and state.hp < 80
end

local function obliterate_matches(context, state)
    return state.in_combat
end

local function scourge_strike_matches(context, state)
    return state.in_combat
end

local function heart_strike_matches(context, state)
    return state.in_combat
end

local function howling_blast_matches(context, state)
    return state.in_combat
        and NS.aoe_target_meets and NS.aoe_target_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_10) or 10, context and context.target, context)
end

local function blood_strike_matches(context, state)
    return state.in_combat
end

local function death_coil_matches(context, state)
    return state.in_combat and state.runic_power >= 40
end

local function pestilence_matches(context, state)
    -- Spread existing diseases to nearby targets when fighting a pack.
    return state.in_combat and state.diseases_up == true
        and NS.aoe_target_meets and NS.aoe_target_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_10) or 10, context and context.target, context)
end

local function death_and_decay_matches(context, state)
    -- Ground-target AoE for larger packs (~10yd Community/WotLK).
    return state.in_combat
        and NS.aoe_target_meets and NS.aoe_target_meets(3, (NS.AOE_RADIUS and NS.AOE_RADIUS.GROUND_10) or 10, context and context.target, context, state)
end

local function blood_boil_matches(context, state)
    -- Instant AoE that also detonates diseases; good for 2+ targets (~10yd self).
    return state.in_combat
        and NS.aoe_self_meets and NS.aoe_self_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_10) or 10, context, state)
end

local function rune_strike_matches(context, state)
    -- Runic-power dump that hits harder than Death Coil; fire before it.
    return state.in_combat and state.runic_power >= 30
end

local function empower_rune_weapon_matches(context, state)
    if not state.in_combat then return false end
    if not state.empower_rune_weapon_ready then return false end
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 120) then return false end
    return true
end

local strategies = {
    { name = "MindFreeze", matches = mind_freeze_matches, execute = function(ctx) return ACTION.MindFreeze and ACTION.MindFreeze:cast_safe(ctx.target) end },
    { name = "BloodPresence", matches = blood_presence_matches, execute = function(ctx) return ACTION.BloodPresence and ACTION.BloodPresence:cast_safe() end },
    { name = "HornOfWinter", matches = horn_of_winter_matches, execute = function(ctx) return ACTION.HornOfWinter and ACTION.HornOfWinter:cast_safe() end },
    { name = "IcyTouch", matches = icy_touch_matches, execute = function(ctx) return ACTION.IcyTouch and ACTION.IcyTouch:cast_safe(ctx.target) end },
    { name = "PlagueStrike", matches = plague_strike_matches, execute = function(ctx) return ACTION.PlagueStrike and ACTION.PlagueStrike:cast_safe(ctx.target) end },
    { name = "Pestilence", matches = pestilence_matches, execute = function(ctx) return ACTION.Pestilence and ACTION.Pestilence:cast_safe(ctx.target) end },
    { name = "DeathAndDecay", matches = death_and_decay_matches, execute = function(ctx) return ACTION.DeathAndDecay and ACTION.DeathAndDecay:cast_safe(ctx.target) end },
    { name = "BloodBoil", matches = blood_boil_matches, execute = function(ctx) return ACTION.BloodBoil and ACTION.BloodBoil:cast_safe() end },
    { name = "DeathStrike", matches = death_strike_matches, execute = function(ctx) return ACTION.DeathStrike and ACTION.DeathStrike:cast_safe(ctx.target) end },
    { name = "Obliterate", matches = obliterate_matches, execute = function(ctx) return ACTION.Obliterate and ACTION.Obliterate:cast_safe(ctx.target) end },
    { name = "ScourgeStrike", matches = scourge_strike_matches, execute = function(ctx) return ACTION.ScourgeStrike and ACTION.ScourgeStrike:cast_safe(ctx.target) end },
    { name = "HeartStrike", matches = heart_strike_matches, execute = function(ctx) return ACTION.HeartStrike and ACTION.HeartStrike:cast_safe(ctx.target) end },
    { name = "HowlingBlast", matches = howling_blast_matches, execute = function(ctx) return ACTION.HowlingBlast and ACTION.HowlingBlast:cast_safe(ctx.target) end },
    { name = "BloodStrike", matches = blood_strike_matches, execute = function(ctx) return ACTION.BloodStrike and ACTION.BloodStrike:cast_safe(ctx.target) end },
    { name = "RuneStrike", matches = rune_strike_matches, execute = function(ctx) return ACTION.RuneStrike and ACTION.RuneStrike:cast_safe(ctx.target) end },
    { name = "DeathCoil", matches = death_coil_matches, execute = function(ctx) return ACTION.DeathCoil and ACTION.DeathCoil:cast_safe(ctx.target) end },
    { name = "EmpowerRuneWeapon", matches = empower_rune_weapon_matches, execute = function(ctx) return ACTION.EmpowerRuneWeapon and ACTION.EmpowerRuneWeapon:cast_safe() end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
