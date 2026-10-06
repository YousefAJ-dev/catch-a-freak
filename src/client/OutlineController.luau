--!strict
-- Rarity outlines (DESIGN.md section 5): the nearest few wandering freaks get
-- an outline in their rarity color. Roblox renders at most ~31 Highlights at
-- once, so a small fixed pool is reassigned to the closest freaks a few times
-- a second instead of giving every freak its own.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FreakConfig = require(ReplicatedStorage.Shared.Config.Freaks)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

local player = Players.LocalPlayer

local UPDATE_INTERVAL = 0.2

local OutlineController = {}

function OutlineController.start()
	local folder = Instance.new("Folder")
	folder.Name = "RarityOutlines"
	folder.Parent = workspace

	local pool: { Highlight } = {}
	for i = 1, FreakConfig.outlinedNearest do
		local highlight = Instance.new("Highlight")
		highlight.Name = "Outline" .. i
		highlight.FillTransparency = 1
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Enabled = false
		highlight.Parent = folder
		pool[i] = highlight
	end

	local function update()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local nearest: { { model: Model, distance: number } } = {}
		if root then
			for _, model in CollectionService:GetTagged("Freak") do
				local freakRoot = model:IsA("Model") and model.Parent and model:FindFirstChild("Root") :: BasePart?
				if freakRoot then
					table.insert(nearest, { model = model :: Model, distance = (freakRoot.Position - root.Position).Magnitude })
				end
			end
			table.sort(nearest, function(a, b)
				return a.distance < b.distance
			end)
		end
		for i, highlight in pool do
			local entry = nearest[i]
			local rarity = entry and Rarities.byId[entry.model:GetAttribute("Rarity") :: string]
			if entry and rarity then
				highlight.Adornee = entry.model
				highlight.OutlineColor = rarity.color
				highlight.Enabled = true
			else
				highlight.Adornee = nil
				highlight.Enabled = false
			end
		end
	end

	task.spawn(function()
		while true do
			update()
			task.wait(UPDATE_INTERVAL)
		end
	end)
end

return OutlineController
