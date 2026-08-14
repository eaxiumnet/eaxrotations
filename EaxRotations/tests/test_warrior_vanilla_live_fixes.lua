-- test_warrior_vanilla_live_fixes.lua — WAVE 1.3 warrior vanilla live-fix regression tests.
-- WHAT:  pins the W1.3 register fixes: leveling disarm settings guard + PvPCCGate
--        no-halt + Execute dance condition; fury BattleShout/Bloodrage presence +
--        Slam swing/2H gates + SS buff check + BerserkerRage OOC gate + Overpower
--        real-proc window; kebab SS buff id (12292, not the TBC constant); prot
--        TC/Taunt/ChallengingShout gates; arms Sunder stance-free.
-- WHEN:  standalone (`lua EaxRotations/tests/test_warrior_vanilla_live_fixes.lua`);
--        registered in run_rotation_tests.lua (Wave 1.5 close-out).
-- WHY:   the Critical/Must fixes must not silently regress.
-- SAFETY: pure unit tests with a mocked _G.EaxRotations; no game API calls.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
end

-- ---------------------------------------------------------------------------
-- Shared spy state
-- ---------------------------------------------------------------------------
local spy = {
    cast_labels = {},
    ss_buff_id = nil,
    ss_buff_up = false,
    cc_active = false,
    debuff_remains = 0,
    swing_until = 999,
}

package.loaded["common/enums"] = { class_id = { WARRIOR = 1 } }

-- Mock shared modules that spec files require at load time.
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {},
}
package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function() end }
-- leveling_vanilla requires shared/leveling_sylvanas; a minimal mock keeps the
-- test hermetic (the real module captures _G.EaxRotations at require time).
package.loaded["shared/leveling_sylvanas"] = {
    create_context_guard = function() return function() return true end end,
    build_common_state = function(context, state)
        state.in_combat = context.in_combat or false
        state.enemies = context.enemies_count or context.enemies or 0
        state.hp = context.hp or 100
        state.target = context.target
    end,
}

local registry_options = {}

