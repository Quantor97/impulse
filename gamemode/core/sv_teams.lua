--- 
-- @classmod Player

meta.OldSetTeam = meta.OldSetTeam or meta.SetTeam

--- Sets the team of a player, applying models, weapons, inventory and stats.
-- Also triggers `OnPlayerChangedTeam` and `UpdatePlayerSync` hooks.
-- @realm server
-- @int teamID Target team ID (from `impulse.Teams.Data`)
-- @bool[opt=false] forced Whether the change is forced
-- @treturn boolean Always returns true
function meta:SetTeam(teamID, forced)
	local teamData = impulse.Teams.Data[teamID]
	local teamPlayers = team.NumPlayers(teamID)

	if teamData.model then
		self:SetModel(teamData.model)
	else
		self:SetModel(self.defaultModel)
	end

	if teamData.skin then
		self:SetSkin(teamData.skin)
	elseif not teamData.model then
		self:SetSkin(self.defaultSkin)
	end

	if teamData.bodygroups then
		for v, bodygroupData in pairs(teamData.bodygroups) do
			self:SetBodygroup(bodygroupData[1], (bodygroupData[2] or math.random(0, self:GetBodygroupCount(bodygroupData[1]))))
		end
	else
		self:SetBodyGroups("0000000")
	end

	self:ResetSubMaterials()

	if self:IsCP() or teamData.cp then
		self:StripAmmo()
	end
	
	self:UnEquipInventory()
	self:ClearRestrictedInventory()
	self:StripWeapons()
	
	if teamData.loadout then
		for v,weapon in pairs(teamData.loadout) do
			self:Give(weapon)
		end
	end

	if teamData.runSpeed then
		self:SetRunSpeed(teamData.runSpeed)
	else
		self:SetRunSpeed(impulse.Config.JogSpeed)
	end

	self.DoorGroups = teamData.doorGroup or {}

	if self:Team() != teamID then
		hook.Run("OnPlayerChangedTeam", self, self:Team(), teamID)
	end

	self:SetLocalSyncVar(SYNC_CLASS, nil, true)
	self:SetLocalSyncVar(SYNC_RANK, nil, true)
	self:OldSetTeam(teamID)
	self:SetupHands()

	hook.Run("UpdatePlayerSync", self)

	if teamData.onBecome then
		teamData.onBecome(self)
	end

	return true
end

--- Sets the class of the current team, applying overrides to model, skin, loadout and inventory.
-- Also triggers the `PlayerChangeClass` hook.
-- @realm server
-- @int classID Class ID (index in `teamData.classes`)
-- @bool[opt=false] skipLoadout If true, inventory and weapons are not modified
-- @treturn boolean Always returns true
function meta:SetTeamClass(classID, skipLoadout)
	local teamData = impulse.Teams.Data[self:Team()]
	local classData = teamData.classes[classID]
	local classPlayers = 0

	if classData.model then
		self:SetModel(classData.model)
	else
		self:SetModel(teamData.model or self.defaultModel)
	end

	self:SetupHands()

	if classData.skin then
		self:SetSkin(classData.skin)
	else
		self:SetSkin(teamData.skin or self.defaultSkin)
	end

	self:SetBodyGroups("0000000")
	
	if classData.bodygroups then
		for v, bodygroupData in pairs(classData.bodygroups) do
			self:SetBodygroup(bodygroupData[1], (bodygroupData[2] or math.random(0, self:GetBodygroupCount(bodygroupData[1]))))
		end
	elseif teamData.bodygroups then
		for v, bodygroupData in pairs(teamData.bodygroups) do
			self:SetBodygroup(bodygroupData[1], (bodygroupData[2] or math.random(0, self:GetBodygroupCount(bodygroupData[1]))))
		end
	end

	if not skipLoadout then
		self:StripWeapons()

		if classData.loadout then
			for v,weapon in pairs(classData.loadout) do
				self:Give(weapon)
			end
		else
			for v,weapon in pairs(teamData.loadout) do
				self:Give(weapon)
			end

			if classData.loadoutAdd then
				for v,weapon in pairs(classData.loadoutAdd) do
					self:Give(weapon)
				end
			end
		end

		self:ClearRestrictedInventory()

		if classData.items then
			for v,item in pairs(classData.items) do
				for i=1, (item.amount or 1) do
					self:GiveInventoryItem(item.class, 1, true)
				end
			end
		else
			if teamData.items then
				for v,item in pairs(teamData.items) do
					for i=1, (item.amount or 1) do
						self:GiveInventoryItem(item.class, 1, true)
					end
				end
			end

			if classData.itemsAdd then
				for v,item in pairs(classData.itemsAdd) do
					for i=1, (item.amount or 1) do
						self:GiveInventoryItem(item.class, 1, true)
					end
				end
			end
		end
	end

	if classData.armour then
		self:SetArmor(classData.armour)
		self.MaxArmour = classData.armour
	else
		self:SetArmor(0)
		self.MaxArmour = nil
	end

	if classData.doorGroup then
		self.DoorGroups = classData.doorGroup
	else
		self.DoorGroups = teamData.doorGroup or {}
	end

	if classData.onBecome then
		classData.onBecome(self)
	end

	self:SetLocalSyncVar(SYNC_CLASS, classID, true)

	hook.Run("PlayerChangeClass", self, classID, classData.name)

	return true
