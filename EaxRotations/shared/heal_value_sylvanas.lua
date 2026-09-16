-- ============================================================================
-- Heal Value Module (EaxRotations)
-- WHAT:  Per-rank expected-heal math + deficit-fit rank selection for TBC
--        healers. Lets heal lanes cast the smallest rank whose expected heal
--        covers the target's deficit instead of always max rank.
-- WHEN:  core_sylvanas.cast_best_heal_rank (deficit-fit hook), paladin
--        heal_helper (SP + penalty), HealerDeficit gates (per-rank size).
-- WHY:   Every heal lane previously cast the top rank (or "first ready"),
--        which wastes mana on small deficits. Base values are harvested from
--        PhDamage (Xerrion/PhDamage @ commit 22b8ed92717c6812a42bac7473e2ec
--        e849e78075, MIT) and spot-verified against Wowhead TBC spell
--        description text (disputed values carry evidence notes below). The
--        downrank penalty is NOT PhDamage's (theirs was open issue #47) --
--        we use the proven NS.PreemptiveHeal formula (LibHealComm-4.0
--        lineage) already gated by the spell-id audits.
-- SAFETY: Pure data + math, no engine calls at require time. Every reader is
--         nil-guarded and fail-closed: with no spell-power source the math
--         degrades to base averages; pick_castable returns nil for legacy
--         ladders so callers fall back to their previous behavior; the
--         healer_rank_fit_enabled=false setting restores legacy casting
--         unconditionally.
-- ============================================================================
local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local math_floor = math.floor
local type = type

-- Downrank penalty source: loaded directly (not via NS state) so the math is
-- correct in any environment that can resolve the module path. The formula
-- is pure Lua with no engine calls.
local PreemptiveHeal = NS.PreemptiveHeal
if not PreemptiveHeal then
    local ok, mod = pcall(require, "shared/preemptive_heal_sylvanas")
    if ok and type(mod) == "table" and type(mod.downrank_penalty) == "function" then
        PreemptiveHeal = mod
        NS.PreemptiveHeal = NS.PreemptiveHeal or mod
    end
end

local M = {}
NS.HealValue = M

-- Provenance: pinned upstream commit of the harvested tables (PhDamage, MIT).
M.SOURCE_COMMIT = "22b8ed92717c6812a42bac7473e2ece849e78075"

-- ---------------------------------------------------------------------------
-- Bonus healing (spell power) resolution.
-- The live engine's stat API is not reachable from this tree, so bonus
-- healing comes from settings, keyed per class. Default 0 keeps the math
-- honest (base averages only) instead of inventing a number.
-- ---------------------------------------------------------------------------
M.DEFAULT_BONUS_HEALING = 0
M.BONUS_HEALING_SETTING = "heal_bonus_healing"

function M.get_bonus_healing(_class_key, settings)
    -- Single user-provided knob (mirrors the existing player_spell_damage
    -- convention in common_spell_damage_section). 0 = off: the math runs on
    -- base averages, identical to pre-module behavior.
    settings = settings or (NS.settings or {})
    local v = settings[M.BONUS_HEALING_SETTING]
    if type(v) == "number" and v >= 0 then return v end
    return M.DEFAULT_BONUS_HEALING
end

