--!strict
-- HUD: money (top right), health bar, and a radiation warning while in a ring. Display
-- only; the server owns money (DataService) and health (RadiationService).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Format = require(ReplicatedStorage.Shared.Format)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

local player = Players.LocalPlayer

local HEALTH_FULL = Color3.fromRGB(80, 220, 110)
local HEALTH_LOW = Color3.fromRGB(230, 60, 60)
local WARNING = Color3.fromRGB(255, 70, 50)
local MONEY_GREEN = Color3.fromRGB(120, 255, 140)
local MONEY_SPENT = Color3.fromRGB(255, 110, 90)

local BUMP = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FLASH = TweenInfo.new(0.5)
local FLOAT = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local HudController = {}

local function make(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	inst.Parent = props.Parent
	return inst
end

local function corner(parent: Instance, radius: number)
	make("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function buildGui()
	local gui = make("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Health bar: bottom center, leaving room below for the carry bar.
	local health = make("Frame", {
		Name = "Health",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -96),
		Size = UDim2.fromOffset(300, 26),
		BackgroundColor3 = Color3.fromRGB(25, 28, 34),
		BackgroundTransparency = 0.2,
		Parent = gui,
	})
	corner(health, 8)
	make("UIStroke", { Color = Color3.fromRGB(0, 0, 0), Transparency = 0.5, Thickness = 1.5, Parent = health })
	local fill = make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = HEALTH_FULL,
		BorderSizePixel = 0,
		Parent = health,
	})
	corner(fill, 8)
	local text = make("TextLabel", {
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.4,
		Text = "",
		ZIndex = 2,
		Parent = health,
	})

	-- Radiation warning: top center, shown only while in a ring.
	local warning = make("TextLabel", {
		Name = "RadiationWarning",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(360, 40),
		BackgroundColor3 = Color3.fromRGB(60, 10, 8),
		BackgroundTransparency = 0.25,
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		TextColor3 = WARNING,
		Text = "",
		Visible = false,
		Parent = gui,
	})
	corner(warning, 10)
	local stroke = make("UIStroke", {
		Color = WARNING,
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = warning,
	})

	-- Money: top right, below the Roblox top bar. A glowing green badge with a
	-- coin, so it's the first thing the eye finds.
	local moneyFrame = make("Frame", {
		Name = "Money",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 12),
		Size = UDim2.fromOffset(290, 64),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = gui,
	})
	corner(moneyFrame, 16)
	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(20, 70, 38), Color3.fromRGB(12, 30, 20)),
		Rotation = 90,
		Parent = moneyFrame,
	})
	make("UIStroke", { Color = MONEY_GREEN, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = moneyFrame })
	make("UIScale", { Name = "Bump", Parent = moneyFrame })
	local coin = make("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = Color3.fromRGB(255, 205, 50),
		Font = Enum.Font.GothamBlack,
		TextSize = 30,
		TextColor3 = Color3.fromRGB(120, 80, 0),
		Text = "$",
		Parent = moneyFrame,
	})
	corner(coin, 23)
	make("UIStroke", { Color = Color3.fromRGB(255, 240, 160), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = coin })
	local money = make("TextLabel", {
		Position = UDim2.fromOffset(64, 0),
		Size = UDim2.new(1, -76, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = MONEY_GREEN,
		TextStrokeColor3 = Color3.fromRGB(0, 40, 10),
		TextStrokeTransparency = 0.2,
		Text = "$0",
		Parent = moneyFrame,
	})

	-- 2x Money timer, under the money display while the boost is active.
	local boost = make("TextLabel", {
		Name = "Boost",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 86),
		Size = UDim2.fromOffset(290, 30),
		BackgroundColor3 = Color3.fromRGB(255, 200, 40),
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(40, 30, 0),
		Text = "",
		Visible = false,
		Parent = gui,
	})
	corner(boost, 8)

	return fill, text, warning, stroke, money, boost
end

