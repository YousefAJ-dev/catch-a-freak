--!strict
-- Applies player stats to their character: max health on spawn, and walk speed
-- from the Shoes upgrade on spawn and whenever the upgrade changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
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

function CharacterService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return CharacterService
