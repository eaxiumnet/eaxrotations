local ZygorGuidesViewer=ZygorGuidesViewer
if not ZygorGuidesViewer then return end
if ZGV:DoMutex("ReputationsC") then return end
ZygorGuidesViewer.GuideMenuTier = "TRI"
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Burning Crusade Reputations\\The Aldor")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Burning Crusade Reputations\\Cenarion Expedition")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Cataclysm Reputations\\Therazane")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Cataclysm Reputations\\Guardians of Hyjal")
