local ADDON_NAME, PRIVATE = ...
local ADDON = PRIVATE.ADDON

local GetRaidTargetIndex = GetRaidTargetIndex
local UnitExists = UnitExists

-- GLOBALS: CompactUnitFrame_UpdateRaidTargetIcon

function ADDON.CompactUnitFrame_UpdateRaidTargetIcon(frame, groupType)
	ADDON.RaidTargetIcon_Update(frame, groupType)
end

function ADDON.RaidTargetIcon_Setup(frame, groupType)
	if not frame.raidTargetIconERF then
		frame.raidTargetIconERF = frame:CreateTexture("$parentRaidTargetIconERF", "ARTWORK")
	end

	local db = ADDON.db.profile[groupType].nameAndIcons.raidTargetIcon
	local size = db.size * ADDON.ComponentScale(groupType)

	frame.raidTargetIconERF:ClearAllPoints()
	frame.raidTargetIconERF:SetPoint(db.anchorPoint, db.xOffset, db.yOffset)
	frame.raidTargetIconERF:SetSize(size, size)
	frame.raidTargetIconERF:SetAlpha(db.alpha)

	ADDON.RaidTargetIcon_Update(frame, groupType)
end

function ADDON.RaidTargetIcon_Update(frame, groupType)
	if not frame or not frame.unit or not frame.raidTargetIconERF then return end
	if not UnitExists(frame.displayedUnit) then return end

	local db = ADDON.db.profile[groupType].nameAndIcons.raidTargetIcon
	if not db.enabled then return end

	local raidTargetIndex = GetRaidTargetIndex(frame.unit)
	if raidTargetIndex then
		if not db.hide then
			frame.raidTargetIconERF:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_"..raidTargetIndex)
			frame.raidTargetIconERF:Show()
		else
			frame.raidTargetIconERF:Hide()
		end

		frame.raidTargetIcon:Hide()
		frame.raidTargetIcon:SetWidth(1)
	else
		frame.raidTargetIconERF:Hide()
	end
end

function ADDON.RaidTargetIcon_Revert()
	for frame in ADDON.IterateCompactFrames() do
		if frame.raidTargetIconERF then
			frame.raidTargetIconERF:Hide()

			if UnitExists(frame.unit) then
				CompactUnitFrame_UpdateRaidTargetIcon(frame)
			end
		end
	end
end