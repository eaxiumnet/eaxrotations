local name,addon = ...

addon.LibRoverData = addon.LibRoverData or {}
local data=addon.LibRoverData

data.version={
	nodes_version = 90, -- Increase this when working on the nodes. Connections will be baked automatically when committing.
}

-- These are kept strictly unique. Make up bogus names if you need to.
-- If multiple numbers are given, then only the first one is used here; others are used by Pointer to define phasedMaps.

data.MapIDsByName = {

--World Zones
["Azeroth"] = {[0]=947},
["Cosmic"] = {[0]=946},
["Eastern Kingdoms"] = {[0]=13},
["Kalimdor"] = {[0]=12},
["Northrend"] = {[0]=113},
["Outland"] = {[0]=1467},
["Pandaria"] = {[0]=424},
["The Maelstrom Continent"] = {[0]=948},


-------------------------------------
------- EASTERN KINGDOMS -------
-------------------------------------

["Abyssal Depths"] = {[0]=204},
["Alterac Valley"] = {[0]=91},
["Arathi Highlands"] = {[0]=14},
["Blasted Lands"] = {[0]=17},
["Burning Steppes"] = {[0]=36,[14]=33,[15]=34,[16]=35}, -- bfa alpha 14,15,16 were marked as searing gorge
["The Cape of Stranglethorn"] = {[0]=210},
["Coldridge Valley"] = {[0]=427,[9]=428},
["Deadwind Pass"] = {[0]=42}, --,[21]=41,[22]=43,[23]=44,[24]=45,[27]=46
["Deeprun Tram"] = {[1]=499,[2]=500},
["Dun Morogh"] = {[0]=27,[6]=28,[7]=29,[10]=30,[11]=31},
["Duskwood"] = {[0]=47},
["Eastern Plaguelands"] = {[0]=23}, --,[20]=24
["Elwynn Forest"] = {[0]=37,[1]=38,[2]=39,[19]=40},
["Hillsbrad Foothills"] = {[0]=25},
["The Hinterlands"] = {[0]=26},
["Ironforge"] = {[0]=87},
["Kelp'thar Forest"] = {[0]=201},
["Loch Modan"] = {[0]=48},
["New Tinkertown"] = {[0]=469,[8]=470},
["Northern Stranglethorn"] = {[0]=50},
["Northshire"] = {[0]=425,[3]=426},
["Redridge Mountains"] = {[0]=49},
["Searing Gorge"] = {[0]=32,},
["Shimmering Expanse"] = {[0]=205},
["Stormwind City"] = {[0]=84},
["Stranglethorn Vale"] = {[0]=224},
["Swamp of Sorrows"] = {[0]=51},
["Twilight Highlands"] = {[0]=241},
["Vashj'ir"] = {[0]=203},
["Western Plaguelands"] = {[0]=22},
["Westfall"] = {[0]=52,[4]=53,[5]=54,[17]=55},
["Wetlands"] = {[0]=56},

--Kalimdor
["Ahn'Qiraj: The Fallen Kingdom"] = {[0]=327},
["Ammen Vale"] = {[0]=468},
["Ashenvale"] = {[0]=63},
["Azshara"] = {[0]=76},
["Azuremyst Isle"] = {[0]=97,[2]=98,[3]=99},
["Badlands"] = {[0]=15,[18]=16},
["Bloodmyst Isle"] = {[0]=106},
["Camp Narache"] = {[0]=462},
["Darkshore"] = {[0]=62},
["Darnassus"] = {[0]=89},
["Deathknell"] = {[0]=465,[12]=466},
["Desolace"] = {[0]=66,[21]=67,[22]=68},
["Durotar"] = {[0]=1,[8]=2,[10]=3,[11]=4,[12]=5,[19]=6},
["Dustwallow Marsh"] = {[0]=70},
["Echo Isles"] = {[0]=463,[9]=464},
["Eversong Woods"] = {[0]=94},
["The Exodar"] = {[0]=103},
["Felwood"] = {[0]=77},
["Feralas"] = {[0]=69},
["Ghostlands"] = {[0]=95,[1]=96},
["Gilneas"] = {[0]=179,[1]=180,[2]=181,[3]=182},
["Gilneas City"] = {[0]=202},
["The Lost Isles"] = {[0]=174,[1]=175,[2]=176,[3]=177,[4]=178},
["Kezan"] = {[0]=194,[5]=195,[6]=196,[7]=197},
["Moonglade"] = {[0]=80},
["Mulgore"] = {[0]=7,[6]=8,[7]=9},
["The Barrens"] = {[0]=10,[20]=11},
["Orgrimmar"] = {[1]=85,[2]=86},
["Shadowglen"] = {[0]=460},
["Silithus"] = {[0]=81,[13]=82},
["Silvermoon City"] = {[0]=110},
["Silverpine Forest"] = {[0]=21},
["Southern Barrens"] = {[0]=199},
["Stonetalon Mountains"] = {[0]=65},
["Sunstrider Isle"] = {[0]=467},
["Tanaris"] = {[0]=71,[15]=72,[16]=73,[17]=74,[18]=75},
["Teldrassil"] = {[0]=57,[2]=58,[3]=59,[4]=60,[5]=61},
["Thousand Needles"] = {[0]=64},
["Thunder Bluff"] = {[0]=88},
["Tirisfal Glades"] = {[0]=18,[13]=19}, --,[25]=20
["Uldum"] = {[0]=249},
["Un'Goro Crater"] = {[0]=78,[14]=79},
["Undercity"] = {[0]=998},
["Valley of Trials"] = {[0]=461},
["Winterspring"] = {[0]=83},


--Outlands
["Blade's Edge Mountains"] = {[0]=105},
["Hellfire Peninsula"] = {[0]=100},
["Nagrand"] = {[0]=107},
["Netherstorm"] = {[0]=109},
["Shadowmoon Valley"] = {[0]=104},
["Shattrath City"] = {[0]=111},
["Terokkar Forest"] = {[0]=108},
["Zangarmarsh"] = {[0]=102},

--Northrend
["Borean Tundra"] = {[0]=114},
["Crystalsong Forest"] = {[0]=127},
["Dalaran"] = {[1]=125,[2]=126},
["Dragonblight"] = {[0]=115},
["Grizzly Hills"] = {[0]=116},
["Howling Fjord"] = {[0]=117},
["Hrothgar's Landing"] = {[0]=170},
["Icecrown"] = {[0]=118},
["Sholazar Basin"] = {[0]=119},
["The Storm Peaks"] = {[0]=120},
["Zul'Drak"] = {[0]=121},
 
 --Pandaria
["Dread Wastes"] = {[0]=422},
["Isle of Giants"] = {[0]=507},
["The Jade Forest"] = {[0]=371,[6]=372,[7]=373,[15]=374,[16]=375},
["Krasarang Wilds"] = {[0]=418,[1]=419,[2]=420,[3]=421},
["Kun-Lai Summit"] = {[0]=379,[8]=380,[9]=381,[10]=382,[11]=383,[12]=384,[17]=385,[20]=386,[21]=387},
["Shrine of Seven Stars"] = {[1]=393,[2]=394}, 
["Shrine of Two Moons"] = {[1]=391,[2]=392},
["Timeless Isle"] = {[0]=554,[22]=555},
["Townlong Steppes"] = {[0]=388,[13]=389},
["Vale of Eternal Blossoms"] = {[0]=390,[1]=395,[2]=396},
["Valley of the Four Winds"] = {[0]=376,[14]=377},
["The Veiled Stair"] = {[0]=433,[5]=434},
["Dalaran P"] = {[0]=501},
["Dalaran P Sewers"] = {[0]=502},

--Dungeons
["Old Scholomance"] = {[3]=306,[2]=307,[1]=308,[0]=309},
["Ahn'kahet: The Old Kingdom"] = {[1]=132},
["Ahn'Qiraj"] = {[1]=319,[2]=320,[3]=321},
["The Arcatraz"] = {[1]=269,[2]=270,[3]=271},
["Auchenai Crypts"] = {[1]=256,[2]=257},
["Azjol-Nerub"] = {[1]=157,[2]=158,[3]=159},
["The Black Morass"] = {[0]=273},
["Blackfathom Deeps"] = {[1]=221,[2]=222,[3]=223},
["Blackrock Caverns"] = {[1]=283,[2]=284},
["Blackrock Depths"] = {[1]=242,[2]=243},
["Blackrock Spire"] = {[1]=250,[2]=251,[3]=252,[4]=253,[5]=254,[6]=255},
["The Blood Furnace"] = {[1]=261},
["The Botanica"] = {[1]=266},
["The Culling of Stratholme"] = {[1]=130,[2]=131},
["The Deadmines"] = {[1]=291,[2]=292},
["Dire Maul"] = {[0]=234,[1]=235,[2]=236,[3]=237,[4]=238,[5]=239,[6]=240},
["Drak'Tharon Keep"] = {[1]=160,[2]=161},
["End Time"] = {[1]=401,[2]=402,[3]=403,[4]=404,[5]=405,[6]=406},
["The Forge of Souls"] = {[1]=183},
["Gate of the Setting Sun"] = {[1]=437,[2]=438},
["Gnomeregan"] = {[1]=226,[2]=227,[3]=228,[4]=229},
["Grim Batol"] = {[1]=293},
["Gundrak"] = {[0]=153,[1]=154},
["Halls of Lightning"] = {[1]=138,[2]=139},
["Halls of Origination"] = {[1]=297,[2]=298,[3]=299},
["Halls of Reflection"] = {[1]=185},
["Halls of Stone"] = {[1]=140},
["HoS Heritage"] = {[1]=1375},
["Hellfire Ramparts"] = {[1]=347},
["Hour of Twilight"] = {[1]=399,[2]=400},
["Lost City of the Tol'vir"] = {[0]=277},
["Magisters' Terrace"] = {[1]=348,[2]=349},
["Mana-Tombs"] = {[1]=272},
["Maraudon"] = {[1]=280,[2]=281},
["The Mechanar"] = {[1]=267,[2]=268},
["Mogu'shan Palace"] = {[1]=453,[2]=454,[3]=455},
["The Nexus"] = {[1]=129},
["The Oculus"] = {[0]=142,[1]=143,[2]=144,[3]=145,[4]=146},
["Old Hillsbrad Foothills"] = {[0]=274},
["Pit of Saron"] = {[0]=184},
["Ragefire Chasm"] = {[1]=213},
["Razorfen Downs"] = {[1]=300},
["Razorfen Kraul"] = {[1]=301},
["Scarlet Halls"] = {[1]=431,[2]=432},
["Scarlet Monastery"] = {[1]=302,[2]=303,[3]=304,[4]=305},
["Scholomance"] = {[1]=476,[2]=477,[3]=478,[4]=479},
["Sethekk Halls"] = {[1]=258,[2]=259},
["Shado-Pan Monastery"] = {[1]=443,[2]=444,[3]=445,[4]=446},
["Shadow Labyrinth"] = {[1]=260},
["Shadowfang Keep"] = {[1]=310,[2]=311,[3]=312,[4]=313,[5]=314,[6]=315,[7]=316},
["The Shattered Halls"] = {[1]=246},
["Siege of Niuzao Temple"] = {[1]=457,[2]=458,[3]=459},
["The Slave Pens"] = {[1]=265},
["The Steamvault"] = {[1]=263,[2]=264},
["The Stockade"] = {[1]=225},
["The Stonecore"] = {[1]=324},
["Stormstout Brewery"] = {[1]=439,[2]=440,[3]=441,[4]=442},
["Stratholme"] = {[1]=317,[2]=318},
["The Temple of Atal'Hakkar"] = {[1]=220},
["Temple of the Jade Serpent"] = {[1]=429,[2]=430},
["Throne of the Tides"] = {[1]=322,[2]=323},
["Trial of the Champion"] = {[1]=171},
["Uldaman"] = {[1]=230,[2]=231},
["The Underbog"] = {[1]=262},
["Utgarde Keep"] = {[1]=133,[2]=134,[3]=135},
["Utgarde Pinnacle"] = {[1]=136,[2]=137},
["The Violet Hold"] = {[1]=168},
["The Vortex Pinnacle"] = {[1]=325},
["Wailing Caverns"] = {[1]=279},
["Well of Eternity"] = {[0]=398},
["Zul'Aman"] = {[0]=333},
["Zul'Farrak"] = {[0]=219},
["Zul'Gurub"] = {[0]=337},


--Raids
["Baradin Hold"] = {[1]=282},
["The Bastion of Twilight"] = {[1]=294,[2]=295,[3]=296},
["Black Temple"] = {[1]=339,[2]=340,[3]=341,[4]=342,[5]=343,[6]=344,[7]=345,[8]=346},
["Black Temple B"] = {[0]=490,[1]=491,[2]=492,[3]=493,[4]=494,[5]=495,[6]=496,[7]=497,},
["Blackwing Descent"] = {[1]=285,[2]=286},
["Blackwing Lair"] = {[1]=287,[2]=288,[3]=289,[4]=290},
["Dragon Soul"] = {[1]=409,[2]=410,[3]=411,[4]=412,[5]=413,[6]=414,[7]=415},
["The Eye of Eternity"] = {[1]=141},
["Firelands"] = {[0]=367,[1]=368,[3]=369},
["Gruul's Lair"] = {[1]=330},
["Heart of Fear"] = {[1]=474,[2]=475},
["Hyjal Summit"] = {[0]=329},
["Icecrown Citadel"] = {[1]=186,[2]=187,[3]=188,[4]=189,[5]=190,[6]=191,[7]=192,[8]=193},
["Karazhan"] = {[1]=350,[2]=351,[3]=352,[4]=353,[5]=354,[6]=355,[7]=356,[8]=357,[9]=358,[10]=359,[11]=360,[12]=361,[13]=362,[14]=363,[15]=364,[16]=365,[17]=366},
["Magtheridon's Lair"] = {[1]=331},
["Mogu'shan Vaults"] = {[1]=471,[2]=472,[3]=473},
["Molten Core"] = {[1]=232},
["Mount Hyjal"] = {[0]=198},
["Naxxramas"] = {[1]=162,[2]=163,[3]=164,[4]=165,[5]=166,[6]=167},
["The Obsidian Sanctum"] = {[0]=155},
["Onyxia's Lair"] = {[1]=248},
["The Ruby Sanctum"] = {[0]=200},
["Ruins of Ahn'Qiraj"] = {[0]=247},
["Serpentshrine Cavern"] = {[1]=332},
["Siege of Orgrimmar"] = {[0]=556,[1]=557,[2]=558,[3]=559,[4]=560,[5]=561,[6]=562,[7]=563,[8]=564,[9]=565,[10]=566,[11]=567,[12]=568,[13]=569,[14]=570},
["Sunwell Plateau"] = {[1]=335,[2]=336},
["Tempest Keep"] = {[1]=334},
["Terrace of Endless Spring"] = {[0]=456},
["Throne of the Four Winds"] = {[1]=328},
["Throne of Thunder"] = {[1]=508,[2]=509,[3]=510,[4]=511,[5]=512,[6]=513,[7]=514,[8]=515},
["Trial of the Crusader"] = {[1]=172,[2]=173},
["Ulduar"] = {[1]=147,[2]=148,[3]=149,[4]=150,[5]=151,[6]=152},
["Vault of Archavon"] = {[1]=156},

--Scenarios
["Assault on Zan'vess"] = {[0]=451},
["Battle on the High Seas"] = {[0]=524},
["A Brewing Storm"] = {[0]=447},
["Blood in the Snow"] = {[0]=523},
["Brewmoon Festival"] = {[0]=452},
["Celestial Tournament"] = {[0]=571},
["Crypt of Forgotten Kings"] = {[1]=481,[2]=482},
["Dagger in the Dark"] = {[0]=488,[1]=489},
["Dark Heart of Pandaria"] = {[0]=520,[1]=521},
["Domination Point"] = {[0]=498},
["Greenstone Village"] = {[0]=448},
["Lion's Landing"] = {[0]=486},
["A Little Patience"] = {[0]=487},
["Proving Grounds"] = {[1]=480},
["The Secrets of Ragefire"] = {[1]=522},
["Theramore's Fall"] = {[0]=483},
["Theramore's Fall H"] = {[0]=416},
["Unga Ingoo"] = {[0]=450},
["Thunder King's Citadel"]={[0]=518},



--Battlegrounds
["Arathi Basin"] = {[0]=93},
["Eye of the Storms"] = {[0]=112,[1]=397},
["Isle of Conquest"] = {[0]=169},
["Silvershard Mines"] = {[1]=423},
["Strand of the Ancients"] = {[0]=128},
["Twin Peaks"] = {[0]=206},
["Warsong Gulch"] = {[0]=92},
["Deepwind Gorge"] = {[0]=519,},


--Instanced Zones/Misc
["Brawl'gar Arena"] = {[1]=503},
["Deepholm"] = {[0]=207,[1]=208,[2]=209},
["Isle of Quel'Danas"] = {[0]=122},
["Isle of Thunder"] = {[0]=504,[1]=505,[2]=506},
["The Maelstrom"] = {[0]=276}, -- deepholm intro scenario, among others
["Molten Front"] = {[0]=338},
["Plaguelands: The Scarlet Enclave"] = {[0]=124},
["Ruins of Gilneas"] = {[0]=217},
["Ruins of Gilneas City"] = {[0]=218},
["Tol Barad"] = {[0]=244},
["Tol Barad Peninsula"] = {[0]=245},
["The Wandering Isle"] = {[0]=378},
["Wintergrasp"] = {[0]=123},

["Isle of Thunder Scenario"] = {[0]=516,[1]=517,[2]=517},

["Temple of Kotmogu"] = {[0]=417,[1]=449,},
["The Battle for Gilneas"] = {[0]=275,},
["Zul'Gurub"] = {[0]=233,},

["The Nexus Scenario"] = {[0] = 370},

["Darkmoon Island"] = {[0]=407,[1]=408},
}










