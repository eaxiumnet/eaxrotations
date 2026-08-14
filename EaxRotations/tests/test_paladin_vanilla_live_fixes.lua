-- test_paladin_vanilla_live_fixes.lua — Paladin Vanilla live-fix regression tests.
-- WHAT:  Validates the WAVE 1.3 paladin vanilla fixes (holy BoW/greater-blessing,
--        protection seal ping-pong + Consecration gate + CC proximity, retribution
--        fleeing lane, leveling judgement seal requirement) via matcher asserts.
-- WHEN:  Standalone (lua test_paladin_vanilla_live_fixes.lua); registered in
--        run_rotation_tests.lua (Wave 1.5 close-out).
-- WHY:   Proves each fixed behavior at the matches(ctx, state) level.
-- SAFETY: Pure mocks; no real API calls.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- Shared-module stubs (mirror test_paladin_vanilla_nil_guards.lua).
package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {}, MANA_POTION_IDS = {} }
package.loaded["shared/tbc_data_sylvanas"] =
    { ITEMS = { healthstones = {}, potions = {} }, SPELLS = {} }
package.loaded["shared/leveling_sylvanas"] = {
    create_context_guard = function() return function() return true end end,
    build_common_state = function(context, state)
        if not context or not state then return state end
        state.in_combat = context.in_combat or false
        state.mana_pct = context.mana_pct or 100
        state.hp = context.hp or 100
        state.enemies = context.enemies_count or 0
        state.target = context.target
        state.is_moving = context.is_moving or false
    end,
    create_wand_matches = function() return function() return false end end,
    execute_wand = function() return false end,
}

-- Per-buff remains switches for the holy blessing test.
local light_remains, wisdom_remains, kings_remains = 999, 0, 999

local function set_remains(light, wisdom, kings)
    light_remains, wisdom_remains, kings_remains = light, wisdom, kings
end

local _mock_time = 0
local _spell_exists_result = false

local _heal_entries = nil

local NS = {
    CLASS_ID = { PALADIN = 2, PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9, WARRIOR = 1, ROGUE = 4, HUNTER = 3, DRUID = 11 },
    POWER_MANA = 0,
    PLAYER_UNIT = { _mock = true, get_class = function() return 2 end },
    PaladinSpells = {
        BlessingOfLight = 19977, BlessingOfWisdom = 19742, BlessingOfKings = 20217,
        GreaterBlessingOfLight = 27145, GreaterBlessingOfWisdom = 27143, GreaterBlessingOfKings = 25898,
        HolyLight = 635, FlashOfLight = 19750, HolyShock = 20473, LayOnHands = 733,
        DivineShield = 642, Cleanse = 4987, Purify = 1152, DivineFavor = 20216,
        Consecration = 26573, HolyWrath = 2812, Exorcism = 879, HammerOfWrath = 24275,
        HammerOfJustice = 853, Judgement = 20271, RighteousFury = 25780, HolyShield = 20925,
        DevotionAura = 465, ConcentrationAura = 19746, SanctityAura = 20218,
        SealRighteousness = 21084, SealOfWisdom = 20166, SealCommand = 20375,
        SealOfLight = 20165, SealOfJustice = 20164, SealOfTheCrusader = 20164,
        BlessingOfProtection = 1022, BlessingOfFreedom = 1044, BlessingOfSanctuary = 20911,
        RetributionAura = 7294, SealOfCommand = 20375, SealCrusader = 20162,
        SealWisdom = 20166, Repentance = 20066, DivineProtection = 498,
    },
    PaladinHealing = {
        scan_healing_targets = function()
            if not _heal_entries then return {}, 0 end
            return _heal_entries, #_heal_entries
        end,
    },
    GetPlayer = function() return NS.PLAYER_UNIT end,
    spell_action = function(ids, label) return type(ids) == "table" and ids[1] or ids end,
    spell_exists = function(spell) return _spell_exists_result end,
    spell_ready = function() return true end,
    try_cast = function() return true end,
    buff_up = function() return false end,
    buff_remains = function(unit, ids)
        if type(ids) == "table" then
            for _, id in ipairs(ids) do
                if id == 19979 or id == 19978 or id == 19977 then return light_remains end
                if id == 20217 then return kings_remains end
                if id == 19742 then return wisdom_remains end
            end
        end
        return 0
    end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    has_player_buff = function() return false end,
    has_player_debuff = function() return false end,
    has_target_debuff = function() return false end,
    healing_get_lowest_hp = function(entries, count, threshold)
        if not entries or count == 0 then return nil end
        local best = entries[1]
        for i = 2, count do
            local e = entries[i]
            if (e.effective_hp or 100) < (best.effective_hp or 100) then best = e end
        end
        return best
    end,
    healing_get_tank = function(entries, count)
        if not entries then return nil end
        for i = 1, count do if entries[i].is_tank then return entries[i] end end
        return nil
    end,
    mana_pct = function() return 80 end,
    unit_health_pct = function(unit) return 100 end,
    same_unit = function(a, b) return a == b end,
    not_same_unit = function(a, b) return a ~= b end,
    unit_distance = nil,  -- omitted on purpose: exercises the get_position path
    time_now = function() _mock_time = _mock_time + 1 return _mock_time end,
    is_item_ready = function() return false end,
    use_item_by_id = function() return true end,
    get_any_setting = function() return false end,
    log = function() end,
    rotation_registry = {
        _reg = {},
        register = function(self, key, strategies, opts)
            self._reg[key] = { strategies = strategies, opts = opts }
        end,
    },
}

