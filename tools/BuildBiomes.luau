--[[
	Biome builder (Milestone 10): terrain, wall cladding and props for the lab
	and each ring, from DESIGN.md section 2 and Config/Biomes.

	Not a game script: run it in Studio's edit DataModel (via the Studio MCP
	execute_luau tool or the command bar) after tools/BuildMap.luau; Rojo
	syncs it to ServerStorage.Tools, so require a clone of it there. It
	replaces all terrain and rebuilds Workspace.Map.Biomes, so re-run it after
	rebuilding the map.
	Placement is seeded, so every run builds the same layout. Save the place
	afterwards to keep the result.

	Freaks walk in straight lines and pass through props, so big props stand
	near the walls and the open middle of each ring stays mostly clear. No prop
	goes in the N/E/S/W lanes that run through the doors.
]]

local Shared = game:GetService("ReplicatedStorage").Shared
-- Require clones so config edits are picked up without restarting Studio.
local function load(module: ModuleScript): any
	local copy = module:Clone()
	local result = require(copy)
	copy:Destroy()
	return result
end
local World = load(Shared.Config.World)
local Biomes = load(Shared.Config.Biomes)

local GROUND_Y = World.groundY
local THICK = World.wallThickness
local LANE_HALF = World.doorWidth / 2 + 6 -- keep this far from each lane's center line
local BANK_DEPTH = 12 -- how far terrain banks reach out from a wall's face

local function dirFromAngle(degrees: number): Vector3
	local a = math.rad(degrees)
	return Vector3.new(math.sin(a), 0, -math.cos(a))
end

local function pointAt(radius: number, degrees: number): Vector3
	return World.center + dirFromAngle(degrees) * radius + Vector3.new(0, GROUND_Y, 0)
end

-- Every prop part goes through here. Small decoration passes `decor = true`:
-- no collisions, no shadows, ignored by raycasts.
local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	local decor = props.decor
	props.decor = nil
	if decor then
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
	end
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

-- An ellipsoid: a block whose sphere mesh stretches to the part's size.
local function blob(props: { [string]: any }): Part
	local p = part(props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- An upright cylinder standing on `base` (its bottom center).
local function column(base: CFrame, height: number, diameter: number, props: { [string]: any }): Part
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	return part(props)
end

-- A cylinder from point a to point b.
local function rod(a: Vector3, b: Vector3, diameter: number, props: { [string]: any }): Part
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new((b - a).Magnitude, diameter, diameter)
	-- A cylinder's axis is X: point X along a -> b.
	props.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	return part(props)
end

local function light(parent: Instance, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
end

local function model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function vary(color: Color3, rng: Random, amount: number): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s, math.clamp(v * (1 + rng:NextNumber(-amount, amount)), 0, 1))
end

------------------------------------------------------------------------------
-- Generated props: textured meshes made with Roblox's mesh generator (see
-- docs/generating-models.md). Each is loaded once, then cloned and scaled.

local AssetService = game:GetService("AssetService")

local PROP_MESHES = {
	deadTree = { mesh = "rbxassetid://78226499815099", texture = "rbxassetid://125523398158330" },
	scarecrow = { mesh = "rbxassetid://113970480724403", texture = "rbxassetid://81469309179972" },
	swampTree = { mesh = "rbxassetid://103303125428981", texture = "rbxassetid://103554161091590" },
	crystals = { mesh = "rbxassetid://130322223811308", texture = "rbxassetid://105715702987523" },
	stalagmite = { mesh = "rbxassetid://85263007780215", texture = "rbxassetid://78347370518006" },
	mushrooms = { mesh = "rbxassetid://75807441907262", texture = "rbxassetid://77642159859702" },
	chemicalTank = { mesh = "rbxassetid://85973143778239", texture = "rbxassetid://98055436336708" },
	toxicBarrel = { mesh = "rbxassetid://115292107387822", texture = "rbxassetid://87474353778075" },
}

local templates: { [string]: MeshPart } = {}

-- A copy of a generated prop, scaled evenly to `height` and standing on `cf`.
-- Matte (Fabric) so it reads as painted rather than plastic.
local function meshProp(key: string, parent: Instance, cf: CFrame, height: number, decor: boolean?): MeshPart
	local template = templates[key]
	if not template then
		local info = PROP_MESHES[key]
		template = AssetService:CreateMeshPartAsync(Content.fromUri(info.mesh))
		template.TextureID = info.texture
		templates[key] = template
	end
	local p = template:Clone()
	p.Name = key
	p.Anchored = true
	p.Material = Enum.Material.Fabric
	p.Size *= height / p.Size.Y
	p.CFrame = cf * CFrame.new(0, p.Size.Y / 2 - 0.1, 0)
	p.CanTouch = false
	if decor then
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end

------------------------------------------------------------------------------
-- Placement

type Placed = { position: Vector3, radius: number }

local function laneClear(p: Vector3, radius: number): boolean
	local rel = p - World.center
	return math.abs(rel.X) > LANE_HALF + radius and math.abs(rel.Z) > LANE_HALF + radius
end

local function free(p: Vector3, radius: number, placed: { Placed }): boolean
	for _, other in placed do
		local gap = ((p - other.position) * Vector3.new(1, 0, 1)).Magnitude
		if gap < radius + other.radius then
			return false
		end
	end
	return true
end

type Spot = {
	kind: "edge" | "field",
	radius: number, -- footprint radius, for spacing and lane clearance
	depth: number?, -- edge props: how far the prop reaches out from the wall (default radius)
	overlap: boolean?, -- may overlap other props
	onBank: boolean?, -- edge props: stand on the wall's bank instead of in front of it
}

-- Finds a spot in a ring (inner..outer radius) for a prop, or nil after
-- enough tries. "edge" spots hug a wall and face away from it, lined up with
-- it; "field" spots are anywhere at least 12 studs clear of both walls, at a
-- random angle. The returned CFrame sits on the ground.
local function findSpot(rng: Random, ring: any, spot: Spot): CFrame?
	local depth = spot.depth or spot.radius
	for _ = 1, 40 do
		local r
		if spot.kind == "edge" then
			local fromFace = depth + rng:NextNumber(0.5, 3) + (if spot.onBank then 0 else ring.bankDepth)
			r = if rng:NextNumber() < 0.5 then ring.inner + THICK / 2 + fromFace else ring.outer - THICK / 2 - fromFace
		else
			local margin = 12 + spot.radius
			r = math.sqrt(rng:NextNumber((ring.inner + margin) ^ 2, (ring.outer - margin) ^ 2))
		end
		local p = pointAt(r, rng:NextNumber(0, 360))
		if laneClear(p, spot.radius) and (spot.overlap or free(p, spot.radius, ring.placed)) then
			table.insert(ring.placed, { position = p, radius = spot.radius })
			-- -Z faces the map center, so X runs along the walls.
			local facing = CFrame.lookAt(p, Vector3.new(World.center.X, p.Y, World.center.Z))
			if spot.kind == "field" then
				facing *= CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			end
			return facing
		end
	end
	return nil
