local ADDON_NAME, PRIVATE = ...
local ADDON = PRIVATE.ADDON

local ipairs = ipairs
local pairs = pairs
local strformat = string.format

local UnitIsPlayer = UnitIsPlayer
local UnitExists = UnitExists

function ADDON:CreateVirtualFrame(frameType, index)
	local frame = CreateFrame("Button", strformat("%sVirtualFrame_%s_%i", ADDON_NAME, frameType, index), UIParent)
	frame:Hide()

	local texture = frame:CreateTexture("$parentTexture", "BACKGROUND")
	texture:SetAllPoints(frame)
	frame.texture = texture

	local text = frame:CreateFontString("$parentText", "OVERLAY", "GameTooltipText")
	text:SetFont("Fonts\\FRIZQT__.TTF", 11, "THICKOUTLINE, MONOCHROME")
	text:SetPoint("CENTER", 0, 0)
	text:SetText(index)
	frame.text = text

	if frameType == "buffFrames" then
		texture:SetTexture("Interface\\Icons\\ability_rogue_sprint")
	elseif frameType == "debuffFrames" then
		texture:SetTexture("Interface\\Icons\\ability_rogue_kidneyshot")
	else
		texture:SetTexture("Interface\\RaidFrame\\Raid-Icon-DebuffMagic")
	end

	return frame
end

function ADDON:ShowVirtual(groupType)
	local frame

	for cuFrame in self.IterateCompactFrames() do
		if cuFrame.displayedUnit and UnitExists(cuFrame.displayedUnit) and UnitIsPlayer(cuFrame.displayedUnit) then
			frame = cuFrame
			break
		end
	end

	if not frame then return end

	self.virtual.shown = true
	self.virtual.frame = frame

	groupType = groupType or self.virtual.groupType

	self:SetUpVirtual("buffFrames", groupType, self.ComponentScale(groupType))
	self:SetUpVirtual("debuffFrames", groupType, self.ComponentScale(groupType), true)
	self:SetUpVirtual("dispelDebuffFrames", groupType, 1)
end

function ADDON:SetUpVirtual(subFrameType, groupType, resize, bigSized)
	if not self.virtual.shown then return end

	local db = self.db.profile[groupType][subFrameType]
	local typedframes = self.virtual.frames[subFrameType]

	for frameType in self.IterateSubFrameTypes() do
		for i = 1, self.maxFrames do
			if not self.virtual.frames[frameType][i] then
				self.virtual.frames[frameType][i] = self:CreateVirtualFrame(frameType, i)
			end
		end
	end

	for frameIndex, frame in ipairs(typedframes) do
		if frameIndex > db.num then
			frame:Hide()
		else
			frame:Show()
		end
	end

	self:SetUpSubFramesPositionsAndSize(self.virtual.frame, subFrameType, groupType, true)

	if bigSized and db.showBigDebuffs then
		local size = db.bigDebuffSize * resize
		typedframes[1]:SetSize(size, size)
		typedframes[1].isBossAura = true

		if db.smartAnchoring then
			self:SmartAnchoring(self.virtual.frame, groupType, true)
		end
	end
end

function ADDON:HideVirtual()
	for _, group in pairs(self.virtual.frames) do
		for _, frame in ipairs(group) do
			frame:Hide()
		end
	end

	self.virtual.shown = nil
end

function ADDON:VirtualFramesToggle()
	if self.virtual.shown then
		self:HideVirtual()
	else
		self:ShowVirtual()
	end
end