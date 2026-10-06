--!strict
-- Rarity table from DESIGN.md section 5, in spawn-roll order (lowest first).

export type Rarity = {
	id: string,
	chance: number, -- spawn chance; all chances add up to 1
	incomeMultiplier: number,
	holdMultiplier: number,
	color: Color3, -- outline color on freaks; also used in the UI
}

local list: { Rarity } = {
	{ id = "Common", chance = 0.50, incomeMultiplier = 1, holdMultiplier = 1, color = Color3.fromRGB(165, 165, 170) },
	{ id = "Uncommon", chance = 0.30, incomeMultiplier = 2, holdMultiplier = 1.5, color = Color3.fromRGB(75, 205, 90) },
	{ id = "Rare", chance = 0.14, incomeMultiplier = 5, holdMultiplier = 2.5, color = Color3.fromRGB(60, 140, 255) },
	{ id = "Epic", chance = 0.05, incomeMultiplier = 15, holdMultiplier = 4, color = Color3.fromRGB(170, 80, 240) },
	{ id = "Legendary", chance = 0.01, incomeMultiplier = 50, holdMultiplier = 6, color = Color3.fromRGB(255, 200, 40) },
}

local byId: { [string]: Rarity } = {}
for _, rarity in list do
	byId[rarity.id] = rarity
end

return {
	list = list,
	byId = byId,
}
