--- @classmod Player

impulse.Data = impulse.Data or {}

--- Returns the player's persisted data table
-- @return table Player's data table (or empty if unset)
-- @realm server
function meta:GetData()
	return self.impulseData or {}
end

--- Saves the player's data to the database
-- @realm server
function meta:SaveData()	
	local query = mysql:Update("impulse_players")
	query:Update("data", util.TableToJSON(self.impulseData))
	query:Where("steamid", self:SteamID())
	query:Execute()
end

--- Handles persistent data saving and loading for impulse framework (e.g., player money, skills, inventory, etc.).
-- @module impulse.Data

--- Writes or updates persistent named data
-- @string name Unique identifier for the data entry
-- @param data Table to be encoded and stored
-- @realm server
function impulse.Data.Write(name, data)
	local query = mysql:Select("impulse_data")
	query:Select("id")
	query:Where("name", name)
	query:Callback(function(result) -- somewhat annoying that we cant do a conditional query or smthing but whatever
		if type(result) == "table" and #result > 0 then
			local followUp = mysql:Update("impulse_data")
			followUp:Update("data", pon.encode(data))
			followUp:Where("name", name)
			followUp:Execute()
		else
			local followUp = mysql:Insert("impulse_data")
			followUp:Insert("name", name)
			followUp:Insert("data", pon.encode(data))
			followUp:Execute()
		end
	end)

	query:Execute()
end

--- Removes persistent named data
-- @string name Unique identifier for the data entry
-- @int[opt] limit Optional deletion limit
-- @realm server
function impulse.Data.Remove(name, limit)
	local query = mysql:Delete("impulse_data")
	query:Where("name", name)

	if limit then
		query:Limit(limit)
	end

	query:Execute()
end

--- Reads persistent named data and passes it to a callback
-- @string name Unique identifier for the data entry
-- @func onDone Callback to receive decoded data table
-- @func[opt] fallback Called if the data does not exist
-- @realm server
function impulse.Data.Read(name, onDone, fallback)
	local query = mysql:Select("impulse_data")
	query:Select("data")
	query:Where("name", name)
	query:Callback(function(result)
		if type(result) == "table" and #result > 0 then
			onDone(pon.decode(result[1].data))
		elseif fallback then
			fallback()
		end
	end)

	query:Execute()
end