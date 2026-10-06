--!strict
-- Sell panel (DESIGN.md section 7, "Selling"): the Sell prompt at the sell
-- counter opens it; the X or walking away closes it. Shows each carried freak
-- with its price, plus "Sell all". ShopService checks the counter distance
-- and pays out.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer

local PROMPT_RANGE = 12

local SellController = {}

function SellController.start()
	local panel = UiKit.panel("SellPanel", "Sell Counter")
	local open = false

	local function render()
		panel.gui.Enabled = open and player:GetAttribute("AtSellCounter") == true
		if not panel.gui.Enabled then
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

	local function setOpen(value: boolean)
		open = value
		render()
	end

	panel.close.Activated:Connect(function()
		setOpen(false)
	end)
	player:GetAttributeChangedSignal("AtSellCounter"):Connect(function()
		if player:GetAttribute("AtSellCounter") ~= true then
			open = false -- walked away
		end
		render()
	end)
	player:GetAttributeChangedSignal("Carry"):Connect(render)

	task.spawn(function()
		local counter = workspace:WaitForChild("Map"):WaitForChild("Shop"):WaitForChild("SellCounter") :: BasePart
		UiKit.localPrompt("SellPrompt", counter.Position + Vector3.new(0, 1, 0), "Sell freaks", "Sell Counter", PROMPT_RANGE, function()
			setOpen(true)
		end)
	end)
	render()
end

return SellController
