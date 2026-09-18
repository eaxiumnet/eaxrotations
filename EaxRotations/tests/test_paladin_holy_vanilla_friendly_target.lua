-- test_paladin_holy_vanilla_friendly_target.lua -- Holy Paladin Vanilla-era compatibility friendly target targeting tests.
-- WHAT:  Holy Paladin Vanilla-era compatibility friendly target targeting tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Verifies Vanilla/Classic-era rotation compatibility and spell availability.
-- SAFETY: Tests only Vanilla spell IDs and mechanics.

-- B6 FriendlyTarget for vanilla paladin holy.
package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

local _ft_unit = { _friendly = true, is_player = function() return true end }
local _ft_hp = 75
local _ft_hostile = false
local _ft_present = true
local _ft_deficit = nil
local _last_cast = nil

_G.core = { time = function() return 0 end, log = function() end, get_game_version = function() return "Vanilla" end }
_G.EaxRotations = {
    PaladinSpells = { HolyLight = 25292, FlashOfLight = 19943, HolyShock = 20473, LayOnHands = 27154, DivineShield = 27155, BlessingOfProtection = 27144, Cleanse = 4987, Purify = 1152, BlessingOfFreedom = 27140, DivineFavor = 20216, BlessingOfSacrifice = 27148, ManaPotion = 1 },
    CLASS_ID = { PALADIN = 2 },
    PLAYER_UNIT = { _mock = true },
    GetPlayer = function() return { get_class = function() return 2 end } end,
    GetTarget = function() return _ft_present and _ft_unit or nil end,
    is_hostile_unit = function() return _ft_hostile end,
    unit_alive = function(u) return u ~= nil end,
    unit_health_pct = function(u) if u == _ft_unit then return _ft_hp end return 100 end,
    get_friendly_target_entry = function()
        if not _ft_present or _ft_hostile then return nil end
        return { unit = _ft_unit, hp_pct = _ft_hp, effective_hp = _ft_hp, deficit = _ft_deficit, is_player = true }
    end,
    spell_ready = function() return true end,
    has_player_buff = function() return false end,
    debuff_remains = function() return 0 end,
    gate_overheal = function() return false end,
    try_cast = function(spell, target, reason, opts) _last_cast = { spell = spell, target = target, reason = reason }; return true end,
    healing_get_tank = function() return nil end,
    healing_get_lowest_hp = function() return nil end,
    healing_all_above_hp = function() return false end,
    healing_get_cleanse_target = function() return nil end,
    healing_count_below_hp = function() return 0 end,
    has_dispel_type_debuff = function() return false end,
    has_healing_reduction_debuff = function() return false end,
    is_in_raid = function() return false end,
    is_in_party = function() return false end,
    get_setting = function(key, fallback) return fallback end,
    spell_action = function(ids, name) return { spell = ids, name = name } end,
    log = function() end,
    rotation_registry = { register = function() end },
}

package.loaded["shared/potion_helper_sylvanas"] = { try_use_potion = function() return false end, MANA_POTION_IDS = {}, HEALTH_POTION_IDS = {} }
package.loaded["classes/paladin/healing_sylvanas"] = { select_heal = function() return nil end, scan_healing_targets = function() return {}, 0 end }

local result = dofile("EaxRotations/classes/paladin/holy_vanilla.lua")
local strategies = result.strategies or result
local function find(name) for i = 1, #strategies do if strategies[i].name == name then return strategies[i] end end error("not found: "..name) end
local ft = find("FriendlyTarget")
assert_true(ft, "FriendlyTarget strategy should exist")

local function ctx(o) local c = { in_combat = true, is_moving = false, mana_pct = 100, hp = 100, settings = {}, me = { _mock = true }, is_pvp = false, target = nil } if o then for k,v in pairs(o) do c[k]=v end end return c end
local function st(o) local s = { lowest = nil, tank = nil, mana_pct = 100, moving = false, has_divine_favor = false, sacrifice_target = nil } if o then for k,v in pairs(o) do s[k]=v end end return s end
local function reset() _ft_present = true; _ft_hostile = false; _ft_hp = 75; _ft_deficit = nil; _last_cast = nil end

print("--- Paladin Holy Vanilla FriendlyTarget (B6) ---")

reset()
local s1 = st({ lowest = { effective_hp = 80, unit = {} } })
assert_true(ft.matches(ctx(), s1), "C1: should match")
_last_cast = nil
assert_true(ft.execute(ctx(), s1), "C1: execute returns true")
assert_eq(_last_cast.target, _ft_unit, "C1: targets friendly unit")
print("  [ PASS ] C1: matches + casts HolyLight on friendly target")

reset()
assert_false(ft.matches(ctx(), st({ lowest = { effective_hp = 20, unit = {} } })), "C2: lowest 20% (<=25) -> emergency override")
print("  [ PASS ] C2: emergency override (EMERGENCY_HP gate)")

