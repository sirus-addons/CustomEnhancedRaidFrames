local ADDON_NAME, PRIVATE = ...
local ADDON = PRIVATE.ADDON
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

local LCG = LibStub("LibCustomGlow-1.0")

local _G = _G
local ipairs = ipairs
local pairs = pairs
local select = select
local tostring = tostring
local min = math.min
local strfind, strformat, strgmatch, strgsub, strlower, strmatch, strsplit, strtrim = string.find, string.format, string.gmatch, string.gsub, string.lower, string.match, string.split, string.trim

local CreateFrame = CreateFrame
local GetNumRaidMembers = GetNumRaidMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitHasVehicleUI = UnitHasVehicleUI
local UnitInRaid = UnitInRaid
local UnitInVehicle = UnitInVehicle

local RAID_CLASS_COLORS = RAID_CLASS_COLORS

-- GLOBALS: DefaultCompactUnitFrameSetupOptions, LibStub, UIParent

local subFrameTypes = {"debuffFrames", "buffFrames", "dispelDebuffFrames"}

ADDON.NATIVE_UNIT_FRAME_HEIGHT = 36
ADDON.NATIVE_UNIT_FRAME_WIDTH = 72
ADDON.CUF_AURA_BOTTOM_OFFSET = 2

ADDON.debuffsColors = {
	magic = {0.2, 0.6, 1.0, 1},
	curse = {0.6, 0.0, 1.0, 1},
	disease = {0.6, 0.4, 0.0, 1},
	poison = {0.0, 0.6, 0.0, 1},
	physical = {1, 1, 1, 1}
}

ADDON.textMirrors = {
	["TOPLEFT"] = {"TOPRIGHT", "LEFT"},
	["LEFT"] = {"RIGHT", "LEFT"},
	["BOTTOMLEFT"] = {"BOTTOMRIGHT", "LEFT"},
	["BOTTOMRIGHT"] = {"BOTTOMLEFT", "RIGHT"},
	["RIGHT"] = {"LEFT", "RIGHT"},
	["TOPRIGHT"] = {"BOTTOMLEFT", "RIGHT"},
}

ADDON.mirrorPositions = {
	["LEFT"] = {"BOTTOMRIGHT", "BOTTOMLEFT"},
	["BOTTOM"] = {"TOPLEFT", "BOTTOMLEFT"},
	["RIGHT"] = {"BOTTOMLEFT", "BOTTOMRIGHT"},
	["TOP"] = {"BOTTOMLEFT", "TOPLEFT"},
}

ADDON.smartAnchoring = {
	["BOTTOM"] = {"LEFT", "RIGHT"},
	["TOP"] = {"LEFT", "RIGHT"},
	["RIGHT"] = {"BOTTOM", "TOP"},
	["LEFT"] = {"BOTTOM", "TOP"},
}

ADDON.smartAnchoringRowsPositions = {
	["LEFT"] = {
		["BOTTOM"] = {"TOPRIGHT", "TOPLEFT"},
		["TOP"] = {"BOTTOMRIGHT", "BOTTOMLEFT"},
	},
	["BOTTOM"] = {
		["LEFT"] = {"TOPRIGHT", "BOTTOMRIGHT"},
		["RIGHT"] = {"TOPLEFT", "BOTTOMLEFT"},
	},
	["RIGHT"] = {
		["BOTTOM"] = {"TOPLEFT", "TOPRIGHT"},
		["TOP"] = {"BOTTOMLEFT", "BOTTOMRIGHT"},
	},
	["TOP"] ={
		["LEFT"] = {"BOTTOMRIGHT", "TOPRIGHT"},
		["RIGHT"] = {"BOTTOMLEFT", "TOPLEFT"},
	},
}

ADDON.rowsPositions = {
	["LEFT"] = {"TOPRIGHT", "TOPLEFT"},
	["BOTTOM"] = {"TOPRIGHT", "BOTTOMRIGHT"},
	["RIGHT"] = {"BOTTOMLEFT", "BOTTOMRIGHT"},
	["TOP"] = {"BOTTOMLEFT", "TOPLEFT"},
}

