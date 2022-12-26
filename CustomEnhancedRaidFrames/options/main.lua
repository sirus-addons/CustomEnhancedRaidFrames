local ADDON_NAME, PRIVATE = ...
local ADDON = PRIVATE.ADDON
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

local strformat, strtrim = string.format, string.trim

-- GLOBALS: AceGUIWidgetLSMlists, ReloadUI

local hexColors = {
	yellow	= "|cffffd100%s|r",
	yellow2	= "|cfffff569%s|r",
	white	= "|cffffffff%s|r",
	red		= "|cffc80000%s|r",
	green	= "|cff009600%s|r",
	purple	= "|cff9600ff%s|r",
	blue	= "|cff3296ff%s|r",
	brown	= "|cff966400%s|r",
	grey	= "|cffb8b6b0%s|r",
}

PRIVATE.DebuffColorsText = strconcat(
	"\n",
	strformat(hexColors.green, "Poison"), "\n",
	strformat(hexColors.purple, "Curse"), "\n",
	strformat(hexColors.brown, "Disease"), "\n",
	strformat(hexColors.blue, "Magic"), "\n",
	strformat(hexColors.white, "Physical"), "\n"
)

PRIVATE.TrackingHelpText = strconcat(
	strformat("\n\n\n%s\nCurse\n155777\nMagic\n\n%s:\n%s155777%s",
		L["Rejuvenation"],
		L["Wildcards"],
		PRIVATE.DebuffColorsText,
		strformat(hexColors.grey, L["-- Comments"])
	),
	"\n\n\n",
	L["AdditionalTrackingHelpText"]
)

local POSITIONS = {
	TOPLEFT			= L["TOPLEFT"],
	LEFT			= L["LEFT"],
	BOTTOMLEFT		= L["BOTTOMLEFT"],
	BOTTOM			= L["BOTTOM"],
	BOTTOMRIGHT		= L["BOTTOMRIGHT"],
	RIGHT			= L["RIGHT"],
	TOPRIGHT		= L["TOPRIGHT"],
	TOP				= L["TOP"],
	CENTER			= L["CENTER"],
}

local TEXT_POSITION = {
	LEFT			= L["LEFT"],
	RIGHT			= L["RIGHT"],
	CENTER			= L["CENTER"],
}

local FONT_OUTLINE = {
	None			= L["None"],
	OUTLINE			= L["OUTLINE"],
	THICKOUTLINE	= L["THICKOUTLINE"],
	MONOCHROME		= L["MONOCHROME"],
}

local PRECISIONS = {
--	[0] = "12345",
	[1] = "1234.5",
	[2] = "123.45",
	[3] = "12.345",
}

