local name,addon = ...
local data={}
addon.LibTaxiData = data
data.taxipoints = {}



--------------------
--- KALIMDOR ---
--------------------
data.taxipoints[12]={
	['Ashenvale']={
		{name="Astranaar",faction="A",npc="Daelyshia",npcid=4267,x=34.4,y=48.0},
		{name="Blackfathom Camp",faction="A",npc="Solais",npcid=34374,x=18.1,y=20.6},
		{name="Forest Song",faction="A",npc="Suralais Farwind",npcid=22935,x=85.1,y=43.5},
		{name="Hellscream's Watch",faction="H",npc="Thraka",npcid=34429,x=38.1,y=42.3},
		{name="Silverwind Refuge",faction="H",npc="Wind Tamer Shoshok",npcid=34943,x=49.3,y=65.3},
		{name="Splintertree Post",faction="H",npc="Vhulgra",npcid=12616,x=73.3,y=61.7},
		{name="Stardust Spire",faction="A",npc="Myre Moonglide",npcid=34378,x=35.0,y=72.1},
		{name="Zoram'gar Outpost",faction="H",npc="Andruk",npcid=11901,x=11.2,y=34.4},
	},
	['Azshara']={
		{name="Bilgewater Harbor",faction="H",npc="Kroum",npcid=8610,x=52.9,y=49.9},
		{name="Northern Rocketway",faction="H",npc="Blitz Blastospazz",npcid=43328,x=66.5,y=20.9},
		{name="Southern Rocketway",faction="H",npc="Friz Groundspin",npcid=37005,x=51.5,y=74.3},
		{name="Valormok",faction="H",npc="Kroum",npcid=36728,x=14.4,y=65.0},
	},
	['Azuremyst Isle']={
		{name="Azure Watch",faction="A",npc="Zaldaan",npcid=43991,x=49.7,y=49.1},
	},
	['Bloodmyst Isle']={
		{name="Blood Watch",faction="A",npc="Laando",npcid=17554,x=57.9,y=53.9},
	},
	['Darkshore']={
		{name="Grove of the Ancients",faction="A",npc="Delanea",npcid=33253,x=44.4,y=75.5},
		{name="Lor'danel",faction="A",npc="Teldira Moonfeather",npcid=3841,x=51.7,y=17.6},
			--BlackCats
			--name needs to be like that to connect a taxi tag. extitle can not be title b/c then only title gets put on the Pointer
		{name="Darkshore Cat 1",extitle="Lor'danel",faction="A",npc="Nightsaber Rider",npcid=33359,x=52.2,y=22.3,taxioperator="blackcat"},
		{name="Darkshore Cat 2",extitle="Lor'danel",faction="A",npc="Nightsaber Rider",npcid=33359,x=51.0,y=22.7,taxioperator="blackcat"},
		{name="Darkshore Cat 3",extitle="Ruins of Mathystra",faction="A",npc="Nightsaber Rider",npcid=33359,x=58.6,y=20.0,taxioperator="blackcat"},
		{name="Darkshore Cat 4",extitle="Shatterspear Vale",faction="A",npc="Nightsaber Rider",npcid=33359,x=69.1,y=18.9,taxioperator="blackcat"},
		{name="Darkshore Cat 5",extitle="Bashal'Aran",faction="A",npc="Nightsaber Rider",npcid=33359,x=46.9,y=33.2,taxioperator="blackcat"},
	},
	['Darnassus']={
		{name="Darnassus",faction="A",npc="Leora",npcid=40552,x=36.6,y=47.8},
	},
	['Desolace']={
		{name="Ethel Rethor",faction="B",npc="Korrah's Hippogryph",npcid=35562,x=39.07,y=26.94},
		{name="Furien's Post",faction="H",npc="Narimar",npcid=35315,x=44.27,y=29.67},
		{name="Karnum's Glade",faction="B",npc="Lastrea Greengale",npcid=35478,x=57.72,y=49.75},
		{name="Nijel's Point",faction="A",npc="Baritanas Skyriver",npcid=6706,x=64.7,y=10.6},
		{name="Shadowprey Village",faction="H",npc="Thalon",npcid=6726,x=21.60,y=74.13},
		{name="Thargad's Camp",faction="A",npc="Moira Steelwing",npcid=35481,x=36.8,y=71.7},
		{name="Thunk's Abode",faction="B",npc="Thunk's Wyvern",npcid=35556,x=70.66,y=32.89},
	},
	['Durotar']={
		{name="Razor Hill",faction="H",npc="Burok",npcid=41140,x=53.1,y=43.6},
		{name="Sen'jin Village",faction="H",npc="Handler Marnlek",npcid=41142,x=55.4,y=73.3},
	},
	['Dustwallow Marsh']={
		{name="Brackenwall Village",faction="H",npc="Shardi",npcid=11899,x=35.6,y=31.8},
		{name="Mudsprocket",faction="B",npc="Dyslix Silvergrub",npcid=40358,x=42.8,y=72.4},
		-- achievemissing: Only include this flight point if an achievement is *missing*.
		-- Used because this flight point disappears when Theramore is destroyed.
		{name="Theramore",faction="A",npc="Baldruc",npcid=4321,x=67.4,y=51.4,achievemissing=7523},
	},
	['Felwood']={
		{name="Emerald Sanctuary",faction="B",npc="Gorrim",npcid=22931,x=51.5,y=80.9},
		{name="Talonbranch Glade",faction="A",npc="Mishellena",npcid=12578,x=60.5,y=25.3},
		{name="Whisperwind Grove",faction="B",npc="Hanah Southsong",npcid=43073,x=43.6,y=28.7},
		{name="Wildheart Point",faction="B",npc="Chyella Hushglade",npcid=43079,x=44.3,y=61.9},
		{name="Irontree Clearing",faction="H",npc="Dirzak Pryocrank",npcid=43085,x=56.4,y=8.4},
	},
	['Feralas']={
		{name="Camp Ataya",faction="H",npc="Tono",npcid=40473,x=41.54,y=15.46},
		{name="Camp Mojache",faction="H",npc="Shyn",npcid=39898,x=75.4,y=44.3},
		{name="Dreamer's Rest",faction="A",npc="Selor",npcid=40966,x=50.2,y=16.7},
		{name="Feathermoon",faction="A",npc="Irela Moonfeather",npcid=41383,x=46.8,y=45.3},
		{name="Shadebough",faction="A",npc="Seyala Nightwisp",npcid=40367,x=77.3,y=56.8},
		{name="Stonemaul Hold",faction="H",npc="Mergek",npcid=41605,x=51.00,y=48.42},
		{name="Tower of Estulan",faction="A",npc=" Aryenda",npcid=41580,x=57.1,y=54.0},
	},
	['Moonglade']={
		{name="Moonglade",faction="A",npc="Sindrayl",npcid=10897,x=48.1,y=67.3},
		{name="Moonglade",faction="H",npc="Faustron",npcid=12740,x=32.1,y=66.6},
		{name="Nighthaven",faction="H",class="DRUID",npc="Bunthen Plainswind",npcid=11798,x=44.2,y=45.6},
		{name="Nighthaven",faction="A",class="DRUID",npc="Silva Fil'naveth",npcid=11800,x=44.2,y=45.8},
	},
	['Mount Hyjal']={
		{name="Gates of Sothann",faction="B",quest=25608,npc="Althera",npcid=43549,x=71.6,y=75.3},
		{name="Grove of Aessina",faction="B",npc="Elizil Wintermoth",npcid=41860,x=19.6,y=36.4},
		{name="Nordrassil",faction="B",npc="Fayran Elthas",npcid=41861,x=62.1,y=21.6},
		{name="Sanctuary of Malorne",faction="B",quest=25372,npc="Ranela Featherglen",npcid=54393,x=27.75,y=63.64}, -- nodeID = 781
		{name="Shrine of Aviana",faction="B",npc="Dinorae Swiftfeather",npcid=50084,x=41.2,y=42.6},
	},
	['Mulgore']={
		{name="Bloodhoof Village",faction="H",npc="Tak",npcid=40809,x=47.4,y=58.6},
	},
	['The Barrens']={
		{name="Nozzlepot's Outpost",faction="H",npc="Gazrix",npcid=40558,x=62.31,y=17.12},
		{name="Ratchet",faction="B",npc="Bragok",npcid=16227,x=69.1,y=70.7,factionid=470,factionstanding=3},
		{name="The Crossroads",faction="H",npc="Devrak",npcid=3615,x=48.6,y=58.6},
		{name="The Mor'Shan Ramparts",faction="H",npc="Gort Goreflight",npcid=34927,x=41.98,y=15.87},
	},
	['Orgrimmar']={
		{name="Orgrimmar",faction="H",npc="Doras",npcid=3310,x=49.7,y=59.2},
	},
	['Silithus']={
		{name="Cenarion Hold",faction="A",npc="Cloud Skydancer",npcid=15177,x=54.4,y=32.7},
		{name="Cenarion Hold",faction="H",npc="Runk Windtamer",npcid=15178,x=52.8,y=34.6},
	},
	['Southern Barrens']={
		{name="Desolation Hold",faction="H",npc="Crador",npcid=39330,x=41.24,y=70.76},
		{name="Fort Triumph",faction="A",npc="Steve Stevenson",npcid=39211,x=49.2,y=67.8},
		{name="Honor's Stand",faction="A",npc="John Johnson",npcid=39210,x=38.9,y=10.9},
		{name="Hunter's Hill",faction="H",npc="Unega",npcid=39340,x=39.79,y=20.26},
		{name="Northwatch Hold",faction="A",npc="Bill Williamson",npcid=39212,x=66.4,y=47.1},
		{name="Vendetta Point",faction="H",npc="Lognah",npcid=52060,x=41.55,y=47.60}, -- nodeID = 77
	},
	['Stonetalon Mountains']={
		{name="Farwatcher's Glen",faction="A",npc="Ceyora",npcid=35138,x=32.0,y=61.8},
		{name="Mirkfallon Post",faction="A",npc="Fiora Moonsoar",npcid=41240,x=48.6,y=51.5},
		{name="Northwatch Expedition Base Camp",faction="A",npc="Kaluna Songflight",npcid=35136,x=70.9,y=80.6},
		{name="Thal'darah Overlook",faction="A",npc="Teloren",npcid=4407,x=40.1,y=32.0},
		{name="Windshear Hold",faction="A",npc="Allana Swiftglide",npcid=35137,x=58.8,y=54.3},
		{name="Cliffwalker Post",faction="H",npc="Orna Skywatcher",npcid=35141,x=45.11,y=30.87},
		{name="Krom'gar Fortress",faction="H",npc="Kormal the Swift",npcid=35140,x=66.5,y=62.8},
		{name="Sun Rock Retreat",faction="H",npc="Tharm",npcid=4312,x=48.48,y=61.95},
		{name="The Sludgewerks",faction="H",npc="Flok",npcid=41246,x=53.87,y=40.12},
		{name="Malaka'jin",faction="H",npc="Zillane",npcid=35139,x=70.6,y=89.4},
	},
	['Tanaris']={
		{name="Bootlegger Outpost",faction="B",npc="Slick Dropdip",npcid=41214,x=55.9,y=60.6},
		{name="Dawnrise Expedition",faction="H",npc="Raina Sunglide",npcid=41215,x=33.3,y=77.4},
		{name="Gadgetzan",faction="A",npc="Bera Stonehammer",npcid=7823,x=51.4,y=29.5,factionid=369,factionstanding=3},
		{name="Gadgetzan",faction="H",npc="Bulkrek Ragefist",npcid=7824,x=52.0,y=27.6,factionid=369,factionstanding=3},
		{name="Gunstan's Dig",faction="A",npc="Thurda",npcid=40827,x=40.0,y=77.5},
	},
	['Teldrassil']={
		{name="Dolanaar",faction="A",npc="Fidelio",npcid=40553,x=55.5,y=50.4},
		{name="Rut'theran Village",faction="A",npc="Vesprystus",npcid=3838,x=55.4,y=88.4},
	},
	['The Exodar']={
		{name="The Exodar",faction="A",npc="Stephanos",npcid=17555,x=54.5,y=36.3},
	},
	['Thousand Needles']={
		{name="Fizzle & Pozzik's Speedbarge",faction="A",npc="Tilly Topspin",npcid=40768,x=79.2,y=72.0},
		{name="Fizzle & Pozzik's Speedbarge",faction="H",npc="Zazzix Boomride",npcid=40769,x=79.0,y=71.8},
		{name="Westreach Summit",faction="H",npc="Nah'te",npcid=44399,x=11.2,y=11.4},
	},
	['Thunder Bluff']={
		{name="Thunder Bluff",faction="H",npc="Tal",npcid=2995,x=46.8,y=49.8},
	},
	['Uldum']={
		{name="Oasis of Vir'sar",faction="B",npc="Jock Lindsey",npcid=48274,x=26.6,y=8.4},
		{name="Ramkahen",faction="B",npc="Kurzel",npcid=48275,x=56.2,y=33.6},
		{name="Schnottz's Landing",faction="B",npc="Evax Oilspark",npcid=48273,x=22.3,y=64.9},
	},
	['Un\'Goro Crater']={
		{name="Marshal's Stand",faction="B",npc="Gryfe",npcid=10583,x=56.0,y=64.2},
		{name="Mossy Pile",faction="B",npc="Flizzy Coilspanner",npcid=39175,x=44.1,y=40.3},
	},
	['Winterspring']={
		{name="Everlook",faction="A",npc="Maethrya",npcid=11138,x=61.0,y=48.6,factionid=577,factionstanding=3},
		{name="Everlook",faction="H",npc="Yugrek",npcid=11139,x=58.8,y=48.3,factionid=577,factionstanding=3},
	},
}



----------------------------
--- EASTERN KINGDOMS ---
----------------------------
data.taxipoints[13]={
	['Abyssal Depths']={
		{name="Darkbreak Cove",faction="A",npc="Swift Seahorse",npcid=40866,x=56.9,y=75.5,taxioperator="seahorse"},
		{name="Tenebrous Cavern",faction="H",npc="Swift Seahorse",npcid=40873,x=53.9,y=59.6,taxioperator="seahorse"},
	},
	['Arathi Highlands']={
		{name="Galen's Fall",faction="H",npc="Rhoda Bowers",npcid=43104,x=13.3,y=34.8},
		{name="Hammerfall",faction="H",npc="Urda",npcid=2851,x=68.2,y=33.4},
		{name="Refuge Pointe",faction="A",npc="Cedrik Prose",npcid=2835,x=39.9,y=47.3},
	},
	['Badlands']={
		{name="Bloodwatcher Point",faction="H",npc="Selara",npcid=44408,x=52.4,y=50.8},
		{name="Dragon's Mouth",faction="A",npc="Jake Badlands",npcid=44410,x=21.7,y=57.8},
		{name="Dustwind Dig",faction="A",npc="Nancy Skybrew",npcid=44409,x=49.0,y=36.2},
		{name="Fuselight",faction="B",npc="Mixi Sweetride",npcid=44407,x=64.3,y=35.0},
		{name="New Kargath",faction="H",npc="Gorrik",npcid=2861,x=17.2,y=40.0},
	},
	['Blasted Lands']={
		{name="Dreadmaul Hold",faction="H",npc="Preda",npcid=43121,x=43.7,y=14.3},
		{name="Nethergarde Keep",faction="A",npc="Alexandra Constantine",npcid=8609,x=61.3,y=21.6},
		{name="Sunveil Excursion",faction="H",npc="Salena",npcid=43114,x=50.9,y=72.9},
		{name="Surwich",faction="A",npc="Graham McAllister",npcid=43107,x=47.1,y=89.3},
	},
	['Burning Steppes']={
		{name="Chiselgrip",faction="B",npc="Grimly Singefeather",npcid=48321,x=46.2,y=41.8},
		{name="Flame Crest",faction="H",npc="Vahgruk",npcid=13177,x=54.1,y=24.3},
		{name="Flamestar Post",faction="B",npc="Hans Oreflight",npcid=48318,x=17.79,y=52.75},
		{name="Morgan's Vigil",faction="A",npc="Borgus Stoutarm",npcid=2299,x=72.1,y=65.7},
	},
	['Dun Morogh']={
		{name="Gol'Bolar Quarry",faction="A",npc="Dominic Galebeard",npcid=43702,x=75.9,y=54.4},
		{name="Kharanos",faction="A",npc="Brolan Galebeard",npcid=43701,x=53.8,y=52.8},
	},
	['Duskwood']={
		{name="Darkshire",faction="A",npc="Felicia Maline",npcid=2409,x=77.5,y=44.3},
		{name="Raven Hill",faction="A",npc="John Shelby",npcid=43697,x=21.1,y=56.4},
	},
	['Eastern Plaguelands']={
		{name="Acherus: The Ebon Hold",faction="B",class="DEATHKNIGHT", npc="Grimwing",npcid=29480,x=83.8,y=50.3},
		{name="Light's Hope Chapel",faction="H",npc="Georgia",npcid=12636,x=75.8,y=53.3},
		{name="Light's Hope Chapel",faction="A",npc="Khaelyn Steelwing",npcid=12617,x=75.84,y=53.41},
		{name="Eastwall Tower",faction="B",npc="Richard Trueflight",npcid=44230,x=61.6,y=43.9},
		{name="Northpass Tower",faction="B",npc="Grayson Ironwing",npcid=28621,x=51.4,y=21.3},
		{name="Light's Shield Tower",faction="B",npc="Devon Manning",npcid=44231,x=52.8,y=53.6},
		{name="Crown Guard Tower",faction="B",npc="Janice Myers",npcid=44232,x=34.9,y=67.9},
		{name="Plaguewood Tower",faction="B",npc="William Kielar Jr.",npcid=44233,x=18.5,y=27.4},
		{name="Thondroril River",faction="B",npc="Frax Bucketdrop",npcid=37888,x=10.1,y=65.7},
	},
	['Elwynn Forest']={
		{name="Goldshire",faction="A",npc="Bartlett the Brave",npcid=42983,x=41.7,y=64.6},
		{name="Eastvale Logging Camp",faction="A",npc="Goss the Swift",npcid=43000,x=81.8,y=66.6},
	},
	['Eversong Woods']={
		{name="Fairbreeze Village",faction="H",npc="Skymaster Brightdawn",npcid=44036,x=43.9,y=70.0},
		{name="Silvermoon City",faction="H",npc="Skymistress Gloaming",npcid=16192,x=54.4,y=50.7},
		{name="Falconwing Square",faction="H",npc="Skymaster Skyles",npcid=44244,x=46.2,y=46.8},
	},
	['Ghostlands']={
		{name="Tranquillien",faction="H",npc="Skymaster Sunwing",npcid=16189,x=45.4,y=30.5},
		{name="Zul'Aman",faction="B",npc="Kiz Coilspanner",npcid=24851,x=74.8,y=67.2},
	},
	['Hillsbrad Foothills']={
		{name="Eastpoint Tower",faction="H",npc="Darren Longfellow",npcid=47661,x=59.62,y=63.25},
		{name="Ruins of Southshore",faction="H",npc="Darla Harris",npcid=47644,x=49.0,y=66.2},
		{name="Southpoint Gate",faction="H",npc="Pamela Stutzka",npcid=47655,x=29.1,y=64.4},
		{name="Strahnbrad",faction="H",npc="Phillip Harding",npcid=47665,x=58.2,y=26.5},
		{name="Tarren Mill",faction="H",npc="Zarise",npcid=2389,x=56.1,y=46.1},
	},
	['Ironforge']={
		{name="Ironforge",faction="A",npc="Gryth Thurden",npcid=1573,x=55.5,y=47.8},
	},
	['Isle of Quel\'Danas']={
		{name="Shattered Sun Staging Area",faction="B",npc="Ohura",npcid=26560,x=48.4,y=25.1}, -- Sun's Reach Harbor ?
	},
	['Kelp\'thar Forest']={
		{name="Smuggler's Scar",faction="B",npc="Swift Seahorse",npcid=40852,x=56.1,y=31.2,taxioperator="seahorse"},
		{name="Sandy Beach",faction="A",npc="Swift Seahorse",npcid=43287,x=42.4,y=66.2,taxioperator="seahorse"},
		{name="Sandy Beach",faction="H",npc="Swift Seahorse",npcid=43216,x=49.3,y=87.9,taxioperator="seahorse"},
		{name="Stygian Bounty",faction="H",npc="Brogdul",npcid=43225,x=64.8,y=68.0},
	},
	['Loch Modan']={
		{name="Farstrider Lodge",faction="A",npc="Eeryven Grayer",npcid=41332,x=81.9,y=64.1},
		{name="Thelsamar",faction="A",npc="Thorgrum Borrelson",npcid=1572,x=34.0,y=50.9},
	},
	['Northern Stranglethorn']={
		{name="Bambala",faction="H",npc="Raskha",npcid=43052,x=62.4,y=39.3},
		{name="Fort Livingston",faction="A",npc="Robert Rhodes",npcid=43042,x=52.6,y=66.1},
		{name="Grom'gol",faction="H",npc="Thysta",npcid=1387,x=39.0,y=51.3},
		{name="Rebel Camp",faction="A",npc="James Stillair",npcid=43045,x=47.9,y=11.9},
	},
	['Redridge Mountains']={
		{name="Camp Everstill",faction="A",npc="Arlen Marsters",npcid=43371,x=52.9,y=54.6},
		{name="Lakeshire",faction="A",npc="Ariena Stormfeather",npcid=931,x=29.4,y=53.8},
		{name="Shalewind Canyon",faction="A",npc="Nora Baldwin",npcid=43072,x=78.0,y=65.9},
	},
	['Searing Gorge']={
		{name="Iron Summit",faction="B",npc="Doug Deepdown",npcid=47927,x=41.1,y=68.8},
		{name="Thorium Point",faction="A",npc="Lanie Reed",npcid=2941,x=37.9,y=30.9},
		{name="Thorium Point",faction="H",npc="Grisha",npcid=3305,x=34.8,y=30.9},
	},
	['Shimmering Expanse']={
		{name="Sandy Beach",faction="A",npc="Francis Greene",npcid=43290,x=57.0,y=17.0},
		{name="Silver Tide Hollow",faction="B",npc="Swift Seahorse",npcid=40851,x=49.5,y=41.2,taxioperator="seahorse"},
		{name="Tranquil Wash",faction="A",npc="Swift Seahorse",npcid=40867,x=48.6,y=57.4,taxioperator="seahorse"},
		{name="Voldrin's Hold",faction="A",quest=26005,npc="Salty McTavish",npcid=43295,x=69.4,y=75.2},
		{name="Voldrin's Hold",faction="A",quest=26005,npc="Swift Seahorse",npcid=43289,x=57.1,y=75.2,taxioperator="seahorse"},
		{name="Stygian Bounty",faction="H",quest=26006,npc="Brogdul",npcid=43225,x=49.5,y=65.6},
		{name="Stygian Bounty",faction="H",quest=26006,npc="Swift Seahorse",npcid=40871,x=50.8,y=63.4,taxioperator="seahorse"},
		{name="Sandy Beach",faction="H",npc="Briglar",npcid=43220,x=61.0,y=28.4},
		{name="Legion's Rest",faction="H",npc="Swift Seahorse",npcid=40871,x=50.8,y=63.5,taxioperator="seahorse"},
	},
	['Silverpine Forest']={
		{name="The Forsaken Front",faction="H",npc="Steven Stutzka",npcid=46552,x=50.8,y=63.6},
		{name="The Sepulcher",faction="H",npc="Karos Razok",npcid=2226,x=45.4,y=42.5},
		{name="Forsaken Rear Guard",faction="H",npc="Franny Mertz",npcid=50463,x=45.9,y=21.9},
		{name="Forsaken High Command",quest=26965,faction="H",npc="Bat Handler Maggotbreath",npcid=44825,x=57.9,y=8.7},
	},
	['Stormwind City']={
		{name="Stormwind",faction="A",npc="Dungar Longdrink",npcid=352,x=70.9,y=72.5},
	},
	['Swamp of Sorrows']={
		{name="Bogpaddle",faction="B",npc="Skeezie",npcid=43086,x=72.0,y=12.0},
		{name="Marshtide Watch",faction="A",npc="Paola Baldwin",npcid=43087,x=70.0,y=38.6},
		{name="Stonard",faction="H",npc="Breyk",npcid=6026,x=47.8,y=55.2},
		{name="The Harborage",faction="A",npc="Yedrin",npcid=43088,x=30.8,y=34.6},
	},
	['The Cape of Stranglethorn']={
		{name="Booty Bay",faction="A",npc="Gyll",npcid=2859,x=41.7,y=74.5,factionid=21,factionstanding=3},
		{name="Booty Bay",faction="H",npc="Gringer",npcid=2858,x=40.6,y=73.4,factionid=21,factionstanding=3},
		{name="Explorers' League Digsite",faction="A",npc="Colin Swifthammer",npcid=43043,x=55.7,y=41.2},
		{name="Hardwrench Hideaway",faction="H",npc="Hizzle",npcid=43053,x=35.2,y=29.4},
	},
	['The Hinterlands']={
		{name="Aerie Peak",faction="A",npc="Guthrum Thunderfist",npcid=8018,x=11.1,y=46.3},
		{name="Hiri'watha Research Station",faction="H",npc="Kellen Kuhn",npcid=43573,x=32.5,y=58.1},
		{name="Revantusk Village",faction="H",npc="Gorkas",npcid=4314,x=81.7,y=81.8},
		{name="Stormfeather Outpost",faction="A",npc="Brock Rockbeard",npcid=43570,x=65.8,y=44.9},
	},
	['Tirisfal Glades']={
		{name="Brill",faction="H",npc="Anette Williams",npcid=43124,x=58.8,y=51.9},
		{name="The Bulwark",faction="H",npc="Timothy Cunningham",npcid=37915,x=83.6,y=70.0},
	},
	['Undercity']={
		{name="Undercity",faction="H",npc="Michael Garrett",npcid=4551,x=63.3,y=48.6},
	},
	['Twilight Highlands']={
		{name="Bloodgulch",faction="H",npc="Bramok Gorewing",npcid=47156,x=54.1,y=42.2},
		{name="Crushblow",faction="H",npc="Tokrog",npcid=47116,x=45.8,y=76.2},
		{name="Dragonmaw Port",quest=26830,faction="H",npc="Gorthul",npcid=47174,x=73.8,y=52.8},
		{name="Firebeard's Patrol",faction="A",npc="Farstad Stonegrip",npcid=47147,x=60.4,y=57.6},
		{name="Highbank",faction="A",quest=28598,npc="Glenn Arbuckle",npcid=47119,x=81.6,y=77.0},
		{name="Kirthaven",faction="A",npc="Shaina Talonheart",npcid=47155,x=56.8,y=15.1},
		{name="The Gullet",faction="H",npc="San'shigo",npcid=47133,x=36.9,y=38.0},
		{name="The Krazzworks",faction="H",npc="Harpo Boltknuckle",npcid=47061,x=75.3,y=17.8},
		{name="Thundermar",faction="A",npc="Doran Talonheart",npcid=47154,x=48.5,y=28.1},
		{name="Vermillion Redoubt",faction="N",quest=27504,npc="Aquinastrasz",npcid=47121,x=28.6,y=24.9},
		{name="Victor's Point",faction="A",npc="Desmond Chadsworth",npcid=47118,x=43.9,y=57.3},
	},
	['Western Plaguelands']={
		{name="The Menders' Stead",faction="B",npc="Marge Heffman",npcid=46011,x=50.5,y=52.2},
		{name="Andorhal",faction="H",npc="Rhonda Molver",npcid=46004,x=46.5,y=64.7},
		{name="Andorhal",faction="A",npc="Ginny Goodwin",npcid=46006,x=39.5,y=69.5},
		{name="Hearthglen",faction="B",npc="William Henderson",npcid=47875,x=44.7,y=18.5},
		{name="Chillwind Camp",faction="A",npc="Bibilfaz Featherwhistle",npcid=12596,x=42.9,y=85.1},
	},
	['Westfall']={
		{name="Sentinel Hill",faction="A",npc="Thor",npcid=523,x=56.6,y=49.4},
		{name="Moonbrook",faction="A",npc="Tina Skyden",npcid=42426,x=42.1,y=63.3},
		{name="Furlbrow's Pumpkin Farm",faction="A",npc="Hoboair",npcid=42406,x=49.8,y=18.7},
	},
	['Wetlands']={
		{name="Dun Modr",faction="A",npc="Caleb Baelor",npcid=41325,x=49.9,y=18.6},
		{name="Greenwarden's Grove",faction="A",npc="Halana",npcid=41322,x=56.3,y=41.9},
		{name="Menethil Harbor",faction="A",npc="Shellei Brondir",npcid=1571,x=9.5,y=59.6},
		{name="Slabchisel's Survey",faction="A",npc="Elgin Baelor",npcid=41321,x=56.9,y=71.1},
		{name="Whelgar's Retreat",faction="A",npc="Damon Baelor",npcid=41323,x=38.8,y=39.0},
	},
}



