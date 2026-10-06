--!strict
-- Small helpers shared by the client's UI controllers so panels look alike.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local FreakConfig = require(ReplicatedStorage.Shared.Config.Freaks)

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
}

-- A panel docked on the right edge of the screen, hidden until enabled.
function UiKit.panel(name: string, title: string): Panel
	local gui = UiKit.make("ScreenGui", { Name = name, ResetOnSpawn = false, Enabled = false })
	local frame = UiKit.make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, -20),
		Size = UDim2.fromOffset(330, 420),
		BackgroundColor3 = UiKit.colors.panel,
		BackgroundTransparency = 0.1,
		Parent = gui,
	})
	UiKit.corner(frame, 12)
	UiKit.make("UIStroke", { Color = Color3.fromRGB(70, 80, 95), Thickness = 1.5, Parent = frame })

	local titleLabel = UiKit.make("TextLabel", {
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 0, 28),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UiKit.colors.text,
		Text = title,
		Parent = frame,
	})
	local subtitle = UiKit.make("TextLabel", {
		Position = UDim2.fromOffset(16, 40),
		Size = UDim2.new(1, -32, 0, 36),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = UiKit.colors.muted,
		Text = "",
		Parent = frame,
	})
	local list = UiKit.make("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 82),
		Size = UDim2.new(1, -24, 1, -146),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = frame,
	})
	UiKit.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local footer = UiKit.make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.new(1, -24, 0, 46),
		BackgroundTransparency = 1,
		Parent = frame,
	})

	gui.Parent = player:WaitForChild("PlayerGui")
	return { gui = gui, title = titleLabel, subtitle = subtitle, list = list, footer = footer }
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
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = if enabled then UiKit.colors.text else UiKit.colors.muted,
		Text = text,
		Parent = parent,
	})
	UiKit.corner(button, 8)
	if enabled then
		button.Activated:Connect(onClick)
	end
	return button
end

function UiKit.section(list: Instance, order: number, text: string)
	UiKit.make("TextLabel", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
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
		Size = UDim2.new(1, -6, 0, 52),
		BackgroundColor3 = UiKit.colors.row,
		Parent = list,
	})
	UiKit.corner(row, 8)
	local icon = UiKit.make("TextLabel", {
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = UiKit.colors.panel,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = rarity.color,
		Text = UiKit.glyph(freak.species),
		Parent = row,
	})
	UiKit.corner(icon, 6)
	UiKit.make("UIStroke", { Color = rarity.color, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = icon })
	UiKit.make("TextLabel", {
		Position = UDim2.fromOffset(54, 6),
		Size = UDim2.new(1, -150, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = rarity.color,
		Text = ("%s %s"):format(freak.rarity, freak.species),
		Parent = row,
	})
	UiKit.make("TextLabel", {
		Position = UDim2.fromOffset(54, 27),
		Size = UDim2.new(1, -150, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UiKit.colors.muted,
		Text = detail,
		Parent = row,
	})
	local holder = UiKit.make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(84, 34),
		BackgroundTransparency = 1,
		Parent = row,
	})
	UiKit.button(holder, buttonText, buttonColor, enabled, onClick)
end

function UiKit.emptyNote(list: Instance, order: number, text: string)
	UiKit.make("TextLabel", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UiKit.colors.muted,
		Text = text,
		Parent = list,
	})
end

return UiKit
