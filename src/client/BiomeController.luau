--!strict
-- Per-biome lighting (Config/Biomes): when the player's zone changes
-- (ZoneTier, set by the server's ZoneService), fade the sky, ambient light,
-- haze and color grading to that zone's look. Local only; each player sees
-- the lighting of the zone they're standing in.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Biomes = require(ReplicatedStorage.Shared.Config.Biomes)

local player = Players.LocalPlayer

local FADE = TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

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

function BiomeController.start()
	local atmosphere = effect("Atmosphere", "BiomeAtmosphere") :: Atmosphere
	local grading = effect("ColorCorrectionEffect", "BiomeColor") :: ColorCorrectionEffect
	local bloom = effect("BloomEffect", "BiomeBloom") :: BloomEffect
	local tweens: { Tween } = {}

	local function apply(tier: number, instant: boolean)
		local biome = Biomes[tier] or Biomes[0]
		local l = biome.lighting
		for _, tween in tweens do
			tween:Cancel()
		end
		table.clear(tweens)
		local targets: { { inst: Instance, props: { [string]: any } } } = {
			{
				inst = Lighting,
				props = {
					ClockTime = l.clockTime,
					GeographicLatitude = l.latitude,
					Brightness = l.brightness,
					Ambient = l.ambient,
					OutdoorAmbient = l.outdoorAmbient,
				},
			},
			{
				inst = atmosphere,
				props = {
					Density = l.atmosphere.density,
					Offset = l.atmosphere.offset,
					Color = l.atmosphere.color,
					Decay = l.atmosphere.decay,
					Glare = l.atmosphere.glare,
					Haze = l.atmosphere.haze,
				},
			},
			{
				inst = grading,
				props = {
					TintColor = l.colorCorrection.tint,
					Saturation = l.colorCorrection.saturation,
					Contrast = l.colorCorrection.contrast,
					Brightness = l.colorCorrection.brightness,
				},
			},
			{ inst = bloom, props = { Intensity = l.bloom.intensity, Size = l.bloom.size, Threshold = l.bloom.threshold } },
		}
		for _, target in targets do
			local inst, props = target.inst, target.props
			if instant then
				for k, v in props do
					(inst :: any)[k] = v
				end
			else
				local tween = TweenService:Create(inst, FADE, props)
				tween:Play()
				table.insert(tweens, tween)
			end
		end
	end

	player:GetAttributeChangedSignal("ZoneTier"):Connect(function()
		apply((player:GetAttribute("ZoneTier") :: number?) or 0, false)
	end)
	apply((player:GetAttribute("ZoneTier") :: number?) or 0, true)
end

return BiomeController