-------------------
--- OUTLAND ---
-------------------
data.taxipoints[102]={
	['Blade\'s Edge Mountains']={
		{name="Evergrove",faction="B",npc="Fhyn Leafshadow",npcid=22216,x=61.7,y=39.6},
		{name="Skyguard Outpost",faction="B",factionid=1031,factionstanding=6,npc="Skyguard Handler Irena",npcid=23413,x=28.2,y=52.0,taxioperator="skyguard"},
		{name="Sylvanaar",faction="A",npc="Amerun Leafshade",npcid=18937,x=37.8,y=61.4},
		{name="Thunderlord Stronghold",faction="H",npc="Unoke Tenderhoof",npcid=18953,x=52.0,y=54.1},
		{name="Mok'Nathal Village",faction="H",npc="Sky-Master Maxxor",npcid=22455,x=76.4,y=65.8},
		{name="Toshley's Station",faction="A",npc="Rip Pedalslam",npcid=21107,x=61.2,y=70.4},
	},
	['Hellfire Peninsula']={
		{name="Falcon Watch",faction="H",npc="Innalia",npcid=18942,x=27.8,y=60.0},
		{name="Honor Hold",faction="A",npc="Flightmaster Krill Bitterhue",npcid=16822,x=54.7,y=62.4},
		{name="Shatter Point",faction="A",npc="Runetog Wildhammer",npcid=20234,x=78.4,y=34.9},
		{name="Spinebreaker Ridge",faction="H",npc="Amilya Airheart",npcid=19558,x=61.7,y=81.2},
		{name="Temple of Telhamat",faction="A",npc="Kuma",npcid=18785,x=25.2,y=37.2},
		{name="Hellfire Peninsula, The Dark Portal",faction="A",npc="Amish Wildhammer",npcid=18931,x=87.4,y=52.4},
		{name="Hellfire Peninsula, The Dark Portal",faction="H",npc="Vlagga Freyfeather",npcid=18930,x=87.3,y=48.1},
		{name="Thrallmar",faction="H",npc="Barley",npcid=16587,x=56.3,y=36.2},
	},
	['Nagrand']={
		{name="Garadar",faction="H",npc="Gursha",npcid=18808,x=57.2,y=35.3},
		{name="Telaar",faction="A",npc="Furgu",npcid=18789,x=54.2,y=75.1},
	},
	['Netherstorm']={
		{name="Area 52",faction="B",npc="Krexcil",npcid=18938,x=33.8,y=64.0},
		{name="Cosmowrench",faction="B",npc="Harpax",npcid=20515,x=65.2,y=66.8},
		{name="The Stormspire",faction="B",npc="Grennik",npcid=19583,x=45.3,y=34.9},
	},
	['Shadowmoon Valley']={
		{name="Altar of Sha'tar",faction="B",factionid=932,factionstanding=3,npc="Maddix",npcid=19581,x=63.3,y=30.4},
		{name="Sanctum of the Stars",faction="B",factionid=934,factionstanding=3,npc="Alieshor",npcid=21766,x=56.3,y=57.8},
		{name="Shadowmoon Village",faction="H",npc="Drek'Gol",npcid=19317,x=30.3,y=29.2},
		{name="Wildhammer Stronghold",faction="A",npc="Brubeck Stormfoot",npcid=18939,x=37.6,y=55.5},
	},
	['Shattrath City']={
		{name="Shattrath",faction="B",npc="Nutral",npcid=18940,x=64.1,y=41.1},
	},
	['Terokkar Forest']={
		{name="Allerian Stronghold",faction="A",npc="Furnan Skysoar",npcid=18809,x=59.4,y=55.4},
		{name="Blackwing Landing",faction="B",factionid=1031,factionstanding=6,npc="Skyguard Handler Deesak",npcid=23415,x=63.6,y=65.8,taxioperator="skyguard"},
		{name="Stonebreaker Hold",faction="H",npc="Kerna",npcid=18807,x=49.2,y=43.4},
	},
	['Zangarmarsh']={
		{name="Orebor Harborage",faction="A",npc="Halu",npcid=22485,x=41.3,y=29.0},
		{name="Swamprat Post",faction="H",npc="Gur'zil",npcid=20762,x=84.8,y=55.1},
		{name="Telredor",faction="A",npc="Munci",npcid=18788,x=67.8,y=51.5},
		{name="Zabra'jin",faction="H",npc="Du'ga",npcid=18791,x=33.1,y=51.1},
	},
}




---------------------
--- NORTHREND ---
---------------------
data.taxipoints[113]={
	['Borean Tundra']={
		{name="Valiance Keep",faction="A",npc="Tomas Riverwell",npcid=26879,x=59.0,y=68.3},
		{name="Warsong Hold",faction="H",npc="Turida Coldwind",npcid=25288,x=40.4,y=51.4},
		{name="Transitus Shield",faction="B",npc="Warmage Adami",npcid=27046,x=33.1,y=34.5},
		{name="Amber Ledge",faction="B",npc="Surristrasz",npcid=24795,x=45.3,y=34.5},
		{name="Bor'gorok Outpost",faction="H",npc="Kimbiza",npcid=26848,x=49.6,y=11.1},
		{name="Fizzcrank Airstrip",faction="A",npc="Kara Thricestar",npcid=26602,x=56.6,y=20.1},
		{name="Unu'pe",faction="B",npc="Bilko Driftspark",npcid=28195,x=78.5,y=51.5},
		{name="Taunka'le Village",faction="H",npc="Omu Spiritbreeze",npcid=26847,x=77.8,y=37.8},
	},
	['Crystalsong Forest']={
		{name="Windrunner's Overlook",faction="A",npc="Galendror Whitewing",npcid=30271,x=72.2,y=81.0},
		{name="Sunreaver's Command",faction="H",npc="Skymaster Baeric",npcid=30269,x=78.5,y=50.5},
	},
	['Dalaran']={
		{name="Dalaran",faction="B",npc="Aludane Whitecloud",npcid=28674,x=72.8,y=45.6},
	},
	['Dragonblight']={
		{name="Stars' Rest",faction="A",npc="Palena Silvercloud",npcid=26881,x=29.2,y=55.3},
		{name="Agmar's Hammer",faction="H",npc="Narzun Skybreaker",npcid=26566,x=37.5,y=45.8},
		{name="Fordragon Hold",faction="A",npc="Derek Rammel",npcid=26877,x=39.5,y=25.9},
		{name="Kor'kron Vanguard",faction="H",npc="Numo Spiritbreeze",npcid=26850,x=43.8,y=17.0},
		{name="Wyrmrest Temple",faction="B",npc="Nethestrasz",npcid=26851,x=60.3,y=51.6},
		{name="Wintergarde Keep",faction="A",npc="Rodney Wells",npcid=26878,x=77.0,y=49.8},
		{name="Venomspite",faction="H",npc="Junter Weiss",npcid=26845,x=76.5,y=62.2},
		{name="Moa'ki",faction="B",npc="Cid Flounderfix",npcid=28196,x=48.51,y=74.39},
	},
	['Gilneas']={
		{name="Forsaken Forward Command",quest=999999,faction="H",npc="Bat Handler Doomair",npcid=45479,x=57.25,y=17.96},
			--enabled after 27290 quest disabled after quest 27405, just assume we dont know it.
	},
	['Grizzly Hills']={
		{name="Amberpine Lodge",faction="A",npc="Vana Grey",npcid=26880,x=31.3,y=59.1},
		{name="Conquest Hold",faction="H",npc="Kragh",npcid=26852,x=22.0,y=64.4},
		{name="Camp Oneqwah",faction="H",npc="Makki Wintergale",npcid=26853,x=65.0,y=46.9},
		{name="Westfall Brigade",faction="A",npc="Samuel Clearbook",npcid=26876,x=59.9,y=26.7},
	},
	['Howling Fjord']={
		{name="Camp Winterhoof",faction="H",npc="Celea Frozenmane",npcid=24032,x=49.6,y=11.6},
		{name="Fort Wildervar",faction="A",npc="James Ormsby",npcid=24061,x=60.1,y=16.1},
		{name="Vengeance Landing",faction="H",npc="Adeline Chambers",npcid=27344,x=79.0,y=29.7},
		{name="Valgarde Port",faction="A",npc="Pricilla Winterwind",npcid=23736,x=59.8,y=63.2},
		{name="New Agamand",faction="H",npc="Tobias Sarkhoff",npcid=24155,x=52.0,y=67.4},
		{name="Kamagua",faction="B",npc="Kip Trawlskip",npcid=28197,x=24.7,y=57.8},
		{name="Westguard Keep",faction="A",npc="Greer Orehammer",npcid=23859,x=31.3,y=44.0},
		{name="Apothecary Camp",faction="H",npc="Lilleth Radescu",npcid=26844,x=26.0,y=25.1},
	},
	['Icecrown']={
		{name="Argent Tournament Grounds",faction="B",npc="Helidan Lightwing",npcid=33849,x=72.6,y=22.6},
		{name="The Shadow Vault",faction="A",quest=12896,npc="Morlia Doomwing",npcid=30314,x=43.7,y=24.4},
		{name="The Shadow Vault",faction="H",quest=12897,npc="Morlia Doomwing",npcid=30314,x=43.7,y=24.4},
		{name="Death's Rise",faction="B",npc="Dreadwind",npcid=31078,x=19.3,y=47.8},
		{name="Crusaders' Pinnacle",faction="B",quest=13141,npc="Penumbrius",npcid=31069,x=79.4,y=72.4},
		{name="The Argent Vanguard",faction="B",npc="Aedan Moran",npcid=30433,x=87.8,y=78.1},
	},
	['Sholazar Basin']={
		{name="River's Heart",faction="B",npc="Marvin Wobblesprocket",npcid=28574,x=50.1,y=61.4},
		{name="Nesingwary Base Camp",faction="B",quest=12523,npc="The Spirit of Gnomeregan",npcid=28037,x=25.3,y=58.4},
	},
	['The Storm Peaks']={
		{name="K3",faction="B",npc="Skizzle Slickslide",npcid=29721,x=40.8,y=84.5},
		{name="Frosthold",faction="A",npc="Faldorf Bitterchill",npcid=29750,x=29.5,y=74.3},
		{name="Grom'arsh Crash-Site",faction="H",npc="Kabarg Windtamer",npcid=29757,x=36.2,y=49.4},
		{name="Dun Niffelem",faction="B",quest=12956,npc="Halvdan",npcid=32571,x=62.6,y=60.9},
		{name="Camp Tunka'lo",faction="H",npc="Hyeyoung Parka",npcid=29762,x=65.4,y=50.6},
		{name="Ulduar",faction="B",npc="Shavalius the Fancy",npcid=29951,x=44.5,y=28.2},
		{name="Bouldercrag's Refuge",faction="B",npc="Breck Rockbrow",npcid=29950,x=30.6,y=36.3},
	},
	['Wintergrasp']={
		{name="Wintergrasp",faction="A",npc="Arzo Safeflight",npcid=30869,x=72.0,y=30.9},
		{name="Warsong Camp",faction="H",npc="Herzo Safeflight",npcid=30870,x=21.6,y=35.0},
		{name="Valiance Landing Camp",faction="A",npc="Arzo Safeflight",npcid=30869,x=72.0,y=31.0},
	},
	['Zul\'Drak']={
		{name="Light's Breach",faction="B",npc="Danica Saint",npcid=28618,x=32.2,y=74.4},
		{name="Ebon Watch",faction="B",npc="Baneflight",npcid=28615,x=14.0,y=73.6},
		{name="The Argent Stand",faction="B",npc=" Gurric",npcid=28623,x=41.5,y=64.4},
		{name="Zim'Torga",faction="B",npc="Maaka",npcid=28624,x=60.0,y=56.7},
		{name="Gundrak",faction="B",npc="Rafae",npcid=30569,x=70.5,y=23.3},
	},
}

------------------------------------------------
-----  PANDARIA (MISTS OF PANDARIA)  -----
------------------------------------------------
data.taxipoints[424]={

	['The Jade Forest']={
		{name="Dawn's Blossom",faction="B",npc="Keg Runner Lee",npcid=59186,x=47.0,y=46.2},
		{name="Emperor's Omen",faction="B",npc="Supplier Towsa",npcid=59735,x=50.82,y=26.80},
		{name="Grookin Hill",faction="H",npc="Grookin Flapmaster",npcid=60952,x=27.8,y=47.9},
		{name="Honeydew Village",faction="H",npc="Wing Hya",npcid=66227,x=28.1,y=15.6},
		{name="Jade Temple Grounds",faction="B",npc="Ginsa Arroweye",npcid=59727,x=54.6,y=61.9},
		{name="Paw'Don Village",faction="A",npc="Wing Kyo",npcid=66023,x=46.0,y=85.1},
		{name="Pearlfin Village",faction="A",npc="Ut-Nam",npcid=56737,x=58.0,y=82.5},
		{name="Serpent's Overlook",faction="A",npc="Sky Dancer Ji",quest=31362,npcid=64310,x=43.1,y=68.5,available=function() return IsSpellKnown(115913) end},
		{name="Serpent's Overlook",faction="H",npc="Sky Dancer Ji",quest=30485,npcid=64310,x=43.1,y=68.5,available=function() return IsSpellKnown(115913) end},
		{name="Sri-La Village",faction="B",npc="Gingo Alebottom",npcid=59733,x=55.4,y=23.7},
		{name="The Arboretum",faction="B",npc="Injar'i Lakebloom",npcid=59732,x=57.0,y=44.0},
		{name="Tian Monastery",faction="B",npc="Studious Chu",npcid=59736,x=43.6,y=24.6},
	},
	['Krasarang Wilds']={
		{name="Cradle of Chi-Ji",faction="B",npc="Feather Keeper Li",npcid=65189,x=31.1,y=63.2},
		{name="Dawnchaser Retreat",faction="H",npc="Munch Windhoof",npcid=59047,x=29.0,y=50.3},
		{name="Domination Point",faction="H",npc="Kromthar",npcid=67785,x=9.7,y=52.5},
		{name="Lion's Landing",faction="A",npc="Daggin Windbeard",npcid=2690,x=88.3,y=34.7},
		{name="Marista",faction="B",npc="Nan-Po",npcid=60441,x=52.4,y=76.6},
		{name="Sentinel Basecamp",faction="A",npc="Maylen Moonfeather",npcid=59048,x=25.2,y=33.5},
		{name="The Incursion",faction="A",npc="Tylen Moonfeather",npcid=59049,x=67.8,y=32.5},
		{name="Thunder Cleft",faction="H",npc="Lira Skysplitter",npcid=59046,x=59.2,y=24.6},
		{name="Zhu's Watch",faction="B",npc="Gee Hung",npcid=60232,x=76.7,y=8.4},
	},
	['Valley of the Four Winds']={
		{name="Pang's Stead",faction="B",npc="Princeton",npcid=60230,x=84.5,y=21.1},
		{name="Grassy Cline",faction="B",npc="Kim of the Mountain Winds",npcid=62658,x=70.8,y=24.1},
		{name="Halfhill",faction="B",npc="Wing Nga",npcid=60231,x=56.5,y=50.4},
		{name="Stoneplow",faction="B",npc="\"Dragonwing\" Dan",npcid=58843,x=20.3,y=58.7},
	},
	['Vale of Eternal Blossoms']={
		{name="Serpent's Spine",faction="B",npc="Mai of the Wall",npcid=63497,x=14.2,y=79.2, taxinodeID=1073},
		{name="Shrine of Two Moons",faction="H",npc="Tania Summerbreeze",npcid=61122,x=62.9,y=21.8},
		{name="Shrine of Seven Stars",faction="A",npc="Sharinga Springrunner",npcid=61121,x=84.6,y=62.4},
	},
	['The Veiled Stair']={
		{name="Tavern in the Mists",faction="B",npc="Shin the Weightless",npcid=61759,x=56.7,y=75.7},
	},
	['Kun-Lai Summit']={
		{name="Binan Village",faction="B",npc="Jo the Wind Watcher",npcid=61474,x=72.5,y=94.2},
		{name="Westwind Rest",faction="A",npc="Tabo the Flyer",npcid=61744,x=54.0,y=84.3},
		{name="Eastwind Rest",faction="H",npc="Soaring Paw",npcid=61745,x=62.4,y=80.7},
		{name="Temple of the White Tiger",faction="B",npc="Big Greenfeather",npcid=61118,x=66.3,y=50.7},
		{name="Zouchin Village",faction="B",npc="Bo the Wind Claimer",npcid=61511,x=62.4,y=30.1},
		{name="One Keg",faction="B",npc="Little Cleankite",npcid=61504,x=57.7,y=59.7},
		{name="Kota Basecamp",faction="B",npc="Uncle Eastwind",npcid=60416,x=42.8,y=69.6},
		{name="Shado-Pan Fallback",faction="B",npc="Kite Master Ni",npcid=61473,x=43.9,y=89.6},
		{name="Winter's Blossom",faction="B",npc="Kite Master Len",npcid=61512,x=34.5,y=59.1},
		{name="Serpent's Spine",faction="H",npc="Morla Skyblade",npcid=65863,x=36.0,y=83.7, taxinodeID=1117},
	},
	['Townlong Steppes']={
		{name="Longying Outpost",faction="B",npc="Kite Master Wong",npcid=62901,x=71.1,y=57.3},
		{name="Gao-Ran Battlefront",faction="B",npc="Kite Master Nenshi",npcid=62903,x=74.4,y=81.5},
		{name="Rensai's Watchpost",faction="B",npc="Kite Master Li-Sen",npcid=62898,x=54.3,y=79.0},
		{name="Shado-Pan Garrison",faction="B",npc="Kite Master Yao-Li",npcid=62909,x=50.1,y=72.0},
	},
	['Dread Wastes']={
		{name="The Sunset Brewgarden",faction="B",npc="Jin the Flying Keg",npcid=63500,x=50.2,y=12.2},
		{name="Klaxxi'vess",faction="B",npc="Kik'tik",npcid=63501,x=55.8,y=34.9},
		{name="Soggy's Gamble",faction="B",npc="Min the Breeze Rider",npcid=63498,x=56.1,y=70.2},
		{name="The Briny Muck",faction="B",npc="Infiltrator Ik'thal",npcid=65511,x=42.5,y=55.8},
		{name="The Lion's Redoubt",faction="A",npc="Tiper Windman",npcid=65865,x=73.0,y=33.1},
	},
	['Isle of Giants']={
		{name="Beeble's Wreck",faction="A",npc="Beeble Sockwrench",npcid=69359,x=41.8,y=79.3},
		{name="Bozzle's Wreck",faction="H",npc="Bozzle Blastinfuse",npcid=69360,x=52.0,y=75.5},
	},
	['Timeless Isle']={
		{name="Tushui Landing",faction="A",npc="Michi Windblossom",npcid=71940,x=23.1,y=71.0},
		{name="Huojin Landing",faction="H",npc="Chi-Ro the Skytamer",npcid=71939,x=21.9,y=39.7},
	},
}




-- NOTE: If two taxis have the same name but different factions then a factions field must be added in here. See Serpent's Spine.
-- If not then one of the taxis will be marked with the wrong faction so will not properly get neighbors that it should.
-- This data is regenerated when performing a Taxi Connections Dump. Any weird data edits may be lost. 





data.flightcost = {}










