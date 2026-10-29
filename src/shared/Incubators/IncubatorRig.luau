-- IncubatorRig, from the incubator skin handover (CatchAFreak_Incubators_Handover,
-- v3.3). Used once in Studio to rig each imported skin into a template in
-- ServerStorage.IncubatorSkins (DESIGN.md section 10, "Incubator skins");
-- FarmService then clones the templates onto plots. Kept as delivered.
-- Rig.setup(model) turns an imported incubator (GLB) into a finished in-game incubator:
--   • scales it to game size the first time (Rig.SIZE), keeps any size you set yourself afterwards
--   • pivot at the centre of the base on the ground, entrance facing the model's front (-Z / LookVector)
--   • Roblox materials / colours / transparency per part (Neon glow, Glass, Foil gold, Ice…)
--   • collision: base, walkway, cell glass and columns are solid; decoration is not
--   • 16 slot attachments (Slot01 … Slot16), one in the middle of each glowing cell tile
--   • lights + theme VFX under a "VFX" folder, tag "IncubatorSkin" for IncubatorVFXClient
-- Safe to run more than once.
--
-- Spawning a freak in a cell:
--   local cf = Rig.slotCFrame(incubatorModel, 7)   -- CFrame on top of cell 7's floor tile, facing the walkway
--   freak:PivotTo(cf)
-- Colouring a cell tile (e.g. by rarity):  Rig.slotTile(incubatorModel, 7).Color = Color3.fromRGB(255, 200, 0)

local CollectionService = game:GetService("CollectionService")
local Data = require(script.Parent:WaitForChild("IncubatorData"))

local Rig = {}

-- Size multiplier applied the first time a model is rigged. 1 = 73.6 x 70.4 studs base,
-- each cell 16 x 16 studs, 18.4 studs tall inside. Change this if your friend's game needs bigger/smaller.
Rig.SIZE = 1

local TEX_SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
-- Optional: upload a petal decal and paste its id here for the Sakura petals (falls back to sparkles).
Rig.PETAL_TEXTURE = ""
Rig.LEAF_TEXTURE = ""   -- optional leaf decal id for Nature's falling leaves

local SOLID_GROUPS = {
	Base_Platform = true, Base_Trim = true, Support_Columns = true, Back_Panel = true, Walkway = true,
	Glass_Side = true, Glass_Rear = true, Glass_Front = true, Glass_Top = true, Interior_Floor = true, Slot_Tile = true,
	Roof_Frame = true,
}
local NO_SHADOW_GROUPS = {
	Glass_Side = true, Glass_Rear = true, Glass_Front = true, Glass_Top = true, Entrance_Barrier = true, Glass_Edge = true,
	Interior_Light = true, Light_Strips = true, Decor_Small = true, Foliage = true, Slot_Tile = true, Ornament_Anim2 = true,
}
local WARM = {
	["#ffc66a"] = true, ["#ffbe40"] = true, ["#ffcc5a"] = true, ["#ffbb40"] = true, ["#ffa060"] = true,
	["#ffd36a"] = true, ["#ff8a2a"] = true, ["#ff7a2a"] = true,
}

local function seq(...): NumberSequence
	local args = { ... }
	local kps = {}
	for i = 1, #args, 2 do
		table.insert(kps, NumberSequenceKeypoint.new(args[i], args[i + 1]))
	end
	return NumberSequence.new(kps)
end

local function scaleSeq(s: NumberSequence, k: number): NumberSequence
	local kps = {}
	for _, kp in ipairs(s.Keypoints) do
		table.insert(kps, NumberSequenceKeypoint.new(kp.Time, kp.Value * k, kp.Envelope * k))
	end
	return NumberSequence.new(kps)
end

local function cseq(a: Color3, b: Color3?): ColorSequence
	return ColorSequence.new(a, b or a)
end

local function skinFromModel(model: Instance): string?
	local attr = model:GetAttribute("IncubatorSkin")
	if typeof(attr) == "string" and Data.Skins[attr] then return attr end
	for skin, d in pairs(Data.Skins) do
		if model.Name == d.ModelName or string.find(model.Name, "Incubator_" .. skin, 1, true) then
			return skin
		end
	end
	return nil
end

-- "<Group>__<Material>" (+ importer suffixes). Cell tiles are "SlotTile_07__<Material>".
local function parse(part: BasePart): (string?, string?, number?)
	local group, mat = string.match(part.Name, "^(.-)__(.+)$")
	if not group then return nil, nil, nil end
	mat = string.gsub(mat, "%.%d+$", "")
	local slot = string.match(group, "^SlotTile_(%d+)$")
	if slot then return "Slot_Tile", mat, tonumber(slot) end
	return group, mat, nil
end

local function resolveMaterial(d, matKey: string?): string?
	if not matKey then return nil end
	if d.Materials[matKey] then return matKey end
	local base = string.match(matKey, "^(.-)_%d+$")
	if base and d.Materials[base] then return base end
	return nil
end

