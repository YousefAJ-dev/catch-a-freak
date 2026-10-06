--!strict
-- Shop panel (DESIGN.md sections 7 and 11): the Shop prompt at the shop
-- counter opens it; the X or walking away closes it. Tabs for
-- Upgrades, Items and Skins; each row shows the current level or count, what
-- the next one does, and its price. ShopService decides every purchase.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Upgrades = require(Shared.Config.Upgrades)
local Items = require(Shared.Config.Items)
local DashConfig = require(Shared.Config.Dash)
local Products = require(Shared.Config.Products)
local UiKit = require(script.Parent.UiKit)
local Purchases = require(script.Parent.Purchases)

local HttpService = game:GetService("HttpService")

-- Robux purchase buttons are teal so they're never mistaken for in-game money.
local ROBUX = Color3.fromRGB(0, 160, 110)

local player = Players.LocalPlayer

local UPGRADE_ORDER = { "shoes", "dash", "dashRecharge", "hazmat", "grip", "farmCapacity", "offlineCapacity" }

-- What each upgrade changes, and its value at a given level. Rows read
-- "<label> <now> → <next>", e.g. "Radiation −84% → −87%".
local EFFECT: { [string]: { label: string, value: (level: number) -> string } } = {
	shoes = {
		label = "Walk speed",
		value = function(level)
			return tostring(Formulas.walkSpeed(level))
		end,
	},
	hazmat = {
		label = "Radiation",
		value = function(level)
			return ("−%d%%"):format(math.round((1 - Formulas.hazmatMultiplier(level)) * 100))
		end,
	},
	grip = {
		label = "Grab time",
		value = function(level)
			return ("−%d%%"):format(math.round((1 - Formulas.gripMultiplier(level)) * 100))
		end,
	},
	farmCapacity = {
		label = "Incubators",
		value = function(level)
			return tostring(Formulas.farmCapacity(level))
		end,
	},
	offlineCapacity = {
		label = "Offline earnings",
		value = function(level)
			return ("%d h"):format(Formulas.offlineHours(level))
		end,
	},
	dash = {
		label = ("Burst %d studs forward [%s]"):format(DashConfig.distance, DashConfig.key.Name),
		value = function(level)
			return if level > 0 then "owned" else "not owned"
		end,
	},
	dashRecharge = {
		label = "Dash cooldown",
		value = function(level)
			return ("%d s"):format(Formulas.dashCooldown(level))
		end,
	},
}

local ShopController = {}

