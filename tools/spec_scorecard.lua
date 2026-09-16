-- spec_scorecard.lua -- per-spec S+ metrics for all rotations (Phase 0).
-- WHAT:  Runs the live behavioral battery (behavioral_audit.run_all), classifies
--        every never-firing lane into (a) opt-in / (b) correctly-silent /
--        (c) mock-limitation / (d) dead, computes per-spec test-suite counts from
--        the rotation runner registry, and emits docs/scorecard.md PLUS the
--        player-facing docs/ACCURACY.md (2026-09-06, #1-roadmap P1-1 — the same
--        live aggregates in plain language for non-engineers). APL status is
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
--   * Regenerated docs/scorecard.md / ACCURACY.md != on disk -> FAIL (stale doc)
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
            -- cleared by the cat_* scenarios — pins removed. (a) opt-in
            -- close-out (2026-08-10): RipTrick + ShredTrick cleared by the
            -- cat_rip_trick / cat_shred_trick scenarios — pins removed.
            -- (c) close-out (2026-09-06): RakeSnapshot + RipSnapshot cleared by
            -- the battery's execute-capture path — the two read module-local
            -- snapshot_state populated only by record_bleed_snapshot inside the
            -- Rip/Rake cast execute, so the capture scenarios
            -- (cat_rip_snapshot_capture / cat_rake_snapshot_capture) run the
            -- seed lane's REAL execute against the mock NS, then re-evaluate
            -- the reap lane on the post-cast frame (bleed applied + AP spiked);
            -- both now fire through the real file — pins removed.
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
            -- (c) pin (2026-08-12 campaign): Ret_SealMartyr_Primary gated on
            -- preferred_damage_seal == "martyr", which the 2026-08-12 seal
            -- rewrite derives from blood_available() → is_spell_learned(31892).
            -- The battery's lenient is_spell_learned mock reports 31892 learned
            -- (no not_learned bank entry for it), so the Alliance-only martyr
            -- branch is inexpressible — a mock limitation (fires live for
            -- Alliance rets with ret_use_martyr default true).
            Ret_SealMartyr_Primary = 'c',
        },
    },
    priest = {
        holy = {
            -- Phase 3 (2026-08-09): ClearcastingGreaterHeal + SurgeOfLightSmite
            -- cleared by the clearcast_surge scenario (per-buff map) — pins
            -- removed.
            -- (b) close-out (2026-09-06, P0-3): MountedProtection cleared by
            -- the ooc_mounted scenario (me:is_mounted now ctx-banked) — the
            -- safety-net lane provably fires on a mounted OOC state.
            EncounterReactions = 'b',
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
    rogue = {
        -- (a) pin (2026-08-12 campaign): assassination ExposeArmor gated on the
        -- new assassin_expose_assigned setting (default false — opt-in, mirrors
        -- combat/subtlety expose keys), so the battery never sees it.
        assassination = { ExposeArmor = 'a' },
        -- (c) close-out (2026-09-06, P0-3): subtlety Sap cleared by the
        -- sap_setup scenario (OOC + stealth_up + PvP target) — the missing
        -- in_combat=false split of pvp_stealth_opener. The lane provably
        -- fires on an OOC PvP sap setup.
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
            -- cleared by the enh_interrupt / enh_low_mana scenarios — pins
            -- removed. (a) opt-in close-out (2026-08-10): GraceOfAirTotemTwist
            -- cleared by the enh_goa_twist scenario — pin removed. (b) close-out
            -- (2026-08-10): AutoAttack cleared via the is_auto_attacking stub;
            -- TremorTotem cleared by fear_nearby.
            -- (c) close-out (2026-09-06): FireNovaReplacement cleared by the
            -- execute-capture scenario enh_fire_nova_replacement_capture_tbc —
            -- the gate reads module-local totem_state.fire_nova_active, so the
            -- capture runs the REAL FireTotem execute (drops Fire Nova against
            -- the mock, seeding the flag), then re-evaluates the replacement
            -- lane on the post-cast frame with flame shock up — pin removed.
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
-- Vanilla lane pins (Wave 1.4 triage 2026-08-13; MagmaTotem cleared 2026-08-14
-- in v2.24.2; MountedProtection cleared 2026-09-06 by the ooc_mounted scenario
-- (P0-3)). Live never = 11 lanes = (b) 8 + (c) 3, verified lane-for-lane
-- against the battery on 2026-09-06. STRICT like the other eras: an
-- unclassified or stale pin hard-fails.
--   (b) druid/bear FaerieFirePull / PrePullEnrage    — OOC pre-pull (TBC mirrors b)
--   (b) mage/fire,frost ManaGemConjure               — mock gem always available
--   (b) mage/leveling ConjureManaGem                 — same gem-availability suppression
--   (b) priest/holy EncounterReactions               — NS.is_tbc() gate (Karazhan is TBC-only)
--   (b) shaman/elemental WrathOfAirTotem             — TBC-only spell; inert marker
--   (b) warlock/affliction RacialArcaneTorrent       — Blood Elf racial; no BE in vanilla
--   (c) priest/leveling Fade                         — threat_pct >= 99; battery caps at 95
-- MagmaTotem was (b) pre-v2.24.2 and is now enabled (four Classic ranks).
-- MountedProtection was (b) pre-P0-3 and now fires (ooc_mounted).
-- FireNovaReplacement + GraceOfAirTotemTwist were (c) pre-2026-09-06 and are
-- now PROVEN by the execute-capture scenarios (enh_fire_nova_replacement_
-- capture_vanilla / enh_grace_air_twist_capture_vanilla — the real
-- FireTotem / WindfuryTotemTwist executes seed the module-local
-- fire_nova_active / next_air state).
-- ---------------------------------------------------------------------------
local VANILLA_LANE_CLASS = {
    druid = { bear = { FaerieFirePull = 'b', PrePullEnrage = 'b' } },
    mage = {
        fire = { ManaGemConjure = 'b' },
        frost = { ManaGemConjure = 'b' },
        leveling = { ConjureManaGem = 'b' },
    },
    priest = {
        -- (b) close-out (2026-09-06, P0-3): MountedProtection cleared by the
        -- ooc_mounted scenario (me:is_mounted now ctx-banked) — provably fires.
        holy = { EncounterReactions = 'b' },
        leveling = { Fade = 'c' },
    },
    shaman = {
        elemental = { WrathOfAirTotem = 'b' },
    },
    warlock = { affliction = { RacialArcaneTorrent = 'b' } },
}

-- ---------------------------------------------------------------------------
-- SoD lane pins (W4.3, 2026-08-14): the initial 37-lane never inventory was
-- cleared to 0 by the _meta fidelity fix + 14 scenario shapes, so SOD_LANE_CLASS
-- is empty because there are NO never-lanes to classify. STRICT like WotLK: a
-- future never-lane hard-fails until pinned.
-- ---------------------------------------------------------------------------
-- 2026-09-14 Skull Bash wiring (Wowhead-verified 410176) added interrupt
-- lanes to druid/feral_sod + druid/tank_sod. The battery harness does not
-- stub NS.try_interrupt / NS.gcd_remains, so the manager's gate (needs all
-- four interrupt APIs present) correctly holds every scenario — the
-- dedicated suite test_sod_druid_hunter pins both firing paths. Bucket (c):
-- works live, silent under the battery mock, mirroring priest/leveling Fade.
local SOD_LANE_CLASS = {
    druid = {
        feral = { Interrupt = 'c' },
        tank  = { Interrupt = 'c' },
    },
    mage = { ["dps_mage"] = { Interrupt = 'c' } },
    rogue = { combat = { Interrupt = 'c' }, tank = { Interrupt = 'c' } },
    warrior = { ["dps_warrior"] = { Interrupt = 'c' }, ["tank_warrior"] = { Interrupt = 'c' } },
    shaman = { elemental = { Interrupt = 'c' }, enhancement = { Interrupt = 'c' },
        restoration = { Interrupt = 'c' }, warden = { Interrupt = 'c' } },
    priest = { shadow = { Interrupt = 'c' } },
    paladin = { protection = { Interrupt = 'c' }, retribution = { Interrupt = 'c' } },
}

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
local ERA_CONFIG = {
    sylvanas = { pins = LANE_CLASS, apl_era = 'tbc' },
    wotlk = { pins = WOTLK_LANE_CLASS, apl_era = 'wotlk' },
    vanilla = { pins = VANILLA_LANE_CLASS, apl_era = nil },
    sod = { pins = SOD_LANE_CLASS, apl_era = nil },
    -- forever: vanilla-superset era — same files, same lane pins (stale-pin
    -- and unclassified checks apply identically until _forever deltas land).
    forever = { pins = VANILLA_LANE_CLASS, apl_era = nil },
}

local function classify_reports(agg, era)
    local cfg = ERA_CONFIG[era] or { pins = LANE_CLASS, apl_era = 'tbc' }
    local pin_table = cfg.pins
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
        if cfg.apl_era == 'wotlk' then
            -- Class-qualified keys disambiguate shared spec names ("holy" is
            -- BOTH priest/holy and paladin/holy; "protection" exists for paladin
            -- and warrior): try wotlk/<class>/<spec> first, mirroring the TBC
            -- branch below. The healer pins are therefore wotlk/priest/holy +
            -- wotlk/priest/discipline (2026-08-10).
            apl = APL_STATUS['wotlk/' .. class_key .. '/' .. spec_key]
                or APL_STATUS['wotlk/' .. spec_key]
                or 'pending'
        elseif cfg.apl_era == 'tbc' then
            -- Class-qualified keys disambiguate shared spec names ("protection"
            -- exists for both paladin and warrior): try tbc/<class>/<spec> first.
            apl = APL_STATUS['tbc/' .. class_key .. '/' .. spec_key]
                or APL_STATUS['tbc/' .. spec_key]
                or APL_STATUS[spec_key]
                or APL_STATUS[class_key .. '/' .. spec_key]
                or 'pending'
        else
            -- Vanilla + SoD: no wowsims APL fixtures are pinned for these eras
            -- (there is no vanilla-era wowsims project, and SoD has no
            -- APL-conformance manifest), so rows honestly read 'pending' — the
            -- behavioral battery is the source of truth there.
            apl = 'pending'
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
                .. tostring(APL_EVIDENCE[era .. '/' .. class_key .. '/' .. spec_key]
                    or APL_EVIDENCE['tbc/' .. class_key .. '/' .. spec_key]
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

-- Era coverage (2026-09-06, #1-roadmap P0): Vanilla (40 specs) and SoD (20
-- roles) join the scorecard so every era carries a per-spec rating.
local vanilla_agg = battery.run_all('vanilla')
if vanilla_agg == nil or type(vanilla_agg) ~= 'table' or vanilla_agg.reports == nil then
    io.stderr:write('spec_scorecard: battery run_all("vanilla") returned no reports\n')
    os.exit(3)
end
local sod_agg = battery.run_all('sod')
if sod_agg == nil or type(sod_agg) ~= 'table' or sod_agg.reports == nil then
    io.stderr:write('spec_scorecard: battery run_all("sod") returned no reports\n')
    os.exit(3)
end
-- WoW Forever (2026-09-15, beta 2026-09-17 / launch 2026-11-04): the forever
-- era runs the SAME _vanilla spec files under the forever harness
-- (_forever -> _vanilla fallback), so its battery is vanilla's lane-for-lane
-- twin and inherits the vanilla lane pins until real _forever delta files
-- land post-beta (docs/forever/dbc_runbook.md).
local forever_agg = battery.run_all('forever')
if forever_agg == nil or type(forever_agg) ~= 'table' or forever_agg.reports == nil then
    io.stderr:write('spec_scorecard: battery run_all("forever") returned no reports\n')
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
local vanilla_rows, vanilla_totals, vanilla_lanes_by_bucket = classify_reports(vanilla_agg, 'vanilla')
local sod_rows, sod_totals, sod_lanes_by_bucket = classify_reports(sod_agg, 'sod')
local forever_rows, forever_totals, forever_lanes_by_bucket = classify_reports(forever_agg, 'forever')

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
    .. '(behavioral_audit.run_all — sylvanas / wotlk / vanilla / sod / forever) + the rotation-runner '
    .. 'registry. Supersedes the '
    .. 'triage-doc "Category counts" paragraphs._')
add('')
emit_totals('TBC/Sylvanas era', agg.total, totals, {
    { 'APL conformant (all eras)', apl_pass_count .. '/' .. apl_total },
    { 'rotation suites (registry)', #all_test_names },
})
emit_totals('WotLK era', wotlk_agg.total, wotlk_totals)
emit_totals('Vanilla era', vanilla_agg.total, vanilla_totals)
emit_totals('SoD era', sod_agg.total, sod_totals)
emit_totals('Forever era', forever_agg.total, forever_totals)
add('')
add('Vanilla rows carry the 12-lane Wave-1.4 triage (2026-08-13: (b) 9 + (c) 3; '
    .. 'MagmaTotem cleared in v2.24.2 on 2026-08-14 — four Classic ranks; full '
    .. 'per-lane evidence in docs/never_strategy_triage_vanilla_2026-08-13.md). '
    .. 'SoD rows carry the W4.3 zero-never result (37-lane inventory cleared '
    .. '2026-08-14). Both eras are STRICT — a future never-lane hard-fails until '
    .. 'pinned. Vanilla + SoD have no wowsims APL fixtures (there is no vanilla-era '
    .. 'wowsims project and no SoD APL-conformance manifest), so their APL column '
    .. 'reads `pending` by design: the behavioral battery is the source of truth.')
add('')
add('Rating rubric: **S+** never=0 ∧ (c)=0 ∧ APL pass · **S** never=0 · **A** never≤3 · '
    .. '**B** never≤6 · **C** never≥7 · **F** (d)>0. Suite columns: class = tests whose '
    .. 'name contains the class keyword; spec = word-matched spec keyword (informational). '
    .. 'WotLK-era rows were triaged in Phase-1 (2026-08-09): the 149-lane inventory was '
    .. 'cleared to **0 never-firing** via battery fixture upgrades (resource/cooldown '
    .. 'accessors, scenario banks, DK stub rewiring), so the era is STRICT like TBC — a '
    .. 'future never-lane is a hard-fail until pinned.')
add('')
add('**Why some healer rows show APL = `pending` (corrected 2026-08-10):** the '
    .. 'earlier claim that "no healer rotation simulator exists for any classic era" '
    .. 'was wrong for WotLK holy/disc priest. wowsims/wotlk HAS a real, executed '
    .. 'healer sim: `sim/priest/healing/healing_priest.go` + `healing_priest_test.go` '
    .. '(TestDisc/TestHoly run with `IsHealer: true` against `core.GetAplRotation` '
    .. 'of `ui/healing_priest/apls/disc.apl.json` + `holy.apl.json`), and both APLs '
    .. 'are now pinned here (keys `wotlk/priest/holy` + `wotlk/priest/discipline`). '
    .. 'Verified claim boundaries: holy/disc priest = real sim + APL (pinned); holy '
    .. 'paladin = engine scaffolding only (`sim/paladin/holy/rotation.go` is a 5s-wait '
    .. 'stub, no `ui/holy_paladin/apls/`); resto druid + resto shaman = agent '
    .. 'scaffolding only (`restoration.go` defines no `OnGCDReady`, no `apls/` dirs); '
    .. 'TBC-era has zero healer dirs and there is no vanilla-era wowsims project '
    .. '(wowsims/classic is SoD) — those rows stay `pending`. See '
    .. 'tools/evidence/apl/SOURCES.md "Healer fixtures" for the full evidence. The '
    .. 'pinned healer APLs are CPM-budget profiles (spellCpm conditions), so the '
    .. 'conformance pins enforce the ORDER of the spell actions (the sim evaluation '
    .. 'order), not the CPM budgets; spells absent from our rotation (holy CoH 48089, '
    .. 'disc filler GH 48063) resolve to nil and impose no constraint, mirroring the '
    .. 'TBC exclusion policy.')
add('')
emit_rows_table('TBC/Sylvanas era', rows, false)
emit_rows_table('WotLK era', wotlk_rows, true)
emit_rows_table('Vanilla era', vanilla_rows, false)
emit_rows_table('SoD era', sod_rows, true)
emit_rows_table('Forever era', forever_rows, false)

add('## APL conformance (computed from pinned fixtures)')
add('')
add('Status is computed live by `tools/apl_status.lua` from the pinned wowsims APL '
    .. 'fixtures (see tools/evidence/apl/SOURCES.md, wowsims/wotlk @ 563e4a08) — '
    .. 'the same manifest `tests/test_apl_conformance.lua` iterates, so this table '
    .. 'and the CI gate can never drift. TBC-era rows are pinned from wowsims/tbc '
    .. 'Go dispatch order (`reference_names` — the TBC repo predates TypeAPL JSON; '
    .. 'see SOURCES.md). WotLK holy/disc priest are pinned from the wowsims healer '
    .. 'APLs (keys `wotlk/priest/holy` + `wotlk/priest/discipline`, 2026-08-10); the '
    .. 'remaining healers (holy paladin, resto druid/shaman, TBC-era) stay `pending` '
    .. '— engine scaffolding only, no implemented rotation (see the healer-fix note '
    .. 'above + SOURCES.md).')
add('')
add('| Spec | Fixture | Verdict | Evidence |')
add('|---|---|---|---|')
local apl_keys = {}
for k in pairs(APL_STATUS) do apl_keys[#apl_keys + 1] = k end
table.sort(apl_keys)
-- Fixture column is DERIVED from the manifest (apl_status.lua ENTRIES), the
-- single source of truth — never a hardcoded per-key map. basename of
-- entry.fixture for JSON pins, else "Go: <go_ref>" for TBC Go-dispatch pins.
-- A manifest key with neither fixture nor go_ref (or a key absent from the
-- manifest entirely) is a HARD FAIL: the dk_frost evidence mislabeling during
-- the pin campaign (scorecard showed the mage frost fixture's evidence) was
-- exactly this drift class — a key the hardcoded map missed rendering the
-- wrong fixture instead of failing.
local manifest_by_key = {}
for _, e in ipairs(apl_mod.ENTRIES or {}) do manifest_by_key[e.key] = e end
for _, k in ipairs(apl_keys) do
    local entry = manifest_by_key[k]
    local fixture
    if entry and entry.fixture then
        fixture = entry.fixture:match('[^/\\]+$') -- basename
    elseif entry and entry.go_ref then
        fixture = 'Go: ' .. entry.go_ref
    end
    if not fixture then
        problems[#problems + 1] = {
            kind = 'badapl',
            msg = 'APL manifest key "' .. tostring(k) .. '" has no fixture or go_ref ' ..
                '(scorecard fixture column cannot render; add one to tools/apl_status.lua)',
        }
        fixture = '-'
    end
    add('| ' .. k .. ' | ' .. fixture .. ' | ' .. APL_STATUS[k] .. ' | '
        .. tostring(APL_EVIDENCE[k] or '-') .. ' |')
end
add('')
emit_buckets('TBC/Sylvanas era', lanes_by_bucket, { 'c', 'b', 'a', 'd' })
emit_buckets('WotLK era', wotlk_lanes_by_bucket, { 'p', 'c', 'b', 'a', 'd' })
emit_buckets('Vanilla era', vanilla_lanes_by_bucket, { 'c', 'b', 'a', 'd' })
emit_buckets('SoD era', sod_lanes_by_bucket, { 'p', 'c', 'b', 'a', 'd' })
emit_buckets('Forever era', forever_lanes_by_bucket, { 'c', 'b', 'a', 'd' })

add('## Notes')
add('')
add('- The 2026-08-10 WotLK APL pin campaign wired every remaining unpinned spec '
    .. 'from its wowsims/wotlk TypeAPL JSON at 563e4a08 (16 new fixtures in '
    .. 'tools/evidence/apl/; provenance in SOURCES.md). The remaining `pending` '
    .. 'WotLK rows are deliberate: `rogue/subtlety` has NO wowsims APL (the rogue '
    .. 'dir ships combat/mutilate only), the `*/leveling` specs are the TBC-era '
    .. 'leveling rotations (no WotLK sim dispatch), and the non-priest healers '
    .. '(holy paladin, resto druid/shaman) are engine scaffolding only — see the '
    .. 'healer-fix note above.')
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
    .. 'wowsims/tbc Go dispatch order. WotLK healer pins (2026-08-10): holy/disc '
    .. 'priest from the real wowsims healing-priest APLs; the rest stay `pending` '
    .. '(no implemented rotation — see the healer-fix note above).')
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
-- Player-facing accuracy page (2026-09-06, #1-roadmap P1-1). Plain-language
-- sibling of docs/scorecard.md: built from the SAME live aggregates (battery
-- never/totals, per-spec ratings, APL verdicts), but written for a player —
-- no lane IDs, no (a)/(b)/(c) buckets, no never-firing jargon. Regenerated
-- and drift-gated together with the scorecard below (one tool, one gate), so
-- the README's accuracy link cannot rot.
-- ---------------------------------------------------------------------------
local A = {}
local function aadd(s) A[#A + 1] = s end

local era_groups = {
    { name = 'Burning Crusade (Project Sylvanas)', label = 'TBC', rows = rows, t = totals },
    { name = 'Wrath of the Lich King', label = 'WotLK', rows = wotlk_rows, t = wotlk_totals },
    { name = 'Vanilla (Classic)', label = 'Vanilla', rows = vanilla_rows, t = vanilla_totals },
    { name = 'Season of Discovery', label = 'Season of Discovery', rows = sod_rows, t = sod_totals },
    { name = 'WoW Forever', label = 'Forever', rows = forever_rows, t = forever_totals },
}
-- The era count and the era name list are DERIVED from the table above: this
-- table is the only owner of "how many eras, and which", so the emitted
-- headline cannot keep saying 4 (2026-09-13: it was a hardcoded
-- 'Game eras covered | 4 -- TBC . WotLK . Vanilla . Season of Discovery').
local era_labels = {}
for i = 1, #era_groups do era_labels[i] = era_groups[i].label end
local ERA_SEP = string.char(0xC2, 0xB7)  -- U+00B7 MIDDLE DOT, built from bytes so the source stays pure ASCII
local era_list = table.concat(era_labels, ' ' .. ERA_SEP .. ' ')
local era_count = #era_groups
local total_specs = #rows + #wotlk_rows + #vanilla_rows + #sod_rows + #forever_rows
local total_strategies = totals.strategies + wotlk_totals.strategies
    + vanilla_totals.strategies + sod_totals.strategies + forever_totals.strategies
local total_dead = totals.d + wotlk_totals.d + vanilla_totals.d + sod_totals.d + forever_totals.d
local total_never = totals.never + wotlk_totals.never + vanilla_totals.never + sod_totals.never + forever_totals.never

local function era_sim_ok(r) return r.apl == 'pass' end

aadd('# EaxRotations — accuracy report')
aadd('')
aadd('Every number below is computed live by `tools/spec_scorecard.lua` from the '
    .. 'same test battery the release gate runs, and the gate re-generates and '
    .. 'compares this page on every run — it cannot go stale. The engineering '
    .. 'version, with per-rule detail, is [docs/scorecard.md](scorecard.md).')
aadd('')

-- ---------------------------------------------------------------------------
aadd('## What a “strategy” is')
aadd('')
aadd('A **strategy** is one decision rule in a spec’s rotation: “when the enemy '
    .. 'is about to die and I have 5 combo points, use Ferocious Bite” is one rule. '
    .. 'Every spec is an ordered list of these rules; each global-cooldown tick, the '
    .. 'first rule whose conditions are true wins the button press.')
aadd('')

-- ---------------------------------------------------------------------------
aadd('## The headline numbers (live)')
aadd('')
aadd('| Claim | Value |')
aadd('|---|---|')
aadd('| Game eras covered | ' .. era_count .. ' ' .. string.char(0xE2, 0x80, 0x94) .. ' ' .. era_list .. ' |')
aadd('| Specs rated | ' .. total_specs .. ' (' .. #rows .. ' TBC · ' .. #wotlk_rows .. ' WotLK · '
    .. #vanilla_rows .. ' Vanilla · ' .. #sod_rows .. ' SoD) |')
aadd('| Decision rules exercised by the test rig | ' .. total_strategies .. ' |')
aadd('| Rules that could never fire in live play (dead code) | ' .. total_dead .. ' — the gate fails if this is ever above 0 |')
aadd('| Rules the rig never triggers, each with a filed written reason | ' .. total_never .. ' |')
aadd('| Behavioral test battery | ' .. #all_test_names .. ' rotation suites — every one must pass or the release gate fails (plus leveling and per-era gates) |')
aadd('| Cast order machine-checked against simulators | ' .. apl_pass_count .. ' of ' .. apl_total .. ' pinned specs (where a simulator exists) |')
aadd('| Unreachable-rule gate | strict in all ' .. era_count .. ' eras — an unexplained unreachable rule fails the release |')
aadd('')
aadd('Every era’s battery is **strict**: if a decision rule ever becomes unreachable '
    .. 'without a filed reason, `run_verify_all` fails. That is why “0 dead code” and '
    .. 'the “unreachable” list below are guarantees, not marketing.')
aadd('')

-- ---------------------------------------------------------------------------
aadd('## What the ratings mean')
aadd('')
aadd('| Rating | Meaning |')
aadd('|---|---|')
aadd('| **S+** | Every rule fires somewhere in the rig **and** the spec’s cast order matches a published simulator rotation |')
aadd('| **S** | Every rule fires somewhere in the rig |')
aadd('| **A / B / C** | A few rules (1–3 / 4–6 / 7+) never fire under test; each carries a filed reason |')
aadd('')
aadd('A rating below S is never silent: every non-firing rule is individually '
    .. 'documented with why, in the engineering scorecard. **Sim-checked** = the '
    .. 'cast order is compared against the simulators’ published rotations. “—” '
    .. 'means no simulator exists for that spec or era (see Known limits).')
aadd('')

-- ---------------------------------------------------------------------------
for _, g in ipairs(era_groups) do
    aadd('## Ratings — ' .. g.name)
    aadd('')
    aadd('| Spec | Rating | Rules the rig never triggers | Sim-checked |')
    aadd('|---|---|---|---|')
    for _, r in ipairs(g.rows) do
        local sim = era_sim_ok(r) and 'yes' or ''
        aadd(string.format('| %s/%s | %s | %d | %s |', r.class, r.spec, rating(r), r.never, sim))
    end
    aadd('')
    aadd('“Rules the rig never triggers” is 0 for every healthy spec. A non-zero value '
        .. 'means the rig cannot construct that exact moment; the reason is on file '
        .. 'and visible in the scorecard.')
    aadd('')
end

-- ---------------------------------------------------------------------------
aadd('## Known limits (honest)')
aadd('')
aadd('1. **Two niche rules are filed as “the rig cannot construct the moment”.** '
      .. 'An Alliance-only retribution paladin damage-seal path in TBC (the rig '
      .. 'never plays an Alliance paladin with that seal armed), and a priest’s '
      .. 'lethal-threat escape (Fade) in Vanilla leveling (building ≥99% threat '
      .. 'would break another rule’s test contract). Both are deliberately classified '
      .. 'with written reasons rather than forced.')
aadd('2. **Healers.** Only WotLK holy and discipline priest cast orders are checked '
      .. 'against a real healing simulator — the simulator repos ship no '
      .. 'implemented rotation for any other healer, so no healer has a comparative '
      .. 'sim benchmark. The full WotLK healer tier (resto druid, holy paladin, resto '
      .. 'shaman, holy + discipline priest) is guide-validated: every spec matches its '
      .. 'published playstyle priority (Icy-Veins / wowsims APL fixtures) with every '
      .. 'rule proven to fire; TBC healers carry the same depth.')
aadd('3. **Leveling rotations** are behavior-validated but have no simulator fixtures '
      .. '(simulators model max-level raid fights).')
aadd('4. **Vanilla and Season of Discovery** have no simulator project to compare '
      .. 'against at all, so their rows reach **S** (every rule proven to fire) rather '
      .. 'than **S+** (sim-checked).')
aadd('5. **No live-client verification.** Every number comes from a rig that replays '
      .. 'the add-on’s real rotation code against simulated World of Warcraft state. '
      .. 'It proves rules are reachable and ordered like the sims — it is not an '
      .. 'in-game DPS measurement.')
aadd('')

-- ---------------------------------------------------------------------------
aadd('## How to check this yourself')
aadd('')
aadd('- Full engineering detail (every rule, every reason): `docs/scorecard.md`.')
aadd('- Run the whole release gate yourself: `lua EaxRotations/tests/run_verify_all.lua` '
      .. '(' .. #all_test_names .. ' rotation suites + leveling + five era batteries + this page’s drift check).')
aadd('- Regenerate this page and the scorecard: `lua tools/spec_scorecard.lua`.')

local accuracy_md = table.concat(A, '\n') .. '\n'

-- ---------------------------------------------------------------------------
-- Drift gate.
-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
-- Derived-claim pass for the hand-maintained pages (2026-09-13).
-- ---------------------------------------------------------------------------
-- The numbers this tool computes have five homes: the two pages it GENERATES
-- (written below) and three HAND-MAINTAINED ones -- EaxRotations/README.md,
-- docs/PER_CLASS_RESEARCH.md and docs/SOD_ROTATIONS.md -- which used to carry
-- hand-typed copies of them (the README specs badge and its alt text, the "132
-- rated spec rotations (31 TBC ...)" intro, the features row, the era never-split
-- line, the APL 50/50 claims, the SoD manifest entry count). Nothing checked
-- those copies, so adding a spec to a battery could leave the README advertising
-- a stale total. Each claim below is now rewritten from the live aggregates, and
-- a claim whose pattern no longer matches is a HARD FAIL: a number that leaves
-- the pattern is a number that left the gate.
local function fmt_thousands(n)
    local rev = tostring(n):reverse():gsub('(%d%d%d)', '%1,'):reverse()
    return (rev:gsub('^,', ''))
end
local wotlk_apl_pass, tbc_apl_pass = 0, 0
for k, v in pairs(APL_STATUS) do
    if v == 'pass' then
        if k:match('^wotlk/') then wotlk_apl_pass = wotlk_apl_pass + 1
        else tbc_apl_pass = tbc_apl_pass + 1 end
    end
end

local README_CLAIMS = {
    { label = 'specs badge URL',
      pat = 'badge/specs%-%d+%%20rated%%20%(%d+%%20eras%)%-brightgreen',
      repl = 'badge/specs-' .. total_specs .. '%%20rated%%20(' .. era_count .. '%%20eras)-brightgreen' },
    { label = 'specs badge alt',
      pat = 'alt="%d+ Specs Rated Across %d+ Eras',
      repl = 'alt="' .. total_specs .. ' Specs Rated Across ' .. era_count .. ' Eras' },
    -- [%a%d]+ matches both the old word form ("four") and the derived digits, so
    -- the claim survives its own first rewording.
    { label = 'intro era count + spec split',
      pat = 'Across the [%a%d]+ eras it ships %*%*(%d+) rated spec rotations%*%* %((%d+) TBC ' .. ERA_SEP
            .. ' (%d+) WotLK ' .. ERA_SEP .. ' (%d+) Vanilla ' .. ERA_SEP .. ' (%d+) SoD ' .. ERA_SEP
            .. ' (%d+) Forever%)',
      repl = 'Across the ' .. era_count .. ' eras it ships **' .. total_specs .. ' rated spec rotations** ('
            .. #rows .. ' TBC ' .. ERA_SEP .. ' ' .. #wotlk_rows .. ' WotLK ' .. ERA_SEP .. ' '
            .. #vanilla_rows .. ' Vanilla ' .. ERA_SEP .. ' ' .. #sod_rows .. ' SoD ' .. ERA_SEP .. ' '
            .. #forever_rows .. ' Forever)' },
    { label = 'features row spec total + era count',
      pat = '%*%*(%d+) Rated Spec Rotations%*%* %| (%d+) eras,',
      repl = '**' .. total_specs .. ' Rated Spec Rotations** | ' .. era_count .. ' eras,' },
    { label = 'pinned-specs claim',
      pat = '%*%*(%d+)/(%d+)%*%* pinned specs pass',
      repl = '**' .. apl_pass_count .. '/' .. apl_total .. '** pinned specs pass' },
}

local PCR_CLAIMS = {
    { label = 'conformance manifest line',
      pat = '| (%d+)/(%d+) specs pass;',
      repl = '| ' .. apl_pass_count .. '/' .. apl_total .. ' specs pass;' },
    { label = 'decision-rule total',
      pat = '~?[%d,]+ decision rules across %d+ specs',
      repl = fmt_thousands(total_strategies) .. ' decision rules across ' .. total_specs .. ' specs' },
    { label = 'era never-split',
      pat = 'tbc %d+ ' .. ERA_SEP .. ' wotlk %d+ ' .. ERA_SEP .. ' vanilla %d+ ' .. ERA_SEP .. ' sod %d+ '
            .. ERA_SEP .. ' forever %d+',
      repl = 'tbc ' .. totals.never .. ' ' .. ERA_SEP .. ' wotlk ' .. wotlk_totals.never .. ' ' .. ERA_SEP
            .. ' vanilla ' .. vanilla_totals.never .. ' ' .. ERA_SEP .. ' sod ' .. sod_totals.never .. ' '
            .. ERA_SEP .. ' forever ' .. forever_totals.never },
    { label = 'strict-across-eras word count',
      pat = 'strict across all [%a%d]+ eras',
      repl = 'strict across all ' .. era_count .. ' eras' },
    { label = 'APL era split',
      pat = '(%d+)/(%d+) APL conformance, WotLK (%d+) specs pinned to `wowsims/wotlk` %+ (%d+) TBC',
      repl = apl_pass_count .. '/' .. apl_total .. ' APL conformance, WotLK ' .. wotlk_apl_pass
            .. ' specs pinned to `wowsims/wotlk` + ' .. tbc_apl_pass .. ' TBC' },
    { label = 'WotLK spec count',
      pat = 'across all %d+ WotLK specs',
      repl = 'across all ' .. #wotlk_rows .. ' WotLK specs' },
    { label = 'rated-spec total in prose',
      pat = 'So the honest ranking of the %d+ rated specs',
      repl = 'So the honest ranking of the ' .. total_specs .. ' rated specs' },
}

local SOD_CLAIMS = {
    { label = 'SoD manifest entry count',
      pat = 'contains exactly (%d+) entries across nine classes',
      repl = 'contains exactly ' .. #sod_rows .. ' entries across nine classes' },
    { label = 'SoD files-above count',
      pat = 'the (%d+) files above own rotation priorities',
      repl = 'the ' .. #sod_rows .. ' files above own rotation priorities' },
}
local function claim_pass(path, claims)
    local text = read_file(path)
    if not text then return nil, false, { path .. ': missing file' } end
    local changed, missing = {}, {}
    for _, c in ipairs(claims) do
        local hits = 0
        for _ in text:gmatch(c.pat) do hits = hits + 1 end
        if hits == 0 then
            missing[#missing + 1] = c.label .. ' (pattern no longer matches)'
        elseif hits > 1 then
            missing[#missing + 1] = c.label .. ' (ambiguous: ' .. hits .. ' matches)'
        else
            local new = text:gsub(c.pat, c.repl, 1)
            if new ~= text then changed[#changed + 1] = c.label; text = new end
        end
    end
    return text, changed, missing
end

local claim_readme_path = ROOT .. '/EaxRotations/README.md'
local claim_pcr_path = ROOT .. '/EaxRotations/docs/PER_CLASS_RESEARCH.md'
local claim_readme_new, readme_claim_changes, readme_missing = claim_pass(claim_readme_path, README_CLAIMS)
local claim_pcr_new, pcr_claim_changes, pcr_missing = claim_pass(claim_pcr_path, PCR_CLAIMS)
local claim_readme_drift = #readme_claim_changes > 0
local claim_pcr_drift = #pcr_claim_changes > 0
local claim_missing = {}
for _, m in ipairs(readme_missing) do claim_missing[#claim_missing + 1] = 'README.md: ' .. m end
for _, m in ipairs(pcr_missing) do claim_missing[#claim_missing + 1] = 'PER_CLASS_RESEARCH.md: ' .. m end
local claim_sod_path = ROOT .. '/EaxRotations/docs/SOD_ROTATIONS.md'
local claim_sod_new, sod_claim_changes, sod_missing = claim_pass(claim_sod_path, SOD_CLAIMS)
local claim_sod_drift = #sod_claim_changes > 0
for _, m in ipairs(sod_missing) do claim_missing[#claim_missing + 1] = 'SOD_ROTATIONS.md: ' .. m end
-- The doc's own inventory table is the other half of this claim: if the derived
-- SoD spec count and the rows the doc prints disagree, a rewrite would state a
-- number the table beside it contradicts, so refuse rather than write.
local sod_doc_rows = 0
if claim_sod_new then for _ in claim_sod_new:gmatch('\n| %d+ |') do sod_doc_rows = sod_doc_rows + 1 end end
if sod_doc_rows ~= #sod_rows then
    claim_missing[#claim_missing + 1] = 'SOD_ROTATIONS.md: inventory table has ' .. sod_doc_rows
        .. ' numbered row(s), the SoD battery reports ' .. #sod_rows
end

local scorecard_path = ROOT .. '/EaxRotations/docs/scorecard.md'
local accuracy_path = ROOT .. '/EaxRotations/docs/ACCURACY.md'
-- EOL-insensitive reads: with core.autocrlf a fresh Windows checkout renders
-- the tracked LF blobs as CRLF on disk, and a raw byte compare failed the
-- drift check on every such checkout while CI (Linux) stayed green. The
-- generated side is always LF, so normalize before comparing.
local old = read_file(scorecard_path)
if old then old = old:gsub(string.char(13, 10), string.char(10)) end
local old_acc = read_file(accuracy_path)
if old_acc then old_acc = old_acc:gsub(string.char(13, 10), string.char(10)) end
local doc_drift = (old ~= markdown) or (old_acc ~= accuracy_md)
    or claim_readme_drift or claim_pcr_drift or claim_sod_drift
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
if vanilla_totals.d > 0 then
    hard_fail = true
    problems[#problems + 1] = { kind = 'dead', msg = 'Vanilla dead lanes must stay 0 (got ' .. vanilla_totals.d .. ')' }
end
if sod_totals.d > 0 then
    hard_fail = true
    problems[#problems + 1] = { kind = 'dead', msg = 'SoD dead lanes must stay 0 (got ' .. sod_totals.d .. ')' }
end

if #claim_missing > 0 then
    io.stderr:write('spec_scorecard: HARD FAIL - derived-claim anchors are out of date:\n')
    for _, m in ipairs(claim_missing) do io.stderr:write('  - ' .. m .. '\n') end
    io.stderr:write('  A claim that no longer matches means that number left the gate. Update the\n')
    io.stderr:write('  claim pattern in tools/spec_scorecard.lua to the new wording (or restore it).\n')
    os.exit(3)
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
            io.stderr:write('  docs/scorecard.md / docs/ACCURACY.md and/or the derived claims in\n')
            io.stderr:write('  EaxRotations/README.md, docs/PER_CLASS_RESEARCH.md and docs/SOD_ROTATIONS.md\n')
            io.stderr:write('  are stale. A claim anchor that no longer matches is reported as a HARD FAIL.\n')
            for _, c in ipairs(readme_claim_changes) do io.stderr:write('    - README.md: ' .. c .. '\n') end
            for _, c in ipairs(pcr_claim_changes) do io.stderr:write('    - PER_CLASS_RESEARCH.md: ' .. c .. '\n') end
            for _, c in ipairs(sod_claim_changes) do io.stderr:write('    - SOD_ROTATIONS.md: ' .. c .. '\n') end
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
        'spec_scorecard: in sync (tbc never=%d a=%d b=%d c=%d d=%d | wotlk never=%d p=%d | vanilla never=%d | sod never=%d | forever never=%d, ratings S/S+=%d/%d, apl pass=%d/%d)',
        totals.never, totals.a, totals.b, totals.c, totals.d,
        wotlk_totals.never, wotlk_totals.p,
        vanilla_totals.never, sod_totals.never, forever_totals.never,
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
if claim_readme_drift and claim_readme_new then
    if write_file(claim_readme_path, claim_readme_new) then
        print('  wrote ' .. claim_readme_path)
        for _, c in ipairs(readme_claim_changes) do print('    - ' .. c) end
    end
end
if claim_pcr_drift and claim_pcr_new then
    if write_file(claim_pcr_path, claim_pcr_new) then
        print('  wrote ' .. claim_pcr_path)
        for _, c in ipairs(pcr_claim_changes) do print('    - ' .. c) end
    end
end
if claim_sod_drift and claim_sod_new then
    if write_file(claim_sod_path, claim_sod_new) then
        print('  wrote ' .. claim_sod_path)
        for _, c in ipairs(sod_claim_changes) do print('    - ' .. c) end
    end
end
local acc_ok = write_file(accuracy_path, accuracy_md)
if acc_ok then
    print('  wrote ' .. accuracy_path)
else
    io.stderr:write('spec_scorecard: cannot write ' .. accuracy_path .. '\n')
    os.exit(3)
end
if write_file(scorecard_path, markdown) then
    print('  wrote ' .. scorecard_path)
    print(string.format('  totals: tbc never=%d (a=%d b=%d c=%d d=%d) | wotlk never=%d (p=%d) | vanilla never=%d | sod never=%d | forever never=%d | %d+%d+%d+%d+%d specs',
        totals.never, totals.a, totals.b, totals.c, totals.d,
        wotlk_totals.never, wotlk_totals.p, vanilla_totals.never, sod_totals.never, forever_totals.never,
        #rows, #wotlk_rows, #vanilla_rows, #sod_rows, #forever_rows))
    if stale_count > 0 then
        print('  NOTE: ' .. stale_count .. ' stale pin(s) reported above - run --check after fixing LANE_CLASS')
    end
else
    io.stderr:write('spec_scorecard: cannot write ' .. scorecard_path .. '\n')
    os.exit(3)
end
