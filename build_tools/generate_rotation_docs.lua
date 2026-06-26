-- generate_rotation_docs.lua — Generate per-class rotation README.md files.
-- WHAT:  reads spec files + scorecard data, outputs per-class rotation guides.
-- WHEN:  run after spec changes or scorecard updates.
-- WHY:   gives users readable rotation docs shipped with every release.
-- USAGE: cd repo_root && lua build_tools/generate_rotation_docs.lua

local SPECS = {
  warrior = {
    { spec = "arms",         tbc = "classes/warrior/arms_sylvanas.lua",       vanilla = "classes/warrior/arms_vanilla.lua" },
    { spec = "fury",         tbc = "classes/warrior/fury_sylvanas.lua",       vanilla = "classes/warrior/fury_vanilla.lua" },
    { spec = "protection",   tbc = "classes/warrior/protection_sylvanas.lua", vanilla = "classes/warrior/protection_vanilla.lua" },
    { spec = "kebab",        tbc = "classes/warrior/kebab_sylvanas.lua",      vanilla = "classes/warrior/kebab_vanilla.lua" },
  },
  hunter = {
    { spec = "beast_mastery", tbc = "classes/hunter/beast_mastery_sylvanas.lua", vanilla = "classes/hunter/beast_mastery_vanilla.lua" },
    { spec = "marksmanship",  tbc = "classes/hunter/marksmanship_sylvanas.lua",  vanilla = "classes/hunter/marksmanship_vanilla.lua" },
    { spec = "survival",      tbc = "classes/hunter/survival_sylvanas.lua",      vanilla = "classes/hunter/survival_vanilla.lua" },
  },
  mage = {
    { spec = "arcane", tbc = "classes/mage/arcane_sylvanas.lua", vanilla = "classes/mage/arcane_vanilla.lua" },
    { spec = "fire",   tbc = "classes/mage/fire_sylvanas.lua",   vanilla = "classes/mage/fire_vanilla.lua" },
    { spec = "frost",  tbc = "classes/mage/frost_sylvanas.lua",  vanilla = "classes/mage/frost_vanilla.lua" },
  },
  paladin = {
    { spec = "holy",        tbc = "classes/paladin/holy_sylvanas.lua",        vanilla = "classes/paladin/holy_vanilla.lua" },
    { spec = "protection",  tbc = "classes/paladin/protection_sylvanas.lua",  vanilla = "classes/paladin/protection_vanilla.lua" },
    { spec = "retribution", tbc = "classes/paladin/retribution_sylvanas.lua", vanilla = "classes/paladin/retribution_vanilla.lua" },
  },
  priest = {
    { spec = "discipline", tbc = "classes/priest/discipline_sylvanas.lua", vanilla = "classes/priest/discipline_vanilla.lua" },
    { spec = "holy",       tbc = "classes/priest/holy_sylvanas.lua",       vanilla = "classes/priest/holy_vanilla.lua" },
    { spec = "shadow",     tbc = "classes/priest/shadow_sylvanas.lua",     vanilla = "classes/priest/shadow_vanilla.lua" },
    { spec = "smite",      tbc = "classes/priest/smite_sylvanas.lua",      vanilla = "classes/priest/smite_vanilla.lua" },
  },
  rogue = {
    { spec = "assassination", tbc = "classes/rogue/assassination_sylvanas.lua", vanilla = "classes/rogue/assassination_vanilla.lua" },
    { spec = "combat",       tbc = "classes/rogue/combat_sylvanas.lua",       vanilla = "classes/rogue/combat_vanilla.lua" },
    { spec = "subtlety",     tbc = "classes/rogue/subtlety_sylvanas.lua",     vanilla = "classes/rogue/subtlety_vanilla.lua" },
  },
  shaman = {
    { spec = "elemental",    tbc = "classes/shaman/elemental_sylvanas.lua",    vanilla = "classes/shaman/elemental_vanilla.lua" },
    { spec = "enhancement",  tbc = "classes/shaman/enhancement_sylvanas.lua",  vanilla = "classes/shaman/enhancement_vanilla.lua" },
    { spec = "restoration",  tbc = "classes/shaman/restoration_sylvanas.lua",  vanilla = "classes/shaman/restoration_vanilla.lua" },
  },
  druid = {
    { spec = "balance",     tbc = "classes/druid/balance_sylvanas.lua",     vanilla = "classes/druid/balance_vanilla.lua" },
    { spec = "bear",        tbc = "classes/druid/bear_sylvanas.lua",        vanilla = "classes/druid/bear_vanilla.lua" },
    { spec = "cat",         tbc = "classes/druid/cat_sylvanas.lua",         vanilla = "classes/druid/cat_vanilla.lua" },
    { spec = "resto",       tbc = "classes/druid/resto_sylvanas.lua",       vanilla = "classes/druid/resto_vanilla.lua" },
  },
  warlock = {
    { spec = "affliction",  tbc = "classes/warlock/affliction_sylvanas.lua",  vanilla = "classes/warlock/affliction_vanilla.lua" },
    { spec = "demonology",  tbc = "classes/warlock/demonology_sylvanas.lua",  vanilla = "classes/warlock/demonology_vanilla.lua" },
    { spec = "destruction", tbc = "classes/warlock/destruction_sylvanas.lua", vanilla = "classes/warlock/destruction_vanilla.lua" },
  },
}

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local c = f:read("*a")
  f:close()
  return c
