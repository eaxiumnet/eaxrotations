-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  EAX Class Identity System  v1.0                                        ║
-- ║  Defines per-class and per-spec visual identities for all TBC classes.  ║
-- ║  Strictly uses documented Project Sylvanas API only.                    ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

local identity = {}

local _color_api
local function c(r, g, b, a)
    if not _color_api then _color_api = require("common/color") end
    return _color_api.new(r, g, b, a or 255)
end

-- ── Class IDs (TBC class_id values) ─────────────────────────────────────────
-- These match enums.class_id in the API
identity.CLASS_IDS = {
    WARRIOR  = 1,
    PALADIN  = 2,
    HUNTER   = 3,
    ROGUE    = 4,
    PRIEST   = 5,
    SHAMAN   = 7,
    MAGE     = 8,
    WARLOCK  = 9,
    DRUID    = 11,
    DEATHKNIGHT = 6,  -- not in TBC but included for completeness
}

-- ── Spec IDs (TBC spec_id values used in plugin_info) ────────────────────────
identity.SPEC_IDS = {
    -- Warrior
    WARRIOR_ARMS      = 1,
    WARRIOR_FURY      = 2,
    WARRIOR_PROT      = 3,
    -- Paladin
    PALADIN_HOLY      = 4,
    PALADIN_PROT      = 5,
    PALADIN_RET       = 6,
    -- Hunter
    HUNTER_BM         = 7,
    HUNTER_MM         = 8,
    HUNTER_SV         = 9,
    -- Rogue
    ROGUE_ASSASSINATION = 10,
    ROGUE_COMBAT      = 11,
    ROGUE_SUBTLETY    = 12,
    -- Priest
    PRIEST_DISCIPLINE = 13,
    PRIEST_HOLY       = 14,
    PRIEST_SHADOW     = 15,
    -- Shaman
    SHAMAN_ELEMENTAL  = 16,
    SHAMAN_ENHANCE    = 17,
    SHAMAN_RESTO      = 18,
    -- Mage
    MAGE_ARCANE       = 19,
    MAGE_FIRE         = 20,
    MAGE_FROST        = 21,
    -- Warlock
    WARLOCK_AFFLICTION  = 22,
    WARLOCK_DEMONOLOGY  = 23,
    WARLOCK_DESTRUCTION = 24,
    -- Druid
    DRUID_BALANCE     = 25,
    DRUID_FERAL_CAT   = 26,
    DRUID_FERAL_BEAR  = 27,
    DRUID_RESTO       = 28,
}

-- ── Color palette per class ───────────────────────────────────────────────────
-- Each class has: panel, border_glow, border_dim, accent, accent_mid,
--                 text_on, text_off, star_rgb, dust_rgb, mood_label
--
-- Colors drawn from authentic WoW class colors + TBC fantasy moods.
local CLASS_PALETTES = {}

-- WARRIOR — Steel blue, iron, battle-hardened
CLASS_PALETTES[identity.CLASS_IDS.WARRIOR] = {
    panel       = function() return c( 10, 14, 22, 250) end,
    panel_deep  = function() return c(  6,  8, 14, 240) end,
    border_glow = function() return c(180, 210, 255, 210) end,
    border_dim  = function() return c( 60,  80, 130, 140) end,
    accent      = function() return c(199, 156, 110, 255) end, -- WoW warrior gold-brown
    accent_mid  = function() return c(160, 115,  70, 255) end,
    text_on     = function() return c(220, 200, 170, 255) end,
    text_off    = function() return c( 90,  80,  60, 200) end,
    star_r = 180, star_g = 200, star_b = 255,
    dust_r = 100, dust_g = 130, dust_b = 200,
    mood = "rage",
    label = "WARRIOR",
}