ADDON.rowsGrows = {
	["TOPLEFT"] = {
		["LEFT"] = "BOTTOM",
		["BOTTOM"] = "RIGHT",
		["RIGHT"] = "BOTTOM",
		["TOP"] = "RIGHT",
	},
	["LEFT"] = {
		["LEFT"] = "BOTTOM",
		["BOTTOM"] = "RIGHT",
		["RIGHT"] = "BOTTOM",
		["TOP"] = "RIGHT",
	},
	["BOTTOMLEFT"] = {
		["LEFT"] = "TOP",
		["BOTTOM"] = "RIGHT",
		["RIGHT"] = "TOP",
		["TOP"] = "RIGHT",
	},
	["BOTTOM"] = {
		["LEFT"] = "TOP",
		["BOTTOM"] = "RIGHT",
		["RIGHT"] = "TOP",
		["TOP"] = "RIGHT",
	},
	["BOTTOMRIGHT"] = {
		["LEFT"] = "TOP",
		["BOTTOM"] = "LEFT",
		["RIGHT"] = "TOP",
		["TOP"] = "LEFT",
	},
	["RIGHT"] = {
		["LEFT"] = "TOP",
		["BOTTOM"] = "LEFT",
		["RIGHT"] = "TOP",
		["TOP"] = "LEFT",
	},
	["TOPRIGHT"] = {
		["LEFT"] = "BOTTOM",
		["BOTTOM"] = "LEFT",
		["RIGHT"] = "BOTTOM",
		["TOP"] = "LEFT",
	},
	["TOP"] = {
		["LEFT"] = "BOTTOM",
		["BOTTOM"] = "LEFT",
		["RIGHT"] = "BOTTOM",
		["TOP"] = "LEFT",
	},
	["CENTER"] = {
		["LEFT"] = "TOP",
		["BOTTOM"] = "RIGHT",
		["RIGHT"] = "TOP",
		["TOP"] = "RIGHT",
	}
}

function ADDON.GetUnitRole(unit)
	if UnitInVehicle(unit) and UnitHasVehicleUI(unit) then
		return "VEHICLE"
	end

	local raidID = UnitInRaid(unit)
	if raidID and select(10, GetRaidRosterInfo(raidID + 1)) then
		return (select(10, GetRaidRosterInfo(raidID + 1))) or "NONE", true
	else
		local isTank, isHealer, isDamage = UnitGroupRolesAssigned(unit);
		local role = isTank and "TANK" or isHealer and "HEALER" or isDamage and "DAMAGER"
		return role or "NONE"
	end
end

function ADDON:SetUpSubFramesPositionsAndSize(frame, subFrameType, groupType, virtual)
	local frameNum = 1
	local typedframe, anchor1, anchor2, relativeFrame, xOffset, yOffset
	local db = self.db.profile[groupType][subFrameType]
	local size = db.size * (subFrameType ~= "dispelDebuffFrames" and self.ComponentScale(groupType) or 1)
	local typedframes = virtual and self.virtual.frames[subFrameType] or frame[subFrameType]

	while frameNum <= #typedframes do
		if frameNum == 1 then
			anchor1, relativeFrame, anchor2 = db.anchorPoint, frame, db.anchorPoint
		elseif frameNum % (db.numInRow) == 1 then
			anchor1, relativeFrame, anchor2 = self.rowsPositions[db.rowsGrowDirection][1], typedframes[frameNum - db.numInRow], self.rowsPositions[db.rowsGrowDirection][2]
		else
			anchor1, relativeFrame, anchor2 = self.mirrorPositions[db.growDirection][1], typedframes[frameNum - 1], self.mirrorPositions[db.growDirection][2]
		end

		if frameNum == 1 then
			xOffset, yOffset = self:Offsets(anchor1, frame, groupType)
			xOffset = xOffset + db.xOffset
			yOffset = yOffset + db.yOffset
		else
			xOffset, yOffset = 0, 0
		end

		typedframe = typedframes[frameNum]
		typedframe:ClearAllPoints()
		typedframe:SetPoint(anchor1, relativeFrame, anchor2, xOffset, yOffset)

		typedframe:SetSize(size, size)
		typedframe:SetAlpha(db.alpha)

		if self.db.profile[groupType].frames.clickThrough then
			typedframe:EnableMouse(false)
		else
			typedframe:EnableMouse(true)
		end

		frameNum = frameNum + 1
	end
end

function ADDON.StartGlow(frame, db, color, key, gType)
	if not db.enabled then return end

	local glowType = db.type
	local glowOptions = db.options[glowType]
	local options = glowOptions.options
	color = color or options.color

	if glowType == "button" then
		LCG.ButtonGlow_Start(frame, color, options.frequency)
	elseif glowType == "pixel" then
		LCG.PixelGlow_Start(frame, color, options.N, options.frequency, options.length, options.th, options.xOffset, options.yOffset, options.border, key or "")
	elseif glowType == "auto" then
		LCG.AutoCastGlow_Start(frame, color, options.N, options.frequency, options.scale, options.xOffset, options.yOffset, key or "")
	end

	ADDON.glowingFrames[gType][key][frame] = color