end

local function extract_strategies(content)
  local strats = {}
  for line in content:gmatch("[^\r\n]+") do
    local name = line:match('name%s*=%s*"([^"]+)"')
    if name and not name:match("^Unavailable") then
      strats[#strats + 1] = name
    end
  end
  return strats
end

local function extract_header_why(content)
  return content:match("%-%- WHY:%s*(.-)\n") or ""
end

local function has_feature(content, feature)
  local patterns = {
    defensive  = { "IceBarrier", "ManaShield", "ShieldWall", "DivineShield", "Barkskin", "PowerWordShield", "hp_pct", "health_percentage", "use_defensives" },
    interrupt  = { "Counterspell", "Kick", "Pummel", "Silence", "WindShear", "use_interrupt", "target_casting" },
    cooldown   = { "RapidFire", "ArcanePower", "PresenceOfMind", "DeathWish", "Recklessness", "AdrenalineRush", "gate_cooldown", "should_burst" },
    consumable = { "potion_helper", "HealthPotion", "ManaPotion", "healthstone", "ManaGem" },
    trinket    = { "Trinket", "trinket", "use_trinket" },
  }
  for _, p in ipairs(patterns[feature] or {}) do
    if content:find(p) then return true end
  end
  return false
end

local function content_gated(content, ctype)
  local patterns = {
    solo = { "is_solo", "not .*is_group" },
    dungeon = { "is_group", "enemy_count", "is_aoe" },
    raid = { "is_raid", "gate_cooldown_boss_only", "should_burst" },
    pvp = { "is_pvp", "arena", "burst_score" },
    leveling = { "is_leveling", "leveling" },
  }
  for _, p in ipairs(patterns[ctype] or {}) do
    if content:find(p) then return true end
  end
  return false
end

local function star(n) return ("★"):rep(n) .. ("☆"):rep(5 - n) end

local function human_spec(spec)
  return spec:gsub("_", " "):gsub("(%a)([%w_]*)", function(a, b) return a:upper() .. b end)
end

local function human_class(cls)
  return cls:gsub("^%l", string.upper)
end

-- Generate per-class doc
local function write_class_doc(class, specs)
  local out_dir = "docs/rotations"
  os.execute('mkdir "' .. out_dir .. '" 2>nul')
  local f = io.open(out_dir .. "/" .. class .. ".md", "w")
  if not f then return end

  f:write("# " .. human_class(class) .. " Rotations\n\n")
  f:write("> Auto-generated rotation guide for " .. human_class(class) .. ".\n\n")

  for _, entry in ipairs(specs) do
    local spec_name = entry.spec
    local h_spec = human_spec(spec_name)

    -- TBC
    local tbc_content = read_file("EaxRotations/" .. entry.tbc)
    if tbc_content then
      f:write("## " .. h_spec .. " (TBC)\n\n")
      local why = extract_header_why(tbc_content)
      if why ~= "" then f:write("**Why:** " .. why .. "\n\n") end

      local strats = extract_strategies(tbc_content)
      if #strats > 0 then
        f:write("### Priority Order\n\n")
        for i, s in ipairs(strats) do
          f:write(i .. ". " .. s .. "\n")
        end
        f:write("\n")
      end

      local feats = {}
      for _, feat in ipairs({"defensive", "interrupt", "cooldown", "consumable", "trinket"}) do
        if has_feature(tbc_content, feat) then feats[#feats + 1] = feat end
      end
      if #feats > 0 then
        f:write("### Features\n\n")
        for _, feat in ipairs(feats) do f:write("- " .. feat:gsub("^%l", string.upper) .. "\n") end
        f:write("\n")
      end

      local content_types = {}
      for _, ct in ipairs({"solo", "dungeon", "raid", "pvp", "leveling"}) do
        if content_gated(tbc_content, ct) then content_types[#content_types + 1] = ct end
      end
      if #content_types > 0 then
        f:write("### Content Types\n\n")
        f:write("Gated for: " .. table.concat(content_types, ", ") .. "\n\n")
      end
    end

    -- Vanilla
    local vanilla_content = read_file("EaxRotations/" .. entry.vanilla)
    if vanilla_content then
      f:write("## " .. h_spec .. " (Vanilla/Classic Era)\n\n")
      local why = extract_header_why(vanilla_content)
      if why ~= "" then f:write("**Why:** " .. why .. "\n\n") end

      local strats = extract_strategies(vanilla_content)
      if #strats > 0 then
        f:write("### Priority Order\n\n")
        for i, s in ipairs(strats) do
          f:write(i .. ". " .. s .. "\n")
        end
        f:write("\n")
      end

      local feats = {}
      for _, feat in ipairs({"defensive", "interrupt", "cooldown", "consumable", "trinket"}) do
        if has_feature(vanilla_content, feat) then feats[#feats + 1] = feat end
      end
      if #feats > 0 then
        f:write("### Features\n\n")
        for _, feat in ipairs(feats) do f:write("- " .. feat:gsub("^%l", string.upper) .. "\n") end
        f:write("\n")
      end

      local content_types = {}
      for _, ct in ipairs({"solo", "dungeon", "raid", "pvp", "leveling"}) do
        if content_gated(vanilla_content, ct) then content_types[#content_types + 1] = ct end
      end
      if #content_types > 0 then
        f:write("### Content Types\n\n")
        f:write("Gated for: " .. table.concat(content_types, ", ") .. "\n\n")
      end
    end
  end

  f:close()
  print("  Wrote docs/rotations/" .. class .. ".md")
end

-- Generate docs/rotations/README.md (index)
local function write_index()
  local f = io.open("docs/rotations/README.md", "w")
  if not f then return end

  f:write("# EAX Rotation Guides\n\n")
  f:write("> Per-class rotation documentation. Auto-generated from spec files.\n\n")
  f:write("Each guide lists: priority order, supported features, and content-type appropriateness.\n\n")
  f:write("## Classes\n\n")

  for class, specs in pairs(SPECS) do
    f:write("- [**" .. human_class(class) .. "**](./" .. class .. ".md) — " .. #specs .. " spec(s)\n")
  end

  f:write("\n---\n\n")
  f:write("*Generated by `build_tools/generate_rotation_docs.lua`*\n")
  f:close()
  print("  Wrote docs/rotations/README.md")
end

-- Main
print("Generating rotation docs...")
for class, specs in pairs(SPECS) do
  write_class_doc(class, specs)
end
write_index()
print("Done.")
