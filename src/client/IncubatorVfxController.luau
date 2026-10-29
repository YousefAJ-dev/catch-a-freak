--!nocheck
-- Incubator skin animations, adapted from the handover's IncubatorVFXClient
-- (Shared.Incubators). Animates every model tagged "IncubatorSkin" (the skins
-- FarmService puts on plots): ornament spin / bob, neon breathing, lantern
-- flicker, alien beacon blink, tech scanline, magma colour pulse, and particle
-- rates scaled by the player's graphics quality. Client-side only, and only
-- for skins within ANIM_DISTANCE of the camera.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Data = require(ReplicatedStorage.Shared.Incubators.IncubatorData)

local ANIM_DISTANCE = 450
local AXES = { X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis }

local IncubatorVfxController = {}

local tracked = {} -- model -> state

local function qualityScale(): number
	local ok, level = pcall(function()
		return UserSettings().GameSettings.SavedQualityLevel.Value
	end)
	if not ok or level == 0 then
		return 1 -- 0 = automatic
	end
	return math.clamp(level / 7, 0.25, 1)
end

local function breathe(part: BasePart, low: number, period: number): Tween
	local info = TweenInfo.new(period, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local tween = TweenService:Create(part, info, { Transparency = low })
	tween:Play()
	return tween
end

local function track(model: Model)
	if tracked[model] or not model.Parent then
		return
	end
	local skin = model:GetAttribute("IncubatorSkin")
	local d = skin and Data.Skins[skin]
	if not d then
		return
	end
	local state = { tweens = {}, spin = {}, spin2 = {}, lights = {}, scans = {}, angle = 0, angle2 = 0, t = 0 }
	local pivot = model:GetPivot()

	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local group = p:GetAttribute("IncubatorGroup")
			if group == "Ornament_Anim" then
				table.insert(state.spin, { part = p, offset = pivot:ToObjectSpace(p.CFrame) })
			elseif group == "Ornament_Anim2" then
				table.insert(state.spin2, { part = p, offset = pivot:ToObjectSpace(p.CFrame) })
			elseif (group == "Light_Strips" or group == "Interior_Light" or group == "Glass_Edge") and p.Material == Enum.Material.Neon then
				local low = (group == "Interior_Light" and 0.12) or (group == "Glass_Edge" and 0.1) or 0.2
				table.insert(state.tweens, breathe(p, low, 2.4 + math.random() * 0.6))
				if skin == "Volcano" then
					local info = TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
					local pulse = TweenService:Create(p, info, { Color = Color3.fromHex("#ff9a2a") })
					pulse:Play()
					table.insert(state.tweens, pulse)
				end
			elseif p:GetAttribute("Scanline") then
				table.insert(state.scans, p)
			end
		elseif p:IsA("PointLight") or p:IsA("SurfaceLight") then
			table.insert(state.lights, { light = p, seed = math.random() * 100 })
		elseif p:IsA("ParticleEmitter") then
			p.Rate = (p:GetAttribute("BaseRate") or p.Rate) * qualityScale()
		end
	end
	tracked[model] = state
end

local function untrack(model: Model)
	local state = tracked[model]
	if not state then
		return
	end
	for _, tween in state.tweens do
		tween:Cancel()
	end
	tracked[model] = nil
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPosition = camera.CFrame.Position
	for model, s in tracked do
		if not model.Parent then
			untrack(model)
			continue
		end
		local pivot = model:GetPivot()
		if (pivot.Position - cameraPosition).Magnitude > ANIM_DISTANCE then
			continue
		end
		s.t += dt
		local d = Data.Skins[model:GetAttribute("IncubatorSkin")]
		local U = model:GetAttribute("ModelUnit") or Data.Unit
		-- ornament animation
		local anim = d and d.Anim
		if anim and #s.spin > 0 then
			local centre = CFrame.new(anim.Center * U)
			local motion
			if anim.Kind == "spin" then
				s.angle += math.rad(anim.Speed) * dt
				motion = centre * CFrame.fromAxisAngle(AXES[anim.Axis], s.angle) * centre:Inverse()
			else -- bob
				motion = CFrame.new(0, math.sin(s.t * 2.2) * anim.Speed * U, 0)
			end
			for _, sp in s.spin do
				sp.part.CFrame = pivot * motion * sp.offset
			end
		end
		-- second animation channel (e.g. the Tech reactor rings)
		local anim2 = d and d.Anim2
		if anim2 and #s.spin2 > 0 then
			local centre = CFrame.new(anim2.Center * U)
			s.angle2 += math.rad(anim2.Speed) * dt
			local motion = centre * CFrame.fromAxisAngle(AXES[anim2.Axis], s.angle2) * centre:Inverse()
			for _, sp in s.spin2 do
				sp.part.CFrame = pivot * motion * sp.offset
			end
		end
		-- tech scanline sweeps up the chamber
		for _, part in s.scans do
			local y0, h = part:GetAttribute("ScanY0") or 1, part:GetAttribute("ScanH") or 10
			local f = (s.t * 0.35) % 1
			part.CFrame = pivot * CFrame.new(part:GetAttribute("ScanX") or 0, y0 + f * h, 0)
			-- faint: it sweeps through the freaks' cells and would wash them out
			part.Transparency = 0.8 + 0.15 * f
		end
		-- lights: flicker (lanterns/torches), blink (alien beacon), gentle breathing otherwise
		for _, entry in s.lights do
			local light = entry.light
			local base = light:GetAttribute("BaseBrightness") or 1
			if light:GetAttribute("Flicker") then
				light.Brightness = base * (0.8 + 0.2 * math.noise(s.t * 6, entry.seed))
			elseif light:GetAttribute("Blink") then
				light.Enabled = (s.t % 1.2) < 0.6
			else
				light.Brightness = base * (0.9 + 0.1 * math.sin(s.t * 2.4))
			end
		end
	end
end

function IncubatorVfxController.start()
	for _, model in CollectionService:GetTagged("IncubatorSkin") do
		track(model)
	end
	CollectionService:GetInstanceAddedSignal("IncubatorSkin"):Connect(function(model)
		task.defer(track, model)
	end)
	CollectionService:GetInstanceRemovedSignal("IncubatorSkin"):Connect(untrack)
	RunService.RenderStepped:Connect(step)
end

return IncubatorVfxController
