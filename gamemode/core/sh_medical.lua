--- @classmod Player

--- Returns whether the player has broken legs.
-- @treturn boolean Whether the player currently has broken legs
-- @realm shared
function meta:HasBrokenLegs()
	return self:GetSyncVar(SYNC_BROKENLEGS, false)
end