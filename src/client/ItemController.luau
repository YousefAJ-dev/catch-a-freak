--!strict
-- Item buttons (DESIGN.md sections 7 and 11): Q fires the Net Launcher at the
-- point under the mouse, R sets a Bear Trap where the player stands. On-screen
-- buttons do the same for mobile (the net then fires straight ahead). Counts
-- come from the "Item_<id>" attributes; ItemService does everything else.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer

local BUTTON = 64
local AIM_DISTANCE = 500 -- how far the mouse ray looks for something to hit

local ItemController = {}

local function root(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- The world point under the mouse, or straight ahead when there's no mouse aim.
local function aimPoint(useMouse: boolean): Vector3?
	local r = root()
	if not r then
		return nil
	end
	if useMouse then
		local camera = workspace.CurrentCamera
		local mouse = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character :: Instance }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, params)
		if hit then
			return hit.Position
		end
	end
	return r.Position + r.CFrame.LookVector * Items.netLauncher.range * 0.6
end

local function fireNet(useMouse: boolean)
	local target = aimPoint(useMouse)
	if target then
		Remotes.UseNetLauncher:FireServer(target)
	end
end

local function placeTrap()
	Remotes.PlaceBearTrap:FireServer()
end

-- A quick expanding ring where a net lands, seen by everyone.
local function showImpact(position: Vector3, caught: number)
	local radius = Items.netLauncher.radius
	local ring = Instance.new("Part")
	ring.Name = "NetImpact"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.ForceField
	ring.Color = if caught > 0 then Color3.fromRGB(120, 255, 140) else Color3.fromRGB(230, 230, 230)
	ring.Size = Vector3.new(0.4, 2, 2)
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	local tween = TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		Transparency = 0.6,
	})
	tween:Play()
	tween.Completed:Connect(function()
		TweenService:Create(ring, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		task.delay(0.45, function()
			ring:Destroy()
		end)
	end)
end

local function buildButtons(): { [string]: TextLabel }
	local gui = UiKit.make("ScreenGui", { Name = "ItemButtons", ResetOnSpawn = false })
	-- Right of the carry bar (9 slots of 56 + gaps, centered).
	local holder = UiKit.make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.5, 292, 1, -16),
		Size = UDim2.fromOffset(BUTTON * 2 + 8, BUTTON),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UiKit.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		Parent = holder,
	})

	local counts = {}
	for order, id in Items.order do
		local item = (Items :: any)[id]
		local button = UiKit.make("TextButton", {
			Name = id,
			LayoutOrder = order,
			Size = UDim2.fromOffset(BUTTON, BUTTON),
			BackgroundColor3 = UiKit.colors.panel,
			BackgroundTransparency = 0.15,
			Text = "",
			Parent = holder,
		})
		UiKit.corner(button, 10)
		UiKit.make("UIStroke", { Color = Color3.fromRGB(90, 100, 115), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = button })
		UiKit.make("TextLabel", {
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.fromOffset(20, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = UiKit.colors.muted,
			Text = item.key.Name,
			Parent = button,
		})
		UiKit.make("TextLabel", {
			Position = UDim2.new(0, 4, 0.32, 0),
			Size = UDim2.new(1, -8, 0.36, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			TextColor3 = UiKit.colors.text,
			Text = if id == "netLauncher" then "Net" else "Trap",
			Parent = button,
		})
		counts[id] = UiKit.make("TextLabel", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -6, 1, -3),
			Size = UDim2.fromOffset(30, 18),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = UiKit.colors.money,
			Text = "×0",
			Parent = button,
		})
		button.Activated:Connect(function()
			if id == "netLauncher" then
				fireNet(false)
			else
				placeTrap()
			end
		end)
	end
	gui.Parent = player:WaitForChild("PlayerGui")
	return counts
end

function ItemController.start()
	local counts = buildButtons()
	local function renderCounts()
		for id, label in counts do
			local count = (player:GetAttribute("Item_" .. id) :: number?) or 0
			label.Text = "×" .. count
			label.TextColor3 = if count > 0 then UiKit.colors.money else UiKit.colors.muted
		end
	end
	for _, id in Items.order do
		player:GetAttributeChangedSignal("Item_" .. id):Connect(renderCounts)
	end
	renderCounts()

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Items.netLauncher.key then
			fireNet(true)
		elseif input.KeyCode == Items.bearTrap.key then
			placeTrap()
		end
	end)

	Remotes.NetImpact.OnClientEvent:Connect(showImpact)
end

return ItemController
