local _,ZGV=...
local ZTA = ZGV.ZTA
if not ZTA then return end
local L = ZTA.L

-- GLOBAL LEARN,TalentFrame_LoadUI,ToggleTalentFrame,ZygorTalentAdvisorPopout_Mixin

ZygorTalentAdvisorPopout_Mixin = {}

function ZygorTalentAdvisorPopout_Mixin:OnShow()
	TalentFrame_LoadUI()
	if ZTA.db.profile.zta_windowdocked then
		if not ZTA.TalentFrame:IsShown() then ToggleTalentFrame() end
	end

	self:Reparent()
	self:UpdateDocking()
	self:Update()
	if ZTA.TalentFrame and not ZTA.TalentFrame:IsShown() then ToggleTalentFrame()
		ZTA.TalentFrame.advisorbutton:SetButtonState("PUSHED",1)
	end
	--PlaySound("igCharacterInfoTab");
end

function ZygorTalentAdvisorPopout_Mixin:OnHide()
	self:UpdateDocking()
	if ZTA.TalentFrame and ZTA.TalentFrame.advisorbutton then
		ZTA.TalentFrame.advisorbutton:SetButtonState("NORMAL")
	end
	--PlaySound("igCharacterInfoTab");
end

function ZygorTalentAdvisorPopout_Mixin:OnUpdate()
	--if self.needsResizing>0 then self.needsResizing=self.needsResizing-1 end

	if self.needsResizing and self.needsResizing>0 then
		ZTA:Debug("resizing")
		if self.scroll.child.group1:GetTop() and not self.glyphmode then 
			local height = self.scroll.child.group1:GetTop() - self.scroll.child.talents3:GetBottom()
			local maxheight=100
			local minheight=50
			if height>maxheight then height=maxheight end
			if height<minheight then height=minheight end
			self.scroll.child:SetHeight(height)

			self:SetHeight(height+145)
		else
			self.suggestionLabel:SetSize(230,0)
			self:SetHeight(self.suggestionLabel:GetHeight()+100)
		end

		self.needsResizing=self.needsResizing-1
		self:UpdateDocking()
	end
	if ZTA.popout.moving then
		ZTA.db.profile.zta_windowdocked=self:InDockingRange()
		ZGV:RefreshOptions()
		self:UpdateDocking()
	end
end

function ZygorTalentAdvisorPopout_Mixin:OnLoad()
	self:RegisterForDrag("LeftButton")

	--[[
	ZygorTalentAdvisorPopoutScroll:SetScript("OnScrollRangeChanged",function(self,xrange,yrange)
		ScrollFrame_OnScrollRangeChanged(self, xrange, yrange)
		print(xrange)
		print(yrange)
		local scrollbar = _G[self:GetName().."ScrollBar"];
		local min,max = scrollbar:GetMinMaxValues()
		if max>0 then
			scrollbar:Show()
		else
			scrollbar:Hide()
		end
		print("scrollrangechanged")
	end)
	--]]
end

function ZygorTalentAdvisorPopout_Mixin:OnDragStart()
	ZTA.db.profile.zta_windowdocked = false
	--self:Reparent()
	self:UpdateDocking(false)
	self:ClearAllPoints()
	self:StartMoving()
	self.moving=true
	--print("dragstart")
end

function ZygorTalentAdvisorPopout_Mixin:InDockingRange()
	return ZTA.TalentFrame and ZTA.TalentFrame:IsShown() and ZTA.popout:IsShown()
	and abs(ZTA.popout:GetLeft()-ZTA.TalentFrame:GetRight()+36)<20
	and ZTA.popout:GetTop()-ZTA.TalentFrame:GetTop()<20
	and ZTA.popout:GetTop()-ZTA.TalentFrame:GetTop()>-200
end

