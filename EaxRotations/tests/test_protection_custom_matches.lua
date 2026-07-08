-- test_protection_custom_matches.lua -- Protection custom match validation tests.
-- WHAT:  Protection custom match validation tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Ensures spec-specific match functions behave correctly under mocked combat state.
-- SAFETY: Uses synthetic context; no live game data required.

-- Gate test: Paladin Protection custom matches functions.
-- Covers: SealRighteousness, SealOfCommandAoE, HammerOfWrath, AvengingWrath,
--         Exorcism, HolyWrath, FlashOfLight, HolyLight, SealOfWisdom, DivineProtection.
-- Asserts TRUE/FALSE return values (gold-standard style, not just no-crash).

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, m) if not v then error("FAIL: " .. m, 2) end end
local function assert_false(v, m) if v then error("FAIL: " .. m, 2) end end

local _captured
_G.EaxRotations = {
    PaladinSpells = {
        RighteousFury = 25780, HolyShield = 27179, Judgement = 20271,
        SealCommand = 27170, SealRighteousness = 27155, SealOfWisdom = 27166,
        Consecration = 27173, Exorcism = 27138, HolyWrath = 27139,
        HammerOfWrath = 27180, AvengingWrath = 31884, AvengerShield = 31935,
        DevotionAura = 27149, BlessingOfSanctuary = 25899, HolyShock = 25903,
        FlashOfLight = 27137, HolyLight = 27136, Cleanse = 4987,
        DivineProtection = 498, DivineShield = 642, LayOnHands = 27154,
        RighteousDefense = 31789, BlessingOfProtection = 10278, BlessingOfKings = 25898,
    },
    PLAYER_UNIT = {},
    setting = function(c, k, d) if c and c.settings and c.settings[k] ~= nil then return c.settings[k] end; return d end,
    spell_ready = function() return true end,
    try_cast = function() return false end,
    buff_up = function() return false end,
    buff_remains = function() return 0 end,
    broken_api_throttled = function() return false end,
    log = function() end,
    time_now = function() return 1000 end,
    GetPlayer = function() return {} end,
    rotation_registry = { register = function(self, spec, strats, opts) _captured = strats end },
}
package.loaded["shared/potion_helper_sylvanas"] = {}

local st = dofile("EaxRotations/classes/paladin/protection_sylvanas.lua")
assert(st, "Protection module should load")
assert(_captured, "Protection strategies captured via register")

local function fs(n)
    for i = 1, #_captured do
        if _captured[i].name == n then return _captured[i] end
    end
    error("not found: " .. n)
end

local function ctx(o)
    local c = {
        me = {}, target = {}, settings = {}, in_combat = true,
        has_valid_enemy_target = true,
    }
    if o then for k, v in pairs(o) do c[k] = v end end
    return c
end

local function cs(o)
    local s = {
        hp_pct = 100, mana_pct = 100, enemy_count = 1, target_hp_pct = 100,
        has_seal = false, has_seal_command = false, has_righteous_fury = false,
        has_forbearance = false, hammer_of_wrath_ready = true,
        avenging_wrath_ready = true, exorcism_ready = true, holy_wrath_ready = true,
        target_creature_type = nil, flash_of_light_ready = true,
        holy_light_ready = true, needs_cleanse = false, cleanse_ready = true,
        seal_of_wisdom_ready = true, divine_protection_ready = true,
        has_divine_shield = false,
    }
    if o then for k, v in pairs(o) do s[k] = v end end
    return s
end

-- NOTE: seal/aura matches have a 3s anti-flicker throttle (module-level _last_*_time).
-- First call after load always passes the throttle (now=1000, last=0).

-- SealRighteousness: needs no seal, no SoC, enabled (default true).
local sr = fs("SealRighteousness")
assert_true(sr.matches(ctx(), cs()), "SealRighteousness match")
assert_false(sr.matches(ctx(), cs({ has_seal = true })), "SealRighteousness skip has seal")

-- SealOfCommandAoE: requires prot_seal_of_command=true (default false), enemy_count >= 3.
local soc = fs("SealOfCommandAoE")
assert_false(soc.matches(ctx(), cs({ enemy_count = 3 })), "SoC skip disabled by default")
assert_true(soc.matches(ctx({ settings = { prot_seal_of_command = true } }), cs({ enemy_count = 3 })), "SoC AoE match")
assert_false(soc.matches(ctx({ settings = { prot_seal_of_command = true } }), cs({ enemy_count = 1 })), "SoC skip single target")

-- HammerOfWrath: target_hp <= 20.
local how = fs("HammerOfWrath")
assert_true(how.matches(ctx(), cs({ target_hp_pct = 15 })), "HammerWrath execute match")
assert_false(how.matches(ctx(), cs({ target_hp_pct = 50 })), "HammerWrath skip above 20%")

-- AvengingWrath: needs use_cooldowns, no Forbearance, TTD >= 15.
local aw = fs("AvengingWrath")
assert_false(aw.matches(ctx(), cs({ has_forbearance = true })), "AW skip Forbearance")
assert_false(aw.matches(ctx(), cs()), "AW skip cooldowns not enabled (default)")
assert_true(aw.matches(ctx({ settings = { use_cooldowns = true } }), cs()), "AW match cooldowns enabled")

-- Exorcism: Undead/Demon only (creature type 3 or 6).
local exo = fs("Exorcism")
assert_true(exo.matches(ctx(), cs({ target_creature_type = 3 })), "Exorcism match Undead")
assert_false(exo.matches(ctx(), cs({ target_creature_type = 7 })), "Exorcism skip Humanoid")
assert_false(exo.matches(ctx(), cs()), "Exorcism skip no creature type")

-- HolyWrath: 2+ enemies + Undead/Demon.
local hw = fs("HolyWrath")
assert_true(hw.matches(ctx(), cs({ enemy_count = 2, target_creature_type = 6 })), "HolyWrath AoE match")
assert_false(hw.matches(ctx(), cs({ enemy_count = 1, target_creature_type = 6 })), "HolyWrath skip single target")

-- FlashOfLight: hp <= 40 (default).
local fol = fs("FlashOfLight")
assert_true(fol.matches(ctx(), cs({ hp_pct = 30 })), "FlashOfLight heal match")
assert_false(fol.matches(ctx(), cs({ hp_pct = 80 })), "FlashOfLight skip high hp")

-- HolyLife: hp <= 25 (default).
local hl = fs("HolyLight")
assert_true(hl.matches(ctx(), cs({ hp_pct = 20 })), "HolyLight heal match")
assert_false(hl.matches(ctx(), cs({ hp_pct = 50 })), "HolyLight skip high hp")

-- SealOfWisdom: mana <= 30 (default), no seal.
local sow = fs("SealOfWisdom")
assert_true(sow.matches(ctx(), cs({ mana_pct = 20 })), "SealOfWisdom low mana match")
assert_false(sow.matches(ctx(), cs({ mana_pct = 80 })), "SealOfWisdom skip high mana")

-- DivineProtection: hp <= 25 (default).
local dp = fs("DivineProtection")
assert_true(dp.matches(ctx(), cs({ hp_pct = 20 })), "DivineProtection match low hp")
assert_false(dp.matches(ctx(), cs({ hp_pct = 80 })), "DivineProtection skip high hp")

print("PASS test_protection_custom_matches")