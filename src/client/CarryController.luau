--!strict
-- Carry bar: the player's 9 carry slots along the bottom of the screen. Display
-- only; CarryService on the server owns the slots and mirrors them into the
-- "Carry" player attribute. Replaces the default Roblox backpack.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local PlayerConfig = require(ReplicatedStorage.Shared.Config.Player)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer

local SLOT = 56
local GAP = 6

local CarryController = {}

type SlotUi = { frame: Frame, stroke: UIStroke, glyph: TextLabel, name: TextLabel }

local function buildBar(): { SlotUi }
	local gui = Instance.new("ScreenGui")
	gui.Name = "CarryBar"
	gui.ResetOnSpawn = false

	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -16)
	bar.Size = UDim2.fromOffset(PlayerConfig.carrySlots * (SLOT + GAP) - GAP, SLOT)
	bar.BackgroundTransparency = 1
	bar.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, GAP)
	layout.Parent = bar

	local slots = {}
	for i = 1, PlayerConfig.carrySlots do
		local frame = Instance.new("Frame")
		frame.Name = "Slot" .. i
		frame.LayoutOrder = i
		frame.Size = UDim2.fromOffset(SLOT, SLOT)
		frame.BackgroundColor3 = Color3.fromRGB(25, 28, 34)
		frame.BackgroundTransparency = 0.35
		frame.Parent = bar
		Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = frame

		local glyph = Instance.new("TextLabel")
		glyph.Size = UDim2.new(1, 0, 0.62, 0)
		glyph.BackgroundTransparency = 1
		glyph.Font = Enum.Font.GothamBlack
		glyph.TextScaled = true
		glyph.Parent = frame

		local name = Instance.new("TextLabel")
		name.Position = UDim2.fromScale(0.05, 0.62)
		name.Size = UDim2.fromScale(0.9, 0.32)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamBold
		name.TextScaled = true
		name.TextColor3 = Color3.new(1, 1, 1)
		name.Parent = frame

		slots[i] = { frame = frame, stroke = stroke, glyph = glyph, name = name }
	end

	gui.Parent = player:WaitForChild("PlayerGui")
	return slots
end

function CarryController.start()
	-- The custom carry bar replaces the Roblox backpack. SetCoreGuiEnabled can
	-- fail very early in a session, so retry briefly.
	task.spawn(function()
		for _ = 1, 20 do
			if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then
				break
			end
			task.wait(0.25)
		end
	end)

	local slots = buildBar()

	local function render()
		local raw = player:GetAttribute("Carry") :: string?
		local ok, contents = pcall(HttpService.JSONDecode, HttpService, raw or "[]")
		for i, ui in slots do
			local freak = ok and contents[i]
			if freak then
				local rarity = Rarities.byId[freak.rarity]
				ui.stroke.Color = rarity.color
				ui.stroke.Thickness = 3
				ui.stroke.Transparency = 0
				ui.glyph.Text = UiKit.glyph(freak.species)
				ui.glyph.TextColor3 = rarity.color
				ui.name.Text = freak.species
			else
				ui.stroke.Color = Color3.fromRGB(120, 125, 135)
				ui.stroke.Thickness = 1.5
				ui.stroke.Transparency = 0.5
				ui.glyph.Text = ""
				ui.name.Text = ""
			end
		end
	end
	player:GetAttributeChangedSignal("Carry"):Connect(render)
	render()
end

return CarryController
