--!strict
-- Monetization (DESIGN.md section 10).
--
-- Every Developer Product goes through one MarketplaceService.ProcessReceipt
-- callback. DataService.processPurchase grants each PurchaseId at most once and
-- only reports PurchaseGranted after the save holding it reaches the
-- DataStore, so a replayed receipt never grants twice and a server crash can't
-- lose a purchase.
--
--   2x Money       doubles farm income and sell payouts; counts down only
--                  while online; each purchase adds an hour
--   Extra Spin     one more daily-wheel spin. Paid spins are "paid random
--                  items": hidden for players whose policy restricts them
--   Revive         offered for a few seconds after dying with freaks; restores
--                  the carry bar and respawns the player at the shop
--   Skin sets      Game Passes; ownership is saved and one can be equipped
--                  (the looks arrive with the art in Milestone 10)
--
-- Player attributes for the client: "Boost2xSecondsLeft", "OwnedSkins",
-- "EquippedSkin" (via DataService) and "PaidRandomItemsRestricted".

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Products = require(Shared.Config.Products)
local DataService = require(script.Parent.DataService)
local CarryService = require(script.Parent.CarryService)

local MonetizationService = {}

type Held = { freaks: { CarryService.CarriedFreak }, heldUntil: number }

-- Freaks lost on death, held for a possible revive purchase.
local heldForRevive: { [Player]: Held } = {}

local function notify(player: Player, message: string)
	Remotes.Notify:FireClient(player, message)
end

local function productByKey(key: string): Products.DevProduct
	return Products.developerProducts[key]
end

local GRANTS: { [string]: (Player) -> () } = {
	money2x = function(player)
		local data = assert(DataService.get(player))
		data.boost2xSecondsLeft += Products.boostSeconds
		DataService.refresh(player)
		notify(player, "2x Money active — farm income and sales are doubled")
	end,
	extraSpin = function(player)
		local data = assert(DataService.get(player))
		data.wheel.extraSpins += 1
		DataService.refresh(player)
		notify(player, "Extra wheel spin added")
	end,
	revive = function(player)
		local held = heldForRevive[player]
		heldForRevive[player] = nil
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			player:LoadCharacter() -- respawn at the shop right away
		end
		if held then
			CarryService.restore(player, held.freaks)
			Remotes.ReviveDone:FireClient(player)
			notify(player, ("Revived with %d freak%s"):format(#held.freaks, if #held.freaks == 1 then "" else "s"))
		else
			-- Nothing left to restore (only after the hold expired): don't take
			-- the purchase for nothing.
			local data = assert(DataService.get(player))
			data.wheel.extraSpins += 1
			DataService.refresh(player)
			notify(player, "Your freaks were already gone — here's an extra wheel spin instead")
		end
	end,
}

local function processReceipt(receipt: { PlayerId: number, ProductId: number, PurchaseId: string }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox retries when they're back
	end
	local key: string? = nil
	for k, product in Products.developerProducts do
		if product.id == receipt.ProductId then
			key = k
		end
	end
	if not key then
		warn(("[Monetization] no handler for product %d"):format(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not DataService.waitFor(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local grant = GRANTS[key]
	return DataService.processPurchase(player, receipt.PurchaseId, Products.receiptCacheSize, function()
		grant(player)
	end)
end

-- Studio debug: runs a Developer Product purchase through the real receipt
-- handler with a simulated receipt. Reusing a purchaseId replays a receipt.
function MonetizationService.simulatePurchase(player: Player, key: string, purchaseId: string?): string
	assert(RunService:IsStudio(), "Studio only")
	local product = productByKey(key)
	assert(product, "unknown product " .. tostring(key))
	local id = purchaseId or ("SIM-%d-%d"):format(os.time(), math.random(1, 1e6))
	local decision = processReceipt({ PlayerId = player.UserId, ProductId = product.id, PurchaseId = id })
	return ("%s receipt %s -> %s"):format(key, id, decision.Name)
end

-- Skins ---------------------------------------------------------------------

local function grantSkin(player: Player, skinKey: string)
	local data = DataService.get(player)
	if data and not table.find(data.ownedSkins, skinKey) then
		table.insert(data.ownedSkins, skinKey)
		DataService.refresh(player)
	end
end

local function skinByPass(passId: number): Products.SkinSet?
	for _, skin in Products.skinSets do
		if skin.passId == passId then
			return skin
		end
	end
	return nil
end

-- Game Passes live on Roblox, not in our save: check them on every join.
local function checkOwnedPasses(player: Player)
	for _, skin in Products.skinSets do
		if skin.passId > 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, skin.passId)
			if ok and owns then
				grantSkin(player, skin.key)
			end
		end
	end
end

function MonetizationService.simulateSkinPurchase(player: Player, skinKey: string): string
	assert(RunService:IsStudio(), "Studio only")
	for _, skin in Products.skinSets do
		if skin.key == skinKey then
			grantSkin(player, skinKey)
			return "granted skin " .. skinKey
		end
	end
	error("unknown skin " .. tostring(skinKey))
end

local function onEquipSkin(player: Player, skinKey: any)
	local data = DataService.get(player)
	if not data or typeof(skinKey) ~= "string" then
		return
	end
	if skinKey ~= "" and not table.find(data.ownedSkins, skinKey) then
		return
	end
	data.equippedSkin = skinKey
	DataService.refresh(player)
end

-- Policy --------------------------------------------------------------------

-- Paid random items (the paid wheel spin) must be hidden where they're
-- restricted. If the check fails, assume restricted.
local function checkPolicy(player: Player)
	local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	local restricted = if ok and info then info.ArePaidRandomItemsRestricted == true else true
	player:SetAttribute("PaidRandomItemsRestricted", restricted)
end

function MonetizationService.setPolicyRestricted(player: Player, restricted: boolean)
	assert(RunService:IsStudio(), "Studio only")
	player:SetAttribute("PaidRandomItemsRestricted", restricted)
end

-- Start ---------------------------------------------------------------------

function MonetizationService.start()
	MarketplaceService.ProcessReceipt = processReceipt
	Remotes.EquipSkin.OnServerEvent:Connect(onEquipSkin)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local skin = skinByPass(passId)
		if purchased and skin then
			grantSkin(player, skin.key)
			notify(player, ("Unlocked the %s"):format(skin.name))
		end
	end)

	CarryService.onLostOnDeath(function(player, lost)
		heldForRevive[player] = { freaks = lost, heldUntil = os.clock() + Products.reviveHoldSeconds }
		Remotes.ReviveOffer:FireClient(player, #lost, workspace:GetServerTimeNow() + Products.reviveOfferSeconds)
	end)

	local function onPlayerAdded(player: Player)
		task.spawn(checkPolicy, player)
		task.spawn(function()
			if DataService.waitFor(player) then
				checkOwnedPasses(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		heldForRevive[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	-- Once a second: 2x Money counts down while the player is online, and
	-- held freaks expire.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				if data and data.boost2xSecondsLeft > 0 then
					data.boost2xSecondsLeft = math.max(0, data.boost2xSecondsLeft - 1)
					DataService.refresh(player)
				end
				local held = heldForRevive[player]
				if held and os.clock() > held.heldUntil then
					heldForRevive[player] = nil
				end
			end
		end
	end)
end

return MonetizationService
