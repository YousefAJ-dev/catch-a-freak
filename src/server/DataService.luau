--!strict
-- One data record per player (DESIGN.md section 12, "Saved data").
-- In memory only for now; loading and saving arrive in Milestone 6.
--
-- Fields the client needs to display are mirrored onto the Player as
-- attributes ("HighestTier", "Upgrade_<id>"). The record stays the source of
-- truth; never read those attributes back on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)

export type Data = {
	version: number,
	money: number,
	upgrades: { [string]: number },
	items: { [string]: number },
	highestTier: number,
	gateProgress: { boolean },
	farm: { any },
	uncollected: number,
	lastSeen: number,
	wheel: { lastFreeSpinDay: number, extraSpins: number },
	boost2xSecondsLeft: number,
	ownedSkins: { any },
	processedReceipts: { any },
}

local function newData(): Data
	local upgrades = {}
	for id in Upgrades do
		upgrades[id] = 0
	end
	return {
		version = 1,
		money = 0,
		upgrades = upgrades,
		items = { netLauncher = 0, bearTrap = 0 },
		highestTier = 1,
		gateProgress = { false, false },
		farm = {},
		uncollected = 0,
		lastSeen = 0,
		wheel = { lastFreeSpinDay = 0, extraSpins = 0 },
		boost2xSecondsLeft = 0,
		ownedSkins = {},
		processedReceipts = {},
	}
end

local records: { [Player]: Data } = {}

local DataService = {}

function DataService.get(player: Player): Data?
	return records[player]
end

local function replicate(player: Player, data: Data)
	player:SetAttribute("HighestTier", data.highestTier)
	for id, level in data.upgrades do
		player:SetAttribute("Upgrade_" .. id, level)
	end
end

function DataService.setHighestTier(player: Player, tier: number)
	local data = records[player]
	assert(data, "no data for player")
	data.highestTier = math.clamp(math.floor(tier), 1, #Tiers)
	replicate(player, data)
end

function DataService.setUpgradeLevel(player: Player, upgradeId: string, level: number)
	local data = records[player]
	local upgrade = Upgrades[upgradeId]
	assert(data, "no data for player")
	assert(upgrade, "unknown upgrade " .. upgradeId)
	data.upgrades[upgradeId] = math.clamp(math.floor(level), 0, upgrade.maxLevel)
	replicate(player, data)
end

local function onPlayerAdded(player: Player)
	local data = newData()
	records[player] = data
	replicate(player, data)
end

function DataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		records[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return DataService
