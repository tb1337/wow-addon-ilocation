-----------------------------------
-- Setting up scope and libs
-----------------------------------

local AddonName = select(1, ...);
iLocation = LibStub("AceAddon-3.0"):NewAddon(AddonName, "AceEvent-3.0");

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local LibQTip = LibStub("LibQTip-1.0");
local LibTourist = LibStub("LibTourist-3.0");

local _G = _G;
local format = _G.string.format; -- iLocation heavyly uses format!

-----------------------------------------
-- Variables, functions and colors
-----------------------------------------

local Tooltip; -- our tooltip
local CoordsTimer;

local CurrentZone = "";
local CurrentZoneColored = "";
local CurrentSubZone = "";
local CurrentPosX = 0;
local CurrentPosY = 0;

local COLOR_GOLD = "|cfffed100%s|r";

-----------------------------
-- Setting up the feed
-----------------------------

iLocation.Feed = LibStub("LibDataBroker-1.1"):NewDataObject(AddonName, {
	type = "data source",
	text = "iLocation",
	--icon = "Interface\\Addons\\iLocation\\Images\\iGuild",
});

iLocation.Feed.OnClick = function(_, button)
	if( button == "RightButton" ) then
		iLocation:OpenOptions();
	end
end

iLocation.Feed.OnEnter = function(anchor)
	for k, v in LibQTip:IterateTooltips() do
		if( type(k) == "string" and strsub(k, 1, 6) == "iSuite" ) then
			v:Release(k);
		end
	end
		
	Tooltip = LibQTip:Acquire("iSuite"..AddonName);
	--Tooltip:SetAutoHideDelay(0.1, anchor);
	Tooltip:SmartAnchorTo(anchor);
	iLocation:UpdateTooltip();
	Tooltip:Show();
end

iLocation.Feed.OnLeave = function()
	Tooltip:Release();
end

----------------------
-- OnInitialize
----------------------

function iLocation:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("iLocationDB", self:CreateDB(), "Default").profile;
	CoordsTimer = LibStub("AceTimer-3.0"):ScheduleRepeatingTimer(self.UpdateCoords, 1);
	
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateZone");
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "UpdateZone");
	self:RegisterEvent("ZONE_CHANGED", "UpdateZone");
	
end

-----------------------
-- Event Handling
-----------------------

function iLocation:UpdateZone()
	CurrentZone = _G.GetRealZoneText() or _G.UNKNOWN;
	CurrentZone = CurrentZone == "" and _G.UNKNOWN or CurrentZone;
	
	local r, g, b;
	-- encolor by difficulty
	if( self.db.ZoneColor == 2 ) then
		r, g, b = LibTourist:GetLevelColor(CurrentZone);
		CurrentZoneColored = ("|cff%02x%02x%02x%s|r"):format(r *255, g *255, b *255, CurrentZone);
	elseif( self.db.ZoneColor == 3 ) then
		r, g, b = LibTourist:GetFactionColor(CurrentZone);
		CurrentZoneColored = ("|cff%02x%02x%02x%s|r"):format(r *255, g *255, b *255, CurrentZone);
	else
		CurrentZoneColored = (COLOR_GOLD):format(CurrentZone);
	end
	
	CurrentSubZone = _G.GetSubZoneText() or _G.UNKNOWN;
	CurrentSubZone = CurrentSubZone == "" and _G.UNKNOWN or CurrentSubZone;
	
	self:UpdateFeed();
end

function iLocation:UpdateCoords()
	CurrentPosX, CurrentPosY = _G.GetPlayerMapPosition("player");
	iLocation:UpdateFeed();
end

-----------------------
-- Update Feed
-----------------------

function iLocation:UpdateFeed()
	self.Feed.text = CurrentZoneColored;
	self.Feed.text = self.Feed.text.." "..("%.0f,%.0f"):format(CurrentPosX *100, CurrentPosY *100);
	
	if( LibQTip:IsAcquired("iSuite"..AddonName) ) then
		self:UpdateTooltip();
	end
end

-----------------------
-- UpdateTooltip
-----------------------

local PVPStatus;
do
	local pvptype;
	
	PVPStatus = function()
		pvptype = _G.GetZonePVPInfo();
		
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
end