end

-- Calls `build(cf, rng)` at `count` spots.
local function scatter(rng: Random, ring: any, count: number, spot: Spot, build: (CFrame, Random) -> ())
	for _ = 1, count do
		local cf = findSpot(rng, ring, spot)
		if cf then
			build(cf, rng)
		end
	end
end

------------------------------------------------------------------------------
-- Ring 1: dry field

local function deadTree(parent: Instance, cf: CFrame, rng: Random)
	meshProp("deadTree", parent, cf, rng:NextNumber(14, 22))
end

local function bush(parent: Instance, cf: CFrame, rng: Random, color: Color3)
	for _ = 1, rng:NextInteger(2, 3) do
		local size = rng:NextNumber(1.8, 3.2)
		blob({
			Name = "Bush",
			Size = Vector3.new(size * 1.3, size, size * 1.3),
			CFrame = cf * CFrame.new(rng:NextNumber(-1.2, 1.2), size * 0.3, rng:NextNumber(-1.2, 1.2)),
			Color = vary(color, rng, 0.15),
			Material = Enum.Material.Grass,
			decor = true,
			Parent = parent,
		})
	end
end

-- The generated hay bale came out with magenta bands; this stays a plain
-- cylinder until a better one is generated.
local function hayBale(parent: Instance, cf: CFrame, rng: Random)
	local d = rng:NextNumber(4, 5)
	part({
		Name = "HayBale",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(rng:NextNumber(4, 5), d, d),
		CFrame = cf * CFrame.new(0, d / 2 - 0.2, 0),
		Color = vary(Color3.fromRGB(214, 182, 96), rng, 0.08),
		Material = Enum.Material.Fabric,
		Parent = parent,
	})
end

local function grassTuft(parent: Instance, cf: CFrame, rng: Random, color: Color3)
	for i = 1, 3 do
		local h = rng:NextNumber(1.5, 3)
		part({
			Name = "Grass",
			Size = Vector3.new(0.25, h, 1.2),
			CFrame = cf * CFrame.Angles(0, math.rad(i * 60), 0) * CFrame.new(0, h / 2 - 0.1, 0) * CFrame.Angles(math.rad(rng:NextNumber(-15, 15)), 0, 0),
			Color = vary(color, rng, 0.12),
			Material = Enum.Material.Grass,
			decor = true,
			Parent = parent,
		})
	end
end

local function boulder(parent: Instance, cf: CFrame, rng: Random, color: Color3, size: number, material: Enum.Material?)
	local s = Vector3.new(size * rng:NextNumber(0.8, 1.3), size * rng:NextNumber(0.5, 0.9), size * rng:NextNumber(0.8, 1.3))
	blob({
		Name = "Rock",
		Size = s,
		CFrame = cf * CFrame.new(0, s.Y * 0.3, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		Color = vary(color, rng, 0.12),
		Material = material or Enum.Material.Rock,
		decor = size < 3,
		Parent = parent,
	})
end

local function fence(parent: Instance, cf: CFrame, rng: Random)
	local m = model("Fence", parent)
	local wood = Color3.fromRGB(120, 92, 62)
	local posts = rng:NextInteger(3, 4)
	local spacing = 5
	local width = (posts - 1) * spacing
	for i = 0, posts - 1 do
		local lean = math.rad(rng:NextNumber(-8, 8))
		part({
			Name = "Post",
			Size = Vector3.new(0.6, 4, 0.6),
			CFrame = cf * CFrame.new(-width / 2 + i * spacing, 2, 0) * CFrame.Angles(0, 0, lean),
			Color = vary(wood, rng, 0.1),
			Material = Enum.Material.WoodPlanks,
			Parent = m,
		})
	end
	for _, y in { 1.6, 3 } do
		part({
			Name = "Rail",
			Size = Vector3.new(width + 1, 0.4, 0.3),
			CFrame = cf * CFrame.new(0, y, 0.3) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-3, 3))),
			Color = vary(wood, rng, 0.1),
			Material = Enum.Material.WoodPlanks,
			Parent = m,
		})
	end
end

local function scarecrow(parent: Instance, cf: CFrame, rng: Random)
	meshProp("scarecrow", parent, cf, rng:NextNumber(8, 10))
end

local function buildDryField(folder: Instance, ring: any, rng: Random)
	scatter(rng, ring, 44, { kind = "edge", radius = 5, onBank = true }, function(cf, r)
		deadTree(folder, cf, r)
	end)
	scatter(rng, ring, 50, { kind = "field", radius = 2, overlap = true }, function(cf, r)
		bush(folder, cf, r, Color3.fromRGB(150, 140, 70))
	end)
	scatter(rng, ring, 22, { kind = "edge", radius = 8, depth = 1 }, function(cf, r)
		fence(folder, cf, r)
	end)
	scatter(rng, ring, 30, { kind = "field", radius = 3 }, function(cf, r)
		hayBale(folder, cf, r)
	end)
	scatter(rng, ring, 5, { kind = "field", radius = 3 }, function(cf, r)
		scarecrow(folder, cf, r)
	end)
	scatter(rng, ring, 45, { kind = "field", radius = 2 }, function(cf, r)
		boulder(folder, cf, r, Color3.fromRGB(150, 140, 120), r:NextNumber(1.5, 4))
	end)
	scatter(rng, ring, 140, { kind = "field", radius = 1, overlap = true }, function(cf, r)
		grassTuft(folder, cf, r, Color3.fromRGB(200, 180, 95))
	end)
end

------------------------------------------------------------------------------
-- Ring 2: wasteland

local RUST = { Color3.fromRGB(140, 70, 45), Color3.fromRGB(120, 90, 70), Color3.fromRGB(90, 100, 105), Color3.fromRGB(150, 120, 60) }