-- PALADIN — Holy gold, Light radiance, divine silver
CLASS_PALETTES[identity.CLASS_IDS.PALADIN] = {
    panel       = function() return c( 20, 16,  8, 252) end,
    panel_deep  = function() return c( 14, 10,  4, 242) end,
    border_glow = function() return c(245, 215,  80, 230) end,
    border_dim  = function() return c(140, 100,  20, 160) end,
    accent      = function() return c(255, 209, 101, 255) end, -- Authentic WoW paladin
    accent_mid  = function() return c(220, 170,  50, 255) end,
    text_on     = function() return c(255, 230, 140, 255) end,
    text_off    = function() return c(120, 90,  30, 200) end,
    star_r = 255, star_g = 230, star_b = 100,
    dust_r = 220, dust_g = 180, dust_b = 60,
    mood = "light",
    label = "PALADIN",
}

-- HUNTER — Forest green, earthy brown, wild spirit
CLASS_PALETTES[identity.CLASS_IDS.HUNTER] = {
    panel       = function() return c(  8, 18, 10, 252) end,
    panel_deep  = function() return c(  4, 10,  5, 242) end,
    border_glow = function() return c(170, 211, 114, 220) end,
    border_dim  = function() return c( 60,  90,  30, 150) end,
    accent      = function() return c(170, 211, 114, 255) end, -- WoW hunter green
    accent_mid  = function() return c(120, 165,  70, 255) end,
    text_on     = function() return c(200, 240, 160, 255) end,
    text_off    = function() return c( 70,  90,  40, 200) end,
    star_r = 140, star_g = 200, star_b = 100,
    dust_r = 80,  dust_g = 140, dust_b = 50,
    mood = "hunt",
    label = "HUNTER",
}

-- ROGUE — Dark shadows, poison yellow-green, obsidian
CLASS_PALETTES[identity.CLASS_IDS.ROGUE] = {
    panel       = function() return c(  8, 10,  8, 252) end,
    panel_deep  = function() return c(  4,  5,  4, 245) end,
    border_glow = function() return c(230, 220,  80, 200) end,
    border_dim  = function() return c( 80,  80,  15, 140) end,
    accent      = function() return c(255, 244,  104, 255) end, -- WoW rogue yellow
    accent_mid  = function() return c(200, 190,  60, 255) end,
    text_on     = function() return c(240, 230, 130, 255) end,
    text_off    = function() return c( 80,  75,  20, 200) end,
    star_r = 200, star_g = 190, star_b = 60,
    dust_r = 100, dust_g = 95,  dust_b = 20,
    mood = "shadow",
    label = "ROGUE",
}

-- PRIEST — Pure white-blue, holy light, shadow void
CLASS_PALETTES[identity.CLASS_IDS.PRIEST] = {
    panel       = function() return c( 14, 14, 20, 252) end,
    panel_deep  = function() return c(  8,  8, 14, 245) end,
    border_glow = function() return c(220, 220, 240, 220) end,
    border_dim  = function() return c( 80,  80, 120, 140) end,
    accent      = function() return c(220, 220, 255, 255) end, -- WoW priest white
    accent_mid  = function() return c(170, 170, 220, 255) end,
    text_on     = function() return c(240, 240, 255, 255) end,
    text_off    = function() return c( 90,  90, 130, 200) end,
    star_r = 200, star_g = 200, star_b = 255,
    dust_r = 120, dust_g = 120, dust_b = 200,
    mood = "holy",
    label = "PRIEST",
}

-- SHAMAN — Storm blue, lava orange, earth brown
CLASS_PALETTES[identity.CLASS_IDS.SHAMAN] = {
    panel       = function() return c(  6, 14, 22, 252) end,
    panel_deep  = function() return c(  3,  8, 14, 245) end,
    border_glow = function() return c(  0, 112, 222, 220) end,
    border_dim  = function() return c(  0,  50, 120, 140) end,
    accent      = function() return c(  0, 112, 222, 255) end, -- WoW shaman blue
    accent_mid  = function() return c(  0,  80, 175, 255) end,
    text_on     = function() return c( 80, 180, 255, 255) end,
    text_off    = function() return c( 20,  60, 110, 200) end,
    star_r = 40,  star_g = 130, star_b = 255,
    dust_r = 20,  dust_g = 80,  dust_b = 200,
    mood = "storm",
    label = "SHAMAN",
}