data.MapNamesByID = {}
data.FloorByID = {}
data.MapGroupIDs = {}
data.InstanceMaps = {}
data.InstanceMapsRev = {}
data.InstanceMapsContinents = {}
data.DungeonMaps = {} -- This is used by |goto implementation to detect which maps cannot be positioned anymore.
for mapname,mapdata in pairs(data.MapIDsByName) do 
	for floornum,floormap in pairs(mapdata) do
		if floornum~="default" then
			data.MapNamesByID[floormap] = {mapname,floornum}
			data.FloorByID[floormap] = floornum
			data.MapGroupIDs[floormap] = mapname
		end
	end
	if mapdata.instance then
		data.InstanceMaps[mapdata.instance] = mapdata[0]
		data.InstanceMapsRev[mapdata[0]] = mapdata.instance
		data.InstanceMapsContinents[mapdata[0]] = mapdata.c
		data.DungeonMaps[mapdata[0]] = true
	end
end

-- /run D={} for i=1,1000 do pcall(EJ_SelectInstance,i) local _, _, _, _, _, _, dungeonMapId, _ = EJ_GetInstanceInfo() D[dungeonMapId or 0]=true end ZGV:ShowDump(ZGV:Serialize(D),"")
-- This is used by |goto implementation to detect which maps cannot be positioned anymore.
data.DungeonMaps = {
}


