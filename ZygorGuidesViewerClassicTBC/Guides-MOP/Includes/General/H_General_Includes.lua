if UnitFactionGroup("player")~="Horde" then return end
local ZygorGuidesViewer=ZygorGuidesViewer
if not ZygorGuidesViewer then return end

-----------------------
----- Auctioneers -----
-----------------------

ZygorGuidesViewer:RegisterInclude("auctioneer",[[
		talk Auctioneer Drezmit##44866 |goto Orgrimmar 54.10,73.30
]])

ZygorGuidesViewer:RegisterInclude("shatt_auctioneer",[[
		talk Auctioneer Itoran##50143 |goto Shattrath City 51.00,26.50 |only if rep('The Aldor')>=Friendly
		talk Auctioneer Lyrsara##50140 |goto Shattrath City 56.80,62.40 |only if rep('The Scryers')>=Friendly
]])