--!strict
-- Farm panel (DESIGN.md section 6): the Farm prompt at the front of the
-- player's own lab opens it (the prompt exists only on their own plot); the X
-- or walking off the lab closes it. Place carried freaks into incubators (one
-- or all), pick placed ones back up, and see income, capacity and the
-- uncollected pool. FarmService decides everything.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiKit = require(script.Parent.UiKit)
local World = require(ReplicatedStorage.Shared.Config.World)

local player = Players.LocalPlayer

local PROMPT_RANGE = 12

local FarmController = {}

local function decode(attribute: string): { any }
	local ok, value = pcall(HttpService.JSONDecode, HttpService, (player:GetAttribute(attribute) :: string?) or "[]")
	return if ok then value else {}
end

function FarmController.start()
	local panel = UiKit.panel("FarmPanel", "Your Lab")
	local open = false

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
		panel.gui.Enabled = open and player:GetAttribute("OnOwnPlot") == true
		if not panel.gui.Enabled then
			return
		end
		UiKit.clear(panel.list)
		UiKit.clear(panel.footer)
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
				-- Stays clickable when full so the server can say "Farm full".
				UiKit.freakRow(panel.list, nextOrder(), freak, ("+%s/s"):format(Format.money(income)), "Place", UiKit.colors.go, true, function()
					Remotes.PlaceFreak:FireServer(slot)
				end)
			end
		end
		if carrying == 0 then
			UiKit.emptyNote(panel.list, nextOrder(), "Catch freaks in the rings to bring them here.")
		elseif not hasRoom then
			UiKit.emptyNote(panel.list, nextOrder(), "Farm full — upgrade Farm Capacity for more.")
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

		UiKit.button(panel.footer, ("Place all (%d)"):format(carrying), UiKit.colors.go, carrying > 0, function()
			Remotes.PlaceAll:FireServer()
		end)
	end

	local function setOpen(value: boolean)
		open = value
		render()
	end

	panel.close.Activated:Connect(function()
		setOpen(false)
	end)
	player:GetAttributeChangedSignal("OnOwnPlot"):Connect(function()
		if player:GetAttribute("OnOwnPlot") ~= true then
			open = false -- walked off the lab
		end
		render()
	end)
	for _, attribute in { "Carry", "Farm", "FarmCapacity" } do
		player:GetAttributeChangedSignal(attribute):Connect(render)
	end

	-- The Farm prompt, at the front of the aisle on this player's own plot only.
	task.spawn(function()
		while not player:GetAttribute("PlotIndex") do
			player:GetAttributeChangedSignal("PlotIndex"):Wait()
		end
		local plot = workspace:WaitForChild("Map"):WaitForChild("Plots"):WaitForChild("Plot" .. player:GetAttribute("PlotIndex"))
		local base = plot:WaitForChild("Base") :: BasePart
		local front = base.CFrame * CFrame.new(0, 3, -(World.farm.plotSize / 2 - 3))
		UiKit.localPrompt("FarmPrompt", front.Position, "Open farm", "Your Lab", PROMPT_RANGE, function()
			setOpen(true)
		end)
	end)
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