-- ------------------------------------------------------------------ VFX recipes (design units)
local BX = Data.BankX
local FLOOR, ROOF = Data.FloorY, Data.RoofY
local function perBank(fn)
	for _, x in ipairs(BX) do fn(x) end
end

local FX = {}

FX.Tech = function(add, d)
	perBank(function(x)
		add.emitter("DataMotes", Vector3.new(x, FLOOR + 0.3, 0), Vector3.new(7.6, 0.1, 15.6), {
			Texture = TEX_SPARKLE, Color = cseq(Color3.fromHex("#38d6ff"), Color3.fromHex("#b8f3ff")),
			LightEmission = 1, Size = seq(0, 0.14, 1, 0), Transparency = seq(0, 0.2, 1, 1),
			Lifetime = NumberRange.new(2, 3.5), Rate = 14, Speed = NumberRange.new(0.6, 1.2),
			SpreadAngle = Vector2.new(10, 10), EmissionDirection = Enum.NormalId.Top,
		})
		add.scanline("Scanline", Vector3.new(x, FLOOR + 0.3, 0), Vector3.new(7.8, 0.01, 15.8), Color3.fromHex("#38d6ff"), FLOOR + 0.25, ROOF - FLOOR - 0.4)
	end)
	-- energy pulses travelling along the roof conduits (animated beam texture)
	for _, path in ipairs((d.Points and d.Points.pulse_paths) or {}) do
		for i = 1, #path - 1 do
			add.pulse("DataPulse", path[i], path[i + 1], Color3.fromHex("#7ff6ff"), 0.22)
		end
	end
	if d.Anim2 then
		add.emitter("ReactorSparks", d.Anim2.Center, Vector3.new(1.4, 1.6, 1.4), {
			Texture = TEX_SPARKLE, Color = cseq(Color3.fromHex("#9ff8ff"), Color3.fromHex("#9a5cff")), LightEmission = 1,
			Size = seq(0, 0.12, 1, 0), Lifetime = NumberRange.new(0.6, 1.1), Rate = 10, Speed = NumberRange.new(0.4, 1),
			SpreadAngle = Vector2.new(180, 180),
		})
	end
end

FX.Nature = function(add, d)
	perBank(function(x)
		add.emitter("Fireflies", Vector3.new(x, 2.6, 0), Vector3.new(7.6, 3.6, 15.6), {
			Texture = TEX_SPARKLE, Color = cseq(Color3.fromHex("#f5e86a"), Color3.fromHex("#b8ff6a")),
			LightEmission = 1, Size = seq(0, 0, 0.2, 0.13, 0.8, 0.13, 1, 0), Transparency = seq(0, 0.1, 0.5, 0.5, 1, 0.1),
			Lifetime = NumberRange.new(3, 5), Rate = 8, Speed = NumberRange.new(0.2, 0.5),
			SpreadAngle = Vector2.new(180, 180), RotSpeed = NumberRange.new(-30, 30),
		})
	end)
	add.emitter("OuterFireflies", Vector3.new(0, 2.5, 0), Vector3.new(24, 4, 23), {
		Texture = TEX_SPARKLE, Color = cseq(Color3.fromHex("#f5e86a")), LightEmission = 1,
		Size = seq(0, 0, 0.2, 0.13, 0.8, 0.13, 1, 0), Lifetime = NumberRange.new(3, 5), Rate = 8,
		Speed = NumberRange.new(0.2, 0.5), SpreadAngle = Vector2.new(180, 180),
	})
	-- leaves drifting down off the leafy roof edges
	local tex = (Rig.LEAF_TEXTURE ~= "" and Rig.LEAF_TEXTURE) or TEX_SPARKLE
	for _, p in ipairs({ Vector3.new(-8.6, 6.6, -9.4), Vector3.new(8.6, 6.6, -9.4), Vector3.new(-8.6, 6.6, 9.4), Vector3.new(8.6, 6.6, 9.4) }) do
		add.emitter("FallingLeaves", p, Vector3.new(4, 0.6, 1.5), {
			Texture = tex, Color = cseq(Color3.fromHex("#8bc94b"), Color3.fromHex("#e0b13a")), LightEmission = 0.1,
			Size = seq(0, 0.16, 1, 0.12), Transparency = seq(0, 0, 0.85, 0, 1, 1), Lifetime = NumberRange.new(5, 7),
			Rate = 3, Speed = NumberRange.new(0.2, 0.5), Acceleration = Vector3.new(0.3, -0.45, 0), Drag = 0.8,
			RotSpeed = NumberRange.new(-120, 120), Rotation = NumberRange.new(0, 360), SpreadAngle = Vector2.new(180, 180),
		})
	end
end

