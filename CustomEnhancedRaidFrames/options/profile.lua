local ADDON_NAME, PRIVATE = ...
local ADDON = PRIVATE.ADDON
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

-- GLOBALS: GameMenuFrame, InterfaceOptionsFrame, ReloadUI

function ADDON:CreateProfileOptions()
	return {
		order = 2,
		type = "group",
		childGroups = "tab",
		name = L["Import/Export"],

		args = {
			export = {
				order = 2,
				type = "execute",
				width = "full",
				name = L["Export Profile"],
				desc = "",
				func = function(info, val)
					self:ExportCurrentProfile(self:ExportProfileToString())
					InterfaceOptionsFrame:Hide()
					GameMenuFrame:Hide()
				end,
			},
			import = {
				order = 3,
				type = "input",
				multiline = 10,
				width = "full",
				confirm = true,
				confirmText = L["Are You sure?"],
				name = L["Import Profile"],
				desc = "",
				set = function(info, val)
					if self:ImportCurrentProfile(val) then
						ReloadUI()
					end
				end,
			},
		},
	}
end