_G.core = { time = function() return 0 end, log = function() end }
_G.EaxRotations = NS

local function find_strategy(strats, name)
    for i = 1, #strats do
        if strats[i].name == name then return strats[i] end
    end
    error("strategy not found: " .. name)
end

-- Plain-style vanilla files register get_state via the registry and return
-- their bare strategies table; resolve both from the registration.
local function spec_parts(key)
    local reg = NS.rotation_registry._reg[key]
    if not reg then error("no registered rotation: " .. key) end
    return reg.strategies, reg.opts.get_state
end

print("=== test_paladin_vanilla_live_fixes ===")

-- ============================================================================
-- protection_vanilla — seal ping-pong / wisdom-judge gate
-- ============================================================================
dofile("EaxRotations/classes/paladin/protection_vanilla.lua")
local prot_strats, prot_build_state = spec_parts("protection")
local prot_judgement = find_strategy(prot_strats, "Judgement")
local prot_sor = find_strategy(prot_strats, "SealRighteousness")
local prot_sow = find_strategy(prot_strats, "SealOfWisdom")
local prot_conc = find_strategy(prot_strats, "Consecration")
local combat_ctx = { in_combat = true, has_valid_enemy_target = true, target = {}, me = {}, settings = {} }

assert_false(prot_sor.matches(combat_ctx, { has_seal = false, has_seal_wisdom = true }),
    "SoR lane must not stomp a live Seal of Wisdom (ping-pong fix)")
assert_false(prot_sow.matches(combat_ctx, { has_seal = false, has_seal_wisdom = true, seal_of_wisdom_ready = true, mana_pct = 20 }),
    "Seal of Wisdom lane must not recast when Wisdom is already up")
assert_true(prot_judgement.matches(combat_ctx, { judgement_ready = true, has_seal = false, has_seal_wisdom = true }),
    "Judgement must fire with Seal of Wisdom up (Judgement of Wisdom mana engine)")
assert_false(prot_judgement.matches(combat_ctx, { judgement_ready = true, has_seal = false, has_seal_wisdom = false }),
    "Judgement must not fire seal-less")
assert_false(prot_sow.matches(combat_ctx, { has_seal = true, has_seal_wisdom = false, seal_of_wisdom_ready = true, mana_pct = 20 }),
    "Seal of Wisdom must not stomp a live Seal of Righteousness")
