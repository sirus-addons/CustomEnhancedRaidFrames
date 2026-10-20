local ADDON_NAME, PRIVATE = ...
local ADDON = PRIVATE.ADDON
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

local SharedMedia = LibStub("LibSharedMedia-3.0")

local max = math.max
local unpack = unpack

local CreateFrame = CreateFrame
local GetUnitName = GetUnitName
local UnitPowerType = UnitPowerType

-- GLOBALS: InterfaceOptionsFrame, PowerBarColor, UIParent

local ICONS = {
	buffFrames = "Interface\\Icons\\ability_rogue_sprint",
	debuffFrames = "Interface\\Icons\\ability_rogue_kidneyshot",
	dispelDebuffFrames = "Interface\\RaidFrame\\Raid-Icon-DebuffMagic",
}

local function CreateIcon(frame, subFrameType, index)
	local icon = CreateFrame("Button", nil, frame)
	icon:SetFrameLevel(frame:GetFrameLevel() + 2)

	local texture = icon:CreateTexture(nil, "ARTWORK")
	texture:SetAllPoints()
	texture:SetTexture(ICONS[subFrameType])

	local text = icon:CreateFontString(nil, "OVERLAY")
	text:SetFont("Fonts\\FRIZQT__.TTF", 11, "THICKOUTLINE, MONOCHROME")
	text:SetPoint("CENTER")
	text:SetText(index)

	return icon
end

local function CreateTestFrame()
	local frame = CreateFrame("Frame", ADDON_NAME.."TestFrame", UIParent)
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		self:SetUserPlaced(false)
	end)
	frame:SetPoint("RIGHT", InterfaceOptionsFrame, "LEFT", -40, 0)
	frame:Hide()

	frame.unit = "player"
	frame.displayedUnit = "player"
	frame.optionTable = {}

	frame.background = frame:CreateTexture(nil, "BACKGROUND")
	frame.background:SetAllPoints()
	frame.background:SetTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Bg")
	frame.background:SetTexCoord(0, 1, 0, 0.53125)

	frame.healthBar = CreateFrame("StatusBar", nil, frame)
	frame.healthBar:SetPoint("TOPLEFT", 1, -1)
	frame.healthBar:SetMinMaxValues(0, 1)
	frame.healthBar:SetValue(0.8)

	frame.healthBar.background = frame.healthBar:CreateTexture(nil, "BACKGROUND")
	frame.healthBar.background:SetAllPoints()

	frame.powerBar = CreateFrame("StatusBar", nil, frame)
	frame.powerBar:SetPoint("BOTTOMLEFT", 1, 1)
	frame.powerBar:SetPoint("BOTTOMRIGHT", -1, 1)
	frame.powerBar:SetMinMaxValues(0, 1)
	frame.powerBar:SetValue(1)

	frame.name = frame.healthBar:CreateFontString(nil, "OVERLAY")

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.title:SetPoint("BOTTOM", frame, "TOP", 0, 4)

	frame.buffFrames = {}
	frame.debuffFrames = {}
	frame.dispelDebuffFrames = {}
	frame.ERFAuraFrames = {
		buffFrames = frame.buffFrames,
		debuffFrames = frame.debuffFrames,
		dispelDebuffFrames = frame.dispelDebuffFrames,
	}

	return frame
end

function ADDON:ShowVirtual(groupType)
	groupType = groupType or self.virtual.groupType
	self.virtual.groupType = groupType
	self.virtual.shown = true

	local frame = self.virtual.frame or CreateTestFrame()
	self.virtual.frame = frame

	local db = self.db.profile[groupType]

	frame:SetSize(self.GetUnitFrameSize(groupType))
	frame.title:SetText(L["Test Frame"]..": "..(groupType == "party" and L["Party"] or L["Raid"]))

	local showPowerBar = self.displayPowerBar and (not self:ShowResourceOnlyForHealers(groupType) or self.GetUnitRole("player") == "HEALER")

	local r, g, b = 0, 1, 0
	if self.useClassColors then
		local color = self.ColorByClass("player")
		r, g, b = color.r, color.g, color.b
	elseif db.frames.colorEnabled then
		r, g, b = unpack(db.frames.color, 1, 3)
	end

	frame.healthBar:SetPoint("BOTTOMRIGHT", -1, 1 + (showPowerBar and db.frames.powerBarHeight or 0))
	frame.healthBar:SetStatusBarTexture(SharedMedia:Fetch("statusbar", db.frames.texture))
	frame.healthBar:SetStatusBarColor(r, g, b)
	frame.healthBar:SetAlpha(db.frames.alpha)

	if db.frames.colorEnabled then
		frame.healthBar.background:SetTexture(unpack(db.frames.backgroundColor, 1, 3))
	else
		frame.healthBar.background:SetTexture(nil)
	end
	frame.healthBar.background:SetAlpha(db.frames.backgoundAlpha)
	frame.background:SetAlpha(db.frames.backgoundAlpha)

	local powerColor = PowerBarColor[UnitPowerType("player")]
	frame.powerBar:SetShown(showPowerBar)
	frame.powerBar:SetHeight(db.frames.powerBarHeight)
	frame.powerBar:SetStatusBarTexture(SharedMedia:Fetch("statusbar", db.frames.powerBarTexture))
	frame.powerBar:SetStatusBarColor(powerColor.r, powerColor.g, powerColor.b)
	frame.powerBar:SetAlpha(db.frames.alpha)

	frame.name:SetFontObject("GameFontHighlightSmall")
	frame.name:SetJustifyH("LEFT")
	frame.name:SetTextColor(1, 1, 1)
	frame.name:SetText(GetUnitName("player"))
	frame.name:ClearAllPoints()
	frame.name:SetPoint("TOPLEFT", 3, -3)
	frame.name:SetPoint("TOPRIGHT", -3, -3)
	frame.name:Show()
	self.Name_Setup(frame, groupType)

	for subFrameType in self.IterateSubFrameTypes() do
		local num = db[subFrameType].num
		local icons = frame[subFrameType]

		for i = 1, max(num, #icons) do
			local icon = icons[i] or CreateIcon(frame, subFrameType, i)
			icons[i] = icon
			icon.isBossAura = nil
			icon:SetShown(i <= num)
		end

		self:SetUpSubFramesPositionsAndSize(frame, subFrameType, groupType)
	end

	local debuffs = db.debuffFrames
	if debuffs.showBigDebuffs and debuffs.num > 0 then
		local icon = frame.debuffFrames[1]
		local size = debuffs.bigDebuffSize * self.ComponentScale(groupType)
		icon:SetSize(size, size)
		icon.isBossAura = true

		if debuffs.smartAnchoring then
			self:SmartAnchoring(frame, groupType)
		end
	end

	frame:Show()
end

function ADDON:HideVirtual()
	self.virtual.shown = nil

	if self.virtual.frame then
		self.virtual.frame:Hide()
	end
end

function ADDON:VirtualFramesToggle()
	if self.virtual.shown then
		self:HideVirtual()
	else
		self:ShowVirtual()
	end
end