end

function ADDON.StopGlow(frame, db, key, gType)
	if db.type == "button" then
		LCG.ButtonGlow_Stop(frame, key or "")
	elseif db.type == "pixel" then
		LCG.PixelGlow_Stop(frame, key or "")
	elseif db.type == "auto" then
		LCG.AutoCastGlow_Stop(frame, key or "")
	end

	ADDON.glowingFrames[gType][key][frame] = nil
end

function ADDON.MasqueSupport(frame)
	if not ADDON.Masque then return end
	local enabled = ADDON.db.profile.Masque

	for _, typedframe in ipairs(frame.buffFrames) do
		if enabled then
			ADDON.Masque.buffFrames:AddButton(typedframe)
		else
			ADDON.Masque.buffFrames:RemoveButton(typedframe)
		end
	end

	for _, typedframe in ipairs(frame.debuffFrames) do
		if enabled then
			ADDON.Masque.debuffFrames:AddButton(typedframe)
		else
			ADDON.Masque.debuffFrames:RemoveButton(typedframe)
		end
	end
end

function ADDON:SetUpMainSubFramePosition(frame, subFrameType, groupType)
	if not frame[subFrameType] or not frame[subFrameType][1] then return end

	local db = self.db.profile[groupType][subFrameType]

	local anchor1, relativeFrame, anchor2 = db.anchorPoint, frame, db.anchorPoint

	local xOffset, yOffset = self:Offsets(anchor1, frame, groupType)
	xOffset = xOffset + db.xOffset
	yOffset = yOffset + db.yOffset

	frame[subFrameType][1]:ClearAllPoints()
	frame[subFrameType][1]:SetPoint(anchor1, relativeFrame, anchor2, xOffset, yOffset)
end

function ADDON:Offsets(anchor, frame, groupType, force)
	local displayPowerBar, powerBarUsedHeight

	if not force then
		if self.db.profile[groupType].frames.showResourceOnlyForHealers and self.displayPowerBar then
			displayPowerBar = frame.unit and UnitGroupRolesAssigned(frame.unit) == "HEALER"
		else
			displayPowerBar = self.displayPowerBar
		end

		powerBarUsedHeight = (displayPowerBar and self.db.profile[groupType].frames.powerBarHeight or 0) + self.CUF_AURA_BOTTOM_OFFSET
	else
		powerBarUsedHeight = (self.displayPowerBar and self.db.profile[groupType].frames.powerBarHeight or 0) + self.CUF_AURA_BOTTOM_OFFSET
	end

	local xOffset, yOffset = 0, 0

	if anchor == "LEFT" then
		xOffset, yOffset = 3, 0
	elseif anchor == "RIGHT" then
		xOffset, yOffset = -3, 0
	elseif anchor == "TOP" then
		xOffset, yOffset = 0, -3
	elseif anchor == "BOTTOM" then
		xOffset, yOffset = 0, powerBarUsedHeight
	elseif anchor == "BOTTOMLEFT" then
		xOffset, yOffset = 3, powerBarUsedHeight
	elseif anchor == "BOTTOMRIGHT" then
		xOffset, yOffset = -3, powerBarUsedHeight
	elseif anchor == "TOPLEFT" then
		xOffset, yOffset = 3, -3
	elseif anchor == "TOPRIGHT" then
		xOffset, yOffset = -3, -3
	end

	return xOffset, yOffset
end

function ADDON:AddSubFrames(frame, groupType)
	if not self.IsFrameOk(frame) then return end

	for subFrameType in self.IterateSubFrameTypes() do
		local frameName, template
		local db = self.db.profile[groupType][subFrameType]

		if subFrameType == "buffFrames" then
			template = "CompactBuffTemplate"
			frameName = frame:GetName().."Buff"
		elseif subFrameType == "debuffFrames" then
			template = "CompactDebuffTemplate"
			frameName = frame:GetName().."Debuff"
		elseif subFrameType == "dispelDebuffFrames" then
			template = "CompactDispelDebuffTemplate"
			frameName = frame:GetName().."DispelDebuff"
		end

		for i = #frame[subFrameType] + 1, db.num do
			local typedFrame = _G[frameName..i] or CreateFrame("Button", frameName..i, frame, template)

			typedFrame:ClearAllPoints()
			typedFrame:Hide()
		end
	end
