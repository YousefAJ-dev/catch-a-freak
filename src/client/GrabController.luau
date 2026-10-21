--!strict
-- Grabbing, client side: sets each freak prompt's range and hold time for this
-- player's Grip level, hides the prompts while the player is dead, and shows
-- the grab bar while the input is held. The server (FreakService) times the
-- hold itself and decides whether the grab counts.
--
-- On touch devices holding a prompt while steering and turning the camera is
-- awkward, so there a Grab button (TouchLayout's slot above jump) replaces
-- the floating prompt: one tap starts the grab and it keeps going while the
-- player stays in range (tapping again stops it). The prompt's hold time is 0
-- there and the server does the timing.
--
-- Both ways, the grab finishes one ping early (up to FreakConfig.grabLeadMax)
-- so the freak disappears as the bar fills rather than a ping after.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local FreakConfig = require(ReplicatedStorage.Shared.Config.Freaks)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TouchLayout = require(script.Parent.TouchLayout)
local UiKit = require(script.Parent.UiKit)

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
local function alive(): boolean
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local tapMode = TouchLayout.enabled

-- How long this player needs to grab a freak.
local function holdTime(model: Model): number
	if model:GetAttribute("PinnedBy") == player.UserId then
		return Items.bearTrap.pinnedHold
	end
	local grip = (player:GetAttribute("Upgrade_grip") :: number?) or 0
	return Formulas.holdTime(model:GetAttribute("Tier") :: number, model:GetAttribute("Rarity") :: string, grip)
end

-- The player's round-trip ping, capped; grabs finish this much early.
local function lead(): number
	return math.clamp(player:GetNetworkPing(), 0, FreakConfig.grabLeadMax)
end

local function applyPromptSettings(prompt: ProximityPrompt)
	local model = freakOf(prompt)
	if not model then
		return
	end
	local pinnedBy = model:GetAttribute("PinnedBy") :: number?
	prompt.MaxActivationDistance = FreakConfig.grabRange
	-- A freak pinned by a bear trap is a quick grab for the trap's owner and
	-- off limits to everyone else (the server enforces both).
	prompt.Enabled = alive() and (pinnedBy == nil or pinnedBy == player.UserId)
	-- Touch players use the Grab button (Custom style hides the prompt's own UI).
	prompt.Style = if tapMode() then Enum.ProximityPromptStyle.Custom else Enum.ProximityPromptStyle.Default
	prompt.HoldDuration = if tapMode() then 0 else math.max(holdTime(model) - lead(), 0.05)
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

-- Horizontal distance from the player to a freak, as this client sees it.
local function distanceTo(model: Model): number
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return math.huge
	end
	local offset = root.Position - model:GetPivot().Position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude
end

local function buildButton()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GrabButton"
	gui.ResetOnSpawn = false

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 1)
	button.BackgroundColor3 = Color3.fromRGB(25, 28, 34)
	button.BackgroundTransparency = 0.15
	button.Text = ""
	button.Visible = false
	button.Parent = gui
	Instance.new("UICorner", button).CornerRadius = UDim.new(0.5, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromScale(0.1, 0.28)
	title.Size = UDim2.fromScale(0.8, 0.3)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = button

	local subtitle = Instance.new("TextLabel")
	subtitle.Position = UDim2.fromScale(0.14, 0.6)
	subtitle.Size = UDim2.fromScale(0.72, 0.16)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamBold
	subtitle.TextScaled = true
	subtitle.TextColor3 = Color3.fromRGB(200, 205, 215)
	subtitle.Parent = button

	local function layout()
		TouchLayout.adopt(gui)
		button.Position, button.Size = TouchLayout.slot("grab")
	end
	TouchLayout.changed:Connect(layout)
	layout()
	gui.Parent = player:WaitForChild("PlayerGui")
	return button, stroke, title, subtitle
end

function GrabController.start()
	local gui, fill, label = buildBar()
	local button, stroke, title, subtitle = buildButton()

	-- The grab in progress, if any.
	local active: ProximityPrompt? = nil
	local activeTap = false -- started by a tap (touch) rather than a hold
	local committed = false -- a hold whose prompt has triggered; waiting for the catch
	local startedAt = 0
	local duration = 0
	local hideToken = 0
	-- The freak prompt Roblox is showing right now (the nearest one in range).
	local shown: ProximityPrompt? = nil

	local function refreshButton()
		local target = if active and activeTap then active else shown
		local model = target and freakOf(target)
		button.Visible = tapMode() and alive() and model ~= nil and not UiKit.anyPanelOpen()
		if model and target then
			stroke.Color = Rarities.byId[model:GetAttribute("Rarity") :: string].color
			title.Text = if target == active then "STOP" else "GRAB"
			subtitle.Text = target.ObjectText
		end
	end

	-- Freak models stream in whole (atomic), so the prompt is there on arrival.
	CollectionService:GetInstanceAddedSignal("Freak"):Connect(applyToFreak)
	local function applyToAll()
		for _, model in CollectionService:GetTagged("Freak") do
			applyToFreak(model)
		end
		refreshButton()
	end
	player:GetAttributeChangedSignal("Upgrade_grip"):Connect(applyToAll)
	TouchLayout.changed:Connect(applyToAll)
	UiKit.panelsChanged:Connect(refreshButton)
	-- No grabbing while dead: hide the prompts on death, show them on respawn.
	local function watchCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(applyToAll)
		applyToAll()
	end
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
	applyToAll()

	local function begin(prompt: ProximityPrompt, model: Model, tap: boolean)
		hideToken += 1
		active = prompt
		activeTap = tap
		committed = false
		startedAt = os.clock()
		duration = holdTime(model)
		local rarity = Rarities.byId[model:GetAttribute("Rarity") :: string]
		fill.BackgroundColor3 = rarity.color
		fill.Size = UDim2.fromScale(0, 1)
		label.Text = ("Grabbing %s"):format(prompt.ObjectText)
		gui.Enabled = true
		refreshButton()
	end

	local function stop()
		hideToken += 1
		active = nil
		activeTap = false
		committed = false
		gui.Enabled = false
		refreshButton()
	end

	-- Caught: show the bar full for a moment, then hide it.
	local function finish()
		active = nil
		activeTap = false
		committed = false
		fill.Size = UDim2.fromScale(1, 1)
		refreshButton()
		hideToken += 1
		local token = hideToken
		task.delay(0.15, function()
			if hideToken == token then
				gui.Enabled = false
			end
		end)
	end

	button.Activated:Connect(function()
		if active and activeTap then
			stop()
			Remotes.CancelTapGrab:FireServer()
		elseif shown then
			-- The prompt's hold time is 0 here, so this triggers it at once.
			shown:InputHoldBegin()
			shown:InputHoldEnd()
		end
	end)

	ProximityPromptService.PromptShown:Connect(function(prompt)
		if freakOf(prompt) then
			applyPromptSettings(prompt) -- picks up the current ping
			shown = prompt
			refreshButton()
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		if prompt == shown then
			shown = nil
		end
		-- Leaving range ends a hold that hasn't triggered yet.
		if prompt == active and not activeTap and not committed then
			stop()
		end
		refreshButton()
	end)
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		local model = freakOf(prompt)
		if model and prompt.HoldDuration > 0 then
			begin(prompt, model, false)
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
		if prompt == active and not activeTap and not committed then
			-- A completed hold fires this just before PromptTriggered, so only
			-- a release before the hold time is up cancels.
			if os.clock() - startedAt >= prompt.HoldDuration - 0.05 then
				committed = true
			else
				stop()
			end
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local model = freakOf(prompt)
		if not model then
			return
		end
		if prompt.HoldDuration > 0 then
			-- The hold went through a ping early; the bar keeps filling until
			-- the catch arrives.
			if prompt == active then
				committed = true
			end
		elseif prompt == active and activeTap then
			stop() -- second tap on the same freak: the server cancels it too
		else
			begin(prompt, model, true)
		end
	end)

	Remotes.TapGrabEnded.OnClientEvent:Connect(function(freakId: string, caught: boolean)
		local model = active and freakOf(active)
		if activeTap and (not model or model:GetAttribute("FreakId") == freakId) then
			if caught then
				finish()
			else
				stop()
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		local prompt = active
		if not prompt then
			return
		end
		local elapsed = os.clock() - startedAt
		local model = freakOf(prompt)
		if activeTap then
			-- Walked out of range or died: stop here and tell the server, which
			-- allows a little more range for lag. If the freak is gone the server
			-- already knows, and says so with TapGrabEnded.
			if not model then
				stop()
				return
			elseif not alive() or distanceTo(model) > FreakConfig.grabRange then
				stop()
				Remotes.CancelTapGrab:FireServer()
				return
			end
		elseif committed and not model then
			finish()
			return
		end
		-- In case the server's answer never arrives (refused, e.g. carry full).
		if elapsed > duration + 1 then
			stop()
			return
		end
		fill.Size = UDim2.fromScale(math.clamp(elapsed / math.max(duration, 1e-3), 0, 1), 1)
	end)
end

return GrabController
