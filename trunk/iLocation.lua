-----------------------------------
-- Setting up scope and libs
-----------------------------------

local AddonName, iLocation = ...;
LibStub("AceEvent-3.0"):Embed(iLocation);
LibStub("AceTimer-3.0"):Embed(iLocation);
LibStub("AceHook-3.0"):Embed(iLocation);

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local LibTourist = LibStub("LibTourist-3.0");

local _G = _G;
local format = _G.string.format; -- iLocation heavyly uses format!

-------------------------------
-- Registering with iLib
-------------------------------

LibStub("iLib"):Register(AddonName, nil, iLocation);

-----------------------------------------
-- Variables, functions and colors
-----------------------------------------

local CurrentZone = "";
local CurrentSubZone = "";
local CurrentPosX = 0;
local CurrentPosY = 0;

local DisplayBPZones = nil;
local recBPZones = {};

local CoordsTimer;

local COLOR_GOLD = "|cfffed100%s|r";

----------------------------
-- Setting up the LDB
----------------------------

iLocation.ldb = LibStub("LibDataBroker-1.1"):NewDataObject(AddonName, {
	type = "data source",
	text = AddonName,
});

iLocation.ldb.OnClick = function(_, button)
	if( button == "RightButton" and not _G.IsModifierKeyDown() ) then
		iLocation:OpenOptions();
	end
end

iLocation.ldb.OnEnter = function(anchor)
	if( iLocation:IsTooltip("Main") ) then
		return;
	end
	iLocation:HideAllTooltips();
	
	local tip = iLocation:GetTooltip("Main", "UpdateTooltip");
	tip:SmartAnchorTo(anchor);
	tip:SetAutoHideDelay(0.1, anchor);
	tip:Show();
end

iLocation.ldb.OnLeave = function() end

----------------------
-- OnInitialize
----------------------

function iLocation:Boot()
	self.db = LibStub("AceDB-3.0"):New("iLocationDB", self:CreateDB(), "Default").profile;
	
	self:RegisterEvent("ZONE_CHANGED", "EventHandler");
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "EventHandler");
	
	-- Pet Battles
	self:RegisterEvent("MINIMAP_UPDATE_TRACKING", "UpdateMinimapTracking");
	self:RegisterEvent("PET_BATTLE_LEVEL_CHANGED", "CalculateRecBPZones");
	self:RegisterEvent("BATTLE_PET_CURSOR_CLEAR", "CalculateRecBPZones");
	
	self:SecureHook("MoveBackwardStart", "StartMoving");
	self:SecureHook("MoveBackwardStop", "StopMoving");
	self:SecureHook("MoveForwardStart", "StartMoving");
	self:SecureHook("MoveForwardStop", "StopMoving");
	self:SecureHook("StrafeLeftStart", "StartMoving");
	self:SecureHook("StrafeLeftStop", "StopMoving");
	self:SecureHook("StrafeRightStart", "StartMoving");
	self:SecureHook("StrafeRightStop", "StartMoving");
	self:SecureHook("ToggleAutoRun", "StartOrStopAutoRun");
	
	self:EventHandler();
	self:UpdateCoords();
	self:UpdateMinimapTracking();
	
	self:UnregisterEvent("PLAYER_ENTERING_WORLD");
end
iLocation:RegisterEvent("PLAYER_ENTERING_WORLD", "Boot");

--------------------
-- Battle Pet
--------------------

local function calculate_pet_levels()	
	-- dirty hack, pet levels are always lower than player levels and we need a value which is higher than pet levels could be
	-- to calculate the lowest level. Why not use MAX_PET_LEVEL? it is set local in Blizzard_PetJournal.lua -.-
	local lowest, highest = _G.MAX_PLAYER_LEVEL, 0;
	
	local level;
	local petID, _, slotLocked;
	
	for i = 1, 3 do
		petID, _, _, _, slotLocked = _G.C_PetJournal.GetPetLoadOutInfo(i);
		
		if( not slotLocked and petID )then
			level = select(3, _G.C_PetJournal.GetPetInfoByPetID( petID )) or 0;
			
			if( level < lowest ) then
				lowest = level;
			end
			
			if( level > highest ) then
				highest = level;
			end
			
		end
	end
	
	return lowest, highest;
end

function iLocation:CalculateRecBPZones()
	if( not DisplayBPZones ) then
		return;
	end
	
	_G.wipe(recBPZones);
	
	local petLowest, petHighest, petAvg = calculate_pet_levels();
	
	local low, high;
	for zone in LibTourist:IterateZones() do
		low, high = LibTourist:GetBattlePetLevel(zone);
		high = low and not high and low or high;
		
		if( low and ((petLowest - low) <= 2) and (high - petLowest <= 2) ) then
			table.insert(recBPZones, zone);
		end
	end
	
	table.sort(recBPZones);
end

function iLocation:UpdateMinimapTracking()
	local _, icon, active;
	
	for i = 1, _G.GetNumTrackingTypes() do
		_, icon, active = _G.GetTrackingInfo(i);
		
		if( icon == "Interface\\Icons\\tracking_wildpet" ) then			
			DisplayBPZones = active;			
			self:CalculateRecBPZones();
			
			return;
		end
	end
