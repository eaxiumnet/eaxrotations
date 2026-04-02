--[[
  Theory Validation: Validation Runner
  
  Executes validation suite against all 27 specs and generates reports.
  Usage: lua theory_validation/validation_runner.lua
]]

local simulator = require("theory_validation.simulator_core")
local json = require("json") -- Assumes json library available

local runner = {}

-- Specs to validate
runner.SPECS = {
  -- DPS Casters
  { name = "MAGE_ARCANE", class = "Mage", spec = "Arcane", role = "DPS", tier = 5 },
  { name = "MAGE_FIRE", class = "Mage", spec = "Fire", role = "DPS", tier = 5 },
  { name = "MAGE_FROST", class = "Mage", spec = "Frost", role = "DPS", tier = 5 },
  { name = "WARLOCK_AFFLICTION", class = "Warlock", spec = "Affliction", role = "DPS", tier = 5 },
  { name = "WARLOCK_DESTRUCTION", class = "Warlock", spec = "Destruction", role = "DPS", tier = 5 },
  { name = "DRUID_BALANCE", class = "Druid", spec = "Balance", role = "DPS", tier = 4 },
  { name = "SHAMAN_ELEMENTAL", class = "Shaman", spec = "Elemental", role = "DPS", tier = 5 },
  { name = "PRIEST_SHADOW", class = "Priest", spec = "Shadow", role = "DPS", tier = 5 },
  
  -- Physical DPS
  { name = "HUNTER_BM", class = "Hunter", spec = "Beast Mastery", role = "DPS", tier = 4 },
  { name = "HUNTER_MM", class = "Hunter", spec = "Marksmanship", role = "DPS", tier = 5 },
  { name = "HUNTER_SURVIVAL", class = "Hunter", spec = "Survival", role = "DPS", tier = 4 },
  { name = "WARRIOR_ARMS", class = "Warrior", spec = "Arms", role = "DPS", tier = 4 },
  { name = "WARRIOR_FURY", class = "Warrior", spec = "Fury", role = "DPS", tier = 5 },
  { name = "ROGUE_ASSASSINATION", class = "Rogue", spec = "Assassination", role = "DPS", tier = 5 },
  { name = "ROGUE_COMBAT", class = "Rogue", spec = "Combat", role = "DPS", tier = 5 },
  { name = "ROGUE_SUBTLETY", class = "Rogue", spec = "Subtlety", role = "DPS", tier = 4 },
  { name = "ENHANCEMENT_SHAMAN", class = "Shaman", spec = "Enhancement", role = "DPS", tier = 5 },
  { name = "FERAL_DRUID", class = "Druid", spec = "Feral", role = "DPS", tier = 5 },
  { name = "RETRIBUTION_PALADIN", class = "Paladin", spec = "Retribution", role = "DPS", tier = 5 },
  
  -- Tanks
  { name = "WARRIOR_PROTECTION", class = "Warrior", spec = "Protection", role = "Tank", tier = 4 },
  { name = "PALADIN_PROTECTION", class = "Paladin", spec = "Protection", role = "Tank", tier = 5 },
  { name = "FERAL_BEAR", class = "Druid", spec = "Feral (Bear)", role = "Tank", tier = 5 },
  
  -- Healers
  { name = "HOLY_PALADIN", class = "Paladin", spec = "Holy", role = "Healer", tier = 5 },
  { name = "RESTO_SHAMAN", class = "Shaman", spec = "Restoration", role = "Healer", tier = 5 },
  { name = "RESTO_DRUID", class = "Druid", spec = "Restoration", role = "Healer", tier = 5 },
  { name = "HOLY_PRIEST", class = "Priest", spec = "Holy", role = "Healer", tier = 5 },
  { name = "DISC_PRIEST", class = "Priest", spec = "Discipline", role = "Healer", tier = 4 },
}

-- Encounters to test against
runner.ENCOUNTERS = { "gruul", "magtheridon", "void_reaver", "lurker" }