end

--- Sets the rank of the current team/class, applying overrides to model, skin, submaterials and inventory.
-- Also triggers the `PlayerChangeRank` hook.
-- @realm server
-- @int rankID Rank ID (index in `teamData.ranks`)
-- @treturn boolean Always returns true
function meta:SetTeamRank(rankID)
	local teamData = impulse.Teams.Data[self:Team()]
	local classData = teamData.classes[self:GetTeamClass()]
	local rankData = teamData.ranks[rankID]

	if rankData.model then
		self:SetModel(rankData.model)
	else
		if classData.model and self:GetModel() != classData.model then
			self:SetModel(classData.model)
		end
	end

	self:SetupHands()

	if rankData.skin then
		self:SetSkin(rankData.skin)
	end

	if rankData.bodygroups then
		for v, bodygroupData in pairs(rankData.bodygroups) do
			self:SetBodygroup(bodygroupData[1], (bodygroupData[2] or math.random(0, self:GetBodygroupCount(bodygroupData[1]))))
		end
	elseif teamData.bodygroups then
		for v, bodygroupData in pairs(teamData.bodygroups) do
			self:SetBodygroup(bodygroupData[1], (bodygroupData[2] or math.random(0, self:GetBodygroupCount(bodygroupData[1]))))
		end
	else
		self:SetBodyGroups("0000000")
	end

	if rankData.subMaterial and not classData.noSubMats then
		for v,k in pairs(rankData.subMaterial) do
			self:SetSubMaterial(v - 1, k)

			self.SetSubMats = self.SetSubMats or {}
			self.SetSubMats[v] = true
		end
	elseif self.SetSubMats then
		self:ResetSubMaterials()
	end

	self:StripWeapons()

	if rankData.loadout then
		for v,weapon in pairs(rankData.loadout) do
			self:Give(weapon)
		end
	else
		for v,weapon in pairs(teamData.loadout) do
			self:Give(weapon)
		end

		if classData and classData.loadoutAdd then
			for v,weapon in pairs(classData.loadoutAdd) do
				self:Give(weapon)
			end
		end

		if rankData.loadoutAdd then
			for v,weapon in pairs(rankData.loadoutAdd) do
				self:Give(weapon)
			end
		end
	end

	self:ClearRestrictedInventory()

	if rankData.items then
		for v,item in pairs(rankData.items) do
			for i=1, (item.amount or 1) do
				self:GiveInventoryItem(item.class, 1, true)
			end
		end
	else
		if teamData.items then
			for v,item in pairs(teamData.items) do
				for i=1, (item.amount or 1) do
					self:GiveInventoryItem(item.class, 1, true)
				end
			end
		end

		if classData.itemsAdd then
			for v,item in pairs(classData.itemsAdd) do
				for i=1, (item.amount or 1) do
					self:GiveInventoryItem(item.class, 1, true)
				end
			end
		end

		if rankData.itemsAdd then
			for v,item in pairs(rankData.itemsAdd) do
				for i=1, (item.amount or 1) do
					self:GiveInventoryItem(item.class, 1, true)
				end
			end
		end
	end

	if rankData.doorGroup then
		self.DoorGroups = rankData.doorGroup
	else
		if classData.doorGroup then
			self.DoorGroups = classData.doorGroup
		else
			self.DoorGroups = teamData.doorGroup or {}
		end
	end

	if rankData.onBecome then
		rankData.onBecome(self)
	end

	self:SetLocalSyncVar(SYNC_RANK, rankID, true)

	hook.Run("PlayerChangeRank", self, rankID, rankData.name)

	return true
