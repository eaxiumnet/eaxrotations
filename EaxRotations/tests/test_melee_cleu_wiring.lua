-- test_melee_cleu_wiring.lua — Validates CLEU SwingDiagnostics wiring in melee specs.
-- WHAT:  Confirms Enhancement Shaman + 3 Warrior specs prefer CLEU swing timer with safe fallback.
-- WHEN:  run via run_rotation_tests.lua or standalone.
-- WHY:   CLEU is additive; must not regress native-timer behavior when CLEU absent.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
local function assert_nil(v, label) if v ~= nil then error((label or "assert_nil failed") .. ": expected nil, got " .. tostring(v), 2) end end

-- ============================================================================
-- Test helpers
-- ============================================================================
local function make_base_NS()
    return {
        log = function() end,
        time_now = function() return 1000 end,
        PLAYER_UNIT = {},
        GetPlayer = function() return {} end,
        SwingDiagnostics = nil,
        buff_up = function() return false end,
        debuff_remains = function() return 0 end,
        debuff_stacks = function() return 0 end,
        get_debuff_stacks = function() return 0 end,
        buff_stacks = function() return 0 end,
        spell_ready = function() return false end,
        cooldown_remains = function() return 99 end,
        broken_api_throttled = function() return false end,
        swing_time_until = function() return 999 end,
        swing_progress = function() return 0 end,
        get_time_until_swing = function() return 0 end,
        get_time_until_oh_swing = function() return 999 end,
        rotation_registry = {
            register = function(self, name, strategies, opts)
                _G._test_captured_get_state = opts and opts.get_state
                _G._test_captured_context_builder = opts and opts.context_builder
            end,
        },
        register_state_builder = function(spec, fn)
            _G._test_captured_state_builder = fn
        end,
        register_strategy = function() end,
    }
end

local function reset_captures()
    _G._test_captured_get_state = nil
    _G._test_captured_state_builder = nil
    _G._test_captured_context_builder = nil
end

-- ============================================================================
-- Enhancement Shaman
-- ============================================================================
reset_captures()
_G.EaxRotations = make_base_NS()
_G.EaxRotations.ShamanSpells = {
    LightningShield = {324}, WaterShield = {33736},
    ShamanisticRage = {30823}, Bloodlust = {2825},
    Stormstrike = {17364}, FlameShock = {8050},
    EarthShock = {8042}, FrostShock = {8056},
    ChainLightning = {421}, LightningBolt = {403},
    WindfuryTotem = {8512}, GraceOfAirTotem = {8835},
    StrengthOfEarthTotem = {8075}, StoneskinTotem = {8155},
    ManaSpringTotem = {5675}, HealingStreamTotem = {5394},
    SearingTotem = {3599}, MagmaTotem = {8190},
    FireNovaTotem = {1535}, ManaTideTotem = {16190},
    NaturesSwiftness = {16188}, LesserHealingWave = {8004},
    ChainHeal = {1064}, GroundingTotem = {8177},
    WindfuryWeapon = 8232, FlametongueWeapon = 8024, RockbiterWeapon = 8017,
    TotemicCall = {36936}, GiftOfTheNaaru = {28880},
    Purge = {370},
}
_G.EaxRotations.unit_mana_pct = function() return 100 end
_G.EaxRotations.unit_health_pct = function() return 100 end
_G.EaxRotations.game_time_ms = function() return 0 end
_G.EaxRotations.try_cast = function() return true end
_G.EaxRotations.is_spell_learned = function() return true end
_G.EaxRotations.get_totem_info = function() return { have_totem = false } end
_G.EaxRotations.debuff_up = function() return false end
_G.core = {
    spell_book = { get_totem_info = function() return { have_totem = false } end },
    object_manager = { get_visible_objects = function() return {} end },
}
package.loaded['shared/potion_helper_sylvanas'] = { try_use_potion = function() return false end, MANA_POTION_IDS = {} }

