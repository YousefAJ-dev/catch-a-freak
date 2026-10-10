--!strict
-- Progression gates (DESIGN.md section 8). At the gate counter the player turns
-- in freaks, from their carry bar or straight from their farm, toward the
-- requirements of their current gate (each asks for a number of one species
-- at a rarity or better). Turned-in freaks are consumed and progress is saved.
-- Completing every requirement unlocks the next tier, which opens that ring's
-- doors for this player only (client DoorController). A gate to a ring this
-- build doesn't include yet (Config/Release) can't be worked on.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Gates = require(Shared.Config.Gates)
local Economy = require(Shared.Config.Economy)
local Release = require(Shared.Config.Release)
local DataService = require(script.Parent.DataService)
local CarryService = require(script.Parent.CarryService)
local FarmService = require(script.Parent.FarmService)

local CHECK_INTERVAL = 0.25

local GateService = {}

local gateCounter: BasePart

local function notify(player: Player, message: string)
	Remotes.Notify:FireClient(player, message)
end

local function isAtGateCounter(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (humanoid and root) or humanoid.Health <= 0 then
		return false
	end
	local offset = root.Position - gateCounter.Position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= Economy.counterRange
end

local function isWholeNumber(value: any, min: number, max: number): boolean
	return typeof(value) == "number" and value == math.floor(value) and value >= min and value <= max
end

local function onTurnIn(player: Player, requirementIndex: any, source: any, index: any)
	local data = DataService.get(player)
	if not data then
		return
	end
	local gate = Gates[data.highestTier]
	if not gate then
		notify(player, "Every ring is already unlocked")
		return
	end
	if gate.unlocksTier > Release.releasedTiers then
		notify(player, ("Ring %d opens in a later update"):format(gate.unlocksTier))
		return
	end
	if not isWholeNumber(requirementIndex, 1, #gate.requirements) or (source ~= "carry" and source ~= "farm") or not isWholeNumber(index, 1, 64) then
		return
	end
	if not isAtGateCounter(player) then
		notify(player, "Go to the gate counter to turn in freaks")
		return
	end
	local requirement = gate.requirements[requirementIndex]
	if (data.gateProgress[requirementIndex] or 0) >= requirement.count then
		notify(player, "That requirement is already done")
		return
	end

	local freak = if source == "carry" then (CarryService.get(player) or {})[index] else FarmService.getFreak(player, index)
	if not freak then
		return
	end
	if not Formulas.meetsRequirement(freak, requirement) then
		notify(player, ("That's not %s %s %s or better"):format(Format.article(requirement.rarity), requirement.rarity, Formulas.requirementSpeciesText(requirement)))
		return
	end

	local taken = if source == "carry" then CarryService.take(player, index) else FarmService.removeFreak(player, index)
	if not taken then
		return
	end
	DataService.addRequirementProgress(player, requirementIndex)
	notify(player, ("Turned in %s %s (%d/%d)"):format(taken.rarity, taken.species, data.gateProgress[requirementIndex], requirement.count))

	for i, other in gate.requirements do
		if (data.gateProgress[i] or 0) < other.count then
			return
		end
	end
	-- Every requirement done: unlock the next ring.
	DataService.setHighestTier(player, gate.unlocksTier)
	Remotes.Popup:FireClient(
		player,
		("Tier %d unlocked!"):format(gate.unlocksTier),
		("The doors to Ring %d are open for you. Its radiation is stronger — check your Hazmat Suit before heading out."):format(gate.unlocksTier)
	)
end

function GateService.start()
	gateCounter = workspace:WaitForChild("Map"):WaitForChild("Shop"):WaitForChild("GateCounter") :: BasePart
	Remotes.TurnIn.OnServerEvent:Connect(onTurnIn)

	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				player:SetAttribute("AtGateCounter", isAtGateCounter(player))
			end
		end
	end)
end

return GateService
