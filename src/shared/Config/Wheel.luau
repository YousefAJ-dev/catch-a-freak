--!strict
-- Daily wheel from DESIGN.md section 9. One free spin per UTC day; the server
-- rolls the prize, and the prize freak goes into a carry slot.
--
-- "Next tier" prizes become Epic / Legendary freaks of the player's own tier
-- once they're on the last tier, so the wheel never skips progression.

export type Prize = {
	chance: number,
	tierOffset: number, -- 0 = the player's highest tier, 1 = the next one
	rarity: string,
	lastTierRarity: string?, -- replaces a next-tier prize for last-tier players
	color: Color3,
}

local prizes: { Prize } = {
	{ chance = 0.47, tierOffset = 0, rarity = "Common", color = Color3.fromRGB(165, 165, 170) },
	{ chance = 0.40, tierOffset = 0, rarity = "Rare", color = Color3.fromRGB(60, 140, 255) },
	{ chance = 0.10, tierOffset = 1, rarity = "Common", lastTierRarity = "Epic", color = Color3.fromRGB(170, 80, 240) },
	{ chance = 0.03, tierOffset = 1, rarity = "Rare", lastTierRarity = "Legendary", color = Color3.fromRGB(255, 200, 40) },
}

return {
	prizes = prizes,
	spinSeconds = 4, -- length of the spin animation
}
