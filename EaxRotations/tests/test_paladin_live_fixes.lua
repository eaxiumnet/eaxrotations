-- test_paladin_live_fixes.lua — regression for verified live-correctness fixes
-- in the three TBC paladin specs (holy / protection / retribution).
-- WHAT:  covers the audit fixes:
--   holy:        TankPreHeal overheal gate uses the Holy Light rank locals (the
--                ACTION table has no "HolyLight" key, so HL pre-heals were gated
--                as 1.5s FlashOfLight); entry_is_mana_user now reads fields that
--                build_healing_entries actually sets (class via get_class) so the
--                Blessing of Wisdom refresh loop is reachable.
--   protection:  CC-proximity check uses real distances (NS.unit_distance /
--                get_position) instead of the always-true .x/.y nil math that
--                globally gated Avenger's Shield/Consecration; build_state is
--                frame-cached (safe_state-wrapped on cache hits); Consecration
--                dead-debuff check documented+kept inert; HolyShock DSL upper HP
--                bound; SealOfCommandAoE no longer overwrites the JoW SoW.
--   retribution: Seal of the Martyr path reachable (NS.unit_faction is mock-only;
--                availability is now detected via is_spell_learned/ret_use_martyr);
--                SealTwistBlood twists Martyr when Blood is unavailable; the prep
--                twist + SoR filler no longer shadow the martyr path; build_state
--                frame cache; context.mana fallback removed.
-- WHEN:  standalone: lua EaxRotations/tests/test_paladin_live_fixes.lua
-- WHY:   each fix was verified dead/broken against the production API surface;
--        these pins keep the fixes from regressing.
-- SAFETY: pure unit tests with a mocked NS; not registered in any runner.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed: expected false", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- ============================================================================
-- Mock NS — one surface serves all three paladin specs.
-- ============================================================================
local captured = {}          -- rotation_registry capture: spec -> strategies
local overhear_calls = {}    -- gate_overheal spy entries { key, cast_time, spell_id }
local gate_block_key = nil   -- when set, gate_overheal blocks that key
local spell_ready_count = 0  -- build_state cache spy
local last_cast = nil        -- try_cast spy
local learned_map = { [31892] = true, [348700] = true }  -- is_spell_learned bank
local cc_units = {}          -- units flagged CC'd (debuff_up spy)
local unit_distance_fn = nil -- NS.unit_distance spy (set per test)
local mock_time = 1000        -- NS.time_now spy (advanced to clear 3s throttles)

local player_unit = { _mock = true, get_class = function() return 2 end }
local mage_unit = { _mock = true, get_class = function() return 8 end }
local warrior_unit = { _mock = true, get_class = function() return 1 end }
local tank_unit = { _mock = true, get_class = function() return 2 end }

local healing_entries = {}

local mock_healing = {
    scan_healing_targets = function()
        return healing_entries, #healing_entries
    end,
    get_lowest_hp_target = function() return nil end,
    get_tank_target = function() return nil end,
    get_cleanse_target = function() return nil end,
}

