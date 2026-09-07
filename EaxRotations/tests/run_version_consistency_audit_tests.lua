-- run_version_consistency_audit_tests.lua -- Static audit: every surface that
-- pins the release version must agree. The runtime plugin version in
-- header.lua, the top release entry in CHANGELOG.md, the version badge in
-- README.md, and the footer in docs/PVP_FEATURE_PAGE.md must all read the
-- SAME "X.Y.Z".
-- WHAT:  Reads all four pinned locations and fails on any mismatch:
--          EaxRotations/header.lua          plugin["version"] = "X.Y.Z"
--          EaxRotations/CHANGELOG.md        first "## X.Y.Z — date" heading
--          EaxRotations/README.md           shields.io "version-X.Y.Z" badge
--          EaxRotations/docs/PVP_FEATURE_PAGE.md  footer "EaxRotations vX.Y.Z"
--        The 2.21.0/2.22.0 release convention bumped the README badge and the
--        PvP footer but never header.lua, so every reload logged v2.18.1 while
--        the shipped release was 2.22.0. Header-vs-changelog alone cannot stop
--        that class (a release can bump the runtime + changelog while the
--        badge and footer silently lag), so the badge and footer are pinned
--        here too — this audit closes the drift mechanism end to end.
-- WHEN:  Run manually, in CI (verify_all), and in the pre-commit gate.
-- WHY:   The runtime-reported version is a user-visible claim; a stale header,
--        badge, or footer silently contradicts the changelog and any release
--        tooling that reads plugin.version. The badge/scorecard drift gates
--        cannot catch it (they own test counts and battery lanes, not this
--        metadata).
-- SAFETY: Read-only text scan; --self-test uses synthetic in-memory fixtures
--        (no filesystem writes).

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;" .. package.path

local HEADER_PATH = "EaxRotations/header.lua"
local CHANGELOG_PATH = "EaxRotations/CHANGELOG.md"
local README_PATH = "EaxRotations/README.md"
local PVP_PATH = "EaxRotations/docs/PVP_FEATURE_PAGE.md"

-- ---------------------------------------------------------------------------
-- Core extraction: content -> version string or nil
-- ---------------------------------------------------------------------------
-- header.lua line:  plugin["version"] = "2.22.0"
local function header_version(content)
    if type(content) ~= "string" then return nil end
    return content:match('plugin%s*%[[\"\']version[\"\']%s*%]%s*=%s*"([%d%.]+)"')
end

-- CHANGELOG.md top entry:  ## 2.22.0 — 2026-08-10  (first "## X.Y.Z" heading)
local function changelog_top_version(content)
    if type(content) ~= "string" then return nil end
    for line in (content .. "\n"):gmatch("(.-)\n") do
        local v = line:match("^##%s+([%d%.]+)")
        if v then return v end
    end
    return nil
end

-- README.md badge:  .../shields.io/badge/version-2.22.0-blue ...
local function readme_badge_version(content)
    if type(content) ~= "string" then return nil end
    return content:match('badge/version%-([%d%.]+)%-')
end

-- PvP footer:  EaxRotations v2.22.0 — CC-BY-4.0 License — Built for TBC ...
local function pvp_footer_version(content)
    if type(content) ~= "string" then return nil end
    return content:match("EaxRotations v([%d%.]+)")
end

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

-- All four pins agree? Returns nil when consistent, else a short reason string.
local function four_pin_mismatch(hver, cver, rver, pver)
    local function disagree(name, val)
        if val == nil then return name .. " has no parseable version" end
        if val ~= hver then return name .. " reads " .. val .. " (header reads " .. tostring(hver) .. ")" end
        return nil
    end
    if hver == nil then return "header.lua has no parseable plugin version" end
    return disagree("CHANGELOG.md top release", cver)
        or disagree("README.md version badge", rver)
        or disagree("PvP footer", pver)
end

