--!strict
-- Centered message the player dismisses (DESIGN.md section 11, "Popups"):
-- offline earnings on join now; revive offers and tier unlocks later.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer

local PopupController = {}

function PopupController.start()
	local gui = UiKit.make("ScreenGui", { Name = "Popup", ResetOnSpawn = false, Enabled = false, DisplayOrder = 10 })
	local frame = UiKit.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(450, 250),
		BackgroundColor3 = UiKit.colors.panel,
		Parent = gui,
	})
	UiKit.corner(frame, 16)
	UiKit.make("UIStroke", { Color = UiKit.colors.money, Thickness = 3, Parent = frame })
	local title = UiKit.make("TextLabel", {
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.new(1, -40, 0, 36),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 30,
		TextColor3 = UiKit.colors.text,
		Parent = frame,
	})
	local body = UiKit.make("TextLabel", {
		Position = UDim2.fromOffset(20, 62),
		Size = UDim2.new(1, -40, 0, 110),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 18,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = UiKit.colors.text,
		Parent = frame,
	})
	local holder = UiKit.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(170, 46),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	UiKit.button(holder, "Nice!", UiKit.colors.go, true, function()
		gui.Enabled = false
	end)
	gui.Parent = player:WaitForChild("PlayerGui")

	Remotes.Popup.OnClientEvent:Connect(function(titleText: string, bodyText: string)
		title.Text = titleText
		body.Text = bodyText
		gui.Enabled = true
	end)
end

return PopupController
