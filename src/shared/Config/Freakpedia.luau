--!strict
-- The Freakpedia (DESIGN.md section 5): a collection book of every species at
-- every rarity. An entry is discovered the first time the player catches that
-- species at that rarity (a grab, net, trap or wheel prize).
--
-- Rewards:
--   * each new entry pays `discoveryReward` × that freak's sell price
--   * a ring's page is complete once every species of the ring has been
--     caught at every rarity in `pageRarities`; each complete page gives a
--     permanent `pageBonus` on farm income
--   * each entry at a `shinyRarities` rarity adds `shinyBonus` on farm income
-- Bonuses add up: 2 complete pages and 3 shiny entries = +13% farm income.

return {
	discoveryReward = 1,
	pageRarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary" },
	pageBonus = 0.05,
	shinyRarities = { "Rainbow", "Radioactive" },
	shinyBonus = 0.01,
}