print("  PASS: protection seal ping-pong + wisdom-judge gate")

-- Consecration gate (fixed to match its comment)
assert_false(prot_conc.matches(combat_ctx, { consecration_ready = true, mana_pct = 100, cc_nearby = false, enemy_count = 1, consecration_remains = 0 }),
    "Consecration must not open on 1-2 mobs when not ticking")
assert_true(prot_conc.matches(combat_ctx, { consecration_ready = true, mana_pct = 100, cc_nearby = false, enemy_count = 1, consecration_remains = 5 }),
    "Consecration must refresh a ticking one on few targets")
assert_true(prot_conc.matches(combat_ctx, { consecration_ready = true, mana_pct = 100, cc_nearby = false, enemy_count = 4, consecration_remains = 0 }),
    "Consecration must cast freely on 3+ targets")
print("  PASS: protection Consecration gate direction")

-- CC proximity via real positions (get_position path; no NS.unit_distance)
local function prot_build(ctx)
    local ok, st = pcall(prot_build_state, ctx)
    if not ok then error("protection build_state failed: " .. tostring(st)) end
    return st
end
NS.debuff_up = function() return true end  -- every enemy "has CC" for the scan
local me = { is_valid = function() return true end, get_creature_type = function() return nil end }
local far_target = { get_position = function() return { x = 40, y = 40, z = 0 } end, is_casting = function() return false end }
local far_enemy = { get_position = function() return { x = 70, y = 70, z = 0 } end }
local near_enemy = { get_position = function() return { x = 40, y = 41, z = 0 } end }  -- ~1 yd from target
local s_far = prot_build({ me = me, target = far_target, enemies = { far_enemy }, in_combat = true, has_valid_enemy_target = true, settings = {}, hp = 100, mana_pct = 100 })
assert_false(s_far.cc_nearby, "distant CC'd mob (30 yd) must not count as nearby")
local s_near = prot_build({ me = me, target = far_target, enemies = { near_enemy }, in_combat = true, has_valid_enemy_target = true, settings = {}, hp = 100, mana_pct = 100 })
assert_true(s_near.cc_nearby, "CC'd mob within 15 yd must count as nearby")
NS.debuff_up = function() return false end
print("  PASS: protection CC proximity uses get_position (not nil .x/.y)")

-- ============================================================================
-- holy_vanilla — Blessing of Wisdom mana-user branch + greater-blessing fallback
-- ============================================================================
dofile("EaxRotations/classes/paladin/holy_vanilla.lua")
local holy_strats, holy_build_state = spec_parts("holy")

local unit_a = { get_class = function() return 5 end }  -- priest (mana user)
local unit_tank = { get_class = function() return 1 end }  -- warrior (not in MANA_CLASS_IDS)

_heal_entries = {
    { unit = unit_a, hp = 55, effective_hp = 55, max_hp = 10000, deficit = 45, is_tank = false, is_player = false, role = "dps" },
    { unit = unit_tank, hp = 30, effective_hp = 30, max_hp = 10000, deficit = 70, is_tank = true, is_player = false, role = "tank" },
}
-- Tank has Blessing of Light + Kings; nobody has Wisdom → BoW branch must fire.
set_remains(999, 0, 999)
local hctx = { in_combat = true, mana_pct = 80, hp = 100, target = nil, is_moving = false, settings = {} }
local hstate = holy_build_state(hctx)
assert_eq(hstate.blessing_spell, 19742, "BoW branch must pick Blessing of Wisdom for a mana-user entry")
assert_eq(hstate.blessing_target, _heal_entries[1], "BoW branch must target the mana-user entry")

