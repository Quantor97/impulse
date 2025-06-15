--- @module impulse

impulse.Vendor = impulse.Vendor or {}
impulse.Vendor.Data = impulse.Vendor.Data or {}

--- Registers a vendor with the system
-- @param vendor Table containing vendor data (must include UniqueID)
-- @realm shared
-- @name impulse.RegisterVendor
function impulse.RegisterVendor(vendor)
	impulse.Vendor.Data[vendor.UniqueID] = vendor
end