--!strict
-- Monetization (DESIGN.md section 10).
--
-- Every Developer Product goes through one MarketplaceService.ProcessReceipt
-- callback. DataService.processPurchase grants each PurchaseId at most once and
-- only reports PurchaseGranted after the save holding it reaches the
-- DataStore, so a replayed receipt never grants twice and a server crash can't
-- lose a purchase.
--
--   2x Money       Game Pass: doubles farm income and sell payouts for good
--   Golden Trap    one Golden Bear Trap (ItemService): only Rainbow and
--                  Radioactive freaks
--   Extra Spin     one more daily-wheel spin. Paid spins are "paid random
--                  items": hidden for players whose policy restricts them
--   Revive         offered for a few seconds after dying with freaks; restores
--                  the carry bar and respawns the player at their farm
--   Free access    whitelisted players (Config/FreeAccess, by User ID or a
--                  VIP pass) own every pass and skin, revive for free
--                  (Remotes.FreeRevive) and buy Golden Bear Traps with money;
--                  checked on every join, never saved. Not the wheel.
--   Skin sets      Game Passes; ownership is saved and one can be equipped
--                  (the looks arrive with the art in Milestone 10)
--
-- Game Pass ownership lives on Roblox; it's checked on every join and copied
-- into the save (so Studio test purchases stick too).
--
-- Player attributes for the client: "OwnedPasses", "OwnedSkins",
-- "EquippedSkin" (via DataService) and "PaidRandomItemsRestricted".

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Products = require(Shared.Config.Products)
local FreeAccess = require(Shared.Config.FreeAccess)
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
	goldenTrap = function(player)
		local data = assert(DataService.get(player))
		data.items.goldenTrap += 1
		DataService.refresh(player)
		notify(player, "Golden Bear Trap added — press T to set it")
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
			player:LoadCharacter() -- respawn at their farm right away
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

local function grantPass(player: Player, passKey: string)
	local data = DataService.get(player)
	if data and not table.find(data.ownedPasses, passKey) then
		table.insert(data.ownedPasses, passKey)
		DataService.refresh(player)
	end
end

local function passById(passId: number): Products.Pass?
	for _, pass in Products.passes do
		if pass.passId == passId then
			return pass
		end
	end
	return nil
end

local function ownsPass(player: Player, passId: number): boolean
	if passId <= 0 then
		return false
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
	return ok and owns == true
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
		if ownsPass(player, skin.passId) then
			grantSkin(player, skin.key)
		end
	end
	for _, pass in Products.passes do
		if ownsPass(player, pass.passId) then
			grantPass(player, pass.key)
		end
	end
end

function MonetizationService.simulatePassPurchase(player: Player, passKey: string): string
	assert(RunService:IsStudio(), "Studio only")
	assert(Products.passes[passKey], "unknown pass " .. tostring(passKey))
	grantPass(player, passKey)
	return "granted pass " .. passKey
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
	if skinKey ~= "" and not table.find(DataService.skinsOf(player), skinKey) then
		return
	end
	data.equippedSkin = skinKey
	DataService.refresh(player)
end

-- Free access ---------------------------------------------------------------

local function checkFreeAccess(player: Player)
	local listed = table.find(FreeAccess.userIds, player.UserId) ~= nil
	DataService.setFreeAccess(player, listed or ownsPass(player, FreeAccess.passId))
end

-- A free revive for a player with free access, instead of the purchase.
local function onFreeRevive(player: Player)
	if DataService.hasFreeAccess(player) and heldForRevive[player] then
		GRANTS.revive(player)
	end
end

function MonetizationService.setFreeAccess(player: Player, on: boolean)
	assert(RunService:IsStudio(), "Studio only")
	DataService.setFreeAccess(player, on)
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
	Remotes.FreeRevive.OnServerEvent:Connect(onFreeRevive)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local skin = skinByPass(passId)
		local pass = passById(passId)
		if skin then
			grantSkin(player, skin.key)
			notify(player, ("Unlocked the %s"):format(skin.name))
		elseif pass then
			grantPass(player, pass.key)
			notify(player, ("%s unlocked — %s"):format(pass.name, pass.description:lower()))
		elseif passId == FreeAccess.passId and passId > 0 then
			DataService.setFreeAccess(player, true)
			notify(player, "VIP unlocked — every pass is yours, and revives are free")
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
				checkFreeAccess(player)
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

	-- Once a second: held freaks expire.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local held = heldForRevive[player]
				if held and os.clock() > held.heldUntil then
					heldForRevive[player] = nil
				end
			end
		end
	end)
end

return MonetizationService
