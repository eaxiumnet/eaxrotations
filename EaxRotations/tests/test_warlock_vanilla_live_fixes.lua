-- test_warlock_vanilla_live_fixes.lua — Warlock vanilla wave-1.3 live fixes.
-- WHAT:  Match-level regression for the 2026-08-13 vanilla warlock fixes:
--        destruction FelDomination no-pet gate, SearingPain movement gate,
--        CurseOfDoom TTD gate, ShadowWard PvP gate, DemonArmor in_combat
--        gate, Shadowburn/Trinket real burst fields; affliction AmplifyCurse
--        order, regen-above-filler, curse-mode rejection, PreCombatPull
--        reachability; demonology regen order + curse-assignment settings.
-- WHEN:  Standalone; registered in run_rotation_tests.lua (Wave 1.5 close-out).
-- WHY:   Pins the wave-1.3 audit fixes so they cannot regress.
-- SAFETY: Pure unit tests with mocked API context (test_smite_solo_matches
--         convention); no game data, no filesystem writes.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq failed") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
end

-- ---------------------------------------------------------------------------
-- Shared-module stubs (same convention as test_affliction_vanilla_strategies)
-- ---------------------------------------------------------------------------
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    HEALTH_POTION_IDS = {}, MANA_POTION_IDS = {}, DAMAGE_POTION_IDS = {},
}
package.loaded["shared/pet_manager_sylvanas"] = {
    set_defensive = function() return true end,
    set_passive = function() return true end,
    set_aggressive = function() return true end,
}
package.loaded["shared/tbc_data_sylvanas"] = {
    ITEMS = { potions = {}, healthstones = {} },
}
package.loaded["shared/spec_kit_sylvanas"] = {
    safe_state = function(s) return s end,
    setting = function(_, _, d) return d end,
}
package.loaded["shared/aoe_hit_volume_sylvanas"] = {
    install = function() end,
}

local function make_ns(overrides)
    local ns = {
        WarlockSpells = {
            ShadowBolt = 686, Corruption = 172, CurseOfAgony = 980, CurseOfDoom = 603,
            SiphonLife = 18265, Immolate = 348, DrainSoul = 1120, DrainLife = 689,
            LifeTap = 1454, DeathCoil = 6789, Fear = 6215, AmplifyCurse = 18288,
            DarkPact = 18220, DemonArmor = 706, ShadowWard = 6229, HealthFunnel = 755,
            CreateHealthstone = 6201, CreateSoulstone = 693, Shoot = 5019,
            CurseOfElements = 1490, CurseOfExhaustion = 18223, CurseOfTongues = 1714,
            HowlOfTerror = 5484, SummonImp = 688, SummonVoidwalker = 697,
            SummonSuccubus = 712, SummonFelhunter = 691,
            Shadowburn = 17877, Conflagrate = 17962, SearingPain = 5676, SoulFire = 6353,
            RainOfFire = 5740, Hellfire = 1949,
        },
        PLAYER_UNIT = {},
        spell_action = function(ids) return type(ids) == "table" and ids[1] or ids end,
        spell_ready = function() return true end,
        try_cast = function() return true end,
        buff_up = function() return false end,
        buff_remains = function() return 0 end,
        debuff_remains = function() return 0 end,
        has_player_buff = function() return false end,
        is_item_ready = function() return false end,
        use_item_by_id = function() return true end,
        has_item = function() return true end,
        spell_exists = function() return true end,
        time_now = function() return 0 end,
        should_use_long_cd = function() return true end,
        is_execute_phase = function(hp, pct) return type(hp) == "number" and hp <= (pct or 20) end,
        GetPlayer = function() return {} end,
        GetPet = function() return nil end,
        unit_alive = function() return true end,
        log = function() end,
        rotation_registry = { register = function() end },
    }
    if overrides then for k, v in pairs(overrides) do ns[k] = v end end
    return ns
end

local function load_strategies(path, ns)
    _G.EaxRotations = ns
    local result = dofile(path)
    if type(result) == "table" and result.strategies then return result.strategies end
    return result
