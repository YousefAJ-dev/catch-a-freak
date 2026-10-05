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

World.zones = {
	{ name = "Shop", innerRadius = 0, outerRadius = 40 },
	{ name = "InnerRing", innerRadius = 40, outerRadius = 175 },
	{ name = "Ring1", innerRadius = 175, outerRadius = 375, tier = 1 },
	{ name = "Ring2", innerRadius = 375, outerRadius = 575, tier = 2 },
	{ name = "Ring3", innerRadius = 575, outerRadius = 775, tier = 3 },
} :: { Zone }

World.walls = {
	{ name = "SafeBarrier", radius = 175, height = 60, doorKind = "Opening" },
	{ name = "Tier2Wall", radius = 375, height = 120, doorKind = "TierDoor", tier = 2 },
	{ name = "Tier3Wall", radius = 575, height = 120, doorKind = "TierDoor", tier = 3 },
	{ name = "OuterBoundary", radius = 775, height = 120, doorKind = "None" },
} :: { Wall }

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