_G.EaxRotations.SwingDiagnostics = {
    is_active = function() return true end,
    get_swing_remains = function() return 1.5 end,
    register_seals = function() end,
}
dofile('EaxRotations/classes/shaman/enhancement_sylvanas.lua')
local enh_build_state = _G._test_captured_get_state
assert_true(enh_build_state, 'Enhancement build_state captured')
local enh_state1 = enh_build_state({ settings = {}, target = {}, me = { is_moving = function() return false end } })
assert_eq(enh_state1.swing_remains, 1.5, 'Enhancement: CLEU swing_remains consumed')

_G.EaxRotations.SwingDiagnostics.get_swing_remains = function() return nil end
_G.EaxRotations.get_time_until_swing = function() return 2.5 end
local enh_state2 = enh_build_state({ settings = {}, target = {}, me = { is_moving = function() return false end } })
assert_eq(enh_state2.swing_remains, 2.5, 'Enhancement: falls back to native get_time_until_swing')
print('  [ PASS ] Enhancement Shaman CLEU wiring')

-- ============================================================================
-- Arms Warrior
-- ============================================================================
reset_captures()
_G.EaxRotations = make_base_NS()
_G.EaxRotations.WarriorSpells = {
    Execute = 5308, BattleShout = 6673, VictoryRush = 34428,
    MortalStrike = 12294, Overpower = 7384, Slam = 1464,
    HeroicStrike = 78, Hamstring = 1715, Charge = 100,
    Cleave = 845, BerserkerRage = 18499, DeathWish = 12292,
    Whirlwind = 1680, SweepingStrikes = 12328, DemoralizingShout = 1160,
    ThunderClap = 6343, SpellReflection = 23920, Retaliation = 20230,
    ShieldWall = 871, IntimidatingShout = 5246, Disarm = 676,
    Intercept = {20252, 20616, 20617, 25275}, PiercingHowl = 12323,
    CommandingShout = 469, Rend = 772, SunderArmor = 7386,
    BattleStance = 2457, BerserkerStance = 2458, DefensiveStance = 71,
    Bloodrage = 2687, Recklessness = 1719,
}
_G.EaxRotations.WarriorConstants = {
    STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
}
_G.EaxRotations.is_execute_phase = function(hp, threshold) return hp and hp <= (threshold or 20) end
_G.EaxRotations.get_setting = function(key, default) return default end

_G.EaxRotations.SwingDiagnostics = {
    is_active = function() return true end,
    get_swing_remains = function() return 1.5 end,
    register_seals = function() end,
}
local arms_result = dofile('EaxRotations/classes/warrior/arms_sylvanas.lua')
local arms_build_state = _G._test_captured_get_state
assert_true(arms_build_state, 'Arms build_state captured')
local arms_state1 = arms_build_state({ target = {}, me = {} })
assert_eq(arms_state1.mh_until, 1.5, 'Arms: CLEU mh_until consumed')

_G.EaxRotations.SwingDiagnostics.get_swing_remains = function() return nil end
_G.EaxRotations.swing_time_until = function() return 2.5 end
local arms_state2 = arms_build_state({ target = {}, me = {} })
assert_eq(arms_state2.mh_until, 2.5, 'Arms: falls back to native swing_time_until')
print('  [ PASS ] Arms Warrior CLEU wiring')

-- ============================================================================
-- Fury Warrior
-- ============================================================================
reset_captures()
_G.EaxRotations = make_base_NS()
_G.EaxRotations.WarriorSpells = {
    Execute = 5308, Slam = 1464, HeroicStrike = 78,
    DeathWish = 12292, Hamstring = 1715, Intercept = 20252,
    Pummel = 6552, Bloodthirst = 23881, Whirlwind = 1680,
    BerserkerStance = 2457, BattleShout = 6673, CommandingShout = 469,
    BerserkerRage = 18499, Rampage = 29801, SweepingStrikes = 12328,
    Cleave = 845, BattleStance = 2458, Overpower = 7384,
    Rend = 772, SunderArmor = 7386, DemoralizingShout = 1160,
    ThunderClap = 6343, Charge = 100, VictoryRush = 34428,
}
_G.EaxRotations.WarriorConstants = {
    STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
}
_G.EaxRotations.is_execute_phase = function(hp, threshold) return hp and hp <= (threshold or 20) end
_G.EaxRotations.get_tactical_mastery_cap = function() return 25 end

