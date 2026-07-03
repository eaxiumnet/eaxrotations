local name,addon = ...
local data={}
addon.LibTaxiData = data
data.taxipoints = {



--------------------
--- KALIMDOR ---
--------------------
[1414]={
	
	["Ashenvale"] = {
		{name="Splintertree Post",faction="H",npc="Vhulgra",npcid=12616,x=73.18,y=61.59},
		{name="Zoram'gar Outpost",faction="H",npc="Andruk",npcid=11901,x=12.24,y=33.80},
		{name="Astranaar",faction="A",npc="Daelyshia",npcid=4267,x=34.41,y=47.99},
		{name="Forest Song",faction="A",npc="Suralais Farwind",npcid=22935,x=85.09,y=43.45},
	},
	
	["Azshara"] = {
		{name="Talrendis Point",faction="A",npc="Jarrodenus",npcid=12577,x=11.90,y=77.59},
		{name="Valormok",faction="H",npc="Kroum",npcid=8610,x=21.96,y=49.62},
	},
	
	["Bloodmyst Isle"] = {
		{name="Blood Watch",faction="A",npc="Laando",npcid=17554,x=57.68,y=53.87},
	},
	
	["Darkshore"] = {
		{name="Auberdine",faction="A",npc="Caylais Moonfeather",npcid=3841,x=36.34,y=45.58},
	},
	
	["Desolace"] = {
		{name="Shadowprey Village",faction="H",npc="Thalon",npcid=6726,x=21.60,y=74.13},
		{name="Nijel's Point",faction="A",npc="Baritanas Skyriver",npcid=6706,x=64.66,y=10.54},
	},
	
	["Dustwallow Marsh"] = {
		{name="Brackenwall Village",faction="H",npc="Shardi",npcid=11899,x=35.56,y=31.88},
		{name="Theramore",faction="A",npc="Baldruc",npcid=4321,x=67.48,y=51.30},
		{name="Mudsprocket",faction="B",npc="Dyslix Silvergrub",npcid=23612,x=42.82,y=72.43},
	},
	
	["Felwood"] = {
		{name="Bloodvenom Post",faction="H",npc="Brakkar",npcid=11900,x=34.44,y=53.96},
		{name="Talonbranch Glade",faction="A",npc="Mishellena",npcid=12578,x=62.49,y=24.24},
		{name="Emerald Sanctuary",faction="B",npc="Gorrim",npcid=22931,x=51.53,y=82.22},
	},
	
	["Feralas"] = {
		{name="Camp Mojache",faction="H",npc="Shyn",npcid=8020,x=75.45,y=44.36},
		{name="Thalanaar",faction="A",npc="Thyssiana",npcid=4319,x=89.50,y=45.85},
		{name="Feathermoon",faction="A",npc="Fyldren Moonfeather",npcid=8019,x=30.24,y=43.25},
	},
	
	["Moonglade"] = {
		{name="Moonglade",faction="H",npc="Faustron",npcid=12740,x=32.09,y=66.61},
		{name="Moonglade",faction="A",npc="Sindrayl",npcid=10897,x=48.10,y=67.34},
		--{name="Nighthaven",faction="A",class="DRUID",npc="Silva Fil'naveth",npcid=11800,x=44.15,y=45.22,forceknown=true},
		--{name="Nighthaven",faction="H",class="DRUID",npc="Bunthen Plainswind",npcid=11798,x=44.29,y=45.87,forceknown=true},
	},
	
	["Orgrimmar"] = {
		{name="Orgrimmar",faction="H",npc="Doras",npcid=3310,x=45.12,y=63.89},
	},
	
	["Silithus"] = {
		{name="Cenarion Hold",faction="H",npc="Runk Windtamer",npcid=15178,x=48.68,y=36.67},
		{name="Cenarion Hold",faction="A",npc="Cloud Skydancer",npcid=15177,x=50.58,y=34.45},
	},
	
	["Stonetalon Mountains"] = {
		{name="Stonetalon Peak",faction="A",npc="Teloren",npcid=4407,x=36.44,y=7.18},
		{name="Sun Rock Retreat",faction="H",npc="Tharm",npcid=4312,x=45.12,y=59.84},
	},
	
	["Tanaris"] = {
		{name="Gadgetzan",faction="H",npc="Bulkrek Ragefist",npcid=7824,x=51.60,y=25.44},
		{name="Gadgetzan",faction="A",npc="Bera Stonehammer",npcid=7823,x=51.01,y=29.35},
	},
	
	["Teldrassil"] = {
		{name="Rut'theran Village",faction="A",npc="Vesprystus",npcid=3838,x=58.40,y=94.02,region="ruttheran"},
	},
	
	["The Barrens"] = {
		{name="Crossroads",faction="H",npc="Devrak",npcid=3615,x=51.51,y=30.36},
		{name="Camp Taurajo",faction="H",npc="Omusa Thunderhorn",npcid=10378,x=44.45,y=59.15},
		{name="Ratchet",faction="B",npc="Bragok",npcid=16227,x=63.08,y=37.16},
	},
	
	["The Exodar"] = {
		{name="The Exodar",faction="A",npc="Stephanos",npcid=17555,x=68.34,y=63.50},
	},
	
	["Thousand Needles"] = {
		{name="Freewind Post",faction="H",npc="Nyse",npcid=4317,x=45.14,y=49.11},
	},
	
	["Thunder Bluff"] = {
		{name="Thunder Bluff",faction="H",npc="Tal",npcid=2995,x=46.99,y=49.83},
	},
	
	["Un'Goro Crater"] = {
		{name="Marshal's Refuge",faction="B",npc="Gryfe",npcid=10583,x=45.23,y=5.83},
	},
	
	["Winterspring"] = {
		{name="Everlook",faction="A",npc="Maethrya",npcid=11138,x=62.33,y=36.61},
		{name="Everlook",faction="H",npc="Yugrek",npcid=11139,x=60.47,y=36.30},
	},
},



----------------------------
--- EASTERN KINGDOMS ---
----------------------------
[1415]={
	
	["Arathi Highlands"] = {
		{name="Refuge Pointe",faction="A",npc="Cedrik Prose",npcid=2835,x=45.76,y=46.11},
		{name="Hammerfall",faction="H",npc="Urda",npcid=2851,x=73.06,y=32.68},
	},
	
	["Badlands"] = {
		{name="Kargath",faction="H",npc="Gorrik",npcid=2861,x=3.99,y=44.78},
	},
	
	["Blasted Lands"] = {
		{name="Nethergarde Keep",faction="A",npc="Alexandra Constantine",npcid=8609,x=65.54,y=24.34},
	},
	
	["Burning Steppes"] = {
		{name="Flame Crest",faction="H",npc="Vahgruk",npcid=13177,x=65.69,y=24.22},
		{name="Morgan's Vigil",faction="A",npc="Borgus Stoutarm",npcid=2299,x=84.33,y=68.33},
	},
	
	["Duskwood"] = {
		{name="Darkshire",faction="A",npc="Felicia Maline",npcid=2409,x=77.49,y=44.29},
	},
	
	["Eastern Plaguelands"] = {
		{name="Light's Hope Chapel",faction="A",npc="Khaelyn Steelwing",npcid=12617,x=81.64,y=59.28},
		{name="Light's Hope Chapel",faction="H",npc="Georgia",npcid=12636,x=80.22,y=57.01},
		--{name="Plaguewood Tower",faction="B",npc="William Kielar",npcid=17209,x=22.33,y=31.40},
	},

	["Eversong Woods"] = {
		{name="Silvermoon City",faction="H",npc="Skymistress Gloaming",npcid=16192,x=54.36,y=50.72},
	},

	["Ghostlands"] = {
		{name="Tranquillien",faction="H",npc="Skymaster Sunwing",npcid=16189,x=45.42,y=30.52},
		{name="Zul'Aman",faction="B",npc="Kiz Coilspanner",npcid=24851,x=74.77,y=67.15},
	},
	
	["Hillsbrad Foothills"] = {
		{name="Southshore",faction="A",npc="Darla Harris",npcid=2432,x=49.34,y=52.27},
		{name="Tarren Mill",faction="H",npc="Zarise",npcid=2389,x=60.14,y=18.62},
	},
	
	["Ironforge"] = {
		{name="Ironforge",faction="A",npc="Gryth Thurden",npcid=1573,x=55.50,y=47.74},
	},
	
	["Loch Modan"] = {
		{name="Thelsamar",faction="A",npc="Thorgrum Borrelson",npcid=1572,x=33.94,y=50.95},
	},
	
	["Redridge Mountains"] = {
		{name="Lakeshire",faction="A",npc="Ariena Stormfeather",npcid=931,x=30.59,y=59.41},
	},
	
	["Searing Gorge"] = {
		{name="Thorium Point",faction="H",npc="Grisha",npcid=3305,x=34.84,y=30.87},
		{name="Thorium Point",faction="A",npc="Lanie Reed",npcid=2941,x=37.94,y=30.86},
	},
	
	["Silverpine Forest"] = {
		{name="The Sepulcher",faction="H",npc="Karos Razok",npcid=2226,x=45.62,y=42.60},
	},
	
	["Stranglethorn Vale"] = {
		{name="Grom'gol",faction="H",npc="Thysta",npcid=1387,x=32.54,y=29.35},
		{name="Booty Bay",faction="H",npc="Gringer",npcid=2858,x=26.87,y=77.10},
		{name="Booty Bay",faction="A",npc="Gyll",npcid=2859,x=27.53,y=77.79},
		{name="Rebel Camp",faction="A",npc="Nizzle",npcid=24366,x=38.23,y=4.04},	
	},
	
	["Swamp of Sorrows"] = {
		{name="Stonard",faction="H",npc="Breyk",npcid=6026,x=46.07,y=54.83},
	},
	
	["Stormwind City"] = {
		{name="Stormwind",faction="A",npc="Dungar Longdrink",npcid=352,x=66.27,y=62.13},
	},
	
	["The Hinterlands"] = {
		{name="Revantusk Village",faction="H",npc="Gorkas",npcid=4314,x=81.70,y=81.76},
		{name="Aerie Peak",faction="A",npc="Guthrum Thunderfist",npcid=8018,x=11.07,y=46.15},
	},
	
	["Undercity"] = {
		{name="Undercity",faction="H",npc="Michael Garrett",npcid=4551,x=63.25,y=48.56},
	},
	
	["Western Plaguelands"] = {
		{name="Chillwind Camp",faction="A",npc="Bibilfaz Featherwhistle",npcid=12596,x=42.92,y=85.06},
	},
	
	["Westfall"] = {
		{name="Sentinel Hill",faction="A",npc="Thor",npcid=523,x=56.55,y=52.64},
	},
	
	["Wetlands"] = {
		{name="Menethil Harbor",faction="A",npc="Shellei Brondir",npcid=1571,x=9.49,y=59.69},
	},
	
	["Isle of Quel'Danas"] = {
		{name="Shattered Sun Staging Area",faction="B",npc="Ohura",npcid=26560,x=48.36,y=25.08},
	},
},



-------------------
--- OUTLAND ---
-------------------
[1945]={
	["Blade\'s Edge Mountains"]={
		{name="Sylvanaar",faction="A",npc="Amerun Leafshade",npcid=18937,x=37.82,y=61.39},
		{name="Toshley's Station",faction="A",npc="Rip Pedalslam",npcid=21107,x=61.15,y=70.44},
		{name="Thunderlord Stronghold",faction="H",npc="Unoke Tenderhoof",npcid=18953,x=52.05,y=54.13},
		{name="Mok'Nathal Village",faction="H",npc="Sky-Master Maxxor",npcid=22455,x=76.37,y=65.93},
		{name="Evergrove",faction="B",npc="Fhyn Leafshadow",npcid=22216,x=61.68,y=39.61},
		{name="Skyguard Outpost",faction="B",factionid=1031,factionstanding=6,npc="Skyguard Handler Irena",npcid=23413,x=28.28,y=52.10,taxioperator="skyguard"},
	},

	["Hellfire Peninsula"]={
		{name="Honor Hold",faction="A",npc="Flightmaster Krill Bitterhue",npcid=16822,x=54.68,y=62.35},
		{name="Shatter Point",faction="A",npc="Runetog Wildhammer",npcid=20234,x=78.42,y=34.90},
		{name="Temple of Telhamat",faction="A",npc="Kuma",npcid=18785,x=25.19,y=37.23},
		{name="Hellfire Peninsula",faction="A",npc="Amish Wildhammer",npcid=18931,x=87.36,y=52.42},
		{name="Falcon Watch",faction="H",npc="Innalia",npcid=18942,x=27.79,y=59.98},
		{name="Spinebreaker Ridge",faction="H",npc="Amilya Airheart",npcid=19558,x=61.65,y=81.19},
		{name="Hellfire Peninsula",faction="H",npc="Vlagga Freyfeather",npcid=18930,x=87.35,y=48.14},
		{name="Thrallmar",faction="H",npc="Barley",npcid=16587,x=56.29,y=36.25},
	},

	["Nagrand"]={
		{name="Telaar",faction="A",npc="Furgu",npcid=18789,x=54.17,y=75.06},
		{name="Garadar",faction="H",npc="Gursha",npcid=18808,x=57.19,y=35.25},
	},

	["Netherstorm"]={
		{name="Area 52",faction="B",npc="Krexcil",npcid=18938,x=33.74,y=63.99},
		{name="Cosmowrench",faction="B",npc="Harpax",npcid=20515,x=65.20,y=66.81},
		{name="The Stormspire",faction="B",npc="Grennik",npcid=19583,x=45.31,y=34.87},
	},

	["Shadowmoon Valley"]={
		{name="Wildhammer Stronghold",faction="A",npc="Brubeck Stormfoot",npcid=18939,x=37.61,y=55.45},
		{name="Shadowmoon Village",faction="H",npc="Drek'Gol",npcid=19317,x=30.34,y=29.19},
		{name="Altar of Sha'tar",faction="B",factionid=932,factionstanding=3,npc="Maddix",npcid=19581,x=63.33,y=30.40,quest=10551},
		{name="Sanctum of the Stars",faction="B",factionid=934,factionstanding=3,npc="Alieshor",npcid=21766,x=56.32,y=57.80,quest=10552},
	},

	["Shattrath City"]={
		{name="Shattrath",faction="B",npc="Nutral",npcid=18940,x=64.07,y=41.12},
	},

	["Terokkar Forest"]={
		{name="Allerian Stronghold",faction="A",npc="Furnan Skysoar",npcid=18809,x=59.45,y=55.43},
		{name="Stonebreaker Hold",faction="H",npc="Kerna",npcid=18807,x=49.19,y=43.42},
		{name="Blackwing Landing",faction="B",factionid=1031,factionstanding=6,npc="Skyguard Handler Deesak",npcid=23415,x=63.50,y=65.81,taxioperator="skyguard"},
	},

	["Zangarmarsh"]={
		{name="Orebor Harborage",faction="A",npc="Halu",npcid=22485,x=41.28,y=29.00},
		{name="Telredor",faction="A",npc="Munci",npcid=18788,x=67.83,y=51.46},
		{name="Swamprat Post",faction="H",npc="Gur'zil",npcid=20762,x=84.76,y=55.11},
		{name="Zabra'jin",faction="H",npc="Du'ga",npcid=18791,x=33.07,y=51.07},
	},
},
}





