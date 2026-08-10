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
            -- (c) close-out (2026-08-09, batch 2): HurricaneAoE + RebirthBattleRez
            -- cleared by the hurricane_aoe / rebirth_dead_ally scenarios (battery
            -- now stubs DruidSpells.Hurricane + find_dead_party_ally) — pins removed.
            -- (a) opt-in close-out (2026-08-10): MoonkinForm cleared by the
            -- moonkin_form_optin scenario (balance_moonkin_auto + OOC) — pin removed.
            -- (b) close-out (2026-08-10): PvP_Cyclone / PvP_EntanglingRoots /
            -- PvP_NaturesGrasp cleared by the pvp_melee scenario.
        },
        bear = {
            -- (c) close-out (2026-08-09, batch 2): Swipe + EnrageCombat cleared
            -- by the bear_swipe_aoe / bear_enrage scenarios (form=1 + rage) — pins
            -- removed.
            -- (a) opt-in close-out (2026-08-10): Barkskin cleared by the
            -- bear_barkskin scenario (bear_use_barkskin + caster form + hp 40) —
            -- pin removed.
            -- (b) close-out (2026-08-10): ChallengingRoar cleared via its
            -- dedicated toggle (bear_use_challenging_roar) + enemy count — the
            -- category-(a) shape, re-bucketed and closed here. Threat-family
            -- close-out (2026-08-10): Growl cleared by the bear_growl scenario
            -- (healer target-of-target + now past the taunt throttle).
            FaerieFirePull = 'b', FeralChargePull = 'b',
            PrePullEnrage = 'b',
        },
        cat = {
            -- (c) close-out (2026-08-09, batch 2): ClawFallback + MangleFiller
            -- cleared by the cat_* scenarios — pins removed. RakeSnapshot +
            -- RipSnapshot remain (c): both read the module-local snapshot_state
            -- (cat:247-254) populated only by record_bleed_snapshot on a real
            -- cast — the battery never casts, so state.rake_ap/rip_ap stay 0 and
            -- the matchers' `<= 0` gate is genuinely unpinnable via fixtures.
            -- (a) opt-in close-out (2026-08-10): RipTrick + ShredTrick cleared
            -- by the cat_rip_trick / cat_shred_trick scenarios (settings + energy
            -- windows + energy_time_to_x stub for ShredTrick's next_tick gate) —
            -- pins removed.
            RakeSnapshot = 'c', RipSnapshot = 'c',
            TrackHumanoids = 'b', TravelForm = 'b',
        },
        resto = {
            -- Healer (c) close-out (2026-08-09): LifebloomLetBloom +
            -- TravelFormReposition cleared by the resto_* scenarios — pins
            -- removed.
            -- (b) close-out (2026-08-10): the four resto PvP-pressure lanes
            -- cleared by pvp_pressure_resto (enemies_in_range → GetEnemiesInRange).
        },
    },
    hunter = {
        -- Phase 3 (2026-08-09): Readiness x3 + SerpentStingRefresh x2 cleared
        -- by the readiness_window / serpent_refresh scenarios — pins removed.
        beast_mastery = {
            -- (c) close-out (2026-08-09, batch 2): Trinket cleared — battery now
            -- stubs TrinketManager.get_equipped_trinkets (has_trinket scenario)
            -- AND the spec's is_item_ready forward-declaration bug was fixed
            -- (beast_mastery:78 vs :458 shadowing — safe_any got nil, so
            -- trinket_1_ready was always false in LIVE game too).
            -- (b) close-out (2026-08-10): Misdirection cleared by the
            -- bm_misdirection scenario (combat_time window + setting);
            -- threat-family close-out (2026-08-10): FeignDeath cleared by the
            -- bm_feign_death scenario (threat_level 2 + high_threat mode).
        },
        marksmanship = {},
        survival = {},
    },
    mage = {
        -- (b) close-out (2026-08-10): arcane Blink + Polymorph, fire Polymorph,
        -- frost Blink cleared (snare_self / pvp_melee scenarios). ManaGemConjure
        -- stays pinned (OOC conjure, correctly silent).
        arcane = { },
        fire = { ManaGemConjure = 'b' },
        frost = {
            -- (a) opt-in close-out (2026-08-10): ArcaneMissiles + FireBlast +
            -- Scorch cleared by the frost_*_optin scenarios (pure setting
            -- toggles, no state shape) — pins removed.
            ManaGemConjure = 'b',
        },
    },
    paladin = {
        holy = {
            -- Healer (c) close-out (2026-08-09): ConsecrationSoloAoE,
            -- HammerOfWrathSolo, JudgementOfLightBoss, JudgementOfWisdomBoss,
            -- JudgementSoloRighteousness, LayOnHandsLastResort cleared by the
            -- holy_* scenarios — pins removed.
            -- (b) close-out (2026-08-10): BlessingOfFreedomSnare cleared by the
            -- snare_self scenario (snared_friend entry flag); threat-family
            -- close-out (2026-08-10): BlessingOfProtectionFocusedAlly cleared
            -- by the holy_bop_focused scenario (low-HP threatened entry).
        },
        protection = {
            -- (c) close-out (2026-08-09, batch 2): AvengingWrath + LayOnHands
            -- cleared by the prot_cd_window / prot_low_self scenarios — pins removed.
            -- (a) opt-in close-out (2026-08-10): AvengerShield + HammerOfWrath +
            -- Judgement + SealOfCommandAoE cleared by the prot_* scenarios
            -- (settings + seal buff map) — pins removed.
            -- Threat-family close-out (2026-08-10): RighteousDefense +
            -- BlessingOfProtectionAlly cleared by the prot_party_peel scenario
            -- (one low-HP threatened party ally + elite classification).
        },
        retribution = {
            -- (c) close-out (2026-08-09, batch 2): the 3 cleanse/purify lanes
            -- cleared by the ret_cleanse_self scenario — battery's
            -- has_player_debuff / has_target_debuff are now map-aware
            -- (player_debuff_remains_map) instead of the catch-all always-true.
            -- (a) opt-in close-out (2026-08-10): Consecration +
            -- Ret_Consecration_ManaDump cleared by the ret_consecration /
            -- ret_consec_dump scenarios (settings + mana) — pins removed.
            -- (b) close-out (2026-08-10): Ret_BlessingFreedom_Ally / _Self +
            -- Ret_HammerWrath_FleeingPvP cleared (snare_self / pvp_melee).
        },
    },
    priest = {
        holy = {
            -- Phase 3 (2026-08-09): ClearcastingGreaterHeal + SurgeOfLightSmite
            -- cleared by the clearcast_surge scenario (per-buff map) — pins
            -- removed.
            EncounterReactions = 'b', MountedProtection = 'b',
        },
        -- (b) close-out (2026-08-10): SWDCCBreak cleared by the
        -- shadow_cc_break scenario (breakable-CC player debuff). DispelMagic
        -- stays pinned (intentionally disabled; middleware handles dispels).
        shadow = { DispelMagic = 'b' },
        smite = {
            -- Healer (c) close-out (2026-08-09): InnerFocus + SoloRenew cleared
            -- by the smite_* scenarios — pins removed.
            -- (b) close-out (2026-08-10): Starshards cleared via RACE_OVERRIDES
            -- (smite loads as night elf). Threat-family close-out (2026-08-10):
            -- DevouringPlague cleared via RACE_VARIANTS — smite loads a second
            -- time as undead (race 5) and the battery merges the never lists,
            -- so both racial lanes are observable.
        },
    },
    shaman = {
        elemental = {
            -- Phase 3 (2026-08-09): EarthShockMoving + FrostShockMoving cleared
            -- by the elem_shock_moving / elem_shock_pvp scenarios — pins removed.
            -- (c) close-out (2026-08-09, batch 2): ChainHeal + ElementalMastery +
            -- TotemicCall cleared by the elem_* scenarios — pins removed.
            -- (b) close-out (2026-08-10): TremorTotem cleared by the fear_nearby
            -- scenario.
        },
        enhancement = {
            -- (c) close-out (2026-08-09, batch 2): EarthShock + ShamanisticRage
            -- cleared by the enh_interrupt / enh_low_mana scenarios (target
            -- get_cast_pct stub + per-CD setting override) — pins removed.
            -- FireNovaReplacement remains (c): the gate reads the module-local
            -- totem_state.fire_nova_active (enhancement:135), populated only by
            -- the spec's own totem-drop lifecycle during a real rotation update
            -- — the battery never drops totems, so it is genuinely unpinnable.
            -- (a) opt-in close-out (2026-08-10): GraceOfAirTotemTwist cleared by
            -- the enh_goa_twist scenario (WF-buff map + GoA-expiry map) — pin
            -- removed. NOTE: this required the battery's buff_remains/buff_up/
            -- debuff_* stubs to normalize spell_action objects (ACTION.* has an
            -- .ids list, not top-level numeric keys), mirroring cooldown_remains.
            -- (b) close-out (2026-08-10): AutoAttack cleared via the
            -- is_auto_attacking stub (battery artifact — live client unaffected);
            -- TremorTotem cleared by fear_nearby.
            FireNovaReplacement = 'c',
        },
        restoration = {
            -- Healer (c) close-out (2026-08-09): ChainLightning + LightningShield
            -- cleared by the resto_* scenarios — pins removed.
            -- (b) close-out (2026-08-10): TremorTotem cleared by the fear_nearby
            -- scenario.
        },
    },
    warlock = {
        affliction = {
            -- (b) close-out (2026-08-10): CC_HowlOfTerror + PvP_CurseExhaustion
            -- + PvP_CurseTongues cleared by the pvp_melee scenario.

        },
        -- (b) close-out (2026-08-10): Seduction cleared by the pvp_succubus
        -- scenario (succubus pet + Lash of Pain).
        demonology = { },
    },
}

