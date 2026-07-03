local ZygorGuidesViewer=ZygorGuidesViewer
if not ZygorGuidesViewer then return end
if UnitFactionGroup("player")~="Horde" then return end
if ZGV:DoMutex("DailiesHCATA") then return end
ZygorGuidesViewer.GuideMenuTier = "TRI"
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\Cataclysm\\Twilight Highlands\\Twilight Highlands Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\Classic\\Cooking\\Orgrimmar Cooking Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\Classic\\Cooking\\Thunder Bluff Cooking Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\Classic\\Cooking\\Undercity Cooking Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\Fishing\\Orgrimmar Fishing Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\Fishing\\Thunder Bluff Fishing Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\Fishing\\Undercity Fishing Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\Jewelcrafting\\Orgimmar Jewelcrafting Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Deepholm Dailies with Pre-Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Uldum Dailies with Pre-Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Twighlight Highlands Dailies with Pre-Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Tol Barad Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Reputation\\Guardians of Hyjal")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Reputation\\The Earthen Ring")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Reputation\\Therazane")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Reputation\\Ramkahen")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Reputation\\Dragonmaw Clan")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Reputation\\Hellscream's Reach")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Zandalari Menace Quest Line")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Mount Hyjal\\The Call of the World-Shaman Quest Line")
