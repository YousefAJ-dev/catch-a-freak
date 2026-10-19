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
-- attributes ("Money", "HighestTier", "Upgrade_<id>", "Item_<id>", "GateProgress",
-- "WheelLastFreeDay", "WheelExtraSpins", "Freakpedia", "FreakpediaPending", "OwnedPasses"). The record stays the
-- source of truth; never read those attributes back on the server as values.
-- (Connecting to their change signals to learn that something changed is fine.)
--
-- Saved data must stay plain: no Instances, Vector3s or other userdata, no
-- tables mixing number and string keys, and no arrays with gaps.

local HttpService = game:GetService("HttpService")
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local FreakConfig = require(ReplicatedStorage.Shared.Config.Freaks)
local Gates = require(ReplicatedStorage.Shared.Config.Gates)
local ProfileStore = require(script.Parent.Vendor.ProfileStore)

local STORE_NAME = "PlayerData"
local AUTOSAVE_PERIOD = 60 -- seconds

export type Data = {
	version: number,
	money: number,
	upgrades: { [string]: number },
	items: { [string]: number },
	highestTier: number,
	gateProgress: { number }, -- freaks turned in for each requirement of the current gate
	playSeconds: number, -- total time played, for tuning progression
	tierReachedAt: { [string]: number }, -- tier (as a string) -> playSeconds when it was unlocked
	farm: { any },
	uncollected: number,
	lastSeen: number, -- os.time() at the last save
	-- pendingPrize: a spin's freak, saved until the wheel stops and a carry slot is free
	wheel: { lastFreeSpinDay: number, extraSpins: number, pendingPrize: { species: string, tier: number, rarity: string, readyAt: number }? },
	ownedPasses: { string }, -- gameplay Game Pass keys (Config/Products.passes)
	ownedSkins: { string }, -- skin set keys (Config/Products)
	equippedSkin: string, -- "" for none
	processedReceipts: { string }, -- recent Developer Product PurchaseIds
	freakpedia: { [string]: { string } }, -- species name -> rarity ids claimed (Config/Freakpedia)
	freakpediaPending: { [string]: { string } }, -- incubated but not claimed yet
	freakpediaBackfilled: boolean, -- farm freaks from before the Freakpedia were added once
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
		items = { netLauncher = 0, bearTrap = 0, goldenTrap = 0 },
		highestTier = 1,
		gateProgress = { 0, 0 },
		playSeconds = 0,
		tierReachedAt = { ["1"] = 0 },
		farm = {},
		uncollected = 0,
		lastSeen = 0,
		wheel = { lastFreeSpinDay = 0, extraSpins = 0 },
		ownedPasses = {},
		ownedSkins = {},
		equippedSkin = "",
		processedReceipts = {},
		freakpedia = {},
		freakpediaPending = {},
		freakpediaBackfilled = false,
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

-- Play time: each loaded player's clock reading when their play time was last
-- added to their record.
local playClock: { [Player]: number } = {}

-- Total seconds played, counting the current session so far.
local function addPlayTime(player: Player, data: Data): number
	local now = os.clock()
	data.playSeconds += now - (playClock[player] or now)
	playClock[player] = now
	return data.playSeconds
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
	player:SetAttribute("WheelLastFreeDay", data.wheel.lastFreeSpinDay)
	player:SetAttribute("WheelExtraSpins", data.wheel.extraSpins)
	player:SetAttribute("OwnedPasses", HttpService:JSONEncode(data.ownedPasses))
	player:SetAttribute("OwnedSkins", HttpService:JSONEncode(data.ownedSkins))
	player:SetAttribute("EquippedSkin", data.equippedSkin)
	player:SetAttribute("Freakpedia", HttpService:JSONEncode(data.freakpedia))
	player:SetAttribute("FreakpediaPending", HttpService:JSONEncode(data.freakpediaPending))
end

-- Re-sends the mirrored attributes after a service changed the record directly.
function DataService.refresh(player: Player)
	local data = DataService.get(player)
	if data then
		replicate(player, data)
	end
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

local function freshGateProgress(tier: number): { number }
	local progress = {}
	for i = 1, if Gates[tier] then #Gates[tier].requirements else 0 do
		progress[i] = 0
	end
	return progress
end

-- Changing tier starts the next gate from scratch. Reaching a tier for the
-- first time records how long it took, for tuning: in the server log, and as
-- an analytics event (Creator Hub > Analytics > Custom events).
function DataService.setHighestTier(player: Player, tier: number)
	local data = dataOf(player)
	local newTier = math.clamp(math.floor(tier), 1, #Tiers)
	if newTier ~= data.highestTier then
		data.gateProgress = freshGateProgress(newTier)
	end
	local key = tostring(newTier)
	if newTier > data.highestTier and not data.tierReachedAt[key] then
		local played = addPlayTime(player, data)
		data.tierReachedAt[key] = played
		local previous = data.tierReachedAt[tostring(newTier - 1)]
		print(
			("[Progress] %s reached tier %d after %.0f min played%s"):format(
				player.Name,
				newTier,
				played / 60,
				if previous then (" (Ring %d took %.0f min)"):format(newTier - 1, (played - previous) / 60) else ""
			)
		)
		pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, ("ReachedTier%d"):format(newTier), played / 60)
	end
	data.highestTier = newTier
	replicate(player, data)
end

-- Adds a rarity to a species' list in a Freakpedia table (claimed or
-- pending). Returns true if it wasn't there before.
local function addEntry(book: { [string]: { string } }, species: string, rarity: string): boolean
	local list = book[species]
	if not list then
		list = {}
		book[species] = list
	end
	if table.find(list, rarity) then
		return false
	end
	table.insert(list, rarity)
	return true
