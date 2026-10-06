--!strict
-- One saved data record per player (DESIGN.md section 12, "Saved data"),
-- stored with ProfileStore: session locking (a player's data is only ever
-- open on one server), autosave every 60 seconds, and a final save when the
-- player leaves or the server shuts down.
--
-- Loading takes a moment, so DataService.get returns nil until it finishes;
-- use DataService.waitFor where a record is required.
--
-- Fields the client needs to display are mirrored onto the Player as
-- attributes ("Money", "HighestTier", "Upgrade_<id>", "Item_<id>", "GateProgress"). The record stays the
-- source of truth; never read those attributes back on the server as values.
-- (Connecting to their change signals to learn that something changed is fine.)
--
-- Saved data must stay plain: no Instances, Vector3s or other userdata, no
-- tables mixing number and string keys, and no arrays with gaps.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local ProfileStore = require(script.Parent.Vendor.ProfileStore)

local STORE_NAME = "PlayerData"
local AUTOSAVE_PERIOD = 60 -- seconds

export type Data = {
	version: number,
	money: number,
	upgrades: { [string]: number },
	items: { [string]: number },
	highestTier: number,
	gateProgress: { boolean },
	farm: { any },
	uncollected: number,
	lastSeen: number, -- os.time() at the last save
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

ProfileStore.SetConstant("AUTO_SAVE_PERIOD", AUTOSAVE_PERIOD)
local store = ProfileStore.New(STORE_NAME, newData())

local profiles: { [Player]: any } = {} -- ProfileStore profiles, one per loaded player
-- When the player was last seen before this session (0 for a new player).
-- Captured at load, before the first save overwrites `lastSeen`.
local previousLastSeen: { [Player]: number } = {}

local DataService = {}

function DataService.get(player: Player): Data?
	local profile = profiles[player]
	return if profile then profile.Data :: Data else nil
end

-- Yields until the player's data has loaded. Returns nil if they leave first.
function DataService.waitFor(player: Player): Data?
	while player.Parent == Players and not profiles[player] do
		task.wait()
	end
	return DataService.get(player)
end

-- os.time() of the player's previous visit, or 0 if this is their first.
function DataService.previousLastSeen(player: Player): number
	return previousLastSeen[player] or 0
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
	player:SetAttribute("GateProgress", HttpService:JSONEncode(data.gateProgress))
end

local function dataOf(player: Player): Data
	local data = DataService.get(player)
	assert(data, "no data for player")
	return data
end

function DataService.addMoney(player: Player, amount: number)
	local data = dataOf(player)
	data.money = math.max(0, data.money + amount)
	replicate(player, data)
end

-- Takes `amount` from the player's money if they have enough. Returns whether
-- it did; check and deduct happen together so nothing can slip in between.
function DataService.trySpend(player: Player, amount: number): boolean
	local data = DataService.get(player)
	if not data or amount < 0 or data.money < amount then
		return false
	end
	data.money -= amount
	replicate(player, data)
	return true
end

function DataService.setItemCount(player: Player, itemId: string, count: number)
	local data = dataOf(player)
	assert(data.items[itemId] ~= nil, "unknown item " .. itemId)
	data.items[itemId] = math.max(0, math.floor(count))
	replicate(player, data)
end

function DataService.setMoney(player: Player, amount: number)
	local data = dataOf(player)
	data.money = math.max(0, math.floor(amount))
	replicate(player, data)
end

-- Changing tier starts the next gate from scratch.
function DataService.setHighestTier(player: Player, tier: number)
	local data = dataOf(player)
	local newTier = math.clamp(math.floor(tier), 1, #Tiers)
	if newTier ~= data.highestTier then
		data.gateProgress = { false, false }
	end
	data.highestTier = newTier
	replicate(player, data)
end

-- Marks one requirement of the player's current gate as turned in.
function DataService.markRequirement(player: Player, index: number)
	local data = dataOf(player)
	data.gateProgress[index] = true
	replicate(player, data)
end

function DataService.setUpgradeLevel(player: Player, upgradeId: string, level: number)
	local data = dataOf(player)
	local upgrade = Upgrades[upgradeId]
	assert(upgrade, "unknown upgrade " .. upgradeId)
	data.upgrades[upgradeId] = math.clamp(math.floor(level), 0, upgrade.maxLevel)
	replicate(player, data)
end

-- Studio debug: resets the player's saved data to a brand-new record. The
-- caller should make the player rejoin so every system starts fresh.
function DataService.wipe(player: Player)
	local data = dataOf(player) :: any
	local fresh = newData() :: any
	for key in data do
		data[key] = nil
	end
	for key, value in fresh do
		data[key] = value
	end
	replicate(player, data)
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(("Player_%d"):format(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if not profile then
		if player.Parent == Players then
			player:Kick("We couldn't load your data. Please rejoin in a moment.")
		end
		return
	end

	profile:AddUserId(player.UserId) -- GDPR: lets Roblox find this player's data
	profile:Reconcile() -- fills in fields added to the template since the last save
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		previousLastSeen[player] = nil
		if player.Parent == Players then
			player:Kick("Your data was opened on another server. Please rejoin.")
		end
	end)
	profile.OnSave:Connect(function()
		profile.Data.lastSeen = os.time()
	end)

	if player.Parent ~= Players then
		profile:EndSession() -- left while loading
		return
	end
	previousLastSeen[player] = profile.Data.lastSeen
	profiles[player] = profile
	replicate(player, profile.Data)
end

function DataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			profile:EndSession() -- saves one last time (OnSave stamps lastSeen)
		end
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	if RunService:IsStudio() then
		task.spawn(function()
			while ProfileStore.DataStoreState == "NotReady" do
				task.wait()
			end
			if ProfileStore.DataStoreState ~= "Access" then
				warn("[DataService] DataStores unavailable — progress will NOT be saved. Enable Game Settings > Security > Studio Access to API Services.")
			end
		end)
	end
end

return DataService