end

function ADDON.UpdateAllCompactFrames(func)
	local groupType = ADDON.GetGroupType()
	if type(func) == "function" then
		for frame in ADDON.IterateCompactFrames(groupType) do
			func(frame)
		end

		if ADDON.virtual.shown then
			ADDON:ShowVirtual()
		end
	else
		ADDON:SafeRefresh(groupType)
	end
end

function ADDON:FilterAuras(name, debuffType, spellId, frameType)
	local groupType = ADDON.GetGroupType()
	local db = self.db.profile[groupType][frameType]

	local excluded = self:FilterAurasInternal(name, debuffType, spellId, db.exclude)
	if excluded then
		return false
	else
		return true
	end
end

function ADDON:FilterAurasInternal(name, debuffType, spellId, db)
	if #db == 0 then return false end

	name = name and self.SanitazeString(name)
	debuffType = debuffType and self.SanitazeString(debuffType)
	spellId = tostring(spellId)

	for _, aura in ipairs(db) do
		if aura ~= nil and (aura == name or aura == debuffType or (spellId ~= nil and aura == spellId)) then
			return true
		end
	end

	return false
end

function ADDON:AdditionalAura(name, debuffType, spellId, unitCaster)
	local groupType = ADDON.GetGroupType()
	local db = self.db.profile[groupType].frames.tracking
	if #db == 0 then return false end

	name = name and self.SanitazeString(name)
	debuffType = debuffType and self.SanitazeString(debuffType)
	spellId = tostring(spellId)

	for _, auraData in ipairs(db) do
		local aura = auraData[1]
		if aura == name or aura == debuffType or aura == spellId then
			local unit = auraData[2]
			if not unit then
				return true
			elseif unit == unitCaster then
				return true
			end
		end
	end

	return false
end

function ADDON:SmartAnchoring(frame, groupType, virtual)
	local db = self.db.profile[groupType].debuffFrames
	local typedframes = virtual and self.virtual.frames.debuffFrames or frame.debuffFrames
	local frameNum = 1
	local typedframe, anchor1, anchor2, relativeFrame, xOffset, yOffset

	local size = db.size * self.ComponentScale(groupType)
	local bigSize = size * 2
	local rowStart = 1
	local actualGroupType = ADDON.GetGroupType()

	while frameNum <= #typedframes do
		local rowLen = db.numInRow
		local index = 1
		local bigs = 0

		if typedframe and not typedframe:IsShown() then
			break
		end

		while true do
			if frameNum > #typedframes then break end

			typedframe = typedframes[frameNum]

			if typedframe and not typedframe:IsShown() then
				break
			end

			typedframe:ClearAllPoints()

			if frameNum == 1 then
				anchor1, relativeFrame, anchor2 = db.anchorPoint, frame, db.anchorPoint
			elseif index == 1 then
				anchor1, relativeFrame, anchor2 = self.smartAnchoringRowsPositions[db.rowsGrowDirection][db.growDirection][1], typedframes[rowStart], self.smartAnchoringRowsPositions[db.rowsGrowDirection][db.growDirection][2]
				rowStart = frameNum
			elseif index % rowLen == 1 then
				if bigs > 0 and rowLen > bigs then
					for j=1, rowLen - (bigs * 2) do
						if frameNum > #typedframes then break end

						typedframe = typedframes[frameNum]
						anchor1, relativeFrame, anchor2 = self.smartAnchoring[db.growDirection][1], typedframes[frameNum - (rowLen - (bigs * 2))], self.smartAnchoring[db.growDirection][2]

						typedframe:ClearAllPoints()
						typedframe:SetPoint(anchor1, relativeFrame, anchor2, xOffset, yOffset)
						typedframe:SetSize(typedframe.isBossAura and bigSize or size, typedframe.isBossAura and bigSize or size)

						frameNum = frameNum + 1
					end
				end
				break
			else
				anchor1, relativeFrame, anchor2 = self.mirrorPositions[db.growDirection][1], typedframes[frameNum - 1], self.mirrorPositions[db.growDirection][2]
			end

			if frameNum == 1 then
				xOffset, yOffset = self:Offsets(anchor1, frame, actualGroupType)
				xOffset = xOffset + db.xOffset
				yOffset = yOffset + db.yOffset
			else
				xOffset, yOffset = 0, 0
			end

			typedframe:SetPoint(anchor1, relativeFrame, anchor2, xOffset, yOffset)
			typedframe:SetSize(typedframe.isBossAura and bigSize or size, typedframe.isBossAura and bigSize or size)

			frameNum = frameNum + 1

			if typedframe.isBossAura then
				index = index + 2
				bigs = bigs + 1

				if index > rowLen then break end
			else
				index = index + 1
			end
		end
	end
