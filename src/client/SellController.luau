--!strict
-- Sell panel (DESIGN.md section 7, "Selling"): opens while the player stands at
-- the sell counter. Shows each carried freak with its price, plus "Sell all".
-- ShopService on the server checks the counter distance and pays out.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer

local SellController = {}

function SellController.start()
	local panel = UiKit.panel("SellPanel", "Sell Counter")

	local function render()
		local open = player:GetAttribute("AtSellCounter") == true
		panel.gui.Enabled = open
		if not open then
			return
		end
		UiKit.clear(panel.list)
		UiKit.clear(panel.footer)

		local ok, slots = pcall(HttpService.JSONDecode, HttpService, (player:GetAttribute("Carry") :: string?) or "[]")
		local count, total = 0, 0
		for slot, freak in if ok then slots else {} do
			if freak then
				count += 1
				local price = Formulas.sellPrice(freak.tier, freak.rarity, freak.effects)
				total += price
				UiKit.freakRow(panel.list, slot, freak, Format.money(price), "Sell", UiKit.colors.go, true, function()
					Remotes.SellFreak:FireServer(slot)
				end)
			end
		end
		if count == 0 then
			UiKit.emptyNote(panel.list, 1, "You're not carrying any freaks.")
		end
		panel.subtitle.Text = ("Sell price is 30 seconds of a freak's income. Carrying %d."):format(count)
		UiKit.button(panel.footer, ("Sell all — %s"):format(Format.money(total)), UiKit.colors.go, count > 0, function()
			Remotes.SellAll:FireServer()
		end)
	end

	player:GetAttributeChangedSignal("AtSellCounter"):Connect(render)
	player:GetAttributeChangedSignal("Carry"):Connect(render)
	render()
end

return SellController
