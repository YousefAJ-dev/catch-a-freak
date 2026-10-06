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
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer

local UPGRADE_ORDER = { "shoes", "hazmat", "grip", "farmCapacity", "offlineCapacity" }

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
			return ("−%d%%"):format(math.round(Upgrades.grip.effectPerLevel * level * 100))
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
		for i, id in UPGRADE_ORDER do
			local upgrade = Upgrades[id]
			local level = (player:GetAttribute("Upgrade_" .. id) :: number?) or 0
			local maxed = level >= upgrade.maxLevel
			local title = ("%s  ·  Lv %d/%d"):format(upgrade.name, level, upgrade.maxLevel)
			local effect = EFFECT[id]
			if maxed then
				UiKit.row(panel.list, i, title, ("%s %s"):format(effect.label, effect.value(level)), "Max level", "Max", UiKit.colors.go, false, function() end)
			else
				local cost = Formulas.upgradeCost(id, level)
				local change = ("%s %s → %s"):format(effect.label, effect.value(level), effect.value(level + 1))
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
			UiKit.emptyNote(panel.list, 1, "Upgrade skins arrive with the store (Milestone 9).")
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

	local watched = { "Money", "HighestTier" }
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
