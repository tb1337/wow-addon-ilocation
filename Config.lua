-----------------------------
-- Get the addon table
-----------------------------

local AddonName = select(1, ...);
local iLocation = LibStub("AceAddon-3.0"):GetAddon(AddonName);

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

---------------------------------
-- The configuration table
---------------------------------

local function CreateConfig()
	CreateConfig = nil; -- we just need this function once, thus removing it from memory.

	local db = {
		type = "group",
		name = AddonName,
		order = 1,
		args = {
			ColOne = {
				type = "group",
				name = L["Feed Options"],
				order = 1,
				inline = true,
				args = {
					ZoneColor = {
					type = "select",
					name = L["Encolor zone names by"],
					order = 1,
					values = {
						[1] = _G.NONE,
						[2] = L["By Difficulty"],
						[3] = L["By Hostility"],
					},
					get = function()
						return iLocation.db.ZoneColor;
					end,
					set = function(info, value)
						iLocation.db.ZoneColor = value;
					end,
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
						get = function()
							return iLocation.db.ShowZoneInstances;
						end,
						set = function(info, value)
							iLocation.db.ShowZoneInstances = value;
						end,
					},
					ShowRecInstances = {
						type = "toggle",
						name = L["Show recommended dungeons"],
						order = 3,
						width = "full",
						get = function()
							return iLocation.db.ShowRecInstances;
						end,
						set = function(info, value)
							iLocation.db.ShowRecInstances = value;
						end,
					},
					ShowRecZones = {
						type = "toggle",
						name = L["Show recommended zones"],
						order = 2,
						width = "full",
						get = function()
							return iLocation.db.ShowRecZones;
						end,
						set = function(info, value)
							iLocation.db.ShowRecZones = value;
						end,
					},
					header1 = {
						type = "header",
						name = "",
						order = 4,
					},
					AlwaysLevelmode = {
						type = "toggle",
						name = L["Always enabled Levelmode"],
						order = 5,
						width = "full",
						get = function()
							return iLocation.db.AlwaysLevelmode;
						end,
						set = function(info, value)
							iLocation.db.AlwaysLevelmode = value;
						end,
					},
					header2 = {
						type = "header",
						name = "",
						order = 6,
					},
					HidePvPZones = {
						type = "toggle",
						name = L["Hide Battlegrounds, Arenas and PvP-Zones"],
						order = 8,
						width = "full",
						get = function()
							return iLocation.db.HidePvPZones;
						end,
						set = function(info, value)
							iLocation.db.HidePvPZones = value;
						end,
					},
					HideRaids = {
						type = "toggle",
						name = L["Hide Raids"],
						order = 7,
						width = "full",
						get = function()
							return iLocation.db.HideRaids;
						end,
						set = function(info, value)
							iLocation.db.HideRaids = value;
						end,
					},
				},
			},
		}
	};
	
	return db;
end

function iLocation:CreateDB()
	iLocation.CreateDB = nil;
	
	return { profile = {
		ShowZoneInstances = true,
		ShowRecInstances = true,
		ShowRecZones = true,
		ZoneColor = 3,
		AlwaysLevelmode = false,
		HidePvPZones = false,
		HideRaids = false,
	}};
end

function iLocation:OpenOptions()
	_G.InterfaceOptionsFrame_OpenToCategory(AddonName);
end

LibStub("AceConfig-3.0"):RegisterOptionsTable(AddonName, CreateConfig);
LibStub("AceConfigDialog-3.0"):AddToBlizOptions(AddonName);
_G.SlashCmdList["ILOCATION"] = iLocation.OpenOptions;
_G["SLASH_ILOCATION1"] = "/ilocation";