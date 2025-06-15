--- @classmod Player

impulse.Doors = impulse.Doors or {}
impulse.Doors.Data = impulse.Doors.Data or {}

--- Determines whether the player is allowed to lock or unlock a door.
-- @realm shared
-- @tparam table doorOwners Table of entity indices who own the door
-- @tparam string|number doorGroup Group name or ID the door belongs to
-- @treturn boolean Whether the player can lock or unlock the door
function meta:CanLockUnlockDoor(doorOwners, doorGroup)
	if not doorOwners and not doorGroup then return end

	hook.Run("playerCanUnlockLock", self, doorOwners, doorGroup)

	local teamDoorGroups = self.DoorGroups or {}

	if CLIENT then
		local t = impulse.Teams.Data[LocalPlayer():Team()]
		teamDoorGroups = t.doorGroup

		local class = LocalPlayer():GetTeamClass()
		local rank = LocalPlayer():GetTeamRank()

		if class != 0 and t.classes[class].doorGroup then
			teamDoorGroups = t.classes[class].doorGroup
		end

		if rank != 0 and t.ranks[rank].doorGroup then
			teamDoorGroups = t.ranks[rank].doorGroup
		end
	end

	if doorOwners and table.HasValue(doorOwners, self:EntIndex()) then
		return true
	elseif doorGroup and teamDoorGroups and table.HasValue(teamDoorGroups, doorGroup) then
		return true
	end
end

--- Checks if the player is an owner of the given door.
-- @realm shared
-- @tparam table doorOwners Table of entity indices who own the door
-- @treturn boolean True if the player owns the door
function meta:IsDoorOwner(doorOwners)
	if doorOwners and table.HasValue(doorOwners, self:EntIndex()) then
		return true
	end
	return false
end

--- Checks if the player can buy a door.
-- @realm shared
-- @tparam[opt] table doorOwners Table of existing owners (if any)
-- @tparam[opt] boolean doorBuyable Whether the door is marked as buyable
-- @treturn boolean True if the player can purchase the door
function meta:CanBuyDoor(doorOwners, doorBuyable)
	if doorOwners or doorBuyable == false then
		return false
	end
	return true
end