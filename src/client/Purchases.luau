--!strict
-- Opens Roblox purchase prompts for Developer Products and skin Game Passes,
-- and looks up their Robux prices for display. Purchases are granted on the
-- server (MonetizationService); this only starts them.
--
-- While a product's ID in Config/Products is still a placeholder (negative),
-- there's nothing on Roblox to buy: say so instead of prompting.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Products = require(ReplicatedStorage.Shared.Config.Products)
local NotifyController = require(script.Parent.NotifyController)

local player = Players.LocalPlayer

local Purchases = {}

local prices: { [number]: number } = {}

local function notSetUp(name: string)
	NotifyController.show(("%s isn't set up in Creator Hub yet (Studio: /buy or /buyskin)"):format(name))
end

-- "R$ 99", or "R$ —" when the ID is a placeholder or the lookup fails.
-- Yields the first time an ID is looked up.
function Purchases.priceText(id: number, infoType: Enum.InfoType): string
	if id <= 0 then
		return "R$ —"
	end
	if not prices[id] then
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
		if ok and info and info.PriceInRobux then
			prices[id] = info.PriceInRobux
		end
	end
	return if prices[id] then ("R$ %d"):format(prices[id]) else "R$ —"
end

function Purchases.productPrice(key: string): string
	return Purchases.priceText(Products.developerProducts[key].id, Enum.InfoType.Product)
end

function Purchases.promptProduct(key: string)
	local product = Products.developerProducts[key]
	if product.id <= 0 then
		notSetUp(product.name)
		return
	end
	MarketplaceService:PromptProductPurchase(player, product.id)
end

function Purchases.promptSkin(skin: Products.SkinSet)
	if skin.passId <= 0 then
		notSetUp(skin.name)
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, skin.passId)
end

return Purchases