local function carWreck(parent: Instance, cf: CFrame, rng: Random)
	local m = model("CarWreck", parent)
	local body = RUST[rng:NextInteger(1, #RUST)]
	local tilt = cf * CFrame.Angles(math.rad(rng:NextNumber(-4, 4)), 0, math.rad(rng:NextNumber(-6, 6)))
	part({ Name = "Body", Size = Vector3.new(6.5, 2.4, 13), CFrame = tilt * CFrame.new(0, 2, 0), Color = body, Material = Enum.Material.CorrodedMetal, Parent = m })
	part({ Name = "Cabin", Size = Vector3.new(5.8, 2.2, 6), CFrame = tilt * CFrame.new(0, 4.2, 1), Color = vary(body, rng, 0.15), Material = Enum.Material.CorrodedMetal, Parent = m })
	part({ Name = "Windows", Size = Vector3.new(5.9, 1.4, 6.1), CFrame = tilt * CFrame.new(0, 4.4, 1), Color = Color3.fromRGB(40, 45, 50), Material = Enum.Material.Glass, Transparency = 0.3, decor = true, Parent = m })
	for _, x in { -3, 3 } do
		for _, z in { -4.2, 4.2 } do
			if rng:NextNumber() < 0.8 then -- some wheels are long gone
				part({
					Name = "Wheel",
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(1.2, 2.8, 2.8),
					CFrame = tilt * CFrame.new(x, 1.2, z),
					Color = Color3.fromRGB(30, 30, 32),
					Material = Enum.Material.Rubber,
					decor = true,
					Parent = m,
				})
			end
		end
	end
end

local function barrel(parent: Instance, cf: CFrame, rng: Random, color: Color3, toxic: boolean)
	if toxic then
		local p = meshProp("toxicBarrel", parent, cf * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), 3.6)
		if rng:NextNumber() < 0.3 then
			light(p, Color3.fromRGB(120, 255, 60), 10, 1)
		end
		return
	end
	local m = model("Barrel", parent)
	local d, h = 2.6, 3.6
	if rng:NextNumber() < 0.3 then
		part({ Name = "Drum", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, d, d), CFrame = cf * CFrame.new(0, d / 2, 0), Color = color, Material = Enum.Material.CorrodedMetal, Parent = m })
	else
		column(cf, h, d, { Name = "Drum", Color = color, Material = Enum.Material.CorrodedMetal, Parent = m })
	end
end

local function tireStack(parent: Instance, cf: CFrame, rng: Random)
	local m = model("Tires", parent)
	local y = 0
	for _ = 1, rng:NextInteger(2, 4) do
		local offset = CFrame.new(rng:NextNumber(-0.3, 0.3), y, rng:NextNumber(-0.3, 0.3))
		column(cf * offset, 1.1, 3.2, { Name = "Tire", Color = Color3.fromRGB(28, 28, 30), Material = Enum.Material.Rubber, Parent = m })
		y += 1.1
	end
end

local function mesa(parent: Instance, cf: CFrame, rng: Random, color: Color3, material: Enum.Material)
	local m = model("RockPile", parent)
	local y = 0
	local w = rng:NextNumber(10, 14)
	for _ = 1, rng:NextInteger(2, 4) do
		local h = rng:NextNumber(4, 8)
		part({
			Name = "Layer",
			Size = Vector3.new(w, h, w * rng:NextNumber(0.7, 1)),
			CFrame = cf * CFrame.new(rng:NextNumber(-1, 1), y + h / 2, rng:NextNumber(-1, 1)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Color = vary(color, rng, 0.1),
			Material = material,
			Parent = m,
		})
		y += h
		w *= rng:NextNumber(0.6, 0.8)
	end
end

local function slab(parent: Instance, cf: CFrame, rng: Random)
	local m = model("Slab", parent)
	local tilt = cf * CFrame.Angles(math.rad(rng:NextNumber(-20, 20)), rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-12, 12)))
	part({ Name = "Concrete", Size = Vector3.new(rng:NextNumber(7, 11), 1.4, rng:NextNumber(5, 8)), CFrame = tilt * CFrame.new(0, 0.4, 0), Color = vary(Color3.fromRGB(150, 145, 135), rng, 0.1), Material = Enum.Material.Concrete, Parent = m })
	for i = 1, 3 do
		local from = (tilt * CFrame.new(-2 + i * 1.2, 0.8, 0)).Position
		rod(from, from + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(1.5, 3), rng:NextNumber(-1, 1)), 0.2, { Name = "Rebar", Color = Color3.fromRGB(120, 60, 40), Material = Enum.Material.CorrodedMetal, decor = true, Parent = m })
	end
end

local function deadShrub(parent: Instance, cf: CFrame, rng: Random, color: Color3)
	local base = cf.Position
	for i = 1, 4 do
		local dir = (cf * CFrame.Angles(0, math.rad(i * 90 + rng:NextNumber(-30, 30)), 0)).LookVector
		rod(base, base + dir * rng:NextNumber(0.8, 1.8) + Vector3.new(0, rng:NextNumber(1.2, 2.5), 0), 0.2, {
			Name = "Twig",
			Color = color,
			Material = Enum.Material.Wood,
			decor = true,
			Parent = parent,
		})
	end
end

