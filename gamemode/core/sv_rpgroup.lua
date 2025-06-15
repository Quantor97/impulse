--- Provides persistent group and rank system, including database logic, rank syncing and player group metadata
-- @module impulse.Group

local DEFAULT_RANKS = pon.encode({
	["Owner"] = {
		[1] = true,
		[2] = true,
		[3] = true,
		[4] = true,
		[5] = true,
		[6] = true,
		[8] = true,
		[99] = true
	},
	["Member"] = {
		[0] = true,
		[1] = true,
		[2] = true
	}
})

--- Creates a new persistent group and stores it in the database
-- @realm server
-- @string name The group name
-- @string ownerid The SteamID of the group's owner
-- @int maxsize Maximum number of members
-- @int maxstorage Maximum storage capacity
-- @tparam[opt] table ranks Custom rank structure (uses default if nil)
-- @tparam[opt] function callback Called with group ID on success, or nil if name is not unique
function impulse.Group.DBCreate(name, ownerid, maxsize, maxstorage, ranks, callback)
	impulse.Group.IsNameUnique(name, function(unique)
		if unique then
			local query = mysql:Insert("impulse_rpgroups")
			query:Insert("ownerid", ownerid)
			query:Insert("name", name)
			query:Insert("maxsize", maxsize)
			query:Insert("maxstorage", maxstorage)
			query:Insert("ranks", ranks and pon.encode(ranks) or DEFAULT_RANKS)
			query:Callback(function(result, status, id)
				if callback then
					callback(id)
				end
			end)

			query:Execute()
		else
			callback()
		end
	end)
end

--- Removes a group from the database by its ID
-- @realm server
-- @int groupid The internal database ID of the group
function impulse.Group.DBRemove(groupid)
	local query = mysql:Delete("impulse_rpgroups")
	query:Where("id", groupid)
	query:Execute()
end

--- Removes a group from the database by its name
-- @realm server
-- @string name Group name
function impulse.Group.DBRemoveByName(name)
	local query = mysql:Delete("impulse_rpgroups")
	query:Where("name", name)
	query:Execute()
end

