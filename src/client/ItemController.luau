--!strict
-- Item buttons (DESIGN.md sections 7 and 11): Q fires the Net Launcher at the
-- point under the mouse, R sets a Bear Trap and T the Golden Bear Trap where
-- the player stands. On-screen
-- buttons do the same for mobile (the net then fires straight ahead). Counts
-- come from the "Item_<id>" attributes; ItemService does everything else.
--
-- Items can't be used while a menu panel (Shop, Sell, ...) is open, and the
-- buttons hide meanwhile, so a tap meant for the panel can't set a trap. On
-- touch devices the buttons sit in TouchLayout's right-hand column.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local UiKit = require(script.Parent.UiKit)
local Sfx = require(script.Parent.Sfx)
local TouchLayout = require(script.Parent.TouchLayout)

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
		Sfx.play("net")
	end
end

local function placeTrap(kind: string)
	Remotes.PlaceBearTrap:FireServer(kind)
	Sfx.play("trap")
end

local LABELS = { netLauncher = "Net", bearTrap = "Trap", goldenTrap = "Gold" }
local GOLD = Color3.fromRGB(255, 200, 60)

local function use(id: string, useMouse: boolean)
	if UiKit.anyPanelOpen() then
		return
	end
	if id == "netLauncher" then
		fireNet(useMouse)
	else
		placeTrap(id)
	end
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
		Size = UDim2.fromOffset(BUTTON * #Items.buttons + 8 * (#Items.buttons - 1), BUTTON),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local list = UiKit.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		Parent = holder,
	})

	local counts = {}
	local buttons: { TextButton } = {}
	local keyLabels: { TextLabel } = {}
	for order, id in Items.buttons do
		local item = (Items :: any)[id]
		local golden = id == "goldenTrap"
		local button = UiKit.make("TextButton", {
			Name = id,
			LayoutOrder = order,
			Size = UDim2.fromOffset(BUTTON, BUTTON),
			BackgroundColor3 = if golden then Color3.fromRGB(70, 52, 10) else UiKit.colors.panel,
			BackgroundTransparency = 0.15,
			Text = "",
			Parent = holder,
		})
		UiKit.corner(button, 10)
		UiKit.make("UIStroke", {
			Color = if golden then GOLD else Color3.fromRGB(90, 100, 115),
			Thickness = if golden then 2.5 else 1.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = button,
		})
		keyLabels[order] = UiKit.make("TextLabel", {
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
		buttons[order] = button
		UiKit.make("TextLabel", {
			Position = UDim2.new(0, 4, 0.32, 0),
			Size = UDim2.new(1, -8, 0.36, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			TextColor3 = if golden then GOLD else UiKit.colors.text,
			Text = LABELS[id],
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
			use(id, false)
		end)
	end

	local function layout()
		local touch = TouchLayout.enabled()
		TouchLayout.adopt(gui)
		gui.Enabled = not UiKit.anyPanelOpen()
		-- Touch: each button in its own slot, so the holder covers the screen
		-- (it's transparent and doesn't take input).
		list.Parent = if touch then nil else holder
		holder.AnchorPoint = if touch then Vector2.zero else Vector2.new(0, 1)
		holder.Position = if touch then UDim2.new() else UDim2.new(0.5, 292, 1, -16)
		holder.Size = if touch
			then UDim2.fromScale(1, 1)
			else UDim2.fromOffset(BUTTON * #Items.buttons + 8 * (#Items.buttons - 1), BUTTON)
		for order, button in buttons do
			if touch then
				button.AnchorPoint = Vector2.new(1, 1)
				button.Position, button.Size = TouchLayout.slot("item" .. order)
			else
				button.AnchorPoint = Vector2.zero
				button.Size = UDim2.fromOffset(BUTTON, BUTTON)
			end
			keyLabels[order].Visible = not touch
			local count = counts[Items.buttons[order]]
			count.TextSize = if touch then math.floor(button.Size.X.Offset * 0.24) else 15
			count.Size = UDim2.fromOffset(count.TextSize * 2, count.TextSize * 1.2)
		end
	end
	TouchLayout.changed:Connect(layout)
	UiKit.panelsChanged:Connect(layout)
	layout()

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
	for _, id in Items.buttons do
		player:GetAttributeChangedSignal("Item_" .. id):Connect(renderCounts)
	end
	renderCounts()

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		for _, id in Items.buttons do
			if input.KeyCode == (Items :: any)[id].key then
				use(id, true)
			end
		end
	end)

	Remotes.NetImpact.OnClientEvent:Connect(showImpact)
end

return ItemController