--------------------------------------------------
-----  KALIMDOR (VANILLA + CATACLYSM)  -----
--------------------------------------------------
data.flightcost[12]={
	{
		tag = "462:603",
		nodeID = 28,
		name = "Astranaar, Ashenvale",
		neighbors = {
			[26] = 205, -- Lor'danel, Darkshore
			[32] = 388, -- Theramore, Dustwallow Marsh
			[33] = 176, -- Thal'darah Overlook, Stonetalon Mountains
			[80] = 193, -- Ratchet, The Barrens
			[166] = 78, -- Emerald Sanctuary, Felwood
			[167] = 135, -- Forest Song, Ashenvale
			[338] = 52, -- Blackfathom Camp, Ashenvale
			[339] = 88, -- Grove of the Ancients, Darkshore
			[351] = 43, -- Stardust Spire, Ashenvale
		},
	},
	{
		tag = "242:734",
		nodeID = 624,
		name = "Azure Watch, Azuremyst Isle",
		neighbors = {
			[94] = 41, -- The Exodar
		},
	},
	{
		tag = "709:633",
		nodeID = 44,
		name = "Bilgewater Harbor, Azshara",
		neighbors = {
			[22] = 304, -- Thunder Bluff, Mulgore
			[23] = 98, -- Orgrimmar, Durotar
			[25] = 234, -- The Crossroads, The Barrens
			[61] = 149, -- Splintertree Post, Ashenvale
			[613] = 33, -- Southern Rocketway, Azshara
			[614] = 53, -- Northern Rocketway, Azshara
			[52] = 150, -- Everlook, Winterspring
			[683] = 83, -- Valormok, Azshara
		},
	},
	{
		tag = "423:647",
		nodeID = 338,
		name = "Blackfathom Camp, Ashenvale",
		neighbors = {
			[28] = 60, -- Astranaar, Ashenvale
			[33] = 137, -- Thal'darah Overlook, Stonetalon Mountains
			[166] = 110, -- Emerald Sanctuary, Felwood
			[339] = 69, -- Grove of the Ancients, Darkshore
		},
	},
	{
		tag = "218:824",
		nodeID = 93,
		name = "Blood Watch, Bloodmyst Isle",
		neighbors = {
			[94] = 101, -- The Exodar
		},
	},
	{
		tag = "466:393",
		nodeID = 402,
		name = "Bloodhoof Village, Mulgore",
		neighbors = {
			[22] = 50, -- Thunder Bluff, Mulgore
		},
	},
	{
		tag = "618:130",
		nodeID = 539,
		name = "Bootlegger Outpost, Tanaris",
		neighbors = {
			[39] = 60, -- Gadgetzan, Tanaris
			[531] = 64, -- Dawnrise Expedition, Tanaris
			[532] = 51, -- Gunstan's Dig, Tanaris
			[39] = 61, -- Gadgetzan, Tanaris
		},
	},
	{
		tag = "567:358",
		nodeID = 55,
		name = "Brackenwall Village, Dustwallow Marsh",
		neighbors = {
			[22] = 224, -- Thunder Bluff, Mulgore
			[23] = 217, -- Orgrimmar, Durotar
			[25] = 162, -- The Crossroads, The Barrens
			[30] = 111, -- Westreach Summit, Thousand Needles
			[80] = 90, -- Ratchet, The Barrens
			[179] = 62, -- Mudsprocket, Dustwallow Marsh
			[391] = 56, -- Desolation Hold, Southern Barrens
			[77] = 60, -- Vendetta Point, Southern Barrens
			[39] = 205, -- Gadgetzan, Tanaris
		},
	},
	{
		tag = "345:361",
		nodeID = 568,
		name = "Camp Ataya, Feralas",
		neighbors = {
			[38] = 68, -- Shadowprey Village, Desolace
			[569] = 78, -- Stonemaul Hold, Feralas
		},
	},
	{
		tag = "442:306",
		nodeID = 42,
		name = "Camp Mojache, Feralas",
		neighbors = {
			[22] = 259, -- Thunder Bluff, Mulgore
			[25] = 264, -- The Crossroads, The Barrens
			[30] = 43, -- Westreach Summit, Thousand Needles
			[38] = 200, -- Shadowprey Village, Desolace
			[366] = 256, -- Furien's Post, Desolace
			[391] = 104, -- Desolation Hold, Southern Barrens
			[72] = 130, -- Cenarion Hold, Silithus
			[569] = 66, -- Stonemaul Hold, Feralas
			[39] = 201, -- Gadgetzan, Tanaris
		},
	},
	{
		tag = "418:209",
		nodeID = 72,
		name = "Cenarion Hold, Silithus",
		faction = "A",
		neighbors = {
			[39] = 188, -- Gadgetzan, Tanaris
			[41] = 120, -- Feathermoon, Feralas
			[79] = 113, -- Marshal's Stand, Un'Goro Crater
			[386] = 72, -- Mossy Pile, Un'Goro Crater
			[653] = 65, -- Oasis of Vir'sar, Uldum
		},
	},
	{
		tag = "416:207",
		nodeID = 72,
		name = "Cenarion Hold, Silithus",
		faction = "H",
		neighbors = {
			[42] = 130, -- Camp Mojache, Feralas
			[39] = 241, -- Gadgetzan, Tanaris
			[79] = 120, -- Marshal's Stand, Un'Goro Crater
			[386] = 77, -- Mossy Pile, Un'Goro Crater
			[569] = 106, -- Stonemaul Hold, Feralas
			[653] = 64, -- Oasis of Vir'sar, Uldum
		},
	},
	{
		tag = "399:577",
		nodeID = 360,
		name = "Cliffwalker Post, Stonetalon Mountains",
		neighbors = {
			[29] = 43, -- Sun Rock Retreat, Stonetalon Mountains
			[58] = 50, -- Zoram'gar Outpost, Ashenvale
			[350] = 62, -- Hellscream's Watch, Ashenvale
			[362] = 44, -- Krom'gar Fortress, Stonetalon Mountains
			[363] = 63, -- Malaka'jin, Stonetalon Mountains
			[540] = 21, -- The Sludgewerks, Stonetalon Mountains
		},
	},
	{
		tag = "001:001",
		nodeID = -101,
		name = "Darkshore Cat 1, Darkshore",
		taxioperator = "blackcat",
		neighbors = {
			[-103] = 50, -- ?
		},
	},
	{
		tag = "002:002",
		nodeID = -102,
		name = "Darkshore Cat 2, Darkshore",
		taxioperator = "blackcat",
		neighbors = {
			[-105] = 53, -- ?
		},
	},
	{
		tag = "003:003",
		nodeID = -103,
		name = "Darkshore Cat 3, Darkshore",
		taxioperator = "blackcat",
		neighbors = {
			[-101] = 50, -- ?
			[-104] = 75, -- ?
		},
	},
	{
		tag = "004:004",
		nodeID = -104,
		name = "Darkshore Cat 4, Darkshore",
		taxioperator = "blackcat",
		neighbors = {
			[-101] = 115, -- ?
		},
	},
	{
		tag = "005:005",
		nodeID = -105,
		name = "Darkshore Cat 5, Darkshore",
		taxioperator = "blackcat",
		neighbors = {
			[-102] = 53, -- ?
		},
	},
	{
		tag = "342:897",
		nodeID = 457,
		name = "Darnassus, Teldrassil",
		neighbors = {
			[27] = 109, -- Rut'theran Village, Teldrassil
			[456] = 62, -- Dolanaar, Teldrassil
		},
	},
	{
		tag = "552:097",
		nodeID = 531,
		name = "Dawnrise Expedition, Tanaris",
		neighbors = {
			[539] = 62, -- Bootlegger Outpost, Tanaris
			[39] = 94, -- Gadgetzan, Tanaris
			[652] = 72, -- Ramkahen, Uldum
		},
	},
	{
		tag = "520:352",
		nodeID = 391,
		name = "Desolation Hold, Southern Barrens",
		neighbors = {
			[30] = 101, -- Westreach Summit, Thousand Needles
			[42] = 97, -- Camp Mojache, Feralas
			[55] = 47, -- Brackenwall Village, Dustwallow Marsh
			[179] = 76, -- Mudsprocket, Dustwallow Marsh
			[390] = 98, -- Hunter's Hill, Southern Barrens
			[77] = 48, -- Vendetta Point, Southern Barrens
		},
	},
	{
		tag = "410:893",
		nodeID = 456,
		name = "Dolanaar, Teldrassil",
		neighbors = {
			[457] = 61, -- Darnassus, Teldrassil
		},
	},
	{
		tag = "370:358",
		nodeID = 565,
		name = "Dreamer's Rest, Feralas",
		neighbors = {
			[41] = 56, -- Feathermoon, Feralas
			[367] = 68, -- Thargad's Camp, Desolace
		},
	},
	{
		tag = "505:650",
		nodeID = 166,
		name = "Emerald Sanctuary, Felwood",
		neighbors = {
			[28] = 80, -- Astranaar, Ashenvale
			[58] = 114, -- Zoram'gar Outpost, Ashenvale
			[61] = 83, -- Splintertree Post, Ashenvale
			[65] = 128, -- Talonbranch Glade, Felwood
			[167] = 103, -- Forest Song, Ashenvale
			[338] = 96, -- Blackfathom Camp, Ashenvale
			[339] = 77, -- Grove of the Ancients, Darkshore
			[350] = 70, -- Hellscream's Watch, Ashenvale
			[594] = 97, -- Whisperwind Grove, Felwood
			[595] = 43, -- Wildheart Point, Felwood
		},
	},
	{
		tag = "348:473",
		nodeID = 370,
		name = "Ethel Rethor, Desolace",
		neighbors = {
			[37] = 66, -- Nijel's Point, Desolace
			[38] = 80, -- Shadowprey Village, Desolace
			[366] = 17, -- Furien's Post, Desolace
			[367] = 52, -- Thargad's Camp, Desolace
			[368] = 39, -- Karnum's Glade, Desolace
			[369] = 52, -- Thunk's Abode, Desolace
		},
	},
	{
		tag = "645:766",
		nodeID = 52,
		name = "Everlook, Winterspring",
		faction = "A",
		neighbors = {
			[49] = 110, -- Moonglade
			[65] = 107, -- Talonbranch Glade, Felwood
			[559] = 130, -- Nordrassil, Hyjal
		},
	},
	{
		tag = "640:767",
		nodeID = 52,
		name = "Everlook, Winterspring",
		faction = "H",
		neighbors = {
			[23] = 243, -- Orgrimmar, Durotar
			[44] = 148, -- Bilgewater Harbor, Azshara
			[49] = 134, -- Moonglade
			[559] = 126, -- Nordrassil, Hyjal
			[597] = 122, -- Irontree Clearing, Felwood
		},
	},
	{
		tag = "367:527",
		nodeID = 365,
		name = "Farwatcher's Glen, Stonetalon Mountains",
		neighbors = {
			[33] = 53, -- Thal'darah Overlook, Stonetalon Mountains
			[37] = 63, -- Nijel's Point, Desolace
			[41] = 219, -- Feathermoon, Feralas
			[361] = 76, -- Windshear Hold, Stonetalon Mountains
			[364] = 115, -- Northwatch Expedition Base Camp, Stonetalon Mountains
			[541] = 44, -- Mirkfallon Post, Stonetalon Mountains
		},
	},
	{
		tag = "360:304",
		nodeID = 41,
		name = "Feathermoon, Feralas",
		neighbors = {
			[26] = 495, -- Lor'danel, Darkshore
			[31] = 92, -- Shadebough, Feralas
			[37] = 227, -- Nijel's Point, Desolace
			[72] = 118, -- Cenarion Hold, Silithus
			[365] = 204, -- Farwatcher's Glen, Stonetalon Mountains
			[367] = 147, -- Thargad's Camp, Desolace
			[565] = 55, -- Dreamer's Rest, Feralas
			[567] = 31, -- Tower of Estulan, Feralas
		},
	},
	{
		tag = "611:238",
		nodeID = 513,
		name = "Fizzle & Pozzik's Speedbarge, Thousand Needles",
		faction = "H",
		neighbors = {
			[30] = 132, -- Westreach Summit, Thousand Needles
			[179] = 72, -- Mudsprocket, Dustwallow Marsh
			[39] = 39, -- Gadgetzan, Tanaris
		},
	},
	{
		tag = "611:239",
		nodeID = 513,
		name = "Fizzle & Pozzik's Speedbarge, Thousand Needles",
		faction = "A",
		neighbors = {
			[31] = 180, -- Shadebough, Feralas
			[39] = 43, -- Gadgetzan, Tanaris
			[179] = 72, -- Mudsprocket, Dustwallow Marsh
		},
	},
	{
		tag = "582:610",
		nodeID = 167,
		name = "Forest Song, Ashenvale",
		neighbors = {
			[28] = 142, -- Astranaar, Ashenvale
			[166] = 110, -- Emerald Sanctuary, Felwood
			[616] = 82, -- Gates of Sothann, Hyjal
		},
	},
	{
		tag = "544:358",
		nodeID = 389,
		name = "Fort Triumph, Southern Barrens",
		neighbors = {
			[179] = 66, -- Mudsprocket, Dustwallow Marsh
			[387] = 103, -- Honor's Stand, Southern Barrens
			[388] = 76, -- Northwatch Hold, Southern Barrens
		},
	},
	{
		tag = "358:469",
		nodeID = 366,
		name = "Furien's Post, Desolace",
		neighbors = {
			[29] = 107, -- Sun Rock Retreat, Stonetalon Mountains
			[38] = 68, -- Shadowprey Village, Desolace
			[42] = 249, -- Camp Mojache, Feralas
			[368] = 38, -- Karnum's Glade, Desolace
			[370] = 10, -- Ethel Rethor, Desolace
		},
	},
	{
		tag = "605:192",
		nodeID = 39,
		name = "Gadgetzan, Tanaris",
		faction = "A",
		neighbors = {
			[31] = 214, -- Shadebough, Feralas
			[32] = 154, -- Theramore, Dustwallow Marsh
			[72] = 198, -- Cenarion Hold, Silithus
			[79] = 96, -- Marshal's Stand, Un'Goro Crater
			[80] = 247, -- Ratchet, The Barrens
			[386] = 105, -- Mossy Pile, Un'Goro Crater
			[513] = 49, -- Fizzle & Pozzik's Speedbarge, Thousand Needles
			[532] = 89, -- Gunstan's Dig, Tanaris
			[539] = 54, -- Bootlegger Outpost, Tanaris
		},
	},
	{
		tag = "607:196",
		nodeID = 39,
		name = "Gadgetzan, Tanaris",
		faction = "H",
		neighbors = {
			[22] = 308, -- Thunder Bluff, Mulgore
			[23] = 350, -- Orgrimmar, Durotar
			[25] = 300, -- The Crossroads, The Barrens
			[30] = 167, -- Westreach Summit, Thousand Needles
			[386] = 102, -- Mossy Pile, Un'Goro Crater
			[72] = 233, -- Cenarion Hold, Silithus
			[42] = 199, -- Camp Mojache, Feralas
			[55] = 194, -- Brackenwall Village, Dustwallow Marsh
			[513] = 50, -- Fizzle & Pozzik's Speedbarge, Thousand Needles
			[79] = 100, -- Marshal's Stand, Un'Goro Crater
			[80] = 243, -- Ratchet, The Barrens
			[531] = 98, -- Dawnrise Expedition, Tanaris
			[539] = 57, -- Bootlegger Outpost, Tanaris
		},
	},
	{
		tag = "613:654",
		nodeID = 616,
		name = "Gates of Sothann, Hyjal",
		neighbors = {
			[23] = 74, -- Orgrimmar, Durotar
			[167] = 42, -- Forest Song, Ashenvale
			[557] = 45, -- Shrine of Aviana, Hyjal
			[683] = 37, -- Valormok, Azshara
		},
	},
	{
		tag = "523:699",
		nodeID = 558,
		name = "Grove of Aessina, Hyjal",
		neighbors = {
			[557] = 45, -- Shrine of Aviana, Hyjal
			[559] = 81, -- Nordrassil, Hyjal
		},
	},
	{
		tag = "444:691",
		nodeID = 339,
		name = "Grove of the Ancients, Darkshore",
		neighbors = {
			[26] = 92, -- Lor'danel, Darkshore
			[28] = 85, -- Astranaar, Ashenvale
			[33] = 162, -- Thal'darah Overlook, Stonetalon Mountains
			[65] = 136, -- Talonbranch Glade, Felwood
			[166] = 82, -- Emerald Sanctuary, Felwood
			[338] = 65, -- Blackfathom Camp, Ashenvale
			[595] = 58, -- Wildheart Point, Felwood
		},
	},
	{
		tag = "572:097",
		nodeID = 532,
		name = "Gunstan's Dig, Tanaris",
		neighbors = {
			[39] = 87, -- Gadgetzan, Tanaris
			[539] = 50, -- Bootlegger Outpost, Tanaris
			[652] = 86, -- Ramkahen, Uldum
		},
	},
	{
		tag = "471:612",
		nodeID = 350,
		name = "Hellscream's Watch, Ashenvale",
		neighbors = {
			[29] = 113, -- Sun Rock Retreat, Stonetalon Mountains
			[58] = 60, -- Zoram'gar Outpost, Ashenvale
			[61] = 106, -- Splintertree Post, Ashenvale
			[166] = 91, -- Emerald Sanctuary, Felwood
			[354] = 120, -- The Mor'Shan Ramparts, Ashenvale
			[356] = 47, -- Silverwind Refuge, Ashenvale
			[360] = 85, -- Cliffwalker Post, Stonetalon Mountains
		},
	},
	{
		tag = "513:473",
		nodeID = 387,
		name = "Honor's Stand, Southern Barrens",
		neighbors = {
			[80] = 85, -- Ratchet, The Barrens
			[351] = 112, -- Stardust Spire, Ashenvale
			[364] = 58, -- Northwatch Expedition Base Camp, Stonetalon Mountains
			[388] = 100, -- Northwatch Hold, Southern Barrens
			[389] = 103, -- Fort Triumph, Southern Barrens
		},
	},
	{
		tag = "516:454",
		nodeID = 390,
		name = "Hunter's Hill, Southern Barrens",
		neighbors = {
			[22] = 66, -- Thunder Bluff, Mulgore
			[25] = 43, -- The Crossroads, The Barrens
			[391] = 93, -- Desolation Hold, Southern Barrens
			[77] = 49, -- Vendetta Point, Southern Barrens
		},
	},
	{
		tag = "517:770",
		nodeID = 597,
		name = "Irontree Clearing, Felwood",
		neighbors = {
			[49] = 76, -- Moonglade
			[594] = 41, -- Whisperwind Grove, Felwood
			[52] = 123, -- Everlook, Winterspring
		},
	},
	{
		tag = "383:445",
		nodeID = 368,
		name = "Karnum's Glade, Desolace",
		neighbors = {
			[29] = 91, -- Sun Rock Retreat, Stonetalon Mountains
			[33] = 121, -- Thal'darah Overlook, Stonetalon Mountains
			[37] = 56, -- Nijel's Point, Desolace
			[38] = 83, -- Shadowprey Village, Desolace
			[366] = 39, -- Furien's Post, Desolace
			[367] = 49, -- Thargad's Camp, Desolace
			[369] = 29, -- Thunk's Abode, Desolace
			[370] = 40, -- Ethel Rethor, Desolace
		},
	},
	{
		tag = "451:525",
		nodeID = 362,
		name = "Krom'gar Fortress, Stonetalon Mountains",
		neighbors = {
			[29] = 46, -- Sun Rock Retreat, Stonetalon Mountains
			[354] = 137, -- The Mor'Shan Ramparts, Ashenvale
			[356] = 77, -- Silverwind Refuge, Ashenvale
			[360] = 70, -- Cliffwalker Post, Stonetalon Mountains
			[363] = 68, -- Malaka'jin, Stonetalon Mountains
			[540] = 47, -- The Sludgewerks, Stonetalon Mountains
		},
	},
	{
		tag = "464:794",
		nodeID = 26,
		name = "Lor'danel, Darkshore",
		neighbors = {
			[27] = 61, -- Rut'theran Village, Teldrassil
			[28] = 225, -- Astranaar, Ashenvale
			[32] = 502, -- Theramore, Dustwallow Marsh
			[33] = 267, -- Thal'darah Overlook, Stonetalon Mountains
			[37] = 348, -- Nijel's Point, Desolace
			[41] = 495, -- Feathermoon, Feralas
			[49] = 92, -- Moonglade
			[65] = 96, -- Talonbranch Glade, Felwood
			[339] = 93, -- Grove of the Ancients, Darkshore
		},
	},
	{
		tag = "461:483",
		nodeID = 363,
		name = "Malaka'jin, Stonetalon Mountains",
		neighbors = {
			[22] = 47, -- Thunder Bluff, Mulgore
			[25] = 86, -- The Crossroads, The Barrens
			[29] = 74, -- Sun Rock Retreat, Stonetalon Mountains
			[38] = 164, -- Shadowprey Village, Desolace
			[360] = 111, -- Cliffwalker Post, Stonetalon Mountains
			[362] = 69, -- Krom'gar Fortress, Stonetalon Mountains
		},
	},
	{
		tag = "514:177",
		nodeID = 79,
		name = "Marshal's Stand, Un'Goro Crater",
		neighbors = {
			[39] = 91, -- Gadgetzan, Tanaris
			[386] = 38, -- Mossy Pile, Un'Goro Crater
			[72] = 126, -- Cenarion Hold, Silithus
			[39] = 93, -- Gadgetzan, Tanaris
			[72] = 121, -- Cenarion Hold, Silithus
		},
	},
	{
		tag = "408:544",
		nodeID = 541,
		name = "Mirkfallon Post, Stonetalon Mountains",
		neighbors = {
			[33] = 39, -- Thal'darah Overlook, Stonetalon Mountains
			[361] = 28, -- Windshear Hold, Stonetalon Mountains
			[365] = 53, -- Farwatcher's Glen, Stonetalon Mountains
		},
	},
	{
		tag = "552:794",
		nodeID = 49,
		name = "Moonglade",
		faction = "A",
		neighbors = {
			[26] = 86, -- Lor'danel, Darkshore
			[52] = 119, -- Everlook, Winterspring
			[65] = 61, -- Talonbranch Glade, Felwood
			[559] = 140, -- Nordrassil, Hyjal
		},
	},
	{
		tag = "537:794",
		nodeID = 49,
		name = "Moonglade",
		faction = "H",
		neighbors = {
			[559] = 135, -- Nordrassil, Hyjal
			[597] = 73, -- Irontree Clearing, Felwood
			[52] = 141, -- Everlook, Winterspring
		},
	},
	{
		tag = "495:201",
		nodeID = 386,
		name = "Mossy Pile, Un'Goro Crater",
		neighbors = {
			[39] = 97, -- Gadgetzan, Tanaris
			[72] = 84, -- Cenarion Hold, Silithus
			[39] = 98, -- Gadgetzan, Tanaris
			[72] = 83, -- Cenarion Hold, Silithus
			[79] = 29, -- Marshal's Stand, Un'Goro Crater
		},
	},
	{
		tag = "583:300",
		nodeID = 179,
		name = "Mudsprocket, Dustwallow Marsh",
		neighbors = {
			[30] = 100, -- Westreach Summit, Thousand Needles
			[31] = 144, -- Shadebough, Feralas
			[32] = 53, -- Theramore, Dustwallow Marsh
			[55] = 63, -- Brackenwall Village, Dustwallow Marsh
			[389] = 66, -- Fort Triumph, Southern Barrens
			[391] = 88, -- Desolation Hold, Southern Barrens
			[513] = 60, -- Fizzle & Pozzik's Speedbarge, Thousand Needles
			[513] = 60, -- Fizzle & Pozzik's Speedbarge, Thousand Needles
		},
	},
	{
		tag = "549:807",
		nodeID = 62,
		name = "Nighthaven",
		faction = "H",
		neighbors = {
			[22] = 400, -- Thunder Bluff, Mulgore
		},
	},
	{
		tag = "549:808",
		nodeID = 62,
		name = "Nighthaven",
		faction = "A",
		neighbors = {
			[27] = 151, -- Rut'theran Village, Teldrassil
		},
	},
	{
		tag = "396:493",
		nodeID = 37,
		name = "Nijel's Point, Desolace",
		neighbors = {
			[26] = 337, -- Lor'danel, Darkshore
			[32] = 308, -- Theramore, Dustwallow Marsh
			[33] = 101, -- Thal'darah Overlook, Stonetalon Mountains
			[41] = 232, -- Feathermoon, Feralas
			[351] = 105, -- Stardust Spire, Ashenvale
			[361] = 73, -- Windshear Hold, Stonetalon Mountains
			[364] = 81, -- Northwatch Expedition Base Camp, Stonetalon Mountains
			[365] = 52, -- Farwatcher's Glen, Stonetalon Mountains
			[367] = 81, -- Thargad's Camp, Desolace
			[368] = 50, -- Karnum's Glade, Desolace
			[369] = 31, -- Thunk's Abode, Desolace
			[370] = 49, -- Ethel Rethor, Desolace
		},
	},
	{
		tag = "597:717",
		nodeID = 559,
		name = "Nordrassil, Hyjal",
		neighbors = {
			[49] = 116, -- Moonglade
			[52] = 128, -- Everlook, Winterspring
			[49] = 132, -- Moonglade
			[557] = 47, -- Shrine of Aviana, Hyjal
			[558] = 77, -- Grove of Aessina, Hyjal
			[52] = 123, -- Everlook, Winterspring
		},
	},
	{
		tag = "740:677",
		nodeID = 614,
		name = "Northern Rocketway, Azshara",
		neighbors = {
			[44] = 50, -- Bilgewater Harbor, Azshara
		},
	},
	{
		tag = "462:497",
		nodeID = 364,
		name = "Northwatch Expedition Base Camp, Stonetalon Mountains",
		neighbors = {
			[33] = 114, -- Thal'darah Overlook, Stonetalon Mountains
			[37] = 67, -- Nijel's Point, Desolace
			[351] = 83, -- Stardust Spire, Ashenvale
			[361] = 61, -- Windshear Hold, Stonetalon Mountains
			[365] = 121, -- Farwatcher's Glen, Stonetalon Mountains
			[387] = 51, -- Honor's Stand, Southern Barrens
		},
	},
	{
		tag = "597:400",
		nodeID = 388,
		name = "Northwatch Hold, Southern Barrens",
		neighbors = {
			[32] = 73, -- Theramore, Dustwallow Marsh
			[80] = 46, -- Ratchet, The Barrens
			[387] = 104, -- Honor's Stand, Southern Barrens
			[389] = 78, -- Fort Triumph, Southern Barrens
		},
	},
	{
		tag = "589:535",
		nodeID = 458,
		name = "Nozzlepot's Outpost, The Barrens",
		neighbors = {
			[25] = 65, -- The Crossroads, The Barrens
			[354] = 58, -- The Mor'Shan Ramparts, Ashenvale
		},
	},
	{
		tag = "418:143",
		nodeID = 653,
		name = "Oasis of Vir'sar, Uldum",
		neighbors = {
			[72] = 108, -- Cenarion Hold, Silithus
			[72] = 102, -- Cenarion Hold, Silithus
			[652] = 122, -- Ramkahen, Uldum
			[674] = 128, -- Schnottz's Landing, Uldum
		},
	},
	{
		tag = "629:561",
		nodeID = 23,
		name = "Orgrimmar, Durotar",
		neighbors = {
			[22] = 225, -- Thunder Bluff, Mulgore
			[25] = 108, -- The Crossroads, The Barrens
			[44] = 114, -- Bilgewater Harbor, Azshara
			[55] = 228, -- Brackenwall Village, Dustwallow Marsh
			[39] = 417, -- Gadgetzan, Tanaris
			[61] = 93, -- Splintertree Post, Ashenvale
			[52] = 240, -- Everlook, Winterspring
			[80] = 108, -- Ratchet, The Barrens
			[354] = 99, -- The Mor'Shan Ramparts, Ashenvale
			[537] = 55, -- Razor Hill, Durotar
			[613] = 93, -- Southern Rocketway, Azshara
			[616] = 117, -- Gates of Sothann, Hyjal
			[683] = 82, -- Valormok, Azshara
		},
	},
	{
		tag = "493:100",
		nodeID = 652,
		name = "Ramkahen, Uldum",
		neighbors = {
			[531] = 68, -- Dawnrise Expedition, Tanaris
			[532] = 80, -- Gunstan's Dig, Tanaris
			[653] = 83, -- Oasis of Vir'sar, Uldum
			[674] = 94, -- Schnottz's Landing, Uldum
		},
	},
	{
		tag = "605:450",
		nodeID = 80,
		name = "Ratchet, The Barrens",
		neighbors = {
			[23] = 104, -- Orgrimmar, Durotar
			[25] = 68, -- The Crossroads, The Barrens
			[28] = 197, -- Astranaar, Ashenvale
			[32] = 105, -- Theramore, Dustwallow Marsh
			[39] = 245, -- Gadgetzan, Tanaris
			[55] = 101, -- Brackenwall Village, Dustwallow Marsh
			[387] = 90, -- Honor's Stand, Southern Barrens
			[388] = 55, -- Northwatch Hold, Southern Barrens
			[39] = 241, -- Gadgetzan, Tanaris
		},
	},
	{
		tag = "646:498",
		nodeID = 537,
		name = "Razor Hill, Durotar",
		neighbors = {
			[23] = 60, -- Orgrimmar, Durotar
			[536] = 36, -- Sen'jin Village, Durotar
		},
	},
	{
		tag = "410:832",
		nodeID = 27,
		name = "Rut'theran Village, Teldrassil",
		neighbors = {
			[26] = 61, -- Lor'danel, Darkshore
			[94] = 100, -- The Exodar
			[457] = 111, -- Darnassus, Teldrassil
		},
	},
	{
		tag = "537:668",
		nodeID = 781,
		name = "Sanctuary of Malorne, Hyjal",
		neighbors = {
			[557] = 31, -- Shrine of Aviana, Hyjal
		},
	},
	{
		tag = "407:047",
		nodeID = 674,
		name = "Schnottz's Landing, Uldum",
		neighbors = {
			[652] = 89, -- Ramkahen, Uldum
			[653] = 88, -- Oasis of Vir'sar, Uldum
		},
	},
	{
		tag = "651:455",
		nodeID = 536,
		name = "Sen'jin Village, Durotar",
		neighbors = {
			[537] = 36, -- Razor Hill, Durotar
		},
	},
	{
		tag = "447:282",
		nodeID = 31,
		name = "Shadebough, Feralas",
		neighbors = {
			[32] = 207, -- Theramore, Dustwallow Marsh
			[39] = 215, -- Gadgetzan, Tanaris
			[41] = 84, -- Feathermoon, Feralas
			[179] = 134, -- Mudsprocket, Dustwallow Marsh
			[513] = 177, -- Fizzle & Pozzik's Speedbarge, Thousand Needles
			[567] = 60, -- Tower of Estulan, Feralas
		},
	},
	{
		tag = "316:415",
		nodeID = 38,
		name = "Shadowprey Village, Desolace",
		neighbors = {
			[22] = 178, -- Thunder Bluff, Mulgore
			[29] = 199, -- Sun Rock Retreat, Stonetalon Mountains
			[42] = 196, -- Camp Mojache, Feralas
			[363] = 172, -- Malaka'jin, Stonetalon Mountains
			[366] = 77, -- Furien's Post, Desolace
			[368] = 83, -- Karnum's Glade, Desolace
			[370] = 91, -- Ethel Rethor, Desolace
			[568] = 71, -- Camp Ataya, Feralas
		},
	},
	{
		tag = "560:692",
		nodeID = 557,
		name = "Shrine of Aviana, Hyjal",
		neighbors = {
			[558] = 37, -- Grove of Aessina, Hyjal
			[559] = 46, -- Nordrassil, Hyjal
			[616] = 61, -- Gates of Sothann, Hyjal
			[781] = 65, -- Sanctuary of Malorne, Hyjal
		},
	},
	{
		tag = "497:576",
		nodeID = 356,
		name = "Silverwind Refuge, Ashenvale",
		neighbors = {
			[61] = 64, -- Splintertree Post, Ashenvale
			[350] = 43, -- Hellscream's Watch, Ashenvale
			[354] = 70, -- The Mor'Shan Ramparts, Ashenvale
			[362] = 77, -- Krom'gar Fortress, Stonetalon Mountains
		},
	},
	{
		tag = "706:596",
		nodeID = 613,
		name = "Southern Rocketway, Azshara",
		neighbors = {
			[23] = 88, -- Orgrimmar, Durotar
			[44] = 39, -- Bilgewater Harbor, Azshara
		},
	},
	{
		tag = "554:582",
		nodeID = 61,
		name = "Splintertree Post, Ashenvale",
		neighbors = {
			[23] = 96, -- Orgrimmar, Durotar
			[25] = 160, -- The Crossroads, The Barrens
			[44] = 158, -- Bilgewater Harbor, Azshara
			[58] = 167, -- Zoram'gar Outpost, Ashenvale
			[166] = 85, -- Emerald Sanctuary, Felwood
			[350] = 82, -- Hellscream's Watch, Ashenvale
			[354] = 54, -- The Mor'Shan Ramparts, Ashenvale
			[356] = 58, -- Silverwind Refuge, Ashenvale
			[683] = 71, -- Valormok, Azshara
		},
	},
	{
		tag = "463:565",
		nodeID = 351,
		name = "Stardust Spire, Ashenvale",
		neighbors = {
			[28] = 39, -- Astranaar, Ashenvale
			[33] = 95, -- Thal'darah Overlook, Stonetalon Mountains
			[37] = 94, -- Nijel's Point, Desolace
			[361] = 64, -- Windshear Hold, Stonetalon Mountains
			[364] = 65, -- Northwatch Expedition Base Camp, Stonetalon Mountains
			[387] = 103, -- Honor's Stand, Southern Barrens
		},
	},
	{
		tag = "372:298",
		nodeID = 569,
		name = "Stonemaul Hold, Feralas",
		neighbors = {
			[72] = 106, -- Cenarion Hold, Silithus
			[42] = 70, -- Camp Mojache, Feralas
			[568] = 66, -- Camp Ataya, Feralas
		},
	},
	{
		tag = "407:527",
		nodeID = 29,
		name = "Sun Rock Retreat, Stonetalon Mountains",
		neighbors = {
			[22] = 175, -- Thunder Bluff, Mulgore
			[25] = 150, -- The Crossroads, The Barrens
			[38] = 143, -- Shadowprey Village, Desolace
			[58] = 121, -- Zoram'gar Outpost, Ashenvale
			[350] = 110, -- Hellscream's Watch, Ashenvale
			[360] = 49, -- Cliffwalker Post, Stonetalon Mountains
			[362] = 43, -- Krom'gar Fortress, Stonetalon Mountains
			[363] = 67, -- Malaka'jin, Stonetalon Mountains
			[366] = 102, -- Furien's Post, Desolace
			[368] = 108, -- Karnum's Glade, Desolace
			[540] = 42, -- The Sludgewerks, Stonetalon Mountains
		},
	},
	{
		tag = "527:742",
		nodeID = 65,
		name = "Talonbranch Glade, Felwood",
		neighbors = {
			[26] = 115, -- Lor'danel, Darkshore
			[49] = 67, -- Moonglade
			[52] = 107, -- Everlook, Winterspring
			[166] = 129, -- Emerald Sanctuary, Felwood
			[339] = 121, -- Grove of the Ancients, Darkshore
			[594] = 51, -- Whisperwind Grove, Felwood
		},
	},
	{
		tag = "387:575",
		nodeID = 33,
		name = "Thal'darah Overlook, Stonetalon Mountains",
		neighbors = {
			[26] = 253, -- Lor'danel, Darkshore
			[28] = 171, -- Astranaar, Ashenvale
			[37] = 109, -- Nijel's Point, Desolace
			[338] = 127, -- Blackfathom Camp, Ashenvale
			[339] = 168, -- Grove of the Ancients, Darkshore
			[351] = 87, -- Stardust Spire, Ashenvale
			[361] = 83, -- Windshear Hold, Stonetalon Mountains
			[364] = 101, -- Northwatch Expedition Base Camp, Stonetalon Mountains
			[365] = 63, -- Farwatcher's Glen, Stonetalon Mountains
			[367] = 143, -- Thargad's Camp, Desolace
			[368] = 121, -- Karnum's Glade, Desolace
			[541] = 41, -- Mirkfallon Post, Stonetalon Mountains
		},
	},
	{
		tag = "344:418",
		nodeID = 367,
		name = "Thargad's Camp, Desolace",
		neighbors = {
			[33] = 158, -- Thal'darah Overlook, Stonetalon Mountains
			[37] = 102, -- Nijel's Point, Desolace
			[41] = 126, -- Feathermoon, Feralas
			[368] = 56, -- Karnum's Glade, Desolace
			[370] = 63, -- Ethel Rethor, Desolace
			[565] = 54, -- Dreamer's Rest, Feralas
		},
	},
	{
		tag = "557:469",
		nodeID = 25,
		name = "The Crossroads, The Barrens",
		neighbors = {
			[22] = 107, -- Thunder Bluff, Mulgore
			[23] = 117, -- Orgrimmar, Durotar
			[29] = 151, -- Sun Rock Retreat, Stonetalon Mountains
			[30] = 188, -- Westreach Summit, Thousand Needles
			[42] = 252, -- Camp Mojache, Feralas
			[44] = 228, -- Bilgewater Harbor, Azshara
			[354] = 63, -- The Mor'Shan Ramparts, Ashenvale
			[363] = 115, -- Malaka'jin, Stonetalon Mountains
			[390] = 49, -- Hunter's Hill, Southern Barrens
			[458] = 67, -- Nozzlepot's Outpost, The Barrens
			[77] = 70, -- Vendetta Point, Southern Barrens
			[55] = 163, -- Brackenwall Village, Dustwallow Marsh
			[58] = 231, -- Zoram'gar Outpost, Ashenvale
			[39] = 303, -- Gadgetzan, Tanaris
			[61] = 162, -- Splintertree Post, Ashenvale
			[80] = 52, -- Ratchet, The Barrens
		},
	},
	{
		tag = "205:745",
		nodeID = 94,
		name = "The Exodar",
		neighbors = {
			[27] = 101, -- Rut'theran Village, Teldrassil
			[93] = 89, -- Blood Watch, Bloodmyst Isle
			[624] = 40, -- Azure Watch, Azuremyst Isle
		},
	},
	{
		tag = "541:537",
		nodeID = 354,
		name = "The Mor'Shan Ramparts, Ashenvale",
		neighbors = {
			[23] = 102, -- Orgrimmar, Durotar
			[25] = 65, -- The Crossroads, The Barrens
			[61] = 46, -- Splintertree Post, Ashenvale
			[350] = 93, -- Hellscream's Watch, Ashenvale
			[356] = 70, -- Silverwind Refuge, Ashenvale
			[362] = 143, -- Krom'gar Fortress, Stonetalon Mountains
			[458] = 58, -- Nozzlepot's Outpost, The Barrens
		},
	},
	{
		tag = "420:562",
		nodeID = 540,
		name = "The Sludgewerks, Stonetalon Mountains",
		neighbors = {
			[29] = 37, -- Sun Rock Retreat, Stonetalon Mountains
			[360] = 31, -- Cliffwalker Post, Stonetalon Mountains
			[362] = 44, -- Krom'gar Fortress, Stonetalon Mountains
		},
	},
	{
		tag = "636:330",
		nodeID = 32,
		name = "Theramore, Dustwallow Marsh",
		neighbors = {
			[26] = 500, -- Lor'danel, Darkshore
			[28] = 369, -- Astranaar, Ashenvale
			[31] = 201, -- Shadebough, Feralas
			[37] = 334, -- Nijel's Point, Desolace
			[39] = 157, -- Gadgetzan, Tanaris
			[80] = 116, -- Ratchet, The Barrens
			[179] = 63, -- Mudsprocket, Dustwallow Marsh
			[388] = 81, -- Northwatch Hold, Southern Barrens
		},
	},
	{
		tag = "449:438",
		nodeID = 22,
		name = "Thunder Bluff, Mulgore",
		neighbors = {
			[23] = 208, -- Orgrimmar, Durotar
			[25] = 103, -- The Crossroads, The Barrens
			[29] = 181, -- Sun Rock Retreat, Stonetalon Mountains
			[30] = 210, -- Westreach Summit, Thousand Needles
			[38] = 159, -- Shadowprey Village, Desolace
			[42] = 252, -- Camp Mojache, Feralas
			[44] = 316, -- Bilgewater Harbor, Azshara
			[363] = 54, -- Malaka'jin, Stonetalon Mountains
			[369] = 66, -- Thunk's Abode, Desolace
			[390] = 66, -- Hunter's Hill, Southern Barrens
			[402] = 51, -- Bloodhoof Village, Mulgore
			[77] = 85, -- Vendetta Point, Southern Barrens
			[55] = 238, -- Brackenwall Village, Dustwallow Marsh
			[58] = 264, -- Zoram'gar Outpost, Ashenvale
			[39] = 290, -- Gadgetzan, Tanaris
		},
	},
	{
		tag = "407:465",
		nodeID = 369,
		name = "Thunk's Abode, Desolace",
		neighbors = {
			[22] = 46, -- Thunder Bluff, Mulgore
			[37] = 33, -- Nijel's Point, Desolace
			[368] = 56, -- Karnum's Glade, Desolace
			[370] = 63, -- Ethel Rethor, Desolace
		},
	},
	{
		tag = "389:287",
		nodeID = 567,
		name = "Tower of Estulan, Feralas",
		neighbors = {
			[31] = 61, -- Shadebough, Feralas
			[41] = 34, -- Feathermoon, Feralas
		},
	},
	{
		tag = "621:610",
		nodeID = 683,
		name = "Valormok, Azshara",
		neighbors = {
			[23] = 76, -- Orgrimmar, Durotar
			[44] = 86, -- Bilgewater Harbor, Azshara
			[61] = 80, -- Splintertree Post, Ashenvale
			[616] = 72, -- Gates of Sothann, Hyjal
		},
	},
	{
		tag = "521:399",
		nodeID = 77,
		name = "Vendetta Point, Southern Barrens",
		neighbors = {
			[22] = 117, -- Thunder Bluff, Mulgore
			[25] = 77, -- The Crossroads, The Barrens
			[30] = 128, -- Westreach Summit, Thousand Needles
			[55] = 62, -- Brackenwall Village, Dustwallow Marsh
			[390] = 56, -- Hunter's Hill, Southern Barrens
			[391] = 45, -- Desolation Hold, Southern Barrens
		},
	},
	{
		tag = "488:310",
		nodeID = 30,
		name = "Westreach Summit, Thousand Needles",
		neighbors = {
			[22] = 215, -- Thunder Bluff, Mulgore
			[25] = 186, -- The Crossroads, The Barrens
			[42] = 50, -- Camp Mojache, Feralas
			[55] = 97, -- Brackenwall Village, Dustwallow Marsh
			[179] = 83, -- Mudsprocket, Dustwallow Marsh
			[391] = 100, -- Desolation Hold, Southern Barrens
			[77] = 122, -- Vendetta Point, Southern Barrens
			[39] = 153, -- Gadgetzan, Tanaris
			[513] = 118, -- Fizzle & Pozzik's Speedbarge, Thousand Needles
		},
	},
	{
		tag = "485:737",
		nodeID = 594,
		name = "Whisperwind Grove, Felwood",
		neighbors = {
			[65] = 59, -- Talonbranch Glade, Felwood
			[166] = 90, -- Emerald Sanctuary, Felwood
			[595] = 60, -- Wildheart Point, Felwood
			[597] = 41, -- Irontree Clearing, Felwood
		},
	},
	{
		tag = "487:682",
		nodeID = 595,
		name = "Wildheart Point, Felwood",
		neighbors = {
			[166] = 35, -- Emerald Sanctuary, Felwood
			[339] = 52, -- Grove of the Ancients, Darkshore
			[594] = 68, -- Whisperwind Grove, Felwood
		},
	},
	{
		tag = "432:539",
		nodeID = 361,
		name = "Windshear Hold, Stonetalon Mountains",
		neighbors = {
			[33] = 65, -- Thal'darah Overlook, Stonetalon Mountains
			[37] = 62, -- Nijel's Point, Desolace
			[351] = 57, -- Stardust Spire, Ashenvale
			[364] = 58, -- Northwatch Expedition Base Camp, Stonetalon Mountains
			[365] = 92, -- Farwatcher's Glen, Stonetalon Mountains
			[541] = 31, -- Mirkfallon Post, Stonetalon Mountains
		},
	},
	{
		tag = "407:625",
		nodeID = 58,
		name = "Zoram'gar Outpost, Ashenvale",
		neighbors = {
			[22] = 247, -- Thunder Bluff, Mulgore
			[25] = 235, -- The Crossroads, The Barrens
			[29] = 121, -- Sun Rock Retreat, Stonetalon Mountains
			[61] = 172, -- Splintertree Post, Ashenvale
			[166] = 122, -- Emerald Sanctuary, Felwood
			[350] = 82, -- Hellscream's Watch, Ashenvale
			[360] = 73, -- Cliffwalker Post, Stonetalon Mountains
		},
	},
}



