--[[
	YE OLDE HELP TEXT

	Okay, to clarify, there's multiple ways to write a map link now. It's a mess, but it works.

	The first, simplest way, is two nodes linked, written in plain text (let's hope they're accessible by some means):
		"First Zone/2 11.22,33.44 -x- Second Zone/3 55.66,77.88",

	The "-x-" means it's a crossing, two-way. You can use "-to-" to make a one-way link.


	NODE NAMES:

	Adding @something after the node coordinates gives the node a name, for later reuse.
		"Stormwind 11.22,33.44 -x- Elwynn Forest 55.66,77.88 @stormgate",
		"Elwynn 77.77,66.66 -x- @stormgate",

	You can also use @+ to indicate the last node created or mentioned, whether it was named or not.
		"Stormwind 11.22,33.44 -x- Elwynn Forest 55.66,77.88",
		"@+ -x- Elwynn 77.77,66.66",

	This allows for easy chaining of nodes.


	ONE NODE?

	You can create just one node:
		"Solitary 11.1,22.2"

	This only makes sense if you @+ link to it later, or give it an explicit @name and refer to that.


	ADDITIONAL NODE DATA:

	Writing <field:value> after a node's coordinates assigns additional data.
		"Stormwind 11.1,22.2 <title:Watch out, dog poo> <radius:5>"

	Data fields include (among others):
		'title' to caption a node,
		'radius' to set the node's player-detection radius,
		'region' to assign a node to a special region,
		'nofly' set to 1 means the node cannot be flown to,
		'dark' set to 1 means the node can only be seen by the player from a small distance, but suffers no penalty when chained between other nodes


	ADDITIONAL LINK DATA:

	Writing {field:value} after both nodes assigns data to their link:
		"Stormwind 11.1,22.2 -x- Elwynn Forest 55.5,66.6 {cost:999}" -- this is a very time-costly connection


	ADVANCED FORMAT:

	If that's not enough, you can use a "raw" format to write node links:
		{ "@+" , "Orgrimmar/1 11.1,22.2" , template="portalauto", faction="H", cost=123 }

	Within that, you can go even deeper and write the node(s) in raw mode, too:
		{ "@+" , {"Orgrimmar/1 11.1,22.2",title="Something in Orgri",region="whatever"} , oneway=1 }

	Very advanced, messy, "fake zone"-based mapping (Maraudon the Zone of Nightmares) makes extensive use of that.

--]]


