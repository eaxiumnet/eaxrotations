-- verify_all.lua -- full verification matrix in one shot.
-- WHAT:  runs rotation + leveling + WotLK tests, the 4 spell-ID audits
--        (sylvanas/vanilla-contamination/vanilla-existence/wotlk), the three
--        audits' --self-test pinned-rank enforcement modes (vanilla TBC_IDS,
--        sylvanas WOTLK_ONLY_IDS, wotlk allowlist + rank-top), the
--        behavioral battery, and the clean-checkout dependency probe
--        (run_clean_checkout_probe.lua -- flags any test file-read target
--        that resolves to a gitignored file instead of a tracked or
--        self-provisioning path, so the 5-suite env-gap class can never
--        silently return); parses each runner's own totals instead of
--        trusting exit codes (the rotation runner exits 0 even when suites
--        fail).
-- WHEN:  invoked via lua EaxRotations/tests/verify_all.lua (or CI).
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
--         dead-lane fix) cleared 18 more 78->60 (RakeSnapshot/RipSnapshot /
--         FireNovaReplacement remain (c)-pinned unpinnable: module-local
--         snapshot/totem state the battery cannot drive). When a lane is
--         cleared or a scenario is added, update these expectations here,
--         otherwise verify_all will (correctly) fail until they are bumped.

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
                { "never-firing " .. never .. " (expected 60)", never == 60 },
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
