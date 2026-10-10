--!strict
-- Builds freak models. Used for wandering freaks (FreakService), freaks placed
-- in incubators (FarmService), and the carried-freak miniatures that trail
-- behind players (client TrailController).
--
-- Each species is a single textured MeshPart, the Body. The server loads every
-- species' mesh once at startup (loadMeshes) into ReplicatedStorage.FreakMeshes,
-- and models clone from there on both server and client. Rarity is not part
-- of the model; the client outlines nearby freaks in their rarity color
-- (OutlineController). Every model is built around an invisible Root part
-- that sits on the ground and faces -Z, with the Body placed relative to it,
-- so a model can be moved by moving its parts with fixed offsets.

local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FreakConfig = require(script.Parent.Config.Freaks)
local Rarities = require(script.Parent.Config.Rarities)

local FOLDER_NAME = "FreakMeshes"
local CLIENT_WAIT = 15 -- seconds a client waits for the server's meshes before using stand-ins

local FreakModels = {}

local speciesByName: { [string]: FreakConfig.Species } = {}
for _, list in FreakConfig.species do
	for _, species in list do
		speciesByName[species.name] = species
	end
end

function FreakModels.species(name: string): FreakConfig.Species
	local species = speciesByName[name] or speciesByName[FreakConfig.renamed[name] or ""]
	assert(species, "unknown species " .. tostring(name))
	return species
end

local function setupPart(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
end

-- Server only. Creates one MeshPart per species, all at once, and publishes
-- the folder when every one has finished, so a client that sees the folder
-- has them all. Returns once loading is done; a species whose mesh fails to
-- load is left out and builds as a stand-in.
function FreakModels.loadMeshes()
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	-- Count first: a load that fails without yielding finishes inside task.spawn.
	local pending = 0
	for _ in speciesByName do
		pending += 1
	end
	local finished = false
	local done = Instance.new("BindableEvent")
	for name, species in speciesByName do
		task.spawn(function()
			local ok, result = pcall(function()
				return AssetService:CreateMeshPartAsync(Content.fromUri(species.mesh), {
					CollisionFidelity = Enum.CollisionFidelity.Box,
				})
			end)
			if ok then
				local part = result :: MeshPart
				part.Name = name
				part.TextureID = species.texture
				part.Size = species.size
				part.Material = Enum.Material.Fabric -- matte: no plastic shine
				setupPart(part)
				part.Parent = folder
			else
				warn(("FreakModels: couldn't load the %s mesh: %s"):format(name, tostring(result)))
			end
			pending -= 1
			if pending == 0 then
				finished = true
				done:Fire()
			end
		end)
	end
	if not finished then
		done.Event:Wait()
	end
	done:Destroy()
	folder.Parent = ReplicatedStorage
end

local meshes: Instance? = nil
local function meshFolder(): Instance?
	if not meshes then
		meshes = ReplicatedStorage:FindFirstChild(FOLDER_NAME) or ReplicatedStorage:WaitForChild(FOLDER_NAME, CLIENT_WAIT)
	end
	return meshes
end

-- A plain colored ball the species' size, used only if its mesh didn't load.
local function standIn(species: FreakConfig.Species): BasePart
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.SmoothPlastic
	p.Color = species.color
	p.Size = Vector3.one * math.max(species.size.X, species.size.Y, species.size.Z)
	return p
end

-- Returns the model (pivot at origin) and its Body part.
function FreakModels.build(species: FreakConfig.Species): (Model, BasePart)
	local model = Instance.new("Model")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one
	root.Transparency = 1
	root.CanQuery = false
	setupPart(root)
	root.Parent = model
	model.PrimaryPart = root

	local folder = meshFolder()
	local template = folder and folder:FindFirstChild(species.name) :: BasePart?
	local body = if template then template:Clone() else standIn(species)
	body.Name = "Body"
	setupPart(body)
	body.CFrame = CFrame.new(0, body.Size.Y / 2, 0)
	body.Parent = model

	return model, body
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 40)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 240, 60)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(70, 230, 90)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(60, 150, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 80, 255)),
})

-- Gives a freak of a glowing rarity (Config/Rarities) a light and a stream
-- of sparkles, so it stands out from across a ring. `scale` shrinks them for
-- small copies (trail miniatures, freaks scaled down to fit an incubator).
-- Rainbow lights are tagged "RainbowGlow" so the client can cycle their color.
function FreakModels.decorate(body: BasePart, rarityId: string, scale: number?)
	local rarity = Rarities.byId[rarityId]
	if not (rarity and rarity.glow) then
		return
	end
	local s = scale or 1
	local light = Instance.new("PointLight")
	light.Name = "RarityLight"
	light.Color = rarity.glow
	light.Range = 18 * s
	light.Brightness = 3
	light.Shadows = false
	light.Parent = body
	if rarity.rainbow then
		CollectionService:AddTag(light, "RainbowGlow")
	end

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "RaritySparkles"
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = if rarity.rainbow then RAINBOW else ColorSequence.new(rarity.glow)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * s), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	sparkles.Lifetime = NumberRange.new(1, 1.6)
	sparkles.Rate = 10
	sparkles.Speed = NumberRange.new(1, 3)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Acceleration = Vector3.new(0, 2, 0)
	sparkles.Parent = body
end

return FreakModels
