local ADDON_NAME, PRIVATE = ...
local ADDON = PRIVATE.ADDON

local unpack = unpack

local GetTexCoordsForRoleSmallCircle = GetTexCoordsForRoleSmallCircle
local UnitExists = UnitExists

-- GLOBALS: CompactUnitFrame_UpdateRoleIcon

function ADDON.CompactUnitFrame_UpdateRoleIcon(frame, groupType)
	ADDON.RoleIcon_Update(frame, groupType)
end

function ADDON.RoleIcon_Setup(frame, groupType)
	if not frame.roleIconERF then
		frame.roleIconERF = frame:CreateTexture("$parentRoleIconERF", "ARTWORK")
	end

	local db = ADDON.db.profile[groupType].nameAndIcons.roleIcon
	local size = db.size * ADDON.ComponentScale(groupType)

	local xOffset, yOffset = ADDON:Offsets("TOPLEFT", frame, groupType)
	xOffset = xOffset + db.xOffset
	yOffset = yOffset + db.yOffset

	frame.roleIconERF:ClearAllPoints()
	frame.roleIconERF:SetPoint(db.anchorPoint, xOffset, yOffset)
	frame.roleIconERF:SetSize(size, size)
	frame.roleIconERF:SetAlpha(db.alpha)

	ADDON.RoleIcon_Update(frame, groupType)
end

function ADDON.RoleIcon_Update(frame, groupType)
	if not frame or not frame.unit or not frame.roleIconERF then return end
	if not UnitExists(frame.displayedUnit) then return end

	local db = ADDON.db.profile[groupType].nameAndIcons.roleIcon
	if not db.enabled then return end

	local role, raidRole = ADDON.GetUnitRole(frame.unit)
	if role ~= "NONE" then
		if not db.hide then
			local roleL = role:lower()
			if db.useCustomTextures and db[roleL] and db[roleL] ~= "" then
				frame.roleIconERF:SetTexture(db[roleL])
				frame.roleIconERF:SetTexCoord(0, 1, 0, 1)
				frame.roleIconERF:SetVertexColor(unpack(db.colors[roleL]))
			else
				if role == "VEHICLE" then
					frame.roleIconERF:SetTexture("Interface\\Vehicles\\UI-Vehicles-Raid-Icon");
					frame.roleIconERF:SetTexCoord(0, 1, 0, 1);
				elseif raidRole then
					frame.roleIconERF:SetTexture("Interface\\GroupFrame\\UI-Group-"..role.."Icon");
					frame.roleIconERF:SetTexCoord(0, 1, 0, 1);
				else
					frame.roleIconERF:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES");
					frame.roleIconERF:SetTexCoord(GetTexCoordsForRoleSmallCircle(role));
				end

				frame.roleIconERF:SetVertexColor(1, 1, 1, 1)
			end
		else
			frame.roleIconERF:Hide()
		end

		frame.roleIcon:Hide()
		frame.roleIcon:SetWidth(1)
	else
		frame.roleIconERF:Hide()
	end
end

function ADDON.RoleIcon_Revert()
	for frame in ADDON.IterateCompactFrames() do
		if frame.roleIconERF then
			frame.roleIconERF:Hide()

			if UnitExists(frame.unit) then
				CompactUnitFrame_UpdateRoleIcon(frame)
			end
		end
	end
end