-- ---------------------------------------------------------------------------
-- Per-rank TBC heal data.
-- Fields per entry: id, rank (spell rank number, for labels), level (rank
-- learn level -- drives the downrank penalty; the class-table/bridge value
-- is the sweep-audited authority), base_min, base_max (Wowhead description
-- text), cost (mana -- present ONLY where the cost was read off the Wowhead
-- page during verification; nil = unverified, and HPM treats nil as
-- no-signal), coeff (total spell-power coefficient, family-level).
--
-- Evidence notes where sources disagreed:
--  * FoL 27137: PhDamage + Wowhead description say 458-513; the pre-existing
--    in-repo table carried 448-502 (the effect-line variant). Description
--    text wins (consistent with every other rank checked).
--  * Era divergence (2026-09-15 SoD verification): spell ids the TBC client
--    reuses from classic can carry different classic-client values -- most
--    notably Healing Touch 25297, whose classic tooltip reads 2267-2677
--    (TBC row: 2303-2714; both pages read 2026-09-15). M.ERA_OVERRIDES below
--    corrects such rows for era-built ladders; the TBC rows stay
--    authoritative for TBC consumers and find_rank_by_id.
-- ---------------------------------------------------------------------------
M.RANKS = {
    paladin = {
        HolyLight = {
            coeff = 0.714, cast_time = 2.5,
            -- PhDamage SpellData_Paladin (SpellData[635].ranks); R11/R9
            -- verified against Wowhead spell=27136 / spell=25292. Cost kept
            -- only where the page was read (25292).
            { id = 27136, rank = 11, level = 70, base_min = 2196, base_max = 2446 },
            { id = 27135, rank = 10, level = 62, base_min = 1773, base_max = 1971 },
            { id = 25292, rank =  9, level = 60, base_min = 1619, base_max = 1799, cost = 660 },
            { id = 10329, rank =  8, level = 54, base_min = 1272, base_max = 1414 },
            { id = 10328, rank =  7, level = 46, base_min =  968, base_max = 1076 },
            { id =  3472, rank =  6, level = 38, base_min =  717, base_max =  799 },
            { id =  1042, rank =  5, level = 30, base_min =  506, base_max =  569 },
            { id =  1026, rank =  4, level = 22, base_min =  322, base_max =  368 },
        },
        FlashOfLight = {
            coeff = 0.429, cast_time = 1.5,
            -- PhDamage SpellData_Paladin (SpellData[19750].ranks); R7/R5
            -- verified against Wowhead spell=27137 / spell=19942.
            { id = 27137, rank = 7, level = 66, base_min = 458, base_max = 513, cost = 180 },
            { id = 19943, rank = 6, level = 58, base_min = 356, base_max = 396 },
            { id = 19942, rank = 5, level = 50, base_min = 278, base_max = 310, cost = 115 },
            { id = 19941, rank = 4, level = 42, base_min = 206, base_max = 231 },
            { id = 19940, rank = 3, level = 34, base_min = 153, base_max = 171 },
            { id = 19939, rank = 2, level = 26, base_min = 102, base_max = 117 },
        },
    },
    priest = {
        GreaterHeal = {
            coeff = 0.857, cast_time = 3.0,
            -- Wowhead spell=25213 / 25210 / 25314 descriptions (PhDamage has
            -- no priest heal data). Learn levels are the class table's
            -- (levels = {68, 63, 60}) -- the sweep-audited authority.
            { id = 25213, rank = 7, level = 68, base_min = 2414, base_max = 2803, cost = 825 },
            { id = 25210, rank = 6, level = 63, base_min = 2107, base_max = 2444, cost = 750 },
            { id = 25314, rank = 5, level = 60, base_min = 2006, base_max = 2235, cost = 710 },
        },
        FlashHeal = {
            coeff = 0.429, cast_time = 1.5,
            -- Wowhead spell=25235 / 25233 / 10917. Class table
            -- levels = {67, 61, 56}.
            { id = 25235, rank = 9, level = 67, base_min = 1116, base_max = 1295, cost = 470 },
            { id = 25233, rank = 8, level = 61, base_min =  931, base_max = 1078, cost = 400 },
            { id = 10917, rank = 7, level = 56, base_min =  833, base_max =  979, cost = 380 },
            -- Classic ranks R1-R6 (2026-09-15 SoD healer wave): the SoD client
            -- (level 60) learns these, so the SoD priest FH lane needs them
            -- for a meaningful deficit fit. Bases from Wowhead description
            -- text per page (spell=2061/9472/9473/9474/10915/10916, TBC db);
            -- levels per the class table; costs from the same pages.
            { id = 10916, rank = 6, level = 51, base_min =  662, base_max =  783, cost = 315 },
            { id = 10915, rank = 5, level = 43, base_min =  534, base_max =  633, cost = 265 },
            { id =  9474, rank = 4, level = 35, base_min =  414, base_max =  492, cost = 215 },
            { id =  9473, rank = 3, level = 27, base_min =  339, base_max =  406, cost = 185 },
            { id =  9472, rank = 2, level = 19, base_min =  269, base_max =  325, cost = 155 },
            { id =  2061, rank = 1, level =  1, base_min =  202, base_max =  247, cost = 125 },
        },
        -- WotLK (3.3.5) priest families (2026-09-16 wave): era-distinct
        -- datasets kept SEPARATE from the TBC families because the eras
        -- disagree on both membership and values -- WotLK adds FH R10 48071
        -- (req 79) / GH R8 48063 (req 78), resurrects the four classic GH
        -- ranks the TBC ladder had replaced (2060/10963/10964/10965), and
        -- retunes two shared rows (FH 25235 1121-1300 vs TBC 1116-1295; GH
        -- 25213 2433-2822 vs TBC 2414-2803). Every row verified 2026-09-16
        -- against the wotlk-client tooltips (nether.wowhead.com
        -- /wotlk/tooltip/spell/<id>: heal range + Requires level + DBC
        -- SpellLevel); the two heads exact-match wowsims/wotlk@563e4a08
        -- (sim/priest/flash_heal.go Roll(1896,2203), greater_heal.go
        -- Roll(3980,4621)). Learn levels: the WotLK bridge
        -- (wowhead_data_bridge_spell_index_wotlk) where present, the tooltip
        -- Requires-level otherwise (the heads); the two sources agree
        -- wherever both exist. Coefficients are the WotLK ones (wowsims
        -- 0.8057 / 1.6114 = the 1.88 wrath healing multiplier on the TBC
        -- 1.5/3.5 ratios). WotLK costs are %-of-base-mana (18% / 32% at
        -- EVERY rank), so cost stays nil and HPM is correctly no-signal --
        -- downranking saves no mana in WotLK; the fit is pure overheal
        -- avoidance. DBC SpellLevel is 80 for every rank on the 3.3.5
        -- client, so the wrath penalty branch (downrank_penalty,
        -- player_level > 70) never scales these rows' bonus term below 1.0
        -- at any caster level <= 82 -- at bonus 0 the fit runs on raw base
        -- averages. Era arg: none of these rows carry era-divergent values,
        -- so build_ladder is called era-less; an era arg would apply
        -- nothing (fail-closed).
        WotlkFlashHeal = {
            coeff = 0.8057, cast_time = 1.5,
            { id = 48071, rank = 10, level = 79, base_min = 1896, base_max = 2203 },
            { id = 25235, rank =  9, level = 67, base_min = 1121, base_max = 1300 },
            { id = 25233, rank =  8, level = 61, base_min =  931, base_max = 1078 },
            { id = 10917, rank =  7, level = 56, base_min =  833, base_max =  979 },
            { id = 10916, rank =  6, level = 50, base_min =  662, base_max =  783 },
            { id = 10915, rank =  5, level = 44, base_min =  534, base_max =  633 },
            { id =  9474, rank =  4, level = 38, base_min =  414, base_max =  492 },
            { id =  9473, rank =  3, level = 32, base_min =  339, base_max =  406 },
            { id =  9472, rank =  2, level = 26, base_min =  269, base_max =  325 },
            { id =  2061, rank =  1, level = 20, base_min =  202, base_max =  247 },
        },
        WotlkGreaterHeal = {
            coeff = 1.6114, cast_time = 3.0,
            { id = 48063, rank = 8, level = 78, base_min = 3980, base_max = 4621 },
            { id = 25213, rank = 7, level = 68, base_min = 2433, base_max = 2822 },
            { id = 25210, rank = 6, level = 63, base_min = 2107, base_max = 2444 },
            { id = 25314, rank = 5, level = 60, base_min = 2006, base_max = 2235 },
            { id = 10965, rank = 4, level = 58, base_min = 1835, base_max = 2044 },
            { id = 10964, rank = 3, level = 52, base_min = 1470, base_max = 1642 },
            { id = 10963, rank = 2, level = 46, base_min = 1178, base_max = 1318 },
            { id =  2060, rank = 1, level = 40, base_min =  924, base_max = 1039 },
        },
    },
    shaman = {
        -- Healing Wave / Lesser Healing Wave: full per-rank data from
        -- PhDamage SpellData_Shaman (SpellData[331]/[8004].ranks @ 22b8ed92);
        -- R12/R11/R10 and LHW R7 heads verified against Wowhead spell=25396 /
        -- 25391 / 25357 / 25420 descriptions (exact match). Costs kept only
        -- where the Wowhead page was read (25396=720, 25391=655, 25357=620,
        -- 10396=560, 25420=440).
        HealingWave = {
            coeff = 0.857, cast_time = 3.0,
            { id = 25396, rank = 12, level = 70, base_min = 2134, base_max = 2436, cost = 720 },
            { id = 25391, rank = 11, level = 63, base_min = 1756, base_max = 2001, cost = 655 },
            { id = 25357, rank = 10, level = 60, base_min = 1647, base_max = 1878, cost = 620 },
            { id = 10396, rank =  9, level = 56, base_min = 1394, base_max = 1589, cost = 560 },
            { id = 10395, rank =  8, level = 48, base_min = 1040, base_max = 1191 },
            { id =  8005, rank =  7, level = 40, base_min =  759, base_max =  874 },
            { id =   959, rank =  6, level = 32, base_min =  552, base_max =  639 },
            { id =   939, rank =  5, level = 24, base_min =  389, base_max =  454 },
            { id =   913, rank =  4, level = 18, base_min =  279, base_max =  328 },
            { id =   547, rank =  3, level = 12, base_min =  136, base_max =  163 },
            { id =   332, rank =  2, level =  6, base_min =   69, base_max =   83 },
            { id =   331, rank =  1, level =  1, base_min =   36, base_max =   47 },
        },
        LesserHealingWave = {
            coeff = 0.429, cast_time = 1.5,
            { id = 25420, rank = 7, level = 66, base_min = 1051, base_max = 1198, cost = 440 },
            { id = 10468, rank = 6, level = 60, base_min =  853, base_max =  949 },
            { id = 10467, rank = 5, level = 52, base_min =  649, base_max =  723 },
            { id = 10466, rank = 4, level = 44, base_min =  473, base_max =  529 },
            { id =  8010, rank =  3, level = 36, base_min =  349, base_max =  394 },
            { id =  8008, rank =  2, level = 28, base_min =  257, base_max =  292 },
            { id =  8004, rank =  1, level = 20, base_min =  170, base_max =  195 },
        },
    },
    druid = {
        -- Healing Touch direct ranks. PhDamage SpellData_Druid
        -- (SpellData[5185].ranks @ 22b8ed92) with three TBC-tail corrections:
        -- Wowhead's TBC description (2.4.3 client, which a 2.5.5 realm runs)
        -- disagrees with PhDamage for R12/R13 (26978: 2401-2827, 26979:
        -- 2715-3206; PhDamage carries pre-2.4 sizes there, ~0.84x) while
        -- agreeing for R10/R11 and every shaman rank checked. Wowhead wins
        -- for the tail. Costs kept only where the page was read (26979=935,
        -- 26978=820, 25297=800, 9889=720). HoTs (Rej/Regrowth/Lifebloom)
        -- deliberately excluded: not deficit-driven, lanes are refresh-based.
        HealingTouch = {
            coeff = 1.0, cast_time = 3.5,
            { id = 26979, rank = 13, level = 69, base_min = 2715, base_max = 3206, cost = 935 },
            { id = 26978, rank = 12, level = 62, base_min = 2401, base_max = 2827, cost = 820 },
            { id = 25297, rank = 11, level = 60, base_min = 2303, base_max = 2714, cost = 800 },
            { id =  9889, rank = 10, level = 56, base_min = 1923, base_max = 2263, cost = 720 },
            { id =  9888, rank =  9, level = 50, base_min = 1545, base_max = 1826 },
            { id =  9758, rank =  8, level = 44, base_min = 1225, base_max = 1453 },
            { id =  8903, rank =  7, level = 38, base_min =  958, base_max = 1143 },
            { id =  6778, rank =  6, level = 32, base_min =  762, base_max =  914 },
            { id =  5189, rank =  5, level = 26, base_min =  589, base_max =  712 },
            { id =  5188, rank =  4, level = 20, base_min =  376, base_max =  459 },
            { id =  5187, rank =  3, level = 14, base_min =  204, base_max =  253 },
            { id =  5186, rank =  2, level =  8, base_min =   94, base_max =  119 },
            { id =  5185, rank =  1, level =  1, base_min =   40, base_max =   55 },
        },
    },
}