local function buildWasteland(folder: Instance, ring: any, rng: Random)
	scatter(rng, ring, 40, { kind = "edge", radius = 7, onBank = true }, function(cf, r)
		mesa(folder, cf, r, Color3.fromRGB(160, 100, 65), Enum.Material.Sandstone)
	end)
	scatter(rng, ring, 18, { kind = "edge", radius = 7, depth = 4 }, function(cf, r)
		carWreck(folder, cf * CFrame.Angles(0, math.rad(r:NextNumber(70, 110)), 0), r)
	end)
	scatter(rng, ring, 18, { kind = "field", radius = 4 }, function(cf, r)
		for i = 1, r:NextInteger(2, 4) do
			local toxic = r:NextNumber() < 0.4
			local color = if toxic then Color3.fromRGB(205, 175, 40) else RUST[r:NextInteger(1, #RUST)]
			barrel(folder, cf * CFrame.new(i * 2.9 - 4, 0, r:NextNumber(-1, 1)), r, color, toxic)
		end
	end)
	scatter(rng, ring, 16, { kind = "field", radius = 2 }, function(cf, r)
		tireStack(folder, cf, r)
	end)
	scatter(rng, ring, 26, { kind = "field", radius = 5 }, function(cf, r)
		slab(folder, cf, r)
	end)
	scatter(rng, ring, 40, { kind = "field", radius = 2 }, function(cf, r)
		boulder(folder, cf, r, Color3.fromRGB(140, 105, 80), r:NextNumber(1.5, 4))
	end)
	scatter(rng, ring, 90, { kind = "field", radius = 1, overlap = true }, function(cf, r)
		deadShrub(folder, cf, r, Color3.fromRGB(95, 75, 55))
	end)
end

------------------------------------------------------------------------------
-- Ring 3: radioactive swamp

local SWAMP_WATER = Color3.fromRGB(70, 140, 55) -- murky toxic green
local WATER_TOP = 0.9 -- ankle deep: players and freaks wade through it

local function pool(parent: Instance, cf: CFrame, rng: Random, diameter: number)
	local m = model("Pool", parent)
	column(cf * CFrame.new(0, WATER_TOP - 0.25, 0), 0.25, diameter, {
		Name = "Water",
		Color = vary(SWAMP_WATER, rng, 0.1),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		Reflectance = 0.15,
		decor = true,
		Parent = m,
	})
	for _ = 1, math.floor(diameter / 6) do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0, diameter / 2 - 2)
		column(cf * CFrame.new(math.cos(a) * r, WATER_TOP, math.sin(a) * r), 0.08, rng:NextNumber(1.6, 3), {
			Name = "LilyPad",
			Color = vary(Color3.fromRGB(70, 140, 50), rng, 0.15),
			Material = Enum.Material.Grass,
			decor = true,
			Parent = m,
		})
	end
	-- A few glowing bubbles on the bigger pools.
	if diameter > 20 then
		for _ = 1, 3 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(0, diameter / 2 - 3)
			part({
				Name = "Bubble",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * rng:NextNumber(0.5, 1),
				CFrame = cf * CFrame.new(math.cos(a) * r, WATER_TOP, math.sin(a) * r),
				Color = Color3.fromRGB(170, 255, 90),
				Material = Enum.Material.Neon,
				decor = true,
				Parent = m,
			})
		end
	end
end

local function swampTree(parent: Instance, cf: CFrame, rng: Random)
	meshProp("swampTree", parent, cf, rng:NextNumber(16, 26))
end

local function reeds(parent: Instance, cf: CFrame, rng: Random)
	local glowing = rng:NextNumber() < 0.35
	for _ = 1, rng:NextInteger(4, 7) do
		local base = cf * CFrame.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2))
		local h = rng:NextNumber(3, 5.5)
		local top = (base * CFrame.Angles(math.rad(rng:NextNumber(-10, 10)), 0, math.rad(rng:NextNumber(-10, 10))) * CFrame.new(0, h, 0)).Position
		rod(base.Position, top, 0.18, { Name = "Reed", Color = Color3.fromRGB(95, 130, 60), Material = Enum.Material.Grass, decor = true, Parent = parent })
		if rng:NextNumber() < 0.6 then
			local tip = top + (top - base.Position).Unit * 0.6
			rod(top - (top - base.Position).Unit * 0.6, tip, 0.45, {
				Name = "Cattail",
				Color = if glowing then Color3.fromRGB(160, 255, 80) else Color3.fromRGB(100, 70, 45),
				Material = if glowing then Enum.Material.Neon else Enum.Material.Fabric,
				decor = true,
				Parent = parent,
			})
		end
	end
end

local function mossyLog(parent: Instance, cf: CFrame, rng: Random)
	local m = model("Log", parent)
	local len, d = rng:NextNumber(9, 14), rng:NextNumber(2.2, 3)
	local lying = cf * CFrame.new(0, d / 2 - 0.3, 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-3, 3)))
	part({ Name = "Log", Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, d, d), CFrame = lying, Color = vary(Color3.fromRGB(85, 65, 50), rng, 0.1), Material = Enum.Material.Wood, Parent = m })
	part({ Name = "Moss", Size = Vector3.new(len * 0.7, 0.3, d * 0.6), CFrame = lying * CFrame.new(0, d / 2 - 0.05, 0), Color = Color3.fromRGB(90, 140, 60), Material = Enum.Material.Grass, decor = true, Parent = m })
end

local function glowShroom(parent: Instance, cf: CFrame, rng: Random, cap: Color3, scale: number, lit: boolean)
	for i = 1, rng:NextInteger(2, 4) do
		local base = cf * CFrame.new(rng:NextNumber(-1.5, 1.5) * scale, 0, rng:NextNumber(-1.5, 1.5) * scale)
		local h = rng:NextNumber(1, 2.5) * scale
		column(base, h, 0.35 * scale, { Name = "Stem", Color = Color3.fromRGB(225, 220, 200), Material = Enum.Material.SmoothPlastic, decor = true, Parent = parent })
		local capPart = blob({
			Name = "Cap",
			Size = Vector3.new(1.6, 0.7, 1.6) * scale * rng:NextNumber(0.8, 1.2),
			CFrame = base * CFrame.new(0, h, 0),
			Color = cap,
			Material = Enum.Material.Neon,
			decor = true,
			Parent = parent,
		})
		if lit and i == 1 then
			light(capPart, cap, 10 * scale, 1.2)
		end
	end
end

local function buildSwamp(folder: Instance, ring: any, rng: Random)
	-- Pools first, overlapping freely so they merge into bigger bogs. They're
	-- walk-through; only their middles are kept clear of other props, so
	-- trees and reeds grow along the banks.
	for _ = 1, 90 do
		local d = rng:NextNumber(16, 44)
		local cf = findSpot(rng, ring, { kind = "field", radius = math.max(d / 2 - 8, 0), overlap = true })
		if cf then
			pool(folder, cf, rng, d)
		end
	end
	scatter(rng, ring, 40, { kind = "edge", radius = 5, onBank = true }, function(cf, r)
		swampTree(folder, cf, r)
	end)
	scatter(rng, ring, 10, { kind = "field", radius = 5 }, function(cf, r)
		swampTree(folder, cf, r)
	end)
	scatter(rng, ring, 18, { kind = "field", radius = 5 }, function(cf, r)
		mossyLog(folder, cf, r)
	end)
	scatter(rng, ring, 70, { kind = "field", radius = 1.5, overlap = true }, function(cf, r)
		reeds(folder, cf, r)
	end)
	scatter(rng, ring, 30, { kind = "field", radius = 2, overlap = true }, function(cf, r)
		glowShroom(folder, cf, r, Color3.fromRGB(150, 255, 90), 0.8, r:NextNumber() < 0.25)
	end)
