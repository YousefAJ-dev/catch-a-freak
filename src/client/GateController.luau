--!strict
-- Gate panel (DESIGN.md sections 8 and 11): the Gate prompt at the gate counter
-- opens it; the X or walking away closes it. It always shows the current gate's
-- two requirements and which are done. Under each open requirement it lists
-- every carried or placed freak that qualifies, with a "Turn in" button.
-- GateService checks and consumes the freak.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)
local Gates = require(Shared.Config.Gates)
local FreakConfig = require(Shared.Config.Freaks)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer

local PROMPT_RANGE = 12

local tierOfSpecies: { [string]: number } = {}
for tier, list in FreakConfig.species do
	for _, species in list do
		tierOfSpecies[species.name] = tier
	end
end

local GateController = {}

local function decode(attribute: string): { any }
	local ok, value = pcall(HttpService.JSONDecode, HttpService, (player:GetAttribute(attribute) :: string?) or "[]")
	return if ok then value else {}
end

function GateController.start()
	local panel = UiKit.panel("GatePanel", "Gate")
	local open = false

	local function render()
		panel.gui.Enabled = open and player:GetAttribute("AtGateCounter") == true
		if not panel.gui.Enabled then
			return
		end
		UiKit.clear(panel.list)
		UiKit.clear(panel.footer)

		local tier = (player:GetAttribute("HighestTier") :: number?) or 1
		local gate = Gates[tier]
		if not gate then
			panel.title.Text = "All rings unlocked"
			panel.subtitle.Text = "You've opened every ring. More are coming in a later update."
			return
		end

		local progress = decode("GateProgress")
		local done = 0
		for i = 1, #gate.requirements do
			if progress[i] then
				done += 1
			end
		end
		panel.title.Text = ("Gate %d"):format(tier)
		panel.subtitle.Text = ("Turn in both freaks to open Ring %d.  %d/%d done."):format(gate.unlocksTier, done, #gate.requirements)

		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end
		local carry = decode("Carry")
		local farm = decode("Farm")
		table.sort(farm, function(a, b)
			return a.pad < b.pad
		end)

		for i, requirement in gate.requirements do
			local title = ("%s %s or better"):format(requirement.rarity, requirement.species)
			local where = ("Found in Ring %d"):format(tierOfSpecies[requirement.species] or 1)
			if progress[i] then
				UiKit.row(panel.list, nextOrder(), title, where, "✓ Turned in", "Done", UiKit.colors.go, false, function() end)
				continue
			end
			UiKit.row(panel.list, nextOrder(), title, where, "Needed", "—", UiKit.colors.go, false, function() end)
			local any = false
			for slot, freak in carry do
				if freak and Formulas.meetsRequirement(freak, requirement) then
					any = true
					UiKit.freakRow(panel.list, nextOrder(), freak, "From your carry bar", "Turn in", UiKit.colors.go, true, function()
						Remotes.TurnIn:FireServer(i, "carry", slot)
					end)
				end
			end
			for _, freak in farm do
				if Formulas.meetsRequirement(freak, requirement) then
					any = true
					UiKit.freakRow(panel.list, nextOrder(), freak, ("From incubator %d"):format(freak.pad), "Turn in", UiKit.colors.action, true, function()
						Remotes.TurnIn:FireServer(i, "farm", freak.pad)
					end)
				end
			end
			if not any then
				UiKit.emptyNote(panel.list, nextOrder(), "You don't have one yet.")
			end
		end
	end

	panel.close.Activated:Connect(function()
		open = false
		render()
	end)
	player:GetAttributeChangedSignal("AtGateCounter"):Connect(function()
		if player:GetAttribute("AtGateCounter") ~= true then
			open = false -- walked away
		end
		render()
	end)
	for _, attribute in { "HighestTier", "GateProgress", "Carry", "Farm" } do
		player:GetAttributeChangedSignal(attribute):Connect(render)
	end

	task.spawn(function()
		local counter = workspace:WaitForChild("Map"):WaitForChild("Shop"):WaitForChild("GateCounter") :: BasePart
		UiKit.localPrompt("GatePrompt", counter.Position + Vector3.new(0, 1, 0), "Turn in freaks", "Gate", PROMPT_RANGE, function()
			open = true
			render()
		end)
	end)
	render()
end

return GateController
