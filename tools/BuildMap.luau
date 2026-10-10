--[[
	Map builder (Milestone 1; ground looks from Config/Biomes since Milestone 10).

	Not a game script: run it in Studio's edit DataModel (via the Studio MCP
	execute_luau tool or the command bar) after Rojo has synced
	ReplicatedStorage.Shared.Config.World. It deletes and rebuilds Workspace.Map
	from the config, so re-run it whenever World.luau changes, then run
	tools/BuildBiomes.luau to put the biome props back. Save the place
	afterwards to keep the result.
]]

-- Require a clone so edits to World.luau are picked up without restarting Studio.
local worldModule = game:GetService("ReplicatedStorage").Shared.Config.World:Clone()
local World = require(worldModule) :: any
worldModule:Destroy()

local GROUND_Y = World.groundY

local function dirFromAngle(degrees: number): Vector3
	local a = math.rad(degrees)
	return Vector3.new(math.sin(a), 0, -math.cos(a))
end

local function pointAt(radius: number, degrees: number, y: number): Vector3
	return World.center + dirFromAngle(degrees) * radius + Vector3.new(0, y, 0)
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function label(parent: Instance, text: string, offsetY: number, color: Color3?, maxDistance: number?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(200, 50)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = maxDistance or 150
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.3
	t.Parent = gui
	gui.Parent = parent
end

-- A flat disc whose top surface sits at topY.
local function disc(name: string, radius: number, topY: number, color: Color3, material: Enum.Material, parent: Instance)
	local thickness = 1
	part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = CFrame.new(World.center + Vector3.new(0, topY - thickness / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
		Parent = parent,
	})
end

-- One straight wall slab between two angles on a circle of the given radius.
local function chordSlab(radius: number, a1: number, a2: number, height: number, thickness: number, extend: number): (CFrame, Vector3)
	local p1 = pointAt(radius, a1, 0)
	local p2 = pointAt(radius, a2, 0)
	local mid = (p1 + p2) / 2 + Vector3.new(0, GROUND_Y + height / 2, 0)
	local length = (p2 - p1).Magnitude + extend
	return CFrame.lookAt(mid, mid + (p2 - p1).Unit), Vector3.new(thickness, height, length)
end

-- The safe zone's ground: the lab floor, with a steel-plate shop floor on top.
-- The rings' ground is terrain, built by tools/BuildBiomes.luau.
local biomesModule = game:GetService("ReplicatedStorage").Shared.Config.Biomes:Clone()
local Biomes = require(biomesModule) :: any
biomesModule:Destroy()

local function buildGround(map: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Ground"
	folder.Parent = map
	-- Tops sit just above ground level (and the terrain), the shop's above the
	-- inner ring's so they never z-fight; the plots and shop are built on them.
	local lab = Biomes[0].ground
	disc("InnerRing", World.safeRadius, GROUND_Y + 0.02 * (#World.zones - 1), lab.color, lab.material, folder)
	disc("Shop", World.zones[1].outerRadius, GROUND_Y + 0.02 * #World.zones, Color3.fromRGB(120, 126, 130), Enum.Material.DiamondPlate, folder)
end

local function buildWall(map: Instance, wall: any)
	local model = Instance.new("Model")
	model.Name = wall.name
	model:SetAttribute("Radius", wall.radius)
	model:SetAttribute("DoorKind", wall.doorKind)
	if wall.tier then
		model:SetAttribute("RequiredTier", wall.tier)
	end
	model.Parent = map

	local thickness = World.wallThickness
	local overlap = 1 -- each slab pokes past its neighbours so the joints have no gaps

	-- Angular half-width of each door gap, measured as a chord at the wall's radius.
	local hasDoors = wall.doorKind ~= "None"
	local doorHalf = hasDoors and math.deg(math.asin((World.doorWidth / 2 + overlap / 2) / wall.radius)) or 0

	-- Arcs of solid wall between consecutive doors (or the full circle).
	local arcs = {}
	if hasDoors then
		local angles = table.clone(World.doorAngles)
		table.sort(angles)
		for i, a in angles do
			local nextA = angles[i % #angles + 1]
			if nextA <= a then
				nextA += 360
			end
			table.insert(arcs, { a + doorHalf, nextA - doorHalf })
		end
	else
		table.insert(arcs, { 0, 360 })
	end

	local maxSlab = 16
	local index = 0
	for _, arc in arcs do
		local arcLength = math.rad(arc[2] - arc[1]) * wall.radius
		local count = math.max(1, math.ceil(arcLength / maxSlab))
		local step = (arc[2] - arc[1]) / count
		for s = 0, count - 1 do
			local a1 = arc[1] + step * s
			local a2 = a1 + step
			-- Don't extend into the door gap at the arc's ends.
			local extend = overlap
			if hasDoors and (s == 0 or s == count - 1) then
				extend = count == 1 and 0 or overlap / 2
			end
			local cf, size = chordSlab(wall.radius, a1, a2, wall.height, thickness, extend)
			if hasDoors and s == 0 and count > 1 then
				cf *= CFrame.new(0, 0, -overlap / 4) -- shift the extension away from the door
			elseif hasDoors and s == count - 1 and count > 1 then
				cf *= CFrame.new(0, 0, overlap / 4)
			end
			index += 1
			part({
				Name = "Segment",
				CFrame = cf,
				Size = size,
				Color = Color3.fromRGB(110, 110, 120),
				Material = Enum.Material.Concrete,
				Parent = model,
			})
		end
	end

	if wall.doorKind == "TierDoor" then
		local doors = Instance.new("Folder")
		doors.Name = "Doors"
		doors.Parent = model
		local names = { [0] = "North", [90] = "East", [180] = "South", [270] = "West" }
		for _, a in World.doorAngles do
			local cf, size = chordSlab(wall.radius, a - doorHalf, a + doorHalf, wall.height, thickness + 1, overlap)
			local door = part({
				Name = names[a] or ("Door" .. a),
				CFrame = cf,
				Size = size,
				Color = Color3.fromRGB(220, 60, 60),
				Material = Enum.Material.Neon,
				Transparency = 0.35,
				Parent = doors,
			})
			door:SetAttribute("RequiredTier", wall.tier)
			door:SetAttribute("Angle", a)
			door:AddTag("TierDoor")
			label(door, ("Tier %d — Locked"):format(wall.tier), -wall.height / 2 + 12, Color3.fromRGB(255, 120, 120))
		end
	end
end

local wheelModule = game:GetService("ReplicatedStorage").Shared.Config.Wheel:Clone()
local Wheel = require(wheelModule) :: any
wheelModule:Destroy()

-- A flat triangle a, b, c made of two wedges, `thickness` thick, lying on
-- the plane and offset toward `normal`.
local function triangle(parent: Instance, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color3, name: string)
	local thickness = 0.1
	-- Use the longest edge as the base, from b to c, with a opposite it.
	local ab, ac, bc = (b - a).Magnitude, (c - a).Magnitude, (c - b).Magnitude
	if ab > ac and ab > bc then
		a, c = c, a
	elseif ac > bc and ac > ab then
		a, b = b, a
	end
	local edge = (c - b).Unit
	local foot = b + edge * (a - b):Dot(edge) -- a projected onto the base
	local up = (a - foot).Unit
	local height = (a - foot).Magnitude
	-- Two right triangles, each with its right angle at the foot.
	for _, corner in { b, c } do
		local length = (foot - corner).Magnitude
		if length > 0.01 then
			-- A wedge's cross-section has its right angle at bottom-back (+Z)
			-- and its point at bottom-front (-Z): the foot goes at the back,
			-- the corner at the front, the apex at the top.
			local back = (foot - corner).Unit
			local center = (corner + foot) / 2 + up * height / 2 + normal * thickness / 2
			local wedge = Instance.new("WedgePart")
			wedge.Name = name
			wedge.Anchored = true
			wedge.CanCollide = false
			wedge.CastShadow = false
			wedge.Material = Enum.Material.SmoothPlastic
			wedge.Color = color
			wedge.Size = Vector3.new(thickness, height, length)
			wedge.CFrame = CFrame.fromMatrix(center, up:Cross(back), up, back)
			wedge.Parent = parent
		end
	end
end

local function buildShop(map: Instance)
	local shop = Instance.new("Model")
	shop.Name = "Shop"
	shop.Parent = map
	local floorY = GROUND_Y + 0.02 * #World.zones

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "ShopSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(World.center + Vector3.new(0, floorY + 0.5, 0))
	spawn.Color = Color3.fromRGB(240, 240, 240)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = shop

	-- Counters sit on the diagonals so the N/E/S/W lanes stay clear.
	local counters = {
		{ name = "UpgradeCounter", text = "SHOP", angle = 45, color = Color3.fromRGB(255, 200, 60) },
		{ name = "SellCounter", text = "SELL", angle = 135, color = Color3.fromRGB(80, 220, 100) },
		{ name = "GateCounter", text = "GATE", angle = 225, color = Color3.fromRGB(230, 80, 80) },
	}
	-- Each counter is an invisible marker: the prompts and range checks use
	-- its position, and tools/BuildBiomes.luau builds a stall around it.
	for _, c in counters do
		local pos = pointAt(26, c.angle, floorY + 2)
		local counter = part({
			Name = c.name,
			CFrame = CFrame.lookAt(pos, Vector3.new(World.center.X, pos.Y, World.center.Z)),
			Size = Vector3.new(12, 4, 4),
			Transparency = 1,
			CanCollide = false,
			Parent = shop,
		})
		label(counter, c.text, 12, c.color)
	end

	-- Daily wheel: a disc of prize segments on a wooden A-frame, with a
	-- pointer at the top. The disc and its segments are the "Spinner" model,
	-- which WheelController turns about the disc's axis. Segments are laid out
	-- so that turning the wheel by fraction f of a full turn puts the prize at
	-- fraction f of the odds strip (see Config/Wheel) under the pointer.
	local wheelBase = pointAt(26, 315, floorY)
	local facing = CFrame.lookAt(wheelBase, Vector3.new(World.center.X, wheelBase.Y, World.center.Z))
	local wheel = Instance.new("Model")
	wheel.Name = "DailyWheel"
	wheel.Parent = shop
	local wood = Color3.fromRGB(110, 75, 45)
	local brass = Color3.fromRGB(190, 150, 70)
	local hubHeight, radius = 10, 6

	part({ Name = "Base", CFrame = facing * CFrame.new(0, 0.5, 0.5), Size = Vector3.new(10, 1, 4), Color = wood, Material = Enum.Material.WoodPlanks, Parent = wheel })
	for _, side in { -1, 1 } do
		local foot = (facing * CFrame.new(side * 4, 1, 1)).Position
		local top = (facing * CFrame.new(0, hubHeight, 1)).Position
		part({
			Name = "Leg",
			CFrame = CFrame.lookAt((foot + top) / 2, top) * CFrame.Angles(math.rad(90), 0, 0),
			Size = Vector3.new(0.9, (top - foot).Magnitude, 0.9),
			Color = wood,
			Material = Enum.Material.Wood,
			Parent = wheel,
		})
	end
	part({
		Name = "Pointer",
		CFrame = facing * CFrame.new(0, hubHeight + radius + 0.6, -0.8) * CFrame.Angles(0, 0, math.rad(45)),
		Size = Vector3.new(1.2, 1.2, 0.4),
		Color = Color3.fromRGB(200, 40, 40),
		Material = Enum.Material.SmoothPlastic,
		Parent = wheel,
	})

	local spinner = Instance.new("Model")
	spinner.Name = "Spinner"
	spinner.Parent = wheel
	local disk = part({
		Name = "Wheel",
		Shape = Enum.PartType.Cylinder,
		-- Cylinder axis is X; rotate so the face points at the shop center.
		CFrame = facing * CFrame.new(0, hubHeight, -0.2) * CFrame.Angles(0, math.rad(90), 0),
		Size = Vector3.new(0.8, radius * 2 + 0.6, radius * 2 + 0.6),
		Color = brass,
		Material = Enum.Material.Metal,
		Parent = spinner,
	})
	spinner.PrimaryPart = disk

	-- Segments: flat triangles on the disc's front face, each prize's share
	-- of the odds split into slices of at most 15 degrees.
	local face = disk.CFrame * CFrame.new(0.45, 0, 0) -- front face center; +X points at the shop
	local function rim(fraction: number): Vector3
		local theta = -2 * math.pi * fraction
		return (face * CFrame.new(0, math.cos(theta) * radius, math.sin(theta) * radius)).Position
	end
	local start = 0
	for i, prize in Wheel.prizes do
		local slices = math.max(1, math.ceil(prize.chance * 360 / 15))
		for k = 0, slices - 1 do
			local f1 = start + prize.chance * k / slices
			local f2 = start + prize.chance * (k + 1) / slices
			triangle(spinner, face.Position, rim(f1), rim(f2), face.XVector, prize.color, ("Segment%d"):format(i))
		end
		start += prize.chance
	end
	part({
		Name = "Hub",
		Shape = Enum.PartType.Cylinder,
		CFrame = disk.CFrame * CFrame.new(0.6, 0, 0),
		Size = Vector3.new(0.6, 2, 2),
		Color = brass,
		Material = Enum.Material.Metal,
		Parent = spinner,
	})
	label(disk, "DAILY WHEEL", 9, Color3.fromRGB(200, 140, 255))
end

-- Studio only draws a limited number of SurfaceGuis at once, so signs switch
-- off past this distance; it's far enough to read them from the shop.
local SIGN_RANGE = 160

-- Lab palette and incubator styling are shared with FarmService, which
-- restyles incubators at runtime. Cloned for the same reason as World above.
local farmVisualsModule = game:GetService("ReplicatedStorage").Shared.FarmVisuals:Clone()
local FarmVisuals = require(farmVisualsModule) :: any
farmVisualsModule:Destroy()
local LAB = FarmVisuals.palette
local styleIncubator = FarmVisuals.styleIncubator

-- A square glass incubator whose floor sits on `floorCf` (the plot's top surface).
local function buildIncubator(name: string, floorCf: CFrame, size: number, height: number): Model
	local m = Instance.new("Model")
	m.Name = name
	local floorT, glassT, postT, lidT = 0.6, 0.2, 0.5, 0.4
	local half = size / 2
	local floor = part({
		Name = "Floor",
		CFrame = floorCf * CFrame.new(0, floorT / 2, 0),
		Size = Vector3.new(size, floorT, size),
		Parent = m,
	})
	m.PrimaryPart = floor
	part({
		Name = "Light",
		CFrame = floorCf * CFrame.new(0, floorT + 0.05, 0),
		Size = Vector3.new(size - 2, 0.1, size - 2),
		CanCollide = false,
		Parent = m,
	})
	local wallY = floorT + height / 2
	for _, side in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
		local alongX = side[1] == 0 -- panes on the front/back sides run along X
		part({
			Name = "Glass",
			CFrame = floorCf * CFrame.new(side[1] * (half - glassT / 2), wallY, side[2] * (half - glassT / 2)),
			Size = alongX and Vector3.new(size - postT * 2, height, glassT) or Vector3.new(glassT, height, size - postT * 2),
			Material = Enum.Material.Glass,
			CastShadow = false,
			Parent = m,
		})
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part({
				Name = "Post",
				CFrame = floorCf * CFrame.new(sx * (half - postT / 2), wallY + lidT / 2, sz * (half - postT / 2)),
				Size = Vector3.new(postT, height + lidT, postT),
				Material = Enum.Material.Metal,
				Parent = m,
			})
		end
	end
	part({
		Name = "Lid",
		CFrame = floorCf * CFrame.new(0, floorT + height + lidT / 2, 0),
		Size = Vector3.new(size, lidT, size),
		Material = Enum.Material.Glass,
		CastShadow = false,
		Parent = m,
	})
	return m
end

-- A board on two posts standing on `cf`, facing its -Z (toward the shop).
-- Returns the SurfaceGui on the board's front for the caller to fill.
local function signBoard(parent: Instance, name: string, cf: CFrame, width: number, boardHeight: number, postHeight: number): SurfaceGui
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	for _, x in { -width / 2 + 1, width / 2 - 1 } do
		part({
			Name = "Post",
			CFrame = cf * CFrame.new(x, postHeight / 2, 0.3),
			Size = Vector3.new(0.5, postHeight, 0.5),
			Color = LAB.metal,
			Material = Enum.Material.Metal,
			Parent = model,
		})
	end
	local board = part({
		Name = "Board",
		CFrame = cf * CFrame.new(0, postHeight + boardHeight / 2 - 0.5, 0),
		Size = Vector3.new(width, boardHeight, 0.4),
		Color = LAB.signBoard,
		Material = Enum.Material.Metal,
		Parent = model,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.MaxDistance = SIGN_RANGE
	gui.Parent = board
	return gui
end

local function signText(gui: SurfaceGui, name: string, text: string, y: number, h: number, font: Enum.Font, color: Color3)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.Position = UDim2.fromScale(0.05, y)
	t.Size = UDim2.fromScale(0.9, h)
	t.BackgroundTransparency = 1
	t.Font = font
	t.TextScaled = true
	t.TextColor3 = color
	t.Text = text
	t.Parent = gui
end

local function buildPlots(map: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	folder.Parent = map
	local cfg = World.farm
	local floorY = GROUND_Y + 0.02 * (#World.zones - 1)
	for i = 1, cfg.plotCount do
		local angle = cfg.angleOffset + (i - 1) * 360 / cfg.plotCount
		local pos = pointAt(cfg.plotRadius, angle, floorY + 0.5)
		-- Plot's -Z faces the map center.
		local cf = CFrame.lookAt(pos, Vector3.new(World.center.X, pos.Y, World.center.Z))

		local plot = Instance.new("Model")
		plot.Name = "Plot" .. i
		plot:SetAttribute("PlotIndex", i)
		plot.Parent = folder

		local base = part({
			Name = "Base",
			CFrame = cf,
			Size = Vector3.new(cfg.plotSize, 1, cfg.plotSize),
			Color = LAB.floor,
			Material = Enum.Material.SmoothPlastic,
			Parent = plot,
		})
		plot.PrimaryPart = base
		local half = cfg.plotSize / 2
		local top = 0.5 -- base's top surface, relative to cf

		-- Center aisle, running from the front edge to the back edge.
		part({
			Name = "Aisle",
			CFrame = cf * CFrame.new(0, top + 0.1, 0),
			Size = Vector3.new(cfg.aisleWidth, 0.2, cfg.plotSize),
			Color = LAB.aisle,
			Material = Enum.Material.DiamondPlate,
			Parent = plot,
		})

		-- Incubators: half the columns on each side of the aisle. Front row
		-- first, left to right as seen standing at the front looking in (-X is right).
		local pads = Instance.new("Folder")
		pads.Name = "Pads"
		pads.Parent = plot
		local perSide = cfg.padColumns / 2
		local columnPitch = (half - cfg.aisleWidth / 2) / perSide
		local rowPitch = cfg.plotSize / cfg.padRows
		local columnX = {}
		for c = perSide, 1, -1 do
			table.insert(columnX, cfg.aisleWidth / 2 + columnPitch * (c - 0.5))
		end
		for c = 1, perSide do
			table.insert(columnX, -(cfg.aisleWidth / 2 + columnPitch * (c - 0.5)))
		end
		for row = 1, cfg.padRows do
			local z = -half + rowPitch * (row - 0.5)
			for col, x in columnX do
				local index = (row - 1) * cfg.padColumns + col
				local incubator = buildIncubator("Pad" .. index, cf * CFrame.new(x, top, z), cfg.padSize, cfg.incubatorHeight)
				incubator:SetAttribute("PadIndex", index)
				styleIncubator(incubator, index <= cfg.startingUnlockedPads)
				incubator.Parent = pads
			end
		end

		-- Collection pad on the ground just off the front edge, facing the shop.
		local collectZ = -(half + cfg.collectPadGap + cfg.collectPadSize / 2)
		local collectPad = part({
			Name = "CollectPad",
			CFrame = cf * CFrame.new(0, -0.3, collectZ),
			Size = Vector3.new(cfg.collectPadSize, 0.4, cfg.collectPadSize),
			-- Grey for everyone; each client colors its own pad green (FarmController).
			Color = Color3.fromRGB(95, 100, 105),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Parent = plot,
		})
		-- Short range so the eight COLLECT labels don't clutter the view from the shop.
		label(collectPad, "COLLECT", 3, Color3.fromRGB(120, 255, 140), 60)

		-- Value sign beside the collection pad: money generated and waiting to be
		-- collected, plus the farm's income per second. FarmService fills these in.
		local valueGui = signBoard(plot, "ValueSign", cf * CFrame.new(cfg.collectPadSize / 2 + 6, -0.5, collectZ), 10, 5, 4)
		signText(valueGui, "Title", "VALUE GENERATED", 0.05, 0.22, Enum.Font.GothamBold, Color3.fromRGB(150, 200, 215))
		signText(valueGui, "Amount", "$0", 0.27, 0.45, Enum.Font.GothamBlack, Color3.fromRGB(120, 255, 140))
		signText(valueGui, "Rate", "+$0/s", 0.72, 0.22, Enum.Font.GothamBold, LAB.signText)

		-- Owner sign over the back end of the aisle, raised above the incubators.
		local ownerGui = signBoard(plot, "OwnerSign", cf * CFrame.new(0, top, half - 1), 16, 4, cfg.incubatorHeight + 4)
		signText(ownerGui, "OwnerName", FarmVisuals.unclaimedText(i), 0.1, 0.8, Enum.Font.GothamBold, LAB.signText)
	end
end

local existing = workspace:FindFirstChild("Map")
if existing then
	existing:Destroy()
end

local map = Instance.new("Folder")
map.Name = "Map"

buildGround(map)
for _, wall in World.walls do
	buildWall(map, wall)
end
buildShop(map)
buildPlots(map)

map.Parent = workspace

-- Sanity check: no plot part may poke into a N/E/S/W lane or through the barrier.
local laneHalf = World.doorWidth / 2
local barrierFace = World.walls[1].radius - World.wallThickness / 2
local worstLane, worstBarrier = math.huge, math.huge
for _, d in map.Plots:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 1 then
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local c = (d.CFrame * CFrame.new(sx * d.Size.X / 2, 0, sz * d.Size.Z / 2)).Position - World.center
				minX, maxX = math.min(minX, c.X), math.max(maxX, c.X)
				minZ, maxZ = math.min(minZ, c.Z), math.max(maxZ, c.Z)
				worstBarrier = math.min(worstBarrier, barrierFace - (c * Vector3.new(1, 0, 1)).Magnitude)
			end
		end
		-- Lanes run along the X and Z axes; a part straddling an axis sits in a lane.
		local distX = (minX < 0 and maxX > 0) and 0 or math.min(math.abs(minX), math.abs(maxX))
		local distZ = (minZ < 0 and maxZ > 0) and 0 or math.min(math.abs(minZ), math.abs(maxZ))
		worstLane = math.min(worstLane, distX, distZ)
	end
end
assert(worstLane > laneHalf, ("a plot pokes into a lane (%.1f from its center line)"):format(worstLane))
assert(worstBarrier > 0, ("a plot pokes through the barrier (%.1f)"):format(worstBarrier))

local count = 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
return ("Built Workspace.Map with %d parts. Plot clearance: %.1f studs from lane center lines (need > %d), %.1f inside the barrier"):format(
	count,
	worstLane,
	laneHalf,
	worstBarrier
)
