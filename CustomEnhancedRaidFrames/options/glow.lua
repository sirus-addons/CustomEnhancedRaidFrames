local ADDON_NAME, PRIVATE = ...
local ADDON = PRIVATE.ADDON
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

local LCG = LibStub("LibCustomGlow-1.0")

local pairs = pairs
local strformat = string.format
local twipe = table.wipe

local InCombatLockdown = InCombatLockdown

local GLOW_TYPES = {
	pixel	= "pixel",
	auto	= "auto",
	button	= "button",
}

local getGlowOptions = function(key)
	return key and PRIVATE.DEFAULTS_GLOW[key] or PRIVATE.DEFAULTS_GLOW
end

function ADDON:CreateGlowOptions()
	return {
		type = "group",
		order = 3,
		name = L["Glows"],
		desc = L["Glows settings"],
		childGroups = "tab",
		args = {
			auraGlow = {
				order = 1,
				type = "group",
				childGroups = "tree",
				name = L["Aura Glow"],
				desc = L["Glow effect options for your Buffs and Debuffs"],
				args = self:CreateGlowTypeOptions("auraGlow"),
			},
			frameGlow = {
				order = 2,
				type = "group",
				childGroups = "tree",
				name = L["Frame Glow"],
				desc = L["Glow effect options for your Frames"],
				args = self:CreateGlowTypeOptions("frameGlow"),
			},
			glowBlockList = {
				order = 3,
				type = "group",
				childGroups = "tab",
				name = L["Block List"],
				desc = L["Exclude auras from Glows"],
				args = {
					excludeStr = {
						order = 1,
						name = L["Block List"],
						desc = L["Exclude auras from Glows"],
						usage = strformat("\n\n\n%s\n155777\n", L["Rejuvenation"]),
						width = "full",
						type = "input",
						multiline = 20,
						set = function(info, val)
							self.db.profile.glows.glowBlockList.tracking = self.SanitizeStrings(val)
							self.db.profile.glows.glowBlockList.excludeStr = val

							self:SafeRefresh()
							self.UpdateAllCompactFrames(self.CompactUnitFrame_UpdateAuras)
						end,
						get = function(info)
							return self.db.profile.glows.glowBlockList.excludeStr
						end
					},
					header = {
						order = 2,
						type = "header",
						name = "",
					},
					resetButton = {
						order = 3,
						type = "execute",
						width = "full",
						confirm = true,
						name = L["Reset"],
						desc = "",
						func = function(info, val)
							self.db.profile.glows.glowBlockList.excludeStr = ""
							twipe(self.db.profile.glows.glowBlockList.tracking)
						end,
					},
				},
			}
		}
	}
end

