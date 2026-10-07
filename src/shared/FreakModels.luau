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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FreakConfig = require(script.Parent.Config.Freaks)

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

return FreakModels
