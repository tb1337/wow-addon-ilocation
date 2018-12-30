-----------------------------
-- Get the addon table
-----------------------------

local AddonName, iLocation = ...;

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local _G = _G;

---------------------------------
-- The option table
---------------------------------

function iLocation:CreateDB()
	iLocation.CreateDB = nil;
	
	return { profile = {
		ShowCoordinates = true,
		SurroundCoordinates = 1,
		ShowZoneInstances = true,
		ShowRecInstances = true,
		ShowRecZones = true,
		ZoneColor = 3,
		ZoneText = 3,
		AlwaysLevelmode = false,
		DecimalDigits = 1,
		HideRaids = false,
		HideEntrances = true,
	}};
end

---------------------------------
-- The configuration table
---------------------------------

local function cfg()
	cfg = nil; -- we just need this function once, thus removing it from memory.

	return {
		type = "group",
		name = AddonName,
		order = 1,
		get = function(info)
			return iLocation.db[info[#info]];
		end,
		set = function(info, value)
			iLocation.db[info[#info]] = value;
		end,
		args = {
			ColOne = {
				type = "group",
				name = L["General Options"],
				order = 1,
				inline = true,
				args = {
					DecimalDigits = {
						type = "range",
						name = L["Decimal digits"],
						desc = L["The number of decimal digits for coordinates."],
						order = 1,
						min = 0,
						max = 2,
						step = 1,
					},
					ZoneColor = {
						type = "select",
						name = L["Encolor zone names"],
						order = 5,
						values = {
							[1] = _G.NONE,
							[2] = L["By Difficulty"],
							[3] = L["By Hostility"],
						},
					},
					Spacer1 = {
						type = "description",
						name = " ",
						fontSize = "small",
						order = 10,
					},
					ShowCoordinates = {
						type = "toggle",
						name = L["Display coordinates on the plugin"],
						order = 15,
						width = "double"
					},
					SurroundCoordinates = {
						type = "select",
						name = L["Surround coordinates"],
						order = 20,
						values = {
							[1] = _G.NO,
							[2] = "( )",
							[3] = "[ ]",
							[4] = "{ }",
							[5] = "< >",
						},
					},
					Spacer2 = {
						type = "description",
						name = " ",
						fontSize = "small",
						order = 25,
					},
					ZoneText = {
						type = "select",
						name = L["Plugin Display"],
						order = 25,
						values = {
							[1] = L["Only Zone"],
							[2] = L["Only Subzone"],
							[3] = L["Both"],
							[4] = _G.NONE,
						},
					},
				},
			},
			ColTwo = {
				type = "group",
				name = L["Tooltip Options"],
				order = 2,
				inline = true,
				args = {
					ShowZoneInstances = {
						type = "toggle",
						name = L["Show dungeons in zone"],
						order = 1,
						width = "full",
					},
					ShowRecZones = {
						type = "toggle",
						name = L["Show recommended zones"],
						order = 2,
						width = "full",
					},
					ShowRecInstances = {
						type = "toggle",
						name = L["Show recommended dungeons"],
						order = 3,
						width = "full",
					},
					HideEntrances = {
						type = "toggle",
						name = L["Hide Dungeon Entrances"],
						order = 4,
						width = "full",
					},
					header1 = {
						type = "header",
						name = "",
						order = 5,
					},
					AlwaysLevelmode = {
						type = "toggle",
						name = L["Always enabled Levelmode"],
						desc = L["Recommended zones or instances are only shown when you are not at maximum level. If enabled, they are always shown."],
						order = 6,
						width = "full",
					},
					header2 = {
						type = "header",
						name = _G.FILTERS,
						order = 7,
					},
					HideRaids = {
						type = "toggle",
						name = L["Hide Raids"],
						order = 8,
						width = "full",
					},
				},
			},
		}
	};
end

function iLocation:OpenOptions()
	_G.InterfaceOptionsFrame_OpenToCategory(AddonName);
end

LibStub("AceConfig-3.0"):RegisterOptionsTable(AddonName, cfg);
LibStub("AceConfigDialog-3.0"):AddToBlizOptions(AddonName);
_G.SlashCmdList["ILOCATION"] = iLocation.OpenOptions;
_G["SLASH_ILOCATION1"] = "/ilocation";