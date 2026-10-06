--!strict
-- Upgrade table from DESIGN.md section 7.
-- Cost of the next level = baseCost × growth ^ currentLevel (see Formulas.upgradeCost).

export type Upgrade = {
	id: string, -- key in the saved `upgrades` table
	name: string,
	maxLevel: number,
	baseCost: number,
	growth: number,
	effectPerLevel: number,
}

local Upgrades: { [string]: Upgrade } = {
	shoes = { id = "shoes", name = "Shoes", maxLevel = 10, baseCost = 50, growth = 4, effectPerLevel = 1 }, -- +walk speed
	hazmat = { id = "hazmat", name = "Hazmat Suit", maxLevel = 10, baseCost = 75, growth = 4, effectPerLevel = 1.7 }, -- radiation damage ÷ (1 + 1.7 × level)
	grip = { id = "grip", name = "Stronger Grip", maxLevel = 10, baseCost = 60, growth = 4, effectPerLevel = 0.07 }, -- −grab hold time
	farmCapacity = { id = "farmCapacity", name = "Farm Capacity", maxLevel = 13, baseCost = 150, growth = 2.8, effectPerLevel = 1 }, -- +incubator
	offlineCapacity = { id = "offlineCapacity", name = "Offline Capacity", maxLevel = 7, baseCost = 300, growth = 4, effectPerLevel = 1 }, -- +hour
}

return Upgrades
