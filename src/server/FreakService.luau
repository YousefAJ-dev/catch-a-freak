--!strict
-- Freaks (DESIGN.md sections 5 and 12): spawning, lifetime, wandering, grabbing.
--
-- Freaks are anchored models with no Humanoid. The server never animates them.
-- Each freak has one waypoint at a time (from, to, start time, speed), published
-- as model attributes; clients move the models locally (FreakRenderer), and the
-- server works out positions from the same data with Formulas.freakPosition.
--
-- Grabbing uses the freak's ProximityPrompt. Its hold events reach the server
-- directly, so the server times the hold itself and trusts nothing from the client.
--
-- Items (ItemService) use query/capture/pin. A pinned freak stands still,
-- never expires, and can only be grabbed by the trap's owner, in
-- Items.bearTrap.pinnedHold seconds. Pins are published as model attributes
-- "PinnedBy" (owner UserId) and "PinnedUntil" (server time).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)
local World = require(Shared.Config.World)
local Tiers = require(Shared.Config.Tiers)
local Rarities = require(Shared.Config.Rarities)
local FreakConfig = require(Shared.Config.Freaks)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local FreakModels = require(script.Parent.FreakModels)
local Items = require(Shared.Config.Items)

-- Network delay can make the server see a hold as slightly shorter, or the
-- player slightly further away, than the client did.
local HOLD_TOLERANCE = 0.25 -- seconds
local RANGE_TOLERANCE = 5 -- studs

type Freak = {
	id: string,
	species: FreakConfig.Species,
	rarity: Rarities.Rarity,
	homeZone: World.Zone, -- wander targets stay inside this zone
	counted: boolean, -- part of a ring's population (debug spawns are not)
	model: Model,
	from: Vector3,
	to: Vector3,
	startTime: number,
	expiresAt: number,
	holdStarts: { [Player]: number }, -- when each player began holding
	holding: { [Player]: true }, -- players holding right now
	waypointSeq: number, -- bumped on every new waypoint so stale timers do nothing
	pinnedBy: Player?, -- set while pinned by a bear trap
}

-- What ItemService sees of a freak.
export type FreakInfo = {
	id: string,
	tier: number,
	rarity: string,
	species: string,
	position: Vector3,
	pinnedBy: Player?,
}

local FreakService = {}

local rng = Random.new()
local freaks: { [string]: Freak } = {}
local population: { [number]: number } = {}
local nextId = 0
local folder: Folder

local function now(): number
	return workspace:GetServerTimeNow()
end

local function groundY(): number
	return World.groundY + 0.1
end

local function currentPosition(freak: Freak): Vector3
	local position = Formulas.freakPosition(freak.from, freak.to, freak.startTime, Tiers[freak.species.tier].freakSpeed, now())
	return position
end

-- Inner and outer radius that spawn and wander targets must stay between.
local function zoneBounds(zone: World.Zone): (number, number)
	local margin = FreakConfig.wallMargin + World.wallThickness / 2
	local inner = zone.innerRadius > 0 and zone.innerRadius + margin or 0
	return inner, zone.outerRadius - margin
end

local function pointAtRadius(radius: number, angle: number): Vector3
	return World.center + Vector3.new(math.sin(angle) * radius, 0, -math.cos(angle) * radius) + Vector3.new(0, groundY(), 0)
end

-- A uniformly random point in the zone (by area, not by radius).
local function randomPointInZone(zone: World.Zone): Vector3
	local inner, outer = zoneBounds(zone)
	local radius = math.sqrt(rng:NextNumber() * (outer ^ 2 - inner ^ 2) + inner ^ 2)
	return pointAtRadius(radius, rng:NextNumber() * math.pi * 2)
end

-- A random point within `radius` of `near` that is still inside the zone.
local function randomPointNear(zone: World.Zone, near: Vector3, radius: number): Vector3
	local inner, outer = zoneBounds(zone)
	for _ = 1, 12 do
		local angle = rng:NextNumber() * math.pi * 2
		local r = math.sqrt(rng:NextNumber()) * radius
		local candidate = near + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
		local offset = candidate - World.center
		local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if distance >= inner and distance <= outer then
			return candidate
		end
	end
	return near
end

local despawn: (freak: Freak, reason: string) -> ()