end

------------------------
-- Moving Control
------------------------

local toggleAutoRun = false;

function iLocation:StartOrStopAutoRun()
	toggleAutoRun = not toggleAutoRun;
	
	if( toggleAutoRun ) then
		self:StartMoving();
	else
		self:StopMoving();
	end
end

do
	local ratio, speed, speedwalk, speedfly;
	
	function iLocation:StartMoving()
		if( CoordsTimer ) then
			return;
		end
		
		speed, speedwalk, speedfly = _G.GetUnitSpeed("player"); -- we determine our normal and flying speed
		-- the more speed we have, the lesser is the result
		-- this brings us as more coordinates updates as faster we are :)
		speed = 1 / ((_G.IsFlying() and speedfly or speedwalk) / 7); -- since WoW speed is based on 7, we recalc it to base 10
		ratio = 2 / (self.db.DecimalDigits + 1) * speed; -- the faster we are, the lower is the update ratio
		
		CoordsTimer = self:ScheduleRepeatingTimer("UpdateCoords", ratio);
	end
end

function iLocation:StopMoving()
	if( not CoordsTimer ) then
		return;
	end
	
	self:CancelTimer(CoordsTimer);
	CoordsTimer = nil;
	toggleAutoRun = false;
	self:UpdateCoords();
end

function iLocation:UpdateCoords()
	CurrentPosX, CurrentPosY = _G.GetPlayerMapPosition("player");
	iLocation:UpdatePlugin();
end

-----------------------
-- Event Handling
-----------------------

function iLocation:EventHandler()
	CurrentZone = _G.GetRealZoneText() or _G.UNKNOWN;
	CurrentZone = CurrentZone == "" and _G.UNKNOWN or CurrentZone;
	
	CurrentSubZone = _G.GetSubZoneText() or "";
	
	self:UpdatePlugin();
end

-----------------------
-- Update Plugin
-----------------------

local function format_zone(zone, subzone)
	if( not zone ) then
		zone = CurrentZone;
	end
	if( subzone and CurrentSubZone == "" ) then
		subzone = nil;
	end
	
	local r, g, b;
		
	-- encolor by difficulty
	if( iLocation.db.ZoneColor == 2 ) then
		r, g, b = LibTourist:GetLevelColor(zone);
		return ("|cff%02x%02x%02x%s|r"):format(r *255, g *255, b *255, zone..(subzone and ": "..CurrentSubZone or ""));
	-- encolor by faction
	elseif( iLocation.db.ZoneColor == 3 ) then
		r, g, b = LibTourist:GetFactionColor(zone);
		return ("|cff%02x%02x%02x%s|r"):format(r *255, g *255, b *255, zone..(subzone and ": "..CurrentSubZone or ""));
	-- encolor gold
	else
		return (COLOR_GOLD):format(zone..(subzone and ": "..CurrentSubZone or ""));
	end
end

local function format_coords(x, y)
	if( not x ) then
		x = CurrentPosX *100;
	end
	if( not y ) then
		y = CurrentPosY *100;
	end
	
	if( (x + y) == 0 ) then
		return "";
	end
	return ("%."..iLocation.db.DecimalDigits.."f, %."..iLocation.db.DecimalDigits.."f"):format(x, y);
end

local function format_level(min, max, r, g, b)
	return ("|cff%02x%02x%02x%s|r"):format(r *255, g *255, b *255, (min == max and min or ("%d-%d"):format(min, max)));
end

function iLocation:UpdatePlugin()
	if( self.db.ShowCoordinates ) then
		local coords = format_coords();
		self.ldb.text = format_zone()..(coords ~= "" and " " or "")..coords;
	else
		self.ldb.text = format_zone();
	end
	
	self:CheckTooltips("Main");
end

-----------------------
-- UpdateTooltip
-----------------------

local function get_pvp_status()
	local pvptype = _G.GetZonePVPInfo();
		
	if( pvptype == "arena" ) then
		return _G.ARENA;
	elseif( pvptype == "friendly" ) then
		return _G.FRIENDLY;
	elseif( pvptype == "contested" ) then
		return L["Contested"];
	elseif( pvptype == "hostile" ) then
		return _G.HOSTILE;
	elseif( pvptype == "sanctuary" ) then
		return L["Sanctuary"];
	elseif( pvptype == "combat" ) then
		return _G.COMBAT;
	else
		return _G.UNKNOWN;
	end
end

