-- test_paladin_holy_forever.lua -- unit pins for the first _forever delta spec.
-- WHAT:  holy_forever.lua contract: baseline capture + re-register splice,
--        lane set and ordering (healing-priority head, fillers above the
--        solo block), by-name dormancy on nil lookups, matcher behavior for
--        every lane (IoL weave, Light's Vigil mark branches, deficit-fit
--        top-off, Holy Shock core, Holy Strike weave, Seal/Judgement of the
--        Crusader support), execute-time spell resolution, and the
--        zero-numeric-literal audit contract.
-- WHEN:  standalone -- lua EaxRotations/tests/test_paladin_holy_forever.lua
--        or via run_rotation_tests.lua.
-- WHY:   the delta replaces the whole "holy" playstyle on Forever clients;
--        a lost baseline lane, a lane that fires while dormant-resolved, a
--        heal lane that shadows an emergency band, a mark lane that ignores
--        the Holy Shock readiness window, or a hardcoded spell ID (which the
--        forever audit must catch on beta day) each silently break day-1
--        healing. Pin them here.
-- SAFETY: fully mocked NS + require (fake baseline module); no real spec
--         logic beyond the delta file itself.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;" .. package.path

local pass, fail = 0, 0
local function assert_true(v, label)
    if v then pass = pass + 1 else fail = fail + 1; print("  FAIL: " .. tostring(label)) end
end
local function assert_eq(a, b, label)
    if a == b then pass = pass + 1
    else fail = fail + 1; print("  FAIL: " .. tostring(label) .. " (expected " .. tostring(b) .. ", got " .. tostring(a) .. ")") end
end

-- ---------------------------------------------------------------------------
-- Mock NS + registry (records the final registration) and a fake baseline
-- module: holy_vanilla's registration shape (strategies + get_state) with a
-- splice anchor lane and an emergency lane.
-- ---------------------------------------------------------------------------
local registered = nil
local cast_log = {}
local SEAL_ACTION_REF = nil
local PLAYER_UNIT_REF = {}
local FRIENDLY_UNIT_REF = {}
local NS = {
    settings = {},
    log = function() end,
    PLAYER_UNIT = PLAYER_UNIT_REF,
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    PaladinSpells = {
        HolyLight = { ids = { 27136 } },
        HolyShock = { ids = { 20473 } },
        Judgement = { ids = { 20271 } },
        SealCrusader = { _meta = { ids = { 20308, 20307, 20306, 20305, 20162 } } },
    },
    spell_action = function(ids, label)
        return { _meta = { ids = ids, label = label } }
    end,
    has_player_buff = function() return false end,
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target, reason = reason }
        return true
    end,
    cooldown_remains = function() return 0 end,
    should_use_long_cd = function() return true end,
    unit_distance = function() return 5 end,
    buff_up = function() return false end,
    debuff_remains = function() return 0 end,
    get_friendly_target_entry = function() return nil end,
    cast_best_heal_rank = function() return nil end,
    FLASH_OF_LIGHT_RANKS = { { spell = "FoL-R6", label = "R6", base_min = 356, base_max = 396 } },
    HOLY_LIGHT_RANKS = { { spell = "HL-R9", label = "R9", base_min = 1619, base_max = 1799 } },
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "holy",
    strategies = {
        { name = "FakeEmergencyLane", matches = function() return false end, execute = function() return false end },
        { name = "SealOfRighteousnessSolo", matches = function() return false end, execute = function() return false end },
    },
    options = { get_state = function() return { fake = true } end },
}

local orig_require = require
local pending_by_name, pending_maxrank, pending_buff = {}, {}, {}
function require(path)
    if path == "shared/wowhead_data_bridge_spell_index_forever_sylvanas" then
        return { spell_index_by_name_forever = pending_by_name,
                 spell_maxrank_by_name_forever = pending_maxrank,
                 spell_buff_by_name_forever = pending_buff }
    end
    if path == "classes/paladin/holy_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/paladin/holy_vanilla' not found", 0)
    end
    if path == "shared/spec_kit_sylvanas" then
        return { setting = function(_, key, default) return default end }
    end
    return orig_require(path)
