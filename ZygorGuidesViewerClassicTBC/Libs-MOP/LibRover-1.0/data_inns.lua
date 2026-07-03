local name,addon = ...

addon.LibRoverData = addon.LibRoverData or {}
local data=addon.LibRoverData

data.basenodes.inns = {
	


	----------------------------
	-----  PANDARIA  -----
	----------------------------

	["The Jade Forest"]={
		{name="The Drunken Hozen",faction="B",npc="Peiji Goldendraft",npcid=55809,x=45.71,y=43.70},
		{name="Dawn's Blossom",faction="B",npc="Lin Wildfur",npcid=55233,x=45.7,y=43.9},
		{name="Paur's Pub",faction="B",npc="Bolo the Elder",npcid=62867,x=41.7,y=23.2},
		{name="Jade Temple Grounds",faction="B",npc="Fela Woodear",npcid=57313,x=54.6,y=63.2},
		{name="Sri-La Village",faction="B",npc="Lana the Sea Breeze",npcid=62868,x=55.8,y=24.4},
		{name="Paw'don Village",faction="A",npc="Jiayi Applebloom",npcid=371,x=44.9,y=84.4},
		{name="Pearlfin Village",faction="A",npc="Cheerful Jessu",npcid=61599,x=59.6,y=83.2},
		{name="Honeydew Village",faction="H",npc="Brewmother Kiki",npcid=700,x=28.5,y=13.3},
		{name="Grookin Hill",faction="H",npc="Grookin Bed-Haver",npcid=62975,x=28.0,y=47.4},
	},

	["Krasarang Wilds"]={
		{name="Wilds' Edge Inn",faction="B",npc="Rude Sho",npcid=62879,x=75.8,y=7.3},
		{name="The Incursion",faction="A",npc="Magister Xintar",npcid=58926,x=67.3,y=33.0},
		{name="Crane Wing Refuge",faction="B",npc="Ni the Merciful",npcid=62869,x=40.8,y=34.5},
		{name="Sentinel Basecamp",faction="A",npc="Magister Xintar",npcid=58926,x=25.5,y=33.2},
		{name="Krasarang Cove",faction="A",npc="Keeper Jaril",npcid=69088,x=88.8,y=35.3},
		{name="Marista's Bair & Brew",faction="B",npc="Cranfur the Noodler",npcid=62872,x=51.5,y=77.2},
		{name="Thunder Cleft",faction="H",npc="Malaya Dawnchaser",npcid=58184,x=60.9,y=24.9},
		{name="Dawnchaser Retreat",faction="H",npc="Aizra Dawnchaser",npcid=62967,x=28.3,y=50.8},
		{name="Horde Landing Site",faction="H",npc="Tonak",npcid=61122,x=10.8,y=52.3},
	},

	["Valley of the Four Winds"]={
		{name="Pang's Stead",faction="B",npc="Nan Thunderfoot",npcid=65528,x=83.7,y=20.2},
		{name="The Lazy Turnip",faction="B",npc="Innkeeper Lei Lan",npcid=59582,x=55.1,y=50.3},
		{name="Stone Mug Tavern",faction="B",npc="Nan the Mason Mug",npcid=62878,x=19.7,y=55.9},
		{name="Sunsong Ranch",faction="B",npc="Farmer's Journal",npcid=70585,x=52.7,y=47.9},
		{name="Thunderfoot Inn",faction="B",npc="Nan Thunderfoot",npcid=65528,x=83.7,y=20.3},
	},

	["Vale of Eternal Blossoms"]={
		{name="The Golden Rose",faction="B",npc="Bartender Tomro",npcid=58691,x=35.34,y=77.64},
	},


	["Shrine of Seven Stars"]={
		{name="The Golden Lantern",f=1,faction="A",npc="Matron Vi Vinh",npcid=64149,x=36.38,y=66.70},
	},

	["Shrine of Two Moons"]={
		{name="Summer's Rest",f=1,faction="H",npc="Madam Vee Luo",npcid=62996,x=68.42,y=47.72},
		{name="Hall of the Crescent Moon",f=2,faction="H",npc="Brewmaster Skye",npcid=63008,x=60.30,y=77.09},
	},

	["The Veiled Stair"]={
		{name="Tavern in the Mists",faction="B",npc="Tong the Fixer",npcid=62917,x=55.0,y=72.4},
	},

	["Kun-Lai Summit"]={
		{name="Binan Brew & Stew",faction="B",npc="Puli the Even Handed",npcid=62871,x=72.7,y=92.3},
		{name="Westwind Rest",faction="A",npc="Kai the Restless",npcid=62882,x=54.1,y=82.9},
		{name="The Two Fisted Brew",faction="B",npc="Li Goldendraft",npcid=59405,x=64.2,y=61.4},
		{name="The Lucky Traveller",faction="B",npc="Chiyo Mistpaw",npcid=59688,x=57.4,y=60.0},
		{name="Kota Basecamp",faction="B",npc="Clover Keeper",npcid=60420,x=42.7,y=70.0},
		{name="Eastwind Rest",faction="H",npc="Mai the Sleepy",npcid=62883,x=62.8,y=80.5},
		{name="Temple of the White Tiger",faction="B",npc="Master Lao",npcid=61651,x=66.9,y=51.0},
		{name="North Wind Tavern",faction="B",npc="Liu Ze",npcid=60605,x=62.5,y=28.8},
		{name="Shado-Pan Fallback",faction="B",npc="Stained Mug",npcid=62877,x=44.4,y=90.3},
	},

	["Townlong Steppes"]={
		{name="Longying Outpost",faction="B",npc="Saito the Sleeping Shadow",npcid=62873,x=71.1,y=57.9},
		{name="Gao-Ran Battlefront",faction="B",npc="Kim the Quiet",npcid=62875,x=76.0,y=82.9},
		{name="Shado-Pan Garrison",faction="B",npc="Kali the Night Watcher",npcid=62874,x=48.9,y=70.8},
	},

	["Dread Wastes"]={
		{name="The Chum Bucket",faction="B",npc="San the Sea Calmer",npcid=63016,x=55.2,y=71.1},
		{name="Klaxxi'vess",faction="B",npc="Zit'tix",npcid=65220,x=55.9,y=32.3},
	},

	["Isle of Thunder"]={
		{name="Violet Rise",faction="A",npc="Isirami Fairwind",npcid=70182,x=64.9,y=73.0},
		{name="Battlefront Provisions",faction="B",npc="Uda the Beast",npcid=70182,x=64.9,y=73.0},
	},

	["Timeless Isle"]={
		{name="The Celestial Court",faction="B",npc="Graceful Swan",npcid=73622,x=36.6,y=46.8},
	},


	----------------------------
	-----  NORTHREND  ----
	----------------------------

	["Borean Tundra"]={
		{name="Valiant Rest",faction="A",npc="James Deacon",npcid=25245,x=58.29,y=68.05},
		{name="Fizzcrank Airstrip",faction="A",npc="\"Charlie\" Northtop",npcid=26596,x=57.12,y=18.71},
		{name="Warsong Hold",faction="H",npc="Williamson",npcid=25278,x=41.8,y=54.6},
		{name="Taunka'le Village",faction="H",npc="Pahu Frosthoof",npcid=26709,x=76.2,y=37.2},
		{name="Unu'pe",faction="B",npc="Caregiver Poallu",npcid=27187,x=78.39,y=49.28},
	},
	["Howling Fjord"]={
		{name="Valgarde",faction="A",npc="Innkeeper Hazel Lagras",npcid=23731,x=58.4,y=62.6},
		{name="Westguard Inn",faction="A",npc="Innkeeper Celeste Goodhutch",npcid=23937,x=30.8,y=41.4},
		{name="Fort Wildervar",faction="A",npc="Christina Daniels",npcid=24057,x=60.4,y=15.8},
		{name="Vengeance Landing",faction="H",npc="Timothy Holland",npcid=24342,x=79.7,y=30.8},
		{name="New Agamand",faction="H",npc="Basil Osgood",npcid=24149,x=52.2,y=66.4},
		{name="Camp Winterhoof",faction="H",npc="Bori Wintertotem",npcid=24033,x=49.4,y=10.8},
		{name="Kamagua",faction="B",npc="Caregiver Iqniq",npcid=27148,x=25.4,y=59.8},
	},
	["Dragonblight"]={
		{name="Wintergarde Keep",faction="A",npc="Illusia Lune",npcid=27042,x=77.40,y=51.84},
		{name="Stars' Rest",faction="A",npc="Naohain",npcid=27052,x=28.89,y=56.09},
		{name="Venomspite",faction="H",npc="Mrs. Winterby",npcid=27027,x=76.8,y=63.0},
		{name="Agmar's Hammer",faction="H",npc="Barracks Master Harga",npcid=26985,x=38.2,y=46.6},
		{name="Moa'ki Harbor",faction="B",npc="Caregiver Mumik",npcid=27174,x=48.14,y=74.76},
		{name="Wyrmrest Temple",faction="B",npc="Demestrasz",npcid=27950,x=59.80,y=54.24},
	},
	["Grizzly Hills"]={
		{name="Amberpine Lodge",faction="A",npc="Jennifer Bell",npcid=27066,x=32.0,y=60.2},
		{name="Westfall Brigade Encampment",faction="A",npc="Quartermaster McCarty",npcid=26375,x=59.6,y=26.4},
		{name="Conquest Hold",faction="H",npc="Barracks Master Rhekku",npcid=27125,x=20.8,y=64.6},
		{name="Camp Oneqwah",faction="H",npc="Aiyan Coldwind",npcid=26680,x=65.4,y=47.0},
	},
	["Dalaran"]={
		{name="Dalaran",faction="B",npc="Amisi Azuregaze",npcid=28687,x=51.0,y=40.0,legion=false}, -- this is the universal innkeeper in Dalaran for our purpose. GetBindLocation() returns Dalaran so needed a way to find it.
		{name="The Silver Enclave",faction="A",npc="Isirami Fairwind",npcid=32413,x=44.6,y=63.0},
		{name="Sunreaver's Sanctuary",faction="H",npc="Uda the Beast",npcid=31557,x=65.6,y=32.6},
		{name="Sunreaver's Sanctuary",faction="H",npc="Abohba",npcid=32418,x=69.0,y=33.4},
		{name="Runeweaver Square",faction="B",npc="Amisi Azuregaze",npcid=28687,x=51.0,y=40.0},
		{name="The Underbelly",faction="B",npc="Ajay Green",npcid=29532,x=37.0,y=56.8},
		{name="Runeweaver Square",faction="B",npc="Afsaneh Asrar",npcid=32411,x=49.6,y=40.6},
	},
	["The Storm Peaks"]={
		{name="Frosthold",faction="A",npc="Gunda Boldhammer",npcid=29926,x=28.6,y=74.4},
		{name="Camp Tunka'lo",faction="H",npc="Wabada Whiteflower",npcid=29971,x=67.6,y=50.6},
		{name="Grom'arsh Crash-Site",faction="H",npc="Peon Gakra",npcid=29944,x=37.0,y=49.6},
		{name="K3",faction="B",npc="Smilin\' Slirk Brassknob",npcid=29904,x=41.0,y=85.8},
		{name="Brunnhildar Village",faction="B",npc="Lodge-Matron Embla",npcid=30005,x=48.8,y=65.0},
		{name="Bouldercrag's Refuge",faction="B",npc="Magorn",npcid=29963,x=30.8,y=37.2},
	},
	["Icecrown"]={
		{name="Silver Covenant Pavilion",faction="A",npc="Caris Sunlance",npcid=33970,x=76.19,y=19.66},
		{name="Sunreaver Pavilion",faction="H",npc="Jarin Dawnglow",npcid=33971,x=76.10,y=23.96},
		{name="The Shadow Vault",faction="B",npc="Initiate Brenners",npcid=30308,x=43.99,y=22.18},
	},
	["Zul\'Drak"]={
		{name="The Argent Stand",faction="B",npc="Marissa Everwatch",npcid=28791,x=40.8,y=66.2},
		{name="Zim'Torga",faction="B",npc="Pan'ya",npcid=29583,x=59.2,y=57.2},
	},
	["Sholazar Basin"]={
		{name="Nesingwary Base Camp",faction="B",npc="Purser Boulian",npcid=28038,x=26.75,y=59.27},
	},


	---------------------------
	-----  OUTLAND  -----
	---------------------------

	["Hellfire Peninsula"]={
		{name="Thrallmar",faction="H",npc="Floyd Pinkus",npcid=16602,x=56.6,y=37.6},
		{name="Falcon Watch",faction="H",npc="Innkeeper Bazil Olof'tazun",npcid=18905,x=26.8,y=59.6},
		{name="Honor Hold",faction="A",npc="Sid Libardi",npcid=16826,x=54.2,y=63.5},
		{name="Temple of Telhamat",faction="A",npc="Caregiver Ophera Windfury",npcid=18906,x=23.4,y=36.4},
	},
	["Zangarmarsh"]={
		{name="Zabra'jin",faction="H",npc="Merajit",npcid=18245,x=30.66,y=50.93},
		{name="Firefly Tavern",faction="B",npc="Innkeeper Coryth Stoktron",npcid=18907,x=78.6,y=63.0},
		{name="Orebor Harborage",faction="A",npc="Innkeeper Kerp",npcid=18908,x=41.9,y=26.3},
		{name="Zangarmarsh",faction="A",npc="Caregiver Abidaar",npcid=18251,x=67.2,y=49.0},
	},
	["Terokkar Forest"]={
		{name="Allerian Stronghold",faction="A",npc="Innkeeper Biribi",npcid=19296,x=56.7,y=53.3},
		{name="Stonebreaker Hold",faction="H",npc="Innkeeper Grilka",npcid=18957,x=48.8,y=45.0},
	},
	["Nagrand"]={
		{name="Telaar",faction="A",npc="Caregiver Isel",npcid=18914,x=54.22,y=76.11},
		{name="Garadar",faction="H",npc="Matron Tikkit",npcid=18913,x=56.6,y=34.6},
	},
	["Blade\'s Edge Mountains"]={
		{name="Sylvanaar",faction="A",npc="Innkeeper Shaunessy",npcid=19495,x=35.8,y=63.9},
		{name="Toshley's Station",faction="A",npc="Fizit \"Doc\" Clocktok",npcid=21110,x=61.0,y=68.1},
		{name="Thunderlord Stronghold",faction="H",npc="Gholah",npcid=19470,x=53.2,y=55.4},
		{name="Mok'Nathal Village",faction="H",npc="Matron Varah",npcid=21088,x=76.0,y=60.2},
		{name="Evergrove",faction="B",npc="Innkeeper Aelerya",npcid=22922,x=62.8,y=38.2},
	},
	["Shadowmoon Valley"]={
		{name="Shadowmoon Village",faction="H",npc="Innkeeper Darg Bloodclaw",npcid=19319,x=30.2,y=27.8},
		{name="Altar of Sha'tar",faction="B",npc="Caretaker Aluuro",npcid=21746,x=61.0,y=28.2},-- // ALDOR ONLY
		{name="Sanctum of the Stars",faction="B",npc="Roldemar",npcid=21744,x=56.2,y=59.8},-- // SCRYER ONLY
		{name="Wildhammer Stronghold",faction="A",npc="Dreg Cloudsweeper",npcid=19352,x=37.0,y=58.2},
	},
	["Shattrath City"]={
		{name="Shattrath City",faction="B",npc="Minalei",npcid=19046,x=28.2,y=48.4},-- // ALDOR ONLY
		{name="Scryer's Tier",faction="B",npc="Innkeeper Haelthol",npcid=19232,x=56.2,y=81.6},-- // SCRYER ONLY
	},
	["Netherstorm"]={
		{name="Area 52",faction="B",npc="Innkeeper Remi Dodoso",npcid=19571,x=32.0,y=64.4},
		{name="The Stormspire",faction="B",npc="Eyonix",npcid=19531,x=43.4,y=36.0},
	},


	------------------------------------
	-----  EASTERN KINGDOMS  -----
	------------------------------------

	["Gilneas"]={
		{name="Duskhaven",faction="A",npc="Willa Arnes",npcid=38791,x=36.8,y=65.6},
		{name="Stormglen Village",faction="A",npc="Willa Arnes",npcid=38792,x=60.06,y=91.67},
	},
	["Dun Morogh"]={
		--{name="Gnomeregan",faction="A",npc="Nevin Twistwrench",npcid=45966,x=25.7,y=31.9},					-- This ports to a submap of DM. Kind of a mess, should never be used because it goes backwards.
		{name="Thunderbrew Distillery",faction="A",npc="Innkeeper Belm",npcid=1247,x=54.5,y=50.8},
	},
	["Elwynn Forest"]={
		{name="Lion's Pride Inn",faction="A",npc="Innkeeper Farley",npcid=295,x=43.8,y=65.8},
		{name="Elwynn Forest",faction="A",npc="Aysa Cloudsinger",npcid=60566,x=74.2,y=92.4},
	},
	["Ironforge"]={
		{name="The Stonefire Tavern",faction="A",npc="Innkeeper Firebrew",npcid=5111,x=18.6,y=51.6},
	},
	["Stormwind City"]={
		{name="Trade District",faction="A",npc="Innkeeper Allison",npcid=6740,x=60.8,y=74.8},
		{name="Old District",faction="A",npc="Maegan Tillman",npcid=44237,x=75.5,y=54.2},
		{name="Dwarven District",faction="A",npc="Thaegra Tillstone",npcid=44235,x=64.8,y=32.3},
	},
	["Loch Modan"]={
		{name="Stoutlager Inn",faction="A",npc="Innkeeper Hearthstove",npcid=6734,x=35.5,y=48.4},
		{name="The Farstrider Lodge",faction="A",npc="Vyrin Swiftmend",npcid=1156,x=81.9,y=64.5},
	},
	["Westfall"]={
		{name="Sentinel Hill",faction="A",npc="Innkeeper Heather",npcid=8931,x=52.8,y=53.6},
	},
	["Redridge Mountains"]={
		{name="Lakeshire",faction="A",npc="Innkeeper Brianna",npcid=6727,x=26.4,y=41.4},
	},
	["Wetlands"]={
		{name="Deepwater Tavern",faction="A",npc="Innkeeper Helbrek",npcid=1464,x=10.7,y=60.8},
		{name="Greenwarden's Grove",faction="A",npc="Innkeeper Larisal",npcid=43993,x=58.2,y=39.2},
		{name="Swiftgear Station",faction="A",npc="Innkeeper Daughny",npcid=44006,x=25.6,y=25.8},
	},
	["Duskwood"]={
		{name="Darkshire",faction="A",npc="Innkeeper Trelayne",npcid=6790,x=73.9,y=44.4},
	},
	["Tirisfal Glades"]={
		{name="Brill",faction="H",npc="Innkeeper Renee",npcid=5688,x=60.8,y=51.6},
		{name="The Bulwark",faction="H",npc="Provisioner Elda",npcid=46271,x=83.0,y=71.8},
	},
	["Deathknell"]={
		{name="Deathknell Graves",faction="H",npc="",npcid=0,x=40.5,y=78.5},
	},
	["Eversong Woods"]={
		{name="Falconwing Inn",faction="H",npc="Innkeeper Delaniel",npcid=15433,x=48.1,y=47.7},
		{name="Fairbreeze Village",faction="H",npc="Marniel Amberlight",npcid=15397,x=43.67,y=71.32},
	},
	["Undercity"]={
		{name="The Trade Quarter",faction="H",npc="Innkeeper Norman",npcid=6741,x=67.8,y=38.6},
	},
	["Silvermoon City"]={
		{name="The Royal Exchange",faction="H",npc="Innkeeper Velandra",npcid=16618,x=79.6,y=58.6},
		{name="The Bazaar",faction="H",npc="Innkeeper Jovia",npcid=17630,x=79.6,y=58.6},
	},
	["Silverpine Forest"]={
		{name="The Sepulcher",faction="H",npc="Innkeeper Velandra",npcid=6739,x=46.4,y=42.6},
		{name="Forsaken Rear Guard",faction="H",npc="Commander Hickley",npcid=45496,x=44.4,y=20.6},
	},
	["Ghostlands"]={
		{name="Tranquillien",faction="H",npc="Innkeeper Kalarin",npcid=16542,x=48.8,y=32.4},
	},
	["Hillsbrad Foothills"]={
		{name="Tarren Mill",faction="H",npc="Innkeeper Shay",npcid=2388,x=57.8,y=47.2},
		{name="The Sludge Fields",faction="H",npc="Innkeeper Hershberg",npcid=49394,x=35.8,y=61.2},
		{name="Eastpoint Tower",faction="H",npc="Innkeeper Durgens",npcid=49430,x=59.6,y=64.8},
	},
	["Arathi Highlands"]={
		{name="Refuge Pointe",faction="A",npc="Vikki Lonsav",npcid=2808,x=39.9,y=49.0},
		{name="Hammerfall",faction="H",npc="Innkeeper Adegwa",npcid=7731,x=69.0,y=33.2},
	},
	["Northern Stranglethorn"]={
		{name="Fort Livingston",faction="A",npc="Livingston Marshal",npcid=44019,x=53.2,y=66.8},
		{name="Grom'gol Base Camp",faction="H",npc="Innkeeper Thulbek",npcid=5814,x=37.2,y=51.8},
	},
	["The Cape of Stranglethorn"]={
		{name="Booty Bay",faction="B",npc="Innkeeper Skindle",npcid=6807,x=40.8,y=73.8},
		{name="Hardwrench Hideaway",faction="H",npc="Innkeeper Draxle",npcid=44190,x=35.08,y=27.20},
	},
	["Swamp of Sorrows"]={
		{name="Bogpaddle",faction="B",npc="Cap'n Geech",npcid=47334,x=71.7,y=13.9},
		{name="The Harborage",faction="A",npc="Verad",npcid=47367,x=29.0,y=32.5},
		{name="Stonard",faction="H",npc="Innkeeper Karakul",npcid=6930,x=46.8,y=56.8},
	},
	["Badlands"]={
		{name="Dragon's Mouth",faction="A",npc="Ivan Zypher",npcid=48093,x=20.7,y=56.2},
		{name="New Kargath",faction="H",npc="Innkeeper Shul\'kar",npcid=9356,x=18.2,y=42.8},
		{name="Fuselight-By-The-Sea",faction="B",npc="The Great Pisani",npcid=49934,x=90.0,y=37.6},
		{name="Fuselight",faction="B",npc="Sally Gearwell",npcid=48054,x=65.8,y=35.6},
	},
	["The Hinterlands"]={
		{name="Stormfeather Outpost",faction="A",npc="Innkeeper Keirnan",npcid=43699,x=66.2,y=44.4},
		{name="Aerie Peak",faction="A",npc="Innkeeper Thulfram",npcid=7744,x=14.0,y=44.8},
		{name="Revantusk Village",faction="H",npc="Lard",npcid=14731,x=78.2,y=81.2},
		{name="Hiri'watha Research Station",faction="H",npc="Bitsy",npcid=43739,x=31.8,y=58.0},
	},
	["Eastern Plaguelands"]={
		{name="Light's Hope Chapel",faction="B",npc="Jessica Chambers",npcid=16256,x=75.6,y=52.4},
	},
	["Isle of Quel\'Danas"]={
		{name="Sun's Reach Harbor",faction="B",npc="Caregiver Inaara",npcid=25036,x=51.2,y=33.4},
	},
	["Western Plaguelands"]={
		{name="Chillwind Camp",faction="A",npc="Mother Matterly",npcid=46269,x=43.4,y=84.6},
		{name="Andorhal",faction="H",npc="Roman Garner",npcid=47857,x=48.2,y=63.8},
	},
	["Blasted Lands"]={
		{name="Surwich",faction="A",npc="Donna Berrymore",npcid=44334,x=44.4,y=87.6},
		{name="Nethergarde Keep",faction="A",npc="Mama Morton",npcid=44325,x=60.7,y=14.0},
		{name="Dreadmaul Hold",faction="H",npc="Innkeeper Grak",npcid=44309,x=40.4,y=11.4},
	},
	["Kelp\'thar Forest"]={
		{name="The Briny Cutter",faction="A",npc="Erunak Stonespeaker",npcid=40697,x=45.2,y=23.4},
		{name="Legion's Fate",faction="H",npc="Erunak Stonespeaker",npcid=41794,x=39.6,y=30.8},
		{name="Deepmist Grotto",faction="B",npc="Erunak Stonespeaker",npcid=41341,x=63.8,y=59.8},
	},
	["Shimmering Expanse"]={
		{name="Silver Tide Hollow",faction="A",npc="Caretaker Movra",npcid=39878,x=49.2,y=41.9},
		{name="Tranquil Wash",faction="A",npc="Anissa Matherly",npcid=42873,x=49.7,y=57.4},
		{name="Legion's Rest",faction="H",npc="Zun'ja",npcid=42908,x=51.6,y=62.6},
	},
	["Abyssal Depths"]={
		{name="Darkbreak Cove",faction="A",npc="Barracks Officer Milson",npcid=42963,x=54.8,y=72.1},
		{name="Tenebrous Cavern",faction="H",npc="Innkeeper Nerius",npcid=43141,x=51.2,y=60.6},
	},
	["Twilight Highlands"]={
		{name="Thundermar",faction="A",npc="Naveen Tendernose",npcid=49591,x=49.5,y=30.4},
		{name="Highbank",faction="A",npc="Innkeeper Francis",npcid=49688,x=79.4,y=78.5},
		{name="Highbank",faction="A",npc="Innkeeper Teresa",npcid=49686,x=79.0,y=77.6},
		{name="Firebeard's Patrol",faction="A",npc="Innkeeper Corlin",npcid=49795,x=60.4,y=58.0},
		{name="Kirthaven",faction="A",npc="Vaughn Blusterbeard",npcid=49574,x=54.6,y=18.0},
		{name="Victor's Point",faction="A",npc="Ben Mora",npcid=49599,x=43.6,y=57.3},
		{name="Dragonmaw Port",faction="H",npc="Innkeeper Lutz",npcid=49498,x=75.8,y=52.6},
		{name="The Krazzworks",faction="H",npc="Innkeeper Geno",npcid=49783,x=75.4,y=16.6},
		{name="Bloodgulch",faction="H",npc="Innkeeper Turk",npcid=49762,x=53.2,y=42.8},
		{name="Crushblow",faction="H",npc="Innkeeper Krum",npcid=49747,x=45.2,y=76.4},
	},


	----------------------------
	-----  KALIMDOR  -----
	----------------------------

	
	["Valley of Trials"]={
		{name="Valley of Trials",faction="H",npc="Kaltunk",npcid=10176,x=45.2,y=68.7},
	},
	["Teldrassil"]={
		{name="Dolanaar",faction="A",npc="Innkeeper Keldamyr",npcid=6736,x=55.4,y=52.2},
	},
	["Shadowglen"]={
		{name="Shadowglen",faction="A",npc="Ilthalaine",npcid=2079,x=45.5,y=74.7},
	},
	["Ammen Vale"]={
		{name="Ammen Vale",faction="A",x=61.39,y=29.48}, -- no innkeeper npc
	},
	["Azuremyst Isle"]={
		{name="Azure Watch",faction="A",npc="Caregiver Chellan",npcid=16553,x=48.4,y=49.2},
	},
	["Darnassus"]={
		{name="Craftsmen's Terrace",faction="A",npc="Innkeeper Saelienne",npcid=6735,x=62.4,y=32.8},
	},
	["Darkshore"]={
		{name="Lor'danel",faction="A",npc="Innkeeper Kyteran",npcid=43420,x=50.92,y=18.63},
	},
	["The Exodar"]={
		{name="The Exodar",faction="A",npc="Caregiver Breel",npcid=16739,x=59.91,y=19.45},
	},
	["Bloodmyst Isle"]={
		{name="Blood Watch",faction="A",npc="Caregiver Topher Loaal",npcid=17553,x=55.6,y=59.6},
	},
	["Ashenvale"]={
		{name="Astranaar",faction="A",npc="Innkeeper Kimlya",npcid=6738,x=37.0,y=49.2},
		{name="Splintertree Post",faction="H",npc="Innkeeper Kaylisk",npcid=12196,x=74.0,y=60.6},
		{name="Silverwind Refuge",faction="H",npc="Innkeeper Chin'toka",npcid=43633,x=50.4,y=67.0},
		{name="Zoram'gar Outpost",faction="H",npc="Innkeeper Duras",npcid=43606,x=12.8,y=34.0},
		{name="Hellscream's Watch",faction="H",npc="Innkeeper Linkasa",npcid=43624,x=38.6,y=42.2},
	},
	["Stonetalon Mountains"]={
		{name="Fallowmere Inn",faction="A",npc="Alithia Fallowmere",npcid=40898,x=59.0,y=56.4},
		{name="Northwatch Expedition Base Camp",faction="A",npc="Lyanath",npcid=41286,x=71.1,y=79.1},
		{name="Thal\'darah Overlook",faction="A",npc="Valos Shadowrest",npcid=41491,x=39.4,y=32.8},
		{name="Farwatcher's Glen",faction="A",npc="Innkeeper Bernice",npcid=44177,x=31.4,y=60.6},
		{name="Krom'gar Fortress",faction="H",npc="Felonius Stark",npcid=41892,x=66.4,y=64.2},
		{name="Sun Rock Retreat",faction="H",npc="Innkeeper Jayka",npcid=7731,x=50.4,y=63.8},
	},
	["Desolace"]={
		{name="Nijel's Point",faction="A",npc="Innkeeper Lyshaerya",npcid=11103,x=66.2,y=6.6},
		{name="Shadowprey Village",faction="H",npc="Innkeeper Sikewa",npcid=11106,x=24.0,y=68.2},
		{name="Karnum's Glade",faction="B",npc="Innkeeper Dessina",npcid=43872,x=56.8,y=50.0},
	},
	["Dustwallow Marsh"]={
		{name="Theramore Isle",faction="A",npc="Innkeeper Janene",npcid=6272,x=66.6,y=45.2},
		{name="Brackenwall Village",faction="H",npc="\"Little\" Logok",npcid=24208,x=36.8,y=32.2},
		{name="Mudsprocket",faction="B",npc="Axle",npcid=23995,x=41.8,y=74.0},
	},
	["Felwood"]={
		{name="Talonbranch Glade",faction="A",npc="Denmother Ulrica",npcid=47931,x=61.8,y=26.6},
		{name="Wildheart Point",faction="B",npc="Innkeeper Teenycaugh",npcid=48599,x=44.0,y=61.8},
		{name="Whisperwind Grove",faction="B",npc="Innkeeper Wylaria",npcid=48215,x=44.8,y=29.0},
	},
	["Tanaris"]={
		{name="The Road Warrior",faction="B",npc="Innkeeper Fizzgrimble",npcid=7733,x=52.6,y=27.0},
		{name="Bootlegger Outpost",faction="B",npc="Carmen Ibanozzle",npcid=38714,x=55.6,y=60.8},
	},
	["Durotar"]={
		{name="Razor Hill",faction="H",npc="Innkeeper Grosk",npcid=6928,x=51.6,y=41.6},
		{name="The Dranosh'ar Blockade",faction="H",npc="Ji Firepaw",npcid=60570,x=45.6,y=13.1},
	},
	["Kezan"]={
		{name="KTC Headquarters",faction="H",npc="Sassy Hardwrench",npcid=34668,x=56.8,y=77.0},
	},
	["The Lost Isles"]={
		{name="Shipwreck Shore",faction="H",npc="Grimy Greasefingers",npcid=36496,x=28.0,y=75.8},
		{name="Town-In-A-Box",faction="H",npc="Grimy Greasefingers",npcid=42473,x=45.0,y=65.4},
		{name="Warchief's Lookout",faction="H",npc="Grimy Greasefingers",npcid=42473,x=36.8,y=43.2},
	},
	["Mulgore"]={
		{name="Bloodhoof Village",faction="H",npc="Innkeeper Kauth",npcid=6747,x=46.8,y=60.4},
	},
	["Orgrimmar"]={
		{name="Orgrimmar",faction="H",npc="Innkeeper Gryshka",npcid=6929,x=53.6,y=78.8},
		{name="Valley of Strength",faction="H",npc="Innkeeper Gryshka",npcid=6929,x=53.6,y=78.8},
		{name="Valley of Honor",faction="H",npc="Innkeeper Nufa",npcid=46642,x=70.6,y=49.2},
		{name="Valley of Wisdom",faction="H",npc="Miwana",npcid=44785,x=39.2,y=48.4},
		{name="Goblin Slums",faction="H",npc="Tinza Silvermug",npcid=45563,x=39.8,y=81.0},
		{name="Valley of Spirits",faction="H",npc="Sijambi",npcid=45086,x=32.8,y=65.6},
	},
	["Thunder Bluff"]={
		{name="Lower Rise",faction="H",npc="Innkeeper Pala",npcid=6746,x=45.8,y=64.6},
	},
	["The Barrens"]={
		{name="The Crossroads",faction="H",npc="Innkeeper Boorand Plainswind",npcid=3934,x=49.6,y=58.0},
		{name="Grol'dom Farm",faction="H",npc="Innkeeper Kerntis",npcid=43946,x=56.2,y=40.0},
		{name="Nozzlepot's Outpost",faction="H",npc="Innkeeper Kritzle",npcid=43945,x=62.4,y=16.6},
		{name="Ratchet",faction="B",npc="Innkeeper Wiley",npcid=6791,x=67.2,y=74.6},
	},
	["Southern Barrens"]={
		{name="Honor's Stand",faction="A",npc="Logistics Officer Renaldo",npcid=44219,x=39.0,y=11.0},
		{name="Northwatch Hold",faction="A", npc="Keep Watcher Kerry",npcid=44268,x=65.6,y=46.6},
		{name="Fort Triumph",faction="A", npc="Logistics Officer Salista",npcid=44267,x=49.0,y=68.5},
		{name="Camp Taurajo",faction="H",npc="Byula",npcid=7714,x=44.2,y=33.6},
		{name="Hunter's Hill",faction="H",npc="Innkeeper Hurnahet",npcid=44270,x=39.2,y=20.0},
		{name="Desolation Hold",faction="H",npc="Innkeeper Lhakadd",npcid=44276,x=40.8,y=69.2},
	},
	["Thousand Needles"]={
		{name="Speedbarge Bar",faction="B",npc="Daisy",npcid=40832,x=76.4,y=74.6},
	},
	["Feralas"]={
		{name="Dreamer's Rest",faction="A",npc="Andoril",npcid=40968,x=51.0,y=17.8},
		{name="Feathermoon Stronghold",faction="A",npc="Innkeeper Shyria",npcid=44391,x=46.0,y=45.2},
		{name="Camp Mojache",faction="H",npc="Innkeeper Greul",npcid=7737,x=74.8,y=45.2},
		{name="Camp Ataya",faction="H",npc="Adene Treetotem",npcid=40467,x=41.4,y=15.6},
		{name="Stonemaul Hold",faction="H",npc="Chonk",npcid=44376,x=51.8,y=47.6},
	},
	["Winterspring"]={
		{name="The Laughing Yeti",faction="B",npc="Innkeeper Vizzie",npcid=11118,x=59.8,y=51.8},
	},
	["Silithus"]={
		{name="The Oasis Inn",faction="B",npc="Calandrath",npcid=15174,x=55.4,y=36.6},
	},
	["Searing Gorge"]={
		{name="Iron Summit",faction="B",npc="Velma Rockslide",npcid=47942,x=39.4,y=66.2},
	},
	["Un\'Goro Crater"]={
		{name="Marshal's Stand",faction="B",npc="Innkeeper Dreedle",npcid=38488,x=55.2,y=62.2},
	},
	["Uldum"]={
		{name="Ramkahen",faction="B",npc="Kazemde",npcid=48886,x=54.7,y=32.9},
		{name="Oasis of Vir'sar",faction="B",npc="Yasmin",npcid=49406,x=26.6,y=7.3},
		{name="Schnottz's Hostel",faction="B",npc="Arcane Guest Registry",npcid=49528,x=22.0,y=64.4},
	},
	["Mount Hyjal"]={
		{name="Nordrassil Inn",faction="B",npc="Sebelia",npcid=40843,x=63.1,y=24.1},
		{name="Shrine of Aviana",faction="B",npc="Isara Riverstride",npcid=50068,x=42.6,y=45.6},
		{name="Grove of Aessina",faction="B",npc="Salirn Moonbear",npcid=53779,x=18.6,y=37.2},
	},
	["Deepholm"]={
		{name="Temple of Earth",faction="B",npc="Caretaker Nuunwa",npcid=45300,x=49.8,y=52.0},
	},

}