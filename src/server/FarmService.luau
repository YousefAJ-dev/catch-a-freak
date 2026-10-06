--!strict
-- Farm plots (DESIGN.md section 6): plot assignment, placing freaks in
-- incubators and picking them back up, income, and collecting.
--
-- The player's placed freaks live in their data record (`farm`, each with the
-- incubator `pad` it sits in) and are mirrored to the client as attributes:
--   "PlotIndex"   which plot they own
--   "Farm"        JSON array of placed freaks
--   "FarmIncome"  total income per second
--   "FarmCapacity" unlocked incubators
--   "Uncollected" money waiting on the collection pad
--   "OnOwnPlot"   standing on (or in front of) their plot; opens the farm panel

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local FarmVisuals = require(Shared.FarmVisuals)
local World = require(Shared.Config.World)
local Rarities = require(Shared.Config.Rarities)
local DataService = require(script.Parent.DataService)
local CarryService = require(script.Parent.CarryService)
local FreakModels = require(Shared.FreakModels)

local INCOME_TICK = 1
local CHECK_INTERVAL = 0.2
local LABEL_RANGE = 20 -- a placed freak's label only shows this close
local MAX_FREAK_WIDTH = 9 -- placed freaks are scaled down to fit their incubator
local MAX_FREAK_HEIGHT = 15

type FarmFreak = {
	species: string,
	tier: number,
	rarity: string,
	effects: { any },
	pad: number,
}

type Plot = {
	index: number,
	model: Model,
	base: BasePart,
	owner: Player?,
	placed: { [number]: Model }, -- pad -> freak model
}

local FarmService = {}

local plots: { Plot } = {}
local plotOf: { [Player]: Plot } = {}

local function notify(player: Player, message: string)
	Remotes.Notify:FireClient(player, message)
end

local function signGui(plot: Plot, sign: string): SurfaceGui
	return (plot.model:FindFirstChild(sign) :: Model):FindFirstChild("Board"):FindFirstChildOfClass("SurfaceGui") :: SurfaceGui
end

local function setOwnerText(plot: Plot, text: string)
	(signGui(plot, "OwnerSign"):FindFirstChild("OwnerName") :: TextLabel).Text = text
end

-- Owner sign for a claimed plot: the player's name and their farm's income.
local function setOwnerSign(plot: Plot, player: Player, income: number)
	setOwnerText(plot, ("%s's Lab\n+%s/s"):format(player.DisplayName, Format.money(income)))
end

local function setValueSign(plot: Plot, pool: number, rate: number)
	local gui = signGui(plot, "ValueSign");
	(gui:FindFirstChild("Amount") :: TextLabel).Text = Format.money(pool);
	(gui:FindFirstChild("Rate") :: TextLabel).Text = ("+%s/s"):format(Format.money(rate))
end

local function farmOf(player: Player): { FarmFreak }
	local data = DataService.get(player)
	return if data then data.farm :: { FarmFreak } else {}
end

local function recordAt(farm: { FarmFreak }, pad: number): (FarmFreak?, number?)
	for i, record in farm do
		if record.pad == pad then
			return record, i
		end
	end
	return nil, nil
end

local function capacityOf(player: Player?): number
	local data = player and DataService.get(player)
	return Formulas.farmCapacity(if data then data.upgrades.farmCapacity else 0)
end

local function incomeOf(farm: { FarmFreak }): number
	local total = 0
	for _, record in farm do
		total += Formulas.incomePerSecond(record.tier, record.rarity, record.effects)
	end
	return total
end

local function refreshIncubators(plot: Plot)
	local farm = if plot.owner then farmOf(plot.owner) else {}
	local capacity = capacityOf(plot.owner)
	for _, incubator in (plot.model:FindFirstChild("Pads") :: Folder):GetChildren() do
		local pad = incubator:GetAttribute("PadIndex") :: number
		local record = recordAt(farm, pad)
		FarmVisuals.styleIncubator(incubator :: Model, pad <= capacity, if record then Rarities.byId[record.rarity].color else nil)
	end
end

local function updatePool(player: Player, plot: Plot)
	local data = DataService.get(player)
	if not data then
		return
	end
	local income = incomeOf(data.farm :: { FarmFreak })
	player:SetAttribute("Uncollected", data.uncollected)
	player:SetAttribute("FarmIncome", income)
	setValueSign(plot, data.uncollected, income)
	setOwnerSign(plot, player, income)
