--!strict
-- Grabbing, client side: sets each freak prompt's range and hold time for this
-- player's Grip level, and shows the grab bar while the input is held. The server
-- (FreakService) times the hold itself and decides whether the grab counts.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local FreakConfig = require(ReplicatedStorage.Shared.Config.Freaks)
local Items = require(ReplicatedStorage.Shared.Config.Items)

local player = Players.LocalPlayer

local GrabController = {}

-- The freak model a prompt belongs to, or nil for any other prompt.
local function freakOf(prompt: ProximityPrompt): Model?
	local model = prompt.Parent and prompt.Parent.Parent
	if model and model:IsA("Model") and model:GetAttribute("FreakId") then
		return model
	end
	return nil
end

-- Sets this player's grab range and hold time on a freak prompt. The server's
-- copy is deliberately loose (see FreakService); these local values are what
-- the player actually experiences.
local function applyPromptSettings(prompt: ProximityPrompt)
	local model = freakOf(prompt)
	if not model then
		return
	end
	local grip = (player:GetAttribute("Upgrade_grip") :: number?) or 0
	local pinnedBy = model:GetAttribute("PinnedBy") :: number?
	prompt.MaxActivationDistance = FreakConfig.grabRange
	-- A freak pinned by a bear trap is a quick grab for the trap's owner and
	-- off limits to everyone else (the server enforces both).
	prompt.Enabled = pinnedBy == nil or pinnedBy == player.UserId
	prompt.HoldDuration = if pinnedBy == player.UserId
		then Items.bearTrap.pinnedHold
		else Formulas.holdTime(model:GetAttribute("Tier") :: number, model:GetAttribute("Rarity") :: string, grip)
end

local watched: { [Instance]: true } = {}

local function applyToFreak(model: Instance)
	local body = model:FindFirstChild("Body")
	local prompt = body and body:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	applyPromptSettings(prompt)
	if not watched[model] then
		watched[model] = true
		model:GetAttributeChangedSignal("PinnedBy"):Connect(function()
			applyPromptSettings(prompt)
		end)
		model.Destroying:Connect(function()
			watched[model] = nil
		end)
	end
end

local function buildBar()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GrabBar"
	gui.ResetOnSpawn = false
	gui.Enabled = false

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.64)
	frame.Size = UDim2.fromOffset(280, 18)
	frame.BackgroundColor3 = Color3.fromRGB(25, 28, 34)
	frame.BackgroundTransparency = 0.2
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 9)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BorderSizePixel = 0
	fill.Parent = frame
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 9)

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 0, -4)
	label.Size = UDim2.fromOffset(280, 22)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = frame

	gui.Parent = player:WaitForChild("PlayerGui")
	return gui, fill, label
end

function GrabController.start()
	local gui, fill, label = buildBar()
	local active: ProximityPrompt? = nil
	local startedAt = 0

	-- Freak models stream in whole (atomic), so the prompt is there on arrival.
	CollectionService:GetInstanceAddedSignal("Freak"):Connect(applyToFreak)
	local function applyToAll()
		for _, model in CollectionService:GetTagged("Freak") do
			applyToFreak(model)
		end
	end
	player:GetAttributeChangedSignal("Upgrade_grip"):Connect(applyToAll)
	applyToAll()

	local function stop(prompt: ProximityPrompt)
		if prompt == active then
			active = nil
			gui.Enabled = false
		end
	end

	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		local model = freakOf(prompt)
		if not model then
			return
		end
		active = prompt
		startedAt = os.clock()
		local rarity = Rarities.byId[model:GetAttribute("Rarity") :: string]
		fill.BackgroundColor3 = rarity.color
		label.Text = ("Grabbing %s"):format(prompt.ObjectText)
		gui.Enabled = true
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(stop)
	ProximityPromptService.PromptTriggered:Connect(stop)
	ProximityPromptService.PromptHidden:Connect(stop)

	RunService.RenderStepped:Connect(function()
		local prompt = active
		if prompt then
			local progress = math.clamp((os.clock() - startedAt) / math.max(prompt.HoldDuration, 1e-3), 0, 1)
			fill.Size = UDim2.fromScale(progress, 1)
		end
	end)
end

return GrabController