FX.Volcano = function(add, d)
	local P = d.Points or {}
	local crater = P.crater or Vector3.new(0, 12, 0.6)
	local cr = P.crater_r or 1.2
	-- layered smoke plumes from the crater
	add.emitter("CraterSmoke", crater + Vector3.new(0, 1.2, 0), Vector3.new(cr * 1.4, 0.3, cr * 1.4), {
		Texture = TEX_SMOKE, Color = cseq(Color3.fromHex("#3b3330"), Color3.fromHex("#141111")),
		LightEmission = 0, Size = seq(0, 1.6, 0.4, 3.2, 1, 6), Transparency = seq(0, 0.5, 0.6, 0.65, 1, 1),
		Lifetime = NumberRange.new(6, 9), Rate = 6, Speed = NumberRange.new(1.4, 2.4), Acceleration = Vector3.new(0.12, 0.35, 0),
		RotSpeed = NumberRange.new(-15, 15), Rotation = NumberRange.new(0, 360), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(12, 12),
	})
	add.emitter("CraterWisps", crater + Vector3.new(0, 0.8, 0), Vector3.new(cr, 0.3, cr), {
		Texture = TEX_SMOKE, Color = cseq(Color3.fromHex("#7a6a62"), Color3.fromHex("#3a3230")),
		LightEmission = 0.05, Size = seq(0, 0.8, 1, 2.6), Transparency = seq(0, 0.6, 1, 1),
		Lifetime = NumberRange.new(3, 5), Rate = 4, Speed = NumberRange.new(1.8, 3), RotSpeed = NumberRange.new(-30, 30),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20),
	})
	add.emitter("CraterGlow", crater + Vector3.new(0, 0.4, 0), Vector3.new(cr, 0.2, cr), {
		Texture = TEX_SMOKE, Color = cseq(Color3.fromHex("#ff7a1a"), Color3.fromHex("#5a1a08")),
		LightEmission = 0.6, Size = seq(0, 1.0, 1, 2.2), Transparency = seq(0, 0.55, 1, 1),
		Lifetime = NumberRange.new(1.2, 2), Rate = 5, Speed = NumberRange.new(0.8, 1.4), EmissionDirection = Enum.NormalId.Top,
	})
	-- molten splashes that arc out of the crater and fall back
	add.emitter("LavaSplash", crater + Vector3.new(0, 0.2, 0), Vector3.new(cr * 0.8, 0.1, cr * 0.8), {
		Texture = TEX_SPARKLE, Color = cseq(Color3.fromHex("#ffd36a"), Color3.fromHex("#ff3a0a")), LightEmission = 1,
		Size = seq(0, 0.22, 1, 0.08), Lifetime = NumberRange.new(0.9, 1.5), Rate = 7, Speed = NumberRange.new(2.2, 3.6),
		Acceleration = Vector3.new(0, -4.5, 0), SpreadAngle = Vector2.new(28, 28), EmissionDirection = Enum.NormalId.Top,
	})
	-- embers drifting up around the whole mountain and off the lava field
	add.emitter("Embers", Vector3.new(0, ROOF + 3, 0.6), Vector3.new(14, 6, 13), {
		Texture = TEX_SPARKLE, Color = cseq(Color3.fromHex("#ffb13a"), Color3.fromHex("#ff3a0a")),
		LightEmission = 1, Size = seq(0, 0.14, 1, 0), Transparency = seq(0, 0, 1, 1),
		Lifetime = NumberRange.new(2, 3.5), Rate = 14, Speed = NumberRange.new(0.6, 1.4), Acceleration = Vector3.new(0.1, 0.5, 0),
		SpreadAngle = Vector2.new(40, 40), EmissionDirection = Enum.NormalId.Top,
	})
	local ap = P.apron or { 11.8, 11.4 }
	add.emitter("LavaFieldEmbers", Vector3.new(0, 0.3, 0), Vector3.new(ap[1] * 2, 0.2, ap[2] * 2), {
		Texture = TEX_SPARKLE, Color = cseq(Color3.fromHex("#ff8a2a"), Color3.fromHex("#ff3a0a")), LightEmission = 1,
		Size = seq(0, 0.12, 1, 0), Lifetime = NumberRange.new(1.5, 2.5), Rate = 10, Speed = NumberRange.new(0.5, 1.2),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15),
	})
	add.emitter("Embers", d.Anim.Center, Vector3.new(1.2, 0.4, 0.8), {
		Texture = TEX_SPARKLE, Color = cseq(Color3.fromHex("#ffb13a"), Color3.fromHex("#ff3a0a")),
		LightEmission = 1, Size = seq(0, 0.2, 1, 0), Lifetime = NumberRange.new(1.5, 2.5), Rate = 6, Speed = NumberRange.new(1, 2),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25),
	})
end

