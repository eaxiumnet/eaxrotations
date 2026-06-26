-- compute_scorecard.lua — Auto-compute rotation quality scores per spec × content type.
-- WHAT:  reads spec files, counts strategies/tests/features, assigns 0-5 scores.
-- WHEN:  run manually after spec changes or in CI.
-- WHY:   gives contributors and users a clear picture of rotation maturity.
-- SAFETY: read-only file scanning; no API calls, no network.
-- USAGE: cd repo_root && lua build_tools/compute_scorecard.lua

local json = require("json")  -- optional; falls back to simple serialization

local SPECS = {
  -- Warrior
  { class = "warrior", spec = "arms",         exp = "tbc",    file = "classes/warrior/arms_sylvanas.lua" },
  { class = "warrior", spec = "fury",         exp = "tbc",    file = "classes/warrior/fury_sylvanas.lua" },
  { class = "warrior", spec = "protection",   exp = "tbc",    file = "classes/warrior/protection_sylvanas.lua" },
  { class = "warrior", spec = "kebab",        exp = "tbc",    file = "classes/warrior/kebab_sylvanas.lua" },
  { class = "warrior", spec = "arms",         exp = "vanilla",file = "classes/warrior/arms_vanilla.lua" },
  { class = "warrior", spec = "fury",         exp = "vanilla",file = "classes/warrior/fury_vanilla.lua" },
  { class = "warrior", spec = "protection",   exp = "vanilla",file = "classes/warrior/protection_vanilla.lua" },
  { class = "warrior", spec = "kebab",        exp = "vanilla",file = "classes/warrior/kebab_vanilla.lua" },
  -- Hunter
  { class = "hunter",  spec = "beast_mastery",exp = "tbc",    file = "classes/hunter/beast_mastery_sylvanas.lua" },
  { class = "hunter",  spec = "marksmanship", exp = "tbc",    file = "classes/hunter/marksmanship_sylvanas.lua" },
  { class = "hunter",  spec = "survival",     exp = "tbc",    file = "classes/hunter/survival_sylvanas.lua" },
  { class = "hunter",  spec = "beast_mastery",exp = "vanilla",file = "classes/hunter/beast_mastery_vanilla.lua" },
  { class = "hunter",  spec = "marksmanship", exp = "vanilla",file = "classes/hunter/marksmanship_vanilla.lua" },
  { class = "hunter",  spec = "survival",     exp = "vanilla",file = "classes/hunter/survival_vanilla.lua" },
  -- Mage
  { class = "mage",    spec = "arcane",       exp = "tbc",    file = "classes/mage/arcane_sylvanas.lua" },
  { class = "mage",    spec = "fire",         exp = "tbc",    file = "classes/mage/fire_sylvanas.lua" },
  { class = "mage",    spec = "frost",        exp = "tbc",    file = "classes/mage/frost_sylvanas.lua" },
  { class = "mage",    spec = "arcane",       exp = "vanilla",file = "classes/mage/arcane_vanilla.lua" },
  { class = "mage",    spec = "fire",         exp = "vanilla",file = "classes/mage/fire_vanilla.lua" },
  { class = "mage",    spec = "frost",        exp = "vanilla",file = "classes/mage/frost_vanilla.lua" },
  -- Paladin
  { class = "paladin", spec = "holy",         exp = "tbc",    file = "classes/paladin/holy_sylvanas.lua" },
  { class = "paladin", spec = "protection",   exp = "tbc",    file = "classes/paladin/protection_sylvanas.lua" },
  { class = "paladin", spec = "retribution",  exp = "tbc",    file = "classes/paladin/retribution_sylvanas.lua" },
  { class = "paladin", spec = "healing",      exp = "tbc",    file = "classes/paladin/healing_sylvanas.lua" },
  { class = "paladin", spec = "holy",         exp = "vanilla",file = "classes/paladin/holy_vanilla.lua" },
  { class = "paladin", spec = "protection",   exp = "vanilla",file = "classes/paladin/protection_vanilla.lua" },
  { class = "paladin", spec = "retribution",  exp = "vanilla",file = "classes/paladin/retribution_vanilla.lua" },
  -- Priest
  { class = "priest",  spec = "discipline",   exp = "tbc",    file = "classes/priest/discipline_sylvanas.lua" },
  { class = "priest",  spec = "holy",         exp = "tbc",    file = "classes/priest/holy_sylvanas.lua" },
  { class = "priest",  spec = "shadow",       exp = "tbc",    file = "classes/priest/shadow_sylvanas.lua" },
  { class = "priest",  spec = "smite",        exp = "tbc",    file = "classes/priest/smite_sylvanas.lua" },
  { class = "priest",  spec = "healing",      exp = "tbc",    file = "classes/priest/healing_sylvanas.lua" },
  { class = "priest",  spec = "discipline",   exp = "vanilla",file = "classes/priest/discipline_vanilla.lua" },
  { class = "priest",  spec = "holy",         exp = "vanilla",file = "classes/priest/holy_vanilla.lua" },
  { class = "priest",  spec = "shadow",       exp = "vanilla",file = "classes/priest/shadow_vanilla.lua" },
  { class = "priest",  spec = "smite",        exp = "vanilla",file = "classes/priest/smite_vanilla.lua" },
  -- Rogue
  { class = "rogue",   spec = "assassination",exp = "tbc",    file = "classes/rogue/assassination_sylvanas.lua" },
  { class = "rogue",   spec = "combat",       exp = "tbc",    file = "classes/rogue/combat_sylvanas.lua" },
  { class = "rogue",   spec = "subtlety",     exp = "tbc",    file = "classes/rogue/subtlety_sylvanas.lua" },
  { class = "rogue",   spec = "assassination",exp = "vanilla",file = "classes/rogue/assassination_vanilla.lua" },
  { class = "rogue",   spec = "combat",       exp = "vanilla",file = "classes/rogue/combat_vanilla.lua" },
  { class = "rogue",   spec = "subtlety",     exp = "vanilla",file = "classes/rogue/subtlety_vanilla.lua" },
  -- Shaman
  { class = "shaman",  spec = "elemental",    exp = "tbc",    file = "classes/shaman/elemental_sylvanas.lua" },
  { class = "shaman",  spec = "enhancement",  exp = "tbc",    file = "classes/shaman/enhancement_sylvanas.lua" },
  { class = "shaman",  spec = "restoration",  exp = "tbc",    file = "classes/shaman/restoration_sylvanas.lua" },
  { class = "shaman",  spec = "healing",      exp = "tbc",    file = "classes/shaman/healing_sylvanas.lua" },
  { class = "shaman",  spec = "elemental",    exp = "vanilla",file = "classes/shaman/elemental_vanilla.lua" },
  { class = "shaman",  spec = "enhancement",  exp = "vanilla",file = "classes/shaman/enhancement_vanilla.lua" },
  { class = "shaman",  spec = "restoration",  exp = "vanilla",file = "classes/shaman/restoration_vanilla.lua" },
  -- Druid
  { class = "druid",   spec = "balance",      exp = "tbc",    file = "classes/druid/balance_sylvanas.lua" },
  { class = "druid",   spec = "bear",         exp = "tbc",    file = "classes/druid/bear_sylvanas.lua" },
  { class = "druid",   spec = "cat",          exp = "tbc",    file = "classes/druid/cat_sylvanas.lua" },
  { class = "druid",   spec = "caster",       exp = "tbc",    file = "classes/druid/caster_sylvanas.lua" },
  { class = "druid",   spec = "resto",        exp = "tbc",    file = "classes/druid/resto_sylvanas.lua" },
  { class = "druid",   spec = "healing",      exp = "tbc",    file = "classes/druid/healing_sylvanas.lua" },
  { class = "druid",   spec = "balance",      exp = "vanilla",file = "classes/druid/balance_vanilla.lua" },
  { class = "druid",   spec = "bear",         exp = "vanilla",file = "classes/druid/bear_vanilla.lua" },
  { class = "druid",   spec = "cat",          exp = "vanilla",file = "classes/druid/cat_vanilla.lua" },
  { class = "druid",   spec = "caster",       exp = "vanilla",file = "classes/druid/caster_vanilla.lua" },
  { class = "druid",   spec = "resto",        exp = "vanilla",file = "classes/druid/resto_vanilla.lua" },
  -- Warlock
  { class = "warlock", spec = "affliction",   exp = "tbc",    file = "classes/warlock/affliction_sylvanas.lua" },
  { class = "warlock", spec = "demonology",   exp = "tbc",    file = "classes/warlock/demonology_sylvanas.lua" },
  { class = "warlock", spec = "destruction",  exp = "tbc",    file = "classes/warlock/destruction_sylvanas.lua" },
  { class = "warlock", spec = "affliction",   exp = "vanilla",file = "classes/warlock/affliction_vanilla.lua" },
  { class = "warlock", spec = "demonology",   exp = "vanilla",file = "classes/warlock/demonology_vanilla.lua" },
  { class = "warlock", spec = "destruction",  exp = "vanilla",file = "classes/warlock/destruction_vanilla.lua" },
}