-- MAGE — Arcane cyan-blue, frost crystalline, fire ember
CLASS_PALETTES[identity.CLASS_IDS.MAGE] = {
    panel       = function() return c(  6, 16, 24, 252) end,
    panel_deep  = function() return c(  3, 10, 16, 245) end,
    border_glow = function() return c(105, 204, 240, 220) end,
    border_dim  = function() return c( 30,  90, 140, 140) end,
    accent      = function() return c(105, 204, 240, 255) end, -- WoW mage cyan
    accent_mid  = function() return c( 60, 160, 210, 255) end,
    text_on     = function() return c(160, 225, 255, 255) end,
    text_off    = function() return c( 40, 100, 150, 200) end,
    star_r = 80,  star_g = 190, star_b = 255,
    dust_r = 40,  dust_g = 120, dust_b = 210,
    mood = "arcane",
    label = "MAGE",
}

-- WARLOCK — Fel green-purple, shadow corruption, demonic
CLASS_PALETTES[identity.CLASS_IDS.WARLOCK] = {
    panel       = function() return c( 14,  8, 22, 252) end,
    panel_deep  = function() return c(  8,  4, 15, 245) end,
    border_glow = function() return c(148, 130, 201, 220) end,
    border_dim  = function() return c( 60,  40, 110, 140) end,
    accent      = function() return c(148, 130, 201, 255) end, -- WoW warlock purple
    accent_mid  = function() return c(100,  80, 160, 255) end,
    text_on     = function() return c(190, 170, 240, 255) end,
    text_off    = function() return c( 70,  55, 110, 200) end,
    star_r = 130, star_g = 100, star_b = 210,
    dust_r = 80,  dust_g = 50,  dust_b = 160,
    mood = "fel",
    label = "WARLOCK",
}

-- DRUID — Nature orange-yellow, moonkin celestial, shapeshifter
CLASS_PALETTES[identity.CLASS_IDS.DRUID] = {
    panel       = function() return c( 16,  9,  4, 252) end,
    panel_deep  = function() return c( 10,  5,  2, 240) end,
    border_glow = function() return c(255, 125,  10, 220) end,
    border_dim  = function() return c(120,  55,   5, 155) end,
    accent      = function() return c(255, 125,  10, 255) end, -- WoW druid orange
    accent_mid  = function() return c(210,  85,   5, 255) end,
    text_on     = function() return c(255, 175,  80, 255) end,
    text_off    = function() return c(115,  60,  12, 200) end,
    star_r = 230, star_g = 130, star_b = 30,
    dust_r = 180, dust_g = 80,  dust_b = 10,
    mood = "nature",
    label = "DRUID",
}

identity.CLASS_PALETTES = CLASS_PALETTES