-- Era-keyed row overrides for ids a non-TBC client reuses with different
-- values. Shape: M.ERA_OVERRIDES[era][class_key][spell_key][id] = partial
-- row (only the differing fields need to be present). Applied exclusively
-- by M.build_ladder when the caller passes an era; nil/unknown era applies
-- nothing (fail-closed), and M.find_rank_by_id stays the TBC-table answer.
-- Verified 2026-09-15 against Wowhead's classic pages (the dataset a SoD
-- client runs):
--   druid HealingTouch 25297: classic 2267-2677 @800 mana vs TBC 2303-2714
--   @800 (cost verified identical on both pages).
--   druid HealingTouch 9889 (R10): classic 1916-2257 vs TBC 1923-2263 @720.
--   priest FlashHeal 10917 (R7): classic 828-975 vs TBC 833-979 @380
--   (costs verified identical on both pages for both rows).
-- Shaman (2026-09-15, own verified pass: every SoD-reachable HW/LHW id
-- checked against Wowhead's classic pages): HW 25357 1620-1850, HW
-- 10396 1389-1583 and LHW 10468 832-928 diverge; all other HW (10395,
-- 8005, 959, 939, 913, 547, 332, 331) and LHW (10467, 10466, 8010, 8008,
-- 8004) ids agree exactly. 10468's cost (380, nil in the TBC row) was
-- also read off the classic page.
-- Full-ladder audit (2026-09-15): every SoD-reachable id in the four
-- value-consuming ladders is now verified against Wowhead's classic pages.
-- HealingWave/LesserHealingWave: 25357, 10396 and 10468 diverge (applied by
-- the shaman-override change), the other 11 agree. HealingTouch: 25297 and
-- 9889 diverge, R1-R9 agree exactly. FlashHeal: 10917 diverges, R1-R6 agree
-- exactly. The TBC-only tails (HT R12/R13, FH R8/R9) are level 61+ and
-- unreachable in SoD.
--   priest GreaterHeal 25314 (R5): classic 1966-2194 vs TBC 2006-2235 @710
--   (classic page read 2026-09-15; the only vanilla-reachable GH row).
-- Paladin (2026-09-16 vanilla holy wave, nether.wowhead.com classic tooltips):
--   every vanilla-reachable HL/FoL id checked; only two diverge. HL R9 25292
--   classic 1590-1770 vs TBC 1619-1799 @660; FoL R6 19943 classic 348-389 vs
--   TBC 356-396. All others agree exactly: HL R8 10329 1272-1414, R7 10328
--   968-1076, R6 3472 717-799, R5 1042 506-569, R4 1026 322-368; FoL R5 19942
--   278-310, R4 19941 206-231, R3 19940 153-171, R2 19939 102-117. HL R1-R3
--   (635/639/647) and FoL R1 (19750) have no TBC base rows, so no override is
--   recorded for them (adding rows would break the era-less TBC ladder shape).
-- Vanilla note: vanilla clients run the same classic dataset as SoD and
-- load this module era-less through class_sylvanas (no class_vanilla
-- exists); build_ladder therefore aliases era "vanilla" onto the sod
-- bucket (fail-closed for anything else) and takes an optional max_level
-- ceiling so unlearnable TBC-tail ranks are excluded at build time.
M.ERA_OVERRIDES = {
    sod = {
        druid = {
            HealingTouch = {
                [25297] = { base_min = 2267, base_max = 2677 },
                [ 9889] = { base_min = 1916, base_max = 2257 },
            },
        },
        priest = {
            FlashHeal = {
                [10917] = { base_min =  828, base_max =  975 },
            },
            GreaterHeal = {
                [25314] = { base_min = 1966, base_max = 2194 },
            },
        },
        shaman = {
            HealingWave = {
                [25357] = { base_min = 1620, base_max = 1850 },
                [10396] = { base_min = 1389, base_max = 1583 },
            },
            LesserHealingWave = {
                [10468] = { base_min = 832, base_max = 928, cost = 380 },
            },
        },
        paladin = {
            HolyLight = {
                [25292] = { base_min = 1590, base_max = 1770 },
            },
            FlashOfLight = {
                [19943] = { base_min = 348, base_max = 389 },
            },
        },
    },
}

-- ---------------------------------------------------------------------------
-- Expected heal for one rank entry.
-- avg(base) + bonus * coeff, with the TBC downrank penalty from
-- NS.PreemptiveHeal (LibHealComm-4.0 formula) applied by rank level.
-- opts.talent_mult multiplies the result (paladin Healing Light 1.12).
-- @return number expected heal (>= 0), number penalty actually applied
-- ---------------------------------------------------------------------------
function M.expected_heal(entry, bonus_healing, opts)
    if type(entry) ~= "table" or type(entry.base_min) ~= "number"
        or type(entry.base_max) ~= "number" then return 0, 1.0 end

    local bonus = (type(bonus_healing) == "number" and bonus_healing > 0)
        and bonus_healing or 0
    local coeff = type(entry.coeff) == "number" and entry.coeff or 0
    local base = (entry.base_min + entry.base_max) / 2

    -- player_level opt (2026-09-15 SoD healer wave): the classic penalty
    -- divisor is the CASTER level, 70 on TBC and 60 on SoD. Default 70
    -- keeps every existing caller numbers byte-identical. Hoisted above the
    -- penalty lookup by the 2026-09-16 WotLK wave: the application shape
    -- below branches on it too.
    local player_level = (opts and type(opts.player_level) == "number"
        and opts.player_level > 0) and opts.player_level or 70
    local penalty = 1.0
    local pre = PreemptiveHeal
    if pre and type(pre.downrank_penalty) == "function"
        and type(entry.level) == "number" then
        local ok, p = pcall(pre.downrank_penalty, entry.level, player_level)
        if ok and type(p) == "number" then penalty = p end
    end

    local heal
    if player_level > 70 then
        -- WotLK 3.0+ (wrath): the level factor scales the BONUS-healing
        -- term only -- LibHealComm-4.0's isWrath branch multiplies the
        -- spell-power portion, and TrinityCore 3.3.5
        -- (Unit::CalculateSpellpowerCoefficientLevelPenalty) scales the
        -- coefficient factor; base heals are never level-penalized in
        -- WotLK. Classic/TBC eras (player_level <= 70) keep the historical
        -- whole-sum shape unchanged.
        heal = base + bonus * coeff * penalty
    else
        heal = (base + bonus * coeff) * penalty
    end
    if opts and opts.talent_mult then heal = heal * opts.talent_mult end
    return math_floor(heal + 0.5), penalty
end

-- Expected heal for a ladder entry built by build_ladder (carries its own
-- coeff and talent_mult).
function M.expected_heal_ladder(entry, bonus_healing, opts)
    if type(entry) ~= "table" or type(entry.base_min) ~= "number" then return 0 end
    local o = { talent_mult = entry.talent_mult }
    if type(opts) == "table" then
        for k, v in pairs(opts) do o[k] = v end
    end
    return M.expected_heal(entry, bonus_healing, o)
end

-- ---------------------------------------------------------------------------
-- HPM: heal per mana. Cost nil/0 (unverified or free) returns 0 so callers
-- treat it as "no cost signal" instead of "infinite efficiency".
-- ---------------------------------------------------------------------------
function M.heal_per_mana(entry, bonus_healing, opts)
    local heal = M.expected_heal(entry, bonus_healing, opts)
    local cost = type(entry) == "table" and type(entry.cost) == "number"
        and entry.cost or 0
    if cost <= 0 then return 0 end
    return heal / cost
end

-- ---------------------------------------------------------------------------
-- Absolute HP deficit of a raw engine unit, via pcall-guarded getters.
-- Returns nil when health data is unavailable (fail-closed to legacy).
-- ---------------------------------------------------------------------------
function M.unit_deficit(unit)
    if not unit then return nil end
    local max_hp, cur
    local ok1, v1 = pcall(function()
        local fn = unit.get_max_health
        return type(fn) == "function" and fn(unit) or nil
    end)
    if ok1 then max_hp = v1 end
    local ok2, v2 = pcall(function()
        local fn = unit.get_health
        return type(fn) == "function" and fn(unit) or nil
    end)
    if ok2 then cur = v2 end
    if type(max_hp) ~= "number" or type(cur) ~= "number" or max_hp <= 0 then
        return nil
    end
    local d = max_hp - cur
    if d > 0 then return d end
    return nil
end

-- ---------------------------------------------------------------------------
-- Castable deficit-fit pick over a ladder (newest rank first).
-- Returns { entry, expected } for the first CASTABLE rank whose expected
-- heal fits deficit * tolerance; when every allowed rank overshoots, the
-- biggest allowed castable rank is the right answer. Returns nil when the
-- ladder carries no per-rank data (legacy shape) or nothing is castable --
-- callers then fall back to their legacy first-ready walk.
-- opts: { is_ready = fn(spell, unit), unit = u, tolerance = number,
--         ceiling = rank_entry (largest allowed rank, e.g. mana tier) }
-- ---------------------------------------------------------------------------
local FIT_TOLERANCE = 1.3  -- 30% headroom, matching the paladin selector's
                           -- existing deficit * 1.3 convention.

function M.pick_castable(ranks, deficit, bonus_healing, opts)
    if type(ranks) ~= "table" or #ranks == 0 then return nil end
    opts = opts or {}
    -- Legacy ladders (no base data on the first entry): defer to the caller.
    local first = ranks[1]
    if type(first) ~= "table" or type(first.base_min) ~= "number" then
        return nil
    end
    local is_ready = opts.is_ready
    local unit = opts.unit
    local tol = (type(opts.tolerance) == "number" and opts.tolerance > 0)
        and opts.tolerance or FIT_TOLERANCE
    -- opts.ceiling: a rank entry marking the LARGEST rank the caller allows
    -- (mana-tier caps). Only entries at or after the ceiling's position in
    -- the array (same size or smaller) may be cast. Within that allowed set
    -- the newest rank that fits the deficit wins; if none fits, the ceiling
    -- rank itself (biggest allowed) is correct; if the ceiling entry is not
    -- castable, nil is returned and the caller falls back to its legacy
    -- walk (fail-closed to previous behavior). An unknown/nil ceiling leaves
    -- the walk unrestricted over the whole ladder.
    local is_ready = opts.is_ready
    local unit = opts.unit
    local tol = (type(opts.tolerance) == "number" and opts.tolerance > 0)
        and opts.tolerance or FIT_TOLERANCE
    local ceiling = opts.ceiling
    local start_i = 1
    if ceiling and type(ceiling.id) == "number" then
        for j = 1, #ranks do
            local e = ranks[j]
            if type(e) == "table" and e.id == ceiling.id then
                start_i = j
                break
            end
        end
        if start_i == 1 and ceiling.id ~= (ranks[1] and ranks[1].id) then
            -- Ceiling id not present in this ladder: treat as unrestricted.
            start_i = 1
            ceiling = nil
        end
    else
        ceiling = nil
    end
    local first_castable, first_castable_expected
    for i = start_i, #ranks do
        local e = ranks[i]
        if e and e.spell then
            local ready = true
            if is_ready and unit then
                local ok, r = pcall(is_ready, e.spell, unit)
                ready = (ok and r == true)
            end
            if ready then
                local expected = M.expected_heal_ladder(e, bonus_healing, 
                    { player_level = opts.player_level })
                if expected > 0 and expected <= deficit * tol then
                    return { entry = e, expected = expected }
                end
                if not first_castable then
                    first_castable, first_castable_expected = e, expected
                end
            end
        end
    end
    -- No allowed rank fits: the biggest allowed castable rank is right.
    -- (With a ceiling that is the ceiling entry itself when castable; the
    -- walk starts there, so first_castable IS the ceiling in that case.)
    if first_castable then
        return { entry = first_castable, expected = first_castable_expected }
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Deficit-fit selection WITHOUT castability (pure math; tests + selectors
-- that handle readiness themselves). Falls back to max rank when the deficit
-- exceeds every rank or is nil/<= 0 (legacy behavior), never to "no cast".
-- opts.hpm: pick the best heal-per-mana rank that still covers at least half
-- the deficit (mana-starved mode).
-- @return rank_entry, label, expected_heal
-- ---------------------------------------------------------------------------
function M.heal_rank_for_deficit(ranks, deficit, bonus_healing, opts)
    if type(ranks) ~= "table" or #ranks == 0 then return nil end
    opts = (type(opts) == "table" and opts) or {}
    local d = (type(deficit) == "number" and deficit > 0) and deficit or nil

    if not d then
        local e = ranks[1]
        return e, "R-max", M.expected_heal(e, bonus_healing, opts)
    end

    if opts.hpm then
        local best, best_hpm, best_heal = nil, -1, 0
        for i = 1, #ranks do
            local e = ranks[i]
            local heal = M.expected_heal(e, bonus_healing, opts)
            if heal >= d * 0.5 then
                local hpm = M.heal_per_mana(e, bonus_healing, opts)
                if hpm > best_hpm then
                    best, best_hpm, best_heal = e, hpm, heal
                end
            end
        end
        if best then
            return best, (opts.label or "R") .. "-hpm", best_heal
        end
        local e = ranks[1]
        return e, "R-max", M.expected_heal(e, bonus_healing, opts)
    end

    for i = 1, #ranks do
        local e = ranks[i]
        local heal = M.expected_heal(e, bonus_healing, opts)
        if heal <= d * FIT_TOLERANCE then
            return e, (opts.label or "R") .. "-" .. tostring(e.rank or e.id), heal
        end
    end
    local e = ranks[1]
    return e, "R-max", M.expected_heal(e, bonus_healing, opts)
end

-- ---------------------------------------------------------------------------
-- Class-table export: build rank ladders in the shape the existing
-- selectors consume ({ spell = <action>, label, base_min, base_max, ... }).
-- make_action(id) is supplied by the caller so this module never depends on
-- core load order at require time.
-- ---------------------------------------------------------------------------
function M.build_ladder(class_key, spell_key, make_action, talent_mult, era, max_level)
    local family = M.RANKS[class_key] and M.RANKS[class_key][spell_key]
    if not family then return nil end
    -- Era alias: 'vanilla' runs the same classic dataset as 'sod' (both are
    -- the 1.12-class engine), so the override bucket is shared. Fail-closed:
    -- any other era name applies nothing. max_level (optional 6th arg, nil =
    -- unchanged) drops ranks the client cannot learn, instead of relying on
    -- pick_castable's is_ready skip.
    if era == "vanilla" then era = "sod" end
    local out = {}
    for i = 1, #family do
        local e = family[i]
        if not (max_level and type(e.level) == "number" and e.level > max_level) then
            local ov = (era and M.ERA_OVERRIDES[era] and M.ERA_OVERRIDES[era][class_key]
                and M.ERA_OVERRIDES[era][class_key][spell_key]
                and M.ERA_OVERRIDES[era][class_key][spell_key][e.id]) or nil
            out[#out + 1] = {
                spell = make_action(e.id),
                label = "R" .. tostring(e.rank),
                id = e.id,
                rank = e.rank,
                level = e.level,
                base_min = ov and ov.base_min or e.base_min,
                base_max = ov and ov.base_max or e.base_max,
                cost = ov and ov.cost or e.cost,
                coeff = family.coeff,
                cast_time = family.cast_time,
                talent_mult = talent_mult,
            }
        end
    end
    return out
end

-- Map a concrete spell id back to its rank entry (any class/family). Lets
-- (TBC-table authority: era overrides apply in build_ladder only.)
-- HealerDeficit-style gates use the verified per-rank base instead of a
-- max-rank ballpark when the caller knows the exact rank being cast.
-- Deterministic precedence (2026-09-16 WotLK wave): era-suffixed families
-- (Wotlk*) resolve AFTER the canonical TBC/classic families, so an id that
-- exists in both keeps the documented TBC-table answer no matter what order
-- pairs() visits the tables in (25213: TBC 2414 wins over wrath 2433).
function M.find_rank_by_id(spell_id)
    if type(spell_id) ~= "number" then return nil end
    for pass = 1, 2 do
        for _class_key, families in pairs(M.RANKS) do
            for _spell_key, family in pairs(families) do
                local is_era = type(_spell_key) == "string" and _spell_key:sub(1, 5) == "Wotlk"
                if (pass == 1) ~= is_era then
                    for i = 1, #family do
                        if family[i].id == spell_id then return family[i] end
                    end
                end
            end
        end
    end
    return nil
end

return M