function ADDON:CreateGlowTypeOptions(glowType)
	return {
		buffFrames = {
			order = 1,
			type = "group",
			childGroups = "tab",
			name = L["Buffs"],
			desc = "",
			args = self:CreateGlowSubOptions("buffFrames", glowType),
		},
		debuffFrames = {
			order = 2,
			type = "group",
			childGroups = "tab",
			name = L["Debuffs"],
			desc = "",
			args = self:CreateGlowSubOptions("debuffFrames", glowType),
		},
		defaultColors = {
			order = 3,
			type = "group",
			childGroups = "tab",
			name = L["Default Colors"],
			desc = "",
			set = function(info, r, g, b, a)
				local color = self.db.profile.glows[glowType].defaultColors[info[#info]]
				color[1], color[2], color[3], color[4] = r, g, b, a
			end,
			get = function(info)
				local color = self.db.profile.glows[glowType].defaultColors[info[#info]]
				return color[1], color[2], color[3], color[4]
			end,
			args = {
				magic = {
					order = 1,
					type = "color",
					hasAlpha = true,
					width = "full",
					name = L["Magic"],
					desc = "",
				},
				curse = {
					order = 2,
					type = "color",
					hasAlpha = true,
					width = "full",
					name = L["Curse"],
					desc = "",
				},
				disease = {
					order = 3,
					type = "color",
					hasAlpha = true,
					width = "full",
					name = L["Disease"],
					desc = "",
				},
				poison = {
					order = 4,
					type = "color",
					hasAlpha = true,
					width = "full",
					name = L["Poison"],
					desc = "",
				},
				physical = {
					order = 5,
					type = "color",
					hasAlpha = true,
					width = "full",
					name = L["Physical"],
					desc = "",
				},
				spacing = {
					order = 6,
					type = "header",
					name = "",
				},
				resetButton = {
					order = 7,
					type = "execute",
					width = "full",
					confirm = true,
					name = L["Reset to Default"],
					desc = "",
					func = function(info, val)
						self:GlowRestoreDefaultColors(glowType)
						self:GlowsRestartOptions("buffFrames", glowType)
						self:GlowsRestartOptions("debuffFrames", glowType)
						self.UpdateAllCompactFrames(self.CompactUnitFrame_UpdateAuras)
					end,
				},
			},
		},
	}
end

function ADDON:CreateGlowSubOptions(frameType, glowType)
	return {
		enabled = {
			order = 1,
			type = "toggle",
			width = "double",
			name = L["Enable"],
			desc = "",
			set = function(info, val)
				self.db.profile.glows[glowType][frameType].enabled = val
				self:GlowsRestartOptions(frameType, glowType)
				self.UpdateAllCompactFrames(self.CompactUnitFrame_UpdateAuras)
			end,
			get = function(info)
				self:HideVirtual()
				return self.db.profile.glows[glowType][frameType].enabled
			end
		},
		glowType = {
			order = 2,
			type = "select",
			width = "normal",
			name = L["Glow Type"],
			desc = "",
			values = GLOW_TYPES,
			disabled = function(info)
				return not self.db.profile.glows[glowType][frameType].enabled
			end,
			set = function(info, val)
				self.db.profile.glows[glowType][frameType].type = val
				self:GlowsRestartOptions(frameType, glowType)
			end,
			get = function(info)
				return self.db.profile.glows[glowType][frameType].type
			end
		},
		frequency = {
			order = 3,
			type = "range",
			min = -1, max = 1, step = 0.01,
			width = "normal",
			name = L["Frequency"],
			desc = "",
			disabled = function(info)
				return not self.db.profile.glows[glowType][frameType].enabled
			end,
			set = function(info, val)
				self.db.profile.glows[glowType][frameType].options[self.db.profile.glows[glowType][frameType].type].options.frequency = val
				self:GlowsRestartOptions(frameType, glowType)
			end,
			get = function(info)
				return self.db.profile.glows[glowType][frameType].options[self.db.profile.glows[glowType][frameType].type].options.frequency
			end
		},
		useDefaultsColors = {
			order = 4,
			type = "toggle",
			width = 1.5,
			name = L["Use Default Colors"],
			desc = PRIVATE.DebuffColorsText,
			disabled = function(info)
				return not self.db.profile.glows[glowType][frameType].enabled
			end,
			set = function(info, val)
				self.db.profile.glows[glowType][frameType].useDefaultsColors = val
				self:GlowsRestartOptions(frameType, glowType)
			end,
			get = function(info)
				return self.db.profile.glows[glowType][frameType].useDefaultsColors
			end
		},
		color = {
			order = 5,
			type = "color",
			hasAlpha = true,
			width = 0.4,
			name = L["Color"],
			desc = "",
			disabled = function(info)
				return not self.db.profile.glows[glowType][frameType].enabled or self.db.profile.glows[glowType][frameType].useDefaultsColors
			end,
			set = function(info, r, g, b, a)
				self.db.profile.glows[glowType][frameType].options[self.db.profile.glows[glowType][frameType].type].options.color = {r, g, b, a}
				self:GlowsRestartOptions(frameType, glowType)
			end,
			get = function(info)
				local color = self.db.profile.glows[glowType][frameType].options[self.db.profile.glows[glowType][frameType].type].options.color
				return color[1], color[2], color[3], color[4]
			end
		},
		spacing1 = {
			order = 6,
			type = "header",
			name = "",
		},
		xOffset = {
			order = 7,
			type = "range",
			min = -100, max = 100, step = 1,
			width = "normal",
			name = L["X Offset"],
			desc = "",
			disabled = function(info)
				return not self.db.profile.glows[glowType][frameType].enabled
			end,
			hidden = function(info)
				local options = getGlowOptions(self.db.profile.glows[glowType][frameType].type)
				return options.options["xOffset"] == nil
			end,
			set = function(info, val)
				self.db.profile.glows[glowType][frameType].options[self.db.profile.glows[glowType][frameType].type].options.xOffset = val
				self:GlowsRestartOptions(frameType, glowType)
			end,
			get = function(info)
				return self.db.profile.glows[glowType][frameType].options[self.db.profile.glows[glowType][frameType].type].options.xOffset
			end
		},
		yOffset = {
			order = 8,
			type = "range",
			min = -100, max = 100, step = 1,
			width = "normal",
			name = L["Y Offset"],
			desc = "",
			disabled = function(info)
				return not self.db.profile.glows[glowType][frameType].enabled
			end,
			hidden = function(info)
				local options = getGlowOptions(self.db.profile.glows[glowType][frameType].type)
				return options.options["yOffset"] == nil
			end,
			set = function(info, val)
				self.db.profile.glows[glowType][frameType].options[self.db.profile.glows[glowType][frameType].type].options.yOffset = val
				self:GlowsRestartOptions(frameType, glowType)
			end,
			get = function(info)
				return self.db.profile.glows[glowType][frameType].options[self.db.profile.glows[glowType][frameType].type].options.yOffset
			end
		},
		num = {
			order = 9,
			type = "range",
			min = 1, max = 20, step = 1,
			width = "normal",
			name = L["Num"],
			desc = "",
			disabled = function(info)
				return not self.db.profile.glows[glowType][frameType].enabled
			end,
			hidden = function(info)
				local options = getGlowOptions(self.db.profile.glows[glowType][frameType].type)
				return options.options["N"] == nil
			end,
			set = function(info, val)
				self.db.profile.glows[glowType][frameType].options[self.db.profile.glows[glowType][frameType].type].options.N = val
				self:GlowsRestartOptions(frameType, glowType)
			end,
			get = function(info)
				return self.db.profile.glows[glowType][frameType].options[self.db.profile.glows[glowType][frameType].type].options.N
			end
		},
		th = {
			order = 10,
			type = "range",
			min = 0.1, max = 10, step = 0.1,
			width = "normal",
			name = L["Thickness"],
			desc = "",
			disabled = function(info)
				return not self.db.profile.glows[glowType][frameType].enabled
			end,
			hidden = function(info)
				local options = getGlowOptions(self.db.profile.glows[glowType][frameType].type)
				return options.options["th"] == nil
			end,
			set = function(info, val)
				self.db.profile.glows[glowType][frameType].options[self.db.profile.glows[glowType][frameType].type].options.th = val
				self:GlowsRestartOptions(frameType, glowType)
			end,
			get = function(info)
				return self.db.profile.glows[glowType][frameType].options[self.db.profile.glows[glowType][frameType].type].options.th
			end
		},
		border = {
			order = 11,
			type = "toggle",
			width = "normal",
			name = L["Border"],
			desc = "",
			disabled = function(info)
				return not self.db.profile.glows[glowType][frameType].enabled
			end,
			hidden = function(info)
				local options = getGlowOptions(self.db.profile.glows[glowType][frameType].type)
				return options.options["border"] == nil
			end,
			set = function(info, val)
				self.db.profile.glows[glowType][frameType].options[self.db.profile.glows[glowType][frameType].type].options.border = val
				self:GlowsRestartOptions(frameType, glowType)
			end,
			get = function(info)
				return self.db.profile.glows[glowType][frameType].options[self.db.profile.glows[glowType][frameType].type].options.border
			end
		},
		spacing2 = {
			order = 80,
			type = "header",
			name = "",
			hidden = function(info)
				local options = getGlowOptions(self.db.profile.glows[glowType][frameType].type)
				return options.options["N"] == nil
			end,
		},
		tracking = {
			order = 81,
			type = "input",
			multiline = 5,
			width = "full",
			usage = PRIVATE.TrackingHelpText,
			name = L["Tracking"],
			desc = L["Track auras"],
			hidden = function(info)
				return frameType == "dispelDebuffFrames"
			end,
			disabled = function(info)
				return not self.db.profile.glows[glowType][frameType].enabled
			end,
			set = function(info, val)
				self.db.profile.glows[glowType][frameType].tracking = self.SanitizeStrings(val)
				self.db.profile.glows[glowType][frameType].trackingStr = val

				self:GlowsRestartOptions(frameType, glowType)
				self.UpdateAllCompactFrames(self.CompactUnitFrame_UpdateAuras)
			end,
			get = function(info)
				return self.db.profile.glows[glowType][frameType].trackingStr
			end
		},
		spacing3 = {
			order = 100,
			type = "header",
			name = "",
		},
		resetButton = {
			order = 101,
			type = "execute",
			width = "full",
			confirm = true,
			name = L["Reset to Default"],
			desc = "",
			func = function(info, val)
				self:GlowRestoreDefaults(frameType, glowType)
				self:GlowsRestartOptions(frameType, glowType)
				self.UpdateAllCompactFrames(self.CompactUnitFrame_UpdateAuras)
			end,
		},
	}
end

function ADDON:GlowRestoreDefaults(frameType, glowType)
	if InCombatLockdown() then
		ADDON:Print(L["Can not refresh settings while in combat"])
		return
	end

	for k, v in pairs(self:Defaults().profile.glows[glowType][frameType]) do
		self.db.profile.glows[glowType][frameType][k] = v
	end

	self:SafeRefresh()
end

function ADDON:GlowRestoreDefaultColors(glowType)
	for spellType in pairs(self.db.profile.glows[glowType].defaultColors) do
		self.db.profile.glows[glowType].defaultColors[spellType] = CopyTable(self.debuffsColors[spellType])
	end

	self:SafeRefresh()
end

function ADDON:GlowsRestartOptions(frameType, glowType)
	local db = self.db.profile.glows[glowType][frameType]

	for frame, color in pairs(self.glowingFrames[glowType][frameType]) do
		LCG.ButtonGlow_Stop(frame, frameType or "")
		LCG.PixelGlow_Stop(frame, frameType or "")
		LCG.AutoCastGlow_Stop(frame, frameType or "")

		self.glowingFrames[glowType][frameType][frame] = nil

		color = db.useDefaultsColors and color or db.options[db.type].color
		self.StartGlow(frame, db, color, frameType, glowType)
	end
end