local CONTENT_TYPES = { "solo", "dungeon", "raid", "arena", "battleground", "leveling" }

-- Score helper: clamp 0-5
local function clamp(v) return math.max(0, math.min(5, math.floor(v + 0.5))) end

-- Read file contents
local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content
end

-- Count strategies in a spec file
local function count_strategies(content)
  local n = 0
  for line in content:gmatch("[^\r\n]+") do
    if line:match('name%s*=%s*"') then n = n + 1 end
  end
  return n
end

-- Check for Pattern 15 header
local function has_pattern15(content)
  local first20 = content:sub(1, 800)
  return first20:find("WHAT:") and first20:find("WHEN:") and first20:find("WHY:")
end

-- Check for content-type gating
local function has_content_gating(content, ctype)
  local patterns = {
    solo       = { "is_solo", "not .*is_group", "not .*is_raid" },
    dungeon    = { "is_group", "enemy_count", "is_aoe" },
    raid       = { "is_raid", "gate_cooldown_boss_only", "should_burst" },
    arena      = { "is_pvp", "arena", "burst_score" },
    battleground = { "is_pvp", "enemy_count", "is_aoe" },
    leveling   = { "is_leveling", "leveling" },
  }
  for _, p in ipairs(patterns[ctype] or {}) do
    if content:find(p) then return true end
  end
  return false
