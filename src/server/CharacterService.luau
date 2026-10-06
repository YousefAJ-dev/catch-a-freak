--!strict
-- Applies player stats to their character: max health on spawn, walk speed
-- from the Shoes upgrade on spawn and whenever the upgrade changes, and the
-- dash cooldown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerConfig = require(ReplicatedStorage.Shared.Config.Player)
local DataService = require(script.Parent.DataService)

local CharacterService = {}

local function applyWalkSpeed(player: Player)
	local data = DataService.get(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if data and humanoid then
		humanoid.WalkSpeed = Formulas.walkSpeed(data.upgrades.shoes)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.MaxHealth = PlayerConfig.maxHealth
	humanoid.Health = PlayerConfig.maxHealth
	applyWalkSpeed(player)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	player:GetAttributeChangedSignal("Upgrade_shoes"):Connect(function()
		applyWalkSpeed(player)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

-- Dash: the client moves its own character (Roblox runs character physics on
-- the owning client), so the server's job is the cooldown. It accepts a dash
-- only from a player who owns it and whose cooldown has passed, and publishes
-- when the next one is ready as the "DashReadyAt" attribute (server time).
local DASH_TOLERANCE = 0.25 -- seconds of network jitter forgiven
local dashReadyAt: { [Player]: number } = {}

local function onDash(player: Player)
	local data = DataService.get(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not (data and humanoid) or humanoid.Health <= 0 or (data.upgrades.dash or 0) < 1 then
		return
	end
	local now = workspace:GetServerTimeNow()
	if now < (dashReadyAt[player] or 0) - DASH_TOLERANCE then
		return
	end
	local readyAt = now + Formulas.dashCooldown(data.upgrades.dashRecharge or 0)
	dashReadyAt[player] = readyAt
	player:SetAttribute("DashReadyAt", readyAt)
end

function CharacterService.start()
	Remotes.Dash.OnServerEvent:Connect(onDash)
	Players.PlayerRemoving:Connect(function(player)
		dashReadyAt[player] = nil
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return CharacterService
