local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local c = f:read("*a")
  f:close()
  return c
end

local function spell_id_to_name(spell_id)
  local db_path = "wowheadScrape/dbc_extract/lua/spell_db.lua"
  local db = read_file(db_path)
  if db then
    local pattern = "\\[" .. tostring(spell_id) .. "\\]%s*=%s*{[^}]*name%s*=%s*\"([^\"]+)\""
    local name = db:match(pattern)
    if name then return name end
  end
  return "Spell_" .. spell_id
end

local function extract_apl_actions(content)
  if not content then return nil end
  
  local plist = content:match('"priorityList"%s*:%s*(%[.-%])')
  if not plist then return nil end
  
  local actions = {}
  local pos = 1
  
  while true do
    local entry_start = plist:find('{', pos)
    if not entry_start then break end
    
    -- Find matching closing brace for this entry
    local depth = 1
    local entry_end = entry_start + 1
    while depth > 0 and entry_end <= #plist do
      local ch = plist:sub(entry_end, entry_end)
      if ch == '{' then
        depth = depth + 1
      elseif ch == '}' then
        depth = depth - 1
      elseif ch == '"' then
        -- Skip string
        local j = entry_end + 1
        while j <= #plist do
          local sch = plist:sub(j, j)
          if sch == '\\' then j = j + 2
          elseif sch == '"' then break
          else j = j + 1 end
        end
        entry_end = j
      end
      entry_end = entry_end + 1
    end
    
    local entry_str = plist:sub(entry_start, entry_end - 1)
    
    -- Check if hidden
    local hide = entry_str:find('"hide"%s*:%s*true') ~= nil
    
    -- Extract spell ID
    local spell_id = entry_str:match('"spellId"%s*:%s*{%s*"spellId"%s*:%s*(%d+)')
    if not spell_id then
      spell_id = entry_str:match('"spellId"%s*:%s*{%s*"itemId"%s*:%s*(%d+)')
    end
    
    -- Extract condition
    local has_cond = entry_str:find('"condition"') ~= nil
    
    -- Extract group reference
    local group_name = entry_str:match('"groupReference"%s*:%s*{%s*"groupName"%s*:%s*"([^"]+)"')
    
    if not hide then
      if spell_id then
        local name = spell_id_to_name(tonumber(spell_id))
        actions[#actions + 1] = { 
          name = name, 
          spell_id = tonumber(spell_id), 
          condition = has_cond,
          group = group_name
        }
      elseif group_name then
        actions[#actions + 1] = {
          name = "[" .. group_name .. "]",
          spell_id = nil,
          condition = has_cond,
          group = group_name
        }
      end
    end
    
    pos = entry_end
  end
  
  return actions
end

local APL_DIRS = {
  tbc = {
    warrior = "tbc-new/ui/warrior/dps/apls",
    warrior_protection = "tbc-new/ui/warrior/protection/apls",
    hunter = "tbc-new/ui/hunter/dps/apls",
    mage = "tbc-new/ui/mage/dps/apls",
    paladin = "tbc-new/ui/paladin/retribution/apls",
    paladin_protection = "tbc-new/ui/paladin/protection/apls",
    priest = "tbc-new/ui/priest/dps/apls",
    rogue = "tbc-new/ui/rogue/dps/apls",
    shaman = "tbc-new/ui/shaman/elemental/apls",
    shaman_enhancement = "tbc-new/ui/shaman/enhancement/apls",
    druid = "tbc-new/ui/druid/balance/apls",
    druid_feralcat = "tbc-new/ui/druid/feralcat/apls",
    druid_feralbear = "tbc-new/ui/druid/feralbear/apls",
    warlock = "tbc-new/ui/warlock/dps/apls",
  },
  classic = {
    warrior = "wowsims_classic/ui/warrior/apls",
    hunter = "wowsims_classic/ui/hunter/apls",
    mage = "wowsims_classic/ui/mage/apls",
    paladin = "wowsims_classic/ui/retribution_paladin/apls",
    priest = "wowsims_classic/ui/shadow_priest/apls",
    rogue = "wowsims_classic/ui/rogue/apls",
    shaman = "wowsims_classic/ui/elemental_shaman/apls",
    druid = "wowsims_classic/ui/balance_druid/apls",
    warlock = "wowsims_classic/ui/warlock/apls",
  },
}

local APL_ALIASES = {
  fury = { "fury.apl.json" },
  arms = { "arms.apl.json" },
  protection = { "default.apl.json" },
  marksmanship = { "default.apl.json" },
  beast_mastery = { "default.apl.json" },
  survival = { "default.apl.json" },
  arcane = { "arcane.apl.json" },
  fire = { "blank.apl.json", "test.apl.json" },
  frost = { "blank.apl.json", "test.apl.json" },
  retribution = { "default.apl.json" },
  protection_paladin = { "default.apl.json" },
  shadow = { "default.apl.json" },
  combat = { "swords.apl.json" },
  assassination = { "swords.apl.json" },
  subtlety = { "swords.apl.json" },
  elemental = { "default.apl.json" },
  enhancement = { "default.apl.json" },
  restoration = { "default.apl.json" },
  balance = { "default.apl.json" },
  bear = { "default.apl.json" },
  cat = { "default.apl.json" },
  resto = { "default.apl.json" },
  affliction = { "affliction.apl.json" },
  demonology = { "demonology.apl.json" },
  destruction = { "destruction.apl.json" },
  destro_fire = { "destro_fire.apl.json" },
}

