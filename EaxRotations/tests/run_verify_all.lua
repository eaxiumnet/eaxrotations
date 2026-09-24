-- verify_all.lua -- full verification matrix in one shot.
-- WHAT:  runs rotation + leveling + WotLK tests, the 4 spell-ID audits
--        (sylvanas/vanilla-contamination/vanilla-existence/wotlk), the three
--        audits' --self-test pinned-rank enforcement modes (vanilla TBC_IDS,
--        sylvanas WOTLK_ONLY_IDS, wotlk allowlist + rank-top), the spell-id
--        sweep gate + its non-vacuity self-test
--        (tests/run_spell_id_sweep_check.lua -> tools/spell_id_sweep.py
--        --check: every pinned id re-derived from the TBC DBC set, both
--        Wowhead index dumps, the wowsims fixtures and the audit pin tables,
--        then compared to the committed classified-once baseline — the
--        `gate` buckets must stay empty and the `pinned` buckets are frozen,
--        so a NEW wrong-family id hard-fails, exactly like a never-fire
--        baseline breach), the
--        behavioral battery (all three eras: TBC sylvanas, wotlk, and the
--        vanilla era wired 2026-08-11 with its 79-lane classified baseline), the
--        era-pair coverage audit (era-mirror strategy
--        divergence baseline, run_era_pair_audit_tests.lua) plus its seed
--        freshness guard (the committed era_pair_seed.lua must match a fresh
--        regeneration — run_era_pair_seed_freshness.lua), and the state-field
--        audit (run_state_field_audit_tests.lua: every build_state state-table
--        field must be read somewhere in its file or pinned in the audit's
--        CROSS_FILE_READS allowlist — the computed-but-unread class that let
--        fury_vanilla's pummel_ready ship un-consumed for 18 months and hid
--        shadow silence_ready / frost counterspell_ready as dead weight) plus
--        its self-test, and the
--        clean-checkout dependency probe
--        (run_clean_checkout_probe.lua -- flags any test file-read target
--        that resolves to a gitignored file instead of a tracked or
--        self-provisioning path, so the 5-suite env-gap class can never
--        silently return), and the shipped-module enrollment probe (every .lua
--        under shared/ and below classes/<class>/<subdir>/ must be
--        git-tracked, the nested ones required, so a forgotten `git add`
--        cannot reach CI green); parses each runner's own totals instead of
--        trusting exit codes (the rotation runner exits 0 even when suites
--        fail).
-- WHEN:  invoked via lua EaxRotations/tests/run_verify_all.lua (or CI).
-- WHY:   single entry point that fails ONLY on *unexpected* failures. The 5
--        rotation suites that fail on missing env/data-file inputs are
--        allowed (see docs/rotation_suite_env_gap_triage_2026-08-08.md for
--        exactly what each needs and how to provision it).
-- EXIT:  0 = green; 1 = at least one unexpected failure. Any allowed
--        failure that starts PASSING is reported as a NOTE (the env gap was
--        provisioned -- update ALLOWED_ROTATION_FAILURES).
-- SAFETY: pure orchestration; only spawns the existing runners via
--         os.execute. No rotation logic, no io writes beyond a temp capture.
-- NOTE:   Named run_verify_all.lua (not verify_all.lua) on purpose:
--         test_spec_layout_compliance's banned-API scan of EaxRotations/tests/
--         exempts run_*.lua runners -- os.execute is required here to spawn
--         the sub-runners and would otherwise be flagged.
-- NOTE:   The 5 allowed rotation failures are not all env gaps: 3 are missing
--         data/evidence inputs and 2 are documented test-code bugs awaiting
--         their verified fixes (see docs/rotation_suite_env_gap_triage_2026-08-08.md
--         sections 2 and 5). Their fail/pass status can also flip run-to-run
--         because the rotation runner shares one process, so they are allowed
--         regardless of which side they land on until fixed.
-- NOTE:   The behavioral battery assertions PIN the live contract (31
--         specs / 0 load failures / 78 never-firing after the Phase-3 (c)
--         fixture batches: readiness_window, serpent_refresh, clearcast_surge,
--         elem_shock_moving, elem_shock_pvp — cleared hunter Readiness x3 +
--         SerpentStingRefresh x2, holy clearcast/surge, elem moving shocks —
--         then the 2026-08-09 healer (c) close-out (holy_*/smite_*/shadow_*/
--         resto_* scenarios) cleared the 13 healer lanes 91->78, and the
--         batch-2 (c) close-out (hurricane_aoe/rebirth_dead_ally/bear_*/
--         cat_*/bm_trinket/mm_aimed_opener/prot_*/ret_cleanse_self/elem_*/
--         enh_interrupt/enh_low_mana scenarios + the BM Trinket is_item_ready
--         dead-lane fix) cleared 18 more 78->60, and the (a) opt-in
--         close-out (2026-08-10: moonkin_form_optin/bear_barkskin/cat_rip_trick/
--         cat_shred_trick/frost_*_optin/prot_avenger_shield/prot_hammer_wrath/
--         prot_judgement/prot_seal_command/ret_consecration/ret_consec_dump/
--         enh_goa_twist scenarios + the buff/debuff spell_action-object
--         normalization for enh totem auras) cleared the 14 remaining (a)
--         lanes 60->46, the (b) bucket close-out (2026-08-10: PvP
--         mega-scenario + cc_target/succubus/melee_on_you/enemy_healer/
--         fear_nearby fixtures, combat_time+use_misdirection, race variants,
--         snare-debuff fixtures, ChallengingRoar toggle, AutoAttack stub)
--         cleared the 28 fixture-modelable lanes 46->19 (9 correctly-silent +
--         EncounterReactions declined + the 3 (c) unpinnable remain), and the
--         threat-family + race close-out (2026-08-10: target-target/threat/
--         focused-ally stub surface for bear Growl, prot RighteousDefense/BoP,
--         BM FeignDeath, plus the shadow DevouringPlague race-5 load) cleared
--         19->13. When a lane is cleared or a scenario is added, update
--         these expectations here, otherwise verify_all will (correctly) fail
--         until they are bumped.

local R = "EaxRotations/tests"

-- No residual env/data-file gaps after the 2026-08-08 provisioning pass —
-- the rotation suite is 466/466. The 5 former gaps were resolved as:
--   - test_aoe_range_audit_contracts: plan doc tracked at
--     EaxRotations/docs/aoe_range_audit_plan_2026-07-16.md
--   - test_sod_rotation_matrix: warden fixture context fixed in-test
--   - test_sod_warlock_warrior_adversarial: require multi-return spread fixed
--   - test_id_audit_report: regenerated offline into
--     EaxRotations/tools/buff_debuff_full_verification.json (tracked)
--   - test_sod_source_audit: self-provisions its gitignored evidence artifact
--     from the tracked generator EaxRotations/tools/generate_sod_task1_action_map.lua
-- Anything failing here is a regression. See
-- docs/rotation_suite_env_gap_triage_2026-08-08.md.
local ALLOWED_ROTATION_FAILURES = {}

local CAPTURE = "verify_all_capture.txt"

local function capture(cmd)
    -- os.tmpname() keeps concurrent runs from colliding; fall back to a fixed
    -- name if the platform cannot provide one.
    local path = os.tmpname() or CAPTURE
    os.remove(path)
    os.execute(cmd .. " > \"" .. path .. "\" 2>&1")
    local f = io.open(path, "rb")
    local content = f and f:read("*a") or ""
    if f then f:close() end
    os.remove(path)
    return content
end

local function num(content, pattern)
    local v = content:match(pattern)
    return v and tonumber(v)
end

-- Each component: label, shell command, and a check(content) that returns a
-- list of { description, passed } assertions.
local components = {
    -- Doc suite-count drift: tools/update_badges.lua REPAIRS the badge-shaped counts
    -- it knows; this gate FAILS CLOSED on EVERY suite-count mention in the
    -- current-state docs (README, the generated ACCURACY/scorecard, the PVP footer,
    -- the research dossier). It exists because the 2026-09-13 count bump was
    -- hand-edited and left two stale 563s: a "563-suite release battery" phrasing the
    -- badge tool's substitution list did not know, and a hardcoded literal in the
    -- ACCURACY generator. An unclassified phrasing fails by design and the per-file
    -- mention inventory is pinned, so the gate cannot pass vacuously.
    {
        label = "doc suite-count drift",
        cmd = "lua tools/doc_suite_count_check.lua",
        check = function(c)
            return { { "in-sync marker present (every suite-count mention matches the registry)",
                       c:find("in sync", 1, true) ~= nil },
                     { "no wrong-count / unclassified / inventory markers",
                       c:find("wrong count", 1, true) == nil
                       and c:find("unclassified", 1, true) == nil
                       and c:find("inventory changed", 1, true) == nil } }
        end,
    },
    -- Its self-test: pins the fail-closed classifier (a NEW phrasing fails), the
    -- residual scan's precision, the historical-line exemption, and that the
    -- comparison follows the injected registry counts rather than today's numbers.
    {
        label = "doc suite-count self-test",
        cmd = "lua tools/doc_suite_count_check.lua --self-test",
        check = function(c)
            return { { "self-test [PASS] marker present", c:find("[PASS]", 1, true) ~= nil } }
        end,
    },
    {
        label = "rotation suite",
        cmd = "lua " .. R .. "/run_rotation_tests.lua",
        check = function(c)
            local total = num(c, "Total:%s*(%d+)%s*suites")
            local passed = num(c, "Passed:%s*(%d+)")
            local failed = num(c, "Failed:%s*(%d+)")
            local failed_suites = {}
            local seen_fail = {}
            local in_fail = false
            for line in c:gmatch("[^\r\n]+") do
                if line:find("Failed suites:", 1, true) then
                    in_fail = true
                elseif in_fail then
                    local name = line:match("^%s*%-%s*(%S+)$")
                    if name and not seen_fail[name] then
                        seen_fail[name] = true
                        failed_suites[#failed_suites + 1] = name
                    end
                end
            end
            local unexpected = {}
            for _, name in ipairs(failed_suites) do
                if not ALLOWED_ROTATION_FAILURES[name] then
                    unexpected[#unexpected + 1] = name
                end
            end
            local provisioned = {}
            for name in pairs(ALLOWED_ROTATION_FAILURES) do
                local still_fails = false
                for _, fn in ipairs(failed_suites) do
                    if fn == name then still_fails = true end
                end
                if not still_fails then provisioned[#provisioned + 1] = name end
            end
            local results = {
                { "reported " .. tostring(total) .. " suites / " .. tostring(passed)
                    .. " passed / " .. tostring(failed) .. " failed",
                  total ~= nil and passed ~= nil and failed ~= nil },
                { "no unexpected failures (unexpected: "
                    .. (#unexpected > 0 and table.concat(unexpected, ", ") or "none") .. ")",
                  #unexpected == 0 },
            }
            if #provisioned > 0 then
                results[#results + 1] =
                    { "NOTE: allowed gap now passing (update ALLOWED_ROTATION_FAILURES): "
                        .. table.concat(provisioned, ", "), true }
            end
            return results
        end,
    },
    {
        label = "leveling suite",
        cmd = "lua " .. R .. "/run_leveling_tests.lua",
        check = function(c)
            local failed = num(c, "Failed:%s*(%d+)")
            return { { "failed " .. tostring(failed), failed == 0 } }
        end,
    },
    {
        label = "wotlk tests",
        cmd = "lua " .. R .. "/run_wotlk_tests.lua",
        check = function(c)
            local failed = num(c, "Failed:%s*(%d+)")
            return { { "failed " .. tostring(failed), failed == 0 } }
        end,
    },
    {
        label = "sylvanas spell audit",
        cmd = "lua " .. R .. "/run_sylvanas_audit_tests.lua",
        check = function(c)
            local invalid = num(c, "Invalid:%s*(%d+)")
            return { { "invalid " .. tostring(invalid), invalid == 0 } }
        end,
    },
    {
        label = "vanilla contamination audit",
        cmd = "lua " .. R .. "/run_vanilla_audit_tests.lua",
        check = function(c)
            local tainted = num(c, "Tainted:%s*(%d+)")
            return { { "tainted " .. tostring(tainted), tainted == 0 } }
        end,
    },
    {
        label = "vanilla existence audit",
        cmd = "lua " .. R .. "/run_vanilla_existence_audit.lua",
        check = function(c)
            local invalid = num(c, "Invalid:%s*(%d+)")
            return { { "invalid " .. tostring(invalid), invalid == 0 } }
        end,
    },
    {
        label = "wotlk spell audit",
        cmd = "lua " .. R .. "/run_wotlk_audit_tests.lua",
        check = function(c)
            local invalid = num(c, "Invalid:%s*(%d+)")
            local unverified = num(c, "Unverified:%s*(%d+)")
            return {
                { "invalid " .. tostring(invalid), invalid == 0 },
                { "unverified " .. tostring(unverified), unverified == 0 },
            }
        end,
    },
    -- Pinned-rank enforcement self-tests: each audit's --self-test asserts its
    -- pinned spell-ID allowlists/blocklists still fire (vanilla TBC_IDS pins,
    -- sylvanas WOTLK_ONLY_IDS pins, wotlk allowlist + rank-top enforcement).
    -- A dropped pin aborts the runner with a non-zero exit and no [PASS] line,
    -- so the [PASS] marker check below fails the build.
    {
        label = "sylvanas audit self-test",
        cmd = "lua " .. R .. "/run_sylvanas_audit_tests.lua --self-test",
        check = function(c)
            return { { "self-test [PASS] marker present (WOTLK_ONLY_IDS pins fire)",
                       c:find("[PASS]", 1, true) ~= nil } }
        end,
    },
    {
        label = "vanilla audit self-test",
        cmd = "lua " .. R .. "/run_vanilla_audit_tests.lua --self-test",
        check = function(c)
            return { { "self-test [PASS] marker present (TBC_IDS pins fire)",
                       c:find("[PASS]", 1, true) ~= nil } }
        end,
    },
    {
        label = "wotlk audit self-test",
        cmd = "lua " .. R .. "/run_wotlk_audit_tests.lua --self-test",
        check = function(c)
            return { { "self-test [PASS] marker present (allowlist + rank-top pins fire)",
                       c:find("[PASS]", 1, true) ~= nil } }
        end,
    },
    -- Spell-id sweep gate (2026-09-13): re-derives every pinned id from the
    -- local sources and compares the result to the committed, classified-once
    -- baseline (EaxRotations/tools/spell_id_sweep_baseline.json). Each of the
    -- sweep's buckets carries a disposition frozen in the tool's
    -- CHECK_DISPOSITION: `gate` buckets (DEAD, REJECTED-ID-IN-USE,
    -- ERA-TBC-IN-VANILLA, ERA-WOTLK-IN-TBC) are proofs of wrongness and must
    -- stay empty (--write-baseline refuses to pin one), while `pinned` buckets
    -- (REDIRECTED, WRONG-RANK, RANK-ORDER, PIN-FAMILY-MISMATCH,
    -- DUPLICATE-CONFLICT, UNSOURCED) freeze the adjudicated finding set entry by
    -- entry (check|id|file, so line/label drift is not id drift). A NEW finding
    -- — a wrong-family id the baseline has never seen, the 48927 fabricated-id
    -- / SodCleave-25286-Heroic-Strike shape — fails the build; so does CLEARING
    -- one, until the pin is moved on purpose. Its self-test injects a
    -- mislabelled pin + an unknown id and proves both fire AND classify NEW.
    {
        label = "spell-id sweep",
        cmd = "lua " .. R .. "/run_spell_id_sweep_check.lua",
        check = function(c)
            local new = num(c, "NEW:%s*(%d+)")
            local cleared = num(c, "CLEARED:%s*(%d+)")
            local hard = num(c, "HARD:%s*(%d+)")
            return {
                { "no new findings vs the pinned baseline (NEW: " .. tostring(new) .. ")",
                  new == 0 },
                { "no cleared pins (CLEARED: " .. tostring(cleared)
                    .. " — re-baseline deliberately if intended)", cleared == 0 },
                { "hard findings " .. tostring(hard)
                    .. " (gate buckets: DEAD / REJECTED-ID-IN-USE / era leaks)", hard == 0 },
                { "in-sync marker present (buckets match the classified-once baseline)",
                  c:find("verdict: in sync", 1, true) ~= nil },
            }
        end,
    },
    {
        label = "spell-id sweep self-test",
        cmd = "lua " .. R .. "/run_spell_id_sweep_check.lua --self-test",
        check = function(c)
            return { { "self-test [PASS] marker present (wrong-family pin + unknown id fire, "
                        .. "correct pin stays silent, both classify NEW)",
                       c:find("[PASS]", 1, true) ~= nil } }
        end,
    },
    {
        label = "cache-hit safe_state audit",
        cmd = "lua " .. R .. "/run_cache_hit_audit_tests.lua",
        check = function(c)
            local invalid = num(c, "Invalid:%s*(%d+)")
            return { { "invalid " .. tostring(invalid), invalid == 0 } }
        end,
    },
    {
        label = "cache-hit audit self-test",
        cmd = "lua " .. R .. "/run_cache_hit_audit_tests.lua --self-test",
        check = function(c)
            return { { "self-test [PASS] marker present (raw-return violations fire)",
                       c:find("[PASS]", 1, true) ~= nil } }
        end,
    },
    {
        label = "dead-matcher audit",
        cmd = "lua " .. R .. "/run_dead_matcher_audit_tests.lua",
        check = function(c)
            local invalid = num(c, "Invalid:%s*(%d+)")
            return { { "invalid " .. tostring(invalid), invalid == 0 } }
        end,
    },
    {
        label = "dead-matcher audit self-test",
        cmd = "lua " .. R .. "/run_dead_matcher_audit_tests.lua --self-test",
        check = function(c)
            return { { "self-test [PASS] marker present (dead matchers fire)",
                       c:find("[PASS]", 1, true) ~= nil } }
        end,
    },
    {
        label = "state-field audit",
        cmd = "lua " .. R .. "/run_state_field_audit_tests.lua",
        check = function(c)
            local invalid = num(c, "Invalid:%s*(%d+)")
            return { { "invalid " .. tostring(invalid), invalid == 0 } }
        end,
    },
    {
        label = "state-field audit self-test",
        cmd = "lua " .. R .. "/run_state_field_audit_tests.lua --self-test",
        check = function(c)
            return { { "self-test [PASS] marker present (dead fields fire)",
                       c:find("[PASS]", 1, true) ~= nil } }
        end,
    },
    {
        label = "read-side audit",
        cmd = "lua " .. R .. "/run_read_side_audit_tests.lua",
        check = function(c)
            local invalid = num(c, "Invalid:%s*(%d+)")
            return { { "invalid " .. tostring(invalid), invalid == 0 } }
        end,
    },
    {
        label = "read-side audit self-test",
        cmd = "lua " .. R .. "/run_read_side_audit_tests.lua --self-test",
        check = function(c)
            return { { "self-test [PASS] marker present (unproduced reads fire)",
                       c:find("[PASS]", 1, true) ~= nil } }
        end,
    },
    {
        label = "version-consistency audit",
        cmd = "lua " .. R .. "/run_version_consistency_audit_tests.lua",
        check = function(c)
            return { { "header.lua version matches CHANGELOG top (no MISMATCH)",
                       c:find("MISMATCH", 1, true) == nil and c:find("matches the top changelog release", 1, true) ~= nil } }
        end,
    },
    {
        label = "version-consistency audit self-test",
        cmd = "lua " .. R .. "/run_version_consistency_audit_tests.lua --self-test",
        check = function(c)
            return { { "self-test [PASS] marker present (mismatch detection fires)",
                       c:find("[PASS]", 1, true) ~= nil } }
        end,
    },
    -- The release-staleness guard's own assertions. Offline and deterministic
    -- (injected tag lists, never the network), so it is a component here like
    -- every sibling audit self-test; only the guard's live remote check is
    -- network-bound and therefore CI-only.
    {
        label = "release-staleness guard self-test",
        cmd = "lua tools/release_staleness_check.lua --self-test",
        check = function(c)
            return { { "self-test [PASS] marker present (version compare + verdicts fire)",
                       c:find("[PASS]", 1, true) ~= nil } }
        end,
    },
    {
        label = "release zip audit self-test",
        cmd = "lua tools/run_release_zip_audit_selftest.lua",
        check = function(c)
            return { { "self-test [PASS] marker present (header/asset extraction + synthetic-zip audit path fire)",
                       c:find("[PASS]", 1, true) ~= nil } }
        end,
    },
    {
        label = "ns-member audit",
        cmd = "lua " .. R .. "/run_ns_member_audit_tests.lua",
        check = function(c)
            local invalid = num(c, "Invalid:%s*(%d+)")
            return { { "invalid " .. tostring(invalid), invalid == 0 } }
        end,
    },
    {
        label = "ns-member audit self-test",
        cmd = "lua " .. R .. "/run_ns_member_audit_tests.lua --self-test",
        check = function(c)
            return { { "self-test [PASS] marker present (bare NS-member calls fire)",
                       c:find("[PASS]", 1, true) ~= nil } }
        end,
    },
    {
        label = "ns-member audit CI-parity",
        cmd = "lua " .. R .. "/run_ns_member_audit_tests.lua --ci-parity",
        check = function(c)
            return { { "CI-parity [PASS] marker present (configured == forced-CI verdict)",
                       c:find("[PASS]", 1, true) ~= nil } }
        end,
    },
    {
        label = "era-pair audit",
        cmd = "lua " .. R .. "/run_era_pair_audit_tests.lua",
        check = function(c)
            local unallowed = num(c, "(%d+) unallowlisted%)")
            return { { "unallowlisted divergences " .. tostring(unallowed) .. " (expected 0)",
                       unallowed == 0 } }
        end,
    },
    {
        label = "era-pair audit self-test",
        cmd = "lua " .. R .. "/run_era_pair_audit_tests.lua --self-test",
        check = function(c)
            return { { "self-test [PASS] marker present (era gaps fire)",
                       c:find("[PASS]", 1, true) ~= nil } }
        end,
    },
    {
        label = "era-pair seed freshness",
        cmd = "lua " .. R .. "/run_era_pair_seed_freshness.lua",
        check = function(c)
            return { { "seed in-sync marker present, no DRIFT (matches a fresh regeneration)",
                       c:find("in sync", 1, true) ~= nil and c:find("DRIFT", 1, true) == nil } }
        end,
    },
    {
        label = "era-pair seed freshness self-test",
        cmd = "lua " .. R .. "/run_era_pair_seed_freshness.lua --self-test",
        check = function(c)
            return { { "self-test [PASS] marker present (corrupted-seed drift detection fires)",
                       c:find("[PASS]", 1, true) ~= nil } }
        end,
    },
    {
        label = "behavioral battery",
        cmd = "lua " .. R .. "/behavioral_audit.lua",
        check = function(c)
            local specs = num(c, "Total:%s*(%d+)%s*|")
            local load_fail = num(c, "Load failures:%s*(%d+)")
            local never = 0
            for _ in c:gmatch("NEVER:") do never = never + 1 end
            return {
                { "specs " .. tostring(specs) .. " (expected 31)", specs == 31 },
                { "load failures " .. tostring(load_fail) .. " (expected 0)", load_fail == 0 },
                -- 2026-08-12 live-correctness campaign: 13 -> 16 (rogue
                -- ExposeArmor (a) + Sap (c) pins + paladin Ret_SealMartyr_Primary
                -- (c), introduced by the seal rewrite; pinned in
                -- tools/spec_scorecard.lua LANE_CLASS). 2026-09-06
                -- execute-capture campaign: 14 -> 12 (druid/cat RakeSnapshot +
                -- RipSnapshot cleared by cat_rake_snapshot_capture /
                -- cat_rip_snapshot_capture) then 12 -> 11 (shaman/enhancement
                -- FireNovaReplacement cleared by
                -- enh_fire_nova_replacement_capture_tbc).
                { "never-firing " .. never .. " (expected 11)", never == 11 },
            }
        end,
    },
    -- WotLK-era battery (Phase 1): same harness, era = "wotlk" (41 specs incl.
    -- Death Knight blood/frost/unholy + leveling). Phase-1 triage (2026-08-09)
    -- COMPLETE: the 149-lane inventory was cleared to 0 never-firing via
    -- battery-fixture upgrades (resource/cooldown accessors, scenario banks,
    -- DK stub rewiring) — the era is now STRICT in the scorecard, so a future
    -- regression here hard-fails verify_all (and --check) until pinned.
    {
        label = "behavioral battery (wotlk)",
        cmd = "lua " .. R .. "/behavioral_audit.lua wotlk",
        check = function(c)
            local specs = num(c, "Total:%s*(%d+)%s*|")
            local load_fail = num(c, "Load failures:%s*(%d+)")
            local never = 0
            for _ in c:gmatch("NEVER:") do never = never + 1 end
            return {
                { "wotlk specs " .. tostring(specs) .. " (expected 41)", specs == 41 },
                { "load failures " .. tostring(load_fail) .. " (expected 0)", load_fail == 0 },
                { "never-firing " .. never .. " (expected 0)", never == 0 },
            }
        end,
    },
    -- Vanilla-era battery (2026-08-11, extended wave 1.4 2026-08-13): the era
    -- previously had ZERO behavioral coverage — run_all errored on
    -- non-sylvanas/wotlk eras, which is why fury_vanilla's never-fired Pummel
    -- shipped silently (it needed a dedicated test instead). Wiring:
    -- SPEC_FILES_VANILLA manifest (ALL 40 vanilla spec files since wave 1.4 —
    -- the 9 leveling_vanilla files joined the battery; they return
    -- { strategies, build_state } and require shared/leveling_sylvanas, whose
    -- require-time NS binding is refreshed per load_spec), CLI/run_all era
    -- acceptance, the plain-style loading shape (vanilla files return bare
    -- strategies + register get_state via NS.rotation_registry — the harness
    -- now captures it via the build_ns registry mock), is_vanilla + NS.setting
    -- stubs (subtlety_vanilla crashed on every matcher without setting — 6
    -- lanes cleared by the stub).
    -- Baseline (honest first run): 79 never-firing lanes, classified, future
    -- campaigns clear them per the (a)/(b)/(c) discipline. The fury Pummel
    -- interrupt (previous unit) FIRES in 11 scenarios incl. wotlk_interrupts.
    --
    -- Classification of the CURRENT 13 pins (wave 1.4 close-out, 2026-08-13;
    -- full per-lane evidence in docs/never_strategy_triage_vanilla_2026-08-13.md):
    --  * OOC/pre-pull/conjure/mounted (7): bear FaerieFirePull + PrePullEnrage
    --    (requires_not_in_combat pre-pull family — TBC pins the same lanes,
    --    and any OOC-bear-target scenario would fire the TBC siblings, so
    --    they cannot be modeled without breaking the era count contract),
    --    mage ManaGemConjure x2 + leveling ConjureManaGem (OOC conjure — the
    --    mock always has a gem available via is_item_ready; modeling "no gem"
    --    would clear the TBC (b) pins — TBC-pinned family), priest holy
    --    MountedProtection (mounted OOC — same era-shared constraint).
    --  * expected-absence / impossible-by-design (4): warlock RacialArcaneTorrent
    --    (Blood Elf racial, no blood elves in vanilla — affliction_vanilla:83
    --    pins ArcaneTorrent = nil), shaman elemental WrathOfAirTotem (TBC-only
    --    spell — elemental_vanilla:452 inert marker) + MagmaTotem
    --    (intentionally-inert by file design — elemental_vanilla:461-462
    --    'Magma Totem max rank is TBC-only in Classic'), priest holy
    --    EncounterReactions (era gate: NS.is_tbc() false in Classic — the
    --    lane is a Karazhan reaction and is_tbc() is the era discriminator).
    --  * module-local / state-machine-bound, PRE-2026-09-06 execute-capture:
    --    FireNovaReplacement (totem_state.fire_nova_active) +
    --    GraceOfAirTotemTwist (totem_state.next_air, flips only inside the
    --    twist executes, enhancement_vanilla:731/739) were unpinnable because
    --    the battery evaluated matches statelessly; the execute-capture
    --    scenarios (enh_fire_nova_replacement_capture_vanilla /
    --    enh_grace_air_twist_capture_vanilla) now run the real FireTotem /
    --    WindfuryTotemTwist executes and both lanes PROVEN → enhancement at
    --    0; the remaining (c) is priest leveling Fade (threat_pct >= 99
    --    "drawn aggro" gate — the battery's threat channel is capped at 95
    --    because the TBC Soulshatter lanes are pinned fires-ONLY-in-threat_high
    --    (test_threat_context_regression.lua), so any threat >= 99 scenario
    --    would break that exclusivity contract).
    --
    -- Wave 1.4 campaign (2026-08-13): 109 → 13 (content reclassified: 96
    --    leveling never-lanes surfaced by the coverage extension cleared, and
    --    AbolishDisease + Ambush cleared; Fade pinned as (c) above). Battery
    --    extension to all 40 specs closed as: spell-table seeds
    --    (DruidSpells/HunterSpells/MageSpells/PaladinSpells/PriestSpells/
    --    RogueSpells/ShamanSpells/WarlockSpells/WarriorSpells ladders mirror
    --    classes/<class>/class_sylvanas.lua), bank-aware spell_ready +
    --    is_behind_target import forwarding, the CCGateDB under-CC stub, the
    --    shared/leveling_sylvanas require-time NS-binding cleanup, and 8
    --    fixture scenarios (cat_lev_claw, ambush_opener, pal_lev_seal,
    --    priest_ve, lev_shock_earth, lev_shock_frost, pvp_cc_gate,
    --    ooc_afflicted). Also cleared: priest holy AbolishDisease
    --    + CureDisease (cure-pair split: friends_afflicted no longer puts
    --    CureDisease on cd; holy_cure_on_cd drives the pre-emptive branch)
    --    and rogue subtlety Ambush (opener_preference setting fixture).
    --    Regression-pinned by test_vanilla_sweep_regression.lua; TBC (16) and
    --    WotLK (0) never counts verified lane-for-lane unchanged; era-pair
    --    seed unchanged (no strategy names added — the leveling names were
    --    already in the files statically).
    {
        label = "behavioral battery (vanilla)",
        cmd = "lua " .. R .. "/behavioral_audit.lua vanilla",
        check = function(c)
            local specs = num(c, "Total:%s*(%d+)%s*|")
            local load_fail = num(c, "Load failures:%s*(%d+)")
            local never = 0
            for _ in c:gmatch("NEVER:") do never = never + 1 end
            return {
                { "vanilla specs " .. tostring(specs) .. " (expected 40)", specs == 40 },
                { "load failures " .. tostring(load_fail) .. " (expected 0)", load_fail == 0 },
                -- 2026-09-06 execute-capture campaign: 11 -> 9 (shaman/enhancement
                -- FireNovaReplacement + GraceOfAirTotemTwist cleared by
                -- enh_fire_nova_replacement_capture_vanilla /
                -- enh_grace_air_twist_capture_vanilla).
                { "never-firing " .. never .. " (expected 9 baseline, classified)", never == 9 },
            }
        end,
    },
    -- SoD-era battery (W4.3, 2026-08-14): the Season-of-Discovery era joined
    -- the behavioral battery (SPEC_FILES_SOD manifest — ALL 20 _sod.lua spec
    -- files; era-conditional callable ns.is_sod; the REAL
    -- shared/sod_context_sylvanas enrich runs against every scenario context
    -- so the battery exercises the production field producers, not hand-built
    -- mocks; the mock spell_action now emits the live `_meta` surface).
    -- Initial honest run: 37 never-firing lanes → 0 after the _meta
    -- fidelity fix + 14 SoD scenario shapes (meta/rockbiter/maelstrom/
    -- bear-form/poison/flame-shock/molten/tank-aoe/berserker/rage-low/
    -- pet-dismissed/pet-low/serpent/weakened-soul). The era is STRICT like
    -- wotlk: a future regression here hard-fails verify_all until pinned.
    {
        label = "behavioral battery (sod)",
        cmd = "lua " .. R .. "/behavioral_audit.lua sod",
        check = function(c)
            local specs = num(c, "Total:%s*(%d+)%s*|")
            local load_fail = num(c, "Load failures:%s*(%d+)")
            local never = 0
            for _ in c:gmatch("NEVER:") do never = never + 1 end
            return {
                { "sod specs " .. tostring(specs) .. " (expected 20)", specs == 20 },
                { "load failures " .. tostring(load_fail) .. " (expected 0)", load_fail == 0 },
                -- 2026-09-14: 0 -> 14 classified (SOD_LANE_CLASS, bucket c):
                -- the 14 per-class Interrupt lanes held under the battery.
                -- 2026-09-16 close-out: 14 -> 0 — the hold was the cast-window
                -- gate, not missing API stubs: the scenario target reported
                -- get_cast_pct = 60 (outside the manager's <50 default), so
                -- cast_has_interrupt_window failed in every scenario. Cleared
                -- with two honest fixtures (sod_interrupt_window /
                -- sod_interrupt_berserker): casting target at pct 20 with
                -- humanize off; the berserker variant adds stance = 3 for dps
                -- Pummel (manager required gate). Firing scope verified: each
                -- lane fires ONLY in those scenarios, Pummel only berserker,
                -- tank ShieldBash only non-berserker. Era is STRICT again.
                { "never-firing " .. never .. " (expected 0)", never == 0 },
            }
        end,
    },
    -- Forever-era battery (2026-09-14, pre-beta; WoW Forever beta 2026-09-17 /
    -- launch 2026-11-04): the forever era runs the SAME _vanilla spec files
    -- under the forever harness (class_loader resolves _forever -> _vanilla;
    -- ns.is_forever() true with the vanilla-superset is_vanilla() also true).
    -- Its never-inventory is therefore identical to vanilla's lane-for-lane
    -- (FOREVER_LANE_CLASS mirrors VANILLA_LANE_CLASS in spec_scorecard) until
    -- _forever delta files land. STRICT from day 1: a future never-lane
    -- hard-fails until pinned — new Forever lanes must be battery-observable
    -- (Pattern 17 doctrine, no SoD-style retrofit).
    {
        label = "behavioral battery (forever)",
        cmd = "lua " .. R .. "/behavioral_audit.lua forever",
        check = function(c)
            local specs = num(c, "Total:%s*(%d+)%s*|")
            local load_fail = num(c, "Load failures:%s*(%d+)")
            local never = 0
            for _ in c:gmatch("NEVER:") do never = never + 1 end
            return {
                { "forever specs " .. tostring(specs) .. " (expected 40)", specs == 40 },
                { "load failures " .. tostring(load_fail) .. " (expected 0)", load_fail == 0 },
                { "never-firing " .. never .. " (expected 9 baseline, classified)", never == 9 },
            }
        end,
    },
    -- Forever spell audit (live since the 2026-09-17 beta DBC landing,
    -- docs/forever/dbc_runbook.md): the real bridge enforces ID resolution
    -- across every _forever file. (The scanner self-probes moved to the
    -- dedicated "forever audit self-test" component below -- the live scan
    -- no longer prints that marker.)
    {
        label = "forever spell audit",
        cmd = "lua " .. R .. "/run_forever_audit_tests.lua",
        check = function(c)
            return {
                { "live mode active (no SCAFFOLD MODE marker)", c:find("SCAFFOLD MODE", 1, true) == nil },
                { "zero invalid ids", c:find("Invalid: 0", 1, true) ~= nil },
            }
        end,
    },
    {
        label = "forever audit self-test",
        cmd = "lua " .. R .. "/run_forever_audit_tests.lua --self-test",
        check = function(c)
            return { { "self-test [PASS] marker present (scanner fires on synthetic violations)",
                       c:find("[PASS]", 1, true) ~= nil } }
        end,
    },
    -- Clean-checkout dependency probe: scans every test/runner for file-read
    -- path literals and asserts each resolves to a tracked file or a
    -- self-provisioning artifact (.omo/evidence regenerated per run). A test
    -- reading a gitignored file (wowsims.db, .omo/evidence/*) passes on a dev
    -- box and silently fails on a clean checkout -- the 5-suite gap class.
    -- The probe prints [PASS] only when zero untracked targets are found.
    {
        label = "clean-checkout dep probe",
        cmd = "lua " .. R .. "/run_clean_checkout_probe.lua",
        check = function(c)
            return { { "no untracked test-read targets ([PASS] marker present)",
                       c:find("[PASS]", 1, true) ~= nil } }
        end,
    },
    -- Clean-checkout probe self-test: pins the directory-vs-file fix so a
    -- revert to the bare io.open existence probe (which false-flags directory
    -- fragments like "classes/" / "//" on POSIX) fails CI immediately.
    {
        label = "clean-checkout probe self-test",
        cmd = "lua " .. R .. "/run_clean_checkout_probe.lua --self-test",
        check = function(c)
            return { { "self-test [PASS] marker present (POSIX dir-vs-file guard)",
                       c:find("[PASS]", 1, true) ~= nil } }
        end,
    },
    -- Shipped-module enrollment probe: every .lua under shared/ and every .lua
    -- nested under classes/<class>/<subdir>/ (the depth behavioral_audit's
    -- one-level era scan cannot see) must be in the git INDEX, and the nested
    -- ones must additionally be required by a tracked file. The artifact is
    -- `git archive HEAD` filtered to tracked lua/md, so a forgotten `git add`
    -- drops the module from what users download while every local suite stays
    -- green; and no era manifest sees either scope, since they enumerate
    -- *_<era>.lua one level below classes/ only.
    {
        label = "module enrollment probe",
        cmd = "lua " .. R .. "/run_module_enrollment_probe.lua",
        check = function(c)
            return { { "no untracked/unenrolled shipped modules ([PASS] marker present)",
                       c:find("[PASS]", 1, true) ~= nil } }
        end,
    },
    {
        label = "module enrollment probe self-test",
        cmd = "lua " .. R .. "/run_module_enrollment_probe.lua --self-test",
        check = function(c)
            return { { "self-test [PASS] marker present (UNTRACKED / UNENROLLED fire)",
                       c:find("[PASS]", 1, true) ~= nil } }
        end,
    },
    -- Spec scorecard (Phase 0): runs the live battery, classifies every
    -- never-firing lane (a)/(b)/(c)/(d) against the pinned LANE_CLASS table,
    -- and drift-checks docs/scorecard.md. Fails on unclassified lanes, stale
    -- pins, dead lanes, or a stale doc — so the triage split is a live,
    -- CI-enforced number instead of stale doc paragraphs.
    {
        label = "spec scorecard",
        cmd = "lua tools/spec_scorecard.lua --check",
        check = function(c)
            return { { "in-sync marker present (never/(a)/(b)/(c)/(d) pins + doc current)",
                       c:find("in sync", 1, true) ~= nil } }
        end,
    },
    -- Perf cost gate (P3): enforces the no-per-frame-allocation rule under the
    -- capturing mock. Disabled/idle paths must amortize to zero retained
    -- growth (same forced-GC standard as the swing-diagnostics pin); enabled
    -- paths must stay within the named bounds defined inside the tool. The
    -- tick path gets the pin's 1.0 KB accounting-tolerance bound, so a real
    -- per-tick retained regression (any bounded-cache fill per frame) hard-fails.
    {
        label = "perf cost gate",
        cmd = "lua tools/perf_cost_gate.lua --check",
        check = function(c)
            return { { "[PASS] marker present (per-path retained deltas within named thresholds)",
                       c:find("[PASS]", 1, true) ~= nil },
                     { "no THRESHOLD FAIL markers",
                       c:find("THRESHOLD FAIL", 1, true) == nil } }
        end,
    },
}

print("verify_all: full verification matrix")
print("=" .. string.rep("=", 62))
local any_unexpected = false
for _, comp in ipairs(components) do
    io.write(string.format("  %-28s ... ", comp.label))
    io.flush()
    local content = capture(comp.cmd)
    if not content or #content == 0 then
        print("FAIL (runner produced no output — check that `lua` is on PATH)")
        any_unexpected = true
    else
        local asserts = comp.check(content)
        local ok = true
        for _, a in ipairs(asserts) do
            if not a[2] then ok = false end
        end
        if ok then
            print("PASS")
        else
            print("FAIL")
            any_unexpected = true
        end
        for _, a in ipairs(asserts) do
            print("    " .. (a[2] and "ok  " or "!!  ") .. a[1])
        end
        if not ok then
            -- show the failing runner's tail for quick diagnosis
            local lines = {}
            for line in content:gmatch("[^\r\n]+") do
                lines[#lines + 1] = line
            end
            local start = math.max(1, #lines - 6)
            for i = start, #lines do print("      | " .. lines[i]) end
        end
    end
end
print("=" .. string.rep("=", 62))
if any_unexpected then
    print("verify_all: UNEXPECTED FAILURES DETECTED (exit 1)")
    os.exit(1)
end
print("verify_all: all checks green (exit 0)")
os.exit(0)