end

local function replicateFarm(player: Player, plot: Plot)
	player:SetAttribute("Farm", HttpService:JSONEncode(farmOf(player)))
	player:SetAttribute("FarmCapacity", capacityOf(player))
	updatePool(player, plot)
end

-- Puts a freak model in its incubator: scaled down to fit if needed, facing
-- the front, with a label that only shows up close.
local function showFreak(plot: Plot, record: FarmFreak)
	local incubator = (plot.model:FindFirstChild("Pads") :: Folder):FindFirstChild("Pad" .. record.pad) :: Model
	local floor = incubator:FindFirstChild("Floor") :: BasePart
	local rarity = Rarities.byId[record.rarity]
	local model, body = FreakModels.build(FreakModels.species(record.species))
	model.Name = "Placed" .. record.pad

	local size = model:GetExtentsSize()
	local scale = math.min(1, MAX_FREAK_WIDTH / math.max(size.X, size.Z), MAX_FREAK_HEIGHT / size.Y)
	if scale < 1 then
		model:ScaleTo(scale)
	end
	-- The incubator is aligned with the plot, whose -Z faces the shop.
	model:PivotTo(floor.CFrame * CFrame.new(0, floor.Size.Y / 2, 0))

	local label = Instance.new("BillboardGui")
	label.Name = "Label"
	label.Size = UDim2.fromOffset(170, 44)
	label.StudsOffset = Vector3.new(0, model:GetExtentsSize().Y / 2 + 1.5, 0)
	label.MaxDistance = LABEL_RANGE
	for i, line in
		{
			{ text = ("%s %s"):format(record.rarity, record.species), color = rarity.color },
			{ text = ("+%s/s"):format(Format.money(Formulas.incomePerSecond(record.tier, record.rarity, record.effects))), color = Color3.new(1, 1, 1) },
		}
	do
		local t = Instance.new("TextLabel")
		t.Position = UDim2.fromScale(0, (i - 1) * 0.5)
		t.Size = UDim2.fromScale(1, 0.5)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBold
		t.TextScaled = true
		t.TextColor3 = line.color
		t.TextStrokeTransparency = 0.3
		t.Text = line.text
		t.Parent = label
	end
	label.Parent = body

	model.Parent = plot.model
	plot.placed[record.pad] = model
end

local function hideFreak(plot: Plot, pad: number)
	local model = plot.placed[pad]
	if model then
		model:Destroy()
		plot.placed[pad] = nil
	end
end

-- Where `position` is relative to the plot (x across, z front (-) to back (+)).
local function plotLocal(plot: Plot, position: Vector3): Vector3
	return plot.base.CFrame:PointToObjectSpace(position)
end

-- On the plot, or on the ground just in front of it where the collection pad is.
local function isOnPlot(plot: Plot, position: Vector3): boolean
	local cfg = World.farm
	local half = cfg.plotSize / 2
	local l = plotLocal(plot, position)
	local front = half + cfg.collectPadGap + cfg.collectPadSize + 2
	return math.abs(l.X) <= half + 2 and l.Z >= -front and l.Z <= half + 2 and l.Y < 30
end

local function isOnCollectPad(plot: Plot, position: Vector3): boolean
	local pad = plot.model:FindFirstChild("CollectPad") :: BasePart
	local l = pad.CFrame:PointToObjectSpace(position)
	return math.abs(l.X) <= pad.Size.X / 2 + 1 and math.abs(l.Z) <= pad.Size.Z / 2 + 1 and l.Y < 8
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local FARM_FULL = "Farm full — upgrade Farm Capacity at the shop for more incubators"

-- Moves the freak in carry `slot` into the lowest-numbered empty unlocked
-- incubator. Returns "placed", "full" (no free incubator) or "empty" (no freak
-- in that slot). The caller has already checked the player is on their plot.
local function placeSlot(player: Player, plot: Plot, slot: number): ("placed" | "full" | "empty", FarmFreak?)
	local slots = CarryService.get(player)
	if not (slots and slots[slot]) then
		return "empty", nil
	end
	local farm = farmOf(player)
	local pad: number? = nil
	for candidate = 1, capacityOf(player) do
		if not recordAt(farm, candidate) then
			pad = candidate
			break
		end
	end
	if not pad then
		return "full", nil
	end
	local freak = CarryService.take(player, slot)
	if not freak then
		return "empty", nil
	end
	local record: FarmFreak = { species = freak.species, tier = freak.tier, rarity = freak.rarity, effects = freak.effects, pad = pad }
	table.insert(farm, record)
	showFreak(plot, record)
	return "placed", record
