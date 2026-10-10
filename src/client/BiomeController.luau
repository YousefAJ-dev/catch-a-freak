--!strict
-- Per-biome lighting (Config/Biomes) and the day/night cycle (Config/DayNight).
-- Each zone has its own daytime look; the cycle moves the sun and blends that
-- look toward night. When the player's zone changes (ZoneTier, set by the
-- server's ZoneService), the lighting fades to the new zone's look. Local
-- only; each player sees the lighting of the zone they're standing in, at the
-- shared time of day.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Biomes = require(ReplicatedStorage.Shared.Config.Biomes)
local DayNight = require(ReplicatedStorage.Shared.Config.DayNight)

local player = Players.LocalPlayer

local FADE_SECONDS = 2.5 -- zone-to-zone fade
local UPDATE_SECONDS = 0.25 -- how often the cycle updates the lighting outside a fade

local CYCLE_SECONDS = DayNight.daySeconds + DayNight.duskSeconds + DayNight.nightSeconds + DayNight.dawnSeconds

local BiomeController = {}

local function effect<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing :: any
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = Lighting
	return inst :: any
end

local function smooth(t: number): number
	return (1 - math.cos(math.pi * t)) / 2
end

-- The shared time of day: (ClockTime, how far into night 0..1).
local function timeOfDay(): (number, number)
	-- DayNightOffset is only ever set by the Studio /time command (DebugService).
	local offset = (workspace:GetAttribute("DayNightOffset") :: number?) or 0
	local t = (workspace:GetServerTimeNow() + offset) % CYCLE_SECONDS
	if t < DayNight.daySeconds then
		return DayNight.dayStart + (DayNight.dayEnd - DayNight.dayStart) * t / DayNight.daySeconds, 0
	end
	t -= DayNight.daySeconds
	if t < DayNight.duskSeconds then
		local f = t / DayNight.duskSeconds
		return DayNight.dayEnd + (DayNight.nightStart - DayNight.dayEnd) * f, smooth(f)
	end
	t -= DayNight.duskSeconds
	if t < DayNight.nightSeconds then
		local f = t / DayNight.nightSeconds
		return (DayNight.nightStart + (24 - DayNight.nightStart + DayNight.nightEnd) * f) % 24, 1
	end
	t -= DayNight.nightSeconds
	local f = t / DayNight.dawnSeconds
	return DayNight.nightEnd + (DayNight.dayStart - DayNight.nightEnd) * f, 1 - smooth(f)
end

type Look = { [string]: any } -- "<target>.<Property>" -> value

local function lerp(a: any, b: any, t: number): any
	if typeof(a) == "Color3" then
		return (a :: Color3):Lerp(b, t)
	end
	return a + (b - a) * t
end

-- Shortest way around the 24-hour clock, so fades never spin the sun.
local function lerpClock(a: number, b: number, t: number): number
	local diff = (b - a + 12) % 24 - 12
	return (a + diff * t) % 24
end

local function lookFor(tier: number, clock: number, night: number): Look
	local biome = Biomes[tier] or Biomes[0]
	local l = biome.lighting
	local n = DayNight.night
	if biome.fixedLighting then
		clock, night = l.clockTime, 0
	end
	return {
		["Lighting.ClockTime"] = clock,
		["Lighting.GeographicLatitude"] = l.latitude,
		["Lighting.Brightness"] = lerp(l.brightness, n.brightness, night),
		["Lighting.Ambient"] = lerp(l.ambient, n.ambient, night),
		["Lighting.OutdoorAmbient"] = lerp(l.outdoorAmbient, n.outdoorAmbient, night),
		["Atmosphere.Density"] = l.atmosphere.density,
		["Atmosphere.Offset"] = l.atmosphere.offset,
		["Atmosphere.Color"] = lerp(l.atmosphere.color, n.atmosphereColor, night),
		["Atmosphere.Decay"] = lerp(l.atmosphere.decay, n.atmosphereDecay, night),
		["Atmosphere.Glare"] = lerp(l.atmosphere.glare, 0, night),
		["Atmosphere.Haze"] = l.atmosphere.haze,
		["Grading.TintColor"] = lerp(l.colorCorrection.tint, n.tint, night),
		["Grading.Saturation"] = l.colorCorrection.saturation,
		["Grading.Contrast"] = l.colorCorrection.contrast,
		["Grading.Brightness"] = lerp(l.colorCorrection.brightness, n.colorBrightness, night),
		["Bloom.Intensity"] = l.bloom.intensity,
		["Bloom.Size"] = l.bloom.size,
		["Bloom.Threshold"] = lerp(l.bloom.threshold, n.bloomThreshold, night),
	}
end

function BiomeController.start()
	local targets: { [string]: Instance } = {
		Lighting = Lighting,
		Atmosphere = effect("Atmosphere", "BiomeAtmosphere"),
		Grading = effect("ColorCorrectionEffect", "BiomeColor"),
		Bloom = effect("BloomEffect", "BiomeBloom"),
	}
	local setters: { [string]: (any) -> () } = {}
	for key in lookFor(0, 12, 0) do
		local target, prop = string.match(key, "^(%w+)%.(%w+)$")
		local inst = targets[target :: string] :: any
		setters[key] = function(value)
			inst[prop :: string] = value
		end
	end

	local tier = (player:GetAttribute("ZoneTier") :: number?) or 0
	local current: Look = {} -- what's applied now
	local from: Look? = nil -- what a running fade started from
	local fadeStart = 0
	local lastUpdate = -math.huge

	local function update(force: boolean)
		local now = os.clock()
		if not (force or from or now - lastUpdate >= UPDATE_SECONDS) then
			return
		end
		lastUpdate = now
		local clock, night = timeOfDay()
		local look = lookFor(tier, clock, night)
		local fadeFrom = from
		if fadeFrom then
			local t = math.clamp((now - fadeStart) / FADE_SECONDS, 0, 1)
			if t >= 1 then
				from = nil
			else
				local e = smooth(t)
				for key, value in look do
					look[key] = if key == "Lighting.ClockTime"
						then lerpClock(fadeFrom[key], value, e)
						else lerp(fadeFrom[key], value, e)
				end
			end
		end
		for key, value in look do
			setters[key](value)
		end
		current = look
	end

	player:GetAttributeChangedSignal("ZoneTier"):Connect(function()
		tier = (player:GetAttribute("ZoneTier") :: number?) or 0
		from = table.clone(current)
		fadeStart = os.clock()
	end)
	update(true)
	RunService.Heartbeat:Connect(function()
		update(false)
	end)
end

return BiomeController
