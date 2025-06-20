--- @module impulse

--- Checks whether a position is empty and free of blocking entities
-- @param vector vector The position to check
-- @param[opt] ignore table A list of entities to ignore
-- @treturn bool True if the position is free
-- @realm server
function impulse.IsEmpty(vector, ignore) -- findpos and isempty are from darkrp
    ignore = ignore or {}

    local point = util.PointContents(vector)
    local a = point ~= CONTENTS_SOLID
        and point ~= CONTENTS_MOVEABLE
        and point ~= CONTENTS_LADDER
        and point ~= CONTENTS_PLAYERCLIP
        and point ~= CONTENTS_MONSTERCLIP
    if not a then return false end

    local b = true

    for _, v in ipairs(ents.FindInSphere(vector, 35)) do
        if (v:IsNPC() or v:IsPlayer() or v:GetClass() == "prop_physics" or v.NotEmptyPos) and not table.HasValue(ignore, v) then
            b = false
            break
        end
    end

	return a and b
end

--- Finds an empty nearby position starting from a base point
-- @param pos vector Starting position
-- @param ignore table List of entities to ignore
-- @param distance number Maximum distance to search
-- @param step number Step size between checks
-- @param area vector Bounding area offset (e.g. Vector(16, 16, 64))
-- @treturn vector The first valid empty position
-- @realm server
function impulse.FindEmptyPos(pos, ignore, distance, step, area)
    if impulse.IsEmpty(pos, ignore) and impulse.IsEmpty(pos + area, ignore) then
        return pos
    end

    for j = step, distance, step do
        for i = -1, 1, 2 do -- alternate in direction
            local k = j * i

            -- Look North/South
            if impulse.IsEmpty(pos + Vector(k, 0, 0), ignore) and impulse.IsEmpty(pos + Vector(k, 0, 0) + area, ignore) then
                return pos + Vector(k, 0, 0)
            end

            -- Look East/West
            if impulse.IsEmpty(pos + Vector(0, k, 0), ignore) and impulse.IsEmpty(pos + Vector(0, k, 0) + area, ignore) then
                return pos + Vector(0, k, 0)
            end

            -- Look Up/Down
            if impulse.IsEmpty(pos + Vector(0, 0, k), ignore) and impulse.IsEmpty(pos + Vector(0, 0, k) + area, ignore) then
                return pos + Vector(0, 0, k)
            end
        end
    end

    return pos
end

--- @classmod Player

--- Sends the player's default model and skin to the client
-- @realm server
function meta:UpdateDefaultModelSkin()
    net.Start("impulseUpdateDefaultModelSkin")
    net.WriteString(self.defaultModel)
    net.WriteUInt(self.defaultSkin, 8)
    net.Send(self)
end

-- divert from slow nwvar shit

--- Returns the number of spawned props for this player
-- @bool[opt] skip If true, skips syncing the value to client
-- @treturn number Number of valid props
-- @realm server
function meta:GetPropCount(skip)
    if ( !self:IsValid() ) then return end

    local key = self:UniqueID()
    local tab = g_SBoxObjects[key]

    if ( !tab || !tab["props"] ) then
        return 0
    end

    local c = 0

    for k, v in pairs(tab["props"]) do
        if ( IsValid(v) and !v:IsMarkedForDeletion() ) then
            c = c + 1
        else
            tab["props"][k] = nil
        end

    end

    if not skip then
        self:SetLocalSyncVar(SYNC_PROPCOUNT, c)
    end

    return c
end

--- Registers a spawned prop to the player's prop tracking system
-- @param ent entity The prop entity to track
-- @realm server
function meta:AddPropCount(ent)
    local key = self:UniqueID()
    g_SBoxObjects[ key ] = g_SBoxObjects[ key ] or {}
    g_SBoxObjects[ key ]["props"] = g_SBoxObjects[ key ]["props"] or {}

    local tab = g_SBoxObjects[ key ]["props"]

    table.insert( tab, ent )

    self:GetPropCount()

    ent:CallOnRemove("GetPropCountUpdate", function(ent, ply) ply:GetPropCount() end, self)
end

--- Resets any submaterials applied to the player model
-- @realm server
function meta:ResetSubMaterials()
    if not self.SetSubMats then
        return
    end
    
    for v,k in pairs(self.SetSubMats) do
        self:SetSubMaterial(v - 1, nil)
    end

    self.SetSubMats = nil
end