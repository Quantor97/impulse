--- @classmod Player

--- Returns the player's current XP value for a given skill
-- @realm server
-- @string name Name of the skill
-- @treturn int Current XP value (defaults to 0 if undefined)
function meta:GetSkillXP(name)
	local skills = self.impulseSkills
	if not skills then return end

	if skills[name] then
		return skills[name]
	else
		return 0
	end
end

--- Sets the XP value for a given skill and saves it to the database
-- Also sends the updated XP to the client.
-- @realm server
-- @string name Skill name
-- @int value New XP value (rounded)
function meta:SetSkillXP(name, value)
	if not self.impulseSkills then return end
	if not impulse.Skills.Skills[name] then return end

	value = math.Round(value)

	self.impulseSkills[name] = value

	local data = util.TableToJSON(self.impulseSkills)

	if data then
		local query = mysql:Update("impulse_players")
		query:Update("skills", data)
		query:Where("steamid", self:SteamID())
		query:Execute()
	end

	self:NetworkSkill(name, value)
end

--- Sends the player's XP for a single skill to their client
-- @realm server
-- @string name Skill name
-- @int value XP value
-- @internal
function meta:NetworkSkill(name, value)
	net.Start("impulseSkillUpdate")
	net.WriteUInt(impulse.Skills.Skills[name], 4)
	net.WriteUInt(value, 16)
	net.Send(self)
end

--- Adds XP to a skill and triggers relevant updates and hooks
-- @realm server
-- @string name Skill name
-- @int value Amount of XP to add
function meta:AddSkillXP(name, value)
	if not self.impulseSkills then return end

	local cur = self:GetSkillXP(name)
	local new = math.Round(math.Clamp(cur + value, 0, 4500))

	if cur != new then
		self:SetSkillXP(name, new)
		hook.Run("PlayerAddSkillXP", self, new, name)
	end
end