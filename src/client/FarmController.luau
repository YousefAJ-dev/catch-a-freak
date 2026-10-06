--!strict
-- Farm panel (DESIGN.md section 6): opens while the player stands on their own
-- lab. Place carried freaks into incubators, pick placed ones back up, and see
-- income, capacity and the uncollected pool. FarmService decides everything.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer

local FarmController = {}

local function decode(attribute: string): { any }
	local ok, value = pcall(HttpService.JSONDecode, HttpService, (player:GetAttribute(attribute) :: string?) or "[]")
	return if ok then value else {}
end

function FarmController.start()
	local panel = UiKit.panel("FarmPanel", "Your Lab")

	local function renderSubtitle()
		local placed = #decode("Farm")
		local capacity = (player:GetAttribute("FarmCapacity") :: number?) or 0
		panel.subtitle.Text = ("+%s/s  ·  %d/%d incubators  ·  %s waiting on the green pad"):format(
			Format.money((player:GetAttribute("FarmIncome") :: number?) or 0),
			placed,
			capacity,
			Format.money((player:GetAttribute("Uncollected") :: number?) or 0)
		)
	end

	local function render()
		local open = player:GetAttribute("OnOwnPlot") == true
		panel.gui.Enabled = open
		if not open then
			return
		end
		UiKit.clear(panel.list)
		renderSubtitle()

		local farm = decode("Farm")
		local capacity = (player:GetAttribute("FarmCapacity") :: number?) or 0
		local hasRoom = #farm < capacity
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end

		UiKit.section(panel.list, nextOrder(), "Carried")
		local carrying = 0
		for slot, freak in decode("Carry") do
			if freak then
				carrying += 1
				local income = Formulas.incomePerSecond(freak.tier, freak.rarity, freak.effects)
				UiKit.freakRow(panel.list, nextOrder(), freak, ("+%s/s"):format(Format.money(income)), "Place", UiKit.colors.go, hasRoom, function()
					Remotes.PlaceFreak:FireServer(slot)
				end)
			end
		end
		if carrying == 0 then
			UiKit.emptyNote(panel.list, nextOrder(), "Catch freaks in the rings to bring them here.")
		elseif not hasRoom then
			UiKit.emptyNote(panel.list, nextOrder(), "All unlocked incubators are full.")
		end

		UiKit.section(panel.list, nextOrder(), "In incubators")
		table.sort(farm, function(a, b)
			return a.pad < b.pad
		end)
		for _, freak in farm do
			local income = Formulas.incomePerSecond(freak.tier, freak.rarity, freak.effects)
			local detail = ("Incubator %d  ·  +%s/s"):format(freak.pad, Format.money(income))
			UiKit.freakRow(panel.list, nextOrder(), freak, detail, "Pick up", UiKit.colors.action, true, function()
				Remotes.PickUpFreak:FireServer(freak.pad)
			end)
		end
		if #farm == 0 then
			UiKit.emptyNote(panel.list, nextOrder(), "No freaks placed yet.")
		end
	end

	for _, attribute in { "OnOwnPlot", "Carry", "Farm", "FarmCapacity" } do
		player:GetAttributeChangedSignal(attribute):Connect(render)
	end
	-- The pool and income change every second; only the subtitle needs updating.
	for _, attribute in { "Uncollected", "FarmIncome" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if panel.gui.Enabled then
				renderSubtitle()
			end
		end)
	end
	render()
end

return FarmController
