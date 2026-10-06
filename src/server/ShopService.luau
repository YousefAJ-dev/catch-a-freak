--!strict
-- The shop (DESIGN.md section 7): upgrades and items at the shop counter, and
-- selling at the sell counter. The client only names what it wants; prices,
-- levels and money are all decided here.
--
-- Mirrors "AtShopCounter" and "AtSellCounter" onto the Player so the client can
-- open the matching panel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Economy = require(Shared.Config.Economy)
local Upgrades = require(Shared.Config.Upgrades)
local Items = require(Shared.Config.Items)
local DataService = require(script.Parent.DataService)
local CarryService = require(script.Parent.CarryService)

local CHECK_INTERVAL = 0.25

local ShopService = {}

local sellCounter: BasePart
local shopCounter: BasePart

local function notify(player: Player, message: string)
	Remotes.Notify:FireClient(player, message)
end

local function isNear(player: Player, counter: BasePart): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (humanoid and root) or humanoid.Health <= 0 then
		return false
	end
	local offset = root.Position - counter.Position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= Economy.counterRange
end

-- Selling ------------------------------------------------------------------

-- Sells the freak in `slot`. Returns its price, or nil if the slot was empty.
local function sellSlot(player: Player, slot: number): number?
	local freak = CarryService.take(player, slot)
	if not freak then
		return nil
	end
	local price = Formulas.sellPrice(freak.tier, freak.rarity, freak.effects)
	DataService.addMoney(player, price)
	return price
end

local function onSellFreak(player: Player, slot: any)
	local slots = CarryService.get(player)
	if not (slots and typeof(slot) == "number" and slot == math.floor(slot) and slot >= 1 and slot <= #slots) then
		return
	end
	if not isNear(player, sellCounter) then
		notify(player, "Go to the sell counter to sell")
		return
	end
	local freak = slots[slot]
	local price = sellSlot(player, slot)
	if freak and price then
		notify(player, ("Sold %s %s for %s"):format(freak.rarity, freak.species, Format.money(price)))
	end
end

local function onSellAll(player: Player)
	local slots = CarryService.get(player)
	if not slots then
		return
	end
	if not isNear(player, sellCounter) then
		notify(player, "Go to the sell counter to sell")
		return
	end
	local count, total = 0, 0
	for slot in slots do
		local price = sellSlot(player, slot)
		if price then
			count += 1
			total += price
		end
	end
	if count == 0 then
		notify(player, "Nothing to sell")
	else
		notify(player, ("Sold %d freak%s for %s"):format(count, if count == 1 then "" else "s", Format.money(total)))
	end
end

-- Buying -------------------------------------------------------------------

local function onBuyUpgrade(player: Player, upgradeId: any)
	local data = DataService.get(player)
	local upgrade = typeof(upgradeId) == "string" and Upgrades[upgradeId]
	if not (data and upgrade) then
		return
	end
	if not isNear(player, shopCounter) then
		notify(player, "Go to the shop counter to buy upgrades")
		return
	end
	local level = data.upgrades[upgrade.id]
	if level >= upgrade.maxLevel then
		notify(player, ("%s is already at max level"):format(upgrade.name))
		return
	end
	local cost = Formulas.upgradeCost(upgrade.id, level)
	if not DataService.trySpend(player, cost) then
		notify(player, ("You need %s for %s level %d"):format(Format.money(cost), upgrade.name, level + 1))
		return
	end
	DataService.setUpgradeLevel(player, upgrade.id, level + 1)
	notify(player, ("%s upgraded to level %d"):format(upgrade.name, level + 1))
end

local function onBuyItem(player: Player, itemId: any)
	local data = DataService.get(player)
	local isItem = typeof(itemId) == "string" and table.find(Items.order, itemId) ~= nil
	if not (data and isItem) then
		return
	end
	local item = (Items :: any)[itemId]
	if not isNear(player, shopCounter) then
		notify(player, "Go to the shop counter to buy items")
		return
	end
	local held = data.items[itemId] or 0
	if held >= Items.maxHeld then
		notify(player, ("You can only carry %d %ss"):format(Items.maxHeld, item.name))
		return
	end
	local price = Formulas.itemPrice(itemId, data.highestTier)
	if not DataService.trySpend(player, price) then
		notify(player, ("You need %s for a %s"):format(Format.money(price), item.name))
		return
	end
	DataService.setItemCount(player, itemId, held + 1)
	notify(player, ("Bought a %s (%d/%d)"):format(item.name, held + 1, Items.maxHeld))
end

function ShopService.start()
	local shop = workspace:WaitForChild("Map"):WaitForChild("Shop")
	sellCounter = shop:WaitForChild("SellCounter") :: BasePart
	shopCounter = shop:WaitForChild("UpgradeCounter") :: BasePart

	Remotes.SellFreak.OnServerEvent:Connect(onSellFreak)
	Remotes.SellAll.OnServerEvent:Connect(onSellAll)
	Remotes.BuyUpgrade.OnServerEvent:Connect(onBuyUpgrade)
	Remotes.BuyItem.OnServerEvent:Connect(onBuyItem)

	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				player:SetAttribute("AtSellCounter", isNear(player, sellCounter))
				player:SetAttribute("AtShopCounter", isNear(player, shopCounter))
			end
		end
	end)
end

return ShopService