FX.Ice = function(add, d)
	local P = d.Points or {}
	local summit = P.summit or Vector3.new(0, 10, 0.5)
	add.emitter("Snowfall", Vector3.new(0, summit.Y + 3, 0), Vector3.new(22, 0.2, 20), {
		Texture = TEX_SPARKLE, Color = cseq(Color3.fromHex("#ffffff"), Color3.fromHex("#cfefff")),
		LightEmission = 0.4, Size = seq(0, 0.13, 1, 0.08), Transparency = seq(0, 0, 0.85, 0, 1, 1),
		Lifetime = NumberRange.new(4, 6), Rate = 26, Speed = NumberRange.new(1.2, 2),
		EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(15, 15), RotSpeed = NumberRange.new(-60, 60),
	})
	add.emitter("SummitSpindrift", summit, Vector3.new(1.5, 0.4, 1.5), {
		Texture = TEX_SMOKE, Color = cseq(Color3.fromHex("#ffffff"), Color3.fromHex("#cfefff")), LightEmission = 0.2,
		Size = seq(0, 0.4, 1, 2.2), Transparency = seq(0, 0.55, 1, 1), Lifetime = NumberRange.new(1.5, 2.5),
		Rate = 6, Speed = NumberRange.new(1, 2), Acceleration = Vector3.new(1.4, 0.2, 0), RotSpeed = NumberRange.new(-40, 40),
	})
	perBank(function(x)
		add.emitter("FrostMist", Vector3.new(x, FLOOR + 0.3, 0), Vector3.new(7.6, 0.1, 15.6), {
			Texture = TEX_SMOKE, Color = cseq(Color3.fromHex("#bfe9ff")), LightEmission = 0.3,
			Size = seq(0, 1, 1, 3), Transparency = seq(0, 0.85, 1, 1), Lifetime = NumberRange.new(3, 4),
			Rate = 4, Speed = NumberRange.new(0.1, 0.3), RotSpeed = NumberRange.new(-15, 15),
		})
	end)
	for _, sx in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do
		add.emitter("CornerGlints", Vector3.new(sx * 9.4, 1.4, sz * 8.95), Vector3.new(1.2, 1.6, 1.2), {
			Texture = TEX_SPARKLE, Color = cseq(Color3.fromHex("#e6f8ff")), LightEmission = 1,
			Size = seq(0, 0, 0.3, 0.25, 1, 0), Lifetime = NumberRange.new(0.5, 0.8), Rate = 2, Speed = NumberRange.new(0, 0),
		})
	end end
end

FX.Royal = function(add, d)
	add.emitter("StarSparkles", d.Anim.Center, Vector3.new(2.4, 2.4, 0.8), {
		Texture = TEX_SPARKLE, Color = cseq(Color3.fromHex("#fff1b0"), Color3.fromHex("#e8b23a")), LightEmission = 1,
		Size = seq(0, 0.28, 1, 0), Lifetime = NumberRange.new(0.6, 1), Rate = 6, Speed = NumberRange.new(0, 0.3),
		SpreadAngle = Vector2.new(180, 180),
	})
	perBank(function(x)
		add.emitter("GoldDust", Vector3.new(x, 2.6, 0), Vector3.new(7.6, 3.6, 15.6), {
			Texture = TEX_SPARKLE, Color = cseq(Color3.fromHex("#ffd36a")), LightEmission = 1,
			Size = seq(0, 0.09, 1, 0), Lifetime = NumberRange.new(2, 3), Rate = 8, Speed = NumberRange.new(0.1, 0.3),
			SpreadAngle = Vector2.new(180, 180),
		})
	end)
	add.emitter("RoofGlints", Vector3.new(0, ROOF + 1.6, 0), Vector3.new(14, 0.6, 13), {
		Texture = TEX_SPARKLE, Color = cseq(Color3.fromHex("#fff1b0"), Color3.fromHex("#ffd36a")), LightEmission = 1,
		Size = seq(0, 0, 0.3, 0.22, 1, 0), Lifetime = NumberRange.new(0.5, 0.9), Rate = 6, Speed = NumberRange.new(0, 0.1),
	})
	for _, sx in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do
		add.emitter("CrystalGlints", Vector3.new(sx * 9.4, 1.4, sz * 8.95), Vector3.new(1.4, 1.8, 1.4), {
			Texture = TEX_SPARKLE, Color = cseq(Color3.fromHex("#fff1b0")), LightEmission = 1,
			Size = seq(0, 0, 0.3, 0.25, 1, 0), Lifetime = NumberRange.new(0.5, 0.8), Rate = 3, Speed = NumberRange.new(0, 0),
		})
	end end
end