-- Lightweight visual metadata used by class_theme.lua
local CLASS_VISUALS = {
    [identity.CLASS_IDS.WARRIOR] = { meteor_angle = -0.16, angle_variance = 0.06, speed = 260, speed_variance = 80, trail_style = "ember", trail_segments = 4, ember_rgb = { 255, 185, 120 }, ambient_intensity = 0.60 },
    [identity.CLASS_IDS.PALADIN] = { meteor_angle = -0.10, angle_variance = 0.04, speed = 210, speed_variance = 60, trail_style = "radiant", trail_segments = 5, ember_rgb = { 255, 245, 200 }, ambient_intensity = 0.72 },
    [identity.CLASS_IDS.HUNTER] = { meteor_angle = -0.20, angle_variance = 0.05, speed = 240, speed_variance = 70, trail_style = "wind", trail_segments = 4, ember_rgb = { 200, 240, 160 }, ambient_intensity = 0.52 },
    [identity.CLASS_IDS.ROGUE] = { meteor_angle = -0.24, angle_variance = 0.08, speed = 280, speed_variance = 90, trail_style = "shadow", trail_segments = 6, ember_rgb = { 220, 210, 120 }, ambient_intensity = 0.42 },
    [identity.CLASS_IDS.PRIEST] = { meteor_angle = -0.08, angle_variance = 0.03, speed = 200, speed_variance = 55, trail_style = "aura", trail_segments = 5, ember_rgb = { 240, 240, 255 }, ambient_intensity = 0.70 },
    [identity.CLASS_IDS.SHAMAN] = { meteor_angle = -0.18, angle_variance = 0.10, speed = 290, speed_variance = 110, trail_style = "storm", trail_segments = 6, ember_rgb = { 140, 220, 255 }, ambient_intensity = 0.78 },
    [identity.CLASS_IDS.MAGE] = { meteor_angle = -0.14, angle_variance = 0.05, speed = 310, speed_variance = 120, trail_style = "arcane", trail_segments = 6, ember_rgb = { 180, 240, 255 }, ambient_intensity = 0.68 },
    [identity.CLASS_IDS.WARLOCK] = { meteor_angle = -0.28, angle_variance = 0.09, speed = 260, speed_variance = 85, trail_style = "fel", trail_segments = 7, ember_rgb = { 200, 150, 255 }, ambient_intensity = 0.64 },
    [identity.CLASS_IDS.DRUID] = { meteor_angle = -0.17, angle_variance = 0.06, speed = 230, speed_variance = 65, trail_style = "nature", trail_segments = 5, ember_rgb = { 255, 190, 90 }, ambient_intensity = 0.62 },
}

local function _apply_visuals()
    for class_id, palette in pairs(CLASS_PALETTES) do
        palette.visual = CLASS_VISUALS[class_id] or CLASS_VISUALS[identity.CLASS_IDS.WARRIOR]
    end
end

_apply_visuals()


-- ── Spec accent overlays ──────────────────────────────────────────────────────
-- Spec accents add a SECONDARY highlight color on top of the class palette.
-- They control: proc highlights, ability group borders, active-spell glow.
local SPEC_ACCENTS = {}

-- DRUID specs
SPEC_ACCENTS[identity.SPEC_IDS.DRUID_FERAL_CAT] = {
    primary   = function() return c(230, 140,  40, 255) end,  -- cat orange
    secondary = function() return c(255, 220,  80, 255) end,  -- tiger gold
    tertiary  = function() return c(200,  80,  10, 200) end,  -- blood red
    group_label = "Cat Form",
    energy_col  = function() return c(230, 185,  20, 255) end,
    resource    = "ENERGY",
    icon_hint   = "ability_druid_catform",
}
SPEC_ACCENTS[identity.SPEC_IDS.DRUID_FERAL_BEAR] = {
    primary   = function() return c( 80, 145, 210, 255) end,  -- bear blue
    secondary = function() return c(130, 195, 255, 255) end,  -- frost
    tertiary  = function() return c( 50,  90, 170, 200) end,  -- deep blue
    group_label = "Bear Form",
    energy_col  = function() return c(200, 80,  20, 255) end, -- rage red
    resource    = "RAGE",
    icon_hint   = "ability_racial_bearform",
}
SPEC_ACCENTS[identity.SPEC_IDS.DRUID_BALANCE] = {
    primary   = function() return c(100, 60, 200, 255) end,   -- astral purple
    secondary = function() return c(180, 140, 255, 255) end,  -- moonfire
    tertiary  = function() return c(60, 180, 100, 200) end,   -- nature teal
    group_label = "Balance",
    energy_col  = function() return c(80, 160, 255, 255) end, -- mana blue
    resource    = "MANA",
    icon_hint   = "spell_nature_starfall",
}
SPEC_ACCENTS[identity.SPEC_IDS.DRUID_RESTO] = {
    primary   = function() return c( 80, 220, 120, 255) end,  -- heal green
    secondary = function() return c(160, 255, 180, 255) end,  -- rejuv mint
    tertiary  = function() return c( 40, 160,  60, 200) end,  -- deep emerald
    group_label = "Restoration",
    energy_col  = function() return c(80, 160, 255, 255) end,
    resource    = "MANA",
    icon_hint   = "spell_nature_healingtouch",
}