function ZygorTalentAdvisorPopout_Mixin:OnDragStop()
	--print("dragstop")
	self:StopMovingOrSizing()
	self.moving=nil
	--	((self:GetLeft()>TalentFrame:GetLeft() and self:GetLeft()-TalentFrame:GetRight()+42<20 and abs(self:GetTop()-TalentFrame:GetTop()+10)<20 then
	ZGV:RefreshOptions()
	self:UpdateDocking(self:InDockingRange())
	self:Reparent()
end

function ZygorTalentAdvisorPopout_Mixin:Hook()
	self:UpdateDocking()
end

function ZygorTalentAdvisorPopout_Mixin:UpdateDocking(set)
	if set~=nil then ZTA.db.profile.zta_windowdocked=set end
	if ZTA.TalentFrame.advisorbutton then
		if ZTA.db.profile.zta_windowdocked and self:IsShown() then
			--PlayerSpecTab1:SetPoint("TOPLEFT",TalentFrame,"TOPRIGHT",ZygorTalentAdvisorPopout:GetWidth()-8,-36)
			ZTA.TalentFrame.advisorbutton:SetParent(self)
			ZTA.TalentFrame.advisorbutton:SetPoint("TOPLEFT",self,"TOPRIGHT",-5,-10)
		else
			--PlayerSpecTab1:SetPoint("TOPLEFT",ZTA.TalentFrame,"TOPRIGHT",0,-36)
			ZTA.TalentFrame.advisorbutton:SetParent(ZTA.TalentFrame)
			ZTA.TalentFrame.advisorbutton:SetPoint("TOPLEFT",ZTA.TalentFrame,"TOPRIGHT",-35,-140)
		end
	end

	if ZTA.db.profile.zta_windowdocked then
		self.TopRight:SetTexture(ZGV.DIR.."\\Skins\\popout-noclose")
		self.TopRight:SetTexCoord(0,1,0,1)
		self.CloseButton:Hide()
	else
		self.TopRight:SetTexture([[Interface\PaperDollInfoFrame\UI-GearManager-Border]])
		self.TopRight:SetTexCoord(0.625,0.75,0,1)
		self.CloseButton:Show()
	end
end

function ZygorTalentAdvisorPopout_Mixin:Reparent()
	if ZTA.db.profile.zta_windowdocked then
		self:SetParent(ZTA.TalentFrame)
		self:ClearAllPoints()
		self:SetPoint("TOPLEFT",ZTA.TalentFrame,"TOPRIGHT",-36,-130)
	else
		self:SetParent(UIParent)
		if self:GetNumPoints()==0 then self:SetPoint("CENTER") end
	end
end

function ZygorTalentAdvisorPopout_Mixin:Popout()
	TalentFrame_LoadUI()
	if not ZTA.TalentFrame:IsShown() and ZGV.db.profile.zta_windowdocked then
		ShowUIPanel(ZTA.TalentFrame)
	end
	self:Show()
end

function ZygorTalentAdvisorPopout_Mixin:SetWarningIcon(code)
	if code=="GREEN" then
		self.warning:Show()
		self.warning:GetRegions():SetVertexColor(0,1,1)
	elseif code=="YELLOW" then
		self.warning:Show()
		self.warning:GetRegions():SetVertexColor(1,0.7,0)
	elseif code=="RED" then
		self.warning:Show()
		self.warning:GetRegions():SetVertexColor(1,0,0)
	elseif code=="BLACK" then
		self.warning:Show()
		self.warning:GetRegions():SetVertexColor(1,0,0)
	else
		self.warning:Hide()
	end
end

-- AND NOW, THE POWERHORSE:

function ZygorTalentAdvisorPopout_Mixin:Update()
	ZTA:Debug("ZGV.ZTA.Popout_Update")

	if not self:IsShown() then
		ZTA:Debug("ZygorTalentAdvisorPopout hidden, not updating")
		return
	end

	-- Prepare basic data: are we handling glyphs? are we viewing the pet?
	
	local s = ""

	self.buildLabel:SetText(L['window_header_buildlabel']) -- "Build: "


	-- Obtain suggestion status code

	local code = ZTA.status.code


	-- Use the code (no matter what we're handling).

	self:SetWarningIcon(code)


	local tabn = 1
	if not ZTA.currentBuild or not ZTA.currentBuild.build or not next(ZTA.currentBuild.build) then
		s=L['error_bulklearn_nobuild']
		self.build:SetText(L['window_header_buildnone'])
		self.suggestionLabel:SetText(L['window_suggestion_nobuild'])
		self.scroll:Hide()
		self.preview:Hide()
		self.accept:Hide()
		--if ZTA.status.code then self.warning:Show() else self.warning:Hide() end
	else
		self.build:SetText(L['window_header_build']:format(ZTA.currentBuildTitle or "?"))
		self.preview:Hide()

			-- Suggestion for: TALENTS

			if ZTA:GetUnusedTalentPoints()==0 then
				self.suggestionLabel:SetText(L['window_suggestion_nopoints'])
				self.scroll:Hide()
				--self.preview:Hide()
				self.accept:Hide()
			elseif not ZTA.suggestion or #ZTA.suggestion==0 then
				if ZTA.status.code=="BLACK" or ZTA.status.code=="NONE" then
					self.suggestionLabel:SetText(ZTA.status.msg or "ERROR")
				elseif ZTA.status.code=="RED" then
					self.suggestionLabel:SetText(ZTA:GetStatusMessage())
				else
					self.suggestionLabel:SetText("Why are there no suggestions..?")
				end
				self.scroll:Hide()
				--self.preview:Hide()
				self.accept:Hide()
			else
				self.suggestionLabel:SetText(L['window_suggestion_normal'])

				local sugformatted = ZTA:GetSuggestionFormatted()
				
				self.sugheight = 0
				for tab,talents in pairs(sugformatted) do
					self.scroll.child['group'..tabn]:SetText(tab)
					s = ""
					for n,levels in ipairs(talents) do
						local talent = "|T"..levels.tex..":0:0:0:0|t "..levels.name
						if #s>0 then s=s.."\n" end
						if levels.oneofone then
							s=s..talent
						else
							local levelrange
							if not levels.to then levelrange=levels.from
							elseif levels.to-levels.from==1 then levelrange=levels.from..","..levels.to
							else levelrange=levels.from.."-"..levels.to end
							s=s..talent.." |cff997700("..levelrange..")|r"
						end
					end
					self.scroll.child['talents'..tabn]:SetText(s)
					tabn=tabn+1
					if tabn>3 then break end
				end

				self.scroll:Show()

				--[[
				if GetCVarBool("previewTalents")
				and (
					GetUnspentTalentPoints(false,pet)-GetGroupPreviewTalentPointsSpent(pet)>0
				  or ZTA.status_preview.code~=ZTA.status.code
				  or tonumber(ZTA.status_preview.missed)>tonumber(ZTA.status.missed)
				) then
					self.preview:SetText(L['preview_button'])
					self.preview:Enable()
				else
					self.preview:SetText(L['preview_button_done'])
					self.preview:Disable()
				end
				self.preview:SetText(L['preview_button'])
				--]]

				self.accept:Show()
				self.accept:SetText(L['learn_button_text'])
				self.accept.is_cancel = false

				if ZTA.bulklearning then
					self.accept:SetText(L['learn_button_abort'])
					self.accept.is_cancel = true
				end
			end
	end
	while tabn<=3 do
		self.scroll.child['group'..tabn]:SetText("")
		self.scroll.child['group'..tabn]:SetHeight(0)
		self.scroll.child['talents'..tabn]:SetText("")
		self.scroll.child['talents'..tabn]:SetHeight(0)
		tabn=tabn+1
	end

	self.configure:SetText(L['configure_button'])
	self.needsResizing=2
end
