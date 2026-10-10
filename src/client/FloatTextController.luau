--!strict
-- Floating text over the player's own head, e.g. "+$1.2M" when collecting at
-- the collection pad or a new Freakpedia entry's reward. Sent by the server
-- through Remotes.FloatText; each one rises and fades. Several at once stack
-- upward so they don't overlap.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local LIFETIME = 1.6
local RISE = 3 -- studs
local STACK = 1.4 -- studs between texts shown at the same time

local FloatTextController = {}

function FloatTextController.start()
	local live = 0

	local function show(text: string, color: Color3)
		local character = player.Character
		local head = character and character:FindFirstChild("Head") :: BasePart?
		if not head then
			return
		end
		local start = 2.5 + live * STACK
		live += 1
		local gui = Instance.new("BillboardGui")
		gui.Name = "FloatText"
		gui.Adornee = head
		gui.Size = UDim2.fromOffset(320, 50)
		gui.StudsOffset = Vector3.new(0, start, 0)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = color
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.TextStrokeTransparency = 0.2
		label.Text = text
		label.Parent = gui
		local scale = Instance.new("UIScale")
		scale.Scale = 0.6
		scale.Parent = label
		gui.Parent = player:WaitForChild("PlayerGui")

		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(gui, TweenInfo.new(LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			StudsOffset = Vector3.new(0, start + RISE, 0),
		}):Play()
		task.delay(LIFETIME * 0.55, function()
			TweenService:Create(label, TweenInfo.new(LIFETIME * 0.45), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end)
		task.delay(LIFETIME, function()
			live -= 1
			gui:Destroy()
		end)
	end

	Remotes.FloatText.OnClientEvent:Connect(show)
end

return FloatTextController