-- Starts the freak walking from wherever it is now toward `to`, then schedules
-- the next waypoint after it arrives and waits.
local function setWaypoint(freak: Freak, to: Vector3)
	local from = currentPosition(freak)
	freak.from, freak.to, freak.startTime = from, to, now()
	freak.waypointSeq += 1
	local seq = freak.waypointSeq

	local model = freak.model
	model:SetAttribute("WpFrom", from)
	model:SetAttribute("WpTo", to)
	model:SetAttribute("WpStart", freak.startTime)
	-- Keep the server copy near the real position so streaming stays correct.
	local facing = (to - from).Magnitude > 1e-3 and CFrame.lookAt(from, to) or CFrame.new(from)
	model:PivotTo(facing)

	local speed = Tiers[freak.species.tier].freakSpeed
	local travel = (to - from).Magnitude / speed
	task.delay(travel + rng:NextNumber(FreakConfig.waitMin, FreakConfig.waitMax), function()
		if freaks[freak.id] == freak and freak.waypointSeq == seq and not freak.pinnedBy then
			setWaypoint(freak, randomPointNear(freak.homeZone, freak.to, FreakConfig.wanderRadius))
		end
	end)
end

local function notify(player: Player, message: string)
	Remotes.Notify:FireClient(player, message)
end

-- Server-side checks for a finished grab. The first player to pass wins.
local function tryGrab(player: Player, freak: Freak)
	local holdStart = freak.holdStarts[player]
	freak.holdStarts[player] = nil
	freak.holding[player] = nil
	if freaks[freak.id] ~= freak or not holdStart then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local data = DataService.get(player)
	if not (humanoid and root and data) or humanoid.Health <= 0 then
		return
	end

	local freakPosition = currentPosition(freak)
	local offset = root.Position - freakPosition
	if Vector3.new(offset.X, 0, offset.Z).Magnitude > FreakConfig.grabRange + RANGE_TOLERANCE then
		return
	end
	if Formulas.zoneFromPosition(root.Position).name ~= Formulas.zoneFromPosition(freakPosition).name then
		return
	end
	if freak.pinnedBy and freak.pinnedBy ~= player then
		notify(player, "That freak is pinned by someone else's trap")
		return
	end
	local required = if freak.pinnedBy == player
		then Items.bearTrap.pinnedHold
		else Formulas.holdTime(freak.species.tier, freak.rarity.id, data.upgrades.grip)
	if os.clock() - holdStart < required - HOLD_TOLERANCE then
		return
	end
	if not CarryService.hasFreeSlot(player) then
		notify(player, "Carry full — drop off your freaks first")
		return
	end

	CarryService.add(player, {
		species = freak.species.name,
		tier = freak.species.tier,
		rarity = freak.rarity.id,
		effects = {},
	})
	despawn(freak, "caught")
end

local function spawnFreak(species: FreakConfig.Species, rarity: Rarities.Rarity, homeZone: World.Zone, position: Vector3, counted: boolean): Freak
	nextId += 1
	local id = tostring(nextId)
	local model, body = FreakModels.build(species)
	model.Name = ("%s_%s_%s"):format(rarity.id, species.name, id)
	model:SetAttribute("FreakId", id)
	model:SetAttribute("Species", species.name)
	model:SetAttribute("Tier", species.tier)
	model:SetAttribute("Rarity", rarity.id)
	model:SetAttribute("WpSpeed", Tiers[species.tier].freakSpeed)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Grab"
	prompt.ObjectText = ("%s %s"):format(rarity.id, species.name)
	-- Roblox checks a prompt's range against the server's copy of the part, and
	-- the server only moves freaks at the start of each waypoint. So the server
	-- copy allows a whole waypoint's worth of distance, each client narrows its
	-- own copy to the real grab range (GrabController), and tryGrab checks range
	-- against the freak's actual position.
	prompt.MaxActivationDistance = FreakConfig.grabRange + FreakConfig.wanderRadius + RANGE_TOLERANCE
	prompt.RequiresLineOfSight = false
	-- Each client sets its own player's hold time (GrabController). The server
	-- copy stays 0 so it never disagrees with a player whose Grip upgrade
	-- shortens the hold; tryGrab does the real timing check, with tolerance.
	prompt.HoldDuration = 0
	prompt.Parent = body

	local freak: Freak = {
		id = id,
		species = species,
		rarity = rarity,
		homeZone = homeZone,
		counted = counted,
		model = model,
		from = position,
		to = position,
		startTime = now(),
		expiresAt = now() + rng:NextNumber(FreakConfig.lifetimeMin, FreakConfig.lifetimeMax),
		holdStarts = {},
		holding = {},
		waypointSeq = 0,
		pinnedBy = nil,
	}

	prompt.PromptButtonHoldBegan:Connect(function(player)
		freak.holdStarts[player] = os.clock()
		freak.holding[player] = true
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player)
		freak.holding[player] = nil
	end)
	prompt.Triggered:Connect(function(player)
		tryGrab(player, freak)
	end)

	freaks[id] = freak
	if counted then
		population[species.tier] = (population[species.tier] or 0) + 1
	end
	model:AddTag("Freak")
	model.Parent = folder
	setWaypoint(freak, position)
	return freak
end

