--!strict
-- Rarity table from DESIGN.md section 5, in spawn-roll order (lowest first).

export type Rarity = {
	id: string,
	chance: number, -- spawn chance; all chances add up to 1
	incomeMultiplier: number,
	holdMultiplier: number,
	color: Color3,
	beam: boolean, -- emits a tall light beam visible across the ring
}

local list: { Rarity } = {
	{ id = "Common", chance = 0.50, incomeMultiplier = 1, holdMultiplier = 1, color = Color3.fromRGB(165, 165, 170), beam = false },
	{ id = "Uncommon", chance = 0.30, incomeMultiplier = 2, holdMultiplier = 1.5, color = Color3.fromRGB(75, 205, 90), beam = false },
	{ id = "Rare", chance = 0.14, incomeMultiplier = 5, holdMultiplier = 2.5, color = Color3.fromRGB(60, 140, 255), beam = false },
	{ id = "Epic", chance = 0.05, incomeMultiplier = 15, holdMultiplier = 4, color = Color3.fromRGB(170, 80, 240), beam = true },
	{ id = "Legendary", chance = 0.01, incomeMultiplier = 50, holdMultiplier = 6, color = Color3.fromRGB(255, 200, 40), beam = true },
}

local byId: { [string]: Rarity } = {}
for _, rarity in list do
	byId[rarity.id] = rarity
end

return {
	list = list,
	byId = byId,
}