_G.EaxRotations = {
    PaladinSpells = {
        -- holy
        AvengingWrath = 31884, BlessingOfFreedom = 1044, BlessingOfKings = 20217,
        BlessingOfLight = 27144, BlessingOfProtection = 10278, BlessingOfSacrifice = 27148,
        BlessingOfWisdom = 27142, Cleanse = 4987, ConcentrationAura = 19746,
        Consecration = 27173, DevotionAura = 27149, DivineFavor = 20216,
        DivineIllumination = 31842, DivineShield = 1020, FireResistanceAura = 27153,
        FlashOfLight = 19750, FrostResistanceAura = 27152, GreaterBlessingOfKings = 25898,
        GreaterBlessingOfLight = 27145, GreaterBlessingOfWisdom = 27143,
        HammerOfJustice = 10308, HammerOfWrath = 27180, HolyLight = 635,
        HolyShock = 33072, Judgement = 20271, LayOnHands = 27154, Purify = 1152,
        SealOfLight = 27160, SealOfWisdom = 27166, SealRighteousness = 27155,
        ShadowResistanceAura = 27151,
        -- protection
        AvengerShield = 32700, BlessingOfSanctuary = 27168, DivineProtection = 5573,
        Exorcism = 27138, HolyShield = 27179, HolyWrath = 27139,
        RighteousDefense = 31789, RighteousFury = 25780, SealCommand = 27170,
        TurnEvil = 10326,
        -- retribution
        BlessingOfMight = 27140, CrusaderStrike = 35395, Repentance = 20066,
        SanctityAura = 20218, SealBlood = 31892, SealCrusader = 27158,
        SealOfTheMartyr = 348700, SealWisdom = 27166, SealCommandRank1 = 20375,
    },
    PaladinHealing = mock_healing,
    POWER_MANA = 0,
    PLAYER_UNIT = player_unit,
    setting = function(context, key, default)
        if context and context.settings and context.settings[key] ~= nil then return context.settings[key] end
        return default
    end,
    get_setting = function(key, default) return default end,
    get_any_setting = function(context, k1, k2, fallback) return fallback end,
    spell_action = nil,
    spell_ready = function(spell, target, opts) spell_ready_count = spell_ready_count + 1; return true end,
    try_cast = function(spell, target, tag, opts) last_cast = spell; return true end,
    has_player_buff = function(ids) return false end,
    has_player_debuff = function(ids) return false end,
    has_target_debuff = function(unit, ids) return false end,
    buff_up = function(unit, ids) return false end,
    debuff_up = function(unit, ids) return cc_units[unit] == true end,
    buff_remains = function(unit, ids)
        if type(ids) == "table" then
            for _, id in ipairs(ids) do
                if id == 27145 or id == 27144 or id == 19979 or id == 19978 or id == 19977 or id == 25890 then
                    return 1000  -- Blessing of Light up on the tank
                end
            end
        end
        return 0
    end,
    debuff_remains = function(unit, ids) return 0 end,
    buff_points = function(unit, ids) return nil end,
    is_spell_learned = function(id) return learned_map[id] == true end,
    is_item_ready = function(id) return false end,
    use_item_by_id = function(id) return false end,
    cooldown_remains = function(spell) return 99 end,
    get_time_until_swing = function() return 99 end,
    time_now = function() return mock_time end,
    GetPlayer = function() return player_unit end,
    unit_alive = function(u) return true end,
    is_valid_target = function(u) return true end,
    not_same_unit = function(a, b) return a ~= b end,
    same_unit = function(a, b) return a == b end,
    unit_health_pct = function(u) return 100 end,
    unit_mana_pct = function(u) return 100 end,
    mana_pct = function(u) return 100 end,
    is_pvp_zone = function() return false end,
    unit_distance = function(a, b)
        if unit_distance_fn then return unit_distance_fn(a, b) end
        return 999
    end,
    gate_overheal = function(spell_key, unit, cast_time, settings, spell_id)
        overhear_calls[#overhear_calls + 1] = { key = spell_key, cast_time = cast_time, spell_id = spell_id }
        return gate_block_key == "ALL" or (gate_block_key ~= nil and spell_key == gate_block_key)
    end,
    healing_get_lowest_hp = function(entries, count, threshold)
        return entries and entries[1] or nil
    end,
    healing_get_tank = function(entries, count)
        for i = 1, count or 0 do if entries[i] and entries[i].is_tank then return entries[i] end end
        return nil
    end,
    pvp_trinket_used_recently = function(unit) return false end,
    aoe_self_meets = function() return true end,
    log = function() end,
    rotation_registry = {
        register = function(self, spec, strategies, opts)
            captured[spec] = strategies
        end,
    },
}

-- Mock shared modules before loading any spec.
local NS_REF = _G.EaxRotations

package.loaded["shared/tbc_data_sylvanas"] = { ITEMS = { healthstones = {}, potions = {} } }
package.loaded["shared/potion_helper_sylvanas"] = { try_use_potion = function() return false end, MANA_POTION_IDS = {}, HEALTH_POTION_IDS = {} }

local function find_strategy(spec, name)
    local list = captured[spec]
    for i = 1, #list do
        if list[i].name == name then return list[i] end
    end
    error("strategy not found in " .. spec .. ": " .. name, 2)
end

-- ============================================================================
-- Load the three specs (each reads _G.EaxRotations at load time).
-- ============================================================================
local holy = dofile("EaxRotations/classes/paladin/holy_sylvanas.lua")
local prot = dofile("EaxRotations/classes/paladin/protection_sylvanas.lua")
local ret = dofile("EaxRotations/classes/paladin/retribution_sylvanas.lua")
assert_true(captured.holy and captured.protection and captured.retribution,
    "all three paladin specs should register strategies")

-- ============================================================================
-- HOLY — TankPreHeal overheal gate must use the Holy Light rank locals.
-- The holy ACTION table has no "HolyLight" key (ranks are separate locals
-- HolyLightRank11/9/7/4), so the old `s.heal_spell == ACTION.HolyLight`
-- comparison never matched and every HL pre-heal was gated as "FlashOfLight"
-- with a 1.5s window on a 2.5s cast.
-- ============================================================================
local tank_pre_heal = find_strategy("holy", "TankPreHeal")
local blessing_refresh = find_strategy("holy", "BlessingRefresh")

local holy_ctx = {
    me = player_unit, target = nil, settings = {}, in_combat = true,
    mana_pct = 100, hp = 100, is_moving = false, is_pvp = false, is_group = false,
}

-- H1: Holy Light tank pre-heal is gated with the "HolyLight" key / 2.5s cast.
overhear_calls = {}
gate_block_key = nil
local tank_hl = { unit = tank_unit, hp = 70, effective_hp = 70, max_hp = 10000, current_hp = 9300, deficit = 700, is_tank = true }
assert_true(tank_pre_heal.matches(holy_ctx, { tank = tank_hl, mana_pct = 100 }),
    "H1: Holy Light tank pre-heal should match")
assert_eq(overhear_calls[#overhear_calls].key, "HolyLight",
    "H1: HL pre-heal must gate as HolyLight (2.5s), not FlashOfLight")
assert_eq(overhear_calls[#overhear_calls].cast_time, 2.5,
    "H1: HL pre-heal gate must use 2.5s cast time")
print("  [ PASS ] H1: Holy Light tank pre-heal gates as HolyLight/2.5s")

-- H2: overheal-gated pre-heal is skipped. The HL gate falls through to the
-- Flash of Light branch by design, so both keys must be blocked to fully skip.
overhear_calls = {}
gate_block_key = "ALL"
assert_false(tank_pre_heal.matches(holy_ctx, { tank = tank_hl, mana_pct = 100 }),
    "H2: overheal-gated tank pre-heal should be blocked (HL and FoL both gated)")
gate_block_key = nil
print("  [ PASS ] H2: overheal-gated tank pre-heal blocked")

-- H3: Flash of Light tank pre-heal still gates as FlashOfLight / 1.5s.
overhear_calls = {}
local tank_fol = { unit = tank_unit, hp = 80, effective_hp = 80, max_hp = 10000, current_hp = 9200, deficit = 800, is_tank = true }
assert_true(tank_pre_heal.matches(holy_ctx, { tank = tank_fol, mana_pct = 100 }),
    "H3: Flash of Light tank pre-heal should match")
assert_eq(overhear_calls[#overhear_calls].key, "FlashOfLight",
    "H3: FoL pre-heal must gate as FlashOfLight")
assert_eq(overhear_calls[#overhear_calls].cast_time, 1.5,
    "H3: FoL pre-heal gate must use 1.5s cast time")
print("  [ PASS ] H3: Flash of Light pre-heal gates as FlashOfLight/1.5s")

-- ============================================================================
-- HOLY — Blessing of Wisdom refresh reachable: build_healing_entries never
-- sets power_type/mana_pct/is_caster/role, so the old entry_is_mana_user
-- could never fire. The class-based check must pick a mage ally.
-- ============================================================================
-- H4: mage ally (class 8) missing BoW gets the Blessing of Wisdom target set.
healing_entries = {
    { unit = mage_unit, hp = 80, effective_hp = 80, current_hp = 8000, max_hp = 10000, deficit = 2000, is_tank = false, is_player = false },
    { unit = tank_unit, hp = 60, effective_hp = 60, current_hp = 6000, max_hp = 10000, deficit = 4000, is_tank = true, is_player = false },
}
local hst = holy.build_state(holy_ctx)
assert_true(hst.blessing_spell ~= nil, "H4: blessing should be selected for the mage ally")
assert_eq(hst.blessing_target, healing_entries[1], "H4: mage ally (mana user) should be the BoW target")
assert_true(blessing_refresh.matches(holy_ctx, hst),
    "H4: BlessingRefresh should fire for the BoW target")
print("  [ PASS ] H4: Blessing of Wisdom reachable for mana-user (mage) ally")

-- H5: warrior ally (class 1, no mana) must NOT get Blessing of Wisdom.
healing_entries = {
    { unit = warrior_unit, hp = 80, effective_hp = 80, current_hp = 8000, max_hp = 10000, deficit = 2000, is_tank = false, is_player = false },
}
local hst5 = holy.build_state(holy_ctx)
assert_true(hst5.blessing_spell ~= nil, "H5: some blessing should still be selected (Kings fallback)")
assert_true(hst5.blessing_spell ~= 27142 and hst5.blessing_label ~= "Blessing of Wisdom",
    "H5: warrior must not be picked for Blessing of Wisdom")
print("  [ PASS ] H5: warrior ally not selected for Blessing of Wisdom")

-- ============================================================================
-- PROTECTION — CC proximity must use real distances. The old
-- dx*dx+dy*dy<225 on .x/.y (not part of the game_object API) always passed,
-- so ANY CC'd mob in the 40yd enemy list gated Avenger's Shield/Consecration.
-- ============================================================================
local cc_far = { _mock = true }
local cc_near = { _mock = true }
local plain_enemy = { _mock = true }
local prot_target = { _mock = true }

local prot_ctx = {
    me = player_unit, target = prot_target, has_valid_enemy_target = true,
    in_combat = true, mana_pct = 100, hp = 100, enemy_count = 3,
    enemies = { cc_far, cc_near, plain_enemy }, settings = {},
}

-- P1: CC'd mob 5yd away -> cc_nearby true (real distance).
unit_distance_fn = function(a, b)
    if a == cc_near then return 5 end
    if a == cc_far then return 30 end
    return 999
end
cc_units = { [cc_far] = true, [cc_near] = true }
local ps1 = prot.build_state(prot_ctx)
assert_true(ps1.cc_nearby, "P1: CC'd mob within 15yd should set cc_nearby")
print("  [ PASS ] P1: CC'd mob at 5yd sets cc_nearby")

-- P2: CC'd mobs 30yd away -> cc_nearby stays false (real distance).
unit_distance_fn = function(a, b)
    if a == cc_near then return 30 end
    if a == cc_far then return 30 end
    return 999
end
local ps2 = prot.build_state(prot_ctx)
assert_false(ps2.cc_nearby, "P2: CC'd mob at 30yd must NOT set cc_nearby")
print("  [ PASS ] P2: CC'd mob at 30yd does not set cc_nearby")

-- P3: no NS.unit_distance -> get_position fallback (pcall-guarded).
unit_distance_fn = nil
NS_REF.unit_distance = nil  -- force the get_position fallback branch
cc_units = { [cc_far] = true }
cc_far.get_position = function() return { x = 0, y = 0 } end
cc_near.get_position = nil
prot_target.get_position = function() return { x = 0, y = 40 } end
local ps3 = prot.build_state(prot_ctx)
assert_false(ps3.cc_nearby, "P3: get_position fallback — 40yd away must NOT set cc_nearby")
prot_target.get_position = function() return { x = 0, y = 10 } end
local ps3b = prot.build_state(prot_ctx)
assert_true(ps3b.cc_nearby, "P3b: get_position fallback — 10yd away should set cc_nearby")
prot_target.get_position = nil
cc_far.get_position = nil
NS_REF.unit_distance = function(a, b)
    if unit_distance_fn then return unit_distance_fn(a, b) end
    return 999
end
print("  [ PASS ] P3: get_position fallback computes real distances")

-- P4: strategy-level effect — Avenger's Shield blocked when CC is nearby.
local avenger = find_strategy("protection", "AvengerShield")
local avenger_ctx = {
    me = player_unit, target = prot_target, has_valid_enemy_target = true,
    in_combat = true, mana_pct = 100, hp = 100, enemy_count = 3,
    enemies = { cc_far, cc_near, plain_enemy },
    settings = { prot_avenger_shield = true },
}
cc_units = { [cc_near] = true }
unit_distance_fn = function(a, b)
    if a == cc_near then return 5 end
    return 999
end
assert_false(avenger.matches(avenger_ctx, { avenger_ready = true }),
    "P4: Avenger's Shield should be blocked when CC is within 15yd")
unit_distance_fn = function(a, b) return 999 end
assert_true(avenger.matches(avenger_ctx, { avenger_ready = true }),
    "P4b: Avenger's Shield should fire when CC'd mobs are far away")
unit_distance_fn = nil
cc_units = {}
print("  [ PASS ] P4: Avenger's Shield gated only by real CC proximity")

-- ============================================================================
-- PROTECTION — build_state frame cache (apply_base_matches rebuilds per
-- strategy; cache within the same frame, safe_state-wrapped on hit).
-- ============================================================================
-- P5: same frame -> no rebuild; next frame -> rebuild.
local ctx_now5 = { me = player_unit, target = prot_target, has_valid_enemy_target = true, in_combat = true, mana_pct = 100, hp = 100, settings = {}, now = 501 }
local ctx_now6 = { me = player_unit, target = prot_target, has_valid_enemy_target = true, in_combat = true, mana_pct = 100, hp = 100, settings = {}, now = 502 }
spell_ready_count = 0
prot.build_state(ctx_now5)
local after_first = spell_ready_count
assert_true(after_first > 0, "P5: first build should call spell_ready")
prot.build_state(ctx_now5)
assert_eq(spell_ready_count, after_first, "P5: same-frame build must hit the cache")
local s_hit = prot.build_state(ctx_now5)
assert_true(getmetatable(s_hit) ~= nil and type(getmetatable(s_hit).__index) == "function",
    "P5: cache-hit return must be a safe_state proxy")
prot.build_state(ctx_now6)
assert_true(spell_ready_count > after_first, "P5: next frame must rebuild")
print("  [ PASS ] P5: protection build_state frame-cached with safe_state proxy")

-- P6: Consecration behavior unchanged; dead "already ticking" debuff field
-- is no longer populated by build_state (Consecration applies no target debuff).
local consecration = find_strategy("protection", "Consecration")
local ctx_conc = { me = player_unit, target = prot_target, has_valid_enemy_target = true, in_combat = true, mana_pct = 90, hp = 100, enemy_count = 5, settings = {} }
assert_true(consecration.matches(ctx_conc, { consecration_ready = true, mana_pct = 90, enemy_count = 5, cc_nearby = false, consecration_remains = 0 }),
    "P6: Consecration matches with enough targets")
assert_false(consecration.matches(ctx_conc, { consecration_ready = true, mana_pct = 90, enemy_count = 5, cc_nearby = true, consecration_remains = 0 }),
    "P6b: Consecration blocked near CC")
local ps6 = prot.build_state(ctx_conc)
assert_eq(ps6.consecration_remains, 0, "P6c: consecration_remains stays 0 (no target debuff in TBC)")
print("  [ PASS ] P6: Consecration gate behavior preserved; dead debuff read removed")

-- P7: HolyShock DSL upper HP bound — no 15s CD spent at (near) full HP.
local prot_hs = find_strategy("protection", "HolyShock")
local ctx_hs = { me = player_unit, target = prot_target, has_valid_enemy_target = true, in_combat = true, mana_pct = 100, hp = 100, settings = {} }
assert_false(prot_hs.matches(ctx_hs, { holy_shock_ready = true, hp_pct = 100 }),
    "P7: HolyShock must NOT fire at 100% HP")
assert_true(prot_hs.matches(ctx_hs, { holy_shock_ready = true, hp_pct = 60 }),
    "P7b: HolyShock fires in the heal band (40, 85)")
assert_false(prot_hs.matches(ctx_hs, { holy_shock_ready = true, hp_pct = 35 }),
    "P7c: HolyShock withheld when a heal is needed (<= 40)")
print("  [ PASS ] P7: protection HolyShock has an upper HP bound")

-- P8: SealOfCommandAoE must not overwrite the JoW emergency SoW seal.
local sca = find_strategy("protection", "SealOfCommandAoE")
local ctx_sca = { me = player_unit, target = prot_target, has_valid_enemy_target = true, in_combat = true, mana_pct = 100, hp = 100, enemy_count = 4, settings = { prot_seal_of_command = true } }
assert_false(sca.matches(ctx_sca, { enemy_count = 4, has_seal = false, has_seal_command = false, judgement_wisdom_mode = true }),
    "P8: SealOfCommandAoE blocked in JoW mode")
assert_false(sca.matches(ctx_sca, { enemy_count = 4, has_seal = false, has_seal_command = false, judgement_wisdom_mode = false, has_seal_wisdom = true, mana_pct = 20 }),
    "P8b: SealOfCommandAoE blocked while SoW is up at low mana")
assert_true(sca.matches(ctx_sca, { enemy_count = 4, has_seal = false, has_seal_command = false, judgement_wisdom_mode = false, has_seal_wisdom = true, mana_pct = 100 }),
    "P8c: SealOfCommandAoE allowed once mana recovered (mirrors SoR guard)")
mock_time = mock_time + 3.1  -- clear the 3s anti-loop throttle
assert_true(sca.matches(ctx_sca, { enemy_count = 4, has_seal = false, has_seal_command = false, judgement_wisdom_mode = false, has_seal_wisdom = false }),
    "P8d: SealOfCommandAoE normal path unchanged")
print("  [ PASS ] P8: SealOfCommandAoE honours the SoW/JoW guards")

-- ============================================================================
-- RETRIBUTION — Seal of the Martyr path must be reachable. NS.unit_faction
-- does not exist in the production API (test-mock only), so the old faction
-- branch was dead and Alliance rets always fell to Seal of Righteousness.
-- ============================================================================
local ret_ctx = {
    me = { _mock = true, get_distance = function(self, unit) return 5 end },
    target = { _mock = true, get_creature_type = function() return 3 end, is_player = function() return false end },
    settings = {}, in_combat = true, has_valid_enemy_target = true,
    mana_pct = 100, hp = 100, enemy_count = 3,
}

-- R1: Blood learned (Horde) -> preferred seal is blood.
learned_map = { [31892] = true, [348700] = true }
local rs1 = ret.build_state(ret_ctx)
assert_eq(rs1.preferred_damage_seal, "blood", "R1: blood learned -> blood preferred")
assert_true(rs1.can_use_blood, "R1: can_use_blood true with Blood learned")

-- R2: Blood NOT learned (Alliance) -> Seal of the Martyr becomes the primary.
learned_map = { [31892] = false, [348700] = true }
local rs2 = ret.build_state(ret_ctx)
assert_eq(rs2.preferred_damage_seal, "martyr",
    "R2: blood unlearned -> martyr preferred (Alliance path reachable)")
assert_false(rs2.can_use_blood, "R2: can_use_blood false without Blood")
print("  [ PASS ] R1/R2: preferred damage seal follows Blood availability")

-- R3: explicit seal_preference = "command" wins over the martyr auto path.
learned_map = { [31892] = false, [348700] = true }
local rs3 = ret.build_state({ me = ret_ctx.me, target = ret_ctx.target, settings = { seal_preference = "command" }, in_combat = true, has_valid_enemy_target = true, mana_pct = 100, hp = 100, enemy_count = 3 })
assert_eq(rs3.preferred_damage_seal, "command",
    "R3: explicit command preference must not be overridden by martyr")

-- R4: ret_use_martyr = false disables the martyr auto path.
local rs4 = ret.build_state({ me = ret_ctx.me, target = ret_ctx.target, settings = { ret_use_martyr = false }, in_combat = true, has_valid_enemy_target = true, mana_pct = 100, hp = 100, enemy_count = 3 })
assert_eq(rs4.preferred_damage_seal, "command",
    "R4: ret_use_martyr=false falls back to command")
print("  [ PASS ] R3/R4: martyr path gated by seal_preference + ret_use_martyr")

-- R5: Ret_SealMartyr_Primary fires when martyr is preferred.
local martyr_primary = find_strategy("retribution", "Ret_SealMartyr_Primary")
assert_true(martyr_primary.matches(ret_ctx, { preferred_damage_seal = "martyr", has_martyr = false }),
    "R5: Ret_SealMartyr_Primary matches on the martyr path")
print("  [ PASS ] R5: Ret_SealMartyr_Primary reachable")

-- ============================================================================
-- RETRIBUTION — Seal twist must twist Seal of the Martyr when Blood is
-- unavailable (Blood-only twist was dead on Alliance).
-- ============================================================================
local twist_blood = find_strategy("retribution", "SealTwistBlood")
local twist_prep = find_strategy("retribution", "SealTwistPrepCommand")

local twist_state_martyr = {
    can_twist = true, has_command = true, has_blood = false, has_martyr = false,
    has_command_rank1 = false, can_use_blood = false, preferred_damage_seal = "martyr",
    swing_remains = 0.3, twist_window = 0.45, mana_pct = 100, mana_emergency = false,
}

-- R6: martyr twist matches and execute casts Seal of the Martyr (348700).
last_cast = nil
assert_true(twist_blood.matches(ret_ctx, twist_state_martyr),
    "R6: SealTwistBlood must match on the martyr path when blood is unavailable")
assert_true(twist_blood.execute(), "R6: martyr twist execute succeeds")
assert_eq(last_cast, 348700, "R6: martyr twist must cast Seal of the Martyr (348700)")
print("  [ PASS ] R6: twist casts Seal of the Martyr on the blood-unavailable path")

-- R7: blood path unchanged — execute casts Seal of Blood (31892).
last_cast = nil
assert_true(twist_blood.matches(ret_ctx, {
    can_twist = true, has_command = true, has_blood = false, has_martyr = false,
    has_command_rank1 = false, can_use_blood = true, preferred_damage_seal = "blood",
    swing_remains = 0.3, twist_window = 0.45, mana_pct = 100, mana_emergency = false,
}), "R7: blood twist still matches with blood available")
assert_true(twist_blood.execute(), "R7: blood twist execute succeeds")
assert_eq(last_cast, 31892, "R7: blood twist must cast Seal of Blood (31892)")
print("  [ PASS ] R7: twist blood path unchanged")

-- R8: martyr twist disabled via ret_use_martyr=false.
assert_false(twist_blood.matches({ me = ret_ctx.me, target = ret_ctx.target, settings = { ret_use_martyr = false }, in_combat = true, has_valid_enemy_target = true, mana_pct = 100, hp = 100, enemy_count = 3 }, twist_state_martyr),
    "R8: martyr twist gated by ret_use_martyr")
print("  [ PASS ] R8: martyr twist respects ret_use_martyr")

-- R9: prep twist works on the martyr path (Command prep mirrors blood prep).
local prep_state_martyr = {
    can_twist = true, can_use_blood = false, preferred_damage_seal = "martyr",
    has_command_rank1 = false, swing_remains = 0.8, twist_window = 0.45,
    mana_pct = 100, mana_emergency = false,
}
assert_true(twist_prep.matches(ret_ctx, prep_state_martyr),
    "R9: SealTwistPrepCommand must match on the martyr path")
assert_false(twist_prep.matches(ret_ctx, {
    can_twist = true, can_use_blood = false, preferred_damage_seal = "blood",
    has_command_rank1 = false, swing_remains = 0.8, twist_window = 0.45,
    mana_pct = 100, mana_emergency = false,
}), "R9b: prep twist stays blood-path-only otherwise")
print("  [ PASS ] R9: prep twist mirrors the martyr path")

-- R10: SoR filler must not shadow the martyr path.
local sor_filler = find_strategy("retribution", "Ret_SealRighteousness_Filler")
assert_false(sor_filler.matches(ret_ctx, { preferred_damage_seal = "martyr", has_damage_seal = false, has_wisdom = false }),
    "R10: SoR filler must skip on the martyr path")
assert_true(sor_filler.matches(ret_ctx, { preferred_damage_seal = "command", has_damage_seal = false, has_wisdom = false }),
    "R10b: SoR filler unchanged off the martyr path")
print("  [ PASS ] R10: SoR filler no longer shadows the martyr fallback")

-- ============================================================================
-- RETRIBUTION — build_state frame cache + mana_pct fallback.
-- ============================================================================
-- R11: context.mana is never set by the engine; the fallback must not use it.
learned_map = { [31892] = true, [348700] = true }
local rs11 = ret.build_state({ me = ret_ctx.me, target = ret_ctx.target, settings = {}, in_combat = true, has_valid_enemy_target = true, mana = 50, hp = 100, enemy_count = 3 })
assert_eq(rs11.mana_pct, 100, "R11: context.mana must be ignored (mana_pct falls back to 100)")
print("  [ PASS ] R11: context.mana fallback removed")

-- R12: same frame -> cached; next frame -> rebuilt; cache hit is safe_state.
local ret_now1 = { me = ret_ctx.me, target = ret_ctx.target, settings = {}, in_combat = true, has_valid_enemy_target = true, mana_pct = 100, hp = 100, enemy_count = 3, now = 601 }
local ret_now2 = { me = ret_ctx.me, target = ret_ctx.target, settings = {}, in_combat = true, has_valid_enemy_target = true, mana_pct = 100, hp = 100, enemy_count = 3, now = 602 }
spell_ready_count = 0
ret.build_state(ret_now1)
local r_after_first = spell_ready_count
assert_true(r_after_first > 0, "R12: first ret build should call spell_ready")
ret.build_state(ret_now1)
assert_eq(spell_ready_count, r_after_first, "R12: same-frame ret build must hit the cache")
local r_hit = ret.build_state(ret_now1)
assert_true(getmetatable(r_hit) ~= nil and type(getmetatable(r_hit).__index) == "function",
    "R12: ret cache-hit return must be a safe_state proxy")
ret.build_state(ret_now2)
assert_true(spell_ready_count > r_after_first, "R12: next frame must rebuild")
print("  [ PASS ] R12: retribution build_state frame-cached with safe_state proxy")

print("PASS test_paladin_live_fixes")