reset()
assert_false(ft.matches(ctx({ settings = { holy_use_friendly_target = false } }), st()), "C3: opt-out respected")
print("  [ PASS ] C3: opt-out setting respected")

reset()
assert_false(ft.matches(ctx({ is_moving = true }), st()), "C4: moving -> no match")
print("  [ PASS ] C4: moving-gated")

reset(); _ft_hostile = true
assert_false(ft.matches(ctx(), st()), "C5: hostile target does not match")
_ft_hostile = false
print("  [ PASS ] C5: hostile target does not match")

local ft_idx, df_idx, bs_idx
for i = 1, #strategies do
    if strategies[i].name == "FriendlyTarget" then ft_idx = i end
    if strategies[i].name == "DivineFavorHolyLightFollowup" then df_idx = i end
    if strategies[i].name == "BlessingOfSacrificeTank" then bs_idx = i end
end
assert_true(ft_idx and df_idx and bs_idx, "C6: expected strategies present")
assert_true(df_idx < ft_idx, "C6: FriendlyTarget after DivineFavorHolyLightFollowup")
assert_true(ft_idx < bs_idx, "C6: FriendlyTarget before BlessingOfSacrificeTank")
print("  [ PASS ] C6: strategy ordering")

-- ============================================================================
-- Holy Light deficit-fit (2026-09-16): smallest covering rank via the shared
-- hook over the learn-capped classic ladder, fail-closed to the legacy
-- hp/deficit bands. Live NS lookup so the hook is injected post-load here.
-- ============================================================================
local NS_V = _G.EaxRotations
NS_V.HOLY_LIGHT_RANKS = { { spell = "HL_FAKE_LADDER", label = "R9" } }
local FIT_HL = "HL_FIT_R7"
local hl_hook_calls = 0
local hl_last_opts = nil
NS_V.cast_best_heal_rank = function(ranks, target, context, label, opts)
    hl_hook_calls = hl_hook_calls + 1
    assert_true(ranks == NS_V.HOLY_LIGHT_RANKS, "HL fit receives the shared ladder")
    assert_eq(label, "Holy Light", "HL fit label")
    hl_last_opts = opts
    return FIT_HL, "Holy Light R7"
end

local function find_strategy(name)
    for i = 1, #strategies do if strategies[i].name == name then return strategies[i] end end
    error("not found: " .. name)
end
local hle = find_strategy("HolyLightEmergency")
local function hle_state(deficit)
    return st({ lowest = { unit = {}, effective_hp = 40, hp = 40, deficit = deficit } })
end

-- Fit used: mid-rank replaces the R9/Max band (hp 40 / deficit 1500).
hl_hook_calls = 0
local s_fit = hle_state(1500)
assert_true(hle.matches(ctx(), s_fit), "C7: HolyLightEmergency should match at hp 40")
assert_eq(s_fit.holy_light_spell, FIT_HL, "C7: deficit-fit rank replaces the Max band")
assert_eq(s_fit.holy_light_label, "Holy Light R7", "C7: fit label threads through")
assert_eq(hl_last_opts and hl_last_opts.player_level, 60, "C7: level-60 penalty divisor threaded")
assert_eq(hl_hook_calls, 1, "C7: hook attempted once")
print("  [ PASS ] C7: emergency deficit-fit + level threading")

-- Fail-closed: hook misses -> legacy Max band (hp 40 / deficit 1500).
NS_V.cast_best_heal_rank = function() return nil end
local s_fb = hle_state(1500)
assert_true(hle.matches(ctx(), s_fb), "C8: HolyLightEmergency should match on fit miss")
assert_eq(s_fb.holy_light_label, "Holy Light Max", "C8: fit miss falls back to the Max band")
print("  [ PASS ] C8: emergency fail-closed fallback")

-- Explicit rank mode always wins, even when the fit is available.
NS_V.cast_best_heal_rank = function() return FIT_HL, "Holy Light R7" end
local s_exp = hle_state(1500)
assert_true(hle.matches(ctx({ settings = { holy_light_rank = "rank4" } }), s_exp), "C9: HolyLightEmergency should match in rank4 mode")
assert_eq(s_exp.holy_light_label, "Holy Light R5", "C9: explicit rank4 bypasses the fit")
print("  [ PASS ] C9: explicit rank mode wins")

-- Unreadable deficit: hook never attempted, legacy band answers.
hl_hook_calls = 0
local hook_probe = NS_V.cast_best_heal_rank
NS_V.cast_best_heal_rank = function(...) hl_hook_calls = hl_hook_calls + 1; return hook_probe(...) end
local s_zero = hle_state(0)
assert_true(hle.matches(ctx(), s_zero), "C10: HolyLightEmergency should match at hp 40 / zero deficit")
assert_eq(s_zero.holy_light_label, "Holy Light Max", "C10: zero deficit keeps the hp band")
assert_eq(hl_hook_calls, 0, "C10: hook skipped when deficit is unreadable")
print("  [ PASS ] C10: zero-deficit skip")

