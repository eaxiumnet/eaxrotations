-- menu_theme_sylvanas.lua — EAX Rotation menu theming, categorization & playstyle visibility.
-- WHAT:  class/playstyle/category colors, role + capability maps, playstyle-section scoping,
--        section-header formatting.
-- WHEN:  required by main.lua at menu init + render time; pure data + pure functions, no on_update allocs.
-- WHY:   gives the menu a consistent visual identity, colors per active playstyle, and lets sections
--        hide themselves when their playstyle is not active — without editing every class schema.
-- SAFETY: all color access is pcall/nil-guarded. No banned APIs. No per-frame table alloc.
-- DECISION: curated PLAYSTYLE_SECTIONS map avoids false-positive substring matching (e.g. "Optional
--           Shadow Spells" under Smite would wrongly match the "shadow" playstyle under aggressive matching).

local MenuTheme = {}

-- ---------------------------------------------------------------------------
-- Color module (lazy + guarded). require("common/color") exposes c.yellow(),
-- c.new(r,g,b,a), etc. If unavailable we degrade to a no-op table so the menu
-- still renders with plain (uncolored) headers.
-- ---------------------------------------------------------------------------
local _color
do
    local ok, c = pcall(require, "common/color")
    if ok and type(c) == "table" and type(c.new) == "function" then
        _color = c
    end
end

local function C(r, g, b, a)
    if _color and _color.new then
        local ok, col = pcall(_color.new, _color, r, g, b, a or 230)
        if ok and col then return col end
    end
    return nil -- caller falls back to a default (uncolored) header
end

-- ---------------------------------------------------------------------------
-- Signature colors per class (used by the title header accent).
-- ---------------------------------------------------------------------------
local CLASS_COLOR = {
    druid   = C(255, 175,  60),  -- orange
    hunter  = C(170, 210,  90),  -- olive green
    mage    = C(120, 185, 255),  -- arcane blue
    paladin = C(245, 200, 110),  -- gold
    priest  = C(255, 255, 255),  -- white
    rogue   = C(255, 190,  90),  -- tan
    shaman  = C( 60, 200, 200),  -- teal
    warlock = C(180, 110, 230),  -- purple
    warrior = C(200, 105,  90),  -- bronze-red
}

-- ---------------------------------------------------------------------------
-- Signature colors per playstyle key (per class). Falls back to class color.
-- ---------------------------------------------------------------------------
local PLAYSTYLE_COLOR = {
    -- Druid
    druid  = { leveling = C(170,150,120), balance = C(120,200,200), bear = C(170,120, 60),
              cat = C(150,210, 90), caster = C(110,160,220), resto = C( 90,210,120), },
    -- Hunter
    hunter = { leveling = C(170,150,120), beast_mastery = C(150,200, 90), marksmanship = C(230,210,110), survival = C(180,130, 70), },
    -- Mage
    mage   = { leveling = C(170,150,120), arcane = C(180,130,230), fire = C(230,110, 60), frost = C(110,200,235), },
    -- Paladin
    paladin= { leveling = C(170,150,120), holy = C(245,220,120), protection = C(120,160,220), retribution = C(220, 90, 80), },
    -- Priest
    priest = { leveling = C(170,150,120), discipline = C(150,150,240), holy = C(255,240,170), shadow = C(160,110,220), smite = C(230,150, 90), },
    -- Rogue
    rogue  = { leveling = C(170,150,120), assassination = C(160,120,220), combat = C(230,170, 80), subtlety = C(110,140,220), },
    -- Shaman
    shaman = { leveling = C(170,150,120), enhancement = C(220,120, 70), elemental = C( 90,150,235), restoration = C( 90,210,120), },
    -- Warlock
    warlock= { leveling = C(170,150,120), affliction = C(150,120,220), demonology = C( 90,190,180), destruction = C(230,110, 60), },
    -- Warrior
    warrior= { leveling = C(170,150,120), arms = C(220,110, 80), fury = C(210, 80, 70), kebab = C(230,180,110), protection = C(120,160,220), },
}

--- Signature color for the currently active playstyle (falls back to class color).
function MenuTheme.playstyle_color(class_key, playstyle)
    local by_ps = class_key and PLAYSTYLE_COLOR[class_key]
    if by_ps and playstyle and by_ps[playstyle] then return by_ps[playstyle] end
    if class_key and CLASS_COLOR[class_key] then return CLASS_COLOR[class_key] end
    return C(220, 220, 220) -- neutral fallback
end

--- Signature color for a class key.
function MenuTheme.class_color(class_key)
    if class_key and CLASS_COLOR[class_key] then return CLASS_COLOR[class_key] end
    return C(220, 220, 220)
end

-- ---------------------------------------------------------------------------
-- Role + capability per playstyle (drives Control Panel filtering).
--   healer → show Healing toggle, hide Threat Drop / Interrupts
--   tank   → show Threat Drop, hide Healing
--   dps    → show Threat Drop + Interrupts, hide Healing
--   hybrid → show everything (safest: leveling priest/druid/paladin/shaman/warrior)
-- ---------------------------------------------------------------------------
local PLAYSTYLE_ROLE = {
    druid   = { leveling = "hybrid", balance = "dps", bear = "tank", cat = "dps", caster = "dps", resto = "healer" },
    hunter  = { leveling = "dps",    beast_mastery = "dps", marksmanship = "dps", survival = "dps" },
    mage    = { leveling = "dps",    arcane = "dps", fire = "dps", frost = "dps" },
    paladin = { leveling = "hybrid", holy = "healer", protection = "tank", retribution = "dps" },
    priest  = { leveling = "hybrid", discipline = "healer", holy = "healer", shadow = "dps", smite = "dps" },
    rogue   = { leveling = "dps",    assassination = "dps", combat = "dps", subtlety = "dps" },
    shaman  = { leveling = "hybrid", enhancement = "dps", elemental = "dps", restoration = "healer" },
    warlock = { leveling = "dps",    affliction = "dps", demonology = "dps", destruction = "dps" },
    warrior = { leveling = "hybrid", arms = "dps", fury = "dps", kebab = "dps", protection = "tank" },
}

--- Returns the role string ("healer"|"tank"|"dps"|"hybrid") for a playstyle. Defaults to "dps".
function MenuTheme.role_for_playstyle(class_key, playstyle)
    local t = class_key and PLAYSTYLE_ROLE[class_key]
    if t and playstyle and t[playstyle] then return t[playstyle] end
    return "dps"
end

-- Which Control Panel toggles are relevant for a role.
local ROLE_CAPABILITIES = {
    -- auto_taunt: only relevant for tanks (and hybrids whose leveling spec may tank).
    -- Pure DPS specs (cat, balance, arms, ret, etc.) and healers never taunt.
    healer = { healing = true,  damage = true, cooldowns = true, aoe = true, interrupts = false, utility = true, threat_drop = false, auto_taunt = false },
    tank   = { healing = false, damage = true, cooldowns = true, aoe = true, interrupts = true,  utility = true, threat_drop = true,  auto_taunt = true  },
    dps    = { healing = false, damage = true, cooldowns = true, aoe = true, interrupts = true,  utility = true, threat_drop = true,  auto_taunt = false },
    hybrid = { healing = true,  damage = true, cooldowns = true, aoe = true, interrupts = true,  utility = true, threat_drop = true,  auto_taunt = true  },
}

--- capability table for a role. Each entry is bool "should this toggle be visible on the Control Panel".
function MenuTheme.capabilities(role)
    return (ROLE_CAPABILITIES[role] or ROLE_CAPABILITIES.hybrid) or ROLE_CAPABILITIES.hybrid
end

-- ---------------------------------------------------------------------------
-- Category color — derives a header color from the section header keywords.
-- Used so all "Defensives", "Cooldowns", "Utility"... sections share a palette.
-- ---------------------------------------------------------------------------
local function lower(s) return type(s) == "string" and s:lower() or "" end

function MenuTheme.category_color(header)
    local h = lower(header)
    -- order matters: most-specific keywords first
    if h:find("consumable", 1, true) or h:find("potion", 1, true) or h:find("flask", 1, true)
       or h:find("drum", 1, true) or h:find("healthstone", 1, true) or h:find("elixir", 1, true)
       or h:find("mana management", 1, true) or h:find("mana recovery", 1, true) then
        return C(230, 195, 90), "consumable"                                   -- gold
    end
    if h:find("interrupt", 1, true) or h:find("pummel", 1, true) or h:find("kick", 1, true)
       or h:find("silence", 1, true) then
        return C(230, 100, 100), "interrupt"                                    -- red
    end
    if h:find("threat", 1, true) or h:find("taunt", 1, true) then
        return C(200, 130,  90), "threat"                                       -- bronze
    end
    if h:find("defensive", 1, true) or h:find("survival", 1, true)
       or h:find("self healing", 1, true) or h:find("self survival", 1, true)
       or h:find("emergency", 1, true) then
        return C(235, 150,  60), "defensive"                                   -- orange
    end
    if h:find("cooldown", 1, true) or h:find("burst", 1, true) or h:find("burn", 1, true)
       or h:find("trinket", 1, true) then
        return C(180, 120, 230), "cooldown"                                    -- purple
    end
    if h:find("smart casting", 1, true) or h:find("healing threshold", 1, true)
       or h:find("shield target", 1, true) or h:find("aoe healing", 1, true)
       or h:find("healing priority", 1, true) then
        return C( 90, 210, 120), "smart"                                        -- green
    end
    if h:find("pvp", 1, true) or h:find("arena", 1, true) then
        return C(220,  80,  80), "pvp"                                          -- bright red
    end
    if h:find("leveling", 1, true) then
        return C(170, 150, 120), "leveling"                                     -- tan
    end
    if h:find("combat", 1, true) or h:find("rotation", 1, true)
       or h:find("core", 1, true) or h:find("seal", 1, true) then
        return nil, "rotation"                                                  -- nil => caller uses playstyle color
    end
    if h:find("utility", 1, true) or h:find("buff", 1, true) or h:find("curse", 1, true)
       or h:find("aspect", 1, true) or h:find("totem", 1, true) or h:find("aura", 1, true)
       or h:find("warrior weapon", 1, true) or h:find("pet", 1, true)
       or h:find("stone", 1, true) or h:find("weapon buff", 1, true) then
        return C( 90, 190, 220), "utility"                                      -- cyan
    end
    if h:find("mana", 1, true) then
        return C( 90, 150, 235), "mana"                                         -- blue
    end
    return C(210, 210, 210), "default"                                          -- light gray
end

-- ---------------------------------------------------------------------------
-- Section-header label formatting. Decorates the text with subtle ASCII
-- brackets so section groups are visually distinct even without pixel drawing.
-- ---------------------------------------------------------------------------
function MenuTheme.format_section_header(label)
    if type(label) ~= "string" or label == "" then return label or "" end
    if label:sub(1, 2) == "—" or label:sub(1, 1) == " " then return label end -- already decorated
    return "» " .. label
end

-- ---------------------------------------------------------------------------
-- Playstyle-section scope.
-- Tabs whose name matches a playstyle (normlised) are scoped to that playstyle.
-- Sections under shared tabs ("General"/"Consumables") may declare an explicit
-- `playstyles` array in the schema; otherwise the curated map below is used.
--
-- Curated map shape:  PLAYSTYLE_SECTIONS[class_key][header] = { "bear", ... }
--   A section with a nil/absent entry is ALWAYS shown.
-- ---------------------------------------------------------------------------
MenuTheme.PLAYSTYLE_SECTIONS = {
    druid = {
        ["Bear Tank"]                    = { "bear" },
        ["Cat (Feral DPS)"]              = { "cat" },
        ["Balance"]                      = { "balance" },
        ["Restoration"]                 = { "resto" },
        ["Restoration — Mana Conservation"] = { "resto" },
        ["Restoration — Solo DPS"]       = { "resto" },
        ["Smart Casting"]               = { "resto" },  -- druid: only resto is a healer spec
    },
    paladin = {
        ["Holy Healing"] = { "holy" },
        ["Holy Utility"] = { "holy" },
        ["Smart Casting"] = { "holy" },
    },
    priest = {
        -- spec-specific sections live under their own tabs; nothing curated here.
        ["Smart Casting"] = { "discipline", "holy" },
    },
    rogue = {
        ["Subtlety"] = { "subtlety" },
    },
    warrior = {
        ["Tactician (Arms)"] = { "arms" },
    },
}

-- Class pattern rules: a function(header_lower) -> {playstyle...} | nil.
-- Used for the shaman "Enhancement – ..." section family (many, prefix-based).
MenuTheme.CLASS_SECTION_RULES = {
    shaman = function(h)
        -- "Enhancement – X" sections belong to the enhancement playstyle only.
        if h:find("enhancement", 1, true) then return { "enhancement" } end
        return nil
    end,
}

--- Normalize a display string to match a playstyle key: lowercased, spaces→underscores.
local function normalize_name(s)
    s = lower(s)
    s = s:gsub("%s+", "_")
    s = s:gsub("[%(%)%-]", "_")
    s = s:gsub("_+", "_")
    s = s:gsub("^_", ""):gsub("_$", "")
    return s
end

--- Given a list of playstyle keys (current class) build a fast lookup.
--- Returns:  keys_set -> map for membership test;  norm_to_key for name matching.
function MenuTheme.build_playstyle_lookup(playstyle_keys, playstyle_display)
    local key_set = {}
    local norm_to_key = {}
    for i, key in ipairs(playstyle_keys or {}) do
        key_set[key] = true
        norm_to_key[normalize_name(key)] = key
        local disp = playstyle_display and playstyle_display[i]
        if disp then norm_to_key[normalize_name(disp)] = key end
    end
    return key_set, norm_to_key
end

--- Resolve the playstyle scope for a TAB by its name.
--- Returns a playstyle-key string (e.g. "bear") or nil (tab is shared/always shown).
function MenuTheme.tab_playscope(tab_name, norm_to_key)
    local n = normalize_name(tab_name)
    if n == "" then return nil end
    return norm_to_key[n]
end

--- Resolve the playstyle scope for a SECTION header (explicit schema field,
--- curated map, or class pattern rule). Returns {keys...} or nil (always shown).
function MenuTheme.section_playscope(class_key, header, explicit, key_set, class_rules)
    -- 1. explicit schema declaration wins
    if type(explicit) == "table" and #explicit > 0 then
        local out = {}
        for _, p in ipairs(explicit) do
            if not key_set or key_set[p] then out[#out + 1] = p end
        end
        if #out > 0 then return out end
    end
    -- 2. curated map
    local cur = class_key and MenuTheme.PLAYSTYLE_SECTIONS[class_key]
    if cur and cur[header] then
        local out, seen = {}, {}
        for _, p in ipairs(cur[header]) do
            if not seen[p] and (not key_set or key_set[p]) then
                seen[p] = true; out[#out + 1] = p
            end
        end
        if #out > 0 then return out end
    end
    -- 3. class pattern rule (e.g. shaman enhancement-* )
    if class_rules then
        local r = class_rules(lower(header))
        if r and #r > 0 then return r end
    end
    return nil
end

--- True if the section/tab scope admits the currently active playstyle.
--- scope == nil           → always shown
--- scope == {playstyles}  → shown iff active is in scope
function MenuTheme.scope_admits(scope, active)
    if not scope or #scope == 0 then return true end
    if not active then return true end -- unknown playstyle → show (safe default)
    for _, p in ipairs(scope) do
        if p == active then return true end
    end
    return false
end

return MenuTheme
