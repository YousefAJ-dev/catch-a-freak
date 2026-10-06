--!strict
-- Owns player health: radiation damage in the rings and regeneration in the
-- safe zone, both applied once per second. Roblox's default regeneration is
-- disabled by the empty "Health" script in StarterCharacterScripts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local PlayerConfig = require(ReplicatedStorage.Shared.Config.Player)
local World = require(ReplicatedStorage.Shared.Config.World)
local DataService = require(script.Parent.DataService)
local ZoneService = require(script.Parent.ZoneService)

local TICK = 1

local RadiationService = {}

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.MaxHealth = PlayerConfig.maxHealth
	humanoid.Health = PlayerConfig.maxHealth
end

local function tick(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local data = DataService.get(player)
	if not (humanoid and data) or humanoid.Health <= 0 then
		return
	end

	local tier = ZoneService.getZoneTier(player)
	if tier > 0 then
		humanoid:TakeDamage(Formulas.radiationDps(tier, data.upgrades.hazmat) * TICK)
	else
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + World.safeZoneRegenPerSecond * TICK)
	end
end

function RadiationService.start()
	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(onCharacterAdded)
		if player.Character then
			task.spawn(onCharacterAdded, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in Players:GetPlayers() do
				tick(player)
			end
		end
	end)
end

return RadiationService
