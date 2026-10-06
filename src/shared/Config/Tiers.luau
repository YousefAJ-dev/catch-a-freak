--!strict
-- Tier table from DESIGN.md section 5. Index = tier number. One ring per tier.
--
-- Population is not listed per tier: every ring holds the same density of
-- freaks as Ring 1 (70 freaks), so outer rings, which have more ground area
-- at the same width, get proportionally more freaks and never feel sparse.

local World = require(script.Parent.World)

export type Tier = {
	tier: number,
	zone: string, -- matches a zone name in World.zones
	population: number, -- filled in below from the ring's area
	radiationDps: number, -- with no Hazmat Suit; doubles every ring
	baseIncome: number, -- $/sec
	baseHold: number, -- seconds
	freakSpeed: number, -- studs/sec
}

local RING_1_POPULATION = 70

local Tiers: { Tier } = {
	{ tier = 1, zone = "Ring1", population = 0, radiationDps = 8, baseIncome = 1, baseHold = 1.0, freakSpeed = 6 },
	{ tier = 2, zone = "Ring2", population = 0, radiationDps = 16, baseIncome = 10, baseHold = 2.0, freakSpeed = 9 },
	{ tier = 3, zone = "Ring3", population = 0, radiationDps = 32, baseIncome = 100, baseHold = 3.5, freakSpeed = 12 },
	{ tier = 4, zone = "Ring4", population = 0, radiationDps = 64, baseIncome = 1000, baseHold = 5.5, freakSpeed = 14 },
	{ tier = 5, zone = "Ring5", population = 0, radiationDps = 128, baseIncome = 10000, baseHold = 8.0, freakSpeed = 16 },
}

-- Population = Ring 1's density × the ring's area: 70, 112, 154, 196, 238.
local function ringArea(zoneName: string): number
	for _, zone in World.zones do
		if zone.name == zoneName then
			return math.pi * (zone.outerRadius ^ 2 - zone.innerRadius ^ 2)
		end
	end
	error("no zone " .. zoneName)
end
local density = RING_1_POPULATION / ringArea(Tiers[1].zone)
for _, tier in Tiers do
	tier.population = math.round(density * ringArea(tier.zone))
end

return Tiers