end

function ADDON.ColorByClass(unit)
	local _, class = UnitClass(unit)

	if class then
		return RAID_CLASS_COLORS[class]
	else
		return RAID_CLASS_COLORS.PRIEST
	end
end

function ADDON.ReverseGroupType(groupType)
	return groupType == "party" and "raid" or "party"
end

function ADDON.IterateCompactFrames(groupType)
	local index = 0
	local groupIndex = 1
	local frame, doneRaid, doneParty, doneOldStyle

	if groupType then
		if groupType == "raid" then
			doneParty = true
		else
			doneRaid = true
		end
	end

	return function()
		while not doneRaid do
			index = index + 1

			if index > 5 then
				index = 1
				groupIndex = groupIndex + 1
			end

			frame = _G["CompactRaidGroup"..groupIndex.."Member"..index]

			if frame then
				return frame
			else
				if groupIndex >= 8 then
					doneRaid = true
					index = 0
					break
				end
			end
		end

		while not doneParty do
			index = index + 1
			frame = _G["CompactPartyFrameMember"..index]

			if frame then
				return frame
			else
				index = 0
				doneParty = true
				break
			end
		end

		while not doneOldStyle do
			index = index + 1
			frame = _G["CompactRaidFrame"..index]

			if frame then
				return frame
			else
				doneOldStyle = true
				break
			end
		end
	end
end

function ADDON.IterateCompactGroups(isInRaid)
	local groupIndex = 0
	local groupFrame

	return function()
		while groupIndex <= 8 do
			groupIndex = groupIndex + 1

			if isInRaid == "raid" then
				groupFrame = _G["CompactRaidGroup"..groupIndex]
			else
				groupFrame = _G["CompactPartyFrame"]
				groupIndex = 9
			end

			if groupFrame then
				return groupFrame
			end
		end
	end
end

function ADDON.IterateSubFrameTypes(exclude)
	local index = 0
	local len = #subFrameTypes

	return function()
		index = index + 1
		if index <= len and subFrameTypes[index] ~= exclude then
			return subFrameTypes[index]
		end
	end
end

function ADDON.SanitazeString(str)
	local key = strmatch(str, "[^--]+")

	if not key then return end

	key = strtrim(key)
	key = strlower(key)
	key = strgsub(key, "\"", "")
	key = strgsub(key, ",", "")

	return key
end

function ADDON.SanitizeStrings(str)
	local t = {}
	local index = 1

	for value in strgmatch(str, "[^\n]+") do
		local key = ADDON.SanitazeString(value)
		if key then
			t[index] = key
			index = index + 1
		end
	end

	return t
end

function ADDON.SanitizeStringsByUnit(str)
	local t = {}
	local index = 1

	for value in strgmatch(str, "[^\n]+") do
		local key = ADDON.SanitazeString(value)
		if key then
			t[index] = {strsplit("::", key)}
			index = index + 1
		end
	end

	return t
end

function ADDON:TrackAuras(name, debuffType, spellID, db)
	for _, aura in ipairs(db) do
		if aura == name or aura == debuffType or aura == spellID then
			if not self:ExcludeAuras(name, debuffType, spellID) then
				return true
			end
		end
	end
end

function ADDON:ExcludeAuras(name, debuffType, spellID)
	for _, exclude in ipairs(self.db.profile.glows.glowBlockList.tracking) do
		if exclude == name or exclude == debuffType or exclude == spellID then
			return true
		end
	end
end

function ADDON:CompressData(data)
	local LibDeflate = LibStub("LibDeflate")
	local LibAceSerializer = LibStub("AceSerializer-3.0")

	if LibDeflate and LibAceSerializer then
		local dataSerialized = LibAceSerializer:Serialize(data)
		if dataSerialized then
			local dataCompressed = LibDeflate:CompressDeflate(dataSerialized, {level = 9})
			if dataCompressed then
				local dataEncoded = LibDeflate:EncodeForPrint(dataCompressed)
				return dataEncoded
			end
		end
	end
