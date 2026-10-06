--!strict
-- Daily wheel (DESIGN.md section 9). At the wheel, a player with a free carry
-- slot gets one free spin per UTC day (or uses an extra spin, sold in
-- Milestone 9). The server rolls the prize and puts the freak in their carry
-- bar, then tells the client where the spin landed so it can play the animation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Economy = require(Shared.Config.Economy)
local FreakConfig = require(Shared.Config.Freaks)
local DataService = require(script.Parent.DataService)
local CarryService = require(script.Parent.CarryService)

local CHECK_INTERVAL = 0.25

local WheelService = {}

local rng = Random.new()
local wheelPart: BasePart

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
	CarryService.add(player, { species = species, tier = tier, rarity = rarity, effects = {} })
	DataService.refresh(player)
	Remotes.WheelResult:FireClient(player, index, tier, rarity, species)
	print(("[Wheel] %s won %s %s %s (tier %d, worth %s)"):format(player.Name, Format.article(rarity), rarity, species, tier, Format.money(Formulas.sellPrice(tier, rarity))))
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
	wheelPart = workspace:WaitForChild("Map"):WaitForChild("Shop"):WaitForChild("DailyWheel"):WaitForChild("Wheel") :: BasePart
	Remotes.SpinWheel.OnServerEvent:Connect(onSpin)

	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				player:SetAttribute("AtWheel", isAtWheel(player))
			end
		end
	end)
end

return WheelService
