local name,ZGV = ...

-- #GLOBALS ZygorGuidesViewer

local GuideMenu = ZGV.GuideMenu

GuideMenu.Featured={}

table.insert(GuideMenu.Featured,{
	title="The Burning Crusade", group="tbc",

	{"section", text=[[LEVELING]]},
	{"banner", image=ZGV.IMAGESDIR.."TBCLeveling",showcaseonly=true},

	{"content", text=[[Complete Your Starter or Boosted Character guide]]},
	{"text", text=[[If you are creating a new character in TBC, use the appropriate starter or boosted guide for your character.]]},
	{"columns",
	{"item", text="**Human Starter (1-12)**", guide="Leveling Guides\\Starter Guides (1-11)\\Human Starter (1-12)",faction="A"},
	{"item", text="**Dwarf & Gnome Starter (1-11)**", guide="Leveling Guides\\Starter Guides (1-11)\\Dwarf & Gnome Starter (1-11)",faction="A"},
	{"item", text="**Night Elf Starter (1-11)**", guide="Leveling Guides\\Starter Guides (1-11)\\Night Elf Starter (1-11)",faction="A"},
	{"item", text="**Draenei Starter (1-11)**", guide="Leveling Guides\\Starter Guides (1-11)\\Draenei Starter (1-11)",faction="A"},
	{"item", text="**Bloodmyst Isle (14-20)**", guide="Leveling Guides\\Classic (11-60)\\Bloodmyst Isle (14-20)", faction="A"},
	{"item", text="**Orc & Troll Starter (1-12)**", guide="Leveling Guides\\Starter Guides (1-12)\\Orc & Troll Starter (1-12)", faction="H"},
	{"item", text="**Tauren Starter (1-12)**", guide="Leveling Guides\\Starter Guides (1-12)\\Tauren Starter (1-12)", faction="H"},
	{"item", text="**Undead Starter (1-13)**", guide="Leveling Guides\\Starter Guides (1-12)\\Undead Starter (1-13)", faction="H"},
	{"item", text="**Blood Elf Starter (1-13)**", guide="Leveling Guides\\Starter Guides (1-12)\\Blood Elf Starter (1-13)", faction="H"},
	{"item", text="**Ghostlands (12-20)**", guide="Leveling Guides\\Classic (12-60)\\Not Warrior & Shaman (12-22)\\Ghostlands (12-20)", faction="H"},
	}, --columnsend

	{"columns",
	{"item", text=[[**Boosted Hunter Intro**]], guide="LEVELING\\Boosted Characters\\Boosted Hunter Intro"},
	{"item", text=[[**Boosted Warrior Intro**]], guide="LEVELING\\Boosted Characters\\Boosted Warrior Intro"},
	{"item", text=[[**Boosted Paladin Intro**]], guide="LEVELING\\Boosted Characters\\Boosted Paladin Intro"},
	{"item", text=[[**Boosted Rogue Intro**]], guide="LEVELING\\Boosted Characters\\Boosted Rogue Intro"},
	{"item", text=[[**Boosted Priest Intro**]], guide="LEVELING\\Boosted Characters\\Boosted Priest Intro"},
	{"item", text=[[**Boosted Mage Intro**]], guide="LEVELING\\Boosted Characters\\Boosted Mage Intro"},
	{"item", text=[[**Boosted Warlock Intro**]], guide="LEVELING\\Boosted Characters\\Boosted Warlock Intro"},
	{"item", text=[[**Boosted Druid Intro**]], guide="LEVELING\\Boosted Characters\\Boosted Druid Intro"},
	{"item", text=[[**Boosted Shaman Intro**]], guide="LEVELING\\Boosted Characters\\Boosted Shaman Intro"},
	}, --columnsend

	{"content", text=[[OPTIONAL: Complete Your Class Quests]]},
	{"text", text=[[These are class specific quests that open up at certain levels. We suggest running this guide in a tab alongside the leveling guides.]]},
	{"columns",
	{"item", text=[[**Druid Class Quests**]], guide="LEVELING\\Class Quests\\Druid Class Quests"},
	{"item", text=[[**Priest Class Quests**]], guide="LEVELING\\Class Quests\\Priest Class Quests"},
	{"item", text=[[**Warrior Class Quests**]], guide="LEVELING\\Class Quests\\Warrior Class Quests"},
	{"item", text=[[**Hunter Class Quests**]], guide="LEVELING\\Class Quests\\Hunter Class Quests"},
	{"item", text=[[**Rogue Class Quests**]], guide="LEVELING\\Class Quests\\Rogue Class Quests"},
	{"item", text=[[**Mage Class Quests**]], guide="LEVELING\\Class Quests\\Mage Class Quests"},
	{"item", text=[[**Paladin Class Quests**]], guide="LEVELING\\Class Quests\\Paladin Class Quests"},
	{"item", text=[[**Warlock Class Quests**]], guide="LEVELING\\Class Quests\\Warlock Class Quests"},
	}, --columnsend

	{"content", text=[[Reach Level 58 or Higher]]},
	{"text", text=[[Use the main leveling guides to reach level 58 or higher in order to go to Outland.]]},
	{"guideslist",columns=4,path="LEVELING\\Classic (12-58)"},

	{"content", text=[[Reach Level 70]]},
	{"text", text=[[Journey to Outland using the guides below and reach the max level of 70.]]},
	{"columns",
	{"item", text=[[**Hellfire Peninsula (60-61)**]], guide="Leveling Guides\\The Burning Crusade (60-70)\\Hellfire Peninsula (60-61)",faction="A"},
	{"item", text=[[**Hellfire Peninsula (60-62)**]], guide="Leveling Guides\\The Burning Crusade (60-70)\\Hellfire Peninsula (60-62)", faction="H"},
	{"item", text=[[**Zangarmarsh (61-63)**]], guide="Leveling Guides\\The Burning Crusade (60-70)\\Zangarmarsh (61-63)",faction="A"},
	{"item", text=[[**Zangarmarsh (62-63)**]], guide="Leveling Guides\\The Burning Crusade (60-70)\\Zangarmarsh (62-63)", faction="H"},
	{"item", text=[[**Terokkar Forest (63-65)**]], guide="Leveling Guides\\The Burning Crusade (60-70)\\Terokkar Forest (63-65)",faction="A"},
	{"item", text=[[**Terokkar Forest (63-65)**]], guide="Leveling Guides\\The Burning Crusade (60-70)\\Terokkar Forest (63-65)", faction="H"},
	{"item", text=[[**Nagrand (65-67)**]], guide="Leveling Guides\\The Burning Crusade (60-70)\\Nagrand (65-67)",faction="A"},
	{"item", text=[[**Nagrand (65-67)**]], guide="Leveling Guides\\The Burning Crusade (60-70)\\Nagrand (65-67)", faction="H"},
	{"item", text=[[**Blade's Edge Mountains (67-68)**]], guide="Leveling Guides\\The Burning Crusade (60-70)\\Blade's Edge Mountains (67-68)",faction="A"},
	{"item", text=[[**Blade's Edge Mountains (67-68)**]], guide="Leveling Guides\\The Burning Crusade (60-70)\\Blade's Edge Mountains (67-68)", faction="H"},
	{"item", text=[[**Netherstorm (68-70)**]], guide="Leveling Guides\\The Burning Crusade (60-70)\\Netherstorm (68-70)",faction="A"},
	{"item", text=[[**Netherstorm (68-70)**]], guide="Leveling Guides\\The Burning Crusade (60-70)\\Netherstorm (68-70)", faction="H"},
	{"item", text=[[**Shadowmoon Valley (70-70)**]], guide="Leveling Guides\\The Burning Crusade (60-70)\\Shadowmoon Valley (70-70)",faction="A"},
	{"item", text=[[**Shadowmoon Valley (70-70)**]], guide="Leveling Guides\\The Burning Crusade (60-70)\\Shadowmoon Valley (70-70)", faction="H"},
	}, --columnsend

	{"content", text=[[Optional: Complete TBC Group Quests]]},
	{"text", text=[[The following guides cover group quests which are generally too difficult to solo so you'll most likely need to join a group to complete them. You can do these if you need extra quests to help you level.]]},
	{"columns",

	{"item", text=[[**Hellfire Peninsula Group Quests**]], guide="LEVELING\\The Burning Crusade (60-70)\\Hellfire Peninsula Group Quests"},
	{"item", text=[[**Zangarmarsh Group Quests**]], guide="LEVELING\\The Burning Crusade (60-70)\\Zangarmarsh Group Quests"},
	{"item", text=[[**Terokkar Forest Group Quests**]], guide="LEVELING\\The Burning Crusade (60-70)\\Terokkar Forest Group Quests"},
	{"item", text=[[**Nagrand Group Quests**]], guide="LEVELING\\The Burning Crusade (60-70)\\Nagrand Group Quests"},
	{"item", text=[[**Blade's Edge Mountains Group Quests**]], guide="LEVELING\\The Burning Crusade (60-70)\\Blade's Edge Mountains Group Quests"},
	{"item", text=[[**Netherstorm Group Quests**]], guide="LEVELING\\The Burning Crusade (60-70)\\Netherstorm Group Quests"},

	}, --columnsend

	{"section", text=[[DUNGEONS]]},
	{"banner", image=ZGV.IMAGESDIR.."TBCDungeons",showcaseonly=true},

	{"content", text=[[Dungeon Boss Strategy Guides]]},
	{"text", text=[[These guides will walk you through defeating the bosses in the Outland dungeons.]]},
	{"columns",
	{"item", text=[[**Hellfire Ramparts (60-70)**]], guide="DUNGEONS\\The Burning Crusade\\Hellfire Ramparts (60-70)"},
	{"item", text=[[**The Blood Furnace (61-70)**]], guide="DUNGEONS\\The Burning Crusade\\The Blood Furnace (61-70)"},
	{"item", text=[[**The Slave Pens (62-70)**]], guide="DUNGEONS\\The Burning Crusade\\The Slave Pens (62-70)"},
	{"item", text=[[**The Underbog (63-70)**]], guide="DUNGEONS\\The Burning Crusade\\The Underbog (63-70)"},
	{"item", text=[[**Mana-Tombs (64-70)**]], guide="DUNGEONS\\The Burning Crusade\\Mana-Tombs (64-70)"},
	{"item", text=[[**Auchenai Crypts (65-70)**]], guide="DUNGEONS\\The Burning Crusade\\Auchenai Crypts (65-70)"},
	{"item", text=[[**Sethekk Halls (67-70)**]], guide="DUNGEONS\\The Burning Crusade\\Sethekk Halls (67-70)"},
	{"item", text=[[**Old Hillsbrad Foothills (66-70)**]], guide="DUNGEONS\\The Burning Crusade\\Old Hillsbrad Foothills (66-70)"},
	{"item", text=[[**The Black Morass (68-70)**]], guide="DUNGEONS\\The Burning Crusade\\The Black Morass (68-70)"},
	{"item", text=[[**The Mechanar (70)**]], guide="DUNGEONS\\The Burning Crusade\\The Mechanar (70)"},
	{"item", text=[[**The Shattered Halls (70)**]], guide="DUNGEONS\\The Burning Crusade\\The Shattered Halls (70)"},
	{"item", text=[[**The Steamvault (70)**]], guide="DUNGEONS\\The Burning Crusade\\The Steamvault (70)"},
	}, --columnsend

	{"content", text=[[Dungeon Quest Guides (BETA)]]},
	{"text", text=[[These guides will walk you through completing the Outland dungeon quests. Note that these guides are still works in progress.]]},
	{"columns",
	{"item", text=[[**Hellfire Ramparts Quests**]], guide="DUNGEONS\\The Burning Crusade\\Hellfire Ramparts Quests"},
	{"item", text=[[**The Slave Pens Quests**]], guide="DUNGEONS\\The Burning Crusade\\The Slave Pens Quests"},
	{"item", text=[[**The Underbog Quests**]], guide="DUNGEONS\\The Burning Crusade\\The Underbog Quests"},
	{"item", text=[[**Mana-Tombs Quests**]], guide="DUNGEONS\\The Burning Crusade\\Mana-Tombs Quests"},
	{"item", text=[[**Auchenai Crypts Quests**]], guide="DUNGEONS\\The Burning Crusade\\Auchenai Crypts Quests"},
	{"item", text=[[**Sethekk Halls Quests**]], guide="DUNGEONS\\The Burning Crusade\\Sethekk Halls Quests"},
	{"item", text=[[**Old Hillsbrad Foothills Quests**]], guide="DUNGEONS\\The Burning Crusade\\Old Hillsbrad Foothills Quests"},
	{"item", text=[[**The Black Morass Quests**]], guide="DUNGEONS\\The Burning Crusade\\The Black Morass Quests"},
	{"item", text=[[**The Mechanar Quests**]], guide="DUNGEONS\\The Burning Crusade\\The Mechanar Quests"},
	{"item", text=[[**The Steamvault Quests**]], guide="DUNGEONS\\The Burning Crusade\\The Steamvault Quests"},
	{"item", text=[[**Shadow Labyrinth Quests**]], guide="DUNGEONS\\The Burning Crusade\\Shadow Labyrinth Quests"},
	{"item", text=[[**The Arcatraz Quests**]], guide="DUNGEONS\\The Burning Crusade\\The Arcatraz Quests"},
	{"item", text=[[**The Botanica Quests**]], guide="DUNGEONS\\The Burning Crusade\\The Botanica Quests"},
	{"item", text=[[**The Cipher of Damnation**]], guide="DUNGEONS\\The Burning Crusade\\The Cipher of Damnation"},
	}, --columnsend

	{"content", text=[[Dungeon Attunement Guides]]},
	{"text", text=[[These guides will walk you through becoming attuned with the following dungeons.]]},
	{"columns",
	{"item", text=[[**Karazhan Attunement**]], guide="DUNGEONS\\The Burning Crusade\\Karazhan Attunement"},
	{"item", text=[[**Hellfire Citadel Attunement**]], guide="DUNGEONS\\The Burning Crusade\\Hellfire Citadel Attunement"},
	{"item", text=[[**Serpentshrine Cavern Attunement**]], guide="DUNGEONS\\The Burning Crusade\\Serpentshrine Cavern Attunement"},
	{"item", text=[[**Tempest Keep Attunement**]], guide="DUNGEONS\\The Burning Crusade\\Tempest Keep Attunement"},
	}, --columnsend

	{"section", text=[[DAILIES]]},
	{"banner", image=ZGV.IMAGESDIR.."TBCDailies",showcaseonly=true},

	{"content", text=[[Daily Quest Guides]]},
	{"columns",
	{"item", text=[[**Ogri'la Daily Quests**]], guide="DAILIES\\The Burning Crusade\\Ogri'la\\Ogri'la Daily Quests"},
	{"item", text=[[**Sha'tari Skyguard Daily Quests**]], guide="DAILIES\\The Burning Crusade\\Sha'tari Skyguard\\Sha'tari Skyguard Daily Quests"},
	{"item", text=[[**Sha'tari Skyguard Terokk Farming**]], guide="DAILIES\\The Burning Crusade\\Sha'tari Skyguard\\Sha'tari Skyguard Terokk Farming"},
	}, --columnsend

	{"section", text=[[PROFESSIONS]]},
	{"banner", image=ZGV.IMAGESDIR.."TBCProfessions",showcaseonly=true},

	{"content", text=[[Profession Leveling Guides]]},
	{"text", text=[[These guides will walk you through leveling up your professions to the new max skill level of 375.]]},
	{"columns",
	{"item", text=[[**Alchemy (1-375)**]], guide="PROFESSIONS\\Alchemy\\Alchemy (1-375)"},
	{"item", text=[[**Blacksmithing (1-375)**]], guide="PROFESSIONS\\Blacksmithing\\Blacksmithing (1-375)"},
	{"item", text=[[**Cooking (300-375)**]], guide="PROFESSIONS\\Cooking\\Cooking (300-375)"},
	{"item", text=[[**Enchanting (1-375)**]], guide="PROFESSIONS\\Enchanting\\Enchanting (1-375)"},
	{"item", text=[[**Engineering (1-375)**]], guide="PROFESSIONS\\Engineering\\Engineering (1-375)"},
	{"item", text=[[**First Aid (300-375)**]], guide="PROFESSIONS\\First Aid\\First Aid (300-375)"},
	{"item", text=[[**Herbalism (300-375)**]], guide="PROFESSIONS\\Herbalism\\Herbalism (300-375)"},
	{"item", text=[[**Jewelcrafting (1-375)**]], guide="PROFESSIONS\\Jewelcrafting\\Jewelcrafting (1-375)"},
	{"item", text=[[**Leatherworking (1-375)**]], guide="PROFESSIONS\\Leatherworking\\Leatherworking (1-375)"},
	{"item", text=[[**Mining (300-375)**]], guide="PROFESSIONS\\Mining\\Mining (300-375)"},
	{"item", text=[[**Skinning (300-375)**]], guide="PROFESSIONS\\Skinning\\Skinning (300-375)"},
	{"item", text=[[**Tailoring (1-375)**]], guide="PROFESSIONS\\Tailoring\\Tailoring (1-375)"},
	}, --columnsend

	{"section", text=[[REPUTATIONS]]},
	{"banner", image=ZGV.IMAGESDIR.."TBCReputations",showcaseonly=true},

	{"content", text=[[Reputation Guides]]},
	{"text", text=[[These guides will walk you through reaching Exalted with various Outland factions.]]},
	{"columns",
	{"item", text=[[**Honor Hold**]], guide="REPUTATIONS\\The Burning Crusade\\Honor Hold",faction="A"},
	{"item", text=[[**Cenarion Expedition**]], guide="REPUTATIONS\\The Burning Crusade\\Cenarion Expedition"},
	{"item", text=[[**Lower City**]], guide="REPUTATIONS\\The Burning Crusade\\Lower City"},
	{"item", text=[[**The Scryers**]], guide="REPUTATIONS\\The Burning Crusade\\The Scryers"},
	{"item", text=[[**The Aldor**]], guide="REPUTATIONS\\The Burning Crusade\\The Aldor"},
	{"item", text=[[**Ogri'la**]], guide="REPUTATIONS\\The Burning Crusade\\Ogri'la"},
	{"item", text=[[**Sha'tari Skyguard**]], guide="REPUTATIONS\\The Burning Crusade\\Sha'tari Skyguard"},


	}, --columnsend

})


