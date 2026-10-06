--!strict
-- Revive offer (DESIGN.md sections 4 and 10): after dying while carrying any
-- freak, a short offer to buy "Respawn with Caught Freaks". The server holds
-- the lost freaks and restores them when the purchase is granted
-- (MonetizationService); this only shows the offer and starts the purchase.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiKit = require(script.Parent.UiKit)
local Purchases = require(script.Parent.Purchases)

local player = Players.LocalPlayer

local ReviveController = {}

function ReviveController.start()
	local gui = UiKit.make("ScreenGui", { Name = "ReviveOffer", ResetOnSpawn = false, Enabled = false, DisplayOrder = 11 })
	local frame = UiKit.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(380, 190),
		BackgroundColor3 = UiKit.colors.panel,
		Parent = gui,
	})
	UiKit.corner(frame, 14)
	UiKit.make("UIStroke", { Color = Color3.fromRGB(255, 90, 70), Thickness = 2, Parent = frame })
	local title = UiKit.make("TextLabel", {
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(1, -40, 0, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 24,
		TextColor3 = UiKit.colors.text,
		Text = "You were overcome by radiation",
		Parent = frame,
	})
	local body = UiKit.make("TextLabel", {
		Position = UDim2.fromOffset(20, 50),
		Size = UDim2.new(1, -40, 0, 50),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 16,
		TextWrapped = true,
		TextColor3 = UiKit.colors.text,
		Parent = frame,
	})
	local buyHolder = UiKit.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(1, -40, 0, 44),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	local countdown = UiKit.make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = Color3.fromRGB(255, 90, 70),
		BorderSizePixel = 0,
		Parent = frame,
	})
	gui.Parent = player:WaitForChild("PlayerGui")

	local endsAt = 0
	local shownFor = 1

	local function hide()
		gui.Enabled = false
	end

	Remotes.ReviveOffer.OnClientEvent:Connect(function(count: number, offerEndsAt: number)
		endsAt = offerEndsAt
		shownFor = math.max(offerEndsAt - workspace:GetServerTimeNow(), 0.1)
		title.Text = "You were overcome by radiation"
		body.Text = ("You dropped %d freak%s. Respawn at the shop still carrying all of them?"):format(count, if count == 1 then "" else "s")
		UiKit.clear(buyHolder)
		UiKit.button(buyHolder, ("Respawn with freaks  ·  %s"):format(Purchases.productPrice("revive")), Color3.fromRGB(0, 160, 110), true, function()
			Purchases.promptProduct("revive")
		end)
		gui.Enabled = true
	end)
	Remotes.ReviveDone.OnClientEvent:Connect(hide)

	RunService.RenderStepped:Connect(function()
		if gui.Enabled then
			local left = endsAt - workspace:GetServerTimeNow()
			countdown.Size = UDim2.new(math.clamp(left / shownFor, 0, 1), 0, 0, 4)
			if left <= 0 then
				hide()
			end
		end
	end)
	task.spawn(Purchases.productPrice, "revive") -- fetch the price once, in the background
end

return ReviveController
