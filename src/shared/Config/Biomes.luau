--!strict
-- Biomes from DESIGN.md section 2: how each zone looks. The ground and walls
-- are built in Studio by tools/BuildMap.luau and tools/BuildBiomes.luau; the
-- lighting is switched by the client (BiomeController) when the player enters
-- the zone.
--
-- Keys are ZoneTier values: 0 is the safe zone (shop + farm plots), 1-5 the rings.
-- The safe zone's ground is a part; the rings' ground is flat terrain at
-- ground level, in `ground` with patches of `patches`, and low banks of
-- `bank` along the walls. A terrain material has one color for the whole map,
-- so each material belongs to a single biome.

-- Daytime biomes keep the sun near noon at the equator: the walls are 120
-- studs tall, and a lower sun leaves most of a ring's floor in their shadow.
-- Mood comes from the haze and color grading instead.
export type Lighting = {
	clockTime: number,
	latitude: number, -- Lighting.GeographicLatitude
	brightness: number,
	ambient: Color3,
	outdoorAmbient: Color3,
	atmosphere: { density: number, offset: number, color: Color3, decay: Color3, glare: number, haze: number },
	colorCorrection: { tint: Color3, saturation: number, contrast: number, brightness: number },
	bloom: { intensity: number, size: number, threshold: number },
}

export type Surface = { material: Enum.Material, color: Color3 }

export type Biome = {
	name: string,
	ground: Surface,
	patches: { Surface }?,
	bank: Surface?, -- terrain banked against the walls, or nil for none
	wall: Surface?, -- cladding on this zone's side of its walls
	lighting: Lighting,
}

