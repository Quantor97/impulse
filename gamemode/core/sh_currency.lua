--- @classmod Player


--- Returns the amount of money the player currently has.
-- @realm shared
-- @treturn number Money amount
function meta:GetMoney()
	return self:GetSyncVar(SYNC_MONEY, 0)
end

--- Returns the amount of money in the player's bank.
-- @realm shared
-- @treturn number Bank money amount
function meta:GetBankMoney()
	return self:GetSyncVar(SYNC_BANKMONEY, 0)
end

--- Checks if the player has enough money to afford something.
-- @realm shared
-- @number amount The amount to check
-- @treturn boolean True if player has enough money
function meta:CanAfford(amount)
	return self:GetMoney() >= amount
end

--- Checks if the player has enough bank money to afford something.
-- @realm shared
-- @number amount The amount to check
-- @treturn boolean True if player has enough bank money
function meta:CanAffordBank(amount)
	return self:GetBankMoney() >= amount
end