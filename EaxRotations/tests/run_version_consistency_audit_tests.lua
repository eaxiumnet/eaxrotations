-- run_version_consistency_audit_tests.lua -- Static audit: the runtime plugin
-- version in header.lua must equal the top release entry in CHANGELOG.md.
-- WHAT:  Reads EaxRotations/header.lua (plugin["version"] = "X.Y.Z" — consumed
--        live by main.lua:1400's startup log) and EaxRotations/CHANGELOG.md
--        (first "## X.Y.Z — date" heading) and fails on any mismatch. The
--        2.21.0/2.22.0 release convention bumped the README badge and the PvP
--        footer but never header.lua, so every reload logged v2.18.1 while the
--        shipped release was 2.22.0 — this audit closes that gap.
-- WHEN:  Run manually, in CI (verify_all), and in the pre-commit gate.
-- WHY:   The runtime-reported version is a user-visible claim; a stale header
--        version silently contradicts the changelog and any release tooling
--        that reads plugin.version. The badge/scorecard drift gates cannot
--        catch it (they own test counts and battery lanes, not this metadata).
-- SAFETY: Read-only text scan; --self-test uses synthetic in-memory fixtures
--        (no filesystem writes).

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;" .. package.path

local HEADER_PATH = "EaxRotations/header.lua"
local CHANGELOG_PATH = "EaxRotations/CHANGELOG.md"

-- ---------------------------------------------------------------------------
-- Core extraction: content -> version string or nil
-- ---------------------------------------------------------------------------
-- header.lua line:  plugin["version"] = "2.22.0"
local function header_version(content)
    if type(content) ~= "string" then return nil end
    return content:match('plugin%s*%[["\']version["\']%s*%]%s*=%s*"([%d%.]+)"')
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

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
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

    -- Mismatch detection is the audit's core contract: differ -> must fail.
    local hv, cv = header_version('plugin["version"] = "2.18.1"'),
                    changelog_top_version("# C\n\n## 2.22.0 — 2026-08-10\n")
    expect(hv ~= cv, true, "header 2.18.1 vs changelog 2.22.0 is a mismatch")

    -- Match: same version -> no failure.
    local hv2, cv2 = header_version('plugin["version"] = "2.22.0"'),
                     changelog_top_version("## 2.22.0 — 2026-08-10\n")
    expect(hv2 == cv2, true, "matching versions are consistent")

    print("[PASS] Version-consistency audit self-tests: header/changelog "
        .. "extraction, first-##-heading rule, mismatch + match detection")
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

print("=============================================================================")
print("  VERSION-CONSISTENCY AUDIT (header.lua plugin version vs CHANGELOG top)")
print("=============================================================================")

if not header or not changelog then
    if not header then print("  MISSING " .. HEADER_PATH) end
    if not changelog then print("  MISSING " .. CHANGELOG_PATH) end
    print("  Fix: both files must be present for a release.")
    os.exit(1)
end

local hver = header_version(header)
local cver = changelog_top_version(changelog)

print(string.format("  header.lua   plugin version: %s", tostring(hver)))
print(string.format("  CHANGELOG.md top release:   %s", tostring(cver)))

if not hver or not cver then
    if not hver then print("  header.lua has no parseable plugin[\"version\"]") end
    if not cver then print("  CHANGELOG.md has no top '## X.Y.Z' entry") end
    os.exit(1)
end

if hver ~= cver then
    print("")
    print("  MISMATCH: the runtime-reported version differs from the top changelog release.")
    print("  Fix: bump header.lua plugin[\"version\"] to " .. cver .. " (the release convention")
    print("  must touch header.lua — main.lua:1400 logs 'v' .. plugin.version on every reload).")
    os.exit(1)
end

print("")
print("  Runtime plugin version matches the top changelog release.")
os.exit(0)