data.basenodes = {}

data.basenodes.setup = {
	--"REGION fuselightbtspre Badlands 79.1,31.6 <150",
}



--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---		GREEN BORDERS		GREEN BORDERS		GREEN BORDERS		GREEN BORDERS		GREEN BORDERS		GREEN BORDERS		GREEN BORDERS		GREEN BORDERS		GREEN BORDERS  ---
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- These zone pairs see directly into each other, as they share "green" borders.
data.greenborders = {
--------------
-- KALIMDOR --
--------------
-- Orgrimmar
	{"Orgrimmar/1","Orgrimmar/2"},
	
	
	
-- Main Zone Borders
	{"Echo Isles/0","Durotar/0"},

-- Durotar
	{"Durotar/0","Durotar/10"},
	{"Durotar/0","Durotar/11"},
	{"Durotar/10","Durotar/11"},





----------------------
-- EASTERN KINGDOMS --
----------------------

-- Main Zone Borders
	{"Elwynn Forest/0","Duskwood/0"},
	{"Westfall/0","Duskwood/0"},
	{"Eversong Woods/0","Ghostlands/0"},
	{"Elwynn Forest/0","Westfall/0"},

-- Ghostlands
	{"Ghostlands/0","Ghostlands/1"},

-- Worgen
	{"Gilneas/0","Gilneas/2"},
	{"Gilneas/0","Gilneas/3"},
	{"Gilneas/2","Gilneas/3"},
	{"Gilneas/0","Gilneas City/0"},





---------------
-- CATACLYSM --
---------------

-- Main Zone Borders
	{"Kelp'thar Forest/0","Shimmering Expanse/0"},
	{"Shimmering Expanse/0","Abyssal Depths/0"},
	{"Abyssal Depths/0","Kelp'thar Forest/0"},

-- Deepholm
	{"Deepholm/1","Deepholm/2"},





---------------
-- PANDARIA --
---------------
	{"Kun-Lai Summit/11","Kun-Lai Summit/12"},
	{"The Jade Forest/6","The Jade Forest/7"},
	{"The Jade Forest/0","The Jade Forest/15"},
	{"The Jade Forest/0","The Jade Forest/16"},
	{"Vale of Eternal Blossoms/0","Shrine of Seven Stars/1"},
	{"Vale of Eternal Blossoms/0","Shrine of Seven Stars/2"},
	{"Shrine of Seven Stars/1","Shrine of Seven Stars/2"},
	{"Vale of Eternal Blossoms/0","Shrine of Two Moons/1"},
	{"Vale of Eternal Blossoms/0","Shrine of Two Moons/2"},
	{"Shrine of Two Moons/1","Shrine of Two Moons/2"},





}