end

local function hasEntry(book: { [string]: { string } }, species: string, rarity: string): boolean
	return book[species] ~= nil and table.find(book[species], rarity) ~= nil
end

-- A species at a rarity went into an incubator: if it's new to the
-- Freakpedia, it waits there to be claimed. Returns true if it's new.
function DataService.addPendingEntry(player: Player, species: string, rarity: string): boolean
	local data = dataOf(player)
	if hasEntry(data.freakpedia, species, rarity) or not addEntry(data.freakpediaPending, species, rarity) then
		return false
	end
	replicate(player, data)
	return true
end

-- Claims every pending entry of a species. Returns the rarities claimed.
function DataService.claimEntries(player: Player, species: string): { string }
	local data = dataOf(player)
	local pending = data.freakpediaPending[species]
	data.freakpediaPending[species] = nil
	local claimed = {}
	for _, rarity in pending or {} do
		if addEntry(data.freakpedia, species, rarity) then
			table.insert(claimed, rarity)
		end
	end
	replicate(player, data)
	return claimed
end

-- Counts one more freak turned in for a requirement of the player's current gate.
function DataService.addRequirementProgress(player: Player, index: number)
	local data = dataOf(player)
	data.gateProgress[index] = (data.gateProgress[index] or 0) + 1
	replicate(player, data)
end

-- Play time so far, and the play time at which each tier was reached.
function DataService.progress(player: Player): (number, { [string]: number })
	local data = dataOf(player)
	return addPlayTime(player, data), data.tierReachedAt
end

function DataService.setUpgradeLevel(player: Player, upgradeId: string, level: number)
	local data = dataOf(player)
	local upgrade = Upgrades[upgradeId]
	assert(upgrade, "unknown upgrade " .. upgradeId)
	data.upgrades[upgradeId] = math.clamp(math.floor(level), 0, upgrade.maxLevel)
	replicate(player, data)
end

-- Grants a Developer Product purchase exactly once and reports when it's safe
-- to tell Roblox it was granted (DESIGN.md section 10; the PurchaseId-cache
-- pattern from ProfileStore's docs). `grant` runs only if this PurchaseId isn't
-- already recorded; then this yields until a save containing the PurchaseId
-- has reached the DataStore. Returns PurchaseGranted once it's saved, or
-- NotProcessedYet (Roblox retries later, even after a rejoin) if the grant
-- failed or the session ended first.
function DataService.processPurchase(player: Player, purchaseId: string, cacheSize: number, grant: () -> ()): Enum.ProductPurchaseDecision
	local profile = profiles[player]
	if not (profile and profile:IsActive()) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = profile.Data :: Data
	if not table.find(data.processedReceipts, purchaseId) then
		local ok, err = pcall(grant)
		if not ok then
			warn(("[DataService] purchase %s for %s failed to grant: %s"):format(purchaseId, player.Name, tostring(err)))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		while #data.processedReceipts >= cacheSize do
			table.remove(data.processedReceipts, 1)
		end
		table.insert(data.processedReceipts, purchaseId)
		replicate(player, data)
	end

	local function isSaved(): boolean
		local saved = profile.LastSavedData and profile.LastSavedData.processedReceipts
		return saved ~= nil and table.find(saved, purchaseId) ~= nil
	end
	while profile:IsActive() do
		if isSaved() then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local before = profile.LastSavedData
		profile:Save()
		if profile.LastSavedData == before then
			profile.OnAfterSave:Wait()
		end
		if isSaved() then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		task.wait(10)
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
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
	profile.Data.boost2xSecondsLeft = nil -- the timed 2x Money boost became a Game Pass
	for _, record in profile.Data.farm do
		record.species = FreakConfig.renamed[record.species] or record.species
		-- Freaks placed before the Freakpedia existed count as claimed (once:
		-- after that, new entries wait in freakpediaPending to be claimed).
		if not profile.Data.freakpediaBackfilled then
			addEntry(profile.Data.freakpedia, record.species, record.rarity)
		end
	end
	profile.Data.freakpediaBackfilled = true
	-- Gate progress used to be done/not-done flags; it's now a count per
	-- requirement. A done flag becomes that requirement's full count.
	local gate = Gates[profile.Data.highestTier]
	for i, value: any in profile.Data.gateProgress do
		if typeof(value) == "boolean" then
			profile.Data.gateProgress[i] = if value and gate and gate.requirements[i] then gate.requirements[i].count else 0
		end
	end
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		previousLastSeen[player] = nil
		playClock[player] = nil
		if player.Parent == Players then
			player:Kick("Your data was opened on another server. Please rejoin.")
		end
	end)
	profile.OnSave:Connect(function()
		profile.Data.lastSeen = os.time()
		addPlayTime(player, profile.Data)
	end)

	if player.Parent ~= Players then
		profile:EndSession() -- left while loading
		return
	end
	previousLastSeen[player] = profile.Data.lastSeen
	playClock[player] = os.clock()
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
