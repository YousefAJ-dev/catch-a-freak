--!strict
-- Carried-freak trail (DESIGN.md Milestone 6.5): each player's carried freaks
-- follow them as miniatures in a line, nearest first in carry-slot order. Every
-- client draws every player's trail from the replicated "Carry" attribute, so
-- the server creates nothing and the trail moves smoothly. A small disc under
-- each miniature glows in its rarity color.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FreakModels = require(ReplicatedStorage.Shared.FreakModels)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

local SCALE = 0.4 -- miniature size relative to the real freak
local FIRST_GAP = 3.5 -- studs between the player and the first miniature
local SPACING = 2.6 -- studs between miniatures
local SNAP_DISTANCE = 40 -- further than this (e.g. after respawning) and the trail jumps back
local BOB_HEIGHT = 0.25
local BOB_RATE = 9

type Mini = {
	model: Model,
	parts: { BasePart },
	offsets: { CFrame }, -- each part relative to the miniature's Root
	position: Vector3, -- on the ground
	facing: CFrame, -- rotation only
	phase: number,
}

type Trail = {
	key: string, -- what the trail currently shows, to skip rebuilds that change nothing
	minis: { Mini },
}

local TrailController = {}

local trails: { [Player]: Trail } = {}
local folder: Folder

local function buildMini(species: string, rarityId: string, at: Vector3): Mini
	local model = FreakModels.build(FreakModels.species(species))
	model:ScaleTo(SCALE)
	local root = model.PrimaryPart :: BasePart
	local size = model:GetExtentsSize()

	local disc = Instance.new("Part")
	disc.Name = "RarityGlow"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.12, math.max(size.X, size.Z) + 0.6, math.max(size.X, size.Z) + 0.6)
	disc.CFrame = root.CFrame * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.rad(90))
	disc.Color = Rarities.byId[rarityId].color
	disc.Material = Enum.Material.Neon
	disc.Transparency = 0.25
	disc.Parent = model

	local parts, offsets = {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			table.insert(parts, d)
			table.insert(offsets, root.CFrame:ToObjectSpace(d.CFrame))
		end
	end
	model.Name = ("Mini_%s_%s"):format(rarityId, species)
	model.Parent = folder
	return { model = model, parts = parts, offsets = offsets, position = at, facing = CFrame.identity, phase = math.random() * math.pi * 2 }
end

local function clearTrail(player: Player)
	local trail = trails[player]
	if trail then
		for _, mini in trail.minis do
			mini.model:Destroy()
		end
		trails[player] = nil
	end
end

local function groundUnder(player: Player): Vector3?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (humanoid and root) or humanoid.Health <= 0 then
		return nil
	end
	return root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
end

local function rebuild(player: Player)
	local ok, slots = pcall(HttpService.JSONDecode, HttpService, (player:GetAttribute("Carry") :: string?) or "[]")
	local carried = {}
	for _, freak in if ok then slots else {} do
		if freak then
			table.insert(carried, freak)
		end
	end
	local keyParts = {}
	for _, freak in carried do
		table.insert(keyParts, freak.rarity .. ":" .. freak.species)
	end
	local key = table.concat(keyParts, ",")
	local existing = trails[player]
	if existing and existing.key == key then
		return
	end

	-- Keep miniatures where they were so a catch or sale doesn't make the
	-- whole line jump; new ones start at the end of the line.
	local previous = if existing then existing.minis else {}
	local start = groundUnder(player) or Vector3.zero
	clearTrail(player)
	local minis = {}
	for i, freak in carried do
		local at = if previous[i] then previous[i].position elseif #minis > 0 then minis[#minis].position else start
		table.insert(minis, buildMini(freak.species, freak.rarity, at))
	end
	trails[player] = { key = key, minis = minis }
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("Carry"):Connect(function()
		rebuild(player)
	end)
	rebuild(player)
end

function TrailController.start()
	folder = Instance.new("Folder")
	folder.Name = "CarryTrails"
	folder.Parent = workspace

	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clearTrail)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	local allParts: { BasePart } = {}
	local allCFrames: { CFrame } = {}
	RunService.RenderStepped:Connect(function()
		table.clear(allParts)
		table.clear(allCFrames)
		local now = os.clock()
		for player, trail in trails do
			local ground = groundUnder(player)
			if not ground then
				continue
			end
			local leader = ground
			for i, mini in trail.minis do
				local gap = if i == 1 then FIRST_GAP else SPACING
				local offset = Vector3.new(mini.position.X - leader.X, 0, mini.position.Z - leader.Z)
				if offset.Magnitude > SNAP_DISTANCE then
					offset = Vector3.new(0, 0, gap) -- respawned or teleported: regroup behind
				end
				local moving = offset.Magnitude > gap
				if moving then
					offset = offset.Unit * gap
				end
				mini.position = Vector3.new(leader.X + offset.X, ground.Y, leader.Z + offset.Z)
				if offset.Magnitude > 0.05 then
					mini.facing = CFrame.lookAt(mini.position, Vector3.new(leader.X, ground.Y, leader.Z)).Rotation
				end
				local bob = if moving then math.abs(math.sin(now * BOB_RATE + mini.phase)) * BOB_HEIGHT else 0
				local rootCFrame = CFrame.new(mini.position + Vector3.new(0, bob, 0)) * mini.facing
				for j, part in mini.parts do
					table.insert(allParts, part)
					table.insert(allCFrames, rootCFrame * mini.offsets[j])
				end
				leader = mini.position
			end
		end
		if #allParts > 0 then
			workspace:BulkMoveTo(allParts, allCFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return TrailController