-- ---------------------------------------------------------------------------
-- WotLK lane pins. The Phase-1 triage (2026-08-09) is COMPLETE: the 149-lane
-- inventory was cleared to 0 never-firing (battery fixture upgrades — resource/
-- cooldown accessors, scenario banks, DK stub rewiring — not spec edits), so
-- WOTLK_LANE_CLASS is empty because there are NO never-lanes to classify, and
-- the era is STRICT like TBC: any future never-lane without a pin here is a
-- hard-fail. Stale/bad pins and (d) lanes hard-fail in both eras.
-- ---------------------------------------------------------------------------
local WOTLK_LANE_CLASS = {}

-- ---------------------------------------------------------------------------
-- APL conformance status — COMPUTED, not hardcoded. tools/apl_status.lua is the
-- single source of truth: for each manifest entry (fixture -> spec file -> spell-id
-- resolver) it loads the spec under the mock-NS harness, parses the pinned
-- wowsims fixture, and returns a live pass/fail verdict + evidence string.
-- The per-spec WotLK rows below and the APL-conformance section render this
-- output, so "pass" is a computed, evidence-backed fact that can never drift
-- from tests/test_apl_conformance.lua (which iterates the same manifest).
-- Keys are era-qualified ("wotlk/<spec>"). Absent key = "pending" (no pinned
-- fixture/resolver yet — adding a spec = one manifest entry + a fixture).
-- ---------------------------------------------------------------------------
local apl_status_chunk, apl_status_err = loadfile(ROOT .. '/tools/apl_status.lua')
if not apl_status_chunk then
    io.stderr:write('spec_scorecard: cannot load tools/apl_status.lua: ' .. tostring(apl_status_err) .. '\n')
    os.exit(3)
