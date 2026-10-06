--!strict
-- Species list and freak behaviour from DESIGN.md section 5.
-- Each species is one textured mesh (FreakModels loads them by ID), stretched
-- to its size here and facing -Z. Rarity is shown by an outline in the rarity
-- color (client OutlineController).

export type Species = {
	name: string,
	tier: number,
	shape: "Ball" | "Block" | "Cylinder", -- picks its icon in menus (UiKit.glyph)
	size: Vector3, -- the model's size in studs
	color: Color3, -- stand-in body color if the mesh can't load
	mesh: string,
	texture: string,
}

local species: { [number]: { Species } } = {
	[1] = {
		{ name = "Glowbug", tier = 1, shape = "Ball", size = Vector3.new(1.6, 2.6, 3), color = Color3.fromRGB(205, 235, 90), mesh = "rbxassetid://86609906550585", texture = "rbxassetid://88720658728380" },
		{ name = "Twitcher", tier = 1, shape = "Block", size = Vector3.new(2.9, 4, 2.7), color = Color3.fromRGB(240, 145, 60), mesh = "rbxassetid://75857159655888", texture = "rbxassetid://128349191176263" },
		{ name = "Sludgelet", tier = 1, shape = "Cylinder", size = Vector3.new(4, 2.75, 4), color = Color3.fromRGB(110, 150, 95), mesh = "rbxassetid://86187885572905", texture = "rbxassetid://93141570199291" },
	},
	[2] = {
		{ name = "Tri-Eye", tier = 2, shape = "Ball", size = Vector3.new(3.5, 4.5, 3.5), color = Color3.fromRGB(70, 185, 190), mesh = "rbxassetid://70393418437597", texture = "rbxassetid://105098802877899" },
		{ name = "Rustback", tier = 2, shape = "Block", size = Vector3.new(3.7, 4.2, 4.4), color = Color3.fromRGB(165, 85, 50), mesh = "rbxassetid://131700904649139", texture = "rbxassetid://133669143130843" },
		{ name = "Nightmare", tier = 2, shape = "Block", size = Vector3.new(2.7, 3.3, 5.8), color = Color3.fromRGB(45, 35, 60), mesh = "rbxassetid://108836171646434", texture = "rbxassetid://132139859150944" },
	},
	[3] = {
		{ name = "Gloomhound", tier = 3, shape = "Block", size = Vector3.new(4.9, 5.7, 6.2), color = Color3.fromRGB(40, 110, 115), mesh = "rbxassetid://88426691293092", texture = "rbxassetid://97006662980706" },
		{ name = "Splitjaw", tier = 3, shape = "Ball", size = Vector3.new(5.3, 6, 5.3), color = Color3.fromRGB(185, 55, 65), mesh = "rbxassetid://131592405632068", texture = "rbxassetid://94824572209564" },
		-- Stretched to twice its generated height: Wobbler is the tall one.
		{ name = "Wobbler", tier = 3, shape = "Block", size = Vector3.new(3.2, 6, 3.2), color = Color3.fromRGB(165, 145, 225), mesh = "rbxassetid://98078051144898", texture = "rbxassetid://135047999453183" },
	},
	[4] = {
		{ name = "Voidmoth", tier = 4, shape = "Block", size = Vector3.new(6.8, 4.8, 4), color = Color3.fromRGB(45, 40, 70), mesh = "rbxassetid://92595353509932", texture = "rbxassetid://103734784565688" },
		{ name = "Gnashling", tier = 4, shape = "Ball", size = Vector3.new(5, 6.5, 4.9), color = Color3.fromRGB(215, 190, 150), mesh = "rbxassetid://74938835839140", texture = "rbxassetid://85826109389461" },
		{ name = "Bloatworm", tier = 4, shape = "Cylinder", size = Vector3.new(3.2, 5, 6.2), color = Color3.fromRGB(190, 60, 110), mesh = "rbxassetid://132868023973223", texture = "rbxassetid://123068489209015" },
	},
	[5] = {
		{ name = "Hexwing", tier = 5, shape = "Block", size = Vector3.new(7.9, 4.8, 7.1), color = Color3.fromRGB(120, 200, 150), mesh = "rbxassetid://82060196258367", texture = "rbxassetid://72827899732947" },
		{ name = "Grimjaw", tier = 5, shape = "Ball", size = Vector3.new(7.4, 7.5, 6.5), color = Color3.fromRGB(110, 30, 35), mesh = "rbxassetid://129569602253189", texture = "rbxassetid://127886371434177" },
		{ name = "Pulsar", tier = 5, shape = "Cylinder", size = Vector3.new(6, 7.4, 5.3), color = Color3.fromRGB(120, 220, 90), mesh = "rbxassetid://103790198148754", texture = "rbxassetid://79297990645623" },
	},
}

-- Species that were renamed, old name -> new name, so saved freaks still load.
local renamed: { [string]: string } = {
	Fizzler = "Nightmare",
}

return {
	species = species,
	renamed = renamed,
	-- Rings that hold freaks.
	spawnTiers = { 1, 2, 3, 4, 5 },
	-- Only rings near players are simulated (DESIGN.md section 12): a ring fills
	-- when a player comes within activationMargin studs of it and empties once
	-- nobody has been that close for deactivateAfter seconds.
	activationMargin = 60,
	deactivateAfter = 60,
	-- Clients only animate freaks within this distance of the camera.
	renderDistance = 300,
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