end

-- Full-kit sentinel maps (distinct per mirror so mirror selection is pinned,
-- not just resolution): by_name 19000s, maxrank 19100s, buff 19200s.
local function full_by_name()
    return {
        ["Holy Strike"] = 19000,
        ["Light's Vigil"] = 19001,
        ["Infusion of Light"] = 19002,
        ["Seal of the Crusader"] = 19003,
        ["Judgement of the Crusader"] = 19004,
    }
end
local function full_maxrank()
    return {
        ["Holy Strike"] = 19100,
        ["Light's Vigil"] = 19101,
        ["Seal of the Crusader"] = 19103,
        ["Judgement of the Crusader"] = 19104,
    }
end
local function full_buff()
    return {
        ["Infusion of Light"] = 19202,
        ["Light's Vigil"] = 19201,
    }
end

local function load_delta(by_name, maxrank, buff)
    -- The delta pcall-requires the bridge module (Pattern 9 optional-module
    -- shape) instead of reading a never-assigned NS member; the intercepted
    -- require above hands it the three pending mirrors (closure captures --
    -- load_delta's parameters themselves would resolve as nil globals
    -- there). Distinct sentinels per mirror pin MIRROR SELECTION, not just
    -- resolution: a lane reading the wrong mirror sees a different id.
    pending_by_name = by_name or {}
    pending_maxrank = maxrank or {}
    pending_buff = buff or {}
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/paladin/holy_forever.lua")
    if not chunk then error("cannot load delta: " .. tostring(err)) end
    return chunk()
end

local function find_lane(list, name)
    for i, st in ipairs(list) do
        if type(st) == "table" and st.name == name then return i end
    end
    return nil
end

local function fresh_ctx()
    return { in_combat = true, target = {}, has_valid_enemy_target = true, me = {}, settings = {} }
end

local function fresh_state(overrides)
    local s = { lowest = { unit = {}, hp = 60 }, mana_pct = 100, entries = {}, count = 0 }
    if overrides then
        for k, v in pairs(overrides) do s[k] = v end
    end
    return s
end

