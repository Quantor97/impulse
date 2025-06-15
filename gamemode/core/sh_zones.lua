--- @classmod Player

--- Returns the current zone ID of the player
-- @return number Zone ID or nil if unset
-- @realm shared
function meta:GetZone()
	return self.impulseZone
end

--- Returns the display name of the player's current zone
-- @return string Zone name or empty string if none assigned
-- @realm shared
function meta:GetZoneName()
	if self.impulseZone then
		return impulse.Config.Zones[self.impulseZone].name
	else
		return ""
	end
end

--- Sets the current zone of the player
-- @param id Zone ID to assign
-- @realm server
function meta:SetZone(id)
	if (self.impulseZone or -1) == id then return end
	self.impulseZone = id

	net.Start("impulseZoneUpdate")
	net.WriteUInt(id, 8)
	net.Send(self)

	hook.Run("PlayerZoneChanged", self, id)
end