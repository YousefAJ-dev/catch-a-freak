--!strict
-- Monetization from DESIGN.md section 10.
--
-- PLACEHOLDER IDS: negative numbers mean "not created in Creator Hub yet".
-- Create each Developer Product / Game Pass, then paste its real ID here.
-- Prices are set in Creator Hub, not in code. Until then, test in Studio with
-- the /buy debug command, which runs the real receipt handler.

export type DevProduct = { key: string, id: number, name: string, description: string }
-- How a skin set dresses the character (CharacterService): the suit covers
-- torso, arms, legs and hands; boots cover the feet; optional goggles over
-- the eyes and a glow from the chest.
export type SkinLook = {
	suit: { color: Color3, material: Enum.Material },
	boots: { color: Color3, material: Enum.Material },
	goggles: Color3?,
	glow: Color3?,
}
export type SkinSet = { key: string, passId: number, name: string, description: string, look: SkinLook }

local developerProducts: { [string]: DevProduct } = {
	money2x = {
		key = "money2x",
		id = -1,
		name = "2x Money (1 hour)",
		description = "Doubles farm income and sell payouts for 60 minutes of play time",
	},
	extraSpin = {
		key = "extraSpin",
		id = -2,
		name = "Extra Wheel Spin",
		description = "One more spin of the daily wheel, usable right away",
	},
	revive = {
		key = "revive",
		id = -3,
		name = "Respawn with Caught Freaks",
		description = "Respawn at the shop still carrying everything you caught",
	},
}

-- Cosmetic only; the looks themselves arrive with the art in Milestone 10.
local skinSets: { SkinSet } = {
	{
		key = "labCoat",
		passId = -101,
		name = "Lab Coat Set",
		description = "White coat, safety goggles, polished boots",
		look = {
			suit = { color = Color3.fromRGB(240, 242, 245), material = Enum.Material.Fabric },
			boots = { color = Color3.fromRGB(30, 30, 34), material = Enum.Material.SmoothPlastic },
			goggles = Color3.fromRGB(120, 220, 255),
		},
	},
	{
		key = "toxic",
		passId = -102,
		name = "Toxic Set",
		description = "Glowing green suit and boots",
		look = {
			suit = { color = Color3.fromRGB(110, 230, 60), material = Enum.Material.SmoothPlastic },
			boots = { color = Color3.fromRGB(40, 70, 30), material = Enum.Material.Rubber },
			goggles = Color3.fromRGB(200, 255, 120),
			glow = Color3.fromRGB(130, 255, 70),
		},
	},
	{
		key = "gold",
		passId = -103,
		name = "Gold Set",
		description = "Gilded hazmat suit and shoes",
		look = {
			suit = { color = Color3.fromRGB(235, 185, 60), material = Enum.Material.Foil },
			boots = { color = Color3.fromRGB(190, 140, 40), material = Enum.Material.Foil },
			goggles = Color3.fromRGB(255, 230, 150),
			glow = Color3.fromRGB(255, 210, 90),
		},
	},
}

return {
	developerProducts = developerProducts,
	skinSets = skinSets,
	boostSeconds = 3600, -- per 2x Money purchase; stacks
	reviveOfferSeconds = 10, -- how long the offer stays on screen after dying
	-- How long a dead player's freaks are held for a revive purchase. Longer
	-- than the offer so a purchase dialog opened in time can still finish.
	reviveHoldSeconds = 300,
	receiptCacheSize = 50, -- processed purchase IDs kept (DESIGN.md section 12)
}
