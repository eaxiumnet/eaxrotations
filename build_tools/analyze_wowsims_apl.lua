-- analyze_wowsims_apl.lua — Parse wowsims/classic APL JSON and compare to our rotations.
-- WHAT:  reads APL JSON, extracts spell priority list, maps spell IDs to names.
-- WHEN:  run after wowsims/classic update to audit our rotations against sim APLs.
-- WHY:   wowsims APLs are community-optimized; gaps against them = optimization opportunities.
-- USAGE: cd repo_root && lua build_tools/analyze_wowsims_apl.lua [spec_name]

local json = {
  decode = function(s)
    -- Minimal JSON decoder for APL files (no nested arrays of objects beyond priorityList)
    local function parse_val(str, i)
      local c = str:sub(i, i)
      if c == '"' then
        local j = i + 1
        while j <= #str do
          local ch = str:sub(j, j)
          if ch == '\\' then j = j + 2
          elseif ch == '"' then return str:sub(i+1, j-1):gsub('\\(.)', '%1'), j + 1
          else j = j + 1 end
        end
      elseif c == '{' then
        local obj, j = {}, i + 1
        while true do
          j = j + (str:sub(j, j):match("%s") and 1 or 0)
          if str:sub(j, j) == '}' then return obj, j + 1 end
          local key; key, j = parse_val(str, j)
          j = str:find(':', j) + 1
          local val; val, j = parse_val(str, j)
          obj[key] = val
          j = j + (str:sub(j, j):match("%s") and 1 or 0)
          if str:sub(j, j) == ',' then j = j + 1 end
        end
      elseif c == '[' then
        local arr, j = {}, i + 1
        while true do
          j = j + (str:sub(j, j):match("%s") and 1 or 0)
          if str:sub(j, j) == ']' then return arr, j + 1 end
          local val; val, j = parse_val(str, j)
          arr[#arr + 1] = val
          j = j + (str:sub(j, j):match("%s") and 1 or 0)
          if str:sub(j, j) == ',' then j = j + 1 end
        end
      elseif c == 't' and str:sub(i, i+3) == 'true' then return true, i + 4
      elseif c == 'f' and str:sub(i, i+4) == 'false' then return false, i + 5
      elseif c == 'n' and str:sub(i, i+3) == 'null' then return nil, i + 4
      else
        local num, nxt = str:match("^(-?%d+%.?%d*)", i)
        if num then return tonumber(num), i + #num end
      end
      return nil, i
    end
    local function skip_ws(str, i)
      while i <= #str and str:sub(i, i):match("%s") do i = i + 1 end
      return i
    end
    local i = skip_ws(s, 1)
    local val, j = parse_val(s, i)
    return val
  end
}

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local c = f:read("*a")
  f:close()
  return c
end

local function spell_id_to_name(spell_id)
  -- Try to resolve from DBC or spell_db
  local db_path = "wowheadScrape/dbc_extract/lua/spell_db.lua"
  local db = read_file(db_path)
  if db then
    local pattern = "\\[" .. tostring(spell_id) .. "\\]%s*=%s*{[^}]*name%s*=%s*\"([^\"]+)\""
    local name = db:match(pattern)
    if name then return name end
  end
  return "Spell_" .. spell_id
end

local function extract_spell_from_action(action)
  if not action then return nil end
  if action.castSpell and action.castSpell.spellId then
    local sid = action.castSpell.spellId.spellId or action.castSpell.spellId.itemId
    if sid then
      local name = spell_id_to_name(sid)
      return name, sid
    end
  end
  if action.autocastOtherCooldowns then return "[Autocast Cooldowns]", nil end
  return nil
end

local function has_condition(action)
  if not action then return false end
  if action.condition then
    if action.condition.const and action.condition.const.val == "false" then return false end
    return true
  end
  return false
end

local function format_condition(cond, depth)
  depth = depth or 0
  if not cond then return "" end
  if depth > 3 then return "..." end
  if cond.cmp then
    local lhs = format_condition(cond.cmp.lhs, depth + 1)
    local rhs = format_condition(cond.cmp.rhs, depth + 1)
    return lhs .. " " .. (cond.cmp.op or "?") .. " " .. rhs
  elseif cond.const then
    return cond.const.val or ""
  elseif cond.and_ then
    local parts = {}
    for _, v in ipairs(cond.and_.vals or {}) do
      parts[#parts + 1] = format_condition(v, depth + 1)
    end
    return table.concat(parts, " && ")
  elseif cond.or_ then
    local parts = {}
    for _, v in ipairs(cond.or_.vals or {}) do
      parts[#parts + 1] = format_condition(v, depth + 1)
    end
    return table.concat(parts, " || ")
  elseif cond.not_ then
    return "!" .. format_condition(cond.not_.val, depth + 1)
  elseif cond.auraIsActive then
    return "aura_active(" .. (cond.auraIsActive.auraId and cond.auraIsActive.auraId.spellId or "?") .. ")"
  elseif cond.isExecutePhase then
    return "execute_phase(" .. (cond.isExecutePhase.threshold or "?") .. ")"
  elseif cond.numberTargets then
    return "targets"
  elseif cond.currentRage then
    return "rage"
  elseif cond.remainingTime then
    return "remaining_time"
  elseif cond.spellTimeToReady then
    return "cd(" .. (cond.spellTimeToReady.spellId and cond.spellTimeToReady.spellId.spellId or "?") .. ")"
  elseif cond.auraNumStacks then
    return "stacks(" .. (cond.auraNumStacks.auraId and cond.auraNumStacks.auraId.spellId or "?") .. ")"
  end
  return "?"
end

local APL_DIRS = {
  warrior = "wowsims_classic/ui/warrior/apls",
  hunter = "wowsims_classic/ui/hunter/apls",
  mage = "wowsims_classic/ui/mage/apls",
  paladin = "wowsims_classic/ui/retribution_paladin/apls",
  priest = "wowsims_classic/ui/shadow_priest/apls",
  rogue = "wowsims_classic/ui/rogue/apls",
  shaman = "wowsims_classic/ui/elemental_shaman/apls",
  druid = "wowsims_classic/ui/balance_druid/apls",
  warlock = "wowsims_classic/ui/warlock/apls",
}

local APL_ALIASES = {
  fury = { "dps_reck.apl.json", "dps_no_reck.apl.json" },
  arms = { "arms.apl.json", "dps_reck.apl.json", "dps_no_reck.apl.json" },
  protection = { "default.apl.json", "basic_prot.apl.json", "p5prot.apl.json" },
  marksmanship = { "p1.apl.json" },
  beast_mastery = { "p1.apl.json" },
  survival = { "p1.apl.json" },
  arcane = { "p1.apl.json", "arcane.apl.json" },
  fire = { "p1.apl.json" },
  frost = { "p1.apl.json" },
  retribution = { "basic_ret.apl.json" },
  holy = { "basic_prot.apl.json" },
  shadow = { "p1.apl.json" },
  combat = { "combat_sinister_strike.apl.json", "swords.apl.json" },
  assassination = { "combat_backstab.apl.json" },
  subtlety = { "combat_sinister_strike.apl.json" },
  elemental = { "default.apl.json" },
  enhancement = { "default.apl.json" },
  restoration = { "default.apl.json" },
  balance = { "balance.apl.json", "p1.apl.json" },
  bear = { "feral.apl.json", "default.apl.json" },
  cat = { "feral.apl.json", "p1.apl.json" },
  resto = { "default.apl.json" },
  affliction = { "rotation.apl.json", "affliction.apl.json" },
  demonology = { "rotation.apl.json", "demonology.apl.json" },
  destruction = { "rotation.apl.json", "destro_fire.apl.json", "destruction.apl.json" },
}

local SPEC_MAP = {
  arms = "warrior",
  fury = "warrior",
  protection = "warrior",
  beast_mastery = "hunter",
  marksmanship = "hunter",
  survival = "hunter",
  arcane = "mage",
  fire = "mage",
  frost = "mage",
  retribution = "paladin",
  holy = "paladin",
  protection_paladin = "paladin",
  shadow = "priest",
  discipline = "priest",
  holy_priest = "priest",
  combat = "rogue",
  assassination = "rogue",
  subtlety = "rogue",
  elemental = "shaman",
  enhancement = "shaman",
  restoration = "shaman",
  balance = "druid",
  feral = "druid",
  resto = "druid",
  affliction = "warlock",
  demonology = "warlock",
  destruction = "warlock",
}

local function analyze_apl_file(apl_path)
  local content = read_file(apl_path)
  if not content then return nil end
  local ok, apl = pcall(json.decode, content)
  if not ok or not apl.priorityList then return nil end

  local spells = {}
  for i, entry in ipairs(apl.priorityList) do
    local action = entry.action
    if not entry.hide then
      local name, id = extract_spell_from_action(action)
      if name then
        local cond = ""
        if has_condition(action) then
          cond = format_condition(action.condition)
        end
        spells[#spells + 1] = {
          rank = i,
          name = name,
          spell_id = id,
          condition = cond,
        }
      end
    end
  end
  return spells
end

-- Compare our rotation strategies against wowsims APL
local function compare_with_our_rotation(spec_name, expansion)
  expansion = expansion or "sylvanas"
  local class = SPEC_MAP[spec_name]
  if not class then return nil end

  -- Find our spec file
  local our_path = "EaxRotations/classes/" .. class .. "/" .. spec_name .. "_" .. expansion .. ".lua"
  local our_content = read_file(our_path)
  if not our_content then return nil end

  -- Extract our strategy names
  local our_strats = {}
  for line in our_content:gmatch("[^\r\n]+") do
    local name = line:match('name%s*=%s*"([^"]+)"')
    if name and not name:match("^Unavailable") then
      our_strats[#our_strats + 1] = name
    end
  end

  -- Find wowsims APL files for this class
  local apl_dir = APL_DIRS[class]
  if not apl_dir then return nil end

  local results = {}
  local tried = APL_ALIASES[spec_name] or { "default.apl.json", "p1.apl.json", spec_name .. ".apl.json" }

  for _, file in ipairs(tried) do
    local apl_spells = analyze_apl_file(apl_dir .. "/" .. file)
    if apl_spells then
      results[#results + 1] = { file = file, apl = apl_spells }
      break  -- Use first match
    end
  end

  -- Fallback: scan directory
  if #results == 0 then
    local handle = io.popen('dir /b "' .. apl_dir:gsub("/", "\\") .. '" 2>nul')
    if handle then
      for file in handle:lines() do
        if file:match("%.apl%.json$") then
          local apl_spells = analyze_apl_file(apl_dir .. "/" .. file)
          if apl_spells then
            results[#results + 1] = { file = file, apl = apl_spells }
          end
        end
      end
      handle:close()
    end
  end

  return { spec = spec_name, class = class, our_strats = our_strats, wowsims = results }
end

-- Main
local target_spec = arg[1]

if target_spec then
  local result = compare_with_our_rotation(target_spec, "sylvanas")
  if not result then
    print("Could not analyze spec: " .. target_spec)
    return
  end

  print("=== " .. target_spec:gsub("_", " "):gsub("^%l", string.upper) .. " (TBC) ===")
  print("\nOur strategies (" .. #result.our_strats .. "):")
  for i, s in ipairs(result.our_strats) do
    print("  " .. i .. ". " .. s)
  end

  for _, wsim in ipairs(result.wowsims) do
    print("\nWoWSims APL: " .. wsim.file .. " (" .. #wsim.apl .. " actions)")
    for i, a in ipairs(wsim.apl) do
      local cond = a.condition ~= "" and "  [if " .. a.condition .. "]" or ""
      print("  " .. i .. ". " .. a.name .. cond)
    end
  end
else
  -- List all available APL files
  print("WoWSims Classic APL files found:")
  for class, dir in pairs(APL_DIRS) do
    local handle = io.popen('dir /b "' .. dir:gsub("/", "\\") .. '" 2>nul')
    if handle then
      for file in handle:lines() do
        if file:match("%.apl%.json$") then
          local spells = analyze_apl_file(dir .. "/" .. file)
          if spells then
            print("  " .. class .. "/" .. file .. " -> " .. #spells .. " actions")
          end
        end
      end
      handle:close()
    end
  end
  print("\nUsage: lua build_tools/analyze_wowsims_apl.lua <spec_name>")
  print("  e.g., lua build_tools/analyze_wowsims_apl.lua fury")
end
