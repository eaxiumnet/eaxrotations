-- spec_scorecard.lua -- per-spec S+ metrics for all rotations (Phase 0).
-- WHAT:  Runs the live behavioral battery (behavioral_audit.run_all), classifies
--        every never-firing lane into (a) opt-in / (b) correctly-silent /
--        (c) mock-limitation / (d) dead, computes per-spec test-suite counts from
--        the rotation runner registry, and emits docs/scorecard.md. APL status is
--        "pending" until Phase 2 (APL conformance harness) fills it.
-- WHEN:  `lua tools/spec_scorecard.lua` (writes) or `--check` (drift gate, exit 2
--        on mismatch / stale pins / unclassified lanes — mirrors update_badges.lua).
-- WHY:   The triage docs' "Category counts" paragraphs went stale mid-campaign;
--        this tool makes the (a)/(b)/(c)/(d) split a LIVE, CI-enforced number.
-- USAGE: lua tools/spec_scorecard.lua [--check]
--
-- Drift semantics (--check):
--   * Any live never-lane NOT in LANE_CLASS        -> FAIL (unclassified lane)
--   * Any LANE_CLASS pin NOT in the live never set -> FAIL (stale pin: lane now fires)
--   * Regenerated docs/scorecard.md != on disk     -> FAIL (stale doc)
--   * (d) lanes present                            -> FAIL (dead lanes must stay 0)

