-- =============================================================================
-- Eax's Fishing - Constants
-- =============================================================================
-- ARCHITECTURE NOTE:
-- Fishing spell resolution has been moved from hardcoded spell IDs to dynamic
-- detection via the core spell book system. The API surface layer now uses
-- core.spell_book.is_spell_learned() to determine which fishing spell the
-- player has learned (e.g., Fishing 1-75, Master Fishing).
--
-- This approach eliminates the need for hardcoded spell ID lookups and allows
-- the addon to automatically adapt to any fishing skill the player possesses.
-- The FISHING_RANKS table below is kept for reference/legacy purposes but
-- actual spell resolution is handled by APISurface.resolve_fishing_spell().
-- =============================================================================

local constants = {}

constants.SPELLS = {
    FISHING_ID = 13147,
    -- NOTE: This table is consumed by api_surface.resolve_fishing_spell()
    -- which uses core.spell_book.is_spell_learned() to dynamically determine
    -- which fishing spell the player has learned. The order matters - higher
    -- skill ranks should come first so they're preferred when multiple are known.
    FISHING_RANKS = { 13147, 7620, 7731, 7732, 18248, 33095 },
}

constants.ITEMS = {
    FISHING_POLE = 6256,
    FISHING_POLES = {
        19970, -- Arcanite Fishing Pole        (+40)
        34077, -- Jeweled Fishing Pole          (+35, TBC)
        19022, -- Nat Pagle's Extreme Angler   (+25)
        25978, -- Seth's Graphite Fishing Pole  (+20)
        12225, -- Blump Family Fishing Pole     (+20)
        6367,  -- Big Iron Fishing Pole         (+20)
        6366,  -- Darkwood Fishing Pole         (+15)
        6365,  -- Strong Fishing Pole           (+5)
        6256,  -- Fishing Pole
    },
    SHINY_BAUBLE = 6529,
    LURES = {
        { id = 6533,  name = "Aquadynamic Fish Attractor", bonus = 100 },
        { id = 34861, name = "Sharpened Fish Hook",         bonus = 100 },
        { id = 6532,  name = "Bright Baubles",              bonus = 75  },
        { id = 6811,  name = "Aquadynamic Fish Lens",       bonus = 50  },
        { id = 6530,  name = "Nightcrawlers",               bonus = 50  },
        { id = 6529,  name = "Shiny Bauble",                bonus = 25  },
    }
}

constants.OBJECTS = {
    BOBBER_NAME = "Fishing Bobber",
    POOLS = {
        ["Floating Wreckage"] = true,
        ["School of Tastyfish"] = true,
        ["School of Deviate Fish"] = true,
        ["Oily Blackmouth School"] = true,
        ["Firefin Snapper School"] = true,
        ["School of Sagefish"] = true,
        ["Greater Sagefish School"] = true,
        ["Stonescale Eel Swarm"] = true,
        ["School of Spotted Feltail"] = true,
        ["School of Darter"] = true,
        ["School of Highland Mixed Fish"] = true,
        ["Steam Pump Flotsam"] = true,
        ["School of Sporefish"] = true,
        ["Mudfish School"] = true,
        ["Bluefish School"] = true,
        ["School of Goldenscale Vendorfish"] = true,
        ["Borean Man O' War School"] = true,
        ["Deep Sea Monsterbelly School"] = true,
        ["Dragonfin Angelfish School"] = true,
        ["Fangtooth Herring School"] = true,
        ["Glacial Salmon School"] = true,
        ["Glassfin Minnow School"] = true,
        ["Imperial Manta Ray School"] = true,
        ["Moonglow Cuttlefish School"] = true,
        ["Musselback Sculpin School"] = true,
        ["Nettlefish School"] = true,
        ["Pygmy Suckerfish School"] = true,
        ["Highland Guppy School"] = true,
        ["Mountain Trout School"] = true,
        ["Deepsea Sagefish School"] = true,
        ["Fathom Eel Swarm"] = true,
        ["Blackbelly Mudfish School"] = true,
        ["Shipwreck Debris"] = true,
        ["Pool of Volatile Fire"] = true,
        ["Reef Octopus Swarm"] = true,
        ["Waterlogged Wreckage"] = true,
        ["Bloodsail Wreckage"] = true,
        ["Schooner Wreckage"] = true,
        ["Patch of Elemental Water"] = true,
        ["Sparse Schooner Wreckage"] = true,
        ["Scanty Bloodsail Wreckage"] = true,
        ["Golden Carp School"] = true,
        ["Emperor Salmon School"] = true,
        ["Jade Lungfish School"] = true,
        ["Krasarang Paddlefish School"] = true,
        ["Redbelly Mandarin School"] = true,
        ["Giant Mantis Shrimp Swarm"] = true,
        ["Tiger Gourami School"] = true,
        ["Spinefish School"] = true,
        ["Abyssal Gulper School"] = true,
        ["Blackwater Whiptail School"] = true,
        ["Blind Lake Sturgeon School"] = true,
        ["Fire Ammonite School"] = true,
        ["Fat Sleeper School"] = true,
        ["Jawless Skulker School"] = true,
        ["Sea Scorpion Swarm"] = true,
        ["Black Barracuda School"] = true,
        ["Cursed Queenfish School"] = true,
        ["Highmountain Salmon School"] = true,
        ["Mossgill Perch School"] = true,
        ["Runescale Koi School"] = true,
        ["Stormray School"] = true,
        ["Ancient Vrykul Ring"] = true,
        ["Oodelfjisk Pool"] = true,
        ["Leyshimmer Blenny Pool"] = true,
        ["Great Sea Catfish School"] = true,
        ["Lane Snapper School"] = true,
        ["Sand Shifter School"] = true,
        ["Slimy Mackerel School"] = true,
        ["Tiragarde Perch School"] = true,
        ["Frenzied Fangtooth School"] = true,
        ["Midnight Salmon Pool"] = true,
        ["Abyssal Focus"] = true,
        ["Elysian Thade School"] = true,
        ["Lost Sole School"] = true,
        ["Pocked Bonefish School"] = true,
        ["Silvergill Pike School"] = true,
        ["Iridescent Amberjack School"] = true,
        ["Temporal Dragonhead School"] = true,
        ["Cerulean Spinefish School"] = true,
        ["Aileron Seamoth School"] = true,
        ["Islefin Dorado School"] = true,
        ["Prismatic Leaper School"] = true,
        ["Thousandbite Piranha School"] = true,
        ["Frosted Rimefin Tuna Pool"] = true,
        ["Magma Thresher Pool"] = true,
        ["Shimmering Treasure Pool"] = true,
        ["River Mouth Fishing Hole"] = true,
        ["Glimmerpool"] = true,
        ["Blood in the Water"] = true,
        ["Bloody Perch Swarm"] = true,
        ["Calm Surfacing Ripple"] = true,
        ["Festering Rotpool"] = true,
        ["Swarm of Slum Sharks"] = true,
        ["Infused Ichor Spill"] = true,
        ["River Bass Pool"] = true,
        ["Anglerseeker Torrent"] = true,
        ["Stargazer Swarm"] = true,
        ["Royal Ripple"] = true,
    }
}

return constants