-- Non-mana-class (warrior) non-tank entry must NOT get Wisdom... but with no
-- class API the non-tank fallback applies; here unit has get_class → warrior
-- is excluded (falls through to Kings below).
local unit_b = { get_class = function() return 1 end }
_heal_entries = {
    { unit = unit_b, hp = 55, effective_hp = 55, max_hp = 10000, deficit = 45, is_tank = false, is_player = false, role = "dps" },
    { unit = unit_tank, hp = 30, effective_hp = 30, max_hp = 10000, deficit = 70, is_tank = true, is_player = false, role = "tank" },
}
set_remains(999, 0, 0)  -- Wisdom AND Kings missing; warrior should skip Wisdom → Kings
local hstate2 = holy_build_state(hctx)
assert_eq(hstate2.blessing_spell, 20217, "non-mana-class entry must fall through to Blessing of Kings")
print("  PASS: holy Blessing of Wisdom mana-user branch")

-- Greater-blessing fallback when the TBC-rank spell is unlearned. The
-- resolver runs at module load, so the learned case needs a fresh dofile.
local many_entries = {}
for i = 1, 5 do
    many_entries[i] = { unit = { get_class = function() return 5 end }, hp = 90, effective_hp = 90, max_hp = 10000, deficit = 10, is_tank = false, is_player = false, role = "dps" }
end
many_entries[1].is_tank = true  -- tank slot carries Blessing of Light branch
_heal_entries = many_entries
set_remains(0, 999, 999)  -- tank missing Blessing of Light → greater branch fires
_spell_exists_result = false  -- TBC-rank Greater Blessing unlearned in Classic
local hstate3 = holy_build_state(hctx)
assert_eq(hstate3.blessing_spell, 19979, "unlearned TBC Greater Blessing must fall back to local vanilla rank")

_spell_exists_result = true  -- learned: reload resolves SPELLS.GreaterBlessingOfLight
NS.rotation_registry._reg["holy"] = nil
dofile("EaxRotations/classes/paladin/holy_vanilla.lua")
local _, holy_build_state2 = spec_parts("holy")
local hstate4 = holy_build_state2(hctx)
assert_eq(hstate4.blessing_spell, 27145, "learned TBC Greater Blessing must be preferred")
print("  PASS: holy greater-blessing resolution (spell_exists gate)")
_heal_entries = nil
set_remains(999, 999, 999)
_spell_exists_result = false

-- ============================================================================
-- retribution_vanilla — fleeing lane real signal + JoW low-mana band
-- ============================================================================
local ret = dofile("EaxRotations/classes/paladin/retribution_vanilla.lua")
local ret_strats = ret.strategies or ret
local flee_lane = find_strategy(ret_strats, "Ret_HammerWrath_FleeingPvP")
local sow_lane = find_strategy(ret_strats, "Ret_SealWisdom_Emergency")

assert_true(flee_lane.matches({ is_pvp = true, target = {}, settings = {} }, { target_fleeing = true, target_hp_pct = 15 }),
    "fleeing lane must match on the context fleeing flag (harness contract)")
assert_false(flee_lane.matches({ is_pvp = true, target = {}, settings = {} }, { target_fleeing = false, target_hp_pct = 15 }),
    "fleeing lane must not match when not fleeing")

-- Distance-delta fleeing via build_state (the live signal)
local function ret_build_state(ctx)
    local ok, st = pcall(ret.build_state, ctx)
    if not ok then error("retribution build_state failed: " .. tostring(st)) end
    return st
end
local ret_me = { get_health_percentage = function() return 100 end, get_class = function() return 2 end }
local ret_target = { get_health_percentage = function() return 15 end }
local ret_ctx = { me = ret_me, target = ret_target, hp = 100, mana_pct = 100, enemy_count = 1, settings = {}, is_pvp = true }
ret_ctx.target_distance = 10
assert_false(ret_build_state(ret_ctx).target_fleeing, "first distance sample cannot be fleeing")
ret_ctx.target_distance = 20
assert_true(ret_build_state(ret_ctx).target_fleeing, "distance increasing past melee range must read as fleeing")
print("  PASS: retribution fleeing lane real signal (distance delta)")

assert_true(sow_lane.matches({ settings = {} }, { mana_pct = 30, has_wisdom = false }),
    "Seal of Wisdom must apply in the 18-45% band (JoW engine)")
