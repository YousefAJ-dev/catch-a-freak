--!strict
-- Per-player tier doors. Every door tagged "TierDoor" is solid on the server;
-- this client opens the ones its player has unlocked by turning off collision
-- locally (the character's physics run on this client). ZoneService on the
-- server sends back anyone who ends up in a ring above their tier.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local LOCKED = { color = Color3.fromRGB(220, 60, 60), transparency = 0.35, text = "Tier %d — Locked" }
local OPEN = { color = Color3.fromRGB(70, 230, 120), transparency = 0.85, text = "Tier %d — Open" }

local DoorController = {}

local function apply(door: Instance)
	if not door:IsA("BasePart") then
		return
	end
	local required = door:GetAttribute("RequiredTier") :: number?
	if not required then
		return
	end
	local open = ((player:GetAttribute("HighestTier") :: number?) or 1) >= required
	local style = open and OPEN or LOCKED
	door.CanCollide = not open
	door.Color = style.color
	door.Transparency = style.transparency
	local label = door:FindFirstChild("Label")
	local text = label and label:FindFirstChildOfClass("TextLabel")
	if text then
		text.Text = style.text:format(required)
		text.TextColor3 = style.color
	end
end

local function applyAll()
	for _, door in CollectionService:GetTagged("TierDoor") do
		apply(door)
	end
end

function DoorController.start()
	-- With streaming on, doors arrive (and re-arrive) as the player moves.
	CollectionService:GetInstanceAddedSignal("TierDoor"):Connect(apply)
	player:GetAttributeChangedSignal("HighestTier"):Connect(applyAll)
	applyAll()
end

return DoorController
