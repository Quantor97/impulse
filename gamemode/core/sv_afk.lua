--- 
-- @classmod Player

--- Marks the player as AFK and optionally kicks or demotes them based on server conditions
-- @realm server
function meta:MakeAFK()
	if self.AFKImmune then
		return
	end
	
	self.AFKState = true

	local playercount = player.GetCount()
	local maxcount = impulse.Config.UserSlots or game.MaxPlayers()
	local limit = impulse.Config.AFKKickRatio * maxcount

	if playercount >= limit and (impulse.Ops.EventManager.GetEventMode() or not self:IsDonator()) then
		if self:IsAdmin() then
			return
		end
		
		self:Kick("You have been kicked for inactivity on a busy server. See you again soon!")
		return
	end

	self:Notify("As a result of inactivity, you have been marked as AFK. You may be demoted from your current team.")

	if not self:IsAdmin() and self:Team() != impulse.Config.DefaultTeam then
		self:SetTeam(impulse.Config.DefaultTeam, true)
	end
end

--- Removes the AFK state from the player
-- @realm server
function meta:UnMakeAFK()
	self.AFKState = false
	self:Notify("You have returned from being AFK.")
end

--- Checks whether the player is currently AFK
-- @return boolean True if the player is AFK
-- @realm server
function meta:IsAFK()
	return self.AFKState or false
end