--!strict
-- Species list and freak behaviour from DESIGN.md section 5.
-- Looks are greybox placeholders until real models arrive in Milestone 10:
-- each species has its own body shape, size, color and eye count. Rarity is
-- shown by an outline in the rarity color (client OutlineController).

export type Species = {
	name: string,
	tier: number,
	shape: "Ball" | "Block" | "Cylinder",
	size: Vector3,
	color: Color3,
	eyes: number,
}

local species: { [number]: { Species } } = {
	[1] = {
		{ name = "Glowbug", tier = 1, shape = "Ball", size = Vector3.new(3, 3, 3), color = Color3.fromRGB(205, 235, 90), eyes = 2 },
		{ name = "Twitcher", tier = 1, shape = "Block", size = Vector3.new(2, 4, 2), color = Color3.fromRGB(240, 145, 60), eyes = 2 },
		{ name = "Sludgelet", tier = 1, shape = "Cylinder", size = Vector3.new(1.5, 4, 4), color = Color3.fromRGB(110, 150, 95), eyes = 1 },
	},
	[2] = {
		{ name = "Tri-Eye", tier = 2, shape = "Ball", size = Vector3.new(4.5, 4.5, 4.5), color = Color3.fromRGB(70, 185, 190), eyes = 3 },
		{ name = "Rustback", tier = 2, shape = "Block", size = Vector3.new(5, 3, 3.5), color = Color3.fromRGB(165, 85, 50), eyes = 2 },
		{ name = "Fizzler", tier = 2, shape = "Cylinder", size = Vector3.new(5, 3, 3), color = Color3.fromRGB(235, 125, 185), eyes = 2 },
	},
	[3] = {
		{ name = "Gloomhound", tier = 3, shape = "Block", size = Vector3.new(3.5, 4.5, 6.5), color = Color3.fromRGB(75, 75, 105), eyes = 2 },
		{ name = "Splitjaw", tier = 3, shape = "Ball", size = Vector3.new(6, 6, 6), color = Color3.fromRGB(185, 55, 65), eyes = 1 },
		{ name = "Wobbler", tier = 3, shape = "Block", size = Vector3.new(3, 7.5, 3), color = Color3.fromRGB(165, 145, 225), eyes = 3 },
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
	-- Only the nearest few freaks get a rarity outline: Roblox renders at most
	-- ~31 outlines (Highlights) at once, and this keeps the view uncluttered.
	outlinedNearest = 6,
}