-- WARRIOR specs
SPEC_ACCENTS[identity.SPEC_IDS.WARRIOR_ARMS] = {
    primary   = function() return c(200, 160,  80, 255) end,  -- steel gold
    secondary = function() return c(230, 210, 140, 255) end,
    tertiary  = function() return c(160, 100,  40, 200) end,
    group_label = "Arms",
    energy_col  = function() return c(220, 80,  60, 255) end,
    resource    = "RAGE",
    icon_hint   = "ability_warrior_savageblow",
}
SPEC_ACCENTS[identity.SPEC_IDS.WARRIOR_FURY] = {
    primary   = function() return c(220,  60,  50, 255) end,  -- fury red
    secondary = function() return c(255, 120,  90, 255) end,
    tertiary  = function() return c(160,  30,  20, 200) end,
    group_label = "Fury",
    energy_col  = function() return c(220, 80,  60, 255) end,
    resource    = "RAGE",
    icon_hint   = "ability_warrior_innerrage",
}
SPEC_ACCENTS[identity.SPEC_IDS.WARRIOR_PROT] = {
    primary   = function() return c(100, 150, 220, 255) end,  -- shield blue
    secondary = function() return c(160, 200, 255, 255) end,
    tertiary  = function() return c( 60,  90, 160, 200) end,
    group_label = "Protection",
    energy_col  = function() return c(220, 80,  60, 255) end,
    resource    = "RAGE",
    icon_hint   = "ability_warrior_defensivestance",
}

-- PALADIN specs
SPEC_ACCENTS[identity.SPEC_IDS.PALADIN_HOLY] = {
    primary   = function() return c(255, 230, 130, 255) end,  -- holy gold
    secondary = function() return c(255, 255, 200, 255) end,
    tertiary  = function() return c(200, 160,  60, 200) end,
    group_label = "Holy",
    energy_col  = function() return c(80, 140, 255, 255) end,
    resource    = "MANA",
    icon_hint   = "spell_holy_holybolt",
}
SPEC_ACCENTS[identity.SPEC_IDS.PALADIN_PROT] = {
    primary   = function() return c(100, 160, 220, 255) end,
    secondary = function() return c(160, 210, 255, 255) end,
    tertiary  = function() return c( 60, 100, 160, 200) end,
    group_label = "Protection",
    energy_col  = function() return c(80, 140, 255, 255) end,
    resource    = "MANA",
    icon_hint   = "spell_holy_devotionaura",
}
SPEC_ACCENTS[identity.SPEC_IDS.PALADIN_RET] = {
    primary   = function() return c(255, 160,  60, 255) end,  -- ret orange
    secondary = function() return c(255, 210, 120, 255) end,
    tertiary  = function() return c(200,  90,  20, 200) end,
    group_label = "Retribution",
    energy_col  = function() return c(80, 140, 255, 255) end,
    resource    = "MANA",
    icon_hint   = "spell_holy_auraoflight",
}

