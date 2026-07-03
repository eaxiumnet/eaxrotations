local DATA_IN_GOSSIP=7 -- 1.14.2: name, level, isTrivial, isDaily, isRepeatable, isLegendary, isIgnored 
function ZGV:QuestAutoAccept_InGossip()
	if IsAltKeyDown() then return end
	local quests={GetGossipAvailableQuests()}
	for qnum=1,GetNumGossipAvailableQuests() do
		local name,level,isTrivial = select((qnum-1)*DATA_IN_GOSSIP+1,unpack(quests))
		if self.CurrentStep then
			for i,goal in ipairs(self.CurrentStep.goals) do
				if goal.action=="accept" and goal.quest and goal.quest.title==name and goal:GetStatus()=="incomplete" then
					self:Debug("&qauto Opening quest in gossip")
					SelectGossipAvailableQuest(qnum)
					return true
				end
			end
		end
		if ZGV.db.profile.autoacceptturninall and not isTrivial then
			self:Debug("&qauto Opening any quest in gossip: #%d %s",qnum,name)
			SelectGossipAvailableQuest(qnum)
			return true
		end
	end
end


local DATA_IN_GOSSIP_TURNIN=6 -- 1.14.2: name, level, isTrivial, isComplete, isLegendary, isIgnored 
function ZGV:QuestAutoTurnin_InGossip()
	if IsAltKeyDown() then return end
	local quests={GetGossipActiveQuests()}
	for qnum=1,GetNumGossipActiveQuests() do
		local title = quests[(qnum-1)*DATA_IN_GOSSIP_TURNIN+1]
		if self.CurrentStep then
			for i,goal in ipairs(self.CurrentStep.goals) do
				if goal.action=="turnin" and goal.quest and goal.quest.title==title and goal:GetStatus()=="incomplete" then
					self:Debug("&qauto Turning in quest")
					SelectGossipActiveQuest(qnum)
					return true
				end
			end
		end
		if ZGV.db.profile.autoacceptturninall then -- let's not be picky
			for i,quest in ipairs(self.quests) do
				if quest.title==title and quest.complete then
					self:Debug("&qauto Turning in quest in gossip: %s", title)
					SelectGossipActiveQuest(qnum)
					return true
				end
			end
		end
	end
end