function HudController.start()
	-- The custom bar replaces Roblox's default health display.
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Health, false)

	local fill, text, warning, stroke, money, boost = buildGui()

	-- Gains bump the badge and float a "+$X" under it; spending flashes it red.
	local moneyFrame = money.Parent :: Frame
	local bump = moneyFrame:FindFirstChild("Bump") :: UIScale
	local shown = (player:GetAttribute("Money") :: number?) or 0
	local function updateMoney()
		local value = (player:GetAttribute("Money") :: number?) or 0
		local change = value - shown
		shown = value
		money.Text = Format.money(value)
		if change == 0 then
			return
		end
		bump.Scale = if change > 0 then 1.12 else 0.94
		TweenService:Create(bump, BUMP, { Scale = 1 }):Play()
		money.TextColor3 = if change > 0 then Color3.new(1, 1, 1) else MONEY_SPENT
		TweenService:Create(money, FLASH, { TextColor3 = MONEY_GREEN }):Play()
		if change > 0 then
			local top = if boost.Visible then 120 else 80 -- below the 2x timer when it shows
			local float = make("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -16, 0, top),
				Size = UDim2.fromOffset(200, 28),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				TextSize = 24,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = MONEY_GREEN,
				TextStrokeTransparency = 0.3,
				Text = "+" .. Format.money(change),
				Parent = moneyFrame.Parent,
			})
			TweenService:Create(float, FLOAT, { Position = UDim2.new(1, -16, 0, top + 40), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.delay(FLOAT.Time, function()
				float:Destroy()
			end)
		end
	end
	player:GetAttributeChangedSignal("Money"):Connect(updateMoney)
	updateMoney()

	local function updateBoost()
		local seconds = (player:GetAttribute("Boost2xSecondsLeft") :: number?) or 0
		boost.Visible = seconds > 0
		if seconds > 0 then
			local h, m, s = seconds // 3600, (seconds % 3600) // 60, seconds % 60
			boost.Text = if h > 0 then ("2x MONEY  %d:%02d:%02d"):format(h, m, s) else ("2x MONEY  %d:%02d"):format(m, s)
		end
	end
	player:GetAttributeChangedSignal("Boost2xSecondsLeft"):Connect(updateBoost)
	updateBoost()

	-- HP per second from carried radioactive freaks (RadiationService).
	local function carriedDamage(): number
		local ok, slots = pcall(HttpService.JSONDecode, HttpService, (player:GetAttribute("Carry") :: string?) or "[]")
		local total = 0
		for _, freak in if ok then slots else {} do
			local rarity = freak and Rarities.byId[freak.rarity]
			total += rarity and rarity.damagePerSecond or 0
		end
		return total
	end

	local function updateWarning()
		local tier = (player:GetAttribute("ZoneTier") :: number?) or 0
		local carried = carriedDamage()
		warning.Visible = tier > 0 or carried > 0
		local hazmat = (player:GetAttribute("Upgrade_hazmat") :: number?) or 0
		-- One decimal at most, without a trailing ".0" (3.6, 6 rather than 3.5999…, 6.0).
		local dps = ("%.1f"):format((if tier > 0 then Formulas.radiationDps(tier, hazmat) else 0) + carried):gsub("%.0$", "")
		if tier > 0 then
			warning.Text = ("☢  RING %d RADIATION  −%s HP/s"):format(tier, dps)
		elseif carried > 0 then
			warning.Text = ("☢  RADIOACTIVE FREAK  −%s HP/s"):format(dps)
		end
	end
	player:GetAttributeChangedSignal("ZoneTier"):Connect(updateWarning)
	player:GetAttributeChangedSignal("Upgrade_hazmat"):Connect(updateWarning)
	player:GetAttributeChangedSignal("Carry"):Connect(updateWarning)
	updateWarning()

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
			fill.Size = UDim2.fromScale(ratio, 1)
			fill.BackgroundColor3 = HEALTH_LOW:Lerp(HEALTH_FULL, ratio)
			text.Text = ("%d / %d"):format(math.ceil(humanoid.Health), humanoid.MaxHealth)
		end
		if warning.Visible then
			-- Pulse the warning so it reads as urgent.
			local pulse = (math.sin(os.clock() * 5) + 1) / 2
			stroke.Transparency = pulse * 0.7
		end
	end)
end

return HudController
