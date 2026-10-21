--!strict
-- Small helpers shared by the client's UI controllers so panels look alike.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local FreakConfig = require(ReplicatedStorage.Shared.Config.Freaks)
local Sfx = require(script.Parent.Sfx)

local player = Players.LocalPlayer

local UiKit = {}

UiKit.colors = {
	panel = Color3.fromRGB(22, 25, 31),
	row = Color3.fromRGB(36, 40, 48),
	text = Color3.new(1, 1, 1),
	muted = Color3.fromRGB(160, 168, 180),
	money = Color3.fromRGB(120, 255, 140),
	go = Color3.fromRGB(60, 170, 90),
	action = Color3.fromRGB(60, 120, 210),
	disabled = Color3.fromRGB(70, 74, 82),
}

-- Accent colors, one per panel, so each menu is recognizable at a glance.
UiKit.accents = {
	shop = Color3.fromRGB(60, 130, 235),
	sell = Color3.fromRGB(235, 170, 30),
	farm = Color3.fromRGB(60, 190, 95),
	gate = Color3.fromRGB(160, 80, 235),
	wheel = Color3.fromRGB(235, 80, 160),
	freakpedia = Color3.fromRGB(150, 220, 60),
}

UiKit.PANEL_WIDTH = 440
UiKit.PANEL_HEIGHT = 540

function UiKit.make(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	inst.Parent = props.Parent
	return inst
end

function UiKit.corner(parent: Instance, radius: number)
	UiKit.make("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

-- Placeholder icons until real art: one glyph per body shape.
local SHAPE_GLYPH = { Ball = "●", Block = "■", Cylinder = "▬" }
local glyphBySpecies: { [string]: string } = {}
for _, list in FreakConfig.species do
	for _, species in list do
		glyphBySpecies[species.name] = SHAPE_GLYPH[species.shape]
	end
end

function UiKit.glyph(speciesName: string): string
	return glyphBySpecies[speciesName] or "?"
end

export type Panel = {
	gui: ScreenGui,
	title: TextLabel,
	subtitle: TextLabel,
	list: ScrollingFrame,
	footer: Frame,
	close: TextButton, -- the X in the corner; controllers connect what closing means
}

-- Every panel made by UiKit.panel (Shop, Sell, Gate, Wheel, Lab), so other
-- controls can step aside while one is open.
local panelGuis: { ScreenGui } = {}
local panelsChangedEvent = Instance.new("BindableEvent")
UiKit.panelsChanged = panelsChangedEvent.Event

function UiKit.anyPanelOpen(): boolean
	for _, gui in panelGuis do
		if gui.Enabled then
			return true
		end
	end
	return false
end

-- A panel docked on the right edge of the screen, hidden until enabled: a
-- header bar in the panel's `accent` color, a glowing accent border and a
-- drop shadow, so it stands out over the world.
function UiKit.panel(name: string, title: string, accent: Color3?): Panel
	local color = accent or UiKit.colors.action
	local gui = UiKit.make("ScreenGui", { Name = name, ResetOnSpawn = false, Enabled = false })
	local size = UDim2.fromOffset(UiKit.PANEL_WIDTH, UiKit.PANEL_HEIGHT)
	local position = UDim2.new(1, -18, 0.5, -24)
	local shadow = UiKit.make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = position + UDim2.fromOffset(6, 8),
		Size = size,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		Parent = gui,
	})
	UiKit.corner(shadow, 16)
	local frame = UiKit.make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = position,
		Size = size,
		BackgroundColor3 = UiKit.colors.panel,
		BackgroundTransparency = 0.04,
		Parent = gui,
	})
	UiKit.corner(frame, 16)
	UiKit.make("UIStroke", { Color = color, Thickness = 3, Parent = frame })

	local header = UiKit.make("Frame", {
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = frame,
	})
	UiKit.corner(header, 16)
	UiKit.make("UIGradient", {
		Color = ColorSequence.new(color, color:Lerp(Color3.new(0, 0, 0), 0.45)),
		Rotation = 90,
		Parent = header,
	})
	-- Squares off the header's bottom corners where it meets the body.
	local seam = UiKit.make("Frame", {
		Position = UDim2.new(0, 0, 1, -16),
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.45),
		BorderSizePixel = 0,
		Parent = header,
	})
	seam.ZIndex = 0

	local close = UiKit.make("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0, 29),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = Color3.fromRGB(200, 60, 60),
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		TextColor3 = UiKit.colors.text,
		Text = "X",
		ZIndex = 2,
		Parent = frame,
	})
	UiKit.corner(close, 10)
	UiKit.make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1.5, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = close })

	local titleLabel = UiKit.make("TextLabel", {
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -70, 0, 58),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UiKit.colors.text,
		TextStrokeTransparency = 0.5,
		Text = title,
		ZIndex = 2,
		Parent = frame,
	})
	local subtitle = UiKit.make("TextLabel", {
		Position = UDim2.fromOffset(18, 66),
		Size = UDim2.new(1, -36, 0, 42),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = UiKit.colors.muted,
		Text = "",
		Parent = frame,
	})
	local list = UiKit.make("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 114),
		Size = UDim2.new(1, -28, 1, -186),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = color,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = frame,
	})
	UiKit.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local footer = UiKit.make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -14),
		Size = UDim2.new(1, -28, 0, 52),
		BackgroundTransparency = 1,
		Parent = frame,
	})

	table.insert(panelGuis, gui)
	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		panelsChangedEvent:Fire()
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	return { gui = gui, title = titleLabel, subtitle = subtitle, list = list, footer = footer, close = close }
end