end

-- The plot and root of a player standing on their own plot, or nil after
-- telling them why not.
local function ownPlotCheck(player: Player, action: string): Plot?
	local plot = plotOf[player]
	local root = rootOf(player)
	if not (plot and root and CarryService.get(player)) then
		return nil
	end
	if not isOnPlot(plot, root.Position) then
		notify(player, ("Stand on your lab to %s"):format(action))
		return nil
	end
	return plot
end

local function onPlaceFreak(player: Player, slot: any)
	local slots = CarryService.get(player)
	if not (slots and typeof(slot) == "number" and slot == math.floor(slot) and slot >= 1 and slot <= #slots) then
		return
	end
	local plot = ownPlotCheck(player, "place freaks")
	if not plot then
		return
	end
	local result, record = placeSlot(player, plot, slot)
	if result == "full" then
		notify(player, FARM_FULL)
	elseif result == "placed" and record then
		refreshIncubators(plot)
		replicateFarm(player, plot)
		notify(player, ("Placed %s %s in incubator %d"):format(record.rarity, record.species, record.pad))
	end
end

local function onPlaceAll(player: Player)
	local plot = ownPlotCheck(player, "place freaks")
	local slots = CarryService.get(player)
	if not (plot and slots) then
		return
	end
	local placed, left = 0, 0
	for slot in slots do
		local result = placeSlot(player, plot, slot)
		if result == "placed" then
			placed += 1
		elseif result == "full" then
			left += 1
		end
	end
	if placed > 0 then
		refreshIncubators(plot)
		replicateFarm(player, plot)
	end
	if placed == 0 and left == 0 then
		notify(player, "You're not carrying any freaks")
	elseif placed == 0 then
		notify(player, FARM_FULL)
	elseif left > 0 then
		notify(player, ("Placed %d — %s"):format(placed, FARM_FULL))
	else
		notify(player, ("Placed %d freak%s"):format(placed, if placed == 1 then "" else "s"))
	end
end

local function onPickUpFreak(player: Player, pad: any)
	local plot = plotOf[player]
	local root = rootOf(player)
	if not (plot and root) then
		return
	end
	if not (typeof(pad) == "number" and pad == math.floor(pad) and pad >= 1 and pad <= World.farm.padRows * World.farm.padColumns) then
		return
	end
	if not isOnPlot(plot, root.Position) then
		notify(player, "Stand on your lab to pick up freaks")
		return
	end
	local farm = farmOf(player)
	local record, index = recordAt(farm, pad)
	if not (record and index) then
		return
	end
	if not CarryService.hasFreeSlot(player) then
		notify(player, "Carry full — sell or place a freak first")
		return
	end
	table.remove(farm, index)
	CarryService.add(player, { species = record.species, tier = record.tier, rarity = record.rarity, effects = record.effects })
	hideFreak(plot, pad)
	refreshIncubators(plot)
	replicateFarm(player, plot)
end

-- The freak in one of the player's incubators, or nil (for gate turn-ins).
function FarmService.getFreak(player: Player, pad: number): FarmFreak?
	local record = recordAt(farmOf(player), pad)
	return record
end

-- Takes a freak out of an incubator for good (consumed by a gate turn-in).
-- Returns the removed record, or nil if the incubator was empty.
function FarmService.removeFreak(player: Player, pad: number): FarmFreak?
	local plot = plotOf[player]
	local farm = farmOf(player)
	local record, index = recordAt(farm, pad)
	if not (plot and record and index) then
		return nil
	end
	table.remove(farm, index)
	hideFreak(plot, pad)
	refreshIncubators(plot)
	replicateFarm(player, plot)
	return record
end

local function collect(player: Player, plot: Plot)
	local data = DataService.get(player)
	if not data or data.uncollected <= 0 then
		return
	end
	local amount = data.uncollected
	data.uncollected = 0
	DataService.addMoney(player, amount)
	updatePool(player, plot)
	notify(player, ("Collected %s"):format(Format.money(amount)))
end

-- Adds what the farm earned while the player was away (capped by Offline
-- Capacity) to the uncollected pool and tells them. Returns the amount.
function FarmService.applyOfflineEarnings(player: Player, secondsAway: number): number
	local plot = plotOf[player]
	local data = DataService.get(player)
	if not (plot and data) then
		return 0
	end
	local income = incomeOf(data.farm :: { FarmFreak })
	local earned = Formulas.offlineEarnings(income, secondsAway, data.upgrades.offlineCapacity)
	if earned <= 0 then
		return 0
	end
	data.uncollected += earned
	updatePool(player, plot)
	local hours = Formulas.offlineHours(data.upgrades.offlineCapacity)
	local capped = secondsAway > hours * 3600
	Remotes.Popup:FireClient(
		player,
		"Welcome back!",
		("While you were away your lab earned %s.%s\nIt's waiting on your green collection pad."):format(
			Format.money(earned),
			if capped then ("\n(Capped at %d h — upgrade Offline Capacity to store more.)"):format(hours) else ""
		)
	)
	return earned
end

local function claimPlot(player: Player)
	-- Data loads asynchronously and CarryService creates its record on
	-- PlayerAdded too; wait for both.
	DataService.waitFor(player)
	while player.Parent and not CarryService.get(player) do
		task.wait()
	end
	if not (player.Parent and DataService.get(player)) then
		return
	end
	for _, plot in plots do
		if not plot.owner then
			plot.owner = player
			plotOf[player] = plot
			player:SetAttribute("PlotIndex", plot.index)
			for _, record in farmOf(player) do
				showFreak(plot, record)
			end
			refreshIncubators(plot)
			replicateFarm(player, plot)
			local lastSeen = DataService.previousLastSeen(player)
			if lastSeen > 0 then
				FarmService.applyOfflineEarnings(player, os.time() - lastSeen)
			end
			player:GetAttributeChangedSignal("Upgrade_farmCapacity"):Connect(function()
				if plotOf[player] == plot then
					refreshIncubators(plot)
					replicateFarm(player, plot)
				end
			end)
			return
		end
	end
	warn(("[FarmService] no free plot for %s"):format(player.Name))
end

local function releasePlot(player: Player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	plotOf[player] = nil
	plot.owner = nil
	for pad in plot.placed do
		hideFreak(plot, pad)
	end
	setOwnerText(plot, FarmVisuals.unclaimedText(plot.index))
	setValueSign(plot, 0, 0)
	refreshIncubators(plot)
end

function FarmService.start()
	local folder = workspace:WaitForChild("Map"):WaitForChild("Plots")
	for _, model in folder:GetChildren() do
		local index = model:GetAttribute("PlotIndex") :: number
		plots[index] = {
			index = index,
			model = model :: Model,
			base = model:FindFirstChild("Base") :: BasePart,
			owner = nil,
			placed = {},
		}
	end
	for _, plot in plots do
		setOwnerText(plot, FarmVisuals.unclaimedText(plot.index))
		setValueSign(plot, 0, 0)
		refreshIncubators(plot)
	end

	Remotes.PlaceFreak.OnServerEvent:Connect(onPlaceFreak)
	Remotes.PlaceAll.OnServerEvent:Connect(onPlaceAll)
	Remotes.PickUpFreak.OnServerEvent:Connect(onPickUpFreak)
	Players.PlayerAdded:Connect(claimPlot)
	Players.PlayerRemoving:Connect(releasePlot)
	for _, player in Players:GetPlayers() do
		task.spawn(claimPlot, player)
	end

	-- Income: every second each placed freak adds its income to the pool.
	task.spawn(function()
		while true do
			task.wait(INCOME_TICK)
			for player, plot in plotOf do
				local data = DataService.get(player)
				if data then
					data.uncollected += incomeOf(data.farm :: { FarmFreak }) * INCOME_TICK
					updatePool(player, plot)
				end
			end
		end
	end)

	-- Standing on the plot opens the farm panel; standing on the pad collects.
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for player, plot in plotOf do
				local root = rootOf(player)
				local onPlot = root ~= nil and isOnPlot(plot, root.Position)
				player:SetAttribute("OnOwnPlot", onPlot)
				if root and isOnCollectPad(plot, root.Position) then
					collect(player, plot)
				end
			end
		end
	end)
end

return FarmService