----------------------------------------------------------
-----  EASTERN KINGDOMS (VANILLA + CATACLYSM)  -----
----------------------------------------------------------
data.flightcost[13]={
	{
		tag = "390:623",
		name = " Forsaken High Command, Silverpine Forest",
		neighbors = {
			[10] = 40, -- The Sepulcher, Silverpine Forest
			[11] = 75, -- Undercity, Tirisfal
			[460] = 50, -- Brill, Tirisfal Glades
			[681] = 28, -- Forsaken Rear Guard, Silverpine Forest
		},
	},
	{
		tag = "622:655",
		nodeID = 315,
		name = "Acherus: The Ebon Hold",
		neighbors = {
			[67] = 10, -- Light's Hope Chapel, Eastern Plaguelands
		},
	},
	{
		tag = "495:583",
		nodeID = 43,
		name = "Aerie Peak, The Hinterlands",
		neighbors = {
			[6] = 256, -- Ironforge, Dun Morogh
			[16] = 75, -- Refuge Pointe, Arathi
			[66] = 57, -- Chillwind Camp, Western Plaguelands
			[67] = 164, -- Light's Hope Chapel, Eastern Plaguelands
			[618] = 80, -- Stormfeather Outpost, The Hinterlands
			[649] = 70, -- Andorhal, Western Plaguelands
		},
	},
	{
		tag = "470:621",
		nodeID = 649,
		name = "Andorhal, Western Plaguelands",
		faction = "A",
		neighbors = {
			[43] = 80, -- Aerie Peak, The Hinterlands
			[66] = 19, -- Chillwind Camp, Western Plaguelands
			[651] = 25, -- The Menders' Stead, Western Plaguelands
		},
	},
	{
		tag = "481:626",
		nodeID = 649,
		name = "Andorhal, Western Plaguelands",
		faction = "H",
		neighbors = {
			[384] = 37, -- The Bulwark, Tirisfal
			[617] = 90, -- Hiri'watha Research Station, The Hinterlands
			[651] = 16, -- The Menders' Stead, Western Plaguelands
		},
	},
	{
		tag = "454:154",
		nodeID = 593,
		name = "Bambala, Stranglethorn",
		neighbors = {
			[20] = 48, -- Grom'gol, Stranglethorn
			[592] = 70, -- Hardwrench Hideaway, Stranglethorn
		},
	},
	{
		tag = "609:447",
		nodeID = 659,
		name = "Bloodgulch, Twilight Highlands",
		neighbors = {
			[656] = 59, -- Crushblow, Twilight Highlands
			[657] = 50, -- The Gullet, Twilight Highlands
			[660] = 50, -- The Krazzworks, Twilight Highlands
			[661] = 57, -- Dragonmaw Port, Twilight Highlands
		},
	},
	{
		tag = "548:334",
		nodeID = 632,
		name = "Bloodwatcher Point, Badlands",
		neighbors = {
			[21] = 39, -- New Kargath, Badlands
			[635] = 25, -- Fuselight, Badlands
		},
	},
	{
		tag = "561:235",
		nodeID = 599,
		name = "Bogpaddle, Swamp of Sorrows",
		neighbors = {
			[56] = 42, -- Stonard, Swamp of Sorrows
			[70] = 109, -- Flame Crest, Burning Steppes
			[71] = 81, -- Morgan's Vigil, Burning Steppes
			[596] = 33, -- Shalewind Canyon, Redridge
			[598] = 25, -- Marshtide Watch, Swamp of Sorrows
		},
	},
	{
		tag = "408:072",
		nodeID = 18,
		name = "Booty Bay, Stranglethorn",
		faction = "H",
		neighbors = {
			[20] = 76, -- Grom'gol, Stranglethorn
			[21] = 309, -- New Kargath, Badlands
			[56] = 238, -- Stonard, Swamp of Sorrows
			[592] = 41, -- Hardwrench Hideaway, Stranglethorn
			[603] = 170, -- Sunveil Excursion, Blasted Lands
		},
	},
	{
		tag = "409:071",
		nodeID = 18,
		name = "Booty Bay, Stranglethorn",
		faction = "A",
		neighbors = {
			[2] = 199, -- Stormwind, Elwynn
			[4] = 148, -- Sentinel Hill, Westfall
			[12] = 166, -- Darkshire, Duskwood
			[195] = 118, -- Rebel Camp, Stranglethorn Vale
			[591] = 50, -- Explorers' League Digsite, Stranglethorn
			[602] = 144, -- Surwich, Blasted Lands
		},
	},
	{
		tag = "413:652",
		nodeID = 460,
		name = "Brill, Tirisfal Glades",
		neighbors = {
			[11] = 59, -- Undercity, Tirisfal
			[384] = 45, -- The Bulwark, Tirisfal
			["390:623"] = 45, -- ?
		},
	},
	{
		tag = "524:245",
		nodeID = 615,
		name = "Camp Everstill, Redridge",
		neighbors = {
			[5] = 24, -- Lakeshire, Redridge
			[596] = 33, -- Shalewind Canyon, Redridge
		},
	},
	{
		tag = "475:606",
		nodeID = 66,
		name = "Chillwind Camp, Western Plaguelands",
		neighbors = {
			[6] = 260, -- Ironforge, Dun Morogh
			[43] = 65, -- Aerie Peak, The Hinterlands
			[67] = 146, -- Light's Hope Chapel, Eastern Plaguelands
			[383] = 59, -- Thondroril River, Eastern Plaguelands
			[649] = 18, -- Andorhal, Western Plaguelands
			[651] = 42, -- The Menders' Stead, Western Plaguelands
		},
	},
	{
		tag = "492:300",
		nodeID = 676,
		name = "Chiselgrip, Burning Steppes",
		neighbors = {
			[70] = 17, -- Flame Crest, Burning Steppes
			[71] = 39, -- Morgan's Vigil, Burning Steppes
			[675] = 35, -- Flamestar Post, Burning Steppes
		},
	},
	{
		tag = "554:639",
		nodeID = 87,
		name = "Crown Guard Tower, Eastern Plaguelands",
		neighbors = {
			[84] = 53, -- Plaguewood Tower, Eastern Plaguelands
			[85] = 62, -- Northpass Tower, Eastern Plaguelands
			[383] = 39, -- Thondroril River, Eastern Plaguelands
			[630] = 35, -- Light's Shield Tower, Eastern Plaguelands
		},
	},
	{
		tag = "594:406",
		nodeID = 656,
		name = "Crushblow, Twilight Highlands",
		neighbors = {
			[657] = 54, -- The Gullet, Twilight Highlands
			[659] = 48, -- Bloodgulch, Twilight Highlands
			[661] = 80, -- Dragonmaw Port, Twilight Highlands
		},
	},
	{
		tag = "219:334",
		nodeID = 524,
		name = "Darkbreak Cove, Vashj'ir",
		taxioperator = "seahorse",
		neighbors = {
			[523] = 63, -- Tranquil Wash, Vashj'ir
			[611] = 80, -- Voldrin's Hold, Vashj'ir
		},
	},
	{
		tag = "469:208",
		nodeID = 12,
		name = "Darkshire, Duskwood",
		neighbors = {
			[2] = 88, -- Stormwind, Elwynn
			[4] = 93, -- Sentinel Hill, Westfall
			[5] = 60, -- Lakeshire, Redridge
			[18] = 171, -- Booty Bay, Stranglethorn
			[45] = 97, -- Nethergarde Keep, Blasted Lands
			[195] = 47, -- Rebel Camp, Stranglethorn Vale
			[582] = 68, -- Goldshire, Elwynn
			[622] = 63, -- Raven Hill, Duskwood
		},
	},
	{
		tag = "515:329",
		nodeID = 634,
		name = "Dragon's Mouth, Badlands",
		neighbors = {
			[71] = 55, -- Morgan's Vigil, Burning Steppes
			[633] = 35, -- Dustwind Dig, Badlands
			[635] = 54, -- Fuselight, Badlands
		},
	},
	{
		tag = "645:434",
		nodeID = 661,
		name = "Dragonmaw Port, Twilight Highlands",
		neighbors = {
			[17] = 237, -- Hammerfall, Arathi
			[21] = 217, -- New Kargath, Badlands
			[656] = 66, -- Crushblow, Twilight Highlands
			[659] = 44, -- Bloodgulch, Twilight Highlands
			[660] = 53, -- The Krazzworks, Twilight Highlands
		},
	},
	{
		tag = "522:194",
		nodeID = 604,
		name = "Dreadmaul Hold, Blasted Lands",
		neighbors = {
			[56] = 44, -- Stonard, Swamp of Sorrows
			[603] = 56, -- Sunveil Excursion, Blasted Lands
		},
	},
	{
		tag = "511:481",
		nodeID = 553,
		name = "Dun Modr, Wetlands",
		neighbors = {
			[16] = 52, -- Refuge Pointe, Arathi
			[551] = 33, -- Whelgar's Retreat, Wetlands
			[552] = 36, -- Greenwarden's Grove, Wetlands
		},
	},
	{
		tag = "544:344",
		nodeID = 633,
		name = "Dustwind Dig, Badlands",
		neighbors = {
			[8] = 53, -- Thelsamar, Loch Modan
			[634] = 37, -- Dragon's Mouth, Badlands
			[635] = 29, -- Fuselight, Badlands
		},
	},
	{
		tag = "462:554",
		nodeID = 669,
		name = "Eastpoint Tower, Hillsbrad",
		neighbors = {
			[13] = 22, -- Tarren Mill, Hillsbrad
			[601] = 32, -- Galen's Fall, Arathi
			[667] = 25, -- Ruins of Southshore, Hillsbrad
		},
	},
	{
		tag = "471:244",
		nodeID = 589,
		name = "Eastvale Logging Camp, Elwynn",
		neighbors = {
			[5] = 41, -- Lakeshire, Redridge
			[582] = 53, -- Goldshire, Elwynn
		},
	},
	{
		tag = "591:661",
		nodeID = 86,
		name = "Eastwall Tower, Eastern Plaguelands",
		neighbors = {
			[67] = 30, -- Light's Hope Chapel, Eastern Plaguelands
			[84] = 66, -- Plaguewood Tower, Eastern Plaguelands
			[85] = 31, -- Northpass Tower, Eastern Plaguelands
			[630] = 18, -- Light's Shield Tower, Eastern Plaguelands
		},
	},
	{
		tag = "429:101",
		nodeID = 591,
		name = "Explorers' League Digsite, Stranglethorn",
		neighbors = {
			[18] = 53, -- Booty Bay, Stranglethorn
			[590] = 46, -- Fort Livingston, Stranglethorn
		},
	},
	{
		tag = "573:794",
		nodeID = 625,
		name = "Fairbreeze Village, Eversong Woods",
		neighbors = {
			[82] = 29, -- Silvermoon City
			[83] = 46, -- Tranquillien, Ghostlands
		},
	},
	{
		tag = "577:820",
		nodeID = 631,
		name = "Falconwing Square, Eversong Woods",
		neighbors = {
			[82] = 19, -- Silvermoon City
		},
	},
	{
		tag = "573:377",
		nodeID = 555,
		name = "Farstrider Lodge, Loch Modan",
		neighbors = {
			[8] = 46, -- Thelsamar, Loch Modan
			[635] = 47, -- Fuselight, Badlands
		},
	},
	{
		tag = "621:428",
		nodeID = 664,
		name = "Firebeard's Patrol, Twilight Highlands",
		neighbors = {
			[662] = 53, -- Highbank, Twilight Highlands
			[663] = 42, -- Victor's Point, Twilight Highlands
			[665] = 57, -- Thundermar, Twilight Highlands
			[666] = 73, -- Kirthaven, Twilight Highlands
		},
	},
	{
		tag = "501:313",
		nodeID = 70,
		name = "Flame Crest, Burning Steppes",
		neighbors = {
			[20] = 206, -- Grom'gol, Stranglethorn
			[21] = 82, -- New Kargath, Badlands
			[56] = 192, -- Stonard, Swamp of Sorrows
			[74] = 61, -- Thorium Point, Searing Gorge
			[599] = 108, -- Bogpaddle, Swamp of Sorrows
			[676] = 17, -- Chiselgrip, Burning Steppes
		},
	},
	{
		tag = "461:292",
		nodeID = 675,
		name = "Flamestar Post, Burning Steppes",
		neighbors = {
			[673] = 45, -- Iron Summit, Searing Gorge
			[676] = 36, -- Chiselgrip, Burning Steppes
		},
	},
	{
		tag = "373:610",
		nodeID = 681,
		name = "Forsaken Rear Guard, Silverpine Forest",
		neighbors = {
			[10] = 31, -- The Sepulcher, Silverpine Forest
			["390:623"] = 25, -- ?
		},
	},
	{
		tag = "440:128",
		nodeID = 590,
		name = "Fort Livingston, Stranglethorn",
		neighbors = {
			[195] = 55, -- Rebel Camp, Stranglethorn Vale
			[591] = 44, -- Explorers' League Digsite, Stranglethorn
		},
	},
	{
		tag = "381:232",
		nodeID = 584,
		name = "Furlbrow's Pumpkin Farm, Westfall",
		neighbors = {
			[2] = 59, -- Stormwind, Elwynn
			[4] = 28, -- Sentinel Hill, Westfall
		},
	},
	{
		tag = "560:345",
		nodeID = 635,
		name = "Fuselight, Badlands",
		neighbors = {
			[21] = 51, -- New Kargath, Badlands
			[67] = 358, -- Light's Hope Chapel, Eastern Plaguelands
			[555] = 49, -- Farstrider Lodge, Loch Modan
			[632] = 18, -- Bloodwatcher Point, Badlands
			[633] = 19, -- Dustwind Dig, Badlands
			[634] = 51, -- Dragon's Mouth, Badlands
		},
	},
	{
		tag = "481:540",
		nodeID = 601,
		name = "Galen's Fall, Arathi",
		neighbors = {
			[11] = 199, -- Undercity, Tirisfal
			[17] = 74, -- Hammerfall, Arathi
			[669] = 34, -- Eastpoint Tower, Hillsbrad
		},
	},
	{
		tag = "480:375",
		nodeID = 620,
		name = "Gol'Bolar Quarry, Dun Morogh",
		neighbors = {
			[6] = 69, -- Ironforge, Dun Morogh
			[619] = 44, -- Kharanos, Dun Morogh
		},
	},
	{
		tag = "423:246",
		nodeID = 582,
		name = "Goldshire, Elwynn",
		neighbors = {
			[2] = 26, -- Stormwind, Elwynn
			[12] = 68, -- Darkshire, Duskwood
			[589] = 57, -- Eastvale Logging Camp, Elwynn
		},
	},
	{
		tag = "520:459",
		nodeID = 552,
		name = "Greenwarden's Grove, Wetlands",
		neighbors = {
			[551] = 26, -- Whelgar's Retreat, Wetlands
			[553] = 28, -- Dun Modr, Wetlands
			[554] = 33, -- Slabchisel's Survey, Wetlands
			[658] = 68, -- Vermillion Redoubt, Twilight Highlands
		},
	},
	{
		tag = "420:142",
		nodeID = 20,
		name = "Grom'gol, Stranglethorn",
		neighbors = {
			[18] = 78, -- Booty Bay, Stranglethorn
			[21] = 243, -- New Kargath, Badlands
			[56] = 173, -- Stonard, Swamp of Sorrows
			[70] = 198, -- Flame Crest, Burning Steppes
			[592] = 39, -- Hardwrench Hideaway, Stranglethorn
			[593] = 57, -- Bambala, Stranglethorn
		},
	},
	{
		tag = "547:542",
		nodeID = 17,
		name = "Hammerfall, Arathi",
		neighbors = {
			[11] = 259, -- Undercity, Tirisfal
			[13] = 117, -- Tarren Mill, Hillsbrad
			[21] = 249, -- New Kargath, Badlands
			[76] = 88, -- Revantusk Village, The Hinterlands
			[601] = 68, -- Galen's Fall, Arathi
			[617] = 53, -- Hiri'watha Research Station, The Hinterlands
			[658] = 167, -- Vermillion Redoubt, Twilight Highlands
			[661] = 251, -- Dragonmaw Port, Twilight Highlands
		},
	},
	{
		tag = "400:112",
		nodeID = 592,
		name = "Hardwrench Hideaway, Stranglethorn",
		neighbors = {
			[18] = 48, -- Booty Bay, Stranglethorn
			[20] = 39, -- Grom'gol, Stranglethorn
			[593] = 73, -- Bambala, Stranglethorn
		},
	},
	{
		tag = "478:672",
		nodeID = 672,
		name = "Hearthglen, Western Plaguelands",
		neighbors = {
			[84] = 61, -- Plaguewood Tower, Eastern Plaguelands
			[651] = 45, -- The Menders' Stead, Western Plaguelands
		},
	},
	{
		tag = "660:405",
		nodeID = 662,
		name = "Highbank, Twilight Highlands",
		neighbors = {
			[8] = 171, -- Thelsamar, Loch Modan
			[664] = 51, -- Firebeard's Patrol, Twilight Highlands
			[666] = 93, -- Kirthaven, Twilight Highlands
		},
	},
	{
		tag = "524:573",
		nodeID = 617,
		name = "Hiri'watha Research Station, The Hinterlands",
		neighbors = {
			[13] = 81, -- Tarren Mill, Hillsbrad
			[17] = 70, -- Hammerfall, Arathi
			[76] = 85, -- Revantusk Village, The Hinterlands
			[383] = 82, -- Thondroril River, Eastern Plaguelands
			[649] = 74, -- Andorhal, Western Plaguelands
		},
	},
	{
		tag = "468:326",
		nodeID = 673,
		name = "Iron Summit, Searing Gorge",
		neighbors = {
			[74] = 25, -- Thorium Point, Searing Gorge
			[675] = 47, -- Flamestar Post, Burning Steppes
		},
	},
	{
		tag = "466:406",
		nodeID = 6,
		name = "Ironforge, Dun Morogh",
		neighbors = {
			[2] = 211, -- Stormwind, Elwynn
			[7] = 115, -- Menethil Harbor, Wetlands
			[8] = 102, -- Thelsamar, Loch Modan
			[16] = 204, -- Refuge Pointe, Arathi
			[43] = 240, -- Aerie Peak, The Hinterlands
			[66] = 257, -- Chillwind Camp, Western Plaguelands
			[67] = 349, -- Light's Hope Chapel, Eastern Plaguelands
			[74] = 85, -- Thorium Point, Searing Gorge
			[213] = 675, -- Shattered Sun Staging Area
			[606] = 187, -- Sandy Beach, Vashj'ir
			[619] = 46, -- Kharanos, Dun Morogh
			[620] = 56, -- Gol'Bolar Quarry, Dun Morogh
			[658] = 228, -- Vermillion Redoubt, Twilight Highlands
		},
	},
	{
		tag = "443:377",
		nodeID = 619,
		name = "Kharanos, Dun Morogh",
		neighbors = {
			[6] = 46, -- Ironforge, Dun Morogh
			[620] = 47, -- Gol'Bolar Quarry, Dun Morogh
		},
	},
	{
		tag = "614:480",
		nodeID = 666,
		name = "Kirthaven, Twilight Highlands",
		neighbors = {
			[662] = 99, -- Highbank, Twilight Highlands
			[664] = 68, -- Firebeard's Patrol, Twilight Highlands
			[665] = 29, -- Thundermar, Twilight Highlands
		},
	},
	{
		tag = "503:246",
		nodeID = 5,
		name = "Lakeshire, Redridge",
		neighbors = {
			[2] = 113, -- Stormwind, Elwynn
			[4] = 134, -- Sentinel Hill, Westfall
			[12] = 61, -- Darkshire, Duskwood
			[71] = 61, -- Morgan's Vigil, Burning Steppes
			[589] = 39, -- Eastvale Logging Camp, Elwynn
			[600] = 47, -- The Harborage, Swamp of Sorrows
			[615] = 21, -- Camp Everstill, Redridge
		},
	},
	{
		tag = "280:337",
		nodeID = 525,
		name = "Legion's Rest, Vashj'ir",
		taxioperator = "seahorse",
		neighbors = {
			[522] = 50, -- Silver Tide Hollow, Vashj'ir
			[526] = 72, -- Tenebrous Cavern, Vashj'ir
			[612] = 28, -- Stygian Bounty, Vashj'ir
		},
	},
	{
		tag = "611:652",
		nodeID = 67,
		name = "Light's Hope Chapel, Eastern Plaguelands",
		faction = "A",
		neighbors = {
			[6] = 369, -- Ironforge, Dun Morogh
			[43] = 162, -- Aerie Peak, The Hinterlands
			[66] = 149, -- Chillwind Camp, Western Plaguelands
			[86] = 24, -- Eastwall Tower, Eastern Plaguelands
			[205] = 223, -- Zul'Aman, Ghostlands
			[315] = 65, -- Acherus: The Ebon Hold
			[383] = 96, -- Thondroril River, Eastern Plaguelands
			[618] = 96, -- Stormfeather Outpost, The Hinterlands
			[630] = 35, -- Light's Shield Tower, Eastern Plaguelands
			[635] = 175, -- Fuselight, Badlands
		},
	},
	{
		tag = "611:653",
		nodeID = 67,
		name = "Light's Hope Chapel, Eastern Plaguelands",
		faction = "H",
		neighbors = {
			[11] = 261, -- Undercity, Tirisfal
			[76] = 144, -- Revantusk Village, The Hinterlands
			[83] = 123, -- Tranquillien, Ghostlands
			[86] = 24, -- Eastwall Tower, Eastern Plaguelands
			[205] = 223, -- Zul'Aman, Ghostlands
			[315] = 65, -- Acherus: The Ebon Hold
			[383] = 96, -- Thondroril River, Eastern Plaguelands
			[630] = 35, -- Light's Shield Tower, Eastern Plaguelands
			[635] = 175, -- Fuselight, Badlands
		},
	},
	{
		tag = "579:652",
		nodeID = 630,
		name = "Light's Shield Tower, Eastern Plaguelands",
		neighbors = {
			[67] = 39, -- Light's Hope Chapel, Eastern Plaguelands
			[84] = 61, -- Plaguewood Tower, Eastern Plaguelands
			[86] = 20, -- Eastwall Tower, Eastern Plaguelands
			[87] = 30, -- Crown Guard Tower, Eastern Plaguelands
		},
	},
	{
		tag = "559:220",
		nodeID = 598,
		name = "Marshtide Watch, Swamp of Sorrows",
		neighbors = {
			[45] = 44, -- Nethergarde Keep, Blasted Lands
			[599] = 30, -- Bogpaddle, Swamp of Sorrows
			[600] = 41, -- The Harborage, Swamp of Sorrows
		},
	},
	{
		tag = "453:442",
		nodeID = 7,
		name = "Menethil Harbor, Wetlands",
		neighbors = {
			[6] = 90, -- Ironforge, Dun Morogh
			[8] = 163, -- Thelsamar, Loch Modan
			[16] = 113, -- Refuge Pointe, Arathi
			[551] = 47, -- Whelgar's Retreat, Wetlands
		},
	},
	{
		tag = "372:196",
		nodeID = 583,
		name = "Moonbrook, Westfall",
		neighbors = {
			[4] = 27, -- Sentinel Hill, Westfall
		},
	},
	{
		tag = "521:283",
		nodeID = 71,
		name = "Morgan's Vigil, Burning Steppes",
		neighbors = {
			[2] = 151, -- Stormwind, Elwynn
			[5] = 63, -- Lakeshire, Redridge
			[45] = 197, -- Nethergarde Keep, Blasted Lands
			[74] = 91, -- Thorium Point, Searing Gorge
			[599] = 77, -- Bogpaddle, Swamp of Sorrows
			[634] = 55, -- Dragon's Mouth, Badlands
			[676] = 43, -- Chiselgrip, Burning Steppes
		},
	},
	{
		tag = "545:188",
		nodeID = 45,
		name = "Nethergarde Keep, Blasted Lands",
		neighbors = {
			[2] = 189, -- Stormwind, Elwynn
			[12] = 92, -- Darkshire, Duskwood
			[71] = 209, -- Morgan's Vigil, Burning Steppes
			[598] = 39, -- Marshtide Watch, Swamp of Sorrows
			[602] = 92, -- Surwich, Blasted Lands
		},
	},
	{
		tag = "510:342",
		nodeID = 21,
		name = "New Kargath, Badlands",
		neighbors = {
			[11] = 470, -- Undercity, Tirisfal
			[17] = 252, -- Hammerfall, Arathi
			[18] = 301, -- Booty Bay, Stranglethorn
			[20] = 243, -- Grom'gol, Stranglethorn
			[56] = 228, -- Stonard, Swamp of Sorrows
			[70] = 73, -- Flame Crest, Burning Steppes
			[74] = 63, -- Thorium Point, Searing Gorge
			[632] = 45, -- Bloodwatcher Point, Badlands
			[635] = 57, -- Fuselight, Badlands
			[658] = 189, -- Vermillion Redoubt, Twilight Highlands
			[661] = 251, -- Dragonmaw Port, Twilight Highlands
		},
	},
	{
		tag = "577:682",
		nodeID = 85,
		name = "Northpass Tower, Eastern Plaguelands",
		neighbors = {
			[84] = 50, -- Plaguewood Tower, Eastern Plaguelands
			[86] = 30, -- Eastwall Tower, Eastern Plaguelands
			[87] = 52, -- Crown Guard Tower, Eastern Plaguelands
		},
	},
	{
		tag = "531:676",
		nodeID = 84,
		name = "Plaguewood Tower, Eastern Plaguelands",
		neighbors = {
			[85] = 57, -- Northpass Tower, Eastern Plaguelands
			[86] = 67, -- Eastwall Tower, Eastern Plaguelands
			[87] = 53, -- Crown Guard Tower, Eastern Plaguelands
			[630] = 61, -- Light's Shield Tower, Eastern Plaguelands
			[672] = 62, -- Hearthglen, Western Plaguelands
		},
	},
	{
		tag = "416:201",
		nodeID = 622,
		name = "Raven Hill, Duskwood",
		neighbors = {
			[4] = 43, -- Sentinel Hill, Westfall
			[12] = 63, -- Darkshire, Duskwood
			[195] = 40, -- Rebel Camp, Stranglethorn Vale
		},
	},
	{
		tag = "433:180",
		nodeID = 195,
		name = "Rebel Camp, Stranglethorn Vale",
		neighbors = {
			[2] = 98, -- Stormwind, Elwynn
			[4] = 66, -- Sentinel Hill, Westfall
			[12] = 48, -- Darkshire, Duskwood
			[18] = 116, -- Booty Bay, Stranglethorn
			[590] = 54, -- Fort Livingston, Stranglethorn
			[622] = 39, -- Raven Hill, Duskwood
		},
	},
	{
		tag = "513:530",
		nodeID = 16,
		name = "Refuge Pointe, Arathi",
		neighbors = {
			[6] = 271, -- Ironforge, Dun Morogh
			[7] = 126, -- Menethil Harbor, Wetlands
			[8] = 170, -- Thelsamar, Loch Modan
			[43] = 72, -- Aerie Peak, The Hinterlands
			[553] = 59, -- Dun Modr, Wetlands
			[618] = 85, -- Stormfeather Outpost, The Hinterlands
			[658] = 146, -- Vermillion Redoubt, Twilight Highlands
		},
	},
	{
		tag = "589:551",
		nodeID = 76,
		name = "Revantusk Village, The Hinterlands",
		neighbors = {
			[11] = 269, -- Undercity, Tirisfal
			[13] = 156, -- Tarren Mill, Hillsbrad
			[17] = 94, -- Hammerfall, Arathi
			[67] = 134, -- Light's Hope Chapel, Eastern Plaguelands
			[617] = 76, -- Hiri'watha Research Station, The Hinterlands
		},
	},
	{
		tag = "444:550",
		nodeID = 667,
		name = "Ruins of Southshore, Hillsbrad",
		neighbors = {
			[13] = 28, -- Tarren Mill, Hillsbrad
			[668] = 45, -- Southpoint Gate, Hillsbrad
			[669] = 19, -- Eastpoint Tower, Hillsbrad
		},
	},
	{
		tag = "297:377",
		nodeID = 609,
		name = "Sandy Beach, Vashj'ir",
		taxioperator = "seahorse",
		faction = "H",
		neighbors = {
			[521] = 40, -- Smuggler's Scar, Vashj'ir
			[522] = 44, -- Silver Tide Hollow, Vashj'ir
		},
	},
	{
		tag = "290:389",
		nodeID = 606,
		name = "Sandy Beach, Vashj'ir",
		faction = "A",
		neighbors = {
			[6] = 189, -- Ironforge, Dun Morogh
			[611] = 68, -- Voldrin's Hold, Vashj'ir
		},
	},
	{
		tag = "296:377",
		nodeID = 608,
		name = "Sandy Beach, Vashj'ir",
		faction = "H",
		neighbors = {
			[11] = 358, -- Undercity, Tirisfal
			[610] = 46, -- Stygian Bounty, Vashj'ir
		},
	},
	{
		tag = "290:391",
		nodeID = 607,
		name = "Sandy Beach, Vashj'ir",
		taxioperator = "seahorse",
		faction = "A",
		neighbors = {
			[521] = 31, -- Smuggler's Scar, Vashj'ir
			[522] = 61, -- Silver Tide Hollow, Vashj'ir
		},
	},
	{
		tag = "390:207",
		nodeID = 4,
		name = "Sentinel Hill, Westfall",
		neighbors = {
			[2] = 86, -- Stormwind, Elwynn
			[5] = 130, -- Lakeshire, Redridge
			[12] = 97, -- Darkshire, Duskwood
			[18] = 186, -- Booty Bay, Stranglethorn
			[195] = 62, -- Rebel Camp, Stranglethorn Vale
			[583] = 25, -- Moonbrook, Westfall
			[584] = 33, -- Furlbrow's Pumpkin Farm, Westfall
			[622] = 31, -- Raven Hill, Duskwood
		},
	},
	{
		tag = "546:239",
		nodeID = 596,
		name = "Shalewind Canyon, Redridge",
		neighbors = {
			[599] = 34, -- Bogpaddle, Swamp of Sorrows
			[615] = 24, -- Camp Everstill, Redridge
		},
	},
	{
		tag = "582:942",
		nodeID = 213,
		name = "Shattered Sun Staging Area",
		neighbors = {
			[82] = 166, -- Silvermoon City
			[205] = 232, -- Zul'Aman, Ghostlands
		},
	},
	{
		tag = "277:361",
		nodeID = 522,
		name = "Silver Tide Hollow, Vashj'ir",
		taxioperator = "seahorse",
		neighbors = {
			[609] = 36, -- Sandy Beach, Vashj'ir
			[521] = 72, -- Smuggler's Scar, Vashj'ir
			[523] = 44, -- Tranquil Wash, Vashj'ir
			[525] = 49, -- Legion's Rest, Vashj'ir
		},
	},
	{
		tag = "591:816",
		nodeID = 82,
		name = "Silvermoon City",
		neighbors = {
			[83] = 65, -- Tranquillien, Ghostlands
			[213] = 185, -- Shattered Sun Staging Area
			[625] = 31, -- Fairbreeze Village, Eversong Woods
			[631] = 24, -- Falconwing Square, Eversong Woods
		},
	},
	{
		tag = "521:431",
		nodeID = 554,
		name = "Slabchisel's Survey, Wetlands",
		neighbors = {
			[8] = 60, -- Thelsamar, Loch Modan
			[552] = 33, -- Greenwarden's Grove, Wetlands
		},
	},
	{
		tag = "305:414",
		nodeID = 521,
		name = "Smuggler's Scar, Vashj'ir",
		taxioperator = "seahorse",
		neighbors = {
			[609] = 43, -- Sandy Beach, Vashj'ir
			[522] = 84, -- Silver Tide Hollow, Vashj'ir
		},
	},
	{
		tag = "410:552",
		nodeID = 668,
		name = "Southpoint Gate, Hillsbrad",
		neighbors = {
			[654] = 39, -- The Forsaken Front, Silverpine Forest
			[667] = 37, -- Ruins of Southshore, Hillsbrad
		},
	},
	{
		tag = "539:210",
		nodeID = 56,
		name = "Stonard, Swamp of Sorrows",
		neighbors = {
			[18] = 230, -- Booty Bay, Stranglethorn
			[20] = 178, -- Grom'gol, Stranglethorn
			[21] = 228, -- New Kargath, Badlands
			[70] = 176, -- Flame Crest, Burning Steppes
			[599] = 45, -- Bogpaddle, Swamp of Sorrows
			[604] = 27, -- Dreadmaul Hold, Blasted Lands
		},
	},
	{
		tag = "568:584",
		nodeID = 618,
		name = "Stormfeather Outpost, The Hinterlands",
		neighbors = {
			[16] = 99, -- Refuge Pointe, Arathi
			[43] = 83, -- Aerie Peak, The Hinterlands
			[67] = 88, -- Light's Hope Chapel, Eastern Plaguelands
			[383] = 120, -- Thondroril River, Eastern Plaguelands
		},
	},
	{
		tag = "409:266",
		nodeID = 2,
		name = "Stormwind, Elwynn",
		neighbors = {
			[4] = 78, -- Sentinel Hill, Westfall
			[5] = 113, -- Lakeshire, Redridge
			[6] = 216, -- Ironforge, Dun Morogh
			[12] = 117, -- Darkshire, Duskwood
			[18] = 199, -- Booty Bay, Stranglethorn
			[45] = 176, -- Nethergarde Keep, Blasted Lands
			[71] = 150, -- Morgan's Vigil, Burning Steppes
			[74] = 133, -- Thorium Point, Searing Gorge
			[195] = 93, -- Rebel Camp, Stranglethorn Vale
			[582] = 32, -- Goldshire, Elwynn
			[584] = 50, -- Furlbrow's Pumpkin Farm, Westfall
		},
	},
	{
		tag = "460:595",
		nodeID = 670,
		name = "Strahnbrad, Alterac Mountains",
		neighbors = {
			[13] = 32, -- Tarren Mill, Hillsbrad
			[384] = 49, -- The Bulwark, Tirisfal
		},
	},
	{
		tag = "277:335",
		nodeID = 612,
		name = "Stygian Bounty, Vashj'ir",
		taxioperator = "seahorse",
		neighbors = {
			[525] = 33, -- Legion's Rest, Vashj'ir
			[526] = 77, -- Tenebrous Cavern, Vashj'ir
		},
	},
	{
		tag = "278:335",
		nodeID = 610,
		name = "Stygian Bounty, Vashj'ir",
		faction = "H",
		neighbors = {
			[608] = 50, -- Sandy Beach, Vashj'ir
		},
	},
	{
		tag = "532:144",
		nodeID = 603,
		name = "Sunveil Excursion, Blasted Lands",
		neighbors = {
			[18] = 172, -- Booty Bay, Stranglethorn
			[604] = 60, -- Dreadmaul Hold, Blasted Lands
		},
	},
	{
		tag = "527:130",
		nodeID = 602,
		name = "Surwich, Blasted Lands",
		neighbors = {
			[18] = 152, -- Booty Bay, Stranglethorn
			[45] = 73, -- Nethergarde Keep, Blasted Lands
		},
	},
	{
		tag = "456:573",
		nodeID = 13,
		name = "Tarren Mill, Hillsbrad",
		neighbors = {
			[10] = 104, -- The Sepulcher, Silverpine Forest
			[11] = 139, -- Undercity, Tirisfal
			[17] = 118, -- Hammerfall, Arathi
			[76] = 162, -- Revantusk Village, The Hinterlands
			[383] = 108, -- Thondroril River, Eastern Plaguelands
			[384] = 69, -- The Bulwark, Tirisfal
			[617] = 104, -- Hiri'watha Research Station, The Hinterlands
			[667] = 30, -- Ruins of Southshore, Hillsbrad
			[669] = 25, -- Eastpoint Tower, Hillsbrad
			[670] = 28, -- Strahnbrad, Alterac Mountains
		},
	},
	{
		tag = "215:347",
		nodeID = 526,
		name = "Tenebrous Cavern, Vashj'ir",
		taxioperator = "seahorse",
		neighbors = {
			[525] = 78, -- Legion's Rest, Vashj'ir
			[612] = 73, -- Stygian Bounty, Vashj'ir
		},
	},
	{
		tag = "451:633",
		nodeID = 384,
		name = "The Bulwark, Tirisfal",
		neighbors = {
			[11] = 89, -- Undercity, Tirisfal
			[13] = 74, -- Tarren Mill, Hillsbrad
			[383] = 73, -- Thondroril River, Eastern Plaguelands
			[460] = 48, -- Brill, Tirisfal Glades
			[649] = 35, -- Andorhal, Western Plaguelands
			[670] = 45, -- Strahnbrad, Alterac Mountains
		},
	},
	{
		tag = "380:569",
		nodeID = 654,
		name = "The Forsaken Front, Silverpine Forest",
		neighbors = {
			[10] = 36, -- The Sepulcher, Silverpine Forest
			[668] = 38, -- Southpoint Gate, Hillsbrad
		},
	},
	{
		tag = "578:452",
		nodeID = 657,
		name = "The Gullet, Twilight Highlands",
		neighbors = {
			[656] = 58, -- Crushblow, Twilight Highlands
			[658] = 31, -- Vermillion Redoubt, Twilight Highlands
			[659] = 55, -- Bloodgulch, Twilight Highlands
		},
	},
	{
		tag = "525:222",
		nodeID = 600,
		name = "The Harborage, Swamp of Sorrows",
		neighbors = {
			[5] = 46, -- Lakeshire, Redridge
			[598] = 38, -- Marshtide Watch, Swamp of Sorrows
		},
	},
	{
		tag = "648:477",
		nodeID = 660,
		name = "The Krazzworks, Twilight Highlands",
		neighbors = {
			[659] = 55, -- Bloodgulch, Twilight Highlands
			[661] = 48, -- Dragonmaw Port, Twilight Highlands
		},
	},
	{
		tag = "487:638",
		nodeID = 651,
		name = "The Menders' Stead, Western Plaguelands",
		neighbors = {
			[66] = 43, -- Chillwind Camp, Western Plaguelands
			[383] = 37, -- Thondroril River, Eastern Plaguelands
			[649] = 29, -- Andorhal, Western Plaguelands
			[672] = 44, -- Hearthglen, Western Plaguelands
		},
	},
	{
		tag = "372:590",
		nodeID = 10,
		name = "The Sepulcher, Silverpine Forest",
		neighbors = {
			[11] = 122, -- Undercity, Tirisfal
			[13] = 97, -- Tarren Mill, Hillsbrad
			["390:623"] = 54, -- ?
			[654] = 25, -- The Forsaken Front, Silverpine Forest
			[681] = 51, -- Forsaken Rear Guard, Silverpine Forest
		},
	},
	{
		tag = "527:385",
		nodeID = 8,
		name = "Thelsamar, Loch Modan",
		neighbors = {
			[6] = 110, -- Ironforge, Dun Morogh
			[7] = 152, -- Menethil Harbor, Wetlands
			[16] = 163, -- Refuge Pointe, Arathi
			[74] = 81, -- Thorium Point, Searing Gorge
			[554] = 60, -- Slabchisel's Survey, Wetlands
			[555] = 46, -- Farstrider Lodge, Loch Modan
			[633] = 46, -- Dustwind Dig, Badlands
			[662] = 181, -- Highbank, Twilight Highlands
		},
	},
	{
		tag = "519:641",
		nodeID = 383,
		name = "Thondroril River, Eastern Plaguelands",
		neighbors = {
			[11] = 161, -- Undercity, Tirisfal
			[13] = 100, -- Tarren Mill, Hillsbrad
			[66] = 58, -- Chillwind Camp, Western Plaguelands
			[67] = 101, -- Light's Hope Chapel, Eastern Plaguelands
			[87] = 45, -- Crown Guard Tower, Eastern Plaguelands
			[384] = 77, -- The Bulwark, Tirisfal
			[617] = 86, -- Hiri'watha Research Station, The Hinterlands
			[618] = 109, -- Stormfeather Outpost, The Hinterlands
			[651] = 39, -- The Menders' Stead, Western Plaguelands
		},
	},
	{
		tag = "464:346",
		nodeID = 74,
		name = "Thorium Point, Searing Gorge",
		faction = "H",
		neighbors = {
			[21] = 67, -- New Kargath, Badlands
			[70] = 61, -- Flame Crest, Burning Steppes
			[673] = 24, -- Iron Summit, Searing Gorge
		},
	},
	{
		tag = "466:346",
		nodeID = 74,
		name = "Thorium Point, Searing Gorge",
		faction = "A",
		neighbors = {
			[2] = 126, -- Stormwind, Elwynn
			[6] = 89, -- Ironforge, Dun Morogh
			[8] = 88, -- Thelsamar, Loch Modan
			[71] = 90, -- Morgan's Vigil, Burning Steppes
			[673] = 25, -- Iron Summit, Searing Gorge
		},
	},
	{
		tag = "599:464",
		nodeID = 665,
		name = "Thundermar, Twilight Highlands",
		neighbors = {
			[658] = 43, -- Vermillion Redoubt, Twilight Highlands
			[663] = 52, -- Victor's Point, Twilight Highlands
			[664] = 58, -- Firebeard's Patrol, Twilight Highlands
			[666] = 24, -- Kirthaven, Twilight Highlands
		},
	},
	{
		tag = "276:344",
		nodeID = 523,
		name = "Tranquil Wash, Vashj'ir",
		taxioperator = "seahorse",
		neighbors = {
			[522] = 44, -- Silver Tide Hollow, Vashj'ir
			[524] = 69, -- Darkbreak Cove, Vashj'ir
			[611] = 60, -- Voldrin's Hold, Vashj'ir
		},
	},
	{
		tag = "578:754",
		nodeID = 83,
		name = "Tranquillien, Ghostlands",
		neighbors = {
			[67] = 128, -- Light's Hope Chapel, Eastern Plaguelands
			[82] = 74, -- Silvermoon City
			[205] = 53, -- Zul'Aman, Ghostlands
			[625] = 53, -- Fairbreeze Village, Eversong Woods
		},
	},
	{
		tag = "416:628",
		nodeID = 11,
		name = "Undercity, Tirisfal",
		neighbors = {
			[10] = 100, -- The Sepulcher, Silverpine Forest
			[13] = 145, -- Tarren Mill, Hillsbrad
			[17] = 301, -- Hammerfall, Arathi
			[21] = 476, -- New Kargath, Badlands
			["390:623"] = 67, -- ?
			[67] = 262, -- Light's Hope Chapel, Eastern Plaguelands
			[76] = 272, -- Revantusk Village, The Hinterlands
			[383] = 157, -- Thondroril River, Eastern Plaguelands
			[384] = 89, -- The Bulwark, Tirisfal
			[460] = 62, -- Brill, Tirisfal Glades
			[601] = 248, -- Galen's Fall, Arathi
			[608] = 345, -- Sandy Beach, Vashj'ir
		},
	},
	{
		tag = "562:468",
		nodeID = 658,
		name = "Vermillion Redoubt, Twilight Highlands",
		neighbors = {
			[6] = 152, -- Ironforge, Dun Morogh
			[16] = 92, -- Refuge Pointe, Arathi
			[17] = 109, -- Hammerfall, Arathi
			[21] = 124, -- New Kargath, Badlands
			[552] = 44, -- Greenwarden's Grove, Wetlands
			[657] = 19, -- The Gullet, Twilight Highlands
			[665] = 29, -- Thundermar, Twilight Highlands
		},
	},
	{
		tag = "590:429",
		nodeID = 663,
		name = "Victor's Point, Twilight Highlands",
		neighbors = {
			[664] = 41, -- Firebeard's Patrol, Twilight Highlands
			[665] = 43, -- Thundermar, Twilight Highlands
		},
	},
	{
		tag = "290:323",
		nodeID = 611,
		name = "Voldrin's Hold, Vashj'ir",
		taxioperator = "seahorse",
		neighbors = {
			[523] = 46, -- Tranquil Wash, Vashj'ir
			[524] = 81, -- Darkbreak Cove, Vashj'ir
		},
	},
	{
		tag = "289:323",
		nodeID = 605,
		name = "Voldrin's Hold, Vashj'ir",
		neighbors = {
			[606] = 70, -- Sandy Beach, Vashj'ir
		},
	},
	{
		tag = "495:462",
		nodeID = 551,
		name = "Whelgar's Retreat, Wetlands",
		neighbors = {
			[7] = 53, -- Menethil Harbor, Wetlands
			[552] = 30, -- Greenwarden's Grove, Wetlands
			[553] = 29, -- Dun Modr, Wetlands
		},
	},
	{
		tag = "611:726",
		nodeID = 205,
		name = "Zul'Aman, Ghostlands",
		neighbors = {
			[67] = 227, -- Light's Hope Chapel, Eastern Plaguelands
			[83] = 52, -- Tranquillien, Ghostlands
			[213] = 251, -- Shattered Sun Staging Area
		},
	},
}





