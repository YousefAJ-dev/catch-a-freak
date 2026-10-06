--!strict
-- Upgrade table from DESIGN.md section 7.
-- Cost of the next level = baseCost × growth ^ currentLevel (see Formulas.upgradeCost).
-- Gear (Shoes, Hazmat, Grip) unlocks levelsPerTier levels per unlocked tier
-- (see Formulas.upgradeLevelCap); its growth of 10^(1/5) makes each ring's
-- 5 levels cost 10× the previous ring's, matching each ring's 10× income.

export type Upgrade = {
	id: string, -- key in the saved `upgrades` table
	name: string,
	maxLevel: number,
	baseCost: number,
	growth: number,
	effectPerLevel: number,
	levelsPerTier: number?, -- set for gear: levels unlocked per highest tier
}

local GEAR_GROWTH = 10 ^ (1 / 5)

local Upgrades: { [string]: Upgrade } = {
	-- +walk speed per level (capped by PlayerConfig.maxWalkSpeed; level 16 reaches it)
	shoes = { id = "shoes", name = "Shoes", maxLevel = 16, baseCost = 50, growth = GEAR_GROWTH, effectPerLevel = 2.5, levelsPerTier = 5 },
	-- radiation damage × effectPerLevel ^ level
	hazmat = { id = "hazmat", name = "Hazmat Suit", maxLevel = 25, baseCost = 75, growth = GEAR_GROWTH, effectPerLevel = 0.85, levelsPerTier = 5 },
	-- grab hold time × effectPerLevel ^ level
	grip = { id = "grip", name = "Stronger Grip", maxLevel = 25, baseCost = 60, growth = GEAR_GROWTH, effectPerLevel = 0.93, levelsPerTier = 5 },
	farmCapacity = { id = "farmCapacity", name = "Farm Capacity", maxLevel = 13, baseCost = 150, growth = 2.8, effectPerLevel = 1 }, -- +incubator
	offlineCapacity = { id = "offlineCapacity", name = "Offline Capacity", maxLevel = 7, baseCost = 300, growth = 4, effectPerLevel = 1 }, -- +hour
}

return Upgrades