FX.Void = function(add, d)
	add.emitter("VortexWisps", d.Anim.Center + Vector3.new(0, 0, -0.15), Vector3.new(0.3, 0.3, 0.1), {
		Texture = TEX_SPARKLE, Color = cseq(Color3.fromHex("#ff4fd8"), Color3.fromHex("#8a2cff")), LightEmission = 1,
		Size = seq(0, 0.05, 1, 0.7), Transparency = seq(0, 0.3, 1, 1), Lifetime = NumberRange.new(0.7, 0.9),
		Rate = 12, Speed = NumberRange.new(0, 0), RotSpeed = NumberRange.new(180, 260), LockedToPart = true,
	})
	perBank(function(x)
		add.emitter("VoidMotes", Vector3.new(x, 2.6, 0), Vector3.new(7.6, 3.6, 15.6), {
			Texture = TEX_SPARKLE, Color = cseq(Color3.fromHex("#c25cff"), Color3.fromHex("#ff4fd8")), LightEmission = 1,
			Size = seq(0, 0.12, 1, 0), Lifetime = NumberRange.new(2.5, 3.5), Rate = 12, Speed = NumberRange.new(0.2, 0.4),
			SpreadAngle = Vector2.new(180, 180),
		})
	end)
	local P = d.Points or {}
	local rift = P.rift or { 11.6, 11.2 }
	add.emitter("RiftWisps", Vector3.new(0, 0.2, 0), Vector3.new(rift[1] * 2, 0.2, rift[2] * 2), {
		Texture = TEX_SMOKE, Color = cseq(Color3.fromHex("#8a2cff"), Color3.fromHex("#2a0a4a")), LightEmission = 0.5,
		Size = seq(0, 0.6, 1, 2.4), Transparency = seq(0, 0.6, 1, 1), Lifetime = NumberRange.new(2, 3.5), Rate = 10,
		Speed = NumberRange.new(0.4, 0.9), RotSpeed = NumberRange.new(-30, 30), EmissionDirection = Enum.NormalId.Top,
	})
	for _, c in ipairs(P.corners or {}) do
		add.emitter("CrystalSparks", c + Vector3.new(0, 3, 0), Vector3.new(3, 5, 3), {
			Texture = TEX_SPARKLE, Color = cseq(Color3.fromHex("#ff4fd8"), Color3.fromHex("#c25cff")), LightEmission = 1,
			Size = seq(0, 0.2, 1, 0), Lifetime = NumberRange.new(1.5, 2.5), Rate = 8, Speed = NumberRange.new(0.6, 1.4),
			Acceleration = Vector3.new(0, 0.6, 0), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30),
		})
	end
	if P.crown then
		add.emitter("RiftColumn", P.crown, Vector3.new(2.4, 0.2, 2.4), {
			Texture = TEX_SPARKLE, Color = cseq(Color3.fromHex("#ff4fd8"), Color3.fromHex("#8a2cff")), LightEmission = 1,
			Size = seq(0, 0.35, 1, 0), Lifetime = NumberRange.new(2, 3), Rate = 20, Speed = NumberRange.new(2, 3.5),
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(8, 8),
		})
	end
end

FX.Alien = function(add, d)
	local c = d.Anim.Center
	add.beam("TractorBeam", Vector3.new(0, c.Y - 0.95, c.Z), Vector3.new(0, ROOF + 0.6, c.Z), Color3.fromHex("#3dff6e"), 4.6, 9)
	perBank(function(x)
		add.emitter("BeamMotes", Vector3.new(x, FLOOR + 0.3, 0), Vector3.new(7.6, 0.1, 15.6), {
			Texture = TEX_SPARKLE, Color = cseq(Color3.fromHex("#3dff6e"), Color3.fromHex("#c8ffd6")), LightEmission = 1,
			Size = seq(0, 0.12, 1, 0), Lifetime = NumberRange.new(2.5, 3.5), Rate = 12, Speed = NumberRange.new(1, 1.6),
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(5, 5),
		})
	end)
	-- radioactive bubbles rising off the slime pools
	for _, p in ipairs((d.Points and d.Points.slime_pools) or {}) do
		add.emitter("SlimeBubbles", p, Vector3.new(1.2, 0.05, 1.0), {
			Texture = TEX_SPARKLE, Color = cseq(Color3.fromHex("#d8ff5a"), Color3.fromHex("#7dff6e")), LightEmission = 0.8,
			Size = seq(0, 0.06, 0.6, 0.14, 1, 0), Transparency = seq(0, 0.2, 1, 1), Lifetime = NumberRange.new(1.2, 2.2),
			Rate = 4, Speed = NumberRange.new(0.3, 0.7), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15),
		})
	end
end

FX.Beach = function(add)
	for _, p in ipairs({ Vector3.new(-1.6, ROOF - 1.6, Data.GateZ - 0.35), Vector3.new(1.6, ROOF - 1.6, Data.GateZ - 0.35) }) do
		add.emitter("LanternMotes", p, Vector3.new(0.6, 0.6, 0.6), {
			Texture = TEX_SPARKLE, Color = cseq(Color3.fromHex("#ffd25a"), Color3.fromHex("#ff9a2a")), LightEmission = 1,
			Size = seq(0, 0.1, 1, 0), Lifetime = NumberRange.new(1.5, 2.5), Rate = 4, Speed = NumberRange.new(0.2, 0.5),
			SpreadAngle = Vector2.new(180, 180),
		})
	end
	add.emitter("SandSparkle", Vector3.new(0, 0.3, -8.5), Vector3.new(18, 0.1, 0.5), {
		Texture = TEX_SPARKLE, Color = cseq(Color3.fromHex("#fff4c8")), LightEmission = 1,
		Size = seq(0, 0, 0.3, 0.12, 1, 0), Lifetime = NumberRange.new(0.6, 1), Rate = 6, Speed = NumberRange.new(0, 0),
	})
	perBank(function(x)
		add.emitter("WarmMotes", Vector3.new(x, 2.6, 0), Vector3.new(7.6, 3.6, 15.6), {
			Texture = TEX_SPARKLE, Color = cseq(Color3.fromHex("#ffe08a")), LightEmission = 1,
			Size = seq(0, 0.09, 1, 0), Lifetime = NumberRange.new(2, 3), Rate = 5, Speed = NumberRange.new(0.1, 0.3),
			SpreadAngle = Vector2.new(180, 180),
		})
	end)
