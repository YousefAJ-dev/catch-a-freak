--!strict
-- Dash (DESIGN.md section 4): a short burst forward, bought once Shoes is
-- maxed, for getting through the later rings faster. Dash Recharge upgrades
-- shorten the cooldown.

return {
	key = Enum.KeyCode.F,
	distance = 50, -- studs covered by one dash
	duration = 0.4, -- seconds the burst lasts
	baseCooldown = 8, -- seconds, with no Dash Recharge
	cooldownPerLevel = 1, -- seconds removed per Dash Recharge level
}