function ADDON:SetupOptions()
	return {
		order = 1,
		type = "group",
		childGroups = "tab",
		name = ADDON.TITLE,

		args = {
			raid = {
				order = 1,
				type = "group",
				childGroups = "tab",
				name = L["Raid"],
				desc = L["Raid settings"],
				args = self:CreateGenericOptionsByType("raid"),
			},
			party = {
				order = 2,
				type = "group",
				childGroups = "tab",
				name = L["Party"],
				desc = L["Party settings"],
				args = self:CreateGenericOptionsByType("party"),
			},
			glows = ADDON:CreateGlowOptions(),
			healPrediction = {
				order = 4,
				type = "group",
				childGroups = "tab",
				name = L["Heal Prediction"],
				desc = L["Heal Prediction settings"],

				set = function(info, val)
					self.db.profile.healPrediction[info[#info]] = val
					ADDON.HealPredictionUpdateAll()
				end,
				get = function(info)
					return self.db.profile.healPrediction[info[#info]]
				end,

				args = {
					heal = {
						order = 1,
						type = "toggle",
						width = 2,
						name = L["Enable Incoming Heal"],
						desc = "",
						disabled = false,
						set = function(info, val)
							self.db.profile.healPrediction[info[#info]] = val
							ADDON:ToggleHealComm(val)
							ADDON.HealPredictionUpdateAll()
						end,
					},

					absorbs = {
						order = 2,
						type = "toggle",
						width = 1.2,
						name = L["Enable Absorbs"],
						desc = "",
						disabled = false,
						set = function(info, val)
							self.db.profile.healPrediction[info[#info]] = val
							ADDON:ToggleLibAbsorb(val)
							ADDON.HealPredictionUpdateAll()
						end,
					},
					healThresholdSeconds = {
						order = 3,
						type = "range",
						min = 0, max = 6, step = 0.1,
						width = 2,
						name = L["Threshold for imminent healing in seconds"],
						desc = "",
						disabled = function()
							return not self.db.profile.healPrediction.heal
						end,
					},
					spacer = {
						order = 4,
						type = "description",
						name = " "
					},
					healMaxOverflowPercent = {
						order = 5,
						type = "range",
						min = 0, max = 100, step = 1,
						width = 2,
						name = L["Maxmimum percent of healing overflow"],
						desc = "",
						get = function(info)
							return (self.db.profile.healPrediction[info[#info]] - 1) * 100
						end,
						set = function(info, val)
							self.db.profile.healPrediction[info[#info]] = val * 0.01 + 1
							ADDON.HealPredictionUpdateAll()
						end,
						disabled = function()
							return not self.db.profile.healPrediction.heal
						end,
					},
				},
			},
			virtualFrames = {
				order = 100,
				type = "execute",
				width = "double",
				name = L["Show/Hide Test Frames"],
				desc = L["Show/Hide Test Frames DESC"],
				func = function(info, val)
					self:VirtualFramesToggle()
				end,
			},
			profileName = {
				order = 200,
				type = "header",
				name = L["Profile: |cFFC80000<text>|r"],
				hidden = function()
					return not PRIVATE.SyncProfiles
				end,
			},
		}
	}
end

function ADDON:CreateGenericOptionsByType(groupType)
	return {
		currentGroupType = {
			order = 1,
			type = "header",
			name = function()
				self.virtual.groupType = groupType

				if self.virtual.shown then
					self:ShowVirtual(groupType)
				end

				return L["You are in |cFFC80000<text>|r"]
			end,
		},
		frames = {
			order = 2,
			type = "group",
			childGroups = "tab",
			name = L["General"],
			desc = L["General options"],
			args = {
				hideGroupTitles = {
					order = 1,
					type = "toggle",
					name = L["Hide Group Title"],
					desc = "",
					width = 1.5,
					set = function(info, val)
						self.db.profile[groupType].frames.hideGroupTitles = val
						self:CompactRaidFrameContainer_LayoutFrames()
					end,
					get = function(info)
						return self.db.profile[groupType].frames.hideGroupTitles
					end
				},
				clickThrough = {
					order = 2,
					type = "toggle",
					name = L["Click Through Auras"],
					desc = L["Click Through Auras Desc"],
					width = 1.5,
					hidden = true,
					set = function(info, val)
						self.db.profile[groupType].frames.clickThrough = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].frames.clickThrough
					end
				},
				autoScaling = {
					order = 3,
					type = "toggle",
					name = L["Auto Scaling"],
					desc = L["Auto Scaling Desc"],
					width = 1.5,
					set = function(info, val)
						self.db.profile[groupType].frames.autoScaling = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].frames.autoScaling
					end
				},
				ButtonFacade = {
					order = 4,
					type = "toggle",
					name = L["Enable ButtonFacade Support"],
					desc = L["Enable ButtonFacade Support Desc"],
					width = 1.5,
					set = function(info, val)
						self.db.profile.Masque = val

						for frame in ADDON.IterateCompactFrames("raid") do
							ADDON.MasqueSupport(frame)
						end
						for frame in ADDON.IterateCompactFrames("group") do
							ADDON.MasqueSupport(frame)
						end
					end,
					get = function(info)
						return self.db.profile.Masque
					end
				},
				headerTracking = {
					type = "header",
					name = "",
					order = 50,
				},
				trackingStr = {
					order = 51,
					type = "input",
					multiline = 16,
					width = "full",
					name = L["Additional Auras Tracking"],
					desc = L["Track Auras that are not shown by default by Blizzard"],
					usage = PRIVATE.TrackingHelpText,
					set = function(info, val)
						self.db.profile[groupType].frames.tracking = self.SanitizeStringsByUnit(val)
						self.db.profile[groupType].frames.trackingStr = val
						self.UpdateAllCompactFrames(self.CompactUnitFrame_UpdateAuras)
					end,
					get = function(info)
						return self.db.profile[groupType].frames.trackingStr
					end
				},
				headerButtons = {
					order = 100,
					type = "header",
					name = "",
				},
				copyButton = {
					order = 101,
					type = "execute",
					width = 1.5,
					confirm = true,
					name = L["Copy settings to |cFFffd100<text>|r"]:gsub("<text>", groupType == "party" and L["Raid_decl"] or L["Party_decl"]),
					desc = L["Copy settings to |cFFffd100<text>|r"]:gsub("<text>", groupType == "party" and L["Raid_decl"] or L["Party_decl"]),
					func = function(info, val)
						self:CopySettings(self.db.profile[groupType].frames, self.db.profile[self.ReverseGroupType(groupType)].frames)
					end,
				},
				resetButton = {
					order = 102,
					type = "execute",
					width = 1.5,
					confirm = true,
					name = L["Reset to Default"],
					desc = "",
					func = function(info, val)
						local vars = {
							"hideGroupTitles",
							"clickThrough",
							"autoScaling",
							"tracking",
							"trackingStr"
						}

						self:RestoreDefaultsByTable(groupType, "frames", nil, vars)
					end,
				},
			},
		},
		buffsAndDebuffs = {
			order = 3,
			type = "group",
			childGroups = "tree",
			name = L["buffsAndDebuffs"],
			desc = "",
			args = {
				buffFrames = {
					order = 3,
					type = "group",
					childGroups = "tab",
					name = L["Buffs"],
					desc = "",
					args = self:SetupAuraFrames(groupType, ADDON.AURA_TYPES.BUFF),
				},
				debuffFrames = {
					order = 4,
					type = "group",
					childGroups = "tab",
					name = L["Debuffs"],
					desc = "",
					args = self:SetupAuraFrames(groupType, ADDON.AURA_TYPES.DEBUFF),
				},
				dispelDebuffFrames = {
					order = 6,
					type = "group",
					childGroups = "tab",
					name = L["Dispell Debuffs"],
					desc = L["Dispell Debuffs options"],
					args = self:SetupAuraFrames(groupType, ADDON.AURA_TYPES.DISPEL),
				},
			},
		},
		nameAndIcons = {
			order = 7,
			type = "group",
			childGroups = "tree",
			name = L["Name and Icons"],
			desc = L["Name and Icons options"],
			args = self:CreateNameIconOptions(groupType),
		},
		textures = {
			order = 8,
			type = "group",
			childGroups = "tree",
			name = L["Textures & Frames"],
			desc = "",
			args = self:CreateTexturesFrameOptions(groupType),
		},
	}
end

function ADDON:CreateNameIconOptions(groupType)
	return {
		name = {
			order = 1,
			type = "group",
			childGroups = "tab",
			name = L["Name"],
			desc = L["Name Options"],
			args = {
				enabled = {
					order = 1,
					type = "toggle",
					width = "normal",
					name = L["Enable"],
					desc = "",
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.name.enabled = val

						if val then
							self:RefreshProfileSettings(true)
							self:SafeRefresh(groupType)
						else
							self.Name_Revert()
						end
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.name.enabled
					end,
				},
				hide = {
					order = 2,
					type = "toggle",
					width = "normal",
					name = L["Hide Element"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.name.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.name.hide = val
						if not val then
							self:RefreshProfileSettings(true)
						end
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.name.hide
					end
				},
				font = {
					order = 3,
					type = "select",
					width = "normal",
					values = AceGUIWidgetLSMlists.font,
					dialogControl = "LSM30_Font",
					name = L["Font"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.name.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.name.font = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.name.font
					end
				},
				flag = {
					order = 4,
					type = "select",
					width = "normal",
					values = FONT_OUTLINE,
					name = L["Flags"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.name.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.name.flag = val
						self:SafeRefresh(groupType)
					end,
					get = function(info, value)
						return self.db.profile[groupType].nameAndIcons.name.flag
					end
				},
				size = {
					order = 5,
					type = "range",
					min = 1, max = 64, step = 1,
					width = "normal",
					name = L["Size"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.name.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.name.size = val
						self:SafeRefresh(groupType)
					end,
					get = function(info) return self.db.profile[groupType].nameAndIcons.name.size end
				},
				hJustify = {
					order = 6,
					type = "select",
					width = "normal",
					values = TEXT_POSITION,
					name = L["Horizontal Justify"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.name.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.name.hJustify = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.name.hJustify
					end
				},
				freeAnchor = {
					order = 7,
					type = "toggle",
					width = "full",
					name = L["Detach from icons"],
					desc = L["Detach from icons desc"],
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.name.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.name[info[#info]] = val

						if not val then
							self.Name_Revert()
						end

						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.name[info[#info]]
					end
				},
				xOffset = {
					order = 8,
					type = "range",
					min = -200, max = 200, step = 1,
					width = "normal",
					name = L["X Offset"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.name.enabled or not self.db.profile[groupType].nameAndIcons.name.freeAnchor
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.name.xOffset = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.name.xOffset
					end
				},
				yOffset = {
					order = 9,
					type = "range",
					min = -200, max = 200, step = 1,
					width = "normal",
					name = L["Y Offset"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.name.enabled or not self.db.profile[groupType].nameAndIcons.name.freeAnchor
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.name.yOffset = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.name.yOffset
					end
				},
				showServer = {
					order = 10,
					type = "toggle",
					width = "normal",
					name = L["Show Server"],
					desc = "",
					hidden = true,
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.name.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.name.showServer = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.name.showServer
					end
				},
				useClassColor = {
					order = 11,
					type = "toggle",
					width = "normal",
					name = L["Class Colored Names"],
					desc = L["Class Colored Names desc"],
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.name.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.name.useClassColor = val

						if not val then
							self.Name_Revert()
						end

						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.name.useClassColor
					end
				},
				headerButtons = {
					order = 100,
					type = "header",
					name = "",
				},
				copyButton = {
					order = 101,
					type = "execute",
					width = "full",
					confirm = true,
					name = L["Copy settings to |cFFffd100<text>|r"]:gsub("<text>", groupType == "party" and L["Raid_decl"] or L["Party_decl"]),
					desc = L["Copy settings to |cFFffd100<text>|r"]:gsub("<text>", groupType == "party" and L["Raid_decl"] or L["Party_decl"]),
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.name.enabled
					end,
					func = function(info, val)
						self:CopySettings(self.db.profile[groupType].nameAndIcons.name, self.db.profile[self.ReverseGroupType(groupType)].nameAndIcons.name)
					end,
				},
				resetButton = {
					order = 102,
					type = "execute",
					width = "full",
					confirm = true,
					name = L["Reset to Default"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.name.enabled
					end,
					func = function(info, val)
						self:RestoreDefaults(groupType, "nameAndIcons", "name")
					end,
				},
			},
		},
		statusText = {
			order = 2,
			type = "group",
			childGroups = "tab",
			name = L["Status Text"],
			desc = L["Status Text Options"],
			args = {
				enabled = {
					order = 1,
					type = "toggle",
					width = "double",
					name = L["Enable"],
					desc = "",
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.statusText.enabled = val

						if not val then
							self.StatusText_Revert()
						end

						self:RefreshProfileSettings(true)
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.statusText.enabled
					end,
				},
				font = {
					order = 2,
					type = "select",
					width = "normal",
					dialogControl = "LSM30_Font",
					values = AceGUIWidgetLSMlists.font,
					name = L["Font"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.statusText.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.statusText.font = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.statusText.font
					end
				},
				flag = {
					order = 3,
					type = "select",
					width = "normal",
					values = FONT_OUTLINE,
					name = L["Flags"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.statusText.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.statusText.flag = val
						self:SafeRefresh(groupType)
					end,
					get = function(info, value)
						return self.db.profile[groupType].nameAndIcons.statusText.flag
					end
				},
				size = {
					order = 4,
					type = "range",
					min = 1, max = 64, step = 1,
					width = "normal",
					name = L["Size"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.statusText.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.statusText.size = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.statusText.size
					end
				},
				hJustify = {
					order = 5,
					type = "select",
					width = "normal",
					values = TEXT_POSITION,
					name = L["Horizontal Justify"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.statusText.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.statusText.hJustify = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.statusText.hJustify
					end
				},
				xOffset = {
					order = 6,
					type = "range",
					min = -200, max = 200, step = 1,
					width = "normal",
					name = L["X Offset"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.statusText.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.statusText.xOffset = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.statusText.xOffset
					end
				},
				yOffset = {
					order = 7,
					type = "range",
					min = -200, max = 200, step = 1,
					width = "normal",
					name = L["Y Offset"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.statusText.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.statusText.yOffset = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.statusText.yOffset
					end
				},
				color = {
					order = 8,
					type = "color",
					hasAlpha = true,
					width = "normal",
					name = "",
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.statusText.enabled or self.db.profile[groupType].nameAndIcons.statusText.useClassColor
					end,
					set = function(info, r, g, b, a)
						self.db.profile[groupType].nameAndIcons.statusText.color = {r, g, b, a}
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						local color = self.db.profile[groupType].nameAndIcons.statusText.color
						return color[1], color[2], color[3], color[4]
					end
				},
				useClassColor = {
					order = 9,
					type = "toggle",
					width = "normal",
					name = L["Class Colored Text"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.statusText.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.statusText.useClassColor = val

						if not val then
							self.Name_Revert()
						end

						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.statusText.useClassColor
					end
				},
				headerFormatting = {
					order = 10,
					type = "header",
					name = L["Formatting"],
				},
				abbreviateNumbers = {
					order = 11,
					type = "toggle",
					width = "normal",
					name = L["Abbreviate"],
					desc = L["Abbreviate Desc"],
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.statusText.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.statusText.abbreviateNumbers = val

						self:SafeRefresh(groupType)
					end,
					get = function(info, value)
						return self.db.profile[groupType].nameAndIcons.statusText.abbreviateNumbers
					end
				},
				precision = {
					order = 12,
					type = "select",
					width = "normal",
					values = PRECISIONS,
					name = L["Precision"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.statusText.enabled or not self.db.profile[groupType].nameAndIcons.statusText.abbreviateNumbers
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.statusText.precision = val
						self:SafeRefresh(groupType)
					end,
					get = function(info, value)
						return self.db.profile[groupType].nameAndIcons.statusText.precision
					end
				},
				showPercents = {
					order = 13,
					type = "toggle",
					width = "normal",
					name = L["Show Percents"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.statusText.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.statusText.showPercents = val

						self:SafeRefresh(groupType)
					end,
					get = function(info, value)
						return self.db.profile[groupType].nameAndIcons.statusText.showPercents
					end
				},
				hideStatusText = {
					order = 14,
					type = "toggle",
					width = "normal",
					name = L["Don\'t Show Status Text"],
					desc = L["Don\'t Show Status Text Desc"],
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.statusText.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.statusText.hideStatusText = val

						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.statusText.hideStatusText
					end,
				},
				headerButtons = {
					order = 100,
					type = "header",
					name = "",
				},
				copyButton = {
					order = 101,
					type = "execute",
					width = "full",
					confirm = true,
					name = L["Copy settings to |cFFffd100<text>|r"]:gsub("<text>", groupType == "party" and L["Raid_decl"] or L["Party_decl"]),
					desc = L["Copy settings to |cFFffd100<text>|r"]:gsub("<text>", groupType == "party" and L["Raid_decl"] or L["Party_decl"]),
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.statusText.enabled
					end,
					func = function(info, val)
						self:CopySettings(self.db.profile[groupType].nameAndIcons.statusText, self.db.profile[self.ReverseGroupType(groupType)].nameAndIcons.statusText)
					end,
				},
				resetButton = {
					order = 102,
					type = "execute",
					width = "full",
					confirm = true,
					name = L["Reset to Default"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.statusText.enabled
					end,
					func = function(info, val)
						self:RestoreDefaults(groupType, "nameAndIcons", "statusText")
					end,
				},
			},
		},
		readyCheckIcon = {
			order = 3,
			type = "group",
			childGroups = "tab",
			name = L["Ready Check Icon"],
			desc = L["Ready Check Icon Options"],
			args = {
				enabled = {
					order = 1,
					type = "toggle",
					width = "normal",
					name = L["Enable"],
					desc = "",
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.readyCheckIcon.enabled = val

						if not val then
							self.ReadyCheckIcon_Revert()
						end

						self:RefreshProfileSettings(true)
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.readyCheckIcon.enabled
					end,
				},
				hide = {
					order = 2,
					type = "toggle",
					width = "normal",
					name = L["Hide Element"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.readyCheckIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.readyCheckIcon.hide = val
						self:RefreshProfileSettings(true)
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.readyCheckIcon.hide
					end
				},
				size = {
					order = 3,
					type = "range",
					min = 1, max = 64, step = 1,
					width = "full",
					name = L["Size"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.readyCheckIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.readyCheckIcon.size = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.readyCheckIcon.size
					end
				},
				xOffset = {
					order = 4,
					type = "range",
					min = -200, max = 200, step = 1,
					width = "normal",
					name = L["X Offset"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.readyCheckIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.readyCheckIcon.xOffset = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.readyCheckIcon.xOffset
					end
				},
				yOffset = {
					order = 5,
					type = "range",
					min = -200, max = 200, step = 1,
					width = "normal",
					name = L["Y Offset"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.readyCheckIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.readyCheckIcon.yOffset = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.readyCheckIcon.yOffset
					end
				},
				useCustomTextures = {
					order = 20,
					type = "execute",
					width = "full",
					name = L["Custom Textures"],
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.readyCheckIcon.enabled
					end,
					func = function(info, val)
						self.db.profile[groupType].nameAndIcons.readyCheckIcon.useCustomTextures = not self.db.profile[groupType].nameAndIcons.readyCheckIcon.useCustomTextures
						self.UpdateAllCompactFrames(self.CompactUnitFrame_UpdateReadyCheck)
					end,
				},
				ready = {
					order = 21,
					type = "input",
					width = 1.5,
					name = L["Ready"],
					desc = L["Custom Texture Options"],
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.readyCheckIcon.enabled
					end,
					hidden = function(info)
						return not self.db.profile[groupType].nameAndIcons.readyCheckIcon.useCustomTextures
					end,
					set = function(info, val)
						val = strtrim(val)
						self.db.profile[groupType].nameAndIcons.readyCheckIcon.ready = val

						if val == "" then
							self.ReadyCheckIcon_Revert()
						end

						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.readyCheckIcon.ready
					end
				},
				readyColor = {
					order = 22,
					type = "color",
					hasAlpha = true,
					width = "half",
					name = "",
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.readyCheckIcon.enabled
					end,
					hidden = function(info)
						return not self.db.profile[groupType].nameAndIcons.readyCheckIcon.useCustomTextures
					end,
					set = function(info, r, g, b, a)
						self.db.profile[groupType].nameAndIcons.readyCheckIcon.colors.ready = {r, g, b, a}
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						local color = self.db.profile[groupType].nameAndIcons.readyCheckIcon.colors.ready
						return color[1], color[2], color[3], color[4]
					end
				},
				notready = {
					order = 23,
					type = "input",
					width = 1.5,
					name = L["Not Ready"],
					desc = L["Custom Texture Options"],
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.readyCheckIcon.enabled
					end,
					hidden = function(info)
						return not self.db.profile[groupType].nameAndIcons.readyCheckIcon.useCustomTextures
					end,
					set = function(info, val)
						val = strtrim(val)
						self.db.profile[groupType].nameAndIcons.readyCheckIcon.notready = val

						if val == "" then
							self.ReadyCheckIcon_Revert()
						end

						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.readyCheckIcon.notready
					end
				},
				notreadyColor = {
					order = 24,
					type = "color",
					hasAlpha = true,
					width = "half",
					name = "",
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.readyCheckIcon.enabled
					end,
					hidden = function(info)
						return not self.db.profile[groupType].nameAndIcons.readyCheckIcon.useCustomTextures
					end,
					set = function(info, r, g, b, a)
						self.db.profile[groupType].nameAndIcons.readyCheckIcon.colors.notready = {r, g, b, a}
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						local color = self.db.profile[groupType].nameAndIcons.readyCheckIcon.colors.notready
						return color[1], color[2], color[3], color[4]
					end
				},
				waiting = {
					order = 25,
					type = "input",
					width = 1.5,
					name = L["Waiting"],
					desc = L["Custom Texture Options"],
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.readyCheckIcon.enabled
					end,
					hidden = function(info)
						return not self.db.profile[groupType].nameAndIcons.readyCheckIcon.useCustomTextures
					end,
					set = function(info, val)
						val = strtrim(val)
						self.db.profile[groupType].nameAndIcons.readyCheckIcon.waiting = val

						if val == "" then
							self.ReadyCheckIcon_Revert()
						end

						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.readyCheckIcon.waiting
					end
				},
				waitingColor = {
					order = 26,
					type = "color",
					hasAlpha = true,
					width = "half",
					name = "",
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.readyCheckIcon.enabled
					end,
					hidden = function(info)
						return not self.db.profile[groupType].nameAndIcons.readyCheckIcon.useCustomTextures
					end,
					set = function(info, r, g, b, a)
						self.db.profile[groupType].nameAndIcons.readyCheckIcon.colors.waiting = {r, g, b, a}
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						local color = self.db.profile[groupType].nameAndIcons.readyCheckIcon.colors.waiting
						return color[1], color[2], color[3], color[4]
					end
				},
				headerButtons = {
					order = 100,
					type = "header",
					name = "",
				},
				copyButton = {
					order = 101,
					type = "execute",
					width = "full",
					confirm = true,
					name = L["Copy settings to |cFFffd100<text>|r"]:gsub("<text>", groupType == "party" and L["Raid_decl"] or L["Party_decl"]),
					desc = L["Copy settings to |cFFffd100<text>|r"]:gsub("<text>", groupType == "party" and L["Raid_decl"] or L["Party_decl"]),
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.readyCheckIcon.enabled
					end,
					func = function(info, val)
						self:CopySettings(self.db.profile[groupType].nameAndIcons.readyCheckIcon, self.db.profile[self.ReverseGroupType(groupType)].nameAndIcons.readyCheckIcon)
					end,
				},
				resetButton = {
					order = 102,
					type = "execute",
					width = "full",
					confirm = true,
					name = L["Reset to Default"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.readyCheckIcon.enabled
					end,
					func = function(info, val)
						self:RestoreDefaults(groupType, "nameAndIcons", "readyCheckIcon")
					end,
				},
			},
		},
		centerStatusIcon = {
			order = 4,
			type = "group",
			childGroups = "tab",
			name = L["Center Status Icon"],
			desc = L["Center Status Icon Options"],
			args = {
				enabled = {
					order = 1,
					type = "toggle",
					width = "normal",
					name = L["Enable"],
					desc = "",
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.centerStatusIcon.enabled = val

						if val then
							self:RefreshProfileSettings(true)
							self:SafeRefresh(groupType)
						else
							self.CenterStatusIcon_Revert()
						end
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.centerStatusIcon.enabled
					end,
				},
				hide = {
					order = 2,
					type = "toggle",
					width = "normal",
					name = L["Hide Element"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.centerStatusIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.centerStatusIcon.hide = val
						self:RefreshProfileSettings(true)
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.centerStatusIcon.hide
					end
				},
				size = {
					order = 3,
					type = "range",
					min = 1, max = 64, step = 1,
					width = "full",
					name = L["Size"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.centerStatusIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.centerStatusIcon.size = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.centerStatusIcon.size
					end
				},
				xOffset = {
					order = 4,
					type = "range",
					min = -200, max = 200, step = 1,
					width = "normal",
					name = L["X Offset"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.centerStatusIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.centerStatusIcon.xOffset = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.centerStatusIcon.xOffset
					end
				},
				yOffset = {
					order = 5,
					type = "range",
					min = -200, max = 200, step = 1,
					width = "normal",
					name = L["Y Offset"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.centerStatusIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.centerStatusIcon.yOffset = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.centerStatusIcon.yOffset
					end
				},
				useCustomTextures = {
					order = 20,
					type = "execute",
					width = "full",
					name = L["Custom Textures"],
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.centerStatusIcon.enabled
					end,
					func = function(info, val)
						self.db.profile[groupType].nameAndIcons.centerStatusIcon.useCustomTextures = not self.db.profile[groupType].nameAndIcons.centerStatusIcon.useCustomTextures
						self.UpdateAllCompactFrames(self.CompactUnitFrame_UpdateCenterStatusIcon)
					end,
				},
				hasIncomingResurrection = {
					order = 21,
					type = "input",
					width = 1.5,
					name = L["Has Icoming Ressurection"],
					desc = L["Custom Texture Options"],
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.centerStatusIcon.enabled
					end,
					hidden = function(info)
						return not self.db.profile[groupType].nameAndIcons.centerStatusIcon.useCustomTextures
					end,
					set = function(info, val)
						val = strtrim(val)
						self.db.profile[groupType].nameAndIcons.centerStatusIcon.hasIncomingResurrection = val

						if val == "" then
							self.CenterStatusIcon_Revert()
						end

						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.centerStatusIcon.hasIncomingResurrection
					end
				},
				hasIncomingResurrectionColor = {
					order = 22,
					type = "color",
					hasAlpha = true,
					width = "half",
					name = "",
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.centerStatusIcon.enabled
					end,
					hidden = function(info)
						return not self.db.profile[groupType].nameAndIcons.centerStatusIcon.useCustomTextures
					end,
					set = function(info, r, g, b, a)
						self.db.profile[groupType].nameAndIcons.centerStatusIcon.colors.hasIncomingResurrection = {r, g, b, a}
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						local color = self.db.profile[groupType].nameAndIcons.centerStatusIcon.colors.hasIncomingResurrection
						return color[1], color[2], color[3], color[4]
					end
				},
				hasIncomingSummonPending = {
					order = 23,
					type = "input",
					width = 1.5,
					name = L["Incoming Summon Pending"],
					desc = L["Custom Texture Options"],
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.centerStatusIcon.enabled
					end,
					hidden = function(info)
						return not self.db.profile[groupType].nameAndIcons.centerStatusIcon.useCustomTextures
					end,
					set = function(info, val)
						val = strtrim(val)
						self.db.profile[groupType].nameAndIcons.centerStatusIcon.hasIncomingSummonPending = val

						if val == "" then
							self.CenterStatusIcon_Revert()
						end

						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.centerStatusIcon.hasIncomingSummonPending
					end
				},
				hasIncomingSummonPendingColor = {
					order = 24,
					type = "color",
					hasAlpha = true,
					width = "half",
					name = "",
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.centerStatusIcon.enabled
					end,
					hidden = function(info)
						return not self.db.profile[groupType].nameAndIcons.centerStatusIcon.useCustomTextures
					end,
					set = function(info, r, g, b, a)
						self.db.profile[groupType].nameAndIcons.centerStatusIcon.colors.hasIncomingSummonPending = {r, g, b, a}
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						local color = self.db.profile[groupType].nameAndIcons.centerStatusIcon.colors.hasIncomingSummonPending
						return color[1], color[2], color[3], color[4]
					end
				},
				hasIncomingSummonAccepted = {
					order = 25,
					type = "input",
					width = 1.5,
					name = L["Incoming Summon Accepted"],
					desc = L["Custom Texture Options"],
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.centerStatusIcon.enabled
					end,
					hidden = function(info)
						return not self.db.profile[groupType].nameAndIcons.centerStatusIcon.useCustomTextures
					end,
					set = function(info, val)
						val = strtrim(val)
						self.db.profile[groupType].nameAndIcons.centerStatusIcon.hasIncomingSummonAccepted = val

						if val == "" then
							self.CenterStatusIcon_Revert()
						end

						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.centerStatusIcon.hasIncomingSummonAccepted
					end
				},
				hasIncomingSummonAcceptedColor = {
					order = 26,
					type = "color",
					hasAlpha = true,
					width = "half",
					name = "",
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.centerStatusIcon.enabled
					end,
					hidden = function(info)
						return not self.db.profile[groupType].nameAndIcons.centerStatusIcon.useCustomTextures
					end,
					set = function(info, r, g, b, a)
						self.db.profile[groupType].nameAndIcons.centerStatusIcon.colors.hasIncomingSummonAccepted = {r, g, b, a}
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						local color = self.db.profile[groupType].nameAndIcons.centerStatusIcon.colors.hasIncomingSummonAccepted
						return color[1], color[2], color[3], color[4]
					end
				},
				hasIncomingSummonDeclined = {
					order = 27,
					type = "input",
					width = 1.5,
					name = L["Incoming Summon Declined"],
					desc = L["Custom Texture Options"],
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.centerStatusIcon.enabled
					end,
					hidden = function(info)
						return not self.db.profile[groupType].nameAndIcons.centerStatusIcon.useCustomTextures
					end,
					set = function(info, val)
						val = strtrim(val)
						self.db.profile[groupType].nameAndIcons.centerStatusIcon.hasIncomingSummonDeclined = val

						if val == "" then
							self.CenterStatusIcon_Revert()
						end

						self:SafeRefresh(groupType)
					end,
					get = function(info) return self.db.profile[groupType].nameAndIcons.centerStatusIcon.hasIncomingSummonDeclined end
				},
				hasIncomingSummonDeclinedColor = {
					order = 28,
					type = "color",
					hasAlpha = true,
					width = "half",
					name = "",
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.centerStatusIcon.enabled
					end,
					hidden = function(info)
						return not self.db.profile[groupType].nameAndIcons.centerStatusIcon.useCustomTextures
					end,
					set = function(info, r, g, b, a)
						self.db.profile[groupType].nameAndIcons.centerStatusIcon.colors.hasIncomingSummonDeclined = {r, g, b, a}
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						local color = self.db.profile[groupType].nameAndIcons.centerStatusIcon.colors.hasIncomingSummonDeclined
						return color[1], color[2], color[3], color[4]
					end
				},
				headerButtons = {
					order = 100,
					type = "header",
					name = "",
				},
				copyButton = {
					order = 101,
					type = "execute",
					width = "full",
					confirm = true,
					name = L["Copy settings to |cFFffd100<text>|r"]:gsub("<text>", groupType == "party" and L["Raid_decl"] or L["Party_decl"]),
					desc = L["Copy settings to |cFFffd100<text>|r"]:gsub("<text>", groupType == "party" and L["Raid_decl"] or L["Party_decl"]),
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.centerStatusIcon.enabled
					end,
					func = function(info, val)
						self:CopySettings(self.db.profile[groupType].nameAndIcons.centerStatusIcon, self.db.profile[self.ReverseGroupType(groupType)].nameAndIcons.centerStatusIcon)
					end,
				},
				resetButton = {
					order = 102,
					type = "execute",
					width = "full",
					confirm = true,
					name = L["Reset to Default"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.centerStatusIcon.enabled
					end,
					func = function(info, val)
						self:RestoreDefaults(groupType, "nameAndIcons", "centerStatusIcon")
					end,
				},
			},
		},
		raidTargetIcon = {
			order = 5,
			type = "group",
			childGroups = "tab",
			name = L["Raid Icon"],
			desc = L["Raid Icon options"],
			args = {
				enabled = {
					order = 1,
					type = "toggle",
					width = "normal",
					name = L["Enable"],
					desc = "",
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.raidTargetIcon[info[#info]] = val
						if not val then
							self.RaidTargetIcon_Revert()
							self:RefreshProfileSettings(true)
						end
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						x = info
						return self.db.profile[groupType].nameAndIcons.raidTargetIcon[info[#info]]
					end
				},
				hide = {
					order = 2,
					type = "toggle",
					width = "normal",
					name = L["Hide Element"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.raidTargetIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.raidTargetIcon.hide = val

						if not val then
							self.RaidTargetIcon_Revert()
						end

						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.raidTargetIcon.hide
					end
				},
				size = {
					order = 3,
					type = "range",
					min = 1, max = 64, step = 1,
					width = "normal",
					name = L["Size"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.raidTargetIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.raidTargetIcon[info[#info]] = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.raidTargetIcon[info[#info]]
					end
				},
				alpha = {
					order = 4,
					type = "range",
					min = 0.1, max = 1.0, step = 0.1,
					width = "normal",
					name = L["Transparency"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.raidTargetIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.raidTargetIcon[info[#info]] = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.raidTargetIcon[info[#info]]
					end
				},
				xOffset = {
					order = 5,
					type = "range",
					min = -200, max = 200, step = 1,
					width = "normal",
					name = L["X Offset"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.raidTargetIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.raidTargetIcon[info[#info]] = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.raidTargetIcon[info[#info]]
					end
				},
				yOffset = {
					order = 6,
					type = "range",
					min = -200, max = 200, step = 1,
					width = "normal",
					name = L["Y Offset"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.raidTargetIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.raidTargetIcon[info[#info]] = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.raidTargetIcon[info[#info]]
					end
				},
				anchorPoint = {
					order = 7,
					type = "select",
					width = "normal",
					values = POSITIONS,
					name = L["Anchor Point"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.raidTargetIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.raidTargetIcon[info[#info]] = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.raidTargetIcon[info[#info]]
					end
				},
				headerButtons = {
					type = "header",
					name = "",
					order = 100,
				},
				copyButton = {
					order = 101,
					type = "execute",
					width = "full",
					confirm = true,
					name = L["Copy settings to |cFFffd100<text>|r"]:gsub("<text>", groupType == "party" and L["Raid_decl"] or L["Party_decl"]),
					desc = L["Copy settings to |cFFffd100<text>|r"]:gsub("<text>", groupType == "party" and L["Raid_decl"] or L["Party_decl"]),
					func = function(info, val)
						self:CopySettings(
							self.db.profile[groupType].nameAndIcons.raidTargetIcon,
							self.db.profile[self.ReverseGroupType(groupType)].nameAndIcons.raidTargetIcon
						)
					end,
				},
				resetButton = {
					order = 102,
					type = "execute",
					width = "full",
					confirm = true,
					name = L["Reset to Default"],
					desc = "",
					func = function(info, val)
						self:RestoreDefaults(groupType, "raidTargetIcon")
					end,
				},
			},
		},
		roleGroupIcon = {
			order = 6,
			type = "group",
			name = L["Leader Icon"],
			desc = L["Leader Icon Options"],
			childGroups = "tab",
			args = {
				enabled = {
					order = 1,
					type = "toggle",
					width = "normal",
					name = L["Enable"],
					desc = "",
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.roleGroupIcon[info[#info]] = val
						if not val then
							self.RoleGroupIcon_Revert()
							self:RefreshProfileSettings(true)
						end
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.roleGroupIcon[info[#info]]
					end,
				},
				hide = {
					order = 2,
					type = "toggle",
					width = "normal",
					name = L["Hide Element"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.roleGroupIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.roleGroupIcon.hide = val

						if not val then
							self.RoleGroupIcon_Revert()
							self:RefreshProfileSettings(true)
						end

						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.roleGroupIcon.hide
					end
				},
				size = {
					order = 3,
					type = "range",
					min = 1, max = 64, step = 1,
					width = "normal",
					name = L["Size"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.roleGroupIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.roleGroupIcon[info[#info]] = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.roleGroupIcon[info[#info]]
					end
				},
				alpha = {
					order = 4,
					type = "range",
					min = 0.1, max = 1.0, step = 0.1,
					width = "normal",
					name = L["Transparency"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.roleGroupIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.roleGroupIcon[info[#info]] = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.roleGroupIcon[info[#info]]
					end
				},
				xOffset = {
					order = 5,
					type = "range",
					min = -200, max = 200, step = 1,
					width = "normal",
					name = L["X Offset"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.roleGroupIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.roleGroupIcon[info[#info]] = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.roleGroupIcon[info[#info]]
					end
				},
				yOffset = {
					order = 6,
					type = "range",
					min = -200, max = 200, step = 1,
					width = "normal",
					name = L["Y Offset"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.roleGroupIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.roleGroupIcon[info[#info]] = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.roleGroupIcon[info[#info]]
					end
				},
				anchorPoint = {
					order = 7,
					type = "select",
					values = POSITIONS,
					width = "normal",
					name = L["Anchor Point"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.roleGroupIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.roleGroupIcon[info[#info]] = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.roleGroupIcon[info[#info]]
					end
				},
				headerButtons = {
					order = 100,
					type = "header",
					name = "",
				},
				copyButton = {
					order = 101,
					type = "execute",
					width = "full",
					confirm = true,
					name = L["Copy settings to |cFFffd100<text>|r"]:gsub("<text>", groupType == "party" and L["Raid_decl"] or L["Party_decl"]),
					desc = L["Copy settings to |cFFffd100<text>|r"]:gsub("<text>", groupType == "party" and L["Raid_decl"] or L["Party_decl"]),
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.roleGroupIcon.enabled
					end,
					func = function(info, val)
						self:CopySettings(
							self.db.profile[groupType].nameAndIcons.roleGroupIcon,
							self.db.profile[self.ReverseGroupType(groupType)].nameAndIcons.roleGroupIcon
						)
					end,
				},
				resetButton = {
					order = 102,
					type = "execute",
					width = "full",
					confirm = true,
					name = L["Reset to Default"],
					desc = "",
					disabled = function(info)
						return not self.db.profile[groupType].nameAndIcons.roleGroupIcon.enabled
					end,
					func = function(info, val)
						self:RestoreDefaults(groupType,"nameAndIcons", "roleGroupIcon")
					end,
				},
			},
		},
		roleIcon = {
			order = 7,
			type = "group",
			childGroups = "tab",
			name = L["Role Icon"],
			desc = L["Role Icon Options"],
			args = {
				enabled = {
					order = 1,
					type = "toggle",
					width = "normal",
					name = L["Enable"],
					desc = "",
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.roleIcon.enabled = val
						self:RefreshProfileSettings(true)
						if not val then
							self.RoleIcon_Revert()
						end
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.roleIcon.enabled
					end,
				},
				hide = {
					order = 2,
					type = "toggle",
					width = "normal",
					name = L["Hide Element"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.roleIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.roleIcon.hide = val

						if not val then
							ADDON.RoleIcon_Revert()
						end

						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.roleIcon.hide
					end
				},
				size = {
					order = 3,
					type = "range",
					min = 1, max = 64, step = 1,
					width = "normal",
					name = L["Size"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.roleIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.roleIcon.size = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.roleIcon.size
					end
				},
				alpha = {
					order = 4,
					type = "range",
					min = 0.1, max = 1.0, step = 0.1,
					width = "normal",
					name = L["Transparency"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.roleIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.roleIcon[info[#info]] = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.roleIcon[info[#info]]
					end
				},
				xOffset = {
					order = 5,
					type = "range",
					min = -200, max = 200, step = 1,
					width = "normal",
					name = L["X Offset"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.roleIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.roleIcon.xOffset = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.roleIcon.xOffset
					end
				},
				yOffset = {
					order = 6,
					type = "range",
					min = -200, max = 200, step = 1,
					width = "normal",
					name = L["Y Offset"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.roleIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.roleIcon.yOffset = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.roleIcon.yOffset
					end
				},
				anchorPoint = {
					order = 7,
					type = "select",
					values = POSITIONS,
					width = "normal",
					name = L["Anchor Point"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.roleIcon.enabled
					end,
					set = function(info, val)
						self.db.profile[groupType].nameAndIcons.roleIcon[info[#info]] = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.roleIcon[info[#info]]
					end
				},
				useCustomTextures = {
					order = 20,
					type = "execute",
					width = "full",
					name = L["Custom Textures"],
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.roleIcon.enabled
					end,
					func = function(info, val)
						self.db.profile[groupType].nameAndIcons.roleIcon[info[#info]] = not self.db.profile[groupType].nameAndIcons.roleIcon[info[#info]]
						self.UpdateAllCompactFrames(self.CompactUnitFrame_UpdateRoleIcon)
					end,
				},
				healer = {
					order = 21,
					type = "input",
					width = 1.5,
					name = L["Healer"],
					desc = L["Custom Texture Options"],
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.roleIcon.enabled
					end,
					hidden = function(info)
						return not self.db.profile[groupType].nameAndIcons.roleIcon.useCustomTextures
					end,
					set = function(info, val)
						val = strtrim(val)
						self.db.profile[groupType].nameAndIcons.roleIcon.healer = val

						if val == "" then
							self.RoleIcon_Revert()
						end

						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.roleIcon.healer
					end
				},
				healerColor = {
					order = 22,
					type = "color",
					hasAlpha = true,
					width = "half",
					name = "",
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.roleIcon.enabled
					end,
					hidden = function(info)
						return not self.db.profile[groupType].nameAndIcons.roleIcon.useCustomTextures
					end,
					set = function(info, r, g, b, a)
						self.db.profile[groupType].nameAndIcons.roleIcon.colors.healer = {r, g, b, a}
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						local color = self.db.profile[groupType].nameAndIcons.roleIcon.colors.healer
						return color[1], color[2], color[3], color[4]
					end
				},
				damager = {
					order = 23,
					type = "input",
					width = 1.5,
					name = L["Damager"],
					desc = L["Custom Texture Options"],
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.roleIcon.enabled
					end,
					hidden = function(info)
						return not self.db.profile[groupType].nameAndIcons.roleIcon.useCustomTextures
					end,
					set = function(info, val)
						val = strtrim(val)
						self.db.profile[groupType].nameAndIcons.roleIcon.damager = val

						if val == "" then
							self.RoleIcon_Revert()
						end

						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.roleIcon.damager
					end
				},
				damagerColor = {
					order = 24,
					type = "color",
					hasAlpha = true,
					width = "half",
					name = "",
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.roleIcon.enabled
					end,
					hidden = function(info)
						return not self.db.profile[groupType].nameAndIcons.roleIcon.useCustomTextures
					end,
					set = function(info, r, g, b, a)
						self.db.profile[groupType].nameAndIcons.roleIcon.colors.damager = {r, g, b, a}
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						local color = self.db.profile[groupType].nameAndIcons.roleIcon.colors.damager
						return color[1], color[2], color[3], color[4]
					end
				},
				tank = {
					order = 25,
					type = "input",
					width = 1.5,
					name = L["Tank"],
					desc = L["Custom Texture Options"],
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.roleIcon.enabled
					end,
					hidden = function(info)
						return not self.db.profile[groupType].nameAndIcons.roleIcon.useCustomTextures
					end,
					set = function(info, val)
						val = strtrim(val)
						self.db.profile[groupType].nameAndIcons.roleIcon.tank = val

						if val == "" then
							self.RoleIcon_Revert()
						end

						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.roleIcon.tank
					end
				},
				tankColor = {
					order = 26,
					type = "color",
					hasAlpha = true,
					width = "half",
					name = "",
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.roleIcon.enabled
					end,
					hidden = function(info)
						return not self.db.profile[groupType].nameAndIcons.roleIcon.useCustomTextures
					end,
					set = function(info, r, g, b, a)
						self.db.profile[groupType].nameAndIcons.roleIcon.colors.tank = {r, g, b, a}
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						local color = self.db.profile[groupType].nameAndIcons.roleIcon.colors.tank
						return color[1], color[2], color[3], color[4]
					end
				},
				vehicle = {
					order = 27,
					type = "input",
					width = 1.5,
					name = L["Vehicle"],
					desc = L["Custom Texture Options"],
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.roleIcon.enabled
					end,
					hidden = function(info)
						return not self.db.profile[groupType].nameAndIcons.roleIcon.useCustomTextures
					end,
					set = function(info, val)
						val = strtrim(val)
						self.db.profile[groupType].nameAndIcons.roleIcon.vehicle = val

						if val == "" then
							self.RoleIcon_Revert()
						end

						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].nameAndIcons.roleIcon.vehicle
					end
				},
				vehicleColor = {
					order = 28,
					type = "color",
					hasAlpha = true,
					width = "half",
					name = "",
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.roleIcon.enabled
					end,
					hidden = function(info)
						return not self.db.profile[groupType].nameAndIcons.roleIcon.useCustomTextures
					end,
					set = function(info, r, g, b, a)
						self.db.profile[groupType].nameAndIcons.roleIcon.colors.vehicle = {r, g, b, a}
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						local color = self.db.profile[groupType].nameAndIcons.roleIcon.colors.vehicle
						return color[1], color[2], color[3], color[4]
					end
				},
				headerButtons = {
					order = 100,
					type = "header",
					name = "",
				},
				copyButton = {
					order = 101,
					type = "execute",
					width = "full",
					confirm = true,
					name = L["Copy settings to |cFFffd100<text>|r"]:gsub("<text>", groupType == "party" and L["Raid_decl"] or L["Party_decl"]),
					desc = L["Copy settings to |cFFffd100<text>|r"]:gsub("<text>", groupType == "party" and L["Raid_decl"] or L["Party_decl"]),
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.roleIcon.enabled
					end,
					func = function(info, val)
						self:CopySettings(self.db.profile[groupType].nameAndIcons.roleIcon, self.db.profile[self.ReverseGroupType(groupType)].nameAndIcons.roleIcon)
					end,
				},
				resetButton = {
					order = 102,
					type = "execute",
					width = "full",
					confirm = true,
					name = L["Reset to Default"],
					desc = "",
					disabled = function()
						return not self.db.profile[groupType].nameAndIcons.roleIcon.enabled
					end,
					func = function(info, val)
						self:RestoreDefaults(groupType,"nameAndIcons", "roleIcon")
					end,
				},
			},
		},
	}
end

function ADDON:CreateTexturesFrameOptions(groupType)
	return {
		health = {
			order = 1,
			type = "group",
			childGroups = "tab",
			name = L["Healthbar"],
			desc = "",
			args = {
				texture = {
					order = 1,
					type = "select",
					dialogControl = "LSM30_Statusbar",
					width = "full",
					values = AceGUIWidgetLSMlists.statusbar,
					name = L["Texture"],
					desc = "",
					set = function(info, val)
						self.db.profile[groupType].frames.texture = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].frames.texture
					end
				},
				headerColor = {
					order = 2,
					type = "header",
					name = "",
				},
				colorEnabled = {
					order = 3,
					type = "toggle",
					width = "full",
					name = L["Enable"],
					desc = "",
					set = function(info, val)
						self.db.profile[groupType].frames.colorEnabled = val

						if not val then
							self.HealthBar_Revert()
						end

						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].frames.colorEnabled
					end
				},
				color = {
					order = 4,
					type = "color",
					width = "normal",
					name = L["Healthbar Color"],
					desc = L["Healthbar Color Desc"],
					disabled = function(info)
						return not self.db.profile[groupType].frames.colorEnabled
					end,
					set = function(info, r, g, b, a)
						self.db.profile[groupType].frames.color = {r, g, b}
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						local color = self.db.profile[groupType].frames.color
						return color[1], color[2], color[3]
					end
				},
				backgroundColor = {
					order = 5,
					type = "color",
					width = "normal",
					name = L["Background Color"],
					desc = L["Background Color"],
					disabled = function(info)
						return not self.db.profile[groupType].frames.colorEnabled
					end,
					set = function(info, r, g, b, a)
						self.db.profile[groupType].frames.backgroundColor = {r, g, b}
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						local color = self.db.profile[groupType].frames.backgroundColor
						return color[1], color[2], color[3]
					end
				},
				headerBackground = {
					order = 6,
					type = "header",
					name = "",
				},
				alpha = {
					order = 7,
					type = "range",
					min = 0.1, max = 1.0, step = 0.05,
					width = "normal",
					name = L["Transparency"],
					desc = "",
					set = function(info, val)
						self.db.profile[groupType].frames.alpha = val

						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].frames.alpha
					end
				},
				backgoundAlpha = {
					order = 8,
					type = "range",
					min = 0.1, max = 1.0, step = 0.05,
					width = "normal",
					name = L["Background Transparency"],
					desc = "",
					set = function(info, val)
						self.db.profile[groupType].frames.backgoundAlpha = val

						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].frames.backgoundAlpha
					end
				},
				headerButtons = {
					type = "header",
					name = "",
					order = 100,
				},
				copyButton = {
					order = 101,
					type = "execute",
					width = "full",
					confirm = true,
					name = L["Copy settings to |cFFffd100<text>|r"]:gsub("<text>", groupType == "party" and L["Raid_decl"] or L["Party_decl"]),
					desc = L["Copy settings to |cFFffd100<text>|r"]:gsub("<text>", groupType == "party" and L["Raid_decl"] or L["Party_decl"]),
					func = function(info, val)
						local vars = {
							"alphaPowerBar",
							"alphaHealth",
							"advancedTransparency",
							"backgoundAlpha",
							"alpha",
						}

						self:CopySettingsByTable(
							self.db.profile[groupType].frames,
							self.db.profile[self.ReverseGroupType(groupType)].frames,
							vars
						)
					end,
				},
				resetButton = {
					order = 102,
					type = "execute",
					width = "full",
					confirm = true,
					name = L["Reset to Default"],
					desc = "",
					func = function(info, val)
						local vars = {
							"backgroundColor",
							"color",
							"colorEnabled",
							"texture",
						}
						self:RestoreDefaultsByTable(groupType, "frames", nil, vars)
					end,
				},
			}
		},
		powerbar = {
			order = 2,
			type = "group",
			childGroups = "tab",
			name = L["Power Bar"],
			desc = "",
			args = {
				powerBarTexture = {
					order = 1,
					type = "select",
					dialogControl = "LSM30_Statusbar",
					width = "full",
					values = AceGUIWidgetLSMlists.statusbar,
					name = L["Power Bar Texture"],
					desc = L["Show Resource Only For Healers Desc"],
					set = function(info, val)
						self.db.profile[groupType].frames.powerBarTexture = val
						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].frames.powerBarTexture
					end
				},
				powerBarHeight = {
					order = 2,
					type = "range",
					min = 1, max = 50, step = 1,
					width = "full",
					name = L["Power Bar Height"],
					desc = L["Show Resource Only For Healers Desc"],
					confirmText = L["Show Resource Only For Healers Desc"],
					confirm = function()
						return not self.displayPowerBar
					end,
					set = function(info, val)
						if val and not self.displayPowerBar then val = 8 end

						self.db.profile[groupType].frames.powerBarHeight = val

						self:SafeRefresh(groupType)
					end,
					get = function(info)
						return self.db.profile[groupType].frames.powerBarHeight
					end
				},
				showResourceOnlyForHealers = {
					order = 3,
					type = "toggle",
					width = "full",
					name = L["Show Resource Only For Healers"],
					desc = L["Show Resource Only For Healers Desc"],
					confirmText = L["Show Resource Only For Healers Desc"],
					confirm = function()
						return not self.displayPowerBar
					end,
					set = function(info, val)
						if val and not self.displayPowerBar then val = false end
						self.db.profile[groupType].frames.showResourceOnlyForHealers = val
						self.PowerBar_Revert()
					end,
					get = function(info)
						return self.db.profile[groupType].frames.showResourceOnlyForHealers
					end
				},
				headerButtons = {
					order = 100,
					type = "header",
					name = "",
				},
				copyButton = {
					order = 101,
					type = "execute",
					width = "full",
					confirm = true,
					name = L["Copy settings to |cFFffd100<text>|r"]:gsub("<text>", groupType == "party" and L["Raid_decl"] or L["Party_decl"]),
					desc = L["Copy settings to |cFFffd100<text>|r"]:gsub("<text>", groupType == "party" and L["Raid_decl"] or L["Party_decl"]),
					func = function(info, val)
						local vars = {
							"alphaPowerBar",
							"alphaHealth",
							"advancedTransparency",
							"backgoundAlpha",
							"alpha",
						}

						self:CopySettingsByTable(
							self.db.profile[groupType].frames,
							self.db.profile[self.ReverseGroupType(groupType)].frames,
							vars
						)
					end,
				},
				resetButton = {
					order = 102,
					type = "execute",
					width = "full",
					confirm = true,
					name = L["Reset to Default"],
					desc = "",
					func = function(info, val)
						local vars = {
							"powerBarTexture",
							"powerBarHeight",
							"showResourceOnlyForHealers",
						}

						self:RestoreDefaultsByTable(groupType, "frames", nil, vars)
					end,
				},
			},
		},
	}
end