end

local function find(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return i, strategies[i] end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- Destruction (destruction_vanilla.lua)
-- ============================================================================
local destro = load_strategies("EaxRotations/classes/warlock/destruction_vanilla.lua", make_ns())

-- (1) FelDomination: no-pet gate — Critical fix (the generic `return true`
-- matcher burned the 15-min CD every tick, even with a pet out).
local fd_i, fd = find(destro, "FelDomination")
assert_true(fd.matches({ in_combat = false, has_valid_enemy_target = false, me = {} }, {}),
    "FelDomination fires OOC with no pet")
assert_true(fd.matches({ in_combat = true, has_valid_enemy_target = true, target = {}, me = {} }, {}),
    "FelDomination fires in combat with no pet (resummon path, mirrors demonology)")
local destro_pet = load_strategies("EaxRotations/classes/warlock/destruction_vanilla.lua",
    make_ns({ GetPet = function() return { is_valid = function() return true end } end }))
local _, fd_pet = find(destro_pet, "FelDomination")
assert_false(fd_pet.matches({ in_combat = true, has_valid_enemy_target = false, me = {} }, {}),
    "FelDomination must not burn the 15-min CD with a live pet out")

-- (2) SearingPain: movement-filler gate (was above ShadowBolt with no gate →
-- always beat the filler inside 20yd).
local sp_i, sp = find(destro, "SearingPain")
assert_false(sp.matches({ target = {}, is_moving = false }, {}),
    "SearingPain blocked stationary (Shadow Bolt filler owns stationary ticks)")
assert_true(sp.matches({ target = {}, is_moving = true }, {}),
    "SearingPain fires while moving (movement filler)")

-- (3) CurseOfDoom: ACTIONS-declared TTD gate enforced (min_ttd = 62).
local cod_i, cod = find(destro, "CurseOfDoom")
assert_false(cod.matches({ target = {}, has_valid_enemy_target = true, ttd = 30 }, { cod_remains = 0 }),
    "CoD blocked on short-lived adds (ttd 30 < 62)")
assert_true(cod.matches({ target = {}, has_valid_enemy_target = true, ttd = 120 }, { cod_remains = 0 }),
    "CoD fires on long-lived targets")

-- (4) ShadowWard: PvP + shadow-caster gate (was a 30s PvE recast).
local sw_i, sw = find(destro, "ShadowWard")
assert_false(sw.matches({ is_pvp = false }, { has_shadow_ward = false }),
    "ShadowWard blocked in PvE")
assert_false(sw.matches({ is_pvp = true, target = { get_class = function() return 1 end } }, { has_shadow_ward = false }),
    "ShadowWard blocked vs non-shadow-caster target")
assert_true(sw.matches({ is_pvp = true, target = { get_class = function() return 9 end } }, { has_shadow_ward = false }),
    "ShadowWard fires vs shadow caster in PvP")

-- (5) DemonArmor: in_combat gate (was refreshing mid-combat).
local da_i, da = find(destro, "DemonArmor")
assert_false(da.matches({ in_combat = true }, { has_demon_armor = false }),
    "DemonArmor blocked in combat")
assert_true(da.matches({ in_combat = false }, { has_demon_armor = false }),
    "DemonArmor fires OOC without the buff")

-- (6) Shadowburn: burst-only setting now reads the real engine field
-- context.should_burst (NS.should_burst was battery-mock-only).
local sb_i, sb = find(destro, "Shadowburn")
assert_false(sb.matches({ target = {}, target_hp = 15, settings = { destro_shadowburn_burst_only = true } }, {}),
    "Shadowburn burst-only blocked outside a burst window")
assert_true(sb.matches({ target = {}, target_hp = 15, should_burst = true, settings = { destro_shadowburn_burst_only = true } }, {}),
    "Shadowburn burst-only fires inside a burst window")

-- (7) Trinket: real burst field + manager entry (NS.use_trinket / try_use
-- were mock-only; live manager exports on_update).
local destro_tm = load_strategies("EaxRotations/classes/warlock/destruction_vanilla.lua",
    make_ns({ TrinketManager = { on_update = function() return true end } }))
local tr_i, tr = find(destro_tm, "Trinket")
assert_false(tr.matches({ in_combat = true, target_hp = 100, should_burst = false }, {}),
    "Trinket blocked outside burst/execute")
assert_true(tr.matches({ in_combat = true, target_hp = 100, should_burst = true }, {}),
    "Trinket fires in a burst window (context.should_burst)")
assert_true(tr.matches({ in_combat = true, target_hp = 8 }, {}),
    "Trinket fires in execute")

-- ============================================================================
-- Affliction (affliction_vanilla.lua)
-- ============================================================================
local affl = load_strategies("EaxRotations/classes/warlock/affliction_vanilla.lua", make_ns())

-- (8) AmplifyCurse sits ABOVE the curse lanes (was after CoD/CoA — the curse
-- lane won the tick and the amplifier never preceded its target curse).
local amp_i, amp = find(affl, "AmplifyCurse")
local cod_a_i = find(affl, "CurseOfDoom")
local coa_a_i, coa_a = find(affl, "CurseOfAgony")
assert_true(amp_i < cod_a_i, "AmplifyCurse ordered above CurseOfDoom")
assert_true(amp.matches({ target = {}, settings = {}, ttd = 120 },
    { amplify_curse_ready = true, doom_remains = 0, agony_remains = 0 }),
    "AmplifyCurse matches before a long-lived curse is applied")

-- (9) Regen lanes (LifeTap/DarkPact/ManaPotion) sit ABOVE the always-true
-- ShadowBoltFiller (was below → regen only triggered once SB was uncastable).
local lt_a_i = find(affl, "LifeTap")
local dp_a_i = find(affl, "DarkPact")
local mp_a_i = find(affl, "ManaPotion")
local sbf_a_i = find(affl, "ShadowBoltFiller")
assert_true(lt_a_i < sbf_a_i, "LifeTap ordered above ShadowBoltFiller")
assert_true(dp_a_i < sbf_a_i, "DarkPact ordered above ShadowBoltFiller")
assert_true(mp_a_i < sbf_a_i, "ManaPotion ordered above ShadowBoltFiller")

-- (10) PreCombatPull sits ABOVE the DoT lane (was below Corruption/Siphon/
-- CoA/Immolate/CoE, all of which fire OOC and stole the tick).
local prepull_i, prepull = find(affl, "PreCombatPull")
local corr_a_i = find(affl, "CorruptionDoT")
assert_true(prepull_i < corr_a_i, "PreCombatPull ordered above CorruptionDoT")
assert_true(prepull.matches({ in_combat = false, has_valid_enemy_target = true, target = {}, target_range = 20 }, {}),
    "PreCombatPull fires OOC with a target in range")
assert_false(prepull.matches({ in_combat = true, has_valid_enemy_target = true, target = {} }, {}),
    "PreCombatPull blocked in combat")

-- (11) Curse-mode rejection: recklessness/weakness have no vanilla lanes, so
-- select_curse must reject them (mode honored for agony/doom/elements).
assert_false(coa_a.matches({ has_valid_enemy_target = true, target = {}, settings = { warlock_curse_mode = "recklessness" } },
    { agony_remains = 0 }),
    "recklessness mode blocks CoA (no Curse of Recklessness lane — no phantom curse)")
assert_false(coa_a.matches({ has_valid_enemy_target = true, target = {}, settings = { warlock_curse_mode = "weakness" } },
    { agony_remains = 0 }),
    "weakness mode blocks CoA (no Curse of Weakness lane — no phantom curse)")
assert_true(coa_a.matches({ has_valid_enemy_target = true, target = {}, settings = { warlock_curse_mode = "agony" } },
    { agony_remains = 0 }),
    "agony mode fires CoA")
local coe_a_i, coe_a = find(affl, "CurseOfElements")
local ctx_assigned_elements = { target = {}, settings = { warlock_assigned_curse = "elements" } }
assert_false(coa_a.matches({ has_valid_enemy_target = true, target = {}, settings = { warlock_assigned_curse = "elements" } },
    { agony_remains = 0 }),
    "raid-assigned elements blocks CoA")
assert_true(coe_a.matches(ctx_assigned_elements, { coe_remains = 0 }),
    "raid-assigned elements fires CurseOfElements")

-- ============================================================================
-- Demonology (demonology_vanilla.lua)
-- ============================================================================
local demo = load_strategies("EaxRotations/classes/warlock/demonology_vanilla.lua", make_ns())

-- (12) Regen lanes above the Shadow Bolt filler (mirror of the affliction fix).
local lt_d_i = find(demo, "LifeTap")
local dp_d_i = find(demo, "DarkPact")
local mp_d_i = find(demo, "ManaPotion")
local sbf_d_i, sbf_d = find(demo, "ShadowBoltFiller")
assert_true(lt_d_i < sbf_d_i, "demonology LifeTap ordered above ShadowBoltFiller")
assert_true(dp_d_i < sbf_d_i, "demonology DarkPact ordered above ShadowBoltFiller")
assert_true(mp_d_i < sbf_d_i, "demonology ManaPotion ordered above ShadowBoltFiller")

-- (13) select_curse honors warlock_curse_mode / warlock_assigned_curse (was
-- ignored entirely — raid-assigned Elements/Recklessness overwritten with
-- Agony).
local coa_d_i, coa_d = find(demo, "CurseOfAgony")
local coe_d_i, coe_d = find(demo, "CurseOfElements")
local ctx_mode_elements = { has_valid_enemy_target = true, target = {}, settings = { warlock_curse_mode = "elements" } }
assert_false(coa_d.matches(ctx_mode_elements, { agony_remains = 0, agony_ready = true }),
    "demonology mode=elements blocks CoA")
assert_true(coe_d.matches(ctx_mode_elements, { coe_remains = 0 }),
    "demonology mode=elements fires CurseOfElements")
assert_false(coa_d.matches({ has_valid_enemy_target = true, target = {}, settings = { warlock_curse_mode = "recklessness" } },
    { agony_remains = 0, agony_ready = true }),
    "demonology recklessness mode blocks CoA (rejected — no lane)")
local ctx_demo_assigned = { has_valid_enemy_target = true, target = {}, settings = { warlock_assigned_curse = "elements" } }
assert_false(coa_d.matches(ctx_demo_assigned, { agony_remains = 0, agony_ready = true }),
    "demonology raid-assigned elements blocks CoA")
assert_true(coe_d.matches(ctx_demo_assigned, { coe_remains = 0 }),
    "demonology raid-assigned elements fires CurseOfElements")

-- (14) PvP lanes read the safe_state proxy, not the raw demo_state table.
local fear_d_i, fear_d = find(demo, "PvP_Fear")
assert_true(fear_d.matches({ is_pvp = true, target = {} }, { fear_ready = true }),
    "demonology PvP_Fear reads proxy state (fear_ready)")
assert_false(fear_d.matches({ is_pvp = true, target = {} }, { fear_ready = false }),
    "demonology PvP_Fear blocked when not ready")

-- (15) HealthFunnelFallback: the byte-identical duplicate of HealthFunnel is
-- KEPT — tests/era_pair_seed.lua pins the name as a vanilla-era divergence
-- (present here, missing in the sylvanas/wotlk siblings), so removing it
-- without regenerating the seed fails the era-pair seed-freshness gate. It
-- can never fire first (HealthFunnel wins the tick); its matcher must still
-- be callable without crashing (nil-guard battery).
local hff_d_i, hff_d = find(demo, "HealthFunnelFallback")
assert_true(hff_d ~= nil, "HealthFunnelFallback kept for era-pair seed parity")
assert_false(hff_d.matches({}, { has_pet = false }),
    "HealthFunnelFallback gated on pet presence (no crash on minimal state)")

print("PASS test_warlock_vanilla_live_fixes")
