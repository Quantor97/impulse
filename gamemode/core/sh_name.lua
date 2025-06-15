--- @classmod Player

if SERVER then
	--- Sets the player's RP name and optionally saves it to the database.
	-- @realm server
	-- @string name The RP name to assign
	-- @bool[opt=false] save Whether the name should be saved persistently
	function meta:SetRPName(name, save)
		if save then
			local query = mysql:Update("impulse_players")
			query:Update("rpname", name)
			query:Where("steamid", self:SteamID())
			query:Execute(true)

			self.defaultRPName = name
		end

		hook.Run("PlayerRPNameChanged", self, self:Name(), name)

		self:SetSyncVar(SYNC_RPNAME, name, true)
	end

	--- Returns the player's saved RP name (only available server-side).
	-- @realm server
	-- @treturn string The saved RP name
	function meta:GetSavedRPName()
		return self.defaultRPName
	end
end

local blacklistNames = {
	["ooc"] = true,
	["shared"] = true,
	["world"] = true,
	["world prop"] = true,
	["blocked"] = true,
	["admin"] = true,
	["server admin"] = true,
	["mod"] = true,
	["game moderator"] = true,
	["adolf hitler"] = true,
	["masked person"] = true,
	["masked player"] = true,
	["unknown"] = true,
	["nigger"] = true,
	["tyrone jenson"] = true
}

meta.steamName = meta.steamName or meta.Name

--- Returns the player's Steam name (not the RP name).
-- @realm shared
-- @treturn string Steam name
function meta:SteamName()
	return self.steamName(self)
end

--- Returns the player's active display name (RP name or fallback).
-- This is the main method for accessing the player's in-game name.
-- @realm shared
-- @treturn string RP name or Steam name
function meta:Name()
    return self:GetSyncVar(SYNC_RPNAME, self:SteamName())
end

--- Returns the name the player is known by, which may be overridden by a hook.
-- Falls back to RP name or Steam name.
-- @realm shared
-- @treturn string Known name
function meta:KnownName()
	local custom = hook.Run("PlayerGetKnownName", self)
	return custom or self:GetSyncVar(SYNC_RPNAME, self:SteamName())
end

meta.GetName = meta.Name
meta.Nick = meta.Name

--- @module impulse

--- Returns whether the given RP name is valid and can be used.
-- Checks for length, characters, blacklisted terms, and numerics.
-- @realm shared
-- @string name The RP name to validate
-- @treturn bool success Whether the name is valid
-- @treturn string|nil reasonOrName If invalid, a string describing the reason; otherwise the cleaned name
function impulse.CanUseName(name)
	if name:len() >= 24 then
		return false, "Name too long. (max. 24)" 
	end

	name = name:Trim()
	name = impulse.SafeString(name)

	if name:len() <= 6 then
		return false, "Name too short. (min. 6)"
	end

	if name == "" then
		return false, "No name was provided."
	end


	local numFound = string.match(name, "%d") -- no numerics

	if numFound then
		return false, "Name contains numbers."
	end
	
	if blacklistNames[name:lower()] then
		return false, "Blacklisted/reserved name."	
	end

	return true, name
end