end

--- Checks if a player has a whitelist for a specific team.
-- Optionally compares if they meet or exceed a specific level.
-- @realm server
-- @string team Team name or ID
-- @int[opt] level Minimum level
-- @treturn boolean True if whitelist exists and level is met (if given)
function meta:HasTeamWhitelist(team, level)
	if not self.Whitelists then
		return false
	end

	local whitelist = self.Whitelists[team]

	if whitelist then
		if level then
			return whitelist >= level
		else
			return true
		end
	end

	return false
end

--- Loads whitelist information from the database for this player.
-- Populates `self.Whitelists`.
-- @realm server
function meta:SetupWhitelists()
	self.Whitelists = {}

	impulse.Teams.GetAllWhitelistsPlayer(self:SteamID(), function(result)
		if not result or not IsValid(self) then
			return
		end

		for v,k in pairs(result) do
			local teamName = k.team
			local level = k.level
			local realTeam = impulse.Teams.NameRef[teamName]

			--if not realTeam then -- team does not exist
			--	continue
			--end

			self.Whitelists[realTeam or k.team] = level
		end
	end)
end

--- Provides whitelist storage and query functions for team access control. 
-- @module impulse.Teams

--- Initializes a default whitelist entry for the given SteamID.
-- Currently unused / placeholder.
-- @realm server
-- @string steamid Player's SteamID
function impulse.Teams.WhitelistSetup(steamid)
	local query = mysql:Insert("impulse_whitelists")
	query:Insert("steamid")
end

--- Sets or updates the whitelist level for a player on a specific team.
-- @realm server
-- @string steamid Player's SteamID
-- @string team Team name
-- @int level Whitelist access level
function impulse.Teams.SetWhitelist(steamid, team, level)
	local inTable = impulse.Teams.GetWhitelist(steamid, team, function(exists)
		if exists then
			local query = mysql:Update("impulse_whitelists")
			query:Update("level", level)
			query:Where("team", team)
			query:Where("steamid", steamid)
			query:Execute()	
		else
			local query = mysql:Insert("impulse_whitelists")
			query:Insert("level", level)
			query:Insert("team", team)
			query:Insert("steamid", steamid)
			query:Execute()	
		end
	end)
end

--- Retrieves all whitelisted SteamIDs and their levels for a specific team.
-- @realm server
-- @string team Team name
-- @tparam function callback Function called with table of results
function impulse.Teams.GetAllWhitelists(team, callback)
	local query = mysql:Select("impulse_whitelists")
	query:Select("level")
	query:Select("steamid")
	query:Where("team", team)
	query:Callback(function(result)
		if type(result) == "table" and #result > 0 and callback then -- if player exists in db
			callback(result)
		end
	end)
	query:Execute()
end

--- Retrieves all team whitelists for a specific player.
-- @realm server
-- @string steamid Player's SteamID
-- @tparam function callback Function called with table of results
function impulse.Teams.GetAllWhitelistsPlayer(steamid, callback)
	local query = mysql:Select("impulse_whitelists")
	query:Select("level")
	query:Select("team")
	query:Where("steamid", steamid)
	query:Callback(function(result)
		if (type(result) == "table" and #result > 0) and callback then -- if player exists in db
			callback(result)
		end
	end)
	query:Execute()
end

function impulse.Teams.GetWhitelist(steamid, team, callback)
	local query = mysql:Select("impulse_whitelists")
	query:Select("level")
	query:Where("team", team)
	query:Where("steamid", steamid)
	query:Callback(function(result)
		if type(result) == "table" and #result > 0 and callback then -- if player exists in db
			callback(result[1].level)
		else
			callback()
		end
	end)
	query:Execute()
end

