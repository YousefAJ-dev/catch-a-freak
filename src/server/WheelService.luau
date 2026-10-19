--!strict
-- Daily wheel (DESIGN.md section 9). At the wheel, a player with a free carry
-- slot gets one free spin per UTC day (or uses an extra spin, sold in
-- Milestone 9). The server rolls the prize and tells the client where the
-- spin landed so it can play the animation; the freak goes into the carry bar
-- once the wheel stops (Wheel.spinSeconds). Until then the prize is saved as
-- `wheel.pendingPrize`, so leaving mid-spin, or filling the carry bar while
-- it turns, never loses it: it's handed over as soon as there's a free slot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Economy = require(Shared.Config.Economy)
local FreakConfig = require(Shared.Config.Freaks)
local Wheel = require(Shared.Config.Wheel)
local DataService = require(script.Parent.DataService)
local CarryService = require(script.Parent.CarryService)

local CHECK_INTERVAL = 0.25

local WheelService = {}

local rng = Random.new()
local wheelPart: BasePart
-- Players already told their prize is waiting on a free carry slot.
local toldFull: { [Player]: boolean } = {}

local function notify(player: Player, message: string)
	Remotes.Notify:FireClient(player, message)
end

local function isAtWheel(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (humanoid and root) or humanoid.Health <= 0 then
		return false
	end
	local offset = root.Position - wheelPart.Position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= Economy.counterRange
end

-- Rolls and grants one spin's prize. Returns the prize index, tier, rarity and
-- species. Exposed so the odds can be tested without spending spins.
function WheelService.roll(highestTier: number): (number, number, string, string)
	local index = Formulas.rollWheel(rng:NextNumber())
	local tier, rarity = Formulas.wheelPrize(index, highestTier)
	local speciesList = FreakConfig.species[tier]
	local species = speciesList[rng:NextInteger(1, #speciesList)].name
	return index, tier, rarity, species
end

local function onSpin(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	if not isAtWheel(player) then
		notify(player, "Go to the daily wheel to spin")
		return
	end
	if data.wheel.pendingPrize then
		notify(player, "Your last prize is still on its way")
		return
	end
	if not CarryService.hasFreeSlot(player) then
		notify(player, "Free up a carry slot first — the prize goes there")
		return
	end
	local today = Formulas.utcDay(os.time())
	if data.wheel.lastFreeSpinDay < today then
		data.wheel.lastFreeSpinDay = today
	elseif data.wheel.extraSpins > 0 then
		data.wheel.extraSpins -= 1
	else
		local wait = (today + 1) * 86400 - os.time()
		notify(player, ("Next free spin in %dh %dm"):format(wait // 3600, (wait % 3600) // 60))
		return
	end

	local index, tier, rarity, species = WheelService.roll(data.highestTier)
	data.wheel.pendingPrize = { species = species, tier = tier, rarity = rarity, readyAt = os.time() + Wheel.spinSeconds }
	DataService.refresh(player)
	Remotes.WheelResult:FireClient(player, index, tier, rarity, species)
	print(("[Wheel] %s won %s %s %s (tier %d, worth %s)"):format(player.Name, Format.article(rarity), rarity, species, tier, Format.money(Formulas.sellPrice(tier, rarity))))
end

-- Hands over a finished spin's prize once there's a free carry slot.
local function deliverPrize(player: Player)
	local data = DataService.get(player)
	local prize = data and data.wheel.pendingPrize
	if not (data and prize) or os.time() < prize.readyAt or not CarryService.get(player) then
		return
	end
	if not CarryService.hasFreeSlot(player) then
		if not toldFull[player] then
			toldFull[player] = true
			notify(player, "Free a carry slot to collect your wheel prize")
		end
		return
	end
	toldFull[player] = nil
	data.wheel.pendingPrize = nil
	CarryService.add(player, { species = prize.species, tier = prize.tier, rarity = prize.rarity, effects = {} })
	DataService.refresh(player)
end

-- Studio debug helpers.
function WheelService.resetFreeSpin(player: Player)
	local data = DataService.get(player)
	assert(data, "no data")
	data.wheel.lastFreeSpinDay = 0
	DataService.refresh(player)
end

function WheelService.setExtraSpins(player: Player, count: number)
	local data = DataService.get(player)
	assert(data, "no data")
	data.wheel.extraSpins = math.max(0, math.floor(count))
	DataService.refresh(player)
end

function WheelService.start()
	wheelPart = workspace:WaitForChild("Map"):WaitForChild("Shop"):WaitForChild("DailyWheel"):WaitForChild("Spinner"):WaitForChild("Wheel") :: BasePart
	Remotes.SpinWheel.OnServerEvent:Connect(onSpin)
	Players.PlayerRemoving:Connect(function(player)
		toldFull[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				player:SetAttribute("AtWheel", isAtWheel(player))
				deliverPrize(player)
			end
		end
	end)
end

return WheelService
