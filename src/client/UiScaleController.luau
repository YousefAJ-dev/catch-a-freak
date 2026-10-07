--!strict
-- Scales every game ScreenGui down on small screens (phones), so the panels,
-- HUD and carry bar fit. The UI is laid out in pixels for a screen at least
-- REFERENCE wide and tall; smaller screens shrink it evenly, down to MIN_SCALE.

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local REFERENCE = Vector2.new(1100, 640)
local MIN_SCALE = 0.55

local UiScaleController = {}

function UiScaleController.start()
	local playerGui = player:WaitForChild("PlayerGui")
	local camera = workspace.CurrentCamera
	local scales: { UIScale } = {}

	local function scaleFor(): number
		local view = camera.ViewportSize
		return math.clamp(math.min(view.X / REFERENCE.X, view.Y / REFERENCE.Y), MIN_SCALE, 1)
	end

	local function adopt(gui: Instance)
		if gui:IsA("ScreenGui") and not gui:FindFirstChild("AutoScale") then
			local scale = Instance.new("UIScale")
			scale.Name = "AutoScale"
			scale.Scale = scaleFor()
			scale.Parent = gui
			table.insert(scales, scale)
		end
	end

	for _, gui in playerGui:GetChildren() do
		adopt(gui)
	end
	playerGui.ChildAdded:Connect(adopt)
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		local s = scaleFor()
		for _, scale in scales do
			scale.Scale = s
		end
	end)
end

return UiScaleController
