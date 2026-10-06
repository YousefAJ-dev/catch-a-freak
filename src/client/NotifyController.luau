--!strict
-- Short on-screen messages sent by the server through Remotes.Notify.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local SHOW_FOR = 2.5

local NotifyController = {}

-- Set by start(); lets other client code show a notice without the server.
local showMessage: ((string) -> ())? = nil

function NotifyController.show(message: string)
	if showMessage then
		showMessage(message)
	end
end

function NotifyController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Notify"
	gui.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	-- Below the radiation warning (HudController).
	label.Position = UDim2.new(0.5, 0, 0, 64)
	label.Size = UDim2.fromOffset(420, 34)
	label.BackgroundColor3 = Color3.fromRGB(25, 28, 34)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextTransparency = 1
	label.Parent = gui
	Instance.new("UICorner", label).CornerRadius = UDim.new(0, 8)
	gui.Parent = player:WaitForChild("PlayerGui")

	local shownAt = 0
	local function show(message: string)
		label.Text = message
		label.TextTransparency = 0
		label.BackgroundTransparency = 0.2
		local stamp = os.clock()
		shownAt = stamp
		task.delay(SHOW_FOR, function()
			if shownAt == stamp then
				TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			end
		end)
	end
	showMessage = show
	Remotes.Notify.OnClientEvent:Connect(show)
end

return NotifyController