-- Run full validation suite
function runner.validate_all()
  print("=" .. string.rep("=", 78))
  print("EAX TBC CLASSIC ROTATIONS - THEORY VALIDATION SUITE")
  print("=" .. string.rep("=", 78))
  print()
  
  local results = {}
  local pass_count = 0
  local warn_count = 0
  local fail_count = 0
  
  for _, spec in ipairs(runner.SPECS) do
    print(string.format("Testing %s %s...", spec.class, spec.spec))
    
    local spec_results = {
      spec = spec,
      encounters = {}
    }
    
    for _, encounter_name in ipairs(runner.ENCOUNTERS) do
      local result, err = simulator.run_rotation(spec.name, encounter_name)
      
      if result then
        table.insert(spec_results.encounters, {
          encounter = encounter_name,
          dps = math.floor(result.dps),
          oom_time = math.floor(result.om_time or 0),
          verdict = result.verdict,
          issues = result.issues or {},
          warnings = result.warnings or {}
        })
        
        -- Track overall status
        if result.verdict == "PASS" then
          pass_count = pass_count + 1
        elseif result.verdict == "PASS_WITH_WARNINGS" then
          warn_count = warn_count + 1
        else
          fail_count = fail_count + 1
        end
      else
        print(string.format("  ERROR: %s", err or "Unknown error"))
        fail_count = fail_count + 1
      end
    end
    
    table.insert(results, spec_results)
    
    -- Print summary for this spec
    local avg_dps = 0
    local min_oom = 9999
    for _, enc in ipairs(spec_results.encounters) do
      avg_dps = avg_dps + enc.dps
      if enc.oom_time < min_oom then min_oom = enc.oom_time end
    end
    avg_dps = math.floor(avg_dps / #spec_results.encounters)
    
    local status_icon = "✓"
    local status_color = "PASS"
    if fail_count > 0 then
      status_icon = "✗"
      status_color = "FAIL"
    elseif warn_count > 0 then
      status_icon = "⚠"
      status_color = "WARN"
    end
    
    print(string.format("  %s Avg DPS: %d | Min OOM: %ds | Status: %s", 
      status_icon, avg_dps, min_oom, status_color))
    print()
  end
  
  -- Print summary
  print("=" .. string.rep("=", 78))
  print("VALIDATION SUMMARY")
  print("=" .. string.rep("=", 78))
  print(string.format("Total specs tested: %d", #runner.SPECS))
  print(string.format("PASS: %d | WARNINGS: %d | FAIL: %d", pass_count, warn_count, fail_count))
  print()
  
  -- Generate report
  runner.generate_report(results)
  
  return results
end

-- Generate validation report
function runner.generate_report(results)
  local report = {}
  
  table.insert(report, "# EAX Theory Validation Report")
  table.insert(report, "")
  table.insert(report, string.format("Generated: %s", os.date("%Y-%m-%d %H:%M:%S")))
  table.insert(report, "")
  
  -- Summary table
  table.insert(report, "## Summary")
  table.insert(report, "")
  table.insert(report, "| Status | Count |")
  table.insert(report, "|--------|-------|")
  
  local pass = 0
  local warn = 0
  local fail = 0
  for _, spec_result in ipairs(results) do
    local spec_pass = true
    local has_warn = false
    for _, enc in ipairs(spec_result.encounters) do
      if enc.verdict == "FAIL" then spec_pass = false end
      if enc.verdict == "PASS_WITH_WARNINGS" then has_warn = true end
    end
    if not spec_pass then fail = fail + 1 elseif has_warn then warn = warn + 1 else pass = pass + 1 end
  end
  
  table.insert(report, string.format("| ✅ PASS | %d |", pass))
  table.insert(report, string.format("| ⚠️ WARN | %d |", warn))
  table.insert(report, string.format("| ❌ FAIL | %d |", fail))
  table.insert(report, "")
  
  -- Detailed results
  table.insert(report, "## Detailed Results")
  table.insert(report, "")
  
  for _, spec_result in ipairs(results) do
    local spec = spec_result.spec
    table.insert(report, string.format("### %s %s (%s)", spec.class, spec.spec, spec.role))
    table.insert(report, "")
    
    table.insert(report, "| Encounter | DPS/HPS | Mana Sustain | Verdict |")
    table.insert(report, "|-----------|---------|--------------|---------|")
    
    for _, enc in ipairs(spec_result.encounters) do
      local encounter = simulator.ENCOUNTERS[enc.encounter]
      local mana_status = enc.oom_time >= encounter.fight_duration and "✓" or string.format("⚠ %ds", enc.oom_time)
      local verdict_icon = enc.verdict == "PASS" and "✅" or (enc.verdict == "PASS_WITH_WARNINGS" and "⚠️" or "❌")
      
      table.insert(report, string.format("| %s | %d | %s | %s |", 
        encounter.name, enc.dps, mana_status, verdict_icon))
    end
    
    table.insert(report, "")
  end
  
  -- Write report
  local report_text = table.concat(report, "\n")
  local f = io.open("validation_report.md", "w")
  if f then
    f:write(report_text)
    f:close()
    print("Report saved: validation_report.md")
  end
end

-- Run if executed directly
if arg and arg[0]:match("validation_runner%.lua$") then
  runner.validate_all()
end

return runner
