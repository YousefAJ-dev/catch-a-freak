--!strict
-- Daily wheel panel (DESIGN.md sections 9 and 11): the Spin prompt at the
-- wheel opens it. It always shows the odds table, the spin button, and the
-- time until the next free spin. The server (WheelService) rolls the prize;
-- this only plays the animation: a pointer sweeps along a strip of prize
-- segments, sized by their odds, and lands on the result while the wheel in
-- the shop spins.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Wheel = require(Shared.Config.Wheel)
local Rarities = require(Shared.Config.Rarities)
local Products = require(Shared.Config.Products)
local UiKit = require(script.Parent.UiKit)
local Purchases = require(script.Parent.Purchases)

local player = Players.LocalPlayer

local PROMPT_RANGE = 12
local SWEEPS = 3 -- full passes along the strip before the pointer settles

local WheelController = {}

local function hasFreeSlot(): boolean
	local ok, slots = pcall(HttpService.JSONDecode, HttpService, (player:GetAttribute("Carry") :: string?) or "[]")
	if not ok then
		return false
	end
	for _, slot in slots do
		if slot == false then
			return true
		end
	end
	return false
end

-- Seconds until today's free spin resets, or 0 if it's available now.
local function freeSpinWait(): number
	local now = workspace:GetServerTimeNow()
	local today = Formulas.utcDay(now)
	if ((player:GetAttribute("WheelLastFreeDay") :: number?) or 0) < today then
		return 0
	end
	return (today + 1) * 86400 - now
end