end

------------------------------------------------------------------------------
-- Ring 4: cavern

local CAVE_ROCK = Color3.fromRGB(70, 66, 80)
local CRYSTALS = { Color3.fromRGB(175, 95, 255), Color3.fromRGB(80, 225, 255), Color3.fromRGB(255, 110, 210) }

-- Big rock masses against the walls, so the ring reads as a cave rather than
-- a walled field.
local function caveWall(parent: Instance, cf: CFrame, rng: Random)
	local m = model("CaveRock", parent)
	local h = rng:NextNumber(26, 48)
	blob({
		Name = "Rock",
		Size = Vector3.new(rng:NextNumber(18, 28), h, rng:NextNumber(10, 14)),
		CFrame = cf * CFrame.new(0, h * 0.35, 0),
		Color = vary(CAVE_ROCK, rng, 0.15),
		Material = Enum.Material.Slate,
		Parent = m,
	})
	part({
		Name = "Chunk",
		Size = Vector3.new(rng:NextNumber(8, 12), rng:NextNumber(8, 14), rng:NextNumber(6, 9)),
		CFrame = cf * CFrame.new(rng:NextNumber(-6, 6), 3, -2) * CFrame.Angles(math.rad(rng:NextNumber(-15, 15)), rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-15, 15))),
		Color = vary(CAVE_ROCK, rng, 0.2),
		Material = Enum.Material.Rock,
		Parent = m,
	})
end

local function stalagmite(parent: Instance, cf: CFrame, rng: Random)
	meshProp("stalagmite", parent, cf, rng:NextNumber(6, 18))
end