end

-- Check for feature categories
local function has_feature(content, feature)
  local patterns = {
    defensive  = { "IceBarrier", "ManaShield", "ShieldWall", "DivineShield", "Barkskin", "PowerWordShield", "hp_pct", "health_percentage", "use_defensives" },
    interrupt  = { "Counterspell", "Kick", "Pummel", "Silence", "WindShear", "use_interrupt", "target_casting" },
    cooldown   = { "RapidFire", "ArcanePower", "PresenceOfMind", "DeathWish", "Recklessness", "AdrenalineRush", "gate_cooldown", "should_burst" },
    consumable = { "potion_helper", "HealthPotion", "ManaPotion", "healthstone", "ManaGem", "consumable" },
    trinket    = { "Trinket", "trinket", "use_trinket" },
  }
  for _, p in ipairs(patterns[feature] or {}) do
    if content:find(p) then return true end
  end
  return false
end

-- Count test files for a spec
local function count_tests(class, spec, exp)
  local test_dir = "EaxRotations\\tests"
  local count = 0
  local prefix = spec:gsub("_", ""):gsub("%-", "")
  local class_lower = class:lower()
  local prefix_lower = prefix:lower()

  -- Use dir on Windows (io.popen uses cmd.exe)
  local cmd = 'dir /b "' .. test_dir .. '" 2>nul'
  local f = io.popen(cmd)
  if f then
    for line in f:lines() do
      local lowered = line:lower()
      if lowered:find(class_lower) or lowered:find(prefix_lower) then
        if exp == "tbc" and not lowered:find("vanilla") then
          count = count + 1
        elseif exp == "vanilla" and lowered:find("vanilla") then
          count = count + 1
        end
      end
    end
    f:close()
  end
  return count
end

