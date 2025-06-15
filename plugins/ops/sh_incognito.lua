---@classmod Player

--- Checks whether the player is in incognito mode.
-- @realm shared
-- @treturn boolean True if the player is incognito, false otherwise
function meta:IsIncognito()
	return self:GetSyncVar(SYNC_INCOGNITO, false)
end

local incognitoCommand = {
    description = "Toggles incognito mode. DO NOT USE FOR LONG PERIODS.",
    requiresArg = false,
    adminOnly = true,
    onRun = function(ply, arg, rawText)
    	ply:SetSyncVar(SYNC_INCOGNITO, !ply:IsIncognito(), true)

    	if ply:IsIncognito() then
    		ply:Notify("You have entered incognito mode. Please go back to normal mode as soon as you can.")
    	else
    		ply:Notify("You have exited incognito mode.")
    	end
    end
}

impulse.RegisterChatCommand("/incognitotoggle", incognitoCommand)