-- A ProximityPrompt that exists only on this client, on an invisible anchor at
-- `position`. Local prompts can't appear for other players, and the anchor is
-- created here (not streamed), so the prompt survives streaming.
function UiKit.localPrompt(name: string, position: Vector3, actionText: string, objectText: string, range: number, onTriggered: () -> ()): ProximityPrompt
	local anchor = UiKit.make("Part", {
		Name = name,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.one,
		Position = position,
		Parent = workspace,
	})
	local prompt = UiKit.make("ProximityPrompt", {
		ActionText = actionText,
		ObjectText = objectText,
		HoldDuration = 0,
		MaxActivationDistance = range,
		RequiresLineOfSight = false,
		Parent = anchor,
	})
	prompt.Triggered:Connect(onTriggered)
	return prompt
end

function UiKit.clear(list: Instance)
	for _, child in list:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

function UiKit.button(parent: Instance, text: string, color: Color3, enabled: boolean, onClick: () -> ()): TextButton
	local button = UiKit.make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = if enabled then color else UiKit.colors.disabled,
		AutoButtonColor = enabled,
		Font = Enum.Font.GothamBlack,
		TextSize = 17,
		TextColor3 = if enabled then UiKit.colors.text else UiKit.colors.muted,
		Text = text,
		Parent = parent,
	})
	UiKit.corner(button, 10)
	if enabled then
		UiKit.make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1.5, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = button })
		button.Activated:Connect(function()
			Sfx.play("click")
			onClick()
		end)
	end
	return button
end

function UiKit.section(list: Instance, order: number, text: string)
	UiKit.make("TextLabel", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UiKit.colors.muted,
		Text = text:upper(),
		Parent = list,
	})
end

