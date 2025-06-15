--- @classmod Player

--- Sets the player's wallet money
-- @number amount Amount to set (must be >= 0)
-- @realm server
function meta:SetMoney(amount)
	if not self.beenSetup or self.beenSetup == false then return end
	if not isnumber(amount) or amount < 0 or amount >= 1 / 0 then return end

	local query = mysql:Update("impulse_players")
	query:Update("money", amount)
	query:Where("steamid", self:SteamID())
	query:Execute()

	return self:SetLocalSyncVar(SYNC_MONEY, amount)
end

--- Sets the player's bank money
-- @number amount Amount to set (must be >= 0)
-- @realm server
function meta:SetBankMoney(amount)
	if not self.beenSetup or self.beenSetup == false then return end
	if not isnumber(amount) or amount < 0 or amount >= 1 / 0 then return end

	local query = mysql:Update("impulse_players")
	query:Update("bankmoney", amount)
	query:Where("steamid", self:SteamID())
	query:Execute()

	return self:SetLocalSyncVar(SYNC_BANKMONEY, amount)
end

--- Adds money to the player's bank account
-- @number amount Amount to add
-- @realm server
function meta:GiveBankMoney(amount)
	return self:SetBankMoney(self:GetBankMoney() + amount)
end

--- Removes money from the player's bank account
-- @number amount Amount to remove
-- @realm server
function meta:TakeBankMoney(amount)
	return self:SetBankMoney(self:GetBankMoney() - amount)
end

--- Adds money to the player's wallet
-- @number amount Amount to add
-- @realm server
function meta:GiveMoney(amount)
	return self:SetMoney(self:GetMoney() + amount)
end

--- Removes money from the player's wallet
-- @number amount Amount to remove
-- @realm server
function meta:TakeMoney(amount)
	return self:SetMoney(self:GetMoney() - amount)
end

--- @module impulse

--- Spawns a physical money entity in the world
-- @param pos vector Position where the money should spawn
-- @number amount Amount of money to spawn
-- @param[opt] dropper player Who dropped the money
-- @return entity The spawned money entity
-- @realm server
function impulse.SpawnMoney(pos, amount, dropper)
	local note = ents.Create("impulse_money")
	note:SetMoney(amount)
	note:SetPos(pos)
	note.Dropper = dropper or nil
	note:Spawn()

	return note
end