_G.EaxRotations = {
    CLASS_ID = { WARRIOR = 1 },
    PLAYER_UNIT = {},
    WarriorSpells = {
        BattleShout = 6673, BattleStance = 2457, BerserkerRage = 18499,
        BerserkerStance = 2458, Bloodrage = 2687, Bloodthirst = 23881,
        Charge = 100, Cleave = 845, DeathWish = 12292, DefensiveStance = 71,
        DemoralizingShout = 1160, Disarm = 676, Execute = 5308, Hamstring = 1715,
        HeroicStrike = 78, Intercept = 20252, Overpower = 7384, Pummel = 6552,
        Recklessness = 1719, Rend = 772, Slam = 1464, SunderArmor = 7386,
        SweepingStrikes = 12292, ThunderClap = 6343, Whirlwind = 1680,
        MortalStrike = 12294, Retaliation = 20230, ShieldWall = 871,
        IntimidatingShout = 5246, PiercingHowl = 12323, Taunt = 355,
        MockingBlow = 694, ChallengingShout = 1161, ShieldBash = 72,
        LastStand = 12975, ShieldSlam = 23922, Revenge = 6572, ShieldBlock = 2565,
    },
    WarriorConstants = {
        STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
        -- Real class_sylvanas value (TBC id): the W1.3 kebab fix must NOT use it
        BUFF_ID = { SWEEPING_STRIKES = 12328 },
        BATTLE_SHOUT_IDS = { 11551, 11550, 11549, 6192, 5242, 6673 },
        SUNDER_DEBUFF = { 11597, 11596, 8380, 7405, 7386 },
        THUNDER_CLAP_DEBUFF = { 11581, 11580, 8205, 8204, 8198, 6343 },
        DEMO_SHOUT_DEBUFF = { 11556, 11555, 11554, 6190, 1160 },
        DISARM_CLASS_IDS = { [1] = true, [2] = true, [4] = true, [7] = true },
    },
    GetPlayer = function() return { get_class = function() return 1 end } end,
    spell_action = function(ids) return type(ids) == "table" and ids[1] or ids end,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    try_cast = function(spell, target, label)
        spy.cast_labels[#spy.cast_labels + 1] = tostring(label or spell)
        return true
    end,
    buff_up = function() return false end,
    buff_remains = function() return 0 end,
    debuff_up = function() return false end,
    debuff_remains = function() return spy.debuff_remains end,
    debuff_stacks = function() return 0 end,
    get_debuff_stacks = function() return 0 end,
    cooldown_remains = function() return 0 end,
    is_execute_phase = function(hp, t) return (hp or 100) <= (t or 20) end,
    is_interruptible = function() return true end,
    is_spell_learned = function() return true end,
    is_item_ready = function() return false end,
    get_spell_id = function(spell) return spell end,
    is_current_spell = function() return false end,
    swing_time_until = function() return spy.swing_until end,
    get_equipped_item_id = function() return 0 end,
    aoe_target_meets = function() return true end,
    aoe_self_meets = function() return true end,
    AOE_RADIUS = { TARGET_8 = 8, SELF_8 = 8, SELF_10 = 10 },
    SwingDiagnostics = { is_overpower_proc_active = function() return false end },
    same_unit = function(a, b) return a == b end,
    log = function() end,
    get_setting = function() return nil end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            registry_options[name] = options or {}
        end,
    },
    OffensiveDispelDB = {
        is_any_nearby_enemy_under_cc = function() return spy.cc_active end,
        find_best_dispel_target = function() return nil end,
    },
    import_helpers = function()
        return function(spell, target, label)  -- try_cast
                spy.cast_labels[#spy.cast_labels + 1] = tostring(label or spell)
                return true
            end,
            function() return true end,  -- spell_exists
            function() return true end,  -- spell_ready
            function() return 0 end,     -- debuff_remains
            function() return 0 end,     -- debuff_stacks
            function() return 0 end,     -- buff_remains
            function() return 100 end,   -- health_pct
            function() return false end, -- player_control_locked
            function(id)                 -- has_player_buff (records the id)
                spy.ss_buff_id = id
                return spy.ss_buff_up
            end,
            function() return false end, -- has_breakable_cc_nearby
            function() return true end   -- can_attack_target
    end,
}

local NS = _G.EaxRotations

local function find(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. tostring(name))
end

-- ============================================================================
-- LEVELING: disarm settings nil-guard (Critical), PvPCCGate no-halt (Must),
-- Execute dance condition (Must), Execute rage gate, SS buff check, MS stance
-- ============================================================================
local leveling = dofile("EaxRotations/classes/warrior/leveling_vanilla.lua")
assert_true(type(leveling) == "table" and type(leveling.build_state) == "function",
    "leveling_vanilla should return the module table")
local lst = leveling.strategies
assert_true(type(lst) == "table" and #lst > 0, "leveling strategies load")

-- Critical: disarm_matches must not nil-index `settings` (previously crashed)
local disarm = find(lst, "Disarm")
local dctx = {
    in_combat = true, is_pvp = true, in_melee_range = true,
    target = { get_class = function() return 1 end, is_player = function() return true end },
    me = {}, settings = {},
}
local dstate = leveling.build_state(dctx)
assert_true(dstate.disarm_class_ok, "disarm_class_ok should derive from target class")
assert_true(pcall(disarm.matches, dctx, dstate), "disarm matches must not crash (settings nil-index fixed)")
-- on_burst trigger with no burst name -> no match, still no crash
assert_false(disarm.matches(dctx, dstate), "disarm on_burst with no burst name should not match")
-- settings path: pvp_only=false + trigger always -> match
dctx.settings.disarm_pvp_only = false
dctx.settings.disarm_trigger = "always"
dstate = leveling.build_state(dctx)
assert_true(disarm.matches(dctx, dstate), "disarm should match with pvp_only=false + trigger always")

-- Must: PvPCCGate execute must NOT return true (that halted the whole list)
local pvp_cc = find(lst, "PvPCCGate")
assert_false(pvp_cc.execute({}), "PvPCCGate execute must not return true (would halt the priority list)")

-- Must: with the gate active, AoE lanes suppress themselves; single-target lanes don't
spy.cc_active = true
local gctx = { in_combat = true, enemies_count = 2, settings = { use_pvp_cc_gating = true }, target = {}, me = {} }
local gstate = leveling.build_state(gctx)
assert_true(gstate.pvp_cc_gate == true, "build_state should compute the PvP CC gate flag")
assert_false(find(lst, "SweepingStrikes").matches(gctx, gstate), "SweepingStrikes suppressed under PvP CC gate")
assert_false(find(lst, "Whirlwind").matches(gctx, gstate), "Whirlwind suppressed under PvP CC gate")
assert_false(find(lst, "ThunderClap").matches(gctx, gstate), "ThunderClap suppressed under PvP CC gate")
assert_true(find(lst, "Rend").matches(gctx, gstate), "Rend (single-target) unaffected by the AoE gate")
spy.cc_active = false

-- Must: Execute dance only from Defensive; Battle (common leveling stance) casts directly
local exec = find(lst, "Execute")
local ectx = { in_combat = true, target = { get_health_percentage = function() return 15 end }, me = {}, settings = {} }
local est = leveling.build_state(ectx)
est.execute_ready = true
est.rage = 5
assert_false(exec.matches(ectx, est), "Execute needs 15 rage")
est.rage = 20
assert_true(exec.matches(ectx, est), "Execute matches at execute HP with rage")
spy.cast_labels = {}
ectx.stance = 1  -- Battle
assert_true(exec.execute(ectx), "Execute should cast from Battle stance")
assert_true(tostring(spy.cast_labels[1]):find("Execute", 1, true) ~= nil, "Battle stance -> cast Execute directly")
assert_false(tostring(spy.cast_labels[1]):find("Berserker Stance", 1, true) ~= nil,
    "Battle stance -> must NOT waste a GCD dancing to Berserker")
spy.cast_labels = {}
ectx.stance = 2  -- Defensive
assert_true(exec.execute(ectx), "Execute should dance from Defensive stance")
assert_true(tostring(spy.cast_labels[1]):find("Berserker Stance", 1, true) ~= nil,
    "Defensive stance -> dance to Berserker for Execute")

-- Nits: MS Battle-stance gate; SS buff check
local ms = find(lst, "MortalStrike")
assert_false(ms.matches({ stance = 2 }, { mortal_strike_ready = true, in_combat = true, target = {} }),
    "MortalStrike is Battle-only in Vanilla")
assert_true(ms.matches({ stance = 1 }, { mortal_strike_ready = true, in_combat = true, target = {} }),
    "MortalStrike matches in Battle stance")
local lss = find(lst, "SweepingStrikes")
local ssctx = { in_combat = true, target = {}, me = {}, settings = {}, enemies_count = 2 }
local ssstate = leveling.build_state(ssctx)
ssstate.sweeping_strikes_ready = true
assert_true(lss.matches(ssctx, ssstate), "SweepingStrikes matches with 2 targets and no buff")
ssstate.pvp_cc_gate = true
assert_false(lss.matches(ssctx, ssstate), "SweepingStrikes suppressed under gate")

-- ============================================================================
-- FURY: BattleShout/Bloodrage present (Must), stance gates (Must), Slam gates
-- (Must), SS buff check (Must), BerserkerRage OOC (Must), Overpower proc window
-- (Must), Execute rage 15, register guard (Must)
-- ============================================================================
local fury = dofile("EaxRotations/classes/warrior/fury_vanilla.lua")
if type(fury) == "table" and fury.strategies then fury = fury.strategies end
assert_true(type(fury) == "table" and #fury > 0, "fury_vanilla strategies load")
local fury_build_state = registry_options["fury"] and registry_options["fury"].get_state
assert_true(type(fury_build_state) == "function", "fury registers get_state")

local bs = find(fury, "BattleShout")
assert_true(type(bs.matches) == "function", "BattleShout strategy must exist (guide top of priority)")
assert_true(bs.matches({}, { battle_shout_ready = true, has_battle_shout = false, rage = 50 }),
    "BattleShout matches without buff and with rage")
assert_false(bs.matches({}, { battle_shout_ready = true, has_battle_shout = true, rage = 50 }),
    "BattleShout must not recast with buff up")
assert_false(bs.matches({}, { battle_shout_ready = true, has_battle_shout = false, rage = 5 }),
    "BattleShout needs 10 rage")

local br = find(fury, "Bloodrage")
assert_true(type(br.matches) == "function", "Bloodrage strategy must exist (rage opener)")
assert_true(br.matches({ in_combat = true }, { bloodrage_ready = true, rage = 10, hp = 100 }),
    "Bloodrage matches at low rage in combat")
assert_false(br.matches({ in_combat = true }, { bloodrage_ready = true, rage = 25, hp = 100 }),
    "Bloodrage must not fire with 20+ rage")

local brr = find(fury, "BerserkerRage")
assert_false(brr.matches({ in_combat = false }, { bw_ready = true }),
    "BerserkerRage must not pop OOC on the 30s CD")
assert_true(brr.matches({ in_combat = true }, { bw_ready = true }), "BerserkerRage fires in combat")

local pummel = find(fury, "Pummel")
assert_false(pummel.matches({ in_combat = true, stance = 1, target = {} },
    { target_casting = true, pummel_ready = true }), "Pummel is Berserker-only (Battle blocks)")
assert_true(pummel.matches({ in_combat = true, stance = 3, target = {} },
    { target_casting = true, pummel_ready = true }), "Pummel matches in Berserker")
assert_false(pummel.matches({ in_combat = true, stance = 3, target = {} },
    { target_casting = false, pummel_ready = true }), "Pummel needs a casting target")

local fss = find(fury, "SweepingStrikes")
assert_false(fss.matches({ stance = 1 }, { sweeping_strikes_ready = true, target_count = 2, has_sweeping_strikes = true }),
    "SweepingStrikes must not recast while buff is up (30 rage waste)")
assert_false(fss.matches({ stance = 3 }, { sweeping_strikes_ready = true, target_count = 2, has_sweeping_strikes = false }),
    "SweepingStrikes is Battle-only")
assert_true(fss.matches({ stance = 1 }, { sweeping_strikes_ready = true, target_count = 2, has_sweeping_strikes = false }),
    "SweepingStrikes matches in Battle with 2 targets")

local ww = find(fury, "Whirlwind")
assert_false(ww.matches({ stance = 1 }, { whirlwind_ready = true, rage = 50 }),
    "Whirlwind is Berserker-only (Battle blocks)")
assert_true(ww.matches({ stance = 3 }, { whirlwind_ready = true, rage = 50 }),
    "Whirlwind matches in Berserker with rage")

local slam = find(fury, "Slam")
assert_false(slam.matches({}, { slam_ready = true, rage = 30, has_offhand = true, mh_until = 1.0 }),
    "Slam must not fire for DW (clips autos)")
assert_false(slam.matches({}, { slam_ready = true, rage = 30, has_offhand = false, mh_until = 0.5 }),
    "Slam must not fire with the swing landing too early")
assert_false(slam.matches({}, { slam_ready = true, rage = 30, has_offhand = false, mh_until = 2.0 }),
    "Slam must not fire with the swing landing too late")
assert_true(slam.matches({}, { slam_ready = true, rage = 30, has_offhand = false, mh_until = 1.0 }),
    "Slam fires for 2H in the (0.7, 1.5] swing window")

local op = find(fury, "Overpower")
assert_false(op.matches({}, { overpower_ready = true, overpower_window = false }),
    "Overpower must not fire outside the proc window")
assert_true(op.matches({}, { overpower_ready = true, overpower_window = true }),
    "Overpower fires inside the proc window")

-- Overpower window: real CLEU proc tracker is authoritative; the dodge-chance
-- heuristic remains the drivable fallback (battery dodge_proc scenario)
local opctx = { in_combat = true, target = { is_casting = function() return false end, get_dodge_chance = function() return 0 end }, settings = {} }
local opstate = fury_build_state(opctx)
assert_false(opstate.overpower_window, "no proc + zero dodge chance -> no window")
opctx.target.get_dodge_chance = function() return 5 end
opstate = fury_build_state(opctx)
assert_true(opstate.overpower_window, "dodge-chance heuristic fallback drives the window")
NS.SwingDiagnostics.is_overpower_proc_active = function() return true end
opstate = fury_build_state(opctx)
assert_true(opstate.overpower_window, "real CLEU proc tracker opens the window")
NS.SwingDiagnostics.is_overpower_proc_active = function() return false end

-- Must: unguarded register is guarded (reload with no registry -> no crash)
local saved_registry = NS.rotation_registry
NS.rotation_registry = nil
assert_true(pcall(dofile, "EaxRotations/classes/warrior/fury_vanilla.lua"),
    "fury must not crash without rotation_registry")
NS.rotation_registry = saved_registry

-- ============================================================================
-- KEBAB: SS buff id must be the vanilla 12292, not the TBC constant 12328
-- (Must); register guard (Must)
-- ============================================================================
local kebab = dofile("EaxRotations/classes/warrior/kebab_vanilla.lua")
if type(kebab) == "table" and kebab.strategies then kebab = kebab.strategies end
assert_true(type(kebab) == "table" and #kebab > 0, "kebab_vanilla strategies load")

local kss = find(kebab, "SweepingStrikes")
local kctx = {
    enemy_count = 2, rage = 50, stance = 1, target = {}, target_hp = 100,
    settings = {}, in_melee_range = true, has_offhand = true,
    has_breakable_cc_nearby = false, player_control_locked = false,
}
spy.ss_buff_id = nil
spy.ss_buff_up = false
assert_true(kss.matches(kctx), "kebab SweepingStrikes matches with 2 enemies and no buff")
assert_eq(spy.ss_buff_id, 12292,
    "kebab must check the VANILLA SS buff id (12292), not the TBC constant 12328")
spy.ss_buff_up = true
assert_false(kss.matches(kctx), "kebab must skip SweepingStrikes while the buff is up")
spy.ss_buff_up = false

NS.rotation_registry = nil
assert_true(pcall(dofile, "EaxRotations/classes/warrior/kebab_vanilla.lua"),
    "kebab must not crash without rotation_registry")
NS.rotation_registry = saved_registry

-- ============================================================================
-- PROTECTION: TC debuff/rage gates (Must), Taunt threat gate (Must),
-- ChallengingShout threat gate (Must), register guard (Must)
-- ============================================================================
local prot = dofile("EaxRotations/classes/warrior/protection_vanilla.lua")
if type(prot) == "table" and prot.strategies then prot = prot.strategies end
assert_true(type(prot) == "table" and #prot > 0, "protection_vanilla strategies load")

local tc = find(prot, "ThunderClap")
spy.debuff_remains = 0
assert_true(tc.matches({ target = {}, stance = 1, rage = 100, me = {}, settings = {} }),
    "ThunderClap matches with fresh debuff + rage in Battle")
spy.debuff_remains = 8
assert_false(tc.matches({ target = {}, stance = 1, rage = 100, me = {}, settings = {} }),
    "ThunderClap must not recast while the debuff is up (20 rage burn)")
spy.debuff_remains = 0
assert_false(tc.matches({ target = {}, stance = 1, rage = 10, me = {}, settings = {} }),
    "ThunderClap needs 20 rage")
spy.debuff_remains = 0

local taunt = find(prot, "Taunt")
assert_false(taunt.matches({ target = {}, me = {}, has_aggro = true, settings = {} }),
    "Taunt must not fire on a target already tanked")
assert_true(taunt.matches({ target = {}, me = {}, has_aggro = false, settings = {} }),
    "Taunt fires on threat loss")

local cs = find(prot, "ChallengingShout")
assert_false(cs.matches({ target = {}, me = {}, enemy_count = 3, has_aggro = true, settings = {} }),
    "ChallengingShout must not fire while holding aggro (wasted at pull)")
assert_true(cs.matches({ target = {}, me = {}, enemy_count = 3, has_aggro = false, settings = {} }),
    "ChallengingShout fires on threat loss with 3+ enemies")
assert_false(cs.matches({ target = {}, me = {}, enemy_count = 2, has_aggro = false, settings = {} }),
    "ChallengingShout needs 3+ enemies")

NS.rotation_registry = nil
assert_true(pcall(dofile, "EaxRotations/classes/warrior/protection_vanilla.lua"),
    "protection must not crash without rotation_registry")
NS.rotation_registry = saved_registry

-- ============================================================================
-- ARMS: Sunder Armor must be stance-free in Classic (Must) — previously
-- DEFENSIVE-gated, so the lane was dead whenever enabled in Battle stance
-- ============================================================================
local arms = dofile("EaxRotations/classes/warrior/arms_vanilla.lua")
if type(arms) == "table" and arms.strategies then arms = arms.strategies end
assert_true(type(arms) == "table" and #arms > 0, "arms_vanilla strategies load")

local sunder = find(arms, "SunderArmor")
assert_true(sunder.matches({ target = {}, stance = 1, rage = 30, target_armor = 1000, target_hp = 100, me = {}, settings = { use_sunder_armor = true } }),
    "Sunder Armor is stance-free in Classic: must match in Battle stance (was DEFENSIVE-gated)")
assert_false(sunder.matches({ target = {}, stance = 1, rage = 30, target_armor = 1000, target_hp = 100, me = {}, settings = { use_sunder_armor = false } }),
    "Sunder Armor still honors the use_sunder_armor toggle")
assert_false(sunder.matches({ target = {}, stance = 1, rage = 10, target_armor = 1000, target_hp = 100, me = {}, settings = { use_sunder_armor = true } }),
    "Sunder Armor still needs 15 rage")

print("PASS test_warrior_vanilla_live_fixes")
