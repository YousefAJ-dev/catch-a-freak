--!strict
-- Builds freak models. Used for wandering freaks (FreakService) and freaks
-- placed in incubators (FarmService).
--
-- Looks are greybox placeholders until Milestone 10: each species has its own
-- body shape, size, color and eye count. Rarity is not part of the model; the
-- client outlines nearby freaks in their rarity color (OutlineController).
-- Every model is built around an invisible Root part that sits on the ground
-- and faces -Z, with all other parts placed relative to it, so a model can be
-- moved by moving its parts with fixed offsets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FreakConfig = require(ReplicatedStorage.Shared.Config.Freaks)

local FreakModels = {}

local speciesByName: { [string]: FreakConfig.Species } = {}
for _, list in FreakConfig.species do
	for _, species in list do
		speciesByName[species.name] = species
	end
end

function FreakModels.species(name: string): FreakConfig.Species
	local species = speciesByName[name]
	assert(species, "unknown species " .. tostring(name))
	return species
end

local function makePart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

-- Returns the model (pivot at origin) and its Body part.
function FreakModels.build(species: FreakConfig.Species): (Model, BasePart)
	local model = Instance.new("Model")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local root = makePart({ Name = "Root", Size = Vector3.one, Transparency = 1, CanQuery = false, Parent = model })
	model.PrimaryPart = root

	local isCylinder = species.shape == "Cylinder"
	local height = if isCylinder then species.size.X else species.size.Y
	local width = species.size.Z
	local depth = if isCylinder then species.size.Y else species.size.Z
	if species.shape == "Ball" then
		width, depth = species.size.X, species.size.X
	end

	local body = makePart({
		Name = "Body",
		Shape = Enum.PartType[species.shape],
		Size = species.size,
		-- A cylinder's axis is X; stand it upright.
		CFrame = CFrame.new(0, height / 2, 0) * (if isCylinder then CFrame.Angles(0, 0, math.rad(90)) else CFrame.identity),
		Color = species.color,
		Parent = model,
	})

	-- Eyes on the front (-Z) face, spread evenly across its width.
	local eyeSize = math.clamp(math.min(width, height) * 0.28, 0.5, 1.4)
	for i = 1, species.eyes do
		local x = (i - (species.eyes + 1) / 2) * eyeSize * 1.3
		local eyeCf = CFrame.new(x, height * 0.68, -depth / 2 + eyeSize * 0.25)
		makePart({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * eyeSize, CFrame = eyeCf, Color = Color3.new(1, 1, 1), Parent = model })
		makePart({
			Name = "Pupil",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * eyeSize * 0.5,
			CFrame = eyeCf * CFrame.new(0, 0, -eyeSize * 0.35),
			Color = Color3.new(0.05, 0.05, 0.05),
			Parent = model,
		})
	end

	return model, body
end

return FreakModels
