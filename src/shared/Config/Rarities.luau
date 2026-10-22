--!strict
-- Rarity table from DESIGN.md section 5, in spawn-roll order (lowest first).
--
-- The two top rarities stand out from across a ring (FreakModels.decorate):
--   Rainbow     glows and sparkles in shifting rainbow colors
--   Radioactive glows a strong yellow-green and gives off radioactive motes;
--               carrying one hurts the carrier `damagePerSecond` HP every
--               second, anywhere, and the Hazmat Suit doesn't help
--               (RadiationService)

export type Rarity = {
	id: string,
	chance: number, -- spawn chance; all chances add up to 1
	incomeMultiplier: number,
	holdMultiplier: number,
	color: Color3, -- outline color on freaks; also used in the UI
	glow: Color3?, -- a light and particles on the freak in this color
	rainbow: boolean?, -- the outline, light and particles cycle through the rainbow
	damagePerSecond: number?, -- HP per second taken by a player carrying one
}

local list: { Rarity } = {
	{ id = "Common", chance = 0.56, incomeMultiplier = 1, holdMultiplier = 1, color = Color3.fromRGB(165, 165, 170) },
	{ id = "Uncommon", chance = 0.25, incomeMultiplier = 2, holdMultiplier = 1.5, color = Color3.fromRGB(75, 205, 90) },
	{ id = "Rare", chance = 0.15, incomeMultiplier = 3, holdMultiplier = 2.5, color = Color3.fromRGB(60, 140, 255) },
	{ id = "Epic", chance = 0.0351, incomeMultiplier = 9, holdMultiplier = 4, color = Color3.fromRGB(170, 80, 240) },
	{ id = "Legendary", chance = 0.007, incomeMultiplier = 20, holdMultiplier = 6, color = Color3.fromRGB(255, 200, 40) },
	-- Pink is what the menus show; on the freak itself everything cycles.
	{ id = "Rainbow", chance = 0.001, incomeMultiplier = 30, holdMultiplier = 8, color = Color3.fromRGB(255, 110, 200), glow = Color3.fromRGB(255, 110, 200), rainbow = true },
	{
		id = "Radioactive",
		chance = 0.001,
		incomeMultiplier = 40,
		holdMultiplier = 8,
		color = Color3.fromRGB(190, 255, 40),
		glow = Color3.fromRGB(170, 255, 30),
		damagePerSecond = 1,
	},
}

local byId: { [string]: Rarity } = {}
for _, rarity in list do
	byId[rarity.id] = rarity
end

return {
	list = list,
	byId = byId,
}