data.walls = {
	["Tirisfal Glades"] = {
		{ 48.8,50.9, 50.8,50.7, 51.0,56.1, 48.2,56.4, "loop" }, -- Calston Lake (example)
	},
	["Eastern Plaguelands"] = {
		{ 90.3,0.1, 84.7,38.2, 80.8,54.1, 84.3,71.8 }, -- wall off Scarlet Enclave
	},
	["The Maw"] = {
		{ 46.81,54.61, 54.80,53.86, 64.80,16.40 }, -- top cutoff of southeast part
		{ 42.18,65.04, 42.51,85.87, 47.10,91.90 }, -- bottom cutoff of southeast part
	},
}

data.ZoneMeta = {
	["ALL_MICROS"] = {hostile=true},

	["Orgrimmar/2"] = {flyable=true}, -- Cleft of Shadow
	["Razorfen Kraul"]={dark=1},
	["Caverns of Time"] = {hostile=false},
	["Deeprun Tram/1"] = {hostile=false},
	["Deeprun Tram/2"] = {hostile=false},
	[831] = {hostile=false},
	[886] = {hostile=false},
	[883] = {hostile=false},

	["The Exodar/0"] = {flyable=false},
	["Azuremyst Isle/0"] = {flyable=false},
	["Azuremyst Isle/2"] = {flyable=false},
	["Azuremyst Isle/3"] = {flyable=false},
	["Bloodmyst Isle/0"] = {flyable=false},
	["Ammen Vale/0"] = {flyable=false},
	["Silvermoon City/0"] = {flyable=false},
	["Ghostlands/0"] = {flyable=false},
	["Ghostlands/1"] = {flyable=false},
	["Eversong Woods/0"] = {flyable=false},
	["Sunstrider Isle/0"] = {flyable=false},
	

	["Vashj'ir/0"] = {vashjir=true},
	["Shimmering Expanse/0"] = {vashjir=true},
	["Kelp'thar Forest/0"] = {vashjir=true},
	["Abyssal Depths/0"] = {vashjir=true},

	["Tol Barad/0"] = {flyable=false},
	["Tol Barad Peninsula/0"] = {flyable=false},

	["Shrine of Seven Stars/1"] = {flyable=true}, 
	["Shrine of Seven Stars/2"] = {flyable=true}, 
	["Shrine of Two Moons/1"] = {flyable=true}, 
	["Shrine of Two Moons/2"] = {flyable=true}, 

	--["The Timeways/0"] = {routable=true},

} -- Gets numberized and setmetatable-ized in lib code.

