-- test_paladin_throttle_regression.lua -- Paladin throttle logic regression coverage tests.
-- WHAT:  Paladin throttle logic regression coverage tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- test_paladin_throttle_regression.lua
-- Minimal regression: verify 3s match-end throttles on key strategies.
package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path
local assert_true = function(v, l) if not v then error(l or "fail", 2) end end
local assert_false = function(v, l) if v then error(l or "fail", 2) end end

local mock_time = 1000.0
local NS = {
    PaladinSpells = {
        DevotionAura = {27149}, RetributionAura = {27150}, ConcentrationAura = {19746},
        SanctityAura = {20218}, FireResistanceAura = {27153}, FrostResistanceAura = {27152},
        ShadowResistanceAura = {27151}, RighteousFury = 25780, SealRighteousness = {27155},
        SealCommand = {27170}, BlessingOfKings = 25898, GreaterBlessingOfKings = 25898,
        BlessingOfWisdom = 27143, GreaterBlessingOfWisdom = 27143, BlessingOfMight = 27141,
        BlessingOfSanctuary = 27169, BlessingOfLight = 27145, BlessingOfSacrifice = 27148,
        BlessingOfFreedom = 1044, BlessingOfProtection = 10278, DivineShield = {642},
        LayOnHands = 27154, HolyShield = {27179}, Consecration = {27173}, AvengerShield = {32699},
        Judgement = {20271}, HammerOfWrath = {27180}, HammerOfJustice = {10308},
        AvengingWrath = 31884, Exorcism = {871}, HolyWrath = {27139}, DivineProtection = {498},
        SealOfWisdom = 27166, RighteousDefense = 31789, Cleanse = {4987},
    },
    buff_up = function() return false end, debuff_up = function() return false end,
    buff_remains = function(unit, ids)
        if type(ids)=="table" then
            for _, id in ipairs(ids) do
                if id==25898 or id==20217 then
                    -- CombatKingsRefresh needs in (0,60], GroupBlessKings needs <=0
                    if unit and unit.unit then return 0 end -- GroupBlessKings (member tables have .unit)
                    return 30 -- CombatKingsRefresh (self)
                end
                if id==27149 or id==465 then return 0 end -- DEVOTION_AURA_BUFF
                if id==27168 or id==20914 or id==20913 or id==20912 or id==20911 then return 0 end -- BLESSING_OF_SANCTUARY_BUFF
            end
        end
        return 1
    end,
    debuff_remains = function() return 1 end, -- >0 for Forbearance check
    has_buff = function() return false end, has_player_buff = function() return false end,
    has_player_debuff = function() return false end, is_spell_learned = function() return true end,
    spell_ready = function() return true end, time_now = function() return mock_time end,
    log = function() end, spell_action = function(ids) return type(ids)=="table" and ids[1] or ids end,
    try_cast = function() return true end, register_class_middleware = function() end,
    rotation_registry = { register = function() end }, broken_api_throttled = function() return false end,
    setting = function(ctx, key, fallback) if ctx and ctx.settings and ctx.settings[key]~=nil then return ctx.settings[key] end return fallback end,
    has_item = function() return false end, is_in_raid = function() return false end,
    unit_faction = function() return "Alliance" end, GetPlayer = function() return {} end,
    GetPartyMembers = function() return {{unit={}}} end, unit_health_pct = function() return 100 end,
    mana_pct = function() return 100 end,
}
_G.EaxRotations = NS

package.loaded["shared/interrupt_manager_sylvanas"] = { register_interrupt_spell = function() return {name="mock"} end }
package.loaded["shared/consumable_manager_sylvanas"] = { on_update = function() return false end }
package.loaded["shared/offensive_dispel_sylvanas"] = {}
package.loaded["shared/potion_helper_sylvanas"] = { try_use_potion = function() return false end, MANA_POTION_IDS={} }

local function find_strategy(list, name)
    if type(list)=="table" then
        if list.strategies then return find_strategy(list.strategies, name) end
        for _, s in ipairs(list) do if s.name==name then return s end end
    end
    error("not found: "..name)
end

local ms = dofile("EaxRotations/classes/paladin/middleware_sylvanas.lua")
local prot = dofile("EaxRotations/classes/paladin/protection_sylvanas.lua")
local prot_strats = type(prot)=="table" and (prot.strategies or prot) or {}

local ctx_ooc = { in_combat=false, is_mounted=false, me={}, settings={playstyle="protection"} }
local ctx_combat = { in_combat=true, is_mounted=false, has_valid_enemy_target=true, me={}, target={x=1,y=1}, settings={playstyle="protection", prot_seal_of_command=true} }

-- 1) Aura (original fix)
local aura = find_strategy(ms, "Paladin_SelfBuffAura")
assert_true(aura.matches(ctx_ooc), "aura fresh")
assert_false(aura.matches(ctx_ooc), "aura 3s block")

-- 2) SelfBuffKings
local kings = find_strategy(ms, "Paladin_SelfBuffKings")
assert_true(kings.matches(ctx_ooc), "kings fresh")
assert_false(kings.matches(ctx_ooc), "kings 3s block")

-- 3) RighteousFury
local rf = find_strategy(prot_strats, "RighteousFury")
local rf_state = { has_righteous_fury=false, hp_pct=100, mana_pct=100, consecration_ready=true }
assert_true(rf.matches(ctx_ooc, rf_state), "rf fresh")
assert_false(rf.matches(ctx_ooc, rf_state), "rf 3s block")

