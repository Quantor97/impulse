--- Refund system for tracking and managing refundable items
-- @module impulse.Refunds

impulse.Refunds = impulse.Refunds or {}

local timeoutTime = 86400 -- 24 hours (86400)

--- Removes old refund entries that have expired
-- @realm server
function impulse.Refunds.Clean()
	local query = mysql:Delete("impulse_refunds")
	query:WhereLTE("date", math.floor(os.time()) - timeoutTime)
	query:Execute()
end

--- Removes a specific refund entry for a player
-- @string steamid Player's SteamID
-- @string item Item class or ID
-- @realm server
function impulse.Refunds.Remove(steamid, item)
	local query = mysql:Delete("impulse_refunds")
	query:Where("steamid", steamid)
	query:Where("item", item)
	query:Limit(1)
	query:Execute()
end

--- Removes all refund entries for a player
-- @string steamid Player's SteamID
-- @realm server
function impulse.Refunds.RemoveAll(steamid)
	local query = mysql:Delete("impulse_refunds")
	query:Where("steamid", steamid)
	query:Execute()
end

--- Adds a refund entry for a player
-- @string steamid Player's SteamID
-- @string item Item class or ID
-- @realm server
function impulse.Refunds.Add(steamid, item)
	local query = mysql:Insert("impulse_refunds")
	query:Insert("steamid", steamid)
	query:Insert("item", item)
	query:Insert("date", math.floor(os.time()))
	query:Execute()
end

if not timer.Exists("impulseRefundCleaner") then
	timer.Create("impulseRefundCleaner", 120, 0, function()
		impulse.Refunds.Clean()
	end)
end