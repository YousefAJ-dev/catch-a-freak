--!strict
-- Tracks which zone each player is in (by distance from the map center) and
-- enforces tier access: a player found in a ring above their highest unlocked
-- tier is sent back to the shop.
--
-- Mirrors the zone onto the Player as attributes for the HUD:
--   "Zone"     zone name, e.g. "Ring1"
--   "ZoneTier" the ring's tier, or 0 in the safe zone

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local DataService = require(script.Parent.DataService)

local CHECK_INTERVAL = 0.25

local ZoneService = {}

local zoneTiers: { [Player]: number } = {}

-- The tier of the ring the player is standing in, or 0 in the safe zone or
-- when they have no living character.
function ZoneService.getZoneTier(player: Player): number
	return zoneTiers[player] or 0
end

local function shopSpawnCFrame(): CFrame
	local spawn = workspace:WaitForChild("Map"):WaitForChild("Shop"):WaitForChild("ShopSpawn") :: BasePart
	return spawn.CFrame + Vector3.new(0, 4, 0)
end

function ZoneService.sendToShop(player: Player)
	local character = player.Character
	if character then
		character:PivotTo(shopSpawnCFrame())
	end
end

local function update(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (humanoid and root) or humanoid.Health <= 0 then
		zoneTiers[player] = 0
		return
	end

	local zone = Formulas.zoneFromPosition(root.Position)
	local tier = zone.tier or 0
	local data = DataService.get(player)
	if data and tier > data.highestTier then
		ZoneService.sendToShop(player)
		zone = Formulas.zoneFromPosition(shopSpawnCFrame().Position)
		tier = 0
	end

	zoneTiers[player] = tier
	player:SetAttribute("Zone", zone.name)
	player:SetAttribute("ZoneTier", tier)
end

function ZoneService.start()
	Players.PlayerRemoving:Connect(function(player)
		zoneTiers[player] = nil
	end)
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				update(player)
			end
			task.wait(CHECK_INTERVAL)
		end
	end)
end

return ZoneService
