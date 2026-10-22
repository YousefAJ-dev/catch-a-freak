--!strict
-- Tier table from DESIGN.md section 5. Index = tier number. One ring per tier.
--
-- Population is not listed per tier: every ring holds the same density of
-- freaks as Ring 1 (70 freaks), so outer rings, which have more ground area
-- at the same width, get proportionally more freaks and never feel sparse.

local World = require(script.Parent.World)
local Upgrades = require(script.Parent.Upgrades)

export type Tier = {
	tier: number,
	zone: string, -- matches a zone name in World.zones
	population: number, -- filled in below from the ring's area
	radiationDps: number, -- with no Hazmat Suit; filled in below
	baseIncome: number, -- $/sec
	baseHold: number, -- seconds
	freakSpeed: number, -- studs/sec
}

local RING_1_POPULATION = 70

-- Radiation is tied to the Hazmat Suit: each ring is hotter than the last by
-- exactly what one ring's Hazmat levels block, times RADIATION_CREEP. So a
-- player fully geared for their ring takes about 3% more damage there than in
-- the ring before, and a ring that just unlocked runs about 2.3× hotter until
-- its Hazmat levels are bought. This holds however many rings there are.
local RING_1_RADIATION = 6
local RADIATION_CREEP = 1.03
local hazmatPerTier = Upgrades.hazmat.effectPerLevel ^ (Upgrades.hazmat.levelsPerTier :: number)
local RADIATION_GROWTH = RADIATION_CREEP / hazmatPerTier

local Tiers: { Tier } = {
	{ tier = 1, zone = "Ring1", population = 0, radiationDps = 0, baseIncome = 1, baseHold = 1.0, freakSpeed = 6 },
	{ tier = 2, zone = "Ring2", population = 0, radiationDps = 0, baseIncome = 8, baseHold = 2.0, freakSpeed = 9 },
	{ tier = 3, zone = "Ring3", population = 0, radiationDps = 0, baseIncome = 75, baseHold = 3.5, freakSpeed = 12 },
	{ tier = 4, zone = "Ring4", population = 0, radiationDps = 0, baseIncome = 750, baseHold = 5.5, freakSpeed = 14 },
	{ tier = 5, zone = "Ring5", population = 0, radiationDps = 0, baseIncome = 7500, baseHold = 8.0, freakSpeed = 16 },
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
	-- 6, 14.1, 33, 77.5, 181.9 HP/s for Rings 1–5
	tier.radiationDps = RING_1_RADIATION * RADIATION_GROWTH ^ (tier.tier - 1)
end

return Tiers