-------------------------------------------------
-----  OUTLAND (THE BURNING CRUSADE)  -----
-------------------------------------------------
-- early beta has mapID set to 102. should be 101. If so, update Lib:GetMapContinent
data.flightcost[102]={
	{
		tag = "554:234",
		nodeID = 121,
		name = "Allerian Stronghold, Terokkar Forest",
		neighbors = {
			[100] = 96, -- Honor Hold, Hellfire Peninsula
			[119] = 149, -- Telaar, Nagrand
			[124] = 79, -- Wildhammer Stronghold, Shadowmoon Valley
			[128] = 74, -- Shattrath, Terokkar Forest
		},
	},
	{
		tag = "808:228",
		nodeID = 140,
		name = "Altar of Sha'tar, Shadowmoon Valley",
		neighbors = {
			[123] = 66, -- Shadowmoon Village, Shadowmoon Valley
			[124] = 80, -- Wildhammer Stronghold, Shadowmoon Valley
		},
	},
	{
		tag = "576:729",
		nodeID = 122,
		name = "Area 52, Netherstorm",
		neighbors = {
			[125] = 126, -- Sylvanaar, Blade's Edge Mountains
			[126] = 108, -- Thunderlord Stronghold, Blade's Edge Mountains
			[139] = 48, -- The Stormspire, Netherstorm
			[150] = 66, -- Cosmowrench, Netherstorm
			[156] = 93, -- Toshley's Station, Blade's Edge Mountains
			[160] = 80, -- Evergrove, Blade's Edge Mountains
			[163] = 64, -- Mok'Nathal Village, Blade's Edge Mountains
		},
	},
	{
		tag = "002:002",
		nodeID = -202,
		name = "Blackwing Landing, Terokkar Forest",
		taxioperator = "skyguard",
		neighbors = {
			[-201] = 245, -- ?
		},
	},
	{
		tag = "719:720",
		nodeID = 150,
		name = "Cosmowrench, Netherstorm",
		neighbors = {
			[122] = 64, -- Area 52, Netherstorm
			[139] = 60, -- The Stormspire, Netherstorm
		},
	},
	{
		tag = "421:720",
		nodeID = 160,
		name = "Evergrove, Blade's Edge Mountains",
		neighbors = {
			[122] = 77, -- Area 52, Netherstorm
			[125] = 55, -- Sylvanaar, Blade's Edge Mountains
			[126] = 36, -- Thunderlord Stronghold, Blade's Edge Mountains
			[156] = 44, -- Toshley's Station, Blade's Edge Mountains
		},
	},
	{
		tag = "535:430",
		nodeID = 102,
		name = "Falcon Watch, Hellfire Peninsula",
		neighbors = {
			[99] = 73, -- Thrallmar, Hellfire Peninsula
			[118] = 149, -- Zabra'jin, Zangarmarsh
			[120] = 132, -- Garadar, Nagrand
			[128] = 71, -- Shattrath, Terokkar Forest
			[151] = 68, -- Swamprat Post, Zangarmarsh
		},
	},
	{
		tag = "288:375",
		nodeID = 120,
		name = "Garadar, Nagrand",
		neighbors = {
			[102] = 127, -- Falcon Watch, Hellfire Peninsula
			[118] = 67, -- Zabra'jin, Zangarmarsh
			[128] = 77, -- Shattrath, Terokkar Forest
		},
	},
	{
		tag = "786:451",
		nodeID = 129,
		name = "Hellfire Peninsula, The Dark Portal",
		faction = "A",
		neighbors = {
			[100] = 73, -- Honor Hold, Hellfire Peninsula
			[101] = 115, -- Temple of Telhamat, Hellfire Peninsula
			["748:500"] = 27, -- ?
		},
	},
	{
		tag = "786:463",
		nodeID = 129,
		name = "Hellfire Peninsula, The Dark Portal",
		faction = "H",
		neighbors = {
			[99] = 60, -- Thrallmar, Hellfire Peninsula
			[102] = 122, -- Falcon Watch, Hellfire Peninsula
		},
	},
	{
		tag = "648:423",
		nodeID = 100,
		name = "Honor Hold, Hellfire Peninsula",
		neighbors = {
			[101] = 75, -- Temple of Telhamat, Hellfire Peninsula
			[121] = 118, -- Allerian Stronghold, Terokkar Forest
			[128] = 119, -- Shattrath, Terokkar Forest
			["748:500"] = 56, -- ?
			[129] = 64, -- Hellfire Peninsula, The Dark Portal
		},
	},
	{
		tag = "486:643",
		nodeID = 163,
		name = "Mok'Nathal Village, Blade's Edge Mountains",
		neighbors = {
			[122] = 56, -- Area 52, Netherstorm
			[126] = 63, -- Thunderlord Stronghold, Blade's Edge Mountains
			[151] = 73, -- Swamprat Post, Zangarmarsh
		},
	},
	{
		tag = "266:556",
		nodeID = 164,
		name = "Orebor Harborage, Zangarmarsh",
		neighbors = {
			[117] = 52, -- Telredor, Zangarmarsh
			[125] = 64, -- Sylvanaar, Blade's Edge Mountains
		},
	},
	{
		tag = "778:146",
		nodeID = 159,
		name = "Sanctum of the Stars, Shadowmoon Valley",
		neighbors = {
			[123] = 61, -- Shadowmoon Village, Shadowmoon Valley
			[124] = 41, -- Wildhammer Stronghold, Shadowmoon Valley
		},
	},
	{
		tag = "661:232",
		nodeID = 123,
		name = "Shadowmoon Village, Shadowmoon Valley",
		neighbors = {
			[127] = 73, -- Stonebreaker Hold, Terokkar Forest
			[140] = 84, -- Altar of Sha'tar, Shadowmoon Valley
			[159] = 65, -- Sanctum of the Stars, Shadowmoon Valley
		},
	},
	{
		tag = "748:500",
		name = "Shatter Point, Hellfire Peninsula",
		neighbors = {
			[100] = 57, -- Honor Hold, Hellfire Peninsula
			[129] = 32, -- Hellfire Peninsula, The Dark Portal
		},
	},
	{
		tag = "437:328",
		nodeID = 128,
		name = "Shattrath, Terokkar Forest",
		neighbors = {
			[99] = 131, -- Thrallmar, Hellfire Peninsula
			[100] = 111, -- Honor Hold, Hellfire Peninsula
			[102] = 76, -- Falcon Watch, Hellfire Peninsula
			[117] = 83, -- Telredor, Zangarmarsh
			[118] = 136, -- Zabra'jin, Zangarmarsh
			[119] = 88, -- Telaar, Nagrand
			[120] = 81, -- Garadar, Nagrand
			[121] = 75, -- Allerian Stronghold, Terokkar Forest
			[127] = 68, -- Stonebreaker Hold, Terokkar Forest
			[151] = 79, -- Swamprat Post, Zangarmarsh
		},
	},
	{
		tag = "001:001",
		nodeID = -201,
		name = "Skyguard Outpost, Blade's Edge Mountains",
		taxioperator = "skyguard",
		neighbors = {
			[-202] = 245, -- ?
		},
	},
	{
		tag = "677:370",
		nodeID = 141,
		name = "Spinebreaker Ridge, Hellfire Peninsula",
		neighbors = {
			[99] = 63, -- Thrallmar, Hellfire Peninsula
		},
	},
	{
		tag = "509:268",
		nodeID = 127,
		name = "Stonebreaker Hold, Terokkar Forest",
		neighbors = {
			[99] = 125, -- Thrallmar, Hellfire Peninsula
			[123] = 67, -- Shadowmoon Village, Shadowmoon Valley
			[128] = 56, -- Shattrath, Terokkar Forest
		},
	},
	{
		tag = "444:485",
		nodeID = 151,
		name = "Swamprat Post, Zangarmarsh",
		neighbors = {
			[102] = 62, -- Falcon Watch, Hellfire Peninsula
			[118] = 111, -- Zabra'jin, Zangarmarsh
			[126] = 106, -- Thunderlord Stronghold, Blade's Edge Mountains
			[128] = 87, -- Shattrath, Terokkar Forest
			[163] = 70, -- Mok'Nathal Village, Blade's Edge Mountains
		},
	},
	{
		tag = "315:656",
		nodeID = 125,
		name = "Sylvanaar, Blade's Edge Mountains",
		neighbors = {
			[117] = 81, -- Telredor, Zangarmarsh
			[122] = 119, -- Area 52, Netherstorm
			[139] = 154, -- The Stormspire, Netherstorm
			[156] = 57, -- Toshley's Station, Blade's Edge Mountains
			[160] = 51, -- Evergrove, Blade's Edge Mountains
			[164] = 76, -- Orebor Harborage, Zangarmarsh
		},
	},
	{
		tag = "274:255",
		nodeID = 119,
		name = "Telaar, Nagrand",
		neighbors = {
			[117] = 126, -- Telredor, Zangarmarsh
			[121] = 121, -- Allerian Stronghold, Terokkar Forest
			[128] = 87, -- Shattrath, Terokkar Forest
		},
	},
	{
		tag = "375:495",
		nodeID = 117,
		name = "Telredor, Zangarmarsh",
		neighbors = {
			[101] = 81, -- Temple of Telhamat, Hellfire Peninsula
			[119] = 124, -- Telaar, Nagrand
			[125] = 91, -- Sylvanaar, Blade's Edge Mountains
			[128] = 97, -- Shattrath, Terokkar Forest
			[156] = 68, -- Toshley's Station, Blade's Edge Mountains
			[164] = 62, -- Orebor Harborage, Zangarmarsh
		},
	},
	{
		tag = "524:494",
		nodeID = 101,
		name = "Temple of Telhamat, Hellfire Peninsula",
		neighbors = {
			[100] = 87, -- Honor Hold, Hellfire Peninsula
			[117] = 80, -- Telredor, Zangarmarsh
		},
	},
	{
		tag = "628:816",
		nodeID = 139,
		name = "The Stormspire, Netherstorm",
		neighbors = {
			[122] = 53, -- Area 52, Netherstorm
			[125] = 154, -- Sylvanaar, Blade's Edge Mountains
			[126] = 146, -- Thunderlord Stronghold, Blade's Edge Mountains
			[150] = 68, -- Cosmowrench, Netherstorm
		},
	},
	{
		tag = "655:496",
		nodeID = 99,
		name = "Thrallmar, Hellfire Peninsula",
		neighbors = {
			[102] = 67, -- Falcon Watch, Hellfire Peninsula
			[127] = 128, -- Stonebreaker Hold, Terokkar Forest
			[128] = 123, -- Shattrath, Terokkar Forest
			[129] = 70, -- Hellfire Peninsula, The Dark Portal
			[141] = 66, -- Spinebreaker Ridge, Hellfire Peninsula
		},
	},
	{
		tag = "378:677",
		nodeID = 126,
		name = "Thunderlord Stronghold, Blade's Edge Mountains",
		neighbors = {
			[118] = 148, -- Zabra'jin, Zangarmarsh
			[122] = 96, -- Area 52, Netherstorm
			[139] = 158, -- The Stormspire, Netherstorm
			[151] = 116, -- Swamprat Post, Zangarmarsh
			[160] = 26, -- Evergrove, Blade's Edge Mountains
			[163] = 55, -- Mok'Nathal Village, Blade's Edge Mountains
		},
	},
	{
		tag = "418:629",
		nodeID = 156,
		name = "Toshley's Station, Blade's Edge Mountains",
		neighbors = {
			[117] = 72, -- Telredor, Zangarmarsh
			[122] = 83, -- Area 52, Netherstorm
			[125] = 59, -- Sylvanaar, Blade's Edge Mountains
			[160] = 53, -- Evergrove, Blade's Edge Mountains
		},
	},
	{
		tag = "694:153",
		nodeID = 124,
		name = "Wildhammer Stronghold, Shadowmoon Valley",
		neighbors = {
			[121] = 100, -- Allerian Stronghold, Terokkar Forest
			[140] = 83, -- Altar of Sha'tar, Shadowmoon Valley
			[159] = 42, -- Sanctum of the Stars, Shadowmoon Valley
		},
	},
	{
		tag = "232:496",
		nodeID = 118,
		name = "Zabra'jin, Zangarmarsh",
		neighbors = {
			[102] = 147, -- Falcon Watch, Hellfire Peninsula
			[120] = 82, -- Garadar, Nagrand
			[126] = 112, -- Thunderlord Stronghold, Blade's Edge Mountains
			[128] = 151, -- Shattrath, Terokkar Forest
			[151] = 112, -- Swamprat Post, Zangarmarsh
		},
	},
}










