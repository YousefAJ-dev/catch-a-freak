--!strict
-- Each player's carry slots (DESIGN.md section 4). Carried freaks are not
-- saved, and dying destroys them all.
--
-- The slots are mirrored to the client as a JSON array in the "Carry" player
-- attribute; an empty slot is `false`.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerConfig = require(ReplicatedStorage.Shared.Config.Player)

export type CarriedFreak = {
	species: string,
	tier: number,
	rarity: string,
	effects: { any },
}

type Slots = { CarriedFreak | false }

local slotsByPlayer: { [Player]: Slots } = {}

local CarryService = {}

local function replicate(player: Player)
	player:SetAttribute("Carry", HttpService:JSONEncode(slotsByPlayer[player]))
end

local function emptySlots(): Slots
	local slots: Slots = {}
	for i = 1, PlayerConfig.carrySlots do
		slots[i] = false
	end
	return slots
end

function CarryService.get(player: Player): Slots?
	return slotsByPlayer[player]
end

function CarryService.hasFreeSlot(player: Player): boolean
	local slots = slotsByPlayer[player]
	return slots ~= nil and table.find(slots, false) ~= nil
end

-- Puts a freak in the first free slot. Returns the slot index, or nil when full.
function CarryService.add(player: Player, freak: CarriedFreak): number?
	local slots = slotsByPlayer[player]
	local index = slots and table.find(slots, false)
	if not (slots and index) then
		return nil
	end
	slots[index] = freak
	replicate(player)
	return index
end

-- Removes and returns the freak in a slot, or nil if the slot is empty.
function CarryService.take(player: Player, index: number): CarriedFreak?
	local slots = slotsByPlayer[player]
	local freak = slots and slots[index]
	if not (slots and freak) then
		return nil
	end
	slots[index] = false
	replicate(player)
	return freak
end

function CarryService.clear(player: Player)
	if slotsByPlayer[player] then
		slotsByPlayer[player] = emptySlots()
		replicate(player)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		CarryService.clear(player)
	end)
end

local function onPlayerAdded(player: Player)
	slotsByPlayer[player] = emptySlots()
	replicate(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function CarryService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		slotsByPlayer[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return CarryService