function ShopController.start()
	local panel = UiKit.panel("ShopPanel", "Shop")
	local open = false
	local tab = "Upgrades"

	local function money(): number
		return (player:GetAttribute("Money") :: number?) or 0
	end

	local function renderUpgrades()
		local tier = (player:GetAttribute("HighestTier") :: number?) or 1
		for i, id in UPGRADE_ORDER do
			local upgrade = Upgrades[id]
			local level = (player:GetAttribute("Upgrade_" .. id) :: number?) or 0
			local maxed = level >= upgrade.maxLevel
			local capped = not maxed and level >= Formulas.upgradeLevelCap(id, tier)
			local title = ("%s  ·  Lv %d/%d"):format(upgrade.name, level, upgrade.maxLevel)
			local effect = EFFECT[id]
			local requires = upgrade.requires
			local missing = requires and ((player:GetAttribute("Upgrade_" .. requires.upgrade) :: number?) or 0) < requires.level
			if missing and requires then
				local needed = Upgrades[requires.upgrade]
				local what = if needed.maxLevel > 1 then ("%s level %d"):format(needed.name, requires.level) else needed.name
				UiKit.row(panel.list, i, title, effect.label, ("Requires %s"):format(what), "Locked", UiKit.colors.go, false, function() end)
			elseif maxed then
				UiKit.row(panel.list, i, title, ("%s %s"):format(effect.label, effect.value(level)), "Max level", "Max", UiKit.colors.go, false, function() end)
			elseif capped then
				local needed = Formulas.tierForUpgradeLevel(id, level + 1)
				UiKit.row(panel.list, i, title, ("%s %s"):format(effect.label, effect.value(level)), ("Next level unlocks at Tier %d"):format(needed), ("Tier %d"):format(needed), UiKit.colors.go, false, function() end)
			else
				local cost = Formulas.upgradeCost(id, level)
				local change = if upgrade.maxLevel == 1
					then effect.label -- one-time purchase: just say what it does
					else ("%s %s → %s"):format(effect.label, effect.value(level), effect.value(level + 1))
				UiKit.row(panel.list, i, title, change, Format.money(cost), "Buy", UiKit.colors.go, money() >= cost, function()
					Remotes.BuyUpgrade:FireServer(id)
				end)
			end
		end
	end

	local function renderItems()
		local tier = (player:GetAttribute("HighestTier") :: number?) or 1
		for i, id in Items.order do
			local item = (Items :: any)[id]
			local held = (player:GetAttribute("Item_" .. id) :: number?) or 0
			local price = Formulas.itemPrice(id, tier)
			local full = held >= Items.maxHeld
			local title = ("%s  ·  %d/%d  [%s]"):format(item.name, held, Items.maxHeld, item.key.Name)
			UiKit.row(panel.list, i, title, item.description, Format.money(price), if full then "Full" else "Buy", UiKit.colors.go, not full and money() >= price, function()
				Remotes.BuyItem:FireServer(id)
			end)
		end
		-- Robux boost, sold alongside the items.
		local boostProduct = Products.developerProducts.money2x
		local left = (player:GetAttribute("Boost2xSecondsLeft") :: number?) or 0
		local status = if left > 0 then ("Active: %d min left — buying adds an hour"):format(math.ceil(left / 60)) else boostProduct.description
		UiKit.row(panel.list, #Items.order + 1, boostProduct.name, status, Purchases.productPrice("money2x"), "Buy", ROBUX, true, function()
			Purchases.promptProduct("money2x")
		end)
	end

	local function renderSkins()
		local owned = {}
		local ok, list = pcall(HttpService.JSONDecode, HttpService, (player:GetAttribute("OwnedSkins") :: string?) or "[]")
		for _, key in if ok then list else {} do
			owned[key] = true
		end
		local equipped = (player:GetAttribute("EquippedSkin") :: string?) or ""
		for i, skin in Products.skinSets do
			if equipped == skin.key then
				UiKit.row(panel.list, i, skin.name, skin.description, "Equipped", "Unequip", UiKit.colors.action, true, function()
					Remotes.EquipSkin:FireServer("")
				end)
			elseif owned[skin.key] then
				UiKit.row(panel.list, i, skin.name, skin.description, "Owned", "Equip", UiKit.colors.go, true, function()
					Remotes.EquipSkin:FireServer(skin.key)
				end)
			else
				UiKit.row(panel.list, i, skin.name, skin.description, Purchases.priceText(skin.passId, Enum.InfoType.GamePass), "Buy", ROBUX, true, function()
					Purchases.promptSkin(skin)
				end)
			end
		end
		UiKit.emptyNote(panel.list, #Products.skinSets + 1, "Skins are cosmetic only. Their looks arrive with the art update.")
	end

	local function render()
		panel.gui.Enabled = open and player:GetAttribute("AtShopCounter") == true
		if not panel.gui.Enabled then
			return
		end
		UiKit.clear(panel.list)
		if tab == "Upgrades" then
			renderUpgrades()
		elseif tab == "Items" then
			renderItems()
		else
			renderSkins()
		end
	end

	local select = UiKit.tabs(panel, { "Upgrades", "Items", "Skins" }, function(name)
		tab = name
		render()
	end)
	select("Upgrades")

	panel.close.Activated:Connect(function()
		open = false
		render()
	end)
	player:GetAttributeChangedSignal("AtShopCounter"):Connect(function()
		if player:GetAttribute("AtShopCounter") ~= true then
			open = false -- walked away
		end
		render()
	end)
	task.spawn(function()
		local counter = workspace:WaitForChild("Map"):WaitForChild("Shop"):WaitForChild("UpgradeCounter") :: BasePart
		UiKit.localPrompt("ShopPrompt", counter.Position + Vector3.new(0, 1, 0), "Browse", "Shop", 12, function()
			open = true
			render()
		end)
	end)

	-- Look up Robux prices once in the background so rendering never waits on them.
	task.spawn(function()
		Purchases.productPrice("money2x")
		for _, skin in Products.skinSets do
			Purchases.priceText(skin.passId, Enum.InfoType.GamePass)
		end
	end)

	local watched = { "Money", "HighestTier", "OwnedSkins", "EquippedSkin" }
	for _, id in UPGRADE_ORDER do
		table.insert(watched, "Upgrade_" .. id)
	end
	for _, id in Items.order do
		table.insert(watched, "Item_" .. id)
	end
	for _, attribute in watched do
		player:GetAttributeChangedSignal(attribute):Connect(render)
	end
	render()
end

return ShopController