-- HUNTER specs
SPEC_ACCENTS[identity.SPEC_IDS.HUNTER_BM] = {
    primary   = function() return c(180, 220, 100, 255) end,
    secondary = function() return c(220, 255, 160, 255) end,
    tertiary  = function() return c(100, 160,  50, 200) end,
    group_label = "Beast Mastery",
    energy_col  = function() return c(80, 160, 255, 255) end,
    resource    = "MANA",
    icon_hint   = "ability_hunter_beasttaming",
}
SPEC_ACCENTS[identity.SPEC_IDS.HUNTER_MM] = {
    primary   = function() return c(160, 200, 100, 255) end,
    secondary = function() return c(200, 240, 150, 255) end,
    tertiary  = function() return c( 90, 145,  50, 200) end,
    group_label = "Marksmanship",
    energy_col  = function() return c(80, 160, 255, 255) end,
    resource    = "MANA",
    icon_hint   = "ability_marksmanship",
}
SPEC_ACCENTS[identity.SPEC_IDS.HUNTER_SV] = {
    primary   = function() return c(120, 175,  80, 255) end,
    secondary = function() return c(170, 220, 120, 255) end,
    tertiary  = function() return c( 70, 120,  40, 200) end,
    group_label = "Survival",
    energy_col  = function() return c(80, 160, 255, 255) end,
    resource    = "MANA",
    icon_hint   = "ability_hunter_harass",
}

-- ROGUE specs
SPEC_ACCENTS[identity.SPEC_IDS.ROGUE_ASSASSINATION] = {
    primary   = function() return c(80, 220, 100, 255) end,   -- poison green
    secondary = function() return c(140, 255, 150, 255) end,
    tertiary  = function() return c( 40, 140,  50, 200) end,
    group_label = "Assassination",
    energy_col  = function() return c(255, 220, 60, 255) end,
    resource    = "ENERGY",
    icon_hint   = "ability_rogue_shadowstrikes",
}
SPEC_ACCENTS[identity.SPEC_IDS.ROGUE_COMBAT] = {
    primary   = function() return c(220, 160,  60, 255) end,
    secondary = function() return c(255, 200, 100, 255) end,
    tertiary  = function() return c(160,  90,  20, 200) end,
    group_label = "Combat",
    energy_col  = function() return c(255, 220, 60, 255) end,
    resource    = "ENERGY",
    icon_hint   = "ability_backstab",
}
SPEC_ACCENTS[identity.SPEC_IDS.ROGUE_SUBTLETY] = {
    primary   = function() return c(140,  80, 200, 255) end,  -- shadow purple
    secondary = function() return c(190, 140, 255, 255) end,
    tertiary  = function() return c( 80,  40, 140, 200) end,
    group_label = "Subtlety",
    energy_col  = function() return c(255, 220, 60, 255) end,
    resource    = "ENERGY",
    icon_hint   = "ability_stealth",
}

-- PRIEST specs
SPEC_ACCENTS[identity.SPEC_IDS.PRIEST_DISCIPLINE] = {
    primary   = function() return c(200, 200, 255, 255) end,
    secondary = function() return c(230, 230, 255, 255) end,
    tertiary  = function() return c(120, 120, 210, 200) end,
    group_label = "Discipline",
    energy_col  = function() return c(80, 140, 255, 255) end,
    resource    = "MANA",
    icon_hint   = "spell_holy_powerwordshield",
}
SPEC_ACCENTS[identity.SPEC_IDS.PRIEST_HOLY] = {
    primary   = function() return c(255, 240, 180, 255) end,  -- holy glow
    secondary = function() return c(255, 255, 220, 255) end,
    tertiary  = function() return c(200, 180, 100, 200) end,
    group_label = "Holy",
    energy_col  = function() return c(80, 140, 255, 255) end,
    resource    = "MANA",
    icon_hint   = "spell_holy_guardianspirit",
}
SPEC_ACCENTS[identity.SPEC_IDS.PRIEST_SHADOW] = {
    primary   = function() return c(140,  60, 200, 255) end,  -- void purple
    secondary = function() return c(200, 120, 255, 255) end,
    tertiary  = function() return c( 80,  20, 130, 200) end,
    group_label = "Shadow",
    energy_col  = function() return c(80, 140, 255, 255) end,
    resource    = "MANA",
    icon_hint   = "spell_shadow_shadowwordpain",
}

