--!strict
-- 2x Money pads (DESIGN.md section 10): a pad beside each plot's collection
-- pad. Each client styles them locally: the player's own pad glows gold with
-- a "2x MONEY" label (or "2x MONEY ✓" once they own the pass); everyone
-- else's is plain grey and unlabeled. Stepping onto your own pad opens the
-- Game Pass purchase prompt, once per visit to the pad. The purchase itself is
-- granted on the server (MonetizationService).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Products = require(ReplicatedStorage.Shared.Config.Products)
local Purchases = require(script.Parent.Purchases)

local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(215, 125, 0) -- Neon blooms brighter than this
local OTHER = Color3.fromRGB(95, 100, 105)
local CHECK_INTERVAL = 0.15
local STAND_HEIGHT = 6 -- how far above the pad the player's root can be and still count

local MoneyPadController = {}

local function ownsPass(): boolean
	local ok, passes = pcall(HttpService.JSONDecode, HttpService, (player:GetAttribute("OwnedPasses") :: string?) or "[]")
	return ok and table.find(passes, Products.passes.money2x.key) ~= nil
end

local function isOwn(pad: Instance): boolean
	local plot = pad.Parent
	return plot ~= nil and plot:GetAttribute("PlotIndex") == player:GetAttribute("PlotIndex")
end

local function stylePad(pad: Instance)
	if not (pad:IsA("BasePart") and pad.Name == "MoneyPad") then
		return
	end
	local own = isOwn(pad)
	pad.Color = if own then GOLD else OTHER
	pad.Material = if own then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local light = pad:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = own
	end
	local label = pad:FindFirstChild("Label") :: BillboardGui?
	if label then
		label.Enabled = own
		local text = label:FindFirstChildOfClass("TextLabel")
		if text then
			text.Text = if ownsPass() then "2x MONEY ✓" else "2x MONEY"
		end
	end
end

function MoneyPadController.start()
	task.spawn(function()
		local plots = workspace:WaitForChild("Map"):WaitForChild("Plots")
		local function styleAll()
			for _, pad in plots:GetDescendants() do
				stylePad(pad)
			end
		end
		plots.DescendantAdded:Connect(stylePad) -- pads streaming back in
		player:GetAttributeChangedSignal("PlotIndex"):Connect(styleAll)
		player:GetAttributeChangedSignal("OwnedPasses"):Connect(styleAll)
		styleAll()

		-- Prompt when the player steps onto their own pad (not again until
		-- they've stepped off).
		local onPad = false
		while true do
			task.wait(CHECK_INTERVAL)
			local index = player:GetAttribute("PlotIndex")
			local plot = index and plots:FindFirstChild("Plot" .. tostring(index))
			local pad = plot and plot:FindFirstChild("MoneyPad") :: BasePart?
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local now = false
			if pad and root then
				local relative = pad.CFrame:PointToObjectSpace(root.Position)
				now = math.abs(relative.X) <= pad.Size.X / 2
					and math.abs(relative.Z) <= pad.Size.Z / 2
					and relative.Y >= 0
					and relative.Y <= STAND_HEIGHT
			end
			if now and not onPad and not ownsPass() then
				Purchases.promptPass(Products.passes.money2x)
			end
			onPad = now
		end
	end)
end

return MoneyPadController
