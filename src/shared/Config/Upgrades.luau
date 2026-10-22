--!strict
-- Upgrade table from DESIGN.md section 7. Prices come from Formulas.upgradeCost.
--
-- Ring-priced upgrades (levelsPerTier set) unlock levelsPerTier levels per
-- unlocked tier (Formulas.upgradeLevelCap) and are priced per ring:
--   * Each ring has a gear budget: what its full set of Shoes, Hazmat and Grip
--     levels costs in total. It's sized from the ring's income and its target
--     time (Config/Economy), so buying a ring's gear takes about that long for
--     a strong farm: 30 min for Ring 1, then 1, 2, 3, 4 h (N − 1 h for Ring N).
--   * `priceWeight` is the upgrade's share of that budget at its first level in
--     the ring, and each further level in the ring costs `growth` times more.
--   * Farm and Offline Capacity are priced off the same budget but aren't part
--     of it (they pay for themselves in income).
-- Other upgrades cost `baseCost × growth ^ level`, or `priceOf` another
-- upgrade's last level.

export type Upgrade = {
	id: string, -- key in the saved `upgrades` table
	name: string,
	maxLevel: number,
	effectPerLevel: number,
	growth: number, -- price × this per level (within a ring, if ring-priced)
	levelsPerTier: number?, -- ring-priced: levels unlocked per highest tier
	priceWeight: number?, -- ring-priced: share of the ring's gear budget
	baseCost: number?, -- otherwise: cost of the first level
	priceOf: { upgrade: string, multiplier: number }?, -- otherwise: × that upgrade's last level
	requires: { upgrade: string, level: number }?, -- must own this first
}

local Upgrades: { [string]: Upgrade } = {
	-- +walk speed per level (capped by PlayerConfig.maxWalkSpeed; level 10, the
	-- first Ring 4 level, reaches it)
	shoes = { id = "shoes", name = "Shoes", maxLevel = 10, effectPerLevel = 4.2, levelsPerTier = 3, priceWeight = 400, growth = 3 },
	-- radiation damage × effectPerLevel ^ level. Each ring's 3 levels block
	-- what that ring adds (Config/Tiers ties radiation to this). Raise maxLevel
	-- by 3 per ring when adding rings.
	hazmat = { id = "hazmat", name = "Hazmat Suit", maxLevel = 15, effectPerLevel = 0.76, levelsPerTier = 3, priceWeight = 600, growth = 3 },
	-- grab hold time × effectPerLevel ^ level
	grip = { id = "grip", name = "Stronger Grip", maxLevel = 25, effectPerLevel = 0.93, levelsPerTier = 5, priceWeight = 250, growth = 2 },
	-- +1 incubator per level: 2 more per ring, all 16 by Ring 7
	farmCapacity = { id = "farmCapacity", name = "Farm Capacity", maxLevel = 14, effectPerLevel = 1, levelsPerTier = 2, priceWeight = 500, growth = 2.5 },
	-- Raises the offline money cap from 1/4 of the ring's gear budget to 1/3,
	-- then 1/2 (Economy.offlineBudgetShares). Raise maxLevel by 2 per ring.
	offlineCapacity = { id = "offlineCapacity", name = "Offline Capacity", maxLevel = 10, effectPerLevel = 1, levelsPerTier = 2, priceWeight = 1000, growth = 2 },
	-- Dash: a one-time purchase once Shoes is maxed, priced at 2.5× the last
	-- Shoes level. Dash Recharge then shortens its cooldown (see Config/Dash).
	dash = {
		id = "dash",
		name = "Dash",
		maxLevel = 1,
		effectPerLevel = 1,
		priceOf = { upgrade = "shoes", multiplier = 2.5 },
		growth = 1,
		requires = { upgrade = "shoes", level = 10 },
	},
	dashRecharge = {
		id = "dashRecharge",
		name = "Dash Recharge",
		maxLevel = 5,
		effectPerLevel = 1, -- seconds off the cooldown (Config/Dash.cooldownPerLevel)
		priceOf = { upgrade = "dash", multiplier = 1 },
		growth = 3,
		requires = { upgrade = "dash", level = 1 },
	},
}

return Upgrades