local SPEC_MAP = {
  arms = "warrior", fury = "warrior", protection = "warrior",
  beast_mastery = "hunter", marksmanship = "hunter", survival = "hunter",
  arcane = "mage", fire = "mage", frost = "mage",
  retribution = "paladin", holy = "paladin", protection_paladin = "paladin",
  shadow = "priest", discipline = "priest", holy_priest = "priest",
  combat = "rogue", assassination = "rogue", subtlety = "rogue",
  elemental = "shaman", enhancement = "shaman", restoration = "shaman",
  balance = "druid", feral = "druid", resto = "druid",
  affliction = "warlock", demonology = "warlock", destruction = "warlock",
}

local function get_apl_dir(class, expansion)
  expansion = expansion or "tbc"
  local dirs = APL_DIRS[expansion]
  if not dirs then return nil end
  if class == "warrior" then return dirs.warrior end
  if class == "paladin" then return dirs.paladin end
  if class == "shaman" then return dirs.shaman end
  if class == "druid" then return dirs.druid end
  return dirs[class]
end

local function get_apl_aliases(spec_name, expansion)
  expansion = expansion or "tbc"
  return APL_ALIASES[spec_name] or { "default.apl.json", spec_name .. ".apl.json" }
end

local function extract_strategies(our_content)
  local strats = {}
  for line in our_content:gmatch("[^\r\n]+") do
    local name = line:match('^[%s]*{[%s]*"([^"]+)"[%s]*,')
    if not name then name = line:match('name[%s]*=[%s]*"([^"]+)"') end
    if not name then name = line:match('{[%s]*name[%s]*=[%s]*"([^"]+)"') end
    if name and not name:match("^Unavailable") then
      strats[#strats + 1] = name
    end
  end
  return strats
end

local function compare_with_our_rotation(spec_name, expansion)
  expansion = expansion or "sylvanas"
  local class = SPEC_MAP[spec_name]
  if not class then return nil end

  local our_path = "EaxRotations/classes/" .. class .. "/" .. spec_name .. "_" .. expansion .. ".lua"
  local our_content = read_file(our_path)
  if not our_content then return nil end

  local our_strats = extract_strategies(our_content)

  local repo_expansion = "tbc"
  if our_path:match("_classic") then repo_expansion = "classic" end

  local apl_dir = get_apl_dir(class, repo_expansion)
  if not apl_dir then return nil end

  local results = {}
  local tried = get_apl_aliases(spec_name, repo_expansion)

  for _, file in ipairs(tried) do
    local apl_content = read_file(apl_dir .. "/" .. file)
    local apl_spells = extract_apl_actions(apl_content)
    if apl_spells and #apl_spells > 0 then
      results[#results + 1] = { file = file, apl = apl_spells }
      break
    end
  end

  if #results == 0 then
    local handle = io.popen('dir /b "' .. apl_dir:gsub("/", "\\") .. '" 2>nul')
    if handle then
      for file in handle:lines() do
        if file:match("%.apl%.json$") then
          local apl_content = read_file(apl_dir .. "/" .. file)
          local apl_spells = extract_apl_actions(apl_content)
          if apl_spells and #apl_spells > 0 then
            results[#results + 1] = { file = file, apl = apl_spells }
          end
        end
      end
      handle:close()
    end
  end

  return { spec = spec_name, class = class, our_strats = our_strats, wowsims = results }
end

local target_spec = arg[1]
local expansion_arg = arg[2] or "tbc"

if target_spec then
  local result = compare_with_our_rotation(target_spec, "sylvanas")
  if not result then
    print("Could not analyze spec: " .. target_spec)
    return
  end

  local label = expansion_arg == "classic" and "Classic" or "TBC"
  print("=== " .. target_spec:gsub("_", " "):gsub("^%l", string.upper) .. " (" .. label .. ") ===")
  print("\nOur strategies (" .. #result.our_strats .. "):")
  for i, s in ipairs(result.our_strats) do
    print("  " .. i .. ". " .. s)
  end

  for _, wsim in ipairs(result.wowsims) do
    print("\nWoWSims APL: " .. wsim.file .. " (" .. #wsim.apl .. " actions)")
    for i, a in ipairs(wsim.apl) do
      local cond = a.condition and "  [condition]" or ""
      print("  " .. i .. ". " .. a.name .. cond)
    end
  end
else
  local function list_apl_files(label, dirs)
    print("\n" .. label .. " APL files found:")
    for class, dir in pairs(dirs) do
      if type(dir) == "string" then
        local handle = io.popen('dir /b "' .. dir:gsub("/", "\\") .. '" 2>nul')
        if handle then
          for file in handle:lines() do
            if file:match("%.apl%.json$") then
              local apl_content = read_file(dir .. "/" .. file)
              local spells = extract_apl_actions(apl_content)
              if spells and #spells > 0 then
                print("  " .. class .. "/" .. file .. " -> " .. #spells .. " actions")
              end
            end
          end
          handle:close()
        end
      end
    end
  end

  list_apl_files("WoWSims TBC", APL_DIRS.tbc)
  list_apl_files("WoWSims Classic", APL_DIRS.classic)

  print("\nUsage: lua build_tools/analyze_wowsims_apl.lua <spec_name> [expansion]")
  print("  expansion: tbc (default) | classic")
  print("  e.g., lua build_tools/analyze_wowsims_apl.lua fury")
end
