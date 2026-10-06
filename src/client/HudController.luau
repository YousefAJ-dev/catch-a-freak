--!strict
-- HUD: money, health bar, and a radiation warning while in a ring. Display
-- only; the server owns money (DataService) and health (RadiationService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Format = require(ReplicatedStorage.Shared.Format)

local player = Players.LocalPlayer

local HEALTH_FULL = Color3.fromRGB(80, 220, 110)
local HEALTH_LOW = Color3.fromRGB(230, 60, 60)
local WARNING = Color3.fromRGB(255, 70, 50)

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

	-- Money: top left, below the Roblox top bar.
	local money = make("TextLabel", {
		Name = "Money",
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.fromOffset(200, 40),
		BackgroundColor3 = Color3.fromRGB(25, 28, 34),
		BackgroundTransparency = 0.2,
		Font = Enum.Font.GothamBlack,
		TextSize = 24,
		TextColor3 = Color3.fromRGB(120, 255, 140),
		Text = "$0",
		Parent = gui,
	})
	corner(money, 10)

	-- 2x Money timer, under the money display while the boost is active.
	local boost = make("TextLabel", {
		Name = "Boost",
		Position = UDim2.fromOffset(16, 58),
		Size = UDim2.fromOffset(200, 28),
		BackgroundColor3 = Color3.fromRGB(255, 200, 40),
		Font = Enum.Font.GothamBlack,
		TextSize = 16,
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

	local function updateMoney()
		money.Text = Format.money((player:GetAttribute("Money") :: number?) or 0)
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

	local function updateWarning()
		local tier = (player:GetAttribute("ZoneTier") :: number?) or 0
		warning.Visible = tier > 0
		if tier > 0 then
			local hazmat = (player:GetAttribute("Upgrade_hazmat") :: number?) or 0
			-- One decimal at most, without a trailing ".0" (3.6, 6 rather than 3.5999…, 6.0).
			local dps = ("%.1f"):format(Formulas.radiationDps(tier, hazmat)):gsub("%.0$", "")
			warning.Text = ("☢  RING %d RADIATION  −%s HP/s"):format(tier, dps)
		end
	end
	player:GetAttributeChangedSignal("ZoneTier"):Connect(updateWarning)
	player:GetAttributeChangedSignal("Upgrade_hazmat"):Connect(updateWarning)
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