--[[
data.ZoneMeta[614].level=80 -- 3 sub zones in Vashj'ir that returned 0 as their level... Thank you blizzard. They're just subzones of Vashj'ir #613.
data.ZoneMeta[615].level=80
data.ZoneMeta[610].level=80
data.ZoneMeta[499].level=65 -- Isle of Quel'Danas. Had 0 for whatever reason but FP is learned automatically at 65
--Panda Land Levels hardcoded until GetCurrentMapLevelRange() works for them.
data.ZoneMeta[873].level=87
data.ZoneMeta[929].level=90
--]]

--[[
TaxiWhistlePredictor valid maps
[123] = true,
[123] = 11111, -- whistle valid if quest completed
[123]={11111,22222} -- whistle valid if any quest completed
--]]
data.WhistleMaps = {}



-- force areas of map1 to be treated as if player was on target map. useful when blizz map detection fails and gives us continent instead of local map. 
data.RemapData = {
	-- source map = ractange based on y,x = unitposition, target map to remap coords to
	-- use ZGV.Testing.remap_dump to grab this
	[12] = {
		{top=2098.349609375, bottom=1833.2788085938, left=-4810.2495117188, right=-5487.0249023438, target=85},
	},
	[13] = {
	},
	[18] = { -- tirisfal glades
		{left=1700, right=1640, top=1685, bottom=1600, target=465}, -- Deathknell crypt, Undead starter
	}
}
