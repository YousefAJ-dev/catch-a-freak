--!strict
-- Radiation damage in the rings and regeneration in the safe zone, both
-- applied once per second. Carrying a freak of a rarity with damagePerSecond
-- (Radioactive) also hurts, anywhere, regardless of the Hazmat Suit. Roblox's default regeneration is disabled by the
-- empty "Health" script in StarterCharacterScripts; CharacterService sets max
-- health on spawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local World = require(ReplicatedStorage.Shared.Config.World)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local DataService = require(script.Parent.DataService)
local ZoneService = require(script.Parent.ZoneService)
local CarryService = require(script.Parent.CarryService)

local TICK = 1

local RadiationService = {}

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
	local carried = 0
	for _, freak in CarryService.get(player) or {} do
		if freak then
			carried += Rarities.byId[freak.rarity].damagePerSecond or 0
		end
	end
	if carried > 0 then
		humanoid:TakeDamage(carried * TICK)
	end
end

function RadiationService.start()
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
