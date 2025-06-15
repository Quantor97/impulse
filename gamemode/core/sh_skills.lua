--- Skill system for the impulse framework.
-- @module impulse.Skills

impulse.Skills = impulse.Skills or {}
impulse.Skills.Skills = impulse.Skills.Skills or {}
impulse.Skills.NiceNames = impulse.Skills.NiceNames or {}
impulse.Skills.Data = impulse.Skills.Data or {}

local count = 0

--- Defines a new skill.
-- @realm shared
-- @string name Internal skill name (e.g. "craft")
-- @string niceName Display name for the skill (e.g. "Crafting")
function impulse.Skills.Define(name, niceName)
	count = count + 1
	impulse.Skills.Skills[name] = count
	impulse.Skills.NiceNames[name] = niceName
end

--- Returns the display name for a skill.
-- @realm shared
-- @string name Internal skill name
-- @treturn string Display name of the skill
function impulse.Skills.GetNiceName(name)
	return impulse.Skills.NiceNames[name]
end

if CLIENT then
	--- Returns the total XP required to reach a skill level.
	-- XP cost scales quadratically with level.
	-- @realm client
	-- @int level Skill level (1–10)
	-- @treturn number XP required to reach the given level (max 4500)
	function impulse.Skills.GetLevelXPRequirement(level)
		local req = 0

		for i = 1, level do
			req = req + (i * 100)
		end

		return math.Clamp(req, 0, 4500)
	end

	--- @classmod Player

	--- Returns the player's XP for a specific skill.
	-- @realm client
	-- @string name Skill name
	-- @treturn number XP amount for the skill
	function meta:GetSkillXP(name)
		local xp = impulse.Skills.Data[name]
		return xp or 0
	end
end

--- @classmod Player

--- Returns the player's current level in a given skill.
-- @realm shared
-- @string name Skill name
-- @treturn int Skill level (0–10)
function meta:GetSkillLevel(name)
	local xp = self:GetSkillXP(name)
	local req = 0

	for i = 1, 10 do
		if xp < req then
			return i - 1
		end

		req = req + (i * 100)
	end

	return 10
end

impulse.Skills.Define("craft", "Crafting")
--impulse.Skills.Define("medicine", "Medicine")
impulse.Skills.Define("strength", "Strength")
impulse.Skills.Define("lockpick", "Lockpicking")
