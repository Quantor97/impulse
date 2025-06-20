---
-- @module impulse.Teams

impulse.Teams = impulse.Teams or {}
impulse.Teams.Data = impulse.Teams.Data or {}
impulse.Teams.ClassRef = impulse.Teams.ClassRef or {}
impulse.Teams.NameRef = impulse.Teams.NameRef or {}
teamID = 0

CLASS_EMPTY = 0

--- Defines a new team
-- @param teamData Table containing team configuration
-- @return number The assigned team ID
-- @realm shared
function impulse.Teams.Define(teamData)
    teamID = teamID + 1
    impulse.Teams.Data[teamID] = teamData
    impulse.Teams.NameRef[teamData.name] = teamID

    if teamData.classes then
    	impulse.Teams.Data[teamID].ClassRef = {}

    	for id,k in pairs(teamData.classes) do
    		impulse.Teams.Data[teamID].ClassRef[id] = k.name
    	end
    end

    if teamData.ranks then
    	impulse.Teams.Data[teamID].RankRef = {}

    	for id,k in pairs(teamData.ranks) do
    		impulse.Teams.Data[teamID].RankRef[id] = k.name
    	end
    end

    team.SetUp(teamID, teamData.name, teamData.color, false)
    return teamID
end

--- @classmod Player

--- Checks if the player is allowed to join a team
-- @param teamID The team ID to join
-- @bool[opt] notify Whether to notify the player with a message
-- @return boolean True if the player can become this team
-- @realm shared
function meta:CanBecomeTeam(teamID, notify)
	local teamData = impulse.Teams.Data[teamID]
	local teamPlayers = team.NumPlayers(teamID)

	if not self:Alive() then return false end

	if self:GetSyncVar(SYNC_ARRESTED, false) then
		return false
	end

	if teamID == self:Team() then
		return false
	end

	if teamData.donatorOnly and not self:IsDonator() then
		return false
	end

	local canSwitch = hook.Run("CanPlayerChangeTeam", self, teamID)

	if canSwitch != nil and canSwitch == false then
		return false
	end

	if teamData.xp and teamData.xp > self:GetXP() then
		if notify then self:Notify("You don't have the XP required to play as this team.") end
		return false
	end

	if SERVER and teamData.cp then
		if self:HasIllegalInventoryItem() then
			if notify then self:Notify("You cannot become this team with illegal items in your inventory.") end
			return false
		end
	end

	if teamData.limit then
		if teamData.percentLimit and teamData.percentLimit == true then
			local percentTeam = teamPlayers / #player.GetAll()

			if not self:IsDonator() and percentTeam > teamData.limit then
				if notify then self:Notify(teamData.name .. " is full.") end
				return false
			end
		else
			if not self:IsDonator() and teamPlayers >= teamData.limit then
				if notify then self:Notify(teamData.name .. " is full.") end
				return false
			end
		end
	end

	if teamData.customCheck then
		local r = teamData.customCheck(self, teamID)

		if r != nil and r == false then
			return false
		end
	end

	return true
end

--- Checks if the player is allowed to become a team class
-- @realm shared
-- @string classID The class ID to check
-- @bool[opt] notify Whether to notify the player with a message
-- @return boolean True if the player can become this class
function meta:CanBecomeTeamClass(classID, notify)
	local teamData = impulse.Teams.Data[self:Team()]
	local classData = teamData.classes[classID]
	local classPlayers = 0

	if not self:Alive() then return false end

	if self:GetTeamClass() == classID then return false end

	if classData.whitelistLevel and classData.whitelistUID and not self:HasTeamWhitelist(classData.whitelistUID, classData.whitelistLevel) then
		local add = classData.whitelistFailMessage or ""
		if notify then self:Notify("You must be whitelisted to play as this rank. "..add) end
		return false
	end

	if classData.xp and classData.xp > self:GetXP() then
		if notify then self:Notify("You don't have the XP required to play as this class.") end
		return false
	end

	if classData.limit then
		local classPlayers = 0

		for v,k in pairs(team.GetPlayers(self:Team())) do
			if k:GetTeamClass() == classID then
				classPlayers = classPlayers + 1
			end
		end

		if classData.percentLimit and classData.percentLimit == true then
			local percentClass = classPlayers / #player.GetAll()
			if percentClass > classData.limit then
				if notify then self:Notify(classData.name .. " is full.") end
				return false
			end
		else
			if classPlayers >= classData.limit then
				if notify then self:Notify(classData.name .. " is full.") end
				return false
			end
		end
	end

	if classData.customCheck then
		local r = classData.customCheck(self, classID)

		if r != nil and r == false then
			return false
		end
	end

	return true
