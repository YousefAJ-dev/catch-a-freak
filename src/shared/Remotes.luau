--!strict
-- Creates (on the server) or finds (on the client) every RemoteEvent, so both
-- sides refer to them by name through this module.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"Notify", -- server -> client: (message: string) short on-screen message
	"SellFreak", -- client -> server: (slot: number) sell one carried freak
	"SellAll", -- client -> server: () sell every carried freak
	"PlaceFreak", -- client -> server: (slot: number) put a carried freak in the farm
	"PickUpFreak", -- client -> server: (pad: number) take a freak out of an incubator
	"BuyUpgrade", -- client -> server: (upgradeId: string) buy the next level
	"BuyItem", -- client -> server: (itemId: string) buy one item
	"UseNetLauncher", -- client -> server: (target: Vector3) fire a net at a point
	"PlaceBearTrap", -- client -> server: () set a trap where the player stands
	"NetImpact", -- server -> all clients: (position: Vector3, caught: number) net visual
}

local folder: Folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENTS do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local Remotes: { [string]: RemoteEvent } = {}
for _, name in EVENTS do
	Remotes[name] = folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
