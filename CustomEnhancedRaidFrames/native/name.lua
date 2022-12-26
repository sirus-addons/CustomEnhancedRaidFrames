local ADDON_NAME, PRIVATE = ...
local ADDON = PRIVATE.ADDON

local SharedMedia = LibStub("LibSharedMedia-3.0")

local max, min = math.max, math.min

local CompactUnitFrame_IsTapDenied = CompactUnitFrame_IsTapDenied
local GetUnitName = GetUnitName
local UnitExists = UnitExists

-- GLOBALS: CompactUnitFrame_UpdateName, DefaultCompactUnitFrameSetupOptions

function ADDON.CompactUnitFrame_UpdateName(frame, groupType)
	local db = ADDON.db.profile[groupType].nameAndIcons

	if not db.name.enabled or not db.name.freeAnchor then
		frame.name:ClearAllPoints()

		if not db.roleGroupIcon.enabled then
			frame.name:SetPoint("TOPLEFT", frame.roleGroupIcon, "TOPRIGHT", 0, 1)
		elseif not db.roleIcon.enabled then
			frame.name:SetPoint("TOPLEFT", frame.roleIcon, "TOPRIGHT", 0, 1)
		elseif not db.raidTargetIcon.enabled then
			frame.name:SetPoint("TOPLEFT", frame.raidTargetIcon, "TOPRIGHT", 0, 1)
		else
			frame.name:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -1)
		end

		frame.name:SetPoint("TOPRIGHT", -3, -3);
	end

	ADDON.Name_Update(frame, groupType)
end

function ADDON.Name_Setup(frame, groupType)
	if not frame.name then return end

	local db = ADDON.db.profile[groupType].nameAndIcons.name
	if not db.enabled then
		return
	end

	if db.freeAnchor then
		local xOffset, yOffset = ADDON:Offsets("TOPLEFT", frame, groupType)
		xOffset = xOffset + db.xOffset
		yOffset = yOffset + db.yOffset

		frame.name:ClearAllPoints()
		frame.name:SetPoint("TOPLEFT", frame, "TOPLEFT", xOffset, yOffset)
		frame.name:SetPoint("TOPRIGHT", frame, "TOPRIGHT", xOffset, yOffset)
	end

	local flags = db.flag ~= "None" and db.flag or ""
	local font = SharedMedia:Fetch("font", db.font) or SharedMedia:Fetch("font", ADDON.font)
	local size = db.size * ADDON.ComponentScale(groupType)

	frame.name:SetFont(font, size, flags)

	frame.name:SetJustifyH(db.hJustify)
	frame.name:SetHeight(size)

	ADDON.Name_Update(frame, groupType)
end

function ADDON.Name_Update(frame, groupType)
	if not frame.unit or not frame.name then return end
	if not UnitExists(frame.displayedUnit) then return end

	local db = ADDON.db.profile[groupType].nameAndIcons.name
	if not db.enabled then
		return
	elseif db.hide then
		frame.name:Hide()
		return
	end

	local name

	if db.showServer then
		name = GetUnitName(frame.unit, true)
	else
		name = GetUnitName(frame.unit, false)
		name = name and name:gsub("%p", "")
	end

	if name and name ~= "" then
		frame.name:SetText(name)
	end

	if db.useClassColor then
		local classColor = ADDON.ColorByClass(frame.unit)
		frame.name:SetTextColor(classColor.r, classColor.g, classColor.b)
	else
		if CompactUnitFrame_IsTapDenied(frame) then
			frame.name:SetVertexColor(0.5, 0.5, 0.5)
		else
			frame.name:SetVertexColor(1.0, 1.0, 1.0)
		end
	end
end

local NATIVE_UNIT_FRAME_HEIGHT = 36;
local NATIVE_UNIT_FRAME_WIDTH = 72;
function ADDON.Name_Revert()
	for frame in ADDON.IterateCompactFrames() do
		if UnitExists(frame.unit) then
			local options = DefaultCompactUnitFrameSetupOptions
			local componentScale = min(options.height / NATIVE_UNIT_FRAME_HEIGHT, options.width / NATIVE_UNIT_FRAME_WIDTH)
			local NAME_LINE_HEIGHT = min(10 * max(1.15, componentScale), 14)

			local font, _, fontFlagsN = frame.name:GetFontObject():GetFont()
			frame.name:SetFont(font, NAME_LINE_HEIGHT, fontFlagsN)
			frame.name:SetHeight(NAME_LINE_HEIGHT)

			frame.name:SetJustifyH("LEFT")
			frame.name:SetVertexColor(1.0, 1.0, 1.0)

			if CompactUnitFrame_IsTapDenied(frame) then
				frame.name:SetVertexColor(0.5, 0.5, 0.5)
			else
				frame.name:SetVertexColor(1.0, 1.0, 1.0)
			end

			CompactUnitFrame_UpdateName(frame)
		end
	end
end