local ROOT = arg and arg[0] and arg[0]:match('^(.*)[\\/]tools[\\/]') or '.'
if ROOT == '' then ROOT = '.' end
local CHECK_ONLY = false
for i = 1, (arg and #arg or 0) do if arg[i] == '--check' then CHECK_ONLY = true end end

local function read_file(path)
    local f = io.open(path, 'rb')
    if not f then return nil end
    local s = f:read('*a'); f:close(); return s
end
local function write_file(path, content)
    local f = io.open(path, 'wb')
    if not f then return false end
    f:write(content); f:close(); return true
end

-- ---------------------------------------------------------------------------
-- Lane classification pins (authoritative; supersedes triage-doc paragraphs).
-- Buckets: a = opt-in setting, b = PvP/OOC/situational correctly-silent,
--          c = battery mock-limitation (works live), d = dead lane (must stay 0).
-- Source: never_strategy_triage_dps/non_dps_2026-08-07.md classifications +
--        the live battery never-list (2026-08-09).
-- ---------------------------------------------------------------------------
local LANE_CLASS = {
    druid = {
        balance = {
            HurricaneAoE = 'c', MoonkinForm = 'a', PvP_Cyclone = 'b',
            PvP_EntanglingRoots = 'b', PvP_NaturesGrasp = 'b', RebirthBattleRez = 'c',
        },
        bear = {
            Barkskin = 'a', ChallengingRoar = 'b', EnrageCombat = 'c',
            FaerieFirePull = 'b', FeralChargePull = 'b', Growl = 'b',
            PrePullEnrage = 'b', Swipe = 'c',
        },
        cat = {
            ClawFallback = 'c', MangleFiller = 'c', RakeSnapshot = 'c',
            RipSnapshot = 'c', RipTrick = 'a', ShredTrick = 'a',
            TrackHumanoids = 'b', TravelForm = 'b',
        },
        resto = {
            BearFormFocusedByMelee = 'b', CycloneEnemyHealer = 'b',
            EntanglingRootsMelee = 'b', LifebloomLetBloom = 'c',
            NaturesGraspMelee = 'b', TravelFormReposition = 'c',
        },
    },
    hunter = {
        beast_mastery = {
            FeignDeath = 'b', Misdirection = 'b', Readiness = 'c',
            SerpentStingRefresh = 'c', Trinket = 'c',
        },
        marksmanship = { InCombatAimedShot = 'c', Readiness = 'c' },
        survival = { Readiness = 'c', SerpentStingRefresh = 'c' },
    },
    mage = {
        arcane = { Blink = 'b', Polymorph = 'b' },
        fire = { ManaGemConjure = 'b', Polymorph = 'b' },
        frost = {
            ArcaneMissiles = 'a', Blink = 'b', FireBlast = 'a',
            ManaGemConjure = 'b', Scorch = 'a',
        },
    },
    paladin = {
        holy = {
            BlessingOfFreedomSnare = 'b', BlessingOfProtectionFocusedAlly = 'b',
            ConsecrationSoloAoE = 'c', HammerOfWrathSolo = 'c',
            JudgementOfLightBoss = 'c', JudgementOfWisdomBoss = 'c',
            JudgementSoloRighteousness = 'c', LayOnHandsLastResort = 'c',
        },
        protection = {
            AvengerShield = 'a', AvengingWrath = 'c', BlessingOfProtectionAlly = 'b',
            HammerOfWrath = 'a', Judgement = 'a', LayOnHands = 'c',
            RighteousDefense = 'b', SealOfCommandAoE = 'a',
        },
        retribution = {
            Consecration = 'a', Ret_BlessingFreedom_Ally = 'b',
            Ret_BlessingFreedom_Self = 'b', Ret_Cleanse_Ally = 'c',
            Ret_Cleanse_Self = 'c', Ret_Consecration_ManaDump = 'a',
            Ret_HammerWrath_FleeingPvP = 'b', Ret_Purify_SelfFallback = 'c',
        },
    },
    priest = {
        holy = {
            ClearcastingGreaterHeal = 'c', EncounterReactions = 'b',
            MountedProtection = 'b', SurgeOfLightSmite = 'c',
        },
        shadow = { DispelMagic = 'b', HolyNovaAoE = 'c', SWDCCBreak = 'b' },
        smite = {
            DevouringPlague = 'b', InnerFocus = 'c', SoloRenew = 'c', Starshards = 'b',
        },
    },
    shaman = {
        elemental = {
            ChainHeal = 'c', EarthShockMoving = 'c', ElementalMastery = 'c',
            FrostShockMoving = 'c', TotemicCall = 'c', TremorTotem = 'b',
        },
        enhancement = {
            AutoAttack = 'b', EarthShock = 'c', FireNovaReplacement = 'c',
            GraceOfAirTotemTwist = 'a', ShamanisticRage = 'c', TremorTotem = 'b',
        },
        restoration = { ChainLightning = 'c', LightningShield = 'c', TremorTotem = 'b' },
    },
    warlock = {
        affliction = {
            CC_HowlOfTerror = 'b', PvP_CurseExhaustion = 'b', PvP_CurseTongues = 'b',
        },
        demonology = { Seduction = 'b' },
    },
}

-- ---------------------------------------------------------------------------
-- APL conformance status. Phase 2 (APL harness) flips these to "pass"/"fail".
-- Absent key = "pending".
-- Keys are era-qualified ("wotlk/<spec>") because the harness tests the WotLK
-- spec files while the battery rows are TBC-era; the WotLK status renders in a
-- dedicated section below rather than on the TBC row column.
-- ---------------------------------------------------------------------------
local APL_STATUS = {
    ["wotlk/fire"] = 'pass',
    ["wotlk/affliction"] = 'pass',
    ["wotlk/cat"] = 'pass',
}

-- Lanes that are NOT actionable despite sitting in a bucket: documented
-- correct-suppression / disabled-by-design. Rendered in the Notes section so
-- Phase 3 does not burn time "clearing" a lane that must stay silent.
local LANE_NOTES = {
    ["mage/fire/ManaGemConjure"] = "correctly suppressed in the mock (gem always available) - do not re-triage",
    ["mage/frost/ManaGemConjure"] = "correctly suppressed in the mock (gem always available) - do not re-triage",
    ["priest/shadow/DispelMagic"] = "disabled by design (middleware PartyDispelMagic owns self+party dispel)",
    ["shaman/enhancement/AutoAttack"] = "correctly silent (already auto-attacking)",
}

local BUCKET_LABEL = {
    a = '(a) opt-in',
    b = '(b) correctly-silent',
    c = '(c) mock-limitation',
    d = '(d) DEAD',
}

-- ---------------------------------------------------------------------------
-- Load the battery as a module WITHOUT triggering its standalone report.
-- ---------------------------------------------------------------------------
local battery_path = ROOT .. '/EaxRotations/tests/behavioral_audit.lua'
local chunk, lerr = loadfile(battery_path)
if not chunk then
    io.stderr:write('spec_scorecard: cannot load battery: ' .. tostring(lerr) .. '\n')
    os.exit(3)
end
-- Passing an arg makes select("#", ...) ~= 0, so the standalone print block is skipped.
local ok, battery = pcall(chunk, 'scorecard')
if not ok then
    io.stderr:write('spec_scorecard: battery load failed: ' .. tostring(battery) .. '\n')
    os.exit(3)
end
if type(battery) ~= 'table' or type(battery.run_all) ~= 'function' then
    io.stderr:write('spec_scorecard: battery did not expose run_all()\n')
    os.exit(3)
end

local agg = battery.run_all()
if agg == nil or type(agg) ~= 'table' or agg.reports == nil then
    io.stderr:write('spec_scorecard: battery run_all() returned no reports\n')
    os.exit(3)
end

-- ---------------------------------------------------------------------------
-- Suite counts from the rotation-runner registry (same source as update_badges).
-- ---------------------------------------------------------------------------
local runner_path = ROOT .. '/EaxRotations/tests/run_rotation_tests.lua'
local runner_content = read_file(runner_path)
if not runner_content then
    io.stderr:write('spec_scorecard: cannot read rotation runner: ' .. runner_path .. '\n')
    os.exit(3)
end
local all_test_names = {}
if runner_content then
    for entry in runner_content:gmatch('"([^"]+%.lua)"') do
        local name = entry:gsub('%.lua$', ''):gsub('^test_', '')
        all_test_names[#all_test_names + 1] = name
    end
end
table.sort(all_test_names)

local function word_matches(name, kw)
    return name == kw
        or name:find('^' .. kw .. '_') ~= nil
        or name:find('_' .. kw .. '_') ~= nil
        or name:find('_' .. kw .. '$') ~= nil
end

local function count_suites(class_key, spec_key)
    local class_n, spec_n = 0, 0
    for _, n in ipairs(all_test_names) do
        if word_matches(n, class_key) then class_n = class_n + 1 end
        if word_matches(n, spec_key) then spec_n = spec_n + 1 end
    end
    return class_n, spec_n
end

-- ---------------------------------------------------------------------------
-- Classify + aggregate.
-- ---------------------------------------------------------------------------
local problems = {} -- { {kind=...} } collected for --check / hard-fail

-- Era-qualified APL keys ("wotlk/<spec>") are never looked up by a TBC-era
-- row, so validate ALL values once here — otherwise a typo'd value would
-- render silently in the dedicated section without failing --check.
for ak, av in pairs(APL_STATUS) do
    if av ~= 'pass' and av ~= 'fail' then
        problems[#problems + 1] = {
            kind = 'badapl',
            msg = 'APL_STATUS["' .. tostring(ak) .. '"] = "' .. tostring(av) .. '" (must be pass/fail)',
        }
    end
end

local rows = {}       -- per-spec rows, sorted
local totals = { strategies = 0, never = 0, a = 0, b = 0, c = 0, d = 0 }
local lanes_by_bucket = {} -- [bucket] = { "class/spec: lane", ... }

for _, r in ipairs(agg.reports) do
    local class_key, spec_key = r.class, r.spec
    local pins = (LANE_CLASS[class_key] or {})[spec_key] or {}
    local a, b, c, d = 0, 0, 0, 0
    local lanes = {}
    for _, lane in ipairs(r.never or {}) do
        local bucket = pins[lane]
        if not bucket then
            problems[#problems + 1] = {
                kind = 'unclassified',
                msg = class_key .. '/' .. spec_key .. ': never-lane "' .. lane .. '" has no pin',
            }
            bucket = '?'
        elseif not BUCKET_LABEL[bucket] then
            problems[#problems + 1] = {
                kind = 'badpin',
                msg = class_key .. '/' .. spec_key .. ': lane "' .. lane .. '" has invalid pin "' .. tostring(bucket) .. '"',
            }
            bucket = '?'
        end
        lanes[#lanes + 1] = lane
        if bucket == 'a' then a = a + 1
        elseif bucket == 'b' then b = b + 1
        elseif bucket == 'c' then c = c + 1
        elseif bucket == 'd' then d = d + 1 end
        local key = bucket .. '|' .. class_key .. '/' .. spec_key .. ': ' .. lane
        lanes_by_bucket[bucket] = lanes_by_bucket[bucket] or {}
        lanes_by_bucket[bucket][#lanes_by_bucket[bucket] + 1] = key
    end
    -- Stale-pin check: every pin must still be never-firing (else the pin is outdated).
    for lane, bucket in pairs(pins) do
        local found = false
        for _, live in ipairs(r.never or {}) do if live == lane then found = true break end end
        if not found then
            problems[#problems + 1] = {
                kind = 'stale',
                msg = class_key .. '/' .. spec_key .. ': pin "' .. lane .. '"=' .. bucket ..
                    ' but the lane now FIRES (remove the pin)',
            }
        end
    end
    local class_suites, spec_suites = count_suites(class_key, spec_key)
    local apl = APL_STATUS[spec_key] or APL_STATUS[class_key .. '/' .. spec_key] or 'pending'
    if apl ~= 'pending' and apl ~= 'pass' and apl ~= 'fail' then
        problems[#problems + 1] = {
            kind = 'badapl',
            msg = class_key .. '/' .. spec_key .. ': invalid APL status "' .. tostring(apl) .. '"',
        }
        apl = 'pending'
    end
    rows[#rows + 1] = {
        class = class_key, spec = spec_key,
        strategies = r.strategy_count or 0,
        never = #(r.never or {}),
        a = a, b = b, c = c, d = d,
        class_suites = class_suites, spec_suites = spec_suites,
        apl = apl,
    }
    totals.strategies = totals.strategies + (r.strategy_count or 0)
    totals.never = totals.never + #(r.never or {})
    totals.a = totals.a + a; totals.b = totals.b + b; totals.c = totals.c + c; totals.d = totals.d + d
end
table.sort(rows, function(x, y)
    if x.class == y.class then return x.spec < y.spec end
    return x.class < y.class
end)

-- ---------------------------------------------------------------------------
-- Rating rubric (documented in the emitted doc).
--   S+ : never==0 AND c==0 AND apl=="pass"
--   S  : never==0
--   A  : never<=3
--   B  : never<=6
--   C  : never>=7
--   F  : d>0 (dead lanes)
-- ---------------------------------------------------------------------------
local function rating(r)
    if r.d > 0 then return 'F' end
    if r.never == 0 then
        if r.c == 0 and r.apl == 'pass' then return 'S+' end
        return 'S'
    end
    if r.never <= 3 then return 'A' end
    if r.never <= 6 then return 'B' end
    return 'C'
end

-- ---------------------------------------------------------------------------
-- Emit markdown.
-- ---------------------------------------------------------------------------
local L = {}
local function add(s) L[#L + 1] = s end

local apl_pass_count = 0
for k, v in pairs(APL_STATUS) do if v == 'pass' then apl_pass_count = apl_pass_count + 1 end end
local apl_total = 0
for _ in pairs(APL_STATUS) do apl_total = apl_total + 1 end

add('# Spec Scorecard — live battery metrics (Phase 0)')
add('')
add('_Generated by `tools/spec_scorecard.lua` from the live behavioral battery '
    .. '(behavioral_audit.run_all) + the rotation-runner registry. Supersedes the '
    .. 'triage-doc "Category counts" paragraphs._')
add('')
add('## Totals (TBC/Sylvanas era, ' .. tostring(agg.total) .. ' specs)')
add('')
add('| Metric | Value |')
add('|---|---|')
add('| strategies | ' .. totals.strategies .. ' |')
add('| never-firing | ' .. totals.never .. ' |')
add('| (a) opt-in | ' .. totals.a .. ' |')
add('| (b) correctly-silent | ' .. totals.b .. ' |')
add('| (c) mock-limitation | ' .. totals.c .. ' |')
add('| (d) dead | ' .. totals.d .. ' |')
add('| APL conformant (WotLK, Phase 2) | ' .. apl_pass_count .. '/' .. apl_total .. ' |')
add('| rotation suites (registry) | ' .. #all_test_names .. ' |')
add('')
add('Rating rubric: **S+** never=0 ∧ (c)=0 ∧ APL pass · **S** never=0 · **A** never≤3 · '
    .. '**B** never≤6 · **C** never≥7 · **F** (d)>0. Suite columns: class = tests whose '
    .. 'name contains the class keyword; spec = word-matched spec keyword (informational).')
add('')
add('## Per-spec scorecard')
add('')
add('| Spec | Strat | Never | (a) | (b) | (c) | (d) | Suites(cl/spec) | APL | Rating |')
add('|---|---|---|---|---|---|---|---|---|---|')
for _, r in ipairs(rows) do
    add(string.format('| %s/%s | %d | %d | %d | %d | %d | %d | %d/%d | %s | %s |',
        r.class, r.spec, r.strategies, r.never, r.a, r.b, r.c, r.d,
        r.class_suites, r.spec_suites, r.apl, rating(r)))
end
add('')
add('## APL conformance (Phase 2 — WotLK pilots)')
add('')
add('Strategy order verified against the pinned wowsims APL fixtures '
    .. '(see tools/evidence/apl/SOURCES.md, wowsims/wotlk @ 563e4a08). TBC-era '
    .. 'rows above remain `pending` — the harness has not yet been extended to them.')
add('')
add('| Spec | Fixture | Status |')
add('|---|---|---|')
local apl_keys = {}
for k in pairs(APL_STATUS) do apl_keys[#apl_keys + 1] = k end
table.sort(apl_keys)
for _, k in ipairs(apl_keys) do
    local fixture = (k == 'wotlk/fire' and 'fire_wotlk.apl.json')
        or (k == 'wotlk/affliction' and 'affliction_wotlk.apl.json')
        or (k == 'wotlk/cat' and 'feralcat_wotlk.apl.json') or '-'
    add('| ' .. k .. ' | ' .. fixture .. ' | ' .. APL_STATUS[k] .. ' |')
end
add('')
add('## Never-firing lanes by bucket')
add('')
for _, bucket in ipairs({ 'c', 'b', 'a', 'd' }) do
    local entries = lanes_by_bucket[bucket] or {}
    table.sort(entries)
    add('### ' .. BUCKET_LABEL[bucket] .. ' (' .. #entries .. ')')
    add('')
    if #entries == 0 then
        add('_none_')
    else
        add('```')
        for _, e in ipairs(entries) do add(e) end
        add('```')
    end
    add('')
end
add('## Notes')
add('')
add('- `(c)` lanes are the actionable Phase-3 inventory (ranked fixtures exist in the '
    .. 'non-DPS triage report items 1–20) **minus the documented correct-suppressions** '
    .. 'listed below.')
add('- `(b)` lanes are correctly silent vs the PvE-shaped scenario set; Phase 4 adds a '
    .. 'PvP scenario family to model them.')
add('- `(a)` lanes are opt-in settings (disabled by default); Phase 3 settings-fixture '
    .. 'scenarios make them observable.')
add('- APL status: WotLK pilots fire/affliction/cat are `pass` (Phase 2 harness, '
    .. 'test_apl_conformance.lua); TBC-era rows are `pending` until the harness is '
    .. 'extended to the sylvanas spec files.')
add('- Phase 2 note: `shared/apl_parser.lua` (resurrected) parses the pinned wowsims '
    .. 'TypeAPL JSON; test_apl_conformance.lua asserts strategy order for the 3 pilots '
    .. 'and fails CI on drift.')
add('- Suite-count note: `registry` = every quoted `*.lua` in run_rotation_tests.lua '
    .. '(includes check_* audits + duplicate entries, so it can exceed the 466 real '
    .. 'rotation suites verify_all reports). The spec column is word-matched and '
    .. 'collides across classes (e.g. `holy` matches both paladin and priest suites) — '
    .. 'informational only; the class column is the reliable number.')
local lane_notes_list = {}
for key, note in pairs(LANE_NOTES) do lane_notes_list[#lane_notes_list + 1] = '`' .. key .. '`: ' .. note end
table.sort(lane_notes_list)
if #lane_notes_list > 0 then
    add('')
    add('### Documented non-actionable lanes (do not re-triage)')
    add('')
    for _, n in ipairs(lane_notes_list) do add('- ' .. n) end
end

local markdown = table.concat(L, '\n') .. '\n'

-- ---------------------------------------------------------------------------
-- Drift gate.
-- ---------------------------------------------------------------------------
local scorecard_path = ROOT .. '/EaxRotations/docs/scorecard.md'
local old = read_file(scorecard_path)
local doc_drift = (old ~= markdown)
local hard_fail = false

for _, p in ipairs(problems) do
    if p.kind == 'unclassified' or p.kind == 'badpin' or p.kind == 'badapl' then hard_fail = true end
end
if totals.d > 0 then
    hard_fail = true
    problems[#problems + 1] = { kind = 'dead', msg = 'dead lanes must stay 0 (got ' .. totals.d .. ')' }
end

if hard_fail then
    io.stderr:write('spec_scorecard: HARD FAIL - classification pins are out of date:\n')
    for _, p in ipairs(problems) do io.stderr:write('  - ' .. p.kind .. ': ' .. p.msg .. '\n') end
    io.stderr:write('  Fix the LANE_CLASS table in tools/spec_scorecard.lua.\n')
    os.exit(3)
end

if CHECK_ONLY then
    local stale = false
    for _, p in ipairs(problems) do
        if p.kind == 'stale' then
            io.stderr:write('  stale pin: ' .. p.msg .. '\n')
            stale = true
        end
    end
    if doc_drift or stale then
        io.stderr:write('\nERROR: spec-scorecard drift detected.\n')
        if doc_drift then
            io.stderr:write('  docs/scorecard.md is stale (recompute differs from disk).\n')
        end
        if stale then io.stderr:write('  stale lane pins above (lanes now fire; remove them).\n') end
        io.stderr:write('  Fix: lua tools/spec_scorecard.lua && commit the diff.\n')
        os.exit(2)
    end
    print(string.format(
        'spec_scorecard: in sync (never=%d a=%d b=%d c=%d d=%d, ratings S/S+=%d/%d)',
        totals.never, totals.a, totals.b, totals.c, totals.d,
        (function()
            local s, sp = 0, 0
            for _, r in ipairs(rows) do
                if rating(r) == 'S' then s = s + 1 end
                if rating(r) == 'S+' then sp = sp + 1 end
            end
            return s, sp
        end)()))
    os.exit(0)
end

-- Write mode: report problems as warnings, but still write a correct doc.
local stale_count = 0
for _, p in ipairs(problems) do
    if p.kind == 'stale' then
        stale_count = stale_count + 1
        print('  warning (stale pin): ' .. p.msg)
    end
end
if write_file(scorecard_path, markdown) then
    print('  wrote ' .. scorecard_path)
    print(string.format('  totals: never=%d (a=%d b=%d c=%d d=%d) | %d specs',
        totals.never, totals.a, totals.b, totals.c, totals.d, #rows))
    if stale_count > 0 then
        print('  NOTE: ' .. stale_count .. ' stale pin(s) reported above - run --check after fixing LANE_CLASS')
    end
else
    io.stderr:write('spec_scorecard: cannot write ' .. scorecard_path .. '\n')
    os.exit(3)
end
