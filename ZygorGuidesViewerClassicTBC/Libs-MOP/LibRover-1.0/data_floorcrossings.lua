local name,addon = ...

addon.LibRoverData = addon.LibRoverData or {}
local data=addon.LibRoverData

data.basenodes.FloorCrossings = --[[LIBROVER]] {

	


	-- Old Dalaran
		["Dalaran"] = {
			 --Underbelly, a few entries. Cost to adjust which gets used for each part of the city.
			"Dalaran/1 35.0,45.3 <radius:5> -x- Dalaran/2 34.4,43.4 <region:underbelly> <radius:5> {template:tunnel}",
			"@+ -x- Dalaran/1 38.8,45.1 <region:underbelly> ",
			"@+ -x- Dalaran/2 34.3,43.3",
			"Dalaran/1 60.2,47.7 <radius:5> -x- Dalaran/2 64.3,48.6 <region:underbelly> <radius:5> {template:tunnel} {cost:4}",
			"@+ -x- Dalaran/1 38.8,45.1 <region:underbelly> ",
			"@+ -x- Dalaran/2 64.4,48.6",
			"Dalaran/1 48.1,32.7 <radius:2> <title:Dalaran Well> -to- Dalaran/2 44.3,25.2 {cost:8}",

			--[[
			"Dalaran/1 34.89,45.42 <title:Western sewer entrance> -x- Dalaran/1 31.59,45.56 <onlyhardwire_qq:1> <title:Western sewer entrance midpoint> <region:underbelly> {cost:0}",
			"@+ -x- Dalaran/2 34.28,43.57 <title:Western sewer exit> {cost:0}",
			"Dalaran/1 60.28,47.77 <title:Eastern sewer entrance> -x- Dalaran/1 62.68,51.37 <onlyhardwire_qq:1> <title:Eastern sewer entrance midpoint> <region:underbelly> {cost:0}",
			"@+ -x- Dalaran/2 64.16,48.00 <title:Eastern sewer exit> {cost:0}",
			--]]
		},

		[762] = { -- Scarlet Monastery - has to stay numeric! - this is funny, yes, it should be empty: floors are wings, inaccessible from each other. Rely on normal entrance/exit paths.
		},

	-- Kalimdor

		["Azuremyst Isle"] = {
			"Azuremyst Isle/0 27.01,76.61 <radius:10> -x- Azuremyst Isle/2 58.76,85.37 <radius:10> {template:cave}", -- Tides' Hollow, Azuremyst Isle
			"Azuremyst Isle/0 45.34,19.54 <radius:10> -x- Azuremyst Isle/3 21.11,91.45 <radius:10> {template:cave}", -- Stillpine Hold, Azuremyst Isle
		},
		["Desolace"] = {
			-- Wicked Grotto, Desolace (Mauradon entrance) **Only Way to Get To Felspore Cavern**
			"Desolace/0 29.09,62.55 <radius:10> -x- Desolace/21 22.85,43.46 <radius:10> {title_atob:Click the Stone Door and enter the cave} {title_btoa:Click the Stone Door and leave the cave}",
			
			"Desolace/21 28.36,42.60 <radius:10> -x- Desolace/22 48.27,88.67 <radius:10> {template:cave}", -- Felspore Cavern, Desolace (Mauradon inner cave)
			
			"Desolace/21 27.07,35.72 <radius:10> -x- Desolace/22 46.12,77.70 <radius:10> {template:cave}", -- Felspore Cavern, Desolace (Mauradon inner cave)
		},
		["Durotar"] = {
			"Durotar/0 54.99,9.67 <radius:8> -x- Durotar/12 84.13,53.61 <radius:8> {template:cave}", -- Skull Rock, Durotar
			"Valley of Trials/0 52.87,21.89 <radius:8> -x- Durotar/0 45.35,56.32 <radius:8> {template:cave} <region:durotar_burningbladecoven_entry>", -- Valley of Trials to Durotar buffer map for Burning Blade Coven, Valley of Trials (Durotar)
			"Durotar/0 45.40,56.21 <radius:8> <region:durotar_burningbladecoven_entry> -x- Durotar/8 72.48,89.43 <radius:8> {template:cave}", -- Buffer map to Burning Blade Coven, Valley of Trials (Durotar)
			"Durotar/0 52.83,28.69 <radius:6> -x- Durotar/19 49.95,91.36 <radius:6> {template:cave}", -- Dustwind Cave, Durotar
		},
		["Echo Isles"] = {
			"Echo Isles/0 59.11,22.33 <radius:10> -x- Echo Isles/9 54.16,80.12 <radius:10> {template:cave}", -- Spitescale Cavern, Echo Isles (Durotar)
		},
		["Mulgore"] = {
			"Mulgore/0 35.00,61.35 <radius:10> -x- Mulgore/6 74.75,55.62 <radius:10> {template:cave}", -- Palemane Rock
			"Mulgore/0 60.74,47.59 <radius:10> -x- Mulgore/7 40.15,89.72 <radius:10> {template:mine}", -- The Venture Co. Mine (East)
			"Mulgore/0 59.19,36.39 <radius:10> -x- Mulgore/7 29.55,13.58 <radius:8> {template:mine}", -- The Venture Co. Mine (West)
			"Mulgore/0 59.19,44.16 <radius:10> -x- Mulgore/7 28.50,65.33 <radius:10> {template:mine}", -- The Venture Co. Mine (Middle)
		},
		["The Barrens"] = {
			"The Barrens/0 38.97,69.42 <radius:10> -x- The Barrens/20 22.61,87.96 <radius:10> {template:cave}", -- Wailing Caverns cave entrance, The Barrens
		},
		["Orgrimmar"] = {
			"Orgrimmar/1 55.98,51.39 <radius:15> -x- Orgrimmar/2 77.67,15.09 <radius:15> {template:cave}", -- The Drag, Orgrimmar (East)
			"Orgrimmar/1 42.18,61.25 <radius:10> -x- Orgrimmar/2 24.27,73.65 <radius:10> {template:cave}", -- The Drag, Orgrimmar (West)
		},
		["Silithus"] = {
			"Silithus/0 70.4,15.9 -x- Silithus/13 15.1,70.0 {template:cave}", -- Twilight's Run
		},
		["Tanaris"] = {
			"Tanaris/0 35.3,42.6 -x- Tanaris/15 55.9,36.4 {template:tunnel}", -- The Noxious Lair
			"Tanaris/0 34.8,41.6 -x- Tanaris/15 50.4,25.1 {template:tunnel}", -- The Noxious Lair
			"Tanaris/0 34.5,42.4 -x- Tanaris/15 47.5,33.6 {template:tunnel}", -- The Noxious Lair
			"Tanaris/0 54.5,69.8 -x- Tanaris/16 42.2,39.4 {template:tunnel}", -- The Gaping Chasm
			"Tanaris/0 55.5,68.2 -x- Tanaris/16 51.5,24.3 {template:tunnel}", -- The Gaping Chasm
			{ {"Tanaris/0 64.9,50.0",radius=20,actiontitle=function(self,fromnode,tonode) if tonode==self.border then return "Enter Caverns of Time" else return "Exit Caverns of Time" end end},
			 {"Tanaris/17 53.3,29.4",actiontitle=function(self,fromnode,tonode) if fromnode and fromnode.m==self.m and fromnode.f==self.f then return "Go up the spiral tunnel" end end, actionicon=function(self,fromnode,tonode) if fromnode and fromnode.m==self.m and fromnode.f==self.f then return "upstairs" end end} }, -- Caverns of Time2
			{ {"Tanaris/17 36.8,75.0",radius=20,actiontitle=function(self,fromnode,tonode) if fromnode and fromnode.m==self.m and fromnode.f==self.f then return "Go down the spiral tunnel" end end, actionicon=function(self,fromnode,tonode) if fromnode and fromnode.m==self.m and fromnode.f==self.f then return "downstairs" end end} ,
			"Tanaris/18 61.8,52.4" }, -- Caverns of Time2
			--[[ Detailed waypoints through the CoT tunnel. Obsolete, kindish.
			"Tanaris/17 56,27 -x- Tanaris/17 59,28 {title:Traverse the Timeless Tunnel}",
			"@+ -x- Tanaris/17 66,29 {title:Traverse the Timeless Tunnel}",
			"@+ -x- Tanaris/17 68,18 {title:Traverse the Timeless Tunnel}",
			"@+ -x- Tanaris/17 49,20 {title:Traverse the Timeless Tunnel}",
			"@+ -x- @cot_tunnel_17to18 {title:Traverse the Timeless Tunnel}",
			--]]
		},
		["Teldrassil"] = {
			"Teldrassil/0 45.6,50.6 @teldrbanethila0 -x- Teldrassil/4 52.6,15.5 @teldrbanethila4 {template:cave}", -- Banethil Barrow Den (Upper Den)
			"Teldrassil/4 24.6,86.0 @teldrbanethilb4 -x- Teldrassil/5 29.9,76.4 @teldrbanethilb5 {title_atob:Go downstairs inside the cave} {title_btoa:Go upstairs inside the cave}", -- Banethil Barrow Den (Lower Den)
			"Teldrassil/4 54.2,36.5 @teldrbanethilc4 -x- Teldrassil/5 46.7,39.7 @teldrbanethilc5 {title_atob:Go downstairs inside the cave} {title_btoa:Go upstairs inside the cave}", -- Banethil Barrow Den (Lower Den)
			"@teldrbanethila4 -x- @teldrbanethilb4 {replace:1}",
			"@teldrbanethilb4 -x- @teldrbanethilc4 {replace:1}",
			"@teldrbanethilc4 -x- @teldrbanethila4 {replace:1}",
			"Teldrassil/4 25.9,34.2 @teldrbanethil4up <onlyhardwire:1>",
			"Teldrassil/4 38.8,56.8 @teldrbanethil4x <onlyhardwire:1>",
			"@teldrbanethil4up -x- @teldrbanethila4 {dontsetborder:1}",
			"@teldrbanethil4up -x- @teldrbanethil4x {dontsetborder:1}",
			"@teldrbanethil4x -x- @teldrbanethilb4 {dontsetborder:1}",
			"@teldrbanethil4x -x- @teldrbanethilc4 {dontsetborder:1}",

			"Teldrassil/0 54.5,46.3 -x- Teldrassil/3 77.6,81.7 {template:cave}", -- Fel Rock
			"Shadowglen/0 39.3,30.4 -x- Teldrassil/2 45.4,90.3 {template:cave}", -- Shadowthread Cave
		},

	-- Eastern Kingdoms

		["Badlands"] = {
			"Badlands/0 41.6,11.6 -x- Badlands/18 75.6,36.5 {template:cave}", --Uldaman Entrance
		},
		["Burning Steppes"] = {
			"Burning Steppes/0 21.0,38.0 -x- Burning Steppes/14 49.50,88.66", -- Blackrock Spire south entrance
			"Burning Steppes/14 72.0,43.2 -x- Burning Steppes/15 60.5,27.8", -- Blackrock Caverns foyer
			"Burning Steppes/14 66.8,60.7 -x- Burning Steppes/15 41.7,79.6", -- Blackrock Caverns foyer north
			"Burning Steppes/14 46.8,50.8 -x- Burning Steppes/16 58.2,88.5", -- Blackrock Depths chain
		},
		["Coldridge Valley"] = {
			"Coldridge Valley/0 51.3,82.5 -x- Coldridge Valley/9 14.4,50.1 {template:cave}", -- Frostmane Hovel
		},
		["Deathknell"] = {
			"Deathknell/0 29.7,30.7 -x- Deathknell/12 87.3,52.0 {template:mine}", -- Night's Web Hollow
		},
		["Dun Morogh"] = {
			"Dun Morogh/0 48.9,52.6 -x- Dun Morogh/7 60.4,77.0 {template:cave}", -- Grizzled Den
			"Dun Morogh/0 42.7,64.1 -x- Dun Morogh/6 60.6,11.0", -- Coldridge Pass
			"Dun Morogh/0 41.1,70.0 -x- Dun Morogh/6 38.0,91.1", -- Coldridge Pass
			"Dun Morogh/10 79.5,84.2 -x- New Tinkertown/0 32.6,37.0", --Gnome Starter
			"Dun Morogh/0 77.8,55.1 -x- Dun Morogh/11 39.6,84.2 {template:cave}", -- Gol'Bolar Quarry Mine
		},
		["Elwynn Forest"] = {
			"Elwynn Forest/0 61.7,53.7 -x- Elwynn Forest/19 48.9,90.1 {template:mine}", --Jasperload Mine
			"Elwynn Forest/0 38.9,82.3 -x- Elwynn Forest/1 39.9,88.0 {template:mine}", --Fargodeep Mine
			"Elwynn Forest/1 55.4,36.3 -x- Elwynn Forest/2 56.3,26.0", --Fargodeep Mine Lower
			"Elwynn Forest/0 38.5,81.5 -x- Elwynn Forest/2 35.2,68.4 {template:mine}", --Fargodeep Mine Lower
		},
		["Gilneas"] = {
			"Gilneas/0 29.03,51.66 <radius:15> -x- Gilneas/2 66.89,58.26 <radius:15> {template:building}", -- Greymane Manor Main Floor
			"Gilneas/2 61.0,47.5 <radius:15> -x- Gilneas/3 56.7,47.5 <radius:15> {title_atob:Run up the stairs} {title_btoa:Run down the stairs}", -- Greymane Manor Upper Floor
			"Gilneas/0 76.44,31.19 <radius:10> -x- Gilneas/1 28.91,67.78 <radius:10> {template:mine}", -- Emberstone Mine
		},
		["New Tinkertown"] = {
			"New Tinkertown/0 33.3,66.4 -x- New Tinkertown/8 94.6,58.1 {template:cave}", -- Frostmane Hold
		},
		["Tirisfal Glades"] = {
			"Tirisfal Glades/0 82.6,33.5 -x- Tirisfal Glades/13 17.3,82.9 {template:building}", -- Scarlet Monastery Entrance
			"Tirisfal Glades/0 82.3,32.6 -x- Tirisfal Glades/13 14.5,73.1 {template:building}", -- Scarlet Monastery Entrance
		},
		["Westfall"] = {
			"Westfall/0 42.5,71.8 -x- Westfall/17 69.3,23.7 {template:building}", -- Deadmines Cave Entrance (Moonbrook)
			"Westfall/0 44.5,24.7 -x- Westfall/5 41.1,94.1 {template:mine}", -- Jangolode Mine
		},

	-- Outland

	-- Northrend

	-- Cataclysm

		["Kezan"] = {
			"Kezan/0 65.6,86.7 -x- Kezan/7 64.0,19.6 {template:mine}", -- Kaja'Mine Copper
			"Kezan/0 74.3,83.3 -x- Kezan/6 32.9,31.0 {template:mine}", -- Kaja'Mine Silver
			"Kezan/0 70.9,76.5 -x- Kezan/5 41.0,75.5 {template:mine}", -- Kaja'Mine Gold
		},
		["The Lost Isles"] = {
			"The Lost Isles/0 31.2,78.6 -x- The Lost Isles/1 48.1,90.0 {template:cave}", -- Kaja'mite Cavern
			"The Lost Isles/0 70.0,48.0 -x- The Lost Isles/2 50.0,10.8 {template:cave}", -- Volcanoth's Lair
		},


		["Deepholm"] = {
		},
			

	-- Pandaria

		["The Jade Forest"] = {
			-- Greenstone Quarry Main Entrance
				"The Jade Forest/0 45.91,28.90 <radius:15> -x- The Jade Forest/6 69.01,22.69 <radius:15> {template:mine}",

			-- Greenstone Quarry Lower Floor
				"The Jade Forest/6 51.48,40.94 <radius:10> -x- The Jade Forest/6 69.01,22.69 <radius:10> {title_atob:Run down the stairs inside the mine} {title_btoa:Run up the stairs inside the mine}",
		},
		["Krasarang Wilds"] = {
			"Krasarang Wilds/0 80.3,17.8 -x- Krasarang Wilds/1 33.3,24.4 {template:building}",
			"Krasarang Wilds/1 61.6,51.8 -x- Krasarang Wilds/2 59.5,36.7",
			"Krasarang Wilds/2 62.7,39.6 -x- Krasarang Wilds/3 82.3,36.0",
		},
		["Kun-Lai Summit"] = {
			"Kun-Lai Summit/0 52.9,71.3 -x- Kun-Lai Summit/11 56.5,15.9 {template:cave}", --The Deeper
			"Kun-Lai Summit/0 50.3,61.7 -x- Kun-Lai Summit/10 74.9,91.5 {template:cave}", -- Knucklethump Hole
			"Kun-Lai Summit/0 72.96,73.39 <radius:15> -x- Kun-Lai Summit/9 16.69,34.49 <radius:15> {template:cave}", -- Pranksters' Hollow
			"Kun-Lai Summit/0 59.1,52.5 -x- Kun-Lai Summit/8 66.9,82.3 {template:cave}", -- Howlingwind Cavern
			"Kun-Lai Summit/0 53.0,46.5 -x- Kun-Lai Summit/17 88.3,54.8 {template:building}", -- Tomb of Conquerors
			"Kun-Lai Summit/17 59.39,86.63 -x- Kun-Lai Summit/0 50.64,49.84 {title:Follow the path}", -- Tomb of Conquerors
			"Kun-Lai Summit/0 33.1,26.6 -x- Kun-Lai Summit/20 52.2,11.6 {template:building}", -- Ruins of Korune
			"Kun-Lai Summit/20 30.9,75.9 <radius:15> -x- Kun-Lai Summit/21 34.3,76.1 {title_atob:Go downstairs} {title_btoa:Go upstairs}", -- Crypt of Korune
		},
		["Townlong Steppes"] = {
			"Townlong Steppes/0 33.02,61.24 -x- Townlong Steppes/13 20.15,68.46 {template:cave}", -- Niuzao Catacombs
		},
		["Vale of Eternal Blossoms"] = {
			"Vale of Eternal Blossoms/0 22.2,26.3 <radius:7> -x- Vale of Eternal Blossoms/1 54.0,88.2 <radius:7> {template:building}", -- Guo-Lai Halls
		},
		["The Veiled Stair"] = {
			"Kun-Lai Summit/0 73.2,94.6 -x- The Veiled Stair/5 25.1,12.5", -- The Ancient Passage
			"The Veiled Stair/0 50.6,40.4 -x- The Veiled Stair/5 63.1,86.4", -- The Ancient Passage
			"The Veiled Stair/0 57.3,13.6 -x- The Veiled Stair/5 77.6,36.7", -- The Ancient Passage
		},
		["Isle of Thunder"] = {
			"Isle of Thunder/0 54.6,29.1 -x- Isle of Thunder/1 73.1,51.3 {template:cave}", --Ghostly Veins
			"Isle of Thunder/0 49.3,25.5 -x- Isle of Thunder/1 38.8,27.1 {template:cave}", --Ghostly Veins
			"Isle of Thunder/0 49.2,32.2 -x- Isle of Thunder/1 31.7,81.7 {template:cave}", --Ghostly Veins
			"Isle of Thunder/0 62.4,40.3 -x- Isle of Thunder/2 66.1,77.9 {template:tunnel}", --The Swollen Vault
		},
		["Isle of Thunder Scenario"] = { -- Isle of Thunder scenario clone
			"Isle of Thunder Scenario/0 54.6,29.1 -x- Isle of Thunder Scenario/1 73.1,51.3 {template:cave}",
			"Isle of Thunder Scenario/0 49.27,25.52 -x- Isle of Thunder Scenario/1 37.45,26.92 {template:cave}",
			"Isle of Thunder Scenario/0 49.2,33.0 -x- Isle of Thunder Scenario/1 31.5,82.0 {template:cave}",
			"Isle of Thunder Scenario/0 62.4,40.3 -x- Isle of Thunder Scenario/2 66.1,77.9 {template:tunnel}",
		},
		["Timeless Isle"] = {
			"Timeless Isle/0 43.3,40.8 -x- Timeless Isle/22 44.4,81.0 {template:cave}", --Cavern of Lost Spirits
		},


}


--[[
-- translate the flooring zone-folders from names to numbers
	local TEMP={}
	for zone,zonedata in pairs(data.basenodes.FloorCrossings) do
		if type(zone)~="number" then
			local id=data.MapIDsByName[zone]
			if type(id)=="table" then id=id[1] end
			if not id then error("Map "..zone.." has no ID!") end
			zone=id
		end
		TEMP[zone]=zonedata
	end
	data.basenodes.FloorCrossings=TEMP
--]]