local AddZone;
do
	local r, g, b, isPvP, isRaid;
	
	AddZone = function(zone)
		isPvP = nil;
		isRaid = nil;
		
		-- check if it's PvP and filter it, if set in the options
		if( LibTourist:IsPvPZone(zone) or LibTourist:IsArena(zone) or LibTourist:IsBattleground(zone) ) then
			if( iLocation.db.HidePvPZones ) then
				return;
			end
			isPvP = true;
		end
		
		-- check if it's a raid and filter it, if set in the options
		-- if it's a PvP zone, we cancel the check for group size
		if( not isPvP and LibTourist:GetInstanceGroupSize(zone) >= 10 ) then
			if( iLocation.db.HideRaids ) then
				return;
			end
			isRaid = true;
		end
		
		r, g, b = LibTourist:GetLevelColor(zone);
		mini, maxi = LibTourist:GetLevel(zone);
		Tooltip:AddLine(zone, ("|cff%02x%02x%02x%s|r"):format(r *255, g *255, b *255,
			(mini == maxi and mini or ("%d-%d"):format(mini, maxi))..
			(isPvP and " |cffff0000".._G.PVP.."|r" or "")..
			(isRaid and " |cffff4400".._G.RAID.."|r" or "")
		));
	end
end

function iLocation:UpdateTooltip()
	Tooltip:Clear();
	Tooltip:SetColumnLayout(2, "LEFT", "LEFT");
	
	-- add zone name
	local r, g, b = LibTourist:GetFactionColor(CurrentZone);
	Tooltip:AddLine((COLOR_GOLD):format(L["Zone:"]), CurrentZoneColored.." "..("%.0f,%.0f"):format(CurrentPosX *100, CurrentPosY *100));
	
	-- sub zone may be unknown or empty string
	if( CurrentSubZone ~= "" and CurrentSubZone ~= _G.UNKNOWN ) then
		Tooltip:AddLine((COLOR_GOLD):format(L["Subzone:"]), CurrentSubZone);
	end
	
	-- add pvp status
	-- we need to check if it's a sanctuary, because Tourist encolors them yellow in some cases. I really dislike hardcoding.
	if( PVPStatus() == L["Sanctuary"] ) then
		r, g, b = 0.41, 0.8, 0.94;
	end
	Tooltip:AddLine((COLOR_GOLD):format(_G.STATUS..":"), ("|cff%02x%02x%02x%s|r"):format(r *255, g *255, b *255, PVPStatus()));
	
	-- add level
	local mini, maxi = LibTourist:GetLevel(CurrentZone);
	if( mini > 0 and maxi > 0 ) then
		r, g, b = LibTourist:GetLevelColor(CurrentZone);
		Tooltip:AddLine((COLOR_GOLD):format(_G.LEVEL..":"), ("|cff%02x%02x%02x%s|r"):format(r *255, g *255, b *255, mini == maxi and mini or ("%d-%d"):format(mini, maxi)));
	end
	
	-- add continent
	Tooltip:AddLine((COLOR_GOLD):format(_G.CONTINENT..":"), LibTourist:GetContinent(CurrentZone));
	
	-- add existing instances in a zone
	if( self.db.ShowZoneInstances and LibTourist:DoesZoneHaveInstances(CurrentZone) ) then
		Tooltip:AddLine(" ");
		Tooltip:AddLine((COLOR_GOLD):format(_G.DUNGEONS..":"));
		
		for zone in LibTourist:IterateZoneInstances(CurrentZone) do
			AddZone(zone);
		end
	end
	
	-- if not max level, show recommended zones
	if( self.db.AlwaysLevelmode or UnitLevel("player") < MAX_PLAYER_LEVEL ) then
		if( self.db.ShowRecZones ) then
			Tooltip:AddLine(" ");
			Tooltip:AddLine((COLOR_GOLD):format(L["Recommended Zones:"]));
			
			for zone in LibTourist:IterateRecommendedZones() do
				AddZone(zone);
			end
		end
		
		if( self.db.ShowRecInstances ) then
			Tooltip:AddLine(" ");
			Tooltip:AddLine((COLOR_GOLD):format(L["Recommended Dungeons:"]));
			
			for zone in LibTourist:IterateRecommendedInstances() do
				AddZone(zone);
			end
		end
	end
end