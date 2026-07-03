local name,addon = ...

addon.LibRoverData = addon.LibRoverData or {}
local data=addon.LibRoverData

data.basenodes.transit = --[[LIBROVER]] {

---------------------
---------------------
---- PORTALS ----
---------------------
---------------------

	-- COMMON TELEPORT DESTINATIONS - DON'T MOVE THEM DOWN.

	--------------
	-- ALLIANCE --
	--------------

		-- Stormwind - Elwynn Forest, Eastern Kingdoms --
		"Stormwind City/0 46.35,90.23 @sw_tp_dst <region:magetower>", 

		-- Stormwind - Elwynn Forest, Eastern Kingdoms --
--		"Stormwind City/0 46.35,90.23 @SW_Tower", 

		-- Stormwind (The Eastern Earthshrine) - Elwynn Forest, Eastern Kingdoms --
--		"Stormwind City/0 74.46,18.34 @SW_Earthshrine", 

		-- Stormwind (Stormwind Embassy) - Elwynn Forest, Eastern Kingdoms --
--		"Stormwind City/0 54.00,14.75 @SW_Embassy", 

		-- Ironforge - Dun Morogh, Eastern Kingdoms --
		"Ironforge/0 25.51,8.43 @if_tp_dst",

		-- Darnassus - Teldrassil, Kalimdor --
		"Darnassus/0 43.47,78.68 @darn_tp_dst",

		-- Exodar - Azuremyst Isle, Kalimdor --
--		"The Exodar/0 47.62,59.82 @The_Exodar_tb_dst",

		-- Exodar - Azuremyst Isle, Kalimdor --
		"The Exodar/0 47.62,59.82 @exo_tp_dst",

		-- The Stair of Destiny - Hellfire Peninsula, Outland --
		"Hellfire Peninsula/0 89.16,50.86 @hfpA_tp_dst",

		-- Shrine of Seven Stars - Vale of Eternal Blossoms, Pandaria --
		"Vale of Eternal Blossoms/0 62.50,21.82 @sss_tp_dst",

	-----------
	-- HORDE --
	-----------

		-- Ogrimmar - Durotar, Kalimdor --
		"Orgrimmar/1 57.10,89.81 @org_tp_dst",

		-- Undercity - Tirisfal Glades, Kalimdor --
		"Undercity/0 84.59,16.33 @uc_tp_dst",

		-- Thunder Bluff - Mulgore, Kalimdor --
		"Thunder Bluff/0 22.21,16.87 @tb_tp_dst",

		-- Silvermoon City - Eversong Woods, Kalimdor --
		"Silvermoon City/0 58.26,19.24 @smc_tp_dst",

		-- The Stair of Destiny - Hellfire Peninsula, Outland --
		"Hellfire Peninsula/0 89.16,49.56 @hfpH_tp_dst",

		-- Shrine of Two Moons - Vale of Eternal Blossoms, Pandaria --
		"Vale of Eternal Blossoms/0 62.50,21.82 @stm_tp_dst",

	-------------
	-- NEUTRAL --
	-------------

		-- Dalaran - Crystalsong Forest, Northrend --
		"Dalaran/1 55.92,46.78 @dala_tp_dst",



	--------------
	-- KALIMDOR --
	--------------

	--## ALLIANCE ##--

		-- Caverns of Time - Tanaris, Kalimdor -to- Stormwind City - Elwynn Forest, Eastern Kingdoms --CHECKED
		"Tanaris/17 58.96,26.78 -to- @sw_tp_dst {fac:A} {mode:PORTAL} {title:Click the Portal to Stormwind}",

		-- The Exodar - Azuremyst Isle, Kalimdor -to- Rut'theran Village - Darnassus, Kalimdor --CHECKED
		"Azuremyst Isle/0 20.40,54.17 -to- Teldrassil/0 52.38,89.47 {fac:A} {mode:PORTAL} {title:Click the Portal to Darnassus}",

		-- The Exodar - Azuremyst Isle, Kalimdor -to- Stormwind City - Elwynn Forest, Eastern Kingdoms --CHECKED
		"The Exodar/0 48.34,62.94 -to- @sw_tp_dst {fac:A} {mode:PORTAL} {title:Click the Portal to Stormwind}",

		-- Nordrassil - Mount Hyjal, Kalimdor -to- Stormwind - Elwynn Forest, Eastern Kingdoms --CHECKED
		"Mount Hyjal/0 62.62,23.12 -to- Stormwind City/0 74.46,18.34 {fac:A} {mode:PORTAL} {cond:PlayerCompletedQuest(25316)}",

		-- Rut'theran Village - Darnassus, Kalimdor -to- Stormwind - Elwynn Forest, Eastern Kingdoms --CHECKED
		"Teldrassil/0 55.03,93.72 -to- @sw_tp_dst {fac:A} {mode:PORTAL}",

		-- Rut'theran Village - Darnassus, Kalimdor -to- The Exodar - Azuremyst Isle, Kalimdor --CHECKED
		"Teldrassil/0 52.27,89.47 -to- Azuremyst Isle/0 20.52,54.16 {mode:PORTAL}",

		-- Temple of the Moon - Darnassus, Kalimdor -to- The Exodar - Azuremyst Isle, Kalimdor --CHECKED
		"Darnassus/0 44.23,78.70 -to- The Exodar/0 47.62,59.82 {fac:A} {mode:PORTAL}",

	--## HORDE ##--

		-- Caverns of Time - Tanaris, Kalimdor -to- Orgrimmar - Durotar, Kalimdor --CHECKED
		"Tanaris/17 58.14,26.72 -to- @org_tp_dst {fac:H} {mode:PORTAL} {title:Click the Portal to Orgrimmar}",

		-- Northern Stranglethorn Vale, Kalimdor -to- Undercity - Tirisfal Glades, Eastern Kingdoms --CHECKED
		--"Northern Stranglethorn/0 37.54,50.99 -to- Undercity/0 84.58,16.33 {fac:H} {mode:Z}",

		"Orgrimmar 49.2,36.5 -to- Kelp'thar Forest 44,28 {fac:H} {mode:PORTAL} {cond:PlayerCompletedQuest(26784) and not PlayerCompletedQuest(25222)}",
		"Orgrimmar 49.2,36.5 -to- Shimmering Expanse 49.5,40.5 {fac:H} {mode:PORTAL} {cond:PlayerCompletedQuest(25222) and not PlayerCompletedQuest(99999)}",
		"Orgrimmar 49.2,36.5 -to- Abyssal Depths 51.4,61.0 {fac:H} {mode:PORTAL} {cond:PlayerCompletedQuest(26784)}",
		"Orgrimmar 48.9,38.5 -to- Uldum 54.9,34.3 {fac:H} {mode:PORTAL} {cond:PlayerCompletedQuest(28112)}",
		"Orgrimmar 50.8,36.4 -to- Deepholm 50.6,52.9 {fac:H} {mode:PORTAL} {cond:PlayerCompletedQuest(27123)}",	
		"Deepholm 50.9,53.1 -to- Orgrimmar 50.0,37.7 {fac:H} {mode:PORTAL} {cond:PlayerCompletedQuest(27123)}",
		"Orgrimmar 51.1,38.3 -to- Mount Hyjal 63.5,23.4 {fac:H} {mode:PORTAL} {cond:PlayerCompletedQuest(25316)}",	
		"Mount Hyjal 63.5,24.4 -to- Orgrimmar 50.0,37.7 {fac:H} {mode:PORTAL} {cond:PlayerCompletedQuest(25316)}",
		"Orgrimmar 47.4,39.3 -to- Tol Barad Peninsula 55.8,80.1 {fac:H} {mode:PORTAL} {cond:UnitLevel('player')>=85}", 	
		"Tol Barad Peninsula 56.3,79.7 -to- Orgrimmar 47.6,39.1 {fac:H} {mode:PORTAL} {cond:UnitLevel('player')>=85}",
		"Orgrimmar 50.2,39.4 -x- Twilight Highlands 73.57,53.53 <template:cityportal> {fac:H} {mode:PORTAL} {cond:PlayerCompletedQuest(26784)}",
		"Orgrimmar/1 70.6,30.9 -x- Brawl'gar Arena/1 55.8,17.0 {fac:H} {mode:PORTAL} {template:pinkportal}",
		"Orgrimmar 68.7,40.7 -x- The Jade Forest,28.5,14.0 <title:Honeydew Village> {fac:H} {mode:PORTAL} {cond:PlayerCompletedQuest(29690)}",


	--## NEUTRAL ##--


		-- Darnassus - Teldrassil, Kalimdor -x- Rut'theran Village - Teldrassil, Kalimdor --CHECKED
		"Darnassus/0 36.79,50.44 -x- Teldrassil/0 55.07,88.38 {mode:PORTAL} {template:pinkportal}",

		-- Nordune Ridge - Mount Hyjal, Kalimdor -to- The Molten Front - Mount Hyjal, Kalimdor --CHECKED
		"Mount Hyjal/0 27.48,56.37 -to- Molten Front/0 51.74,84.42 {mode:PORTAL} {title:Click the Portal to the Firelands} "..
			"{cond:PlayerCompletedQuest(29199)}",

			-- The Molten Front - Mount Hyjal, Kalimdor -to- Nordune Ridge - Mount Hyjal, Kalimdor --CHECKED
			"Molten Front/0 53.02,83.70 -to- Mount Hyjal/0 27.46,55.94 {mode:PORTAL} {title:Click the Portal to Mount Hyjal}",

	----------------------
	-- EASTERN KINGDOMS --
	----------------------

	--## ALLIANCE ##--

		-- Highbank - Twilight Highlands, Eastern Kingdoms -to- Stormwind - Elwynn Forest, Eastern Kingdoms --CHECKED
		"Twilight Highlands/0 79.43,77.85 -to- Stormwind City/0 75.17,16.81 {fac:A} {mode:PORTAL} {cond:PlayerCompletedQuest(27537)} "..
			"{title:Walk Through the Large Portal}",

		-- Skyfire Airship - Elwynn Forest, Eastern Kingdoms -to- The Jade Forest, Pandaria --
		"Eastern Kingdoms/0 41.47,70.19 <title:Skyfire Airship> -to- The Jade Forest 46.23,85.17 {fac:A} {mode:PORTAL} "..
			"{cond:PlayerLevel() >= 10 and not PlayerCompletedQuest(29548)}",

		-- Skyfire Airship - Elwynn Forest, Eastern Kingdoms -to- The Jade Forest, Pandaria --
		"Eastern Kingdoms/0 41.47,70.19 <title:The Skyfire Airship> <override_text:You must be at least 10 to enter Pandaria.> "..
			"<override_icon:error> -to- The Jade Forest 46.23,85.17 {fac:A} {mode:PORTAL} {cond:PlayerLevel() < 10} {cost:999}",

		"Stormwind City,73.2,16.9 -to- Kelp'thar Forest 44,28 {fac:A} {mode:PORTAL} {cond:PlayerCompletedQuest(14482) and not PlayerCompletedQuest(25222)}",
		"Stormwind City,73.2,16.9 -to- Shimmering Expanse 47.2,57.5 {fac:A} {mode:PORTAL} {cond:PlayerCompletedQuest(25222) and not PlayerCompletedQuest(99999)}",
		"Stormwind City,73.2,16.9 -to- Abyssal Depths 55.7,72.8 {fac:A} {mode:PORTAL} {cond:PlayerCompletedQuest(14482)}",
		"Stormwind City,75.3,20.5 -to- Uldum,54.9,34.3 {fac:A} {mode:PORTAL} {cond:PlayerCompletedQuest(28112)}",
		"Stormwind City,73.2,19.6 -to- Deepholm,48.7,53.6 @deepholm_tp_dst {fac:A} {mode:PORTAL} {cond:PlayerCompletedQuest(27123)}",	
		"Deepholm,48.5,53.8 -to- Stormwind City,74.5,18.3 {fac:A} {mode:PORTAL} {cond:PlayerCompletedQuest(27123)}",
		"Stormwind City,76.2,18.7 -x- Mount Hyjal,62.6,23.1 {fac:A} {mode:PORTAL} {cond:PlayerCompletedQuest(25316)}",
		"Stormwind City,73.2,18.4 -to- Tol Barad Peninsula,73.7,60.9 {fac:A} {mode:PORTAL} {cond:UnitLevel('player')>=85}", 
		"Tol Barad Peninsula,75.2,58.9 -to- Stormwind City,73.4,18.3 {fac:A} {mode:PORTAL} {cond:UnitLevel('player')>=85}",
		"Stormwind City,75.2,16.8 -x- Twilight Highlands,79.5,77.8 <template:cityportal> {fac:A} {mode:PORTAL} {cond:PlayerCompletedQuest(27537)}",
		"Stormwind City,68.8,17.1 -x- The Jade Forest,46.23,85.17 <title:Paw'don Village> {fac:A} {mode:PORTAL} {cond:PlayerCompletedQuest(29548)}",

		"Stormwind City/0 48.98,87.36 -to- Blasted Lands/0 53.90,46.08 {fac:A} {mode:PORTAL} {title:Click the Portal to Blasted Lands Inside the Tower} {cond:UnitLevel('player') >= 58}",
		"Ironforge/0 27.23,7.01 -to- Blasted Lands/0 53.90,46.08 {fac:A} {mode:PORTAL} {cond:UnitLevel('player') >= 58}",
		"The Exodar/0 48.15,63.00 -to- Blasted Lands/0 53.90,46.08 {fac:A} {mode:PORTAL} {cond:UnitLevel('player') >= 58}",
		"Darnassus/0 43.98,78.15 -to- Blasted Lands/0 53.90,46.08 {fac:A} {mode:PORTAL} {cond:UnitLevel('player') >= 58}",


	--## HORDE ##--

		-- Dragonmaw Port - Twilight Highlands, Eastern Kingdoms -to- Orgrimmar - Durotar, Kalimdor --CHECKED
		"Twilight Highlands/0 73.56,53.54 -to- Orgrimmar/1 50.14,37.89 {fac:H} {mode:PORTAL} {cond:PlayerCompletedQuest(26784)} "..
			"{title:Walk Through the Large Portal Inside the Building}",



		-- Silvermoon City - Eversong Woods, Eastern Kingdoms -x- Ruins of Lordaeron - Tirisfal Glades, Eastern Kingdoms (Old Time) --CHECKED
		"Silvermoon City/0 49.49,14.80 -x- Tirisfal Glades/0 59.45,67.44 <region:undercitycourt> {fac:H} {mode:PORTAL} {title:Click the Orb of Translocation} ",

		-- Tirisfal Glades, Eastern Kingdoms (Old Time) -to- Northern Stranglethorn Vale, Kalimdor --CHECKED
		"Tirisfal Glades/0 61.88,59.01 -x- Northern Stranglethorn/0 37.23,50.48 {fac:H} {mode:ZEPPELIN}",

		-- Tirisfal Glades, Eastern Kingdoms (Old Time) -to- Orgrimmar - Durotar, Kalimdor --CHECKED
		"Tirisfal Glades/0 60.74,58.67 -x- @org_tp_dst {fac:H} {mode:ZEPPELIN}",

		-- Tirisfal Glades, Eastern Kingdoms (Old Time) -to- Vengeance Landing - Howling Fjord, Northrend --CHECKED
		"Tirisfal Glades/0 59.09,58.91 -x- Howling Fjord/0 79.00,28.92 {fac:H} {mode:ZEPPELIN}",

		"Orgrimmar/1 35.47,69.14 -to- Blasted Lands/0 53.90,46.08 <tag:cityportal> {fac:H} {mode:PORTAL} {title:Click the Portal to Blasted Lands Upstairs Inside the Hut} {cond:UnitLevel('player') >= 58}",
		"Orgrimmar/2 44.70,67.97 -to- Blasted Lands/0 53.90,46.08 <tag:cityportal> {fac:H} {mode:PORTAL} {title:Click the Portal to Blasted Lands Down in the Cleft of Shadows} {cond:UnitLevel('player') >= 58}",
		"Silvermoon City/0 58.42,21.03 -to- Blasted Lands/0 53.90,46.08 <tag:cityportal> {fac:H} {mode:PORTAL} {cond:UnitLevel('player') >= 58}",
		"Undercity/0 85.25,17.04 -to- Blasted Lands/0 53.90,46.08 <tag:cityportal> {fac:H} {mode:PORTAL} {cond:UnitLevel('player') >= 58}",









	--## NEUTRAL ##--

		-- Eastern Plaguelands, Eastern Kingdoms -x- Ghostlands, Eastern Kingdoms --CHECKED
		"Eastern Plaguelands/0 54.38,8.77 <subtype:darkportal> -x- Ghostlands/0 52.22,97.43 <subtype:darkportal> {mode:PORTAL}",

		-- The Dark Portal - Blasted Lands, Eastern Kingdoms (Portal Usable) -to- The Stair of Destiny - Hellfire Penninsula, Outland
		"Blasted Lands/0 55.01,54.27 -to- Hellfire Peninsula/0 89.56,50.22 {mode:PORTAL}",




	----------------------
	-- Darkmoon Island --
	----------------------

	-- Thunder Bluff - Mulgore, Kalimdor -to- Darkmoon Island --CHECKED
	"Mulgore/0 36.85,35.86 -to- Darkmoon Island/0 51.29,23.86 {mode:PORTAL} {cond:ZGV:FindEvent('DARKMOON FAIRE')} "..
		"{title:Click the Portal to the Darkmoon Faire}",

		-- Darkmoon Island -to- Thunder Bluff - Mulgore, Kalimdor --CHECKED
		"Darkmoon Island/0 51.22,23.12 -to- Mulgore/0 36.49,35.11 {fac:H} {mode:PORTAL} {title:Click the Portal Back}",

		-- Darkmoon Island -to- Thunder Bluff - Mulgore, Kalimdor --CHECKED
		"Darkmoon Island/0 50.56,90.75 -to- Mulgore/0 36.49,35.11 {fac:H} {mode:PORTAL} {title:Click the Portal Back}",


	-- Goldshire - Elynn Forest, Eastern Kingdoms -to- Darkmoon Island --CHECKED
	"Elwynn Forest/0 41.79,69.48 -to- Darkmoon Island/0 51.29,23.86 {mode:PORTAL} {cond:ZGV:FindEvent('DARKMOON FAIRE')} "..
		"{title:Click the Portal to the Darkmoon Faire}",
		-- Darkmoon Island -to- Goldshire - Elynn Forest, Eastern Kingdoms --CHECKED
		"Darkmoon Island/0 51.22,23.12 -to- Elwynn Forest/0 41.87,68.17 {fac:A} {mode:PORTAL} {title:Click the Portal Back}",

		-- Darkmoon Island -to- Goldshire - Elynn Forest, Eastern Kingdoms --CHECKED
		"Darkmoon Island/0 50.56,90.75 -to- Elwynn Forest/0 41.87,68.17 {fac:A} {mode:PORTAL} {title:Click the Portal Back}",

	-------------
	-- OUTLAND --
	-------------

	--## ALLIANCE ##--

		-- The Stair of Destiny - Hellfire Peninsula, Outland -to- Stormwind - Elwynn Forest, Eastern Kingdoms --CHECKED
		"Hellfire Peninsula/0 89.22,51.00 -to- @sw_tp_dst {fac:A} {mode:PORTAL}",

		-- The Stair of Destiny - Hellfire Peninsula, Outland -to- Stormwind - Elwynn Forest, Eastern Kingdoms --CHECKED
		"Hellfire Peninsula/0 88.62,52.81 -to- @sw_tp_dst {fac:A} {mode:PORTAL}",

		-- Shattrath City - Terokka Forest, Outland -to- Stormwind - Elwynn Forest, Eastern Kingdoms --CHECKED
		"Shattrath City/0 57.21,48.27 -to- @sw_tp_dst {fac:A} {mode:PORTAL} {cost:15}",

	--## HORDE ##--

		-- The Stair of Destiny - Hellfire Peninsula, Outland -to- Orgrimmar - Durotar, Kalimdor --CHECKED
		"Hellfire Peninsula/0 89.23,49.45 -to- @org_tp_dst {fac:H} {mode:PORTAL}",

		-- The Stair of Destiny - Hellfire Peninsula, Outland -to- Orgrimmar - Durotar, Kalimdor --CHECKED
		"Hellfire Peninsula/0 88.57,47.70 -to- @org_tp_dst {fac:H} {mode:PORTAL}",

		-- Shattrath City - Terokkar Forest, Outland -to- Orgrimmar - Durotar, Kalimdor --CHECKED
		"Shattrath City/0 56.81,48.85 -to- @org_tp_dst {fac:H} {mode:PORTAL}",

	--## NEUTRAL ##--

		-- Shattrath City - Terokka Forest, Outland -to- Sung's Reach Sanctum - Isle of Quel'Danas, Eastern Kingdoms --CHECKED
		"Shattrath City/0 48.57,42.02 -to- Isle of Quel'Danas/0 48.25,34.48 {mode:PORTAL} {title:Click the Shattrath Portal to Isle of Quel'Danas}",

	---------------
	-- NORTHREND --
	---------------

	--## ALLIANCE ##--

		-- Dalaran - Crystalsong Forest, Northrend -to- Stormwind City - Elwynn Forest, Eastern Kingdoms --CHECKED
		"Dalaran/1 40.10,62.81 -to- @sw_tp_dst {fac:A} {mode:PORTAL} {title:Click the Portal to Stormwind}",

		-- Dalaran - Crystalsong Forest, Northrend -to- Wintergrasp Fortress - Wintergrasp, Northrend --
		--"Dalaran 33.6,68.6 -to- Wintergrasp 50.0,16.7 {fac:A} {mode:PORTAL} {cond:LibRover:IsWintergraspControlled()}",

		-- Wintergrasp Fortress - Wintergrasp, Northrend -to- Dalaran - Crystalsong Forest, Northrend --
		--"Wintergrasp/0 49.11,15.31 -to- Dalaran 33.6,68.6 {fac:A} {mode:PORTAL} {cond:LibRover:IsWintergraspControlled()} "..
			--"{title:Click the Portal to The Violet Citadel}",

	--## HORDE ##--

		-- Dalaran - Crystalsong Forest, Northrend -to- Orgrimmar - Durotar, Kalimdor --CHECKED
		"Dalaran/1 55.33,25.45 -to- @org_tp_dst {fac:H} {mode:PORTAL}",

		-- Dalaran - Crystalsong Forest, Northrend -to- Wintergrasp Fortress - Wintergrasp, Northrend --
		--"Dalaran 33.6,68.6 -to- Wintergrasp 50.0,16.7 {fac:H} {mode:PORTAL} {cond:LibRover:IsWintergraspControlled()}",

		-- Wintergrasp Fortress - Wintergrasp, Northrend -to- Dalaran - Crystalsong Forest, Northrend --
		--"Wintergrasp/0 49.11,15.31 -to- Dalaran/1 26.84,44.71 {fac:H} {mode:PORTAL} {cond:LibRover:IsWintergraspControlled()} "..
			--"{title:Click the Portal to The Violet Citadel}",

	--## NEUTRAL ##--

		-- Dalaran - Crystalsong Forest, Northrend -to- The Violet Stand - Crystalsong Forest, Northrend --CHECKED
		"Dalaran/1 55.93,46.77 -to- Crystalsong Forest/0 15.81,42.85 {mode:PORTAL} {title:Click the Teleport to Violet Stand Crystal Inside the Building}",

			-- The Violet Stand - Crystalsong Forest, Northrend -to- Dalaran - Crystalsong Forest, Northrend --CHECKED
			"Crystalsong Forest/0 15.74,42.47 -to- Dalaran/1 55.92,46.79 {mode:PORTAL} {title:Click the Teleport to Dalaran Crystal}",

		-- The Violet Citadel - Dalaran, Northrend -to- The Purple Parlor - Dalaran, Northrend --CHECKED
		"Dalaran/1 25.96,44.14 -to- Dalaran/1 23.95,39.43 {mode:PORTAL} {title:Click the Portal to The Purple Parlor}",

		-- The Purple Parlor - Dalaran, Northrend -to- The Violet Citadel - Dalaran, Northrend --CHECKED
		"Dalaran/1 22.31,39.67 -to- Dalaran/1 26.84,44.71 {mode:PORTAL} {title:Click the Portal to The Violet Citadel}",

		-- Waygate - Sholazar Basin, Northrend -to- Waygate - Un'Goro Crater, Kalimdor --CHECKED
		"Sholazar Basin/0 40.38,83.20 -x- Un'Goro Crater/0 50.53,7.71 {mode:PORTAL} {title:Walk into the light and touch the ground} {cond:PlayerCompletedQuest(12546)}",

	--------------
	-- PANDARIA --
	--------------

	--## ALLIANCE ##--

		-- Paw'don Village - The Jade Forest, Pandaria -to- Stormwind City - Elwynn Forest, Eastern Kingdoms --CHECKED
		"The Jade Forest/0 46.24,85.17 -to- @sw_tp_dst {fac:A} {mode:PORTAL} {cond:PlayerCompletedQuest(31735)} "..
			"{title:Click the Portal to Stormwind}",

		-- Shado-Pan Garrison - Townlong Steppes, Pandaria -to- The Seabolt - Isle of Thunder, Pandaria --
		"Townlong Steppes/0 49.74,68.66 -to- Isle of Thunder/0 34.86,89.85 <title:Portal to the Isle of Thunder> {fac:A} {mode:PORTAL} "..
			"{cond:PlayerCompletedQuest(32681) and not PlayerCompletedQuest(32644)}",

			-- The Seabolt - Isle of Thunder, Pandaria -to- Shado-Pan Garrison - Townlong Steppes, Pandaria --
			"Isle of Thunder/0 35.33,90.57 -to- Townlong Steppes/0 49.76,68.89 <title:Portal to Shado-Pan Garrison> {fac:A} {mode:PORTAL} "..
				"{cond:PlayerCompletedQuest(32681) and not PlayerCompletedQuest(32644)}",

		-- The Seabolt - Isle of Thunder, Pandaria -to- Za'Tual - Isle of Thunder, Pandaria --
		"Isle of Thunder/0 34.86,89.41 -to- Isle of Thunder/0 31.63,83.78 {fac:A} {mode:PORTAL} {cond:PlayerCompletedQuest(32681) and not PlayerCompletedQuest(32644)} "..
			"{title:Click Teleport to Za'Tual}",

			-- Za'Tual - Isle of Thunder, Pandaria -to- The Seabolt - Isle of Thunder, Pandaria --
			"Isle of Thunder/0 31.62,83.61 -to- Isle of Thunder/0 34.78,89.26 {fac:A} {mode:PORTAL} {cond:PlayerCompletedQuest(32681) and not PlayerCompletedQuest(32644)} "..
				"{title:Click Teleport to The Seabolt}",

		-- Shado-Pan Garrison - Townlong Steppes, Pandaria -to- The Violet Rise - Isle of Thunder, Pandaria --
		"Townlong Steppes/0 49.74,68.67 -to- Isle of Thunder/0 64.08,72.48 <title:the Isle of Thunder> {fac:A} {mode:PORTAL} "..
			"{cond:PlayerCompletedQuest(32644)} {template:portal}",

			-- The Violet Rise - Isle of Thunder, Pandaria -to- Shado-Pan Garrison - Townlong Steppes, Pandaria --
			"Isle of Thunder/0 64.71,73.48 -to- Townlong Steppes/0 49.76,68.89 <title:Shado-Pan Garrison> {fac:A} {mode:PORTAL} "..
				"{cond:PlayerCompletedQuest(32644)} {template:portal}",

		-- Shrine of Seven Stars - Vale of Eternal Blossoms, Pandaria -to- Stormwind - Elwynn Forest, Eastern Kingdoms --
		"Shrine of Seven Stars/2 71.66,35.94 <region:shrine7star_east> -to- @sw_tp_dst {fac:A} {mode:PORTAL}",

		-- The Timeless Shore - Timeless Isle, Pandaria -x- Paw'don Village - The Jade Forest, Pandaria --
		"Timeless Isle/0 24.32,52.15 -to- The Jade Forest/0 45.85,84.66 {fac:A} {mode:PORTAL} {cond:hasbuff(424143)}"..
				"{title:Click the Portal to Paw'don Village}",

	--## HORDE ##--

		-- Hellscream's Fist Airship - Durotar, Kalimdor -to- The Jade Forest, Pandaria --
		"Durotar 66,1 <title:Hellscream's Fist Airship> -to- The Jade Forest 28.5,14.0 {fac:H} {mode:PORTAL} "..
			"{cond:PlayerLevel()>=10 and PlayerLevel() < 50 and not PlayerCompletedQuest(31769) and not ZGV.IsLegionOn()}",

		-- Hellscream's Fist Airship - Durotar, Kalimdor -to- The Jade Forest, Pandaria --
		"Durotar 66,1 <title:Hellscream's Fist Airship> <override_text:You must be at least 10 to enter Pandaria.> <override_icon:error> -to- The Jade Forest 28.5,14.0 "..
			"{fac:H} {mode:PORTAL} {cond:PlayerLevel() < 10} {cost:999}",

		-- Honeydew Village - The Jade Forest, Pandaria -to- Orgrimmar - Durotar, Kalimdor --
		"The Jade Forest/0 28.52,14.02 -to- @org_tp_dst <title:Orgrimmar> {fac:H} "..
			"{mode:PORTAL}",

		-- Shado-Pan Garrison - Townlong Steppes, Pandaria -to- The Crimson Treader - Isle of Thunder, Pandaria --
		"Townlong Steppes/0 50.65,73.40 <title:the Isle of Thunder> -to- Isle of Thunder/0 28.39,52.90 {fac:H} {mode:PORTAL} "..
			"{cond:PlayerCompletedQuest(32680) and not PlayerCompletedQuest(32212)} {template:portal}",

			-- The Crimson Treader - Isle of Thunder, Pandaria -to- Shado-Pan Garrison - Townlong Steppes, Pandaria --
			"Isle of Thunder/0 28.37,52.98 <title:Shado-Pan Garrison> -to- Townlong Steppes/0 50.70,73.16 {fac:H} {mode:PORTAL} "..
				"{cond:PlayerCompletedQuest(32680) and not PlayerCompletedQuest(32212)} {template:portal}",

		-- Shado-Pan Garrison - Townlong Steppes, Pandaria -to- Dawnseeker's Promontory - Isle of Thunder, Pandaria --
		"Townlong Steppes/0 50.65,73.40 -to- Isle of Thunder/0 33.25,32.43 {fac:H} {mode:PORTAL} {cond:PlayerCompletedQuest(32212)}"..
				"<title:the Isle of Thunder>",

			-- Dawnseeker's Promontory - Isle of Thunder, Pandaria -to- Shado-Pan Garrison - Townlong Steppes, Pandaria --
			"Isle of Thunder/0 33.22,32.69 -to- Townlong Steppes/0 50.70,73.16 {fac:H} {mode:PORTAL} {cond:PlayerCompletedQuest(32212)}"..
				"<title:Shado-Pan Garrison upstairs inside the building>",

		-- The Crimson Treader - Isle of Thunder, Pandaria -to- Court of Bones - Isle of Thunder, Pandaria --
		"Isle of Thunder/0 28.60,52.79 -to- Isle of Thunder/0 33.06,52.84 {fac:H} {mode:PORTAL} {title:Click Teleport to Court of Bones} "..
			"{cond:PlayerCompletedQuest(32212) and not PlayerCompletedQuest(32212)}",

			-- Court of Bones - Isle of Thunder, Pandaria -to- The Crimson Treader - Isle of Thunder, Pandaria --
			"Isle of Thunder/0 33.02,52.72 -to- Isle of Thunder/0 28.50,51.55 {fac:H} {mode:PORTAL} {title:Click Teleport to the Crimson Treader} "..
				"{cond:PlayerCompletedQuest(32212) and not PlayerCompletedQuest(32212)}",

		-- Shrine of Two Moons - Vale of Eternal Blossoms, Pandaria -to- Orgrimmar - Durotar, Kalimdor --
		"Shrine of Two Moons/2 73.35,42.69 -to- @org_tp_dst {fac:H} {mode:PORTAL}",


	--## NEUTRAL ##--

		-- Bleak Hollow - Isle of Thunder, Pandaria -x- The Foot of Lei Shen - Isle of Thunder, Pandaria --
		"Isle of Thunder/0 52.06,45.03 -x- Isle of Thunder/0 62.82,32.29 {mode:PORTAL}",

		-- The Deepwild - Krasarang Wilds, Pandaria -x- Wind's Edge - Valley of the Four Winds, Pandaria
		"Krasarang Wilds/0 50.47,22.42 -x- Valley of the Four Winds/0 51.25,77.50 {mode:PORTAL} {template:pandarope}",

		-- Terrace of Gurthan - Dread Wastes, Pandaria -x- Serpent's Spine - Vale of Eternal Blossoms, Pandaria --
		"Dread Wastes/0 75.09,21.29 -x- Vale of Eternal Blossoms/0 14.20,76.72 <region:topofthewallVEB> {mode:PORTAL} {template:pandarope}",

	-------------------
	-- THE MAELSTROM --
	-------------------

	--## ALLIANCE ##--

		-- Baradin Base Camp - Tol Barad Peninsula, Eastern Kingdoms -x- Stormwind - Elwynn Forest, Eastern Kingdoms --
		"Tol Barad Peninsula/0 75.23,58.86 -to- Stormwind City/0 74.46,18.34 {fac:A} {mode:PORTAL} {cond:PlayerLevel() >= 30}",

		-- Temple of Earth - Deepholm, The Maelstrom -x- Stormwind - Elwynn Forest, Eastern Kingdoms --
		"Deepholm/0 48.53,53.84 -to- Stormwind City/0 74.46,18.34 {fac:A} {mode:PORTAL} {cond:PlayerCompletedQuest(27123) or PlayerLevel() >= 50}",

		--## HORDE ##--

		-- Hellscream's Grasp - Tol Barad Peninsula, Eastern Kingdoms -to- Orgrimmar - Durotar, Kalimdor --
		"Tol Barad Peninsula/0 56.30,79.66 -to- @org_tp_dst {fac:H} {mode:PORTAL} {cond:PlayerLevel() >= 30}",

		-- Temple of Earth - Deepholm, The Maelstrom -to- Orgrimmar - Durotar, Kalimdor --
		"Deepholm/0 50.93,53.10 -to- @org_tp_dst {fac:H} {mode:PORTAL} {cond:PlayerCompletedQuest(27123) or PlayerLevel() >= 50}",



-------------------------
-------------------------
-- BOATS AND ZEPPELINS --
-------------------------
-------------------------
	
	
	
	--------------
	-- KALIMDOR --
	--------------

	--## ALLIANCE ##--

	--## HORDE ##--

		-- Orgrimmar - Durotar, Kalimdor -x- Thunder Bluff - Mulgore, Kalimdor --
		"Orgrimmar/1 43.00,64.99 -x- Thunder Bluff/0 15.28,25.70 {fac:H} {mode:ZEPPELIN}",

		-- Orgrimmar - Durotar, Kalimdor -x- Grom'gol - Northern Stranglethorn, Eastern Kingdoms --
		"Orgrimmar/1 52.52,53.15 -x- Northern Stranglethorn/0 37.17,52.49 {fac:H} {mode:ZEPPELIN}",

		-- Orgrimmar - Durotar, Kalimdor -x- Warsong Hold - Borean Tundra, Northrend --
		"Orgrimmar/1 44.75,62.30 -x- Borean Tundra/0 41.38,53.61 {fac:H} {mode:ZEPPELIN}",


	--## NEUTRAL ##--

	----------------------
	-- EASTERN KINGDOMS --
	----------------------

	--## ALLIANCE ##--

		-- Booty Bay - The Cape of Stranglethorn, Eastern Kingdoms -x- Rachet - The Barrens, Kalimdor --
		"The Cape of Stranglethorn/0 39.02,67.01 <region:booty_bay> <port:Booty Bay> -x- The Barrens/0 70.16,73.27 <port:Ratchet> {mode:SHIP}",

		-- Menethil Harbor - Wetlands, Eastern Kingdoms -x- Theramore - Dustwallow Marsh, Kalimdor --
		"Wetlands/0 6.37,62.24 <port:Menethil Harbor> -x- Dustwallow Marsh/0 71.51,56.34 {fac:A} {mode:SHIP}",

		-- Menethil Harbor - Wetlands, Eastern Kingdoms -x- Valgarde - Howling Fjord, Northrend --
		"Wetlands/0 5.10,55.72 <port:Menethil Harbor> -x- Howling Fjord/0 61.33,62.60 <port:Valgarde> {fac:A} {mode:SHIP}",

		-- Stormwind - Elwyyn Forest, Eastern Kingdoms -x- Valiance Keep - Borian Tundra, Northrend --
		"Stormwind City/0 18.02,25.84 -x- Borean Tundra/0 59.68,69.41 {fac:A} {mode:SHIP} {cost:177} {cond:not ZGV.IsLegionBoatLock()}",

	--## HORDE ##--

	--## NEUTRAL ##--

		"@deeprun_sw -x- @deeprun_if {mode:TRAM} {cost:30} {dontsetborder:1}",

		-- Stormwind - Elwyyn Forest, Eastern Kingdoms --
		"Stormwind City/0 69.62,31.11 -x- Deeprun Tram/1 42.53,11.53 @deeprun_sw {mode:PORTAL} {title_atob:Enter Stormwind Deeprun Tram portal\nTake tram to Ironforge} "..
			"{title_btoa:Exit Stormwind Deeprun Tram through portal}",

		-- Ironforge - Dun Morogh, Eastern Kingdoms --
		"Ironforge/0 76.93,51.25 -x- Deeprun Tram/1 45.77,12.47 @deeprun_if {mode:PORTAL} {title_atob:Enter Ironforge Deeprun Tram portal\nTake tram to Stormwind} "..
			"{title_btoa:Take tram to Ironforge\nExit Ironforge Deeprun Tram through portal}",

	-------------
	-- OUTLAND --
	-------------

	--## ALLIANCE ##--

	--## HORDE ##--

	--## NEUTRAL ##--

	---------------
	-- NORTHREND --
	---------------

	--## ALLIANCE ##--

	--## HORDE ##--

	--## NEUTRAL ##--

		-- Unu'pe - Borean Tundra, Northrend -x- Moa'ki Harbor - Dragonblight, Northrend --
		"Borean Tundra/0 78.92,53.65 <port:Unu'pe> -x- Dragonblight/0 47.94,78.76 <port:Moa'ki Harbor> {mode:SHIP} {template:turtle}",

		-- Moa'ki Harbor - Dragonblight, Northrend -x- Kamagua - Howling Fjord, Northrend --
		"Dragonblight/0 49.64,78.43 -x- Howling Fjord/0 23.46,57.75 <port:Kamagua> {mode:SHIP} {template:turtle}",

	--------------
	-- PANDARIA --
	--------------

	--## ALLIANCE ##--

	--## HORDE ##--

	--## NEUTRAL ##--

	-------------
	-- DRAENOR --
	-------------

	--## ALLIANCE ##--

	--## HORDE ##--

	--## NEUTRAL ##--

	-------------------
	-- THE MAELSTROM --
	-------------------

	--## ALLIANCE ##--

	--## HORDE ##--

	--## NEUTRAL ##--

	------------------
	-- BROKEN ISLES --
	------------------

	--## ALLIANCE ##--

	--## HORDE ##--

	--## NEUTRAL ##--



----------------------
----------------------
-- TELEPORT TARGETS --
----------------------
----------------------

------------------
-- CLASS SPELLS --
------------------

		--## MAGE ##--

		-- ALLIANCE --
		-- Teleport: Exodar --
		"The Exodar/0 47.62,59.82				<spell:32271>	<faction:A>",
		-- Teleport: Theramore --
		"Dustwallow Marsh/0 66.00,48.99				<spell:49359>	<faction:A>",
		-- Teleport: Shattrath --
		"Shattrath City/0 54.97,40.23				<spell:33690>	<faction:A>",
		-- Teleport: Darnassus --
		"Darnassus/0 43.47,78.67				<spell:3565>	<faction:A>",
		-- Teleport: Ironforge --
		"Ironforge/0 25.51,8.43					<spell:3562>	<faction:A>",
		-- Teleport: Stormwind --
		"Stormwind City/0 49.59,86.53				<spell:3561>	<faction:A> <region:magetower>", 
		-- Teleport: Tol Barad --
		"Tol Barad Peninsula/0 73.67,60.92			<spell:88342>	<faction:A>",
		-- Teleport: Vale of Eternal Blossoms --
		"Vale of Eternal Blossoms/0 86.30,61.05			<spell:132621>	<faction:A>",

		-- HORDE --
		-- Teleport: Orgrimmar --
		"Orgrimmar/1 57.10,89.81				<spell:3567> <faction:H>",
		-- Teleport: Silvermoon City --
		"Silvermoon City 58.3,19.2				<spell:32272> <faction:H>",
		-- Teleport: Stonard --
		"Swamp of Sorrows 49.8,55.8				<spell:49358> <faction:H>",
		-- Teleport: Thunder Bluff --
		"Thunder Bluff 22.2,16.9				<spell:3566> <faction:H>",
		-- Teleport: Shattrath City --
		"Shattrath City 53.0,49.2				<spell:35715> <faction:H>",
		-- Teleport: Undercity --
		"Undercity 84.58,16.33					<spell:3563> <faction:H>",
		-- Teleport: Tol Barad --
		"Tol Barad Peninsula 55.8,80.1				<spell:88344> <faction:H>",
		-- Teleport: Vale of Eternal Blossoms --
		"Vale of Eternal Blossoms/0 62.21,21.54			<spell:132627> <faction:H>",

		-- BOTH --
		-- Ancient Teleport: Dalaran - Eastern Kingdoms --
		"Hillsbrad Foothills/0 30.81,36.47			<spell:120145>	<faction:B>	<title:Teleport to Old Dalaran Crater\n\n|cffff1100 Cast Slow Fall After Loading!|r\n>",
		-- Teleport: Dalaran - Northrend --
		"Dalaran/1 55.92,46.79					<spell:53140>	<faction:B>",

		--[[ Note: node cond functions work only for teleport spells --]]
		-- DRUIDS
		"Moonglade 56.3,32.4					<spell:18960>", --Teleport Moonglade
		-- DK (DEATHGATE)
		"Eastern Plaguelands 83.72,50.03			<spell:50977> <cond:not (PlayerCompletedQuest(38990) or PlayerCompletedQuest(40935) or PlayerCompletedQuest(40740))>", --Class based!
		-- MONKS (Zen Pilgrimage)
		"Kun-Lai Summit 48.64,42.94				<spell:126892> <region:peak_of_serenity> <cond:not PlayerCompletedQuest(40236)>", --Class based!

}
