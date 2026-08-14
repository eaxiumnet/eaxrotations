-- test_hunter_live_fixes.lua -- Hunter TBC live-correctness regression tests.
-- WHAT:  pins the 2026-08 live-correctness audit fixes for the three TBC hunter
--        specs: BM Intimidation in_combat gate + Misdirection target validity +
--        Readiness expected_cooldown hint; MM/SV FeignDeath threat gating,
--        ViperSting debuff/mana/setting gates, MM AimedShotPrepull one-shot
--        latch + range gate, MM MultiShot AoE gate, MM FreezingTrap nearby-enemy
--        gate, MM aspect auto_aspect gate, SV trap mutual exclusion, SV
--        Misdirection CD/window/buff gates, SV ConcussiveShot readiness, SV
--        ExplosiveTrap opt-in, SV Volley threshold, SV WyvernSting group gate.
-- WHEN:  standalone (lua EaxRotations/tests/test_hunter_live_fixes.lua).
-- WHY:   regression guard so the live-correctness fixes never silently regress.
-- SAFETY: pure unit tests with a mocked API; no live game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- ============================================================================
-- Mock NS
-- ============================================================================
local now = 100.0
local try_cast_calls = {}
local cooldown_calls = {}          -- { spell = id, expected = hint }
local debuff_calls = {}            -- { unit = u, ids = ladder }
local debuff_up_result = false
local has_buff_result = false
local pet_available = false
local pet_mock = {
    is_valid = function() return true end,
    is_alive = function() return true end,
    is_dead = function() return false end,
    get_health_percentage = function() return 100 end,
}

local function spell_id(spell)
    if type(spell) == "number" then return spell end
    if type(spell) == "table" then
        if spell.ids then return spell.ids[1] end
        if spell._meta and spell._meta.ids then return spell._meta.ids[1] end
    end
    return spell
end

