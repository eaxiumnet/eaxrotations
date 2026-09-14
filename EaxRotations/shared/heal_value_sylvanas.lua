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

    local penalty = 1.0
    local pre = PreemptiveHeal
    if pre and type(pre.downrank_penalty) == "function"
        and type(entry.level) == "number" then
        local ok, p = pcall(pre.downrank_penalty, entry.level, 70)
        if ok and type(p) == "number" then penalty = p end
    end

    local heal = (base + bonus * coeff) * penalty
    if opts and opts.talent_mult then heal = heal * opts.talent_mult end
    return math_floor(heal + 0.5), penalty
end

-- Expected heal for a ladder entry built by build_ladder (carries its own
-- coeff and talent_mult).
function M.expected_heal_ladder(entry, bonus_healing)
    if type(entry) ~= "table" or type(entry.base_min) ~= "number" then return 0 end
    return M.expected_heal(entry, bonus_healing,
        { talent_mult = entry.talent_mult })
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
                local expected = M.expected_heal_ladder(e, bonus_healing)
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
function M.build_ladder(class_key, spell_key, make_action, talent_mult)
    local family = M.RANKS[class_key] and M.RANKS[class_key][spell_key]
    if not family then return nil end
    local out = {}
    for i = 1, #family do
        local e = family[i]
        out[i] = {
            spell = make_action(e.id),
            label = "R" .. tostring(e.rank),
            id = e.id,
            rank = e.rank,
            level = e.level,
            base_min = e.base_min,
            base_max = e.base_max,
            cost = e.cost,
            coeff = family.coeff,
            cast_time = family.cast_time,
            talent_mult = talent_mult,
        }
    end
    return out
end

-- Map a concrete spell id back to its rank entry (any class/family). Lets
-- HealerDeficit-style gates use the verified per-rank base instead of a
-- max-rank ballpark when the caller knows the exact rank being cast.
function M.find_rank_by_id(spell_id)
    if type(spell_id) ~= "number" then return nil end
    for _class_key, families in pairs(M.RANKS) do
        for _spell_key, family in pairs(families) do
            for i = 1, #family do
                if family[i].id == spell_id then return family[i] end
            end
        end
    end
    return nil
end

return M
