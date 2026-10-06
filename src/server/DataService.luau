--!strict
-- One data record per player (DESIGN.md section 12, "Saved data").
-- In memory only for now; loading and saving arrive in Milestone 6.
--
-- Fields the client needs to display are mirrored onto the Player as
-- attributes ("Money", "HighestTier", "Upgrade_<id>", "Item_<id>"). The record stays the
-- source of truth; never read those attributes back on the server as values.
-- (Connecting to their change signals to learn that something changed is fine.)

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
	player:SetAttribute("Money", data.money)
	player:SetAttribute("HighestTier", data.highestTier)
	for id, level in data.upgrades do
		player:SetAttribute("Upgrade_" .. id, level)
	end
	for id, count in data.items do
		player:SetAttribute("Item_" .. id, count)
	end
end

function DataService.addMoney(player: Player, amount: number)
	local data = records[player]
	assert(data, "no data for player")
	data.money = math.max(0, data.money + amount)
	replicate(player, data)
end

-- Takes `amount` from the player's money if they have enough. Returns whether
-- it did; check and deduct happen together so nothing can slip in between.
function DataService.trySpend(player: Player, amount: number): boolean
	local data = records[player]
	if not data or amount < 0 or data.money < amount then
		return false
	end
	data.money -= amount
	replicate(player, data)
	return true
end

function DataService.setItemCount(player: Player, itemId: string, count: number)
	local data = records[player]
	assert(data, "no data for player")
	assert(data.items[itemId] ~= nil, "unknown item " .. itemId)
	data.items[itemId] = math.max(0, math.floor(count))
	replicate(player, data)
end

function DataService.setMoney(player: Player, amount: number)
	local data = records[player]
	assert(data, "no data for player")
	data.money = math.max(0, math.floor(amount))
	replicate(player, data)
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