-- SHAMAN specs
SPEC_ACCENTS[identity.SPEC_IDS.SHAMAN_ELEMENTAL] = {
    primary   = function() return c( 60, 140, 255, 255) end,  -- lightning
    secondary = function() return c(120, 200, 255, 255) end,
    tertiary  = function() return c( 20,  80, 200, 200) end,
    group_label = "Elemental",
    energy_col  = function() return c(80, 140, 255, 255) end,
    resource    = "MANA",
    icon_hint   = "spell_nature_lightning",
}
SPEC_ACCENTS[identity.SPEC_IDS.SHAMAN_ENHANCE] = {
    primary   = function() return c(255, 130,  40, 255) end,  -- lava orange
    secondary = function() return c(255, 190, 100, 255) end,
    tertiary  = function() return c(180,  60,  10, 200) end,
    group_label = "Enhancement",
    energy_col  = function() return c(80, 140, 255, 255) end,
    resource    = "MANA",
    icon_hint   = "spell_shaman_improvedstormstrike",
}
SPEC_ACCENTS[identity.SPEC_IDS.SHAMAN_RESTO] = {
    primary   = function() return c( 60, 200, 160, 255) end,  -- healing teal
    secondary = function() return c(120, 240, 200, 255) end,
    tertiary  = function() return c( 20, 130, 100, 200) end,
    group_label = "Restoration",
    energy_col  = function() return c(80, 140, 255, 255) end,
    resource    = "MANA",
    icon_hint   = "spell_nature_magicimmunity",
}

-- MAGE specs
SPEC_ACCENTS[identity.SPEC_IDS.MAGE_ARCANE] = {
    primary   = function() return c(120,  80, 255, 255) end,  -- arcane violet
    secondary = function() return c(180, 140, 255, 255) end,
    tertiary  = function() return c( 70,  30, 190, 200) end,
    group_label = "Arcane",
    energy_col  = function() return c(80, 140, 255, 255) end,
    resource    = "MANA",
    icon_hint   = "spell_holy_magicalsentry",
}
SPEC_ACCENTS[identity.SPEC_IDS.MAGE_FIRE] = {
    primary   = function() return c(255,  80,  20, 255) end,  -- fire red-orange
    secondary = function() return c(255, 160,  60, 255) end,
    tertiary  = function() return c(190,  30,   5, 200) end,
    group_label = "Fire",
    energy_col  = function() return c(80, 140, 255, 255) end,
    resource    = "MANA",
    icon_hint   = "spell_fire_fireball",
}
SPEC_ACCENTS[identity.SPEC_IDS.MAGE_FROST] = {
    primary   = function() return c( 60, 200, 255, 255) end,  -- frost blue
    secondary = function() return c(160, 230, 255, 255) end,
    tertiary  = function() return c( 20, 130, 210, 200) end,
    group_label = "Frost",
    energy_col  = function() return c(80, 140, 255, 255) end,
    resource    = "MANA",
    icon_hint   = "spell_frost_frostbolt02",
}

-- WARLOCK specs
SPEC_ACCENTS[identity.SPEC_IDS.WARLOCK_AFFLICTION] = {
    primary   = function() return c(120, 200,  80, 255) end,  -- fel corruption green
    secondary = function() return c(180, 255, 130, 255) end,
    tertiary  = function() return c( 60, 130,  30, 200) end,
    group_label = "Affliction",
    energy_col  = function() return c(80, 140, 255, 255) end,
    resource    = "MANA",
    icon_hint   = "spell_shadow_curseofachimonde",
}
SPEC_ACCENTS[identity.SPEC_IDS.WARLOCK_DEMONOLOGY] = {
    primary   = function() return c(180, 100, 240, 255) end,  -- demonic purple
    secondary = function() return c(220, 160, 255, 255) end,
    tertiary  = function() return c(110,  40, 170, 200) end,
    group_label = "Demonology",
    energy_col  = function() return c(80, 140, 255, 255) end,
    resource    = "MANA",
    icon_hint   = "spell_shadow_metamorphosis",
}
SPEC_ACCENTS[identity.SPEC_IDS.WARLOCK_DESTRUCTION] = {
    primary   = function() return c(255,  60,  40, 255) end,  -- hellfire red
    secondary = function() return c(255, 130,  80, 255) end,
    tertiary  = function() return c(180,  20,   5, 200) end,
    group_label = "Destruction",
    energy_col  = function() return c(80, 140, 255, 255) end,
    resource    = "MANA",
    icon_hint   = "spell_shadow_rainoffire",
}

