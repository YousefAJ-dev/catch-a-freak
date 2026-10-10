--!strict
-- Glowing rarities (Config/Rarities): every wandering freak of a rarity with a
-- `glow` gets its own Highlight that tints its whole body in that color, so
-- it reads as glowing from far away (on top of the light and sparkles from
-- FreakModels.decorate). They're rare enough that this stays well under
-- Roblox's limit of ~31 visible Highlights, and OutlineController leaves them
-- out of its nearest-freak outlines. Rainbow ones, and every "RainbowGlow"
-- light, cycle through the rainbow.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

local CYCLE_SECONDS = 4 -- one trip around the rainbow

local RarityFxController = {}

function RarityFxController.start()
	local folder = Instance.new("Folder")
	folder.Name = "RarityGlows"
	folder.Parent = workspace

	local glows: { [Instance]: { highlight: Highlight, rainbow: boolean } } = {}

	local function add(model: Instance)
		local rarity = Rarities.byId[model:GetAttribute("Rarity") :: string]
		if glows[model] or not (rarity and rarity.glow) then
			return
		end
		local highlight = Instance.new("Highlight")
		highlight.Name = model.Name
		highlight.Adornee = model
		highlight.FillColor = rarity.glow
		highlight.FillTransparency = 0.55
		highlight.OutlineColor = rarity.glow
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = folder
		glows[model] = { highlight = highlight, rainbow = rarity.rainbow == true }
	end

	local function remove(model: Instance)
		local glow = glows[model]
		if glow then
			glow.highlight:Destroy()
			glows[model] = nil
		end
	end

	CollectionService:GetInstanceAddedSignal("Freak"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("Freak"):Connect(remove)
	for _, model in CollectionService:GetTagged("Freak") do
		add(model)
	end

	RunService.RenderStepped:Connect(function()
		local color = Color3.fromHSV((os.clock() / CYCLE_SECONDS) % 1, 0.85, 1)
		for _, glow in glows do
			if glow.rainbow then
				glow.highlight.FillColor = color
				glow.highlight.OutlineColor = color
			end
		end
		for _, light in CollectionService:GetTagged("RainbowGlow") do
			(light :: PointLight).Color = color
		end
	end)
end

return RarityFxController