end

--- Checks if player can become team rank
-- @realm shared
-- @string rankID The rank ID to check
-- @bool[opt] notify Whether to notify the player with a message
-- @return boolean True if the player can become this rank
function meta:CanBecomeTeamRank(rankID, notify)
	local teamData = impulse.Teams.Data[self:Team()]
	local rankData = teamData.ranks[rankID]
	local rankPlayers = 0

	if not self:Alive() then return false end

	if rankData.whitelistLevel and not self:HasTeamWhitelist(self:Team(), rankData.whitelistLevel) then
		local add = rankData.whitelistFailMessage or ""
		if notify then self:Notify("You must be whitelisted to play as this rank. "..add) end
		return false
	end
		
	if rankData.xp and rankData.xp > self:GetXP() and forced == false then
		if notify then self:Notify("You don't have the XP required to play as this rank.") end
		return false
	end

	if rankData.limit then
		local rankPlayers = 0 

		for v,k in pairs(team.GetPlayers(self:Team())) do
			if k:GetTeamRank() == rankID then
				rankPlayers = rankPlayers + 1
			end
		end

		if rankData.percentLimit and rankData.percentLimit == true then
			local percentRank = rankPlayers / #player.GetAll()

			if percentRank > rankData.limit then
				if notify then self:Notify(rankData.name .. " is full.") end
				return false
			end
		else
			if rankPlayers >= rankData.limit then
				if notify then self:Notify(rankData.name .. " is full.") end
				return false
			end
		end
	end

	if rankData.customCheck then
		local r = rankData.customCheck(self, rankID)

		if r != nil and r == false then
			return false
		end
	end

	return true
end

--- Gets the class name the player currently belongs to
-- @return string Class ID (Default: "Default")
-- @realm shared
function meta:GetTeamClassName()
	if not impulse.Teams.Data[self:Team()] then return "" end

	local classRef = impulse.Teams.Data[self:Team()].ClassRef
	local plyClass = self:GetSyncVar(SYNC_CLASS, nil)

	if classRef and plyClass then
		return classRef[plyClass]
	end

	return "Default"
end

--- Gets the display name of the player's current team rank
-- @return string Team rank name or "Default" if unavailable
-- @realm shared
function meta:GetTeamClass()
	return self:GetSyncVar(SYNC_CLASS, 0)
end

--- Gets the rank name the player currently belongs to
-- @return string Rank name (Default: "default")
-- @realm shared
function meta:GetTeamRankName()
	local rankData = impulse.Teams.Data[self:Team()].ranks
	local plyRank = self:GetSyncVar(SYNC_RANK, nil)

	if rankData and plyRank then
		return rankData[plyRank].name
	end

	return "Default"
end

--- Gets the rank ID the player currently belongs to
-- @return number Rank ID (default 0)
-- @realm shared
function meta:GetTeamRank()
	return self:GetSyncVar(SYNC_RANK, 0)
end

--- Checks whether the player's team is considered civil protection (CP)
-- @return boolean True if the team is CP, false otherwise
-- @realm shared
function meta:IsCP()
	local teamData = impulse.Teams.Data[self:Team()]

	if teamData then
		return teamData.cp or false
	end
end