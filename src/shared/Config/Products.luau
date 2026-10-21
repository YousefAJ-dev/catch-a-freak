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
-- A Game Pass with a gameplay effect, owned for good once bought.
export type Pass = { key: string, passId: number, name: string, description: string }

local developerProducts: { [string]: DevProduct } = {
	-- One Golden Bear Trap (Config/Items.goldenTrap).
	goldenTrap = {
		key = "goldenTrap",
		id = 3718491005,
		name = "Golden Bear Trap",
		description = "A trap that lures and pins ONLY Rainbow and Radioactive freaks",
	},
	extraSpin = {
		key = "extraSpin",
		id = 3720604931,
		name = "Extra Wheel Spin",
		description = "One more spin of the daily wheel, usable right away",
	},
	revive = {
		key = "revive",
		id = 3720602904,
		name = "Respawn with Caught Freaks",
		description = "Respawn at the shop still carrying everything you caught",
	},
}

local passes: { [string]: Pass } = {
	money2x = {
		key = "money2x",
		passId = 2026484651,
		name = "2x Money",
		description = "Permanently doubles farm income and sell payouts",
	},
}

-- Cosmetic only; the looks themselves arrive with the art in Milestone 10.
local skinSets: { SkinSet } = {
	{
		key = "natureIncubator",
		passId = -101,
		name = "Nature Incubator",
		description = "",
		look = {
			
		},
	},
	{
		key = "iceIncubator",
		passId = -102,
		name = "Ice Incubator",
		description = "",
		look = {
			
		},
	},
	{
		key = "royalIncubator",
		passId = -103,
		name = "Royal Incubator",
		description = "",
		look = {
			
		},
	},
	{
		key = "voidIncubator",
		passId = -103,
		name = "Void Incubator",
		description = "",
		look = {
			
		},
	},
	{
		key = "alienIncubator",
		passId = -103,
		name = "Alien Incubator",
		description = "",
		look = {
			
		},
	},
	{
		key = "sakuraIncubator",
		passId = -103,
		name = "Sakura Incubator",
		description = "",
		look = {
			
		},
	},
	{
		key = "volcanoIncubator",
		passId = -103,
		name = "Volcano Incubator",
		description = "",
		look = {
			
		},
	},
	{
		key = "beachIncubator",
		passId = -103,
		name = "Beach Incubator",
		description = "",
		look = {
			
		},
	},
	{
		key = "techIncubator",
		passId = -103,
		name = "Tech Incubator",
		description = "",
		look = {
			
		},
	},
}

return {
	developerProducts = developerProducts,
	passes = passes,
	skinSets = skinSets,
	reviveOfferSeconds = 10, -- how long the offer stays on screen after dying
	-- How long a dead player's freaks are held for a revive purchase. Longer
	-- than the offer so a purchase dialog opened in time can still finish.
	reviveHoldSeconds = 300,
	receiptCacheSize = 50, -- processed purchase IDs kept (DESIGN.md section 12)
}