assert_false(sow_lane.matches({ settings = {} }, { mana_pct = 50, has_wisdom = false }),
    "Seal of Wisdom must stay silent above the low-mana band")
print("  PASS: retribution JoW low-mana band")

-- ============================================================================
-- leveling_vanilla — judgement/damage lanes require a live seal
-- ============================================================================
local lvl = dofile("EaxRotations/classes/paladin/leveling_vanilla.lua")
local lvl_strats = lvl.strategies or lvl
local lvl_judgement = find_strategy(lvl_strats, "Judgement")
local lvl_how = find_strategy(lvl_strats, "HammerOfWrath")
local lvl_conc = find_strategy(lvl_strats, "Consecration")
local lvl_hl = find_strategy(lvl_strats, "HolyLight")
local lvl_hs = find_strategy(lvl_strats, "HolyShield")

local lctx = { in_combat = true, target = {}, enemies_count = 3, hp = 100, mana_pct = 100, is_moving = false, settings = {} }
-- Seal-less with a castable seal: damage lanes must yield so the Seal lane
-- (last, pinned) gets the GCD instead of starving.
assert_false(lvl_judgement.matches(lctx, { target = {}, in_combat = true, judgement_ready = true, has_any_seal = false, selected_seal = 20375 }),
    "Judgement must not fire seal-less while a seal is castable (Seal lane would starve)")
assert_true(lvl_judgement.matches(lctx, { target = {}, in_combat = true, judgement_ready = true, has_any_seal = true }),
    "Judgement must fire with a live seal")
assert_true(lvl_judgement.matches(lctx, { target = {}, in_combat = true, judgement_ready = true, has_any_seal = false, selected_seal = nil }),
    "Judgement must still fire when no seal can be cast (nothing to yield to)")
assert_false(lvl_how.matches(lctx, { target = {}, in_combat = true, hammer_wrath_ready = true, has_any_seal = false, target_hp_pct = 10, selected_seal = 20375 }),
    "Hammer of Wrath must not fire seal-less at execute range while a seal is castable")
assert_true(lvl_how.matches(lctx, { target = {}, in_combat = true, hammer_wrath_ready = true, has_any_seal = true, target_hp_pct = 10 }),
    "Hammer of Wrath must fire at execute range with a live seal")
assert_false(lvl_how.matches(lctx, { target = {}, in_combat = true, hammer_wrath_ready = true, has_any_seal = true, target_hp_pct = 30 }),
    "Hammer of Wrath must respect the execute band via state.target_hp_pct")
assert_false(lvl_conc.matches(lctx, { target = {}, in_combat = true, consecration_ready = true, has_any_seal = false, enemies = 3, is_moving = false, selected_seal = 20375 }),
    "Consecration must not fire seal-less while a seal is castable")
assert_true(lvl_conc.matches(lctx, { target = {}, in_combat = true, consecration_ready = true, has_any_seal = true, enemies = 3, is_moving = false }),
    "Consecration must fire with a live seal on 2+ mobs")
print("  PASS: leveling judgement/damage seal-up gates")

assert_false(lvl_hl.matches(lctx, { in_combat = true, holy_light_ready = true, hp = 30, is_moving = true }),
    "Holy Light must not cast while moving (2.5s cast)")
assert_true(lvl_hl.matches(lctx, { in_combat = true, holy_light_ready = true, hp = 30, is_moving = false }),
    "Holy Light must cast when stationary at low HP")
print("  PASS: leveling Holy Light moving gate")

assert_true(lvl_hs.matches(lctx, { in_combat = true, holy_shield_ready = true, hp = 100, enemies = 3 }),
    "Holy Shield must cast proactively while healthy")
assert_false(lvl_hs.matches(lctx, { in_combat = true, holy_shield_ready = true, hp = 50, enemies = 3 }),
    "Holy Shield must not be gated on already-damaged (proactive direction)")
print("  PASS: leveling Holy Shield proactive direction")

print("PASS test_paladin_vanilla_live_fixes")
