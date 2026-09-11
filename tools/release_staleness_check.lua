-- tools/release_staleness_check.lua -- Release-staleness guard.
--
-- WHAT:  Compares the version this checkout SHIPS (EaxRotations/header.lua
--        plugin["version"], the same pin the version-consistency audit reads)
--        against the newest version PUBLISHED to the GitHub repo (a remote
--        vX.Y.Z tag, cross-checked against the Releases page when `gh` is
--        available). Reports one of three verdicts:
--
--          UP-TO-DATE  shipped == newest published   -> nothing to do
--          STALE       shipped  > newest published   -> the download users get
--                                                      is behind the code
--          DRIFT       shipped  < newest published   -> a published release is
--                                                      newer than header.lua
--
--        STALE is the failure class this guard exists for. The publish
--        workflow (.github/workflows/release-publish.yml) is deliberately
--        manual, so a `release: vX.Y.Z` commit can land on master, CI can stay
--        green, and no tag or Release is ever created -- exactly the
--        2.18.0->2.22.0 stall and again the 2.24.2->2.25.0 stall, where users
--        spent a month downloading a zip without the fixes already on master.
--
-- WHEN:  CI on master pushes (`--strict`, fails the build so it cannot be
--        missed), the pre-commit gate (warn-only, so release-prep commits are
--        not blocked), and manually when cutting a release.
--
-- WHY:   The version-consistency audit proves the four in-repo pins agree with
--        each other; none of them know whether the result was ever PUBLISHED.
--        Only the remote can answer that, which is why this is a separate,
--        network-aware check rather than another static-text pin.
--
-- SAFETY: Read-only. Shells out to `git ls-remote` (and `gh` when present) and
--        reads header.lua. Never writes, tags, or publishes anything. Network
--        failure is reported as UNAVAILABLE and exits 0 -- a flaky remote must
--        never red a build for an unrelated reason.
--
-- USAGE:
--   lua tools/release_staleness_check.lua                  # warn-only
--   lua tools/release_staleness_check.lua --strict         # exit 1 when STALE
--   lua tools/release_staleness_check.lua --self-test      # synthetic fixtures
--   lua tools/release_staleness_check.lua --offline        # local tags only
--   lua tools/release_staleness_check.lua --tags=2.24.2,2.25.0   # inject (tests)

local HERE = (arg and arg[0] or ""):gsub("\\", "/")
-- Derive the repo root from the script path (tools/ lives at the root), so the
-- check works from any cwd. A bare relative invocation (arg[0] = "tools/x.lua")
-- yields an empty prefix, which means the cwd -- normalize that to ".".
local ROOT = HERE:match("^(.*)/tools/[^/]+$")
if not ROOT or ROOT == "" then ROOT = "." end

local HEADER_PATH = ROOT .. "/EaxRotations/header.lua"
local REMOTE = "origin"

-- ---------------------------------------------------------------------------
-- Core logic (pure functions -- driven by --self-test without touching disk)
-- ---------------------------------------------------------------------------

-- header.lua line:  plugin["version"] = "2.25.0"
local function header_version(content)
    if type(content) ~= "string" then return nil end
    return content:match('plugin%s*%[["\']version["\']%s*%]%s*=%s*"([%d%.]+)"')
end