identity.SPEC_ACCENTS = SPEC_ACCENTS

-- ── Spec ability groups ───────────────────────────────────────────────────────
-- Maps spec_id -> ordered list of ability group definitions
-- Each group: { label, role, spells = { "SpellName", ... }, priority }
identity.SPEC_ABILITY_GROUPS = {}

-- Feral Cat ability groups
identity.SPEC_ABILITY_GROUPS[identity.SPEC_IDS.DRUID_FERAL_CAT] = {
    { label = "Opener",   role = "opener",   priority = 1,
      spells = { "Pounce", "Ravage", "Prowl" } },
    { label = "Builders", role = "builder",  priority = 2,
      spells = { "Mangle (Cat)", "Shred", "Rake", "Claw" } },
    { label = "Finishers",role = "finisher", priority = 3,
      spells = { "Rip", "Ferocious Bite", "Maim" } },
    { label = "Cooldowns",role = "cooldown", priority = 4,
      spells = { "Tiger's Fury", "Berserk", "Feral Charge" } },
    { label = "Utility",  role = "utility",  priority = 5,
      spells = { "Faerie Fire (Feral)", "Barkskin", "Dash" } },
}

-- Feral Bear ability groups
identity.SPEC_ABILITY_GROUPS[identity.SPEC_IDS.DRUID_FERAL_BEAR] = {
    { label = "Threat",   role = "builder",  priority = 1,
      spells = { "Mangle (Bear)", "Lacerate", "Maul", "Swipe" } },
    { label = "Debuffs",  role = "finisher", priority = 2,
      spells = { "Faerie Fire (Feral)", "Demoralizing Roar", "Growl" } },
    { label = "Cooldowns",role = "cooldown", priority = 3,
      spells = { "Frenzied Regeneration", "Berserk", "Enrage" } },
    { label = "Utility",  role = "utility",  priority = 4,
      spells = { "Bash", "Feral Charge", "Challenging Roar" } },
}

-- ── Lookup helpers ────────────────────────────────────────────────────────────

-- Return the class palette for a given class_id (or default to warrior)
function identity.get_class_palette(class_id)
    return CLASS_PALETTES[class_id] or CLASS_PALETTES[identity.CLASS_IDS.WARRIOR]
end

function identity.get_class_visuals(class_id)
    return (identity.get_class_palette(class_id) or {}).visual
end

-- Return the spec accent for a given spec_id (or nil)
function identity.get_spec_accent(spec_id)
    return SPEC_ACCENTS[spec_id]
end

-- Return ability groups for a spec_id (or empty table)
function identity.get_ability_groups(spec_id)
    return identity.SPEC_ABILITY_GROUPS[spec_id] or {}
end

-- Detect current class_id from the local player using core API
function identity.detect_class_id()
    local ok, ui_init = pcall(require, "class_ui_init")
    if ok and ui_init and ui_init.class_id then return ui_init.class_id end
    return nil
end

-- Mood flavor text used in panel headers
identity.MOOD_LABELS = {
    rage    = "⚔ Fury of Battle",
    light   = "✦ Blessed by the Light",
    hunt    = "◈ Hunter's Focus",
    shadow  = "◆ From the Shadows",
    holy    = "✧ Channel of the Light",
    storm   = "⚡ Call of the Storm",
    arcane  = "∞ Weave of Arcana",
    fel     = "◉ Pact with Darkness",
    nature  = "❧ One with Nature",
}

return identity