end

FX.Sakura = function(add)
	local tex = (Rig.PETAL_TEXTURE ~= "" and Rig.PETAL_TEXTURE) or TEX_SPARKLE
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			add.emitter("Petals", Vector3.new(sx * 10, 6.2, sz * 9.6), Vector3.new(4, 1.5, 4), {
				Texture = tex, Color = cseq(Color3.fromHex("#ffb3d4"), Color3.fromHex("#ff6fae")), LightEmission = 0.2,
				Size = seq(0, 0.16, 1, 0.12), Transparency = seq(0, 0, 0.85, 0, 1, 1), Lifetime = NumberRange.new(5, 7),
				Rate = 4, Speed = NumberRange.new(0.3, 0.6), Acceleration = Vector3.new(0.25, -0.5, 0), Drag = 0.8,
				RotSpeed = NumberRange.new(-90, 90), Rotation = NumberRange.new(0, 360), SpreadAngle = Vector2.new(180, 180),
			})
		end
	end
	add.emitter("PetalDrift", Vector3.new(0, ROOF + 4.6, 0), Vector3.new(18, 0.5, 17), {
		Texture = tex, Color = cseq(Color3.fromHex("#ffc6dd")), LightEmission = 0.2,
		Size = seq(0, 0.14, 1, 0.1), Lifetime = NumberRange.new(5, 7), Rate = 4, Speed = NumberRange.new(0.2, 0.4),
		Acceleration = Vector3.new(0.2, -0.4, 0), RotSpeed = NumberRange.new(-90, 90), Rotation = NumberRange.new(0, 360),
		EmissionDirection = Enum.NormalId.Bottom,
	})
end

