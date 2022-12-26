local ADDON_NAME, PRIVATE = ...
local ADDON = PRIVATE.ADDON
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

ADDON.AURA_TYPES = {
	BUFF = 1,
	DEBUFF = 2,
	DISPEL = 3,
}

local POSITIONS = {
	TOPLEFT		= L["TOPLEFT"],
	LEFT		= L["LEFT"],
	BOTTOMLEFT	= L["BOTTOMLEFT"],
	BOTTOM		= L["BOTTOM"],
	BOTTOMRIGHT	= L["BOTTOMRIGHT"],
	RIGHT		= L["RIGHT"],
	TOPRIGHT	= L["TOPRIGHT"],
	TOP			= L["TOP"],
	CENTER		= L["CENTER"],
}

local GROW_POSITIONS = {
	LEFT		= L["LEFT"],
	BOTTOM		= L["BOTTOM"],
	RIGHT		= L["RIGHT"],
	TOP			= L["TOP"],
}

function ADDON:SetupAuraFrames(groupType, auraType)
	local auraTypeDB
	if auraType == ADDON.AURA_TYPES.BUFF then
		auraTypeDB = "buffFrames"
	elseif auraType == ADDON.AURA_TYPES.DEBUFF then
		auraTypeDB = "debuffFrames"
	elseif auraType == ADDON.AURA_TYPES.DISPEL then
		auraTypeDB = "dispelDebuffFrames"
	end

	local options = {
		num = {
			order = 1,
			type = "range",
			min = 0, max = 10, step = 1,
			width = "normal",
			name = L["Num"],
			desc = "",
			set = function(info, val)
				self.db.profile[groupType][auraTypeDB].num = val
				self.UpdateAllCompactFrames(self.CompactUnitFrame_UpdateAuras)
			end,
			get = function(info)
				return self.db.profile[groupType][auraTypeDB].num
			end
		},
		size = {
			order = 2,
			type = "range",
			min = 1, max = 100, step = 1,
			width = "normal",
			name = L["Size"],
			desc = "",
			set = function(info, val)
				self.db.profile[groupType][auraTypeDB].size = val
				self:SafeRefresh(groupType)
			end,
			get = function(info)
				return self.db.profile[groupType][auraTypeDB].size
			end
		},
		numInRow = {
			order = 3,
			type = "range",
			min = 1, max = 10, step = 1,
			width = "normal",
			name = L["Num In Row"],
			desc = "",
			set = function(info, val)
				self.db.profile[groupType][auraTypeDB].numInRow = val
				self:SafeRefresh(groupType)
			end,
			get = function(info)
				return self.db.profile[groupType][auraTypeDB].numInRow
			end
		},
		alpha = {
			order = 4,
			min = 0.1, max = 1.0, step = 0.1,
			type = "range",
			width = "normal",
			name = L["Transparency"],
			desc = "",
			set = function(info, val)
				self.db.profile[groupType][auraTypeDB].alpha = val
				self:SafeRefresh(groupType)
			end,
			get = function(info)
				return self.db.profile[groupType][auraTypeDB].alpha
			end
		},
		xOffset = {
			order = 5,
			type = "range",
			min = -200, max = 200, step = 1,
			width = "normal",
			name = L["X Offset"],
			desc = "",
			set = function(info, val)
				self.db.profile[groupType][auraTypeDB].xOffset = val
				self:SafeRefresh(groupType)
			end,
			get = function(info)
				return self.db.profile[groupType][auraTypeDB].xOffset
			end
		},
		yOffset = {
			order = 6,
			type = "range",
			min = -200, max = 200, step = 1,
			width = "normal",
			name = L["Y Offset"],
			desc = "",
			set = function(info, val)
				self.db.profile[groupType][auraTypeDB].yOffset = val
				self:SafeRefresh(groupType)
			end,
			get = function(info)
				return self.db.profile[groupType][auraTypeDB].yOffset
			end
		},
		anchorPoint = {
			order = 7,
			type = "select",
			width = "normal",
			name = L["Anchor Point"],
			desc = "",
			values = POSITIONS,
			set = function(info, val)
				self.db.profile[groupType][auraTypeDB].anchorPoint = val
				self.db.profile[groupType][auraTypeDB].rowsGrowDirection = self.rowsGrows[val][self.db.profile[groupType][auraTypeDB].growDirection]
				self:SafeRefresh(groupType)
			end,
			get = function(info)
				return self.db.profile[groupType][auraTypeDB].anchorPoint
			end
		},
		growDirection = {
			order = 8,
			type = "select",
			width = "normal",
			name = L["Grow Direction"],
			desc = "",
			values = GROW_POSITIONS,
			set = function(info, val)
				self.db.profile[groupType][auraTypeDB].growDirection = val
				self.db.profile[groupType][auraTypeDB].rowsGrowDirection = self.rowsGrows[self.db.profile[groupType][auraTypeDB].anchorPoint][val]
				self:SafeRefresh(groupType)
			end,
			get = function(info)
				return self.db.profile[groupType][auraTypeDB].growDirection
			end
		},
		headerBlockList = {
			order = 100,
			type = "header",
			name = L["Block List"],
		},
		exclude = {
			order = 101,
			type = "input",
			multiline = 5,
			width = "full",
			usage = PRIVATE.TrackingHelpText,
			name = L["Exclude"],
			desc = L["Exclude auras"],
			set = function(info, val)
				self.db.profile[groupType][auraTypeDB].exclude = self.SanitizeStrings(val)
				self.db.profile[groupType][auraTypeDB].excludeStr = val
				self.UpdateAllCompactFrames(self.CompactUnitFrame_UpdateAuras)
			end,
			get = function(info)
				return self.db.profile[groupType][auraTypeDB].excludeStr
			end
		},
		copyButton = {
			order = 102,
			type = "execute",
			width = "full",
			confirm = true,
			name = L["Copy settings to |cFFffd100<text>|r"]:gsub("<text>", groupType == "party" and L["Raid_decl"] or L["Party_decl"]),
			desc = L["Copy settings to |cFFffd100<text>|r"]:gsub("<text>", groupType == "party" and L["Raid_decl"] or L["Party_decl"]),
			func = function(info, val)
				self:CopySettings(self.db.profile[groupType][auraTypeDB], self.db.profile[self.ReverseGroupType(groupType)][auraTypeDB])
			end,
		},
		resetButton = {
			order = 103,
			type = "execute",
			width = "full",
			confirm = true,
			name = L["Reset to Default"],
			desc = "",
			func = function(info, val)
				self:RestoreDefaults(groupType, auraTypeDB)
			end,
		},
	}

	if auraType == ADDON.AURA_TYPES.DISPEL then
		options.num.max = 4
		options.numInRow.max = 4
	elseif auraType == ADDON.AURA_TYPES.DEBUFF then
		options.headerBigDebuffs = {
			order = 50,
			type = "header",
			name = L["Big Debuffs"],
		}
		options.showBigDebuffs = {
			order = 51,
			type = "toggle",
			width = "normal",
			name = L["Show Big Debuffs"],
			desc = "",
			set = function(info, val)
				self.db.profile[groupType][auraTypeDB].showBigDebuffs = val
				self:SafeRefresh(groupType)
			end,
			get = function(info)
				return self.db.profile[groupType][auraTypeDB].showBigDebuffs
			end
		}
		options.smartAnchoring = {
			order = 52,
			type = "toggle",
			width = "normal",
			name = L["Align Big Debuffs"],
			desc = L["Align Big Debuffs Desc"],
			disabled = function(info)
				return not self.db.profile[groupType][auraTypeDB].showBigDebuffs
			end,
			set = function(info, val)
				self.db.profile[groupType][auraTypeDB].smartAnchoring = val
				self:SafeRefresh(groupType)
			end,
			get = function(info)
				return self.db.profile[groupType][auraTypeDB].smartAnchoring
			end
		}
		options.bigDebuffSize = {
			order = 12,
			type = "range",
			min = 1, max = 100, step = 1,
			width = "double",
			name = L["Size"],
			desc = "",
			disabled = function(info)
				return not self.db.profile[groupType][auraTypeDB].showBigDebuffs or self.db.profile[groupType][auraTypeDB].smartAnchoring
			end,
			set = function(info, val)
				self.db.profile[groupType][auraTypeDB].bigDebuffSize = val
				self:SafeRefresh(groupType)
			end,
			get = function(info)
				return self.db.profile[groupType][auraTypeDB].bigDebuffSize
			end
		}
	end

	return options
end