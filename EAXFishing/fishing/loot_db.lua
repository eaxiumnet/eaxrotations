-- =============================================================================
-- Eax's Fishing - Item Category Database
-- Used to categorise looted items for the session HUD.
-- Vendor prices are NOT included — TBC fish vendor for a few silver each,
-- and real value is AH-dependent. Only Goldenscale Vendorfish has a fixed
-- notable vendor price (6g) and is included as an exception.
-- =============================================================================

local M = {}

-- Quality constants
M.GRAY  = 1
M.WHITE = 2
M.GREEN = 3
M.BLUE  = 4

-- Category constants
M.CAT_FISH   = "fish"
M.CAT_GRAY   = "gray"
M.CAT_TRADE  = "trade"
M.CAT_OTHER  = "other"

-- [item_id] = { name, quality, cat, vendor_copper }
-- vendor_copper only set for items with notable/fixed vendor value
M.ITEMS = {
    -- ── Vanilla fish ──────────────────────────────────────────────────────
    [6291]  = { name="Raw Brilliant Smallfish",       quality=M.WHITE, cat=M.CAT_FISH },
    [6289]  = { name="Raw Longjaw Mud Snapper",       quality=M.WHITE, cat=M.CAT_FISH },
    [6308]  = { name="Raw Bristle Whisker Catfish",   quality=M.WHITE, cat=M.CAT_FISH },
    [6358]  = { name="Oily Blackmouth",               quality=M.WHITE, cat=M.CAT_FISH },
    [6359]  = { name="Firefin Snapper",               quality=M.WHITE, cat=M.CAT_FISH },
    [6361]  = { name="Raw Rainbow Fin Albacore",      quality=M.WHITE, cat=M.CAT_FISH },
    [6362]  = { name="Raw Rockscale Cod",             quality=M.WHITE, cat=M.CAT_FISH },
    [6317]  = { name="Raw Glossy Mightfish",          quality=M.WHITE, cat=M.CAT_FISH },
    [6522]  = { name="Deviate Fish",                  quality=M.WHITE, cat=M.CAT_FISH },
    [6524]  = { name="Raw Spotted Yellowtail",        quality=M.WHITE, cat=M.CAT_FISH },
    [6525]  = { name="Stonescale Eel",                quality=M.WHITE, cat=M.CAT_FISH },
    [13754] = { name="Raw Sunscale Salmon",           quality=M.WHITE, cat=M.CAT_FISH },
    [13755] = { name="Raw Nightfin Snapper",          quality=M.WHITE, cat=M.CAT_FISH },
    [13756] = { name="Raw Bream",                     quality=M.WHITE, cat=M.CAT_FISH },
    [13757] = { name="Raw Sagefish",                  quality=M.WHITE, cat=M.CAT_FISH },
    [13760] = { name="Raw Greater Sagefish",          quality=M.WHITE, cat=M.CAT_FISH },
    -- ── TBC fish ──────────────────────────────────────────────────────────
    [27422] = { name="Barbed Gill Trout",             quality=M.WHITE, cat=M.CAT_FISH },
    [27425] = { name="Spotted Feltail",               quality=M.WHITE, cat=M.CAT_FISH },
    [27426] = { name="Zangarian Sporefish",           quality=M.WHITE, cat=M.CAT_FISH },
    [27429] = { name="Golden Darter",                 quality=M.WHITE, cat=M.CAT_FISH },
    [27435] = { name="Furious Crawdad",               quality=M.WHITE, cat=M.CAT_FISH },
    [27436] = { name="Mr. Pinchy",                    quality=M.BLUE,  cat=M.CAT_FISH },
    [27438] = { name="Icefin Bluefish",               quality=M.WHITE, cat=M.CAT_FISH },
    [27439] = { name="Figluster's Mudfish",          quality=M.WHITE, cat=M.CAT_FISH },
    [33818] = { name="Bloodfin Catfish",              quality=M.WHITE, cat=M.CAT_FISH },
    [33820] = { name="Crescent-Tail Skullfish",       quality=M.WHITE, cat=M.CAT_FISH },
    [27516] = { name="Enormous Barbed Gill Trout",    quality=M.WHITE, cat=M.CAT_FISH },
    [27513] = { name="Huge Spotted Feltail",          quality=M.WHITE, cat=M.CAT_FISH },
    [21153] = { name="Raw Spotted Feltail",           quality=M.WHITE, cat=M.CAT_FISH },
    [21154] = { name="Zangarian Sporefish",           quality=M.WHITE, cat=M.CAT_FISH },
    -- Goldenscale Vendorfish: fixed 6g vendor price, that's its only purpose
    [20646] = { name="Goldenscale Vendorfish",        quality=M.WHITE, cat=M.CAT_FISH,
                vendor_copper=60000 },
    -- ── Trade goods from fishing ─────────────────────────────────────────
    [24401] = { name="Mote of Water",                 quality=M.WHITE, cat=M.CAT_TRADE },
    [22786] = { name="Primal Water",                  quality=M.WHITE, cat=M.CAT_TRADE },
    [7974]  = { name="Ironjaw Blowfish",              quality=M.WHITE, cat=M.CAT_TRADE },
    -- ── Gray junk from fishing ────────────────────────────────────────────
    [6303]  = { name="Empty Rum Bottle",              quality=M.GRAY, cat=M.CAT_GRAY },
    [6304]  = { name="Broken Crate",                  quality=M.GRAY, cat=M.CAT_GRAY },
    [6305]  = { name="Waterlogged Crate",             quality=M.GRAY, cat=M.CAT_GRAY },
    [6306]  = { name="Mithril Casing",                quality=M.GRAY, cat=M.CAT_GRAY },
    [6307]  = { name="Skull of Impending Doom",       quality=M.GRAY, cat=M.CAT_GRAY },
    [4597]  = { name="Fish Bones",                    quality=M.GRAY, cat=M.CAT_GRAY },
    [1210]  = { name="Worn Axe",                      quality=M.GRAY, cat=M.CAT_GRAY },
    [3068]  = { name="Rusty Hatchet",                 quality=M.GRAY, cat=M.CAT_GRAY },
    [3069]  = { name="Small Brown Pouch",             quality=M.GRAY, cat=M.CAT_GRAY },
    [3712]  = { name="Corroded Knife",                quality=M.GRAY, cat=M.CAT_GRAY },
    [3713]  = { name="Rusty Knife",                   quality=M.GRAY, cat=M.CAT_GRAY },
    [3714]  = { name="Nicked Shortsword",             quality=M.GRAY, cat=M.CAT_GRAY },
    [3715]  = { name="Bent Staff",                    quality=M.GRAY, cat=M.CAT_GRAY },
}

--- Look up by item ID
function M.get(item_id)
    return M.ITEMS[item_id]
end

-- Build reverse name index for O(1) lookup (built once at require time)
local _NAME_INDEX = {}
for _, data in pairs(M.ITEMS) do
    _NAME_INDEX[string.lower(data.name)] = data
end

--- Look up by name (case-insensitive fallback)
function M.get_by_name(name)
    if not name or name == "" then return nil end
    return _NAME_INDEX[string.lower(name)]
end

--- Format copper as gold string (only used for Goldenscale Vendorfish)
function M.format_gold(copper)
    if not copper or copper <= 0 then return nil end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    if g > 0 then return string.format("%dg %ds", g, s)
    elseif s > 0 then return string.format("%ds %dc", s, c)
    else return string.format("%dc", c) end
end

return M