-- Compute scores for one spec
local function score_spec(entry)
  local path = "EaxRotations/" .. entry.file
  local content = read_file(path)
  if not content then
    return { overall = 0, apl = 0, tests = 0, features = 0, spell_validity = 5,
             content = {}, missing = true }
  end

  local strat_count = count_strategies(content)
  local p15 = has_pattern15(content)

  -- APL score: strategies + header + nil-guards
  local apl = 2  -- base for having a file
  if p15 then apl = apl + 1 end
  if strat_count >= 5 then apl = apl + 1 end
  if strat_count >= 10 then apl = apl + 1 end
  if content:find("or 0") and content:find("or 100") then apl = apl + 1 end
  apl = clamp(apl)

  -- Test score
  local test_count = count_tests(entry.class, entry.spec, entry.exp)
  local tests = clamp(test_count)

  -- Feature score
  local feat_count = 0
  for _, feat in ipairs({"defensive", "interrupt", "cooldown", "consumable", "trinket"}) do
    if has_feature(content, feat) then feat_count = feat_count + 1 end
  end
  local features = clamp(feat_count + 1)

  -- Content-type scores
  local content_scores = {}
  for _, ctype in ipairs(CONTENT_TYPES) do
    local gated = has_content_gating(content, ctype)
    local score = 2  -- base
    if gated then score = score + 1 end
    if feat_count >= 3 then score = score + 1 end
    if apl >= 4 then score = score + 1 end
    content_scores[ctype] = clamp(score)
  end

  -- Spell validity (assume 5 if file exists; spell audit catches separately)
  local spell_validity = 5

  -- Overall = weighted average
  local overall = clamp((apl * 2 + tests + features * 1.5 + spell_validity) / 5.5)

  return {
    overall = overall,
    apl = apl,
    tests = tests,
    features = features,
    spell_validity = spell_validity,
    content = content_scores,
    missing = false,
    strat_count = strat_count,
    has_pattern15 = p15,
  }
end

-- Star rendering
local function stars(n)
  local out = ""
  for i = 1, 5 do
    out = out .. (i <= n and "★" or "☆")
  end
  return out
end

-- Main
local results = {}
local total_score = 0
local count = 0

for _, entry in ipairs(SPECS) do
  local scores = score_spec(entry)
  results[#results + 1] = {
    class = entry.class,
    spec = entry.spec,
    expansion = entry.exp,
    scores = scores,
  }
  total_score = total_score + scores.overall
  count = count + 1
end

local avg = count > 0 and (total_score / count) or 0

