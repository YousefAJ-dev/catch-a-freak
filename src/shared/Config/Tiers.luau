--!strict
-- Tier table from DESIGN.md section 5. Index = tier number.

export type Tier = {
	tier: number,
	zone: string, -- matches a zone name in World.zones
	population: number,
	radiationDps: number, -- with no Hazmat Suit; 100 HP lasts 12.5 s in Ring 1
	baseIncome: number, -- $/sec
	baseHold: number, -- seconds
	freakSpeed: number, -- studs/sec
}

local Tiers: { Tier } = {
	{ tier = 1, zone = "Ring1", population = 70, radiationDps = 8, baseIncome = 1, baseHold = 1.0, freakSpeed = 6 },
	{ tier = 2, zone = "Ring2", population = 80, radiationDps = 16, baseIncome = 10, baseHold = 2.0, freakSpeed = 9 },
	{ tier = 3, zone = "Ring3", population = 90, radiationDps = 32, baseIncome = 100, baseHold = 3.5, freakSpeed = 12 },
}

return Tiers