-- NOTE: If two taxis have the same name but different factions then a factions field must be added in here. See Serpent's Spine.
-- If not then one of the taxis will be marked with the wrong faction so will not properly get neighbors that it should.
-- This data is regenerated when performing a Taxi Connections Dump. Any weird data edits may be lost. 





data.flightcost = {

--------------------
--- KALIMDOR ---
--------------------
	[1414]={
		{
			tag = "005:005",
			nodeID = -5,
			name = "Bashal'Aran",
			taxioperator = "blackcat",
			neighbors = {
				[-2] = 53, -- Lor'danel
			},
		},
		{
			tag = "004:004",
			nodeID = -4,
			name = "Shatterspear Vale",
			taxioperator = "blackcat",
			neighbors = {
				[-1] = 115, -- Lor'danel
			},
		},
		{
			tag = "003:003",
			nodeID = -3,
			name = "Ruins of Mathystra",
			taxioperator = "blackcat",
			neighbors = {
				[-4] = 75, -- Shatterspear Vale
				[-1] = 50, -- Lor'danel
			},
		},
		{
			tag = "002:002",
			nodeID = -2,
			name = "Lor'danel",
			taxioperator = "blackcat",
			neighbors = {
				[-5] = 53, -- Bashal'Aran
			},
		},
		{
			tag = "001:001",
			nodeID = -1,
			name = "Lor'danel",
			taxioperator = "blackcat",
			comment = "black cat ride",
			neighbors = {
				[-3] = 50, -- Ruins of Mathystra
			},
		},
		{
			tag = "462:570",
			nodeID = 22,
			name = "Thunder Bluff",
			faction = "H",
			neighbors = {
				[23] = 208, -- Orgrimmar
				[25] = 103, -- Crossroads
				[29] = 183, -- Sun Rock Retreat
				[30] = 205, -- Freewind Post
				[38] = 179, -- Shadowprey Village
				[40] = 305, -- Gadgetzan
				[42] = 253, -- Camp Mojache
				[44] = 251, -- Valormok
				[55] = 225, -- Brackenwall Village
				[58] = 247, -- Zoram'gar Outpost
				[77] = 87, -- Camp Taurajo
			},
		},
		{
			tag = "581:453",
			nodeID = 23,
			name = "Orgrimmar",
			faction = "H",
			neighbors = {
				[22] = 208, -- Thunder Bluff
				[25] = 117, -- Crossroads
				[40] = 418, -- Gadgetzan
				[44] = 96, -- Valormok
				[48] = 253, -- Bloodvenom Post
				[53] = 244, -- Everlook
				[55] = 218, -- Brackenwall Village
				[61] = 90, -- Splintertree Post
				[80] = 108, -- Ratchet
			},
		},
		{
			tag = "534:539",
			nodeID = 25,
			name = "Crossroads",
			faction = "H",
			neighbors = {
				[22] = 107, -- Thunder Bluff
				[23] = 117, -- Orgrimmar
				[29] = 151, -- Sun Rock Retreat
				[30] = 186, -- Freewind Post
				[40] = 304, -- Gadgetzan
				[42] = 265, -- Camp Mojache
				[44] = 165, -- Valormok
				[48] = 242, -- Bloodvenom Post
				[55] = 163, -- Brackenwall Village
				[58] = 232, -- Zoram'gar Outpost
				[61] = 161, -- Splintertree Post
				[77] = 79, -- Camp Taurajo
				[80] = 69, -- Ratchet
			},
		},
		{
			tag = "448:263",
			nodeID = 26,
			name = "Auberdine",
			faction = "A",
			neighbors = {
				[27] = 85, -- Rut'theran Village
				[28] = 149, -- Astranaar
				[32] = 440, -- Theramore
				[33] = 182, -- Stonetalon Peak
				[37] = 292, -- Nijel's Point
				[41] = 473, -- Feathermoon
				[49] = 152, -- Moonglade
				[64] = 302, -- Talrendis Point
				[65] = 191, -- Talonbranch Glade
			},
		},
		{
			tag = "440:169",
			nodeID = 27,
			name = "Rut'theran Village",
			faction = "A",
			neighbors = {
				[26] = 86, -- Auberdine
			},
		},
		{
			tag = "471:406",
			nodeID = 28,
			name = "Astranaar",
			faction = "A",
			neighbors = {
				[26] = 150, -- Auberdine
				[32] = 389, -- Theramore
				[33] = 155, -- Stonetalon Peak
				[64] = 149, -- Talrendis Point
				[80] = 194, -- Ratchet
				[166] = 79, -- Emerald Sanctuary
				[167] = 142, -- Forest Song
			},
		},
		{
			tag = "435:482",
			nodeID = 29,
			name = "Sun Rock Retreat",
			faction = "H",
			neighbors = {
				[22] = 183, -- Thunder Bluff
				[25] = 151, -- Crossroads
				[38] = 144, -- Shadowprey Village
				[58] = 122, -- Zoram'gar Outpost
			},
		},
		{
			tag = "529:742",
			nodeID = 30,
			name = "Freewind Post",
			faction = "H",
			neighbors = {
				[22] = 205, -- Thunder Bluff
				[25] = 186, -- Crossroads
				[40] = 87, -- Gadgetzan
				[42] = 124, -- Camp Mojache
				[55] = 96, -- Brackenwall Village
				[77] = 126, -- Camp Taurajo
				[179] = 70, -- Mudsprocket
			},
		},
		{
			tag = "484:704",
			nodeID = 31,
			name = "Thalanaar",
			faction = "A",
			neighbors = {
				[32] = 161, -- Theramore
				[39] = 178, -- Gadgetzan
				[41] = 179, -- Feathermoon
				[179] = 87, -- Mudsprocket
			},
		},
		{
			tag = "586:677",
			nodeID = 32,
			name = "Theramore",
			faction = "A",
			neighbors = {
				[26] = 440, -- Auberdine
				[28] = 370, -- Astranaar
				[31] = 164, -- Thalanaar
				[37] = 308, -- Nijel's Point
				[39] = 157, -- Gadgetzan
				[64] = 234, -- Talrendis Point
				[80] = 116, -- Ratchet
				[179] = 53, -- Mudsprocket
			},
		},
		{
			tag = "424:412",
			nodeID = 33,
			name = "Stonetalon Peak",
			faction = "A",
			neighbors = {
				[26] = 182, -- Auberdine
				[28] = 155, -- Astranaar
				[37] = 120, -- Nijel's Point
			},
		},
		{
			tag = "427:516",
			nodeID = 37,
			name = "Nijel's Point",
			faction = "A",
			neighbors = {
				[26] = 292, -- Auberdine
				[32] = 308, -- Theramore
				[33] = 120, -- Stonetalon Peak
				[41] = 228, -- Feathermoon
			},
		},
		{
			tag = "375:593",
			nodeID = 38,
			name = "Shadowprey Village",
			faction = "H",
			neighbors = {
				[22] = 179, -- Thunder Bluff
				[29] = 144, -- Sun Rock Retreat
				[42] = 197, -- Camp Mojache
			},
		},
		{
			tag = "565:816",
			nodeID = 39,
			name = "Gadgetzan",
			faction = "A",
			neighbors = {
				[31] = 178, -- Thalanaar
				[32] = 157, -- Theramore
				[73] = 198, -- Cenarion Hold
				[79] = 104, -- Marshal's Refuge
				[80] = 246, -- Ratchet
			},
		},
		{
			tag = "566:809",
			nodeID = 40,
			name = "Gadgetzan",
			faction = "H",
			neighbors = {
				[22] = 305, -- Thunder Bluff
				[23] = 418, -- Orgrimmar
				[25] = 304, -- Crossroads
				[30] = 87, -- Freewind Post
				[42] = 202, -- Camp Mojache
				[55] = 194, -- Brackenwall Village
				[72] = 242, -- Cenarion Hold
				[79] = 108, -- Marshal's Refuge
				[80] = 244, -- Ratchet
			},
		},
		{
			tag = "373:700",
			nodeID = 41,
			name = "Feathermoon",
			faction = "A",
			neighbors = {
				[26] = 473, -- Auberdine
				[31] = 179, -- Thalanaar
				[37] = 228, -- Nijel's Point
				[73] = 154, -- Cenarion Hold
			},
		},
		{
			tag = "458:701",
			nodeID = 42,
			name = "Camp Mojache",
			faction = "H",
			neighbors = {
				[22] = 253, -- Thunder Bluff
				[25] = 265, -- Crossroads
				[30] = 124, -- Freewind Post
				[38] = 201, -- Shadowprey Village
				[40] = 202, -- Gadgetzan
				[72] = 131, -- Cenarion Hold
			},
		},
		{
			tag = "583:372",
			nodeID = 44,
			name = "Valormok",
			faction = "H",
			neighbors = {
				[22] = 251, -- Thunder Bluff
				[23] = 96, -- Orgrimmar
				[25] = 165, -- Crossroads
				[48] = 235, -- Bloodvenom Post
				[53] = 131, -- Everlook
				[61] = 94, -- Splintertree Post
			},
		},
		{
			tag = "472:315",
			nodeID = 48,
			name = "Bloodvenom Post",
			faction = "H",
			neighbors = {
				[23] = 253, -- Orgrimmar
				[25] = 242, -- Crossroads
				[44] = 235, -- Valormok
				[53] = 196, -- Everlook
				[58] = 138, -- Zoram'gar Outpost
				[69] = 166, -- Moonglade
				[166] = 80, -- Emerald Sanctuary
			},
		},
		{
			tag = "531:217",
			nodeID = 49,
			name = "Moonglade",
			faction = "A",
			neighbors = {
				[26] = 143, -- Auberdine
				[52] = 120, -- Everlook
				[65] = 68, -- Talonbranch Glade
			},
		},
		{
			tag = "592:244",
			nodeID = 52,
			name = "Everlook",
			faction = "A",
			neighbors = {
				[49] = 120, -- Moonglade
				[64] = 168, -- Talrendis Point
				[65] = 108, -- Talonbranch Glade
			},
		},
		{
			tag = "589:244",
			nodeID = 53,
			name = "Everlook",
			faction = "H",
			neighbors = {
				[23] = 244, -- Orgrimmar
				[44] = 131, -- Valormok
				[48] = 196, -- Bloodvenom Post
				[69] = 142, -- Moonglade
			},
		},
		{
			tag = "541:650",
			nodeID = 55,
			name = "Brackenwall Village",
			faction = "H",
			neighbors = {
				[22] = 225, -- Thunder Bluff
				[23] = 218, -- Orgrimmar
				[25] = 163, -- Crossroads
				[30] = 96, -- Freewind Post
				[40] = 206, -- Gadgetzan
				[77] = 50, -- Camp Taurajo
				[80] = 90, -- Ratchet
				[179] = 64, -- Mudsprocket
			},
		},
		{
			tag = "436:384",
			nodeID = 58,
			name = "Zoram'gar Outpost",
			faction = "H",
			neighbors = {
				[22] = 247, -- Thunder Bluff
				[25] = 232, -- Crossroads
				[29] = 122, -- Sun Rock Retreat
				[48] = 138, -- Bloodvenom Post
				[61] = 167, -- Splintertree Post
				[166] = 123, -- Emerald Sanctuary
			},
		},
		{
			tag = "532:427",
			nodeID = 61,
			name = "Splintertree Post",
			faction = "H",
			neighbors = {
				[23] = 90, -- Orgrimmar
				[25] = 161, -- Crossroads
				[44] = 95, -- Valormok
				[58] = 167, -- Zoram'gar Outpost
				[166] = 85, -- Emerald Sanctuary
			},
		},
		{
			nodeID = 62,
			name = "Nighthaven",
			faction = "A",
			neighbors = {
				[27] = 154, -- Rut'theran Village
			},
		},
		{
			nodeID = 63,
			name = "Nighthaven",
			faction = "H",
			neighbors = {
				[22] = 401, -- Thunder Bluff
			},
		},
		{
			tag = "569:410",
			nodeID = 64,
			name = "Talrendis Point",
			faction = "A",
			neighbors = {
				[26] = 302, -- Auberdine
				[28] = 149, -- Astranaar
				[32] = 234, -- Theramore
				[52] = 168, -- Everlook
				[65] = 284, -- Talonbranch Glade
				[80] = 137, -- Ratchet
				[167] = 27, -- Forest Song
			},
		},
		{
			tag = "516:268",
			nodeID = 65,
			name = "Talonbranch Glade",
			faction = "A",
			neighbors = {
				[26] = 191, -- Auberdine
				[49] = 68, -- Moonglade
				[52] = 108, -- Everlook
				[64] = 284, -- Talrendis Point
				[166] = 129, -- Emerald Sanctuary
			},
		},
		{
			tag = "521:217",
			nodeID = 69,
			name = "Moonglade",
			faction = "H",
			neighbors = {
				[48] = 166, -- Bloodvenom Post
				[53] = 142, -- Everlook
			},
		},
		{
			tag = "441:799",
			nodeID = 72,
			name = "Cenarion Hold",
			faction = "H",
			neighbors = {
				[40] = 242, -- Gadgetzan
				[42] = 131, -- Camp Mojache
				[79] = 101, -- Marshal's Refuge
			},
		},
		{
			tag = "442:797",
			nodeID = 73,
			name = "Cenarion Hold",
			faction = "A",
			neighbors = {
				[39] = 198, -- Gadgetzan
				[41] = 154, -- Feathermoon
				[79] = 93, -- Marshal's Refuge
			},
		},
		{
			tag = "514:618",
			nodeID = 77,
			name = "Camp Taurajo",
			faction = "H",
			neighbors = {
				[22] = 87, -- Thunder Bluff
				[25] = 79, -- Crossroads
				[30] = 126, -- Freewind Post
				[55] = 61, -- Brackenwall Village
			},
		},
		{
			tag = "494:770",
			nodeID = 79,
			name = "Marshal's Refuge",
			neighbors = {
				[39] = 104, -- Gadgetzan
				[40] = 108, -- Gadgetzan
				[72] = 101, -- Cenarion Hold
				[73] = 93, -- Cenarion Hold
			},
		},
		{
			tag = "566:558",
			nodeID = 80,
			name = "Ratchet",
			neighbors = {
				[23] = 108, -- Orgrimmar
				[25] = 69, -- Crossroads
				[28] = 198, -- Astranaar
				[32] = 106, -- Theramore
				[39] = 246, -- Gadgetzan
				[40] = 242, -- Gadgetzan
				[55] = 90, -- Brackenwall Village
				[64] = 137, -- Talrendis Point
			},
		},
		{
			tag = "310:182",
			nodeID = 93,
			name = "Blood Watch",
			faction = "A",
			neighbors = {
				[94] = 78, -- The Exodar
			},
		},
		{
			tag = "305:270",
			nodeID = 94,
			name = "The Exodar",
			faction = "A",
			neighbors = {
				[93] = 78, -- Blood Watch
			},
		},
		{
			tag = "499:359",
			nodeID = 166,
			name = "Emerald Sanctuary",
			neighbors = {
				[28] = 81, -- Astranaar
				[48] = 80, -- Bloodvenom Post
				[58] = 115, -- Zoram'gar Outpost
				[61] = 84, -- Splintertree Post
				[65] = 129, -- Talonbranch Glade
				[167] = 104, -- Forest Song
			},
		},
		{
			tag = "550:399",
			nodeID = 167,
			name = "Forest Song",
			faction = "A",
			neighbors = {
				[28] = 142, -- Astranaar
				[64] = 29, -- Talrendis Point
				[166] = 111, -- Emerald Sanctuary
			},
		},
		{
			tag = "551:707",
			nodeID = 179,
			name = "Mudsprocket",
			neighbors = {
				[30] = 70, -- Freewind Post
				[31] = 106, -- Thalanaar
				[32] = 53, -- Theramore
				[55] = 64, -- Brackenwall Village
			},
		},
	},

----------------------------
--- EASTERN KINGDOMS ---
----------------------------
	[1415]={
		{
			tag = "434:737",
			nodeID = 2,
			name = "Stormwind",
			faction = "A",
			neighbors = {
				[4] = 79, -- Sentinel Hill
				[5] = 113, -- Lakeshire
				[6] = 216, -- Ironforge
				[12] = 117, -- Darkshire
				[19] = 200, -- Booty Bay
				[45] = 177, -- Nethergarde Keep
				[71] = 154, -- Morgan's Vigil
				[74] = 126, -- Thorium Point
				[195] = 93, -- Rebel Camp
			},
		},
		{
			tag = "420:803",
			nodeID = 4,
			name = "Sentinel Hill",
			faction = "A",
			neighbors = {
				[2] = 79, -- Stormwind
				[5] = 131, -- Lakeshire
				[12] = 97, -- Darkshire
				[19] = 149, -- Booty Bay
				[195] = 67, -- Rebel Camp
			},
		},
		{
			tag = "500:758",
			nodeID = 5,
			name = "Lakeshire",
			faction = "A",
			neighbors = {
				[2] = 113, -- Stormwind
				[4] = 131, -- Sentinel Hill
				[12] = 61, -- Darkshire
				[71] = 64, -- Morgan's Vigil
			},
		},
		{
			tag = "474:589",
			nodeID = 6,
			name = "Ironforge",
			faction = "A",
			neighbors = {
				[2] = 211, -- Stormwind
				[7] = 115, -- Menethil Harbor
				[8] = 102, -- Thelsamar
				[14] = 217, -- Southshore
				[16] = 204, -- Refuge Pointe
				[43] = 256, -- Aerie Peak
				[66] = 260, -- Chillwind Camp
				[67] = 107, -- Light's Hope Chapel
				[74] = 86, -- Thorium Point
				[213] = 99, -- Shattered Sun Staging Area
			},
		},
		{
			tag = "465:551",
			nodeID = 7,
			name = "Menethil Harbor",
			faction = "A",
			neighbors = {
				[6] = 90, -- Ironforge
				[8] = 153, -- Thelsamar
				[14] = 108, -- Southshore
				[16] = 127, -- Refuge Pointe
			},
		},
		{
			tag = "517:611",
			nodeID = 8,
			name = "Thelsamar",
			faction = "A",
			neighbors = {
				[6] = 102, -- Ironforge
				[7] = 153, -- Menethil Harbor
				[16] = 172, -- Refuge Pointe
				[74] = 83, -- Thorium Point
			},
		},
		{
			tag = "408:394",
			nodeID = 10,
			name = "The Sepulcher",
			faction = "H",
			neighbors = {
				[11] = 113, -- Undercity
				[13] = 96, -- Tarren Mill
			},
		},
		{
			tag = "439:353",
			nodeID = 11,
			name = "Undercity",
			faction = "H",
			neighbors = {
				[10] = 107, -- The Sepulcher
				[13] = 140, -- Tarren Mill
				[17] = 301, -- Hammerfall
				[21] = 489, -- Kargath
				[68] = 262, -- Light's Hope Chapel
				[76] = 285, -- Revantusk Village
			},
		},
		{
			tag = "477:798",
			nodeID = 12,
			name = "Darkshire",
			faction = "A",
			neighbors = {
				[2] = 117, -- Stormwind
				[4] = 97, -- Sentinel Hill
				[5] = 61, -- Lakeshire
				[19] = 173, -- Booty Bay
				[45] = 98, -- Nethergarde Keep
				[195] = 49, -- Rebel Camp
			},
		},
		{
			tag = "467:411",
			nodeID = 13,
			name = "Tarren Mill",
			faction = "H",
			neighbors = {
				[10] = 96, -- The Sepulcher
				[11] = 140, -- Undercity
				[17] = 119, -- Hammerfall
				[76] = 160, -- Revantusk Village
			},
		},
		{
			tag = "458:437",
			nodeID = 14,
			name = "Southshore",
			faction = "A",
			neighbors = {
				[6] = 217, -- Ironforge
				[7] = 108, -- Menethil Harbor
				[16] = 74, -- Refuge Pointe
				[43] = 72, -- Aerie Peak
				[66] = 82, -- Chillwind Camp
			},
		},
		{
			tag = "507:457",
			nodeID = 16,
			name = "Refuge Pointe",
			faction = "A",
			neighbors = {
				[6] = 204, -- Ironforge
				[7] = 127, -- Menethil Harbor
				[8] = 172, -- Thelsamar
				[14] = 88, -- Southshore
				[43] = 77, -- Aerie Peak
			},
		},
		{
			tag = "531:445",
			nodeID = 17,
			name = "Hammerfall",
			faction = "H",
			neighbors = {
				[11] = 301, -- Undercity
				[13] = 119, -- Tarren Mill
				[21] = 259, -- Kargath
				[76] = 91, -- Revantusk Village
			},
		},
		{
			tag = "433:943",
			nodeID = 18,
			name = "Booty Bay",
			faction = "H",
			neighbors = {
				[20] = 79, -- Grom'gol
				[21] = 315, -- Kargath
				[56] = 231, -- Stonard
			},
		},
		{
			tag = "434:944",
			nodeID = 19,
			name = "Booty Bay",
			faction = "A",
			neighbors = {
				[2] = 200, -- Stormwind
				[4] = 149, -- Sentinel Hill
				[12] = 173, -- Darkshire
				[195] = 117, -- Rebel Camp
			},
		},
		{
			tag = "442:868",
			nodeID = 20,
			name = "Grom'gol",
			faction = "H",
			neighbors = {
				[18] = 79, -- Booty Bay
				[21] = 239, -- Kargath
				[56] = 174, -- Stonard
				[70] = 207, -- Flame Crest
			},
		},
		{
			tag = "499:656",
			nodeID = 21,
			name = "Kargath",
			faction = "H",
			neighbors = {
				[11] = 498, -- Undercity
				[17] = 259, -- Hammerfall
				[18] = 315, -- Booty Bay
				[20] = 239, -- Grom'gol
				[56] = 232, -- Stonard
				[70] = 69, -- Flame Crest
				[75] = 57, -- Thorium Point
			},
		},
		{
			tag = "495:401",
			nodeID = 43,
			name = "Aerie Peak",
			faction = "A",
			neighbors = {
				[6] = 256, -- Ironforge
				[14] = 72, -- Southshore
				[16] = 77, -- Refuge Pointe
				[66] = 54, -- Chillwind Camp
				[67] = 163, -- Light's Hope Chapel
			},
		},
		{
			tag = "530:820",
			nodeID = 45,
			name = "Nethergarde Keep",
			faction = "A",
			neighbors = {
				[2] = 177, -- Stormwind
				[12] = 98, -- Darkshire
				[71] = 209, -- Morgan's Vigil
			},
		},
		{
			tag = "526:796",
			nodeID = 56,
			name = "Stonard",
			faction = "H",
			neighbors = {
				[18] = 231, -- Booty Bay
				[20] = 174, -- Grom'gol
				[21] = 232, -- Kargath
				[70] = 192, -- Flame Crest
			},
		},
		{
			tag = "481:377",
			nodeID = 66,
			name = "Chillwind Camp",
			faction = "A",
			neighbors = {
				[6] = 260, -- Ironforge
				[14] = 82, -- Southshore
				[43] = 54, -- Aerie Peak
				[67] = 147, -- Light's Hope Chapel
			},
		},
		{
			tag = "577:328",
			nodeID = 67,
			name = "Light's Hope Chapel",
			faction = "A",
			neighbors = {
				[6] = 349, -- Ironforge
				[43] = 164, -- Aerie Peak
				[66] = 147, -- Chillwind Camp
				[205] = 107, -- Zul'Aman
				[213] = 339, -- Shattered Sun Staging Area
			},
		},
		{
			tag = "575:325",
			nodeID = 68,
			name = "Light's Hope Chapel",
			faction = "H",
			neighbors = {
				[11] = 262, -- Undercity
				[76] = 140, -- Revantusk Village
				[83] = 119, -- Tranquillien
				[205] = 97, -- Zul'Aman
			},
		},
		{
			tag = "499:688",
			nodeID = 70,
			name = "Flame Crest",
			faction = "H",
			neighbors = {
				[20] = 207, -- Grom'gol
				[21] = 69, -- Kargath
				[56] = 193, -- Stonard
				[75] = 61, -- Thorium Point
			},
		},
		{
			tag = "513:719",
			nodeID = 71,
			name = "Morgan's Vigil",
			faction = "A",
			neighbors = {
				[2] = 154, -- Stormwind
				[5] = 64, -- Lakeshire
				[45] = 209, -- Nethergarde Keep
				[74] = 91, -- Thorium Point
			},
		},
		{
			tag = "474:653",
			nodeID = 74,
			name = "Thorium Point",
			faction = "A",
			neighbors = {
				[2] = 126, -- Stormwind
				[6] = 86, -- Ironforge
				[8] = 83, -- Thelsamar
				[71] = 91, -- Morgan's Vigil
			},
		},
		{
			tag = "473:653",
			nodeID = 75,
			name = "Thorium Point",
			faction = "H",
			neighbors = {
				[21] = 57, -- Kargath
				[70] = 61, -- Flame Crest
			},
		},
		{
			tag = "561:435",
			nodeID = 76,
			name = "Revantusk Village",
			faction = "H",
			neighbors = {
				[11] = 285, -- Undercity
				[13] = 160, -- Tarren Mill
				[17] = 91, -- Hammerfall
				[68] = 140, -- Light's Hope Chapel
			},
		},
		{
			tag = "564:154",
			nodeID = 82,
			name = "Silvermoon City",
			faction = "H",
			neighbors = {
				[83] = 66, -- Tranquillien
				[213] = 167, -- Shattered Sun Staging Area
			},
		},
		{
			tag = "555:220",
			nodeID = 83,
			name = "Tranquillien",
			faction = "H",
			neighbors = {
				[68] = 116, -- Light's Hope Chapel
				[82] = 66, -- Silvermoon City
				[205] = 52, -- Zul'Aman
			},
		},
		{
			tag = "451:829",
			nodeID = 195,
			name = "Rebel Camp",
			faction = "A",
			neighbors = {
				[2] = 93, -- Stormwind
				[4] = 67, -- Sentinel Hill
				[12] = 49, -- Darkshire
				[19] = 116, -- Booty Bay
			},
		},
		{
			tag = "579:249",
			nodeID = 205,
			name = "Zul'Aman",
			neighbors = {
				[67] = 107, -- Light's Hope Chapel
				[68] = 97, -- Light's Hope Chapel
				[83] = 52, -- Tranquillien
				[213] = 233, -- Shattered Sun Staging Area
			},
		},
		{
			tag = "558:020",
			nodeID = 213,
			name = "Shattered Sun Staging Area",
			neighbors = {
				[6] = 99, -- Ironforge
				[67] = 339, -- Light's Hope Chapel
				[82] = 167, -- Silvermoon City
				[205] = 233, -- Zul'Aman
			},
		},
	},

-------------------
--- OUTLAND ---
-------------------
	[1945]={
		{
			tag = "002:002",
			nodeID = -7,
			name = "Blackwing Landing, Terokkar Forest",
			taxioperator = "skyguard",
			neighbors = {
				[-6] = 245, -- Skyguard Outpost, Blade's Edge Mountains
			},
		},
		{
			tag = "001:001",
			nodeID = -6,
			name = "Skyguard Outpost, Blade's Edge Mountains",
			taxioperator = "skyguard",
			neighbors = {
				[-7] = 245, -- Blackwing Landing, Terokkar Forest
			},
		},
		{
			tag = "593:480",
			nodeID = 99,
			name = "Thrallmar",
			faction = "H",
			neighbors = {
				[102] = 68, -- Falcon Watch
				[127] = 126, -- Stonebreaker Hold
				[130] = 71, -- Hellfire Peninsula
				[141] = 63, -- Spinebreaker Ridge
			},
		},
		{
			tag = "588:557",
			nodeID = 100,
			name = "Honor Hold",
			faction = "A",
			neighbors = {
				[101] = 77, -- Temple of Telhamat
				[121] = 97, -- Allerian Stronghold
				[128] = 58, -- Shattrath
				[129] = 66, -- Hellfire Peninsula
				[149] = 57, -- Shatter Point
			},
		},
		{
			tag = "501:482",
			nodeID = 101,
			name = "Temple of Telhamat",
			faction = "A",
			neighbors = {
				[100] = 88, -- Honor Hold
				[117] = 82, -- Telredor
				[129] = 116, -- Hellfire Peninsula
			},
		},
		{
			tag = "509:550",
			nodeID = 102,
			name = "Falcon Watch",
			faction = "H",
			neighbors = {
				[99] = 68, -- Thrallmar
				[118] = 148, -- Zabra'jin
				[120] = 133, -- Garadar
				[128] = 73, -- Shattrath
				[130] = 123, -- Hellfire Peninsula
				[151] = 69, -- Swamprat Post
			},
		},
		{
			tag = "396:481",
			nodeID = 117,
			name = "Telredor",
			faction = "A",
			neighbors = {
				[101] = 82, -- Temple of Telhamat
				[119] = 125, -- Telaar
				[125] = 92, -- Sylvanaar
				[128] = 85, -- Shattrath
				[156] = 70, -- Toshley's Station
				[164] = 54, -- Orebor Harborage
			},
		},
		{
			tag = "296:481",
			nodeID = 118,
			name = "Zabra'jin",
			faction = "H",
			neighbors = {
				[102] = 148, -- Falcon Watch
				[120] = 82, -- Garadar
				[126] = 149, -- Thunderlord Stronghold
				[128] = 137, -- Shattrath
				[151] = 113, -- Swamprat Post
			},
		},
		{
			tag = "325:734",
			nodeID = 119,
			name = "Telaar",
			faction = "A",
			neighbors = {
				[117] = 125, -- Telredor
				[121] = 123, -- Allerian Stronghold
				[128] = 89, -- Shattrath
			},
		},
		{
			tag = "335:608",
			nodeID = 120,
			name = "Garadar",
			faction = "H",
			neighbors = {
				[102] = 133, -- Falcon Watch
				[118] = 68, -- Zabra'jin
				[128] = 77, -- Shattrath
			},
		},
		{
			tag = "522:756",
			nodeID = 121,
			name = "Allerian Stronghold",
			faction = "A",
			neighbors = {
				[100] = 97, -- Honor Hold
				[119] = 123, -- Telaar
				[124] = 102, -- Wildhammer Stronghold
				[128] = 75, -- Shattrath
			},
		},
		{
			tag = "538:235",
			nodeID = 122,
			name = "Area 52",
			neighbors = {
				[125] = 120, -- Sylvanaar
				[126] = 97, -- Thunderlord Stronghold
				[139] = 48, -- The Stormspire
				[150] = 65, -- Cosmowrench
				[156] = 94, -- Toshley's Station
				[160] = 82, -- Evergrove
				[163] = 65, -- Mok'Nathal Village
			},
		},
		{
			tag = "597:759",
			nodeID = 123,
			name = "Shadowmoon Village",
			faction = "H",
			neighbors = {
				[127] = 74, -- Stonebreaker Hold
				[140] = 84, -- Altar of Sha'tar, Shadowmoon Valley
				[159] = 62, -- Sanctum of the Stars
			},
		},
		{
			tag = "620:842",
			nodeID = 124,
			name = "Wildhammer Stronghold",
			faction = "A",
			neighbors = {
				[121] = 102, -- Allerian Stronghold
				[140] = 84, -- Altar of Sha'tar, Shadowmoon Valley
				[159] = 43, -- Sanctum of the Stars
			},
		},
		{
			tag = "355:312",
			nodeID = 125,
			name = "Sylvanaar",
			faction = "A",
			neighbors = {
				[117] = 92, -- Telredor
				[122] = 120, -- Area 52
				[139] = 155, -- The Stormspire
				[156] = 60, -- Toshley's Station
				[160] = 52, -- Evergrove
				[164] = 76, -- Orebor Harborage
			},
		},
		{
			tag = "399:289",
			nodeID = 126,
			name = "Thunderlord Stronghold",
			faction = "H",
			neighbors = {
				[118] = 149, -- Zabra'jin
				[122] = 97, -- Area 52
				[139] = 159, -- The Stormspire
				[151] = 107, -- Swamprat Post
				[160] = 27, -- Evergrove
				[163] = 56, -- Mok'Nathal Village
			},
		},
		{
			tag = "490:720",
			nodeID = 127,
			name = "Stonebreaker Hold",
			faction = "H",
			neighbors = {
				[99] = 126, -- Thrallmar
				[123] = 69, -- Shadowmoon Village
				[128] = 70, -- Shattrath
			},
		},
		{
			tag = "440:657",
			nodeID = 128,
			name = "Shattrath",
			neighbors = {
				[100] = 58, -- Honor Hold
				[102] = 78, -- Falcon Watch
				[117] = 85, -- Telredor
				[118] = 137, -- Zabra'jin
				[119] = 89, -- Telaar
				[120] = 77, -- Garadar
				[121] = 75, -- Allerian Stronghold
				[127] = 69, -- Stonebreaker Hold
				[151] = 87, -- Swamprat Post
			},
		},
		{
			tag = "685:528",
			nodeID = 129,
			name = "Hellfire Peninsula",
			faction = "A",
			neighbors = {
				[100] = 66, -- Honor Hold
				[101] = 116, -- Temple of Telhamat
				[149] = 33, -- Shatter Point
			},
		},
		{
			tag = "685:515",
			nodeID = 130,
			name = "Hellfire Peninsula",
			faction = "H",
			neighbors = {
				[99] = 71, -- Thrallmar
				[102] = 123, -- Falcon Watch
			},
		},
		{
			tag = "574:142",
			nodeID = 139,
			name = "The Stormspire",
			neighbors = {
				[122] = 48, -- Area 52
				[125] = 155, -- Sylvanaar
				[126] = 159, -- Thunderlord Stronghold
				[150] = 70, -- Cosmowrench
			},
		},
		{
			tag = "000:000",
			nodeID = 140,
			name = "Altar of Sha'tar, Shadowmoon Valley",
			neighbors = {
				[123] = 68, -- Shadowmoon Village
				[124] = 81, -- Wildhammer Stronghold
			},
		},
		{
			tag = "609:613",
			nodeID = 141,
			name = "Spinebreaker Ridge",
			faction = "H",
			neighbors = {
				[99] = 63, -- Thrallmar
			},
		},
		{
			tag = "659:476",
			nodeID = 149,
			name = "Shatter Point",
			neighbors = {
				[100] = 57, -- Honor Hold
				[129] = 33, -- Hellfire Peninsula
			},
		},
		{
			tag = "638:244",
			nodeID = 150,
			name = "Cosmowrench",
			neighbors = {
				[122] = 65, -- Area 52
				[139] = 70, -- The Stormspire
			},
		},
		{
			tag = "445:492",
			nodeID = 151,
			name = "Swamprat Post",
			faction = "H",
			neighbors = {
				[102] = 70, -- Falcon Watch
				[118] = 113, -- Zabra'jin
				[126] = 107, -- Thunderlord Stronghold
				[128] = 87, -- Shattrath
				[163] = 72, -- Mok'Nathal Village
			},
		},
		{
			tag = "427:340",
			nodeID = 156,
			name = "Toshley's Station",
			faction = "A",
			neighbors = {
				[117] = 73, -- Telredor
				[122] = 84, -- Area 52
				[125] = 60, -- Sylvanaar
				[160] = 45, -- Evergrove
			},
		},
		{
			tag = "000:000",
			nodeID = 159,
			name = "Sanctum of the Stars",
			neighbors = {
				[123] = 62, -- Shadowmoon Village
				[124] = 43, -- Wildhammer Stronghold
			},
		},
		{
			tag = "429:244",
			nodeID = 160,
			name = "Evergrove",
			neighbors = {
				[122] = 82, -- Area 52
				[125] = 52, -- Sylvanaar
				[126] = 37, -- Thunderlord Stronghold
				[156] = 45, -- Toshley's Station
			},
		},
		{
			tag = "474:325",
			nodeID = 163,
			name = "Mok'Nathal Village",
			faction = "H",
			neighbors = {
				[122] = 65, -- Area 52
				[126] = 63, -- Thunderlord Stronghold
				[151] = 72, -- Swamprat Post
			},
		},
		{
			tag = "320:416",
			nodeID = 164,
			name = "Orebor Harborage",
			faction = "A",
			neighbors = {
				[117] = 54, -- Telredor
				[125] = 76, -- Sylvanaar
			},
		},
	},

}
