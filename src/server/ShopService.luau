--!strict
-- The shop (DESIGN.md section 7). Milestone 4: selling at the sell counter.
-- Upgrades and items arrive in Milestone 5.
--
-- Mirrors "AtSellCounter" onto the Player so the client can open the sell panel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Economy = require(Shared.Config.Economy)
local DataService = require(script.Parent.DataService)
local CarryService = require(script.Parent.CarryService)

local CHECK_INTERVAL = 0.25

local ShopService = {}

local sellCounter: BasePart

local function notify(player: Player, message: string)
	Remotes.Notify:FireClient(player, message)
end

local function isAtSellCounter(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (humanoid and root) or humanoid.Health <= 0 then
		return false
	end
	local offset = root.Position - sellCounter.Position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= Economy.sellRange
end

-- Sells the freak in `slot`. Returns its price, or nil if the slot was empty.
local function sellSlot(player: Player, slot: number): number?
	local freak = CarryService.take(player, slot)
	if not freak then
		return nil
	end
	local price = Formulas.sellPrice(freak.tier, freak.rarity, freak.effects)
	DataService.addMoney(player, price)
	return price
end

local function onSellFreak(player: Player, slot: any)
	local slots = CarryService.get(player)
	if not (slots and typeof(slot) == "number" and slot == math.floor(slot) and slot >= 1 and slot <= #slots) then
		return
	end
	if not isAtSellCounter(player) then
		notify(player, "Go to the sell counter to sell")
		return
	end
	local freak = slots[slot]
	local price = sellSlot(player, slot)
	if freak and price then
		notify(player, ("Sold %s %s for %s"):format(freak.rarity, freak.species, Format.money(price)))
	end
end

local function onSellAll(player: Player)
	local slots = CarryService.get(player)
	if not slots then
		return
	end
	if not isAtSellCounter(player) then
		notify(player, "Go to the sell counter to sell")
		return
	end
	local count, total = 0, 0
	for slot in slots do
		local price = sellSlot(player, slot)
		if price then
			count += 1
			total += price
		end
	end
	if count == 0 then
		notify(player, "Nothing to sell")
	else
		notify(player, ("Sold %d freak%s for %s"):format(count, if count == 1 then "" else "s", Format.money(total)))
	end
end

function ShopService.start()
	sellCounter = workspace:WaitForChild("Map"):WaitForChild("Shop"):WaitForChild("SellCounter") :: BasePart
	Remotes.SellFreak.OnServerEvent:Connect(onSellFreak)
	Remotes.SellAll.OnServerEvent:Connect(onSellAll)

	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				player:SetAttribute("AtSellCounter", isAtSellCounter(player))
			end
		end
	end)
end

return ShopService