_G.EaxRotations.SwingDiagnostics = {
    is_active = function() return true end,
    get_swing_remains = function() return 1.5 end,
    register_seals = function() end,
}
local fury_result = dofile('EaxRotations/classes/warrior/fury_sylvanas.lua')
-- Canonical return: { strategies = {...}, build_state = fn }
local fury_build_state = (type(fury_result) == "table" and fury_result.build_state) or _G._test_captured_get_state
assert_true(fury_build_state, 'Fury build_state captured')
local fury_state1 = fury_build_state({ target = {}, me = {} })
assert_eq(fury_state1.mh_until, 1.5, 'Fury: CLEU mh_until consumed')

_G.EaxRotations.SwingDiagnostics.get_swing_remains = function() return nil end
_G.EaxRotations.swing_time_until = function() return 2.5 end
local fury_state2 = fury_build_state({ target = {}, me = {} })
assert_eq(fury_state2.mh_until, 2.5, 'Fury: falls back to native swing_time_until')
print('  [ PASS ] Fury Warrior CLEU wiring')

-- ============================================================================
-- Kebab Warrior
-- ============================================================================
reset_captures()
_G.EaxRotations = make_base_NS()
_G.EaxRotations.CLASS_ID = { WARRIOR = 1 }
_G.EaxRotations.WarriorSpells = {
    Execute = 5308, BerserkerStance = 2458, SweepingStrikes = 12328,
    MortalStrike = 12294, Whirlwind = 1680, Overpower = 7384,
    BattleShout = 6673, CommandingShout = 469, HeroicStrike = 78, Cleave = 845,
}
_G.EaxRotations.WarriorConstants = {
    STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
    BUFF_ID = { SWEEPING_STRIKES = 12328 },
    SUNDER_DEBUFF = {}, THUNDER_CLAP_DEBUFF = {}, DEMO_SHOUT_DEBUFF = {}, BATTLE_SHOUT_IDS = {},
}
_G.EaxRotations.GetPlayer = function() return { get_class = function() return 1 end } end
_G.EaxRotations.import_helpers = function()
    return function() return true end,
           function() return true end,
           function() return true end,
           function() return 0 end,
           function() return 0 end,
           function() return 0 end,
           function() return 100 end,
           function() return false end,
           function() return false end,
           function() return false end,
           function() return true end
end
_G.EaxRotations.is_execute_phase = function(hp, threshold) return (hp or 100) <= (threshold or 20) end
_G.EaxRotations.cooldown_remains = function() return 0 end
_G.EaxRotations.get_spell_id = function(spell) return spell end
_G.EaxRotations.is_current_spell = function() return false end
package.loaded['common/enums'] = { class_id = { WARRIOR = 1 } }

_G.EaxRotations.SwingDiagnostics = {
    is_active = function() return true end,
    get_swing_remains = function() return 1.5 end,
    register_seals = function() end,
}
local kebab_result = dofile('EaxRotations/classes/warrior/kebab_sylvanas.lua')
-- Canonical return: { strategies = {...}, build_state = fn }
local kebab_build_state = (type(kebab_result) == "table" and kebab_result.build_state) or _G._test_captured_get_state
assert_true(kebab_build_state, 'Kebab build_state captured')
local kebab_ctx1 = { settings = {}, target = {} }
kebab_build_state(kebab_ctx1)
assert_eq(kebab_ctx1.mh_remain, 1.5, 'Kebab: CLEU mh_remain consumed')

_G.EaxRotations.SwingDiagnostics.get_swing_remains = function() return nil end
_G.EaxRotations.get_time_until_swing = function() return 2.5 end
local kebab_ctx2 = { settings = {}, target = {} }
kebab_build_state(kebab_ctx2)
assert_eq(kebab_ctx2.mh_remain, 2.5, 'Kebab: falls back to native get_time_until_swing')
print('  [ PASS ] Kebab Warrior CLEU wiring')

print('PASS test_melee_cleu_wiring')