-- ============================================================================
-- Flash of Light deficit-fit (2026-09-16): smallest covering FoL rank via the
-- shared hook over the learn-capped classic ladder (R7 tail dropped);
-- conserve/max bands stay as fail-closed fallback. Public practice: Warcraft
-- Tavern classic ("have a couple of ranks of each on your action bar ...
-- choose the correct spell"; FoL 4+6, HL 6+9), wowhead classic holy guide
-- ("If your target is missing 200 health, you should not cast a max rank
-- Holy Light. Instead ... cast a lower rank of Flash of Light").
-- ============================================================================
NS_V.FLASH_OF_LIGHT_RANKS = { { spell = "FOL_FAKE_LADDER", label = "R6" } }
local FIT_FOL = "FOL_FIT_R4"
local fol_hook_calls = 0
local fol_fit_enabled = true
NS_V.cast_best_heal_rank = function(ranks, target, context, label, opts)
    if ranks == NS_V.HOLY_LIGHT_RANKS then return nil end
    assert_true(ranks == NS_V.FLASH_OF_LIGHT_RANKS, "FoL fit receives the shared FoL ladder")
    assert_eq(label, "Flash of Light", "FoL fit label")
    fol_hook_calls = fol_hook_calls + 1
    assert_eq(opts and opts.player_level, 60, "FoL level-60 divisor threaded")
    if not fol_fit_enabled then return nil end
    return FIT_FOL, "Flash of Light R4"
end

local smart_heal = find_strategy("SmartHeal")
local function fol_state(hp, deficit, mana)
    return st({ mana_pct = mana or 100, lowest = { unit = {}, effective_hp = hp, hp = hp, deficit = deficit } })
end

-- Fit used in the flash zone (hp 80, deficit 300: above the HL 70/900 bar).
fol_hook_calls = 0
local s_fol = fol_state(80, 300)
assert_true(smart_heal.matches(ctx(), s_fol), "C11: SmartHeal should match in the flash zone")
assert_eq(s_fol.heal_spell, FIT_FOL, "C11: deficit-fit FoL replaces max Flash")
assert_eq(s_fol.heal_label, "Flash of Light R4", "C11: FoL fit label threads through")
assert_eq(fol_hook_calls, 1, "C11: FoL hook attempted once")
print("  [ PASS ] C11: flash deficit-fit")

-- Fail-closed: hook misses -> max Flash of Light.
fol_fit_enabled = false
local s_fol_fb = fol_state(80, 300)
assert_true(smart_heal.matches(ctx(), s_fol_fb), "C12: SmartHeal should match on FoL fit miss")
assert_eq(s_fol_fb.heal_label, "Flash of Light", "C12: FoL fit miss falls back to max")
print("  [ PASS ] C12: flash fail-closed fallback")

-- Conserve band preserved: hook misses + low mana -> R6 conserve.
local s_fol_cons = fol_state(80, 300, 10)
assert_true(smart_heal.matches(ctx(), s_fol_cons), "C13: SmartHeal should match at low mana")
assert_eq(s_fol_cons.heal_label, "Flash of Light R6 conserve", "C13: conserve band survives the fit")
print("  [ PASS ] C13: conserve band preserved")

-- Zero deficit + low mana: hook never attempted, conserve answers directly.
fol_hook_calls = 0
local s_fol_zero = fol_state(80, 0, 10)
assert_true(smart_heal.matches(ctx(), s_fol_zero), "C14: SmartHeal should match at zero deficit")
assert_eq(s_fol_zero.heal_label, "Flash of Light R6 conserve", "C14: zero deficit keeps the conserve band")
assert_eq(fol_hook_calls, 0, "C14: FoL hook skipped when deficit is unreadable")
print("  [ PASS ] C14: flash zero-deficit skip")

-- FriendlyTarget fit: deficit 500 on the friendly entry -> fit rank.
fol_fit_enabled = true
NS_V.cast_best_heal_rank = function(ranks, target, context, label, opts)
    if ranks == NS_V.FLASH_OF_LIGHT_RANKS then return nil end
    return FIT_HL, "Holy Light R6"
end
reset(); _ft_deficit = 500
local s_ft = st({ lowest = { effective_hp = 80, unit = {} } })
assert_true(ft.matches(ctx(), s_ft), "C15: FriendlyTarget should match at deficit 500")
assert_eq(s_ft.holy_light_spell, FIT_HL, "C15: friendly-target lane uses the fit rank")
print("  [ PASS ] C15: friendly-target deficit-fit")

print("PASS test_paladin_holy_vanilla_friendly_target")