-- Write Markdown report
local md = io.open("SCORECARD.md", "w")
if md then
  -- Grade distribution
  local grades = { s = 0, a = 0, b = 0, c = 0, d = 0, f = 0 }
  local tbc_avg, tbc_count, van_avg, van_count = 0, 0, 0, 0
  local content_sums = { solo = 0, dungeon = 0, raid = 0, arena = 0, battleground = 0, leveling = 0 }
  for _, r in ipairs(results) do
    local ov = r.scores.overall
    if ov >= 5 then grades.s = grades.s + 1
    elseif ov >= 4 then grades.a = grades.a + 1
    elseif ov >= 3 then grades.b = grades.b + 1
    elseif ov >= 2 then grades.c = grades.c + 1
    elseif ov >= 1 then grades.d = grades.d + 1
    else grades.f = grades.f + 1 end
    if r.expansion == "tbc" then tbc_avg = tbc_avg + ov; tbc_count = tbc_count + 1
    else van_avg = van_avg + ov; van_count = van_count + 1 end
    for k, v in pairs(r.scores.content) do content_sums[k] = content_sums[k] + v end
  end

  md:write("# EAX Rotation Scorecard\n\n")
  md:write("> Auto-generated quality scores for all specs. Run `lua build_tools/compute_scorecard.lua` to regenerate.\n\n")
  md:write(string.format("**Overall Average:** %.1f / 5.0  |  **%d specs scored**\n\n", avg, count))
  md:write("## Grade Distribution\n\n")
  md:write("| Grade | Count | Meaning |\n")
  md:write("|-------|-------|---------|\n")
  md:write(string.format("| ★★★★★ S (5/5) | %d | Excellent — guide-verified APL, full features, tested |\n", grades.s))
  md:write(string.format("| ★★★★☆ A (4/5) | %d | Good — functional, some gaps (usually tests) |\n", grades.a))
  md:write(string.format("| ★★★☆☆ B (3/5) | %d | Fair — works but minimal (shared healers, leveling specs) |\n", grades.b))
  md:write(string.format("| ★★☆☆☆ C (2/5) | %d | — |\n", grades.c))
  md:write(string.format("| ★☆☆☆☆ D (1/5) | %d | — |\n", grades.d))
  md:write(string.format("| ☆☆☆☆☆ F (0/5) | %d | — |\n\n", grades.f))
  md:write("## Expansion Averages\n\n")
  md:write(string.format("- **TBC:** %.1f/5 (%d specs)\n", tbc_count > 0 and tbc_avg/tbc_count or 0, tbc_count))
  md:write(string.format("- **Vanilla:** %.1f/5 (%d specs)\n\n", van_count > 0 and van_avg/van_count or 0, van_count))
  md:write("## Content Type Averages\n\n")
  md:write("| Solo | Dungeon | Raid | Arena | Battleground | Leveling |\n")
  md:write("|------|---------|------|-------|--------------|----------|\n")
  md:write(string.format("| %.1f | %.1f | %.1f | %.1f | %.1f | %.1f |\n\n",
    content_sums.solo/count, content_sums.dungeon/count, content_sums.raid/count,
    content_sums.arena/count, content_sums.battleground/count, content_sums.leveling/count))
  md:write("## Full Score Table\n\n")
  md:write("| Class | Spec | Expansion | APL | Tests | Features | Solo | Dungeon | Raid | Arena | BG | Level | Overall |\n")
  md:write("|-------|------|-----------|-----|-------|----------|------|---------|------|-------|----|-------|---------|\n")

  for _, r in ipairs(results) do
    local s = r.scores
    md:write(string.format("| %s | %s | %s | %d | %d | %d | %s | %s | %s | %s | %s | %s | %s (%d/5) |\n",
      r.class:gsub("^%l", string.upper),
      r.spec,
      r.expansion,
      s.apl, s.tests, s.features,
      stars(s.content.solo),
      stars(s.content.dungeon),
      stars(s.content.raid),
      stars(s.content.arena),
      stars(s.content.battleground),
      stars(s.content.leveling),
      stars(s.overall),
      s.overall
    ))
  end

  md:write("\n## Legend\n\n")
  md:write("- **APL**: Strategy count, Pattern 15 header, nil-guard coverage\n")
  md:write("- **Tests**: Dedicated test file count\n")
  md:write("- **Features**: Defensive, Interrupt, Cooldown, Consumable, Trinket coverage\n")
  md:write("- **Content**: Content-type gating + feature appropriateness\n")
  md:write("- **Overall**: Weighted average of all dimensions\n\n")
  md:write("★ = Needs work  |  ★★ = Basic  |  ★★★ = Functional  |  ★★★★ = Good  |  ★★★★★ = Excellent\n")
  md:close()
  print("Wrote SCORECARD.md")
end

-- Write JSON
local json_out = io.open("EaxRotations/scorecard_data.json", "w")
if json_out then
  json_out:write("{\n  \"generated\": \"", os.date("%Y-%m-%d"), "\",\n")
  json_out:write(string.format("  \"overall_average\": %.2f,\n", avg))
  json_out:write("  \"specs\": [\n")
  for i, r in ipairs(results) do
    local s = r.scores
    local comma = (i < #results) and "," or ""
    json_out:write(string.format(
      "    {\"class\":\"%s\",\"spec\":\"%s\",\"expansion\":\"%s\",\"overall\":%d,\"apl\":%d,\"tests\":%d,\"features\":%d,\"spell_validity\":%d,\"content\":{\"solo\":%d,\"dungeon\":%d,\"raid\":%d,\"arena\":%d,\"battleground\":%d,\"leveling\":%d}}%s\n",
      r.class, r.spec, r.expansion, s.overall, s.apl, s.tests, s.features, s.spell_validity,
      s.content.solo, s.content.dungeon, s.content.raid, s.content.arena, s.content.battleground, s.content.leveling,
      comma
    ))
  end
  json_out:write("  ]\n}\n")
  json_out:close()
  print("Wrote EaxRotations/scorecard_data.json")
end

print(string.format("\nDone. %d specs scored. Average: %.1f/5.0", count, avg))