-- 4) BlessingOfSanctuary
local bos = find_strategy(prot_strats, "BlessingOfSanctuary")
local bos_state = { has_blessing_sanctuary=false, hp_pct=100, mana_pct=100, consecration_ready=true }
assert_true(bos.matches(ctx_ooc, bos_state), "bos fresh")
assert_false(bos.matches(ctx_ooc, bos_state), "bos 3s block")

-- 5) AutoConsumable — throttle set only on successful execute, not in matches
local ac = find_strategy(ms, "AutoConsumable")
assert_true(ac.matches(ctx_combat), "ac fresh")
-- execute returns false (mock consumable_manager), so throttle is NOT set
assert_true(ac.matches(ctx_combat), "ac still fresh after failed execute")
-- now mock a successful execute
package.loaded["shared/consumable_manager_sylvanas"] = { on_update = function() return true end }
local ms2 = dofile("EaxRotations/classes/paladin/middleware_sylvanas.lua")
local ac2 = find_strategy(ms2, "AutoConsumable")
assert_true(ac2.matches(ctx_combat), "ac2 fresh")
assert_true(ac2.execute(ctx_combat), "ac2 execute succeeds")
assert_false(ac2.matches(ctx_combat), "ac2 3s block after success")

-- 6) SealRighteousness
local sr = find_strategy(prot_strats, "SealRighteousness")
local sr_state = { has_seal=false, has_seal_command=false, hp_pct=100, mana_pct=100, consecration_ready=true }
assert_true(sr.matches(ctx_combat, sr_state), "sr fresh")
assert_false(sr.matches(ctx_combat, sr_state), "sr 3s block")

-- 7) SealOfCommandAoE
local sca = find_strategy(prot_strats, "SealOfCommandAoE")
local sca_state = { has_seal=false, has_seal_command=false, enemy_count=4, target_hp_pct=100, mana_pct=100, consecration_ready=true }
assert_true(sca.matches(ctx_combat, sca_state), "sca fresh")
assert_false(sca.matches(ctx_combat, sca_state), "sca 3s block")

-- 8) DevotionAura
local da = find_strategy(prot_strats, "DevotionAura")
local da_state = { has_devotion_aura=false, hp_pct=100, mana_pct=100, consecration_ready=true }
assert_true(da.matches(ctx_ooc, da_state), "da fresh")
assert_false(da.matches(ctx_ooc, da_state), "da 3s block")

-- 9) SelfBuffBlessing
local sbb = find_strategy(ms, "Paladin_SelfBuffBlessing")
assert_true(sbb.matches(ctx_ooc), "sbb fresh")
assert_false(sbb.matches(ctx_ooc), "sbb 3s block")

-- 10) CombatKingsRefresh
local ckr = find_strategy(ms, "Paladin_CombatKingsRefresh")
assert_true(ckr.matches(ctx_combat), "ckr fresh")
assert_false(ckr.matches(ctx_combat), "ckr 3s block")

-- 11) CombatWisdomRefresh
local cwr = find_strategy(ms, "Paladin_CombatWisdomRefresh")
local cwr_ctx = { in_combat=true, is_mounted=false, me={}, mana_pct=100, settings={playstyle="holy", combat_wisdom_refresh_mana=30, combat_wisdom_refresh_threshold=120} }
assert_true(cwr.matches(cwr_ctx), "cwr fresh")
assert_false(cwr.matches(cwr_ctx), "cwr 3s block")

-- 12) CombatGroupKingsRefresh (shares _last_group_bless_kings_match_time with GroupBlessKings)
local cgkr = find_strategy(ms, "Paladin_CombatGroupKingsRefresh")
assert_true(cgkr.matches(ctx_combat), "cgkr fresh")
assert_false(cgkr.matches(ctx_combat), "cgkr 3s block")

-- 13) GroupBlessKings — advance time past shared throttle before testing
mock_time = mock_time + 3.05
local gbk = find_strategy(ms, "Paladin_GroupBlessKings")
assert_true(gbk.matches(ctx_ooc), "gbk fresh")
assert_false(gbk.matches(ctx_ooc), "gbk 3s block")

-- 14) DivineShield
NS.debuff_remains = function() return 0 end
local ds = find_strategy(ms, "Paladin_DivineShield")
local ds_ctx = { in_combat=true, is_mounted=false, me={}, hp=12, settings={divine_shield_hp=15} }
assert_true(ds.matches(ds_ctx), "ds fresh")
assert_false(ds.matches(ds_ctx), "ds 3s block")

-- 15) LayOnHands
local loh = find_strategy(ms, "Paladin_LayOnHands")
local loh_ctx = { in_combat=true, is_mounted=false, me={}, hp=5, settings={lay_on_hands_hp=8} }
assert_true(loh.matches(loh_ctx), "loh fresh")
assert_false(loh.matches(loh_ctx), "loh 3s block")

-- 16) DivineProtection
local dp = find_strategy(prot_strats, "DivineProtection")
local dp_state = { hp_pct=20, mana_pct=100, has_forbearance=false, has_divine_shield=false, divine_protection_ready=true, consecration_ready=true }
assert_true(dp.matches(ctx_combat, dp_state), "dp fresh")
assert_false(dp.matches(ctx_combat, dp_state), "dp 3s block")

-- 17) LayOnHands (protection)
local ploh = find_strategy(prot_strats, "LayOnHands")
local ploh_state = { hp_pct=8, mana_pct=100, lay_on_hands_ready=true, consecration_ready=true }
assert_true(ploh.matches(ctx_combat, ploh_state), "ploh fresh")
assert_false(ploh.matches(ctx_combat, ploh_state), "ploh 3s block")

print("[PASS] test_paladin_throttle_regression — all 17 throttled strategies verified")