-- One freak in a list: icon with rarity border, name, a detail line, and a button.
function UiKit.freakRow(
	list: Instance,
	order: number,
	freak: { species: string, rarity: string },
	detail: string,
	buttonText: string,
	buttonColor: Color3,
	enabled: boolean,
	onClick: () -> ()
)
	local rarity = Rarities.byId[freak.rarity]
	local row = UiKit.make("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 64),
		BackgroundColor3 = UiKit.colors.row,
		Parent = list,
	})
	UiKit.corner(row, 10)
	local icon = UiKit.make("TextLabel", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = UiKit.colors.panel,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = rarity.color,
		Text = UiKit.glyph(freak.species),
		Parent = row,
	})
	UiKit.corner(icon, 6)
	UiKit.make("UIStroke", { Color = rarity.color, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = icon })
	UiKit.make("TextLabel", {
		Position = UDim2.fromOffset(66, 9),
		Size = UDim2.new(1, -180, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = rarity.color,
		Text = ("%s %s"):format(freak.rarity, freak.species),
		Parent = row,
	})
	UiKit.make("TextLabel", {
		Position = UDim2.fromOffset(66, 33),
		Size = UDim2.new(1, -180, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UiKit.colors.muted,
		Text = detail,
		Parent = row,
	})
	local holder = UiKit.make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(100, 40),
		BackgroundTransparency = 1,
		Parent = row,
	})
	UiKit.button(holder, buttonText, buttonColor, enabled, onClick)
end

-- A plain row: a title, two lines of detail, and a button.
function UiKit.row(
	list: Instance,
	order: number,
	title: string,
	line1: string,
	line2: string,
	buttonText: string,
	buttonColor: Color3,
	enabled: boolean,
	onClick: () -> ()
)
	-- The row grows to fit: long text wraps onto extra lines instead of being
	-- cut off, and 76 px is the minimum height.
	local row = UiKit.make("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 76),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UiKit.colors.row,
		Parent = list,
	})
	UiKit.corner(row, 10)
	local text = UiKit.make("Frame", {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -130, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = row,
	})
	UiKit.make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1), Parent = text })
	UiKit.make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = text })
	for i, line in
		{
			{ text = title, font = Enum.Font.GothamBlack, size = 18, color = UiKit.colors.text },
			{ text = line1, font = Enum.Font.GothamMedium, size = 14, color = UiKit.colors.muted },
			{ text = line2, font = Enum.Font.GothamBold, size = 15, color = UiKit.colors.money },
		}
	do
		UiKit.make("TextLabel", {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 18),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = line.font,
			TextSize = line.size,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = line.color,
			Text = line.text,
			Parent = text,
		})
	end
	local holder = UiKit.make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(100, 40),
		BackgroundTransparency = 1,
		Parent = row,
	})
	UiKit.button(holder, buttonText, buttonColor, enabled, onClick)
end

-- A row of tab buttons in the panel's subtitle area. Calls onSelect(name) and
-- highlights the chosen tab; returns a function to select one from code.
function UiKit.tabs(panel: Panel, names: { string }, onSelect: (string) -> ()): (string) -> ()
	panel.subtitle.Visible = false
	local bar = UiKit.make("Frame", {
		Position = UDim2.fromOffset(16, 70),
		Size = UDim2.new(1, -32, 0, 34),
		BackgroundTransparency = 1,
		Parent = panel.subtitle.Parent,
	})
	UiKit.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = bar })
	local buttons: { [string]: TextButton } = {}
	local function select(name: string)
		for tabName, button in buttons do
			button.BackgroundColor3 = if tabName == name then UiKit.colors.action else UiKit.colors.row
		end
		onSelect(name)
	end
	for _, name in names do
		local button = UiKit.make("TextButton", {
			Size = UDim2.new(1 / #names, -4, 1, 0),
			BackgroundColor3 = UiKit.colors.row,
			Font = Enum.Font.GothamBlack,
			TextSize = 15,
			TextColor3 = UiKit.colors.text,
			Text = name,
			Parent = bar,
		})
		UiKit.corner(button, 8)
		button.Activated:Connect(function()
			Sfx.play("click")
			select(name)
		end)
		buttons[name] = button
	end
	return select
end

function UiKit.emptyNote(list: Instance, order: number, text: string)
	UiKit.make("TextLabel", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UiKit.colors.muted,
		Text = text,
		Parent = list,
	})
end

return UiKit
