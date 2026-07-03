local ZygorGuidesViewer=ZygorGuidesViewer
if not ZygorGuidesViewer then return end
if UnitFactionGroup("player")~="Alliance" then return end
if ZGV:DoMutex("DailiesACATA") then return end
ZygorGuidesViewer.GuideMenuTier = "TRI"
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\Cataclysm\\Twilight Highlands\\Twilight Highlands Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\Cooking\\Stormwind Cooking Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\Cooking\\Ironforge Cooking Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\Cooking\\Darnassus Cooking Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\Fishing\\Darnassus Fishing Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\Fishing\\Ironforge Fishing Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\Fishing\\Stormwind Fishing Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\Jewelcrafting\\Stormwind Jewelcrafting Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Deepholm\\Therazane's Throne Dailies, plus Pre-Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Uldum Dailies with Pre-Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Twilight Highlands\\Twilight Highlands Dailies with Pre-Quests")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Tol Barad Peninsula\\Tol Barad Dailies")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Reputation\\Guardians of Hyjal")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Reputation\\The Earthen Ring")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Reputation\\Therazane")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Reputation\\Ramkahen")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Reputation\\Wildhammer Clan")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Reputation\\Baradin's Wardens")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Zandalari Menace Quest Line")
ZygorGuidesViewer:RegisterGuidePlaceholder("Daily Guides\\Cataclysm Dailies\\Mount Hyjal\\The Call of the World-Shaman Quest Line")
