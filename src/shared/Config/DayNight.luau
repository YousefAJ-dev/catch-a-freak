--!strict
-- Day/night cycle (DESIGN.md section 2). Every client runs the same clock off
-- the server's time (workspace:GetServerTimeNow()), so all players share it.
-- Most of the cycle is day. The sun stays fairly high through the day
-- (dayStart..dayEnd) because the 120-stud walls shade most of a ring's floor
-- when it's low.
--
-- Night blends each zone's own daytime look (Config/Biomes) toward `night`,
-- keeping strong moonlit ambient so freaks stay easy to spot. Zones with
-- `fixedLighting` (the Cavern, already lit as night) ignore the cycle.

return {
	-- Seconds of each phase, in order; one full cycle is their sum (20 min).
	daySeconds = 14 * 60,
	duskSeconds = 75,
	nightSeconds = 3 * 60 + 30,
	dawnSeconds = 75,

	-- Lighting.ClockTime at the start and end of each phase.
	dayStart = 10.5,
	dayEnd = 15.5,
	nightStart = 20, -- dusk runs dayEnd..nightStart
	nightEnd = 4, -- night runs nightStart..24..nightEnd; dawn runs nightEnd..dayStart

	night = {
		brightness = 1.4,
		ambient = Color3.fromRGB(105, 110, 150),
		outdoorAmbient = Color3.fromRGB(100, 108, 150),
		atmosphereColor = Color3.fromRGB(60, 66, 100),
		atmosphereDecay = Color3.fromRGB(30, 32, 60),
		tint = Color3.fromRGB(215, 222, 255),
		colorBrightness = 0.05,
		bloomThreshold = 1,
	},
}