end
local apl_ok, apl_mod = pcall(apl_status_chunk)
if not apl_ok or type(apl_mod) ~= 'table' or type(apl_mod.compute) ~= 'function' then
    io.stderr:write('spec_scorecard: tools/apl_status.lua did not expose compute()\n')
    os.exit(3)
end
-- NOTE: compute() MUST run AFTER the battery, not before. compute() dofiles
-- each manifest spec file with ITS OWN mock NS (tools/apl_status.lua base_ns),
-- and shared modules (hunter pet scan, warrior stance manager, ...) cache
-- `NS = _G.EaxRotations` at their FIRST require(). If compute() ran first,
-- those shared modules would stay bound to the apl mock, so the battery's
-- subsequent run would evaluate pet/stance/engineering lanes against the
-- wrong mock and they would never fire (spurious never-lanes, e.g. BM
-- BestialWrath/KillCommand/MendPet, arms/fury BattleStance, cat EngineeringBomb).
-- compute() only reads strategy NAMES for order conformance, so running it
-- after the battery is safe; the battery must always see virgin shared modules.
local apl_result
local APL_STATUS = {}
local APL_EVIDENCE = {}

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
    p = '(p) pending (untriaged)',
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
-- Same counting discipline as update_badges.lua: only the runner's tests-table
-- entries are suites it actually executes (#tests); a whole-file scan would
-- also catch package.path patterns, the runner's file_exists path and the
-- manifest_only_test variable (473 vs the real 470). The 3 check_*.lua
-- static-analysis audits ARE list entries, so they are part of the 470.
local all_test_names = {}
if runner_content then
    local inside = false
    -- NOTE: this inside-table scan is duplicated in tools/update_badges.lua
    -- (count_tests_in_runner). If you change the toggle here, mirror it there so
    -- the badge and scorecard registry counts cannot silently diverge.
    for line in runner_content:gmatch('([^\r\n]*)\r?\n?') do
        local trimmed = line:gsub('^%s+', '')
        if not inside and trimmed:match('^local tests = {') then inside = true end
        if inside and trimmed == '}' then inside = false end
        if inside and not trimmed:match('^%-%-') then
            for entry in trimmed:gmatch('"([^"]+%.lua)"') do
                local name = entry:gsub('%.lua$', ''):gsub('^test_', '')
                all_test_names[#all_test_names + 1] = name
            end
        end
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

-- Aggregate one era's battery reports into rows/totals/lane-buckets.
--   era "sylvanas": STRICT - every never-lane needs a LANE_CLASS pin; an
--                   unclassified lane is a hard-fail (pre-Phase-1 gate).
--   era "sylvanas": STRICT - every never-lane needs a LANE_CLASS pin; an
--                   unclassified lane is a hard-fail (pre-Phase-1 gate).
--   era "wotlk"   : STRICT as of the Phase-1 triage (2026-08-09) — the 149-lane
--                   inventory was cleared to 0 never-firing, so there is no
--                   untriaged backlog left to stay lenient about; a future
--                   never-lane without a WOTLK_LANE_CLASS pin hard-fails.
local function classify_reports(agg, era)
    local pin_table = (era == 'sylvanas') and LANE_CLASS or WOTLK_LANE_CLASS
    local strict = true
    local rows = {}       -- per-spec rows, sorted
    local totals = { strategies = 0, never = 0, a = 0, b = 0, c = 0, d = 0, p = 0 }
    local lanes_by_bucket = {} -- [bucket] = { "class/spec: lane", ... }
    for _, r in ipairs(agg.reports) do
        local class_key, spec_key = r.class, r.spec
        local pins = (pin_table[class_key] or {})[spec_key] or {}
        local a, b, c, d, p = 0, 0, 0, 0, 0
        for _, lane in ipairs(r.never or {}) do
            local bucket = pins[lane]
            if not bucket then
                if strict then
                    problems[#problems + 1] = {
                        kind = 'unclassified',
                        msg = class_key .. '/' .. spec_key .. ': never-lane "' .. lane .. '" has no pin',
                    }
                    bucket = '?'
                else
                    bucket = 'p' -- untriaged WotLK inventory: pending, no hard-fail
                end
            elseif not BUCKET_LABEL[bucket] then
                problems[#problems + 1] = {
                    kind = 'badpin',
                    msg = class_key .. '/' .. spec_key .. ': lane "' .. lane .. '" has invalid pin "' .. tostring(bucket) .. '"',
                }
                bucket = '?'
            end
            if bucket == 'a' then a = a + 1
            elseif bucket == 'b' then b = b + 1
            elseif bucket == 'c' then c = c + 1
            elseif bucket == 'd' then d = d + 1
            elseif bucket == 'p' then p = p + 1 end
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
                    msg = era .. '/' .. class_key .. '/' .. spec_key .. ': pin "' .. lane .. '"=' .. bucket ..
                        ' but the lane now FIRES (remove the pin)',
                }
            end
        end
        local class_suites, spec_suites = count_suites(class_key, spec_key)
        local apl
        if era == 'wotlk' then
            apl = APL_STATUS['wotlk/' .. spec_key] or 'pending'
        else
            -- Class-qualified keys disambiguate shared spec names ("protection"
            -- exists for both paladin and warrior): try tbc/<class>/<spec> first.
            apl = APL_STATUS['tbc/' .. class_key .. '/' .. spec_key]
                or APL_STATUS['tbc/' .. spec_key]
                or APL_STATUS[spec_key]
                or APL_STATUS[class_key .. '/' .. spec_key]
                or 'pending'
        end
    if apl ~= 'pending' and apl ~= 'pass' and apl ~= 'fail' then
        problems[#problems + 1] = {
            kind = 'badapl',
            msg = class_key .. '/' .. spec_key .. ': invalid APL status "' .. tostring(apl) .. '"',
        }
        apl = 'pending'
    end
    if apl == 'fail' then
        problems[#problems + 1] = {
            kind = 'aplfail',
            msg = era .. '/' .. class_key .. '/' .. spec_key .. ': APL conformance FAIL ('
                .. tostring(APL_EVIDENCE['tbc/' .. class_key .. '/' .. spec_key]
                    or APL_EVIDENCE[era .. '/' .. spec_key]
                    or APL_EVIDENCE['tbc/' .. spec_key]) .. ')',
        }
    end
        rows[#rows + 1] = {
            class = class_key, spec = spec_key,
            strategies = r.strategy_count or 0,
            never = #(r.never or {}),
            a = a, b = b, c = c, d = d, p = p,
            class_suites = class_suites, spec_suites = spec_suites,
            apl = apl,
        }
        totals.strategies = totals.strategies + (r.strategy_count or 0)
        totals.never = totals.never + #(r.never or {})
        totals.a = totals.a + a; totals.b = totals.b + b; totals.c = totals.c + c
        totals.d = totals.d + d; totals.p = totals.p + p
    end
    table.sort(rows, function(x, y)
        if x.class == y.class then return x.spec < y.spec end
        return x.class < y.class
    end)
    return rows, totals, lanes_by_bucket
end

-- Phase 1: run the WotLK-era battery (41 files incl. DK) alongside TBC.
local wotlk_agg = battery.run_all('wotlk')
if wotlk_agg == nil or type(wotlk_agg) ~= 'table' or wotlk_agg.reports == nil then
    io.stderr:write('spec_scorecard: battery run_all("wotlk") returned no reports\n')
    os.exit(3)
end

-- Ordering self-guard: compute() rebinds shared modules to its own mock NS, so
-- if the battery run ever happens AFTER compute() (a future refactor), the
-- pet/stance/engineering lanes below appear as spurious never-lanes. Assert
-- they are ABSENT from the TBC aggregate so that regression fails loudly.
-- (These lanes must come from LANE_CLASS pins when truly never, not from
-- module pollution; the pollution signature is exactly this lane set.)
local POLLUTION_SIGNATURE = {
    ['hunter/beast_mastery'] = { 'BestialWrath', 'Intimidation', 'KillCommand', 'MendPet', 'RevivePet', 'PetAggressive', 'PetDefensive', 'PetPassive' },
    ['warrior/arms'] = { 'BattleStance', 'BerserkerStance', 'DefensiveStance', 'EngineeringBomb' },
    ['warrior/fury'] = { 'BattleStance', 'BerserkerStance', 'EngineeringBomb' },
    ['druid/cat'] = { 'EngineeringBomb' },
}
for _, r in ipairs(agg.reports) do
    local key = r.class .. '/' .. r.spec
    local sig = POLLUTION_SIGNATURE[key]
    if sig then
        local live = {}
        for _, n in ipairs(r.never or {}) do live[n] = true end
        for _, lane in ipairs(sig) do
            if live[lane] then
                problems[#problems + 1] = {
                    kind = 'unclassified',
                    msg = key .. ': never-lane "' .. lane .. '" is the module-pollution signature ' ..
                        '(compute() ran before the battery? battery must run before apl compute())',
                }
            end
        end
    end
end

-- Battery runs are done; now compute the APL manifest (see NOTE above: this
-- must come AFTER the battery so shared modules are not rebound to its mock).
apl_result = apl_mod.compute()
APL_STATUS = apl_result.status or {}
APL_EVIDENCE = apl_result.evidence or {}

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

local rows, totals, lanes_by_bucket = classify_reports(agg, 'sylvanas')
local wotlk_rows, wotlk_totals, wotlk_lanes_by_bucket = classify_reports(wotlk_agg, 'wotlk')

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

local function emit_totals(label, spec_count, t, extra)
    add('## Totals (' .. label .. ', ' .. tostring(spec_count) .. ' specs)')
    add('')
    add('| Metric | Value |')
    add('|---|---|')
    add('| strategies | ' .. t.strategies .. ' |')
    add('| never-firing | ' .. t.never .. ' |')
    add('| (a) opt-in | ' .. t.a .. ' |')
    add('| (b) correctly-silent | ' .. t.b .. ' |')
    add('| (c) mock-limitation | ' .. t.c .. ' |')
    add('| (d) dead | ' .. t.d .. ' |')
    add('| (p) pending (untriaged) | ' .. t.p .. ' |')
    if extra then
        for _, e in ipairs(extra) do add('| ' .. e[1] .. ' | ' .. e[2] .. ' |') end
    end
    add('')
end

local function emit_rows_table(label, rows_, show_pending)
    add('## Per-spec scorecard (' .. label .. ')')
    add('')
    if show_pending then
        add('| Spec | Strat | Never | (a) | (b) | (c) | (d) | (p) | Suites(cl/spec) | APL | Rating |')
        add('|---|---|---|---|---|---|---|---|---|---|---|')
        for _, r in ipairs(rows_) do
            add(string.format('| %s/%s | %d | %d | %d | %d | %d | %d | %d | %d/%d | %s | %s |',
                r.class, r.spec, r.strategies, r.never, r.a, r.b, r.c, r.d, r.p,
                r.class_suites, r.spec_suites, r.apl, rating(r)))
        end
    else
        add('| Spec | Strat | Never | (a) | (b) | (c) | (d) | Suites(cl/spec) | APL | Rating |')
        add('|---|---|---|---|---|---|---|---|---|---|')
        for _, r in ipairs(rows_) do
            add(string.format('| %s/%s | %d | %d | %d | %d | %d | %d | %d/%d | %s | %s |',
                r.class, r.spec, r.strategies, r.never, r.a, r.b, r.c, r.d,
                r.class_suites, r.spec_suites, r.apl, rating(r)))
        end
    end
    add('')
end

local function emit_buckets(label, lb, buckets)
    add('## Never-firing lanes by bucket (' .. label .. ')')
    add('')
    for _, bucket in ipairs(buckets) do
        local entries = lb[bucket] or {}
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
end

add('# Spec Scorecard — live battery metrics (Phases 0–1, cross-era)')
add('')
add('_Generated by `tools/spec_scorecard.lua` from the live behavioral battery '
    .. '(behavioral_audit.run_all, both eras) + the rotation-runner registry. Supersedes the '
    .. 'triage-doc "Category counts" paragraphs._')
add('')
emit_totals('TBC/Sylvanas era', agg.total, totals, {
    { 'APL conformant (all eras)', apl_pass_count .. '/' .. apl_total },
    { 'rotation suites (registry)', #all_test_names },
})
emit_totals('WotLK era', wotlk_agg.total, wotlk_totals)
add('')
add('Rating rubric: **S+** never=0 ∧ (c)=0 ∧ APL pass · **S** never=0 · **A** never≤3 · '
    .. '**B** never≤6 · **C** never≥7 · **F** (d)>0. Suite columns: class = tests whose '
    .. 'name contains the class keyword; spec = word-matched spec keyword (informational). '
    .. 'WotLK-era rows were triaged in Phase-1 (2026-08-09): the 149-lane inventory was '
    .. 'cleared to **0 never-firing** via battery fixture upgrades (resource/cooldown '
    .. 'accessors, scenario banks, DK stub rewiring), so the era is STRICT like TBC — a '
    .. 'future never-lane is a hard-fail until pinned.')
add('')
add('**Why healer rows show APL = `pending`:** wowsims (tbc, tbc-new, wotlk, '
    .. 'classic/SoD) is explicitly a DPS-only simulator — its checked-out rotation '
    .. 'trees contain zero healer files (druid = balance/feral/tank, paladin = '
    .. 'protection/retribution, priest = shadow/smite) — and no healer rotation '
    .. 'simulator exists for any classic era (GitHub repo search returns 0). Healer '
    .. 'validation is therefore battery-verified internal correctness (never=0, S '
    .. 'ratings, the ~60 healer regression suites), with priority logic based on '
    .. 'community guides (Icy Veins / Wowhead; see the provenance note at '
    .. 'holy_sylvanas.lua:4) rather than sim-authored APLs.')
add('')
emit_rows_table('TBC/Sylvanas era', rows, false)
emit_rows_table('WotLK era', wotlk_rows, true)

add('## APL conformance (computed from pinned fixtures)')
add('')
add('Status is computed live by `tools/apl_status.lua` from the pinned wowsims APL '
    .. 'fixtures (see tools/evidence/apl/SOURCES.md, wowsims/wotlk @ 563e4a08) — '
    .. 'the same manifest `tests/test_apl_conformance.lua` iterates, so this table '
    .. 'and the CI gate can never drift. TBC-era rows are pinned from wowsims/tbc '
    .. 'Go dispatch order (`reference_names` — the TBC repo predates TypeAPL JSON; '
    .. 'see SOURCES.md). Healers (holy/disc/resto/healing) have no wowsims rotation '
    .. 'and remain `pending`.')
add('')
add('| Spec | Fixture | Verdict | Evidence |')
add('|---|---|---|---|')
local apl_keys = {}
for k in pairs(APL_STATUS) do apl_keys[#apl_keys + 1] = k end
table.sort(apl_keys)
for _, k in ipairs(apl_keys) do
    local fixture = (k == 'wotlk/fire' and 'fire_wotlk.apl.json')
        or (k == 'wotlk/affliction' and 'affliction_wotlk.apl.json')
        or (k == 'wotlk/cat' and 'feralcat_wotlk.apl.json')
        or (k == 'wotlk/arcane' and 'arcane_wotlk.apl.json')
        or (k == 'wotlk/frost' and 'frost_wotlk.apl.json')
        or (k == 'wotlk/combat' and 'combat_wotlk.apl.json')
        or (k == 'wotlk/assassination' and 'mutilate_wotlk.apl.json')
        or (k == 'wotlk/elemental' and 'elemental_wotlk.apl.json')
        or (k == 'wotlk/shadow' and 'shadow_wotlk.apl.json')
        or (k == 'tbc/shadow' and 'Go: sim/priest/shadow_rotation.go')
        or (k == 'tbc/affliction' and 'Go: sim/warlock_rotations.go')
        or (k == 'tbc/combat' and 'Go: sim/rogue_rotation.go')
        or (k == 'tbc/elemental' and 'Go: sim/shaman_elemental_rotation.go')
        or (k == 'tbc/fire' and 'Go: sim/mage_rotations.go')
        or (k == 'tbc/frost' and 'Go: sim/mage_rotations.go')
        or (k == 'tbc/balance' and 'Go: sim/druid_balance_rotation.go')
        or (k == 'tbc/cat' and 'Go: sim/druid_feral_rotation.go')
        or (k == 'tbc/beast_mastery' and 'Go: sim/hunter_rotation.go')
        or (k == 'tbc/marksmanship' and 'Go: sim/hunter_rotation.go')
        or (k == 'tbc/survival' and 'Go: sim/hunter_rotation.go')
        or (k == 'tbc/arcane' and 'Go: sim/mage_rotations.go')
        or (k == 'tbc/retribution' and 'Go: sim/paladin_retribution_rotation.go')
        or (k == 'tbc/smite' and 'Go: sim/priest_smite_rotation.go')
        or (k == 'tbc/enhancement' and 'Go: sim/shaman_enhancement_rotation.go')
        or (k == 'tbc/demonology' and 'Go: sim/warlock_rotations.go')
        or (k == 'tbc/destruction' and 'Go: sim/warlock_rotations.go')
        or (k == 'tbc/arms' and 'Go: sim/warrior_dps_rotation.go')
        or (k == 'tbc/fury' and 'Go: sim/warrior_dps_rotation.go')
        or (k == 'tbc/bear' and 'Go: sim/druid_tank_rotation.go')
        or (k == 'tbc/paladin/protection' and 'Go: sim/paladin_protection_rotation.go')
        or (k == 'tbc/warrior/protection' and 'Go: sim/warrior/protection/rotation.go')
        or (k == 'tbc/caster' and 'Go: sim/druid/balance/rotation.go (damage-chain subset)') or '-'
    add('| ' .. k .. ' | ' .. fixture .. ' | ' .. APL_STATUS[k] .. ' | '
        .. tostring(APL_EVIDENCE[k] or '-') .. ' |')
end
add('')
emit_buckets('TBC/Sylvanas era', lanes_by_bucket, { 'c', 'b', 'a', 'd' })
emit_buckets('WotLK era', wotlk_lanes_by_bucket, { 'p', 'c', 'b', 'a', 'd' })

add('## Notes')
add('')
add('- `(p)` lanes are the pending bucket. The WotLK Phase-1 triage (2026-08-09) is '
    .. 'complete: the 149-lane inventory was cleared to 0 never-firing (battery fixtures '
    .. 'only — no spec edits), so no WotLK lane is pending today; the era is STRICT, so '
    .. 'a future never-lane hard-fails --check until pinned.')
add('- `(c)` lanes are the actionable Phase-3 inventory (ranked fixtures exist in the '
    .. 'non-DPS triage report items 1–20) **minus the documented correct-suppressions** '
    .. 'listed below.')
add('- `(b)` lanes are correctly silent vs the PvE-shaped scenario set; Phase 4 adds a '
    .. 'PvP scenario family to model them.')
add('- `(a)` lanes are opt-in settings (disabled by default); Phase 3 settings-fixture '
    .. 'scenarios make them observable.')
add('- APL status is COMPUTED, not hardcoded: `tools/apl_status.lua` loads each '
    .. 'manifest entry (pinned fixture -> spec file -> resolver, or reference_names '
    .. 'for Go-dispatch TBC pins) live and returns pass/fail + evidence; '
    .. '`tests/test_apl_conformance.lua` iterates the same manifest, so the APL '
    .. 'column and the CI gate can never drift. TBC-era rows are pinned from '
    .. 'wowsims/tbc Go dispatch order; healers stay `pending` (no wowsims rotation).')
add('- Phase 2 note: `shared/apl_parser.lua` (resurrected) parses the pinned wowsims '
    .. 'TypeAPL JSON; test_apl_conformance.lua asserts strategy order for the 3 pilots '
    .. 'and fails CI on drift.')
add('- Suite-count note: `registry` = the ' .. #all_test_names .. ' rotation suites the '
    .. 'runner actually executes (its `tests = { ... }` table — the same count '
    .. 'update_badges.lua reports; includes the 3 `check_*` static-analysis audits '
    .. 'the runner runs as suites). The spec column is word-matched and collides '
    .. 'across classes (e.g. `holy` matches both paladin and priest suites) — '
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

    local apl_fail = false
    for _, p in ipairs(problems) do
        if p.kind == 'unclassified' or p.kind == 'badpin' or p.kind == 'badapl' then hard_fail = true end
        if p.kind == 'aplfail' then hard_fail = true apl_fail = true end
    end
if totals.d > 0 then
    hard_fail = true
    problems[#problems + 1] = { kind = 'dead', msg = 'dead lanes must stay 0 (got ' .. totals.d .. ')' }
end
if wotlk_totals.d > 0 then
    hard_fail = true
    problems[#problems + 1] = { kind = 'dead', msg = 'WotLK dead lanes must stay 0 (got ' .. wotlk_totals.d .. ')' }
end

if hard_fail then
    io.stderr:write('spec_scorecard: HARD FAIL - classification pins are out of date:\n')
    for _, p in ipairs(problems) do io.stderr:write('  - ' .. p.kind .. ': ' .. p.msg .. '\n') end
    if apl_fail then
        io.stderr:write('  An APL conformance FAIL means a rotation drifted from its pinned wowsims APL:\n')
        io.stderr:write('  reorder the strategies in the spec file (or fix the resolver in tools/apl_status.lua).\n')
    else
        io.stderr:write('  Fix the LANE_CLASS table in tools/spec_scorecard.lua.\n')
    end
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
    local s_rating, sp_rating = 0, 0
    for _, r in ipairs(rows) do
        if rating(r) == 'S' then s_rating = s_rating + 1 end
        if rating(r) == 'S+' then sp_rating = sp_rating + 1 end
    end
    print(string.format(
        'spec_scorecard: in sync (tbc never=%d a=%d b=%d c=%d d=%d | wotlk never=%d p=%d, ratings S/S+=%d/%d, apl pass=%d/%d)',
        totals.never, totals.a, totals.b, totals.c, totals.d,
        wotlk_totals.never, wotlk_totals.p,
        s_rating, sp_rating, apl_pass_count, apl_total))
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
    print(string.format('  totals: tbc never=%d (a=%d b=%d c=%d d=%d) | wotlk never=%d (p=%d) | %d+%d specs',
        totals.never, totals.a, totals.b, totals.c, totals.d,
        wotlk_totals.never, wotlk_totals.p, #rows, #wotlk_rows))
    if stale_count > 0 then
        print('  NOTE: ' .. stale_count .. ' stale pin(s) reported above - run --check after fixing LANE_CLASS')
    end
else
    io.stderr:write('spec_scorecard: cannot write ' .. scorecard_path .. '\n')
    os.exit(3)
end