-- ------------------------------------------------------------------ setup
function Rig.setup(model: Model, skinName: string?): (boolean, string)
	local skin = skinName or skinFromModel(model)
	if not skin then return false, "Could not tell which skin '" .. model.Name .. "' is (name it Incubator_<Skin> or set attribute IncubatorSkin)" end
	local d = Data.Skins[skin]
	local parts: { [string]: { BasePart } } = {}
	local tiles: { [number]: BasePart } = {}
	local base: BasePart? = nil
	local barrier: BasePart? = nil
	local count, unknown = 0, 0

	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("BasePart") and inst.Name ~= "Slots" and not inst:FindFirstAncestor("VFX") then
			local group, rawKey, slot = parse(inst)
			local matKey = resolveMaterial(d, rawKey)
			inst.Anchored = true
			if group and matKey then
				count += 1
				local m = d.Materials[matKey]
				for _, c in ipairs(inst:GetChildren()) do
					if c:IsA("SurfaceAppearance") then c:Destroy() end
				end
				inst.Material = m.Material
				inst.Color = m.Color
				inst.Transparency = m.Transparency
				inst.Reflectance = m.Reflectance
				inst.CastShadow = not NO_SHADOW_GROUPS[group] and m.Material ~= Enum.Material.Neon
				inst.CanCollide = SOLID_GROUPS[group] == true
				inst.CanTouch = SOLID_GROUPS[group] == true
				inst.CanQuery = true
				inst:SetAttribute("IncubatorGroup", group)
				inst:SetAttribute("IncubatorMaterial", matKey)
				pcall(function()
					(inst :: any).CollisionFidelity = Enum.CollisionFidelity.Box
				end)
				parts[group] = parts[group] or {}
				table.insert(parts[group], inst)
				if slot then
					tiles[slot] = inst
					inst:SetAttribute("SlotIndex", slot)
				end
				if group == "Base_Platform" then base = inst end
				if group == "Entrance_Barrier" then barrier = inst end
			else
				unknown += 1
			end
		end
	end
	if not base then return false, skin .. ": no Base_Platform part found — was the model imported with its part names?" end
	local b = base :: BasePart

	-- size: first rig scales to Rig.SIZE; later runs keep whatever size you gave it in Studio
	local wide = math.max(b.Size.X, b.Size.Z)
	if not model:GetAttribute("IncubatorRigged") then
		local target = Data.BaseWidth * Data.Unit * Rig.SIZE
		if math.abs(wide - target) > 0.05 then
			model:ScaleTo(model:GetScale() * target / wide)
			wide = math.max(b.Size.X, b.Size.Z)
		end
	end
	local U = wide / Data.BaseWidth -- studs per design unit
	model:SetAttribute("ModelUnit", U)

	-- pivot at base-bottom centre, upright, entrance on the front (-Z). No PrimaryPart: it would override WorldPivot.
	model.PrimaryPart = nil
	local pos = b.Position - Vector3.new(0, b.Size.Y / 2, 0)
	local look = b.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
	model.WorldPivot = CFrame.lookAt(pos, pos + flat.Unit)
	if barrier then
		local localPos = model.WorldPivot:PointToObjectSpace((barrier :: BasePart).Position)
		if localPos.Z > 0 then
			model.WorldPivot = model.WorldPivot * CFrame.Angles(0, math.pi, 0)
		end
	end
	model:SetAttribute("IncubatorSkin", skin)
	model:SetAttribute("IncubatorRigged", true)
	local pivot = model.WorldPivot

	-- slot attachments
	local oldSlots = model:FindFirstChild("Slots")
	if oldSlots then oldSlots:Destroy() end
	local slotPart = Instance.new("Part")
	slotPart.Name = "Slots"
	slotPart.Size = Vector3.new(1, 1, 1)
	slotPart.Transparency = 1
	slotPart.Anchored, slotPart.CanCollide, slotPart.CanTouch, slotPart.CanQuery, slotPart.CastShadow = true, false, false, false, false
	slotPart.CFrame = pivot
	for i, p in ipairs(Data.Slots) do
		local a = Instance.new("Attachment")
		a.Name = string.format("Slot%02d", i)
		-- face the walkway (centre line x = 0)
		local world = p * U
		local toward = Vector3.new(-math.sign(world.X), 0, 0)
		a.CFrame = CFrame.lookAt(world, world + toward)
		a:SetAttribute("SlotIndex", i)
		a.Parent = slotPart
	end
	slotPart.Parent = model

	-- VFX folder (rebuilt)
	local old = model:FindFirstChild("VFX")
	if old then old:Destroy() end
	local vfx = Instance.new("Folder")
	vfx.Name = "VFX"
	vfx.Parent = model
	local K = U * 0.75 -- particle size / speed scale

	local function anchorPart(name: string, p: Vector3, size: Vector3): Part
		local a = Instance.new("Part")
		a.Name = name
		a.Size = size
		a.CFrame = pivot * CFrame.new(p * U)
		a.Transparency = 1
		a.Anchored, a.CanCollide, a.CanTouch, a.CanQuery, a.CastShadow = true, false, false, false, false
		a:SetAttribute("ModelOffset", CFrame.new(p * U))
		a.Parent = vfx
		return a
	end

	local add = {}
	function add.emitter(name: string, p: Vector3, size: Vector3, props: { [string]: any })
		local a = anchorPart(name .. "Emitter", p, size * U)
		local e = Instance.new("ParticleEmitter")
		e.Name = name
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		for k, v in pairs(props) do
			(e :: any)[k] = v
		end
		e.Size = scaleSeq(e.Size, K)
		e.Speed = NumberRange.new(e.Speed.Min * K, e.Speed.Max * K)
		e.Acceleration = e.Acceleration * K
		e:SetAttribute("BaseRate", e.Rate)
		e.Parent = a
	end
	function add.scanline(name: string, p: Vector3, size: Vector3, color: Color3, y0: number, h: number)
		local a = anchorPart(name, p, Vector3.new(size.X * U, 0.05, size.Z * U))
		a.Material = Enum.Material.Neon
		a.Color = color
		a.Transparency = 0.55
		a:SetAttribute("Scanline", true)
		a:SetAttribute("ScanX", p.X * U)
		a:SetAttribute("ScanY0", y0 * U)
		a:SetAttribute("ScanH", h * U)
	end
	function add.beam(name: string, p0: Vector3, p1: Vector3, color: Color3, w0: number, w1: number)
		local mid = (p0 + p1) / 2
		local a = anchorPart(name, mid, Vector3.new(0.2, 0.2, 0.2))
		local at0 = Instance.new("Attachment"); at0.Position = (p0 - mid) * U; at0.Parent = a
		local at1 = Instance.new("Attachment"); at1.Position = (p1 - mid) * U; at1.Parent = a
		local bm = Instance.new("Beam")
		bm.Attachment0, bm.Attachment1 = at0, at1
		bm.Color = cseq(color)
		bm.LightEmission = 1
		bm.Transparency = seq(0, 0.72, 1, 0.92)
		bm.Width0, bm.Width1 = w0 * U, w1 * U
		bm.FaceCamera = true
		bm.Segments = 1
		bm.Parent = a
	end

	function add.pulse(name: string, p0: Vector3, p1: Vector3, color: Color3, w: number)
		local mid = (p0 + p1) / 2
		local a = anchorPart(name, mid, Vector3.new(0.2, 0.2, 0.2))
		local at0 = Instance.new("Attachment"); at0.Parent = a; at0.Position = (p0 - mid) * U
		local at1 = Instance.new("Attachment"); at1.Parent = a; at1.Position = (p1 - mid) * U
		local bm = Instance.new("Beam")
		bm.Attachment0, bm.Attachment1 = at0, at1
		bm.Color = cseq(color); bm.LightEmission = 1; bm.LightInfluence = 0
		bm.Texture = TEX_SPARKLE; bm.TextureMode = Enum.TextureMode.Static; bm.TextureLength = 2.5; bm.TextureSpeed = 1.4
		bm.Transparency = seq(0, 0.2, 1, 0.2); bm.Width0, bm.Width1 = w * U, w * U; bm.FaceCamera = true; bm.Segments = 1
		bm.Parent = a
	end

	-- lights
	for i, l in ipairs(d.Lights) do
		local a = anchorPart("Light" .. i, l.Position, Vector3.new(0.2, 0.2, 0.2))
		local lt: Light
		if l.Kind == "SurfaceLight" then
			local s = Instance.new("SurfaceLight")
			s.Face = l.Face or Enum.NormalId.Top
			s.Angle = 120
			lt = s
			a.Size = Vector3.new(7.6 * U, 0.1, 15.6 * U)
		else
			lt = Instance.new("PointLight")
		end
		local col = l.Color or d.Accent
		lt.Color = col
		lt.Brightness = l.Brightness
		;(lt :: any).Range = math.min(60, l.Range * U)
		lt.Shadows = false
		lt:SetAttribute("BaseBrightness", l.Brightness)
		local hex = "#" .. col:ToHex():lower()
		if WARM[hex] then lt:SetAttribute("Flicker", true) end
		if skin == "Alien" and l.Position.Y > ROOF + 7 then lt:SetAttribute("Blink", true) end
		lt.Parent = a
	end

	local recipe = FX[skin]
	if recipe then recipe(add, d) end

	if not CollectionService:HasTag(model, "IncubatorSkin") then
		CollectionService:AddTag(model, "IncubatorSkin")
	end
	local nTiles = 0
	for _ in pairs(tiles) do nTiles += 1 end
	return true, string.format("%s: %d parts styled, %d unrecognised, %d cell tiles, 16 slots, %d lights, %.1f x %.1f studs",
		skin, count, unknown, nTiles, #d.Lights, b.Size.X, b.Size.Z)
end

-- ------------------------------------------------------------------ slot helpers
function Rig.slotCFrame(model: Model, index: number): CFrame?
	local sp = model:FindFirstChild("Slots")
	local a = sp and sp:FindFirstChild(string.format("Slot%02d", index))
	return a and (a :: Attachment).WorldCFrame or nil
end

function Rig.slotTile(model: Model, index: number): BasePart?
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p:GetAttribute("SlotIndex") == index then return p end
	end
	return nil
end

-- ------------------------------------------------------------------ import helpers
local PREFIX = { Tech = "Tech", Nat = "Nature", Vol = "Volcano", Ice = "Ice", Roy = "Royal", Void = "Void", Ali = "Alien", Bch = "Beach", Sak = "Sakura" }

-- A combined import may come in as one flat model: regroup parts into one Model per skin by material prefix.
function Rig.splitCombined(container: Instance?): number
	local made = 0
	for _, m in ipairs((container or workspace):GetDescendants()) do
		if m:IsA("Model") and not skinFromModel(m) then
			local buckets = {}
			for _, p in ipairs(m:GetChildren()) do
				if p:IsA("BasePart") then
					local _, matKey = parse(p)
					local pre = matKey and string.match(matKey, "^(%a+)_")
					local skin = pre and PREFIX[pre]
					if skin then
						buckets[skin] = buckets[skin] or {}
						table.insert(buckets[skin], p)
					end
				end
			end
			local count = 0
			for _ in pairs(buckets) do count += 1 end
			if count > 1 then
				for skin, ps in pairs(buckets) do
					local nm = Instance.new("Model")
					nm.Name = Data.Skins[skin].ModelName
					nm.Parent = m.Parent
					for _, p in ipairs(ps) do p.Parent = nm end
					made += 1
				end
			end
		end
	end
	return made
end

-- Move every incubator out of the wrapper model the importer creates and straight into Workspace,
-- so each one is its own top-level model you can select and move on its own (no grouping).
function Rig.unwrap(container: Instance?): number
	local moved = 0
	local wrappers = {}
	for _, m in ipairs((container or workspace):GetDescendants()) do
		if m:IsA("Model") and skinFromModel(m) and m.Parent ~= workspace then
			local p = m.Parent
			local nested = p and p:IsA("Model") and skinFromModel(p)
			if not nested then
				m.Parent = workspace
				moved += 1
				if p and p ~= workspace then wrappers[p] = true end
			end
		end
	end
	for p in pairs(wrappers) do
		local hasParts = false
		for _, d in ipairs(p:GetDescendants()) do if d:IsA("BasePart") then hasParts = true break end end
		if not hasParts then p:Destroy() end
	end
	return moved
end

function Rig.setupAll(container: Instance?): { string }
	local report = {}
	local split = Rig.splitCombined(container)
	if split > 0 then table.insert(report, "Regrouped combined import into " .. split .. " skin models") end
	for _, m in ipairs((container or workspace):GetDescendants()) do
		if m:IsA("Model") and skinFromModel(m) and m:FindFirstChildWhichIsA("BasePart", true) then
			local isNested = m.Parent and m.Parent:IsA("Model") and skinFromModel(m.Parent)
			if not isNested then
				local ok, msg = Rig.setup(m)
				table.insert(report, (ok and "OK  " or "ERR ") .. msg)
			end
		end
	end
	return report
end

return Rig