------------------------------------------------------
-----  NORTHREND (WRATH OF THE LICH KING)  -----
------------------------------------------------------
data.flightcost[113]={
	{
		tag = "453:491",
		nodeID = 256,
		name = "Agmar's Hammer, Dragonblight",
		neighbors = {
			[252] = 51, -- Wyrmrest Temple, Dragonblight
			[254] = 88, -- Venomspite, Dragonblight
			[258] = 113, -- Taunka'le Village, Borean Tundra
			[260] = 65, -- Kor'kron Vanguard, Dragonblight
			[294] = 63, -- Moa'ki, Dragonblight
			[332] = 117, -- Warsong Camp, Wintergrasp
		},
	},
	{
		tag = "165:473",
		nodeID = 289,
		name = "Amber Ledge, Borean Tundra",
		neighbors = {
			[226] = 37, -- Transitus Shield, Coldarra
			[245] = 66, -- Valiance Keep, Borean Tundra
			[246] = 35, -- Fizzcrank Airstrip, Borean Tundra
			[257] = 41, -- Warsong Hold, Borean Tundra
			[258] = 71, -- Taunka'le Village, Borean Tundra
			[259] = 34, -- Bor'gorok Outpost, Borean Tundra
		},
	},
	{
		tag = "729:464",
		nodeID = 253,
		name = "Amberpine Lodge, Grizzly Hills",
		neighbors = {
			[184] = 116, -- Fort Wildervar, Howling Fjord
			[185] = 83, -- Westguard Keep, Howling Fjord
			[244] = 81, -- Wintergarde Keep, Dragonblight
			[255] = 83, -- Westfall Brigade, Grizzly Hills
			[306] = 66, -- Light's Breach, Zul'Drak
		},
	},
	{
		tag = "743:377",
		nodeID = 248,
		name = "Apothecary Camp, Howling Fjord",
		neighbors = {
			[190] = 92, -- New Agamand, Howling Fjord
			[192] = 60, -- Camp Winterhoof, Howling Fjord
			[250] = 47, -- Conquest Hold, Grizzly Hills
			[254] = 117, -- Venomspite, Dragonblight
			[295] = 54, -- Kamagua, Howling Fjord
		},
	},
	{
		tag = "494:789",
		nodeID = 340,
		name = "Argent Tournament Grounds, Icecrown",
		neighbors = {
			[310] = 140, -- Dalaran
			[327] = 52, -- Bouldercrag's Refuge, The Storm Peaks
			[333] = 89, -- The Shadow Vault, Icecrown
			[335] = 73, -- Crusaders' Pinnacle, Icecrown
		},
	},
	{
		tag = "182:530",
		nodeID = 259,
		name = "Bor'gorok Outpost, Borean Tundra",
		neighbors = {
			[257] = 72, -- Warsong Hold, Borean Tundra
			[258] = 77, -- Taunka'le Village, Borean Tundra
			[289] = 58, -- Amber Ledge, Borean Tundra
			[308] = 56, -- River's Heart, Sholazar Basin
			[309] = 47, -- Nesingwary Base Camp, Sholazar Basin
		},
	},
	{
		tag = "573:789",
		nodeID = 327,
		name = "Bouldercrag's Refuge, The Storm Peaks",
		neighbors = {
			[321] = 78, -- Frosthold, The Storm Peaks
			[323] = 40, -- Grom'arsh Crash-Site, The Storm Peaks
			[326] = 44, -- Ulduar, The Storm Peaks
			[333] = 112, -- The Shadow Vault, Icecrown
			[340] = 61, -- Argent Tournament Grounds, Icecrown
		},
	},
	{
		tag = "844:492",
		nodeID = 249,
		name = "Camp Oneqwah, Grizzly Hills",
		neighbors = {
			[191] = 105, -- Vengeance Landing, Howling Fjord
			[192] = 49, -- Camp Winterhoof, Howling Fjord
			[250] = 97, -- Conquest Hold, Grizzly Hills
			[304] = 99, -- The Argent Stand, Zul'Drak
			[306] = 92, -- Light's Breach, Zul'Drak
			[307] = 92, -- Zim'Torga, Zul'Drak
		},
	},
	{
		tag = "733:745",
		nodeID = 324,
		name = "Camp Tunka'lo, The Storm Peaks",
		neighbors = {
			[307] = 98, -- Zim'Torga, Zul'Drak
			[320] = 114, -- K3, The Storm Peaks
			[322] = 45, -- Dun Niffelem, The Storm Peaks
			[323] = 101, -- Grom'arsh Crash-Site, The Storm Peaks
			[326] = 73, -- Ulduar, The Storm Peaks
		},
	},
	{
		tag = "835:412",
		nodeID = 192,
		name = "Camp Winterhoof, Howling Fjord",
		neighbors = {
			[190] = 79, -- New Agamand, Howling Fjord
			[191] = 73, -- Vengeance Landing, Howling Fjord
			[248] = 57, -- Apothecary Camp, Howling Fjord
			[249] = 58, -- Camp Oneqwah, Grizzly Hills
			[250] = 93, -- Conquest Hold, Grizzly Hills
		},
	},
	{
		tag = "698:452",
		nodeID = 250,
		name = "Conquest Hold, Grizzly Hills",
		neighbors = {
			[192] = 85, -- Camp Winterhoof, Howling Fjord
			[248] = 57, -- Apothecary Camp, Howling Fjord
			[249] = 102, -- Camp Oneqwah, Grizzly Hills
			[254] = 87, -- Venomspite, Dragonblight
			[306] = 79, -- Light's Breach, Zul'Drak
		},
	},
	{
		tag = "521:655",
		nodeID = 335,
		name = "Crusaders' Pinnacle, Icecrown",
		neighbors = {
			[310] = 70, -- Dalaran
			[325] = 168, -- Death's Rise, Icecrown
			[332] = 159, -- Warsong Camp, Wintergrasp
			[333] = 123, -- The Shadow Vault, Icecrown
			[334] = 32, -- The Argent Vanguard, Icecrown
			[340] = 97, -- Argent Tournament Grounds, Icecrown
		},
	},
	{
		tag = "522:617",
		nodeID = 310,
		name = "Dalaran",
		neighbors = {
			[183] = 281, -- Valgarde Port, Howling Fjord
			[245] = 261, -- Valiance Keep, Borean Tundra
			[251] = 100, -- Fordragon Hold, Dragonblight
			[252] = 122, -- Wyrmrest Temple, Dragonblight
			[260] = 73, -- Kor'kron Vanguard, Dragonblight
			[294] = 159, -- Moa'ki, Dragonblight
			[303] = 116, -- Valiance Landing Camp, Wintergrasp
			[305] = 81, -- Ebon Watch, Zul'Drak
			[308] = 212, -- River's Heart, Sholazar Basin
			[320] = 54, -- K3, The Storm Peaks
			[332] = 161, -- Warsong Camp, Wintergrasp
			[334] = 32, -- The Argent Vanguard, Icecrown
			[335] = 39, -- Crusaders' Pinnacle, Icecrown
			[336] = 52, -- Windrunner's Overlook, Crystalsong Forest
			[337] = 57, -- Sunreaver's Command, Crystalsong Forest
			[340] = 123, -- Argent Tournament Grounds, Icecrown
		},
	},
	{
		tag = "278:721",
		nodeID = 325,
		name = "Death's Rise, Icecrown",
		neighbors = {
			[303] = 173, -- Valiance Landing Camp, Wintergrasp
			[308] = 116, -- River's Heart, Sholazar Basin
			[309] = 117, -- Nesingwary Base Camp, Sholazar Basin
			[332] = 114, -- Warsong Camp, Wintergrasp
			[333] = 93, -- The Shadow Vault, Icecrown
			[335] = 175, -- Crusaders' Pinnacle, Icecrown
		},
	},
	{
		tag = "720:713",
		nodeID = 322,
		name = "Dun Niffelem, The Storm Peaks",
		neighbors = {
			[307] = 88, -- Zim'Torga, Zul'Drak
			[320] = 87, -- K3, The Storm Peaks
			[324] = 32, -- Camp Tunka'lo, The Storm Peaks
			[326] = 84, -- Ulduar, The Storm Peaks
		},
	},
	{
		tag = "636:578",
		nodeID = 305,
		name = "Ebon Watch, Zul'Drak",
		neighbors = {
			[244] = 61, -- Wintergarde Keep, Dragonblight
			[251] = 111, -- Fordragon Hold, Dragonblight
			[252] = 91, -- Wyrmrest Temple, Dragonblight
			[254] = 98, -- Venomspite, Dragonblight
			[260] = 108, -- Kor'kron Vanguard, Dragonblight
			[304] = 63, -- The Argent Stand, Zul'Drak
			[306] = 44, -- Light's Breach, Zul'Drak
			[310] = 67, -- Dalaran
			[320] = 40, -- K3, The Storm Peaks
			[336] = 33, -- Windrunner's Overlook, Crystalsong Forest
			[337] = 26, -- Sunreaver's Command, Crystalsong Forest
		},
	},
	{
		tag = "208:508",
		nodeID = 246,
		name = "Fizzcrank Airstrip, Borean Tundra",
		neighbors = {
			[245] = 70, -- Valiance Keep, Borean Tundra
			[247] = 133, -- Stars' Rest, Dragonblight
			[289] = 44, -- Amber Ledge, Borean Tundra
			[296] = 64, -- Unu'pe, Borean Tundra
			[308] = 63, -- River's Heart, Sholazar Basin
			[309] = 76, -- Nesingwary Base Camp, Sholazar Basin
		},
	},
	{
		tag = "460:539",
		nodeID = 251,
		name = "Fordragon Hold, Dragonblight",
		neighbors = {
			[244] = 86, -- Wintergarde Keep, Dragonblight
			[247] = 73, -- Stars' Rest, Dragonblight
			[252] = 65, -- Wyrmrest Temple, Dragonblight
			[303] = 60, -- Valiance Landing Camp, Wintergrasp
			[305] = 118, -- Ebon Watch, Zul'Drak
			[310] = 65, -- Dalaran
		},
	},
	{
		tag = "999:999",
		name = "Forsaken Forward Command, Gilneas",
		neighbors = {
			["000:000"] = 999, -- ?
		},
	},
	{
		tag = "877:400",
		nodeID = 184,
		name = "Fort Wildervar, Howling Fjord",
		neighbors = {
			[183] = 73, -- Valgarde Port, Howling Fjord
			[185] = 80, -- Westguard Keep, Howling Fjord
			[253] = 96, -- Amberpine Lodge, Grizzly Hills
			[255] = 97, -- Westfall Brigade, Grizzly Hills
		},
	},
	{
		tag = "568:672",
		nodeID = 321,
		name = "Frosthold, The Storm Peaks",
		neighbors = {
			[320] = 48, -- K3, The Storm Peaks
			[326] = 97, -- Ulduar, The Storm Peaks
			[327] = 65, -- Bouldercrag's Refuge, The Storm Peaks
			[334] = 33, -- The Argent Vanguard, Icecrown
		},
	},
	{
		tag = "599:749",
		nodeID = 323,
		name = "Grom'arsh Crash-Site, The Storm Peaks",
		neighbors = {
			[320] = 87, -- K3, The Storm Peaks
			[324] = 96, -- Camp Tunka'lo, The Storm Peaks
			[326] = 51, -- Ulduar, The Storm Peaks
			[327] = 37, -- Bouldercrag's Refuge, The Storm Peaks
			[334] = 79, -- The Argent Vanguard, Icecrown
		},
	},
	{
		tag = "818:687",
		nodeID = 331,
		name = "Gundrak, Zul'Drak",
		neighbors = {
			[307] = 55, -- Zim'Torga, Zul'Drak
		},
	},
	{
		tag = "619:641",
		nodeID = 320,
		name = "K3, The Storm Peaks",
		neighbors = {
			[305] = 43, -- Ebon Watch, Zul'Drak
			[310] = 72, -- Dalaran
			[321] = 43, -- Frosthold, The Storm Peaks
			[322] = 100, -- Dun Niffelem, The Storm Peaks
			[323] = 75, -- Grom'arsh Crash-Site, The Storm Peaks
			[324] = 90, -- Camp Tunka'lo, The Storm Peaks
			[336] = 53, -- Windrunner's Overlook, Crystalsong Forest
			[337] = 37, -- Sunreaver's Command, Crystalsong Forest
		},
	},
	{
		tag = "738:292",
		nodeID = 295,
		name = "Kamagua, Howling Fjord",
		neighbors = {
			[183] = 80, -- Valgarde Port, Howling Fjord
			[185] = 36, -- Westguard Keep, Howling Fjord
			[190] = 63, -- New Agamand, Howling Fjord
			[248] = 55, -- Apothecary Camp, Howling Fjord
			[294] = 194, -- Moa'ki, Dragonblight
		},
	},
	{
		tag = "476:561",
		nodeID = 260,
		name = "Kor'kron Vanguard, Dragonblight",
		neighbors = {
			[252] = 67, -- Wyrmrest Temple, Dragonblight
			[254] = 90, -- Venomspite, Dragonblight
			[256] = 52, -- Agmar's Hammer, Dragonblight
			[305] = 106, -- Ebon Watch, Zul'Drak
			[310] = 56, -- Dalaran
		},
	},
	{
		tag = "694:576",
		nodeID = 306,
		name = "Light's Breach, Zul'Drak",
		neighbors = {
			[244] = 83, -- Wintergarde Keep, Dragonblight
			[249] = 105, -- Camp Oneqwah, Grizzly Hills
			[250] = 74, -- Conquest Hold, Grizzly Hills
			[253] = 83, -- Amberpine Lodge, Grizzly Hills
			[254] = 121, -- Venomspite, Dragonblight
			[304] = 43, -- The Argent Stand, Zul'Drak
			[305] = 39, -- Ebon Watch, Zul'Drak
		},
	},
	{
		tag = "493:421",
		nodeID = 294,
		name = "Moa'ki, Dragonblight",
		neighbors = {
			[244] = 85, -- Wintergarde Keep, Dragonblight
			[247] = 54, -- Stars' Rest, Dragonblight
			[252] = 48, -- Wyrmrest Temple, Dragonblight
			[254] = 61, -- Venomspite, Dragonblight
			[256] = 64, -- Agmar's Hammer, Dragonblight
			[295] = 184, -- Kamagua, Howling Fjord
			[296] = 132, -- Unu'pe, Borean Tundra
			[310] = 122, -- Dalaran
		},
	},
	{
		tag = "175:603",
		nodeID = 309,
		name = "Nesingwary Base Camp, Sholazar Basin",
		neighbors = {
			[246] = 77, -- Fizzcrank Airstrip, Borean Tundra
			[259] = 60, -- Bor'gorok Outpost, Borean Tundra
			[308] = 51, -- River's Heart, Sholazar Basin
			[325] = 91, -- Death's Rise, Icecrown
		},
	},
	{
		tag = "845:267",
		nodeID = 190,
		name = "New Agamand, Howling Fjord",
		neighbors = {
			[191] = 80, -- Vengeance Landing, Howling Fjord
			[192] = 80, -- Camp Winterhoof, Howling Fjord
			[248] = 103, -- Apothecary Camp, Howling Fjord
			[254] = 191, -- Venomspite, Dragonblight
			[295] = 76, -- Kamagua, Howling Fjord
		},
	},
	{
		tag = "244:597",
		nodeID = 308,
		name = "River's Heart, Sholazar Basin",
		neighbors = {
			[246] = 69, -- Fizzcrank Airstrip, Borean Tundra
			[259] = 61, -- Bor'gorok Outpost, Borean Tundra
			[303] = 150, -- Valiance Landing Camp, Wintergrasp
			[309] = 42, -- Nesingwary Base Camp, Sholazar Basin
			[310] = 301, -- Dalaran
			[325] = 93, -- Death's Rise, Icecrown
			[332] = 86, -- Warsong Camp, Wintergrasp
		},
	},
	{
		tag = "423:467",
		nodeID = 247,
		name = "Stars' Rest, Dragonblight",
		neighbors = {
			[244] = 123, -- Wintergarde Keep, Dragonblight
			[245] = 132, -- Valiance Keep, Borean Tundra
			[246] = 129, -- Fizzcrank Airstrip, Borean Tundra
			[251] = 80, -- Fordragon Hold, Dragonblight
			[252] = 89, -- Wyrmrest Temple, Dragonblight
			[294] = 70, -- Moa'ki, Dragonblight
			[296] = 100, -- Unu'pe, Borean Tundra
			[303] = 67, -- Valiance Landing Camp, Wintergrasp
		},
	},
	{
		tag = "596:602",
		nodeID = 337,
		name = "Sunreaver's Command, Crystalsong Forest",
		neighbors = {
			[305] = 37, -- Ebon Watch, Zul'Drak
			[310] = 55, -- Dalaran
			[320] = 33, -- K3, The Storm Peaks
		},
	},
	{
		tag = "287:464",
		nodeID = 258,
		name = "Taunka'le Village, Borean Tundra",
		neighbors = {
			[256] = 91, -- Agmar's Hammer, Dragonblight
			[257] = 84, -- Warsong Hold, Borean Tundra
			[259] = 72, -- Bor'gorok Outpost, Borean Tundra
			[289] = 76, -- Amber Ledge, Borean Tundra
			[296] = 30, -- Unu'pe, Borean Tundra
			[332] = 80, -- Warsong Camp, Wintergrasp
		},
	},
	{
		tag = "724:598",
		nodeID = 304,
		name = "The Argent Stand, Zul'Drak",
		neighbors = {
			[249] = 99, -- Camp Oneqwah, Grizzly Hills
			[255] = 71, -- Westfall Brigade, Grizzly Hills
			[305] = 52, -- Ebon Watch, Zul'Drak
			[306] = 24, -- Light's Breach, Zul'Drak
			[307] = 41, -- Zim'Torga, Zul'Drak
		},
	},
	{
		tag = "555:639",
		nodeID = 334,
		name = "The Argent Vanguard, Icecrown",
		neighbors = {
			[310] = 31, -- Dalaran
			[321] = 40, -- Frosthold, The Storm Peaks
			[323] = 103, -- Grom'arsh Crash-Site, The Storm Peaks
			[333] = 147, -- The Shadow Vault, Icecrown
			[335] = 27, -- Crusaders' Pinnacle, Icecrown
		},
	},
	{
		tag = "377:785",
		nodeID = 333,
		name = "The Shadow Vault, Icecrown",
		neighbors = {
			[303] = 141, -- Valiance Landing Camp, Wintergrasp
			[325] = 77, -- Death's Rise, Icecrown
			[327] = 121, -- Bouldercrag's Refuge, The Storm Peaks
			[332] = 138, -- Warsong Camp, Wintergrasp
			[334] = 134, -- The Argent Vanguard, Icecrown
			[335] = 120, -- Crusaders' Pinnacle, Icecrown
			[340] = 78, -- Argent Tournament Grounds, Icecrown
		},
	},
	{
		tag = "121:472",
		nodeID = 226,
		name = "Transitus Shield, Coldarra",
		neighbors = {
			[289] = 45, -- Amber Ledge, Borean Tundra
		},
	},
	{
		tag = "637:814",
		nodeID = 326,
		name = "Ulduar, The Storm Peaks",
		neighbors = {
			[307] = 153, -- Zim'Torga, Zul'Drak
			[321] = 102, -- Frosthold, The Storm Peaks
			[322] = 103, -- Dun Niffelem, The Storm Peaks
			[323] = 43, -- Grom'arsh Crash-Site, The Storm Peaks
			[324] = 87, -- Camp Tunka'lo, The Storm Peaks
			[327] = 48, -- Bouldercrag's Refuge, The Storm Peaks
		},
	},
	{
		tag = "290:430",
		nodeID = 296,
		name = "Unu'pe, Borean Tundra",
		neighbors = {
			[245] = 59, -- Valiance Keep, Borean Tundra
			[246] = 79, -- Fizzcrank Airstrip, Borean Tundra
			[247] = 97, -- Stars' Rest, Dragonblight
			[257] = 87, -- Warsong Hold, Borean Tundra
			[258] = 21, -- Taunka'le Village, Borean Tundra
			[294] = 118, -- Moa'ki, Dragonblight
		},
	},
	{
		tag = "875:278",
		nodeID = 183,
		name = "Valgarde Port, Howling Fjord",
		neighbors = {
			[184] = 70, -- Fort Wildervar, Howling Fjord
			[185] = 69, -- Westguard Keep, Howling Fjord
			[295] = 95, -- Kamagua, Howling Fjord
			[310] = 281, -- Dalaran
		},
	},
	{
		tag = "217:388",
		nodeID = 245,
		name = "Valiance Keep, Borean Tundra",
		neighbors = {
			[246] = 75, -- Fizzcrank Airstrip, Borean Tundra
			[247] = 145, -- Stars' Rest, Dragonblight
			[289] = 63, -- Amber Ledge, Borean Tundra
			[296] = 63, -- Unu'pe, Borean Tundra
			[310] = 262, -- Dalaran
		},
	},
	{
		tag = "410:571",
		nodeID = 303,
		name = "Valiance Landing Camp, Wintergrasp",
		neighbors = {
			[247] = 80, -- Stars' Rest, Dragonblight
			[251] = 49, -- Fordragon Hold, Dragonblight
			[308] = 136, -- River's Heart, Sholazar Basin
			[310] = 91, -- Dalaran
			[325] = 166, -- Death's Rise, Icecrown
			[333] = 162, -- The Shadow Vault, Icecrown
			[335] = 109, -- Crusaders' Pinnacle, Icecrown
		},
	},
	{
		tag = "951:365",
		nodeID = 191,
		name = "Vengeance Landing, Howling Fjord",
		neighbors = {
			[190] = 88, -- New Agamand, Howling Fjord
			[192] = 73, -- Camp Winterhoof, Howling Fjord
			[249] = 104, -- Camp Oneqwah, Grizzly Hills
			[310] = 303, -- Dalaran
		},
	},
	{
		tag = "594:451",
		nodeID = 254,
		name = "Venomspite, Dragonblight",
		neighbors = {
			[190] = 186, -- New Agamand, Howling Fjord
			[248] = 98, -- Apothecary Camp, Howling Fjord
			[250] = 59, -- Conquest Hold, Grizzly Hills
			[252] = 52, -- Wyrmrest Temple, Dragonblight
			[256] = 133, -- Agmar's Hammer, Dragonblight
			[260] = 120, -- Kor'kron Vanguard, Dragonblight
			[294] = 82, -- Moa'ki, Dragonblight
			[305] = 83, -- Ebon Watch, Zul'Drak
			[306] = 106, -- Light's Breach, Zul'Drak
		},
	},
	{
		tag = "313:566",
		nodeID = 332,
		name = "Warsong Camp, Wintergrasp",
		neighbors = {
			[256] = 100, -- Agmar's Hammer, Dragonblight
			[258] = 79, -- Taunka'le Village, Borean Tundra
			[308] = 76, -- River's Heart, Sholazar Basin
			[310] = 141, -- Dalaran
			[325] = 113, -- Death's Rise, Icecrown
			[333] = 164, -- The Shadow Vault, Icecrown
			[335] = 159, -- Crusaders' Pinnacle, Icecrown
		},
	},
	{
		tag = "148:430",
		nodeID = 257,
		name = "Warsong Hold, Borean Tundra",
		neighbors = {
			[258] = 87, -- Taunka'le Village, Borean Tundra
			[259] = 68, -- Bor'gorok Outpost, Borean Tundra
			[289] = 35, -- Amber Ledge, Borean Tundra
			[296] = 92, -- Unu'pe, Borean Tundra
		},
	},
	{
		tag = "826:537",
		nodeID = 255,
		name = "Westfall Brigade, Grizzly Hills",
		neighbors = {
			[184] = 85, -- Fort Wildervar, Howling Fjord
			[253] = 78, -- Amberpine Lodge, Grizzly Hills
			[304] = 81, -- The Argent Stand, Zul'Drak
			[307] = 72, -- Zim'Torga, Zul'Drak
		},
	},
	{
		tag = "764:328",
		nodeID = 185,
		name = "Westguard Keep, Howling Fjord",
		neighbors = {
			[183] = 69, -- Valgarde Port, Howling Fjord
			[184] = 85, -- Fort Wildervar, Howling Fjord
			[244] = 151, -- Wintergarde Keep, Dragonblight
			[253] = 76, -- Amberpine Lodge, Grizzly Hills
			[295] = 51, -- Kamagua, Howling Fjord
		},
	},
	{
		tag = "585:566",
		nodeID = 336,
		name = "Windrunner's Overlook, Crystalsong Forest",
		neighbors = {
			[244] = 75, -- Wintergarde Keep, Dragonblight
			[305] = 46, -- Ebon Watch, Zul'Drak
			[310] = 47, -- Dalaran
			[320] = 46, -- K3, The Storm Peaks
		},
	},
	{
		tag = "596:481",
		nodeID = 244,
		name = "Wintergarde Keep, Dragonblight",
		neighbors = {
			[185] = 125, -- Westguard Keep, Howling Fjord
			[247] = 114, -- Stars' Rest, Dragonblight
			[251] = 96, -- Fordragon Hold, Dragonblight
			[252] = 54, -- Wyrmrest Temple, Dragonblight
			[253] = 77, -- Amberpine Lodge, Grizzly Hills
			[294] = 98, -- Moa'ki, Dragonblight
			[305] = 64, -- Ebon Watch, Zul'Drak
			[306] = 88, -- Light's Breach, Zul'Drak
			[336] = 71, -- Windrunner's Overlook, Crystalsong Forest
		},
	},
	{
		tag = "535:477",
		nodeID = 252,
		name = "Wyrmrest Temple, Dragonblight",
		neighbors = {
			[244] = 50, -- Wintergarde Keep, Dragonblight
			[247] = 66, -- Stars' Rest, Dragonblight
			[251] = 58, -- Fordragon Hold, Dragonblight
			[254] = 50, -- Venomspite, Dragonblight
			[256] = 69, -- Agmar's Hammer, Dragonblight
			[260] = 66, -- Kor'kron Vanguard, Dragonblight
			[294] = 53, -- Moa'ki, Dragonblight
			[305] = 105, -- Ebon Watch, Zul'Drak
			[310] = 65, -- Dalaran
		},
	},
	{
		tag = "784:614",
		nodeID = 307,
		name = "Zim'Torga, Zul'Drak",
		neighbors = {
			[249] = 82, -- Camp Oneqwah, Grizzly Hills
			[255] = 56, -- Westfall Brigade, Grizzly Hills
			[304] = 52, -- The Argent Stand, Zul'Drak
			[322] = 85, -- Dun Niffelem, The Storm Peaks
			[324] = 86, -- Camp Tunka'lo, The Storm Peaks
			[326] = 154, -- Ulduar, The Storm Peaks
			[331] = 53, -- Gundrak, Zul'Drak
		},
	},
}











