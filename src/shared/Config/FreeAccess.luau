--!strict
-- Free access (DESIGN.md section 10): whitelisted players get every Game Pass
-- (2x Money and all skins) for free, a free revive whenever it's offered, and
-- can buy Golden Bear Traps with in-game money at `goldenTrapPriceMultiplier`
-- × the Bear Trap's money price. The daily wheel is NOT included: no free or
-- extra spins.
--
-- Add someone by their User ID (the number in their profile link,
-- roblox.com/users/<UserId>/profile). User IDs never change; usernames can.
-- Access is checked on every join and nothing is saved, so removing someone
-- here takes it away the next time they join.
--
-- `passId`: an optional Game Pass that also grants free access (a paid VIP
-- whitelist). 0 for none; set it to the pass's ID from Creator Hub to sell it.

return {
	userIds = {
		3725760364, -- the developer
		292016505,
	},
	passId = 0,
	goldenTrapPriceMultiplier = 3,
}
