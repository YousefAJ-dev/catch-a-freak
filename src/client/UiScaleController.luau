--!strict
-- Scales every game ScreenGui down on small screens (phones), so the panels,
-- HUD and carry bar fit. Roblox's TouchGui and guis marked NoAutoScale
-- (TouchLayout) are left at full size. The UI is laid out in pixels for a screen at least
-- REFERENCE wide and tall; smaller screens shrink it evenly, down to MIN_SCALE.

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local REFERENCE = Vector2.new(1100, 640)
local MIN_SCALE = 0.55

local UiScaleController = {}

function UiScaleController.start()
	local playerGui = player:WaitForChild("PlayerGui")
	local camera = workspace.CurrentCamera
	local updaters: { () -> () } = {}

	local function scaleFor(): number
		local view = camera.ViewportSize
		return math.clamp(math.min(view.X / REFERENCE.X, view.Y / REFERENCE.Y), MIN_SCALE, 1)
	end

	local function adopt(gui: Instance)
		-- Roblox's own touch controls (thumbstick, jump) keep their native size.
		if not gui:IsA("ScreenGui") or gui.Name == "TouchGui" or gui:FindFirstChild("AutoScale") then
			return
		end
		local scale = Instance.new("UIScale")
		scale.Name = "AutoScale"
		scale.Parent = gui
		-- A gui with the NoAutoScale attribute sizes itself (TouchLayout's
		-- controls, which sit by the touch jump button that Roblox doesn't scale).
		local function update()
			scale.Scale = if gui:GetAttribute("NoAutoScale") then 1 else scaleFor()
		end
		gui:GetAttributeChangedSignal("NoAutoScale"):Connect(update)
		update()
		table.insert(updaters, update)
	end

	for _, gui in playerGui:GetChildren() do
		adopt(gui)
	end
	playerGui.ChildAdded:Connect(adopt)
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		for _, update in updaters do
			update()
		end
	end)
end

return UiScaleController