-- "2.25.0" -> {2,25,0}; nil unless the whole string is dotted digits.
local function parse_version(v)
    if type(v) ~= "string" then return nil end
    v = v:match("^%s*(.-)%s*$")
    if v == "" or v:find("[^%d%.]") or v:find("%.%.") or v:match("^%.") or v:match("%.$") then
        return nil
    end
    local parts = {}
    for p in v:gmatch("[^.]+") do parts[#parts + 1] = tonumber(p) end
    if #parts < 2 then return nil end
    return parts
end

-- -1 / 0 / 1, padding missing components with zero (2.25 == 2.25.0).
local function compare_versions(a, b)
    local pa, pb = parse_version(a), parse_version(b)
    if not pa or not pb then return nil end
    local n = math.max(#pa, #pb)
    for i = 1, n do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then return x < y and -1 or 1 end
    end
    return 0
end

-- Newest version in a list of ref lines ("<sha>\trefs/tags/vX.Y.Z", possibly
-- with a "^{}" peeled duplicate) or bare tag names. Non-semver tags --
-- including this repo's date-stamped v2026-06-26.<sha> history -- are ignored.
local function newest_published(refs)
    if type(refs) ~= "table" then return nil end
    local best = nil
    for _, line in ipairs(refs) do
        local name = tostring(line):match("refs/tags/(v[%w%.%-%+]+)") or tostring(line)
        name = name:gsub("%^{}$", "")
        local v = name:match("^v?([%d]+%.[%d]+%.[%d]+)$")
        if v then
            if not best or (compare_versions(v, best) or 0) > 0 then best = v end
        end
    end
    return best
end

-- shipped vs published -> verdict tag + human explanation.
local function verdict(shipped, published)
    if not shipped then
        return "UNKNOWN", "EaxRotations/header.lua has no parseable plugin version"
    end
    if not published then
        return "UNPUBLISHED", "no vX.Y.Z tag found on the remote -- nothing has shipped yet"
    end
    local cmp = compare_versions(shipped, published)
    if cmp == 0 then
        return "UP-TO-DATE", "shipped version matches the newest published release"
    elseif cmp > 0 then
        return "STALE", "shipped " .. shipped .. " is newer than the newest published "
            .. published .. " -- users are downloading older code"
    end
    return "DRIFT", "published " .. published .. " is newer than shipped "
        .. shipped .. " -- header.lua is behind a release"
end

-- ---------------------------------------------------------------------------
-- Shell helpers
-- ---------------------------------------------------------------------------

-- io.popen shells out to cmd.exe on Windows and /bin/sh elsewhere, so the
-- stderr redirect has to match the platform. Suppressing stderr keeps the gate
-- output clean when `git`/`gh` are missing or the remote is unreachable.
local IS_WINDOWS = package.config:sub(1, 1) == "\\"
local NULL_SINK = IS_WINDOWS and "2>nul" or "2>/dev/null"

local function capture(cmd)
    local pipe = io.popen(cmd .. " " .. NULL_SINK)
    if not pipe then return nil end
    local out = pipe:read("*a")
    pipe:close()
    if out == nil or out == "" then return nil end
    return out
end

-- Quote a path only when it needs it: cmd.exe has no single-quote semantics,
-- and the repo path normally has no spaces.
local function q(path)
    if path:find("%s") then return '"' .. path .. '"' end
    return path
end

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local function split_lines(text)
    local out = {}
    for line in (text or ""):gmatch("[^\r\n]+") do out[#out + 1] = line end
    return out
end

local function published_tag_versions(remote, offline)
    -- NOTE: double quotes, not single -- io.popen runs through cmd.exe on
    -- Windows where single quotes are literal, which would pass a quoted
    -- refspec to git and silently return nothing. No pattern is supplied at
    -- all; newest_published() filters to semver vX.Y.Z in Lua, so the
    -- shell never does the globbing (same fix for the tag -l fallback).
    if offline then
        local out = capture("git -C " .. q(ROOT) .. ' tag -l "v*"')
        return newest_published(split_lines(out)), "local tags (--offline)", true
    end
    local out = capture("git -C " .. q(ROOT) .. " ls-remote --tags " .. remote)
    if not out then
        -- Remote unreachable: fall back to local tags but mark the verdict
        -- unverified, so a flaky network is never reported as "nothing shipped".
        local local_out = capture("git -C " .. q(ROOT) .. ' tag -l "v*"')
        return newest_published(split_lines(local_out)), "local tags only (remote unreachable)", false
    end
    return newest_published(split_lines(out)), "remote " .. remote, true
end

-- Releases page cross-check: a version can be tagged while its Release (the
-- actual zip users download) failed to publish. Best-effort -- `gh` may be
-- absent or unauthenticated, in which case this is skipped, never failed.
local function published_release_versions()
    local out = capture('gh release list --repo eaxiumnet/eaxrotations --limit 50 --json tagName --jq ".[].tagName"')
    if not out then return nil end
    local versions = {}
    for _, line in ipairs(split_lines(out)) do
        local v = line:match("^v([%d]+%.[%d]+%.[%d]+)$")
        if v then versions[#versions + 1] = v end
    end
    if #versions == 0 then return nil end
    return versions
end

-- ---------------------------------------------------------------------------
-- Self-tests (non-vacuity: extraction, comparison, verdict, tag filtering)
-- ---------------------------------------------------------------------------
local function run_self_tests()
    local function expect(actual, want, label)
        if actual ~= want then
            error(label .. ": expected " .. tostring(want) .. ", got " .. tostring(actual))
        end
    end

    -- Version parsing + comparison, including zero-padding and boundaries.
    expect(compare_versions("2.25.0", "2.25.0"), 0, "equal versions")
    expect(compare_versions("2.25", "2.25.0"), 0, "missing patch pads with zero")
    expect(compare_versions("2.24.2", "2.25.0"), -1, "minor bump is newer")
    expect(compare_versions("2.25.0", "2.24.9"), 1, "higher minor wins over patch")
    expect(compare_versions("2.9.0", "2.10.0"), -1, "numeric (not lexical) minor compare")
    expect(compare_versions("10.0.0", "9.9.9"), 1, "numeric major compare")
    expect(compare_versions("2.25.0.1", "2.25.0"), 1, "extra component counts")
    expect(compare_versions("bogus", "2.25.0"), nil, "unparseable version -> nil")
    expect(compare_versions(nil, "2.25.0"), nil, "nil version -> nil")
    expect(parse_version("2.25."), nil, "trailing dot rejected")
    expect(parse_version("2..0"), nil, "double dot rejected")

    -- header extraction.
    expect(header_version('plugin["version"] = "2.25.0"'), "2.25.0", "header double-quote")
    expect(header_version("plugin['version'] = \"2.18.1\""), "2.18.1", "header single-quote key")
    expect(header_version("plugin[\"version\"] = \"2.25.0\"  -- note"), "2.25.0", "header trailing comment")
    expect(header_version("nothing"), nil, "header without version")
    expect(header_version(nil), nil, "header nil content")

    -- Newest-published extraction: semver tags win, peeled dupes and the
    -- date-stamped historical tags are ignored.
    local refs = {
        "aaa\trefs/tags/v2.24.1",
        "bbb\trefs/tags/v2.24.2",
        "bbb\trefs/tags/v2.24.2^{}",
        "ccc\trefs/tags/v2.9.0",
        "ddd\trefs/tags/v2.10.0",
        "eee\trefs/tags/v2026-06-28.f802211b",
        "fff\trefs/tags/v2026.06.25-f6d93cb9",
    }
    expect(newest_published(refs), "2.24.2", "date tags ignored, semver tags win")
    expect(newest_published({ "x\trefs/tags/v2.25.0", "y\trefs/tags/v2.24.2" }), "2.25.0", "later tag wins")
    expect(newest_published({ "v2.25.0", "v2.4.0" }), "2.25.0", "bare tag names accepted")
    expect(newest_published({ "2.25.0", "2.24.2" }), "2.25.0", "v-less release tags accepted")
    expect(newest_published({ "x\trefs/tags/v2026-06-28.f802211b" }), nil, "only date tags -> nil")
    expect(newest_published({}), nil, "no tags -> nil")
    expect(newest_published(nil), nil, "nil refs -> nil")

    -- Verdicts, both sides of every branch (the guard's whole contract).
    expect((verdict("2.24.2", "2.25.0")), "DRIFT", "shipped behind published")
    expect((verdict("2.25.0", "2.25.0")), "UP-TO-DATE", "shipped == published")
    expect((verdict("2.25.0", "2.24.2")), "STALE", "shipped ahead of published -> the stall")
    expect((verdict("2.26.0", nil)), "UNPUBLISHED", "nothing published yet")
    expect((verdict(nil, "2.25.0")), "UNKNOWN", "unparseable header")
    expect((verdict("2.24.2", nil)), "UNPUBLISHED", "shipped but never published")

    print("[PASS] Release-staleness guard self-tests: header extraction, semantic "
        .. "version compare (padding/rollover), date-tag filtering, and all five "
        .. "verdicts on both sides")
    os.exit(0)
end

-- ---------------------------------------------------------------------------
-- CLI
-- ---------------------------------------------------------------------------
local strict = false
local offline = false
local injected = nil
for _, a in ipairs(arg or {}) do
    if a == "--strict" then strict = true
    elseif a == "--offline" then offline = true
    elseif a == "--self-test" then run_self_tests()
    elseif a:match("^%-%-tags=") then injected = a:match("^%-%-tags=(.*)$")
    end
end

local header = read_file(HEADER_PATH)
if not header then
    print("[FAIL] release-staleness: cannot read " .. HEADER_PATH)
    os.exit(1)
end

local shipped = header_version(header)

local published, source, reachable
if injected then
    local refs = {}
    for v in injected:gmatch("[^,]+") do refs[#refs + 1] = "v" .. v:gsub("^v", "") end
    published, source, reachable = newest_published(refs), "injected --tags", true
else
    published, source, reachable = published_tag_versions(REMOTE, offline)
end

local code, reason = verdict(shipped, published)
-- An unreachable remote proves nothing: a local tag list is routinely stale
-- (tags created by the publish workflow are not auto-fetched), so a local-only
-- STALE would be a false alarm. Downgrade to an informational UNVERIFIED and
-- never fail the build on it. `--offline` is the explicit opt-in to local tags.
if not reachable then code = "UNVERIFIED" end

print("=============================================================================")
print("  RELEASE-STALENESS CHECK (shipped header.lua vs newest published release)")
print("=============================================================================")
print("  shipped version:  " .. tostring(shipped) .. "   (EaxRotations/header.lua)")
print("  newest published: " .. tostring(published) .. "   (" .. tostring(source) .. ")")

-- Cross-check the Releases page (the artifact users actually download). A tag
-- with no Release means the publish workflow's tag step ran but its release
-- step did not -- reported, not failed.
if code ~= "UNKNOWN" then
    local releases = published_release_versions()
    if releases then
        local newest_release = newest_published(releases)
        print("  newest Release:   " .. tostring(newest_release) .. "   (GitHub Releases page)")
        if published and newest_release and compare_versions(published, newest_release) > 0 then
            print("  [WARN] tag v" .. published .. " has no matching GitHub Release -- the zip is not downloadable.")
        end
    else
        print("  newest Release:   (gh unavailable -- tag check only)")
    end
end

print("")

if code == "STALE" then
    print("  [STALE] " .. reason .. ".")
    print("")
    print("  This is the release stall: a `release: v" .. tostring(shipped)
        .. "` commit is on master but")
    print("  no v" .. tostring(shipped) .. " tag/Release was published, so the download is behind the code.")
    print("  Publish it (one command, deliberately manual by design):")
    print("")
    print("    gh workflow run release-publish.yml -f version=" .. tostring(shipped))
    print("")
    print("  Then re-run this check -- it goes green once the tag exists.")
    os.exit(strict and 1 or 0)
elseif code == "DRIFT" then
    print("  [DRIFT] " .. reason .. ".")
    print("  Fix: bump header.lua (and the other three pins) to the published version,")
    print("  or publish the newer version if the release was the mistake.")
    os.exit(0)
elseif code == "UP-TO-DATE" then
    print("  [PASS] " .. reason .. ".")
    os.exit(0)
elseif code == "UNPUBLISHED" then
    print("  [WARN] " .. reason .. ".")
    print("  (Publishing a first release clears this; nothing is stale by comparison yet.)")
    os.exit(0)
elseif code == "UNVERIFIED" then
    print("  [WARN] could not reach the remote; cannot verify whether v"
        .. tostring(shipped) .. " has been published.")
    if published then
        print("  Local tags suggest: " .. reason .. " (unverified -- not a failure).")
    end
    print("  Re-run with network access (CI does this on master pushes) to gate.")
    os.exit(0)
end

print("  [FAIL] " .. reason .. ".")
os.exit(1)