local Biomes: { [number]: Biome } = {
	[0] = {
		name = "Radioactive Lab",
		ground = { material = Enum.Material.Concrete, color = Color3.fromRGB(88, 96, 92) },
		lighting = {
			clockTime = 13,
			latitude = 0,
			brightness = 2.4,
			ambient = Color3.fromRGB(80, 90, 85),
			outdoorAmbient = Color3.fromRGB(140, 155, 145),
			atmosphere = { density = 0.25, offset = 0.1, color = Color3.fromRGB(190, 225, 200), decay = Color3.fromRGB(110, 150, 120), glare = 0, haze = 1 },
			colorCorrection = { tint = Color3.fromRGB(235, 255, 238), saturation = 0.05, contrast = 0.05, brightness = 0 },
			bloom = { intensity = 0.6, size = 24, threshold = 1.6 },
		},
	},
	[1] = {
		name = "Dry Field",
		ground = { material = Enum.Material.Grass, color = Color3.fromRGB(170, 155, 85) },
		patches = { { material = Enum.Material.Ground, color = Color3.fromRGB(168, 140, 98) } },
		bank = { material = Enum.Material.Grass, color = Color3.fromRGB(170, 155, 85) },
		wall = { material = Enum.Material.WoodPlanks, color = Color3.fromRGB(125, 95, 65) },
		lighting = {
			clockTime = 13.5,
			latitude = 0,
			brightness = 2.6,
			ambient = Color3.fromRGB(95, 85, 65),
			outdoorAmbient = Color3.fromRGB(165, 150, 120),
			atmosphere = { density = 0.3, offset = 0.15, color = Color3.fromRGB(235, 215, 165), decay = Color3.fromRGB(190, 160, 110), glare = 0.4, haze = 1.5 },
			colorCorrection = { tint = Color3.fromRGB(255, 245, 225), saturation = 0.1, contrast = 0.05, brightness = 0.02 },
			bloom = { intensity = 0.5, size = 24, threshold = 1.8 },
		},
	},
	[2] = {
		name = "Wasteland",
		ground = { material = Enum.Material.Sand, color = Color3.fromRGB(182, 150, 110) },
		patches = { { material = Enum.Material.Rock, color = Color3.fromRGB(128, 112, 98) } },
		bank = { material = Enum.Material.Sandstone, color = Color3.fromRGB(172, 120, 80) },
		wall = { material = Enum.Material.CorrodedMetal, color = Color3.fromRGB(96, 84, 76) },
		lighting = {
			clockTime = 12.5,
			latitude = 0,
			brightness = 2.6,
			ambient = Color3.fromRGB(105, 88, 70),
			outdoorAmbient = Color3.fromRGB(170, 145, 120),
			atmosphere = { density = 0.36, offset = 0.1, color = Color3.fromRGB(225, 190, 150), decay = Color3.fromRGB(170, 120, 80), glare = 0.6, haze = 2.2 },
			colorCorrection = { tint = Color3.fromRGB(255, 238, 218), saturation = -0.05, contrast = 0.08, brightness = 0.02 },
			bloom = { intensity = 0.6, size = 24, threshold = 1.6 },
		},
	},
	[3] = {
		name = "Radioactive Swamp",
		ground = { material = Enum.Material.Mud, color = Color3.fromRGB(88, 102, 66) },
		patches = { { material = Enum.Material.LeafyGrass, color = Color3.fromRGB(92, 125, 60) } },
		bank = { material = Enum.Material.LeafyGrass, color = Color3.fromRGB(92, 125, 60) },
		wall = { material = Enum.Material.Cobblestone, color = Color3.fromRGB(84, 104, 76) },
		lighting = {
			clockTime = 12,
			latitude = 0,
			brightness = 2.2,
			ambient = Color3.fromRGB(85, 110, 80),
			outdoorAmbient = Color3.fromRGB(145, 170, 135),
			atmosphere = { density = 0.42, offset = 0.05, color = Color3.fromRGB(150, 190, 130), decay = Color3.fromRGB(80, 130, 70), glare = 0, haze = 2.2 },
			colorCorrection = { tint = Color3.fromRGB(228, 255, 222), saturation = 0, contrast = 0.06, brightness = 0.02 },
			bloom = { intensity = 1, size = 30, threshold = 1.2 },
		},
	},
	[4] = {
		name = "Cavern",
		ground = { material = Enum.Material.Slate, color = Color3.fromRGB(70, 68, 82) },
		patches = { { material = Enum.Material.Basalt, color = Color3.fromRGB(52, 49, 64) } },
		bank = { material = Enum.Material.Basalt, color = Color3.fromRGB(52, 49, 64) },
		wall = { material = Enum.Material.Rock, color = Color3.fromRGB(72, 68, 86) },
		-- Night, so the crystals and mushrooms glow, but with strong ambient
		-- light so freaks stay easy to see.
		lighting = {
			clockTime = 0,
			latitude = 0,
			brightness = 1.5,
			ambient = Color3.fromRGB(120, 110, 165),
			outdoorAmbient = Color3.fromRGB(110, 100, 155),
			atmosphere = { density = 0.4, offset = 0, color = Color3.fromRGB(55, 45, 90), decay = Color3.fromRGB(30, 22, 55), glare = 0, haze = 1 },
			colorCorrection = { tint = Color3.fromRGB(230, 225, 255), saturation = 0.1, contrast = 0.1, brightness = 0.06 },
			bloom = { intensity = 1.2, size = 32, threshold = 0.95 },
		},
	},
	[5] = {
		name = "Chemical Plant",
		ground = { material = Enum.Material.Asphalt, color = Color3.fromRGB(84, 86, 82) },
		patches = { { material = Enum.Material.Pavement, color = Color3.fromRGB(125, 127, 118) } },
		wall = { material = Enum.Material.Metal, color = Color3.fromRGB(118, 126, 112) },
		lighting = {
			clockTime = 13,
			latitude = 0,
			brightness = 2.3,
			ambient = Color3.fromRGB(105, 110, 90),
			outdoorAmbient = Color3.fromRGB(160, 165, 140),
			atmosphere = { density = 0.42, offset = 0.05, color = Color3.fromRGB(200, 210, 150), decay = Color3.fromRGB(130, 140, 70), glare = 0.3, haze = 2 },
			colorCorrection = { tint = Color3.fromRGB(245, 255, 228), saturation = -0.1, contrast = 0.1, brightness = 0.02 },
			bloom = { intensity = 1, size = 28, threshold = 1.2 },
		},
	},
}

return Biomes
