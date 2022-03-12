-- Pinup by Vger-Azjol-Nerub
-- www.vgermods.com
-- © 2020-2022 Travis Spomer.  This mod is released under the Creative Commons Attribution-NonCommercial-NoDerivs 4.0 license.
-- See Readme.md for more information.

------------------------------------------------------------

Pinup = { Version = 1.0002 }
local _

Pinup.SetPinAtSelf = function()
	local MapID = C_Map.GetBestMapForUnit("player")
	local Pos = C_Map.GetPlayerMapPosition(MapID, "player")
	return Pinup.SetPin(MapID, Pos.x, Pos.y, false)
end

Pinup.SetPin = function(MapID, x, y, Track)
	if not C_Map.CanSetUserWaypointOnMap(MapID) then
		print(MAP_PIN_INVALID_MAP)
		return false
	end

	C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(MapID, x, y))
	print(C_Map.GetUserWaypointHyperlink())
	if Track then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
	return true

	-- GetUserWaypointHyperlink can be bypassed entirely by manually crafting a "worldmap" link, in case you want to support a custom name:
	-- https://wowpedia.fandom.com/wiki/Hyperlinks#worldmap
end

local UpperNamesToMapIDs
local function FindMapByName(MapName)
	-- First, if we haven't already built the list of map names, do that now.
	if UpperNamesToMapIDs == nil then
		local MapID = 1
		local SubsequentInvalidMaps = 0
		UpperNamesToMapIDs = {}
		while SubsequentInvalidMaps < 10 do
			local MapInfo = C_Map.GetMapInfo(MapID)
			if MapInfo then
				local UpperName = strupper(strtrim(MapInfo.name))
				if UpperNamesToMapIDs[UpperName] == nil then
					UpperNamesToMapIDs[UpperName] = MapID
				-- else
					-- There are lots of map duplicates. We skip them, but this code could probably be improved if necessary using other values from GetMapInfo.
					-- print("Duplicate map name:", UpperName, "IDs", MapID, UpperNamesToMapIDs[UpperName])
				end
				SubsequentInvalidMaps = 0
			else
				-- Keep going until we try 10 invalid map IDs in a row: then we know we're probably at the end.
				SubsequentInvalidMaps = SubsequentInvalidMaps + 1
			end
			MapID = MapID + 1
		end
		-- print("Found roughly this many maps:", MapID - 10)
	end

	-- Once we have a table, it's a simple lookup.
	return UpperNamesToMapIDs[strupper(strtrim(MapName))]
end

local function WayCommand(Command)
	local PrintUsage
	if Command == "" then
		PrintUsage = true
	else
		local _
		local MapID
		-- Before doing any other parsing, check to see if they're trying to place a pin on a map by its map ID.
		-- We handle that case first so that it doesn't get confused for an X-coordinate.
		if strsub(Command, 1, 1) == "#" then
			local IDPos, IDLength, IDStr, SpaceStr = strfind(Command, "^#(%d+)(%s+)")
			if IDPos then
				MapID = tonumber(IDStr)
				if MapID then
					Command = strsub(Command, 1 + strlen(IDStr) + strlen(SpaceStr) + 1)
				end
			end
		end

		local Pattern = "([%d.,]+)%s+([%d.,]+)"
		if MapID then
			-- If we already have a map ID from earlier, there can't be another map name specified.
			Pattern = "^" .. Pattern
		end
		local XPos, YEndPos, XStr, YStr = strfind(Command, Pattern)
		XStr = gsub(XStr, ",", ".") -- Don't combine this with tonumber(); gsub has multiple return values
		YStr = gsub(YStr, ",", ".")
		local x = tonumber(XStr)
		local y = tonumber(YStr)
		local MapName
		if XPos > 1 then
			MapName = strtrim(strsub(Command, 1, XPos - 1))
			if strlen(MapName) == 0 then MapName = nil end
		end
		if MapID then
			-- If we already found a map ID earlier, there's nothing to do here.
		elseif MapName then
			-- If they specified a zone name, and it's not the current zone, we need to look it up.
			MapID = C_Map.GetBestMapForUnit("player")
			local MapInfo = C_Map.GetMapInfo(MapID)
			if strupper(MapInfo.name) ~= strupper(MapName) then
				-- This is a different map, so look it up.
				MapID = FindMapByName(MapName)
				if not MapID then
					print("I couldn't find the map named \"" .. MapName .. "\" so I couldn't place a pin there.")
				end
			end
		else
			-- Otherwise, just use the map they're already on.
			MapID = C_Map.GetBestMapForUnit("player")
		end
		if MapID ~= nil and x ~= nil and y ~= nil then
			-- If they specified X and Y, they must be between 0 and 100. (The game APIs use 0-1.)
			if x < 0 or x > 100 or y < 0 or y > 100 then
				print("X and Y coordinates must be between 0 and 100.")
			else
				Pinup.SetPin(MapID, x / 100, y / 100, true)
			end
		else
			PrintUsage = true
		end
	end
	if PrintUsage then print("Usage:\n  /way 24.8 26.2\n  /way Nazmir 42.8 26.2") end
end

local function WayBackCommand(Command)
	if Command == "" then
		Pinup.SetPinAtSelf()
	else
		print("Usage: /wayb")
	end
end

local function PinupInitialize()
	-- Register our slash command. Well, actually, it's TomTom's and Cartographer's slash command, so don't take it over if it's already set.
	if SlashCmdList["WAY"] == nil then
		SLASH_WAY1 = "/way"
		SlashCmdList["WAY"] = WayCommand
		if SlashCmdList["WAYB"] == nil then
			SLASH_WAYB1 = "/wayb"
			SlashCmdList["WAYB"] = WayBackCommand
		end
	else
		print("Pinup didn't take over the /way slash command because something else already did. Looks like you can uninstall Pinup now.")
	end
end

PinupInitialize()
