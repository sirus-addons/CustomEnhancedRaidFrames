local ADDON_NAME, PRIVATE = ...
local ADDON = PRIVATE.ADDON

ADDON.DEFAULT_FONT = "Friz Quadrata TT" or LibStub("LibSharedMedia-3.0").DefaultMedia.font

local strformat = string.format

local getGroupDefaults = function(groupType)
	return {
		frames = {
			hideGroupTitles = false,
			texture = "Blizzard Raid Bar",
			clickThrough = false,
			tracking = {},
			trackingStr = "",
			autoScaling = true,
			showResourceOnlyForHealers = false,
			alpha = 1.0,
			backgoundAlpha = 1.0,
			powerBarHeight = 8,
			powerBarTexture = "Blizzard Raid PowerBar",
			colorEnabled = false,
			color = {1, 1, 1},
			backgroundColor = {0.1, 0.1, 0.1},
		},
		dispelDebuffFrames = {
			num = 3,
			numInRow = 3,
			rowsGrowDirection = "TOP",
			anchorPoint = "TOPRIGHT",
			growDirection = "LEFT",
			size = 12,
			xOffset = 0,
			yOffset = 0,
			exclude = {},
			excludeStr = "",
			alpha = 1.0,
		},
		debuffFrames = {
			num = 3,
			numInRow = 3,
			rowsGrowDirection = "TOP",
			anchorPoint = "BOTTOMLEFT",
			growDirection = "RIGHT",
			size = 11,
			xOffset = 0,
			yOffset = 0,
			exclude = {},
			excludeStr = "",
			bigDebuffSize = 11 + 9,
			showBigDebuffs = true,
			smartAnchoring = true,
			alpha = 1.0,
		},
		buffFrames = {
			num = 3,
			numInRow = 3,
			rowsGrowDirection = "TOP",
			anchorPoint = "BOTTOMRIGHT",
			growDirection = "LEFT",
			size = 11,
			xOffset = 0,
			yOffset = 0,
			exclude = {},
			excludeStr = "",
			alpha = 1.0,
		},
		nameAndIcons = {
			name = {
				enabled = false,
				hide = false,
				size = 7,
				xOffset = 0,
				yOffset = 0,

				font = ADDON.DEFAULT_FONT,
				flag = "None",
				hJustify = "LEFT",
				freeAnchor = false,
				useClassColor = false,
				showServer = true,
			},
			statusText = {
				enabled = false,
				size = 12,
				xOffset = 0,
				yOffset = 0,

				font = ADDON.DEFAULT_FONT,
				flag = "None",
				hJustify = "CENTER",
				abbreviateNumbers = false,
				precision = 1,
				hideStatusText = false,
				showPercents = false,

				useClassColor = false,
				color = {1, 1, 1, 1},
			},
			readyCheckIcon = {
				enabled = false,
				hide = false,
				size = 15,
				xOffset = 0,
				yOffset = 0,

				useCustomTextures = false,
				ready = "",
				notready = "",
				waiting = "",
				colors = {
					ready = {1, 1, 1, 1},
					notready = {1, 1, 1, 1},
					waiting = {1, 1, 1, 1},
				},
			},
			centerStatusIcon = {
				enabled = false,
				hide = false,
				size = 22,
				xOffset = 0,
				yOffset = 0,

				useCustomTextures = false,
				hasIncomingResurrection = "",
				hasIncomingSummonPending = "",
				hasIncomingSummonAccepted = "",
				hasIncomingSummonDeclined = "",
				colors = {
					hasIncomingResurrection = {1, 1, 1, 1},
					hasIncomingSummonPending = {1, 1, 1, 1},
					hasIncomingSummonAccepted = {1, 1, 1, 1},
					hasIncomingSummonDeclined = {1, 1, 1, 1},
				},
			},
			raidTargetIcon = {
				enabled = false,
				hide = false,
				size = 15,
				xOffset = 0,
				yOffset = 0,
				anchorPoint = "TOP",
				alpha = 1.0,
			},
			roleGroupIcon = {
				enabled = false,
				hide = false,
				size = 10,
				xOffset = 0,
				yOffset = 0,
				anchorPoint = "TOPRIGHT",
				alpha = 1.0,
			},
			roleIcon = {
				enabled = false,
				hide = false,
				size = 12,
				xOffset = 0,
				yOffset = 0,
				anchorPoint = "LEFT",
				alpha = 1.0,

				useCustomTextures = false,
				tank = strformat("Interface\\AddOns\\%s\\media\\icons\\%s", ADDON_NAME, "tank"),
				damager = strformat("Interface\\AddOns\\%s\\media\\icons\\%s", ADDON_NAME, "damager"),
				healer = strformat("Interface\\AddOns\\%s\\media\\icons\\%s", ADDON_NAME, "healer"),
				vehicle = "",
				colors = {
					healer = {1, 1, 1, 1},
					damager = {1, 1, 1, 1},
					tank = {1, 1, 1, 1},
					vehicle = {1, 1, 1, 1},
				},
			},
		},
	}
end

local getGlowDefaults = function()
	return {
		pixel = {
			options = {
				color = {0.95, 0.95, 0.32, 1},
				N = 8,
				length = false,
				frequency = 0.25,
				th = 2,
				xOffset = 0,
				yOffset = 0,
				border = false,
			},
		},
		auto = {
			options = {
				color = {0.95, 0.95, 0.32, 1},
				N = 4,
				frequency = 0.125,
				scale = 1,
				xOffset = 0,
				yOffset = 0,
			},
		},
		button = {
			options = {
				color = {0.95, 0.95, 0.32, 1},
				frequency = 0.125,
			},
		},
	}
end

PRIVATE.DEFAULTS_GLOW = getGlowDefaults()

PRIVATE.DEFAULTS = {
	profile = {
		current_profile = "default",
		saved_profiles = {
			default = {
				displayPowerBar = true,
				frameHeight = ADDON.NATIVE_UNIT_FRAME_HEIGHT,
				frameWidth = ADDON.NATIVE_UNIT_FRAME_WIDTH,
				displayBorder = true,
				keepGroupsTogether = false,
				displayPets = true,
				useCompactPartyFrames = true,
				horizontalGroups = false,
				displayMainTankAndAssist = false,
			}
		},

		Masque = false,

		healPrediction = {
			absorbs = true,
			absorbsEnhanced = false,

			heal = true,
			healThresholdSeconds = 3.0,
			healMaxOverflowPercent = 1.05,
		},

		party = getGroupDefaults("party"),
		raid = getGroupDefaults("raid"),

		glows = {
			auraGlow = {
				buffFrames = {
					type = "pixel",
					options = getGlowDefaults(),
					tracking = {},
					trackingStr = "",
					enabled = false,
					useDefaultsColors = true,
				},
				debuffFrames = {
					type = "pixel",
					options = getGlowDefaults(),
					tracking = {},
					trackingStr = "",
					enabled = false,
					useDefaultsColors = true,
				},
				defaultColors = CopyTable(ADDON.debuffsColors),
			},
			frameGlow = {
				buffFrames = {
					type = "pixel",
					options = getGlowDefaults(),
					tracking = {},
					trackingStr = "",
					enabled = false,
					useDefaultsColors = true,
				},
				debuffFrames = {
					type = "pixel",
					options = getGlowDefaults(),
					tracking = {},
					trackingStr = "",
					enabled = false,
					useDefaultsColors = true,
				},
				defaultColors = CopyTable(ADDON.debuffsColors),
			},
			glowBlockList = {
				tracking = {},
				trackingStr = "",
			},
		}
	}
}