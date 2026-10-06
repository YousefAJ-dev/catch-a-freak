--!strict
-- World layout from DESIGN.md section 2. Distances are studs from the map center.

export type Zone = {
	name: string,
	innerRadius: number,
	outerRadius: number,
	tier: number?, -- nil for the safe zone (shop + inner ring)
}

export type Wall = {
	name: string,
	radius: number,
	height: number,
	doorKind: "Opening" | "TierDoor" | "None",
	tier: number?, -- tier a TierDoor unlocks
}

local World = {}

World.center = Vector3.new(0, 0, 0)
World.groundY = 0

-- Rings: all the same width, one per tier, starting at the safe-zone barrier.
-- Adding a ring is just raising ringCount (plus its tier, species and gate).
World.safeRadius = 175 -- the barrier; shop + inner ring are inside it
World.ringWidth = 150
World.ringCount = 5
World.barrierHeight = 60
World.wallHeight = 120

World.zones = {
	{ name = "Shop", innerRadius = 0, outerRadius = 40 },
	{ name = "InnerRing", innerRadius = 40, outerRadius = World.safeRadius },
} :: { Zone }
World.walls = {
	{ name = "SafeBarrier", radius = World.safeRadius, height = World.barrierHeight, doorKind = "Opening" },
} :: { Wall }
for tier = 1, World.ringCount do
	local inner = World.safeRadius + World.ringWidth * (tier - 1)
	table.insert(World.zones, { name = "Ring" .. tier, innerRadius = inner, outerRadius = inner + World.ringWidth, tier = tier })
	if tier > 1 then
		table.insert(World.walls, { name = ("Tier%dWall"):format(tier), radius = inner, height = World.wallHeight, doorKind = "TierDoor", tier = tier })
	end
end
table.insert(World.walls, {
	name = "OuterBoundary",
	radius = World.safeRadius + World.ringWidth * World.ringCount,
	height = World.wallHeight,
	doorKind = "None",
})

World.wallThickness = 4
World.doorWidth = 24
-- N/E/S/W in degrees, measured from -Z (north) toward +X (east).
World.doorAngles = { 0, 90, 180, 270 }

World.farm = {
	plotCount = 8,
	plotRadius = 137, -- distance of each plot's center from the map center
	plotSize = 60, -- at this radius the corners stay clear of the 24-stud N/E/S/W lanes and the barrier
	-- Offset so plots sit between the N/E/S/W lanes instead of in them.
	angleOffset = 22.5,
	-- Freak pads: a grid split down the middle by an aisle, numbered front row
	-- first (front = the edge facing the shop), left to right seen from the front.
	padRows = 4,
	padColumns = 4, -- half on each side of the aisle
	padSize = 11, -- each pad is the floor of a square glass incubator this wide
	incubatorHeight = 16, -- inside height, tall enough for big freaks
	aisleWidth = 8,
	startingUnlockedPads = 3, -- matches the farm's starting capacity
	collectPadSize = 6,
	collectPadGap = 2, -- distance between the plot's front edge and the collection pad
}

World.safeZoneRegenPerSecond = 10

return World