-- ---------------------------------------------------------------------------
-- Self-tests (non-vacuity): extraction + mismatch detection on synthetic text.
-- ---------------------------------------------------------------------------
local function run_self_tests()
    local function expect(actual, expected, label)
        if actual ~= expected then
            error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
        end
    end

    -- Extraction: header line forms.
    expect(header_version('plugin["version"] = "2.22.0"'), "2.22.0", "header double-quote form")
    expect(header_version("plugin['version'] = \"2.18.1\""), "2.18.1", "header single-quote key form")
    expect(header_version('plugin["version"] = "2.22.0"  -- comment'), "2.22.0", "header trailing comment")
    expect(header_version("no version here"), nil, "header without version")
    expect(header_version(nil), nil, "header nil content")

    -- Extraction: changelog top entry (first ## heading wins; # title skipped).
    local changelog = "# Changelog\n\n## 2.22.0 — 2026-08-10\n\n### Customer Changelog\n...\n## 2.21.0 — 2026-08-10\n"
    expect(changelog_top_version(changelog), "2.22.0", "changelog top entry")
    expect(changelog_top_version("no headings"), nil, "changelog without headings")
    expect(changelog_top_version(nil), nil, "changelog nil content")

    -- Extraction: README version badge (the URL form only — not other badges).
    expect(readme_badge_version('<img src="https://img.shields.io/badge/version-2.22.0-blue" alt="Version 2.22.0">'),
           "2.22.0", "readme version badge")
    expect(readme_badge_version('<img src="https://img.shields.io/badge/tests-563%2F563-blue" alt="563/563">'),
           nil, "readme non-version badge is ignored")
    expect(readme_badge_version("no badge"), nil, "readme without version badge")

    -- Extraction: PvP footer.
    expect(pvp_footer_version("EaxRotations v2.22.0 — CC-BY-4.0 License — Built for TBC Classic Anniversary"),
           "2.22.0", "pvp footer version")
    expect(pvp_footer_version("no footer"), nil, "pvp without footer")

    -- Mismatch detection is the audit's core contract: one drifted pin -> fail.
    expect(four_pin_mismatch("2.18.1", "2.22.0", "2.22.0", "2.22.0") ~= nil, true,
           "header 2.18.1 vs changelog 2.22.0 is a mismatch")
    expect(four_pin_mismatch("2.22.0", "2.22.0", "2.24.0", "2.22.0") ~= nil, true,
           "README badge 2.24.0 behind header 2.22.0 is a mismatch")
    expect(four_pin_mismatch("2.22.0", "2.22.0", "2.22.0", "2.18.1") ~= nil, true,
           "PvP footer 2.18.1 behind header 2.22.0 is a mismatch")
    expect(four_pin_mismatch("2.22.0", nil, "2.22.0", "2.22.0") ~= nil, true,
           "missing changelog top is a mismatch")
    expect(four_pin_mismatch(nil, "2.22.0", "2.22.0", "2.22.0") ~= nil, true,
           "missing header version is a mismatch")

    -- Match: same version on all four pins -> no failure.
    expect(four_pin_mismatch("2.22.0", "2.22.0", "2.22.0", "2.22.0"), nil,
           "matching versions are consistent")

    print("[PASS] Version-consistency audit self-tests: four-pin extraction "
        .. "(header/changelog/readme/pvp), first-##-heading rule, badge + footer "
        .. "extraction, drift + match detection")
    os.exit(0)
end

-- ---------------------------------------------------------------------------
-- CLI
-- ---------------------------------------------------------------------------
if arg and arg[1] == "--self-test" then
    run_self_tests()
end

local header = read_file(HEADER_PATH)
local changelog = read_file(CHANGELOG_PATH)
local readme = read_file(README_PATH)
local pvp = read_file(PVP_PATH)

print("=============================================================================")
print("  VERSION-CONSISTENCY AUDIT (header.lua / CHANGELOG top / README badge / PvP footer)")
print("=============================================================================")

local missing = {}
if not header then missing[#missing + 1] = HEADER_PATH end
if not changelog then missing[#missing + 1] = CHANGELOG_PATH end
if not readme then missing[#missing + 1] = README_PATH end
if not pvp then missing[#missing + 1] = PVP_PATH end

if #missing > 0 then
    for _, path in ipairs(missing) do print("  MISSING " .. path) end
    print("  Fix: all four files must be present for a release.")
    os.exit(1)
end

local hver = header_version(header)
local cver = changelog_top_version(changelog)
local rver = readme_badge_version(readme)
local pver = pvp_footer_version(pvp)

print(string.format("  header.lua    plugin version: %s", tostring(hver)))
print(string.format("  CHANGELOG.md  top release:    %s", tostring(cver)))
print(string.format("  README.md     version badge:  %s", tostring(rver)))
print(string.format("  PvP footer    version:        %s", tostring(pver)))

local mismatch = four_pin_mismatch(hver, cver, rver, pver)
if mismatch then
    print("")
    print("  MISMATCH: " .. mismatch .. ".")
    print("  Fix: bump every pinned surface to the same version — header.lua")
    print("  plugin[\"version\"] (main.lua logs 'v' .. plugin.version on every")
    print("  reload), the CHANGELOG top '## X.Y.Z' heading, the README")
    print("  shields.io version badge, and the PvP footer 'EaxRotations vX.Y.Z'.")
    os.exit(1)
end

print("")
print("  All four pinned surfaces agree — header.lua plugin version matches the top changelog release.")
os.exit(0)