------------------------------------------------
-----  PANDARIA (MISTS OF PANDARIA)  -----
------------------------------------------------
data.flightcost[424]={
	{
		tag = "463:856",
		name = "Beeble's Wreck, Isle of Giants",
		nodeID = 1221,
		neighbors = {
			[1021] = 54, -- Zouchin Village, Kun-Lai Summit
			[1057] = 203, -- Shrine of Seven Stars, Vale of Eternal Blossoms
		},
	},
	{
		tag = "543:514",
		nodeID = 1017,
		name = "Binan Village, Kun-Lai Summit",
		neighbors = {
			[966] = 141, -- Paw'Don Village, Jade Forest
			[973] = 58, -- Honeydew Village, Jade Forest
			[986] = 85, -- Zhu's Watch, Krasarang Wilds
			[1018] = 66, -- Temple of the White Tiger, Kun-Lai Summit
			[1019] = 34, -- Eastwind Rest, Kun-Lai Summit
			[1020] = 51, -- Westwind Rest, Kun-Lai Summit
			[1022] = 61, -- One Keg, Kun-Lai Summit
			[1029] = 40, -- Tavern in the Mists, The Veiled Stair
			[1057] = 97, -- Shrine of Seven Stars, Vale of Eternal Blossoms
			[1058] = 84, -- Shrine of Two Moons, Vale of Eternal Blossoms
		},
	},
	{
		tag = "478:860",
		nodeID = 1222,
		name = "Bozzle's Wreck, Isle Of Giants",
		neighbors = {
			[1021] = 50, -- Zouchin Village, Kun-Lai Summit
			[1058] = 185, -- Shrine of Two Moons, Vale of Eternal Blossoms
		},
	},
	{
		tag = "444:197",
		nodeID = 992,
		name = "Cradle of Chi-Ji, Krasarang Wilds",
		neighbors = {
			[985] = 80, -- Halfhill, Valley of the Four Winds
			[988] = 80, -- The Incursion, Krasarang Wilds
			[989] = 61, -- Stoneplow, Valley of the Four Winds
			[990] = 15, -- Dawnchaser Retreat, Krasarang Wilds
			[993] = 43, -- Marista, Krasarang Wilds
		},
	},
	{
		tag = "723:499",
		nodeID = 895,
		name = "Dawn's Blossom, Jade Forest",
		neighbors = {
			[894] = 71, -- Grookin Hill, Jade Forest
			[966] = 78, -- Paw'Don Village, Jade Forest
			[967] = 28, -- The Arboretum, Jade Forest
			[968] = 36, -- Jade Temple Grounds, Jade Forest
			[970] = 40, -- Emperor's Omen, Jade Forest
			[971] = 49, -- Tian Monastery, Jade Forest
			[972] = 70, -- Pearlfin Village, Jade Forest
			[973] = 88, -- Honeydew Village, Jade Forest
			[984] = 76, -- Pang's Stead, Valley of the Four Winds
			[1057] = 178, -- Shrine of Seven Stars, Vale of Eternal Blossoms
			[1058] = 167, -- Shrine of Two Moons, Vale of Eternal Blossoms
			[1080] = 48, -- Serpent's Overlook, Jade Forest
			[1293] = 142, -- Tushui Landing, Timeless Isle
			[1294] = 143, -- Huojin Landing, Timeless Isle
		},
	},
	{
		tag = "435:230",
		nodeID = 990,
		name = "Dawnchaser Retreat, Krasarang Wilds",
		neighbors = {
			["359:225"] = 73, -- ?
			[987] = 67, -- Thunder Cleft, Krasarang Wilds
			[989] = 50, -- Stoneplow, Valley of the Four Winds
			[992] = 19, -- Cradle of Chi-Ji, Krasarang Wilds
			[993] = 50, -- Marista, Krasarang Wilds
			[1070] = 104, -- Klaxxi'vess, Dread Wastes
		},
	},
	{
		tag = "359:225",
		name = "Domination Point, Krassarang Wilds",
		neighbors = {
			[989] = 64, -- Stoneplow, Valley of the Four Winds
			[990] = 61, -- Dawnchaser Retreat, Krasarang Wilds
		},
	},
	{
		tag = "490:561",
		nodeID = 1019,
		name = "Eastwind Rest, Kun-Lai Summit",
		neighbors = {
			[1017] = 30, -- Binan Village, Kun-Lai Summit
			[1018] = 59, -- Temple of the White Tiger, Kun-Lai Summit
			[1021] = 88, -- Zouchin Village, Kun-Lai Summit
			[1022] = 48, -- One Keg, Kun-Lai Summit
			[1023] = 62, -- Kota Basecamp, Kun-Lai Summit
			[1024] = 50, -- Shado-Pan Fallback, Kun-Lai Summit
			[1058] = 61, -- Shrine of Two Moons, Vale of Eternal Blossoms
		},
	},
	{
		tag = "745:574",
		nodeID = 970,
		name = "Emperor's Omen, Jade Forest",
		neighbors = {
			[895] = 38, -- Dawn's Blossom, Jade Forest
			[969] = 23, -- Sri-La Village, Jade Forest
			[971] = 21, -- Tian Monastery, Jade Forest
		},
	},
	{
		tag = "333:493",
		nodeID = 1054,
		name = "Gao-Ran Battlefront, Townlong Steppes",
		neighbors = {
			[1024] = 39, -- Shado-Pan Fallback, Kun-Lai Summit
			[1053] = 46, -- Longying Outpost, Townlong Steppes
			[1055] = 51, -- Rensai's Watchpost, Townlong Steppes
			[1072] = 33, -- The Sunset Brewgarden, Dread Wastes
			[1117] = 33, -- ?
		},
	},
	{
		tag = "577:411",
		nodeID = 1052,
		name = "Grassy Cline, Valley of the Four Winds",
		neighbors = {
			[984] = 30, -- Pang's Stead, Valley of the Four Winds
			[985] = 37, -- Halfhill, Valley of the Four Winds
			[1029] = 16, -- Tavern in the Mists, The Veiled Stair
			[1057] = 64, -- Shrine of Seven Stars, Vale of Eternal Blossoms
			[1058] = 69, -- Shrine of Two Moons, Vale of Eternal Blossoms
		},
	},
	{
		tag = "610:491",
		nodeID = 894,
		name = "Grookin Hill, Jade Forest",
		neighbors = {
			[895] = 63, -- Dawn's Blossom, Jade Forest
			[971] = 58, -- Tian Monastery, Jade Forest
			[973] = 61, -- Honeydew Village, Jade Forest
			[984] = 40, -- Pang's Stead, Valley of the Four Winds
		},
	},
	{
		tag = "530:353",
		nodeID = 985,
		name = "Halfhill, Valley of the Four Winds",
		neighbors = {
			[984] = 51, -- Pang's Stead, Valley of the Four Winds
			[986] = 43, -- Zhu's Watch, Krasarang Wilds
			[987] = 35, -- Thunder Cleft, Krasarang Wilds
			[988] = 44, -- The Incursion, Krasarang Wilds
			[989] = 49, -- Stoneplow, Valley of the Four Winds
			[991] = 66, -- Sentinel Basecamp, Krasarang Wilds
			[992] = 77, -- Cradle of Chi-Ji, Krasarang Wilds
			[1052] = 37, -- Grassy Cline, Valley of the Four Winds
			[1057] = 73, -- Shrine of Seven Stars, Vale of Eternal Blossoms
			[1058] = 76, -- Shrine of Two Moons, Vale of Eternal Blossoms
		},
	},
	{
		tag = "612:618",
		nodeID = 973,
		name = "Honeydew Village, Jade Forest",
		neighbors = {
			[894] = 63, -- Grookin Hill, Jade Forest
			[895] = 77, -- Dawn's Blossom, Jade Forest
			[971] = 43, -- Tian Monastery, Jade Forest
			[1017] = 61, -- Binan Village, Kun-Lai Summit
			[1058] = 126, -- Shrine of Two Moons, Vale of Eternal Blossoms
		},
	},
	{
		tag = "956:338",
		nodeID = 1294,
		name = "Huojin Landing, Timeless Isle",
		neighbors = {
			[895] = 143, -- Dawn's Blossom, Jade Forest
		},
	},
	{
		tag = "767:437",
		nodeID = 968,
		name = "Jade Temple Grounds, Jade Forest",
		neighbors = {
			[895] = 46, -- Dawn's Blossom, Jade Forest
			[966] = 57, -- Paw'Don Village, Jade Forest
			[967] = 38, -- The Arboretum, Jade Forest
			[972] = 36, -- Pearlfin Village, Jade Forest
		},
	},
	{
		tag = "304:387",
		nodeID = 1070,
		name = "Klaxxi'vess, Dread Wastes",
		neighbors = {
			[989] = 50, -- Stoneplow, Valley of the Four Winds
			[990] = 100, -- Dawnchaser Retreat, Krasarang Wilds
			[991] = 71, -- Sentinel Basecamp, Krasarang Wilds
			[1057] = 110, -- Shrine of Seven Stars, Vale of Eternal Blossoms
			[1058] = 97, -- Shrine of Two Moons, Vale of Eternal Blossoms
			[1071] = 48, -- Soggy's Gamble, Dread Wastes
			[1072] = 39, -- The Sunset Brewgarden, Dread Wastes
			[1073] = 42, -- Serpent's Spine, Vale of Eternal Blossoms
			[1090] = 43, -- The Briny Muck, Dread Wastes
		},
	},
	{
		tag = "387:601",
		nodeID = 1023,
		name = "Kota Basecamp, Kun-Lai Summit",
		neighbors = {
			[1019] = 59, -- Eastwind Rest, Kun-Lai Summit
			[1020] = 37, -- Westwind Rest, Kun-Lai Summit
			[1022] = 41, -- One Keg, Kun-Lai Summit
			[1024] = 30, -- Shado-Pan Fallback, Kun-Lai Summit
			[1025] = 29, -- Winter's Blossom, Kun-Lai Summit
		},
	},
	{
		tag = "669:272",
		name = "Lion's Landing, Krassarang Wilds",
		neighbors = {
			[966] = 64, -- Paw'Don Village, Jade Forest
			[988] = 45, -- The Incursion, Krasarang Wilds
		},
	},
	{
		tag = "317:571",
		nodeID = 1053,
		name = "Longying Outpost, Townlong Steppes",
		neighbors = {
			[1024] = 41, -- Shado-Pan Fallback, Kun-Lai Summit
			[1025] = 34, -- Winter's Blossom, Kun-Lai Summit
			[1054] = 40, -- Gao-Ran Battlefront, Townlong Steppes
			[1055] = 49, -- Rensai's Watchpost, Townlong Steppes
			[1117] = 30, -- ?
		},
	},
	{
		tag = "527:162",
		nodeID = 993,
		name = "Marista, Krasarang Wilds",
		neighbors = {
			[987] = 61, -- Thunder Cleft, Krasarang Wilds
			[988] = 62, -- The Incursion, Krasarang Wilds
			[990] = 64, -- Dawnchaser Retreat, Krasarang Wilds
			[991] = 86, -- Sentinel Basecamp, Krasarang Wilds
			[992] = 51, -- Cradle of Chi-Ji, Krasarang Wilds
		},
	},
	{
		tag = "466:635",
		nodeID = 1022,
		name = "One Keg, Kun-Lai Summit",
		neighbors = {
			[1017] = 67, -- Binan Village, Kun-Lai Summit
			[1018] = 24, -- Temple of the White Tiger, Kun-Lai Summit
			[1019] = 47, -- Eastwind Rest, Kun-Lai Summit
			[1020] = 56, -- Westwind Rest, Kun-Lai Summit
			[1021] = 59, -- Zouchin Village, Kun-Lai Summit
			[1023] = 52, -- Kota Basecamp, Kun-Lai Summit
		},
	},
	{
		tag = "622:418",
		nodeID = 984,
		name = "Pang's Stead, Valley of the Four Winds",
		neighbors = {
			[895] = 56, -- Dawn's Blossom, Jade Forest
			[985] = 56, -- Halfhill, Valley of the Four Winds
			[986] = 37, -- Zhu's Watch, Krasarang Wilds
			[987] = 65, -- Thunder Cleft, Krasarang Wilds
			[1029] = 29, -- Tavern in the Mists, The Veiled Stair
			[1052] = 25, -- Grassy Cline, Valley of the Four Winds
			[1057] = 86, -- Shrine of Seven Stars, Vale of Eternal Blossoms
			[1058] = 94, -- Shrine of Two Moons, Vale of Eternal Blossoms
		},
	},
	{
		tag = "717:346",
		nodeID = 966,
		name = "Paw'Don Village, Jade Forest",
		neighbors = {
			["669:272"] = 49, -- ?
			[895] = 96, -- Dawn's Blossom, Jade Forest
			[968] = 65, -- Jade Temple Grounds, Jade Forest
			[972] = 38, -- Pearlfin Village, Jade Forest
			[986] = 49, -- Zhu's Watch, Krasarang Wilds
			[1017] = 110, -- Binan Village, Kun-Lai Summit
			[1057] = 131, -- Shrine of Seven Stars, Vale of Eternal Blossoms
		},
	},
	{
		tag = "787:356",
		nodeID = 972,
		name = "Pearlfin Village, Jade Forest",
		neighbors = {
			[895] = 75, -- Dawn's Blossom, Jade Forest
			[966] = 47, -- Paw'Don Village, Jade Forest
			[968] = 37, -- Jade Temple Grounds, Jade Forest
			[1080] = 44, -- Serpent's Overlook, Jade Forest
		},
	},
	{
		tag = "235:501",
		nodeID = 1055,
		name = "Rensai's Watchpost, Townlong Steppes",
		neighbors = {
			[1053] = 49, -- Longying Outpost, Townlong Steppes
			[1054] = 44, -- Gao-Ran Battlefront, Townlong Steppes
			[1056] = 22, -- Shado-Pan Garrison, Townlong Steppes
		},
	},
	{
		tag = "420:275",
		nodeID = 991,
		name = "Sentinel Basecamp, Krasarang Wilds",
		neighbors = {
			[985] = 65, -- Halfhill, Valley of the Four Winds
			[988] = 75, -- The Incursion, Krasarang Wilds
			[989] = 43, -- Stoneplow, Valley of the Four Winds
			[993] = 75, -- Marista, Krasarang Wilds
			[1070] = 74, -- Klaxxi'vess, Dread Wastes
		},
	},
	{
		tag = "700:411",
		nodeID = 1080,
		name = "Serpent's Overlook, Jade Forest",
		neighbors = {
			[895] = 56, -- Dawn's Blossom, Jade Forest
			[972] = 44, -- Pearlfin Village, Jade Forest
		},
	},
	{
		tag = "351:551",
		nodeID = 1117,
		name = "Serpent's Spine, Kun-Lai Summit",
		faction = "H",
		neighbors = {
			[1053] = 22, -- Longying Outpost, Townlong Steppes
			[1054] = 28, -- Gao-Ran Battlefront, Townlong Steppes
			[1058] = 77, -- Shrine of Two Moons, Vale of Eternal Blossoms
		},
	},
	{
		tag = "390:424",
		nodeID = 1073,
		name = "Serpent's Spine, Vale of Eternal Blossoms",
		faction = "B",
		neighbors = {
			[1057] = 71, -- Shrine of Seven Stars, Vale of Eternal Blossoms
			[1058] = 59, -- Shrine of Two Moons, Vale of Eternal Blossoms
			[1070] = 52, -- Klaxxi'vess, Dread Wastes
			[1071] = 73, -- Soggy's Gamble, Dread Wastes
			[1072] = 54, -- The Sunset Brewgarden, Dread Wastes
		},
	},
	{
		tag = "393:530",
		nodeID = 1024,
		name = "Shado-Pan Fallback, Kun-Lai Summit",
		neighbors = {
			[1019] = 45, -- Eastwind Rest, Kun-Lai Summit
			[1020] = 26, -- Westwind Rest, Kun-Lai Summit
			[1023] = 31, -- Kota Basecamp, Kun-Lai Summit
			[1053] = 52, -- Longying Outpost, Townlong Steppes
			[1054] = 38, -- Gao-Ran Battlefront, Townlong Steppes
		},
	},
	{
		tag = "215:524",
		nodeID = 1056,
		name = "Shado-Pan Garrison, Townlong Steppes",
		neighbors = {
			[1055] = 14, -- Rensai's Watchpost, Townlong Steppes
		},
	},
	{
		tag = "541:447",
		nodeID = 1057,
		name = "Shrine of Seven Stars, Vale of Eternal Blossoms",
		neighbors = {
			[1221] = 201, -- ?
			[895] = 170, -- Dawn's Blossom, Jade Forest
			[966] = 124, -- Paw'Don Village, Jade Forest
			[984] = 80, -- Pang's Stead, Valley of the Four Winds
			[985] = 67, -- Halfhill, Valley of the Four Winds
			[1017] = 91, -- Binan Village, Kun-Lai Summit
			[1020] = 64, -- Westwind Rest, Kun-Lai Summit
			[1052] = 63, -- Grassy Cline, Valley of the Four Winds
			[1070] = 114, -- Klaxxi'vess, Dread Wastes
			[1072] = 113, -- The Sunset Brewgarden, Dread Wastes
			[1073] = 69, -- Serpent's Spine, Vale of Eternal Blossoms
			[1115] = 83, -- The Lion's Redoubt, Dread Wastes
		},
	},
	{
		tag = "494:505",
		nodeID = 1058,
		name = "Shrine of Two Moons, Vale of Eternal Blossoms",
		neighbors = {
			[1117] = 84, -- ?
			[895] = 163, -- Dawn's Blossom, Jade Forest
			[973] = 133, -- Honeydew Village, Jade Forest
			[984] = 92, -- Pang's Stead, Valley of the Four Winds
			[985] = 74, -- Halfhill, Valley of the Four Winds
			[1017] = 84, -- Binan Village, Kun-Lai Summit
			[1019] = 67, -- Eastwind Rest, Kun-Lai Summit
			[1052] = 74, -- Grassy Cline, Valley of the Four Winds
			[1070] = 108, -- Klaxxi'vess, Dread Wastes
			[1072] = 107, -- The Sunset Brewgarden, Dread Wastes
			[1073] = 63, -- Serpent's Spine, Vale of Eternal Blossoms
			[1222] = 193, -- Bozzle's Wreck, Isle Of Giants
		},
	},
	{
		tag = "305:281",
		nodeID = 1071,
		name = "Soggy's Gamble, Dread Wastes",
		neighbors = {
			[1070] = 49, -- Klaxxi'vess, Dread Wastes
			[1073] = 81, -- Serpent's Spine, Vale of Eternal Blossoms
			[1090] = 44, -- The Briny Muck, Dread Wastes
		},
	},
	{
		tag = "772:587",
		nodeID = 969,
		name = "Sri-La Village, Jade Forest",
		neighbors = {
			[967] = 50, -- The Arboretum, Jade Forest
			[970] = 21, -- Emperor's Omen, Jade Forest
		},
	},
	{
		tag = "410:335",
		nodeID = 989,
		name = "Stoneplow, Valley of the Four Winds",
		neighbors = {
			["359:225"] = 64, -- ?
			[985] = 46, -- Halfhill, Valley of the Four Winds
			[988] = 61, -- The Incursion, Krasarang Wilds
			[990] = 45, -- Dawnchaser Retreat, Krasarang Wilds
			[991] = 27, -- Sentinel Basecamp, Krasarang Wilds
			[992] = 62, -- Cradle of Chi-Ji, Krasarang Wilds
			[1070] = 64, -- Klaxxi'vess, Dread Wastes
		},
	},
	{
		tag = "586:438",
		nodeID = 1029,
		name = "Tavern in the Mists, The Veiled Stair",
		neighbors = {
			[984] = 22, -- Pang's Stead, Valley of the Four Winds
			[1017] = 38, -- Binan Village, Kun-Lai Summit
			[1052] = 20, -- Grassy Cline, Valley of the Four Winds
		},
	},
	{
		tag = "511:667",
		nodeID = 1018,
		name = "Temple of the White Tiger, Kun-Lai Summit",
		neighbors = {
			[1017] = 75, -- Binan Village, Kun-Lai Summit
			[1019] = 52, -- Eastwind Rest, Kun-Lai Summit
			[1020] = 61, -- Westwind Rest, Kun-Lai Summit
			[1021] = 40, -- Zouchin Village, Kun-Lai Summit
			[1022] = 32, -- One Keg, Kun-Lai Summit
		},
	},
	{
		tag = "782:507",
		nodeID = 967,
		name = "The Arboretum, Jade Forest",
		neighbors = {
			[895] = 26, -- Dawn's Blossom, Jade Forest
			[968] = 31, -- Jade Temple Grounds, Jade Forest
			[969] = 50, -- Sri-La Village, Jade Forest
		},
	},
	{
		tag = "244:324",
		nodeID = 1090,
		name = "The Briny Muck, Dread Wastes",
		neighbors = {
			[1070] = 49, -- Klaxxi'vess, Dread Wastes
			[1071] = 33, -- Soggy's Gamble, Dread Wastes
		},
	},
	{
		tag = "588:277",
		nodeID = 988,
		name = "The Incursion, Krasarang Wilds",
		neighbors = {
			["669:272"] = 64, -- ?
			[985] = 44, -- Halfhill, Valley of the Four Winds
			[989] = 60, -- Stoneplow, Valley of the Four Winds
			[991] = 76, -- Sentinel Basecamp, Krasarang Wilds
			[992] = 76, -- Cradle of Chi-Ji, Krasarang Wilds
			[993] = 63, -- Marista, Krasarang Wilds
		},
	},
	{
		tag = "384:392",
		nodeID = 1115,
		name = "The Lion's Redoubt, Dread Wastes",
		neighbors = {
			[1057] = 81, -- Shrine of Seven Stars, Vale of Eternal Blossoms
		},
	},
	{
		tag = "279:455",
		nodeID = 1072,
		name = "The Sunset Brewgarden, Dread Wastes",
		neighbors = {
			[1054] = 34, -- Gao-Ran Battlefront, Townlong Steppes
			[1057] = 118, -- Shrine of Seven Stars, Vale of Eternal Blossoms
			[1058] = 106, -- Shrine of Two Moons, Vale of Eternal Blossoms
			[1070] = 33, -- Klaxxi'vess, Dread Wastes
			[1073] = 52, -- Serpent's Spine, Vale of Eternal Blossoms
		},
	},
	{
		tag = "554:298",
		nodeID = 987,
		name = "Thunder Cleft, Krasarang Wilds",
		neighbors = {
			[984] = 61, -- Pang's Stead, Valley of the Four Winds
			[985] = 34, -- Halfhill, Valley of the Four Winds
			[986] = 39, -- Zhu's Watch, Krasarang Wilds
			[990] = 80, -- Dawnchaser Retreat, Krasarang Wilds
			[993] = 71, -- Marista, Krasarang Wilds
		},
	},
	{
		tag = "703:583",
		nodeID = 971,
		name = "Tian Monastery, Jade Forest",
		neighbors = {
			[894] = 66, -- Grookin Hill, Jade Forest
			[895] = 42, -- Dawn's Blossom, Jade Forest
			[970] = 22, -- Emperor's Omen, Jade Forest
			[973] = 54, -- Honeydew Village, Jade Forest
		},
	},
	{
		tag = "959:296",
		nodeID = 1293,
		name = "Tushui Landing, Timeless Isle",
		neighbors = {
			[895] = 142, -- Dawn's Blossom, Jade Forest
		},
	},
	{
		tag = "446:549",
		nodeID = 1020,
		name = "Westwind Rest, Kun-Lai Summit",
		neighbors = {
			[1017] = 45, -- Binan Village, Kun-Lai Summit
			[1018] = 63, -- Temple of the White Tiger, Kun-Lai Summit
			[1021] = 97, -- Zouchin Village, Kun-Lai Summit
			[1022] = 47, -- One Keg, Kun-Lai Summit
			[1023] = 38, -- Kota Basecamp, Kun-Lai Summit
			[1024] = 27, -- Shado-Pan Fallback, Kun-Lai Summit
			[1057] = 65, -- Shrine of Seven Stars, Vale of Eternal Blossoms
		},
	},
	{
		tag = "344:637",
		nodeID = 1025,
		name = "Winter's Blossom, Kun-Lai Summit",
		neighbors = {
			[1023] = 27, -- Kota Basecamp, Kun-Lai Summit
			[1053] = 34, -- Longying Outpost, Townlong Steppes
		},
	},
	{
		tag = "623:341",
		nodeID = 986,
		name = "Zhu's Watch, Krasarang Wilds",
		neighbors = {
			[966] = 40, -- Paw'Don Village, Jade Forest
			[984] = 34, -- Pang's Stead, Valley of the Four Winds
			[985] = 47, -- Halfhill, Valley of the Four Winds
			[987] = 43, -- Thunder Cleft, Krasarang Wilds
			[1017] = 87, -- Binan Village, Kun-Lai Summit
		},
	},
	{
		tag = "490:739",
		nodeID = 1021,
		name = "Zouchin Village, Kun-Lai Summit",
		neighbors = {
			[1018] = 44, -- Temple of the White Tiger, Kun-Lai Summit
			[1019] = 82, -- Eastwind Rest, Kun-Lai Summit
			[1020] = 93, -- Westwind Rest, Kun-Lai Summit
			[1022] = 62, -- One Keg, Kun-Lai Summit
			[1222] = 52, -- Bozzle's Wreck, Isle Of Giants
			[1221] = 50, -- ?
		},
	},
}

