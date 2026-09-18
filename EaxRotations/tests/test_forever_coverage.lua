-- test_forever_coverage.lua — Every vanilla rotation file has a Forever path decision.
-- WHAT:  Pins the campaign's coverage contract: for every one of the 40
--        tracked *_vanilla.lua rotation files, either a _forever delta
--        exists or the spec sits on the explicit fallback allowlist (kits
--        that changed nothing mechanically). Also fails on a stale
--        allowlist entry (a fallback spec that gained a delta).
-- WHEN:  run as a standalone test or via run_rotation_tests.lua (rotation
--        suite registry).
-- WHY:   The Forever day-1 campaign's DONE criterion is "all 29 specs have a
--        _forever rotation path" — the loader's _forever -> _vanilla
--        fallback makes that true today (test_class_loader_forever_fallback
--        pins the mechanics), and this manifest pins the per-spec DECISION
--        so a fallback can never be silent. NOTE: test files may not use
--        io.popen (layout-compliance gate), so the spec set is an explicit
--        manifest here; a NEW vanilla file needs a manifest entry, which is
--        the deliberate step this pin exists to force.
-- SAFETY: read-only io.open existence probes only; fully self-contained.

local function fail(msg)
    io.stderr:write("forever coverage: " .. msg .. "\n")
    os.exit(1)
end

local function exists(path)
    local f = io.open(path, "rb")
    if not f then return false end
    f:close()
    return true
end

-- The 40 vanilla rotation files (class dir / spec base) and their Forever
-- decision: true = a _forever delta is required, false = deliberate
-- fallback (the loader resolves _vanilla, which stays correct-until-
-- proven-otherwise). The fallback set: paladin retribution,
-- druid caster, warrior kebab. (shaman restoration joined the delta set
-- 2026-09-18: the Riptide capstone loop + Water Shield rework; paladin
-- protection joined 2026-09-18: the Seal of Fury tank seal + Judgement
-- taunt pair — the first prot taunt.)
local SPECS = {
    ["druid/balance"] = true,
    ["druid/bear"] = true,
    ["druid/caster"] = false,
    ["druid/cat"] = true,
    ["druid/leveling"] = true,
    ["druid/resto"] = true,
    ["hunter/beast_mastery"] = true,
    ["hunter/leveling"] = true,
    ["hunter/marksmanship"] = true,
    ["hunter/survival"] = true,
    ["mage/arcane"] = true,
    ["mage/fire"] = true,
    ["mage/frost"] = true,
    ["mage/leveling"] = true,
    ["paladin/holy"] = true,
    ["paladin/leveling"] = true,
    ["paladin/protection"] = true,
    ["paladin/retribution"] = false,
    ["priest/discipline"] = true,
    ["priest/holy"] = true,
    ["priest/leveling"] = true,
    ["priest/shadow"] = true,
    ["priest/smite"] = true,
    ["rogue/assassination"] = true,
    ["rogue/combat"] = true,
    ["rogue/leveling"] = true,
    ["rogue/subtlety"] = true,
    ["shaman/elemental"] = true,
    ["shaman/enhancement"] = true,
    ["shaman/leveling"] = true,
    ["shaman/restoration"] = true,
    ["warlock/affliction"] = true,
    ["warlock/demonology"] = true,
    ["warlock/destruction"] = true,
    ["warlock/leveling"] = true,
    ["warrior/arms"] = true,
    ["warrior/fury"] = true,
    ["warrior/kebab"] = false,
    ["warrior/leveling"] = true,
    ["warrior/protection"] = true,
}

local problems, deltas, fallbacks, total = {}, 0, 0, 0
for spec, needs_delta in pairs(SPECS) do
    total = total + 1
    local vanilla = "EaxRotations/classes/" .. spec .. "_vanilla.lua"
    local forever = "EaxRotations/classes/" .. spec .. "_forever.lua"
    local has_vanilla = exists(vanilla)
    local has_delta = exists(forever)
    if not has_vanilla then
        problems[#problems + 1] = spec .. ": _vanilla file missing"
    end
    if needs_delta and not has_delta then
        problems[#problems + 1] = spec .. ": declared a delta but _forever file is missing"
    end
    if not needs_delta and has_delta then
        problems[#problems + 1] = spec .. ": declared a fallback but a _forever delta exists (stale entry)"
    end
    if needs_delta then deltas = deltas + 1 else fallbacks = fallbacks + 1 end
end

if total ~= 40 then
    problems[#problems + 1] = string.format("manifest carries %d specs, expected 40", total)
end
if #problems > 0 then
    for _, p in ipairs(problems) do io.stderr:write("  !! " .. p .. "\n") end
    fail(#problems .. " coverage problem(s)")
end

print(string.format(
    "forever coverage: %d vanilla specs -> %d _forever deltas + %d deliberate fallbacks [PASS]",
    total, deltas, fallbacks))
print("PASS forever_coverage")