end

function ADDON:DecompressData(data)
	local LibDeflate = LibStub("LibDeflate")
	local LibAceSerializer = LibStub("AceSerializer-3.0")

	if LibDeflate and LibAceSerializer then
		local dataCompressed = LibDeflate:DecodeForPrint(data)
		if not dataCompressed then
			self:Print(L["Couldn't decode the data"])
			return false
		end

		local dataSerialized = LibDeflate:DecompressDeflate(dataCompressed)
		if not dataSerialized then
			self:Print(L["Couldn't uncompress the data"])
			return false
		end

		local success, result = LibAceSerializer:Deserialize(dataSerialized)
		if not success then
			self:Print(L["Couldn't unserialize the data"])
			return false
		end

		return result
	end
end

function ADDON:ExportProfileToString()
	local profile = self.db.profile

	local data = self:CompressData(profile)
	if not data then
		self:Print(L["Failed to compress the profile"])
	end

	return data
end

function ADDON:ExportCurrentProfile(text)
	if not self.ProfileFrame then
		local frame = CreateFrame("Frame", strformat("%sProfileFrame", ADDON_NAME), UIParent, "UIPanelDialogTemplate")
		frame:SetSize(700, 300)
		frame:SetPoint("CENTER")
		frame:EnableMouse(true)
		frame:SetClampedToScreen(true)

		local title = frame:CreateFontString("$parentTitle", "OVERLAY", "ChatFontNormal")
		title:SetPoint("TOP", 0, -7)
		title:SetPoint("LEFT", 60, 0)
		title:SetPoint("RIGHT", -60, 0)
		title:SetWordWrap(false)
		title:SetText(L["Export Profile"])
		frame.title = title

		local scrollFrame = CreateFrame("ScrollFrame", "$parentScrollFrame", frame, "UIPanelScrollFrameTemplate")
		scrollFrame:SetPoint("TOPLEFT", 16, -32)
		scrollFrame:SetPoint("RIGHT", -32, -8)
		frame.scrollFrame = scrollFrame

		local editbox = CreateFrame("EditBox", "$parentEditBox", scrollFrame)
		editbox:SetSize(scrollFrame:GetSize())
		editbox:SetMultiLine(true)
		editbox:SetAutoFocus(true)
		editbox:SetFontObject("ChatFontNormal")
		editbox:SetScript("OnEscapePressed", function() frame:Hide() end)
		scrollFrame:SetScrollChild(editbox)
		frame.editbox = editbox

		self.ProfileFrame = frame
	end

	self.ProfileFrame.editbox:SetText(text)
	self.ProfileFrame.editbox:HighlightText()
	self.ProfileFrame:Show()
end

function ADDON:ImportCurrentProfile(text)
	local db = self:DecompressData(text)
	if not db then return end

	self.db:SetProfile(db.current_profile)

	for k, v in pairs(db) do
		self.db.profile[k] = v
	end
end

function ADDON.IsFrameOk(frame)
	return frame and (UnitExists(frame.displayedUnit)) and not (frame.unit and strfind(frame.unit, "pet", 1, true))
end

local ABBREVIATE_FORMAT = {
	[1] = "%.1f%s",
	[2] = "%.2f%s",
	[3] = "%.3f%s",
}

function ADDON.Abbreviate(num, precision)
	if precision == 0 or num < 1000 then
		return num
	elseif num < 1000000 then
		return strformat(ABBREVIATE_FORMAT[precision], num / 1000, "K")
	else
		return strformat(ABBREVIATE_FORMAT[precision], num / 1000000, "M")
	end
end

function ADDON.ComponentScale(groupType)
	if not ADDON.db.profile[groupType].frames.autoScaling then
		return 1
	end

	local scale = min(
		DefaultCompactUnitFrameSetupOptions.height / ADDON.NATIVE_UNIT_FRAME_HEIGHT,
		DefaultCompactUnitFrameSetupOptions.width / ADDON.NATIVE_UNIT_FRAME_WIDTH
	)

	return scale > 0 and scale or 1
end

function ADDON.GetGroupType()
--	return (GetDisplayedAllyFrames() == "raid" or GetNumRaidMembers() > 0) and "raid" or "party"
	return (GetNumRaidMembers() > 0 or GetNumPartyMembers() == 0) and "raid" or "party"
end

function ADDON.GetGroupTypeDB()
	return ADDON.db.profile[ADDON.GetGroupType()]
end