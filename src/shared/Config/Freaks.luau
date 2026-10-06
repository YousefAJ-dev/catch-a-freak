--!strict
-- Species list and freak behaviour from DESIGN.md section 5.
-- Looks are greybox placeholders until real models arrive in Milestone 10:
-- species differ by body shape, size and eye count; the body is tinted in
-- the freak's rarity color.

export type Species = {
	name: string,
	tier: number,
	shape: "Ball" | "Block" | "Cylinder",
	size: Vector3,
	eyes: number,
}

local species: { [number]: { Species } } = {
	[1] = {
		{ name = "Glowbug", tier = 1, shape = "Ball", size = Vector3.new(3, 3, 3), eyes = 2 },
		{ name = "Twitcher", tier = 1, shape = "Block", size = Vector3.new(2, 4, 2), eyes = 2 },
		{ name = "Sludgelet", tier = 1, shape = "Cylinder", size = Vector3.new(1.5, 4, 4), eyes = 1 },
	},
	[2] = {
		{ name = "Tri-Eye", tier = 2, shape = "Ball", size = Vector3.new(4.5, 4.5, 4.5), eyes = 3 },
		{ name = "Rustback", tier = 2, shape = "Block", size = Vector3.new(5, 3, 3.5), eyes = 2 },
		{ name = "Fizzler", tier = 2, shape = "Cylinder", size = Vector3.new(5, 3, 3), eyes = 2 },
	},
	[3] = {
		{ name = "Gloomhound", tier = 3, shape = "Block", size = Vector3.new(3.5, 4.5, 6.5), eyes = 2 },
		{ name = "Splitjaw", tier = 3, shape = "Ball", size = Vector3.new(6, 6, 6), eyes = 1 },
		{ name = "Wobbler", tier = 3, shape = "Block", size = Vector3.new(3, 7.5, 3), eyes = 3 },
	},
}

return {
	species = species,
	-- Rings that hold freaks. Rings 2 and 3 join in Milestone 7.
	spawnTiers = { 1 },
	respawnDelay = 3, -- seconds after a freak is caught or expires
	lifetimeMin = 120,
	lifetimeMax = 240,
	wallMargin = 10, -- spawn and wander targets stay this far from any wall
	wanderRadius = 60,
	waitMin = 1,
	waitMax = 3,
	grabRange = 10,
	beamHeight = 150,
	beamWidth = 2,
}