_G.core = { object_manager = { get_local_player = function() return {} end } }
_G.EaxRotations = {
    HunterSpells = {
        AimedShot = 27065, ArcaneShot = 27019, AspectOfTheHawk = 27044,
        AspectOfTheViper = 34074, BestialWrath = 19574, CallPet = 883,
        ConcussiveShot = 5116, ExplosiveTrap = 27025, FeignDeath = 5384,
        FreezingTrap = 14311, HuntersMark = 14325, ImmolationTrap = 29906,
        Intimidation = 19577, KillCommand = 34026, MendPet = 27046,
        Misdirection = 34477, MongooseBite = 14271, MultiShot = 27021,
        RapidFire = 3045, RaptorStrike = 27014, Readiness = 23989,
        RevivePet = 982, ScorpidSting = 3043, SerpentSting = 27016,
        SilencingShot = 34490, SnakeTrap = 34600, SteadyShot = 34120,
        TrueshotAura = 19506, ViperSting = 27018, Volley = 27022,
        WingClip = 14268, WyvernSting = 27068,
    },
    PLAYER_UNIT = {},
    GetPlayer = function() return {} end,
    GetPet = function() return pet_available and pet_mock or nil end,
    GetFocus = function() return nil end,
    time_now = function() return now end,
    cooldown_remains = function(spell, expected)
        cooldown_calls[#cooldown_calls + 1] = { spell = spell_id(spell), expected = expected }
        return 0
    end,
    spell_ready = function() return true end,
    buff_up = function() return false end,
    debuff_up = function(unit, ids)
        debuff_calls[#debuff_calls + 1] = { unit = unit, ids = ids }
        return debuff_up_result
    end,
    debuff_remains = function() return 0 end,
    has_buff = function() return has_buff_result end,
    is_spell_learned = function() return true end,
    mana_pct = function() return 100 end,
    health_pct = function() return 100 end,
    aoe_target_meets = function() return true end,
    aoe_self_meets = function() return true end,
    GetEnemiesCount = function() return 0 end,
    try_cast = function(...) try_cast_calls[#try_cast_calls + 1] = { ... } return true end,
    log = function() end,
    rotation_registry = { register = function() end },
    HunterClipTracker = {
        ms_until_auto = function() return 0 end,
        can_cast_steady = function() return true end,
        record_manual_shot = function() end,
    },
}

-- ============================================================================
-- Load the three specs (BM first: its install block wires the real
-- aoe_hit_volume into NS; the aoe stubs are re-installed below so threshold
-- args are observable).
-- ============================================================================
local bm = dofile("EaxRotations/classes/hunter/beast_mastery_sylvanas.lua")
local mm = dofile("EaxRotations/classes/hunter/marksmanship_sylvanas.lua")
local sv = dofile("EaxRotations/classes/hunter/survival_sylvanas.lua")
assert_true(bm and bm.strategies, "BM strategies should load")
assert_true(mm and mm.strategies, "MM strategies should load")
assert_true(sv and sv.strategies, "SV strategies should load")

local function find_strategy(strats, name)
    for i = 1, #strats do
        if strats[i].name == name then return strats[i] end
    end
    error("strategy not found: " .. name)
end

-- Re-stub AoE gates after the specs' install blocks so min_count args are
-- observable for the threshold wiring tests.
local aoe_threshold_calls = {}
_G.EaxRotations.aoe_target_meets = function(min_count, radius, target, ctx, st)
    aoe_threshold_calls[#aoe_threshold_calls + 1] = min_count
    return true
end
_G.EaxRotations.aoe_self_meets = function() return true end

-- ============================================================================
-- BM: Intimidation is combat-only (was casting the 60s stun OOC every tick)
-- ============================================================================
local intim = find_strategy(bm.strategies, "Intimidation")
assert_false(intim.matches({}, { is_mounted = false, in_combat = false, pet_alive = true, intimidation_ready = true }),
    "BM Intimidation must not fire out of combat")
assert_true(intim.matches({}, { is_mounted = false, in_combat = true, pet_alive = true, intimidation_ready = true }),
    "BM Intimidation fires in combat")
assert_false(intim.matches({}, { is_mounted = false, in_combat = true, pet_alive = false, intimidation_ready = true }),
    "BM Intimidation requires live pet")

-- ============================================================================
-- BM: Misdirection never self-casts (invalid) — focus/pet target only
-- ============================================================================
local bm_md = find_strategy(bm.strategies, "Misdirection")
assert_false(bm_md.matches({ in_combat = true, combat_time = 2, me = {} }, { use_misdirection = false, in_combat = true }),
    "BM Misdirection requires use_misdirection")
assert_true(bm_md.matches({ in_combat = true, combat_time = 2, me = {} }, { use_misdirection = true, in_combat = true }),
    "BM Misdirection matches inside the pull window")

now = 500
try_cast_calls = {}
pet_available = false
bm_md.execute({ me = {}, target = {} })
assert_eq(#try_cast_calls, 0, "BM Misdirection must not cast on self when no focus/pet")

pet_available = true
now = now + 5
try_cast_calls = {}
bm_md.execute({ me = {}, target = {} })
assert_eq(#try_cast_calls, 1, "BM Misdirection casts on pet when focus absent")
assert_true(try_cast_calls[1][2] == pet_mock, "BM Misdirection target is the pet, not self")

-- ============================================================================
-- BM: Readiness reads rapid_fire_cd with an expected_cooldown hint (Rapid Fire
-- 3045 = 300s CD per the TBC 2.5.5 DBC) so the cast-history fallback reports a
-- real remaining CD and the readiness lane can fire.
-- ============================================================================
cooldown_calls = {}
bm.build_state({ me = {}, target = {}, in_combat = true, settings = {}, mana_pct = 100, hp = 100, enemy_count = 1, distance_sq = 400, player_level = 70, is_leveling = false })
local rf_hint_found = false
for _, c in ipairs(cooldown_calls) do
    if c.spell == 3045 and c.expected == 300 then rf_hint_found = true break end
end
assert_true(rf_hint_found, "BM rapid_fire_cd must pass expected_cooldown=300 to cooldown_remains")

-- ============================================================================
-- MM: FeignDeath is threat-gated (fd_mode defaults off; fires only at high
-- threat / aggro) — was feigning death on every pull
-- ============================================================================
local mm_fd = find_strategy(mm.strategies, "FeignDeath")
assert_false(mm_fd.matches({ in_combat = true }, { in_combat = true, feign_death_ready = true }),
    "MM FeignDeath defaults off (fd_mode)")
assert_true(mm_fd.matches({ in_combat = true }, { in_combat = true, feign_death_ready = true, fd_mode = "high_threat", threat_level = 2 }),
    "MM FeignDeath fires at threat >= 2 in high_threat mode")
assert_false(mm_fd.matches({ in_combat = true }, { in_combat = true, feign_death_ready = true, fd_mode = "high_threat", threat_level = 1 }),
    "MM FeignDeath blocks below the high_threat threshold")
assert_false(mm_fd.matches({ in_combat = false }, { in_combat = false, feign_death_ready = true, fd_mode = "high_threat", threat_level = 2 }),
    "MM FeignDeath requires combat")

-- ============================================================================
-- MM: ViperSting — combat + debuff ladder + target-mana + middleware settings
-- ============================================================================
local mm_vs = find_strategy(mm.strategies, "ViperSting")
local mana_target = { get_mana_percentage = function() return 100 end }
local low_mana_target = { get_mana_percentage = function() return 10 end }
assert_true(mm_vs.matches({ in_combat = true, target = mana_target, settings = {} }, { viper_sting_ready = true, in_combat = true }),
    "MM ViperSting matches in combat vs a mana user")
assert_false(mm_vs.matches({ in_combat = true, target = low_mana_target, settings = {} }, { viper_sting_ready = true, in_combat = true }),
    "MM ViperSting skips a low-mana target (nothing left to drain)")
assert_false(mm_vs.matches({ in_combat = false, target = mana_target, settings = {} }, { viper_sting_ready = true, in_combat = false }),
    "MM ViperSting requires combat")
assert_false(mm_vs.matches({ in_combat = true, target = mana_target, settings = { use_viper_sting_pve = false } }, { viper_sting_ready = true, in_combat = true }),
    "MM ViperSting honors use_viper_sting_pve off in PvE")
debuff_up_result = true
assert_false(mm_vs.matches({ in_combat = true, target = mana_target, settings = {} }, { viper_sting_ready = true, in_combat = true }),
    "MM ViperSting skips when the debuff is already live")
debuff_up_result = false

-- ============================================================================
-- MM: AimedShotPrepull — one-shot per combat cycle + 35yd + target gates
-- ============================================================================
local prepull = find_strategy(mm.strategies, "AimedShotPrepull")
assert_true(prepull.matches({ target = {}, in_combat = false }, { is_ooc = true, aimed_shot_prepull_ready = true, distance_sq = 400 }),
    "MM AimedShotPrepull matches OOC with a target within 35yd")
assert_false(prepull.matches({ target = {}, in_combat = false }, { is_ooc = true, aimed_shot_prepull_ready = true, distance_sq = 3600 }),
    "MM AimedShotPrepull skips a target beyond 35yd")
assert_false(prepull.matches({ in_combat = false }, { is_ooc = true, aimed_shot_prepull_ready = true }),
    "MM AimedShotPrepull requires a target")
assert_false(prepull.matches({ target = {}, in_combat = true }, { is_ooc = false, aimed_shot_prepull_ready = true, distance_sq = 400 }),
    "MM AimedShotPrepull never fires in combat")
try_cast_calls = {}
prepull.execute({ target = {} })
assert_eq(#try_cast_calls, 1, "MM AimedShotPrepull execute casts")
assert_false(prepull.matches({ target = {}, in_combat = false }, { is_ooc = true, aimed_shot_prepull_ready = true, distance_sq = 400 }),
    "MM AimedShotPrepull latches after a successful cast")
mm.build_state({ in_combat = true, me = {}, target = {}, settings = {}, mana_pct = 100, hp = 100, distance_sq = 400 })
assert_true(prepull.matches({ target = {}, in_combat = false }, { is_ooc = true, aimed_shot_prepull_ready = true, distance_sq = 400 }),
    "MM AimedShotPrepull re-arms after combat starts (one per cycle)")

-- ============================================================================
-- MM: MultiShot — combat + AoE gate (aoe_threshold setting)
-- ============================================================================
local mm_ms = find_strategy(mm.strategies, "MultiShot")
aoe_threshold_calls = {}
assert_true(mm_ms.matches({ target = {}, in_combat = true }, { in_combat = true, multi_shot_ready = true, mana_pct = 50, enemy_count = 3 }),
    "MM MultiShot matches in combat")
assert_eq(aoe_threshold_calls[1], 3, "MM MultiShot default aoe threshold is 3")
aoe_threshold_calls = {}
assert_true(mm_ms.matches({ target = {}, in_combat = true, settings = { aoe_threshold = 5 } }, { in_combat = true, multi_shot_ready = true, mana_pct = 50 }),
    "MM MultiShot matches with aoe_threshold 5")
assert_eq(aoe_threshold_calls[1], 5, "MM MultiShot honors the aoe_threshold setting")
assert_false(mm_ms.matches({ target = {}, in_combat = false }, { in_combat = false, multi_shot_ready = true, mana_pct = 50 }),
    "MM MultiShot requires combat")

-- ============================================================================
-- MM: FreezingTrap — nearby-enemy gate (target within ~15yd)
-- ============================================================================
local mm_ft = find_strategy(mm.strategies, "FreezingTrap")
assert_true(mm_ft.matches({ in_combat = false, target = {} }, { in_combat = false, freezing_trap_ready = true }),
    "MM FreezingTrap matches OOC with a target and unknown distance")
assert_false(mm_ft.matches({ in_combat = false, target = {} }, { in_combat = false, freezing_trap_ready = true, distance_sq = 400 }),
    "MM FreezingTrap skips a target beyond 15yd")
assert_false(mm_ft.matches({ in_combat = false }, { in_combat = false, freezing_trap_ready = true }),
    "MM FreezingTrap skips with no target (town gate)")
assert_false(mm_ft.matches({ in_combat = true, target = {} }, { in_combat = true, freezing_trap_ready = true }),
    "MM FreezingTrap skips in combat")

-- ============================================================================
-- MM: Wing Clip debuff ladder covers all castable ranks (2974/14267/14268)
-- ============================================================================
debuff_calls = {}
mm.build_state({ me = {}, target = {}, pet = nil, in_combat = true, settings = {}, mana_pct = 100, hp = 100, distance_sq = 16 })
local wc_ladder
for _, c in ipairs(debuff_calls) do
    if type(c.ids) == "table" and c.ids[1] == 2974 then wc_ladder = c.ids break end
end
assert_true(wc_ladder ~= nil, "MM build_state queries the Wing Clip debuff ladder")
assert_eq(#wc_ladder, 3, "MM Wing Clip debuff ladder has all three ranks")
assert_eq(wc_ladder[3], 14268, "MM Wing Clip debuff ladder includes top rank 14268")

-- ============================================================================
-- MM: aspects honor hunter_auto_aspect (BM parity)
-- ============================================================================
local mm_hawk = find_strategy(mm.strategies, "AspectOfTheHawk")
local mm_viper = find_strategy(mm.strategies, "AspectOfTheViper")
assert_false(mm_hawk.matches({ settings = {} }, { auto_aspect = false, has_aspect_hawk = false }),
    "MM hawk aspect respects hunter_auto_aspect off")
assert_true(mm_hawk.matches({ settings = {} }, { has_aspect_hawk = false, mana_pct = 30 }),
    "MM hawk aspect matches with auto_aspect default")
assert_false(mm_viper.matches({ settings = {} }, { auto_aspect = false, has_aspect_viper = false, mana_pct = 3 }),
    "MM viper aspect respects hunter_auto_aspect off")
assert_true(mm_viper.matches({ settings = {} }, { has_aspect_viper = false, mana_pct = 3 }),
    "MM viper aspect matches with auto_aspect default")

-- ============================================================================
-- SV: FeignDeath is threat-gated (same contract as MM)
-- ============================================================================
local sv_fd = find_strategy(sv.strategies, "FeignDeath")
assert_false(sv_fd.matches({ in_combat = true }, { in_combat = true, feign_death_ready = true }),
    "SV FeignDeath defaults off (fd_mode)")
assert_true(sv_fd.matches({ in_combat = true }, { in_combat = true, feign_death_ready = true, fd_mode = "high_threat", threat_level = 2 }),
    "SV FeignDeath fires at threat >= 2 in high_threat mode")
assert_false(sv_fd.matches({ in_combat = true }, { in_combat = true, feign_death_ready = true, fd_mode = "aggro_only", threat_level = 2 }),
    "SV FeignDeath aggro_only mode requires threat 3")
assert_false(sv_fd.matches({ in_combat = false }, { in_combat = false, feign_death_ready = true, fd_mode = "high_threat", threat_level = 2 }),
    "SV FeignDeath requires combat")

-- ============================================================================
-- SV: ViperSting gates (same contract as MM)
-- ============================================================================
local sv_vs = find_strategy(sv.strategies, "ViperSting")
assert_true(sv_vs.matches({ in_combat = true, target = mana_target, settings = {} }, { viper_sting_ready = true, in_combat = true }),
    "SV ViperSting matches in combat vs a mana user")
assert_false(sv_vs.matches({ in_combat = true, target = low_mana_target, settings = {} }, { viper_sting_ready = true, in_combat = true }),
    "SV ViperSting skips a low-mana target")
assert_false(sv_vs.matches({ in_combat = true, target = mana_target, settings = { use_viper_sting_pve = false } }, { viper_sting_ready = true, in_combat = true }),
    "SV ViperSting honors use_viper_sting_pve off in PvE")
debuff_up_result = true
assert_false(sv_vs.matches({ in_combat = true, target = mana_target, settings = {} }, { viper_sting_ready = true, in_combat = true }),
    "SV ViperSting skips when the debuff is already live")
debuff_up_result = false

-- ============================================================================
-- SV: Misdirection — 30s expected CD (patch 2.3.2+), pull window, buff guard,
-- setting opt-in
-- ============================================================================
local sv_md = find_strategy(sv.strategies, "Misdirection")
assert_false(sv_md.matches({ in_combat = true, combat_time = 2, me = {}, settings = {} }, { pet_alive = true, in_combat = true }),
    "SV Misdirection requires use_misdirection setting")
assert_true(sv_md.matches({ in_combat = true, combat_time = 2, me = {}, settings = { use_misdirection = true } }, { pet_alive = true, in_combat = true }),
    "SV Misdirection matches inside the pull window")
assert_false(sv_md.matches({ in_combat = true, combat_time = 10, me = {}, settings = { use_misdirection = true } }, { pet_alive = true, in_combat = true }),
    "SV Misdirection blocks outside the pull window")
assert_false(sv_md.matches({ in_combat = false, combat_time = 2, me = {}, settings = { use_misdirection = true } }, { pet_alive = true, in_combat = false }),
    "SV Misdirection requires combat")
has_buff_result = true
assert_false(sv_md.matches({ in_combat = true, combat_time = 2, me = {}, settings = { use_misdirection = true } }, { pet_alive = true, in_combat = true }),
    "SV Misdirection skips when the MD buff is already active")
has_buff_result = false
cooldown_calls = {}
sv_md.matches({ in_combat = true, combat_time = 2, me = {}, settings = { use_misdirection = true } }, { pet_alive = true, in_combat = true })
local md_cd_hint
for _, c in ipairs(cooldown_calls) do
    if c.spell == 34477 then md_cd_hint = c.expected break end
end
assert_eq(md_cd_hint, 30, "SV Misdirection passes expected_cooldown=30 (TBC 2.3.2+ CD)")

-- ============================================================================
-- SV: ConcussiveShot — readiness computed + combat gate
-- ============================================================================
local conc = find_strategy(sv.strategies, "ConcussiveShot")
assert_true(conc.matches({ in_combat = true, has_valid_enemy_target = true, target = {} }, { in_combat = true, concussive_shot_ready = true, distance_sq = 100 }),
    "SV ConcussiveShot matches in combat within 15yd")
assert_false(conc.matches({ in_combat = true, has_valid_enemy_target = true, target = {} }, { in_combat = true, concussive_shot_ready = false, distance_sq = 100 }),
    "SV ConcussiveShot requires readiness (was casting every tick)")
assert_false(conc.matches({ in_combat = false, has_valid_enemy_target = true, target = {} }, { in_combat = false, concussive_shot_ready = true, distance_sq = 100 }),
    "SV ConcussiveShot requires combat")
sv.build_state({ me = {}, target = {}, pet = nil, in_combat = true, settings = {}, mana_pct = 100, hp = 100, distance_sq = 100 })
assert_true(true, "SV build_state computes concussive_shot_ready without error")

-- ============================================================================
-- SV: SnakeTrap / ImmolationTrap mutual exclusion (one trap at a time)
-- ============================================================================
local snake = find_strategy(sv.strategies, "SnakeTrap")
local immo = find_strategy(sv.strategies, "ImmolationTrap")
now = 1000
assert_true(snake.matches({ target = {} }, { in_combat = true, enemy_count = 3, snake_trap_ready = true, use_snake_trap = true }),
    "SV SnakeTrap matches at 3 enemies")
assert_true(immo.matches({ target = {} }, { in_combat = true, enemy_count = 3, immolation_trap_ready = true }),
    "SV ImmolationTrap matches at 3 enemies")
try_cast_calls = {}
snake.execute({ me = {}, target = {} })
assert_eq(#try_cast_calls, 1, "SV SnakeTrap execute casts")
now = 1005
assert_false(immo.matches({ target = {} }, { in_combat = true, enemy_count = 3, immolation_trap_ready = true }),
    "SV ImmolationTrap suppressed inside the trap window (no overwrite)")
assert_false(snake.matches({ target = {} }, { in_combat = true, enemy_count = 3, snake_trap_ready = true, use_snake_trap = true }),
    "SV SnakeTrap also suppressed inside the window")
now = 1030
assert_true(immo.matches({ target = {} }, { in_combat = true, enemy_count = 3, immolation_trap_ready = true }),
    "SV ImmolationTrap re-enabled after the window")

-- ============================================================================
-- SV: ExplosiveTrap — combat + opt-in setting
-- ============================================================================
local et = find_strategy(sv.strategies, "ExplosiveTrap")
assert_false(et.matches({}, { in_combat = true, use_explosive_trap = false, explosive_trap_ready = true }),
    "SV ExplosiveTrap requires the opt-in setting")
assert_false(et.matches({}, { in_combat = false, use_explosive_trap = true, explosive_trap_ready = true }),
    "SV ExplosiveTrap requires combat")
assert_true(et.matches({}, { in_combat = true, use_explosive_trap = true, explosive_trap_ready = true, enemy_count = 4 }),
    "SV ExplosiveTrap matches in combat with the setting on")

-- ============================================================================
-- SV: Volley threshold configurable via aoe_threshold (default 4)
-- ============================================================================
local vol = find_strategy(sv.strategies, "Volley")
aoe_threshold_calls = {}
assert_true(vol.matches({ in_combat = true, target = {}, is_moving = false }, { in_combat = true, volley_ready = true }),
    "SV Volley matches")
assert_eq(aoe_threshold_calls[1], 4, "SV Volley default threshold is 4 (historical hardcode)")
aoe_threshold_calls = {}
assert_true(vol.matches({ in_combat = true, target = {}, is_moving = false, settings = { aoe_threshold = 2 } }, { in_combat = true, volley_ready = true }),
    "SV Volley matches with aoe_threshold 2")
assert_eq(aoe_threshold_calls[1], 2, "SV Volley honors the aoe_threshold setting")

-- ============================================================================
-- SV: WyvernSting — skip the group's engaged DPS target (sleep breaks
-- instantly); idle / CC'd adds are still stingable in group PvP
-- ============================================================================
local wy = find_strategy(sv.strategies, "WyvernSting")
assert_false(wy.matches({ target = {} }, { wyvern_sting_ready = true, has_serpent_sting = false, has_scorpid_sting = false }),
    "SV WyvernSting requires a PvP context")
assert_true(wy.matches({ is_pvp = true, target = {} }, { wyvern_sting_ready = true, has_serpent_sting = false, has_scorpid_sting = false }),
    "SV WyvernSting matches solo PvP")
local engaged_target = { get_target = function() return { is_valid = function() return true end } end }
assert_false(wy.matches({ is_pvp = true, is_group = true, target = engaged_target }, { wyvern_sting_ready = true, has_serpent_sting = false, has_scorpid_sting = false }),
    "SV WyvernSting skips the group's engaged DPS target")
assert_true(wy.matches({ is_pvp = true, is_group = true, target = {} }, { wyvern_sting_ready = true, has_serpent_sting = false, has_scorpid_sting = false }),
    "SV WyvernSting matches an un-engaged group target")
assert_false(wy.matches({ is_pvp = true, target = {} }, { wyvern_sting_ready = true, has_serpent_sting = true }),
    "SV WyvernSting skips when a DoT is already on the target")

-- ============================================================================
-- SV: serpent_sting_refresh is pcall-wrapped (nil-target safe)
-- ============================================================================
local ssr = find_strategy(sv.strategies, "SerpentStingRefresh")
local ok_refresh, res_refresh = pcall(ssr.matches, { in_combat = true }, { in_combat = true, serpent_sting_ready = true, has_serpent_sting = true })
assert_true(ok_refresh, "SV SerpentStingRefresh must not crash with a nil target")
assert_true(type(res_refresh) == "boolean", "SV SerpentStingRefresh returns a boolean")

print("PASS test_hunter_live_fixes")
