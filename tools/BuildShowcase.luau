--[[
	Freak showcase for thumbnails and promo shots: every species lined up on a
	floating stage high above the lab, ring 1 in front and ring 5 at the back on
	raised steps, all facing the camera. The edit camera is moved to the shot.

	Not a game script: run it in Studio's edit DataModel with
	require(game.ServerStorage.Tools.BuildShowcase:Clone()). It rebuilds
	Workspace.Showcase each run. Delete Workspace.Showcase before publishing.
]]

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function load(module: ModuleScript): any
	local copy = module:Clone()
	local result = require(copy)
	copy:Destroy()
	return result
end
local FreakConfig = load(ReplicatedStorage.Shared.Config.Freaks)
local World = load(ReplicatedStorage.Shared.Config.World)

local HEIGHT = World.barrierHeight + 40 -- stage floor, above the barrier
local SCALE = 1.3 -- freaks a bit larger than in game, to fill the frame
local ROW_DEPTH = 6.5 -- studs between rows
local ROW_RISE = 3.2 -- each row back stands this much higher
local SPACING = 8.5 -- studs between freaks in a row

local existing = workspace:FindFirstChild("Showcase")
if existing then
	existing:Destroy()
end
local showcase = Instance.new("Model")
showcase.Name = "Showcase"

local origin = CFrame.new(World.center + Vector3.new(0, HEIGHT, 0))

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = showcase
	return p
end

-- Stage: a dark metal deck with a step per ring and a glowing hazard trim.
local rows = #FreakConfig.species
local depth = rows * ROW_DEPTH + 8
part({
	Name = "Deck",
	Size = Vector3.new(SPACING * 4 + 8, 2, depth),
	CFrame = origin * CFrame.new(0, -1, (rows - 1) * ROW_DEPTH / 2),
	Material = Enum.Material.DiamondPlate,
	Color = Color3.fromRGB(70, 76, 80),
})
part({
	Name = "Trim",
	Size = Vector3.new(SPACING * 4 + 8.4, 0.6, 0.8),
	CFrame = origin * CFrame.new(0, -0.2, -4.2),
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(150, 255, 60),
})

for row, list in FreakConfig.species do
	local z = (row - 1) * ROW_DEPTH
	local y = (row - 1) * ROW_RISE
	if row > 1 then
		part({
			Name = "Step" .. row,
			Size = Vector3.new(SPACING * 4 + 8, y, ROW_DEPTH),
			CFrame = origin * CFrame.new(0, y / 2, z + 1),
			Material = Enum.Material.DiamondPlate,
			Color = Color3.fromRGB(70, 76, 80):Lerp(Color3.fromRGB(40, 44, 48), row / rows),
		})
	end
	-- Stagger every other row so the one behind shows between the gaps.
	local stagger = if row % 2 == 0 then SPACING / 2 else 0
	for i, species in list do
		local x = (i - (#list + 1) / 2) * SPACING + stagger
		local ok, body = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromUri(species.mesh))
		end)
		if ok then
			local p = body :: MeshPart
			p.Name = species.name
			p.TextureID = species.texture
			p.Material = Enum.Material.Fabric
			p.Anchored = true
			p.Size = species.size * SCALE
			-- Freaks face -Z, toward the camera; a slight turn toward the
			-- middle reads better than a flat lineup.
			local turn = math.rad(x * 1.5)
			p.CFrame = origin * CFrame.new(x, y + p.Size.Y / 2, z) * CFrame.Angles(0, turn, 0)
			p.Parent = showcase
		else
			warn("BuildShowcase: couldn't load " .. species.name .. ": " .. tostring(body))
		end
	end
end

showcase.Parent = workspace

-- The shot: slightly above the front row, looking up the steps.
local camera = workspace.CurrentCamera
local eye = origin * CFrame.new(0, 13, -24)
local target = origin * CFrame.new(0, 7, rows * ROW_DEPTH / 2)
camera.CFrame = CFrame.lookAt(eye.Position, target.Position)
camera.Focus = target

return ("Built Workspace.Showcase at y = %d; camera moved to the shot"):format(HEIGHT)
