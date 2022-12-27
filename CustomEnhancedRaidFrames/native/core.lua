local ADDON_NAME, PRIVATE = ...
local ADDON = PRIVATE.ADDON

local SharedMedia = LibStub("LibSharedMedia-3.0")

local InCombatLockdown = InCombatLockdown
local UnitExists = UnitExists

local strfind = string.find

-- GLOBALS: CompactRaidGroup_UpdateLayout

function ADDON:CompactUnitFrame_UpdateAll(frame)
	if not frame then return end

	local groupType = ADDON.GetGroupType()
	if groupType ~= self.currentGroup then
		self:RefreshProfileSettings()
	end

	local name = frame:GetName()
	if not name then return end
	if not UnitExists(frame.displayedUnit) then return end

	if groupType ~= self.processedFrames[name] then
		local inCombat = InCombatLockdown()
		self:LayoutFrame(frame, groupType, inCombat)
		self.processedFrames[name] = groupType
	end
end

function ADDON:CompactRaidFrameContainer_LayoutFrames()
	local groupType = ADDON.GetGroupType()

	for group in self.IterateCompactGroups(groupType) do
		self:LayoutGroup(group, groupType)
	end
end

local originalTitleHeight = {}
function ADDON:LayoutGroup(frame, groupType, isInCombatLockDown)
	if self.db.profile[groupType].frames.hideGroupTitles then
		if not originalTitleHeight[frame] then
			originalTitleHeight[frame] = frame.title:GetHeight()
		end
		frame.title:Hide()
		frame.title:SetHeight(0)
	else
		if originalTitleHeight[frame] then
			frame.title:SetHeight(originalTitleHeight[frame])
			originalTitleHeight[frame] = nil
		end
		frame.title:Show()
	end

	if not isInCombatLockDown then
		CompactRaidGroup_UpdateLayout(frame)
	end
end

function ADDON:LayoutFrame(frame, groupType, isInCombatLockDown)
	local db = self.db.profile[groupType]
	local deferred = false

	if not isInCombatLockDown then
		self:AddSubFrames(frame, groupType)
	else
		deferred = true
	end

	do
		local texture = SharedMedia:Fetch("statusbar", db.frames.texture) or SharedMedia:Fetch("statusbar", self:Defaults().profile[groupType].frames.texture)
		frame.healthBar:SetStatusBarTexture(texture, "BORDER")

		if not db.frames.showResourceOnlyForHealers and ADDON.displayPowerBar and (frame.unit and not strfind(frame.unit, "pet", 1, true)) then
			frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, db.frames.powerBarHeight + 1)
			frame.horizDivider:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 1 + db.frames.powerBarHeight)
			frame.horizDivider:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 1 + db.frames.powerBarHeight)
		end

		local texture = SharedMedia:Fetch("statusbar", db.frames.powerBarTexture) or SharedMedia:Fetch("statusbar", self:Defaults().profile[groupType].frames.powerBarTexture)
		frame.powerBar:SetStatusBarTexture(texture, "BORDER")

		self.PowerBar_Setup(frame, groupType, true)

		frame.background:SetAlpha(db.frames.backgoundAlpha)
		frame.healthBar:SetAlpha(db.frames.alpha)
		frame.healthBar.background:SetAlpha(db.frames.backgoundAlpha)
		frame.powerBar:SetAlpha(db.frames.alpha)
	end

	self:SetUpSubFramesPositionsAndSize(frame, "buffFrames", groupType)
	self:SetUpSubFramesPositionsAndSize(frame, "debuffFrames", groupType)
	self:SetUpSubFramesPositionsAndSize(frame, "dispelDebuffFrames", groupType)

	if db.nameAndIcons.name.enabled then
		self.Name_Setup(frame, groupType)
	else
		self.Name_Revert()
	end

	if db.nameAndIcons.statusText.enabled then
		self.StatusText_Setup(frame, groupType)
	end

	if db.nameAndIcons.raidTargetIcon.enabled then
		self.RaidTargetIcon_Setup(frame, groupType)
	end

	if db.nameAndIcons.roleGroupIcon.enabled then
		self.RoleGroupIcon_Setup(frame, groupType)
	end

	if db.nameAndIcons.roleIcon.enabled then
		self.RoleIcon_Setup(frame, groupType)
	end

	if db.nameAndIcons.readyCheckIcon.enabled then
		self.ReadyCheckIcon_Setup(frame, groupType)
	end

	if db.nameAndIcons.centerStatusIcon.enabled then
		self.CenterStatusIcon_Setup(frame, groupType)
	end

	if db.frames.colorEnabled then
		self.HealthBar_Setup(frame, groupType)
	end

	return deferred
end