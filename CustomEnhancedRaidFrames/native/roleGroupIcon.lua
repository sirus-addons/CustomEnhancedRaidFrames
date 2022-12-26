local ADDON_NAME, PRIVATE = ...
local ADDON = PRIVATE.ADDON

local select = select

local GetRaidRosterInfo = GetRaidRosterInfo
local UnitExists = UnitExists
local UnitInRaid = UnitInRaid
local UnitIsGroupLeader = UnitIsGroupLeader

-- GLOBALS: CompactUnitFrame_UpdateRoleGroupIcon

function ADDON.CompactUnitFrame_UpdateRoleGroupIcon(frame, groupType)
	ADDON.RoleGroupIcon_Update(frame, groupType)
end

function ADDON.RoleGroupIcon_Setup(frame, groupType)
	if not frame.roleGroupIconERF then
		frame.roleGroupIconERF = frame:CreateTexture("$parentRoleGroupIconERF", "ARTWORK")
	end

	local db = ADDON.db.profile[groupType].nameAndIcons.roleGroupIcon
	local size = db.size * ADDON.ComponentScale(groupType)

	local xOffset, yOffset = ADDON:Offsets(db.anchorPoint, frame, groupType)
	xOffset = xOffset + db.xOffset
	yOffset = yOffset + db.yOffset

	frame.roleGroupIconERF:ClearAllPoints()
	frame.roleGroupIconERF:SetPoint(db.anchorPoint, xOffset, yOffset)
	frame.roleGroupIconERF:SetSize(size, size)
	frame.roleGroupIconERF:SetAlpha(db.alpha)

	ADDON.RoleGroupIcon_Update(frame, groupType)
end

function ADDON.RoleGroupIcon_Update(frame, groupType)
	if not frame or not frame.unit or not frame.roleGroupIconERF then return end
	if not UnitExists(frame.displayedUnit) then return end

	local db = ADDON.db.profile[groupType].nameAndIcons.roleGroupIcon
	if not db.enabled then return end

	local raidID = UnitInRaid(frame.unit);
	if (raidID and select(2, GetRaidRosterInfo(raidID + 1)) > 0 or UnitIsGroupLeader(frame.unit)) then
		if not db.hide then
			local role = (UnitIsGroupLeader(frame.unit) or select(2, GetRaidRosterInfo(raidID + 1)) == 2) and "Leader" or "Assistant"
			frame.roleGroupIconERF:SetTexture("Interface\\GroupFrame\\UI-Group-"..role.."Icon")
			frame.roleGroupIconERF:Show()
		else
			frame.roleGroupIconERF:Hide()
		end

		frame.roleGroupIcon:Hide()
		frame.roleGroupIcon:SetWidth(1)
	else
		frame.roleGroupIconERF:Hide()
	end
end

function ADDON.RoleGroupIcon_Revert()
	for frame in ADDON.IterateCompactFrames() do
		if frame.roleGroupIconERF then
			frame.roleGroupIconERF:Hide()

			if UnitExists(frame.unit) then
				CompactUnitFrame_UpdateRoleGroupIcon(frame)
			end
		end
	end
end