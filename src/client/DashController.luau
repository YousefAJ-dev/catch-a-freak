--!strict
-- Dash (DESIGN.md section 4): F, or the on-screen button for mobile, bursts the
-- player about 50 studs in the direction they're moving (or facing). The
-- character's physics run on this client, so the dash starts instantly here;
-- CharacterService on the server enforces the cooldown and publishes when the
-- next dash is ready ("DashReadyAt"). Walls and closed doors still stop a dash.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local DashConfig = require(ReplicatedStorage.Shared.Config.Dash)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer

local BUTTON = 64

local DashController = {}

local localReadyAt = 0 -- our own guess, so a double-press can't sneak in before the server's reply

local function ownsDash(): boolean
	return ((player:GetAttribute("Upgrade_dash") :: number?) or 0) >= 1
end

local function readyAt(): number
	return math.max(localReadyAt, (player:GetAttribute("DashReadyAt") :: number?) or 0)
end

local function dash()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (ownsDash() and humanoid and root) or humanoid.Health <= 0 then
		return
	end
	local now = workspace:GetServerTimeNow()
	if now < readyAt() then
		return
	end
	localReadyAt = now + Formulas.dashCooldown((player:GetAttribute("Upgrade_dashRecharge") :: number?) or 0)
	Remotes.Dash:FireServer()

	-- Direction: where the player is steering, or where they face if standing still.
	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		direction = root.CFrame.LookVector
	end
	direction = Vector3.new(direction.X, 0, direction.Z).Unit

	-- A horizontal-only velocity constraint: it overpowers walking for the
	-- burst while leaving gravity alone, and collisions still apply.
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local push = Instance.new("LinearVelocity")
	push.Attachment0 = attachment
	push.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	push.MaxAxesForce = Vector3.new(1e6, 0, 1e6)
	push.VectorVelocity = direction * (DashConfig.distance / DashConfig.duration)
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.Parent = root
	task.delay(DashConfig.duration, function()
		push:Destroy()
		attachment:Destroy()
	end)
end

local function buildButton(): (TextButton, Frame, TextLabel)
	local gui = UiKit.make("ScreenGui", { Name = "DashButton", ResetOnSpawn = false })
	-- Right of the Net and Trap buttons.
	local button = UiKit.make("TextButton", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.5, 292 + (BUTTON + 8) * 2, 1, -16),
		Size = UDim2.fromOffset(BUTTON, BUTTON),
		BackgroundColor3 = UiKit.colors.panel,
		BackgroundTransparency = 0.15,
		Text = "",
		Visible = false,
		Parent = gui,
	})
	UiKit.corner(button, 10)
	UiKit.make("UIStroke", { Color = Color3.fromRGB(90, 100, 115), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = button })
	-- Darkens from the top while recharging and shrinks away as it recovers.
	local shade = UiKit.make("Frame", {
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		ZIndex = 2,
		Parent = button,
	})
	UiKit.corner(shade, 10)
	UiKit.make("TextLabel", {
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.fromOffset(20, 16),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UiKit.colors.muted,
		Text = DashConfig.key.Name,
		ZIndex = 3,
		Parent = button,
	})
	local label = UiKit.make("TextLabel", {
		Position = UDim2.new(0, 4, 0.32, 0),
		Size = UDim2.new(1, -8, 0.36, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = UiKit.colors.text,
		Text = "Dash",
		ZIndex = 3,
		Parent = button,
	})
	gui.Parent = player:WaitForChild("PlayerGui")
	return button, shade, label
end

-- Same as pressing F; exposed for scripted tests.
DashController.dash = dash

function DashController.start()
	local button, shade, label = buildButton()
	button.Activated:Connect(dash)

	local function refreshOwned()
		button.Visible = ownsDash()
	end
	player:GetAttributeChangedSignal("Upgrade_dash"):Connect(refreshOwned)
	refreshOwned()

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == DashConfig.key then
			dash()
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not button.Visible then
			return
		end
		local remaining = readyAt() - workspace:GetServerTimeNow()
		local cooldown = Formulas.dashCooldown((player:GetAttribute("Upgrade_dashRecharge") :: number?) or 0)
		if remaining > 0 then
			shade.Size = UDim2.fromScale(1, math.clamp(remaining / cooldown, 0, 1))
			label.Text = ("%.1f"):format(remaining)
		else
			shade.Size = UDim2.fromScale(1, 0)
			label.Text = "Dash"
		end
	end)
end

return DashController