--- Adds a player to a group in the database
-- @realm server
-- @string steamid The player's SteamID
-- @int groupid The internal ID of the group
-- @string rank The rank to assign (defaults to group's default rank)
-- @tparam[opt] function callback Optional callback once database operation completes
function impulse.Group.DBAddPlayer(steamid, groupid, rank, callback)
	local query = mysql:Update("impulse_players")
	query:Update("rpgroup", groupid)
	query:Update("rpgrouprank", rank or impulse.Group.GetDefaultRank(name))
	query:Where("steamid", steamid)
	query:Callback(function()
		if callback then
			callback()
		end
	end)
	query:Execute()
end

--- Removes a player from their group in the database
-- @realm server
-- @string steamid The player's SteamID
-- @int groupid Unused, kept for legacy compatibility
function impulse.Group.DBRemovePlayer(steamid, groupid)
	local query = mysql:Update("impulse_players")
	query:Update("rpgroup", nil)
	query:Update("rpgrouprank", "")
	query:Where("steamid", steamid)
	query:Execute()
end

--- Removes all players from the specified group
-- @realm server
-- @int groupid The group ID
function impulse.Group.DBRemovePlayerMass(groupid)
	local query = mysql:Update("impulse_players")
	query:Update("rpgroup", nil)
	query:Update("rpgrouprank", "")
	query:Where("rpgroup", groupid)
	query:Execute()
end

--- Updates a player's group rank in the database
-- @realm server
-- @string steamid The player's SteamID
-- @string rank The new rank
function impulse.Group.DBUpdatePlayerRank(steamid, rank)
	local query = mysql:Update("impulse_players")
	query:Update("rpgrouprank", rank)
	query:Where("steamid", steamid)
	query:Execute()
end

--- Shifts all players from one rank to another in a group
-- @realm server
-- @int groupid The group ID
-- @string rank The old rank name
-- @string newrank The new rank name
function impulse.Group.DBPlayerRankShift(groupid, rank, newrank)
	local query = mysql:Update("impulse_players")
	query:Update("rpgrouprank", newrank)
	query:Where("rpgroup", groupid)
	query:Where("rpgrouprank", rank)
	query:Execute()
end

--- Updates the rank structure of a group in the database
-- @realm server
-- @int groupid The group ID
-- @tparam table ranks A table of ranks to store (will be PON encoded)
function impulse.Group.DBUpdateRanks(groupid, ranks)
	local query = mysql:Update("impulse_rpgroups")
	query:Update("ranks", pon.encode(ranks))
	query:Where("id", groupid)
	query:Execute()
end

--- Updates the group's maximum member limit
-- @realm server
-- @int groupid The group ID
-- @int max Maximum number of members
function impulse.Group.DBUpdateMaxMembers(groupid, max)
	local query = mysql:Update("impulse_rpgroups")
	query:Update("maxsize", max)
	query:Where("id", groupid)
	query:Execute()
end

--- Updates additional group metadata (e.g. description, color)
-- @realm server
-- @int groupid The group ID
-- @tparam table data A table with group metadata (will be PON encoded)
function impulse.Group.DBUpdateData(groupid, data)
	local query = mysql:Update("impulse_rpgroups")
	query:Update("data", pon.encode(data))
	query:Where("id", groupid)
	query:Execute()
end

--- Refreshes the in-memory member list of a group from the database
-- @realm server
-- @string name Group name
-- @tparam[opt] function callback Callback when done
function impulse.Group.ComputeMembers(name, callback)
	local id = impulse.Group.Groups[name].ID

	local query = mysql:Select("impulse_players")
	query:Select("steamid")
	query:Select("rpname")
	query:Select("rpgroup")
	query:Select("rpgrouprank")
	query:Where("rpgroup", id)
	query:Callback(function(result)
		local members = {}
		local membercount = 0

		if type(result) == "table" and #result > 0 then
			for v,k in pairs(result) do
				membercount = membercount + 1
				members[k.steamid] = {Name = k.rpname, Rank = k.rpgrouprank or impulse.Group.GetDefaultRank(name)}
			end
		end

		impulse.Group.Groups[name].Members = members
		impulse.Group.Groups[name].MemberCount = membercount

		if callback then
			callback()
		end
	end)

	query:Execute()
end

--- Changes the name of a group rank across all members
-- @realm server
-- @string name Group name
-- @string from The old rank name
-- @string to The new rank name
function impulse.Group.RankShift(name, from, to)
	local group = impulse.Group.Groups[name]

	impulse.Group.DBPlayerRankShift(group.ID, from, to)

	for v,k in pairs(group.Members) do
		if k.Rank == from then
			local ply = player.GetBySteamID(v)

			impulse.Group.Groups[name].Members[v].Rank = to

			if IsValid(ply) then
				ply:GroupAdd(name, to, true)
			else
				impulse.Group.NetworkMemberToOnline(name, v)
			end
		end
	end

	impulse.Group.NetworkRankToOnline(name, to)
end

--- Returns the default rank of a group
-- Looks for the first rank that has permission level 0.
-- @realm server
-- @string name Group name
-- @treturn string Default rank name (defaults to "Member" if none match)
function impulse.Group.GetDefaultRank(name)
	local data = impulse.Group.Groups[name]

	for v,k in pairs(data.Ranks) do
		if k[0] then
			return v
		end
	end

	return "Member"
end

--- Sets the metadata for a group (info string and color)
-- @realm server
-- @string name Group name
-- @string info Group description
-- @tparam[opt] Color col Group color (optional)
function impulse.Group.SetMetaData(name, info, col)
	local grp = impulse.Group.Groups[name]
	local id = grp.ID
	local data = grp.Data or {}

	data.Info = info or grp.Data.Info
	data.Col = col or (grp.Data.Col and Color(grp.Data.Col.r, grp.Data.Col.g, grp.Data.Col.b)) or nil

	impulse.Group.Groups[name].Data = data
	impulse.Group.DBUpdateData(id, data)
end

--- Sends group metadata (info + color) to a specific player
-- @realm server
-- @player to Target player
-- @string name Group name
function impulse.Group.NetworkMetaData(to, name)
	local grp = impulse.Group.Groups[name]

	net.Start("impulseGroupMetadata")
	net.WriteString(grp.Data.Info or "")

	if grp.Data.Col then
		net.WriteColor(Color(grp.Data.Col.r, grp.Data.Col.g, grp.Data.Col.b))
	else
		net.WriteColor(Color(0, 0, 0))
	end

	net.Send(to)
end

--- Sends group metadata (info + color) to all online players in the group
-- @realm server
-- @string name Group name
function impulse.Group.NetworkMetaDataToOnline(name)
	local grp = impulse.Group.Groups[name]

	local rf = RecipientFilter()

	for v,k in pairs(player.GetAll()) do
		local x = k:GetSyncVar(SYNC_GROUP_NAME, nil)

		if x and x == name then
			rf:AddPlayer(k)
		end
	end

	net.Start("impulseGroupMetadata")
	net.WriteString(grp.Data.Info or "")
	net.WriteColor(grp.Data.Col or Color(0, 0, 0))
	net.Send(rf)
end

--- Sends a single member's data to one player
-- @realm server
-- @player to Target player
-- @string name Group name
-- @string sid SteamID of the member
function impulse.Group.NetworkMember(to, name, sid)
	local member = impulse.Group.Groups[name].Members[sid]

	net.Start("impulseGroupMember")
	net.WriteString(sid)
	net.WriteString(member.Name)
	net.WriteString(member.Rank)
	net.Send(to)
end

--- Broadcasts group metadata to all members of the group
-- @realm server
-- @string name Group name
-- @string sid SteamID of the member
function impulse.Group.NetworkMemberToOnline(name, sid)
	local member = impulse.Group.Groups[name].Members[sid]

	local rf = RecipientFilter()

	for v,k in pairs(player.GetAll()) do
		local x = k:GetSyncVar(SYNC_GROUP_NAME, nil)

		if x and x == name then
			rf:AddPlayer(k)
		end
	end

	net.Start("impulseGroupMember")
	net.WriteString(sid)
	net.WriteString(member.Name)
	net.WriteString(member.Rank)
	net.Send(rf)
end

--- Broadcasts a member removal to all online group members
-- @realm server
-- @string name Group name
-- @string sid SteamID of removed member
function impulse.Group.NetworkMemberRemoveToOnline(name, sid)
	local rf = RecipientFilter()

	for v,k in pairs(player.GetAll()) do
		local x = k:GetSyncVar(SYNC_GROUP_NAME, nil)

		if x and x == name then
			rf:AddPlayer(k)
		end
	end

	net.Start("impulseGroupMemberRemove")
	net.WriteString(sid)
	net.Send(rf)
end

--- Sends all group members to the given player
-- @realm server
-- @player to Target player
-- @string name Group name
function impulse.Group.NetworkAllMembers(to, name)
	local members = impulse.Group.Groups[name].Members

	for v,k in pairs(members) do
		impulse.Group.NetworkMember(to, name, v)
	end
end

--- Sends all group ranks to players with rank management permissions
-- @realm server
-- @string name Group name
function impulse.Group.NetworkRanksToOnline(name)
	local ranks = impulse.Group.Groups[name].Ranks
	local data = pon.encode(ranks)
	local rf = RecipientFilter()

	for v,k in pairs(player.GetAll()) do
		local x = k:GetSyncVar(SYNC_GROUP_NAME, nil)

		if x and x == name then
			if k:GroupHasPermission(5) or k:GroupHasPermission(6) then
				rf:AddPlayer(k)
			end
		end
	end

	net.Start("impulseGroupRanks")
	net.WriteUInt(#data, 32)
	net.WriteData(data, #data)
	net.Send(rf)
end

--- Sends a single rank structure to a player
-- @realm server
-- @string name Group name
-- @player to Target player
-- @string rankName Name of the rank
function impulse.Group.NetworkRank(name, to, rankName)
	local rank = impulse.Group.Groups[name].Ranks[rankName]
	local data = pon.encode(rank)

	net.Start("impulseGroupRank")
	net.WriteString(rankName)
	net.WriteUInt(#data, 32)
	net.WriteData(data, #data)
	net.Send(to)
end

--- Sends a single rank to all matching online group members
-- @realm server
-- @string name Group name
-- @string rankName Rank name
function impulse.Group.NetworkRankToOnline(name, rankName)
	local rank = impulse.Group.Groups[name].Ranks[rankName]
	local data = pon.encode(rank)
	local rf = RecipientFilter()

	for v,k in pairs(player.GetAll()) do
		local x = k:GetSyncVar(SYNC_GROUP_NAME, nil)
		local r = k:GetSyncVar(SYNC_GROUP_RANK, nil)

		if x and x == name and r == rank then
			if k:GroupHasPermission(5) or k:GroupHasPermission(6) then
				continue
			end

			rf:AddPlayer(k)
		end
	end

	net.Start("impulseGroupRank")
	net.WriteString(rankName)
	net.WriteUInt(#data, 32)
	net.WriteData(data, #data)
	net.Send(rf)
end

--- Sends full rank table to a player
-- @realm server
-- @player to Target player
-- @string name Group name
function impulse.Group.NetworkRanks(to, name)
	local ranks = impulse.Group.Groups[name].Ranks
	local data = pon.encode(ranks)

	net.Start("impulseGroupRanks")
	net.WriteUInt(#data, 32)
	net.WriteData(data, #data)
	net.Send(to)
end

--- Checks if a group name is already used
-- @realm server
-- @string name Group name to check
-- @tparam function callback Function called with boolean result (true if unique)
function impulse.Group.IsNameUnique(name, callback)
	local query = mysql:Select("impulse_rpgroups")
	query:Select("name")
	query:Where("name", name)
	query:Callback(function(result)
		if type(result) == "table" and #result > 0 then
			return callback(false)
		else
			return callback(true)
		end
	end)

	query:Execute()
end

--- Loads group data from the database and caches it
-- Calls the provided callback with the group name once loaded.
-- @realm server
-- @int id Group ID
-- @tparam function onLoaded Callback receiving the group name
function impulse.Group.Load(id, onLoaded)
	local query = mysql:Select("impulse_rpgroups")
	query:Select("ownerid")
	query:Select("name")
	query:Select("type")
	query:Select("maxsize")
	query:Select("maxstorage")
	query:Select("ranks")
	query:Select("data")
	query:Where("id", id)
	query:Callback(function(result)
		if type(result) == "table" and #result > 0 then
			local data = result[1]

			if impulse.Group.Groups[data.name] then
				return onLoaded(data.name)
			end

			impulse.Group.Groups[data.name] = {
				ID = id,
				OwnerID = data.ownerid,
				Type = data.type,
				MaxSize = data.maxsize,
				MaxStorage = data.maxstorage,
				Ranks = pon.decode(data.ranks),
				Data = (data.data and pon.decode(data.data) or {})
			}

			if onLoaded then
				onLoaded(data.name)
			end
		end
	end)

	query:Execute()
end

local function postCompute(self, name, rank, skipDb)
	if not IsValid(self) then
		return
	end

	impulse.Group.NetworkMemberToOnline(name, self:SteamID())

	self:SetSyncVar(SYNC_GROUP_NAME, name, true)
	self:SetSyncVar(SYNC_GROUP_RANK, rank, true)

	if not skipDb then
		impulse.Group.NetworkAllMembers(self, name)
	end

	if self:GroupHasPermission(5) or self:GroupHasPermission(6) then
		impulse.Group.NetworkRanks(self, name)
	else
		impulse.Group.NetworkRank(name, self, rank)
	end

	impulse.Group.NetworkMetaData(self, name)
end

--- @classmod Player

--- Adds the player to a group and synchronizes metadata
-- @realm server
-- @string name Group name
-- @string[opt] rank Rank name to assign (defaults to default rank)
-- @bool[opt] skipDb Whether to skip saving to the database
function meta:GroupAdd(name, rank, skipDb)
	local id = impulse.Group.Groups[name].ID
	local rank = rank or impulse.Group.GetDefaultRank(name)

	if not skipDb then
		impulse.Group.DBAddPlayer(self:SteamID(), id, rank)
	end

	impulse.Group.ComputeMembers(name, function()
		postCompute(self, name, rank, skipDb)
	end)
end

--- Removes the player from the specified group
-- @realm server
-- @string name Group name
function meta:GroupRemove(name)
	local id = impulse.Group.Groups[name].ID
	local sid = self:SteamID()

	impulse.Group.DBRemovePlayer(sid)
	impulse.Group.ComputeMembers(name)
	impulse.Group.NetworkMemberRemoveToOnline(name, sid)

	self:SetSyncVar(SYNC_GROUP_NAME, nil, true)
	self:SetSyncVar(SYNC_GROUP_RANK, nil, true)
end

--- applies the specified rank
-- @realm server
-- @int groupid The group ID
-- @string[opt] rank The rank name to assign (default if invalid)
function meta:GroupLoad(groupid, rank)
	impulse.Group.Load(groupid, function(name)
		if not IsValid(self) then
			return
		end

		impulse.Group.ComputeMembers(name, function()
			if not IsValid(self) then
				return
			end

			impulse.Group.NetworkAllMembers(self, name)

			if self:GroupHasPermission(5) or self:GroupHasPermission(6) then
				impulse.Group.NetworkRanks(self, name)
			end

			impulse.Group.NetworkMetaData(self, name)
		end)

		if rank then
			if not impulse.Group.Groups[name].Ranks[rank] then
				rank = impulse.Group.GetDefaultRank(name)
				impulse.Group.DBUpdatePlayerRank(self:SteamID(), rank)
			end
		end

		rank = rank or impulse.Group.GetDefaultRank(name)

		self:SetSyncVar(SYNC_GROUP_NAME, name, true)
		self:SetSyncVar(SYNC_GROUP_RANK, rank, true)

		impulse.Group.NetworkRank(name, self, rank)

		if self:IsDonator() and self:GroupHasPermission(99) and impulse.Group.Groups[name].MaxSize < impulse.Config.GroupMaxMembersVIP then
			impulse.Group.DBUpdateMaxMembers(groupid, impulse.Config.GroupMaxMembersVIP)
			impulse.Group.Groups[name].MaxSize = impulse.Config.GroupMaxMembersVIP
		end
	end)
end
