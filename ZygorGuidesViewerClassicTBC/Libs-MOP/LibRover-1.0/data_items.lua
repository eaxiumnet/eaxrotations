local name,addon = ...

addon.LibRoverData = addon.LibRoverData or {}
local ZGV=addon
local data=addon.LibRoverData

local IsQuestFlaggedCompleted = C_QuestLog.IsQuestFlaggedCompleted

-- "_HEARTH" or "_G_HEARTH" destinations are not parsed immediately; they get assigned at calculation time.

local hearthcost = 30
local otheritem = 30
data.portkeys = { -- smile if you're a muggle

	{item=6948, destination="_HEARTH", cost=hearthcost, mode="hearth"}, -- Hearthstone!!!

	{item=64488, destination="_HEARTH", cost=hearthcost, toy=true, mode="hearth"}, -- The Innkeeper's Daughter
	{item=142542, destination="_HEARTH", cost=hearthcost, toy=true, mode="hearth"}, -- Tome of Town Portal

	{item=162973, destination="_HEARTH", cost=hearthcost, toy=true, mode="hearth"}, -- Greatfather Winter's Hearthstone
	{item=163045, destination="_HEARTH", cost=hearthcost, toy=true, mode="hearth"}, -- Headless Horseman's Hearthstone
	{item=165669, destination="_HEARTH", cost=hearthcost, toy=true, mode="hearth"}, -- Lunar Elder's Hearthstone
	{item=165670, destination="_HEARTH", cost=hearthcost, toy=true, mode="hearth"}, -- Peddlefeet's Lovely Hearthstone
	{item=165802, destination="_HEARTH", cost=hearthcost, toy=true, mode="hearth"}, -- Noble Gardeners Hearthstone
	{item=166746, destination="_HEARTH", cost=hearthcost, toy=true, mode="hearth"}, -- Fire Eater's Hearthstone
	{item=166747, destination="_HEARTH", cost=hearthcost, toy=true, mode="hearth"}, -- Brewfest Revelers Hearthstone
	{item=168907, destination="_HEARTH", cost=hearthcost, toy=true, mode="hearth"}, -- Holographic Digitalization Hearthstone
	{item=172179, destination="_HEARTH", cost=hearthcost, toy=true, mode="hearth"}, -- Eternal Traveler's Hearthstone
	{item=193588, destination="_HEARTH", cost=hearthcost, toy=true, mode="hearth"}, -- Timewalker's Hearthstone
	{item=209035, destination="_HEARTH", cost=hearthcost, toy=true, mode="hearth"}, -- Hearthstone of the Flame
	{item=208704, destination="_HEARTH", cost=hearthcost, toy=true, mode="hearth"}, -- Deepdweller's Earthen Hearthstone
	{item=188952, destination="_HEARTH", cost=hearthcost, toy=true, mode="hearth"}, -- Dominated Hearthstone
	{item=190196, destination="_HEARTH", cost=hearthcost, toy=true, mode="hearth"}, -- Enlightened Hearthstone
	{item=200630, destination="_HEARTH", cost=hearthcost, toy=true, mode="hearth"}, -- Ohn'ir Windsage's Hearthstone
	{item=228940, destination="_HEARTH", cost=hearthcost, toy=true, mode="hearth"}, -- Notorious Thread's Hearthstone

	{item=28585, destination="_HEARTH", cost=hearthcost, mode="hearth"}, -- Ruby Slippers
	{item=37118, destination="_HEARTH", cost=hearthcost, maxlevel=49}, -- Scroll of Recall 1 DIFFERENT HEARTHSTONE CD level <= 40	--Cost a little different so that lower level ones get priority if usable.
	{item=44314, destination="_HEARTH", cost=hearthcost, maxlevel=49}, -- Scroll of Recall 2 DIFFERENT HEARTHSTONE CD level >=35 <= 70
	{item=44315, destination="_HEARTH", cost=hearthcost, maxlevel=49}, -- Scroll of Recall 3 DIFFERENT HEARTHSTONE CD level >=65 <= 90

	{spell=556, destination="_HEARTH", cost=hearthcost, is_astral=1 }, -- Astral Recall

	{item=63352, destination="@!sw_tp_dst", cost=otheritem, cooldown=28800}, -- Shroud of Cooperation
	{item=63206, destination="@!sw_tp_dst", cost=otheritem, cooldown=14400}, -- Wrap of Unity
	{item=65360, destination="@!sw_tp_dst", cost=otheritem, cooldown=7200}, -- Cloak of Cooperation

	{item=63353, destination="@!org_tp_dst", cost=otheritem, cooldown=28800}, -- Shroud of Cooperation
	{item=63207, destination="@!org_tp_dst", cost=otheritem, cooldown=14400}, -- Wrap of Unity
	{item=65274, destination="@!org_tp_dst", cost=otheritem, cooldown=7200}, -- Cloak of Cooperation

	{item=40585, destination="@!dala_tp_dst", cost=otheritem, cooldown=1800}, -- Signet of the Kirin Tor
	{item=40586, destination="@!dala_tp_dst", cost=otheritem, cooldown=1800}, -- Band of the Kirin Tor
	{item=44934, destination="@!dala_tp_dst", cost=otheritem, cooldown=1800}, -- Loop of the Kirin Tor
	{item=44935, destination="@!dala_tp_dst", cost=otheritem, cooldown=1800}, -- Ring of the Kirin Tor
	{item=45688, destination="@!dala_tp_dst", cost=otheritem, cooldown=1800}, -- Inscribed Band of the Kirin Tor
	{item=45689, destination="@!dala_tp_dst", cost=otheritem, cooldown=1800}, -- Inscribed Loop of the Kirin Tor
	{item=45690, destination="@!dala_tp_dst", cost=otheritem, cooldown=1800}, -- Inscribed Ring of the Kirin Tor
	{item=45691, destination="@!dala_tp_dst", cost=otheritem, cooldown=1800}, -- Inscribed Signet of the Kirin Tor
	{item=48954, destination="@!dala_tp_dst", cost=otheritem, cooldown=1800}, -- Etched Band of the Kirin Tor
	{item=48955, destination="@!dala_tp_dst", cost=otheritem, cooldown=1800}, -- Etched Loop of the Kirin Tor
	{item=48956, destination="@!dala_tp_dst", cost=otheritem, cooldown=1800}, -- Etched Ring of the Kirin Tor
	{item=48957, destination="@!dala_tp_dst", cost=otheritem, cooldown=1800}, -- Etched Signet of the Kirin Tor
	{item=51557, destination="@!dala_tp_dst", cost=otheritem, cooldown=1800}, -- Runed Signet of the Kirin Tor
	{item=51558, destination="@!dala_tp_dst", cost=otheritem, cooldown=1800}, -- Runed Loop of the Kirin Tor
	{item=51559, destination="@!dala_tp_dst", cost=otheritem, cooldown=1800}, -- Runed Ring of the Kirin Tor
	{item=51560, destination="@!dala_tp_dst", cost=otheritem, cooldown=1800}, -- Runed Band of the Kirin Tor
	{item=52251, destination="@!dala_tp_dst", cost=otheritem, cooldown=3600}, -- Jaina's Locket

	{item=32757, destination="Shadowmoon Valley 63,44", cost=otheritem, cooldown=900}, -- APPROXIMATE. Blessed Medallion of Karabor
	{item=37863, destination="Blackrock Depths/2 46,54", cost=otheritem, cooldown=3600}, -- APPROX. Direbrew's Remote
	{item=46874, destination="Icecrown 69.38,22.64", cost=otheritem, cooldown=1800}, -- Argent Crusader's Tabard
	{item=50287, destination="The Cape of Stranglethorn 40.8,73.8", cost=120, cooldown=86400}, -- Boots of the Bay 24h
	{item=58587, destination="Deepholm,48.7,53.6", cost=90, cooldown=1800}, -- Potion of Deepholm --CD is modified because it is a consumable potion. Don't use it like candy
	{item=22631, destination="Deadwind Pass 55,78", cost=otheritem, cooldown=60}, -- Atiesh, Greatstaff of the Guardian


	{item=95567, destination="Isle of Thunder 64.6,73.5", cost=45, cooldown=600, cond=function() return ZGV.CurrentMapID==928 and IsQuestFlaggedCompleted(32644) end}, -- Kirin Tor Beacon --only usable on Thunder Isle
	{item=95567, destination="Isle of Thunder 34.8,89.3", cost=45, cooldown=600, cond=function() return ZGV.CurrentMapID==928 and not IsQuestFlaggedCompleted(32644) end}, -- Kirin Tor Beacon --only usable on Thunder Isle

	{item=95568, destination="Isle of Thunder 33.3,32.6", cost=45, cooldown=600, cond=function() return ZGV.CurrentMapID==928 and IsQuestFlaggedCompleted(32212) end}, -- Sunreaver Beacon --only usable on Thunder Isle
	{item=95568, destination="Isle of Thunder 28.5,51.7", cost=45, cooldown=600, cond=function() return ZGV.CurrentMapID==928 and not IsQuestFlaggedCompleted(32212) end}, -- Sunreaver Beacon --only usable on Thunder Isle

	{item=104113, destination="Timeless Isle/0 23.28,70.83", cost=300, cooldown=0 }, -- Ally. Curious Bronze Timepiece, 1 time use only.
	{item=104110, destination="Timeless Isle/0 21.32,39.52", cost=300, cooldown=0 }, -- Horde. Curious Bronze Timepiece, 1 time use only.

	{item=30542, destination="Netherstorm 32,63", cost=120, cooldown=14400, cond=function() return ZGV.Parser.ConditionEnv.skill('Engineering')>=350 end}, -- Dimensional Ripper - Area 52 Goblin -- TODO only approx coords
	{item=18984, destination="Winterspring 59,50", cost=120, cooldown=14400, cond=function() return ZGV.Parser.ConditionEnv.skill('Engineering')>=260 end}, -- Dimensional Ripper - Everlook Goblin -- TODO only approx coords
	{item=30544, destination="Blade's Edge Mountains 60.4,65.1", cost=120, cooldown=14400, cond=function() return ZGV.Parser.ConditionEnv.skill('Engineering')>=350 end}, -- Ultrasafe Transporter: Toshley's Station Gnomish
	{item=18986, destination="Tanaris 51.6,28.0", cost=120, cooldown=14400, cond=function() return ZGV.Parser.ConditionEnv.skill('Engineering')>=260 end}, -- APPROX. Ultrasafe Transporter: Gadgetzan Gnomish

	{item=63378, destination="Tol Barad Peninsula 73.7,60.9", cost=otheritem, cooldown=14400}, -- Baradin's Wardens Tabard Alliance -- TODO only approx coords
	{item=63379, destination="Tol Barad Peninsula 55.8,80.1", cost=otheritem, cooldown=14400}, -- Hellscream's Reach Tabard Horde

	--Wormhole Generator: Northrend
	{item=48933, toy=true, destination="Borean Tundra 51.78,45.03", cost=15, cooldown=4*60*60, title="Use Wormhole Generator: Northrend and select Borean Tundra", cond=function() local c = ZGV.Parser.ConditionEnv return c.skill('Northrend Engineering')>=40 and c.level>=24 end}, 
	{item=48933, toy=true, destination="Howling Fjord 58.53,48.63", cost=15, cooldown=4*60*60, title="Use Wormhole Generator: Northrend and select Howling Fjord", cond=function() local c = ZGV.Parser.ConditionEnv return c.skill('Northrend Engineering')>=40 and c.level>=24 end}, 
	{item=48933, toy=true, destination="Sholazar Basin 49.21,39.62", cost=15, cooldown=4*60*60, title="Use Wormhole Generator: Northrend and select Sholazar Basin", cond=function() local c = ZGV.Parser.ConditionEnv return c.skill('Northrend Engineering')>=40 and c.level>=24 end}, 
	{item=48933, toy=true, destination="Icecrown 62.87,26.92", cost=15, cooldown=4*60*60, title="Use Wormhole Generator: Northrend and select Icecrown", cond=function() local c = ZGV.Parser.ConditionEnv return c.skill('Northrend Engineering')>=40 and c.level>=24 end}, 
	{item=48933, toy=true, destination="The Storm Peaks 43.90,25.80", cost=15, cooldown=4*60*60, title="Use Wormhole Generator: Northrend and select Storm Peaks", cond=function() local c = ZGV.Parser.ConditionEnv return c.skill('Northrend Engineering')>=40 and c.level>=24 end}, 

}