-- A. Full kit: all bridge names resolve in every mirror; splice +
-- registration shape.
do
    local combined = load_delta(full_by_name(), full_maxrank(), full_buff())
    assert_eq(registered and registered.name, "holy", "A: re-registers the holy playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 7, "A: 7 delta lanes over 2 baseline lanes")
    assert_eq(find_lane(combined, "Forever_InfusionOfLightWeave"), 1, "A: IoL weave is lane #1 (healing priority)")
    assert_eq(find_lane(combined, "Forever_LightsVigilBurst"), 2, "A: Light's Vigil is lane #2")
    assert_eq(find_lane(combined, "Forever_DeficitFitTopoff"), 3, "A: deficit-fit top-off is lane #3")
    local solo = find_lane(combined, "SealOfRighteousnessSolo")
    assert_eq(find_lane(combined, "Forever_HolyShockCore"), solo - 4, "A: Holy Shock core sits just above the solo block")
    assert_eq(find_lane(combined, "Forever_HolyStrikeWeave"), solo - 3, "A: Holy Strike weave follows the core")
    assert_eq(find_lane(combined, "Forever_SealOfTheCrusaderSupport"), solo - 2, "A: SotC seal lane sits above the solo block")
    assert_eq(find_lane(combined, "Forever_JudgementOfTheCrusaderSupport"), solo - 1, "A: SotC judgement lane sits above the solo block")
    assert_true(find_lane(combined, "FakeEmergencyLane") > 3, "A: baseline lanes preserved below the delta head")
end

-- B. Matcher behavior: IoL weave.
do
    local combined = load_delta(full_by_name(), full_maxrank(), full_buff())
    local state = fresh_state()
    local ctx = fresh_ctx()

    local iol = combined[find_lane(combined, "Forever_InfusionOfLightWeave")]
    NS.has_player_buff = function() return true end
    assert_true(iol.matches(ctx, state), "B: IoL weave matches with buff + 40% deficit")
    NS.has_player_buff = function() return false end
    assert_true(not iol.matches(ctx, state), "B: IoL weave dormant without the buff")
    state.lowest.hp = 90 -- deficit 10 < 30
    NS.has_player_buff = function() return true end
    assert_true(not iol.matches(ctx, state), "B: IoL weave skips near-full targets")
    state.lowest.hp = 15 -- below the head floor: LoH/Divine Shield stay reachable
    assert_true(not iol.matches(ctx, state), "B: IoL weave never shadows the last-resort lanes")
    state.lowest.hp = 60
    NS.has_player_buff = function() return false end
end

-- B2. Light's Vigil mark: ally branch, enemy branch, readiness + mana gates,
-- already-marked skip.
do
    local combined = load_delta(full_by_name(), full_maxrank(), full_buff())
    local state = fresh_state({ heavy_healing = true })
    local ctx = fresh_ctx()
    local vigil = combined[find_lane(combined, "Forever_LightsVigilBurst")]

    NS.buff_up = function() return false end
    assert_true(vigil.matches(ctx, state), "B2: vigil ally branch fires when heavy healing + HS ready")
    state.mana_pct = 10
    assert_true(not vigil.matches(ctx, state), "B2: vigil respects the hard mana floor")
    state.mana_pct = 100
    NS.buff_up = function(unit, ids) return ids and ids[1] == 19201 end
    assert_true(not vigil.matches(ctx, state), "B2: vigil skips an ally already carrying the mark (buff-mirror id)")
    NS.buff_up = function() return false end

    -- Enemy branch: no heavy healing, healthy group (lowest 95 >= 88).
    state.heavy_healing = false
    state.lowest.hp = 95
    assert_true(vigil.matches(ctx, state), "B2: vigil enemy branch fires on a healthy group with a valid enemy")
    local cast_before = #cast_log
    assert_true(vigil.execute(ctx, state), "B2: vigil enemy branch executes")
    assert_eq(cast_log[#cast_log].target, ctx.target, "B2: enemy branch marks the enemy target")
    assert_true(#cast_log > cast_before, "B2: enemy branch logged a cast")

    -- Marked enemy: skip (debuff mirror id).
    NS.debuff_remains = function(unit, ids) return (ids and ids[1] == 19201) and 20 or 0 end
    assert_true(not vigil.matches(ctx, state), "B2: vigil skips an enemy already carrying the mark")
    NS.debuff_remains = function() return 0 end

    -- Holy Shock on cooldown: hold the mark (it pays off on the next shock).
    NS.cooldown_remains = function(spell) return spell == NS.PaladinSpells.HolyShock and 4 or 0 end
    assert_true(not vigil.matches(ctx, state), "B2: vigil holds while Holy Shock is on cooldown")
    NS.cooldown_remains = function() return 0 end

    -- Healer-first: a hurt group that is not in heavy healing keeps the ally branch off.
    state.lowest.hp = 60
    assert_true(not vigil.matches(ctx, state), "B2: ally branch requires the heavy-healing triage signal")
end

-- B3. Deficit-fit top-off: band gates, zero-deficit skip, friendly target
-- preference, execute fit + escalation fallback.
do
    local combined = load_delta(full_by_name(), full_maxrank(), full_buff())
    local ctx = fresh_ctx()
    local fit = combined[find_lane(combined, "Forever_DeficitFitTopoff")]

    local state = fresh_state({ lowest = { unit = {}, hp = 90, deficit = 500 } })
    assert_true(fit.matches(ctx, state), "B3: fit lane matches a 90% entry with a positive deficit")
    state.lowest.hp = 100
    state.lowest.deficit = 0
    assert_true(not fit.matches(ctx, state), "B3: zero-deficit target never fires (hook skip)")
    state.lowest.hp = 90 -- inside the band, explicit zero deficit: the hook-skip gate alone must hold
    state.lowest.deficit = 0
    state.lowest.effective_deficit = 0
    assert_true(not fit.matches(ctx, state), "B3: in-band zero-deficit target never fires (hook skip)")
    state.lowest.effective_deficit = nil
    state.lowest.hp = 60
    state.lowest.deficit = 4000
    assert_true(not fit.matches(ctx, state), "B3: fit lane never touches the baseline emergency band")
    state.lowest.hp = 97
    state.lowest.deficit = 300
    assert_true(not fit.matches(ctx, state), "B3: fit lane respects the top-off ceiling")
    state.lowest.hp = 90
    state.lowest.deficit = 500
    state.moving = true
    assert_true(not fit.matches(ctx, state), "B3: fit lane holds while moving")
    state.moving = false
    state.mana_pct = 5
    assert_true(not fit.matches(ctx, state), "B3: fit lane respects the mana floor")
    state.mana_pct = 100

    -- Friendly target is worse than the group's lowest: it wins the frame.
    local friendly_entry = { unit = FRIENDLY_UNIT_REF, hp_pct = 80, effective_hp = 80, is_player = true }
    NS.get_friendly_target_entry = function() return friendly_entry end
    assert_true(fit.matches(ctx, state), "B3: fit lane matches when the friendly target is worse")
    local ft = friendly_entry
    cast_log = {}
    NS.cast_best_heal_rank = function(ranks, entry, context, label)
        assert_eq(entry.unit, ft.unit, "B3: fit targets the friendly unit")
        return "FIT_FOL", "FoL R6", 420
    end
    assert_true(fit.execute(ctx, state), "B3: fit lane executes on the friendly target")
    assert_eq(cast_log[1] and cast_log[1].spell, "FIT_FOL", "B3: fit lane casts the fitted Flash rank")
    assert_eq(cast_log[1] and cast_log[1].target, ft.unit, "B3: fit cast lands on the friendly unit")

    -- Escalation fallback: the fit says Flash cannot cover the deficit.
    NS.get_friendly_target_entry = function() return nil end
    state.lowest.deficit = 4000
    state.lowest.hp = 90
    cast_log = {}
    local calls = 0
    NS.cast_best_heal_rank = function(ranks, entry, context, label)
        calls = calls + 1
        if calls == 1 then return "FIT_FOL", "FoL R6", 420 end
        return "FIT_HL", "HL R9", 1700
    end
    assert_true(fit.execute(ctx, state), "B3: fit lane escalates when Flash undershoots")
    assert_eq(calls, 2, "B3: escalation calls the hook twice (Flash then Holy Light)")
    assert_eq(cast_log[1] and cast_log[1].spell, "FIT_HL", "B3: escalation casts the Holy Light fit")

    -- No fit available: the lane declines instead of casting blindly.
    NS.cast_best_heal_rank = function() return nil end
    assert_true(not fit.execute(ctx, state), "B3: no fit -> no cast (fallback is decline)")
    NS.cast_best_heal_rank = function() return nil end
end

-- B4. Seal/Judgement of the Crusader support: seal lane, judge lane, gates.
do
    local combined = load_delta(full_by_name(), full_maxrank(), full_buff())
    local ctx = fresh_ctx()
    local state = fresh_state({ target_hp_pct = 80 })
    local seal = combined[find_lane(combined, "Forever_SealOfTheCrusaderSupport")]
    local judge = combined[find_lane(combined, "Forever_JudgementOfTheCrusaderSupport")]

    NS.debuff_remains = function() return 0 end
    NS.buff_up = function() return false end
    assert_true(seal.matches(ctx, state), "B4: seal lane fires while the target lacks JoC")
    assert_true(not judge.matches(ctx, state), "B4: judge lane holds without the seal up")
    cast_log = {}
    assert_true(seal.execute(ctx, state), "B4: seal lane executes")
    SEAL_ACTION_REF = cast_log[1] and cast_log[1].spell
    assert_eq(SEAL_ACTION_REF and SEAL_ACTION_REF._meta and SEAL_ACTION_REF._meta.ids[1], 19103,
        "B4: seal lane casts the maxrank-sentinel seal action")
    assert_eq(cast_log[1] and cast_log[1].target, NS.PLAYER_UNIT, "B4: seal lane casts on self")

    NS.buff_up = function(unit, ids)
        if type(ids) ~= "table" then return false end
        for i = 1, #ids do
            if ids[i] == 19103 or ids[i] == 19003 then return true end
        end
        return false
    end
    assert_true(not seal.matches(ctx, state), "B4: seal lane holds while SotC is already up")
    assert_true(judge.matches(ctx, state), "B4: judge lane fires with SotC up and no JoC")
    cast_log = {}
    assert_true(judge.execute(ctx, state), "B4: judge lane executes")
    assert_eq(cast_log[1] and cast_log[1].spell, NS.PaladinSpells.Judgement, "B4: judge lane casts the shared Judgement action")

    NS.debuff_remains = function(unit, ids)
        for i = 1, #ids do
            if ids[i] == 19104 or ids[i] == 19004 then return 20 end
        end
        return 0
    end
    assert_true(not seal.matches(ctx, state), "B4: seal lane holds once the target carries JoC")
    assert_true(not judge.matches(ctx, state), "B4: judge lane holds once the target carries JoC")

    NS.debuff_remains = function() return 0 end
    NS.buff_up = function() return false end
    state.target_hp_pct = 10
    assert_true(not seal.matches(ctx, state), "B4: seal lane respects the boss-hp floor")
    state.target_hp_pct = 80
    state.mana_pct = 10
    assert_true(not seal.matches(ctx, state), "B4: seal lane respects the mana floor")
    state.mana_pct = 100
    ctx.has_valid_enemy_target = false
    assert_true(not seal.matches(ctx, state), "B4: seal lane needs a valid enemy")
    ctx.has_valid_enemy_target = true
end

-- C. Dormancy on nil lookups: empty mirrors leave bridge-gated lanes out,
-- never guessed; the always-resolvable lanes still splice in.
do
    local combined = load_delta({}, {}, {})
    assert_eq(#combined, #FAKE_BASELINE.strategies + 2, "C: 2 bridge-free delta lanes on empty mirrors")
    assert_true(find_lane(combined, "Forever_DeficitFitTopoff"), "C: fit lane present (no bridge ids needed)")
    assert_true(find_lane(combined, "Forever_HolyShockCore"), "C: core lane present")
    assert_true(not find_lane(combined, "Forever_HolyStrikeWeave"), "C: Holy Strike dormant")
    assert_true(not find_lane(combined, "Forever_LightsVigilBurst"), "C: Light's Vigil dormant")
    assert_true(not find_lane(combined, "Forever_InfusionOfLightWeave"), "C: IoL dormant")
    assert_true(not find_lane(combined, "Forever_SealOfTheCrusaderSupport"), "C: SotC seal dormant")
    assert_true(not find_lane(combined, "Forever_JudgementOfTheCrusaderSupport"), "C: SotC judgement dormant")
    local solo = find_lane(combined, "SealOfRighteousnessSolo")
    assert_eq(find_lane(combined, "Forever_HolyShockCore"), solo - 1, "C: core still spliced above the solo block")
end

-- D. Splice fallback: no solo-block anchor means the fillers append.
do
    FAKE_BASELINE.strategies = {
        { name = "FakeEmergencyLane", matches = function() return false end, execute = function() return false end },
    }
    local combined = load_delta({ ["Holy Strike"] = 19000 }, { ["Holy Strike"] = 19100 }, {})
    assert_eq(find_lane(combined, "Forever_HolyStrikeWeave"), #combined, "D: weave appends when the anchor lane is absent")
    assert_eq(find_lane(combined, "Forever_HolyShockCore"), #combined - 1, "D: core appends before the weave")
end

-- G. Mirror selection + execute-time resolution: cast lanes resolve
-- max-rank ids, buff lanes resolve the buff-mirror id -- never the rank-1
-- baseline (distinct sentinels per mirror prove which table each lane read).
do
    local combined = load_delta(full_by_name(), full_maxrank(), full_buff())
    local ctx = fresh_ctx()
    local state = fresh_state({ heavy_healing = true })

    local weave = combined[find_lane(combined, "Forever_HolyStrikeWeave")]
    state.lowest.hp = 96
    assert_true(weave.matches(ctx, state), "G: weave matches")
    cast_log = {}
    assert_true(weave.execute(ctx, state), "G: weave executes")
    assert_eq(cast_log[1] and cast_log[1].spell, 19100, "G: weave casts the maxrank sentinel (not the 19000 baseline)")

    local vigil = combined[find_lane(combined, "Forever_LightsVigilBurst")]
    state.lowest.hp = 60
    state.mana_pct = 100
    cast_log = {}
    assert_true(vigil.execute(ctx, state), "G: vigil ally branch executes")
    assert_eq(cast_log[1] and cast_log[1].spell, 19101, "G: vigil casts the maxrank sentinel")
    assert_eq(cast_log[1] and cast_log[1].target, state.lowest.unit, "G: vigil ally branch casts on the lowest ally")

    local seal = combined[find_lane(combined, "Forever_SealOfTheCrusaderSupport")]
    state.target_hp_pct = 80
    cast_log = {}
    assert_true(seal.execute(ctx, state), "G: seal lane executes")
    SEAL_ACTION_REF = cast_log[1] and cast_log[1].spell
    assert_eq(SEAL_ACTION_REF and SEAL_ACTION_REF._meta and SEAL_ACTION_REF._meta.ids[1], 19103,
        "G: seal action built from the maxrank-mirror sentinel (not the 19003 baseline)")

    local iol = combined[find_lane(combined, "Forever_InfusionOfLightWeave")]
    state.lowest.hp = 60
    NS.has_player_buff = function(id) return id == 19202 end
    assert_true(iol.matches(ctx, state), "G: IoL matches on the buff-mirror sentinel")
    NS.has_player_buff = function(id) return id == 19002 end
    assert_true(not iol.matches(ctx, state), "G: IoL ignores the rank-1 baseline sentinel")
    NS.has_player_buff = function() return false end
end

-- E. Zero numeric spell-ID literals (audit contract): no digits-only table
-- literal in non-comment code lines of the delta source.
do
    local f = io.open("EaxRotations/classes/paladin/holy_forever.lua", "r")
    local content = f and f:read("*a") or ""
    if f then f:close() end
    assert_true(#content > 0, "E: delta source readable")
    local bad = {}
    local line_no = 0
    for line in content:gmatch("[^\r\n]+") do
        line_no = line_no + 1
        if line:match("^%s*%-%-") ~= nil then
            -- comment line: exempt
        else
            for table_part in line:gmatch("(%b{})") do
                local inner = table_part:sub(2, -2)
                if inner:match("^[%s%d,]*$") then
                    for num in inner:gmatch("%d+") do
                        if tonumber(num) >= 100 then bad[#bad + 1] = line_no .. ":" .. num end
                    end
                end
            end
        end
    end
    assert_eq(#bad, 0, "E: zero numeric ID literals in code (found: " .. table.concat(bad, ", ") .. ")")
end

-- F. Baseline load failure is loud (no silently-missing playstyle).
do
    FAKE_BASELINE = nil
    local ok, err = pcall(load_delta, {})
    assert_true(not ok, "F: delta errors when the baseline cannot load")
    assert_true(tostring(err):find("baseline load failed", 1, true) ~= nil, "F: error names the baseline failure")
end

require = orig_require

print(string.format("test_paladin_holy_forever: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
print("PASS paladin_holy_forever")