local function add_zone(tip, zone, isPet)
	local r, g, b, min, max;
	local size, entrance, x, y = "", "", 0, 0;
		
	if( LibTourist:IsArena(zone) or LibTourist:IsBattleground(zone) or LibTourist:IsPvPZone(zone) ) then
		return;
	end
		
	if( LibTourist:IsInstance(zone) ) then
		size = LibTourist:GetInstanceGroupSize(zone);
		if( size >= 10 ) then
			if( iLocation.db.HideRaids ) then
				return;
			end
			size = "+";
		else
			size = "";
		end
		entrance, x, y = LibTourist:GetEntrancePortalLocation(zone);
	end
	
	if( not isPet ) then
		r, g, b = LibTourist:GetLevelColor(zone);
		min, max = LibTourist:GetLevel(zone);
	else
		-- additional filter
		-- no hostile faction citys please :)
		if( LibTourist:IsCity(zone) and LibTourist:IsHostile(zone) ) then
			return;
		end
		
		local petLevel = calculate_pet_levels();
		r, g, b = LibTourist:GetBattlePetLevelColor(zone, petLevel);
		min, max = LibTourist:GetBattlePetLevel(zone);
	end
	
	tip:AddLine(
		zone, -- zone name
		format_level(min, max, r, g, b), -- level req
		(iLocation.db.HideRaids and nil or size),
		(iLocation.db.HideEntrances and nil or format_zone(entrance or "")),
		(iLocation.db.HideEntrances and nil or format_coords(x or 0, y or 0))
	);
end

local _initial_pet_calc;
function iLocation:UpdateTooltip(tip)
	tip:Clear();
	tip:SetColumnLayout(
		2 + (self.db.HideEntrances and 0 or 2) + (self.db.HideRaids and 0 or 1),
		"LEFT", (self.db.HideRaids and "RIGHT" or "CENTER"), "CENTER", "LEFT", "RIGHT"
	);
	
	if( LibStub("iLib"):IsUpdate(AddonName) ) then
		line = tip:AddHeader("");
		tip:SetCell(line, 1, "|cffff0000"..L["Addon update available!"].."|r", nil, "CENTER", 0);
	end
	
	local r, g, b, line;
	
	-- add zone name
	line = tip:AddLine("");
	tip:SetCell(line, 1, format_zone(nil, true), nil, "CENTER", 0);
	tip:AddLine("");
	
	-- add coordinates
	local coords = format_coords();
	if( coords ~= "" ) then
		line = tip:AddLine((COLOR_GOLD):format(L["Position:"]));
		tip:SetCell(line, 2, coords, nil, "RIGHT", 0);
	end
	
	-- add pvp status
	-- we need to check if it's a sanctuary, because Tourist encolors them yellow in some cases. I really dislike hardcoding.
	r, g, b = LibTourist:GetFactionColor(CurrentZone);
	if( get_pvp_status() == L["Sanctuary"] ) then
		r, g, b = 0.41, 0.8, 0.94;
	end
	line = tip:AddLine((COLOR_GOLD):format(_G.STATUS..":"));
	tip:SetCell(line, 2, ("|cff%02x%02x%02x%s|r"):format(r *255, g *255, b *255, get_pvp_status()), nil, "RIGHT", 0);
	
	-- add level
	local min, max = LibTourist:GetLevel(CurrentZone);
	if( min > 0 and max > 0 ) then
		r, g, b = LibTourist:GetLevelColor(CurrentZone);
		line = tip:AddLine((COLOR_GOLD):format(_G.LEVEL..":"));
		tip:SetCell(line, 2, format_level(min, max, r, g, b), nil, "RIGHT", 0);
	end
	
	-- add battle pet level
	line = tip:AddLine((COLOR_GOLD):format(L["Battle Pets:"]));
	tip:SetCell(line, 2, LibTourist:GetBattlePetLevelString(CurrentZone), nil, "RIGHT", 0);
	
	-- add continent
	line = tip:AddLine((COLOR_GOLD):format(_G.CONTINENT..":"));
	tip:SetCell(line, 2, LibTourist:GetContinent(CurrentZone), nil, "RIGHT", 0);
	
	-- add pet battle zones if needed
	if( not _initial_pet_calc ) then
		self:CalculateRecBPZones();
		_initial_pet_calc = 1;
	end
	
	if( DisplayBPZones ) then
		tip:AddLine(" ");
		tip:AddLine((COLOR_GOLD):format(L["Pet Battle Zones:"]));
		
		for _,zone in ipairs(recBPZones) do
			add_zone(tip, zone, 1);
		end
	end
	
	-- add existing instances in a zone
	if( self.db.ShowZoneInstances and LibTourist:DoesZoneHaveInstances(CurrentZone) ) then
		tip:AddLine(" ");
		tip:AddLine((COLOR_GOLD):format(_G.DUNGEONS..":"));
		
		for zone in LibTourist:IterateZoneInstances(CurrentZone) do
			add_zone(tip, zone);
		end
	end
	
	-- if not max level, show recommended zones
	if( self.db.AlwaysLevelmode or _G.UnitLevel("player") < _G.MAX_PLAYER_LEVEL ) then
		if( self.db.ShowRecZones ) then
			tip:AddLine(" ");
			tip:AddLine((COLOR_GOLD):format(L["Recommended Zones:"]));
			
			for zone in LibTourist:IterateRecommendedZones() do
				add_zone(tip, zone);
			end
		end
		
		if( self.db.ShowRecInstances ) then
			tip:AddLine(" ");
			tip:AddLine((COLOR_GOLD):format(L["Recommended Dungeons:"]));
			
			for zone in LibTourist:IterateRecommendedInstances() do
				add_zone(tip, zone);
			end
		end
	end
end