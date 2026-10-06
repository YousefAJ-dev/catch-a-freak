--!strict
-- Player stats from DESIGN.md section 4.

return {
	maxHealth = 100,
	baseWalkSpeed = 16,
	-- Above this Roblox characters get hard to steer and the client can't
	-- stream the map in fast enough (DESIGN.md section 4).
	maxWalkSpeed = 55,
	carrySlots = 9,
}