function WheelController.start()
	local panel = UiKit.panel("WheelPanel", "Daily Wheel")
	local open = false
	local spinning = false
	local awaiting = false -- asked the server to spin, no answer yet
	local lastResult: string? = nil

	-- The strip: one segment per prize, its width proportional to the odds.
	local strip = UiKit.make("Frame", {
		LayoutOrder = 1,
		Size = UDim2.new(1, -6, 0, 54),
		BackgroundTransparency = 1,
	})
	local segments = UiKit.make("Frame", {
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = strip,
	})
	UiKit.corner(segments, 6)
	local starts: { number } = {}
	local x = 0
	for i, prize in Wheel.prizes do
		starts[i] = x
		UiKit.make("Frame", {
			Position = UDim2.fromScale(x, 0),
			Size = UDim2.fromScale(prize.chance, 1),
			BackgroundColor3 = prize.color,
			BorderSizePixel = 0,
			Parent = segments,
		})
		x += prize.chance
	end
	local pointer = UiKit.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromOffset(4, 52),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = strip,
	})
	UiKit.make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5, Parent = pointer })

	local resultLabel = UiKit.make("TextLabel", {
		LayoutOrder = 2,
		Size = UDim2.new(1, -6, 0, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 17,
		TextWrapped = true,
		TextColor3 = UiKit.colors.money,
		Text = "",
	})

	local function prizeText(index: number): (string, Color3)
		local tier = (player:GetAttribute("HighestTier") :: number?) or 1
		local prizeTier, rarity = Formulas.wheelPrize(index, tier)
		return ("%s freak · Tier %d"):format(rarity, prizeTier), Rarities.byId[rarity].color
	end

	local function render()
		panel.gui.Enabled = open and player:GetAttribute("AtWheel") == true
		if not panel.gui.Enabled then
			return
		end
		-- The strip and result label are reused; everything else is rebuilt.
		for _, child in panel.list:GetChildren() do
			if child ~= strip and child ~= resultLabel and not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
		strip.Parent = panel.list
		resultLabel.Parent = panel.list
		resultLabel.Text = lastResult or ""

		UiKit.section(panel.list, 3, "Odds")
		for i, prize in Wheel.prizes do
			local text, color = prizeText(i)
			local row = UiKit.make("Frame", {
				LayoutOrder = 3 + i,
				Size = UDim2.new(1, -6, 0, 26),
				BackgroundColor3 = UiKit.colors.row,
				Parent = panel.list,
			})
			UiKit.corner(row, 6)
			UiKit.make("Frame", { Position = UDim2.fromOffset(8, 7), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = prize.color, Parent = row })
			UiKit.make("TextLabel", {
				Position = UDim2.fromOffset(28, 0),
				Size = UDim2.new(1, -90, 1, 0),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = color,
				Text = text,
				Parent = row,
			})
			UiKit.make("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 0),
				Size = UDim2.fromOffset(60, 26),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = UiKit.colors.text,
				Text = ("%d%%"):format(math.round(prize.chance * 100)),
				Parent = row,
			})
		end

		-- Paid spins are "paid random items" under Roblox policy: offered only
		-- where allowed, and only below the full odds table shown above.
		if player:GetAttribute("PaidRandomItemsRestricted") == false then
			local product = Products.developerProducts.extraSpin
			UiKit.row(panel.list, 10, product.name, product.description, Purchases.productPrice("extraSpin"), "Buy", Color3.fromRGB(0, 160, 110), true, function()
				Purchases.promptProduct("extraSpin")
			end)
		end

		local extra = (player:GetAttribute("WheelExtraSpins") :: number?) or 0
		local wait = freeSpinWait()
		local status = if wait <= 0
			then "Free spin ready!"
			else ("Next free spin in %dh %dm"):format(math.floor(wait / 3600), math.floor(wait % 3600 / 60))
		if extra > 0 then
			status ..= ("  ·  %d extra spin%s"):format(extra, if extra == 1 then "" else "s")
		end
		panel.subtitle.Text = status .. "\nThe prize goes into a free carry slot."

		UiKit.clear(panel.footer)
		local canSpin = not spinning and (wait <= 0 or extra > 0) and hasFreeSlot()
		local label = if spinning then "Spinning…" elseif not hasFreeSlot() then "Free a carry slot" else "Spin"
		UiKit.button(panel.footer, label, UiKit.colors.go, canSpin, function()
			spinning = true
			awaiting = true
			lastResult = nil
			render()
			Remotes.SpinWheel:FireServer()
			-- No result means the server refused (it says why in a notice);
			-- let the player try again.
			task.delay(2, function()
				if awaiting then
					awaiting = false
					spinning = false
					render()
				end
			end)
		end)
	end

	-- Play the landing animation for a result from the server.
	Remotes.WheelResult.OnClientEvent:Connect(function(index: number, tier: number, rarity: string, species: string)
		awaiting = false
		spinning = true
		local landing = starts[index] + Wheel.prizes[index].chance * (0.2 + 0.6 * math.random())
		local wheelPart = workspace:FindFirstChild("Map")
			and workspace.Map:FindFirstChild("Shop")
			and workspace.Map.Shop:FindFirstChild("DailyWheel")
			and workspace.Map.Shop.DailyWheel:FindFirstChild("Wheel") :: BasePart?
		local wheelStart = if wheelPart then wheelPart.CFrame else nil
		local started = os.clock()
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local t = math.clamp((os.clock() - started) / Wheel.spinSeconds, 0, 1)
			local eased = 1 - (1 - t) ^ 3
			pointer.Position = UDim2.fromScale((eased * (SWEEPS + landing)) % 1, 0)
			if wheelPart and wheelStart then
				-- The cylinder's axis is X: spinning about it turns the disc.
				wheelPart.CFrame = wheelStart * CFrame.Angles(eased * math.pi * 2 * (SWEEPS + landing), 0, 0)
			end
			if t >= 1 then
				connection:Disconnect()
				pointer.Position = UDim2.fromScale(landing, 0)
				spinning = false
				lastResult = ("You won %s %s %s (Tier %d)!"):format(Format.article(rarity), rarity, species, tier)
				render()
			end
		end)
	end)

	panel.close.Activated:Connect(function()
		open = false
		render()
	end)
	player:GetAttributeChangedSignal("AtWheel"):Connect(function()
		if player:GetAttribute("AtWheel") ~= true then
			open = false
		end
		render()
	end)
	task.spawn(Purchases.productPrice, "extraSpin") -- fetch the price once, in the background
	for _, attribute in { "WheelLastFreeDay", "WheelExtraSpins", "Carry", "HighestTier", "PaidRandomItemsRestricted" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if not spinning then
				render()
			end
		end)
	end
	-- Keep the countdown fresh while the panel is open.
	task.spawn(function()
		while true do
			task.wait(30)
			if panel.gui.Enabled and not spinning then
				render()
			end
		end
	end)

	task.spawn(function()
		local wheel = workspace:WaitForChild("Map"):WaitForChild("Shop"):WaitForChild("DailyWheel"):WaitForChild("Wheel") :: BasePart
		UiKit.localPrompt("WheelPrompt", wheel.Position - Vector3.new(0, 4, 0), "Spin", "Daily Wheel", PROMPT_RANGE, function()
			open = true
			render()
		end)
	end)
	render()
end

return WheelController