local function crystals(parent: Instance, cf: CFrame, rng: Random, lit: boolean)
	local p = meshProp("crystals", parent, cf, rng:NextNumber(5, 10))
	if lit then
		light(p, CRYSTALS[rng:NextInteger(1, #CRYSTALS)], 22, 2)
	end
end

local function caveShrooms(parent: Instance, cf: CFrame, rng: Random, lit: boolean)
	local p = meshProp("mushrooms", parent, cf, rng:NextNumber(3, 6), true)
	if lit then
		light(p, Color3.fromRGB(90, 210, 255), 14, 1.5)
	end
end

local function arch(parent: Instance, cf: CFrame, rng: Random, span: number, height: number)
	local m = model("Arch", parent)
	local color = vary(CAVE_ROCK, rng, 0.1)
	local thickness = 6
	local radius = span / 2
	local legHeight = height - radius
	for _, x in { -radius, radius } do
		part({ Name = "Leg", Size = Vector3.new(thickness, legHeight, thickness), CFrame = cf * CFrame.new(x, legHeight / 2, 0), Color = color, Material = Enum.Material.Slate, Parent = m })
	end
	local segments = 8
	for i = 1, segments do
		local a1 = math.pi * (i - 1) / segments
		local a2 = math.pi * i / segments
		local p1 = cf * CFrame.new(-math.cos(a1) * radius, legHeight + math.sin(a1) * radius, 0)
		local p2 = cf * CFrame.new(-math.cos(a2) * radius, legHeight + math.sin(a2) * radius, 0)
		local mid = (p1.Position + p2.Position) / 2
		part({
			Name = "Span",
			Size = Vector3.new(thickness, thickness, (p2.Position - p1.Position).Magnitude + 1),
			CFrame = CFrame.lookAt(mid, p2.Position, cf.LookVector),
			Color = color,
			Material = Enum.Material.Slate,
			Parent = m,
		})
	end
	-- Stalactites hanging from the top.
	for _ = 1, 3 do
		local x = rng:NextNumber(-radius * 0.5, radius * 0.5)
		local top = legHeight + math.sqrt(radius * radius - x * x) - thickness / 2
		local h = rng:NextNumber(3, 6)
		column(cf * CFrame.new(x, top - h, 0), h, rng:NextNumber(1, 1.8), { Name = "Stalactite", Color = color, Material = Enum.Material.Rock, decor = true, Parent = m })
	end
end

local function buildCavern(folder: Instance, ring: any, rng: Random)
	scatter(rng, ring, 90, { kind = "edge", radius = 8, depth = 6, overlap = true, onBank = true }, function(cf, r)
		caveWall(folder, cf, r)
	end)
	-- Arches over the four lanes, so players run under them on the way through.
	local mid = (ring.inner + ring.outer) / 2
	for _, angle in World.doorAngles do
		local p = pointAt(mid, angle)
		local cf = CFrame.lookAt(p, Vector3.new(World.center.X, p.Y, World.center.Z))
		arch(folder, cf, rng, World.doorWidth + 20, 40)
	end
	scatter(rng, ring, 6, { kind = "field", radius = 14 }, function(cf, r)
		arch(folder, cf * CFrame.Angles(0, math.rad(90), 0), r, r:NextNumber(20, 30), r:NextNumber(26, 36))
	end)
	scatter(rng, ring, 55, { kind = "field", radius = 3 }, function(cf, r)
		stalagmite(folder, cf, r)
	end)
	local lit = 0
	scatter(rng, ring, 60, { kind = "field", radius = 2.5 }, function(cf, r)
		lit += 1
		crystals(folder, cf, r, lit % 2 == 0)
	end)
	scatter(rng, ring, 70, { kind = "field", radius = 2, overlap = true }, function(cf, r)
		caveShrooms(folder, cf, r, r:NextNumber() < 0.3)
	end)
end

------------------------------------------------------------------------------
-- Ring 5: chemical plant

local PLANT_METAL = Color3.fromRGB(175, 180, 185)
local TOXIC = Color3.fromRGB(130, 255, 60)

local function tank(parent: Instance, cf: CFrame, rng: Random)
	meshProp("chemicalTank", parent, cf, rng:NextNumber(18, 30))
end

local function smokestack(parent: Instance, cf: CFrame, rng: Random)
	local m = model("Smokestack", parent)
	local h = rng:NextNumber(55, 75)
	local d = rng:NextNumber(7, 9)
	local bands = 5
	for i = 0, bands - 1 do
		column(cf * CFrame.new(0, h * i / bands, 0), h / bands, d * (1 - i * 0.05), {
			Name = "Section",
			Color = if i % 2 == 0 then Color3.fromRGB(190, 60, 50) else Color3.fromRGB(225, 225, 220),
			Material = Enum.Material.Concrete,
			Parent = m,
		})
	end
	local top = column(cf * CFrame.new(0, h, 0), 1, d * 0.8, { Name = "Rim", Color = Color3.fromRGB(40, 40, 40), Material = Enum.Material.Metal, decor = true, Parent = m })
	local attachment = Instance.new("Attachment")
	attachment.Parent = top
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(170, 185, 120), Color3.fromRGB(110, 115, 100))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 18) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(6, 9)
	smoke.Rate = 3
	smoke.Speed = NumberRange.new(5, 8)
	smoke.SpreadAngle = Vector2.new(12, 12)
	smoke.Acceleration = Vector3.new(2, 1, 0)
	smoke.LightInfluence = 1
	smoke.Parent = attachment
end

-- A straight run of two pipes on supports, along the cf's X axis.
local function pipeRun(parent: Instance, cf: CFrame, rng: Random)
	local m = model("Pipes", parent)
	local len = rng:NextNumber(28, 44)
	local colors = { Color3.fromRGB(205, 175, 40), Color3.fromRGB(80, 140, 90), Color3.fromRGB(150, 155, 160) }
	for i, y in { 7, 10 } do
		local a = (cf * CFrame.new(-len / 2, y, 0)).Position
		local b = (cf * CFrame.new(len / 2, y, 0)).Position
		rod(a, b, if i == 1 then 2.4 else 1.6, { Name = "Pipe", Color = colors[rng:NextInteger(1, #colors)], Material = Enum.Material.Metal, Parent = m })
	end
	for x = -len / 2 + 2, len / 2 - 2, 10 do
		part({ Name = "Support", Size = Vector3.new(0.8, 11, 3), CFrame = cf * CFrame.new(x, 5.5, 0), Color = Color3.fromRGB(70, 72, 76), Material = Enum.Material.Metal, Parent = m })
	end
end

local function vat(parent: Instance, cf: CFrame, rng: Random)
	local m = model("Vat", parent)
	local d = rng:NextNumber(8, 12)
	part({
		Name = "Floor",
		Size = Vector3.new(d + 6, 0.2, d + 6),
		CFrame = cf * CFrame.new(0, 0.1, 0),
		Color = Color3.fromRGB(120, 124, 128),
		Material = Enum.Material.DiamondPlate,
		Parent = m,
	})
	column(cf, 4, d, { Name = "Wall", Color = PLANT_METAL, Material = Enum.Material.Metal, Parent = m })
	local liquid = column(cf * CFrame.new(0, 3.6, 0), 0.3, d - 1, { Name = "Liquid", Color = TOXIC, Material = Enum.Material.Neon, Transparency = 0.1, decor = true, Parent = m })
	light(liquid, TOXIC, 18, 2)
	for _ = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0, d / 2 - 1.5)
		part({ Name = "Bubble", Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(0.6, 1.2), CFrame = cf * CFrame.new(math.cos(a) * r, 3.9, math.sin(a) * r), Color = Color3.fromRGB(200, 255, 150), Material = Enum.Material.Neon, decor = true, Parent = m })
	end
end

local function container(parent: Instance, cf: CFrame, rng: Random)
	local m = model("Container", parent)
	local paints = { Color3.fromRGB(190, 95, 50), Color3.fromRGB(60, 100, 150), Color3.fromRGB(80, 120, 80), Color3.fromRGB(170, 160, 150) }
	local stacked = rng:NextNumber() < 0.4
	for level = 0, if stacked then 1 else 0 do
		local paint = paints[rng:NextInteger(1, #paints)]
		local body = cf * CFrame.new(0, 4.25 + level * 8.5, 0) * CFrame.Angles(0, math.rad(level * rng:NextNumber(-8, 8)), 0)
		part({ Name = "Body", Size = Vector3.new(20, 8.5, 8), CFrame = body, Color = paint, Material = Enum.Material.CorrodedMetal, Parent = m })
		for _, x in { -10, 10 } do
			part({ Name = "End", Size = Vector3.new(0.3, 8.6, 8.1), CFrame = body * CFrame.new(x, 0, 0), Color = vary(paint, rng, 0.3), Material = Enum.Material.Metal, decor = true, Parent = m })
		end
	end
end

local function buildChemicalPlant(folder: Instance, ring: any, rng: Random)
	scatter(rng, ring, 7, { kind = "edge", radius = 5 }, function(cf, r)
		smokestack(folder, cf, r)
	end)
	scatter(rng, ring, 30, { kind = "edge", radius = 10 }, function(cf, r)
		tank(folder, cf, r)
	end)
	scatter(rng, ring, 24, { kind = "edge", radius = 11, depth = 4.5 }, function(cf, r)
		container(folder, cf, r)
	end)
	scatter(rng, ring, 28, { kind = "edge", radius = 18, depth = 2 }, function(cf, r)
		pipeRun(folder, cf, r)
	end)
	scatter(rng, ring, 18, { kind = "field", radius = 9 }, function(cf, r)
		vat(folder, cf, r)
	end)
	scatter(rng, ring, 26, { kind = "field", radius = 4 }, function(cf, r)
		for i = 1, r:NextInteger(2, 5) do
			local toxic = r:NextNumber() < 0.5
			local color = if toxic then Color3.fromRGB(230, 195, 35) else Color3.fromRGB(50, 90, 160)
			barrel(folder, cf * CFrame.new((i - 3) * 2.9, 0, r:NextNumber(-1.5, 1.5)), r, color, toxic)
		end
	end)
end

------------------------------------------------------------------------------
-- Safe zone: radioactive lab

local HAZARD_YELLOW = Color3.fromRGB(245, 200, 30)
local HAZARD_BLACK = Color3.fromRGB(30, 30, 32)

-- A ring of alternating yellow and black floor stripes at `radius`.
local function hazardRing(parent: Instance, radius: number, width: number, count: number)
	for i = 0, count - 1 do
		local a1, a2 = 360 * i / count, 360 * (i + 1) / count
		local p1, p2 = pointAt(radius, a1), pointAt(radius, a2)
		local mid = (p1 + p2) / 2 + Vector3.new(0, 0.2, 0)
		part({
			Name = "Stripe",
			Size = Vector3.new(width, 0.1, (p2 - p1).Magnitude + 0.05),
			CFrame = CFrame.lookAt(mid, mid + (p2 - p1).Unit),
			Color = if i % 2 == 0 then HAZARD_YELLOW else HAZARD_BLACK,
			Material = Enum.Material.SmoothPlastic,
			decor = true,
			Parent = parent,
		})
	end
end

local function labVat(parent: Instance, cf: CFrame)
	local m = model("GlowVat", parent)
	local d, h = 6, 11
	column(cf, 1.2, d + 1.5, { Name = "Base", Color = Color3.fromRGB(70, 75, 80), Material = Enum.Material.DiamondPlate, Parent = m })
	column(cf * CFrame.new(0, 1.2, 0), h, d, { Name = "Glass", Color = Color3.fromRGB(200, 240, 220), Material = Enum.Material.Glass, Transparency = 0.6, CastShadow = false, Parent = m })
	local liquid = column(cf * CFrame.new(0, 1.3, 0), h * 0.75, d - 0.8, { Name = "Liquid", Color = TOXIC, Material = Enum.Material.Neon, Transparency = 0.2, decor = true, Parent = m })
	column(cf * CFrame.new(0, 1.2 + h, 0), 1, d + 1, { Name = "Cap", Color = Color3.fromRGB(70, 75, 80), Material = Enum.Material.Metal, Parent = m })
	light(liquid, TOXIC, 20, 2)
	return m
end

local function buildLab(folder: Instance)
	local shopRadius = World.zones[1].outerRadius
	hazardRing(folder, shopRadius, 2, 64)
	hazardRing(folder, World.safeRadius - THICK / 2 - 2, 3, 120)

	-- Glowing vats and pipes in the gaps between farm plots (the diagonals),
	-- piping into the barrier.
	for _, angle in { 45, 135, 225, 315 } do
		local plotRadius = World.farm.plotRadius
		for _, side in { -1, 1 } do
			local p = pointAt(plotRadius + side * 8, angle)
			local cf = CFrame.lookAt(p, Vector3.new(World.center.X, p.Y, World.center.Z))
			labVat(folder, cf)
		end
		local from = pointAt(plotRadius + 8, angle) + Vector3.new(0, 13.2, 0)
		local to = pointAt(World.safeRadius - THICK / 2 - 0.5, angle) + Vector3.new(0, 13.2, 0)
		rod(from, to, 1.6, { Name = "Pipe", Color = Color3.fromRGB(150, 155, 160), Material = Enum.Material.Metal, Parent = folder })
		rod(pointAt(plotRadius - 8, angle) + Vector3.new(0, 13.2, 0), from, 1.6, { Name = "Pipe", Color = Color3.fromRGB(150, 155, 160), Material = Enum.Material.Metal, Parent = folder })
	end
end

------------------------------------------------------------------------------
-- Terrain: flat ground at ground level (freaks stand at a fixed height), with
-- patches of a second material and banks sloping up against the walls.

local Terrain = workspace.Terrain

-- Terrain is stored in 4-stud cells, each with a material and how full it is.
-- On flat ground the surface sits level with the top of the uppermost cell
-- when that cell is half full (a full one puts it half a cell higher). So the
-- ground is written cell by cell, with a half-full top layer ending at ground
-- level: that's where freaks stand.
local CELL = 4
local GROUND_LAYERS = 3
local WRITE_CHUNK = 64 -- cells per side in each WriteVoxels call

-- Writes the ground out to `radius`, with each column's material from
-- `materialAt(x, z)` (Air for none).
local function writeGround(radius: number, materialAt: (number, number) -> Enum.Material)
	assert(GROUND_Y % CELL == 0, "ground level must be on the terrain grid")
	local cells = math.ceil(radius / CELL)
	for cx = -cells, cells - 1, WRITE_CHUNK do
		for cz = -cells, cells - 1, WRITE_CHUNK do
			local nx = math.min(WRITE_CHUNK, cells - cx)
			local nz = math.min(WRITE_CHUNK, cells - cz)
			local columns = {}
			for ix = 1, nx do
				columns[ix] = {}
				for iz = 1, nz do
					columns[ix][iz] = materialAt(World.center.X + (cx + ix - 0.5) * CELL, World.center.Z + (cz + iz - 0.5) * CELL)
				end
			end
			local materials, occupancy = {}, {}
			for ix = 1, nx do
				materials[ix], occupancy[ix] = {}, {}
				for iy = 1, GROUND_LAYERS do
					local mats, occs = {}, {}
					for iz = 1, nz do
						local m = columns[ix][iz]
						mats[iz] = m
						occs[iz] = if m == Enum.Material.Air then 0 elseif iy == GROUND_LAYERS then 0.5 else 1
					end
					materials[ix][iy], occupancy[ix][iy] = mats, occs
				end
			end
			local low = Vector3.new(World.center.X + cx * CELL, GROUND_Y - GROUND_LAYERS * CELL, World.center.Z + cz * CELL)
			Terrain:WriteVoxels(Region3.new(low, low + Vector3.new(nx, GROUND_LAYERS, nz) * CELL), CELL, materials, occupancy)
		end
	end
end

local function buildTerrain(rings: { any })
	Terrain:Clear()
	for tier, biome in Biomes do
		if tier > 0 then
			Terrain:SetMaterialColor(biome.ground.material, biome.ground.color)
			if biome.bank then
				Terrain:SetMaterialColor(biome.bank.material, biome.bank.color)
			end
			for _, surface in biome.patches or {} do
				Terrain:SetMaterialColor(surface.material, surface.color)
			end
		end
	end

	-- Patches: a few overlapping discs each, for a less regular outline. Each
	-- cell they cover is marked here, then the ground is written in one pass.
	local patchAt: { [number]: Enum.Material } = {}
	local cells = math.ceil((World.safeRadius + World.ringWidth * World.ringCount + CELL) / CELL)
	local function key(ix: number, iz: number): number
		return (ix + cells) * (cells * 2 + 1) + (iz + cells)
	end
	for _, ring in rings do
		local biome = Biomes[ring.tier]
		local rng = Random.new(2000 + ring.tier)
		local area = math.pi * (ring.outer ^ 2 - ring.inner ^ 2)
		for _ = 1, math.floor(area / 2500) do
			local patch = biome.patches[rng:NextInteger(1, #biome.patches)]
			local size = rng:NextNumber(8, 20)
			local center = pointAt(rng:NextNumber(ring.inner + size * 1.6, ring.outer - size * 1.6), rng:NextNumber(0, 360))
			for _ = 1, rng:NextInteger(2, 3) do
				local c = center + Vector3.new(rng:NextNumber(-size, size), 0, rng:NextNumber(-size, size)) * 0.6
				local radius = size * rng:NextNumber(0.5, 0.8)
				for ix = math.floor((c.X - radius) / CELL), math.floor((c.X + radius) / CELL) do
					for iz = math.floor((c.Z - radius) / CELL), math.floor((c.Z + radius) / CELL) do
						local x, z = (ix + 0.5) * CELL, (iz + 0.5) * CELL
						local fromCenter = Vector2.new(x - World.center.X, z - World.center.Z).Magnitude
						if (Vector2.new(x - c.X, z - c.Z)).Magnitude <= radius and fromCenter > ring.inner and fromCenter < ring.outer then
							patchAt[key(ix, iz)] = patch.material
						end
					end
				end
			end
		end
	end

	-- Ground: each ring in its biome's material, and the safe zone's terrain
	-- (hidden under the lab floor) in concrete.
	local outermost = rings[#rings].outer
	writeGround(outermost + CELL, function(x, z)
		local r = Vector2.new(x - World.center.X, z - World.center.Z).Magnitude
		if r > outermost + CELL then
			return Enum.Material.Air
		elseif r < World.safeRadius then
			return Enum.Material.Concrete
		end
		local patch = patchAt[key(math.floor(x / CELL), math.floor(z / CELL))]
		if patch then
			return patch
		end
		local tier = math.clamp(math.floor((r - World.safeRadius) / World.ringWidth) + 1, 1, #rings)
		return Biomes[rings[tier].tier].ground.material
	end)

	for _, ring in rings do
		local biome = Biomes[ring.tier]
		local rng = Random.new(2000 + ring.tier)

		-- Banks along both walls: wedges rising toward the wall with lumps on
		-- top, gapped at the lanes so every doorway stays level.
		if biome.bank then
			for _, side in { { face = ring.inner + THICK / 2, into = 1 }, { face = ring.outer - THICK / 2, into = -1 } } do
				-- Terrain is stored in 4-stud cells: starting 2 studs off the face
				-- keeps a bank from showing through under the wall on the other side.
				local start = side.face + side.into * 2
				local step = math.deg(10 / start)
				for angle = 0, 360 - step, step do
					local at = pointAt(start, angle)
					if not laneClear(at, 8) then
						continue
					end
					local dir = dirFromAngle(angle)
					local h = 7 + 5 * math.noise(angle / 6, ring.tier * 3.7 + side.into) + rng:NextNumber(-1, 1)
					-- A wedge's slope faces its front (-Z): point the front into the ring.
					-- Its base starts 2 studs down, inside the ground, so it joins it smoothly.
					local mid = at + dir * side.into * BANK_DEPTH / 2 + Vector3.new(0, h / 2 - 2, 0)
					Terrain:FillWedge(CFrame.lookAt(mid, mid + dir * side.into), Vector3.new(12, h, BANK_DEPTH), biome.bank.material)
					if rng:NextNumber() < 0.5 then
						local fromFace = rng:NextNumber(4, 8)
						Terrain:FillBall(at + dir * side.into * fromFace + Vector3.new(0, h * 0.45, 0), rng:NextNumber(3, fromFace), biome.bank.material)
					end
				end
			end
		end
	end
end

------------------------------------------------------------------------------
-- Wall cladding: each side of a tier wall dressed in its ring's material.

local function buildCladding(map: Instance, folder: Instance)
	for _, wall in World.walls do
		local wallModel = map:FindFirstChild(wall.name)
		if not wallModel or wall.doorKind == "Opening" then
			continue -- the safe-zone barrier is a force field, left as it is
		end
		for _, segment in wallModel:GetChildren() do
			if not segment:IsA("BasePart") or segment.Name ~= "Segment" then
				continue
			end
			for _, sign in { -1, 1 } do
				-- A segment's X axis points across the wall.
				local outward = (segment.CFrame.RightVector * sign):Dot(segment.Position - World.center) > 0
				local tier
				for _, zone in World.zones do
					if zone.tier and (if outward then zone.innerRadius else zone.outerRadius) == wall.radius then
						tier = zone.tier
					end
				end
				local biome = tier and Biomes[tier]
				if biome and biome.wall then
					part({
						Name = "Cladding",
						Size = Vector3.new(0.4, segment.Size.Y, segment.Size.Z),
						CFrame = segment.CFrame * CFrame.new(sign * (THICK / 2 + 0.2), 0, 0),
						Color = biome.wall.color,
						Material = biome.wall.material,
						decor = true,
						Parent = folder,
					})
				end
			end
		end
	end
end

------------------------------------------------------------------------------

local map = workspace:FindFirstChild("Map")
assert(map, "build the map first (tools/BuildMap.luau)")
local existing = map:FindFirstChild("Biomes")
if existing then
	existing:Destroy()
end
local biomes = Instance.new("Folder")
biomes.Name = "Biomes"

local lab = Instance.new("Folder")
lab.Name = "Lab"
lab.Parent = biomes
buildLab(lab)

local rings = {}
for _, zone in World.zones do
	if zone.tier then
		table.insert(rings, {
			name = zone.name,
			tier = zone.tier,
			inner = zone.innerRadius,
			outer = zone.outerRadius,
			bankDepth = if Biomes[zone.tier].bank then BANK_DEPTH else 0,
			placed = {},
		})
	end
end
buildTerrain(rings)

local walls = Instance.new("Folder")
walls.Name = "Walls"
walls.Parent = biomes
buildCladding(map, walls)

local builders = { buildDryField, buildWasteland, buildSwamp, buildCavern, buildChemicalPlant }
for _, ring in rings do
	if builders[ring.tier] then
		local folder = Instance.new("Folder")
		folder.Name = ring.name
		folder.Parent = biomes
		builders[ring.tier](folder, ring, Random.new(1000 + ring.tier))
	end
end

biomes.Parent = map

local counts = {}
for _, folder in biomes:GetChildren() do
	local parts, lights = 0, 0
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		elseif d:IsA("PointLight") then
			lights += 1
		end
	end
	table.insert(counts, ("%s: %d parts, %d lights"):format(folder.Name, parts, lights))
end
return "Built Workspace.Map.Biomes\n" .. table.concat(counts, "\n")