local function zoneForTier(tier: number): World.Zone
	for _, zone in World.zones do
		if zone.name == Tiers[tier].zone then
			return zone
		end
	end
	error("no zone for tier " .. tier)
end

-- Spawns one population freak in a tier's ring with a random species and rarity.
local function spawnInRing(tier: number)
	local speciesList = FreakConfig.species[tier]
	local species = speciesList[rng:NextInteger(1, #speciesList)]
	local rarity = Rarities.byId[Formulas.rollRarity(rng:NextNumber())]
	local zone = zoneForTier(tier)
	spawnFreak(species, rarity, zone, randomPointInZone(zone), true)
end

function despawn(freak: Freak, _reason: string)
	if freaks[freak.id] ~= freak then
		return
	end
	freaks[freak.id] = nil
	freak.model:Destroy()
	if freak.counted then
		local tier = freak.species.tier
		population[tier] -= 1
		task.delay(FreakConfig.respawnDelay, spawnInRing, tier)
	end
end

-- Studio debug: spawns a freak of the given tier and rarity a few studs in
-- front of the player. It wanders inside whichever zone it spawned in and is
-- not part of any ring's population.
function FreakService.spawnNear(player: Player, tier: number, rarityId: string): string
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	assert(root, "no character")
	assert(FreakConfig.species[tier], "unknown tier " .. tostring(tier))
	local rarity = Rarities.byId[rarityId]
	assert(rarity, "unknown rarity " .. tostring(rarityId))
	local speciesList = FreakConfig.species[tier]
	local species = speciesList[rng:NextInteger(1, #speciesList)]
	local spot = root.Position + root.CFrame.LookVector * 6
	local position = Vector3.new(spot.X, groundY(), spot.Z)
	local freak = spawnFreak(species, rarity, Formulas.zoneFromPosition(position), position, false)
	return freak.model.Name
end

-- Every freak within `radius` studs (horizontally) of `center`, nearest first.
function FreakService.query(center: Vector3, radius: number): { FreakInfo }
	local found = {}
	for _, freak in freaks do
		local position = currentPosition(freak)
		local offset = position - center
		if Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius then
			table.insert(found, {
				id = freak.id,
				tier = freak.species.tier,
				rarity = freak.rarity.id,
				species = freak.species.name,
				position = position,
				pinnedBy = freak.pinnedBy,
			})
		end
	end
	table.sort(found, function(a, b)
		return (a.position - center).Magnitude < (b.position - center).Magnitude
	end)
	return found
end

-- Moves a freak straight into the player's carry bar (no hold), if it still
-- exists and they have a free slot. Callers do their own eligibility checks.
function FreakService.capture(player: Player, id: string): boolean
	local freak = freaks[id]
	if not freak or not CarryService.hasFreeSlot(player) then
		return false
	end
	CarryService.add(player, {
		species = freak.species.name,
		tier = freak.species.tier,
		rarity = freak.rarity.id,
		effects = {},
	})
	despawn(freak, "caught")
	return true
end

-- Stops a freak where it is for `duration` seconds; only `owner` can grab it
-- meanwhile. Returns false if the freak is gone or already pinned.
function FreakService.pin(id: string, owner: Player, duration: number): boolean
	local freak = freaks[id]
	if not freak or freak.pinnedBy then
		return false
	end
	setWaypoint(freak, currentPosition(freak)) -- stand still
	freak.pinnedBy = owner
	freak.model:SetAttribute("PinnedBy", owner.UserId)
	freak.model:SetAttribute("PinnedUntil", now() + duration)
	task.delay(duration, function()
		if freaks[id] == freak and freak.pinnedBy == owner then
			freak.pinnedBy = nil
			freak.model:SetAttribute("PinnedBy", nil)
			freak.model:SetAttribute("PinnedUntil", nil)
			setWaypoint(freak, randomPointNear(freak.homeZone, freak.to, FreakConfig.wanderRadius))
		end
	end)
	return true
end

function FreakService.exists(id: string): boolean
	return freaks[id] ~= nil
end

function FreakService.getPopulation(tier: number): number
	return population[tier] or 0
end

function FreakService.start()
	folder = Instance.new("Folder")
	folder.Name = "Freaks"
	folder.Parent = workspace

	for _, tier in FreakConfig.spawnTiers do
		for _ = 1, Tiers[tier].population do
			spawnInRing(tier)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		for _, freak in freaks do
			freak.holdStarts[player] = nil
			freak.holding[player] = nil
		end
	end)

	-- Expire old freaks, except ones someone is holding the grab on.
	task.spawn(function()
		while true do
			task.wait(1)
			local t = now()
			for _, freak in freaks do
				if t >= freak.expiresAt and next(freak.holding) == nil and not freak.pinnedBy then
					despawn(freak, "expired")
				end
			end
		end
	end)
end

return FreakService
