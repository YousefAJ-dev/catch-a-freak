--!strict
-- Moves freak models along their server-published waypoints every frame
-- (DESIGN.md section 12, "Freak performance"). The server never animates them.
-- All parts are anchored, so each frame is one BulkMoveTo of the freak parts
-- within FreakConfig.renderDistance of the camera.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local FreakConfig = require(ReplicatedStorage.Shared.Config.Freaks)

local BOB_HEIGHT = 0.35
local BOB_RATE = 8

type Tracked = {
	parts: { BasePart },
	offsets: { CFrame }, -- each part relative to Root
	from: Vector3,
	to: Vector3,
	start: number,
	speed: number,
	facing: CFrame, -- rotation only
	phase: number, -- so freaks don't bob in sync
	connection: RBXScriptConnection,
}

local FreakRenderer = {}

local tracked: { [Model]: Tracked } = {}

local function readWaypoint(model: Model, t: Tracked)
	t.from = (model:GetAttribute("WpFrom") :: Vector3?) or t.from
	t.to = (model:GetAttribute("WpTo") :: Vector3?) or t.to
	t.start = (model:GetAttribute("WpStart") :: number?) or t.start
	t.speed = (model:GetAttribute("WpSpeed") :: number?) or t.speed
	if (t.to - t.from).Magnitude > 1e-3 then
		t.facing = CFrame.lookAt(t.from, t.to).Rotation
	end
end

local function track(instance: Instance)
	if not instance:IsA("Model") or tracked[instance] then
		return
	end
	local model = instance
	local root = model:FindFirstChild("Root") :: BasePart?
	if not root then
		return
	end
	local parts, offsets = {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			table.insert(offsets, root.CFrame:ToObjectSpace(d.CFrame))
		end
	end
	local t: Tracked = {
		parts = parts,
		offsets = offsets,
		from = root.Position,
		to = root.Position,
		start = 0,
		speed = 0,
		facing = root.CFrame.Rotation,
		phase = math.random() * math.pi * 2,
		connection = model.AttributeChanged:Connect(function()
			local current = tracked[model]
			if current then
				readWaypoint(model, current)
			end
		end),
	}
	readWaypoint(model, t)
	tracked[model] = t
end

local function untrack(instance: Instance)
	local t = tracked[instance :: Model]
	if t then
		t.connection:Disconnect()
		tracked[instance :: Model] = nil
	end
end

function FreakRenderer.start()
	-- With streaming on, freaks arrive and leave as the player moves.
	CollectionService:GetInstanceAddedSignal("Freak"):Connect(track)
	CollectionService:GetInstanceRemovedSignal("Freak"):Connect(untrack)
	for _, model in CollectionService:GetTagged("Freak") do
		track(model)
	end

	local allParts: { BasePart } = {}
	local allCFrames: { CFrame } = {}
	RunService.RenderStepped:Connect(function()
		table.clear(allParts)
		table.clear(allCFrames)
		local now = workspace:GetServerTimeNow()
		local eye = workspace.CurrentCamera.CFrame.Position
		local maxSq = FreakConfig.renderDistance * FreakConfig.renderDistance
		for model, t in tracked do
			if not model.Parent then
				continue
			end
			local position, moving = Formulas.freakPosition(t.from, t.to, t.start, t.speed, now)
			-- Far freaks are tiny on screen; leave them where they are.
			local dx, dz = position.X - eye.X, position.Z - eye.Z
			if dx * dx + dz * dz > maxSq then
				continue
			end
			local bob = if moving then math.abs(math.sin(now * BOB_RATE + t.phase)) * BOB_HEIGHT else 0
			local rootCFrame = CFrame.new(position + Vector3.new(0, bob, 0)) * t.facing
			for i, part in t.parts do
				table.insert(allParts, part)
				table.insert(allCFrames, rootCFrame * t.offsets[i])
			end
		end
		if #allParts > 0 then
			workspace:BulkMoveTo(allParts, allCFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return FreakRenderer
